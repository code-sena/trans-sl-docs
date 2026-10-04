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

Verify these ports are free before starting:

| Port | Service | Description |
|------|---------|-------------|
| 3000 | Backend API | Express backend (Traduce Señas) |
| 5433 | PostgreSQL | Relational database (traduce_senas) |
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

### Step 2: Environment variables — Backend

In the `backend/` directory:

```bash
cd backend
cp .env.example .env
```

**Required variables in `backend/.env`:**

| Variable | Description | Value for local |
|----------|-------------|----------------|
| `PORT` | Backend API port | `3000` |
| `DB_HOST` | PostgreSQL host | `localhost` |
| `DB_PORT` | PostgreSQL port | `5433` |
| `DB_USER` | PostgreSQL user | `traduce_user` |
| `DB_PASSWORD` | PostgreSQL password | `dev_password` |
| `DB_NAME` | Database name | `traduce_senas` |
| `JWT_SECRET` | Key for signing JWT | `openssl rand -base64 32` (generate one) |
| `EMAIL_USER` | SMTP user for password recovery | [optional for local] |
| `EMAIL_PASS` | SMTP password | [optional for local] |

> **NEVER** commit `.env`. It is in `.gitignore`.

### Step 3: Start PostgreSQL locally

```bash
# Start PostgreSQL container (5433 to avoid conflicts with local installs)
docker run --name traduce-postgres \
  -e POSTGRES_USER=traduce_user \
  -e POSTGRES_PASSWORD=dev_password \
  -e POSTGRES_DB=traduce_senas \
  -p 5433:5432 \
  -d postgres:15-alpine

# Verify it is running
docker ps | grep traduce-postgres
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

### Step 6: Start the Backend

```bash
cd backend
npm run dev
```

Expected output: `Servidor corriendo en el puerto 3000`

### Step 7: Install and start Frontend (React Native + Expo)

In a new terminal:

```bash
cd frontend
npm install
npm start
```

Follow Expo's prompts to run on web (`w`), Android, or iOS.

### Step 8: Verify it works

**Backend:**
```bash
curl http://localhost:3000/api/auth/register
# Should respond with 400 (missing fields) or similar, not connection error
```

**Frontend (web):**
- Open http://localhost:19001 (Expo tunnel) or http://localhost:8081 (web)
- Verify it loads the login screen

---

## Daily workflow

```bash
# At the start of the day
git pull origin dev

# Ensure Docker PostgreSQL is running
docker start traduce-postgres

# Backend
cd backend
npm install  # If package.json changed
npm run dev  # Starts on http://localhost:3000

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

### "Port 3000 or 5433 already in use"

```bash
# Windows — Find process using port
netstat -ano | findstr :3000
# Then kill it:
taskkill /PID [PID] /F

# macOS/Linux
lsof -i :3000
kill -9 [PID]
```

### "PostgreSQL container not starting"

```bash
# Check if container exists but stopped
docker ps -a | grep traduce-postgres

# Restart it
docker start traduce-postgres

# View logs
docker logs traduce-postgres

# Remove and recreate (data will be lost)
docker rm traduce-postgres
# Then re-run the docker run command from Step 3
```

### "Database connection refused"

```bash
# Verify PostgreSQL is running and healthy
docker ps | grep postgres

# Check credentials in backend/.env match the docker run command
# Defaults: user=traduce_user, password=dev_password, db=traduce_senas, port=5433

# Test connection
psql -h localhost -p 5433 -U traduce_user -d traduce_senas -c "SELECT 1"
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
| Backend API | http://localhost:3000/api | |
| Backend Health | http://localhost:3000/api/auth/register | (POST test) |
| Frontend (Expo web) | http://localhost:8081 | Auto-opens |
| Expo tunnel | http://localhost:19001 | Auto-opens |
| PostgreSQL | localhost:5433 | user: traduce_user / pass: dev_password |
| API Endpoints (real) | See `05-architecture/overview.md` | |

---

## Correlations

- Environment variables per environment → `10-devops/environments.md`
- CI/CD pipeline → `10-devops/README.md`
- Production troubleshooting → `09-microservices/services/XX/runbook.md`
