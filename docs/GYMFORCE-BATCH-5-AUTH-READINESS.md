# Batch 5 - Auth and local acceptance readiness

Prepared 2026-11-20, Asia/Manila. Original repository, master at 5283e35.
All 16 Batch 4 candidate files preserved. LOCAL ONLY. A02 pending. Production NO-GO.

## Auth dependency readiness

| Component | Result | Evidence / remaining requirement |
| --- | --- | --- |
| Native Auth / GoTrue server | BLOCKED | No auth.exe/gotrue.exe in command discovery, known tool cache, Program Files/local Programs or running native Auth processes. This is a bounded inventory, not proof about every disk location. No service installed/started. |
| Native Go build toolchain | BLOCKED | go command absent; C:/Go/bin/go.exe and Program Files/Go/bin/go.exe absent; no matching inspected WinGet package. |
| Official portable Auth binary for Windows | NOT VERIFIED | Inspected stable v2.198.0 official asset inventory has no Windows-labelled executable. Architecture-only amd64 names do not establish a PE/Windows binary. Nothing downloaded. |
| Native source build | NOT VERIFIED | Official source describes a standalone Go binary, but Windows compilation/dependencies have not been qualified. Candidate v2.198.0 go.mod declares Go 1.27.4. This is an inspected candidate, not an approved acquisition or hosted-version match. |
| Docker / WSL | EXCLUDED / BLOCKED | docker.exe exists but Docker is excluded. Read-only wsl.exe --list --verbose reports no installed distributions (exit 1). No distro was installed or started. |
| PostgreSQL / PostgREST / Deno / Node / Chrome | AVAILABLE | Existing isolated PG17.12, PostgREST16.6, Deno2.9.8, Node24.21.0, Chrome157; exercised locally, not hosted equivalence. |
| Auth SDK | AVAILABLE CLIENT ONLY | Installed @supabase/auth-js 2.118.0 and supabase-js; not a user/session/password server. Supabase CLI package is not an independently available Auth server. |
| Auth schema/migrations | BLOCKED | supabase/tests/synthetic_bootstrap.sql:1 explicitly supplies only an id table and auth.uid SQL shim. There are no real Auth sessions/identities/refresh-token migrations in that fixture. Do not point GoTrue at it. |
| Auth gateway route | NOT IMPLEMENTED | Current persisted HTTP gateway serves /rest/v1 and public recovery plus Vite. It does not route /auth/v1 to a real Auth service. |
| Actual Owner Edge serving | NOT QUALIFIED | Existing local serve adapter imports only public-walkin-recovery. Real Owner handlers exist, but a reviewed loopback adapter must run owner-status and owner-walkins with real Auth and synthetic service transport. |
| Local issuer/audience/signing configuration | NOT VERIFIED | TOML values are CLI intentions, not an active native Auth deployment. Exact issuer, audience, keys, public/service transport compatibility and session settings need runtime verification. |
| Actual Owner Auth -> Edge integration | BLOCKED / scenario 13 PARTIAL | No real login, refresh or Owner Edge authentication evidence. Hand-signed gateway tokens and SDK mocks remain separate evidence. |

Official sources inspected (no binaries downloaded):

- [Supabase Auth README](https://github.com/supabase/auth): standalone build/configuration; startup automatically applies Auth migrations. Startup is therefore a database-changing action, not harmless health discovery.
- [v2.198.0 release](https://github.com/supabase/auth/releases/tag/v2.198.0), [exact asset inventory](https://github.com/supabase/auth/releases/expanded_assets/v2.198.0) and [tagged go.mod](https://github.com/supabase/auth/blob/v2.198.0/go.mod): no qualified Windows asset; portable source-build feasibility remains unverified. No Linux archive is treated as a Windows executable.
- [JWT fields](https://supabase.com/docs/guides/auth/jwt-fields) and [sessions](https://supabase.com/docs/guides/auth/sessions): claims/session/refresh semantics must be tested using actual issued tokens.

## Existing authentication and authorization contracts

- src/lib/supabase.ts:29 lazily creates the browser SDK with a public key. It
  rejects service-role/secret keys and credential-bearing URLs. No changes made.
- src/App.tsx:82 calls owner-status after Auth events, login and focus changes;
  line 167 uses signInWithPassword. Owner views require authenticated,
  isActiveOwner and authorizationReady. Local sign-out clears browser state;
  it is not a promise of immediate server-wide bearer-token revocation.
- supabase/functions/owner-status/index.ts:84 and
  supabase/functions/owner-walkins/index.ts:34 call actual Auth getUser(). Actor
  comes from the verified user, never client input. Walk-in parsing rejects
  additional actor fields (supabase/functions/_shared/walkin-request.ts:25).
- The trusted service calls api.is_active_owner_for_user / Owner business RPCs.
  SQL checks private.owner_access and active Owner status. The user JWT role is
  authenticated, not an invented owner/manager/staff database role. Initial
  release has no staff accounts; negative tests use a synthetic non-Owner user.
- Issuer must be the chosen local Auth /auth/v1 URL; audience/role must match
  the pinned Auth and PostgREST configuration. Verify real token signature,
  iss/aud/sub/exp/iat/role/session_id and actual session association. Do not log
  tokens or decode a token and call that authentication. Handlers delegate
  identity validation to configured Auth getUser, not custom claim checks here.
- Keep public signup/anonymous signin disabled, as in supabase/config.toml:180.
  Existing TOML JWT lifetime 3600, refresh rotation true/reuse interval 10s are
  local intentions requiring explicit mapping to native GoTrue configuration.
  They are not newly approved production policies.

## Prepared real-Auth integration test specification

Execution remains BLOCKED; these are not mocked passes. Required architecture:
Browser -> loopback gateway -> real Auth /auth/v1; Browser -> actual Owner Edge
module -> real Auth getUser -> service-only PostgREST -> PG17 protected objects.

Before these tests, qualify a separately approved pinned native Auth build. Use
an explicit fresh profile of the existing isolated PG17 harness; bootstrap the
reviewed upstream Auth schema before application data, not over the id-only shim.
A dedicated Auth migration/runtime identity must be restricted to required Auth
objects, with no private application privileges, CREATEROLE, executor membership,
superuser or RLS-bypass shortcut. Review extension requirements and any distinct
bootstrap authority. Refuse unsupported upstream requirements instead of granting
broad permanent authority. Preserve existing application ownership/RLS assertions.

Provision synthetic Owner and non-Owner accounts through the real Auth admin API
only after approval. Use actual returned UUIDs for the isolated Owner registry;
do not pretend shim rows are password identities. Disable outbound mail/SMS,
external providers and telemetry exporters. Generate ephemeral local credentials
in memory/protected ignored files; never use production credentials or print
login bodies, tokens, refresh secrets, cookies, private claims or database rows.

| Test | Exact operation and acceptance | Persisted / security assertions |
| --- | --- | --- |
| 1 Valid Owner | SDK password login -> real /token?grant_type=password; call actual owner-status and owner-walkins list | Auth-issued session/user; Owner verified; no management business mutation for reads |
| 2 Invalid credentials | Wrong password and unknown synthetic account -> Auth non-success (version-specific error category recorded privately) | No session, no privileged RPC and unchanged protected ledger/audit snapshots; generic UI |
| 3 JWT expiry/malformed | Use real short-lived access token after expiry; separately malformed/signature-tampered token -> real getUser / Owner Edge rejection | No protected mutation; no invented edited-exp token presented as expiry evidence; direct gateway JWT tests remain distinct |
| 4 Non-Owner / staff denial | Real authenticated synthetic non-Owner invokes actual Owner endpoint with valid list/confirm payload -> 403; extra actor fields -> 400 | No staff feature/role introduced; no financial/attendance/audit change; deactivated Owner also denied via SQL registry |
| 5 Owner reconciliation | Create a provisional synthetic request. POST owner-walkins confirm with action, requestId, operationId, amountPhp as exact decimal string, paymentMethod and evidenceReviewed=true, plus real Owner bearer | Verified Auth actor -> exact server p_actor_user_id; one receipt/attendance; same operation replay retains originals; conflicting payload refused |
| 6 RPC permissions | Actual authenticated user token directly invokes protected API; actual non-Owner Edge route; public transport attempts direct private data access | Unauthorized function/schema/table/column/sequence access denied; no additional grants; service may invoke only reviewed RPCs |
| 7 Integrity | Hash protected receipts/allocations/events/attendance/stream heads before failures, check original audit verifier after successes and faults | Denials/rollbacks leave originals unchanged; successful audited actions extend valid chain; retries do not duplicate money or attendance |
| 8 Expiry/refresh | Obtain real login, call refresh_token grant, verify rotation/session continuity, SDK TOKEN_REFRESHED -> Owner re-verification; wait beyond selected expiry/reuse windows | Actual issued child tokens only; no token fabrication; revoked/invalid refresh behavior recorded; UI clears privileged state on rejection |
| 9 Replay/boundary | Replay valid access bearer with same operation, cross-user actor injection, rejected Origin, signed-out/disabled Owner and reuse of old refresh outside configured grace | Access bearer replay is not inherently one-use: operation idempotency prevents duplicate effects. Do not promise immediate access-JWT revocation on local sign-out; observe pinned Auth behavior and flag any unmet approved requirement |

All tests require complete private evidence and sanitized classifications. Auth
HTTP status details vary by pinned release; record actual categories rather than
changing assertions to accept arbitrary errors. Request validation failure is
not authentication evidence. If the Auth binary, database schema, getUser route,
issuer or live identity cannot be proved, stop and mark BLOCKED. No mock substitute.

## Deterministic and real HTTP qualification

The new supabase/tests/public_walkin_clock_boundaries.sql runs only inside the
fresh guarded PG17 test profile. It creates two transactional test copies from
pg_get_functiondef of the installed admit/bind functions. Changes are limited to
function names and replacement of exactly three / one clock_timestamp calls;
reverse substitution must reproduce the original definition byte-for-byte.
Copies retain gym_public_executor ownership, original runtime checks, table ACLs
and FORCE RLS. Client/service execution is denied. Final ROLLBACK removes clock,
functions, grants, fixtures and GUC changes; original definitions are checked.

This verifies the actual decision bodies with deterministic inputs, not a new
production clock or the live HTTP time source. Real HTTP continues to use
unchanged originals. Added HTTP load uses two independent Deno processes and
one PostgREST/PG17 backend: eight concurrent hot-key lookups, then three waves
of eight rotating-key lookups, never more than eight HTTP requests in flight.
Observe committed charge counts, allowed/denied/unavailable classifications,
window duration and unchanged business-binding count. Do not infer hosted
Supabase isolate, shared-network fairness or arbitrary stress equivalence.

## Fresh execution results

Final PG17 command (exit 0):

powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-recovery-pg17.ps1 -CustomerCompatibility -IngressTest -HttpIntegration

Evidence: .cache/security-test-3c52a2085b5446188aade9f8e2b2344e;
summary .cache/batch5-pg17-qualified.log. Executed harness/helper hashes were
independently matched against current source. No new runtime/tool was installed.

Read-only WSL discovery returned exit 1 with no installed distributions; this is
a missing dependency result, not a passing runtime test. The initial sandboxed
enumeration was access-denied; approved read-only enumeration established the
absence without installing or starting a distribution.

| Exact boundary / load | Actual evidence | Classification |
| --- | --- | --- |
| UTC day | Last admission at 23:59:59.999999; exact midnight resets daily count to 1; backward-day call refuses without changing count | PASS deterministic copies |
| Sliding window | Inclusive age 10/60s bins deny; age 11/61s bins expire | PASS deterministic copies |
| Key refill | Creation 4.999999s denied / 5s allowed; lookup 9.999999s denied / 10s allowed; one-microsecond rollback refused | PASS deterministic copies |
| Lease / forward clock | Eight slots; 14.999999s refuses ninth; exact 15s expiry reclaims; old generation refused; forward jump to 2035 resets day | PASS deterministic copies |
| Clock fixture closure | Original definitions unchanged, test-copy service/browser execution denied, explicit rollback leaves no test functions | PASS PG17 runtime |
| Eight concurrent hot-key HTTP lookups | 2 allowed (unknown-outcome 404), 6 rate-limited, 0 unavailable; 8 committed admission charges | PASS actual two-process HTTP |
| Three eight-request rotating-key waves | 24 charged attempts in 1 server-clock second: 20 allowed 404, 4 rate-limited, 0 unavailable; no new bindings | PASS actual two-process HTTP |
| Final-token / capacity / eight-slot / lease-lock / ABA / pool recovery | Existing live HTTP and native barrier tests rerun, including deterministic PGRST003 and unqualified business-timer refusal | PASS recorded scopes, not hosted isolates |

A 404 lookup is an admitted unknown capability, not a member/payment disclosure
or a new business operation. The 32 lookup attempts created no business effects.
No system clock was changed. Exact-boundary evidence uses copied decision bodies;
real HTTP uses original clock functions and does not claim a physical UTC cutover.

The rerun reproduced a fault-observer coordination weakness in Batch 4: it did
not synchronize its observer session before dispatch or refresh cached activity
snapshots during its polling DO block. The helper now waits for its guarded
readiness marker and calls pg_stat_clear_snapshot before each activity sample.
This discards cached observer information, not counters or audit history; see
[PostgreSQL 17 statistics documentation](https://www.postgresql.org/docs/17/monitoring-stats.html).
The full fault campaign then passed with the original timeouts unchanged.

Earlier new-fixture iterations remain failures: the first exposed a PL/pgSQL
CASE comparison syntax error; the second combined a mutating call and a scalar
subquery in one assertion, without guaranteeing observation after the call.
Those tests now use explicit parentheses and separate call/state-read statements.
A third run reached the observer failure above. Final evidence is the fourth
run only; previous successful Batch 4 evidence remains historical, not reused.

| Fresh command | Final result / exit code |
| --- | --- |
| npm.cmd run lint | PASS / 0 |
| npm.cmd run typecheck | PASS / 0 |
| npm.cmd run test:security | PASS / 0 |
| npm.cmd test | 45 passed, 0 failed/skipped / 0 |
| npm.cmd run test:recovery-request | 10 passed, 0 failed/skipped / 0 |
| npm.cmd run test:ingress-monitor | 10 passed, 0 failed/skipped / 0 |
| node --test tests/recovery.test.mjs tests/recovery-sql.test.mjs tests/hosted-package.test.mjs tests/recovery-compatibility.test.mjs tests/recovery-integrity.test.mjs tests/recovery-tooling.test.mjs | 27 passed, 0 failed/skipped / 0 |
| Installed Deno test --cached-only --node-modules-dir=manual --allow-read=supabase/functions --allow-env=MEMBER_MOBILE_ENCRYPTION_KEY_B64,MEMBER_MOBILE_HMAC_KEY_B64 supabase/functions/_shared | 109 passed, 0 failed / 0 |
| Installed Deno check --cached-only --node-modules-dir=manual (22 actual Edge entrypoints and serve-local-edge.ts) | 23 checks PASS / 0 |
| npm.cmd run test:dev | 1 passed, 0 failed/skipped / 0 |
| npm.cmd run build | PASS; 9 PWA precache entries, 611.30 KiB / 0 |
| node scripts/test-browser.mjs | PASS synthetic development browser suite / 0 |
| node scripts/test-browser.mjs --production | PASS synthetic production/PWA suite and Android emulation / 0 |
| PG17 command above | 37 stages, 11 legacy refusals, 2 ownership rollback probes, 9 original races, 2 recovery races, ingress/ACL/fault cases and 5 new deterministic clock groups PASS / 0 |
| node scripts/recovery/validate-source.mjs | Original 75/75 HEAD blobs, candidates and PG17/18 grammar PASS / 0 |
| node scripts/recovery/validate-hosted-package.mjs | Original 30 diagnostic hashes/order PASS / 0 |
| node docs/production-preflight/sql-editor/validate.cjs | Original 16 SQL-editor variants PASS / 0 |
| git diff --check and changed-file credential-pattern scan | PASS; 18 candidate files, no credential patterns / 0 |

Node counted suites total 93, Deno separately 109. The new SQL fixture has five
named result groups; no invented individual SQL assertion count is added. Real
Auth cases 1-9 in the prepared specification are BLOCKED, not counted as passes
or hidden within the synthetic browser/SDK checks. Physical Android not tested.

## Updated fifteen-scenario acceptance

| # | Scenario | Current classification |
| --- | --- | --- |
| 1 | First valid submission | PASS scoped real local HTTP/commit |
| 2 | Identical retry | PASS same persisted binding |
| 3 | Same-key conflict | PASS original preserved, 409 |
| 4 | Concurrent submission | PASS two independent Deno processes, one binding |
| 5 | Two tabs | PASS real browser and persisted recovery |
| 6 | Reload | PASS durable capability, same request |
| 7 | Pre-commit loss | PASS dispatch and mid-business/COMMIT interruptions, observed rollback/retry |
| 8 | Post-commit loss | PASS dropped acknowledgement, observed binding and pool reconnection |
| 9 | Timeouts | PASS scoped statement/lock/pool refusal and recovery; not a WAL/COMMIT duration guarantee |
| 10 | Transaction rollback | PASS separate charge survives; protected ledger/attendance/audit preserved |
| 11 | Expiry | PASS actual 410, no revival/replacement |
| 12 | Unauthorized lookup | PASS scoped capability/ACL/gateway JWT tests; not real Owner Auth |
| 13 | Owner reconciliation | PARTIAL: financial SQL/HTTP safeguards pass; actual Auth -> Owner Edge chain BLOCKED |
| 14 | All-attempt limits | PARTIAL: bounded two-process load and exact copied-body clock tests pass; broad stress/fairness, live/provider clock/connection/isolate and operational deployment qualification remain unverified |
| 15 | Payment/attendance uniqueness | PASS actual confirmation retry/replay and interruption tests |

## Exact changed-file inventory

Working tree relative to master HEAD 5283e35: six modified tracked files and
twelve untracked project files, index empty. The original 16 are retained; two
new files were added. No application source, Edge handler, historical migration,
approved diagnostic, production setting or private evidence was changed.

Modified tracked files:

- docs/GYMFORCE-DEVELOPMENT-PROGRESS.md
- docs/GYMFORCE-PHASE-6-1B-INGRESS-IMPLEMENTATION.md
- package.json
- scripts/recovery/validate-source.mjs
- scripts/test-database.ps1
- scripts/test-recovery-pg17.ps1

Untracked project files:

- docs/GYMFORCE-BATCH-5-AUTH-READINESS.md (new Batch 5)
- supabase/tests/public_walkin_clock_boundaries.sql (new Batch 5)
- scripts/recovery/durable-ingress-ops.mjs
- scripts/recovery/ingress-monitor.mjs
- scripts/recovery/qualify-http-faults.mjs
- scripts/recovery/serve-local-edge.ts
- scripts/test-persisted-http.mjs
- supabase/recovery/phase61b/003-local-operational-controls.sql
- supabase/recovery/phase61b/operational-manifest.json
- tests/durable-ingress-ops.test.mjs
- tests/ingress-monitor.test.mjs
- tests/persisted-http-guard.test.mjs

Batch 5 updated seven existing candidates: the two progress/implementation
reports, validator, database harness, HTTP harness, qualification helper and
unapproved operational manifest. The other nine existing candidates were not
edited in Batch 5. The manifest adds only the new test fingerprint and updated
helper hash; original source/diagnostic contracts remain unchanged, including
M1 c0477249f71a2ab4065d5b43392dcdd326e919201fee56188331799b0b21390a and
M2 b4acd4b9caf0a6d40135a418e7b05e850f953ebe23cecbcf8b70820a0906b6cd (LF).

Cleanup independently checked all four PG attempts: zero remaining temporary
credential/bootstrap/PostgREST config files, server PID files, HTTP profiles or
matching runtime processes. The two fixture Chrome profiles were removed only
after exact path/reparse/process checks. Screenshots, sanitized aggregate journals,
stopped synthetic clusters, logs and dist output remain ignored; PostgreSQL 18,
user browser data and existing private production evidence were not touched.
Git line-ending warnings are existing checkout policy; diff --check passes.

## Owner authorization request (not granted)

Requested next step: **portable Auth acquisition/build qualification only**,
subject to a reviewed exact source/toolchain/dependency manifest and authenticated
upstream provenance before downloads. Suggested wording:

> I authorize qualification of a portable Windows GoTrue source build from an
> exact Owner-reviewed version/commit, toolchain and dependency checksum manifest,
> under Git-ignored workspace tooling only. No system-wide installation, automatic
> unreviewed dependency/toolchain acquisition, Auth service startup, Auth migration,
> role/grant change, hosted access, commit or deployment is authorized. Stop if
> native Windows support cannot be demonstrated within that scope.

This request is unapproved. Auth startup/schema/identity fixture changes and the
real integration campaign need their own subsequent approval. The service's
automatic migrations make a bare startup command consequential even locally.


## Remaining approvals and operational dependencies

- Auth acquisition is NOT AUTHORIZED by this report. Requested next authorization:
  qualify a pinned portable Windows source-build package (candidate Auth v2.198.0
  and the tagged Go requirement), with exact commit/archive/toolchain/module
  provenance and Owner-reviewed hashes before acquisition. No blind download,
  unverified DLL, automatic toolchain retrieval or system-wide install.
- Separate approval is required for building/executing that package, upstream
  Auth migrations in the existing synthetic harness, narrow Auth roles, synthetic
  account creation, gateway/Owner adapters and the nine real-Auth tests above.
  Stop if native Windows cannot be supported without additional infrastructure.
  No Auth server was installed or started in Batch 5.
- The existing local scheduler/queue/watchdog is test infrastructure. Production
  still needs approved supervised scheduling, protected durable storage, independent
  failure detection, recipient/reviewer, transport credentials/TLS, deduplicating
  sink, retry/backoff/retention/privacy policy and crash/power-loss qualification.
  No production task scheduler or external alert destination is configured.
- Hosted authority/ADMIN grantors and membership options, A03 effective ACLs,
  A04 legacy/audit/backup/restore evidence and A07 drift/history reconciliation
  remain separately authorized hosted gates. Physical Android acceptance and
  provider connection/timer/pool/isolate behavior remain unverified.

A02 remains PENDING OWNER DECISION. Full local acceptance PARTIAL; production NO-GO.
