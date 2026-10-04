# API Gateway

> Single entry point of Traduce Señas. Receives every request of the mobile / web app under `/api`, validates the JWT
> and routes the request to the domain service that owns the path. It owns the routing rules and nothing else.

**Extraction status:** pending. There is no gateway code yet; today the backend process mounts the routers directly and
`authMiddleware` verifies the JWT in-process. This document is the target. See `09-microservices/service-catalog.md`.

---

## Responsibility

Edge component: routing, JWT signature validation, rate limiting and CORS. It has no bounded context and no data.

---

## Location in the architecture

| Field | Value |
|-------|-------|
| Number in catalog | 01 |
| Local port | 8080 |
| Bounded contexts | None (edge) |
| DB engine | None (stateless) |
| Communicates with | iam (3001), recognition (3002), lexicon (3003), analytics (3004), profile (3005) over HTTP |
| Consumed by | The mobile / web app and admin tools |
| Events | Does not publish or consume domain events |
| Health | `GET /health` |

---

## Responsibilities (what this service DOES)

- Route `/api/**` requests to the owner service (table below)
- Validate the JWT signature and expiry before forwarding. An invalid or missing token on a protected route is answered `401` at the edge
- Forward the original `Authorization: Bearer` header untouched. Services read `sub` and `roles` from the token themselves
- Rate limit per IP on public routes (`/api/auth/**`) and per `sub` on authenticated routes
- Apply CORS for the app origins
- Add and propagate `X-Correlation-Id` for tracing a request across services
- Aggregate the health of the upstreams on `GET /health`

## Out of scope (what it does NOT do)

- **Business logic and data:** each domain service owns them
- **Issuing tokens:** `iam-service` does it
- **Authorization by role or resource:** each service checks `roles` (for example ADMIN for lexicon writes and model training)
- **Domain events:** the gateway does not touch RabbitMQ

---

## Routing table

| Public path (all under `/api`) | Upstream | Public (no JWT) routes |
|--------------------------------|----------|------------------------|
| `/api/auth/**`, `/api/users/**`, `/api/roles/**`, `/api/consents/**` | iam-service `:3001` | `/api/auth/register`, `/login`, `/forgot-password`, `/verify-code`, `/reset-password` |
| `/api/translations/**`, `/api/recognition/**`, `/api/models/**`, `/api/samples/**` | recognition-service `:3002` | `GET /api/recognition/sign-templates` (today `GET /api/sign-templates` is public so the translation screen can download the templates before sign-in) |
| `/api/lexicon/**` (including `/api/lexicon/media/**`) | lexicon-service `:3003` | All `GET`; writes need ADMIN |
| `/api/analytics/**` | analytics-service `:3004` | None (ADMIN reads) |
| `/api/profile/**`, `/api/notifications/**`, `/api/achievements/**` | profile-service `:3005` | None |

The gateway only decides whether a JWT is required (public route list). Whether the caller has the right role is the
decision of the upstream.

The current backend routes that map to these paths: `/api/auth` and `/api/users` (iam), `/api/translations` (recognition),
`/api/sign-templates` (recognition, to be exposed under `/api/recognition`), `/api/lexicon` (lexicon).

---

## How to run it locally

```bash
# Target (no gateway image exists yet). From the project root, once docker-compose.yml defines it:
docker compose up -d api-gateway

# Verify
curl http://localhost:8080/health

# A routed public call
curl http://localhost:8080/api/lexicon/alphabet
```

### Environment variables (target)

| Variable | Purpose |
|----------|---------|
| `PORT` | HTTP port (default `8080`) |
| `IAM_URL`, `RECOGNITION_URL`, `LEXICON_URL`, `ANALYTICS_URL`, `PROFILE_URL` | Upstream base URLs (default `http://localhost:3001` ... `3005`) |
| `JWT_VERIFY_KEY` | Secret (HS256) or public key (RS256) used to validate the signature. The same value `iam-service` signs with |
| `CORS_ORIGINS` | Comma separated allowed origins |
| `RATE_LIMIT_PUBLIC_PER_MIN` | Limit per IP on public routes (default `30`, assumption) |
| `RATE_LIMIT_AUTH_PER_MIN` | Limit per `sub` on protected routes (default `120`, assumption) |

---

## Related documents

- [data-model.md](./data-model.md) — Not applicable (stateless)
- [events.md](./events.md) — Not applicable
- [decisions.md](./decisions.md) — Gateway design decisions
- [runbook.md](./runbook.md) — Operation
- Catalog → `../../service-catalog.md`
- API contract → `07-api/contracts/openapi/api-gateway.yaml` (scaffold, to be realigned to the routing table above)
