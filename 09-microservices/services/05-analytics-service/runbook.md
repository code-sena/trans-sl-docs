# Runbook — Analytics Service

> For whoever is on call. The service is not implemented yet; the commands are the target ones and assume Docker Compose.
> No Kubernetes, dashboard or alert channel is defined yet.

**Service:** analytics-service
**Version:** 1.0 (target)
**Last updated:** 2026-10-04

---

## 1. Quick information

| Field | Value |
|-------|-------|
| Local port | 3004 |
| Health | `GET http://localhost:3004/health` |
| Database | PostgreSQL `analytics` (schema `usage`) |
| Broker | RabbitMQ, exchange `traduce.events`, queue `analytics.main` |
| Impact of an outage | None for users. Statistics lag until the queue is drained |

---

## 2. Verify the service is healthy

```bash
curl -s http://localhost:3004/health
docker compose exec rabbitmq rabbitmqctl list_queues name messages consumers | grep analytics
```

```sql
-- Events arrive (expect a recent timestamp)
SELECT max(created_at) FROM usage.usage_events;
```

---

## 3. Frequent problems and what to do

### Statistics are stale

The queue is backing up or the consumer is down.

```bash
docker compose logs --tail=100 analytics-service | grep -i error
docker compose restart analytics-service
```

The queue keeps the messages; once the consumer is back it catches up. Handlers are idempotent, so reprocessing is safe.

### Messages in `analytics.main.dlq`

Read the message, fix the handler or the data, and shovel it back to the main queue. A permanently invalid message can be discarded; a lost statistic is not a compliance issue.

### A rollup is wrong or `unique_users` looks inflated

Rollups are a cache. Recompute the affected day from `usage_events`:

```sql
DELETE FROM usage.usage_daily_stats WHERE stat_date = '2026-10-01';
-- then run the recompute job for that date
```

Remember that `unique_users` cannot be summed across rows; check the grain of the report first.

### An account was deleted but its events still show a `user_id`

`iam.AccountDeleted` was not processed. Check the DLQ, reprocess, then verify:

```sql
SELECT count(*) FROM usage.usage_events WHERE user_id = '<deleted-user-uuid>';   -- expect 0
```

---

## 4. Maintenance operations

### 4.1 Back up

```bash
docker compose exec postgres pg_dump -U postgres -d analytics -t usage.usage_events > usage_events_backup.sql
```

`usage_events` is the only table that cannot be rebuilt.

### 4.2 Recompute the rollups

Run the recompute job for a date range; it rebuilds `usage_daily_stats` and `session_daily_stats` from `usage_events`.

### 4.3 Roll back

```bash
docker compose up -d analytics-service   # previous image tag
```

### 4.4 Growth

`usage_events` grows without bound (DATA-10). Monthly partitioning by `created_at` or a purge policy is an open decision shared with the audit log in iam.

---

## 5. Post-incident checklist

- [ ] The queue is empty and `max(created_at)` is recent
- [ ] The dashboard shows the last day
- [ ] Incident recorded in `13-operations/incident-management.md`
