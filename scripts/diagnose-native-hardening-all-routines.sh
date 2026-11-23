#!/usr/bin/env bash
# Read-only integrity inventory before retrying executor hardening.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -z "${DATABASE_URL:-}${SUPABASE_DB_URL:-}${PGHOST:-}${PGHOSTADDR:-}${PGSERVICE:-}${PGDATABASE:-}${PGUSER:-}${PGPORT:-}" ]] || { echo "BLOCKED: inherited database override"; exit 2; }
root="$(pwd -P)/.cache/gymforce-native-23c0b94e3cec48efa403ab08a37a4937"
socket="/tmp/gf-pg-23c0b94e"
[[ ! -L .cache && ! -L "$root" && ! -L "$socket" ]] || { echo "BLOCKED: redirected path"; exit 2; }
[[ "$(sudo -n stat -c '%U:%G:%a' "$root")" == "postgres:postgres:700" && "$(sudo -n stat -c '%U:%G:%a' "$socket")" == "postgres:postgres:700" ]] || { echo "BLOCKED: ownership mismatch"; exit 2; }
psql=(sudo -n /usr/sbin/runuser -u postgres -- /usr/bin/env -u PGHOST -u PGHOSTADDR -u PGPORT -u PGDATABASE -u PGUSER -u PGSERVICE -u DATABASE_URL -u SUPABASE_DB_URL /usr/lib/postgresql/17/bin/psql -X -w -v ON_ERROR_STOP=1 -h "$socket" -p 55439 -U postgres -d gymforce_integration_test)
identity="$("${psql[@]}" -At -c "select current_database() || '|' || current_user || '|' || current_setting('data_directory') || '|' || current_setting('listen_addresses') || '|' || current_setting('server_version_num')")"
[[ "$identity" == "gymforce_integration_test|postgres|$root/data||170012" ]] || { echo "BLOCKED: synthetic identity mismatch"; exit 2; }
echo "=== Complete migration-25 baseline routine checksum comparison ==="
python3 - <<'PY' | "${psql[@]}" -P pager=off -f -
import pathlib,re
s=pathlib.Path('supabase/migrations/20261110100000_executor_hardening.sql').read_text(encoding='utf-8-sig')
# Extract every signature and pinned hash from both duplicated hardening inventories.
pairs=re.findall(r"\('((?:api|private)\.[^']+\([^']*\))','([0-9a-f]{32})','gym_[^']+','(?:true|false)','(?:true|false)','[^']*'\)",s)
unique=dict(pairs)
if len(unique)!=25 or len(pairs)!=50:
    raise SystemExit(f'BLOCKED: unexpected integrity inventory size: {len(pairs)} entries, {len(unique)} unique')
values=",\n".join("('%s','%s')" % (a,b) for a,b in unique.items())
print("WITH expected(signature, pinned_md5) AS (VALUES "+values+""")
SELECT e.signature, e.pinned_md5,
       md5(p.prosrc) AS actual_md5,
       md5(replace(replace(replace(p.prosrc,chr(13)||chr(10),chr(10)),chr(13),chr(10)),chr(10),chr(13)||chr(10))) AS crlf_md5,
       CASE WHEN p.oid IS NULL THEN 'MISSING'
            WHEN md5(p.prosrc)=e.pinned_md5 THEN 'RAW_MATCH'
            WHEN md5(replace(replace(replace(p.prosrc,chr(13)||chr(10),chr(10)),chr(13),chr(10)),chr(10),chr(13)||chr(10)))=e.pinned_md5 THEN 'CRLF_MATCH'
            ELSE 'MISMATCH' END AS status,
       pg_get_userbyid(p.proowner) AS owner, p.prosecdef AS security_definer, p.proconfig AS config
FROM expected e LEFT JOIN pg_proc p ON p.oid=to_regprocedure(e.signature)
ORDER BY status DESC,e.signature;
""")
PY
echo "PASS: read-only full inventory comparison completed"
