#!/usr/bin/env bash
# GYMFORCE C3.5 — read-only native PostgreSQL compatibility inventory.
# No databases/roles created, migrations applied, Docker or external connections.
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/check-native-postgres-local.sh
psql_bin=/usr/lib/postgresql/17/bin/psql
sql="SELECT 'extension|' || name || '|' || default_version FROM pg_available_extensions WHERE name IN ('pgcrypto','uuid-ossp','pgjwt','pg_graphql','pg_net','pgsodium','vector','citext') ORDER BY name;
SELECT 'role|' || rolname FROM pg_roles WHERE rolname IN ('anon','authenticated','service_role','authenticator','supabase_auth_admin','gf_provider_admin') ORDER BY rolname;
SELECT 'database|' || datname FROM pg_database WHERE datname LIKE 'gymforce%' ORDER BY datname;"
echo "Read-only local extension/role/database inventory:"
sudo -n /usr/sbin/runuser -u postgres -- /usr/bin/env -u PGHOST -u PGHOSTADDR -u PGPORT -u PGDATABASE -u PGUSER -u PGSERVICE -u DATABASE_URL -u SUPABASE_DB_URL "$psql_bin" -X -w -v ON_ERROR_STOP=1 -At -d postgres -c "$sql"
echo "Historical migration inventory (file count only):"
find supabase/migrations -maxdepth 1 -type f -name '*.sql' | wc -l
echo "Native backend binaries:"
for bin in postgrest deno; do
  if command -v "$bin" >/dev/null 2>&1; then "$bin" --version | head -n 2; else echo "$bin: not installed"; fi
done
echo "PASS: C3.5 read-only compatibility inventory completed; runtime migrations still UNVERIFIED"
