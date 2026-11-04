# Data Lifecycle, Retention and Law 1581

> What happens to each kind of data over time, and what happens to all of it when a person exercises
> their right to be deleted. This model holds biometric data of identifiable people, which makes this a
> requirement rather than good practice.

**Version:** v0.2 · **Last updated:** 2026-11-04
**Legal basis:** NFR-005 (regulatory compliance, Law 1581) in [`non-functional.md`](../04-requirements/non-functional.md) · **Law 1581 of 2012** (habeas data, Colombia) · **Decree 1377 of 2013**

---

## 1. Lifecycle by kind of data

| Data | Where it lives | Lifecycle |
|------|----------------|-----------|
| Account and personal data | `iam.users` (`public.users` in the iam database) | **Hard delete** on request (`DELETE /api/users/me`, confirmed with an email code). Other services erase their copies when they consume `iam.UserDeleted` (§ 2) |
| Consent evidence for the account | `users.terms_accepted_at`, `users.terms_version` | Kept while the account exists, deleted with the row. What survives the deletion is only the ids in `erased_users` (recognition, analytics, profile) and the `iam.UserDeleted` outbox row |
| Credentials and tokens | `users.password` (bcrypt), `user_tokens` | Hashed, never in clear. The account's `user_tokens` are deleted with the account. `refresh_tokens` is not implemented |
| Login sessions | — | No session table. Sessions are one JWT that lasts one day (`JWT_EXPIRES_IN`, default `1d`) |
| Translation history | `recognition.translations` | The user's own data. Individually deletable (ERF5.5); **deleted after 30 days** (see §4); erased with the account |
| Sign catalog and media | `lexicon.*` | Never personal data. `created_by` / `updated_by` keep the id of the author on purpose (ADR-008) |
| Sign templates (DTW: `static`, `motion`, `word`) | `recognition.sign_templates` | Not personal data in its features. `created_by` is the iam user id of the administrator who imported it (logical id, no FK). **Account deletion does not clear it**: the erasure in recognition deletes the user's translations and retention counts and unlinks the samples; it does not touch `sign_templates`. The id stays in the row; the table has no retention rule |
| Gesture samples | `gesture_samples` (MongoDB) | Kept. On account deletion `recorded_by` is set to null and the samples stay unlinked from the person (`mongo_sample_repository.ts`). `performed_by` is not changed. Revocation by capture session is not implemented |
| Registered devices | — | `user_devices` is not implemented (ADR-007) |
| Notifications | `profile.notifications` | Personal. Deleted with the account (profile erasure, § 2) |
| Usage events | `analytics.usage_event` | Survive the account: `user_id` and `session_id` are set to null (`UNLINK_USER`), and references to the user are unlinked |
| Rollups | `recognition.translation_daily_counts`, `translation_user_words` | Counts and distinct words kept after the 30-day purge, with no text and no time of day. Erased with the account. `usage_daily_stats` and `session_daily_stats` are not implemented |
| Audit and error trail | — | `audit_logs` and `error_logs` are not implemented (FR-901 … FR-904 are pending) |

---

## 2. Right of deletion, as the code implements it

Deleting an account is a **hard delete** of the iam row plus an event. There is no anonymized row.
The flow is split across services, because each service owns its own database (ADR-008):

```
DELETE /api/users/me   (after the code sent by email, token ACCOUNT_DELETION)
   │
   ▼
iam-service, one transaction (services/iam-service/src/users/adapters/outbound/postgres/account_repository.ts)
   ├─ locks the user row; refuses the deletion if it is the last ADMIN
   ├─ DELETE user_tokens, user_roles
   ├─ DELETE the legacy rows of user_role / user_auth / user_session / password_reset_token, if those tables exist
   ├─ INSERT outbox_events  (type iam.UserDeleted, payload { userId, occurredAt })
   └─ DELETE users
   │
   ▼  the relay publishes iam.UserDeleted (mandatory = true; retries with backoff)
   │
   ├─ recognition-service   deletes the user's translations, translation_daily_counts and translation_user_words,
   │                        sets recorded_by = null on the user's Mongo samples, records erased_users
   ├─ analytics-service     sets user_id and session_id to null in usage_event, unlinks references
   │                        to the user, records erased_users
   └─ profile-service       deletes its rows for the user (user_profiles, user_preferences, notifications,
                            user_achievements, achievement_activity, user_challenges, challenge_rewards, ...),
                            records erased_users
```

What this means in practice:

- **Nothing in iam keeps the personal data** after the transaction: the `users` row is gone.
- **Late events are refused.** Each service that keeps user data stores the id in its `erased_users`
  table, so a later event for that id does not recreate data (ADR-008).
- **Statistics survive without identity.** `usage_event` keeps the facts, with `user_id` null.
- **Consistency is eventual.** For a few seconds after the deletion, other services may still hold the
  user's data. The outbox keeps the event until it is published.

**Gesture samples are the exception to the "no identity" rule:** `recorded_by` is cleared, but the
document keeps `performed_by` and the frames. Whether a sample can still be linked to a person through
`performed_by` is an open question (ALIGN-02 in [`open-items.md`](open-items.md)).

---

## 3. Consent, and what makes it provable

Three columns carry the legal weight of this project:

| Column | What it proves |
|--------|----------------|
| `users.terms_accepted_at` | **When** the person authorized |
| `users.terms_version` | **What** they authorized — consent that cannot say which document was accepted is not provable consent |
| `gesture_samples.consent_granted_at` + `consent_terms_version` | The same pair, per performer, for the biometric corpus. Both are `required` in the validator: **a sample with no proof of consent cannot physically exist** |

On registration the application requires `acceptedTerms` and `termsVersion`
(`services/iam-service/src/auth/adapters/inbound/http/dto/register_request.ts`). The column
`users.terms_version` allows `NULL` (migration `013_users_terms_version.sql`): `NULL` marks accounts
created before the version was stored, and accounts created with a social provider without an explicit
consent. So the rule "no account without consent" is enforced by the application, not by the schema.
The reference model (DBML) declares both columns `NOT NULL`; that is not what is deployed.

> **Revocation is terminal** (INV-009). A withdrawn authorization is never reactivated — authorizing
> again creates a new grant with its own timestamp and policy version. The schema does not model
> `ConsentGrant` as its own table today; the evidence lives as columns on two tables, which is one of
> the entity-without-a-table items in [`open-items.md`](open-items.md).

---

## 4. Retention

| Store | Current policy | What it should be |
|-------|----------------|-------------------|
| `audit_logs` | Not implemented | Monthly partitioning by `created_at`, or purge beyond N months with archival to object storage |
| `error_logs` | Not implemented | Same decision, same conversation |
| `usage_event` (analytics) | **None** — grows with every screen opened | Same. The rollups mean old raw events are less needed over time |
| `user_tokens` | No purge job. Codes expire by `expires_at` and are checked in the application | A scheduled purge of expired and used rows. They are credentials; keeping spent ones has no upside |
| `translations` | **30 days.** recognition-service deletes older rows every 6 hours (`TRANSLATION_RETENTION_DAYS`, default 30; 0 turns it off). Their counts and distinct words move first to `translation_daily_counts` and `translation_user_words`, so stats keep their history; both are deleted with the account | Implemented |
| `gesture_samples` | While consent holds | Explicit maximum retention, restated in the authorization document the performer signs |

**Have this conversation once, for all three log tables.** It is free to decide now and expensive to
retrofit — DATA-10, and it belongs in `13-operations/observability.md` as much as here.

---

## 5. Security obligations this data creates

- **Encryption at rest is not optional** for the MongoDB store and for the object storage holding
  samples and media. A landmark sequence of a named person is biometric data.
- **Credentials must never reach the audit trail.** `password_hash`, `token_hash` and `push_token` must
  be filtered out of `old_values` / `new_values`. An audit log that copies credentials is a second, less
  protected credential store.
- **`push_token` is a secret stored in clear**, because the provider needs the value to deliver.
  Restricted access or column-level encryption is the mitigation. (Not applicable today: `user_devices`
  is not implemented.)
- **A deletion must be verifiable.** Whatever the flow does, there must be a way to demonstrate
  afterwards that it did it. Today the evidence is the `erased_users` table in each service and the
  `iam.UserDeleted` outbox row; a formal audit trail is not implemented.

---

## Correlations

- The account and its deletion → [`domains/01-identity.md`](domains/01-identity.md)
- Biometric samples and the consent columns → [`domains/06-ai.md`](domains/06-ai.md)
- Logs that survive the user → [`domains/10-audit.md`](domains/10-audit.md)
- DATA-06 and DATA-10 → [`open-items.md`](open-items.md)
- Encryption, secrets and access control → `00-governance/security-policy.md`
- Law 1581 requirements (NFR-005) → `04-requirements/non-functional.md`
- Consent as a domain concept → `02-domain/domain-map.md`, Consent & Personal Data
