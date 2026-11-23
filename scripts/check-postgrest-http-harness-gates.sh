#!/usr/bin/env bash
# GYMFORCE: fail-closed PostgREST HTTP harness readiness gate.
# Read-only: does not create login roles, JWT secrets, start a listener, or mutate SQL.
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/inspect-postgrest-role-transport.sh >/dev/null
[[ -z "${DATABASE_URL:-}${SUPABASE_DB_URL:-}${PGHOST:-}${PGHOSTADDR:-}${PGSERVICE:-}${PGDATABASE:-}${PGUSER:-}${PGPORT:-}${SUPABASE_SERVICE_ROLE_KEY:-}${PGRST_DB_URI:-}${PGRST_JWT_SECRET:-}" ]] || { echo 'BLOCKED: inherited database or service credentials'; exit 2; }
socket="/tmp/gf-pg-23c0b94e"
psql=(sudo -n /usr/sbin/runuser -u postgres -- /usr/bin/env -u PGHOST -u PGHOSTADDR -u PGPORT -u PGDATABASE -u PGUSER -u PGSERVICE -u DATABASE_URL -u SUPABASE_DB_URL /usr/lib/postgresql/17/bin/psql -X -w -v ON_ERROR_STOP=1 -h "$socket" -p 55439 -U postgres -d gymforce_integration_test)
echo '=== HTTP harness security gates ==='
"${psql[@]}" -At <<'SQL'
BEGIN READ ONLY;
DO $$
DECLARE
  authenticator_login boolean;
  role_memberships integer;
  api_usage boolean;
BEGIN
  SELECT rolcanlogin INTO authenticator_login FROM pg_roles WHERE rolname='authenticator';
  SELECT count(*) INTO role_memberships FROM pg_auth_members am
    JOIN pg_roles m ON m.oid=am.member JOIN pg_roles r ON r.oid=am.roleid
    WHERE m.rolname='authenticator' AND r.rolname IN ('anon','authenticated','service_role') AND am.set_option;
  SELECT has_schema_privilege('anon','api','USAGE') INTO api_usage;
  RAISE NOTICE 'authenticator_login=%; permitted_role_switch_memberships=%; anon_api_schema_usage=%',
    authenticator_login,role_memberships,api_usage;
  IF authenticator_login OR role_memberships <> 0 THEN
    RAISE EXCEPTION 'Unexpected fixture role configuration; inspect before proceeding';
  END IF;
  RAISE NOTICE 'PASS: fixture still has no PostgREST login or role-switch privileges';
END $$;
ROLLBACK;
SQL
echo '=== Synthetic JWT test prerequisites ==='
command -v node
command -v openssl
"$(pwd -P)/.cache/gymforce-postgrest/postgrest" --version
echo 'BLOCKED_FOR_HTTP: authenticator has no LOGIN and no role-switch memberships.'
echo 'NEXT: create a disposable isolated HTTP fixture with a least-privilege authenticator; do not use postgres superuser as the HTTP connection role.'
echo 'PASS: security gate inspected without modifying roles or launching HTTP.'
