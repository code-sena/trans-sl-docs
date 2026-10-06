# Profile — Data Model

> **Domain 3 of 10** · Bounded Context: **Profile & Preferences** (Supporting) · PostgreSQL schema: `profile`
> **Tables:** `user_preferences`
> **Requirements:** RF5 · ERF5.1, ERF5.2, ERF5.4 · RF4 (the notification switch)

**Owned by:** profile-service (PostgreSQL db `profile`)
**Version:** v0.2 · **Last updated:** 2026-09-10 · **Source:** `traduce_senas.dbml` (v9)
**Conventions:** [`../modeling-conventions.md`](../modeling-conventions.md) · **Open items:** [`../open-items.md`](../open-items.md)

---

## What this domain owns

Interface preferences: theme, language and the master notification switch. **Nothing else.** The
profile *screen* also shows the user's name and lets them change their password, but those columns live
in `identity.users` and that operation belongs to Identity & Access — the profile only invokes it.

The smallest domain in the model, and it earns its own table for a reason given below.

---

## `user_preferences`

```sql
CREATE TABLE profile.user_preferences (
  user_preference_id    UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID         NOT NULL UNIQUE
                                     REFERENCES identity.users (user_id) ON DELETE CASCADE,
  ui_language           ui_language  NOT NULL DEFAULT 'ES',       -- ERF5.4
  theme                 theme_option NOT NULL DEFAULT 'LIGHT',    -- ERF5.2
  notifications_enabled BOOLEAN      NOT NULL DEFAULT TRUE,       -- RF4
  updated_at            TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

**Data dictionary:**

| Column | Meaning | Values |
|--------|---------|--------|
| `ui_language` | Language of the **interface texts**. Not the language of the content — the signs are always LSC | `ES` (i18n `es`) · `EN` (i18n `en`) |
| `theme` | Light or dark interface (ERF5.2) | `LIGHT` · `DARK` |
| `notifications_enabled` | The one notification control the user has (RF4). `FALSE` suppresses every new notification on every channel; the ones already received stay in their history (INV-025) | `TRUE` by default |

---

## Modeling decisions

1. **`user_id` is `UNIQUE` — this is a one-to-one with `users`, not a one-to-many.** It is a separate
   table rather than three more columns on `users` because the access patterns differ: preferences are
   read on every screen load and written whenever the user flips a switch, while `users` is read on
   authentication. Keeping the authentication row narrow is worth one join.
2. **A user with no preferences row is a valid state.** The application falls back to the column
   defaults. Creating the row at registration is cleaner, and is what the flow should do — but the read
   path must not assume it exists, or a missing row becomes a crash on the home screen.
3. **`ui_language` is `ES`/`EN`, not `es-CO`/`en-US`.** The domain model uses IETF tags (ALIGN-08).
   Cosmetic, but the two documents must pick one; the IETF tag is the better choice if regional variants
   are ever expected.
4. **The word "language" means two different things in this project**, and this table holds one of them.
   `ui_language` here is the interface; `sign_language` in [`04-lexicon.md`](04-lexicon.md) is the
   content. They are never named alike, in the schema or in the code — that collision is the textbook
   case the domain map warns about.

---

## The one notification control, and why there is only one

RF4 says the user can turn notifications on or off. **One switch.** That switch is
`notifications_enabled`, and it is the only per-user notification control in the whole model.

| Level | Column | Operated by |
|-------|--------|-------------|
| All my notifications | `user_preferences.notifications_enabled` | The user (RF4) |
| A type, for everyone | `notification_types.is_active` | The administrator |
| ~~A type, for me~~ | — | **Does not exist, on purpose** |

Building a per-user, per-type preference matrix would be building something no requirement asks for —
and a table with no requirement behind it is exactly what the traceability review flags.

---

## Invariants this domain participates in

| Invariant | Note |
|-----------|------|
| INV-025 — a disabled switch suppresses every delivery | Checked **before creating** the notification, not before delivering it. Enforced in [`07-notification.md`](07-notification.md) reading this column |

---

## Open items affecting this domain

| ID | Summary |
|----|---------|
| **DATA-07** | `updated_at` has a `DEFAULT` and no trigger — it never changes after insert |
| **ALIGN-08** | `ui_language` (`ES`/`EN`) vs the domain's `AppLanguage` (`es-CO`/`en-US`). Pick one |

---

## Correlations

- The account these preferences belong to → [`01-identity.md`](01-identity.md)
- The switch's effect on delivery → [`07-notification.md`](07-notification.md)
- `UserProfile` entity → [`../../02-domain/entities-and-rules.md`](../../02-domain/entities-and-rules.md)
- Theme and language on screen → `12-ux-ui/design-system.md`
