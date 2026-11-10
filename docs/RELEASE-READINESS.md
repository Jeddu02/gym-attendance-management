# Local release readiness — 2026-11-10

**Not authorized for production release.** Local implementation and synthetic
verification do not establish hosted Supabase compatibility or production
security acceptance. The [progress tracker](GYMFORCE-DEVELOPMENT-PROGRESS.md)
contains the current test counts and remaining work.

Local reports now include confirmed income by Manila confirmation date/source/
method, loaded-page membership CSVs and on-screen expiry reminders. A consecutive
fully paid renewal suppresses its reminder; its void restores reminder visibility.
CSV exports can be opened in Excel; no native `.xlsx` exporter is included.

## Reviewed trust boundary

Owner approved the restricted RPC boundary on November 10. Local Data API schema
configuration already included `api`; approval confirmed that architecture.
`api` contains routines only. Private tables remain unexposed and FORCE RLS is
enabled. `anon` and `authenticated` cannot execute application RPCs or access
application tables. `service_role` has bounded RPC execution but no direct
application table/column grants. It is never a browser credential.

Owner Edge handlers verify the incoming Auth token using `getUser` and derive
the SQL actor from that verified user. SQL independently checks active Owner
access. Public handlers use narrow server operations rather than member Auth
accounts. Registration and anonymous Auth signup are disabled. A public entrance
QR contains only `/entrance`; PIN setup/reset capabilities are separate one-use
links, held in memory and removed from the address fragment before rendering.

Hosted schema exposure, function grants, JWT handling and role assumptions must
be tested through actual PostgREST/Edge/Auth before enabling access. Native SQL
tests use an Auth shim and PostgreSQL 18.6. Local configuration targets PostgreSQL
17; Docker Engine was unavailable. Neither native SQL nor browser Auth fixtures
prove hosted request authorization.

## Runtime release switches

These server-side switches default to unavailable. Do not enable them merely
because a build or unit test passes:

| Switch | Required acceptance |
| --- | --- |
| `PIN_SETUP_ENABLED` | Owner-supervised identity workflow; approved token lifetime; PIN KDF/abuse testing. |
| `PIN_RECOVERY_ENABLED` | Same identity, one-use/versioning, recovery abuse and token-lifetime review. |
| `PUBLIC_MEMBER_CHECKIN_ENABLED` | Hosted CPU/memory/latency tests, shared-network and denial-of-service tests, approved global/identifier limits, independent dummy verifier and trusted gateway checks. |
| `PUBLIC_WALKIN_ENABLED` | Explicit tested request limiter, configured fee, approved 15-minute expiry behavior, Owner payment workflow. |
| `OWNER_OFFLINE_REVIEW_ENABLED` | Privacy/retention acceptance and operational review procedure. This enables server review, not a persistent device queue. |

Server-only configuration also includes `APP_ORIGIN`, Supabase service credentials,
member mobile encryption/HMAC keys, public lookup HMAC key and dummy PIN verifier.
The Owner controls their custody. Never place them in browser `VITE_*` variables,
source, diagnostic output, screenshots or shared test fixtures. Public browser
configuration consists only of the project URL and publishable key.

Development six-digit PIN/Argon2id settings and the SQL development token lifetime
are preparation values, not approved production settings. Actual Edge capacity
must be measured; do not infer safe concurrency from a successful laptop test.

## Financial and attendance acceptance

Owner must exercise these cases with synthetic data on an authorized isolated
hosted development environment before a release decision:

1. Approval without payment grants no access. Full confirmed payment without
   dated finalization remains pending activation. Delayed confirmation cannot
   backdate activation. Verify month ends, leap dates, inclusive expiry and early
   renewal across Manila midnight.
2. A wrong PIN, unknown identifier and ineligible member have generic failures.
   A PIN reset invalidates a verification already in flight. Duplicate accepted
   check-in does not create a second row or rewrite original audit history.
3. Walk-in request ID, fee/version, method, amount and 15-minute expiry are
   server-controlled. Expired requests never revive. Actual mismatched receipts
   survive in review without attendance or confirmed income.
4. Explicit allocation uses one verified whole receipt exactly once. Price/method
   mismatch cannot grant access. Membership allocation still needs paid-term
   finalization; walk-in allocation requires current physical presence and a new
   unexpired request. Original receipt target/facts remain unchanged.
5. Voids preserve original payment/attendance/audit events, invalidate the exact
   supporting eligibility and exclude invalidated attendance/income from valid
   totals. Re-recording cannot duplicate still-verified money. Independent
   eligibility restoration remains a separate unresolved review workflow.
6. Drawer close counts verified cash including unallocated receipts, excludes
   electronic payments and stores immutable receipt IDs/amounts. Count variance
   requires reason/evidence and never changes income automatically. A late close
   remains blocked pending an approved stale-drawer procedure.
7. Claims stay provisional until server validation. Device dates never prove
   historical attendance. Older/conflicting claims stay in review or receive a
   reasoned resolution without attendance. No automatic expiry/deletion or
   24-hour approval rule exists. Persistent offline storage is not implemented
   pending retention/privacy decisions.

## Owner-controlled hosting and recovery

Prepare a reviewed release artifact with `npm.cmd run build`; static output is
`dist/`. A free provider subdomain is sufficient. The repository includes static
response headers for a compatible host. Verify HTTPS, SPA fallback for entrance
and PIN routes, no-store API/PIN responses, actual security headers, stable QR
destination and cache behavior on the selected host. Scan the printed QR with a
real phone before distributing it.

Use the provider's current documentation rather than assuming free-tier
availability or guarantees: [Supabase Edge limits](https://supabase.com/docs/guides/functions/limits),
[hosted database role limitations](https://supabase.com/docs/guides/database/postgres/roles-superuser),
[backup capabilities](https://supabase.com/docs/guides/platform/backups),
[free-project pausing](https://supabase.com/docs/guides/platform/free-project-pausing),
[Cloudflare Pages build configuration](https://developers.cloudflare.com/pages/configuration/build-configuration/)
and [Pages limits](https://developers.cloudflare.com/pages/platform/limits/).
No provider resource, domain, production environment or hosted schema was changed.

Before production data, the Owner must approve privacy/retention, recovery
objectives and backup cadence, secure key custody and perform an actual isolated
restore drill including verification of audit chains and encrypted mobile data.
Preserve the existing ledger/audit history. Incompatible legacy UTC audit hashes
or historical state cause migration refusal; obtain evidence review rather than
rewriting hashes or bypassing checks.

Real-device PWA install/update/offline-denial behavior, independent security
review where practical, and hosted synthetic acceptance remain open. Request
separate deployment authorization only after these gates have reviewable evidence.
The Developer uses source and synthetic data; no routine production membership,
financial data or privileged credential access is granted.
