# Risk Register

> Unmitigated risks become problems. This register allows the team to
> anticipate, not just react.
> Review and update at each retrospective or when there is a significant project change.

---

## Probability × impact matrix

```
IMPACT
  │
  │ HIGH  │  [Mitigate]    │  [Avoid]       │
  │       │  Low           │  High          │
  │       │  Probability   │  Probability   │
  │───────────────────────────────────────
  │ MEDIUM│  [Accept]      │  [Mitigate]    │
  │       │  with monitoring│              │
  │───────────────────────────────────────
  │ LOW   │  [Accept]      │  [Accept]      │
  │       │                │               │
  └───────────────────────────────────────
              LOW              HIGH
                      PROBABILITY
```

**Response strategies:**
- **Avoid:** Change the plan so the risk cannot materialize
- **Mitigate:** Reduce the probability or impact
- **Transfer:** Pass the risk to another party (insurance, provider, contract)
- **Accept:** Acknowledge the risk and have a contingency plan

---

## Active risk register

### R-001 — Insufficient Colombian Sign Language (LSC) training dataset

| Field | Value |
|-------|-------|
| **ID** | R-001 |
| **Category** | Technical / Business |
| **Description** | The LSC-54 dataset (54 signs) is limited. Model accuracy in production may be <85% on untrained signs or regional variations of LSC. Pilot users request signs not in the training set and receive FAILED translations. |
| **Probability** | High |
| **Impact** | High |
| **Risk level** | Critical |
| **Strategy** | Mitigate |
| **Mitigation plan** | (1) Collect gesture samples from pilot users with consent (stored in MongoDB). (2) Prioritize retraining on most-failed signs monthly. (3) Publish monthly model updates. (4) Set user expectations: "This app knows these 54 signs; more signs coming." |
| **Contingency plan** | If accuracy drops below 80%: pause new user registrations and focus on model retraining for 2 weeks. |
| **Trigger** | (1) TRANSLATION_FAILED ratio > 20% in production. (2) User reports same failed sign 3+ times. (3) Average confidence < 0.75. |
| **Owner** | Juan Mauricio Suaza Solórzano (Tech Lead) |
| **Review date** | 2026-11-01 |
| **Status** | Active |

---

### R-002 — AI model accuracy degrades in production without monitoring

| Field | Value |
|-------|-------|
| **ID** | R-002 |
| **Category** | Technical |
| **Description** | The trained TensorFlow.js model is good in the lab (85%+ accuracy on test set) but fails silently in production: users get low-confidence predictions but the system accepts them anyway. Team does not detect the degradation until user complaints. |
| **Probability** | High |
| **Impact** | High |
| **Risk level** | Critical |
| **Strategy** | Mitigate |
| **Mitigation plan** | (1) Implement RED metrics for translations: COMPLETED vs FAILED, average confidence histogram. (2) Prometheus alert if average confidence drops below 0.75 (set in Month 3–4). (3) Monthly accuracy report comparing new test samples to baseline. (4) Confidence rejection threshold: if <0.60, show "Please try again" instead of translating. |
| **Contingency plan** | Rollback to the previous model version if new version shows <3% confidence drop on the same test set. |
| **Trigger** | Average confidence drops 5+ percentage points day-over-day. |
| **Owner** | Juan Mauricio Suaza Solórzano |
| **Review date** | 2026-11-01 |
| **Status** | Active |

---

### R-003 — SENA project timeline compression and scope creep

| Field | Value |
|-------|-------|
| **ID** | R-003 |
| **Category** | Business / Team |
| **Description** | Original plan: 14 sprints (Jan–July 2026). Actual start: Sept 2026. Current plan: undefined. Team is 3 developers at full-time cost ($48M COP/6mo) but budget is finite. Scope includes accessibility (WCAG 2.1 AA), data protection (Law 1581), and real-time translation — all non-negotiable per NFRs. Pilot deployment deadline is not yet confirmed by SENA. Feature requests will grow. |
| **Probability** | High |
| **Impact** | High |
| **Risk level** | Critical |
| **Strategy** | Mitigate |
| **Mitigation plan** | (1) Freeze scope now: only features in 03-product/roadmap phases 1–2 (auth, core translation). (2) Establish formal sprint planning with SENA PO before sprint 1 starts. (3) Implement strict DoD that enforces accessibility testing (blocks release if any screen fails WCAG AA). (4) Track velocity per sprint and re-plan every 2 sprints if actual ≠ forecast. (5) If timeline slips: cut Phase 4 (admin dashboards) and Phase 5 (ML improvements), keep MVP. |
| **Contingency plan** | If PO requests mid-sprint scope additions: create a "future roadmap" document and defer to next quarter. |
| **Trigger** | (1) Scope items requested that are not in phases 1–2. (2) Sprint velocity drops below 50% of forecast. (3) Accessibility or security findings in QA that require >1 sprint to fix. |
| **Owner** | Juan Mauricio Suaza Solórzano (triple role: Tech Lead, Scrum Master, Developer) |
| **Review date** | Weekly in retro |
| **Status** | Active |

---

### R-004 — Small team, no redundancy, and microservices operational complexity

| Field | Value |
|-------|-------|
| **ID** | R-004 |
| **Category** | Team / Technical |
| **Description** | The team is 3 developers. Tech Lead holds 3 roles (Scrum Master, Tech Lead, Developer). Microservices add deployment, monitoring, and incident response complexity. If Tech Lead becomes unavailable, there is no backup for: (1) managing 5 services + RabbitMQ, (2) coordinating distributed incidents across services, (3) architectural decisions. Knowledge is not fully documented. |
| **Probability** | Medium |
| **Impact** | High |
| **Risk level** | High |
| **Strategy** | Mitigate |
| **Mitigation plan** | (1) Every architectural decision goes into 05-architecture/decisions/records/ADR-XXX (mandatory). (2) Deployment runbook + per-service runbook in 09-microservices/services/[service]/runbook.md. (3) Weekly sync with full team on blockers (prevents information silos). (4) Pair programming on critical code: service extraction, RabbitMQ integration, incident response drills. (5) Each developer owns one service (iam, recognition, lexicon, analytics, profile) and documents its health checks, common failures, and mitigation steps. (6) Incident response drill quarterly: simulate a service outage, practice coordination via correlation ID tracing. |
| **Contingency plan** | If Tech Lead is out >3 days: Luis Alejandro takes over incident response (follows runbooks); Camilo reviews deployments. For architectural decisions: escalate to PO or steering committee. |
| **Trigger** | Tech Lead unavailable for >3 days; incident affecting >1 service simultaneously. |
| **Owner** | Juan Mauricio Suaza Solórzano & Luis Alejandro Duarte Aldana |
| **Review date** | Monthly |
| **Status** | Active |

---

### R-005 — Dependency on TensorFlow.js (TFJS) and TFLite; inference location TBD

| Field | Value |
|-------|-------|
| **ID** | R-005 |
| **Category** | Technical / External |
| **Description** | Sign recognition runs TensorFlow.js model. Decision is still open: on-device (React Native) or on server (Node.js). Model size is 25 MB; phone storage / battery assumptions differ by 1000x. TFJS/TFLite updates may break compatibility. Framework has no formal SLA. |
| **Probability** | Medium |
| **Impact** | High |
| **Risk level** | High |
| **Strategy** | Mitigate |
| **Mitigation plan** | (1) Decide inference location NOW (open decision Q-001 in open-questions.md). (2) Design SignRecognitionPort abstraction (already done in domain model) so either implementation can be swapped. (3) Pin TFJS version to major.minor; do not auto-update. (4) Test model on reference device (Android 11, 4 GB RAM) every release. (5) If TFJS breaks: fallback to ONNX Runtime (has vendor support). |
| **Contingency plan** | If on-device inference breaks during pilot: switch to server-side inference within 1 sprint (architecture allows it). Accept higher latency and battery drain for that iteration. |
| **Trigger** | TFJS version breaks on target device in integration test. |
| **Owner** | Juan Mauricio Suaza Solórzano |
| **Review date** | 2026-11-01 |
| **Status** | Active |

---

### R-006 — Video and gesture sample privacy; Law 1581/2012 compliance

| Field | Value |
|-------|-------|
| **ID** | R-006 |
| **Category** | Business / Legal / Technical |
| **Description** | System stores gesture samples (body movements linked to an identifiable person) for model training. Colombian Law 1581/2012 (Habeas Data) requires express, written consent per sample. Consent must be revocable and demonstrable. Failure to prove consent makes the entire training dataset legally unusable. Fines up to 50M COP + project cancellation. |
| **Probability** | Low (controls are in place) |
| **Impact** | Critical |
| **Risk level** | High |
| **Strategy** | Mitigate |
| **Mitigation plan** | (1) Consent is NOT nullable in the data model: gesture_samples.consent_granted_at NOT NULL. (2) Every sample has consent_terms_version so we know which terms the user accepted. (3) On-screen, in-app consent form before any sample is collected (FR-602). (4) Admin can delete samples by session (no cascade; identity is detached via hashing). (5) Data controller is SENA (documented in privacy notice and terms). (6) No sample is exported, shared, or used for anything other than LSC model training. |
| **Contingency plan** | If a sample is discovered without consent: (1) Delete it immediately. (2) Audit all samples from that user. (3) Report to SENA. (4) Notify legal team. |
| **Trigger** | (1) Audit discovers sample without consent. (2) User complaint about data use. |
| **Owner** | Juan Mauricio Suaza Solórzano & PO (Jesús Ariel González Bonilla) |
| **Review date** | Monthly |
| **Status** | Active |

---

### R-007 — Single production server; no redundancy, no failover (microservices complexity)

| Field | Value |
|-------|-------|
| **ID** | R-007 |
| **Category** | Technical / Business |
| **Description** | Production and staging run on one shared server. 5 microservices + RabbitMQ + PostgreSQL x5 + MongoDB all on one host. No multi-AZ, no load balancing, no hot standby. SLO is 99.5% (3h 39min/month downtime). If the server is down, all services offline simultaneously. If one component (e.g., RabbitMQ) fails, async event flow breaks and users cannot recover until manual restart. |
| **Probability** | Medium |
| **Impact** | High |
| **Risk level** | High |
| **Strategy** | Accept (with mitigation) |
| **Mitigation plan** | (1) Maintenance window: Sundays 2am–4am COT (low-traffic, predictable). (2) Database + RabbitMQ message queue daily automated backup at 3am. (3) Quarterly backup restore drill (test recovery of all 5 databases + message queue). (4) Deployment SOP: never deploy on Friday or near a holiday. (5) Container restart policy: restart unless-stopped for all services. (6) Monitoring: alert on RabbitMQ queue depth (if growing unbounded, broker is stuck). (7) Graceful degradation: if RabbitMQ is down, sync calls still work (gateway + services online), events queue when broker restarts. |
| **Contingency plan** | If server is down: (1) Restore from latest backup to a temporary instance. (2) Restore all 5 PostgreSQL databases and MongoDB in order (auth first, then others). (3) Restart RabbitMQ and replay undelivered messages. (4) RTO = 45 min. RPO = 24 hours. (5) During restore, users see a status page: "We are back in 45 minutes." |
| **Trigger** | Server outage > 15 min; RabbitMQ queue depth > 1000 for >10 min (indicates broker stall). |
| **Owner** | DevOps / IT infrastructure (external to the team, SENA responsibility) |
| **Review date** | Monthly |
| **Status** | Active |

---

## Common technical risks in microservices

These risks apply to almost all microservices projects. Evaluate which ones apply:

| Risk | Typical probability | Standard mitigation |
|------|--------------------|--------------------|
| Failure cascade (one service down brings everything down) | Medium | Circuit Breaker, timeout, fallback |
| Data inconsistency between services | High | Saga, Outbox, idempotent events |
| Network latency in synchronous calls | High | gRPC, cache, async where possible |
| Lost messages in the broker | Medium | At-least-once + idempotent consumers |
| Schema evolution breaks consumers | High | Version events, compatible changes first |
| Technical debt accumulation | High | DoD with minimum coverage, regular reviews |
| Premature over-engineering | Medium | Start simple, YAGNI, measure before optimizing |
| Sensitive data exposure in logs | Medium | Logging policy, PII masking, SAST |
| Configuration drift between environments | High | Infrastructure as Code, environment variables |

---

## Closed risks / Lessons learned

| ID | Risk | Outcome | Lesson |
|----|------|---------|--------|
| R-00X | [name] | [Occurred / Did not occur] | [What we learned] |

---

## Template for adding a new risk

```markdown
### R-00X — [Name]

| Field | Value |
|-------|-------|
| **ID** | R-00X |
| **Category** | |
| **Description** | |
| **Probability** | |
| **Impact** | |
| **Risk level** | |
| **Strategy** | |
| **Mitigation plan** | |
| **Contingency plan** | |
| **Trigger** | |
| **Owner** | |
| **Review date** | |
| **Status** | Active |
```

---

## Correlations

- External dependencies → `15-project-control/dependencies.md`
- Related open questions → `15-project-control/open-questions.md`
- Architectural decisions that mitigated risks → `05-architecture/decisions/`
