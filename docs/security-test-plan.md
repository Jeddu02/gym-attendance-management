# Database and security test plan

**Status:** proposed tests for the later schema/policy phase. No tests or
workflows are implemented by this document.

## Test environments and tooling

- Use a local, disposable Supabase stack with synthetic seed data after the
  database schema is approved. The current machine has no Supabase CLI,
  Docker/Podman, `psql`, PostgreSQL server tools, or registered PostgreSQL
  service, so Supabase migration, RLS, and pgTAP tests cannot run here today.
  WSL exists as a command, but its available invocation returned usage text and
  no Linux distribution/local database could be confirmed.
- Once a local stack is available, use SQL/pgTAP for constraints, RLS, role
  behavior, transition functions, local dates, and concurrency. Use endpoint
  integration tests for Edge Function authorization, PIN behavior, rate limits,
  idempotency, and response privacy. Use browser tests for public QR and Owner
  PWA behavior, including offline provisional state and service-worker cache
  inspection.
- Seed only a fake Owner/member identity, fake phone numbers, synthetic payment
  references, and deterministic test dates. Never use a live database or live
  member data. Do not grant developer automation production credentials.
- Run tests under distinct `anon`, Owner Auth, and trusted server-side
  execution contexts. Verify direct PostgREST requests as well as approved RPCs;
  a hidden button is not an authorization test.

## Authorization scenarios

| Actor | Allowed | Must be denied |
| --- | --- | --- |
| Anonymous entrance visitor | Submit an identifier + PIN to the one public check-in endpoint | Read member/plan/payment/attendance tables; look up whether an ID/phone exists; create or confirm payment; list records; call Owner operations |
| Owner | Approved management operations, payment confirmation/correction, settings, registration, walk-in confirmation, offline submission, reconciliation | Delete audit/financial history; expose service-role key; turn a provisional claim valid without server validation |
| Developer/test automation | Synthetic local fixtures only | Authenticate to production, read live member data, decrypt live PII, or use a production service-role secret |

There are no manager or front-desk actors in the initial release. `staff` in
older audit terminology, if retained as an enum, must not imply an additional
login role; Owner actions are recorded as Owner, and public member actions as
anonymous/public.

## Required test cases

### RLS and role boundaries

1. With `anon`, direct SELECT/INSERT/UPDATE/DELETE on every exposed table is
   denied. The single public endpoint returns only the allowed outcome.
2. Owner operations succeed only for the current active Owner identity. Direct
   client writes to protected tables, another actor ID, forged metadata, and
   calls made as a member identity are denied.
3. A revoked/suspended Owner identity and member identity cannot invoke
   management operations. Forged `user_metadata` or stale claims grant no
   privileges.
4. Authenticated users cannot call a `SECURITY DEFINER` function with another
   user's actor ID, change search path to shadow trusted objects, or use a
   generic SQL/table endpoint.
5. No developer account or CI credential can access a production project or
   production member table. Verify the absence of production credentials in
   local environment, browser bundle, logs, build artifacts, and automation.

### Member registration, payment, and membership expiry

7. Pending, denied, and suspended members cannot check in even with a correct
   PIN and an otherwise paid purchase. Only an authorized approval transition
   makes a member eligible.
8. A confirmed payment alone does not grant access before registration approval.
   An approved member with an unconfirmed, wrong-currency, or insufficient
   payment remains ineligible. A partial or installment payment attempt is
   rejected; one complete payment must equal the purchase snapshot.
9. Confirming the single full payment activates the associated paid
   purchase/entitlement once. Duplicate confirmation retries are idempotent;
   a second effective confirmed payment for that purchase is rejected.
10. Access succeeds on `starts_on` and the entire `expires_on` date in
    `Asia/Manila`; it fails one local date before start and at local midnight
    on the day after expiry. At `2026-06-15T15:59:59.999Z` the local date is
    June 15 and a June 15 expiry is valid; at `2026-06-15T16:00:00Z` the local
    date is June 16 and it is expired. A timezone change never rewrites stored
    historical dates.
11. Test finalized Option A: Jan 31, 2027 advances to Feb 28, 2027, expiry
    Feb 27; Jan 31, 2028 advances to Feb 29, expiry Feb 28. Feb 28 in a normal
    year advances to Mar 28, and Feb 29 in a leap year advances to Mar 29.
    Verify timestamp storage is UTC while date arithmetic is `Asia/Manila`.
11a. Initial activation is the later of registration approval and full payment
     confirmation in gym-local date; delayed confirmation never backdates.
     Early renewal starts the day after existing expiry; a lapsed renewal starts
     on its new activation date. Concurrent/adjacent terms cannot overlap and
     arbitrary future prepayment is rejected.
12. Membership access remains valid through the full inclusive `expires_on`
    date. After expiry, access is denied until an approved new purchase is fully
    paid and confirmed. Security suspension/reinstatement is tested separately
    and does not change paid dates. No freeze operation is exposed initially.
13. Plan price/term updates do not change existing purchase snapshots. A zero-price
    plan, zero payment, or zero walk-in fee violates a database constraint.

### Duplicate check-ins and concurrency

14. Two simultaneous requests for one eligible member and one local date
    produce exactly one valid check-in. The other receives a safe duplicate
    outcome; the partial unique index holds even when requests use separate
    connections/transactions.
15. Repeating the same idempotency key returns the original outcome and creates
    no second valid row. Reusing a key for a different member/request is
    rejected.
16. A member may have one valid check-in on each of two consecutive gym-local
    dates. UTC midnight alone does not change the gym-local date.
17. A public request and a Owner/offline sync racing for the same member/date
    still produce at most one valid row. A provisional or rejected row never
    counts as valid attendance.

### Walk-in fee confirmation and cash

18. A walk-in request has a stable opaque request ID and fee-version FK plus
    immutable amount/currency snapshot. No payment or an unconfirmed payment
    leaves it provisional. Owner confirmation of actual receipt and server
    validation commit payment event and attendance exactly once.
18a. Concurrent confirmations/retries for one walk-in request create at most
     one effective confirmed-payment pointer and one attendance row; same-key
     retries return the original outcome and a different key cannot confirm a
     second payment.
19. Wrong fee, wrong currency, duplicate walk-in payment, fabricated
    client-side `paid` state, or unverified callback cannot validate a walk-in.
    An expired request cannot be confirmed or revived; a new attempt requires a
    new request ID and snapshots the then-current fee.
20. Drawer reconciliation includes verified physical cash receipts assigned to
    the session exactly once, including receipts awaiting allocation; it must
    not treat those as confirmed income until correctly allocated. A discrepancy
    is recorded with actor/reason and never rewrites original records.
21. Correct a cash source receipt after drawer close where verified evidence
    changes expected physical cash; exactly one separately authorized adjustment
    must link the correction, receipt, closed reconciliation, Owner and reason.
    The close snapshot is unchanged and retry cannot duplicate the adjustment.
    Correct only the target allocation and verify no physical-cash adjustment is
    created. GCash/bank corrections never alter the drawer. No refund or cash
    movement is represented.

### PIN abuse and enumeration resistance

22. Database inspection and API responses never expose plaintext PIN or hash.
    Logs, analytics, audit metadata, browser storage, and service-worker caches
    contain neither PIN nor raw phone.
23. Unknown member ID, unknown mobile, wrong PIN, pending/unpaid/expired member,
    duplicate, and throttled request use the same public failure body and
    non-revealing message. Responses do not disclose member name, existence,
    payment status, or expiry.
24. Concurrent guesses cannot exceed identifier or network rate limits because
    attempt counts update atomically. Test repeated failures, lockout expiry,
    valid PIN during lockout, and distributed identifier/IP buckets.
25. Very high-volume attempts are throttled before expensive Argon2id work.
    Verify lockout cannot be reset by changing casing/spacing of IDs or mobile
    formatting. Confirm rate-limit rows retain only keyed hashes and expire.
26. PIN reset requires the active Owner, approved identity verification, new
    verifier, and audit event. The current PIN is never retrievable or sent.

### Offline synchronization

27. Offline Owner UI labels a queued item **provisional** and shows no success
    claim. No queued item appears as valid attendance before a server response.
28. Public/member QR requests without internet create no local queue and show
     no successful check-in claim; there is no public offline check-in path.
29. Sync from the active Owner re-checks current registration,
    payment, entitlement, expiry, timezone date, and duplicate status. A member
    who expired or was suspended while the device was offline is rejected.
30. Sync from a revoked Owner identity, forged actor/member ID, altered client
    time, replayed payload, or different payload under an existing idempotency
    key is rejected and audited without creating valid attendance.
31. An offline item competing with an online check-in yields one valid record
    only. Replaying an accepted sync returns its original result.
32. Test receipt just before/after gym-local midnight, stale sync, device clock
    drift, timezone setting change, queue expiry/retry, and provisional
    24-hour triage boundary. Verify server receipt time is authoritative; the
    triage age never proves attendance and no claim is silently discarded.
33. Clearing the PWA cache removes queued sensitive references. No member
    profile, PIN, mobile, payment detail, or entitlement snapshot is precached.
34. The 24-hour age window is a provisional triage/review threshold only.
     Neither client time nor a recent claim proves historical presence. Test
     the configured threshold boundary, Owner attestation of physical presence
     for a current-date check-in, and server-side eligibility/date/duplicate
     validation. Old, suspicious, conflicting, or expired claims must surface
     for Owner resolution, not be silently discarded or approved.

### Corrections, audits, and privacy

35. Payment correction requires an immutable case linked to the original,
    non-empty reason, evidence/reference, Owner actor and server time. Proposed,
    approved and rejected decisions append events; original receipt rows never
    change. No non-Owner can approve.
36. Void a false confirmation and verify it is excluded from the effective
    payment pointer without recording a refund or implying money was returned.
    The associated purchase becomes `payment_review` and ineligible; no
    replacement allocation is created unless separate evidence establishes an
    actual receipt; source receipt facts are never duplicated or changed.
37. App roles cannot UPDATE or DELETE audit, payment, correction, or attendance
    history. Each sensitive success/failure action records actor, UTC time,
    request ID, entity, and reason where required; no secrets or raw PII appear.
38. Encrypted contact data is available only through an audited Owner
    path. Key rotation supports old key versions until safe re-encryption; a
    keyed phone lookup does not reveal the phone value.
39. Realtime subscriptions respect RLS and reveal only the approved Owner view.
    Anonymous users cannot subscribe to member or attendance changes.
40. An expired member remains ineligible until a new approved purchase has full
    confirmed payment. A separate authorized security suspension can deny
    access but cannot alter entitlement dates or grant access past expiry. No
    expiry-override operation is exposed.
41. A PIN reset requires server-side Owner authorization, approved identity
    verification, invalidation of the previous verifier, and an audit event
    containing no proof documents or raw PIN.
42. The audit trigger and grants reject application-role UPDATE/DELETE. Verify
    event hashes chain correctly, detect altered/deleted/reordered rows, and
    compare a signed external anchor. Document that a database superuser can
    rewrite an unanchored chain.
43. Restore an encrypted synthetic backup in an isolated environment; verify
    constraints, RLS/grants, payment/cash totals, timezones, audit chain, and
    attendance unique indexes. A production restore requires owner approval and
    never grants developers access to restored live member data.
44. Bootstrap cannot be claimed by an arbitrary authenticated user, replayed,
    or used after the one-time capability is consumed. Recovery does not create
    another Owner; every bootstrap/recovery action is audited.
45. A setup/reset token is absent from URLs, logs, analytics, browser storage,
    and audit payloads; only its hash is stored, it expires and is consumed
    once, and replacement invalidates prior tokens. Generic public responses
    remain indistinguishable for unknown and ineligible identities.
46. A public walk-in request cannot select a fee version, amount, currency,
    status, or historical timestamp. Replayed or expired requests cannot
    produce a second payment or attendance row; the approved expiry boundary is
    enforced server-side.
47. Correction proposal/approval races serialize; only one unresolved proposal
    exists per payment. A sole-Owner approval records that maker/checker
    separation is absent and cannot rewrite the original payment or a closed
    reconciliation. Required evidence/reviewer policy is tested after Owner
    approval.
48. Cash open/close retries are idempotent; only one open session exists per
    drawer. Verified actual cash is included once by session even while
    unallocated; allocation/payment eligibility does not determine drawer cash.
    Later source-fact correction adjusts only if physical cash expected changes;
    target-only allocation corrections do not.
49. Profile mobile changes preserve normalized-HMAC uniqueness under
    concurrency, require approved identity verification, and audit only masked
    references. The Developer's member identity cannot cross into Owner or
    technical authorization.
50. Direct API/RPC inspection and database status constraints show no
    membership-cancellation or non-renewal operation, permission, field, state,
    or cancellation-specific audit action. Access ends only after inclusive
    expiry; subsequent access requires a new approved, fully paid purchase.

### Correction, transaction, relationship, and function-boundary cases

51. For `replace_misrecorded_receipt`, verify the replacement is a distinct
    immutable receipt row, links to exactly one original receipt and approved
    correction, and documents the same actual receipt with corrected recorded
    fields. The old receipt is voided in the same transaction, its allocation
    pointer is removed, and income counts exactly once.
52. Reject a replacement with another target, different amount/currency,
    unsupported receipt evidence, multiple replacements, replacement cycles,
    or a second effective payment. A corrected confirmation must never become
    an installment, complimentary membership, or refund/cash-out.
53. If a voided confirmation had activated membership, atomically remove its
    effective-payment pointer, move purchase to `payment_review`, make access
    ineligible, append linked payment-impact events for affected check-ins, and
    preserve original check-in events. Rebuild effective income/eligibility
    from immutable source events and confirm the projection matches.
54. If a later renewal, attendance, or reconciliation relied on the original
    confirmation, verify all affected records are locked/re-evaluated and
    linked. No membership dates or attendance history are silently rewritten.
    Verify invalidated check-ins are excluded from valid totals but retained in
    history. An independent valid payment may change derived eligibility only
    after a separate Owner resolution event references that allocation, reason,
    actor and request; the original check-in and invalidation remain unchanged.
55. Race two protected operations in different entry points (payment confirm vs
    correction; payment confirm vs cash close; member check-in vs payment
    correction; early renewals; walk-in confirmation retries). Verify each
    follows the canonical lock order, no deadlocks corrupt state, and uniqueness
    is the final duplicate guard.
56. Force serialization and deadlock SQLSTATEs. Verify only bounded retries
    with the same key/fingerprint occur; exhausted retry returns a retry-safe
    response and creates no partial business/audit/idempotency result.
57. Verify audit failure, idempotency-result failure, or any linked
    payment/attendance/reconciliation constraint failure rolls back the whole
    business transaction. Confirm clients are not told success before commit.
58. Attempt FK-mismatched composites: an entitlement for a different member's
    purchase; walk-in payment for request A paired with attendance for request
    B; wrong walk-in effective payment; multiple effective payments; member
    attendance without its matching entitlement. Each must fail at a constraint
    or trusted transaction boundary.
59. Verify audit subject references use typed FKs and cannot dangle. Confirm
    idempotency result references use typed nullable FKs with an at-most-one
    check; same scope/key/fingerprint replays one result, changed payload fails.
60. As `anon`, attempt every table operation and direct function call not
    explicitly granted. Only fixed public QR operations execute; public callers
    cannot read directories, select a member by ID, set price/payment/date, or
    directly insert valid attendance.
61. Record an unmatched actual receipt and verify it persists in Owner review,
    is not confirmed income, and grants no membership or attendance eligibility.
    Retry the same receipt/allocation request and verify idempotency prevents a
    duplicate receipt or allocation.
62. Verify Owner allocation links a receipt to exactly one target with exact
    source amount/currency; rejecting, mismatching, splitting, or allocating one
    receipt twice fails atomically. Unresolved receipts are never auto-deleted.
63. Verify the five non-additive reports: verified money actually received;
    unmatched/unresolved receipts split into unverified claims and verified but
    unallocated/unresolved receipts; approved underpaid receipts; qualifying
    exact full payments; and operational confirmed membership-payment total.
    Each source receipt appears at most once in verified-received money;
    unverified claims are excluded. Underpaid is a subset of received money,
    remains excluded from qualifying payment and membership-payment total, and
    creates no amount-due credit or access. Owner verification/allocation
    produces one `approved_underpaid` outcome, traceable and retained. If a
    distinct later exact full receipt arrives, it independently qualifies
    without voiding/correcting the underpayment and alone is effective. Reject
    a second effective full payment and all installment summing. Verify report
    categories are not added together and do not double count. Walk-in
    underpayment cannot validate attendance or confirmed income. Mark category
    labels/accounting classification unapproved until Owner/accountant review.
64. Correct a wrong allocation and verify old allocation remains in history,
    is voided only by an audited Owner event, and exactly one new current
    allocation determines receipt classification. Reject a mismatched receipt/allocation pair
    in the current-allocation composite FK. Fail audit append and verify allocation,
    receipt event and projections all roll back. Verify a target-only correction
    changes allocation/income classification but leaves physical cash expected
    unchanged and creates no cash adjustment.
65. Rebuild current-allocation, effective-income, membership-payment and
    walk-in-payment projections from receipt/allocation/correction events and compare with stored projections;
    an unallocated, rejected, voided, or duplicate receipt must never count;
    an approved-underpaid receipt appears only in the distinct received-receipt
    classification and never as a qualifying membership payment.
66. As authenticated Owner, use forged actor IDs, user metadata, stale JWT,
    inactive `owner_access`, and direct table writes. All privileged operations
    must fail unless the current JWT's `auth.uid()` resolves to the active Owner.
67. Inspect every `SECURITY DEFINER` function: exact owner role is
    `gym_public_executor` or `gym_owner_executor`, each NOLOGIN/NOSUPERUSER/
    NOBYPASSRLS with no caller role membership, no table ownership, and only
    least-privilege grants plus targeted RLS. Confirm separate `gym_table_owner`,
    FORCE RLS, `SET search_path = ''`, schema-qualified references, no dynamic
    SQL, revoked `PUBLIC` execute/default privileges, exact endpoint grants,
    and authorization inside the function independent of RLS.
68. Verify Edge/server/browser code does not expose or log service-role or
    other privileged secrets. The ordinary request path uses caller JWTs and
    narrow RPCs without bypass-RLS credentials. Confirm no generic SQL/table
    endpoint exists. Developer source/deployment access cannot invoke
    production operations or access live data; Owner controls production
    credentials and releases.
69. Verify a post-close source-fact correction that changes expected cash
    creates one adjustment linked by enforceable FKs to the original verified
    cash receipt, its correction, the closed reconciliation for that same cash
    session, the Owner who approved the correction (the actor IDs must match),
    and the idempotency operation. Assert
    `delta = corrected_expected_cash_for_receipt - prior_expected_cash_for_receipt`;
    false/unreceived cash yields a negative delta and a verified amount increase
    a positive delta. Wrong receipt/correction/session pairing, duplicate
    correction adjustment, and changed-payload retry fail. The closed count and
    expected snapshot remains immutable after close; the adjustment is an
    expected-cash delta, not a cash movement.
70. Verify allocation-only reassignment, including voiding an erroneous target
    and allocating a new target, never creates or changes physical-cash
    adjustments. Verify pre-close source corrections alter the computed expected
    amount once and do not create a post-close adjustment.
71. Insert audit subjects for a payment allocation and an attendance validity
    resolution and verify each is enforced by its typed FK. Reject nonexistent
    or mismatched subjects; RESTRICT deletion of referenced allocation or
    resolution history. Verify audit event, subjects, business changes and chain
    head roll back together if any subject FK or audit append fails.
72. Verify every GCash/bank source correction leaves expected physical cash
    unchanged and creates no drawer adjustment. Verify pre-close cash source
    correction changes the calculated close expectation once, without a
    post-close adjustment. Reject automatic cash/non-cash method
    reclassification until an explicit approved rule exists.
73. Inspect grants and runtime authorization in the disposable database:
    business tables expose no direct DML to `anon`/`authenticated`; `PUBLIC`
    has no execute on functions; only exact named functions are granted to the
    intended role. Confirm separate NOLOGIN/NOSUPERUSER/NOBYPASSRLS public and
    Owner executor roles, no role membership for callers, separate table-owner
    role, FORCE RLS and role-targeted policies. Confirm function ownership,
    `SET search_path = ''`, schema-qualified references, no dynamic SQL, and
    Owner `auth.uid()` plus active `owner_access` checks. Anonymous callers
    cannot invoke Owner functions or learn member status. Force an audit subject,
    audit-chain, or idempotency write failure and verify full transaction
    rollback and no success response. Confirm no service-role key is present in
    browser bundles and Developer identity has no production role or live-data
    access.

## Exit criteria before production

- All tests above pass against a disposable environment and are reviewed by the
  owner; policy tests include direct-table attempts, not only UI tests.
- A migration review confirms RLS on every exposed table, safe grants, indexes,
  constraints, timezone rules, and reversible operational procedures.
- PIN parameters, throttles, retention, payment evidence, offline age, security
  suspension controls, and privacy notice have explicit Owner approval.
- Backups/restore, key rotation, incident response, audit retention, and
  production access are documented. Developer access to live member data stays
  disabled by default.
