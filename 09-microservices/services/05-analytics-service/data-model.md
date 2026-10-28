# Data Model — Analytics Service

> `analytics-service` is the **authoritative owner** of the data described here. No other service reads these tables.
> Full DDL and data dictionary: `06-data/domains/08-usage.md`; this file is the service view.

---

## Implemented today

Taken from the migrations of Backend `develop` `2e0816f` (`services/analytics-service/db/`, applied in order by `docker-compose.yml`). Tables marked † are in `develop` but not yet deployed (production runs v1.3.0). PostgreSQL database `analytics`, schema `public` (no `usage` schema).

| Table | Key columns | Notes |
|-------|-------------|-------|
| `usage_event` (singular) | `usage_event_id` BIGSERIAL, `event_id` UNIQUE (makes the consumers idempotent), `user_id` VARCHAR(64), `session_id`, `section`, `event_type`, `reference_type`, `reference_id`, `sign_codes` TEXT[], `created_at` | Fed by `recognition.TranslationProduced`, `iam.UserRegistered` and `POST /api/analytics/events`. No retention: rows are kept, unlinked from the user on erasure |
| `erased_users` | `user_id` VARCHAR(64), `erased_at` | Late events for an erased user are stored without the user |

There are no `usage_daily_stats` or `session_daily_stats` rollups; reports aggregate `usage_event` directly.

> **The sections after this one describe the reference (target) model**, which the code does not fully implement.

## Database engine

**Engine:** PostgreSQL, database `analytics`, schema `usage`.
**Justification:** an append-only log plus small rollup tables, queried by date and by dimension; indexes and `GROUP BY` cover the
dashboard. Monthly partitioning of `usage_events` is not needed at this scale (DATA-10).

---

## Schema

### Table: `usage_events`

**Purpose:** one row per recorded fact of use. Append-only; the only source from which every report can be rebuilt.

| Field | Type | Nullable | Description | Constraints |
|-------|------|----------|-------------|-------------|
| usage_event_id | UUID | No | Identifier | PK |
| user_id | UUID | Yes | Who, while the account exists. **Logical ID** of iam | No FK. Set to NULL on `AccountDeleted` / `AccountDeletionRequested` (the fact survives the person) |
| session_id | UUID | Yes | Login session. **Logical ID** of iam `user_sessions` | No FK |
| section | enum `usage_section` | No | `HOME`, `TRANSLATION`, `ALPHABET`, `LEXICON`, `HISTORY`, `PROFILE`, `SETTINGS`, `NOTIFICATIONS`, `ACHIEVEMENTS`, `ADMIN` | |
| event_type | enum `usage_event_type` | No | `SECTION_VIEW`, `TRANSLATION_STARTED`, `TRANSLATION_COMPLETED`, `TRANSLATION_FAILED`, `AUDIO_PLAYED`, `SIGN_VIEWED`, `SEARCH_PERFORMED`, `HISTORY_ENTRY_DELETED`, `PREFERENCE_CHANGED`, `NOTIFICATION_OPENED` | |
| reference_type | enum `reference_entity` | Yes | Kind of record the event was about | No FK, polymorphic |
| reference_id | UUID | Yes | The record (a translation, a sign, ...) in another service | No FK |
| created_at | TIMESTAMPTZ | No | | Default `CURRENT_TIMESTAMP` |

Indexes: `idx_usage_user_created (user_id, created_at)`, `idx_usage_section (section, created_at)`, `idx_usage_session (session_id)`, `idx_usage_event_type (event_type, created_at)`.

To make the consumers idempotent, the service also stores the processed `eventId` (column `source_event_id` UNIQUE on `usage_events`, or a separate `processed_events` table). It is not in `06-data/` yet; it is an addition that the data team must approve.

### Table: `usage_daily_stats`

| Field | Type | Description |
|-------|------|-------------|
| stat_date | DATE | Calendar day in America/Bogota |
| section | `usage_section` | |
| event_type | `usage_event_type` | |
| event_count | INTEGER | |
| unique_users | INTEGER | **Not additive**: valid only at this grain |
| calculated_at | TIMESTAMPTZ | |

Primary key `(stat_date, section, event_type)`. The index `idx_daily_stats_date_section` is redundant and not created (DATA-09).

### Table: `session_daily_stats`

| Field | Type | Description |
|-------|------|-------------|
| stat_date | DATE | PK |
| session_count | INTEGER | |
| unique_users | INTEGER | Not additive |
| total_duration_seconds | BIGINT | |
| avg_duration_seconds | INTEGER | |
| calculated_at | TIMESTAMPTZ | |

---

## Cross-service references

| Field | Points at | Rule |
|-------|-----------|------|
| `usage_events.user_id` | iam `users.user_id` | Logical ID, nullable, detached on account deletion |
| `usage_events.session_id` | iam `user_sessions.session_id` | Logical ID |
| `usage_events.reference_id` | translation, sign, notification, achievement, ... | Logical ID, never a FK |

---

## Modeling decisions

- **No FK and `user_id` nullable:** the opposite of `translations.user_id` in recognition. A usage event is an anonymous statistical fact and must not disappear with the account, or reports would change retroactively (RNF8 and RF6 are both satisfied).
- **Append-only:** no `updated_at`, no `deleted_at`.
- **Rollups are a cache:** they can be dropped and recomputed from `usage_events`. Open item DATA-03: the matrix has no requirement for the two rollup tables and the domain map says Analytics owns no aggregated data; the data team must reconcile them.
- **`unique_users` is not additive:** recompute from `usage_events` when a report is not at the stored grain, or store an HLL sketch. Every report states its grain.
- **Open item:** `session_daily_stats` is computed from login sessions that iam owns. The event catalog has `UserSignedIn` but no event for the close of a session (with its duration); one must be agreed with iam.

---

## Schema migration

**Tool:** Liquibase (one migration set per service).
**Script location:** `analytics-service/db/changelog/`.
**Naming convention:** `NNN-description.xml` / `.sql`.

**Rollback policy:**
- Schema changes have a rollback block. The rollup tables can always be dropped and rebuilt from `usage_events`.
- `usage_events` is the one table that cannot be rebuilt: back it up before any destructive change.
