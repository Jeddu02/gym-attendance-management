# Phase 3D decisions and open questions

**Status:** planning record only. No Supabase connection, database operation,
migration, policy, or application workflow was performed for this document.

This record consolidates the decisions supplied for Phase 3D. Where an earlier
proposal in `database-security-design.md` conflicts with a confirmed decision
here, the confirmed decision controls. The planning documents are being
reconciled together; no implementation is authorized by this record.

## Confirmed decisions

1. Use `Asia/Manila` for gym-local dates and PHP (`PHP`, peso) for money.
2. Full payment must be confirmed before membership access.
3. One member per normalized mobile number.
4. Freeze is disabled initially.
5. Each purchase is for exactly one calendar month. Early renewal is allowed
   only as a consecutive extension starting the day after the current expiry.
   Entitlement periods cannot overlap; arbitrary future prepaid terms are not
   allowed. A lapsed term starts on its activation date. Finalized Option A:
   add one calendar month to the activation/term-start date, clamp to the final
   day of the target month, and set inclusive expiry to the preceding date
   (Jan 31 -> Feb 28/29 next-term start, expiry Feb 27/28). Activation is the
   later gym-local date of registration approval and full confirmed payment.
   Delayed confirmation never backdates access.
6. Public member check-in requires internet. Offline Owner-entered submissions
   are provisional claims until server validation. The proposed 24-hour cutoff
   is a triage rule only; client time cannot prove historical attendance.
7. Payment corrections require Owner approval, preserve the original, and record
   the reason and actors in audit history.
8. Members choose their PIN privately through a secure setup flow.
9. The Owner is the only management-system account. No public Owner registration
   after the one-time bootstrap.
10. The Developer has technical source/deployment access only, no routine access
   to live member or financial data, and is also an ordinary member subject to
   the same membership, payment, PIN, and attendance rules as everyone else.
   These are separate identities and permissions.
11. Members and walk-ins use the public entrance QR page and have no management
    account, member login, or public member dashboard.
12. No refunds of any kind, no complimentary memberships, and no checkout,
    checkout timestamps, visit-closing workflow, or occupancy/duration tracking.
13. No service-role or secret key in browser code. Use the existing React + Vite
    + TypeScript PWA and hosted Supabase services; keep the product free-first
    and do not require paid services.
14. Payment events, registration decisions, membership changes, attendance,
    PIN resets, Owner settings, backups, and security events need auditable
    history.
15. Membership cancellation and non-renewal are not features or workflows.
    Access continues through inclusive expiry; after expiry, access requires an
    approved new purchase and full confirmed payment. No expiry override is
    available in the initial release. Separate security suspension remains
    available only for its distinct audited purpose.
16. Unmatched or underpaid actual receipts are preserved in a separate review
    workflow. Until the Owner verifies and allocates a receipt, it does not
    activate membership, validate attendance, or count as confirmed income.
    Unresolved receipts are not automatically discarded; no automatic access,
    complimentary membership, or refund is created. Receipt allocation must be
    unique and distinguish money received from a purchase being fully paid.
17. If an erroneous payment confirmation supported a check-in, preserve the
    original check-in and audit history, mark its eligibility invalidated, and
    exclude it from valid-attendance totals while retaining it in history. If
    another valid payment independently establishes eligibility, a separate
    documented Owner resolution is required; never silently restore or rewrite
    the original check-in.

## Confirmed operational design

- One location initially, PHP, `Asia/Manila`, Owner-only management, and no
  manager/front-desk roles. Retain gym scope in the design for possible future
  expansion without implying current multi-location behavior.
- Required member fields are member code, full name, and unique normalized
  mobile. DOB, email, emergency contact, address, and identity-document copies
  are excluded absent a separately justified and approved need.
- Membership Option A, activation date, early renewal, and inclusive expiry are
  finalized as stated above. Exactly one complete payment per purchase; no
  installments, overpayment-as-access, grace period, cancellation/non-renewal,
  refunds, complimentary memberships, automatic renewal, freeze, expiry
  override, or checkout.
- The public entrance QR may create an opaque provisional walk-in request. The
  server snapshots the configured fee version, immutable PHP amount/currency,
  creation timestamp, and expiry. Only Owner confirmation of actual receipt
  makes payment and attendance valid in one transaction. Expired requests are
  never revived; a new request uses a new ID and current fee. Its lifetime is
  an operational setting still to be chosen.
- Walk-in methods are cash, GCash, and bank transfer. Screenshots alone do not
  prove receipt. Pending/rejected payments are not income. Corrections preserve
  originals and require reason, actor, timestamp, evidence/reference, and
  decision history. Owner is sole in-app approver; independent review is
  recommended where practical, and maker/checker separation does not exist.
- Public member check-in requires internet. Offline Owner submissions have
  unique operation IDs, idempotent sync, minimal encrypted local data, and stay
  provisional until validation. The 24-hour window is a triage/review threshold
  only; it does not prove attendance. Owner may attest current physical
  presence, but the server still checks eligibility and duplicates. Stale,
  suspicious, and conflicting claims are surfaced, never silently discarded or
  approved.
- PIN design uses private member enrollment/reset, short-lived single-use
  hashed tokens, server-side salted password hashing and protected secrets,
  generic errors, enumeration/replay protection, and rate limiting. Numeric
  thresholds and token lifetimes remain untested until security validation.
- Developer uses source and synthetic data only. Owner controls production
  project membership, secrets, releases, backups, and restores. Emergency
  Developer access, if needed, is explicit, narrow, time-limited, logged, and
  revoked. No routine live-data or privileged production credential access.
- One Owner-operated cash drawer. Reconciliation compares counted cash with
  verified physical cash receipts (including receipts awaiting allocation) and
  documented adjustments; this is separate from confirmed-income reporting.
  GCash/bank are reconciled separately.
  Closing snapshots are immutable. Floats, cadence, and variance handling are
  operational values, not invented here.

## Remaining pre-launch operational checks

- Set the walk-in request lifetime. Enforce server expiry; never revive an
  expired request. A new attempt creates a new request ID and snapshots the
  then-current fee. Set this value before accepting walk-ins.
- Validate the provisional 24-hour offline triage threshold. Set queue expiry,
  retry/backoff, midnight handling, clock-drift tolerance, encrypted local
  storage/key handling, and Owner review procedures. Unresolved claims must not
  be silently discarded; only current-date server validation makes attendance
  valid.
- Set PIN KDF parameters, attempt thresholds, cooldowns, token lifetime, and
  abuse monitoring after synthetic security testing. Examples are not tested or
  production-approved values.
- Finalize payment evidence by method, correction evidence, and periodic
  independent review where practical. The Owner remains the sole in-app
  approver; there is no maker/checker separation.
- Define separate security suspension grounds, evidence, review, and
  reinstatement. It does not alter paid dates. Registration-application
  withdrawal, Owner-account revocation, and PIN-token revocation remain only for
  their distinct purposes.
- Complete privacy notice, purpose, rights/request, and incident review with
  appropriate Philippine privacy professionals. Accountant/counsel determine
  applicable financial record categories and retention. No legal conclusion or
  retention period is assumed here.
- Owner sets key custody/rotation, backup cadence/retention, RPO/RTO, restore
  authorization, and isolated synthetic restore procedures before live data.
- Verify actual selected Supabase free-tier features, quotas, availability,
  backup/export/restore support, and cost. No guarantee or unlimited capability
  is assumed. Confirm the trusted-server and Owner-controlled release boundary.
- Configure actual plan prices and walk-in fees before sales; no amounts are
  specified by this design.

## Security and operational risks

- **Single Owner concentration:** one account creates an availability and
  correction-separation risk. Protect it with MFA, recovery controls, alerts,
  audited actions, and a tested one-time bootstrap. A backup Owner account would
  change the confirmed one-Owner rule and needs explicit approval.
- **Developer deployment privilege:** source or deployment access can become
  indirect data access if code can read secrets or query production. Enforce
  Owner-reviewed releases, restricted CI secrets, redacted logs, synthetic
  tests, no production database credentials for developer automation, and no
  developer project membership unless separately approved.
- **Public PIN endpoint:** public QR traffic is anonymous and attackable. Rate
  limit before expensive hashing, use generic responses, dummy verification for
  unknown IDs, avoid response timing distinctions, and never expose member
  status or a directory.
- **Payment fraud:** screenshots can be fabricated or stale. Confirm actual
  account/cash receipt server-side before counting income or enabling access.
  Preserve originals and corrections; do not create refund paths.
- **Offline ambiguity:** device time and queue ordering are untrusted. Server
  receipt controls local date and race resolution; old/ambiguous submissions
  cannot be converted into historical valid attendance.
- **Privacy versus accounting retention:** financial records may need retention
  while unnecessary member identifiers should be minimized or removed. Apply
  category-specific retention and separation/anonymization only after
  professional review.
- **Backups and keys:** encrypted backups are useless if keys are lost and risky
  if broadly accessible. Test isolated restores, restrict key custody, and do
  not restore production member data into developer environments.

## Consolidated confirmed model and operational checks

See `phase-3d-final-review.md` for the consolidated model, table access matrix,
transaction boundaries, security tests, and final schema review checklist. The
24-hour offline age remains a provisional triage parameter; client time never
proves historical attendance. The public QR may create walk-in requests; they
remain provisional until Owner confirmation and trusted server validation
commit payment and attendance together. The request lifetime is an operational
value to set, and expired requests always require a new request with a new
ID/current fee snapshot.

The sole Owner may propose and approve an immutable, reasoned payment correction;
there is no independent in-app maker/checker. Whether external review or
independent evidence is required remains an Owner decision. Cash reconciliation
preserves immutable close snapshots and represents later corrections separately.
No financial amount, legal retention duration, legal conclusion, backup
objective, provider guarantee, or PIN abuse threshold is invented here.
