# ADR-004 — Microservices Architecture

> Based on: Backend `b29a2fa` (`origin/develop`)

- **ID:** ADR-004
- **Date:** 2026-10-05
- **Status:** Accepted
- **Authors:** Juan Mauricio Suaza Solórzano (Tech Lead, proposal); accepted by the development team and the Product Owner on 2026-10-05

---

## Context

Until 2026-09-28 the backend was one Express process organised in domain modules (`auth`, `users`, `translations`, `ia`, `lexicon`) over a single PostgreSQL database. On 2026-09-28 the team agreed to describe it as a "modular monolith". That agreement was **never recorded in an ADR**, so this ADR does not supersede a document; it replaces an oral agreement that still appears as "monolith" or "N layers" in `01-context/overview.md` and `01-context/scope.md`.

On 2026-10-05 the Tech Lead proposed splitting the backend into independent services and the team accepted it. Reasons given:

- The domain already had clear bounded contexts (`02-domain/domain-map.md`) and the modules were already hexagonal, so the split was cheap.
- Each context has a different load and release rhythm (for example the lexicon catalog changes rarely, translations are written constantly).
- A failure in one context (mail delivery, the broker, the sample store) must not take the whole API down.
- The team of four works in parallel; separate services reduce merge conflicts.

**Known constraints:**
- Team of four, no staging environment and no CI yet (see `10-devops/environments.md`).
- The mobile / web client must keep a single public base URL.
- ADR-002 (JWT) and ADR-003 (PostgreSQL + MongoDB without foreign keys between them) are already accepted and must stay valid.

---

## Decision

**We decided:** the backend is a set of independent services behind one API gateway, one database per service, and domain events over RabbitMQ for service-to-service communication. Each service is internally hexagonal (domain, application, ports, adapters).

What exists in `Backend@origin/develop` (`b29a2fa`), as an npm workspaces monorepo (`package.json`: `packages/*`, `services/*`):

| Component | Port | Owns | Public prefixes (`services/api-gateway/src/route_table.ts`) |
|-----------|------|------|-----------------------------------------------------------|
| `api-gateway` | 8080 (only port published to the host) | nothing | routes, CORS, rate limit, optional JWT check, `GET /health` |
| `iam-service` | 3001 | PostgreSQL `iam` | `/api/auth`, `/api/users`, `/api/iam` |
| `recognition-service` | 3002 | PostgreSQL `recognition` + MongoDB `gesture_samples` | `/api/translations`, `/api/recognition`, `/api/sign-templates`, `/api/samples` |
| `lexicon-service` | 3003 | PostgreSQL `lexicon` + static media | `/api/lexicon` |
| `analytics-service` | 3004 | PostgreSQL `analytics` | `/api/analytics` |
| `profile-service` | 3005 | PostgreSQL `profile` | `/api/profile`, `/api/notifications`, `/api/achievements` |

Shared code lives in `packages/shared` (`@traduce/shared`): configuration loader, PostgreSQL pool, JWT provider, auth / role / permission middleware, error handler and the event bus.

**Justification:**
- **Gateway.** The client talks to one URL. The gateway forwards paths unchanged and, when a `Bearer` token is present, rejects an invalid one with `401` before reaching a service. Each service still verifies the token and decides which routes need a session. The only public prefix is `/api/auth`.
- **Database per service.** No service reads another service's tables. A reference to data of another service is a logical id (for example `user_id`) with no foreign key. This extends ADR-003, which separated PostgreSQL from MongoDB: the rule "no foreign keys between stores" now also holds between services. In the code, MongoDB is used only by `recognition-service` (`gesture_samples`); when `MONGO_URL` is empty the samples are kept in memory.
- **Events over RabbitMQ.** Topic exchange `traduce.events`, routing key `<service>.<Event>`. Events implemented today: `iam.UserRegistered` (consumed by `profile-service` and `analytics-service`), `recognition.TranslationProduced` (consumed by `profile-service` and `analytics-service`), `lexicon.SignPublished` and `lexicon.SignWithdrawn` (consumed by `recognition-service`, which only logs them for now), `profile.AchievementUnlocked` and `profile.PreferencesChanged` (published, no consumer). When `RABBITMQ_URL` is empty the services use an in-memory bus. Consumers are idempotent by `eventId`.
- **Authentication (complements ADR-002).** `iam-service` signs the JWT (HS256, issuer `traduce-iam`, audience `traduce-api`, claims `sub`, `email`, `roles`, `permissions`). All services share `JWT_SECRET` (minimum 32 characters) and verify the token locally; roles and permissions travel in the token, so no service queries the `iam` database to authorise a request.
- **Internal style: hexagonal per service.** Every service has `domain`, `application`, `ports` and `adapters` (inbound HTTP / events, outbound PostgreSQL / MongoDB / mailer). This settles the open question "N layers vs hexagonal": hexagonal is the style (`05-architecture/hexagonal-architecture.md`). The "N layers" wording in `01-context/overview.md` and `01-context/scope.md` is outdated documentation debt, not a competing decision.

---

## Evaluated alternatives

| Alternative | Pros | Cons | Reason for discarding |
|------------|------|------|-----------------------|
| Gateway + 5 services, one database each, RabbitMQ events (chosen) | Independent deploys and failures, clear ownership, parallel work | More moving parts (13 containers in `docker-compose.yml`), eventual consistency, no cross-service transactions | — (chosen) |
| Modular monolith (the 2026-09-28 agreement) | One process, one database, simple local setup and transactions | One release unit, one failure domain, modules share tables and call each other directly | Replaced by the team's decision of 2026-10-05 |
| Microservices with a shared database | Fewer databases, foreign keys across contexts | Services coupled through the schema; defeats independent evolution | Breaks the "database per service" rule |
| Synchronous REST between services only (no broker) | No broker to operate | Chains of calls, cascading failures, temporal coupling | Events fit the cases that exist (profile and analytics react to what others did) |

---

## Consequences

**Positive:**
- A service can fail or be redeployed without stopping the others; `GET /health` of the gateway reports the state of each (`ok` / `degraded`).
- Each context owns its schema (`services/*/db/*.sql`) and its tests (`services/*/tests`, `packages/shared/tests`).
- The client keeps a single base URL (`http://localhost:8080` in local setup).

**Negative / Trade-offs:**
- More infrastructure to run and document: five PostgreSQL instances, MongoDB and RabbitMQ.
- Consistency between services is eventual. Known gap: account deletion in `iam-service` publishes no event, and its SQL (`account_repository.ts`, `erase`) still touches tables of other services (`translations`, `usage_events`) that are not in the `iam` database (analytics owns `usage_event`, singular, in its own database); `lexicon-service` (`created_by` / `updated_by`) and the other services would keep the old `user_id`. Marked as debt in `services/iam-service/src/users/application/delete_account.ts`; fix in progress.
- Cross-cutting concerns (JWT secret, error format `{success, code, message}`, event contracts in `packages/shared/src/events/contracts.ts`) must be kept consistent by hand.
- The documents that still describe the monolith or the old single `traduce_senas` database (`01-context/`, parts of `06-data/`) are out of date.

**Impact on the system:**
- Affected services: all of them (gateway, iam, recognition, lexicon, analytics, profile).
- Documents updated by this change: `09-microservices/service-catalog.md`, `07-api/contracts/openapi/*.yaml`, `10-devops/local-setup.md`, `05-architecture/decisions/README.md`.
- Documents still to update (pending): `01-context/overview.md`, `01-context/scope.md`, `06-data/` (per-service data model).

---

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Account deletion leaves orphan `user_id` references in other services | High | Medium | Publish a `UserDeleted` event and consume it in the other services. Done after this ADR: `iam.UserDeleted` through an outbox, consumed by profile, recognition and analytics (Backend `2993301`) |
| A leaked `JWT_SECRET` lets anyone forge tokens for every service (symmetric HS256) | Low | High | Secret only in `.env` (never committed), minimum 32 characters; evaluate asymmetric keys (RS256, as `00-governance/security-rules.md` asks for production) |
| Event lost or duplicated by the broker | Medium | Medium | Consumers are idempotent by `eventId`; `subscribeWithRetry` and dead-letter exchange `traduce.events.dead` |
| Running everything locally is heavy for a four-person team | Medium | Low | One command (`docker compose up --build`); see `10-devops/local-setup.md` |

---

## References

- `Backend@origin/develop`: `docker-compose.yml`, `MICROSERVICES_PLAN.md`, `services/api-gateway/src/route_table.ts`, `packages/shared/src/events/contracts.ts`, `packages/shared/src/security/jwt_token_provider.ts`
- `09-microservices/service-catalog.md`
- `05-architecture/hexagonal-architecture.md`
- Related to: ADR-002 (JWT authentication, complemented), ADR-003 (database separation, extended to one database per service)
