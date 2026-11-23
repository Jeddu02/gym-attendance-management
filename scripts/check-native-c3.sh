#!/usr/bin/env bash
# C3 native readiness smoke suite. Read-only; no Docker, migration, deployment, or backend provisioning.
set -euo pipefail
cd "$(dirname "$0")/.."
echo "[1/5] Native PostgreSQL local identity"
bash scripts/check-native-postgres-local.sh
echo "[2/5] Codespaces configuration"
npm run check:codespaces
echo "[3/5] Lint and TypeScript"
npm run lint
npm run typecheck
echo "[4/5] Source security and Node tests"
npm run test:security
node --test tests/*.test.mjs
echo "[5/5] Production frontend build"
npm run build
echo "PASS: C3 native smoke checks (database migrations, RLS runtime, Auth and PostgREST remain UNVERIFIED)"
