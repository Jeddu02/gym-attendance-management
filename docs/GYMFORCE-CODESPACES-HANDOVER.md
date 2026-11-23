# GYMFORCE master audit and Codespaces handover

Prepared 2026-11-23, Asia/Manila. Source checkpoint: branch `master`, HEAD
`5283e35dcb64a72bbe96c89637f9167508401ffa`. This is a local development audit,
not a production release or a certification of hosted state.

**A02 PENDING OWNER DECISION. Production NO-GO. Codespaces runtime UNVERIFIED.**
No branch switch, staging, commit, push, hosted connection, SQL execution,
deployment, cloud provisioning or system-wide installation was performed.
The supplied attachment begins with a truncated title and a PowerShell/Linux
compatibility instruction, followed by sections 7–11. This report addresses its
available instructions and required final-report items without inventing missing
earlier authorization. AGENTS.md remains authoritative.

## Development progress and feature completion

“Implemented locally” describes source and synthetic testing, not production
acceptance. Historical counts below are identified separately from fresh checks.
The detailed chronology remains in GYMFORCE-DEVELOPMENT-PROGRESS.md.

| Capability | Local implementation / evidence | Remaining gate |
| --- | --- | --- |
| React + Vite + TypeScript shell | Implemented; responsive Owner portal and public routes | Real deployment/phone acceptance |
| PWA | Static shell, manifest, prompt-driven update handling, offline notice | Physical Android install/update and host/cache validation |
| Owner Auth | Password SDK flow, Owner status recheck, server getUser and SQL Owner checks | Actual local GoTrue login/refresh/Owner Edge integration BLOCKED; hosted bootstrap/access unverified |
| Owner-only administration | Members, plans, purchases, payments, receipt review, cash, reports, audit and claims screens exist | Actual hosted authorization and Owner workflow acceptance |
| Member registration | Member code, name, normalized unique mobile and server-side protection | Mobile change/suspension/privacy decisions |
| Monthly purchases/renewals | Option A month-clamp, inclusive expiry, delayed activation and consecutive renewal source/tests | Hosted financial/calendar acceptance; no future arbitrary prepaid overlap |
| Payments and receipt review | Whole receipt allocation, unmatched/underpaid review, immutable originals | Owner evidence standards and hosted workflow acceptance |
| Corrections | Reason/evidence, linked void/re-record and eligibility invalidation prepared | Separate independent eligibility resolution remains a policy/design gate |
| Member entrance | Identifier/PIN public handler; generic failures, internet required | Approved production KDF/abuse parameters, shared-network/DoS qualification |
| PIN setup/reset | Supervised one-use fragment-link flow, hashed verification, gates default unavailable | Token lifetime, identity procedure and production abuse approval |
| Walk-in requests | Opaque request, PHP fee snapshot, 15-minute lifetime, Owner payment confirmation | End-to-end Owner Auth and hosted acceptance |
| Request recovery | Atomic browser capability slot, versioned lookup/create and SQL replay binding | Production/browser retention and shared-browser disposal policy |
| Ingress controls | All-attempt charging, bounded leases/body/timeouts, separate committed admission | Provider isolation/capacity/fairness and complete operational campaign |
| Offline Owner claims | Provisional current-date physical-presence review; stale conflicts preserved | Persistent offline queue intentionally absent pending retention/privacy approval |
| Cash drawer | Verified cash including unallocated receipts; attested float/close/variance | Stale close procedure and actual Owner operations |
| Reporting | Attendance, confirmed income, cash distinctions, audit and CSV | Actual hosted totals/reconciliation; no native XLSX feature |
| Operational monitoring | Local aggregate monitor, durable queue, watchdog and deduplication tests | Production scheduler/storage/TLS/delivery/recipient/crash qualification |
| Database security | Private tables, FORCE RLS, narrow api RPCs, audited mutations | A02 authority, actual hosted ACLs/history/legacy and restore gates |
| Supabase Realtime | Service configuration exists; no general live subscription acceptance claimed | Justify specific use and validate privacy before enabling |
| Codespaces | Frontend devcontainer and prerequisite check prepared | First real Codespace install/check/private preview NOT RUN |

No checkout, refund, complimentary membership, member dashboard/login, grace
period, installment, freeze or automatic renewal was added. No feature approval
is inferred from this audit.

## Architecture and trust boundaries

React components in `src/components` use helpers in `src/lib` and a lazy public
Supabase SDK client. `src/App.tsx` coordinates Owner Auth and navigation; public
routes include `/entrance`, `/pin-setup`, and `/pin-reset`. Browser configuration
contains only URL and publishable key. The permanent entrance QR contains the
HTTPS entrance address, without member data or credentials.

Owner requests flow through Edge handlers that verify Auth using getUser, derive
the actor, and invoke narrowly granted `api` RPCs. SQL separately checks active
Owner access. Public member/PIN/walk-in handlers use scoped operations; members
have no Auth dashboard. Browser state, dates, amounts and offline claims are
untrusted. Private data tables are unexposed with FORCE RLS. `anon` and
`authenticated` have no application routine execution; service-role execution is
bounded and has no direct private table access. Production enforcement remains
a hosted acceptance gate.

Business dates use Asia/Manila. Receipt preservation, paid-purchase eligibility,
confirmed income and physical-cash accounting are distinct. Audit history and
original attendance/payment facts survive corrections. PWA caches contain the
static shell rather than API, member, payment or PIN payloads; the approved
request-recovery capability is a narrow, hash-scoped browser-storage exception.

## Database and migration status

There are 37 historical migrations in `supabase/migrations`, from
`20261028061728_initial_schema.sql` through
`20261110200000_operational_reports.sql`. No historical migration was edited.
Local config targets PostgreSQL 17, exposes only `api`, disables automatic
table exposure and public/anonymous signup, and contains no synthetic seed.
Configuration is local intention, not proof of hosted configuration.

`supabase/recovery` holds separately reviewed source manifests, compatibility
artifacts and additive candidates. Phase 6.1 keyed recovery, Phase 6.1B ingress
and `003-local-operational-controls.sql` remain distinct from historical
migrations. Do not copy them into migration history or automatically apply them
in Codespaces. Diagnostic files in `docs/production-preflight` remain unchanged.

Fresh validators check 75/75 reviewed migration/runtime HEAD blobs, additive
fingerprints, PG17/18 grammar (993 historical top-level statements), and the
diagnostic AST/read-only boundary. Grammar and hashes do not execute function
bodies or establish a hosted migration ledger, correct production data, RLS
runtime behavior or authority to apply DDL. A full-history checkout is required:
validation also references historical commit `01ceeab403e5689c0de0688893cdfba3e05f9c65`.

The most recent historical Batch 5 PG17.12 evidence is documented in
GYMFORCE-BATCH-5-AUTH-READINESS.md and the Phase 6.1B implementation report.
Those reports record 13 scoped local recovery scenarios PASS / 2 PARTIAL:
real Owner Auth and comprehensive limits/operations/provider qualification.
No database, PostgREST or persisted HTTP test was rerun in this migration audit.

## Dependencies and environment inventory

Fresh host: Windows x64, Node 24.21.0, npm 11.19.0, Git 2.56.0.windows.2.
`npm ls --depth=0` succeeded: React/React DOM 19.3.1, Vite 8.3.5, TypeScript
5.8.3, ESLint 9.39.5, PWA plugin 2.0.0, Supabase SDK 2.118.0, QRCode 1.5.4,
Supabase CLI 2.122.0; complete direct/transitive versions remain in package locks.
No runtime package or lockfile was added or upgraded. Separately locked parser
aliases are libpg-query 17.8.2 and 18.1.4 in `tools/recovery-parser`.
Deno PIN tests use `npm:hash-wasm@4.12.0` under `deno.lock`.

| Category | Names / source | Handling |
| --- | --- | --- |
| Browser | VITE_SUPABASE_URL, VITE_SUPABASE_PUBLISHABLE_KEY | `.env.example` has placeholders only; optional ignored `.env.local` for approved synthetic backend |
| Edge origin/API | APP_ORIGIN, SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY or SUPABASE_ANON_KEY | Exact origin required; owner-register-member currently reads SUPABASE_ANON_KEY specifically |
| Edge privileged credential | SUPABASE_SERVICE_ROLE_KEY | Server only; never VITE, browser, Git, logs or shared frontend environment |
| Mobile protection | MEMBER_MOBILE_ENCRYPTION_KEY_B64, MEMBER_MOBILE_HMAC_KEY_B64 | Server-only independent 32-byte keys; no migration of existing keys |
| Check-in protection | PUBLIC_CHECKIN_LOOKUP_HMAC_KEY_B64, DUMMY_PIN_HASH, CHECKIN_GLOBAL_LIMIT_PER_MINUTE, CHECKIN_IDENTIFIER_LIMIT_PER_MINUTE | Synthetic testing only until production KDF/abuse approval |
| Feature gates | PIN_SETUP_ENABLED, PIN_RECOVERY_ENABLED, PUBLIC_MEMBER_CHECKIN_ENABLED, PUBLIC_WALKIN_ENABLED, OWNER_OFFLINE_REVIEW_ENABLED | Leave unset/unavailable in new environment |
| Walk-in rate control | WALKIN_REQUEST_LIMIT_PER_MINUTE | Reviewed synthetic value only; not an assumed production threshold |
| Guarded SQL harness | GYMFORCE_TEST_RUN_ID, GYMFORCE_TEST_PSQL, GYMFORCE_TEST_CONNECTION, GYMFORCE_TEST_DATA_DIRECTORY | Generated by fresh guarded Windows harness, never manually repoint to another database |
| Local Edge bootstrap | GYMFORCE_HTTP_PORT plus validated run ID | Loopback only; never forwarded as a public API |
| Browser test override | CHROME_PATH | Absolute path to an approved installed native Chrome/Chromium; not an argument string |
| Synthetic JWT | In-memory random signing secret; short-lived anon/service tokens generated in test-persisted-http.mjs | Not real Auth; do not save or transfer tokens/secrets |
| Synthetic database | Fresh cluster password/passfile; dedicated temporary transport password/config | Ignored protected run directory and harness cleanup; no production passwords |
| Real Auth future config | GOTRUE_* / DATABASE_URL / API_EXTERNAL_URL categories in Batch 6A manifest | NOT configured or authorized here; startup automatically migrates Auth schema |

No test-only secret needs to be committed or entered as a shared Codespaces
secret. No real member data is required. The developer's ordinary gym membership
does not confer Owner, database or production access.

## Codespaces preparation and compatibility

`.devcontainer/devcontainer.json` selects the official Node 24/Bookworm image
`mcr.microsoft.com/devcontainers/typescript-node:5.2.5-24-bookworm`, runs as
nonroot `node`, and installs existing locked frontend packages with
`npm ci --ignore-scripts --no-audit --no-fund`. The versioned tag is based on
the [official image manifest](https://github.com/devcontainers/images/blob/main/src/typescript-node/manifest.json);
the image was not pulled, digest-verified or started here. Record its resolved
digest and actual Node/npm versions during the first Codespaces qualification.
No Docker-in-Docker, database service, Auth download, secret mount, privileged
mode, automatic migration or background server is configured.

Only frontend port 5173 is explicitly forwarded. Other auto-forwarding is
disabled/ignored; this does not prevent a user manually forwarding a port.
The JSON is syntactically valid and passes the project boundary check; full
upstream schema validation and image installation remain UNVERIFIED.
`npm run dev:codespaces` binds Vite to 127.0.0.1:5173 with strictPort. Loopback
serving is tested locally; forwarding through GitHub and HMR/WebSocket behavior
must be tested in a real Codespace. Do not add broad allowedHosts or expose
0.0.0.0 merely to silence a failed preview. Investigate the actual host/proxy.

Forwarded ports must stay **Private** in the Ports panel. Port attributes do
not enforce GitHub visibility. Never forward SQL, Auth, PostgREST, Edge test,
Chrome debugging or monitoring ports. GitHub explains private port access and
forwarding in its [port documentation](https://docs.github.com/en/codespaces/developing-in-a-codespace/forwarding-ports-in-your-codespace).

| Workflow | Linux/Codespaces assessment |
| --- | --- |
| npm ci, lint, typecheck, build, security, Node tests | Portable entrypoints; installed Windows dependencies pass; clean Linux npm installation NOT RUN |
| Separate recovery parser install/validators | Portable WASM/Node path; run separate npm ci and retain full Git history |
| Deno unit/type checks | Native Linux Deno and locked/cached npm artifacts needed; not included in frontend container |
| Browser smoke | Runner now accepts absolute CHROME_PATH, defaults to Windows Chrome or /usr/bin/chromium; Linux binary/library/sandbox qualification pending |
| Windows SQL harness | BLOCKED on Linux: .exe names, WindowsIdentity ACLs, Set-Acl, Start-Process options and native utility resolution |
| Persisted HTTP harness | BLOCKED on Linux: pinned PE/DLL checks, semicolon PATH, SystemRoot/LOCALAPPDATA and hardcoded Windows Chrome/PostgREST/Deno |
| Recovery reproducibility script | BLOCKED on Linux: explicit cmd.exe/npm.cmd invocation; do not relabel as cross-platform |
| Portable Windows PG/PostgREST bundles | Remain ignored local artifacts; cannot execute in Linux |
| Real Auth | BLOCKED: Batch 6A is a proposal, not acquisition/build/startup authorization |
| Supabase CLI/Docker stack | Package is locked but CLI scripts are suppressed; no Docker feature or approved stack bootstrap supplied |

Installing PowerShell on Linux alone would not fix these native runtime,
permissions, connection-identity and cleanup assumptions. Existing Windows
workflows were preserved. The browser-path override and read-only Node
prerequisite checker are the limited portable additions. A safe Linux database
port needs a fresh-cluster guard, restrictive POSIX credentials, SCRAM identity,
PG environment rejection, version/provenance checks, transactional refusal/race
coverage, owned-process shutdown and credential cleanup before SQL execution.
Do not replace that work with psql against an ambient DATABASE_URL.

## Test results and evidence from this audit

| Command / check | Fresh result |
| --- | --- |
| npm.cmd run lint | PASS |
| npm.cmd run typecheck | PASS |
| npm.cmd run test:security | PASS static source boundary; not a credential/RLS proof |
| npm.cmd run build | PASS including PWA service worker generation; one run reported slow PWA callback timing, exit 0 |
| node --test tests/*.test.mjs | PASS 93/93; zero failed, skipped or cancelled; includes actual loopback Vite test |
| node scripts/recovery/validate-source.mjs | PASS original/additive/operational fingerprints and PG17/18 grammar |
| node docs/production-preflight/sql-editor/validate.cjs | PASS 16 diagnostic files for both parser majors; originals unchanged; no SQL executed |
| npm.cmd run check:codespaces | PASS JSON/restricted configuration/Node checks; missing backend commands reported, not treated as suite passes |
| npm.cmd ls --depth=0 | PASS installed direct dependency inventory |
| git diff --check | PASS; Git emitted informational LF/CRLF conversion warnings |
| Deno shared tests and 23 Edge/bootstrap checks | PASS 109/109 and 23/23 checks using documented manual mode outside sandbox |
| node scripts/test-browser.mjs; node scripts/test-browser.mjs --production | PASS both on Windows outside sandbox; synthetic Auth/API only |
| PostgreSQL/PostgREST integration | NOT RUN; historical results remain attributed to Batch 5 |
| Container image build, Linux npm ci, private forwarding/HMR | NOT RUN; Codespaces runtime UNVERIFIED |

An initial sandboxed Deno execution was access-denied. An execution outside the
sandbox with automatic node module resolution failed cached-only dependency
discovery for @types/qrcode. The retry uses the existing documented manual mode:

```sh
deno test --cached-only --node-modules-dir=manual --allow-read=supabase/functions --allow-env=MEMBER_MOBILE_ENCRYPTION_KEY_B64,MEMBER_MOBILE_HMAC_KEY_B64 supabase/functions/_shared
deno check --cached-only --node-modules-dir=manual supabase/functions/*/index.ts scripts/recovery/serve-local-edge.ts
```

These Unix globs are expanded by the shell; Windows verification used an explicit
PowerShell path list and the installed WinGet Deno executable. In a fresh Linux
environment cached-only will fail until separately reviewed dependency acquisition
is performed. Do not interpret a missing cache or denied executable as a pass.
The first sandboxed Chrome run timed out at isolated browser startup. The retry
uses the same synthetic loopback suite outside the sandbox. Browser tests mock
Auth/API responses; they cannot prove real GoTrue, RLS or hosted behavior.
Both retry suites exited 0. Production installability diagnostics contained zero
errors; this is Chrome emulation, not physical Android acceptance. Screenshots
and browser profiles remain ignored in `.cache/browser-test-*`, not checkpoint
content. The dev/production successful run IDs were
`6b547980-e1ac-4967-9287-2abe2d497703` and
`4e269d96-a670-429a-9be3-3e42d48f4a33`.

Foundation checks were also executed directly through the installed ESLint,
TypeScript and Vite Node entrypoints plus scripts/check-source-security.mjs;
all exited 0. No additional test result is inferred from that duplicate check.
The npm chain and direct check overlapped; both completed successfully. The
source inventory and redacted scan/preservation summary are reproducible local
audit evidence in ignored `.cache/migration-audit-2026-11-23/`; tool output and
the exact commands above establish the fresh test scopes.

## Security, privacy and preservation audit

All tracked/nonignored files were byte-read for the source inventory and a
redacted pattern scan. Candidate changes were inspected along with their
manifests/tests. No environment contents, local database rows, browser profile
contents or private test evidence were read into the report. No secrets were
copied to container configuration. The `.env.example` contains placeholders only.

The scan checked private-key headers, GitHub token patterns, Supabase secret-key
patterns, JWT literals and credential-bearing URLs without printing values.
Two findings were reviewed: qualify-http-faults.mjs has an intentionally invalid
JWT negative test; test-persisted-http.mjs builds a loopback URI from a fresh
random synthetic password. Neither is an embedded usable credential. Existing
source-security checks also pass. No apparent real customer/member dataset was
identified in source/candidates; synthetic fixtures are test data. This bounded
scan is not a forensic Git-history scan, high-entropy detector or legal privacy
review, and does not certify that secrets never existed in history.

Ignore coverage now explicitly includes executable/library artifacts, PID files,
private key material, common browser profile and database-data directories, in
addition to existing env/cache/dependency/build/backup/private-evidence rules.
Representative check-ignore probes passed. Existing tracked files are not made
safe merely by ignore rules; the tracked source inventory was scanned separately.
No ignored files were force-added, copied or proposed for the checkpoint.

At entry Git status listed 20 paths; one was src/style.css with no substantive
diff (line-ending/stat normalization). Its bytes were not edited. The 19
substantive original candidates were fingerprinted in ignored audit evidence.
All remained byte-identical except package.json, where two portable script
entries were added without removing earlier work. Original historical migrations,
approved source fingerprints and diagnostic artifacts remain unchanged. No
destructive filesystem action, reset, restore, cleanup or project-file deletion
was performed by the audit. Existing tests manage their own temporary fixtures.

Ignored local state is deliberately not a migration payload: `.env.local`,
`.cache` (portable binaries, synthetic clusters, browser profiles, logs and
private evidence), `backups`, `node_modules`, `dist`, `.vscode`, debug logs,
batch inspection scratch text and style backups stay local. Git internals stay
in Git. Recreate dependencies from locks; do not upload a workspace ZIP.

## Full file inventory and proposed Git checkpoint

See [the complete source inventory](GYMFORCE-MIGRATION-FILE-INVENTORY.md) for all
528 tracked and nonignored untracked paths, disposition, size and purpose. Nothing
is staged. The exact proposed candidate list is below; src/style.css is excluded
because there is no content change to stage. Recheck before Owner approval:

```text
.devcontainer/devcontainer.json
.env.example
.gitignore
README.md
docs/GYMFORCE-BATCH-5-AUTH-READINESS.md
docs/GYMFORCE-BATCH-6A-GOTRUE-ACQUISITION-MANIFEST.md
docs/GYMFORCE-CODESPACES-HANDOVER.md
docs/GYMFORCE-DEVELOPMENT-PROGRESS.md
docs/GYMFORCE-MIGRATION-FILE-INVENTORY.md
docs/GYMFORCE-PHASE-6-1B-INGRESS-IMPLEMENTATION.md
package.json
scripts/check-codespaces.mjs
scripts/recovery/durable-ingress-ops.mjs
scripts/recovery/ingress-monitor.mjs
scripts/recovery/qualify-http-faults.mjs
scripts/recovery/serve-local-edge.ts
scripts/recovery/validate-source.mjs
scripts/test-browser.mjs
scripts/test-database.ps1
scripts/test-persisted-http.mjs
scripts/test-recovery-pg17.ps1
supabase/recovery/phase61b/003-local-operational-controls.sql
supabase/recovery/phase61b/operational-manifest.json
supabase/tests/public_walkin_clock_boundaries.sql
tests/durable-ingress-ops.test.mjs
tests/ingress-monitor.test.mjs
tests/persisted-http-guard.test.mjs
```

Recommended message: `chore: checkpoint local ingress qualification and prepare Codespaces handover`.
This includes existing local qualification work so a clone does not lose required
scripts, SQL candidates, manifests or tests. It does not approve those candidates
for hosted migration. Review the entire inventory and diff, rather than using
`git add .`. Staging, commit and push each remain unauthorized in this task.
Use a separately approved development checkpoint branch; do not update the
production branch. No remote URL or account details are reproduced here.

## Exact next steps for the Owner and next developer

1. Review this report, all 27 candidate files and the complete diff. Resolve any
   requested review changes, then authorize the checkpoint branch, explicit
   staging list, commit and push. None has been performed here.
2. After the approved checkpoint exists on GitHub, choose that development branch
   in Code > Codespaces > Create codespace on the selected branch. Check available
   included usage first and keep paid usage disabled; do not provision a Codespace
   from the production branch. This step is future Owner action, not authorization
   to create a resource during this audit.
3. Let postCreateCommand install locked frontend packages with scripts disabled.
   If image pull/install fails, retain redacted evidence; do not change dependency
   versions, run unreviewed installers or enable backend services to bypass it.
4. In the Codespaces terminal run `node --version`, `npm --version`,
   `npm run check:codespaces`, and `git status --short`. Confirm Node 24, branch,
   source checkpoint and absence of production credentials without printing env.
5. Run `npm ci --prefix tools/recovery-parser --ignore-scripts --no-audit --no-fund`,
   then lint, typecheck, source security, `node --test tests/*.test.mjs`, build,
   source validation and diagnostic validation using the commands above. Record
   each result explicitly as Codespaces/Linux evidence. If Git objects are missing,
   obtain the approved full history; do not disable integrity checks.
6. Run `npm run dev:codespaces`. In Ports confirm 5173 is Private, open its HTTPS
   forwarded URL, and verify shell/entrance rendering and HMR after a harmless
   local edit. Verify env/cache URLs are refused without retrieving secrets.
   No backend is needed for build or shell preview; missing configuration is
   expected for protected actions. Preview is not a working management service.
7. If a synthetic backend is later authorized, use only newly generated synthetic
   settings. For shared development environment secrets, the Owner can create
   account-specific Codespaces secrets restricted to the chosen repository and
   restart the Codespace as GitHub instructs. Only URL/publishable key may use
   VITE names; server secrets belong in isolated server processes, never the
   frontend/container configuration. Do not transfer existing secrets or grant
   the Developer production credentials. See GitHub's
   [secret setup guide](https://docs.github.com/en/codespaces/managing-your-codespaces/managing-your-account-specific-secrets-for-github-codespaces).
8. Stop at frontend qualification until the native Linux Deno/browser and fresh
   PostgreSQL/PostgREST harness ports are reviewed. Do not run existing Windows
   database/HTTP npm scripts in Linux or start the Supabase/Auth stack as a shortcut.
9. Record container digest, tool versions, install/test/preview evidence and all
   failures before changing Codespaces readiness from UNVERIFIED. Stop the
   Codespace when idle; storage usage persists until its eventual Owner-managed
   removal. GitHub documents [included usage limits](https://docs.github.com/en/codespaces/troubleshooting/troubleshooting-included-usage);
   this product requires no paid plan or custom domain.

## Remaining development milestones and blockers

1. Owner review/checkpoint approval and actual frontend Codespaces qualification.
2. Reviewed native Linux test dependency acquisition and safe isolated SQL/HTTP
   runner port; do not reuse Windows bundles or weaken version/identity checks.
3. Resolve real Auth provenance/acquisition/build approval, then separately review
   startup/schema/role isolation and run the nine-case real Owner Auth campaign
   in Batch 5. Batch 6A source metadata is historical, not a new version recommendation.
4. Complete ingress stress/fairness/provider and durable operations acceptance,
   including independent alerting, recipient, protected storage and crash behavior.
5. Resolve A02 and separately authorized hosted authority/ACL/history/legacy/restore
   gates. Existing local bootstrap authority does not establish hosted permission.
6. Obtain remaining Owner policies: PIN lifetime/KDF/abuse, mobile change and
   security suspension, privacy/retention/incident response, stale queue/drawer
   review, evidence standards, backup/recovery/key custody and shared-device cleanup.
7. Complete physical Android/PWA, QR, HTTPS/headers/SPA/cache, financial/attendance
   and operational acceptance; obtain a separate production release decision.

The next assistant should read AGENTS.md, this handover, the progress tracker,
Phase 6.1B evidence, Batch 5, Batch 6A and the release/recovery readiness documents
before proposing further work. Preserve their distinctions between local source,
synthetic evidence, Owner approvals and hosted production authority.
