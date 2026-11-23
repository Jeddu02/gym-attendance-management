#!/usr/bin/env bash
# GYMFORCE: read-only PostgREST + JWT integration preflight.
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/inspect-native-http-auth-readiness.sh
echo '=== PostgREST runtime candidates (no installation) ==='
for bin in postgrest /usr/local/bin/postgrest /usr/bin/postgrest; do
 if command -v "$bin" >/dev/null 2>&1; then
  path="$(command -v "$bin")"
  printf 'FOUND %s\n' "$path"
  "$path" --version || true
 else
  printf 'NOT_INSTALLED %s\n' "$bin"
 fi
done
echo '=== PostgREST local package availability ==='
if command -v apt-cache >/dev/null; then apt-cache policy postgrest | head -n 12; fi
echo '=== Local listener inventory (read-only) ==='
if command -v ss >/dev/null; then ss -ltn '( sport = :8000 or sport = :18743 or sport = :18744 or sport = :3000 )' || true; fi
echo '=== Auth and PostgREST source contracts ==='
node --input-type=module <<'NODE'
import { readFileSync,readdirSync } from 'node:fs';
const root='supabase/functions';
const endpoints=readdirSync(root,{withFileTypes:true}).filter(x=>x.isDirectory()&&x.name!=='_shared').map(x=>x.name).sort();
const out=[];
for(const name of endpoints){
 const source=readFileSync(`${root}/${name}/index.ts`,'utf8');
 const keys=[...source.matchAll(/Deno\.env\.get\(["']([A-Z][A-Z0-9_]*)["']\)/g)].map(m=>m[1]);
 const checks={bearer:/Authorization|authorization/.test(source),getUser:/\.auth\.getUser\s*\(/.test(source),service:/SUPABASE_SERVICE_ROLE_KEY/.test(source),cors:/withBrowserCors/.test(source)};
 out.push({name,env:[...new Set(keys)].sort(),...checks});
}
console.log(JSON.stringify(out,null,2));
console.log('EDGE_ENDPOINT_COUNT='+out.length);
if(out.length!==22)process.exitCode=2;
NODE
echo '=== Integration readiness decision ==='
echo 'PASS: read-only compatibility inventory; no credentials, HTTP service, package installation, or database mutation.'
echo 'NOTE: real JWT verification and PostgREST RPC integration remain UNVERIFIED.'
