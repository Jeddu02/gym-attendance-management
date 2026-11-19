# Phase 6.1 - Local server-enforced public-request recovery

2026-11-19, Asia/Manila. Original repository, `master`, unchanged HEAD
`ad41b7988d0d9fc4a56e675aeaff9b613878cdda`.

**Implemented locally; not a production release. Production NO-GO.**
Core recovery is ready for source review. Full recovery acceptance remains
**NO-GO** pending ingress protection, qualified persisted HTTP integration and
the operating/authority decisions below. No commit, push, deployment or hosted
connection/SQL occurred.

## 1. Authorization and preserved boundaries

The Owner authorized isolated local implementation/testing of A1/B1/C1 and L1-L6,
then explicitly confirmed these are the controlling requirements and that no
D1/E1 requirements should be invented. This supersedes the *local implementation*
pending status in the historical Phase 6.0A decision package. It does not accept
the continuing provider-ADMIN A02 trust model or authorize production operations.
**A02 remains PENDING OWNER DECISION.** No policy period, signature, additional
identity rule, production limiter value or hosted permission has been approved.

Controlling sources: [Phase 6.0 contract](GYMFORCE-PHASE-6-0-PUBLIC-REQUEST-RECOVERY-CONTRACT.md),
[Owner package](GYMFORCE-PHASE-6-0A-OWNER-DECISION-PACKAGE.md),
[Phase 5.9 audit](GYMFORCE-PHASE-5-9-COMPLETE-SYSTEM-AUDIT.md) and development
progress. Existing user work was inventoried before editing. Historical SQL,
original runtime fingerprints and approved diagnostics remain preserved.

## 2. Exact implementation inventory

Paths below describe Phase 6.1 work, not every pre-existing working-tree change.

| File | Implementation |
| --- | --- |
| `supabase/recovery/phase61/001-public-walkin-recovery.sql` (new) | One additive forward migration **candidate**, deliberately outside the historical migration directory; private replay table, unique identity/binding, FORCE RLS, invoker helper, two definer RPCs, explicit scoped ACLs and old unkeyed service execution retirement. |
| `supabase/recovery/phase61/source-manifest.json` (new) | Four separate UTF-8/LF-canonical fingerprints for the additive SQL, new handler/shared module and capability store. Does not rewrite original manifests. |
| `supabase/functions/_shared/walkin-recovery.ts` (new) | Canonical 32-byte capability validation, domain-separated hashing, strict input parser and allowlisted output/error classifications. |
| `supabase/functions/public-walkin-recovery/index.ts` (new) | Versioned create/lookup Edge adapter; no logging of bodies, no automatic retries, strict CORS/config/feature controls, local-backend restriction. |
| `supabase/config.toml` | Local handler gateway entry with verify_jwt=false, consistent with existing independently validated public routes; no hosted settings changed. |
| `src/lib/walkin-recovery-store.ts` (new) | Project/version-scoped atomic IndexedDB slot, cryptographic key allocation and minimal stored fields; fail-closed validation, abort and connection cleanup. |
| `src/components/EntrancePage.tsx` | Uses keyed endpoint; recovers saved operation after reload, explicitly retries only the same key, preserves unknown/closed/conflict state and blocks dispatch without storage/internet. Member/PIN behavior preserved. |
| `supabase/tests/public_walkin_recovery.sql` (new) | Real SQL replay, conflict, lookup, expiry, Owner, limiter, privilege and injected binding-failure tests; protected-row hashes and transaction rollback. |
| `scripts/test-db-concurrency.mjs` | Adds an opt-in guarded recovery branch: two-session replay, timeout, connection loss and recovery/Owner-confirmation overlap. Existing nine races preserved. |
| `scripts/test-database.ps1` | Adds opt-in PublicRecoveryTest stage after existing final baseline/compatibility checks; existing cleanup boundary covers it. Preserves the earlier Phase 5.9 eligibility call. |
| `scripts/test-recovery-pg17.ps1` | Passes PublicRecoveryTest through to the existing native harness. |
| `supabase/functions/_shared/walkin-recovery_test.ts` (new) | Four Deno capability/parser/digest/response tests. |
| `supabase/functions/_shared/preflight_test.ts` | Explicit inventory/actual-handler coverage for all original 21 plus the new endpoint; no CORS/Auth/gate assertion removed. |
| `tests/walkin-recovery.test.mjs` (new) | Five Node tests: actual handler adapter, no-network RPC fixtures, malformed bodies/results, digest vector and storage-source exception/tampering. |
| `tests/hosting-diagnostics.test.mjs` | Updates expected OPTIONS count to 22 and requires the recovery route explicitly; continues forbidding POST and authorization headers. |
| `scripts/test-browser.mjs` | Replaces the known fresh-key tab/reload reproduction with recovery assertions; adds simultaneous two-tab allocation, persistence and storage-unavailable refusal. Preserves PIN, Owner navigation and PWA coverage. |
| `scripts/check-source-security.mjs` | B1 persistence exception applies only to the exact capability-store path and its reviewed hash. Other persistence, secrets, cache and auth checks remain active. |
| `scripts/recovery/validate-source.mjs` | Preserves all 75 original pinned inputs; additionally checks the exact four-file additive manifest, the additional endpoint and PG17/18 additive grammar. |
| `package.json` | Adds test:recovery-request. Existing scripts/dependencies and prior sprint edits retained. No dependency added. |
| `docs/GYMFORCE-PHASE-6-1-RECOVERY-IMPLEMENTATION.md` (new) | This implementation/evidence/limitations record. |
| `docs/GYMFORCE-DEVELOPMENT-PROGRESS.md` | Appended Phase 6.1 status/authorization; historical entries retained. |

There is **one additive SQL candidate and zero new files registered in
supabase/migrations/**. All 37 historical files remain unchanged. The native
test runner explicitly opts into this review artifact; ordinary historical
replay and CLI migration history are not silently changed. A production version,
reviewed hashes, actual authority and release/history procedure require separate
approval. Do not run this candidate as a general production runbook.

## 3. Server contract, atomicity and privileges

The public payload is exactly the approved create or lookup action, capability
and (create only) paymentMethod. The capability namespace is version 1; the
successor creation RPC uses the designed v2 name. No client version, fee, actor,
date, identity or hash field was added to the API.

The Edge decodes/re-encodes the 43-character base64url capability, hashes its
32 bytes with the reviewed zero-terminated domain, and forwards only bytea digest.
SQL derives the LF-delimited payload fingerprint from the typed method. Primary
key `(contract_version, capability_digest)` and UNIQUE request_id bind one key
to one server-generated request. Advisory transaction serialization plus fresh
VOLATILE PL/pgSQL statements govern lookup/replay. The original fee/rate creation
function inserts the request within the same transaction as the binding; failure
at binding insertion rolls back the request and limiter event as well.

Matching retry returns the original eligible snapshot. Conflicting method returns
409, unknown lookup 404, expired/terminal operation 410, malformed input 400,
creation limit 429 and unavailable/uncertain RPC result 503. First creation is
201; recovery is 200. Negative classifications carry no business snapshot.
Responses are no-store and disclose no payment, attendance, actor or member data.
Public success is provisional, never actual payment/attendance confirmation.

The private table is owned by gym_data_owner with ENABLE/FORCE RLS. Public
executor gets explicit SELECT/INSERT columns and policies, not UPDATE/DELETE.
It receives only the additional walk-in snapshot SELECT columns necessary for
recovery; confirmed_by/confirmed_at are not added. The private helper is invoker;
API wrappers are definer under gym_public_executor with empty search_path.
PUBLIC, browser roles, Owner/check-in executors and direct service table access
remain denied as tested. No role creation, membership, schema CREATE or new
extension is introduced by the candidate.

The candidate revokes service_role EXECUTE on the original unkeyed create RPC.
Its function owner still calls it internally through the new helper, retaining
its original business guards. The old Edge source is unchanged; with the additive
schema it safely fails instead of creating an unkeyed request. The local test
actually attempts and rejects that bypass. Hosted retirement/quiescence remains
separately authorized work, not something performed here.

**Authority limitation:** baseline compatibility replay uses the existing
non-superuser customer fixture and synthetic provider edges. The *new additive
DDL* is applied by the harness's bootstrap administrator; runtime RPC tests use
service_role/bounded definer paths. This proves engine/runtime behavior, not
customer authority to perform new OWNER TO or hosted grants. No new compatibility
variant or provider-ADMIN exception was silently substituted. A02 remains open.

## 4. Browser recovery and privacy

IndexedDB has one active slot per origin/backend project/version. Its allocation
uses one readwrite transaction; racing tabs converge on one K. Fields are exactly
capability, version and selected method. No PIN, member/mobile data, request/fee
response, payment, attendance or Owner session is saved there. Notifications,
URL transfer, export, service-worker storage and offline queue were not added.

On reload an existing operation locks ordinary creation and offers explicit
lookup/manual same-key retry. A different stored method is adopted for review;
it is not silently overwritten. The component rechecks mount and connectivity
after asynchronous storage. Missing/corrupt storage, unavailable crypto or an
aborted transaction prevents dispatch. Closed responses disable creation retry;
404 or unknown HTTP outcome never authorizes a new key automatically.

The exact source hash limits the existing conservative persistence guard's B1
exception to this module. It still flags persistence in other files and any
alteration of the reviewed store, including added member storage. LF/CRLF
equivalence is explicit; general content changes do not pass as line endings.

No automatic deletion/purge, slot rotation, shared-browser reset or new-visit
override was invented. Capability loss, eviction, independent profiles/devices
or deliberately different keys remain outside the same-key guarantee. The next
person using a shared browser may encounter the unresolved active operation.
The Owner's detailed cleanup/new-visit procedure is still needed; that portion
is held for review. A bearer capability can be read by same-origin scripts/XSS
or someone using the device; IndexedDB is not claimed to be a secret vault.

## 5. Duplicate protections and retained history

Same-key public retry adds no receipt or attendance. The existing unique Owner
operation ID, one allocation per receipt/request and one attendance per request
remain authoritative. The tests verify Owner confirmation replay adds no second
receipt/allocation/attendance and that public lookup closes after confirmation.

Different anonymous keys still create different requests. There is no supported
per-person walk-in identity or globally unique real-world cash receipt identity.
Do not infer one from amount, method, IP, browser or a membership-only external
reference index. No additional walk-in identity collection, per-day person rule,
fuzzy merge or automatic financial suppression was implemented. Separate actual
money remains Owner review material with preserved corrections/audit history.

Pending/expired/terminal bindings remain retained; no purge path is granted.
The approved 15-minute request lifetime is unchanged. A response TTL does not
delete replay evidence, revive a request or reprice it. Record-specific retention,
version retirement, disposal and restore interactions require Owner decisions
before production; C1 did not authorize indefinite production retention.

## 6. Fifteen-scenario evidence matrix

PASS below is scoped to the named local layer. None means actual hosted or
browser-to-Auth/Edge/PostgREST-to-persisted-SQL integration passed. Browser HTTP
fixtures and Node RPC fixtures cannot certify that missing full chain.

| # | Scenario | Local result / actual evidence |
| --- | --- | --- |
| 1 | First submission | PASS SQL + handler independently: one binding/request, server UUID, exact PHP snapshot and 15-minute interval, no financial/attendance effect. |
| 2 | Identical retry | PASS SQL + handler: same saved snapshot after a fee change; no second creation; 200 classification. |
| 3 | Same key/different payload | PASS SQL + handler: 409; original binding unaffected, no original payload disclosure. |
| 4 | Concurrent requests | PASS native two-session race with both waiters observed before release; one request. |
| 5 | Two tabs | PASS real Chrome IndexedDB/HTTP fixture: racing initial allocation shares one operation; later second tab recovers it. Persisted SQL is independently tested, not wired to these pages. |
| 6 | Reload | PASS real Chrome/fixture: saved key remains, ordinary submit cannot create anew and explicit lookup recovers. |
| 7 | Loss before commit | PASS native psql transport: terminate uncommitted client; no committed binding; rollback tests show no partial request. Actual browser-to-SQL interruption remains untested. |
| 8 | Loss after commit | PARTIAL: committed SQL result discarded/recovered independently; browser connection-reset fixture retains same operation. No real Edge/PostgREST lost-ack test available. |
| 9 | Timeout | PARTIAL: real held-key statement timeout leaves no binding; browser unavailable/malformed responses remain uncertain. A real HTTP deadline crossing commit remains untested. |
| 10 | Rollback | PASS SQL: injected failure at the new binding after request insertion; no orphan; protected finance/member/audit row hashes unchanged. Subtransaction rollback also verified. |
| 11 | Expired recovery | PASS SQL + handler: newly inserted synthetic expired snapshot returns closed on lookup/retry; terminal confirmed operation closes; no repricing/revival or evidence deletion. Existing clocks/guards were not changed. |
| 12 | Unauthorized lookup | PASS scoped handler/SQL: wrong Origin/config, extra/bare-ID input, invalid capability, malformed body; effective unauthorized RPC grants denied, service table DELETE and old unkeyed call actually refused. |
| 13 | Owner reconciliation | PASS SQL: non-Owner denied, active Owner confirms actual synthetic receipt once, same operation replays; public result stays provisional/closed and reveals no finance details. |
| 14 | Rate limits | BLOCKED for all-attempt ingress. Existing creation limiter PASS including no binding from a rejected create. Lookup/replay/flood/shared-network budgets and production lock bounds remain undecided. |
| 15 | Payment/attendance uniqueness | PASS native recovery/Owner-confirmation race with both blocked sessions observed, confirmation replay and one receipt/allocation/attendance. Existing nine financial/attendance/void races also pass. |

There are 12 scoped PASS cases, two PARTIAL cases and one BLOCKED case. Full integrated acceptance remains
NOT VERIFIED regardless of those scoped results. Migration-history SQL is not
part of the business RPC. The synthetic hash probe checks protected rows and
history-relation identity; it does not prove real hosted history integrity or
applied migration bytes.

## 7. Commands and actual regression results

Windows, Node 24.21.0; existing portable PostgreSQL 17.12/170012; installed cached
Deno and desktop Chrome. No Docker, dependency installation, paid service or
external environment provisioned. Only synthetic/loopback application requests.

| Command / check | Result |
| --- | --- |
| `npm.cmd run lint` / `npm.cmd run typecheck` | PASS, exit 0 after implementation. |
| `npm.cmd run build` | PASS, exit 0; 112 modules, 9 static precaches, final build 611.30 KiB. PWA closeBundle emitted a 118-second callback timing warning; not a request-performance claim. |
| `npm.cmd test` | PASS 45/45, exit 0, after fixing the new endpoint-count expectation. |
| `npm.cmd run test:recovery-request` | PASS 5/5, exit 0; actual handler source + installed SDK with strict synthetic fetch interception, no external requests. |
| `npm.cmd run test:security` | PASS, exit 0; scoped reviewed persistence exception, general secret/persistence/auth/cache checks preserved. |
| `node --test tests/recovery.test.mjs tests/recovery-sql.test.mjs tests/hosted-package.test.mjs tests/recovery-compatibility.test.mjs tests/recovery-integrity.test.mjs tests/recovery-tooling.test.mjs` | PASS 27/27, exit 0; source, compatibility, grammar, catalog/history, parser and line-ending/tamper regressions. |
| `node scripts/recovery/validate-source.mjs` | PASS PG17/18; all original 75 fingerprints unchanged plus exact separate four-file additions. |
| `node docs/production-preflight/sql-editor/validate.cjs` | PASS both grammars; original 16-file package unchanged, no SQL execution. |
| `node scripts/recovery/validate-hosted-package.mjs` | PASS 30 exact reviewed hashes and conditional ordering; no hosted authorization inferred. |
| Deno shared tests (command below) | PASS 109/109, exit 0, including actual all-22-entrypoint preflight/Auth/config/release coverage. |
| Cached Deno check over all `supabase/functions/*/index.ts` | PASS 22/22, exit 0. Latest handler body-error correction also individually checked afterward. |
| `npm.cmd run test:dev` | PASS 1/1, exit 0; actual Vite CSS/SDK/watch/private-cache denial regression. |
| `node scripts/test-browser.mjs` | PASS, exit 0; final dev evidence `.cache/browser-test-df63128b-ece9-417a-8f41-c58841386793`. |
| `node scripts/test-browser.mjs --production` | PASS, exit 0; final production/PWA evidence `.cache/browser-test-553d4f2a-6360-4ac4-af15-8fccd67b76c8`. Android UA/touch emulation only; physical Android NOT TESTED. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-recovery-pg17.ps1 -CustomerCompatibility -PublicRecoveryTest` | PASS, exit 0, final `.cache/security-test-3190f9fc303842b480ee29d547f6b396`: real server 17.12/170012; existing 37-stage profile, 11 legacy refusals, two ownership rollback probes, ACL/default/inherited checks and nine original races; additive SQL/hash/fault/expiry/retirement tests, two new recovery races, connection loss and timeout. Server stopped. Earlier runs are superseded, not added to counts. |
| `git diff --check` | PASS; existing CRLF-conversion notices do not represent normalization or integrity exemptions. |

The Deno executable resolved through the existing installed package, not the
non-executable WinGet link. Command arguments:
`deno test --cached-only --node-modules-dir=manual --allow-read=supabase/functions --allow-env=MEMBER_MOBILE_ENCRYPTION_KEY_B64,MEMBER_MOBILE_HMAC_KEY_B64 supabase/functions/_shared`.
Edge checks used `deno check --cached-only --node-modules-dir=manual` with all
22 explicit entrypoint paths. No online module resolution was allowed.

Final native log marker counts are four baseline races, five operational races
and two recovery races. Fixed-path metadata checks confirmed zero remaining
bootstrap-password, pgpass.conf, recovery-actor-bootstrap.sql or postmaster.pid
files in the final run; earlier checked failed/superseded runs also cleaned up.
No credential contents or private hosted evidence were read. Native logs and
browser profiles remain ignored synthetic artifacts, not commit candidates.

The 37-file starting dirty inventory grew to 53 dirty files including prior
work: 21 files belong to this phase (the inventory above). Only five previously
dirty files were intentionally extended: package.json, test-browser.mjs,
test-database.ps1, EntrancePage.tsx and development progress. Other pre-existing
dirty files are byte unchanged. All 37 historical migration raw hashes match the
starting snapshot; the progress file's complete historical prefix/BOM remains.
The original 75 source fingerprints and 30 reviewed diagnostic hashes pass.
No files were staged. No environment file, archive, server data or generated
dist/cache/node_modules artifact was added to Git.

### Failures encountered and corrected/qualified

- Sandbox pg_ctl failed restricted-token creation (87 / 3); sandbox Chrome CDP
  initialization timed out and WinGet Deno execution was denied. Authorized local
  tests were run outside that process context; no security settings were disabled.
- One isolated repeat failed during customer bootstrap before application SQL;
  later identical-profile runs succeeded. Its server stopped and credentials
  were removed. Root cause of that isolated bootstrap failure is not established.
- First Deno/hosting tests failed their obsolete 21-endpoint inventory. Coverage
  was extended explicitly to 22, retaining every original assertion.
- Browser fixtures initially retained malformed response settings during recovery
  and checked a walk-in message before revealing its panel. Corrected fixtures;
  actual app validation remained fail-closed. An earlier production browser run
  had a CDP Runtime.evaluate timeout; the final unchanged-timeout run passed.
- A new long concurrency application_name label prevented its overlap probe from
  identifying sessions. Shortened the label; final rerun status is recorded below.
- Code review corrected blocked IndexedDB late-success connection cleanup,
  project scoping, corrupt-store validation, crypto-allocation abort handling,
  mount/connectivity rechecks and malformed-body HTTP 400 classification. Reviewed
  additive fingerprints were updated for these authorized implementation edits;
  original approved hashes were never recalculated.

## 8. Remaining blockers, Owner decisions and local assessment

| Gate | Status / required next action |
| --- | --- |
| All-attempt ingress and runtime budgets | BLOCKED. Decide supported global ingress mechanism and tested limits/lock bounds. Do not substitute the transactional creation counter or an isolate-memory map. The new Edge deliberately rejects non-loopback backend targets until a separately reviewed solution exists. |
| Full persisted Auth/Edge/PostgREST/browser integration | NOT VERIFIED. Existing source/PG/handler/browser layers pass independently; no qualified real stack was started. Qualify existing authorized infrastructure or obtain explicit resource approval. |
| Shared-browser cleanup / next visit | REQUIRES OWNER DECISION. No automatic reset, hidden purge or new-person inference. Define resolution/cleanup without losing uncertain evidence. |
| Production retention/disposal and restore semantics | REQUIRES OWNER DECISION. C1 prototype retains bindings; no calendar period or production purge implementation invented. |
| New migration authority / A02 | PENDING OWNER DECISION / NOT HOSTED-VERIFIED. Bootstrap DDL success does not prove the real customer actor can apply it. Preserve provider-edge/ownership/cleanup review. |
| A03/A04/A07 and M1/M2 | Hosted effective grants/defaults, legacy finance/audit/lifecycle/drawer data and exact history/object reconciliation remain unverified. No diagnostics were run remotely. |
| Release artifacts / rollback | Review the additive migration candidate, new hashes, old-route retirement, traffic quiescence and safe failure/restore plan. No drop/rerun/history repair or re-enabling unkeyed creation as a backout shortcut. |
| Physical Android and operating gates | PENDING, including real-device acceptance, PIN/abuse values, privacy, backup/restore/RPO/RTO and release approvals. |

**Local core implementation: GO for Owner code review. Complete Phase 6.1
integrated recovery acceptance: NO-GO. Production: NO-GO.** Continue independent
local verification where infrastructure exists; do not enable a hosted recovery
route by removing the loopback restriction or choose production policy values
without explicit review. The single highest-priority decision is the supported
all-attempt ingress/runtime contract; it determines the remaining server-facing
security implementation. A02 must remain a separate pending decision.
