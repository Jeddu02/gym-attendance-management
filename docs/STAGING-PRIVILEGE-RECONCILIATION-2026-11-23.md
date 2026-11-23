# Staging privilege reconciliation — 2026-11-23

## Scope and verified observations

Target: `GYMFORCE-Staging` (`yucmfsjvjskefrxfhtbd`), PostgreSQL 17, Tokyo. Production was not accessed for mutation.

The 24 recorded migrations are present through `20261030120000_owner_membership_payments` (migration history records a renamed timestamp). There are zero deployed staging Edge Functions at the time of inspection.

The live read-only privilege audit `supabase/tests/staging_privilege_regression.sql` executed without exception. It checks schema USAGE/CREATE, direct relation privileges (including TRUNCATE/REFERENCES/TRIGGER), RLS, and direct function EXECUTE for `anon` and `authenticated`.

A separate read-only default ACL query showed that hosted staging has only the `postgres` creator among the five names in the native-only proposal, and no explicit global function/type default ACL entry for that creator.

## Reconciliation

The original native PostgreSQL 18 draft assertions conflated PostgreSQL's **implicit** PUBLIC USAGE on types with explicit unsafe grants. The documented classification in `docs/drafts/foundation-2026-11-06/default-privilege-proposal.md` treats implicit type USAGE as acceptable when no unexpected explicit or additive grants exist. The same document treats implicit PUBLIC EXECUTE on newly created functions as a **future-object hardening risk**, not proof that current application functions are exposed.

**Do not run** `docs/drafts/foundation-2026-11-06/default-function-privileges.sql.draft` against staging. It contains a deliberate exception, is restricted to a separate native test cluster, references local-only roles, and changes future function creation defaults for roles that do not all exist in hosted staging.

## Gate for continuation

1. Preserve existing application object ACLs and RLS, as demonstrated by the staging audit.
2. Distinguish implicit PostgreSQL defaults from explicit grants in future preflight assertions. Accept implicit type USAGE only with the narrowly documented baseline; do not relax existing function EXECUTE restrictions.
3. If a future-function default ACL policy is needed in hosted Supabase, prepare a separate provider-compatible, approved migration with extension-upgrade impact assessment. Do not silently transplant the native-only five-role proposal.
4. Inventory and review the remaining migration files and Edge Function sources before applying any. The previously quoted total of 37 is **not** proof that 13 remaining migrations are approved or deployable.
5. Re-run the audit after each staging deployment batch, followed by role-negative and service-positive integration tests.

**Current release gate:** schema security audit PASS; complete staging deployment NOT YET VERIFIED. No migration or Edge Function deployment is authorized by this document.
