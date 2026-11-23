#!/usr/bin/env bash
# Service-role valid-signature RPC dispatch test. Disposable local PostgreSQL only.
set -euo pipefail
cd "$(dirname "$0")/.."
for name in DATABASE_URL SUPABASE_DB_URL PGHOST PGHOSTADDR PGPORT PGDATABASE PGUSER PGSERVICE SUPABASE_URL SUPABASE_SERVICE_ROLE_KEY SUPABASE_JWT_SECRET PGRST_DB_URI PGRST_JWT_SECRET; do
 [[ -z "${!name:-}" ]] || { echo "BLOCKED: inherited $name"; exit 2; }
done
bash scripts/check-migrated-rpc-http-readiness.sh >/dev/null
pgbin=/usr/lib/postgresql/17/bin
binary="$(pwd -P)/.cache/gymforce-postgrest/postgrest"
[[ -x "$binary" && ! -L "$binary" ]] || { echo 'BLOCKED: local PostgREST missing'; exit 2; }
for tool in initdb pg_ctl pg_dump pg_restore psql createdb; do [[ -x "$pgbin/$tool" ]] || exit 2; done
work="$(mktemp -d /tmp/gymforce-migrated-http.XXXXXXXX)"
chmod 700 "$work"
started=0
http_pid=''
cleanup(){
 [[ -z "$http_pid" ]] || { kill "$http_pid" 2>/dev/null || true; wait "$http_pid" 2>/dev/null || true; }
 [[ "$started" == 0 ]] || "$pgbin/pg_ctl" -D "$work/data" -m immediate -w stop >/dev/null 2>&1 || true
 rm -rf -- "$work"
}
trap cleanup EXIT
echo '=== Archive migration-backed isolated fixture ==='
sudo -n /usr/sbin/runuser -u postgres -- /usr/bin/env -u PGHOST -u PGHOSTADDR -u PGPORT -u PGDATABASE -u PGUSER -u PGSERVICE -u DATABASE_URL -u SUPABASE_DB_URL "$pgbin/pg_dump" -Fc --no-owner --no-acl -h /tmp/gf-pg-23c0b94e -p 55439 -U postgres -d gymforce_integration_test > "$work/source.dump"
[[ -s "$work/source.dump" ]] || exit 2
"$pgbin/initdb" -D "$work/data" --auth-local=trust --auth-host=trust --no-instructions >"$work/init.log"
# HTTP listener is loopback only; database listener is Unix-socket only.
"$pgbin/pg_ctl" -D "$work/data" -o "-c listen_addresses='' -p 55469 -c unix_socket_directories=$work" -w start >"$work/pg.log"
started=1
psql=("$pgbin/psql" -X -w -v ON_ERROR_STOP=1 -h "$work" -p 55469 -U "$(id -un)" -d postgres)
"${psql[@]}" <<'SQL'
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN;
CREATE ROLE authenticator LOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS;
CREATE ROLE gym_checkin_executor NOLOGIN;
CREATE ROLE gym_owner_executor NOLOGIN;
CREATE ROLE gym_public_executor NOLOGIN;
GRANT anon,authenticated,service_role TO authenticator;
SQL
# Additional executor role names must come from the isolated source, never guessed.
roles_file="$work/executor_roles"
sudo -n /usr/sbin/runuser -u postgres -- /usr/bin/env -u PGHOST -u PGHOSTADDR -u PGPORT -u PGDATABASE -u PGUSER -u PGSERVICE -u DATABASE_URL -u SUPABASE_DB_URL "$pgbin/psql" -X -w -At -h /tmp/gf-pg-23c0b94e -p 55439 -U postgres -d gymforce_integration_test -c "SELECT rolname FROM pg_roles WHERE rolname LIKE 'gym_%_executor' ORDER BY rolname" > "$roles_file"
while IFS= read -r role; do
 [[ "$role" =~ ^gym_[a-z0-9_]+_executor$ ]] || exit 2
 "${psql[@]}" -At -c "SELECT 1 FROM pg_roles WHERE rolname='$role'" | grep -qx 1 || "${psql[@]}" -c "CREATE ROLE $role NOLOGIN;" >/dev/null
done < "$roles_file"
"$pgbin/createdb" -h "$work" -p 55469 -U "$(id -un)" gymforce_http_test
"$pgbin/pg_restore" --exit-on-error --no-owner --no-acl -h "$work" -p 55469 -U "$(id -un)" -d gymforce_http_test "$work/source.dump" >"$work/restore.log" 2>&1 || { tail -n 25 "$work/restore.log"; exit 1; }
psql_db=("$pgbin/psql" -X -w -v ON_ERROR_STOP=1 -h "$work" -p 55469 -U "$(id -un)" -d gymforce_http_test)
"${psql_db[@]}" <<'SQL'
REVOKE ALL ON SCHEMA api FROM PUBLIC;
GRANT USAGE ON SCHEMA api TO anon,authenticated,service_role;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA api FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA api TO service_role;
DO $$
DECLARE n int;
BEGIN
 SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace s ON s.oid=p.pronamespace
 WHERE s.nspname='api' AND p.proname IN ('prepare_member_checkin','commit_member_checkin','reserve_member_checkin_request','owner_approve_member','owner_record_membership_payment','owner_confirm_membership_payment','owner_activate_membership_purchase')
 AND p.prosecdef AND NOT has_function_privilege('anon',p.oid,'EXECUTE')
 AND NOT has_function_privilege('authenticated',p.oid,'EXECUTE')
 AND has_function_privilege('service_role',p.oid,'EXECUTE');
 IF n<>7 THEN RAISE EXCEPTION 'RPC grant/definer mismatch: %',n; END IF;
END $$;
SQL
# Build exact named argument objects from the restored PostgreSQL function catalog.
# This avoids accidental PGRST202 caused by missing/misspelled parameters.
"${psql_db[@]}" -At -c "
SELECT jsonb_object_agg(p.proname, args.payload)::text
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
CROSS JOIN LATERAL (
 SELECT coalesce(jsonb_object_agg(p.proargnames[i], CASE
  WHEN format_type(p.proargtypes[i-1],NULL)='uuid' THEN to_jsonb('00000000-0000-0000-0000-000000000001'::text)
  WHEN format_type(p.proargtypes[i-1],NULL) IN ('integer','bigint','smallint','numeric','real','double precision') THEN to_jsonb(1)
  WHEN format_type(p.proargtypes[i-1],NULL)='boolean' THEN to_jsonb(false)
  WHEN format_type(p.proargtypes[i-1],NULL) LIKE 'timestamp%' THEN to_jsonb('2026-01-01T00:00:00Z'::text)
  WHEN format_type(p.proargtypes[i-1],NULL)='bytea' THEN to_jsonb('\\\\x00'::text)
  ELSE to_jsonb('synthetic-test-value'::text)
 END), '{}'::jsonb) AS payload
 FROM generate_series(1,p.pronargs) i
) args
WHERE n.nspname='api' AND p.proname IN
('prepare_member_checkin','commit_member_checkin','reserve_member_checkin_request','owner_approve_member','owner_record_membership_payment','owner_confirm_membership_payment','owner_activate_membership_purchase')
" > "$work/rpc-args.json"
test -s "$work/rpc-args.json"
export GYMFORCE_RPC_ARGS_FILE="$work/rpc-args.json"
secret="$(node -e 'process.stdout.write(require("node:crypto").randomBytes(48).toString("base64url"))')"
# PostgREST authenticates via private Unix socket; never exposes database TCP.
export PGRST_DB_URI="postgres://authenticator@/gymforce_http_test?host=$work&port=55469"
export PGRST_DB_SCHEMAS=api PGRST_DB_ANON_ROLE=anon PGRST_JWT_SECRET="$secret"
export PGRST_SERVER_HOST=127.0.0.1 PGRST_SERVER_PORT=18769
# Every HTTP transaction rolls back even if a function would otherwise write.
export PGRST_DB_TX_END=rollback
"$binary" >"$work/postgrest.log" 2>&1 &
http_pid=$!
ready=0
for _ in {1..60}; do
 if curl -sS --max-time 1 -o /dev/null "http://127.0.0.1:18769/" 2>/dev/null; then ready=1; break; fi
 sleep 0.25
done
[[ "$ready" == 1 ]] || { tail -n 30 "$work/postgrest.log"; exit 1; }
node --input-type=module <<'NODE'
import {createHmac} from 'node:crypto';
import {readFileSync} from 'node:fs';
import assert from 'node:assert/strict';
const base='http://127.0.0.1:18769';
const enc=x=>Buffer.from(JSON.stringify(x)).toString('base64url');
const jwt=role=>{const p=enc({alg:'HS256',typ:'JWT'})+'.'+enc({role,exp:Math.floor(Date.now()/1000)+300});return p+'.'+createHmac('sha256',process.env.PGRST_JWT_SECRET).update(p).digest('base64url')};
const args=JSON.parse(readFileSync(process.env.GYMFORCE_RPC_ARGS_FILE,'utf8'));
const names=['prepare_member_checkin','commit_member_checkin','reserve_member_checkin_request','owner_approve_member','owner_record_membership_payment','owner_confirm_membership_payment','owner_activate_membership_purchase'];
assert.deepEqual(Object.keys(args).sort(),[...names].sort(),'catalog must contain exactly seven RPCs');
for(const fn of names){
 const payload=args[fn];
 assert.ok(payload && Object.keys(payload).length>0,fn+' catalog arguments missing');
 const res=await fetch(base+'/rpc/'+fn,{method:'POST',headers:{Authorization:'Bearer '+jwt('service_role'),'Content-Type':'application/json'},body:JSON.stringify(payload)});
 const body=await res.text();
 let parsed;try{parsed=JSON.parse(body)}catch{parsed=null}
 assert.notEqual(parsed?.code,'PGRST202',fn+' did not resolve in PostgREST schema cache: '+body.slice(0,300));
 const ownerGuard=fn.startsWith('owner_') && parsed?.code==='42501' && parsed?.message==='OWNER_ACCESS_REQUIRED';
 assert.ok(parsed?.code!=='42501'||ownerGuard,fn+' unexpected SQL privilege failure: '+body.slice(0,300));
 assert.ok(res.status!==404,fn+' returned HTTP 404: '+body.slice(0,300));
 assert.ok(res.status!==401&&(res.status!==403||ownerGuard),fn+' returned unexpected auth error: '+body.slice(0,300));
 // Synthetic values may fail business validation; this stage checks dispatch only.
 console.log('PASS: '+fn+' service-role RPC '+(ownerGuard?'reached owner access guard':'dispatched')+' (HTTP '+res.status+', code '+(parsed?.code??'none')+')');
}
// A forged identity claim is not proof of an approved owner. Verify owner RPCs
// continue to enforce the database owner guard, even with a syntactically valid JWT.
const forged=(()=>{
 const p=enc({alg:'HS256',typ:'JWT'})+'.'+enc({
  role:'service_role',sub:'00000000-0000-0000-0000-000000000001',
  email:'synthetic-owner@example.invalid',
  app_metadata:{role:'owner'},user_metadata:{role:'owner'},
  exp:Math.floor(Date.now()/1000)+300
 });
 return p+'.'+createHmac('sha256',process.env.PGRST_JWT_SECRET).update(p).digest('base64url');
})();
for(const fn of names.filter(x=>x.startsWith('owner_'))){
 const res=await fetch(base+'/rpc/'+fn,{
  method:'POST',headers:{Authorization:'Bearer '+forged,'Content-Type':'application/json'},
  body:JSON.stringify(args[fn])
 });
 const body=await res.text();
 let parsed;try{parsed=JSON.parse(body)}catch{parsed=null}
 assert.equal(res.status,403,fn+' forged owner claim unexpectedly passed guard: '+body.slice(0,300));
 assert.equal(parsed?.code,'42501',fn+' unexpected forged-claim response: '+body.slice(0,300));
 assert.equal(parsed?.message,'OWNER_ACCESS_REQUIRED',fn+' owner guard message changed: '+body.slice(0,300));
 console.log('PASS: '+fn+' forged owner metadata/sub denied by database (403/42501)');
}
console.log('PASS: 7 service-role dispatch/guard checks + 4 forged-owner-claim denial checks; every HTTP transaction configured to roll back');
NODE
echo 'PASS: disposable service-role HTTP RPC dispatch and forged-owner-claim checks; transactions configured for rollback; no source or production changes.'
echo 'NOT VERIFIED: successful business operations, full payment/check-in workflows, real Supabase Auth, or production.'
