# ADR-006 — Continuous Integration and Static Analysis

> Based on: Backend `19ff387` (`origin/main`, v1.2.0), Frontend `origin/develop` after #62, #64 and #65

- **ID:** ADR-006
- **Date:** 2026-10-23
- **Status:** Accepted
- **Authors:** Luis Alejandro Duarte Aldana (proposal and implementation); accepted by the development team on 2026-10-23 (PRs reviewed and merged by both developers)

---

## Context

Until 2026-10-23 **no repository had CI** (finding H-03 of the 2026-10-21 evaluation). Tests, typecheck and builds ran only when someone remembered to run them; a fix for Android reached `develop` with no automatic check. The Definition of Done (`00-governance/definition-of-done.md`) already asked for "CI green", which nobody could meet.

**Known constraints:**
- GitHub repositories, public; no paid CI.
- The backend has Postgres integration tests that were silently skipped without a database (`PROFILE_TEST_DATABASE_URL`).
- The frontend web image is built with a Dockerfile that production uses (`web` service behind Caddy).

---

## Decision

**We decided:** every pull request and every push to `develop` and `main` runs a GitHub Actions workflow (`.github/workflows/ci.yml`) in both code repositories, and the frontend is also analyzed by SonarCloud with its default quality gate.

| Repository | Job | Steps |
|------------|-----|-------|
| backendTS | **Build and test** | `npm ci --ignore-scripts` (plus `npm rebuild bcrypt`), `npm run build`, `npm test`, with a throwaway `postgres:16-alpine` service so the profile and analytics integration tests run (`PROFILE_PREFERENCES_PG_TESTS=1`, `GAMIFICATION_PG_TESTS=1`) |
| frontendTS | **Typecheck, test and web build** | `npm ci`, `npm run typecheck`, `npm test -- --ci --coverage`, `expo export --platform web`, then **SonarCloud scan** (only when the `SONAR_TOKEN` secret exists) |
| frontendTS | **Docker image** | `docker build` and a smoke test: the SPA is served on port 80, unknown routes fall back to `index.html`, the process is not root, the CSP header is present |

Hardening applied to the workflows: read-only `contents` permission, actions pinned by commit SHA, no persisted credentials, timeouts, and cancellation of older runs on the same ref.

SonarCloud project `tadeo77789_frontendTS` (configuration in `sonar-project.properties`): sources `src` and `Dockerfile`; coverage from `coverage/lcov.info`; locale files excluded from duplication; screens, providers and visual components excluded from coverage (they are tested by hand); long-lived branches pattern `(main|develop|(branch|release)-.*)`. Quality gate: "Sonar way" on new code (coverage ≥ 80 %, duplication ≤ 3 %, ratings A).

**Justification:**
- GitHub Actions is free for public repositories and already where the code and PRs live.
- Running the Postgres tests in CI exposed two existing failures on its first run (a stale test fixture and a timing issue), which shows the value of the change.
- SonarCloud adds bug, vulnerability and duplication checks the test suite does not cover, and comments the result on each PR.

---

## Evaluated alternatives

| Alternative | Pros | Cons | Reason for discarding |
|------------|------|------|-----------------------|
| GitHub Actions + SonarCloud (chosen) | Free, integrated with PRs, quality gate per PR | SonarCloud needs a token secret and project setup | — (chosen) |
| GitHub Actions only | Less setup | No static analysis of bugs and vulnerabilities | SonarCloud found real issues (unhandled promises, Dockerfile risks) |
| SonarCloud automatic analysis (no CI scan) | No token or workflow step | No coverage data; cannot run together with CI analysis | Coverage is part of the quality gate |
| Self-hosted CI (Jenkins, Drone) | Full control | A server to maintain | No infrastructure budget; Actions is enough |

---

## Consequences

**Positive:**
- Every PR shows green or red checks before review; the evaluation's closing criterion for H-03 ("each PR shows a green Actions check") is met.
- The backend runs 750 tests in CI, including the Postgres ones; the frontend runs its tests with coverage and builds the same image production uses.

**Negative / Trade-offs:**
- The checks are **not yet required** by branch rules; a PR can still be merged with a red check until the rulesets are set (task M4 / L1 in `notas/ejecucion-100.md`).
- Backend PRs also show a SonarCloud check, but it is not run from the backend CI and receives no coverage report; to confirm how it is configured.
- The quality gate on new code is strict (80 % coverage); PRs that add UI logic need tests or the gate fails.

**Impact on the system:**
- Affected repositories: backendTS, frontendTS.
- Documents to keep in sync: `11-quality/testing-strategy.md`, `00-governance/definition-of-done.md`, `10-devops/`.

---

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Checks ignored because they are not required | Medium | Medium | Mark them required in the GitHub rulesets |
| `SONAR_TOKEN` expires or is revoked | Low | Low | The scan step is skipped instead of failing; renew the token in SonarCloud and in the repo secrets |
| A pinned action has a security fix | Low | Medium | Review and bump the pinned SHAs when GitHub announces a fix |

---

## References

- Backend: #51 (CI); Frontend: #62 (CI), #64 (SonarCloud), #65 (Docker image job)
- `.github/workflows/ci.yml` in both repositories; `sonar-project.properties` in frontendTS
- Evaluation of 2026-10-21, findings H-03 and H-14
- Related to: ADR-004 (microservices, one test suite per service)
