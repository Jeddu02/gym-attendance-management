# Phase 6.1A - Public-request ingress Owner decision package

Prepared 2026-11-19, Asia/Manila. Repository: original GYMFORCE, branch `master`,
baseline `01ceeab403e5689c0de0688893cdfba3e05f9c65`; clean starting working tree.

**DESIGN AND REVIEW ONLY. All new decisions below are PENDING.** No ingress
implementation, SQL execution, environment creation or runtime acceptance occurred.
The loopback restriction remains intact. A02 remains **PENDING OWNER DECISION**.
Production remains **NO-GO**. This package neither extends the earlier A1/B1/C1
local authorization nor accepts the continuing-ADMIN authority model.

## 1. Source findings and evidence boundaries

Read the Phase 6.1 implementation report, Phase 6.0A Owner package, Phase 6.0
contract and Phase 5.9 audit. Historical design statements that recovery was
unimplemented are superseded only within the local scope of Phase 6.1.

| Exact source | Verified source finding |
| --- | --- |
| `supabase/functions/public-walkin-recovery/index.ts:12`, `:13`, `:21` | `isolatedBackend` accepts only localhost, 127.0.0.1 or [::1]; POST returns 503 for other backend hosts even with its feature flag enabled. This is the restriction that MUST remain. |
| `supabase/functions/_shared/browser-cors.ts:23` | Exact Origin comparison and OPTIONS handling precede handler configuration/business checks. Origin is browser policy, not anonymous identity or a secret. |
| `supabase/functions/public-walkin-recovery/index.ts:23`, `:29` | Body/parser failures precede RPC dispatch. Valid create/lookup reaches SQL; there is no independent admission RPC or distributed concurrency lease. |
| `supabase/functions/_shared/pin-recovery.ts:44` | Existing reader requires JSON, checks declared length, bounds actual streamed bytes to 2,048, decodes strict UTF-8 and parses JSON. No read-duration bound is supplied here. It is shared with PIN routes; do not silently change those routes in this milestone. |
| `supabase/functions/_shared/walkin-recovery.ts:6`, `:28`, `:39` | Canonical 32-byte/43-character key, domain-separated digest and allowlisted recovery classifications already exist. No ingress capability is supplied by the browser. |
| `supabase/recovery/phase61/001-public-walkin-recovery.sql:29`, `:37`, `:59` | Operation advisory lock precedes lookup; new request and immutable binding share one business transaction. Replays/conflicts/unknown lookups bypass the creation-rate event. |
| `supabase/migrations/20261110140000_walkin_operations.sql:261`, `:269`, `:272`, `:278` | Original global rolling creation limiter counts accepted new creates; its event and cleanup roll back with business failure. It is NOT a durable all-attempt limiter. |
| `supabase/recovery/phase61/001-public-walkin-recovery.sql:17`, `:26`, `:81`, `:89` | Restricted ownership/FORCE RLS, command policies, service-only RPCs and old unkeyed service EXECUTE retirement must survive future integration. |
| `src/lib/walkin-recovery-store.ts:40`; `src/components/EntrancePage.tsx:101`, `:121` | Atomic browser slot precedes dispatch; explicit create/lookup retains the same capability and method. No automatic new-key retry, reset/purge, offline queue or cross-device transfer is approved. |
| `tests/walkin-recovery.test.mjs:17`, `:30`; `supabase/tests/public_walkin_recovery.sql:1`; `scripts/test-db-concurrency.mjs:172` | Actual-handler fixtures, native SQL state/fault tests and SQL transport races exist. These are separate layers, not persisted HTTP integration. |

The candidate's top-level 30s statement/2s lock settings govern its installation
transaction, NOT future RPC requests. The new runtime limits proposed below
require separate implementation and verification. No current timeout guarantee
is inferred from that file or from a browser fetch cancellation.

Phase 6.1 section 6 records **12 scoped PASS, two PARTIAL (#8 loss after commit,
#9 timeout), one BLOCKED (#14 all-attempt rate limits)**. These are historical
results, not fresh tests in Phase 6.1A. Actual browser/Edge/PostgREST/persisted-SQL
acceptance and physical Android acceptance remain unverified.

## 2. Recommendation and alternatives

Recommend **I1: independently committed, bounded PostgreSQL admission before
body parsing, followed by bounded per-key admission and an admission-required
business wrapper**, for separately authorized local implementation. Reuse the
existing isolated environment, existing restricted roles and service-only RPC
pattern. No Redis account, new cloud service, paid feature or custom domain is
required for this local design. This is an application work limiter, not a claim
of network-level DDoS protection or hosted compatibility.

| Option | Benefit | Limit / required decision |
| --- | --- | --- |
| I1 - existing-database admission | Independently committed attempt budgets survive malformed input, business exceptions and rollback; fixed storage and global leases work across Edge isolates. | Adds small RPC transactions and a hot admission lock; database/gateway admission traffic itself can be flooded. Requires exact ACL/authority review, runtime timeout qualification and persisted HTTP testing. Recommended for local work only. |
| I2 - independently qualified upstream gateway/distributed limiter | Can reject traffic before business infrastructure; potentially protects invocation quota if it genuinely sits before every invocation. | No such customer-configurable, non-bypassable ingress is established for this project. A proxy alone leaves the default function URL reachable. Provider capabilities, free-tier availability, privacy and any extra resource need separate approval. No provisioning authorized. |
| I3 - retain public recovery disabled | Avoids exposing an unqualified public mutation/recovery path. | Owner-mediated operating workflow needs separate acceptance; this does not satisfy server ingress acceptance. Current hosted-release default until evidence passes. |

Do not substitute isolate-memory maps, client storage, an IP header, the existing
creation counter, or a counter in the same transaction that raises an exception.
Do not introduce a database extension/autonomous transaction to simulate an
independent commit. Do not apply a project-wide PostgREST pre-request hook as an
unreviewed shortcut affecting Owner/PIN/other routes.

### Provider evidence and limits of the recommendation

Supabase's official rate-limiting example uses an external Redis service; it does
not establish an existing built-in, project-specific all-attempt budget or grant
permission to provision that service. [Supabase rate-limiting example](https://supabase.com/docs/guides/functions/examples/rate-limiting).

The documented Edge runtime has memory, CPU, wall-clock and idle limits; they are
platform ceilings, not this API's admission, fairness or response SLA. No inference
about the project's current plan/settings is made. [Supabase Edge limits](https://supabase.com/docs/guides/functions/limits).

PostgREST pre-request configuration applies to the Data API, not all Supabase
products or malformed requests stopped earlier at Edge. It also does not make
business-transaction counters independently durable. [Supabase API security](https://supabase.com/docs/guides/api/securing-your-api).

PostgreSQL distinguishes statement and lock timeouts. The proposed effective
settings must be in place before the relevant request statement begins; setting
a statement timeout inside an already running function is not accepted as proof
of an outer RPC deadline. [PostgreSQL 17 timeout semantics](https://www.postgresql.org/docs/17/runtime-config-client.html).

These references were read without project authentication. They establish no
actual hosted authority, trust-header behavior, queue bound or resource capacity.

## 3. Boundary, ordering and durable admission contract

**Coverage definition:** every public recovery attempt is either cheaply rejected
before business access, or requires fresh distributed admission before reading
its body. All permitted-origin POSTs count, including malformed JSON/keys,
oversize bodies, valid creates, conflicts, replay and lookup. OPTIONS, rejected
Origins, unsupported methods and disabled/configuration failures take bounded
early-return paths with no business RPC. They are NOT durable database attempt
events. Counting them by database writes would amplify unauthenticated floods.
Their invocation/transport exposure requires separate upstream qualification.
This explicit exemption needs Owner acceptance; no claim that every network
packet is counted, stored or prevented from invoking an Edge worker is made.

Proposed request order, with no automatic RPC retry:

1. Preserve exact-origin CORS and trusted OPTIONS first, including when service
   configuration is absent. Disallowed/missing Origin gets no CORS allow headers.
   Nonbrowser callers can forge Origin; all later controls still apply.
2. Reject unsupported method; validate feature gate, loopback restriction and
   all required server policy/configuration. Missing/inconsistent policy fails
   closed. No fallback to unkeyed creation or permissive default limiter.
3. Call **admit** as a distinct service-only POST RPC, before content validation
   or body reading. Under a short global lock, consume rolling aggregate budget
   and acquire one fixed lease slot. Return a normal allowed/denied result so
   intentional denials commit bounded counter state instead of raising it away.
   An SQL error or lost admission acknowledgement gives 503; dispatch NO business
   call and perform no automatic admission retry. An unused lease expires safely.
4. Under the body deadline enforce JSON, no content encoding, declared/streamed
   2,048-byte limit and canonical action/capability/paymentMethod schema. Reject
   malformed/missing keys without any capability lookup. Cancel the reader on
   oversize/deadline/disconnect; no unbounded drain. Admission credit is not refunded.
5. Hash the capability using the unchanged domain. A separate **bind-admission**
   RPC commits the per-key budget charge and binds the server-generated lease
   token to action, digest and SQL-derived canonical method fingerprint. This is
   before business processing, including valid but unknown lookups. Action/digest
   cannot subsequently be changed by the Edge or browser. Conflict/closed/unknown
   results still cost admission, but no additional creation event.
6. One **execute-admitted-operation** RPC checks the bound, unexpired lease and
   locks its row through transaction completion, then invokes the reviewed core
   recovery helper. It uses the established operation-lock -> creation-rate-lock
   -> fee-lock order. Only a new request incurs the existing creation event.
   Binding/request effects remain one business transaction. No admission budget
   refund occurs on rollback because those charges committed separately.
7. Allowlist responses, no-store and exact CORS. Preserve the same browser key
   for any ambiguous result; do not infer rollback from 429/503/network loss.
   On known completion release/complete the lease without refunding counters;
   a failed release cannot change a committed outcome. On unknown business
   completion do NOT release early. Expiry/reclamation must respect database
   locks as described below; no retrying a payment-sensitive operation.

The names above are proposed internal operations, not implemented endpoints or
approved SQL signatures. Each independent commit is a separate request/transaction;
no function may COMMIT inside the caller's business transaction. Admission can
commit without a business result; this conservative loss of quota is intentional.
Admissions must never create provisional requests, receipts or attendance.

### Bounded state, locks and crash handling

Propose private admission state separate from immutable recovery bindings:

- A preallocated 61-slot, one-second ring for conservative global rolling counters, a daily counter,
  eight reusable lease rows and 4,096 fixed digest-hash buckets for per-key
  budgets. No row per invalid/random key, raw IP or request body. A hash-bucket
  collision can conservatively throttle unrelated keys; this is a documented
  false-denial tradeoff, not exact per-person identification.
- Global 10s/60s counts charge every reachable POST once admitted to the counter
  transaction, including denied saturation attempts (use saturating arithmetic).
  Unknown/canceled transactions are not claimed durably counted. Allowed work
  remains bounded by successfully committed reservations. Do not refund charge
  when a later stage fails. Reject on lock timeout or unavailable store.
- bind-admission serializes budget changes in deterministic global -> bucket ->
  lease order; it never calls business logic. Business calls lock lease ->
  operation -> existing rate -> fee -> new-binding capacity; they never reacquire admission/bucket locks.
  Release/reclamation locks only a lease. Measure hot-key and full-slot behavior
  to reject deadlocks or unbounded scan/queue growth.
- A lease has an unpredictable server token, generation, issued/expiry times,
  bound digest/action/fingerprint and state. Tokens never reach the browser or
  logs. Owner/configured policy values cannot be supplied by the public payload.
  The business wrapper verifies every binding and the generation, and rejects
  expired/reassigned tokens. The limiter is trusted server mediation, not a new
  public bearer API. No client-selected bypass/admission header is accepted.
- Reclamation skips locked slots; an expired lease with a business transaction
  still holding its row is NOT reusable. After crash/rollback releases the row,
  an expired slot may be reused with a new generation. Expiry alone never proves
  rollback. An already admitted transaction can finish after client loss, with
  its result recovered using the same original capability.
- Completion marks a ticket unusable. Business rollback can also roll back that
  completion marker: the Edge MUST acquire a fresh admission for every subsequent
  HTTP attempt and never automatically reuse a ticket after an error. Same-key
  business idempotency remains authoritative independently of ticket lifecycle.
  Do not advertise exactly-once ticket consumption across a business rollback.
- Enforce the new-binding capacity at insertion (proposed narrow trigger on the
  new recovery table), using a serialized capacity row checked/incremented last
  in the business lock order. Failure rolls back the just-created request and
  binding together; the capacity increment also rolls back. Replay never inserts
  or increments it. Initial counter/table consistency, all insertion paths and
  refusal on drift need assertions. Never use an unlocked count or test capacity
  before deciding whether this is a replay. No historical trigger is replaced.
- Per-key budgets use fixed token buckets: refill 12/minute, capacity 3, with
  a separate lookup sub-bucket refill 6/minute, capacity 2. A lookup consumes
  both. No token refund on business failure. No raw capability/digest is retained
  in those buckets; the short-lived bound lease retains only the digest needed
  for server-side validation, not a business response.

Lease bounds limit admitted parsing/business work, not all live Edge isolates,
in-flight rejected admission queries or the provider's queue. Establish bounded
PostgREST queue/pool behavior and upstream protection before hosted release.
If the platform cannot supply the needed bounds, retain I3 or separately review
I2; do not quietly label I1 complete network-level protection.

## 4. Proposed security threshold matrix - NONE approved by this package

Values are conservative initial synthetic-test candidates, not measured capacity
or approved production policy. Owner may accept, revise or reject each ID.
No per-IP rule or trust in forwarded headers is proposed. Day limits use UTC
for technical accounting only; all gym business dates remain Asia/Manila.

| ID / recommended value | Rationale and operational tradeoff | Enforcement / test | Owner approval |
| --- | --- | --- | --- |
| T1 body: 2,048 bytes, streamed and declared; JSON UTF-8 only; reject Content-Encoding | Retains the existing reader bound; no decompression amplification. Valid JSON at the bound may pass only if its schema is valid. | Edge reader; 2,047/2,048/2,049-byte valid-whitespace cases, chunked/absent/lying length, invalid UTF-8, compression and slow body. Oversize remains generic 400 to retain existing public classifications. | YES: retain bound; new encoding/deadline enforcement requires implementation approval. |
| T2 global: at most 20 admitted POSTs in any trailing 10s AND 120 in trailing 60s; 2,000 per UTC day | Covers all create/lookup/replay/malformed paths; one attacker can deny shared service. Daily circuit is NOT an Edge invocation/cost cap. | Independent admission transaction, server clock, 61 serialized second bins; count every bin intersecting the trailing window and expire only wholly old bins. Test 20/21, 120/121, 2,000/2,001, window edges and multiple isolates. Bins may deny up to one extra second, never allow an extra quota; 60 bins alone would omit a partial boundary bin. | YES, including shared-service false denials and daily reset. |
| T3 keyed: capacity 3/refill 12 tokens per minute; lookup capacity 2/refill 6 per minute; 4,096 fixed buckets | Bounds hot-key replay and probing without unbounded key records. Different keys remain subject to global budgets; bucket collisions reduce fairness. In 60s token buckets may admit the initial burst PLUS refill, not a strict rolling 12/6 cap. | Independent bind-admission transaction; fractional server-time refill, concurrent last token, collisions, lookup consumes both, unknown keys and rollback survival. | YES. |
| T4 concurrency: 8 global admitted leases; 1 active business transaction per operation through its existing lock | Avoids per-isolate pseudo-global limits. Busy keys can hold slots; no fairness guarantee or hidden queue. Different operations remain distinct. | Fixed slots, no waiting for a free slot; ninth is 429. Overlap, expiry-while-locked, crash, ABA and multi-isolate tests must keep active business calls <=8. | YES. |
| T5 runtime: 10s total Edge response deadline; 2s body read within it; each admission/bind RPC <=1s; business statement <=5s; admission lock <=100ms; business lock <=500ms; lease TTL 15s | Limits slow readers/locks; cold starts and normal contention can cause false unavailable/uncertain outcomes. Expired locked slots stay occupied, never enable overlapping work. | Monotonic Edge deadline/AbortSignal; effective DB settings BEFORE statements, verified across reused PostgREST sessions. Hold locks and interrupt at every stage. Header/body/response timing included; provider startup/transport delay outside Edge handler is not an SLA. | YES; supported scope of timeout configuration remains an implementation/provider gate. |
| T6 creation: propose existing global limiter configured at 10 new requests / rolling 60s; hard capacity 10,000 retained bindings for the accepting version | Separate business-storage safeguard; replays/lookups do not consume new-create credit. Capacity exhaustion closes NEW creation with 503, retains recovery/Owner operations and ALL records. It never purges or revives. | Existing rolling limiter plus new atomic capacity check/counter only in the new wrapper transaction; 9/10/11 creations, near-capacity race, rollback and replay-at-cap tests. No historical SQL edit. | YES: proposed new capacity policy and configuration; not an approved new business entitlement rule. |
| T7 transient cleanup: lease fields cleared on known completion or safe reclamation after 15s; idle per-key token state reused after full refill (<=20s); wholly old global bins reused after at most 61s | Fixed state avoids append-per-attempt exhaustion. Digest present in a locked lease can outlive TTL until transaction cleanup; an error never authorizes erasing replay evidence. | Narrow RPC maintenance on bounded admission rows only; no DELETE grant on business history, cleanup crash tests. | YES: technical privacy policy; not permission to purge C1 bindings. |
| T8 monitoring: one aggregate minute record in a fixed 2,880-slot ring (48h); no identifiers/bodies/digests/IPs; alert at >=20 denials/min, any limiter outage, or >=5 timeouts/min | Enough local signals to detect abuse without a tracking log. Ring rollover loses old samples; business audit remains separate. Provider automatic logs/retention are not controlled by this proposal. | Fixed counters/classifications/latency histogram, no per-request inserts; sentinel leak and overflow tests. Sample counters saturate instead of increasing storage. Owner reviews alerts; no automatic privilege/config changes. | YES, including 48h proposal and mandatory retention/incident holds review before release. |
| T9 throttled response: 429 REQUEST_UNAVAILABLE, fixed Retry-After: 5 seconds; unavailable/deadline: 503 REQUEST_UNAVAILABLE | Does not expose remaining quota, key existence or SQL errors. Five seconds is minimum advice, not guaranteed admission; no automatic browser retry. | Response allowlist, no-store and exact-origin CORS tests for all paths; deny CORS on rejected Origin. No new client payload fields. | YES for added header semantics; 400/403/405/429/503 classes already exist. |

Client key remains exactly 32 Web Crypto random bytes, canonical unpadded
base64url length 43, fixed version/domain and existing typed fingerprint. This
is an existing A1/B1 invariant, not a new adjustable entropy threshold. Validate
decode/re-encode/trailing bits; no weak fallback. The existing 15-minute server
request expiry is approved and unchanged. Binding retention is still C1: no
purge while its version accepts creation. Production schedule, restore/retirement
and shared-browser cleanup remain separate open decisions, not T7/T8 TTLs.

## 5. Request classifications and fail-closed behavior

| Attempt | Before business / persisted consequence | Public handling |
| --- | --- | --- |
| Trusted OPTIONS | Exact Origin, no body/DB/admission needed; A06 preserved | 204 even if unrelated service settings missing. |
| Missing/wrong Origin; non-POST | Bounded rejection, no business or admission row | 403 without permissive CORS; allowed-origin non-POST 405. No Origin-as-auth claim. |
| Disabled/missing policy, service config or non-loopback backend | No business dispatch | 503; loops/gates unchanged. |
| Malformed JSON, invalid/missing key, extras, oversized/slow body | Global admission already charged; no key lookup or business rows; safe lease cleanup | 400 for invalid/oversize; 503 on deadline. No parser/database details. |
| First valid create | Global + key admission; atomic request/binding/creation event | 201 provisional snapshot only; no payment/attendance. |
| Identical replay | Both budgets; original binding/snapshot, zero new creation event | 200 while pending/unexpired; unchanged fee/expiry. |
| Same key changed payload | Both budgets; SQL refuses conflict, zero new business effects | 409 without original payload/snapshot. |
| Lookup with valid unknown/other key or bare UUID | Bare UUID fails parser; valid unknown key costs both budgets; no target disclosure | 400 or 404; a 404 cannot prove a delayed original will never commit. |
| Expired/terminal key | Both budgets; preserve evidence and original records | Generic 410, no reason/payment/attendance details; no revival/re-key. |
| Concurrent calls | Independent admission, same-key SQL serialization; lease/global/key excess refuses before business | Replay/conflict or 429/503; do not queue unbounded work. |
| Rate/store/capacity failure | Rate denial changes only bounded admission counters; unknown admission commit means no business; capacity failure preserves bindings | 429 for known quotas/slots; 503 for unknown state/storage limit; no automatic retry. |
| Interrupted before DB receives business / transaction rolls back | Admission can persist; no partial request/binding or financial effects after verified rollback | Retain K and uncertainty until recovery; fresh admission for explicit same-key retry. |
| Interrupted after commit / deadline races commit | One committed binding/request possible; admission expiry never rewrites it | Treat HTTP failure as unknown, lookup with same K; never promise cancellation undid the commit. |

No public endpoint returns raw capabilities, admission tokens, body hashes,
receipt IDs, Owner identity, payment/attendance status or audit material. Existing
201/200 distinction and 404/410 classifications necessarily reveal limited state
to a capability holder. Do not claim constant-time processing or complete state
indistinguishability: hot locks and DB timing differ. Use uniform generic errors,
bounded work and no detailed quota/status headers; test for accidental additional
disclosure. Random-key guessing remains computationally infeasible, but stolen
keys and malicious different-key operations remain real residual risks.

## 6. Integration and privilege design

Propose additive private admission/bucket/lease/aggregate structures owned by
gym_data_owner with ENABLE/FORCE RLS. Use existing gym_public_executor for narrow
command/column policies on these new structures only. SELECT/INSERT/UPDATE of
required limiter fields is an explicit new local review surface; no general
data access, membership, schema CREATE or bypass-RLS privilege. Preallocate
rows during separately authorized local setup; no caller-controlled schema/SQL.
Private helpers remain invoker, empty search_path and fully qualified names;
API definer functions use the restricted executor, service-only EXECUTE and
explicit revocation from PUBLIC/anon/authenticated/other executors. Verify global,
schema, inherited, column and future-function privileges; no broad blanket grants.

Before future opening, retire service EXECUTE on the Phase 6.1 *ungated* v2
create/lookup wrappers as well as the already retired unkeyed creator, or enforce
admission in a separately reviewed forward replacement. Recommend new internal
admission-required wrappers and explicit revocation of older transport entrypoints;
keep the core helper/internal ownership path. Review all overloads, old bundles,
direct API URLs and stale client paths. No browser can call these RPCs directly.
Service credential compromise remains outside an anonymous limiter's guarantees;
it must not be possible to bypass admission using ordinary public/anon keys.

No Auth/session/Owner RPC changes, no new login/executor roles, no changes to
A02's model. New object ownership/grants still require actual authority proof;
local administrator-created objects cannot close that hosted gate. Policy checks
on CURRENT_USER constrain executors, not end-user identity. Owner actual-receipt
approval and existing payment/allocation/attendance guards remain authoritative.

Browser payload and storage stay unchanged. Admission is invisible to the client;
all retries are explicit, same key/method and freshly admitted. Preserve offline
no-dispatch, strict response validation and no API caching. A rate-limited lookup
must not clear the saved capability or imply absence of a request. No new slot
reset, selective revocation, transfer or person-level deduplication is introduced.

Abuse telemetry is separate from the append-only business audit. Do not append
one business audit event for every malformed anonymous request. Configuration
changes, shutdown/reopening or an Owner financial resolution require separately
authorized procedures and appropriate existing audit evidence. Admission cleanup
cannot delete financial/member/attendance/audit history or replay tombstones.

## 7. Threat model and residual risk

| Threat | Proposed control | Residual / release gate |
| --- | --- | --- |
| Anonymous flood, spoofed Origin, rotating keys | Independent global burst/day budget before parsing; fixed-state key buckets and leases | Admission RPC/Edge invocation itself can be flooded; CORS and public API keys are not authentication. Upstream/queue qualification mandatory, no free-tier availability guarantee. |
| Key enumeration/unauthorized lookup | Canonical 256-bit K, no UUID lookup/list, service-only RPC and generic unknown response | XSS/device theft gives the limited bearer authority; never call hashing encryption or authentication of a person. |
| Same-key replay/conflict and two devices | Existing immutable binding, canonical payload, SQL operation lock; fresh admission for every attempt | Different anonymous K remain distinct operations; no inferred per-person rule. Cross-device transfer is not approved. |
| Duplicate money/attendance | Recovery touches only provisional requests/bindings; unchanged Owner operation replay/allocation/attendance constraints | Different real receipts need Owner review, never fuzzy suppression, refund or automatic correction. |
| Timing/status probing | No detailed quota/config errors, bounded waits, no sensitive response fields | Existing capability-holder outcome classifications remain; no claim of timing noninterference. |
| Admission bypass | Gate every new public handler call, service-only admitted wrappers, remove legacy direct EXECUTE paths, negative direct-URL tests | A second reachable function or forgotten overload defeats the boundary. An optional proxy with a reachable origin is insufficient. |
| Storage exhaustion | Fixed admission tables; atomic new-binding capacity circuit; no per-key log inserts | Legitimate new creation eventually stops under C1 retention. Owner must decide sustainable retention/version retirement or capacity before production. Recovery stays available when only create capacity is exhausted. |
| Network loss/worker death/clock jumps | Committed independent budgets, locked leases with generation, server clocks; monotonic Edge deadlines and same-key recovery | UTC clock jumps and expired-but-active sessions require tests. No automatic refund or conclusion of rollback from client abort. |
| Shared-network fairness | No unverified IP trust or per-IP person assumption; global budget tests with legitimate users | An attacker can exhaust everyone's budget. IP/challenge controls would require a new privacy/trust/provider decision. |
| Log/trace collection | No request bodies, capability/digest/ticket, IP or identifiers in app telemetry; bounded aggregates only | Actual provider request/error/query logging and retention require separately authorized inspection; a code redaction test alone cannot establish hosted privacy. |

## 8. Acceptance specification and existing 15-scenario mapping

All NEW ingress tests below are **NOT RUN**. Implementation does not exist.
Reuse existing isolated PG17 and harness only after explicit new authorization;
do not provision another environment. Existing fixtures remain useful regression
layers, but the final persisted HTTP test must run the actual Edge module and
PostgREST against synthetic SQL, with server configuration and failpoints controlled
only in tests. No fixture-response success may stand in for committed rows.

State notation: I=independently committed admission counters, S=active lease,
O=immutable operation binding, W=walk-in request, L=creation-rate event,
P=receipt/allocation history, A=attendance. Delta counts refer to one operation.

| Original case / historical Phase 6.1 status | Required Phase 6.1B extension and measurable acceptance |
| --- | --- |
| 1 first submission / scoped PASS | Real HTTP 201; I charged, S released after known completion, O=W=L=1, P=A=0; exact snapshot/15 minutes. |
| 2 identical retry / scoped PASS | Another admission, same O/W/L after fee change, 200 original snapshot; no creation quota recharge. |
| 3 conflict / scoped PASS | Charge I/key bucket, HTTP 409, unchanged original O/W/L, no original-method disclosure. |
| 4 concurrency / scoped PASS | Multiple Edge workers + native SQL waiters: <=8 locked active business leases; one O/W/L for same K, ninth admission 429; no stale-generation execution or lock-order deadlock. |
| 5 two tabs / scoped PASS | Real two-tab IndexedDB race plus actual HTTP persistence: same K and one O/W/L; every dispatched retry charged separately; different-method conflict and deliberate different-key residual demonstrated. |
| 6 reload / scoped PASS | Reload unknown operation, explicit admitted lookup; no automatic POST create/new K, original O/W retained. |
| 7 loss before commit / scoped PASS | Drop before business delivery AND cancel after transaction starts; independently inspect actual rollback: O=W=L=0, I remains; lease eventually reclaimable; delayed original/retry yields <=1 request. |
| 8 loss after commit / **PARTIAL** | Real Edge/PostgREST delivery fault AFTER confirmed commit; no fabricated response, same-key lookup recovers O=W=L=1; no P/A or duplicate, I counts each new attempt. This is currently missing. |
| 9 timeout / **PARTIAL** | Actual HTTP deadline before/after commit, held admission/bucket/operation/fee locks, slow body, pool queue and worker death; verify DB cleanup separately. No early reuse of expired-but-locked lease; UI unknown, same K, 0 or 1 whole O/W/L consistent with independently observed commit. This is currently missing. |
| 10 rollback / scoped PASS | Inject business binding failure; I/key charge survives, O=W=L=0, protected finance/member/audit/history hashes unchanged; all leases/locks reclaim safely. Admission/bind failure cannot dispatch business. |
| 11 expiry / scoped PASS | 410 without snapshot/revival, repeated expired replay costs I but never L; no tombstone purge; bounded admission cleanup does not touch C1 records. |
| 12 unauthorized lookup / scoped PASS | Wrong/missing K, malformed trailing bits, extra UUID/fields, wrong Origin, disabled config, direct RPC/table and old routes; expected generic status and no target snapshot. Invalid inputs cost global budget after early checks; malformed keys create zero bucket/binding rows. |
| 13 Owner reconciliation / scoped PASS | Admission failure never grants access or suppresses Owner review. Non-Owner/deactivated actor denied; actual Owner receipt once, mandatory correction/evidence history unchanged. No public receipt/attendance disclosure. |
| 14 rates / **BLOCKED** | Test ALL classes through real HTTP, not just accepted creation: T1-T9 edges, rotating keys, hot-key flood, malformed/oversize attempts, no per-key row growth, collisions, same-key denied business calls, store outage and multi-isolate budgets. Prove independent I survives downstream rollback, stale/missing admission fails and no transport bypass. Existing creation-only PASS is insufficient. |
| 15 payment/attendance uniqueness / scoped PASS | Concurrent recovery/Owner-confirmation/allocation/void flows retain one allocation and one attendance per request, same Owner operation one receipt; protected financial/audit hashes and original nine races remain valid. |

Additional acceptance controls:

- Test T1 byte boundaries separately from JSON/schema validity, declared vs actual
  size, unknown Content-Length and reader cancellation. Zero business dispatch
  for all failures; trusted OPTIONS still works with missing service config.
- Use deterministic test clocks, then real server-clock boundary tests: sliding
  rings must never undercount because timestamps were sampled before waiting;
  token refill and UTC-day reset must handle clock movement conservatively.
- Simultaneous last-budget/last-slot/10,000th-binding races, eight locked expired
  leases, ABA/stale release, process termination and lost admission acknowledgements.
  No unbounded retries, per-client records, reconnect loop or automatic cleanup
  of uncertain bindings. Counter overflow saturates and refuses.
- Verify actual per-statement settings, request pool reuse and no timeout leakage
  into unrelated Owner/PIN routes; a function SET clause or mocked AbortSignal
  alone is not sufficient. If the approved client/provider cannot supply a scoped
  setting safely, mark runtime qualification BLOCKED and retain loopback restriction.
- Snapshot ACLs/owners/defaults/inherited paths/FORCE RLS, negative anonymous and
  authenticated requests, old service-RPC denial and all overload inventories.
  Prove no schema CREATE, membership, audit rewrite or broad service table grant.
- Scan HTTP/DB error/app/trace outputs with synthetic secret sentinels; monitor
  ring bound stays fixed under flood. Qualified upstream tests must address
  default endpoint bypass, OPTIONS/bad-Origin invocation exhaustion and queue
  pressure separately; application admission tests cannot certify those layers.

## 9. Owner decisions and exact proposed wording

All decisions require a recorded accept/revise/reject, Owner name/date and explicit
conditions. **Nothing is preselected or approved here.** Earlier A1/B1/C1 approval
continues within its original scope; the IDs below are new Phase 6.1A decisions.

| ID | Decision required | Recommendation / consequence |
| --- | --- | --- |
| I1 | Architecture and coverage exception | Accept bounded independent DB admission for local implementation, plus mandatory upstream/queue release gate; accept cheap no-DB rejection paths, not a promise to persist every packet. Otherwise revise or retain I3. |
| T1-T9 | Each exact proposed threshold/policy | Accept for synthetic local testing only or provide replacements. Production values remain unapproved even if local tests pass. No silent default or removal of limits. |
| P1 | Abuse/privacy handling | Accept minimal aggregates, no IP/identifier logging, proposed 48h ring, C1 no-purge separation, false-denial/collision/shared-service limitations. Hosted provider logging/privacy review still required. |
| L61B | Local source implementation permission | Separate affirmative authorization needed for forward proposals, scoped Edge/wrapper/limiter grants and tests. Current task authorizes documents only. |
| V61B | Isolated persisted HTTP test permission | Identify already authorized local PG17/Edge/PostgREST/client components and operator, synthetic scope and interruption/load tests. Missing software/stack must be reported, not installed or provisioned implicitly. |
| H1 | Future hosted ingress/authority/privacy verification | Remains unapproved; exact scope/client/target/evidence/window required later. Does not grant A02 trust acceptance or changes. |

**Design acceptance only:**

> I accept I1, including its stated early-rejection coverage and residual Edge/
> admission-RPC flood exposure, for further local implementation consideration.
> I accept/revise/reject each T1-T9 as recorded and accept/revise/reject P1.
> These are proposed synthetic-test limits, not approved production policy.
> I require non-bypassable entry paths, independent committed admission, bounded
> state/leases and unchanged recovery/Owner financial security. This design
> decision does not authorize code, SQL execution, hosted access or A02 acceptance.

**Separate optional LOCAL implementation authorization (L61B):**

> Subject to my explicit I1/T1-T9/P1 selections, I authorize Phase 6.1B local-only
> source implementation: new additive review SQL/manifests, narrow admission
> state/policies/RPCs, admitted wrappers and retirement of local ungated transport
> execution, bounded recovery-handler integration and regression tests. Preserve
> historical migrations, approved diagnostic hashes, A02's pending status and all
> business rules. Keep the loopback restriction; do not enable a hosted route,
> add resources/dependencies without approval, commit, push, merge or deploy.
> Stop any portion needing a materially different security or business decision.

**Separate optional LOCAL integration authorization (V61B):**

> I authorize synthetic tests only in the following existing isolated local
> environment/components: [OWNER TO IDENTIFY/CONFIRM]. Operator/window/load ceiling:
> [OWNER TO CONFIRM]. Permit reviewed additive SQL there, real loopback Edge/
> PostgREST HTTP tests, controlled disconnect/timeout/crash/concurrency tests and
> independent persisted-state/cleanup assertions for the 15 cases. No hosted
> connection, real records, infrastructure creation or software installation is
> authorized. Report unavailable components as BLOCKED. Maintain private synthetic
> evidence without tokens/credentials in source or logs.

Owner decision/name/date/conditions for each row: **PENDING; not supplied here**.
Local implementation and integration authorizations are independent of production
diagnostic, privilege, migration, deployment and operating approvals.

## 10. Implementation dependencies, recovery and final decision

If separately authorized: (1) pin selected policy and private-state/ACL design;
(2) implement bounded independent admission and faults in existing local PG17;
(3) add admitted wrappers and negative transport-bypass tests with the original
core recovery intact; (4) integrate Edge deadlines/body controls without changing
PIN/Owner paths or lifting loopback; (5) execute the full persisted HTTP matrix,
existing regressions and source/hash review; (6) request Owner review of exact
new artifacts, evidence and remaining limits. No new migration version or expected
fingerprint is fabricated by this design. New artifacts need their own reviewed
manifest and truthful future runner/history strategy, not revised original hashes.

Failure rollback must preserve earlier independent admission charges and the
atomic business outcome. A later release/telemetry failure cannot undo a committed
request. Stop/reconcile unknown acknowledgements; no rekey, history repair, ledger
deletion or unkeyed fallback. Backout means keep the public feature unavailable
and review forward recovery; it does not mean restoring ungated SQL execution.
Admission ring restoration is not replay-evidence restoration. Actual backup,
RPO/RTO, keys, traffic quiescence and version retirement remain release gates.

**Remaining blockers:** Owner selections and new local permissions; qualified
persisted HTTP infrastructure; demonstrated effective scoped timeout/queue/lease
behavior; provider ingress/logging/capacity evidence; A02 decision/authority;
A03 privileges, A04 legacy data/audit, A07 object/history reconciliation;
record/browser retention and shared-device procedures; physical Android and
operating/recovery approvals. No local result can replace them.

**Phase 6.1B: NO-GO until I1, T1-T9, P1, L61B and V61B decisions are explicit.**
The package is ready for Owner design review, not implementation or execution.
Highest-priority next action: Owner accept/revise/reject I1's independent-admission
architecture and coverage/residual-risk boundary, then record threshold and local
scope decisions together. If unacceptable, retain the disabled hosted path and
request a separately scoped I2 feasibility review. **Production remains NO-GO.**

## 11. Validation performed in this documentation-only phase

Repository/source/report inspection and unauthenticated official-documentation
research only; no application/SQL/test/manifest changes and no database tests or
connections. Required final checks are file-scope review and `git diff --check`;
their actual result is recorded in the accompanying development-progress entry.
Prior Phase 6.1 runtime counts above remain historical, not rerun or promoted.
