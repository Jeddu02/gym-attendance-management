# GYMFORCE production recovery: final local readiness assessment

## Latest local hardening, 2026-11-17

**Four local review findings R02-R05: PASS. Production remains NO-GO.**
The detailed current matrix, exact twenty-file implementation inventory, root
causes, corrections, commands/evidence and limitations are in
[PG17-COMPATIBILITY-FINAL-REVIEW.md](PG17-COMPATIBILITY-FINAL-REVIEW.md), current
section. This section supersedes prior local test results and the review's old
coverage/cache/provenance/cleanup findings. No production SQL/data/roles/config,
historical migrations, application source, root package/lock, commit or deployment.

| Finding | Correction / files | Evidence | Status / remaining limitation |
| --- | --- | --- | --- |
| Legacy refusal coverage | `scripts/test-database.ps1`: eleven actual P01/P07/P13/P14 refusals, explicit SQLSTATE/message, protected-row and catalog before/after fingerprints. | Both full PG17 profiles pass all eleven cases, nine races and security/rollback/ACL suites; negative audit profile also passes. | **PASS locally**; synthetic-only, P13 inherited fixture explicitly documented; actual legacy production state remains NOT VERIFIED. |
| Parser reproducibility | `tools/recovery-parser/` package/lock/README; `scripts/recovery/parser.cjs`; consumers and SQL Editor validator use exact pinned versions; new reproducibility/tooling tests. | Fresh allowlisted workspace with no root dependencies or old parser cache uses new empty npm cache; npm ci/SRI, all 16 tests, validators and 42 byte-identical artifacts pass. | **PASS**; public registry access and trusted lock required, no signature/local-tamper guarantee. Same existing parser libraries; no application dependency added. |
| Archive provenance | `scripts/setup-native-pg17.ps1`, new verifier and provenance regression script; mode/observed URL separated from publisher source. | ZIP matches publisher HTTPS SHA-256; malformed archive refuses before extraction/execution. | **PASS** publisher comparison; no detached signature claim; unavailable/mismatching checksum blocks setup. PG18 untouched. |
| Credential cleanup | `scripts/test-database.ps1`, new cleanup fault script: creation and init under try/finally, nested cleanup attempts. | Five real fault invocations pass before/during/after init and after startup; stopped servers/no temporary credentials, no literal password SQL in logs. | **PASS** controlled exceptions/native failures; abrupt OS/process death or denied filesystem operations remain outside guaranteed cleanup. |

Exact archive: PostgreSQL **17.12-1 Windows x64**, 386263884 bytes; matching
publisher/observed SHA-256
`a2cd8a774389347b70be7748ac4a37ef43cb6ee539c5fc3e85ae264b15e4a04c`.
Compared with the [publisher checksum](https://get.enterprisedb.com/postgresql/postgresql-17.12-1-windows-x64-binaries.zip.sha256),
not inferred from the local digest. Actual isolated servers report 17.12/170012.

Fresh private evidence:

- Customer `.cache/security-test-ff3be9a6addd4c4caa356f71e2c2af90`;
  audit-negative `.cache/security-test-f07b325e6c284fa59a0f1100f33fb04b`;
  unchanged control `.cache/security-test-8bdcde3ec4ba408c9f6a0c26a5afc250`.
- Fault evidence `.cache/cleanup-test-04438ac14f9c4e2a813373a6f10a5580.json`;
  clean room `.cache/parser-repro-lQWssL`;
  publisher `.cache/pg17-portable-17.12/publisher-verification.json`;
  browser `.cache/browser-test-b64d6475-68ca-47dc-a1d9-b35b8d1130b7`.

Full regression: lint/typecheck/security PASS, application Node 38/38, recovery
Node 16/16, Deno 105/105, all 21 Edge checks, completed production/PWA build and
synthetic browser regressions PASS. Servers stopped and temporary credentials
removed; no raw records or secrets exported. The active tree includes three
tracked tooling modifications and 91 untracked recovery paths; no staging/commit.
The SQL Editor validator changed only its parser loader, not approved SQL.

**A02 hosted authority remains NOT VERIFIED / REQUIRES OWNER APPROVAL.** Four
provider-controlled ADMIN edges remain by design; customer SET/INHERIT/CREATE
and policies are temporary and removed. Local success cannot establish actual
Supabase grantor/actor/default/schema/extension behavior. A03 hosted ACL/defaults,
A04 actual legacy data/three present markers, A07 real history/definitions and
approved artifact provenance/runner remain held. Owner approvals for diagnostics,
trust adoption, data resolution, backup/restore, maintenance and releases are
unchanged. Scripts 03-07 remain on hold. No production GO or execution approval.

The sections below retain the earlier detailed readiness assessment; use the
latest results above where local implementation evidence has advanced.

Updated 2026-11-17, Asia/Manila. Branch `review/production-recovery`, unchanged
HEAD `db700c1f42cdf561e3f55d61897ba8eb4948c94e`.
Intended production project: `alxhytivwybjbkjjdsyn`; not connected.

**Production: NO-GO. Local PG17 implementation and testing: completed as scoped
below.** This report supersedes its earlier unavailable-PG17/unimplemented-A02
assessment. Owner authorization covered local redesign and synthetic testing;
it did not approve hosted adoption of the revised trust boundary.

No production SQL, configuration/data/privilege changes, migration history writes,
commits, pushes, merges or deployments were performed. Historical migrations,
application behavior and production configuration are preserved. Earlier reports
remain historical evidence, not current runtime status.

## 1. Blocker status

| Scope | Status | Evidence / remaining gate |
| --- | --- | --- |
| Native isolated PG17 runtime | **RESOLVED locally** | Actual server 17.12 / 170012; portable workspace installation, no Docker, paid service, Windows service or PG18 change. |
| A02 unchanged zero-membership contract | **BLOCKED** | Original non-superuser refusal controls still reproduce the authority conflict. Successful superuser replay does not resolve it. |
| A02 redesigned customer authority | **RESOLVED locally** | Real SCRAM-authenticated, non-superuser, NOBYPASSRLS customer replay succeeds through all stages, cleanup, rollback and nine races. This is a revised contract, not unchanged-migration compatibility. |
| A02 production adoption / actual provider capabilities | **REQUIRES OWNER APPROVAL / NOT VERIFIED** | Approve exact ADMIN-edge exception, artifact identities and execution/provenance design; verify actual Supabase grantor, actor, extension/schema authority and hosted behavior. |
| A03 scoped existing RPC ACL and future defaults | **RESOLVED locally** | PG17 customer correction/replay, PUBLIC-leak repair, inherited-leak refusal/rollback, future-default denial and ten final effective-privilege screens pass. |
| A03 hosted defaults and RPC allowlist | **NOT VERIFIED / REQUIRES OWNER APPROVAL** | Actual creators/defaults/inheritance unknown. Global postgres future-default change affects all schemas and requires impact review. |
| A04 read-only diagnostics and dependency detection | **RESOLVED locally** | Actual catalog/history/authority/legacy queries exercised in isolation; dependency fixture detects old table dependencies and policy. No live objects identified or removed. |
| A04 real legacy/data blockers | **NOT VERIFIED** | Three present marker occurrences, legacy audit/lifecycle/payment/overlap/cash state remain unidentified or unverified. |
| A07 local source/hash/history/drift tools | **RESOLVED locally** | 37 original migration, 21 endpoint and 17 shared runtime hashes unchanged; PG17/18 grammar; history and catalog comparisons tested. |
| A07 hosted history, exact definitions and artifact bookkeeping | **NOT VERIFIED / REQUIRES OWNER APPROVAL** | Synthetic history is a model, not runner history. No skip, mark-applied, altered-file adoption or repair is authorized. |
| Hosted full-stack acceptance and deployment | **NOT VERIFIED** | Local fixtures do not certify hosted Auth/Edge/PostgREST/RLS or Cloudflare release. |

Supplied historical production evidence remains 20 recorded versions through
`20261030180000`, 17 unrecorded local versions, 91 marker occurrences (88 absent,
three present without history), ENABLE RLS on 22 inventoried tables and 14
previously missing endpoints. No fresh production observations were made.
Final source expects 33 protected tables. ENABLE flags do not certify FORCE RLS,
policies, owners, effective permissions or complete coverage.

## 2. Implemented A02 boundary

Start with [the compatibility README](../supabase/recovery/compatibility/README.md).
The generator is `scripts/recovery/build-compatibility.mjs`. Exact byte manifests
and separately generated SQL live under:

- `supabase/recovery/compatibility/review/manifest.json`: 19 SQL artifacts, expected
  provider `supabase_admin`; prepared and parsed, never executed against Supabase.
- `supabase/recovery/compatibility/synthetic/manifest.json`: 21 artifacts, synthetic
  provider `gf_provider_admin`; includes two synthetic-only diagnostic fixtures.

The 37 files in `supabase/migrations/` are unchanged. Thirteen P05-P17 variants,
one scoped ACL variant, three assertion variants and two diagnostic variants
are explicit review artifacts outside migration discovery. Each application
CREATE FUNCTION AST (signature, returns, configuration, language and body) matches
its original, ignoring parser positions and CRLF/LF normalization only. Seven
role-graph predicates are explicitly changed to the approved local design;
they are not silently disabled. Artifact/source SHA-256 checks run before replay.

At rest the four restricted roles remain NOLOGIN, NOSUPERUSER, NOBYPASSRLS,
NOINHERIT, NOCREATEROLE, NOCREATEDB and NOREPLICATION. The revised contract permits
exactly one provider-granted ADMIN edge per role to Owner-controlled postgres,
SET=false and INHERIT=false. Every other edge is refused. **ADMIN is powerful:**
it permits future grants and is a permanent administrative trust exception.
The Developer/member identity must never hold this administrator identity.

Inside each single transaction, postgres uses its ADMIN authority to grant itself
temporary SET/INHERIT, ADMIN=false, with grantor postgres. Destination schema
CREATE is temporarily granted only for required transfers: data owner in private
(also public in P05), API executors in api. Normal ownership/default-ACL checks
remain active. No provider SET ROLE, provider impersonation, generic privileged
DDL runner or new BYPASS privilege is introduced.

FORCE RLS remains active. Explicit uncommitted SELECT-only maintenance policies
allow full visibility for source legacy checks in the exact postgres session and
current role, on these tables only:

| Stage | Temporary SELECT tables in private |
| --- | --- |
| P06 | audit_events, audit_chain_heads |
| P07 | members, membership_purchases, payment_records, payment_allocations, payment_events |
| P13 | membership_purchases |
| P14 | cash_drawer_sessions |
| Others | None |

Restrictive-policy conflicts cause refusal. No write policy is added. Temporary
policies, customer-granted edges and destination CREATE are revoked before
COMMIT; final effective SET/inheritance/CREATE and policy-leak checks must pass.
The provider-owned digest grant is replaced by an existing effective EXECUTE
prerequisite check, never an unsupported grant. Missing authority stops execution.

Fresh local replay uses 24 unchanged originals through P04, then 13 variants.
Production's already recorded first 20 must never be replayed on that basis.
These variants are not truthful substitutes for original-file history entries.
An explicit Owner-reviewed runner/provenance/history strategy remains a mandatory
gate; no code here records them as applied. A migration appended after failing
P05 cannot repair its execution prerequisite. Never copy variants over originals,
skip assertions or use blanket db push.

Supabase documents that hosted postgres may have BYPASSRLS; the review profile
allows a pre-existing operator attribute but never grants or relies on it.
The synthetic profile rejects it, proving the local path without bypass.
Existing inherited authority, supautils, provider grants, actual CLI identity and
extension/schema grant options still require hosted evidence. The native fixture
is not a complete Supabase emulator.
[Supabase role grantor guidance](https://supabase.com/kb/troubleshooting/cant-revoke-a-role-membership-granted-by-supabase_admin-d08922),
[Supabase RLS guidance](https://supabase.com/docs/guides/database/postgres/row-level-security).

## 3. Exact native PG17 runtime

No existing PG17 archive was located in the searched workspace/download/document/
temporary locations. The authorized acquisition used the official EDB archive
link published through PostgreSQL's Windows distribution guidance:
`https://sbp.enterprisedb.com/getfile.jsp?fileid=1260667`.
`scripts/setup-native-pg17.ps1` extracted bin/lib/share only into ignored
`.cache/pg17-portable-17.12/pgsql/bin`, preserving PG18 and system PATH/services.
It refuses existing targets, redirected paths and unsafe ZIP entries.

| Verification | Result |
| --- | --- |
| Actual binary | postgres (PostgreSQL) 17.12 |
| Actual server | server_version 17.12; server_version_num 170012 |
| Archive bytes | 386263884 |
| Archive SHA-256 | `a2cd8a774389347b70be7748ac4a37ef43cb6ee539c5fc3e85ae264b15e4a04c` |
| postgres.exe SHA-256 | `70334b2428dac81d111b4e3a6cfed01568b216e4ef3c5cc879d423a0fe69c0df` |

Provenance is official HTTPS acquisition plus local fingerprints; an independently
published checksum/signature verification is not claimed. Private local provenance
is `.cache/pg17-portable-17.12/provenance.json`. Do not rerun setup over that target.
[PostgreSQL Windows distribution](https://www.postgresql.org/download/windows/),
[linked EDB binary archive list](https://www.enterprisedb.com/download-postgresql-binaries).

## 4. Verification evidence and limits

These results combine the completed implementation session on November 16 and
its resumed verification on November 17. Repeated runs are distinguished from
earlier baseline reports. Only synthetic objects/data and loopback services were
used; no test receipts or members were created in production.

| Check actually executed | Result | Scope / limit |
| --- | --- | --- |
| PG17 unchanged control: `scripts/test-recovery-pg17.ps1` | PASS | 37 originals, behavior suites, nine two-session races, original non-superuser refusal controls, ACL proposals and ten effective-privilege screens. Superuser engine control, not customer authority proof. |
| PG17 `-CustomerCompatibility` | PASS | Real separate SCRAM LOGIN postgres, NOSUPERUSER/NOBYPASSRLS/NOINHERIT/CREATEROLE; 24 originals + 13 variants; all phase tests and nine races. Provider arranges synthetic fixtures, not customer migration DDL. |
| Failure injection | PASS, expected refusals | Errors after first P05/P11 table transfer restore pre-file metadata; unexpected membership refuses; snapshots match after rollback/fixture cleanup. Not exhaustive arbitrary-statement/network-loss coverage. |
| `-CustomerCompatibility -TestLegacyAuditRefusal` | PASS, expected refusal | Incompatible historical chain refuses P06; original hashes and metadata preserved. Not a complete replay. |
| A03 actual customer ACL tests | PASS | PUBLIC leak repaired, proposal replay safe, inherited leak refuses/rolls back, future defaults deny unauthorized access, explicit service grants survive, ten final screens PASS. |
| Maintenance RLS proof | PASS | RLS active with required SELECT visibility; INSERT denied, UPDATE affects zero; policy/temporary grant cleanup verified. Native operator has no bypass. |
| A04 dependency fixture | PASS | Actual diagnostic detects synthetic obsolete table dependencies and one policy; fixture removed. Zero dependencies would not prove unused; dynamic/external callers remain outside catalog counts. |
| A07 history fixture | PASS | Actual READ ONLY query on temporary model history gives 20 known / 17 unrecorded, no duplicates/unknowns/gaps, HOLD. Model removed, no runner-history claim. |
| Catalog self-comparison | PASS | 906 exact metadata entries, zero missing/different/unexpected; keeps authority/data/history NOT VERIFIED and HOLD. Self-comparison validates tooling, not external equivalence. |
| Original control versus compatibility final | Expected difference, NOT equality | 901 exact, five different, none missing/unexpected: four redesigned role records and extension schema ownership in the provider fixture. No hidden normalization. |
| Baseline prerequisite planner | PASS, conservative | Registration/plan/cash and audit screens ready for review; lifecycle/payment and additional legacy screens UNKNOWN because prerequisite objects/columns are absent. No unsafe automatic execution. |
| `npm.cmd run lint`, `npm.cmd run typecheck` | PASS | Local static checks. |
| `npm.cmd test`, `npm.cmd run test:security` | PASS, 38/38 Node | Synthetic handler/security regressions, no hosted calls. |
| Three recovery Node test files | PASS, 14/14 | History/hash/drift/planner negatives, read-only ASTs and both compatibility manifests/full application function AST equivalence. |
| Cached Deno tests / all Edge checks | PASS, 105/105 and 21/21 | Includes actual entrypoint preflight/origin/config/Auth/gate coverage; cached local dependencies. |
| `npm.cmd run build` | PASS | Completed Vite/PWA generation in implementation session. |
| `node scripts/test-browser.mjs --production` | PASS | Synthetic mobile Owner/public QR/PIN, error/empty/retry/payment/walk-in and static-only PWA cache regressions; zero external application requests. |
| `node scripts/recovery/validate-source.mjs` | PASS | Original 37/21/17 byte hashes; PG17/18 grammar, 993 migration statements each. Parsing alone does not validate function runtime authority. |
| SQL Editor validator | PASS | All 16 original variants preserve exact SELECTs, ASTs/columns, wrappers and source hashes; no SQL executed. |
| `git diff --check` | PASS | Two tracked harness files have Git future LF-to-CRLF warnings; no historical SQL/runtime conversion. |
| Hosted SQL, real Auth/Edge/PostgREST, recovery drill, deployment | NOT RUN / NOT VERIFIED | Outside current authorization. |

Private ignored evidence (do not commit or export raw metadata/logs):

- Final customer rerun: `.cache/security-test-68bbf89f88cb4b4b921935c07d8fc1ce`.
  All stages, nine races, failure/rollback and ten privilege screens passed again
  on November 17; exit 0 and clean shutdown. Its retained authority JSON has four
  approved ADMIN edges, zero unexpected edges, zero maintenance policies and no
  effective CREATE/SET/inheritance paths at rest.
- Completed interrupted control: `.cache/security-test-a5d478f15b5c476e8af15c2ccb586d85`.
  Actual runtime JSON, final catalog, ten PASS screens and clean shutdown log
  were inspected on resumption; its original process handle had expired.
- Negative audit: `.cache/security-test-dab4bc95ab5a4eaa8420cc34c86dd244`.
- Browser: `.cache/browser-test-49bcbd67-89fa-49d0-a5bb-054d6d0b1ba4`.

Servers are stopped and synthetic credential files removed by harness cleanup.
The final control shutdown was confirmed in server.log. Preliminary generator
AST-location/line-ending comparisons and PowerShell fixture array handling needed
local corrections before the passing runs. They were harness issues; no original
migration or business routine was altered to force acceptance.

Resumption also found and corrected a harness evidence overwrite: the customer
authority result was subsequently replaced by the hosted-profile diagnostic run
as the bootstrap superuser. The customer assertions had already passed, but that
retained transcript described the wrong actor/provider. Customer mode now skips
that redundant incompatible-profile invocation, preserving its asserted JSON.
The complete customer suite was rerun after the correction; the old transcript
in `.cache/security-test-02f5df1a75be4f9d8b44c665acaf55c3` must not be used as the
final customer-authority evidence. No diagnostic SQL semantics were changed.

## 5. Exact read-only hosted handoff (prepared, not authorized to execute)

Review full SQL bytes in the files below before separate Owner authorization.
Keep existing preflight 03-07 on hold. No command below connects automatically.

1. `supabase/recovery/history.sql`: version-only JSON; missing history schema,
   table, column or privileges causes error. Compare offline with
   `node scripts/recovery/compare-history.mjs <private-history.json>`.
2. `supabase/recovery/diagnostics/compatibility-authority.sql`: single JSON result
   for exact actor flags, existing provider ADMIN edges, role attributes,
   schema grant authority, digest prerequisite and effective capability cleanup.
   Missing roles are explicit; absent roles are not a PASS. SQL Editor does not
   prove a different CLI session's authority. Strict `migration-authority.sql`
   retains its zero-edge meaning and may legitimately disagree with this design.
3. `supabase/recovery/catalog.sql`: private hashed catalog inventory; compare only
   with a trusted PG17 reference for the exact stage/profile/approved amendments:
   `node scripts/recovery/compare-catalog.mjs <reference.json> <observed.json>`.
4. `supabase/recovery/effective-privileges.sql`: original strict boundary screen.
   The separately reviewed compatibility variant permits only exact approved
   ADMIN edges; neither file authorizes correcting production grants.
5. `supabase/recovery/diagnostics/legacy-dependencies.sql`: incoming catalog
   dependencies/policy/trigger counts for superseded aggregate limiter table.
   Preserve the current rolling limiter RPC and wrapped original PIN issuer.
6. Remaining audit/lifecycle/registration/financial checks: use
   `node scripts/recovery/plan-checks.mjs <observed.json> <reviewed-stage>` first.
   Missing prerequisites mean UNKNOWN, never create columns merely to run a probe.

The target must be confirmed in the Owner's project dashboard/connection context;
catalog SQL does not prove the project reference. Run each separately through the
intended connection with its explicit READ ONLY transaction, 30s statement/2s
lock timeout and final ROLLBACK. On error stop and close/roll back that same
session. If SQL Editor hides results, use a separately approved Owner-operated
client that displays them; never split a transaction across sessions.

Keep full results private. Catalog/history diagnostics return no raw member,
payment, PIN, token or audit records/function bodies, but security metadata is
still sensitive. Other aggregate data-blocker checks require full visibility and
can scan real tables or wait behind DDL. Read-only is not zero load/locking risk.
Report only file/hash/time, actor/target confirmation, transaction closure,
sanitized check labels/status/counts and SQLSTATE category. No full exception,
function source, connection strings, ACL grids or private records in chat/Git.

## 6. Files and review boundaries

Tracked modifications are confined to `scripts/test-database.ps1` and
`scripts/test-db-concurrency.mjs`. New local recovery work includes:

- `scripts/setup-native-pg17.ps1`, `scripts/test-recovery-pg17.ps1`;
- `scripts/recovery/` validators, generator, comparators and prerequisite planner;
- `supabase/recovery/` manifests, diagnostics, two mutating REVIEW-ONLY ACL
  proposals, compatibility artifacts and README documentation;
- `supabase/tests/compatibility_security_behavior.sql`,
  `compatibility_legacy_diagnostics.sql` and the existing recovery test fixtures;
- `tests/recovery.test.mjs`, `recovery-sql.test.mjs`,
  `recovery-compatibility.test.mjs`, this report and earlier untracked A02 reports.

No changes to `supabase/migrations`, `src`, Edge runtime, package manifests or
lockfiles, Supabase/Cloudflare settings or environment templates. No secrets were
requested or exposed. Synthetic credentials/logs and native archive stay ignored.
No stage/commit operation was performed; uncommitted work awaits Owner review.

## 7. Mandatory Owner decisions and remaining acceptance

1. Approve specific read-only hosted diagnostics and intended actor/client;
   identify all three present marker occurrences and unmarked drift privately.
2. Approve or reject production adoption of the four exact provider ADMIN edges,
   temporary ownership capabilities and scoped SELECT maintenance policies.
   Local authorization does not approve this permanent trust-contract revision.
3. Verify actual Supabase PG17 customer role/grantor/schema/extension behavior in
   an approved isolated hosted-equivalent environment. No provider impersonation,
   elevated developer access or new hosted resource is authorized here.
4. Approve a truthful artifact execution/provenance/history mechanism. Test exact
   runner BEGIN/COMMIT, failed-stage cleanup, acknowledgement-loss reconciliation
   and concurrent operator behavior. Present rollback injections are not an
   exhaustive all-statements/provider-disconnect proof.
5. Review A03's exact RPC allowlist, real inherited access and every actual creator
   default. Proposal 02 changes postgres future routine defaults globally and can
   affect unrelated schemas/automation. Do not alter provider-owned defaults.
6. Resolve actual audit UTC, approval/lifecycle/date/payment-basis, uniqueness,
   exclusion, walk-in/attendance and legacy drawer blockers without guessing,
   deleting, rehashing, backdating or silently correcting financial history.
7. Verify backup/key custody, restore capability and isolated drill with agreed
   RPO/RTO; approve maintenance traffic controls, measured locks/duration, exact
   artifact hashes/operator/checkpoints and abort procedure. No blanket apply.
8. Separately approve hosted api-only settings, reviewed Edge bundles and Pages
   release only after database acceptance. Run real isolated Auth/JWT -> Edge ->
   PostgREST -> SQL success/negative/race tests and actual Owner production reads.
   Require actual Pages SHA/build success, not reachable HTML alone.
9. Keep public/PIN/claim gates closed until Owner-approved fee, token/KDF/abuse,
   runtime, privacy/retention/evidence and device acceptance requirements pass.

Finalized rules are preserved: Owner-only high-risk approvals, PHP/Manila/Option A
dates, confirmed payment before access, immutable 15-minute provisional walk-ins,
one valid member check-in per local day, financial/audit originals and corrections.
No refunds, free memberships, checkout, public member dashboard, silent approval
or restored invalid eligibility was added.

**Stop for Owner review. Production remains NO-GO. Local PASS does not authorize
production SQL, history changes, grants, migrations, deployments or commits.**
