# Events — IAM Service

> Asynchronous events over RabbitMQ: topic exchange `traduce.events`, routing key `<service>.<event>`.
> Event definitions, payloads and the envelope are in `02-domain/domain-events.md`; this file lists what iam publishes and
> consumes. **No event is published by the code today** (there is no broker); everything below is the target.

---

## Events this service PUBLISHES

Routing key = `iam.<EventName>`.

| Event | Routing key | When it is emitted | Payload (key fields) | Consumers |
|-------|-------------|--------------------|----------------------|-----------|
| `UserRegistered` | `iam.UserRegistered` | Registration with accepted terms | `{userId, email, name, role, termsAcceptedAt}` | profile (creates preferences), analytics |
| `UserSignedIn` | `iam.UserSignedIn` | Valid sign-in | `{userId, method, signedInAt}` | analytics |
| `ExternalProviderLinked` | `iam.ExternalProviderLinked` | Google / Facebook account linked | `{userId, provider, externalId, linkedAt}` | audit (itself) |
| `EmailVerified` | `iam.EmailVerified` | The 6-digit code is validated | `{userId, verifiedAt}` | analytics |
| `PasswordResetRequested` | `iam.PasswordResetRequested` | Recovery requested | `{userId, email, resetToken, expiresAt}` (the token is never persisted in the event store) | profile (mail) |
| `PasswordChanged` | `iam.PasswordChanged` | Reset or change completed | `{userId, changedAt, source}` | profile (security notice) |
| `PasswordPolicyChanged` | `iam.PasswordPolicyChanged` | An administrator activates a new policy | `{policyId, previousPolicyId, changedBy, changedAt}` | audit (itself) |
| `AccountLocked` | `iam.AccountLocked` | A lockout level is reached | `{userId, lockedAt, lockoutLevel, lockedUntil}` | profile (alert), analytics |
| `AccountBlocked` | `iam.AccountBlocked` | The ladder is exhausted | `{userId, blockedAt, lockoutLevel}` | profile (alert), analytics |
| `RoleAssigned`, `RoleRevoked` | `iam.RoleAssigned`, `iam.RoleRevoked` | An administrator changes a role | `{userId, roleId, roleName, assignedBy, assignedAt}` | audit (itself) |
| `AccountDeleted` | `iam.AccountDeleted` | Account deletion completed | `{userId, deletedAt}` (no personal data) | analytics, profile |
| `ConsentGranted` | `iam.ConsentGranted` | The data subject authorizes sample use | `{consentId, userId, purpose, policyVersion, grantedAt}` | recognition |
| `ConsentRevoked` | `iam.ConsentRevoked` | The data subject revokes the authorization | `{consentId, userId, revokedAt}` | recognition (stop keeping samples, discard capture sessions), profile (confirmation) |
| `AccountDeletionRequested` | `iam.AccountDeletionRequested` | The data subject requests deletion | `{requestId, userId, requestedAt}` | recognition, profile, analytics (detach identity) |

`AccountDeletionRequested` has the most consumers and each one deletes its own data and reports back. The `AccountDeleted`
event closes the flow once iam has finished.

### Event schema example: `UserRegistered`

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
  "metadata": { "correlationId": "1a2b3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d", "userId": "9f1c2b34-5d6e-4f70-8a91-b2c3d4e5f601" }
}
```

Content rule: no payload carries passwords, hashes, plain-text tokens, video or biometric data.

---

## Events this service CONSUMES

iam keeps the audit trail. It subscribes to the change events of the other services and writes `audit_logs`.

| Event | Published by | What iam does |
|-------|--------------|---------------|
| `SignPublished`, `SignWithdrawn` | lexicon | Insert an `audit_logs` row (`entity_type = sign_lexicon`) |
| `RecognitionModelTrained`, `RecognitionModelPublished` | recognition | Insert an `audit_logs` row (`ai_models`) |
| `GestureSampleCaptured`, `CaptureSessionDiscarded`, `TrainingSampleAnonymized` | recognition | Insert a compliance `audit_logs` row |
| `RoleAssigned`, `RoleRevoked`, `PasswordPolicyChanged` | iam (itself) | Insert an `audit_logs` row; written in the same transaction as the change, not through the broker |

Queue: `iam.audit` bound to `lexicon.Sign*`, `recognition.RecognitionModel*`, `recognition.GestureSample*`,
`recognition.CaptureSessionDiscarded`, `recognition.TrainingSampleAnonymized`.

---

## Delivery guarantees

| Guarantee | Value | Implication |
|-----------|-------|-------------|
| At-least-once | Yes | Consumers must be idempotent: use `eventId` as the key |
| At-most-once | No | |
| Exactly-once | No | |

Publishing uses a transactional outbox (an `outbox` table in the same database, written in the same transaction as the
change) so a state change and its event cannot diverge. The outbox table is part of the target schema and is not in `06-data/`
yet.

## Error handling

- **Dead Letter Queue:** `traduce.events.dlq`, queue `iam.audit.dlq`
- **Retries:** 3 to 5 with exponential backoff before the DLQ, 7-day retention
- **Alerts:** a message in the DLQ is an alert condition (a lost audit record is a compliance defect)
