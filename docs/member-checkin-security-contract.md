# GYMFORCE Member Check-in Security Contract

**Status:** Design contract. The PIN abuse-control thresholds in section 3 and
the in-person recovery identity methods in section 4 are **approved design
requirements**. They are not implemented controls. Other items explicitly
marked **proposed** remain subject to Owner approval. No check-in implementation,
migration, or deployment is approved by this document.

## 1. Scope and fixed requirements

- The first release has one management role: the Owner. There are no manager or
  front-desk accounts or attendance bypasses.
- A member presents a member code/ID or registered mobile number and a
  six-digit numeric PIN through the public check-in page reached from the
  permanent entrance QR. The QR contains no credentials or member data.
- The browser is untrusted. The trusted server validates identity, PIN,
  membership, confirmed full payment, expiry, duplicate status, date, and
  idempotency. The browser cannot submit an authoritative attendance date or
  payment/eligibility state.
- One valid member check-in is allowed per `Asia/Manila` calendar date.
  Membership expiry is inclusive through the entire local expiry date.
- No expiry override, staff bypass, member dashboard, checkout, or offline
  public/member check-in is in scope.
- Responses for an unknown identifier, incorrect PIN, ineligible member, and
  throttled attempt must not disclose membership or payment status or confirm
  whether an identifier belongs to a member.

## 2. Current source evidence (not deployment evidence)

The repository has a PIN enrollment foundation, not a member authentication
flow:

- `supabase/functions/_shared/pin-password.ts` validates six digits and uses
  Argon2id with memory 65,536 KiB, three iterations, parallelism one, a random
  16-byte salt, and a 32-byte output. It exports a verifier helper. This is
  code evidence only; parameters have not been validated for production load.
- `supabase/migrations/20261028062853_member_pin_security.sql` defines
  `private.member_pin_credentials`, token storage, and
  `private.pin_attempt_buckets`. The tables store an Argon2id encoded hash and
  keyed identifier digests; browser roles are revoked. The attempt bucket
  structure is not itself a working lockout policy.
- `supabase/functions/member-enroll-pin/index.ts` accepts enrollment token and
  PIN, applies a global enrollment request limit, hashes the PIN in the Edge
  Function, and calls `api.member_enroll_pin`. It does not verify PINs for
  check-in.
- `supabase/migrations/20261030150000_member_pin_enrollment.sql` locks and
  consumes one-time enrollment tokens and stores the supplied Argon2id hash.
  It permits enrollment tokens only; reset is not implemented by this RPC.
- `supabase/migrations/20261030140000_owner_create_pin_enrollment_token.sql`
  limits enrollment tokens to at most 30 minutes and invalidates previous
  unused enrollment tokens. Its function accepts only the `enrollment`
  purpose.
- `supabase/migrations/20261030170000_rolling_pin_enrollment_rate_limit.sql`
  limits enrollment traffic to 30 accepted requests in a rolling 60-second
  global window. This is enrollment abuse protection, not check-in PIN
  attempt protection.
- `supabase/migrations/20261028062706_walkin_attendance.sql` is explicitly
  labeled a draft. It defines attendance and walk-in tables and indexes, but
  no check-in operation. `attendance_checkins.gym_local_date` is supplied as a
  column value; no source trigger/RPC derives it from `Asia/Manila`.
- `supabase/migrations/20261030120000_audit_chain_enforcement.sql` defines an
  append-only hash-chain audit foundation and `api.append_audit_event`.
  Existing attendance operations do not exist to call it.
- `supabase/migrations/20261028062516_membership_core.sql` defines purchases,
  date columns, and statuses. Membership payment operations are separate; no
  check-in operation currently consumes them for eligibility.

The above is a static repository inspection. It does not prove any migration,
table, function, grant, or secret is present in a hosted project.

## 3. Owner-approved PIN attempt protection

The Owner has approved these settings as design requirements. They are **not
implemented controls** and must be verified with synthetic load, shared-network,
and denial-of-service tests before production use:

| Control | Approved setting | Notes |
|---|---:|---|
| Consecutive failed PIN attempts per normalized member identifier | 5 failures | Store a keyed HMAC digest of the normalized identifier, never the raw identifier in a rate-limit row. Unknown identifiers use the same accounting path. |
| Identifier lockout | 15 minutes after the fifth consecutive failure | Enforce server-side; do not tell the caller whether lockout came from an existing member. Expire automatically. Do not clear a lockout merely because another identifier format was used. |
| Attempts per identifier | 10 requests per rolling 5 minutes | Counts successes and failures to constrain repeated submissions; keep separate from the consecutive-failure lock. |
| Trusted source-network throttle | 60 requests per rolling 5 minutes | Use only an ingress-provided client address whose provenance is verified for the deployed Supabase edge path; do not trust arbitrary browser headers. Store a keyed digest, not an IP address. Throttle rather than long-lock a shared NAT network. |
| Global emergency throttle | 300 requests per rolling 5 minutes | Backstop for service protection, with operational alerting. It must not become a member-existence oracle. |
| Response retry guidance | Generic response; optional bounded `Retry-After` | Use the same response body for unknown/ineligible/incorrect/locked outcomes. Do not expose remaining attempts or member state. |

These approved values must be tested under synthetic load, shared-network
conditions, and denial-of-service scenarios before production use. Six numeric
digits have limited entropy; rate limiting and non-enumerating behavior are
required.

### Counter behavior

- Normalize member code and mobile number on the server using one canonical
  format before deriving an HMAC bucket key. Do not log normalized values.
- Update/check buckets atomically so parallel guesses cannot exceed a limit.
- Use a keyed HMAC with a server-held secret for rate-limit identifiers. Never
  persist a raw phone number, IP address, or PIN in the bucket table.
- Reserve rate-limit capacity before Argon2id verification to limit expensive
  hashing. Apply comparable work/response handling for unknown identifiers to
  reduce timing-based enumeration.
- A correct PIN never bypasses an active 15-minute lockout. A successful
  verification outside an active lockout ends the consecutive-failure streak;
  it does not reset the separate rolling request counters.
- Retain only the minimum bucket history needed for the approved window and
  lockout; cleanup must not reset active locks early.

## 4. Recovery, reset, and PIN change

The Owner initiates recovery and verifies the member in person against existing
membership, registration, and available payment records. A government-issued
ID is **not mandatory**. Use the registered mobile number when accessible. If
records are insufficient or conflict, stop recovery until the Owner resolves
the discrepancy. The Owner documents the verification method and outcome.

Recovery requirements:

- Issue a new high-entropy, single-use recovery enrollment capability with a
  **15-minute lifetime**. The lifetime is Owner-approved.
- The Owner hands the capability directly to the verified member in person.
  Do not use a paid SMS service or place the capability in a URL, log, or
  support record.
- Store only a secure token hash. Expire the capability server-side and
  invalidate all previous unused recovery capabilities when issuing a
  replacement.
- Replace the existing PIN verifier securely and increment its credential
  version. The old verifier must stop authenticating immediately.
- The existing PIN is never retrieved or disclosed to the Owner or member.
  Do not expose PINs, hashes, or raw recovery tokens in URLs, logs, analytics,
  audit details, browser storage, or support records.
- Document which verification was performed and the resulting recovery/mobile
  update action. Audit method and outcome without storing raw mobile numbers,
  proof documents, or unnecessary payment details.
- Rate-limit recovery requests and audit issuance, redemption, replacement,
  and completion without recording secrets.

Reasonable safeguards that do not add a document requirement: conduct the
check in person; compare multiple existing membership, registration, and
payment details; use the registered mobile as an additional check when
accessible; avoid disclosing account or payment details while asking
verification questions; and audit the method, Owner, time, and outcome. These
safeguards reduce, but do not eliminate, impersonation, social-engineering,
SIM-swap, stale-record, or Owner-error risks.

The Owner must never learn the old or new PIN. When recovery is stopped because
records are insufficient or conflict, resolve the discrepancy manually before
issuing a capability; do not bypass this condition with an unapproved proof
method.

## 5. Registered mobile-number changes

Only the Owner may update a member's registered mobile number, after verifying
the existing member record. When the old number is accessible, use it as an
additional verification channel. When it is unavailable, verify from existing
membership, registration, and available payment records. Stop for manual
resolution if information is insufficient or conflicting. Record old/new
number references in a privacy-conscious form (for example, masked values or
keyed references), the Owner, timestamp, verification method, and reason. Notify
the previous number when practical and safe. Never allow a public,
unauthenticated endpoint to change a member number. The specific notification
and number-reference format should minimize exposure of phone data.

## 6. Check-in authorization contract

The check-in must be denied unless all conditions hold at the server's
transaction decision point:

1. Identifier is valid and maps to exactly one member.
2. Submitted PIN passes server-side Argon2id verification against the current
   credential version.
3. Member is approved and active (not pending or suspended).
4. A membership entitlement is active on the server-derived Manila date.
5. The entitlement's full confirmed payment is still effective; recorded,
   pending, partial, rejected, or voided payment does not qualify.
6. `activation_date <= gym_local_date <= expiry_date`, inclusive.
7. There is no existing valid member check-in for that member and local date.
8. The request's idempotency key is new, or it is a replay with the same
   authenticated operation fingerprint.

No browser field can override these checks. There is no Owner expiry override,
staff bypass, offline public success, or provisional record counted as valid.

## 7. Membership payment confirmation contract

GYMFORCE accepts both cash and online payments, including supported e-wallet
and bank-transfer methods. Membership eligibility must not depend on payment
method. Each actual receipt is recorded in the payment ledger with method,
actual amount, payment date/time, and confirmation status. Cash and online
receipts are both confirmed by the Owner:

- For cash, the Owner records and confirms the actual cash received.
- For online payment, the Owner verifies the actual receipt/transaction before
  confirming it through the relevant provider or bank. A submitted reference
  number or member claim is not confirmation by itself. Do not add payment
  provider integrations or paid services as part of this contract.
- A confirmed, effective payment counts toward the required full membership
  price regardless of method. Pending, partial, rejected, or voided payments
  do not qualify. Eligibility begins only when the required full amount is
  confirmed and effective, subject to membership approval and activation rules.
  Partial payments/installments do not activate membership.
- Corrections and reversals preserve the original payment record and require
  auditable reason, actor, time, and linked correction history. Correct by
  reversal and re-recording where appropriate. Never overwrite or delete
  historical payment records/events. Prevent duplicate allocation of the same
  verified online transaction.
- Physical cash received and confirmed membership income remain distinct
  accounting views. Cash-drawer reconciliation includes verified cash receipts
  even while allocation/review is pending; that alone does not activate a
  membership. Reconciliation records opening float, actual cash received,
  closing cash, expected cash, variance, and documented discrepancy/adjustment.

The repository's payment schema permits `cash`, `gcash`, and `bank_transfer`
and records amount, method, received timestamp, and verification status.
Source inspection does not prove end-to-end cash/online Owner verification,
correction, or eligibility behavior is implemented or deployed.

## 8. Server operation and transaction boundary

Recommended flow:

1. A public Edge Function accepts a small, schema-validated request containing
   identifier, six-digit PIN, and a random idempotency key. Reject oversized or
   malformed bodies. Never return member name, mobile, expiry, payment, or
   account-existence detail.
2. Apply identifier, trusted network, and global throttles before password
   hashing. Use generic failure status/body semantics.
3. Resolve the identifier and retrieve the Argon2id verifier and credential
   version only within trusted server-side code. Verify the PIN in the Edge
   Function; never send hash or PIN to the browser beyond the submitted
   request. Avoid logging request bodies.
4. After PIN verification, call one narrowly granted database operation. That
   transaction locks/rechecks the member and credential version, derives
   `Asia/Manila` date from trusted database time, checks membership and effective
   confirmed payment, serializes the member/date decision, inserts attendance,
   appends the audit event, and stores the idempotency result. If credential
   version changed after Argon2 verification, abort and require a fresh attempt.
5. Commit all attendance/audit/idempotency effects together. Any failure rolls
   back all of them. Return success only after commit.

**Transaction precision:** Argon2id verification is performed by trusted Edge
Function code and is not realistically part of a PostgreSQL transaction. The
database transaction therefore atomically revalidates the credential version
and all mutable eligibility state before committing attendance and audit. The
overall endpoint is one logical check-in operation, but PIN hashing and the
database commit are distinct execution stages. The API boundary must prevent a
verified result from being reused or detached from its member/version.

### Duplicate, concurrency, and idempotency

- Use a cryptographically random key of at least 128 bits, scoped by operation
  (`member-checkin`, `walkin-confirm`, etc.). Store a keyed digest of the key,
  not the raw key. Keys are retry identifiers, never authorization credentials.
- Persist a keyed request fingerprint over the operation scope, canonical
  non-secret request fields, and keyed identifier/reference. Never include or
  store the plaintext PIN, PIN hash, access token, or raw mobile in the
  fingerprint record. Re-verify authorization on every retry before disclosing
  even a generic stored outcome.
- Same scope/key/fingerprint returns the original safe outcome without
  repeating the business effect. Same key with a different fingerprint is
  rejected generically and does not mutate records. A fresh key for an already
  checked-in member returns the safe duplicate outcome.
- **Proposed idempotency result retention: 24 hours after completion.** This
  supports delayed network retries; after expiry, the attendance unique
  constraint remains the duplicate backstop. The exact duration and deletion
  procedure remain subject to privacy/legal review. If an expired key has been
  purged, a retry must still re-authenticate and must not create a second
  attendance record.
- Check-in and Owner confirmation transactions must serialize races on the
  relevant member/date or payment/request and rely on unique constraints as
  final database guards. Commit the business record, audit event, and
  idempotency outcome atomically.
- Serialize competing requests for one member/date using a database lock or
  equivalent row/advisory lock, and retain the unique partial index as the
  final database backstop.
- Existing index: `attendance_one_member_valid_checkin_per_day` on
  `(member_id, gym_local_date)` where member is non-null and status is valid.
  It does not authenticate callers or derive the date.
- A concurrent distinct request for an already checked-in member/day returns
  a generic duplicate/no-new-check-in result without creating another valid
  record. Do not disclose details about another request.
- Use server timestamps for `checked_in_at`; derive `gym_local_date` from
  database/server time in `Asia/Manila`, never from browser/device time.

## 9. Audit and privacy contract

Audit at minimum:

- Successful member check-in: member reference, server timestamp, local date,
  operation/idempotency reference, and outcome; use the existing append-only
  audit mechanism.
- Administrative attendance validity resolution: actor, time, prior/new
  status, affected attendance ID, non-empty reason, and linked evidence
  reference where appropriate. Preserve the original check-in event.
- PIN recovery/reset/enrollment and credential-version change: actor, member
  reference, event type, time, and method; no secret material.
- Security throttles/lockouts where useful for abuse detection. Prefer
  aggregate or keyed-digest references and avoid creating a permanent audit
  event for every malformed public request. Keep operational rate-limit data
  separate from member history.

Never log or audit plaintext PINs, PIN hashes, raw recovery tokens, access or
refresh tokens, service-role keys, passwords, full phone numbers, or identity
proof documents. Public responses and telemetry must not disclose whether a
member exists. Minimize browser state and ensure service-worker caches never
store PIN, member, payment, entitlement, or attendance data.

### Retention and archive proposal

- Permanent business/security audit events are append-only and must not be
  deleted or rewritten by application roles. Preserve hash-chain verification
  material and periodically create encrypted, integrity-verifiable archives
  under Owner-controlled access. Archive copies must retain event ordering,
  links, and verification metadata; test restore and chain verification.
- Suggested starting cadence for Owner consideration: create an encrypted
  archive monthly and perform a synthetic restore/hash-chain verification
  quarterly. This cadence is a proposal, not an approved backup schedule.
- Keep operational rate-limit counters separate from permanent audit history.
  Proposed maximum retention is 24 hours after the last relevant request or
  lockout expiry, whichever is later, followed by secure deletion of the keyed
  digest/counter data. Lockout state must not be removed before its 15-minute
  period ends.
- Exact audit/event retention periods, archive cadence, backup cadence, and
  deletion schedule remain **unresolved pending legal/accounting and privacy
  review**. No statutory period is asserted here. Until an approved schedule
  exists, do not implement age-based deletion of permanent audit/payment
  history; minimize access and use encrypted backups/archives.

## 10. Walk-in scope (not implemented)

The draft migration `supabase/migrations/20261028062706_walkin_attendance.sql`
defines versioned PHP fees and provisional requests with immutable amount and
currency snapshots, timestamps, expiry, status, and confirmation fields. The
attendance table can reference a walk-in request. Payment allocations later
gain a foreign key to the request in
`supabase/migrations/20261028063404_integrity_fixes.sql`.

No walk-in request endpoint, fee-management endpoint, Owner payment-confirmation
operation, or atomic confirmation-plus-attendance transaction was found. The
eventual implementation must create opaque IDs and snapshot fee/time/expiry on
the server; prevent caller-selected fees/status/date; verify actual receipt;
allow at most one allocation and attendance; reject replay and expiry; and
confirm payment plus attendance atomically under Owner authorization.

**Owner decision still required:** request lifetime and precise expiry
handling. Expired requests must never be revived; a retry after expiry creates
a new request at the current fee. Do not encode a lifetime until approved.

## 11. Release security tests

Use a disposable local Supabase project and synthetic records only. Required
coverage includes:

- Correct/wrong PIN, unknown member ID/mobile, pending/suspended member,
  unpaid/voided/expired entitlement, and duplicate check-in all produce
  non-enumerating responses.
- PINs/hashes/tokens/credentials and raw personal data never appear in
  browser bundles, storage, service-worker caches, logs, audit details, or
  error reports.
- Argon2 verification and approved parameter performance under synthetic
  load; malformed/oversized input handling.
- Identifier/network/global limits, parallel guesses, lockout expiry,
  normalized identifier variants, shared NAT traffic, and recovery abuse.
- Manila midnight boundary, inclusive expiry day, one day after expiry,
  activation boundary, UTC/local date conversion, and server/device clock
  disagreement.
- Two simultaneous check-ins yield at most one valid row; same-key retries
  are idempotent; payload/key mismatch is rejected; unique index remains the
  final guard.
- Credential reset racing with verification; changed credential version
  cannot authorize a stale verification result.
- Attendance insert, audit event, and idempotency result roll back together
  under forced failures; success is returned only after commit.
- Anonymous direct table access and ungranted RPC calls fail; public function
  cannot call Owner operations, choose payment/date/status, or enumerate
  members.
- Walk-in expiry, replay, wrong fee, duplicate receipt/allocation, concurrent
  Owner confirmation, and atomic attendance/payment behavior after that phase
  is approved and implemented.

See also [attendance implementation readiness](attendance-implementation-readiness.md)
and the existing [database security test plan](security-test-plan.md).
