# API Gateway

> Single entry point of Traduce Señas. Receives every request of the mobile / web app under `/api`, checks the JWT when one is sent
> and routes the request to the domain service that owns the path. It owns the routing rules and nothing else.

**Extraction status:** extracted. The gateway is its own process (`services/api-gateway`, own Dockerfile, port 8080). The routing rules are in code (`src/route_table.ts`). See `09-microservices/service-catalog.md`.

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
| Communicates with | iam (3001), recognition (3002), lexicon (3003), analytics (3004), profile (3005) over HTTP (reverse proxy) |
| Consumed by | The mobile / web app and admin tools |
| Events | Does not publish or consume domain events |
| Health | `GET /health` (internal, used by Docker) and `GET /api/health` (public, through Caddy) |

---

## Responsibilities (what this service DOES)

- Route `/api/**` requests to the owner service (table below). Paths are forwarded unchanged, without prefix stripping
- Verify the JWT signature and expiry when the request carries `Authorization: Bearer`. An invalid token answers `401 UNAUTHORIZED` at the edge. Requests without a token are forwarded, and `/api/auth` never checks the token. Each service decides which routes need a session
- Forward the original `Authorization` header untouched. The gateway adds no identity headers: services read `sub`, `roles` and `permissions` from the token themselves
- Rate limit per client IP: 300 requests per minute for every route, and 10 per minute, shared, for the sensitive `/api/auth` paths
- Apply CORS for the app origins
- Aggregate the health of the upstreams on `GET /health` and `GET /api/health`

## Out of scope (what it does NOT do)

- **Business logic and data:** each domain service owns them
- **Issuing tokens:** `iam-service` does it
- **Authorization by role or resource:** each service checks `roles` and `permissions` (for example ADMIN for lexicon writes)
- **Domain events:** the gateway does not touch RabbitMQ

---

## Routing table

Source: `services/api-gateway/src/route_table.ts` (`ROUTE_PREFIXES`).

| Public path prefix (all under `/api`) | Upstream | Token |
|---------------------------------------|----------|-------|
| `/api/auth`, `/api/users`, `/api/iam` | iam-service `:3001` | Not verified on `/api/auth`; verified on the others when sent |
| `/api/translations`, `/api/recognition`, `/api/sign-templates` (deprecated alias), `/api/samples` | recognition-service `:3002` | Verified when sent; the service requires it where needed |
| `/api/lexicon` (including `/api/lexicon/media`) | lexicon-service `:3003` | Verified when sent; writes need ADMIN in the service |
| `/api/analytics` | analytics-service `:3004` | Verified when sent; reports need ADMIN or `stats.read` in the service |
| `/api/profile`, `/api/notifications`, `/api/achievements` | profile-service `:3005` | Verified when sent; the service requires it |

The gateway only decides whether a token is verified. Roles and permissions are checked by the upstream.

Matching is by path segment: `/api/lexicon` matches `/api/lexicon` and `/api/lexicon/...`, but not `/api/lexicons`. A path outside these prefixes answers `404 NOT_FOUND`.

---

## How to run it locally

```bash
# From the project root. Docker Compose builds the gateway and starts the services it depends on
docker compose up -d api-gateway

# Or, without containers, the gateway and the five services with reload
npm run dev:all

# Verify
curl http://localhost:8080/health

# A routed public call
curl http://localhost:8080/api/lexicon/alphabet
```

### Environment variables

| Variable | Purpose |
|----------|---------|
| `PORT` | HTTP port (default `8080`) |
| `IAM_SERVICE_URL`, `RECOGNITION_SERVICE_URL`, `LEXICON_SERVICE_URL`, `ANALYTICS_SERVICE_URL`, `PROFILE_SERVICE_URL` | Upstream base URLs (default `http://localhost:3001` ... `3005`) |
| `JWT_SECRET` | Required. HS256 secret, the same value `iam-service` signs with |
| `CORS_ORIGINS` | Comma separated allowed origins. Empty: development allows the Expo web origins; with `NODE_ENV=production` none |
| `RATE_LIMIT_MAX`, `RATE_LIMIT_WINDOW_MS` | Requests per window on every route (default `300` per `60000` ms) |
| `AUTH_RATE_LIMIT_MAX`, `AUTH_RATE_LIMIT_WINDOW_MS` | Requests per window shared by the sensitive `/api/auth` paths (default `10` per minute) |
| `TRUST_PROXY` | Number of trusted proxies in front of the gateway (`1` behind Caddy). With `0` (default) `X-Forwarded-For` is ignored |
| `HEALTH_TIMEOUT_MS` | Timeout of each upstream check in `/health` (default `2000`) |

---

## Related documents

- [data-model.md](./data-model.md) — Not applicable (stateless)
- [events.md](./events.md) — Not applicable
- [decisions.md](./decisions.md) — Gateway design decisions
- [runbook.md](./runbook.md) — Operation
- Catalog → `../../service-catalog.md`
- API contract → `07-api/contracts/openapi/api-gateway.yaml`
