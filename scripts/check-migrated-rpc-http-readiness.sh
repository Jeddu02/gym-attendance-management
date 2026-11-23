#!/usr/bin/env bash
# GYMFORCE migration-backed RPC HTTP readiness: read-only catalog checks.
# Checks real migrated isolated fixture, not synthetic PostgREST smoke schema.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -z "${DATABASE_URL:-}${SUPABASE_DB_URL:-}${PGHOST:-}${PGHOSTADDR:-}${PGPORT:-}${PGDATABASE:-}${PGUSER:-}${PGSERVICE:-}${SUPABASE_URL:-}${SUPABASE_SERVICE_ROLE_KEY:-}${PGRST_DB_URI:-}${PGRST_JWT_SECRET:-}" ]] || { echo 'BLOCKED: inherited connection settings'; exit 2; }
bash scripts/inspect-postgrest-role-transport.sh >/dev/null
socket=/tmp/gf-pg-23c0b94e
psql=(sudo -n /usr/sbin/runuser -u postgres -- /usr/bin/env -u PGHOST -u PGHOSTADDR -u PGPORT -u PGDATABASE -u PGUSER -u PGSERVICE -u DATABASE_URL -u SUPABASE_DB_URL /usr/lib/postgresql/17/bin/psql -X -w -v ON_ERROR_STOP=1 -h "$socket" -p 55439 -U postgres -d gymforce_integration_test)
echo '=== GYMFORCE migrated RPC catalog, execution grants and schema exposure ==='
"${psql[@]}" -At <<'SQL'
BEGIN READ ONLY;
DO $$
DECLARE
 expected text[] := ARRAY[
 'prepare_member_checkin','commit_member_checkin',
 'reserve_member_checkin_request','owner_approve_member',
 'owner_record_membership_payment','owner_confirm_membership_payment',
 'owner_activate_membership_purchase'
 ];
 actual integer;
 forbidden integer;
 public_grants integer;
 unexpected integer;
BEGIN
 IF current_database() <> 'gymforce_integration_test'
 OR current_setting('listen_addresses') <> ''
 OR current_setting('data_directory') NOT LIKE '%/.cache/gymforce-native-23c0b94e3cec48efa403ab08a37a4937/data'
 THEN RAISE EXCEPTION 'Isolated database identity mismatch'; END IF;
 SELECT count(*),count(*) FILTER (WHERE NOT p.prosecdef),
        count(*) FILTER (WHERE has_function_privilege('anon',p.oid,'EXECUTE') OR has_function_privilege('authenticated',p.oid,'EXECUTE')),
        count(*) FILTER (WHERE NOT has_function_privilege('service_role',p.oid,'EXECUTE'))
 INTO actual,forbidden,public_grants,unexpected
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='api' AND p.proname=ANY(expected);
 IF actual<>7 THEN RAISE EXCEPTION 'Expected seven unique RPCs, found %',actual; END IF;
 IF forbidden<>0 THEN RAISE EXCEPTION 'Expected seven SECURITY DEFINER RPCs; non-definer count %',forbidden; END IF;
 IF public_grants<>0 THEN RAISE EXCEPTION 'Sensitive RPC exposed to anon/authenticated: %',public_grants; END IF;
 IF unexpected<>0 THEN RAISE EXCEPTION 'Service role lacks RPC execute permission: %',unexpected; END IF;
 RAISE NOTICE 'PASS: 7 migrated sensitive RPCs; definer 7; anon/auth grants 0; service_role execute 7';
END $$;
SELECT p.proname,pg_get_function_identity_arguments(p.oid),
       p.prosecdef,has_function_privilege('anon',p.oid,'EXECUTE'),
       has_function_privilege('authenticated',p.oid,'EXECUTE'),
       has_function_privilege('service_role',p.oid,'EXECUTE')
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='api' AND p.proname IN
 ('prepare_member_checkin','commit_member_checkin','reserve_member_checkin_request',
 'owner_approve_member','owner_record_membership_payment',
 'owner_confirm_membership_payment','owner_activate_membership_purchase')
ORDER BY p.proname;
ROLLBACK;
SQL
echo 'PASS: migrated RPC authorization preflight; transaction read-only and rolled back.'
echo 'NOT VERIFIED: migrated RPCs through PostgREST HTTP, actual payment/attendance behavior, Supabase Auth or production.'
