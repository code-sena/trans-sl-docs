# Lexicon

> Catalog of Colombian Sign Language (LSC) signs: letters, words and phrases, with their categories, their
> text in each interface language and their media (3D models, images). The alphabet is not a separate
> structure: it is the set of signs with `type = 'LETTER'`.
>
> **Form:** a module of the backend modular monolith (`backend/src/domains/lexicon/`), not an independent service.
> See `09-microservices/service-catalog.md`.

---

## Responsibility

Owns the sign catalog: `categories`, `sign_lexicon`, `sign_localizations` and `multimedia_resource`.
`sign_lexicon.code` (for example `LETTER_A`, `GREETING_HELLO`) is the class that the recognizer predicts, so the
published codes are the contract between this catalog and the recognition engine. A published code is never renamed
and a sign is never deleted: it is retired with `status = 'INACTIVE'`.

---

## Location in the architecture

| Field | Value |
|-------|-------|
| Number in catalog | 03 |
| Process / port | Backend process, port `3000` (env `PORT`) |
| Mount path | `/api/lexicon` |
| Code | `backend/src/domains/lexicon/` |
| Module factory | `makeLexiconModule` in `lexicon.module.ts`, mounted in `backend/cmd/server/main.ts` |
| DB engine | PostgreSQL, database `traduce_senas`, schema `public` |
| Bounded context | Learning & Lexicon (`02-domain/domain-map.md`) |
| Communicates with | `shared/http/auth_middleware` (JWT), `shared/http/require_role` (`ADMIN`), PostgreSQL |
| Consumed by | The mobile / web app (alphabet screen, catalog search, admin screens) |
| Status | Implemented, with unit tests |

---

## Responsibilities (what this module DOES)

- Lists and searches active signs with relevance ordering (exact match, then prefix, then contains, also against `code`)
- Serves the 27-letter alphabet in order (Ñ after N)
- Returns `word`, `meaning` and `description` in the requested interface language (`?lang=ES|EN`), falling back to ES and then to any
- Lets an administrator create, edit, publish and retire signs, manage categories, localizations and media
- Serves the alphabet 3D models (`.glb`) and thumbnails from `public/lexicon/` under `/api/lexicon/media`
- Enforces the catalog rules: unique `code`, one letter per sign language, `letter` only for `LETTER` signs, unique media position per sign, categories with signs cannot be deleted

## Out of scope (what it does NOT do)

- **Authentication and roles:** `shared/http/auth_middleware` and `require_role` do it; the module only receives them as dependencies
- **Recognition:** the on-device engine and the `ia` module (`/api/sign-templates`) do it; the lexicon only supplies the class names
- **Translation history:** the `translations` module stores what was recognized
- **Storing binary files:** media are files in `public/lexicon/` (or a CDN); the database stores only the path or URL
- **Emitting events:** no event is published when a sign changes

---

## How to run it locally

```bash
# 1. PostgreSQL with the base tables (users, role) already created by migrations/000_users.sql
# 2. Apply the lexicon migration (idempotent, can be re-run). It seeds the 27 letters and the ADMIN role
psql -h localhost -p 5433 -U postgres -d traduce_senas -f backend/migrations/003_lexicon.sql

# 3. Start the backend
cd backend
cp .env.example .env           # then set DB_*, JWT_SECRET and the other variables listed below
npm install
npm run dev

# 4. Verify
curl http://localhost:3000/api/lexicon/alphabet
curl "http://localhost:3000/api/lexicon?q=a&lang=ES&limit=5"

# 5. Run the tests
npm test
```

To make a user an administrator (the migration does not do it):

```sql
INSERT INTO public.user_role (user_id, role_id)
SELECT u.user_id, r.role_id
FROM public.users u
JOIN public.role r ON r.name = 'ADMIN'
WHERE u.email = 'admin@example.com'
ON CONFLICT DO NOTHING;
```

### Environment variables

| Variable | Purpose |
|----------|---------|
| `PORT` | HTTP port (default `3000`) |
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` | PostgreSQL connection |
| `JWT_SECRET` | Secret used to verify the admin token |
| `LEXICON_MEDIA_DIR` | Optional. Directory of the media files (default `<cwd>/public/lexicon`) |
| `LEXICON_MEDIA_BASE_URL` | Optional. Origin from which absolute `https` resource URLs are accepted (for example a CDN). Without it, only relative paths are accepted |

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
| GET | `/media/*` | Public | Files from `public/lexicon/` (cached 7 days) |
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
      { "type": "IMAGE", "url": "http://localhost:3000/api/lexicon/media/alfabeto/thumbs/A.png" },
      { "type": "MODEL_3D", "url": "http://localhost:3000/api/lexicon/media/alfabeto/glb/A.glb" }
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
lexicon/
├── domain/                 entity.ts (types), rules.ts (validation and domain errors), repository.ts
├── ports/inbound/          lexicon_service.ts (use cases the HTTP layer can call)
├── application/            one factory per use case: list_signs, get_alphabet, get_sign, create_sign,
│                           update_sign, publish_sign, deactivate_sign, upsert_localization,
│                           manage_resources, manage_categories, resolve_category
├── adapters/inbound/http/  routes.ts, lexicon_controller.ts, dto/sign_request.ts
├── adapters/outbound/postgres/  lexicon_repository.ts, category_repository.ts
└── lexicon.module.ts       wires repositories, use cases and the router
```

---

## Documents for this module

- [data-model.md](./data-model.md) — Tables, constraints and differences with the target model
- [events.md](./events.md) — Events (none today) and the planned ones
- [decisions.md](./decisions.md) — Design decisions of the module
- [runbook.md](./runbook.md) — Operation and troubleshooting
- Target data model → `06-data/domains/04-lexicon.md`
- Module README in the code → `backend/src/domains/lexicon/README.md`
- API contract: there is no OpenAPI file for this module yet (`07-api/contracts/openapi/` only holds the scaffold gateway and auth-service)
