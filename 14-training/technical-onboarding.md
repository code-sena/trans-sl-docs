# Technical Onboarding

> **Version:** 1.0 · **Date:** 2026-10-12
> **Based on:** Docs `cc30cd7` · Backend `origin/develop` `b29a2fa` · Frontend `origin/develop` `06e7f39`
> **Notation:** `path@branch` means "file `path` on that branch", read with `git show origin/develop:<path>`.
> **Status:** draft written by an agent; human review pending.

Guide for a new developer of Traduce Señas. Goal: on day 1 you have the system running locally and you know
where to read; in the first week you understand the domain and the Git flow.

If something here is wrong or outdated, fix it in a PR: that is a valid first contribution.

The backend is a set of **microservices** (one API gateway plus five domain services). There is no monolith.

---

## Day 1 — Setup

### 1. Access to the three repositories

| Repo | Remote | Integration branch |
|------|--------|--------------------|
| Backend | `github.com/mauro-1508/backendTS` | `develop` |
| Frontend | `github.com/tadeo77789/frontendTS` | `develop` |
| Docs | `github.com/code-sena/trans-sl-docs` | `main` (the remote also has a `dev` branch, see [Git flow](#git-flow)) |

Ask the Tech Lead to add you as a collaborator to each one. Clone them side by side.

### 2. Prerequisites

Docker with Compose, Git, Node.js 20 and npm (as stated in [10-devops/local-setup.md](../10-devops/local-setup.md);
Backend `Dockerfile`s use `node:20-alpine`). For the app on a phone: the Expo Go app.

### 3. Start the backend with Docker

Source: `README.md@origin/develop` of Backend.

```bash
cd Backend
git checkout develop
cp .env.example .env     # required: fill in the placeholders, never commit .env
docker compose up --build
```

Required values in `.env` (no default, Compose fails without them): `JWT_SECRET` (32+ characters),
`POSTGRES_PASSWORD`, `MONGO_ROOT_PASSWORD`, `RABBITMQ_PASSWORD`. Avoid `@ : / ? #` in the passwords because they
are placed inside connection URLs. Use your own values; never reuse a real password from another system.
Optional: `MONGO_ROOT_USER`, `RABBITMQ_USER`, `CORS_ORIGINS`, `EMAIL_USER`, `EMAIL_PASS`.
Without `EMAIL_USER` / `EMAIL_PASS` the verification and password-recovery e-mails are not sent.

Check that it is up. Only the gateway is published to the network:

```bash
curl http://localhost:8080/health
```

The gateway answers `{"status":"ok", ...}` with the state of each service, or `"degraded"` if one is down
(`services/api-gateway/src/health.ts@origin/develop`).

To stop: `docker compose down` (add `-v` to delete the data).

Ports published on the host (`README.md@origin/develop`):

| Component | Host port |
|-----------|-----------|
| api-gateway | 8080 (the only one open to the whole network) |
| postgres (iam, recognition, lexicon, analytics, profile) | 127.0.0.1 only: 5433 / 5434 / 5435 / 5436 / 5437 |
| mongo | 127.0.0.1 only: 27017 |
| rabbitmq | management panel on 127.0.0.1:15672; AMQP is not published |
| services 3001-3005 | not published; reachable only inside the Docker network |

### 4. Start the backend without Docker (optional)

```bash
npm install
# copy services/<service>/.env.example to services/<service>/.env and fill it in
npm run dev:all          # gateway + the 5 services with hot reload
```

With `RABBITMQ_URL` and `MONGO_URL` empty the services use in-memory events and samples
(`README.md@origin/develop`). You still need PostgreSQL databases for the services that use them, and **you must apply
by hand the `.sql` files of each service (`services/<service>/db/*.sql`, in numeric order) to its own database**:
without Docker nothing creates the tables (see the migrations FAQ).

### 5. Start the frontend

Scripts that exist in `package.json@origin/develop` of Frontend: `start`, `android`, `ios`, `web`, `typecheck`.

```bash
cd Frontend
git checkout develop
npm install
npm start          # Expo dev server; or: npm run web / npm run android / npm run ios
npm run typecheck  # tsc --noEmit
```

There is no `test`, `lint` or `build` script in the Frontend. The web build used by Docker is
`npx expo export --platform web` (`Dockerfile@origin/develop` of Frontend).

> **Known issue:** the frontend will not reach the gateway out of the box. See [Known issues](#known-issues), item 1.
>
> **Docker build of the frontend:** `nginx.conf@origin/develop` of Frontend proxies `/api/` to `http://backend:3000`
> and `/api/lexicon/` to `http://lexicon:3003`. Those hosts do not exist in the Backend compose (the entry point
> is `api-gateway:8080`), so the image built from that Dockerfile cannot reach the backend as it is.

### 6. Read, in this order

1. [00-sdd-guide.md](../00-sdd-guide.md): how the team works (30 min)
2. [01-context/overview.md](../01-context/overview.md): what we are building (20 min)
3. [02-domain/domain-map.md](../02-domain/domain-map.md): the business domain (30 min)
4. [05-architecture/overview.md](../05-architecture/overview.md): how it is built (30 min)
5. [09-microservices/service-catalog.md](../09-microservices/service-catalog.md): the services (30 min). It describes the target design; it marks some services (api-gateway, analytics, profile) as "No code", although Backend `develop` already contains code for them, so trust the code when they differ
6. [00-governance/git-conventions.md](../00-governance/git-conventions.md): how we manage code (20 min)

Also useful: [01-context/scope.md](../01-context/scope.md) (the MVP is one direction only: sign to text or voice),
[12-ux-ui/navigation-map.md](../12-ux-ui/navigation-map.md) and `MICROSERVICES_PLAN.md@origin/develop` of Backend.

---

## Week 1 — Understand the domain and your service

- Read the folder of the service you will work on in [service catalog (per-service folders)](../09-microservices/service-catalog.md)
  (`README.md`, `data-model.md`, `events.md`, `runbook.md`, `decisions.md`).
- Read its OpenAPI contract (table below).
- Read [06-data/README.md](../06-data/README.md) and [06-data/open-items.md](../06-data/open-items.md).
- Read [04-requirements/traceability-matrix.md](../04-requirements/traceability-matrix.md) to see which requirement your work serves.

### Service map

| Service | Code folder (Backend `develop`) | Public prefixes (`route_table.ts`) | Docs | OpenAPI contract |
|---------|---------------------------------|------------------------------------|------|------------------|
| api-gateway (port 8080) | `services/api-gateway/` | routes everything below | [01-api-gateway](../09-microservices/services/01-api-gateway/README.md) | [api-gateway.yaml](../07-api/contracts/openapi/api-gateway.yaml) |
| iam-service (3001) | `services/iam-service/` | `/api/auth`, `/api/users`, `/api/iam` | [02-iam-service](../09-microservices/services/02-iam-service/README.md) | [iam-service.yaml](../07-api/contracts/openapi/iam-service.yaml) |
| recognition-service (3002) | `services/recognition-service/` | `/api/translations`, `/api/recognition`, `/api/sign-templates`, `/api/samples` | [03-recognition-service](../09-microservices/services/03-recognition-service/README.md) | [recognition-service.yaml](../07-api/contracts/openapi/recognition-service.yaml) |
| lexicon-service (3003) | `services/lexicon-service/` | `/api/lexicon` | [04-lexicon-service](../09-microservices/services/04-lexicon-service/README.md) | [lexicon-service.yaml](../07-api/contracts/openapi/lexicon-service.yaml) |
| analytics-service (3004) | `services/analytics-service/` | `/api/analytics` | [05-analytics-service](../09-microservices/services/05-analytics-service/README.md) | [analytics-service.yaml](../07-api/contracts/openapi/analytics-service.yaml) |
| profile-service (3005) | `services/profile-service/` | `/api/profile`, `/api/notifications`, `/api/achievements` | [06-profile-service](../09-microservices/services/06-profile-service/README.md) | [profile-service.yaml](../07-api/contracts/openapi/profile-service.yaml) |

Shared code: `packages/shared/` (config, JWT, HTTP middleware, event bus, permission names in
`src/security/permissions.ts`). Each service uses hexagonal folders: `domain/`, `application/`, `ports/`,
`adapters/inbound`, `adapters/outbound` (for example `services/analytics-service/src/`).

Frontend code: `src/feature/<Feature>/pages|components|hooks|services`, routes in `src/app/routes/`,
endpoint list in `src/app/config/api.config.ts` (`Frontend@origin/develop`).

---

## Tests and build

Both commands are defined in `package.json@origin/develop` of Backend and run from the Backend root:

```bash
npm run build     # compiles shared and every service (tsc)
npm test          # builds @traduce/shared, then scripts/run-tests.js runs every *.test.ts with node:test
```

`scripts/run-tests.js` looks for `*.test.ts` under `tests/`, `packages/` and `services/`. Tests exist for
`packages/shared` and for `analytics-service` and `api-gateway`, among others; not every service has the same
coverage. **Do not assume a coverage figure**: no coverage report is configured.

Frontend: only `npm run typecheck`.

---

## Git flow

Rules: [00-governance/git-conventions.md](../00-governance/git-conventions.md). Summary of what applies today:

- The **integration branch is `develop`**. Backend and Frontend have it. **`git-conventions.md` and the
  [Definition of Done](../00-governance/definition-of-done.md) still say `dev`**: they are outdated on this point.
  The Docs remote currently only has `dev`; ask the Tech Lead which branch to target for Docs PRs.
- Branches: `feat/<description>`, `fix/<description>`, `chore/<description>`, `hotfix/<description>`, in kebab-case.
  `feat`, `fix` and `chore` branch from `develop`; **`hotfix` branches start from `main`** and are meant for urgent
  fixes directly to `main` (`git-conventions.md`, branch strategy).
- Nobody commits directly to `main` or `develop`. **One task = one branch = one Pull Request.**
- Commits and PRs in **English**, Conventional Commits, short (about 50 characters), for example
  `feat(iam): add resend verification route`. Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `perf`.
- A PR uses the [pull request template](../.github/pull_request_template.md). Update the documents your change affects
  (see [documentation-rules.md](../00-governance/documentation-rules.md)).
- Ask a teammate for review in the PR. There is no CI today, so run `npm run build` and `npm test` yourself
  before opening the PR.

---

## First contribution

1. Agree on a small first task with the Tech Lead; there is no issue-label list.
2. Create your branch from `develop` and make small commits.
3. Run `npm run build` and `npm test` (Backend) or `npm run typecheck` (Frontend).
4. Open the PR and request review.

---

## Frequently asked questions

### How do I add a new endpoint?

1. Update the contract first: [07-api/contracts/openapi/](../07-api/README.md) (the file of the service; shared
   schemas in `_shared.yaml`).
2. In the service (`services/<service>/src/`): add the use case in `application/`, extend the inbound port in
   `ports/inbound/`, then add the controller method and route in `adapters/inbound/http/` (for example
   `routes.ts`). Protect it with the `authMiddleware` that the service receives as a dependency (`deps.authMiddleware`, built
   in `cmd/main.ts` with `makeAuthMiddleware` from `@traduce/shared`) and with `requirePermission(...)` or `requireRole(...)`.
   The ports folder is not identical everywhere: `iam-service` and `recognition-service` use `ports/inbound` and
   `ports/outbound` (inside each domain folder); `profile-service` uses a single `src/ports/repositories.ts` and has no `ports/inbound/`. Follow the
   layout of the service you are changing.
3. Add a `*.test.ts` in the service `tests/` folder.
4. Only if you create a **new URL prefix**, add it in `services/api-gateway/src/route_table.ts`.
5. If the frontend calls it, add it to `ENDPOINTS` in `Frontend@origin/develop:src/app/config/api.config.ts`.
6. Update the service documentation in [service catalog (per-service folders)](../09-microservices/service-catalog.md) if behavior changes.

### How do I add a database migration?

Where migrations really are in Backend `develop`: each service owns its database and keeps two parallel sets in
`services/<service>/db/`:

- numbered SQL files (`000_users.sql`, `003_iam_roles_permissions.sql`, `001_translations.sql`, `003_lexicon.sql`, ...);
- a Liquibase set: `master.xml`, `changelogs/*.xml` and `liquibase.properties.example`. **`profile-service/db/` only has
  `001_profile.sql` and no Liquibase set.**

`docker-compose.yml@origin/develop` mounts **only the `.sql` files, each one by name**, into `/docker-entrypoint-initdb.d`
(for example `./services/iam-service/db/006_users_status_email_verification.sql:/docker-entrypoint-initdb.d/006_...sql:ro`).
A new `.sql` file therefore **does nothing until you add its line to the `volumes` of the right `postgres-*` service in
the compose file**. PostgreSQL runs those files **only when the data volume is created for the first time**. For an
existing database you must apply the new file by hand, for example:

```bash
docker compose exec -T postgres-iam psql -U postgres -d iam < services/iam-service/db/<file>.sql
```

(Compose service names: `postgres-iam`, `postgres-recognition`, `postgres-lexicon`, `postgres-analytics`, `postgres-profile`.)

> **Documentation does not match.** [06-data/migration-strategy.md](../06-data/migration-strategy.md) prescribes
> `node-pg-migrate` with `V001__` / `S001__` files in a single place. The code does not use that. Until the team decides,
> add a numbered `.sql` file **and** the matching Liquibase changelog, keep both consistent, and write the
> deviation in your PR. Data open items: [06-data/open-items.md](../06-data/open-items.md).

### How do I run just one service?

Without Docker (`package.json` of each service defines `dev`):

```bash
cp services/iam-service/.env.example services/iam-service/.env   # fill in the placeholders
npm run dev -w @traduce/iam-service
```

Workspace names: `@traduce/api-gateway`, `@traduce/iam-service`, `@traduce/recognition-service`,
`@traduce/lexicon-service`, `@traduce/analytics-service`, `@traduce/profile-service`.
The service needs its own PostgreSQL database and the same `JWT_SECRET` as the others.

With Docker, name the service (Compose starts its `depends_on` too). Services 3001-3005 are **not published** to the host,
so also start the gateway to reach it: `docker compose up --build api-gateway iam-service` (the gateway `depends_on` `iam-service` and `lexicon-service`, so the lexicon starts too).
Service names in `docker-compose.yml@origin/develop`: `api-gateway`, `iam-service`, `recognition-service`,
`lexicon-service`, `analytics-service`, `profile-service`.

### Who can call what? (permissions)

Roles `USER`, `LINGUIST`, `ADMIN`; permission names in `packages/shared/src/security/permissions.ts`. Roles and
permissions travel inside the JWT. See the [administrator manual](admin-manual.md#2-roles-and-permissions).

### How do I create the first administrator?

There is no route for it. See [admin-manual.md](admin-manual.md#3-creating-the-first-administrator).

---

## Known issues

| # | Issue | Detail |
|---|-------|--------|
| 1 | **Port mismatch: frontend `:3000` vs gateway `:8080`** (see also item 8) | `src/app/config/api.config.ts@origin/develop` (Frontend) sets `API_BASE_URL` in development to `http://localhost:3000/api` (web) or `http://<host>:3000/api` (native), but the gateway listens on `:8080` (`README.md@origin/develop` of Backend: "the frontend must point to the gateway"). Not fixed in code yet; do not edit it as part of onboarding, report it to the Tech Lead. |
| 2 | **`10-devops/local-setup.md` does not match Backend `develop`** | The Backend `README.md` is the reference for starting the system. Check the document against it before trusting a port, variable or command from `local-setup.md`. |
| 3 | **No CI and no staging** | None of the three repos has CI workflows, and there is no staging environment. Quality gates in the Definition of Done that need CI or staging cannot be met today; run the checks locally. |
| 4 | **No ADR for the microservices decision** | Only ADR-001 to ADR-003 exist in [05-architecture/decisions/](../05-architecture/decisions/README.md). The microservices style was accepted on 2026-10-05 without an ADR. |
| 5 | **`dev` vs `develop`** | See [Git flow](#git-flow). |
| 6 | **Migrations duplicated** | SQL files and Liquibase in parallel, and `06-data/migration-strategy.md` describes a third tool. See the FAQ. |
| 7 | **Social login** | The Google button has no action and `/auth/facebook` (called by the frontend) does not exist in the Backend `develop` routes. |
| 8 | **Frontend image does not reach the backend** | `nginx.conf@origin/develop` of Frontend sends `/api/` to `http://backend:3000` and `/api/lexicon/` to `http://lexicon:3003`; neither host exists in the Backend compose (the gateway is `api-gateway:8080`). Together with item 1, the frontend cannot reach the backend out of the box, in development or in the Docker build. |
| 9 | **API contracts out of date** | The OpenAPI files in `07-api` do not reflect `develop`: `iam-service.yaml` lacks `/api/iam/*`, `/api/users/stats`, `/api/auth/verify-email` and `/resend-verification`; `recognition-service.yaml` lacks `/api/translations/stats` and `/me/stats`; `analytics-service.yaml` documents `/api/analytics/sections` while the code serves `/reports/sections`. The code is the source of truth: update the contract when you touch an endpoint. |
| 10 | **Delete account likely fails in Docker** | `account_repository.ts@origin/develop` (iam-service) deletes from `translations` and updates `usage_events` in the `iam` database, where those tables do not exist (code review, not tested). Needs a Backend fix; it matters for the deletion right of Law 1581. |

---

## Correlations

- [10-devops/local-setup.md](../10-devops/local-setup.md), [10-devops/environments.md](../10-devops/environments.md)
- [09-microservices/](../09-microservices/README.md), [07-api/README.md](../07-api/README.md)
- [00-governance/](../00-governance/README.md)
- [README of this folder](README.md)
