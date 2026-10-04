# Recognition Service (core)

> The core of Traduce Señas: it stores the result of sign recognition and the user's translation history, manages the
> recognition models, serves the sign templates used by the on-device recognizer, and holds the corpus of gesture samples
> used to train the model.

**Extraction status:** pending. The code exists as the backend modules `translations` (`backend/src/domains/translations/`)
and `ia` (`backend/src/domains/ia/`), both hexagonal. See `09-microservices/service-catalog.md`.

---

## Responsibility

Owns `translations`, `translation_signs` and `ai_models` (PostgreSQL) and `gesture_samples` (MongoDB). Decides what counts
as a recognized translation and which model version is active. Recognition itself runs on the device (TensorFlow.js in
the mobile app); this service stores what it produces and distributes the model and the templates.

---

## Location in the architecture

| Field | Value |
|-------|-------|
| Number in catalog | 03 |
| Local port | 3002 |
| Bounded contexts | Recognition & Translation (core) and AI / model training (the sample rules belong to Consent & Personal Data) |
| DB engine | PostgreSQL `recognition` + **MongoDB** (`gesture_samples`) |
| Data owned | `06-data/domains/05-translation`, `06-ai` |
| Gateway paths | `/api/translations/**`, `/api/recognition/**`, `/api/models/**`, `/api/samples/**` |
| Communicates with | RabbitMQ. No synchronous calls to other services |
| Consumed by | The app (through the gateway) |
| Events | Publishes translation, model and sample events; consumes consent, account and lexicon events. See [events.md](./events.md) |
| Health | `GET /health` |

---

## Responsibilities (what this service DOES)

- Save a translation produced on the device, list the user's history, soft-delete an entry (irreversible, private to its owner)
- Keep the registry of recognition models (`ai_models`): version, provenance, accuracy, exactly one active model
- Serve the sign templates used by the on-device recognizer (static: 63 values, motion: 16 frames of 126 values)
- Register the gesture samples recorded to train the model (MongoDB `gesture_samples`), group them by capture session, validate them
- Enforce the consent rule for samples: no sample without consent evidence; a revoked consent discards the capture sessions
- Keep a local copy of the active sign codes from lexicon (refreshed by `lexicon.SignPublished` / `SignWithdrawn`)
- Run or register model training (ADMIN only)

## Out of scope (what it does NOT do)

- **The sign catalog** (codes, texts, media): `lexicon-service`. Recognition only knows the `sign_lexicon.code` values
- **Accounts, roles, consent grants:** `iam-service`
- **Usage statistics and achievements:** `analytics-service` and `profile-service`, fed by events
- **Showing notifications:** `profile-service`

---

## What exists today

### Module `translations` (PostgreSQL, JWT required on every route)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/translations` | Save `{inputText?, outputText, type, confidence?, source?}`. `type`: `texto_sena`, `sena_texto`, `voz_sena` |
| GET | `/api/translations/history` | List the user's translations that are not deleted |
| DELETE | `/api/translations/:id` | Soft delete (`is_deleted = TRUE`) |

### Module `ia` (sign templates, PostgreSQL JSONB)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/sign-templates` | Public | The translation screen downloads the templates when it opens, even without a session |
| POST | `/api/sign-templates` | JWT | Import templates `{label, kind, features, source?}` |
| DELETE | `/api/sign-templates/:id` | JWT | Delete a template |

Scripts under `ia/training/` import the LSC54 dataset (`convert-lsc54-to-templates`, `upload-templates`, ...).
The outbound ports `ai_service` and `gesture_repository` are declared but empty (comments say: pending, the gesture domain
is planned on MongoDB). **MongoDB is not connected in the code yet.**

### Target paths

| Path prefix | Content |
|-------------|---------|
| `/api/translations/**` | Same as today |
| `/api/recognition/**` | Sign templates (today `/api/sign-templates`) and recognition-related reads |
| `/api/models/**` | Model registry, publish and training (ADMIN, permission `models.manage`) |
| `/api/samples/**` | Capture sessions, samples, validation (LINGUIST / ADMIN, permissions `samples.capture`, `samples.validate`) |

The endpoint-level contract for `/models` and `/samples` is not defined yet.

---

## How to run it locally

Today (inside the backend, port 3000):

```bash
psql -h localhost -p 5433 -U postgres -d traduce_senas -f backend/migrations/001_translations.sql
psql -h localhost -p 5433 -U postgres -d traduce_senas -f backend/migrations/002_sign_templates.sql
cd backend && npm install && npm run dev
curl http://localhost:3000/api/sign-templates
```

Target:

```bash
docker compose up -d recognition-service
curl http://localhost:3002/health
```

### Environment variables

| Variable | Purpose |
|----------|---------|
| `PORT` | HTTP port (`3002` target) |
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` | PostgreSQL (`DB_NAME=recognition`) |
| `MONGO_URL` | MongoDB connection for `gesture_samples` (target) |
| `JWT_VERIFY_KEY` | Verification key of the JWT |
| `RABBITMQ_URL` | Broker URL (target) |
| `MODEL_STORAGE_DIR` | Where the published `.tflite` artifacts are stored (target) |

---

## Related documents

- [data-model.md](./data-model.md) — Tables and the MongoDB collection
- [events.md](./events.md) — Events published and consumed
- [decisions.md](./decisions.md) — Design decisions
- [runbook.md](./runbook.md) — Operation
- Data model source → `06-data/domains/05-translation.md`, `06-ai.md`
- API contract → `07-api/contracts/openapi/` (no file for this service yet)
