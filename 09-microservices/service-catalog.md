# Service Catalog

> The inventory of the components of Traduce Señas: one edge component (the API gateway) and five domain services.
> For the detail of each one go to `09-microservices/services/NN-name/`.

**Last updated:** 2026-10-16 · **Based on:** Backend `2993301` (`origin/develop`) · **Sources:** `services/*` and `packages/shared` of the Backend repository, `docker-compose.yml`, `MICROSERVICES_PLAN.md`, `02-domain/domain-map.md`, `06-data/domains/*`. Decision record: [ADR-004](../05-architecture/decisions/records/ADR-004-microservices-architecture.md).

---

## Architecture

**Traduce Señas is a microservices architecture.** Five domain services and one API gateway, each one with its own
Dockerfile, its own PostgreSQL database and its own SQL schema (`services/<name>/db/`). Every service is internally hexagonal (ports and adapters, see
`05-architecture/hexagonal-architecture.md`). The mobile / web app talks only to the gateway.

```text
        Mobile / Web app (Expo, React Native)
                      │  HTTP, REST, Bearer JWT
                      ▼
          ┌─────────────────────────────────────────────┐
          │ 01 api-gateway :8080                        │
          │ routing, optional JWT check, rate limit,    │
          │ CORS, GET /health                           │
          └──┬────────┬────────┬────────┬────────┬──────┘
             │        │        │        │        │
             ▼        ▼        ▼        ▼        ▼
        ┌────────┐┌────────┐┌────────┐┌────────┐┌────────┐
        │02 iam  ││03 recog││04 lexi-││05 ana- ││06 pro- │
        │  :3001 ││  :3002 ││con:3003││lytics  ││file    │
        │        ││        ││        ││  :3004 ││  :3005 │
        └───┬────┘└──┬───┬─┘└───┬────┘└───┬────┘└───┬────┘
            │        │   │      │         │         │
         PG iam   PG recog. │  PG lexicon PG analytics PG profile
                          MongoDB      + media (.glb/.png)
                      gesture_samples

   All services ◀──▶ RabbitMQ, topic exchange `traduce.events`
                     routing key `<service>.<Event>`
```

Gateway prefixes (`services/api-gateway/src/route_table.ts`): `/api/auth|users|iam` → 02, `/api/translations|recognition|sign-templates|samples` → 03,
`/api/lexicon` → 04, `/api/analytics` → 05, `/api/profile|notifications|achievements` → 06. The gateway forwards the path unchanged (no prefix stripping).

### Rules that apply to every service

- **Database per service.** No foreign keys across services. A reference to another service's data is a logical ID
  (for example `user_id`, an integer issued by `iam-service`; `profile-service` and `analytics-service` store it as text). PostgreSQL and MongoDB never share foreign keys.
  Only `recognition-service` uses MongoDB.
- **Synchronous communication:** REST through the gateway for client calls. Services do not call each other.
- **Asynchronous communication:** domain events over RabbitMQ (exchange `traduce.events`, type `topic`, routing key
  `<service>.<Event>`, for example `iam.UserRegistered`). Event payloads are typed in `packages/shared/src/events/contracts.ts`.
  Without `RABBITMQ_URL` the services use an in-memory bus.
- **Authentication:** `iam-service` issues the JWT (HS256, one day by default, claims `sub`, `email`, `roles`, `permissions`; no refresh token).
  All services share `JWT_SECRET` and verify the token themselves. The gateway rejects an invalid token if one is sent, but lets requests without a token through; each service decides which routes need a session.
  The `ADMIN` role is required for lexicon writes, samples and analytics reports; permissions such as `stats.read` and `models.manage` come from the token.
- **Health:** every service exposes `GET /health` → `{"status":"ok","service":"<name>"}`. The gateway's `GET /health` aggregates them (see `10-devops/local-setup.md`).
- **Error format:** `{"success": false, "code": "...", "message": "..."}`. The create, history and delete routes of `translations` and all `sign-templates` routes answer business errors with `400` and only `success` and `message` (no `code`).

### Naming of events

Event names follow `<service>.<Event>`; the domain names are in `02-domain/domain-events.md`. Only the events listed in the detail per service below exist in the code.

---

## Service registry

| # | Service | Folder in `09-microservices/services/` | Port | Gateway paths (`/api/...`) | Store | Extraction status |
|---|---------|----------------------------------------|------|----------------------------|-------|-------------------|
| 01 | `api-gateway` | `01-api-gateway/` | 8080 | all | none | Extracted |
| 02 | `iam-service` | `02-iam-service/` | 3001 | `/auth`, `/users`, `/iam` | PostgreSQL `iam` | Extracted |
| 03 | `recognition-service` | `03-recognition-service/` | 3002 | `/translations`, `/recognition/sign-templates` (alias `/sign-templates`), `/samples` | PostgreSQL `recognition` + MongoDB `gesture_samples` | Extracted |
| 04 | `lexicon-service` | `04-lexicon-service/` | 3003 | `/lexicon` (incl. `/lexicon/media`) | PostgreSQL `lexicon` + static media | Extracted |
| 05 | `analytics-service` | `05-analytics-service/` | 3004 | `/analytics` | PostgreSQL `analytics` | Extracted |
| 06 | `profile-service` | `06-profile-service/` | 3005 | `/profile`, `/notifications`, `/achievements` | PostgreSQL `profile` | Extracted |

**Current code status.** The Backend repository (`origin/develop`, `2993301`) is an npm workspaces monorepo (`packages/*`, `services/*`).
The six components above run as separate processes, each with its own `Dockerfile` and (except the gateway) its own database; `docker-compose.yml`
starts all of them plus five PostgreSQL instances, MongoDB and RabbitMQ. The old domain modules (`auth`, `users`, `translations`, `ia`, `lexicon`) were moved
into the services. Gaps that remain: the documented bounded contexts "Consent & Personal Data" and the audit trail have no code.
Account deletion erases the account in `iam-service` and writes `iam.UserDeleted` to an outbox in the same transaction; profile, recognition and analytics
erase or unlink their own data when the event arrives and keep the id in `erased_users` to refuse later writes. Every service has unit tests (see "Tests" in each card); there is no CI.

**Extraction status values:** Pending (no extraction work started) | In progress (code exists and is hexagonal, split not finished) | Extracted (own process, database and Dockerfile).

---

## Detail per service

### 01 — `api-gateway`

| Field | Value |
|-------|-------|
| **Responsibility** | Single entry point: routing by prefix, JWT check when a token is sent, rate limiting, CORS, aggregated health |
| **Bounded contexts** | None (edge component) |
| **Data owned** | None |
| **Port** | 8080 (the only port published to the host by `docker-compose.yml`) |
| **Routes** | `GET /health` → `{"status":"ok"|"degraded","services":{"iam":{"status":"up"|"down"},...}}`, always HTTP 200. Unknown path → 404 `NOT_FOUND`. Rate limit 300 requests per minute per client by default; `login`, `forgot-password`, `verify-code`, `reset-password`, `google` and `facebook` are limited to 10 per minute (`429 RATE_LIMITED`). `TRUST_PROXY` (`1` behind Caddy in production) makes the limits count per client IP |
| **Events** | Publishes none, consumes none |
| **Depends on** | The five domain services (`*_SERVICE_URL`), `JWT_SECRET`, `CORS_ORIGINS` |
| **Tests** | 1 file in `services/api-gateway/tests` (`routing.test.ts`) |
| **Extraction status** | Extracted |

### 02 — `iam-service`

| Field | Value |
|-------|-------|
| **Responsibility** | Accounts, registration with email verification, login and JWT issuance, password reset, account self-service, roles and permissions (RBAC) |
| **Bounded contexts** | Identity & Access (Consent & Personal Data is not implemented) |
| **Data owned** | PostgreSQL `iam`: `users`, `user_tokens`, `roles`, `permissions`, `user_roles`, `role_permissions` (plus the older `role`, `user_role`, `password_reset_token` created by `000_users.sql`) |
| **Store / port** | PostgreSQL `iam` / 3001 |
| **Routes (19)** | `/api/auth`: `POST register`, `login`, `forgot-password`, `verify-code`, `verify-email`, `resend-verification`, `reset-password`, `google`, `facebook`. `/api/users`: `GET stats`, `GET me`, `DELETE me`, `POST me/delete-code`, `POST me/password`. `/api/iam`: `GET me/access`, `GET roles`, `POST users/:userId/roles`, `DELETE users/:userId/roles/:roleName`, `DELETE roles/:roleId` |
| **Publishes** | `iam.UserRegistered`, `iam.UserDeleted` (through the `outbox_events` table and a relay) |
| **Consumes** | None |
| **Depends on** | PostgreSQL; RabbitMQ (optional); Gmail account (`EMAIL_USER` / `EMAIL_PASS`) to send verification and reset codes |
| **Tests** | 30 files in `services/iam-service/tests` |
| **Extraction status** | Extracted |

### 03 — `recognition-service` (core)

| Field | Value |
|-------|-------|
| **Responsibility** | Translation history, sign templates used by the on-device recognizer, gesture sample corpus (landmarks only, with consent data) |
| **Bounded contexts** | Recognition & Translation (core) |
| **Data owned** | PostgreSQL `recognition`: `translations`, `sign_templates`; MongoDB collection `gesture_samples` (in memory if `MONGO_URL` is empty) |
| **Store / port** | PostgreSQL `recognition` + MongoDB / 3002 |
| **Routes (10)** | `/api/translations`: `POST /`, `GET /stats`, `GET /me/stats`, `GET /history`, `DELETE /:id`. `/api/recognition/sign-templates` (alias `/api/sign-templates`, deprecated): `GET /` (public), `POST /`, `DELETE /:id` (permission `models.manage`). `/api/samples`: `POST /`, `GET /` (ADMIN) |
| **Publishes** | `recognition.TranslationProduced` |
| **Consumes** | `lexicon.SignPublished`, `lexicon.SignWithdrawn` (logged only; it does not update any catalog yet), `iam.UserDeleted` (deletes translations, unlinks samples) |
| **Depends on** | PostgreSQL, MongoDB (optional), RabbitMQ (optional) |
| **Tests** | 13 files in `services/recognition-service/tests` |
| **Extraction status** | Extracted |

Note: the recognition model itself runs in the client (MediaPipe + template matching); the service stores and serves the templates. Training scripts live in `services/recognition-service/src/ia/training/`.

### 04 — `lexicon-service`

| Field | Value |
|-------|-------|
| **Responsibility** | Catalog of LSC signs (letters, words, phrases), categories, texts per interface language (ES / EN), media |
| **Bounded contexts** | Learning & Lexicon |
| **Data owned** | PostgreSQL `lexicon`: `categories`, `sign_lexicon`, `sign_localizations`, `multimedia_resource` |
| **Store / port** | PostgreSQL `lexicon` + static media (`public/lexicon`, `.glb`, `.png`) / 3003 |
| **Routes (17 + media)** | Public: `GET /`, `GET /search`, `GET /alphabet`, `GET /categories`, `GET /:code`, `GET /media/*`. ADMIN: `POST /`, `PATCH /:code`, `DELETE /:code` (deactivates), `POST /:code/publish`, `PUT /:code/localizations/:lang`, `POST /:code/resources`, `DELETE /:code/resources/:resourceId`, `POST /categories`, `PATCH /categories/:id`, `DELETE /categories/:id`, `GET /admin/signs`, `GET /admin/signs/:code` |
| **Publishes** | `lexicon.SignPublished`, `lexicon.SignWithdrawn` |
| **Consumes** | None |
| **Depends on** | PostgreSQL, RabbitMQ (optional); the JWT `ADMIN` role for writes |
| **Tests** | 5 files in `services/lexicon-service/tests` |
| **Extraction status** | Extracted. `created_by` / `updated_by` keep the ids of deleted users on purpose (authorship); the service does not consume `iam.UserDeleted` |

### 05 — `analytics-service`

| Field | Value |
|-------|-------|
| **Responsibility** | Records how the app is used and serves aggregated statistics to the administrator |
| **Bounded contexts** | Usage Analytics |
| **Data owned** | PostgreSQL `analytics`: `usage_event` |
| **Store / port** | PostgreSQL `analytics` / 3004 |
| **Routes (5)** | `POST /api/analytics/events` (any logged-in user, answers 202). ADMIN: `GET /summary`, `GET /top-signs`, `GET /daily`. Permission `stats.read`: `GET /reports/sections`. Reports need `from` and `to` (`YYYY-MM-DD`) |
| **Publishes** | None |
| **Consumes** | `recognition.TranslationProduced`, `iam.UserRegistered`, `iam.UserDeleted` (unlinks the user's usage events) (one queue per event) |
| **Depends on** | PostgreSQL, RabbitMQ (optional) |
| **Tests** | 6 files in `services/analytics-service/tests` |
| **Extraction status** | Extracted |

### 06 — `profile-service`

| Field | Value |
|-------|-------|
| **Responsibility** | Profile copy of the account, interface preferences, in-app notifications and achievements |
| **Bounded contexts** | Profile & Preferences; Notifications; Gamification (provisional, RF8 not approved) |
| **Data owned** | PostgreSQL `profile`: `user_profiles`, `user_preferences`, `notification_types`, `notifications`, `achievements`, `user_achievements`, `challenges`, `user_challenges`, `challenge_rewards`, `processed_events` |
| **Store / port** | PostgreSQL `profile` / 3005 |
| **Routes (10)** | `GET /api/profile/me`, `PATCH /api/profile/me`, `GET /api/profile/preferences`, `PATCH /api/profile/preferences`, `GET /api/profile/challenges/today`, `GET /api/profile/challenges/rewards/summary`, `GET /api/notifications`, `PATCH /api/notifications/:id/read`, `GET /api/achievements`, `POST /api/achievements/activity` (daily challenges: [ADR-009](../05-architecture/decisions/records/ADR-009-daily-challenges.md), [ADR-010](../05-architecture/decisions/records/ADR-010-challenge-points-medals.md)) |
| **Publishes** | `profile.AchievementUnlocked`, `profile.PreferencesChanged` (no consumer yet) |
| **Consumes** | `iam.UserRegistered` (creates profile and default preferences), `iam.UserDeleted` (erases profile, preferences, notifications and progress), `recognition.TranslationProduced` (advances achievements) |
| **Depends on** | PostgreSQL, RabbitMQ (optional). Gmail SMTP for administrator reports sent by email ([ADR-007](../05-architecture/decisions/records/ADR-007-email-notifications.md)); no push provider |
| **Tests** | 11 files in `services/profile-service/tests` |
| **Extraction status** | Extracted |

Shared code (`packages/shared`) has 5 test files in `packages/shared/tests`.

---

## Dependency map

```text
 app ──▶ api-gateway ──▶ iam | recognition | lexicon | analytics | profile        (sync REST)

 iam         ──UserRegistered──────────▶ profile, analytics
 recognition ──TranslationProduced─────▶ profile, analytics
 lexicon     ──SignPublished/Withdrawn─▶ recognition (log only)
 profile     ──AchievementUnlocked, PreferencesChanged──▶ (no consumer)
```

No service calls another one synchronously. The graph of events has no cycle.

## Data ownership

| Entity / data | Owner service | Others that hold a reference | How they stay in sync |
|---------------|---------------|------------------------------|-----------------------|
| User (`users`) | iam | All services keep `user_id` only (recognition, lexicon: integer; profile, analytics: text) | `UserRegistered`; deletion is not propagated yet |
| Role, permission, assignment | iam | Every service reads `roles` and `permissions` from the JWT | Token claims (a token keeps its claims until it expires) |
| Translation, sign template, gesture sample | recognition | analytics (counters), profile (achievements) | `TranslationProduced` |
| Sign, category, localization, media | lexicon | recognition keeps `sign_lexicon.code` values in samples | `SignPublished`, `SignWithdrawn` |
| Profile, preferences, notification, achievement | profile | none | `AchievementUnlocked`, `PreferencesChanged` (no consumer) |
| Usage event | analytics | None | Consumed events and `POST /api/analytics/events` |

## Differences between the documented data model and the code

| Aspect | Code today (`2993301`) | Documented (`06-data/`, `02-domain/`) |
|--------|------------------------|---------------------------------------|
| Primary keys | `SERIAL` integers in iam, recognition and lexicon; UUID primary keys in profile; `BIGSERIAL` in analytics | UUID everywhere |
| JWT | HS256 with shared secret, claims `sub`, `email`, `roles`, `permissions`, no refresh token | Access + refresh token, validated at the gateway |
| Events | 7 events (see dependency map) | Full catalog in `02-domain/domain-events.md` |
| Consent, audit, devices, push notifications | Not implemented | Described as part of iam and profile |
| Tables | See "Data owned" per service | `06-data/traduce_senas.dbml` (single reference model) |

## How to add a new service

1. Define the bounded context in `02-domain/domain-map.md` and the tables in `06-data/domains/`.
2. Copy `09-microservices/_template/service` to `09-microservices/services/NN-<name>` and fill it in.
3. Create the service under `services/<name>` in the Backend repository with its own `Dockerfile`, `GET /health`, hexagonal structure and SQL under `db/`; add its database and variables to `docker-compose.yml` and `.env.example`.
4. Add its prefixes to `services/api-gateway/src/route_table.ts` and its events to `packages/shared/src/events/contracts.ts`.
5. Add the service to this catalog, write its OpenAPI contract in `07-api/contracts/openapi/` and record an ADR in `05-architecture/decisions/records/`.

---

## Correlations

- Architecture and patterns → `05-architecture/` (decision: ADR-004)
- Domain boundaries → `02-domain/domain-map.md`
- Events → `02-domain/domain-events.md`
- Data model → `06-data/`
- API contracts → `07-api/contracts/openapi/` (`api-gateway.yaml` plus one file per service)
- Local setup → `10-devops/local-setup.md`
- Template for a new service → `09-microservices/_template/service/`
