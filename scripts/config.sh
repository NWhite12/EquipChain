#!/bin/bash

# ================================================================================
# Environment Configuration
# Description: 4-layer hierarchy for database configuration
# ================================================================================

set -euo pipefail

# ================================================================================
# Layer 0: Application Defaults
# ================================================================================

# Database Configuration
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-equipchain}"
DB_SSL_MODE="${DB_SSL_MODE:-disable}"
APP_ENV="${APP_ENV:-dev}"

# Becomes the password for equipchain_prod / equipchain_dev / etc.
DB_PASSWORD="${DB_PASSWORD:-}"

# Superuser for setup (never used by app)
DB_SUPERUSER="${DB_SUPERUSER:-postgres}"
DB_SUPERUSER_PASSWORD="${DB_SUPERUSER_PASSWORD:-}"

# App Roles
APP_OWNER_ROLE="equipchain_owner"
APP_USER_ROLE="equipchain_app"
APP_ANALYTICS_ROLE="equipchain_analytics"
APP_SCHEMA="equipchain"

# ================================================================================
# Config Array
# ================================================================================
config_vars=(DB_HOST DB_PORT DB_NAME DB_PASSWORD DB_SSL_MODE DB_SUPERUSER DB_SUPERUSER_PASSWORD)

# ================================================================================
# Layer 1: Global Environment Variables (EQUIPCHAIN_*)
# Overrides Defaults
# ================================================================================

for var in "${config_vars[@]}"; do
  global_var="EQUIPCHAIN_$var"
  if [ -v "$global_var" ]; then
    eval "$var=\${$global_var}"
  fi
done

# ================================================================================
# Layer 2: Stage-Specific Prefix Variables EQUIPCHAIN_[STAGE]_* (e.g. EQUIPCHAIN_DEV_DB_HOST)
# Overrides Defaults and Global Environment Variables
# ================================================================================

# Determine stage for Prefix
STAGE="${APP_ENV}"
STAGE_UPPER=$(echo "$STAGE" | tr '[:lower:]' '[:upper:]')
STAGE_PREFIX="EQUIPCHAIN_${STAGE_UPPER}_"

# Gets stage-specific variables
get_stage_var() {
  local var_name="$1"
  local full_var="${STAGE_PREFIX}${var_name}"
  if [ -v "$full_var" ]; then
    echo "${!full_var}"
    return 0
  else
    return 1
  fi
}

# Apply stage-sepcific override
for var in "${config_vars[@]}"; do
  suffix="${var#DB_}"
  if value=$(get_stage_var "$suffix"); then
    eval "$var=\$value"
  fi
done

# ================================================================================
# Layer 3: CLI / Runtime Overrides (highest priority)
# ================================================================================
apply_cli_overrides() {
  local override
  for override in "$@"; do
    # Only allow known config keys
    case "$override" in
      DB_HOST=*|DB_PORT=*|DB_NAME=*|DB_PASSWORD=*|DB_SSL_MODE=*|APP_ENV=*|DB_SUPERUSER=*|DB_SUPERUSER_PASSWORD=*)
        # Extract key and value
        local key="${override%%=*}"
        local val="${override#*=}"
        eval "$key=\"\$val\""
        ;;
      *)
        echo "WARNING: Ignored unknown override: $override" >&2
        ;;
    esac
  done
}

# ================================================================================
# Helper Functions
# ================================================================================

print_config() {
  echo "=== EquipChain Database Configuration ==="
  echo "Environment: $APP_ENV"
  echo "Host:        $DB_HOST"
  echo "Port:        $DB_PORT"
  echo "Database:    $DB_NAME"
  echo "Schema:      $APP_SCHEMA"
  echo "Owner Role:  $APP_OWNER_ROLE"
  echo "App Role:    $APP_USER_ROLE"
  echo "SSL Mode:    $DB_SSL_MODE"
  echo "========================================="
}

validate_config() {
  local errors=0
  for var in DB_HOST DB_PORT DB_NAME; do
    if [ -z "${!var}" ]; then
      echo "ERROR: $var is not set" >&2
      ((errors++))
    fi
  done
  if [ "$errors" -gt 0 ]; then return 1; fi
  return 0
}

build_url() {
  local user="$1"
  local pass="${2:-}"
  local db="${3:-$DB_NAME}"
  local extra="${4:-}"
  local pass_part=""
  [[ -n "$pass" ]] && pass_part=":$pass"
  echo "postgres://$user$pass_part@${DB_HOST}:${DB_PORT}/$db?sslmode=$DB_SSL_MODE$extra"
}

super_url() {
  [[ -z "$DB_SUPERUSER_PASSWORD" ]] && echo "postgres://$DB_SUPERUSER@${DB_HOST}:${DB_PORT}/postgres" || \
    echo "postgres://$DB_SUPERUSER:$DB_SUPERUSER_PASSWORD@${DB_HOST}:${DB_PORT}/postgres"
}

export DB_HOST DB_PORT DB_NAME DB_PASSWORD DB_SSL_MODE APP_ENV
export DB_SUPERUSER DB_SUPERUSER_PASSWORD APP_SCHEMA APP_OWNER_ROLE APP_USER_ROLE APP_ANALYTICS_ROLE
export -f print_config validate_config build_url super_url apply_cli_overrides
