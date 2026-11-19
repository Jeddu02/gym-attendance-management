# Phase 6.0 — Public-request recovery contract and idempotency architecture

2026-11-19, Asia/Manila. Original repository, `master`, HEAD
`ad41b7988d0d9fc4a56e675aeaff9b613878cdda`.

**DESIGN PROPOSAL — NOT IMPLEMENTED OR AUTHORIZED FOR EXECUTION.**
Production remains **NO-GO**. A02 continuing-ADMIN authority remains **PENDING
OWNER DECISION**. This document proposes a forward contract for Owner review;
it neither approves that authority model nor authorizes SQL, API changes,
browser capability storage, migration execution or deployment.

## 1. Verified existing behavior

References are repository paths and source line numbers at this working-tree
baseline, including the preserved, uncommitted Phase 5 changes.

| Component | Source evidence | Existing behavior / boundary |
| --- | --- | --- |
| Public page | `src/components/EntrancePage.tsx:20`, `:80`, `:88` | Mount-local attempt/in-flight guards; sends only paymentMethod. Once dispatched, an unknown outcome locks this mounted page. No durable cross-tab/reload identity. |
| Public parser | `supabase/functions/_shared/walkin-request.ts:54` | Exactly one property, paymentMethod, with cash/gcash/bank_transfer enum. A recovery argument is currently rejected. |
| Edge transport | `supabase/functions/public-walkin-request/index.ts:22`, `:38`, `:46` | Exact-origin wrapper, feature/config/rate prerequisites, server-only RPC; safe allowlisted snapshot or generic failure. RPC commit can precede a lost response or failed response-shape validation. |
| Creation RPC | `supabase/migrations/20261110140000_walkin_operations.sql:261` | Every accepted invocation inserts a new request and rate event. Transaction locks serialize global rate/fee decisions; they do not associate retries with prior outcomes. Fee and clock are server-selected; lifetime is 15 minutes. |
| Existing request | `supabase/migrations/20261028062706_walkin_attendance.sql:24` | Server UUID, fee/version/currency/time snapshot, status and Owner confirmation fields. No anonymous creation operation key. |
| Owner confirmation | `supabase/migrations/20261110140000_walkin_operations.sql:312`, `:332`, `:354`, `:368` | Separate Owner operation UUID, verified active Owner, operation replay checks and request row lock. Atomically records actual receipt and either confirmed allocation/attendance or receipt review. Public creation does not confirm payment. |
| Uniqueness | `supabase/migrations/20261110140000_walkin_operations.sql:37`; `supabase/migrations/20261028062706_walkin_attendance.sql:102` | One allocation per walk-in and one attendance row per walk-in. These do not prohibit two different request UUIDs for an anonymous person's intended visit. |
| Final receipt rules | `supabase/migrations/20261110190000_receipt_allocation_review.sql:42`, `:72`, `:85` | Owner-only verified receipt allocation; expiry, exact amount/method, prior allocation/void and current-presence checks. These final rules must survive the new creation design. |
| Tests | `scripts/test-browser.mjs:220`; `supabase/functions/_shared/walkin-request_test.ts:25`; `tests/public-entry-contract.test.mjs:44` | Real second browser target/reload can dispatch another creation POST; parser forbids extra operation fields; snapshot tests reject malformed responses. HTTP fixtures do not prove two database commits. |

Reviewed the Phase 5.9 audit, Phase 5.8 acceptance record and development progress.
Their runtime outcomes remain historical. No database or HTTP runtime test was
performed for this documentation-only milestone.

Current lifecycle: entrance QR → page selects method → POST → Edge checks → one
database transaction creates provisional request → allowlisted HTTP result →
page shows provisional reference → Owner independently verifies money. If the
HTTP outcome is unknown, the first transaction may still commit. Reload/new tab
resets the page guard; another accepted call creates another UUID. Duplicate
provisional requests are the confirmed missing protection. Duplicate payments
or attendance from that browser reproduction are **not established**.

## 2. Recommended contract and guarantee

Recommend a **versioned creation/recovery API with a durable, unique capability
digest**, plus an atomically shared browser operation slot. Keep the server's
request UUID and Owner confirmation operation UUID unchanged and separate.

The guarantee is: **within a supported contract version, one accepted capability
and canonical payload can commit at most one provisional request; retries can
recover that request without creating payment or attendance**. This is not an
exactly-once delivery guarantee. Errors can leave the caller uncertain.

Different random keys represent different business operations, even if payloads
match. Anonymous access cannot establish that two independent keys/devices belong
to one person. Do not deduplicate all cash requests, introduce member identity
requirements for walk-ins, or claim one walk-in per person/day. An attacker can
always generate new keys; abuse controls remain mandatory.

### 2.1 Identifiers, ownership and canonical payload

| Item | Proposed definition |
| --- | --- |
| Recovery capability K | Browser Web Crypto generates 32 random bytes before any creation dispatch; canonical unpadded base64url is exactly 43 characters. Validate alphabet, length and decode/re-encode equivalence, not length alone. No user-chosen identifiers or fallback to weak randomness. |
| Operation identity | Pair `(contract_version, SHA-256(domain || decoded K))`; fixed domain bytes `gymforce:walkin-recovery:v1` followed by a zero byte. Hash raw bytes, not differently encoded strings. The version namespace is fixed by the reviewed endpoint, not arbitrary client input. |
| Authorization | Possession of K authorizes only a bounded lookup/replay for this operation. It proves neither a person's identity nor Owner authority. Public project keys, Origin and request UUID are not recovery authorization. |
| Business request ID | Existing server-generated UUID, never chosen by the public caller. One-to-one with the operation record. |
| Owner operation ID | Existing independently validated confirmation/receipt operation UUID; never derive it from K or accept K as payment authority. |
| Payload | Only the typed paymentMethod enum. Reject extra fields, including actor, fee, currency, dates, requestId and client payload hashes. |
| Canonical bytes | UTF-8 ASCII `gymforce:walkin-create:v1\npaymentMethod=<enum>\n`, where `\n` means a single LF byte, not backslash+n. No whitespace/case normalization of enum values; no generic JSON serialization dependency. |
| Fingerprint | SHA-256 of those canonical payload bytes, derived in trusted SQL from the typed method/version. Edge may independently compare, but a client digest is never authoritative. Store/compare typed fields as well as digest. |

K is a bearer secret: never place it in the entrance QR, URL/query/fragment,
analytics, logs, audit details, error messages, screenshots or public references.
Transmit it only in bounded HTTPS POST JSON. Edge hashes K before RPC dispatch;
the database stores the fixed-size digest, not plaintext K. Protect diagnostic,
request-body tracing and error tooling from capturing K. Hashing a high-entropy
capability is not a substitute for TLS or strict authorization boundaries.

Changing paymentMethod after dispatch is a payload conflict, not a correction.
Changes to fee/version/configuration after first commit cannot change the saved
snapshot. A transport retry always retains K, contract version and original method.

### 2.2 Proposed private schema and privileges

One new private table, proposed name `private.walkin_creation_operations`:

- Primary key `(contract_version, capability_digest)`; supported version and
  exact 32-byte digest checks; method enum check, immutable canonical fingerprint.
- `request_id` NOT NULL UNIQUE FK to `private.walkin_requests(id)` ON DELETE RESTRICT.
  Existing request holds fee/time snapshot; do not duplicate editable response JSON.
- `created_at` NOT NULL server timestamp matching the request creation time.
  Response eligibility ends at the existing request's expires_at; no extra public
  recovery duration is assumed. Terminal request states also close public access.
- Immutable identity/request binding with no public update/delete path. Creation
  RPC inserts request and operation in one transaction; no committed half-link.
  No persistent in-progress status, queue, additional sequence or payment table.
- Primary/unique indexes above suffice for replay and Owner request lookup.
  Add retention index only after a reviewed deletion policy exists; no purge job
  is proposed now. Version/digest collisions must refuse, never overwrite.

Intended owner is restricted `gym_data_owner`; ENABLE and FORCE RLS, no browser
or direct service-role table/column grants, no schema CREATE or executor membership
expansion. Narrow public executor SELECT/INSERT columns and command policies serve
only reviewed SECURITY DEFINER RPCs with empty search_path and qualified objects.
Only service_role may EXECUTE those API RPCs; deny PUBLIC/anon/authenticated and
unexpected inherited execution. Owner lookup uses the Owner executor, verified
actor and separately scoped SELECT. No Owner access to plaintext capabilities.
Existing public executor rights are already bounded server duties, not browser
identities; a policy testing CURRENT_USER is not end-user authorization.

If append-only protection needs a trigger, use a reviewed invoker helper and
explicit ACLs; do not grant public UPDATE/DELETE to implement it. No new reserved
role or extension is required by this proposal. Actual creation/ownership/default
ACL authority still depends on unresolved A02/A03: **no runnable DDL authorized**.

### 2.3 Atomic creation/replay algorithm

Propose `api.public_create_walkin_request_v2` and a separate bounded lookup RPC.
Names/signatures are reserved design suggestions, not installed overloads.
All calls go to the primary transactional path, not an eventually consistent cache.

1. Edge validates exact origin, POST body bounds, approved version, capability,
   method, feature/config and both abuse budgets before dispatch. No fallback to
   the old RPC on any error. Strict CORS preflight stays before unrelated config;
   this does not authorize POST or stop non-browser attackers.
2. SQL validates typed inputs/digest lengths and acquires a transaction advisory
   lock derived from operation version/digest. A unique key remains the correctness
   backstop; advisory hash collisions only serialize unrelated work.
3. Use a fresh SQL statement/snapshot after acquiring the lock at READ COMMITTED.
   Declare the proposed mutating PL/pgSQL entrypoint VOLATILE; do not mark the
   synchronized lookup STABLE/IMMUTABLE or rely on a pre-lock cached snapshot.
   If an operation exists, compare version, method and fingerprint. Conflict
   returns no request data; matching operation returns its eligible original
   snapshot, or generic closed result. Never inspect the current fee to reprice it.
4. Only for an absent operation, acquire existing global creation-rate lock then
   fee lock in that order, select server clock/fee after waiting and enforce the
   rolling creation limit. Insert rate event, request and binding in one RPC
   transaction. Request expiry is server creation time + exactly 15 minutes.
5. Commit all business rows together. A rollback removes all three inserts;
   transaction locks release. Unique-constraint or unexpected-state failure must
   abort safely, not swallow errors and start a new operation. No autonomous
   transaction, client-side transaction or Edge-memory deduplication.

All relevant paths must share the documented lock ordering. Lookup may take the
operation lock to observe an in-flight creation's commit/rollback, but must not
acquire fee/request locks in reverse order. Owner confirmation continues to lock
its own operation then request and must not start acquiring the new operation
lock. Verify a complete lock graph in implementation; test timeouts/deadlocks.
Do not rely on a single INSERT ON CONFLICT DO NOTHING plus same-statement read
to observe a concurrent row. Different isolation levels/serialization errors
must fail safely; same-key retry cannot silently become a new-key operation.

The database transaction ends before Edge can guarantee delivery. A malformed
RPC result, HTTP timeout, client abort or connection loss can follow commit.
Treat these as unknown outcome and retain K. A lookup observing no committed row
does not promise an earlier dispatch cannot still arrive later; only same-key
retry is safe. It must never unlock automatic creation under a different key.

### 2.4 Proposed HTTP contract

Proposed new endpoint: `public-walkin-recovery`, POST actions:
`{action:"create", capability:K, paymentMethod:<enum>}` and
`{action:"lookup", capability:K}`. Reject all extra properties. This is an
explicit public API change needing approval; the current parser accepts neither.
Service-only lookup RPC takes only the fixed version/digest, never a bare UUID.

| HTTP / classification | Meaning and permitted response | Client action |
| --- | --- | --- |
| 201 / PROVISIONAL_CREATED | First committed request; allowlisted id, exact-decimal feePhp, PHP, original method, createdAt/expiresAt only. | Show provisional reference; explicitly not payment/attendance confirmation. |
| 200 / PROVISIONAL_RECOVERED | Matching retry or lookup while original request is pending and unexpired; same original fields. | Restore reference without creating another operation or extending expiry. |
| 409 / OPERATION_CONFLICT | Existing key with different typed payload/fingerprint; no snapshot or original payload returned. | Keep operation locked; Owner review; no automatic rotation. |
| 410 / RECOVERY_CLOSED | Existing operation is expired or request no longer pending. Same generic class for terminal reasons; no payment/status/attendance details. | No reuse, revival or inference of actual payment; Owner review before any deliberate replacement. |
| 404 / NO_RECOVERABLE_OUTCOME | Valid-key lookup found no binding after synchronization. Same response for random/unknown key; no listing or bare-ID fallback. | Retain same K; no proof that a delayed request cannot commit. Manual same-key create retry only under the approved protocol. |
| 400 / INVALID_REQUEST | Malformed/unsupported input; no business operation. | Correct only undispatched input; after uncertain dispatch preserve original operation for review. |
| 429 / REQUEST_UNAVAILABLE | Abuse budget exceeded; no original snapshot disclosed. | No automatic retry or new key. Respect bounded backoff guidance; Owner assistance if uncertain. |
| 503 / REQUEST_UNAVAILABLE or transport/malformed response | Configuration, gate, database or response failure; commit state may be unknown. | Retain K/method, show uncertain outcome, offer explicit lookup; never claim no request exists. |

All response classes use no-store, no sensitive cache/telemetry, bounded shapes,
and exact-origin CORS. A closed result may reflect expiry or another terminal
condition; it must not claim the visitor paid or checked in. Public lookup returns
no member identifier, Owner actor, receipt/payment ID, evidence, audit data,
confirmation time, attendance status or list of other operations. The request
snapshot is provisional even if subsequent Owner processing races with delivery.
Server confirmation is always authoritative. No public cancellation API.

### 2.5 Expiry, retention and replacement

The approved 15-minute lifetime is unchanged. Retries/lookup do not extend it or
rewrite fee, currency or method. Public snapshot access is limited to pending,
unexpired requests. After closure the operation identity must still block reuse.

**Do not delete accepted key bindings while that contract version accepts new
creation.** Deleting a digest permits an old key to create again. A response TTL
is not a deduplication TTL. Keep digest/request binding as a replay tombstone,
with business-history retention and Owner-approved restricted custody. Eventual
purge requires both approved record retention and retirement of the accepting
version (no remaining create route/RPC path), with recovery impact reviewed.
Clients must not migrate a pending key into a new version namespace.

This is a retention decision, not authorization for indefinite storage. If the
Owner requires a finite deduplication horizon on a still-active version, revise
the design before implementation: for example, server-issued authenticated
expiry-bearing capabilities and reviewed signing-key rotation/issuance controls.
Client timestamps alone cannot prevent post-purge replay. That alternative adds
issuance, key-custody and rollout complexity and is not implicitly approved here.

An unbound key has no trusted issuance time; its first successful arrival creates
at that server time/current fee. UI must not redispatch old queued work. Never
queue public submissions offline. A delayed first dispatch remains possible;
once dispatched, replacement needs reconciliation, not a client claim of failure.
A new visit/replacement is deliberate user/Owner action with a new key after
the previous operation is resolved. Expired requests never revive; replacements
use current fee and a new server UUID. Lost keys cannot be reconstructed from
identity guesses. A safe automatic replacement policy is outside this contract.

## 3. Frontend recovery and cross-tab coordination proposal

Requires explicit Owner approval for minimal bearer-capability browser storage.
Use one origin/project/version-scoped IndexedDB active-operation slot. In a single
readwrite transaction, read existing slot or allocate K and save K, version,
method and minimal dispatch state **before** any network dispatch. Never use
localStorage read-then-write as a concurrency lock. Request UUID/fee, personal
details, PINs, payment/attendance responses and Owner session tokens do not belong
in this slot. Do not put the slot into service-worker caches or sync queues.

All tabs use the existing active slot and frozen method; a conflicting selection
must prompt recovery/review, not create another key. Notifications may use a
non-secret change signal; tabs re-read the transactional slot. Do not broadcast
K. After reload, explicitly recover the active operation; do not auto-create.
Use manual same-key retry only after validated server support, never blind
payment retry. Marking a local timeout cannot prove cancellation on the server.

If storage/crypto is unavailable, quota fails or slot persistence cannot be
confirmed, block dispatch and refer to the Owner. Do not fall back to the current
volatile guarantee while advertising reload protection. Do not automatically
clear a pending/uncertain slot, on sign-out, worker update or elapsed device time.
Cleanup/new-operation policy requires server closure and deliberate review.
Multiple people sharing one browser will share the active slot: do not assume
this proves they are one person. Owner-assisted resolution must handle kiosks.

Same-key requests from another device recover the same provisional request if
the capability is privately supplied; public sharing/export is not proposed.
Independent devices/profiles or cleared browser storage can generate independent
keys and still duplicate a person's intended operation. Incognito contexts,
storage eviction, XSS and physical access to a shared browser are explicit limits.
Capability storage discloses its provisional snapshot to that browser's users;
Owner privacy approval is mandatory. No client can enforce per-person uniqueness.

## 4. Threat model and abuse controls

| Threat | Required control / residual limitation |
| --- | --- |
| Guessing and enumeration | 256-bit entropy, strict canonical decoding, hashed storage, no UUID-only lookup/list; generic unknown/closed outputs. Brute-force and timing abuse still need ingress budgets. |
| Stolen capability / replay | TLS, no logging/URL/referrer leakage, restricted browser storage, no-store; possession permits only that provisional snapshot before closure. Cannot approve money, change method or bypass expiry. XSS/device access remains a bearer-secret risk. |
| Same key/different payload | SQL canonicalization and typed comparison under operation lock, generic conflict; never overwrite binding. |
| Concurrent tabs/devices | Database unique identity plus atomic transaction; browser atomic slot prevents accidental fresh-key races only in the same storage context. Different keys remain different operations. |
| Request flooding / hot key | Body bounds and approved global ingress budgets for every create/lookup/replay, bounded operation-lock waits and response sizes; creation budget for genuinely new requests. Replays must not consume another creation quota event. No trusted forwarded-IP assumption. |
| Limiter rollback | Existing rolling events are transactional; rejected/rolled-back calls do not reliably leave durable attempt counts. Do not call that an ingress DoS defense. Qualify separately supported ingress or bounded limiter design before release; unknown provider capability remains a blocker. |
| Unauthorized SQL / grants | Server-only RPC, table deny, FORCE RLS, exact defaults/effective ACL tests, qualified empty-search-path routines. CORS and public Auth keys are not authorization. |
| Duplicate receipts / attendance | Creation/recovery never touches financial or attendance tables. Retain Owner operation replay, allocation uniqueness, final guards, expired receipt review and append-only correction/void rules. Separate actual receipts must not be discarded as transport duplicates. |
| Cleanup / key reuse | Preserve binding tombstones until accepting version retired; no automatic purge/re-key, no resurrecting expired request. |
| Public audit flooding | Do not append full audit events for every replay/invalid key. Use sanitized aggregate operational counts; no K/digest in logs. Existing privileged audit events remain append-only. Any new creation audit event must use a reviewed narrow append path and commit atomically, never a new broad public audit grant. |

Owner reconciliation stays on verified Auth → Edge → active-Owner RPC. Request ID
is a reference, not proof of payment or identity. Owner reviews actual evidence,
records reasons/evidence for corrections, and preserves original requests,
receipts, allocations, attendance and audit events. Without a key/reference,
anonymous attribution can remain uncertain; never guess, delete duplicates,
silently merge/reallocate, waive payment, revive expiry or issue refunds.

## 5. Acceptance specification — all cases NOT RUN for this proposed contract

Use synthetic data in an already authorized isolated PG17 environment. Assert
actual committed rows independently of mocked HTTP responses. Let O=operation
binding, W=request, L=creation limiter event, P=payment, A=attendance. Counts below
are operation-scoped deltas excluding unrelated traffic/limiter expiry cleanup.
Capture original hashes/finance/audit/history before fault cases; database
migration metadata must never change during business-operation tests.

| # / case | Stimulus and expected response | Required persisted state / assertions |
| --- | --- | --- |
| 1 First valid submission | New K/method with available fee and budgets → 201 PROVISIONAL_CREATED. | O=1,W=1,L=1,P=0,A=0; UUID server-generated; PHP/fee version immutable; exactly 15-minute lifetime. |
| 2 Identical retry | Same K/method before closure → 200 PROVISIONAL_RECOVERED, original snapshot even after fee changes. | Still one O/W and one creation event; no added P/A/audit replay event; typed fingerprint unchanged. Test all methods. |
| 3 Conflicting payload | Same K with changed method → 409, no original payload/snapshot leaked. | O/W unchanged, no extra creation event/P/A; replay original method still works. |
| 4 Concurrent submissions | Two independently connected SQL transactions, same K/method, barrier before insert. | One 201 and one 200 after serialization; one O/W/L. Conflict variant returns 409 for loser. Force timeout variant leaves no partial binding. |
| 5 Two tabs | Race slot allocation before dispatch in two real browser targets; race different method selections too. | Both use one stored K or second blocks/conflicts; database has one O/W/L. Deliberately different K proves documented residual risk, not a false dedupe PASS. |
| 6 Reload | Reload before response and after commit; re-open persisted slot then lookup. | Same K retained, no automatic create/new key; recovered original or explicit unknown. Existing O/W remains one. |
| 7 Network loss before commit | Drop transport before DB receives request; separately drop after transaction starts then rollback. | No O/W/L after proven rollback, P/A=0; UI remains uncertain until recovery; manual same-key retry may create once. A delayed original arriving later must replay, not add another W. |
| 8 Network loss after commit | Commit SQL, discard response at Edge/network boundary, lookup and retry. | O/W/L=1; recover original; no new P/A. Malformed Edge-success variant must also recover safely. |
| 9 Server timeout | Hold operation/rate lock; test statement cancellation before commit and HTTP deadline after commit. | Before commit rollback=0 new business rows; after commit=1 O/W/L. Same generic uncertain UI; no assumption abort cancels commit, no new-key retry. |
| 10 Transaction rollback | Inject failure after request insertion and after binding insertion, before commit. | O/W/L all absent for attempt; original finance/member/audit hashes and migration history unchanged; locks released, same-key retry succeeds once. |
| 11 Expired recovery | Retry same K at/after expires_at and after terminal Owner processing; test request row still marked pending but clock expired. | 410 generic closed, no snapshot/payment detail; old O/W retained, no new L/P/A, no repricing/revival. Purge safeguards refuse removal on an active version. |
| 12 Unauthorized lookup | Missing/malformed/random K, bare request UUID, browser direct RPC/table, another key, wrong Origin, disabled gate/missing config. | Generic 400/404/403/503 as applicable; no target snapshot or mutation. Effective inherited ACL/default tests deny unauthorized SQL execution. Valid stolen K scope limited as documented. |
| 13 Owner reconciliation | Non-Owner/deactivated/forged actor denied; verified Owner resolves with actual receipt evidence using existing flows. | Public lookup never confirms payment; original records preserved, reason/evidence audit retained. Unknown attribution remains review, no invented historical facts. |
| 14 Rate limits | Flood new keys, replays, unknown lookups, simultaneous hot-key calls and shared network. | Creation budget bounds W/L; ingress budget bounds all classes; replay adds no creation event. Missing limits fail closed; limit rollback behavior explicitly observed; no unapproved thresholds. |
| 15 Payment/attendance uniqueness | Recover/create retries interleave with two Owner confirmations, allocation, void and request expiry. | One allocation and one attendance per W; same Owner operation replay adds no receipt. A genuinely different receipt is preserved in review, never silently deleted. Recovery adds no P/A; no unverified income/access, no expired revival or silent restoration after void. |

Also test 32-byte canonical encoding edge cases, extra fields, cross-version
pending operation, digest/typed mismatch refusals, fee/config absence, fresh and
retired-version behavior, stale PWA clients, storage failure/eviction, method
changes, offline no-dispatch, response allowlists, exact cents and server clocks.
Use SQLSTATE/category assertions without logging tokens, records or raw errors.
Deadlock, cancellation and lost acknowledgement outcomes must be reconciled from
the known isolated transaction/session, never inferred from one HTTP status.

## 6. Forward implementation and rollout gates

| Workstream | Proposed deliverable and dependency | Acceptance gate |
| --- | --- | --- |
| Database | New forward migration after reconciled final source, table/constraints/immutable guards, create/lookup RPCs, exact grants/policies. Do not edit the 37 historical files or silently substitute compatibility variants. | A02 authority accepted and independently verified; A03 defaults/effective grants accepted; A04 legacy and A07 object/history drift reconciled; unchanged final financial/audit invariants. |
| Edge | Versioned bounded parsers, capability hashing, allowlisted classifications, no-store/log hygiene, feature and ingress controls. | Real handler negative tests including CORS/config gates; no v1 fallback or broad RPC grants. |
| Frontend | Atomic persistent slot, recovery UI, frozen dispatched payload, explicit same-key retry, safe deliberate replacement policy. | Owner privacy/storage approval; actual two-tab/reload tests and failure injection. No offline create queue or automatic payment retries. |
| Automated tests | Unit canonicalization/parser tests; real SQL races/rollback/ACL suites; actual handler serialization and redaction tests. | All 15 cases with database-state assertions; existing A05/A06/PIN/PWA suites preserved. |
| Integrated acceptance | Existing authorized isolated Auth/Edge/PostgREST/browser stack with synthetic records, real transport loss and Android acceptance. | Independent committed-row checks; fixtures alone cannot qualify end-to-end delivery/recovery. Any missing infrastructure requires separate authorization, not silent provisioning. |
| Release | Reviewed artifact hashes, explicit old-route retirement, supported source/bundle/frontend versions, traffic controls, backup and recovery plan. | Separate Owner approval for each hosted diagnostic, mutation/configuration/migration and deployment scope. Nothing executes under this document. |

Stage new schema and bundles with feature gates closed; verify final stage-aware
ACL/RLS/owners, exact migration runner commit/history semantics and rollback
behavior first. Do not grant temporary authority here. New fingerprints belong
in a separately reviewed manifest, not edits to approved diagnostic contracts.

Before opening v2, disable/retire legacy creation through **all** entry paths,
including old Edge bundles, stale PWA assets and service-only old RPC callers.
Leaving an unkeyed v1 creator reachable preserves the original vulnerability.
Review explicit v1 denial/revocation/config changes separately; never silently
change the existing function's signature or claim the browser update notice
forces every client to upgrade. An old client must receive safe unavailable
feedback, not an unkeyed fallback. In-flight old operations need quiescence and
Owner reconciliation before opening new creation. Legacy requests retain
original references/history; do not fabricate recovery keys for them.

Recovery/backout: keep gates closed on any mismatch. Before migration commit,
verify same-session rollback/lock release. After commit or lost acknowledgement,
freeze blind reruns/history repair and reconcile committed schema/history under
separate authorization. Do not drop committed operation bindings or business
records to roll back application code. An older app cannot regain unkeyed create
access as a rollback shortcut. Prefer reviewed forward repair; restore only
under an Owner-approved, tested backup/RPO/RTO plan preserving key custody and
post-backup financial evidence. No generally safe destructive down-migration
is assumed. Recovery APIs may be unavailable during a gate closure; retain K
and use Owner review rather than inventing success.

## 7. Owner decision register

All entries below are **PENDING**, with no approval implied by this design.

| ID | Exact decision / consequence |
| --- | --- |
| D60-01 | Approve operation-scoped, not per-person, idempotency and versioned API/schema scope. Different keys/devices can still create distinct provisional requests. |
| D60-02 | Approve bearer capability privacy model, minimal IndexedDB retention/access/disposal, shared-browser handling and lost-key/new-operation review procedure. Without approval, do not add durable browser storage or promise reload recovery. |
| D60-03 | Approve tombstone retention until accepting version retirement and business retention review; otherwise commission authenticated expiry-bearing issuance design. Deleting active-version identities is unsafe. |
| D60-04 | Approve public snapshot access ending at pending-request expiry/closure, generic negative classifications and manual recovery policy. No payment-status public lookup. |
| D60-05 | Approve tested ingress/creation budgets, time/lock bounds, operational monitoring and provider feasibility. No production values or paid service assumptions are selected here. |
| D60-06 | Resolve A02 separately; verify hosted actor/grant authority and final cleanup, defaults/RLS, legacy/data/audit compatibility and migration history. Local synthetic PG17 success cannot waive these gates. |
| D60-07 | Approve reviewed forward artifacts/hashes and old-route retirement, recovery/backup/maintenance procedures, then separately authorize execution and deployment. No implementation or release authorization is supplied now. |
| D60-08 | Approve synthetic integration/hardware resources if existing isolated infrastructure cannot support acceptance. Physical Android and full persisted HTTP workflow acceptance remain outstanding. |

## 8. This milestone's verification and recommendation

Source-level verification: traced current browser/parser/Edge/RPC/confirmation
and final allocation rules, compared the existing Phase 5.8/5.9 evidence, and
specified all 15 acceptance cases. The proposed mechanism does not already exist.
No SQL, HTTP or runtime regression suite was executed for a documentation-only
change. Earlier test counts remain historical, not Phase 6.0 contract PASS.
Local document verification PASS: all 15 acceptance rows are present, 12 explicit
path-and-line references resolve within existing files, and `git diff --check`
succeeded. Git still reports pre-existing Windows line-ending conversion notices;
no normalization was performed. SHA-256 comparison of the 35-file starting dirty
inventory confirms the other 34 files are byte unchanged. The progress file's
entire original 21,458-byte prefix and UTF-8 BOM are preserved; only the Phase 6.0
entry was appended. Both approved M1/M2 hashes remain unchanged. No historical
migration diff exists. Final inventory is 8 tracked edits and 28 untracked files;
only this report and the progress append belong to Phase 6.0.

**Design status: ready for Owner review, conditional on D60-01–D60-08.**
Implementation, contract runtime acceptance, hosted compatibility and physical
Android acceptance are NOT VERIFIED. Existing lost-response/global recovery
limitation remains unresolved until implementation and real persisted tests pass.

Recommend Owner review of D60-01–D60-04 first: they determine the API, retained
identity and browser privacy contract. Only after explicit scope approval should
local forward implementation begin. This is an implementation-ready proposal,
not permission to write/apply migrations or change current public behavior.
**Production remains NO-GO.**
