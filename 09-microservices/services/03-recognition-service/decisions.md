# Design Decisions — Recognition Service

> Decisions specific to this service. Global ones go in `05-architecture/decisions/records/`.

---

## [DEC-001] Samples live in MongoDB, history and models in PostgreSQL

**Date:** 2026-10-04
**Status:** Active (product decision and `06-data/domains/06-ai.md`)

**Context:**
A training sample's metadata changes whenever the recognition pipeline changes. Translations and models are stable and relational.

**Decision:**
`gesture_samples` is a MongoDB collection with a JSON Schema validator. Translations, `translation_signs` and `ai_models`
stay in PostgreSQL. The two stores share no foreign keys.

**Alternatives considered:**
- Everything in PostgreSQL: each new sample attribute is a migration.
- Everything in MongoDB: loses constraints that matter (one active model, ordered signs).

**Consequences:**
- Advantage: the corpus evolves without migrations and can be moved or destroyed as a unit (Law 1581).
- Trade-off: nothing prevents a sample from pointing at a sign that no longer exists; consistency is the application's job.

---

## [DEC-002] Recognition runs on the device; the service stores and distributes

**Date:** 2026-10-04
**Status:** Active (matches `05-architecture/overview.md`: React Native app with TensorFlow.js)

**Context:**
The mobile app does the inference (camera and TensorFlow.js). The `.tflite` extension of `storage_reference` suggests on-device
inference, but the decision was never recorded in the domain map.

**Decision:**
The service does not infer. It receives the result (`recognized_text`, `confidence`), stores it, and distributes the active
model and the sign templates. The outbound port `ai_service` stays empty until server-side inference is needed.

**Consequences:**
- Advantage: latency (RNF1) does not depend on the network.
- Trade-off: the confidence threshold is evaluated on the device; ALIGN-03 (a threshold column in `ai_models`) must be resolved so that the server publishes it with the model.

---

## [DEC-003] No foreign keys to iam or lexicon

**Date:** 2026-10-04
**Status:** Active

**Context:**
`06-data/domains/05-translation.md` declares FKs to `identity.users` and `lexicon.sign_lexicon`. Those two now live in other services.

**Decision:**
`user_id` and `sign_id` are logical IDs without FK. Deletion of a user is propagated by `iam.AccountDeletionRequested`. The guarantee
that a sign in a history is never deleted is kept by lexicon (signs are retired, never deleted).

**Consequences:**
- Advantage: services deploy and migrate independently.
- Trade-off: referential integrity is the application's responsibility; reconciliation job recommended.

---

## [DEC-004] Consent is checked per sample, not per account

**Date:** 2026-10-04
**Status:** Active (v8 data model)

**Context:**
Samples come from deliberate capture sessions run by a linguist, with a signed authorization per person and document version.

**Decision:**
`consent_granted_at` and `consent_terms_version` are required in the Mongo validator. The capture session is the unit of
discard. `iam.ConsentRevoked` triggers `DiscardCaptureSessions`.

**Consequences:**
- Advantage: a withdrawn authorization is enforceable in one operation.
- Trade-off: contradicts INV-010 (anonymous pseudonym) of the domain model. Open item ALIGN-02; the team must choose one.

---

## [DEC-005] Exactly one active model, activated in one transaction

**Date:** 2026-10-04
**Status:** Active

**Decision:**
Publishing a model deactivates the previous one in the same transaction. `uq_single_active_model` (partial unique index) guarantees
it once the constraints migration exists. `RecognitionModelPublished` carries `previousModelId` so that a rollback is a decision, not an investigation.

---

## [DEC-006] The modules `translations` and `ia` are merged without rewriting their use cases

**Date:** 2026-10-04
**Status:** Active

**Context:**
Both are hexagonal today and live in the same backend.

**Decision:**
They become two modules of one service (`translations`, `templates`/`ia`). The routes change prefix: `/api/sign-templates`
moves to `/api/recognition/...`; the mobile app is updated in the same release or the gateway keeps an alias during the transition.
The `Translation` entity is migrated from free text (`input_text`, `output_text`, `type`) to the model of `06-data` in a separate step.

**Consequences:**
- Trade-off: two data models coexist until the app sends `translation_signs`.

---

## Correlations

- Data model → [data-model.md](./data-model.md)
- Consent and data lifecycle → `06-data/data-lifecycle.md`
- Open items → `06-data/open-items.md` (ALIGN-01, ALIGN-02, ALIGN-03, ALIGN-07, GAP-06)
