# Phase 5.6 local release-candidate stabilization

2026-11-19, Asia/Manila. Branch `master`; unchanged HEAD
`ad41b7988d0d9fc4a56e675aeaff9b613878cdda`.

**Local application candidate: ready for Owner code review, with Android acceptance open.**
**Production: NO-GO. A02: PENDING OWNER DECISION.** No production connection,
SQL, database changes, installation, commit, push, merge or deployment occurred.

## Baseline and reproduced defect

Reviewed the development-progress, November 19 local sprint, consolidated
recovery-readiness and Owner-decision reports, and the eight existing sprint
files listed below. Existing recovery evidence and proposed approvals remain
separate from application acceptance. Owner-only management is the initial
scope; manager/front-desk accounts and membership cancellation are excluded.

The dev server watched the repository's generated `.cache` directory. Git's
ignore rule does not exclude it from Vite's watcher. That directory contains
native database clusters and live Chrome profiles created by the local tests.
Before the correction, Vite emitted EBUSY watcher errors for Chrome's Cookies,
Cookies-journal and Session files. A direct probe took about 17,981 ms to serve
the stylesheet; another unexcluded probe exceeded its 45-second request budget.
An uncorrected browser rerun also timed out during navigation. The previous
sprint's CSS/SDK timeouts are documented in its own report.

Tracing Vite hooks located the CSS delay inside `vite:css` transformation, not
React rendering. Excluding `.cache` with an otherwise unchanged configuration
served CSS in approximately 328 ms and the optimized SDK in 225 ms; the probe
completed in 703 ms overall. The full dev browser regression then passed.
An earlier unexcluded probe served the SDK in 191 ms: the SDK is not consistently
defective; no SDK import or optimizer workaround is justified by this evidence.
The identified environmental cause is excessive/contended generated-file
watching. Individual filesystem waits were not CPU-profiled.

The correction adds `server.watch.ignored: ['**/.cache/**']`. It keeps source
watching, dependency optimization, CSS transforms, security checks and production
bundling enabled. No cache deletion, dependency upgrade, polling, security
disablement or larger application timeout was used to obtain the PASS.
Vite documents root-directory watching and explicit exclusions in its
[server options](https://vite.dev/config/server-options) and recommends excluding
large directories in its [troubleshooting guide](https://vite.dev/guide/troubleshooting).
This is a watcher exclusion, not a file-access or data-retention guarantee.

## Implementation and regression review

- `vite.config.ts`: exclude only generated `.cache` contents from dev watching.
- `tests/vite-development.test.mjs`: start the real configured Vite server on an
  ephemeral loopback port; require HTTP 200 for the actual CSS and optimized
  Supabase SDK, with bounded requests. Create synthetic source/artifact probes,
  verify source watch events arrive and ignored artifact events do not, then
  remove only those probes and close the server. No SDK/API mocks are used.
- `package.json`: add `test:dev`; preserve the earlier public-contract test entry.
- `scripts/test-browser.mjs`: bound readiness fetches; verify replacement PIN
  links in the same document, replacement token use, fragment removal, stale
  PIN/error clearing, and clearing a prior successful completion. Production
  checks now exercise browser offline transition and disabled public submissions.

The earlier public-entry contract fixes remain unchanged. Seven Node tests
compare reset-token and money parsing with actual shared server parsers.
Browser tests reject five malformed walk-in snapshots without false pending
confirmation or automatic retry, reject reset lengths 40/42/44/128, and accept
the generated 43-character contract. Replacement B/C links are synthetic only.
No Auth, Owner authorization, database, payment, PIN KDF or release gate changed.

An initial new watcher test incorrectly relied on `getWatched()` enumerating
recursive directories; Vite's watcher reports explicitly registered files there.
That test failed and was corrected to check actual source/artifact watch events.
The final test passes; the initial failure is not counted as product acceptance.

## Fresh verification

Environment: Windows PowerShell; Node 24.21.0, Vite 8.3.5, cached Deno 2.9.8,
installed headless desktop Chrome. All app browser requests use synthetic
loopback Auth/API fixtures. Commands below completed successfully unless marked
not rerun. Separate repeated runs are not added to test counts.

| Command/check | Actual result |
| --- | --- |
| `npm.cmd run lint` | PASS; rerun after final test changes. |
| `npm.cmd run typecheck` | PASS. |
| `npm.cmd test` | 45 passed, 0 failed, 0 skipped; includes A05 and public-contract regressions. |
| `npm.cmd run test:security` | PASS; static source boundaries, not hosted proof. |
| `npm.cmd run test:dev` | 1 passed, 0 failed, 0 skipped; real CSS/SDK and watcher-event regression. |
| `node --test tests/recovery.test.mjs tests/recovery-sql.test.mjs tests/recovery-compatibility.test.mjs tests/recovery-integrity.test.mjs tests/hosted-package.test.mjs` | 25 passed, 0 failed, 0 skipped. All 30 candidates, history/source hashes, compatibility AST, encoding and tamper/refusal cases. No SQL executed. |
| `node docs/production-preflight/sql-editor/validate.cjs` | PASS: 16 variants each under PG17 and PG18 grammar; original approved hashes unchanged. No SQL executed. |
| Deno shared tests, command below | 105 passed, 0 failed; actual all-21-handler CORS/Auth/config/gate regression included. |
| Deno cached `check` on all endpoint `index.ts` files | 21/21 passed. |
| `npm.cmd run build` | PASS: TypeScript, Vite and PWA generateSW; 9 precache entries, 606.00 KiB. Vite bundle phase 1.13 s; PWA completion took longer. Exit 0 verified after worker generation. |
| `node scripts/test-browser.mjs` | PASS after watcher correction; actual React dev rendering, mobile/desktop navigation and synthetic workflows. |
| `node scripts/test-browser.mjs --production` | PASS; same-document links, offline public submission blocking, active controlling worker and static-only cache checks. Zero external app requests. |
| `node --check scripts/test-browser.mjs` and new test file | PASS. |
| `git diff --check` | PASS. Line-ending notices are Git autocrlf warnings, not migration changes. |
| PostgreSQL runtime compatibility/races | NOT RERUN: no SQL/security-architecture change. The existing runner always initializes a new cluster and has no reuse mode; this task limits PG tests to an existing authorized environment. No new cluster or test environment was created. |

Cached Deno command (installed executable, no network dependency resolution):

```text
deno test --cached-only --node-modules-dir=manual --allow-read=supabase/functions --allow-env=MEMBER_MOBILE_ENCRYPTION_KEY_B64,MEMBER_MOBILE_HMAC_KEY_B64 supabase/functions/_shared
deno check --cached-only --node-modules-dir=manual <the 21 existing endpoint index.ts paths>
```

The November 19 sprint's native PG17.12 PASS, nine races and eleven legacy
refusals remain **historical local evidence**, not fresh Phase 5.6 results and
not proof of Supabase-hosted ADMIN/ownership authority. No PG18 substitution.

Ignored browser evidence:

- Dev after watcher correction: `.cache/browser-test-cc253513-a1f2-4245-aa59-3479ec9060f3`.
- Dev including replacement-link cases: `.cache/browser-test-6e79e5ae-8b38-4122-b5ca-02016a9cac02`.
- Final exact-harness dev rerun: `.cache/browser-test-6d51bce7-79e4-4fee-9724-8c6e25e47f9e`.
- Production including offline/cache checks: `.cache/browser-test-d0d8da3d-2384-4585-a725-2374aaf43f6e`.

## Android/PWA readiness

| Area | Evidence and limit |
| --- | --- |
| Manifest | Generated name/short_name, root start_url/scope, standalone display and theme/background colors present. Only `/pwa.svg`, sizes `any`, purpose `any maskable` is declared. Explicit 192/512 raster fallback icons are absent. |
| Installability | NOT VERIFIED on Android. Chrome's [published promotion criteria](https://web.dev/articles/install-criteria) include HTTPS, engagement and 192/512 icons. Desktop worker/mobile emulation does not certify Android install promotion or WebAPK behavior. Review icon compatibility before claiming install readiness. No icon redesign or new dependency was introduced. |
| Service worker/cache | Production worker controls the page. Generated worker precaches static assets/index only and uses index navigation fallback; browser cache inspection found no Auth/API/PIN/attendance submissions. No runtime data cache added. |
| Offline | Browser offline transition shows the notice and disables member/walk-in submission with no request/queue creation. Offline cold-launch fallback, updates across versions and OS storage eviction were not device-tested. Owner claims remain provisional; no durable queue added. |
| Viewport/navigation | Existing 375x812 and 1280x900 browser assertions pass across all Owner pages. Touch keyboard, Android navigation and standalone safe areas remain device acceptance items. |
| Camera/QR | App generates the permanent public entrance URL QR; no in-app camera/getUserMedia permission flow exists. External Android camera/QR-reader behavior and HTTPS production routing require real-device acceptance. No identity/PIN in QR. |

## Exact working-tree inventory and review scope

Pre-existing eight sprint files at start (preserved):

1. `docs/GYMFORCE-DEVELOPMENT-PROGRESS.md` — tracked edit; append Phase 5.6 status.
2. `docs/SPRINT-2026-11-19-LOCAL-RC.md` — untracked, unchanged this phase.
3. `package.json` — tracked edit; add only `test:dev` this phase.
4. `scripts/test-browser.mjs` — tracked edit; additional regressions/readiness bound this phase.
5. `src/components/EntrancePage.tsx` — tracked edit, unchanged this phase.
6. `src/components/PinSetupPage.tsx` — tracked edit, unchanged this phase.
7. `src/lib/public-entry-contract.ts` — untracked, unchanged this phase.
8. `tests/public-entry-contract.test.mjs` — untracked, unchanged this phase.

New Phase 5.6 scope: `vite.config.ts` (tracked modification),
`tests/vite-development.test.mjs` (new untracked), this report (new untracked),
plus the three additional edits to pre-existing files identified above.
No other pre-existing files were changed in this phase.
Final working tree: 6 tracked modifications and 22 untracked files; no staged
files. Of those, six files were edited/created in Phase 5.6; the remaining
changes predate it.

Other pre-existing untracked files, preserved without edits:

```text
docs/GYMFORCE-CONSOLIDATED-RECOVERY-READINESS.md
docs/GYMFORCE-OWNER-DECISION-MATRIX.md
docs/GYMFORCE-PRODUCTION-RECOVERY-GATES.md
docs/M2-OWNER-SECURITY-REVIEW.md
docs/PHASE-5-2-HOSTED-READINESS-RESULTS.md
docs/PHASE-5-2-MANUAL-DIAGNOSTIC-GUIDE.md
docs/PHASE-5-2-WINDOWS-PSQL-QUALIFICATION.md
docs/PHASE-5-3-COMPATIBILITY-RESOLUTION.md
docs/PHASE-5-4-INTEGRATION-TEST-REPORT.md
docs/PHASE-5-CONSOLIDATED-COMPATIBILITY-RECOVERY-REVIEW.md
docs/PHASE-5-FINAL-READINESS-ASSESSMENT.md
docs/PHASE-5-M1-M2-DIAGNOSTIC-PREPARATION.md
docs/PHASE-5-TARGETED-REMEDIATION-PLAN.md
scripts/recovery/validate-hosted-package.mjs
supabase/recovery/diagnostics/m1-plan-routine-components.sql
supabase/recovery/diagnostics/m2-data-privilege-attribution.sql
tests/hosted-package.test.mjs
```

Generated `dist/`, browser profiles/screenshots and investigation probes under
`.cache/` are ignored. Test source probes were removed. No environment-file
contents or private evidence were inspected. Source-boundary tests passed; this
is not a fresh secret audit of unrelated private artifacts. Nothing was staged.
Original migrations, Edge/shared source, package lock, diagnostics and
`src/style.css` have no new tracked diff. M1/M2 byte hashes remain respectively
`c0477249f71a2ab4065d5b43392dcdd326e919201fee56188331799b0b21390a` and
`b4acd4b9caf0a6d40135a418e7b05e850f953ebe23cecbcf8b70820a0906b6cd`.

Proposed commit message (not executed):
`fix: stabilize Vite development watching and extend browser regressions`.
Review the previous sprint's frontend fixes separately from this narrow dev/test
change; do not stage unrelated recovery/approval drafts automatically.

## Remaining release blockers

- A02 revised trust model needs an explicit Owner decision and independent
  hosted grantor, membership, schema/extension authority and cleanup evidence.
- A03/A04/A07 and M1/M2 require separately authorized hosted reconciliation,
  effective privilege/reference/visibility checks and legacy-data safeguards.
  Unrecorded history is not permission to replay or repair it.
- Actual Auth/Edge/PostgREST full-stack acceptance, endpoint release alignment,
  backup/restore/RPO/RTO/key custody and controlled release approvals remain open.
- PIN token/KDF/abuse values, privacy/retention/evidence procedures, durable
  offline claims policy and lost-public-creation-response recovery remain gated.
- Android installation/update/QR acceptance and manifest icon compatibility
  remain unverified. No local result opens the production release gate.

The dev-only blocker is resolved locally. This candidate is ready for focused
Owner code review, not Phase 6 production execution. **Production remains NO-GO.**
