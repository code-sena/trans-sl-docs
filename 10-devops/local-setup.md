# Local Project Setup

> Goal: any developer has the backend running locally in less than 1 hour.
> **Rule:** if you have to guess something or look elsewhere, add what is missing here.

**Based on:** Backend `v1.4.0` (`package.json`, `docker-compose.yml`, `.env.example`, `scripts/run-tests.js`, `services/api-gateway/src/health.ts`). Frontend `v1.3.1` (`package.json`, `src/app/config/api.config.ts`, `nginx.conf`).
**Last updated:** 2026-11-04. For a guided first week (reading order, Git flow, FAQ) see [14-training/technical-onboarding.md](../14-training/technical-onboarding.md).

---

## Prerequisites

| Tool | Minimum version | Verify with |
|------|----------------|-------------|
| Docker with Compose | Docker 24+, Compose 2.20+ | `docker --version`, `docker compose version` |
| Git | 2.40+ | `git --version` |
| Node.js | 20.x LTS (the Dockerfiles use `node:20-alpine`) | `node --version` |
| npm | 10.x | `npm --version` |

Optional: the Expo Go app on a phone, Postman or Insomnia.

The Backend is an npm workspaces monorepo (`packages/shared`, `services/*`). The branch to work from is `develop`.

---

## 1. Start the whole backend with Docker

```bash
cd Backend
git checkout develop
cp .env.example .env      # then edit .env (see below). Never commit .env
docker compose up --build
```

### Required variables in `.env`

Docker Compose stops with an error if any of these four is empty:

| Variable | What to put | Notes |
|----------|-------------|-------|
| `JWT_SECRET` | A random string of **32 characters or more** | The same secret is used by all services. Generate one: `openssl rand -hex 32` |
| `POSTGRES_PASSWORD` | A password you choose | Used by the five PostgreSQL containers (user `postgres`) |
| `MONGO_ROOT_PASSWORD` | A password you choose | MongoDB root user (default name `signa`) |
| `RABBITMQ_PASSWORD` | A password you choose | RabbitMQ user (default name `signa`) |

Use your own values; never reuse a real password from another system and never put real values in a file that is committed.

Optional variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `MONGO_ROOT_USER`, `RABBITMQ_USER` | `signa` | Names of the MongoDB and RabbitMQ users |
| `CORS_ORIGINS` | `http://localhost:8081,http://localhost:19006` | Web origins allowed to call the gateway (Expo web). Comma separated. The container runs in production mode: an empty value would allow none |
| `EMAIL_USER`, `EMAIL_PASS` | empty | Gmail account that sends the verification and password-reset codes. Without them registration works but the code is not emailed (`verification_email_sent: false`) |

The other variables in `.env.example` (ports, `*_DB_*`, rate limits, `LEXICON_MEDIA_*`) are only used when you run the services without Docker.

### Check that it works

Locally, only the gateway is published to the network (in production nothing but Caddy is, on ports 80 and 443):

```bash
curl http://localhost:8080/health
```

Expected answer when every service is up (HTTP 200). The same answer is served at `http://localhost:8080/api/health`:

```json
{"status":"ok","version":"1.4.0","services":{"iam":{"status":"up"},"recognition":{"status":"up"},"lexicon":{"status":"up"},"analytics":{"status":"up"},"profile":{"status":"up"}}}
```

If one service is down the gateway still answers 200, with `"status":"degraded"` and `"down"` for that service. The first start can show `degraded` for a few seconds while the databases and RabbitMQ become healthy; repeat the command.

A quick functional check (the gateway forwards to iam-service; the body is validated before any email is sent):

```bash
curl -i -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" -d '{}'
# 400 {"success":false,"code":"INVALID_BODY",...}  -> the request reached iam-service
```

To stop: `docker compose down`. Add `-v` to delete the data volumes (needed to re-run the SQL, see "Database schema").

---

## 2. Ports

| Port | Component | Published to the host? |
|------|-----------|------------------------|
| 8080 | api-gateway | Yes, to the whole network (the only public entry point of the local stack) |
| 3001 | iam-service | No, only inside the Docker network |
| 3002 | recognition-service | No |
| 3003 | lexicon-service | No |
| 3004 | analytics-service | No |
| 3005 | profile-service | No |
| 5433 / 5434 / 5435 / 5436 / 5437 | PostgreSQL of iam / recognition / lexicon / analytics / profile | Only on `127.0.0.1` |
| 27017 | MongoDB (gesture samples of recognition-service) | Only on `127.0.0.1` |
| 15672 | RabbitMQ management panel (user and password from `.env`) | Only on `127.0.0.1` |
| 5672 | RabbitMQ AMQP | No |
| 8081, 19006 | Expo web (Metro / webpack) | Development server of the Frontend, not part of the Compose |

Because services 3001-3005 are not published, call everything through `http://localhost:8080/api/...`. If port 8080 or any of 5433-5437, 27017 or 15672 is busy, Compose fails to start that container; free the port or stop the other program (`netstat -ano | findstr :8080` on Windows, `lsof -i :8080` on macOS / Linux).

---

## 3. Database schema (SQL files)

Each service owns its database (`iam`, `recognition`, `lexicon`, `analytics`, `profile`). The `.sql` files in `services/<service>/db/` are mounted **by name** in `/docker-entrypoint-initdb.d` of the matching PostgreSQL container in `docker-compose.yml`:

| Container | Files mounted at first start (in order) |
|-----------|-----------------------------------------|
| `postgres-iam` | `000_users.sql`, `003_iam_roles_permissions.sql`, `005_auth_email_normalization_user_tokens.sql`, `006_users_status_email_verification.sql`, `009_outbox_events.sql`, `010_users_password_nullable.sql`, `011_account_deletion_token.sql`, `012_outbox_claim_token.sql`, `013_users_terms_version.sql` |
| `postgres-recognition` | `001_translations.sql`, `002_sign_templates.sql`, `003_erased_users.sql`, `004_sign_templates_word_kind.sql`, `005_translation_retention.sql` |
| `postgres-lexicon` | `003_lexicon.sql` (also seeds the alphabet) |
| `postgres-analytics` | `001_usage_event.sql`, `002_erased_users.sql` |
| `postgres-profile` | `001_profile.sql` (also seeds the achievements), `002_erased_users.sql`, `003_ui_languages.sql`, `004_achievement_catalog.sql`, `005_obtainable_achievements.sql`, `006_translation_milestones.sql`, `007_functional_achievements.sql`, `008_admin_reports.sql`, `009_daily_challenges.sql`, `010_challenge_reward_achievements.sql` |

Two consequences:

- PostgreSQL runs those files **only the first time the data volume is created**. To apply a new or changed file to an existing database, either apply it by hand (see the next subsection) or recreate the volumes with `docker compose down -v`.
- A new `.sql` file does nothing until you add its line to the `volumes` of the right `postgres-*` service in `docker-compose.yml`.

### Applying migrations to an existing volume

The comment at the top of `docker-compose.yml` lists the commands for an existing volume, but it is **incomplete**: it omits `iam-service/db/012_outbox_claim_token.sql` and `profile-service/db/007_functional_achievements.sql`, although both are mounted. The list below is the complete one. Run it with the platform up (`docker compose up -d`), in this order:

```bash
docker compose exec -T postgres-iam       psql -U postgres -d iam       < services/iam-service/db/009_outbox_events.sql
docker compose exec -T postgres-iam       psql -U postgres -d iam       < services/iam-service/db/010_users_password_nullable.sql
docker compose exec -T postgres-iam       psql -U postgres -d iam       < services/iam-service/db/011_account_deletion_token.sql
docker compose exec -T postgres-iam       psql -U postgres -d iam       < services/iam-service/db/012_outbox_claim_token.sql
docker compose exec -T postgres-iam       psql -U postgres -d iam       < services/iam-service/db/013_users_terms_version.sql
docker compose exec -T postgres-analytics psql -U postgres -d analytics < services/analytics-service/db/002_erased_users.sql
docker compose exec -T postgres-profile   psql -U postgres -d profile   < services/profile-service/db/002_erased_users.sql
docker compose exec -T postgres-profile   psql -U postgres -d profile   < services/profile-service/db/003_ui_languages.sql
docker compose exec -T postgres-profile   psql -X -v ON_ERROR_STOP=1 -U postgres -d profile < services/profile-service/db/004_achievement_catalog.sql
docker compose exec -T postgres-profile   psql -X -v ON_ERROR_STOP=1 -U postgres -d profile < services/profile-service/db/005_obtainable_achievements.sql
docker compose exec -T postgres-profile   psql -X -v ON_ERROR_STOP=1 -U postgres -d profile < services/profile-service/db/006_translation_milestones.sql
docker compose exec -T postgres-profile   psql -X -v ON_ERROR_STOP=1 -U postgres -d profile < services/profile-service/db/007_functional_achievements.sql
docker compose exec -T postgres-profile   psql -X -v ON_ERROR_STOP=1 -U postgres -d profile < services/profile-service/db/008_admin_reports.sql
docker compose exec -T postgres-profile   psql -X -v ON_ERROR_STOP=1 -U postgres -d profile < services/profile-service/db/009_daily_challenges.sql
docker compose exec -T postgres-profile   psql -X -v ON_ERROR_STOP=1 -U postgres -d profile < services/profile-service/db/010_challenge_reward_achievements.sql
docker compose exec -T postgres-recognition psql -U postgres -d recognition < services/recognition-service/db/003_erased_users.sql
docker compose exec -T postgres-recognition psql -X -v ON_ERROR_STOP=1 -U postgres -d recognition < services/recognition-service/db/004_sign_templates_word_kind.sql
docker compose exec -T postgres-recognition psql -X -v ON_ERROR_STOP=1 -U postgres -d recognition < services/recognition-service/db/005_translation_retention.sql
```

Notes:

- Only `009_outbox_events.sql` is documented as idempotent (re-running it adds the missing columns). Run the other files once, unless their header says otherwise.
- Use this list only for a volume created before these files existed. A new volume already gets all of them from the initial mount.
- Keep the order shown: the `iam` files depend on the earlier ones, and `iam-service/db/009_outbox_events.sql` must come before `iam.UserDeleted` is published.

### Liquibase files

Some `db/` folders also contain Liquibase files (`master.xml` and `changelogs/`): `analytics-service`, `iam-service`, `lexicon-service` and `recognition-service`. `profile-service` has none. Docker Compose does not run them. The changelogs do not yet reproduce the current schema (see [ADR-008](../05-architecture/decisions/records/ADR-008-database-per-service.md)); the `.sql` files are the ones that build the databases.

---

## 4. Run without Docker (optional)

```bash
cd Backend
npm install
# for each service: copy services/<service>/.env.example to services/<service>/.env and fill it in
npm run dev:all          # gateway + the 5 services with reload
```

You still need the PostgreSQL databases, and you must apply the `.sql` files of each service by hand (nothing creates the tables without Docker). With `RABBITMQ_URL` and `MONGO_URL` empty the services use in-memory events and samples (they are lost on restart; events do not cross processes). To run one service: `npm run dev -w @traduce/iam-service` (workspace names `@traduce/api-gateway`, `@traduce/iam-service`, `@traduce/recognition-service`, `@traduce/lexicon-service`, `@traduce/analytics-service`, `@traduce/profile-service`). All services need the same `JWT_SECRET`.

---

## 5. Tests and build

Run from the Backend root:

```bash
npm install
npm run build      # compiles @traduce/shared and every service with tsc
npm test           # builds @traduce/shared, then runs every *.test.ts with node:test
```

`scripts/run-tests.js` looks for `*.test.ts` under `services/*/tests`, `packages/shared/tests` and `tests/`. CI runs the same build and test on every pull request, so run both commands before opening one. There is no coverage threshold. Details in [testing-strategy.md](../11-quality/testing-strategy.md).

---

## 6. Frontend (React Native + Expo)

In a new terminal:

```bash
cd Frontend
git checkout develop
npm install
npm start            # Expo dev server; or: npm run web / npm run android / npm run ios
npm run typecheck    # tsc --noEmit
npm test             # Jest unit tests (see 11-quality/testing-strategy.md)
npm run e2e          # Playwright end-to-end tests (needs the backend running)
```

There is no `lint` or `build` script in the Frontend. The web bundle is built with `npx expo export --platform web`.

> **Which backend the app uses.** `src/app/config/api.config.ts` points to the deployed API, `https://traducesenas.tech/api`,
> in development too. To work against your local backend, create `.env` in the Frontend root with
> `EXPO_PUBLIC_API_URL=http://localhost:8080/api` (or `http://<your-LAN-IP>:8080/api` for a phone) and restart Expo; the value is
> read at build time. The production web build uses the relative `/api`, and `nginx.conf` only serves the static files: Caddy
> sends `/api` to the gateway.

---

## Common issues

### Compose says a variable is not defined

`docker compose up` fails with `Define JWT_SECRET ...` (or `POSTGRES_PASSWORD`, `MONGO_ROOT_PASSWORD`, `RABBITMQ_PASSWORD`). Copy `.env.example` to `.env` **in the Backend root** and fill in the four variables. `JWT_SECRET` needs at least 32 characters or the services refuse to start.

### Special characters in passwords

The passwords of MongoDB and RabbitMQ are placed inside connection URLs (`MONGO_URL`, `RABBITMQ_URL`). Do not use `@ : / ? #` in `POSTGRES_PASSWORD`, `MONGO_ROOT_PASSWORD` or `RABBITMQ_PASSWORD`: the URL breaks and the service cannot connect (the gateway then reports `down` or `degraded`). Use letters, digits and characters such as `-` or `_`.

### Changed a `.sql` file and nothing happened

PostgreSQL only runs the initialisation files on an empty volume. See "Database schema" above.

### `degraded` in `/health`

Look at the service that says `down`: `docker compose logs <service>` (for example `docker compose logs iam-service`). Typical causes: its database is not healthy yet, a wrong password in `.env` after changing it without recreating the volume (`docker compose down -v`), or RabbitMQ not ready.

### The verification email never arrives

Without `EMAIL_USER` / `EMAIL_PASS` the codes are not sent. The registration response shows `verification_email_sent: false`. Set a Gmail account (an application password, not your normal password) in `.env` and restart `iam-service`.

### The browser blocks the call (CORS)

Add the origin of your web app to `CORS_ORIGINS` and restart the gateway. Native apps do not send `Origin` and do not need it.

### The app cannot reach the backend

By default the Frontend calls the deployed API, not your local gateway. See "Which backend the app uses" in section 6.

### Expo hangs or crashes

```bash
npx expo start -c       # clear the cache
```

---

## Useful local URLs

| What | URL |
|------|-----|
| API entry point | `http://localhost:8080/api` |
| Gateway health | `http://localhost:8080/health` |
| Lexicon media | `http://localhost:8080/api/lexicon/media/alfabeto/glb/A.glb` |
| RabbitMQ panel | `http://localhost:15672` (user and password from your `.env`) |
| Expo web | `http://localhost:8081` |

---

## Correlations

- Environment variables per environment → `10-devops/environments.md`
- Technical onboarding (first day and first week) → [14-training/technical-onboarding.md](../14-training/technical-onboarding.md)
- Service catalog and ports → `09-microservices/service-catalog.md`
- API contracts → `07-api/README.md`
- Production troubleshooting → `09-microservices/services/<service>/runbook.md`
