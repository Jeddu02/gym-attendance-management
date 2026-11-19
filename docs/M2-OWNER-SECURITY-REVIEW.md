
# GYMFORCE — M2 Owner Security Review

Status: OPEN — PRODUCTION NO-GO
Review date: 2026-11-19

## 1. Verified Observations

Table: public.gym_settings

| Property | Expected | Observed | Result |
|---|---|---|---|
| Owner | gym_data_owner | postgres | MISMATCH |
| RLS enabled | true | true | MATCH |
| FORCE RLS | true | false | MISMATCH |

Evidence:
- M2 read-only diagnostic
- Original executor-hardening migration
- Local SHA-256 verification

## 2. Privilege Attribution

- 19 reported privilege records
- All 19 associated with service_role
- All 19 contain one candidate source
- Source legitimacy not independently verified
- Catalog visibility attestation pending

Status: NOT VERIFIED

## 3. Trusted Reference Verification

Pending:
- Approved policy baseline
- Approved constraint baseline
- Approved ACL fingerprint
- Approved catalog fingerprint

Status: NOT VERIFIED

## 4. Owner Decisions Required

[ ] Review ownership mismatch
[ ] Review FORCE RLS mismatch
[ ] Verify trusted reference fingerprints
[ ] Complete catalog visibility attestation
[ ] Resolve A02 production authority approval
[ ] Review controlled recovery procedure

## 5. Production Decision

Production recovery: NO-GO

No database modifications, migration execution,
privilege changes, deployment, or history changes
are authorized by this document.


## 3A. Local Constraint Source Consistency

Status: PASS - LOCAL SOURCE CONSISTENCY ONLY

Original migration:
20261028061728_initial_schema.sql

Historical references:
- schema-contract.json
- aligned-schema-contract.json

Verified:
- Both reference files parse as valid JSON.
- Both contain gym_settings_pkey.
- Both contain gym_settings_key_not_blank.
- Both report validated=true for both constraints.
- Constraint definitions are consistent with the original migration.

Reference file SHA-256:
- schema-contract.json:
  CEF13D83DBC3EA99750B4D5FC685FA4D13365DB5F2BD2453D491EA7D2A65CEF8

- aligned-schema-contract.json:
  97F2EFB3BE670D5841BA81E90BBDA5D68C1EF09243AEB5D52F5DE08753C2E807

M2 observations:
- Two constraints reported.
- Both reported as validated.
- Both contain SHA-256 fingerprints.

Limitations:
- No independent comparison of M2 fingerprints
  against trusted PostgreSQL catalog fingerprints.
- Historical draft contracts are not automatically authoritative.
- Local consistency does not establish production schema compliance.

Production decision: NO-GO.

## 6. Offline Evidence Investigation Conclusion

Status: INVESTIGATION DOCUMENTED — OPEN BLOCKERS REMAIN

### Confirmed observations

- public.gym_settings owner observed as postgres.
- Intended owner is gym_data_owner.
- RLS enabled matches the migration contract.
- FORCE RLS observed as false.
- Intended FORCE RLS is true.
- M2 reports 19 service_role privilege records.
- Privilege attribution remains candidate-only.
- Two validated constraints were captured.

### Local source verification

- Original schema migration SHA-256 verified.
- Executor-hardening migration SHA-256 verified.
- M2 diagnostic SHA-256 verified.
- Historical schema contracts agree on both
  gym_settings constraint definitions.
- PG17 compatibility methodology documented.

### Outstanding evidence

- Independent constraint fingerprint comparison.
- Trusted ACL fingerprint comparison.
- Trusted catalog composite comparison.
- Catalog visibility Owner attestation.
- Hosted migration history reconciliation.
- A02 production authority compatibility.
- Owner-approved recovery procedure.

### Evidence limitations

- Historical drafts are supporting references,
  not automatically authoritative baselines.
- Local compatibility tests do not certify
  hosted Supabase security configuration.
- Candidate privilege sources are not proof
  of authorized privilege grants.
- No production remediation is authorized.

### Decision

Production recovery: NO-GO.

Maintain the production freeze until the Owner
reviews the discrepancies, resolves the required
authority and provenance decisions, and separately
authorizes a verified recovery procedure.