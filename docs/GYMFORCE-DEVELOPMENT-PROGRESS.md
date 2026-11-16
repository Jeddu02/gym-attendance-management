# GYMFORCE development progress

Updated 2026-11-16, Asia/Manila. Current batch: local bug fixing and deployment
diagnostics. No production records, hosted settings or resources changed.
The November 10 acceptance and Git publication notes below remain historical
evidence. Existing drafts, unrelated edits and original migrations are preserved.

## Stabilization continuation — 2026-11-16

- Fresh public HTML/OPTIONS diagnostics reproduce four successful routes, seven
  successful preflights and 14 missing Edge endpoints (HTTP 404), including
  Payments and both walk-in endpoints. Production fixes remain deployment-gated.
- Owner supplied 20 migration versions; 17 local versions remain unrecorded.
  Owner's SQL Editor exposed only 51 valid/ready indexes, not the other 14
  catalog results. Object presence, definitions and hosted prerequisites remain
  unknown; no production catalog execution was performed by Codex.
- Prepared [SQL Editor variants](production-preflight/sql-editor/README.md):
  15 separate catalog SELECT files plus one marker file, exact output contracts,
  sanitized reporting template and offline validator. PostgreSQL 17/18 static
  checks pass; original approved SQL hashes are unchanged. Separate snapshots
  require renewed execution approval. Scripts 03–07 and deployments remain held.
- Rechecked lint/typecheck, 37 Node tests, source security, build, 103 Deno tests,
  21 Edge typechecks, all 37 synthetic migrations and nine database races.
  See [the current report](STABILIZATION-2026-11-16.md) for final browser results,
  environment startup failures, exact evidence boundaries and release handoff.
- No production SQL, migration, configuration change, financial/member write,
  commit, push or deployment. Existing source fixes and unrelated work preserved.

## Stabilization — 2026-11-11

### Read-only production verification package — awaiting Owner review

- Prepared [the manual SQL Editor guide](production-preflight/MANUAL-SQL-EDITOR-GUIDE.md)
  for Owner execution of approved scripts 01 and 02. It includes project/context
  confirmation, the reviewed identity excerpt, complete-file ordered execution,
  result-display and transaction-cleanup stop conditions, and a sanitized summary
  template. Both SQL files remain byte-for-byte unchanged. No production SQL was
  executed while preparing the guide; scripts 03–07 and all changes remain on hold.
- Owner subsequently authorized scripts 01 and 02 only, subject to verified
  production connection/role, unchanged SQL, ordered separate execution and
  private metadata handling. [The execution status](production-preflight/AUTHORIZED-01-02-STATUS.md)
  records that neither script started: the project link matches, but no matching
  database authentication is configured in the checked local paths. No database
  connection was attempted and no production transaction opened. The Supabase
  integration was offered but is not installed/connected. Catalog/role/object
  results remain UNKNOWN; scripts 03–07 and all production changes remain gated.
- Owner supplied 20 production migration versions, exactly matching the first
  20 local files. Seventeen local versions remain unrecorded; no production
  catalog query has been executed to determine which objects already exist.
- Prepared [the review package](production-preflight/README.md) with seven SQL
  files for catalog/signature/ACL/RLS inventory, 91 unrecorded-object markers,
  hardening input screens, migration-authority inspection and aggregate-only
  audit/registration/lifecycle/cash blocker checks. All SQL is available before
  Owner execution. The lifecycle/payment query is conditional on columns added
  by an unrecorded migration; absent prerequisites remain UNKNOWN.
- PostgreSQL 17 and 18 parser checks PASS for all seven files. AST safety checks
  PASS for 66 statements, limited to SELECT, local settings and read-only
  transaction wrappers. No SQL execution or production connection occurred.
- Identified a structural non-superuser ownership risk: hardening forbids
  reserved-role memberships and schema CREATE while transferring ownership.
  Actual hosted migration-role compatibility requires separately approved,
  isolated synthetic testing; catalog checks alone cannot certify it.
- Readiness checklist records the known migration/Edge gaps as FAIL and unrun
  hosted catalog, RLS, audit, lifecycle, backup and compatibility checks as UNKNOWN.
  No migrations, deployment, authentication/RLS/grant/membership changes or
  mutation-based compatibility tests were performed. Awaiting review/approval.

See [the stabilization report](STABILIZATION-2026-11-11.md) for confirmed source
defects, modified files, test evidence, exact deployment instructions and the
production acceptance checklist.

- Corrected preflight ordering in eight payment/walk-in/PIN/check-in handlers;
  unavailable services now return safe POST failures after valid-origin OPTIONS.
  Owner/Auth/SQL authorization and all release switches remain enforced.
- Payments refresh retries both history and payable purchases, with independent
  errors. Failed management lists no longer appear empty; Member directory has
  a dedicated retry control. Owner reads use safe status messages.
- Local API exposure and regression checks now match the approved `api`-only
  boundary. No SQL migration or business-rule change was needed.
- Added synthetic handler/preflight/error regressions, broader browser recovery
  coverage and a credential-free public HTML/OPTIONS diagnostic script.
- Verified 37 Node tests, 103 Deno tests, all 21 Edge entrypoints and the native
  database suite (37 migrations, final security assertions, nine races).
  Lint/typecheck/build, source-security checks and expanded production-browser
  tests also PASS, including all management navigation, failed-list recovery,
  mobile layout, QR/PIN and static-only PWA caches. The harness now waits for
  prompt-mode worker activation and navigation before checking document control.
- Live URL supplied: `https://gym-attendance-management.pages.dev/`. Public
  diagnostics confirm four HTML routes and seven function preflights succeed,
  while 14 required function endpoints are absent from the frontend-configured
  Supabase project. Payments, Owner Walk-ins and public walk-in creation each
  return gateway HTTP 404 / `NOT_FOUND` / `Requested function was not found`.
  This confirms a common deployment mismatch before application SQL executes.
- User confirmed `alxhytivwybjbkjjdsyn` is the intended production project.
  Applied migration versions and release authorization remain required.
  No push/deployment performed and no
  production end-to-end success is claimed. The report contains the revised
  deployment list and exact public diagnostics command.

## Approved scope

Owner-only management. No cancellation, freeze, checkout, refunds, free access,
member account/dashboard or automatic renewal. Owner approved 15-minute walk-in
requests, supervised one-use PIN flow preparation, documented corrections,
current-date presence review, daily drawer procedure, local QR dependencies and
the restricted PostgREST api RPC boundary. AGENTS.md records these approvals.
Local api exposure already existed; the latest approval confirms that boundary.

## Implemented and locally verified

- Restricted NOLOGIN executors, column grants, FORCE RLS and RPC-only access;
  13 forward migrations. API schema contains routines only; browser execution
  and direct service-role application-data grants denied.
- UTC audit serialization preserves compatible history and refuses incompatible
  legacy hashes without rewriting originals. Append-only financial/resolution
  history and atomic audit rollback checks.
- Owner approval, full-paid term finalization, Option A calendar dates, inclusive
  Manila expiry and consecutive early/lapsed renewal. No browser date authority.
- Default-disabled supervised PIN setup/reset and public online check-in:
  one-use links, KDF/dummy verification, explicit rate limits, credential-version
  recheck, private PIN fields and duplicate prevention.
- Walk-in fee versions and immutable 15-minute requests; atomic Owner receipt
  confirmation/attendance. Expired/mismatched money stays in receipt review.
- Actual-receipt verification, explicit whole-receipt allocation, immutable
  void/re-record links, affected eligibility invalidation and preserved history.
  Underpayments cannot combine into installments. Allocation preserves original
  receipt targets; retrying a void does not restore access. Still-verified money
  cannot be duplicated by a replacement receipt.
- Attested opening float and daily drawer close: verified cash including
  unallocated receipts, electronic exclusion, immutable receipt-ID snapshots,
  reason/evidence for variance and no automatic income changes.
- Immutable provisional claims and operation IDs; current paid physical presence
  only, stale/duplicate review, reasoned no-attendance resolution. Review handler
  defaults disabled. Persistent offline storage is NOT implemented while
  privacy/retention and queue parameters remain unapproved.
- Dashboard exact decimal money, confirmed-income date/method reports, Owner-only
  expiry reminders suppressed by consecutive paid renewal, attendance/audit
  history and loaded-data CSV exports (Excel-compatible, no native .xlsx).
- Search/pagination including payable purchases beyond 100 records, stale-response
  and uncertain-retry protection, responsive public/Owner UI and downloadable
  local HTTPS entrance QR. Owner app and QR library load separately.

## Verification actually completed

| Check | Latest result |
| --- | --- |
| npm.cmd run lint / typecheck / build | PASS. Final bundle uses separate Owner/QR chunks; no chunk-size warning. |
| npm.cmd test | PASS 34/34: source boundaries, CSV, QR, exact money and retry outcomes. |
| npm.cmd run test:security | PASS static regression checks, not runtime certification. |
| Deno shared tests / all Edge checks | PASS 102/102 and all 21 entrypoints; cached-only, node-modules-dir=manual. |
| scripts/test-database.ps1 | PASS all 37 migrations, phase behavior, rollback tests, final RLS/ownership/RPC-only invariants and nine deterministic two-session races. Synthetic PostgreSQL 18.6 Auth shim. |
| Concurrency races | PASS receipt recording, confirmation, token redemption, audit append, daily check-in, walk-in confirmation, reviewed allocation, claim confirmation and void-versus-check-in. Both blocked sessions observed before release. |
| Negative legacy audit refusal | PASS expected migration refusal; original hash/head/config preserved. |
| node scripts/test-browser.mjs --production | PASS isolated Chrome mobile Owner/public rendering, no overflow, PIN clearing, fragment removal, provisional walk-in, payable pagination and local QR preview. Synthetic Auth/API fixtures only; no external app requests. |
| Production PWA cache | PASS observed shell worker control and static-only cache entries; no API/Auth/PIN/entrance submissions cached. Real-phone installation/update acceptance remains open. |
| Dependency audit | Production: zero advisories. Full audit exit 1: 12 development findings (2 low, 10 moderate), none high/critical. No force upgrades applied. |
| git diff --check | PASS; normal Windows line-ending notices only. |

Latest native logs: .cache/security-test-408e440a41044ddd9a6eb3245f57cbad.
Latest production browser fixtures/screenshots:
.cache/browser-test-8e7f4aff-9370-4fb1-a512-18011ae4c894.
Synthetic clusters/servers stopped; generated DB credential files removed.
No live identities, member records or production financial data used.

## Remaining gates

- Persistent offline queue, retention/privacy acceptance, clock-drift policy and
  validation of the 24-hour triage threshold. Current online claim review is not
  a durable offline queue and does not claim historical attendance.
- Production PIN token/KDF/abuse parameters after shared-network, load and
  denial-of-service testing in the intended runtime. All relevant release
  switches stay disabled by default.
- Separate independent-eligibility resolution, mobile-change verification,
  security suspension grounds, and stale/post-close cash review procedures.
  Original invalidated history/closed snapshots must not be silently restored.
- Owner privacy/retention review, backup objectives/cadence/key custody and an
  actual isolated recovery drill before production data.
- Actual Supabase Auth/JWT/PostgREST/Edge and hosted role/migration-authority
  acceptance. Docker Engine/Desktop are unavailable locally; no installation or
  cloud resource is authorized. Native PostgreSQL 18 is not hosted PostgreSQL 17.
- Real-device PWA install/update, final security/release acceptance and separate
  deployment authorization. Dev-tool advisory remediation remains open.

Approximate development completion: **70%**, based on local feature coverage;
not a production-readiness percentage. Safe independent source implementation
and local acceptance for this batch are complete. Next work requires the above
policy/infrastructure gates rather than enabling services or inventing retention
rules. See [release readiness](RELEASE-READINESS.md) for concrete acceptance steps.

## Git publication preflight — 2026-11-10

Owner authorized one reviewed commit and a conditional push using the existing
GitHub repository, without changing hosted settings or applying cloud migrations.
Required lint, typecheck, 34 Node tests, source-security check and build passed.
Public/PIN/claim release switches remain disabled by default in server source.

Verified remote: https://github.com/Jeddu02/gym-attendance-management.git.
Local branch: master; pre-commit HEAD and remote master both ba2ff72.
Remote main also exists. GitHub's remote default is master, but this does not
verify the Cloudflare Pages production branch. Deployment metadata was not
available through public GitHub API access. Push is held until the actual Pages
branch is confirmed; do not infer it from the GitHub default or local tracking.

The publication scope excludes historical drafts, the older local harness,
generated evidence, caches, environment files and unrelated pre-existing work.
Only reviewed source, tests, forward migrations, lockfiles and safe documentation
are selected. No production Supabase resource or live workflow is enabled.
