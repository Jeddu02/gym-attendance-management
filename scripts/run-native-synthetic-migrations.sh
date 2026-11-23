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
# Resume only after the known first 15 successful migrations, or start fresh.
# A partially migrated database must match the exact known checkpoint.
existing="$("${psql[@]}" -At -c "select count(*) from information_schema.tables where table_schema in ('private','public') and table_name not like 'pg_%' and table_name not like 'sql_%'")"
resume=0
if [[ "$existing" != "0" ]]; then
  checkpoint="$("${psql[@]}" -At -c "select (to_regprocedure('api.owner_register_member(uuid,text,bytea,bytea)') is not null)::int::text || '|' || (to_regprocedure('api.owner_create_pin_enrollment_token(uuid,uuid,text,timestamp with time zone)') is null)::int::text || '|' || (to_regclass('private.member_pin_setup_tokens') is not null)::int::text")"
  if [[ "$checkpoint" == "1|1|1" ]]; then
    resume=15
    echo "Verified known migration-15 checkpoint; resuming at migration 16"
  else
    checkpoint24="$("${psql[@]}" -At -c "select (to_regprocedure('api.owner_record_membership_payment(uuid,uuid,uuid,numeric,text,text)') is not null)::int::text || '|' || (to_regprocedure('api.owner_list_membership_payments(uuid,text,text,integer,integer)') is not null)::int::text || '|' || (to_regprocedure('api.owner_create_pin_enrollment_token(uuid,uuid,text,timestamp with time zone)') is not null)::int::text || '|' || (to_regprocedure('api.append_audit_event(text,uuid,text,text,text,jsonb)') is not null)::int::text || '|' || (select count(*) from pg_roles where rolname in ('gym_data_owner','gym_owner_executor','gym_public_executor'))::text")
    [[ "$checkpoint24" == "1|1|1|1|0" ]] || { echo "BLOCKED: unexpected partial migration checkpoint ($checkpoint / $checkpoint24)"; exit 2; }
    resume=24
    echo "Verified known migration-24 checkpoint; resuming at migration 25"
  fi
fi
prereq="$("${psql[@]}" -At -c "select (select count(*) from pg_roles where rolname in ('anon','authenticated','service_role','authenticator','supabase_auth_admin'))::text || '|' || (select count(*) from information_schema.tables where table_schema='auth' and table_name='users')::text || '|' || (select count(*) from pg_extension where extname in ('pgcrypto','btree_gist'))::text")"
[[ "$prereq" == "5|1|2" ]] || { echo "BLOCKED: synthetic prerequisites missing ($prereq)"; exit 2; }
mapfile -t migrations < <(find supabase/migrations -maxdepth 1 -type f -name '*.sql' | LC_ALL=C sort)
[[ "${#migrations[@]}" == 37 ]] || { echo "BLOCKED: expected exactly 37 migrations"; exit 2; }
# PostgreSQL reads source files as the postgres OS user; stdin avoids granting
# postgres filesystem access to the developer-owned checkout.
passed=$resume
for file in "${migrations[@]:resume}"; do
  echo "RUN [$((passed+1))/37] $(basename "$file")"
  # SQL migrations already contain their own BEGIN/COMMIT boundaries.
  # Guard and file share one psql invocation; a failure halts the sequence.
  if { printf '%s\n' "DO \$guard\$ BEGIN IF current_database() <> 'gymforce_integration_test' OR current_user <> 'postgres' OR current_setting('listen_addresses') <> '' OR current_setting('data_directory') <> '$root/data' THEN RAISE EXCEPTION 'Synthetic migration identity mismatch'; END IF; END \$guard\$;"; if [[ "$(head -c 3 "$file" | od -An -tx1 | tr -d ' \n')" == "efbbbf" ]]; then
    echo "INFO: removing UTF-8 BOM from execution stream for $(basename "$file")" >&2
    tail -c +4 "$file"
  else
    if [[ "$(basename "$file")" == "20261110100000_executor_hardening.sql" ]]; then
      # Execution-only portability adjustment: pinned checksums were computed
      # from CRLF function bodies. PostgreSQL stores the LF source faithfully.
      # Preserve the historical migration on disk and all pinned MD5 values.
      echo "INFO: normalizing routine line endings only inside migration-25 checksum comparisons" >&2
      python3 - "$file" <<'PY'
import pathlib,sys
p=pathlib.Path(sys.argv[1]); data=p.read_bytes()
old=b'md5(p.prosrc)=r.body_md5'
assert data.count(old)==2, 'BLOCKED: unexpected hardening assertion shape'
new=b"md5(replace(replace(replace(p.prosrc,chr(13)||chr(10),chr(10)),chr(13),chr(10)),chr(10),chr(13)||chr(10)))=r.body_md5"
sys.stdout.buffer.write(data.replace(old,new))
PY
    else
      cat "$file"
    fi
  fi
  fi; } | "${psql[@]}" -q -f -; then
    passed=$((passed+1))
    echo "PASS [$passed/37] $(basename "$file")"
  else
    echo "FAIL: $(basename "$file") after $passed successful migrations; stopping without retry/reset"
    exit 1
  fi
done
echo "PASS: all 37 preserved migrations executed in isolated synthetic PostgreSQL"
echo "WARNING: synthetic Auth fixture is not a production-equivalent authentication test"
