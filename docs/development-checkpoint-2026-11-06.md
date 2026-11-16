# GYMFORCE development checkpoint — 2026-11-06

**Follow-up:** [Foundation/lifecycle review](foundation-lifecycle-review-2026-11-06.md)
records six subsequently completed non-destructive safety cases with unchanged
before/after state, fresh validation results, and a more precise distinction
between missing ownership hardening and obsolete Phase 1 test assumptions.
Ownership remains unchanged and the foundation suite still exits 3. Remaining
negative-test statements below describe the earlier checkpoint; use the
follow-up for current coverage. No Attendance implementation is approved.

## Decision and scope

**NOT READY for Attendance implementation or release.** The existing frontend
passes its local checks. The next checkpoint is review of database ownership,
membership activation, and the Attendance security contract, followed by
Owner-controlled hosted verification. This review implements no Attendance,
changes no UI, and performs no push, deployment, hosted query, migration,
bootstrap, database reset, cleanup, ownership change, or role-membership change.

The Owner reports that online login and CORS work at `https://gymforce.mx`,
with frontend hosting at `https://gym-attendance-management.pages.dev`. Those
are user-confirmed observations, not authenticated tests performed here.

## Source and Git checkpoint

- Branch: `master`; HEAD: `ba2ff726988531c143e8d3d8f1f5466f4cae236b`,
  `chore: checkpoint gymforce development and membership features`.
- Previous commits include dashboard design, dashboard components, Owner
  management, and membership purchase history.
- At inspection, tracked files were clean. Local inspection text files, two
  CSS backups, and eight `docs/local-testing/` source files were untracked.
- HEAD and the locally cached `origin/master` had zero commits of divergence.
  No fetch was performed; this does not establish the current GitHub head.
- Public web inspection could not retrieve the supplied production, Pages,
  or GitHub pages. No authenticated Cloudflare or GitHub settings were read.
- React/Vite/TypeScript frontend; lazy browser Supabase client; Owner Auth
  followed by server-side active-Owner verification; management components
  for members, plans, purchases, and payments; native SQL migration harness.
- Edge handlers validate access tokens using Auth and derive the actor ID
  from the verified user. Owner/payment RPCs use the server-only boundary.
  `APP_ORIGIN` is an exact configured origin; CORS is not authorization.
- Attendance navigation currently falls through to a placeholder. No public
  QR route, check-in endpoint, attendance RPC, Owner attendance screen,
  walk-in creation/confirmation endpoint, or offline claims queue exists.
- Registration creates pending members. No source operation was found that
  approves registration and fills `approved_at`. Purchase creation requires
  an active member. Payment confirmation reaches `pending_activation` and
  does not assign membership activation/expiry dates. Existing membership
  management is not yet a complete access-entitlement lifecycle.

## Checks actually executed

| Command/check | Result |
|---|---|
| `npm.cmd run lint` | PASS, exit 0 |
| `npm.cmd run typecheck` | PASS, exit 0 |
| `npm.cmd run build` | PASS, exit 0, including generated PWA service worker |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File supabase/tests/check-security-config.ps1` | PASS, exit 0 |
| `deno test --cached-only --allow-env=MEMBER_MOBILE_ENCRYPTION_KEY_B64,MEMBER_MOBILE_HMAC_KEY_B64 supabase/functions/_shared` | PASS, 38 tests, 0 failures, exit 0 |
| Exact approved native PostgreSQL preflight | PASS; SCRAM, ACLs, marker, system identifier, server data directory, database, role, and endpoint |
| Native preservation inventory | PASS for the specific log/catalog checks below; complete preservation/security review remains incomplete |
| `membership_payment_security_assertions.sql`, read-only session | PASS, exit 0 |
| `database_security_foundation_assertions.sql`, read-only session | FAIL, exit 3: `public.gym_settings is not owned by gym_data_owner` |

Deno 2.9.8 launches outside the sandbox; the sandbox launcher initially failed.
The first unit run without environment permission passed 34 tests and failed
four when their synthetic fixtures called `Deno.env.set`. The final run allowed
only the two required environment names, cleared inherited values in its child
process, used cached dependencies, and passed all 38. No dependency installation
or hosted call was needed. These unit tests exercise normalization, encryption,
bytea encoding, registration request/service boundaries, token generation, and
PIN hashing/verification. They do not test deployed Edge handlers or attendance.

The PWA build precached six static entries. Current source config defines no
runtime API cache. Future check-in responses and sensitive Owner/member data
must remain outside Cache Storage and precache; verify this in browser tests.
Build output is ignored and must not be committed.

Skipped intentionally: `scripts/test-pin-enrollment-rate-limit.ps1`, which
targets `localhost:5432/gym_full_migration_test`, requests a password, and
truncates rate-limit events. It is not safe to run against the approved target
unchanged. Also skipped: mutating ownership procedures and all SQL cleanup.

## Native database evidence and unresolved security findings

Fresh checks used PostgreSQL **18.6**, `gymforce_pg18_test`, user `postgres`,
at **127.0.0.1:55432**, with required SCRAM. Approved identity:

- Marker: `f497fabb-a12f-4068-b745-8b0729279276`.
- System identifier: `7704603813616068820`.
- Canonical data directory:
  `C:\Users\Banco-Sual\AppData\Local\GYMFORCE-PG18-TEST\data`.

The preserved existing migration log has 4,886 NUL characters caused by mixed
Windows PowerShell log encodings. Removing NULs in memory, without rewriting
the log, recovered exactly 24 PASS filenames in source order and the COMPLETE
marker. The corrected future logger writes UTF-8 consistently. Its changed
pipeline is verified separately using synthetic log lines; migrations must not
be reapplied to validate logging.

Read-only live inspection found:

- 22 application tables, all with RLS enabled; none with FORCE RLS.
- Final migration artifacts
  `api.owner_confirm_membership_payment(uuid,uuid,boolean)` and
  `private.payment_records_operation_id_uidx` present.
- Zero invalid/unready application indexes.
- `public.gym_settings` still owned by `postgres`.
- No `supabase_migrations` schema. This native runner has no authoritative
  per-migration database history ledger; its completion log and current
  postconditions corroborate preservation. A full object/fingerprint comparison
  and the remaining safety-negative cases are not completed by these queries.

Previous session evidence, not rerun in this checkpoint: 24 migrations
committed, 14 RLS fixture assertions passed, 18 synthetic Owner/payment
assertions passed, and eight identity
refusals returned exit 3 after the `\quit 3` defect was fixed. An environment
override rejection also passed. The interrupted final rerun is not counted as
a new pass. Wrong-database/endpoint/role/state negatives remain pending.

The broader foundation suite remains failed. Its expected ownership, forced
RLS, executor-role boundary, and Supabase GraphQL wrapper are not implemented
by the migration named `database_security_foundation`, which only prepares the
API schema and service-role usage. Tables created as `postgres` retain that
owner because the migrations contain no ownership transfer. This is a
migration/security-design gap relative to the foundation assertions; native
harness creation of empty reserved roles does not implement that design.
Owner/superuser RLS bypass and highly privileged function ownership need review.
Existing browser grant revocations remain relevant safeguards. No ownership,
membership, or privilege changes were made to conceal the mismatch.

Hosted PostgreSQL 17, Supabase Auth, PostgREST, Edge ingress, actual grants,
function revisions, CORS, and secrets remain unverified here. Native 18 results
do not establish hosted compatibility or authorize routine production access.

## Attendance implementation plan — proposal only

### 1. Close prerequisite decisions and entitlement gaps

Review the ownership/executor architecture before new privileged SQL. Reconcile
the foundation suite and migrations in a separately approved change; do not
change ownership ad hoc or relax assertions. Finish the safe negative tests
and immutable-schema preservation review against the existing local database.

Specify and test approved registration and membership activation/renewal as
prerequisites. A paid purchase needs a server-derived access period. Activation
is the later gym-local approval/full-payment-confirmation date; delayed
confirmation cannot backdate access. For early renewal use the day after
existing inclusive expiry, with consecutive terms and no arbitrary prepaid
future periods. For a new or expired term, advance activation one calendar
month with end-of-month clamping and subtract one day for inclusive expiry.
Test Jan 31, normal-year Feb 28, leap-year Feb 29, and year boundaries.

Review unmatched/underpaid actual receipts separately from purchase-paid and
confirmed-income status. Current mismatch rejection does not supply the
required Owner receipt-review/allocation workflow. Preserve received-money
facts and accounting; never create access or discard money records.

Use the existing check-in security contract for the approved PIN design
values, and reconcile remaining approval items with AGENTS.md. The contract
records five consecutive failures, a 15-minute identifier lockout, ten attempts
per identifier per rolling five minutes, 60 per trusted network per rolling
five minutes, and 300 globally per rolling five minutes. Production abuse
values require synthetic validation. Owner decisions still include
walk-in request lifetime, operational retention, stale offline claims, privacy,
backup/recovery, payment evidence/correction review, and security suspension.

There is no cancellation workflow or cancelled membership state in the
requirements. Reject expired or inactive/ineligible members and unrecognized
states. Do not add cancellation, refunds, grace periods, or expiry overrides.

### 2. Database changes after design approval

Use new forward migrations for approved changes. Do not edit/reapply the
already-applied 24 migrations as a deployment strategy.

- Review existing `attendance_checkins`, `walkin_requests`, fee versions,
  payment allocations, and validity resolutions before adding columns.
- Add a narrow server-only check-in transaction that derives
  `(trusted_server_timestamp AT TIME ZONE 'Asia/Manila')::date`, validates
  active/approved member, credential version, confirmed effective payment,
  activation date and inclusive expiry, and inserts attendance plus audit
  atomically. The browser cannot supply authoritative date or eligibility.
- Decide the reviewed Edge/SQL boundary: Edge verifies Argon2id; SQL must
  consume a narrowly scoped verification result and recheck credential version
  and eligibility under appropriate locks. No public writable attendance RPC.
- Retain the one-valid-member/day unique index as the concurrent duplicate
  backstop. Add reviewed idempotency records and an attendance-to-entitlement/
  payment eligibility basis sufficient to invalidate affected attendance if
  payment confirmation is later voided. Preserve original check-ins and audit
  history; exclude invalidated visits from valid totals.
- Implement atomic identifier/network/global attempt accounting with keyed
  digests and reviewed retention. Counter updates must survive a rejected PIN;
  they must not roll back with the attendance failure transaction.
- Server-assign each provisional walk-in's opaque ID, immutable fee-version/
  PHP amount/currency snapshot, trusted creation timestamp, and approved expiry.
- Implement Owner-confirmed receipt, allocation, request validation, attendance,
  and audit as one atomic walk-in operation. Expired requests cannot be revived;
  a new request gets a new ID and current fee snapshot. Unmatched/underpaid
  receipts remain reviewable without validating attendance or confirmed income.
- Apply/test RLS on every exposed table, explicit execute grants and owners,
  safe function search paths, and append-only correction history.

### 3. Proposed Edge Functions and frontend boundaries

Names below are proposals, not deployed interfaces or new implemented files.

| Surface | Proposed responsibility |
|---|---|
| `member-check-in` | Strict bounded JSON; normalized Member ID/mobile plus PIN; trusted ingress rate limiting before Argon2id; generic failures; no member enumeration; safe idempotency and credential-version recheck |
| `walkin-create-request` | Public abuse-limited provisional request with server fee snapshot; grants no attendance/payment confirmation |
| `owner-confirm-walkin` | Verify Auth token and active Owner; derive actor from token; validate actual receipt and call atomic SQL operation |
| `owner-list-attendance` | Owner-only paginated history and valid/invalidated totals; minimal fields and no sensitive caching |
| `owner-resolve-attendance` | Separately reviewed reason/evidence-based resolution with append-only history; no arbitrary backdating or silent restoration |

Choose a permanent public entrance URL such as `https://gymforce.mx/check-in`
only after Owner approval of the route. The printed QR contains that stable
URL alone, with no credentials or member data. It must render independently
of Owner login, using a minimal public form, generic result screen, online-only
member verification, and a separate provisional walk-in request view. Scanning
the QR alone grants no access. No member dashboard or member Auth login.

Proposed components: `PublicCheckInPage`, a narrow public route, a walk-in
request form, and an Owner `AttendancePage` using the established UI design.
Retain the existing management layout. Owner summaries count valid attendance
only; history retains invalidated/review entries. Do not add checkout UI/data.
Do not cache PINs, identifiers, eligibility, attendance responses, or payment
data in the PWA. Review deep-link fallback and service-worker updates.

Offline Owner claims remain a separate approval-gated phase. Unique operation
IDs are provisional, device times never prove historical attendance, and the
24-hour threshold is triage only. No public offline check-in or payment
confirmation is included.

### 4. Required tests and implementation gates

1. PostgreSQL 17 synthetic compatibility, exact schema/grants/owners, all RLS
   roles, direct SQL denials, and database-error rollback. No production data.
2. PIN/identifier normalization, unknown/wrong/ineligible uniform responses,
   Argon2id resource bounds, credential-reset races, atomic counters, parallel
   guesses, shared NAT, and global denial-of-service protection.
3. Approved registration plus full confirmed payment, all payment methods,
   inclusive expiry through Manila midnight, future/expired/suspended states,
   early/late renewal, end-of-month dates, and payment-void invalidation.
4. Concurrent duplicate attempts, idempotent replay and mismatched payloads,
   network retries, date tampering, audit failure rollback, and cross-role bypass.
5. Walk-in immutable snapshots, request expiry/replacement, actual Owner
   receipt confirmation, allocation once, unmatched receipts, concurrent replay,
   and atomic failure of payment-plus-attendance.
6. Public QR deep-link, small-screen forms, Owner Auth/authorization, denied
   non-Owner access, no sensitive storage/logging/cache, and no offline success.
7. Owner-controlled staging acceptance with synthetic identities, observed
   deployed migration/function revisions, PWA update behavior, and rollback
   strategy. No automatic promotion to production.

Implementation begins only after these contracts/prerequisite decisions are
reviewed. Passing today's membership units is not Attendance acceptance.

## GitHub / Cloudflare / Supabase deployment gates

- Local `master` is confirmed. **Cloudflare Pages production branch `master`
  is unverified**: no Cloudflare settings file or authenticated account access
  establishes it. The Owner must inspect Pages project `gym-attendance-management`
  and verify repository/production-branch binding, build command
  `npm run build`, output `dist`, and public frontend environment configuration.
  Do not infer the branch from a working URL or local Git branch.
- Owner login/CORS success is reported by the Owner. Verify the intended
  production origin, approved preview origins, Auth redirects, and all relevant
  Edge revisions using the Owner-controlled testing path; do not change working
  CORS or access live member/financial data during this review.
- Cloudflare publishes frontend assets. SQL migrations, RPC grants/RLS/owners,
  Edge Functions, and server-only secrets require separate hosted Supabase
  review/deployment. This documentation/logging checkpoint changes no hosted
  backend, while the future Attendance phase necessarily will.
- Ignore `dist`, build caches, `.env*` except the placeholder `.env.example`,
  credentials, logs, dumps, database directories/identity files, local inspection
  text, CSS backups, and local result/artifact directories. Existing backups
  are preserved on disk. Pattern scans found no candidate secret values in
  reviewed source/untracked files and no tracked service-role JWT; this limited
  scan is not a complete historical secret audit.
- Reviewed test source is different from generated test output. The eight
  untracked local-harness source files remain a separate explicit review/staging
  decision; they are not part of the Vite production entry graph. Do not use
  `git add .` or commit machine state/logs. No files were staged here.
- Do not push `master` or deploy automatically. A future push may trigger Pages
  automatically, so review the exact staged diff and hosting settings first.

## Recommended next action

Review the ownership/executor migration contract and the missing approval/
activation lifecycle first. Finish safe preservation/negative-test coverage
without changing the existing migrated database. Have the Owner verify Pages
branch binding and hosted revision metadata through a read-only path. Approve
the Attendance transaction/security contract and remaining operational choices
before implementation. Current frontend checks are green; the next Attendance
development phase remains **NOT READY**.
