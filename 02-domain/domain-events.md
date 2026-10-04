# Domain Events — Traduce Señas

> A domain event is a fact that occurred in the business. Events are the backbone of communication
> between bounded contexts. The name is ALWAYS in past tense and in the ubiquitous language of the domain.

**Version:** v1.1 · **Last updated:** 2026-09-08

> **What changed in v1.2.** `PasswordPolicyChanged` is an Identity & Access event, not a cross-cutting
> one: `PasswordPolicy` moved into that context. See `domain-map.md` §5.
>
> **What changed in v1.1.** Realigned with the v8 persistence model. Twenty-two events added for the domains
> the model introduced: the notification lifecycle, device registration, sign and model publication,
> sample capture and validation, role assignment and the password policy. The catalog goes from 18 to
> 40 events. `AlphabetLetterViewed` is generalized into `SignViewed`, since the alphabet turned out to
> be a subset of the sign catalog.

> **Channel in this project:** **RabbitMQ between services**. Traduce Señas is a microservices
> architecture, so events are published to the topic exchange `traduce.events` with routing key
> `<service>.<event>` (for example `iam.UserRegistered`, `recognition.TranslationCompleted`,
> `lexicon.SignActivated`). The sections marked `[IF DISTRIBUTED]` now apply: schema evolution,
> retries and the dead letter queue are part of the design.
>
> ⚠️ **v1.1: there is no `domain_events` table in the v8 model.** Either it is added, or the claim of
> event traceability is dropped. With a broker, a failed event ends in the dead letter queue, but
> "which events preceded this bug" still needs persistence in each service.
> See `domain-map.md` §6, ALIGN-04.

---

## What is a domain event

A **domain event** communicates that something important occurred. It is an immutable message that
describes the fact in past tense.

```
✓ TranslationProduced
✓ ConsentRevoked
✓ UserRegistered
✓ RecognitionFailed

✗ StartTranslationSession  (this is a command, not an event)
✗ TranslationUpdated       (too generic — what changed?)
✗ UserEvent                (does not indicate what occurred)
```

### Difference between Command and Event

| Concept | Intent | Tense | Can fail? |
|---------|--------|-------|-----------|
| **Command** | Instruction to do something | Present | Yes |
| **Event** | Notification of something that occurred | Past | No — it already happened |

```
User → [StartTranslationSession] → System → [TranslationSessionStarted] → other contexts
            (command)                            (event)
```

In Traduce Señas the typical confusion is between *turning the camera on* and *the session started*:
`ActivateTranslationMode` is what the user asks for; `TranslationSessionStarted` is what occurred once
the system managed to do it.

---

## Event catalog

### Context: Identity & Access

#### `UserRegistered`

| Field | Value |
|-------|-------|
| **Bounded Context** | Identity & Access |
| **Aggregate** | `User` |
| **Trigger** | Successful registration with terms and conditions accepted (ERF1.1) |
| **Consumers** | Profile & Preferences (creates the profile with default preferences), Usage Analytics, mail service (verification) |
| **Channel (topic)** | `iam.UserRegistered` (RabbitMQ, exchange `traduce.events`) |
| **Schema version** | `v1` |

```json
{
  "eventId": "550e8400-e29b-41d4-a716-446655440000",
  "eventType": "UserRegistered",
  "aggregateId": "9f1c2b34-5d6e-4f70-8a91-b2c3d4e5f601",
  "aggregateType": "User",
  "occurredAt": "2026-08-31T15:42:10Z",
  "version": 1,
  "payload": {
    "userId": "9f1c2b34-5d6e-4f70-8a91-b2c3d4e5f601",
    "email": "user@example.com",
    "name": "María Rodríguez",
    "role": "USER",
    "termsAcceptedAt": "2026-08-31T15:42:09Z"
  },
  "metadata": {
    "correlationId": "1a2b3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d",
    "userId": "9f1c2b34-5d6e-4f70-8a91-b2c3d4e5f601"
  }
}
```

| Consumer | Action | Idempotent? |
|----------|--------|-------------|
| Profile & Preferences | Creates `UserProfile` with `LIGHT` theme and `es-CO` language | Yes — no-op if the profile already exists |
| Usage Analytics | Increments the day's registration count | Yes — uses `eventId` as the key |
| Mail service | Sends the verification email | Yes — checks whether it was already sent |

---

#### `UserSignedIn`

| Field | Value |
|-------|-------|
| **Aggregate** | `User` · **Trigger:** valid sign-in, with native credentials or with Google/Facebook (ERF1.2) |
| **Consumers** | Usage Analytics (time of use per user, RF6) |

```json
{
  "eventType": "UserSignedIn",
  "payload": { "userId": "9f1c…", "method": "GOOGLE", "signedInAt": "2026-08-31T15:50:00Z" }
}
```

`method` takes the values `PASSWORD`, `GOOGLE` or `FACEBOOK`.

---

#### `ExternalProviderLinked`
**Aggregate:** `User` · **Trigger:** the user links a Google or Facebook account to their existing account (ERF1.2)
**Consumers:** none today — recorded for security auditing
**Payload:** `{ userId, provider, externalId, linkedAt }`

#### `PasswordResetRequested`
**Aggregate:** `PasswordResetRequest` · **Trigger:** the user requests password recovery (ERF1.3)
**Consumers:** mail service (sends the reset link)
**Payload:** `{ userId, email, resetToken, expiresAt }`
> The token is never written to the events table in plain text: only its hash is stored.

#### `PasswordChanged`
**Aggregate:** `User` · **Trigger:** completed reset or change from the profile (ERF1.3, ERF5.3)
**Consumers:** mail service (security notice to the account holder)
**Payload:** `{ userId, changedAt, source: "RESET" | "PROFILE" }`

#### `AccountLocked` — **revised in v1.1**
**Aggregate:** `User` · **Trigger:** a lockout level is reached after consecutive failed attempts (RNF4, INV-014)
**Consumers:** Notifications (alerts the holder), Usage Analytics
**Payload:** `{ userId, lockedAt, lockoutLevel, lockedUntil }`
> The lockout is temporary and lifts on its own: `lockedUntil` is a date, not a flag. v1.0 carried
> `failedAttempts` and `unlockAt` on the assumption of a single fixed lockout at five failures.

#### `AccountBlocked` — **new in v1.1**
**Aggregate:** `User` · **Trigger:** the lockout escalation is exhausted (RNF4, INV-014)
**Consumers:** Notifications (alerts the holder), Usage Analytics, security audit
**Payload:** `{ userId, blockedAt, lockoutLevel }`
> Different from `AccountLocked`: this one **does not lift on its own**. Only an administrator restores
> the account. Distinguishing the two events is what lets Analytics tell "a user who mistyped their
> password" from "an account under attack".

#### `EmailVerified` — **new in v1.1**
**Aggregate:** `User` · **Trigger:** the user validates the 6-digit code sent at registration
**Consumers:** Identity (activates the account), Usage Analytics
**Payload:** `{ userId, verifiedAt }`

#### `RoleAssigned` / `RoleRevoked` — **new in v1.1**
**Aggregate:** `Role` · **Trigger:** an administrator grants or removes a role from a user (INV-016)
**Consumers:** change audit — **always**
**Payload:** `{ userId, roleId, roleName, assignedBy, assignedAt }`
> A permission change is exactly the kind of fact you need recorded when something later goes wrong.
> This event always ends up in `audit_logs`.

#### `AccountDeleted` — **new in v1.1**
**Aggregate:** `User` · **Trigger:** the user's account deletion completes (RNF8)
**Consumers:** Usage Analytics, Audit — both keep their records with the identity detached
**Payload:** `{ userId, deletedAt }`
> The event carries no personal data: by the time it is emitted, there is none left to carry.

---

### Context: Recognition & Translation ⭐ Core

#### `TranslationSessionStarted`

| Field | Value |
|-------|-------|
| **Aggregate** | `TranslationSession` |
| **Trigger** | The user turns translation mode on and the camera is ready (ERF3.1) |
| **Consumers** | Usage Analytics |
| **Channel (topic)** | `recognition.TranslationSessionStarted` (RabbitMQ, exchange `traduce.events`) |

```json
{
  "eventType": "TranslationSessionStarted",
  "aggregateType": "TranslationSession",
  "payload": {
    "sessionId": "3c4d5e6f-…",
    "userId": "9f1c…",
    "outputMode": "BOTH",
    "modelVersion": "1.3.0",
    "startedAt": "2026-08-31T16:02:11Z"
  }
}
```

---

#### `TranslationProduced` ⭐ the system's central event

| Field | Value |
|-------|-------|
| **Aggregate** | `TranslationSession` |
| **Trigger** | A sign is recognized above the confidence threshold and delivered to the user (ERF3.2) |
| **Consumers** | History (projection of the aggregate), Usage Analytics, Notifications |
| **Channel (topic)** | `recognition.TranslationProduced` (RabbitMQ, exchange `traduce.events`) |

```json
{
  "eventId": "7b8c9d0e-…",
  "eventType": "TranslationProduced",
  "aggregateId": "3c4d5e6f-…",
  "aggregateType": "TranslationSession",
  "occurredAt": "2026-08-31T16:02:19Z",
  "version": 1,
  "payload": {
    "sessionId": "3c4d5e6f-…",
    "translationId": "aa11bb22-…",
    "userId": "9f1c…",
    "gloss": "THANK-YOU",
    "text": "Thank you",
    "confidence": 0.94,
    "outputMode": "BOTH",
    "modelVersion": "1.3.0",
    "producedAt": "2026-08-31T16:02:19Z"
  },
  "metadata": {
    "correlationId": "1a2b3c4d-…",
    "causationId": "6f7e8d9c-…",
    "userId": "9f1c…"
  }
}
```

| Consumer | Action | Idempotent? |
|----------|--------|-------------|
| History | Appends the entry to the user's recent translations (ERF5.5) | Yes — `translationId` is the key |
| Usage Analytics | Increments translations per day and per user (RF6) | Yes — uses `eventId` |
| Notifications | Shows the result on screen (RF4) | Yes |

> **Important:** this event **does not carry the video or the sample**. It carries the gloss and the text.
> The sample only exists if there is a valid consent grant, and it lives in the Consent context (INV-008).

---

#### `RecognitionFailed`

| Field | Value |
|-------|-------|
| **Aggregate** | `TranslationSession` |
| **Trigger** | Confidence fell below the threshold (INV-007), the sign is not in the model's vocabulary, or the inference engine failed |
| **Consumers** | Notifications (on-screen alert, RF4), Usage Analytics (problematic signs) |

```json
{
  "eventType": "RecognitionFailed",
  "payload": {
    "sessionId": "3c4d5e6f-…",
    "reason": "LOW_CONFIDENCE",
    "confidence": 0.41,
    "threshold": 0.75,
    "occurredAt": "2026-08-31T16:02:25Z"
  }
}
```

`reason` takes the values `LOW_CONFIDENCE`, `UNSUPPORTED_GLOSS` or `ENGINE_ERROR`.
A sign the model does not recognize **is not a technical exception: it is a business fact**, and that is
why it is an event and not a silent error. This is where the vocabulary to prioritize in the next model
version comes from.

---

#### `TranslationSessionEnded`
**Trigger:** the user turns translation mode off (ERF3.1)
**Consumers:** Usage Analytics (session duration, RF6)
**Payload:** `{ sessionId, userId, endedAt, translationCount, durationSeconds }`

#### `TranslationSessionInterrupted`
**Trigger:** camera permission denied, connection lost, or engine error (RNF7)
**Consumers:** Notifications (understandable error message), Usage Analytics
**Payload:** `{ sessionId, userId, reason, interruptedAt, translationCount }`
> Translations already produced are kept: an interruption does not destroy the user's work.

#### `TranslationDeleted`
**Trigger:** the user deletes an entry from their history (ERF5.5)
**Consumers:** Usage Analytics (adjusts counts)
**Payload:** `{ translationId, sessionId, userId, deletedAt }`
> Deletion is irreversible (INV-011). The event is kept as a record that it happened, without the
> content of the deleted translation.

---

### Context: Consent & Personal Data

#### `ConsentGranted`
**Aggregate:** `ConsentGrant` · **Trigger:** the data subject expressly authorizes the use of samples (RNF8)
**Consumers:** Recognition & Translation (enables sample retention)
**Payload:** `{ consentId, userId, purpose: "MODEL_TRAINING", policyVersion, grantedAt }`
> `grantedAt` is what makes the authorization **provable**, which is exactly what the RNF8 acceptance
> criterion requires.

#### `ConsentRevoked`
**Aggregate:** `ConsentGrant` · **Trigger:** the data subject revokes their authorization (RNF8)
**Consumers:** Recognition & Translation (stops keeping samples), Consent (anonymizes or purges what is pending)
**Payload:** `{ consentId, userId, revokedAt }`

#### `TrainingSampleAnonymized`
**Aggregate:** `TrainingSample` · **Trigger:** a sample is persisted with an irreversible pseudonym (INV-010)
**Consumers:** none — this is a compliance audit event
**Payload:** `{ sampleId, anonymousSubjectId, gloss, anonymizedAt }`

#### `AccountDeletionRequested`
**Aggregate:** `DataDeletionRequest` · **Trigger:** the data subject requests deletion of their account and data (RNF8)
**Consumers:** **every context that stores user data** — Identity, Profile, Translation, Consent
**Payload:** `{ requestId, userId, requestedAt }`
> It is the event with the most consumers in the system and the easiest one to forget. Each context is
> responsible for deleting its own data and reporting when it finished.

---

### Context: Profile & Preferences

#### `PreferencesChanged`
**Aggregate:** `UserProfile` · **Trigger:** light/dark theme or interface language change (ERF5.2, ERF5.4)
**Consumers:** the mobile app (applies the change), Usage Analytics
**Payload:** `{ userId, theme: "DARK", language: "es-CO", changedAt }`

---

### Context: Learning & Lexicon

#### `SignViewed` — **generalizes `AlphabetLetterViewed` in v1.1**
**Aggregate:** `Sign` · **Trigger:** the user consults a sign in the catalog, letter or word (ERF7.1)
**Consumers:** Usage Analytics — feeds the "most visited sections" metric of RF6
**Payload:** `{ signId, signCode: "GREETING_HELLO", signType: "WORD", userId, viewedAt }`
> `AlphabetLetterViewed` is now this event with `signType: "LETTER"`. Two events for the same fact
> would have meant two counters to add up every time somebody asks how much the catalog is used.

#### `LexiconSearchPerformed` — **new in v1.1**
**Aggregate:** — (query, not an aggregate) · **Trigger:** the user searches the catalog (RF7)
**Consumers:** Usage Analytics
**Payload:** `{ userId, query, resultCount, searchedAt }`
> **Searches with zero results are the most valuable metric this system produces.** They are a list,
> written by the users themselves, of the signs they expect to find and the catalog does not have.
> That list is what should decide the vocabulary of the next model version.

#### `SignPublished` — **new in v1.1**
**Aggregate:** `Sign` · **Trigger:** an administrator moves a sign from `DRAFT` to `ACTIVE` (INV-018, INV-019)
**Consumers:** change audit, mobile app (catalog cache invalidation)
**Payload:** `{ signId, signCode, signType, categoryId, publishedBy, publishedAt }`
> Publishing must verify that the active model recognizes the code (INV-018). Publishing a sign the
> recognizer does not know produces the worst kind of failure: the user signs correctly, and nothing
> happens.

#### `SignWithdrawn` — **new in v1.1**
**Aggregate:** `Sign` · **Trigger:** an administrator moves a sign to `INACTIVE`
**Consumers:** change audit, mobile app
**Payload:** `{ signId, signCode, withdrawnBy, withdrawnAt, reason }`

---

### Context: Notifications — **new in v1.1**

#### `DeviceRegistered`
**Aggregate:** `UserDevice` · **Trigger:** the user signs in on a device and grants the notification permission (RF4)
**Consumers:** Notifications
**Payload:** `{ deviceId, userId, platform, registeredAt }`
> The push token never travels in the payload. It is a credential.

#### `DeviceRevoked`
**Aggregate:** `UserDevice` · **Trigger:** the provider rejects the token, or the user signs out
**Consumers:** Notifications — stops attempting delivery to that device
**Payload:** `{ deviceId, userId, revokedAt, reason: "TOKEN_REJECTED" | "SIGNED_OUT" }`

#### `NotificationScheduled`
**Aggregate:** `Notification` · **Trigger:** a notification is created for future delivery (RF4)
**Consumers:** the delivery scheduler
**Payload:** `{ notificationId, userId, typeCode, channel, scheduledAt }`

#### `NotificationDelivered`
**Aggregate:** `Notification` · **Trigger:** the notification reaches the user through its channel (RF4)
**Consumers:** Usage Analytics
**Payload:** `{ notificationId, userId, typeCode, channel, sentAt }`

#### `NotificationDeliveryFailed`
**Aggregate:** `Notification` · **Trigger:** the channel provider rejects or fails the delivery
**Consumers:** Notifications (may revoke the device), error log
**Payload:** `{ notificationId, userId, channel, reason, failedAt }`
> **Why this event has to exist.** Without it there is no way to tell "not sent yet" from "tried and
> could not". Those are opposite situations: the first resolves itself, the second means something is
> broken and nobody finds out.

#### `NotificationRead`
**Aggregate:** `Notification` · **Trigger:** the user opens the notification (RF4)
**Consumers:** Usage Analytics — `NOTIFICATION_OPENED`
**Payload:** `{ notificationId, userId, readAt }`

#### `NotificationTypeWithdrawn`
**Aggregate:** `NotificationType` · **Trigger:** an administrator deactivates a type for every user
**Consumers:** Notifications — stops generating notifications of that type
**Payload:** `{ notificationTypeId, code, withdrawnBy, withdrawnAt }`

---

### Context: Recognition & Translation — model lifecycle

#### `RecognitionModelTrained` — **new in v1.1**
**Aggregate:** `RecognitionModel` · **Trigger:** a training run finishes and is registered (RF3)
**Consumers:** change audit
**Payload:** `{ modelId, version, trainedBy, trainedAt, sampleCount, signCount, accuracy }`

#### `RecognitionModelPublished` — **new in v1.1**
**Aggregate:** `RecognitionModel` · **Trigger:** an administrator activates a model version (INV-022)
**Consumers:** mobile app (downloads the artifact), Usage Analytics, change audit
**Payload:** `{ modelId, version, previousModelId, accuracy, storageReference, publishedAt }`
> Carries `previousModelId` on purpose: activating one model deactivates another, and the event says
> which. That is what makes a rollback a decision instead of an investigation.

---

### Context: Consent & Personal Data — capture lifecycle

#### `GestureSampleCaptured` — **new in v1.1**
**Aggregate:** `TrainingSample` · **Trigger:** a sample is recorded within a capture session (RF3, RNF8)
**Consumers:** compliance audit
**Payload:** `{ sampleId, captureSessionId, signCode, sampleType, recordedBy, consentGrantedAt, consentTermsVersion, capturedAt }`
> `consentGrantedAt` and `consentTermsVersion` travel with the event because that is what makes the
> authorization provable. A sample event with no consent evidence is a compliance defect, not a
> missing field.

#### `GestureSampleValidated` — **new in v1.1**
**Aggregate:** `TrainingSample` · **Trigger:** a linguist approves a sample (INV-008)
**Consumers:** the training pipeline — only validated samples enter it
**Payload:** `{ sampleId, validatedBy, validatedAt }`

#### `CaptureSessionDiscarded` — **new in v1.1**
**Aggregate:** `TrainingSample` · **Trigger:** an entire recording batch is discarded, or a collaborator withdraws their authorization (RNF8)
**Consumers:** compliance audit, the training pipeline
**Payload:** `{ captureSessionId, sampleCount, reason, discardedBy, discardedAt }`
> This is the event that makes a withdrawn authorization actually enforceable: the capture session is
> the unit that gets removed, not the individual sample.

---

### Identity & Access: password policy

#### `PasswordPolicyChanged` — **new in v1.1** · **context corrected in v1.2**
**Aggregate:** `PasswordPolicy` *(Identity & Access)* · **Trigger:** an administrator activates a new policy (INV-026)
**Consumers:** change audit
**Payload:** `{ policyId, previousPolicyId, changedBy, changedAt }`
> Existing passwords are not invalidated. The policy applies to the next password created or changed.

---

### Context: Gamification ⏸ — pending RF8

#### `AchievementUnlocked` ⏸ — **new in v1.1**
**Aggregate:** `UserAchievement` · **Trigger:** the user reaches an achievement's target count (INV-027)
**Consumers:** Notifications (in-app visual alert), Usage Analytics
**Payload:** `{ userAchievementId, userId, achievementId, achievementName, achievedAt }`
> Notifications consumes it through `reference_type: ACHIEVEMENT` and `reference_id`, **with no foreign
> key**. That is what keeps Notifications working if RF8 is rejected and this context disappears.

---

## Standard fields for all events

Every event carries this envelope:

| Field | Type | Description |
|-------|------|-------------|
| `eventId` | UUID | Unique event id (idempotency key) |
| `eventType` | string | Event name in `PascalCase` |
| `aggregateId` | UUID | Id of the aggregate that generated it |
| `aggregateType` | string | Aggregate type |
| `occurredAt` | ISO 8601 | When the business fact occurred |
| `version` | integer | Event schema version |
| `payload` | object | Event-specific data |
| `metadata.correlationId` | UUID | Traces one operation across several contexts |
| `metadata.causationId` | UUID | Id of the event or command that caused this event |
| `metadata.userId` | UUID | User who initiated the chain, if applicable |

> **Content rule:** no payload carries passwords, hashes, plain-text tokens, video, or biometric data.
> Events are persisted in the `domain_events` table and that table must not become a parallel store of
> personal data (RNF8).

---

## Event flow: translating a sign

```
User (deaf)
  │
  │  ActivateTranslationMode (command)
  ▼
[Aggregate: TranslationSession]
  │
  │  TranslationSessionStarted (event)
  └──────────────▶ [Usage Analytics] records the session start
  │
  │  ← the inference engine returns gloss + confidence (through the ACL)
  │
  ├── confidence ≥ threshold ──▶ TranslationProduced (event)
  │                               ├──▶ [History]       stores the translation
  │                               ├──▶ [Analytics]     +1 translation
  │                               └──▶ [Notifications] shows the text / plays the audio
  │
  └── confidence < threshold ──▶ RecognitionFailed (event)
                                  ├──▶ [Notifications] "sign not recognized, try again"
                                  └──▶ [Analytics]     records the problematic sign
  │
  │  DeactivateTranslationMode (command)
  ▼
  TranslationSessionEnded (event) ──▶ [Analytics] session duration
```

## Event flow: revoking consent

```
Data subject
  │
  │  RevokeConsent (command)
  ▼
[Aggregate: ConsentGrant]
  │
  │  ConsentRevoked (event)
  ├──▶ [Recognition & Translation] stops keeping samples — translation keeps working
  ├──▶ [Consent] purges or anonymizes pending samples
  └──▶ [Notifications] confirms to the subject that the authorization was revoked
```

> This second flow is literally the RNF8 criterion: *"if the user does not grant or revokes the
> authorization, the system must continue operating without storing samples, preserving the translation
> functionality"*.

---

## Policies — automatic reactions to events

A **policy** describes what happens automatically when an event arrives: the logic of
"whenever X occurs, do Y".

| Trigger event | Policy | Emitted command | Owning context |
|---------------|--------|-----------------|----------------|
| `TranslationProduced` | Whenever a translation is produced, append it to the user's history | `AppendToHistory` | Recognition & Translation |
| `TranslationProduced` | If a valid consent grant exists, keep the anonymized sample | `StoreTrainingSample` | Consent & Personal Data |
| `RecognitionFailed` | Show an on-screen alert without blocking navigation (RF4) | `ShowNotification` | Notifications |
| `ConsentRevoked` | Stop keeping samples while translation stays operational | `DisableSampleStorage` | Recognition & Translation |
| `AccountDeletionRequested` | Each context deletes the subject's data and reports completion | `PurgeUserData` | All |
| `AccountLocked` | Notify the holder of the lockout after unauthorized attempts (RNF4) | `SendSecurityAlert` | Identity & Access |
| `UserRegistered` | Create the profile with `LIGHT` theme and `es-CO` language | `CreateDefaultProfile` | Profile & Preferences |
| `TranslationSessionInterrupted` | Show an understandable error message and keep what was translated (RNF7) | `ShowNotification` | Notifications |
| **v1.1 —** `AccountBlocked` | Notify the holder and record it for security review | `SendSecurityAlert` | Identity & Access |
| **v1.1 —** `NotificationDeliveryFailed` | If the provider rejected the token, deactivate the device so no further delivery is attempted | `RevokeDevice` | Notifications |
| **v1.1 —** `DeviceRevoked` | Cancel the pending push notifications targeting that device | `CancelPendingPush` | Notifications |
| **v1.1 —** `RecognitionModelPublished` | Deactivate the previously active model — never two at once (INV-022) | `DeactivatePreviousModel` | Recognition & Translation |
| **v1.1 —** `ConsentRevoked` | Discard every capture session of that collaborator | `DiscardCaptureSessions` | Consent & Personal Data |
| **v1.1 —** `GestureSampleValidated` | Make the sample eligible for the next training run | `AddToTrainingSet` | Consent & Personal Data |
| **v1.1 —** `AchievementUnlocked` ⏸ | Emit an in-app visual alert referencing the achievement | `ShowNotification` | Notifications |
| **v1.1 —** `TranslationProduced` | Advance the user's progress towards the achievements that count translations | `AdvanceAchievementProgress` | Gamification ⏸ |
| **v1.1 —** `SignPublished` | Invalidate the catalog cache on the devices | `InvalidateCatalogCache` | Learning & Lexicon |

---

## Idempotency

With RabbitMQ, delivery is at-least-once, so **consumers must be idempotent**. Two real cases: a broker
redelivery, and the user tapping the translate button twice or the app resending a request after
a network drop. If that produces two identical history entries, the user sees a system bug.

```typescript
async function onTranslationProduced(event: TranslationProduced): Promise<void> {
  if (await eventStore.alreadyProcessed(event.eventId)) {
    logger.info(`Event ${event.eventId} already processed, ignoring`);
    return;
  }
  await historyProjection.append(event.payload);
  await eventStore.markProcessed(event.eventId);   // in the same transaction
}
```

---

## Schema evolution and resilience (applies: `[IF DISTRIBUTED]` is now the case)

> This section **applies**: each bounded context runs in its own service and events cross service
> boundaries through RabbitMQ.

**Compatible changes:** adding an optional field to the payload; adding a new event type; making a
required field optional.
**Incompatible changes:** removing a field; changing a field's type; making an optional field required;
renaming the event.

**Strategy:** publish `EventV2` alongside `EventV1`, migrate consumers one by one, announce the
deprecation of `V1` one sprint in advance, then stop publishing it.

**Dead Letter Queue (DLQ):** 3 to 5 retries with exponential backoff before the DLQ, 7-day retention,
alert when the DLQ has more than 0 messages.

---

## Event summary table

| Event | Origin context | Consumers | Version |
|-------|----------------|-----------|---------|
| `UserRegistered` | Identity & Access | Profile, Analytics, Mail | v1 |
| `UserSignedIn` | Identity & Access | Analytics | v1 |
| `ExternalProviderLinked` | Identity & Access | — (audit) | v1 |
| `PasswordResetRequested` | Identity & Access | Mail | v1 |
| `PasswordChanged` | Identity & Access | Mail | v1 |
| `AccountLocked` | Identity & Access | Notifications, Analytics | v1 |
| `TranslationSessionStarted` | Recognition & Translation | Analytics | v1 |
| `TranslationProduced` | Recognition & Translation | History, Analytics, Notifications | v1 |
| `RecognitionFailed` | Recognition & Translation | Notifications, Analytics | v1 |
| `TranslationSessionEnded` | Recognition & Translation | Analytics | v1 |
| `TranslationSessionInterrupted` | Recognition & Translation | Notifications, Analytics | v1 |
| `TranslationDeleted` | Recognition & Translation | Analytics | v1 |
| `ConsentGranted` | Consent & Personal Data | Recognition & Translation | v1 |
| `ConsentRevoked` | Consent & Personal Data | Recognition & Translation, Consent | v1 |
| `TrainingSampleAnonymized` | Consent & Personal Data | — (audit) | v1 |
| `AccountDeletionRequested` | Consent & Personal Data | All | v1 |
| `PreferencesChanged` | Profile & Preferences | Mobile app, Analytics | v1 |
| `EmailVerified` | Identity & Access | Identity, Analytics | v1 — **new** |
| `AccountBlocked` | Identity & Access | Notifications, Analytics, Audit | v1 — **new** |
| `RoleAssigned` / `RoleRevoked` | Identity & Access | Audit | v1 — **new** |
| `AccountDeleted` | Identity & Access | Analytics, Audit | v1 — **new** |
| `SignViewed` | Learning & Lexicon | Analytics | v1 — **generalizes `AlphabetLetterViewed`** |
| `LexiconSearchPerformed` | Learning & Lexicon | Analytics | v1 — **new** |
| `SignPublished` | Learning & Lexicon | Audit, mobile app | v1 — **new** |
| `SignWithdrawn` | Learning & Lexicon | Audit, mobile app | v1 — **new** |
| `DeviceRegistered` | Notifications | Notifications | v1 — **new** |
| `DeviceRevoked` | Notifications | Notifications | v1 — **new** |
| `NotificationScheduled` | Notifications | Scheduler | v1 — **new** |
| `NotificationDelivered` | Notifications | Analytics | v1 — **new** |
| `NotificationDeliveryFailed` | Notifications | Notifications, error log | v1 — **new** |
| `NotificationRead` | Notifications | Analytics | v1 — **new** |
| `NotificationTypeWithdrawn` | Notifications | Notifications | v1 — **new** |
| `RecognitionModelTrained` | Recognition & Translation | Audit | v1 — **new** |
| `RecognitionModelPublished` | Recognition & Translation | Mobile app, Analytics, Audit | v1 — **new** |
| `GestureSampleCaptured` | Consent & Personal Data | Compliance audit | v1 — **new** |
| `GestureSampleValidated` | Consent & Personal Data | Training pipeline | v1 — **new** |
| `CaptureSessionDiscarded` | Consent & Personal Data | Compliance audit, training pipeline | v1 — **new** |
| `PasswordPolicyChanged` | Identity & Access | Audit | v1 — **new** |
| `AchievementUnlocked` ⏸ | Gamification | Notifications, Analytics | v1 — **new, pending RF8** |

**40 events** (39 active, 1 blocked pending RF8). Every payload in this catalog feeds the contracts in
`07-api/contracts/` and the consolidated catalog in `09-microservices/event-catalog.md`.

### Events per context

| Context | Events | v1.0 | v1.1 |
|---------|--------|------|------|
| Identity & Access | 11 | 6 | +5 |
| Recognition & Translation | 8 | 6 | +2 |
| Consent & Personal Data | 7 | 4 | +3 |
| Notifications | 7 | 0 | +7 |
| Learning & Lexicon | 4 | 1 | +3 |
| Profile & Preferences | 1 | 1 | — |
| Cross-cutting | 1 | 0 | +1 |
| Gamification ⏸ | 1 | 0 | +1 |

> The per-context column sums to 40. `RoleAssigned` / `RoleRevoked` share one section but count as two
> events, which is why the summary table above has one row fewer than the total.
