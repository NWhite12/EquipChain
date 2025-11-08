#!/bin/bash

set -euo pipefail

# CI/CD mode: use dedicated superuser
if [[ "${CI:-}" == "true" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]]; then
  SUPER_USER="ci_deploy"
  # CI must provide CI_DB_SUPERUSER_PASSWORD
  if [[ -z "${CI_DB_SUPERUSER_PASSWORD:-}" ]]; then
    echo "ERROR: CI_DB_SUPERUSER_PASSWORD is required in CI" >&2
    exit 1
  fi
  SUPER_PASSWORD="$CI_DB_SUPERUSER_PASSWORD"
else
  SUPER_USER="${DB_SUPERUSER:-postgres}"
  # Local dev: DB_SUPERUSER_PASSWORD is optional (falls back to peer if empty)
  SUPER_PASSWORD="${DB_SUPERUSER_PASSWORD:-}"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Parse --force
FORCE=0
if [[ " $* " == *" --force "* ]]; then
  FORCE=1
  echo "WARNING: --force detected — will DROP database and roles if they exist"
fi


# Parse --seed
SEED=0
if [[ " $* " == *" --seed "* ]]; then
  SEED=1
  echo "INFO: --seed detected — will populate lookup tables and dev data"
fi

apply_cli_overrides "$@"
print_config
validate_config

SUPER_URL="$(super_url)"

# Generate one-time migrator password
MIGRATOR_PASS=$(openssl rand -base64 48 2>/dev/null || head /dev/urandom | LC_ALL=C tr -dc A-Za-z0-9 | head -c48)

# Use DB_PASSWORD for equipchain_${APP_ENV} if provided (prod), else random (dev)
ENV_USER_PASS="${DB_PASSWORD:-}"
if [[ -z "$ENV_USER_PASS" ]] && [[ "$APP_ENV" != "dev" ]]; then
  echo "ERROR: DB_PASSWORD must be set for non-dev environments" >&2
  exit 1
fi
ENV_USER_PASS="${ENV_USER_PASS:-$(openssl rand -base64 32)}"

echo "Setting up database: $DB_NAME (env: $APP_ENV, force: $FORCE)"

psql "$SUPER_URL" -v ON_ERROR_STOP=1 <<-EOSQL
  -- Optional: full reset
  $( ((FORCE)) && echo "DROP DATABASE IF EXISTS ${DB_NAME};" || echo "-- Skipping DROP DATABASE (use --force to nuke)" )
  $( ((FORCE)) && echo "DROP OWNED BY equipchain_${APP_ENV} CASCADE;" || true )
  $( ((FORCE)) && echo "DROP ROLE IF EXISTS equipchain_${APP_ENV};" || true )

  -- Create database
  CREATE DATABASE ${DB_NAME} TEMPLATE template0;

  -- Connect
  \c ${DB_NAME}

  -- Drop old migrator if exists
  DROP ROLE IF EXISTS equipchain_migrator;

  -- Create NOLOGIN privilege bundles (works on PostgreSQL 9.1+)
 DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${APP_OWNER_ROLE}') THEN
      CREATE ROLE ${APP_OWNER_ROLE} NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${APP_USER_ROLE}') THEN
      CREATE ROLE ${APP_USER_ROLE} NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${APP_ANALYTICS_ROLE}') THEN
      CREATE ROLE ${APP_ANALYTICS_ROLE} NOLOGIN;
    END IF;
  END \$\$;

  -- Create real environment LOGIN user
  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'equipchain_${APP_ENV}') THEN
      CREATE ROLE equipchain_${APP_ENV} LOGIN PASSWORD '${ENV_USER_PASS}';
    ELSE
      ALTER ROLE equipchain_${APP_ENV} WITH PASSWORD '${ENV_USER_PASS}';
    END IF;
  END \$\$;

  -- Create one-time migrator
  CREATE ROLE equipchain_migrator LOGIN PASSWORD '${MIGRATOR_PASS}';

  -- Grant privileges
  GRANT ${APP_USER_ROLE}      TO equipchain_${APP_ENV};
  GRANT ${APP_ANALYTICS_ROLE} TO equipchain_${APP_ENV};

  -- Dev: god mode
  DO \$\$
  BEGIN
    IF '${APP_ENV}' = 'dev' THEN
      GRANT ${APP_OWNER_ROLE} TO equipchain_${APP_ENV};
    END IF;
  END \$\$;

  -- Temporary: give migrator full power
  GRANT ${APP_OWNER_ROLE} TO equipchain_migrator;

  -- Schema + ownership
  CREATE SCHEMA IF NOT EXISTS ${APP_SCHEMA} AUTHORIZATION ${APP_OWNER_ROLE};
  ALTER SCHEMA ${APP_SCHEMA} OWNER TO ${APP_OWNER_ROLE};

  -- Usage
  GRANT USAGE ON SCHEMA ${APP_SCHEMA} TO ${APP_USER_ROLE}, ${APP_ANALYTICS_ROLE}, equipchain_migrator;

  -- Default privileges (future objects)
  ALTER DEFAULT PRIVILEGES FOR ROLE ${APP_OWNER_ROLE} IN SCHEMA ${APP_SCHEMA}
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ${APP_USER_ROLE};
  ALTER DEFAULT PRIVILEGES FOR ROLE ${APP_OWNER_ROLE} IN SCHEMA ${APP_SCHEMA}
    GRANT SELECT ON TABLES TO ${APP_ANALYTICS_ROLE};
  ALTER DEFAULT PRIVILEGES FOR ROLE ${APP_OWNER_ROLE} IN SCHEMA ${APP_SCHEMA}
    GRANT USAGE, SELECT ON SEQUENCES TO ${APP_USER_ROLE}, ${APP_ANALYTICS_ROLE};
  -- Lock down public
  REVOKE CREATE ON SCHEMA public FROM PUBLIC;
  ALTER DEFAULT PRIVILEGES REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

  -- Search path
  ALTER DATABASE ${DB_NAME} SET search_path TO ${APP_SCHEMA}, public;
  ALTER ROLE equipchain_${APP_ENV} SET search_path TO ${APP_SCHEMA}, public;

  -- Extensions
  CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
  CREATE EXTENSION IF NOT EXISTS "pgcrypto";
EOSQL

echo "Running migrations as equipchain_migrator..."
export DB_USER="equipchain_migrator"
export DB_PASSWORD="$MIGRATOR_PASS"
export PGPASSWORD="$MIGRATOR_PASS"


# Build migration arguments
MIGRATE_ARGS=("--stage" "$APP_ENV")
if [ $SEED -eq 1 ]; then
  MIGRATE_ARGS+=("--seed")
fi
"$SCRIPT_DIR/migrate.sh" "${MIGRATE_ARGS[@]}"

psql "$SUPER_URL" -v ON_ERROR_STOP=1 <<-EOSQL
\c ${DB_NAME}
-- Grant permissions on ALL EXISTING tables created by migrations
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA ${APP_SCHEMA} TO ${APP_USER_ROLE};
GRANT SELECT ON ALL TABLES IN SCHEMA ${APP_SCHEMA} TO ${APP_ANALYTICS_ROLE};

-- Grant permissions on ALL EXISTING sequences (for auto-increment IDs)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA ${APP_SCHEMA} TO ${APP_USER_ROLE};
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA ${APP_SCHEMA} TO ${APP_ANALYTICS_ROLE}; 

-- Grant function execution (for check_and_update_lockout, etc.)
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA ${APP_SCHEMA} TO ${APP_USER_ROLE};
EOSQL

echo "Cleaning up: destroying equipchain_migrator..."
psql "$SUPER_URL" -c "REVOKE ${APP_OWNER_ROLE} FROM equipchain_migrator;" 2>/dev/null || true
psql "$SUPER_URL" -c "DROP ROLE equipchain_migrator;" 2>/dev/null || true

echo ""
echo "SUCCESS! Database ready and secure."
echo ""
echo "Connection strings:"
echo "  Runtime (API):"
echo "    postgres://equipchain_${APP_ENV}:[HIDDEN]@${DB_HOST}:${DB_PORT}/${DB_NAME}?schema=${APP_SCHEMA}"
echo ""
if [[ "$APP_ENV" = "dev" ]]; then
  echo "  Dev god mode active — equipchain_dev has app_owner"
else
  echo "  Production mode — equipchain_${APP_ENV} has only app_user + app_analytics"
  echo "  Store this password securely (Vault/Render Secrets): ${ENV_USER_PASS}"
fi
echo ""
echo "Idempotent: safe to run again. Use --force to nuke everything."
