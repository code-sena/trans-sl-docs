# Events — Lexicon Service

> Asynchronous events over RabbitMQ: exchange `traduce.events` (topic), routing key `lexicon.<EventName>`.
> Definitions and payloads: `02-domain/domain-events.md`.
>
> **Implementation status:** the module `lexicon` emits **no event today** (`backend/src` has no event publisher, no broker).
> The events below are the target of the service. Until then, the app learns about catalog changes only by calling the API again.

---

## Events this service PUBLISHES

| Event | Routing key | Emitted when | Payload (key fields) | Consumers |
|-------|-------------|--------------|----------------------|-----------|
| `SignPublished` | `lexicon.SignPublished` | `POST /api/lexicon/:code/publish` succeeds (`DRAFT` / `INACTIVE` to `ACTIVE`) | `{signId, signCode, signType, categoryId, publishedBy, publishedAt}` | recognition (refreshes its sign catalog), iam (audit), the app (invalidate catalog cache) |
| `SignWithdrawn` | `lexicon.SignWithdrawn` | `DELETE /api/lexicon/:code` sets `status = INACTIVE` | `{signId, signCode, withdrawnBy, withdrawnAt, reason}` | recognition, iam (audit), the app |
| `SignViewed` | `lexicon.SignViewed` | `GET /api/lexicon/:code` (generalizes `AlphabetLetterViewed`) | `{signId, signCode, signType, userId, viewedAt}` | analytics |
| `LexiconSearchPerformed` | `lexicon.LexiconSearchPerformed` | `GET /api/lexicon?q=` or `/search` | `{userId, query, resultCount, searchedAt}` | analytics |

`userId` in the view and search events is the `sub` of the token when there is one (reads are public, so it can be absent).
Searches with zero results are the most valuable metric of the system: they list the signs users expect and the catalog lacks.

### Event schema example: `SignPublished`

```json
{
  "eventId": "uuid",
  "eventType": "SignPublished",
  "aggregateId": "uuid of the sign",
  "aggregateType": "Sign",
  "occurredAt": "2026-10-04T12:00:00Z",
  "version": 1,
  "payload": {
    "signId": "uuid",
    "signCode": "GREETING_HELLO",
    "signType": "WORD",
    "categoryId": "uuid",
    "publishedBy": "uuid (sub of the admin)",
    "publishedAt": "2026-10-04T12:00:00Z"
  },
  "metadata": { "correlationId": "uuid", "userId": "uuid" }
}
```

---

## Events this service CONSUMES

None. The catalog is authoritative and reacts to no other service.

---

## Contract with the recognizer

The set of `ACTIVE` codes is the vocabulary that the recognizer must be able to predict. `SignPublished` / `SignWithdrawn` tell
`recognition-service` which codes exist, but publishing a sign does not train a model, and lexicon does not check the code against the model.
The rule INV-018 of `06-data/domains/04-lexicon.md` ("publish only a sign the active model recognizes") cannot be checked synchronously
without calling recognition; it is an open item (options: a manual checklist, or recognition rejecting unknown codes and emitting `RecognitionFailed`).

## Synchronous dependencies

| Dependency | Used for |
|------------|----------|
| JWT forwarded by the gateway | Verify the token and read `sub` and `roles` on admin routes. Today: `shared/http/auth_middleware` and `require_role` |

No service is called over HTTP.

---

## Delivery guarantees

| Guarantee | Value | Implication |
|-----------|-------|-------------|
| At-least-once | Yes | Consumers are idempotent (`eventId`) |
| At-most-once | No | |
| Exactly-once | No | |

Publishing goes through a transactional outbox in the `lexicon` database, so that a publication and its event cannot diverge.
`SignViewed` and `LexiconSearchPerformed` are high volume and tolerate loss; they may be published without the outbox.

## Error handling

- **Dead Letter Queue:** `traduce.events.dlq` (publisher side retries from the outbox)
- **Retries:** 3 to 5 with exponential backoff
- **Alerts:** outbox rows older than 5 minutes without delivery
