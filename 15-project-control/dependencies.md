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

### PostgreSQL

| Field | Value |
|-------|-------|
| **Dependency** | PostgreSQL 15+ relational database |
| **Type** | Self-hosted (on SENA's shared server) |
| **Required for** | Structured data (users, translations, lexicon, audit logs) |
| **External owner** | SENA IT / Infrastructure team |
| **SLA** | SENA-defined (not formally documented) |
| **Fallback** | Restore from daily backup (RTO: 30 min, RPO: 24 hours) |
| **Status** | Running in production |
| **Notes** | Connection string in .env. Pooled with pg-pool (min: 2, max: 30 connections). Migrations in migrations/ run on deploy. |
| **Risk** | Connection pool exhaustion under load (R-007 trigger). No read replicas; all reads hit the primary. |

---

### MongoDB

| Field | Value |
|-------|-------|
| **Dependency** | MongoDB 6+ document database |
| **Type** | Self-hosted (on SENA's shared server) |
| **Required for** | AI data: gesture samples, model versions, training logs |
| **External owner** | SENA IT / Infrastructure team |
| **SLA** | SENA-defined |
| **Fallback** | Restore from daily backup (RTO: 2 hours, RPO: 24 hours) |
| **Status** | Running in production |
| **Notes** | Connection string in .env (MONGO_URI). No sharding; single replica set. Collections: gesture_samples, ai_models, training_logs. |
| **Risk** | Grows independently of PostgreSQL; no FK constraints to catch orphaned records. |

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
| PostgreSQL | Ready | Yes | SENA IT | No read replicas |
| MongoDB | Ready | Yes | SENA IT | Grows independently |
| React Native | Ready | No | Meta / Expo | Can switch to Flutter if needed |
| MediaPipe | Ready | No | Google | Fallback: raw video |

---

## Coordination points with SENA

1. **SMTP credentials:** needed before MVP release (password recovery unimplemented until then)
2. **MongoDB backup schedule:** quarterly drill scheduled for 2026-11-15
3. **PostgreSQL backup restore:** tested 2026-11-15
4. **Server capacity planning:** model size (25 MB) + concurrent users (500) + gesture samples (unknown growth rate)

---

## Correlations

- Risk register (dependency failures) → `15-project-control/risks.md`
- Open questions (inference location decision) → `15-project-control/open-questions.md`
- Deployment plan → `05-architecture/deployment.md`
