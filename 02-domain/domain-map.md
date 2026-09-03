# Domain Map — Bounded Contexts of Traduce Señas

> The domain map is the central DDD artifact. It defines the system's boundaries and how they relate to
> each other. This map was built from the project SRS (IEEE 830) and from a team Event Storming session.

**Version:** v1.0 · **Last updated:** 2026-08-31

---

## How it was built: Event Storming

**Event Storming** is a collaborative workshop for modeling the domain before writing code.
It lasts 2–4 hours with the whole team.

**Materials:** a board (Miro / FigJam or a physical wall), 4-color sticky notes, markers.

**Standard colors:**

| Color | Represents | Example in Traduce Señas |
|-------|-----------|--------------------------|
| 🟠 Orange | **Domain events** (something that happened, past tense) | `TranslationProduced`, `ConsentRevoked` |
| 🔵 Blue | **Commands** (action that triggers the event) | `StartTranslationSession`, `RevokeConsent` |
| 🟡 Yellow | **Actors** (who executes the command) | `End user`, `Administrator` |
| 🩷 Pink | **External systems** or integration points | Google OAuth, Facebook Login, SMTP service, inference engine |

**Session steps:**

1. (30 min) Post every event that occurs in the business, in chronological order
2. (30 min) Identify which command or actor triggers each event
3. (45 min) Group related events — each group is a candidate Bounded Context
4. (30 min) Draw the relationships between contexts (who depends on whom)
5. (30 min) Discuss the resulting map and agree on names

**Result:** identified events → `domain-events.md`; entities and rules → `entities-and-rules.md`;
contexts and their map → this document.

---

## 1. Domain overview

> Written without technical terms: a non-programmer must be able to read it.

A deaf person and a hearing person are face to face and share no language. The deaf person signs in
front of the phone camera; the application recognizes the sign and delivers it as text on the screen or
as audio through the speaker. That is the whole business: **turning a gesture into something the other
person can understand, without an interpreter present.**

Around that fact the system does four more things: it identifies who is using the application so it can
keep their history; it teaches the Colombian Sign Language alphabet to anyone who wants to learn it; it
shows the administrator how the application is being used; and it asks for and honors the user's
authorization before keeping any sample of their video, because their face and hands are personal data.

---

## 2. Identified Bounded Contexts

A **Bounded Context** is the explicit boundary within which a domain model has consistent meaning and a
given term means exactly one thing. Each context has its own Ubiquitous Language.

> **From eight candidates down to six.** The first draft had eight contexts, one per SRS functional
> requirement. Two were merged, and the rationale is in §5:
> **Translation History** was absorbed into *Recognition & Translation* (history is nothing more than
> the translations already produced: same model, same data owner), and
> **Notifications** stopped being a context and became a cross-cutting service, because it has no
> language of its own and no business rules: it only displays on screen what other contexts decide.

---

### Bounded Context: Recognition & Translation ⭐ CORE

| Field | Value |
|-------|-------|
| **Name** | `TranslationContext` |
| **Responsibility** | Capture the video, recognize the sign, produce the translation as text or audio, and keep each user's history of what was translated |
| **Owner** | Juan Mauricio Suaza Solórzano *(proposed assignment)* |
| **Module(s)** | `backend/src/modules/translation`, `mobile/src/features/translation` |
| **Persistence** | `translation` schema (sessions, translations, model versions) |
| **SRS requirements** | RF3, ERF3.1, ERF3.2, ERF5.5, RNF1 |

**Ubiquitous Language of this context:**

| Term | Meaning HERE | Different in another context? |
|------|--------------|-------------------------------|
| **Sign** | Hand configuration and movement the model tries to recognize | No |
| **Gloss** | Written label of a sign, uppercase and uninflected (`HOUSE`, `THANK-YOU`) | No — it is the technical term used by LSC interpreters |
| **Translation** | Result delivered to the user: text and, optionally, audio | Yes — in Analytics it is just a counter |
| **Confidence** | The model's certainty about the recognized sign, between 0.0 and 1.0 | No |
| **Translation session** | Continuous period with the camera active, from turning translation mode on until turning it off | No |
| **History** | Set of translations already produced and not deleted by their owner | Yes — the SRS calls it "Recent Translations" in the UI |
| **User** | Whoever produces the signs in front of the camera | Yes — in Identity it is an account holder; in Analytics, an anonymous row |

---

### Bounded Context: Identity & Access

| Field | Value |
|-------|-------|
| **Name** | `IdentityContext` |
| **Responsibility** | Account lifecycle: registration, native and external-provider authentication, password recovery, security lockout and roles |
| **Owner** | Luis Alejandro Duarte Aldana *(proposed assignment)* |
| **Module(s)** | `backend/src/modules/identity`, `mobile/src/features/auth` |
| **Persistence** | `identity` schema |
| **SRS requirements** | RF1, ERF1.1, ERF1.2, ERF1.3, RNF4 |

| Term | Meaning HERE | Different in another context? |
|------|--------------|-------------------------------|
| **User** (`User`) | Account holder, with credentials and a role | Yes — see above |
| **Credential** | Email + password owned by the application | No |
| **External provider** | Google or Facebook linked to the same account | No |
| **Role** | `USER` or `ADMIN`; determines access to the statistics module | No |

---

### Bounded Context: Consent & Personal Data

| Field | Value |
|-------|-------|
| **Name** | `ConsentContext` |
| **Responsibility** | Granting, validity and revocation of the data-processing authorization; data deletion on request; anonymization of the samples kept for training |
| **Owner** | Luis Alejandro Duarte Aldana *(proposed assignment)* |
| **Module(s)** | `backend/src/modules/consent` |
| **Persistence** | `consent` schema — anonymized samples are stored **with no reference to the user** |
| **SRS requirements** | RNF8 (Colombian Law 1581 of 2012, Decree 1377 of 2013) |

| Term | Meaning HERE | Different in another context? |
|------|--------------|-------------------------------|
| **Consent grant** (`ConsentGrant`) | Express, timestamped, provable permission to keep samples | No |
| **Sample** (`TrainingSample`) | Video fragment or hand-landmark sequence kept to train the model | Yes — in the Core it is only the transient input of recognition |
| **Data subject** | The person who owns the data, in the sense of Law 1581 | Yes — Identity calls them "user" |
| **Revocation** | Act by which the data subject withdraws their authorization; irreversible for that grant | No |

> **Why this is its own context and not a boolean field on `User`:** the authorization has a lifecycle,
> a provable timestamp, an associated policy version and consequences over data that already exists.
> That is an aggregate, not a checkbox.

---

### Bounded Context: Profile & Preferences

| Field | Value |
|-------|-------|
| **Name** | `ProfileContext` |
| **Responsibility** | Visible profile data and interface preferences: light/dark theme and language |
| **Owner** | Juan Camilo Fierro Esquivel *(proposed assignment)* |
| **Module(s)** | `backend/src/modules/profile`, `mobile/src/features/profile` |
| **Persistence** | `profile` schema |
| **SRS requirements** | RF5, ERF5.1, ERF5.2, ERF5.3, ERF5.4 |

| Term | Meaning HERE | Different in another context? |
|------|--------------|-------------------------------|
| **Profile** (`UserProfile`) | What the user sees and edits about themselves | No |
| **Preferences** | Interface theme and language | No |
| **Language** | Language of the application's texts (`es-CO`, `en-US`) | Yes — in the Core, "language" means LSC, which is the input language, not the interface one |

> **Watch that last term:** it is the textbook case of one word with two meanings. That is why
> "interface language" and "sign language" are never named the same way in the code.
> Changing the password (ERF5.3) is shown on the profile screen, but **the operation belongs to
> Identity & Access**: the profile only invokes it.

---

### Bounded Context: Learning (LSC Alphabet)

| Field | Value |
|-------|-------|
| **Name** | `LearningContext` |
| **Responsibility** | Catalog of the LSC fingerspelling alphabet with visual resources verified by an interpreter |
| **Owner** | Juan Camilo Fierro Esquivel *(proposed assignment)* |
| **Module(s)** | `backend/src/modules/learning`, `mobile/src/features/alphabet` |
| **Persistence** | `learning` schema + resources in file storage |
| **SRS requirements** | RF7, ERF7.1 |

| Term | Meaning HERE | Different in another context? |
|------|--------------|-------------------------------|
| **Letter** (`AlphabetLetter`) | One of the 27 letters of the LSC fingerspelling alphabet (A–Z plus Ñ) | No |
| **Visual resource** | 2D image or animation representing the letter | No |
| **Verification** | Approval by a certified interpreter of the accuracy of the representation | No |

---

### Bounded Context: Usage Analytics

| Field | Value |
|-------|-------|
| **Name** | `AnalyticsContext` |
| **Responsibility** | Build, from the events of the other contexts, the usage metrics the administrator consults |
| **Owner** | Juan Mauricio Suaza Solórzano *(proposed assignment)* |
| **Module(s)** | `backend/src/modules/analytics` |
| **Persistence** | `analytics` schema — **read model**, not a source of truth |
| **SRS requirements** | RF6, ERF6.1 |

| Term | Meaning HERE | Different in another context? |
|------|--------------|-------------------------------|
| **Usage report** (`UsageReport`) | Set of aggregated metrics over a date range | No |
| **Visited section** | Application module a user entered | No |
| **User** | Aggregated row, with no direct identification | Yes — here it is never an identifiable person |

> Analytics **owns no data**: everything it shows is rebuilt from events. If its whole schema is dropped,
> it can be regenerated. That is the proof that it is a read model.

---

## 3. Context Map

```
                          ┌───────────────────────────┐
                          │  Identity & Access        │
                          │  (Generic · RF1)          │
                          └────────────┬──────────────┘
                                       │ U → D  (userId, valid session)
                                       ▼
┌──────────────────────┐   U → D   ┌───────────────────────────────┐   events    ┌────────────────────┐
│ Consent & Personal   │──────────▶│  RECOGNITION & TRANSLATION    │────────────▶│ Usage Analytics    │
│ Data                 │  may I    │  ★ CORE DOMAIN · RF3, RF5.5   │             │ (Supporting · RF6) │
│ (Supporting · RNF8)  │  store?   │                               │             └────────────────────┘
└──────────────────────┘           └───────────────┬───────────────┘                       ▲
                                                   │ events                                │ events
                                                   ▼                                       │
                          ┌───────────────────────────┐          ┌────────────────────────┴───┐
                          │  Profile & Preferences    │          │  Learning (Alphabet)       │
                          │  (Supporting · RF5)       │          │  (Supporting · RF7)        │
                          └───────────────────────────┘          └────────────────────────────┘

Cross-cutting service: on-screen Notifications (RF4) — consumes events from every context.
Shared Kernel: the `UserId` value object is shared by Identity, Consent, Profile and Translation.
```

### Context relationship types

| Type | Symbol | Description |
|------|--------|-------------|
| **Upstream → Downstream** | `U → D` | U provides, D consumes. D depends on U. |
| **Shared Kernel** | `SK` | Two contexts share part of the model |
| **Customer/Supplier** | `C/S` | The supplier negotiates with the customer |
| **Conformist** | `CONF` | D adopts U's model without negotiating |
| **Anti-Corruption Layer** | `ACL` | D translates U's model to protect itself |
| **Open Host Service** | `OHS` | U publishes a stable protocol |
| **Published Language** | `PL` | Explicit shared language (OpenAPI, event schema) |

### Relationships table

| Context A | Relationship | Context B | Channel | Contract |
|-----------|--------------|-----------|---------|----------|
| Identity & Access | U → D | Recognition & Translation | In-process call | `UserId` + authenticated session |
| Identity & Access | SK | Profile, Consent, Translation | — | `UserId` value object |
| Consent & Personal Data | U → D | Recognition & Translation | In-process call | `isConsentActive(userId)` |
| Recognition & Translation | U → D | Usage Analytics | In-process event | `TranslationProduced`, `TranslationSessionStarted` |
| Learning | U → D | Usage Analytics | In-process event | `AlphabetLetterViewed` |
| Identity & Access | U → D | Usage Analytics | In-process event | `UserRegistered`, `UserSignedIn` |
| Identity & Access | ACL | Google OAuth / Facebook Login | HTTPS (OAuth 2.0) | Adapter translating the external profile into `User` |
| Recognition & Translation | ACL | Inference engine (computer vision) | HTTPS / device SDK | `SignRecognitionPort` adapter |

> **Both anti-corruption layers are deliberate.** Neither Google's model nor the raw output of the
> inference engine (tensors, probability arrays, hand landmarks) should enter the domain as they come:
> they enter translated into `User` and into `Gloss` + `Confidence`. This is what allows swapping the
> recognition engine without touching a single business rule.

---

## 4. Core Domain, Supporting, Generic

| Type | Description | Investment |
|------|-------------|-----------|
| **Core Domain** | Where the project's advantage lies. What differentiates it. | MAXIMUM — build it |
| **Supporting Subdomain** | Necessary for the core, but not differentiating. | MEDIUM |
| **Generic Subdomain** | Commodity. An off-the-shelf solution exists. | MINIMUM — use a library or service |

### Classification of the Traduce Señas contexts

| Bounded Context | Type | Justification |
|-----------------|------|---------------|
| **Recognition & Translation** | **Core** | The only part of the project that cannot be bought ready-made. The entire reason Traduce Señas exists — recognizing an LSC sign and delivering it as text or audio in under a second — lives here. This is where the team's maximum effort goes. |
| Consent & Personal Data | Critical supporting | It does not differentiate the product, but failing it makes the product unviable: Law 1581 is not optional and the data being processed is biometric. Not delegated. |
| Profile & Preferences | Supporting | Necessary for the experience (theme, language, visible history), but no user picks the app for its profile screen. |
| Learning (LSC Alphabet) | Supporting | Delivers real educational value and reinforces the inclusive purpose of the project, but it is catalogued content, not an algorithm. |
| Usage Analytics | Supporting | Serves the administrator, not the end user. Solved with simple aggregations over events. |
| Identity & Access | **Generic** | Registration, login, Google/Facebook OAuth and recovery email are solved problems. Use an existing solution (Firebase Auth or Passport + JWT); do not write your own cryptography. |
| Notifications (cross-cutting) | **Generic** | On-screen alerts: a UI component, not business logic. |

> **Practical consequence of this table:** if the schedule tightens, cut Analytics and Learning before
> the Core, and never cut Consent.

---

## 5. Modeling decisions

### How these decisions were made

- **Event Storming session:** [date] · participants: Mauricio, Alejandro, Camilo
- **Tool:** [Miro / FigJam / physical whiteboard]
- **Input:** project SRS (IEEE 830), sections 1.6 (scope), 3.2 (functional) and 3.3 (non-functional)
- **Map iterations:** v1 — 8 contexts, one per functional requirement · v1.0 — 6 contexts after the two merges

### Key decisions and discarded alternatives

| Decision | Discarded alternative | Reason |
|----------|-----------------------|--------|
| History inside *Recognition & Translation* | A separate "Translation History" context | History is the same model already produced; splitting it would duplicate `Translation` and force syncing two sources of truth for nothing |
| Notifications as a cross-cutting service | A "Notifications" context | It has no ubiquitous language of its own and not a single business rule: it only presents what others decide |
| Consent as its own context | An `acceptedTerms: boolean` field on `User` | The authorization has a lifecycle, a provable timestamp, a policy version and retroactive effects over data already stored (RNF8) |
| Analytics as a read model | Analytics with its own master tables | Everything it shows can be rebuilt from events; not owning data prevents metrics and reality from drifting apart |
| Bounded contexts as modules of a monolith | Real microservices | Three developers, one mobile app and one Express backend. Boundaries are documented as logical so they can be extracted later without redoing the model |
| `ADMIN` as a role on `User` | A separate `Administrator` entity | An administrator uses the application exactly like any user and additionally sees statistics; there are no distinct attributes justifying another entity |

### Open decisions

- **Where inference runs** (on the device or on the server). It directly affects the
  `TranslationSession` aggregate and RNF1 (< 1 s per sign). Until it is decided, the domain is modeled
  against the `SignRecognitionPort` port and not against an implementation.
- **Confidence threshold** below which a recognition is not presented as a confirmed translation
  (INV-007). It must be set by the team with interpreter support, not picked arbitrarily.

---

## 6. How to update this map

1. Before adding a new backend module, verify whether it belongs to an existing context.
2. If a context's ubiquitous language starts having terms with two meanings, consider splitting it.
3. Repeat the Event Storming whenever the domain changes significantly — especially if reverse
   translation or 3D modeling of the alphabet enters the scope.
4. This map must stay synchronized with the system-level C4 diagram in `05-architecture/overview.md`.

> **Correlation:** the bounded contexts in this document → backend modules in
> `09-microservices/service-catalog.md` → C4 diagrams in `08-uml/` →
> separation decisions in `05-architecture/decisions/`.
