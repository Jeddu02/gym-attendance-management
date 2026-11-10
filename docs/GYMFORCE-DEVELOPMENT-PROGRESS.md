# GYMFORCE development progress

Updated 2026-11-10, Asia/Manila. Current batch: integrated local acceptance and
release gates. Development evidence below precedes the separately authorized
Git publication preflight recorded at the end. No cloud provisioning, deployment
or production access performed. Existing drafts and original migrations preserved.

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
