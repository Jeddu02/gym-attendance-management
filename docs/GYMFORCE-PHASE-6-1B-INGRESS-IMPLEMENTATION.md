# Phase 6.1B - Local admission implementation and evidence

2026-11-19, Asia/Manila. Existing repository, `master`, starting commit
`5cb851f3a30f321e3044207513c645dd2c6f3cf7`; starting tree clean.

**Local implementation completed for scoped review; integrated qualification
remains NO-GO. Production NO-GO.** No hosted connection, installation,
infrastructure provisioning, deployment, staging, commit or push occurred.

## Authorization and preserved decisions

The Owner explicitly accepted I1 and T1-T9 solely as initial synthetic local-test
parameters, accepted P1 locally, and separately authorized L61B and V61B using
the existing isolated PG17 environment and available application components.
Operator: project developer using Codex; maximum eight concurrent admitted
operations; synthetic data and controlled faults only. This supersedes the
Phase 6.1A package's local authorization HOLD, not its hosted release gates.
Missing infrastructure must remain BLOCKED. **A02 remains PENDING OWNER DECISION**;
the continuing-ADMIN model has not been approved. C1 replay retention is unchanged.

## Exact changed-file inventory

| File | Change |
| --- | --- |
| `supabase/recovery/phase61b/002-public-ingress.sql` (new) | Additive local review candidate: six bounded private tables, three private helpers and five service-only RPCs; admission, binding, execution, safe finish and identifier-free observation. Scoped column grants, FORCE RLS, closure/refusal checks, new-binding capacity trigger and ungated transport EXECUTE retirement. |
| `supabase/recovery/phase61b/source-manifest.json` (new) | Separate UTF-8 LF fingerprints of the candidate, new body module and authorized handler successor. Original manifests not rewritten. |
| `supabase/functions/_shared/walkin-ingress.ts` (new) | Recovery-only JSON/encoding/actual-byte reader with bounded cancellation; original shared PIN reader unchanged. |
| `supabase/functions/public-walkin-recovery/index.ts` | Admission before parsing, separately committed key charge, admitted business RPC, per-stage aborts/deadline, generic errors/429 Retry-After, safe cleanup and non-identifying telemetry. Loopback restriction retained. |
| `supabase/tests/public_walkin_ingress.sql` (new) | Actual PG SQL tests: independent commit/rollback, limits, expiry/stale lease, effective/negative permissions, runtime refusal, replay/conflict/unknown lookup, capacity failure and telemetry cleanup. |
| `scripts/test-db-concurrency.mjs` | New guarded native ingress branch: eight barrier-released clients, ninth-lease refusal and expired-locked-slot reclamation protection. Existing nine baseline and two recovery races preserved. |
| `scripts/test-database.ps1` | Opt-in IngressTest after existing baseline/recovery checks; existing target and credential/server cleanup guards retained. |
| `scripts/test-recovery-pg17.ps1` | Forwards IngressTest, explicitly enabling prerequisite PublicRecoveryTest; no hosted connection parameter. |
| `scripts/recovery/validate-source.mjs` | Original 75 source checks unchanged; retains Phase 6.1 historical handler fingerprint against pinned checkpoint blob and separately checks the active successor/new SQL/module. Both PG17/18 grammars cover the new candidate. |
| `tests/walkin-recovery.test.mjs` | Actual handler/SDK fixtures updated for admitted dispatch; added pre-parse denial and malformed-attempt coverage. Fixtures are not persisted HTTP proof. |
| `tests/walkin-ingress.test.mjs` (new) | Actual streamed reader boundaries, malformed UTF-8/encoding/length and slow-reader cancellation. |
| `package.json` | Includes new reader regression in test:recovery-request; no dependency change. |
| `docs/GYMFORCE-PHASE-6-1B-INGRESS-IMPLEMENTATION.md` (new) | This evidence and limitations record. |
| `docs/GYMFORCE-DEVELOPMENT-PROGRESS.md` | Append authorization, results and remaining gates; historical entries retained. |

No files entered `supabase/migrations/`. All 37 historical migrations, 30
diagnostic candidates, M1/M2 drafts, original source manifest, compatibility
artifacts and Phase 6.1 SQL/manifest remain unchanged. Frontend, Owner/PIN
handlers, PWA configuration and business rules were not changed in this phase.

## Implementation behavior and security review

1. Exact-Origin CORS and OPTIONS precede handler service checks. Unsupported
   method/configuration, disabled feature and non-loopback backend reject before
   database processing. The original approved early-rejection coverage exception
   remains: these are not durable database attempt events or network flood defense.
2. `public_walkin_admit()` is a separate RPC transaction. Global 61-slot second
   ring conservatively checks 20/10s and 120/60s plus 2,000/UTC-day attempts.
   Known saturation returns a normal denied object so counters commit; it does
   not raise away the charge. Eight preallocated slots use unpredictable UUID
   tickets; reclaim skips locked rows. No row per malformed/random key or IP.
3. Only after admission does Edge read at most 2,048 actual bytes, with a 2s body
   deadline. Reject compressed input, malformed JSON/UTF-8, invalid length,
   noncanonical/missing capability and extra fields before any business RPC.
4. `public_walkin_bind()` commits its charge independently: 4,096 fixed buckets,
   capacity 3/refill 12 per minute, lookup capacity 2/refill 6 per minute. Lookup
   costs both. Bucket collisions conservatively deny unrelated callers. Action,
   digest, method and SQL-derived fingerprint bind to the ticket; no plaintext
   capability reaches SQL. Refills are token buckets, not strict 12/6 rolling caps.
5. `public_walkin_execute()` locks the bound lease through business completion,
   checks expiry/action/digest/method/fingerprint, and calls the unchanged recovery
   helper. Existing operation/rate/fee order is preserved. A separate capacity row
   is locked last by a BEFORE INSERT trigger on the additive recovery table:
   count/counter mismatch or >=10,000 refuses, rolling back request and binding.
   It does not touch the admission global row, avoiding a reverse lock order.
6. Existing business creation limiter is fixed to the accepted local value 10;
   Edge refuses a different/missing configured value. Old unkeyed, ungated v2
   create and ungated lookup service EXECUTE cannot remain reachable. Unexpected
   overloads, unknown default grantees and effective browser execution cause
   installation refusal. No function drop, history marking or historical edit.
7. Successful execution clears the ticket. Before business dispatch, a failure
   can safely finish its own lease; after dispatch an ambiguous result never
   releases it early. Expired locked leases remain unavailable. An independent
   observation RPC has no ticket and cannot release uncertain work. No automatic
   admission/business retry, re-key, refund or payment-sensitive resubmission.
8. All public responses remain allowlisted/no-store. 429 uses generic unavailable
   plus Retry-After: 5; no quota balance or identifying fields. Existing provisional
   success, conflict/closed/unknown meanings and browser payload/storage stay intact.

Private admission structures use gym_data_owner ownership, ENABLE/FORCE RLS and
public-executor SELECT/UPDATE of required columns only; immutable slot/id columns
are not UPDATE-granted. Capacity grants only the counter update. No new roles,
memberships, schema CREATE, extension, direct service table or browser RPC grants.
Private helpers are invokers; API definers have empty search_path and restricted
ownership. Negative tests cover effective ACLs and actual denied calls, not UI hiding.

The business rollback can also roll back ticket completion. This is NOT exactly-once
ticket consumption across rollback. Every new HTTP attempt obtains fresh admission;
the immutable capability/request binding still enforces same-key business effects.
Independent quotas may be spent without a business outcome; no unsafe refund occurs.

### Runtime and monitoring limitations that remain release gates

- Edge uses a shared 10s response budget and 1s admission/bind/finish/observation,
  2s body and 5s business abort signals. An abort does not establish SQL rollback.
  SQL refuses admission/bind/finish/observe unless the caller already has positive
  statement_timeout <=1s and lock_timeout <=100ms; business requires <=5s and
  <=500ms. These checks do not set project-wide roles/configuration or falsely
  claim a function-local statement timeout limits an outer statement.
- Native tests explicitly qualify each session before calls. No real local
  PostgREST component was found/started. Its statement-boundary/pool-reuse settings
  and actual HTTP cancellation remain UNVERIFIED; a default unbounded session
  fails closed. Do not remove the loopback guard to get around this refusal.
- T8's fixed 2,880-minute ring holds attempt/denied/unavailable/timeout counts,
  with no personal/key/ticket/digest fields. Expired records clear on metric writes;
  expired leases clear on safe admission/reclamation. Tests cover that cleanup.
  There is no installed scheduler, notification service or autonomous idle-time
  maintenance. Physical erasure during complete inactivity, alert delivery and
  latency-histogram instrumentation remain NOT VERIFIED/NOT IMPLEMENTED. Counter
  thresholds can be reviewed locally; do not claim automatic alerting is operational.
  No installation/provisioning was performed to fill that missing infrastructure.
- Deadline exhaustion or limiter outage can prevent even the observation RPC;
  telemetry is best effort, not a complete forensic attempt ledger. No raw logging
  fallback was added. Actual provider logs/retention remain unverified.
- Admission queries/Edge invocations themselves can still be flooded. Distributed
  leases cap admitted work, not the provider queue, invocation quota or every
  live isolate. Shared-service starvation, hash-bucket false denials, key theft,
  different-key operations and shared-browser cleanup remain documented limits.

## Actual verification results

Environment: Windows, Node 24.21.0, installed cached Deno, desktop Chrome and
existing portable PostgreSQL **17.12 / 170012**. Synthetic loopback only. No
new dependency, paid service or software installation. Commands below exited 0
in their final runs; failed intermediate runs are recorded separately.

| Command/check | Actual result and scope |
| --- | --- |
| `npm.cmd run lint`, `npm.cmd run typecheck`, `npm.cmd run test:security` | PASS, final rerun after handler changes. Static/runtime boundaries are distinct. |
| `npm.cmd test` | PASS 45/45; A05/A06 and existing application checks retained. |
| `npm.cmd run test:recovery-request` | PASS 8/8; actual handler/SDK under synthetic fetch and actual body reader. Not persisted integration. |
| `npm.cmd run build` | PASS, 112 modules and 9 static precaches / 611.30 KiB; SW/workbox generated. |
| Cached Deno shared test command from Phase 6.1 | PASS 109/109; all-22-entrypoint origin/config/Auth/release coverage. |
| Cached Deno check over all actual entrypoints | PASS 22/22; changed recovery handler checked again after observation integration. No network dependency resolution. |
| Six recovery/integrity Node files from Phase 6.1 report | PASS 27/27; history/catalog/compatibility/encoding/tamper and approved-package checks. |
| `node scripts/recovery/validate-source.mjs` | PASS 75 original inputs plus original Phase 6.1 and separate current-ingress fingerprints; PG17/18 grammar. |
| `node scripts/recovery/validate-hosted-package.mjs` | PASS 30 unchanged candidate hashes/scopes/order; no SQL execution or authorization implied. |
| `node docs/production-preflight/sql-editor/validate.cjs` | PASS original 16-file package under PG17/18; no diagnostic mutation. |
| `npm.cmd run test:dev` | PASS 1/1 actual Vite CSS/SDK/watch/private-artifact denial. |
| `node scripts/test-browser.mjs` | PASS, exit 0; `.cache/browser-test-54e90b9a-0451-4a78-a827-377285fad4ef`. Real browser, synthetic HTTP fixtures only. |
| `node scripts/test-browser.mjs --production` | PASS, exit 0; `.cache/browser-test-5f28e2c7-8605-44fe-b716-dfcfd2818c3c`. Static-only caches, offline no-dispatch, update/PIN/two-tab/reload checks; Android emulation, not physical acceptance. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-recovery-pg17.ps1 -CustomerCompatibility -IngressTest` | PASS final run, exit 0; existing 37-stage customer profile, 11 real legacy refusals, two ownership rollback probes, ACL/default/inherited checks, nine original races and two Phase 6.1 recovery races. Both additive candidates and new ingress SQL/concurrency tests passed. |
| `git diff --check` and source/secret scope review | PASS; only authorized local source/tests/tooling and these documents. Final review also checks new untracked file whitespace. No staging/commit. |
| Persisted Edge/PostgREST/browser-to-SQL HTTP chain | **BLOCKED / NOT RUN**: PostgREST and Supabase Edge CLI not available in command paths or known local cache directories; Deno alone is not that chain. No replacement mocks counted as integration evidence. |

Native final evidence: `.cache/security-test-6d25c0f5eba34e928fcac5e2aaa0e8f4`.
The server stopped. Independent permitted metadata checks of all four attempted
run roots found zero bootstrap-password, pgpass.conf, recovery-actor-bootstrap.sql
or postmaster.pid artifacts. Sandbox access to a run log was initially denied;
it was not treated as evidence of absence. A permitted read retrieved only PASS
markers and exact cleanup-path metadata, never credential contents.

New native evidence comprises four SQL assertion groups and one concurrency
group (overlapping assertions, not five independent end-to-end scenarios):

- Separate committed admission/key charges survive a business subtransaction
  rollback; one later atomic creation, consumed-ticket denial and unchanged
  payment/allocation/event/member/membership/attendance/audit hashes.
- Burst 20/21, slots 8/9, key tokens 3/4, lookup tokens 2/3; seeded daily/minute
  saturation; expired/stale-generation refusal. These are scoped boundary tests,
  not a 2,000-request/day or full refill/clock-shift/load qualification campaign.
- FORCE RLS, no direct service data, actual anonymous/ungated RPC denial,
  effective browser EXECUTE absence and refusal of unqualified runtime settings.
- Admitted replay/conflict/unknown lookup; capacity refusal rolls back request;
  fixed 48h aggregate cleanup. The capacity fixture is not a 10,000-row benchmark.
- Eight clients released from a native SQL barrier respect slot cardinality;
  ninth lease refused, expired locked lease skipped without erasure. Native SQL
  transport is not multi-isolate Edge/PostgREST acceptance.

New candidate DDL is installed by the harness's bootstrap administrator; runtime
RPCs execute through service_role/restricted definers. Existing customer-authority
baseline tests do NOT establish customer/hosted authority for new ownership/grants.
No A02 compatibility or production GO is inferred.

### Failures found and corrected

1. First native ingress boundary run timed out because telemetry cleanup updated
   every empty preallocated minute slot. Corrected its predicate to touch only
   actually populated expired slots. Timeout limits were not extended or disabled.
2. Second run exposed ambiguous CASE syntax in a new test assertion. Parenthesized
   the scalar expression; application logic was not changed to force a test PASS.
3. Third run's new RLS inventory included indexes and falsely demanded table RLS
   flags on them. Restricted it to ordinary/partitioned tables, retaining actual
   role/function/data denial checks. Fourth complete profile passed.

All failed-run servers stopped. Their ignored references are
`e3070bf1c0d34d7eb925e793f347c37b`, `7483cfdd132a477da6ce7f91fc7072f4`,
and `718f5461f1694c15bd1328a306c55815` under `.cache/security-test-*`.
No original migration assertion, hook, permission refusal or security check was
bypassed. Final results supersede failed runs rather than adding their counts.

## Fifteen-scenario qualification and remaining work

| Original cases | Status after this phase |
| --- | --- |
| 1-3 first/create/replay/conflict | Scoped native SQL + actual-handler fixture PASS; persisted HTTP not verified. |
| 4 concurrency | Native original/recovery races and new admission barrier/locked-slot tests PASS; real multi-isolate admitted business HTTP remains unverified. |
| 5-6 two tabs/reload | Browser fixture PASS retained; not a browser-to-persisted-SQL chain. |
| 7 loss before commit, 10 rollback | Existing SQL transport and new independent-admission/business-rollback evidence PASS as scoped; real HTTP fault chain not verified. |
| 8 loss after commit | **PARTIAL** retained: persisted Edge/PostgREST dropped-ack fault unavailable. |
| 9 timeout | **PARTIAL** retained: session refusal and native cancellation tests pass; actual HTTP deadline crossing commit/pool reuse unverified. |
| 11 expired recovery | Existing helper expiry/closed tests freshly pass; admitted wrapper expiry/HTTP full chain not independently qualified. No revival/purge change. |
| 12 unauthorized lookup | Scoped actual-handler malformed/origin/config tests and SQL ACL/old-route denial PASS; hosted identity/policy behavior unverified. |
| 13 Owner, 15 finance/attendance | Existing native Owner/confirmation/void/cardinality suites and protected-row assertions PASS; no new Owner/payment behavior introduced. |
| 14 all-attempt ingress | **PARTIALLY VERIFIED LOCALLY / BLOCKED FOR INTEGRATED ACCEPTANCE**. Native budgets/leases and actual Edge ordering tested separately; real multi-isolate persisted HTTP, complete T1-T9 stress/clock/refill/idle-maintenance/alert acceptance not established. |

Do not relabel the historical 12/2/1 matrix as 15 integrated PASS. Scoped database
and handler evidence advances #14 without closing missing infrastructure or
operational guarantees. Future safe work needs a qualified already available
local HTTP stack or separate permission for missing components; this task does
not authorize installing them. Review the new candidate and exact manifests,
complete timeout/pool, clock/refill/collision/load, idle cleanup/alerts and
persisted-loss acceptance before broader qualification. Keep public recovery
loopback-only throughout local work.

Local source is **ready for Owner code review**, not a fully qualified release.
Missing integration/maintenance evidence, physical Android, A02 authority/decision,
A03/A04/A07 hosted reconciliation, backup/restore/RPO/RTO, privacy and separate
release approvals remain gates. **Production remains NO-GO.**

## Phase 6.1B.1 � local acceptance hardening (2026-11-19)

Owner scope: local corrections and existing synthetic test components only. This
section supplements the earlier Phase 6.1B evidence; it does not replace failed
runs with historical PASS results. HEAD remains
`5cb851f3a30f321e3044207513c645dd2c6f3cf7`. A02 remains pending; production NO-GO.

### Corrections and focused evidence

- Header/content-encoding/declared-length rejection now attempts cancellation
  before returning the same INVALID_REQUEST classification. Cancellation is
  best effort, guarded against locked/consumed/unavailable bodies, and never
  awaited on early rejection. A rejected or never-settling cancellation promise
  cannot dispatch business work or delay the rejection. Existing streamed-byte
  and body deadline enforcement remains. Real-handler fixtures also verify
  HTTP 400, admit/finish only, and no bind/business dispatch when cleanup fails.
  This proves application cancellation attempts, not provider connection cleanup.
- The ownership/grant enumeration explicitly uses `pg_catalog.pg_proc`,
  `pg_catalog.pg_namespace` and `pg_catalog.regprocedure`. The guarded harness
  installs the candidate with empty temporary catalog lookalikes in the same
  session. Real-catalog assertions verify all eight routine owners/definer
  modes, all five RPC ACLs (including observe), and existing FORCE RLS checks.
  No production or historical SQL was modified.
- Counter drift is seeded below the capacity threshold and tested separately.
  A consistent 9,999-row binding fixture preserves all triggers/constraints,
  accepts the final slot, recovers its replay at 10,000, refuses the next insert
  without an orphan request, and rolls back the complete fixture. A separate
  native two-session race competes for the last consistent slot.
- Real limiter calls test creation refill at 4/6 elapsed seconds and lookup
  refill at 9/11 seconds; these bracket the 5/10-second refill points without a
  production clock hook. Prior-day exhausted state resets on a UTC day change.
  Future timestamps deny conservatively. Live 59/61-second bins bracket the
  conservative 60-second inclusive window; an exact predicate check supplements
  this, but is not a real wall-clock cutoff test. Two barrier-released psql
  clients compete for the final bucket token. Existing locked-expired-lease
  coverage is extended with stale-finish/renewed-generation (ABA) assertions.
  These are native database clients, not concurrent Edge isolates.

### Operational implementation proposal � NOT OPERATIONAL

No scheduler, alert destination, worker credential or infrastructure has been
installed or provisioned. The current minute ring has exactly 2,880 rows and
contains counters only; metric writes clear expired bins. This bounds storage
but does not physically erase idle bins on a deadline. C1 replay bindings and
financial/audit records must never be purged by this operational cleanup.

Proposed next implementation, requiring separate operational/security review:

1. Use an Owner-controlled, already-supported scheduler, if one is available,
   to invoke a narrow maintenance RPC once per minute in a dedicated bounded
   transaction. The RPC would clear only expired aggregate bins and reclaim
   only unlocked expired leases using generation checks and SKIP LOCKED. It
   must not finalize outcomes, alter business tables or release active leases.
   Do not give the worker direct table access, broad RPC execution, role
   membership or schema CREATE. Define and review its specific identity/ACLs
   before implementation; no hosted scheduler availability is assumed.
2. Read aggregate minute counters privately once per minute. Use the proposed
   local-test thresholds from the decision package: at least 20 denials/minute,
   any unavailable event, or at least five timeouts/minute. Deliver only an
   aggregate alert category, count and time to an Owner-approved authenticated
   destination. No capabilities, digests, request IDs, member/network identifiers,
   payloads, database definitions or credentials in logs or notifications.
3. Make deliveries idempotent per minute/category, deduplicate repeat alerts,
   and bound the delivery queue independently of replay evidence. Propose a
   48-hour aggregate-only queue, with no overwrite of undelivered incident
   evidence without an Owner-approved incident/retention policy. Alert-channel
   retention and access restrictions require explicit confirmation.
4. Add an independent heartbeat/dead-man monitor. Failed cleanup/monitor ticks
   must roll back, generate an operational failure alert, and never bypass
   admission or retry business mutations. Failure of alert delivery must be
   visible through that independent channel. If unavailable, operational
   acceptance remains BLOCKED; successful local counters are insufficient.
5. A one-minute schedule implies physical expiry up to one tick late, plus any
   outage. Owner must approve an explicit cleanup-lag SLA or select a stricter
   mechanism; do not represent it as guaranteed physical erasure at 48 hours.
   Test idle expiry, scheduler interruption, overlapping ticks, locked leases,
   bounded queues, duplicate/failed delivery and recovery before acceptance.

Dependencies: confirmed scheduler execution/support model, least-privilege
maintenance API design, privately managed identity, authenticated alert channel,
independent health monitoring, and approved retention/cleanup-lag policy. These
are proposals only; existing all-attempt ingress remains loopback restricted.

### Fresh Phase 6.1B.1 verification

All final commands below exited 0. No saved Phase 6.1B result is counted as a
fresh run. Windows/Node 24.21.0, installed Deno, local Chrome and existing native
PostgreSQL 17.12 were used. No dependency installation or hosted connection.

| Command/check | Fresh result |
| --- | --- |
| `npm.cmd run lint`, `npm.cmd run typecheck`, `npm.cmd run test:security` | PASS; lint repeated after final harness edits. |
| `npm.cmd test` | 45 passed, 0 failed/skipped. |
| `npm.cmd run test:recovery-request` | 10 passed, 0 failed/skipped; includes actual handler with synthetic fetch and real stream cancellation probes. |
| `npm.cmd run build` | PASS, production/PWA; 9 static precaches, 611.30 KiB. PWA closeBundle was slow (162.6s), successful exit. |
| Cached Deno shared tests | 109 passed, 0 failed. |
| Cached Deno check of all entrypoints | 22 checked, exit 0. |
| Six recovery Node files listed in the earlier command table | 27 passed, 0 failed/skipped. |
| `node scripts/recovery/validate-source.mjs` | PASS: 75 original hashes plus current additive manifests, PG17/18 grammar. |
| `node scripts/recovery/validate-hosted-package.mjs` | PASS: 30 original diagnostic hashes/order/scopes unchanged. |
| `node docs/production-preflight/sql-editor/validate.cjs` | PASS: original 16-file package, PG17/18 static validation. |
| `npm.cmd run test:dev` | 1 passed, 0 failed/skipped. |
| `node scripts/test-browser.mjs` | PASS, development browser fixture suite, exit 0. |
| `node scripts/test-browser.mjs --production` | PASS, production/PWA/Android-emulation fixture suite, exit 0. No physical-device acceptance. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-recovery-pg17.ps1 -CustomerCompatibility -IngressTest` | PASS, final exit 0: 37 historical stages, 11 legacy refusals, two ownership rollback probes, existing ACL/default/inheritance/security assertions, nine original and two recovery races, six ingress SQL PASS groups, admission barrier, final-token clients, final-capacity race, locked expiration and same-slot ABA assertions. |
| `git diff --check`, candidate scope/secret review | PASS. No historical migration/approved-diagnostic/Phase 6.1 SQL changes. |

Reproducible Deno commands use the already installed executable at
`%LOCALAPPDATA%\Microsoft\WinGet\Packages\DenoLand.Deno_Microsoft.Winget.Source_8wekyb3d8bbwe\deno.exe`:
`test --cached-only --node-modules-dir=manual --allow-read=supabase/functions --allow-env=MEMBER_MOBILE_ENCRYPTION_KEY_B64,MEMBER_MOBILE_HMAC_KEY_B64 supabase/functions/_shared`,
then `check --cached-only --node-modules-dir=manual` with each of the 22 actual
entrypoint paths. Windows PowerShell must preserve the native exit code;
ordinary Deno stderr progress is not a failing test. No network resolution.

Fresh final evidence (ignored):

- PG17 `.cache/security-test-f77394a9b4214f0297f06b976ed8fd82`, summary `.cache/phase61b1-pg17-acceptance.log`.
- Development browser `.cache/browser-test-3ae3eda3-e973-437e-8103-5b8483d78989`.
- Production browser `.cache/browser-test-4e71f741-4848-4768-81ee-3c772297c79d`.
- Other command outputs `.cache/phase61b1-*.log`; these are synthetic local artifacts, not files to commit.

Intermediate failures are retained: restricted-token PostgreSQL startup and
sandbox browser/Deno launch restrictions required an authorized local process
context; no security settings were disabled. The first capacity fixture left
its 60s setup timeout active during a bounded RPC, which correctly refused it.
The fixture now restores 1s before RPC calls. The next native ingress concurrency
run failed under its coarse `ingress` stage; that output did not isolate the
specific assertion. Final-token synchronization was changed to two ready
transactions released together within the existing 100ms lock budget, with
specific stage labels. Subsequent runs passed. An initial Deno invocation also
stopped on normal stderr progress due to PowerShell error handling; the final
invocation used native exit status and passed. None of these failures is silently
counted as PASS. All five PG17 attempt directories were checked independently:
no bootstrap password, passfile, actor-bootstrap SQL or server PID remained.

The last fixture explicitly lets the lease expire while another transaction
holds its row lock, then proves reclamation skips it. After rollback it occupies
other slots, requires reuse of that exact slot with a new UUID, and verifies a
stale finish cannot erase the renewed generation. No system clock is changed.

Updated LF-canonical review hashes (only this unapproved additive package):

- `walkin-ingress.ts`: `c83a850b079122d8d03d43c57912d7b0391941d3754cb3def82679616f57f2c6`.
- `002-public-ingress.sql`: `6b46a533005eb43e5a1dc2777ab51063d6e1b32c7ae7a4447795830eeb0ce7cb`.
- Handler unchanged from Phase 6.1B: `63bbca8a9a9b68a4f719e62f57bc0dcdd88163557cfaf499c004418ae1c363be`.

### Updated acceptance matrix and decision

PASS means the specified local scope only; no row implies hosted acceptance.

| # | Scenario | Phase 6.1B.1 result / limitation |
| --- | --- | --- |
| 1 | First submission | PASS native SQL and separate actual-handler fixture. |
| 2 | Identical replay | PASS native and fixture, including replay at consistent capacity. |
| 3 | Payload conflict | PASS native and fixture. |
| 4 | Concurrent requests | PARTIAL: native admission/token/capacity/recovery races pass; multi-isolate HTTP unverified. |
| 5 | Two tabs | PARTIAL: browser fixture passes; persisted HTTP chain absent. |
| 6 | Reload | PARTIAL: browser fixture passes; persisted HTTP chain absent. |
| 7 | Loss before commit | PARTIAL: native interrupted transaction/rollback passes; HTTP fault chain absent. |
| 8 | Loss after commit | PARTIAL: scoped persisted lookup passes; real HTTP dropped acknowledgement unverified. |
| 9 | Timeout | PARTIAL: native refusal/cancellation and reader cancellation pass; pool/commit-boundary HTTP behavior unverified. |
| 10 | Rollback | PASS scoped: independent admission charges, business rollback, capacity rollback, protected rows/hashes preserved. |
| 11 | Expiry | PARTIAL: native recovery expiry, lease expiry-under-lock and same-slot ABA pass; full admitted expiry HTTP unverified. |
| 12 | Unauthorized lookup | PARTIAL: native ACL/legacy bypass and actual-handler fixtures pass; integrated identity/policy behavior unverified. |
| 13 | Owner reconciliation | PASS existing native safeguards; no Owner workflow change. |
| 14 | All-attempt ingress | PARTIAL locally / BLOCKED integrated: stronger boundary/rate/capacity checks pass; HTTP infrastructure, idle scheduling and alerts absent. |
| 15 | Payment/attendance uniqueness | PASS scoped native safeguards/races; no financial business rule change. |

Targeted cancellation, catalog qualification and capacity-test defects: corrected
and locally verified. The full Phase 6.1B acceptance gate remains NO-GO. Remaining
limits include exact wall-clock cutover/stress campaigns, automatic idle expiry,
alert delivery, missing qualified persisted HTTP components, provider connection
cleanup, physical Android testing and hosted authority/A02. New admission DDL is
still installed by the synthetic bootstrap administrator; runtime customer/role
success does not certify Supabase installation authority.

### Exact current Git inventory

The same 14-file candidate set remains uncommitted. This phase edited ten files:

- `docs/GYMFORCE-PHASE-6-1B-INGRESS-IMPLEMENTATION.md`
- `docs/GYMFORCE-DEVELOPMENT-PROGRESS.md`
- `scripts/test-database.ps1`
- `scripts/test-db-concurrency.mjs`
- `supabase/functions/_shared/walkin-ingress.ts`
- `supabase/recovery/phase61b/002-public-ingress.sql`
- `supabase/recovery/phase61b/source-manifest.json`
- `supabase/tests/public_walkin_ingress.sql`
- `tests/walkin-ingress.test.mjs`
- `tests/walkin-recovery.test.mjs`

Four pre-existing Phase 6.1B changes were preserved without further edits:
`package.json`, `scripts/recovery/validate-source.mjs`,
`scripts/test-recovery-pg17.ps1`,
`supabase/functions/public-walkin-recovery/index.ts`.
Eight tracked modifications and six untracked files; index empty. Generated
builds/logs/databases/browser profiles remain ignored. No commit, push, hosted
SQL, deployment or historical migration edit. Recommended milestone: Owner
review of this hardening, followed by separately authorized persisted local HTTP
qualification and operational scheduler/alert design approval. Production NO-GO.

## Phase 6.1B.3C � persisted local HTTP and operational controls (2026-11-20)

Starting baseline: `5283e35dcb64a72bbe96c89637f9167508401ffa`, branch `master`,
clean tree. Owner's batch authorization permits synthetic local SQL, processes,
JWTs and source/test changes only. No hosted access, deployment or commit.
A02 is still pending; the continuing provider ADMIN trust model is not approved.

### Implemented architecture and authority

`npm.cmd run test:http` invokes the existing PG17 customer compatibility runner
with `-IngressTest -HttpIntegration`. It creates a guarded fresh synthetic cluster
and applies the existing reviewed stages before the new HTTP test hook. Every
administrative SQL session checks the exact synthetic database, loopback address,
port, actor, run UUID, data directory and server version 170012. The harness
refuses inherited PG/PGRST settings, foreign connection envelopes and malformed
targets. A regression verifies refusal does not delete unrelated artifacts.

The persisted chain is real Chrome -> loopback routing -> actual
`public-walkin-recovery/index.ts` module in Deno -> PostgREST 16.6 -> PG17.12.
The Deno bootstrap changes only Deno.serve listener options to an explicit
127.0.0.1/dynamic-port real server; no handler, fetch, SDK or SQL response is
mocked. Routing forwards actual HTTP bytes. Fault modes close connections before
dispatch or discard actual committed responses. Existing CDP fixture browser
suites remain a separate class of evidence.

Preflight pins the PostgREST executable hash, PG17 libpq/OpenSSL/intl/iconv hashes,
checks for unexpected application DLLs/System32 overrides, and verifies runtime
versions. These DLL hashes preserve prior local qualification; they are not new
publisher signatures. PostgreSQL libraries are added to the PostgREST child's
PATH only. Parent/user/machine settings are unchanged. Actual browser, Node,
Deno and PostgreSQL paths use already available components; no installation.

The new LOGIN transport role has NOINHERIT/NOSUPERUSER/NOBYPASSRLS and no
CREATEDB/CREATEROLE authority. Only SET access to service_role and anon is granted,
with INHERIT false. No reserved executor membership or object ownership is added.
Synthetic JWTs and a random transport password remain in memory/a restricted
short-lived PostgREST config; none is exported to source or command arguments.
Only api is exposed. SQL timers are established on the actual pool connections
(1s statement, 100ms lock), not simulated inside a business function. All REST
transactions commit normally; business failures roll back their own transaction.

A temporary test-only SECURITY INVOKER sleep RPC, service-only and synthetic-target
guarded, exercises the two-slot pool under the same 1s SQL timer. It reads no
application data and is dropped during cleanup. The transport role and its
memberships are removed after all HTTP sessions close. Config and browser
capability profiles are removed; parent runner stops PG and removes its own
credential files. Abrupt process/OS termination is not certified by normal
cleanup evidence; no persistent Windows service/job/schedule was installed.

### New operational source candidate

`supabase/recovery/phase61b/003-local-operational-controls.sql` is an additive
local review candidate, not a historical migration or hosted command. Its only
new API is service-only `api.public_walkin_maintenance()`, SECURITY DEFINER under
gym_public_executor with empty search_path and explicit ACL closure. It uses
existing bounded column grants and FORCE RLS policies; it adds no table grants,
roles, memberships, schema CREATE or maintenance bypass policy.

An explicit tick reclaims unlocked expired leases, skips locked leases, clears
aggregate bins older than 48 hours, and returns at most two minutes of counters.
It never removes C1 recovery bindings or financial/audit/member/attendance rows.

`IngressMonitor` validates strictly shaped aggregate input, detects local-test
thresholds (20 denials, any unavailable event, five timeouts per minute), emits
only minute/category/count/idempotency key, and deduplicates acknowledged alerts.
Its in-memory journal has a 48h/11,520-entry bound across four categories.
Delivery is disabled by default. An explicit callback is used only by local tests;
no external endpoint or secrets are configured. Cleanup/delivery failure is
surfaced with a sanitized health category and no automatic business retry.

Actual HTTP operational tests cover idle aggregate expiry, anonymous denial,
thresholds/deduplication, cleanup lock timeout with rollback and recovery, and
locked-expired-lease handling. Unit tests cover malformed/private input, clock
regression, failed delivery, 48h journal bounds and no unsafe retry. This is an
explicit local scheduler adapter, not an operational hosted scheduler.

### Acceptance scope

The persisted harness executes numbered scenarios 1-15 and records their exact
local assertions. A passing assertion is not a declaration of complete acceptance:

| # | Scenario | Qualification boundary |
| --- | --- | --- |
| 1 | First submission | Real Edge/REST/SQL commit and binding count. |
| 2 | Identical replay | Same HTTP key preserves one binding. |
| 3 | Conflicting payload | HTTP 409 and preserved original. |
| 4 | Concurrent requests | Two concurrent real HTTP calls; one creation and one replay. Not Supabase isolate equivalence. |
| 5 | Two tabs | Two real Chrome tabs recover one persisted binding. |
| 6 | Reload | Real browser reload retains capability and recovers original. |
| 7 | Pre-commit connection loss | Proxy pre-dispatch loss and direct incomplete-body disconnect; native SQL interrupted-transaction coverage supplements this. Mid-business Edge/REST connection loss remains partial. |
| 8 | Dropped acknowledgement | Actual committed Edge response discarded by proxy; same capability recovers original. |
| 9 | Timeout/cancellation | Real lock timeout, two pool calls cancelled by SQL timer, reader disconnect and subsequent pool recovery. Arbitrary commit-boundary HTTP cancellation remains partial. |
| 10 | Business rollback | Capacity refusal leaves no orphan request while earlier admission/key transactions persist. |
| 11 | Expiry | Actual lease denial/reclamation plus HTTP 410 lookup/replay for a valid expired historical synthetic request; no replacement binding created. |
| 12 | Unauthorized lookup | Actual anonymous/legacy RPC denial and generic unknown-capability lookup. |
| 13 | Owner reconciliation | Actual service-only RPC, invalid actor refusal and active Owner confirmation/replay. Owner Auth -> Owner Edge is not included. |
| 14 | Admission limits | Actual HTTP burst, minute, daily, key/lookup and eight-lease limits; native final-token/clock/race tests supplement this. Comprehensive load/cutover qualification remains partial. |
| 15 | Financial uniqueness | Replayed Owner confirmation preserves one receipt and attendance. Existing native financial/audit guards also run. |

Pool pressure is demonstrated, but a pool-acquisition timeout specifically depends
on timer ordering (a queued request may succeed as a timed-out slot frees).
Neither this behavior nor Deno process behavior certifies hosted pool/Edge limits.

Remaining operational requirements: production scheduler and independent heartbeat,
durable cross-restart alert delivery/deduplication and approved destination,
cleanup-lag/outage policy, and real external delivery qualification. In-memory
alert deduplication does not survive restart; no durable outbox is claimed.
Runtime telemetry is best effort, not an independent availability monitor.
Physical Android, hosted Auth/Edge/PostgREST acceptance, recovery/backup evidence
and A02/A03/A04/A07 production gates remain pending. Production remains NO-GO.

### Fresh Phase 6.1B.3C execution evidence and closing decision

Final frozen source passed the complete guarded profile. The recorded harness
SHA-256 was independently compared with the current file and matched. No source
was changed during that final HTTP execution. Commands below actually ran on
Windows with Node 24.21.0, Deno 2.9.8, PostgREST 16.6, Chrome and PG17.12/170012.

| Command / evidence class | Fresh result |
| --- | --- |
| `npm.cmd run lint`, `npm.cmd run typecheck`, `npm.cmd run test:security` | PASS, exit 0; final checks repeated after harness changes. |
| `npm.cmd test` | 45 passed, 0 failed/skipped; existing application/handler regressions. |
| `npm.cmd run test:recovery-request` | 10 passed, 0 failed/skipped; actual reader/handler with synthetic fetch, not persisted integration. |
| `npm.cmd run test:ingress-monitor` | 6 passed, 0 failed/skipped (five monitor cases plus malformed-target safety case). |
| Cached Deno shared tests | 109 passed, 0 failed, exit 0. |
| Cached Deno entrypoint/bootstrap checks | All 22 actual entrypoints and `scripts/recovery/serve-local-edge.ts`, exit 0. |
| `npm.cmd run build` | PASS production/PWA, 9 static precaches / 611.30 KiB. Slow PWA callback warning (273s); exit 0. |
| Six recovery Node files from earlier command table | 27 passed, 0 failed/skipped. |
| `npm.cmd run test:dev` | 1 passed, 0 failed/skipped. |
| `node scripts/test-browser.mjs` | PASS development CDP fixture suite, exit 0; synthetic Auth/API, separate from new integration. |
| `node scripts/test-browser.mjs --production` | PASS production/PWA fixture suite, exit 0; Android emulation, not physical acceptance. |
| `node scripts/recovery/validate-source.mjs` | PASS: original 75 inputs and separate additive/operational fingerprints, PG17/18 grammar. |
| `node scripts/recovery/validate-hosted-package.mjs` | PASS original 30 diagnostic hashes/order/scope. |
| `node docs/production-preflight/sql-editor/validate.cjs` | PASS original 16-file diagnostic package static validation. |
| `npm.cmd run test:http` / equivalent direct PowerShell command | PASS final exit 0; real committed HTTP transactions, 15 numbered scoped scenarios, additional pool/body/operational checks and actual browser recovery. |
| Native suite inside the HTTP command | PASS: 37 historical stages, 11 legacy refusals, two ownership rollback probes, ACL/default/inheritance screens, original nine races, two recovery races, six ingress SQL groups and strengthened ingress races. |
| `git diff --check`, credential/artifact/source scope checks | PASS; no staging or original source/evidence drift. |

The exact final HTTP invocation was:
`powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-recovery-pg17.ps1 -CustomerCompatibility -IngressTest -HttpIntegration`.
Deno used the cached commands documented in Phase 6.1B.1, with the bootstrap
added to the typecheck list. No download or installation was performed.

Final native/HTTP evidence:
`.cache/security-test-20d8fa43670e4dbc8d9ae6fec9bbd7b8/`:
`runtime.json`, `persisted-http.log`, `persisted-http-results.json` (15 distinct
scenario IDs and source hash), native SQL/race logs. Summary:
`.cache/phase61b3c-expiry-acceptance.log`.
Browser fixture screenshots/logs:
`.cache/browser-test-e0ad1a37-6e3b-4f2f-b2f7-c7ef815fbd1d` (development),
`.cache/browser-test-5b5993e9-b054-4a3f-9a94-06d493ef8b92` (production).
Other local command summaries use `.cache/phase61b3c-*.log`.

Intermediate failures remain failures: the first attempt stopped during customer
bootstrap; a later attempt hit the unchanged five-second connection timeout at a
local audit screen. No SQL/security refusal was overridden. Sanitized bootstrap
reporting was added, heavy checks were allowed to finish and later guarded runs
succeeded. The precise cause of the first intermittent environment failure was
not established. Failed runs are retained separately from final evidence.

Cleanup was independently checked across all seven database attempts: no plaintext
bootstrap password, passfile, actor-bootstrap SQL, PostgREST credential config,
server PID or HTTP browser profile remained. Process inspection found zero
matching batch processes. The two fixture-browser profiles were also removed;
screenshots/logs and stopped synthetic database evidence remain ignored.
The HTTP transport role/memberships and temporary sleep RPC were removed before
PG shutdown. No production records, credentials or private evidence were used.

Local acceptance classifications after these results:

- PASS for the defined local HTTP scopes of 1-6, 8, 10-12 and 15.
- PARTIAL for 7 (mid-business network-loss chain), 9 (arbitrary commit-boundary
  cancellation), 13 (Owner Auth/Edge path),
  and 14 (full stress/cutover/operational availability campaign).
- Real public persisted integration is now demonstrated; it is no longer
  BLOCKED by absent PostgREST. Hosted equivalence remains NOT VERIFIED.
- Local operational cleanup/evaluation/deduplication/failure tests PASS. Durable
  external alerting, independent heartbeat and production scheduling remain
  NOT IMPLEMENTED / REQUIRES OWNER APPROVAL.

Exact changed-file inventory for this batch, relative to 5283e35:

Modified:
`docs/GYMFORCE-PHASE-6-1B-INGRESS-IMPLEMENTATION.md`,
`docs/GYMFORCE-DEVELOPMENT-PROGRESS.md`, `package.json`,
`scripts/recovery/validate-source.mjs`, `scripts/test-database.ps1`,
`scripts/test-recovery-pg17.ps1`.

New:
`scripts/recovery/ingress-monitor.mjs`,
`scripts/recovery/serve-local-edge.ts`, `scripts/test-persisted-http.mjs`,
`supabase/recovery/phase61b/003-local-operational-controls.sql`,
`supabase/recovery/phase61b/operational-manifest.json`,
`tests/ingress-monitor.test.mjs`, `tests/persisted-http-guard.test.mjs`.

Six modified and seven new files. Application components, actual Edge handler,
historical migrations, original compatibility artifacts and approved diagnostics
are unchanged. No source credentials/private evidence/generated files staged.
Local integration milestone: qualified for the explicit tested scope and Owner
review, not complete release acceptance. Next batch: close the remaining Owner
Auth/commit-boundary fault cases and separately decide durable operations
and physical Android acceptance. A02 remains pending. Production NO-GO.

Closing hardening: transport role creation and grants are one explicit transaction.
A controlled missing-role grant probe confirms its role creation rolls back with
no residual membership. The final frozen run includes this probe. Prior successful
HTTP iterations remain retained separately, including
`.cache/security-test-10bd22097a5a4b41a0730b1e151e9bab`; their source snapshots are
not substituted for the final matching hash. Abrupt harness/OS termination and
port-collision cleanup remain outside the fault cases qualified here.

Expiry gap closed in the final run: a valid historical synthetic fee/request/
replay binding was inserted without modifying existing snapshots or any financial
or attendance record. Its expiry is exactly creation plus 15 minutes. The actual
HTTP lookup and same-key create both returned 410, and no replacement binding
was created. This is a historical fixture, not a claim that the test waited 15
wall-clock minutes. Scenario 11 is now scoped local HTTP PASS. Prior successful
atomic-authority run remains at `.cache/security-test-4eea3cf5676b404085837708a804d904`.


## Batch 4 - Acceptance gap closure, 2026-11-20 (fresh local evidence)

Checkpoint: master at 5283e35dcb64a72bbe96c89637f9167508401ffa. All 13
pre-existing uncommitted Batch 3C files were preserved. No staging, commit,
push, hosted connection, deployment, historical migration change or application
source change occurred. A02 remains PENDING OWNER DECISION. Production NO-GO.

### Implemented qualification and operational changes

- scripts/recovery/qualify-http-faults.mjs installs guarded synthetic-only
  invoker triggers, retaining every existing integrity trigger and RLS rule.
  A BEFORE trigger pauses inside business processing; a deferred constraint
  trigger pauses at COMMIT. A separate guarded administrator session observes
  the owned transport backend waiting, then terminates that backend. All hooks
  are removed in finally blocks on the successful campaign. No hook is a
  deployment candidate or a historical migration edit.
- Three public-request fault cases exercise mid-business disconnect, pre-commit
  disconnect and statement timeout. Each checks actual binding counts, preserved
  membership/ledger/attendance/audit snapshots, independently committed admission
  charges, absence lookup, explicit retry and identical replay.
- Two financial fault cases interrupt actual Owner confirmation mid-payment and
  at deferred attendance commit. Protected receipt/allocation/event/attendance/
  audit-head snapshots remain identical after rollback. The same operation's
  actual RPC retry and replay leave exactly one payment and one attendance.
- Dropped acknowledgement is injected only after receiving the actual committed
  upstream response. The binding is independently counted, idle transport
  connections are terminated, bounded health probes qualify reconnection, and
  lookup returns the original request. This is an observed post-commit window,
  not precision instrumentation of PostgreSQL's commit-record write or WAL fsync.
- A second, synthetic one-slot PostgREST probe produces PGRST003 deterministically.
  Only its test-only sleep RPC uses a 6s statement timer. Protected business RPCs
  refuse that configuration with SQLSTATE 55000. The application pool retains
  1s statement / 100ms lock timers; no business timeout was increased.
- Two independent Deno processes load the unchanged actual Edge module. Shared
  HTTP creation/replay races use one database. New real HTTP tests exercise
  2047/2048-byte accepted bodies, 2049-byte refusal, malformed JSON/schema/header
  charges, disallowed Origin and method denial, prior-day reset, backward-clock
  refusal, 59/61s windows and simultaneous final-token binds. Seeded timestamps
  are clock-relative fixtures, not a replaceable production clock.
- scripts/recovery/durable-ingress-ops.mjs adds opt-in serialized cleanup ticks,
  a disk-backed aggregate queue, fsynced temporary-file replacement, durable
  acknowledgements, same-key delivery retries and separate worker/watchdog/sink
  journals. No capabilities, tickets, IPs, request bodies or personal identifiers
  enter these journals. Replay bindings and C1 retention are untouched.
- The actual maintenance RPC -> scheduled worker -> durable queue -> real loopback
  HTTP sink path passes. Restarted queues do not redeliver acknowledged alerts.
  Four new Node tests also exercise HTTP failure, dropped delivery acknowledgement,
  restarted sender/sink deduplication, an independent watchdog process, interrupted
  worker lock, malformed state, stale temporary file, retention, backward clock,
  destination restrictions and non-overlapping scheduler failure/recovery/stop.
- HTTP result records now distinguish scoped-check PASS from scenario acceptance:
  scenarios 13 and 14 explicitly remain PARTIAL. The harness and four helper
  sources are hashed and rechecked before a successful result is written.

### Fresh test evidence (all final commands exit 0)

Final PG17 command:

powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-recovery-pg17.ps1 -CustomerCompatibility -IngressTest -HttpIntegration

Frozen final evidence: .cache/security-test-a898ce36e55c44799cba752fa39f9b70;
summary .cache/batch4-pg17-final.log. Server is PostgreSQL 17.12 / 170012,
PostgREST 16.6, Deno 2.9.8, Node 24.21.0, local Chrome 157. Synthetic records
only, dynamically allocated loopback ports and guarded fresh-cluster runner.
The harness raw-byte SHA-256 is
027fe64a180ccd7fe449e73c374b52134c439fc6dc386b5ca63fca5ef0b3604c.
Its four recorded helper hashes independently match the final working files.
This hash identifies this executed working file; original repository integrity
continues to use its explicitly defined Git-blob/LF contracts.

| Fresh command/check | Actual result |
| --- | --- |
| npm.cmd run lint | PASS, exit 0 |
| npm.cmd run typecheck | PASS, exit 0 |
| npm.cmd run test:security | PASS, exit 0 |
| npm.cmd test | 45 passed, 0 failed/skipped |
| npm.cmd run test:recovery-request | 10 passed, 0 failed/skipped |
| npm.cmd run test:ingress-monitor | 10 passed, 0 failed/skipped (4 new durable tests) |
| node --test tests/recovery.test.mjs tests/recovery-sql.test.mjs tests/hosted-package.test.mjs tests/recovery-compatibility.test.mjs tests/recovery-integrity.test.mjs tests/recovery-tooling.test.mjs | 27 passed, 0 failed/skipped |
| Installed Deno: test --cached-only --node-modules-dir=manual --allow-read=supabase/functions --allow-env=MEMBER_MOBILE_ENCRYPTION_KEY_B64,MEMBER_MOBILE_HMAC_KEY_B64 supabase/functions/_shared | 109 passed, 0 failed |
| Installed Deno: check --cached-only --node-modules-dir=manual (all 22 index.ts paths plus scripts/recovery/serve-local-edge.ts) | 23 checks PASS |
| npm.cmd run test:dev | 1 passed, 0 failed/skipped |
| npm.cmd run build | PASS; PWA 9 precache entries, 611.30 KiB |
| node scripts/test-browser.mjs | PASS; synthetic Auth/API development suite |
| node scripts/test-browser.mjs --production | PASS; synthetic production/PWA suite, Android UA/touch emulation, static-only caches and offline/update restrictions |
| node scripts/recovery/validate-source.mjs | PASS; original 75/75 HEAD blobs, historical SQL and separate candidate hashes; PG17/18 grammar |
| node scripts/recovery/validate-hosted-package.mjs | PASS; original 30 diagnostic hashes/order/read-only static contracts |
| node docs/production-preflight/sql-editor/validate.cjs | PASS; original 16 SQL-editor variants and hashes |
| PG17 customer/ingress/HTTP command above | PASS; 37 migration stages, 11 real legacy refusals, 2 ownership rollback probes, ACL/default/inherited refusals, 9 original races, 2 recovery races, ingress clock/capacity/lease and contention tests |
| git diff --check; changed-file sensitive-path/key/JWT scan | PASS; 16 candidate files, no matched credential patterns |

The Deno binary is the existing WinGet installation; no package/software was
installed. Node counted suites total 93 tests; Deno separately counts 109.
Browser scripts and PG SQL groups are not added to those counts as invented
individual assertions. Full hosted Auth/integration has not been run.

Earlier evidence is not relabelled: four new fault-harness iterations failed
before a complete run. Corrections included recognizing COMMIT-phase backend
queries, separating statement-timeout injection from deferred COMMIT timing,
and allowing explicit pool health qualification after deliberately severing
idle connections. The prior successful iteration is retained at
.cache/security-test-e2d0d94f040046aaa685bf76b126e61b. Final source/reporting and
full durable sink wiring were rerun in the frozen final directory above.
The early deferred-COMMIT sleep did not establish a COMMIT-duration bound; no
such guarantee is claimed. An interim lint read during a validator rewrite
failed parsing; frozen lint and node syntax validation subsequently passed.

### Updated fifteen-scenario acceptance

PASS below means the specified isolated local scope, never hosted acceptance.

| # | Acceptance scenario | Current result and evidence |
| --- | --- | --- |
| 1 | First valid submission | PASS: real Edge/PostgREST commit and one binding |
| 2 | Identical retry | PASS: same binding and original outcome |
| 3 | Payload conflict | PASS: 409, original preserved |
| 4 | Concurrent creation | PASS: two independent Deno handlers; one 201, one 200, one binding |
| 5 | Two tabs | PASS: real Chrome tabs and persisted database recovery |
| 6 | Reload | PASS: durable browser capability and same persisted outcome |
| 7 | Loss before commit | PASS: pre-dispatch loss plus mid-business/pre-commit backend interruption; no binding, safe explicit retry |
| 8 | Loss after commit | PASS: dropped acknowledgement and severed idle DB connection; observed committed binding recovered |
| 9 | Timeout | PASS: statement/lock timeout, deterministic separate pool acquisition refusal and recovery; unqualified business timers refused |
| 10 | Rollback | PASS: independent admission persists; public and financial state/audit preservation assertions |
| 11 | Expired record | PASS: actual HTTP 410 for valid expired snapshot; no replacement or revival |
| 12 | Unauthorized lookup | PASS: unknown capability, valid anon and ungated RPC denial; malformed/expired JWT rejection at real PostgREST |
| 13 | Owner reconciliation | PARTIAL: actual Owner SQL RPC, non-Owner denial and preserved/replayed financial effects pass; real Auth -> Owner Edge chain unavailable |
| 14 | All-attempt limits | PARTIAL: real HTTP representative limits/body boundaries, two Deno processes and native final-capacity/token/lease/ABA tests pass; exact live cutovers, full stress/fairness and provider-isolate campaign remain unverified |
| 15 | Payment/attendance uniqueness | PASS: actual RPC replay after two financial interruption phases; one payment and one attendance, native races supplement |

### Operational acceptance and remaining infrastructure

Local delivery components PASS their exercised scopes. The scheduler defaults to
60s, runs serially, reports sanitized failure and performs no automatic business
retry. The local watchdog test treats a heartbeat older than two minute bins as
stale; that is an explicit test/control proposal, not approved production policy.
Separate watchdog locking detects a stale heartbeat even when the worker's lock
remains after interruption. Journals expire aggregates at 2880 minutes and allow
at most 14400 unique minute/category records per lane; input reads are capped at
4 MiB. Disk write/lock/corruption failure refuses operation. No stale lock or
partial temporary file is silently stolen/deleted. Owner-local recovery must
inspect interrupted writes and reconcile sink acknowledgement keys before restart.
File fsync plus rename is not claimed to prove Windows power-loss durability.

Production still needs separately approved supervised worker/watchdog scheduling,
protected storage/ACLs and capacity, a genuinely independent failure detector,
qualified alert destination and reviewer, transport credentials/TLS, receiver
idempotency, heartbeat thresholds, delivery/retry/backoff/retention/privacy policy,
backup/restore and process-restart/power-loss qualification. Source has no external
alert credentials and configures no Windows service, scheduler or firewall rule.
Two Deno processes are not a Supabase multi-isolate or provider cleanup guarantee.

Read-only local inventory found no usable GoTrue/Auth server in the known installed
components or command paths. The Supabase client SDK and synthetic auth schema
are not an authentication service. Initial release remains Owner-only; no staff
account or new staff authority was introduced. Auth acquisition/provisioning is
outside this batch and requires separate authorization; scenario 13 stays PARTIAL.

### Exact working-tree inventory and cleanup

Six modified tracked files relative to HEAD:

- docs/GYMFORCE-DEVELOPMENT-PROGRESS.md
- docs/GYMFORCE-PHASE-6-1B-INGRESS-IMPLEMENTATION.md
- package.json
- scripts/recovery/validate-source.mjs
- scripts/test-database.ps1
- scripts/test-recovery-pg17.ps1

Ten untracked project source/test files:

- scripts/recovery/durable-ingress-ops.mjs (new Batch 4)
- scripts/recovery/qualify-http-faults.mjs (new Batch 4)
- tests/durable-ingress-ops.test.mjs (new Batch 4)
- scripts/recovery/ingress-monitor.mjs
- scripts/recovery/serve-local-edge.ts
- scripts/test-persisted-http.mjs
- supabase/recovery/phase61b/003-local-operational-controls.sql
- supabase/recovery/phase61b/operational-manifest.json
- tests/ingress-monitor.test.mjs
- tests/persisted-http-guard.test.mjs

Of the original 13, this batch updated the two reports, package test command,
validator, database harness (extra probe credential cleanup), HTTP harness and
local operational manifest. The wrapper, original monitor/bootstrap, candidate
003 SQL and two original monitor/guard tests were preserved without Batch 4 edits.
Only the unapproved local operational manifest gained the new helper fingerprints;
no historical or approved diagnostic fingerprints were changed.

Independent cleanup checked all six Batch 4 database attempts: zero plaintext
bootstrap/passfile/actor files, PostgREST credential configs, server PID files or
HTTP Chrome profiles remained; zero matching batch runtime processes remained.
Only the two verified fixture Chrome profiles were subsequently removed, retaining
screenshots/logs. Stopped synthetic databases, sanitized journals, screenshots and
dist output remain ignored. Existing PostgreSQL 18 and user browser data were not
modified. Index remains empty; HEAD remains 5283e35. Git's existing CRLF checkout
warnings are not new content changes; diff --check passes.

Local decision: PASS for the recorded component qualification, PARTIAL overall
acceptance. No new application defect was established by the final fault campaign;
the corrected failures were in test coordination/reporting. Production stays
NO-GO: A02 pending, hosted authority/ACL/legacy/drift/recovery gates unverified,
real Owner Auth integration absent, full load/cutover and physical Android
acceptance outstanding. Next milestone: separately authorize and qualify an
existing-compatible local Auth integration dependency, then exercise the actual
Owner Auth -> Edge -> PostgREST chain while preserving these frozen fault tests.


## Batch 5 - Auth discovery and local acceptance readiness, 2026-11-20

Preserved all 16 candidates, added only the deterministic SQL fixture and
GYMFORCE-BATCH-5-AUTH-READINESS.md (18 files total). No application/Edge handler,
historical migration, approved diagnostic or production change. Index empty;
master HEAD remains 5283e35. No Auth installation or startup occurred.

Fresh final PG17 evidence: .cache/security-test-3c52a2085b5446188aade9f8e2b2344e,
summary .cache/batch5-pg17-qualified.log. Exact clock-copy cases pass: UTC midnight,
10/60 inclusive window edges, fractional refill, rollback/forward time, exact
15s lease expiry and stale generations. Copies preserve original bodies except
names/clock, retain restricted executor/RLS/runtime checks, deny service/browser
execution and are fully rolled back. They are not live clock or hosted proof.

Two-process real HTTP load: eight concurrent hot-key lookups -> 2 allowed 404 /
6 rate-limited / 0 unavailable. Three waves of eight rotating keys -> 24 charges
in 1 second, 20 allowed 404 / 4 rate-limited / 0 unavailable, no business bindings.
Existing 37-stage/legacy/ACL/fault/concurrency suite passes. A rerun exposed the
old observer's missing startup/snapshot synchronization; guarded readiness plus
pg_stat_clear_snapshot now make its polling explicit. Timeouts unchanged.

Fresh final regressions: 93 counted Node tests, 109 Deno, 23 Edge/bootstrap checks,
lint/typecheck/security/build, Vite, both browser/PWA suites and all source/diagnostic
integrity checks PASS. Three earlier test-coordination/fixture iterations remain
failures in separate logs. Four database attempts and two browser profiles have
verified cleanup. Full commands, inventory and limitations are in the Batch 5 report.

No real native Auth/Go toolchain was found in inspected locations. The id-only
Auth shim cannot host GoTrue; a real schema, narrowly scoped identity, gateway
route and Owner adapter need separate approval. Official v2.198.0 inspected assets
have no Windows-labelled binary; source-build feasibility remains unverified.
Prepared nine actual-Auth acceptance cases without fabricating Auth evidence.
15-scenario status: 13 scoped PASS / 2 PARTIAL (13 and 14). A02 pending; production
NO-GO. Next approval is a pinned portable Auth acquisition/build qualification,
not service startup or SQL authorization.
