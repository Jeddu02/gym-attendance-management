# Proposed schema for review

**Status:** schema proposal only; no migrations, SQL, tables, policies, database
functions, or hosted-project changes have been created. Implementation requires
completion of the technical schema blockers and approval of explicitly open
operational decisions that affect schema behavior.

This proposal incorporates the finalized Owner decisions. Any legacy
manager/front-desk, cancellation, installment, or date-rule wording elsewhere
in the planning set is superseded by these rules. The initial release has one Owner management
account and one location. Membership uses anniversary-based Option A as defined
below; no cancellation or non-renewal state/workflow exists.

The Owner-approved unmatched-receipt and invalidated-check-in decisions in
`phase-3d-decisions.md` are binding requirements, not open decisions. The
receipt-allocation and attendance-resolution contracts below are proposed
database designs for implementing them.

## Global rules

- UUID primary keys; database-generated `timestamptz` record/audit times; ISO
  currency plus integer minor units for money; no floating point.
- One gym initially; `Asia/Manila` and `PHP`. Store timezone snapshots where
  local dates affect eligibility/reconciliation. Never recalculate history.
- Enforce at most one valid member check-in per member and gym-local date with a
  partial unique index. The server derives the date from receipt time.
- Membership Option A: from activation date, advance one calendar month and
  clamp to the target month's last day to obtain the next-term start; expiry is
  the preceding calendar date, inclusive through the full gym-local date. For
  Jan 31 this gives Feb 28/29 next-term start and Feb 27/28 expiry; Feb 28 in a
  normal year advances to Mar 28 and Feb 29 in a leap year to Mar 29.
- Access requires approved registration and one complete, confirmed payment
  equal to the purchase amount. Partial payments/installments are prohibited;
  pending/rejected payments are not income. No refunds, complimentary
  memberships, cancellation/non-renewal, freeze, expiry override, checkout, or
  member-login state.
- Preserve financial, attendance, registration-decision, PIN-reset, settings,
  and security history through append-only records/events. Historical FKs
  normally use `ON DELETE RESTRICT`.
- Encrypt sensitive profile fields and use versioned server-held encryption and
  keyed-lookup keys. Do not expose searchable plaintext mobile numbers via the
  Data API.
- Developer membership is an ordinary member record only, subject to the same
  rules as everyone else. Do not link it to Owner Auth or a management role.
  Keep source/deployment identity separate from gym-member identity.

## Table-by-table proposal

| Table | Purpose and important fields | Keys, constraints, and indexes |
| --- | --- | --- |
| `owner_access` | The one authorized management identity: `auth_user_id`, status, activation time, bootstrap reference. | PK/FK `auth_user_id -> auth.users.id`; singleton constraint; role is fixed as Owner. Disable public sign-up/bootstrap after first activation. Index status. |
| `gym_settings` | Single-location IANA timezone, currency, active privacy-notice version, settings version, changed-at/by. Version walk-in fees separately. | Singleton PK/check; timezone validated against PostgreSQL metadata; initial currency `PHP`; no silent historical edits. Owner-only trusted updates. |
| `gym_setting_events` | Append-only old/new safe settings, actor, reason, effective time, request ID. | PK; FK actor to `owner_access`; index `(setting_key, recorded_at)`; exclude secrets and unnecessary PII. |
| `member_profiles` | Random member-code ciphertext and unique keyed lookup; encrypted full name/mobile; unique keyed normalized-mobile HMAC and key version; registration status (`pending`, `approved`, `denied`, `suspended`); approval metadata/timestamps. | PK UUID; unique HMACs; index `(registration_status, created_at)`; approval actor FK Owner. No `auth.users` FK or public listing. Initial profile is member code, full name, unique normalized mobile only. |
| `registration_applications` | Application projection with member, status, submitted time, current review state. New application follows denial; decisions are preserved separately. | PK; FK member; partial unique pending application per member; status check; index `(member_id, created_at)`. |
| `registration_decision_events` | Append-only approve/deny/suspend/reinstate decisions, Owner, reason, time, request/idempotency ID. | PK; FKs member/application/Owner; indexes member/time and actor/time. Update current projection and append event in one transaction. |
| `member_pin_credentials` | Current Argon2id encoded verifier (salt included), pepper key version, credential version, changed time. | PK/FK member; private schema/no Data API grants. No plaintext PIN or verifier in audit/logs/client. Pepper only server-side. |
| `member_pin_tokens` | Single-use setup/reset token hash, member, purpose, issue/expiry/use times, attempts, invalidation data. | PK; FKs member/issuing Owner; unique token hash; expiry check; partial index for unconsumed member/purpose. Store no raw token; invalidate prior token on replacement. |
| `pin_attempt_buckets` | Pseudonymous identifier/network/device bucket, window start, count, blocked-until, expiry. | Composite PK or unique bucket/window; private server-only; atomic upsert/lock. No raw mobile, IP, or PIN; no permanent lockout. Threshold/retention unresolved. |
| `membership_plans` | Owner-configured code/name, `term_months = 1`, `price_minor > 0`, currency, sellable flag, effective timestamps. | PK; unique code; exact one-month and positive-price/currency checks; index sellable/effective date. Revisions do not alter purchases. No complimentary plan. |
| `membership_purchases` | Member, plan reference, one-month term/price/currency snapshots, Owner creator, status (`pending_payment`, `paid`, `payment_review`), created time. | PK; FKs member/plan; `term_months = 1`, positive snapshot checks; indexes member/time and status. Paid only after exactly one effective confirmed payment equals the purchase snapshot and member is approved. No cancellation state or operation. |
| `membership_entitlements` | Purchase/member, `starts_on`, `expires_on`, stored timezone, status (`active`, `suspended`), activation actor/time. Every purchase has exactly one calendar-month term. | PK; unique FK purchase; FK member; `expires_on >= starts_on`; create/extend under a member-row lock and reject any date-range overlap; index `(member_id, starts_on, expires_on)` and status. Early renewals extend consecutively; lapsed terms start on activation. Recheck approval and full confirmed payment on access. No non-renewal/cancellation state. |
| `membership_lifecycle_events` | Append-only activation, renewal/extension, suspension, reinstatement with old/new dates, Owner, reason, request ID. | PK; FKs entitlement/member/Owner; index `(entitlement_id, recorded_at)`. No cancellation, refund, or checkout event; plan edits do not rewrite paid dates. |
| `walkin_requests` | Stable random `request_id` (PK), status (`provisional`, `valid`, `rejected`, `expired`, `payment_review`), source, server timestamps, required expiry, fee-version FK, immutable positive amount and `PHP` currency snapshot. No member identity required by default. | PK; FK fee version; check snapshot equals that version at creation; index `(status, expires_at)` and fee-version FK. This is the payment target and exists before any payment. It has no FK back to attendance; attendance references request, avoiding a cycle. Public input cannot set fee, amount, currency, expiry, or valid status. Expired request cannot be revived; new request gets new ID/current fee. Lifetime is an Owner-configured operational setting. `payment_review` follows a voided erroneous confirmation; expired request cannot be reused. |
| `payment_records` | Immutable source-of-funds receipt independent of allocation target; positive actual amount, PHP currency, method, protected evidence reference, server receipt/record time and Owner recorder. | PK; positive amount; cash-session FK iff cash; append-only; no target columns. Unallocated/unverified receipts remain reviewable and are not confirmed income. Index `(method, recorded_at)`, cash session and actor/time. |
| `payment_allocations` / `payment_allocation_events` | Immutable allocation of one whole receipt to one purchase or walk-in request, plus append-only Owner approval/rejection/void decisions. | RESTRICT FKs; CHECK exactly one nullable target FK by kind; source amount/currency exact; one current allocation per receipt; indexes all FKs/targets. Multiple receipts may be attributed to a purchase for traceability, but never summed for access. `approved_underpaid` is reported separately as received money, not confirmed membership income; one exact full receipt alone may qualify. |
| `current_receipt_allocations` | One current approved allocation pointer per source receipt. | Receipt PK/FK; allocation UNIQUE/FK; composite FK requires matching receipt ID; trusted transaction swaps projection atomically with allocation events and audit. |
| `membership_payment_effective` | One effective confirmed full-payment allocation per membership purchase. | `purchase_id` PK/FK; unique `allocation_id` FK. Source receipt verified and allocation approved/current; exact amount/currency equals purchase snapshot; atomically changed only through authorized correction. |
| `payment_events` | Append-only `recorded`, `confirmed`, `rejected`, `confirmation_voided_in_error` events for receipt verification. | PK; FK payment/Owner; index `(payment_id, recorded_at)`. Confirmed membership income requires a verified receipt, current approved allocation, and exact full-purchase eligibility; approved-underpaid amounts remain a separate received-money classification. Void-in-error does not assert refund or returned money. |
| `walkin_payment_effective` | One current effective confirmed full-payment allocation per walk-in request. | `request_id` PK/FK; unique `allocation_id` FK; amount/currency equal fee snapshot. Private projection rebuilt from receipt, allocation, and payment events; updated atomically with request validity, attendance, and audit. |
| `payment_corrections` | Immutable case linked to an erroneous source receipt and, when applicable, its allocation: correction kind, reason, evidence/reference, Owner proposer and time; state derived from events. | PK; RESTRICT FKs to receipt and nullable affected allocation; composite FKs ensure allocation and `(id,original_receipt_id)` match; one open case/receipt; indexes every FK/time. Corrected allocation is a new row; receipt facts remain immutable. |
| `payment_correction_events` | Append-only approve/reject/withdraw decision with Owner, reason, time, request ID, effective-value link. | PK; FK correction/Owner; index `(correction_id, recorded_at)`. Approved correction affects the effective receipt projection; Owner is sole in-app approver and no maker/checker separation exists. External evidence/review requirements remain operational decisions. |
| `attendance_checkins` | `id`, `kind` (`member`,`walk_in`), nullable `member_id`, nullable unique `walkin_request_id`, status (`provisional`,`valid`,`rejected`,`duplicate`), source, server/client times, `gym_local_date`, timezone snapshot, Owner actor, optional offline submission FK, idempotency UUID. | PK; `member_id` FK `ON DELETE RESTRICT`; `walkin_request_id` FK `ON DELETE RESTRICT`; row check requires exactly `member_id` for member kind or `walkin_request_id` for walk-in kind; server-only valid/date/timezone; check source-kind compatibility. Partial unique `(member_id,gym_local_date)` for valid member rows; unique walk-in request FK; unique `(operation,idempotency_key)` or FK to idempotency row; indexes all FKs, `(gym_local_date,status)`, `(server_received_at,status)`. Walk-in validity is committed with its confirmed payment event in one transaction. No checkout fields. |
| `offline_sync_submissions` | Append-only sync receipt: Owner Auth ID, device UUID, opaque member ref, client/server times, keyed payload fingerprint, outcome, resulting check-in. | PK; unique `(owner_user_id, idempotency_key)`; FKs Owner/member/check-in; indexes outcome/receipt and member. No PIN/mobile/profile/payment/eligibility snapshot. |
| `walkin_fee_versions` | Owner-configured positive fee/currency/effective range, snapshotted per walk-in. | PK; positive amount; PHP; non-overlapping effective periods enforced transactionally; Owner actor FK. Amount unset until approved. |
| `request_idempotency` | Operation, UUID key, keyed request fingerprint, safe outcome/entity reference, recorded time. | PK; unique `(operation, idempotency_key)`; private; no raw body/PIN/mobile. Same key/fingerprint returns prior result; changed payload rejected. Retention unresolved. |
| `cash_drawer_sessions` | One `main` drawer: open/close time, opening float, Owner opener/closer, status. Cash payments link here. | PK; float `>= 0`; partial unique open session per drawer; indexes drawer/status/time. Closed sessions are immutable. |
| `cash_reconciliations` | Immutable close snapshot: session, expected physical cash receipts, count, variance, count/review actor, reason, time. | PK; unique FK session; expected/count nonnegative; variance equals count minus expected; index session/time. Drawer reconciliation is distinct from confirmed-income classification. Procedure unresolved. |
| `cash_reconciliation_adjustments` | Append-only post-close expected-physical-cash delta linked to the approved correction event, original cash receipt, same-session closed reconciliation, approving Owner, and idempotency operation. | PK; composite RESTRICT FKs enforce receipt/correction/reconciliation/session/Owner actor match; unique correction; nonzero signed delta (`corrected expected - prior expected`); allocation-only and GCash/bank changes create none. Never rewrites close or represents a refund/new receipt/movement. |
| `member_privacy_events` *(only if needed after legal review)* | Notice version/date shown and acknowledgment; separate consent evidence only where approved lawful basis is consent. | PK; member FK; notice version/purpose/time/minimal evidence. Acknowledgment is not automatically consent; DPO/counsel decides model. |
| `audit_events` | Append-only action/entity, actor kind/Owner, UTC time, reason, request ID, minimal redacted metadata, previous/event hash. Covers decisions, payments, attendance, PIN, settings, backup, security. | PK UUID/sequence; Owner FK where applicable; indexes entity/time and actor/time; app roles cannot update/delete. Never store secrets, raw PIN/mobile/token, or full PII/financial snapshots. |
| `audit_chain_heads` | Per-entity/request stream key, last event ID/hash, update time. | PK stream key; FK last event; lock only affected stream. Signed external anchor storage/cadence requires Owner decision. |

### Relationships and index summary

- One member has many applications, purchases, entitlements, payments, and
  check-ins. One purchase has one entitlement and one effective full confirmed
  payment; payments can have correction histories. Developer's member record
  is not linked to `owner_access`.
- A walk-in may have attempted payment entries, but its row is locked and at
  most one effective fee payment can be confirmed. Confirmation and valid
  attendance transition happen in one transaction.
- Index every referencing FK used for joins (PostgreSQL does not automatically
  index referencing columns), plus member status/mobile HMAC, purchase
  status/member, entitlement member/date, payment targets/events, attendance
  member/date, offline Owner/idempotency/outcome, cash session, and audit
  actor/entity/time.
- Keep PIN/token/rate/audit data private or revoke Data API access. Do not
  publish private tables to Realtime.

### Proposed access matrix

RLS and grants default-deny. This is an access design, not implemented policy.

| Table | `anon` | Owner Auth user | Trusted server-side function |
|---|---|---|---|
| `owner_access` | No table access | No direct writes; bootstrap/recovery operation only | Verifies current actor; controlled one-time bootstrap and recovery |
| `gym_settings` | No access | Narrow settings read; change via Owner operation | Reads effective settings; validates configuration |
| `gym_setting_events` | No access | Read through audit/settings view | Appends versioned changes atomically |
| `member_profiles` | No access; public endpoint accepts identifier/PIN only | Minimum operational read; edits via audited operation | Private identity lookup/validation; generic public response |
| `registration_applications` | No access | Read/review via Owner operation | Creates/submits application and enforces pending uniqueness |
| `registration_decision_events` | No access | Read; no direct mutation | Appends Owner decision atomically with current projection and audit |
| `member_pin_credentials` | No access | No direct read/write | Private verifier access only; never returns verifier or PIN |
| `member_pin_tokens` | No access | Invoke setup/reset only; no token-hash read | Issues/consumes private single-use token; never returns stored hash |
| `pin_attempt_buckets` | No access | No direct access | Atomic private throttle updates; no raw identifier/network value |
| `membership_plans` | No access | Read and edit through Owner operation | Validates one-month positive-price plan revision; history preserved |
| `membership_purchases` | No access | Minimum read; create through Owner operation | Requires exactly one full effective confirmed payment and approved registration |
| `membership_payment_effective` | No access | No direct access | Maintains one full effective payment per purchase atomically |
| `membership_entitlements` | No access | Read and lifecycle operations; no direct date edits | Enforces activation, renewal adjacency, eligibility and non-overlap |
| `membership_lifecycle_events` | No access | Read; no direct mutation | Appends authorized lifecycle event atomically |
| `payment_records` | No access | Minimum review view; immutable original | Records actual receipt claim independent of target |
| `payment_allocations`, `payment_allocation_events` | No access | Review and allocate/approve through Owner operation | Verifies exact source receipt, enforces one current target allocation, and appends decision |
| `current_receipt_allocations` | No access | No direct access | Maintains one current allocation per receipt atomically |
| `payment_events` | No access | Read; no direct mutation | Appends receipt verification/void-in-error events |
| `payment_corrections` | No access | Read and propose/approve through Owner operation | Creates immutable proposal; serialized approval |
| `payment_correction_events` | No access | Read; no direct mutation | Appends Owner decision and effective-value link |
| `payment_replacements` | No access | Read via restricted payment view | Links old/new receipt rows in approved same-receipt correction |
| `attendance_payment_impacts`, `attendance_validity_resolutions` | No access | Read via restricted attendance view; resolve through Owner operation | Appends invalidation impacts or separately supported resolution; never edits check-in |
| `attendance_validity` | No access | Restricted read view | Rebuildable derived validity projection; no direct writes |
| `walkin_fee_versions` | No access | Read/configure through Owner operation | Versions positive fee; prevents overlapping effective intervals |
| `walkin_requests` | No table access; public request endpoint only | Read and confirm through Owner operation | Creates stable expiring request and immutable fee snapshot; rejects expired requests |
| `walkin_payment_effective` | No access | No direct access | Maintains one effective confirmed payment per request atomically |
| `attendance_checkins` | No table access; public member-check-in endpoint only | Read; submit offline provisional claims; cannot set `valid` directly | Checks eligibility/date/idempotency and duplicate constraints |
| `offline_sync_submissions` | No access | Submit/read own Owner-device claims through operation | Revalidates Owner, member and current date; stores terminal result |
| `request_idempotency` | No access | No direct access | Atomic reserve/replay check and stored safe outcome |
| `cash_drawer_sessions` | No access | Read and Owner-only open/close operations | Enforces one open session per drawer |
| `cash_reconciliations` | No access | Read; close through Owner operation | Calculates expected cash and immutable close snapshot |
| `cash_reconciliation_adjustments` | No access | Read; append via Owner correction operation | Appends separately authorized adjustment; never rewrites close |
| `member_privacy_events` | No access | Narrow read/record operation as approved | Records approved notice acknowledgment; no implication of consent by default |
| `audit_events` | No access | Read through restricted audit view; no insert/update/delete | Appends redacted event inside protected business transaction |
| `audit_event_subjects` | No access | Read through restricted audit view | Adds typed, FK-enforced subjects atomically with audit event |
| `audit_chain_heads` | No access | No direct access | Locks/updates stream head atomically with event append |

Developer source/deployment identity receives no database role, project
membership, production secret, or live/restored member-data access by default.
Their separate ordinary member record grants only the public member flow.

## Membership lifecycle and dates

Proposed transitions are `application pending -> approved/denied`,
Transitions are application `pending -> approved/denied`, purchase
`pending_payment -> paid/payment_review`, and entitlement activation plus
separate audited security suspension/reinstatement. No membership cancellation,
non-renewal, freeze, or expiry-override state/operation exists.

Activation date is the later gym-local date of registration approval and full
confirmed payment. Delayed confirmation never backdates access. Exactly one
complete confirmed payment equal to the immutable purchase amount is required;
no installment or partial-payment path exists. A membership purchase starts its
first entitlement on the activation date. For early renewal, the new term starts
on the day after existing inclusive expiry. For a lapsed member, the new term
starts on its new activation date. Terms cannot overlap or be prepaid arbitrarily
far ahead.

Finalized Option A: from a term start/activation date, advance one calendar
month and clamp the result to the target month's last date; this is the next
term start. Inclusive expiry is the preceding calendar date. Jan 31 advances to
Feb 28 in a normal year or Feb 29 in a leap year, so expiry is Feb 27/28.
Feb 28 in a normal year advances to Mar 28; Feb 29 in a leap year advances to
Mar 29. Store local business dates as `date` with the IANA timezone snapshot;
store event times as UTC `timestamptz`. Access remains valid for the whole local
`expires_on` date and fails at the following local midnight.

## Payment and correction integrity

1. Recording a payment creates an immutable claim and `recorded` event.
2. Owner verifies actual cash receipt or actual GCash/bank settlement through
   the approved channel and appends `confirmed`; screenshots alone do not
   confirm transfer receipt.
3. A rebuildable accounting view includes a receipt only when its verification
   is confirmed and it has one current approved allocation; exclude rejected,
   voided, and unallocated receipts. A corrected allocation replaces the old
   allocation for that same source receipt; never create a second receipt.
   Membership eligibility is separately based on one exact full effective
   allocation. Pending/rejected corrections have no effective-payment effect.
4. A correction points to an original record, requires a reason, and is an
   immutable proposal/event. It never rewrites the original, issues a refund, or
   creates a cash movement. Exactly one whole effective payment equal to the
   purchase amount is allowed; a partial amount is never carried forward as an
   installment. If an erroneous payment is voided, access is blocked until one
   new, complete actual payment is confirmed. A metadata-only correction may
   preserve the existing verified receipt and allocation if evidence supports it.
5. Owner-only approval without a second management account is a known
   concentration risk. Require evidence/reference and preserve the single-actor
   audit trail; periodic independent review is recommended where practical.
   No maker/checker separation exists.

### Proposed receipt, allocation, and correction ledger contract

The immutable `payment_records` row is the canonical fact that actual money
was reported received. It is independent of membership/walk-in targets.
`payment_events` records `recorded`, `confirmed`, `rejected`, and
`confirmation_voided_in_error` as append-only receipt-verification events. A
void-in-error event means the confirmation was erroneous; it never asserts
money was returned or creates a cash outflow. There is no refund event, status,
or endpoint. Keep five non-additive operational report categories separate:
(1) **verified money actually received**, counting every verified,
non-voided source receipt once regardless of allocation; (2)
**unmatched/unresolved receipts**, separating unverified claims from verified
but unallocated or unresolved receipts (only the verified subset appears in
category 1); (3) **approved underpaid receipts**, a subset of category 1
allocated once to a purchase below its full snapshot; (4) **qualifying full
payments**, exact full receipts with a current approved allocation and valid
confirmation; and (5) **operational confirmed membership-payment total**, only
qualifying full membership receipts. Categories overlap and must never be
summed together. Unverified claims are not verified money received.
Underpayments never qualify, reduce amount due, become installment credit, or
count in category 5. A later independent exact full receipt may qualify on its
own without voiding the earlier underpayment. The Owner/accountant must confirm
the category 5 label and accounting treatment, including whether approved
underpayments count as accounting income, before live financial reporting;
these operational categories are not an accounting or legal conclusion.
Walk-in income requires its exact fee and valid attendance transaction.

`payment_allocations` assigns the whole receipt to exactly one purchase or
walk-in request through exclusive nullable typed FKs. `payment_allocation_events`
records Owner approval, rejection, and voiding with reason, actor, request ID,
and server timestamp. The immutable source amount/currency is copied exactly;
no split, multiple target allocation, or double count is allowed. A lower
amount than the purchase snapshot may be correctly allocated and counted once
as verified received money, but it cannot create paid status/access and cannot
be combined with another receipt. A receipt allocation for a walk-in must
match the fee snapshot to validate attendance. A unique current-allocation
projection prevents duplicate allocation; a correction voids an allocation
before creating a separately audited reallocation. Unresolved receipts remain
in review indefinitely until Owner action and are not auto-discarded.

Use an immutable `payment_corrections` row linked by FK to the original
payment. Required fields: `id`, `original_payment_id`, `kind` (`void_false_receipt`
or `replace_misrecorded_receipt`), mandatory `reason`, evidence/reference,
Owner proposer and server timestamp. Append-only `payment_correction_events`
records proposed/approved/rejected with decision actor, timestamp, reason, and
request ID. Only one open case per original payment is permitted by a partial
unique index. Approval is Owner-only, serialized, and audited; the Owner may
self-approve because no second management account exists.

For `void_false_receipt`, approval appends `confirmation_voided_in_error`,
removes any current allocation/effective pointer, and records impacts to
dependent access/check-ins; no replacement receipt is implied. For
`replace_misrecorded_receipt`, create a distinct immutable replacement
`payment_records` row for the same evidenced actual receipt and link it through
`payment_replacements(original_payment_id PK/FK, replacement_payment_id UNIQUE
FK, correction_id UNIQUE FK)`. In the same transaction void the erroneous
source row, remove its current allocation, and create a new allocation to the
correct target if supported. The old and replacement receipt cannot both count;
the replacement is not a second actual receipt or refund. A correction only to
the allocation target keeps the same receipt row, voids the old allocation,
and appends the corrected allocation under an audited Owner case. Source amount
corrections require evidence and still represent that same actual receipt.

`membership_payment_effective(purchase_id PK/FK, allocation_id UNIQUE/FK)` and
`walkin_payment_effective(request_id PK/FK, allocation_id UNIQUE/FK)` are
private projections. A pointer is permitted only to an approved current
allocation whose receipt is confirmed/non-voided and whose amount/currency
exactly matches the immutable target snapshot. Each target has at most one
effective receipt. Effective income is derived from verified receipt plus its
single current approved allocation; access eligibility additionally requires
exact full amount. Projections are rebuildable and reconciled against source
events. Corrections never alter source receipts or silently delete history.

If a false confirmation already activated a membership purchase, the same
correction transaction removes its effective payment, puts the purchase in
`payment_review`, and makes its entitlement ineligible. If it validated a
walk-in, the request moves from `valid` to `payment_review` and its linked
attendance validity is marked `invalidated_payment`. In both cases append a
payment-correction attendance-impact event; keep the check-in row and original
decision immutable, and derive current validity from the event projection. A
separate append-only impact FK links the correction to each affected check-in.
No attendance or financial row is deleted. An expired walk-in request remains
expired and cannot be reused; a new attempt requires a new request ID/current
fee snapshot. Any already activated consecutive renewal or other eligibility
decision is re-evaluated under the same locks: later terms lacking their own
valid full receipt become ineligible, and dates/history are not silently
rewritten. A fresh approved purchase and complete confirmed payment are
required to restore membership access. No correction can create a
zero-price/complimentary term or partial-payment path.

#### Unmatched and underpaid receipts (confirmed requirements and proposed lifecycle)

Use `payment_records` as the immutable source-of-funds receipt ledger, with no
membership or walk-in target columns. Every receipt has a positive actual
amount, PHP currency, method, receipt time, recorder, and protected evidence
reference. A receipt starts unverified/unallocated. `payment_allocations` is a
separate append-only decision ledger that assigns the entire receipt exactly
once to one membership purchase or walk-in request; its target columns are
nullable with an exclusive target-kind CHECK and RESTRICT FKs. Allocation
events record Owner verification, approval/rejection, and any later void of a
mistaken allocation with actor, reason, request ID, and server timestamp.
Unresolved receipts remain available in an Owner review view and are never
automatically discarded.

Enforce at most one current allocation per receipt with a private unique
projection. A receipt cannot be split, applied to multiple targets, or counted
twice. Multiple distinct receipts may be allocated to one target for accounting,
but only one receipt exactly equal to the full purchase snapshot may qualify for
access; receipts are never summed. The allocation
amount and currency are copied as immutable snapshots and must equal the source
receipt; it may be less than the target's required amount. Proposed lifecycle:
the Owner verifies the source receipt and evidence, then explicitly allocates
the whole receipt to one target. If it is underpaid for a membership purchase,
record an immutable `approved_underpaid` allocation outcome. Count the receipt
once in verified-money-received reporting and, for cash, once in expected
physical cash from the time actual cash is verified/recorded—even while it is
unallocated. Its unresolved/underpaid status is an overlapping category, not
another receipt amount.
It is not confirmed membership income, does not reduce the purchase amount due,
does not create a payment balance/credit, and grants no access. Do not combine
it with another receipt as installments. For walk-ins, an underpaid allocation
cannot validate attendance or count as confirmed walk-in income.

A later distinct receipt may independently qualify the purchase without first
voiding or correcting the earlier underpayment allocation, if that new receipt
is itself Owner-verified, is exactly the immutable full purchase amount and
currency, and no other effective full receipt exists. It alone is the effective
payment for access; the earlier underpayment remains traceable as an
`approved_underpaid` allocation and a separate received-money item. Never count
one receipt twice, sum receipts for entitlement, or insert a second effective
payment pointer. A further receipt after a full effective payment exists stays
in review until the Owner resolves its target; no automatic refund or deletion
path exists. This can leave total verified receipts greater than the purchase
price; report the five categories above separately and never add overlapping
category totals. The confirmed rules are preservation, no access, no
installments, no automatic refund, and the independent-later-full-receipt rule.
Accounting treatment remains subject to Owner/accountant confirmation.

Reallocation of a mistaken target requires an Owner correction with evidence,
reason, actor, timestamp, and audit event. Append a void event for the prior
allocation and a new allocation; the prior row is never edited/deleted. Enforce
one current allocation per receipt transactionally so retries or corrections
cannot count the same receipt twice. Source receipt facts remain unchanged.
Correcting the recorded source amount/method is a separate receipt-fact
correction and replacement flow; it must preserve the original and atomically
move the current allocation pointer to the replacement. For any correction,
lock the receipt and target in canonical order and abort if its audit append
fails.

`membership_payment_effective` and `walkin_payment_effective` reference the
approved allocation ID (unique per target), not a mutable receipt target. The
allocation's composite FKs enforce that its receipt and target agree; a
membership pointer additionally requires exact full purchase amount/currency,
while a walk-in pointer requires exact fee snapshot. Income is derived from
source receipt plus its current approved allocation and correction events;
eligibility is derived separately from exact-full-payment pointers. Thus actual
money received and purchase-paid status are never conflated.

#### Invalidated attendance and independent eligibility (Owner-approved behavior)

When correction removes the payment basis for a previously accepted check-in,
append an `attendance_payment_impacts` row and derive
`attendance_validity.state='invalidated_payment'`. Valid-attendance totals
exclude it; history and audit views retain the original check-in and all
decisions. Do not update or delete that source row. If a different valid
payment independently proves eligibility for that same attendance date, the
Owner may create a separate `attendance_validity_resolutions` event referencing
the check-in and the independent effective allocation, with reason, actor,
time, and idempotency request. A transaction rechecks approval, paid dates,
physical-presence basis, and uniqueness. The projection may then report
`valid_by_owner_resolution` for valid totals, while retaining the original
invalidation and check-in history. No automatic restoration or complimentary
eligibility is allowed. If the separate basis does not meet all checks, retain
`invalidated_payment`.

### Proposed key and constraint contract

- `membership_purchases`: PK `id`; non-null RESTRICT FKs `member_id`, `plan_id`,
  `created_by`; `term_months=1`, `price_minor>0`, currency check, immutable
  snapshots; status check `pending_payment|paid|payment_review`; indexes
  `(member_id,created_at)`, `(status,created_at)`, and every FK.
- `membership_entitlements`: PK `id`; unique non-null RESTRICT FKs
  `purchase_id`, `member_id`; `starts_on`, `expires_on`, timezone/status/actor
  non-null; `expires_on>=starts_on`; unique `(purchase_id)`; index
  `(member_id,starts_on,expires_on)` and all FKs. A trusted transaction locks
  the member and rejects overlap; a database exclusion constraint may provide
  an additional guard if its date-range semantics are validated.
- `payment_records`: PK `id`; positive actual receipt amount, PHP currency,
  checked method, immutable protected receipt reference, Owner recorder and
  server timestamp; nullable cash-session RESTRICT FK iff method is cash. It
  has no target FK and remains immutable. Index `(method,recorded_at)`,
  cash-session FK and actor/time.
- `payment_allocations`: PK `id`; non-null RESTRICT receipt and Owner proposer
  FKs; exactly one nullable RESTRICT target FK (`purchase_id` or
  `walkin_request_id`) via checked `target_kind`; positive amount/currency equal
  source receipt; amount cannot exceed target snapshot. A unique projection
  enforces one current allocation per receipt. Multiple attributed receipts do
  not combine for access; only one exact full receipt may qualify. Index every
  FK and target.
- `payment_allocation_events`: append-only decision/action FK to allocation,
  Owner FK, event/reason/request/time; one terminal decision. Current
  allocation and effective-payment projections change in the same transaction
  as the event and audit append.
- `current_receipt_allocations`: `receipt_id` PK/FK, unique `allocation_id` FK,
  composite FK to `(receipt_id,id)` on `payment_allocations`, and server
  effective timestamp. Private mutable/rebuildable projection; transaction-only
  writes enforce one current allocation per receipt while retaining history.
- `payment_corrections`: PK `id`; non-null RESTRICT FKs to source receipt and
  Owner proposer, nullable affected-allocation RESTRICT FK with composite
  receipt/allocation consistency; correction kind/reason/evidence/time non-null;
  state is a rebuildable projection of decision events.
  Replacement linkage is represented only by `payment_replacements`. Partial unique
  `(original_receipt_id) WHERE state='open'`. `payment_replacements` has
  original-receipt PK/FK, replacement-receipt unique FK, correction unique FK,
  and CHECK original differs from replacement; a constraint trigger rejects
  replacement cycles or reusing a replacement. A trusted transaction verifies
  same-receipt evidence and approved corrected source facts.
  FK indexes are explicit.
- `walkin_requests`: PK `request_id`; non-null RESTRICT FK `fee_version_id`;
  immutable positive `amount_minor`, `currency`, server `created_at`, required
  `expires_at>created_at`, status check `provisional|valid|rejected|expired|payment_review`;
  index `(status,expires_at)` and every FK. Payment allocations point to this
  row; it has no attendance FK.
- `walkin_fee_versions`: PK `id`; positive amount and PHP currency; valid
  effective interval; Owner FK and timestamp; no overlapping active intervals
  under a serialized settings lock. Requests snapshot the fee version and
  amount; historical snapshots do not change.
- `membership_payment_effective`: `purchase_id` PK/FK and `allocation_id
  UNIQUE` FK; composite FK to allocation `(purchase_id,id)`.
  `walkin_payment_effective`: `request_id` PK/FK and `allocation_id UNIQUE` FK;
  `UNIQUE(request_id,allocation_id)` and composite FK to allocation
  `(walkin_request_id,id)`. All FKs RESTRICT; source receipt verification,
  allocation approval, and exact full amount/currency are validated in the same
  trusted transaction, with private procedures/constraint triggers preventing
  direct mutation.
- `attendance_checkins`: PK `id`; nullable RESTRICT FKs `member_id`,
  `walkin_request_id`, `walkin_payment_id`, and `eligibility_entitlement_id`;
  CHECK enforces exactly one member or walk-in target for `kind`; member rows
  link `(eligibility_entitlement_id,member_id)` to a matching entitlement;
  valid walk-in rows link `(walkin_request_id,walkin_payment_id)` by composite
  FK to the effective walk-in payment. Server-only status/date/timezone and
  source compatibility; unique walk-in request for walk-in rows; partial unique
  `(member_id,gym_local_date)` for valid member rows. Add indexes to each FK and
  `(gym_local_date,status)`, `(server_received_at,status)`. The date is a
  server-derived `Asia/Manila` date, never caller supplied.
- `attendance_payment_impacts`: PK `id`; non-null RESTRICT FKs to correction
  case and check-in; unique `(correction_id,checkin_id)`; impact reason and
  server timestamp. `attendance_validity` is derived from immutable check-in
  plus impacts, not a client-writable status.
- `cash_reconciliations`: PK `id`; unique RESTRICT FK to one closed drawer
  session; nonnegative counted/expected amounts and checked variance; immutable
  snapshot. `cash_reconciliation_adjustments`: PK; RESTRICT FKs to
  reconciliation, correction, the correction's original receipt, Owner, and
  idempotency operation. Composite FKs require the correction to name that
  receipt and require the receipt's cash session to equal the reconciliation's
  session. A signed `delta_minor` equals corrected expected physical cash for
  that receipt minus its prior expected physical cash; false/unreceived cash
  corrections are negative, verified amount increases positive. This changes
  expected cash only, not the counted snapshot or actual cash movement. Exactly
  one adjustment per qualifying correction; uniqueness plus idempotency blocks
  retries. It must identify the correction, receipt, closed reconciliation,
  Owner actor, reason/evidence, delta, and server time. Create it atomically
  only when an approved source-fact correction changes expected physical cash
  after close. Allocation-only changes and GCash/bank corrections never change
  expected physical cash and create no adjustment. Pre-close corrections feed
  the calculation before the immutable close snapshot; post-close corrections
  append an adjustment and preserve that snapshot and all original events.
  Automatic cash/non-cash method reclassification is unsupported and must be
  held for explicit Owner resolution; do not infer a cash adjustment. Do not
  presume opening floats or variance thresholds. Index all FK columns.
- `audit_events`: PK `id`; nullable Owner FK with RESTRICT, actor kind/action,
  RESTRICT FK `request_id` to idempotency operation, timestamp, reason,
  redacted metadata and hash-chain fields. Do
  not use polymorphic `entity_type + entity_id` as if it were FK enforced.
  `audit_event_subjects(event_id FK, member_id?, purchase_id?, payment_id?,
  payment_allocation_id?, walkin_request_id?, attendance_id?,
  attendance_validity_resolution_id?, correction_id?, reconciliation_id?)` has
  an exactly-one-non-null CHECK and RESTRICT typed FKs. One audit event may have
  several subject rows. Unique `(event_id, typed subject)` rules and indexes on
  every FK preserve referential integrity without leaking data in metadata.
  Actor/time index; never place raw identifiers or secrets in metadata.
- `request_idempotency`: PK `id`; non-null operation, actor scope, UUID key,
  request fingerprint, creation time; nullable safe result/entity reference
  and completion time. Replace generic `entity_type + entity_id` with nullable
  typed result FKs (purchase, payment, request, check-in, correction,
  reconciliation) and a CHECK allowing at most one. Unique
  `(operation,actor_scope,key)`, CHECK completion fields are consistent, index
  each result FK and creation/expiry. Same key and
  fingerprint returns the committed stored result; same key/different
  fingerprint rejects. Entity reference may remain non-FK only for generic
  non-entity outcomes. Retention is separate and must not expire
  idempotency before retry risk is over.

All historical/financial relationships use `ON DELETE RESTRICT` (or no delete
grant); update cascades are prohibited. Controlled maintenance must use audited
Owner procedures and retain immutable history.

## Attendance idempotency and concurrency

- Every check-in request has a random idempotency UUID. Store a keyed fingerprint
  of normalized request fields, not PIN or raw identity, and persist outcome
  atomically with attendance.
- For member check-in, a trusted server operation verifies PIN/current
  eligibility, locks member/date scope, calculates receipt time/local date, then
  inserts `valid`. A partial unique index on member/local date is the final race
  guard. Concurrent public/Owner/offline requests produce at most one valid
  row. Same-key retries return the saved outcome; changed payload is rejected.
- A duplicate receives the generic public result. Do not expose member status,
  payment, name, attendance history, or whether an identifier exists.
- The public QR may create a provisional walk-in request. Server creates its
  opaque ID, fee-version reference, immutable amount/currency snapshot, creation
  time, and expiry. Public input cannot set these values or mark valid. Owner
  confirms actual receipt only while the request is pending and unexpired.
  Payment confirmation, unique effective-payment linkage, attendance creation,
  idempotency result, and audit append commit atomically. An expired request is
  never revived; a new request has a new ID and current fee snapshot. Its
  configured lifetime is an operational value to set before use.

## PIN setup and reset

- Initial setup and reset use a cryptographically random, single-use, expiring
  token. Store only a keyed token hash, bind to member and purpose, limit
  attempts, and invalidate on use/replacement. Delivery and identity proof
  remain Owner decisions; no paid SMS is required.
- Member privately chooses the PIN. Store only an Argon2id verifier with
  per-PIN salt and a versioned server-only pepper. Treat PIN as a string to
  preserve leading zeros. Benchmark memory/time settings on the selected
  server runtime.
- Unknown ID, wrong PIN, ineligible member, duplicate, and throttled request
  return a uniform public body/message. Unknown IDs use a dummy KDF path.
  Atomic pseudonymous identifier/network throttles run before expensive hashing.
  Thresholds and cooldown remain unapproved.
- PIN credentials, setup tokens, and attempt buckets are never readable through
  public Data API or Realtime. No service-role/secret key or database password
  is sent to the browser.

## Offline queue and conflicts

Store only a minimal encrypted provisional envelope locally: idempotency UUID,
Owner ID, device installation UUID, opaque member reference, client-observed
time, and payload integrity value. Do not cache PIN, mobile, profile, payment,
or entitlement data. Label it provisional and clear it after final outcome.

At sync the server re-checks Owner authorization, approval, full confirmed
payment, entitlement, expiry, Manila date, and duplicate index. Client time is
untrusted and never proves event age or historical presence. The 24-hour window
is a triage/review threshold only, not automatic approval or proof. An Owner may
confirm that the member is physically present for a current-date check-in; the
server still validates eligibility, date, and duplicates. Old, suspicious,
conflicting, or expired claims stay non-valid until the documented Owner
resolution path; do not silently discard or approve them. Configure queue
expiry, retries, midnight behavior, and clock-drift tolerance before use.
Public member requests never queue offline or claim success.

## Authorization, RLS, and server-only operations

### Access boundaries

- **`anon`:** no direct table grants, directory, membership status, or payment
  visibility. It may execute only explicitly granted fixed-input public
  registration, walk-in-request, or member-check-in functions; never Owner
  operations.
- **Owner:** one authenticated management identity. Verify `auth.uid()` against
  private `owner_access` server-side on every protected operation; never trust
  user metadata or client role flags. RLS denies broad access by default. Use
  narrow Owner RPCs for writes and minimal RLS-protected views for needed reads.
- **Developer:** source/deploy identity only; no Owner/Auth role, service secret,
  production database credentials, live member/financial query, or routine
  access to live/restored records. Use synthetic fixtures. Owner-reviewed
  releases are recommended because deployment rights can become an indirect
  path to secrets/data.
- **Trusted executors:** separate `NOLOGIN`, `NOSUPERUSER`, `NOBYPASSRLS`
  `gym_owner_executor` and `gym_public_executor` roles. Neither owns tables,
  neither is assumable by `anon`/`authenticated`, and each receives only the
  required table privileges and role-targeted RLS policies. A separate non-
  login table-owner role owns private objects and never executes request
  functions. Force RLS on private business tables. Owner RPCs verify the caller
  JWT using `auth.uid()` against active `owner_access` on every call; public
  functions accept no client-supplied member/status/price/date facts. Ignore
  client actor IDs and metadata.
- **Function boundary:** prefer invoker reads. Narrow `SECURITY DEFINER`
  mutations are owned by the matching executor role, use
  `SET search_path = ''`, schema-qualify every object and function, and avoid
  dynamic SQL. Revoke function `EXECUTE` from `PUBLIC`, then grant only the
  exact endpoint to `anon` (fixed public operations) or `authenticated` (Owner
  operations). Internal authorization is mandatory even with RLS. No direct
  client DML to business tables, effective-payment projections, valid
  attendance, PIN material, or audit tables. PIN verification is server-side,
  rate-limited, generic-response, and reveals no member status.
- **Privileged credentials:** the normal request path uses caller JWTs and
  narrowly granted database operations, never a service-role key in the
  browser. Any future server-only service-role exception requires separate
  Owner approval and request-level JWT/Owner validation; no generic SQL/table
  endpoint is permitted. The Developer's source/deployment access conveys no
  production role, secret, or live-data access; the Owner controls releases
  and credentials.

### Operations that must not be direct anonymous/client table writes

1. One-time Owner bootstrap and subsequent Owner access administration.
2. Registration create/review/approve/deny/suspend and profile changes.
3. Plan, price, currency, timezone, and walk-in-fee configuration.
4. Purchase creation, payment record/confirmation/void-in-error, correction
   proposal/approval, entitlement activation/renewal, security suspension,
   (no membership-expiry override operation exists).
5. PIN setup-token issue/consume, PIN verification/reset, and throttling.
6. Public member check-in and walk-in request/confirmation.
7. Offline synchronization and acceptance/rejection of provisional records.
8. Cash drawer open/close, reconciliation, variance decisions, and adjustments.
9. Audit append/chain-head update, privacy/security event writes, backup,
   restore, key rotation, and retention/deletion operations.

Each operation validates current actor, role, state, and idempotency in one
transaction and appends the event, typed subject references, and chain-head
update before commit. Any audit, typed-subject FK, or chain-head failure rolls
back the protected mutation and idempotency result; return no success before
commit. The public Edge Function boundary
exposes fixed operations only, returns uniform generic results, and accesses
private PIN/PII only server-side. Exact Edge Function versus restricted RPC
architecture and key custody require approval.

## Backup, restore, and audit requirements

- Do not assume provider backup/PITR features or require a paid plan. Owner
  confirms selected-plan capabilities and sets cadence, retention, RPO/RTO,
  encryption, key recovery, and restore approvers.
- Backups use Owner-controlled storage/permissions. Restore drills use synthetic
  or properly isolated data; production restore needs Owner approval and must
  not grant Developer access to live records.
- Audit events include actor kind/ID when known, UTC time, request ID, action,
  entity, reason where required, and redacted metadata. Never log PIN, raw member
  ID/mobile, token, key, or full profile/payment contents.
- Hash-link events and periodically sign/anchor chain heads outside the mutable
  database. Choose anchor frequency, key custody, audit retention, and incident
  response before go-live. A database superuser can alter unanchored history.

## Final schema review checklist

Owner business decisions in this proposal are confirmed. Before migration
authoring, the technical review must close the following design checks:

- [ ] Effective payment projections enforce exactly one confirmed, exact-amount
  payment per purchase and per walk-in request; correction/void-in-error
  replacement cannot create installments, duplicate income, or membership
  access without a full confirmed payment.
- [ ] Walk-in `expires_at` is mandatory. Confirmation is rejected at/after the
  expiry boundary; a replacement is a new request ID with current fee snapshot.
- [ ] Offline queue/submission outcome states distinguish provisional,
  accepted-current-date, needs-review, duplicate, rejected, and expired claims;
  unresolved claims are visible, idempotent, and never historical attendance
  based on device time.
- [ ] Option A calculations use gym-local `date`; UTC timestamps are separate.
  Validate Jan 31, Feb 28/29 and daylight/date-boundary behavior in the target
  timezone implementation.
- [ ] Partial unique index and transactional lock/idempotency path guarantee one
  valid member check-in per Manila-local date under concurrency.
- [ ] Cross-table payment-target, same-request payment, immutable snapshot,
  eligibility, and audit-append constraints are enforced in trusted server
  transactions and cannot be bypassed by direct client writes.
- [ ] Table-by-table access matrix, RLS/default-deny grants, anonymous endpoints,
  Owner checks, private schemas, function search paths, and service secrets are
  reviewed for least privilege.
- [ ] No membership-cancellation/non-renewal, refund, installment, complimentary,
  freeze, expiry-override, or checkout state/operation/permission/field is
  present. Separate registration withdrawal, account revocation, PIN-token
  revocation, and justified security suspension retain their own purpose.
- [ ] RLS, concurrency, expiry, payment/correction, PIN, offline, walk-in,
  reconciliation, bootstrap, privacy, and isolated synthetic-restore tests are
  specified before implementation. These tests have not been run.

The two formerly open Owner decisions—unmatched/underpaid receipts and the
effect of invalidating a check-in—are now approved and represented by the
receipt-allocation and attendance-resolution contracts above. They no longer
block schema approval. Operational values that must be set before their use include the walk-in request lifetime,
24-hour triage validation, offline queue expiry/clock tolerance/review path,
PIN/KDF/rate/token settings after synthetic testing, detailed cash procedures,
payment evidence/review cadence, and actual plan/fee amounts. Privacy/legal
review, retention, backup/recovery targets, key custody, and actual Supabase
free-tier capability verification are required before live data or production
reliance; no legal period or provider guarantee is assumed.

The earlier design gaps are addressed by the proposed receipt-allocation and
attendance-resolution contracts, canonical transaction protocol, typed FK
contract, and Supabase access contract. They remain design proposals, not tested
or implemented and not approval to create migrations. Before implementation,
translate the approved receipt allocation and attendance-resolution semantics
into valid PostgreSQL constraints and transactions. Final PostgreSQL constraint
syntax, RLS/grants, function context and transaction behavior require
implementation-level technical review.

## Column-level implementation contract (proposal)

This section makes the table summaries implementable without silently choosing
business rules. Types below are PostgreSQL types; all IDs are `uuid` generated
by the database unless explicitly noted. `created_at`, `recorded_at`, and
`updated_at` are server-generated `timestamptz`; dates used for eligibility are
`date` values with an associated IANA timezone snapshot. Amounts are
`bigint` minor units and currency is `char(3)`. Business/history references
use `ON UPDATE RESTRICT ON DELETE RESTRICT`; only disposable lookup/cache rows
may cascade. Every nullable FK is paired with a check that defines when it may
be null. All FK columns used for joins have indexes.

| Table | Required columns and nullability | Additional integrity requirements |
|---|---|---|
| `owner_access` | `auth_user_id uuid PK/FK`, `status text NOT NULL`, `activated_at timestamptz NOT NULL`, `revoked_at timestamptz NULL`, `bootstrap_ref uuid NULL` | Singleton key/check; status enum/check; active iff `revoked_at IS NULL`; unique active Owner. No client grant to write. |
| `gym_settings` | `id smallint PK CHECK (id=1)`, `time_zone text NOT NULL`, `currency char(3) NOT NULL`, `version bigint NOT NULL`, `updated_at timestamptz NOT NULL`, `updated_by uuid FK NULL` | Initial values proposed as `Asia/Manila`/`PHP`; timezone validated server-side; versions increase monotonically. |
| `gym_setting_events` | `id uuid PK`, `setting_key text NOT NULL`, `old_value jsonb NULL`, `new_value jsonb NOT NULL`, `actor_id uuid FK NOT NULL`, `reason text NOT NULL`, `request_id uuid NOT NULL`, `recorded_at timestamptz NOT NULL` | Append-only; values must be secret/PII-free; index `(setting_key, recorded_at DESC)` and actor/time. |
| `member_profiles` | `id uuid PK`, `member_code_ciphertext bytea NOT NULL`, `member_code_lookup_hmac bytea UNIQUE NOT NULL`, `full_name_ciphertext bytea NOT NULL`, `mobile_ciphertext bytea NOT NULL`, `mobile_lookup_hmac bytea UNIQUE NOT NULL`, `lookup_key_version smallint NOT NULL`, `registration_status text NOT NULL`, `created_at timestamptz NOT NULL`, `updated_at timestamptz NOT NULL`, `approved_by uuid FK NULL`, `approved_at timestamptz NULL` | Status check; approval actor/time both null or both non-null; no plaintext searchable identifier. |
| `registration_applications` | `id uuid PK`, `member_id uuid FK NOT NULL`, `status text NOT NULL`, `submitted_at timestamptz NOT NULL`, `created_at timestamptz NOT NULL` | Status check; one pending row/member via partial unique index `(member_id) WHERE status='pending'`; member/time index. |
| `registration_decision_events` | `id uuid PK`, `application_id uuid FK NOT NULL`, `member_id uuid FK NOT NULL`, `actor_id uuid FK NOT NULL`, `decision text NOT NULL`, `reason text NOT NULL`, `request_id uuid NOT NULL`, `recorded_at timestamptz NOT NULL` | Decision enum/check; append-only; indexes `(member_id,recorded_at)` and actor/time. |
| `member_pin_credentials` | `member_id uuid PK/FK`, `verifier text NOT NULL`, `pepper_version smallint NOT NULL`, `credential_version bigint NOT NULL`, `changed_at timestamptz NOT NULL` | Private schema, server-only access; verifier is encoded Argon2id and never returned. |
| `member_pin_tokens` | `id uuid PK`, `member_id uuid FK NOT NULL`, `purpose text NOT NULL`, `token_hash bytea UNIQUE NOT NULL`, `issued_by uuid FK NOT NULL`, `issued_at timestamptz NOT NULL`, `expires_at timestamptz NOT NULL`, `consumed_at timestamptz NULL`, `revoked_at timestamptz NULL`, `attempt_count integer NOT NULL CHECK (attempt_count>=0)` | `expires_at>issued_at`; single-use atomically; partial unique unconsumed token/member/purpose; raw token never persisted. |
| `pin_attempt_buckets` | `bucket_hash bytea NOT NULL`, `window_start timestamptz NOT NULL`, `attempt_count integer NOT NULL CHECK (attempt_count>=0)`, `blocked_until timestamptz NULL`, `expires_at timestamptz NOT NULL`, composite PK `(bucket_hash,window_start)` | Private, atomic upsert; no raw identifier/IP/PIN. Limits and retention await approval. |
| `membership_plans` | `id uuid PK`, `plan_code text UNIQUE NOT NULL`, `label text NOT NULL`, `term_months smallint NOT NULL CHECK (=1)`, `price_minor bigint NOT NULL CHECK (>0)`, `currency char(3) NOT NULL`, `is_sellable boolean NOT NULL`, `effective_from timestamptz NOT NULL`, `effective_to timestamptz NULL`, `created_at timestamptz NOT NULL`, `created_by uuid FK NOT NULL` | Effective interval valid; revisions create new versions, never mutate snapshots. No zero-price plan. |
| `membership_purchases` | `id uuid PK`, `member_id uuid FK NOT NULL`, `plan_id uuid FK NOT NULL`, `term_months smallint NOT NULL CHECK (=1)`, `price_minor bigint NOT NULL CHECK (>0)`, `currency char(3) NOT NULL`, `status text NOT NULL`, `created_by uuid FK NOT NULL`, `created_at timestamptz NOT NULL` | Status check (`pending_payment`, `paid`, `payment_review`); `UNIQUE(id,member_id)` supports composite entitlement FK; immutable snapshots; indexes every FK, member/time and status. No cancellation column/action. |
| `membership_payment_effective` | `purchase_id uuid PK/FK NOT NULL`, `allocation_id uuid UNIQUE FK NOT NULL`, `effective_at timestamptz NOT NULL` | Composite FK to allocation `(purchase_id,id)`; source receipt is Owner-verified, allocation approved/current, and exact amount/currency equals immutable purchase snapshot; maintained atomically. At most one effective full payment per purchase. |
| `membership_entitlements` | `id uuid PK`, `purchase_id uuid UNIQUE FK NOT NULL`, `member_id uuid FK NOT NULL`, `starts_on date NOT NULL`, `expires_on date NOT NULL`, `time_zone text NOT NULL`, `status text NOT NULL`, `activated_at timestamptz NOT NULL`, `activated_by uuid FK NOT NULL` | `UNIQUE(id,member_id)` supports attendance composite FK; composite `(purchase_id,member_id)` references purchase `(id,member_id)`; `expires_on>=starts_on`; member/date index; serialize by member and reject overlap; transition event required. |
| `membership_lifecycle_events` | `id uuid PK`, `entitlement_id uuid FK NOT NULL`, `member_id uuid FK NOT NULL`, `event_type text NOT NULL`, old/new start/expiry `date NULL`, `actor_id uuid FK NOT NULL`, `reason text NOT NULL`, `request_id uuid NOT NULL`, `recorded_at timestamptz NOT NULL` | Append-only; event-specific old/new checks; no refund/checkout/freeze event in initial release. |
| `walkin_fee_versions` | `id uuid PK`, `amount_minor bigint NOT NULL CHECK (>0)`, `currency char(3) NOT NULL`, `effective_from timestamptz NOT NULL`, `effective_to timestamptz NULL`, `created_by uuid FK NOT NULL`, `created_at timestamptz NOT NULL` | Initial currency PHP; `effective_to>effective_from`; non-overlap under serialized setting lock. |
| `walkin_requests` | `request_id uuid PK`, `status text NOT NULL`, `source text NOT NULL`, `fee_version_id uuid FK NOT NULL`, `amount_minor bigint NOT NULL CHECK (>0)`, `currency char(3) NOT NULL`, `created_at timestamptz NOT NULL`, `expires_at timestamptz NOT NULL`, `confirmed_at timestamptz NULL`, `rejected_at timestamptz NULL`, `idempotency_id uuid FK NOT NULL` | Request amount/currency immutable and match fee version at creation; `expires_at>created_at`; status `provisional|valid|rejected|expired|payment_review`; only trusted transaction sets valid/review. Expired requests cannot be revived. Lifetime is configured before operation. |
| `payment_records` | `id uuid PK`, `amount_minor bigint NOT NULL CHECK (>0)`, `currency char(3) NOT NULL`, `method text NOT NULL`, `reference_ciphertext bytea NULL`, `cash_session_id uuid FK NULL`, `recorded_by uuid FK NOT NULL`, `recorded_at timestamptz NOT NULL` | Immutable source receipt, independent of target; cash session non-null iff cash; unique `(id,cash_session_id)` supports same-session adjustment FK; unverified/unallocated receipts are preserved and classified separately; indexes cash session, actor/time, method/time. |
| `payment_allocations` | `id uuid PK`, `receipt_id uuid FK NOT NULL`, `target_kind text NOT NULL`, nullable `purchase_id uuid FK`, nullable `walkin_request_id uuid FK`, `amount_minor bigint NOT NULL CHECK (>0)`, `currency char(3) NOT NULL`, `proposed_by uuid FK NOT NULL`, `proposed_at timestamptz NOT NULL` | Exclusive target CHECK; amount/currency equals immutable source receipt; target RESTRICT FKs; amount may be below target snapshot; append-only. Index every FK and target/time. Unique current-allocation projection per receipt; no unique target allocation that would preclude separately recording receipts. Corrections void before reallocation. |
| `current_receipt_allocations` | `receipt_id uuid PK/FK`, `allocation_id uuid UNIQUE FK`, `effective_at timestamptz NOT NULL` | Composite FK `(receipt_id,allocation_id)` to allocation `(receipt_id,id)`; private mutable/rebuildable projection, transaction-only writes; indexes all FKs. One current allocation per receipt. |
| `payment_allocation_events` | `id uuid PK`, `allocation_id uuid FK NOT NULL`, `event_type text NOT NULL`, `actor_id uuid FK NOT NULL`, `reason text NOT NULL`, `request_id uuid FK NOT NULL`, `recorded_at timestamptz NOT NULL` | Append-only `approved_full|approved_underpaid|rejected|voided`; only Owner approves and supplies evidence/reason; one approval decision and at most one current allocation; receipt verification, allocation decision, projection, and audit commit atomically. Only `approved_full` with exact target amount can create an effective membership/walk-in payment. |
| `payment_events` | `id uuid PK`, `payment_id uuid FK NOT NULL`, `event_type text NOT NULL`, `actor_id uuid FK NOT NULL`, `reason text NULL`, `evidence_ref_ciphertext bytea NULL`, `request_id uuid NOT NULL`, `recorded_at timestamptz NOT NULL` | Event check (`recorded`, `confirmed`, `rejected`, `confirmation_voided_in_error`); append-only; confirmation requires evidence metadata and Owner; partial unique one `confirmed` and one `confirmation_voided_in_error` event per payment; index all FKs and `(payment_id,recorded_at)`. |
| `walkin_payment_effective` | `request_id uuid PK/FK`, `allocation_id uuid UNIQUE FK NOT NULL`, `effective_at timestamptz NOT NULL` | Composite FK to approved allocation `(walkin_request_id,id)` and `UNIQUE(request_id,allocation_id)` for attendance composite FK. Insert/update only in atomic Owner verification/approval; allocation must equal fee snapshot and source receipt must be verified; one effective payment. |
| `payment_corrections` | `id uuid PK`, `original_receipt_id uuid FK NOT NULL`, nullable `original_allocation_id uuid FK`, `kind text NOT NULL`, `state text NOT NULL`, `reason text NOT NULL`, `evidence_ref_ciphertext bytea NOT NULL`, `proposed_by uuid FK NOT NULL`, `proposed_at timestamptz NOT NULL` | Kind check (`void_false_receipt`,`replace_misrecorded_receipt`); `UNIQUE(id,original_receipt_id)` supports the adjustment composite FK; composite receipt/allocation FK; state projection (`open`,`approved`,`rejected`); immutable; one open correction/receipt via partial unique index; append-only decision events. |
| `payment_replacements` | `original_payment_id uuid PK/FK NOT NULL`, `replacement_payment_id uuid UNIQUE FK NOT NULL`, `correction_id uuid UNIQUE FK NOT NULL -> payment_corrections.id`, `recorded_at timestamptz NOT NULL` | Original differs from replacement; one-to-one links; both rows represent the same evidenced actual receipt with corrected recorded fields; only approved correction transaction inserts; indexes every FK; unique chain/cycle guard. |
| `payment_correction_events` | `id uuid PK`, `correction_id uuid FK NOT NULL`, `event_type text NOT NULL`, `actor_id uuid FK NOT NULL`, `reason text NOT NULL`, `request_id uuid NOT NULL`, `recorded_at timestamptz NOT NULL` | Event check `proposed|approved|rejected`; append-only; only one terminal decision per case enforced transactionally and by unique partial indexes; unique `(correction_id,id,actor_id)` supports an adjustment FK proving the exact approving Owner; sole-Owner self-approval visibly audited. |
| `attendance_checkins` | `id uuid PK`, `kind text NOT NULL`, `member_id uuid FK NULL`, `eligibility_entitlement_id uuid FK NULL`, `walkin_request_id uuid NULL`, `walkin_payment_id uuid NULL` (allocation ID), `status text NOT NULL`, `source text NOT NULL`, `server_received_at timestamptz NOT NULL`, `client_claimed_at timestamptz NULL`, `gym_local_date date NULL`, `time_zone text NOT NULL`, `owner_id uuid FK NULL`, `offline_submission_id uuid UNIQUE FK NULL`, `idempotency_id uuid FK NOT NULL` | Exclusive target-kind check; member row requires member+matching entitlement composite FK; walk-in row requires request+effective allocation composite FK; unique walk-in request; partial unique member/local date for accepted valid rows; provisional rows cannot be valid evidence; indexes every FK/date/status. Server alone chooses status/date. |
| `attendance_payment_impacts` | `id uuid PK`, `correction_id uuid FK NOT NULL`, `checkin_id uuid FK NOT NULL`, `reason text NOT NULL`, `recorded_at timestamptz NOT NULL` | Unique `(correction_id,checkin_id)`; append-only; indexes both FKs. |
| `attendance_validity` | `checkin_id uuid PK/FK NOT NULL`, `state text NOT NULL`, `derived_at timestamptz NOT NULL` | Private rebuildable projection (`valid`,`invalidated_payment`,`valid_by_owner_resolution`); no client writes; counts only `valid` and explicitly resolved valid states. |
| `attendance_validity_resolutions` | `id uuid PK`, `checkin_id uuid FK NOT NULL`, `independent_allocation_id uuid FK NOT NULL`, `owner_id uuid FK NOT NULL`, `reason text NOT NULL`, `request_id uuid FK NOT NULL`, `recorded_at timestamptz NOT NULL` | Append-only; unique resolution/check-in unless a separately approved superseding event; exact entitlement/date eligibility and physical-presence evidence are revalidated; indexes each FK. Does not rewrite source check-in or invalidation. |
| `offline_sync_submissions` | `id uuid PK`, `owner_id uuid FK NOT NULL`, `device_id uuid NOT NULL`, `member_id uuid FK NOT NULL`, `client_claimed_at timestamptz NULL`, `server_received_at timestamptz NOT NULL`, `payload_fingerprint bytea NOT NULL`, `outcome text NOT NULL`, `checkin_id uuid UNIQUE FK NULL`, `idempotency_id uuid FK NOT NULL` | Unique `(owner_id,idempotency_id)`; outcome check; no client-provided validity; replay fingerprint immutable. |
| `request_idempotency` | `id uuid PK`, `operation text NOT NULL`, `actor_scope text NOT NULL`, `key uuid NOT NULL`, `request_fingerprint bytea NOT NULL`, `outcome jsonb NULL`, typed result FKs nullable, `created_at timestamptz NOT NULL`, `completed_at timestamptz NULL` | Unique `(operation,actor_scope,key)`; same key/different fingerprint rejected; at most one typed result FK; outcome contains no secret/PII; retention unresolved. |
| `cash_drawer_sessions` | `id uuid PK`, `drawer_code text NOT NULL`, `status text NOT NULL`, `opening_float_minor bigint NOT NULL CHECK (>=0)`, `opened_by uuid FK NOT NULL`, `opened_at timestamptz NOT NULL`, `closed_by uuid FK NULL`, `closed_at timestamptz NULL` | Status/time consistency check; partial unique one open session per drawer; closed snapshot fields immutable. |
| `cash_reconciliations` | `id uuid PK`, `session_id uuid UNIQUE FK NOT NULL`, `expected_minor bigint NOT NULL CHECK (>=0)`, `counted_minor bigint NOT NULL CHECK (>=0)`, `variance_minor bigint NOT NULL`, `reason text NOT NULL`, `counted_by uuid FK NOT NULL`, `reviewed_by uuid FK NULL`, `recorded_at timestamptz NOT NULL` | `variance=counted-expected`; immutable; unique `(id,session_id)` supports same-session adjustment FK; index actor/time. Independent review not presumed. |
| `cash_reconciliation_adjustments` | `id uuid PK`, `reconciliation_id uuid NOT NULL`, `session_id uuid NOT NULL`, `correction_id uuid NOT NULL`, `correction_event_id uuid NOT NULL`, `receipt_id uuid NOT NULL`, `delta_minor bigint NOT NULL CHECK (delta_minor<>0)`, `reason text NOT NULL`, `evidence_ref_ciphertext bytea NOT NULL`, `actor_id uuid FK NOT NULL`, `idempotency_id uuid FK NOT NULL`, `recorded_at timestamptz NOT NULL` | Composite FKs require correction `(id,original_receipt_id)` to equal `(correction_id,receipt_id)`, receipt `(id,cash_session_id)` to equal `(receipt_id,session_id)`, reconciliation `(id,session_id)` to equal `(reconciliation_id,session_id)`, and the approved correction-decision event `(correction_id,event_id,actor_id)` to match `(correction_id,correction_event_id,actor_id)`; all RESTRICT. The recorded Owner actor must therefore be the actor who approved that source-fact correction. `UNIQUE(correction_id)` and idempotency prevent duplicates. `delta_minor = corrected expected physical cash for this receipt - its prior expected physical cash`; false/unreceived cash negative, verified increase positive. Allocation-only and GCash/bank corrections create no adjustment. Cash/non-cash reclassification waits for explicit Owner resolution. Append-only; not a cash movement and never rewrites the close snapshot. |
| `member_privacy_events` | `id uuid PK`, `member_id uuid FK NOT NULL`, `notice_version text NOT NULL`, `event_type text NOT NULL`, `recorded_at timestamptz NOT NULL`, `evidence jsonb NULL` | Minimal evidence; acknowledgment is not consent unless specifically reviewed/approved. |
| `audit_events` | `id uuid PK`, `stream_key text NOT NULL`, `actor_kind text NOT NULL`, `owner_id uuid FK NULL`, `action text NOT NULL`, `request_id uuid NOT NULL`, `reason text NULL`, `metadata jsonb NOT NULL`, `recorded_at timestamptz NOT NULL`, `previous_hash bytea NULL`, `event_hash bytea NOT NULL` | Append-only; actor-kind/owner consistency check; unique stream sequence/hash position; actor/time index. Typed subject references live in `audit_event_subjects`; no unenforced polymorphic entity ID. |
| `audit_event_subjects` | `id uuid PK`, `event_id uuid FK NOT NULL`, nullable typed FKs for member, purchase, payment, payment allocation, walk-in request, attendance, attendance validity resolution, correction, reconciliation | CHECK exactly one subject FK is non-null; all FKs `ON DELETE RESTRICT`, indexed; unique typed subject/event. One event may have multiple subject rows. Allocation and validity-resolution subjects are real FKs to their respective tables; referenced history cannot be deleted. |
| `audit_chain_heads` | `stream_key text PK`, `last_event_id uuid UNIQUE FK NOT NULL`, `last_hash bytea NOT NULL`, `updated_at timestamptz NOT NULL` | Locked and updated atomically with append; external signed anchoring/cadence awaits Owner decision. |

### Transaction and uniqueness requirements

All privileged state transitions, idempotency reservation, effective financial
projection, related attendance, and audit append commit or roll back together.
Use `SELECT ... FOR UPDATE` in a documented global lock order and retry
serialization/deadlock failures with the same idempotency key. Do not make a
network call while holding locks. Critical unique constraints are: normalized
mobile HMAC; one pending application/member; one entitlement/purchase; one valid
member attendance/member/local date; one attendance/request; one effective
confirmed walk-in payment/request; one payment correction in unresolved state;
one cash reconciliation/session; one open drawer/drawer code; idempotency scope;
and unique offline replay identity. Add indexes to each FK and common filter
columns. Constraints are defense in depth; trusted server functions still
validate actor, eligibility, payment state, timezone, and immutable snapshots.

This column contract is a proposal, not executable SQL. Confirm nullable
business cases and cross-table transactional checks during schema review; never
weaken the confirmed access, payment, attendance, or privacy rules to fit a
convenient client workflow.
