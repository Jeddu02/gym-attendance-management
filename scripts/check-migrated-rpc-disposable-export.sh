#!/usr/bin/env bash
# GYMFORCE: verify that a migration-backed fixture can be exported for disposable HTTP tests.
# No restore, role changes, listener, or production database access.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -z "${DATABASE_URL:-}${SUPABASE_DB_URL:-}${PGHOST:-}${PGHOSTADDR:-}${PGPORT:-}${PGDATABASE:-}${PGUSER:-}${PGSERVICE:-}${SUPABASE_URL:-}${SUPABASE_SERVICE_ROLE_KEY:-}${SUPABASE_JWT_SECRET:-}${PGRST_DB_URI:-}${PGRST_JWT_SECRET:-}" ]] || { echo 'BLOCKED: inherited connection or service configuration'; exit 2; }
bash scripts/check-migrated-rpc-http-readiness.sh >/dev/null
pgbin=/usr/lib/postgresql/17/bin
for tool in pg_dump pg_restore; do [[ -x "$pgbin/$tool" ]] || { echo "BLOCKED: PG17 $tool unavailable"; exit 2; }; done
work="$(mktemp -d /tmp/gymforce-migrated-export.XXXXXXXX)"
chmod 700 "$work"
trap 'rm -rf -- "$work"' EXIT
socket=/tmp/gf-pg-23c0b94e
echo '=== Export isolated migration-backed database (temporary local archive) ==='
sudo -n /usr/sbin/runuser -u postgres -- /usr/bin/env -u PGHOST -u PGHOSTADDR -u PGPORT -u PGDATABASE -u PGUSER -u PGSERVICE -u DATABASE_URL -u SUPABASE_DB_URL "$pgbin/pg_dump" --format=custom --no-owner --no-acl -h "$socket" -p 55439 -U postgres -d gymforce_integration_test > "$work/fixture.dump"
[[ -s "$work/fixture.dump" ]] || { echo 'FAIL: empty archive'; exit 1; }
"$pgbin/pg_restore" --list "$work/fixture.dump" > "$work/catalog.txt"
node --input-type=module - "$work/catalog.txt" <<'NODE'
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const catalog=readFileSync(process.argv[2],'utf8');
for(const rpc of ['prepare_member_checkin','commit_member_checkin','reserve_member_checkin_request','owner_approve_member','owner_record_membership_payment','owner_confirm_membership_payment','owner_activate_membership_purchase']){
 assert.match(catalog,new RegExp('FUNCTION[^\\n]*\\b'+rpc+'\\b'), 'Missing migrated RPC in archive: '+rpc);
 console.log('PASS: migration-backed RPC archived: '+rpc);
}
console.log('PASS: 7/7 sensitive RPC definitions present in temporary archive');
NODE
echo 'PASS: isolated PG17 migration-backed archive generated and validated; archive removed on exit.'
echo 'NEXT: validate disposable restore, safe role bootstrap and actual PostgREST HTTP requests.'
echo 'NOT VERIFIED: restored database behavior, GYMFORCE HTTP workflows, Supabase Auth or production.'
