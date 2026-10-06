# Diagram Index

> **What to fill in here:** The registry of all system diagrams.
> Diagrams go in `08-uml/diagrams/source/` as PlantUML or Mermaid files.
> Exported renders go in `08-uml/diagrams/rendered/`.

---

## When to create a diagram?

```
✓ When the flow involves 3+ services or actors
✓ When the architecture needs to be communicated to a non-technical stakeholder
✓ When data modeling is complex (ER diagram)
✓ When a bug took more than 2 hours to understand (retroactive sequence diagram)

✗ For simple 2-element flows — code describes them better
✗ To "document for documentation's sake" — an outdated diagram is worse than none
```

---

## File naming

```
[c4-level]-[descriptive-name].[puml|mmd]

Examples:
  c1-system-context.puml
  c2-container-diagram.puml
  c3-auth-service.puml
  seq-create-order.puml
  erd-orders-service.mmd
  state-order-lifecycle.puml
```

---

## Diagram registry

### Architecture diagrams (C4)

| ID | Name | Type | Tool | Source file | Description |
|----|------|------|------|-------------|-------------|
| C4-01 | System Context | C4 L1 | PlantUML | `source/c1-system-context.puml` | The system and its external actors |
| C4-02 | Container Diagram | C4 L2 | PlantUML | `source/c2-container-diagram.puml` | All services and DBs |
| C4-03 | [Service A] Components | C4 L3 | PlantUML | `source/c3-service-a.puml` | Internal components of the service |

### Sequence diagrams

| ID | Name | Tool | Source file | Description |
|----|------|------|-------------|-------------|
| SEQ-01 | Login flow | PlantUML | `source/seq-login.puml` | Registration → Login → JWT |
| SEQ-02 | [Main flow] | PlantUML | `source/seq-[name].puml` | [Description] |
| SEQ-03 | [Error flow] | PlantUML | `source/seq-[name]-error.puml` | [Error scenario] |

### State diagrams

| ID | Name | Tool | Source file | Description |
|----|------|------|-------------|-------------|
| ST-01 | Order lifecycle | PlantUML | `source/state-order.puml` | Order states and transitions |

### ER diagrams (data)

| ID | Name | Tool | Source file | Service |
|----|------|------|-------------|---------|
| ERD-01 | Orders DB | Mermaid | `source/erd-orders.mmd` | order-service |
| ERD-02 | Auth DB | Mermaid | `source/erd-auth.mmd` | auth-service |

### Class diagrams (Traduce Señas)

All sources are based on `backendTS@497feef` (`origin/develop`, 2026-10-05; generated 2026-10-06). They replace the previous set based on `backendTS@c142c80`. Renders: `diagrams/exports/<name>.svg`. Review, changes and comparison with the original team diagram: [`class-diagram-review.md`](class-diagram-review.md).

| ID | Name | Tool | Source file | Description |
|----|------|------|-------------|-------------|
| CL-01 | Backend classes by pattern (main) | PlantUML | [`source/class-backend-patterns.puml`](diagrams/source/class-backend-patterns.puml) | Same package structure as the original diagram (Singleton, Factory Method, Observer, Command, Domain). `<<implementado>>` = exists in code; `<<propuesta>>` = pattern with no code yet |
| CL-02 | Backend overview | PlantUML | [`source/class-backend-overview.puml`](diagrams/source/class-backend-overview.puml) | One package per domain (iam, auth, users, translations, analytics, ia), shared, and the lexicon-service microservice; names only |
| CL-03 | Domain auth | PlantUML | [`source/class-backend-auth.puml`](diagrams/source/class-backend-auth.puml) | Entities, domain service, errors, ports, use cases, adapters, routes and module of auth |
| CL-04 | Domain users | PlantUML | [`source/class-backend-users.puml`](diagrams/source/class-backend-users.puml) | Same detail level for users (profile, stats, password change, account deletion) |
| CL-05 | Domain translations | PlantUML | [`source/class-backend-translations.puml`](diagrams/source/class-backend-translations.puml) | Same detail level for translations (history and stats) |
| CL-06 | Domain ia | PlantUML | [`source/class-backend-ia.puml`](diagrams/source/class-backend-ia.puml) | Same detail level for sign templates (DTW) |
| CL-07 | Shared | PlantUML | [`source/class-backend-shared.puml`](diagrams/source/class-backend-shared.puml) | TokenProvider, JWT adapter, auth middleware, role checker, error handler, pg pool, config |
| CL-08 | Planned entities | PlantUML | [`source/class-backend-planned.puml`](diagrams/source/class-backend-planned.puml) | All `<<planned>>`: a selection of 6 DBML tables equivalent to elements of the old diagram that still have no code; the rest of the DBML (29 tables) is not drawn |
| CL-09 | Domain iam | PlantUML | [`source/class-backend-iam.puml`](diagrams/source/class-backend-iam.puml) | Roles, permissions and their rules (RBAC) |
| CL-10 | Domain analytics | PlantUML | [`source/class-backend-analytics.puml`](diagrams/source/class-backend-analytics.puml) | Usage events and the section report |
| CL-11 | lexicon-service | PlantUML | [`source/class-lexicon-service.puml`](diagrams/source/class-lexicon-service.puml) | Microservice `services/lexicon-service`: sign catalog, categories, resources, events (RabbitMQ) and its own security |

---

## Diagram templates

### C4 L1 — Context (PlantUML)

```plantuml
@startuml C4-Context
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Context.puml

title System Context — [System Name]

Person(user, "User", "Description of the user")
Person_Ext(admin, "Administrator", "Manages the system")

System(system, "[System Name]", "Description of what it does")

System_Ext(externalSystem, "[External System]", "Description of the external system")

Rel(user, system, "Uses", "HTTPS")
Rel(admin, system, "Administers", "HTTPS")
Rel(system, externalSystem, "Sends data to", "REST API")

@enduml
```

### Sequence diagram (PlantUML)

```plantuml
@startuml seq-example

title Flow: [Flow name]

actor "User" as U
participant "API Gateway" as GW
participant "Auth Service" as AUTH
participant "Service A" as SA
database "Service A DB" as DBA

U -> GW: POST /resource\n{payload}
GW -> AUTH: Validate JWT
AUTH --> GW: 200 OK {claims}
GW -> SA: POST /resource (with claims)
SA -> DBA: INSERT ...
DBA --> SA: OK
SA --> GW: 201 Created {id}
GW --> U: 201 Created {id}

@enduml
```

### State diagram (PlantUML)

```plantuml
@startuml state-example

title Lifecycle: [Resource name]

[*] --> DRAFT : create()

DRAFT --> ACTIVE : publish()
DRAFT --> CANCELLED : cancel()

ACTIVE --> INACTIVE : suspend()
ACTIVE --> CANCELLED : cancel()

INACTIVE --> ACTIVE : reactivate()

CANCELLED --> [*]

@enduml
```

### ER diagram (Mermaid)

```mermaid
erDiagram
    ENTITY_A ||--o{ ENTITY_B : "has"
    ENTITY_A {
        uuid id PK
        varchar name
        timestamptz created_at
    }
    ENTITY_B {
        uuid id PK
        uuid entity_a_id FK
        decimal value
    }
```

---

## Tools and rendering

| Tool | For what | How to use |
|------|---------|------------|
| PlantUML | C4, sequence, state, class diagrams | `plantuml -tsvg file.puml` |
| Mermaid | Simple diagrams in Markdown | Native support on GitHub and GitLab |
| draw.io (diagrams.net) | Complex visual diagrams | Export as XML + image |
| Structurizr | C4 model with DSL | For projects that adopt the C4 DSL |

**Rendering pipeline:**
```bash
# Render all PlantUML diagrams
find 08-uml/diagrams/source -name "*.puml" -exec plantuml -tsvg -o ../rendered {} \;

# Or with Docker (without installing PlantUML locally)
docker run --rm -v $(pwd):/data ghcr.io/plantuml/plantuml:latest \
  -tsvg -o /data/08-uml/diagrams/rendered /data/08-uml/diagrams/source/*.puml
```

---

## Correlations

- Architecture view → `05-architecture/overview.md`
- Domain bounded contexts → `02-domain/domain-map.md`
- ER models per service → `09-microservices/services/NN/data-model.md`
