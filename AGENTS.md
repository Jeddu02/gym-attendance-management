# Project requirements and development rules

## Product requirements

- Build a React + Vite + TypeScript Progressive Web App (PWA).
- Use Supabase PostgreSQL, Auth, Row Level Security (RLS), and Realtime where
  appropriate. Do not create a Supabase project or cloud resource without
  explicit approval.
- Prefer free-tier services. The product must not require a paid subscription,
  custom domain, paid SMS, or other paid service.
- The Owner is the only management-system user in the initial release. There
  are no manager or front-desk accounts.
- The Developer uses source code and synthetic test data only and has no
  routine access to live member or financial data. The Developer is also an
  ordinary gym member; that member identity grants no Owner or technical
  privileges. Keep identities and access paths separate. The Owner controls
  production project membership, credentials, secrets, releases, backups, and
  restores. Any emergency Developer access requires explicit Owner
  authorization, narrow scope, time limitation, logging, and revocation.
- Members and walk-ins use a public webpage reached through a permanent
  entrance QR code. The QR code must not contain credentials or member data.
- Members identify themselves with their Member ID or registered mobile number
  and a secure member-specific PIN. There is no member dashboard or member
  login.
- Allow at most one valid check-in per member per gym-local calendar day.
- This is check-in only. Do not add a checkout feature.
- Each membership purchase covers exactly one calendar month. Use
  `Asia/Manila` for gym-local business dates and treat expiry as inclusive
  through the entire expiry date. Option A is finalized: advance the activation
  date by one calendar month, clamp to the target month's final day, and set
  inclusive expiry to the day before that next-term start. Jan 31 advances to
  Feb 28/29 and expires Feb 27/28; Feb 28 in a normal year advances to Mar 28,
  and Feb 29 in a leap year advances to Mar 29.
- Early renewal extends the current entitlement consecutively, starting the
  day after its existing expiry. Do not allow overlapping access periods or
  arbitrary future prepaid membership terms. A renewal after expiry starts on
  its new activation date.
- Membership cancellation and non-renewal are not features or workflows. Access
  continues through inclusive expiry; after expiry, an approved new purchase
  and full confirmed payment are required. Expiry overrides are not available
  in the initial release.
- Activation date is the later of registration approval and full confirmed
  payment, evaluated as a gym-local date. Do not backdate for delayed payment
  confirmation. Early renewal starts the new term the day after existing
  inclusive expiry; after expiry, a new approved purchase and full confirmed
  payment are required. No cancellation/non-renewal, refund, complimentary
  membership, installment, grace period, automatic renewal, freeze, expiry
  override, or checkout feature is included.
- The public entrance QR may create a provisional walk-in request. The server
  assigns its opaque ID, fee version, immutable PHP amount/currency, creation
  timestamp, and expiry. Only the Owner confirms actual receipt; that operation
  atomically validates the request, payment, and attendance. Expired requests
  cannot be revived; a new request uses a new ID and current fee snapshot. The
  request lifetime is 15 minutes (Owner approved 2026-11-10). Expired requests
  stay closed; replacements receive a new ID and current fee snapshot.
- Public member self-check-in requires internet access. Offline Owner-recorded
  submissions are provisional claims with unique operation IDs. The 24-hour age
  window is a triage threshold only and remains provisional pending validation;
  device timestamps never prove historical attendance. An Owner may confirm
  physical presence for a current-date check-in, but the server still validates
  eligibility and duplicates. Stale/conflicting claims must not be silently
  discarded or approved.
- Currency is PHP. Preserve original payment transactions; corrections require
  a reason and audit history. No checkout feature or checkout-related data or
  workflow is allowed.
- Preserve unmatched or underpaid actual receipts in a separate Owner review
  workflow. Until the Owner verifies and allocates a receipt, it does not
  activate membership, validate attendance, or count as confirmed income. Never
  discard it automatically or create access, complimentary membership, or a
  refund. Keep received-money accounting distinct from purchase-paid status;
  one receipt may be allocated at most once.
- If a supporting payment confirmation is voided as erroneous, preserve every
  original check-in and audit event, mark affected eligibility invalidated,
  and exclude it from valid-attendance totals while retaining it in history.
  Any independent eligibility basis requires a separate documented Owner
  resolution; do not silently restore or rewrite the original check-in.
- Cash-drawer reconciliation tracks verified physical cash received, including
  receipts still awaiting allocation. It is separate from confirmed-income and
  membership-eligibility reporting.
- Secure server-side authorization, RLS, audit logs, payment corrections, and
  privacy safeguards are mandatory.

## Security and privacy rules

- Treat all browser input and client-side state as untrusted. Enforce business
  rules and privileged actions server-side.
- Enforce server-side authorization and enable/test RLS on every exposed table.
  Grant only the access required by the Owner and narrowly scoped server-side
  operations; do not rely on UI hiding for authorization.
- Never expose Supabase service-role or other secret keys in the browser, source
  control, logs, or `VITE_*` variables. Environment files are ignored by Git.
- Do not store, log, or expose plaintext PINs. The Owner must not learn a
  member's PIN. PIN verification must use a secure server-side design with
  rate limiting, abuse controls, and non-revealing failure responses; finalize
  setup/reset and abuse-control details before implementation.
- Minimize member data, restrict access, and define retention and correction
  procedures before production use. Avoid sensitive data in browser caches,
  analytics, or logs.
- Keep append-only or otherwise tamper-evident audit history for attendance,
  payment confirmation/correction, and privileged changes. Record actor, time,
  reason, and affected record; corrections must preserve history.
- Do not store card numbers or security codes. Any future payment integration
  must use an approved provider flow and verified server-side payment status.
- No public Owner registration is allowed after the secure one-time bootstrap.
- Treat the public QR page as public and abuse-prone. Apply server-side rate
  limits and generic responses so it cannot be used to enumerate members or
  reveal membership/payment status.
- Offline submissions are untrusted provisional claims until the server
  rechecks Owner authorization, eligibility, gym-local date, duplicate status,
  and idempotency. Do not backdate valid attendance from a client timestamp.
- Avoid caching sensitive member, payment, PIN, or attendance data in the PWA.

## Prohibited features

- No checkout feature.
- No refunds.
- No complimentary/free memberships.
- No member dashboard or member login.
- No membership access before approved registration and confirmed payment.
- No valid walk-in attendance or income until the Owner confirms actual
  payment and server-side validation succeeds.
- No treating offline Owner submissions as confirmed attendance before server
  validation.
- No payment card data storage.

## Decisions requiring Owner approval

Do not treat these as finalized requirements or encode assumptions for them in
schema, policy, or application behavior without Owner approval:

- Walk-in request lifetime is approved at 15 minutes; never revive expired
  requests. Changes to that lifetime require Owner approval.
- Offline review approved 2026-11-10: confirm physical presence only for the
  current Manila date. Older/conflicting claims remain in Owner review and may
  be resolved without attendance only with a recorded reason; never delete,
  backdate, or approve automatically. Queue retention, clock-drift tolerance,
  and the provisional 24-hour triage threshold still require validation.
- Corrections approved 2026-11-10: Owner-only, mandatory reason and evidence
  reference, preserved originals, linked void/re-record history, and affected
  eligibility invalidation. Periodic independent review is deferred until a
  practical reviewer is appointed. Detailed evidence standards remain gated.
- Cash procedure approved 2026-11-10: Owner enters and attests opening float,
  closes each Manila business day, records reason and evidence reference for
  every variance, and never changes income automatically to match cash counts.
- PIN setup/reset uses Owner-supervised in-person identity verification and
  a one-use setup link (preparation approved 2026-11-10). Token lifetime and
  production abuse/KDF parameters still need approval after synthetic testing;
  preparing the flow does not authorize enabling it in production.
- Grounds, evidence, and review procedure for separate account/member security
  suspension. Required member fields are member code, full name, and unique
  normalized mobile; finalize the mobile-change verification method.
- Privacy notice, purposes, rights/request handling, incident response, and
  record-specific retention after appropriate Philippine review.
- Backup cadence, recovery objectives, key custody, and actual provider
  capabilities before production data.
- Trusted server boundary approved 2026-11-10: expose only the `api` RPC schema
  to PostgREST; keep private tables unexposed, deny anon/authenticated routine
  execution and direct service-role data access, and use verified Owner identity
  or narrowly scoped public server handlers. Local preparation/testing only;
  hosted configuration, migration authority and plan limits still require
  separately authorized verification. Do not assume free-tier guarantees.
- Emergency Developer access, if ever used, requires explicit Owner
  authorization, narrow scope, time limitation, logging, and revocation. The
  Developer has no routine live-data or privileged production-credential access.
- Validate proposed PIN abuse values under synthetic load, shared-network, and
  denial-of-service testing before setting production thresholds.

## Development workflow

- Inspect existing files and Git status before editing. Preserve user work; do
  not delete or overwrite unrelated files.
- Keep changes limited to the approved phase. Ask before destructive actions,
  cloud provisioning, deployment, or unexpected dependency additions.
- Use `npm.cmd` in Windows PowerShell if `npm.ps1` is blocked by execution
  policy.
- Keep `.env` files and credentials out of Git. `.env.example` may contain
  placeholders only.
- Run lint, typecheck, and build checks after foundation changes; report the
  commands actually run and their results.
- Do not implement membership, payment, attendance, PIN verification, or
  administrative screens until their requirements and security design are
  approved.
