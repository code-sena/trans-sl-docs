# Domain Map — Bounded Contexts of Traduce Señas

> The domain map is the central DDD artifact. It defines the system's boundaries and how they relate to
> each other. This map was built from the project SRS (IEEE 830) and from a team Event Storming session.

**Version:** v1.2 · **Last updated:** 2026-09-10

> **What changed in v1.2.** One reversal: **the password policy is no longer a cross-cutting technical
> service — it belongs to Identity & Access.** §2.9 defines a cross-cutting service as one that "serves
> every context equally"; `password_policies` never met that definition, and the test is spelled out in
> §5. The persistence model moves with it (`identity.password_policies`, model v9), and the file of
> record is now `traduce_senas.dbml` — the version lives in its header so a version bump stops
> invalidating every pointer to it.
>
> **What changed in v1.1.** The persistence model (then `traduce_senas_v8.dbml`) grew from the six contexts
> of v1.0 to eleven table groups. This revision brings the map back in sync with it: **Notifications is
> promoted from a cross-cutting service to a Supporting context**, **Learning expands into Learning &
> Lexicon** because the alphabet turned out to be a subset of a general sign catalog, **Authorization
> becomes an explicit part of Identity & Access** now that roles carry permissions, and **Gamification**
> appears as a provisional context pending the RF8 decision. Two v1.0 decisions are reversed as a
> result; both reversals are recorded in §5 with the reason. §6 lists where the map and the database
> still disagree.

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

> **From eight candidates down to six, and back up to eight.** The first draft had eight contexts, one
> per SRS functional requirement. Two were merged in v1.0: **Translation History** was absorbed into
> *Recognition & Translation* (history is nothing more than the translations already produced: same
> model, same data owner), and **Notifications** stopped being a context because it had no language of
> its own and no business rules.
>
> In v1.1 the count is eight again, for a different reason. Notifications came back — the persistence
> model gave it an administrable type catalog, delivery channels, scheduling, a delivery lifecycle and
> registered devices, which is a language and a set of rules. And Gamification appeared. The full
> rationale for both is in §5; neither was a change of mind about the original argument, both are
> consequences of the model growing.

**The eight contexts:**

| # | Context | Type | Status |
|---|---------|------|--------|
| 1 | Recognition & Translation | ⭐ Core | Active |
| 2 | Identity & Access | Generic | Active |
| 3 | Consent & Personal Data | Critical supporting | Active |
| 4 | Profile & Preferences | Supporting | Active |
| 5 | Learning & Lexicon | Supporting | Active — **expanded in v1.1** |
| 6 | Usage Analytics | Supporting | Active |
| 7 | Notifications | Supporting | **New in v1.1** (was a cross-cutting service) |
| 8 | Gamification | Supporting | ⏸ **Provisional** — pending the RF8 decision |

Plus one set of **cross-cutting technical services** that are deliberately *not* contexts: the audit
trail and the error log. They have tables in the model but no ubiquitous language and no business
vocabulary of their own — they serve every context equally. See §2.9.

> **The password policy used to be listed here and no longer is (v1.2).** It failed the very test this
> paragraph states: it does not serve every context equally, it serves exactly one. See §2.9 and §5.

---

### Bounded Context: Recognition & Translation ⭐ CORE

| Field | Value |
|-------|-------|
| **Name** | `TranslationContext` |
| **Responsibility** | Capture the video, recognize the sign, produce the translation as text or audio, and keep each user's history of what was translated |
| **Owner** | Juan Mauricio Suaza Solórzano *(proposed assignment)* |
| **Service** | `recognition-service` (extraction status: in progress; today the `translations` and `ia` domain modules) |
| **Module(s)** | `backend/src/modules/translation`, `mobile/src/features/translation` |
| **Persistence** | `translation` schema — `translations`, `translation_signs`, `ai_models` |
| **SRS requirements** | RF3, ERF3.1, ERF3.2, ERF5.5, RNF1 |

> ⚠️ **The aggregate root has no table.** `TranslationSession` is the central aggregate of this context
> and of the whole system, but the v8 model has no `translation_sessions` table: `translations` hangs
> directly off `user_id`. `user_sessions` is a *login* session, a different concept in a different
> context. Consequences: there is nowhere to store `outputMode` and `modelVersion` per session, and
> AGGR-INV-003 (consecutive `sequence` within the session) cannot be enforced. See §6, ALIGN-01.

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
| **Service** | `iam-service` (extraction status: pending; today the `auth` and `users` domain modules) |
| **Module(s)** | `backend/src/modules/identity`, `mobile/src/features/auth` |
| **Persistence** | `identity` schema — `users`, `user_auth_providers`, `user_sessions`, `refresh_tokens`, `user_tokens`, `password_policies` *(v1.2)*, `roles`, `permissions`, `user_roles`, `role_permissions` |
| **SRS requirements** | RF1, ERF1.1, ERF1.2, ERF1.3, ERF5.3, RNF4 |

| Term | Meaning HERE | Different in another context? |
|------|--------------|-------------------------------|
| **User** (`User`) | Account holder, with credentials and one or more roles | Yes — see above |
| **Credential** | Email + password owned by the application | No |
| **External provider** | Google or Facebook linked to the same account | No |
| **Role** (`Role`) | Named set of permissions a user holds. A user may hold several | No |
| **Permission** (`Permission`) | A single capability (`stats.read`, `signs.write`), granted through a role, never directly to a user | No |
| **Login session** | Period between a sign-in and its close, with its own IP and duration | **Yes — critical.** In the Core, "session" means a *translation* session, with the camera on. The two are never named the same in code: `LoginSession` vs `TranslationSession` |
| **Lockout level** | How many lockouts the account has accumulated in the current streak; it determines how long the next one lasts | No |

> **Authorization grew into a model of its own (v1.1).** In v1.0 `role` was a value object on `User`
> holding `USER` or `ADMIN`. The v8 model replaced it with four tables: `roles`, `permissions`,
> `user_roles` and `role_permissions`. That is not a bigger enum — it is a different model: a user can
> hold several roles, and a capability can be granted by adding a permission to a role instead of
> inventing a third role. It stays **inside Identity & Access** rather than becoming its own context,
> because it shares the ubiquitous language (`User`, `Role`) and answers the same question: who is this
> person and what may they do. Reversal recorded in §5.

---

### Bounded Context: Consent & Personal Data

| Field | Value |
|-------|-------|
| **Name** | `ConsentContext` |
| **Responsibility** | Granting, validity and revocation of the data-processing authorization; data deletion on request; anonymization of the samples kept for training |
| **Owner** | Luis Alejandro Duarte Aldana *(proposed assignment)* |
| **Service** | `iam-service` owns the consent records; the training samples are stored by `recognition-service` |
| **Module(s)** | `backend/src/modules/consent` |
| **Persistence** | `gesture_samples` — **its own MongoDB collection, owned by recognition-service and separate from the PostgreSQL databases**, with no foreign keys · consent evidence for the account itself lives in `users.terms_accepted_at` / `terms_version` |
| **SRS requirements** | RNF8 (Colombian Law 1581 of 2012, Decree 1377 of 2013) |

| Term | Meaning HERE | Different in another context? |
|------|--------------|-------------------------------|
| **Consent grant** | Express, timestamped, provable permission, recorded together with the version of the document signed | No |
| **Sample** (`TrainingSample`) | Landmark sequence, video fragment or image kept to train the model | Yes — in the Core it is only the transient input of recognition |
| **Capture session** | One recording batch: every take of the same sign recorded in one sitting. It is the unit that gets discarded, not the individual sample | No |
| **Performer** | The person who physically executed the sign. May be an external collaborator with no account in the system | **Yes** — Identity has no concept for a person without an account |
| **Operator** | The administrator or linguist who ran the capture interface | Yes — in Identity they are simply a user with a role |
| **Data subject** | The person who owns the data, in the sense of Law 1581 | Yes — Identity calls them "user" |
| **Revocation** | Act by which the data subject withdraws their authorization; irreversible for that grant | No |
| **Validation** | Approval of a sample by a linguist. Only validated samples feed training | No |

> **Why this is its own context and not a boolean field on `User`:** the authorization has a lifecycle,
> a provable timestamp, an associated policy version and consequences over data that already exists.
> That is an aggregate, not a checkbox.

> ⚠️ **The capture process changed, and it changes this context (v1.1).** v1.0 modeled samples as
> something harvested from end users while they translated — hence `AnonymousSubjectId` and INV-010
> ("a sample never carries a userId"). The v8 model describes a different process: **deliberate capture
> sessions**, run by a linguist, with named collaborators who sign an authorization
> (`gesture_samples.performed_by`, `recorded_by`, `consent_granted_at`, `consent_terms_version`,
> `validated_by`). Samples are no longer anonymous — they identify who performed the sign, on purpose,
> so consent stays provable per person and a withdrawn authorization can be honored.
>
> These are two legitimate but **incompatible** designs, and the model currently implements the second
> while the invariants still describe the first. Which one is correct is a team decision, not an
> editorial one. See §6, ALIGN-02.

---

### Bounded Context: Profile & Preferences

| Field | Value |
|-------|-------|
| **Name** | `ProfileContext` |
| **Responsibility** | Visible profile data and interface preferences: light/dark theme and language |
| **Owner** | Juan Camilo Fierro Esquivel *(proposed assignment)* |
| **Service** | `profile-service` (extraction status: pending) |
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

### Bounded Context: Learning & Lexicon — **expanded in v1.1**

| Field | Value |
|-------|-------|
| **Name** | `LexiconContext` |
| **Responsibility** | Catalog of LSC signs — the fingerspelling alphabet, individual words and phrases — organized by category, with their visual resources and their written form in each interface language |
| **Owner** | Juan Camilo Fierro Esquivel *(proposed assignment)* |
| **Service** | `lexicon-service` (extraction status: pending; today the `lexicon` domain module) |
| **Module(s)** | `backend/src/modules/lexicon`, `mobile/src/features/alphabet`, `mobile/src/features/lexicon` |
| **Persistence** | `lexicon` schema — `sign_lexicon`, `sign_localizations`, `categories`, `multimedia_resources` + resources in file storage |
| **SRS requirements** | RF7, ERF7.1 · ERF5.4 (localization) |

| Term | Meaning HERE | Different in another context? |
|------|--------------|-------------------------------|
| **Sign** (`Sign`) | Catalog entry: a letter, a word or a phrase in LSC | **Yes** — in the Core, "sign" is what the camera is trying to recognize right now; here it is a published catalog record |
| **Sign code** | Stable, language-independent identifier (`GREETING_HELLO`). **It is the same value the Core calls `Gloss`** | Yes — the Core names it `Gloss` |
| **Sign type** | `LETTER`, `WORD` or `PHRASE`. The alphabet is the subset where the type is `LETTER` | No |
| **Localization** | The written form of a sign in one interface language (`Hola` / `Hello`) | No |
| **Category** | Thematic grouping of signs (Greetings, Family, Numbers) | No |
| **Visual resource** | Image, video or animation representing the sign, with an explicit playback order | No |
| **Publication status** | `DRAFT`, `ACTIVE` or `INACTIVE`. Only `ACTIVE` signs are visible to end users | No |
| **Verification** | Approval by a certified interpreter of the accuracy of the representation | No |

> **Why Learning grew (v1.1).** v1.0 modeled this context as the 27 letters of the fingerspelling
> alphabet and nothing else. The v8 model has one general sign catalog where the alphabet is simply the
> rows with `sign_type = LETTER`. That is the better model — a letter and a word are the same thing to
> the recognizer, both are a class it predicts — but it means the context now owns considerably more
> than the alphabet, and its name had to change to say so.
>
> **The consequence that matters most:** `sign_lexicon.code` is the class the AI model predicts, which
> is exactly what the Core calls `Gloss`. That creates a relationship between Learning & Lexicon and the
> Core that did not exist in v1.0, and it is a **Published Language**: the set of codes is the contract
> between the catalog and the recognizer. Adding a sign to the catalog without training the model, or
> renaming a code, breaks recognition silently.

---

### Bounded Context: Usage Analytics

| Field | Value |
|-------|-------|
| **Name** | `AnalyticsContext` |
| **Responsibility** | Build, from the events of the other contexts, the usage metrics the administrator consults |
| **Owner** | Juan Mauricio Suaza Solórzano *(proposed assignment)* |
| **Service** | `analytics-service` (extraction status: pending) |
| **Module(s)** | `backend/src/modules/analytics` |
| **Persistence** | `usage_events` (event log) + reads `user_sessions` from Identity — **read model**, not a source of truth |
| **SRS requirements** | RF6, ERF6.1 |

| Term | Meaning HERE | Different in another context? |
|------|--------------|-------------------------------|
| **Usage report** (`UsageReport`) | Set of aggregated metrics over a date range | No |
| **Usage event** | One recorded fact of use: a section entered, a translation completed, a search performed | No |
| **Visited section** | Application module a user entered — one of the values of `usage_section` | No |
| **User** | Aggregated row, with no direct identification | Yes — here it is never an identifiable person |

> Analytics **owns no aggregated data**: every report it shows is rebuilt from `usage_events`. If every
> report is dropped, they can be regenerated. That is the proof that the reports are a read model.
>
> **Nuance added in v1.1:** `usage_events` itself *is* a source of truth — it is the log the reports are
> rebuilt from, and it cannot be regenerated from anything else. The read model is the report, not the
> event log. The distinction matters because `usage_events` survives the deletion of the account that
> produced it (`ON DELETE SET NULL`), which is what keeps historical reports stable — and that is a rule
> about owned data, not about a projection.

---

### Bounded Context: Notifications — **new in v1.1**

| Field | Value |
|-------|-------|
| **Name** | `NotificationContext` |
| **Responsibility** | Catalog of the alert types that exist, delivery of each alert through a visual channel, scheduling, delivery state, and registration of the devices that can receive a push |
| **Owner** | *(to be assigned)* |
| **Service** | `profile-service` (extraction status: pending) |
| **Module(s)** | `backend/src/modules/notification`, `mobile/src/features/notifications` |
| **Persistence** | `notification` schema — `notification_types`, `notifications`, `user_devices` |
| **SRS requirements** | RF4, ERF4.1 · accessibility ERF (cross-cutting) |

| Term | Meaning HERE | Different in another context? |
|------|--------------|-------------------------------|
| **Notification type** (`NotificationType`) | Kind of alert that exists in the application, with a stable code. The administrator activates or withdraws a type for everyone | No |
| **Channel** | How the alert reaches the user: `PUSH`, `IN_APP` or `EMAIL`. **All three are visual; none is audio** | No |
| **Delivery state** | `PENDING`, `SENT`, `FAILED`, `READ` or `CANCELLED` | No |
| **Device** (`UserDevice`) | A phone registered with its push token and platform. It is deactivated when the provider rejects its token | No |
| **Reference** | The record in another context that caused the alert, named by entity type and id, with no foreign key | No |
| **Scheduling** | Future moment at which a pending notification must be delivered | No |

> **Why it came back as a context (v1.1).** v1.0 argued that Notifications was "a UI component with no
> language of its own and not a single business rule". That was accurate for what existed then. It is
> no longer accurate: the v8 model gave it an administrable type catalog, three delivery channels, a
> five-state delivery lifecycle, scheduled delivery, device registration with revocation, and a
> polymorphic reference to the record that caused each alert. Those are rules and that is a language.
>
> **The rule that matters most here is not in the tables — it is in the enum.** No value of
> `notification_channel` is audio-only, deliberately: the users are deaf and hard-of-hearing people, and
> an alert that depends on sound does not reach them. Encoding that as a constraint rather than a
> guideline means it cannot be violated by accident. Reversal recorded in §5.

---

### Bounded Context: Gamification ⏸ provisional — **new in v1.1**

| Field | Value |
|-------|-------|
| **Name** | `GamificationContext` |
| **Responsibility** | Catalog of achievements, tracking of each user's progress towards them, and unlocking |
| **Owner** | *(to be assigned)* |
| **Service** | `profile-service` (extraction status: pending) |
| **Module(s)** | `backend/src/modules/gamification` |
| **Persistence** | `gamification` schema — `achievements`, `user_achievements` |
| **SRS requirements** | **RF8 — proposed, not yet in the SRS** |

| Term | Meaning HERE | Different in another context? |
|------|--------------|-------------------------------|
| **Achievement** (`Achievement`) | Goal a user unlocks by using the application, with a target count | No |
| **Progress** | How far a user is from a target, computed from `usage_events` | No |
| **Unlock** | The moment a user reaches the target. It happens once per user and per achievement | No |

> ⏸ **This context is provisional.** The `achievements` and `user_achievements` tables exist in the v8
> model with no SRS requirement behind them. Either RF8 is approved and added to the SRS, or the context
> and both tables are removed. Nothing here should be built before that decision.
> See `04-requirements/traceability-matrix.md` § 6, GAP-01.

---

### 2.9 Cross-cutting technical services — deliberately not contexts

Three sets of tables in the v8 model belong to no bounded context, on purpose:

| Service | Tables | Why it is not a context |
|---------|--------|-------------------------|
| **Change audit** | `audit_logs` | It records *that* something changed in any entity of any context, storing the values before and after. It has no vocabulary of its own — it borrows every other context's. It is infrastructure for traceability, not a model of the business |
| **Error log** | `error_logs` | Technical failures classified by type. A stack trace is not a business fact |
| ~~**Password policy**~~ | ~~`password_policies`~~ | **Moved to Identity & Access in v1.2.** It was listed here because it *looked* like configuration — a statement about the shape of the data, not about who owns it. Reversal recorded in §5 |

> **Why draw this line explicitly.** The easy mistake is the opposite one: promoting every table group
> to a context because it has tables. A bounded context exists where a *term* means one specific thing;
> these three have no terms of their own. They are documented here so nobody looks for them in §3 and
> concludes the map is incomplete.
>
> Note that the audit trail and the error log both survive the deletion of the user who produced them
> (`ON DELETE SET NULL`), which is a real requirement: a trace that disappears when the account does is
> not a trace.

---

## 3. Context Map

```
                          ┌───────────────────────────┐
                          │  Identity & Access        │
                          │  (Generic · RF1, RF6)     │
                          │  + Roles and Permissions  │
                          └────────────┬──────────────┘
                                       │ U → D  (userId, authenticated session, permissions)
                                       ▼
┌──────────────────────┐   U → D   ┌───────────────────────────────┐   events    ┌────────────────────┐
│ Consent & Personal   │──────────▶│  RECOGNITION & TRANSLATION    │────────────▶│ Usage Analytics    │
│ Data                 │  may I    │  ★ CORE DOMAIN · RF3, RF5.5   │             │ (Supporting · RF6) │
│ (Supporting · RNF8)  │  store?   │                               │             └────────────────────┘
│ gesture_samples      │           └───────┬───────────────┬───────┘                  ▲    ▲
│ (MongoDB, no FK)     │                   │ events        │                          │    │ events
└──────────────────────┘                   │               │ PL: sign code = Gloss    │    │
           ▲                               ▼               ▼                          │    │
           │ trains        ┌───────────────────────┐  ┌─────────────────────────┐     │    │
           │ the model     │ Profile & Preferences │  │ Learning & Lexicon      │─────┘    │
           └───────────────│ (Supporting · RF5)    │  │ (Supporting · RF7)      │  events  │
                           └───────────┬───────────┘  │ signs · alphabet        │          │
                                       │              └─────────────────────────┘          │
                                       │ events                                            │
                                       ▼                                                   │
                          ┌───────────────────────────┐                                    │
                          │  Notifications            │────────────────────────────────────┘
                          │  (Supporting · RF4)       │   events
                          │  visual channels only     │
                          └───────────────────────────┘
                                       ▲
                                       │ AchievementUnlocked
                          ┌────────────┴──────────────┐
                          │  Gamification  ⏸          │
                          │  (Supporting · RF8?)      │
                          └───────────────────────────┘

Hosting (services, 2026-10-04): iam-service = Identity & Access + Consent (+ audit) ·
               recognition-service = Recognition & Translation (+ model training, MongoDB samples) ·
               lexicon-service = Learning & Lexicon · analytics-service = Usage Analytics ·
               profile-service = Profile + Notifications + Gamification · api-gateway = edge, no context.
               Events travel over RabbitMQ; "may I store?" and permission checks use the JWT
               (`sub`, `roles`) or a REST call to iam-service.

Cross-cutting technical services (not contexts): audit_logs · error_logs
Shared Kernel: the `UserId` value object is shared by Identity, Consent, Profile, Translation,
               Notifications and Gamification.
Published Language: `sign_lexicon.code` — the same value the Core calls `Gloss`. It is the contract
               between the catalog and the recognizer.
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
| Identity & Access | U → D | Recognition & Translation | REST (via JWT claims / iam-service) | `UserId` + authenticated session |
| Identity & Access | SK | Profile, Consent, Translation, Notifications, Gamification | — | `UserId` value object |
| Identity & Access | U → D | every context with a restricted operation | REST (via JWT claims / iam-service) | `hasPermission(userId, permission)` — **new in v1.1** |
| Consent & Personal Data | U → D | Recognition & Translation | REST (via JWT claims / iam-service) | `isConsentActive(userId)` |
| **Learning & Lexicon** | **PL** | **Recognition & Translation** | Shared catalog | **`sign_lexicon.code` = `Gloss`. The set of published codes is the recognizer's vocabulary — new in v1.1** |
| Recognition & Translation | U → D | Usage Analytics | Event (RabbitMQ) | `TranslationProduced`, `TranslationSessionStarted` |
| Learning & Lexicon | U → D | Usage Analytics | Event (RabbitMQ) | `SignViewed`, `LexiconSearchPerformed` |
| Identity & Access | U → D | Usage Analytics | Event (RabbitMQ) | `UserRegistered`, `UserSignedIn` |
| Recognition & Translation | U → D | **Notifications** | Event (RabbitMQ) | `RecognitionFailed`, `TranslationSessionInterrupted` — **new in v1.1** |
| Identity & Access | U → D | **Notifications** | Event (RabbitMQ) | `AccountLocked` — **new in v1.1** |
| **Gamification** ⏸ | U → D | **Notifications** | Event (RabbitMQ) | `AchievementUnlocked` + `reference_type`/`reference_id` — **new in v1.1** |
| Usage Analytics | U → D | **Gamification** ⏸ | Event (RabbitMQ) | Usage events feed progress towards a target — **new in v1.1** |
| Notifications | U → D | Usage Analytics | Event (RabbitMQ) | `NotificationOpened` — **new in v1.1** |
| Identity & Access | ACL | Google OAuth / Facebook Login | HTTPS (OAuth 2.0) | Adapter translating the external profile into `User` |
| Recognition & Translation | ACL | Inference engine (computer vision) | HTTPS / device SDK | `SignRecognitionPort` adapter |
| **Notifications** | **ACL** | **Push provider (FCM / APNs)** | HTTPS | **Adapter translating the provider's response into a delivery state; a rejected token deactivates the device — new in v1.1** |

> **On the new Gamification → Notifications relationship.** It is worth looking at how it is
> implemented, because it is the cleanest thing in the v8 model. `notifications.reference_type` and
> `reference_id` name the record that caused the alert — an achievement, a translation — **with no
> foreign key**. That means Notifications does not depend on Gamification at all: if RF8 is rejected and
> the context disappears, Notifications does not break. The reference is resolved by the application
> layer. This is the pattern that makes the provisional context genuinely removable.

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
| **Learning & Lexicon** | Supporting — **raised in v1.1** | Delivers real educational value and reinforces the inclusive purpose of the project. It was catalogued content in v1.0; it is more than that now, because `sign_lexicon.code` is the recognizer's vocabulary. **The catalog and the model are the same contract seen from two sides**, and a sign published without training is a sign the app promises and cannot deliver. |
| Profile & Preferences | Supporting | Necessary for the experience (theme, language, visible history), but no user picks the app for its profile screen. |
| Usage Analytics | Supporting | Serves the administrator, not the end user. Solved with simple aggregations over events. |
| **Notifications** | Supporting — **raised in v1.1** | It was classified Generic when it was a UI component. It is not generic any more: the accessibility constraint (no channel may be audio-only) is a **product** rule, not a technical one, and it is the reason the app is usable by its intended users at all. An off-the-shelf notification service does not enforce it. |
| Identity & Access | **Generic** | Registration, login, Google/Facebook OAuth and recovery email are solved problems. Use an existing solution (Firebase Auth or Passport + JWT); do not write your own cryptography. The RBAC added in v1.1 does not change this: role and permission tables are a textbook pattern. |
| **Gamification** ⏸ | Supporting *(if approved)* | Achievements motivate the repeated practice a learner needs, which is exactly what is hardest to sustain. But it is the first thing to cut if the schedule tightens, and it does not exist until RF8 does. |

> **Practical consequence of this table:** if the schedule tightens, cut Gamification first, then
> Analytics, then Learning & Lexicon beyond the alphabet. Never cut Consent, and never cut the
> accessibility rule inside Notifications — cutting that one does not make the product smaller, it makes
> it useless to the people it is for.

---

## 5. Modeling decisions

### How these decisions were made

- **Event Storming session:** [date] · participants: Mauricio, Alejandro, Camilo
- **Tool:** [Miro / FigJam / physical whiteboard]
- **Input:** project SRS (IEEE 830), sections 1.6 (scope), 3.2 (functional) and 3.3 (non-functional)
- **Map iterations:** v1 — 8 contexts, one per functional requirement · v1.0 — 6 contexts after the two merges · **v1.1 — 8 contexts, realigned with the v8 persistence model**

### Key decisions and discarded alternatives

| Decision | Discarded alternative | Reason |
|----------|-----------------------|--------|
| History inside *Recognition & Translation* | A separate "Translation History" context | History is the same model already produced; splitting it would duplicate `Translation` and force syncing two sources of truth for nothing |
| Consent as its own context | An `acceptedTerms: boolean` field on `User` | The authorization has a lifecycle, a provable timestamp, a policy version and retroactive effects over data already stored (RNF8) |
| Analytics reports as a read model | Analytics with its own master tables | Every report can be rebuilt from `usage_events`; not owning aggregates prevents metrics and reality from drifting apart |
| Bounded contexts hosted by microservices (reverses the earlier "modules of a monolith" decision, see below) | Modular monolith | Product owner decision of 2026-10-04: each context lives in the service listed in the context map, with its own database |
| **v1.1 —** Authorization inside Identity & Access | Authorization as its own context | It shares the ubiquitous language (`User`, `Role`) and answers the same question — who is this person and what may they do. A separate context would split one language across two boundaries |
| **v1.1 —** Learning renamed to Learning & Lexicon | Keeping Learning for the alphabet and creating a second Lexicon context | A letter and a word are the same thing to the recognizer: both are a class it predicts. Two contexts would mean two models for one table and two names for one code |
| **v1.1 —** Reference by type and id, with no FK, from Notifications | Foreign key from `notifications` to each referenced table | The FK would make Notifications depend on Gamification, and Gamification may not exist. The polymorphic reference is what keeps the provisional context removable |
| **v1.1 —** Audit, errors and password policy as cross-cutting services | Promoting each one to a context | They have tables but no terms of their own. A bounded context exists where a word means one specific thing; none of these three has a word |

### Decisions reversed in v1.2

| v1.1 decision | v1.2 decision | What changed |
|---------------|---------------|--------------|
| **2026-10-04 —** Bounded contexts as modules of a modular monolith, with in-process events | **Bounded contexts hosted by microservices** (iam, recognition, lexicon, analytics, profile + API Gateway), events over RabbitMQ | The product owner confirmed microservices. Each context keeps its boundary and now has a deployment of its own and a database per service; cross-service references are logical IDs, not foreign keys |
| **Password policy as a cross-cutting technical service** — "configuration consumed by Identity & Access; one rule is not enough to constitute a language" | **Password policy inside Identity & Access** | The first half of that sentence contained the answer: *consumed by Identity & Access* — by it, and by nothing else. §2.9 defines a cross-cutting service as one that serves **every** context equally, and applying that test settles it: any context writes to `audit_logs`; only one reads `password_policies`. The second half was answering a different question — whether it is a context of its own, which it is not. Not being a context does not make something cross-cutting; it makes it part of the context that depends on it. Its vocabulary is *password*, which is Identity's word |

> **What the reversal costs.** The `Configuration` domain is dissolved and there is no generic bucket for
> a future setting. That is intended: the two candidates anyone would reach for already have better
> homes — the confidence threshold belongs on `ai_models` (ALIGN-03) and log retention is operations
> configuration, not database rows. **A `config` grouping is a place to avoid deciding where something
> belongs.**

### Decisions reversed in v1.1

Two v1.0 decisions no longer hold. Both are recorded rather than quietly edited, because the original
reasoning was correct for the model that existed then:

| v1.0 decision | v1.1 decision | What changed |
|---------------|---------------|--------------|
| **Notifications as a cross-cutting service** — "it has no ubiquitous language of its own and not a single business rule: it only presents what others decide" | **Notifications as a Supporting bounded context** | The argument was sound when notifications were a banner. The v8 model gave the area an administrable type catalog, three channels, a five-state delivery lifecycle, scheduling, device registration with revocation, and the accessibility constraint on the channel enum. That is a language and those are rules. The original reasoning did not fail — its premise expired |
| **`ADMIN` as a role on `User`** — "an administrator uses the application exactly like any user and additionally sees statistics" | **`Role` and `Permission` as entities, a user may hold several roles** | Still true that an administrator is not a different kind of person. But the model now has a third profile — the LSC linguist, who validates samples without administering users — and adding a `LINGUIST` value to an enum every time a new capability appears is how an enum becomes a permission system by accident. Better to have the permission system on purpose |

### Open decisions

- **Where inference runs** (on the device or on the server). It directly affects the
  `TranslationSession` aggregate and RNF1 (< 1 s per sign). Until it is decided, the domain is modeled
  against the `SignRecognitionPort` port and not against an implementation.
  > **v1.1 note:** `ai_models.storage_reference` points to a published `.tflite` artifact, which
  > suggests on-device inference, but the decision has not been recorded anywhere. A file extension is
  > not a decision — write it down.
- **Confidence threshold** below which a recognition is not presented as a confirmed translation
  (INV-007). It must be set by the team with interpreter support, not picked arbitrarily.
  > **v1.1 note:** this is now blocking. `ai_models` has no column to store the threshold, so INV-007
  > has nowhere to read it from. See §6, ALIGN-03.
- **v1.1 —** Whether **RF8 (Gamification)** enters the SRS, which decides whether context 8 exists.
- **v1.1 —** Which sample-capture model is correct: anonymous samples from end users (v1.0, INV-010) or
  identified samples from named collaborators in capture sessions (v8 model). See §6, ALIGN-02.

---

## 6. Where the map and the database still disagree

> **New section in v1.1.** Bringing the map in sync with the persistence model closed most of the
> distance, but not all of it. What follows is what is still inconsistent. These are not defects in
> either artifact — they are decisions that were made in one place and never carried to the other.

| ID | What disagrees | Domain says | Model says | Action |
|----|----------------|-------------|------------|--------|
| **ALIGN-01** | The Core aggregate root has no table | `TranslationSession` is the aggregate root; `Translation` exists only inside it (INV-005), sharing `outputMode` and `modelVersion` | There is no `translation_sessions` table. `translations` hangs off `user_id`, each row with its own `output_mode` and `model_id` | **Decide which model is right.** Either add the table, or accept that the session is a runtime concept only and rewrite INV-005 and AGGR-INV-001…004, which currently describe something that cannot be persisted |
| **ALIGN-02** | Sample identity | INV-010: a `TrainingSample` never carries a `userId` nor anything allowing re-identification | `gesture_samples` stores `performed_by` (the performer's name, as text), `recorded_by` and `validated_by` | **Decide which capture model is right.** They are incompatible. The v8 design is defensible — consent stays provable per person and a withdrawn authorization can be honored, which anonymization makes impossible — but then INV-010 must be rewritten, not left standing |
| **ALIGN-03** | Confidence threshold | INV-007 compares each recognition against the model's `confidenceThreshold` | `ai_models` has `accuracy` but **no threshold column** | Add the column, or move the threshold to `password_policies`-style configuration. As it stands INV-007 has nowhere to read its threshold from and cannot be implemented |
| **ALIGN-04** | The events table | `domain-events.md` states events are persisted in a `domain_events` table for traceability | There is no `domain_events` table in the model | Add it (per service, as an outbox/inbox), or drop the claim. RabbitMQ alone does not persist history — without a table, traceability of events is not a property the project has |
| **ALIGN-05** | Account states | `PENDING_VERIFICATION` / `ACTIVE` / `LOCKED` / `DELETED` | `user_status`: `ACTIVE` / `INACTIVE` / `BLOCKED`, plus `locked_until` and `deleted_at` | Unify the names. `INACTIVE` is `PENDING_VERIFICATION`; a temporary lockout is a date, not a state; `DELETED` is `deleted_at`. Four names for the same four situations is how two developers implement two different state machines |
| **ALIGN-06** | Lockout rule | RNF4 and the `User` code example: five consecutive failures → `LOCKED` | Progressive escalation: `lockout_level` determines the wait (1, 5, 10 min); `BLOCKED` only when the escalation is exhausted; the level resets after 24 h | The model's rule is better and more detailed. Update the domain: the code example in `entities-and-rules.md` implements a rule the database no longer has |
| **ALIGN-07** | Output mode | `OutputMode`: `TEXT` \| `AUDIO` \| `BOTH` | `output_mode`: `TEXT` \| `AUDIO`. There is no `BOTH` | Decide. If audio always accompanies visible text — which is what accessibility requires — then `BOTH` is the only sensible value and `AUDIO` alone should not exist |
| **ALIGN-08** | Interface language | `AppLanguage`: `es-CO` \| `en-US` | `ui_language`: `ES` \| `EN` | Cosmetic, but pick one. The IETF tag is the better choice if regional variants are ever expected |
| **ALIGN-09** | Password reset | `PasswordResetRequest`, its own aggregate root | `user_tokens`, one table for verification codes and reset tokens, distinguished by `token_type` | The model is better: one lifecycle, one table. Update the domain |

**Priority order:** ALIGN-01 and ALIGN-02 are model decisions and block work. ALIGN-03 and ALIGN-04
block a documented invariant and a documented mechanism. The rest are naming, and cheap to fix now and
expensive to fix after the code exists.

---

## 7. How to update this map

1. Before adding a new backend module, verify whether it belongs to an existing context.
2. If a context's ubiquitous language starts having terms with two meanings, consider splitting it.
3. Repeat the Event Storming whenever the domain changes significantly — especially if reverse
   translation or 3D modeling of the alphabet enters the scope.
4. This map must stay synchronized with the system-level C4 diagram in `05-architecture/overview.md`.

> **Correlation:** the bounded contexts in this document → backend modules in
> `09-microservices/service-catalog.md` → C4 diagrams in `08-uml/` →
> separation decisions in `05-architecture/decisions/`.
