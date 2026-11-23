# GYMFORCE — Native backend batch execution (Codespaces)

## Evidence and scope

- C3 baseline: user-run PG17 localhost identity, Codespaces config, lint, TypeScript, static security, 93/93 Node tests and Vite build all passed on 2026-11-23.
- C3.5 onward: repository preparation only until the new combined script is run and its output reviewed.
- No Docker, hosted credentials, hosted SQL, or changes to the 37 historical migrations.
- A02 hosted migration authority remains pending. Production is NO-GO.

## Batch A — C3.5/C4 preparation (ready to run)

`git pull --ff-only && bash scripts/run-native-preintegration-batch.sh`

This checks the real local PostgreSQL 17 cluster, available extensions and roles, historical migration fingerprints, offline SQL validation, frontend build and security tests. It does not execute migration SQL or install backend binaries. Save its terminal output as evidence.

## Batch B — isolated backend integration (blocked pending Batch A inventory and explicit local mutation approval)

1. Review PG17 extensions, Supabase-compatible roles and schema prerequisites against the historical migrations and synthetic compatibility manifest. Do not assume a stock PGDG cluster has Supabase extensions or auth schemas.
2. Select a dedicated disposable test cluster and isolated database, with local-only socket/loopback, generated non-production credentials and bounded cleanup. Do not reuse the OS-owned 17/main cluster for destructive test execution.
3. Review the exact migration order, provider compatibility overlays, extension requirements, transactional behavior and failure recovery before applying anything.
4. Review pinned native PostgREST, Deno and GoTrue versions and source/checksums. GoTrue can migrate its own auth schema on startup; require an explicit decision before launching it.
5. Run actual native HTTP/RLS/authorization tests using only synthetic identities and the application's existing handlers; log negative cases and fail closed.

## Batch C — functional acceptance and release gating

Test member QR/PIN check-in, walk-in pending/confirmed payments, one check-in per Manila calendar day, expiry, role boundaries, no refunds, offline provisional queue, error paths, mobile layout and accessibility. Record test evidence, triage failures and repeat regressions. Hosted A02 and production deployment require separate authorization and verified production state.

## Required distinctions

A successful static source fingerprint does not establish successful SQL execution. A successful frontend build does not establish working authentication. A local synthetic integration PASS cannot authorize a production migration. Never treat the number of remaining steps as a substitute for passing gates.
