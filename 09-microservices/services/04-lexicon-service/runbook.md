# Runbook — Lexicon Service

> Operation of the lexicon service. The commands assume Docker Compose. No Kubernetes, dashboard or alert channel is defined yet.

**Service:** lexicon-service (`services/lexicon-service`)
**Version:** 1.4.0 (backend `main` a962982)
**Last updated:** 2026-11-04

---

## 1. Quick information

| Field | Value |
|-------|-------|
| Process | Container `lexicon-service` (built from `services/lexicon-service/Dockerfile`) |
| Local port | `3003` (internal; Compose does not publish it) |
| Base path | `/api/lexicon` (through the gateway: `http://localhost:8080/api/lexicon`) |
| Database | PostgreSQL `lexicon` (container `postgres-lexicon`, published on `127.0.0.1:5435`), tables `categories`, `sign_lexicon`, `sign_localizations`, `multimedia_resource` |
| Media | The directory `public/lexicon/` of the service, or `LEXICON_MEDIA_DIR`; served at `/api/lexicon/media` |
| Health endpoint | `GET /health` (internal) |

---

## 2. Verify the service is healthy

```bash
# Through the gateway: expect HTTP 200 and 27 letters in "data"
curl -s http://localhost:8080/api/lexicon/alphabet

# Expect HTTP 200 and a binary glTF file
curl -sI http://localhost:8080/api/lexicon/media/alfabeto/glb/A.glb
```

```bash
# Expect 27
docker compose exec -T postgres-lexicon psql -U postgres -d lexicon -c "SELECT COUNT(*) FROM sign_lexicon WHERE type = 'LETTER' AND language = 'LSC' AND status = 'ACTIVE';"
```

---

## 3. Frequent problems and what to do

### Admin endpoints answer `403 FORBIDDEN`

The user has a valid token but no `ADMIN` role in the token. The roles are read from the token, so grant the role in iam-service and have the user sign in again (see the iam runbook).

### The alphabet returns an empty list or fewer than 27 letters

The seed did not run or signs were retired. The seed runs when the volume of `postgres-lexicon` is created.

```bash
docker compose exec -T postgres-lexicon psql -U postgres -d lexicon -c "SELECT code, status FROM sign_lexicon WHERE type = 'LETTER' ORDER BY display_order;"
```

If rows are missing, apply `services/lexicon-service/db/003_lexicon.sql` again (it only creates what is missing). If a letter is `INACTIVE`, publish it: `POST /api/lexicon/LETTER_X/publish` with an ADMIN token.

### 3D models or thumbnails return 404

- The media directory is missing or `LEXICON_MEDIA_DIR` points elsewhere. Check the files in the container: `docker compose exec lexicon-service ls public/lexicon/alfabeto/glb`.
- The URLs point to a CDN that does not hold the files: check `LEXICON_MEDIA_BASE_URL`.
- Media are cached for 7 days by clients; a replaced file must get a new name.

### `409 CODE_TAKEN`, `LETTER_TAKEN` or `POSITION_TAKEN` when saving

A uniqueness rule was hit. Inspect the existing row:

```bash
docker compose exec -T postgres-lexicon psql -U postgres -d lexicon -c "SELECT lexicon_id, code, letter, language, status FROM sign_lexicon WHERE code = 'SIGN_CODE_HERE' OR (language = 'LSC' AND letter = 'A');"
docker compose exec -T postgres-lexicon psql -U postgres -d lexicon -c "SELECT resource_id, type, url, display_order FROM multimedia_resource WHERE lexicon_id = 1 ORDER BY display_order;"
```

Use another position or code, or remove the conflicting resource with `DELETE /api/lexicon/:code/resources/:resourceId`.

### `400 VALIDATION_ERROR` on a resource URL

Only relative paths with an allowed extension, or `https` URLs of the origin in `LEXICON_MEDIA_BASE_URL`, are accepted. Set that variable and recreate the container to allow a CDN: `docker compose up -d --force-recreate lexicon-service`.

### Recognition does not know a newly published sign

Recognition only logs `lexicon.SignPublished`; it keeps no catalog. Check that the event was published and not left in a dead-letter queue:

```bash
docker compose logs --tail=100 lexicon-service | grep -i rabbit
docker compose exec rabbitmq rabbitmqctl list_queues name messages | grep -E 'lexicon|recognition'
```

---

## 4. Maintenance operations

### 4.1 Apply or re-apply the migration

```bash
# Back up first if the database already holds lexicon data
docker compose exec -T postgres-lexicon pg_dump -U postgres -d lexicon -t sign_lexicon -t sign_localizations -t categories -t multimedia_resource > lexicon_backup.sql

docker compose exec -T postgres-lexicon psql -X -v ON_ERROR_STOP=1 -U postgres -d lexicon < services/lexicon-service/db/003_lexicon.sql
```

The script is idempotent and does not overwrite what an administrator edited.

### 4.2 Retire or restore a sign

```bash
# Retire (status = INACTIVE)
curl -X DELETE http://localhost:8080/api/lexicon/WORD_CODE -H "Authorization: Bearer $TOKEN"

# Restore
curl -X POST http://localhost:8080/api/lexicon/WORD_CODE/publish -H "Authorization: Bearer $TOKEN"
```

### 4.3 Roll back a deploy

There is no migration rollback. Check out the previous commit and rebuild the service:

```bash
git checkout <previous-commit>
docker compose up -d --build lexicon-service
```

If the older build expects columns that `003_lexicon.sql` has already removed (the `word`, `description` and `category` columns of the first version), restore the tables from the backup of section 4.1 as well.

---

## 5. Post-incident checklist

- [ ] `GET /api/lexicon/alphabet` returns 27 letters
- [ ] An ADMIN can create, publish and retire a test sign
- [ ] Media are served (section 2)
- [ ] Incident recorded in `13-operations/incident-management.md`
