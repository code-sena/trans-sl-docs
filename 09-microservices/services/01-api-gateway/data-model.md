# Data Model — API Gateway

> The API gateway is **stateless**: it has no database and owns no data. This is deliberate. A gateway with a database
> would become a second owner of some entity and break the rule of one database per service.

---

## Implemented today

No database. The routing table is code: `services/api-gateway/src/route_table.ts` (prefixes per service and the prefixes that skip token verification). Rate-limit counters live in process memory (`express-rate-limit`), so they reset on restart. `GET /health` and `/api/health` call the `/health` of each service on every request and keep nothing.

## Database engine

**Engine:** none.

## What it keeps

| Item | Where | Notes |
|------|-------|-------|
| Routing table | `src/route_table.ts` | Code, versioned in Git. A change ships with a new image |
| Rate-limit counters | In process memory, per gateway instance | Lost on restart; acceptable because the limit is a protection, not a business rule. If the gateway is scaled to several instances the effective limit is multiplied by the number of instances |
| JWT secret | Environment variable `JWT_SECRET` | Not logged by the gateway |

## Schema migration

Not applicable. A routing change is a code change deployed with the image.

## Data it handles in transit

The `Authorization` header and the request body pass through; the body is not parsed and neither is stored. The gateway writes no access log: it logs only upstream errors, without the token or the body.
