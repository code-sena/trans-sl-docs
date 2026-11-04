# Runbook — API Gateway

> For whoever is on call. Each section is executable without extra context. The gateway runs with Docker Compose.
> There is no Kubernetes, dashboard or alert channel defined yet.

**Service:** api-gateway
**Version:** 1.4.0 (backend `main` a962982; the gateway reports the version of the root `package.json`)
**Last updated:** 2026-11-04

---

## 1. Quick information

| Field | Value |
|-------|-------|
| Local port | 8080 (published in development; in production only Caddy publishes 80/443) |
| Health | `GET http://localhost:8080/health` (internal) and `GET /api/health` (through Caddy) |
| Upstreams | iam `:3001`, recognition `:3002`, lexicon `:3003`, analytics `:3004`, profile `:3005` |
| State | None. A restart loses only the in-memory rate-limit counters |
| Configuration | Environment variables (see [README.md](./README.md)). The routing table is in `src/route_table.ts` |

---

## 2. Verify the service is healthy

```bash
curl -s http://localhost:8080/health
# Expected (HTTP 200 even when a service is down; read the body):
# {"status":"ok","version":"1.4.0","services":{"iam":{"status":"up"},"recognition":{"status":"up"},"lexicon":{"status":"up"},"analytics":{"status":"up"},"profile":{"status":"up"}}}

# Routing works end to end (public route of lexicon)
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/api/lexicon/alphabet   # 200

# Token check works (an invalid token is refused at the edge)
curl -s -H "Authorization: Bearer invalid" http://localhost:8080/api/translations/history   # 401 UNAUTHORIZED
```

---

## 3. Frequent problems and what to do

### 502 on one path prefix only

One upstream does not answer. The gateway returns `502 BAD_GATEWAY` and the `/health` body says which service is `down`.

```bash
docker compose ps
docker compose logs --tail=100 <service>      # for example lexicon-service
docker compose restart <service>
```

If every prefix fails, the problem is the gateway: `docker compose logs --tail=100 api-gateway`.

### 401 on every request that carries a token, after a change of secret

`JWT_SECRET` differs between `iam-service` and the gateway (both must sign and verify with the same value).

```bash
# Check that JWT_SECRET is the same in the environment of iam-service and api-gateway, then recreate the gateway
docker compose up -d --force-recreate api-gateway
```

### 429 Too Many Requests for legitimate users

Several users behind one IP (campus network) hit the per-IP limit. Raise `RATE_LIMIT_MAX` and recreate the container.
If every user shares one IP behind Caddy, check that `TRUST_PROXY=1` is set in production. Do not disable the limit on `/api/auth/**`; change `AUTH_RATE_LIMIT_MAX` only with care.

### CORS errors in the browser

The app origin is missing in `CORS_ORIGINS`. Add it and recreate the container.

---

## 4. Maintenance operations

### 4.1 Add or change a route

1. Edit `services/api-gateway/src/route_table.ts` (`ROUTE_PREFIXES`) in a branch.
2. Run the gateway tests in `services/api-gateway/tests`, which cover the routing.
3. Deploy with `docker compose up -d --build api-gateway` and run the checks of section 2.

### 4.2 Rotate the JWT secret

`JWT_SECRET` is one shared HS256 secret, and the gateway holds no key list.

1. Change `JWT_SECRET` at the same time in `iam-service`, `api-gateway` and the other services that verify tokens.
2. Recreate them: `docker compose up -d --force-recreate`.
3. Tokens signed with the old secret answer `401 UNAUTHORIZED` until users sign in again.

### 4.3 Roll back

The gateway is stateless, so a rollback never needs a data restore. Check out the previous commit and rebuild:

```bash
git checkout <previous-commit>
docker compose up -d --build api-gateway
```

---

## 5. Post-incident checklist

- [ ] `/health` shows every upstream `up`
- [ ] A public and a protected call work through the gateway
- [ ] Incident recorded in `13-operations/incident-management.md`
- [ ] Improvement ticket created in `15-project-control/technical-backlog.md`
