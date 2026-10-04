# Lexicon — Data Model

> **Domain 4 of 10** · Bounded Context: **Learning & Lexicon** (Supporting) · PostgreSQL schema: `lexicon`
> **Tables:** `categories`, `sign_lexicon`, `sign_localizations`, `multimedia_resources`
> **Requirements:** RF7 · ERF7.1 · ERF5.4 (localization) · FR-301 … FR-310

**Owned by:** lexicon-service (PostgreSQL db `lexicon` + static media)
**Version:** v0.2 · **Last updated:** 2026-09-10 · **Source:** `traduce_senas.dbml` (v9)
**Conventions:** [`../modeling-conventions.md`](../modeling-conventions.md) · **Constraints:** [`../constraints.md`](../constraints.md) · **Open items:** [`../open-items.md`](../open-items.md)

---

## What this domain owns

The catalog of LSC signs — letters, words and phrases — organized by category, with their visual
resources and their written form in each interface language.

**The alphabet is not a separate structure.** RF7 is served by the rows where `sign_type = 'LETTER'`. A
letter and a word are the same thing to the recognizer: a class it predicts. Modeling them separately
would mean two models for one table, two names for one code, and a decision to make every time somebody
asks whether a fingerspelled word is a letter or a word.

> **This domain publishes a contract to the Core.** `sign_lexicon.code` **is** the class the AI model
> predicts — the same value [`05-translation.md`](05-translation.md) calls `Gloss`. That makes the set
> of published codes a *Published Language* between the catalog and the recognizer: adding a sign
> without training the model, or renaming a code, breaks recognition silently. The user signs correctly
> and nothing happens.

---

## `categories`

```sql
CREATE TABLE lexicon.categories (
  category_id UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  name        VARCHAR(100) NOT NULL UNIQUE,
  description VARCHAR(255)
);
```

Thematic grouping: Greetings, Family, Numbers. Referenced by `sign_lexicon.category_id` with
`ON DELETE RESTRICT` — a category holding signs cannot be deleted (INV-021), because orphaned signs are
signs with no place in the catalog.

---

## `sign_lexicon`

**Purpose:** the sign itself — only what does **not** depend on any written language.

```sql
CREATE TABLE lexicon.sign_lexicon (
  sign_id       UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  code          VARCHAR(50)    NOT NULL UNIQUE,
  sign_type     sign_type      NOT NULL DEFAULT 'WORD',
  letter        VARCHAR(1),                                       -- RF7, only when sign_type = LETTER
  sign_language sign_language  NOT NULL DEFAULT 'LSC',
  category_id   UUID           NOT NULL REFERENCES lexicon.categories (category_id) ON DELETE RESTRICT,
  status        content_status NOT NULL DEFAULT 'ACTIVE',
  created_by    UUID,                                             -- ⚠️ no FK in v8 — see DATA-02
  updated_by    UUID,
  created_at    TIMESTAMPTZ    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMPTZ    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX        idx_lexicon_lang_type ON lexicon.sign_lexicon (sign_language, sign_type);
CREATE UNIQUE INDEX uq_alphabet_letter    ON lexicon.sign_lexicon (sign_language, letter);
CREATE INDEX        idx_lexicon_category  ON lexicon.sign_lexicon (category_id);
CREATE INDEX        idx_lexicon_status    ON lexicon.sign_lexicon (status, sign_language);
```

**Data dictionary:**

| Column | Meaning | Rule it carries |
|--------|---------|-----------------|
| `code` | Stable, language-independent identifier: `GREETING_HELLO`. **It is the class the AI model predicts** | INV-018 — never renamed once published. This is the Published Language between the catalog and the recognizer |
| `sign_type` | `LETTER`, `WORD` or `PHRASE`. The alphabet is the `LETTER` subset | Defaults to `WORD` |
| `letter` | The letter this sign represents. `NULL` unless `sign_type = 'LETTER'` | INV-013 — 27 letters (A–Z plus Ñ) per sign language, none repeated |
| `sign_language` | The **content's** sign language. `LSC` = Lengua de Señas Colombiana, ISO 639-3 `csn` | Not the interface language — that is `ui_language` |
| `status` | `DRAFT` / `ACTIVE` / `INACTIVE`. Only `ACTIVE` reaches end users | INV-019 |
| `created_by` / `updated_by` | Who authored and last edited the entry | ⚠️ No foreign key exists — DATA-02 |

**Why `uq_alphabet_letter` works even though most rows have `letter = NULL`:** PostgreSQL treats NULLs
as distinct in a unique index, so the constraint binds only the rows that actually carry a letter.
Thousands of words and phrases coexist with 27 constrained letters in one index. This is correct *only*
while `letter` is genuinely NULL for non-letters — which is what `ck_lexicon_letter_iff_type` in
[`../constraints.md`](../constraints.md) guarantees.

---

## `sign_localizations`

**Purpose:** the written form of a sign in one interface language.

```sql
CREATE TABLE lexicon.sign_localizations (
  sign_localization_id UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  sign_id              UUID         NOT NULL REFERENCES lexicon.sign_lexicon (sign_id) ON DELETE CASCADE,
  ui_language          ui_language  NOT NULL,
  name                 VARCHAR(150) NOT NULL,                     -- 'Hola' / 'Hello'
  meaning              VARCHAR(255),
  description          TEXT,
  created_at           TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at           TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX uq_sign_localization        ON lexicon.sign_localizations (sign_id, ui_language);
CREATE INDEX        idx_sign_localizations_name ON lexicon.sign_localizations (ui_language, name);
```

**`code` and `name` are different columns in different tables, and that separation is the whole point.**
The recognizer predicts `GREETING_HELLO`; this table decides whether the user reads *Hola* or *Hello*.
Adding English is inserting rows here — it does not touch the AI model.

`description` is the text description of the hand configuration, and it exists for screen readers
(NFR-001). `idx_sign_localizations_name (ui_language, name)` serves catalog search (FR-302); it is a
B-tree, so it covers prefix search (`name LIKE 'Ho%'`). Accent-insensitive or full-text search needs
`pg_trgm` and a GIN index — not required at v1, but this is where it would go.

---

## `multimedia_resources`

**Purpose:** the images, videos and animations that show the sign.

```sql
CREATE TABLE lexicon.multimedia_resources (
  resource_id   UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  sign_id       UUID          NOT NULL REFERENCES lexicon.sign_lexicon (sign_id) ON DELETE CASCADE,
  resource_type resource_type NOT NULL,
  uri           TEXT          NOT NULL,
  mime_type     VARCHAR(100),
  position      INTEGER       NOT NULL DEFAULT 1,
  description   TEXT,
  created_at    TIMESTAMPTZ   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX uq_resource_order ON lexicon.multimedia_resources (sign_id, position);
```

`uri` points at object storage — binary content never goes in the database. `position` is the playback
order when a sign has several resources, unique per sign (INV-020): two resources sharing a position
means the explanation of the sign plays in an order decided by chance.

> **The resource must be understandable without sound, always.** A video that explains a sign through
> narration is useless to the users of this application. `description` exists so a screen reader can
> convey what the video shows.

---

## Modeling decisions

1. **Three tables instead of one wide `signs` table.** The sign, its written forms and its media have
   different cardinalities (1, N per language, N ordered) and different edit rhythms. Flattening them
   would mean either repeated rows or array columns, and both break the unique constraints that make
   INV-013, INV-019 and INV-020 enforceable.
2. **Localizations and resources `CASCADE`; the category `RESTRICT`s.** The first two are *inside* the
   `Sign` aggregate and have no meaning without it. The category is a separate aggregate that the sign
   merely points at.
3. **A sign is never deleted once it has been recognized.** `translation_signs.sign_id` is `RESTRICT`
   (see [`05-translation.md`](05-translation.md)). Retirement is `status = 'INACTIVE'`, which hides the
   sign from the catalog while keeping every history entry that references it intact.

---

## Invariants this domain enforces

| Invariant | Where it is enforced |
|-----------|----------------------|
| INV-013 — the alphabet is complete and unrepeated | `uq_alphabet_letter` + `ck_lexicon_letter_iff_type` + a catalog integrity test at startup |
| INV-018 — the sign code is the recognizer's vocabulary | `code UNIQUE`; publication validates the code against the active model |
| INV-019 — only `ACTIVE` content reaches the end user | `status` + every catalog query filtering on it |
| INV-020 — resource order is unambiguous | `uq_resource_order` + `ck_resource_position` |
| INV-021 — a category with signs is not deletable | `ON DELETE RESTRICT` on `category_id` |

---

## Open items affecting this domain

| ID | Summary |
|----|---------|
| **DATA-02** | `created_by` / `updated_by` are `UUID` columns with no foreign key, but their notes say "NULL if that account was deleted" — behaviour nothing implements |
| **DATA-07** | `updated_at` never changes after insert on either table with the column |
| **GAP-02** | `sign_translations` was a duplicate of `sign_localizations`. **Already removed from the v8 model** — recorded here so the fix is not undone |

---

## Correlations

- The Published Language contract with the recognizer → [`05-translation.md`](05-translation.md) and [`06-ai.md`](06-ai.md)
- `Sign`, `SignLocalization`, `Category`, `MultimediaResource` entities → [`../../02-domain/entities-and-rules.md`](../../02-domain/entities-and-rules.md)
- Why Learning grew into Learning & Lexicon → [`../../02-domain/domain-map.md`](../../02-domain/domain-map.md)
- Samples captured per sign → [`06-ai.md`](06-ai.md)
- Alphabet screen and 3D letter cards → `12-ux-ui/navigation-map.md`
