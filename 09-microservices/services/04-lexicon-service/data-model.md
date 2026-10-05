# Data Model — Lexicon Service

> `lexicon-service` is the **authoritative owner** of the data described here. No other service reads these tables; they use the
> HTTP API (through the gateway) or the events. Other services keep only the sign `code` or `sign_id` as a logical reference.

**Source of truth today:** `backend/migrations/003_lexicon.sql` (idempotent) and the Liquibase changelogs `009`, `010`, `011` in `backend/DB/traduce_senas/changelogs/`.
**Target model:** `06-data/domains/04-lexicon.md`.

---

## Database engine

**Engine:** PostgreSQL (target database `lexicon`; today database `traduce_senas`, schema `public`) plus static media files.
**Justification:** the catalog is relational and small: signs, their texts per language and their media have fixed cardinalities, and the rules (unique code, one letter per language, ordered media) are best enforced with unique indexes and foreign keys inside the same database. See ADR-003 for the general database decision.

Data model and ER: `06-data/domains/04-lexicon.md`.

---

## Schema

### Table: `categories`

**Purpose:** thematic grouping of signs (`Alfabeto`, `General`, and any the administrator creates).

| Field | Type | Nullable | Description | Constraints |
|-------|------|----------|-------------|-------------|
| category_id | SERIAL | No | Identifier | PK |
| name | VARCHAR(100) | No | Category name | `uq_categories_name` UNIQUE |
| description | VARCHAR(255) | Yes | Short description | |
| created_at | TIMESTAMPTZ | No | Creation date | Default `NOW()` |

Seeded rows: `Alfabeto` and `General`.

### Table: `sign_lexicon`

**Purpose:** the sign itself, with only what does not depend on the interface language.

| Field | Type | Nullable | Description | Constraints |
|-------|------|----------|-------------|-------------|
| lexicon_id | SERIAL | No | Identifier | PK |
| code | VARCHAR(50) | No | Stable identifier and recognizer class, for example `LETTER_A`. Pattern `^[A-Z0-9_]{1,50}$` | `uq_sign_lexicon_code` UNIQUE |
| type | VARCHAR(50) | No | `LETTER`, `WORD` or `PHRASE`. Default `WORD` | `ck_sign_lexicon_type` |
| letter | CHAR(1) | Yes | The letter (A-Z or Ñ); only for `LETTER` | `ck_sign_lexicon_letter_iff_type` |
| language | VARCHAR(10) | No | Sign language of the content, default `LSC` | `uq_sign_lexicon_letter` on `(language, letter)` |
| category_id | INT | No | Category | FK to `categories`, `ON DELETE RESTRICT` |
| is_animated | BOOLEAN | No | The 3D model contains an animation (G, H, J, Ñ, S, Z). Default `FALSE` | |
| display_order | INT | No | Order in listings and in the alphabet. Default `1000` | |
| status | VARCHAR(10) | No | `DRAFT`, `ACTIVE` or `INACTIVE`. Default `ACTIVE` | `ck_sign_lexicon_status` |
| created_by | INT | Yes | User who created it | Today FK to `users`, `ON DELETE SET NULL`. **Target: logical user ID, no FK** |
| updated_by | INT | Yes | User who last edited it | Same as `created_by` |
| created_at | TIMESTAMPTZ | No | Creation date | Default `NOW()` |
| updated_at | TIMESTAMPTZ | No | Last modification | Trigger `trg_sign_lexicon_updated_at` |

**Relationships:**
- `category_id` → `categories.category_id` (same service)
- `created_by`, `updated_by` → `sub` of the JWT, the user ID issued by `iam-service` (logical, no FK)

### Table: `sign_localizations`

**Purpose:** the written form of a sign in one interface language.

| Field | Type | Nullable | Description | Constraints |
|-------|------|----------|-------------|-------------|
| sign_localization_id | SERIAL | No | Identifier | PK |
| lexicon_id | INT | No | Sign | FK to `sign_lexicon`, `ON DELETE CASCADE` |
| ui_language | VARCHAR(2) | No | `ES` or `EN` | `ck_sign_localizations_lang`; `uq_sign_localizations_lang` UNIQUE `(lexicon_id, ui_language)` |
| name | VARCHAR(150) | No | Name shown to the user | |
| meaning | VARCHAR(255) | Yes | Meaning | |
| description | TEXT | Yes | Description of the hand configuration (also for screen readers) | |
| created_at | TIMESTAMPTZ | No | Creation date | Default `NOW()` |
| updated_at | TIMESTAMPTZ | No | Last modification | Trigger `trg_sign_localizations_updated_at` |

### Table: `multimedia_resource`

**Purpose:** images, 3D models, videos and GIFs that show a sign.

| Field | Type | Nullable | Description | Constraints |
|-------|------|----------|-------------|-------------|
| resource_id | SERIAL | No | Identifier | PK |
| lexicon_id | INT | Yes | Sign (nullable only for legacy orphan rows) | FK to `sign_lexicon`, `ON DELETE CASCADE` |
| type | VARCHAR(50) | Yes | `MODEL_3D`, `IMAGE`, `VIDEO` or `GIF` | `ck_multimedia_resource_type` |
| url | VARCHAR(255) | Yes | Relative media path (`alfabeto/glb/A.glb`) or an `https` URL of the configured origin | |
| mime_type | VARCHAR(100) | Yes | For example `model/gltf-binary`, `image/png` | |
| display_order | INT | No | Position among the sign's resources, `>= 1` | `ck_multimedia_resource_order`; `uq_multimedia_resource_position` UNIQUE `(lexicon_id, display_order)` |
| description | TEXT | Yes | What the resource shows (for screen readers) | |
| created_at | TIMESTAMPTZ | No | Creation date | Default `NOW()` |

### Indexes

| Name | Fields | Type | Justification |
|------|--------|------|---------------|
| uq_sign_lexicon_code | `code` | UNIQUE BTREE | Lookup by code; the code is the recognizer class |
| uq_sign_lexicon_letter | `(language, letter)` | UNIQUE BTREE | One row per letter and sign language; NULL letters do not collide |
| idx_sign_lexicon_type | `(language, type, status)` | BTREE | Listings filtered by type and status |
| idx_sign_lexicon_category | `category_id` | BTREE | Category counts and filters |
| idx_sign_localizations_name | `(ui_language, name)` | BTREE | Catalog search by name |
| uq_multimedia_resource_position | `(lexicon_id, display_order)` | UNIQUE BTREE | Unambiguous media order |

### Static media

Files under `public/lexicon/alfabeto/{glb,thumbs}` (or `LEXICON_MEDIA_DIR`, or a CDN). The database stores the path or URL only.
Served at `/api/lexicon/media/*`, cached 7 days.

---

## Modeling decisions

- **The alphabet is a subset of `sign_lexicon`.** The 27 letters are rows with `type = 'LETTER'`, seeded with codes `LETTER_A` ... `LETTER_Z` (`LETTER_NN` for Ñ), `display_order` 1 to 27 and the category `Alfabeto`.
- **Texts live in `sign_localizations`, not in `sign_lexicon`.** The first version had `word`, `description` and `category` columns; migration 003 copies them into localizations (ES) and `categories` and then drops them.
- **Media store paths, not binaries.**
- **Retire, never delete.** A sign leaves the public catalog by `status = 'INACTIVE'`; there is no delete endpoint for signs. This is what lets `recognition-service` keep sign IDs in its history without a foreign key.

### Differences with the target model (`06-data/domains/04-lexicon.md`)

| Aspect | Implemented | Target |
|--------|-------------|--------|
| Primary keys | `SERIAL` integers | `UUID` |
| Schema | `public` | `lexicon` |
| Enumerations | `VARCHAR` with `CHECK` | PostgreSQL enum types |
| Names | `type`, `language`, `multimedia_resource`, `display_order` | `sign_type`, `sign_language`, `multimedia_resources`, `position` |
| Animation flag | `is_animated` | Not modeled |
| `translations` link | `translations` stores free text, not a sign reference | `translation_signs.sign_id` in recognition-service, logical ID, no FK (the FK of `06-data` is dropped by the database-per-service rule) |
| `created_by`, `updated_by` | FK to `users` | Logical user ID, no FK |

### Coupling to remove in the extraction

| Coupling today | In the service |
|----------------|----------------|
| `003_lexicon.sql` creates `role`, `user_role` and the `ADMIN` role | Removed; roles belong to iam-service |
| `postgresRoleChecker` reads `user_role` | Replaced by a role checker that reads the `roles` claim of the token |
| FK `created_by`/`updated_by` → `users` | Dropped; keep the integer / UUID value |

---

## Schema migration

**Tool:** today plain SQL run with `psql` (`backend/migrations/`); the Liquibase changelogs in `backend/DB/traduce_senas/changelogs/` created the legacy tables first. Target: Liquibase changelog of the service.
**Script location:** `backend/migrations/003_lexicon.sql` today.
**Naming convention:** `NNN_description.sql`, numbered in order.

**Rollback policy:**
- The script has no down migration. It is wrapped in one transaction (`BEGIN` ... `COMMIT`), so a failure leaves the database unchanged.
- It is safe to re-run: tables use `IF NOT EXISTS`, the seed uses `ON CONFLICT DO NOTHING` and never overwrites what an administrator edited.
- It copies data from the old columns before dropping them. Take a database backup before applying it to a database that already holds lexicon data.
