# 15 — Project Control

> **What is this?** Project administration: risks, dependencies, unanswered questions,
> and technical debt. The difference between a project that gets delivered and one that "keeps getting delayed".

---

## What is here and how to fill it in

### `risks.md` ✓ FILLED
Project risk register.
**Status:** FILLED — 7 risks identified covering: LSC dataset limitations (R-001), model accuracy degradation (R-002), SENA timeline compression (R-003), team single points of failure (R-004), TensorFlow dependency (R-005), privacy/compliance risk under Law 1581 (R-006), single-server infrastructure (R-007).
See file for mitigation and contingency plans per risk.

### `dependencies.md` ✓ FILLED
External project dependencies: third-party services, APIs, external teams.
**Status:** FILLED — 9 critical/non-critical dependencies tracked: Google OAuth, Facebook, Firebase FCM, SMTP, TensorFlow.js, PostgreSQL, MongoDB, React Native, MediaPipe.
Each includes fallback plans and coordination points with SENA IT.

### `open-questions.md` ⭐ ✓ FILLED
Unanswered questions that block or could block the project.
**Status:** FILLED — 7 questions including critical ones: Q-001 (inference location), Q-002 (staging environment), Q-003 (model accuracy threshold), Q-004 (consent revocation), Q-005–Q-007 (lower priority).
When answered, decisions become ADRs (05-architecture/decisions/).

### `technical-backlog.md` ✓ FILLED
Technical debt and technical improvements identified.
**Status:** FILLED — 13 items organized by priority (critical: logging, health checks, metrics, error logs; high: audit, rate limiting, CORS; medium: transactions, retries, feature flags; low: testing, tracing, idempotency).
All items link to blocking features or risk mitigations.

---

## Correlations with other sections

| Fed by... | Why |
|-----------|-----|
| `05-architecture/` — difficult decisions | Technical risks |
| `04-requirements/` — demanding NFRs | Performance risks |
| Incidents in `13-operations/` | Post-incident technical debt |
| `03-product/product-backlog.md` | Coordination of technical vs business priorities |

---

## Questions this section must answer

- What can go wrong and how prepared are we?
- What external things do we depend on that we do not control?
- What decisions are blocked waiting for information?
- What code needs to be improved before it becomes a bigger problem?
