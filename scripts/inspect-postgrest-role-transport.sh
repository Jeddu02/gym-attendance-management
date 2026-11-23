#!/usr/bin/env bash
# Read-only PostgREST transport/role preflight against GYMFORCE's isolated PG17 fixture.
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/inspect-isolated-postgrest-connection.sh >/dev/null
socket="/tmp/gf-pg-23c0b94e"
psql=(sudo -n /usr/sbin/runuser -u postgres -- /usr/bin/env -u PGHOST -u PGHOSTADDR -u PGPORT -u PGDATABASE -u PGUSER -u PGSERVICE -u DATABASE_URL -u SUPABASE_DB_URL /usr/lib/postgresql/17/bin/psql -X -w -v ON_ERROR_STOP=1 -h "$socket" -p 55439 -U postgres -d gymforce_integration_test)
echo '=== Isolated PostgREST role membership and connection permissions ==='
"${psql[@]}" -P pager=off <<'SQL'
BEGIN READ ONLY;
SELECT r.rolname, r.rolcanlogin, r.rolinherit, r.rolsuper,
       has_database_privilege(r.oid,current_database(),'CONNECT') AS db_connect
FROM pg_roles r WHERE r.rolname IN ('postgres','authenticator','anon','authenticated','service_role')
ORDER BY r.rolname;
SELECT member.rolname AS member, role.rolname AS granted_role,
       am.inherit_option, am.set_option
FROM pg_auth_members am
JOIN pg_roles member ON member.oid=am.member
JOIN pg_roles role ON role.oid=am.roleid
WHERE member.rolname IN ('postgres','authenticator') AND role.rolname IN ('anon','authenticated','service_role')
ORDER BY member.rolname,role.rolname;
SELECT 'socket_dir='||current_setting('unix_socket_directories')||
       ' port='||current_setting('port')||
       ' hba='||current_setting('hba_file');
ROLLBACK;
SQL
echo '=== Isolated socket and PostgREST executable ownership ==='
stat -c '%U:%G %a %n' "$socket" "$(pwd -P)/.cache/gymforce-postgrest/postgrest"
echo 'PASS: read-only role and transport preflight complete.'
echo 'NOTE: no role changes, no server startup, no synthetic JWT issuance, and no production access.'
