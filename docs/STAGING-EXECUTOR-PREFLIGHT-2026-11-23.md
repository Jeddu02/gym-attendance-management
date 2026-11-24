# Executor-hardening staging preflight — 2026-11-23

Target: GYMFORCE-Staging `yucmfsjvjskefrxfhtbd`. Read-only inspection; production untouched.

The next migration in the 37-file inventory is `20261110100000_executor_hardening.sql` (177,867 bytes). Its header explicitly requires a separately authorized Owner-controlled maintenance window and recovery plan. It contains transaction-level locks, creates three NOLOGIN roles, transfers ownership, changes function privileges, and sets future-function defaults for the three application roles only. **Do not deploy automatically** without satisfying that stated gate.

## Read-only hosted observations

| Check | Observed | Expected in migration | Result |
|---|---|---|---|
| PostgreSQL | 17.12 | PG17-compatible target | Consistent |
| Connected role | postgres | Migration's catalog/DDL expectations | Consistent; privileges not certified |
| Existing reserved application roles | 0 | Creates three if absent | Consistent |
| Application routines in api/private | 25 | 25 signatures in preflight | Count consistent; signatures not fully verified |
| Application noninternal triggers | 13 | 13 | Match |
| Private sequences | 3 | 3 | Match |
| Browser table/schema/function restrictions | All denied by separate audit | No direct access | Match |

The 37 migration filenames and 22 Edge Function entrypoints are enumerated in `docs/GYMFORCE-MIGRATION-FILE-INVENTORY.md` on the Codespaces migration branch. Staging currently has 24 recorded migrations and zero deployed Edge Functions.

## Deployment gates

1. Check full signature and metadata equality, dependencies, default ACL semantics, and service-role grants, not only counts.
2. Review Supabase hosted role/ownership and pgcrypto extension interactions before executing the ownership transfer.
3. Honor the migration's maintenance/recovery requirement. No production data changes or staging reset.
4. Apply migrations strictly in timestamp order and re-run `supabase/tests/staging_privilege_regression.sql` after each batch.
5. Deploy Edge Functions only after their corresponding database RPCs exist; then perform positive and negative HTTP/auth tests.

This document does not approve migration execution. The current read-only checks are positive but insufficient to certify the full 177 KB migration.
