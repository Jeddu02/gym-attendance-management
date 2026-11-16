# GYMFORCE stabilization — 2026-11-11 (Asia/Manila)

## Release status and evidence boundary

Local fixes, synthetic verification and read-only live hosting diagnostics.
**A common production cause is now confirmed: the frontend calls functions that
are absent from its configured Supabase project.** The Owner supplied
`https://gym-attendance-management.pages.dev/`. Its public JavaScript embeds
`https://alxhytivwybjbkjjdsyn.supabase.co`. All three reported endpoints return
HTTP 404 with gateway code `NOT_FOUND` and message `Requested function was not
found`, before application handlers/Auth/RPCs can run. They are not yet fixed in
production. Migration history, privileged hosted settings and business end-to-end
behavior remain unverified. Successful Owner authentication does not establish
that payment, walk-in, PostgREST, RLS or membership operations work.

No cloud resources, production settings, database records or credentials were
changed. No commit, push, deployment, branch reset or force-push was performed.
Existing unrelated modified documentation and untracked drafts were preserved.
Management access remains Owner-only; no staff roles were introduced.

## Confirmed live deployment mismatch

Read-only diagnostics on November 11 used public HTML/assets and OPTIONS only.
No sign-in, Auth/data query, request creation or financial operation was performed.
The diagnostic command exited 1 because 14 of 21 configured functions returned
404. The three reported endpoints were independently repeated and their gateway
error markers verified. Gateway `Access-Control-Allow-Origin: *` does not fix a
missing function; it does not mean the application allowed an untrusted origin.

| Live check | Observed result |
| --- | --- |
| `/`, `/entrance`, `/pin-setup`, `/pin-reset` | HTTP 200 HTML; PIN routes include no-store. |
| `owner-status`, `member-enroll-pin`, `owner-list-members`, `owner-list-membership-plans`, `owner-save-membership-plan`, `owner-register-member` | OPTIONS 204 with required origin/method/headers. |
| `owner-create-pin-enrollment-token` | OPTIONS 200 with required origin/method/headers. |
| `owner-create-membership-purchase`, `owner-list-membership-purchases`, `owner-membership-payments`, `owner-membership-lifecycle`, `owner-reporting`, `owner-attendance`, `owner-receipt-review`, `owner-cash`, `owner-attendance-claims`, `owner-create-pin-recovery-token`, `member-reset-pin`, `owner-walkins`, `public-walkin-request`, `member-checkin` | OPTIONS 404; required endpoints absent from this frontend-configured project. |

This explains why a working static site and reachable Owner authorization
endpoint coexist with failed Payments/Walk-ins/public requests. SQL query or RLS
changes cannot repair these gateway 404s. The user subsequently confirmed that
`alxhytivwybjbkjjdsyn` is the intended production project. Applied migration
versions remain outstanding; review those prerequisites before requesting
authorization to deploy the missing handlers. Project confirmation does not
authorize production database changes or enable gated public operations.

## Request tracing and confirmed local defects

| Entry point | Server path | Evidence / disposition |
| --- | --- | --- |
| Payments | `PaymentsPage` → `owner-membership-payments` → Auth `getUser` → `api.owner_list_membership_payments` / `api.owner_list_payable_purchases` | Live gateway 404: handler missing from configured project. Reads verified against synthetic handlers and SQL separately. |
| Owner Walk-ins | `WalkinsPage` → `owner-walkins` → Auth `getUser` → `api.owner_list_walkin_requests` | Live gateway 404: handler missing from configured project. Synthetic handler/SQL coverage. |
| Entrance walk-in | `EntrancePage` → `public-walkin-request` → release/config checks → `api.public_create_walkin_request` | Live gateway 404: handler missing from configured project. Independent local preflight-order defect corrected; server still controls the fee snapshot, ID and expiry. |
| Member entrance / PIN | Public handlers → independent release gates → narrow private operations | Same preflight ordering defect found in member check-in, PIN enrollment/reset and Owner PIN-link issuance; corrected without enabling them. |

Confirmed root causes in source and synthetic reproduction:

1. **CORS checks depended on service availability.** Eight handlers evaluated
   missing credentials or disabled release flags before answering OPTIONS. With a
   valid `APP_ORIGIN`, browsers still rejected the preflight, hiding the intended
   safe unavailable response behind a transport error. Valid-origin preflight now
   succeeds independently; untrusted origins still fail and POST remains gated.
   Missing/wrong `APP_ORIGIN` deliberately still fails closed.
2. **Payment retries omitted the payable list.** “Refresh payments” reloaded only
   history. A failed payable lookup stayed failed until navigation/search changed.
   It now retries both reads. History and payable errors are independent, so a
   successful read cannot clear the other read's failure.
3. **Load errors looked like empty data.** Payments, walk-ins, members, plans,
   purchases, attendance, audit, receipt review, cash and presence review could
   display empty-state rows after a failed request. They now show unavailable
   states. Walk-in and review-list failures clear on successful reload. The Member
   directory also lacked a dedicated retry control; one was added after the
   browser regression reproduced the missing recovery path.
4. **Opaque Owner read failures.** Payment and walk-in loads discarded useful HTTP
   status distinctions. They now present safe session/access/rate/service messages
   without rendering response bodies, SQL, identifiers or credentials.
5. **Configuration contradicted the approved RPC boundary.** Local API exposure
   included `public` and `graphql_public`. Configuration and both source/PowerShell
   assertions now require exactly `["api"]`. This is a local configuration change,
   not a hosted schema-setting change or a confirmed cause of the production
   request failures.
6. **Walk-in infrastructure failures lacked safe log evidence.** Unexpected RPC
   failures now log only a bounded SQL/PostgREST error code, or the allowlisted
   `WALKIN_FEE_UNAVAILABLE` marker. No request payload, token, identity, receipt,
   PIN or raw database message is logged.

The live gateway 404s confirm a common deployment mismatch. After resolving that
mismatch, use these distinctions for any subsequent failures; deeper problems
must not be inferred from the current gateway failures:

| Observation | Investigate without changing financial data |
| --- | --- |
| OPTIONS 404 | Missing/incorrect function deployment or wrong project URL. |
| OPTIONS rejected / origin mismatch | Exact `APP_ORIGIN`, Pages canonical/preview origin, deployed handler version. |
| Gateway 401 before handler | Deployed gateway JWT setting versus checked-in `verify_jwt = false`; retain handler `getUser` and SQL Owner checks. |
| Handler 401 | Session validity and project consistency. Never paste bearer tokens into reports. |
| Handler 403 | Origin or inactive/non-Owner authorization. Do not weaken RLS/grants. |
| Handler 5xx | Required server configuration, missing migrations/RPCs, `api` exposure, constrained executor grants/RLS. |
| Public 503 | Intentional release gate, missing explicit limiter, missing fee, or RPC failure; 503 alone does not distinguish them. |
| Public 429 | Explicit rolling limiter; wait rather than bypassing it. |

Local `.env.local` contains both required browser variable names with nonempty
values. Values were not printed. This does not validate them or establish the
Cloudflare build environment. The existing Pages `_headers`, Vite/PWA setup,
Supabase function declarations, grants and migration tests were reviewed.

## Files changed in this session

- `src/components/PaymentsPage.tsx`, `WalkinsPage.tsx`: independent read errors,
  retry recovery, safe status messages and unavailable/empty separation.
- `src/components/MembersPage.tsx`, `MembershipPlansPage.tsx`,
  `MembershipPurchasesPage.tsx`, `AttendancePage.tsx`, `AuditLogPage.tsx`,
  `CashDrawerPage.tsx`, `ClaimReviewPage.tsx`, `ReceiptReviewPage.tsx`: distinguish
  failed lists; add member retry and clear review-list load errors on retry.
- `src/lib/function-error.ts`: allowlisted status messages; never render server
  response text.
- `supabase/functions/{owner-membership-payments,owner-walkins,
  public-walkin-request,member-checkin,member-enroll-pin,member-reset-pin,
  owner-create-pin-enrollment-token,owner-create-pin-recovery-token}/index.ts`:
  safe preflight ordering; bounded walk-in diagnostic logs.
- `supabase/config.toml`, `supabase/tests/check-security-config.ps1`,
  `scripts/check-source-security.mjs`, `tests/source-security.test.mjs`:
  enforce the approved local `api`-only exposure.
- `tests/edge-handlers.test.mjs`, `tests/function-error.test.mjs`,
  `supabase/functions/_shared/preflight_test.ts`: handler/auth/RPC/status/preflight
  regression tests using synthetic data.
- `scripts/test-browser.mjs`: failed-service recovery, empty-state distinctions,
  expanded mobile navigation and existing PIN/QR/PWA coverage.
- `scripts/diagnose-hosting.mjs`, `tests/hosting-diagnostics.test.mjs`: public
  read-only HTML/OPTIONS diagnostics and synthetic safety regression.
- `package.json`: add the three Node regression files to the existing test command.
- This report and the progress tracker: current evidence and deployment handoff.

**Database changes: none.** All 37 existing migration files are preserved. No
business-rule, financial-history, membership-date or RLS weakening was needed.
No dependencies were added. Existing operation IDs and immutable financial retry
payloads were preserved; no automatic mutation retries were introduced. Public
walk-in creation still lacks recovery of a lost success response: do not blindly
resubmit after an uncertain result; consult the Owner before creating another
request, particularly if money was received. No cross-reload deduplication or
production load/DoS certification is claimed.

## Verification results

Final command results are recorded below. These layers are
separate: browser fixtures are not a real Supabase end-to-end test, native SQL
uses a synthetic Auth shim, and Node handler tests use the installed SDK with
synthetic HTTP rather than the hosted Deno gateway.

| Check | Result |
| --- | --- |
| `npm.cmd run lint` | PASS, including final browser harness changes. |
| `npm.cmd run typecheck` | PASS. |
| `npm.cmd test` | PASS 37/37, including handler, safe-error and diagnostic regressions. |
| `npm.cmd run test:security` | PASS source checks, not runtime certification. |
| `npm.cmd run build` | PASS including static-only PWA generation and the final Member retry control. |
| `npm.cmd run test:database` | PASS all 37 migrations, lifecycle/finance/attendance/reporting tests, final permissions/RLS checks and nine deterministic two-session races. |
| Deno shared tests | PASS 103/103, including the eight-handler preflight regression. |
| Deno `check --cached-only --node-modules-dir=manual` on all 21 `index.ts` entrypoints | PASS including final logging changes. |
| `node scripts/test-browser.mjs --production` | PASS all management-page mobile navigation, targeted management-list failure/recovery checks, payment/walk-in safe error recovery, public unavailable/retry behavior, payable pagination, QR/PIN and static-only PWA cache assertions. |
| `git diff --check` | PASS; normal Windows line-ending notices only. |
| Hosted Auth/JWT/PostgREST/Edge/RLS and real-device PWA | UNTESTED. |
| Live Pages public routes / function preflight | 4 routes PASS; 7 function preflights PASS; 14 function preflights FAIL with 404. Three reported endpoints independently confirmed gateway NOT_FOUND. |
| Cloudflare deployed build | Public HTML/assets reachable. Embedded backend URL identified; build logs/SHA/branch, key validity and migration history remain UNVERIFIED. No deployment performed. |

Synthetic database evidence: `.cache/security-test-b1683ea1fe2643d891d80331cddb2e95`.
The cluster stopped and generated credential files were removed. Native
PostgreSQL 18.6 is not proof of hosted PostgreSQL 17 behavior.
Final production-browser evidence:
`.cache/browser-test-79da2cc0-dcc8-4473-8ff7-114912310c3d`.

Initial sandbox PostgreSQL startup and Deno executable access failed; authorized
local execution outside the sandbox resolved them. The first Deno command also
omitted the environment permissions required by four existing encryption tests;
the scoped rerun passed. Initial new preflight test attempts failed in test setup
(property descriptor and dynamic-import read permission), before handler
assertions. The expanded browser test found the missing Member retry control;
the application was corrected and the suite rerun. A subsequent PWA assertion
timed out: diagnostics showed an activated worker without document control.
Prompt-mode workers do not claim the first document; the harness now waits for
activation and navigates once before asserting control. No worker configuration
was changed to make this assertion pass. These are not hosted failures.

Coverage of requested business workflows:

- Native SQL verifies approved registration, full-payment activation, Option A
  month ends/leap dates, inclusive Manila expiry, early/lapsed renewal, payment
  review and cash/GCash/bank-transfer validation.
- Unit/SQL tests cover identifier normalization, wrong/unknown PIN outcomes,
  ineligible/expired membership, token versioning and one valid daily check-in.
- SQL races cover payment recording/confirmation, one-use token redemption,
  audit append, daily check-in, walk-in confirmation, receipt allocation, claim
  confirmation and void versus check-in. Both competing sessions were observed
  blocked before lock release.
- SQL tests cover no access before confirmed payment, Owner restrictions,
  no direct browser/service table access, immutable receipts/audit, unallocated
  money, void eligibility invalidation, income and drawer separation.
- UI fixtures cover navigation/mobile layout and safe public behavior. They do
  not verify real registration/payment/check-in flows across every hosted layer.

## Exact deployment preparation and Owner-controlled release

Do not deploy until the hosted evidence and remaining release gates in
`RELEASE-READINESS.md` are accepted. Instructions below are a handoff, not actions
already performed. Use the existing repository and Pages project.

1. Confirm the Pages production branch, deployed Git SHA, canonical HTTPS origin,
   Supabase project reference and intended preview configuration. GitHub's default
   branch does not establish the Pages production branch. Do not blindly push to
   a branch that triggers production deployment.
2. Run public diagnostics with the actual origins (no credentials required):

   ```powershell
   node scripts/diagnose-hosting.mjs https://SITE.pages.dev https://PROJECT.supabase.co
   ```

   This performs four public HTML GETs and OPTIONS for all 21 configured
   functions. It makes no Auth/data requests or writes. Success proves only shell
   reachability and CORS, not enabled services, Owner authorization or RLS.
   The live run for the supplied URL already confirms 14 missing functions.
   Obtain applied migration versions and bounded function logs from the
   Owner; preserve request time/function name without member/payment payloads.
3. In Pages **Build settings**, confirm repository root, `npm run build`, output
   `dist`, and a Node version compatible with the installed Vite toolchain. These
   settings follow [Cloudflare's Vite build guidance](https://developers.cloudflare.com/pages/configuration/build-configuration/).
   Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` for the intended
   production build environment. Verify project matching and absence of a secret
   or service-role browser key. Vite embeds these values at build time; changing
   a dashboard variable requires a new build.
4. In Supabase, the Owner verifies `APP_ORIGIN` equals the exact canonical origin
   (scheme/hostname/port, no path/trailing slash); built-in URL and server-role
   credentials exist server-side; an appropriate public Auth key is available.
   Do not paste values into this report or commit them. Keep `PUBLIC_WALKIN_ENABLED`
   disabled until isolated runtime acceptance, an explicitly tested
   `WALKIN_REQUEST_LIMIT_PER_MINUTE` and an Owner-configured fee are approved.
   Keep PIN/check-in/claim switches disabled until their existing release gates
   are accepted. Do not create a fee directly in SQL to mask configuration errors.
5. The Owner compares hosted migration history with the 37 source migrations.
   A separately authorized migration operator may use the installed CLI:

   ```powershell
   npx.cmd --no-install supabase migration list --linked
   npx.cmd --no-install supabase db push --linked --dry-run
   ```

   These require an already verified Owner-controlled project link and credentials.
   Alternatively, the Owner can run this read-only query in that project's
   Supabase SQL Editor and share only the version results:

   ```sql
   select version
   from supabase_migrations.schema_migrations
   order by version;
   ```

   If the history table is missing or the query is denied, report that outcome;
   do not create a history table, grant access or mark migrations applied.
   No new SQL migration is introduced by this fix. If earlier migrations are
   missing, stop for an exact reviewed migration plan, verified backups/recovery
   and explicit production database approval. Never reset, repair history,
   rewrite audit hashes or broadly grant access to make the UI work. Review
   restricted-role/migration authority compatibility in the intended hosted
   runtime before any apply. Changing hosted API exposure to `api` only also
   requires approval and testing; local TOML does not apply that hosted setting.
6. After confirming the intended project, migration prerequisites and release
   authorization, deploy the 14 missing functions and the two already-present
   PIN handlers changed in this fix. Use the installed CLI and the
   Owner-confirmed project reference:

   ```powershell
   $gymforceProjectRef = 'alxhytivwybjbkjjdsyn'
   $gymforceFunctions = @('owner-create-membership-purchase','owner-list-membership-purchases','owner-membership-payments','owner-membership-lifecycle','owner-reporting','owner-attendance','owner-receipt-review','owner-cash','owner-attendance-claims','owner-create-pin-recovery-token','member-reset-pin','owner-walkins','public-walkin-request','member-checkin','member-enroll-pin','owner-create-pin-enrollment-token')
   foreach ($gymforceFunction in $gymforceFunctions) {
     npx.cmd --no-install supabase functions deploy $gymforceFunction --project-ref $gymforceProjectRef
     if ($LASTEXITCODE -ne 0) { throw "Function deployment failed: $gymforceFunction" }
   }
   ```

   Verify the checked-in per-function `verify_jwt = false` configuration is
   honored; preserve explicit Auth verification and SQL Owner checks. Refer to
   [Supabase function configuration](https://supabase.com/docs/guides/functions/function-configuration)
   and [authorization headers](https://supabase.com/docs/guides/functions/auth-headers).
   The other five configured functions answered live preflight successfully;
   this does not certify their POST behavior or deployed source version.
7. Rerun local checks below, review only intended files, then make a normal commit
   and authorized push through the existing GitHub/Pages workflow. Do not stage
   `.env`, `.cache`, unrelated drafts or existing user changes. Verify the Pages
   build/deployment log and deployed SHA. Confirm headers and SPA fallback for all
   public routes with the diagnostic command after deployment.

   ```powershell
   npm.cmd run lint
   npm.cmd run typecheck
   npm.cmd test
   npm.cmd run test:security
   npm.cmd run build
   npm.cmd run test:database
   deno test --cached-only --node-modules-dir=manual --allow-read=supabase/functions --allow-env=MEMBER_MOBILE_ENCRYPTION_KEY_B64,MEMBER_MOBILE_HMAC_KEY_B64 supabase/functions/_shared
   node scripts/test-browser.mjs --production
   git diff --check
   ```

## Final production acceptance checklist

All items remain open for hosted acceptance unless separately evidenced by the
Owner. Use synthetic identities in an explicitly authorized isolated environment;
do not create synthetic financial transactions among real production records.

- [ ] Owner confirms Pages SHA/branch/build success, correct project URL/public
  key, exact origin, HTTPS, SPA routes and headers. No secrets in browser assets.
- [ ] All function deployments and exposed `api` RPCs match reviewed source;
  private tables remain unexposed and runtime grants/RLS pass negative tests.
- [ ] Real Auth → Edge → PostgREST → SQL verifies active Owner; ordinary member,
  unauthenticated, revoked, forged and expired sessions cannot manage the system.
- [ ] Owner loads payments/payables/walk-ins with real HTTP success; successful
  empty lists differ from missing deployment, CORS, session and server failures.
- [ ] Approved registration plus full confirmed receipt activates only on the
  correct Manila date; delayed confirmation, expiry and early/lapsed renewals
  retain Option A behavior. Approval/payment alone never grants premature access.
- [ ] Cash, GCash and bank transfers require actual receipt verification; pending,
  mismatched, unallocated and voided payments retain original history correctly.
- [ ] Member ID/mobile + PIN works after approved setup; invalid/unknown/ineligible
  requests remain generic. Concurrent duplicate daily check-ins yield one valid
  row, including around Manila midnight; test real runtime abuse limits.
- [ ] Public walk-in has server fee/version/ID and 15-minute expiry; only the Owner
  confirms receipt; expired requests never revive. Duplicate confirmation retries
  do not duplicate receipt/attendance; lost-response cases are reviewed safely.
- [ ] Dashboard/reports match confirmed income and valid attendance. Drawer cash
  includes verified unallocated cash separately; voids preserve audits and
  invalidate affected eligibility. No financial totals are edited to match cash.
- [ ] QR scans to the permanent public entrance without credentials/member data.
  Real phones pass navigation, layout, PWA install/update and offline-denial tests;
  sensitive APIs, PINs and attendance are absent from caches/logs.
- [ ] Owner accepts privacy/retention, backup/recovery drill, evidence procedures,
  release switches and production PIN/KDF/shared-network/DoS values. No extra staff
  accounts, checkout, refunds, complimentary access or member dashboards exist.

If deployment or migration fails, keep gates closed, preserve existing data and
logs, and return to the reviewed release plan. Prefer a reviewed application
rollback through the existing hosting workflow; never reverse ledger/audit data
or reset the database as a rollback shortcut.
