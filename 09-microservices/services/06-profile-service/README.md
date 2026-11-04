# Profile Service

> Everything the user configures or receives that is not their identity: interface preferences (theme, language), the
> notifications (devices, alerts, delivery) and, provisionally, the achievements.

**Status:** implemented in `backend/services/profile-service` (preferences, in-app and email notifications, achievements, daily
challenges). Parts of this document below were written as a target before the code existed; the real endpoints are in
`07-api/contracts/openapi/profile-service.yaml`. Push and devices were dropped ([ADR-007](../../../05-architecture/decisions/records/ADR-007-email-notifications.md)).
Reference model: `02-domain/domain-map.md` and `06-data/domains/03-profile.md`, `07-notification.md`, `09-gamification.md`.
The `users` module of the backend (`GET /api/users/me`) belongs to `iam-service`, not to this service.
See `09-microservices/service-catalog.md`.

---

## Responsibility

Owns `user_preferences`, `notification_types`, `user_devices`, `notifications` and (provisional) `achievements` and
`user_achievements`. Creates the profile when a user registers and reacts to events to create notifications and advance achievements.

---

## Location in the architecture

| Field | Value |
|-------|-------|
| Number in catalog | 06 |
| Local port | 3005 |
| Bounded contexts | Profile & Preferences; Notifications; Gamification (provisional, RF8 pending) |
| DB engine | PostgreSQL, database `profile` |
| Data owned | `06-data/domains/03-profile`, `07-notification`, `09-gamification` |
| Gateway paths | `/api/profile/**`, `/api/notifications/**`, `/api/achievements/**` |
| Communicates with | RabbitMQ; push provider (FCM / APNs) and mail provider (outbound) |
| Consumed by | The app (through the gateway) |
| Events | Publishes preference, notification and achievement events; consumes iam and recognition events. See [events.md](./events.md) |
| Health | `GET /health` |

---

## Responsibilities (what this service DOES)

- Create the preferences row when `iam.UserRegistered` arrives (theme `LIGHT`, language `ES`, notifications enabled); reads must not assume the row exists
- Read and update preferences: `ui_language` (`ES` / `EN`), `theme` (`LIGHT` / `DARK`), the master switch `notifications_enabled` (RF4)
- Register and revoke devices for push (`user_devices`); registration is an upsert on `push_token`
- Create, schedule, deliver and mark as read notifications; channels `PUSH`, `IN_APP`, `EMAIL`, **never audio only** (INV-023: the users are deaf and hard of hearing)
- Check `notifications_enabled` **before creating** a notification (INV-025)
- Administrators activate or withdraw a notification type for everyone (`notification_types.is_active`)
- (Provisional, RF8) Keep the catalog of achievements and each user's progress; emit `AchievementUnlocked` exactly once

### Daily challenges and challenge-point medals

- Assigns one challenge per user and day (Bogota time), advances it with each saved translation (`recognition.TranslationProduced`) and grants the reward once. [ADR-009](../../../05-architecture/decisions/records/ADR-009-daily-challenges.md)
- Unlocks medals for 500, 1,000 and 3,000 accumulated challenge points, computed from the persisted rewards. [ADR-010](../../../05-architecture/decisions/records/ADR-010-challenge-points-medals.md)
- Routes: `GET /api/profile/challenges/today`, `GET /api/profile/challenges/rewards/summary`, `POST /api/achievements/activity` (functional activity for achievements). All through the existing gateway prefixes.
- Weekly and monthly administrator reports are sent by email ([ADR-007](../../../05-architecture/decisions/records/ADR-007-email-notifications.md), migration `008_admin_reports.sql`).

## Out of scope (what it does NOT do)

- **Name, email, password:** `iam-service`. The profile screen calls iam for them
- **Per-user, per-type notification preferences:** does not exist on purpose (no requirement)
- **Usage statistics:** `analytics-service`
- **Recognition:** `recognition-service`

---

## API (target; no endpoint exists yet)

The endpoint-level contract is not defined yet. Path groups:

| Path prefix | Content | Auth |
|-------------|---------|------|
| `/api/profile/**` | Preferences of the authenticated user | JWT |
| `/api/notifications/**` | List and mark as read, register / revoke a device, administer notification types (`notifications.manage`) | JWT |
| `/api/achievements/**` | Catalog and the user's progress (provisional) | JWT |

The user is always the `sub` of the token; the path never carries a `userId` for own data.

---

## How to run it locally

```bash
# Target (no image exists yet)
docker compose up -d profile-service
curl http://localhost:3005/health
```

### Environment variables (target)

| Variable | Purpose |
|----------|---------|
| `PORT` | HTTP port (`3005`) |
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` | PostgreSQL (`DB_NAME=profile`) |
| `JWT_VERIFY_KEY` | Verification key of the JWT |
| `RABBITMQ_URL` | Broker URL |
| `PUSH_PROVIDER_CREDENTIALS` | FCM / APNs credentials (secret) |
| `EMAIL_USER`, `EMAIL_PASS` | Mail account for the `EMAIL` channel |

---

## Related documents

- [data-model.md](./data-model.md) — Tables
- [events.md](./events.md) — Events published and consumed
- [decisions.md](./decisions.md) — Design decisions
- [runbook.md](./runbook.md) — Operation
- Data model source → `06-data/domains/03-profile.md`, `07-notification.md`, `09-gamification.md`
