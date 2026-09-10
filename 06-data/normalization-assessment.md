# Normalization Assessment

> What normal form this model is in, which four places deliberately break it, and what each of those
> costs. A denormalization nobody wrote down is a bug waiting to be "fixed".

**Version:** v0.1 · **Last updated:** 2026-09-10

---

## Verdict

**The relational model is in Third Normal Form, with four deliberate departures.**

| Form | Status | Evidence |
|------|--------|----------|
| **1NF** | ✅ | No repeating groups, no multi-valued columns, no arrays. Where a one-to-many exists it is a table: `sign_localizations`, `multimedia_resources`, `translation_signs`, `user_auth_providers` |
| **2NF** | ✅ | The only composite keys are `user_roles`, `role_permissions` and `usage_daily_stats`. In each, every non-key column depends on the **whole** key: `assigned_at` depends on the pair, `event_count` on the grain |
| **3NF** | ✅ with four exceptions | No transitive dependencies except the four listed below. Notably, `translations` stores `model_id` and joins for the version rather than copying `ai_models.version` — which is 3NF working correctly |
| **BCNF** | ✅ | No table has a non-trivial functional dependency whose determinant is not a candidate key |

---

## The four deliberate denormalizations

| # | Where | What is denormalized | Why it is kept | What it costs |
|---|-------|---------------------|----------------|---------------|
| 1 | `translations.recognized_text` | The assembled text is derivable by joining `translation_signs` → `sign_localizations` | The history screen is one of the most used views in the app and reads a hundred rows at a time; rebuilding each phrase through two joins per row makes ERF5.5 slow for no benefit. More importantly the text must be **frozen as it was delivered**: if a localization is corrected later, the user's history must not silently change | Two representations of one phrase. If they ever disagree, **the stored text is the truth** — it is what the user actually saw |
| 2 | `user_sessions.duration_seconds` | `ended_at - started_at` | RF6 aggregates over months of sessions; computing an interval per row on every report is work repeated forever for a value that never changes once the session closes | Must be written exactly once, at close. A session with `ended_at` and no duration is a bug no `CHECK` can catch |
| 3 | `usage_daily_stats`, `session_daily_stats` | Everything — both are rollups of `usage_events` and `user_sessions` | The administrator dashboard must answer in under a second over an event log that grows with every screen the users open | Recomputation lag, and the non-additive `unique_users` trap below. They also currently contradict the domain map — DATA-03 |
| 4 | `translations.confidence` alongside `translation_signs.confidence` | The whole-translation confidence next to the per-sign confidence | **They are different measurements, not a copy:** the confidence of a phrase is not the average of its signs' | None, provided nobody tries to derive one from the other |

---

## ⚠️ The cost that bites hardest: `unique_users` is not additive

This is denormalization #3's real price, and it deserves its own heading because it produces wrong
answers silently.

Summing `unique_users` across sections, event types or days **does not** give the number of distinct
users. The same person counted in `HOME` and in `TRANSLATION` is one user, and the sum says two. The
column is valid **only at the grain it was computed at**.

A query that adds it up produces a plausible, wrong number that nobody notices — which is the worst kind
of wrong, and exactly the kind an instructor asks about. Two ways out, both acceptable, neither free:

- Recompute distinct users from `usage_events` whenever the report is not at the stored grain, or
- store an HLL sketch instead of an integer (`postgresql-hll`), which *is* mergeable.

Until one is chosen, every report built on `unique_users` must state its grain on the screen.

---

## Two things that look like denormalization and are not

**`sign_lexicon.code` and `sign_localizations.name`** are not a duplicated name. `code` is a stable
machine identifier the model predicts (`GREETING_HELLO`); `name` is human text that varies per interface
language (*Hola* / *Hello*). Merging them is what would break — adding English would mean retraining the
recognizer.

**`translations.model_id` and `ai_models.version`.** Storing the id and joining for the version is
normal form working correctly. Copying the version string into `translations` would be the
denormalization, and it is deliberately not done.

---

## How to keep the denormalized values honest

| Value | Written when | Reconciliation |
|-------|--------------|----------------|
| `translations.recognized_text` | Once, at insert | Never recomputed — it is a historical record, not a cache |
| `user_sessions.duration_seconds` | Once, at session close | A job can find `ended_at IS NOT NULL AND duration_seconds IS NULL` and fill the gaps |
| `usage_daily_stats`, `session_daily_stats` | By a nightly job, per calendar day | Recompute the last N days on every run: late-arriving events change yesterday's numbers. `calculated_at` is how a reader knows how fresh a row is |
| `user_achievements.current_count` ⏸ | On each qualifying event | A periodic recompute from `usage_events`, since an incremental counter drifts |

**`calculated_at` on both rollup tables exists for this.** It is not decoration: it is what lets the
dashboard say "as of 03:00" instead of implying the number is live.

---

## Correlations

- The tables involved → [`domains/05-translation.md`](domains/05-translation.md), [`domains/08-usage.md`](domains/08-usage.md), [`domains/01-identity.md`](domains/01-identity.md)
- Conventions these decisions sit inside → [`modeling-conventions.md`](modeling-conventions.md)
- DATA-03, the rollups' missing requirement → [`open-items.md`](open-items.md)
- Performance requirements the denormalizations serve → `04-requirements/non-functional.md`
