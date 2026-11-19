# GYMFORCE — Consolidated Production Recovery Readiness

Status: NO-GO
Review date: 2026-11-19
Scope: Documentation and Owner decision preparation only

## 1. Verified Local Evidence

- Original migration integrity: PASS
- M2 diagnostic integrity: PASS
- M1/M2 structural diagnostic validation: PASS
- Original gym_settings constraint definitions: verified locally
- Historical schema-contract consistency: PASS
- PG17 customer-authority compatibility: PASS locally, as scoped
- Production authority compatibility: NOT VERIFIED

## 2. M2 Configuration Discrepancies

Table: public.gym_settings

| Property | Intended | Observed | Result |
|---|---|---|---|
| Owner | gym_data_owner | postgres | MISMATCH |
| RLS | true | true | MATCH |
| FORCE RLS | true | false | MISMATCH |

Additional findings:
- 19 reported service_role privilege records
- Candidate privilege sources are not independently verified
- Two validated constraints captured
- Zero policies reported for gym_settings
- Trusted ACL and catalog fingerprint equality pending
- Catalog visibility requires Owner attestation

## 3. Recovery Gates

| Gate | Status |
|---|---|
| A02 original zero-membership contract | BLOCKED |
| A02 redesigned customer authority | LOCAL PASS |
| A02 hosted authority and ADMIN-edge approval | HOLD |
| A03 hosted RPC/default privilege verification | HOLD |
| A04 local diagnostic preparation | LOCAL PASS |
| A07 hosted migration history/provenance | HOLD |
| M2 catalog visibility attestation | HOLD |
| Production release | NO-GO |

## 4. Owner Decisions Required

- [ ] Approve or reject the proposed A02 authority redesign.
- [ ] Review exact provider ADMIN-edge exceptions.
- [ ] Verify hosted grantor and actor capabilities.
- [ ] Approve RPC privilege allowlist and default-grant policy.
- [ ] Reconcile hosted migration history with exact artifact identities.
- [ ] Establish trusted ACL, constraint and catalog references.
- [ ] Attest M2 catalog visibility limitations.
- [ ] Review gym_settings owner and FORCE RLS discrepancies.
- [ ] Review backup, rollback, monitoring and acceptance gates.
- [ ] Separately authorize any production recovery operation.

## 5. Mandatory Restrictions

Do not:
- Rewrite historical migrations.
- Fabricate migration-history records.
- Mark unapplied migrations as applied.
- Execute blanket database pushes.
- Modify hosted roles, grants or ownership.
- Deploy or execute recovery SQL without separate approval.

## 6. Decision

Production recovery remains NO-GO.

Local test success does not certify hosted permissions,
migration history, Supabase services or production safety.

This document is a review record, not an authorization.