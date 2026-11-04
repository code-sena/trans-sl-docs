# IAM Service

> Identity authority of Traduce Señas. Owns accounts, authentication, JWT issuance, roles and permissions. It is the
> authoritative owner of `User`, `Role` and `Permission`. Consent and the audit trail are in the target model only (see status below).

**Extraction status:** extracted. The code lives in `services/iam-service` (own process, own Dockerfile, port 3001, database `iam`).
The interface preferences moved to `profile-service`. See `09-microservices/service-catalog.md`.

---

## Responsibility

Answers "who is this person and what may they do". Issues the JWT that the gateway validates and that every other service
reads (`sub`, `email`, `roles`, `permissions`).

---

## Location in the architecture

| Field | Value |
|-------|-------|
| Number in catalog | 02 |
| Local port | 3001 (internal; not published by Docker Compose) |
| Bounded contexts | Identity & Access. Consent & Personal Data and audit are not implemented |
| DB engine | PostgreSQL, database `iam`, schema `public` |
| Data owned | See [data-model.md](./data-model.md) |
| Gateway paths | `/api/auth/**`, `/api/users/**`, `/api/iam/**` |
| Communicates with | RabbitMQ (`traduce.events`, publishes only). No synchronous calls to other services |
| Consumed by | api-gateway (public paths), the app; every service through the JWT it issues |
| Events | Publishes `iam.UserRegistered` and `iam.UserDeleted`; consumes none. See [events.md](./events.md) |
| Health | `GET /health` |

---

## Responsibilities (what this service DOES)

- Register users with consent: `acceptedTerms` must be `true` and `termsVersion` is stored in `users.terms_version`. Emails are trimmed and lower-cased, and unique
- Sign in with email and password, and with Google (ID token) or Facebook (access token). A social login with a new email creates an `ACTIVE` account without password
- Issue one JWT (HS256, signed with `JWT_SECRET`, lifetime `JWT_EXPIRES_IN`, 1 day by default) with the claims `sub`, `email`, `roles` and `permissions`. There is no refresh token
- Verify the email and recover the password with single-use codes sent by email (`user_tokens`)
- Manage roles and permissions (`USER`, `LINGUIST`, `ADMIN`). A permission reaches a user only through a role. Assigning and revoking roles needs `users.manage`
- Erase an account on request (`DELETE /api/users/me`, with the password or, for social accounts, the code sent by email) and publish `iam.UserDeleted` through the outbox
- Give profile-service the ids of the active administrators (`GET /api/users/admins`, permission `admins.read`, which only the service token carries)

## Out of scope (what it does NOT do)

- **Interface preferences, notifications and achievements:** `profile-service`
- **Interface notifications and administrator reports:** `profile-service`. iam sends only its own verification and reset codes, by email (`EMAIL_USER` / `EMAIL_PASS`)
- **Per-resource authorization:** each service checks `roles` and `permissions` from the token; iam only informs them
- **Routing and rate limiting:** `api-gateway`
- **Gesture samples and their files:** `recognition-service` (iam keeps no consent records for them)

---

## Routes (implemented)

All of them are under the gateway at `/api`. The full contract with the errors is in `07-api/contracts/openapi/iam-service.yaml`.

| Area | Method and path | Access |
|------|-----------------|--------|
| Auth | `POST /api/auth/register`, `login`, `verify-email`, `resend-verification`, `forgot-password`, `verify-code`, `reset-password`, `google`, `facebook` | Public (rate limited by the gateway) |
| Users | `GET /api/users/me`, `DELETE /api/users/me`, `POST /api/users/me/delete-code`, `POST /api/users/me/password` | Any valid JWT |
| Users | `GET /api/users/stats` | Permission `stats.read` |
| Users | `GET /api/users/admins` | Permission `admins.read` (service token only) |
| IAM | `GET /api/iam/me/access` | Any valid JWT |
| IAM | `GET /api/iam/roles`, `POST /api/iam/users/:userId/roles`, `DELETE /api/iam/users/:userId/roles/:roleName`, `DELETE /api/iam/roles/:roleId` | Permission `users.manage` |

Errors: `{ "success": false, "code", "message" }`.

### Planned, not implemented

Refresh and logout, a JWKS endpoint, `/api/roles` and `/api/consents`, user administration (`GET /api/users`, status changes) and the lockout ladder. They are listed in `07-api/README.md` ("Planned, not implemented").

---

## Internal structure

```
src/
  app.ts                      composition of the modules and the /health route
  auth/      application/ (register, login, forgot_password, reset_password, google_login,
             facebook_login, issue_verification, sign_session, ...)
             adapters/inbound/http (routes, auth_controller, dto/)
             adapters/outbound/ (postgres, mailer, security/password, google and facebook verifiers)
  users/     application/ (account, stats)
             adapters/inbound/http, adapters/outbound/postgres
  iam/       application/ (assign_role, revoke_role, list_roles, delete_role, ...)
             adapters/inbound/http
  shared/    outbox (relay_outbox, outbox_health, outbox repository)
```

Each module keeps the hexagonal layout of `ports/`, `application/` and `adapters/`.

---

## How to run it locally

```bash
# With Docker Compose (starts postgres-iam and rabbitmq first)
docker compose up -d iam-service

# Locally, only this service (port 3001)
npm run dev -w @traduce/iam-service
curl http://localhost:3001/health

# Sign-in through the gateway (the way a client calls it)
curl -X POST http://localhost:8080/api/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"user@example.com","password":"Secret123!"}'
```

### Environment variables

| Variable | Purpose |
|----------|---------|
| `PORT` | HTTP port (`3001`) |
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` | PostgreSQL connection (`DB_NAME=iam`; in Compose the host is `postgres-iam`) |
| `JWT_SECRET` | Signing secret (HS256), shared with the gateway and the other services |
| `JWT_EXPIRES_IN` | Token lifetime (default `1d`) |
| `EMAIL_USER`, `EMAIL_PASS` | Mail account used to send the codes |
| `GOOGLE_CLIENT_IDS` | Audiences accepted for Google ID tokens |
| `FACEBOOK_APP_ID`, `FACEBOOK_APP_SECRET` | Used to verify Facebook access tokens |
| `RABBITMQ_URL` | Broker URL. Empty means the in-memory bus (no events leave the process) |

---

## Related documents

- [data-model.md](./data-model.md) — Tables of the `iam` database
- [events.md](./events.md) — Events published and consumed
- [decisions.md](./decisions.md) — Design decisions
- [runbook.md](./runbook.md) — Operation
- Target data model → `06-data/domains/01-identity.md`, `02-authorization.md`, `10-audit.md`
- API contract → `07-api/contracts/openapi/iam-service.yaml`
