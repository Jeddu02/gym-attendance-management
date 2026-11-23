#!/usr/bin/env bash
# GYMFORCE Batch B — native integration dependency gate (read-only).
# Fail closed before any SQL execution or service startup.
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/check-native-postgres-local.sh
node scripts/recovery/validate-source.mjs
echo "=== Local native prerequisites ==="
for tool in deno postgrest; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "BLOCKED: $tool unavailable; native HTTP integration cannot start"
  else
    echo "FOUND: $tool"
    "$tool" --version | head -n 3
  fi
done
echo "=== Supabase compatibility prerequisites ==="
psql_bin=/usr/lib/postgresql/17/bin/psql
sql="SELECT 'schema|'||nspname FROM pg_namespace WHERE nspname IN ('auth','extensions','api','private') ORDER BY nspname;
SELECT 'role|'||rolname FROM pg_roles WHERE rolname IN ('anon','authenticated','service_role','authenticator','supabase_auth_admin','gf_provider_admin') ORDER BY rolname;
SELECT 'extension|'||name FROM pg_available_extensions WHERE name IN ('pgcrypto','uuid-ossp','citext','pgjwt','pg_graphql','pg_net','pgsodium','vector') ORDER BY name;"
sudo -n /usr/sbin/runuser -u postgres -- /usr/bin/env -u PGHOST -u PGHOSTADDR -u PGPORT -u PGDATABASE -u PGUSER -u PGSERVICE -u DATABASE_URL -u SUPABASE_DB_URL "$psql_bin" -X -w -v ON_ERROR_STOP=1 -At -d postgres -c "$sql"
echo "=== Migration source prerequisites ==="
node --input-type=module <<'NODE'
import { readFileSync,readdirSync } from 'node:fs';
const files=readdirSync('supabase/migrations').filter(x=>x.endsWith('.sql')).sort();
const text=files.map(x=>readFileSync('supabase/migrations/'+x,'utf8')).join('\n');
for(const pattern of [/\bauth\.users\b/gi,/\bauth\.uid\s*\(/gi,/\bextensions\./gi,/\bservice_role\b/gi,/\bauthenticated\b/gi,/\banon\b/gi]){
  console.log(pattern.source+': '+[...text.matchAll(pattern)].length+' references');
}
console.log('Historical migration files: '+files.length);
if(files.length!==37) process.exitCode=2;
NODE
echo "BATCH B GATE: read-only inventory finished; no database/role created, no migrations executed, no services started."
