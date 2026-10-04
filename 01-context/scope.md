# System Scope

> **Why this document exists:** Scope prevents scope creep and aligns expectations.
> It is equally important to define what the system does NOT do as what it does.
> Review this document at the start of each planning cycle.

---

## In Scope

What the system **DOES build and maintain**:

### MVP Features

| # | Feature | Description | Owning module |
|---|---------|-------------|---------------|
| 1 | User management (FR1) | Registration, login with email and password, login with Google/Facebook, password recovery by email | `business/usuario` + `services/AuthService` |
| 2 | Main panel and navigation (FR2) | Post-login dashboard and a navigation bar available on every screen and every device | `presentation/navigation` |
| 3 | Sign → text / speech translation (FR3) | Camera activation, real-time sign recognition and rendering of the result as on-screen text or synthesised speech | `business/traduccion` + `services/IAService` |
| 4 | Visual notifications (FR4) | On-screen alerts for relevant events, which the user can enable and disable | `business/notificaciones` + `services/PushService` |
| 5 | Profile management (FR5) | View profile, switch light/dark theme, change password, choose interface language, list recent translations | `business/perfil` |
| 6 | Usage statistics (FR6) | Administrator dashboard: number of translations, time of use, most visited sections, filterable by date and activity type | `business/notificaciones` event observers + backend reporting |
| 7 | Sign alphabet (FR7) | Learning module showing every letter of the alphabet in LSC, in alphabetical order, rendered as **2D images or animations** | `business/traduccion` lexicon + `data/repositories` |

> **Each feature is delivered by one of the microservices.** TraduceSeñas is a microservices
> architecture (iam, recognition, lexicon, analytics, profile + API Gateway) — see `overview.md`
> and `09-microservices/`. The module names in the table are the client-side folders of the
> technical document §4.2; the backend part of each feature lives in the service that owns its
> bounded context. Extraction from the current domain modules is in progress.
>
> **FR7 renders in 2D.** The SRS left 3D modelling of the alphabet under evaluation, with 2D
> images or animations as the fallback if it proved too slow to build. With the 3D avatar out of
> scope entirely (see below), the fallback becomes the decision: the alphabet is static imagery,
> not a 3D model.

### Data protection obligations (NFR8) — in scope

The system captures video of identifiable people. Under **Ley 1581 de 2012** and
**Decreto 1377 de 2013**, the following are build obligations of the MVP, not later additions:

| # | Obligation | Acceptance condition |
|---|-----------|---------------------|
| 1 | Express authorisation before any video or gesture sample is stored for model training | The authorisation is recorded with date and time and can be demonstrated |
| 2 | The user can revoke that authorisation at any time | After revocation the system keeps translating, and simply stores nothing |
| 3 | The user can request deletion of their account and associated data | Deletion is honoured and verifiable |
| 4 | Retained training samples are detached from the user's identity | No stored sample can be traced back to the person who produced it |
| 5 | Two supporting documents exist: a personal data processing policy and a user consent form | Both are published before the pilot begins |

> Translation must keep working for a user who refuses or withdraws consent. Consent buys the
> right to keep samples for training; it is not the price of using the product.

### Included integrations

| External system | Integration type | Purpose |
|----------------|-----------------|---------|
| Google Sign-In | OAuth 2.0 | Social login |
| Facebook Login | OAuth 2.0 | Social login |
| Email provider | SMTP / transactional API | Password recovery messages |
| Firebase Cloud Messaging | SDK | Push notifications without manual polling |
| MediaPipe / OpenCV | Library, embedded | Hand and gesture detection for sign recognition |

> **Decided (2026-08-28):** the providers are **Google and Facebook**, as specified in the SRS.
> The technical document proposes Google and Apple; the SRS wins.
>
> **Sign in with Apple is deliberately not implemented.** App Store review rules make it mandatory
> for an app that offers any other third-party login — but that rule applies at App Store
> submission, and TraduceSeñas is an academic project that will be demonstrated, not published.
> If distribution through the App Store ever enters scope, this becomes a blocking requirement
> and must be reopened.

### Target platforms

| Platform | Minimum supported |
|----------|-------------------|
| Android | Android 9.0 (Pie), octa-core 1.8 GHz, 4 GB RAM, 64 GB storage, 720p camera, 3000 mAh |
| iOS | iOS 14 or higher |
| Web | Chrome, Firefox, Edge, Safari |

> Recommended profile: Android 12+, Snapdragon 700 series or MediaTek Dimensity, 6 GB RAM,
> 128 GB storage, 1080p camera, 4500 mAh. Source: `informe tecnico (1).xlsx`, sheet 1.

### Environments being built

| Environment | Purpose | Host |
|-------------|---------|------|
| Local | Development on each developer's machine | Developer laptops |
| Development (dev) | Integration and development testing | Shared server |
| Production | Deployment used for the pilot and the final demonstration | Shared server |

> **There is no staging environment.** The scaffold assumed four environments; the budget funds a
> single server at $225,000 COP/month. Product Owner acceptance therefore happens against `dev`,
> and the risk this carries — accepting on an environment that is not production-identical — is
> accepted deliberately rather than hidden. Reopen this if a second host is ever funded.

### Post-delivery commitments in scope

> Promised in the technical-economic proposal §8. They are part of what is delivered, not
> goodwill afterwards.

| Commitment | Term |
|-----------|------|
| Technical support | 24/7 for the first six months after launch |
| Periodic updates for performance, compatibility and security | Ongoing over the support term |
| Correction of user-reported defects | Within 48 hours maximum |
| Basic training for administrators and key users | Once, at handover |

---

## Out of Scope

What the system **does NOT build** in this version and why:

| # | What is out of scope | Reason | Future version? |
|---|---------------------|--------|----------------|
| 1 | **Text → sign translation** | Removed from scope by team decision. Producing correct LSC output requires a validated sign corpus and animation work that does not fit the MVP schedule | Yes — candidate for v2 |
| 2 | **Voice → sign translation** | Depends on feature 1: it is speech-to-text followed by text-to-sign | Yes — candidate for v2 |
| 3 | **Animated 3D avatar** | It is the rendering surface for features 1 and 2; with those out of scope it has no consumer in the MVP | Yes — candidate for v2 |
| 4 | Full LSC vocabulary | The MVP recognises a limited, curated set of signs; complete coverage requires a corpus built with certified interpreters over a long period | Progressive, release by release |
| 5 | Offline operation | Recognition relies on cloud processing and continuous connectivity | Under evaluation — on-device inference |
| 6 | Regional sign variants and other sign languages | The MVP targets Colombian Sign Language only | Yes — after LSC is stable |
| 7 | Certified interpretation for legal, medical or formal settings | The system is an everyday communication aid, not a substitute for a professional interpreter. Claiming otherwise creates legal and ethical exposure | No — deliberately never |

> **Note on removing text → sign.** The system is therefore **unidirectional** in the MVP:
> sign → text/speech. Every document that still describes TraduceSeñas as "bidirectional"
> (the source SRS, the technical document and the technical-economic proposal) predates this
> decision and must be corrected. The sign alphabet module (FR7) stays in scope: it displays
> static letters for learning and is not a translation into signs.

### What another system / team handles (and why not us)

| Feature | Who builds it | Why not us |
|---------|--------------|-----------|
| Sign recognition models | MediaPipe / OpenCV (third-party) | Pre-trained hand and gesture detection; training from scratch is outside the capacity and schedule of a three-person team |
| Sign validation and corpus quality | Certified LSC interpreters | Linguistic authority the development team does not have |
| Push delivery infrastructure | Firebase Cloud Messaging | Reusing a proven service is cheaper than operating our own |

---

## Scope assumptions

> These assumptions are taken to be true. If they change, the scope must be renegotiated.

| # | Assumption | Consequence if false |
|---|-----------|---------------------|
| 1 | Both Deaf and hearing users are willing to adopt the application as a communication channel | The product has no adoption path and the validation phase produces no usable feedback |
| 2 | Educational institutions or public bodies support the pilot and grant access to real environments | FR3 cannot be validated in the field; acceptance would rest on lab testing only |
| 3 | Certified LSC interpreters are available to validate translations and label training data | Recognition accuracy cannot be certified and the corpus loses linguistic validity |
| 4 | End users have a smartphone that meets the minimum profile (Android 9+, 4 GB RAM, 720p camera) | The audience shrinks and a lighter recognition mode would be required |
| 5 | Users have stable connectivity while translating | Offline operation would move into scope, which changes the whole recognition architecture |
| 6 | The sign set is updated continuously after release | Perceived value drops as users hit the vocabulary limit |

---

## Constraints

| Type | Description |
|------|-------------|
| **Time** | ⚠ **Re-planning pending.** The original baseline was 14 two-week sprints, 2026-01-01 → 2026-07-31 (`Scrum.xlsx`), and that window has closed. The technical-economic proposal describes a different plan — 6 phases totalling 26 weeks against the sprint plan's 28 — so the two were never reconciled. Until the team agrees a new baseline, treat time as an open constraint and do not commit to dates |
| **Budget** | ⚠ **Unreconciled.** The components are development and programming $48,000,000 · hardware $15,003,310 · infrastructure and servers $1,350,000 · testing and training $2,000,000 · software and security $225,000 — which **sum to $66,578,310**. The proposal's own §7 states a total of $66,350,000, its summary states approximately $66,800,000, and its change report §10.1 states $51,350,000. Four figures, none of which match the arithmetic. Treat $66,578,310 as the only defensible number until the proposal is corrected. Source: `Propuesta Técnica y Económica.docx` |
| **Technology** | React Native + TypeScript, React for web, Node.js + Express, PostgreSQL + MongoDB, RabbitMQ, MediaPipe + OpenCV. Microservices (iam, recognition, lexicon, analytics, profile + API Gateway), database per service |
| **Team** | 3 people for 6 months. One of them holds Tech Lead, Scrum Master and developer roles simultaneously — see `overview.md` |
| **Developer equipment** | Minimum per developer: Intel Core i5 8th gen / Ryzen 5, 8 GB RAM, 256 GB SSD, 720p camera. Training recognition models requires an NVIDIA GTX 1650 or better, which the minimum profile does not include. Source: `informe tecnico (1).xlsx`, sheet 2 |
| **Regulatory** | Ley 1581 de 2012 and Decreto 1377 de 2013 on personal data protection. Binding, not advisory — see the NFR8 obligations above |
| **Domain** | Limited initial sign vocabulary; continuous internet connection required; device hardware must meet the minimum profile |
| **Validation** | Pilot testing must take place in real environments, which depends on third-party permission and cooperation |
| **Accessibility** | The interface targets people with hearing disabilities: high contrast, large buttons, clear iconography, and no interaction that depends on hearing |

---

## External dependencies

| Dependency | Team / Provider | Required date | Status |
|-----------|----------------|--------------|--------|
| Certified LSC interpreters for validation and labelling | External / institutional | Before FR3 acceptance | 🟡 To confirm |
| Institutional permission for pilot testing | Schools and public bodies | Before the validation phase | 🟡 To confirm |
| Server hosting | Hosting provider | Before the dev environment | 🟡 To confirm |
| Google / Facebook OAuth credentials | Provider consoles | Before FR1 | 🔴 Pending |
| Firebase project and FCM keys | Google | Before FR4 | 🔴 Pending |
| Development equipment (3 laptops, monitors, camera, modem) | Purchase | Sprint 1 | 🟡 To confirm |
| Personal data processing policy and user consent form | Team, reviewed by the Product Owner | Before the pilot | 🔴 Pending |

---

## Open decisions that still affect the scope

> The source documents contradict each other in places. Each conflict is recorded here rather
> than resolved silently, so that a reader knows which statements are settled and which are not.

| # | Conflict between the sources | Status |
|---|------------------------------|--------|
| 1 | Architectural style: the technical document §4.1 describes a modular monolith in N layers, while the repository and the product owner decision use microservices | ✅ Resolved 2026-10-04 — microservices (see `05-architecture/`). The technical document §4.1 must be corrected |
| 2 | Direction of translation: the SRS, the technical document and the proposal all describe a bidirectional system | ✅ Resolved 2026-08-28 — the MVP is unidirectional. The three source documents must be corrected |
| 3 | Budget total: $66,800,000 (proposal summary) · $66,350,000 (proposal §7) · $66,578,310 (the sum of the components) · $51,350,000 (change report §10.1) | 🔴 Open — see Constraints above |
| 4 | Schedule: 26 weeks over 6 phases (proposal) vs. 28 weeks over 14 sprints (`Scrum.xlsx`) | 🔴 Open — and both baselines have expired |
| 5 | Social login providers: Google + Facebook (SRS) vs. Google + Apple (technical document) | ✅ Google + Facebook — see Included integrations |
| 6 | Product licence: MIT in this repository vs. a $2,000,000 COP/month commercial fee in the proposal §10.1 | 🔴 Open |
| 7 | Two dates in `Scrum.xlsx` are impossible: S4 spans "Febrero 15 – Febrero 18" while claiming two weeks, and S12 reads "Junio 16 – Junio 31" | 🔴 Open — fix at the source, not here |

### Source documents

> These are not in this repository. They live in `PROYECTO/entrega/docs/`.

| Document | What this section takes from it | Last read |
|----------|-------------------------------|-----------|
| `srs.docx` | FR1–FR7, NFR1–NFR8, use cases, user profiles, interfaces, constraints, scope statement §1.6 | 2026-09-03 |
| `Documento Técnico del Proyecto de Software.docx` | Framework selection, layered architecture, folder structure, the four GoF patterns | 2026-09-03 |
| `Propuesta Técnica y Económica.docx` | Budget, 6-phase plan, support commitments, payment milestones | 2026-09-03 |
| `informe tecnico (1).xlsx` | End-user and developer hardware profiles, team costs | 2026-09-03 |
| `Scrum.xlsx` | Scrum roles, 14 sprints, US1–US20 with priority and story points | 2026-09-03 |

---

## How to update the scope

The scope can change, but the change has a process:

1. Document the proposed change in this file
2. Evaluate the impact on schedule and effort
3. Obtain approval from the Product Owner and Tech Lead
4. Update the roadmap in `03-product/vision.md`
5. Create or update user stories in `04-requirements/user-stories.md`

---

## Change log

| Date | Change | Reason |
|------|--------|--------|
| 2026-08-28 | Text → sign, voice → sign and the 3D avatar removed from scope. The MVP becomes unidirectional (sign → text/speech) | Team decision |
| 2026-08-28 | Target platforms fixed as Android + iOS + web | Team decision, resolving a conflict between the SRS, the NFRs and the proposal |
| 2026-08-28 | Social login fixed as Google + Facebook; Sign in with Apple excluded | The project is demonstrated, not published to the App Store |
| 2026-08-28 | Schedule marked as pending re-planning | The original 2026-01-01 → 2026-07-31 baseline closed with no replacement agreed |
| 2026-09-03 | Feature ownership re-expressed as modules of a modular monolith instead of microservices | Aligns the scope with the architecture decided in the technical document §4.1 (superseded on 2026-10-04) |
| 2026-10-04 | Architecture confirmed as microservices (iam, recognition, lexicon, analytics, profile + API Gateway); database changed from MySQL to PostgreSQL + MongoDB | Product owner decision; aligned with `05-architecture/` |
| 2026-09-03 | NFR8 data protection obligations brought into scope as build items | Ley 1581 de 2012 is binding and was absent from every document in this section |
| 2026-09-03 | Staging environment dropped; PO acceptance moves to `dev` | Only one server is funded. The risk is accepted explicitly rather than left implicit |
| 2026-09-03 | FR7 alphabet fixed as 2D imagery | The SRS left 3D under evaluation; with the avatar out of scope, the 2D fallback becomes the decision |
| 2026-09-03 | Post-delivery support commitments recorded as in scope | Promised in the proposal §8 and previously recorded nowhere in the repository |
| 2026-09-03 | Budget marked unreconciled, with $66,578,310 as the defensible figure | The four totals in circulation disagree and none match the sum of the components |
| 2026-09-03 | iOS minimum fixed at 14 | The SRS §3.1.3 gives a concrete version; "current supported versions" was vaguer than the source |

---

## Correlations

- Vision and roadmap → `03-product/vision.md`
- Term glossary → `01-context/glossary.md`
- System overview → `01-context/overview.md`
- Functional requirements → `04-requirements/user-stories.md`
- Non-functional requirements → `04-requirements/non-functional.md`
- Scope-related risks → `15-project-control/risks.md`
