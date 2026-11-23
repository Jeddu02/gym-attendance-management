# GYMFORCE

Owner-only gym management and a public entrance check-in page, built with React,
Vite, TypeScript and Supabase. Local source includes membership approval/renewal,
receipt review and correction, cash reconciliation, audit/attendance reporting,
supervised PIN setup/reset and a permanent entrance QR generator.

Development is in progress. See [the progress tracker](docs/GYMFORCE-DEVELOPMENT-PROGRESS.md)
for verified behavior and remaining release gates. No hosted deployment or live
data access is implied by local tests. Follow [AGENTS.md](AGENTS.md).

For the November 23 audit, complete file inventory, proposed Git checkpoint and
Codespaces setup, see [the migration handover](docs/GYMFORCE-CODESPACES-HANDOVER.md).
Codespaces runtime readiness is **UNVERIFIED**; A02 is pending and production is
**NO-GO**. The prepared container installs frontend dependencies only; it does not
start Supabase, PostgreSQL, Auth or any migration.

## Local development

Use Node.js and npm (`npm.cmd` on Windows PowerShell).

```powershell
npm.cmd ci --ignore-scripts
Copy-Item .env.example .env.local
npm.cmd run dev
```

Only the Supabase URL and publishable browser key belong in `.env.local`.
Never put a service-role key, member encryption key or PIN configuration in a
`VITE_*` variable. Environment files stay outside Git. Production credentials,
project membership, releases, backups and restores remain Owner-controlled.
Use synthetic data in an isolated development project; do not create cloud
resources or connect to production as part of this setup.

Public routes: `/entrance`, `/pin-setup`, `/pin-reset`. The root route is the
Owner portal. Public check-in, walk-in requests, PIN setup/recovery and claim
review default to unavailable until their server-side release gates are met.
The entrance QR contains only the HTTPS `/entrance` address.

## Verification

```powershell
npm.cmd run lint
npm.cmd run typecheck
npm.cmd test
npm.cmd run test:security
npm.cmd run build
npm.cmd run test:database
npm.cmd run test:browser
node scripts/test-browser.mjs --production
```

Database tests require installed PostgreSQL 18 Windows utilities and create a
fresh synthetic cluster under ignored `.cache/`. They never reuse an existing
cluster or hosted database, and stop the test server afterward. Browser smoke
tests require installed Chrome and use a fresh profile, loopback-only synthetic
configuration and mocked Auth/API responses. Neither suite certifies hosted
Supabase Auth, JWT validation, PostgREST, Edge limits or production RLS behavior.

The original [audit](docs/GYMFORCE-PROJECT-STATUS-AUDIT.md) is a historical baseline;
the progress tracker supersedes its implementation status.
See [release readiness](docs/RELEASE-READINESS.md) for the remaining Owner policy,
hosted-runtime, privacy and recovery acceptance gates.
