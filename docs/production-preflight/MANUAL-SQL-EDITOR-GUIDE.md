# Manual SQL Editor guide — approved scripts 01 and 02 only

Prepared 2026-11-11, Asia/Manila. Project: `alxhytivwybjbkjjdsyn`.
This guide does not record an execution. Codex has not run production SQL.
The existing conditional authorization covers scripts 01 and 02 only.
Scripts 03–07, migrations, deployments and privilege/security changes remain on hold.

## 1. Confirm the project and execution context

1. Sign in to Supabase Dashboard using the Owner-controlled account.
2. Open the confirmed project. Check the **project reference**, not just its name:
   `alxhytivwybjbkjjdsyn`. The dashboard URL must contain
   `/project/alxhytivwybjbkjjdsyn/`. You can start at
   [this project's SQL Editor](https://supabase.com/dashboard/project/alxhytivwybjbkjjdsyn/sql/new).
3. Confirm the intended production project/branch and primary database are selected.
   Do not use a preview branch, replica or another project with a similar name.
4. Check the SQL Editor role/context selector. Use the expected Owner database
   context, normally the dashboard's `postgres` context, with no member/anon/
   authenticated role impersonation. Do not grant privileges or use SET ROLE to
   make checks succeed. A changed/unexpected role requires review before continuing.
5. Use a fresh query tab containing no older SQL. Avoid AI rewrites or automatic
   fixes. If available, disable result auto-limiting using the editor's No limit
   setting; do not add or remove LIMIT clauses in either file.

Supabase documents dashboard SQL execution through the database `postgres` role;
this is not proof of the actual role for a particular run or of migration authority.
[Dashboard execution context](https://supabase.com/kb/troubleshooting/tracking-postgres-role-activity-to-specific-dashboard-users-8d3715).

## 2. Verify the effective role before the full files

The following preliminary identity block uses the already-reviewed identity SELECT
and read-only settings from file 01. It is an excerpt for connection verification;
it does not edit either approved file or inspect additional application data.
Run it in its own new query tab, as one complete submission:

```sql
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '2s';
SET LOCAL search_path=pg_catalog;

SELECT current_user AS effective_role, session_user AS connection_role,
       current_setting('server_version_num') AS postgres_version_number,
       current_setting('transaction_read_only') AS read_only;

ROLLBACK;
```

Inspect the identity SELECT result privately:

- `effective_role` and `connection_role` must match the expected Owner-controlled
  SQL Editor context. Normally both are `postgres`; unexpected results are a stop.
- `read_only` must be `on` **in that SELECT's result**. An independent SELECT in a
  later request would inspect a different transaction and cannot replace this check.
- Record the PostgreSQL major version privately. The prepared scripts were parsed
  for PostgreSQL 17 and 18; another major version needs review before proceeding.
- The displayed role does not identify the Supabase project. Project confirmation
  comes from the verified dashboard target; both checks are needed.

**Result-display gate:** SQL Editor versions can differ in how multi-statement
results are exposed. If it displays only the final ROLLBACK status, or “Success,
no rows returned,” and the identity SELECT result is inaccessible, stop. Mark
identity verification UNKNOWN. Do not remove ROLLBACK, run the SELECT alone, or
assume separate Run clicks use the same database session. Request a separately
reviewed editor-compatible execution format or use an Owner-controlled client
that preserves transaction boundaries and captures every result set.

## 3. Preserve the approved files

The files are:

1. [01-catalog.sql](01-catalog.sql)
2. [02-unrecorded-object-markers.sql](02-unrecorded-object-markers.sql)

Use the files in the repository, not a manually retyped copy. Do not change
settings, comments, SELECTs, transaction boundaries or the final ROLLBACK.

Optional local integrity check from the repository root (does not connect to Supabase):

```powershell
Get-FileHash docs/production-preflight/01-catalog.sql,docs/production-preflight/02-unrecorded-object-markers.sql -Algorithm SHA256
```

Expected hashes, ignoring letter case:

```text
01-catalog.sql
ebbfcc096f28fc15cbd352010887eb07d095b7af6f82cb27b9b98d2fcccd1106

02-unrecorded-object-markers.sql
9b187d2c9adf3590f6da7353940972d88502fd44e07584810a0d2d714b0a0277
```

If the hashes differ, stop and compare the local files before any execution.

## 4. Execute 01-catalog.sql by itself

1. Create a fresh SQL Editor tab named `GYMFORCE preflight 01 — read only`.
2. Recheck the project reference, production/primary selection and expected role.
3. Open file 01 in VS Code, select all and copy. Paste the entire file into the
   empty SQL Editor tab, including BEGIN, every SET LOCAL and the final ROLLBACK.
4. Check that no unrelated SQL or AI-generated additions are present. Clear any
   text selection so Run does not execute only the selected fragment.
5. Use the editor's Run action to submit the complete file once. The official
   dashboard workflow is New Query → enter SQL → Run.
   [Supabase SQL Editor workflow](https://supabase.com/docs/guides/database/functions).
6. Wait for completion. Do not run script 02 concurrently or repeatedly click Run.
   The file retains a 30-second per-statement timeout and 2-second lock timeout.
7. Inspect all available result sets and the completion/error status privately.
   Confirm the identity result still matches the preliminary check and reports
   `read_only = on`.
8. Require evidence that the complete submission reached its final ROLLBACK and
   that all diagnostic outputs are available before advancing. A generic success
   banner does not prove that earlier result sets were captured or validated.

Expected file-01 result groups (15 SELECTs):

| Group | What to inspect privately |
| --- | --- |
| 1 | Effective/connection roles, PostgreSQL version and read-only state. |
| 2 | Applied migration versions; compare with the 20 versions already supplied. |
| 3 | Presence/ownership of `api`, `private`, `extensions`. |
| 4 | Exact routine signatures, types, owners and execution metadata. |
| 5 | Explicit/default routine execution ACLs. |
| 6 | Effective execution permissions for the fixed application roles. |
| 7 | Schema USAGE/CREATE permissions. |
| 8 | Global/schema default object privileges. |
| 9 | Table ownership, RLS enabled/forced and current-role filtering flags. |
| 10 | Effective direct table/column privileges for anon/authenticated/service roles. |
| 11 | Policy names, commands, roles and expression-presence flags; no expressions. |
| 12 | Private table column names/types/nullability; no values. |
| 13 | Application trigger names/status/routine identities. |
| 14 | Constraint names/types/validation flags. |
| 15 | Index names/validity/readiness/uniqueness flags. |

Some metadata groups can legitimately have zero rows. That differs from an error,
a hidden result set or truncated output. Do not declare a whole-file PASS merely
because some groups returned data. RLS flags alone do not prove policy correctness;
absence of FORCE RLS on the older pre-hardening baseline must be reviewed against
that baseline, not automatically classified using the future release target.

If you cannot retrieve all 15 outputs, record file 01 as UNKNOWN/incomplete and
stop before 02. Do not strip the wrapper, split the file or append a different
summary query under the current exact-content authorization.

## 5. Execute 02-unrecorded-object-markers.sql only after 01 succeeds

1. Confirm file 01 completed without unexpected errors, its transaction is closed,
   its identity matches the intended context, and its outputs are available.
2. Create a separate new query tab named `GYMFORCE preflight 02 — read only`.
3. Recheck the same project/production database/role context.
4. Copy and paste the entire unchanged file 02 from VS Code. Retain every setting
   and the final ROLLBACK. Clear any text selection and submit the whole file once.
5. Retain the 30-second per-statement and 2-second lock timeouts. Wait for completion.
6. Inspect the single diagnostic result set and completion status privately.
   It should contain 91 marker rows, unless a client truncates/hides results.
   Confirm complete output rather than interpreting a UI display limit as the
   database result. Do not modify the script to change pagination or limits.
7. Confirm the submission reached ROLLBACK. If the SELECT result is inaccessible
   because the final command's status is all the editor exposes, record UNKNOWN
   and stop; do not treat “no rows returned” as 91 absent objects.

Interpret each row using its actual `observation` value:

- `ABSENT_WITHOUT_HISTORY`: this declaration marker is missing and its migration
  version is not recorded. This supports a pending prerequisite finding.
- `PRESENT_WITHOUT_HISTORY: older definition or manual drift possible`: an object
  with that name exists without the corresponding history entry. An older routine
  or overload can satisfy this name-only check. This is a review candidate, not
  proof of manual application, corruption or complete migration execution.
- `RECORDED: definition still needs verification`: history now records the version;
  the actual definition still needs comparison. If history differs from the supplied
  20-version baseline, report the change for review rather than explaining it away.

Marker rows are not unique object counts: the same routine can appear in several
migrations. Do not mark migrations applied, repair history, create missing objects
or rerun original migrations based on these presence results.

## 6. Handle errors and transaction cleanup

On an error, cancellation, browser/network failure, target mismatch, unexpected
warning, timeout or unexplained output:

1. Stop. Do not run 02 after an unexpected issue in 01, and do not automatically retry.
2. Record the filename, execution time in Asia/Manila and sanitized error category.
   Mark the execution/check UNKNOWN; an execution error is not proof that an
   inspected security requirement itself has failed.
3. Keep detailed errors private. Examples of safe categories are permission denied,
   missing relation/schema/column, statement timeout, lock timeout, output unavailable,
   wrong context and connection failure. SQLSTATE can be shared without its raw
   DETAIL/HINT/CONTEXT or query output.
4. If your client confirms you still control the **same database session**, use
   only `ROLLBACK;` to close an aborted/open transaction. This is cleanup, not a
   schema/data repair. Do not use COMMIT or rerun the script to clear an error.
5. Do not assume a separate SQL Editor Run request uses that same session. A
   ROLLBACK in another session cannot close the original transaction. Browser-tab
   closure is not proof of database-session closure either.
6. If session closure cannot be confirmed, mark cleanup UNKNOWN and stop. Have
   the Owner use the provider's connection/support controls to confirm the
   request/session has ended before further execution. Do not kill unrelated
   sessions or run unreviewed backend-termination SQL.

Do not extend timeouts, bypass permissions, disable RLS, switch to another project,
change memberships or accept generated repairs. All later checks remain on hold.

## 7. Return a sanitized summary

Do not paste raw result grids, full CSV exports, screenshots of credentials or
connection strings, custom owner-role identities, policy details or function code.
Keep security metadata in Owner-controlled private storage if it must be retained,
outside this repository and shared chat. These files return no member/payment rows,
but their architecture and permission metadata is still private.

Share a short summary using this template. Replace UNKNOWN only with observed
results; do not fill in expected outcomes as though they were measured:

```text
Project: alxhytivwybjbkjjdsyn
Executed at (Asia/Manila):

Project/production-primary context confirmed: PASS / FAIL / UNKNOWN
Expected Owner SQL role confirmed privately: PASS / FAIL / UNKNOWN
Identity SELECT read_only = on: PASS / FAIL / UNKNOWN
SQL file integrity checked: PASS / FAIL / UNKNOWN

01-catalog.sql:
  Execution and all 15 result sets available: PASS / FAIL / UNKNOWN
  Transaction closed: PASS / FAIL / UNKNOWN
  Applied migration count:
  Matches previously supplied 20-version history: PASS / FAIL / UNKNOWN
  api schema present: YES / NO / UNKNOWN
  private schema present: YES / NO / UNKNOWN
  extensions schema present: YES / NO / UNKNOWN
  Protected-table RLS enabled throughout: YES / NO / UNKNOWN
  Unexpected direct anon/authenticated/service table or column privileges: YES / NO / UNKNOWN
  Unexpected routine signatures/ownership/grants requiring review: YES / NO / UNKNOWN
  Unavailable/truncated metadata groups (group numbers only):

02-unrecorded-object-markers.sql:
  Execution and complete result set available: PASS / FAIL / UNKNOWN
  Transaction closed: PASS / FAIL / UNKNOWN
  Marker rows observed:
  ABSENT_WITHOUT_HISTORY marker count:
  PRESENT_WITHOUT_HISTORY marker count:
  RECORDED marker count:
  Counts sum to 91: PASS / FAIL / UNKNOWN
  Relevant known application object names + classifications, if needed:
    api.<reviewed routine name> — ABSENT_WITHOUT_HISTORY / PRESENT_WITHOUT_HISTORY / RECORDED

Unexpected error: NONE / sanitized category
SQLSTATE, if present:
Stopped before further work: YES / NO
Scripts 03–07, migrations, deployments and security changes remain on hold: YES
```

Known application routine/table names already present in the reviewed SQL may be
used to identify a prerequisite. Omit custom identifiers that contain private
information. Presence results do not establish definition equivalence or runtime
authorization; full catalog correctness and hosted migration compatibility remain
UNKNOWN until separately reviewed and approved checks establish them.

After the summary, wait for interpretation and your next explicit approval.
No source SQL changes, migrations, deployments or scripts 03–07 are authorized by
this manual execution guide.
