# Profile Service

> Everything the user configures or receives that is not their identity: interface preferences (theme, language), the
> in-app and email notifications, the achievements (provisional) and the daily challenges.

**Status:** extracted. The code lives in `services/profile-service` (own process, own Dockerfile, port 3005, PostgreSQL database `profile`).
Push and devices were dropped ([ADR-007](../../../05-architecture/decisions/records/ADR-007-email-notifications.md)): notifications reach the user in the app or by email.
Reference model: `02-domain/domain-map.md` and `06-data/domains/03-profile.md`, `07-notification.md`, `09-gamification.md`.
The `users` routes (`GET /api/users/me`) belong to `iam-service`, not to this service. See `09-microservices/service-catalog.md`.

---

## Responsibility

Owns `user_profiles`, `user_preferences`, `notification_types`, `notifications`, `achievements`, `user_achievements`, the daily
challenge tables and the administrator-report tables. Creates the profile when a user registers and reacts to events to advance
achievements and challenges and to create notifications.

---

## Location in the architecture

| Field | Value |
|-------|-------|
| Number in catalog | 06 |
| Local port | 3005 (internal; not published by Docker Compose) |
| Bounded contexts | Profile & Preferences; Notifications; Gamification (provisional, RF8 pending) |
| DB engine | PostgreSQL `profile`, schema `public` |
| Data owned | See [data-model.md](./data-model.md) |
| Gateway paths | `/api/profile/**`, `/api/notifications/**`, `/api/achievements/**` |
| Communicates with | RabbitMQ (consumes and publishes). Internal HTTP to recognition and analytics (statistics for the administrator reports) and to iam (list of administrators). Mail (EMAIL channel and the reports) |
| Consumed by | The app (through the gateway) |
| Events | Publishes `profile.PreferencesChanged` and `profile.AchievementUnlocked`; consumes `iam.UserRegistered`, `iam.UserDeleted` and `recognition.TranslationProduced`. See [events.md](./events.md) |
| Health | `GET /health` |

---

## Responsibilities (what this service DOES)

- Create the profile and the default preferences when `iam.UserRegistered` arrives (theme `LIGHT`, language `ES`, notifications on). A preferences update creates the profile if it is missing
- Read and update preferences: `uiLanguage` (`ES`, `EN`, `FR`, `PT`), `theme` (`LIGHT`, `DARK`) and the master switch `notificationsEnabled`. Sending `notificationsEnabled` needs the permission `notifications.manage`
- Create notifications on the channels `IN_APP` (the bell of the app) and `EMAIL` (sent by a worker from the `PENDING` rows). Checks `notifications_enabled` before creating one
- Advance the achievements with each translation and with the functional activity of the client (`POST /api/achievements/activity`), and emit `profile.AchievementUnlocked` once per unlock
- Assign one daily challenge per user and day (Bogota time), advance it with each saved translation and grant its points once ([ADR-009](../../../05-architecture/decisions/records/ADR-009-daily-challenges.md)). Challenge-point medals ([ADR-010](../../../05-architecture/decisions/records/ADR-010-challenge-points-medals.md))
- Send the weekly and monthly administrator reports, and a model reminder, by email to the administrators with notifications on (`ADMIN_REPORTS_*`; migration `008_admin_reports.sql`). The reports read the statistics of recognition and analytics over internal HTTP
- On `iam.UserDeleted`, erase the profile, preferences, notifications and achievement progress, and remember the user in `erased_users`. Later writes of that account answer `410 ACCOUNT_DELETED`

## Out of scope (what it does NOT do)

- **Name, email, password:** `iam-service`. The profile screen calls iam for them
- **Per-user, per-type notification preferences:** do not exist on purpose (no requirement)
- **Usage statistics:** `analytics-service`
- **Recognition:** `recognition-service`
- **Push notifications and devices:** dropped (ADR-007)

---

## Routes (implemented)

Every route needs a valid JWT. Each user only sees their own data; the user id comes from the token. The full contract with the errors is in `07-api/contracts/openapi/profile-service.yaml`.

| Area | Method and path | Notes |
|------|-----------------|-------|
| Profile | `GET /api/profile/me`, `PATCH /api/profile/me` | `PATCH` returns the whole profile |
| Preferences | `GET /api/profile/preferences`, `PATCH /api/profile/preferences` | |
| Challenges | `GET /api/profile/challenges/today`, `GET /api/profile/challenges/rewards/summary` | Administrators (`users.manage`) get `403` |
| Notifications | `GET /api/notifications`, `PATCH /api/notifications/:id/read` | Paginated list with `unreadCount` |
| Achievements | `GET /api/achievements`, `POST /api/achievements/activity` | Achievements take `catalogVersion` and `challengeRewards`. Administrators get `403` |

The user is always the user id of the token; no path carries a `userId` for own data.

### Target (not in the code)

Devices, notification types administration, creating notifications or achievements from the API, and `PATCH /api/achievements/:id`. They are listed in `07-api/README.md` ("Planned, not implemented").

---

## How to run it locally

```bash
# With Docker Compose (starts postgres-profile, recognition, analytics and iam as needed)
docker compose up -d profile-service

# Locally, only this service (port 3005)
npm run dev -w @traduce/profile-service
curl http://localhost:3005/health
```

### Environment variables

| Variable | Purpose |
|----------|---------|
| `PORT` | HTTP port (`3005`) |
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` | PostgreSQL connection (`DB_NAME=profile`; in Compose the host is `postgres-profile`) |
| `JWT_SECRET` | Verification secret of the JWT (HS256) |
| `RABBITMQ_URL` | Broker URL. Empty means the in-memory bus |
| `IAM_URL`, `RECOGNITION_URL`, `ANALYTICS_URL` | Internal URLs for the administrator directory and the statistics |
| `ADMIN_REPORTS_ENABLED` | `true` (default) or `false`. Turns the administrator reports on or off |
| `ADMIN_REPORTS_TICK_MS` | How often the reports are checked, in milliseconds (default `900000`, 15 minutes) |
| `EMAIL_USER`, `EMAIL_PASS` | Mail account for the `EMAIL` channel and the reports (the same account as iam) |
| `APP_URL` | Address of the app that the button of the emails opens (default `https://traducesenas.tech`) |

---

## Related documents

- [data-model.md](./data-model.md) — Tables
- [events.md](./events.md) — Events published and consumed
- [decisions.md](./decisions.md) — Design decisions
- [runbook.md](./runbook.md) — Operation
- Target data model → `06-data/domains/03-profile.md`, `07-notification.md`, `09-gamification.md`
- API contract → `07-api/contracts/openapi/profile-service.yaml`
