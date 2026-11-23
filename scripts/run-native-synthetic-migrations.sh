#!/usr/bin/env bash
# Execute preserved GYMFORCE migrations in the explicitly identified disposable database.
# Never runs against 17/main, production, or an arbitrary PostgreSQL connection.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -z "${DATABASE_URL:-}${SUPABASE_DB_URL:-}${PGHOST:-}${PGHOSTADDR:-}${PGSERVICE:-}${PGDATABASE:-}${PGUSER:-}${PGPORT:-}" ]] || { echo "BLOCKED: inherited database connection override"; exit 2; }
root="$(pwd -P)/.cache/gymforce-native-23c0b94e3cec48efa403ab08a37a4937"
socket="/tmp/gf-pg-23c0b94e"
[[ ! -L .cache && ! -L "$root" && ! -L "$socket" ]] || { echo "BLOCKED: redirected isolated path"; exit 2; }
[[ "$(sudo -n stat -c '%U:%G:%a' "$root")" == "postgres:postgres:700" ]] || { echo "BLOCKED: cluster ownership"; exit 2; }
[[ "$(sudo -n stat -c '%U:%G:%a' "$socket")" == "postgres:postgres:700" ]] || { echo "BLOCKED: socket ownership"; exit 2; }
psql=(sudo -n /usr/sbin/runuser -u postgres -- /usr/bin/env -u PGHOST -u PGHOSTADDR -u PGPORT -u PGDATABASE -u PGUSER -u PGSERVICE -u DATABASE_URL -u SUPABASE_DB_URL /usr/lib/postgresql/17/bin/psql -X -w -v ON_ERROR_STOP=1 -h "$socket" -p 55439 -U postgres -d gymforce_integration_test)
identity="$("${psql[@]}" -At -c "select current_database() || '|' || current_user || '|' || current_setting('data_directory') || '|' || current_setting('listen_addresses') || '|' || current_setting('server_version_num')")"
[[ "$identity" == "gymforce_integration_test|postgres|$root/data||170012" ]] || { echo "BLOCKED: synthetic database identity mismatch"; exit 2; }
# Fail closed if any application objects or a previous migration ledger exist.
existing="$("${psql[@]}" -At -c "select count(*) from information_schema.tables where table_schema in ('private','public') and table_name not like 'pg_%' and table_name not like 'sql_%'")"
[[ "$existing" == "0" ]] || { echo "BLOCKED: app tables already exist; migration runner is single-use"; exit 2; }
prereq="$("${psql[@]}" -At -c "select (select count(*) from pg_roles where rolname in ('anon','authenticated','service_role','authenticator','supabase_auth_admin'))::text || '|' || (select count(*) from information_schema.tables where table_schema='auth' and table_name='users')::text || '|' || (select count(*) from pg_extension where extname in ('pgcrypto','btree_gist'))::text")"
[[ "$prereq" == "5|1|2" ]] || { echo "BLOCKED: synthetic prerequisites missing ($prereq)"; exit 2; }
mapfile -t migrations < <(find supabase/migrations -maxdepth 1 -type f -name '*.sql' | LC_ALL=C sort)
[[ "${#migrations[@]}" == 37 ]] || { echo "BLOCKED: expected exactly 37 migrations"; exit 2; }
# PostgreSQL reads source files as the postgres OS user; stdin avoids granting
# postgres filesystem access to the developer-owned checkout.
passed=0
for file in "${migrations[@]}"; do
  echo "RUN [$((passed+1))/37] $(basename "$file")"
  # SQL migrations already contain their own BEGIN/COMMIT boundaries.
  # Guard and file share one psql invocation; a failure halts the sequence.
  if { printf '%s\n' "DO \$guard\$ BEGIN IF current_database() <> 'gymforce_integration_test' OR current_user <> 'postgres' OR current_setting('listen_addresses') <> '' OR current_setting('data_directory') <> '$root/data' THEN RAISE EXCEPTION 'Synthetic migration identity mismatch'; END IF; END \$guard\$;"; cat "$file"; } | "${psql[@]}" -q -f -; then
    passed=$((passed+1))
    echo "PASS [$passed/37] $(basename "$file")"
  else
    echo "FAIL: $(basename "$file") after $passed successful migrations; stopping without retry/reset"
    exit 1
  fi
done
echo "PASS: all 37 preserved migrations executed in isolated synthetic PostgreSQL"
echo "WARNING: synthetic Auth fixture is not a production-equivalent authentication test"
