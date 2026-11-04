# Runbook — Profile Service

> For whoever is on call. The service is not implemented yet; the commands are the target ones and assume Docker Compose.
> No Kubernetes, dashboard or alert channel is defined yet.

**Service:** profile-service
**Version:** 1.0 (target)
**Last updated:** 2026-10-04

---

## 1. Quick information

| Field | Value |
|-------|-------|
| Local port | 3005 |
| Health | `GET http://localhost:3005/health` |
| Database | PostgreSQL `profile` (schemas `profile`, `notification`, `gamification`) |
| Broker | RabbitMQ, exchange `traduce.events`, queue `profile.main` |
| External providers | Push (FCM / APNs), mail |

---

## 2. Verify the service is healthy

```bash
curl -s http://localhost:3005/health
docker compose exec rabbitmq rabbitmqctl list_queues name messages consumers | grep profile
```

```sql
-- Notifications waiting for delivery (the worker's query; expect a small number)
SELECT count(*) FROM notification.notifications WHERE status = 'PENDING' AND scheduled_at <= now();
```

---

## 3. Frequent problems and what to do

### A new user has no preferences

`iam.UserRegistered` was not consumed. The app still works (defaults). Check the DLQ, reprocess, or create the row:

```sql
INSERT INTO profile.user_preferences (user_id) VALUES ('<user-uuid>') ON CONFLICT (user_id) DO NOTHING;
```

### Notifications stay `PENDING`

The delivery worker is down or the provider fails.

```bash
docker compose logs --tail=100 profile-service | grep -iE 'push|mail|provider'
docker compose restart profile-service
```

```sql
SELECT status, count(*) FROM notification.notifications GROUP BY status;   -- many FAILED = provider problem
```

### A push is rejected (`FAILED`)

The token was recycled or revoked by the provider. The service revokes the device (`is_active = FALSE`). Do not delete the row (INV-024).
A user who reinstalls registers again with an upsert on `push_token`.

### A user complains of no notifications

Check, in order: `notifications_enabled` in `user_preferences`, `is_active` of the notification type, an active device for push.

```sql
SELECT notifications_enabled FROM profile.user_preferences WHERE user_id = '<user-uuid>';
SELECT code, is_active FROM notification.notification_types;
SELECT device_id, is_active FROM notification.user_devices WHERE user_id = '<user-uuid>';
```

### An achievement is announced twice

`notified_at` must be set when the notification is created; if the progress row was recomputed without it, set it:

```sql
UPDATE gamification.user_achievements SET notified_at = now() WHERE achieved_at IS NOT NULL AND notified_at IS NULL;
```

### Migrating an existing database to 008–010 (manual)

The init scripts in `docker-compose.yml` only run on new volumes. On an existing database: back up first (4.1), stop the
Profile consumers, and apply in order, with the commands listed at the top of `backend/docker-compose.yml`:

```bash
docker compose exec -T postgres-profile psql -X -v ON_ERROR_STOP=1 -U postgres -d profile < services/profile-service/db/008_admin_reports.sql
docker compose exec -T postgres-profile psql -X -v ON_ERROR_STOP=1 -U postgres -d profile < services/profile-service/db/009_daily_challenges.sql
docker compose exec -T postgres-profile psql -X -v ON_ERROR_STOP=1 -U postgres -d profile < services/profile-service/db/010_challenge_reward_achievements.sql
```

Then deploy Profile before the frontend. Do not recreate volumes. Read-only check of a user's challenges:

```sql
SELECT uc.challenge_date, uc.code, uc.current_count, uc.target_count, uc.completed_at, cr.points, cr.granted_at
FROM user_challenges uc LEFT JOIN challenge_rewards cr USING (user_challenge_id) WHERE uc.user_id = '<user-id>';
```

### `AccountDeletionRequested` in the DLQ

Legal priority. Read the message, fix the cause and reprocess; verify no rows remain for that `user_id` in `user_preferences`, `user_devices`, `notifications` and `user_achievements`.

---

## 4. Maintenance operations

### 4.1 Back up

```bash
docker compose exec postgres pg_dump -U postgres -d profile > profile_backup.sql
```

### 4.2 Withdraw a notification type

An administrator sets `is_active = FALSE` (never deletes). Pending notifications of that type are `CANCELLED`.

### 4.3 Roll back

```bash
docker compose up -d profile-service   # previous image tag
```

---

## 5. Post-incident checklist

- [ ] The queue is empty and no notification is stuck in `PENDING`
- [ ] A test push and an in-app notification are delivered
- [ ] Incident recorded in `13-operations/incident-management.md`
