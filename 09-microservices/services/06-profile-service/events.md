# Events — Profile Service

> Asynchronous events over RabbitMQ: exchange `traduce.events` (topic), routing key `profile.<EventName>` for the events it publishes.
> Typed payloads are in `packages/shared/src/events/contracts.ts` and `services/profile-service/src/domain/events.ts`; the catalog is in `02-domain/domain-events.md`.
> This file lists what the code does **today**, and the events of the target model that the code does not have yet.

---

## Events this service PUBLISHES

| Event | Routing key | Emitted when | Payload | Consumers in the code |
|-------|-------------|--------------|---------|-----------------------|
| `PreferencesChanged` | `profile.PreferencesChanged` | A `PATCH` of the preferences is saved (also through `PATCH /api/profile/me`) | `{userId, ...}` with the fields sent: `uiLanguage`, `theme` and/or `notificationsEnabled` | None |
| `AchievementUnlocked` | `profile.AchievementUnlocked` | An achievement reaches its target count, from a translation or from `POST /api/achievements/activity`. One event per unlock (also for the challenge-point medals, [ADR-010](../../../05-architecture/decisions/records/ADR-010-challenge-points-medals.md)) | `{userId, achievementId, code, points}` | None |

Both are published with a best-effort publish after the change is saved: if the bus fails, the change stays and the failure is logged. There is no outbox for events.

Completing a daily challenge publishes no event: it creates an in-app notification of type `CHALLENGE_COMPLETED` in the same transaction ([ADR-009](../../../05-architecture/decisions/records/ADR-009-daily-challenges.md)).

### Event example: `AchievementUnlocked`

```json
{
  "eventId": "7b8c9d0e-0000-4000-8000-000000000004",
  "type": "profile.AchievementUnlocked",
  "occurredAt": "2026-10-04T12:00:00.000Z",
  "payload": {
    "userId": "42",
    "achievementId": "0f9e8d7c-0000-4000-8000-000000000005",
    "code": "FIRST_TRANSLATION",
    "points": 10
  }
}
```

---

## Events this service CONSUMES

Each consumer has its own queue (one queue per event).

| Event | Published by | Queue | What profile does |
|-------|--------------|-------|-------------------|
| `iam.UserRegistered` | iam | `profile-service.user-registered` | Creates the profile (`user_profiles`) and the default preferences. A repeated event changes nothing |
| `recognition.TranslationProduced` | recognition | `profile-service.translation-produced` | Advances the achievements that count translations and the daily challenge of the day of `occurredAt`. Creates the notification of an unlock when the user has notifications enabled. Events without a `userId` (anonymous) are ignored |
| `iam.UserDeleted` | iam | `profile-service.user-deleted` | Erases the profile, preferences, notifications and achievement progress of the user, and records the user in `erased_users` |

Every handler stores the `eventId` in `processed_events`, so a repeated event is ignored.

### Target consumers (not implemented)

`iam.PasswordResetRequested`, `iam.PasswordChanged`, `iam.AccountLocked`, `iam.AccountBlocked`, `iam.ConsentRevoked`, `iam.AccountDeletionRequested`, `recognition.RecognitionFailed` and `recognition.TranslationSessionInterrupted`. The code has none of them.

### Target publications (not implemented)

`profile.DeviceRegistered`, `profile.DeviceRevoked` (devices were dropped, ADR-007), `profile.NotificationScheduled`, `profile.NotificationDelivered`, `profile.NotificationDeliveryFailed`, `profile.NotificationRead` and `profile.NotificationTypeWithdrawn`. In the code, the notifications are rows (`IN_APP` and `EMAIL`) and the `EMAIL` rows are sent by a worker; `NotificationDeliveryFailed` is not emitted.

---

## Delivery guarantees

| Guarantee | Value | Implication |
|-----------|-------|-------------|
| At-least-once | Yes for the consumed events | Handlers are idempotent by `eventId` (`processed_events`); the unlock notification is created once |
| At-most-once | No for the published events | A failed publish is logged and not retried |
| Exactly-once | No | |

The target model uses a transactional outbox in the `profile` database. The code has an outbox only for the `EMAIL` notifications (the `PENDING` rows that the mail worker sends); it is not an event outbox.

## Error handling

- Messages a consumer rejects are kept in `<queue>.dead` (for example `profile-service.user-deleted.dead`). The `/health` of the service reports `dead_letters` when those queues have messages.
- The `iam.UserDeleted` handler retries without a limit while it fails. `/health` reports `consumer_retrying` after 10 minutes of retries.
- The target policy (3 to 5 retries with exponential backoff, a `profile.main.dlq` queue and 7-day retention) is not implemented as written.
