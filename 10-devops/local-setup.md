# Local Project Setup

> This document ensures that any developer can have a functional local environment
> in less than 1 hour. If it takes longer, the document is incomplete.
> **Rule:** If you have to guess something or look elsewhere, add what's missing here.

---

## Prerequisites

### Universal tools (all stacks)

| Tool | Minimum version | Install from | Verify with |
|------|----------------|--------------|-------------|
| Docker | 24.0+ | docker.com | `docker --version` |
| Docker Compose | 2.20+ | Included with Docker Desktop | `docker compose version` |
| Git | 2.40+ | git-scm.com | `git --version` |

### Backend and Frontend tools

| Tool | Minimum version | Install from | Verify with |
|------|----------------|--------------|-------------|
| Node.js | 20.x (LTS) | nodejs.org | `node --version` |
| npm | 10.x | Included with Node.js | `npm --version` |

**Backend:** Express 5.2+ TypeScript 5.6+ on Node.js 20+
**Frontend:** React Native (Expo 57) via Expo CLI

**Recommended (not required):**
- VS Code with ESLint and Prettier extensions
- Postman or Insomnia for testing API endpoints
- Expo Go app (iOS/Android) for testing the mobile app

---

## Local ports in use

Verify these ports are free before starting. Traduce Señas runs 5 microservices + API Gateway:

| Port | Service | Description |
|------|---------|-------------|
| 8080 | api-gateway | Main entry point (routing, JWT validation, rate limit) |
| 3001 | iam-service | Identity & Access Management |
| 3002 | recognition-service | Sign recognition & translation (core) |
| 3003 | lexicon-service | Sign lexicon & learning |
| 3004 | analytics-service | Usage analytics |
| 3005 | profile-service | User profiles, notifications, achievements |
| 5433 | PostgreSQL (iam) | Identity database |
| 5434 | PostgreSQL (recognition) | Translation & AI database |
| 5435 | PostgreSQL (lexicon) | Lexicon database |
| 5436 | PostgreSQL (analytics) | Analytics database |
| 5437 | PostgreSQL (profile) | Profile database |
| 27017 | MongoDB | Gesture samples (recognition service) |
| 5672 | RabbitMQ | Async messaging (domain events) |
| 8081 | Frontend (Expo) | React Native development server (web) |
| 19000 | Expo | Expo development server |
| 19001 | Expo | Expo development server (tunnel) |

**Check free ports:**
```bash
# Windows
netstat -ano | findstr ":[PORT]"

# macOS / Linux
lsof -i :[PORT]
```

---

## Step-by-step installation

### Step 1: Clone the repository

```bash
git clone https://github.com/sena-proyectos/traduce-senas.git
cd traduce-senas
```

### Step 2: Environment variables — Backend services

Each microservice runs from `backend/src/services/[service]/` and has its own `.env`.

**For now (extraction in progress):** services run from the monorepo (backend/) with separate env sections.

Example `backend/.env` (5 service ports + databases):

| Variable | Description | Value for local |
|----------|-------------|----------------|
| `API_GATEWAY_PORT` | Gateway public port | `8080` |
| `IAM_SERVICE_PORT` | iam-service internal port | `3001` |
| `RECOGNITION_SERVICE_PORT` | recognition-service internal port | `3002` |
| `LEXICON_SERVICE_PORT` | lexicon-service internal port | `3003` |
| `ANALYTICS_SERVICE_PORT` | analytics-service internal port | `3004` |
| `PROFILE_SERVICE_PORT` | profile-service internal port | `3005` |
| `IAM_DB_HOST` | iam service PostgreSQL | `localhost` |
| `IAM_DB_PORT` | iam database port | `5433` |
| `RECOGNITION_DB_HOST` | recognition service PostgreSQL | `localhost` |
| `RECOGNITION_DB_PORT` | recognition database port | `5434` |
| `MONGODB_URI` | MongoDB connection (gesture samples) | `mongodb://localhost:27017/gesture_samples` |
| `RABBITMQ_URL` | RabbitMQ broker (domain events) | `amqp://guest:guest@localhost:5672` |
| `JWT_SECRET` | Key for signing JWT | `openssl rand -base64 32` (generate one) |

> **NEVER** commit `.env`. It is in `.gitignore`.

### Step 3: Start databases locally

Start PostgreSQL per service, MongoDB, and RabbitMQ:

```bash
# Start iam-service PostgreSQL (5433)
docker run --name traduce-iam-db \
  -e POSTGRES_USER=traduce_user \
  -e POSTGRES_PASSWORD=dev_password \
  -e POSTGRES_DB=iam \
  -p 5433:5432 \
  -d postgres:15-alpine

# Start recognition-service PostgreSQL (5434)
docker run --name traduce-recognition-db \
  -e POSTGRES_USER=traduce_user \
  -e POSTGRES_PASSWORD=dev_password \
  -e POSTGRES_DB=recognition \
  -p 5434:5432 \
  -d postgres:15-alpine

# Start lexicon-service PostgreSQL (5435)
docker run --name traduce-lexicon-db \
  -e POSTGRES_USER=traduce_user \
  -e POSTGRES_PASSWORD=dev_password \
  -e POSTGRES_DB=lexicon \
  -p 5435:5432 \
  -d postgres:15-alpine

# Start analytics-service PostgreSQL (5436)
docker run --name traduce-analytics-db \
  -e POSTGRES_USER=traduce_user \
  -e POSTGRES_PASSWORD=dev_password \
  -e POSTGRES_DB=analytics \
  -p 5436:5432 \
  -d postgres:15-alpine

# Start profile-service PostgreSQL (5437)
docker run --name traduce-profile-db \
  -e POSTGRES_USER=traduce_user \
  -e POSTGRES_PASSWORD=dev_password \
  -e POSTGRES_DB=profile \
  -p 5437:5432 \
  -d postgres:15-alpine

# Start MongoDB (gesture samples for recognition service)
docker run --name traduce-mongodb \
  -p 27017:27017 \
  -d mongo:6-alpine

# Start RabbitMQ (domain events broker)
docker run --name traduce-rabbitmq \
  -e RABBITMQ_DEFAULT_USER=guest \
  -e RABBITMQ_DEFAULT_PASS=guest \
  -p 5672:5672 \
  -p 15672:15672 \
  -d rabbitmq:3-management-alpine

# Verify all are running
docker ps | grep traduce-
```

### Step 4: Install dependencies — Backend

```bash
cd backend
npm install
```

### Step 5: Run database migrations

```bash
# Migrations are in backend/DB/traduce_senas/ (Liquibase)
# The application applies them on startup. Just ensure the DB is running.
# Verify by connecting:
psql -h localhost -p 5433 -U traduce_user -d traduce_senas
```

### Step 6: Start the Backend services

**Current status (2026-10-04):** Services are being extracted from the monorepo. For now, start all services from one terminal:

```bash
cd backend
npm run dev:all
# Or individually (in separate terminals):
npm run dev:iam
npm run dev:recognition
npm run dev:lexicon
npm run dev:analytics
npm run dev:profile
npm run dev:gateway
```

Expected output: all services log their startup (ports 3001–3005 + gateway on 8080). Verify:
```bash
curl http://localhost:8080/health
# Should respond with {alive: true}
```

### Step 7: Install and start Frontend (React Native + Expo)

In a new terminal:

```bash
cd frontend
npm install
npm start
```

Follow Expo's prompts to run on web (`w`), Android, or iOS.

### Step 8: Verify it works

**Backend (via API Gateway):**
```bash
curl http://localhost:8080/api/auth/register
# Should respond with 400 (missing fields) or similar, not connection error
```

**Health check per service:**
```bash
curl http://localhost:8080/health                 # Gateway
curl http://localhost:3001/health                 # iam-service
curl http://localhost:3002/health                 # recognition-service
curl http://localhost:3003/health                 # lexicon-service
curl http://localhost:3004/health                 # analytics-service
curl http://localhost:3005/health                 # profile-service
```

**Frontend (web):**
- Open http://localhost:19001 (Expo tunnel) or http://localhost:8081 (web)
- Verify it loads the login screen

---

## Daily workflow

```bash
# At the start of the day
git pull origin dev

# Start all infrastructure (PostgreSQL x5, MongoDB, RabbitMQ)
docker start traduce-iam-db traduce-recognition-db traduce-lexicon-db traduce-analytics-db traduce-profile-db traduce-mongodb traduce-rabbitmq

# Backend microservices
cd backend
npm install  # If package.json changed
npm run dev:all  # Starts all 5 services + gateway

# Frontend (in a new terminal)
cd frontend
npm install  # If package.json changed
npm start    # Starts Expo dev server

# At the end of a task
git add [specific files]
git commit -m "type(scope): description"
# See 00-governance/git-conventions.md for format
```

---

## Common issues

### "Port 3001–3005 or 5433–5437 already in use"

```bash
# Windows — Find process using port
netstat -ano | findstr :3001
# Then kill it:
taskkill /PID [PID] /F

# macOS/Linux
lsof -i :3001
kill -9 [PID]

# Or stop all Traduce containers
docker stop traduce-iam-db traduce-recognition-db traduce-lexicon-db traduce-analytics-db traduce-profile-db traduce-mongodb traduce-rabbitmq
```

### "PostgreSQL container not starting"

```bash
# Check if container exists but stopped
docker ps -a | grep traduce-

# Restart specific service database
docker start traduce-iam-db

# View logs
docker logs traduce-iam-db

# Remove and recreate (data will be lost)
docker rm traduce-iam-db
# Then re-run the docker run command from Step 3
```

### "Database connection refused"

```bash
# Verify PostgreSQL is running for each service
docker ps | grep postgres

# Test connection to iam service (5433)
psql -h localhost -p 5433 -U traduce_user -d iam -c "SELECT 1"

# Test connection to recognition service (5434)
psql -h localhost -p 5434 -U traduce_user -d recognition -c "SELECT 1"
```

### "RabbitMQ or MongoDB not starting"

```bash
# Check RabbitMQ
docker logs traduce-rabbitmq
docker start traduce-rabbitmq

# Check MongoDB
docker logs traduce-mongodb
docker start traduce-mongodb

# Test RabbitMQ management UI
open http://localhost:15672  # user: guest, pass: guest
```

### "JWT_SECRET not configured"

```bash
# Generate one and add to backend/.env
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
JWT_SECRET=<paste the output here>
```

### "Expo development server hangs or crashes"

```bash
# Clear Expo cache
expo start --clear

# Or fully reset
rm -rf node_modules/.cache/expo
npm install
npm start
```

### "Backend migrations not applied"

```bash
# The application applies Liquibase migrations on startup
# If they fail, check logs:
docker logs traduce-postgres

# Manually run a migration (pending — no SQL tool integrated yet)
# See: backend/DB/traduce_senas/ for the migration scripts
```

---

## Utility commands

### Backend (backend/ directory)

```bash
# Build
npm run build               # Compile TypeScript to dist/

# Tests (pending — test suite not yet configured)
npm test                    # Run the backend test suite (node:test)

# Development
npm run dev                 # Start with nodemon (hot reload)

# AI/Training domain (LSC-54 dataset)
npm run ia:inspect-lsc54       # Inspect LSC-54 dataset
npm run ia:download-lsc54      # Download LSC-54 dataset
npm run ia:measure-lsc54       # Measure sign separability
npm run ia:convert-lsc54       # Convert to sign templates
npm run ia:upload-templates    # Upload templates to DB

# Production
npm run start                # Start compiled app (dist/cmd/server/main.js)
npm run build:docker        # Build Docker image: node:20-alpine
```

### Frontend (frontend/ directory)

```bash
# Development
npm start                   # Start Expo dev server
npm run android             # Start on Android emulator
npm run ios                 # Start on iOS simulator
npm run web                 # Start web (localhost:8081 after Expo tunnel)

# Build (pending — not yet configured)
expo build:android          # Build APK
expo build:ios              # Build IPA
```

---

## Useful local URLs

| Service | URL | Credentials (local only) |
|---------|-----|--------------------------|
| **API Gateway** | http://localhost:8080/api | Public entry point |
| **Gateway Health** | http://localhost:8080/health | GET (liveness) |
| **iam-service** | http://localhost:3001 | Internal port |
| **recognition-service** | http://localhost:3002 | Internal port |
| **lexicon-service** | http://localhost:3003 | Internal port |
| **analytics-service** | http://localhost:3004 | Internal port |
| **profile-service** | http://localhost:3005 | Internal port |
| Frontend (Expo web) | http://localhost:8081 | Auto-opens |
| Expo tunnel | http://localhost:19001 | Auto-opens |
| RabbitMQ Management | http://localhost:15672 | user: guest / pass: guest |
| PostgreSQL (iam) | localhost:5433 | user: traduce_user / pass: dev_password |
| PostgreSQL (recognition) | localhost:5434 | user: traduce_user / pass: dev_password |
| MongoDB | localhost:27017 | (no auth in dev) |
| API Gateway Endpoints | See `09-microservices/` | Service routing rules |

---

## Correlations

- Environment variables per environment → `10-devops/environments.md`
- CI/CD pipeline → `10-devops/README.md`
- Production troubleshooting → `09-microservices/services/XX/runbook.md`
