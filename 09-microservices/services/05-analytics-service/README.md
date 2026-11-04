# Analytics Service

> Records how Traduce Señas is used and serves aggregated statistics to the administrator (translations per day, most
> translated signs, visits per section). Every report is computed from the usage events it stores.

**Extraction status:** extracted. The code lives in `services/analytics-service` (own process, own Dockerfile, port 3004, PostgreSQL database `analytics`).
Rollup tables, sessions and the section report beyond `reports/sections` are planned (see "Target" below). See `09-microservices/service-catalog.md`.

---

## Responsibility

Owns `usage_event` and `erased_users` (PostgreSQL). It is mainly a **consumer**: it listens to the events of the other services,
stores them as usage facts and answers the reports from them. It never calls the other services.

---

## Location in the architecture

| Field | Value |
|-------|-------|
| Number in catalog | 05 |
| Local port | 3004 (internal; not published by Docker Compose) |
| Bounded context | Usage Analytics |
| DB engine | PostgreSQL `analytics`, schema `public` |
| Data owned | See [data-model.md](./data-model.md) |
| Gateway path | `/api/analytics/**` |
| Communicates with | RabbitMQ (consumes). No synchronous calls to other services |
| Consumed by | The administration panel (through the gateway) and the app (`POST /api/analytics/events`) |
| Events | Publishes none; consumes `recognition.TranslationProduced`, `iam.UserRegistered` and `iam.UserDeleted`. See [events.md](./events.md) |
| Health | `GET /health` |

---

## Responsibilities (what this service DOES)

- Turn consumed events into `usage_event` rows, idempotently by `eventId` (a second copy is ignored)
- Accept a usage event sent by a logged-in client (`POST /api/analytics/events`, answers `202`). The user id always comes from the token. `USER_REGISTERED` and `referenceType: USER` are refused
- Answer the administrator reports for a date range: totals (`GET /summary`), most translated signs (`GET /top-signs`), translations and new users per day (`GET /daily`) and visits per section (`GET /reports/sections`, permission `stats.read`)
- Unlink the user from the usage events when `iam.UserDeleted` arrives (`user_id` becomes NULL, the facts stay) and remember the user in `erased_users`, so later events of that account are stored without the user
- Compute the report days in Colombia time (`America/Bogota`)

## Out of scope (what it does NOT do)

- **Business decisions:** it only observes. Achievements are computed in `profile-service`
- **Login sessions:** `iam-service`. The session events are not in the code
- **Domain events publication:** it publishes none

---

## Routes (implemented)

Every route needs a valid JWT. The full contract with the errors is in `07-api/contracts/openapi/analytics-service.yaml`.

| Method and path | Access |
|-----------------|--------|
| `POST /api/analytics/events` | Any valid JWT (the account must not be erased) |
| `GET /api/analytics/summary`, `/api/analytics/top-signs`, `/api/analytics/daily` | ADMIN role |
| `GET /api/analytics/reports/sections` | Permission `stats.read` |

Reports need `from` and `to` as calendar dates `YYYY-MM-DD` (both included, Colombia time), with `from` not after `to`.

### Target (not in the code)

`GET /api/analytics/sections`, `/sessions`, `/events/summary` and the rollup tables described in the data model. They are listed in `07-api/README.md` ("Planned, not implemented").

---

## How to run it locally

```bash
# With Docker Compose (starts postgres-analytics and rabbitmq first)
docker compose up -d analytics-service

# Locally, only this service (port 3004)
npm run dev -w @traduce/analytics-service
curl http://localhost:3004/health
```

### Environment variables

| Variable | Purpose |
|----------|---------|
| `PORT` | HTTP port (`3004`) |
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` | PostgreSQL connection (`DB_NAME=analytics`; in Compose the host is `postgres-analytics`) |
| `JWT_SECRET` | Verification secret of the JWT (HS256) |
| `RABBITMQ_URL` | Broker URL. Empty means the in-memory bus |

---

## Related documents

- [data-model.md](./data-model.md) — Tables
- [events.md](./events.md) — Events consumed and how they map to usage events
- [decisions.md](./decisions.md) — Design decisions
- [runbook.md](./runbook.md) — Operation
- Target data model → `06-data/domains/08-usage.md`
- API contract → `07-api/contracts/openapi/analytics-service.yaml`
- Event catalog → `02-domain/domain-events.md`
