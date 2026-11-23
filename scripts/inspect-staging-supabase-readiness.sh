#!/usr/bin/env bash
# GYMFORCE staging readiness inventory. Offline/read-only; never contact Supabase.
set -euo pipefail
cd "$(dirname "$0")/.."
echo '=== GYMFORCE staging preflight (offline, read-only) ==='
if [[ -n "$(git status --porcelain)" ]]; then
  echo 'NOTICE: working tree has local changes; inspect before any future deployment'
else
  echo 'PASS: working tree clean'
fi
echo "BRANCH: $(git branch --show-current)"
echo '=== Local migration and Edge inventories ==='
find supabase/migrations -maxdepth 1 -type f -name '*.sql' | sort | awk 'END {print "MIGRATION_FILES:",NR}'
find supabase/functions -mindepth 2 -maxdepth 2 -type f -name 'index.ts' | sort | awk 'END {print "EDGE_ENTRYPOINTS:",NR}'
echo '=== Local configuration contract ==='
node --input-type=module <<'NODE'
import {readFileSync,existsSync} from 'node:fs';
const cfg=readFileSync('supabase/config.toml','utf8');
const example=readFileSync('.env.example','utf8');
const checks=[
 ['PostgreSQL 17 configured',/^major_version\s*=\s*17\s*$/m.test(cfg)],
 ['API exposes api schema only',/^schemas\s*=\s*\["api"\]\s*$/m.test(cfg)],
 ['Auth signup disabled by default',/^enable_signup\s*=\s*false\s*$/m.test(cfg)],
 ['No anonymous Auth signup',/^enable_anonymous_sign_ins\s*=\s*false\s*$/m.test(cfg)],
 ['Browser publishable key placeholder documented',example.includes('VITE_SUPABASE_PUBLISHABLE_KEY')],
 ['Release readiness documentation present',existsSync('docs/RELEASE-READINESS.md')]
];
for(const [label,ok] of checks)console.log((ok?'PASS: ':'BLOCKED: ')+label);
if(checks.some(([,ok])=>!ok))process.exitCode=2;
NODE
echo '=== Staging prerequisites (manual, no secret disclosure) ==='
echo 'REQUIRED: separate nonproduction Supabase project with PostgreSQL 17 compatibility confirmed'
echo 'REQUIRED: owner-approved staging project access, isolated synthetic identities and test data'
echo 'REQUIRED: hosted API exposure restricted to api, least-privilege grants and RLS verified'
echo 'REQUIRED: hosted Auth redirect/CORS origins and Edge secrets configured securely'
echo 'REQUIRED: migration dry-run, backup/rollback plan, explicit approval before staging writes'
echo 'NOT VERIFIED: staging project exists, permissions, remote migrations, Auth, Edge or HTTP flows'
echo 'PASS: offline staging preflight completed; no credentials displayed, network calls or database writes'
