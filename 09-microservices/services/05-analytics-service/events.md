# Events — Analytics Service

> Analytics is a pure **consumer**: it publishes no events. Exchange `traduce.events` (topic), routing key `<service>.<event>`.
> Typed payloads are in `packages/shared/src/events/contracts.ts`; the catalog is in `02-domain/domain-events.md`.

---

## Events this service PUBLISHES

None. It observes; other services do not react to statistics.

---

## Events this service CONSUMES

One queue per event, so that each handler receives only its own events.

| Event | Published by | Queue | What analytics does |
|-------|--------------|-------|---------------------|
| `recognition.TranslationProduced` | recognition | `analytics-service.translation-produced` | Inserts a `TRANSLATION_COMPLETED` usage event (section `TRANSLATION`, reference type `TRANSLATION`, reference id = `translationId`). The signs of the gloss (words separated by spaces) go to `sign_codes` |
| `iam.UserRegistered` | iam | `analytics-service.user-registered` | Inserts a `USER_REGISTERED` usage event (section `HOME`, reference type `USER`). Ignored if the account was already erased |
| `iam.UserDeleted` | iam | `analytics-service.user-deleted` | Sets `user_id` to NULL in the user's usage events and records the user in `erased_users`. Retried without a limit until it succeeds |

Events of the target model, not consumed today: `iam.UserSignedIn`, `iam.EmailVerified`, `iam.AccountLocked`, `iam.AccountBlocked`, `iam.AccountDeletionRequested`, `recognition.TranslationSessionStarted`, `recognition.RecognitionFailed`, `recognition.TranslationSessionEnded`, `recognition.TranslationSessionInterrupted`, `recognition.TranslationDeleted`, `recognition.RecognitionModelPublished`, `lexicon.SignViewed`, `lexicon.LexiconSearchPerformed`, `profile.PreferencesChanged`, `profile.NotificationRead`, `profile.AchievementUnlocked`.

### Facts with no event

The client sends the facts that no service emits (for example `SECTION_VIEW`, `AUDIO_PLAYED`) to `POST /api/analytics/events`. That is the only way they enter the usage log today.

### Handler rule

Each handler is idempotent: `usage_event.event_id` is unique, and a repeated event is ignored by the database write.

---

## Delivery guarantees

| Guarantee | Value | Implication |
|-----------|-------|-------------|
| At-least-once | Yes | A repeated event does not count twice (unique `event_id`) |
| At-most-once | No | |
| Exactly-once | No | |

## Error handling

- Each queue has a dead-letter queue `<queue>.dead` (for example `analytics-service.user-deleted.dead`). The `/health` of the service reports `dead_letters` when those queues have messages.
- The `iam.UserDeleted` handler keeps retrying with backoff. `/health` reports `consumer_retrying` after 10 minutes of retries.
- The target policy (3 to 5 retries and an `analytics.main.dlq` queue) is not implemented as written.
