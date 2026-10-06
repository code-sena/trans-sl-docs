# Design Decisions — Lexicon Service

> Technical decisions specific to this service (global ones go in `05-architecture/decisions/records/`).
> DEC-001 to DEC-005 and DEC-007 are taken from the code and its comments. DEC-006 is superseded and DEC-008 is the change that the extraction requires.

---

## [DEC-001] The alphabet is the set of `LETTER` signs

**Date:** 2026-10-04
**Status:** Active

**Context:**
The alphabet screen needs the 27 letters, and the recognizer treats a letter and a word as the same thing: a class it predicts.

**Decision:**
There is no alphabet table. Letters are rows of `sign_lexicon` with `type = 'LETTER'` and a `letter` value; `GET /api/lexicon/alphabet` filters on them and orders by `display_order` (Ñ after N).

**Alternatives considered:**
- Separate `alphabet` table: two models for one concept and two names for one code.

**Consequences:**
- Advantage: one catalog, one search, one recognizer vocabulary.
- Trade-off: the rule "27 letters, none repeated" needs `uq_sign_lexicon_letter` and `ck_sign_lexicon_letter_iff_type` to hold.

---

## [DEC-002] `code` is immutable and signs are never deleted

**Date:** 2026-10-04
**Status:** Active

**Context:**
`sign_lexicon.code` is the class the AI model predicts, and other services (recognition, analytics) keep it as a reference without a foreign key. Renaming it, or removing a sign, breaks them silently.

**Decision:**
`PATCH /:code` cannot change `code` or `status`. A sign is retired with `DELETE /:code`, which sets `status = 'INACTIVE'`, and can come back through `POST /:code/publish`. `code` must match `^[A-Z0-9_]{1,50}$` and cannot be `ALPHABET`, `SEARCH`, `CATEGORIES`, `ADMIN` or `MEDIA`.

**Alternatives considered:**
- Hard delete: loses history and breaks any reference to the sign.
- Free renaming: breaks the contract with the recognizer.

**Consequences:**
- Advantage: stable identifiers for the model, the history in recognition and the app.
- Trade-off: a typo in a published code cannot be fixed in place; a new sign must be created.

---

## [DEC-003] Texts live in `sign_localizations`; ES is mandatory

**Date:** 2026-10-04
**Status:** Active

**Context:**
The interface is bilingual (ES and EN) while the sign language is LSC. Adding a language must not touch the sign or the model.

**Decision:**
`name`, `meaning` and `description` are stored per `ui_language` (`ES`, `EN`). Reads accept `?lang=` and fall back to ES and then to any localization. `word` and `description` in request bodies are shortcuts for the ES localization. A sign cannot be published without an ES name.

**Alternatives considered:**
- Text columns in `sign_lexicon`: used in the first version; one column per language does not scale and mixes sign data with translations.

**Consequences:**
- Advantage: adding English means inserting rows.
- Trade-off: every read joins localizations.

---

## [DEC-004] Signs are created as `DRAFT` and published explicitly

**Date:** 2026-10-04
**Status:** Active

**Context:**
Only reviewed content should reach end users.

**Decision:**
`POST /` always creates the sign in `DRAFT` (it ignores any `status` sent). `POST /:code/publish` moves `DRAFT` or `INACTIVE` to `ACTIVE`, and in the target publishes `lexicon.SignPublished`. Public reads return only `ACTIVE` signs; `/admin/signs` shows every status.

**Alternatives considered:**
- Create as `ACTIVE`: an incomplete sign would be visible immediately.

**Consequences:**
- Advantage: an editorial step before publication, and a clear moment to emit the event.
- Trade-off: two calls to add a visible sign.

---

## [DEC-005] Resource URLs are validated against an allow list

**Date:** 2026-10-04
**Status:** Active

**Context:**
An administrator can attach media to a sign, and the URL ends up in the app (images and 3D models). An arbitrary URL would allow content from any origin.

**Decision:**
A resource URL is either a relative path with an allowed extension (`glb`, `gltf`, `png`, `jpg`, `jpeg`, `webp`, `gif`, `mp4`, `webm`) or an `https` URL whose origin equals the origin of `LEXICON_MEDIA_BASE_URL`. Without that variable no absolute URL is accepted. The API returns relative paths as absolute URLs. Positions are unique per sign (`POSITION_TAKEN`).

**Alternatives considered:**
- Accept any URL: simpler, but opens the app to untrusted content.
- Upload endpoint: not needed yet; files are copied into `public/lexicon/` or a CDN.

**Consequences:**
- Advantage: media can move to a CDN without changing the data.
- Trade-off: adding a new media origin requires configuration.

---

## [DEC-006] Public reads, ADMIN-only writes; role checked in the database

**Date:** 2026-10-04
**Status:** Superseded by DEC-008 (the public-reads part stays Active)

**Context:**
The alphabet screen must work without a session, but editing the catalog must be restricted.

**Decision (as implemented today):**
Read routes have no authentication. Write routes use `authMiddleware` and then `requireAdmin` (`requireRole('ADMIN')`), which checks `user_role` in the shared PostgreSQL on every request. A user without the role gets `403 FORBIDDEN`.

**Alternatives considered:**
- Roles inside the JWT: they would go stale until the token expires (1 day) after a role change.

**Consequences:**
- Advantage: role changes take effect immediately.
- Trade-off: one extra query per admin request, and a dependency on tables of another domain.

---

## [DEC-007] Domain errors carry their public code and HTTP status

**Date:** 2026-10-04
**Status:** Active

**Context:**
The HTTP layer must translate business failures without a switch over message strings.

**Decision:**
Every business error extends `LexiconError` (`rules.ts`) with a `code` and an `httpStatus`; the controller answers `{ success: false, code, message }` using them. Use cases receive their repositories as parameters (`make<UseCase>(deps)`), so they are tested with fakes (`backend/tests/helpers/fakes.ts`).

**Alternatives considered:**
- Generic `Error` with a message, as the `auth` module does: the controller can only answer 400.

**Consequences:**
- Advantage: precise status codes (404, 409) and stable codes the app can rely on.
- Trade-off: a new error needs a new class.

---

## [DEC-008] In the service, the ADMIN role comes from the token and `created_by` is a logical ID

**Date:** 2026-10-04
**Status:** Active (applies at extraction)

**Context:**
Database per service: lexicon cannot read `user_role` or reference `users` with a foreign key. The spec says iam issues the JWT and
services read `sub` and `roles` from the forwarded token; ADMIN is required for lexicon writes.

**Decision:**
Replace `postgresRoleChecker` with a role checker adapter that reads the `roles` claim (the `RoleChecker` is already a port in
`shared/security/role_checker.ts`, so only the adapter changes). `created_by` / `updated_by` store the `sub` of the token with no FK.
`003_lexicon.sql` stops creating `role` and `user_role`.

**Alternatives considered:**
- Call iam on every admin write: adds a synchronous dependency.

**Consequences:**
- Advantage: the lexicon has no dependency on another domain's tables; the use cases and the controller do not change.
- Trade-off: a revoked ADMIN keeps the right until the access token expires (short-lived token, see `../02-iam-service/decisions.md` DEC-002).

---

## [DEC-009] Events are emitted from the use cases through an outbox port

**Date:** 2026-10-04
**Status:** Proposed

**Decision:**
`publish_sign` and `deactivate_sign` call an `EventPublisher` outbound port; the adapter writes to an `outbox` table in the same transaction and a relay publishes to RabbitMQ. This keeps the domain free of the broker.

**Consequences:**
- Advantage: no event is lost or emitted for a rolled-back change.
- Trade-off: one more table and a relay process.
