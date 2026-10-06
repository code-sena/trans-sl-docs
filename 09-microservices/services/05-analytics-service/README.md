# Analytics Service

> Records how Traduce Señas is used and serves aggregated statistics to the administrator (most visited sections, translations
> per day, usage time). Every report is rebuilt from the usage events it stores.

**Extraction status:** pending. There is no code for this service in the repository yet; this document is the target
based on `02-domain/domain-map.md` (Usage Analytics) and `06-data/domains/08-usage.md`. See `09-microservices/service-catalog.md`.

---

## Responsibility

Owns `usage_events`, `usage_daily_stats` and `session_daily_stats`. It is a **consumer**: it listens to the events of the other
services, stores them as usage facts and computes the rollups. It never calls the other services.

---

## Location in the architecture

| Field | Value |
|-------|-------|
| Number in catalog | 05 |
| Local port | 3004 |
| Bounded context | Usage Analytics |
| DB engine | PostgreSQL, database `analytics` |
| Data owned | `06-data/domains/08-usage` |
| Gateway path | `/api/analytics/**` |
| Communicates with | RabbitMQ (consumes). No synchronous calls to other services |
| Consumed by | The administration panel (through the gateway) |
| Events | Publishes none; consumes events of iam, recognition, lexicon and profile. See [events.md](./events.md) |
| Health | `GET /health` |

---

## Responsibilities (what this service DOES)

- Turn consumed events into `usage_events` rows (section, event type, optional reference), idempotently by `eventId`
- Compute the daily rollups `usage_daily_stats` and `session_daily_stats` (calendar day in America/Bogota)
- Serve statistics to administrators only (permission `stats.read`, INV-012); only aggregated data leaves the service
- Keep the usage facts when an account is deleted (the user reference is detached, `user_id` becomes NULL)

## Out of scope (what it does NOT do)

- **Business decisions:** it only observes. Achievements are computed in `profile-service`
- **Login sessions:** `iam-service` owns `user_sessions`; analytics only keeps their `session_id` as a logical ID
- **Domain events publication:** it publishes none

---

## API (target; no endpoint exists yet)

All routes require a JWT with the `ADMIN` role (`stats.read`). The endpoint-level contract is not defined yet; the planned
groups below follow the RF6 requirement.

| Path | Content |
|------|---------|
| `GET /api/analytics/sections` | Most visited sections for a date range (from `usage_daily_stats`) |
| `GET /api/analytics/translations` | Translations per day |
| `GET /api/analytics/sessions` | Sessions and time of use per day (from `session_daily_stats`) |

Every report that shows `unique_users` must state its grain (the value is not additive, see the data model).
Ingestion of client-side facts that no service emits (section view, audio played) needs an authenticated endpoint
(`POST /api/analytics/events`); it is **proposed**, not agreed.

---

## How to run it locally

```bash
# Target (no image exists yet)
docker compose up -d analytics-service
curl http://localhost:3004/health
```

### Environment variables (target)

| Variable | Purpose |
|----------|---------|
| `PORT` | HTTP port (`3004`) |
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` | PostgreSQL (`DB_NAME=analytics`) |
| `JWT_VERIFY_KEY` | Verification key of the JWT |
| `RABBITMQ_URL` | Broker URL |
| `STATS_TIMEZONE` | Calendar day used by the rollups (default `America/Bogota`) |

---

## Related documents

- [data-model.md](./data-model.md) — Tables
- [events.md](./events.md) — Events consumed and how they map to usage events
- [decisions.md](./decisions.md) — Design decisions
- [runbook.md](./runbook.md) — Operation
- Data model source → `06-data/domains/08-usage.md`
- Event catalog → `02-domain/domain-events.md`
