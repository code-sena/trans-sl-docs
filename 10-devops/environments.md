# Deployment Environments

> Defines the system's environments, their purposes, access, and key configurations.
> **Rule:** If you need to access production directly, something is wrong in the process.
> Most problems should be detected in staging.

---

## Project environments

Traduce Señas runs as a microservices architecture with 5 domain services + API Gateway.

| Environment | Purpose | Update | Access | Data | Gateway URL |
|-------------|---------|--------|--------|------|-------------|
| **local** | Development on dev's machine | Manual (npm run dev:all) | Individual dev | Seed data or empty | http://localhost:8080/api |
| **staging** | Pre-production, testing | (Pending: CI/CD not yet configured) | Team | Test users | (Pending) |
| **production** | Real users (Colombia) | Manual (approval) | Tech Lead + DevOps | Real | https://api.traducsenas.com/api |

---

## Environment variables per environment

> Specific variables go in the environment's secrets system (not chosen yet; options: Vault, AWS Secrets Manager, K8s Secrets).
> Local values go in `.env.example` (without real data).

### Naming convention

```
APP_[SERVICE]_[VARIABLE]

Examples:
  APP_AUTH_JWT_SECRET
  APP_ORDERS_DATABASE_URL
  APP_NOTIFICATIONS_SMTP_HOST
```

### Variables per environment (Traduce Señas microservices)

All services share these base variables; each service also has service-specific DB vars.

| Variable | Local | Staging | Production |
|----------|-------|---------|------------|
| **Gateway (edge)** | | | |
| `API_GATEWAY_PORT` | `8080` | `8080` | `80/443` |
| **IAM Service** | | | |
| `IAM_SERVICE_PORT` | `3001` | `3001` | (internal) |
| `IAM_DB_HOST` | `localhost` | Pending | Pending |
| `IAM_DB_PORT` | `5433` | Pending | Pending |
| `IAM_DB_USER` | `traduce_user` | Pending | Pending |
| `IAM_DB_PASSWORD` | `dev_password` | Pending | Pending |
| `IAM_DB_NAME` | `iam` | `iam` | `iam` |
| **Recognition Service** | | | |
| `RECOGNITION_SERVICE_PORT` | `3002` | `3002` | (internal) |
| `RECOGNITION_DB_HOST` | `localhost` | Pending | Pending |
| `RECOGNITION_DB_PORT` | `5434` | Pending | Pending |
| `MONGODB_URI` | `mongodb://localhost:27017/gesture_samples` | Pending | Pending |
| **Lexicon Service** | | | |
| `LEXICON_SERVICE_PORT` | `3003` | `3003` | (internal) |
| `LEXICON_DB_HOST` | `localhost` | Pending | Pending |
| `LEXICON_DB_PORT` | `5435` | Pending | Pending |
| `LEXICON_MEDIA_DIR` | `./public/lexicon` | Cloud storage | Cloud storage (S3/GCS) |
| `LEXICON_MEDIA_BASE_URL` | (localhost serves directly) | CDN URL | CDN URL |
| **Analytics Service** | | | |
| `ANALYTICS_SERVICE_PORT` | `3004` | `3004` | (internal) |
| `ANALYTICS_DB_HOST` | `localhost` | Pending | Pending |
| `ANALYTICS_DB_PORT` | `5436` | Pending | Pending |
| **Profile Service** | | | |
| `PROFILE_SERVICE_PORT` | `3005` | `3005` | (internal) |
| `PROFILE_DB_HOST` | `localhost` | Pending | Pending |
| `PROFILE_DB_PORT` | `5437` | Pending | Pending |
| **Cross-service** | | | |
| `JWT_SECRET` | Generated locally | Pending | Pending |
| `RABBITMQ_URL` | `amqp://guest:guest@localhost:5672` | Pending | Pending |
| `EMAIL_USER` | (optional for local) | Pending | Pending |
| `EMAIL_PASS` | (optional for local) | Pending | Pending |

---

## CI/CD Pipeline

> **STATUS:** Pending. CI/CD automation is not yet configured for Traduce Señas.
> The following describes the intended pipeline to implement.

**Current process:** Developers push to `dev` or `main` and deploy manually.

**Planned automated pipeline (GitHub Actions):**

```
Developer
  │
  │ git push feature/HU-XXX
  │
  ▼
┌─────────────────────────────────────────────────────────┐
│  PR VALIDATION (on every PR to dev or main)             │
│  ─────────────────────────────────────────────          │
│  1. Lint (ESLint) backend + frontend                    │
│  2. Format check (Prettier)                             │
│  3. Build backend (npm run build)                       │
│  4. Build frontend (pending: Expo build config)         │
│  5. Unit tests backend (npm test)                        │
│  ─────────────────────────────────────────────          │
│  If it fails: blocks the PR merge                       │
└─────────────────────────────────────────────────────────┘
  │
  │ PR approved and merged to `dev`
  │
  ▼
┌─────────────────────────────────────────────────────────┐
│  MERGE TO DEV (future automation)                       │
│  ─────────────────────────────────────────────          │
│  1. All PR validations (above)                          │
│  2. Build Docker image (backend)                        │
│  3. (Future) Deploy to dev environment                  │
│  4. (Future) Run smoke tests                            │
└─────────────────────────────────────────────────────────┘
  │
  │ Release: merge dev → main (when ready)
  │
  ▼
┌─────────────────────────────────────────────────────────┐
│  PRODUCTION RELEASE (manual, needs approval)            │
│  ─────────────────────────────────────────────          │
│  1. All tests pass                                      │
│  2. Tech Lead approval required                         │
│  3. Manual deploy to production                         │
│  4. Verify health endpoint                              │
└─────────────────────────────────────────────────────────┘
```

---

## Production deploy strategy

### Current deployment (Manual, no orchestration yet)

**Adopted strategy:** Manual deployment with verification.

The Traduce Señas microservices (Express + Node.js) are deployed as containers:
- **Server:** Cloud provider (pending: details to be documented)
- **Process manager per service:** (pending: PM2, systemd, or container orchestration)
- **Reverse proxy (API Gateway):** nginx routes `/api/*` to the appropriate service (port 8080 public → 3001–3005 internal)
- **Message broker:** RabbitMQ for asynchronous domain events
- **Databases:** 5 PostgreSQL instances (per service) + MongoDB (gesture samples)

### Production deploy checklist

- [ ] Code is on the `main` branch and has been reviewed + approved
- [ ] All tests pass
- [ ] Database migrations are applied (Liquibase runs automatically on app startup)
- [ ] Tech Lead gives final approval
- [ ] Someone is available to monitor the first 30 minutes post-deploy
- [ ] Backup of the current version is available
- [ ] Frontend API URLs point to `https://api.traducsenas.com/api` (check config)

### Rollback

```bash
# Manual rollback procedure (pending: automate with scripts)

# 1. Check current deployed version
curl https://api.traducsenas.com/api/auth/register -i

# 2. If needed, redeploy previous version
# (Exact steps depend on deployment infrastructure — document when infrastructure is finalized)

# 3. Verify health
curl https://api.traducsenas.com/api/auth/register

# 4. If database migration caused issues (EMERGENCY)
# Consult with Tech Lead before reverting migrations
```

**TODO:** Document exact production deploy steps (SSH, Docker push, restart service, etc.) once infrastructure is finalized.

---

## Deploy log

> Log all production deployments here for audit and debugging.

| Date | Service | Version | Environment | Deployed by | Issues |
|------|---------|---------|-------------|-------------|--------|
| (pending) | traduce-backend | (TBD) | production | (TBD) | N/A |
| (pending) | traduce-frontend | (TBD) | production | (TBD) | N/A |

---

## Correlations

- Local setup → `10-devops/local-setup.md`
- Post-deploy observability → `13-operations/observability.md`
- Runbook per service → `09-microservices/services/XX/runbook.md`
- Branch policy → `00-governance/git-conventions.md`
