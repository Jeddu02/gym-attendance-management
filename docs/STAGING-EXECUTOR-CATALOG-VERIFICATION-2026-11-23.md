# Staging executor-hardening preflight: verified catalog evidence

Date: 2026-11-23. Target: staging project `yucmfsjvjskefrxfhtbd` only. Read-only catalog queries; no migrations or functions deployed.

## Results

- PostgreSQL 17.12; connected database role `postgres`.
- 0 of 3 reserved application roles exist (the migration creates them).
- 25 application functions in `api`/`private`. **All 25 expected signatures and execution metadata matched** the exact `$portable_metadata$` allowlist in `20261110100000_executor_hardening.sql`. Verified routine kind, language, volatility, parallel setting, STRICT, set-returning, leakproof, argument-default count, support function, variadic status, binary body, and SQL body.
- 13 noninternal application triggers and 3 private sequences match the migration preconditions.
- `extensions.digest(bytea,text)` exists and is bound to the `pgcrypto` extension in `extensions`; not SECURITY DEFINER.
- 0 unexpected private relation kinds; 0 unvalidated application constraints; 0 application rewrite rules.
- Separate read-only security regression SQL passed for browser-facing schema, relation, RLS and function privileges.
- Supabase security advisor reported 22 INFO notices for RLS-enabled tables without policies. This matches the server-only/no-direct-browser-access design; do not add permissive policies merely to silence the advisor. Review if architecture changes. See https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy

## Remaining gate

The source migration explicitly requires a separately authorized Owner-controlled maintenance window and recovery plan. These preflight successes do not remove that condition. A full dry-run on a disposable staging-like database and provider ownership/privilege behavior checks are still needed before applying this 177,867-byte migration. Keep production unchanged.

Supabase reference: https://supabase.com/docs/guides/api/securing-your-api
