# Phase 3D final schema review package

**Status:** planning only. Business rules explicitly listed as confirmed are
Owner-confirmed; technical implementation details and operational parameters
remain proposals/checks as labeled. No database connection, SQL, migration,
or live-data operation was performed.

## Confirmed decisions

- One Owner management identity; no manager/front-desk accounts. Owner controls
  production credentials, backups, and production releases.
- Developer source/technical deployment responsibilities are separate from an
  ordinary gym-member identity. Owner controls production project membership,
  credentials/secrets, releases, backups and restores. Developer has no routine
  live member/financial data access; exact deployment permission and emergency
  procedure remain operational checks.
- Members and walk-ins use the entrance QR webpage. Member self-check-in needs
  internet; no member dashboard/login.
- One location initially; PHP and `Asia/Manila` business dates.
- Each purchase covers one calendar month. Month-end clamping is required;
  expiry is inclusive through the full local expiry date. Early renewal starts
  the day after current expiry; access intervals cannot overlap, and arbitrary
  future prepaid periods are prohibited. Lapsed renewal starts on activation.
- Finalized Option A: advance activation/term-start by one calendar month and
  clamp to the target month's last day. That is the next-term start; inclusive
  expiry is the prior date. Jan 31 -> Feb 28/29 next-term start and Feb 27/28
  expiry. Feb 28 normal year -> Mar 28; Feb 29 leap year -> Mar 29. Activation
  is the later gym-local date of registration approval and full confirmed
  payment; delayed confirmation never backdates access.
- Registration approval and fully confirmed payment are both required for
  membership access. No grace period, complimentary membership, automatic
  renewal, installment, membership cancellation/non-renewal, freeze, expiry
  override, or checkout in release one. Exactly one full payment equal to the
  purchase amount is required.
- No refunds or checkout and no checkout-related data/workflow. Original
  payment records are preserved; corrections require reason and audit history.
- Walk-in attendance and income are invalid until Owner verifies actual receipt
  and trusted server-side validation commits the result.
- Offline Owner submissions are provisional claims. The 24-hour window is for
  triage only. A client timestamp cannot establish historical attendance.
- PINs are privately chosen by members, never stored in plaintext or exposed to
  the Owner. No service-role/secret key in browser code.

## Confirmed design and remaining operational checks

### Finalized membership dates and payment

Use local `date` values in `Asia/Manila`; keep event timestamps in UTC
`timestamptz`. Option A is finalized: next-term start is activation/start date
plus one calendar month with target-month-end clamping; inclusive expiry is one
calendar day before that next-term start. The examples above are normative.
Access is valid for all of `expires_on` and fails at the next local midnight.
Activation is the later gym-local date of approval and full confirmed payment.
For early renewal, the new term starts the day after existing expiry; for a
lapsed term, it starts on the new activation date.

Exactly one complete payment per purchase is required. No installments or
partial-payment path exists. A purchase is eligible only with one confirmed
effective payment exactly equal to the purchase snapshot. Pending or rejected
payments do not count as income or access.

### Finalized walk-in flow

The public QR may create a provisional
`walkin_request` with a random opaque request ID. It collects no member profile
or payment proof. The server chooses the currently effective positive fee
version and snapshots its version ID, amount in integer minor units, and `PHP`
currency. The server also records creation timestamp and expiry. The public response reveals only a generic request acknowledgement
and opaque request reference; do not use that reference as payment proof.

The Owner receives actual cash/GCash/bank receipt through the gym's normal
channel, locates the request, verifies actual receipt and exact snapshotted fee,
then invokes one trusted transaction. That transaction reserves idempotency,
locks request/receipt/allocation/cash session in the global lock order, validates
the request is pending and unexpired, appends receipt confirmation and exact-fee
allocation events, inserts the unique effective-allocation pointer,
creates/validates exactly one walk-in attendance row, updates request
projection, appends audit, and commits.
Only this committed state counts as income or attendance. Screenshots alone do
not verify receipt. The public QR request flow is confirmed; its lifetime is an
operational value to set before accepting walk-ins.

Use `walkin_requests.request_id` as the allocation target. `attendance_checkins`
references the request; the request does not reference attendance. This avoids a
circular FK. A unique `walkin_payment_effective.request_id` primary key and
unique allocation ID, plus a request row lock, prevent two effective confirmed
allocations. Attendance has a unique FK to the request. Same idempotency key and
same payload returns the committed result; changed payload fails. A second key
cannot confirm a second payment.

Lifecycle: pending -> valid after atomic confirmation, or pending ->
expired/rejected by trusted server. An expired request cannot be revived. A new
attempt is a new request with a new ID and then-current fee snapshot. Request
lifetime is an operational value to set before accepting walk-ins; no duration
is assumed. Never reprice a request after creation.

### Offline submissions

The confirmed rule is that the 24-hour age window is a triage/review threshold,
not proof or automatic approval. Its exact inclusive boundary remains a
provisional operational parameter pending validation. Compare client-claimed
`client_observed_at` with server receipt only to route review; client time is
forgeable. Do not set clock-drift tolerance without testing.

The sync server timestamp is authoritative for processing date and duplicates.
An offline claim must never create a past-date valid row. The Owner may confirm
physical presence for a current-date check-in, but the server must still check
current registration, full payment, expiry, security suspension, local date,
and the unique check-in constraint. Queue outcomes must distinguish
provisional/needs-review, accepted-current-date, duplicate, rejected, and
expired. Old, conflicting, suspicious, ineligible, or duplicate claims remain
visible for the documented Owner resolution path; never silently discard or
approve them. Offline claims never create income or confirm payment.

Use a random UUID scoped to Owner + device + operation for idempotency; bind it
to a keyed payload fingerprint that excludes PIN, raw mobile, and raw identity.
Same key/fingerprint returns the saved terminal result; changed payload is
rejected and audited. Server-side reservation, attendance result, and audit are
atomic. Queue only encrypted minimal references; no PIN/token/profile/payment
or entitlement snapshot. Clear the local item after a terminal server result.
Retain the idempotency record at least as long as its linked operation record
can be retried; do not choose a purge interval until retention is approved.

### Owner-only payment correction

There is no second in-app approver. **Confirmed control:** never mutate or delete
the original payment. The Owner creates an immutable correction proposal
referencing the original payment, proposed corrected fields, mandatory reason,
supporting evidence/reference, actor and server timestamp. State transitions:
proposed -> approved, rejected, or withdrawn; decisions are append-only. The
same Owner may approve after reviewing evidence, but the audit explicitly marks
that maker/checker separation is absent. Where practical, attach independent
accountant/reviewer evidence and periodically compare correction log with
statements/cash counts. Owner must decide required evidence and whether an
external reviewer is required for defined cases.

Approval transaction locks the original payment, correction stream, affected
purchase/entitlement and cash reconciliation in fixed order; ensures no other
pending correction exists; appends decision; updates a private effective-value
projection; recalculates confirmed balance; blocks membership when effective
confirmed payment is below purchase amount; creates a separate reconciliation
adjustment only if verified correction changes expected physical cash for a
closed session. Target/allocation-only changes create no adjustment. Any
adjustment links correction, source receipt, reconciliation, Owner and reason,
is unique per correction, and is appended atomically with audit. Original amount,
confirmation, and evidence remain available. Correction is a record correction,
not return of money: no refund, cash-out, refund status, or refund API.

### Finalized PIN enrollment, reset, and abuse controls

The member chooses a numeric PIN privately on their own device through
a TLS-protected setup/reset form. Owner verifies identity in person or through
an Owner-approved existing channel but never sees, chooses, receives, or
retrieves the PIN. Issue a cryptographically random, short-lived, single-use
setup token; store only a keyed token hash, purpose, issue/expiry/use/revocation
times and attempt count. Deliver out of band or in person, never in a URL,
analytics, logs, or offline queue. Consume atomically, invalidate prior tokens
on replacement/use, and audit issuance/reset without recording the secret.

Store only an Argon2id verifier with salt and version; pepper/key stays in
server-managed secrets, not database/client. Generic response body and similar
work for unknown identifier, wrong PIN, ineligible member, duplicate, and
throttle. Use dummy KDF for unknown identifiers and normalize identifiers
before lookup. Apply atomic pseudonymous identifier and trusted network buckets
before expensive KDF work; no permanent account lock.

Illustrative abuse-control values for testing only (not tested or approved): at
most 5 failures per keyed identifier per 15 minutes, and 30 per trusted network
bucket per 15 minutes; progressive temporary cooldown after repeated windows,
capped at one hour, plus Owner-assisted recovery. Tune under synthetic load,
NAT/shared-network and denial-of-service tests before Owner approval. Do not
return the threshold state to the public caller.

### Owner bootstrap and Developer boundary

**Confirmed boundary; procedure still to finalize:** Owner or trusted project operator creates the sole
Owner Auth identity through a controlled out-of-band Supabase Auth invitation
and verifies identity before enabling it. No public signup endpoint or
claim-first account. A one-time, high-entropy bootstrap capability is stored
only as a server-side hash, bound to the pre-authorized Owner identity, short
lived, single-use, rate-limited and audited; disable it atomically after success.
Require MFA if available without requiring a paid feature. Recovery is
Owner-controlled out of band, identity-verified, audited, and must not silently
create another Owner. This is a proposal; exact operator/recovery procedure
needs approval. Do not execute bootstrap during planning.

Developer has source repository access and synthetic
local fixtures. Owner controls production project membership, secrets, database
access, backup keys and the release button. Developer submits reviewed source;
production deployment runs only through Owner-controlled CI/manual approval
with secrets unavailable to Developer and production data disabled. No standing
Developer database/service-role credential. Any emergency access is just-in-time,
time-limited, Owner-approved, logged, scoped to the task and revoked afterward;
prefer synthetic reproduction. Deployment can execute code with secret access,
so Owner review must include server functions and CI configuration. Exact
permissions and emergency-access procedure require Owner approval.

### Member profile and privacy

**Confirmed minimum:** random member code, full name, uniquely normalized mobile
number, registration state, approval actor/time, and essential audit metadata.
No DOB, email, emergency contact, address, ID copy, or minor/guardian fields
until the Owner approves a documented need and privacy review. Normalize mobile
to a consistent international representation and enforce a unique keyed lookup
index; do not expose the number through public API/log/audit.

For a mobile change, Owner verifies the member using an approved identity
process; check normalized-number uniqueness under a transaction lock; atomically
replace encrypted value and keyed lookup, record masked old/new references,
actor/time/reason and notification outcome, and invalidate any pending PIN
setup token tied to the old contact. Do not retain identity documents unless
separately approved. Owner/privacy counsel must decide the exact identity proof,
notice/lawful basis, member rights process, incident response, data fields and
record-specific retention before live data.

### Membership end and security controls

Membership cancellation and non-renewal are not features or states. An active
membership remains available through the inclusive expiry date. Early renewal
starts on the next day after existing expiry. Once expired, access requires an
approved new purchase and full confirmed payment. No expiry override is
available in release one. Separately justified account/member security
suspension or Owner-account revocation may remain, with reason and audit; those
controls do not rewrite paid dates or serve as cancellation mechanisms.

**Proposed one-drawer procedure:** Owner opens the `main` drawer with a recorded
counted opening float. Expected close cash is opening float plus verified
physical cash receipts assigned to that session, including receipts awaiting
allocation; this is distinct from confirmed-income totals and membership
eligibility. Exclude receipts known not received or voided. GCash and bank
transfers are reconciled separately and excluded from cash. At close, Owner
records actual count, expected total, variance, explanation, timestamps and
actor. A closed snapshot is immutable. Correcting a transaction afterward
creates an adjustment linked by FKs to the approved correction, its original
verified cash receipt, the closed reconciliation for that receipt's same drawer
session, the Owner actor, and idempotency operation only if evidence changes
expected physical cash after close. Its signed `delta_minor` is corrected
expected physical cash for that receipt minus its prior expected cash: a false
or unreceived cash receipt is negative; a verified amount increase is positive.
It changes expected cash, not actual movement or the counted snapshot. An
allocation-only target change changes income classification but not drawer
cash, so it creates no adjustment. Corrections before close affect expected
cash directly. GCash and bank corrections never affect the drawer. Automatic
cash/non-cash method reclassification is held for explicit Owner resolution.
Adjustments are append-only, reasoned/evidenced and Owner-attributed, unique per
correction, and cannot duplicate a receipt delta. Never rewrite the close or
count a receipt twice. No cash-out/expense workflow is implied.
Owner chooses opening-float handling, close cadence, variance escalation and
evidence procedure.

### Privacy, retention, backup, recovery

Before live data: identify the responsible entity; review privacy notice,
processing purposes/lawful basis, member rights/contact path, incident response,
and any applicable privacy governance duties with appropriate Philippine
privacy professional. Accountant/counsel classify financial records and
recordkeeping duties. Do not assume a legal retention duration. Approve separate
retention/legal-hold/deletion schedules for profile, attendance, payment/receipt,
PIN/throttle, idempotency, audit and backup data.

Owner approves encrypted backup method, schedule, storage location/access,
retention, encryption-key custody/rotation/recovery, RPO/RTO, restore approvers,
and incident procedure. Verify actual backup/export/restore capability, storage
limits, quotas and price against the selected Supabase plan; do not promise
provider backups, PITR, unlimited storage, or free features without checking.
Restore drills use synthetic data in isolation; production restore is
Owner-authorized and never makes data available to Developer. Hash-chain audit
events and anchor signed digests outside the database; Owner chooses anchor
custody/cadence and retention.

## Schema integrity: proposed invariants vs trusted-server work

Database-enforceable where supported: PK/FK; `ON DELETE RESTRICT` for
historical/financial rows; nullability and kind/target checks; positive amount
and exactly-one-month checks; unique normalized-mobile HMAC; unique walk-in
effective-payment pointer; unique request/idempotency scope; partial unique
`(member_id,gym_local_date)` for valid member attendance; unique one attendance
per walk-in request; immutable append-only event grants/triggers; supporting
indexes for every FK; non-overlap via a locked member row and transaction (or a
validated exclusion constraint); single open cash session; state projection
constraints.

Trusted server responsibilities: authenticate current Owner; never trust client
role/status/date/amount/fee; private PIN verification/throttles; calculate
Manila date and month boundaries; validate full payment and approval; serialize
correction and walk-in state transitions; enforce idempotency; authorize
bootstrap/recovery; create audit event and chain-head update in the same
transaction. If audit append or audit-chain update fails, abort the protected
business transaction. No direct client table writes for privileged operations,
no arbitrary SQL endpoint, and no service-role secret in browser.

Idempotency keys are scoped by operation and actor/device as applicable, with a
keyed fingerprint and safe terminal outcome. Reserve the key first and commit
reservation, business effects and audit together. Same key/same fingerprint
replays outcome; same key/different fingerprint fails. Keep key record at least
as long as the associated operation can be retried; exact deletion timing awaits
record-specific retention approval.

## Four technical blocker resolutions (proposed, not implemented)

The detailed contracts are in `schema-proposal.md` and
`database-security-design.md`. This section records the decisions together so
they can be reviewed as one design. None has been tested or implemented.

### 1. Payment confirmation correction

**Proposed model:** immutable source-receipt ledger, separate allocation ledger,
append-only payment/correction events and rebuildable effective-payment
projections. `payment_records` represents actual money received, with no target
columns. `payment_allocations` assigns the whole receipt to one purchase or
walk-in request; an unresolved receipt remains reviewable. No allocation means
no qualifying payment, membership access, or valid walk-in attendance. Reports
separately show five non-additive categories: (1) verified money actually
received, with each verified non-voided receipt counted once; (2)
unmatched/unresolved receipts, separating unverified claims from verified but
unallocated/unresolved items; (3) approved underpaid receipts, a subset of
verified received money; (4) qualifying exact full payments; and (5) an
operational confirmed membership-payment total containing only qualifying
membership receipts. Categories overlap and must not be added. An underpaid
receipt is allocated once with immutable `approved_underpaid` outcome; it is
not qualifying, does not reduce amount due, create credit, or confer access.
A later distinct exact full receipt may qualify on its own without
voiding/correcting the underpayment; it alone becomes effective. The earlier
receipt remains traceable and counted once. No installments or automatic
refund/deletion. Owner/accountant confirmation is required for the accounting
label/treatment before live financial reporting. `payment_events` uses
`recorded -> confirmed -> confirmation_voided_in_error` or `recorded ->
rejected`; the void event reverses an erroneous confirmation only and never
means money was returned. A `payment_corrections` case references the original,
kind (`void_false_receipt` or `replace_misrecorded_receipt`), required reason,
evidence/reference, Owner actor and server timestamp. Decision events are
append-only (`proposed -> approved|rejected`); one open case per original.

For a corrected receipt fact, create an immutable replacement receipt and
`payment_replacements` link for the same evidenced actual receipt; atomically
void the original and remove its allocation pointer. For a corrected target,
retain the receipt and replace only the allocation under an audited Owner
correction. Unique current-allocation/effective-payment pointers prevent double
count. For a false confirmation with no actual receipt, create no replacement.
Effective income derives reproducibly from verified receipt and current
allocation/event history. No refund or cash movement is represented.

Alternatives considered: (A) editing the original receipt/allocation row is
rejected because it destroys what was entered and confirmed; (B) appending only a
negative/reversal amount is rejected because it can look like a refund and does
not clearly distinguish a false confirmation from money returned; (C) the
chosen correction case plus immutable replacement receipt/allocation and effective pointer
preserves the original, explains the decision, and makes double counting
constraint-checkable. A replacement is allowed only for the same evidenced
receipt, not to turn an underpayment into installments.

If confirmation already enabled membership, remove the effective pointer, put
the purchase in `payment_review`, make access ineligible, and append impacts for
affected check-ins. If it validated a walk-in, change request `valid ->
payment_review` and derive linked attendance as `invalidated_payment`. Preserve
the original check-in decision and row; do not erase history. Re-evaluate
dependent early renewals under the same locks. An expired walk-in request stays
expired; a new attempt needs a new ID and current fee. No free term or partial
payment results.

### 2. Canonical transaction order and pseudocode

All workflows reserve idempotency first, then lock applicable rows in this
single order; within each class, sort by primary key: (0) idempotency
`(operation,actor_scope,key)` unique claim; (1) singleton settings; (2) member;
(3) purchase; (4) entitlement; (5) walk-in request; (6) cash drawer session;
(7) payment; (8) correction/effective-payment projection; (9) attendance or
member/date decision key; (10) reconciliation/adjustment stream; (11) audit
chain heads sorted by stream key. Skip unused classes. Settings reads hold a
share lock; settings writes take an exclusive lock. No network or human action
occurs while locks are held.

Idempotency is unique on `(operation,actor_scope,key)`: Owner operations use the
authenticated Owner UUID; offline sync uses Owner UUID plus installation UUID;
public operations use the fixed `public` scope and a cryptographically random
client operation key (never a raw member ID/mobile). The payload fingerprint
is keyed and excludes PIN/PII. Same scope/key/fingerprint returns the saved
outcome; same key with another fingerprint is rejected.

```text
BEGIN
  reserve unique idempotency key + keyed fingerprint
  if prior committed key: same fingerprint => return saved result; else reject
  lock settings, member, purchase, entitlement, request, drawer,
       payment, correction/projection, attendance, reconciliation in that order
  verify current Owner JWT where required; derive Manila date from server time
  recheck target snapshots, actual receipt, approval/payment/expiry/duplicates
  apply all state/projection/impact changes; append typed audit event/subjects
  persist safe idempotency outcome
COMMIT
```

Payment confirmation, entitlement activation, walk-in payment/attendance,
correction and impacts, cash close/adjustments, audit, and idempotency outcome
commit or roll back together. Membership check-in locks the member before
rechecking purchase/entitlement/effective payment and inserts using server
`Asia/Manila` date. Early renewal locks the member and entitlement chain, starts
the next date after inclusive expiry, and rejects overlaps/future prepayment.
Cash confirmation and close both lock drawer before payment rows. The partial
unique daily check-in index, unique effective-payment pointers, unique
replacement links, one-open-correction index, one-open-drawer index, and unique
idempotency key remain mandatory final guards despite locks. Retry only
serialization/deadlock errors with the same key/fingerprint under a bounded
server policy; after exhaustion return retry-safe failure. No success before
commit; audit/idempotency failure aborts the business change.

### 3. Relational constraints and target integrity

Primary/foreign keys and actions are detailed in `schema-proposal.md`. Core
contracts: purchase PK with non-null RESTRICT member/plan/Owner FKs and
`term_months=1`, positive price, immutable snapshot and status CHECK;
entitlement unique purchase FK, composite `(purchase_id,member_id)` FK to
purchase and non-overlap enforced after locking member; effective payment
target PK plus unique payment FK. Payment rows have exclusive nullable purchase
or walk-in target FKs with a kind CHECK, positive amount and matching currency;
cash-session FK is present iff cash method. Payment correction/replacement
linkage is one-to-one by unique RESTRICT FKs and a correction can have only one
open case.

Walk-in request PK links to a fee-version FK and immutable positive PHP snapshot
with `expires_at > created_at`; it does not point back to attendance. Allocation
has exclusive target FKs. Walk-in effective payment has request PK, allocation
UNIQUE, plus `UNIQUE(request_id,allocation_id)`. Attendance has CHECKed
member vs walk-in target columns; member attendance includes a composite FK to
its member's entitlement; walk-in attendance includes a composite FK from
`(walkin_request_id,walkin_payment_id)` (allocation ID) to the same effective
allocation pair.
There is a unique walk-in check-in per request and a partial unique
`(member_id,gym_local_date)` for accepted valid member check-ins. Every FK column
is indexed. This makes payment-for-A plus attendance-for-B impossible at the
constraint/transaction boundary. A check-in later marked `invalidated_payment`
remains in the original unique-day guard as an accepted attendance attempt;
this prevents a second same-day record after a correction.

Owner-approved impact rule: invalidated check-ins are excluded from valid
attendance totals and remain visible in history. If a separate valid payment
independently supports the check-in, only a separate documented Owner
resolution referencing that payment allocation may derive
`valid_by_owner_resolution`. The source check-in and invalidation event remain
unchanged. Test projection/report behavior and correction races before relying
on this design.

Audit subject and idempotency result links use typed nullable FK columns/rows,
with an at-most-one target CHECK where a result has one target. No polymorphic
`type + UUID` is represented as a real FK. Multi-subject audit events use
`audit_event_subjects` rows, exactly one typed RESTRICT FK per row. Audit append
and subject links fail the protected transaction if any reference is invalid.
Typed subject columns include real FKs to `payment_allocations` and
`attendance_validity_resolutions`, as well as the existing subject tables; every
FK is indexed and `ON DELETE RESTRICT`, preserving referenced allocation and
resolution history.

### 4. RLS, grants, and trusted-function boundary

| Data/operation | Anonymous QR visitor | Authenticated Owner | Trusted server-side executor | Developer |
|---|---|---|---|---|
| Member/profile/PIN/registration | No table grants; only fixed public registration/check-in endpoint; no directory or status | Restricted read view; mutations via Owner operation; no PIN/hash read | Exact lookup + PIN verification or validated Owner profile operation; private access only | Source and synthetic data only; no production database role/project membership or routine live data |
| Plans/purchases/entitlements | No table grants | Read view; purchase/approval/renewal via Owner operation | Enforces approval, payment, date, non-overlap | No production access |
| Receipts/corrections/effective payments/cash | No table grants or payment operation | Read view; confirm/correct/reconcile through Owner operation | Rechecks actual receipt and target; atomic projection/correction | No production access |
| Walk-in requests/attendance/offline claims | Fixed registration submission, request creation, and member check-in endpoints only; cannot set fee/status/date or read records | Read view; Owner confirmation/offline submission operations | Server assigns fee snapshot; authenticates Owner for confirm/sync; enforces eligibility and uniqueness | No production access |
| Settings/idempotency/audit | No table grants | Restricted views and named operations | Narrow private procedures; audit append in same transaction | No production access |

Enable RLS on exposed tables and default-deny `anon` and `authenticated` base
table DML; private schemas are not Data API exposed. Use separate
`NOLOGIN`/`NOSUPERUSER`/`NOBYPASSRLS` `gym_public_executor` and
`gym_owner_executor` function-owner roles, neither table owners nor assumable
by callers, plus separate non-login `gym_table_owner`. Give executors only
required table grants and role-targeted policies; force RLS on private business
tables. Prefer `SECURITY INVOKER` for reads. Narrow definer functions are owned
by the matching executor, set `search_path = ''`, schema-qualify every
reference, and prohibit dynamic SQL. Revoke `EXECUTE` from `PUBLIC` and grant
only exact fixed public functions to `anon` and Owner functions to
`authenticated`. RLS is defense in depth. Owner functions verify the signed
JWT `auth.uid()` against active `owner_access` on every call, ignoring supplied
actor IDs, metadata, prices, payment/attendance states and dates. Public
functions accept no client-established membership identity/status facts, and
never expose table reads or generic SQL. No direct client DML to business
tables, valid attendance, effective-payment projections, PIN material, or
audit tables. Any audit event/typed reference/chain-head/idempotency write
failure rolls back the full mutation. The normal request path uses caller JWTs,
not a service-role credential; never expose privileged secrets in browser code.

The public PIN endpoint rate-limits before KDF, uses generic responses and
timing protection, and returns no existence, profile, membership, payment or
attendance detail. It accepts no client member UUID or status. Public walk-in
creation accepts no price/status/payment/date values. The normal server path
forwards the caller JWT to a narrow RPC and uses no service-role credential.
Any future exception requires separate Owner approval and server-only secret
storage plus request-level identity/Owner validation. Never expose or log the
key. Audit failure aborts the transaction.

## Remaining Owner decisions and technical blockers

This review does not approve the schema. The proposal now records the two new
Owner decisions and is ready to present for the Owner's final design approval,
subject to the implementation-validation blockers below. Approval would accept
the proposed behavior, not certify PostgreSQL/RLS implementation.

The two decisions formerly open in the prior review are now Owner-approved:
preserve/review and correctly allocate unmatched/underpaid receipts without
double counting, and invalidate payment-dependent attendance while preserving
history, with any independent restoration requiring separate documented Owner
resolution. They are recorded in `phase-3d-decisions.md` and the schema
proposal. The five report categories and underpayment treatment specified here
are proposed operational classifications, not an approved accounting policy.
The Owner/accountant must confirm category labels and accounting treatment
before live reporting. Correction evidence and practical independent review
remain operational decisions; no accounting/legal conclusion is invented here.

Remaining technical blockers before migrations:

1. A database designer must translate the proposed composite and cross-table
   constraints, exclusion/overlap protection, partial unique indexes,
   projection maintenance and correction-cycle guard into valid PostgreSQL
   definitions without weakening these invariants.
2. Review final Supabase grants, RLS policies, `SECURITY DEFINER` ownership,
   execute grants, JWT forwarding, safe `search_path`, and private-schema
   exposure against the actual deployment architecture.
3. Obtain a disposable local PostgreSQL/Supabase test environment and validate
   the concurrency, rollback, RLS and correction cases in the security test
   plan. These proposals are not tested.

Operational pre-launch approvals and provider checks remain listed above.
## Remaining Owner operational approvals and pre-launch checks

- Exact PIN KDF cost/rate thresholds after implementation benchmarking on
  synthetic data; no unapproved values in production.
- Final privacy notice wording and record-specific retention, provided no real
  member data is collected before professional review and approval.
- Backup cadence, RPO/RTO and restore rehearsal, provided production data is not
  entered until plan capabilities, key custody and restore controls are set.
- Optional profile fields, multi-location/multiple drawers, and staff roles;
  keep them out of release one unless scope is re-approved. Membership
  cancellation and expiry override remain excluded.
- Independent audit anchor cadence and incident playbook details, provided
  audit events are append-only and transactional from the first migration.

## Final schema approval checklist

- [x] Confirmed: Option A month calculation, activation date, leap-year and
      month-end examples, inclusive expiry, consecutive and lapsed renewal.
- [x] Confirmed: public provisional walk-in request, stable ID, fee snapshot,
      Owner actual-payment confirmation and atomic validation; set request
      lifetime before accepting walk-ins.
- [x] Confirmed: offline claims remain provisional, 24-hour age is triage only,
      and device time cannot prove historical attendance.
- [ ] Correction evidence and any external-review procedure are operationally
      defined. Owner-only in-app approval is confirmed; no maker/checker exists.
- [x] Confirmed: unresolved receipts are preserved; only Owner verification and
      correct unique allocation can make a receipt eligible for income
      classification; payment status remains distinct from money received.
      Proposed detail: allocated underpayment is separately reported as
      received money, not confirmed membership income; a later full receipt can
      independently qualify without voiding it. Owner/accountant confirmation
      of this reporting classification is required before live use. Underpayment
      never grants access or combines into installments.
- [x] Confirmed: payment-supported check-ins are invalidated on erroneous
      confirmation, excluded from valid totals and retained in history; any
      independent eligibility basis requires separate documented Owner
      resolution and never rewrites the original.
- [ ] PIN abuse thresholds, token lifetime and KDF parameters validated using
      synthetic abuse tests; reset identity procedure documented.
- [ ] One-time Owner bootstrap/recovery and MFA method documented; Developer
      deployment/emergency permissions bounded without routine live-data access.
- [ ] Security suspension/reinstatement procedure, mobile-change verification,
      cash workflow, and privacy/accounting review are recorded. Initial member
      fields are confirmed as member code, full name and unique normalized mobile.
- [ ] Each table has exact columns/types/nullability, PK/FK actions, checks,
      uniqueness, indexes, states and access grants documented.
- [ ] RLS/default-deny, trusted-function authorization, audit-abort behavior,
      idempotency and concurrent race protections are reviewed.
- [ ] Retention, backup/restore, key custody and actual Supabase plan limits are
      confirmed before live data.
- [ ] Synthetic security tests can run in a disposable local
      Supabase/PostgreSQL environment; no production data or credentials used.
- [ ] Run proposed security tests 63–65 and 69–73 in the disposable environment:
      report categories and underpayment/full-receipt behavior, projection and
      cash separation, adjustment idempotency/cross-FKs, typed audit subjects,
      grants/function ownership/RLS, and atomic audit failure. No tests have
      been run for this design review.
- [ ] The four design proposals are reviewed; remaining PostgreSQL constraint,
      Supabase RLS/grant, function-context and local-test-environment blockers
      listed above are resolved before migrations.
