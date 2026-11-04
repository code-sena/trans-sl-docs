# Events — Lexicon Service

> Asynchronous events over RabbitMQ: exchange `traduce.events` (topic), routing key `lexicon.<EventName>`.
> Typed payloads are in `packages/shared/src/events/contracts.ts`; the catalog is in `02-domain/domain-events.md`.
> This file lists what the code does **today**, and the events of the target model that the code does not have yet.

---

## Events this service PUBLISHES

| Event | Routing key | Emitted when | Payload | Consumers |
|-------|-------------|--------------|---------|-----------|
| `SignPublished` | `lexicon.SignPublished` | `POST /api/lexicon/:code/publish` succeeds (`DRAFT` or `INACTIVE` to `ACTIVE`) | `{lexiconId, code, type, language, letter, categoryId}` | recognition-service (keeps the codes it knows; today it only logs them) |
| `SignWithdrawn` | `lexicon.SignWithdrawn` | `DELETE /api/lexicon/:code` sets `status = INACTIVE` | `{lexiconId, code}` | recognition-service (today it only logs them) |

Both are published with a best-effort publish after the change is saved: if the bus fails, the change stays and the failure is logged. There is no outbox (see DEC-009 in `decisions.md`).

### Event example: `SignPublished`

```json
{
  "eventId": "7b8c9d0e-0000-4000-8000-000000000003",
  "type": "lexicon.SignPublished",
  "occurredAt": "2026-10-04T12:00:00.000Z",
  "payload": {
    "lexiconId": 12,
    "code": "GREETING_HELLO",
    "type": "WORD",
    "language": "LSC",
    "letter": null,
    "categoryId": 2
  }
}
```

---

## Events this service CONSUMES

None. The catalog is authoritative and reacts to no other service.

---

## Target events (not in the code yet)

The events below belong to the target model of `02-domain/domain-events.md`. The code does not emit them.

| Event | Routing key | Emitted when | Payload (key fields) | Consumers |
|-------|-------------|--------------|----------------------|-----------|
| `SignViewed` | `lexicon.SignViewed` | `GET /api/lexicon/:code` (generalizes `AlphabetLetterViewed`) | `{signId, signCode, signType, userId, viewedAt}` | analytics |
| `LexiconSearchPerformed` | `lexicon.LexiconSearchPerformed` | `GET /api/lexicon?q=` or `/search` | `{userId, query, resultCount, searchedAt}` | analytics |

The target `userId` is the `sub` of the token when there is one (reads are public, so it can be absent). Searches with zero results would be the most valuable metric: they list the signs users expect and the catalog lacks.

---

## Contract with the recognizer

The set of `ACTIVE` codes is the vocabulary that the recognizer must be able to predict. `SignPublished` and `SignWithdrawn` tell `recognition-service` which codes exist, but publishing a sign does not train a model, and lexicon does not check the code against the model.
The rule INV-018 of `06-data/domains/04-lexicon.md` ("publish only a sign the active model recognizes") cannot be checked synchronously without calling recognition; it is an open item (options: a manual checklist, or recognition rejecting unknown codes and emitting `RecognitionFailed`).

## Synchronous dependencies

| Dependency | Used for |
|------------|----------|
| JWT forwarded by the gateway | Verify the token and read the `roles` claim on admin routes (`requireRole('ADMIN')` from `packages/shared`) |

No service is called over HTTP.

---

## Delivery guarantees

| Guarantee | Value | Implication |
|-----------|-------|-------------|
| At-least-once | No (best-effort publish) | A lost `SignPublished` is not retried. The catalog itself is not affected |
| At-most-once | Yes | |
| Exactly-once | No | |

The target model uses a transactional outbox in the `lexicon` database, so that a publication and its event cannot diverge. The outbox is not in the code.

## Error handling

- The failure of a publish is logged by the `publishQuietly` helper of `packages/shared`. The request still succeeds.
- Messages that a consumer cannot process go to `<queue>.dead` in RabbitMQ (`recognition-service.lexicon-events.dead` for recognition).
- Target policy (dead-letter queue and retries from the outbox, alert on outbox rows older than 5 minutes): not implemented.
