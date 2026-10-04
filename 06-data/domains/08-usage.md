# Usage — Data Model

> **Domain 8 of 10** · Bounded Context: **Usage Analytics** (Supporting) · PostgreSQL schema: `usage`
> **Tables:** `usage_events`, `usage_daily_stats`, `session_daily_stats`
> **Requirements:** RF6 · ERF6.1 · RF2 (section entries) · FR-701 … FR-706

**Owned by:** analytics-service (PostgreSQL db `analytics`)
**Version:** v0.2 · **Last updated:** 2026-09-10 · **Source:** `traduce_senas.dbml` (v9)
**Conventions:** [`../modeling-conventions.md`](../modeling-conventions.md) · **Constraints:** [`../constraints.md`](../constraints.md) · **Open items:** [`../open-items.md`](../open-items.md)

---

## What this domain owns

The record of how the application is used, and the pre-aggregated rollups the administrator dashboard
reads.

**`usage_events` is a source of truth; the reports are not.** Every metric the administrator sees is
rebuilt from this log — drop every report and they can be regenerated. But `usage_events` itself cannot
be regenerated from anything else, which is why it survives the deletion of the account that produced it.

---

## `usage_events`

**Purpose:** one row per recorded fact of use. Append-only.

```sql
CREATE TABLE usage.usage_events (
  usage_event_id UUID             PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID             REFERENCES identity.users (user_id)            ON DELETE SET NULL,
  session_id     UUID             REFERENCES identity.user_sessions (session_id) ON DELETE SET NULL,
  section        usage_section    NOT NULL,
  event_type     usage_event_type NOT NULL,
  reference_type reference_entity,
  reference_id   UUID,
  created_at     TIMESTAMPTZ      NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_usage_user_created ON usage.usage_events (user_id, created_at);
CREATE INDEX idx_usage_section      ON usage.usage_events (section, created_at);
CREATE INDEX idx_usage_session      ON usage.usage_events (session_id);
CREATE INDEX idx_usage_event_type   ON usage.usage_events (event_type, created_at);
```

**Data dictionary:**

| Column | Meaning | Values |
|--------|---------|--------|
| `section` | Which part of the app the user was in (RF6 — most visited sections) | `HOME`, `TRANSLATION`, `ALPHABET`, `LEXICON`, `HISTORY`, `PROFILE`, `SETTINGS`, `NOTIFICATIONS`, `ACHIEVEMENTS`, `ADMIN` |
| `event_type` | What the user did | `SECTION_VIEW`, `TRANSLATION_STARTED`, `TRANSLATION_COMPLETED`, `TRANSLATION_FAILED`, `AUDIO_PLAYED`, `SIGN_VIEWED`, `SEARCH_PERFORMED`, `HISTORY_ENTRY_DELETED`, `PREFERENCE_CHANGED`, `NOTIFICATION_OPENED` |
| `reference_type` / `reference_id` | Which record the event was about, when it was about one | No foreign key — same polymorphic pattern as `notifications` |
| `user_id` | Who, while the account exists | `SET NULL` on deletion: **the fact survives the person** |

**Four indexes, one per question the dashboard asks:** per user over time, per section over time, per
login session, per event type over time. Each is a real query in RF6; none is speculative.

**RF2 produces no tables of its own, but it does produce data.** Every entry into a section is written
as a `SECTION_VIEW` row — that is the entire reason the `usage_section` enum exists. The DBML
traceability comment currently says RF2 has "no persistence", which is not right (GAP-04). Producing no
domain and producing no data are different things.

---

## `usage_daily_stats`

**Purpose:** daily rollup of the event log, by section and event type.

```sql
CREATE TABLE usage.usage_daily_stats (
  stat_date     DATE             NOT NULL,                        -- calendar day, America/Bogota
  section       usage_section    NOT NULL,
  event_type    usage_event_type NOT NULL,
  event_count   INTEGER          NOT NULL,
  unique_users  INTEGER          NOT NULL,
  calculated_at TIMESTAMPTZ      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (stat_date, section, event_type)
);
```

**The grain *is* the primary key.** `(stat_date, section, event_type)` — one row per day, per section,
per kind of event. `stat_date` is a `DATE`, not a timestamp: a calendar day in Colombia is not an
instant.

---

## `session_daily_stats`

**Purpose:** daily rollup of login sessions and time spent.

```sql
CREATE TABLE usage.session_daily_stats (
  stat_date              DATE        PRIMARY KEY,
  session_count          INTEGER     NOT NULL,
  unique_users           INTEGER     NOT NULL,
  total_duration_seconds BIGINT      NOT NULL,
  avg_duration_seconds   INTEGER     NOT NULL,
  calculated_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

`total_duration_seconds` is `BIGINT` and `avg_duration_seconds` is `INTEGER`, correctly: a sum of
seconds across a growing user base outgrows a 32-bit integer; an average session length never will.

---

## ⚠️ `unique_users` is not additive — the trap in this whole schema

Summing `unique_users` across sections, event types or days **does not** give the number of distinct
users. The same person counted in `HOME` and in `TRANSLATION` is one user, and the sum says two.

The column is valid **only at the grain it was computed at**. A query that adds it up produces a
plausible, wrong number that nobody notices — which is the worst kind of wrong. Two ways out, both
acceptable, neither free:

- Recompute distinct users from `usage_events` whenever the report is not at the stored grain, or
- store an HLL sketch instead of an integer (`postgresql-hll`), which *is* mergeable.

Until one is chosen, **every report built on `unique_users` must state its grain on the screen.**

---

## Modeling decisions

1. **`SET NULL` on both foreign keys, not `CASCADE`.** This is the deliberate opposite of
   `translations.user_id`: the translation history is the user's personal data and must go with the
   account; a usage event is an anonymous statistical fact that must not, or the reports collapse
   retroactively every time somebody exercises their right to deletion (RNF8 and RF6 both satisfied).
2. **No `updated_at`, no `deleted_at`.** Append-only. An `updated_at` on a log is a column always equal
   to `created_at`.
3. ⚠️ **`idx_daily_stats_date_section` is redundant and has been dropped.** The DBML declares an index
   on `(stat_date, section)`, which is a left prefix of the primary key `(stat_date, section,
   event_type)` — PostgreSQL already serves those queries from the PK index. Keeping it costs writes and
   buys nothing (DATA-09).
4. **No partitioning yet.** `usage_events` grows with every screen the users open. At this project's
   scale monthly partitioning by `created_at` is not urgent, but it is the same conversation as the log
   retention in [`10-audit.md`](10-audit.md) and should be had once, for both.

---

## ⚠️ The two rollup tables have no requirement behind them

`04-requirements/traceability-matrix.md` § 3 does not list `usage_daily_stats` or
`session_daily_stats`, and `02-domain/domain-map.md` states that Usage Analytics **"owns no aggregated
data — every report is rebuilt from `usage_events`"**.

By the matrix's own rule — *a table with no FR does not enter the model* — these two are currently in
the same position `achievements` was in when GAP-01 was raised. The tables themselves are a reasonable
idea: an administrator dashboard must answer in under a second over a log that grows continuously. What
is missing is the requirement, the matrix rows, and a sentence in the domain map that stops contradicting
them. **The report is a read model; the rollup is a cache with a recompute job.** That distinction is
what needs writing down (DATA-03).

---

## Invariants this domain participates in

| Invariant | Note |
|-----------|------|
| INV-012 — statistics are admin-only and always aggregated | Enforced by `stats.read` in [`02-authorization.md`](02-authorization.md) plus a read model that stores counts only |

---

## Open items affecting this domain

| ID | Summary |
|----|---------|
| **DATA-03** | Both rollup tables lack an FR and contradict the domain map's claim that Analytics owns no aggregated data |
| **DATA-09** | `idx_daily_stats_date_section` is a left prefix of the primary key — redundant |
| **DATA-10** | No retention or partitioning policy; `usage_events` grows without bound |
| **GAP-04** | The DBML says RF2 has "no persistence"; every section entry is a `SECTION_VIEW` row |
| **GAP-07** | `usage_section.ACHIEVEMENTS` depends on GAP-01 |

---

## Correlations

- Login sessions and their duration → [`01-identity.md`](01-identity.md)
- Events emitted by the Core → [`05-translation.md`](05-translation.md)
- Progress towards achievements is computed from these events → [`09-gamification.md`](09-gamification.md)
- Who may read statistics → [`02-authorization.md`](02-authorization.md)
- Event catalog → [`../../02-domain/domain-events.md`](../../02-domain/domain-events.md)
- Dashboard requirements → `04-requirements/traceability-matrix.md`
