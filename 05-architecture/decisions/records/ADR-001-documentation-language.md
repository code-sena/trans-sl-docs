# ADR-001: Documentation Language

## Status

* Accepted

## Date

2026-09-08

## Context

The Traduce Señas project requires technical documentation that allows the architecture, requirements, design decisions, and different system components to be clearly described.

The project uses documentation related to architecture, requirements, design patterns, security, and evolution toward microservices.

To maintain consistent documentation, it is necessary to establish a primary language for the technical documents.

## Decision

**English is established as the primary language for the technical and architectural documentation of the Traduce Señas project**.

File names, technical titles, pattern names, architectural component names, and terms related to code will follow the technical conventions used in the project.

The documentation may include explanations in Spanish when necessary for academic documents or material specifically intended for users or team members who require this language.

## Alternatives considered

### Alternative 1 — Use Spanish as the primary language

Use Spanish for all technical documentation.

**Advantages:**

* Facilitates reading for Spanish-speaking project members.
* Is appropriate for academic explanations within the SENA context.

**Disadvantages:**

* May generate inconsistencies with technical terminology commonly used in software development.
* Some architectural concepts and tools primarily use documentation and terminology in English.

### Alternative 2 — Use English as the primary language

Use English for technical and architectural documentation.

**Advantages:**

* Maintains standard technical terminology.
* Facilitates alignment with official documentation for frameworks, tools, and patterns.
* Allows the documentation to be more easily reused in international technical contexts.

**Disadvantages:**

* May require greater reading effort for team members who primarily speak Spanish.

### Alternative 3 — Use both languages without a defined rule

Allow each document to be written interchangeably in Spanish or English.

**Advantages:**

* Greater freedom for authors.
* Allows the use of the language that is most comfortable for each document.

**Disadvantages:**

* May generate inconsistency in the documentation.
* Makes it difficult to maintain a uniform documentation structure.

## Justification

English is selected as the primary language because the documentation mainly corresponds to technical and architectural aspects of the project.

This decision allows terminology consistent with concepts such as:

* Architecture Decision Record (ADR).
* Design Patterns.
* Hexagonal Architecture.
* Backend.
* Frontend.
* API.
* Database.
* Authentication.
* Authorization.
* Microservices.

The decision also allows the project to maintain a structure compatible with the microservices governance framework used as a reference for the project's documentation.

## Consequences

### Positive

* Greater consistency in technical documentation.
* Terminology aligned with standards and technical resources.
* Facilitates the consultation of external documentation.
* Facilitates future evolution of the project toward a microservices-based architecture.

### Negative

* Some team members may need more time to understand certain documents.
* Academic documents intended exclusively for Spanish-speaking users may require a Spanish version.

## Impact on architecture

This decision mainly affects the project's documentation and does not directly modify the system implementation.

Component names, patterns, architectural decisions, and technical concepts must maintain consistent nomenclature.

## Relationship with other documents

* `overview.md`
* `pattern-guide.md`
* `security-threat-model.md`
* `decisions/_template-adr.md`
* `09-microservices/`

## Review

This decision may be reviewed if the project's academic requirements, team needs, or established conventions for technical documentation change.
