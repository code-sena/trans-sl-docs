# Migration Strategy

> How the schema changes without breaking a running system, in what order the migrations run, and what
> to do about the two changes that cannot be made in a single release.

**Version:** v0.2 · **Last updated:** 2026-09-10
**Tool:** node-pg-migrate — plain SQL up/down, no ORM required, matches the Node/Express stack

---

## Naming and order

```
V{nnn}__{snake_case_description}.sql       schema changes
S{nnn}__{snake_case_description}.sql       seed data

V001__create_enums.sql
V002__create_identity_schema.sql          ← includes password_policies (v9)
V003__create_authz_schema.sql
V004__create_profile_schema.sql
V005__create_lexicon_schema.sql
V006__create_translation_ai_schema.sql
V007__create_notification_schema.sql
V008__create_usage_schema.sql
V009__create_audit_schema.sql
V010__constraints_and_triggers.sql          ← constraints.md, in full
S001__seed_roles_permissions.sql
S002__seed_notification_types.sql
S003__seed_alphabet_lsc.sql                 ← the 27 LETTER signs, INV-013
S004__seed_password_policy.sql              ← identity.password_policies
```

> **The order is not cosmetic.** Enums first — a table cannot reference a type that does not exist.
> Identity before everything else — almost every foreign key in the model points at `users`. Constraints
> last — `ck_push_requires_device` cannot be added before `notifications` exists. Seeds after the
> constraints, so a bad seed fails loudly instead of installing invalid data.

**The Gamification schema is not in this list**, and does not get a `V` number until RF8 is approved
(GAP-01). When it is, it becomes `V011`, after everything else, because nothing depends on it.

---

## Rules

```
✓ Forward-only. A mistake is corrected by a new migration, never by editing an old one
✓ One logical change per migration
✓ Every migration runs inside a transaction — except ALTER TYPE … ADD VALUE and
  CREATE INDEX CONCURRENTLY, which cannot, and therefore go in their own file
✓ Seeds are separate files with the S prefix, and are idempotent (ON CONFLICT DO NOTHING)
✓ Both stores share one history: MongoDB changes live in migrations/mongo/ with the same numbering
✗ Never modify a migration that has run in any environment — not even to fix a typo in a comment
✗ Never DROP a column or table in the same release that stops using it
```

**Why "never edit a migration that has run".** The tool records a checksum. Editing the file makes every
environment that already ran it disagree with every environment that has not, and the disagreement
surfaces weeks later as a schema that is *almost* right. A typo in a comment is not worth that.

---

## Compatible changes — safe while the previous version of the code is still running

```sql
ALTER TABLE lexicon.sign_lexicon ADD COLUMN notes TEXT;                       -- nullable: always safe
ALTER TABLE ai.ai_models ADD COLUMN confidence_threshold DECIMAL(5,4);        -- nullable: safe
ALTER TABLE translation.translations
  ADD COLUMN retry_count INTEGER NOT NULL DEFAULT 0;                          -- NOT NULL + DEFAULT: safe
CREATE INDEX CONCURRENTLY idx_lexicon_code ON lexicon.sign_lexicon (code);    -- no write lock
ALTER TYPE usage_section ADD VALUE 'TUTORIAL';                                -- own file, no transaction
```

**`CREATE INDEX CONCURRENTLY` in production, plain `CREATE INDEX` locally.** The plain form takes a write
lock on the table for as long as the build takes; concurrently is slower and cannot run in a transaction,
which is why it lives in its own migration file.

---

## Incompatible changes — two releases, never one

### Renaming a column

```sql
-- Release N   — add, backfill, and have the code write both
ALTER TABLE translation.translations ADD COLUMN delivered_text TEXT;
UPDATE translation.translations SET delivered_text = recognized_text;

-- Release N+1 — the code no longer reads the old column
ALTER TABLE translation.translations DROP COLUMN recognized_text;
```

### Making `translations.model_id` NOT NULL — GAP-06, worked through

This is the concrete one the project has pending. It is **three steps across two releases**, not an
`ALTER`:

```sql
-- V0xx (release N): backfill with the model that was active when each row was created
UPDATE translation.translations t
   SET model_id = (SELECT model_id FROM ai.ai_models
                    WHERE trained_at <= t.created_at
                    ORDER BY trained_at DESC LIMIT 1)
 WHERE model_id IS NULL;

-- release N: the application stops writing NULL — whichever side runs inference knows its version

-- V0yy (release N+1): now the constraint can hold
ALTER TABLE translation.translations ALTER COLUMN model_id SET NOT NULL;
```

> If the backfill leaves rows with no candidate model — translations older than every recorded model —
> the decision is explicit: insert a `0.0.0` "unknown, pre-registry" row in `ai_models` and point them at
> it, or keep the column nullable and document exactly what `NULL` means. **Silently leaving them is the
> one option that is not available**, because it is what makes FR-408 untrue.

---

## Rollback policy

Every `V` migration ships with a `down` that is **tested in staging**, not written and assumed. An
untested `down` is worse than none, because it will be trusted during an incident.

Where a `down` would lose data — dropping a column that has been written to — **the `down` is
deliberately absent and the migration file says so at the top.** Recovery in that case is the backup, not
the rollback. Writing a `down` that silently discards production data is how a rollback becomes the
incident.

| Change | `down` | Note |
|--------|--------|------|
| `CREATE TABLE` | `DROP TABLE` | Safe before the table has data; after, treat as destructive |
| `ADD COLUMN` (nullable) | `DROP COLUMN` | Destructive once written to — no `down` after release N+1 |
| `CREATE INDEX` | `DROP INDEX` | Always safe |
| `ADD CONSTRAINT` | `DROP CONSTRAINT` | Always safe |
| `ALTER TYPE … ADD VALUE` | **none possible** | PostgreSQL cannot remove an enum value. Recreating the type is a data migration, not a rollback |
| Backfill `UPDATE` | **none** | The previous values are gone. This is why the backfill is its own migration, so the schema change can roll back without it |

---

## The MongoDB collection migrates differently

`gesture_samples` has no schema to alter. A change is a **validator update plus a backfill script**,
versioned in the same `migrations/` folder under `mongo/` so both stores share one history.

```
migrations/mongo/M001__create_gesture_samples_validator.js
migrations/mongo/M002__add_extractor_version_field.js
```

**A document store with no migration history is a document store where nobody knows what shape last
year's data has.** The validator is the schema; treating it as untracked configuration is how a
collection ends up holding four generations of document shape with no record of which is which.

Adding an optional field is safe and needs no backfill. Making a field `required` needs the backfill
first, exactly like `NOT NULL` — same two-release shape, different syntax.

---

## Environments

| Environment | How migrations run | Seeds |
|-------------|--------------------|-------|
| Local | `npm run migrate up` against the Docker Postgres | All `S` files, plus fixtures |
| CI | On a fresh database, every run, from V001 — **this is the test that the order is right** | All `S` files |
| Staging | Automatically on deploy, before the app starts | `S` files only |
| Production | Automatically on deploy, before the app starts, with a backup taken first | `S` files only, idempotent |

**Running every migration from V001 on a clean database in CI is the only reliable check that the
sequence still works.** A migration set that only ever runs incrementally hides its own broken order
until the day somebody sets up a new environment.

---

## Correlations

- What `V010` contains → [`constraints.md`](constraints.md)
- The schemas being created → [`domains/`](domains/)
- Local Docker Postgres and Mongo → `10-devops/local-setup.md`
- Environments and deploy pipeline → `10-devops/environments.md`
- Backup and recovery → `13-operations/incident-management.md`
