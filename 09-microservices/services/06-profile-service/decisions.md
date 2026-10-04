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
They live in one service and one database (`profile`), in separate schemas. The code is organized in one hexagonal module per context.

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
`notification_channel` admits `PUSH`, `EMAIL`, `IN_APP` only. No audio-only value can be added. The target users are deaf and hard of hearing; an alert they cannot perceive is information the system failed to deliver.

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
The handler creates the row (no-op if it exists). `GET /api/profile` returns the defaults when there is no row, so a missing row never breaks the home screen.

---

## [DEC-005] One master switch; no per-type user preference

**Date:** 2026-10-04
**Status:** Active (RF4)

**Decision:**
`notifications_enabled` is the only per-user control; `notification_types.is_active` is an administrator control. A per-user matrix is a table without a requirement.

---

## [DEC-006] Gamification is not built until RF8 is approved

**Date:** 2026-10-04
**Status:** Proposed (blocked by GAP-01)

**Decision:**
The `gamification` schema is a separate changelog and the routes `/api/achievements/**` return `404` until RF8 is approved. Nothing in notifications or analytics depends on it.

---

## [DEC-007] Push token is a credential

**Date:** 2026-10-04
**Status:** Active

**Decision:**
Registration is an upsert on `push_token` that re-points the row at the current user. The token is never written to logs or events, and the column is protected with restricted access or column-level encryption.

---

## Correlations

- Data model → [data-model.md](./data-model.md)
- Open items → `06-data/open-items.md` (ALIGN-08, DATA-04, DATA-05, DATA-07, DATA-11, GAP-01, GAP-07)
