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
echo "=== Positive check-in fixture prerequisites (read-only) ==="
"${psql[@]}" -P pager=off <<'SQL'
BEGIN READ ONLY;
SELECT c.table_name,c.ordinal_position,c.column_name,c.data_type,c.is_nullable,c.column_default
FROM information_schema.columns c
WHERE c.table_schema='private' AND c.table_name IN
('members','member_pin_credentials','membership_plans','membership_purchases','payment_records','payment_allocations','payment_events','attendance_checkins','owner_access','audit_events')
ORDER BY c.table_name,c.ordinal_position;
SELECT con.conrelid::regclass AS table_name,con.conname AS constraint_name,con.contype,
pg_get_constraintdef(con.oid) AS definition
FROM pg_constraint con JOIN pg_namespace n ON n.oid=con.connamespace
WHERE n.nspname='private' AND con.conrelid::regclass::text IN
('private.members','private.member_pin_credentials','private.membership_plans','private.membership_purchases','private.payment_records','private.payment_allocations','private.payment_events','private.attendance_checkins')
ORDER BY 1,2;
SELECT t.tgrelid::regclass AS table_name,t.tgname AS trigger_name,
t.tgfoid::regprocedure AS function_name
FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='private' AND NOT t.tgisinternal
AND c.relname IN ('members','member_pin_credentials','membership_plans','membership_purchases','payment_records','payment_allocations','payment_events','attendance_checkins')
ORDER BY 1,2;
ROLLBACK;
SQL
echo "PASS: read-only positive fixture prerequisite inspection completed"
