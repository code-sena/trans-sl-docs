# Runbook — Lexicon

> Operation of the lexicon module. It runs inside the backend process, so starting, scaling and
> deploying it means operating the backend. There is no Kubernetes, dashboard or alert channel defined yet;
> this runbook covers what exists: Node.js, PostgreSQL and the media directory.

**Module:** lexicon (`backend/src/domains/lexicon/`)
**Version:** 1.0
**Last updated:** 2026-10-04

---

## 1. Quick information

| Field | Value |
|-------|-------|
| Process | Backend (`npm run dev` in development, `npm run build` then `npm start` in production) |
| Local port | `3000` (env `PORT`) |
| Base path | `/api/lexicon` |
| Database | PostgreSQL `traduce_senas`, tables `categories`, `sign_lexicon`, `sign_localizations`, `multimedia_resource` (plus `users`, `role`, `user_role` for admin checks) |
| Media | `backend/public/lexicon/` or `LEXICON_MEDIA_DIR`; served at `/api/lexicon/media` |
| Health endpoint | None dedicated. Use `GET /api/lexicon/alphabet` |

---

## 2. Verify the module is healthy

```bash
# Expect HTTP 200 and 27 letters in "data"
curl -s http://localhost:3000/api/lexicon/alphabet

# Expect HTTP 200 and a binary glTF file
curl -sI http://localhost:3000/api/lexicon/media/alfabeto/glb/A.glb

# Tests (from backend/)
npm test
```

```sql
-- Expect 27
SELECT COUNT(*) FROM public.sign_lexicon WHERE type = 'LETTER' AND language = 'LSC' AND status = 'ACTIVE';
```

---

## 3. Frequent problems and what to do

### Admin endpoints answer `403 FORBIDDEN`

The user has a valid token but no `ADMIN` role.

```sql
SELECT u.email, r.name
FROM public.users u
LEFT JOIN public.user_role ur ON ur.user_id = u.user_id
LEFT JOIN public.role r ON r.role_id = ur.role_id
WHERE u.email = 'admin@example.com';

-- Grant the role
INSERT INTO public.user_role (user_id, role_id)
SELECT u.user_id, r.role_id FROM public.users u JOIN public.role r ON r.name = 'ADMIN'
WHERE u.email = 'admin@example.com'
ON CONFLICT DO NOTHING;
```

The change takes effect on the next request (roles are not stored in the token).

### Admin endpoints answer `500` and the log says "Falta la tabla public.user_role o public.role"

The roles migration was not applied. Run the lexicon migration, which creates both tables:

```bash
psql -h localhost -p 5433 -U postgres -d traduce_senas -f backend/migrations/003_lexicon.sql
```

### The alphabet returns an empty list or fewer than 27 letters

The migration was not applied or signs were retired.

```sql
SELECT code, status FROM public.sign_lexicon WHERE type = 'LETTER' ORDER BY display_order;
```

If rows are missing, re-run `003_lexicon.sql` (it only creates what is missing). If a letter is `INACTIVE`, publish it: `POST /api/lexicon/LETTER_X/publish` with an ADMIN token.

### 3D models or thumbnails return 404

```bash
ls backend/public/lexicon/alfabeto/glb | head
```

- The directory is missing or `LEXICON_MEDIA_DIR` points elsewhere: restore the files from `modelado/glb` and `modelado/thumbs` (see `backend/src/domains/lexicon/README.md`).
- The URLs point to a CDN that does not hold the files: check `LEXICON_MEDIA_BASE_URL`.
- Media are cached for 7 days by clients; a replaced file must get a new name.

### `409 CODE_TAKEN`, `LETTER_TAKEN` or `POSITION_TAKEN` when saving

A uniqueness rule was hit. Inspect the existing row:

```sql
SELECT lexicon_id, code, letter, language, status FROM public.sign_lexicon WHERE code = 'SIGN_CODE_HERE' OR (language = 'LSC' AND letter = 'A');
SELECT resource_id, type, url, display_order FROM public.multimedia_resource WHERE lexicon_id = 1 ORDER BY display_order;
```

Use another position or code, or remove the conflicting resource with `DELETE /api/lexicon/:code/resources/:resourceId`.

### `400 VALIDATION_ERROR` on a resource URL

Only relative paths with an allowed extension, or `https` URLs of the origin in `LEXICON_MEDIA_BASE_URL`, are accepted. Set that variable and restart the backend to allow a CDN.

---

## 4. Maintenance operations

### 4.1 Apply or re-apply the migration

```bash
# Back up first if the database already holds lexicon data
pg_dump -h localhost -p 5433 -U postgres -d traduce_senas -t public.sign_lexicon -t public.sign_localizations -t public.categories -t public.multimedia_resource > lexicon_backup.sql

psql -h localhost -p 5433 -U postgres -d traduce_senas -f backend/migrations/003_lexicon.sql
```

The script is idempotent and does not overwrite what an administrator edited.

### 4.2 Retire or restore a sign

```bash
# Retire (status = INACTIVE)
curl -X DELETE http://localhost:3000/api/lexicon/WORD_CODE -H "Authorization: Bearer $TOKEN"

# Restore
curl -X POST http://localhost:3000/api/lexicon/WORD_CODE/publish -H "Authorization: Bearer $TOKEN"
```

### 4.3 Roll back a deploy

There is no migration rollback. Redeploying an older backend build is enough if the database already ran migration 003. If the older build predates the localization refactor it expects the `word`, `description` and `category` columns that migration 003 drops, so restore the tables from the backup of section 4.1 as well.

---

## 5. Post-incident checklist

- [ ] `GET /api/lexicon/alphabet` returns 27 letters
- [ ] An ADMIN can create, publish and retire a test sign
- [ ] Media are served (section 2)
- [ ] Incident recorded in `13-operations/incident-management.md`
