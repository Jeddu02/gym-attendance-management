# GYMFORCE Attendance Implementation Readiness

**Current checkpoint (2026-11-06):** See
[development-checkpoint-2026-11-06.md](development-checkpoint-2026-11-06.md)
for fresh build/unit-test results, Docker-free PostgreSQL preservation evidence,
unresolved ownership/security findings, deployment gates, and the next-phase
implementation plan. Attendance remains unimplemented and is not approved for
release. The source audit below is the historical 2026-11-04 snapshot; its
deployment and tooling observations must not be treated as current results.

**Audit date:** 2026-11-04
**Scope:** Source/configuration review and security contract design only. No
database connection, migration, function deployment, credential use, or live
member data access was performed.

## 1. Executive summary

Attendance is **not ready for implementation release**. Source contains an
Attendance navigation item and a draft attendance/walk-in schema, but no
member check-in page, QR route, PIN verification endpoint, eligibility
operation, attendance history workflow, walk-in confirmation flow, or offline
attendance queue. A unique index is a useful duplicate backstop but cannot
implement authorization or trusted Manila-date derivation.

The repository's existing security patterns provide foundations: PIN
enrollment uses Argon2id in trusted Edge code, private tables revoke browser
access, Owner-facing operations use server-side functions/RPCs, and the audit
chain is append-only in source. These are not equivalent to a complete
Attendance implementation. Deployment of any source-defined object remains
unverified.

## 2. Requirements and status

| Requirement | Status | Repository evidence |
|---|---|---|
| Permanent entrance QR/public check-in page | **MISSING** | No QR page, route, or generator found in `src/`, `public/`, or `supabase/functions/`. `src/App.tsx` says check-in will use a separate QR flow but does not implement it. |
| Member ID/mobile plus six-digit PIN check-in | **MISSING** | PIN enrollment exists, but no check-in PIN verifier or public check-in function exists. `supabase/functions/_shared/pin-password.ts` contains a reusable verifier, not an endpoint. |
| Server-side identity, PIN, and eligibility validation | **MISSING** | No check-in Edge Function or attendance RPC found. |
| One valid check-in/member/Manila date | **PARTIAL** | Draft attendance migration has a partial unique index over `member_id,gym_local_date` for valid rows. There is no server date derivation or authorization operation. |
| Membership payment and inclusive expiry validation | **MISSING** | Purchases have date/status fields; no check-in logic consumes effective confirmed payment or date range. |
| Cash and online membership payment eligibility | **PARTIAL** | The payment schema supports `cash`, `gcash`, and `bank transfer`, and Owner membership payment flows exist. Attendance has no eligibility check that accepts every supported method only after the Owner confirms effective full payment. |
| Walk-in fee/request foundation | **PARTIAL** | Draft tables snapshot PHP fee, currency, creation, and expiry. No endpoint creates or confirms a walk-in. Expiry duration remains an Owner decision. |
| Owner walk-in payment confirmation + attendance | **MISSING** | No walk-in confirmation RPC/function exists. |
| Owner attendance history/resolution | **PARTIAL** | Draft status and resolution tables exist, but no query, operation, authorization wrapper, or UI. |
| Staff roles/bypass | **MISSING / OUT OF SCOPE** | Current initial-release requirements allow Owner as the only management user. No staff accounts exist. Do not introduce them for Attendance. |
| Offline Owner claims | **MISSING** | PWA manifest/service worker setup exists; no attendance queue, encryption, sync, or review flow. |
| Public offline check-in | **MISSING / PROHIBITED** | Requirements require internet for member check-in; no offline member path should be added. |
| Audit events for attendance | **PARTIAL** | Append-only audit-chain machinery exists, but no attendance write/resolution operation calls it. |

## 3. Repository objects inspected

### Application and Edge Functions

- `src/App.tsx`: Owner dashboard navigation includes Attendance. The branch
  renders Members, Payments, Memberships, or Overview; Attendance falls
  through to a disconnected-module placeholder.
- `src/lib/supabase.ts`: browser Supabase client uses public configuration and
  rejects service-role keys. No Attendance call site was found.
- `src/components/MembersPage.tsx`, `MembershipPlansPage.tsx`,
  `MembershipPurchasesPage.tsx`, `PaymentsPage.tsx`: existing Owner workflows;
  none implements check-in eligibility/history.
- `supabase/functions/owner-status/index.ts`: validates the authenticated user
  and active Owner status through a server-side RPC. It is not a member
  authorization endpoint.
- `supabase/functions/member-enroll-pin/index.ts` and
  `supabase/functions/_shared/pin-password.ts`: PIN enrollment and Argon2id
  helper. The function's global rate limit is for enrollment, not member
  check-in attempts.
- No Attendance, member-check-in, walk-in-create, or walk-in-confirm Edge
  Function was found.
- `vite.config.ts`: PWA manifest/service-worker plugin setup. No offline
  attendance queue or sensitive-data cache policy for an Attendance feature
  was found in application code.

### Database schema, functions, and security

- `supabase/migrations/20261028061728_initial_schema.sql`: Owner registry,
  member records, default private schema boundary, `Asia/Manila` setting, and
  initial audit table.
- `supabase/migrations/20261028062516_membership_core.sql`: membership plans
  and purchases, including activation/expiry date fields and status checks.
- `supabase/migrations/20261028062602_payment_ledger.sql` and
  `supabase/migrations/20261103120000_owner_membership_payments.sql`:
  payment ledger and Owner membership payment flows. These do not provide a
  walk-in payment confirmation/check-in transaction.
- `supabase/migrations/20261028062706_walkin_attendance.sql`: draft walk-in
  fee/request, attendance, and validity-resolution tables; check-in indexes;
  RLS enabled and direct browser grants revoked.
- `supabase/migrations/20261028062757_owner_security.sql`: private table
  access revocation and active Owner helper.
- `supabase/migrations/20261028062853_member_pin_security.sql`,
  `supabase/migrations/20261030140000_owner_create_pin_enrollment_token.sql`,
  `supabase/migrations/20261030150000_member_pin_enrollment.sql`, and
  `supabase/migrations/20261030170000_rolling_pin_enrollment_rate_limit.sql`:
  PIN enrollment foundation; no check-in verification/lockout transaction.
- `supabase/migrations/20261030120000_audit_chain_enforcement.sql`: append-only
  hash-chain audit functions and mutation protection. Attendance does not yet
  use them.
- `supabase/migrations/20261028063404_integrity_fixes.sql`: walk-in payment
  allocation foreign key.
- `supabase/migrations/20261028063446_membership_overlap_guard.sql`: dated
  membership overlap constraint; source comment says PostgreSQL validation is
  required before deployment.
- `supabase/config.toml`: local Supabase configuration with project id
  `gym`, schemas, and selected local function definitions. This does not
  identify or prove the hosted project or deployments.
- No attendance-specific database assertion or integration test was found.
  Existing database/security and membership-payment assertions are not proof
  that attendance objects work.

## 4. Security and database findings

### What source supports

- Attendance and walk-in tables are in the `private` schema, RLS is enabled,
  and direct grants to `public`, `anon`, and `authenticated` are revoked in
  the draft migration and Owner security migration.
- The attendance table has a check constraint requiring exactly one subject
  (member or walk-in), constrained statuses, and a unique partial index for
  valid member/day rows.
- PIN credential schema stores an encoded Argon2id verifier, not plaintext.
  Enrollment token and rate-limit source similarly contain no intentional
  plaintext PIN storage.
- Audit-chain functions exist for trusted functions to append events.

### Missing enforcement/workflows

- No check-in Edge Function, public RPC grant, or atomic attendance transaction
  exists in source.
- `gym_local_date` is a normal required `date` column; the source does not
  derive it from trusted time in `Asia/Manila`.
- No operation rechecks approved/active member state, fully paid effective
  entitlement, activation date, inclusive expiry, payment correction/void
  state, or duplicate status before attendance insertion.
- PIN attempt buckets are only schema. No check-in attempt counter, lockout,
  member/network rate limit, generic verification response, or enumeration
  protection is implemented for attendance.
- No idempotency record/key handling exists for check-in requests.
- Attendance insert/status changes are not coupled to an audit event or
  validity-resolution row by an implemented operation.
- A schema-level `confirmed` walk-in status does not enforce Owner identity,
  verified actual receipt, request expiry, single allocation, or atomic
  confirmation plus attendance.
- No Attendance operation connects its eligibility decision to Owner-confirmed
  cash or online receipts. Payment-method eligibility must be neutral: actual
  cash received and online transactions verified by the Owner both count when
  confirmed, effective, and sufficient for full payment. A reference number or
  member claim alone is not proof of receipt.
- There is no deployed-state evidence for table ownership, effective grants,
  RLS state, or function execute ACLs.

### Payment handling requirement

GYMFORCE accepts cash and online payments, including supported e-wallet and
bank-transfer methods. The ledger must record method, actual amount, payment
date/time, and confirmation status for both. The Owner records and confirms
actual cash received; for online payments, the Owner verifies the actual
receipt/transaction before confirmation. Pending, partial, rejected, or voided
payments never count as confirmed full payment. Confirmed effective payments
count toward membership regardless of method. Corrections and reversals must
preserve original payment history and be auditable; submitted references and
member-reported payment are not confirmation.

Repository evidence: `20261028062602_payment_ledger.sql` defines amount,
method, received timestamp, and verification status; `payment_method_valid`
permits `cash`, `gcash`, and `bank_transfer`. The Owner membership payment
workflow exists in source, but no Attendance eligibility operation uses its
effective result. This source evidence does not establish hosted deployment or
prove the entire cash/online lifecycle.

## 5. Migration and live deployment verification

### Verified in repository source

- Attendance/walk-in draft table definitions and constraints in
  `20261028062706_walkin_attendance.sql`.
- PIN credential/setup-token/attempt-bucket definitions and enrollment
  functions listed above.
- Owner/authentication, membership/payment, audit-chain, and local Supabase
  configuration source files listed above.

### Verified in live Supabase database

**None.** This task did not access a live Supabase project or database, and no
secrets were requested or inspected. Therefore no live table, migration
version, RPC, RLS policy, grant, or database setting is confirmed.

### Deployment status unknown

- Whether the local project id `gym` corresponds to the intended hosted
  project.
- Which migrations have been applied and whether the hosted schema matches
  current local source.
- Whether PIN enrollment, Owner verification, membership/payment functions,
  and audit functions are deployed at the expected revisions.
- Current hosted Edge Function secrets, logs, runtime behavior, and function
  deployment versions.
- Effective hosted RLS policies, table ownership, role memberships, and
  function privileges.

The migration comments explicitly call the attendance/walk-in migration a
draft, membership core a draft pending PostgreSQL testing, and the overlap
guard a draft requiring PostgreSQL validation. These must not be considered
production-ready or deployed based on their presence in Git. Other migration
headers and prior design documents also describe pending disposable database
validation; source files are not evidence of application to Supabase.

The initial schema, membership core, payment ledger, walk-in/attendance,
Owner security, PIN security, cash reconciliation, audit integrity, membership
overlap, and payment integrity migrations explicitly carry draft or
pre-deployment validation warnings. Apply the ordered migration chain only to
a disposable synthetic local database after review; never infer hosted state
from migration filenames.

Repository timestamp order (not an applied/deployed status):

`20261028061728_initial_schema` → `20261028062516_membership_core` →
`20261028062602_payment_ledger` → `20261028062706_walkin_attendance` →
`20261028062757_owner_security` → `20261028062853_member_pin_security` →
`20261028062935_cash_reconciliation` → `20261028063027_audit_integrity` →
`20261028063404_integrity_fixes` → `20261028063446_membership_overlap_guard` →
`20261028063638_payment_integrity_guard` →
`20261028064100_database_security_foundation` →
`20261029100000_owner_authorization_rpc` →
`20261030120000_audit_chain_enforcement` →
`20261030130000_owner_register_member` →
`20261030140000_owner_create_pin_enrollment_token` →
`20261030150000_member_pin_enrollment` →
`20261030160000_global_pin_enrollment_rate_limit` →
`20261030170000_rolling_pin_enrollment_rate_limit` →
`20261030180000_owner_list_members` →
`20261103080000_owner_membership_plans` →
`20261103100000_owner_create_membership_purchase` →
`20261103110000_owner_list_membership_purchases` →
`20261103120000_owner_membership_payments`.

## 6. Local Supabase and free-plan readiness

### Local tooling observed

- `supabase` is installed as the project npm dependency at version `2.122.0`
  (`npm ls supabase --depth=0`). The global command is not on `PATH`. Running
  `npm.cmd exec -- supabase --version` failed because the CLI tried to create
  its telemetry file under the protected `C:\Users\Banco-Sual\.supabase`
  directory and received `EPERM`. A clean CLI invocation was not verified.
- Docker CLI `29.9.2` is present, but `docker info` cannot connect to the
  Docker Engine named pipe; the daemon is unavailable in this session.
- Native `psql`, `postgres`, `pg_ctl`, and `initdb` are not on `PATH`. A Deno
  shim is present but cannot launch its associated application. No PostgreSQL
  service or disposable local Supabase database was verified.
- Project config identifies local `project_id = "gym"`, Postgres major
  version 17, Edge Runtime Deno 2, migrations enabled, and no enabled seed
  file. This is local configuration only.

**Superseded by the Docker-free checkpoint:** Docker is prohibited. The existing
PostgreSQL 18 cluster at `%LOCALAPPDATA%\GYMFORCE-PG18-TEST\data` is the only
approved native test target, on `127.0.0.1:55432`, database
`gymforce_pg18_test`. Its 24 migrations previously completed. Do not initialize,
reset, recreate, reapply migrations, or run `cleanup.sql` during preservation
checks. The 2026-11-06 checkpoint records fresh preflight and read-only
preservation results, plus 38 passing Deno unit tests. Native PostgreSQL testing
does not validate Supabase Auth, HTTP ingress, Edge Runtime, or PostgreSQL 17
compatibility. Keep hosted verification Owner-controlled and separately approved.

### Current Free-plan constraints (checked 2026-11-04)

Supabase's published Free-plan figures relevant to this design include:

- Up to 2 active free projects; free projects may pause after a week of
  inactivity.
- 500 MB database-size quota per project and fixed 2 GB disk; free disk does
  not autoscale and the database may become read-only near capacity.
- Shared Nano compute, 500 MB RAM, no automatic backups, and no point-in-time
  recovery on Free.
- 500,000 Edge Function invocations/month and up to 100 functions/project.
  Hosted Edge Functions have a 256 MB memory limit, 2 seconds CPU time per
  request, and 150 seconds maximum wall-clock duration on Free.
- 5 GB uncached and 5 GB cached egress, plus 1 GB file storage.

These quotas are ceilings, not a guarantee that the proposed production
workload or retention needs fit. Existing Argon2id code uses 64 MiB and three
iterations; benchmark its per-request CPU and memory on the target Edge
Runtime, especially against the 2-second CPU limit. Do not assume the Free plan
provides adequate production backups, availability, or retention. Confirm plan
limits and an Owner-approved backup/recovery design before production.

Sources: [Supabase Free Plan and quotas](https://supabase.com/docs/guides/platform/billing-on-supabase),
[Edge Function limits](https://supabase.com/docs/guides/functions/limits),
[database size and disk behavior](https://supabase.com/docs/guides/platform/database-size),
and [pricing and plan comparison](https://supabase.com/pricing). Limits can
change; recheck official documentation before implementation/deployment.

## 7. Owner-approved PIN settings and remaining decisions

See the complete contract in
[member-checkin-security-contract.md](member-checkin-security-contract.md).
The Owner approved these as design requirements; none is implemented yet:

- 5 consecutive failed PIN attempts per normalized member identifier.
- A 15-minute identifier lockout after the fifth consecutive failure.
- 10 requests per identifier per rolling 5-minute window.
- 60 requests per trusted source network per rolling 5-minute window.
- 300 requests globally per rolling 5-minute window.

The thresholds are approved design values, not configured or operational
controls. Verify them using synthetic load, shared-network, and
denial-of-service tests before production use.

For PIN recovery, the Owner initiates and verifies in person using existing
membership, registration, and available payment records; government-issued ID
is not mandatory. Use the registered mobile when accessible. If records are
insufficient or conflict, stop until manually resolved. The Owner documents
the verification method and outcome, then hands a single-use 15-minute
capability directly to the verified member. Store only its secure hash,
invalidate previous unused capabilities, and securely replace the old
verifier. The old PIN is never retrieved or disclosed. Recovery policy is not
implemented.

For mobile-number changes, the Owner verifies the existing member record and
uses the old number when accessible; otherwise use membership, registration,
and available payment records. Stop for manual resolution on conflicts or
insufficient records. Record privacy-conscious old/new number references;
notify the previous number when practical and safe. No public unauthenticated
number-change endpoint is allowed. This procedure is not implemented.

Idempotency proposal: use high-entropy keys scoped to each operation, store
keyed key/fingerprint digests without PINs or raw identifiers, re-authenticate
on retry, replay only the same safe outcome for the same fingerprint, and
reject key/payload mismatch. Proposed result retention is 24 hours; attendance
unique constraints continue to block duplicate effects after result expiry.
Audit/business history is append-only and archived in encrypted,
integrity-verifiable form. Keep operational throttle data separate, with a
proposed 24-hour cleanup after its latest applicable window/lockout. These
retentions and archive cadence remain subject to legal/accounting/privacy
review; no statutory duration is assumed.

Remaining Owner decisions relevant to Attendance are:

- Privacy-conscious format for old/new mobile-number references and exact
  notification procedure; notify the previous number when practical and safe.
- Detailed online e-wallet/bank-transfer evidence standard and whether
  periodic independent review of Owner confirmations/corrections is practical.
- Cash opening-float procedure, drawer close cadence, variance escalation, and
  adjustment evidence. Reconciliation must record opening float, actual cash
  received, closing cash, expected cash, and variance.
- Exact idempotency-result retention and deletion schedule; 24 hours is a
  technical proposal, not a statutory or final retention period.
- Audit/payment-history retention duration and archive cadence after legal,
  accounting, and privacy review. Monthly encrypted archiving and a quarterly
  synthetic restore/hash-chain check are suggested starting cadences, not an
  approved backup schedule. No statutory duration is asserted.
- Walk-in request lifetime and expired-request handling. An expired request
  must never be revived.
- If offline Owner claims are later authorized: queue expiry, clock-drift
  tolerance, stale/conflicting claim review path, and the provisional 24-hour
  triage threshold.
- Final trusted server-function boundary and confirmation of selected
  Supabase plan limits before production use.
- Grounds, evidence, and review procedure for a separate member security
  suspension; suspension must deny access without changing paid dates or
  creating an expiry override.
- Backup cadence, recovery objectives, key custody, and verified provider
  capabilities for production data.
- Applicable privacy notice, member rights/request handling, incident response,
  and record-specific retention after appropriate Philippine review.

PIN abuse settings and recovery token handling require synthetic security
validation; approval of design values is not evidence that implementation or
testing has occurred. Proposed idempotency and throttle-data retention and
audit/archive rules still need legal/accounting/privacy review; exact retention
durations are unresolved and no statutory period is assumed.

## 8. Implementation blockers and sequence

1. Resolve insufficient/conflicting record cases and finalize audit-safe mobile
   update/notification details. Then implement and test the approved PIN,
   recovery, and payment security policies in synthetic environments.
2. Confirm the intended Supabase project's actual migration/function/RLS/grant
   state through an Owner-controlled, read-only verification path. Do not
   expose credentials to the Developer or use live member records.
3. Review and validate draft schema in a disposable local Supabase/PostgreSQL
   environment. Do not apply to the hosted project as part of this phase.
4. Implement a narrow server-side PIN check-in operation: rate-limit before
   Argon2id; generic failures; credential-version recheck; Manila date; active
   member + fully paid membership eligibility; inclusive expiry; idempotency;
   duplicate serialization; attendance+audit atomic commit.
5. Add the public QR landing/check-in UI only after the backend contract,
   RLS/execute grants, and integration tests pass.
6. Add Owner attendance history and reasoned validity resolution with
   append-only audit behavior.
7. Decide walk-in request lifetime, then implement fee versioning, provisional
   opaque request creation, Owner-confirmed actual payment, and atomic
   payment/attendance finalization.
8. Consider provisional offline Owner claims only after separate Owner
   decisions and tests. Do not add public/offline member check-in or payment
   confirmation.

No migrations, functions, UI, or database policies were changed during this
audit/design task.

## 9. Release test requirements

Run these with synthetic fixtures in a disposable local environment before
release:

- Apply and inspect the complete migration chain against the target PostgreSQL
  version; verify migration order and rollback behavior.
- Check `anon`, non-Owner authenticated, active Owner, and trusted service
  access to every table/function; verify RLS and exact execute grants.
- Correct/wrong PIN, unknown ID/mobile, ineligible state, unconfirmed/voided
  payment, activation/expiry boundaries, inclusive expiry, and non-enumerating
  responses.
- `Asia/Manila` date transitions and UTC boundary cases; reject
  browser/device-supplied dates.
- Concurrent check-in attempts, duplicate index backstop, idempotent retries,
  key/payload mismatch, member reset race, and forced transaction rollback.
- PIN rate limits/lockout, parallel attempts, normalization variants, shared
  NAT, Argon2 resource use, and service-wide throttle behavior.
- Verify no PIN/hash/token/raw phone/access token enters logs, audit metadata,
  client storage, caches, telemetry, or error messages.
- Audit append and verification, mutation denial, reasoned validity resolution,
  and rollback if audit insertion fails.
- Once walk-ins are implemented: immutable fee snapshot, Owner verification,
  exact allocation, request expiry, replay/reuse, concurrency, and atomic
  payment-plus-attendance rollback.
- Once offline Owner claims are approved: encrypted queue, provisional labels,
  stale/conflicting claim review, server revalidation, idempotent sync, and
  proof no offline result is valid before server acceptance.
- Browser tests for QR path, responsive UI, no sensitive precache/cache, and
  public failure behavior.

Existing proposed cases are also listed in
[security-test-plan.md](security-test-plan.md); they require an appropriate
disposable environment and have not been executed as part of this audit.

## 10. Files inspected and changed

Inspected files include `src/App.tsx`, `src/lib/supabase.ts`, the existing
Members/Membership Plans/Membership Purchases/Payments components,
`vite.config.ts`, `supabase/config.toml`, PIN shared code and enrollment
functions, `owner-status`, migrations for initial schema, memberships,
payments, walk-ins/attendance, Owner security, PIN security, audit integrity,
membership overlap, and relevant existing `docs/` security/schema decisions
and test plans.

Updated in this documentation-only task:

- `docs/member-checkin-security-contract.md`
- `docs/attendance-implementation-readiness.md`
- `docs/security-test-plan.md`

No application code, authentication, migration, database, secret, UI, or
deployment was changed.
