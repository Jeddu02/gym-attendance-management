# PG17 Windows startup recovery and commit verification

Prepared 2026-11-17, Asia/Manila. Review branch `review/production-recovery`;
input HEAD `db700c1f42cdf561e3f55d61897ba8eb4948c94e`.
**Local execution recovery only. Production remains NO-GO.**

## Root cause and smallest correction

The blocked run completed initdb but failed before starting the PostgreSQL
server. Its pg_ctl stderr reported restricted-token creation error 87, followed
by startup error 3. No migration or schema assertion ran in that attempt.
The failed run directory had no server.log, consistent with failure before
server execution. Its initialized data directory granted full control to the
actual sandbox user, SYSTEM and Administrators; no ACL changes were made.

Environment inspection established Windows 11 Home Single Language, build
10.0.22631, 64-bit. Both postgres.exe and pg_ctl.exe report 17.12, and their PE
machine field is 0x8664 (AMD64). The sandbox executes under a separate restricted
local account. Its WMI operating-system query was denied. The approved execution
context outside the sandbox uses the existing interactive account at medium
integrity, with Administrators membership deny-only; this is not a newly created
account or an assertion that the test ran with an enabled Administrator token.

The exact error originates in PostgreSQL's CreateRestrictedToken failure branch,
before CreateProcessAsUser: see [PG17.12 restricted_token.c](https://github.com/postgres/postgres/blob/REL_17_12/src/common/restricted_token.c#L73).
The same binaries, launcher and repository succeeded outside the sandbox.
Together these observations identify a sandbox-specific Windows process/token
launch incompatibility, rather than a SQL migration, PG17 version, architecture
or data-directory permission defect. The precise Windows internal reason for
rejecting that token is not independently established by these observations.
The secondary startup code is not evidence of a missing migration/file path.

**Correction:** execute the unchanged synthetic launcher through the approved
non-sandbox tool execution context. PostgreSQL's own restricted-token creation
remains active. No PG_RESTRICT_EXEC override, Windows protection change, direct
postgres startup bypass, privilege relaxation, service installation, PG18
substitution, historical migration edit or application change was introduced.
Outside-sandbox permission is scoped to the named local checks; do not treat it
as permission for arbitrary commands or production access.

Reproduction commands (PowerShell, existing local runtime only):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-recovery-pg17.ps1 -CustomerCompatibility
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-recovery-pg17.ps1 -CustomerCompatibility -TestLegacyAuditRefusal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-recovery-pg17.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-recovery-cleanup.ps1
```

ExecutionPolicy Bypass applies to the child PowerShell invocation, as in the
existing harness; no persistent execution-policy setting is changed. Each run
creates a new ignored, ACL-restricted loopback-only cluster with random
credentials and checks its identity. Do not reuse a production connection or
the failed sandbox account's data directory. In an ordinary manual workflow use
an Owner-controlled normal terminal, not a sandbox-token workaround. If that
context still refuses startup, leave the check BLOCKED and diagnose separately.

## Fresh verification evidence

| Check | Result / boundary |
| --- | --- |
| PG17 customer compatibility | PASS: actual server 17.12 / 170012; complete replay, two partial-ownership rollback probes, eleven actual legacy refusals with 11/11 identical protected-row snapshots, all nine concurrency scenarios, RLS/permission/ACL/default/inherited denial tests and ten final privilege screens. |
| Customer at-rest authority | PASS locally: four expected synthetic provider ADMIN edges; zero unexpected edges, maintenance policies, effective schema CREATE or operator SET/inheritance paths. Not actual Supabase evidence. |
| Audit-refusal profile | PASS: incompatible synthetic stored audit history refused; rollback and audit integrity assertions passed; server stopped. |
| Unchanged engine control | PASS: all 37 original migrations, original non-superuser authority refusal controls, eleven legacy refusals, all nine races, rollback/ACL/default/security suites and ten privilege screens; server stopped. |
| Five cleanup faults | PASS: AfterCredential, BeforeInitdb, native InitdbFailure, AfterInitdb and AfterStart; expected errors, no temporary credentials and no active server markers. |
| Lint, TypeScript, application Node/security | PASS: fresh lint/typecheck, 38/38 Node tests and source security checks. |
| Recovery Node and source/SQL validators | PASS: 16/16; both grammars, exact 37 migration/21 entrypoint/17 shared-runtime hashes and all 16 approved SQL Editor variants. |
| Deno/Edge | PASS: 105/105 cached synthetic tests, checks on all 21 entrypoints. Sandbox could not execute the WinGet Deno binary; the existing real binary succeeded in the approved non-sandbox context. No download or deployment. |
| Production/PWA build and synthetic browser | PASS: npm.cmd run build completed including generateSW; node scripts/test-browser.mjs --production passed mobile/navigation, list error/empty recovery, payment/walk-in/PIN/QR and static-only cache checks. No external application requests; not real hosted E2E. |

Fresh private ignored evidence: customer
`.cache/security-test-0986764ee5224516b390bea45a7decc5`; audit refusal
`.cache/security-test-08fe5a9ec7ba47b696dc5aa598663241`.
Unchanged control: `.cache/security-test-b53456f7e30d41d0820b9e020941cf30`;
fault evidence: `.cache/cleanup-test-582aede287c94553b3dc7cc302494ad5.json`;
browser: `.cache/browser-test-f9e46470-69f3-4458-a473-1a3128eaf4ac`.
The previous failed launch is retained under
`.cache/security-test-d7fecef1603c405f936114fd3fca0585`.
Customer and failed-run cleanup checks found no bootstrap-password, pgpass.conf,
recovery-actor-bootstrap.sql or data/postmaster.pid. These path references are
not exports of private runtime logs or synthetic records.

## Commit boundary and remaining gates

The preceding review inventory contains 99 project files: three modified
tooling files and 96 untracked recovery source/test/documentation files. Their
bytes remained identical when rechecked during this task. This new verification
document is the only additional project file, bringing the intended commit to
100 paths. Ignored clusters, archives, dependency caches, environment files,
temporary credentials and test output must remain excluded. Stage exact reviewed
paths only and verify staged content against the byte inventory before commit.
Fresh inspection read all 100 text files and found no credential-pattern
matches or binary/runtime exports. Ignore checks cover runtime/archive/cache,
parser node_modules, local environment and dist output. A pattern scan is a
bounded safety check, not a universal guarantee against arbitrary embedded data.

The final Git synchronization result is reported separately after the requested
commit/push; this document does not predeclare either successful. Historical
migrations, application source, Supabase/Pages settings, root package/lock and
ignore rules are unchanged. No hosted SQL, live records, roles or migration
history were accessed or changed. No release or deployment is authorized here.

Local PG17 success resolves the local startup blocker only. A02 actual provider
ADMIN/actor/schema/extension compatibility and adoption, A03 hosted permissions,
A04 real legacy state, A07 hosted reconciliation and truthful runner/history,
backup/restore and full hosted business acceptance remain open. Owner diagnostic
forms remain drafts, with no boxes checked or signature supplied by this task.

## Additional staged formatting check

The first staged diff check, which also examines newly added files, found
whitespace-only lines in generated SQL that the earlier unstaged diff did not
inspect. Commit was withheld. Four conditional interpolations in
`scripts/recovery/build-compatibility.mjs` were adjusted so an empty template
branch emits no indentation. Nonempty output retains its original indentation.
Both artifact sets/manifests were regenerated; 29 SQL files differ only by
removing whitespace from otherwise empty lines. All 40 SQL outputs were compared
against the pre-correction text after removing line-end whitespace, with exact
equality; the generator also verifies unchanged original application-function
ASTs. Historical migrations are untouched.

`tests/recovery-compatibility.test.mjs` now checks every generated SQL artifact
for trailing whitespace. All 16 recovery tests pass after this correction. The
full customer replay and clean-room generation checks passed again against the
updated artifact hashes before commit. Final replay evidence is
`.cache/security-test-a3991673cc79430ab4f5c2903b088e36`; clean-room evidence is
`.cache/parser-repro-OjURAq`. The customer server stopped after all assertions.
Fresh lint and both grammar/source/SQL Editor validators also passed again.
Thus the original 99 paths remain the
same reviewed file set, but the builder, regression, 29 generated SQL files and
two manifests have this explicitly reviewed formatting change; the earlier
99-byte-identity statement describes the check before this correction.
