# Events — Lexicon

> Because the backend is a modular monolith, there is no message broker and the lexicon module does not publish or consume events today.
> The only integration points are HTTP routes and direct function calls inside the process.

---

## Events this module PUBLISHES

None. No `EventEmitter`, outbox or broker exists in the backend (`backend/src` has no event publisher).

### Planned events

`02-domain/domain-events.md` defines the events that this module would emit once an in-process event channel exists.

| Event | Would be emitted when | Intended consumers |
|-------|----------------------|--------------------|
| `SignPublished` | `POST /api/lexicon/:code/publish` succeeds | Audit, mobile app (invalidate the catalog cache) |
| `SignWithdrawn` | `DELETE /api/lexicon/:code` sets `status = INACTIVE` | Audit, mobile app |
| `SignViewed` | `GET /api/lexicon/:code` | Usage Analytics |
| `LexiconSearchPerformed` | `GET /api/lexicon?q=` or `/search` | Usage Analytics |

Until then, the mobile app learns about catalog changes only by calling the API again.

---

## Events this module CONSUMES

None.

---

## Synchronous dependencies (in-process)

| Dependency | Used for |
|-----------|----------|
| `shared/http/auth_middleware` | Verifies the JWT on admin routes and sets `req.user` |
| `shared/http/require_role` with `postgresRoleChecker` | Verifies the `ADMIN` role in `user_role` |
| `users.user_id` (via `created_by` / `updated_by`) | Records who created or edited a sign |

## Contract with the recognizer

The set of `ACTIVE` codes is the vocabulary that the recognizer must be able to predict. It is kept in sync by hand: publishing a sign does not train a model, and the lexicon does not check the code against the model. This is the rule INV-018 in `06-data/domains/04-lexicon.md`.
