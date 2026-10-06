# 06 — Data

> **What is this?** How Traduce Señas stores, structures and migrates its data. It is the physical
> counterpart of `02-domain/`: every entity there becomes a table here, or it is an entity nobody can
> persist.

**Status:** 🟡 Living document — v0.3, 2026-09-10 · **Maintainer:** Juan Mauricio Suaza Solórzano
**Model of record:** `traduce_senas.dbml` — model **v9**: 29 tables, 10 domains, 21 enum types

---

## ⚠️ Read this first

**Traduce Señas is a microservices architecture, and the rule is: database per service.**

Each service (iam, recognition, lexicon, analytics, profile) owns its own store, and the 10 domains of
this model are distributed among them:

| Service | Domains it owns | Store |
|---------|-----------------|-------|
| iam-service | 01-identity, 02-authorization, 10-audit | PostgreSQL db `iam` |
| recognition-service | 05-translation, 06-ai | PostgreSQL db `recognition` + MongoDB `gesture_samples` |
| lexicon-service | 04-lexicon | PostgreSQL db `lexicon` + static media |
| analytics-service | 08-usage | PostgreSQL db `analytics` |
| profile-service | 03-profile, 07-notification, 09-gamification | PostgreSQL db `profile` |

> **No service reads another service's tables, and there are no foreign keys across services.**
> Cross-service references are logical IDs (for example the `user_id` UUID issued by iam-service),
> and consistency between services is kept with asynchronous domain events over RabbitMQ.

The model of record (`traduce_senas.dbml`) still describes all 10 domains in one file; read each
domain's "Owned by" line to know where it is deployed. Extraction status: the backend code is still
being split from the original domain modules into these services (pending / in progress).

---

## How this folder is organized

**One file per domain, plus the cross-cutting rules that apply to all of them.** The domain files are
the reference you open while writing a query; the root files are the ones you read once and then follow.

```
06-data/
├── README.md                     ← you are here
├── models.md                     ⭐ overview: engines, schema map, cross-domain diagram, ER diagrams
├── modeling-conventions.md          naming, keys, timestamps, referential actions, the 21 enums
├── constraints.md                   002_constraints.sql in full — CHECKs, partial indexes, triggers
├── normalization-assessment.md      3NF and the four deliberate denormalizations
├── migration-strategy.md            tool, order, compatible vs incompatible changes, rollback
├── data-lifecycle.md                retention, right of deletion, Law 1581
├── open-items.md                 ⭐ DATA-02…DATA-12 + the data consequence of every ALIGN and GAP
├── traduce_senas.dbml               the model of record (v9) — the version lives in its header
└── domains/
    ├── 01-identity.md               users, auth providers, sessions, tokens, password policies
    ├── 02-authorization.md          roles, permissions and their two junction tables
    ├── 03-profile.md                user preferences — theme, language, notification switch
    ├── 04-lexicon.md                sign catalog, localizations, categories, multimedia
    ├── 05-translation.md         ⭐ Core — translations and their ordered signs
    ├── 06-ai.md                     ai_models (PostgreSQL) + gesture_samples (MongoDB)
    ├── 07-notification.md           types, devices, notifications, delivery states
    ├── 08-usage.md                  usage events and the two daily rollups
    ├── 09-gamification.md        ⏸ achievements — not built until RF8 exists
    ├── 10-audit.md                  audit trail and error log
    └── 11-configuration.md       ⛔ dissolved in v9 — kept as the record of a reversed decision
```

**Every domain file has the same shape:** what the domain owns → the DDL of each table → a data
dictionary for the columns that are not self-evident → the modeling decisions worth defending → the
invariants it enforces → the open items affecting it → correlations.

### Where to start

| If you are… | Read |
|-------------|------|
| Writing a query or a repository | The relevant [`domains/`](domains/) file |
| Adding a table or a column | [`modeling-conventions.md`](modeling-conventions.md), then the domain file, then [`migration-strategy.md`](migration-strategy.md) |
| Reviewing the model as a whole | [`models.md`](models.md), then [`open-items.md`](open-items.md) |
| Setting up the database | [`migration-strategy.md`](migration-strategy.md) and [`constraints.md`](constraints.md) |
| Answering a question about privacy or deletion | [`data-lifecycle.md`](data-lifecycle.md) |

---

## The state of this model, honestly

The documents are a **baseline**, faithful to the DBML including where the DBML disagrees with
`02-domain/`. Those disagreements are listed, not resolved: reversing a design decision belongs to the
team, not to a documentation pass.

Immediate work, none of it requiring a decision:

| Item | What | Why now |
|------|------|---------|
| **DATA-11** | Write `migrations/V010__constraints_and_triggers.sql` — its full content is [`constraints.md`](constraints.md) | Until it exists the database accepts `confidence = 9.5`, two active AI models and two password policies in force. **A constraint that lives only in a comment is a comment** |
| **DATA-07** | Add the `set_updated_at()` trigger to the six tables with an `updated_at` | The column currently never changes after insert — it is a creation timestamp with a misleading name |
| **DATA-06** | Implement the anonymization routine for deleted accounts, including the MongoDB side | A soft-deleted `users` row still holds name, email and username in clear, and gesture samples are reached by no cascade at all. Under Law 1581 that is the gap between a compliant deletion and a nominal one |
| **DATA-02** | Give `sign_lexicon.created_by` / `updated_by` a foreign key, or document them as external identifiers | Their note says "NULL if that account was deleted", which is `ON DELETE SET NULL` behaviour that nothing implements |

One more needs a small decision: **DATA-03** (the two rollup tables have no requirement behind them and
contradict the domain map). Two are blocking and belong to the team: **ALIGN-01** and **ALIGN-02**.

**Closed in v9:** DATA-01 (the model file no longer carries the version in its name), GAP-03 and GAP-04.

Full list with actions and priorities: [`open-items.md`](open-items.md).

---

## Correlations with other sections

| Fed by… | Feeds… |
|---------|--------|
| `02-domain/entities-and-rules.md` — entities and invariants INV-001…INV-027 | `07-api/contracts/openapi/` — what each endpoint exposes |
| `02-domain/domain-map.md` — bounded contexts become schemas | `08-uml/` — ER and class diagrams |
| `04-requirements/traceability-matrix.md` § 3 — the FR → tables check | `11-quality/` — one test per invariant |
| `05-architecture/` — engine and deployment decisions | `10-devops/local-setup.md` — running migrations locally |
| `00-governance/security-policy.md` — encryption at rest, secret handling | `13-operations/observability.md` — log retention (DATA-10) |

---

## How to maintain this section

1. **A table with no requirement does not enter the model.** This is the rule that surfaced GAP-01 and
   DATA-03; it only works if it is applied before the table is added, not after.
2. Any schema change is a migration file, never an edit to a table in place — and never an edit to a
   migration that has already run somewhere.
3. When a table is added or changed: update its **domain file**, update the DBML, and add the row to
   `04-requirements/traceability-matrix.md` § 3. All three in the same PR — the DoD requires it.
4. A new table in an existing domain goes in that domain's file. **A new domain is a new file in
   `domains/`, added to the map in [`models.md`](models.md) § 2** — and needs a bounded context in
   `02-domain/domain-map.md` first, or it is a schema with no owner.
5. If a change contradicts an invariant in `02-domain/`, record it in [`open-items.md`](open-items.md)
   rather than quietly rewriting the invariant. A reversed decision with its reason is documentation; a
   silently edited one is a lost argument.

## Questions this section answers

- **What data does the system hold, and which module owns each piece?** [`models.md`](models.md) § 2
- **Why PostgreSQL for almost everything and MongoDB for one collection?** [`models.md`](models.md) § 1
- **What does each column actually mean?** the data dictionary in the relevant [`domains/`](domains/) file
- **What rules does the database enforce, and which does it not enforce yet?** [`constraints.md`](constraints.md)
- **How does the schema change without breaking a running system?** [`migration-strategy.md`](migration-strategy.md)
- **What happens to a user's data when they exercise their right to deletion?** [`data-lifecycle.md`](data-lifecycle.md)
