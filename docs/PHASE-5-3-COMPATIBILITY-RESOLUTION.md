# Phase 5.3 — compatibility resolution

2026-11-17. Reviewed master baseline `ad41b7988d0d9fc4a56e675aeaff9b613878cdda`.
**Local regressions PASS; hosted blocker resolution incomplete. Production NO-GO.**

| Finding | Classification | Fresh evidence and remaining requirement |
| --- | --- | --- |
| A02 original zero-membership customer migrations | BLOCKED | Unchanged P05/P11 non-superuser refusal controls pass; ordinary customer replay cannot satisfy the original authority contract. No assertion removed. |
| A02 explicit compatibility architecture | RESOLVED LOCALLY / HOSTED UNVERIFIED | Actual PG17.12 non-superuser customer replay, two partial-ownership rollback probes, security/cleanup assertions and nine races pass. Actual Supabase authority and Owner trust adoption unverified. |
| A03 explicit RPC ACLs / defaults / inherited leaks | RESOLVED LOCALLY / HOSTED UNVERIFIED | Customer ACL correction/replay, future-default denial, inherited-leak refusal/rollback and ten final privilege screens pass. Actual hosted creator/defaults/graph/definers unknown. |
| A04 legacy refusal and diagnostic tooling | RESOLVED LOCALLY / HOSTED UNVERIFIED | Eleven actual migration refusal fixtures, unchanged protected-row/catalog hashes, audit incompatibility refusal and existing diagnostic suites pass. Real finance, approval, overlap, attendance, cash and stored chains unverified. |
| A07 source/history/drift verification | RESOLVED LOCALLY / HOSTED UNVERIFIED | 75 exact reviewed source checks, 37 migrations/993 statements parsed under PG17/18, history gap/duplicate/unknown and catalog-drift tests pass. Three historical present occurrences and actual runner/history remain unknown. |
| A05 malformed successful list responses | RESOLVED LOCALLY / HOSTED UNVERIFIED | Actual three handler sources reject object/null/scalars safely; populated and empty arrays remain valid. Browser fixture covers unavailable versus empty recovery. No reimplementation. |
| A06 preflight/CORS | RESOLVED LOCALLY / HOSTED UNVERIFIED | Actual all-21 entrypoint test passes trusted OPTIONS, rejected origins, missing configuration, Auth and feature-gate cases. No POST permission inferred from OPTIONS. |

## Implemented local improvement

`scripts/recovery/validate-hosted-package.mjs` closes the repeatability gap between
the existing 16-file SQL Editor validator and the complete 30-candidate hosted
package. It verifies exact existing hashes, matching form scopes, ordered identity,
conditional flags, transaction settings, allowed ASTs and reviewed builtin calls.
`tests/hosted-package.test.mjs` checks the real package plus tampered hashes,
duplicate IDs, scope/hash disagreement, unsafe SELECT functions, nested DML,
SELECT INTO, row locks, mutation DO, COMMIT and timeout/read-write changes.
Four new tests pass under PG17/18 grammars. No SQL text/hash/approval changed.

No new production discrepancy is asserted from absent evidence. Existing A08
lost-response recovery for public creation needs a reviewed idempotency/recovery
contract before enabling public use; it is not repaired by blindly retrying.
A09 dependency resolution, A10 hosted Auth-key availability and A11 invalid-token
UI breadth retain their prior bounded findings; valid generated PIN-token paths
are covered locally. No hosted configuration is assumed present or missing.

## Authority boundary retained

The compatibility builder's reviewed/synthetic artifacts preserve application
function ASTs and original 37 migration fingerprints. The local customer model
permits exactly four provider-granted reserved-role ADMIN edges, with SET and
INHERIT false. Review profile grantor is `supabase_admin`; synthetic profile uses
`gf_provider_admin`. These are a deliberate trust-contract exception, **not**
literal zero memberships and not a customer-revocable temporary permission.

Temporary customer-granted SET/INHERIT edges, destination schema CREATE and
stage-specific SELECT maintenance policies are transactional and must disappear
before commit. FORCE RLS, NOLOGIN/NOBYPASSRLS executors, explicit RPC ACLs and
financial/audit rules remain enforced. Local success proves the synthetic actor
model only. Owner/provider confirmation must establish actual edge grantor/options,
supported self-grant/revoke, schema/extension authority, unchanged actor path,
provider hooks and failure cleanup; read-only catalogs alone cannot prove DDL.
No support request was sent and no provider permission was changed.

## Safe future sequence and recovery gates

1. Complete exact diagnostic authorization and no-SQL pre-flight. Obtain fresh
   private stage/history/marker/ACL results; classify absent, exact, older,
   incompatible and unknown effects without marking migrations applied.
2. Resolve provider authority and Owner adoption of the ADMIN trust exception;
   demonstrate supported operations in a separately approved hosted-equivalent
   isolated target. No resources were provisioned here.
3. Resolve real legacy blockers with preserved originals. Any pre-P14 cash
   session, even closed, blocks the current source. No deleting, rehashing,
   guessed payment basis/approval dates or backfilling history to pass guards.
4. Approve truthful compatibility artifact provenance and runner/history behavior,
   backups, isolated restore, RPO/RTO, keys, traffic exclusion, lock budgets and
   abort plan. Variants are not unchanged original migrations under another label.
5. Only under new migration authorization, consider originals P01–P04 then the
   reviewed P05–P17 compatibility sequence, with the recovery plan's checkpoints.
   Do not replay the 20 recorded files, blanket db push, rewrite historical SQL
   or manually mark versions applied. Keep traffic closed across intermediate stages.
6. After separately approved database acceptance, authorize any hosted settings,
   all affected Edge bundles and Pages release separately. Public/PIN/claim gates
   remain closed until their own acceptance and parameter approvals.

On refusal/lost acknowledgement: stop, close the actual transaction, privately
verify committed objects/history and lock cleanup; do not blindly rerun. After a
committed stage, prefer separately reviewed forward recovery. No generic safe
down-migration is established. Restore requires its own Owner decision and an
actual tested recovery point, including post-backup operation-loss assessment.

Exact commands and fresh evidence are in
[the integration report](PHASE-5-4-INTEGRATION-TEST-REPORT.md). Original detailed
dependencies remain in `docs/production-recovery-plan.md` sections 2, 6 and 12–13;
revised authority mechanics are in `supabase/recovery/compatibility/README.md`.
