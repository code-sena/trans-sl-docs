# ADR-007 — Email Instead of Push for Notifications Outside the App

> Based on: Backend `a8a90be` (`feat/profile-admin-notifications`)

- **ID:** ADR-007
- **Date:** 2026-10-24
- **Status:** Accepted
- **Authors:** Mauricio Suaza Solórzano (proposal and implementation); accepted by the development team when the pull requests of this change are merged

---

## Context

The data model (`06-data/domains/07-notification.md`) planned push notifications as the way to reach a user outside the app: a `user_devices` table with FCM/APNs tokens and `PUSH` as the default channel. None of that was built. Production has no `user_devices` table, no Firebase project and no device registration in the APK, and every notification stored so far is `IN_APP`: it is only seen by someone who opens the app and looks at the bell.

That gap became visible with the administrator reports (weekly summary, monthly summary and the model reminder). They are useful precisely because the administrator does not have to open the app to know how it is being used, and an `IN_APP` notice does not achieve that.

**Known constraints:**
- The change had to be ready on 2026-10-24.
- iam-service already sends email through a Gmail account (`EMAIL_USER`, `EMAIL_PASS`) for verification and password reset codes, so the credentials and the operating experience exist.
- Push would need a Firebase project, Expo push tokens in the APK build, a new table, and the token recycling problem already recorded as DATA-05.
- Every channel must be visual (INV-023): the users are deaf and hard of hearing.

---

## Decision

**We decided:** notifications that must reach a user outside the app are sent by **email**. The `PUSH` channel is dropped. `IN_APP` stays as the notice shown in the bell.

How it works in profile-service:

1. The use case that produces a notification creates one row per channel. For the administrator reports these are an `IN_APP` row, already `SENT`, and an `EMAIL` row that starts `PENDING` with `scheduled_at` set to the creation time.
2. A worker runs every minute. It locks up to 20 `EMAIL` rows that are `PENDING` and whose `scheduled_at` has passed (`FOR UPDATE SKIP LOCKED`, so two instances never take the same row), sends them, and stores the result:
   - `SENT`, with `sent_at`, when the SMTP server accepts the message.
   - `FAILED` when the SMTP server rejects it. It is not retried automatically.
   - `CANCELLED` when the profile has no email address or the user turned notifications off (INV-025).
3. The email shows the title and body of the notification and a button that opens the app (`APP_URL`, `https://traducesenas.tech` by default). The button text follows the user's interface language.
4. The bell lists and marks as read only `IN_APP` rows, so the email copy never shows up twice.

Without `EMAIL_USER` and `EMAIL_PASS` the worker does not start and the `EMAIL` rows wait as `PENDING`; they go out as soon as the credentials are configured.

**Justification:** email reaches the administrator without opening the app, it is visual, and it reuses the Gmail account the team already operates. Push would have needed several new pieces outside the backend before a single notice could be delivered, and it would not have been ready the same day. Keeping each email as a notification row means that `scheduled_at` and the delivery states the model already defined (`PENDING`, `SENT`, `FAILED`, `CANCELLED`) are finally used.

---

## Evaluated alternatives

| Alternative | Pros | Cons | Reason for discarding |
|------------|------|------|-----------------------|
| Email through Gmail SMTP, from a queue in `notifications` (chosen) | Reuses existing credentials; states and scheduling stored in the table; testable by changing `scheduled_at` | Gmail daily sending limit; can land in spam | — (chosen) |
| Push through Expo / FCM | Arrives on the phone instantly | Firebase project, tokens in the APK, `user_devices`, token recycling (DATA-05); nothing reaches web users | Too many missing pieces for the deadline |
| Transactional email provider (SendGrid, Resend) | Better deliverability and statistics | New account, DNS verification of the domain, another secret | Not needed for the current volume; the `Mailer` port allows switching later |
| Send the email directly when the report is created | Less code | No state, no retries, no scheduling; an SMTP failure would roll back the report | Loses what the `notifications` table was designed for |

---

## Consequences

**Positive:**
- The administrator receives the reports in the inbox, with a direct link to the app.
- `scheduled_at` makes it possible to schedule a notice (FR-504) and to test delivery by moving that date.
- `FAILED` and `PENDING` can be told apart (FR-505).

**Negative / Trade-offs:**
- A Gmail account can send a few hundred emails a day. That is enough for administrator reports, but not for mass notifications to every user.
- The worker keeps the transaction open while it sends the batch. If the process stops after the SMTP server accepted an email and before the commit, that email is sent again.
- `FAILED` emails stay failed until someone puts them back to `PENDING`.
- On a phone the button opens the web app in the browser, not the APK.

**Impact on the system:**
- Affected services: profile-service (worker, `Mailer` port, Nodemailer adapter, migration `007_admin_reports.sql`) and `docker-compose.yml` (`EMAIL_USER`, `EMAIL_PASS` and `APP_URL` for profile-service).
- Achievement notifications stay `IN_APP` only; sending them by email is a separate decision.
- Documents that must be updated: `06-data/domains/07-notification.md` (channel and devices). FR-503 and FR-509 (device registration and push device) no longer apply while this ADR is in force.

---

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Gmail blocks the account or rejects the credentials | Medium | High | The service checks the SMTP connection at startup and logs the result; emails stay `PENDING` or `FAILED` and can be sent again |
| Emails land in spam | Medium | Medium | Ask administrators to mark the sender as trusted; move to a provider with a verified domain if it persists |
| Duplicate email after a crash in the middle of a batch | Low | Low | Batches of 20; a duplicate summary is harmless |

---

## References

- `06-data/domains/07-notification.md` — channels, states and INV-023 to INV-025
- `04-requirements/functional.md` — FR-501 to FR-509
- Related to: [ADR-004](ADR-004-microservices-architecture.md) (profile-service owns notifications)
