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
echo "=== Post-migration database inventory (read-only) ==="
"${psql[@]}" -P pager=off -v ON_ERROR_STOP=1 <<'SQL'
BEGIN TRANSACTION READ ONLY;
SELECT 'schema' AS category,nspname AS name FROM pg_namespace WHERE nspname IN ('api','private','auth','extensions') ORDER BY name;
SELECT 'object_count' AS category,n.nspname AS schema,c.relkind::text AS kind,count(*) AS total
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname IN ('api','private') AND c.relkind IN ('r','p','v','m','S','i')
GROUP BY n.nspname,c.relkind ORDER BY 2,3;
SELECT 'function_count' AS category,n.nspname AS schema,count(*) AS total
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname IN ('api','private') GROUP BY n.nspname ORDER BY 2;
SELECT 'trigger_count' AS category,n.nspname AS schema,count(*) AS total
FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='private' AND NOT t.tgisinternal GROUP BY n.nspname;
SELECT 'constraint_count' AS category,contype::text AS kind,count(*) AS total
FROM pg_constraint co JOIN pg_namespace n ON n.oid=co.connamespace WHERE n.nspname='private' GROUP BY contype ORDER BY kind;
SELECT 'RLS_DISABLED' AS finding,format('%I.%I',n.nspname,c.relname) AS relation
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='private' AND c.relkind IN ('r','p') AND NOT c.relrowsecurity ORDER BY 2;
SELECT 'RLS_NOT_FORCED' AS finding,format('%I.%I',n.nspname,c.relname) AS relation
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='private' AND c.relkind IN ('r','p') AND NOT c.relforcerowsecurity ORDER BY 2;
SELECT 'DIRECT_TABLE_PRIVILEGE' AS finding,r.rolname AS role,format('%I.%I',n.nspname,c.relname) AS relation,
concat_ws(',',CASE WHEN has_table_privilege(r.rolname,c.oid,'SELECT') THEN 'SELECT' END,
CASE WHEN has_table_privilege(r.rolname,c.oid,'INSERT') THEN 'INSERT' END,
CASE WHEN has_table_privilege(r.rolname,c.oid,'UPDATE') THEN 'UPDATE' END,
CASE WHEN has_table_privilege(r.rolname,c.oid,'DELETE') THEN 'DELETE' END) AS privileges
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
CROSS JOIN pg_roles r WHERE n.nspname='private' AND c.relkind IN ('r','p')
AND r.rolname IN ('anon','authenticated')
AND (has_table_privilege(r.rolname,c.oid,'SELECT') OR has_table_privilege(r.rolname,c.oid,'INSERT') OR has_table_privilege(r.rolname,c.oid,'UPDATE') OR has_table_privilege(r.rolname,c.oid,'DELETE'))
ORDER BY 2,3;
SELECT 'PUBLIC_API_EXECUTE' AS finding,p.oid::regprocedure AS routine
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='api' AND has_function_privilege('public',p.oid,'EXECUTE') ORDER BY 2;
SELECT 'API_ANON_EXECUTE' AS finding,p.oid::regprocedure AS routine
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='api' AND has_function_privilege('anon',p.oid,'EXECUTE') ORDER BY 2;
SELECT 'API_AUTHENTICATED_EXECUTE' AS finding,p.oid::regprocedure AS routine
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='api' AND has_function_privilege('authenticated',p.oid,'EXECUTE') ORDER BY 2;
SELECT 'UNSAFE_DEFINER_SEARCH_PATH' AS finding,p.oid::regprocedure AS routine,p.proconfig
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname IN ('api','private') AND p.prosecdef
AND (p.proconfig IS NULL OR NOT ('search_path=""'=ANY(p.proconfig)))
ORDER BY 2;
ROLLBACK;
SQL
echo "PASS: read-only catalog inventory completed; review findings before claiming security acceptance"
