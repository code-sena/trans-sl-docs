# Runbook — Recognition Service

> For whoever is on call. The service is not extracted yet; commands marked "today" refer to the backend process. No Kubernetes,
> dashboard or alert channel is defined yet; commands assume Docker Compose.

**Service:** recognition-service
**Version:** 1.0 (target)
**Last updated:** 2026-10-04

---

## 1. Quick information

| Field | Value |
|-------|-------|
| Local port | 3002 (today: backend on 3000) |
| Health | `GET http://localhost:3002/health` |
| Databases | PostgreSQL `recognition`; MongoDB `gesture_samples` |
| Broker | RabbitMQ, exchange `traduce.events`, queue `recognition.main` |
| Files | Published model artifacts (`MODEL_STORAGE_DIR`), sample object storage |

---

## 2. Verify the service is healthy

```bash
curl -s http://localhost:3002/health
# Today
curl -s http://localhost:3000/api/sign-templates | head -c 200

# Through the gateway, with a token
curl -s http://localhost:8080/api/translations/history -H "Authorization: Bearer $TOKEN"
```

```sql
-- Exactly one active model (expect 1)
SELECT COUNT(*) FROM ai.ai_models WHERE is_active;
```

```javascript
// mongosh: the validator is in place
db.getCollectionInfos({ name: "gesture_samples" })[0].options.validator
```

---

## 3. Frequent problems and what to do

### Recognition stops working after publishing a model (rise in `MODEL_INFERENCE_ERROR`)

The new model is worse than the previous one. Roll back to the previous version (its id is in `RecognitionModelPublished.previousModelId`):

```sql
BEGIN;
UPDATE ai.ai_models SET is_active = FALSE WHERE is_active;
UPDATE ai.ai_models SET is_active = TRUE WHERE model_id = '<previous-model-id>';
COMMIT;
```

### Two active models

The unique index `uq_single_active_model` is missing (DATA-11). Fix the data with the transaction above and apply the constraints migration.

### Samples are rejected by MongoDB

The validator requires `consent_granted_at` and `consent_terms_version`. A sample without consent evidence is an illegal record;
do not relax the validator. Fix the caller.

### A user revoked consent but samples remain

```javascript
// mongosh: find the batches recorded for that collaborator, then delete by capture session
db.gesture_samples.find({ performed_by: "<name>" }, { capture_session_id: 1 })
db.gesture_samples.deleteMany({ capture_session_id: UUID("<id>") })
```

Delete the files in object storage too and make sure `CaptureSessionDiscarded` was published. Escalate to the data owner.

### Consumer errors: `ConsentRevoked` or `AccountDeletionRequested` in the DLQ

```bash
docker compose exec rabbitmq rabbitmqctl list_queues name messages | grep recognition
```

Read the message, fix the cause, shovel it back. Legal priority: these two events are compliance obligations.

### The sign catalog is out of date (a published sign is not recognized)

Check that `lexicon.SignPublished` was consumed; compare the codes:

```bash
curl -s http://localhost:3003/api/lexicon?limit=100 | head -c 400
```

If an event was lost, replay it from lexicon or run the catalog refresh job.

---

## 4. Maintenance operations

### 4.1 Back up

```bash
docker compose exec postgres pg_dump -U postgres -d recognition > recognition_backup.sql
docker compose exec mongo mongodump --db traduce --collection gesture_samples --archive > gesture_samples.archive
```

The dump of `gesture_samples` contains biometric data of identified people: store it encrypted.

### 4.2 Publish a model

1. Register the model (`POST /api/models`, ADMIN) with its `storage_reference`.
2. Activate it; check section 2 (exactly one active model).
3. Watch `RecognitionFailed` and `MODEL_INFERENCE_ERROR` for the next hour.

### 4.3 Roll back a deploy

```bash
docker compose up -d recognition-service   # previous image tag
```

---

## 5. Post-incident checklist

- [ ] One active model, history endpoint answers
- [ ] No messages in `recognition.main.dlq`
- [ ] No samples without consent evidence
- [ ] Incident recorded in `13-operations/incident-management.md`
