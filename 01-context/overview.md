# System Overview

## What is TraduceSeñas?

TraduceSeñas is a mobile and web application that recognises Colombian Sign Language (LSC)
through the device camera and converts it into written text or synthesised speech in real time.
It is aimed at closing the communication gap between Deaf people and hearing people who do not
know sign language, in everyday settings such as schools, shops, health centres and public services.

It also includes a learning module that displays the sign alphabet, so that a hearing user can
start recognising and reproducing basic signs without a prior course.

## Objectives

**General.** Design and implement a mobile application that translates Colombian Sign Language
into text or audio in real time, using computer vision and artificial intelligence, in order to
reduce the communication barriers Deaf people face in everyday settings.

**Specific.**

1. Build a tool that recognises LSC signs and returns the translation immediately.
2. Turn recognised signs into written or spoken words that any hearing person understands.
3. Let Deaf and hearing people communicate in ordinary situations — a classroom, a shop, a
   service counter — without an interpreter present.
4. Validate the tool in real environments to confirm it is accurate and useful in daily life.
5. Contribute to a more inclusive society in which capability does not decide who can communicate.

> "Real time" means an end-to-end response of **5 seconds or less** from capture to displayed
> result, per NFR1. See `glossary.md`.

## Problem it solves

**Before the system:** a Deaf person who needs to communicate with someone who does not know LSC
depends on a certified interpreter. In Colombia the number of interpreters is far below demand,
and availability is especially scarce in rural areas, public institutions and unplanned everyday
situations. The result is loss of autonomy and reduced participation in education, work and health.

**With the system:** any person with a compatible smartphone can point the camera at the signer and
read what is being signed, without an interpreter present and without prior knowledge of LSC.
The system does not replace a professional interpreter in formal or legal settings; it covers the
everyday interactions that today have no coverage at all.

## Main users

| Role | Description | What they do in the system |
|------|-------------|--------------------------|
| Deaf / hard-of-hearing user | Person who communicates in LSC | Signs in front of the camera so the system produces text or speech for the hearing party; consults their translation history |
| Hearing user | Person who does not know LSC — teacher, student, shop assistant, public servant | Reads or listens to the translation; consults the sign alphabet to learn basic signs |
| Administrator | Technical profile in charge of the platform | Manages users and roles, publishes signs in the lexicon, manages sign templates, consults usage statistics |

> The MVP is designed around school environments (students and teachers) as the first validation
> setting, and then extends to shops and public services.

## Architecture

TraduceSeñas is a **microservices system**: five domain services — `iam`, `recognition`,
`lexicon`, `analytics` and `profile` — behind an **API Gateway**, the only published entry point.
The client is a single Expo / React Native codebase that runs on the web and on Android, organised
by feature (`src/feature/`), and talks to the gateway over REST. Each service is hexagonal, has its
own database (PostgreSQL, plus MongoDB for the gesture samples in recognition) and communicates
with the others through asynchronous domain events over RabbitMQ; account deletion uses an outbox
so the `UserDeleted` event is never lost. The decision was confirmed by the product owner on
2026-10-04 and is recorded in
[ADR-004](../05-architecture/decisions/records/ADR-004-microservices-architecture.md); the full
description lives in [`05-architecture/`](../05-architecture/overview.md).

**Sign recognition runs on the user's device.** MediaPipe locates the hands and body in each
camera frame (128 values per frame) and the team's own TensorFlow.js model, trained on the
LSC-54 dataset, classifies the sign among 54 words. A second engine recognises the alphabet with
hand geometry, KNN and DTW. Video never leaves the device, which supports the legal frame below
and means the server needs no GPU.

**Deployment.** Everything runs with Docker Compose on a Hostinger VPS, behind Caddy, which serves
HTTPS with Let's Encrypt certificates. The web app is published at https://traducesenas.tech and
the Android APK is distributed through GitHub Pages.

## Technology stack

| Layer | Technology | Justification |
|-------|-----------|---------------|
| Client (web and Android) | Expo 57 + React Native 0.86 + react-native-web + TypeScript | One codebase for the browser and the Android APK; the APK opens translation in a WebView |
| Navigation | React Navigation 6 | Standard routing for React Native, integrates with the screen structure |
| Global state | React Context API | Session, access, language, preferences and theme are read across the whole app |
| HTTP client | axios | REST calls to the API Gateway; no server-state cache library |
| Local persistence | expo-secure-store (native) / browser storage (web), AsyncStorage | Session token and local preferences |
| Speech | expo-speech | Reads the translated word aloud |
| Languages | i18n with Spanish, English, French and Portuguese | Interface text in four languages |
| Sign recognition | MediaPipe Tasks Vision + TensorFlow.js | Hand and pose landmarks plus the team's own 54-sign model, all running on the device |
| Backend | Node.js + Express 5 + TypeScript, zod | Same language as the client; REST is enough for the traffic profile of the MVP |
| Databases | PostgreSQL 16 (one per service) + MongoDB 7 | Data ownership per service, no foreign keys across databases ([ADR-003](../05-architecture/decisions/records/ADR-003-database-separation.md)) |
| Messaging | RabbitMQ (exchange `traduce.events`) | Asynchronous domain events between services, with a dead-letter queue per queue |
| Authentication | JWT (HS256), email + verification code, Google and Facebook login | Stateless sessions validated at the gateway ([ADR-002](../05-architecture/decisions/records/ADR-002-jwt-authentication.md)) |
| Notifications | In-app notifications and email (`profile-service`, Gmail SMTP) | No push service is used ([ADR-007](../05-architecture/decisions/records/ADR-007-email-notifications.md)) |
| Deployment | Docker Compose + Caddy on a VPS | 15 containers; HTTPS with automatic Let's Encrypt renewal |

## Current status

- **Phase:** In production at https://traducesenas.tech since 2026-10-16
- **Current version:** Backend `v1.3.0`, Frontend `v1.2.0` (web and Android APK) per each `package.json`; includes daily challenges and medals ([ADR-009](../05-architecture/decisions/records/ADR-009-daily-challenges.md), [ADR-010](../05-architecture/decisions/records/ADR-010-challenge-points-medals.md))
- **Release process:** production is built from `main`; each repository has its own SemVer version, published as a git tag and a GitHub Release ([git conventions](../00-governance/git-conventions.md))
- **Original planned schedule:** 14 two-week sprints, 2026-01-01 → 2026-07-31 (`Scrum.xlsx`). Kept as the baseline of record; not rewritten.
- **Next milestone:** final project defence (SENA ADSO) on 2026-10-28.

## Project contacts

| Role | Name | Contact |
|------|------|---------|
| Product Owner · Instructor of record | Jesús Ariel González Bonilla | Through the training programme |
| Tech Lead · Scrum Master · Analyst-Developer | Juan Mauricio Suaza Solórzano | suazasolorzano@gmail.com |
| Analyst-Developer | Luis Alejandro Duarte Aldana | aleosea777@gmail.com |
| Analyst-Developer | Juan Camilo Fierro Esquivel | fierroesquiveljuancamilo@gmail.com |

> The Product Owner is the instructor receiving this delivery: he reviews and accepts the
> increment and the documentation at each sprint review. He does not write the requirements.
>
> **Juan Mauricio Suaza Solórzano holds three roles at once.** This is stated rather than left
> implicit because it puts technical authority, process authority and delivery capacity in one
> person, with nobody to escalate to when the schedule and the process disagree.

Each of the three developers is costed at full-time dedication for six months —
$3,000,000 COP/month for the lead and $2,500,000 COP/month for each analyst-developer,
$48,000,000 COP in total. That figure is the "development and programming" line of the
budget in `scope.md`.

## Legal frame

The system captures video of people and stores personal data, so it operates under
**Ley 1581 de 2012** and **Decreto 1377 de 2013** (Colombian personal data protection).
In practice this means: no video sample is stored for model training without the user's
express, timestamped authorisation; that authorisation can be revoked; the user can request
deletion of their account and associated data; and retained training samples must be
detached from the user's identity. See NFR8 and `scope.md`.

---

## Correlations

- Scope boundaries → `01-context/scope.md`
- Term definitions → `01-context/glossary.md`
- Product vision and roadmap → `03-product/vision.md`
- Architecture → `05-architecture/overview.md`
- Documentation language rule → `05-architecture/decisions/records/ADR-001-documentation-language.md`
