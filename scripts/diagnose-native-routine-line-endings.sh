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
"${psql[@]}" -At -F '|' -c "select p.oid::regprocedure::text, encode(convert_to(p.prosrc,'UTF8'),'base64') from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('private','api') order by 1" | python3 -c '
import sys,base64,hashlib,re
expected={
"api.append_audit_event(text,uuid,text,text,text,jsonb)":"7a05ca54592137c75b9adda7023516a8",
"api.verify_audit_stream(text)":"f7c5cdb53ec4cf2d845e38f404df5fb9",
"private.audit_events_chain_insert()":"6fa6a434395de93250213752513ffb34",
"private.compute_audit_event_hash(bigint,text,text,uuid,text,text,text,jsonb,timestamp with time zone)":"a0635caf0c329b24571bd68df684f69f",
"private.is_active_owner()":"76af3203b0fe03c30e1eb6d8264a04e6",
"private.prevent_audit_event_mutation()":"d835b9b2db211d2439e03ec9d8a6337",
}
count=0
for line in sys.stdin:
 if "|" not in line: continue
 name,encoded=line.rstrip("\n").split("|",1)
 if name not in expected: continue
 raw=base64.b64decode(encoded)
 norm=raw.replace(b"\r\n",b"\n").replace(b"\r",b"\n")
 variants={"raw":raw,"LF":norm,"CRLF":norm.replace(b"\n",b"\r\n")}
 matched=[key for key,value in variants.items() if hashlib.md5(value).hexdigest()==expected[name]]
 print(name)
 print(" expected="+expected[name]+" actual="+hashlib.md5(raw).hexdigest())
 print(" line_endings: CRLF="+str(raw.count(b"\r\n"))+" LF="+str(raw.count(b"\n"))+" CR="+str(raw.count(b"\r")))
 print(" normalized_matches="+(",".join(matched) if matched else "NONE"))
 count+=1
if count!=len(expected):
 print("BLOCKED: expected six functions, found",count,file=sys.stderr);sys.exit(2)
'
echo "PASS: six routines compared without changing database or historical SQL"
