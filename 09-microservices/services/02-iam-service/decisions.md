# Design Decisions — IAM Service

> Decisions specific to this service. Global ones go in `05-architecture/decisions/records/` (see ADR-002 for the JWT).

---

## [DEC-001] iam issues the tokens; the gateway and services only verify

**Date:** 2026-10-04
**Status:** Active (product decision)

**Context:**
Six components need to know the caller. Only one should create identities.

**Decision:**
`iam-service` issues the access token (JWT) and the refresh token. The gateway validates the signature; services read `sub`
and `roles` from the forwarded token. Nobody else signs tokens.

**Alternatives considered:**
- Each service validates against iam on every request: adds a network hop and couples availability.

**Consequences:**
- Advantage: iam can be down briefly without breaking requests that carry a valid token.
- Trade-off: a role change reaches services only when the token is renewed.

---

## [DEC-002] Roles travel in the token, not in a shared table

**Date:** 2026-10-04
**Status:** Active

**Context:**
Today the `lexicon` module checks the `ADMIN` role by reading `user_role` on each admin request (so role changes apply
immediately). With one database per service, lexicon cannot read iam's `authz.user_roles`.

**Decision:**
The access token carries a `roles` claim (array of role names). Access tokens are short-lived (target: 15 minutes), and the
refresh flow re-reads the roles.

**Alternatives considered:**
- Services call `GET /api/roles/...` of iam: restores immediate effect but couples every admin request to iam.
- Replicate `user_roles` into each service by events: more moving parts for six role checks.

**Consequences:**
- Advantage: no cross-service query; services are autonomous.
- Trade-off: a revoked ADMIN keeps the role until the access token expires. Acceptable for the current risk; a block list can be added later.

---

## [DEC-003] Roles and permissions, not an enum

**Date:** 2026-10-04
**Status:** Active (from `06-data/domains/02-authorization.md`)

**Context:**
The LSC linguist needs `samples.validate` without the administrator's other capabilities.

**Decision:**
`roles`, `permissions`, `user_roles`, `role_permissions`. A permission reaches a user only through a role (there is no `user_permissions`).

**Consequences:**
- Advantage: "who can do X" is one query.
- Trade-off: `USER` must be seeded and assigned at registration, or the account authenticates and can do nothing.

---

## [DEC-004] Refresh-token rotation with reuse detection

**Date:** 2026-10-04
**Status:** Proposed (target; today there is no refresh token)

**Context:**
The current 1-day access token cannot be revoked and forces a long window.

**Decision:**
Short access token plus stored refresh token (hash only) in `refresh_tokens`. Each use issues a new one and links
`replaced_by_token_id`. Presenting a replaced token revokes the whole chain.

**Alternatives considered:**
- Long-lived stateless JWT (today): simpler, not revocable.

**Consequences:**
- Advantage: revocation and theft detection.
- Trade-off: a lookup in PostgreSQL per refresh.

---

## [DEC-005] Signing algorithm

**Date:** 2026-10-04
**Status:** Proposed

**Context:**
HS256 (today) means every verifier knows the signing secret.

**Decision:**
Move to RS256: private key only in iam, public key distributed to the gateway and services. Rotation with two keys valid at
the same time. Final choice recorded in ADR-002.

**Consequences:**
- Advantage: only iam can forge tokens.
- Trade-off: key distribution and rotation procedure (see the runbook).

---

## [DEC-006] The audit trail lives in iam and is fed by events

**Date:** 2026-10-04
**Status:** Active

**Context:**
`audit_logs` records changes of entities of every domain. The spec assigns the audit data to iam.

**Decision:**
iam writes `audit_logs` and `error_logs`. Other services publish their change events and iam consumes them. The audit writer
filters out credentials (hashes, tokens, push tokens) before storing values.

**Alternatives considered:**
- Each service keeps its own audit table: no single trail for a compliance request.

**Consequences:**
- Advantage: one place to answer "who changed this".
- Trade-off: the trail is eventually consistent. `error_logs` from other services need an agreed channel (open: not defined in `domain-events.md`).

---

## [DEC-007] Hexagonal modules are kept during the extraction

**Date:** 2026-10-04
**Status:** Active

**Context:**
`auth` and `users` are already hexagonal (`ports/inbound`, `ports/outbound`, `application`, `adapters`).

**Decision:**
The extraction moves both modules into one service without rewriting the use cases. `auth` uses the `UserRepository` port of
`users`; inside iam they are one module, so the port becomes an internal call. Only the adapters change (UUID keys,
outbox publisher, event handlers).

**Consequences:**
- Advantage: low risk; the use-case tests keep running.
- Trade-off: the preferences data in `users` has to be split out to profile.

---

## Correlations

- Global ADRs → `05-architecture/decisions/records/`
- Data model → [data-model.md](./data-model.md)
- Security rules → `00-governance/security-policy.md`
