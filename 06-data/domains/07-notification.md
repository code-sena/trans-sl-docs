# Notification — Data Model

> **Domain 7 of 10** · Bounded Context: **Notifications** (Supporting) · PostgreSQL schema: `notification`
> **Tables:** `notification_types`, `user_devices`, `notifications`
> **Requirements:** RF4 · ERF4.1 · accessibility ERF (cross-cutting) · FR-501 … FR-509

**Owned by:** profile-service (PostgreSQL db `profile`)
**Version:** v0.2 · **Last updated:** 2026-09-10 · **Source:** `traduce_senas.dbml` (v9)
**Conventions:** [`../modeling-conventions.md`](../modeling-conventions.md) · **Constraints:** [`../constraints.md`](../constraints.md) · **Open items:** [`../open-items.md`](../open-items.md)

---

## What this domain owns

The catalog of alert types that exist, the devices that can receive a push, and every alert with its
delivery state.

> **Since 2026-10-24 ([ADR-007](../../05-architecture/decisions/records/ADR-007-email-notifications.md)) push is
> not used.** Alerts outside the app go by `EMAIL`, sent by a profile-service worker from the `PENDING`
> rows whose `scheduled_at` has passed; `IN_APP` is the bell. `user_devices` and the `PUSH` value are kept
> below as the original design and are not created in production.

> **The most important rule in this domain is not in a table — it is in an enum.**
> `notification_channel` admits `PUSH`, `EMAIL` and `IN_APP`. **No value is audio-only, and none can be
> added.** The users of this application are deaf and hard-of-hearing people: an alert they cannot
> perceive is not a degraded alert, it is information the system failed to deliver. Encoding that as a
> type constraint rather than a guideline is what makes it impossible to violate by accident (INV-023).

---

## `notification_types`

**Purpose:** the catalog of alert kinds — few, each with a clear meaning, not an open-ended list.

```sql
CREATE TABLE notification.notification_types (
  notification_type_id UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  code                 VARCHAR(50)  NOT NULL UNIQUE,              -- ACHIEVEMENT_UNLOCKED, ACCOUNT_SECURITY…
  name                 VARCHAR(100) NOT NULL,
  description          VARCHAR(255),
  is_active            BOOLEAN      NOT NULL DEFAULT TRUE,        -- administrator control, system-wide
  created_at           TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

`is_active` is an **administrator** control: it activates or withdraws a type for every user at once.
There is no per-user, per-type preference in this model, deliberately — see the control table below.

Seeded in `S002__seed_notification_types.sql`. Codes are stable identifiers, like
`sign_lexicon.code`: renaming one orphans every notification that referenced it by meaning.

---

## `user_devices`

**Purpose:** a phone registered to receive push notifications.

```sql
CREATE TABLE notification.user_devices (
  device_id     UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID            NOT NULL REFERENCES identity.users (user_id) ON DELETE CASCADE,
  push_token    VARCHAR(255)    NOT NULL UNIQUE,
  platform      device_platform NOT NULL,
  is_active     BOOLEAN         NOT NULL DEFAULT TRUE,
  registered_at TIMESTAMPTZ     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  revoked_at    TIMESTAMPTZ
);

CREATE INDEX idx_devices_user_active ON notification.user_devices (user_id, is_active);
```

**`push_token` is a credential.** Anyone holding it can send that device a notification. It is not
hashed because the provider requires the value in clear to deliver — which makes it a secret the
database stores in clear, and column-level encryption or restricted access is the mitigation.

⚠️ **`push_token` is globally `UNIQUE`, and FCM/APNs reassign tokens** between reinstalls and device
handovers. Registration must be an **upsert on `push_token`** that re-points the row at the current user
and revokes the previous binding — a plain insert makes the second user to receive a recycled token
unable to register, which is a real and reproducible failure (DATA-05).

**Devices are revoked, never deleted** — `is_active = FALSE` plus `revoked_at`. This is not a style
preference; see the caution under `notifications` below.

---

## `notifications`

```sql
CREATE TABLE notification.notifications (
  notification_id      UUID                 PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              UUID                 NOT NULL REFERENCES identity.users (user_id) ON DELETE CASCADE,
  notification_type_id UUID                 NOT NULL REFERENCES notification.notification_types (notification_type_id) ON DELETE RESTRICT,
  device_id            UUID                 REFERENCES notification.user_devices (device_id) ON DELETE SET NULL,
  channel              notification_channel NOT NULL DEFAULT 'PUSH',
  title                VARCHAR(150)         NOT NULL,
  body                 TEXT                 NOT NULL,
  reference_type       reference_entity,                          -- what caused the alert — no FK
  reference_id         UUID,
  status               notification_status  NOT NULL DEFAULT 'PENDING',
  scheduled_at         TIMESTAMPTZ,                               -- RF4 — scheduled notifications
  sent_at              TIMESTAMPTZ,
  read_at              TIMESTAMPTZ,
  created_at           TIMESTAMPTZ          NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_notifications_user_created ON notification.notifications (user_id, created_at);
CREATE INDEX idx_notifications_pending      ON notification.notifications (status, scheduled_at);
CREATE INDEX idx_notifications_type         ON notification.notifications (notification_type_id);
CREATE INDEX idx_notifications_reference    ON notification.notifications (reference_type, reference_id);
```

**Data dictionary:**

| Column | Meaning | Notes |
|--------|---------|-------|
| `channel` | How the alert reaches the user | `PUSH` · `IN_APP` · `EMAIL`. All visual. In use: `IN_APP` (the bell, default) and `EMAIL` (ADR-007) |
| `device_id` | Target device | Required if and only if `channel = 'PUSH'` (INV-024) |
| `reference_type` / `reference_id` | The record in another domain that caused the alert | **No foreign key.** See below |
| `status` | Delivery state | `PENDING` → `SENT` → `READ`, or `FAILED`, or `CANCELLED` |
| `scheduled_at` | When a pending notification must go out (RF4) | `idx_notifications_pending (status, scheduled_at)` is the delivery worker's query |

**Lifecycle:**

```
[PENDING] ──(delivered)──▶ [SENT] ──(user opens it)──▶ [READ]
     │
     ├──(provider rejects it)──▶ [FAILED]
     └──(type withdrawn / user opts out)──▶ [CANCELLED]
```

`FAILED` exists so that "not sent yet" and "tried and could not" are distinguishable. A queue where the
second silently looks like the first is a queue that retries forever, or never.

---

## The polymorphic reference — the best-designed thing in this model

`reference_type` + `reference_id` name the record that caused the alert — an achievement, a translation
— **with no foreign key**. That means Notifications does not depend on Gamification at all: if RF8 is
rejected and both Gamification tables are dropped, Notifications does not break.

The price is that the database cannot check the reference and the application must. The price is worth
paying, because it is what makes a provisional context genuinely removable.
`idx_notifications_reference` is what turns "every notification about this record" into a query rather
than a scan — the same pattern `audit_logs` uses for `(entity_type, entity_id)`.

---

## Two control levels, not three

| Level | Column | Operated by |
|-------|--------|-------------|
| A type, on or off, for everyone | `notification_types.is_active` | Administrator |
| All my notifications | `user_preferences.notifications_enabled` | The user (RF4) |
| ~~A type, on or off, for me~~ | — | **Does not exist, on purpose** |

RF4 says the user can turn notifications on or off — one switch. Per-type granularity is an
administrator control. A per-user, per-type matrix would be a table with no requirement behind it.

---

## Modeling decisions and cautions

1. ⚠️ **`device_id ON DELETE SET NULL` collides with INV-024.** The invariant requires
   `(channel = 'PUSH') = (device_id IS NOT NULL)`. Deleting a device would null the `device_id` of its
   past `PUSH` notifications and violate that `CHECK`. The resolution is that devices are **revoked,
   never deleted** — which the table is already designed for. Worth writing down because the schema
   currently permits the deletion that breaks it; `ON DELETE RESTRICT` would make it enforced rather
   than agreed (DATA-04).
2. **`notification_type_id` is `RESTRICT`.** Withdrawing a type is `is_active = FALSE`, not a delete.
   Deleting it would orphan every notification that explained itself through it.
3. **`user_id` is `CASCADE`.** A notification is personal data with no meaning after the account is
   gone — unlike a usage event, which is a statistical fact and survives.
4. **`title` and `body` are stored, not templated at delivery.** What the user was told must be
   reconstructible later, even if the template changes.

---

## Invariants this domain enforces

| Invariant | Where it is enforced |
|-----------|----------------------|
| INV-023 ⭐ — no alert depends on sound | The `notification_channel` enum has no audio-only value |
| INV-024 — a push has a device | `ck_push_requires_device` |
| INV-025 — a disabled switch suppresses every delivery | Checked against `user_preferences.notifications_enabled` **before creating** the notification |

---

## Open items affecting this domain

| ID | Summary |
|----|---------|
| **DATA-04** | `device_id ON DELETE SET NULL` would violate INV-024. Make devices non-deletable, or change the action to `RESTRICT` |
| **DATA-05** | `push_token` is globally unique but providers recycle tokens. Register with an upsert |
| **DATA-11** | `ck_push_requires_device` does not exist yet — the constraints migration is unwritten |
| **GAP-07** | `reference_entity` declares `CATEGORY`, `AI_MODEL` and `USER`, which no requirement produces. Document them as reserved or trim them |

---

## Correlations

- The switch that suppresses everything → [`03-profile.md`](03-profile.md)
- The provisional source of `ACHIEVEMENT` references → [`09-gamification.md`](09-gamification.md)
- `NOTIFICATION_OPENED` events → [`08-usage.md`](08-usage.md)
- Why Notifications came back as a bounded context → [`../../02-domain/domain-map.md`](../../02-domain/domain-map.md) § 5
- `Notification`, `NotificationType`, `UserDevice` entities → [`../../02-domain/entities-and-rules.md`](../../02-domain/entities-and-rules.md)
- Accessibility requirement NFR-001 → `04-requirements/non-functional.md`
