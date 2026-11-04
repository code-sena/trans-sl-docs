# Testing Strategy — Traduce Señas

> What the team tests, with which tools, how to run the tests and how much code they cover.
> Complements the TDD guide (`tdd-guide.md`), which explains the process.
>
> **Last verified:** 2026-10-16 against Backend `develop@2993301` and Frontend PR
> [#38](https://github.com/tadeo77789/frontendTS/pull/38) (`chore/frontend-unit-tests`, pending merge into `develop`).
> Figures in this document come from running the suites on those commits; update them when they change.

---

## Current state at a glance

| | Backend (`backendTS`) | Frontend (`frontendTS`) |
|---|---|---|
| **Test runner** | `node:test` (built into Node) + `ts-node` | Jest 29 + `jest-expo` (Expo SDK 57 preset) |
| **Helpers** | `node:assert/strict`, in-memory repositories and fake adapters | `@testing-library/react-native` for hooks |
| **Command** | `npm test` (from the repo root) | `npm test` |
| **Test files** | 72 | 8 |
| **Tests** | 683 (681 pass, 2 skipped without a test database) | 79 |
| **Line coverage** | 88.5 % | 4.5 % |
| **CI** | GitHub Actions (ADR-006) | GitHub Actions: typecheck, Jest, web build, Docker, E2E |

**Summary:** the backend business logic is well covered by unit tests. The frontend has just started
(the figures in the table are a snapshot from before the CI work and the new Jest and Playwright tests).
CI runs the tests on every pull request ([ADR-006](../05-architecture/decisions/records/ADR-006-ci-and-static-analysis.md)) and the Frontend has
Playwright E2E tests (see "End-to-end" below). There are still no contract or performance tests.

---

## Test types

### Unit tests — in place

**Goal:** test business logic in isolation, with no real database, broker, network or device.

#### Backend

- **Location:** `tests/` folder inside each workspace: `packages/shared/tests/`, `services/<service>/tests/`,
  plus `tests/` at the repo root for cross-service checks.
- **Naming:** `<subject>.test.ts`. `scripts/run-tests.js` collects every `*.test.ts` under `tests/`,
  `packages/` and `services/` (Node 20 does not expand globs in `node --test`).
- **Test doubles:** in-memory implementations of the ports (for example `services/profile-service/tests/in_memory.ts`),
  `InMemoryEventBus` from `@traduce/shared` and fake `pg` pools. HTTP routes are tested on the Express app
  without opening a real server where possible.
- **Static checks as tests:** `tests/postgres_schema.test.ts` checks that every table used by a Postgres adapter
  is created by a migration mounted for that service. It reads files only; it needs no database.

#### Frontend

- **Location:** `__tests__/` folder next to the code under test, for example
  `src/shared/utils/__tests__/email.test.ts`. Jest only picks up `src/**/__tests__/**/*.test.ts(x)`.
- **What is covered today:**

  | Area | File under test | Tests |
  |---|---|---|
  | Validation | `shared/utils/email.ts`, `passwordStrength.ts`, `userDisplayName.ts` | 26 |
  | API client | `shared/services/api.client.ts` (error mapping, token only sent to the API, single 401 notice) | 19 |
  | Auth flows | `feature/auth/services/pendingAuthFlow.ts`, `passwordResetFlow.ts` (30-minute expiry) | 14 |
  | Resend cooldown | `feature/auth/hooks/useResendCooldown.ts` | 5 |
  | Sign recognition | `feature/Translation/services/vision/normalize.ts`, `knnClassifier.ts` | 15 |

- **Test doubles:** `jest.mock` for `expo-secure-store` and `templateStore`; the official AsyncStorage mock;
  a custom axios `adapter` to capture outgoing requests instead of calling the server.
- **Setup notes** (in `package.json` → `jest` and `jest.setup.js`):
  - `moduleNameMapper` points `expo-modules-core` to the copy nested inside `expo`.
  - `jest.setup.js` restores Node's native Web Streams; without it, importing axios crashes Jest.
  - `tsconfig.json` declares `"types": ["jest"]`, required by TypeScript 6 for `npm run typecheck`.

### Integration tests — partial

**Goal:** check adapters against real infrastructure.

Three backend suites run against a real PostgreSQL and are **skipped** unless a dedicated, disposable
database is provided:

| Suite | Variables |
|---|---|
| `services/profile-service/tests/preferences_postgres.test.ts` | `PROFILE_TEST_DATABASE_URL`; `PROFILE_PREFERENCES_PG_TESTS=1` makes the suite fail instead of skip when the URL is missing |
| `services/profile-service/tests/gamification_concurrency.test.ts` | `PROFILE_TEST_DATABASE_URL`; `GAMIFICATION_PG_TESTS=1` (same behaviour) |
| `services/analytics-service/tests/atomic_erasure_postgres.test.ts` | `PROFILE_TEST_DATABASE_URL` |

> ⚠️ Never point these variables at a shared or production database: the suites create and drop data.

There are no integration tests yet for RabbitMQ, MongoDB or Liquibase migrations.

### Contract tests — not started

The OpenAPI files in `07-api/contracts/openapi/` are not validated against the running services.

### End-to-end (E2E) tests — started (Frontend)

Playwright runs in the `e2e` job of the Frontend CI (`.github/workflows/ci.yml`): it starts the backend with Docker Compose,
serves the production web build and runs `npm run e2e` in Chromium. Specs in `frontend/e2e/`: `auth.spec.ts` (registration with
consent, verification and login; wrong password), `history.spec.ts` (a saved translation appears in the history and can be
deleted) and `alphabet.spec.ts` (a letter opens its sign). The report is uploaded as an artifact when the job fails.
Besides these, Jest now also covers the services, the auth forms, the vision classifiers and the template stores.

Flows still without E2E coverage (priority list):

| # | Flow | Services involved |
|---|------|-------------------|
| 1 | Register, verify email with the code, log in | api-gateway, iam-service |
| 2 | Log in with Google | api-gateway, iam-service, profile-service |
| 3 | Recognise a sign and save the translation in the history | recognition-service, profile-service, analytics-service |
| 4 | Delete the account with the email code and check the data is removed in every service | iam-service, profile-service, recognition-service, analytics-service |

### Performance tests — not started

No load tests exist. The NFR performance targets are in `04-requirements/non-functional.md`.

---

## How to run the tests

### Backend

```bash
npm ci
npm test            # builds @traduce/shared, then runs every *.test.ts with node:test
```

With a disposable Postgres for the integration suites:

```bash
PROFILE_TEST_DATABASE_URL=postgres://<user>:<password>@<host>:<port>/<empty_test_db> npm test
```

### Frontend

```bash
npm ci
npm test            # jest
npm run typecheck   # tsc --noEmit, includes the test files
```

---

## How to measure coverage

Coverage is **not** collected by default and no threshold is enforced.

### Backend

`node:test` has built-in coverage (experimental in Node 22/24). From the Backend root, with `@traduce/shared` built:

```bash
TS_NODE_PROJECT=tsconfig.base.json node --require ts-node/register --test \
  --experimental-test-coverage \
  --test-coverage-exclude='**/tests/**' --test-coverage-exclude='**/node_modules/**' --test-coverage-exclude='**/dist/**' \
  $(find tests packages services -name '*.test.ts' -not -path '*/node_modules/*')
```

> Only files loaded by at least one test are counted. Of the 246 `src/**/*.ts` files, 72 are never loaded;
> most of them are type-only (ports, entities, request types) and produce no runtime code. The others are
> configuration, composition roots (`app.ts`, `*.module.ts`) and the LSC-54 dataset scripts in recognition-service.

### Frontend

```bash
npx jest --coverage
```

The report goes to `coverage/` (ignored by git).

### Coverage by area (2026-10-16)

| Workspace | Line coverage | Note |
|---|---|---|
| `packages/shared` | 99.5 % | |
| `api-gateway` | 100 % | |
| `analytics-service` | 95.1 % | |
| `iam-service` | 89.3 % | Lowest: `iam_controller.ts` (~37 %), `mailer.ts` (~43 %) |
| `recognition-service` | 86.0 % | Lowest: recognition `service.ts` (~39 %), `mongo_sample_repository.ts` (~45 %) |
| `lexicon-service` | 83.5 % | Lowest: `category_repository.ts` (~29 %), `lexicon_repository.ts` (~48 %) |
| `profile-service` | 83.5 % | |
| **Backend total** | **88.5 %** | |
| **Frontend total** | **4.5 %** | Screens, navigation and login hooks have no tests |

---

## Targets and gaps

**Target:** NFR-007 (`04-requirements/non-functional.md`) asks for ≥ 80 % line coverage (≥ 90 % in the domain layer).
The backend meets the global target; the frontend does not.

| Gap | Impact | Proposed next step |
|---|---|---|
| CI exists ([ADR-006](../05-architecture/decisions/records/ADR-006-ci-and-static-analysis.md)); no coverage threshold yet | A PR can still lower coverage unnoticed | Add a threshold (see below) |
| Frontend coverage 4.5 % | UI and login regressions are only caught by hand | Cover the login and register hooks, `AuthContext` and the services that call the API |
| Postgres integration suites skipped by default | Concurrency and deletion guarantees are not checked routinely | Disposable Postgres service in CI with `PROFILE_TEST_DATABASE_URL` |
| No contract or performance tests; E2E covers only part of the flows | API drift and breakage of the remaining flows go unnoticed | Extend E2E with the flows listed above |
| No coverage threshold | Coverage can drop without anyone noticing | Add a threshold once CI exists |

**Known defect found while writing frontend tests:** `classifyLetterLSC` (`feature/Translation/services/vision/classifier.ts`)
never returns `L`, because index extended with the other fingers folded matches the `D`/`G` rule first.

---

## Correlations

- TDD process → `11-quality/tdd-guide.md`
- Coverage requirement → `04-requirements/non-functional.md` (NFR-007)
- Definition of Done → `00-governance/definition-of-done.md`
- Technical debt on coverage → `15-project-control/technical-backlog.md` (TD-011)
- How a new developer runs the tests → `14-training/technical-onboarding.md`
- OpenAPI contracts (future contract tests) → `07-api/contracts/openapi/`
