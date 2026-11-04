# 05 — Architecture

# Architecture Overview

## 1. Architectural style

Traduce Señas uses an architecture oriented toward the separation of responsibilities and based on the principles of **Hexagonal Architecture (Ports and Adapters)**. Each backend service follows this style (see [hexagonal-architecture.md](./hexagonal-architecture.md)).

The system has three kinds of parts:

* **Client:** one Expo / React Native codebase that runs as a web app and as an Android APK.
* **API gateway** (`api-gateway`, Express 5): the only public entry point of the backend. When a request carries a JWT, the gateway checks it and rejects invalid tokens; it also applies rate limits and forwards each `/api/...` path prefix to the service that owns it. Each service decides which of its routes need a session.
* **Domain services:** `iam`, `recognition`, `lexicon`, `analytics` and `profile`. Each one owns its database and talks to the others through domain events published on RabbitMQ.

Storage follows database-per-service:

* **PostgreSQL 16:** one instance per service (five instances). Structured and transactional data.
* **MongoDB 7:** gesture samples of `recognition-service`.

Services do not share tables and do not use foreign keys across databases. They refer to each other with logical identifiers (for example `user_id`). See [ADR-003](./decisions/records/ADR-003-database-separation.md) and [ADR-008](./decisions/records/ADR-008-database-per-service.md).

The services, their routes and their events are described in the [service catalog](../09-microservices/service-catalog.md). This document does not repeat them.

---

## 2. Architecture diagram

```text
┌──────────────────────────────┐
│ Client                       │
│ Expo / React Native          │
│ web app and Android APK      │
└──────────────┬───────────────┘
               │ HTTPS (production) / HTTP :8080 (local)
               ▼
┌──────────────────────────────┐        production only
│ Caddy (TLS, Let's Encrypt)   │ ─ /* ─► web (nginx, Expo export)
└──────────────┬───────────────┘
               │ /api/*
               ▼
┌──────────────────────────────┐
│ API gateway (Express 5)      │
│ JWT check, rate limits,      │
│ /health, reverse proxy       │
└──┬─────────┬──────────┬──────────┬──────────┬──┘
   │         │          │          │          │   HTTP inside the Docker network
   ▼         ▼          ▼          ▼          ▼
┌──────┐ ┌──────────┐ ┌────────┐ ┌──────────┐ ┌────────┐
│ iam  │ │recognition│ │lexicon │ │analytics │ │profile │
└──┬───┘ └────┬─────┘ └───┬────┘ └────┬─────┘ └───┬────┘
   │          │           │           │           │
   ▼          ▼           ▼           ▼           ▼
 PostgreSQL (one database per service)     MongoDB (recognition only)

 iam, recognition, lexicon, analytics and profile ⇄ RabbitMQ
 (exchange `traduce.events`, dead-letter queues `<queue>.dead`)
```

Local development runs the same containers with `docker compose up --build`; only the gateway is published on the host. Production adds Caddy and the web container through `docker-compose.prod.yml`. See [deployment.md](./deployment.md).
