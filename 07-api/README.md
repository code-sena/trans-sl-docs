# 07 — API Contracts

> **What is this?** The formal specification of how the microservices communicate with their clients
> through the api-gateway. The contract is the promise a service makes to its consumers.

## Why contracts are critical in microservices

Each service is deployed on its own. A change to an API can silently break another service or the
mobile app in production, and the compiler cannot warn you across service boundaries.

**Contract-first development:** design the API before implementing it, so frontend, backend and other
services can work in parallel against an agreed contract.

---

## Contract index (`contracts/openapi/`)

> **Based on:** Backend `2993301` (`origin/develop`, 2026-10-16). Each contract lists only routes that exist in the code; every path and method was compared with the `routes.ts` files of each service.

One OpenAPI 3.0.3 file per component. They reuse `_shared.yaml` (`ApiError`, `Timestamp`, pagination and the `bearerAuth` security scheme) through `$ref`.

| Contract | Service | Internal port | Public paths (under `/api`) | Operations* |
|----------|---------|---------------|-----------------------------|-------------|
| [`api-gateway.yaml`](contracts/openapi/api-gateway.yaml) | api-gateway | 8080 (published) | routing table and `GET /health` | 1 |
| [`iam-service.yaml`](contracts/openapi/iam-service.yaml) | iam-service | 3001 | `/auth/**`, `/users/**`, `/iam/**` | 17 |
| [`recognition-service.yaml`](contracts/openapi/recognition-service.yaml) | recognition-service | 3002 | `/translations/**`, `/recognition/sign-templates/**` (alias `/sign-templates/**`, deprecated), `/samples/**` | 14 |
| [`lexicon-service.yaml`](contracts/openapi/lexicon-service.yaml) | lexicon-service | 3003 | `/lexicon/**` (including `/lexicon/media/**`) | 19 |
| [`analytics-service.yaml`](contracts/openapi/analytics-service.yaml) | analytics-service | 3004 | `/analytics/**` | 6 |
| [`profile-service.yaml`](contracts/openapi/profile-service.yaml) | profile-service | 3005 | `/profile/**`, `/notifications/**`, `/achievements/**` | 8 |

\* Operations per file, `GET /health` included. In the service contracts `/health` is the internal endpoint of the service (not routed by the gateway).

Support files: [`_shared.yaml`](contracts/openapi/_shared.yaml) (shared components) and
[`_template-service.yaml`](contracts/openapi/_template-service.yaml) (starting point for a new service).

### How to read an operation

- `x-requirements` — the FR-xxx / HU-xxx that justify the operation.
- `deprecated: true` — the route still works but must not be used by new code (the `/api/sign-templates` alias).
- The access rule of each operation (public, any valid JWT, a permission such as `stats.read`, or the `ADMIN` role) is written in its description and in the header of the file.

### Conventions common to every contract

- Clients call the gateway only: `http://localhost:8080`. The service ports are internal (Docker Compose does not publish them).
- Authentication: `Authorization: Bearer <token>`, JWT (HS256) issued by iam-service in `POST /api/auth/login` (`data.token`). The gateway rejects an invalid token if one is sent;
  each service decides which routes need a session and checks roles and permissions from the token claims.
- Success envelope: `{ "success": true, "message"?, "data"? }`. profile-service returns plain objects for profile, preferences and notifications (see its contract).
- Errors: `{ "success": false, "code", "message" }` (`ApiError` in `_shared.yaml`). In recognition-service, the create, history and delete routes of `translations` and all `sign-templates` routes carry no `code` in business errors.
- Pagination is not uniform: notifications use `page`/`limit` with `meta`; lexicon and translation history use `limit`/`offset`.
- Ids are integers (`SERIAL`) in iam, recognition and lexicon; profile uses UUIDs for its own records. References between services are logical ids, never foreign keys.
- Asynchronous integration uses domain events on RabbitMQ (`02-domain/domain-events.md`, [ADR-004](../05-architecture/decisions/records/ADR-004-microservices-architecture.md)).

### Validating the contracts

```bash
npx --yes @redocly/cli lint 07-api/contracts/openapi/iam-service.yaml
npx --yes @redocly/cli build-docs 07-api/contracts/openapi/lexicon-service.yaml
```

Expected result: "Your API description is valid", with style warnings only (no license, `localhost` servers).

---

## Planned, not implemented

These routes appeared in earlier drafts of the contracts but **do not exist** in Backend `2993301`. They were removed from the YAML files so that the contracts describe only what the code does. They stay here as proposals, with the requirement that justified each one; none of them is a commitment.

| Service | Route (as drafted) | Purpose | Requirements |
|---------|--------------------|---------|--------------|
| iam | `POST /api/auth/refresh`, `POST /api/auth/logout`, `GET /api/auth/jwks` | Refresh token, logout, public keys (RS256) | FR-011, FR-012, FR-013, HU-IAM-007, HU-IAM-008, ADR-002 |
| iam | `GET /api/users`, `PATCH /api/users/{id}/status` | User administration | FR-015, FR-901, HU-IAM-010 |
| iam | `PUT/DELETE /api/users/{id}/roles/{roleId}`, `GET/POST /api/roles`, `DELETE /api/roles/{id}`, `PUT /api/roles/{id}/permissions`, `GET /api/roles/permissions` | Role administration under `/api/roles`. Implemented today under `/api/iam`: `POST /api/iam/users/{userId}/roles`, `DELETE /api/iam/users/{userId}/roles/{roleName}`, `GET /api/iam/roles`, `DELETE /api/iam/roles/{roleId}`. Creating roles and editing role permissions have no route | FR-101, FR-102, FR-103, HU-AUTHZ-001, HU-AUTHZ-002 |
| iam | `GET/POST /api/consents`, `DELETE /api/consents/{id}` | Consent and personal data (Law 1581 of 2012) | FR-002, FR-603, NFR-005 |
| recognition | `GET /api/models`, `GET /api/models/active`, `POST /api/models/train`, `POST /api/models/{id}/activate` | Model registry and training | FR-604, FR-605, FR-606, HU-AI-003, HU-AI-004, HU-AI-005 |
| recognition | `POST /api/samples/{id}/validate`, `DELETE /api/samples/sessions/{captureSessionId}` | Validate samples, discard a capture session | FR-603, FR-604, HU-AI-001, HU-AI-003 |
| analytics | `GET /api/analytics/sections`, `GET /api/analytics/sessions`, `GET /api/analytics/events/summary` | Drafted reports. The implemented ones are `GET /summary`, `/top-signs`, `/daily` and `/reports/sections` | FR-702, FR-703, FR-704, FR-706, HU-USG-002, HU-USG-003 |
| profile | `POST /api/notifications`, `POST /api/notifications/devices`, `DELETE /api/notifications/devices/{id}`, `GET /api/notifications/types`, `PATCH /api/notifications/types/{id}` | Create / schedule notifications, push devices, notification types | FR-501, FR-503, FR-504, FR-505, FR-509, HU-NOTIF-001, HU-NOTIF-003, HU-NOTIF-004, HU-NOTIF-005 |
| profile | `POST /api/achievements`, `PATCH /api/achievements/{id}` | Administer achievements (RF8 not approved) | FR-801, HU-GAM-001 |

Behaviour that is not in the code either, although it is not a route: refresh tokens, consent records, audit trail, push notifications.

Implemented since the first version of this list: Google and Facebook login (`POST /api/auth/google`, `POST /api/auth/facebook`; FR-008, FR-009, HU-IAM-005) and the `iam.UserDeleted` event.

---

## Open items in the contracts

- Pending (not documented as behaviour): a session version in the token (`401 SESSION_REVOKED`, `503 AUTH_UNAVAILABLE` at the gateway).
- The error format is not uniform inside recognition-service (the errors listed above have no `code`).
- Gamification depends on the approval of RF8.

---

## Correlations with other sections

| This section is fed by... | And feeds into... |
|---------------------------|-------------------|
| `04-requirements/user-stories.md` → what it must do (FR/HU) | Endpoints implementing each requirement |
| `06-data/` → what data exists | Schemas in the contracts |
| `02-domain/domain-events.md` | Events listed in each contract |
| `05-architecture/` → gateway, JWT, hexagonal services | Security and routing rules |
| Contracts here | `09-microservices/services/*` that implement them |
| Contracts here | `11-quality/testing-strategy.md` → contract tests |

---

## Questions this section must answer

- What is each endpoint called and what does it do?
- What data does it receive and what does it return?
- How does the client authenticate and which role does it need?
- What errors can the service return?
- Which service owns the path and on which port does it run?
