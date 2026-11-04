# Recognition Service (core)

> The core of Traduce Señas: it stores the translation history of each user, serves the sign templates used by the
> on-device recognizer, and holds the corpus of gesture samples used to train the model.

**Extraction status:** extracted. The code lives in `services/recognition-service` (own process, own Dockerfile, port 3002,
PostgreSQL database `recognition`, and MongoDB for `gesture_samples` when `MONGO_URL` is set). See `09-microservices/service-catalog.md`.

---

## Responsibility

Owns `translations`, `sign_templates` and `erased_users` (PostgreSQL) and `gesture_samples` (MongoDB). Recognition itself runs
on the device (TensorFlow.js in the mobile app and the web app); this service stores what it produces and distributes the
templates. The model registry (`ai_models`) is planned, not implemented.

---

## Location in the architecture

| Field | Value |
|-------|-------|
| Number in catalog | 03 |
| Local port | 3002 (internal; not published by Docker Compose) |
| Bounded contexts | Recognition & Translation (core). The consent rule for samples is checked here too |
| DB engine | PostgreSQL `recognition` + MongoDB (`gesture_samples`, only when `MONGO_URL` is set) |
| Data owned | See [data-model.md](./data-model.md) |
| Gateway paths | `/api/translations/**`, `/api/recognition/sign-templates`, `/api/sign-templates` (deprecated alias), `/api/samples/**` |
| Communicates with | RabbitMQ only (publishes `TranslationProduced`, consumes `iam.UserDeleted` and `lexicon.*`). No synchronous calls to other services |
| Consumed by | The app (through the gateway) |
| Events | See [events.md](./events.md) |
| Health | `GET /health` |

---

## Responsibilities (what this service DOES)

- Save a translation sent by the client (`POST /api/translations`), list the user's history and delete an entry (soft delete, private to its owner)
- Count translations for statistics: all users for administrators (`GET /api/translations/stats`, permission `stats.read`) and the user's own counters (`GET /api/translations/me/stats`)
- Serve the sign templates used by the on-device recognizer, in three kinds: `static` (63 values), `motion` (16 frames of 126 values) and `word` (30 frames of 128 values). Reading is public; importing and deleting need the permission `models.manage`
- Register gesture samples (`POST /api/samples`, ADMIN), grouped by capture session. Every sample needs the date of consent and the terms version, or it is rejected
- On `iam.UserDeleted`, delete the user's translations, unlink the user from the samples and keep the user id in `erased_users`
- Delete translations after `RECOGNITION_TRANSLATION_RETENTION_DAYS` (default 30) and keep their daily counts and distinct words for the statistics

## Out of scope (what it does NOT do)

- **The sign catalog** (codes, texts, media): `lexicon-service`. Recognition only receives the `lexicon.*` events, and today it only logs them
- **Accounts, roles and consent grants:** `iam-service`
- **Usage statistics and achievements:** `analytics-service` and `profile-service`
- **Notifications:** `profile-service`
- **Model training and the model registry:** not implemented in the service. The training scripts live in `services/recognition-service/training/extraction/` (`train_model.py`, `train_and_export.py`, `colab_train.ipynb`)

---

## Routes (implemented)

All routes of `/api/translations` need a valid JWT. The full contract with the errors is in `07-api/contracts/openapi/recognition-service.yaml`.

| Area | Method and path | Access |
|------|-----------------|--------|
| Translations | `POST /api/translations`, `GET /api/translations/history`, `DELETE /api/translations/:id`, `GET /api/translations/me/stats` | Any valid JWT |
| Translations | `GET /api/translations/stats` | Permission `stats.read` |
| Sign templates | `GET /api/recognition/sign-templates` (and the alias `/api/sign-templates`) | Public |
| Sign templates | `POST /api/recognition/sign-templates`, `DELETE /api/recognition/sign-templates/:id` (and the alias) | Permission `models.manage` |
| Samples | `POST /api/samples`, `GET /api/samples` | ADMIN role |

The alias `/api/sign-templates` is deprecated; the current frontend still calls it.

---

## How to run it locally

```bash
# With Docker Compose (starts postgres-recognition, mongo and rabbitmq first)
docker compose up -d recognition-service

# Locally, only this service (port 3002)
npm run dev -w @traduce/recognition-service
curl http://localhost:3002/health
```

### Environment variables

| Variable | Purpose |
|----------|---------|
| `PORT` | HTTP port (`3002`) |
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` | PostgreSQL connection (`DB_NAME=recognition`; in Compose the host is `postgres-recognition`) |
| `MONGO_URL` | MongoDB connection for `gesture_samples`. Empty: the samples are kept in memory and lost on restart |
| `JWT_SECRET` | Verification secret of the JWT (HS256) |
| `RECOGNITION_TRANSLATION_RETENTION_DAYS` | Days before a translation is deleted (default `30`) |
| `RABBITMQ_URL` | Broker URL. Empty means the in-memory bus |

---

## Related documents

- [data-model.md](./data-model.md) — Tables and the MongoDB collection
- [events.md](./events.md) — Events published and consumed
- [decisions.md](./decisions.md) — Design decisions
- [runbook.md](./runbook.md) — Operation
- Target data model → `06-data/domains/05-translation.md`, `06-ai.md`
- API contract → `07-api/contracts/openapi/recognition-service.yaml`
