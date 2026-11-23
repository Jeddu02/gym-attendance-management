#!/usr/bin/env bash
# GYMFORCE staging deployment boundary; offline, read-only, no secrets.
set -euo pipefail
cd "$(dirname "$0")/.."
echo '=== GYMFORCE isolated staging boundary (offline/read-only) ==='
branch="$(git branch --show-current)"
echo "BRANCH: $branch"
if [[ "$branch" != fix/* ]]; then echo 'BLOCKED: expected existing nonproduction fix branch'; exit 2; fi
if [[ -n "$(git status --porcelain)" ]]; then echo 'NOTICE: uncommitted local changes present'; fi
bash scripts/inspect-staging-supabase-readiness.sh
node --input-type=module <<'NODE'
import {readFileSync,readdirSync,existsSync} from 'node:fs';
const cfg=readFileSync('supabase/config.toml','utf8');
const entries=readdirSync('supabase/migrations').filter(x=>x.endsWith('.sql')).sort();
const edges=readdirSync('supabase/functions',{withFileTypes:true}).filter(x=>x.isDirectory()&&existsSync('supabase/functions/'+x.name+'/index.ts')).map(x=>x.name).sort();
const checks=[
 ['migration files present',entries.length>0],
 ['Edge functions present',edges.length>0],
 ['PostgreSQL 17',/^major_version\s*=\s*17\s*$/m.test(cfg)],
 ['api-only exposure',/^schemas\s*=\s*\["api"\]\s*$/m.test(cfg)],
 ['public sign-up disabled',/^enable_signup\s*=\s*false\s*$/m.test(cfg)],
 ['anonymous sign-in disabled',/^enable_anonymous_sign_ins\s*=\s*false\s*$/m.test(cfg)],
 ['new tables not auto-exposed',/^auto_expose_new_tables\s*=\s*false\s*$/m.test(cfg)],
];
for(const [label,ok] of checks)console.log((ok?'PASS: ':'BLOCKED: ')+label);
console.log('MIGRATION_COUNT='+entries.length);
console.log('EDGE_COUNT='+edges.length);
console.log('FIRST_MIGRATION='+(entries[0]||'none'));
console.log('LAST_MIGRATION='+(entries.at(-1)||'none'));
if(checks.some(([,ok])=>!ok))process.exitCode=2;
NODE
echo '=== Hosted staging gates (not verified by local config) ==='
echo 'BLOCKED UNTIL VERIFIED: distinct nonproduction Supabase project, owner-approved access'
echo 'BLOCKED UNTIL VERIFIED: hosted PostgreSQL compatibility, remote migration inventory, backup/rollback'
echo 'BLOCKED UNTIL VERIFIED: hosted Auth restrictions, API exposure, grants/RLS, CORS and Edge secrets'
echo 'BLOCKED UNTIL VERIFIED: synthetic users only; explicit approval before any hosted writes'
echo 'PASS: offline boundary inspection completed; no network calls, secrets or database writes'
