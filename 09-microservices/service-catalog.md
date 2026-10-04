# Service Catalog

> The inventory of the components of Traduce Señas: one edge component (the API gateway) and five domain services.
> For the detail of each one go to `09-microservices/services/NN-name/`.

**Last updated:** 2026-10-04 · **Sources:** `02-domain/domain-map.md`, `02-domain/domain-events.md`, `06-data/domains/*`, `05-architecture/`, `backend/src/domains/*`

---

## Architecture

**Traduce Señas is a microservices architecture.** Five domain services and one API gateway, each one with its own
Dockerfile, its own database and its own migrations. Every service is internally hexagonal (ports and adapters, see
`05-architecture/hexagonal-architecture.md`). The mobile / web app talks only to the gateway.

```
        Mobile / Web app (Expo, React Native)
                      │  HTTPS, REST, Bearer JWT
                      ▼
          ┌─────────────────────────────────────────────┐
          │ 01 api-gateway :8080                        │
          │ routing, JWT validation, rate limit, CORS   │
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
                     routing key `<service>.<event>`
```

Gateway paths: `/api/auth|users|roles|consents` → 02, `/api/translations|recognition|models|samples` → 03,
`/api/lexicon` → 04, `/api/analytics` → 05, `/api/profile|notifications|achievements` → 06.

### Rules that apply to every service

- **Database per service.** No foreign keys across services. A reference to another service's data is a logical ID
  (for example `user_id`, a UUID issued by `iam-service`). PostgreSQL and MongoDB never share foreign keys.
- **Synchronous communication:** REST through the gateway for client calls.
- **Asynchronous communication:** domain events over RabbitMQ (exchange `traduce.events`, type `topic`, routing key
  `<service>.<event>`, for example `iam.UserRegistered`). The events come from `02-domain/domain-events.md`.
- **Authentication:** `iam-service` issues the JWT (access and refresh token). The gateway validates the signature.
  Services read `sub` and `roles` from the forwarded token. The `ADMIN` role is required for lexicon writes and model training.
- **Health:** every service exposes `GET /health`.

### Naming of events

Event names follow `02-domain/domain-events.md`.

---

## Service registry

| # | Service | Folder in `09-microservices/services/` | Port | Gateway paths (`/api/...`) | Store | Extraction status |
|---|---------|----------------------------------------|------|----------------------------|-------|-------------------|
| 01 | `api-gateway` | `01-api-gateway/` | 8080 | all | none | Pending (no code yet) |
| 02 | `iam-service` | `02-iam-service/` | 3001 | `/auth`, `/users`, `/roles`, `/consents` | PostgreSQL `iam` | Pending. Code exists as backend modules `auth` and `users` |
| 03 | `recognition-service` | `03-recognition-service/` | 3002 | `/translations`, `/recognition`, `/models`, `/samples` | PostgreSQL `recognition` + MongoDB `gesture_samples` | Pending. Code exists as backend modules `translations` and `ia` |
| 04 | `lexicon-service` | `04-lexicon-service/` | 3003 | `/lexicon` (incl. `/lexicon/media`) | PostgreSQL `lexicon` + static media | In progress. Module `lexicon` implemented and tested, not yet extracted |
| 05 | `analytics-service` | `05-analytics-service/` | 3004 | `/analytics` | PostgreSQL `analytics` | Pending (no code yet) |
| 06 | `profile-service` | `06-profile-service/` | 3005 | `/profile`, `/notifications`, `/achievements` | PostgreSQL `profile` | Pending. No code (`GET /api/users/me` of module `users` goes to iam) |

**Current code status.** The backend repository today holds the domain modules `auth`, `users`, `translations`, `ia` and
`lexicon` under `backend/src/domains/`, each one already hexagonal. They are being split into the services above:
`auth` + `users` into iam and profile, `translations` + `ia` into recognition, `lexicon` into lexicon-service. Until each
extraction is done, the module runs in the backend process; the per-service documents describe the target service and mark
what exists today.

**Extraction status values:** Pending (no extraction work started) | In progress (code exists and is hexagonal, split not finished) | Extracted (own process, database and Dockerfile).

---

## Detail per service

### 01 — `api-gateway`

| Field | Value |
|-------|-------|
| **Responsibility** | Single entry point: routing, JWT signature validation, rate limiting, CORS |
| **Bounded contexts** | None (edge component) |
| **Data owned** | None |
| **Port** | 8080 |
| **Events** | Publishes none, consumes none |
| **Depends on** | The five domain services (HTTP upstreams) and the public key / secret to verify the JWT |

### 02 — `iam-service`

| Field | Value |
|-------|-------|
| **Responsibility** | Accounts, authentication, JWT issuance, roles and permissions, consent and personal data, audit trail |
| **Bounded contexts** | Identity & Access; Consent & Personal Data; audit (cross-cutting) |
| **Data owned** | `06-data/domains/01-identity`, `02-authorization`, `10-audit` |
| **Store / port** | PostgreSQL `iam` / 3001 |
| **Publishes** | `UserRegistered`, `UserSignedIn`, `ExternalProviderLinked`, `EmailVerified`, `PasswordResetRequested`, `PasswordChanged`, `PasswordPolicyChanged`, `AccountLocked`, `AccountBlocked`, `RoleAssigned`, `RoleRevoked`, `AccountDeleted`, `ConsentGranted`, `ConsentRevoked`, `AccountDeletionRequested` |
| **Consumes** | Audit-relevant events of all services (`SignPublished`, `SignWithdrawn`, `RecognitionModelTrained`, `RecognitionModelPublished`, `GestureSampleCaptured`, `CaptureSessionDiscarded`, `TrainingSampleAnonymized`) |
| **Depends on** | RabbitMQ. No other service is called synchronously |
| **Extraction status** | Pending. Modules `auth` and `users` today (HS256 JWT, 1-day expiry, no refresh token, integer ids) |

### 03 — `recognition-service` (core)

| Field | Value |
|-------|-------|
| **Responsibility** | Translation of signs to text, translation history, recognition model registry and training, gesture sample corpus |
| **Bounded contexts** | Recognition & Translation (core) and AI / model training |
| **Data owned** | `06-data/domains/05-translation`, `06-ai` |
| **Store / port** | PostgreSQL `recognition` (`translations`, `translation_signs`, `ai_models`) + MongoDB `gesture_samples` / 3002 |
| **Publishes** | `TranslationSessionStarted`, `TranslationProduced`, `RecognitionFailed`, `TranslationSessionEnded`, `TranslationSessionInterrupted`, `TranslationDeleted`, `RecognitionModelTrained`, `RecognitionModelPublished`, `GestureSampleCaptured`, `GestureSampleValidated`, `CaptureSessionDiscarded`, `TrainingSampleAnonymized` |
| **Consumes** | `iam.ConsentGranted`, `iam.ConsentRevoked`, `iam.AccountDeletionRequested`, `lexicon.SignPublished`, `lexicon.SignWithdrawn` |
| **Depends on** | RabbitMQ, MongoDB. Receives sign codes from lexicon through events (refreshes its sign catalog) |
| **Extraction status** | Pending. Modules `translations` (save, list, soft-delete) and `ia` (`sign_templates`) today. Ports `ai_service` and `gesture_repository` are declared without adapter; MongoDB is not used yet |

### 04 — `lexicon-service`

| Field | Value |
|-------|-------|
| **Responsibility** | Catalog of LSC signs (letters, words, phrases), categories, texts per language, media |
| **Bounded contexts** | Learning & Lexicon |
| **Data owned** | `06-data/domains/04-lexicon`: `categories`, `sign_lexicon`, `sign_localizations`, `multimedia_resource` |
| **Store / port** | PostgreSQL `lexicon` + static media (`.glb`, `.png`) / 3003 |
| **Publishes** | `SignPublished`, `SignWithdrawn`, `SignViewed`, `LexiconSearchPerformed` (none emitted by the code yet) |
| **Consumes** | None |
| **Depends on** | RabbitMQ; the forwarded JWT (`roles`) for ADMIN writes |
| **Extraction status** | In progress. Module `lexicon`: 17 routes, unit tests, hexagonal. Still reads roles from the shared `user_role` table and links `created_by` to `users` |

### 05 — `analytics-service`

| Field | Value |
|-------|-------|
| **Responsibility** | Records how the app is used and serves aggregated statistics to the administrator |
| **Bounded contexts** | Usage Analytics |
| **Data owned** | `06-data/domains/08-usage`: `usage_events`, `usage_daily_stats`, `session_daily_stats` |
| **Store / port** | PostgreSQL `analytics` / 3004 |
| **Publishes** | None |
| **Consumes** | Events of iam, recognition, lexicon and profile (see its `events.md`) |
| **Depends on** | RabbitMQ; the forwarded JWT (`stats.read`, ADMIN only) |
| **Extraction status** | Pending. No code |

### 06 — `profile-service`

| Field | Value |
|-------|-------|
| **Responsibility** | Interface preferences, notifications (devices, delivery) and achievements |
| **Bounded contexts** | Profile & Preferences; Notifications; Gamification (provisional, RF8 not approved) |
| **Data owned** | `06-data/domains/03-profile`, `07-notification`, `09-gamification` |
| **Store / port** | PostgreSQL `profile` / 3005 |
| **Publishes** | `PreferencesChanged`, `DeviceRegistered`, `DeviceRevoked`, `NotificationScheduled`, `NotificationDelivered`, `NotificationDeliveryFailed`, `NotificationRead`, `NotificationTypeWithdrawn`, `AchievementUnlocked` (pending RF8) |
| **Consumes** | `iam.UserRegistered`, `iam.AccountLocked`, `iam.AccountBlocked`, `iam.PasswordChanged`, `iam.PasswordResetRequested`, `iam.AccountDeletionRequested`, `iam.ConsentRevoked`, `recognition.TranslationProduced`, `recognition.RecognitionFailed`, `recognition.TranslationSessionInterrupted` |
| **Depends on** | RabbitMQ; push provider (FCM / APNs) and mail provider |
| **Extraction status** | Pending. No code |

---

## Dependency map

```
 app ──▶ api-gateway ──▶ iam | recognition | lexicon | analytics | profile        (sync REST)

 iam         ──events──▶ profile, analytics, recognition
 recognition ──events──▶ analytics, profile, iam (audit)
 lexicon     ──events──▶ recognition, analytics, iam (audit)
 profile     ──events──▶ analytics
```

No service calls another one synchronously. The graph of events has no cycle that blocks a service: `recognition` and `profile`
both react to events of the other, but only for notifications and counters, never to complete a request.

## Data ownership

| Entity / data | Owner service | Others that hold a reference | How they stay in sync |
|---------------|---------------|------------------------------|-----------------------|
| User (`users`) | iam | All services keep `user_id` (UUID) only | `UserRegistered`, `AccountDeleted`, `AccountDeletionRequested` |
| Role, permission, assignment | iam | Every service reads `roles` from the JWT | Token claims; `RoleAssigned` / `RoleRevoked` for audit |
| Audit and error logs | iam | None | Events from every service |
| Translation, model, sample | recognition | analytics (counters), profile (achievements) | `TranslationProduced` and friends |
| Sign, category, localization, media | lexicon | recognition keeps the `sign_lexicon.code` values | `SignPublished`, `SignWithdrawn` |
| Preferences, notification, device, achievement | profile | analytics (counters) | `PreferencesChanged`, `Notification*`, `AchievementUnlocked` |
| Usage event and daily stats | analytics | None | Consumed events |

## Differences between the target data model and the code today

| Aspect | Code today | Target (`06-data/`, this catalog) |
|--------|------------|-----------------------------------|
| Deployment | One backend process, one router per module | Six independent services |
| Database | One PostgreSQL database `traduce_senas`, schema `public` | One database per service (+ MongoDB for samples) |
| Primary keys | `SERIAL` integers | UUID |
| Cross-module links | Foreign keys (`created_by`, `user_id`) and direct function calls | Logical IDs and events |
| JWT | HS256, 1-day expiry, no refresh token, claims `user_id` and `email`, roles read from `user_role` per request | Access + refresh token, claims `sub` and `roles`, validated at the gateway |
| Events | None | RabbitMQ `traduce.events` |

## How to add a new service

1. Define the bounded context in `02-domain/domain-map.md` and the tables in `06-data/domains/`.
2. Copy `09-microservices/_template/service` to `09-microservices/services/NN-<name>` and fill it in.
3. Create the service with its own `Dockerfile`, `GET /health`, hexagonal structure and migrations.
4. Add its routes to the gateway and its events to its `events.md`.
5. Add the service to this catalog and record an ADR in `05-architecture/decisions/records/`.

---

## Correlations

- Architecture and patterns → `05-architecture/`
- Domain boundaries → `02-domain/domain-map.md`
- Events → `02-domain/domain-events.md`
- Data model → `06-data/`
- API contracts → `07-api/contracts/openapi/` (the existing `api-gateway.yaml` and `auth-service.yaml` are scaffold examples; they have to be realigned to the paths above)
- Template for a new service → `09-microservices/_template/service/`
