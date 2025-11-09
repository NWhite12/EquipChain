#!/bin/bash

# ================================================================================
# EquipChain Database Migration Runner
# Description: 
# ================================================================================

set -euo pipefail

# Ensure we're running from setup-db.sh (not standalone)
if [[ "$DB_USER" != "equipchain_migrator" ]] && [[ -z "${DB_PASSWORD:-}" ]]; then
  echo "ERROR: migrate.sh must be run from setup-db.sh" >&2
  echo "       Do not run migrate.sh directly in production." >&2
  exit 1
fi

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MIGRATIONS_DIR="$PROJECT_ROOT/backend/migrations"

# ================================================================================
# Layer 3: Parse CLI Flags (highest priority)
# These override all previous layers
# ================================================================================

# Flags to apply after sourcing config.sh
OVERRIDE_HOST=""
OVERRIDE_PORT=""
OVERRIDE_NAME=""
OVERRIDE_SSL_MODE=""
OVERRIDE_STAGE=""
SHOW_HELP=0
SHOW_CONFIG=0
DRY_RUN=0
SEED_DATA=0

# Parse CLI arguments
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --host)
        OVERRIDE_HOST="$2"
        shift 2
        ;;
      --port)
        OVERRIDE_PORT="$2"
        shift 2
        ;;
      --db|--database)
        OVERRIDE_NAME="$2"
        shift 2
        ;;
      --ssl-mode)
        OVERRIDE_SSL_MODE="$2"
        shift 2
        ;;
      --stage)
        OVERRIDE_STAGE="$2"
        shift 2
        ;;
      --config)
        SHOW_CONFIG=1
        shift
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --seed)
        SEED_DATA=1
        shift
        ;;
      --help|-h)
        SHOW_HELP=1
        shift
        ;;
      --user|--password)
        echo "WARNING: $1 is ignored. migrate.sh only runs as equipchain_migrator" >&2
        shift 2
        ;;
      *)
        echo "ERROR: Unknown option: $1" >&2
        echo "Use --help for usage information" >&2
        exit 1
        ;;
    esac
  done
}


# Show help message
show_help() {
  cat << 'HELP'
EquipChain Database Migration Runner

USAGE:
  ./migrate.sh [OPTIONS]

OPTIONS:
  --host HOST              Override database host (Layer 3)
  --port PORT              Override database port (Layer 3)
  --db DATABASE            Override database name (Layer 3)
  --user, --password       Ignored (migrate.sh uses ephemeral equipchain_migrator)
  --ssl-mode MODE          Override SSL mode (Layer 3)
  --stage STAGE            Use EQUIPCHAIN_[STAGE]_* variables (Layer 2)
  --config                 Show configuration and exit
  --dry-run                Show what would be executed without running
  --seed                   Populate lookup tables and sample dev data
  --help, -h               Show this help message

ENVIRONMENT VARIABLES (Layers 1 & 2):
  Layer 1 (Global):
    EQUIPCHAIN_DB_HOST
    EQUIPCHAIN_DB_PORT
    EQUIPCHAIN_DB_NAME
    EQUIPCHAIN_DB_SSL_MODE
    EQUIPCHAIN_APP_ENV

  Layer 2 (Stage-specific):
    EQUIPCHAIN_DEV_DB_HOST
    EQUIPCHAIN_STAGING_DB_HOST
    EQUIPCHAIN_PROD_DB_HOST
    (and *_PORT, *_NAME, *_SSL_MODE)

EXAMPLES:
  # Use defaults (Layer 0)
  ./migrate.sh

  # Use development stage config (Layer 2)
  ./migrate.sh --stage dev

  # Override specific host (Layer 3)
  ./migrate.sh --host myhost.com --port 5433

  # Dry run to see what would execute
  ./migrate.sh --dry-run

  # Show current configuration
  ./migrate.sh --config

LAYER PRIORITY (highest to lowest):
  Layer 3: CLI flags (--host, --port, etc.)
  Layer 2: Stage prefix (EQUIPCHAIN_[STAGE]_*)
  Layer 1: Global vars (EQUIPCHAIN_DB_HOST, etc.)
  Layer 0: Application defaults
HELP
}

# ================================================================================
# Source Configuration Loading Script
# ================================================================================
#
# Load config (Layers 0,1,2)
source "$SCRIPT_DIR/config.sh"

# ================================================================================
# Parse Arguments (Layer 3 - highest priority)
# ================================================================================

parse_arguments "$@"

echo "$OVERRIDE_STAGE"

# Apply APP_ENV override to avoid setting and then overriding
APP_ENV="${OVERRIDE_STAGE:-dev}"

# Build CLI overrides (Layer 3)
overrides=()
[ -n "$OVERRIDE_HOST" ] && overrides+=("DB_HOST=$OVERRIDE_HOST")
[ -n "$OVERRIDE_PORT" ] && overrides+=("DB_PORT=$OVERRIDE_PORT")
[ -n "$OVERRIDE_NAME" ] && overrides+=("DB_NAME=$OVERRIDE_NAME")
[ -n "$OVERRIDE_SSL_MODE" ] && overrides+=("DB_SSL_MODE=$OVERRIDE_SSL_MODE")


# Apply CLI overrides (Layer 3)
apply_cli_overrides "${overrides[@]}"

# ================================================================================
# Validate And Show Configuration
# ================================================================================

# Show help if requested
if [ $SHOW_HELP -eq 1 ]; then
  show_help
  exit 0
fi

# Validate configuration
if ! validate_config; then 
  echo "" >&2
  echo "Configuration validation failed. Use --config to debug." >&2
  exit 1
fi

# Show config if requested or in dry-run mode
if [ $SHOW_CONFIG -eq 1 ] || [ $DRY_RUN -eq 1 ]; then 
  print_config
  echo ""
fi

# ================================================================================
# Build Migration File List
# ================================================================================

declare -a MIGRATION_FILES=(
  "$MIGRATIONS_DIR/001_create_core_tables.sql"
  "$MIGRATIONS_DIR/002_add_foreign_keys_and_constraints.sql"
)


# Add seed data if --seed flag was used
if [ $SEED_DATA -eq 1 ]; then
  MIGRATION_FILES+=("$MIGRATIONS_DIR/003_seed_data.sql")
fi

for file in "${MIGRATION_FILES[@]}"; do 
  if [ ! -f "$file" ]; then
    echo "ERROR: Migration file not found: $file" >&2
    exit 1
  fi
done

# ================================================================================
# Run Migrations
# ================================================================================

echo "Starting database migrations..."
echo ""

# Export passsword for psql
export PGPASSWORD="$DB_PASSWORD"

for migration_file in "${MIGRATION_FILES[@]}"; do 
  migration_name=$(basename "$migration_file")

  psql_cmd="psql -h $DB_HOST -p $DB_PORT -U  equipchain_migrator -d $DB_NAME -v search_path=$APP_SCHEMA -f $migration_file"

  if [ $DRY_RUN -eq 1 ]; then
    echo "[DRY RUN] Would execute:"
    echo " $psql_cmd"
    echo ""
  else
    echo "Running: $migration_name"
    
    if $psql_cmd 2>&1 | grep -q "ERROR"; then
      echo "Migration failed: $migration_name" >&2
      exit 1
    else
      echo "Completed: $migration_name"
      echo ""
    fi
  fi  
done

unset PGPASSWORD

if [ $DRY_RUN -eq 1 ]; then 
  echo "[DRY RUN] No migrations were actually executed"
else 
  echo "All migrations completed successfully!"
fi

exit 0
