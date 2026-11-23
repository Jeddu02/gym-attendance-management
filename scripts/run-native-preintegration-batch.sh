#!/usr/bin/env bash
# C3.5 -> C4 preparation batch. All actions are read-only.
# No Docker, package installation, DB/role creation, SQL migration or network deployment.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -n "${DATABASE_URL:-}${SUPABASE_DB_URL:-}${PGHOST:-}${PGHOSTADDR:-}${PGSERVICE:-}${PGDATABASE:-}${PGUSER:-}${PGPORT:-}" ]]; then
  echo "BLOCKED: database connection override detected"; exit 2
fi
echo "=== C3.5: local database compatibility ==="
bash scripts/check-native-c35-inventory.sh
echo "=== Historical migration and runtime source fingerprints ==="
node scripts/recovery/validate-source.mjs
echo "=== Production diagnostic SQL validation (offline) ==="
node docs/production-preflight/sql-editor/validate.cjs
echo "=== C3: frontend, static security and tests ==="
bash scripts/check-native-c3.sh
echo "=== Backend runtime availability ==="
for binary in postgrest deno; do
  if command -v "$binary" >/dev/null 2>&1; then
    echo "PRESENT: $binary"
  else
    echo "BLOCKED for live backend integration: $binary not installed"
  fi
done
echo "PASS: read-only C3.5-to-C4 preparation batch; live DB migration/RLS/Auth/HTTP tests NOT performed"
