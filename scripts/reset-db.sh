#!/bin/bash
# ================================================================================
# Reset Database
# Description: Complete database reset and full rebuild
# ================================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

FORCE=0
if [[ " $* " == *" --force "* ]]; then
  FORCE=1
  echo "NUCLEAR MODE: --force detected"
fi

apply_cli_overrides "$@"
print_config

if [[ "$APP_ENV" != "dev" ]] && [[ $FORCE -eq 0 ]]; then
  echo "REFUSING TO RESET $APP_ENV WITHOUT --force"
  echo "Add --force if you're ABSOLUTELY sure"
  exit 1
fi

echo "Dropping database + roles..."

SUPER_URL="$(super_url)"

psql "$SUPER_URL" -v ON_ERROR_STOP=1 <<-EOSQL
  DROP DATABASE IF EXISTS ${DB_NAME};
  DROP OWNED BY equipchain_${APP_ENV} CASCADE;
  DROP ROLE IF EXISTS equipchain_${APP_ENV};
  DROP ROLE IF EXISTS equipchain_migrator;
EOSQL

echo "Rebuilding from scratch..."
"$SCRIPT_DIR/setup-db.sh" "$@"

echo "RESET COMPLETE. Database is pristine."
