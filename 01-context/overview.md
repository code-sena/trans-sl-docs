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
| Administrator | Technical profile in charge of the platform | Monitors recognition accuracy, manages content updates, consults usage statistics, supports end users |

> The MVP is designed around school environments (students and teachers) as the first validation
> setting, and then extends to shops and public services.

## Architecture

TraduceSeñas is a **microservices system**: five domain services — `iam`, `recognition`,
`lexicon`, `analytics` and `profile` — behind an **API Gateway**. The React Native / web client
(internally organised in N layers: presentation, business, data, external services and
configuration) talks to the gateway over REST. Each service is hexagonal, has its own database
(PostgreSQL, plus MongoDB for the training samples in recognition) and communicates with the
others through asynchronous domain events over RabbitMQ. The decision was confirmed by the
product owner on 2026-10-04; the full description lives in `05-architecture/`.

> **Extraction status:** the backend code today has the domain modules `auth`, `users`,
> `translations`, `ia` and `lexicon`, each already hexagonal, which are being split into the
> services above. Status per service: pending / in progress.

## Technology stack

| Layer | Technology | Justification |
|-------|-----------|---------------|
| Mobile frontend | React Native + TypeScript | Single codebase for Android and iOS; the team already knows JavaScript; good integration with camera and computer-vision libraries |
| Web frontend | React | Shares language, tooling and a large part of the component logic with React Native |
| Navigation | React Navigation | Standard routing for React Native, integrates with the screen structure |
| Global state | React Context API | Session, language and theme are read across the whole app |
| Server state | React Query | Caching and revalidation of history, lexicon and notifications without manual polling |
| Local persistence | AsyncStorage | Session token and offline preferences |
| Backend | Node.js + Express | Same language as the frontend; REST is enough for the traffic profile of the MVP |
| Sign recognition | MediaPipe + OpenCV | Pre-trained hand and gesture detection models; drastically reduces model training time |
| Database | MySQL | Reliable, free, widely supported and known by the team |
| Real-time transport | HTTPS + WebSockets | HTTPS for standard client-server calls, WebSockets for the live recognition stream |
| Push notifications | Firebase Cloud Messaging (FCM) | Avoids manual polling and battery drain |

## Current status

- **Phase:** In development
- **Current version:** not yet released
- **Last release:** none
- **Original planned schedule:** 14 two-week sprints, 2026-01-01 → 2026-07-31 (`Scrum.xlsx`). Kept as the baseline of record; not rewritten.
- **Next milestone:** **Pending re-planning.** The original schedule closed on 2026-07-31 and no new baseline has been agreed yet. This field stays empty on purpose until the team re-plans.

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
- Documentation language rule → `05-architecture/decisions/records/ADR-001-idioma-documentacion.md`
