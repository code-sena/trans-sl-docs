# ADR-009 — Daily Challenges Assigned Once per Day, Counted per Saved Translation

> Based on: Backend `develop` (profile-service, migration `009_daily_challenges.sql`)

- **ID:** ADR-009
- **Date:** 2026-10-27
- **Status:** Accepted
- **Authors:** Juan Camilo Fierro (implementation, backend PR #67 and frontend PR #85); recorded by the documentation team

---

## Context

Achievements reward long-term milestones, but nothing encouraged a user to come back every day. A daily challenge ("save N translations today") gives a small, repeatable goal. It had to fit into profile-service without new services, without touching the gateway and without giving points twice if an event is delivered again.

**Known constraints:**
- Events from RabbitMQ can arrive late or twice; consumers are idempotent by `eventId` and by `translationId`.
- There are no foreign keys between services (ADR-003, ADR-004): `user_id` is a logical id of iam-service.
- Users can delete their account (`erased_users` must stop late events from recreating data).
- Every notice must be visual (INV-023).

---

## Decision

**We decided:** profile-service assigns one challenge per user and per day, keeps a snapshot of it, advances it only when a translation is saved and confirmed, and grants the reward exactly once.

How it works:

1. **Catalog and daily choice.** Table `challenges` holds the definitions (seeds `TRANSLATE_1`, `TRANSLATE_3`, `TRANSLATE_5`, `TRANSLATE_8`: goal 1/3/5/8 translations, reward 5/10/15/25 points, texts in ES/EN/FR/PT). Active definitions are sorted by `code` and the one at index (days since 1970-01-01) modulo (number of definitions) is chosen. The date uses the America/Bogota time zone, not the host's. All eligible users without an assignment see the same challenge that day.
2. **Snapshot.** The first time the challenge advances, a row is created in `user_challenges` with `UNIQUE(user_id, challenge_date)`, copying code, name, description, goal, points and texts. Changing or disabling a definition later does not alter assignments already stored.
3. **Counting.** Only the `recognition.TranslationProduced` event advances the challenge: one saved and confirmed translation counts once, not each prediction or each word of a phrase. The day comes from `occurredAt` (in Bogota time), so a yesterday event can only advance yesterday's assignment. The update runs inside the existing once-only processing of the translation event (same per-user lock, `erased_users` check and receipt per `translationId`). A completed challenge is never reopened and its counter never exceeds the goal.
4. **Idempotent reward.** On completion a row is inserted in `challenge_rewards` whose primary key is `user_challenge_id`, so a second grant is impossible. `challenges.points` and `user_challenges.points` are the planned reward; the points really granted live only in `challenge_rewards`.
5. **Notice.** If the user has notifications enabled, an `IN_APP` notification of type `CHALLENGE_COMPLETED` is created with reference type `CHALLENGE` and the assignment UUID. Progress, completion, reward and notice are committed or rolled back together. Turning notices off keeps the points and the completion.
6. **Reading.** `GET /api/profile/challenges/today` (JWT, identity only from the token, administrators with `users.manage` get `403`) returns the day's progress. It creates nothing: without activity it answers zero progress, and an erased account answers `data: null`.

**Justification:** a deterministic choice by date needs no scheduler and no table filled in advance. The snapshot protects what the user already sees when the catalog changes. A primary key on the reward is the simplest guarantee against double points, and reusing the existing translation processing avoids a second consumer with its own race conditions.

---

## Evaluated alternatives

| Alternative | Pros | Cons | Reason for discarding |
|------------|------|------|-----------------------|
| Deterministic daily choice plus snapshot per user (chosen) | No scheduler; stable history; same challenge for everyone | Less variety; rotation is predictable | — (chosen) |
| Nightly job that creates every user's challenge | Allows random or personal challenges | Needs a scheduler, creates rows for inactive users | Too much machinery for the current volume |
| Count each recognition prediction or word | Faster progress | Easy to inflate; a phrase would count many times | Does not measure real use |
| Add points directly to the achievement counters | One less table | Mixes two kinds of points; history can not be audited | Rewards are kept apart in `challenge_rewards` |

---

## Consequences

**Positive:**
- A visible daily goal in the profile that refreshes when a translation is saved.
- Points can not be granted twice, even with repeated or concurrent events.
- Catalog changes never rewrite history.

**Negative / Trade-offs:**
- There is no replay: events that were not processed on their day are not rebuilt.
- Rotation depends on the number of active definitions; adding one changes which challenge comes up on a given day for users without assignment.
- Existing databases need a manual migration (the init scripts only run on new volumes).

**Impact on the system:**
- Affected services: profile-service (domain `challenge.ts`, use case `daily_challenge.ts`, `ChallengeRepository`, route `GET /api/profile/challenges/today`); frontend (daily progress card). The gateway already routes `/api/profile`.
- Documents updated: `06-data/domains/09-gamification.md`, `06-data/domains/07-notification.md`, `07-api/contracts/openapi/profile-service.yaml`, `09-microservices/services/06-profile-service/`.

---

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Migration 009 not applied on an existing database | Medium | High | Manual command in `docker-compose.yml` and in the profile-service runbook; apply 001–009 in order before the new version |
| Day boundary confusion (UTC against Bogota) | Low | Medium | The date is always computed in America/Bogota |
| Late events after account deletion | Low | Medium | `erased_users` blocks recreation |

---

## References

- `backend/services/profile-service/README.md` — rules of assignment, progress, reward and notice
- Related to: [ADR-004](ADR-004-microservices-architecture.md), [ADR-007](ADR-007-email-notifications.md), [ADR-010](ADR-010-challenge-points-medals.md)
