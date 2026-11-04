# Design Decisions — Profile Service

> Decisions specific to this service. Global ones go in `05-architecture/decisions/records/`.

---

## [DEC-001] Three contexts in one service

**Date:** 2026-10-04
**Status:** Active (product decision)

**Context:**
Profile & Preferences, Notifications and Gamification are small and tightly related: the switch in the preferences suppresses
notifications, and achievements surface as notifications.

**Decision:**
They live in one service and one database (`profile`). The code is organized in one hexagonal module per context; the tables are in schema `public`.

**Alternatives considered:**
- Three services: more infrastructure than the size of the data justifies, and the `notifications_enabled` check would become a network call.

**Consequences:**
- Advantage: INV-025 is checked locally, in the same database.
- Trade-off: the service has two reasons to change; keep module boundaries clean so it can be split later.

---

## [DEC-002] No audio-only channel, enforced by the type

**Date:** 2026-10-04
**Status:** Active (INV-023)

**Decision:**
`notification_channel` admits `IN_APP` and `EMAIL` only (`PUSH` was dropped, ADR-007). No audio-only value can be added. The target users are deaf and hard of hearing; an alert they cannot perceive is information the system failed to deliver.

---

## [DEC-003] The notification references its cause without a foreign key

**Date:** 2026-10-04
**Status:** Active

**Context:**
A notification can be caused by an achievement or a translation, which lives in this or another service.

**Decision:**
`reference_type` + `reference_id`, no FK. Notifications do not depend on Gamification, so RF8 can be rejected without breaking them, and they do not depend on recognition either.

**Consequences:**
- Advantage: a provisional context is removable.
- Trade-off: the application validates the reference.

---

## [DEC-004] Preferences are created by an event, and the read path tolerates a missing row

**Date:** 2026-10-04
**Status:** Active

**Context:**
The registration happens in iam; the preferences row is created when `iam.UserRegistered` is consumed, which can be late or fail.

**Decision:**
The handler creates the row (no-op if it exists). `GET /api/profile/preferences` returns the defaults when there is no row. `GET /api/profile/me` answers `404` until the profile exists, and a `PATCH` of the preferences creates the profile when it is missing.

---

## [DEC-005] One master switch; no per-type user preference

**Date:** 2026-10-04
**Status:** Active (RF4)

**Decision:**
`notifications_enabled` is the only per-user control; `notification_types.is_active` is an administrator control. A per-user matrix is a table without a requirement.

---

## [DEC-006] Gamification is not built until RF8 is approved

**Date:** 2026-10-04
**Status:** Superseded in the code: the achievements and the daily challenges are implemented as provisional features (RF8 is still not approved, GAP-01)

**Decision (as implemented):**
The achievements live in the `profile` database with the rest of the service, and the routes `/api/achievements/**` answer normally. Their notifications are in-app or email notifications like any other; the medals and challenges follow ADR-009 and ADR-010. If RF8 is rejected, the achievement tables and routes are removed as a unit.

---

## [DEC-007] Push token is a credential

**Date:** 2026-10-04
**Status:** Not applicable: push and devices were dropped (ADR-007). It applies only if push is reintroduced

**Decision:**
Registration is an upsert on `push_token` that re-points the row at the current user. The token is never written to logs or events, and the column is protected with restricted access or column-level encryption.

---

## Correlations

- Data model → [data-model.md](./data-model.md)
- Open items → `06-data/open-items.md` (ALIGN-08, DATA-04, DATA-05, DATA-07, DATA-11, GAP-01, GAP-07)
