# Ownership/executor proposal — DRAFT ONLY

Latest preparation: [controlled-pilot/README.md](controlled-pilot/README.md).
A separate gated catalogue-only rollback candidate is prepared, with 23 offline
refusal tests. Original blocked SQL drafts are unchanged. Recovery evidence,
post-rollback verification and isolation decisions block executable client
preparation; no database connection was made. **NOT READY for pilot execution.**

Latest review: [accelerated-review/README.md](accelerated-review/README.md).
All 17 draft procedural bodies now parse after narrow CASE-parenthesis fixes.
The separate aligned contract integrates all 110 constraints, 149 columns and
28 explicit indexes/40 keys. Existing security safeguards and unconditional
execution blockers remain. Offline checks pass; five default changes, safe
promotion/recovery approval and restricted-executor runtime acceptance remain.
**NOT READY for controlled local execution.**
The [earlier review](pre-execution-security-review.md) is retained as history.

Latest cause analysis and exact non-executable correction:
[default-privilege-proposal.md](default-privilege-proposal.md).
Eleven narrow queries have been accepted. All ten flags are built-in PUBLIC
defaults, not explicit/inherited default-ACL configuration. The corrected draft
accepts only unmodified implicit type USAGE; five future-function EXECUTE
hardening blockers remain. Definition alignment and offline parser/integration
are complete; runtime validation remains unperformed.

**Corrected draft: NOT READY for local application.** Read
[technical-review-2026-11-06.md](technical-review-2026-11-06.md) before relying on
this proposal's acceptance claims. The latest addendum records restored guards,
31 offline refusal cases and remaining catalog/deparser/runtime blockers.
Only draft files and offline validators were changed. Authorized catalog
investigation used guarded read-only connections; no database changes occurred.

## Approval and containment

The user approved **draft preparation and scoped read-only inspection only**.
No migration/assertion/privilege proposal draft has been submitted to PostgreSQL,
applied, deployed, staged, committed, or pushed. Only approved structural catalog
SELECT queries and identity preflight have connected to the dedicated database.
The SQL is outside `supabase/migrations`, uses `.sql.draft` suffixes, and
starts with an unconditional exception inside a transaction. Removing that
blocker or promoting a copy is a separately approved action. The existing 24
migrations, bootstrap, runner and historical assertions remain byte-for-byte
unchanged by this proposal.

Draft migration: `20261106120000_owner_executor_foundation.sql.draft`.
The timestamp is a proposed future migration identifier, not an applied version.
Do not feed this file to psql, a migration runner, or a hosted SQL editor.

## Design and complete object scope

- `gym_data_owner`: existing NOLOGIN/non-superuser/non-BYPASSRLS data owner.
  Owns the 22 application tables and their three identity sequences. Owns
  nine private helper functions, all SECURITY INVOKER.
- `gym_owner_executor`: existing restricted NOLOGIN role. Owns 14 current
  server-only API definers (Owner operations, Owner verification, audit append/
  verification). Has only the column/command/sequence permissions below.
- `gym_public_executor`: existing restricted NOLOGIN role. Owns the two
  server-only PIN-enrollment/reservation API definers. This is not a member
  account or public SQL role. The browser never receives its credentials,
  membership, direct-table grants, or execute grants.
- `service_role` keeps schema API usage and EXECUTE on exactly the existing
  16 API signatures. It gets no private schema usage or direct application
  table/sequence grants. Every public/browser caller stays outside this boundary.
  Existing Edge handlers must still validate tokens/capabilities and derive
  actor identity; CORS and this ownership proposal do not replace that.
- Seven private trigger definers become INVOKER; the pure audit-hash helper
  and dormant `private.is_active_owner()` stay INVOKER. All function bodies are
  fingerprint-pinned and unchanged. The dormant helper is not newly exposed.
- FORCE RLS on all 22 application tables. Exactly 34 policies are scoped to
  a named executor **and command**, with a CURRENT_USER equality predicate.
  Authorization comes from the unchanged, allowlisted entrypoints and their
  active-Owner/capability checks. These are not browser/member allow policies.
  Tables without an implemented operation get no runtime privileges or policies.

PostgreSQL requires an allowing policy for non-bypass runtime access after
RLS is enabled; FORCE also subjects the data owner to RLS. See
[PostgreSQL 17 RLS](https://www.postgresql.org/docs/17/ddl-rowsecurity.html).
The role/command policies intentionally replace superuser bypass with explicit
runtime authority; they must be reviewed as a security design change, not
introduced simply to obtain a green assertion.

Every directly or transitively affected object is enumerated in
`object-manifest.json` and `dependent-objects.json`:

| Kind | Count / change |
|---|---|
| Application tables | 22 explicit owner/RLS/ACL changes, listed below |
| Identity sequences | 3 owner dependencies; no executor grants |
| Dependent indexes | 57 named in dependent inventory; ownership follows table |
| Composite/array types | 44 named in dependent inventory; ownership follows table |
| API/private functions | 25 exact signatures below; body fingerprints preserved |
| New policies | 34 exact table/name/role/command records in manifest |
| Existing triggers | 13 exact definitions pinned; not recreated or rewritten |
| Schema ACLs | private, api, public, extensions; schema owners unchanged |
| Extension function ACL | EXECUTE on `extensions.digest(bytea,text)` to Owner executor only; no body/owner/version change |
| Roles | Per-object grants to existing roles only; no CREATE/ALTER ROLE or membership grants |
| Auth/provider objects | No Auth/GraphQL/extension ownership or provider-role changes |

The three sequences are `private.audit_events_id_seq`,
`private.payment_events_id_seq`, and
`private.pin_enrollment_global_rate_limit_events_id_seq`. Their exact identity
column bindings are checked; ownership follows the parent table instead of
issuing an independent owner change against an internally dependent sequence.
Constraints stay attached and unchanged. No data, dates, receipt facts, audit
history, function bodies, fees, PIN parameters or lifecycle states are rewritten.

### Table/column/command matrix

All listed SELECT/INSERT/UPDATE permissions are column grants. DELETE is allowed
only for the existing enrollment rate-event retention operation. No executor
gets TRUNCATE, REFERENCES, TRIGGER, MAINTAIN, sequence UPDATE, or schema CREATE.
No grant options or executor/data-owner memberships are introduced.

| Table | Proposed runtime permissions |
|---|---|
| `private.attendance_checkins` | No runtime grants or policies; default deny |
| `private.attendance_validity_resolutions` | No runtime grants or policies; default deny |
| `private.audit_chain_heads` | `gym_owner_executor`: SELECT(stream_key, last_event_id, last_event_hash, updated_at)<br>`gym_owner_executor`: INSERT(stream_key, last_event_id, last_event_hash)<br>`gym_owner_executor`: UPDATE(last_event_id, last_event_hash, updated_at) |
| `private.audit_events` | `gym_owner_executor`: SELECT(id, actor_user_id, event_type, subject_type, subject_id, details, created_at, stream_key, previous_event_hash, event_hash)<br>`gym_owner_executor`: INSERT(stream_key, actor_user_id, event_type, subject_type, subject_id, details) |
| `private.cash_drawer_sessions` | No runtime grants or policies; default deny |
| `private.cash_reconciliation_adjustments` | No runtime grants or policies; default deny |
| `private.cash_reconciliations` | No runtime grants or policies; default deny |
| `private.member_pin_credentials` | `gym_public_executor`: SELECT(member_id)<br>`gym_public_executor`: INSERT(member_id, password_hash, credential_version, created_at, updated_at) |
| `private.member_pin_setup_tokens` | `gym_owner_executor`: SELECT(id, member_id, token_hash, token_purpose, expires_at, consumed_at, created_at)<br>`gym_owner_executor`: INSERT(member_id, token_hash, token_purpose, expires_at)<br>`gym_owner_executor`: UPDATE(consumed_at)<br>`gym_public_executor`: SELECT(id, member_id, token_hash, token_purpose, expires_at, consumed_at)<br>`gym_public_executor`: UPDATE(consumed_at) |
| `private.members` | `gym_owner_executor`: SELECT(id, member_code, full_name, mobile_lookup_hash, mobile_encrypted, status, created_at, updated_at, approved_at)<br>`gym_owner_executor`: INSERT(member_code, full_name, mobile_lookup_hash, mobile_encrypted, status)<br>`gym_owner_executor`: UPDATE(updated_at)<br>`gym_public_executor`: SELECT(id, status)<br>`gym_public_executor`: UPDATE(updated_at) |
| `private.membership_plans` | `gym_owner_executor`: SELECT(id, name, price_php, is_active, created_at)<br>`gym_owner_executor`: INSERT(name, price_php, is_active)<br>`gym_owner_executor`: UPDATE(name, price_php, is_active) |
| `private.membership_purchases` | `gym_owner_executor`: SELECT(id, member_id, plan_id, price_php, purchase_status, activation_date, expiry_date, created_at)<br>`gym_owner_executor`: INSERT(member_id, plan_id, price_php, purchase_status)<br>`gym_owner_executor`: UPDATE(purchase_status) |
| `private.owner_access` | `gym_owner_executor`: SELECT(user_id, is_active, created_at, deactivated_at) |
| `private.payment_allocations` | `gym_owner_executor`: SELECT(id, payment_id, membership_purchase_id, walkin_request_id, allocated_by, allocated_at)<br>`gym_owner_executor`: INSERT(payment_id, membership_purchase_id, allocated_by) |
| `private.payment_corrections` | No runtime grants or policies; default deny |
| `private.payment_events` | `gym_owner_executor`: SELECT(id, payment_id, event_type, reason, actor_user_id, created_at)<br>`gym_owner_executor`: INSERT(payment_id, event_type, reason, actor_user_id) |
| `private.payment_records` | `gym_owner_executor`: SELECT(id, amount_php, payment_method, received_at, verification_status, external_reference, evidence_reference, recorded_by, created_at, operation_id, target_membership_purchase_id)<br>`gym_owner_executor`: INSERT(amount_php, payment_method, verification_status, external_reference, recorded_by, operation_id, target_membership_purchase_id)<br>`gym_owner_executor`: UPDATE(verification_status) |
| `private.pin_attempt_buckets` | No runtime grants or policies; default deny |
| `private.pin_enrollment_global_rate_limit_events` | `gym_public_executor`: SELECT(requested_at)<br>`gym_public_executor`: INSERT(requested_at)<br>`gym_public_executor`: DELETE(table) |
| `private.walkin_fee_versions` | No runtime grants or policies; default deny |
| `private.walkin_requests` | No runtime grants or policies; default deny |
| `public.gym_settings` | No runtime grants or policies; default deny |

Two executors receive UPDATE only on `members.updated_at` to retain the
existing `SELECT ... FOR UPDATE` member-row locks. This does not implement an
approval/status update operation. PostgreSQL requires UPDATE privilege on at
least one column for row-locking SELECT, as described in
[SELECT privileges](https://www.postgresql.org/docs/17/sql-select.html).
This small residual write capability is an explicit review risk. Removing it
requires a separately reviewed locking/function-body redesign, not silently
dropping locks or granting UPDATE on status/approved_at.

No executor receives sequence privileges. All three columns use GENERATED
ALWAYS AS IDENTITY and no current function explicitly calls nextval/currval/
lastval/setval. PostgreSQL's identity evaluation does not perform the ordinary
caller sequence ACL check; the technical review links the 17/18 implementation.
Identity insertion still requires later authorized runtime verification. Owner
executor can SELECT all current member columns because existing routines use
full row types; it receives no PIN-verifier SELECT privilege. The manifest
pins columns/types so an added sensitive column cannot silently extend this
draft's reviewed permission set.

### Function ownership / execution matrix

Implicit owner execution is retained explicitly. All non-owner callers below
receive EXECUTE only, with no grant option. Private helpers have no public/
browser/service execution. Public executor can call audit append for the
existing enrollment audit flow; it receives no audit-table writes directly.

| Exact signature | Proposed owner | Execution | Additional callers |
|---|---|---|---|
| `api.append_audit_event(text, uuid, text, text, text, jsonb)` | `gym_owner_executor` | DEFINER | `service_role`, `gym_public_executor` |
| `api.is_active_owner_for_user(uuid)` | `gym_owner_executor` | DEFINER | `service_role` |
| `api.member_enroll_pin(text, text)` | `gym_public_executor` | DEFINER | `service_role` |
| `api.owner_confirm_membership_payment(uuid, uuid, boolean)` | `gym_owner_executor` | DEFINER | `service_role` |
| `api.owner_create_membership_purchase(uuid, uuid, uuid)` | `gym_owner_executor` | DEFINER | `service_role` |
| `api.owner_create_pin_enrollment_token(uuid, uuid, text, timestamp with time zone)` | `gym_owner_executor` | DEFINER | `service_role` |
| `api.owner_list_members(uuid, text, text, integer, integer)` | `gym_owner_executor` | DEFINER | `service_role` |
| `api.owner_list_membership_payments(uuid, text, text, integer, integer)` | `gym_owner_executor` | DEFINER | `service_role` |
| `api.owner_list_membership_plans(uuid)` | `gym_owner_executor` | DEFINER | `service_role` |
| `api.owner_list_membership_purchases(uuid, text, text, integer, integer)` | `gym_owner_executor` | DEFINER | `service_role` |
| `api.owner_record_membership_payment(uuid, uuid, uuid, numeric, text, text)` | `gym_owner_executor` | DEFINER | `service_role` |
| `api.owner_register_member(uuid, text, bytea, bytea)` | `gym_owner_executor` | DEFINER | `service_role` |
| `api.owner_reject_membership_payment(uuid, uuid, text)` | `gym_owner_executor` | DEFINER | `service_role` |
| `api.owner_save_membership_plan(uuid, uuid, text, numeric, boolean)` | `gym_owner_executor` | DEFINER | `service_role` |
| `api.reserve_pin_enrollment_request()` | `gym_public_executor` | DEFINER | `service_role` |
| `api.verify_audit_stream(text)` | `gym_owner_executor` | DEFINER | `service_role` |
| `private.audit_events_chain_insert()` | `gym_data_owner` | INVOKER | `gym_owner_executor` |
| `private.compute_audit_event_hash(bigint, text, text, uuid, text, text, text, jsonb, timestamp with time zone)` | `gym_data_owner` | INVOKER | `gym_owner_executor` |
| `private.guard_membership_payment_allocation()` | `gym_data_owner` | INVOKER | `gym_owner_executor` |
| `private.guard_membership_payment_record_insert()` | `gym_data_owner` | INVOKER | `gym_owner_executor` |
| `private.guard_membership_payment_record_update()` | `gym_data_owner` | INVOKER | `gym_owner_executor` |
| `private.guard_purchase_pending_activation()` | `gym_data_owner` | INVOKER | `gym_owner_executor` |
| `private.is_active_owner()` | `gym_data_owner` | INVOKER | Owner only; dormant helper |
| `private.prevent_audit_event_mutation()` | `gym_data_owner` | INVOKER | `gym_owner_executor` |
| `private.prevent_payment_history_mutation()` | `gym_data_owner` | INVOKER | `gym_owner_executor` |

## Preconditions, postconditions and atomicity

The native draft requires the exact approved local marker, system identifier,
canonical data path, loopback endpoint, database, postgres session/current role,
and real superuser DDL actor. It requires existing safe reserved-role attributes,
zero reserved-role membership edges, the exact 22-table/25-function inventory,
original owners, body hashes, safe search paths, closed caller ACLs, expected
columns/types, valid constraints/indexes, 13 trigger definitions, and no existing
application policies. Drift causes refusal, never automatic normalization.

After preconditions it takes a transaction advisory lock plus ACCESS EXCLUSIVE
locks on the enumerated tables, repeats preconditions, and makes all changes
in one transaction. Lock timeout is five seconds; statement timeout 120 seconds.
A maintenance window and explicit application approval are needed.

Postconditions repeat exact inventories, validate owners, FORCE RLS, all column
grants, the exact 34 role/command/predicate policies, sequence bindings/grants,
helper invoker flags, API owners/definer flags, safe search paths, routine body
hashes, trigger definitions, dependencies and caller denials. No function owner
or grantee is silently accepted just because a routine is SECURITY DEFINER.

Default ACLs are unchanged, but are now checked independently for postgres,
gym_data_owner, both executors and gym_registration_login. Effective global
defaults (including implicit defaults) and additive schema defaults are checked
for tables, sequences, functions and types. Non-owner grants refuse except
PUBLIC type USAGE without grant option under unchanged implicit built-in
defaults (no explicit global entry). Explicit type/browser grants and schema
additions remain denied. PUBLIC function EXECUTE still blocks the current
database. A separate blocked five-revocation proposal is prepared, not executed.
New functions still need explicit
PUBLIC EXECUTE revocation and reviewed grants in their creation transaction.

## Phase-aware assertions

`foundation_assertions.sql.draft` has the same unconditional draft blocker.
After separate approval a runner must select an explicit profile:

| Profile | Scope and honest result |
|---|---|
| historical_phase1 | Refuses acceptance execution; maps to original archival assertions, including obsolete empty-API assumptions |
| current_server_only | Checks today's exact ingress/RPC/table boundary and pinned source; emits a hardening warning, not a hardened-readiness claim |
| proposed_owner_executor | Requires the full proposed owners, policies, least-column matrix and invoker/definer split; cannot pass the current database |
| future_attendance | Refuses acceptance execution; eligibility/PIN verification/check-in guarantees are not implemented |

The old foundation assertion file is unchanged and its ownership failure is
not hidden. The proposal removes **obsolete phase-shape assumptions from new
profiles**, not enduring security requirements. API access remains service-only,
browser/private denial remains strict, and the target profile requires stronger
ownership/RLS controls. No test is weakened to report an unimplemented feature
as passed. Profile code is native-only; hosted/provider checks require their own
reviewed adapter and cannot use a fabricated GraphQL shim.

## Lifecycle dependencies — no feature implementation

- Registration approval needs an independently authorized Owner RPC/Edge path,
  trusted approval timestamp and audit event. The draft deliberately grants
  neither UPDATE(status) nor UPDATE(approved_at) to an executor.
- Confirmation still reaches pending_activation. New confirmed-payment
  activation needs a reviewed operation, immutable confirmation-time basis and
  eligibility checks. The draft grants neither UPDATE(activation_date) nor
  UPDATE(expiry_date). It cannot manufacture access from a receipt record.
- Calendar-month expiry remains Option A: advance activation one calendar month,
  clamp to the final day and subtract a day. Expiry is inclusive in Asia/Manila.
  Later approval/full-confirmation governs new/expired activation; early renewal
  begins the day after existing inclusive expiry.
- Renewal serialization needs per-member locking, consecutive/non-overlapping
  entitlement checks, idempotency and an approved limit on queued advance terms.
  The existing row locks and overlap exclusion stay unchanged.
- Void/correction handling needs separately approved immutable events, affected
  entitlement/attendance invalidation and accounting distinctions. No executor
  DELETE privilege exists on receipts, allocations, payment events or audits.
- Underpaid/unmatched actual receipts still need an Owner review/allocation
  workflow. This draft does not turn current rejection into that workflow.
- No cancellation, grace period, refund, complimentary membership, checkout,
  Attendance operation or UI is added. Future permissions require a new reviewed
  grant/policy/function-body manifest rather than borrowing broad privileges.

## Hosted compatibility and security risks

This is a **native test-target draft**, not a hosted migration ready to upload.
Hosted postgres may lack superuser and SET/ownership-transfer capabilities.
The native-only precondition deliberately rejects that environment. Review
[ALTER FUNCTION ownership prerequisites](https://www.postgresql.org/docs/17/sql-alterfunction.html)
before designing a hosted transfer; do not add permanent role memberships to
make it work. Supabase-managed roles may have different attributes/default ACLs.

Owner-controlled hosted inventory must compare existing migrations, columns,
bodies, grants, role memberships, extensions and Auth/provider ownership. Hosted
PostgreSQL 17 deparser output and provider extension versions can differ from
the native 18 manifest; differences require review, not disabling checks.
Digest ACL authority, internal identity dependencies, FORCE RLS behavior under
nested definers/invoker triggers, FK checks, row locks and trigger execution all
need actual synthetic integration tests. Service-role BYPASSRLS on a hosted
plan is not a substitute for missing privileges or correct API authorization.

Existing audit hashing/timezone behavior, phase-aware defaults, deployment
ordering, privileged migration-actor control and future schema drift remain
review risks. Current membership lifecycle gaps remain blockers even if
ownership application eventually passes. No Free-plan capability is assumed.

## Future sequence — every execution/deployment approval remains separate

1. Review this manifest, policy/column matrix, locking residual privilege,
   function call graph and phase profiles. Approve a promoted revision and
   define maintenance/backup/rollback evidence under Owner control.
2. Obtain explicit **local application approval**. Reverify the existing native
   cluster and source/baseline hashes. Promote a reviewed copy, deliberately
   remove the draft blocker, and apply that new forward migration once. Never
   reapply the old 24 or reset the existing database to hide a failure.
3. Under separate test authorization, run the proposed profile and synthetic
   role/RPC/trigger/FK/audit/sequence tests. Exercise actual Owner registration,
   plans, purchase, payment record/confirm/reject, enrollment, reservation,
   duplicate/concurrent attempts, negative actor paths and rollback. Fingerprint
   persisted state and test grant leakage. No runtime proof is claimed today.
4. Have the Owner review hosted Supabase inventory and PostgreSQL 17 compatibility
   using synthetic/staging data. Prepare an independently reviewed hosted
   adaptation if necessary; no local marker/path copy or provider-object transfer.
5. Obtain **separate hosted deployment approval**. The Owner controls credentials,
   backups, migration/function deployment and restoration. Do not expose
   production credentials or live member/financial data to the Developer.
6. Review the exact Git diff and approved revision. Only on explicit instruction
   commit/push; confirm Pages production branch/build settings. Keep drafts
   outside active migrations until promotion is authorized.
7. Obtain online-test approval for synthetic Owner-controlled testing at
   https://gymforce.mx. Verify deployed DB/Edge revisions, Owner authorization,
   existing CORS/login, membership regression, logs and PWA behavior. No
   Attendance claims may be inferred from existing Owner login.

**GitHub/Cloudflare deployment does not deploy Supabase migrations, grants,
secrets or Edge Functions.** Plan backend changes and frontend compatibility
explicitly; do not depend on an automatic Pages build for database release.

## Validation status

The corrected-draft follow-up adds `validate-offline.ps1` and 31 independent
negative subprocess cases. Each refusal must exit 1 for its expected reason;
the positive control exits 0. The checker compares structured source metadata
and a complete reviewed statement inventory, including generated guard bodies.
It does not execute SQL or refresh its own baselines.

`schema-contract.json` is derived from the original migration sources, not a
catalog export. Strict lexical comparison preserves casts, literals and
grouping. PostgreSQL deparser differences (IN/ANY, text/NULL casts, TRIM/btrim)
still need authoritative alignment and can currently refuse a healthy database.
Unknown default privileges also refuse. These are unresolved application
blockers, not reasons to weaken guards. Read the current review addendum.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File docs/drafts/foundation-2026-11-06/validate-offline.ps1
if ($LASTEXITCODE -ne 0) { throw 'Stop: offline validation failed.' }
```

Future SQL execution requires a separately approved identity preflight and
fail-fast runner using `psql -X -w -v ON_ERROR_STOP=1`, with native failures
propagated to its process exit. No executable SQL runner is promoted here.

On November 6, 2026, the filesystem-only static review passed, including hashes
for all 24 existing migrations and protected harness sources. Existing Deno
shared-function unit tests passed: **38 passed, 0 failed**, using cached
dependencies and only their two named environment permissions. These results
do not validate the proposed SQL at runtime.

Run `static-review.ps1` for filesystem-only manifest/source/hash and lexical
checks. This is not a PostgreSQL parser or runtime security proof. Existing
Deno unit tests can run without applying the draft; they do not test these SQL
ownership changes. Read-only catalog inventory supplied the manifests.
Neither draft SQL file nor any portion of its executable blocks is to be run
in this approval scope. All baseline migrations/assertions remain unchanged.

