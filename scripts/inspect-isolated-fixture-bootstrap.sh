#!/usr/bin/env bash
# Locate the original isolated PG17 fixture bootstrap; never execute candidates.
set -euo pipefail
cd "$(dirname "$0")/.."
for name in DATABASE_URL SUPABASE_DB_URL PGHOST PGHOSTADDR PGPORT PGDATABASE PGUSER PGSERVICE SUPABASE_URL SUPABASE_SERVICE_ROLE_KEY SUPABASE_JWT_SECRET PGRST_DB_URI PGRST_JWT_SECRET; do
  [[ -z "${!name:-}" ]] || { echo "BLOCKED: inherited $name; unset before local inspection"; exit 2; }
done
socket=/tmp/gf-pg-23c0b94e
port=55439
db=gymforce_integration_test
echo '=== Isolated fixture status ==='
if [[ -S "$socket/.s.PGSQL.$port" ]]; then
 echo 'FOUND: expected isolated Unix socket'
 if sudo -n /usr/sbin/runuser -u postgres -- /usr/bin/env -u PGHOST -u PGHOSTADDR -u PGPORT -u PGDATABASE -u PGUSER -u PGSERVICE -u DATABASE_URL -u SUPABASE_DB_URL /usr/lib/postgresql/17/bin/psql -X -w -At -h "$socket" -p "$port" -U postgres -d "$db" -c 'BEGIN READ ONLY; SELECT current_database(); ROLLBACK;' 2>/dev/null; then
  echo 'PASS: isolated fixture reachable; run bash scripts/inspect-isolated-owner-authorization.sh'
  exit 0
 fi
 echo 'BLOCKED: socket exists but isolated fixture cannot be verified'
 exit 2
fi
echo 'OFFLINE: original isolated fixture is not running'
echo '=== Local bootstrap candidates (source inspection only) ==='
node --input-type=module <<'NODE'
import {readdirSync,readFileSync} from 'node:fs';
const files=readdirSync('scripts').filter(f=>f.endsWith('.sh')).sort();
let found=0;
for(const file of files){
 const src=readFileSync('scripts/'+file,'utf8');
 if(!/initdb|pg_ctl|pg_createcluster|gymforce_integration_test|gf-pg-23c0b94e/.test(src))continue;
 const matches=src.split('\n').flatMap((line,i)=>/initdb|pg_ctl|pg_createcluster|gymforce_integration_test|gf-pg-23c0b94e/.test(line)?[i+1]:[]);
 console.log('CANDIDATE scripts/'+file+' lines '+matches.slice(0,12).join(',')+(matches.length>12?' ...':''));
 found++;
}
console.log('CANDIDATE_COUNT='+found);
if(!found)process.exitCode=2;
NODE
echo 'NEXT: inspect a candidate bootstrap before starting any local database; this script performed no writes.'
