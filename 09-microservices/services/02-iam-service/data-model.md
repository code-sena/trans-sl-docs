# Data Model — IAM Service

> `iam-service` is the **authoritative owner** of the data described here. No other service reads these tables.
> Other services keep only `user_id` (a UUID) as a logical reference and learn about changes through events.

**Source of truth for the target model:** `06-data/domains/01-identity.md`, `02-authorization.md`, `10-audit.md` (full DDL, data dictionary and invariants live there; this file is the service view and does not repeat the DDL).

---

## Database engine

**Engine:** PostgreSQL, database `iam`, schemas `identity`, `authz` and `audit`.
**Justification:** accounts, roles and the audit trail are relational and transactional (unique email, one active policy,
role assignment with referential integrity inside the same database).

---

## Tables

### Schema `identity`

| Table | Purpose | Key facts |
|-------|---------|-----------|
| `users` | The account: credentials, status (`ACTIVE`, `INACTIVE`, `BLOCKED`), lockout ladder, accepted terms | `user_id` UUID PK; `email` and `username` UNIQUE; `password_hash` nullable (provider-only accounts); `terms_accepted_at` and `terms_version` NOT NULL (provable consent); `deleted_at` for soft delete |
| `user_auth_providers` | Google / Facebook links | Unique `(provider, provider_user_id)` and unique `(user_id, provider)` |
| `user_sessions` | A login session (sign-in to close) | `user_id` nullable `ON DELETE SET NULL`; `duration_seconds` computed on close |
| `refresh_tokens` | Refresh-token rotation with reuse detection | `token_hash` UNIQUE; `replaced_by_token_id` links the chain; FK to `user_sessions` |
| `user_tokens` | Single-use codes: 6-digit email verification and password reset | `token_type`, `token_hash`, `expires_at`, `used_at`, `attempts` |
| `password_policies` | Rules in force and their history | Exactly one row `is_active = TRUE` (INV-026, index `uq_single_active_policy` pending, DATA-11) |

### Schema `authz`

| Table | Purpose | Key facts |
|-------|---------|-----------|
| `roles` | `USER`, `LINGUIST`, `ADMIN` | `name` UNIQUE |
| `permissions` | `resource.action` capabilities (`stats.read`, `samples.validate`, `lexicon.write`, `models.manage`, ...) | `name` UNIQUE |
| `user_roles` | Role held by a user | Composite PK `(user_id, role_id)`; `role_id` `ON DELETE RESTRICT` (INV-017) |
| `role_permissions` | Permissions of a role | Composite PK; there is no `user_permissions` table on purpose (INV-016) |

Seed data (`S001__seed_roles_permissions.sql`): `USER` is assigned to every account at registration; `LINGUIST` adds
`samples.capture`, `samples.validate`, `lexicon.write`; `ADMIN` has everything plus `users.manage`, `stats.read`,
`models.manage`, `notifications.manage`, `security.policy.manage`.

### Schema `audit`

| Table | Purpose | Key facts |
|-------|---------|-----------|
| `audit_logs` | Change trail with `old_values` and `new_values` (JSONB) | Append-only; `entity_type` + `entity_id` polymorphic, no FK; `user_id` `ON DELETE SET NULL`; never stores password hashes, token hashes or push tokens |
| `error_logs` | Technical failures | Append-only; `error_type` enum (`VALIDATION_ERROR`, `AUTH_ERROR`, ..., `MODEL_INFERENCE_ERROR`); `user_id` nullable |

`audit_logs.entity_id` points at entities of **other services** too (a sign, a model). It is a logical ID, never a foreign key.

### Consent

The `ConsentGrant` of the domain model has no table of its own in `06-data/`. Consent evidence today is
`users.terms_accepted_at` + `users.terms_version`; per-sample consent evidence (`consent_granted_at`,
`consent_terms_version`) lives with the sample in MongoDB `gesture_samples`, owned by `recognition-service`. A consent
table is an open item of the data team (see `06-data/open-items.md`, ALIGN-02) and is not invented here.

---

## Cross-service references

| This service stores | Points at | Rule |
|---------------------|-----------|------|
| `audit_logs.entity_id` | Any entity of any service | Logical ID, no FK |
| Nothing else | | iam depends on no other service's data |

Every other service references `identity.users.user_id` as a logical ID. The foreign keys that `06-data/domains/*.md`
declare to `identity.users` (translations, notifications, usage, etc.) are **dropped** in each service's own migrations
(database per service).

---

## What exists today (code)

Source: `backend/migrations/000_users.sql`, the Liquibase changelogs, and `003_lexicon.sql` (which creates `role`/`user_role`).
All in database `traduce_senas`, schema `public`, integer keys.

| Today (`public`) | Target |
|------------------|--------|
| `users(user_id SERIAL, name, email, password, terms_accepted, terms_accepted_at, created_at)` | `identity.users` (UUID, `password_hash`, status, lockout ladder, `terms_version`) |
| `password_reset_token(token_id, user_id, token_hash, expires_at, used_at, created_at)` | `identity.user_tokens` (covers verification and reset) |
| `role(role_id, name, description)`, `user_role(user_id, role_id)` | `authz.roles`, `authz.user_roles` (+ `permissions`, `role_permissions`) |
| none | `user_auth_providers`, `user_sessions`, `refresh_tokens`, `password_policies`, `audit_logs`, `error_logs` |

---

## Modeling decisions

- **The lockout ladder lives in four columns of `users`,** not in a separate table (read and written on each failed sign-in).
- **Tokens are stored hashed,** refresh tokens and codes alike.
- **A soft-deleted user keeps `email` and `username`** until the anonymization routine exists (DATA-06).
- **`updated_at` has no trigger** yet (DATA-07).
- **Roles in the JWT:** since other services cannot read `user_roles`, the role names travel as the `roles` claim.

---

## Schema migration

**Tool:** Liquibase (as the spec requires one migration set per service). Today plain SQL in `backend/migrations/` run with `psql`.
**Script location:** `iam-service/db/changelog/` (target).
**Naming convention:** `NNN-description.xml` / `.sql`, numbered in order. Seeds `S001` (roles and permissions).

**Rollback policy:**
- Each changeset has a rollback block when it is reversible. Data migrations from the integer-key schema to UUID are one-way: take a backup first.
- The migration of existing users from `public.users` (integer id) to `identity.users` (UUID) needs a mapping table kept until the other services have migrated their `user_id` columns.
