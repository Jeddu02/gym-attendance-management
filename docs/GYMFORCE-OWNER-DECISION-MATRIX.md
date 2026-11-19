# GYMFORCE — Owner Decision Matrix

Status: PENDING OWNER REVIEW
Production: NO-GO

## Decision A02 — Authority Model

Proposal:
Use the locally tested redesigned customer-authority
model instead of assuming unrestricted superuser access.

Required decisions:
- [ ] Approve exact authority redesign and reviewed artifacts.
- [ ] Approve or reject the limited ADMIN-edge exception.
- [ ] Verify actual hosted grantors and role memberships.
- [ ] Verify schema and extension grant authority.
- [ ] Verify cleanup and privilege rollback behavior.

Local result: PASS within tested scope.
Hosted result: NOT VERIFIED.

## Decision A03 — RPC Privileges

- [ ] Approve exact RPC allowlist.
- [ ] Verify actual routine owners and creators.
- [ ] Verify hosted default privileges.
- [ ] Verify inherited and effective permissions.
- [ ] Approve any narrowly scoped corrective changes.

Hosted result: NOT VERIFIED.

## Decision A07 — Migration Provenance

- [ ] Verify hosted migration-history records.
- [ ] Reconcile exact original and compatibility artifacts.
- [ ] Approve truthful runner and history strategy.
- [ ] Define interrupted-run and recovery procedures.
- [ ] Require evidence before marking any migration applied.

Hosted result: NOT VERIFIED.

## Decision M2 — Security Discrepancies

- [ ] Review gym_settings ownership mismatch.
- [ ] Review FORCE RLS mismatch.
- [ ] Review reported service_role privileges.
- [ ] Review trusted fingerprint limitations.
- [ ] Attest catalog visibility limitations.

## Final Decision

- [ ] HOLD
- [ ] Approve further read-only verification only
- [ ] Approve a separately reviewed recovery plan

No selection is presumed.
This document does not authorize production actions.