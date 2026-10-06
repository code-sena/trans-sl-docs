# Design Decisions — Analytics Service

> Decisions specific to this service. Global ones go in `05-architecture/decisions/records/`.

---

## [DEC-001] Analytics is a consumer fed by events, not by calls

**Date:** 2026-10-04
**Status:** Active (product decision)

**Context:**
Every service produces facts of use. Making each one call analytics would couple the core to a supporting service.

**Decision:**
Services publish domain events to RabbitMQ; analytics subscribes and stores. Analytics is never in the path of a user request.

**Alternatives considered:**
- Each service calls `POST /api/analytics/events`: the core would fail or slow down when analytics is down.

**Consequences:**
- Advantage: analytics can be down or redeployed without affecting translation.
- Trade-off: statistics are eventually consistent.

---

## [DEC-002] `usage_events` survives the user; `user_id` is a nullable logical ID

**Date:** 2026-10-04
**Status:** Active (`06-data/domains/08-usage.md`)

**Context:**
RNF8 requires deleting personal data; RF6 requires stable statistics.

**Decision:**
No FK. On `AccountDeleted` the user reference is set to NULL; the fact remains.

**Consequences:**
- Advantage: reports do not shift when somebody exercises the right to deletion.
- Trade-off: the service must handle the deletion event reliably (it is in the compliance DLQ priority list).

---

## [DEC-003] Rollups are a cache with a recompute job

**Date:** 2026-10-04
**Status:** Active

**Context:**
The dashboard must answer in under a second over a log that grows continuously.

**Decision:**
`usage_daily_stats` and `session_daily_stats` are filled by a daily job (and on demand for the current day) and can be recomputed from `usage_events`.

**Consequences:**
- Advantage: fast dashboard, no loss if a rollup is wrong.
- Trade-off: DATA-03 is open: the requirements matrix and the domain map must acknowledge these tables.

---

## [DEC-004] `unique_users` is shown only at its stored grain

**Date:** 2026-10-04
**Status:** Active

**Decision:**
The API never sums `unique_users` across sections, event types or days. A report at another grain recomputes distinct users from `usage_events`; every report states its grain.

**Consequences:**
- Advantage: no plausible but wrong number.
- Trade-off: some reports query the log instead of the rollup. An HLL sketch is the alternative if that becomes slow.

---

## [DEC-005] Statistics are admin-only and aggregated

**Date:** 2026-10-04
**Status:** Active (INV-012)

**Decision:**
Every route requires the `ADMIN` role (permission `stats.read`) read from the forwarded token. The API returns counts, never individual events.

---

## Correlations

- Data model → [data-model.md](./data-model.md)
- Events → [events.md](./events.md)
- Open items → `06-data/open-items.md` (DATA-03, DATA-09, DATA-10, GAP-04)
