# Domain Events — Traduce Señas

> A domain event is a fact that occurred in the business. Events are the backbone of communication
> between bounded contexts. The name is ALWAYS in past tense and in the ubiquitous language of the domain.

**Version:** v1.0 · **Last updated:** 2026-08-31

> **Channel in this project:** *in-process*. The backend is a modular monolith on Node/Express, so
> events are published through an internal `EventEmitter` and recorded in a `domain_events` table for
> traceability. **There is no message broker.** The sections marked `[IF DISTRIBUTED]` describe what
> would have to be solved the day a context is extracted into its own service; they do not apply today.

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
| **Channel (topic)** | `identity.user.registered` (in-process) |
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

#### `AccountLocked`
**Aggregate:** `User` · **Trigger:** five consecutive failed access attempts (RNF4)
**Consumers:** Notifications (alerts the holder), Usage Analytics
**Payload:** `{ userId, lockedAt, failedAttempts, unlockAt }`

---

### Context: Recognition & Translation ⭐ Core

#### `TranslationSessionStarted`

| Field | Value |
|-------|-------|
| **Aggregate** | `TranslationSession` |
| **Trigger** | The user turns translation mode on and the camera is ready (ERF3.1) |
| **Consumers** | Usage Analytics |
| **Channel (topic)** | `translation.session.started` (in-process) |

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
| **Channel (topic)** | `translation.produced` (in-process) |

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

### Context: Learning

#### `AlphabetLetterViewed`
**Aggregate:** `AlphabetLetter` · **Trigger:** the user consults a letter of the alphabet (ERF7.1)
**Consumers:** Usage Analytics — feeds the "most visited sections" metric of RF6
**Payload:** `{ letter: "Ñ", userId, viewedAt }`

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
| `RecognitionFailed` | Show an on-screen alert without blocking navigation (RF4) | `ShowNotification` | Notifications (cross-cutting) |
| `ConsentRevoked` | Stop keeping samples while translation stays operational | `DisableSampleStorage` | Recognition & Translation |
| `AccountDeletionRequested` | Each context deletes the subject's data and reports completion | `PurgeUserData` | All |
| `AccountLocked` | Notify the holder of the lockout after unauthorized attempts (RNF4) | `SendSecurityAlert` | Identity & Access |
| `UserRegistered` | Create the profile with `LIGHT` theme and `es-CO` language | `CreateDefaultProfile` | Profile & Preferences |
| `TranslationSessionInterrupted` | Show an understandable error message and keep what was translated (RNF7) | `ShowNotification` | Notifications (cross-cutting) |

---

## Idempotency

Even with an in-process channel, **consumers must be idempotent**. The real case in this project is not
a broker retry: it is the user tapping the translate button twice, or the app resending a request after
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

## `[IF DISTRIBUTED]` Schema evolution and resilience

> This section **does not apply to the current monolith**. It is documented for the day a context —
> most likely Recognition & Translation, if inference moves to its own service — is extracted into a
> separate deployment.

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
| `AlphabetLetterViewed` | Learning | Analytics | v1 |

**18 events.** Every payload in this catalog feeds the contracts in `07-api/contracts/` and the
consolidated catalog in `09-microservices/event-catalog.md`.
