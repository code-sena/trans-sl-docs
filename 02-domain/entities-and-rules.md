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

**Version:** v1.0 · **Last updated:** 2026-08-31

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
are validated on every operation. In this project they are numbered INV-001 through INV-013.

---

## System entities

### Entity: `User`

**Context:** Identity & Access
**Description:** Holder of an application account, with credentials, role and status.

**Attributes:**

| Attribute | Type | Description | Required | Rules |
|-----------|------|-------------|----------|-------|
| `id` | UUID | Unique identifier | Yes | Auto-generated on creation |
| `name` | string | User's name | Yes | 2 to 80 characters |
| `email` | `Email` (VO) | Account email | Yes | Unique across the system (INV-001) |
| `passwordHash` | `PasswordHash` (VO) | Password hash | No | Absent if only an external provider is used |
| `providers` | `ExternalProviderLink[]` | Google/Facebook links | No | At most one per provider (INV-004) |
| `role` | `UserRole` (VO) | `USER` or `ADMIN` | Yes | Defaults to `USER` |
| `status` | `AccountStatus` (VO) | Account status | Yes | See lifecycle |
| `termsAcceptedAt` | DateTime | When terms were accepted | Yes | No registration without it (INV-002) |
| `failedLoginAttempts` | int | Consecutive failed attempts | Yes | Reset on a successful sign-in |
| `createdAt` | DateTime | Creation date | Yes | Immutable |
| `updatedAt` | DateTime | Last modification | Yes | Set automatically |

**Lifecycle:**

```
[PENDING_VERIFICATION] ──(verifies email)──▶ [ACTIVE] ──(requests deletion)──▶ [DELETED]
                                                │  ▲
                              (5 failed         │  │ (lockout expires or
                               attempts)        ▼  │  admin releases it)
                                             [LOCKED]
```

| State | Description | Allowed transitions |
|-------|-------------|---------------------|
| `PENDING_VERIFICATION` | Registered but email not confirmed | → `ACTIVE`, → `DELETED` |
| `ACTIVE` | May use the application | → `LOCKED`, → `DELETED` |
| `LOCKED` | Temporarily locked after unauthorized access attempts (RNF4) | → `ACTIVE`, → `DELETED` |
| `DELETED` | Deletion requested by the data subject (RNF8) | Terminal state |

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

  registerFailedLogin(): void {
    this.failedLoginAttempts += 1;
    if (this.failedLoginAttempts >= 5) {
      this.status = AccountStatus.LOCKED;           // RNF4
      this.addEvent(new AccountLocked(this.id));
    }
  }
}
```

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
INV-005: Every translation belongs to a session and to a user
  - Rule: No Translation exists outside a TranslationSession
  - Violation: DomainException when trying to create one standalone
  - Implementation: Translation's constructor is private; only session.addTranslation() creates one

INV-006: Confidence within range
  - Rule: Confidence is always between 0.0 and 1.0
  - Violation: DomainException in the VO constructor
  - Implementation: Validation in Confidence.constructor()

INV-007: Confidence below the threshold is not a confirmed translation
  - Rule: If confidence < the configured threshold, the result is not presented as a confirmed
    translation nor stored in the history; RecognitionFailed is emitted instead
  - Violation: The user would be shown an incorrect translation as if it were correct
  - Implementation: session.addTranslation() compares against the threshold before appending

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
INV-010: Kept samples are dissociated from identity
  - Rule: A TrainingSample cannot carry a userId nor any data allowing re-identification of the subject
  - Violation: Direct breach of the RNF8 acceptance criterion
  - Implementation: The entity has no userId attribute. Anonymization happens at sample creation time,
    not afterwards
```

---

### Entity: `AlphabetLetter`

**Context:** Learning
**Description:** A letter of the LSC fingerspelling alphabet with its verified visual resource.

| Attribute | Type | Description | Required | Rules |
|-----------|------|-------------|----------|-------|
| `letter` | `LetterCode` (VO) | Letter (A–Z, Ñ) | Yes | It is the identifier; unique |
| `resource` | `VisualResource` (VO) | 2D image or animation | Yes | Exactly one per letter |
| `description` | string | Text description of the hand configuration | Yes | Accessible to screen readers |
| `verifiedBy` | string | Interpreter who verified it | Yes | — |
| `verifiedAt` | DateTime | Verification date | Yes | — |

```
INV-013: The alphabet is complete and verified
  - Rule: Exactly 27 letters exist (A–Z plus Ñ), each with a single verified visual resource
  - Violation: The alphabet module is not released incomplete
  - Implementation: Catalog integrity test at startup plus validation when loading content
```

---

### Entity: `RecognitionModel`

**Context:** Recognition & Translation
**Description:** Version of the recognition model in use. It exists as an entity because the SRS
promises continuous vocabulary updates: the system must know which version produced each translation.

| Attribute | Type | Description | Required |
|-----------|------|-------------|----------|
| `id` | UUID | Identifier | Yes |
| `version` | `ModelVersion` (VO) | Semantic version | Yes |
| `confidenceThreshold` | `Confidence` (VO) | Minimum acceptable confidence (INV-007) | Yes |
| `supportedGlosses` | `Gloss[]` | Covered vocabulary | Yes |
| `isActive` | boolean | Whether it is the production version | Yes |
| `releasedAt` | DateTime | Release date | Yes |

---

## System Value Objects

| Value Object | Context | Validation rules |
|--------------|---------|------------------|
| `UserId` | Shared (Shared Kernel) | Valid UUID |
| `Email` | Identity | Format `text@domain.ext`; normalized to lowercase |
| `PasswordHash` | Identity | Only built from plain text through hashing; never exposed |
| `UserRole` | Identity | `USER` \| `ADMIN` |
| `AccountStatus` | Identity | `PENDING_VERIFICATION` \| `ACTIVE` \| `LOCKED` \| `DELETED` |
| `Gloss` | Translation | Not empty, uppercase, unaccented; must exist in the active model's vocabulary |
| `Confidence` | Translation | `0.0 ≤ value ≤ 1.0` (INV-006) |
| `TranslatedText` | Translation | Not empty |
| `OutputMode` | Translation | `TEXT` \| `AUDIO` \| `BOTH` |
| `SessionStatus` | Translation | `STARTED` \| `ACTIVE` \| `ENDED` \| `INTERRUPTED` |
| `ModelVersion` | Translation | Semantic version `major.minor.patch` |
| `ConsentStatus` | Consent | `GRANTED` \| `REVOKED` |
| `PolicyVersion` | Consent | Identifier of the data-processing policy version |
| `AnonymousSubjectId` | Consent | Non-reversible pseudonym |
| `Theme` | Profile | `LIGHT` \| `DARK` |
| `AppLanguage` | Profile | `es-CO` \| `en-US` — **interface language, not sign language** |
| `DateRange` | Analytics | Start date ≤ end date |

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

| Name | Type | Bounded Context | Aggregate Root? |
|------|------|-----------------|-----------------|
| `User` | Entity | Identity & Access | Yes |
| `ExternalProviderLink` | Entity | Identity & Access | No — inside `User` |
| `PasswordResetRequest` | Entity | Identity & Access | Yes |
| `TranslationSession` | Entity | Recognition & Translation | **Yes** |
| `Translation` | Entity | Recognition & Translation | No — inside the session |
| `RecognitionModel` | Entity | Recognition & Translation | Yes |
| `ConsentGrant` | Entity | Consent & Personal Data | Yes |
| `TrainingSample` | Entity | Consent & Personal Data | Yes |
| `DataDeletionRequest` | Entity | Consent & Personal Data | Yes |
| `UserProfile` | Entity | Profile & Preferences | Yes |
| `AlphabetLetter` | Entity | Learning | Yes |
| `UsageReport` | **Read model** | Usage Analytics | N/A — not an aggregate |
| `Email`, `Confidence`, `Gloss`, `OutputMode`, `Theme`, `DateRange`… | Value Objects | Various / shared | N/A |
| `SignRecognitionService` | Domain Service | Recognition & Translation | N/A |
| `ConsentPolicyService` | Domain Service | Consent & Personal Data | N/A |

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
