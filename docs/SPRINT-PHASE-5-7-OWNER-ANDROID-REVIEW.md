# Phase 5.7 - Owner code-review preparation and Android PWA qualification

2026-11-19, Asia/Manila. Original repository, `master`, unchanged HEAD
`ad41b7988d0d9fc4a56e675aeaff9b613878cdda`.

**Local candidate: GO for Owner code review only. Physical Android acceptance:
NOT VERIFIED. Production/release: NO-GO. A02: PENDING OWNER DECISION.**
This technical review does not constitute Owner approval of code, the revised
continuing-ADMIN model, diagnostic execution, migration artifacts or deployment.
No database connection/SQL, historical migration change, installation, staging,
commit, push, merge or deployment occurred.

## Baseline and scope

Read the Phase 5.6 stabilization and November 19 sprint reports, development
progress, Owner decision matrix and production recovery gates. Captured the
initial 28 dirty-file paths/statuses and byte hashes in ignored
`.cache/phase57-baseline.json`. All pre-existing changes were preserved.
Reviewed the complete tracked candidate diff, new frontend contracts/tests,
browser/Vite test code and relevant unchanged authorization/payment boundaries.
Recovery drafts are retained as drafts; checking their integrity does not approve
their proposed security model. PostgreSQL runtime results remain historical.

## Findings and corrections

| ID / severity | Evidence and impact | Disposition |
| --- | --- | --- |
| R57-01 / **High**, local development confidentiality | Phase 5.6 excluded `.cache` from watching, but not HTTP serving. A harmless unique sentinel returned HTTP 200 and its content through both `/.cache/` and `/@fs/<repo>/.cache/`. Browser profiles/database test artifacts reside there. Any caller able to reach this dev server could request known artifact paths; no actual credential or private file was requested, and production exposure is not asserted. | **FIXED locally** at `vite.config.ts:10`. Add `.cache` to `server.fs.deny`, retaining all six installed Vite default patterns. `tests/vite-development.test.mjs:37` compares the defaults and requires 403 for normal, @fs, raw, raw-import and mixed-case paths; no sentinel content returned. CSS/SDK and source watching still pass. |
| R57-02 / **Medium**, pre-existing public creation recovery limitation | `src/components/EntrancePage.tsx:78`: in-memory in-flight/request guards prevent immediate duplicate actions, but no public creation idempotency/recovery key survives a lost committed response or reload. Error guidance at line 100 warns to consult the Owner before retrying after payment. This is the existing A08 limitation, not a new regression or proof of duplicate money/attendance. | **OPEN**. Requires an approved recovery/idempotency design and server acceptance before operational use. No speculative client persistence, automatic retry, payment confirmation or historical migration edit added. |
| R57-03 / **Low**, update awareness | `vite.config.ts:18` uses prompt-mode registration. No application update-ready UI is present. A generated-worker update installs and waits while the current document stays controlled by its active worker. Users keeping all tabs open may continue using the old version. | **OPEN UX limitation**. Preserve safe non-interruption of forms; a future update-ready UX should request explicit user action. Full two-version activation/old-cache retirement remains device acceptance work. No forced reload/skipWaiting added. |

No new Critical finding or unresolved High application defect was established
in this scoped review. This is not a claim that untested hosted authorization,
RLS or real-device security has passed.

### Review of application/security boundaries

- `src/components/PinSetupPage.tsx:8` and `src/lib/public-entry-contract.ts:12`:
  reset format is exactly 43 URL-safe characters; enrollment retains its approved
  existing parser contract. Fragments are removed before paint and on replacement.
  Replacement clears stale PIN/error/completion state; an in-flight request
  refuses replacement. Tokens remain capabilities, not Owner identities.
- `src/components/EntrancePage.tsx:95` and `src/lib/public-entry-contract.ts:19`:
  malformed successful walk-in payloads are rejected; output fields are
  allowlisted and money formatting uses the existing exact-decimal utility.
  Pending references do not assert payment or valid attendance. Client time does
  not decide eligibility or revive expiry.
- Member requests still contain identifier/PIN only. PIN fields clear on denial
  and now-tested network interruption. No new logs, persistent queue, sensitive
  cache, QR identity data or public Owner/member registration was introduced.
- `src/App.tsx:86` still requires authenticated, active-Owner and authorization-
  ready responses. Auth-generation guards and immediate sign-out removal remain.
  Hidden navigation and browser types do not grant server access. All 21 actual
  Edge handlers retain CORS, missing-config, Auth and feature-gate regression
  coverage. A05 malformed-list regressions still pass.
- Payment/membership pages, Edge/shared runtime, SQL, executor/RLS/ACL definitions
  and business rules are unchanged. Existing operation IDs and uncertain-outcome
  handling remain. No manager/front-desk, cancellation, refund, complimentary
  term, checkout or unverified payment confirmation was added.
- A targeted scan of all 28 initial dirty text files found **0** secret-key,
  private-key-block or password-bearing PostgreSQL URL patterns. Source security
  tests pass. This limited scan is not a guarantee against every possible secret
  encoding. No `.env` or private-evidence contents were inspected or printed.

## Android/PWA technical qualification

The real browser is **desktop Chrome 157.0.8103.79** with Android 14 user-agent,
375x812 mobile viewport and touch emulation. This is not Android Chrome/WebAPK.
No physical device or authorized device-debug session was available; `adb` was
not found in PATH. No software was installed or device connected.

| Area | Actual local result / limit |
| --- | --- |
| Manifest | Chrome parsed generated manifest with zero errors. `standalone`, `/` scope/start URL, name/short_name and theme/background colors are present. `Page.getInstallabilityErrors` returned `[]`, now asserted by the regression. This does not verify actual install UI, engagement heuristics or WebAPK generation. |
| Icons | Existing 512-viewBox SVG declares sizes `any`, purpose `any maskable`. No 192/512 raster fallback added. This Chrome accepts the configuration without reported installability errors; the earlier icon concern is not a confirmed defect in this engine. Android launcher rendering/masking and compatibility remain unverified. |
| Secure context | `window.isSecureContext === true` at loopback. Localhost's exception does **not** verify hosted HTTPS, TLS, routing or certificates. No hosted request was made. |
| Registration | Worker activates and controls the synthetic production page after navigation. Development mode does not enable a production worker. |
| Updates | Appending a comment only to this run's generated `dist/sw.js`, followed by `registration.update()`, produces an installed waiting worker while the original controller stays activated. No forced activation or form disruption. Different application asset versions, Android process death and full cache retirement are not certified by this same-assets update probe. |
| Static caching | Browser inspection finds only index/assets/manifest/registration/icon precaches, no Auth/API/PIN/attendance submissions. Generated worker uses index navigation fallback and outdated-precache cleanup. No runtime data cache added. |
| Offline navigation | After emulated offline transition, navigate to a new `/entrance?synthetic-offline-navigation=1` document. URL and disappearance of a document-only marker prove a fresh document, not a stale visible page. Cached shell renders offline notice; public member/walk-in submissions stay disabled and no public request is created. This is not an Android cold OS launch. |
| Touch/layout | An actual CDP touchStart/touchEnd switches the entrance tab. All Owner navigation remains within the 375px viewport; desktop 1280x900 screenshot retained. Android keyboard/safe-area/back-gesture behavior remains manual acceptance. |
| Interrupted requests | A synthetic connection reset on member submission produces safe retry feedback, clears PIN and releases the busy button. Server commit-unknown reconciliation and public creation recovery remain independent. |
| Camera/QR | No app camera stream, permission prompt, BarcodeDetector or scanner lifecycle exists to initialize/clean up. The app displays/generates the public entrance URL QR; an external phone camera/scanner opens it. Do not treat absence of an in-app scanner as a missing approved feature. Physical scanning, permission denial and browser return behavior remain untested. |

## Fresh test evidence

All listed commands completed with **exit code 0** unless explicitly NOT RUN.
Repeated runs are not additive. Windows, Node 24.21.0, Vite 8.3.5, cached Deno
2.9.8; all browser APIs/Auth synthetic and loopback-only. No dependency download.

| Command | Result |
| --- | --- |
| `npm.cmd run lint` | PASS. |
| `npm.cmd run typecheck` | PASS. |
| `npm.cmd test` | 45 passed, 0 failed, 0 skipped. |
| `npm.cmd run test:security` | PASS, static boundary checks. |
| `npm.cmd run test:dev` | 1 passed, 0 failed, 0 skipped; five denied URL forms, installed-default preservation and real CSS/SDK/source-watching assertions. |
| `npm.cmd run build` | PASS: 110 modules, Vite phase 688 ms; PWA completion verified, 9 precaches / 606.00 KiB. Build duration includes longer worker generation, not only Vite phase. |
| `node scripts/test-browser.mjs` | PASS, 1 development suite; Android UA/touch and interrupted-request recovery included. |
| `node scripts/test-browser.mjs --production` | PASS, 1 production suite; exact final harness including asserted zero installability errors, fresh offline navigation and waiting-worker update. |
| `node --test tests/recovery.test.mjs tests/recovery-sql.test.mjs tests/recovery-compatibility.test.mjs tests/recovery-integrity.test.mjs tests/hosted-package.test.mjs` | 25 passed, 0 failed, 0 skipped; original hashes, encoding/tamper, compatibility AST and all 30 original candidate units. No SQL execution. |
| `node docs/production-preflight/sql-editor/validate.cjs` | PASS: 16 variants under each PG17/PG18 grammar; original hashes unchanged. |
| Cached Deno test command below | 105 passed, 0 failed, including all-21-endpoint actual preflight/Auth/config/gate regressions. |
| Cached Deno check below | 21/21 endpoint entrypoints PASS. |
| `node --check scripts/test-browser.mjs` and `node --check tests/vite-development.test.mjs` | PASS. |
| `git diff --check` | PASS; normal autocrlf notices only. |
| PG runtime compatibility/races | NOT RUN. No database logic changed; existing runner initializes a new cluster rather than reusing an already-authorized running environment. No fresh environment was created. Earlier PG17.12/race/refusal results remain historical, not fresh or hosted proof. |

Exact Deno arguments, using the existing installed binary:

```text
deno test --cached-only --node-modules-dir=manual --allow-read=supabase/functions --allow-env=MEMBER_MOBILE_ENCRYPTION_KEY_B64,MEMBER_MOBILE_HMAC_KEY_B64 supabase/functions/_shared
deno check --cached-only --node-modules-dir=manual <all 21 existing supabase/functions/*/index.ts entrypoints, excluding _shared>
```

Ignored evidence (synthetic only):

- Initial production qualification: `.cache/browser-test-4a3790b0-57d2-4d79-b679-b32a88905a59`.
- Final production run: `.cache/browser-test-2d833c78-9b3f-439f-9849-402b30f4295a`.
- Development run: `.cache/browser-test-79cbc327-7d20-49c0-a0e5-6d91d629d032`.
- `pwa-qualification.json` contains browser identity, generated manifest and empty
  installability-error array. Screenshots contain synthetic entrance/QR data only.
- Sentinel tests inspect synthetic content only; all their unique source/cache
  probe files were removed. Servers/browser processes launched by the tests close.

## Physical Android acceptance - NOT VERIFIED

Prerequisites: Owner selects an **existing authorized synthetic test target**,
confirms its build SHA and non-production API configuration, device model,
Android/Chrome versions and private evidence custody. Desktop CDP fixtures do
not automatically serve a phone. Do not point the phone at production or create
a replacement environment without separate authorization. If no safe target is
available, this checklist remains BLOCKED. USB localhost forwarding, if later
approved/configured, qualifies local behavior only; actual HTTPS needs its own
authorized target. No credentials or diagnostic SQL are needed for these steps.

| Step | Exact action | Expected outcome / evidence |
| --- | --- | --- |
| 1 | In Chrome, open the approved synthetic HTTPS origin; record displayed build, device/OS/browser versions and origin. | Correct target, valid HTTPS, no security warning. Keep test metadata privately; stop on production/identity/config mismatch. |
| 2 | Inspect site install UI, install, open from launcher, rotate once. | Correct icon/name, standalone window and readable content; no cropped controls. Record install outcome and redacted launcher screenshot. Failure remains FAIL, not waived by desktop diagnostics. |
| 3 | Scan the printed synthetic entrance QR with the device's external camera. Deny camera permission once, then allow if appropriate. Return/back and rescan. | Denial grants no access; scanner offers its own recovery; successful scan opens exactly the approved `/entrance` URL, with no identity/PIN/token embedded. No app camera stream remains because no in-app stream is created. |
| 4 | Tap member/walk-in tabs; use on-screen keyboard, scroll and Android back navigation. | No overflow/hidden submit button or unintended submit. PIN masked, no prior member/PIN left after intended clearing. Evidence must never show entered PINs. |
| 5 | In the synthetic fixture, submit malformed/denied and then interrupted member requests. Reconnect. | Safe generic feedback, cleared PIN, busy state released. No automatic resubmission. Synthetic valid check-in requires actual backend validation; do not infer that from rendered success. |
| 6 | Create a synthetic provisional walk-in, inspect its reference and pending message. Interrupt creation once. | No confirmed payment/attendance from public UI. On unknown outcome, consult Owner before retrying; record the unresolved A08 recovery limitation. Never use real payments. |
| 7 | Open synthetic reset link A, enter test fields, then replacement B on the same page; use invalid length then valid 43-character link. | Fragment removed, stale fields/errors cleared, correct replacement used; invalid link makes no reset call. Never screenshot/copy capability URLs or PINs into reports. |
| 8 | After a normal load, enable airplane mode; navigate to entrance, then close/reopen installed app. Try both public submissions. | Cached shell/clear offline message, no valid attendance/payment or queued public operation; submissions disabled. Record separately whether OS cold launch succeeds. |
| 9 | Reconnect, close every app window/tab, reopen. In a separately approved synthetic two-version update, repeat while a form is open. | No silent loss/forced submit. Waiting update does not interrupt the current form; after all controlled clients close, verify intended new build, static cache retirement and no private cached responses. Current local comment-update test does not satisfy this step. |
| 10 | With synthetic Owner access only, sign out while offline and inspect app/cache after reopening. | Sensitive management views disappear; no cached member/financial/PIN/API responses. Real hosted roles/RLS remain a separate acceptance gate. |

For each step record PASS/FAIL/NOT TESTED, time, target/build, device/browser and
sanitized evidence reference. Owner retains originals privately; report only
outcomes. Stop on private data, wrong origin, unexpected API target, security
warning or uncertain financial result. No physical step is marked PASS here.

## Exact changed-file inventory

Initial state: **6 tracked modifications, 22 untracked files**. Final state:
**6 tracked modifications, 23 untracked files**, none staged. `M` = tracked
modification; `U` = untracked. All initial paths remain.

```text
M docs/GYMFORCE-DEVELOPMENT-PROGRESS.md
M package.json
M scripts/test-browser.mjs
M src/components/EntrancePage.tsx
M src/components/PinSetupPage.tsx
M vite.config.ts
U docs/GYMFORCE-CONSOLIDATED-RECOVERY-READINESS.md
U docs/GYMFORCE-OWNER-DECISION-MATRIX.md
U docs/GYMFORCE-PRODUCTION-RECOVERY-GATES.md
U docs/M2-OWNER-SECURITY-REVIEW.md
U docs/PHASE-5-2-HOSTED-READINESS-RESULTS.md
U docs/PHASE-5-2-MANUAL-DIAGNOSTIC-GUIDE.md
U docs/PHASE-5-2-WINDOWS-PSQL-QUALIFICATION.md
U docs/PHASE-5-3-COMPATIBILITY-RESOLUTION.md
U docs/PHASE-5-4-INTEGRATION-TEST-REPORT.md
U docs/PHASE-5-CONSOLIDATED-COMPATIBILITY-RECOVERY-REVIEW.md
U docs/PHASE-5-FINAL-READINESS-ASSESSMENT.md
U docs/PHASE-5-M1-M2-DIAGNOSTIC-PREPARATION.md
U docs/PHASE-5-TARGETED-REMEDIATION-PLAN.md
U docs/SPRINT-2026-11-19-LOCAL-RC.md
U docs/SPRINT-PHASE-5-6-STABILIZATION.md
U docs/SPRINT-PHASE-5-7-OWNER-ANDROID-REVIEW.md
U scripts/recovery/validate-hosted-package.mjs
U src/lib/public-entry-contract.ts
U supabase/recovery/diagnostics/m1-plan-routine-components.sql
U supabase/recovery/diagnostics/m2-data-privilege-attribution.sql
U tests/hosted-package.test.mjs
U tests/public-entry-contract.test.mjs
U tests/vite-development.test.mjs
```

**Phase 5.7 edits only:** `vite.config.ts`, `scripts/test-browser.mjs`,
`tests/vite-development.test.mjs`, appended progress and this new report.
Baseline byte-hash comparison verifies all other existing dirty files unchanged.
Generated `dist/`, `.cache` profiles/evidence/probes and TypeScript outputs are
ignored. No historical migration, Edge/shared runtime, compatibility artifact,
lockfile, `src/style.css`, approved diagnostic or production configuration changed.
M1/M2 hashes remain:

```text
c0477249f71a2ab4065d5b43392dcdd326e919201fee56188331799b0b21390a
b4acd4b9caf0a6d40135a418e7b05e850f953ebe23cecbcf8b70820a0906b6cd
```

## Proposed review/commit contents and readiness decision

Proposed application candidate scope (12 files, no staging authorization):
`EntrancePage.tsx`, `PinSetupPage.tsx`, `public-entry-contract.ts`,
`public-entry-contract.test.mjs`, `vite-development.test.mjs`, `test-browser.mjs`,
`package.json`, `vite.config.ts`, development progress and the three sprint reports.
Use the full paths above; exclude the 17 unrelated pre-existing recovery/approval
drafts, all generated artifacts and secrets. Owner should review the earlier
frontend changes separately from the new dev-server protection/test extensions.

Proposed message: `fix: harden local artifact access and qualify PWA candidate`.
No commit, approval or publication is implied by this proposal.

| Gate | Decision |
| --- | --- |
| Local candidate code-review preparation | **GO for review**: reproduced High dev exposure fixed; scoped regressions green. This is not Owner code approval. |
| Android physical acceptance | **NOT VERIFIED / BLOCKED by device and safe target availability**. Checklist above is unexecuted. |
| A02 continuing-ADMIN model | **PENDING OWNER DECISION**; actual grantors/authority and cleanup remain hosted verification gates. |
| A03/A04/A07 and M1/M2 | **HOLD** for separately authorized effective privilege/reference/visibility, legacy-data and provenance reconciliation. No diagnostic approval inferred. |
| Hosted business/security integration | **NOT VERIFIED**; local fixtures and historical PG17 results do not prove hosted Auth/RLS/Edge or required endpoint release alignment. |
| Recovery/operating approval | **HOLD** for actual backup/restore/RPO/RTO/key custody, privacy/retention, PIN runtime/abuse parameters, public recovery policy and release approvals. |
| Production release / Phase 6 execution | **NO-GO**. No hosted change/deployment authorization. |

Next development milestone: complete the physical Android checklist on an
explicitly approved existing synthetic target and obtain Owner review of the
12-file candidate. A02 design acceptance and narrowly authorized hosted evidence
remain parallel prerequisites; neither can be replaced by more desktop reruns.
