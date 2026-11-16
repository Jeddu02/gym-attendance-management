# GYMFORCE stabilization review — 2026-11-16 (Asia/Manila)

Production status: HOLD. The three reported workflows still depend on missing
Edge Function deployments. Local source fixes and synthetic tests pass at the
layers listed below; hosted business end-to-end success is not established.

## Confirmed findings

Fresh public GET/OPTIONS diagnostics against
`https://gym-attendance-management.pages.dev` and the confirmed intended backend
`https://alxhytivwybjbkjjdsyn.supabase.co` reproduced four successful HTML routes,
seven successful function preflights and 14 HTTP 404 function preflights.
Earlier November 11 diagnostics additionally inspected the gateway NOT_FOUND
marker for the three reported endpoints. The new run confirms their HTTP 404
status again; it did not make authenticated POST/data requests.

| Reported issue | Request trace | Confirmed cause / status |
| --- | --- | --- |
| Payments cannot load | PaymentsPage → owner-membership-payments → api.owner_list_membership_payments / api.owner_list_payable_purchases | Missing Edge endpoint; gateway failure precedes SQL/Auth handler execution. Still blocked in production. |
| Owner Walk-ins cannot load | WalkinsPage → owner-walkins → api.owner_list_walkin_requests | Same missing deployment. Still blocked in production. |
| Public walk-in cannot submit | EntrancePage → public-walkin-request → api.public_create_walkin_request | Same missing deployment. Release/configuration and database prerequisites remain separate gates after deployment. |
| Static site/Auth appear successful | Pages assets and older Owner endpoints are reachable | Independent deployments explain partial reachability. This does not verify business operations, grants or RLS. |

All 14 absent endpoints are listed in the November 11 report; the refreshed
results match that list. Database migrations define PostgreSQL RPCs and cannot
deploy these Edge endpoints. Conversely, deploying an endpoint does not install
its SQL dependencies. No RLS change can fix a missing-function gateway 404.

Owner supplied 20 migration versions matching the first 20 of 37 local files;
17 versions remain unrecorded in that supplied history. This does not establish
whether their objects are absent, older or manually present. The Owner's SQL
Editor run exposed only result 15: 51 indexes, all valid/ready. Results 1–14,
object markers, role/ownership compatibility, audit blockers and hosted
exposed-schema configuration remain UNKNOWN.

## Local fixes already prepared and rechecked

The existing working tree contains the coordinated fixes described in
[the complete November 11 bug report](STABILIZATION-2026-11-11.md): valid-origin
CORS preflight precedes unavailable/release-gate checks in eight handlers;
payment refresh retries history and payables independently; failed management
lists show unavailable states rather than empty-success rows; Member retry and
safe payment/walk-in status messages are provided. Local Supabase exposure is
restricted to the approved `api` schema, and walk-in diagnostics log bounded
codes only. Owner authorization, SQL checks and default-disabled release gates
are preserved. Initial release management remains Owner-only; no staff accounts
were introduced.

No further application defect was demonstrated by this review. Avoid speculative
SQL/grant rewrites while the gateway and migration prerequisites are unresolved.
The source changes have not been deployed and do not resolve production 404s.

## Files and database changes

The November 11 report lists all existing application/handler/configuration/test
modifications by filename. Existing unrelated work is preserved. New files for
this continuation are:

- `docs/production-preflight/sql-editor/01-01-identity.sql` through
  `01-15-indexes.sql`: one preserved original diagnostic SELECT per transaction.
- `docs/production-preflight/sql-editor/02-01-unrecorded-object-markers.sql`:
  preserved 91-marker WITH/SELECT in its own transaction.
- That directory's `README.md`, `OUTPUT-CONTRACTS.md`, `REPORT-TEMPLATE.md`,
  `manifest.json`, `validate.cjs` and `VALIDATION.md`: execution review,
  exact output contracts, sanitized reporting, hashes and offline validation.
- This status report and the progress tracker update.

Database changes: none. Original approved scripts 01/02 remain byte-for-byte
unchanged. No original migration was edited or newly introduced. No production
SQL, deployment, push, role/RLS/grant/configuration change or financial/member
mutation occurred. Database tests used only a new local synthetic cluster.

The split SQL files require Owner execution approval: SELECT semantics and
visibility are preserved, but separate transactions lose the original shared
catalog snapshot. Their hosted SQL Editor compatibility remains untested. The
package documents stop/cleanup procedures and a separately reviewed client
alternative if the editor hides the sole result before ROLLBACK.

## Verification results for this continuation

| Command / layer | Result and boundary |
| --- | --- |
| npm.cmd run lint | PASS; final package/documentation rerun also completed. |
| npm.cmd run typecheck | PASS. |
| npm.cmd test | PASS 37/37; synthetic handler, source, money, retry, QR, CSV and error tests. |
| npm.cmd run test:security | PASS static source checks. |
| npm.cmd run build | PASS Vite production bundle and PWA generation. |
| Deno shared tests, cached dependencies | PASS 103/103. |
| Deno check, cached dependencies | PASS all 21 Edge entrypoints. |
| npm.cmd run test:database | PASS all 37 migrations, phase suites, final permissions/RLS assertions and nine deterministic two-session races on native PostgreSQL 18 with synthetic Auth. Cluster stopped. |
| node scripts/test-browser.mjs --production | PASS: mobile public/all Owner navigation, failed-list recovery, payment/walk-in failures, payable pagination, PIN clearing, fragment removal, QR and static-only PWA caching. Synthetic Auth/API fixtures only; no external app requests. |
| git diff --check | PASS; normal Windows line-ending notices only. |
| SQL Editor package validation | PASS PostgreSQL 17/18 parsers, all 16 files, exact SELECT text/AST/columns, catalog boundaries, wrappers/timeouts/ROLLBACK and unchanged original hashes. Static only; no SQL execution. |
| Fresh public hosting diagnostics | FAIL overall as expected: four routes and seven preflights PASS, 14 endpoints HTTP 404. No business/Auth calls. |
| Hosted Auth → Edge → PostgREST → RLS business workflows | UNTESTED. No authenticated production connection or isolated hosted environment is available. |
| Cloudflare branch/SHA/build logs/environment-key validation | UNKNOWN; public reachability does not validate private deployment configuration. No deployment performed. |

Initial sandbox attempts failed to launch Deno/local PostgreSQL, contact public
hosts, or enable Chrome's DevTools page. These were infrastructure/test-startup
failures, not evidence of application failure. Approved execution outside the
sandbox resolved Deno, PostgreSQL and public diagnostics. Keep these initial
failures distinct from final rerun outcomes.

Current synthetic database evidence:
`.cache/security-test-b991df01300a49008a191ccc4320e158`.
Final synthetic browser evidence:
`.cache/browser-test-10650f30-676d-404d-9040-4dc9926ff7d5`.
The earlier November 11 legacy incompatible-audit refusal test remains historical
PASS; that optional negative-seed mode was not rerun in this continuation.

Requested lifecycle, registration, payments, cash/GCash/bank transfer, attendance,
invalid/unknown PIN, expired membership, role restrictions, audit preservation,
reports and duplicate/concurrent operations are covered by these synthetic
SQL/unit layers as detailed in the November 11 report. Native PostgreSQL 18
tests do not certify hosted PostgreSQL 17, real Auth/JWT, Edge runtime limits,
mobile installation or production recovery.

## Safest deployment sequence and exact handoff

1. Owner reviews/approves the new SQL Editor package. Run only 01 variants in
   numeric order, then 02 variant, on the confirmed project; retain full outputs
   privately and report sanitized results. Stop on errors or incomplete output.
2. Reconcile object-presence/history classifications. Do not mark migrations
   applied, repair history, reapply partial definitions or bypass hardening.
   Scripts 03–07 remain on hold until their prerequisites and separate approval.
3. Review hardening authority, audit-chain and lifecycle blockers with verified
   prerequisite metadata. Verify hosted PostgREST exposes only `api` using
   Owner dashboard settings; local TOML alone is insufficient. Obtain separately
   approved isolated runtime tests for ownership transfers and full migration
   replay. A read-only catalog PASS cannot prove ALTER OWNER compatibility.
4. Owner verifies backup/recovery and accepts the exact drift-specific migration
   plan. The potential forward order is the 17 unrecorded filenames below;
   **this is not an apply command or authorization**. If any preconditions fail,
   stop for a revised reviewed plan rather than running the entire set blindly.
5. Only after database approval and isolated acceptance, the Owner-controlled
   migration operator applies the reviewed forward plan. Separately approve
   required hosted API/settings changes; verify grants/RLS without broadening
   direct browser/service-role table access.
6. After SQL dependencies pass, separately authorize Edge deployment using the
   exact CLI instructions/function list in the November 11 report. Verify
   project link, canonical APP_ORIGIN, server-only credentials and actual
   handler JWT/Owner checks. Keep public/PIN/claim gates disabled until approved
   runtime limiter/KDF/fee/privacy criteria pass.
7. Review intended source files, rerun the documented checks, and authorize a
   normal commit/push to the actual Pages production branch. Verify Pages
   build/deployment logs and deployed SHA. The November 11 report contains
   exact build variables/output directory and CLI commands; they remain
   approval-gated instructions. No force-push, reset or database rollback.
8. Refresh public GET/OPTIONS diagnostics, then perform approved isolated
   synthetic end-to-end acceptance and Owner-controlled production read checks.
   Never create test receipts/members among real records. Keep production gates
   closed on failure and preserve all original ledger/audit records.

Potential forward order:

```text
20261103080000_owner_membership_plans.sql
20261103100000_owner_create_membership_purchase.sql
20261103110000_owner_list_membership_purchases.sql
20261103120000_owner_membership_payments.sql
20261110100000_executor_hardening.sql
20261110103000_audit_timezone.sql
20261110110000_membership_lifecycle.sql
20261110120000_owner_reporting.sql
20261110130000_pin_recovery.sql
20261110140000_walkin_operations.sql
20261110150000_member_checkin.sql
20261110153000_owner_attendance.sql
20261110160000_receipt_review_corrections.sql
20261110170000_cash_operations.sql
20261110180000_provisional_claims.sql
20261110190000_receipt_allocation_review.sql
20261110200000_operational_reports.sql
```

## Production readiness checklist

| Gate | Result |
| --- | --- |
| Confirmed intended Supabase project and supplied history comparison | PASS: project confirmed; 20 recorded / 17 unrecorded. |
| Required endpoint availability | FAIL: 14 HTTP 404 endpoints remain. |
| All catalog outputs and object-marker classifications | UNKNOWN: only index result supplied. |
| Reviewed split SQL file integrity/static read-only checks | PASS; execution approval pending. |
| Hosted hardening ownership authority, definitions, grants and RLS | UNKNOWN. |
| Audit-chain, membership/payment/cash migration blockers | UNKNOWN. |
| Hosted exposed schemas, server config, Pages SHA/branch/build variables | UNKNOWN. |
| Isolated real Auth/Edge/PostgREST end-to-end business/negative tests | UNKNOWN. |
| Production backup/recovery, privacy/retention and PIN/abuse acceptance | UNKNOWN. |
| Real-device QR/PWA installation/update and navigation | UNKNOWN; synthetic browser evidence is separate. |
| Production release, database and deployment authorization | HOLD; no action taken. |

Owner production read verification after the approved release must establish
Payments/payables and Walk-ins successful loading, safe empty/error distinction,
Owner-only access and consistent dashboard/report totals. Isolated synthetic
acceptance must establish payment-approved activation and renewal/expiry,
one daily Manila check-in, wrong PIN/expired/unauthorized denial, immutable
15-minute provisional walk-ins and Owner-only actual-receipt confirmation,
idempotent/concurrent handling, audit preservation, financial corrections and
cash/income separation. The full checklist remains in the November 11 report.
