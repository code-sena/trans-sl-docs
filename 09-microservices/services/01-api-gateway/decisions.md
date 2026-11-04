# Design Decisions — API Gateway

> Decisions specific to the gateway. Global ones go in `05-architecture/decisions/records/`.
> Status `Proposed` means the team has not confirmed it yet.

---

## [DEC-001] The gateway validates the JWT signature; services read the claims

**Date:** 2026-10-04
**Status:** Active (product owner decision, 2026-10-04)

**Context:**
`iam-service` issues the JWT. Every request must be checked before it reaches a service, and every service needs to know
who calls (`sub`) and with which roles.

**Decision:**
When the request carries a token, the gateway validates its signature and expiry and rejects it with `401` at the edge (on `/api/auth` it does not check it). It forwards the original token.
Services decode `sub` and `roles` from the forwarded token. No `X-User-*` headers are invented.

**Alternatives considered:**
- Gateway extracts claims into headers: services would trust headers that anyone reaching a service port could forge.
- Every service validates against `iam-service` on each call: one more network hop per request and iam becomes a bottleneck.

**Consequences:**
- Advantage: a service can still validate the token itself if it is reached directly (defense in depth).
- Trade-off: every service needs the JWT verification key.
- Trade-off: the signature algorithm must be shared knowledge (see DEC-004).

---

## [DEC-002] Rate limiting in process memory

**Date:** 2026-10-04
**Status:** Active (implemented with `express-rate-limit`)

**Context:**
Login and register must be protected against brute force (RNF4). The architecture lists no Redis.

**Decision:**
Fixed-window counters in memory, per client IP: 300 requests per minute on every route, and 10 per minute, shared, on the sensitive `/api/auth` paths. The code counts by IP for every route, not by `sub`. One gateway instance at the beginning.

**Alternatives considered:**
- Redis counters: precise with several instances, but adds a component that is not in the architecture.
- No limit at the gateway: moves the problem to each service.

**Consequences:**
- Advantage: no extra infrastructure.
- Trade-off: with N instances the real limit is N times higher; revisit if the gateway is scaled out.

---

## [DEC-003] Gateway implementation

**Date:** 2026-10-04
**Status:** Active (implemented)

**Context:**
The backend stack is Node.js, Express and TypeScript, and the team already knows it. The routing logic is small
(a path-prefix table).

**Decision:**
A small Express service with a reverse-proxy middleware (`http-proxy-middleware`). Unlike the domain services, its code is not
split into ports and adapters. No Kong or NGINX Plus.

**Alternatives considered:**
- Kong / NGINX: more features than needed and a new configuration language to learn.
- Envoy: designed for service meshes, too heavy for six services.

**Consequences:**
- Advantage: same stack, same tests, same Dockerfile style.
- Trade-off: the team maintains the proxy code. Replacing it with NGINX later only changes the adapter.

---

## [DEC-004] Signature algorithm of the JWT

**Date:** 2026-10-04
**Status:** Proposed

**Context:**
The current backend signs with HS256 and a shared secret (`JWT_SECRET`). With a gateway and six services, sharing a signing
secret widens the number of components that could forge a token.

**Decision:**
Move to RS256: `iam-service` holds the private key, the gateway and the services hold only the public key.
The ADR for this is `05-architecture/decisions/records/ADR-002-jwt-authentication.md`; the final choice is made there.

**Alternatives considered:**
- Keep HS256 with the shared secret: simplest, acceptable in a first extraction, weaker.

**Consequences:**
- Advantage: only iam can issue tokens.
- Trade-off: key distribution and rotation procedure (documented in the iam runbook).

---

## Correlations

- Global ADRs → `05-architecture/decisions/records/`
- Operation → [runbook.md](./runbook.md)
- Token issuer → `../02-iam-service/decisions.md`
