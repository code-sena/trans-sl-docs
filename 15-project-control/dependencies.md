# External Dependencies

> TraduceSeñas depends on third-party services and APIs. This document tracks what we depend on,
> what can go wrong, and contingency plans.

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
| **Notes** | OAuth client ID and secret in .env; refreshed tokens stored in PostgreSQL. No data sync; we only verify the token at login time. |

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
| **Notes** | OAuth client ID/secret in .env. Facebook API v18+. App must be registered in Meta App Dashboard. |

---

### Firebase Cloud Messaging (FCM)

| Field | Value |
|-------|-------|
| **Dependency** | Google Cloud Firebase Messaging |
| **Type** | External SaaS (Google Cloud) |
| **Required for** | Push notifications (FR-004). Alternative to polling for app resume notifications. |
| **External owner** | Google Cloud |
| **SLA** | 99.9% uptime |
| **Fallback** | HTTP polling on app resume (less battery-efficient, already in scope as fallback) |
| **Status** | Integrated, not blocking for MVP |
| **Notes** | Firebase project ID in .env. Push tokens stored in PostgreSQL.push_tokens (revocable). |

---

### SMTP Email Provider (password recovery)

| Field | Value |
|-------|-------|
| **Dependency** | SMTP server (SendGrid, AWS SES, or self-hosted) |
| **Type** | External SaaS or self-hosted |
| **Required for** | Password recovery email (FR-001) |
| **External owner** | SendGrid or AWS SES or local IT |
| **SLA** | SendGrid: 99.9%; SES: 99.9% |
| **Fallback** | Manual reset by admin (no automated email) |
| **Status** | TBD; SENA will provide SMTP credentials |
| **Notes** | Credentials in .env. Email templates in src/domains/auth/adapters/templates/. |

---

### TensorFlow.js / TensorFlow Lite

| Field | Value |
|-------|-------|
| **Dependency** | TensorFlow.js (on-device) or TensorFlow Lite (mobile/server) |
| **Type** | Open-source library (Apache 2.0) |
| **Required for** | Sign language recognition engine (FR-003) |
| **External owner** | Google / TensorFlow community |
| **SLA** | No SLA; community-maintained. Updates every quarter. |
| **Fallback** | Switch to ONNX Runtime (Microsoft, more stable) — requires model conversion |
| **Status** | Pinned version: 4.10.0 (TensorFlow.js); model location TBD (on-device vs server) |
| **Notes** | Model file (25 MB) stored in public/models/lsc-54.tfjs or uploaded to cloud storage. Inference decision (Q-001 in open-questions.md) is NOT YET MADE. |
| **Risk** | Version update may break compatibility with React Native. Model may not run on target device (4 GB RAM). |

---

### PostgreSQL (5 instances, one per service)

| Field | Value |
|-------|-------|
| **Dependency** | PostgreSQL 15+ relational database x5 (iam, recognition, lexicon, analytics, profile) |
| **Type** | Self-hosted (on SENA's shared server) |
| **Required for** | Structured data per service (users, translations, lexicon, audit logs, analytics events) |
| **External owner** | SENA IT / Infrastructure team |
| **SLA** | SENA-defined (not formally documented) |
| **Fallback** | Restore from daily backup per database (RTO: 45 min, RPO: 24 hours) |
| **Status** | Running in production (5 databases) |
| **Notes** | Each service has its own connection string in .env (IAM_DB_*, RECOGNITION_DB_*, etc.). Pooled with pg-pool (min: 2, max: 30 connections per service). Migrations per service run on deploy. |
| **Risk** | Connection pool exhaustion per service (one slow service does not block others). No read replicas; all reads hit the primary. Restore complexity: 5 databases must be restored in order (iam first). |

---

### MongoDB

| Field | Value |
|-------|-------|
| **Dependency** | MongoDB 6+ document database |
| **Type** | Self-hosted (on SENA's shared server) |
| **Required for** | AI data: gesture samples, model versions, training logs (recognition-service only) |
| **External owner** | SENA IT / Infrastructure team |
| **SLA** | SENA-defined |
| **Fallback** | Restore from daily backup (RTO: 2 hours, RPO: 24 hours) |
| **Status** | Running in production |
| **Notes** | Connection string in .env (MONGODB_URI). Only recognition-service uses it. No sharding; single replica set. Collections: gesture_samples, ai_models, training_logs. |
| **Risk** | Grows independently of PostgreSQL; no FK constraints to catch orphaned records. If MongoDB is down, recognition-service cannot persist samples but can still serve cached models. |

---

### RabbitMQ (Message Broker)

| Field | Value |
|-------|-------|
| **Dependency** | RabbitMQ 3.10+ message broker |
| **Type** | Self-hosted (on SENA's shared server) |
| **Required for** | Async domain events: iam.UserRegistered → profile-service creates profile; recognition.TranslationCompleted → analytics records usage |
| **External owner** | SENA IT / Infrastructure team |
| **SLA** | SENA-defined |
| **Fallback** | (1) If broker is down, sync calls still work (gateway + services), but events queue on restart. (2) Restore message queue from backup. |
| **Status** | Running in production (as of 2026-10-04, microservices decision) |
| **Notes** | Connection string in .env (RABBITMQ_URL). Topic exchange: `traduce.events`. All services subscribe to events relevant to them. Management UI at localhost:15672 (user: guest, pass: guest). |
| **Risk** | If broker is down, events are lost (unless persistent queue + backup restore). Message queue can grow unbounded if consumer is slow or down. Monitor queue depth; alert if > 1000 messages for > 10 min. |

---

## Non-critical dependencies (nice-to-have, fallback exists)

### React Native (mobile framework)

| Field | Value |
|-------|-------|
| **Dependency** | React Native + Expo |
| **Type** | Open-source library (MIT) |
| **Required for** | Mobile app (Android + iOS) |
| **External owner** | Meta / Expo community |
| **Fallback** | Switch to Flutter (Google) — requires rewrite of UI |
| **Status** | In use; version pinned |

---

### OpenCV / MediaPipe

| Field | Value |
|-------|-------|
| **Dependency** | MediaPipe + OpenCV (hand detection) |
| **Type** | Open-source library |
| **Required for** | Real-time hand pose detection before TensorFlow inference |
| **External owner** | Google (MediaPipe) / OpenCV community |
| **Fallback** | Skip hand detection; inference on full video frame (slower, less accurate) |
| **Status** | Integrated in sign recognition pipeline |

---

## Dependency status summary

| Dependency | Status | Block? | Owner | Notes |
|------------|--------|--------|-------|-------|
| Google OAuth | Ready | No | Google Cloud | Fallback: email/password |
| Facebook OAuth | Ready | No | Meta | Fallback: Google |
| Firebase FCM | Ready | No | Google Cloud | Fallback: polling |
| SMTP | Pending | No | SENA IT | Password recovery emails |
| TensorFlow.js | Ready | Yes | TensorFlow team | Model location TBD (Q-001) |
| PostgreSQL (x5) | Ready | Yes | SENA IT | One per service; no read replicas |
| MongoDB | Ready | Yes | SENA IT | recognition-service only; grows independently |
| RabbitMQ | Ready | Yes | SENA IT | Message broker for async events; critical for microservices |
| React Native | Ready | No | Meta / Expo | Can switch to Flutter if needed |
| MediaPipe | Ready | No | Google | Fallback: raw video |

---

## Coordination points with SENA

1. **SMTP credentials:** needed before MVP release (password recovery unimplemented until then)
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
- Incident response per service → `09-microservices/services/XX/runbook.md`
