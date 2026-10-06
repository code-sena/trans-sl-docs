# Audit — Data Model

> **Domain 10 of 10** · **Not a bounded context** — cross-cutting technical service · PostgreSQL schema: `audit`
> **Tables:** `audit_logs`, `error_logs`
> **Requirements:** no RF in the SRS (GAP-08) · FR-901 … FR-904 · RNF6 observability

**Owned by:** iam-service (PostgreSQL db `iam`)
**Version:** v0.2 · **Last updated:** 2026-09-10 · **Source:** `traduce_senas.dbml` (v9)
**Conventions:** [`../modeling-conventions.md`](../modeling-conventions.md) · **Constraints:** [`../constraints.md`](../constraints.md) · **Open items:** [`../open-items.md`](../open-items.md)

---

## Why this is not a bounded context

`audit_logs` records *that* something changed in any entity of any domain, storing the values before and
after. It has no vocabulary of its own — it borrows every other domain's. `error_logs` records technical
failures, and a stack trace is not a business fact.

A bounded context exists where a *term* means one specific thing. Neither of these has a term. They are
infrastructure for traceability, documented here so nobody looks for them in the domain map and concludes
it is incomplete.

---

## `audit_logs`

**Purpose:** the change trail. Who changed what, when, and **what the row looked like before and after.**

```sql
CREATE TABLE audit.audit_logs (
  audit_log_id UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID         REFERENCES identity.users (user_id) ON DELETE SET NULL,
  entity_type  VARCHAR(100) NOT NULL,                             -- the table affected
  entity_id    UUID,
  action       audit_action NOT NULL,                             -- INSERT | UPDATE | DELETE
  old_values   JSONB,
  new_values   JSONB,
  ip_address   INET,
  application  VARCHAR(100),
  created_at   TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_user_created ON audit.audit_logs (user_id, created_at);
CREATE INDEX idx_audit_entity       ON audit.audit_logs (entity_type, entity_id);
```

**It stores the values, not a description.** `old_values` and `new_values` as `jsonb` is the difference
between a log that can answer *"what did this row look like before?"* and one that can only say
*"something changed"*. `jsonb` rather than `json`: stored parsed, deduplicated keys, and indexable with
GIN if a query like `new_values @> '{"status":"BLOCKED"}'` is ever needed.

**`entity_id` has no foreign key and cannot have one** — it points at a different table per row, named
by `entity_type`. Same polymorphic pattern as `notifications.reference_type`, same trade-off, applied for
the same reason. `idx_audit_entity (entity_type, entity_id)` is what makes "the full history of this
row" a query.

**What must be audited** — the decision belongs in `00-governance/security-policy.md`, but the model
implies a minimum: account state changes, role assignments, catalog publication and retirement, model
activation, and password policy changes. Auditing every write to every table is possible and is how an
audit log grows faster than the data it audits.

> **Never write a password hash, a token hash or a `push_token` into `old_values` / `new_values`.** An
> audit trail that copies credentials is a second, less protected credential store. The column filter
> belongs in the audit writer, not in a code review checklist.

---

## `error_logs`

**Purpose:** technical failures — exceptions, external services down, model inference errors.

```sql
CREATE TABLE audit.error_logs (
  error_log_id UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID        REFERENCES identity.users (user_id) ON DELETE SET NULL,
  error_type   error_type  NOT NULL,
  message      TEXT        NOT NULL,
  stack_trace  TEXT,
  endpoint     VARCHAR(255),                                      -- route, method or job
  ip_address   INET,
  application  VARCHAR(100),
  occurred_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_errors_user_occurred ON audit.error_logs (user_id, occurred_at);
CREATE INDEX idx_errors_type          ON audit.error_logs (error_type);
CREATE INDEX idx_errors_date          ON audit.error_logs (occurred_at);
```

| `error_type` | What it classifies |
|--------------|--------------------|
| `VALIDATION_ERROR` | Invalid input data |
| `AUTH_ERROR` | Credentials, expired token, locked account |
| `PERMISSION_ERROR` | Authenticated but not authorized |
| `NOT_FOUND` | Resource does not exist |
| `MODEL_INFERENCE_ERROR` | The recognition model failed to process |
| `EXTERNAL_SERVICE_ERROR` | Push provider, mail, storage |
| `DATABASE_ERROR` | Database failure |
| `UNEXPECTED_ERROR` | Everything else — the catch-all |

`user_id` is nullable for a second reason here, not just deletion: **an error can occur with no
authenticated session at all** — a failed sign-in, a malformed request, a scheduled job.

`MODEL_INFERENCE_ERROR` is the one worth watching: it is the failure mode of the Core, and a rise in it
is the earliest signal that a newly activated model is worse than the one it replaced.

---

## Both logs survive the user

`ON DELETE SET NULL` on `user_id` in both tables. **A trace that disappears when the account does is not
a trace.** The entry keeps `ip_address`, `entity_id` and the values; it loses only the link to a person
who exercised their right to be forgotten. That is the correct balance between RNF8 and auditability —
and it is the same decision as `usage_events`, for a different reason.

---

## ⚠️ Neither log has a retention policy, and both grow without bound

`error_logs` grows with traffic and with every incident. `audit_logs` grows with **every write to every
table** — faster than any business table in the model.

At this project's scale that is not urgent, but it is the kind of thing that is free to decide now and
expensive to retrofit. Two options, either acceptable:

- **Monthly partitioning** by `created_at` / `occurred_at`, dropping or detaching old partitions.
- **A scheduled purge** beyond N months, with the older rows archived to object storage.

The decision belongs in `13-operations/observability.md` as much as here, and it is the same
conversation as partitioning `usage_events` — have it once, for all three (DATA-10).

---

## Modeling decisions

1. **No `updated_at`, no `deleted_at`, no soft delete.** Both tables are append-only. **An audit row is
   never updated and never deleted** — a mutable audit log is not an audit log.
2. **`application VARCHAR(100)` in both.** Identifies which component wrote the row (`mobile-app`,
   `admin-web`, `worker`). Cheap, and the first thing anyone wants when reading an unfamiliar entry.
3. **No `correlation_id` column, and there probably should be one.** RNF6 asks for structured logs with
   a correlation id; neither table has one, so an error cannot be tied to the audit entries of the same
   request. Worth raising when `13-operations/observability.md` is filled in — not added here
   unilaterally.

---

## Correlations

- Every domain writes here; none of them owns it
- Log retention and structured logging → `13-operations/observability.md`
- What must be audited, and what must never be copied into it → `00-governance/security-policy.md`
- `AuditEntry` and `ErrorEntry` entities → [`../../02-domain/entities-and-rules.md`](../../02-domain/entities-and-rules.md)
- Why these are not bounded contexts → [`../../02-domain/domain-map.md`](../../02-domain/domain-map.md) § 2.9
- GAP-08 (no explicit SRS requirement) → `04-requirements/traceability-matrix.md` § 6
