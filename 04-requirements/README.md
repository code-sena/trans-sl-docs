# 04 — Requirements

> **Status:** 🟡 Living document — baseline v0.1, 2026-09-08
> **Project:** TraduceSeña 2.0 — Colombian Sign Language (LSC) translation app
> **What is this?** The formal specification of what the system must do.
> Functional: what it does. Non-functional: how well it does it.

---

## ⚠️ Read this first

This section was **filled in from the data model**, not from the SRS. The v8
DBML (`traduce_senas.dbml`, model v9) is the most complete artifact the project has:
it carries explicit references to RF1–RF7 and to the ERFs, and it encodes design
decisions that no other document records.

That means two things:

1. **The FR catalog is a reconstruction.** It is faithful to the model and to
   the SRS references embedded in it, but it must be **reviewed against the
   actual SRS** and corrected wherever the two disagree. The SRS wins.
2. **The comparison surfaced defects.** Checking in both directions — every
   requirement needs a table, every table needs a requirement — produced ten
   gaps, recorded in `traceability-matrix.md` § 6. Two of them need a decision
   from the team and the instructor.

This is a baseline, not a finished document. It is deliberately versioned and
carries a change log per file so the work is visible as it evolves.

---

## Current state of this section

| File | State | Content |
|------|-------|---------|
| `functional.md` ⭐ | ✅ v0.1 | 79 functional requirements across 11 modules |
| `non-functional.md` ⭐ | ✅ v0.1 | 10 NFRs with real metrics for this project |
| `user-stories.md` | ✅ v0.1 | 11 epics, 53 user stories with Gherkin criteria |
| `traceability-matrix.md` ⭐ | ✅ v0.1 | SRS→FR→HU→test→module→tables + 10 gaps |
| `_template-hu.md` | ✅ | Template for a new user story |

### Baseline numbers

| Metric | Value |
|--------|-------|
| Functional requirements | 79 (62 Must · 12 Should · 5 Could) |
| Non-functional requirements | 10 |
| User stories | 53 across 11 epics |
| Total story points | 226 |
| Planned sprints | 7 |
| Tables in the model | 28 relational + 1 MongoDB collection |
| Requirement coverage | 17/17 SRS requirements have at least one FR |
| Open gaps | 10 (2 need a decision) |

---

## Types of requirements

### Functional (FR)

Describe **what the system does**: functions, behaviors, data transformations.
*Example: FR-401 — "The system must capture sign language through the device camera and translate it into written text in real time."*

### Non-functional (NFR)

Describe **how it does it**: quality, performance, availability, security, accessibility.
*Example: NFR-002 — "Camera-to-result latency below 500 ms per recognized sign on a mid-range device."*

NFRs are usually harder to meet than FRs and are ignored more often. **They are equally important** — and in this project one of them, accessibility, is the reason the product exists at all.

---

## What is in each file

### `functional.md` ⭐

The full catalog of functional requirements, organized by module (each module
matches a `TableGroup` in the data model). Each FR states the SRS requirement
that originates it, the user story that plans it, its MoSCoW priority and the
tables that persist it.

**Numbering:** by series, so a module can grow without renumbering everything.

| Series | Module |
|--------|--------|
| FR-0xx | Identity |
| FR-1xx | Authorization |
| FR-2xx | Profile |
| FR-3xx | Lexicon |
| FR-4xx | Translation |
| FR-5xx | Notification |
| FR-6xx | AI |
| FR-7xx | Usage |
| FR-8xx | Gamification ⚠️ conditional on RF8 |
| FR-9xx | Audit / Configuration |
| FR-95x | Navigation |

### `non-functional.md` ⭐

Ten NFRs with real, project-specific metrics — not template placeholders.

**Accessibility is NFR-001, deliberately.** The primary users are deaf and
hard-of-hearing people. A sound-dependent alert is not a minor annoyance here;
it makes the app unusable for the exact population it serves. Every other
decision is checked against that constraint.

Also includes recognition latency as the user perceives it — flagged, because
**where inference runs is still an open decision** in `02-domain/domain-map.md`
§5 — and Law 1581 of 2012 compliance, which is what makes the gesture sample
dataset legally usable.

### `user-stories.md`

The backlog: 11 epics, 53 stories, with acceptance criteria in Gherkin.

**Four concrete roles**, never "as a user": deaf or hard-of-hearing person,
hearing learner, administrator, LSC linguist.

Each story carries story points, MoSCoW priority, target sprint, dependencies
and module. EP-009 (gamification) is created `⏸ Blocked` pending the RF8
decision, so nothing gets built before the scope question is settled.

### `traceability-matrix.md` ⭐

Connects everything, in both directions:

```
SRS (RF/ERF) → FR → HU → Test case → Module → Tables
```

Includes the check most matrices skip: **table → FR**. That is what surfaced
GAP-01 (two tables nobody asked for) and GAP-02 (one table duplicated). It also
flags that sprints 4, 5 and 6 are overloaded — left visible on purpose, because
a planning problem hidden at baseline reappears at the Sprint Review.

### `_template-hu.md`

Template for adding a new user story without losing the format. Adapted to this
project: the four real roles and the twelve module abbreviations.

---

## Decisions pending for the instructor

| # | Decision | Where | Impact |
|---|----------|-------|--------|
| 1 | **Does RF8 (gamification) enter the SRS?** The `achievements` and `user_achievements` tables exist with no requirement behind them. Either RF8 is added, or both tables and the FR-800 series are removed. The RF8 draft and its four user stories are already written and blocked, ready either way. | `traceability-matrix.md` § 6, GAP-01 | 2 tables, 5 FRs, 4 HUs, 13 points |
| 2 | **Is `translations.model_id` mandatory?** It is nullable today, but FR-403 requires every translation to record the model that produced it. A nullable field means a translation can exist with no traceability, which defeats the field's stated purpose. | `traceability-matrix.md` § 6, GAP-06 | Traceability of the AI model |

---

## Immediate work, no decision needed

Three DBML corrections that close the traceability without changing any design decision:

- **GAP-02** — remove `sign_translations` (it duplicates `sign_localizations`)
- **GAP-03** — the traceability comment cites `password_reset_tokens`, a table that does not exist; the real one is `user_tokens`
- **GAP-04** — the comment states RF2 has "no persistence", but section entries are persisted in `usage_events` for RF6

And one piece of pending work:

- **GAP-05** — write `migrations/002_constraints.sql`. Six constraints are declared in a DBML comment and four more are missing. A constraint that lives only in a comment is a comment: the database will accept `confidence = 47.3` until the DDL says otherwise.

---

## Correlations with other sections

| This section feeds… | Why |
|---------------------|-----|
| `05-architecture/` | NFR-002 (recognition latency) and NFR-003 (degradation with no connection) are what the open inference decision has to be weighed against |
| `06-data/` | The FR → tables matrix is what validates the data model against the requirements |
| `02-domain/` | Every FR must land in a bounded context; the domain invariants (INV-001…) become acceptance criteria |
| `07-api/` | Each FR with an interaction becomes an endpoint in the API contracts |
| `11-quality/testing-strategy.md` | Each FR already has a named test case in the matrix |
| `10-devops/` | The NFRs that are validated in CI define the pipeline gates |
| `15-project-control/risks.md` | GAP-01 (undefined scope) and the overloaded sprints are project risks, not just documentation defects |

---

## Common mistakes to avoid

❌ **"The system must be fast"** → not measurable. Better: "P95 < 300 ms under 50 RPS"

❌ **"The system must be secure"** → not verifiable. Better: "JWT expiring in 1 h, bcrypt cost ≥ 12, rotating refresh tokens"

❌ **A table with no requirement** → gold-plating. That is GAP-01.

❌ **A requirement with no table** → something nobody can store.

❌ **A constraint written only in a comment** → the database does not read comments.

❌ Writing requirements that describe the solution instead of the problem.

✅ A good requirement is **specific, measurable, achievable, relevant and verifiable**.

---

## Questions this section answers

- What must the system do for each of the four roles? → `functional.md`
- With what speed, availability, security and **accessibility**? → `non-functional.md`
- Which requirement originates each test case? → `traceability-matrix.md` § 2
- Is every requirement covered by a test? → `traceability-matrix.md` § 7
- Is every table justified by a requirement? → `traceability-matrix.md` § 3
- What is wrong with the data model and how is it fixed? → `traceability-matrix.md` § 6

---

## How to keep this section alive

1. When the SRS changes → update `functional.md` and re-check § 1 of the matrix
2. When an HU is created → add it to `user-stories.md` and to both matrix sections
3. When a test is written → note the file in the matrix
4. When a table is added to the model → add it to matrix § 3 with the FR that justifies it. **A table with no FR does not enter the model.**
5. At each Sprint Planning → review the gaps in matrix § 6
6. Every change → bump the version and add a row to that file's change log

---

## Change log for this section

| Version | Date | Change | Author |
|---------|------|--------|--------|
| v0.1 | 2026-09-08 | Baseline. Empty templates replaced with real content reconstructed from the v8 data model. `functional.md` created (the README required it and it did not exist). 10 gaps recorded in the traceability matrix, 2 requiring a decision. | Juan Mauricio Suaza Solórzano |
