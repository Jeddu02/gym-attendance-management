# Phase 6.0A - Public-request recovery Owner decision package

2026-11-19, Asia/Manila. Existing GYMFORCE repository, `master`, baseline
`ad41b7988d0d9fc4a56e675aeaff9b613878cdda`.

**DECISION PACKAGE ONLY. All approvals are PENDING.** No proposed contract has
been implemented. A02 continuing-ADMIN authority remains **PENDING OWNER
DECISION**. Production remains **NO-GO**.

## 1. Executive summary and controlling evidence

Recommend accepting Decisions A1, B1 and C1 below for a separately authorized
local implementation. They provide operation-scoped replay protection, minimal
browser capability persistence and retained server replay evidence. They do not
identify anonymous people, prove payment, or authorize production work.

The controlling design is [the Phase 6.0 contract](GYMFORCE-PHASE-6-0-PUBLIC-REQUEST-RECOVERY-CONTRACT.md),
especially sections 2-5. This package consolidates its decisions; it does not
replace its canonical byte formats, transaction rules or 15 acceptance scenarios.
Also reviewed [the Phase 5.9 audit](GYMFORCE-PHASE-5-9-COMPLETE-SYSTEM-AUDIT.md)
and [development progress](GYMFORCE-DEVELOPMENT-PROGRESS.md).

| Verified source | Fact relevant to the decision |
| --- | --- |
| `src/components/EntrancePage.tsx:80` | Current in-memory attempt lock prevents repeated dispatch only within the mounted page; reload/new tab can start again. |
| `supabase/functions/_shared/walkin-request.ts:54` | Public input currently permits only paymentMethod; a key would require an explicit new API contract. |
| `supabase/functions/public-walkin-request/index.ts:38` | Calls the unkeyed creation RPC; response validation can fail after the RPC committed. HTTP failure does not prove rollback. |
| `supabase/migrations/20261110140000_walkin_operations.sql:261` | Accepted calls each create a server UUID, immutable fee snapshot and 15-minute request. Rate/fee locks do not deduplicate operations. |
| `scripts/test-browser.mjs:220` | Existing two-tab/reload reproduction counts dispatched requests under synthetic HTTP fixtures; it does not prove duplicate database commits. |
| `supabase/functions/_shared/walkin-request_test.ts:25` | Existing tests expressly reject public operation/fee/identity overrides; preserve these for the old contract rather than silently broadening it. |

No SQL, network call or runtime suite was run in this documentation milestone.
Previous local PG17/handler/browser results remain historical and do not validate
the unimplemented recovery mechanism or actual hosted authority.

## 2. Decision A - Versioned API and server-enforced operation identity

### Recommended option A1

- Generate capability K before dispatch: 32 cryptographically random bytes,
  canonical 43-character unpadded base64url; reject invalid decode/re-encode,
  alphabet, length and extra fields. Existing business request UUID stays
  server-generated; Owner confirmation retains its separate operation UUID.
- Scope identity to the fixed reviewed contract version and domain-separated
  SHA-256 digest of decoded K. Store no plaintext K in SQL. Keys identify
  operations, not people, browsers, payments or membership entitlements.
- Only paymentMethod is public business input. SQL computes the canonical
  fingerprint from the typed method/version using the Phase 6.0 LF-delimited
  bytes. Do not accept a client-supplied fee, actor, timestamp or fingerprint.
- A new private operation binding, request and creation-rate event commit
  together. Unique digest identity and unique request binding are mandatory.
  Key-scoped transaction serialization precedes existing rate/fee locks; use
  fresh statements/snapshots and fail safely on conflicts/timeouts. No partial
  committed reservation or Edge-memory deduplication is sufficient.
- Same key and same payload recovers the original eligible snapshot, including
  its original fee/version/time. Same key and different payload never overwrites
  it. Concurrent identical requests converge on one committed request.
- A lost response, client abort, timeout or malformed success retains K and the
  original method. Explicit lookup/manual same-key retry is available only after
  server enforcement is proven. No automatic key rotation or payment retry.
- Proposed `public-walkin-recovery` accepts bounded POST create/lookup actions;
  fixed version is a route/server decision. Lookup requires K, not a bare request
  UUID. API/public project keys and Origin are not end-user authorization.
- Use server-only API RPCs, restricted executors, FORCE RLS, empty search paths,
  explicit effective ACL checks and no direct service/browser table grants.
  Preserve exact-origin OPTIONS behavior, POST feature/config gates and A05/A06.

| Classification | Public meaning / disclosure |
| --- | --- |
| 201 PROVISIONAL_CREATED | First commit; provisional id, exact-decimal feePhp, PHP, method, creation and expiry timestamps only. |
| 200 PROVISIONAL_RECOVERED | Same original snapshot while pending and unexpired; no new request or creation quota event. |
| 409 OPERATION_CONFLICT | Same key with changed payload; no original snapshot/payload disclosure. |
| 410 RECOVERY_CLOSED | Expired or terminal request, same generic response; never say payment/attendance succeeded. |
| 404 NO_RECOVERABLE_OUTCOME | No binding observed by synchronized lookup; does not prove an earlier delayed dispatch cannot later commit. Never authorizes a fresh key automatically. |
| 400 / 403 / 429 / 503 | Invalid input / rejected Origin / rate control / unavailable or uncertain outcome. Keep generic safe errors; no database details. |

Public output must omit member data, Owner identity, receipt/payment IDs, payment
status, evidence, attendance outcomes and audit records. No-store on every
response; no sensitive request tracing. Possession of K permits only its limited
provisional recovery. It does not confirm actual payment or authorize attendance.

API versioning is a release prerequisite: stale PWA clients must fail safely.
Retire every unkeyed creation route/RPC path before opening the new contract;
no silent fallback or signature replacement. Quiesce/reconcile old in-flight
operations; retain legacy requests without fabricating keys. Pending operations
cannot be automatically reissued into another version namespace.

### Alternatives and tradeoffs

| Option | Benefit | Cost / decision consequence |
| --- | --- | --- |
| A1: capability-based create/lookup | Direct recovery after commit-response loss; minimal anonymous input; database-enforced same-key protection. | New reviewed schema/API/client contract, bearer privacy and retention obligations; no different-key person-level deduplication. |
| A2: Owner-mediated registration; keep public creation unavailable | Avoids a new public recovery surface while preserving manual verification. | Changes operating workflow and requires separate Owner policy/UI approval; no self-service recovery. Does not automatically accept existing uncertainty as safe. |
| A3: server-issued authenticated expiry-bearing capabilities | Can enforce a trusted finite key-acceptance horizon, supporting a different retention design. | Additional issuance flow, signing-key custody/rotation and failure/race tests; Phase 6.0 design must be revised before implementation. |

### Exact proposed approval wording A

> I select A1 and accept the Phase 6.0 operation-scoped, versioned API design:
> one accepted key/payload binds atomically to at most one provisional request;
> matching retries recover its original eligible snapshot, conflicts refuse,
> and lookup requires the capability. I accept that different keys can represent
> duplicate intended visits. Public recovery never confirms payment or attendance.
> I require retirement of unkeyed creation before release. This accepts the
> design only; implementation requires the separate local authorization below.
> No production action or A02 authority approval is granted.

## 3. Decision B - Capability ownership, storage and lifecycle

### Recommended option B1

Use Web Crypto and one IndexedDB active-operation slot scoped to the existing
origin/project/contract version. One readwrite transaction reads/reuses the slot
or creates/persists K before dispatch. Freeze the method once dispatched. Two
tabs in that storage context must use the same slot or stop on a method conflict;
localStorage check-then-set is not an acceptable substitute.

Persist only K, version, selected method and minimal local dispatch/review state.
No saved fee/reference response, PIN, mobile/member identity, Owner session,
receipt, payment or attendance record. The selected method is still user-linked
preference data in this context and needs privacy review. IndexedDB is not a
secret vault: same-origin scripts, XSS or another person using the browser can
access K. Do not claim encryption at rest or browser isolation from its own users.

After reload, recover the active slot explicitly; do not create automatically.
Use non-secret change notifications and re-read the slot, without broadcasting
K. No service-worker/API cache, Background Sync or offline submission queue.
No token in URLs/QR codes, logs, analytics, exception traces or screenshots.
Use HTTPS and bounded POST bodies. Hash K before service RPC dispatch and keep
digests out of public output/operational logs as well.

Storage/crypto failure, quota error or failed persistence blocks creation and
directs the visitor to the Owner. No weak random fallback or volatile-only
dispatch advertised as durable recovery. Clearing storage, separate profiles,
private browsing or devices break shared-slot coordination; the limitation must
be visible. No cross-device transfer/export UI is approved by B1.

**Expiry and revocation:** the server stops snapshot disclosure at request
expiry or terminal state, but keeps replay identity. The client must not delete
or rotate an uncertain active key just because its local clock elapsed. Retire
the browser slot only after authoritative closure and deliberate Owner-assisted
resolution/new-operation handling; a generic closed result does not prove money
was received. No fixed client retention period has been approved.

B1 does not add a public selective revocation/cancellation endpoint. If K is
stolen, its scope remains provisional-only; the Owner may request separately
authorized operational containment, including gate closure. Neither deleting
the browser slot nor changing K revokes a copied key. A requirement to revoke
individual pending capabilities before expiry needs a separately reviewed
lookup-disable design that preserves request, tombstone and financial history;
do not invent a terminal business state or change attendance to achieve it.

Shared-browser reuse needs deliberate Owner review: a slot is not an identified
person. Do not silently let the next visitor view another visitor's reference
or assume clearing a slot proves no request exists. Recovery and local cleanup
must be explained in the privacy notice and synthetic kiosk tests.

### Alternatives and tradeoffs

| Option | Benefit | Cost / decision consequence |
| --- | --- | --- |
| B1: minimal durable IndexedDB slot | Reload and same-storage-context tab coordination without storing business responses. | Bearer-secret persistence, shared-browser exposure and lifecycle policy; eviction remains possible. |
| B2: memory/session-only handling | Less persistent bearer material. | Cannot satisfy cross-tab/reload recovery; only viable with explicitly accepted Owner-mediated operating fallback, not as a PASS for this objective. |
| B3: server/session-bound transport | Potentially avoids JavaScript-readable capability storage. | Cookie/session/CSRF, expiry, browser compatibility and anonymous binding architecture require a new design. No existing secure cookie/session contract is assumed. |

### Exact proposed approval wording B

> I select B1 for a minimal origin/project/version-scoped IndexedDB capability
> slot, atomically persisted before dispatch. I accept the disclosed same-origin,
> shared-browser, theft and eviction limitations. No personal, PIN, payment or
> attendance records may be persisted there; unavailable storage must block
> submission. Unknown operations must not be silently cleared or re-keyed.
> Public snapshot access closes at expiry/terminal outcome; no public selective
> revocation or cross-device export is approved. I require the described
> Owner-assisted cleanup and privacy review before release. This is design
> acceptance only, not implementation or production authorization.

## 4. Decision C - Recovery availability and replay-evidence retention

### Recommended option C1

Separate three lifecycles rather than assign one arbitrary TTL:

| Record / access | Recommended rule | What remains unapproved |
| --- | --- | --- |
| Public provisional snapshot | Available only while the original request is pending and before its server expiry; existing request lifetime remains 15 minutes. Retry never extends it. | New public-disclosure policy requires Decision A/C acceptance even though the underlying lifetime is already approved. |
| Browser capability slot | Retain uncertain operation for recovery/review; cleanup only after authoritative closure and deliberate resolution. Do not queue or silently resubmit old work. | Maximum local retention, shared-browser cleanup procedure and required privacy treatment; no numerical period selected here. |
| Terminal operation digest/binding | Preserve immutable replay evidence while its contract version accepts creation, even after public lookup closes. | Production retention schedule, legal/privacy review, custody, backup interaction and terminal purge procedure. This is not approval of indefinite retention. |
| Request/receipt/allocation/attendance/audit history | Preserve under record-specific Owner-approved policies and existing correction rules. Idempotency cleanup must not cascade-delete or rewrite them. | Actual record-specific periods and legal/incident holds; no existing backup/PITR capability or period assumed. |

Removing an active-version binding makes the old key look unused and can create
another request. C1 therefore approves a **no-purge invariant**, not an arbitrary
number of days. Eventual deletion requires accepting-version retirement across
all Edge/RPC paths, no migration of pending keys into a new namespace, approved
record-specific retention, dependency review, and an authorized cleanup procedure.
Backup restore must not restore creation access without corresponding replay
evidence. A retention hold or unresolved reconciliation blocks cleanup.

For a local prototype, retain synthetic bindings; implement no automatic purge.
Production remains blocked until the Owner approves an operationally feasible
retention/disposal schedule or selects C2. If an active version may run without
a defined end, the practical storage commitment can be open-ended: explicitly
resolve that before release rather than disguise it as a short TTL.

Cleanup must be Owner-controlled, least privileged, independently reviewed and
separately authorized. Any future cleanup evidence should record actor, time,
reason, approved policy/version, aggregate counts and outcome without plaintext
keys, raw digests or personal/financial exports. Preserve privileged audit
integrity; no broad audit-append grant or per-public-replay audit flooding.

### Alternatives and tradeoffs

| Option | Benefit | Cost / decision consequence |
| --- | --- | --- |
| C1: bindings survive active contract; no purge prototype | Simple persistent same-key guarantee; does not weaken financial history. | Requires approved version retirement and retention/disposal plan before production; cannot promise a fixed short storage lifetime. |
| C2: trusted expiring issuance (A3) | A reviewed token not-after can reject old replay after a finite retention horizon. | Must define issuance, signing-key rotation, grace/clock rules and horizon through a new Owner decision; no values inferred. More schema/API/security work. |
| C3: delete bindings at 15 minutes | Reduces storage. | **Not recommended / fails the current guarantee:** request expiry alone does not prevent old raw keys creating again. Requires a redesigned guarantee and acceptance tests, not a cleanup optimization. |

### Exact proposed approval wording C

> I select C1: public snapshot recovery ends when the original request expires
> or closes, without extending its approved 15-minute lifetime. Replay bindings
> must not be purged while that contract version accepts creation. I permit a
> local synthetic prototype with no purge mechanism. I do not approve indefinite
> production retention or a new numerical policy period. Production requires my
> separate record-specific retention, custody, retirement and disposal decisions;
> if a finite active-version horizon is required, the design must be revised
> before release. Financial, attendance and audit histories remain preserved.

## 5. Different-key duplication: guarantees and residual risk

| Object/effect | Existing source protection | Adequacy across different creation keys |
| --- | --- | --- |
| Provisional walk-in registration | Server UUID and immutable snapshot; global rolling creation limiter (`20261110140000_walkin_operations.sql:261`). | **Insufficient for per-person/visit uniqueness.** Two accepted keys can produce two request UUIDs. Rate limiting limits volume, not identity. |
| Payment operation | `supabase/migrations/20261103120000_owner_membership_payments.sql:10` unique operation_id; Owner confirmation replay/typed checks at `supabase/migrations/20261110140000_walkin_operations.sql:332`. | Same Owner operation cannot create two receipts, but distinct Owner operation IDs can represent separate receipts or an accidental duplicate observation. Creation key does not solve real-world receipt identity. |
| Receipt allocation | `supabase/migrations/20261028062602_payment_ledger.sql:53` unique payment_id; `supabase/migrations/20261110140000_walkin_operations.sql:37` unique walk-in allocation. | One receipt row cannot allocate twice; one walk-in request cannot receive two allocations. Two request IDs and two receipt rows are not inherently the same actual money in the database. |
| Walk-in attendance | `supabase/migrations/20261028062706_walkin_attendance.sql:102` unique walkin_request_id, Owner receipt/request validation and final allocation checks. | One attendance row per request, not per anonymous person/day. Two distinct validly confirmed requests can produce two rows. This is not evidence of an observed production duplicate. |
| Member attendance | `supabase/migrations/20261028062706_walkin_attendance.sql:97` member/date partial unique index. | Existing one-valid-member-check-in-per-Manila-day rule is separate and must not be extended to unidentified walk-ins silently. |

The external-reference unique index in
`supabase/migrations/20261103120000_owner_membership_payments.sql:17` is scoped to
targeted membership receipts. Do not describe it as a global walk-in bank/GCash
receipt deduplication guarantee. Cash also has no inherent external transaction
identity. Existing Owner receipt record/review and final allocation flows
(`supabase/migrations/20261110160000_receipt_review_corrections.sql:118`;
`supabase/migrations/20261110190000_receipt_allocation_review.sql:72`) remain
authoritative; inspect their full final-stage guards during implementation.

Recommend these protections within the proposed contract:

1. Atomic shared browser slot and no automatic key rotation, offline queue,
   replacement or retry under a fresh key. Server constraints remain decisive.
2. Owner checks the presented reference, pending/review/confirmed history and
   actual receipt before re-entering money; retain the same Owner operation ID
   for an uncertain confirmation. Never ask the visitor to pay again merely
   because public recovery is closed or unavailable.
3. Preserve separate actual receipts in Owner review; never delete or suppress
   real money based on a fuzzy match. Apply existing reason/evidence correction,
   void and eligibility-invalidation procedures when warranted.
4. Test two distinct keys explicitly, demonstrating the residual boundary, and
   interleave their Owner confirmations with replay/allocation/void scenarios.

Stronger per-visit identity, verified bank/GCash transaction identity/uniqueness,
or Owner-assisted duplicate-candidate warnings may be justified later, but each
needs separate business/privacy definition and false-positive handling. They are
**not authorized by A1/B1/C1**. Do not silently add mobile/name collection, device
fingerprinting, IP-as-person rules, same-amount deduplication or automatic record
merging. The Owner must explicitly accept the residual risk for this scope or
request those separate designs before release.

## 6. Phase 6.1 implementation gates and acceptance

Design acceptance A/B/C and authorization to implement are distinct decisions.
This document itself grants neither. Work can be approved in bounded local
batches; a local synthetic authority fixture does not approve A02 or resolve
actual Supabase permissions.

| Gate | Exact authorization / evidence required |
| --- | --- |
| L1 - additive migration artifacts | Explicit permission to author new forward-only files/proposals and manifests, targeting the reconciled final schema. Preserve every historical migration byte and approved diagnostic hash; no automatic registration in a hosted runner or history edits. Review new names, signatures, constraints, ownership/RLS/ACL assertions and lock order. |
| L2 - Edge contract implementation | Explicit permission for new versioned handler/RPC dispatch, strict parsers, allowlisted responses and bounded limiter design. Preserve A05/A06, existing authentication, feature gates and generic errors; no v1 fallback. No production secret/config changes. |
| L3 - frontend implementation | Explicit B1 privacy/storage scope plus UI implementation permission. Atomic persisted slot before dispatch, recover-on-reload, no-dispatch on storage failure, no forced service-worker activation, no sensitive API caching and no offline public queue. |
| L4 - isolated PG17 execution | Identify the already authorized local environment, test profile and loopback-only scope; synthetic records only. Apply new artifacts there only after local test authorization, against documented baseline/final-stage inputs. No new environment, external provisioning or provider privilege emulation presented as hosted proof. |
| L5 - 15 recovery scenarios | Execute the Phase 6.0 section 5 matrix against actual committed SQL state, plus real handler/browser transport and storage tests. Use existing infrastructure; if a qualified Auth/Edge/PostgREST stack is absent, mark integration BLOCKED and obtain its own resource authorization. |
| L6 - review closure | Complete source/secret/artifact diff review; unchanged historical migrations/diagnostics and business rules; lint/typecheck/build/Node/Deno/Edge and relevant browser/security/recovery regressions actually pass. Report all failures/untested cases; no commit/push/deploy implied. |

Acceptance mapping (all **NOT RUN for the proposed contract**):

| Phase 6.0 case | Mandatory persisted-state / response evidence |
| --- | --- |
| 1 First valid submission | 201; one binding, request and creation-rate event; zero payment/attendance. |
| 2 Identical retry | 200; same original snapshot and counts, including after fee change. |
| 3 Payload conflict | 409; original binding/snapshot unchanged, no disclosure or extra request. |
| 4 Concurrent requests | Two actual SQL sessions converge on one request; conflict/timeout variants fail safely. |
| 5 Two tabs | Race browser slot allocation; one key/request or blocked conflict; different-key limitation explicitly demonstrated. |
| 6 Reload | Recover saved key without automatically creating/re-keying. |
| 7 Loss before commit | Prove no partial binding/request after rollback; delayed original and same-key retry cannot double-create. |
| 8 Loss after commit | Drop HTTP delivery; recover the one committed snapshot. |
| 9 Timeout | Distinguish canceled-before-commit from committed-but-undelivered; unknown UI never claims rollback. |
| 10 Rollback | Inject failures between inserts; zero partial rows, locks released, original finance/member/audit/history unchanged. |
| 11 Expired recovery | Generic 410; no revival, repricing, added creation event or deleted replay evidence. |
| 12 Unauthorized lookup | No bare-ID/cross-key data; malformed inputs, direct RPC/table calls, inherited grants, Origin/config gates fail safely. |
| 13 Owner reconciliation | Active verified Owner only; actual receipt/evidence and preserved correction history; no anonymous identity guessing. |
| 14 Rate limits | Bound new creates, replay/lookup floods and hot-key waits; no extra creation quota charge on replay; rollback limitations visible. |
| 15 Payment/attendance uniqueness | Creation/recovery never creates money/attendance; Owner replay, allocation, expiry and void races preserve final financial invariants. |

Actual database assertions, handler tests and browser fixtures are separate
layers. Mocked HTTP success is not a committed-row assertion. Real full-stack
and physical Android acceptance remain required before final operational
qualification. Production has additional gates: A02 acceptance/hosted authority,
A03 permissions, A04 legacy/audit/data, A07 history/object reconciliation,
approved ingress thresholds, privacy/retention, backup/restore/RPO/RTO, reviewed
artifact hashes and separate maintenance/migration/config/deployment approval.

### Optional exact local implementation authorization wording

The Owner may copy and explicitly approve this **only after** selecting the
design options and completing the fields below:

> I approve A1, B1 and C1 subject to my recorded conditions and authorize Phase
> 6.1 local-only work L1-L6: new additive recovery artifacts, versioned Edge
> contract code, frontend capability recovery, regression tests and synthetic
> execution in the named existing isolated PostgreSQL 17 environment. Preserve
> historical migrations, diagnostic evidence, current security boundaries and
> all financial/attendance business rules. Do not create another environment,
> alter the A02 trust model, connect to hosted services, modify production,
> repair history, commit, push or deploy. Missing infrastructure or unapproved
> policy values remain blockers; this does not authorize their substitution.

Existing isolated environment / profile: **Owner confirmation required**.
Operator, scope/conditions and approval date: **Owner confirmation required**.
This is proposed wording, not a record that it was approved.

## 7. Owner decision register and approval checklist

All boxes are intentionally unchecked. Accept, request revision or reject each
decision explicitly; silence and partial design acceptance do not authorize work.

| Decision | Recommended selection | Recorded Owner selection / conditions |
| --- | --- | --- |
| A - API | A1; maps Phase 6.0 D60-01 and D60-04 | **PENDING** |
| B - storage | B1; maps D60-02 | **PENDING** |
| C - retention | C1 local no-purge invariant; production schedule still gated; maps D60-03 | **PENDING** |
| Different-key residual risk | Accept operation-scoped limit or request an additional business-level design | **PENDING** |
| Phase 6.1 implementation | Separate L1-L6 authorization with exact existing test environment/profile | **NOT AUTHORIZED** |
| Abuse/runtime values | D60-05: tested ingress/creation limits and time/lock bounds | **PENDING; no numeric values selected** |
| Authority/release/operating gates | D60-06-D60-08, separate A02 decision and all hosted/resource/release approvals | **PENDING / NOT AUTHORIZED** |

- [ ] Select A1/A2/A3, or request specified revisions, using explicit wording.
- [ ] Select B1/B2/B3; accept or revise shared-browser, cleanup and revocation limits.
- [ ] Select C1/C2 or request revision; keep production retention decisions visible.
- [ ] Accept different-key residual risk or commission a separate business rule review.
- [ ] Separately approve or withhold L1-L6; identify existing test environment/profile.
- [ ] Record conditions, operator and approval date without approving production work.

Owner / authorized reviewer: **not supplied**.
Decision date/time (Asia/Manila): **not supplied**.
Conditions / selected alternatives: **not supplied**.
Signature or explicit recorded approval: **not supplied**.

No selection, signature, policy period or execution permission has been fabricated.
Even complete design/local approval leaves production migrations, roles/grants,
configuration, history changes, deployment and release prohibited until their
separate evidence and authorizations exist.

## 8. Phase 6.1 readiness and review evidence

**Package: ready for Owner decision. Phase 6.1 implementation: NO-GO pending
A/B/C selections and separate L1-L6 authorization. Production: NO-GO.**
The highest-value next action is one explicit Owner response selecting A/B/C,
accepting or revising different-key residual risk, and granting or withholding
the bounded local implementation scope. Do not repeat general readiness audits
or begin implementation from this package alone. A02 remains a separate pending
decision, unaffected by acceptance of this public recovery design.

This milestone changes only this new package and an appended progress entry.
Local documentation verification:

- `git diff --check`: PASS; existing Git CRLF-conversion notices remain, with
  no line-ending normalization performed.
- Fifteen explicit source path/line references are in bounds; relative report
  links resolve. All 15 acceptance rows and three proposed approval wordings
  are present; six checklist boxes remain unchecked and none is pre-approved.
- Starting dirty inventory: 36 files. SHA-256 comparison confirms the other 35
  existing files are unchanged, including Phase 6.0 and M1/M2 diagnostics.
  The original progress file's 23,123-byte prefix and UTF-8 BOM are preserved.
- No historical migration or Edge source diff. Final inventory: 37 dirty files
  including prior work; only these two documentation changes belong to 6.0A.

These are static documentation/work-preservation checks, not runtime acceptance.
No SQL, runtime/API/schema changes, hosted access, commit or deployment occurred.
