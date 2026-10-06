# Technical Backlog

> Technical improvements, refactors, and debt that must be paid soon.
> Different from product HUs: these do not add features but improve how the system works.
> Tracked separately so they do not compete with feature capacity (but still get prioritized).

---

## Critical (must do before MVP release)

### TD-001: Implement structured logging (Pino/Winston)

| Field | Value |
|-------|-------|
| **ID** | TD-001 |
| **Title** | Replace console.error() with structured JSON logging |
| **Description** | Backend error handler uses console.error() (unstructured). Logs mix with Node.js internal logs, timestamps are missing, no correlation ID. Implement Pino logger: JSON output, correlation ID propagation, log levels, context fields. |
| **Why now** | NFR-006 requires structured logs. Cannot operate production without it. |
| **Impact** | Production incidents take 10x longer to debug without proper logs. |
| **Effort** | 8 hours (1 SP) |
| **Priority** | Critical |
| **Target sprint** | Sprint 1 or 2 (before any staging deployment) |
| **Acceptance criteria** | (1) src/shared/logger.ts exports configured Pino instance. (2) Every error uses logger.error() instead of console.error(). (3) Correlation ID is propagated via middleware. (4) JSON log sample is in the repo with all required fields. |
| **Blocks** | NFR-006 observability checklist, monitoring setup (TD-002) |
| **Unblocks** | incident response, production debugging |
| **Notes** | Affects: error_handler.ts, auth domain, translation domain, all adapters. |

---

### TD-002: Implement health check endpoints

| Field | Value |
|-------|-------|
| **ID** | TD-002 |
| **Title** | Add GET /health (liveness) and GET /health/ready (readiness) endpoints |
| **Description** | Deployment monitoring and orchestration require health checks. Liveness: is the process alive? Readiness: can it serve traffic? (DB connected, model available). |
| **Why now** | NFR-003 requires availability SLO (99.5%). Cannot set SLO without monitoring. |
| **Impact** | Without readiness checks, deploying a broken backend looks like success for 5 min, then crashes. |
| **Effort** | 4 hours (1 SP) |
| **Priority** | Critical |
| **Target sprint** | Sprint 1 |
| **Acceptance criteria** | (1) GET /health returns 200 + {alive: true} if process is running. (2) GET /health/ready returns 200 if PostgreSQL responds to SELECT 1, MongoDB ping succeeds, model file exists. Returns 503 if any check fails. (3) No auth required. (4) Accessible from 0.0.0.0:3000 (not through API Gateway). |
| **Blocks** | Deployment readiness, container orchestration, monitoring alerts |
| **Notes** | Endpoint: src/shared/health/health.route.ts |

---

### TD-003: Implement RED metrics (prom-client)

| Field | Value |
|-------|-------|
| **ID** | TD-003 |
| **Title** | Add Prometheus metrics to track latency, error rate, throughput |
| **Description** | Express middleware to measure: http_request_duration_seconds (histogram), http_requests_total (counter by status), translations_completed/failed (business metrics). Expose at GET /metrics. |
| **Why now** | NFR-002 requires latency SLOs (P95 < 300ms). Cannot measure without metrics. |
| **Impact** | Without metrics: cannot detect performance degradation. |
| **Effort** | 12 hours (2 SP) |
| **Priority** | Critical |
| **Target sprint** | Sprint 2 |
| **Acceptance criteria** | (1) GET /metrics returns Prometheus format. (2) Latency buckets match NFR-002 (0.05, 0.1, 0.3, 0.5, 1.0 s). (3) Translation metrics have reason label (COMPLETED, FAILED, CONFIDENCE_TOO_LOW). (4) Middleware measures all endpoints. (5) Grafana dashboard pulls metrics (dashboard JSON in 10-devops/). |
| **Blocks** | SLO monitoring, performance regression detection |
| **Notes** | Replaces manual load testing in later sprints. |

---

### TD-004: Error classification and error_logs table

| Field | Value |
|-------|-------|
| **ID** | TD-004 |
| **Title** | Persist all unhandled errors to database for audit and analysis |
| **Description** | Every unhandled exception should be logged to error_logs table: error_type (PostgreSQLError, ValidationError, etc.), message, stack, context, user_id, created_at. Allows post-incident analysis and trend detection. |
| **Why now** | NFR-006 requires error persistence. Production incidents require RCA (root cause analysis). |
| **Impact** | Without error logs: cannot explain why 10 users had the same problem. |
| **Effort** | 8 hours (1 SP) |
| **Priority** | Critical |
| **Target sprint** | Sprint 2 |
| **Acceptance criteria** | (1) error_logs table exists (schema in 06-data/domains/10-audit.md). (2) Express error handler catches all errors, classifies them, writes to DB. (3) Admin console shows top errors by frequency. (4) No PII in error messages. |
| **Blocks** | Incident RCA, SLO tracking, error budget calculation |

---

## High priority (must do in MVP)

### TD-005: Audit trail for sensitive data changes

| Field | Value |
|-------|-------|
| **ID** | TD-005 |
| **Title** | Log all changes to users, gesture_samples, ai_models (before/after values) |
| **Description** | Regulatory requirement (Law 1581/2012) and operational necessity. Who changed what, when, and why. Audit logs stored in audit_logs table with before_value, after_value, changed_by, created_at. |
| **Why now** | NFR-005 § regulatory compliance. SENA audit will ask: "Show me who deleted that user." |
| **Impact** | Without audit: cannot prove compliance. Cannot debug data corruption. |
| **Effort** | 16 hours (2–3 SP) |
| **Priority** | High |
| **Target sprint** | Sprint 3 |
| **Acceptance criteria** | (1) Audit logs created for user updates, deletions, sample consent changes. (2) Each log includes before_value, after_value, changed_by (user ID or system). (3) Queries to show audit trail per user per entity. |
| **Blocks** | Legal compliance certification |

---

### TD-006: Rate limiting on auth endpoints

| Field | Value |
|-------|-------|
| **ID** | TD-006 |
| **Title** | Implement progressive lockout on failed login / password reset attempts |
| **Description** | NFR-005 requires: 10 requests/minute per IP on POST /auth/login. Add rate limiter: after 10 failed attempts, 1-min lockout; after 3 lockouts, 10-min lockout; after that, account BLOCKED. |
| **Why now** | Brute force protection (security baseline). |
| **Impact** | Without rate limiting: attacker can try 10k passwords per minute. |
| **Effort** | 8 hours (1 SP) |
| **Priority** | High |
| **Target sprint** | Sprint 2 |
| **Acceptance criteria** | (1) Rate limiter middleware on /auth/login and /auth/password-reset. (2) Store attempt count in Redis (or in-memory for MVP). (3) Lockout levels: 1, 5, 10 minutes. (4) After exhaustion, user.status = BLOCKED. |
| **Blocks** | Security certification |

---

### TD-007: CORS and HTTPS enforcement

| Field | Value |
|-------|-------|
| **ID** | TD-007 |
| **Title** | Configure CORS headers, enforce HTTPS in production, redirect HTTP → HTTPS |
| **Description** | API must be only callable from trusted origins. Prevent CSRF and data leaks. HTTPS mandatory in production (TLS 1.2+). |
| **Why now** | NFR-005 security requirement. |
| **Impact** | Without HTTPS: all requests (tokens, passwords) transmitted in cleartext. |
| **Effort** | 4 hours (1 SP) |
| **Priority** | High |
| **Target sprint** | Sprint 1 or 2 (before any prod deployment) |
| **Acceptance criteria** | (1) Express CORS middleware allows only https://traduce-senas.com (prod) and http://localhost:3000 (dev). (2) Non-HTTPS requests to prod return 403. (3) Certificate auto-renewal (Let's Encrypt). |

---

## Medium priority (do in Sprint 3–4)

### TD-008: Implement database transaction boundaries

| Field | Value |
|-------|-------|
| **ID** | TD-008 |
| **Title** | Ensure ACID properties for multi-step operations (e.g., persist translation + update usage stats + emit event) |
| **Description** | If DB commit fails halfway through a business operation, the system ends in an inconsistent state. Wrap multi-step ops in transactions: BEGIN → operation → COMMIT or ROLLBACK. |
| **Why now** | Data integrity. If a translation is persisted but usage event is not, reports are wrong. |
| **Impact** | Transactions are boring until you have a bug; then they save your reputation. |
| **Effort** | 12 hours (2 SP) |
| **Priority** | Medium |
| **Target sprint** | Sprint 3 |
| **Acceptance criteria** | (1) Identify all multi-step operations. (2) Wrap in transaction. (3) Test: kill DB mid-transaction, verify rollback. |

---

### TD-009: Implement exponential backoff for external service retries

| Field | Value |
|-------|-------|
| **ID** | TD-009 |
| **Title** | Add retry logic with exponential backoff for Firebase FCM, SMTP, OAuth providers |
| **Description** | If an external service is slow, retry with delays: 100ms → 300ms → 1s → give up. Prevents cascading failures. |
| **Why now** | Resilience. If Firebase is slow, do not hammer it; back off. |
| **Impact** | Without backoff: every timeout cascades to 30-second waits. |
| **Effort** | 8 hours (1 SP) |
| **Priority** | Medium |
| **Target sprint** | Sprint 3 |
| **Acceptance criteria** | (1) Retry logic on FCM, SMTP, OAuth. (2) Max 3 retries, exponential backoff. (3) Logs each retry with reason. |

---

### TD-010: Implement feature flags for gradual rollout

| Field | Value |
|-------|-------|
| **ID** | TD-010 |
| **Title** | Add feature flag system (e.g., LaunchDarkly or in-house) to enable/disable features without deployment |
| **Description** | Allow enabling new features for a % of users (canary rollout). If broken: kill the flag, no rollback deploy needed. |
| **Why now** | Risk mitigation. Deploying a broken auth flow affects 100% of users immediately. Feature flags let you affect 1% first. |
| **Impact** | Canary rollouts reduce MTTR (mean time to recovery) from 30 min to 2 min (just flip a flag). |
| **Effort** | 16 hours (2–3 SP) |
| **Priority** | Medium |
| **Target sprint** | Sprint 4 |
| **Acceptance criteria** | (1) Feature flag infrastructure in place (in-house OK for MVP). (2) New features ship behind flags. (3) Admin UI to toggle flags. |

---

## Lower priority (post-MVP, pay later)

### TD-011: Upgrade test coverage to 80%

| Field | Value |
|-------|-------|
| **ID** | TD-011 |
| **Title** | Increase unit and integration test coverage from current ~20% to 80%+ |
| **Description** | Low coverage means bugs escape to production. NFR-007 requires ≥80% coverage. |
| **Why now** | Test-first development (TDD) slows down initial sprints but prevents 3–4 week debugging cycles later. |
| **Effort** | 40 hours (6–8 SP) |
| **Priority** | Medium |
| **Target sprint** | Sprint 5+ (once features are stable) |

---

### TD-012: Implement distributed tracing (OpenTelemetry)

| Field | Value |
|-------|-------|
| **ID** | TD-012 |
| **Title** | Add OpenTelemetry instrumentation to trace requests across 5 microservices |
| **Description** | Architecture is now microservices: trace a user request as it flows through api-gateway → iam-service → profile-service (via RabbitMQ) → analytics-service, etc. For MVP: use correlation ID in logs. For post-MVP: integrate Jaeger/Zipkin. |
| **Why now** | Microservices are now decided (2026-10-04). Start simple with correlation IDs in logs; upgrade to OpenTelemetry after MVP if needed. |
| **Effort** | 20 hours (20 for correlation ID MVP; 20 for full OpenTelemetry) |
| **Priority** | Medium |
| **Target sprint** | Sprint 3 (correlation ID MVP); Sprint 5+ (OpenTelemetry) |

---

### TD-013: Implement request deduplication for idempotency

| Field | Value |
|-------|-------|
| **ID** | TD-013 |
| **Title** | Add idempotency keys to POST endpoints (client retry-safe) |
| **Description** | If client retries POST /translations with same body, server returns the same response (not a duplicate). Idempotency key stored and checked. |
| **Why now** | Nice-to-have. Mobile networks are unreliable; client may retry a slow request. Helps prevent double-translating. |
| **Effort** | 8 hours (1 SP) |
| **Priority** | Low |
| **Target sprint** | Sprint 4+ |

---

## Template for adding a new technical item

```markdown
### TD-00X: [Title]

| Field | Value |
|-------|-------|
| **ID** | TD-00X |
| **Title** | [1-line summary] |
| **Description** | [What, why, impact] |
| **Why now** | [Blocking what?] |
| **Impact** | [What breaks if we do not do this?] |
| **Effort** | [time estimate] |
| **Priority** | [Critical / High / Medium / Low] |
| **Target sprint** | [Sprint N] |
| **Acceptance criteria** | (1) ... (2) ... |
| **Blocks** | [What feature depends on this?] |
| **Notes** | [...] |
```

---

## Correlations

- Incident post-mortems generate technical items → `13-operations/incident-management.md`
- Risk mitigation drives technical debt → `15-project-control/risks.md`
- NFR verification dependencies → `04-requirements/non-functional.md`
- Backlog prioritization in product context → `03-product/product-backlog.md`
