# Identity — Data Model

> **Domain 1 of 10** · Bounded Context: **Identity & Access** (Generic) · PostgreSQL schema: `identity`
> **Tables:** `users`, `user_auth_providers`, `user_sessions`, `refresh_tokens`, `user_tokens`, `password_policies`
> **Requirements:** RF1 · ERF1.1, ERF1.2, ERF1.3 · ERF5.3 · RNF4 · FR-905 … FR-907

**Owned by:** iam-service (PostgreSQL db `iam`)
**Version:** v0.2 · **Last updated:** 2026-09-10 · **Source:** `traduce_senas.dbml` (v9)
**Conventions:** [`../modeling-conventions.md`](../modeling-conventions.md) · **Constraints:** [`../constraints.md`](../constraints.md) · **Open items:** [`../open-items.md`](../open-items.md)

---

## What this domain owns

Account lifecycle and authentication: registration, email verification, native and external-provider
sign-in, password recovery, login sessions, the security lockout ladder, **and the password policy those
flows validate against**.

**It does not own authorization.** What a person *may do* lives in
[`02-authorization.md`](02-authorization.md), which references `user_id` and nothing else. This domain
answers "who is this?"; that one answers "what may they do?".

> **`password_policies` moved here in v9 of the model.** It used to be a `Configuration` domain of its
> own. The test for a cross-cutting service is whether it serves *every* context equally — `audit_logs`
> and `error_logs` pass it, because any domain writes to them. `password_policies` fails it: it is read
> by exactly one flow, in exactly one context, and by nothing else. A domain of one table with one
> consumer is not a domain. See the rationale in § *Why the policy lives here* below.

---

## `users`

**Purpose:** the account. Holds credentials, verification state, the progressive lockout ladder and the
provable evidence of terms acceptance.

```sql
CREATE TABLE identity.users (
  user_id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),

  username              VARCHAR(255) NOT NULL UNIQUE,
  full_name             VARCHAR(255) NOT NULL,                    -- ERF1.1 / ERF5.1
  birth_date            DATE,                                     -- ERF1.1 asks for age; the date is stored, the age computed
  email                 VARCHAR(255) NOT NULL UNIQUE,             -- INV-001
  password_hash         VARCHAR(255),                             -- NULL when the account only signs in through a provider
  status                user_status  NOT NULL DEFAULT 'INACTIVE',

  email_verified_at     TIMESTAMPTZ,

  -- Progressive lockout ladder (INV-014)
  failed_login_attempts INTEGER      NOT NULL DEFAULT 0,
  lockout_level         INTEGER      NOT NULL DEFAULT 0,
  locked_until          TIMESTAMPTZ,
  last_failed_login_at  TIMESTAMPTZ,
  blocked_at            TIMESTAMPTZ,

  -- Provable consent (INV-002, RNF8)
  terms_accepted_at     TIMESTAMPTZ  NOT NULL,
  terms_version         VARCHAR(20)  NOT NULL,

  created_at            TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at            TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_access_at        TIMESTAMPTZ,
  deleted_at            TIMESTAMPTZ                               -- RNF8: the row is kept, anonymized
);

CREATE INDEX idx_users_status ON identity.users (status);
CREATE INDEX idx_users_locked ON identity.users (locked_until);
```

**Data dictionary — the columns that are not self-evident:**

| Column | Meaning | Values / example |
|--------|---------|------------------|
| `status` | Account state. `INACTIVE` is what `02-domain/` calls `PENDING_VERIFICATION`: registered, email not yet confirmed. Registration through Google/Facebook inserts `ACTIVE` directly | `ACTIVE` · `INACTIVE` · `BLOCKED` |
| `password_hash` | Argon2id or bcrypt hash. **Never the password.** `NULL` is legitimate: an account that only exists through an external provider has no password to hash | `$argon2id$v=19$…` |
| `failed_login_attempts` | Consecutive failures towards the *next* lockout. Reset to 0 on a successful sign-in and on each lockout | `0` … `5` |
| `lockout_level` | Lockouts accumulated in the current streak. Determines the next wait: 1, 5, 10 minutes. Resets to 0 after 24 h with no failures (`last_failed_login_at`) | `0` … `3` |
| `locked_until` | End of the temporary lockout. **This is why there is no `LOCKED` status:** a state has to be exited by somebody, and nobody runs a job every minute to unlock accounts. A future timestamp expires on its own | `2026-09-10T14:31:00Z` |
| `blocked_at` | When the ladder was exhausted and the account became `BLOCKED`. Only an administrator restores it (RNF4) | `NULL` |
| `terms_version` | Version of the document the user accepted. **Consent that cannot say *what* was accepted is not provable consent** (Law 1581) | `1.0` |
| `deleted_at` | Deletion requested by the data subject. The row survives so that `usage_events` and `audit_logs` keep their `ON DELETE SET NULL` meaning | `NULL` |

**Modeling decisions:**

1. **`status` defaults to `INACTIVE`, not `ACTIVE`.** An account starts unverified; the provider path
   inserts `ACTIVE` explicitly. The default is the safe value, which is the point of a default.
2. **`birth_date` instead of `age`.** ERF1.1 asks for age. Age is a value that becomes wrong every year;
   a date of birth never does.
3. **The lockout ladder lives in four columns, not in a separate table.** They are attributes of the
   account, read and written on every failed sign-in. A `login_attempts` table would be a write per
   failure and a join per sign-in, for data nobody queries historically.
4. ⚠️ **A soft-deleted user still occupies `email` and `username`.** Both are `UNIQUE` over the whole
   table, so a deleted account's email can never be registered again, and the row still holds
   `full_name` and `email` in clear. RNF8 says the row is "kept anonymized" — nothing in the schema does
   the anonymizing. See DATA-06 and [`../data-lifecycle.md`](../data-lifecycle.md).

---

## `user_auth_providers`

**Purpose:** links to Google and Facebook. Replaces what would otherwise be an `auth_type` column on
`users` — ERF1.2 names both providers, and a user may link both to one account.

```sql
CREATE TABLE identity.user_auth_providers (
  auth_provider_id  UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID          NOT NULL REFERENCES identity.users (user_id) ON DELETE CASCADE,
  provider          auth_provider NOT NULL,
  provider_user_id  VARCHAR(255)  NOT NULL,
  email_provider    VARCHAR(255),
  linked_at         TIMESTAMPTZ   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX uq_provider_identity ON identity.user_auth_providers (provider, provider_user_id);
CREATE UNIQUE INDEX uq_user_provider     ON identity.user_auth_providers (user_id, provider);
```

**The two unique indexes are two different rules**, and both are needed:

- `uq_provider_identity` — one Google account cannot be linked to two Traduce Señas accounts (INV-004).
- `uq_user_provider` — one Traduce Señas account cannot hold two Google links.

Without the first, an attacker links their Google identity to someone else's account. Without the
second, the same account accumulates duplicate links and "sign in with Google" becomes ambiguous.

`email_provider` is stored separately from `users.email` because they legitimately differ: the
provider's email can change without the account's email changing, and the account may have been created
with a different address entirely.

---

## `user_sessions`

**Purpose:** a **login** session — sign-in to close, with its IP and duration. It is the source for the
RF6 usage-time metrics.

```sql
CREATE TABLE identity.user_sessions (
  session_id       UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID           REFERENCES identity.users (user_id) ON DELETE SET NULL,
  started_at       TIMESTAMPTZ    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ended_at         TIMESTAMPTZ,
  duration_seconds INTEGER,                                       -- RF6, computed on close
  ip_address       INET,
  status           session_status NOT NULL DEFAULT 'ACTIVE',
  last_activity_at TIMESTAMPTZ
);

CREATE INDEX idx_sessions_user_started ON identity.user_sessions (user_id, started_at);
CREATE INDEX idx_sessions_status       ON identity.user_sessions (status);
```

> **This is not a translation session.** `user_sessions` is a login period; `TranslationSession` in
> `02-domain/` is a period with the camera on. They are never named alike — and the second one has no
> table at all, which is ALIGN-01. See [`05-translation.md`](05-translation.md).

`user_id` is nullable with `ON DELETE SET NULL`: when an account is deleted its sessions stay, so the
aggregate usage-time report does not shift retroactively. `duration_seconds` is denormalized — see
[`../normalization-assessment.md`](../normalization-assessment.md).

---

## `refresh_tokens`

**Purpose:** refresh-token rotation with reuse detection.

```sql
CREATE TABLE identity.refresh_tokens (
  refresh_token_id     UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id           UUID         NOT NULL REFERENCES identity.user_sessions (session_id) ON DELETE CASCADE,
  token_hash           VARCHAR(255) NOT NULL UNIQUE,
  issued_at            TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at           TIMESTAMPTZ  NOT NULL,
  revoked_at           TIMESTAMPTZ,
  replaced_by_token_id UUID         REFERENCES identity.refresh_tokens (refresh_token_id) ON DELETE SET NULL
);

CREATE INDEX idx_refresh_session ON identity.refresh_tokens (session_id);
CREATE INDEX idx_refresh_expires ON identity.refresh_tokens (expires_at);
```

**`replaced_by_token_id` is the part worth defending.** Rotation without it is just short-lived tokens.
With it, a token presented *after* it has been replaced is proof that someone is holding a stolen copy —
and the correct response is to revoke the whole chain, not just refuse the request. Most implementations
omit this column and lose the only signal rotation was invented to produce.

The token is stored as a hash, like a password. A refresh token in clear in a database is a credential
in clear in a database.

---

## `user_tokens`

**Purpose:** one table for both single-use codes — the 6-digit email verification code and the password
reset link token — distinguished by `token_type`.

```sql
CREATE TABLE identity.user_tokens (
  token_id   UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID         NOT NULL REFERENCES identity.users (user_id) ON DELETE CASCADE,
  token_type token_type   NOT NULL,
  token_hash VARCHAR(255) NOT NULL,
  expires_at TIMESTAMPTZ  NOT NULL,
  used_at    TIMESTAMPTZ,
  attempts   INTEGER      NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_user_tokens_lookup ON identity.user_tokens (user_id, token_type, created_at);
```

Both token kinds have exactly the same lifecycle — issued, hashed, expiring, single-use, attempt-counted
— so they are one table with a discriminator rather than two tables with identical columns (INV-015).
This supersedes the `password_reset_tokens` table named in the DBML traceability comment, which does not
exist (GAP-03).

`used_at` is what makes a code single-use: validation requires `used_at IS NULL AND expires_at > now()`.
`attempts` is what stops a 6-digit code from being brute-forced — a million tries against six digits is
minutes of work without it.

---

## `password_policies`

**Purpose:** the password rules in force, and the history of the rules that were in force before.

```sql
CREATE TABLE identity.password_policies (
  password_policy_id UUID        PRIMARY KEY DEFAULT gen_random_uuid(),

  min_length         INTEGER     NOT NULL DEFAULT 8,
  max_length         INTEGER     NOT NULL DEFAULT 20,

  requires_uppercase BOOLEAN     NOT NULL DEFAULT TRUE,
  requires_lowercase BOOLEAN     NOT NULL DEFAULT TRUE,
  requires_numbers   BOOLEAN     NOT NULL DEFAULT TRUE,
  requires_symbols   BOOLEAN     NOT NULL DEFAULT TRUE,

  is_active          BOOLEAN     NOT NULL DEFAULT TRUE,

  created_at         TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

| Column | Meaning | Default |
|--------|---------|---------|
| `min_length` / `max_length` | Length bounds the password must satisfy | 8 … 20 |
| `requires_*` | Which character classes are mandatory | All four `TRUE` |
| `is_active` | Whether this is the policy in force. **Several rows exist; exactly one is active** (INV-026) | `TRUE` |

**It has no foreign key to `users`, and must not have one.** The policy is not *a user's* policy — it is
the rule that applies to all of them. That is precisely why it is a table in this schema rather than a
column on `users`.

**Why it is a table and not a config file:** because the history is the point. The policy is versioned
by keeping rows, never by overwriting one:

```
policy A (2026-01, is_active = FALSE)  → min 8, no symbols required
policy B (2026-09, is_active = TRUE)   → min 8, symbols required
```

Knowing which rules were in force **when a given account was created** is auditable; an `UPDATE` in
place destroys that. It is the same reasoning as `users.terms_version`: what matters is not only what the
rule is now, but what it was then.

⚠️ **The single-active rule is not enforced by the model as it stands.** Nothing stops two rows with
`is_active = TRUE`, and then validation depends on which row is read first.
`uq_single_active_policy` — a partial unique index on `is_active = TRUE`, in
[`../constraints.md`](../constraints.md) — is what makes INV-026 real.

### Why the policy lives here

The move from a `Configuration` domain into `identity` is a modeling decision, so here is the reasoning
in full:

| Test | `audit_logs`, `error_logs` | `password_policies` |
|------|---------------------------|---------------------|
| Who writes to it? | Every domain | An administrator, through one screen |
| Who reads it? | Operations, any investigation | **Identity only** — `User.register()` and `changePassword()` |
| Does it borrow other domains' vocabulary? | Yes — `entity_type` is any table in the model | No. Its vocabulary is *password*, which is Identity's word |
| Would another context break if it disappeared? | Every context loses its trail | Only Identity |
| **Cross-cutting?** | ✅ Yes | ❌ **No** |

`02-domain/domain-map.md` § 2.9 defines a cross-cutting service as one that "serves every context
equally". By that definition `password_policies` never qualified — it was grouped with the genuinely
cross-cutting tables because it *looked* like configuration, which is a statement about the shape of the
data, not about who owns it.

**The objection worth answering:** an administrator manages this table, not the account holder — so is it
really Identity's? Yes: `roles`, `permissions` and `ai_models` are all administrator-managed and none of
them is homeless because of it. Who operates a table does not determine which context owns it; who
*depends* on it does.

**What it costs:** the `config` schema is now empty and disappears. If a second setting ever appears —
a confidence threshold, a retention window — there is no generic bucket to drop it into. That is the
intended outcome: the same reasoning that placed this table will place that one, and the threshold in
particular belongs on `ai_models`, which is where [`06-ai.md`](06-ai.md) already puts it. **A `config`
schema is a place to avoid deciding where something belongs.**

---

## Invariants this domain enforces

| Invariant | Where it is enforced |
|-----------|----------------------|
| INV-001 — unique email | `users.email UNIQUE` |
| INV-002 — no registration without accepted terms | `terms_accepted_at NOT NULL` + `terms_version NOT NULL` |
| INV-003 — the password is never stored in clear | `password_hash` holds a hash; enforced in code by the `PasswordHash` value object |
| INV-004 — an external provider maps to a single account | `uq_provider_identity` |
| INV-014 — the lockout escalates and expires on its own | Four columns on `users` + `ck_users_blocked_coherent` |
| INV-015 — verification and recovery codes are single-use and expire | `user_tokens.used_at`, `expires_at`, `attempts` |
| INV-026 — exactly one password policy is in force | `uq_single_active_policy` |

---

## Open items affecting this domain

| ID | Summary |
|----|---------|
| **DATA-06** | A soft-deleted `users` row keeps name, email and username in clear, and permanently occupies both `UNIQUE` constraints. The anonymization routine is in [`../data-lifecycle.md`](../data-lifecycle.md) and is unimplemented |
| **DATA-07** | `updated_at` has a `DEFAULT` and no trigger — it never changes after insert |
| **ALIGN-05** | The domain names four account states (`PENDING_VERIFICATION`/`ACTIVE`/`LOCKED`/`DELETED`); this model uses three plus two timestamps. Unify the names |
| **ALIGN-06** | The `User` code example in `02-domain/` still implements "five failures → LOCKED"; the model implements the progressive ladder. The model's rule is the better one — update the domain |
| **ALIGN-09** | The domain models `PasswordResetRequest` as its own aggregate; the model uses `user_tokens` for both token kinds. The model is better — update the domain |
| **GAP-03** | The DBML traceability comment cited `password_reset_tokens`, which does not exist. **Fixed in v9** — it now cites `user_tokens` |
| **DATA-11** | `uq_single_active_policy` and `ck_policy_length` do not exist yet — the constraints migration is unwritten, so the database currently accepts two policies in force |
| **DATA-12** | The FR-900 series groups audit, errors and password policy as one cross-cutting module. After the v9 move, FR-905 … FR-907 belong to the Identity module |

---

## Correlations

- Entities and invariants → [`../../02-domain/entities-and-rules.md`](../../02-domain/entities-and-rules.md) — `User`, `LoginSession`, `PasswordResetRequest`, `PasswordPolicy`
- Roles and permissions, and the `security.policy.manage` permission → [`02-authorization.md`](02-authorization.md)
- Preferences of the same user → [`03-profile.md`](03-profile.md)
- The dissolved `Configuration` domain → no file of its own; the reasoning is in this document and in [`../models.md`](../models.md)
- Auth contract → `07-api/contracts/openapi/auth-service.yaml`
- Hashing, secrets and why `max_length` is questionable → `00-governance/security-policy.md`
