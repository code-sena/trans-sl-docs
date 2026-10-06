# Translation — Data Model ⭐ Core

> **Domain 5 of 10** · Bounded Context: **Recognition & Translation** (⭐ Core) · PostgreSQL schema: `translation`
> **Tables:** `translations`, `translation_signs`
> **Requirements:** RF3 · ERF3.1, ERF3.2 · ERF5.5 · RNF1

**Owned by:** recognition-service (PostgreSQL db `recognition`)
**Version:** v0.2 · **Last updated:** 2026-09-10 · **Source:** `traduce_senas.dbml` (v9)
**Conventions:** [`../modeling-conventions.md`](../modeling-conventions.md) · **Constraints:** [`../constraints.md`](../constraints.md) · **Open items:** [`../open-items.md`](../open-items.md)

---

## What this domain owns

The result of recognition and the user's history of it. **They are the same rows** — the history screen
(ERF5.5) is `translations` filtered by `deleted_at IS NULL`. There is no separate history table, because
history is not a different model: it is the translations already produced and not deleted by their owner.

> ⚠️ **The aggregate root of this domain has no table.** `TranslationSession` — the period with the
> camera on — is the central aggregate of the whole domain model, and the v8 model has no
> `translation_sessions` table. `translations` hangs directly off `user_id`. This is **ALIGN-01**, the
> most consequential open item in the project, and its data-layer consequences are listed at the bottom
> of this file.

---

## `translations`

```sql
CREATE TABLE translation.translations (
  translation_id  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID        NOT NULL REFERENCES identity.users (user_id) ON DELETE CASCADE,
  recognized_text TEXT        NOT NULL,
  confidence      DECIMAL(5,4),
  output_mode     output_mode NOT NULL DEFAULT 'TEXT',            -- ERF3.2
  model_id        UUID        REFERENCES ai.ai_models (model_id) ON DELETE RESTRICT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted_at      TIMESTAMPTZ                                     -- ERF5.5
);

CREATE INDEX idx_translations_user_created ON translation.translations (user_id, created_at);
CREATE INDEX idx_translations_deleted      ON translation.translations (deleted_at);
```

**Data dictionary:**

| Column | Meaning | Notes |
|--------|---------|-------|
| `recognized_text` | The text delivered to the user, already assembled from the recognized signs | Denormalized on purpose — see [`../normalization-assessment.md`](../normalization-assessment.md) |
| `confidence` | Confidence of the translation as a whole | `DECIMAL(5,4)` gives four decimals and caps the magnitude at 9.9999 — the 0…1 range needs `ck_translation_confidence`. `DECIMAL`, not `FLOAT`: a comparison against a threshold must not depend on binary rounding |
| `output_mode` | How the translation was delivered: `TEXT` or `AUDIO` (ERF3.2) | ⚠️ There is no `BOTH` — ALIGN-07 |
| `model_id` | Which model version produced this translation, for traceability | ⚠️ Nullable — GAP-06 |
| `deleted_at` | Individual history entry deleted by the user (ERF5.5). Irreversible (INV-011) | |

---

## `translation_signs`

**Purpose:** the ordered signs that make up one translation.

```sql
CREATE TABLE translation.translation_signs (
  translation_sign_id UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  translation_id      UUID         NOT NULL REFERENCES translation.translations (translation_id) ON DELETE CASCADE,
  sign_id             UUID         NOT NULL REFERENCES lexicon.sign_lexicon (sign_id)            ON DELETE RESTRICT,
  position            INTEGER      NOT NULL,
  confidence          DECIMAL(5,4)
);

CREATE UNIQUE INDEX uq_sign_order              ON translation.translation_signs (translation_id, position);
CREATE INDEX        idx_translation_signs_sign ON translation.translation_signs (sign_id);
```

`position` is the order of this sign inside the translation, unique per translation. It is **the one
ordering this model has** — ordering translations inside a session has nowhere to live (ALIGN-01).

`confidence` here and `confidence` on `translations` are different measurements, not a copy: the
confidence of a phrase is not the average of its signs'. Nobody should try to derive one from the other.

`idx_translation_signs_sign` answers the reverse question — "which translations used this sign?" —
which is what the RF6 statistic *most translated signs* needs.

---

## Modeling decisions

1. **`translations.user_id` is `CASCADE` while `usage_events.user_id` is `SET NULL`.** Deliberate and
   asymmetric: the translation history is **the user's personal data** and must disappear with the
   account (RNF8); a usage event is an anonymous statistical fact that must not (RF6). Same deletion,
   two correct opposite answers, because the two rows mean different things.
2. **`translation_signs.sign_id` is `RESTRICT`.** A sign that appears in someone's history can never be
   deleted. Retiring a sign is `status = 'INACTIVE'` in [`04-lexicon.md`](04-lexicon.md), which hides it
   from the catalog while keeping the history intact.
3. **`model_id` is `RESTRICT`.** A model that produced translations is never deleted, or the history
   points at a version that no longer exists (INV-022).
4. **`idx_translations_deleted` should be partial.** Every history query is
   `WHERE user_id = ? AND deleted_at IS NULL ORDER BY created_at DESC`; a full index on `deleted_at`
   mostly indexes NULLs. The better shape is
   `CREATE INDEX … ON translations (user_id, created_at DESC) WHERE deleted_at IS NULL` — DATA-08.

---

## Invariants this domain enforces

| Invariant | Where it is enforced |
|-----------|----------------------|
| INV-006 — confidence within range | `ck_translation_confidence` and `ck_translation_sign_confidence` |
| INV-011 — history is private and its deletion is irreversible | Every query filters by `user_id`; `deleted_at` is set once and never cleared |
| INV-005 — every translation belongs to a session | ⚠️ **Cannot be enforced** — there is no session table. ALIGN-01 |
| INV-007 — confidence below the threshold is not a confirmed translation | ⚠️ **Cannot be implemented** — `ai_models` has no threshold column. ALIGN-03 |

---

## Open items affecting this domain

| ID | Summary and data-layer consequence |
|----|-------------------------------------|
| **ALIGN-01** | No `translation_sessions` table. Three consequences here: `output_mode` and `model_id` are repeated on every row instead of held once per session; **nothing orders translations within a session**, so AGGR-INV-003 (consecutive `sequence`) has no home; and INV-005 cannot be enforced at the persistence layer. Either the table is added, or the session is accepted as a runtime-only concept and INV-005 / AGGR-INV-001…004 are rewritten |
| **ALIGN-03** | `ai_models` has no `confidence_threshold`, so INV-007 has nothing to compare against. The `ALTER TABLE` is written in [`../constraints.md`](../constraints.md), pending the decision |
| **ALIGN-07** | `output_mode` has no `BOTH`. If audio always accompanies visible text — which is what accessibility requires — then `BOTH` is the only sensible value and `AUDIO` alone should not exist |
| **GAP-06** | `model_id` is nullable while FR-403 requires every translation to record its model. The three-step migration that fixes it is in [`../migration-strategy.md`](../migration-strategy.md) |

---

## Correlations

- The model that produced each translation → [`06-ai.md`](06-ai.md)
- The signs referenced, and the `code` = `Gloss` contract → [`04-lexicon.md`](04-lexicon.md)
- Events emitted on each translation → [`08-usage.md`](08-usage.md) and [`../../02-domain/domain-events.md`](../../02-domain/domain-events.md)
- `TranslationSession`, `Translation` entities and the aggregate rules → [`../../02-domain/entities-and-rules.md`](../../02-domain/entities-and-rules.md)
- Recognition latency (RNF1) → `04-requirements/non-functional.md`
