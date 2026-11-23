#!/usr/bin/env bash
# GYMFORCE: transactional role-authorization simulation on the isolated fixture.
# No PostgREST listener, JWT secrets, production access, or persistent SQL changes.
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/inspect-postgrest-role-transport.sh >/dev/null
socket="/tmp/gf-pg-23c0b94e"
psql=(sudo -n /usr/sbin/runuser -u postgres -- /usr/bin/env -u PGHOST -u PGHOSTADDR -u PGPORT -u PGDATABASE -u PGUSER -u PGSERVICE -u DATABASE_URL -u SUPABASE_DB_URL /usr/lib/postgresql/17/bin/psql -X -w -v ON_ERROR_STOP=1 -h "$socket" -p 55439 -U postgres -d gymforce_integration_test)
echo '=== Isolated SQL role-switch authorization simulation ==='
"${psql[@]}" -At <<'SQL'
BEGIN READ ONLY;
DO $$
DECLARE
  role_name text;
  sensitive text[] := ARRAY[
    'prepare_member_checkin','commit_member_checkin',
    'reserve_member_checkin_request','owner_approve_member',
    'owner_record_membership_payment','owner_confirm_membership_payment',
    'owner_activate_membership_purchase'
  ];
  checked integer;
  unexpected integer;
BEGIN
  FOR role_name IN SELECT unnest(ARRAY['anon','authenticated','service_role']) LOOP
    EXECUTE format('SET LOCAL ROLE %I',role_name);
    IF current_user <> role_name THEN
      RAISE EXCEPTION 'Role switch failed: %',role_name;
    END IF;
    SELECT count(*), count(*) FILTER (WHERE has_function_privilege(current_user,p.oid,'EXECUTE') <> (role_name='service_role'))
      INTO checked,unexpected
      FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
      WHERE n.nspname='api' AND p.proname=ANY(sensitive);
    IF checked <> 7 OR unexpected <> 0 THEN
      RAISE EXCEPTION 'RPC authorization mismatch for %: checked %, unexpected %',role_name,checked,unexpected;
    END IF;
    RAISE NOTICE 'PASS: role %, sensitive RPCs %, unexpected grants %',role_name,checked,unexpected;
    RESET ROLE;
  END LOOP;
END $$;
ROLLBACK;
SQL
echo 'PASS: isolated SQL role authorization simulation rolled back.'
echo 'NOT VERIFIED: PostgREST JWT signature validation, HTTP status codes, Auth user sessions, or end-to-end payment behavior.'
