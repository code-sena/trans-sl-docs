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

One OpenAPI 3.0.3 file per service. All of them reuse `_shared.yaml` (pagination, `ErrorResponse`,
reusable parameters/responses and the `bearerAuth` security scheme) through `$ref`.

| Contract | Service | Local port | Public paths (under `/api`) | Endpoints* | Code status |
|----------|---------|-----------|-----------------------------|------------|-------------|
| [`api-gateway.yaml`](contracts/openapi/api-gateway.yaml) | api-gateway | 8080 | routing table and `GET /health` | 1 | edge component |
| [`iam-service.yaml`](contracts/openapi/iam-service.yaml) | iam-service | 3001 | `/auth/**`, `/users/**`, `/roles/**`, `/consents/**` | 25 | extraction in progress (auth and users exist) |
| [`recognition-service.yaml`](contracts/openapi/recognition-service.yaml) | recognition-service | 3002 | `/translations/**`, `/recognition/**`, `/models/**`, `/samples/**` | 15 | extraction in progress (translations and ia exist) |
| [`lexicon-service.yaml`](contracts/openapi/lexicon-service.yaml) | lexicon-service | 3003 | `/lexicon/**` (including `/lexicon/media/**`) | 19 | extraction in progress (all endpoints exist) |
| [`analytics-service.yaml`](contracts/openapi/analytics-service.yaml) | analytics-service | 3004 | `/analytics/**` | 5 | pending |
| [`profile-service.yaml`](contracts/openapi/profile-service.yaml) | profile-service | 3005 | `/profile/**`, `/notifications/**`, `/achievements/**` | 16 | pending (gamification pending RF8) |

\* Operations per file, `GET /health` included.

Support files: [`_shared.yaml`](contracts/openapi/_shared.yaml) (shared components) and
[`_template-service.yaml`](contracts/openapi/_template-service.yaml) (starting point for a new service).

`auth-service.yaml` is superseded by `iam-service.yaml` and must not be used.

### How to read an operation

- `x-status: implemented` — the route exists in the backend today; the contract was written from the code.
- `x-status: planned` — not in code yet; derived from `04-requirements/user-stories.md` and `06-data`.
- `x-requirements` — the FR-xxx / HU-xxx that justify the operation.
- `x-required-role: ADMIN` — the JWT must carry the ADMIN role (besides being valid).
- `x-current-path` — path used today by the backend when it differs from the target path.

### Conventions common to every contract

- Every service exposes `GET /health` (public).
- Authentication: `Authorization: Bearer <accessToken>`, JWT issued by iam-service and validated by the
  gateway. Services read `sub` and `roles` from the forwarded token.
- Errors: `ErrorResponse` from `_shared.yaml`. The lexicon contract keeps the envelope of the current
  code (`{success, code, message}`) and documents it as `LexiconError`.
- Pagination: `?page=1&limit=20` (shared parameters). Lexicon and translation history still use
  `limit`/`offset`, as in the code.
- Local server in each file points at the service port; the gateway (`http://localhost:8080`) is also
  listed because clients should always go through it.
- No endpoint crosses a service database. References between services are logical ids (for example
  `user_id` issued by iam-service); asynchronous integration uses domain events on RabbitMQ
  (`02-domain/domain-events.md`).

### Validating the contracts

```bash
npx @redocly/cli lint 07-api/contracts/openapi/iam-service.yaml
npx @redocly/cli build-docs 07-api/contracts/openapi/lexicon-service.yaml
```

---

## Open items in the contracts

- Ids: the current code uses integers; the contracts use UUID (`06-data`) except lexicon, which keeps
  the integer ids of the code until its migration.
- Response envelope: the current code answers `{success, message, data}`; the target contracts return
  `ErrorResponse` for errors and plain payloads for the new services.
- Consent endpoints (`/api/consents`) and the model-training endpoints are proposals: no source
  requirement defines them in detail yet.
- Gamification (`/api/achievements`) depends on the approval of RF8.

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
