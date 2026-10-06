# Authorization — Data Model

> **Domain 2 of 10** · Bounded Context: **Identity & Access** (Generic) · PostgreSQL schema: `authz`
> **Tables:** `roles`, `permissions`, `user_roles`, `role_permissions`
> **Requirements:** RF6 (admin access) · cross-cutting access control

**Owned by:** iam-service (PostgreSQL db `iam`)
**Version:** v0.2 · **Last updated:** 2026-09-10 · **Source:** `traduce_senas.dbml` (v9)
**Conventions:** [`../modeling-conventions.md`](../modeling-conventions.md) · **Constraints:** [`../constraints.md`](../constraints.md) · **Open items:** [`../open-items.md`](../open-items.md)

---

## What this domain owns

Role-based access control. It is a separate file, but **not a separate bounded context**: it shares the
ubiquitous language of Identity & Access (`User`, `Role`) and answers the second half of the same
question — who is this person, and what may they do.

**Why it stopped being an enum.** Until v1.0 of the domain model, `role` was a value on `users` holding
`USER` or `ADMIN`. Then the LSC **linguist** appeared: a third profile that needs `samples.validate` and
none of the administrator's other capabilities. Adding a value to an enum for every new capability is
how an enum becomes a permission system by accident. Better to have the permission system on purpose.

---

## The four tables

```sql
CREATE TABLE authz.roles (
  role_id     UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name        VARCHAR(50) NOT NULL UNIQUE,
  description VARCHAR(255)
);

CREATE TABLE authz.permissions (
  permission_id UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  name          VARCHAR(100) NOT NULL UNIQUE,
  description   VARCHAR(255)
);

CREATE TABLE authz.user_roles (
  user_id     UUID        NOT NULL REFERENCES identity.users (user_id) ON DELETE CASCADE,
  role_id     UUID        NOT NULL REFERENCES authz.roles (role_id)    ON DELETE RESTRICT,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, role_id)
);

CREATE TABLE authz.role_permissions (
  role_id       UUID        NOT NULL REFERENCES authz.roles (role_id)             ON DELETE CASCADE,
  permission_id UUID        NOT NULL REFERENCES authz.permissions (permission_id) ON DELETE CASCADE,
  assigned_at   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (role_id, permission_id)
);
```

**Data dictionary:**

| Column | Meaning | Example |
|--------|---------|---------|
| `roles.name` | Role name, unique across the system | `ADMIN`, `LINGUIST` |
| `permissions.name` | A single capability, in `resource.action` form. The dot is a convention, not a parser: keep it consistent so a wildcard check stays possible later | `stats.read`, `samples.validate` |
| `user_roles.assigned_at` | When the role was granted. The only attribute of the pair, and it depends on the whole pair — which is why this table is in 2NF with no surrogate key | `2026-09-10T09:12:00Z` |

---

## Modeling decisions

1. **There is no `user_permissions` table, deliberately** (INV-016). A permission reaches a user only
   through a role. The moment individual exceptions are grantable, nobody can answer "who can do this?"
   without scanning the exceptions — and that question is the entire purpose of an access-control model.
2. **No surrogate key on either junction table.** The composite of the two foreign keys *is* the
   identity of the row. A third `id` column would add nothing and would allow the same pair twice.
3. **`user_roles.role_id` is `RESTRICT`, `role_permissions.role_id` is `CASCADE`.** Deleting a role that
   somebody holds is refused (INV-017: users must not silently lose their permissions). Deleting a role
   nobody holds takes its permission grants with it, because those grants mean nothing without the role.
4. **No indexes beyond the primary keys.** Both tables are queried by their leading column
   (`user_roles` by `user_id`, `role_permissions` by `role_id`), which the composite PK index already
   serves. Reverse lookups ("who holds this role?") are administrative and rare; if they become frequent,
   an index on the trailing column is the addition — not before.

---

## Seed data

`S001__seed_roles_permissions.sql`. These rows are not test data: the system does not work without them.

| Role | Permissions | Who |
|------|-------------|-----|
| `USER` | `translation.create`, `translation.read.own`, `translation.delete.own`, `lexicon.read`, `profile.manage.own` | Every account, assigned at registration |
| `LINGUIST` | everything in `USER`, plus `samples.capture`, `samples.validate`, `lexicon.write` | Captures and validates gesture samples. **Does not administer users** |
| `ADMIN` | everything, plus `users.manage`, `stats.read`, `models.manage`, `notifications.manage`, `security.policy.manage` | Administration panel |

> **`USER` must be seeded and assigned, not implied.** `02-domain/` states every user holds at least one
> role. If the registration flow forgets the `user_roles` insert, the account authenticates and can do
> nothing — and the failure looks like a permissions bug rather than a missing row.

---

## Invariants this domain enforces

| Invariant | Where it is enforced |
|-----------|----------------------|
| INV-012 — only the administrator sees statistics | `stats.read` granted to `ADMIN` only, checked in the application layer |
| INV-016 — permissions are granted through roles, never directly | The absence of a `user_permissions` table |
| INV-017 — a role in use cannot be deleted | `ON DELETE RESTRICT` on `user_roles.role_id` |

---

## Correlations

- The account these roles are attached to → [`01-identity.md`](01-identity.md)
- `Role` and `Permission` entities, and why they replaced a value object → [`../../02-domain/entities-and-rules.md`](../../02-domain/entities-and-rules.md)
- The reversal that created them → [`../../02-domain/domain-map.md`](../../02-domain/domain-map.md) § 5
- Who may read statistics → [`08-usage.md`](08-usage.md)
- Who may validate samples → [`06-ai.md`](06-ai.md)
- Who may change the password policy (`security.policy.manage`, renamed from `config.manage` in v9) → [`01-identity.md`](01-identity.md)
