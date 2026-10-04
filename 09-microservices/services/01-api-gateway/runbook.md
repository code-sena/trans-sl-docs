# Runbook — API Gateway

> For whoever is on call. Each section is executable without extra context. The gateway is not implemented yet; the
> commands are the target ones and assume the services run with Docker Compose. There is no Kubernetes, dashboard or
> alert channel defined yet.

**Service:** api-gateway
**Version:** 1.0 (target)
**Last updated:** 2026-10-04

---

## 1. Quick information

| Field | Value |
|-------|-------|
| Local port | 8080 |
| Health | `GET http://localhost:8080/health` |
| Upstreams | iam `:3001`, recognition `:3002`, lexicon `:3003`, analytics `:3004`, profile `:3005` |
| State | None. A restart loses only the in-memory rate-limit counters |
| Configuration | `gateway.routes.json` and environment variables (see [README.md](./README.md)) |

---

## 2. Verify the service is healthy

```bash
curl -s http://localhost:8080/health
# Expected: {"status":"ok","upstreams":{"iam":"up","recognition":"up","lexicon":"up","analytics":"up","profile":"up"}}

# Routing works end to end (public route of lexicon)
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/api/lexicon/alphabet   # 200

# JWT validation works (no token on a protected route)
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080/api/translations/history   # 401
```

---

## 3. Frequent problems and what to do

### 502 / 504 on one path prefix only

One upstream is down or slow. The `/health` body says which one.

```bash
docker compose ps
docker compose logs --tail=100 <service>      # for example lexicon-service
docker compose restart <service>
```

If every prefix fails, the problem is the gateway: `docker compose logs --tail=100 api-gateway`.

### 401 on every protected request after a deploy of iam

The signing key changed and the gateway still holds the old verification key.

```bash
# Compare the key in iam and in the gateway environment, then restart the gateway
docker compose up -d --force-recreate api-gateway
```

### 429 Too Many Requests for legitimate users

Several users behind one IP (campus network) hit the per-IP limit on public routes. Raise
`RATE_LIMIT_PUBLIC_PER_MIN` and recreate the container. Do not disable the limit on `/api/auth/**`.

### CORS errors in the browser

The app origin is missing in `CORS_ORIGINS`. Add it and recreate the container.

---

## 4. Maintenance operations

### 4.1 Add or change a route

1. Edit `gateway.routes.json` (prefix, upstream, public flag) in a branch.
2. Run the gateway tests, which assert the routing table.
3. Deploy and run the checks of section 2.

### 4.2 Rotate the JWT verification key

1. Deploy the new key to `iam-service` and to the gateway at the same time (or accept both keys during the transition, if the gateway supports a key list).
2. Tokens signed with the old key fail with `401` until users sign in again or refresh.

### 4.3 Roll back

```bash
docker compose pull api-gateway   # with the previous tag set in the compose file
docker compose up -d api-gateway
```

The gateway is stateless, so a rollback never needs a data restore.

---

## 5. Post-incident checklist

- [ ] `/health` shows every upstream `up`
- [ ] A public and a protected call work through the gateway
- [ ] Incident recorded in `13-operations/incident-management.md`
- [ ] Improvement ticket created in `15-project-control/technical-backlog.md`
