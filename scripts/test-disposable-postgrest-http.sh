#!/usr/bin/env bash
# GYMFORCE disposable PostgREST HTTP/JWT smoke test. Synthetic schema only.
# Creates a new throwaway PG17 cluster, never connects to existing/hosted databases.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -z "${DATABASE_URL:-}${SUPABASE_DB_URL:-}${PGHOST:-}${PGHOSTADDR:-}${PGSERVICE:-}${PGDATABASE:-}${PGUSER:-}${PGPORT:-}${SUPABASE_URL:-}${SUPABASE_SERVICE_ROLE_KEY:-}${SUPABASE_JWT_SECRET:-}${PGRST_DB_URI:-}${PGRST_JWT_SECRET:-}" ]] || { echo 'BLOCKED: inherited database or service credentials'; exit 2; }
binary="$(pwd -P)/.cache/gymforce-postgrest/postgrest"
[[ -x "$binary" && ! -L "$binary" ]] || { echo 'BLOCKED: verified local PostgREST binary missing'; exit 2; }
command -v curl >/dev/null && command -v node >/dev/null || { echo 'BLOCKED: required local tools missing'; exit 2; }
pgbin=/usr/lib/postgresql/17/bin
[[ -x "$pgbin/initdb" && -x "$pgbin/pg_ctl" ]] || { echo 'BLOCKED: PG17 tools missing'; exit 2; }
work="$(mktemp -d /tmp/gymforce-http-fixture.XXXXXXXX)"
chmod 700 "$work"
pgport=55449
httpport=18749
pgpid=''
http_pid=''
cleanup(){
  if [[ -n "$http_pid" ]]; then kill "$http_pid" 2>/dev/null || true; wait "$http_pid" 2>/dev/null || true; fi
  if [[ -n "$pgpid" ]]; then "$pgbin/pg_ctl" -D "$work/data" -m immediate -w stop >/dev/null 2>&1 || true; fi
  rm -rf -- "$work"
}
trap cleanup EXIT
"$pgbin/initdb" -D "$work/data" --auth-local=trust --auth-host=trust --no-instructions >/dev/null
# Isolated unprivileged cluster and loopback-only listener; fail if ports occupied.
"$pgbin/pg_ctl" -D "$work/data" -o "-c listen_addresses=127.0.0.1 -p $pgport -c unix_socket_directories=$work" -w start >/dev/null
pgpid=started
psql=("$pgbin/psql" -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -p "$pgport" -U "$(id -un)" -d postgres)
"${psql[@]}" >/dev/null <<'SQL'
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE gf_http_login LOGIN NOINHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
GRANT anon,authenticated TO gf_http_login;
CREATE SCHEMA api;
CREATE FUNCTION api.ping() RETURNS json LANGUAGE sql STABLE AS $$ SELECT '{"ok":true}'::json $$;
CREATE FUNCTION api.restricted() RETURNS json LANGUAGE sql STABLE AS $$ SELECT '{"secret":true}'::json $$;
REVOKE ALL ON SCHEMA api FROM PUBLIC;
GRANT USAGE ON SCHEMA api TO anon,authenticated;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA api FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.ping() TO anon,authenticated;
GRANT EXECUTE ON FUNCTION api.restricted() TO authenticated;
SQL
secret="$(node -e 'process.stdout.write(require("node:crypto").randomBytes(48).toString("base64url"))')"
export PGRST_DB_URI="postgres://gf_http_login@127.0.0.1:$pgport/postgres"
export PGRST_DB_SCHEMAS=api PGRST_DB_ANON_ROLE=anon PGRST_JWT_SECRET="$secret"
export PGRST_SERVER_HOST=127.0.0.1 PGRST_SERVER_PORT="$httpport"
"$binary" >"$work/postgrest.log" 2>&1 &
http_pid=$!
ready=0
for _ in {1..40}; do
 if curl -fsS --max-time 1 "http://127.0.0.1:$httpport/rpc/ping" >/dev/null 2>&1; then ready=1; break; fi
 sleep 0.25
done
if [[ "$ready" != 1 ]]; then echo 'FAIL: PostgREST failed readiness; local logs:'; tail -n 25 "$work/postgrest.log"; exit 1; fi
node --input-type=module <<'NODE'
import {createHmac} from 'node:crypto';
import assert from 'node:assert/strict';
const secret=process.env.PGRST_JWT_SECRET, base='http://127.0.0.1:18749';
const encode=x=>Buffer.from(JSON.stringify(x)).toString('base64url');
const token=(claims)=>{const p=encode({alg:'HS256',typ:'JWT'})+'.'+encode(claims);return p+'.'+createHmac('sha256',secret).update(p).digest('base64url')};
const now=Math.floor(Date.now()/1000);
const good=token({role:'authenticated',exp:now+300});
const expired=token({role:'authenticated',exp:now-60});
const tampered=good.slice(0,-4)+'xxxx';
const cases=[
 ['anonymous public RPC', '/rpc/ping',null,200],
 ['anonymous restricted RPC denied','/rpc/restricted',null,401],
 ['authenticated restricted RPC','/rpc/restricted',good,200],
 ['expired JWT rejected','/rpc/ping',expired,401],
 ['tampered JWT rejected','/rpc/ping',tampered,401],
 ['unknown role rejected','/rpc/ping',token({role:'service_role',exp:now+300}),401],
 ['future nbf rejected','/rpc/ping',token({role:'authenticated',nbf:now+300,exp:now+600}),401],
 ['unsigned token rejected','/rpc/ping',encode({alg:'none',typ:'JWT'})+'.'+encode({role:'authenticated',exp:now+300})+'.',401],
 ['malformed token rejected','/rpc/ping','not-a-jwt',401],
 ['authenticated public RPC','/rpc/ping',good,200]
];
for(const [label,path,jwt,expected] of cases){
 const res=await fetch(base+path,{method:'POST',headers:jwt?{Authorization:'Bearer '+jwt}:{}});
 assert.equal(res.status,expected,label+' HTTP '+res.status+' expected '+expected+' body '+(await res.text()).slice(0,250));
 console.log('PASS: '+label+' ('+expected+')');
}
console.log('PASS: 10/10 real local PostgREST JWT and RPC HTTP assertions');
NODE
echo 'PASS: disposable PG17 + PostgREST HTTP integration; cleanup on exit; no existing database accessed.'
echo 'NOT VERIFIED: real Supabase Auth, GYMFORCE migration RPCs, production deployment.'
