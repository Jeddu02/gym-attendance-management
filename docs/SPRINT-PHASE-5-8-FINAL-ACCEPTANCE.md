# Phase 5.8 - Reliability, update awareness and final acceptance preparation

2026-11-19, Asia/Manila. `master`, unchanged HEAD
`ad41b7988d0d9fc4a56e675aeaff9b613878cdda`.

**Local candidate: GO for Owner code review only. Physical Android: PENDING.
Production: NO-GO. A02 continuing-ADMIN model: PENDING OWNER DECISION.**
No hosted connection/SQL, database permission/history change, historical migration
edit, dependency installation, commit, push, merge or deployment occurred.

## Baseline and implemented changes

Reviewed Phase 5.7/5.6 reports, development progress, Owner decision matrix and
production recovery gates. Initial state was 29 dirty files (6 tracked edits,
23 untracked). Captured byte hashes in ignored `.cache/phase58-baseline.json`;
unrelated work and historical evidence were preserved.

### Public-request reliability

Source investigation: `supabase/functions/_shared/walkin-request.ts` accepts only
`paymentMethod` for public creation. `supabase/functions/public-walkin-request/index.ts`
can return 503 after an RPC error or malformed RPC success. No public operation
ID/recovery key or reference-retrieval contract exists. Neither HTTP failure nor
a client-side exception proves absence of a committed provisional request.
Owner confirmation already uses its own operation ID; that contract is unchanged.

`src/components/EntrancePage.tsx:80` now guards attempts synchronously with a ref,
in addition to the existing in-flight/success guards. Once a request is dispatched,
the current mounted page cannot dispatch a second creation, even through repeated
programmatic submit events or entrance-tab switching. A valid allowlisted success
still displays only a provisional reference, never confirmed money/attendance.

On transport failure, non-success HTTP response (including 503), or malformed
success, the page shows **outcome unverified / Owner review required** and disables
creation/method changes. It warns that a request may exist, not to submit/pay again,
and that reloading or another tab may duplicate it. No automatic retry, persisted
token/reference, new RPC argument or invented client idempotency guarantee added.
Configuration failure before dispatch remains an unavailable-service outcome.

**A08/R57-02 is mitigated, not resolved.** The ref is scoped to the mounted page,
not a trusted cross-tab/device/reload boundary. Actual duplicate prevention and
recovery require separately reviewed server support. Existing server payment,
expiry, receipt and attendance checks remain authoritative. Network failures are
handled when surfaced by the SDK/browser; no new application request deadline
or claim that aborting a client cancels a server commit was introduced.

### Owner update awareness and controlled activation

New `src/components/OwnerUpdateNotice.tsx` observes the existing registration's
ready/waiting/installing state and updatefound/statechange events. It handles an
already-waiting worker and cleans up listeners on unmount. Discovery failure
does not block operations. `src/App.tsx:411` mounts it **only in the verified
Owner view**; signed-out/public/PIN views do not receive this management notice.

The notice says an update is ready and offers “How to apply safely.” It instructs
the Owner to finish or resolve operations, close **all** app tabs/windows on the
device, then reopen. This uses the browser's normal waiting-worker lifecycle.
There is deliberately no immediate “reload now,” SKIP_WAITING message,
controllerchange reload, automatic sign-out, form reset or forced activation.
One page cannot certify that another tab has no active transaction. The explicit
finish-and-close procedure is the controlled activation path, not an automated
multi-tab transaction detector. No new worker, cache strategy or registration is
created; existing prompt-mode/static-shell behavior remains.

## Security and code-review findings

| Severity / area | Result |
| --- | --- |
| Critical/High regression | None established in the scoped candidate review. This is not hosted security certification. Phase 5.7's High dev-artifact exposure remains fixed; all five denied-path regressions pass. |
| Medium - public unknown outcome | Current-page retries now refused conservatively, with truthful feedback. Reload/cross-device recovery remains OPEN for server design and Owner approval. No unsupported idempotency field added. |
| Low - update awareness | IMPLEMENTED locally for verified Owner. Manual closure allows natural activation without disrupting current forms. Forced activation remains intentionally unavailable. |
| Auth/roles | App diff adds only the notice import/mount. Existing Auth/active-Owner generation checks remain; no manager/front-desk role, browser RPC grant or authorization shortcut. |
| PIN/member attendance | Earlier exact reset contract, replacement-link clearing, generic check-in responses and PIN clearing retain their browser/Node regressions. No KDF, token lifetime, membership date or duplicate-check-in rule changed. |
| Finance/walk-ins | No automatic payment confirmation, valid attendance, backdating, refund or receipt mutation. Existing server checks and operation IDs unchanged. |
| Privacy/offline/cache | New state contains booleans only, in memory. No local storage, offline queue, raw error logging or sensitive cache added. Public submissions stay disabled offline; Owner claims remain provisional. |
| Source integrity | Original migrations, Edge/shared runtime, compatibility artifacts, diagnostics, lockfile and `src/style.css` unchanged. Exact original fingerprint/static suites pass. |

## Fresh verification and evidence

Windows, Node 24.21.0, Vite 8.3.5, cached Deno 2.9.8 and installed desktop Chrome.
All following commands completed **exit 0**, except the explicitly unrun PG/device
checks. Repeated runs are not added to counts. APIs/Auth in browser tests are
synthetic loopback fixtures; no production connection or dependency download.

| Command | Actual result |
| --- | --- |
| `npm.cmd run lint` | PASS. |
| `npm.cmd run typecheck` | PASS. |
| `npm.cmd test` | 45 passed, 0 failed, 0 skipped. Existing A05/contract/security regressions retained. |
| `npm.cmd run test:security` | PASS; source boundaries, not hosted proof. |
| `npm.cmd run test:dev` | 1 passed, 0 failed, 0 skipped; real CSS/SDK, source events, preserved default denies and five forbidden artifact URL forms. |
| `npm.cmd run build` | PASS: 111 modules, Vite bundle phase 1.97 s; PWA worker completion verified, 9 precache entries / 607.41 KiB. |
| `node scripts/test-browser.mjs` | PASS, 1 development suite. Seven uncertain public outcomes lock repeated submits; five malformed successes never display pending confirmation; PIN, all Owner navigation, touch/network and existing workflows remain covered. |
| `node scripts/test-browser.mjs --production` | PASS, 1 production suite. Same reliability cases plus Owner-only update notice, mobile instructions, preserved form/document, waiting worker and natural activation after the only controlled client leaves; offline fresh navigation and static-only caches. |
| `node --test tests/recovery.test.mjs tests/recovery-sql.test.mjs tests/recovery-compatibility.test.mjs tests/recovery-integrity.test.mjs tests/hosted-package.test.mjs` | 25 passed, 0 failed, 0 skipped. Original fingerprints, compatibility AST, tamper/refusal and all 30 existing diagnostic candidates. No SQL executed. |
| `node docs/production-preflight/sql-editor/validate.cjs` | PASS: 16 variants each under PG17/PG18 grammar; original approved hashes unchanged. |
| Cached Deno command below | 105 passed, 0 failed, including real all-21-endpoint CORS/Auth/config/gate checks. |
| Cached Deno check below | 21/21 entrypoints PASS. |
| `node --check scripts/test-browser.mjs`, `git diff --check` | PASS. Normal autocrlf notices do not change approved source contracts. |
| PG runtime/races | NOT RUN. Existing runner creates a new cluster, rather than reusing an already-authorized running environment. No database logic changed or fresh cluster created. Earlier PG17.12/race/refusal results remain historical only. |
| Physical Android | NOT RUN / PENDING. No device or authorized remote device-debug session available; no device evidence supplied. |

```text
deno test --cached-only --node-modules-dir=manual --allow-read=supabase/functions --allow-env=MEMBER_MOBILE_ENCRYPTION_KEY_B64,MEMBER_MOBILE_HMAC_KEY_B64 supabase/functions/_shared
deno check --cached-only --node-modules-dir=manual <all 21 existing endpoint index.ts paths, excluding _shared>
```

Browser evidence, ignored and synthetic only:

- Final dev: `.cache/browser-test-6b3f86a8-746d-4ead-b757-d83fe91a25f8`.
- Final production: `.cache/browser-test-e630e331-21ae-4439-a307-af8fea9290f6`;
  includes `owner-update-mobile.png`, entrance/QR screenshots and
  `pwa-qualification.json` with manifest/installability metadata only.
- Earlier production implementation probe:
  `.cache/browser-test-5326cc22-e39b-4ec4-9f61-a07b073fcb1a` (not additive).

Seven uncertain cases are 503, five malformed payloads and a connection reset.
Each scenario uses a separate synthetic document; this test isolation does NOT
recommend reload as a recovery procedure. Repeated submits are tested even when
the button is disabled. Valid provisional success is tested separately.
Update tests change only the generated worker comment in the run directory.
They do not constitute a different-assets production update/rollback test.

## Android acceptance preparation

Desktop Chrome Android UA/mobile/touch emulation passes manifest parsing with
zero installability errors, secure loopback context, masked PIN/input behavior,
touch tab switching, mobile navigation, interruption feedback, offline shell
navigation and worker lifecycle checks. Existing SVG icon, standalone/root
manifest and static-only worker remain unchanged. No raster-icon defect is
established by this engine; launcher rendering/WebAPK compatibility is unverified.
Loopback secure context is not hosted HTTPS/TLS evidence.

No app camera/scanner exists: the permanent QR is scanned by an external Android
camera and opens the public URL. No camera permission or stream lifecycle was
added. Real scanning, denial/recovery, installed startup and OS behavior remain
physical-device acceptance items.

### Physical procedure - all outcomes PENDING

Prerequisite: Owner identifies an **existing approved, phone-accessible synthetic
target**, its reviewed build and synthetic API configuration. Desktop CDP fixtures
do not automatically serve a phone. Do not substitute production or create a new
environment without separate approval. Stop if a safe target is unavailable.

| Step | Action | Expected result and evidence |
| --- | --- | --- |
| 1 | Record device/model, Android/Chrome versions, approved origin/build; open it in Chrome. | Correct target, no TLS/security warning. HTTPS qualification separate from any approved USB-localhost exception. |
| 2 | Install, open from launcher, close/reopen, rotate, use keyboard and back gestures. | Correct name/icon, standalone shell, visible controls and no horizontal overflow. Record sanitized launcher/viewport evidence. |
| 3 | Scan the synthetic entrance QR externally; deny permission once, recover in the scanner and scan again. | Denial grants no access; success opens exactly the public entrance URL without identity or credentials. No in-app camera stream to leak. |
| 4 | Submit one synthetic public request with interrupted response, then attempt repeated submit/tab switches. | Outcome-unverified guidance; no second same-page request or false payment/attendance success. Do not reload to bypass review; record the server recovery limitation. |
| 5 | In a separate known-clean synthetic scenario, create a valid request and have authorized synthetic Owner processing validate it. | Provisional reference only on public UI; server payment/expiry/attendance rules still required. No real financial/member records. |
| 6 | Test synthetic invalid PIN, invalid reset length, valid reset and replacement private link. | Generic denials, cleared fields, removed fragment and correct replacement. Never capture PIN/token/URL fragments in screenshots or reports. |
| 7 | Go offline, navigate to entrance, close/reopen installed app and reconnect. | Static shell/clear offline notice where available; no queued/confirmed public operation. Separate OS cold-launch result from emulated navigation. |
| 8 | In an approved synthetic two-version update, keep an Owner form open when worker waits. Open safe-update instructions. | Notice appears only after verified Owner access; fields unchanged, no forced reload/activation. Record waiting state and sanitized form result. |
| 9 | Finish/resolve all pending operations; close every app tab/window, then reopen. | New intended version controls the new document, no update loop; verify old static-cache retirement and absence of sensitive responses. Do not close an uncertain operation solely to update. |
| 10 | Sign out of synthetic Owner session offline, reopen, inspect local caches. | Sensitive views disappear; no cached Auth/API/member/payment/PIN/attendance records. Actual hosted authorization remains a separate gate. |

Owner records PASS/FAIL/NOT TESTED per step, timestamp, device/browser, origin,
build and private evidence reference. Stop on wrong target, private data,
certificate warning or uncertain financial state. No physical step is marked
PASS by this report. The detailed Phase 5.7 checklist remains historical context.

## Exact working-tree inventory and proposed commit

Phase 5.8 changed/created **six files**:

| File | Change this phase |
| --- | --- |
| `src/components/EntrancePage.tsx` | Current-page dispatched-attempt guard and truthful uncertain-outcome feedback/disabled controls; preserves earlier parser/formatting fixes. |
| `src/components/OwnerUpdateNotice.tsx` | New verified-Owner update notice and safe natural-activation instructions. |
| `src/App.tsx` | Notice import and mount only; no Auth logic changes. |
| `scripts/test-browser.mjs` | Actual retry-lock, Owner notice, form retention, mobile instructions and natural-activation assertions. |
| `docs/GYMFORCE-DEVELOPMENT-PROGRESS.md` | Append this phase's evidence/status. |
| `docs/SPRINT-PHASE-5-8-FINAL-ACCEPTANCE.md` | This new report. |

Final inventory: **7 tracked edits, 25 untracked files**, none staged:

```text
M docs/GYMFORCE-DEVELOPMENT-PROGRESS.md
M package.json
M scripts/test-browser.mjs
M src/App.tsx
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
U docs/SPRINT-PHASE-5-8-FINAL-ACCEPTANCE.md
U scripts/recovery/validate-hosted-package.mjs
U src/components/OwnerUpdateNotice.tsx
U src/lib/public-entry-contract.ts
U supabase/recovery/diagnostics/m1-plan-routine-components.sql
U supabase/recovery/diagnostics/m2-data-privilege-attribution.sql
U tests/hosted-package.test.mjs
U tests/public-entry-contract.test.mjs
U tests/vite-development.test.mjs
```

All other initial dirty files remain byte-identical. Generated `dist/`, profiles,
screenshots, synthetic worker changes and snapshots remain ignored. Targeted
secret-pattern/source checks do not certify every possible secret encoding; no
credential/private-evidence contents are included. Original diagnostic hashes
are unchanged and no approved evidence was rewritten.

Proposed combined application-candidate contents: the 15 files comprising App,
EntrancePage, PinSetupPage, OwnerUpdateNotice, public-entry-contract, its Node
test, Vite test, browser harness, package.json, vite.config.ts, progress and the
four local sprint reports. Exclude the 17 unrelated recovery/approval drafts and
all generated/private files. Proposed message:
`fix: guard uncertain walk-in requests and surface safe PWA updates`.
This is a review scope, not commit/push authorization.

## Remaining gates and decisions

- **Owner code review:** approve or request changes to the exact 15-file candidate;
  no approval assumed and no staging/commit action authorized here.
- **Android:** device/target availability and actual evidence are required;
  physical acceptance remains PENDING, not replaced by desktop emulation.
- **Public recovery:** approve a server-supported recovery/idempotency design
  and any future forward schema/API changes. Current-page mitigation is not a
  production duplicate guarantee. Do not use generic status codes as proof of
  rollback or automatically resubmit a paid/unknown request.
- **Updates:** manual close-all-windows activation is locally verified. Full
  different-assets update/rollback, multi-window OS lifecycle and cache retirement
  still need approved synthetic/device acceptance. No force-update approval.
- **Production security/recovery:** A02 revised continuing-ADMIN authority remains
  PENDING OWNER DECISION. A03/A04/A07/M1/M2 hosted authority, effective grants,
  trusted references, visibility, legacy data and provenance remain gated.
  Backup/restore/RPO/RTO/key custody, PIN runtime/abuse values, privacy/retention,
  actual hosted business acceptance and separate release approvals remain open.

**Assessment:** safe local implementation and regression verification completed;
GO for focused Owner code review only. Not a final Android acceptance or hosted
release approval. **Production remains NO-GO.**

Next milestone: execute the physical checklist against an Owner-approved existing
synthetic target and review this candidate. In parallel, obtain the explicit A02
design decision; further desktop reruns cannot establish hosted authority.
