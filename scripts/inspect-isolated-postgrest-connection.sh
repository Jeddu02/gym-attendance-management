#!/usr/bin/env bash
# GYMFORCE: determine whether isolated PostgREST can connect without production credentials.
# Read-only. No password creation, role changes, HTTP server, or database writes.
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/check-local-postgrest-integration-preflight.sh >/dev/null
root="$(pwd -P)/.cache/gymforce-native-23c0b94e3cec48efa403ab08a37a4937"
socket="/tmp/gf-pg-23c0b94e"
psql=(sudo -n /usr/sbin/runuser -u postgres -- /usr/bin/env -u PGHOST -u PGHOSTADDR -u PGPORT -u PGDATABASE -u PGUSER -u PGSERVICE -u DATABASE_URL -u SUPABASE_DB_URL /usr/lib/postgresql/17/bin/psql -X -w -v ON_ERROR_STOP=1 -h "$socket" -p 55439 -U postgres -d gymforce_integration_test)
echo '=== Isolated PostgREST connection prerequisites (read-only) ==='
"${psql[@]}" -At <<'SQL'
BEGIN READ ONLY;
SELECT 'DB='||current_database()||' USER='||current_user||' DATA='||current_setting('data_directory')||' LISTEN='||current_setting('listen_addresses');
SELECT 'ROLE='||rolname||' LOGIN='||rolcanlogin||' SUPERUSER='||rolsuper||' BYPASSRLS='||rolbypassrls
FROM pg_roles WHERE rolname IN ('anon','authenticated','service_role','authenticator') ORDER BY rolname;
SELECT 'HBA='||type||' DATABASE='||array_to_string(database,',')||' USER='||array_to_string(user_name,',')||' AUTH='||auth_method
FROM pg_hba_file_rules WHERE error IS NULL AND type='local';
ROLLBACK;
SQL
echo '=== Available local PostgREST flags ==='
"$(pwd -P)/.cache/gymforce-postgrest/postgrest" --version
echo 'PASS: isolated PostgREST connection prerequisites inventoried; no credentials or data changed.'
echo 'NOTE: no PostgREST server was started and JWT/RPC HTTP integration is not yet verified.'
