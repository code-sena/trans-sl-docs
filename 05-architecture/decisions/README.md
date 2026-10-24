# ADRs — Architecture Decision Records

ADRs document important architectural decisions. Each file = one decision.

## How to create an ADR

1. Copy `_template-adr.md`
2. Name it `ADR-NNN-short-title.md` (e.g.: `ADR-001-message-broker.md`)
3. Fill it in completely — especially the evaluated alternatives
4. Once accepted, the status is **permanent** (it is not deleted, it is "Superseded" by another ADR)

## Possible statuses

- `Proposed` — under discussion
- `Accepted` — approved by the team
- `Rejected` — evaluated and discarded (document why)
- `Superseded` — superseded by ADR-NNN (indicate which one)

## ADR register

| # | Title | Status | Date |
|---|-------|--------|------|
| [ADR-001](records/ADR-001-documentation-language.md) | Documentation Language | Accepted | 2026-09-08 |
| [ADR-002](records/ADR-002-jwt-authentication.md) | JWT Authentication | Accepted | 2026-09-08 |
| [ADR-003](records/ADR-003-database-separation.md) | Database Separation (PostgreSQL + MongoDB) | Accepted | 2026-09-08 |
| [ADR-004](records/ADR-004-microservices-architecture.md) | Microservices Architecture | Accepted | 2026-10-05 |
| [ADR-005](records/ADR-005-terms-consent.md) | Express Consent on Account Creation (Ley 1581) | Accepted | 2026-10-23 |
| [ADR-006](records/ADR-006-ci-and-static-analysis.md) | Continuous Integration and Static Analysis | Accepted | 2026-10-23 |

> Add rows here as you create ADRs in `records/`. ADR-004 records a decision that was taken orally on 2026-09-28 ("modular monolith") and replaced on 2026-10-05; there was no earlier ADR to supersede.
