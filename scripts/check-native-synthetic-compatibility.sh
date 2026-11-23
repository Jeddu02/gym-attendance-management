#!/usr/bin/env bash
# Read-only preflight against ONLY the isolated GYMFORCE synthetic PG17 database.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -z "${DATABASE_URL:-}${SUPABASE_DB_URL:-}${PGHOST:-}${PGHOSTADDR:-}${PGSERVICE:-}${PGDATABASE:-}${PGUSER:-}${PGPORT:-}" ]] || { echo "BLOCKED: inherited database override"; exit 2; }
root="$(pwd -P)/.cache/gymforce-native-23c0b94e3cec48efa403ab08a37a4937"
socket="/tmp/gf-pg-23c0b94e"
[[ ! -L .cache && ! -L "$root" && ! -L "$socket" ]] || { echo "BLOCKED: redirected path"; exit 2; }
[[ "$(sudo -n stat -c '%U:%G:%a' "$root")" == "postgres:postgres:700" ]] || { echo "BLOCKED: unexpected cluster ownership"; exit 2; }
[[ "$(sudo -n stat -c '%U:%G:%a' "$socket")" == "postgres:postgres:700" ]] || { echo "BLOCKED: unexpected socket ownership"; exit 2; }
psql=(sudo -n /usr/sbin/runuser -u postgres -- /usr/bin/env -u PGHOST -u PGHOSTADDR -u PGPORT -u PGDATABASE -u PGUSER -u PGSERVICE -u DATABASE_URL -u SUPABASE_DB_URL /usr/lib/postgresql/17/bin/psql -X -w -v ON_ERROR_STOP=1 -h "$socket" -p 55439 -U postgres -d gymforce_integration_test)
identity="$("${psql[@]}" -At -c "select current_database() || '|' || current_user || '|' || current_setting('data_directory') || '|' || current_setting('listen_addresses') || '|' || current_setting('server_version_num')")"
[[ "$identity" == "gymforce_integration_test|postgres|$root/data||170012" ]] || { echo "BLOCKED: isolated database identity mismatch: $identity"; exit 2; }
echo "PASS: synthetic PG17 identity verified"
"${psql[@]}" -At -c "BEGIN READ ONLY; SELECT 'schema|'||nspname FROM pg_namespace WHERE nspname IN ('auth','extensions','api','private') ORDER BY 1; SELECT 'role|'||rolname FROM pg_roles WHERE rolname IN ('anon','authenticated','service_role','authenticator','supabase_auth_admin','gf_provider_admin') ORDER BY 1; SELECT 'extension|'||name||'|'||default_version FROM pg_available_extensions WHERE name IN ('pgcrypto','uuid-ossp','citext','pgjwt','pg_graphql','pg_net','pgsodium','vector') ORDER BY 1; SELECT 'auth.users|'||count(*) FROM information_schema.tables WHERE table_schema='auth' AND table_name='users'; ROLLBACK;"
echo "=== Historical SQL dependencies (source inspection only) ==="
node --input-type=module <<'NODE'
import {readFileSync,readdirSync} from 'node:fs';
const files=readdirSync('supabase/migrations').filter(x=>x.endsWith('.sql')).sort();
for(const x of files) {
 const s=readFileSync('supabase/migrations/'+x,'utf8');
 const deps=['auth.users','auth.uid(', 'auth.jwt(', 'extensions.', 'service_role', 'authenticated','anon'].filter(t=>s.includes(t));
 if(deps.length) console.log(x+': '+deps.join(', '));
}
console.log('Migration files: '+files.length);
if(files.length!==37) process.exitCode=2;
NODE
echo "PASS: read-only compatibility preflight; no schema/role/migration changes"
