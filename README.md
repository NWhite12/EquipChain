# EquipChain

Blockchain-verified equipment maintenance tracking. EquipChain creates immutable, timestamped proof that maintenance happened—legally defensible, instantly verifiable, and impossible to forge.

Technicians scan a QR code on equipment, take photos (before/during/after), and submit a maintenance record. The Go backend uploads photos to IPFS and writes cryptographic proof to the Solana blockchain at $0.00025 per record. Insurance companies and auditors can verify any record in seconds without relying on paper logs or mutable databases.

**Stack:** React 19 + Vite (frontend) · Go + Gin (backend) · PostgreSQL · Solana · IPFS

---

## Installation

### Prerequisites

- Node.js 18+
- Go 1.21+
- PostgreSQL 15+

### 1. Clone & configure environment

```bash
git clone <repo-url>
cd equipchain
cp .env.example .env.local
```

Edit `.env.local` with your database credentials:

```bash
EQUIPCHAIN_DB_HOST=localhost
EQUIPCHAIN_DB_PORT=5432
EQUIPCHAIN_DB_NAME=equipchain_dev
EQUIPCHAIN_DB_USER=postgres
EQUIPCHAIN_DB_PASSWORD=yourpassword
EQUIPCHAIN_DB_SSL_MODE=disable
EQUIPCHAIN_APP_ENV=dev
```

### 2. Database setup

Database creation and migrations are handled by shell scripts in `scripts/`.

```bash
# Create the database, roles, schema, and run all migrations
./scripts/setup-db.sh

# Optionally seed lookup tables and sample dev data
./scripts/setup-db.sh --seed
```

### 3. Backend

```bash
cd backend

# Download Go dependencies
go mod download

# Start the API server (http://localhost:8080)
go run cmd/server/main.go
```

### 4. Frontend

```bash
cd frontend

# Install dependencies
npm install

# Start the dev server (http://localhost:5173)
npm run dev
```

---

## Scripts

### Frontend (`frontend/`)

| Script | Command | Description |
|--------|---------|-------------|
| `dev` | `npm run dev` | Start Vite dev server on `http://localhost:5173` with hot module replacement |
| `build` | `npm run build` | Compile and bundle for production output to `dist/` |
| `preview` | `npm run preview` | Serve the production build locally for testing before deploy |
| `lint` | `npm run lint` | Run ESLint across all source files |

### Backend (`backend/`)

| Command | Description |
|---------|-------------|
| `go run cmd/server/main.go` | Start the API server on `:8080` |
| `go mod download` | Download all Go module dependencies |
| `go test ./...` | Run the full test suite |
| `go build -o equipchain ./cmd/server` | Compile a production binary |

### Database Scripts (`scripts/`)

All database operations use shell scripts that call `psql` directly. Migrations are plain `.sql` files located in `backend/migrations/`.

#### `setup-db.sh`

Full database provisioning. Creates the database, roles, schema, grants permissions, and runs all migrations. This is the primary entry point for database setup.

```bash
# Standard setup
./scripts/setup-db.sh

# Include seed data (lookup tables + sample dev records)
./scripts/setup-db.sh --seed

# Drop and fully recreate (required for non-dev environments)
./scripts/setup-db.sh --force
./scripts/setup-db.sh --force --seed
```

#### `migrate.sh`

Runs SQL migration files as the `equipchain_migrator` role. Called internally by `setup-db.sh`—do not run standalone in production.

```bash
# Run migrations for a specific stage
./scripts/migrate.sh --stage dev

# Include seed data
./scripts/migrate.sh --stage dev --seed

# Dry run: show what would execute without running it
./scripts/migrate.sh --dry-run

# Show resolved configuration
./scripts/migrate.sh --config

# Override specific connection values (Layer 3)
./scripts/migrate.sh --host myhost.com --port 5433 --db equipchain_staging
```

#### `reset-db.sh`

Complete teardown and rebuild. Drops the database and all roles, then calls `setup-db.sh` to rebuild from scratch. Requires `--force` on any non-dev environment.

```bash
# Dev reset (no --force required)
./scripts/reset-db.sh

# Non-dev reset (requires explicit --force)
./scripts/reset-db.sh --force
```

#### `config.sh`

Sourced by the other scripts. Not called directly. Implements the four-layer configuration hierarchy.

### Environment Configuration

Scripts resolve database config through four layers, highest priority wins:

| Layer | Source | Example |
|-------|--------|---------|
| 0 | Hardcoded defaults | `DB_HOST=localhost` |
| 1 | Global env vars (`EQUIPCHAIN_*`) | `EQUIPCHAIN_DB_HOST=myhost` |
| 2 | Stage-specific vars (`EQUIPCHAIN_[STAGE]_*`) | `EQUIPCHAIN_PROD_DB_HOST=prod.db.com` |
| 3 | CLI flags | `./scripts/migrate.sh --host myhost` |

---

## What's Been Completed

### Backend

- **Authentication** — JWT-based register and login endpoints, bcrypt password hashing (cost 12), account lockout after repeated failed attempts (OWASP compliant)
- **Equipment CRUD** — Full create, read, update (PATCH), and delete endpoints with serial number uniqueness enforced per organization
- **Request validation** — Hardened validators for serial number, make, model, status ID, and date fields
- **Database schema** — PostgreSQL migrations for `organizations`, `users`, `roles`, `equipment`, and `equipment_status_lookup` tables including foreign keys, constraints, and seed data
- **Database scripts** — Shell-based provisioning with ephemeral migrator role, role-based access control, and four-layer config system
- **Middleware** — JWT auth middleware, CORS, and structured request logging via Zap
- **Service layer** — Business logic cleanly separated from HTTP handlers using repository and service patterns
- **Configuration** — Viper-based config supporting dev/staging/prod environments

### Frontend

- **Routing & auth** — React Router v7 setup with protected routes, auth context, and JWT storage/refresh
- **UI component library** — Button, Modal, Badge, Spinner, Table, Pagination, EmptyState, SkeletonLoader (all with variants)
- **Form components** — `FormInput`, `FormSelect`, `FormDateInput` with error and hint support
- **Equipment interface** — Equipment list with filters (status, location, search), create/edit modal, and detail panel
- **Dashboard structure** — `StatCard`, `EquipmentStatusChart`, `EquipmentTrendChart`, and grid layout via Recharts
- **Custom hooks** — `useAuth`, `useDebounce`, `useLocalStorage`, `usePagination`, `useEquipmentFilters`, `useEquipmentModal`
- **API service layer** — Axios client with auth header injection, 401 auto-redirect, and service modules for auth and equipment
- **State management** — Zustand store structure scaffolded for auth, equipment, and UI state

### API Endpoints (Implemented)

```
POST   /api/auth/register
POST   /api/auth/login

GET    /api/equipment
POST   /api/equipment
GET    /api/equipment/:id
PATCH  /api/equipment/:id
DELETE /api/equipment/:id

GET    /api/health
```

### Not Yet Started

- Maintenance record management
- QR code generation and scanning
- Photo upload (IPFS)
- Blockchain integration (Solana)
- Multi-signature support
- Offline / PWA mode
- Email notifications
- PDF export for OSHA compliance
