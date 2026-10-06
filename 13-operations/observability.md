# System Observability

> An unobservable system cannot be operated. For TraduceSeñas, observability is the difference
> between "the system is broken and we know it" and "we wake up to 20 WhatsApp messages".
> This document describes what exists today and what is planned.

---

## Current Status: Production System

**TraduceSeñas is a microservices architecture (decision by product owner, 2026-10-04).**
- 5 domain services + API Gateway, each with its own database
- Services communicate synchronously via REST (through gateway) and asynchronously via RabbitMQ
- Deployed on a shared server (no orchestration yet); manual deployment
- PostgreSQL x5 + MongoDB on the same host

**What exists today:**
- Express error-handler middleware in each service logs to `console.error()` (unstructured)
- HTTP status codes as the only public signal
- Manual health checks: `GET /health` and `GET /health/ready` per service
- No metrics collection, no distributed tracing, no alert automation

**Implication:** production availability depends on someone noticing a report in Slack. Multi-service failures compound quickly.
**Observability strategy:** logs + metrics per service, distributed tracing via correlation ID across services (RabbitMQ event headers, gateway request ID).

---

## Phase 1: Logs (Month 2–3, In Progress)

### Standard format (structured JSON)

All errors and significant events **must** produce JSON logs:

```
                    ┌───────────────────────────────────────────┐
                    │           Production system               │
                    │                                           │
                    │  [Service A]   [Service B]  [Service C]  │
                    └──────┬──────────────┬───────────┬─────────┘
                           │              │           │
               ┌───────────┼──────────────┼───────────┼──────────┐
               ▼           ▼              ▼           ▼          │
           [LOGS]      [METRICS]      [TRACES]   [EVENTS]       │
               │           │              │                       │
               ▼           ▼              ▼                       │
       [Elasticsearch] [Prometheus]  [Jaeger/Zipkin]             │
               │           │              │                       │
               ▼           ▼              │                       │
           [Kibana]    [Grafana]          │                       │
                           │              │                       │
                           └──────────────┘                      │
                                  │                              │
                           [ALERTS] ──────────────────────────▶│
                        [Alertmanager]                          │
                        [PagerDuty]                             │
                        [Slack]                                  │
                    └──────────────────────────────────────────-┘
```

---

## Logs

### Standard format (structured JSON)

All services must produce JSON logs with these minimum fields:

```json
{
  "timestamp": "2024-01-15T10:30:00.123Z",
  "level": "ERROR",
  "service": "signa-backend",
  "version": "0.1.0",
  "environment": "production",
  "correlationId": "550e8400-e29b-41d4-a716-446655440000",
  "userId": "user-uuid-if-available",
  "message": "Failed to persist translation",
  "context": {
    "method": "POST",
    "path": "/api/translations",
    "statusCode": 500,
    "durationMs": 145,
    "error": "PostgreSQL connection timeout"
  }
}
```

**Required fields in every log:**

| Field | Description | Example |
|-------|-------------|---------|
| `timestamp` | ISO 8601 UTC | `2024-01-15T10:30:00.123Z` |
| `level` | ERROR, WARN, INFO | `ERROR` |
| `service` | Backend name | `signa-backend` |
| `correlationId` | UUID for tracing | `550e8400-e29b-41d4-a716-446655440000` |
| `message` | What happened | `PostgreSQL connection failed` |

**Implementation:**

```typescript
// Today (❌ wrong)
console.error('Error:', err.stack); // unstructured, mixed with stdout

// Tomorrow (✓ correct)
import { logger } from '@shared/logger';
logger.error('Failed to persist translation', {
  correlationId,
  userId,
  error: err.message,
  path: req.path,
});
```

**What NOT to log:** passwords, full tokens, unmasked PII, full SQL queries with user data.

### Log levels

| Level | When | Example |
|-------|------|---------|
| `ERROR` | Something failed that the user will notice | `PostgreSQL connection timeout` |
| `WARN` | Something unexpected but the system recovered | `JWT token refresh retry #2` |
| `INFO` | Normal business events | `User logged in`, `Translation persisted` |

### Tool: Pino (planned)

```typescript
// Setup: src/shared/logger.ts
import pino from 'pino';

export const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  formatters: {
    level: (label) => ({ level: label.toUpperCase() }),
    bindings: (bindings) => ({
      service: 'signa-backend',
      version: process.env.APP_VERSION || '0.1.0',
      environment: process.env.NODE_ENV || 'development',
    }),
  },
  timestamp: pino.stdTimeFunctions.isoTime,
});
```

**Destination:**
- Local dev: console (Pino's pretty-printer)
- Staging/production: stdout → Docker logs → (planned) centralized logging

---

## Phase 2: Metrics and Health (Month 3–4, Planned)

### Health endpoints (foundation)

**Liveness check — is the process running?**
```
GET /health
→ 200 OK: { alive: true }
```

**Readiness check — can it serve traffic?**
```
GET /health/ready
→ 200 OK if:
   - PostgreSQL connected (query: SELECT 1)
   - MongoDB connected (ping)
   - Active ML model resolvable (file exists)
→ 503 Service Unavailable otherwise
```

This is the hook for orchestration (if we move to containers with Kubernetes later).

### RED Metrics (Rate, Errors, Duration)

Per NFR-002, critical endpoints must hit:
- P95 latency < 300 ms
- P99 latency < 500 ms

Implement with `prom-client`:

```typescript
// src/shared/metrics.ts
import { Counter, Histogram } from 'prom-client';

export const httpRequestDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request latency',
  labelNames: ['method', 'path', 'status'],
  buckets: [0.05, 0.1, 0.3, 0.5, 1], // align with NFR-002
});

export const httpRequestsTotal = new Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'path', 'status'],
});
```

**Domain metrics to track:**

| Metric | Type | Why |
|--------|------|-----|
| `translations_completed_total` | Counter | Happy path: model worked |
| `translations_failed_total` | Counter | Model failed; reason label = LOW_CONFIDENCE / NO_HAND_DETECTED / etc. |
| `recognition_confidence_seconds` | Histogram | Silent model degradation detector |
| `signs_most_failed` | Top-K | Which classes need more training samples |

**Metrics endpoint:**
```
GET /metrics
Response: Prometheus format (text/plain)
Access: Internal network only, not through the API Gateway
```

---

## Phase 3: Dashboards (Month 4–5, Planned)

### Main dashboard — Command center

Required panels:
1. **Error rate (%)** — last 30 min — CRITICAL: if > 5%, page ops
2. **P95 latency (ms)** — per endpoint — CRITICAL: if > 300ms, investigate
3. **Throughput (RPS)** — total and per endpoint
4. **Active users** — concurrent sessions (from `users.last_activity`)
5. **Translations per day** — trending
6. **Model accuracy trend** — average confidence of COMPLETED translations

### Per-domain dashboard

**Authentication:**
- Login success rate (%)
- Failed login attempts (by reason: wrong password, account locked, etc.)
- Token refresh failures

**Translations:**
- Completed / Failed ratio
- Average latency per request
- Most failed signs (which classes to retrain)

**Lexicon:**
- Sign catalog query latency
- Cache hit rate

---

## Phase 4: Distributed Traces (Month 5–6, Planned)

Traces allow following a user's request across all 5 microservices.

**Tool:** OpenTelemetry + Jaeger (or Zipkin).

**For now (MVP):** use `x-correlation-id` header to link logs and events across services:

```typescript
// src/shared/http/correlation_middleware.ts (every service)
app.use((req, res, next) => {
  const correlationId = req.headers['x-correlation-id'] || generateUUID();
  res.setHeader('x-correlation-id', correlationId);
  req.correlationId = correlationId;
  next();
});

// When publishing events to RabbitMQ:
eventBroker.publish('iam.UserRegistered', { userId: '123', ... }, {
  headers: { 'x-correlation-id': req.correlationId }
});
```

**Result:** a single user request creates logs across iam-service → profile-service (RabbitMQ event) all tagged with the same correlationId. Searchable in Kibana/Elasticsearch.

---

## Phase 5: Alerts (Month 5+, Planned)

### Alert rules (Prometheus + Alertmanager)

| Alert | Rule | Severity | Notifies | SLA |
|-------|------|----------|----------|-----|
| `HighErrorRate` | Error rate > 5% for 5 min | P1 | Slack #incidents | Ack within 5 min |
| `HighLatency` | P95 > 300 ms for 10 min | P2 | Slack #alerts | Ack within 15 min |
| `ServiceDown` | Health check 503 for > 2 min | P1 | Slack #incidents + SMS | Ack within 5 min |
| `PostgreSQLDown` | Connection pool exhausted | P0 | Slack #incidents + SMS | Immediate |

```yaml
# Planned: prometheus-rules.yaml
groups:
  - name: traduce-senas-alerts
    rules:
      - alert: HighErrorRate
        expr: (rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate in production"
          description: "Error rate: {{ $value | humanizePercentage }}"
          
      - alert: ServiceUnhealthy
        expr: up{job="signa-backend"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Backend health check failing"
```

**Notification channels:**
- `#incidents`: P0–P1 alerts, for immediate escalation
- `#alerts`: P2–P3, informational
- SMS + PagerDuty: P0 only (future, if on-call rotation is established)

---

## Correlations

- Observability requirements → `04-requirements/non-functional.md` § NFR-006
- Alert response → `13-operations/incident-management.md`
- SLO tracking → `13-operations/README.md`
- Backlog (logging library, observability setup) → `15-project-control/technical-backlog.md`
