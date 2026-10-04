# Functional Requirements (FR)

> **Status:** 🟡 Living document — v0.2
> **Last updated:** 2026-10-04
> **Baseline:** 79 FR across 11 modules (62 Must · 12 Should · 5 Could)
> **Scope:** TraduceSeña 2.0 — React Native / Expo mobile app + Node/Express microservices behind an API gateway (iam, recognition, lexicon, analytics, profile) + PostgreSQL (one database per service) + MongoDB

> Functional requirements define **what the system does**. Each FR is atomic, verifiable
> and traced to the SRS requirement that originates it, the user story (HU) that plans it,
> and the tables that persist it.

> ⚠️ **This catalog is a reconstruction.** It was rebuilt from the data model (v9), the
> domain documents (`02-domain/`), the user stories and the traceability matrix. It must be
> **reviewed against the actual SRS**; where they disagree, the SRS wins. See `README.md`.

---

## How to read this catalog

| Column | Meaning |
|--------|---------|
| **FR** | Requirement ID. Series by module (see numbering below) so a module can grow without renumbering |
| **Requirement** | What the system must do, in testable terms |
| **SRS** | Originating requirement (RF / ERF) in the SRS. `—` means a cross-cutting technical requirement with no explicit RF (GAP-08) |
| **HU** | User story that plans it (`user-stories.md`) |
| **Priority** | MoSCoW priority, inherited from the planning HU: **M**ust · **S**hould · **C**ould |
| **Tables** | Where it is persisted (`06-data/`). `—` means nothing is persisted by this FR itself |

### Numbering

| Series | Module | Owning service | HU prefix |
|--------|--------|----------------|-----------|
| FR-0xx | Identity | `iam-service` | `HU-IAM` |
| FR-1xx | Authorization | `iam-service` | `HU-AUTHZ` |
| FR-2xx | Profile | `profile-service` | `HU-PROF` |
| FR-3xx | Lexicon | `lexicon-service` | `HU-LEX` |
| FR-4xx | Translation | `recognition-service` | `HU-TRA` |
| FR-5xx | Notification | `profile-service` | `HU-NOTIF` |
| FR-6xx | AI | `recognition-service` (PostgreSQL + MongoDB) | `HU-AI` |
| FR-7xx | Usage | `analytics-service` | `HU-USG` |
| FR-8xx | Gamification ⚠️ conditional on RF8 | `profile-service` | `HU-GAM` |
| FR-9xx | Audit / Configuration | `iam-service` | `HU-AUD`, `HU-CFG` |
| FR-95x | Navigation | Mobile app (UI); events go to `analytics-service` | `HU-NAV` |

### Summary by module

| Module | Owning service | FRs | Must | Should | Could |
|--------|----------------|-----|------|--------|-------|
| Identity | iam-service | 15 | 13 | 2 | 0 |
| Authorization | iam-service | 4 | 4 | 0 | 0 |
| Profile | profile-service | 6 | 3 | 3 | 0 |
| Lexicon | lexicon-service | 10 | 10 | 0 | 0 |
| Translation | recognition-service | 8 | 6 | 2 | 0 |
| Notification | profile-service | 9 | 7 | 2 | 0 |
| AI | recognition-service | 7 | 7 | 0 | 0 |
| Usage | analytics-service | 6 | 6 | 0 | 0 |
| Gamification ⚠️ | profile-service | 5 | 0 | 0 | 5 |
| Audit / Configuration | iam-service | 7 | 4 | 3 | 0 |
| Navigation | mobile app (UI) | 2 | 2 | 0 | 0 |
| **Total** | | **79** | **62** | **12** | **5** |

---

## 1. Identity (FR-0xx)

| FR | Requirement | SRS | HU | Priority | Tables |
|----|-------------|-----|----|----------|--------|
| FR-001 | The system must register a user with full name, birth date, username, email and a password that satisfies the active policy. The account is created `INACTIVE` until the email is verified | RF1, ERF1.1 | HU-IAM-001 | M | `users` |
| FR-002 | The system must refuse registration unless the terms are accepted, and must store the acceptance timestamp and the terms version (INV-002) | ERF1.1 | HU-IAM-001 | M | `users` |
| FR-003 | The system must verify the email with a 6-digit code sent to the address | RF1 | HU-IAM-002 | M | `user_tokens` |
| FR-004 | Verification and recovery codes must be stored only as a hash, expire, be single-use and count failed attempts (INV-015) | RF1 | HU-IAM-002 | M | `user_tokens` |
| FR-005 | The system must authenticate a user with email and password | RF1 | HU-IAM-003 | M | `users` |
| FR-006 | The system must lock an account temporarily after repeated failed sign-ins, with escalating waits of 1, 5 and 10 minutes. The lockout is a date that lifts by itself, and the level resets after 24 hours without failures (INV-014) | RF1 | HU-IAM-004 | M | `users` |
| FR-007 | The system must block an account definitively once the lockout escalation is exhausted. Only an administrator can restore it | RF1 | HU-IAM-004 | M | `users` |
| FR-008 | The system must allow registration and sign-in with Google and Facebook. Accounts created this way are verified immediately | RF1, ERF1.2 | HU-IAM-005 | M | `user_auth_providers` |
| FR-009 | A user may link several external providers, but one `(provider, external id)` pair belongs to a single account (INV-004) | RF1, ERF1.2 | HU-IAM-005 | M | `user_auth_providers` |
| FR-010 | The system must let a user recover a forgotten password through a single-use, expiring token | RF1 | HU-IAM-006 | M | `user_tokens` |
| FR-011 | The system must open a session on successful sign-in | RF1 | HU-IAM-007 | M | `user_sessions` |
| FR-012 | The system must rotate refresh tokens on every use and must make reuse of a spent token detectable | RF1 | HU-IAM-007 | M | `refresh_tokens` |
| FR-013 | The system must close the session on logout and record its duration | RF1 | HU-IAM-008 | M | `user_sessions` |
| FR-014 | The system must let a user delete their account, anonymizing the row instead of removing it (Law 1581 of 2012) | RF1, RF5 | HU-IAM-009 | S | `users` |
| FR-015 | An administrator must be able to list, view, block, restore and deactivate user accounts | RF1, RF6 | HU-IAM-010 | S | `users` |

---

## 2. Authorization (FR-1xx)

| FR | Requirement | SRS | HU | Priority | Tables |
|----|-------------|-----|----|----------|--------|
| FR-101 | The system must implement role-based access control: a user may hold several roles (`USER`, `ADMIN`, `LINGUIST`) | RF6 | HU-AUTHZ-001 | M | `roles`, `user_roles` |
| FR-102 | Permissions must be independent entities granted to roles and never directly to users (INV-016) | RF6 | HU-AUTHZ-001 | M | `permissions`, `role_permissions` |
| FR-103 | The system must deny access to administration functions to users without the required permission | RF6 | HU-AUTHZ-002 | M | `role_permissions` |
| FR-104 | A role assigned to at least one user must not be deletable (INV-017) | RF6 | HU-AUTHZ-002 | M | `roles` |

---

## 3. Profile (FR-2xx)

| FR | Requirement | SRS | HU | Priority | Tables |
|----|-------------|-----|----|----------|--------|
| FR-201 | The user must be able to view and edit their profile data | RF5, ERF1.1, ERF5.1 | HU-PROF-001 | M | `users` |
| FR-202 | The user must be able to change their password, which must satisfy the active policy | RF5 | HU-PROF-002 | M | `users` |
| FR-203 | The user must be able to choose a light or dark theme | RF5, ERF5.2 | HU-PROF-003 | S | `user_preferences` |
| FR-204 | The user must be able to choose the interface language | RF5, ERF5.4 | HU-PROF-004 | S | `user_preferences` |
| FR-205 | The user must be able to turn notifications on or off with a single master switch | RF4, RF5 | HU-PROF-005 | M | `user_preferences` |
| FR-206 | The system must create default preferences when an account is created | ERF5.2 | HU-PROF-003 | S | `user_preferences` |

---

## 4. Lexicon (FR-3xx)

| FR | Requirement | SRS | HU | Priority | Tables |
|----|-------------|-----|----|----------|--------|
| FR-301 | The system must present the sign catalog organized by category | RF7 | HU-LEX-001 | M | `categories`, `sign_lexicon` |
| FR-302 | The user must be able to search the catalog by sign name | RF7 | HU-LEX-002 | M | `sign_localizations` |
| FR-303 | The system must show a sign's detail with its multimedia resources | RF7 | HU-LEX-003 | M | `multimedia_resources` |
| FR-304 | The system must present the alphabet (A–Z plus Ñ) with no repeated letter per sign language (INV-013) | RF7 | HU-LEX-004 | M | `sign_lexicon` |
| FR-305 | Every sign must have a stable code independent of language; it is never renamed once published (INV-018) | RF7 | HU-LEX-005 | M | `sign_lexicon` |
| FR-306 | Every sign must have at most one written localization per interface language | RF7, ERF5.4 | HU-LEX-005 | M | `sign_localizations` |
| FR-307 | An administrator must be able to create, edit and withdraw signs | RF7 | HU-LEX-006 | M | `sign_lexicon` |
| FR-308 | An administrator must be able to manage categories. A category with signs is not deletable (INV-021) | RF7 | HU-LEX-006 | M | `categories` |
| FR-309 | A sign's multimedia resources must be ordered, with no two at the same position and `position >= 1` (INV-020) | RF7 | HU-LEX-007 | M | `multimedia_resources` |
| FR-310 | Only signs with status `ACTIVE` must be visible to end users (INV-019) | RF7 | HU-LEX-006 | M | `sign_lexicon` |

---

## 5. Translation (FR-4xx)

| FR | Requirement | SRS | HU | Priority | Tables |
|----|-------------|-----|----|----------|--------|
| FR-401 | The system must capture sign language through the device camera and translate it into written text in real time ⭐ | RF3 | HU-TRA-001 | M | — |
| FR-402 | The system must offer audio output of the translation, always accompanied by the visible text | RF3, ERF3.2 | HU-TRA-002 | S | — |
| FR-403 | Every persisted translation must record the model that produced it and its confidence | RF3 | HU-TRA-003 | M | `translations` |
| FR-404 | A translation must keep the ordered list of signs that compose it | RF3 | HU-TRA-003 | M | `translation_signs` |
| FR-405 | When recognition fails or falls below the confidence threshold, the system must tell the user visually instead of showing a wrong translation (INV-007) | RF3 | HU-TRA-004 | M | — |
| FR-406 | The user must be able to see their translation history, newest first. The history is private to its owner (INV-011) | RF3, RF5 | HU-TRA-005 | M | `translations` |
| FR-407 | The user must be able to delete history entries. Deletion is logical and irreversible for the user | RF5, ERF5.5 | HU-TRA-006 | S | `translations` |
| FR-408 | A model that has produced translations must not be deletable (INV-022) | RF3 | HU-TRA-003 | M | `ai_models` |

---

## 6. Notification (FR-5xx)

| FR | Requirement | SRS | HU | Priority | Tables |
|----|-------------|-----|----|----------|--------|
| FR-501 | An administrator must be able to manage the catalog of notification types and activate or withdraw each one | RF4 | HU-NOTIF-001 | M | `notification_types` |
| FR-502 | Every notification must be delivered through a visual channel only (`PUSH`, `IN_APP`, `EMAIL`). No audio-only channel may exist (INV-023) ⭐ | RF4, ERF4.1 | HU-NOTIF-002 | M | `notifications` |
| FR-503 | The system must register the user's devices for push delivery and deactivate a device whose token the provider rejects | RF4 | HU-NOTIF-003 | M | `user_devices` |
| FR-504 | The system must support scheduled notifications | RF4 | HU-NOTIF-004 | S | `notifications` |
| FR-505 | The system must distinguish `FAILED` deliveries from `PENDING` ones | RF4 | HU-NOTIF-005 | M | `notifications` |
| FR-506 | A notification may reference the record that caused it, by type and id, without a foreign key | RF4 | HU-NOTIF-006 | S | `notifications` |
| FR-507 | The user must be able to mark a notification as read | RF4 | HU-NOTIF-002 | M | `notifications` |
| FR-508 | With the master switch off, the system must create no new notification through any channel; those already received stay visible (INV-025) | RF4 | HU-PROF-005 | M | `user_preferences` |
| FR-509 | A notification on the `PUSH` channel must have a target device, and must not have one on other channels (INV-024) | RF4 | HU-NOTIF-003 | M | `user_devices`, `notifications` |

---

## 7. AI (FR-6xx)

| FR | Requirement | SRS | HU | Priority | Tables |
|----|-------------|-----|----|----------|--------|
| FR-601 | A linguist must be able to capture gesture samples, grouped by capture session | RF3 | HU-AI-001 | M | `gesture_samples` (MongoDB) |
| FR-602 | No sample may be stored without demonstrable consent from the data subject ⚖️ Law 1581 of 2012 | — | HU-AI-002 | M | `gesture_samples` (MongoDB) |
| FR-603 | A linguist must be able to discard a full capture session | RF3 | HU-AI-001 | M | `gesture_samples` (MongoDB) |
| FR-604 | Samples must be validated before they are used for training | RF3 | HU-AI-003 | M | `gesture_samples` (MongoDB) |
| FR-605 | The system must keep a registry of models with their training metrics (sample count, sign count, accuracy) | RF3 | HU-AI-004 | M | `ai_models` |
| FR-606 | Exactly one model must be active at any time. Activation deactivates the previous one in the same operation (INV-022) | RF3 | HU-AI-005 | M | `ai_models` |
| FR-607 | Samples must live in MongoDB, decoupled from the relational schema | RF3 | HU-AI-001 | M | `gesture_samples` (MongoDB) |

---

## 8. Usage (FR-7xx)

| FR | Requirement | SRS | HU | Priority | Tables |
|----|-------------|-----|----|----------|--------|
| FR-701 | The system must record an event each time a user enters an application section | RF6, RF2 | HU-USG-001 | M | `usage_events` |
| FR-702 | The system must record functional events (translation started, completed, failed, audio played, search performed) | RF6 | HU-USG-001 | M | `usage_events` |
| FR-703 | An administrator must be able to see the most visited sections | RF6 | HU-USG-002 | M | `usage_events` |
| FR-704 | An administrator must be able to see sessions and their average duration | RF6 | HU-USG-003 | M | `user_sessions` |
| FR-705 | Usage events must survive account deletion (`user_id` becomes null) | RF6 | HU-USG-004 | M | `usage_events` |
| FR-706 | Statistics must be accessible only with the required permission, and always aggregated (INV-012) | RF6 | HU-AUTHZ-002 | M | — |

---

## 9. Gamification (FR-8xx) ⚠️

> **Conditional on RF8, which is not in the SRS** (GAP-01). Nothing in this module is built
> until the team and the instructor decide. If RF8 is rejected, this series is removed
> together with its tables and EP-009. HUs are created `⏸ Blocked`.

| FR | Requirement | SRS | HU | Priority | Tables |
|----|-------------|-----|----|----------|--------|
| FR-801 | The system must keep a catalog of achievements, each with a target count greater than zero | RF8 | HU-GAM-001 | C | `achievements` |
| FR-802 | The system must track each user's progress toward achievements | RF8 | HU-GAM-002 | C | `user_achievements` |
| FR-803 | An achievement unlocks exactly once per user (INV-027) | RF8 | HU-GAM-002 | C | `user_achievements` |
| FR-804 | Unlocking an achievement must notify the user through a visual channel | RF8 | HU-GAM-003 | C | `notifications` |
| FR-805 | The user must be able to consult their achievements | RF8 | HU-GAM-004 | C | `user_achievements` |

---

## 10. Audit and configuration (FR-9xx)

| FR | Requirement | SRS | HU | Priority | Tables |
|----|-------------|-----|----|----------|--------|
| FR-901 | The system must keep an audit trail of changes with before and after values | — | HU-AUD-001 | M | `audit_logs` |
| FR-902 | The audit trail must survive deletion of the acting user | — | HU-AUD-001 | M | `audit_logs` |
| FR-903 | The system must keep a technical error log | — | HU-AUD-002 | M | `error_logs` |
| FR-904 | Errors must be classified by type (`VALIDATION`, `AUTH`, `PERMISSION`, `NOT_FOUND`, `MODEL_INFERENCE`, `EXTERNAL_SERVICE`, `DATABASE`, `UNEXPECTED`) | — | HU-AUD-002 | M | `error_logs` |
| FR-905 | An administrator must be able to configure the password policy: length bounds (`min_length <= max_length`) and required character classes. Exactly one policy is active (INV-026) | — | HU-CFG-001 | S | `password_policies` |
| FR-906 | Passwords must be validated against the active policy | — | HU-CFG-001 | S | `password_policies` |
| FR-907 | Superseded policies must be preserved as history, never overwritten | — | HU-CFG-001 | S | `password_policies` |

> **Note.** Since model v9, `password_policies` belongs to the Identity domain (DATA-12,
> `06-data/domains/01-identity.md`). The FR-905 … FR-907 numbers stay in the 900 series to
> avoid renumbering.

---

## 11. Navigation (FR-95x)

| FR | Requirement | SRS | HU | Priority | Tables |
|----|-------------|-----|----|----------|--------|
| FR-951 | The user must be able to move between the application's sections. Each section entry is recorded as an event for RF6 | RF2 | HU-NAV-001 | M | `usage_events` |
| FR-952 | No screen may be a dead end: every screen offers a way to navigate onward or back | RF2 | HU-NAV-001 | M | — |

---

## Correlations

- Planning → `user-stories.md`
- Traceability (SRS → FR → HU → test → tables, and the gaps) → `traceability-matrix.md`
- Quality attributes → `non-functional.md`
- Domain invariants cited above (INV-xxx) → `02-domain/entities-and-rules.md`
- Persistence → `06-data/domains/`

---

## Change log

| Version | Date | Change | Author |
|---------|------|--------|--------|
| v0.1 | 2026-09-08 | Catalog created. The README promised it and it did not exist. Priorities derived from the planning HU of each FR. | Juan Mauricio Suaza Solórzano |
| v0.2 | 2026-10-04 | Scope updated to microservices; owning service added per module (numbering and summary tables). | Documentation |
