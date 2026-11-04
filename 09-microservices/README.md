# 09 — Microservices

> **What is this?** The individual documentation for each microservice in the system.
> This is the most active section of the repository — it is updated with every significant change.

## Services

Traduce Señas is a microservices architecture: one API gateway and five domain services, each with its own database.

```
services/
├── 01-api-gateway/          :8080  edge: routing, JWT check (when a token is sent), rate limit, CORS
├── 02-iam-service/          :3001  identity, roles and permissions (consent and audit are not implemented)
├── 03-recognition-service/  :3002  translation (core), sign templates, gesture samples (PostgreSQL + MongoDB)
├── 04-lexicon-service/      :3003  sign catalog and media
├── 05-analytics-service/    :3004  usage statistics
└── 06-profile-service/      :3005  preferences, notifications, achievements, daily challenges
```

The full inventory, with events, dependencies and extraction status, is in [`service-catalog.md`](./service-catalog.md).
Services communicate through REST (via the gateway), domain events over RabbitMQ and, in two places, internal HTTP (profile-service reads statistics and administrator ids).

## Structure of each microservice

Each service has its own folder in `services/` with this structure:

```
services/
└── 01-service-name/
    ├── README.md              ← Description, responsibility, how to run it
    ├── data-model.md          ← The service's own data model
    ├── events.md              ← Events it publishes and consumes
    ├── decisions.md           ← Design decisions specific to the service
    ├── runbook.md             ← How to operate the service in production
    └── components/            ← If the service has sub-components
        └── [component]/
            ├── README.md
            └── contract.md
```

**Use `_template/service/` as a starting point for each new service.**

---

## Cross-cutting documents

### `service-catalog.md` ⭐ (Start here)
Registry of all microservices in the system: responsibility, contexts, data, port, events, dependencies and extraction status.
**Update when you add, remove or rename a service, and when an extraction status changes.**

The other cross-cutting documents of the template (`service-boundary-rules.md`, `communication-patterns.md`, `event-catalog.md`, `data-ownership-matrix.md`, `dependency-map.md`, `storage-and-documents.md`, `service-readiness-checklist.md`) are not written yet. Their content for today's system is in `service-catalog.md` (dependency map, data ownership, communication rules), and the events in each service's `events.md`.

---

## Correlations with other sections

| This section is fed by... | And feeds into... |
|---------------------------|-------------------|
| `02-domain/domain-map.md` → bounded contexts | One per context |
| `05-architecture/overview.md` → defined services | README of each service |
| `07-api/contracts/openapi/` → service contract | `services/[service]/` implements it |
| `06-data/models.md` → data model | `services/[service]/data-model.md` |
| `services/[service]/runbook.md` | `13-operations/` consolidates them |

---

## Service numbering

The numbers only order the folders: the gateway is `01`, and `02` (iam) is the service that issues the tokens the others verify.
