#!/usr/bin/env bash
# Read-only: distinguish newline normalization from true routine source drift.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -z "${DATABASE_URL:-}${SUPABASE_DB_URL:-}${PGHOST:-}${PGHOSTADDR:-}${PGSERVICE:-}${PGDATABASE:-}${PGUSER:-}${PGPORT:-}" ]] || { echo "BLOCKED: inherited DB override"; exit 2; }
root="$(pwd -P)/.cache/gymforce-native-23c0b94e3cec48efa403ab08a37a4937"
socket="/tmp/gf-pg-23c0b94e"
[[ ! -L .cache && ! -L "$root" && ! -L "$socket" ]] || { echo "BLOCKED: redirected path"; exit 2; }
[[ "$(sudo -n stat -c '%U:%G:%a' "$root")" == "postgres:postgres:700" && "$(sudo -n stat -c '%U:%G:%a' "$socket")" == "postgres:postgres:700" ]] || { echo "BLOCKED: ownership mismatch"; exit 2; }
psql=(sudo -n /usr/sbin/runuser -u postgres -- /usr/bin/env -u PGHOST -u PGHOSTADDR -u PGPORT -u PGDATABASE -u PGUSER -u PGSERVICE -u DATABASE_URL -u SUPABASE_DB_URL /usr/lib/postgresql/17/bin/psql -X -w -v ON_ERROR_STOP=1 -h "$socket" -p 55439 -U postgres -d gymforce_integration_test)
identity="$("${psql[@]}" -At -c "select current_database() || '|' || current_user || '|' || current_setting('data_directory') || '|' || current_setting('listen_addresses') || '|' || current_setting('server_version_num')")"
[[ "$identity" == "gymforce_integration_test|postgres|$root/data||170012" ]] || { echo "BLOCKED: identity mismatch"; exit 2; }
"${psql[@]}" -P pager=off -c "
WITH expected(signature, expected_md5) AS (VALUES
 ('api.append_audit_event(text,uuid,text,text,text,jsonb)','7a05ca54592137c75b9adda7023516a8'),
 ('api.verify_audit_stream(text)','f7c5cdb53ec4cf2d845e38f404df5fb9'),
 ('private.audit_events_chain_insert()','6fa6a434395de93250213752513ffb34'),
 ('private.compute_audit_event_hash(bigint,text,text,uuid,text,text,text,jsonb,timestamp with time zone)','a0635caf0c329b24571bd68df684f69f'),
 ('private.is_active_owner()','76af3203b0fe03c30e1eb6d8264a04e6'),
 ('private.prevent_audit_event_mutation()','d835b9b2db211d2439e03ec9d8a6337')
)
SELECT e.signature,
       e.expected_md5,
       md5(p.prosrc) AS actual_md5,
       md5(replace(replace(p.prosrc,chr(13)||chr(10),chr(10)),chr(13),chr(10))) AS lf_md5,
       md5(replace(replace(replace(p.prosrc,chr(13)||chr(10),chr(10)),chr(13),chr(10)),chr(10),chr(13)||chr(10))) AS crlf_md5,
       CASE
         WHEN md5(p.prosrc)=e.expected_md5 THEN 'RAW'
         WHEN md5(replace(replace(p.prosrc,chr(13)||chr(10),chr(10)),chr(13),chr(10)))=e.expected_md5 THEN 'LF'
         WHEN md5(replace(replace(replace(p.prosrc,chr(13)||chr(10),chr(10)),chr(13),chr(10)),chr(10),chr(13)||chr(10)))=e.expected_md5 THEN 'CRLF'
         ELSE 'NONE'
       END AS matches
FROM expected e LEFT JOIN pg_proc p ON p.oid=to_regprocedure(e.signature)
ORDER BY e.signature;"
echo "PASS: six routines compared without changing database or historical SQL"
