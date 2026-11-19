# GYMFORCE accelerated local sprint — 2026-11-19

Base: master, `ad41b7988d0d9fc4a56e675aeaff9b613878cdda`.
**Uncommitted local candidate for Owner review. Production NO-GO.** A02 remains
PENDING OWNER DECISION. Existing untracked recovery work was preserved. No hosted
connection/SQL, historical migration edit, history/permission change, deployment,
dependency installation, release-switch change, commit or push occurred.

## Implemented defects

| Priority | Confirmed defect | Correction and regression |
| --- | --- | --- |
| 1, medium | EntrancePage accepted malformed successful walk-in responses: empty reference, boolean fee, excess precision, mismatched method or backwards expiry. Existing Edge validation already rejects these; frontend disagreed under response-contract drift. | Public-entry-contract parser validates the existing UUID/method/positive bounded cents/timestamp contract and allowlists public fields. Existing exact-decimal PHP formatter replaces floating-point display. Five malformed HTTP successes are rejected in the real production browser test. No device-clock eligibility decision or automatic retry. |
| 2, medium | PIN page consumed/removed a capability only at mount. Same-document replacement links retained their new fragments and stale form state. New production browser regression failed here before correction. | Hash-change handling removes the fragment and resets PIN/form state; refuses replacing an in-flight operation. Browser invalid-to-valid replacement and failure-secret clearing pass. Server authorization and one-use capability semantics unchanged. |
| 3, low | Reset UI accepted 40–128-character tokens, while actual reset parser requires 43. | Purpose-aware validation: reset 43; enrollment retains 40–128. Actual server-parser boundary/generated-token tests and four invalid browser token lengths pass. No KDF/lifetime/release-gate change. |
| Test tooling | Windows browser startup failures had poor diagnostics. | Prepare isolated profile explicitly, capture bounded about:blank startup stderr and initial empty-page evidence only, then stop capturing before private inputs. Dev initial-render wait is bounded at 60s; product/API/SQL timeouts unchanged. No Chrome security flag disabled. |

Sprint files: `src/lib/public-entry-contract.ts`,
`src/components/EntrancePage.tsx`, `src/components/PinSetupPage.tsx`,
`tests/public-entry-contract.test.mjs`, `scripts/test-browser.mjs`, `package.json`
(test command only), `docs/GYMFORCE-DEVELOPMENT-PROGRESS.md`, and this report.
No Edge/shared runtime, compatibility artifact, approved diagnostic, application
configuration, dependency lockfile or historical migration changed.

## Fresh verification

Windows; Node 24.21.0; installed Deno 2.9.8/cached dependencies; native PostgreSQL
17.12/170012; installed Chrome with synthetic CDP HTTP/Auth fixtures. Some tests
needed authorized execution outside the restricted process sandbox, not relaxed
security protections. All database mutations were isolated synthetic tests.

| Check | Actual result and limits |
| --- | --- |
| Initial lint/typecheck/npm test | PASS; original Node suite 38/38. Final counts below supersede this baseline. |
| Final `npm.cmd run lint`, `npm.cmd run typecheck` | PASS. |
| `npm.cmd test` | **45 passed, 0 failed, 0 skipped**, including seven new tests. Separate focused 7/7 run is not additive. |
| `npm.cmd run test:security` | PASS; static source boundaries, not hosted authorization proof. |
| Installed Deno: `test --cached-only --node-modules-dir=manual --allow-read=supabase/functions --allow-env=MEMBER_MOBILE_ENCRYPTION_KEY_B64,MEMBER_MOBILE_HMAC_KEY_B64 supabase/functions/_shared` | **105 passed, 0 failed**. Includes all-21-handler CORS/Auth/config/gate regressions and existing PIN/mobile/calendar/lifecycle/finance/claim validators. Initial Windows command-link launch failed; actual target executable succeeded under authorized context. |
| Same Deno: `check --cached-only --node-modules-dir=manual` on endpoint index.ts files | **21/21 passed**, endpoint count asserted. No dependency download or deployment. |
| `node --test tests/recovery.test.mjs tests/recovery-sql.test.mjs tests/recovery-compatibility.test.mjs tests/recovery-integrity.test.mjs` | **21 passed, 0 failed, 0 skipped**. Original migration/Edge/shared fingerprints, compatibility AST, encoding/tamper and reconciliation coverage. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-recovery-pg17.ps1 -CustomerCompatibility` | PASS, actual **17.12/170012**. 24 originals + 13 synthetic compatibility variants; business/security suites, ACL replay/default/inherited-denial checks, two ownership rollback probes, eleven legacy-refusal cases. Synthetic provider fixture is not hosted authority proof. |
| Concurrency within PG17 suite | **9/9 passed**: payment record/confirm, token redemption, audit append, daily check-in, walk-in confirmation, allocation, claim confirmation, void/check-in. Two blocked sessions observed. |
| Successful PG17 cleanup | PASS: server stopped; independent authorized metadata check found zero generated credential files, no postmaster.pid and eleven refusal-evidence files. |
| Final `npm.cmd run build` | PASS, latest app source; TypeScript + Vite/PWA, nine precache entries. An earlier successful build had ~198s PWA callback warning. |
| `node scripts/test-browser.mjs --production` | **1 suite passed**. Actual React, synthetic HTTP/Auth; mobile 375×812/desktop 1280×900, all Owner navigation, list failure/empty/retry, payable pagination, QR/PIN, five malformed walk-in cases and four invalid reset lengths. Zero external app requests; worker controls page, cache contains static shell only. |
| Development-mode `node scripts/test-browser.mjs` | **BLOCKED / initial-render timeout**. Page interactive but empty, no runtime exception or external request. Loopback probe served /@vite/client; CSS and SDK module responses timed out at 15s, including forced reoptimization. Root cause UNKNOWN; no claim this is a proven application regression. |
| `git diff --check` | PASS; Windows line-ending notices do not represent historical source changes. |

Successful PG17 evidence:
`.cache/security-test-c3a27fd0ff5a4fabb6651e7f58099568`.
Production browser:
`.cache/browser-test-afc12614-97c2-4de8-84c0-b556045a9e65`.
Dev boot:
`.cache/browser-test-17b5e01c-a52d-450c-be7e-370fd4b45890/entrance-startup.json`.
All are ignored synthetic artifacts, not production records or upload artifacts.

Initial PG startup failed with restricted-token error 87/start error 3 in
`.cache/security-test-56f2a7769e0f4802ad0a78a02e85f120`. The unchanged harness
passed in the authorized process context. Independent inspection of that first
protected failed directory was denied, so no independent cleanup PASS is claimed
for it. No existing PG18 service was modified/stopped. The successful harness
also ran unchanged M1/M2 SQL locally; that is not hosted execution approval.

## Remaining blockers and release assessment

| Area | Status / next action |
| --- | --- |
| Owner access | Synthetic checks PASS; actual hosted Auth/JWT NOT VERIFIED. Manager/front-desk accounts are outside approved initial scope. |
| Registration/activation/renewal/expiry | PG17/Deno synthetic PASS, including approved/full-paid basis, Manila/Option A and duplicate rules. Cancellation is prohibited, not an incomplete workflow. |
| Member QR/ID/mobile/PIN | Synthetic validator/SQL/race/browser coverage PASS. Production PIN token/KDF/abuse settings and real hosted acceptance remain gated. QR remains public URL only. |
| Walk-ins/receipts/corrections/cash/reports/audit | Synthetic business/security/race suites PASS. Actual hosted definitions, policies, legacy data and final endpoint inventory remain unverified. No client grants confirmed attendance/income. |
| Offline claims | Existing current-presence/review logic tested locally. Durable queue/retention/clock-drift/triage requirements remain Owner-gated; nothing silently confirmed or queued offline. |
| Android/PWA | Production worker/static cache/mobile viewport PASS. Real Android installation/update/offline-shell acceptance NOT VERIFIED. |
| Dev smoke | BLOCKED locally by Vite module stalls. Investigate transformation/optimizer/Windows environment separately; no speculative dependency upgrade or weakened assertions. |
| A02 | PENDING OWNER DECISION; local compatibility does not establish hosted ADMIN grantor/schema/extension authority or adopt the revised trust exception. |
| A03/A04/A07/M1/M2 | Hosted effective privileges, trusted references/catalog completeness, legacy compatibility and honest runner/history reconciliation remain independent gates. No new hosted evidence collected here. |
| Recovery/release | Owner backup/restore/RPO/RTO/key custody, maintenance/abort procedures and separate change/deployment approvals remain required. |
| Lost public creation response | Existing no-idempotency/lost-reference limitation remains. No automatic retry introduced. Owner-approved recovery design needed before operational opening. |

**Decision:** latest application changes pass production-mode local acceptance;
ready for Owner code review as an **uncommitted local candidate**. Overall local
QA is qualified by the dev-only smoke blocker. Phase 5 is not fully complete;
Phase 6/release is not authorized. Production **NO-GO**. Synthetic tests do not
prove real Supabase Auth/Edge/PostgREST, hosted privileges or recoverability.

Next local engineering action: isolate the dev-module stall. Key Owner
production-recovery action: explicit A02 design decision; acceptance for
verification would still not authorize execution or deployment.
