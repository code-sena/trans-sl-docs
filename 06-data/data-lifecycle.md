# Data Lifecycle, Retention and Law 1581

> What happens to each kind of data over time, and what happens to all of it when a person exercises
> their right to be deleted. This model holds biometric data of identifiable people, which makes this a
> requirement rather than good practice.

**Version:** v0.1 · **Last updated:** 2026-09-10
**Legal basis:** RNF8 · **Law 1581 of 2012** (habeas data, Colombia) · **Decree 1377 of 2013**

---

## 1. Lifecycle by kind of data

| Data | Where it lives | Lifecycle |
|------|----------------|-----------|
| Account and personal data | `identity.users` | Soft delete on request (`deleted_at`). ⚠️ Anonymization required and **unimplemented** — DATA-06 |
| Consent evidence for the account | `users.terms_accepted_at`, `users.terms_version` | Kept while the account exists **and after** — it is the proof |
| Credentials and tokens | `password_hash`, `refresh_tokens`, `user_tokens` | Hashed, never in clear. Expired and revoked rows purged on a schedule |
| Login sessions | `identity.user_sessions` | Kept for RF6; `user_id` nulled when the account goes |
| Translation history | `translation.translations` | The user's own data. Individually deletable (ERF5.5); **cascades away with the account** |
| Sign catalog and media | `lexicon.*` | Never personal data. Retired by `status`, not deleted |
| Gesture samples | `gesture_samples` (MongoDB) | Kept while the authorization holds. A revocation discards **every sample of the affected `capture_session_id`** |
| Registered devices | `notification.user_devices` | Revoked (`is_active = FALSE`), never deleted. Cascades with the account |
| Notifications | `notification.notifications` | Personal. Cascades with the account |
| Usage events | `usage.usage_events` | Survive the account (`SET NULL`). Statistical facts, **not personal data — once `user_id` is null** |
| Rollups | `usage.*_daily_stats` | Never held personal data. Recomputed nightly |
| Audit and error trail | `audit.audit_logs`, `audit.error_logs` | Survive the account. ⚠️ No retention policy — DATA-10 |

---

## 2. Right of deletion, as the schema implements it today

Setting `users.deleted_at` triggers three different behaviours, and each one is the right answer for
what that row means:

```
users.deleted_at = now()
   │
   ├─ CASCADE  → user_auth_providers, user_tokens, user_preferences,
   │             user_devices, notifications, translations, user_achievements
   │             "personal data with no meaning after the account"
   │
   ├─ SET NULL → user_sessions, usage_events, audit_logs, error_logs
   │             "the fact survives the person"
   │
   └─ the users row itself stays — ⚠️ still holding full_name, email, username in clear
```

**The missing step is the anonymization of the surviving row.** RNF8 says it is "kept anonymized";
nothing in the schema does the anonymizing. The routine is a requirement, not a nicety:

```sql
UPDATE identity.users
   SET full_name      = 'deleted user',
       email          = 'deleted+' || user_id || '@invalid.local',
       username       = 'deleted_' || left(user_id::text, 8),
       birth_date     = NULL,
       password_hash  = NULL,
       last_access_at = NULL
 WHERE user_id = $1 AND deleted_at IS NOT NULL;
```

**Note what this does and does not solve.** It removes the personal data. It does **not** free the
original email for re-registration — the `UNIQUE` constraint is still occupied by the placeholder, by
design, so that the account cannot be silently resurrected by someone signing up with the same address.
Whether that is the desired behaviour is a decision the team should make explicitly rather than inherit
from a constraint.

**Gesture samples are not reached by this cascade at all** — they are in MongoDB with no foreign key.
Deleting an account must trigger a separate operation against that collection, keyed by
`capture_session_id` or `performed_by`. **A deletion flow that forgets this is a deletion flow that
leaves biometric data behind**, which is precisely the failure Law 1581 exists to prevent.

---

## 3. Consent, and what makes it provable

Three columns carry the legal weight of this project:

| Column | What it proves |
|--------|----------------|
| `users.terms_accepted_at` | **When** the person authorized |
| `users.terms_version` | **What** they authorized — consent that cannot say which document was accepted is not provable consent |
| `gesture_samples.consent_granted_at` + `consent_terms_version` | The same pair, per performer, for the biometric corpus. Both are `required` in the validator: **a sample with no proof of consent cannot physically exist** |

`terms_accepted_at` and `terms_version` are `NOT NULL` on `users`, which means an account cannot be
created without them (INV-002). That is the difference between a checkbox and an obligation.

> **Revocation is terminal** (INV-009). A withdrawn authorization is never reactivated — authorizing
> again creates a new grant with its own timestamp and policy version. The schema does not model
> `ConsentGrant` as its own table today; the evidence lives as columns on two tables, which is one of
> the entity-without-a-table items in [`open-items.md`](open-items.md).

---

## 4. Retention

| Store | Current policy | What it should be |
|-------|----------------|-------------------|
| `audit_logs` | **None** — grows with every write to every table | Monthly partitioning by `created_at`, or purge beyond N months with archival to object storage |
| `error_logs` | **None** — grows with traffic and incidents | Same decision, same conversation |
| `usage_events` | **None** — grows with every screen opened | Same. The rollups mean old raw events are less needed over time |
| `refresh_tokens`, `user_tokens` | Implied by `expires_at` | A scheduled purge of expired and revoked rows. They are credentials; keeping spent ones has no upside |
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
  Restricted access or column-level encryption is the mitigation.
- **A deletion must be verifiable.** Whatever the flow does, there must be a way to demonstrate
  afterwards that it did it — which is what the audit trail is for, and why it survives the account.

---

## Correlations

- The account and its deletion → [`domains/01-identity.md`](domains/01-identity.md)
- Biometric samples and the consent columns → [`domains/06-ai.md`](domains/06-ai.md)
- Logs that survive the user → [`domains/10-audit.md`](domains/10-audit.md)
- DATA-06 and DATA-10 → [`open-items.md`](open-items.md)
- Encryption, secrets and access control → `00-governance/security-policy.md`
- RNF8 acceptance criteria → `04-requirements/non-functional.md`
- Consent as a domain concept → `02-domain/domain-map.md`, Consent & Personal Data
