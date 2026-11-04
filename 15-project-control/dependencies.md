# External Dependencies

> TraduceSeñas depends on third-party services and APIs. This document tracks what we depend on,
> what can go wrong, and contingency plans.
> Status values were checked against the repositories on 2026-11-04. Production state is not verifiable from the repositories and is marked as such.

---

## Critical dependencies

### Google OAuth 2.0 (Google Sign-In)

| Field | Value |
|-------|-------|
| **Dependency** | Google Identity Services |
| **Type** | External SaaS (Google Cloud) |
| **Required for** | Social login (FR-001); hearing users authenticate with existing Google accounts |
| **External owner** | Google Cloud (Alphabet) |
| **SLA** | 99.9% uptime (Google's public SLA) |
| **Fallback** | Email + password login (already implemented) |
| **Status** | Integrated, not blocking |
| **Notes** | Client IDs are read from `GOOGLE_CLIENT_IDS` (docker-compose.yml). If empty, `POST /api/auth/google` answers 503. The token is verified at login time. No refresh tokens are issued and no provider data is synced. |

---

### Facebook Login (OAuth 2.0)

| Field | Value |
|-------|-------|
| **Dependency** | Meta (Facebook) Login SDK |
| **Type** | External SaaS |
| **Required for** | Social login (FR-001); alternative to Google |
| **External owner** | Meta Platforms, Inc. |
| **SLA** | Not publicly stated (typical: 99%+) |
| **Fallback** | Google + email/password |
| **Status** | Integrated, not blocking |
| **Notes** | `FACEBOOK_APP_ID` and `FACEBOOK_APP_SECRET` are read by iam-service. If empty, `POST /api/auth/facebook` answers 503. The app must be registered in the Meta developer dashboard. |

---

### Firebase Cloud Messaging (FCM) — retired

| Field | Value |
|-------|-------|
| **Dependency** | Google Cloud Firebase Messaging |
| **Type** | External SaaS (Google Cloud) |
| **Required for** | Nothing. It was planned for push notifications (FR-004). Push was retired: notifications that must reach a user outside the app are sent by email ([ADR-007](../05-architecture/decisions/records/ADR-007-email-notifications.md)) |
| **External owner** | Google Cloud |
| **SLA** | Not applicable |
| **Fallback** | Not needed |
| **Status** | Not used. There is no Firebase project and no FCM code in the repositories |
| **Notes** | The client lists `expo-notifications` in `package.json` and `app.json`, but the source does not call it. No push token is stored. |

---

### SMTP email (Gmail)

| Field | Value |
|-------|-------|
| **Dependency** | Gmail SMTP, through a team Gmail account |
| **Type** | External SaaS (Google) |
| **Required for** | Verification and password-reset codes (iam-service); administrator summaries and notification emails (profile-service) |
| **External owner** | Google (the account is operated by the team) |
| **SLA** | Not documented |
| **Fallback** | None in code. Without credentials no code is emailed and the registration response shows `verification_email_sent: false` |
| **Status** | Configured in `docker-compose.yml` (`EMAIL_USER`, `EMAIL_PASS`). Whether the production values are set is not verifiable from the repositories |
| **Notes** | Gmail limits how many messages can be sent per day (see ADR-007). Credentials are read from `.env`. |

---

### TensorFlow.js

| Field | Value |
|-------|-------|
| **Dependency** | TensorFlow.js (runs in the client, on the device) |
| **Type** | Open-source library (Apache 2.0) |
| **Required for** | Sign language recognition engine (FR-003) |
| **External owner** | Google / TensorFlow community |
| **SLA** | No SLA; community-maintained. Updates every quarter. |
| **Fallback** | Switch to ONNX Runtime (Microsoft, more stable) — requires model conversion |
| **Status** | Declared as `^4.22.0` in the frontend `package.json` (a range, not a pinned version). Inference runs on the device: decision made, see Q-001 in open-questions.md |
| **Notes** | The model is the team's own, trained on the LSC-54 dataset. Inference runs on the device, so the server needs no GPU. |
| **Risk** | Version update may break compatibility with React Native. Model may not run on target device (4 GB RAM). |

---

### PostgreSQL (5 instances, one per service)

| Field | Value |
|-------|-------|
| **Dependency** | PostgreSQL 16 (`postgres:16-alpine` in docker-compose.yml), five instances (iam, recognition, lexicon, analytics, profile) |
| **Type** | Self-hosted (Docker containers on the server) |
| **Required for** | Structured data per service (users, translations, lexicon, analytics events, profile data) |
| **External owner** | SENA IT / Infrastructure team |
| **SLA** | SENA-defined (not formally documented) |
| **Fallback** | Restore from daily backup per database (RTO: 45 min, RPO: 24 hours) |
| **Status** | Defined in `docker-compose.yml`. Production state not verifiable from the repositories |
| **Notes** | Each service reads its own connection settings (`IAM_DB_*` and so on, or `DB_*` inside compose). The `pg` pool uses library defaults: no pool size is set in `packages/shared/src/database/postgres.ts`. Migrations are applied by hand (see `10-devops/local-setup.md`). |
| **Risk** | Connection pool exhaustion per service (one slow service does not block others). No read replicas; all reads hit the primary. Restore complexity: 5 databases must be restored in order (iam first). |

---

### MongoDB

| Field | Value |
|-------|-------|
| **Dependency** | MongoDB 7 (`mongo:7` in docker-compose.yml) |
| **Type** | Self-hosted (Docker container on the server) |
| **Required for** | Gesture samples (collection `gesture_samples`, recognition-service only) |
| **External owner** | SENA IT / Infrastructure team |
| **SLA** | SENA-defined |
| **Fallback** | Restore from daily backup (RTO: 2 hours, RPO: 24 hours) |
| **Status** | Defined in `docker-compose.yml`. Production state not verifiable from the repositories |
| **Notes** | `MONGO_URL` is built by docker-compose.yml from `MONGO_ROOT_USER` and `MONGO_ROOT_PASSWORD`. Only recognition-service uses it. Single node, no sharding. |
| **Risk** | Grows independently of PostgreSQL; no FK constraints to catch orphaned records. If MongoDB is down, recognition-service cannot persist samples. |

---

### RabbitMQ (Message Broker)

| Field | Value |
|-------|-------|
| **Dependency** | RabbitMQ 3 (`rabbitmq:3-management-alpine` in docker-compose.yml) |
| **Type** | Self-hosted (Docker container on the server) |
| **Required for** | Async domain events: `iam.UserRegistered` → analytics-service; `iam.UserDeleted` → analytics, profile and recognition services (erasure); `recognition.TranslationProduced` → analytics-service; `lexicon.SignPublished` → recognition-service |
| **External owner** | SENA IT / Infrastructure team |
| **SLA** | SENA-defined |
| **Fallback** | (1) If the broker is down, synchronous calls still work (gateway and services). Other events published meanwhile are lost, because publication is best-effort. `iam.UserDeleted` is an exception: it stays in the iam outbox and is retried. (2) Restore the message queues from backup. |
| **Status** | Defined in `docker-compose.yml`. Production state not verifiable from the repositories |
| **Notes** | `RABBITMQ_URL` is built by compose from `RABBITMQ_USER` and `RABBITMQ_PASSWORD`. Topic exchange `traduce.events`; rejected messages go to the `traduce.events.dead` exchange and `<queue>.dead` queues. The management panel is bound to `127.0.0.1:15672`. |
| **Risk** | If broker is down, events are lost (unless persistent queue + backup restore). Message queue can grow unbounded if consumer is slow or down. Monitor queue depth; alert if > 1000 messages for > 10 min (planned, not configured). |

---

## Non-critical dependencies (nice-to-have, fallback exists)

### React Native and Expo (client framework)

| Field | Value |
|-------|-------|
| **Dependency** | React Native 0.86 + Expo 57 (react-native-web for the web build) |
| **Type** | Open-source library (MIT) |
| **Required for** | Client app (Android APK and web) |
| **External owner** | Meta / Expo community |
| **Fallback** | Switch to Flutter (Google) — requires rewrite of UI |
| **Status** | In use; version pinned in `package.json` |

---

### MediaPipe

| Field | Value |
|-------|-------|
| **Dependency** | MediaPipe Tasks Vision (`@mediapipe/tasks-vision` 0.10.14) |
| **Type** | Open-source library (Apache 2.0) |
| **Required for** | Hand and pose landmarks before the TensorFlow.js inference |
| **External owner** | Google (MediaPipe) |
| **Fallback** | Skip hand detection; inference on full video frame (slower, less accurate) |
| **Status** | Integrated in the client's sign recognition pipeline. OpenCV is not used. |

---

## Dependency status summary

| Dependency | Status | Block? | Owner | Notes |
|------------|--------|--------|-------|-------|
| Google OAuth | Ready | No | Google Cloud | Fallback: email/password |
| Facebook OAuth | Ready | No | Meta | Fallback: Google |
| Firebase FCM | Retired (not used) | No | — | Push retired, see ADR-007 |
| SMTP (Gmail) | Configured (optional) | No | Team | Without credentials no code is emailed |
| TensorFlow.js | Ready | Yes | TensorFlow team | On-device inference (Q-001 resolved) |
| PostgreSQL (x5) | Defined in compose | Yes | SENA IT | One per service; no read replicas |
| MongoDB | Defined in compose | Yes | SENA IT | recognition-service only; grows independently |
| RabbitMQ | Defined in compose | Yes | SENA IT | Message broker for async events; critical for microservices |
| React Native / Expo | Ready | No | Meta / Expo | Can switch to Flutter if needed |
| MediaPipe | Ready | No | Google | Fallback: raw video |

---

## Coordination points with SENA

1. **SMTP credentials:** `EMAIL_USER` and `EMAIL_PASS` must be set in the server's `.env`. Without them, verification and password-reset codes are not emailed.
2. **RabbitMQ setup:** broker must be running; test connection before first microservice deploy
3. **PostgreSQL x5 databases:** one per service (iam, recognition, lexicon, analytics, profile); backups must include all 5
4. **MongoDB backup schedule:** daily automated backup; quarterly restore drill scheduled for 2026-11-15
5. **Backup restore procedure:** restore order is critical: (1) PostgreSQL iam, (2) other PostgreSQL dbs, (3) MongoDB, (4) RabbitMQ queue. Test quarterly.
6. **Server capacity planning:** 5 services + RabbitMQ broker + 5 databases + MongoDB = higher resource usage than monolith. Monitor: CPU, memory, disk I/O, network (inter-service calls + event broker).

---

## Correlations

- Risk register (dependency failures) → `15-project-control/risks.md`
- Open questions (inference location decision) → `15-project-control/open-questions.md`
- Microservices architecture spec → `09-microservices/service-catalog.md`
- Deployment plan → `05-architecture/deployment.md`
- Incident response per service → `09-microservices/services/<service>/runbook.md`
