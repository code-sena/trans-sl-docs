# Deployment Environments

> Defines the system's environments, their purposes, access, and key configurations.
> **Rule:** If you need to access production directly, something is wrong in the process.
> Most problems should be detected in staging. Note: the repositories define no staging environment today (see Q-002 in `15-project-control/open-questions.md`).

---

## Project environments

Traduce Señas runs as a backend with an API gateway and 5 domain services, and a client that runs on the web and on Android.

| Environment | Purpose | Update | Access | Data | Gateway URL |
|-------------|---------|--------|--------|------|-------------|
| **local** | Development on the developer's machine | `docker compose up --build` (backend), `npm start` (client) | Individual developer | Local, disposable | `http://localhost:8080/api` |
| **staging** | Not defined | — | — | — | — |
| **production** | Real users | Manual deploy on the server (no deploy workflow, see CI/CD) | Not recorded in the repositories | Real | `https://traducesenas.tech/api` |

The production values come from `docker-compose.prod.yml`, `deploy/Caddyfile` and the client's `src/app/config/api.config.ts`. The state of the live server cannot be checked from the repositories.

---

## Environment variables

> Local values for Docker Compose go in the backend's root `.env` (copied from `.env.example`). Runs without Docker use each service's own `.env`. Real secrets never go in the repositories.

### Naming convention (as the code uses it)

- Shared variables have no prefix: `JWT_SECRET`, `RABBITMQ_URL`, `MONGO_URL`, `EMAIL_USER`.
- Each service reads `<SERVICE>_<NAME>` first and falls back to `<NAME>`. For example, `IAM_DB_HOST` takes precedence over `DB_HOST` (`makeEnvReader` in `packages/shared/src/config/load_config.ts`).
- Under Docker Compose, `docker-compose.yml` gives each service its own `DB_HOST`, `DB_NAME` and so on.

```
JWT_SECRET
IAM_DB_HOST
RECOGNITION_TRANSLATION_RETENTION_DAYS
```

### Variables used by the Docker Compose setup

| Variable | Read by | Default | Notes |
|----------|---------|---------|-------|
| `JWT_SECRET` | gateway and all services | none (required) | At least 32 characters. The same value everywhere |
| `POSTGRES_PASSWORD` | the five PostgreSQL containers and services | none (required) | Do not use `@ : / ? #` |
| `MONGO_ROOT_USER`, `MONGO_ROOT_PASSWORD` | MongoDB, recognition-service | `signa`, none (required) | Compose builds `MONGO_URL` from them |
| `RABBITMQ_USER`, `RABBITMQ_PASSWORD` | RabbitMQ and services | `signa`, none (required) | Compose builds `RABBITMQ_URL` from them |
| `CORS_ORIGINS` | gateway | `http://localhost:8081,http://localhost:19006` | Production: `CORS_ORIGINS_PROD`, default `https://traducesenas.tech` |
| `TRUST_PROXY` | gateway | empty (production sets `1`) | Number of proxies in front of the gateway |
| `EMAIL_USER`, `EMAIL_PASS` | iam-service, profile-service | empty | Gmail account. Without them no code or notice is emailed |
| `GOOGLE_CLIENT_IDS` | iam-service | empty | Empty: `POST /api/auth/google` answers 503 |
| `FACEBOOK_APP_ID`, `FACEBOOK_APP_SECRET` | iam-service | empty | Empty: `POST /api/auth/facebook` answers 503 |
| `RECOGNITION_TRANSLATION_RETENTION_DAYS` | recognition-service | `30` | `0` = translations are not deleted |
| `ADMIN_REPORTS_ENABLED`, `ADMIN_REPORTS_TICK_MS` | profile-service | `true`, `900000` | Administrator summaries |
| `APP_URL` | profile-service | `https://traducesenas.tech` | Target of the button in the notification emails |
| `LEXICON_MEDIA_BASE_URL` | lexicon-service | empty | Production sets `https://${DOMAIN}/api/lexicon/media` |
| `DOMAIN` | Caddy, lexicon-service (production) | `traducesenas.tech` | Production compose file |
| `FRONTEND_DIR` | `web` build (production) | `../frontendTS` | Path of the client repository on the server |

Variables for runs without Docker (ports, `*_DB_HOST`, `*_DB_PORT`, rate limits) are listed in the backend's `.env.example`. The ports are in [local-setup.md](./local-setup.md#2-ports).

---

## CI/CD

> **STATUS:** Continuous integration is in place in both repositories. Deployment is manual. There is no workflow that deploys.

**Continuous integration** (GitHub Actions, file `.github/workflows/ci.yml` in each repository, on pull requests and pushes to `develop` and `main`):

- **Backend:** `npm ci --ignore-scripts`, `npm rebuild bcrypt`, `npm run build`, `npm test`. A disposable PostgreSQL 16 service runs the profile and analytics integration tests.
- **Frontend:** `npm run typecheck`, `npm test -- --ci --coverage`, `npx expo export --platform web`, a Docker build of the web image with a smoke test, and a Playwright E2E job. The E2E job starts the backend with `docker compose` and runs `npm run e2e`. The SonarCloud scan runs when the `SONAR_TOKEN` secret exists.

**Flow today:**

```
push or pull request (develop, main)
  │
  ├─ backend ci.yml: build and tests
  └─ frontend ci.yml: typecheck, Jest, web export, Docker smoke test, Playwright E2E
  │
  │ release: production is built from main
  ▼
manual deploy to the production server (see below)
```

---

## Production deploy strategy

### Current deployment (manual)

- **Server:** one server that runs Docker Compose. The provider is not recorded in the repositories.
- **Containers:** `docker-compose.yml` with `docker-compose.prod.yml` on top. Every container has `restart: unless-stopped`. Logs are capped at 10 MB × 3 files per container.
- **Reverse proxy:** Caddy (`deploy/Caddyfile`) serves HTTPS for `DOMAIN` (default `traducesenas.tech`) with Let's Encrypt. `/api/*` goes to `api-gateway:8080`. Everything else goes to the `web` container (nginx serving the Expo web export). `www.` redirects to the main domain. In production the gateway no longer publishes port 8080; ports 80 and 443 belong to Caddy.
- **Message broker:** RabbitMQ, exchange `traduce.events`, with dead-letter queues.
- **Databases:** five PostgreSQL instances (one per service) and MongoDB.

### Production deploy checklist

- [ ] The code is on `main`, reviewed and approved (team rule, see [git-conventions](../00-governance/git-conventions.md)).
- [ ] CI passed for that commit in both repositories.
- [ ] Database migrations are applied by hand with `psql`, as described in [local-setup.md](./local-setup.md#3-database-schema-sql-files). Nothing in compose, the Dockerfiles or CI runs Liquibase.
- [ ] A backup of the current database and of the running version is available.
- [ ] Someone is available to watch the first 30 minutes after the deploy.
- [ ] `https://traducesenas.tech/api/health` answers with `"status":"ok"`.

The production web build calls the API with a relative `/api` path, because Caddy serves the app and the API on the same domain. The client's default API URL is `https://traducesenas.tech/api`.

### Rollback

```bash
# 1. Check the deployed version (the gateway reports it in "version")
curl -i https://traducesenas.tech/api/health

# 2. If needed, redeploy the previous version
# (Exact steps depend on how the server is set up; document them when the server is finalized)

# 3. Verify health
curl https://traducesenas.tech/api/health

# 4. If a database migration caused issues (EMERGENCY)
# Consult with Tech Lead before reverting migrations
```

**TODO:** Document the exact production deploy steps (SSH, image build, restart of the services) once the server setup is final.

---

## Deploy log

No deployment history is kept in this repository. Releases are versioned with git tags and GitHub Releases (see [git-conventions](../00-governance/git-conventions.md)).

---

## Correlations

- Local setup → `10-devops/local-setup.md`
- Architecture and deployment components → `05-architecture/deployment.md`
- Post-deploy observability → `13-operations/observability.md`
- Runbook per service → `09-microservices/services/<service>/runbook.md`
- Branch policy → `00-governance/git-conventions.md`
