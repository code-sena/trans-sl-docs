# IAM Service

> Identity authority of Traduce Señas. Owns accounts, authentication, JWT issuance, roles and permissions, consent and
> personal-data requests, and the audit trail. It is the authoritative owner of `User`, `Role` and `Permission`.

**Extraction status:** pending. The code exists as the backend modules `auth` (`backend/src/domains/auth/`) and `users`
(`backend/src/domains/users/`), both hexagonal. The profile data (preferences) moves to `profile-service`.
See `09-microservices/service-catalog.md`.

---

## Responsibility

Answers "who is this person and what may they do". Issues the access and refresh tokens that the gateway validates and
that every other service reads (`sub`, `roles`). Records the audit trail of the system.

---

## Location in the architecture

| Field | Value |
|-------|-------|
| Number in catalog | 02 |
| Local port | 3001 |
| Bounded contexts | Identity & Access; Consent & Personal Data; audit (cross-cutting) |
| DB engine | PostgreSQL, database `iam`, schemas `identity`, `authz`, `audit` |
| Data owned | `06-data/domains/01-identity`, `02-authorization`, `10-audit` |
| Gateway paths | `/api/auth/**`, `/api/users/**`, `/api/roles/**`, `/api/consents/**` |
| Communicates with | RabbitMQ (`traduce.events`). No synchronous calls to other services |
| Consumed by | api-gateway (public paths), the app; every service through the JWT it issues |
| Events | Publishes the identity and consent events; consumes events of other services for the audit trail. See [events.md](./events.md) |
| Health | `GET /health` |

---

## Responsibilities (what this service DOES)

- Register users with accepted terms (version and date stored), email unique
- Authenticate with email and password (external providers Google / Facebook are in the model; see status below)
- Issue a JWT access token and a refresh token (rotation with reuse detection in `refresh_tokens`)
- Verify the email and recover the password with single-use, expiring, attempt-counted codes (`user_tokens`)
- Apply the progressive lockout ladder (1, 5, 10 minutes, then `BLOCKED`) and the active password policy
- Manage roles, permissions and role assignment (`USER`, `LINGUIST`, `ADMIN`); permissions reach users only through roles
- Register consent evidence and handle personal-data deletion requests (publishes `AccountDeletionRequested`)
- Write `audit_logs` and `error_logs` from the events and requests it receives

## Out of scope (what it does NOT do)

- **Interface preferences, notifications and achievements:** `profile-service`
- **Sending push or email notifications:** `profile-service` (it consumes `iam.PasswordResetRequested`, `iam.AccountLocked`)
- **Per-resource authorization:** each service checks `roles` from the token; iam only informs them
- **Routing and rate limiting:** `api-gateway`
- **Gesture samples and their files:** `recognition-service` (iam only holds the consent evidence and emits consent events)

---

## What exists today (module `auth` and `users`)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/auth/register` | Public | `{name, email, password}`; answers `201` |
| POST | `/api/auth/login` | Public | `{email, password}`; returns the JWT |
| POST | `/api/auth/forgot-password` | Public | `{email}`; sends a code by email |
| POST | `/api/auth/verify-code` | Public | `{email, code}` |
| POST | `/api/auth/reset-password` | Public | `{email, code, newPassword}` |
| GET | `/api/users/me` | JWT | Data of the authenticated user |

Errors of the current module are `400 {success: false, message}`. A use case `google_login` exists but no route is mounted.
The current JWT is HS256, expires in 1 day, has no refresh token, and carries `user_id` and `email`; roles are read
from the `user_role` table on each request (`require_role`). Password hash: bcrypt (`adapters/outbound/security/password.ts`).
The mail is sent with Nodemailer (`adapters/outbound/mailer`).

## Target API (to be formalized in `07-api/contracts/openapi/auth-service.yaml`)

| Area | Path prefix | Notes |
|------|-------------|-------|
| Authentication | `/api/auth/**` | The endpoints above plus refresh and logout of a session |
| Users | `/api/users/**` | `GET /me`, administration of users (permission `users.manage`) |
| Roles | `/api/roles/**` | Roles, permissions and assignments (ADMIN) |
| Consents | `/api/consents/**` | Grant, revoke, request deletion |

JWT target claims: `sub` (user UUID), `roles` (array of role names), `iat`, `exp`. Access token short-lived, refresh token
stored hashed.

---

## Internal structure (current modules)

```
auth/   domain/ (entity, repository, service)  ports/inbound/auth_service.ts
        ports/outbound/ (auth_repository, mailer, auth_provider)
        application/ (register, login, forgot_password, verify_code, reset_password, google_login)
        adapters/inbound/http/ (routes, auth_controller, dto/)
        adapters/outbound/ (postgres/auth_repository, mailer/mailer, security/password)
users/  domain/, ports/, application/get_user.ts, adapters/inbound/http, adapters/outbound/postgres
```

---

## How to run it locally

Today (inside the backend process, port 3000):

```bash
psql -h localhost -p 5433 -U postgres -d traduce_senas -f backend/migrations/000_users.sql
cd backend && cp .env.example .env && npm install && npm run dev
curl -X POST http://localhost:3000/api/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"user@example.com","password":"Secret123!"}'
```

Target (own service):

```bash
docker compose up -d iam-service
curl http://localhost:3001/health
```

### Environment variables

| Variable | Purpose |
|----------|---------|
| `PORT` | HTTP port (`3001` target, `3000` today) |
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` | PostgreSQL connection (`DB_NAME=iam` target) |
| `JWT_SECRET` | Signing secret (HS256 today). Target: private key, see decisions |
| `EMAIL_USER`, `EMAIL_PASS` | Mail account used by the mailer today |
| `RABBITMQ_URL` | Broker URL (target) |

---

## Related documents

- [data-model.md](./data-model.md) — Tables of `identity`, `authz`, `audit`
- [events.md](./events.md) — Events published and consumed
- [decisions.md](./decisions.md) — Design decisions
- [runbook.md](./runbook.md) — Operation
- Data model source → `06-data/domains/01-identity.md`, `02-authorization.md`, `10-audit.md`
- API contract → `07-api/contracts/openapi/auth-service.yaml` (scaffold, to be realigned)
