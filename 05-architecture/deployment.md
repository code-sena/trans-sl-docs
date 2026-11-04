# Deployment

## 1. Objective

The deployment of Traduce Señas must allow the main components of the system to be executed in an organized manner, maintaining the separation between the mobile application, the backend, and the persistence systems.

The deployment strategy must consider the performance, scalability, compatibility, and fault tolerance needs defined for the project.

---

## 2. Deployment components

The backend is defined by `docker-compose.yml` (13 containers). In production, `docker-compose.prod.yml` adds the `web` and `caddy` containers, for 15 in total.

| Component           | Technology                     | Responsibility                                                                 |
| ------------------- | ------------------------------ | ------------------------------------------------------------------------------ |
| Client              | Expo / React Native + TypeScript | Web app and Android APK. The web build is served by nginx (`web` container)  |
| Reverse proxy       | Caddy 2 (production only)      | HTTPS with Let's Encrypt. Sends `/api/*` to the gateway and the rest to `web`   |
| API gateway         | Express 5 + TypeScript         | Only public entry point (port 8080 locally). JWT check, rate limits, proxy by path, `/health` |
| Domain services (5) | Express 5 + TypeScript, hexagonal | `iam`, `recognition`, `lexicon`, `analytics`, `profile` (internal ports 3001–3005) |
| Structured databases | PostgreSQL 16                 | One database per service (five containers)                                      |
| AI data database    | MongoDB 7                      | Gesture samples of `recognition-service`                                        |
| Message broker      | RabbitMQ 3 (management image) | Domain events on the `traduce.events` topic exchange                            |

---

## 3. Development environment

Running `docker compose up --build` in the backend repository starts the whole backend (gateway, five services, five PostgreSQL databases, MongoDB and RabbitMQ). The Expo app runs separately. See [local-setup.md](./../10-devops/local-setup.md).

Without Docker, `npm run dev:all` starts the gateway and the five services. The databases and RabbitMQ must then be started by hand.

```text
Expo app (web / Android) ──HTTP──► API gateway :8080
                                     │
     ┌──────────┬───────────┬────────┴───┬───────────┐
     ▼          ▼           ▼            ▼           ▼
    iam    recognition   lexicon    analytics    profile
     │          │                        │           │
     └── PostgreSQL (one per service) ───┘           │
                │                                    │
            MongoDB (recognition)      RabbitMQ (traduce.events) ◄── all services
```

---

## 4. Production

Production runs the same compose files with `docker-compose.prod.yml` on one server. The domain is set by `DOMAIN` (default `traducesenas.tech`). Caddy is the only proxy in front of the gateway, so the gateway trusts one hop (`TRUST_PROXY=1`). Environment variables and the current deploy checklist are in [10-devops/environments.md](./../10-devops/environments.md). The step-by-step production deploy is still not fully documented.
