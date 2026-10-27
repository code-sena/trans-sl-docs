# ADR-010 — Medals for Accumulated Challenge Points, Computed from Persisted Rewards

> Based on: Backend `develop` (profile-service, migration `010_challenge_reward_achievements.sql`)

- **ID:** ADR-010
- **Date:** 2026-10-27
- **Status:** Accepted
- **Authors:** Juan Camilo Fierro (implementation, backend PR #69 and frontend PR #86); recorded by the documentation team

---

## Context

With daily challenges ([ADR-009](ADR-009-daily-challenges.md)) users earn points, but the profile only had a plain list of achievements. We wanted medals for long-term effort ("500 points from challenges") and a total of challenge points in the profile, without mixing them with achievement points or inventing a second source of truth.

**Known constraints:**
- Clients of catalog v2 validate a closed list of metrics, so a new metric must not reach them by surprise.
- Reads must not write anything (no profiles, assignments or progress created by looking).
- Users who already earned rewards before the migration must not need to complete another challenge.

---

## Decision

**We decided:** medals are computed from the rewards already stored in `challenge_rewards`; the only measure is the sum of the user's persisted reward points. The medals themselves grant zero extra points.

How it works:

1. **Migration 010** adds the metric `DAILY_CHALLENGE_POINTS` to the allowed metrics and creates three medals in the `achievements` catalog: `dailyChallengePoints500` (bronze), `dailyChallengePoints1000` (silver) and `dailyChallengePoints3000` (gold), with texts in ES/EN/FR/PT and `points = 0`.
2. **Single measure.** Progress is `sum(challenge_rewards.points)` of the user. It excludes the catalog points, partial progress and points of achievements.
3. **Backfill.** The migration initializes `user_achievements` only for users who already have rewards; goals already reached are recognized with the execution date of the migration, with no retroactive notices and no invented historical dates. Repeating the migration keeps existing rows.
4. **New rewards.** Each new reward recalculates the total inside the same transaction and per-user lock, updates the three medals and unlocks and notifies each one once. Retries do not add again.
5. **Catalog versions.** The medals are published in catalog v2 only when the client sends `challengeRewards=1`. Older v2 requests keep their 21 rules and v1 keeps its five.
6. **Summary route.** `GET /api/profile/challenges/rewards/summary` (JWT, `403` for `users.manage`) returns `{ success: true, data: { totalPoints } }` using `COALESCE(SUM(points), 0)` over `challenge_rewards`. It creates nothing; a query error fails instead of returning zero.
7. **Frontend.** A queue of confirmed notices (challenges and achievements), the total of challenge points, four indicators in the profile that adapt to the screen, and the medals in the achievements catalog. The client never grants points: it crosses `CHALLENGE_COMPLETED`, the assignment reference, completion and reward before showing a notice.

**Justification:** reading the persisted rewards keeps one source of truth, so medals can be rebuilt and audited at any time and a retry can not inflate them. The `challengeRewards=1` flag lets old clients keep working with their closed validators.

---

## Evaluated alternatives

| Alternative | Pros | Cons | Reason for discarding |
|------------|------|------|-----------------------|
| Medals from `sum(challenge_rewards.points)` (chosen) | One source of truth; auditable; reusable for the summary route | Needs recalculation on each reward | — (chosen) |
| Separate counter incremented by the client or by events | Cheaper to read | Can drift from the real rewards; double counting on retries | Not reliable |
| Medals that also grant points | More motivation | Points would feed back into the total and mix measures | Medals grant zero points by design |
| Show the new metric to every v2 client | No flag | Breaks clients with closed metric validators | Flag `challengeRewards=1` instead |

---

## Consequences

**Positive:**
- Profile shows a total of challenge points that matches what was really granted.
- Existing users get their medals without extra play.
- Old clients keep working.

**Negative / Trade-offs:**
- The medal date for users recognized by the migration is the migration date, not the real one.
- Migration 010 locks `challenge_rewards`, `user_achievements` and `erased_users` briefly; Profile consumers must be stopped while it runs on an existing database.

**Impact on the system:**
- Affected services: profile-service (migration 010, `challenge_reward_achievements.ts`, summary route); frontend (profile and achievements catalog).
- Documents updated: `06-data/domains/09-gamification.md`, `07-api/contracts/openapi/profile-service.yaml`, `09-microservices/services/06-profile-service/`.

---

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Migration 010 applied before 009 | Low | High | Apply 001–010 in order; documented in the runbook |
| Total outside the safe integer range | Very low | Low | The summary fails instead of returning a wrong number |

---

## References

- `backend/README.md` — section "Recompensas de retos y medallas"
- Related to: [ADR-009](ADR-009-daily-challenges.md)
