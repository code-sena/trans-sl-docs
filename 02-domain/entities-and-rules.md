# Entities, Value Objects and Business Rules — Traduce Señas

> The building blocks of the domain following the DDD tactical model. This document translates the
> domain knowledge (gathered in the Event Storming and recorded in `domain-map.md`) into models that
> become code directly.

> **Stack note:** the concepts of Entity, Value Object and Aggregate are language-independent. Code
> examples are in TypeScript because that is the project stack (React Native/Expo + Node/Express).
> For other technologies:
> [`_stacks/node-typescript.md`](../_stacks/node-typescript.md) ·
> [`_stacks/java-spring.md`](../_stacks/java-spring.md) ·
> [`_stacks/python-fastapi.md`](../_stacks/python-fastapi.md) ·
> [`_stacks/go.md`](../_stacks/go.md)

**Version:** v1.2 · **Last updated:** 2026-09-10

> **What changed in v1.2.** `PasswordPolicy` moves from cross-cutting to **Identity & Access** — it is
> read by that context and by no other. Reversal recorded in `domain-map.md` §5.
>
> **What changed in v1.1.** Realigned with the v8 persistence model. New entities for the tables the
> model added: `Role` and `Permission` (Identity), `Sign`, `SignLocalization`, `Category` and
> `MultimediaResource` (Learning & Lexicon), `NotificationType`, `Notification` and `UserDevice`
> (Notifications), `PasswordPolicy`, and `Achievement` / `UserAchievement` marked ⏸ pending RF8.
> `User` gains the progressive lockout attributes. Invariants go from 13 to 27.
>
> Four invariants are now marked ⚠️ **because the database contradicts them** — INV-005, INV-007,
> INV-010 and the `User` lockout rule. They are left standing rather than quietly rewritten: each one
> was a deliberate decision, and reversing it is the team's call. The conflicts are listed in
> `domain-map.md` §6.

---

## Tactical DDD concepts, with project examples

### Entity
An **Entity** is defined by its identity, not by its attributes. Two entities are equal if they have the
same id, even if all their other attributes differ.

```
✓ Entity: User (still the same user even after changing email and password)
✓ Entity: TranslationSession (changes state but remains the same session)
✗ Not an entity: Confidence (0.87 == 0.87, no matter which recognition produced it)
```

### Value Object (VO)
A **Value Object** is defined by its attributes, has no identity of its own and is immutable: if an
attribute changes, it is a new VO.

```
✓ Value Object: Email (user@example.com)
✓ Value Object: Confidence (0.87)
✓ Value Object: Gloss ("THANK-YOU")
✓ Value Object: DateRange (2026-08-01 → 2026-08-31)
```

### Aggregate
An **Aggregate** is a cluster of entities and VOs treated as a unit. It has an **aggregate root** which
is the only entry point: internal objects are reached only through it.

```
TranslationSession (Aggregate Root)
  ├── Translation[]     (entities inside the aggregate)
  ├── OutputMode        (value object)
  └── ModelVersion      (value object: which model version produced it)
```

**Golden rule of the aggregate:** transactions do not cross aggregate boundaries. If two aggregates must
change in one operation, use a domain event and a policy.
For example: when a translation is produced, Analytics is not written in the same transaction — a
`TranslationProduced` event is emitted and Analytics reacts.

### Business rules
**Invariants** are the constraints the domain must always satisfy. They live in the aggregate root and
are validated on every operation. In this project they are numbered INV-001 through INV-027.

---

## System entities

### Entity: `User`

**Context:** Identity & Access
**Description:** Holder of an application account, with credentials, role and status.

**Attributes:**

| Attribute | Type | Description | Required | Rules |
|-----------|------|-------------|----------|-------|
| `id` | UUID | Unique identifier | Yes | Auto-generated on creation |
| `name` | string | User's full name | Yes | 2 to 80 characters |
| `username` | string | Unique display handle | Yes | Unique across the system — **v1.1** |
| `birthDate` | Date | Date of birth | No | ERF1.1 asks for age; the date is stored and the age computed — **v1.1** |
| `email` | `Email` (VO) | Account email | Yes | Unique across the system (INV-001) |
| `passwordHash` | `PasswordHash` (VO) | Password hash | No | Absent if only an external provider is used |
| `providers` | `ExternalProviderLink[]` | Google/Facebook links | No | At most one per provider (INV-004) |
| `roles` | `Role[]` | Roles held | Yes | At least one; defaults to `USER` — **changed in v1.1: was a single `UserRole` VO** |
| `status` | `AccountStatus` (VO) | Account status | Yes | See lifecycle |
| `emailVerifiedAt` | DateTime | When the email was confirmed | No | Set on validating the code, or immediately on registering through a provider — **v1.1** |
| `termsAcceptedAt` | DateTime | When terms were accepted | Yes | No registration without it (INV-002) |
| `termsVersion` | string | Version of the document accepted | Yes | Provable consent requires knowing *what* was accepted (INV-002) — **v1.1** |
| `failedLoginAttempts` | int | Consecutive failed attempts | Yes | Reset on a successful sign-in |
| `lockoutLevel` | int | Lockouts accumulated in the current streak | Yes | Determines how long the next lockout lasts (INV-014) — **v1.1** |
| `lockedUntil` | DateTime | End of the temporary lockout | No | Lifts on its own when the date passes — **v1.1** |
| `lastFailedLoginAt` | DateTime | Last failed attempt | No | Allows resetting `lockoutLevel` after 24 h — **v1.1** |
| `blockedAt` | DateTime | When the escalation was exhausted | No | Only when status is `BLOCKED` — **v1.1** |
| `createdAt` | DateTime | Creation date | Yes | Immutable |
| `updatedAt` | DateTime | Last modification | Yes | Set automatically |
| `lastAccessAt` | DateTime | Last access | No | — **v1.1** |
| `deletedAt` | DateTime | Deletion requested by the data subject | No | The row is kept anonymized (RNF8) — **v1.1** |

**Lifecycle — revised in v1.1:**

```
[PENDING_VERIFICATION] ──(verifies email)──▶ [ACTIVE] ──(requests deletion)──▶ [DELETED]
        │                                       │  ▲
        │ (registers with Google/Facebook:      │  │ (lockedUntil passes,
        │  goes straight to ACTIVE)             │  │  or an admin releases it)
        └───────────────────────────────────────┤  │
                                                ▼  │
                                        [temporarily locked]
                                          lockedUntil = now + 1 / 5 / 10 min
                                                │
                                    (escalation exhausted)
                                                ▼
                                           [BLOCKED]
                                    only an admin restores it
```

| State | Description | Allowed transitions |
|-------|-------------|---------------------|
| `PENDING_VERIFICATION` | Registered but email not confirmed. Persisted as `INACTIVE` | → `ACTIVE`, → `DELETED` |
| `ACTIVE` | May use the application | → temporarily locked, → `BLOCKED`, → `DELETED` |
| *temporarily locked* | **Not a state — a date.** `status` stays `ACTIVE` and `lockedUntil` holds a future timestamp. It lifts by itself | → `ACTIVE` (automatic), → `BLOCKED` |
| `BLOCKED` | Lockout escalation exhausted (RNF4). Requires administrator intervention | → `ACTIVE`, → `DELETED` |
| `DELETED` | Deletion requested by the data subject (RNF8). Persisted as `deletedAt` | Terminal state |

> **Why a temporary lockout is a date and not a state (v1.1).** v1.0 modeled `LOCKED` as a fourth
> state. The v8 model uses `locked_until`, which is better: a state has to be exited by somebody, and
> nobody is going to run a job every minute to unlock accounts. A date in the future expires on its own.
> The only real state is `BLOCKED`, which genuinely requires a human to lift it.

**Invariants:**

```
INV-001: Unique email
  - Rule: No two users can share the same email
  - Violation: Registration is rejected with a domain error
  - Implementation: Checked in the registration service against the repository, before building the User

INV-002: No registration without accepted terms
  - Rule: A User cannot be persisted without termsAcceptedAt
  - Violation: DomainException is thrown; the account is not created
  - Implementation: Validated in the static factory User.register()

INV-003: The password is never stored in plain text
  - Rule: Only the password hash is stored
  - Violation: Impossible by construction: the attribute is a PasswordHash, not a string
  - Implementation: PasswordHash can only be built through PasswordHash.fromPlainText()

INV-004: An external provider maps to a single account
  - Rule: A user may link several providers, but the same (provider, externalId) pair cannot exist
    in two accounts
  - Violation: The link is rejected and signing in with the existing account is offered
  - Implementation: Unique index on (provider, externalId) plus validation in linkProvider()

INV-014: Lockout escalates progressively and expires on its own      [NEW in v1.1]
  - Rule: Each accumulated lockout level lengthens the next wait (1, 5, 10 minutes). The lockout is a
    future date, not a state, and it lifts without intervention. Only when the escalation is exhausted
    does the account become BLOCKED, and only an administrator restores it. The level resets to zero
    after 24 hours with no failed attempts
  - Violation: Either a legitimate user is locked out forever over a typo, or an attacker gets
    unlimited attempts
  - Implementation: user.registerFailedLogin() computes lockedUntil from lockoutLevel;
    a successful sign-in resets failedLoginAttempts; lastFailedLoginAt drives the 24-hour reset
  - ⚠️ Supersedes the "five failures → LOCKED" rule of v1.0. See domain-map.md §6, ALIGN-06

INV-015: Verification and recovery codes are single-use and expire    [NEW in v1.1]
  - Rule: A code is stored only as a hash, has an expiry date, is marked used the first time it is
    validated, and counts its failed attempts. A used code is never valid again
  - Violation: A leaked or reused code grants access to an account that is not the holder's
  - Implementation: user_tokens with token_type, token_hash, expires_at, used_at, attempts

INV-016: Permissions are granted through roles, never directly       [NEW in v1.1]
  - Rule: A user holds roles; a role holds permissions. There is no path from a user to a permission
    that does not pass through a role
  - Violation: Individual exceptions accumulate until nobody can say who can do what
  - Implementation: user_roles and role_permissions; there is no user_permissions table, deliberately

INV-017: A role in use cannot be deleted                             [NEW in v1.1]
  - Rule: A role assigned to at least one user is not deletable
  - Violation: Users left with no permissions and no trace of why
  - Implementation: ON DELETE RESTRICT on user_roles.role_id
```

**Code example:**

```typescript
class User {
  private constructor(
    private readonly id: UserId,
    private name: string,
    private email: Email,
    private passwordHash: PasswordHash | null,
    private role: UserRole,
    private status: AccountStatus,
    private readonly termsAcceptedAt: Date,
    private failedLoginAttempts: number = 0,
  ) {}

  static register(name: string, email: Email, password: PasswordHash, termsAccepted: boolean): User {
    if (!termsAccepted) {
      throw new DomainException('INV-002: cannot register without accepting the terms and conditions');
    }
    const user = new User(
      UserId.new(), name, email, password,
      UserRole.USER, AccountStatus.PENDING_VERIFICATION, new Date(),
    );
    user.addEvent(new UserRegistered(user.id, email));
    return user;
  }

  // Revised in v1.1: progressive escalation instead of "5 failures → LOCKED"
  registerFailedLogin(): void {
    this.failedLoginAttempts += 1;
    this.lastFailedLoginAt = new Date();

    if (this.failedLoginAttempts < FAILURES_PER_LEVEL) return;

    this.lockoutLevel += 1;
    this.failedLoginAttempts = 0;

    const waitMinutes = LOCKOUT_LADDER[this.lockoutLevel - 1];   // 1, 5, 10
    if (waitMinutes === undefined) {                             // ladder exhausted
      this.status = AccountStatus.BLOCKED;                       // RNF4 — only an admin restores it
      this.blockedAt = new Date();
      this.addEvent(new AccountBlocked(this.id, this.lockoutLevel));
      return;
    }

    this.lockedUntil = addMinutes(new Date(), waitMinutes);      // INV-014 — expires on its own
    this.addEvent(new AccountLocked(this.id, this.lockoutLevel, this.lockedUntil));
  }

  // A streak that goes cold stops counting: 24 h with no failures resets the ladder
  resetLockoutIfStale(now: Date): void {
    if (this.lastFailedLoginAt && hoursBetween(this.lastFailedLoginAt, now) >= 24) {
      this.lockoutLevel = 0;
      this.failedLoginAttempts = 0;
    }
  }
}
```

---

### Entity: `Role` / `Permission` — **new in v1.1**

**Context:** Identity & Access
**Description:** Access control. In v1.0 the role was a value object on `User` holding `USER` or
`ADMIN`; the v8 model turned it into two entities with their association tables.

| Entity | Attributes | Rules |
|--------|-----------|-------|
| `Role` | `id`, `name` (unique), `description` | Not deletable while assigned (INV-017) |
| `Permission` | `id`, `name` (unique, e.g. `stats.read`), `description` | Granted only through a role (INV-016) |

**Roles foreseen in the project:**

| Role | What it can do |
|------|----------------|
| `USER` | Translate, consult the lexicon and the alphabet, manage their own profile and history |
| `ADMIN` | Everything a `USER` can, plus managing content, accounts, models and reading statistics |
| `LINGUIST` | Capture and validate gesture samples. **Does not administer users** |

> **Why `LINGUIST` is what forced this change.** With two roles, an enum was enough. The linguist is a
> third profile that needs a capability (`samples.validate`) without any of the others — and adding a
> value to an enum for every new capability is how an enum becomes a permission system by accident.
> Better to have the permission system on purpose. Reversal recorded in `domain-map.md` §5.

---

### Entity: `TranslationSession` ⭐ central aggregate root

**Context:** Recognition & Translation (Core)
**Description:** Continuous period with the camera active, from the moment the user turns translation
mode on until they turn it off. It is the container of every translation produced in that period.

| Attribute | Type | Description | Required | Rules |
|-----------|------|-------------|----------|-------|
| `id` | UUID | Unique identifier | Yes | Auto-generated |
| `userId` | `UserId` (VO) | Session owner | Yes | Immutable once assigned |
| `status` | `SessionStatus` (VO) | Session status | Yes | See lifecycle |
| `outputMode` | `OutputMode` (VO) | `TEXT`, `AUDIO` or `BOTH` | Yes | Can change during the session |
| `modelVersion` | `ModelVersion` (VO) | Model version used | Yes | Fixed at start |
| `translations` | `Translation[]` | Translations produced | Yes | May be empty |
| `startedAt` | DateTime | Start | Yes | Immutable |
| `endedAt` | DateTime | End | No | Only in terminal states |

**Lifecycle:**

```
[STARTED] ──(camera ready)──▶ [ACTIVE] ──(user turns it off)──▶ [ENDED]
                                 │
                    (camera denied, connection
                     lost, engine error)
                                 ▼
                          [INTERRUPTED]
```

| State | Description | Allowed transitions |
|-------|-------------|---------------------|
| `STARTED` | Translation mode on, camera starting up | → `ACTIVE`, → `INTERRUPTED` |
| `ACTIVE` | Recognizing signs | → `ENDED`, → `INTERRUPTED` |
| `ENDED` | Closed normally by the user | Terminal |
| `INTERRUPTED` | Closed by a failure; translations already produced are kept (RNF7) | Terminal |

**Invariants:**

```
INV-005: Every translation belongs to a session and to a user     ⚠️ CONTRADICTED BY THE MODEL
  - Rule: No Translation exists outside a TranslationSession
  - Violation: DomainException when trying to create one standalone
  - Implementation: Translation's constructor is private; only session.addTranslation() creates one
  - ⚠️ v1.1: the v8 model has no translation_sessions table. `translations` hangs directly off
    user_id, so this invariant cannot be enforced at the persistence layer. Either the table is
    added or the invariant is rewritten. See domain-map.md §6, ALIGN-01

INV-006: Confidence within range
  - Rule: Confidence is always between 0.0 and 1.0
  - Violation: DomainException in the VO constructor
  - Implementation: Validation in Confidence.constructor()

INV-007: Confidence below the threshold is not a confirmed translation   ⚠️ NO THRESHOLD IN THE MODEL
  - Rule: If confidence < the configured threshold, the result is not presented as a confirmed
    translation nor stored in the history; RecognitionFailed is emitted instead
  - Violation: The user would be shown an incorrect translation as if it were correct
  - Implementation: session.addTranslation() compares against the threshold before appending
  - ⚠️ v1.1: ai_models stores `accuracy` but has no confidence_threshold column, so there is
    nowhere to read the threshold from. Blocking: this invariant cannot be implemented as written.
    See domain-map.md §6, ALIGN-03

INV-008: No sample is stored without a valid consent grant
  - Rule: No video fragment or landmark sequence is persisted unless the user has a ConsentGrant
    in GRANTED status
  - Violation: Breach of Law 1581; the operation is aborted
  - Implementation: The application service queries the Consent context before persisting. Without
    consent, translation still works: only the sample is not kept (RNF8)

INV-011: History is private and its deletion is irreversible
  - Rule: Only the owner accesses their translations; individual deletion cannot be undone
  - Violation: Access denied / operation rejected
  - Implementation: Every history query filters by userId; deletion emits TranslationDeleted
```

**Code example:**

```typescript
class TranslationSession {
  private translations: Translation[] = [];

  static start(userId: UserId, mode: OutputMode, model: ModelVersion): TranslationSession {
    const session = new TranslationSession(
      SessionId.new(), userId, SessionStatus.STARTED, mode, model, new Date(),
    );
    session.addEvent(new TranslationSessionStarted(session.id, userId, model));
    return session;
  }

  addTranslation(gloss: Gloss, confidence: Confidence, threshold: Confidence): void {
    if (this.status !== SessionStatus.ACTIVE) {
      throw new DomainException('INV-005: cannot translate in a session that is not active');
    }
    if (confidence.isBelow(threshold)) {
      this.addEvent(new RecognitionFailed(this.id, confidence));   // INV-007
      return;
    }
    const translation = Translation.create(gloss, confidence, this.outputMode);
    this.translations.push(translation);
    this.addEvent(new TranslationProduced(this.id, this.userId, translation.id, gloss));
  }

  interrupt(reason: InterruptionReason): void {
    this.status = SessionStatus.INTERRUPTED;   // RNF7: what was already translated is kept
    this.endedAt = new Date();
    this.addEvent(new TranslationSessionInterrupted(this.id, reason));
  }
}
```

---

### Entity: `Translation`

**Context:** Recognition & Translation · **inside the `TranslationSession` aggregate**
**Description:** A recognized sign delivered to the user. It is what later appears in the history.

| Attribute | Type | Description | Required | Rules |
|-----------|------|-------------|----------|-------|
| `id` | UUID | Identifier | Yes | Auto-generated |
| `sequence` | int | Order within the session | Yes | Consecutive from 1 |
| `gloss` | `Gloss` (VO) | Recognized gloss | Yes | Not empty |
| `text` | `TranslatedText` (VO) | Text shown to the user | Yes | Derived from the gloss |
| `confidence` | `Confidence` (VO) | Model certainty | Yes | ≥ threshold (INV-007) |
| `outputMode` | `OutputMode` (VO) | How it was delivered | Yes | — |
| `producedAt` | DateTime | When it was produced | Yes | Immutable |
| `deletedAt` | DateTime | Deleted by the user | No | If present, it does not appear in the history |

---

### Entity: `ConsentGrant`

**Context:** Consent & Personal Data
**Description:** Express authorization by the data subject to keep video or gesture samples for model
training. Required by RNF8 (Law 1581 of 2012, Decree 1377 of 2013).

| Attribute | Type | Description | Required | Rules |
|-----------|------|-------------|----------|-------|
| `id` | UUID | Identifier | Yes | Auto-generated |
| `userId` | `UserId` (VO) | Data subject | Yes | Immutable |
| `purpose` | `ConsentPurpose` (VO) | `MODEL_TRAINING` | Yes | One grant per purpose |
| `policyVersion` | `PolicyVersion` (VO) | Version of the accepted policy | Yes | Immutable |
| `status` | `ConsentStatus` (VO) | `GRANTED` or `REVOKED` | Yes | See lifecycle |
| `grantedAt` | DateTime | Date and time of granting | Yes | Provable (RNF8) |
| `revokedAt` | DateTime | Date and time of revocation | No | Only if `REVOKED` |

**Lifecycle:**

```
[GRANTED] ──(subject revokes)──▶ [REVOKED]   (terminal: authorizing again creates a new grant)
```

**Invariants:**

```
INV-009: Revocation is terminal and timestamped
  - Rule: A revoked ConsentGrant never returns to GRANTED; if the subject authorizes again, a new
    grant is created with its own timestamp and policy version
  - Violation: DomainException when trying to reactivate it
  - Implementation: revoke() validates the status and sets revokedAt; there is no reactivate() method

INV-012: Only the administrator sees statistics, and always aggregated
  - Rule: Access to the statistics module requires the ADMIN role, and metrics never expose
    identifiable individual translations
  - Violation: Access denied
  - Implementation: Role guard in the application layer plus a read model that stores counts only
```

---

### Entity: `TrainingSample`

**Context:** Consent & Personal Data
**Description:** Sample kept to train the model. **It never stores a reference to the user.**

| Attribute | Type | Description | Required | Rules |
|-----------|------|-------------|----------|-------|
| `id` | UUID | Identifier | Yes | Auto-generated |
| `anonymousSubjectId` | `AnonymousSubjectId` (VO) | Irreversible pseudonym | Yes | Cannot be resolved back to the user (INV-010) |
| `gloss` | `Gloss` (VO) | Sign label | Yes | — |
| `capturedAt` | DateTime | Capture date | Yes | Immutable |
| `anonymizedAt` | DateTime | Dissociation date | Yes | Set before persisting |
| `storageRef` | string | File reference | Yes | — |

```
INV-010: Kept samples are dissociated from identity        ⚠️ CONTRADICTED BY THE MODEL
  - Rule: A TrainingSample cannot carry a userId nor any data allowing re-identification of the subject
  - Violation: Direct breach of the RNF8 acceptance criterion
  - Implementation: The entity has no userId attribute. Anonymization happens at sample creation time,
    not afterwards
  - ⚠️ v1.1: gesture_samples stores performed_by (the performer's name as text), recorded_by
    and validated_by. Samples are identified, deliberately. The v8 design is defensible — consent
    stays provable per person and a withdrawn authorization can actually be honored, which
    anonymization makes impossible — but it is the opposite rule. One of the two has to go.
    See domain-map.md §6, ALIGN-02
```

---

### Entity: `Sign` — **replaces `AlphabetLetter` in v1.1**

**Context:** Learning & Lexicon
**Description:** A catalog entry in LSC: a letter, a word or a phrase. **The alphabet is the subset
where `signType` is `LETTER`.**

| Attribute | Type | Description | Required | Rules |
|-----------|------|-------------|----------|-------|
| `id` | UUID | Identifier | Yes | Auto-generated |
| `code` | `SignCode` (VO) | Stable, language-independent identifier (`GREETING_HELLO`) | Yes | Unique. **It is the same value the Core calls `Gloss`** (INV-018) |
| `signType` | `SignType` (VO) | `LETTER`, `WORD` or `PHRASE` | Yes | Defaults to `WORD` |
| `letter` | `LetterCode` (VO) | Letter represented | No | Present if and only if `signType` is `LETTER` (INV-013) |
| `signLanguage` | `SignLanguage` (VO) | `LSC` | Yes | The content's sign language, not the interface language |
| `category` | `Category` | Thematic grouping | Yes | — |
| `status` | `ContentStatus` (VO) | `DRAFT`, `ACTIVE` or `INACTIVE` | Yes | Only `ACTIVE` is visible to end users (INV-019) |
| `localizations` | `SignLocalization[]` | Written form per interface language | Yes | At most one per language |
| `resources` | `MultimediaResource[]` | Images, videos, animations | No | Ordered, no two at the same position (INV-020) |
| `createdBy` / `updatedBy` | UUID | Who created it, who last edited it | No | Null if that account was deleted |
| `createdAt` / `updatedAt` | DateTime | Dates | Yes | — |

```
INV-013: The alphabet is complete and verified      [revised in v1.1]
  - Rule: Exactly 27 signs of type LETTER exist (A–Z plus Ñ) per sign language, each with at least
    one verified visual resource, and no letter is repeated within the same sign language
  - Violation: The alphabet module is not released incomplete
  - Implementation: Unique index (sign_language, letter) plus a catalog integrity test at startup

INV-018: The sign code is the recognizer's vocabulary            [NEW in v1.1]
  - Rule: sign.code is the class the AI model predicts. A code is never renamed once published, and
    a sign is not published ACTIVE unless the active model recognizes its code
  - Violation: The catalog promises a sign the recognizer cannot produce, and it fails silently —
    the user signs correctly and nothing happens
  - Implementation: Publication validates the code against ai_models.sign_count / the model's
    vocabulary. This is the Published Language between Lexicon and the Core

INV-019: Only ACTIVE content reaches the end user                [NEW in v1.1]
  - Rule: Signs in DRAFT or INACTIVE never appear in any end-user query
  - Violation: Unfinished or withdrawn material shown as if it were verified
  - Implementation: Every catalog query filters by status = ACTIVE

INV-020: Resource order is unambiguous                            [NEW in v1.1]
  - Rule: Two resources of the same sign cannot share a position
  - Violation: Playback order depends on chance, and the explanation of the sign stops making sense
  - Implementation: Unique index (sign_id, position); position >= 1
```

> **Why `AlphabetLetter` disappeared.** It did not disappear — it became a `Sign` with
> `signType = LETTER`. Keeping a separate entity for letters would have meant two models for one table,
> two names for one code, and a decision to make every time somebody asks whether a fingerspelled word
> is a letter or a word. To the recognizer a letter and a word are the same thing: a class it predicts.

---

### Entity: `SignLocalization` — **new in v1.1**

**Context:** Learning & Lexicon · **inside the `Sign` aggregate**
**Description:** The written form of a sign in one interface language.

| Attribute | Type | Description | Required | Rules |
|-----------|------|-------------|----------|-------|
| `id` | UUID | Identifier | Yes | — |
| `uiLanguage` | `AppLanguage` (VO) | Interface language | Yes | At most one localization per sign and language |
| `name` | string | Displayed text (`Hola` / `Hello`) | Yes | — |
| `meaning` | string | Meaning | No | — |
| `description` | string | Description of the hand configuration | No | Accessible to screen readers |

---

### Entity: `Category` — **new in v1.1**

**Context:** Learning & Lexicon
**Description:** Thematic grouping of signs (Greetings, Family, Numbers).

| Attribute | Type | Description | Required | Rules |
|-----------|------|-------------|----------|-------|
| `id` | UUID | Identifier | Yes | — |
| `name` | string | Category name | Yes | Unique |
| `description` | string | Description | No | — |

```
INV-021: A category with signs is not deletable                   [NEW in v1.1]
  - Rule: A category assigned to at least one sign cannot be deleted
  - Violation: Orphaned signs with no place in the catalog
  - Implementation: ON DELETE RESTRICT on sign_lexicon.category_id
```

---

### Entity: `MultimediaResource` — **new in v1.1**

**Context:** Learning & Lexicon · **inside the `Sign` aggregate**

| Attribute | Type | Description | Required | Rules |
|-----------|------|-------------|----------|-------|
| `id` | UUID | Identifier | Yes | — |
| `resourceType` | `ResourceType` (VO) | `IMAGE`, `VIDEO` or `ANIMATION` | Yes | — |
| `uri` | string | Storage reference | Yes | — |
| `mimeType` | string | MIME type | No | — |
| `position` | int | Playback order | Yes | ≥ 1, unique per sign (INV-020) |
| `description` | string | Text description | No | Accessible to screen readers (NFR-001) |

> **The resource is playable without sound, always.** A video that explains a sign through narration is
> useless to the users of this application. The description exists so a screen reader can convey what
> the video shows.

---

### Entity: `RecognitionModel`

**Context:** Recognition & Translation
**Description:** Version of the recognition model in use. It exists as an entity because the SRS
promises continuous vocabulary updates: the system must know which version produced each translation.

| Attribute | Type | Description | Required |
|-----------|------|-------------|----------|
| `id` | UUID | Identifier | Yes |
| `version` | `ModelVersion` (VO) | Semantic version | Yes |
| `confidenceThreshold` | `Confidence` (VO) | Minimum acceptable confidence (INV-007) | Yes ⚠️ **not in the model — ALIGN-03** |
| `supportedGlosses` | `Gloss[]` | Covered vocabulary | Yes |
| `signLanguage` | `SignLanguage` (VO) | Sign language it was trained for — **v1.1** | Yes |
| `trainedBy` | UUID | Administrator who ran the training — **v1.1** | Yes |
| `trainedAt` | DateTime | Training date — **v1.1** | Yes |
| `sampleCount` | int | Samples used — **v1.1** | Yes |
| `signCount` | int | Distinct signs it recognizes — **v1.1** | Yes |
| `accuracy` | decimal | Accuracy on the test set, 0 to 1 — **v1.1** | No |
| `storageReference` | string | Path to the published artifact — **v1.1** | Yes |
| `isActive` | boolean | Whether it is the production version | Yes |
| `releasedAt` | DateTime | Release date | Yes |

```
INV-022: Exactly one model is active                              [NEW in v1.1]
  - Rule: At no point are two models active at once. Activating one deactivates the previous one in
    the same operation. A model that produced translations is never deleted
  - Violation: Two devices translating with different versions and results nobody can compare;
    or history pointing at a model that no longer exists
  - Implementation: Partial unique index on is_active = true; ON DELETE RESTRICT on
    translations.model_id
```

---

### Entity: `NotificationType` — **new in v1.1**

**Context:** Notifications
**Description:** Kind of alert that exists in the application. The administrator activates or withdraws
a type for every user at once.

| Attribute | Type | Description | Required | Rules |
|-----------|------|-------------|----------|-------|
| `id` | UUID | Identifier | Yes | — |
| `code` | string | Stable code (`ACHIEVEMENT_UNLOCKED`, `ACCOUNT_SECURITY`) | Yes | Unique |
| `name` | string | Descriptive name | Yes | — |
| `isActive` | boolean | Administrator control | Yes | Defaults to true |

> **There is no per-user, per-type preference, deliberately.** RF4 says the user can turn notifications
> on or off — one switch, which is `UserProfile.notificationsEnabled`. Per-type granularity is an
> administrator control, not a user one. Adding a preferences matrix would be building something the
> requirement does not ask for.

---

### Entity: `Notification` — **new in v1.1**

**Context:** Notifications

| Attribute | Type | Description | Required | Rules |
|-----------|------|-------------|----------|-------|
| `id` | UUID | Identifier | Yes | — |
| `userId` | `UserId` (VO) | Recipient | Yes | — |
| `type` | `NotificationType` | Alert type | Yes | — |
| `channel` | `NotificationChannel` (VO) | `PUSH`, `IN_APP` or `EMAIL` | Yes | **All three visual** (INV-023) |
| `device` | `UserDevice` | Target device | No | Required if and only if the channel is `PUSH` (INV-024) |
| `title` / `body` | string | Content | Yes | — |
| `referenceType` | `ReferenceEntity` (VO) | Type of record that caused the alert | No | No foreign key |
| `referenceId` | UUID | The record itself | No | Resolved by the application layer |
| `status` | `DeliveryStatus` (VO) | `PENDING`, `SENT`, `FAILED`, `READ`, `CANCELLED` | Yes | See lifecycle |
| `scheduledAt` | DateTime | Scheduled delivery moment | No | RF4 |
| `sentAt` / `readAt` | DateTime | Delivery and reading | No | — |

**Lifecycle:**

```
[PENDING] ──(delivered)──▶ [SENT] ──(user opens it)──▶ [READ]
     │                        
     ├──(provider rejects it)──▶ [FAILED]
     └──(type withdrawn / user opts out)──▶ [CANCELLED]
```

```
INV-023: No alert depends on sound                                [NEW in v1.1] ⭐
  - Rule: Every delivery channel is visual. No audio-only channel exists, and none can be added
  - Violation: The users of this application are deaf and hard-of-hearing people. An alert they
    cannot perceive is not a degraded alert — it is information the system failed to deliver
  - Implementation: The notification_channel enum admits only PUSH, IN_APP and EMAIL. Encoding it
    as a constraint rather than a guideline is what makes it impossible to violate by accident

INV-024: A push has a device                                      [NEW in v1.1]
  - Rule: A notification on the PUSH channel requires a target device; on other channels it must
    not carry one
  - Violation: A delivery with nowhere to go, stuck PENDING forever
  - Implementation: CHECK constraint (channel = 'PUSH') = (device_id IS NOT NULL)

INV-025: A disabled switch suppresses every delivery              [NEW in v1.1]
  - Rule: A user with notificationsEnabled = false receives no new notification through any channel.
    Ones already received stay visible in their history
  - Violation: The one control RF4 grants the user does not work
  - Implementation: Checked before creating the notification, not before delivering it
```

---

### Entity: `UserDevice` — **new in v1.1**

**Context:** Notifications

| Attribute | Type | Description | Required | Rules |
|-----------|------|-------------|----------|-------|
| `id` | UUID | Identifier | Yes | — |
| `userId` | `UserId` (VO) | Owner | Yes | — |
| `pushToken` | string | Provider token | Yes | Unique. **Treated as a credential** |
| `platform` | `DevicePlatform` (VO) | `ANDROID`, `IOS` or `WEB` | Yes | — |
| `isActive` | boolean | Whether it can receive deliveries | Yes | Deactivated when the provider rejects its token |
| `registeredAt` / `revokedAt` | DateTime | Registration and revocation | — | — |

---

### Entity: `PasswordPolicy` — **new in v1.1** · **moved to Identity & Access in v1.2**

**Context:** Identity & Access
**Description:** The password rules in force, and the history of the rules in force before. It is not an
aggregate of a user — it is the rule that applies to all of them, which is why it is its own entity and
not a set of constants.

| Attribute | Type | Description | Required | Rules |
|-----------|------|-------------|----------|-------|
| `id` | UUID | Identifier | Yes | — |
| `minLength` / `maxLength` | int | Length bounds | Yes | `minLength <= maxLength` |
| `requiresUppercase` / `requiresLowercase` / `requiresNumbers` / `requiresSymbols` | boolean | Required character classes | Yes | — |
| `isActive` | boolean | Whether it is the policy in force | Yes | Exactly one active (INV-026) |
| `createdAt` / `updatedAt` | DateTime | Dates | Yes | — |

```
INV-026: Exactly one password policy is in force                  [NEW in v1.1]
  - Rule: Only one policy has isActive = true. Superseded policies are preserved as history, never
    overwritten — knowing which rules were in force when an account was created is auditable
  - Violation: Two contradictory policies, and validation depending on which row is read first
  - Implementation: Partial unique index on is_active = true
```

---

### Entity: `Achievement` / `UserAchievement` ⏸ — **new in v1.1, pending RF8**

**Context:** Gamification

| Entity | Attributes |
|--------|-----------|
| `Achievement` | `id`, `name` (unique), `description`, `targetCount` (> 0), `createdAt` |
| `UserAchievement` | `id`, `userId`, `achievementId`, `achievedAt` — unique per (user, achievement) |

```
INV-027: An achievement unlocks once per user                     [NEW in v1.1] ⏸
  - Rule: A user unlocks a given achievement exactly once, however much they keep using the app
  - Violation: Repeated notifications for the same achievement; a meaningless reward
  - Implementation: Unique index (user_id, achievement_id)
```

> ⏸ **Provisional.** These two entities exist only if RF8 is approved and added to the SRS. Until then
> nothing here is built. See `04-requirements/traceability-matrix.md` § 6, GAP-01.

**Daily challenges (implemented in profile-service; not numbered as INV).** Rules from
[ADR-009](../05-architecture/decisions/records/ADR-009-daily-challenges.md) and
[ADR-010](../05-architecture/decisions/records/ADR-010-challenge-points-medals.md):

- A user has at most one challenge per day (Bogota time); the assignment keeps a snapshot of the definition.
- Only a saved and confirmed translation advances it, once; the counter never exceeds the goal and a completed challenge is not reopened.
- The reward is granted once per assignment, even if the user turned notifications off; only the notice depends on that switch.
- Medals for 500, 1,000 and 3,000 challenge points are computed from the persisted rewards and grant no extra points.

---

## System Value Objects

| Value Object | Context | Validation rules |
|--------------|---------|------------------|
| `UserId` | Shared (Shared Kernel) | Valid UUID |
| `Email` | Identity | Format `text@domain.ext`; normalized to lowercase |
| `PasswordHash` | Identity | Only built from plain text through hashing; never exposed |
| `AccountStatus` | Identity | `PENDING_VERIFICATION` \| `ACTIVE` \| `BLOCKED` \| `DELETED` — ⚠️ **ALIGN-05: the model calls them `INACTIVE` / `ACTIVE` / `BLOCKED` + `deleted_at`** |
| `TokenType` | Identity | `EMAIL_VERIFICATION` \| `PASSWORD_RESET` — **v1.1** |
| `AuthProvider` | Identity | `GOOGLE` \| `FACEBOOK` — **v1.1** |
| `Gloss` | Translation | Not empty, uppercase, unaccented; must exist in the active model's vocabulary. **Same value as `SignCode`** |
| `Confidence` | Translation | `0.0 ≤ value ≤ 1.0` (INV-006) |
| `TranslatedText` | Translation | Not empty |
| `OutputMode` | Translation | `TEXT` \| `AUDIO` \| `BOTH` — ⚠️ **ALIGN-07: the model has no `BOTH`** |
| `SessionStatus` | Translation | `STARTED` \| `ACTIVE` \| `ENDED` \| `INTERRUPTED` — ⚠️ **ALIGN-01: no table stores it** |
| `ModelVersion` | Translation | Semantic version `major.minor.patch` |
| `SignCode` | Lexicon | Stable, language-independent identifier. Never renamed once published (INV-018) — **v1.1** |
| `SignType` | Lexicon | `LETTER` \| `WORD` \| `PHRASE` — **v1.1** |
| `SignLanguage` | Lexicon | `LSC` (Colombian Sign Language, ISO 639-3 `csn`) — **content language, not interface language** — **v1.1** |
| `LetterCode` | Lexicon | One character, A–Z plus Ñ. Only when the type is `LETTER` — **v1.1** |
| `ContentStatus` | Lexicon | `DRAFT` \| `ACTIVE` \| `INACTIVE` — **v1.1** |
| `ResourceType` | Lexicon | `IMAGE` \| `VIDEO` \| `ANIMATION` — **v1.1** |
| `ConsentStatus` | Consent | `GRANTED` \| `REVOKED` |
| `PolicyVersion` | Consent | Identifier of the data-processing policy version |
| `AnonymousSubjectId` | Consent | Non-reversible pseudonym — ⚠️ **ALIGN-02: the model identifies the performer instead** |
| `SampleType` | Consent | `LANDMARKS` \| `VIDEO` \| `IMAGE`. `LANDMARKS` is the main one: coordinates, not video — **v1.1** |
| `Theme` | Profile | `LIGHT` \| `DARK` |
| `AppLanguage` | Profile / Lexicon | `es-CO` \| `en-US` — **interface language, not sign language** — ⚠️ **ALIGN-08: the model calls them `ES` / `EN`** |
| `NotificationChannel` | Notifications | `PUSH` \| `IN_APP` \| `EMAIL`. **All visual; no audio-only value exists** (INV-023) — **v1.1** |
| `DeliveryStatus` | Notifications | `PENDING` \| `SENT` \| `FAILED` \| `READ` \| `CANCELLED` — **v1.1** |
| `DevicePlatform` | Notifications | `ANDROID` \| `IOS` \| `WEB` — **v1.1** |
| `ReferenceEntity` | Notifications / Analytics | Type of record a `referenceId` points at, with no foreign key — **v1.1** |
| `UsageSection` | Analytics | Application section a user entered — **v1.1** |
| `UsageEventType` | Analytics | Kind of recorded fact: translation started, completed, failed, audio played, search performed… — **v1.1** |
| `ErrorType` | Cross-cutting | `VALIDATION` \| `AUTH` \| `PERMISSION` \| `NOT_FOUND` \| `MODEL_INFERENCE` \| `EXTERNAL_SERVICE` \| `DATABASE` \| `UNEXPECTED` — **v1.1** |
| `DateRange` | Analytics | Start date ≤ end date |

> **`UserRole` disappeared as a value object in v1.1.** It became the `Role` entity. A value object
> cannot hold permissions, and that is exactly what the role has to do now.

**Code example:**

```typescript
// Value Object — immutable, validated in the constructor
class Confidence {
  private readonly value: number;

  constructor(value: number) {
    if (value < 0 || value > 1) {
      throw new DomainException(`INV-006: confidence out of range: ${value}`);
    }
    this.value = value;
  }

  isBelow(threshold: Confidence): boolean { return this.value < threshold.value; }
  equals(other: Confidence): boolean { return this.value === other.value; }
  toString(): string { return this.value.toFixed(2); }
}
```

---

## System Aggregates

### Aggregate: `TranslationSession` ⭐

**Root:** `TranslationSession`
**Internal entities:** `Translation` — meaningless outside the session that produced it
**Value Objects:** `OutputMode`, `ModelVersion`, `Gloss`, `Confidence`, `TranslatedText`

```
AGGR-INV-001: Every Translation in the session has confidence ≥ the session model's threshold
AGGR-INV-002: Translations cannot be added to a session that is not in ACTIVE status
AGGR-INV-003: The sequence field of the translations is consecutive and gapless within the session
AGGR-INV-004: A session in a terminal state (ENDED or INTERRUPTED) never changes state again
```

**Why do these objects form an aggregate?** A translation does not exist without the session that
produced it: they share the model version, the output mode and the moment. Keeping them consistent as a
unit is what makes it possible to answer "this translation was produced with model v1.3, in audio mode,
in the 10:42 session" without querying three tables. The history the user sees is a projection of this
aggregate.

### Aggregate: `User`
**Root:** `User` · **Internal entities:** `ExternalProviderLink` · **VOs:** `Email`, `PasswordHash`, `UserRole`, `AccountStatus`

### Aggregate: `ConsentGrant`
**Root:** `ConsentGrant` · No internal entities · **VOs:** `ConsentStatus`, `PolicyVersion`, `ConsentPurpose`

---

## Summary table of tactical building blocks

| Name | Type | Bounded Context | Aggregate Root? | Table(s) in the v8 model |
|------|------|-----------------|-----------------|--------------------------|
| `User` | Entity | Identity & Access | Yes | `users` |
| `ExternalProviderLink` | Entity | Identity & Access | No — inside `User` | `user_auth_providers` |
| `LoginSession` | Entity | Identity & Access | Yes — **v1.1** | `user_sessions`, `refresh_tokens` |
| `PasswordResetRequest` | Entity | Identity & Access | Yes | `user_tokens` — ⚠️ ALIGN-09: one table also covers email verification |
| `Role` | Entity | Identity & Access | Yes — **v1.1** | `roles`, `user_roles` |
| `Permission` | Entity | Identity & Access | Yes — **v1.1** | `permissions`, `role_permissions` |
| `TranslationSession` | Entity | Recognition & Translation | **Yes** | ⚠️ **none — ALIGN-01** |
| `Translation` | Entity | Recognition & Translation | No — inside the session | `translations`, `translation_signs` |
| `RecognitionModel` | Entity | Recognition & Translation | Yes | `ai_models` |
| `ConsentGrant` | Entity | Consent & Personal Data | Yes | ⚠️ no table of its own — fields on `users` and `gesture_samples` |
| `TrainingSample` | Entity | Consent & Personal Data | Yes | `gesture_samples` (MongoDB) — ⚠️ ALIGN-02 |
| `DataDeletionRequest` | Entity | Consent & Personal Data | Yes | ⚠️ **none** — only `users.deleted_at` |
| `UserProfile` | Entity | Profile & Preferences | Yes | `user_preferences` |
| `Sign` | Entity | Learning & Lexicon | Yes — **v1.1, replaces `AlphabetLetter`** | `sign_lexicon` |
| `SignLocalization` | Entity | Learning & Lexicon | No — inside `Sign` — **v1.1** | `sign_localizations` |
| `Category` | Entity | Learning & Lexicon | Yes — **v1.1** | `categories` |
| `MultimediaResource` | Entity | Learning & Lexicon | No — inside `Sign` — **v1.1** | `multimedia_resources` |
| `NotificationType` | Entity | Notifications | Yes — **v1.1** | `notification_types` |
| `Notification` | Entity | Notifications | Yes — **v1.1** | `notifications` |
| `UserDevice` | Entity | Notifications | Yes — **v1.1** | `user_devices` |
| `Achievement` ⏸ | Entity | Gamification | Yes — **v1.1** | `achievements` |
| `UserAchievement` ⏸ | Entity | Gamification | No — inside `Achievement` — **v1.1** | `user_achievements` |
| `UsageEvent` | Entity | Usage Analytics | Yes — **v1.1** | `usage_events` |
| `UsageReport` | **Read model** | Usage Analytics | N/A — not an aggregate | none, by design |
| `PasswordPolicy` | Entity | Identity & Access — **v1.2** | Yes | `identity.password_policies` |
| `AuditEntry` | Entity | Cross-cutting | Yes — **v1.1** | `audit_logs` |
| `ErrorEntry` | Entity | Cross-cutting | Yes — **v1.1** | `error_logs` |
| `Email`, `Confidence`, `Gloss`, `OutputMode`, `Theme`, `DateRange`… | Value Objects | Various / shared | N/A | enums and columns |
| `SignRecognitionService` | Domain Service | Recognition & Translation | N/A | — |
| `ConsentPolicyService` | Domain Service | Consent & Personal Data | N/A | — |

> **The table column is the point of this table (v1.1).** An entity with no table is a promise nobody
> can keep, and a table with no entity is code with no justification. Three rows carry a ⚠️:
> `TranslationSession` (the Core aggregate root, with no table), `ConsentGrant` (an aggregate with a
> lifecycle, flattened into columns on two other tables) and `DataDeletionRequest` (an entity reduced to
> a timestamp). All three are listed in `domain-map.md` §6.

> `UsageReport` **is not an entity**: it is a projection rebuilt from events. Treating it as an aggregate
> would create two sources of truth for the same data.

---

## Domain Services

A **Domain Service** is business logic that does not naturally belong to any entity. Use it when the
operation involves several entities or when it would be unnatural for it to belong to a single one.

```typescript
// Domain Service — stateless, orchestrates between entities
class SignRecognitionService {
  constructor(private readonly recognizer: SignRecognitionPort) {}   // ACL towards the inference engine

  async recognize(frames: FrameSequence, model: RecognitionModel): Promise<RecognitionResult> {
    const raw = await this.recognizer.infer(frames, model.version);
    const gloss = new Gloss(raw.label);
    const confidence = new Confidence(raw.score);

    if (!model.supports(gloss)) {
      return RecognitionResult.unsupported(gloss);   // the sign is not in the v1 vocabulary
    }
    return RecognitionResult.of(gloss, confidence);
  }
}
```

```typescript
// Domain Service — decides whether a sample may be kept (RNF8)
class ConsentPolicyService {
  canStoreTrainingSample(grant: ConsentGrant | null): boolean {
    return grant !== null
        && grant.status === ConsentStatus.GRANTED
        && grant.purpose === ConsentPurpose.MODEL_TRAINING;   // INV-008
  }
}
```

---

## What does NOT belong in this document

These rules appear in the SRS but **are not domain invariants**. They are documented where they belong:

| SRS rule | Why it is not an invariant | Where it goes |
|----------|---------------------------|---------------|
| "Recognition must not exceed 1 second" (RNF1) | A slow model is still a valid model | `05-architecture/` and `11-quality/` |
| "The app must run on Android 9+ and iOS 14+" (RNF3) | Platform constraint | `05-architecture/` |
| "The navigation bar must be visible on every screen" (ERF2.1) | Interface requirement | `12-ux-ui/` |
| "The system supports 100 concurrent users" (RNF5) | Capacity requirement | `05-architecture/` |

> Confusing a non-functional requirement with a domain invariant is the most frequent mistake when
> filling in this section — and the easiest one to spot in a defense.

---

## Correlation with code

| Domain artifact | Folder in code | File |
|-----------------|----------------|------|
| Aggregate `TranslationSession` | `backend/src/modules/translation/domain/` | `TranslationSession.ts` |
| Entity `Translation` | `backend/src/modules/translation/domain/` | `Translation.ts` |
| Value Object `Confidence` | `backend/src/modules/translation/domain/value-objects/` | `Confidence.ts` |
| Value Object `Email` | `backend/src/shared/domain/value-objects/` | `Email.ts` |
| Aggregate `User` | `backend/src/modules/identity/domain/` | `User.ts` |
| Aggregate `ConsentGrant` | `backend/src/modules/consent/domain/` | `ConsentGrant.ts` |
| Domain Service `SignRecognitionService` | `backend/src/modules/translation/domain/services/` | `SignRecognitionService.ts` |
| Port `SignRecognitionPort` | `backend/src/modules/translation/domain/ports/` | `SignRecognitionPort.ts` |
| Repository `TranslationSessionRepository` | `backend/src/modules/translation/domain/ports/` | `TranslationSessionRepository.ts` |

> The hexagonal structure is detailed in `05-architecture/hexagonal-architecture.md`.
> Every invariant in this document should have at least one unit test in `11-quality/`.
