#!/usr/bin/env bash
# GYMFORCE: one-command local regression batch. Never deploys or accesses hosted DB.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -z "${DATABASE_URL:-}${SUPABASE_DB_URL:-}${PGHOST:-}${PGHOSTADDR:-}${PGSERVICE:-}${PGDATABASE:-}${PGUSER:-}${PGPORT:-}${SUPABASE_URL:-}${SUPABASE_SERVICE_ROLE_KEY:-}${SUPABASE_ANON_KEY:-}${SUPABASE_PUBLISHABLE_KEY:-}${PGRST_DB_URI:-}${PGRST_JWT_SECRET:-}${SUPABASE_JWT_SECRET:-}" ]] || { echo 'BLOCKED: inherited database, JWT, or hosted service settings'; exit 2; }
[[ -d node_modules ]] || { echo 'BLOCKED: node_modules missing; no packages installed by this batch'; exit 2; }
steps=(
 'npm test'
 'npm run test:recovery-request'
 'npm run test:ingress-monitor'
 'npm run test:security'
 'npm run lint'
 'npm run typecheck'
 'npm run build'
 'bash scripts/test-synthetic-jwt-security.sh'
 'bash scripts/test-isolated-postgrest-role-authorization.sh'
 'bash scripts/rehearse-disposable-postgrest-role.sh'
 'bash scripts/test-native-edge-http-matrix.sh'
)
total=${#steps[@]}
echo "=== GYMFORCE consolidated regression: $total stages ==="
for i in "${!steps[@]}"; do
  step="${steps[$i]}"
  printf '\n=== Stage %d/%d: %s ===\n' "$((i+1))" "$total" "$step"
  if ! bash -c "$step"; then
    echo "FAIL: stage $((i+1))/$total: $step"
    echo 'No deployment or production SQL was initiated by this batch.'
    exit 1
  fi
  echo "PASS: stage $((i+1))/$total)"
done
echo "PASS: $total/$total local regression stages completed."
echo 'UNVERIFIED: PostgREST real JWT HTTP behavior, real Supabase Auth sessions, full payment HTTP integration, production migrations and deployments.'
echo 'RELEASE: NO-GO until separate integration and production gates pass.'
