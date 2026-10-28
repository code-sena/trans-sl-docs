# ADR-008 — Database per Service

> Based on: Backend `develop` `2e0816f` (`docker-compose.yml`, `services/*/db/`, `packages/shared/src/events/`)

- **ID:** ADR-008
- **Date:** 2026-10-25
- **Status:** Proposed
- **Authors:** Luis Alejandro Duarte Aldana (proposal); to be accepted by the development team and the Product Owner

---

## Context

[ADR-004](ADR-004-microservices-architecture.md) chose microservices and states the rule "one database per service" in a single bullet. [ADR-003](ADR-003-database-separation.md) chose PostgreSQL plus MongoDB, but it was written for the monolith: it talks about one backend coordinating both engines. No document explains why the rule holds for this project, how the services stay consistent without sharing tables, who owns each piece of personal data, or how the databases are operated.

The code already follows the rule. Each service has its own PostgreSQL container and connects only to it (`DB_HOST` in `docker-compose.yml`). Only `recognition-service` uses MongoDB. No service reads another service's tables.

**Known constraints:**
- Ley 1581 de 2012: the system must be able to erase a person's data and prove it, and the gesture samples are biometric data.
- Three developers change the schema in parallel (for example profile-service for achievements and challenges while iam changes consent).
- Everything runs on one VPS with Docker Compose; there is no managed database service.
- Identifiers are `SERIAL` / `BIGSERIAL` and are never reused, so a deleted id cannot belong to a new account.

---

## Decision

**We decided:** every service owns one database. No service reads or writes another service's tables, and there are no foreign keys between databases. Data of another service is referenced by a logical id (`user_id`, `lexicon_id`, `translation_id`).

| Service | Database | Main data | Personal data it holds |
|---------|----------|-----------|------------------------|
| iam | PostgreSQL `iam` | accounts, roles, permissions, one-time codes, outbox | email, name, password hash, accepted terms version |
| recognition | PostgreSQL `recognition` + MongoDB `gesture_samples` | translations, sign templates, retention summaries, samples | translation texts (30 days), words translated per user, samples (`performed_by`, `recorded_by`) |
| lexicon | PostgreSQL `lexicon` + static media | public sign catalog | `created_by` / `updated_by` ids, kept on purpose as authorship |
| analytics | PostgreSQL `analytics` | usage events | `user_id` and sign codes per event |
| profile | PostgreSQL `profile` | profile, preferences, notifications, achievements, challenges, admin reports | copy of email and name received in `iam.UserRegistered` |

### How the services stay consistent

1. **Domain events over RabbitMQ** (exchange `traduce.events`). Consumers are idempotent: analytics stores the `eventId` with a unique constraint, profile keeps `processed_events`. A message that keeps failing goes to `<queue>.dead` instead of being lost.
2. **Transactional outbox for events that must not be lost.** `iam.UserDeleted` is written to `outbox_events` in the same transaction that deletes the account. A relay publishes pending rows every 5 seconds, waits for the broker confirmation (`mandatory`, so an event with no queue counts as failed) and retries with exponential backoff and the same `eventId`. Today only `iam.UserDeleted` uses the outbox; `iam.UserRegistered` and the other events are published directly and can be lost if the broker is down.
3. **`erased_users` in every service that keeps user data** (recognition, analytics, profile). When a service processes `iam.UserDeleted` it deletes or unlinks that user's data and stores the id in `erased_users` in the same transaction. Every later write for that id is refused or unlinked. This covers three cases:
   - a JWT issued before the deletion that is still valid (the token lives up to one day);
   - events that arrive late or out of order (a `TranslationProduced` or `UserRegistered` processed after `UserDeleted`);
   - a write that runs at the same time as the deletion. Create and erase take the same per-user transaction lock (`pg_advisory_xact_lock`), so one of them always sees the other.
4. **Internal HTTP for read-only questions.** profile asks recognition and analytics for statistics and iam for the administrator list, with a short-lived service JWT that carries only the permission it needs (`stats.read`, `admins.read`).

### Operation

- Each service brings its schema as numbered SQL files in `services/<service>/db/`, applied by the PostgreSQL image when the volume is created. In production new files are applied by hand with `psql`, after a backup in `/opt/backups/`. Unifying the tool is task M8 (H-02); the Liquibase changelogs do not reproduce the current schema yet.
- **Target, not met today:** each service connects with its own database user and password, with rights only on its own database. Today all five use the `postgres` superuser with the same `POSTGRES_PASSWORD` (`x-service-env` in `docker-compose.yml`).
- Backups are taken per database. They are manual today (RNF12 is open).
- **Detecting stuck events.** The outbox relay and the consumers write an `ALERTA` line to the log, but nobody receives it. Each service's internal `/health` reports what can leave data behind: iam the pending outbox events and the age of the oldest one; the consumers the messages in their `<queue>.dead` queues and the events their handler has been retrying for a long time. The second check matters because the cleanup of `iam.UserDeleted` retries forever: a cleanup that always fails never reaches `.dead`, and RabbitMQ does not count a message the consumer holds without acknowledging. The gateway marks `/api/health` as `degraded` when an event waits more than 10 minutes in the outbox, a dead-letter queue is not empty or a handler has been retrying for more than 10 minutes, so an external monitor can alert once when the state changes, not on every failure.
- Container logs are capped in `docker-compose.yml` (json-file, 10 MB × 3 files per container), so a failure that logs in a loop cannot fill the disk.

**Justification:**

1. **Personal data stays where it belongs.** Password hashes and emails are only in `iam`, and biometric samples only in recognition's MongoDB. A defect in analytics or profile cannot read them. With a shared database any defect anywhere reaches everything.
2. **Erasure can be shown.** "Where is this person's data?" has an exact answer: iam, plus the three services subscribed to `iam.UserDeleted`, each of which records the erasure in `erased_users`.
3. **Each kind of data uses the right engine.** Sample frames are variable-length number arrays (MongoDB); accounts, roles and achievements are relational (PostgreSQL). Only recognition needs to know MongoDB.
4. **Each kind of data has its own lifecycle.** Translations are deleted after 30 days, the sign catalog is public and permanent, samples are kept unlinked, codes expire in 15 minutes. Retention and backup rules can be set per database.
5. **Failures stay local.** A slow analytics report or the retention purge in recognition does not lock the tables used by login. `/api/health` reports each service separately.
6. **Parallel work without schema conflicts.** profile added its challenge tables (`009_daily_challenges.sql`) without touching any other service; a duplicated migration number stayed inside profile.
7. **Public data is apart from private data.** The alphabet and the sign templates are readable without a session and live in databases with no personal data.
8. **It is what makes ADR-004 meaningful.** Microservices over a shared database couple the services through the schema; ADR-004 already rejected that option.

---

## Evaluated alternatives

| Alternative | Pros | Cons | Reason for discarding |
|------------|------|------|-----------------------|
| One PostgreSQL container per service, plus MongoDB for recognition (chosen) | Isolation of data, failures and schema changes; clear ownership | Five PostgreSQL processes on one VPS, five backups, no cross-service transactions | — (chosen) |
| One PostgreSQL container with one database and one user per service | Keeps ownership and access isolation with less memory | A crash or a full disk of that container stops every service | Valid fallback if memory on the VPS becomes a problem; it does not change the rule of this ADR |
| One shared database for all services | Foreign keys and joins across contexts, one backup | Services coupled through tables; any defect reaches all data; erasure is harder to prove | Breaks ADR-004 |
| Modular monolith with one database | Simplest to run, real transactions | One release unit and one failure domain | Replaced by ADR-004 on 2026-10-05 |

---

## Consequences

**Positive:**
- Every table has one owner, so the question "who can change this?" has one answer.
- Account erasure works without any service touching another's tables.
- Schema changes of one service do not need coordination with the others.

**Negative / Trade-offs:**
- Consistency between services is eventual: right after an account is deleted, other services may still hold its data for a few seconds.
- No transaction spans two services. Anything that must happen in two places needs an event, and a lost event means stale data unless it goes through the outbox.
- Reports that combine data of several services need HTTP calls (the admin report reads recognition and analytics).
- More to operate: five PostgreSQL containers, MongoDB, RabbitMQ, five sets of migrations and backups.
- The `erased_users` tables grow with every deleted account. They only hold ids and dates.

**Impact on the system:**
- Affected services: all five, plus `docker-compose.yml` and `.env.example` when the per-service database users are introduced.
- Documents that must be updated: ADR-003 (it still describes one backend for both engines), `06-data/models.md` §0 (tables added after 2026-10-23), the six `09-microservices/services/*/data-model.md` (they describe the reference model, not the implemented one) and `06-data/migration-strategy.md` (it describes node-pg-migrate, which is not used).

---

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| One leaked `POSTGRES_PASSWORD` opens every database, because all services share the superuser | Medium | High | One user and password per service with rights only on its own database (part of M8) |
| A new service stores user data and nobody subscribes it to `iam.UserDeleted` | Medium | High | Rule for new services: if it stores a `user_id`, it consumes `iam.UserDeleted`, keeps `erased_users` and is added to `USER_DELETED_QUEUES` (`packages/shared/src/events/account_deletion_topology.ts`) |
| `iam.UserRegistered` is lost while the broker is down, and profile or analytics never learn about the account | Low | Medium | Move it to the outbox like `iam.UserDeleted` |
| Schemas drift between environments because migrations are applied by hand | Medium | Medium | One migration tool with a CI check against an empty database (M8, H-02) |
| Manual backups are forgotten | Medium | High | Scheduled daily dumps per database (RNF12) |
| An account erasure stays stuck (broker down, consumer failing, message in a dead-letter queue) and nobody notices, so the data is not erased as promised | Medium | High | `/api/health` turns `degraded` with the reason (`outbox_backlog`, `dead_letters`, `consumer_retrying`); an external monitor (for example UptimeRobot, or a `cron` on the VPS that emails through the existing Gmail account) alerts on the change of state |

---

## References

- [ADR-003](ADR-003-database-separation.md) — PostgreSQL + MongoDB without foreign keys (extended by this ADR to one database per service)
- [ADR-004](ADR-004-microservices-architecture.md) — microservices; this ADR details its "database per service" rule
- [ADR-005](ADR-005-terms-consent.md) — consent stored in `iam`
- `06-data/models.md` §0 — implemented tables per service
- `09-microservices/service-catalog.md` — data owned by each service
- `packages/shared/src/events/` — event bus, retries, dead-letter queues, `USER_DELETED_QUEUES`
- `services/iam-service/src/shared/application/relay_outbox.ts` — outbox relay
