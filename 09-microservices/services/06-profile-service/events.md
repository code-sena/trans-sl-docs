# Events — Profile Service

> Asynchronous events over RabbitMQ: exchange `traduce.events` (topic), routing key `profile.<EventName>`.
> Definitions and payloads: `02-domain/domain-events.md`. Nothing is published or consumed today (no code, no broker).

---

## Events this service PUBLISHES

| Event | Routing key | When | Payload (key fields) | Consumers |
|-------|-------------|------|----------------------|-----------|
| `PreferencesChanged` | `profile.PreferencesChanged` | Theme or interface language changes | `{userId, theme, language, changedAt}` | the app (applies it), analytics |
| `DeviceRegistered` | `profile.DeviceRegistered` | The user grants notification permission on a device | `{deviceId, userId, platform, registeredAt}` (never the push token) | profile (itself) |
| `DeviceRevoked` | `profile.DeviceRevoked` | The provider rejects the token or the user signs out | `{deviceId, userId, revokedAt, reason}` | profile (cancels pending pushes) |
| `NotificationScheduled` | `profile.NotificationScheduled` | A notification is created for future delivery | `{notificationId, userId, typeCode, channel, scheduledAt}` | the delivery scheduler (itself) |
| `NotificationDelivered` | `profile.NotificationDelivered` | The notification reaches the user through its channel | `{notificationId, userId, typeCode, channel, sentAt}` | analytics |
| `NotificationDeliveryFailed` | `profile.NotificationDeliveryFailed` | The provider rejects or fails the delivery | `{notificationId, userId, channel, reason, failedAt}` | profile (may revoke the device), error log |
| `NotificationRead` | `profile.NotificationRead` | The user opens the notification | `{notificationId, userId, readAt}` | analytics (`NOTIFICATION_OPENED`) |
| `NotificationTypeWithdrawn` | `profile.NotificationTypeWithdrawn` | An administrator deactivates a type | `{notificationTypeId, code, withdrawnBy, withdrawnAt}` | profile (itself) |
| `AchievementUnlocked` (pending RF8) | `profile.AchievementUnlocked` | A user reaches an achievement's target count | `{userAchievementId, userId, achievementId, achievementName, achievedAt}` | profile (in-app alert), analytics |

Events that only profile consumes (`DeviceRegistered`, `DeviceRevoked`, `NotificationScheduled`, `NotificationTypeWithdrawn`) are internal
facts; they may be handled in process and published only if another service needs them.

`NotificationDeliveryFailed` has to exist: without it nobody can tell "not sent yet" from "tried and could not".

### Event schema example: `AchievementUnlocked`

```json
{
  "eventId": "uuid",
  "eventType": "AchievementUnlocked",
  "aggregateId": "uuid of the user_achievement",
  "aggregateType": "UserAchievement",
  "occurredAt": "2026-10-04T12:00:00Z",
  "version": 1,
  "payload": {
    "userAchievementId": "uuid",
    "userId": "uuid",
    "achievementId": "uuid",
    "achievementName": "First translation",
    "achievedAt": "2026-10-04T12:00:00Z"
  },
  "metadata": { "correlationId": "uuid", "causationId": "eventId of the TranslationProduced that caused it" }
}
```

---

## Events this service CONSUMES

Queue `profile.main`.

| Event | Published by | What profile does |
|-------|--------------|-------------------|
| `UserRegistered` | iam | Create `user_preferences` with defaults (no-op if it exists) |
| `PasswordResetRequested` | iam | Create an `EMAIL` notification with the reset link (the token is not stored in clear) |
| `PasswordChanged` | iam | Security notice to the holder |
| `AccountLocked`, `AccountBlocked` | iam | Alert the holder (type `ACCOUNT_SECURITY`) |
| `ConsentRevoked` | iam | Confirm to the data subject that the authorization was revoked |
| `AccountDeletionRequested` | iam | Delete preferences, devices, notifications and progress of the user; report completion |
| `TranslationProduced` | recognition | Advance achievements that count translations; show the result when the type is active |
| `RecognitionFailed` | recognition | On-screen alert "sign not recognized, try again" (without blocking navigation, RF4) |
| `TranslationSessionInterrupted` | recognition | Understandable error message; what was translated is kept (RNF7) |

Before creating any notification the handler checks `notifications_enabled` of the user (INV-025). All handlers are idempotent by `eventId`.

---

## Delivery guarantees

| Guarantee | Value | Implication |
|-----------|-------|-------------|
| At-least-once | Yes | Handlers are idempotent; `notified_at` prevents a second unlock notification |
| At-most-once | No | |
| Exactly-once | No | |

Publishing goes through a transactional outbox in the `profile` database.

## Error handling

- **Dead Letter Queue:** `profile.main.dlq`
- **Retries:** 3 to 5 with exponential backoff, 7-day retention
- **Alerts:** a message in the DLQ; `AccountDeletionRequested` failing is a legal risk and has priority
