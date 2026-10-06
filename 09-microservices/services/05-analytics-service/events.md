# Events — Analytics Service

> Analytics is a pure **consumer**. It publishes no events. Exchange `traduce.events` (topic), routing key `<service>.<event>`.
> Definitions and payloads: `02-domain/domain-events.md`. Nothing is consumed today: no broker and no service exist yet.

---

## Events this service PUBLISHES

None. It observes; other services do not react to statistics.

---

## Events this service CONSUMES

Queue `analytics.main`, bound to the routing keys below.

| Event | Published by | What analytics does |
|-------|--------------|---------------------|
| `iam.UserRegistered` | iam | Count a registration for the day |
| `iam.UserSignedIn` | iam | Start of a login session (`session_daily_stats`) |
| `iam.EmailVerified` | iam | Count a verification |
| `iam.AccountLocked`, `iam.AccountBlocked` | iam | Count lockouts (tells a mistyped password from an account under attack) |
| `iam.AccountDeleted`, `iam.AccountDeletionRequested` | iam | Set `user_id = NULL` in the user's `usage_events`; the facts stay |
| `recognition.TranslationSessionStarted` | recognition | Insert `TRANSLATION_STARTED` (section `TRANSLATION`) |
| `recognition.TranslationProduced` | recognition | Insert `TRANSLATION_COMPLETED`, `reference_id = translationId` |
| `recognition.RecognitionFailed` | recognition | Insert `TRANSLATION_FAILED` (feeds "problematic signs") |
| `recognition.TranslationSessionEnded`, `recognition.TranslationSessionInterrupted` | recognition | Session duration and interruption count |
| `recognition.TranslationDeleted` | recognition | Insert `HISTORY_ENTRY_DELETED` (section `HISTORY`) |
| `recognition.RecognitionModelPublished` | recognition | Mark the date of a model change in the reports |
| `lexicon.SignViewed` | lexicon | Insert `SIGN_VIEWED` (section `ALPHABET` for letters, `LEXICON` otherwise) |
| `lexicon.LexiconSearchPerformed` | lexicon | Insert `SEARCH_PERFORMED`; searches with zero results are the most valuable metric |
| `profile.PreferencesChanged` | profile | Insert `PREFERENCE_CHANGED` (section `SETTINGS`) |
| `profile.NotificationDelivered` | profile | Count a delivery |
| `profile.NotificationRead` | profile | Insert `NOTIFICATION_OPENED` (section `NOTIFICATIONS`) |
| `profile.AchievementUnlocked` | profile | Count an unlock (pending RF8) |

### Facts with no event

`SECTION_VIEW` (RF2) and `AUDIO_PLAYED` happen on the client and no service emits an event for them. They need an ingestion
endpoint or a client-side event; it is an open decision (see [README.md](./README.md)).
`UserRegistered` and `UserSignedIn` have no matching value in `usage_event_type`; their counts need a new enum value or a separate counter (open item for the data team).

### Handler rule

Each handler is idempotent: it stores the `eventId` and ignores a repeated one.

```typescript
async function onTranslationProduced(event: TranslationProduced): Promise<void> {
  if (await processed.has(event.eventId)) return;
  await usageEvents.insert({ eventType: 'TRANSLATION_COMPLETED', section: 'TRANSLATION',
    userId: event.payload.userId, referenceId: event.payload.translationId });
  await processed.add(event.eventId); // same transaction
}
```

---

## Delivery guarantees

| Guarantee | Value | Implication |
|-----------|-------|-------------|
| At-least-once | Yes | Handlers are idempotent |
| At-most-once | No | |
| Exactly-once | No | |

## Error handling

- **Dead Letter Queue:** `analytics.main.dlq`
- **Retries:** 3 to 5 with exponential backoff, 7-day retention
- **Alerts:** a message in the DLQ means a lost statistic; it can be replayed. Lower priority than the compliance queues of iam and recognition
