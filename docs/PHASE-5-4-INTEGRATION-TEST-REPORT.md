# Phase 5.4 — integration test report

## Latest execution — explicit Phase 5.2–5.5 request

Fresh execution completed 2026-11-17, observed at 04:21:29 UTC / 12:21:29
Asia/Manila. Branch master, HEAD still
`ad41b7988d0d9fc4a56e675aeaff9b613878cdda`. The six untracked files from the
previous task were present at entry and preserved. This execution changed only
this report, adding actual rerun evidence; it did not create another assessment
package. No new local application/recovery defect was reproduced, so no source
change or additional regression implementation was justified. Known hosted and
product-policy gaps below remain unresolved, not silently declared fixed.

Inspected actual builder role graph/prepare/cleanup and function-AST preservation,
PG17 launcher/test harness, scoped RPC/default ACL proposals, legacy prerequisite
planner/check definitions/dependency SQL, history comparison, 30-unit checker and
regressions, three list-handler array guards, shared CORS guard and entrance
submission path. Executed the same exact commands in the command table below
again for this request, with these fresh outcomes:

| Executed layer | Passed | Failed | Skipped / qualification |
| --- | --- | --- | --- |
| Application Node | 38 | 0 | 0 |
| Recovery/package Node | 27 | 0 | 0 |
| Deno | 105 | 0 | 0 |
| Edge entrypoint typechecks | 21 | 0 | 0 |
| Diagnostic candidates, exact hashes + PG17/18 safety | 30 | 0 | 0 static checks; all 30 hosted executions NOT RUN |
| Source fingerprints | 75 | 0 | 37 original migrations, 21 entrypoints, 17 shared runtime modules; HEAD blob checks |
| Existing SQL Editor variants | 16 | 0 | Both grammar passes; no database execution by validator |
| PG17 profiles | 3 | 0 | Customer, negative audit and unchanged engine control; 17.12/170012 verified |
| Unique concurrency cases | 9/9 in each full profile | 0 | 18 executions total; negative audit profile stops before later stages |
| Legacy refusal cases | 11/11 in each full profile | 0 | 22 executions total; unchanged protected-row/catalog hashes |
| Customer partial-ownership rollback probes | 2 | 0 | P05 and P11; extra membership refusal and cleanup also pass |
| Final effective-privilege screens | 10/10 in each full profile | 0 | Additional inherited-leak, future-default and unauthorized access assertions pass |
| Incompatible stored-audit refusal | 1 | 0 | Expected refusal and preservation assertions pass |
| Initialization cleanup faults | 5 | 0 | Each expected failure leaves no temporary credential files/active PID marker |
| Synthetic production browser suite | 1 suite | 0 | Harness does not provide an individual assertion total; no hosted JWT/RLS proof |
| Lint, typecheck, production/PWA build, security check | 4 checks | 0 | All processes exited zero; SW/workbox generation completed |

These are overlapping evidence groups, not a summed independent-test count.
Intentional negative refusals are passing tests. Staff accounts and cancellation
are not initial-release features; non-Owner denial is tested instead. Durable
encrypted offline queue/reconnect synchronization remains unimplemented and
gated; online provisional-claim/retry tests passing do not certify that feature.

New private ignored evidence:

- Customer: `.cache/security-test-06e5d8ba808247b7b4178a974a9a8f56`.
- Audit refusal: `.cache/security-test-b35bf2f08ec8448bb9547077d5abc9d6`.
- Engine control: `.cache/security-test-abb1a75b85c24e7aa041442596b55545`.
- Five faults: `.cache/cleanup-test-52fb5cb2d11d4ef29d8295f7b6736104.json`.
- Browser: `.cache/browser-test-d5a01481-0362-4b53-903d-c9124a7f47b7`.

All three PG17 profiles reported their server stopped. The initial Deno launch
request hit an automatic approval-review timeout before execution; its permitted
retry executed successfully. No failed Deno test or security bypass resulted.

Phase outcomes for this execution: **5.2 PARTIALLY COMPLETED; 5.3 PARTIALLY
COMPLETED; 5.4 PARTIALLY COMPLETED; 5.5 COMPLETED as an evidence-based NO-GO
decision**, not completion of all Phase 5 requirements or permission for Phase 6.
A02 compatibility, A03 ACL/defaults, A04 refusal/diagnostic and A07 integrity
tools PASS locally; their actual hosted prerequisites remain UNKNOWN/BLOCKED.
Original zero-edge non-superuser P05/P11 remains BLOCKED and its refusal controls
passed. A05/A06 fixes remain intact. No hosted connection or SQL was attempted.

The smallest proposed first metadata batch is still units **1, 2, 3, 19, 20,
22, 23, 25**, all freshly verified against existing hashes. It establishes the
stage, exact marker identities and authority/ACL/dependency evidence; it cannot
by itself resolve real legacy-data or DDL-authority acceptance. Separately approve
26–28 after visibility/prerequisites, and 29–30 only if required P04/P10/P11 columns
exist. Missing prerequisites mean SKIP/UNKNOWN, never create-to-test. Approval
must specify existing actor/client, window, private custody/access/retention,
sanitized reporting and same-session stop/rollback handling. The form is still
DRAFT; none of these hosted executions is authorized by this local-test request.

Remaining release gates: actual provider ADMIN authority and explicit trust
adoption; hosted creator/default/role/RLS/definer evidence; real legacy audit,
finance/membership/attendance/drawer outcomes; current history/partial-object
reconciliation and honest artifact runner/history design; real isolated
Auth/Edge/PostgREST integration; approved backup/restore and operational policy;
public lost-response recovery, PIN parameters and offline retention decisions;
then separate migration/config/Edge/Pages/window/opening authorizations. Prior
missing-endpoint observations remain historical, not refreshed. **Production
NO-GO; no deployment advancement authorized.**

The sections below preserve the preceding run's detailed matrix and command
syntax. Their older private run IDs are historical; use the fresh IDs above for
this execution.

2026-11-17. Baseline master `ad41b7988d0d9fc4a56e675aeaff9b613878cdda`.
**Local verification PASS as scoped below. Hosted end-to-end UNVERIFIED/BLOCKED.**
No production request, connection, SQL, mutation or deployment was performed.

## Environment and commands executed this run

Windows native PostgreSQL **17.12 / 170012**, portable workspace runtime;
fresh private loopback clusters, synthetic records/Auth shim only. PG18 was not
used as PG17 evidence or modified. PG and Deno/browser processes used the approved
execution context outside the sandbox's restricted-token startup limitation;
no Windows security protection or PostgreSQL privilege check was disabled.
The existing archive publisher comparison is historical evidence, not rerun here;
no runtime was downloaded/replaced. Existing pinned parser dependencies were reused.

| Command | Fresh result | Practical limit |
| --- | --- | --- |
| `npm.cmd run lint` | PASS | Static lint. |
| `npm.cmd run typecheck` | PASS | Frontend TypeScript. |
| `npm.cmd test` | PASS 38/38 | Includes actual-handler synthetic HTTP A05 tests; no hosted Auth. |
| `npm.cmd run test:security` | PASS | Static browser/server/Owner/config boundaries; never reads environment files. |
| `node --test tests/recovery.test.mjs tests/recovery-sql.test.mjs tests/recovery-compatibility.test.mjs tests/recovery-tooling.test.mjs tests/recovery-integrity.test.mjs tests/hosted-package.test.mjs` | PASS 27/27 | Includes four new package tests, exact source/function ASTs, parser version guards, history/drift, LF/CRLF/tamper tests. |
| `node scripts/recovery/validate-source.mjs` | PASS | 37 migrations, 993 statements under PG17/18; 21 entrypoints + 17 runtime modules; 75/75 HEAD blob checks. |
| `node scripts/recovery/validate-hosted-package.mjs` | PASS | 30 unchanged candidate hashes/scopes/order; PG17/18 static safety. No SQL execution. |
| `node docs/production-preflight/sql-editor/validate.cjs` | PASS | All 16 variants retain approved SELECTs, columns, wrappers and source hashes. |
| `deno test --cached-only --node-modules-dir=manual --allow-read=supabase/functions --allow-env=MEMBER_MOBILE_ENCRYPTION_KEY_B64,MEMBER_MOBILE_HMAC_KEY_B64 supabase/functions/_shared` | PASS 105/105 | Installed Deno executable; synthetic key values. All-21 actual entrypoint preflight/Auth/gate tests included. |
| `deno check --cached-only --node-modules-dir=manual` with every actual endpoint `index.ts` | PASS 21/21 | Inventory explicitly checked for 21; no remote module installation or deploy. |
| `npm.cmd run build` | PASS, including generated SW/workbox | Local Vite/PWA build, not Pages success. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-recovery-pg17.ps1 -CustomerCompatibility` | PASS | Non-superuser compatibility replay, ACL/negative/rollback tests and nine races. |
| Same PG17 command with `-CustomerCompatibility -TestLegacyAuditRefusal` | PASS expected refusal | Stops at incompatible audit stage; does not run the later full suite in this profile. |
| Same PG17 command without switches | PASS | Unchanged superuser engine control plus real non-superuser P05/P11 expected refusals; not hosted authority. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-recovery-cleanup.ps1` | PASS 5/5 | AfterCredential, BeforeInitdb, InitdbFailure, AfterInitdb, AfterStart: expected failure, no credential files or active server marker. |
| `node scripts/test-browser.mjs --production` | PASS | Real local Chrome, synthetic Auth/API fixtures and isolated production build; no external application requests. |
| `git diff --check` | PASS, final rerun | New-file whitespace also checked separately; no staging/commit. |

The Deno binary is the existing WinGet package executable; all endpoint paths are
enumerated from `supabase/functions`, excluding `_shared`. Commands above do not
accept a hosted connection string. Fresh test outcomes supersede historical test
counts for this run only; no parser clean-room reinstall/provenance network check
was needed for this tooling-only change. Their older results remain historical.

## Business, security and race matrix

| Workflow | Local evidence this run | Hosted status |
| --- | --- | --- |
| Owner login/session/role restriction | Synthetic browser/Auth fixtures; real handler actor forwarding and denial; SQL outsider tests | UNVERIFIED real JWT/Auth/Edge/PostgREST chain |
| Registration/plans/purchase/renewal | PG membership and lifecycle suites; calendar tests including month/leap/Manila edges | UNVERIFIED real schema/data/key settings |
| Approval + full payment before activation; inclusive expiry | PG lifecycle, calendar and check-in eligibility suites | UNVERIFIED hosted |
| PIN setup/reset, Member ID/mobile, invalid PIN and ineligible denial | Deno normalization/KDF/token/rate/generic-output tests; PG credential and check-in tests; browser PIN/fragment clearing | UNVERIFIED hosted runtime/rates/DoS and real-mobile acceptance |
| Once-per-Manila-day check-in and credential races | PG check-in behavior and deterministic concurrency | UNVERIFIED hosted timing/load |
| 15-minute walk-in, fee snapshot, expiry, Owner payment/attendance | PG walk-in/receipt suites; synthetic public/Owner handlers and browser states | UNVERIFIED deployment/fee/gates; lost creation response still lacks recovery contract |
| Cash/GCash/bank, pending/rejected/confirmed, immutable corrections | PG membership payment/receipt/allocation/cash suites; exact cents tests | UNVERIFIED real evidence/legacy money; no automated gateway claim |
| Dashboard/attendance/audit/income/expiry/payable reports | PG report/history suites; browser unavailable/retry/list routes | UNVERIFIED real totals and end-to-end reads |
| Audit links/UTC and legacy migration safeguards | Eleven actual migration refusals with row/catalog preservation; separate incompatible-audit profile | UNVERIFIED stored production chains/legacy rows |
| RLS, unauthorized RPC/data access/defaults/inheritance | PG final security, ten privilege screens, leak refusal and rollback | UNVERIFIED real owners/FORCE/policies/defaults/overloads |
| Public QR/mobile navigation/PWA cache | Synthetic browser QR/navigation/mobile and static-only cache checks | UNVERIFIED real device/hosted updates |
| Provisional claims/manual retry | PG submit/resolve/current-presence/idempotency tests; retry payload tests | UNVERIFIED hosted; durable encrypted offline queue NOT IMPLEMENTED |
| Staff accounts; membership cancellation | EXCLUDED: initial release is Owner-only; cancellation is prohibited | Do not add these features to satisfy a generic test matrix |

Nine races passed in each full PG17 profile: payment-record, payment-confirm,
token-redeem, audit-append, daily-checkin, walkin-confirm, receipt-allocation,
claim-confirm and void-checkin. Tests observe two blocked sessions and check
cardinality, operation retry and audit/eligibility invariants. This is not a
production load benchmark. Eleven legacy refusals cover normalized plan duplicates,
seven approval/lifecycle/date/payment anomalies, dated review history, and open/
closed legacy drawers. Both P05/P11 partial ownership rollback probes pass in
the customer profile. No original history is deleted or rehashed to make tests pass.

Fresh private synthetic evidence (ignored):

- Customer `.cache/security-test-ddb639ee85d248efb886c63f43c84c03`.
- Audit refusal `.cache/security-test-fc862f7652ab4bd78331b7a69acd9164`.
- Engine control `.cache/security-test-580a6b512bdc4e0db8a602a23c8e47f1`.

All three profile processes exited zero and reported their server stopped.
Fault evidence: `.cache/cleanup-test-f2e2022820fc47689fd12563f95be803.json`.
Browser evidence: `.cache/browser-test-1fc52a98-d76d-4c98-b2f5-35a3216c7894`.
Browser assertions passed mobile/Owner navigation without overflow, unavailable
versus empty recovery, public retry, payable pagination, PIN clearing, private
fragment removal, signed-out screen, QR preview and static-only service-worker
caches. Real-device install/update and hosted Auth/RLS remain unverified.

Final Git scope: exactly six new files listed in the final assessment; no tracked
file changed. Historical migrations, application/Edge source, configuration,
dependencies and reviewed SQL/hash catalogs match HEAD. Build/runtime/private
synthetic artifacts remain ignored under `dist`, `.cache` and existing dependency
paths. The scoped secret review found no credential/record export among the six
text files; production environment files were not read. Full synthetic logs stay
private/ignored. An additional read-only existence check of all three profile
roots confirmed no temporary credential files or active postmaster marker.
No real financial records, raw security grids, PINs, tokens or credentials belong
in these reports. A local PASS is never hosted integration acceptance.
