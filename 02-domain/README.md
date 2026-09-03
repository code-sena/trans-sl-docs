# 02 — Problem Domain

> **What is this?** The mental model of the **Traduce Señas** business. It is not technology — it is
> understanding the problem the system solves before writing code. This section comes from
> Domain-Driven Design (DDD).

**Last updated:** 2026-08-31 · **Maintainers:** Juan Mauricio Suaza Solórzano, Luis Alejandro Duarte Aldana, Juan Camilo Fierro Esquivel
**Primary source:** Software Requirements Specification (IEEE 830) of the Traduce Señas project.

---

## The domain in one sentence

Traduce Señas solves a communication barrier: **a deaf person signs in front of the phone camera and a
hearing person receives that sign as text or as audio, right away.**
Around that central fact the system manages accounts, keeps a history of what was translated, teaches
the fingerspelling alphabet of Colombian Sign Language (LSC), and gives the administrator usage
statistics — all of it under the user's express authorization to process their data (Colombian Law 1581 of 2012).

---

## Why this section exists

The most costly mistakes in software are not bugs — they are domain misunderstandings.
When the team does not deeply understand the business:

- It creates incorrect abstractions that have to be rewritten
- Names in the code do not match the business's names → permanent confusion
- Module boundaries are drawn in the wrong places

This section captures domain knowledge **before** designing the architecture.

---

## Conventions for this folder

| Convention | Rule |
|-----------|------|
| **Language** | English, for both prose and code |
| **Identifiers** | `PascalCase` for entities and events (`TranslationSession`, `TranslationProduced`), `camelCase` for attributes |
| **Event names** | Always past tense (`UserRegistered`, never `RegisterUser` nor `UserUpdated`) |
| **System scale** | Modular monolith: each bounded context is a **backend module**, not an independent deployment |
| **Database** | A single database, logically separated per context (its own schema or collection) |
| **Event channel** | *In-process* (Node `EventEmitter` + an events table), not a message broker |

> **On scale:** this project is built by three people and ships as a mobile app
> (React Native / Expo) against a Node/Express backend. The bounded contexts in this folder are
> **logical** boundaries, not microservices. They are defined so that, if the system grows, each one can
> be extracted without redoing the model — but documenting today a distributed architecture that does
> not exist would be documenting fiction.

---

## Key concepts you must know

**Entity:** domain object with its own identity.
→ `User` is still the same user even if the email and the password change.

**Value Object:** object with no identity of its own, defined by its attributes and always immutable.
→ `Confidence` (0.87), `Email`, `Gloss`, `Theme`.

**Aggregate:** cluster of entities treated as a unit. Only the aggregate root can be referenced from
outside.
→ `TranslationSession` is the root; its `Translation` objects are only reached through it.

**Domain Event:** something that occurred in the business that other parts of the system must know.
They are facts, stated in past tense.
→ `TranslationProduced`, `ConsentRevoked`, `AlphabetLetterViewed`.

**Bounded Context:** area of the system where a particular model applies and a given term means exactly
one thing.
→ In *Recognition & Translation*, "user" is whoever produces the signs; in *Usage Analytics*, "user" is
an anonymous row in an aggregated metric.

---

## What is here

### `domain-map.md` ⭐
Map of the six bounded contexts of Traduce Señas, their ubiquitous language, how they relate to each
other, and the strategic classification (Core / Supporting / Generic). **It is the file the other two
depend on:** the contexts defined there determine the backend modules, the tables in `06-data/` and the
diagrams in `08-uml/`.

### `entities-and-rules.md` ⭐
Catalog of entities, value objects and aggregates per context, with the lifecycles of the entities that
change state and **the 13 system invariants** (INV-001 to INV-013), each one with its origin in the SRS
and the point where it is enforced.

### `domain-events.md` ⭐
Catalog of the 18 domain events: what triggers them, what data they carry, who consumes them and which
policies run automatically when they occur.

---

## Traceability: from the SRS to this model

| SRS requirement | Bounded Context | Aggregate | Main event |
|-----------------|-----------------|-----------|------------|
| RF1 User management | Identity & Access | `User` | `UserRegistered` |
| RF2 Site navigation | — | — | — *(not domain: it is UI)* |
| RF3 Sign language translation | **Recognition & Translation** | `TranslationSession` | `TranslationProduced` |
| RF4 Visual notifications | Cross-cutting | — | consumes `RecognitionFailed` |
| RF5 Profile management | Profile & Preferences | `UserProfile` | `PreferencesChanged` |
| ERF5.5 Recent translations | Recognition & Translation | `TranslationSession` | `TranslationDeleted` |
| RF6 Usage statistics | Usage Analytics | `UsageReport` *(read model)* | consumes all |
| RF7 Sign language alphabet | Learning | `AlphabetLetter` | `AlphabetLetterViewed` |
| RNF4 Security | Identity & Access | `User` | `AccountLocked` |
| RNF8 Data protection (Law 1581) | Consent & Personal Data | `ConsentGrant` | `ConsentGranted` / `ConsentRevoked` |

> The fact that **RF2 produces no domain** is not a gap in the SRS: it is a user interface requirement.
> It is documented in `12-ux-ui/`, not here. Making that distinction is part of the work of this section.

---

## Model scope (v1)

This model covers only what the SRS declares in scope. **Explicitly out of scope:**

- Reverse translation (from text or voice into signs)
- Three-dimensional avatar representation
- Full coverage of the LSC vocabulary — v1 works on the fingerspelling alphabet and a bounded set of
  frequent signs
- Offline use

If any of these enters the scope, **the context map is reviewed before writing code**: reverse
translation, for example, is not one more function inside the Core context but a new context with its
own language and its own rules.

---

## Correlations with other sections

| This section feeds… | Why |
|---------------------|-----|
| `05-architecture/overview.md` | Bounded contexts → backend modules |
| `06-data/models.md` | Entities and value objects → tables and collections |
| `07-api/contracts/` | Event and command payloads → API contracts |
| `09-microservices/event-catalog.md` | Every domain event is registered there |
| `04-requirements/user-stories.md` | Invariants (INV-001…) → acceptance criteria |
| `08-uml/` | Aggregates → class diagrams; lifecycles → state diagrams |
| `11-quality/` | Invariants → domain unit tests |

---

## How it was built: Event Storming

**Event Storming** is a domain discovery workshop with sticky notes:

1. 🟠 Orange: domain events (past tense)
2. 🔵 Blue: commands (what triggers the event)
3. 🟡 Yellow: actors (who executes the command)
4. 🟣 Purple: policies (automatic reactions)
5. 🩷 Pink: external systems

The session details, participants and decisions are recorded in §5 of `domain-map.md`.
**Every time the domain changes significantly, the workshop is repeated and the three documents are
updated** in this order: map → entities → events.

---

## Questions this section answers

- **What are the main business entities?** → `entities-and-rules.md`
- **What rules can NEVER be violated?** → the 13 invariants in `entities-and-rules.md`
- **What important events occur in the domain?** → `domain-events.md`
- **Where are the natural boundaries of the system?** → `domain-map.md`
- **Where is the real value of the project?** → in the Core Domain: sign recognition. Everything else
  (authentication, emails, light/dark theme, notifications) is generic and is solved with existing
  libraries or services.
