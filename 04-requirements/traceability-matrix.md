# Traceability Matrix

> **Status:** 🟡 Living document — v0.2
> **Last updated:** 2026-09-08
> **Baseline:** 79 FR · 10 NFR · 53 HU · 30 tables

> Traceability connects every line of code to its business justification.
> It answers: "Why does this function exist?" and "Which HU covers this part of the system?"
> It also exposes: unimplemented requirements, and code with no requirement behind it.

---

## How to read this matrix

```
SRS (RF/ERF) → FR → HU → Test case → Module → Tables

If an FR has no HU:        it is not planned
If an HU has no test:      it has no completeness criterion
If a test has no code:     there is test debt
If a table has no FR:      possible gold-plating   ← this is how GAP-01 was found
If an FR has no table:     a requirement nobody can persist
```

**Status legend**

| Status | Meaning |
|--------|---------|
| ✅ Done | Implemented, tested and merged |
| 🟡 In progress | In development in the current sprint |
| 🔴 Pending | In the backlog, not started |
| ⏸ Blocked | Has an external blocker |
| ❌ Cancelled | Removed from scope |

> At baseline every row is 🔴 Pending — the requirements exist, the code does not
> yet. Rows advance at each Sprint Review.

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

> **Note.** The last four rows are requirements that exist in the data model but
> have no RF in the SRS. Unlike RF8 they are not gold-plating — they are
> cross-cutting technical requirements every system needs. It is still worth
> naming them explicitly in the SRS so the traceability closes cleanly.

---

## 2. FR → HU → Test → Module matrix

### Identity

| FR | Description | HU | Test that verifies it | Module | Status |
|----|-------------|----|-----------------------|--------|--------|
| FR-001 | Registration with data + terms | HU-IAM-001 | `RegisterUser.spec.ts` | identity | 🔴 |
| FR-002 | Terms acceptance record | HU-IAM-001 | `TermsAcceptance.spec.ts` | identity | 🔴 |
| FR-003 | Verification with a 6-digit code | HU-IAM-002 | `EmailVerification.spec.ts` | identity | 🔴 |
| FR-004 | Hashed, expiring, single-use tokens | HU-IAM-002 | `UserToken.spec.ts` | identity | 🔴 |
| FR-005 | Login with email and password | HU-IAM-003 | `Login.spec.ts` | identity | 🔴 |
| FR-006 | Progressive lockout | HU-IAM-004 | `LockoutEscalation.spec.ts` | identity | 🔴 |
| FR-007 | Definitive block | HU-IAM-004 | `AccountBlock.spec.ts` | identity | 🔴 |
| FR-008 | Google / Facebook login | HU-IAM-005 | `OAuthProvider.spec.ts` | identity | 🔴 |
| FR-009 | Multiple linked providers | HU-IAM-005 | `ProviderLink.spec.ts` | identity | 🔴 |
| FR-010 | Password recovery | HU-IAM-006 | `PasswordReset.spec.ts` | identity | 🔴 |
| FR-011 | Session opening | HU-IAM-007 | `SessionLifecycle.spec.ts` | identity | 🔴 |
| FR-012 | Refresh token rotation | HU-IAM-007 | `RefreshTokenRotation.spec.ts` | identity | 🔴 |
| FR-013 | Logout with duration | HU-IAM-008 | `SessionLifecycle.spec.ts` | identity | 🔴 |
| FR-014 | Deletion with anonymization | HU-IAM-009 | `AccountDeletion.spec.ts` | identity | 🔴 |
| FR-015 | Account administration | HU-IAM-010 | `AdminUserManagement.spec.ts` | identity | 🔴 |

### Authorization

| FR | Description | HU | Test that verifies it | Module | Status |
|----|-------------|----|-----------------------|--------|--------|
| FR-101 | RBAC with multiple roles | HU-AUTHZ-001 | `RoleAssignment.spec.ts` | authorization | 🔴 |
| FR-102 | Permissions independent of roles | HU-AUTHZ-001 | `PermissionModel.spec.ts` | authorization | 🔴 |
| FR-103 | Administration access denied | HU-AUTHZ-002 | `AdminAccessControl.spec.ts` | authorization | 🔴 |
| FR-104 | Role in use cannot be deleted | HU-AUTHZ-002 | `RoleDeletion.spec.ts` | authorization | 🔴 |

### Profile

| FR | Description | HU | Test that verifies it | Module | Status |
|----|-------------|----|-----------------------|--------|--------|
| FR-201 | View and edit profile | HU-PROF-001 | `ProfileUpdate.spec.ts` | profile | 🔴 |
| FR-202 | Change password | HU-PROF-002 | `ChangePassword.spec.ts` | profile | 🔴 |
| FR-203 | Light / dark theme | HU-PROF-003 | `Preferences.spec.ts` | profile | 🔴 |
| FR-204 | Interface language | HU-PROF-004 | `Preferences.spec.ts` | profile | 🔴 |
| FR-205 | Notification switch | HU-PROF-005 | `Preferences.spec.ts` | profile | 🔴 |
| FR-206 | Default preferences on creation | HU-PROF-003 | `DefaultPreferences.spec.ts` | profile | 🔴 |

### Lexicon

| FR | Description | HU | Test that verifies it | Module | Status |
|----|-------------|----|-----------------------|--------|--------|
| FR-301 | Catalog by category | HU-LEX-001 | `LexiconBrowse.spec.ts` | lexicon | 🔴 |
| FR-302 | Search by name | HU-LEX-002 | `LexiconSearch.spec.ts` | lexicon | 🔴 |
| FR-303 | Detail with multimedia | HU-LEX-003 | `SignDetail.spec.ts` | lexicon | 🔴 |
| FR-304 | Alphabet with no duplicate letters | HU-LEX-004 | `Alphabet.spec.ts` | lexicon | 🔴 |
| FR-305 | Language-independent stable code | HU-LEX-005 | `SignCode.spec.ts` | lexicon | 🔴 |
| FR-306 | Localization per language | HU-LEX-005 | `SignLocalization.spec.ts` | lexicon | 🔴 |
| FR-307 | Sign administration | HU-LEX-006 | `SignAdmin.spec.ts` | lexicon | 🔴 |
| FR-308 | Category administration | HU-LEX-006 | `CategoryAdmin.spec.ts` | lexicon | 🔴 |
| FR-309 | Ordered resources | HU-LEX-007 | `MultimediaOrder.spec.ts` | lexicon | 🔴 |
| FR-310 | Only ACTIVE signs are visible | HU-LEX-006 | `LexiconBrowse.spec.ts` | lexicon | 🔴 |

### Translation

| FR | Description | HU | Test that verifies it | Module | Status |
|----|-------------|----|-----------------------|--------|--------|
| FR-401 | Live camera translation | HU-TRA-001 | `TranslationE2E.spec.ts` (app) | translation | 🔴 |
| FR-402 | Audio output | HU-TRA-002 | `AudioOutput.spec.ts` (app) | translation | 🔴 |
| FR-403 | Persist with model and confidence | HU-TRA-003 | `TranslationPersistence.spec.ts` | translation | 🔴 |
| FR-404 | Ordered signs of the translation | HU-TRA-003 | `TranslationSignsOrder.spec.ts` | translation | 🔴 |
| FR-405 | Failed recognition feedback | HU-TRA-004 | `TranslationFailure.spec.ts` (app) | translation | 🔴 |
| FR-406 | History newest first | HU-TRA-005 | `TranslationHistory.spec.ts` | translation | 🔴 |
| FR-407 | Logical deletion of an entry | HU-TRA-006 | `HistoryDelete.spec.ts` | translation | 🔴 |
| FR-408 | Model with history is undeletable | HU-TRA-003 | `ModelDeletionGuard.spec.ts` | translation | 🔴 |

### Notification

| FR | Description | HU | Test that verifies it | Module | Status |
|----|-------------|----|-----------------------|--------|--------|
| FR-501 | Administrable type catalog | HU-NOTIF-001 | `NotificationTypeAdmin.spec.ts` | notification | 🔴 |
| FR-502 | Visual channel only ⭐ | HU-NOTIF-002 | `VisualChannelContract.spec.ts` | notification | 🔴 |
| FR-503 | Device registration | HU-NOTIF-003 | `DeviceRegistration.spec.ts` | notification | 🔴 |
| FR-504 | Scheduled notifications | HU-NOTIF-004 | `ScheduledNotification.spec.ts` | notification | 🔴 |
| FR-505 | FAILED vs PENDING state | HU-NOTIF-005 | `DeliveryFailure.spec.ts` | notification | 🔴 |
| FR-506 | Reference to the originating record | HU-NOTIF-006 | `NotificationReference.spec.ts` | notification | 🔴 |
| FR-507 | Mark as read | HU-NOTIF-002 | `NotificationRead.spec.ts` | notification | 🔴 |
| FR-508 | Master switch suppresses delivery | HU-PROF-005 | `NotificationOptOut.spec.ts` | notification | 🔴 |
| FR-509 | Push requires a device | HU-NOTIF-003 | `PushDeviceConstraint.spec.ts` | notification | 🔴 |

### AI

| FR | Description | HU | Test that verifies it | Module | Status |
|----|-------------|----|-----------------------|--------|--------|
| FR-601 | Capture grouped by session | HU-AI-001 | `SampleCapture.spec.ts` | ai | 🔴 |
| FR-602 | Demonstrable consent ⚖️ | HU-AI-002 | `ConsentRequired.spec.ts` | ai | 🔴 |
| FR-603 | Discard a full session | HU-AI-001 | `SessionDiscard.spec.ts` | ai | 🔴 |
| FR-604 | Validation before training | HU-AI-003 | `SampleValidation.spec.ts` | ai | 🔴 |
| FR-605 | Model registry with metrics | HU-AI-004 | `ModelRegistry.spec.ts` | ai | 🔴 |
| FR-606 | Exactly one active model | HU-AI-005 | `SingleActiveModel.spec.ts` | ai | 🔴 |
| FR-607 | Samples in MongoDB, decoupled | HU-AI-001 | `SampleRepository.spec.ts` | ai | 🔴 |

### Usage

| FR | Description | HU | Test that verifies it | Module | Status |
|----|-------------|----|-----------------------|--------|--------|
| FR-701 | Section entry event | HU-USG-001 | `UsageEvent.spec.ts` | usage | 🔴 |
| FR-702 | Functional events | HU-USG-001 | `UsageEventTypes.spec.ts` | usage | 🔴 |
| FR-703 | Most visited sections | HU-USG-002 | `SectionStats.spec.ts` | usage | 🔴 |
| FR-704 | Sessions and average duration | HU-USG-003 | `SessionStats.spec.ts` | usage | 🔴 |
| FR-705 | Events survive deletion | HU-USG-004 | `StatsSurviveDeletion.spec.ts` | usage | 🔴 |
| FR-706 | Statistics require permission | HU-AUTHZ-002 | `AdminAccessControl.spec.ts` | usage | 🔴 |

### Gamification ⚠️

| FR | Description | HU | Test that verifies it | Module | Status |
|----|-------------|----|-----------------------|--------|--------|
| FR-801 | Achievement catalog | HU-GAM-001 | `AchievementCatalog.spec.ts` | gamification | ⏸ Blocked |
| FR-802 | Progress tracking | HU-GAM-002 | `AchievementProgress.spec.ts` | gamification | ⏸ Blocked |
| FR-803 | Unlock exactly once | HU-GAM-002 | `AchievementUnlock.spec.ts` | gamification | ⏸ Blocked |
| FR-804 | Unlock notification | HU-GAM-003 | `AchievementNotification.spec.ts` | gamification | ⏸ Blocked |
| FR-805 | Consult achievements | HU-GAM-004 | `UserAchievements.spec.ts` | gamification | ⏸ Blocked |

> **Blocker:** RF8 does not exist in the SRS. See § Gaps, GAP-01.

### Audit and configuration

| FR | Description | HU | Test that verifies it | Module | Status |
|----|-------------|----|-----------------------|--------|--------|
| FR-901 | Audit with before/after values | HU-AUD-001 | `AuditLog.spec.ts` | audit | 🔴 |
| FR-902 | Trail survives deletion | HU-AUD-001 | `AuditSurvivesDeletion.spec.ts` | audit | 🔴 |
| FR-903 | Technical error log | HU-AUD-002 | `ErrorLog.spec.ts` | audit | 🔴 |
| FR-904 | Classification by error type | HU-AUD-002 | `ErrorTypeClassification.spec.ts` | audit | 🔴 |
| FR-905 | Configurable password policy | HU-CFG-001 | `PasswordPolicyAdmin.spec.ts` | configuration | 🔴 |
| FR-906 | Validation against the active policy | HU-CFG-001 | `PasswordValidation.spec.ts` | configuration | 🔴 |
| FR-907 | Historical policies preserved | HU-CFG-001 | `PolicyHistory.spec.ts` | configuration | 🔴 |

### Navigation

| FR | Description | HU | Test that verifies it | Module | Status |
|----|-------------|----|-----------------------|--------|--------|
| FR-951 | Navigation between sections | HU-NAV-001 | `Navigation.spec.ts` (app) | ui | 🔴 |
| FR-952 | No dead-end screens | HU-NAV-001 | `Navigation.spec.ts` (app) | ui | 🔴 |

---

## 3. FR → tables matrix

The check nobody usually runs: does each FR have somewhere to store its data,
and does each table have a requirement justifying it?

| Table | FRs that justify it | Status |
|-------|---------------------|--------|
| `users` | FR-001 … FR-007, FR-014, FR-015, FR-201 | ✅ Justified |
| `user_auth_providers` | FR-008, FR-009 | ✅ Justified |
| `user_sessions` | FR-011, FR-013, FR-704 | ✅ Justified |
| `refresh_tokens` | FR-012 | ✅ Justified |
| `user_tokens` | FR-003, FR-004, FR-010 | ✅ Justified |
| `roles` | FR-101, FR-104 | ✅ Justified |
| `permissions` | FR-102 | ✅ Justified |
| `user_roles` | FR-101 | ✅ Justified |
| `role_permissions` | FR-102, FR-103 | ✅ Justified |
| `user_preferences` | FR-203 … FR-206, FR-508 | ✅ Justified |
| `categories` | FR-301, FR-308 | ✅ Justified |
| `sign_lexicon` | FR-301, FR-304, FR-305, FR-307, FR-310 | ✅ Justified |
| `sign_localizations` | FR-306 | ✅ Justified |
| `sign_translations` | — | ❌ **GAP-02: duplicate of `sign_localizations`** |
| `multimedia_resources` | FR-303, FR-309 | ✅ Justified |
| `translations` | FR-403, FR-406, FR-407 | ✅ Justified |
| `translation_signs` | FR-404 | ✅ Justified |
| `ai_models` | FR-403, FR-408, FR-605, FR-606 | ✅ Justified |
| `gesture_samples` (MongoDB) | FR-601 … FR-604, FR-607 | ✅ Justified |
| `notification_types` | FR-501 | ✅ Justified |
| `user_devices` | FR-503, FR-509 | ✅ Justified |
| `notifications` | FR-502, FR-504 … FR-507 | ✅ Justified |
| `usage_events` | FR-701, FR-702, FR-703, FR-705, FR-951 | ✅ Justified |
| `achievements` | FR-801 | ⚠️ **GAP-01: depends on RF8** |
| `user_achievements` | FR-802, FR-803, FR-805 | ⚠️ **GAP-01: depends on RF8** |
| `audit_logs` | FR-901, FR-902 | ✅ Justified |
| `error_logs` | FR-903, FR-904 | ✅ Justified |
| `password_policies` | FR-905 … FR-907 | ✅ Justified |

**Result:** 26 of 28 tables justified. 1 duplicate (GAP-02), 2 conditional on RF8 (GAP-01).

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
| **GAP-02** | Duplicate table | `sign_translations` and `sign_localizations` are the same table twice — same columns, same unique index `(sign_id, ui_language)`, same explanatory note copied across. `sign_localizations` is the one in the `TableGroup`; `sign_translations` is orphaned, the leftover of a rename | Remove the `Table sign_translations` block and the line `Ref: sign_translations.sign_id > sign_lexicon.sign_id`. Keep `sign_localizations`: it is in the TableGroup and its `(ui_language, name)` index is what FR-302 search needs | Juan Mauricio | **High** |
| **GAP-03** | Non-existent table cited | The traceability comment at the end of the DBML cites `password_reset_tokens`. That table does not exist — `user_tokens` does both jobs through its `token_type` enum | In the RF1 line of the comment, replace `password_reset_tokens` with `user_tokens` | Juan Mauricio | Medium |
| **GAP-04** | Incorrect statement | The DBML states RF2 is "solo UI, sin persistencia", but every section entry is persisted as `SECTION_VIEW` in `usage_events` — that is what makes RF6 possible, and the whole reason the `usage_section` enum exists | Change the RF2 line to: "sin tablas propias; cada entrada a una sección se registra como SECTION_VIEW en usage_events (insumo de RF6)" | Juan Mauricio | Low |
| **GAP-05** | Constraints declared but not written | The DBML lists six constraints delegated to `migrations/002_constraints.sql` and ends with `// ...`. Four more that the requirements demand are missing: `multimedia_resources.position >= 1` (FR-309), `password_policies.min_length <= max_length` (FR-905), a single active `password_policies` row (FR-905), and `achievements.target_count > 0` (FR-801, if RF8 is approved) | Complete the comment list and **write `migrations/002_constraints.sql`**. A constraint that lives only in a comment is a comment: the database will accept `confidence = 47.3` until the DDL says otherwise | Juan Mauricio | **High** |
| **GAP-06** | Nullable field that should not be | `translations.model_id` is nullable, but FR-403 requires every translation to record the model that produced it and FR-408 relies on that link. Nullable means a translation can exist with no traceability, defeating the field's stated purpose. Likely reason: translations queued while the connection was down | **Decision.** Make it `not null` and resolve the active model before insert — whichever side runs inference knows which version it used. Alternatively keep it nullable and document exactly what `NULL` means, plus a backfill job | Team | Medium |
| **GAP-07** | Enum values with no consumer | `reference_entity` declares `CATEGORY`, `AI_MODEL` and `USER`, which no FR produces. `usage_section.ACHIEVEMENTS` depends on GAP-01 | Low impact — an unused enum value costs nothing at runtime. Either document them as reserved extension points or trim them, so a future reader does not hunt for code that does not exist | Juan Mauricio | Low |
| **GAP-08** | RF without an explicit SRS entry | Audit, error handling, password policy and Law 1581 compliance have tables and FRs but no RF in the SRS. Unlike GAP-01 these are not gold-plating — they are cross-cutting technical requirements every system needs — but the traceability does not close cleanly without them | Name them explicitly in the SRS as cross-cutting requirements | Team | Medium |
| **GAP-09** | FR without a test | Every FR is at 🔴 Pending — no test exists yet | Write the test alongside each HU, never after | Team | Expected at baseline |
| **GAP-10** | Overloaded sprints | Sprints 4, 5 and 6 exceed 40 points with velocity still unmeasured | Measure real velocity in Sprint 1 and rebalance from Sprint 4 onwards | Team | Medium |

### Immediate work, no decision required

**GAP-02, GAP-03 and GAP-04** are three edits to the DBML that close the
traceability without changing a single design decision. **GAP-05** is pending
work, not a decision. Only **GAP-01** and **GAP-06** need the team and the
instructor to decide.

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
| SRS requirements with at least one FR | 17 / 17 ✅ |
| FRs with at least one HU | 79 / 79 ✅ |
| HUs with a defined test case | 53 / 53 ✅ |
| Tests implemented | 0 / 53 🔴 (expected at baseline) |
| Tables justified by an FR | 26 / 28 ⚠️ (GAP-01, GAP-02) |
| FRs with a table that persists them | 77 / 79 ✅ (FR-951, FR-952 are UI, correctly without their own table) |
| NFRs with a defined verification method | 10 / 10 ✅ |
| NFRs verified | 0 / 10 🔴 (expected at baseline) |

---

## How to maintain this matrix

1. When an HU is created → add its row in § 2 and § 5
2. When a test is written → note the file in "Test that verifies it"
3. When an HU is completed → change the status to ✅ in both sections
4. When a table is added to the model → add it to § 3 with the FR that justifies it. **A table with no FR does not enter the model.**
5. At each Sprint Planning → review § 6 gaps and assign actions
6. At each Sprint Review → update § 7

---

## Change log

| Version | Date | Change | Author |
|---------|------|--------|--------|
| v0.1 | 2026-09-08 | Generic template replaced with the real matrix. Added the SRS → FR section and the FR → tables section, which is what surfaced GAP-01 and GAP-02. | Juan Mauricio Suaza Solórzano |
| v0.2 | 2026-09-08 | Test file names and tooling corrected to the real stack (Node/Express + Jest, not Java + JUnit). | Juan Mauricio Suaza Solórzano |

---

## Correlations

- User stories → `user-stories.md`
- Functional requirements → `functional.md`
- Non-functional requirements → `non-functional.md`
- Data model → `06-data/` (`traduce_senas_v8.dbml`)
- Testing strategy → `11-quality/testing-strategy.md`
- DoD that determines when an HU is Done → `00-governance/definition-of-done.md`
