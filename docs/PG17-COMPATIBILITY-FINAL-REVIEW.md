# GYMFORCE PG17 compatibility final review

## Current result: Owner-authorized final local hardening, 2026-11-17

**R02, R03, R04 and R05: PASS for the implemented local scope. Production:
NO-GO. R01 provider ADMIN dependency and R06 hosted execution/history design
remain open.** This section supersedes the four findings and older test results
in the historical review retained below. No production connection, SQL, data,
privilege/configuration change, migration-history write, commit or deployment.
HEAD remains `db700c1f42cdf561e3f55d61897ba8eb4948c94e`.

### Finding-by-finding correction and independent evidence

| Finding / root cause | Exact implementation files | Correction and verified evidence | Status / remaining limits |
| --- | --- | --- | --- |
| R02: predicate-only fixtures did not run real migration refusals | `scripts/test-database.ps1` | Eleven stage-specific cases now execute the actual P01/P07/P13/P14 source or compatibility file, require expected message and SQLSTATE P0001, close the failed session and compare catalog plus complete protected-row SHA-256 snapshots. All eleven pass under the real non-superuser customer and unchanged engine control. | **PASS locally.** Synthetic state only; no hosted data verdict or exhaustive arbitrary-corruption claim. P13 fixture method and cleanup are explained below. |
| R03: unrecorded parser packages were loaded from ignored cache | `tools/recovery-parser/package.json`, `package-lock.json`, `README.md`; `scripts/recovery/parser.cjs`, `build-compatibility.mjs`, `validate-source.mjs`; `tests/recovery-compatibility.test.mjs`, `recovery-sql.test.mjs`, `recovery-tooling.test.mjs`; `scripts/test-recovery-reproducibility.mjs`; `docs/production-preflight/sql-editor/validate.cjs` | Same existing libpg-query versions pinned exactly: 17.8.2 and 18.1.4, four transitive package records with SHA-512 npm integrity. Explicit loader checks lock/installed versions and rejects unsupported/stale versions; no cache fallback. Fresh allowlisted workspace, absent root node_modules/historical cache and empty npm cache installs with npm ci/ignore-scripts, passes all 16 tests/validators and byte-identical generation of 42 artifacts. | **PASS locally.** Requires public npm access and trusted supplied lock. SRI/HTTPS installation is not a package signature or protection against later local file tampering. Root application dependencies/lock unchanged. |
| R04: existing archives were mislabeled as official downloads and only locally hashed | `scripts/setup-native-pg17.ps1`, `scripts/verify-native-pg17-archive.ps1`, `scripts/test-native-pg17-provenance.ps1` | Verifier obtains exact filename-bound SHA-256 from EDB's separate HTTPS checksum file with bounded timeouts and compares before extraction/execution. Setup records acquisition mode, observed download URL only for real downloads, version/build/x64 and publisher verification. Existing archive matches; invalid synthetic ZIP refuses before execution. | **PASS.** Publisher HTTPS checksum verified; no detached signature claimed. Network/checksum failure blocks setup. Old provenance is retained as historical evidence; fresh publisher verification is stored separately. |
| R05: password creation preceded outer try/finally | `scripts/test-database.ps1`, `scripts/test-recovery-cleanup.ps1` | All credential creation, port reservation and initialization now lie inside cleanup protection. Nested finally attempts each credential removal even if shutdown fails; secret variables are cleared. Five actual fault invocations verify expected failure, no temporary credential files and no active server marker. | **PASS for controlled failures.** Points: AfterCredential, BeforeInitdb, native InitdbFailure, AfterInitdb before startup, AfterStart. Abrupt process/OS death or filesystem denial can defeat cleanup; no universal power-loss guarantee. Removal failure is reported, never silently passed. |

Additional documentation changed in this hardening: `supabase/recovery/README.md`,
`supabase/recovery/compatibility/README.md`, this report and
`docs/PRODUCTION-RECOVERY-FINAL-READINESS.md`. These plus the files named above
are the **20 paths changed/added in this hardening step**. Older uncommitted
recovery work is preserved. Current total working tree: 94 paths (three tracked
modifications, 91 untracked), distinct from the historical 83-path entry inventory.
The tracked SQL Editor validator change is one loader line; none of its 16 SQL
scripts, original approved SQL or manifest checks changed.

### Legacy tests and preservation boundaries

`scripts/test-database.ps1` now supplies Save-LegacyData, Invoke-LegacyRefusal
and Invoke-LegacyStage. The eleven cases are:

- P01 normalized duplicate plan names.
- P07 active without approval, pending with approval and future approval.
- P07 active without dates, pending with dates, unpaid active term and wrong
  inclusive expiry. The expiry case has a genuine synthetic receipt, confirmed
  allocation and payment event through the real server RPCs, preventing a missing
  payment error from masking a lost expiry guard.
- P13 dated payment_review history.
- P14 existing open and closed legacy cash sessions.

Before and after each actual refusal, the harness hashes every complete synthetic
row in all private tables and public.gym_settings, plus any model history tables
if present, ordered deterministically. Catalog fingerprints cover inventoried
owners/ACLs/RLS/policies/routines/constraints/role graphs and metadata. Comparison
is exact; no raw member/payment/PIN/audit rows leave the synthetic server.
The actual runner-history ledger is absent at these stages; its unchanged
absence/model checks are not real Supabase runner/history certification.

No existing security trigger, RLS flag, policy, constraint or privilege guard is
disabled to seed legacy states. P13 uses a newly created, FORCE-RLS inherited
fixture table: PostgreSQL's actual parent SELECT encounters its dated review
row while the current parent's protective trigger remains intact. This tests
the actual migration refusal without manufacturing an illegal write through that
trigger. Only this isolated fixture table is dropped afterward. It is not a
production reconciliation technique or an assertion that a malformed parent row
can be inserted through the current API.

Most fixture records are removed using only their dedicated synthetic IDs.
The paid-expiry fixture retains its actual synthetic receipt/event/audit history;
after the unchanged-refusal assertion, setup restores only its deliberately
malformed pre-lifecycle term to the server calendar basis so forward replay can
continue. This is an explicit synthetic fixture action, not production data repair
or a claim that the migration corrected history. No existing financial history
is deleted, rehashed, relabeled or silently restored.

### PostgreSQL archive provenance

Official artifact: **PostgreSQL 17.12, build 1, Windows x64**,
`postgresql-17.12-1-windows-x64-binaries.zip`, 386263884 bytes.
Publisher SHA-256 and observed archive SHA-256 both equal:

```text
a2cd8a774389347b70be7748ac4a37ef43cb6ee539c5fc3e85ae264b15e4a04c
```

The local checksum is now compared with the independently retrieved publisher
file, not treated as publisher authenticity by itself. The exact
[EDB archive](https://get.enterprisedb.com/postgresql/postgresql-17.12-1-windows-x64-binaries.zip)
and [EDB SHA-256 file](https://get.enterprisedb.com/postgresql/postgresql-17.12-1-windows-x64-binaries.zip.sha256)
are on the publisher HTTPS host. EDB documents its sidecar checksum convention
in [its installer repository](https://github.com/EnterpriseDB/edb-installers/issues/801).
Trust boundary: publisher publication over authenticated HTTPS, not a detached
signature or protection against publisher compromise. PG18/services/PATH untouched.

### Final verification commands and fresh evidence

All of the following passed after the relevant changes:

| Actual command/check | Result |
| --- | --- |
| `scripts/test-recovery-pg17.ps1 -CustomerCompatibility` through powershell.exe -NoProfile -ExecutionPolicy Bypass -File | PASS: actual PG17.12/170012, eleven real refusals, preserved data/catalog snapshots, all nine races, rollback/ACL/default/inherited-denial/security suites, cleanup. |
| Same launcher with `-CustomerCompatibility -TestLegacyAuditRefusal` | PASS: incompatible stored audit refuses P06, original hashes/catalog preserved, server stopped. |
| Same launcher with no switches | PASS: all 37 originals, eleven refusals, nine races and original non-superuser refusal controls; engine control remains separate. |
| `scripts/test-recovery-cleanup.ps1` | PASS five initialization failure points; no credential files or active server markers; logs checked for literal password SQL. |
| `scripts/test-native-pg17-provenance.ps1` | PASS valid publisher comparison and invalid-archive refusal. |
| `node scripts/test-recovery-reproducibility.mjs` | PASS fresh npm ci/SRI from empty cache, 16 tests, both grammars, original hashes, SQL Editor checks and 42 byte-identical generated artifacts. |
| `npm.cmd run lint`; `npm.cmd run typecheck`; `npm.cmd test`; `npm.cmd run test:security` | PASS; 38 application Node tests. |
| Four recovery Node files including `tests/recovery-tooling.test.mjs` | PASS 16/16, also verified in the clean room. |
| Cached Deno shared tests and checks on all 21 entrypoints | PASS 105/105 and 21/21. No dependencies downloaded or functions deployed. |
| `npm.cmd run build`; `node scripts/test-browser.mjs --production` | PASS complete PWA build and browser/mobile/empty/error/retry/security/cache fixtures; no external application requests. |
| Source/hash validators, PowerShell syntax, `git diff --check` | PASS. Original 37 migration/21 endpoint/17 shared runtime hashes unchanged; no application/config/lock/env-template differences. Git future line-ending warnings concern three tooling files only. |

Private ignored evidence:

- Final customer: `.cache/security-test-ff3be9a6addd4c4caa356f71e2c2af90`.
- Audit refusal: `.cache/security-test-f07b325e6c284fa59a0f1100f33fb04b`.
- Engine control: `.cache/security-test-8bdcde3ec4ba408c9f6a0c26a5afc250`.
- Fault cases: `.cache/cleanup-test-04438ac14f9c4e2a813373a6f10a5580.json`.
- Clean room: `.cache/parser-repro-lQWssL` (final run, including clean scratch-directory setup).
- Publisher evidence: `.cache/pg17-portable-17.12/publisher-verification.json`.
- Browser: `.cache/browser-test-b64d6475-68ca-47dc-a1d9-b35b8d1130b7`.

Independent post-run checks confirmed eleven identical before/after data snapshots
in each full profile, actual 170012 servers, stopped clusters and removed temporary
credentials. Customer final state still has exactly four provider ADMIN edges,
zero unexpected edges/maintenance policies/effective CREATE/SET/inheritance leaks.
The clean room initially exposed missing SQL fixture inputs and a new test's
assumption that its scratch directory already existed; both test-prerequisite
defects were corrected and the final completely fresh run passed. An initial
one-off expected checksum failure needed PowerShell stderr handling; the dedicated
regression script now checks the native failure explicitly and passes.

### Remaining production gates

R01 is **NOT VERIFIED / REQUIRES OWNER APPROVAL**, not resolved by these local
fixes. Provider-controlled ADMIN, actual hosted session/schema/extension privileges,
safe maintenance visibility and the revised trust boundary still require separate
evidence and approval. R06 truthful forward-artifact/history execution strategy is
also still held. A03 real creators/defaults/inherited grants, A04 actual legacy
records/three present markers, A07 hosted definitions/history, backup/restore,
real isolated Auth/Edge/PostgREST tests and production release remain NOT VERIFIED.
Existing production preflight scripts 03-07 remain held. No hosted action is
authorized by this document. **Local four-finding hardening PASS; production NO-GO.**

---

## Historical review before final local hardening

Everything below records the earlier review and its then-current findings,
source line numbers and entry inventory. The current section above supersedes
R02-R05 status, tooling prerequisites and test results. Historical source line
numbers are not references to the now-extended test harness.

Reviewed 2026-11-17, Asia/Manila. Branch `review/production-recovery`, unchanged
HEAD `db700c1f42cdf561e3f55d61897ba8eb4948c94e`.

**Local execution acceptance: PASS within the synthetic scope. Owner review:
ready with findings. Unqualified recovery/reproducibility certification: withheld.
Production: NO-GO.** Three fresh PG17.12 profiles and all requested application
checks passed. Provider authority, production metadata/data and an approved
artifact/history execution mechanism remain unverified. No production SQL,
privilege/configuration/data changes, historical migration edits, commits,
pushes, merges or deployments occurred.

Only this report was added by the review. The builder was rerun to verify
determinism: all 42 generated SQL/manifest artifacts remained byte-identical.
Test/build outputs are ignored. Findings below are reported without changing
implementation files, original diagnostics or earlier reports.

## 1. Scope and exact inventory

The entry working tree contained **83 paths: two tracked modifications and 81
untracked files**, not twelve. Twelve latest changes cannot be reconstructed
independently from Git because the recovery files were never committed and no
immutable twelve-file intermediate snapshot was supplied. The thirteen directly
related hand-maintained paths below were reviewed, along with their generated
artifacts and supporting recovery inputs. Appendix A preserves the exact complete
entry inventory. This new report makes the final count 84 paths, assuming no
concurrent user changes.

| Path | Git state at entry | Reviewed behavioral/security change |
| --- | --- | --- |
| `scripts/test-database.ps1` | Modified | Actual non-superuser SCRAM customer replay, manifest checks, provider fixture, rollback/ACL/diagnostic assertions, private fresh clusters and cleanup. Complete tracked diff reviewed. |
| `scripts/test-db-concurrency.mjs` | Modified | Explicit synthetic provider profile for fixture administration and same-session target guard; racer calls still switch to service_role. Complete tracked diff reviewed. |
| `scripts/recovery/build-compatibility.mjs` | Untracked | Forward compatibility generation, exact-edge authority contract, transactional prepare/cleanup, scoped SELECT maintenance policies, dependency check and source/body/hash verification. |
| `scripts/setup-native-pg17.ps1` | Untracked | Portable archive acquisition/extraction and local provenance; no service/PATH changes. |
| `scripts/test-recovery-pg17.ps1` | Untracked | Cached native PG17 selection, major guard and forwarding of customer/refusal modes. |
| `supabase/recovery/diagnostics/compatibility-authority.sql` | Untracked | Read-only actor/provider graph/schema/digest/cleanup metadata, one JSON result. |
| `supabase/tests/compatibility_security_behavior.sql` | Untracked | Actual customer SET ROLE/data denials, browser/service RPC permissions and future defaults; fixture rollback. |
| `supabase/tests/compatibility_legacy_diagnostics.sql` | Untracked | Synthetic old-table/view/policy fixture, actual read-only dependency query, fixture-only removal. |
| `tests/recovery-compatibility.test.mjs` | Untracked | Both artifact profiles, SHA checks, full application function AST equivalence and maintenance-policy scope. |
| `tests/recovery-sql.test.mjs` | Untracked | Cached PG17/18 AST validation of catalog-only read-only diagnostics. |
| `supabase/recovery/README.md` | Untracked | Current/historical test distinction, held diagnostics, proposals and recovery limitations. |
| `supabase/recovery/compatibility/README.md` | Untracked | Revised ADMIN boundary, lifecycle of temporary capabilities, artifacts, commands and hosted gates. |
| `docs/PRODUCTION-RECOVERY-FINAL-READINESS.md` | Untracked | Current runtime/results, corrected prior evidence overwrite, remaining production gates. |

Generated scope: `supabase/recovery/compatibility/review/` contains 19 SQL files
and one manifest; `synthetic/` contains 21 SQL files and one manifest. Both
manifests enumerate exact filenames, original/artifact SHA-256 and provider.
The remaining 28 entry paths are earlier recovery documentation/tools/proposals/
fixtures, listed in Appendix A. Untracked contents were included in the inventory
and bounded credential-pattern scan; the supporting manifests, ACL proposals,
catalog/comparison and legacy diagnostics were also inspected for this review.

## 2. Security and compatibility findings

### R01 — HIGH release gate: provider-controlled ADMIN edges remain required

`scripts/recovery/build-compatibility.mjs:16` and `:24` accept only the exact
provider-granted ADMIN=true, SET=false, INHERIT=false edge to postgres for each
reserved role. `:47` uses that authority to grant a separate customer-granted
temporary edge. The local provider bootstrap is `gf_provider_admin`; hosted
artifacts require `supabase_admin`. Customer postgres cannot manufacture a grant
recorded as that provider or independently revoke the provider's edge.

Supabase documents that PG16+ role creation supplies this ADMIN edge and that
customer postgres cannot remove it or become supabase_admin. It also documents
that passwordless CLI execution may use a different session login. Therefore a
supported documented basis exists, but the exact project/runner must still be
verified. These artifacts require both SESSION_USER and CURRENT_USER postgres:
a cli_login_postgres session that merely SET ROLEs to postgres will refuse.
[Official Supabase grantor/membership guidance](https://supabase.com/kb/troubleshooting/cant-revoke-a-role-membership-granted-by-supabase_admin-d08922).

Retained ADMIN is permanent administrative power even with SET/INHERIT off.
It is a deliberate departure from the original zero-membership contract, not
complete removal of migration authority. Only the temporary customer-granted
SET/INHERIT edges, schema CREATE and maintenance policies are removed. Hosted
adoption of this trust exception and custody of the administrator require Owner
approval; no ordinary Developer/member identity may hold it.

### R02 — MEDIUM coverage gap: legacy fixtures do not exercise every DDL refusal

`supabase/tests/recovery_legacy_behavior.sql:7` inserts duplicate plan names and
checks a GROUP BY; `:16` inserts a drawer row and checks EXISTS. Both roll back
before the relevant migrations run. These prove the synthetic anomaly predicates
are detected, **not** that P01's duplicate guard or P14's legacy-drawer refusal
actually aborts its complete migration and restores metadata under the redesigned
actor. The fresh audit-negative profile does execute the actual P06 refusal.

Required additional acceptance before treating legacy refusal coverage as complete:
stage-specific isolated fixtures executing the real P01/P07/P13/P14 variants
against incompatible synthetic states, asserting the intended SQLSTATE/message,
unchanged owners/ACLs/RLS/rows and no temporary capabilities after session closure.
Production data remains UNKNOWN regardless of those future synthetic tests.
This review did not modify the tests to fill the gap.

### R03 — MEDIUM reproducibility limitation: fresh checkout lacks parser setup

`scripts/recovery/build-compatibility.mjs:7` and recovery tests import parser
packages directly from ignored `.cache/foundation-parser/node_modules/pg17`
(and pg18 for diagnostics). Existing cached tooling worked and regeneration was
deterministic; a clean clone plus the root package lock alone does not install
these parser dependencies. No new dependency was installed during review.

Before claiming fresh-machine reproducibility, review and document a pinned
parser/tool bootstrap and verify it from an empty cache in an approved local
environment. Archive/version selection is not an independently authenticated
package supply-chain proof. Native PostgreSQL alone also cannot reproduce
Supabase Auth, PostgREST, supautils, hosted schemas or provider policies.

### R04 — LOW confirmed metadata defect: supplied archive provenance overstates origin

`scripts/setup-native-pg17.ps1:41` always records source=officialUrl and `:43`
claims official HTTPS acquisition, even when `-ArchivePath` bypasses the download
branch at `:12`. A local hash and a binary reporting 17.12 do not establish where
a supplied archive came from. No untrusted archive was executed in this review.
The current cache was acquired through the documented official download path;
this finding concerns the reusable existing-archive branch.

Recommended correction in a separately approved follow-up: record acquisition
mode and distinguish asserted source from observed download provenance; validate
an Owner-approved digest/source before executing a supplied archive. Do not
describe the current script as a signature verifier.

### R05 — LOW cleanup limitation: setup errors before try can retain a synthetic secret

`scripts/test-database.ps1:65` writes bootstrap-password; the outer try/finally
starts at `:243`, with port reservation and other setup in between. A terminating
error in that interval can leave this synthetic password file without reaching
the cleanup at `:489`. The private run-directory ACL is set first, and no server
has started in that interval. This pattern is substantially inherited from the
existing harness; it is not evidence of production credential exposure.

Consequently “fully cleaned after every failure” is too broad. Move credential
creation/setup under cleanup protection in a future fix and add an injected
pre-init failure check. Ordinary completion and the tested SQL failures did
remove credential files. Abrupt OS/process termination and every arbitrary
statement/network failure were not tested.

### R06 — Release process gate: no executable hosted history/provenance strategy

Artifacts retain the original version filenames but differ in contents and live
outside automatic migration discovery. Manifests truthfully record changed
artifact hashes and no history action. No tool repairs/marks history applied.
This is safe preparation, not a finished Supabase CLI migration deployment path.
Owner must approve a runner/provenance/bookkeeping design that records actual
executed bytes without falsely adopting them as original historical migrations.

## 3. Builder and temporary-authority review

The current reviewed implementation did not introduce a demonstrated runtime
authorization bypass or a statement disabling ENABLE/FORCE RLS. It is not a
general theorem that future generator edits cannot weaken security.

| Control | Verified result and limitation |
| --- | --- |
| Historical source identity | Exact 37 filenames and SHA values validated; 21 Edge and 17 runtime shared hashes unchanged. Git shows no changes to migrations, src, Edge runtime, config or package/lock files. |
| Application SQL bodies | Both profiles preserve every CREATE FUNCTION AST, including signature, result, language/configuration and body, ignoring parser locations/CRLF only. |
| Other original statements | Independent top-level AST comparison found seven adapted source DO guards and the intentional digest GRANT replacement; original remaining statements match as normalized ASTs. Added statements supply bounded settings, capability/cleanup guards and grants. Statement order was inspected through builder anchors and successful replay. |
| Assertion edits | `scripts/recovery/build-compatibility.mjs:92` performs anchored transformations; `scripts/recovery/build-compatibility.mjs:119` requires seven migration predicate changes by exact per-version counts. Original assertions are not deleted from source; generated assertions use the explicit ADMIN exception. Counts/hashes are safeguards, not independent authenticity signatures. |
| Role attributes | All four executor/data roles stay NOLOGIN, NOSUPERUSER, NOBYPASSRLS, NOINHERIT, NOCREATEROLE, NOCREATEDB, NOREPLICATION. Unexpected graph edges/options refuse. |
| Ownership checks | Temporary SET and inherited ownership plus destination CREATE allow ordinary PG17 owner/default-ACL operations; ADMIN alone is not treated as ownership. See [PostgreSQL membership semantics](https://www.postgresql.org/docs/17/role-membership.html) and [ownership transfer requirements](https://www.postgresql.org/docs/17/sql-altertable.html). |
| Schema CREATE | Data owner receives private (public in P05); executors receive api; cleanup revokes temporary CREATE and tests effective absence. No new unrestricted runtime schema creation is retained. |
| SELECT maintenance scope | P06 audit events/heads; P07 members/purchases/receipts/allocations/events; P13 purchases; P14 drawers only. Both CURRENT_USER and SESSION_USER must be postgres. Restrictive-policy conflicts refuse; no write policy is added. |
| RLS proof | Native operator is NOBYPASSRLS. RLS remains active with required synthetic SELECT visibility; INSERT is denied and UPDATE changes zero rows. That specific proof covers members, not every table/command combination. |
| Dependency authority | Provider-owned digest GRANT is replaced by existing effective EXECUTE prerequisite; no provider impersonation or generic privileged DDL endpoint is installed. Synthetic fixture supplies schema USAGE grant option and preinstalled pgcrypto explicitly. Hosted equivalents remain unknown. |
| Transactional cleanup | Every variant owns BEGIN/COMMIT and cleans temporary policies/customer edges/CREATE before commit. P05/P11 errors after first table transfer and inherited-ACL failures rolled back inventoried metadata through psql session closure. No cross-file atomicity claim. |
| Final state | Fresh customer diagnostic: four approved provider ADMIN edges; zero unexpected edges, maintenance policies, effective CREATE or operator SET/inherited paths. Provider ADMIN edges deliberately remain. |
| Failure evidence | Unexpected application membership refuses P06; incompatible UTC audit refuses without rewriting hashes. Tested paths pass; R02/R05 delimit missing failure coverage. |

The hosted review profile permits a pre-existing migration-operator BYPASSRLS
attribute without granting one. All application roles must remain NOBYPASSRLS.
The synthetic operator deliberately lacks bypass, demonstrating no dependency
on it. Actual hosted inherited privileges, extension ownership/grants, provider
role graph, RLS visibility and runner login are not certified by that fixture.

## 4. Fresh commands and results

All commands below actually ran for this review. SQL execution was restricted
to new isolated local synthetic clusters. No .env contents or production
credentials were read. Cached dependencies were used.

| Command / check | Result |
| --- | --- |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-recovery-pg17.ps1 -CustomerCompatibility` | PASS: real customer SCRAM session, 24 originals + 13 variants, phase behavior suites, all nine races, two transfer rollback probes, unsafe graph refusal, ACL replay/inherited refusal/default tests, diagnostics and cleanup. |
| Same command plus `-TestLegacyAuditRefusal` | PASS: actual incompatible-chain refusal at P06, original hashes and catalog preserved; stops intentionally before later stages. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-recovery-pg17.ps1` | PASS: all 37 unchanged originals under engine-control superuser; real non-superuser P05/P11 refusal/rollback controls, nine races, ten final privilege screens. Not hosted authority proof. |
| `npm.cmd run lint` | PASS |
| `npm.cmd run typecheck` | PASS |
| `npm.cmd test` | PASS 38/38 |
| `npm.cmd run test:security` | PASS |
| `node --test tests/recovery.test.mjs tests/recovery-sql.test.mjs tests/recovery-compatibility.test.mjs` | PASS 14/14 |
| Existing Deno binary: `test --cached-only --node-modules-dir=manual --allow-read=supabase/functions --allow-env=MEMBER_MOBILE_ENCRYPTION_KEY_B64,MEMBER_MOBILE_HMAC_KEY_B64 supabase/functions/_shared` | PASS 105/105; synthetic values, including real all-21-entrypoint preflight/Auth/gate regressions. |
| Same binary: `check --cached-only --node-modules-dir=manual` followed by all 21 exact endpoint index.ts paths | PASS 21/21; directory count asserted. |
| `npm.cmd run build` | PASS, including completed PWA output. PWA closeBundle warning: roughly 294 seconds; performance observation, not build failure or server timing. |
| `node scripts/test-browser.mjs --production` | PASS: mobile Owner/public QR/PIN, failed-list/empty/retry/payment/walk-in and static-only cache regressions; zero external app request attempts. Synthetic Auth/API fixtures, not hosted E2E. |
| `node scripts/recovery/build-compatibility.mjs` and `--synthetic` | PASS: 42 before/after artifact byte hashes identical. No original SQL executed by generator. |
| `node scripts/recovery/validate-source.mjs` | PASS: unchanged 37/21/17 SHA inventory; PG17/18 grammar, 993 top-level migration statements each. |
| `node docs/production-preflight/sql-editor/validate.cjs` | PASS: all 16 original variants/source hashes unchanged, exact read-only AST/text/columns. |
| Independent normalized source/generated AST comparison | PASS: seven adapted source DO blocks across 13 variants. Initial one-off probe included parser locations and was corrected; no implementation change was needed. |
| PowerShell parser on three runner/setup scripts; `git diff --check` | PASS. Git warns future LF-to-CRLF conversion for the two tracked harness files; no historical SQL/application conversion. |
| Bounded high-confidence credential literal scan | Zero candidates among 83 entry changed/untracked paths; no .env files read. Not a comprehensive secret-detection guarantee. |
| Actual Supabase SQL/Auth/PostgREST/Edge integration, hosted configuration, production recovery/restore/deployment | NOT RUN / NOT VERIFIED |

### Nine concurrency scenarios

All nine passed in the fresh customer suite and unchanged engine control:
payment-record, payment-confirm, token-redeem, audit-append, daily-checkin,
walkin-confirm, receipt-allocation, claim-confirm and void-checkin.
The driver observes both sessions blocked on a database lock before releasing
the blocker, switches racer calls to service_role, and checks resulting
cardinality/idempotency/audit/void behavior. Bootstrap arranges fixtures and
locks; it is not the RPC executor. This is SQL concurrency evidence, not JWT,
Edge transport, real midnight-network timing or hosted load certification.

### Private local evidence

| Profile | Ignored evidence directory |
| --- | --- |
| Customer full replay | `.cache/security-test-36a77d9a4bc746119f8420575f034349` |
| Customer incompatible-audit refusal | `.cache/security-test-8fd13f7347e54501bd9466d95ff590d7` |
| Unchanged PG17 engine control | `.cache/security-test-2aacca08898c4491b44f2c92acbd39ac` |
| Browser | `.cache/browser-test-2f14c204-c4d4-46e7-98bd-c6e82109ce48` |

All three servers report **17.12 / 170012**. Each is stopped; no postmaster.pid,
bootstrap-password, pgpass.conf or actor-bootstrap SQL remains in these run
directories. Logs/catalogs are private and ignored, not artifacts to publish.
The repaired evidence-overwrite path remains fixed: customer authority JSON is
retained under the correct actor/provider profile and was checked independently.

Offline fresh evidence: model history has 20 known / 17 unrecorded, no duplicate,
unknown or gapped versions; HOLD. Customer catalog self-comparison gives 906
exact entries. Original-versus-compatibility final catalogs give 901 exact and
five different (four role graph records and extension schema ownership), none
missing/unexpected. Comparator exit 1 for that expected difference is intentional;
it is not equality or release acceptance. Metadata is finite coverage, not
proof of history, authority, financial compatibility or complete database equality.

## 5. Remaining blockers and approvals

| Gate | Local result | Hosted/release status |
| --- | --- | --- |
| A02 original zero-edge contract | Refusal reproduced | BLOCKED for unchanged customer execution. |
| A02 revised contract | Synthetic customer compatibility PASS | REQUIRES OWNER APPROVAL and actual hosted actor/provider/schema/digest evidence; ADMIN dependency remains. |
| A03 existing/future routine permissions | Replay, PUBLIC-leak correction, inherited refusal and ten screens PASS | NOT VERIFIED: actual creators/global defaults/inherited ACLs/allowlists. Global postgres default change needs cross-schema impact approval. |
| A04 legacy diagnostics | Read-only parsing/execution and dependency fixture PASS | NOT VERIFIED: three present marker identities and real legacy audit/lifecycle/finance/overlap/drawer state. R02 remains incomplete refusal coverage. No removals authorized. |
| A07 integrity | Original SHA/AST, deterministic artifacts, history/drift tools PASS | NOT VERIFIED: actual applied definitions/history, stage references and runner/provenance mechanism. No mark-applied or history repair. |
| Recovery | Tested transactional failures close and rollback | NOT VERIFIED: full cleanup failure matrix, lost acknowledgements, actual backups/restore/RPO/RTO and traffic/lock budget. |
| End-to-end/release | Local application regressions PASS | NOT VERIFIED: real isolated Auth/Edge/PostgREST flow, current endpoint inventory, production reads, Pages SHA/build release. |

Owner decisions required before any hosted actions:

1. Review R01-R06 and authorize any desired local follow-up fixes/tests. No code
   corrections beyond the requested review report were made in this task.
2. Approve exact read-only diagnostic bytes, target/actor/client, visibility,
   quiet window and sanitized handling; original preflight 03-07 remain held.
3. Decide whether the four provider ADMIN exceptions and temporary maintenance
   SELECT policies are acceptable for production. Verify actual support without
   provider impersonation or changing application roles to BYPASS/superuser.
4. Approve a truthful forward-artifact runner/history/provenance strategy and
   isolated rehearsal including failed/lost acknowledgements. Never overwrite
   historical files or mark altered artifacts as original migrations.
5. Complete exact object/ACL/default reconciliation and Owner-only legacy data
   decisions. Preserve original finance/member/audit records; never delete,
   rehash, guess payment facts or backdate to make a migration pass.
6. Verify actual backup/key custody, restore capability, operational RPO/RTO,
   maintenance traffic controls/locks/checkpoints/abort policy and appropriate
   isolated hosted tests before approving a migration window.
7. Separately approve settings, Edge and Pages releases only after the gates
   pass. Keep PIN/public/claim gates closed pending fee, token/KDF/abuse/runtime,
   privacy/retention/evidence and device acceptance decisions.

Finalized business rules remain unchanged: Owner-only privileged approval,
PHP/Manila/Option A dates, payment before eligibility, immutable 15-minute
walk-ins, one valid daily member check-in and preserved corrections/audit history.
No checkout, refund, free membership, member dashboard or silent approval added.

**Decision: scoped local tests PASS; ready for Owner review with the documented
findings. Production NO-GO. Stop here; no execution or release approval is implied.**

## Appendix A. Exact working-tree inventory at review entry

`M` means tracked modification; `??` means untracked. This list excludes the
new review report itself. An untracked path has no Git before-image from which
to attribute a specific previous session's edits.

```text
 M scripts/test-database.ps1
 M scripts/test-db-concurrency.mjs
?? docs/A02-EXECUTOR-HARDENING-REVIEW.md
?? docs/A02-PROVIDER-COMPATIBILITY.md
?? docs/A02-REDESIGN-PROPOSAL.md
?? docs/A02-REMEDIATION-DESIGN.md
?? docs/PRODUCTION-RECOVERY-FINAL-READINESS.md
?? docs/PRODUCTION-RECOVERY-IMPLEMENTATION-RESULTS.md
?? scripts/recovery/build-compatibility.mjs
?? scripts/recovery/compare-catalog.mjs
?? scripts/recovery/compare-history.mjs
?? scripts/recovery/plan-checks.mjs
?? scripts/recovery/validate-source.mjs
?? scripts/setup-native-pg17.ps1
?? scripts/test-recovery-pg17.ps1
?? supabase/recovery/README.md
?? supabase/recovery/catalog.sql
?? supabase/recovery/checks.json
?? supabase/recovery/compatibility/README.md
?? supabase/recovery/compatibility/review/01-explicit-routine-acls.sql
?? supabase/recovery/compatibility/review/20261110100000_executor_hardening.sql
?? supabase/recovery/compatibility/review/20261110103000_audit_timezone.sql
?? supabase/recovery/compatibility/review/20261110110000_membership_lifecycle.sql
?? supabase/recovery/compatibility/review/20261110120000_owner_reporting.sql
?? supabase/recovery/compatibility/review/20261110130000_pin_recovery.sql
?? supabase/recovery/compatibility/review/20261110140000_walkin_operations.sql
?? supabase/recovery/compatibility/review/20261110150000_member_checkin.sql
?? supabase/recovery/compatibility/review/20261110153000_owner_attendance.sql
?? supabase/recovery/compatibility/review/20261110160000_receipt_review_corrections.sql
?? supabase/recovery/compatibility/review/20261110170000_cash_operations.sql
?? supabase/recovery/compatibility/review/20261110180000_provisional_claims.sql
?? supabase/recovery/compatibility/review/20261110190000_receipt_allocation_review.sql
?? supabase/recovery/compatibility/review/20261110200000_operational_reports.sql
?? supabase/recovery/compatibility/review/compatibility-authority.sql
?? supabase/recovery/compatibility/review/effective-privileges.sql
?? supabase/recovery/compatibility/review/executor_hardening_assertions.sql
?? supabase/recovery/compatibility/review/final_security_assertions.sql
?? supabase/recovery/compatibility/review/manifest.json
?? supabase/recovery/compatibility/review/member_checkin_behavior.sql
?? supabase/recovery/compatibility/synthetic/01-explicit-routine-acls.sql
?? supabase/recovery/compatibility/synthetic/20261110100000_executor_hardening.sql
?? supabase/recovery/compatibility/synthetic/20261110103000_audit_timezone.sql
?? supabase/recovery/compatibility/synthetic/20261110110000_membership_lifecycle.sql
?? supabase/recovery/compatibility/synthetic/20261110120000_owner_reporting.sql
?? supabase/recovery/compatibility/synthetic/20261110130000_pin_recovery.sql
?? supabase/recovery/compatibility/synthetic/20261110140000_walkin_operations.sql
?? supabase/recovery/compatibility/synthetic/20261110150000_member_checkin.sql
?? supabase/recovery/compatibility/synthetic/20261110153000_owner_attendance.sql
?? supabase/recovery/compatibility/synthetic/20261110160000_receipt_review_corrections.sql
?? supabase/recovery/compatibility/synthetic/20261110170000_cash_operations.sql
?? supabase/recovery/compatibility/synthetic/20261110180000_provisional_claims.sql
?? supabase/recovery/compatibility/synthetic/20261110190000_receipt_allocation_review.sql
?? supabase/recovery/compatibility/synthetic/20261110200000_operational_reports.sql
?? supabase/recovery/compatibility/synthetic/compatibility-authority.sql
?? supabase/recovery/compatibility/synthetic/effective-privileges.sql
?? supabase/recovery/compatibility/synthetic/executor_hardening_assertions.sql
?? supabase/recovery/compatibility/synthetic/final_security_assertions.sql
?? supabase/recovery/compatibility/synthetic/history-fixture.sql
?? supabase/recovery/compatibility/synthetic/maintenance-rls-proof.sql
?? supabase/recovery/compatibility/synthetic/manifest.json
?? supabase/recovery/compatibility/synthetic/member_checkin_behavior.sql
?? supabase/recovery/diagnostics/additional-legacy-blockers.sql
?? supabase/recovery/diagnostics/audit.sql
?? supabase/recovery/diagnostics/compatibility-authority.sql
?? supabase/recovery/diagnostics/legacy-dependencies.sql
?? supabase/recovery/diagnostics/lifecycle-payments.sql
?? supabase/recovery/diagnostics/migration-authority.sql
?? supabase/recovery/diagnostics/registration-plan-cash.sql
?? supabase/recovery/effective-privileges.sql
?? supabase/recovery/history.sql
?? supabase/recovery/proposals/01-explicit-routine-acls.sql
?? supabase/recovery/proposals/02-postgres-future-routine-defaults.sql
?? supabase/recovery/source-manifest.json
?? supabase/tests/compatibility_legacy_diagnostics.sql
?? supabase/tests/compatibility_security_behavior.sql
?? supabase/tests/recovery_creator_defaults.sql
?? supabase/tests/recovery_inherited_cleanup.sql
?? supabase/tests/recovery_inherited_leak.sql
?? supabase/tests/recovery_legacy_behavior.sql
?? supabase/tests/recovery_security_behavior.sql
?? tests/recovery-compatibility.test.mjs
?? tests/recovery-sql.test.mjs
?? tests/recovery.test.mjs
```
