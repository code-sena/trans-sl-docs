# Service Catalog

> The inventory of the backend's deployable pieces and modules, as they exist in the code.
> For the detail of each module go to `09-microservices/services/NN-name/`.

**Last updated:** 2026-10-04 · **Code reviewed:** `backend/cmd/server/main.ts` and `backend/src/domains/*`

---

## Architectural status

**Today the backend is a single deployable: a modular monolith.** One Express process
(`backend/cmd/server/main.ts`, port `3000` by default) mounts one router per domain module and uses
one PostgreSQL database through one connection pool (`src/shared/database/postgres.ts`). There is no API gateway, no
message broker, no Redis and no service-to-service HTTP calls. Modules talk to each other through function calls
(for example `auth` uses the `users` repository port).

The documents disagree on this point:

| Source | What it says |
|--------|--------------|
| `01-context/overview.md`, `01-context/scope.md`, `02-domain/domain-map.md`, `02-domain/domain-events.md`, `06-data/models.md` | Modular monolith in layers; microservices are out of scope; events are in-process |
| `05-architecture/overview.md`, ADR-002 | Hexagonal architecture "designed to allow progressive evolution toward microservices" |
| `09-microservices/` scaffold and `07-api/contracts/openapi/` (`api-gateway.yaml`, `auth-service.yaml`) | Microservice template (gateway, auth-service, Redis, broker) |
| Code | Modular monolith, hexagonal modules |

`01-context/scope.md` records that the ADR for the monolith decision has not been written. **The code and the
domain documents agree on the modular monolith; this catalog follows them.** Hexagonal ports and adapters inside each module
are what keep a future extraction possible.

## Module map

```
  Mobile / Web app (Expo)
          │  HTTPS, REST, Bearer JWT
          ▼
 ┌─────────────────────────────────────────────────────────────┐
 │ Backend API — one Express process (cmd/server/main.ts)      │
 │                                                             │
 │  /api/auth          auth          (public)                  │
 │  /api/users         users         (JWT)                     │
 │  /api/translations  translations  (JWT)                     │
 │  /api/sign-templates ia           (GET public, write JWT)   │
 │  /api/lexicon       lexicon       (GET public, write ADMIN) │
 │                                                             │
 │  shared: config, postgres pool, jwt, auth_middleware,       │
 │          require_role, error_handler                        │
 └──────────────────────────────┬──────────────────────────────┘
                                ▼
                       PostgreSQL (traduce_senas)
```

---

## Module registry

| # | Module | Folder in `09-microservices/services/` | Mount path | Main responsibility | DB | Status |
|---|--------|----------------------------------------|-----------|---------------------|----|--------|
| 01 | `api-gateway` | `01-api-gateway/` | none | Routing, rate limiting (scaffold example) | Redis | Not implemented (template example) |
| 02 | `auth-service` | `02-auth-service/` | none | Scaffold example of an independent auth service | PostgreSQL + Redis | Not implemented (template example) |
| 03 | `lexicon` | `03-lexicon/` | `/api/lexicon` | Catalog of LSC signs, categories, localizations and media | PostgreSQL | Implemented, with unit tests |
| - | `auth` | not documented yet | `/api/auth` | Register, login (JWT), forgot password, verify code, reset password | PostgreSQL | Implemented. Google login use case exists but no route is mounted |
| - | `users` | not documented yet | `/api/users` | `GET /me`. Owns the user repository used by `auth` | PostgreSQL | Implemented (minimal) |
| - | `translations` | not documented yet | `/api/translations` | Save, list (`/history`) and soft-delete a user's translations | PostgreSQL | Implemented |
| - | `ia` | not documented yet | `/api/sign-templates` | Store and serve the sign templates used by the on-device recognizer; import scripts for the LSC54 dataset | PostgreSQL (JSONB) | Implemented. The outbound ports `ai_service` and `gesture_repository` are declared but have no adapter yet |

Bounded contexts of `02-domain/domain-map.md` with **no module in the code yet**: Consent & Personal Data, Profile &
Preferences, Usage Analytics, Notifications, Gamification, and the audit and error log services.

**Statuses:** Implemented (code exists and is mounted in `main.ts`) | Not implemented (documentation example only) | Planned.

---

## Detail per module

### 03 — `lexicon`

| Field | Value |
|-------|-------|
| **Folder** | `09-microservices/services/03-lexicon/` |
| **Responsibility** | Catalog of LSC signs (letters, words, phrases) with categories, texts per interface language and media |
| **Type** | Supporting module |
| **Mount path** | `/api/lexicon` |
| **Technology** | Node.js + Express + TypeScript, hexagonal (`domain`, `ports`, `application`, `adapters`) |
| **DB** | PostgreSQL: `categories`, `sign_lexicon`, `sign_localizations`, `multimedia_resource` |
| **Bounded Context** | `02-domain/domain-map.md` → Learning & Lexicon |
| **Externally exposed** | Reads are public; writes need JWT and the `ADMIN` role |

**Key endpoints:**
- `GET /api/lexicon` — List active signs (filters `type`, `language`, `category`, `q`, `lang`; pagination)
- `GET /api/lexicon/alphabet` — The 27 letters in order
- `GET /api/lexicon/:code` — One active sign with resources and localizations
- `POST /api/lexicon` — Create a sign in `DRAFT` (ADMIN)
- `POST /api/lexicon/:code/publish` — `DRAFT`/`INACTIVE` to `ACTIVE` (ADMIN)

**Events:** none. The module does not emit events; `SignPublished` and `SignWithdrawn` in `02-domain/domain-events.md` are not implemented.

### Other implemented modules

| Module | Key endpoints | Data owned |
|--------|---------------|-----------|
| `auth` | `POST /api/auth/register`, `/login`, `/forgot-password`, `/verify-code`, `/reset-password` | `password_reset_token` |
| `users` | `GET /api/users/me` | `users`. The `role` and `user_role` tables are only read (by `require_role`); no module writes them, roles are assigned with SQL |
| `translations` | `POST /api/translations`, `GET /api/translations/history`, `DELETE /api/translations/:id` | `translations` |
| `ia` | `GET /api/sign-templates` (public), `POST /api/sign-templates` and `DELETE /api/sign-templates/:id` (JWT) | `sign_templates` |

Their folders under `services/` are pending.

---

## Module communication

> Who calls whom. All calls are in-process.

| Source | Destination | Channel | Type | Description |
|--------|-------------|---------|------|-------------|
| Mobile / Web app | Any `/api/*` router | HTTPS + REST | Synchronous | The only external entry point |
| `auth` | `users` (`UserRepository` port) | Function call | Synchronous | Find a user by email, create a user |
| `translations`, `users`, `ia`, `lexicon` | `shared/http/auth_middleware` | Middleware | Synchronous | Verify the JWT and set `req.user` |
| `lexicon` | `shared/http/require_role` | Middleware | Synchronous | Check the `ADMIN` role in `user_role` |

## Data ownership

Every table lives in the same PostgreSQL database; ownership is by module and other modules must go through its ports.

| Entity / Data | Owner module | How other modules access |
|---------------|--------------|--------------------------|
| User | `users` | `UserRepository` port |
| Role assignment (`role`, `user_role`) | None (managed with SQL) | `require_role` reads them through `postgresRoleChecker` |
| Password reset token | `auth` | Not shared |
| Translation | `translations` | Not shared |
| Sign template | `ia` | HTTP `GET /api/sign-templates` (consumed by the app) |
| Sign, category, localization, media | `lexicon` | HTTP `/api/lexicon`; `sign_lexicon.code` is the class the recognizer predicts |

---

## How to add a new module

1. Create `backend/src/domains/<name>/` with `domain/`, `ports/inbound`, `ports/outbound`, `application/`, `adapters/inbound/http` and `adapters/outbound/postgres`
2. Expose a `make<Name>Module(deps)` factory that returns the router (see `lexicon.module.ts`)
3. Mount it in `backend/cmd/server/main.ts` under `/api/<path>`
4. Add the SQL migration in `backend/migrations/`
5. Copy `09-microservices/_template/service` to `09-microservices/services/NN-<name>` and fill it in from the code
6. Add the module to this catalog and, if the architecture changes, record an ADR in `05-architecture/decisions/`

---

## Correlations

- Architecture and patterns → `05-architecture/`
- Domain boundaries → `02-domain/domain-map.md`
- Data model → `06-data/`
- API contracts → `07-api/contracts/openapi/` (only the scaffold gateway and auth-service contracts exist; they do not describe the real API)
- Template for new modules → `09-microservices/_template/service/`
- Detail per module → `09-microservices/services/NN-[name]/`
