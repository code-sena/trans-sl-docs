# Data Model — Profile Service

> `profile-service` is the **authoritative owner** of the data described here. No other service reads these tables.
> Full DDL and data dictionary: `06-data/domains/03-profile.md`, `07-notification.md`, `09-gamification.md`; this file is the service view.

---

## Implemented today

Taken from the migrations of Backend `develop` `2e0816f` (`services/profile-service/db/`, applied in order by `docker-compose.yml`). Tables marked † are in `develop` but not yet deployed (production runs v1.3.0). PostgreSQL database `profile`, schema `public` (no `profile`, `notification` or `gamification` schemas). Keys are UUID; `user_id` is VARCHAR(64). Gamification is implemented (achievements and daily challenges).

| Table | Key columns | Notes |
|-------|-------------|-------|
| `user_profiles` | `user_id`, `email`, `full_name`, `username` | Copy received in `iam.UserRegistered` |
| `user_preferences` | `user_id` UNIQUE, `ui_language` (`ES`, `EN`, `FR`, `PT`), `theme`, `notifications_enabled` | `001`, `003` |
| `notification_types`, `notifications` | `channel` (`IN_APP`, `EMAIL`; `PUSH` unused, ADR-007), `status` (`PENDING`, `SENT`, `FAILED`, `READ`, `CANCELLED`), `scheduled_at`, `reference_type`, `reference_id` | Email queue of ADR-007 |
| `achievements`, `user_achievements` | catalog with `metric`, `target_count`, `points`, `collection`, `availability`, `category`, `level`, `localizations` JSONB; progress per user | `001`, `004` to `007` |
| `achievement_activity`, `achievement_translation_receipts` | activity state JSONB per user; translations already counted | `007` |
| `processed_events` | `event_id` | Idempotency of the consumers |
| `erased_users` | `user_id` | ADR-008 |
| `admin_recipients` †, `admin_report_runs` † | admins seen by the service; one row per report and period | `008` |
| `challenges` †, `user_challenges` †, `challenge_rewards` † | daily challenge catalog, assignment per user and date, granted points | `009` |

> **The sections after this one describe the reference (target) model**, which the code does not fully implement.

## Database engine

**Engine:** PostgreSQL, database `profile`, schemas `profile`, `notification`, `gamification` (the last one only if RF8 is approved).
**Justification:** small relational data with delivery state and one-to-one / one-to-many relations enforced by constraints.

---

## Schema

### Schema `profile`: `user_preferences`

| Field | Type | Nullable | Description | Constraints |
|-------|------|----------|-------------|-------------|
| user_preference_id | UUID | No | | PK |
| user_id | UUID | No | Owner. **Logical ID** issued by iam | UNIQUE (one-to-one with the user), no FK |
| ui_language | enum | No | Interface language: `ES` or `EN` (default `ES`). Not the language of the signs | |
| theme | enum | No | `LIGHT` or `DARK` (default `LIGHT`) | |
| notifications_enabled | BOOLEAN | No | The one per-user notification control (RF4). Default `TRUE` | |
| updated_at | TIMESTAMPTZ | No | | Trigger pending (DATA-07) |

A user with no row is a valid state: the application falls back to the defaults. `ui_language` (`ES`/`EN`) vs the domain's `es-CO`/`en-US` is open (ALIGN-08).

### Schema `notification`

**`notification_types`**: catalog of alert kinds.

| Field | Type | Description |
|-------|------|-------------|
| notification_type_id | UUID | PK |
| code | VARCHAR(50) UNIQUE | Stable identifier (`ACHIEVEMENT_UNLOCKED`, `ACCOUNT_SECURITY`, ...) |
| name, description | VARCHAR | |
| is_active | BOOLEAN | Administrator control, system-wide |
| created_at | TIMESTAMPTZ | |

**`user_devices`**: a phone that can receive a push.

| Field | Type | Description |
|-------|------|-------------|
| device_id | UUID | PK |
| user_id | UUID | **Logical ID** of iam, no FK |
| push_token | VARCHAR(255) UNIQUE | A credential; registration is an upsert (providers recycle tokens, DATA-05) |
| platform | enum | `device_platform` |
| is_active | BOOLEAN | Devices are revoked, never deleted |
| registered_at, revoked_at | TIMESTAMPTZ | |

**`notifications`**: every alert with its delivery state.

| Field | Type | Description |
|-------|------|-------------|
| notification_id | UUID | PK |
| user_id | UUID | **Logical ID** of iam, no FK. The notification is personal data and goes with the account |
| notification_type_id | UUID | FK to `notification_types`, `RESTRICT` |
| device_id | UUID | FK to `user_devices`, nullable; required if and only if `channel = 'PUSH'` (INV-024, `ck_push_requires_device` pending, DATA-11) |
| channel | enum | `PUSH`, `IN_APP`, `EMAIL`; no audio-only value, by design (INV-023) |
| title, body | VARCHAR(150), TEXT | Stored, not templated at delivery |
| reference_type, reference_id | enum, UUID | The record in another service that caused the alert. Polymorphic, **no FK** |
| status | enum | `PENDING`, `SENT`, `READ`, `FAILED`, `CANCELLED` |
| scheduled_at, sent_at, read_at, created_at | TIMESTAMPTZ | |

Indexes: `(user_id, created_at)`, `(status, scheduled_at)` (the delivery worker's query), `(notification_type_id)`, `(reference_type, reference_id)`.

### Schema `gamification` (provisional, RF8 not approved)

Do not create this schema until the team approves RF8 (GAP-01). If approved:

| Table | Content |
|-------|---------|
| `achievements` | `achievement_id`, `code` UNIQUE, `name`, `description`, `metric` (`TRANSLATIONS_COMPLETED`, `SIGNS_LEARNED`, `ALPHABET_COMPLETED`, `SESSIONS_COMPLETED`), `target_count` > 0, `points`, `icon_reference`, `is_secret`, `is_active` |
| `user_achievements` | `user_id` (logical ID), `achievement_id` (FK `RESTRICT`), `current_count`, `achieved_at` (NULL = in progress), `notified_at` (guarantees one notification), unique `(user_id, achievement_id)` |

If RF8 is rejected, the two tables, the `achievement_metric` enum, `usage_section.ACHIEVEMENTS` and `reference_entity.ACHIEVEMENT` come out together; nothing else breaks, because notifications reference achievements without a FK.

---

## Cross-service references

| Field | Points at | Rule |
|-------|-----------|------|
| `user_preferences.user_id`, `user_devices.user_id`, `notifications.user_id`, `user_achievements.user_id` | iam `users.user_id` | Logical ID; erased by `iam.AccountDeletionRequested` |
| `notifications.reference_id` | translation, achievement, ... | Logical ID, polymorphic |

---

## Modeling decisions

- **Two control levels, not three:** the user has one switch (`notifications_enabled`); an administrator activates a type for everyone. There is no per-user, per-type matrix, because no requirement asks for it.
- **`user_id` is personal data:** all rows of the user are deleted on account deletion (the opposite of analytics).
- **`FAILED` exists** so that "not sent yet" and "tried and could not" are distinguishable.
- **`current_count` is stored** and updated by the event handler; a periodic recompute reconciles drift.
- **Open:** `notifications.device_id ON DELETE SET NULL` would break INV-024; devices are revoked, never deleted (DATA-04).

---

## Schema migration

**Tool:** Liquibase (one migration set per service). Seeds: `S002__seed_notification_types.sql`.
**Script location:** `profile-service/db/changelog/`.
**Naming convention:** `NNN-description.xml` / `.sql`.

**Rollback policy:**
- Schema changes have a rollback block.
- The `gamification` schema is created in its own changelog so that it can be omitted or removed as a unit.
