# Incident Management

> An incident is any unplanned event that interrupts or degrades service.
> Effective incident response is trained before incidents occur, not during.
> Follow this playbook in order — in an incident, stress blocks free thinking.

---

## Severity classification

| Level | Name | Definition | Example | Response time |
|-------|------|------------|---------|---------------|
| **P0** | Critical | System completely down. Total impact to all users. | API Gateway down, DB inaccessible | **Immediate** (<5 min) |
| **P1** | High | Core functionality degraded. Impact to > 50% of users. | Login not working, payments failing | **15 minutes** |
| **P2** | Medium | Secondary functionality degraded. Workaround available. | Report export slow | **1 hour** |
| **P3** | Low | Minor nuisance. No impact on business operations. | Button with incorrect label | **Next sprint** |

---

## Roles during an incident

| Role | Responsibility | When activated |
|------|----------------|----------------|
| **Incident Commander (IC)** | Coordinates response. Makes decisions. Communicates. | P0 and P1 always |
| **Tech Lead** | In-depth technical diagnosis | P0 and P1 always |
| **On-Call Engineer** | First responder. Executes technical actions | All incidents |
| **Comms Lead** | Communicates to external stakeholders | P0 and P1 |

---

## Response playbook

### Step 1: DETECT (0-5 min)

```
How do you know there is an incident?
  → Alert from Prometheus / PagerDuty
  → User report
  → Proactive monitoring on the dashboard

Immediate action:
  1. Acknowledge the alert in PagerDuty (to silence it and mark that someone responded)
  2. Go to the Slack #incidents channel and write: "Investigating [brief description] — [your name]"
  3. Open the runbook for the affected service: `09-microservices/services/[service]/runbook.md`
```

### Step 2: CLASSIFY (5-10 min)

```
Determine severity:
  → How many users are affected?
  → What features are down?
  → Is there a workaround available?

If P0 or P1:
  → Activate the Incident Commander
  → Create the incident ticket in [Jira/Linear]: INC-XXX
  → Open the War Room (temporary Slack channel or video call)
```

### Step 3: COMMUNICATE (10-15 min)

Initial update in the team channel and to stakeholders:

```
Initial communication template:
─────────────────────────────────
🔴 INCIDENT P[N] — [INC-XXX]
Affected service: [name]
Impact: [What is not working for whom]
Status: Investigating
Next update: in 30 minutes
IC: [Incident Commander Name]
─────────────────────────────────
```

### Step 4: DIAGNOSE (10-30 min)

For microservices, each service must be checked independently:

```
Diagnostic tools (in order):
  1. Which service is failing? (Check all 5 services + gateway health)
     curl http://localhost:8080/health           # Gateway
     curl http://localhost:3001/health/ready     # iam-service
     curl http://localhost:3002/health/ready     # recognition-service
     curl http://localhost:3003/health/ready     # lexicon-service
     curl http://localhost:3004/health/ready     # analytics-service
     curl http://localhost:3005/health/ready     # profile-service
  
  2. Grafana → When did the problem start? Which service has a high error rate?
  
  3. Logs (Kibana/CloudWatch) per service → What does the affected service say?
     Filter by: service name + correlation ID (x-correlation-id) to trace request flow
  
  4. Distributed tracing (Jaeger) → Where does the trace break across services?
  
  5. RabbitMQ → Are domain events being published and consumed?
     Check broker logs: docker logs traduce-rabbitmq
  
  6. docker ps / kubernetes → Is the pod/container running?

Key question: What changed in the last 2 hours?
  → Last deploy (which service?)
  → Configuration change (which service's .env?)
  → Traffic spike (check gateway + analytics)
  → Database connection pool exhausted (check PostgreSQL/MongoDB logs)
  → RabbitMQ message backlog (check broker health)
```

**See specific decision tree per service:** `09-microservices/services/[service]/runbook.md`

### Step 5: MITIGATE (15-60 min)

```
Mitigation options (from safest to riskiest):
  1. Rollback to the last stable deploy (if a deploy caused the problem)
  2. Disable the feature flag that introduced the problem
  3. Scale horizontally if it is a capacity issue
  4. Temporarily increase timeout / circuit breaker
  5. Redirect traffic to an alternative region (if available)
  6. Activate maintenance mode (last resort)
```

**Before each change during an incident:**
- Announce in the War Room what you are going to do
- Wait for the IC's confirmation
- Execute the change
- Report the result within 2 minutes

### Step 6: RESOLVE AND COMMUNICATE

```
The incident is resolved when:
  - Error metrics return to normal levels
  - Health checks respond 200 on all services
  - The PO / stakeholder confirms users can operate normally

Resolution communication:
─────────────────────────
✅ RESOLVED — [INC-XXX]
Root cause: [brief description]
Resolution: [what was done]
Total duration: [X] minutes
Post-mortem: [meeting date]
─────────────────────────
```

---

## Post-Mortem (Incident Retrospective)

The post-mortem is not to blame anyone — it is to understand and prevent.
Held within 2 business days after resolving the incident.

### Post-mortem structure

**INC-XXX — [Incident title]**

**Key data:**
- Start date and time: 
- Resolution date and time: 
- Total duration: 
- Severity: P[N]
- Affected users: [N]

**Timeline:**

| Time | Event | Action taken |
|------|-------|-------------|
| HH:MM | [What happened] | [Who did what] |

**Root cause:**
> Why did it happen? (5 Why's — get to the real cause, not the symptom)

**Contributing factors:**
> Factors that facilitated the incident (without blaming people)

**What went well:**
> [What part of the incident response was effective]

**What did not work:**
> [What part failed or could be improved]

**Action items:**

| Action | Owner | Deadline | Status |
|--------|-------|---------|--------|
| [Concrete action to prevent recurrence] | [Name] | [date] | Pending |

---

## Communication channels

| Channel | Purpose |
|---------|---------|
| Slack `#incidents` | Main channel for all P0–P1 incidents |
| Slack `#ops-general` | Operational notices, planned maintenance, lessons learned |
| Email (team mailing list) | Incident notifications for asynchronous stakeholders |
| Microsoft Teams (future) | Video war room if SMS alert is activated |

---

## Team structure (TraduceSeñas is a 3-person team)

| Role | Name | Slack handle | On-call |
|------|------|--------------|---------|
| Tech Lead · Incident Commander | Juan Mauricio Suaza Solórzano | `@juan` | Primary (always) |
| Analyst-Developer | Luis Alejandro Duarte Aldana | `@luis` | Secondary (backup) |
| Analyst-Developer | Juan Camilo Fierro Esquivel | `@camilo` | Tertiary (backup) |
| Product Owner · Instructor | Jesús Ariel González Bonilla | `@jesus` | Notify only (not technical responder) |

**On-call rotation:** Primary responder at all times. If unreachable, escalate to secondary.
No formal paging system exists; use Slack mentions + SMS (manual for now).

---

## Example incident: Backend PostgreSQL timeout (P1)

```
13:45 — Alert fires in Grafana:
  "PostgreSQL connection timeout"
  
13:45 — @juan acknowledges in Slack #incidents:
  "Investigating PostgreSQL timeout. Will update in 5 min."
  
13:47 — Diagnosis (Grafana):
  - Connection pool at 100% (max is 30)
  - Spike in login requests (5 RPS → 50 RPS)
  - P95 latency jumped from 100ms → 2000ms
  
13:49 — Mitigation option #1 (preferred):
  "Increase pool size in .env and redeploy"
  vs option #2 (riskier):
  "Kill idle connections and retry"
  
13:50 — Decision: Increase pool size (safe, reversible)
  - Announce: "@everyone scaling DB pool 30→50"
  - Wait for thumbs-up in thread
  - Execute: update .env, docker restart
  - Test: curl https://prod.traduce-senas.com/health/ready
  
13:52 — Metrics return to normal
  - Report: "✅ RESOLVED — pool size increased to 50"
  
14:00 — Post-incident (same day):
  - Root cause: login feature went viral in testing
  - Action item: TD-XXX "Increase default pool size to 50 and add monitoring alert at 80%"
  - Owner: @juan, Sprint 4
```

---

## Correlations

- Observability alerts → `13-operations/observability.md`
- Technical runbooks per service → `09-microservices/services/XX/runbook.md`
- Microservices architecture → `09-microservices/service-catalog.md`
- SLOs and Error Budget → `13-operations/README.md`
- Post-incident technical debt → `15-project-control/technical-backlog.md`
