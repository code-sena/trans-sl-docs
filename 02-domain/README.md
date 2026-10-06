# 02 — Problem Domain

> **What is this?** The mental model of the **Traduce Señas** business. It is not technology — it is
> understanding the problem the system solves before writing code. This section comes from
> Domain-Driven Design (DDD).

**Version:** v1.2 · **Last updated:** 2026-09-10 · **Maintainers:** Juan Mauricio Suaza Solórzano, Luis Alejandro Duarte Aldana, Juan Camilo Fierro Esquivel
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
| **System scale** | Microservices: each bounded context is hosted by one of five services (iam, recognition, lexicon, analytics, profile) behind an API Gateway |
| **Database** | Database per service (PostgreSQL; MongoDB for `gesture_samples` in recognition). No foreign keys across services |
| **Event channel** | Asynchronous domain events over RabbitMQ (topic exchange `traduce.events`, routing key `<service>.<event>`) |

> **On scale:** the product owner confirmed on 2026-10-04 that Traduce Señas is a microservices
> architecture. The bounded contexts in this folder map to services as shown in the context map of
> `domain-map.md`. Extraction status: the backend code still has the domain modules `auth`, `users`,
> `translations`, `ia` and `lexicon` under `backend/src/domains/`, being split into those
> services (pending / in progress per service).

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
→ `TranslationProduced`, `ConsentRevoked`, `SignViewed`.

**Bounded Context:** area of the system where a particular model applies and a given term means exactly
one thing.
→ In *Recognition & Translation*, "user" is whoever produces the signs; in *Usage Analytics*, "user" is
an anonymous row in an aggregated metric.

---

## What is here

### `domain-map.md` ⭐
Map of the **eight** bounded contexts of Traduce Señas, their ubiquitous language, how they relate to
each other, and the strategic classification (Core / Supporting / Generic). **It is the file the other
two depend on:** the contexts defined there determine the backend modules, the tables in `06-data/` and
the diagrams in `08-uml/`. Its §6 lists where the model and the database still disagree.

### `entities-and-rules.md` ⭐
Catalog of entities, value objects and aggregates per context, with the lifecycles of the entities that
change state and **the 27 system invariants** (INV-001 to INV-027), each one with its origin in the SRS
and the point where it is enforced. Its summary table now names the table that persists each entity.

### `domain-events.md` ⭐
Catalog of the **40** domain events: what triggers them, what data they carry, who consumes them and
which policies run automatically when they occur.

---

## Traceability: from the SRS to this model

| SRS requirement | Bounded Context | Aggregate | Main event |
|-----------------|-----------------|-----------|------------|
| RF1 User management | Identity & Access | `User` | `UserRegistered` |
| RF2 Site navigation | — | — | — *(not domain: it is UI)* |
| RF3 Sign language translation | **Recognition & Translation** | `TranslationSession` | `TranslationProduced` |
| RF4 Visual notifications | **Notifications** *(a context since v1.1)* | `Notification` | `NotificationDelivered` |
| RF5 Profile management | Profile & Preferences | `UserProfile` | `PreferencesChanged` |
| ERF5.5 Recent translations | Recognition & Translation | `TranslationSession` | `TranslationDeleted` |
| RF6 Usage statistics | Usage Analytics | `UsageReport` *(read model)* | consumes all |
| RF7 Sign language alphabet | **Learning & Lexicon** | `Sign` *(type `LETTER`)* | `SignViewed` |
| RF8 Gamification ⏸ | **Gamification** *(provisional)* | `Achievement` | `AchievementUnlocked` |
| RNF4 Security | Identity & Access | `User` | `AccountLocked` / `AccountBlocked` |
| RNF8 Data protection (Law 1581) | Consent & Personal Data | `ConsentGrant` | `ConsentGranted` / `ConsentRevoked` |
| — Access control | Identity & Access | `Role`, `Permission` | `RoleAssigned` |
| — Change audit | Cross-cutting *(not a context)* | `AuditEntry` | consumes all |
| — Error handling | Cross-cutting *(not a context)* | `ErrorEntry` | — |
| — Password policy | **Identity & Access** *(moved in v1.2)* | `PasswordPolicy` | `PasswordPolicyChanged` |

> The fact that **RF2 produces no domain** is not a gap in the SRS: it is a user interface requirement.
> It is documented in `12-ux-ui/`, not here. Making that distinction is part of the work of this section.
> Note that it still *produces persistence*: each section entry is recorded as a usage event, because
> RF6 needs it. Producing no domain and producing no data are different things.

---

## What changed in v1.2 (2026-09-10)

One reversal, and it is a small one with a clear test behind it: **the password policy is part of
Identity & Access, not a cross-cutting technical service.** §2.9 of `domain-map.md` defines a
cross-cutting service as one that "serves every context equally". Any context writes to `audit_logs`;
exactly one reads `password_policies`. Being *consumed by* one context is the opposite of being
cross-cutting — and not being a bounded context of its own does not make something cross-cutting, it
makes it part of the context that depends on it.

Persistence follows: `identity.password_policies` in model v9, and the `Configuration` table group is
dissolved. Full reasoning in `domain-map.md` §5 and in `06-data/domains/01-identity.md`.

---

## What changed in v1.1 (2026-09-08)

The persistence model (then `traduce_senas_v8.dbml`) grew to eleven table groups while these three documents
still described six contexts. This revision brings them back in sync.

| Change | Where |
|--------|-------|
| **Notifications promoted** from a cross-cutting service to a Supporting bounded context | `domain-map.md` §2, §5 |
| **Learning renamed to Learning & Lexicon** — the alphabet is the subset of the sign catalog where the type is `LETTER` | `domain-map.md` §2 · `entities-and-rules.md` |
| **`Role` and `Permission` become entities** — the role was a value object holding `USER` or `ADMIN` | `entities-and-rules.md` |
| **Gamification** appears as a provisional context, ⏸ pending RF8 | all three |
| **Audit, error log and password policy** documented as cross-cutting services that are deliberately *not* contexts | `domain-map.md` §2.9 |
| Invariants 13 → 27, events 18 → 40 | `entities-and-rules.md`, `domain-events.md` |
| **New §6: where the map and the database disagree** — nine open items | `domain-map.md` §6 |

**Two v1.0 decisions were reversed**, and both are recorded with their reason rather than quietly
edited: Notifications as a non-context, and `ADMIN` as a role value on `User`. Neither original
argument was wrong — their premises expired when the model grew.

**Four invariants are marked ⚠️ because the database contradicts them** (INV-005, INV-007, INV-010 and
the lockout rule). They are left standing rather than rewritten: each was a deliberate decision and
reversing it belongs to the team, not to a documentation pass. The most consequential are:

- **The Core aggregate root has no table.** `TranslationSession` is the centre of the domain model and
  there is no `translation_sessions` table in the database.
- **`TrainingSample` identity.** INV-010 says a sample never carries a user reference; `gesture_samples`
  stores the performer's name on purpose, so a withdrawn authorization can actually be honored. Both
  designs are defensible and they are incompatible.
- **INV-007 has no threshold to read.** `ai_models` stores accuracy but no confidence threshold.

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
