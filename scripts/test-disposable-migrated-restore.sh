#!/usr/bin/env bash
# GYMFORCE migration-backed restore rehearsal in a fresh disposable PG17 cluster.
# Never writes to the source fixture or any hosted database.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -z "${DATABASE_URL:-}${SUPABASE_DB_URL:-}${PGHOST:-}${PGHOSTADDR:-}${PGPORT:-}${PGDATABASE:-}${PGUSER:-}${PGSERVICE:-}${SUPABASE_URL:-}${SUPABASE_SERVICE_ROLE_KEY:-}${SUPABASE_ANON_KEY:-}${SUPABASE_JWT_SECRET:-}${PGRST_DB_URI:-}${PGRST_JWT_SECRET:-}" ]] || { echo 'BLOCKED: inherited database/service settings'; exit 2; }
bash scripts/check-migrated-rpc-http-readiness.sh >/dev/null
pgbin=/usr/lib/postgresql/17/bin
for tool in initdb pg_ctl pg_dump pg_restore psql createdb; do [[ -x "$pgbin/$tool" ]] || { echo "BLOCKED: PG17 $tool missing"; exit 2; }; done
work="$(mktemp -d /tmp/gymforce-migrated-restore.XXXXXXXX)"
chmod 700 "$work"
started=0
cleanup(){
 if [[ "$started" == 1 ]]; then "$pgbin/pg_ctl" -D "$work/data" -m immediate -w stop >/dev/null 2>&1 || true; fi
 rm -rf -- "$work"
}
trap cleanup EXIT
echo '=== Export source fixture into disposable archive ==='
sudo -n /usr/sbin/runuser -u postgres -- /usr/bin/env -u PGHOST -u PGHOSTADDR -u PGPORT -u PGDATABASE -u PGUSER -u PGSERVICE -u DATABASE_URL -u SUPABASE_DB_URL "$pgbin/pg_dump" --format=custom --no-owner --no-acl -h /tmp/gf-pg-23c0b94e -p 55439 -U postgres -d gymforce_integration_test > "$work/fixture.dump"
[[ -s "$work/fixture.dump" ]] || { echo 'FAIL: source export empty'; exit 1; }
echo '=== Initialize unprivileged disposable PG17 (Unix socket only) ==='
"$pgbin/initdb" -D "$work/data" --auth-local=trust --auth-host=reject --no-instructions >"$work/init.log"
# No TCP listeners; private Unix socket in 0700 temporary directory.
"$pgbin/pg_ctl" -D "$work/data" -o "-c listen_addresses='' -p 55459 -c unix_socket_directories=$work" -w start >"$work/start.log"
started=1
psql=("$pgbin/psql" -X -w -v ON_ERROR_STOP=1 -h "$work" -p 55459 -U "$(id -un)" -d postgres)
"${psql[@]}" <<'SQL'
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN;
CREATE ROLE authenticator NOLOGIN;
SQL
# Copy only application executor ROLE NAMES from the isolated source catalog.
# Never copy passwords, memberships, privileges, or login capabilities.
echo '=== Bootstrap application executor role names (NOLOGIN only) ==='
mapfile -t executor_roles < <(
 sudo -n /usr/sbin/runuser -u postgres -- /usr/bin/env -u PGHOST -u PGHOSTADDR -u PGPORT -u PGDATABASE -u PGUSER -u PGSERVICE -u DATABASE_URL -u SUPABASE_DB_URL "$pgbin/psql" -X -w -A -t -v ON_ERROR_STOP=1 -h /tmp/gf-pg-23c0b94e -p 55439 -U postgres -d gymforce_integration_test -c "SELECT rolname FROM pg_roles WHERE rolname ~ '^gym_[a-z0-9_]+_executor -h "$work" -p 55459 -U "$(id -un)" gymforce_restore_test
echo '=== Restore migration-backed schema/data with no owner or ACL replay ==='
if ! "$pgbin/pg_restore" --exit-on-error --no-owner --no-acl -h "$work" -p 55459 -U "$(id -un)" -d gymforce_restore_test "$work/fixture.dump" >"$work/restore.log" 2>&1; then
 echo 'BLOCKED: disposable restore failed; last diagnostics:'
 tail -n 24 "$work/restore.log"
 exit 1
fi
echo '=== Validate restored GYMFORCE RPC definitions ==='
"$pgbin/psql" -X -w -v ON_ERROR_STOP=1 -h "$work" -p 55459 -U "$(id -un)" -d gymforce_restore_test <<'SQL'
DO $$
DECLARE n integer; d integer;
BEGIN
 IF current_database()<>'gymforce_restore_test' OR current_setting('listen_addresses')<>'' THEN
  RAISE EXCEPTION 'Disposable restore identity mismatch';
 END IF;
 SELECT count(*),count(*) FILTER (WHERE p.prosecdef) INTO n,d
 FROM pg_proc p JOIN pg_namespace s ON s.oid=p.pronamespace
 WHERE s.nspname='api' AND p.proname=ANY(ARRAY[
 'prepare_member_checkin','commit_member_checkin','reserve_member_checkin_request',
 'owner_approve_member','owner_record_membership_payment',
 'owner_confirm_membership_payment','owner_activate_membership_purchase']);
 IF n<>7 OR d<>7 THEN RAISE EXCEPTION 'Restored sensitive RPC count % or definer count % mismatch',n,d; END IF;
 RAISE NOTICE 'PASS: 7/7 migration-backed sensitive RPCs restored with SECURITY DEFINER';
END $$;
SQL
echo 'PASS: disposable migration-backed database restored; no TCP listener; temporary cluster removed on exit.'
echo 'NOTE: --no-acl omits source grants. RPC HTTP authorization still requires a separately verified disposable grant bootstrap.'
echo 'NOT VERIFIED: migration-backed PostgREST HTTP behavior, full payment/check-in workflows, real Supabase Auth or production.'
 ORDER BY rolname"
)
(( ${#executor_roles[@]} > 0 )) || { echo 'BLOCKED: no application executor roles found in isolated source'; exit 2; }
for role in "${executor_roles[@]}"; do
 [[ "$role" =~ ^gym_[a-z0-9_]+_executor$ ]] || { echo 'BLOCKED: unexpected source role name'; exit 2; }
 "${psql[@]}" -c "CREATE ROLE $role NOLOGIN;" >/dev/null
 echo "BOOTSTRAPPED: $role (NOLOGIN)"
done
"$pgbin/createdb" -h "$work" -p 55459 -U "$(id -un)" gymforce_restore_test
echo '=== Restore migration-backed schema/data with no owner or ACL replay ==='
if ! "$pgbin/pg_restore" --exit-on-error --no-owner --no-acl -h "$work" -p 55459 -U "$(id -un)" -d gymforce_restore_test "$work/fixture.dump" >"$work/restore.log" 2>&1; then
 echo 'BLOCKED: disposable restore failed; last diagnostics:'
 tail -n 24 "$work/restore.log"
 exit 1
fi
echo '=== Validate restored GYMFORCE RPC definitions ==='
"$pgbin/psql" -X -w -v ON_ERROR_STOP=1 -h "$work" -p 55459 -U "$(id -un)" -d gymforce_restore_test <<'SQL'
DO $$
DECLARE n integer; d integer;
BEGIN
 IF current_database()<>'gymforce_restore_test' OR current_setting('listen_addresses')<>'' THEN
  RAISE EXCEPTION 'Disposable restore identity mismatch';
 END IF;
 SELECT count(*),count(*) FILTER (WHERE p.prosecdef) INTO n,d
 FROM pg_proc p JOIN pg_namespace s ON s.oid=p.pronamespace
 WHERE s.nspname='api' AND p.proname=ANY(ARRAY[
 'prepare_member_checkin','commit_member_checkin','reserve_member_checkin_request',
 'owner_approve_member','owner_record_membership_payment',
 'owner_confirm_membership_payment','owner_activate_membership_purchase']);
 IF n<>7 OR d<>7 THEN RAISE EXCEPTION 'Restored sensitive RPC count % or definer count % mismatch',n,d; END IF;
 RAISE NOTICE 'PASS: 7/7 migration-backed sensitive RPCs restored with SECURITY DEFINER';
END $$;
SQL
echo 'PASS: disposable migration-backed database restored; no TCP listener; temporary cluster removed on exit.'
echo 'NOTE: --no-acl omits source grants. RPC HTTP authorization still requires a separately verified disposable grant bootstrap.'
echo 'NOT VERIFIED: migration-backed PostgREST HTTP behavior, full payment/check-in workflows, real Supabase Auth or production.'
