# Runbook — Recognition Service

> For whoever is on call. Each section is executable without extra context. The commands assume Docker Compose.
> No Kubernetes, dashboard or alert channel is defined yet.

**Service:** recognition-service
**Version:** 1.4.0 (backend `main` a962982)
**Last updated:** 2026-11-04

---

## 1. Quick information

| Field | Value |
|-------|-------|
| Local port | 3002 (internal; Compose does not publish it) |
| Health | `GET http://localhost:3002/health` when the service runs locally |
| Databases | PostgreSQL `recognition` (container `postgres-recognition`); MongoDB database `recognition`, collection `gesture_samples` (only with `MONGO_URL`) |
| Broker | RabbitMQ, exchange `traduce.events`. Queues `recognition-service.user-deleted` and `recognition-service.lexicon-events` |

---

## 2. Verify the service is healthy

```bash
# Through the gateway: the public list of templates
curl -s http://localhost:8080/api/recognition/sign-templates | head -c 200

# Saving and reading the history need a token
curl -s http://localhost:8080/api/translations/history -H "Authorization: Bearer $TOKEN"
```

```bash
# Templates per kind (expect one row per kind that has templates)
docker compose exec -T postgres-recognition psql -U postgres -d recognition -c "SELECT kind, COUNT(*) FROM sign_templates GROUP BY kind;"
```

---

## 3. Frequent problems and what to do

### Samples disappear after a restart

`MONGO_URL` is empty, so the samples live in memory. Set `MONGO_URL` in `.env` and recreate the container:
`docker compose up -d --force-recreate recognition-service`.

### Samples are rejected with `VALIDATION_ERROR`

Each sample needs `consentGrantedAt` (an ISO date) and `consentTermsVersion`, and frames of 63 or 126 numbers, at most 64 frames. A sample without consent evidence is not stored; fix the caller and do not relax the check.

### A user revoked consent but samples remain

The revocation of consent is not implemented in the code (there is no consent event). Find the samples of the collaborator and delete them by hand, then escalate to the data owner. MongoDB is published on `127.0.0.1:27017` only, so run `mongosh` on the server with the root credentials of `.env` (`MONGO_ROOT_USER`, `MONGO_ROOT_PASSWORD`):

```bash
mongosh "mongodb://<MONGO_ROOT_USER>:<MONGO_ROOT_PASSWORD>@127.0.0.1:27017/recognition?authSource=admin" \
  --eval 'db.gesture_samples.find({ performed_by: "<name>" }, { capture_session_id: 1 })'
mongosh "mongodb://<MONGO_ROOT_USER>:<MONGO_ROOT_PASSWORD>@127.0.0.1:27017/recognition?authSource=admin" \
  --eval 'db.gesture_samples.deleteMany({ capture_session_id: "<id>" })'
```

### Messages in the consumer queues

A message in `recognition-service.user-deleted.dead` is an account deletion that was not applied: translations of that user may remain. Read the message, fix the cause and move it back by hand.

```bash
docker compose exec rabbitmq rabbitmqctl list_queues name messages | grep recognition
```

### The sign catalog does not match lexicon

Recognition only logs `lexicon.SignPublished` and `lexicon.SignWithdrawn`; it keeps no catalog, so nothing in this service changes when lexicon changes. Check the catalog in lexicon:

```bash
curl -s "http://localhost:8080/api/lexicon?limit=100" | head -c 400
```

---

## 4. Maintenance operations

### 4.1 Back up

```bash
docker compose exec -T postgres-recognition pg_dump -U postgres -d recognition > recognition_backup.sql
mongodump --uri "mongodb://<MONGO_ROOT_USER>:<MONGO_ROOT_PASSWORD>@127.0.0.1:27017/recognition?authSource=admin" --collection gesture_samples --archive=gesture_samples.archive
```

The dump of `gesture_samples` contains biometric data of identified people: store it encrypted.

### 4.2 Translation retention

Translations older than `RECOGNITION_TRANSLATION_RETENTION_DAYS` (default 30) are deleted by the retention scheduler. Their counts stay in `translation_daily_counts` and `translation_user_words`, so the statistics do not change. To keep history longer, raise the variable and recreate the container.

### 4.3 Roll back a deploy

```bash
git checkout <previous-commit>
docker compose up -d --build recognition-service
```

---

## 5. Post-incident checklist

- [ ] The history endpoint answers with a valid token
- [ ] No messages in the `recognition-service.*.dead` queues
- [ ] Every sample stored has consent evidence
- [ ] Incident recorded in `13-operations/incident-management.md`
