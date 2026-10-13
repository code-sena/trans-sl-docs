# 14 — Training

> **Version:** 1.0 · **Date:** 2026-10-12 · **Language:** English ([ADR-001](../05-architecture/decisions/records/ADR-001-documentation-language.md) and [documentation-rules.md](../00-governance/documentation-rules.md))
> **Based on:** Docs `cc30cd7` · Backend `origin/develop` `b29a2fa` · Frontend `origin/develop` `06e7f39`
> **Status:** draft written by an agent; human review pending.

Manuals for the people who interact with Traduce Señas: end users, administrators and new developers.

## Source of truth

**This folder is the source of truth for the manuals.** The deliverables kept outside the repositories
(`entregables/Manuales/`, PDF and APA versions) are generated **from these files**, not the other way round.
If a manual needs a fix, fix it here and regenerate the deliverable.

Installation and technical architecture are **not** rewritten here: they are linked.

| Topic | Where it lives |
|-------|----------------|
| Local installation and environments | [10-devops/local-setup.md](../10-devops/local-setup.md), [10-devops/environments.md](../10-devops/environments.md) |
| Architecture | [05-architecture/](../05-architecture/README.md) |
| Services (catalog, data, events, runbooks) | [09-microservices/](../09-microservices/README.md) |
| HTTP contracts | [07-api/README.md](../07-api/README.md) |

## What is here

| File | Audience | Status | Notes |
|------|----------|--------|-------|
| [technical-onboarding.md](technical-onboarding.md) | New developer | Written, v1.0 | Day 1 setup, reading order, Git flow, service map, FAQ, known issues. Commands checked against Backend and Frontend `develop`. |
| [user-manual.md](user-manual.md) | End user (deaf or hearing person) | Written, v1.0 | Adapted from the Spanish user manual v1.2. Screens checked against Frontend `develop`. Screenshots reuse an earlier build (see the manual). |
| [admin-manual.md](admin-manual.md) | Administrator | Written, v1.0 | Roles and permissions from `permissions.ts` and the IAM routes, training, statistics. |

There is no other manual in this folder. Screenshots used by the manuals are in
[assets/14-training/](../assets/14-training/).

## Reading order by profile

- **New developer:** [technical-onboarding.md](technical-onboarding.md), then the files it lists.
- **Administrator:** [admin-manual.md](admin-manual.md), then the runbooks in
  [service catalog and per-service runbooks](../09-microservices/service-catalog.md) and [13-operations/](../13-operations/README.md).
- **End user:** [user-manual.md](user-manual.md).

## Per-service documentation (for developers and administrators)

| Service | Folder in Docs | OpenAPI contract |
|---------|----------------|------------------|
| api-gateway | [09-microservices/services/01-api-gateway/](../09-microservices/services/01-api-gateway/README.md) | [api-gateway.yaml](../07-api/contracts/openapi/api-gateway.yaml) |
| iam-service | [09-microservices/services/02-iam-service/](../09-microservices/services/02-iam-service/README.md) | [iam-service.yaml](../07-api/contracts/openapi/iam-service.yaml) |
| recognition-service | [09-microservices/services/03-recognition-service/](../09-microservices/services/03-recognition-service/README.md) | [recognition-service.yaml](../07-api/contracts/openapi/recognition-service.yaml) |
| lexicon-service | [09-microservices/services/04-lexicon-service/](../09-microservices/services/04-lexicon-service/README.md) | [lexicon-service.yaml](../07-api/contracts/openapi/lexicon-service.yaml) |
| analytics-service | [09-microservices/services/05-analytics-service/](../09-microservices/services/05-analytics-service/README.md) | [analytics-service.yaml](../07-api/contracts/openapi/analytics-service.yaml) |
| profile-service | [09-microservices/services/06-profile-service/](../09-microservices/services/06-profile-service/README.md) | [profile-service.yaml](../07-api/contracts/openapi/profile-service.yaml) |

## Rules for editing these manuals

- Follow [00-governance/documentation-rules.md](../00-governance/documentation-rules.md).
- Every manual starts with a header that states date, version and the commits it was checked against.
  When the code changes, re-check and update the header.
- Document what exists in the code. Anything that is not connected yet is marked **Known issue** or **Not connected**.
- No real secrets, no personal e-mails, no unverified URLs or ports.
- Do not promise CI, staging, production or test coverage: none of them exists today.

## Known issues that affect these manuals

| # | Issue | Where it shows up |
|---|-------|-------------------|
| 1 | The frontend in development points to `:3000/api` but the gateway listens on `:8080`; the frontend image's `nginx.conf` proxies to `backend:3000` and `lexicon:3003`, hosts that do not exist in the Backend compose | [technical-onboarding.md](technical-onboarding.md#known-issues) |
| 2 | [10-devops/local-setup.md](../10-devops/local-setup.md) does not fully match Backend `develop` | [technical-onboarding.md](technical-onboarding.md#known-issues) |
| 3 | There is no CI and no staging environment | [technical-onboarding.md](technical-onboarding.md#known-issues) |
| 4 | There is no ADR for the microservices decision (only ADR-001 to ADR-003 exist) | [technical-onboarding.md](technical-onboarding.md#known-issues) |
| 5 | Google and Facebook sign-in are not working | [user-manual.md](user-manual.md#4-signing-in) |
| 6 | Delete account likely fails in the Docker deployment (code review, not tested; needs a Backend fix) | [admin-manual.md](admin-manual.md#6-personal-data-and-law-1581), [user-manual.md](user-manual.md#7-your-data-and-privacy) |
| 7 | The OpenAPI contracts in `07-api` do not reflect Backend `develop`; the code is the source of truth | [technical-onboarding.md](technical-onboarding.md#known-issues) |

## Correlations

- [10-devops/local-setup.md](../10-devops/local-setup.md): first step of technical onboarding.
- [00-governance/](../00-governance/README.md): rules every new team member must know.
- [09-microservices/](../09-microservices/README.md): destination of most development work.
- [12-ux-ui/navigation-map.md](../12-ux-ui/navigation-map.md): the screens described in the user manual.
