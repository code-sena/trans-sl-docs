# Open Questions

> Unanswered questions that can block the project. When a question is answered,
> the decision is recorded as an ADR (in 05-architecture/decisions/records/) or closed here.

---

## Critical questions (project-blocking)

### Q-001: On-device vs server-side inference — where does sign recognition run?

| Field | Value |
|-------|-------|
| **Question** | Does the TensorFlow.js model run on the mobile device (React Native) or on the backend server (Node.js)? |
| **Context** | Model size: 25 MB. Inference latency: 100–500 ms on mid-range phones (4 GB RAM), 30–100 ms on server. Network latency: 50–200 ms in Colombia. Battery impact: 8% per 10 min on-device. Server-side requires POST /recognize endpoint and model versioning. |
| **Implication** | Decision changes: (1) App size (25 MB vs ~5 MB). (2) User battery and data consumption. (3) Inference SLO in NFR-002 (500 ms total vs 300 ms + network). (4) Server load and ML ops. (5) Offline capability. (6) Where gesture samples are collected. |
| **Required for** | Contract with SENA (scope and budget); deployment architecture; testing plan |
| **Who answers** | Tech Lead (Juan Mauricio) + PO (Jesús Ariel) |
| **Deadline** | 2026-10-15 (must be decided before architecture PR is merged) |
| **Blocking** | YES — domain model assumes a port abstraction (SignRecognitionPort), but we need to know WHICH implementation. |
| **Status** | 🔴 UNANSWERED |
| **Current thinking** | On-device is preferred for offline + battery + latency. Server-side is safer for low-end devices. Hybrid (on-device fallback to server) is possible but expensive in dev time. |

---

### Q-002: Staging environment — do we build it or skip to production?

| Field | Value |
|-------|-------|
| **Question** | Budget funds one shared server. Do we deploy both staging (for PO acceptance) and production (for pilot) on the same host, or do we accept the risk of testing directly in production? |
| **Context** | Scope: 01-context/scope.md explicitly says "no staging environment" due to budget. Product Owner reviews on `dev` (a non-production-identical environment). Risk: deploy bug hits production users immediately. Benefit: no second server cost (saves $225k COP/month). |
| **Implication** | (1) Acceptance testing done on dev, not staging. (2) If a deploy breaks production, RTO = 15–30 min (rollback container). (3) No environment parity; hard to debug "works in dev, breaks in prod." |
| **Required for** | Deployment strategy (10-devops/), CI/CD pipeline |
| **Who answers** | PO + Tech Lead |
| **Deadline** | 2026-10-15 (before first deployment) |
| **Blocking** | YES — if staging is approved, infrastructure must be provisioned. |
| **Status** | 🟡 PARTIAL ANSWER: scope says "no staging," but decision not formally documented as ADR. |
| **Current assumption** | No staging. Risk accepted. Deploy on Monday–Thursday only. Rollback plan in playbook. |

---

### Q-003: What is the baseline accuracy threshold for model deployment?

| Field | Value |
|-------|-------|
| **Question** | At what accuracy level do we publish a new model to production? 85% (NFR-002)? Higher? Lower? What happens if accuracy drops after deployment? |
| **Context** | LSC-54 test set accuracy: ~85%. Real-world accuracy unknown (will vary by user, by regional LSC variation, by lighting, by hand size). NFR-002 says: "Minimum recognition accuracy ≥ 85% over the test set." But test set ≠ production. |
| **Implication** | (1) If threshold is test-set 85%: real-world may be 70%. Users unhappy. (2) If threshold is high (95%): slow to ship new models. (3) Need monitoring (Q-002 decision on observability) to detect real-world degradation. (4) Model rollback process required. |
| **Required for** | ML release process, model deployment checklist, acceptance criteria |
| **Who answers** | Tech Lead + Data/ML advisor (if available) |
| **Deadline** | 2026-11-01 (before model goes to production) |
| **Blocking** | YES — cannot deploy a model without knowing when it is "good enough." |
| **Status** | 🔴 UNANSWERED |
| **Current assumption** | 85% on test set is good-to-ship. Real-world monitoring will detect issues. Model versioning allows rollback. |

---

### Q-004: Consent revocation — what happens to historical gesture samples if a user withdraws consent?

| Field | Value |
|-------|-------|
| **Question** | User grants consent to store gesture samples for model training. Later, user revokes consent. Do we: (a) keep the samples but stop using them for new training, (b) delete the samples immediately, or (c) delete samples per-session at the user's choice? |
| **Context** | Law 1581/2012 (Habeas Data) allows revocation. But if we delete samples that were used to train the current model, do we need to retrain? Is the model legally tainted? If we keep them but do not retrain, are we violating the spirit of revocation? |
| **Implication** | (1) Data model: is there a revocation_date column? Do samples get soft-deleted? (2) ML pipeline: does a retrained model need to exclude revoked samples? (3) User experience: is revocation per-session or global? (4) Audit trail: can we prove which samples were used in which model versions? |
| **Required for** | Data model (06-data/domains/06-ai.md), user consent flow (FR-602), data deletion implementation (FR-014) |
| **Who answers** | PO + Tech Lead + Legal advisor (SENA) |
| **Deadline** | 2026-10-20 (before building consent flow) |
| **Blocking** | YES — cannot implement FR-602 without understanding revocation semantics. |
| **Status** | 🟡 PARTIAL ANSWER: data model allows consent_granted_at and consent_revoked_at, but deletion behavior is not decided. |
| **Current assumption** | Soft delete: revoke_date is set, samples are excluded from new training, old models remain as-is. Retrain on new samples only. |

---

## Important (high-value but not blocking)

### Q-005: Mobile platform priority — which platform do we polish first?

| Field | Value |
|-------|-------|
| **Question** | MVP will run on Android and iOS (both built from React Native code). Which platform gets priority for testing, optimization, and bug fixes? |
| **Context** | Team has limited testing capacity. Android has more variety (devices, OS versions, OEMs). iOS is more uniform but closed ecosystem. Colombia: 75% Android users (estimated). |
| **Implication** | (1) Testing focus: Android first means better coverage of the majority. (2) Optimization: iOS often faster; if we optimize for iOS, Android may feel slow. (3) Marketing: "Android-first" messaging aligns with local market. |
| **Required for** | QA plan, testing schedule, performance targets per platform |
| **Who answers** | Tech Lead + QA (if hired) |
| **Deadline** | 2026-11-01 (before beta testing) |
| **Blocking** | NO — both platforms will be tested; this is about priority. |
| **Status** | 🟡 PARTIAL ANSWER: scope says "Android 9+ minimum," suggesting Android priority. iOS not yet validated. |
| **Current assumption** | Android first, iOS parity goal. Test on Android 11 + 4GB RAM reference device. |

---

### Q-006: Gesture sample database growth — when do we need sharding / archiving?

| Field | Value |
|-------|-------|
| **Question** | Gesture samples are stored in MongoDB (no schema enforcing size limits). If the pilot grows to 10k users and each collects 50 samples, we have 500k documents (~50 GB). At what size do we implement partitioning, sharding, or archival? |
| **Context** | NFR-004 says MongoDB grows independently. Current infrastructure: single replica set, no sharding. Query time: O(collection size). No retention policy yet. |
| **Implication** | (1) If growth is unplanned: queries slow down, backups take longer. (2) Archival strategy: move old samples to cold storage? Delete after 1 year? (3) Sharding: requires rewrite of sample collection logic. (4) Cost: storage grows linearly. |
| **Required for** | Data lifecycle policy (06-data/data-lifecycle.md), backup strategy, storage capacity planning |
| **Who answers** | Tech Lead + SENA IT |
| **Deadline** | 2026-12-01 (before production scale testing) |
| **Blocking** | NO — can be handled post-MVP, but should be planned. |
| **Status** | 🟡 PARTIAL ANSWER: NRF-004 mentions it; no plan yet. |
| **Current assumption** | No sharding in MVP. If MongoDB reaches 50GB: archive samples > 6 months old to cold storage and write ADR-00X to document decision. |

---

### Q-007: Microservices extraction — when and how?

| Field | Value |
|-------|-------|
| **Question** | Should Traduce Señas adopt a microservices architecture? When? Why? |
| **Context** | Microservices add operational complexity (deployment, monitoring, resilience). Worth it only if: (a) scaling bottleneck, (b) teams need independence, (c) different languages/stacks needed. 3-person team on 1 server suggests monolith is sufficient for MVP, but domain boundaries already exist in code. |
| **Implication** | Microservices allow independent deployment, resilience via isolation, and scalability. But they require RabbitMQ, distributed tracing, per-service observability, and careful service coordination. |
| **Required for** | Long-term architecture roadmap, infrastructure planning |
| **Who answers** | Product Owner (decision maker) + Tech Lead |
| **Deadline** | 2026-10-04 |
| **Blocking** | YES — decision affects deployment strategy, infrastructure, and incident response. |
| **Status** | 🟢 RESOLVED |
| **Decision** | **MICROSERVICES** — Product Owner decision, 2026-10-04. 5 domain services (iam, recognition, lexicon, analytics, profile) + api-gateway, with RabbitMQ for async events. See `09-microservices/service-catalog.md` for the single source of truth. |

---

## Closed questions / Decided

| # | Question | Decision | ADR | Closed date |
|---|----------|----------|-----|------------|
| D-001 | JWT vs sessions for auth? | JWT with refresh tokens | ADR-002-jwt-authentication | 2026-09-01 |
| D-002 | PostgreSQL vs MySQL? | PostgreSQL + MongoDB (two-DB strategy) | ADR-003-database-separation | 2026-09-08 |
| D-003 | Documentation language? | English (except comments in Spanish) | ADR-001-documentation-language | 2026-09-01 |
| D-004 | Sign language dataset source? | LSC-54 (government initiative) + crowd-sourced samples | (implicit in scope) | 2026-09-08 |
| D-005 | 3D avatar for alphabet? | No — 2D images/animations only. Avatar out of scope. | (implicit in scope.md §1) | 2026-09-08 |
| D-006 | Monolith vs microservices? | Microservices (5 services + gateway + RabbitMQ) | (see `09-microservices/service-catalog.md`) | 2026-10-04 |

---

## Correlations

- Risk register (risks triggered by unanswered questions) → `15-project-control/risks.md`
- Architectural decisions → `05-architecture/decisions/`
- Scope boundaries → `01-context/scope.md`
- Technical decisions pending (inference location) → Q-001 blocks `05-architecture/decision-records/ADR-00X-inference-location.md`
