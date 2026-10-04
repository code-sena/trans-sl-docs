# Open Items — Data Model

> What is still inconsistent between the model, the domain and the requirements. Stated rather than
> smoothed over, in the same spirit as `02-domain/domain-map.md` § 6 and
> `04-requirements/traceability-matrix.md` § 6.

**Version:** v0.2 · **Last updated:** 2026-09-10
**Convention:** items found from the data side are numbered **DATA-nn**. Items already tracked elsewhere
keep their original ID (**ALIGN-nn**, **GAP-nn**) and are restated here only with their data-layer
consequence.

---

## 1. Found from the data side

| ID | What | Why it matters | Action | Priority | Domain |
|----|------|----------------|--------|----------|--------|
| **DATA-02** | `sign_lexicon.created_by` / `updated_by` are `UUID` columns with **no foreign key**, but their notes say "NULL if that account was deleted" — which only happens with `ON DELETE SET NULL` | The note describes behaviour nothing implements. Deleting an administrator leaves a dangling id that looks valid | Either add `REFERENCES identity.users (user_id) ON DELETE SET NULL`, or document them as external identifiers like `gesture_samples.recorded_by`. Pick one; the current state is neither | **High** | [Lexicon](domains/04-lexicon.md) |
| **DATA-03** | `usage_daily_stats` and `session_daily_stats` have no FR in the traceability matrix § 3, and the domain map states Analytics "owns no aggregated data" | By the matrix's own rule — *a table with no FR does not enter the model* — these are where `achievements` was when GAP-01 was raised | Add an FR for the pre-aggregated dashboard, add both tables to § 3, and amend the domain-map sentence: **the report is a read model, the rollup is a cache with a recompute job** | **High** | [Usage](domains/08-usage.md) |
| **DATA-04** | `notifications.device_id` is `ON DELETE SET NULL`, which would violate INV-024's `CHECK ((channel='PUSH') = (device_id IS NOT NULL))` | Deleting a device breaks the constraint on its past PUSH notifications. The schema permits the deletion that breaks it | State the rule explicitly — **devices are revoked, never deleted** — and consider `ON DELETE RESTRICT` so it is enforced rather than agreed | Medium | [Notification](domains/07-notification.md) |
| **DATA-05** | `user_devices.push_token` is globally `UNIQUE`, but FCM/APNs reassign tokens between reinstalls and devices | The second user to receive a recycled token cannot register — a real, reproducible failure | Register with an upsert on `push_token` that re-points the row at the current user and revokes the previous binding | Medium | [Notification](domains/07-notification.md) |
| **DATA-06** | A soft-deleted `users` row keeps `full_name`, `email` and `username` in clear, and permanently occupies both `UNIQUE` constraints | RNF8 says the row is "kept anonymized". Nothing anonymizes it. Under Law 1581 that is the gap between a compliant deletion and a nominal one | Implement the anonymization routine in [`data-lifecycle.md`](data-lifecycle.md) § 2 as part of the deletion flow, **including the MongoDB side**, and test it | **High** | [Identity](domains/01-identity.md) |
| **DATA-07** | `updated_at` has `DEFAULT CURRENT_TIMESTAMP` and no trigger on any table | The column never changes after insert: it is a creation timestamp with a misleading name | Add the `set_updated_at()` trigger from [`constraints.md`](constraints.md) to the six tables that have the column | **High** — cheap | All with `updated_at` |
| **DATA-08** | `idx_translations_deleted` indexes a mostly-NULL column, while the real query is `user_id = ? AND deleted_at IS NULL ORDER BY created_at DESC` | The index that exists does not serve the query that runs | Replace with a partial index on `(user_id, created_at DESC) WHERE deleted_at IS NULL` | Low | [Translation](domains/05-translation.md) |
| **DATA-09** | `idx_daily_stats_date_section` is a left prefix of the primary key of `usage_daily_stats` | Redundant index: write cost, no read benefit | Drop it — already omitted from the DDL in this folder | Low | [Usage](domains/08-usage.md) |
| **DATA-10** | Neither `audit_logs` nor `error_logs` nor `usage_events` has a retention or partitioning policy | All three grow without bound, `audit_logs` fastest of all since it grows with every write to every table | Decide monthly partitioning or a scheduled purge with archival, once, for all three. Record it in `13-operations/observability.md` | Medium | [Audit](domains/10-audit.md), [Usage](domains/08-usage.md) |
| **DATA-11** | The DBML declares constraints in a trailing comment ending in `// ...` and delegates them to `migrations/002_constraints.sql`, which does not exist | GAP-05 seen from the data side. Until the file exists the database accepts `confidence = 9.5`, two active models and two policies in force | Write it — [`constraints.md`](constraints.md) is its complete content | **High** | All |
| **DATA-12** | The FR-900 series groups audit, error handling and password policy as one cross-cutting module, but after the v9 move `password_policies` belongs to Identity | FR-905 … FR-907 are now Identity requirements. Leaving them filed under a module that no longer exists is how the traceability matrix drifts from the model it is supposed to check | Move FR-905 … FR-907 to the Identity module in `04-requirements`, and keep FR-901 … FR-904 where they are — audit and errors *are* cross-cutting | Medium | [Identity](domains/01-identity.md) |

---

## 2. Already tracked, restated with their data consequence

### From `02-domain/domain-map.md` § 6

| ID | Consequence in this model |
|----|---------------------------|
| **ALIGN-01** | No `translation_sessions` table. `translation_signs.position` orders signs inside one translation; **nothing orders translations inside a session**, so AGGR-INV-003 has no home. `output_mode` and `model_id` are repeated on every row instead of held once per session, and INV-005 cannot be enforced at the persistence layer |
| **ALIGN-02** | `gesture_samples` identifies its performer; INV-010 forbids it. Until this is decided, the encryption-at-rest and per-session-discard requirements hold either way |
| **ALIGN-03** | `ai_models` has no `confidence_threshold` column, so INV-007 has nothing to compare against. The `ALTER TABLE` is written in [`constraints.md`](constraints.md), pending the decision |
| **ALIGN-04** | No `domain_events` table. Events travel over RabbitMQ, which does not keep history; without an outbox/inbox table per service, event traceability is not a property this project has — and `audit_logs` is the only durable record of change |
| **ALIGN-05** | `user_status` is `ACTIVE`/`INACTIVE`/`BLOCKED` plus `locked_until` and `deleted_at`; the domain names four states differently. These documents use the model's names and map them in [`domains/01-identity.md`](domains/01-identity.md) |
| **ALIGN-06** | The `User` code example still implements "five failures → LOCKED"; the model implements the progressive ladder in four columns. The model's rule is better — update the domain |
| **ALIGN-07** | `output_mode` has no `BOTH`. If audio always accompanies visible text — which accessibility requires — then `BOTH` is the only sensible value and `AUDIO` alone should not exist |
| **ALIGN-08** | `ui_language` is `ES`/`EN`; the domain uses `es-CO`/`en-US`. Cosmetic, but pick one |
| **ALIGN-09** | The domain models `PasswordResetRequest` as its own aggregate; the model uses `user_tokens` for both token kinds. The model is better — update the domain |

### From `04-requirements/traceability-matrix.md` § 6

| ID | Consequence in this model |
|----|---------------------------|
| **GAP-01** | The `gamification` schema is documented but **not created** until RF8 exists. Its removal path is listed in [`domains/09-gamification.md`](domains/09-gamification.md) |
| **GAP-02** | `sign_translations` duplicated `sign_localizations`. **Already fixed in the v8 model** — recorded so the fix is not undone |
| **GAP-03** | ✅ **Closed in v9** — the DBML comment now cites `user_tokens` |
| **GAP-04** | ✅ **Closed in v9** — the DBML comment now says RF2 has no tables of its own but records each section entry as `SECTION_VIEW` in `usage_events` |
| **GAP-05** | Closed by [`constraints.md`](constraints.md) once it becomes a migration — tracked here as DATA-11 |
| **GAP-06** | `translations.model_id` is nullable; the three-step migration is in [`migration-strategy.md`](migration-strategy.md) |
| **GAP-07** | `reference_entity` declares `CATEGORY`, `AI_MODEL` and `USER`, which no requirement produces. Document them as reserved or trim them |
| **GAP-08** | Audit, error handling and password policy have tables and FRs but no RF. Name them in the SRS as cross-cutting requirements |

---

## 3. Entities with no table

Three entities in `02-domain/entities-and-rules.md` have nowhere to live. **An entity with no table is a
promise nobody can keep**, and this is the shortest list worth acting on:

| Entity | Status | Consequence |
|--------|--------|-------------|
| `TranslationSession` | ⚠️ **The Core aggregate root**, no table | ALIGN-01 |
| `ConsentGrant` | An aggregate with a lifecycle, flattened into columns on `users` and `gesture_samples` | Revocation (INV-009) has no row to write to, so "terminal revocation" is currently unimplementable as modeled |
| `DataDeletionRequest` | Reduced to `users.deleted_at` | There is no record of *when* the request was made versus when it was executed, which is what a Law 1581 audit asks for |

---

## 4. Closed

| ID | How it was closed |
|----|-------------------|
| **DATA-01** | ✅ v9 — the model of record is now `traduce_senas.dbml`. **The version lives in the header, not in the filename**, so a version bump never again leaves a stale pointer in another section. This is the fix that prevents the problem from recurring, rather than the one that renames the file once |
| **GAP-02** | ✅ Already fixed before v8 was circulated — `sign_translations` removed. Recorded so the fix is not undone |
| **GAP-03** | ✅ v9 — `password_reset_tokens` → `user_tokens` in the DBML traceability comment |
| **GAP-04** | ✅ v9 — the RF2 line now says what actually happens: no tables of its own, one `SECTION_VIEW` row per section entry |

> **Closed items stay here for one revision, then go.** A list where everything is done stops being read.

---

## 5. Priority order

**Do now, no decision attached:** DATA-11 (write the constraints migration), DATA-07 (the trigger).

**Legal obligation:** DATA-06 (anonymization on deletion, both stores).

**One small decision each:** DATA-02, DATA-03, DATA-04, DATA-12.

**Blocking model decisions, for the team:** ALIGN-01 and ALIGN-02 — both are design reversals, both
belong to the team and the instructor, and neither should be settled by a documentation pass.

**Everything else** can wait for a sprint, but not for the code: naming is cheap to fix now and expensive
to fix once there are queries written against it.

---

## How to use this list

1. At each **Sprint Planning**, review this table and assign the items whose priority is High.
2. When an item is closed, **remove the row** and note it in the change log of the affected file — a
   list of items that are all "done" stops being read.
3. When a new inconsistency is found, add it here with the next `DATA-nn`, not in the file where it was
   noticed. One list, one place.
4. **Never close an ALIGN or GAP item from this side.** They belong to `02-domain/` and
   `04-requirements/`; this file only records what they mean for the schema.

---

## Correlations

- Domain-side inconsistencies → `02-domain/domain-map.md` § 6
- Requirement-side gaps → `04-requirements/traceability-matrix.md` § 6
- The constraints that close DATA-11 → [`constraints.md`](constraints.md)
- The deletion routine that closes DATA-06 → [`data-lifecycle.md`](data-lifecycle.md)
