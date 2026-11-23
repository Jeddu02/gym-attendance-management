#!/usr/bin/env bash
# Read-only exact body comparison for the final unresolved routine.
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
export GYMFORCE_SOURCE_SQL="supabase/migrations/20261030120000_audit_chain_enforcement.sql"
"${psql[@]}" -At -c "select encode(convert_to(prosrc,'UTF8'),'hex') from pg_proc where oid=to_regprocedure('private.prevent_audit_event_mutation()')" | python3 -c '
import os,sys,re,hashlib,difflib
hex_body=sys.stdin.read().strip()
if not hex_body or not re.fullmatch(r"[0-9a-f]+",hex_body): sys.exit("BLOCKED: missing function body")
actual=bytes.fromhex(hex_body).decode("utf-8")
source=open(os.environ["GYMFORCE_SOURCE_SQL"],encoding="utf-8-sig",newline="").read()
match=re.search(r"CREATE\s+OR\s+REPLACE\s+FUNCTION\s+private\.prevent_audit_event_mutation\s*\(\s*\).*?AS\s+\$function\$(.*?)\$function\$",source,re.I|re.S)
if not match: sys.exit("BLOCKED: source body not found")
src=match.group(1)
expected="d835b9b2db211d2439e03ec9d8a6337"
def md5(s):return hashlib.md5(s.encode()).hexdigest()
print("actual_db_md5:",md5(actual),"expected:",expected)
for name,body in [("source_exact",src),("source_lf",src.replace("\r\n","\n")),("source_crlf",src.replace("\r\n","\n").replace("\n","\r\n")),("db_crlf",actual.replace("\r\n","\n").replace("\n","\r\n"))]:
 print(name,"md5:",md5(body),"expected_match:",md5(body)==expected)
print("source_equals_db:",src==actual)
print("source_chars:",len(src),"db_chars:",len(actual))
print("source_repr_prefix:",repr(src[:120]))
print("db_repr_prefix:",repr(actual[:120]))
print("source_repr_suffix:",repr(src[-120:]))
print("db_repr_suffix:",repr(actual[-120:]))
print("diff:")
for line in list(difflib.unified_diff(src.replace("\r\n","\n").splitlines(),actual.replace("\r\n","\n").splitlines(),fromfile="historical_source",tofile="database",lineterm=""))[:60]: print(line)
'
echo "PASS: read-only exact source comparison completed"
