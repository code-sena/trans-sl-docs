# Runbook — Profile Service

> For whoever is on call. Each section is executable without extra context. The commands assume Docker Compose.
> No Kubernetes, dashboard or alert channel is defined yet.

**Service:** profile-service
**Version:** 1.4.0 (backend `main` a962982)
**Last updated:** 2026-11-04

---

## 1. Quick information

| Field | Value |
|-------|-------|
| Local port | 3005 (internal; Compose does not publish it) |
| Health | `GET http://localhost:3005/health` when the service runs locally |
| Database | PostgreSQL `profile` (container `postgres-profile`, published on `127.0.0.1:5437`), schema `public` |
| Broker | RabbitMQ, exchange `traduce.events`. Queues `profile-service.user-registered`, `profile-service.translation-produced` and `profile-service.user-deleted` |
| External providers | Mail only (the account of `EMAIL_USER`). Push is not used (ADR-007) |

---

## 2. Verify the service is healthy

```bash
# Through the gateway, with a token
curl -s http://localhost:8080/api/profile/preferences -H "Authorization: Bearer $TOKEN"

# Queues have consumers
docker compose exec rabbitmq rabbitmqctl list_queues name messages consumers | grep profile
```

```bash
# Email notifications waiting for the worker (expect a small number)
docker compose exec -T postgres-profile psql -U postgres -d profile -c "SELECT count(*) FROM notifications WHERE channel = 'EMAIL' AND status = 'PENDING' AND scheduled_at <= now();"
```

---

## 3. Frequent problems and what to do

### A new user has no profile

`iam.UserRegistered` was not consumed. `GET /api/profile/me` answers `404` and the preferences answer the defaults. A `PATCH` of the preferences creates the profile. To create the row by hand, check the message in the dead-letter queue first, then:

```bash
docker compose exec -T postgres-profile psql -U postgres -d profile -c "INSERT INTO user_preferences (user_id) VALUES ('<user-id>') ON CONFLICT (user_id) DO NOTHING;"
```

### Email notifications stay `PENDING`

The mail worker is down or the mail provider fails.

```bash
docker compose logs --tail=100 profile-service | grep -iE 'mail|smtp|email'
docker compose restart profile-service
docker compose exec -T postgres-profile psql -U postgres -d profile -c "SELECT status, count(*) FROM notifications WHERE channel = 'EMAIL' GROUP BY status;"
```

Many `FAILED` rows mean a provider problem; fix the mail account (`EMAIL_USER` and `EMAIL_PASS`) and recreate the container.

### A user complains of no notifications

Check, in order: `notifications_enabled` of the user, and that the notification exists:

```bash
docker compose exec -T postgres-profile psql -U postgres -d profile -c "SELECT notifications_enabled FROM user_preferences WHERE user_id = '<user-id>';"
```

If `notifications_enabled` is false, the code does not create in-app notifications for that user (the user switched them off).

### Messages in a `.dead` queue

A message in `profile-service.user-deleted.dead` is an account deletion that was not applied: the profile of that user may remain. Read the message, fix the cause and move it back by hand, then check that no rows remain for that user in `user_preferences`, `notifications`, `user_achievements` and `user_profiles`.

```bash
docker compose exec rabbitmq rabbitmqctl list_queues name messages | grep profile
```

### Administrator reports do not arrive

Check that `ADMIN_REPORTS_ENABLED` is `true` and that the administrators have notifications on. The reports run every `ADMIN_REPORTS_TICK_MS` (15 minutes by default). Check the logs for mail errors.

---

## 4. Maintenance operations

### 4.1 Back up

```bash
docker compose exec -T postgres-profile pg_dump -U postgres -d profile > profile_backup.sql
```

### 4.2 Apply the migrations 008 to 010 on an existing database

The init scripts run only on new volumes. On an existing database: back up first (4.1), stop the profile consumers and apply in order. The commands are the same as the comments at the top of `docker-compose.yml`:

```bash
docker compose exec -T postgres-profile psql -X -v ON_ERROR_STOP=1 -U postgres -d profile < services/profile-service/db/008_admin_reports.sql
docker compose exec -T postgres-profile psql -X -v ON_ERROR_STOP=1 -U postgres -d profile < services/profile-service/db/009_daily_challenges.sql
docker compose exec -T postgres-profile psql -X -v ON_ERROR_STOP=1 -U postgres -d profile < services/profile-service/db/010_challenge_reward_achievements.sql
```

Do not recreate volumes. Read-only check of a user's challenges:

```bash
docker compose exec -T postgres-profile psql -U postgres -d profile -c "SELECT uc.challenge_date, uc.code, uc.current_count, uc.target_count, uc.completed_at, cr.points, cr.granted_at FROM user_challenges uc LEFT JOIN challenge_rewards cr USING (user_challenge_id) WHERE uc.user_id = '<user-id>';"
```

### 4.3 Stop the administrator reports

Set `ADMIN_REPORTS_ENABLED=false` in the environment and recreate the container: `docker compose up -d --force-recreate profile-service`.

### 4.4 Roll back a deploy

```bash
git checkout <previous-commit>
docker compose up -d --build profile-service
```

---

## 5. Post-incident checklist

- [ ] `GET /api/profile/preferences` answers with a valid token
- [ ] No email notification stuck in `PENDING`
- [ ] The `.dead` queues are empty
- [ ] Incident recorded in `13-operations/incident-management.md`
