# Traceability Matrix

> **Status:** 🟡 Living document — v0.4
> **Last updated:** 2026-10-24
> **Baseline:** 79 FR · 10 NFR · 53 HU · 29 tables (28 PostgreSQL + 1 MongoDB collection)

> Traceability connects every line of code to its business justification.
> It answers: "Why does this function exist?" and "Which HU covers this part of the system?"
> It also exposes: unimplemented requirements, and code with no requirement behind it.

---

## How to read this matrix

```
SRS (RF/ERF) → FR → HU → Test case → Service → Tables

If an FR has no HU:        it is not planned
If an HU has no test:      it has no completeness criterion
If a test has no code:     there is test debt
If a table has no FR:      possible gold-plating   ← this is how GAP-01 was found
If an FR has no table:     either a requirement nobody can persist, or an explicit "no persistence" FR (§ 3)
```

**Status legend**

| Status | Meaning |
|--------|---------|
| ✅ Done | Implemented, tested and merged |
| 🟡 In progress | In development in the current sprint |
| 🔴 Pending | In the backlog, not started |
| ⏸ Blocked | Has an external blocker |
| ❌ Cancelled | Removed from scope |
| ❔ Not verified | Not checked against the code yet |

> Since v0.4 (2026-10-24) § 2 shows the real state of each FR, checked against the code; it advances
> with each merged change.

### Module → owning service

Traduce Señas is a **microservices** architecture (see `09-microservices/`). The FR series are *functional modules* of the catalog; each one is owned
by exactly one service. The data of a service lives in its own database; there are no foreign
keys across services.

| Module (FR series) | Owning service | Store |
|--------------------|----------------|-------|
| Identity (FR-0xx) | `iam-service` | PostgreSQL `iam` |
| Authorization (FR-1xx) | `iam-service` | PostgreSQL `iam` |
| Audit / Configuration (FR-9xx) — password policy is Identity since model v9 | `iam-service` | PostgreSQL `iam` |
| Profile (FR-2xx) | `profile-service` | PostgreSQL `profile` |
| Notification (FR-5xx) | `profile-service` | PostgreSQL `profile` |
| Gamification (FR-8xx) ⚠️ | `profile-service` | PostgreSQL `profile` |
| Lexicon (FR-3xx) | `lexicon-service` | PostgreSQL `lexicon` |
| Translation (FR-4xx) | `recognition-service` | PostgreSQL `recognition` |
| AI (FR-6xx) | `recognition-service` | PostgreSQL `recognition` + MongoDB `gesture_samples` |
| Usage (FR-7xx) | `analytics-service` | PostgreSQL `analytics` |
| Navigation (FR-95x) | Mobile app (UI) — events go to `analytics-service` | — |

---

## 1. SRS → FR coverage

The first check: does every requirement in the SRS have at least one FR that
develops it, and does every FR trace back to an SRS requirement?

| SRS | Description | FRs that develop it | Status |
|-----|-------------|---------------------|--------|
| RF1 | User management | FR-001 … FR-015 | ✅ Covered |
| RF2 | Navigation | FR-951, FR-952 | ✅ Covered |
| RF3 | Sign→text/audio translation | FR-401 … FR-408, FR-601 … FR-607 | ✅ Covered |
| RF4 | Notifications | FR-501 … FR-509, FR-205 | ✅ Covered |
| RF5 | Profile management | FR-201, FR-202, FR-406, FR-407, FR-014 | ✅ Covered |
| RF6 | Statistics (admin) | FR-701 … FR-706, FR-101 … FR-104, FR-015 | ✅ Covered |
| RF7 | Sign alphabet | FR-301 … FR-310 | ✅ Covered |
| **RF8** | **Gamification** | FR-801 … FR-805 | ⚠️ **Proposed, not in the SRS** |
| ERF1.1 | Registration data + terms | FR-001, FR-002, FR-201 | ✅ Covered |
| ERF1.2 | Google / Facebook login | FR-008, FR-009 | ✅ Covered |
| ERF3.2 | Audio output | FR-402 | ✅ Covered |
| ERF4.1 | Visual alerts (accessibility) | FR-502 | ✅ Covered |
| ERF5.1 | Profile data | FR-201 | ✅ Covered |
| ERF5.2 | Theme | FR-203, FR-206 | ✅ Covered |
| ERF5.4 | Interface language | FR-204, FR-306 | ✅ Covered |
| ERF5.5 | Delete history entries | FR-407 | ✅ Covered |
| — | Internal audit | FR-901, FR-902 | ✅ Covered (no explicit RF) |
| — | Error handling | FR-903, FR-904 | ✅ Covered (no explicit RF) |
| — | Password policy | FR-905 … FR-907 | ✅ Covered (no explicit RF) |
| — | Legal compliance Law 1581/2012 | FR-002, FR-602 | ✅ Covered (no explicit RF) |

**Row count:** 20 rows = **15 SRS requirements** (RF1–RF7 + 8 ERF) + **1 proposed** (RF8, not in the
SRS) + **4 cross-cutting** with no explicit RF.

> **Note.** The last four rows are requirements that exist in the data model but
> have no RF in the SRS. Unlike RF8 they are not gold-plating — they are
> cross-cutting technical requirements every system needs. It is still worth
> naming them explicitly in the SRS so the traceability closes cleanly.

---

## 2. FR → HU → Test → Service matrix

> **Status checked against the code on 2026-10-24** (Backend `develop` v1.2.0, Frontend `develop`). The
> "Test" column names the real test files (backend `services/*/tests`, app `src/**/__tests__`); the
> earlier planned names (`RegisterUser.spec.ts`…) never existed. ✅ implemented and tested · 🟡 partly
> implemented, or implemented without a test · 🔴 not implemented · ❔ not verified.

### Identity — `iam-service`

| FR | Description | HU | Test that verifies it | Service | Status |
|----|-------------|----|-----------------------|---------|--------|
| FR-001 | Registration with data + terms | HU-IAM-001 | `request_schema.test.ts`, `register_role.test.ts`, `email_verification.test.ts`; app `registerBody.test.ts` | iam-service | ✅ |
| FR-002 | Terms acceptance record | HU-IAM-001 | `request_schema.test.ts` (consent), `google_login.test.ts`; app `registerBody.test.ts`, `socialConsent.test.ts` | iam-service | ✅ |
| FR-003 | Verification with a 6-digit code | HU-IAM-002 | `email_verification.test.ts` | iam-service | ✅ |
| FR-004 | Hashed, expiring, single-use tokens | HU-IAM-002 | `token_service.test.ts`, `auth_repository.test.ts` | iam-service | ✅ |
| FR-005 | Login with email and password | HU-IAM-003 | `auth.test.ts`, `app.test.ts` (iam); app `AuthContext.test.tsx` | iam-service | ✅ |
| FR-006 | Progressive lockout | HU-IAM-004 | — (only the gateway rate limit, `routing.test.ts`; no progressive lockout) | iam-service | 🔴 |
| FR-007 | Definitive block | HU-IAM-004 | `auth.test.ts` (`ACCOUNT_BLOCKED` at login); no admin action to block | iam-service | 🟡 |
| FR-008 | Google / Facebook login | HU-IAM-005 | `google_login.test.ts`, `facebook_login.test.ts`, `*_token_verifier.test.ts` | iam-service | ✅ |
| FR-009 | Multiple linked providers | HU-IAM-005 | — (no `user_auth_providers` table) | iam-service | 🔴 |
| FR-010 | Password recovery | HU-IAM-006 | `password_reset.test.ts` | iam-service | ✅ |
| FR-011 | Session opening | HU-IAM-007 | `jwt_roles.test.ts` (JWT issued); no session record | iam-service | 🟡 |
| FR-012 | Refresh token rotation | HU-IAM-007 | — (no refresh token, ADR-002; finding H-08) | iam-service | 🔴 |
| FR-013 | Logout with duration | HU-IAM-008 | — (logout only clears the token on the client) | iam-service | 🔴 |
| FR-014 | Deletion with anonymization | HU-IAM-009 | `account.test.ts`, `atomic_erasure.test.ts`, `user_deleted.test.ts`, `erase_user_profile.test.ts`, `relay_outbox.test.ts` | iam-service | ✅ |
| FR-015 | Account administration | HU-IAM-010 | `iam_use_cases.test.ts`, `is_last_admin.test.ts` (roles); no list or block of users | iam-service | 🟡 |

### Authorization — `iam-service`

| FR | Description | HU | Test that verifies it | Service | Status |
|----|-------------|----|-----------------------|---------|--------|
| FR-101 | RBAC with multiple roles | HU-AUTHZ-001 | `jwt_roles.test.ts`, `iam_use_cases.test.ts` | iam-service | ✅ |
| FR-102 | Permissions independent of roles | HU-AUTHZ-001 | `jwt_roles.test.ts`, `preferences_permissions.test.ts` | iam-service | ✅ |
| FR-103 | Administration access denied | HU-AUTHZ-002 | `ia_sign_template_permissions.test.ts`, `stats_routes.test.ts` | iam-service | ✅ |
| FR-104 | Role in use cannot be deleted | HU-AUTHZ-002 | — (`ROLE_IN_USE` in `iam_controller.ts`, no test) | iam-service | 🟡 |

### Profile — `profile-service`

| FR | Description | HU | Test that verifies it | Service | Status |
|----|-------------|----|-----------------------|---------|--------|
| FR-201 | View and edit profile | HU-PROF-001 | `app.test.ts` (profile), `update_preferences.test.ts` | profile-service | ✅ |
| FR-202 | Change password | HU-PROF-002 | `account.test.ts`, `account_routes.test.ts` | profile-service (credential stored by iam-service) | ✅ |
| FR-203 | Light / dark theme | HU-PROF-003 | `update_preferences.test.ts`, `preferences_postgres.test.ts` | profile-service | ✅ |
| FR-204 | Interface language | HU-PROF-004 | `update_preferences.test.ts`; app `LanguageDropdown.test.tsx` | profile-service | ✅ |
| FR-205 | Notification switch | HU-PROF-005 | `record_translation.test.ts`, `validation.test.ts` | profile-service | ✅ |
| FR-206 | Default preferences on creation | HU-PROF-003 | `event_handlers.test.ts`, `preferences_postgres.test.ts` | profile-service (on `iam.UserRegistered`) | ✅ |

### Lexicon — `lexicon-service`

| FR | Description | HU | Test that verifies it | Service | Status |
|----|-------------|----|-----------------------|---------|--------|
| FR-301 | Catalog by category | HU-LEX-001 | `lexicon_use_cases.test.ts` | lexicon-service | ✅ |
| FR-302 | Search by name | HU-LEX-002 | `lexicon_controller.test.ts`, `lexicon_use_cases.test.ts` | lexicon-service | ✅ |
| FR-303 | Detail with multimedia | HU-LEX-003 | `lexicon_use_cases.test.ts` | lexicon-service | ✅ |
| FR-304 | Alphabet with no duplicate letters | HU-LEX-004 | `lexicon_use_cases.test.ts` (alphabet) | lexicon-service | ✅ |
| FR-305 | Language-independent stable code | HU-LEX-005 | `lexicon_use_cases.test.ts` | lexicon-service | ✅ |
| FR-306 | Localization per language | HU-LEX-005 | `lexicon_use_cases.test.ts` (localizations) | lexicon-service | ✅ |
| FR-307 | Sign administration | HU-LEX-006 | `lexicon_controller.test.ts`, `lexicon_use_cases.test.ts` | lexicon-service | ✅ |
| FR-308 | Category administration | HU-LEX-006 | `lexicon_controller.test.ts` | lexicon-service | ✅ |
| FR-309 | Ordered resources | HU-LEX-007 | `rules.test.ts` | lexicon-service | ✅ |
| FR-310 | Only ACTIVE signs are visible | HU-LEX-006 | `lexicon_use_cases.test.ts` | lexicon-service | ✅ |

### Translation — `recognition-service`

| FR | Description | HU | Test that verifies it | Service | Status |
|----|-------------|----|-----------------------|---------|--------|
| FR-401 | Live camera translation | HU-TRA-001 | app `knnClassifier.test.ts`, `normalize.test.ts`, `wordTemplateMatcher.test.ts` (logic); camera flow checked by hand | recognition-service | ✅ |
| FR-402 | Audio output | HU-TRA-002 | app `voicePlayback.test.ts` | recognition-service | ✅ |
| FR-403 | Persist with model and confidence | HU-TRA-003 | `create_translation.test.ts`, `http_contract.test.ts` (confidence and source; no model reference) | recognition-service | 🟡 |
| FR-404 | Ordered signs of the translation | HU-TRA-003 | — (no `translation_signs` table) | recognition-service | 🔴 |
| FR-405 | Failed recognition feedback | HU-TRA-004 | not verified | recognition-service | ❔ |
| FR-406 | History newest first | HU-TRA-005 | `http_contract.test.ts`; app `translations.service.test.ts`, `HistoryScreen.test.tsx` | recognition-service | ✅ |
| FR-407 | Logical deletion of an entry | HU-TRA-006 | `http_contract.test.ts`, `controller_errors.test.ts` | recognition-service | ✅ |
| FR-408 | Model with history is undeletable | HU-TRA-003 | — (no model registry) | recognition-service | 🔴 |

### Notification — `profile-service`

| FR | Description | HU | Test that verifies it | Service | Status |
|----|-------------|----|-----------------------|---------|--------|
| FR-501 | Administrable type catalog | HU-NOTIF-001 | seeded `notification_types`; not administrable through the API | profile-service | 🟡 |
| FR-502 | Visual channel only ⭐ | HU-NOTIF-002 | `record_translation.test.ts` (in-app notifications only) | profile-service | ✅ |
| FR-503 | Device registration | HU-NOTIF-003 | — (no device registration) | profile-service | 🔴 |
| FR-504 | Scheduled notifications | HU-NOTIF-004 | — (admin reports in the unmerged branch `feat/profile-admin-notifications`) | profile-service | 🔴 |
| FR-505 | FAILED vs PENDING state | HU-NOTIF-005 | status type exists (`notification.ts`); no delivery channel that can fail | profile-service | 🟡 |
| FR-506 | Reference to the originating record | HU-NOTIF-006 | `record_translation.test.ts` | profile-service | ✅ |
| FR-507 | Mark as read | HU-NOTIF-002 | `preferences_permissions.test.ts` | profile-service | ✅ |
| FR-508 | Master switch suppresses delivery | HU-PROF-005 | `record_translation.test.ts`, `validation.test.ts` | profile-service | ✅ |
| FR-509 | Push requires a device | HU-NOTIF-003 | — (no push) | profile-service | 🔴 |

### AI — `recognition-service`

| FR | Description | HU | Test that verifies it | Service | Status |
|----|-------------|----|-----------------------|---------|--------|
| FR-601 | Capture grouped by session | HU-AI-001 | partial: `session_id` in the Mongo sample; the app keeps samples on the device (finding H-06) | recognition-service | 🟡 |
| FR-602 | Demonstrable consent ⚖️ | HU-AI-002 | `app.test.ts` (recognition: sample without consent → 400) | recognition-service | ✅ |
| FR-603 | Discard a full session | HU-AI-001 | — (no discard route) | recognition-service | 🔴 |
| FR-604 | Validation before training | HU-AI-003 | — (no validation route) | recognition-service | 🔴 |
| FR-605 | Model registry with metrics | HU-AI-004 | — (no model registry) | recognition-service | 🔴 |
| FR-606 | Exactly one active model | HU-AI-005 | — (motion templates instead of models) | recognition-service | 🔴 |
| FR-607 | Samples in MongoDB, decoupled | HU-AI-001 | `mongo_sample_repository` adapter; not reached by the app (finding H-06) | recognition-service | 🟡 |

### Usage — `analytics-service`

| FR | Description | HU | Test that verifies it | Service | Status |
|----|-------------|----|-----------------------|---------|--------|
| FR-701 | Section entry event | HU-USG-001 | `analytics_use_cases.test.ts` (`SECTION_VIEW`) | analytics-service | ✅ |
| FR-702 | Functional events | HU-USG-001 | `analytics_use_cases.test.ts` | analytics-service | ✅ |
| FR-703 | Most visited sections | HU-USG-002 | `stats.test.ts`, `stats_sql.test.ts` | analytics-service | ✅ |
| FR-704 | Sessions and average duration | HU-USG-003 | — (no session duration in analytics) | analytics-service (session facts come from iam-service) | 🔴 |
| FR-705 | Events survive deletion | HU-USG-004 | `atomic_erasure.test.ts`, `user_deleted.test.ts` (analytics) | analytics-service | ✅ |
| FR-706 | Statistics require permission | HU-AUTHZ-002 | `stats_routes.test.ts` | analytics-service | ✅ |

### Gamification ⚠️ — `profile-service`

| FR | Description | HU | Test that verifies it | Service | Status |
|----|-------------|----|-----------------------|---------|--------|
| FR-801 | Achievement catalog | HU-GAM-001 | `achievement_catalog.test.ts` | profile-service | ✅ |
| FR-802 | Progress tracking | HU-GAM-002 | `functional_achievements.test.ts`, `translation_milestones.test.ts` | profile-service | ✅ |
| FR-803 | Unlock exactly once | HU-GAM-002 | `gamification_concurrency.test.ts`, `record_translation.test.ts` | profile-service | ✅ |
| FR-804 | Unlock notification | HU-GAM-003 | `record_translation.test.ts` | profile-service | ✅ |
| FR-805 | Consult achievements | HU-GAM-004 | `achievement_catalog.test.ts`; app `achievements.test.tsx` | profile-service | ✅ |

> **Blocker:** RF8 does not exist in the SRS. See § Gaps, GAP-01.

### Audit and configuration — `iam-service`

| FR | Description | HU | Test that verifies it | Service | Status |
|----|-------------|----|-----------------------|---------|--------|
| FR-901 | Audit with before/after values | HU-AUD-001 | — (no audit log) | iam-service | 🔴 |
| FR-902 | Trail survives deletion | HU-AUD-001 | — (no audit log) | iam-service | 🔴 |
| FR-903 | Technical error log | HU-AUD-002 | — (no error log table; errors go to stdout) | iam-service | 🔴 |
| FR-904 | Classification by error type | HU-AUD-002 | — (no error log table) | iam-service | 🔴 |
| FR-905 | Configurable password policy | HU-CFG-001 | — (no configurable policy) | iam-service | 🔴 |
| FR-906 | Validation against the active policy | HU-CFG-001 | app `passwordStrength.test.ts` (fixed rules, not a stored policy) | iam-service | 🟡 |
| FR-907 | Historical policies preserved | HU-CFG-001 | — (no policy history) | iam-service | 🔴 |

### Navigation — mobile app (UI)

| FR | Description | HU | Test that verifies it | Service | Status |
|----|-------------|----|-----------------------|---------|--------|
| FR-951 | Navigation between sections | HU-NAV-001 | checked by hand | mobile app (events → analytics-service) | ✅ |
| FR-952 | No dead-end screens | HU-NAV-001 | not verified | mobile app | ❔ |

---

## 3. FR → tables matrix

The check nobody usually runs: does each FR have somewhere to store its data,
and does each table have a requirement justifying it? Tables are grouped by the service
that owns them (database per service; no foreign keys across services).

> These are the tables of the **reference model** (DBML v9). Several do not exist in the code (`refresh_tokens`,
> `user_sessions`, `audit_logs`…); the tables that exist today, per service, are in
> [`06-data/models.md` § 0](../06-data/models.md).

### `iam-service` (PostgreSQL `iam`)

| Table | FRs that justify it | Status |
|-------|---------------------|--------|
| `users` | FR-001 … FR-007, FR-014, FR-015, FR-201, FR-202 | ✅ Justified |
| `user_auth_providers` | FR-008, FR-009 | ✅ Justified |
| `user_sessions` | FR-011, FR-013, FR-704 | ✅ Justified |
| `refresh_tokens` | FR-012 | ✅ Justified |
| `user_tokens` | FR-003, FR-004, FR-010 | ✅ Justified |
| `password_policies` | FR-905 … FR-907 | ✅ Justified — **Identity domain since model v9** (DATA-12) |
| `roles` | FR-101, FR-104 | ✅ Justified |
| `permissions` | FR-102 | ✅ Justified |
| `user_roles` | FR-101 | ✅ Justified |
| `role_permissions` | FR-102, FR-103 | ✅ Justified |
| `audit_logs` | FR-901, FR-902 | ✅ Justified |
| `error_logs` | FR-903, FR-904 | ✅ Justified |

### `profile-service` (PostgreSQL `profile`)

| Table | FRs that justify it | Status |
|-------|---------------------|--------|
| `user_preferences` | FR-203 … FR-206, FR-508 | ✅ Justified |
| `notification_types` | FR-501 | ✅ Justified |
| `user_devices` | FR-503, FR-509 | ✅ Justified |
| `notifications` | FR-502, FR-504 … FR-507, FR-804 | ✅ Justified (FR-804 conditional on RF8) |
| `achievements` | FR-801 | ⚠️ **GAP-01: depends on RF8** |
| `user_achievements` | FR-802, FR-803, FR-805 | ⚠️ **GAP-01: depends on RF8** |

### `lexicon-service` (PostgreSQL `lexicon`)

| Table | FRs that justify it | Status |
|-------|---------------------|--------|
| `categories` | FR-301, FR-308 | ✅ Justified |
| `sign_lexicon` | FR-301, FR-304, FR-305, FR-307, FR-310 | ✅ Justified |
| `sign_localizations` | FR-302, FR-306 | ✅ Justified |
| `multimedia_resources` | FR-303, FR-309 | ✅ Justified |

> `sign_translations` (GAP-02, duplicate of `sign_localizations`) was already removed from the v8
> model and no longer appears here.

### `recognition-service` (PostgreSQL `recognition` + MongoDB)

| Table | FRs that justify it | Status |
|-------|---------------------|--------|
| `translations` | FR-403, FR-406, FR-407 | ✅ Justified |
| `translation_signs` | FR-404 | ✅ Justified |
| `ai_models` | FR-403, FR-408, FR-605, FR-606 | ✅ Justified |
| `gesture_samples` (MongoDB) | FR-601 … FR-604, FR-607 | ✅ Justified |

### `analytics-service` (PostgreSQL `analytics`)

| Table | FRs that justify it | Status |
|-------|---------------------|--------|
| `usage_events` | FR-701, FR-702, FR-703, FR-705, FR-951 | ✅ Justified |
| `usage_daily_stats` | FR-703 (rollup cache) | ⚠️ **GAP-11: no FR text for the rollup** (DATA-03) |
| `session_daily_stats` | FR-704 (rollup cache) | ⚠️ **GAP-11: no FR text for the rollup** (DATA-03) |

### FRs with no table of their own

These FRs are intentionally not persisted by a table of their own. They are not gaps.

| FR | Reason |
|----|--------|
| FR-401 | Live camera capture and inference on the client; the resulting translation is persisted through FR-403 |
| FR-402 | Audio output is a UI behaviour; the delivery mode is recorded by FR-403 (`translations.output_mode`) |
| FR-405 | Visual feedback of a failed recognition (UI); the failure is counted as `TRANSLATION_FAILED` through FR-702 |
| FR-706 | Access-control rule (permission `stats.read`, aggregated output, INV-012); enforced over `role_permissions` and `usage_events`, stores nothing |
| FR-952 | UI rule (no dead-end screens); stores nothing |

### Result

- **29 tables** (28 PostgreSQL + 1 MongoDB collection): **25 justified**, 2 conditional on RF8
  (GAP-01), 2 rollup tables whose FR text is missing (GAP-11).
- **79 FRs**: **74 persisted** in a table (listed above) and **5 with no persistence** (FR-401, FR-402,
  FR-405, FR-706, FR-952).

---

## 4. NFR → validation matrix

| NFR | Description | How it is validated | Tool | Status |
|-----|-------------|---------------------|------|--------|
| NFR-001 | Accessibility WCAG 2.1 AA | Automated scan + manual checklist per screen | axe / Accessibility Scanner | 🔴 Pending |
| NFR-001 | No audio-only channel | Contract test over the channel enum | Jest | 🔴 Pending |
| NFR-002 | Backend P95 < 300 ms | Load test in staging | k6 | 🔴 Pending |
| NFR-002 | Recognition < 500 ms end to end | Measurement on the reference device | RN profiler / Firebase Performance | 🔴 Pending |
| NFR-002 | Model accuracy ≥ 0.85 | Evaluation on the test set before activation | Training pipeline | 🔴 Pending |
| NFR-003 | Availability 99.5% | SLO monitoring | Prometheus + Grafana | 🔴 Pending |
| NFR-003 | Graceful degradation with no connection | Test in airplane mode | Manual + instrumented test | 🔴 Pending |
| NFR-004 | 500 concurrent users | Load test | k6 | 🔴 Pending |
| NFR-005 | JWT 1 h + rotating refresh | Security contract test | Jest + Postman | 🔴 Pending |
| NFR-005 | bcrypt cost ≥ 12 | Configuration test | Jest | 🔴 Pending |
| NFR-005 | Consent per sample (Law 1581) | `NOT NULL` constraint + `ConsentRequired.spec.ts` | Jest | 🔴 Pending |
| NFR-005 | OWASP Top 10 | Static analysis + DAST | SonarQube + OWASP ZAP | 🔴 Pending |
| NFR-006 | Correlation ID in every log | Integration test | Jest + Supertest | 🔴 Pending |
| NFR-007 | Coverage ≥ 80% | Coverage gate in CI | Jest coverage | 🔴 Pending |
| NFR-008 | Runs in Docker | Image build in CI | GitHub Actions | 🔴 Pending |
| NFR-009 | First translation in < 3 min | Usability test with 5 users | Manual | 🔴 Pending |
| NFR-010 | Restorable backup | Quarterly restore drill | Manual | 🔴 Pending |

---

## 5. Inverse traceability: HU → FR

| HU | Title | FRs it implements | Sprint | Points |
|----|-------|-------------------|--------|--------|
| HU-CFG-001 | Password policy | FR-905, FR-906, FR-907 | 1 | 3 |
| HU-IAM-001 | Registration | FR-001, FR-002 | 1 | 5 |
| HU-IAM-002 | Email verification | FR-003, FR-004 | 1 | 3 |
| HU-IAM-003 | Login | FR-005 | 1 | 3 |
| HU-IAM-008 | Logout | FR-013 | 1 | 2 |
| HU-IAM-004 | Progressive lockout | FR-006, FR-007 | 2 | 5 |
| HU-IAM-005 | Google / Facebook | FR-008, FR-009 | 2 | 8 |
| HU-IAM-006 | Password recovery | FR-010 | 2 | 5 |
| HU-IAM-007 | Session and rotation | FR-011, FR-012 | 2 | 5 |
| HU-AUTHZ-001 | Roles and permissions | FR-101, FR-102 | 2 | 5 |
| HU-AUTHZ-002 | Access control | FR-103, FR-104, FR-706 | 2 | 3 |
| HU-PROF-001 | Edit profile | FR-201 | 3 | 3 |
| HU-PROF-002 | Change password | FR-202 | 3 | 3 |
| HU-PROF-003 | Theme | FR-203, FR-206 | 3 | 3 |
| HU-LEX-001 | Browse catalog | FR-301 | 3 | 3 |
| HU-LEX-002 | Search | FR-302 | 3 | 3 |
| HU-LEX-003 | Sign detail | FR-303 | 3 | 5 |
| HU-LEX-004 | Alphabet | FR-304 | 3 | 3 |
| HU-LEX-005 | Code and localization | FR-305, FR-306 | 3 | 5 |
| HU-NAV-001 | Navigation | FR-951, FR-952 | 3 | 5 |
| HU-PROF-004 | Language | FR-204 | 4 | 5 |
| HU-PROF-005 | Notification switch | FR-205, FR-508 | 4 | 2 |
| HU-AI-005 | Publish model | FR-606 | 4 | 5 |
| HU-TRA-001 | Camera translation ⭐ | FR-401 | 4 | 13 |
| HU-TRA-002 | Audio output | FR-402 | 4 | 3 |
| HU-TRA-003 | Persist translation | FR-403, FR-404, FR-408 | 4 | 5 |
| HU-TRA-004 | Failure feedback | FR-405 | 4 | 3 |
| HU-TRA-005 | History | FR-406 | 4 | 3 |
| HU-TRA-006 | Delete entries | FR-407 | 4 | 2 |
| HU-USG-001 | Event recording | FR-701, FR-702 | 4 | 5 |
| HU-IAM-009 | Account deletion | FR-014 | 5 | 5 |
| HU-IAM-010 | Account administration | FR-015 | 5 | 3 |
| HU-LEX-006 | Sign administration | FR-307, FR-308, FR-310 | 5 | 8 |
| HU-LEX-007 | Multimedia resources | FR-309 | 5 | 5 |
| HU-NOTIF-001 | Type catalog | FR-501 | 5 | 3 |
| HU-NOTIF-002 | Receive and read ⭐ | FR-502, FR-507 | 5 | 5 |
| HU-NOTIF-003 | Device registration | FR-503, FR-509 | 5 | 5 |
| HU-USG-004 | Statistics survive deletion | FR-705 | 5 | 3 |
| HU-AUD-001 | Audit trail | FR-901, FR-902 | 5 | 5 |
| HU-AUD-002 | Error log | FR-903, FR-904 | 5 | 3 |
| HU-AI-001 | Sample capture | FR-601, FR-603, FR-607 | 6 | 8 |
| HU-AI-002 | Consent ⚖️ | FR-602 | 6 | 5 |
| HU-AI-003 | Sample validation | FR-604 | 6 | 5 |
| HU-AI-004 | Model registry | FR-605 | 6 | 5 |
| HU-NOTIF-004 | Scheduled | FR-504 | 6 | 5 |
| HU-NOTIF-005 | Failed delivery | FR-505 | 6 | 3 |
| HU-NOTIF-006 | Reference to the record | FR-506 | 6 | 3 |
| HU-USG-002 | Most visited sections | FR-703 | 6 | 5 |
| HU-USG-003 | Session statistics | FR-704 | 6 | 3 |
| HU-GAM-001 ⏸ | Achievement catalog | FR-801 | 7 | 3 |
| HU-GAM-002 ⏸ | Progress | FR-802, FR-803 | 7 | 5 |
| HU-GAM-003 ⏸ | Achievement notification | FR-804 | 7 | 2 |
| HU-GAM-004 ⏸ | Consult achievements | FR-805 | 7 | 3 |

### Load per sprint

| Sprint | HUs | Points | Notes |
|--------|-----|--------|-------|
| Sprint 1 | 5 | 16 | Account foundation |
| Sprint 2 | 6 | 31 | Security and authorization — the heaviest sprint |
| Sprint 3 | 9 | 33 | Lexicon and profile |
| Sprint 4 | 10 | 46 | ⚠️ **Overloaded** — contains the 13-point core story |
| Sprint 5 | 10 | 45 | ⚠️ **Overloaded** — administration |
| Sprint 6 | 9 | 42 | ⚠️ **Overloaded** — AI and statistics |
| Sprint 7 | 4 | 13 | Gamification, blocked |

> ⚠️ **Planning warning.** Sprints 4, 5 and 6 exceed 40 points. With a team of
> 4 and a velocity yet to be measured, that is very likely more than fits. The
> baseline is deliberately left as-is so the overload is visible: it is a real
> planning input, and hiding it by splitting the work arbitrarily would only
> move the problem to the Sprint Review. **Action:** measure real velocity in
> Sprint 1 and rebalance from Sprint 4 onwards.

---

## 6. Identified gaps

| ID | Gap type | Description | Required action | Owner | Priority |
|----|----------|-------------|-----------------|-------|----------|
| **GAP-01** | Table without an FR | `achievements` and `user_achievements` exist in the model with no SRS requirement behind them. In a traceability review this reads as gold-plating | **Decision.** Approve RF8 and add it to the SRS, **or** remove both tables, their two `Ref`s, the `Gamification` TableGroup, the FR-800 series and EP-009. There is no third option: either the requirement exists or the tables do not | Team + instructor | **High** |
| **GAP-02** | Duplicate table | `sign_translations` and `sign_localizations` were the same table twice. ✅ **Already removed from the v8 model** (see `06-data/domains/04-lexicon.md`); no longer in § 3. Recorded so the fix is not undone | None — keep `sign_localizations` (its `(ui_language, name)` index serves FR-302) | Juan Mauricio | Closed |
| **GAP-03** | Non-existent table cited | The traceability comment at the end of the DBML cited `password_reset_tokens`. ✅ **Closed in v9** — it now cites `user_tokens` | None | Juan Mauricio | Closed |
| **GAP-04** | Incorrect statement | The DBML stated RF2 is "solo UI, sin persistencia", but every section entry is persisted as `SECTION_VIEW` in `usage_events`. ✅ **Closed in v9** | None | Juan Mauricio | Closed |
| **GAP-05** | Constraints declared but not written | The DBML lists six constraints delegated to `migrations/002_constraints.sql` and ends with `// ...`. Four more that the requirements demand are missing: `multimedia_resources.position >= 1` (FR-309), `password_policies.min_length <= max_length` (FR-905), a single active `password_policies` row (FR-905), and `achievements.target_count > 0` (FR-801, if RF8 is approved) | Complete the comment list and **write `migrations/002_constraints.sql`**. A constraint that lives only in a comment is a comment: the database will accept `confidence = 47.3` until the DDL says otherwise. In the microservices layout each service carries its own migrations | Juan Mauricio | **High** |
| **GAP-06** | Nullable field that should not be | `translations.model_id` is nullable, but FR-403 requires every translation to record the model that produced it and FR-408 relies on that link. Nullable means a translation can exist with no traceability, defeating the field's stated purpose. Likely reason: translations queued while the connection was down | **Decision.** Make it `not null` and resolve the active model before insert — whichever side runs inference knows which version it used. Alternatively keep it nullable and document exactly what `NULL` means, plus a backfill job | Team | Medium |
| **GAP-07** | Enum values with no consumer | `reference_entity` declares `CATEGORY`, `AI_MODEL` and `USER`, which no FR produces. `usage_section.ACHIEVEMENTS` depends on GAP-01 | Low impact — an unused enum value costs nothing at runtime. Either document them as reserved extension points or trim them, so a future reader does not hunt for code that does not exist | Juan Mauricio | Low |
| **GAP-08** | RF without an explicit SRS entry | Audit, error handling, password policy and Law 1581 compliance have tables and FRs but no RF in the SRS. Unlike GAP-01 these are not gold-plating — they are cross-cutting technical requirements every system needs — but the traceability does not close cleanly without them | Name them explicitly in the SRS as cross-cutting requirements | Team | Medium |
| **GAP-09** | FR without a test | Every FR is at 🔴 Pending — no test exists yet | Write the test alongside each HU, never after | Team | Expected at baseline |
| **GAP-10** | Overloaded sprints | Sprints 4, 5 and 6 exceed 40 points with velocity still unmeasured | Measure real velocity in Sprint 1 and rebalance from Sprint 4 onwards | Team | Medium |
| **GAP-11** | Tables without an FR | `usage_daily_stats` and `session_daily_stats` (`06-data/domains/08-usage.md`, DATA-03) are rollup caches with no requirement text of their own, and `02-domain/domain-map.md` says Usage Analytics "owns no aggregated data". By the matrix rule a table with no FR does not enter the model | Add an FR (or extend FR-703/FR-704) stating the rollup as a cache with a recompute job, and fix the domain map sentence | Team | Medium |
| **GAP-12** | Stale counts in this matrix | Through v0.2 the baseline said 30 tables and § 3 listed 28 rows (including the already-removed `sign_translations`); the model v9 has 29. The "17/17 SRS" and "77/79 persisted" figures in § 7 were also wrong, and 17 FRs were reported as missing from § 3 although most were covered by ranges | ✅ Fixed in v0.3 (SRS 15/15, 74/79 persisted + 5 explicit no-persistence, 25/29 tables) | Documentation | Closed |
| **GAP-13** | Monolith wording outside the matrix | `04-requirements/non-functional.md` and `_template-hu.md` still say "modular monolith" / "module in the monolith"; the architecture decision is microservices. `non-functional.md` also needs the service owner per NFR (e.g. NFR-008 now means one image per service) | ✅ Resolved in branch `chore/docs-microservices-architecture` (2026-10-04) | Documentation | Closed |
| **GAP-14** | Cross-service flows without an FR | FR-202 (change password: `profile-service` UI, credential in `iam-service`), FR-206 (default preferences on `iam.UserRegistered`), FR-704 (session facts from `iam-service`, rollup in `analytics-service`) and FR-804 (unlock notification via events) cross a service boundary, but no FR or HU states the event or call that links them | Record the event/REST contract in the HU acceptance criteria and in `09-microservices/` | Team | Medium |

### Immediate work, no decision required

**GAP-05** is pending work, not a decision. **GAP-11** and **GAP-14** only need a requirement
sentence. Only **GAP-01** and **GAP-06** need the team and the instructor to decide.

### What the model gets right

Worth recording, because a gap list on its own misrepresents a model that is
well built:

- **Soft delete that preserves statistics** — `usage_events.user_id` and `audit_logs.user_id` with `ON DELETE SET NULL` let a user exercise their right to deletion without the reports collapsing
- **`gesture_samples` decoupled into MongoDB** — sample schemas change constantly as the model evolves; forcing them into the relational schema would mean a migration for every new metadata field
- **Consent as `NOT NULL`** — a sample without proof of consent cannot physically exist, which under Law 1581 is the difference between a usable dataset and an illegal one
- **Language-independent sign code** — `sign_lexicon.code` being the class the model predicts, separate from the displayed name, is what allows adding English without touching the AI model
- **No audio-only notification channel** — accessibility encoded as an enum constraint rather than a guideline cannot be violated by accident
- **Refresh token rotation with `replaced_by_token_id`** — makes reuse of a spent token detectable, which is the point of rotation and is frequently omitted

---

## 7. Coverage summary

| Check | Result |
|-------|--------|
| SRS requirements with at least one FR | 15 / 15 ✅ (RF1–RF7 + 8 ERF). Not counted: RF8 (proposed, not in the SRS) and 4 cross-cutting rows with no RF |
| FRs with at least one HU | 79 / 79 ✅ |
| HUs with a defined test case | 53 / 53 ✅ |
| Tests implemented | 0 / 53 🔴 (expected at baseline) |
| Tables justified by an FR | 25 / 29 ⚠️ (GAP-01 ×2, GAP-11 ×2) |
| FRs with a table that persists them | 74 / 79 ✅ (the other 5 — FR-401, FR-402, FR-405, FR-706, FR-952 — have no persistence by design, see § 3) |
| NFRs with a defined verification method | 10 / 10 ✅ |
| NFRs verified | 0 / 10 🔴 (expected at baseline) |

---

## How to maintain this matrix

1. When an HU is created → add its row in § 2 and § 5
2. When a test is written → note the file in "Test that verifies it"
3. When an HU is completed → change the status to ✅ in both sections
4. When a table is added to the model → add it to § 3 under its owning service with the FR that justifies it. **A table with no FR does not enter the model.**
5. At each Sprint Planning → review § 6 gaps and assign actions
6. At each Sprint Review → update § 7

---

## Change log

| Version | Date | Change | Author |
|---------|------|--------|--------|
| v0.1 | 2026-09-08 | Generic template replaced with the real matrix. Added the SRS → FR section and the FR → tables section, which is what surfaced GAP-01 and GAP-02. | Juan Mauricio Suaza Solórzano |
| v0.2 | 2026-09-08 | Test file names and tooling corrected to the real stack (Node/Express + Jest, not Java + JUnit). | Juan Mauricio Suaza Solórzano |
| v0.4 | 2026-10-24 | § 2 checked against the code: every FR now names its real test files and its real status (47 ✅, 10 🟡 partial, 20 🔴 not implemented, 2 ❔ not verified); the planned `*.spec.ts` names were removed. New status ❔. § 3 points to the implemented model in `06-data/models.md` § 0. Audit finding H-05. | Documentation |
| v0.3 | 2026-10-04 | "Module" column renamed to "Service" (iam, profile, lexicon, recognition, analytics) with a module → service table. § 3 regrouped by service; added FR-202, FR-302 and FR-804 to the tables that persist them; listed FR-401, FR-402, FR-405, FR-706 and FR-952 as explicit "no persistence". Added the `usage_daily_stats` and `session_daily_stats` rows; removed the already-dropped `sign_translations`. § 7 corrected (SRS 15/15, tables 25/29, FRs persisted 74/79). Closed GAP-02/03/04; added GAP-11 … GAP-14. | Documentation |

---

## Correlations

- User stories → `user-stories.md`
- Functional requirements → `functional.md`
- Non-functional requirements → `non-functional.md`
- Data model → `06-data/` (`traduce_senas.dbml`, model v9) · per-domain detail in `06-data/domains/`
- Services and ownership → `09-microservices/`
- Testing strategy → `11-quality/testing-strategy.md`
- DoD that determines when an HU is Done → `00-governance/definition-of-done.md`
