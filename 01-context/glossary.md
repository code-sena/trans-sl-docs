# Project Glossary

> **Instructions:** Define here all technical and business terms used in the project.
> This is the official dictionary — if there is ambiguity, this document wins.
> Add terms throughout the project, not only at the start.

---

## How to use this glossary

1. Before using a technical or business term in code, docs, or conversations: look it up here.
2. If it's not there: add it with its definition.
3. If there is disagreement about the definition: discuss it as a team and update this document.

Per [ADR-001](../05-architecture/decisions/records/ADR-001-documentation-language.md), all
documentation and code are written in English while the business domain is Spanish. The
**Canonical term** column below is therefore binding: it is the exact name to use in classes,
variables, database columns and API fields. The **Spanish term** column records the word the
domain actually uses, so the translation is decided once, here, and never re-invented in code.

---

## Domain terms

| Spanish term | Canonical term (code) | Definition | Notes / Terms to AVOID |
|--------------|----------------------|------------|------------------------|
| Seña | `Sign` | Minimal meaningful unit of a sign language, formed by hand shape, movement, location and, where relevant, facial expression | Not "gesture": a gesture carries no fixed linguistic meaning |
| Lengua de Señas Colombiana | `ColombianSignLanguage` / `LSC` | The natural language of the Colombian Deaf community. It is a full language, not a signed transcription of Spanish | Avoid "lenguaje de señas" and "sign language" without a country: sign languages are not universal |
| Persona sorda | `DeafUser` | Person who communicates primarily in LSC and is a primary user of the system | Avoid "sordomudo" / "deaf-mute": inaccurate and considered offensive |
| Oyente | `HearingUser` | Person who does not know LSC and uses the system to understand a signer | |
| Intérprete | `Interpreter` | Certified LSC professional. In this project they validate translations and label training data; the system does not replace them | Avoid "translator": interpretation is live, translation is on recorded material |
| Traducción | `Translation` | One completed sign → text/speech conversion, stored with its timestamp, its result and the user who produced it | |
| Historial de traducciones | `TranslationHistory` | Chronological list of the translations of one user, which they can browse and delete entry by entry | |
| Reconocimiento de señas | `SignRecognition` | The process of turning a camera video stream into an identified sign. Runs on the device with MediaPipe and the team's TensorFlow.js model | Avoid "detección": detection only finds a hand, recognition identifies which sign it is |
| Punto de referencia | `Landmark` | Each of the hand or body coordinates that MediaPipe extracts per frame; the input of the recognition model | |
| Léxico de señas | `SignLexicon` | Curated catalogue of the signs the system knows, with their multimedia resources. Its size defines the real coverage of the MVP | |
| Alfabeto en señas | `SignAlphabet` | The learning module that shows each letter of the alphabet in LSC | |
| Dactilología | `Fingerspelling` | Spelling a word letter by letter with the sign alphabet, used for proper names and words with no sign | |
| Glosa | `Gloss` | Written transcription of a sign in capital letters, used to label corpus data. It is a notation, not a translation | |
| Corpus de señas | `SignCorpus` | The labelled video dataset used to train and evaluate recognition | |
| Avatar 3D | `Avatar3D` | Animated 3D model that reproduces signs. **Out of MVP scope** — see `scope.md` | Do not document features that depend on it as available |
| Administrador | `Administrator` | Technical role that monitors accuracy, manages content and consults usage statistics | |
| Recurso multimedia | `MediaResource` | Image or 2D animation attached to an entry of the sign lexicon. What FR7 renders | |
| Notificación visual | `VisualNotification` | On-screen alert. The system's primary channel to the user, because the audience cannot rely on sound | Never pair information with an audio-only cue |
| Dispositivo del usuario | `UserDevice` | A registered device of a user, used as the delivery target for push notifications | |
| Evento de uso | `UsageEvent` | Recorded fact that a user performed a tracked action. Feeds the administrator statistics of FR6 | |
| Estadísticas de uso | `UsageStatistics` | Aggregation of usage events: translation counts, time of use, most visited sections. Administrator only | |
| Token de recuperación | `PasswordResetToken` | Single-use, time-limited token emailed to a user to reset their password (FR1.3) | |
| Autorización de tratamiento | `DataProcessingConsent` | The user's timestamped, revocable permission to retain their video samples for training, per Ley 1581 de 2012 | Not the same as accepting terms of service; it is separate and independently revocable |

---

## Technical terms of the project

> Updated 2026-10-04: the product owner confirmed that TraduceSeñas is a **microservices**
> architecture. The microservice vocabulary below applies to this project. See the Architecture
> section of `overview.md` and `05-architecture/`.

| Term | Definition |
|------|-----------|
| Microservices | The architecture of this system: five domain services (`iam`, `recognition`, `lexicon`, `analytics`, `profile`) behind an API Gateway, each independently deployable, hexagonal inside, with its own database. Client calls go over REST through the gateway; services talk to each other with asynchronous domain events over RabbitMQ |
| Database per service | Each service owns its data store (PostgreSQL databases `iam`, `recognition`, `lexicon`, `analytics`, `profile`; MongoDB `gesture_samples` in recognition). No foreign keys across services: cross-service references are logical IDs such as the `user_id` UUID issued by iam-service |
| API Gateway | The single public entry point (`/api/**`, port 8080). It routes to the owning service, validates the JWT signature, applies rate limiting and CORS. It owns no data |
| Client structure | How the **web/Android client** is organised: by feature rather than by layer. `src/app` holds configuration, providers (context) and routes; `src/feature/*` holds the screens and services of each feature (Translation, Alphabet, History, Profile, Stats, Admin, auth); `src/shared` holds the API client, common components, hooks and types. The earlier description as an "N-layer" client no longer applies |
| Layer boundary violation | Any code that skips or inverts the layer order — a screen that opens a repository directly, or business logic written inside a component. The most common defect this architecture is meant to prevent |
| Singleton | Creational pattern used for `DatabaseConnection` and `ConfiguracionApp`, the two things that must exist exactly once. Duplicating the connection wastes resources and breaks transactions; duplicating the configuration means a language change in one module is invisible to the others |
| Factory Method | Creational pattern used by `TraduccionFactory` and `NotificacionFactory`. Adding a translation type becomes a new subclass instead of another branch in a growing `if`/`switch` |
| Observer | Behavioural pattern built around `GestorEventos`. When a translation is saved, subscribers react independently: `EventoUsoObserver` records the statistic, `NotificacionObserver` decides whether to push. It is what makes visual notifications immediate without polling |
| Command | Behavioural pattern used by `InvokerPerfil`. Each profile change — language, theme, password — is an object that stores the previous state, so it can be undone and leaves a trace of what changed |
| Domain Event | A fact that has already happened, published through `GestorEventos` for observers to react to. Named in the past tense, always |
| Idempotence | Property of an operation that produces the same result when executed more than once. Required of anything the client may retry after a timeout |
| Real time | In this project, an end-to-end response of **5 seconds or less** from capture to displayed result, per NFR1. Any other reading of "real time" must be qualified explicitly |
| Bidirectional | Historical term describing sign ↔ text/speech. **No longer accurate:** the MVP is unidirectional (sign → text/speech) |

### Anti-patterns named in the technical document

> Recorded here because they are the specific mistakes this project has committed to avoiding.

| Anti-pattern | What it looks like here |
|-------------|------------------------|
| God Object | One class or component holding translation, authentication, notifications and UI at once |
| Unnecessary Singleton | Making `Traduccion` a Singleton. Only `DatabaseConnection` and `ConfiguracionApp` qualify |
| Manual polling | Asking the server every few seconds whether a notification arrived, draining battery. Notifications are fetched from `profile-service` when the user opens them |
| Prop drilling | Passing the authenticated user or the active language through five nested components instead of using Context |
| Business logic in the view | Building a translation object inside a screen component instead of delegating to the factory |
| Magic strings for events | Writing event names as loose string literals. Centralise them in one typed constants object |

---

## Acronyms

| Acronym | Meaning |
|---------|---------|
| IAM | Identity and Access Management |
| JWT | JSON Web Token |
| API | Application Programming Interface |
| CRUD | Create, Read, Update, Delete |
| DTO | Data Transfer Object |
| FR | Functional Requirement — written **RF** (Requerimiento Funcional) in the source SRS |
| ERF | Especificación de Requerimiento Funcional — how the SRS numbers each sub-requirement (ERF1.1, ERF3.2…). In English documents write it as the FR number: FR1.1 |
| NFR | Non-Functional Requirement — written **RNF** in the source SRS. NFR1–NFR8 |
| SLO | Service Level Objective |
| SLA | Service Level Agreement |
| ADR | Architecture Decision Record |
| PR | Pull Request |
| DoD | Definition of Done |
| CI/CD | Continuous Integration / Continuous Delivery |
| LSC | Lengua de Señas Colombiana (Colombian Sign Language) |
| SRS | Software Requirements Specification — written **ERS** in the source documents |
| UC | Use Case — written **CU** (Caso de Uso) in the source SRS |
| US | User Story — written **HU** (Historia de Usuario) in the source documents and in `_template-hu.md` |
| MVP | Minimum Viable Product |
| PRD | Product Requirements Document |
| PO | Product Owner |
| SM | Scrum Master |
| UI / UX | User Interface / User Experience |
| DDD | Domain-Driven Design |
| C4 | Context, Container, Component, Code — architecture diagram model |
| TDD | Test-Driven Development |
| OAuth | Open Authorization — the protocol behind social login |
| SENA | Servicio Nacional de Aprendizaje |
| ADSO | Análisis y Desarrollo de Software — the SENA programme this project belongs to |
| GoF | Gang of Four — the design-pattern catalogue this project draws its four patterns from |
| REST | Representational State Transfer — the style of the API between the app and the backend |
| SMTP | Simple Mail Transfer Protocol — how password recovery messages are sent (FR1.3) |
| IEEE 830 | The standard the source SRS is written against |
| Ley 1581 de 2012 | Colombian personal data protection law. Binding on this system — see NFR8 and `scope.md` |
| Decreto 1377 de 2013 | The regulation implementing Ley 1581, covering consent, revocation and deletion |
