# SQL Editor verification review — 2026-11-16

Status: prepared for Owner review; no SQL in this package has been executed.
Target project: `alxhytivwybjbkjjdsyn`. Execution requires Owner approval of
these new files. The earlier approval of the two original files does not
automatically approve these differently packaged files.

## Contents and preserved checks

Files `01-01` through `01-15` each contain exactly one original top-level SELECT,
in source order, from `../01-catalog.sql`. File
`02-01-unrecorded-object-markers.sql` contains the original WITH/SELECT from
`../02-unrecorded-object-markers.sql`. Every file has its own explicit
`REPEATABLE READ READ ONLY` transaction, 30-second statement timeout, 2-second
lock timeout, local `pg_catalog` search path and final `ROLLBACK`.

The SELECT text, aliases, sort order, filters, anonymization, NULL behavior and
visibility restrictions are preserved. `manifest.json` records original and
variant SHA-256 hashes, SELECT hashes, source ordinals and exact output columns.
The original approved files are unchanged. No script 03–07 is included here.

**Changed observation semantics requiring review:** the 15 catalog results now
come from separate transaction snapshots. A schema/deployment change between
runs can make their results inconsistent. Each transaction remains repeatable
read, but the whole package no longer shares the original single snapshot.
Use a quiet period, record run times and stop if the role or project changes.
This package does not certify migration authority, runtime authorization,
hosted exposed schemas, function definitions or business behavior.

## Owner execution procedure, after approval

1. Open the intended project in the Supabase dashboard. Confirm the project
   reference in the project settings and dashboard address is exactly
   `alxhytivwybjbkjjdsyn`. Confirm the production primary database is selected;
   do not use a preview branch, replica or another project. Project names alone
   are insufficient. These queries do not independently return the project ref.
2. Confirm the SQL Editor role is the Owner-approved diagnostic role. Do not
   impersonate a browser role, change role memberships or grant privileges.
   SQL Editor's role need not be the intended migration connection role;
   checks for that distinction remain on hold in script 04.
3. Open `01-01-identity.sql` locally and paste its entire contents into a fresh
   SQL Editor query. Clear text selection so Run executes the whole file.
   Verify the BEGIN, three SET LOCAL statements and final ROLLBACK are present.
   Run once. Expect one row with `read_only = on`; privately confirm
   `effective_role` and `connection_role` match the intended diagnostic context.
   If not, stop. Do not share raw role names if they identify an individual.
4. Run `01-02` through `01-15` separately, one complete file per Run, in numeric
   order. Confirm the project and role selection before each Run. Keep the
   grids private. Use OUTPUT-CONTRACTS.md to identify columns and interpret
   results. Record only counts and sanitized PASS/FAIL/UNKNOWN observations.
5. Check any UI row limit, truncation notice or pagination. Retrieve the whole
   result through supported UI display controls if possible without changing
   SQL. If completeness cannot be established, mark UNKNOWN and stop rather
   than adding LIMIT, changing filters or claiming a complete inventory.
6. After all 15 outputs are accessible and no error has occurred, run the
   entire `02-01-unrecorded-object-markers.sql` separately. Expect 91 marker
   rows across 17 migration versions, including repeated objects. Summarize
   classifications and the explicit presence/history flags privately.
7. Complete REPORT-TEMPLATE.md. Send only sanitized summaries. Retain full
   security metadata within the Owner-controlled environment. Dashboard query
   history/results may themselves retain metadata; avoid public sharing links.

The prior Owner result of 51 indexes with `valid=true` and `ready=true` supports
only those index flags at that run time. It does not reveal results 01–14,
establish transaction cleanup, verify unique constraints, or prove that any
missing migration was applied. A later run may legitimately have a different
count; investigate drift rather than forcing a count of 51.

## Result visibility and transaction cleanup

The Owner observed the last SELECT result from the original file even with its
final ROLLBACK. Each variant therefore puts exactly one diagnostic result in
that position. This is a compatibility proposal supported by that observation,
not a hosted test of the variants. Do not append a result query after ROLLBACK:
it would run outside the explicit read-only transaction.

If the editor displays only a command acknowledgement or hides the sole grid,
stop and report UNKNOWN. Do not remove ROLLBACK or execute BEGIN, SELECT and
ROLLBACK using separate Run clicks: backend-session continuity is unverified.
An alternative is an Owner-controlled PostgreSQL client that displays every
result of the unchanged originals, using an already approved connection and
fail-on-error handling. That client must reliably close the same session on
failure. This alternative requires a separately reviewed execution procedure;
no connection string, credential, installation or production execution is
requested here.

Any SQL error, timeout, cancellation, unexpected output or unexpected role is a
stop condition. Record only the filename and SQLSTATE/sanitized error category;
do not paste the complete message or request logs. Some clients stop a batch
before reaching ROLLBACK. If the same backend session is definitely still open,
the Owner can use its rollback/close-session control to abort the transaction.
Do not assume a later SQL Editor Run uses that same backend. If cleanup is
uncertain, ask the Owner's database administrator to verify/close the diagnostic
session before continuing. Never resolve a diagnostic failure by changing
schema, roles, grants, history or RLS.

## Safety, permissions and production cost

The only SQL statement classes are transaction control, SET LOCAL and SELECT.
Privilege names such as INSERT/UPDATE/DELETE occur only as string arguments to
catalog permission-inspection functions; they do not execute those operations.
No application RPC is invoked. Reads cover system catalogs and the `version`
column of migration history; they return no member, payment, token or audit
records. Function bodies, policy expressions, defaults, PIN material, trigger
arguments and secret settings are excluded. Names/types of sensitive columns
may still appear as metadata.

All outputs remain security metadata. Identity/owner fields, object names,
routine signatures/results, grants, role lists, RLS flags, policies, trigger
routines, columns, indexes and migration versions should stay private. Existing
OTHER_ROLE masking is retained, but ownership and session names are not masked.
Only aggregate findings and approved source object names belong in a report.

Missing `api`/`private` schemas, tables or listed executor roles generally produce
missing rows, not exceptions: the catalog queries filter by names/OIDs. Missing
roles are omitted, never equivalent to explicit deny. The two migration-history
queries (01-02 and 02-01) can fail if the history schema/table/`version` column is
missing or permission is denied. Catalog access, required catalog columns or
built-ins can also be unavailable on an incompatible runtime. Parse validation
does not resolve hosted objects or permissions. `row_security_active` can require
relation access/locking and can fail on permission or concurrent DDL conditions.
Stop on any error; do not grant access to make a check succeed.

These are metadata scans, not ledger scans. ACL expansion, role cross joins and
the 91 marker lookups can grow with catalog size. They acquire ordinary read
locks, including reads of migration history; `row_security_active` may open a
relation with an AccessShareLock. Reads can wait behind or delay conflicting DDL.
No SELECT FOR UPDATE or explicit stronger lock is used. The 30-second timeout is
per statement, not a total batch deadline; lock timeout is 2 seconds per lock
attempt. Separate small transactions reduce duration, but no zero-cost or
zero-lock guarantee is made. Respect a quiet production window.

## Production versus isolated checks

These 16 files are candidates for narrowly authorized read-only production
verification after review. Hosted SQL Editor display, runtime permissions and
successful cleanup remain UNKNOWN until observed by the Owner. Changing
ownership, role compatibility tests involving SET ROLE/DDL, applying migrations,
audit-chain mutation/refusal tests, lifecycle repair, payment/check-in requests,
concurrency, rate-limit/load and real Auth→Edge→PostgREST acceptance belong in an
explicitly approved isolated environment with synthetic data. Scripts 03–07,
all production migrations, configuration changes and deployments remain on hold.

## Static validation

From the repository root run `node docs/production-preflight/sql-editor/validate.cjs`.
It uses the existing ignored parser cache (PostgreSQL 17 and 18 grammars), with
no database/network connection and no dependency installation. It checks source
hashes, file hashes, exact extracted SELECT text, AST equality, output columns,
transaction/timeout wrappers, allowed statement classes, catalog-only relations
and allowed built-in functions. If that cache is absent, validation fails closed;
do not install a dependency or connect to production as a fallback.
