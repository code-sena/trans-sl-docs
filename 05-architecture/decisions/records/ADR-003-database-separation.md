# ADR-003: Database Separation

## Status

* Accepted
* Extended by [ADR-004](ADR-004-microservices-architecture.md) and [ADR-008](ADR-008-database-per-service.md) (one database per service)

## Date

2026-09-08

## Update 2026-10-26

This ADR was written when the backend was one process. The decision still holds (PostgreSQL for structured data, MongoDB for variable recognition data, no foreign keys between them), but some details no longer describe the system:

* There is no single backend coordinating both engines. Each service owns its own PostgreSQL database, and only `recognition-service` uses MongoDB ([ADR-008](ADR-008-database-per-service.md)).
* The MongoDB collection is `gesture_samples`, not `movement_samples`. It stores the training samples (frames, consent, `recorded_by`, `performed_by`). Inference results, confidence and model versions are not stored in MongoDB: each translation keeps its confidence and source in PostgreSQL (`translations`), and there is no model registry.
* Sign templates, which also hold variable frame data, live in PostgreSQL as `JSONB` (`sign_templates.features`).
* As of 2026-10-26 the app does not send samples to `/api/samples`, so `gesture_samples` receives no data. Whether to connect it, move the samples to PostgreSQL or remove the route and MongoDB is the open decision H-06; the outcome must update this ADR and ADR-008.

## Context

Traduce Señas handles different types of information that have different characteristics and storage requirements.

The system requires storing structured information related to users, authentication, roles, permissions, preferences, history, and translations. It also requires handling information related to artificial intelligence processing and sign recognition, such as movements, landmarks, coordinates, sequences, training data, and inference results.

For this reason, it is necessary to establish a persistence strategy that allows the most appropriate database engine to be used for each type of information.

## Decision

It is decided to use a persistence strategy based on **two database engines**:

* **PostgreSQL** for the structured and relational information of the system.
* **MongoDB** for data related to artificial intelligence, sign recognition, and variable data structures.

The two databases will not have a relationship through foreign keys.

The backend will be responsible for coordinating access to both databases and will use logical identifiers, such as `userId`, when it is necessary to relate information stored in different engines.

## Information Distribution

### PostgreSQL

PostgreSQL will be used to store structured information such as:

* Users.
* Credentials.
* Roles.
* Permissions.
* Preferences.
* Translation history.
* Translations.
* Auditing.
* Administrative information.

### MongoDB

MongoDB will be used to store information related to artificial intelligence processing, such as:

* Movement data.
* Landmarks.
* X, Y, and Z coordinates.
* Movement sequences.
* Frames.
* Training data.
* Validation data.
* Test data.
* Inference results.
* Confidence level.
* Metadata.
* Model versions.

## Example of Logical Relationship

The relationship between information stored in PostgreSQL and MongoDB may be established through logical identifiers.

```text
PostgreSQL
┌──────────────────────┐
│ users                │
├──────────────────────┤
│ id                   │
│ full_name            │
│ email                │
└──────────┬───────────┘
           │
           │ userId
           │
           ▼
MongoDB
┌────────────────────────────┐
│ movement_samples           │
├────────────────────────────┤
│ userId                     │
│ landmarks                  │
│ sequence                   │
│ confidence                 │
│ model_version              │
└────────────────────────────┘
```

MongoDB will not have a foreign key to PostgreSQL.

The backend will be responsible for validating and coordinating these logical references.

## Alternatives Considered

### Alternative 1 — Use Only PostgreSQL

Store all system information in PostgreSQL.

**Advantages:**

* A single database engine.
* Centralized administration.
* Referential integrity through foreign keys.
* Fewer technologies to maintain.

**Disadvantages:**

* Artificial intelligence data may have variable structures and large amounts of information.
* Movement, landmark, and sequence structures may require less rigid models.
* Flexibility for storing different structures related to recognition data is limited.

### Alternative 2 — Use Only MongoDB

Store all system information in MongoDB.

**Advantages:**

* Flexibility in document structure.
* Suitable for variable data related to artificial intelligence.
* Allows complex movement and sequence structures to be handled.

**Disadvantages:**

* It is not the primary option for the highly structured and relational information of the system.
* Managing relationships between users, roles, permissions, and other entities may be less suitable for the project's needs.

### Alternative 3 — Use PostgreSQL and MongoDB

Use PostgreSQL for relational information and MongoDB for data related to artificial intelligence.

**Advantages:**

* Each type of information uses a system appropriate to its characteristics.
* PostgreSQL provides a relational structure for system data.
* MongoDB provides flexibility for artificial intelligence data.
* Allows storage responsibilities to be separated.
* Facilitates the future evolution of the architecture.

**Disadvantages:**

* Requires managing two database engines.
* The backend must coordinate access to both databases.
* Relationships between information from different engines must be managed through logical identifiers.

## Justification

The use of PostgreSQL and MongoDB is selected because the data handled by Traduce Señas has different characteristics.

PostgreSQL is suitable for the structured information of the system, while MongoDB allows the data generated by recognition and artificial intelligence processes to be handled with greater flexibility.

This separation also allows the system's operational data to remain differentiated from the data used for the processing and evolution of recognition models.

## Consequences

### Positive

* Clear separation of storage responsibilities.
* Better adaptation of storage to the type of information.
* Greater flexibility for artificial intelligence data.
* Relational structure for users, roles, permissions, and history.
* Facilitates the future evolution of the system.

### Negative

* Two persistence systems must be managed.
* The backend must manage connections to PostgreSQL and MongoDB.
* There is no referential integrity through foreign keys between both databases.
* Logical identifiers used to relate information must be properly controlled.

## Impact on the Architecture

The decision mainly affects:

* Backend.
* Persistence layer.
* PostgreSQL.
* MongoDB.
* Translation module.
* Artificial intelligence processing.
* Translation history.
* User management.

The general persistence flow will be:

```text
                  Backend
                     │
          ┌──────────┴──────────┐
          │                     │
          ▼                     ▼
     PostgreSQL             MongoDB
          │                     │
          ▼                     ▼
 Structured Data          AI Data
 Users                    Landmarks
 Roles                    Movements
 Permissions              Sequences
 History                  Inferences
 Translations             Metadata
```
