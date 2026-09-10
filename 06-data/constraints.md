# Constraints — `002_constraints.sql`

> Everything the database must enforce that **DBML cannot express**: `CHECK` constraints, partial unique
> indexes and triggers. None of it is visible in dbdiagram.io, and none of it exists in the database
> until this migration is written and run.

**Version:** v0.2 · **Last updated:** 2026-09-10 · **Status:** 🔴 **not yet written as a migration** — DATA-11
**Belongs in:** the backend repository, as `migrations/V010__constraints_and_triggers.sql`

---

## Why this file exists

The v8 DBML ends with a comment listing six constraints "applied in the DDL — see
`migrations/002_constraints.sql`" and then trails off with `// ...`. That file does not exist, and four
more constraints the requirements demand were never listed (GAP-05).

> **A constraint that lives only in a comment is a comment.** Until this migration runs, the database
> accepts `confidence = 9.5` — the `DECIMAL(5,4)` type caps the magnitude at 9.9999 and nothing caps it
> at 1 — accepts two active AI models at once, accepts two password policies in force, and accepts a
> `PUSH` notification with no device to deliver it to.

This document is the completed content. Copy it into the migration; do not maintain two versions.

---

## The migration

```sql
-- ============================================================
-- V010__constraints_and_triggers.sql
-- Checks, partial unique indexes and triggers.
-- Runs after every table exists and before the seeds.
-- ============================================================

-- ── Identity ────────────────────────────────────────────────
ALTER TABLE identity.users
  ADD CONSTRAINT ck_users_attempts_positive CHECK (failed_login_attempts >= 0),
  ADD CONSTRAINT ck_users_lockout_positive  CHECK (lockout_level >= 0),
  ADD CONSTRAINT ck_users_blocked_coherent  CHECK ((status = 'BLOCKED') = (blocked_at IS NOT NULL));

ALTER TABLE identity.user_tokens
  ADD CONSTRAINT ck_user_tokens_expiry   CHECK (expires_at > created_at),
  ADD CONSTRAINT ck_user_tokens_attempts CHECK (attempts >= 0);

ALTER TABLE identity.refresh_tokens
  ADD CONSTRAINT ck_refresh_expiry CHECK (expires_at > issued_at);

ALTER TABLE identity.user_sessions
  ADD CONSTRAINT ck_session_duration CHECK (duration_seconds IS NULL OR duration_seconds >= 0),
  ADD CONSTRAINT ck_session_order    CHECK (ended_at IS NULL OR ended_at >= started_at);

-- ── Lexicon ─────────────────────────────────────────────────
-- INV-013: letter present if and only if the sign is a LETTER
ALTER TABLE lexicon.sign_lexicon
  ADD CONSTRAINT ck_lexicon_letter_iff_type
    CHECK ((sign_type = 'LETTER') = (letter IS NOT NULL));

-- INV-020: playback order starts at 1
ALTER TABLE lexicon.multimedia_resources
  ADD CONSTRAINT ck_resource_position CHECK (position >= 1);

-- ── Translation and AI ──────────────────────────────────────
-- INV-006: confidence is a probability
ALTER TABLE translation.translations
  ADD CONSTRAINT ck_translation_confidence
    CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1));

ALTER TABLE translation.translation_signs
  ADD CONSTRAINT ck_translation_sign_confidence
    CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 1)),
  ADD CONSTRAINT ck_translation_sign_position CHECK (position >= 1);

ALTER TABLE ai.ai_models
  ADD CONSTRAINT ck_model_accuracy CHECK (accuracy IS NULL OR (accuracy >= 0 AND accuracy <= 1)),
  ADD CONSTRAINT ck_model_counts   CHECK (sample_count >= 0 AND sign_count >= 0);

-- INV-022: exactly one active model. A plain index does not enforce this
CREATE UNIQUE INDEX uq_single_active_model
  ON ai.ai_models (is_active) WHERE is_active = TRUE;

-- ── Notification ────────────────────────────────────────────
-- INV-024: a PUSH has a device; no other channel carries one
ALTER TABLE notification.notifications
  ADD CONSTRAINT ck_push_requires_device
    CHECK ((channel = 'PUSH') = (device_id IS NOT NULL));

ALTER TABLE notification.notifications
  ADD CONSTRAINT ck_notification_read_after_sent
    CHECK (read_at IS NULL OR sent_at IS NULL OR read_at >= sent_at);

-- ── Usage ───────────────────────────────────────────────────
ALTER TABLE usage.usage_daily_stats
  ADD CONSTRAINT ck_usage_counts CHECK (event_count >= 0 AND unique_users >= 0);

ALTER TABLE usage.session_daily_stats
  ADD CONSTRAINT ck_session_stats CHECK (session_count >= 0 AND unique_users >= 0
                                     AND total_duration_seconds >= 0 AND avg_duration_seconds >= 0);

-- ── Gamification ⏸ (only if RF8 is approved) ────────────────
ALTER TABLE gamification.achievements
  ADD CONSTRAINT ck_achievement_target CHECK (target_count > 0),
  ADD CONSTRAINT ck_achievement_points CHECK (points >= 0);

ALTER TABLE gamification.user_achievements
  ADD CONSTRAINT ck_progress_positive CHECK (current_count >= 0);

-- ── Password policy (Identity, since v9) ────────────────────
ALTER TABLE identity.password_policies
  ADD CONSTRAINT ck_policy_length CHECK (min_length >= 8 AND min_length <= max_length);

-- INV-026: exactly one policy in force
CREATE UNIQUE INDEX uq_single_active_policy
  ON identity.password_policies (is_active) WHERE is_active = TRUE;

-- ── updated_at, which does not update itself ────────────────
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at              BEFORE UPDATE ON identity.users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_preferences_updated_at        BEFORE UPDATE ON profile.user_preferences
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_sign_lexicon_updated_at       BEFORE UPDATE ON lexicon.sign_lexicon
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_sign_localizations_updated_at BEFORE UPDATE ON lexicon.sign_localizations
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_password_policies_updated_at  BEFORE UPDATE ON identity.password_policies
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
-- gamification.user_achievements gets one too, if RF8 is approved
```

---

## Two techniques worth understanding before changing this file

**Partial unique indexes are the tool for "exactly one".** `uq_single_active_model` and
`uq_single_active_policy` each index a single row — the one where the flag is true — so a second
activation fails at the database. The application still deactivates the previous row first, inside the
same transaction; the index is what guarantees it did.

**The `(a) = (b IS NOT NULL)` form is a biconditional, not two rules.**
`CHECK ((channel = 'PUSH') = (device_id IS NOT NULL))` says *a push has a device **and** nothing else
carries one*. Written as two separate checks, one of the two directions eventually gets dropped as
"redundant". The same shape appears in `ck_lexicon_letter_iff_type` and `ck_users_blocked_coherent`.

---

## Constraints that cannot be added yet

Both wait on a decision, and both are one line once it is made:

```sql
-- Only once GAP-06 is decided (every translation must record its model).
-- The backfill has to run first — see migration-strategy.md
ALTER TABLE translation.translations ALTER COLUMN model_id SET NOT NULL;

-- Only once ALIGN-03 is decided (INV-007 needs a threshold to read)
ALTER TABLE ai.ai_models ADD COLUMN confidence_threshold DECIMAL(5,4)
  CHECK (confidence_threshold >= 0 AND confidence_threshold <= 1);
```

---

## What this file does not cover

| Rule | Where it is enforced instead | Why not here |
|------|------------------------------|--------------|
| INV-013 — exactly 27 letters exist | A catalog integrity test at startup | A `CHECK` sees one row; counting rows needs a trigger or a test, and a test is cheaper to read |
| INV-016 — permissions only through roles | The absence of a `user_permissions` table | The strongest constraint is the table you did not create |
| INV-023 — no audio-only channel | The `notification_channel` enum | A type is stronger than a check: there is no value to reject |
| INV-025 — a disabled switch suppresses delivery | Application code, before creating the notification | It spans two schemas; a cross-schema `CHECK` is not possible in PostgreSQL |
| Consent evidence on every sample | The MongoDB `$jsonSchema` validator in [`domains/06-ai.md`](domains/06-ai.md) | Different store, different mechanism |

---

## Correlations

- The tables these constrain → [`domains/`](domains/)
- When and how to run this → [`migration-strategy.md`](migration-strategy.md)
- Invariants INV-001 … INV-027 → `02-domain/entities-and-rules.md`
- GAP-05, which this closes → `04-requirements/traceability-matrix.md` § 6
- One test per invariant → `11-quality/testing-strategy.md`
