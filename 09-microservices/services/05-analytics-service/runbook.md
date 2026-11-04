# Runbook — Analytics Service

> For whoever is on call. Each section is executable without extra context. The commands assume Docker Compose.
> No Kubernetes, dashboard or alert channel is defined yet.

**Service:** analytics-service
**Version:** 1.4.0 (backend `main` a962982)
**Last updated:** 2026-11-04

---

## 1. Quick information

| Field | Value |
|-------|-------|
| Local port | 3004 (internal; Compose does not publish it) |
| Health | `GET http://localhost:3004/health` when the service runs locally |
| Database | PostgreSQL `analytics` (container `postgres-analytics`, published on `127.0.0.1:5436`), table `usage_event` and `erased_users` |
| Broker | RabbitMQ, exchange `traduce.events`. Queues `analytics-service.translation-produced`, `analytics-service.user-registered` and `analytics-service.user-deleted` |
| Impact of an outage | None for users. Statistics lag until the queues are drained |

---

## 2. Verify the service is healthy

```bash
# Through the gateway (needs an ADMIN token)
curl -s "http://localhost:8080/api/analytics/daily?from=2026-10-01&to=2026-10-12" -H "Authorization: Bearer $TOKEN"

# Queues have consumers
docker compose exec rabbitmq rabbitmqctl list_queues name messages consumers | grep analytics
```

```bash
# Events arrive (expect a recent timestamp)
docker compose exec -T postgres-analytics psql -U postgres -d analytics -c "SELECT max(created_at) FROM usage_event;"
```

---

## 3. Frequent problems and what to do

### Statistics are stale

The queues are backing up or the consumer is down.

```bash
docker compose logs --tail=100 analytics-service | grep -i error
docker compose restart analytics-service
```

The queues keep the messages; once the consumer is back it catches up. The handlers ignore a repeated `eventId`, so reprocessing is safe.

### Messages in a `.dead` queue

A message in `analytics-service.<event>.dead` is an event the handler could not process. Read the message, fix the handler or the data, and move it back to its queue by hand. A permanently invalid message can be discarded: a lost statistic is not a compliance issue. A message in `analytics-service.user-deleted.dead` is different: it means an account was not unlinked (next problem).

### An account was deleted but its events still show a `user_id`

`iam.UserDeleted` was not processed. Check `analytics-service.user-deleted` and its `.dead` queue, fix the cause, then verify (the id is the numeric id of iam):

```bash
docker compose exec -T postgres-analytics psql -U postgres -d analytics -c "SELECT count(*) FROM usage_event WHERE user_id = '<deleted-user-id>';"   # expect 0
```

---

## 4. Maintenance operations

### 4.1 Back up

```bash
docker compose exec -T postgres-analytics pg_dump -U postgres -d analytics -t usage_event -t erased_users > usage_event_backup.sql
```

`usage_event` cannot be rebuilt from anything else: back it up before any destructive change.

### 4.2 Growth

`usage_event` grows without bound. There is no purge policy or partitioning in the code yet; the decision is open with the team.

### 4.3 Roll back a deploy

```bash
git checkout <previous-commit>
docker compose up -d --build analytics-service
```

---

## 5. Post-incident checklist

- [ ] The queues are empty and `max(created_at)` is recent
- [ ] The admin reports answer for the last day
- [ ] The `.dead` queues are empty
- [ ] Incident recorded in `13-operations/incident-management.md`
