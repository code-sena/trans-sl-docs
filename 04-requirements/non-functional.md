# Non-Functional Requirements (NFR)

> **Status:** 🟡 Living document — v0.2
> **Last updated:** 2026-09-08
> **Scope:** TraduceSeña 2.0 — React Native / Expo mobile app + Node/Express microservices (iam, recognition, lexicon, analytics, profile + API Gateway) + PostgreSQL per service + MongoDB + RabbitMQ

> NFRs define the **qualities of the system** — not what it does but how well it does it.
> The golden rule: every NFR must have a metric. "The system must be fast" is not an NFR.
> "P95 latency of `POST /translations` must be < 300ms under 50 RPS" is.

---

## Why accessibility is NFR-001 here

Most projects list performance first. This one does not.

TraduceSeña's primary users are **deaf and hard-of-hearing people**. A design
decision that would be a minor annoyance in another product — an alert that
depends on a sound, a video with no visual caption, a state communicated only
by audio — makes the application **unusable** for the exact population it
exists to serve. Accessibility is not a quality attribute added at the end
here; it is the first constraint every other decision is checked against.

This is why the data model has no audio-only notification channel, and why
`notification_channel` deliberately offers only `PUSH`, `IN_APP` and `EMAIL`,
all three of which are visual.

---

## NFR-001: Accessibility ⭐ P1

| Attribute | Requirement | How to verify |
|-----------|-------------|---------------|
| Non-audio dependency | No information in the application is communicated **exclusively** by sound. Every audio output has a simultaneous visual equivalent. | Manual review checklist per screen, mandatory before each release |
| Contrast | Minimum contrast ratio 4.5:1 for normal text and 3:1 for large text, in **both** light and dark themes | axe DevTools / Accessibility Scanner, automated in CI |
| Touch target size | Minimum 48×48 dp for every interactive element | Android Accessibility Scanner |
| Alerts | 100% of notifications are delivered through a visual channel (banner, badge, in-app card) | Contract test over `notification_channel`: no audio-only value may exist in the enum |
| Sign multimedia | Every sign video/animation is playable without sound and is accompanied by written text in the active interface language | Content review per sign before publication |
| Standard | WCAG 2.1 level AA as target; level A as blocking minimum | Accessibility audit per cut |
| Screen reader | The application is navigable with TalkBack / VoiceOver in the main flows (login, translation, lexicon, alphabet) | Manual test per cut |

**Blocking rule:** an HU that introduces a screen fails the Definition of Done
if the screen has not passed the accessibility checklist.

---

## NFR-002: Performance

### Backend (Node/Express microservices behind the API Gateway)

| Attribute | Metric | Test condition |
|-----------|--------|---------------|
| P95 latency — critical endpoints | < 300 ms | Under 50 RPS sustained load |
| P99 latency — critical endpoints | < 500 ms | Under 50 RPS sustained load |
| P95 latency — non-critical endpoints | < 1000 ms | Normal load |
| Minimum throughput | 50 RPS | Without degradation |
| Application startup time | < 30 s | Cold start |
| Catalog query (paged lexicon) | < 400 ms for 50 items | Catalog of 2000 signs |

**Defined critical endpoints:**

- `POST /auth/login` — gateway to the entire application; if it is slow the app looks broken from the first screen
- `POST /translations` — persists the result of a translation; it is on the path of the app's core function (RF3)
- `GET /signs` — the lexicon catalog, the most consulted screen after translation
- `GET /signs/alphabet` — RF7, entry point for new users learning the alphabet
- `GET /notifications` — polled on every app resume

### Mobile app — recognition latency

> ⚠️ **Where inference runs is an open decision** (`02-domain/domain-map.md` §5). The domain is modeled
> against a `SignRecognitionPort`, not against an implementation. `ai_models.storage_reference` points
> to a published artifact, which suggests on-device inference, but that has not been decided or written
> down anywhere — and a file extension is not a decision.
>
> The targets below are what the **user perceives**, and they hold either way. Which of the two
> architectures can meet them is exactly what the decision has to weigh: on-device removes the network
> from the critical path, server-side removes the model from a low-end phone.

| Attribute | Metric | Test condition |
|-----------|--------|---------------|
| Camera-to-result latency | < 500 ms per recognized sign | Mid-range device (4 GB RAM, Android 11) |
| Sustained capture frame rate | ≥ 15 FPS | During continuous translation |
| Model load time on app start | < 2 s | Cold start, model already downloaded — applies only if inference runs on the device |
| Published model size | ≤ 25 MB | Per published artifact — applies only if inference runs on the device |
| Battery consumption | ≤ 8% per 10 minutes of continuous translation | Mid-range device, screen at 50% |
| Minimum recognition accuracy | ≥ 85% over the test set (`ai_models.accuracy` ≥ 0.85) | Before publishing the model as active |

**Load testing tools:** k6 for the backend; React Native performance profiler / Firebase Performance Monitoring for the app.

**Where is it validated?** k6 in the staging pipeline before promoting to production; device metrics per release candidate on the reference device.

---

## NFR-003: Availability

| Environment | SLO | Maintenance window | Max downtime/month |
|-------------|-----|--------------------|--------------------|
| Production | 99.5% | Sundays 2am–4am (COT) | 3 h 39 min |
| Staging | 95% | No restriction | 36 hours |

> **Why 99.5% and not 99.9%.** This is an academic project deployed on a single
> node with no multi-AZ redundancy. Committing to 99.9% would be a requirement
> the infrastructure cannot honor, and an SLO nobody can meet is worse than no
> SLO. 99.5% is achievable and still meaningful. It is raised when the
> deployment gains redundancy.

**Monthly error budget in production:** 3 h 39 min
**Error Budget policy:** if more than 50% of the budget is consumed in the first
half of the month, feature deploys are frozen until the next month and
stability is prioritized.

**Behavior with no connectivity:**

> ⚠️ **Offline use is explicitly out of scope for v1** (`02-domain/README.md`, model scope). This table
> describes how the app should *degrade* when the connection drops mid-use — which is not the same as
> offering offline operation, and is worth defining because a mobile app on Colombian mobile data will
> lose its connection whether or not the scope says so.

| Capability | Behavior when the connection drops |
|------------|-----------------------------------|
| Sign→text translation | Depends on the open inference decision: works if inference is on-device, unavailable if it is server-side |
| Alphabet and downloaded lexicon | Readable from the local cache |
| Translation history | Readable from the local cache; new entries queued and synced on reconnect |
| Login / registration | Unavailable — requires network |
| Notifications | Deferred until reconnect |

> If offline translation ever enters scope, it is not one more feature: it decides the inference
> question by itself, and `02-domain/domain-map.md` §6 has to be revisited before any code is written.

**Health checks:**

- `GET /health` — Liveness: responds 200 if the process is alive
- `GET /health/ready` — Readiness: responds 200 only if it can serve traffic (PostgreSQL connected, MongoDB connected, active model resolvable)

---

## NFR-004: Scalability

| Scenario | Expected behavior |
|----------|-------------------|
| Expected concurrent users | 500 concurrent, 5000 registered (target for the first production cut) |
| Gradual load growth | Each service scales independently (recognition first); services are stateless, JWT carries the session |
| Sudden spike (institutional launch, press) | Degrade gracefully: rate limit before falling over |
| Lexicon growth | Up to 5000 signs without query degradation, guaranteed by the indexes defined in the model |
| Gesture sample growth | MongoDB (owned by recognition-service) grows independently of the PostgreSQL databases — this is precisely why `gesture_samples` was decoupled |
| Usage event growth | `usage_events` is the highest-volume table; monthly partitioning by `created_at` is planned when it exceeds 10M rows |

**Strategy:** the backend is a set of microservices with a database per service.
Scaling is per service: the load-heavy `recognition-service` can run more
instances without touching the others. Domain boundaries in the data model
(`TableGroup`s, no cross-service FK) are what make that independence possible;
asynchronous events over RabbitMQ absorb spikes between services.

---

## NFR-005: Security

### Authentication and authorization

- All private endpoints require a valid JWT in the `Authorization: Bearer <token>` header
- JWT access tokens expire in **1 hour**
- Refresh tokens valid for **7 days**, with **rotation**: using one revokes it and links it to its replacement (`refresh_tokens.replaced_by_token_id`), so reuse of a spent token is detectable and triggers revocation of the whole session
- RBAC: roles and permissions per `roles` / `permissions` / `user_roles` / `role_permissions`

### Brute force protection

- Progressive lockout: 1, 5 and 10 minutes per accumulated lockout level (`users.lockout_level`)
- After the escalation is exhausted, the account moves to `BLOCKED` and requires administrator intervention
- The lockout level resets after 24 hours with no failed attempts
- Rate limiting of 10 requests/minute per IP on `POST /auth/login` and `POST /auth/password-reset`

### Sensitive data

- Passwords: hashed with **bcrypt (cost factor ≥ 12)** or Argon2id — never reversible encryption
- Verification codes and reset tokens: stored **only as hashes** (`user_tokens.token_hash`), never in clear text; single-use, with an expiry and a failed-attempt counter
- Push tokens: treated as credentials, revocable per device
- PII (personal data): encrypted at rest
- **Gesture samples: the most sensitive asset in the project** — biometric-adjacent body data linked to an identifiable person. Encrypted at rest, access restricted to the linguist/administrator role, and never exposed through a public endpoint
- Secrets/keys: only in environment variables or vault, **never in code**

### Transmission

- HTTPS mandatory in production (TLS 1.2+); certificate pinning in the mobile app for the production domain
- HTTP allowed only in local development

### OWASP

Code reviewed against the OWASP Top 10 (web) and OWASP MASVS (mobile) on each release.
Tools: SAST (SonarQube), dependency scanning (OWASP Dependency-Check), DAST in staging (OWASP ZAP).

### Regulatory compliance — Law 1581 of 2012 (Habeas Data, Colombia) ⭐

| Requirement | How it is satisfied |
|-------------|---------------------|
| Prior, express and informed authorization | `users.terms_accepted_at` + `users.terms_version` — mandatory to create the account (FR-002) |
| Authorization for biometric-adjacent data | `gesture_samples.consent_granted_at` + `consent_terms_version` — mandatory per sample (FR-602) |
| Demonstrable consent | Both are `NOT NULL`: a record without proof of consent cannot physically exist in the database |
| Right of deletion | Account deletion anonymizes the row (FR-014); gesture samples of a withdrawn collaborator are removable by capture session (FR-603) |
| Purpose limitation | Samples are used only for LSC model training; this purpose is stated in the consent document |
| Data controller | SENA — ADSO program. Named in the privacy notice |

> **Why this is P1 and not a footnote.** `gesture_samples` stores body data tied
> to an identifiable person. Under Law 1581 this is sensitive personal data:
> consent is mandatory, and it must be **demonstrable**. If the project cannot
> prove consent per sample, the entire training dataset is legally unusable.

---

## NFR-006: Observability

| Pillar | Requirement | Tool |
|--------|-------------|------|
| Logs | Structured JSON format + Correlation ID | Pino / Winston |
| Application error persistence | Every unhandled exception lands in `error_logs` classified by `error_type` | Express error-handling middleware |
| Change audit | Every change to a sensitive entity lands in `audit_logs` with before and after values | Repository-level interceptor / Prisma or TypeORM middleware |
| Metrics | RED (Rate, Errors, Duration) per endpoint | prom-client + Prometheus |
| Dashboards | Latency, error rate, active sessions, translations per day | Grafana |
| Alerts | Alert within 5 min when an SLI violates its SLO | Alertmanager |
| Mobile crashes | Crash-free sessions ≥ 99% | Firebase Crashlytics |

**Correlation ID:** every external request generates a UUID `correlationId`
propagated across all logs of that transaction and returned in the response
header, so a user-reported failure can be traced to its exact log line.

**Domain metrics worth watching** (beyond the technical ones):

- Ratio of `TRANSLATION_FAILED` to `TRANSLATION_COMPLETED` — the health of the AI model in the real world
- Average confidence of persisted translations — silent model degradation
- Signs with the most failed recognitions — which classes need more training samples

---

## NFR-007: Maintainability

| Metric | Target |
|--------|--------|
| Test coverage | ≥ 80% of lines (≥ 90% in the domain layer) |
| Cyclomatic complexity | ≤ 10 per method |
| Technical debt | Resolution within 1 sprint of registration |
| Onboarding time | A new developer can run the project locally in < 1 hour following `10-devops/local-setup.md` |
| Average build time | < 5 minutes in CI |
| Migrations | Every schema change goes through a versioned migration; no manual changes to any environment's database |
| Domain coupling | No cross-domain dependency other than through the identifiers already declared in the model |

---

## NFR-008: Portability

- Backend deployed as a Docker image
- PostgreSQL 15+ and MongoDB 6+ as declared dependencies, not assumptions
- No service depends on the host operating system
- Environment variables are the only source of environment-specific configuration
- Mobile app: Android 8.0 (API 26) minimum, iOS 14 minimum

---

## NFR-009: Usability

| Attribute | Metric | How to verify |
|-----------|--------|---------------|
| Time to first translation | A new user completes their first translation in < 3 minutes from opening the app | Usability test with 5 users |
| Registration steps | ≤ 4 screens from start to verified account | Flow review |
| Camera permission | Requested in context, with an explanation of why it is needed — never at first launch with no context | Flow review |
| Error messages | Written in plain language, stating what to do next — never a raw error code alone | Copy review per release |
| Language of the interface | Spanish and English, switchable without reinstalling or losing session (ERF5.4) | Functional test |

---

## NFR-010: Disaster recovery

| Scenario | RTO | RPO |
|----------|-----|-----|
| Application process failure | < 2 min (container restart) | 0 (stateless) |
| PostgreSQL failure | < 30 min (restore from the most recent backup) | < 24 h (daily backup) |
| MongoDB failure (gesture samples) | < 2 h | < 24 h |
| Loss of the published model artifact | < 15 min (republish a previous version from `ai_models`) | 0 — versions are preserved |
| Full infrastructure loss | < 8 h (redeploy from repository + restore backup) | < 24 h |

**Backups:** daily automated dump of PostgreSQL and MongoDB, 30-day retention,
with a **quarterly restore drill** — a backup nobody has ever restored is a
hypothesis, not a backup.

---

## NFR priority matrix

| NFR | Priority | Validated in CI? | Owner |
|-----|----------|------------------|-------|
| NFR-001 Accessibility | **P1** | Partially (axe); manual checklist per release | Team |
| NFR-002 Performance | P1 | Yes (k6 in staging) | Backend lead |
| NFR-003 Availability | P2 | Yes (health checks) | DevOps |
| NFR-004 Scalability | P3 | Manual (per cut) | DevOps |
| NFR-005 Security | **P1** | Yes (SAST + dependency scan) | Team |
| NFR-006 Observability | P2 | Yes (smoke test in CI) | Backend lead |
| NFR-007 Maintainability | P2 | Yes (coverage gate in CI) | Team |
| NFR-008 Portability | P2 | Yes (image build) | DevOps |
| NFR-009 Usability | P2 | No (usability test per cut) | Team |
| NFR-010 Disaster recovery | P3 | No (quarterly drill) | DevOps |

---

## Change log

| Version | Date | Change | Author |
|---------|------|--------|--------|
| v0.1 | 2026-09-08 | Generic template replaced with real project values. Accessibility promoted to NFR-001. Law 1581/2012 compliance added as a first-class requirement. Availability SLO lowered from 99.9% to 99.5% to match the actual infrastructure. | Juan Mauricio Suaza Solórzano |
| v0.2 | 2026-09-08 | Corrected against `02-domain/`: the stack is Node/Express + React Native, not Spring Boot. On-device inference and offline translation were stated as facts; they are an open decision and an out-of-scope item respectively, and are now marked as such. | Juan Mauricio Suaza Solórzano |

---

## Correlations

- Functional requirements → `functional.md`
- NFR verification status → `traceability-matrix.md`
- Architectural decisions driven by these NFRs → `05-architecture/`
- Pipeline that validates these NFRs → `10-devops/README.md`
