# Events — IAM Service

> Asynchronous events over RabbitMQ: topic exchange `traduce.events`, routing key `<service>.<event>`.
> Event definitions and payloads are typed in `packages/shared/src/events/contracts.ts`; the catalog is in `02-domain/domain-events.md`.
> This file lists what iam publishes and consumes **today**, and the events of the target model that the code does not have yet.

---

## Events this service PUBLISHES

Routing key = `iam.<EventName>`. The envelope is `{ eventId, type, occurredAt, payload }`.

| Event | Routing key | When it is emitted | Payload | How it is sent | Consumers |
|-------|-------------|--------------------|---------|----------------|-----------|
| `UserRegistered` | `iam.UserRegistered` | An account is created (registration, or the first social login) | `{userId, email, name}` | Direct publish after the insert; a failure is logged, not retried | profile (creates the profile and default preferences), analytics (`USER_REGISTERED` usage event) |
| `UserDeleted` | `iam.UserDeleted` | An account is erased (`DELETE /api/users/me`) | `{userId, occurredAt}` | Written to `outbox_events` in the same transaction as the erasure, then published by the relay | profile (erases its data), recognition (deletes translations, unlinks samples), analytics (unlinks usage events) |

### Event example: `UserRegistered`

```json
{
  "eventId": "550e8400-e29b-41d4-a716-446655440000",
  "type": "iam.UserRegistered",
  "occurredAt": "2026-08-31T15:42:10.000Z",
  "payload": {
    "userId": 42,
    "email": "user@example.com",
    "name": "María Rodríguez"
  }
}
```

Content rule: no payload carries passwords, hashes, plain-text tokens, video or biometric data.

---

## Target events (not in the code yet)

The events below belong to the target model of `02-domain/domain-events.md`. The code does not publish them: it has no sign-in, password-change, lockout, role-change or consent events, and it names the deletion event `iam.UserDeleted`, not `iam.AccountDeleted`.

| Event | Routing key | When it would be emitted | Payload (key fields) | Consumers |
|-------|-------------|--------------------------|----------------------|-----------|
| `UserSignedIn` | `iam.UserSignedIn` | Valid sign-in | `{userId, method, signedInAt}` | analytics |
| `ExternalProviderLinked` | `iam.ExternalProviderLinked` | Google / Facebook account linked | `{userId, provider, externalId, linkedAt}` | audit (itself) |
| `EmailVerified` | `iam.EmailVerified` | The 6-digit code is validated | `{userId, verifiedAt}` | analytics |
| `PasswordResetRequested` | `iam.PasswordResetRequested` | Recovery requested | `{userId, email, resetToken, expiresAt}` (the token is never persisted in the event store) | profile (mail) |
| `PasswordChanged` | `iam.PasswordChanged` | Reset or change completed | `{userId, changedAt, source}` | profile (security notice) |
| `PasswordPolicyChanged` | `iam.PasswordPolicyChanged` | An administrator activates a new policy | `{policyId, previousPolicyId, changedBy, changedAt}` | audit (itself) |
| `AccountLocked` | `iam.AccountLocked` | A lockout level is reached | `{userId, lockedAt, lockoutLevel, lockedUntil}` | profile (alert), analytics |
| `AccountBlocked` | `iam.AccountBlocked` | The ladder is exhausted | `{userId, blockedAt, lockoutLevel}` | profile (alert), analytics |
| `RoleAssigned`, `RoleRevoked` | `iam.RoleAssigned`, `iam.RoleRevoked` | An administrator changes a role | `{userId, roleId, roleName, assignedBy, assignedAt}` | audit (itself) |
| `AccountDeleted` | `iam.AccountDeleted` | Account deletion completed (today: `iam.UserDeleted`) | `{userId, deletedAt}` (no personal data) | analytics, profile |
| `ConsentGranted` | `iam.ConsentGranted` | The data subject authorizes sample use | `{consentId, userId, purpose, policyVersion, grantedAt}` | recognition |
| `ConsentRevoked` | `iam.ConsentRevoked` | The data subject revokes the authorization | `{consentId, userId, revokedAt}` | recognition, profile |
| `AccountDeletionRequested` | `iam.AccountDeletionRequested` | The data subject requests deletion | `{requestId, userId, requestedAt}` | recognition, profile, analytics |

---

## Events this service CONSUMES

The code consumes no events. The audit trail that the target model assigns to iam is not implemented (no `audit_logs` table and no subscriptions).

The target design subscribes to the change events of the other services and writes `audit_logs`:

| Event | Published by | What iam would do |
|-------|--------------|-------------------|
| `SignPublished`, `SignWithdrawn` | lexicon | Insert an `audit_logs` row (`entity_type = sign_lexicon`) |
| `RecognitionModelTrained`, `RecognitionModelPublished` | recognition | Insert an `audit_logs` row (`ai_models`) |
| `GestureSampleCaptured`, `CaptureSessionDiscarded`, `TrainingSampleAnonymized` | recognition | Insert a compliance `audit_logs` row |

---

## Delivery guarantees

| Guarantee | Value | Implication |
|-----------|-------|-------------|
| At-least-once | Yes | Consumers must be idempotent by `eventId`. profile keeps `processed_events`; analytics refuses a second event with the same `eventId` |
| At-most-once | No | |
| Exactly-once | No | |

`UserDeleted` uses a transactional outbox: the `outbox_events` table (migrations `009` and `012`) receives the event in the same transaction that erases the account. The relay (`src/shared/application/relay_outbox.ts`) publishes it with `mandatory: true`. If no queue accepts the message, the publish fails and the relay retries, so the event is not lost. `UserRegistered` does not use the outbox.

## Error handling

- iam publishes and consumes no queue, so it has no dead-letter queue of its own.
- Consumers keep the messages they cannot process in `<queue>.dead` (for example `recognition-service.user-deleted.dead`). The `/health` of each consumer reports `dead_letters` when that queue has messages.
- iam's own `/health` reports `outbox_backlog` when an event waits more than 10 minutes in `outbox_events`.
- The target retry policy (3 to 5 retries with backoff, 7-day retention) is not implemented as written.
