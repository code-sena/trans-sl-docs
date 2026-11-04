# Gamification — Data Model ⏸

> **Domain 9 of 10** · Bounded Context: **Gamification** (Supporting, **provisional**) · PostgreSQL schema: `gamification`
> **Tables:** `achievements`, `user_achievements`
> **Requirements:** **RF8 — proposed, not in the SRS**

**Owned by:** profile-service (PostgreSQL db `profile`)
**Version:** v0.2 · **Last updated:** 2026-09-10 · **Source:** `traduce_senas.dbml` (v9)
**Conventions:** [`../modeling-conventions.md`](../modeling-conventions.md) · **Constraints:** [`../constraints.md`](../constraints.md) · **Open items:** [`../open-items.md`](../open-items.md)

---

## ⏸ Do not create this schema yet

Both tables exist in the v8 model with **no requirement behind them**. In a traceability review that
reads as gold-plating, and it is exactly how **GAP-01** was found.

There are two options and no third one:

| Option | What it means |
|--------|---------------|
| **Approve RF8** and add it to the SRS | This schema is built, and the FR-800 series, EP-009 and the enum values below stay |
| **Remove it** | These two tables, their two foreign keys, the `achievement_metric` enum, the `Gamification` TableGroup, `usage_section.ACHIEVEMENTS`, `reference_entity.ACHIEVEMENT`, the FR-800 series and EP-009 all come out **together** |

The decision belongs to the team and the instructor. Nothing here is built before it is made.

> **Why the rest of the model does not depend on this one.** Notifications references an unlocked
> achievement through `reference_type` / `reference_id` **with no foreign key**
> ([`07-notification.md`](07-notification.md)). That is what makes this context genuinely removable: if
> RF8 is rejected, dropping both tables breaks nothing.

---

## `achievements`

**Purpose:** the catalog of goals. `metric` + `target_count` is what turns it into a rule engine —
adding an achievement is a row, not a code change, as long as the metric it counts already exists.

```sql
CREATE TABLE gamification.achievements (
  achievement_id UUID               PRIMARY KEY DEFAULT gen_random_uuid(),
  code           VARCHAR(50)        NOT NULL UNIQUE,              -- FIRST_TRANSLATION
  name           VARCHAR(100)       NOT NULL,
  description    TEXT               NOT NULL,                     -- how it is earned; shown locked and unlocked
  metric         achievement_metric NOT NULL,                     -- WHAT is counted
  target_count   INTEGER            NOT NULL,                     -- HOW MUCH is needed
  points         INTEGER            NOT NULL DEFAULT 10,
  icon_reference TEXT,
  is_secret      BOOLEAN            NOT NULL DEFAULT FALSE,
  is_active      BOOLEAN            NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ        NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

| Column | Meaning | Values |
|--------|---------|--------|
| `metric` | What is counted, and therefore which usage events feed progress | `TRANSLATIONS_COMPLETED` · `SIGNS_LEARNED` · `ALPHABET_COMPLETED` · `SESSIONS_COMPLETED` |
| `target_count` | How much of that metric unlocks it | `> 0` (`ck_achievement_target`) |
| `is_secret` | When true, name and description stay hidden until it is unlocked | |
| `icon_reference` | Path to the icon; shown greyed out while locked | Object storage, like every other binary |

**Every value of `achievement_metric` must be computable from `usage_events`** — that is the constraint
on adding new ones. A metric nothing counts is an achievement nobody can ever unlock.

---

## `user_achievements`

**Purpose:** one row per user and achievement, tracking progress and the unlock.

```sql
CREATE TABLE gamification.user_achievements (
  user_achievement_id UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID        NOT NULL REFERENCES identity.users (user_id)                   ON DELETE CASCADE,
  achievement_id      UUID        NOT NULL REFERENCES gamification.achievements (achievement_id) ON DELETE RESTRICT,
  current_count       INTEGER     NOT NULL DEFAULT 0,
  achieved_at         TIMESTAMPTZ,                                -- NULL = in progress
  notified_at         TIMESTAMPTZ,                                -- guarantees one notification only
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX uq_user_achievement            ON gamification.user_achievements (user_id, achievement_id);
CREATE INDEX        idx_user_achievements_unlocked ON gamification.user_achievements (user_id);
```

**`achieved_at IS NULL` means in progress; with a value, unlocked.** A separate `status` column would be
a second source of truth for the same fact.

**`notified_at` is separate from `achieved_at` on purpose.** It is what guarantees the unlock
notification fires exactly once, even if the progress row is written again afterwards. Without it, a
recompute job re-announces every achievement the user already has.

---

## Implemented in profile-service: daily challenges and challenge-point medals

Unlike the reference model above, profile-service already runs a daily challenge feature (migrations
`009_daily_challenges.sql` and `010_challenge_reward_achievements.sql`). Decisions:
[ADR-009](../../05-architecture/decisions/records/ADR-009-daily-challenges.md) and
[ADR-010](../../05-architecture/decisions/records/ADR-010-challenge-points-medals.md). `user_id` is the logical id
of iam-service (`VARCHAR(64)`), with no foreign key between services.

| Table | Purpose | Key points |
|-------|---------|-----------|
| `challenges` | Catalog of definitions | `code` unique; `target_count > 0`; `points >= 0`; `localizations` JSONB (es/en/fr/pt); `is_active`. Seeds `TRANSLATE_1/3/5/8` (goal 1/3/5/8, 5/10/15/25 points) |
| `user_challenges` | Snapshot of the challenge assigned to a user on a day | `UNIQUE(user_id, challenge_date)`; copies code, name, description, goal, points and texts; `current_count` between 0 and the goal; `completed_at` is set exactly when the goal is reached; FK to `challenges` is `RESTRICT` |
| `challenge_rewards` | Points really granted | PK = `user_challenge_id` (FK, `CASCADE`), which makes the reward idempotent; `user_id`; `points`; `granted_at`; index on `user_id` |

Migration 009 also adds the notification type `CHALLENGE_COMPLETED` (`reference_type = CHALLENGE`, `reference_id` = the
`user_challenge_id`). Migration 010 adds the metric `DAILY_CHALLENGE_POINTS` and three medals in `achievements`
(`dailyChallengePoints500`, `dailyChallengePoints1000`, `dailyChallengePoints3000`, zero extra points). Their progress is
`SUM(challenge_rewards.points)` of the user, and it is the only measure.

---

## Modeling decisions

1. **`user_id` is `CASCADE`, `achievement_id` is `RESTRICT`.** Progress is personal data and goes with
   the account. A catalog entry somebody has unlocked cannot be deleted — retire it with
   `is_active = FALSE`.
2. **`current_count` is stored, not computed on read.** Recomputing every user's progress from
   `usage_events` on every dashboard load is the kind of query that is fine with fifty users and
   unusable with five thousand. The cost is that it must be updated by the event handler and can drift;
   a periodic recompute is the reconciliation.
3. **No `points` total per user table.** The score is `SUM(points)` over the unlocked rows. A stored
   total would be a third place the same number lives.

---

## Invariants this domain enforces

| Invariant | Where it is enforced |
|-----------|----------------------|
| INV-027 ⏸ — an achievement unlocks once per user | `uq_user_achievement` + `notified_at` |

---

## Open items affecting this domain

| ID | Summary |
|----|---------|
| **GAP-01** | These two tables have no SRS requirement. **Blocking** — approve RF8 or remove the schema |
| **GAP-07** | `usage_section.ACHIEVEMENTS` and `reference_entity.ACHIEVEMENT` exist only for this domain and come out with it |
| **DATA-07** | `user_achievements.updated_at` needs the trigger, if this schema is built |

---

## Correlations

- The events progress is computed from → [`08-usage.md`](08-usage.md)
- The unlock alert, referenced with no foreign key → [`07-notification.md`](07-notification.md)
- Why this context is provisional → [`../../02-domain/domain-map.md`](../../02-domain/domain-map.md)
- GAP-01 in full → `04-requirements/traceability-matrix.md` § 6
