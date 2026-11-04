# Lexicon Service

> Catalog of Colombian Sign Language (LSC) signs: letters, words and phrases, with their categories, their text in each
> interface language and their media (3D models, images). The alphabet is not a separate structure: it is the set of signs
> with `type = 'LETTER'`.

**Extraction status:** extracted. The code lives in `services/lexicon-service` (own process, own Dockerfile, port 3003, PostgreSQL database `lexicon`).
It reads the ADMIN role from the `roles` claim of the token; the link with iam's tables was removed (see [decisions.md](./decisions.md), DEC-008). See `09-microservices/service-catalog.md`.

---

## Responsibility

Owns the sign catalog: `categories`, `sign_lexicon`, `sign_localizations` and `multimedia_resource`, and serves the static media.
`sign_lexicon.code` (for example `LETTER_A`, `GREETING_HELLO`) is the class that the recognizer predicts, so the published codes
are the contract between this catalog and `recognition-service`. A published code is never renamed and a sign is never deleted:
it is retired with `status = 'INACTIVE'`.

---

## Location in the architecture

| Field | Value |
|-------|-------|
| Number in catalog | 04 |
| Local port | 3003 (internal; not published by Docker Compose) |
| Gateway path | `/api/lexicon/**`, including `/api/lexicon/media/**` |
| Code | `services/lexicon-service/src/` (`lexicon.module.ts` wires the use cases and the router) |
| DB engine | PostgreSQL, database `lexicon`, schema `public` + static media files (`.glb`, `.png`) |
| Bounded context | Learning & Lexicon (`02-domain/domain-map.md`) |
| Communicates with | RabbitMQ (publishes). Reads `roles` from the forwarded JWT; no synchronous calls to other services |
| Consumed by | The app through the gateway (alphabet screen, catalog search, admin screens); recognition through events |
| Events | Publishes `SignPublished` and `SignWithdrawn`. See [events.md](./events.md) |
| Health | `GET /health` (internal) |
| Status | Extracted, with unit tests (`services/lexicon-service/tests`) |

---

## Responsibilities (what this service DOES)

- Lists and searches active signs with relevance ordering (exact match, then prefix, then contains, also against `code`)
- Serves the 27-letter alphabet in order (Ñ after N)
- Returns `word`, `meaning` and `description` in the requested interface language (`?lang=ES|EN`), falling back to ES and then to any
- Lets an administrator create, edit, publish and retire signs, manage categories, localizations and media
- Serves the alphabet 3D models (`.glb`) and thumbnails from the media directory under `/api/lexicon/media`
- Enforces the catalog rules: unique `code`, one letter per sign language, `letter` only for `LETTER` signs, unique media position per sign, categories with signs cannot be deleted

## Out of scope (what it does NOT do)

- **Authentication and roles:** `iam-service` issues the JWT; the service reads `roles` from it and requires `ADMIN` for writes
- **Recognition:** `recognition-service`. The lexicon only supplies the class names (codes)
- **Translation history:** `recognition-service`
- **Storing binary files in the database:** media are files in the media directory (or a CDN); the database stores only the path or URL
- **Usage statistics:** `analytics-service` (the view and search events are target, not in the code)

---

## How to run it locally

```bash
# With Docker Compose (starts postgres-lexicon and rabbitmq first). The base tables and the alphabet seed come from db/003_lexicon.sql
docker compose up -d lexicon-service

# Locally, only this service (port 3003)
npm run dev -w @traduce/lexicon-service
curl http://localhost:3003/health

# Through the gateway
curl http://localhost:8080/api/lexicon/alphabet
curl "http://localhost:8080/api/lexicon?q=a&lang=ES&limit=5"
```

Granting the ADMIN role is done in iam-service (`user_roles`); the role reaches lexicon in the token, so the user must sign in again. See the runbook of iam-service.

### Environment variables

| Variable | Purpose |
|----------|---------|
| `PORT` | HTTP port (`3003`) |
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` | PostgreSQL connection (`DB_NAME=lexicon`; in Compose the host is `postgres-lexicon`) |
| `JWT_SECRET` | Secret used to verify the token (HS256), shared with the gateway and iam |
| `LEXICON_MEDIA_DIR` | Optional. Directory of the media files (default `<cwd>/public/lexicon`) |
| `LEXICON_MEDIA_BASE_URL` | Optional. Public origin of the media (for example a CDN). It has two effects: the only origin from which absolute `https` resource URLs are accepted on write, and the base of the absolute URLs that the API returns. Without it, relative paths are accepted only and the returned URLs use the host of the request plus `/api/lexicon/media` |
| `RABBITMQ_URL` | Broker URL. Empty means the in-memory bus |

---

## Main endpoints

Base path `/api/lexicon`. "ADMIN" means a valid JWT plus the `ADMIN` role; without the role the answer is `403 FORBIDDEN`.

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/` | Public | Active signs. Filters `type`, `language`, `category`, `q`, `lang`; pagination `limit` (default and max 100), `offset` |
| GET | `/alphabet` | Public | The 27 letters in order |
| GET | `/search?q=` | Public | Same as `/?q=` |
| GET | `/categories` | Public | `[{categoryId, name, description, signCount}]` (counts only `ACTIVE`) |
| GET | `/:code` | Public | One active sign with `resources` and `localizations` |
| GET | `/media/*` | Public | Files from the media directory (cached 7 days) |
| POST | `/categories` | ADMIN | Create `{name, description?}` |
| PATCH | `/categories/:id` | ADMIN | Edit `{name?, description?}` |
| DELETE | `/categories/:id` | ADMIN | Delete; `409 CATEGORY_IN_USE` if it has signs |
| GET | `/admin/signs` | ADMIN | List including `DRAFT` and `INACTIVE`; filter `status` |
| GET | `/admin/signs/:code` | ADMIN | Detail in any status |
| POST | `/` | ADMIN | Create in `DRAFT`: `{code, type?, letter?, category or categoryId, localizations?, word?, description?, animated?, displayOrder?}` |
| PATCH | `/:code` | ADMIN | Edit (never `code` or `status`) |
| POST | `/:code/publish` | ADMIN | `DRAFT`/`INACTIVE` to `ACTIVE`; requires the ES name |
| DELETE | `/:code` | ADMIN | Retire the sign (`status = INACTIVE`) |
| PUT | `/:code/localizations/:lang` | ADMIN | Create or replace the `ES` or `EN` text `{name, meaning?, description?}` |
| POST | `/:code/resources` | ADMIN | Add `{type: MODEL_3D\|IMAGE\|VIDEO\|GIF, url, mimeType?, displayOrder?, description?}`; `409 POSITION_TAKEN` |
| DELETE | `/:code/resources/:resourceId` | ADMIN | Remove a resource |

Example response of `GET /api/lexicon/LETTER_A`:

```json
{
  "success": true,
  "data": {
    "code": "LETTER_A",
    "word": "A",
    "type": "LETTER",
    "letter": "A",
    "language": "LSC",
    "category": "Alfabeto",
    "animated": false,
    "status": "ACTIVE",
    "resources": [
      { "type": "IMAGE", "url": "http://localhost:8080/api/lexicon/media/alfabeto/thumbs/A.png" },
      { "type": "MODEL_3D", "url": "http://localhost:8080/api/lexicon/media/alfabeto/glb/A.glb" }
    ],
    "localizations": [{ "uiLanguage": "ES", "name": "A" }]
  }
}
```

The fields shown are a subset; the full shape is `Sign` in `domain/entity.ts`.

### Error codes

Errors have the form `{ success: false, code, message }`.

| Code | HTTP | When |
|------|------|------|
| `VALIDATION_ERROR` | 400 | Invalid field, reserved or malformed `code`, unsupported resource URL |
| `FORBIDDEN` | 403 | The user does not have the `ADMIN` role |
| `SIGN_NOT_FOUND`, `CATEGORY_NOT_FOUND` | 404 | The sign or category does not exist |
| `CODE_TAKEN`, `LETTER_TAKEN`, `CATEGORY_NAME_TAKEN`, `CATEGORY_IN_USE`, `POSITION_TAKEN` | 409 | A uniqueness or integrity rule would be broken |

The `code` values `ALPHABET`, `SEARCH`, `CATEGORIES`, `ADMIN` and `MEDIA` are reserved because they collide with fixed routes.

---

## Internal structure

```
src/
├── domain/                 entity.ts (types), rules.ts (validation and domain errors), repository.ts
├── ports/inbound/          lexicon_service.ts (use cases the HTTP layer can call)
├── application/            one factory per use case: list_signs, get_alphabet, get_sign, create_sign,
│                           update_sign, publish_sign, deactivate_sign, upsert_localization,
│                           manage_resources, manage_categories, resolve_category
├── adapters/inbound/http/  routes.ts, lexicon_controller.ts, dto/sign_request.ts
├── adapters/outbound/postgres/  lexicon_repository.ts, category_repository.ts
├── config.ts               the only place that reads LEXICON_MEDIA_DIR and LEXICON_MEDIA_BASE_URL
└── lexicon.module.ts       wires repositories, use cases and the router
```

---

## Documents for this service

- [data-model.md](./data-model.md) — Tables, constraints and differences with the target model
- [events.md](./events.md) — Events published and the target ones
- [decisions.md](./decisions.md) — Design decisions
- [runbook.md](./runbook.md) — Operation and troubleshooting
- Target data model → `06-data/domains/04-lexicon.md`
- Module README in the code → `services/lexicon-service/src/README.md`
- API contract → `07-api/contracts/openapi/lexicon-service.yaml`
