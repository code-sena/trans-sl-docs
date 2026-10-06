# Runbook — IAM Service

> For whoever is on call. Each section is executable without extra context. The service is not extracted yet: where a
> command refers to today's backend it says so. No Kubernetes, dashboard or alert channel is defined yet; commands assume Docker Compose.

**Service:** iam-service
**Version:** 1.0 (target)
**Last updated:** 2026-10-04

---

## 1. Quick information

| Field | Value |
|-------|-------|
| Local port | 3001 (today: backend on 3000, paths `/api/auth`, `/api/users`) |
| Health | `GET http://localhost:3001/health` |
| Database | PostgreSQL `iam` (schemas `identity`, `authz`, `audit`) |
| Broker | RabbitMQ, exchange `traduce.events` |
| Secrets | `JWT_SECRET` (or the private key), `EMAIL_PASS`, DB password |

---

## 2. Verify the service is healthy

```bash
curl -s http://localhost:3001/health

# Sign-in works (through the gateway)
curl -s -X POST http://localhost:8080/api/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"user@example.com","password":"Secret123!"}'
```

```sql
-- Exactly one active password policy (expect 1)
SELECT COUNT(*) FROM identity.password_policies WHERE is_active;
-- The three seed roles exist (expect 3)
SELECT COUNT(*) FROM authz.roles WHERE name IN ('USER','LINGUIST','ADMIN');
```

---

## 3. Frequent problems and what to do

### Everyone gets 401 after a deploy

The signing key changed and the gateway or a service still verifies with the old one. Align `JWT_SECRET` / the public key in
iam, the gateway and the services, then recreate them (see the gateway runbook, section 3).

### A user can authenticate but cannot do anything

The account has no role. Check and assign `USER`:

```sql
SELECT u.email, r.name FROM identity.users u
LEFT JOIN authz.user_roles ur ON ur.user_id = u.user_id
LEFT JOIN authz.roles r ON r.role_id = ur.role_id
WHERE u.email = 'user@example.com';

INSERT INTO authz.user_roles (user_id, role_id)
SELECT u.user_id, r.role_id FROM identity.users u JOIN authz.roles r ON r.name = 'USER'
WHERE u.email = 'user@example.com' ON CONFLICT DO NOTHING;
```

### An administrator was granted ADMIN but gets 403 in lexicon

The role reaches the other services in the token. The user must refresh the token (or sign in again).

### Today (backend process): grant ADMIN with the old tables

```sql
INSERT INTO public.user_role (user_id, role_id)
SELECT u.user_id, r.role_id FROM public.users u JOIN public.role r ON r.name = 'ADMIN'
WHERE u.email = 'admin@example.com' ON CONFLICT DO NOTHING;
```

### Account locked or blocked

`locked_until` in the future is a temporary lockout that lifts on its own. `status = 'BLOCKED'` only an administrator restores:

```sql
SELECT status, lockout_level, locked_until, blocked_at FROM identity.users WHERE email = 'user@example.com';
-- Restore (after verifying the identity of the holder)
UPDATE identity.users SET status = 'ACTIVE', blocked_at = NULL, lockout_level = 0,
       failed_login_attempts = 0, locked_until = NULL WHERE email = 'user@example.com';
```

### Reset or verification codes do not arrive

The mailer uses the account of `EMAIL_USER`/`EMAIL_PASS`. Check the logs for mail errors and the Gmail app password.
Tokens are single-use and expire; request a new one.

### Events are not reaching other services

```bash
docker compose logs --tail=100 iam-service | grep -i rabbit
docker compose exec rabbitmq rabbitmqctl list_queues name messages | grep -E 'dlq|iam'
```

Messages in a DLQ mean a consumer failed 3 to 5 times; read the message, fix the consumer, then shovel it back.

---

## 4. Maintenance operations

### 4.1 Rotate the JWT key

1. Generate the new key pair; deploy the public key to the gateway and services (accept both keys during the transition).
2. Switch iam to sign with the new private key.
3. After the access-token lifetime, remove the old public key.

### 4.2 Back up the database

```bash
docker compose exec postgres pg_dump -U postgres -d iam > iam_backup.sql
```

### 4.3 Personal-data deletion request

A request creates `AccountDeletionRequested`; every service deletes its own data and iam finishes with `AccountDeleted`.
Check that the `users` row has `deleted_at`. Note DATA-06: name and email stay in clear until the anonymization routine is implemented.

### 4.4 Roll back

```bash
docker compose up -d iam-service   # with the previous image tag
```

Migrations have no automatic down path for the integer-to-UUID change; restore from the backup of 4.2.

---

## 5. Post-incident checklist

- [ ] Login and refresh work through the gateway
- [ ] A new account receives the `USER` role and a profile (event `UserRegistered` consumed)
- [ ] DLQs are empty
- [ ] Incident recorded in `13-operations/incident-management.md`
