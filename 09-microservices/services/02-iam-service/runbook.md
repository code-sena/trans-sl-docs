# Runbook — IAM Service

> For whoever is on call. Each section is executable without extra context. The commands assume Docker Compose.
> No Kubernetes, dashboard or alert channel is defined yet.

**Service:** iam-service
**Version:** 1.4.0 (backend `main` a962982)
**Last updated:** 2026-11-04

---

## 1. Quick information

| Field | Value |
|-------|-------|
| Local port | 3001 (internal; Compose does not publish it. From outside use the gateway on 8080) |
| Health | `GET http://localhost:3001/health` when the service runs locally with `npm run dev -w @traduce/iam-service` |
| Database | PostgreSQL `iam` (container `postgres-iam`, schema `public`) |
| Broker | RabbitMQ, exchange `traduce.events` (publishes `iam.UserRegistered` and `iam.UserDeleted`) |
| Secrets | `JWT_SECRET`, `EMAIL_PASS`, `POSTGRES_PASSWORD`, `FACEBOOK_APP_SECRET` |

---

## 2. Verify the service is healthy

```bash
# Sign-in works through the gateway
curl -s -X POST http://localhost:8080/api/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"user@example.com","password":"Secret123!"}'
```

```bash
# The three seed roles exist (expect 3)
docker compose exec -T postgres-iam psql -U postgres -d iam -c "SELECT COUNT(*) FROM roles WHERE name IN ('USER','LINGUIST','ADMIN');"
```

---

## 3. Frequent problems and what to do

### Everyone gets 401 after a change of secret

`JWT_SECRET` differs between `iam-service` and the gateway or a service. Align it in all of them, then recreate them (see section 4.2 of the gateway runbook).

### A user can sign in but cannot do anything

The account has no role. Check and assign `USER`:

```bash
docker compose exec -T postgres-iam psql -U postgres -d iam -c "
SELECT u.email, r.name FROM users u
LEFT JOIN user_roles ur ON ur.user_id = u.user_id
LEFT JOIN roles r ON r.role_id = ur.role_id
WHERE u.email = 'user@example.com';"

docker compose exec -T postgres-iam psql -U postgres -d iam -c "
INSERT INTO user_roles (user_id, role_id)
SELECT u.user_id, r.role_id FROM users u JOIN roles r ON r.name = 'USER'
WHERE u.email = 'user@example.com' ON CONFLICT DO NOTHING;"
```

### An administrator was granted ADMIN but still gets 403

The role reaches the other services in the token. The roles of a token are fixed when it is signed, so the user must sign in again.

### The first administrator

There is no endpoint that creates the first ADMIN. Promote the account by hand (the comment at the end of `services/iam-service/db/003_iam_roles_permissions.sql` has the statement).

### Account blocked

The code does not set the status `BLOCKED` today; it only refuses sign-in when the status is `BLOCKED`. To restore an account, after verifying the identity of its holder:

```bash
docker compose exec -T postgres-iam psql -U postgres -d iam -c "
UPDATE users SET status = 'ACTIVE' WHERE email = 'user@example.com';"
```

### Verification or reset codes do not arrive

The mailer uses the account of `EMAIL_USER`/`EMAIL_PASS`. Check the logs for mail errors and the Gmail app password.
Codes are single-use and expire; ask for a new one.

### Events are not reaching other services

```bash
docker compose logs --tail=100 iam-service | grep -i rabbit
docker compose exec rabbitmq rabbitmqctl list_queues name messages | grep -E 'dead|user-deleted|user-registered'
```

A message in a `.dead` queue means a consumer failed to process it. Fix the consumer, then move the message back by hand.
An unpublished `iam.UserDeleted` stays in `outbox_events` (`published_at` is null) until the relay can publish it; the `/health` of iam reports `outbox_backlog` after 10 minutes.

---

## 4. Maintenance operations

### 4.1 Rotate the JWT secret

`JWT_SECRET` is one shared HS256 secret (there is no key pair today).

1. Change `JWT_SECRET` at the same time in `iam-service`, `api-gateway` and the other services that verify tokens.
2. Recreate them: `docker compose up -d --force-recreate`.
3. Tokens signed with the old secret answer `401 UNAUTHORIZED` until users sign in again.

### 4.2 Back up the database

```bash
docker compose exec -T postgres-iam pg_dump -U postgres -d iam > iam_backup.sql
```

### 4.3 Account deletion (`DELETE /api/users/me`)

The erasure removes the `users` row, its roles and its codes in one transaction, and writes `iam.UserDeleted` to `outbox_events` in the same transaction. Check that the row is gone and that the event is published:

```bash
docker compose exec -T postgres-iam psql -U postgres -d iam -c "
SELECT event_id, type, published_at FROM outbox_events WHERE type = 'iam.UserDeleted' ORDER BY created_at DESC LIMIT 5;"
```

### 4.4 Roll back

The migrations have no down scripts. To roll back the code, check out the previous commit and rebuild:

```bash
git checkout <previous-commit>
docker compose up -d --build iam-service
```

If a migration must be undone, restore from the backup of 4.2.

---

## 5. Post-incident checklist

- [ ] Sign-in works through the gateway
- [ ] A new account receives the `USER` role and a profile (event `UserRegistered` consumed by profile-service)
- [ ] The `.dead` queues are empty
- [ ] Incident recorded in `13-operations/incident-management.md`
