# Data Model — Recognition Service

> `recognition-service` is the **authoritative owner** of the data described here. No other service reads these tables or this
> collection. Full DDL and data dictionary: `06-data/domains/05-translation.md` and `06-ai.md`; this file is the service view.

---

## Implemented today

Taken from the migrations of Backend `develop` `2e0816f` (`services/recognition-service/db/`, applied in order by `docker-compose.yml`). Tables marked † are in `develop` but not yet deployed (production runs v1.3.0). PostgreSQL database `recognition`, schema `public` (no `translation` or `ai` schemas), plus MongoDB.

| Store | Table / collection | Key columns | Notes |
|-------|--------------------|-------------|-------|
| PostgreSQL | `translations` | `translation_id` SERIAL, `user_id` INT (logical, no FK), `input_text`, `output_text`, `type` (`texto_sena`, `sena_texto`, `voz_sena`), `confidence` NUMERIC(4,3), `source`, `is_deleted`, `created_at` | Deleted after 30 days (`005`, `TRANSLATION_RETENTION_DAYS`) |
| PostgreSQL | `sign_templates` | `template_id` SERIAL, `label`, `kind` (`static`, `motion`, `word`), `features` JSONB, `source`, `created_by` | Templates used by the recognizers in the app (`002`, `004`) |
| PostgreSQL | `erased_users` | `user_id`, `erased_at` | Accounts already erased; blocks writes with an old JWT (ADR-008) |
| PostgreSQL | `translation_daily_counts` † | `user_id`, `day`, `total` | Counts kept after the retention purge (`005`) |
| PostgreSQL | `translation_user_words` † | `user_id`, `word` | Distinct words kept after the purge (`005`) |
| MongoDB | `gesture_samples` | `_id` (UUID), `sign_code`, `capture_session_id`, `recorded_by` (NULL after erasure), `performed_by`, `consent_granted_at`, `consent_terms_version`, `frames`, `is_validated` | Indexes on `sign_code`, `capture_session_id`, `recorded_by`. As of 2026-10-26 the app does not call `/api/samples`, so it receives no data (decision H-06) |

There are no `translation_signs` or `ai_models` tables; each translation keeps its own `confidence` and `source`.

> **The sections after this one describe the reference (target) model**, which the code does not fully implement.

## Database engines

| Engine | Content | Justification |
|--------|---------|---------------|
| PostgreSQL, database `recognition` (schemas `translation`, `ai`) | `translations`, `translation_signs`, `ai_models` | Transactional, relational (history, model provenance, one active model) |
| **MongoDB 7**, collection `gesture_samples` | The samples / repetitions recorded to train the model | The metadata of a sample changes whenever the pipeline changes (landmarks today; frame rate, hands, device, extractor tomorrow). It is the one unstable schema of the system |

PostgreSQL and MongoDB never share foreign keys. References between them are logical IDs resolved by the application.

---

## PostgreSQL

### `translations`

The result of recognition and the user's history (the same rows: history is `deleted_at IS NULL`).

| Field | Type | Nullable | Description | Constraints |
|-------|------|----------|-------------|-------------|
| translation_id | UUID | No | Identifier | PK |
| user_id | UUID | No | Owner. **Logical ID** issued by iam | No FK (other service) |
| recognized_text | TEXT | No | Text delivered to the user | |
| confidence | DECIMAL(5,4) | Yes | Confidence of the whole translation, 0 to 1 | `ck_translation_confidence` |
| output_mode | enum | No | `TEXT` or `AUDIO` (default `TEXT`; `BOTH` is an open item, ALIGN-07) | |
| model_id | UUID | Yes | Model that produced it | FK to `ai_models`, `RESTRICT` (nullable, GAP-06) |
| created_at | TIMESTAMPTZ | No | | Default `CURRENT_TIMESTAMP` |
| deleted_at | TIMESTAMPTZ | Yes | History entry deleted by its owner; irreversible (INV-011) | |

Index: `(user_id, created_at)`; `idx_translations_deleted` should be partial `WHERE deleted_at IS NULL` (DATA-08).

### `translation_signs`

Ordered signs that make up a translation.

| Field | Type | Nullable | Description | Constraints |
|-------|------|----------|-------------|-------------|
| translation_sign_id | UUID | No | | PK |
| translation_id | UUID | No | | FK to `translations`, `CASCADE` |
| sign_id | UUID | No | Sign in the catalog. **Logical ID** of lexicon (`sign_lexicon`) | No FK (other service) |
| position | INTEGER | No | Order inside the translation | Unique `(translation_id, position)` |
| confidence | DECIMAL(5,4) | Yes | Confidence of this sign | `ck_translation_sign_confidence` |

`06-data/domains/05-translation.md` declares `sign_id` as a foreign key to `lexicon.sign_lexicon` with `RESTRICT`. That is
valid only while both live in one database. With a database per service, the FK is dropped, `sign_id` is a logical ID and the
guarantee "a sign in someone's history is never deleted" is kept by lexicon's rule that signs are retired (`INACTIVE`) and
never deleted. Recognition keeps its own copy of the active sign codes (`lexicon.SignPublished` / `SignWithdrawn`).

### `ai_models`

| Field | Type | Nullable | Description | Constraints |
|-------|------|----------|-------------|-------------|
| model_id | UUID | No | | PK |
| version | VARCHAR(50) | No | Semantic version | UNIQUE |
| description | VARCHAR(255) | Yes | | |
| trained_at | TIMESTAMPTZ | No | | |
| trained_by | UUID | No | Administrator / linguist. **Logical ID** of iam | No FK (other service) |
| sign_language | enum | No | Default `LSC` | |
| sample_count, sign_count | INTEGER | No | Samples used, distinct signs recognized | |
| accuracy | DECIMAL(5,4) | Yes | On the test set, 0 to 1. Not the confidence threshold | |
| storage_reference | TEXT | No | Path to the published `.tflite` | |
| is_active | BOOLEAN | No | The model the app serves. Only one (INV-022), via partial unique index `uq_single_active_model` (pending, DATA-11) | |
| created_at | TIMESTAMPTZ | No | | |

Activating a model deactivates the previous one in the same transaction. A model that produced translations is never deleted.
`ai_models` has no `confidence_threshold` column (ALIGN-03, the `ALTER TABLE` is written in `06-data/constraints.md`).

---

## MongoDB: `gesture_samples`

Training corpus. Not a table; **no foreign keys** into PostgreSQL.

| Field | Type | Description |
|-------|------|-------------|
| `_id` / `sample_id` | UUID | Identifier |
| `sign_id` | UUID | Sign recorded. Logical ID of lexicon |
| `capture_session_id` | UUID | Groups every take (repetition) of one recording batch. It is the unit of discard |
| `recorded_by` | UUID | Operator (administrator / linguist). Logical ID of iam |
| `performed_by` | String (max 150) | Who physically performed the sign; may be an external collaborator |
| `consent_granted_at` | Date | Required (Law 1581) |
| `consent_terms_version` | String | Required: which authorization document was signed |
| `sample_type` | String | `LANDMARKS` (default), `VIDEO`, `IMAGE` |
| `storage_reference` | String | Object-storage path |
| `is_validated` | Boolean | Only validated samples feed training |
| `validated_by`, `validated_at` | UUID, Date | Nullable |
| `created_at` | Date | |

Indexes: `{sign_id: 1}`, `{capture_session_id: 1}`, `{sign_id: 1, is_validated: 1}` (trainable samples).

A `$jsonSchema` validator (`validationLevel: strict`, `validationAction: error`) makes the consent fields and the other
required fields mandatory; it replaces the `NOT NULL`s. The full validator is in `06-data/domains/06-ai.md`.

The collection holds biometric data of identified people: **encryption at rest is mandatory** for MongoDB and for the object
storage, and a revocation must be executable in one operation (delete every sample of a `capture_session_id`).
Open item ALIGN-02: anonymous pseudonym (INV-010) versus named performer. It is a team decision.

---

## What exists today (code)

Database `traduce_senas`, schema `public`, integer keys. MongoDB is not used.

| Today | Target |
|-------|--------|
| `translations(translation_id SERIAL, user_id INT FK users, input_text, output_text, type, confidence NUMERIC(4,3), source, is_deleted, created_at)` | `translations` + `translation_signs` (UUID, `recognized_text`, `output_mode`, `deleted_at`, `model_id`) |
| `sign_templates(template_id SERIAL, label, kind 'static'/'motion', features JSONB, source, created_by INT FK users, created_at)` | No table in `06-data/`. Kept as the templates store of the on-device recognizer until the model registry replaces it (open) |
| none | `ai_models`, `gesture_samples` |

The code stores free text per translation (`output_text`); it does not link signs (`translation_signs`).

---

## Cross-service references

| Field | Points at | Rule |
|-------|-----------|------|
| `translations.user_id`, `ai_models.trained_by`, `gesture_samples.recorded_by`, `validated_by` | iam `users.user_id` | Logical ID; erased by `iam.AccountDeletionRequested` |
| `translation_signs.sign_id`, `gesture_samples.sign_id` | lexicon `sign_lexicon` | Logical ID |

`translations.user_id` is personal data: the history disappears with the account (RNF8), the opposite of `usage_events` in analytics.

---

## Schema migration

**Tool:** Liquibase for PostgreSQL; MongoDB validators and indexes are created by a startup migration script (`migrate-mongo` or equivalent, assumption).
**Script location:** `recognition-service/db/changelog/`, `recognition-service/db/mongo/`.
**Rollback policy:** reversible changesets have a rollback block; the data move from `public.translations` is one-way, back up first.
