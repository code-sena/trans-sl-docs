# Data Model — API Gateway

> The API gateway is **stateless**: it has no database and owns no data. This is deliberate. A gateway with a database
> would become a second owner of some entity and break the rule of one database per service.

---

## Database engine

**Engine:** none.

## What it keeps

| Item | Where | Notes |
|------|-------|-------|
| Routing table | Configuration file versioned in Git (`gateway.routes.json`, target) | Same content as the routing table in [README.md](./README.md) |
| Rate-limit counters | In process memory, per gateway instance | Lost on restart; acceptable because the limit is a protection, not a business rule. If the gateway is scaled to several instances the effective limit is multiplied by the number of instances |
| JWT verification key | Environment variable `JWT_VERIFY_KEY` | Never logged |

## Schema migration

Not applicable. A routing change is a configuration change deployed with the gateway.

## Data it handles in transit

The `Authorization` header and the request body pass through; neither is stored. Access logs record method, path,
status, latency, `sub` and correlation id, never the token or the body.
