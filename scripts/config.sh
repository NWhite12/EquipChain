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
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="equipchain"
DB_USER="equipchain_dev"
DB_PASSWORD="1234"
DB_SSL_MODE="disabled"

# Application Environment
APP_ENV="dev"

# ================================================================================
# Config Array
# ================================================================================
config_vars=(DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD DB_SSL_MODE)

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
# LAYER 3: CLI / RUNTIME OVERRIDES (highest priority)
# ================================================================================
apply_cli_overrides() {
  local override
  for override in "$@"; do
    # Only allow known config keys
    case "$override" in
      DB_HOST=*|DB_PORT=*|DB_NAME=*|DB_USER=*|DB_PASSWORD=*|DB_SSL_MODE=*|APP_ENV=*)
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
  echo "Stage: $APP_ENV"
  echo "Host: $DB_HOST"
  echo "Port: $DB_PORT"
  echo "Database: $DB_NAME"
  echo "User: $DB_USER"
  echo "SSL Mode: $DB_SSL_MODE"
  echo "========================================"
}

validate_config() {
 local errors=0

  if [ -z "$DB_HOST" ]; then
    echo "ERROR: DB_HOST is not set" >&2
    ((errors++))
  fi

  if [ -z "$DB_PORT" ]; then
    echo "ERROR: DB_PORT is not set" >&2
    ((errors++))
  elif ! [[ "$DB_PORT" =~ ^[0-9]+$ ]]; then
    echo "ERROR: DB_PORT must be a number (got: $DB_PORT)" >&2
    ((errors++))
  fi

  if [ -z "$DB_NAME" ]; then
    echo "ERROR: DB_NAME is not set" >&2
    ((errors++))
  fi

  if [ -z "$DB_USER" ]; then
    echo "ERROR: DB_USER is not set" >&2
    ((errors++))
  fi

  if [ -z "$DB_PASSWORD" ]; then
    echo "WARNING: DB_PASSWORD is empty" >&2
  fi

  if [ "$errors" -gt 0 ]; then
    return 1
  fi

  return 0
}

build_psql_command(){
  local psql_cmd="psql"

  if [ -n "$DB_HOST" ]; then
    psql_cmd="$psql_cmd -h $DB_HOST"
  fi

  if [ -n "$DB_PORT" ]; then
    psql_cmd="$psql_cmd -p $DB_PORT"
  fi

  if [ -n "$DB_USER" ]; then
    psql_cmd="$psql_cmd -U $DB_USER"
  fi

  if [ -n "$DB_NAME" ]; then
    psql_cmd="$psql_cmd -d $DB_NAME"
  fi

  echo "$psql_cmd"
}

export DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD DB_SSL_MODE APP_ENV
export -f print_config validate_config build_psql_command
