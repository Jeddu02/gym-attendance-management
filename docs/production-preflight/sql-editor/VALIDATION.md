# Static validation evidence — 2026-11-16

Command: `node docs/production-preflight/sql-editor/validate.cjs`

Result: PASS on both installed parser grammars (`pg17`, `pg18`).

- 15 catalog results map one-to-one, in original order, to 15 standalone files.
- Original marker WITH/SELECT maps to one standalone file, preserving 91 VALUES
  rows and all classification/NULL behavior.
- All 16 files contain six statements: explicit repeatable-read READ ONLY BEGIN,
  three SET LOCAL statements, one diagnostic SELECT and final ROLLBACK.
- Exact original SELECT source text, normalized ASTs and ordered output column
  names match. PostgreSQL 17/18 parser location offsets differ; only source
  position metadata is excluded from AST comparison. The manifest records PG17
  source byte ranges including their preceding comments. Neither grammar's
  comparison changes expressions, aliases, constants, filters or ordering.
- No nested mutation statements, SELECT INTO or locking clauses; relations and
  function calls are restricted to the reviewed catalogs/history/CTEs and
  allowlisted PostgreSQL built-ins. Application RPCs are not executed.
- Timeout values remain statement_timeout=30s and lock_timeout=2s; local search
  path remains pg_catalog. No role, grant, RLS, schema or persistent setting change.
- Original SHA-256 values remain:

```text
01-catalog.sql
ebbfcc096f28fc15cbd352010887eb07d095b7af6f82cb27b9b98d2fcccd1106
02-unrecorded-object-markers.sql
9b187d2c9adf3590f6da7353940972d88502fd44e07584810a0d2d714b0a0277
```

Initial validator development encountered PostgreSQL 18 parser source-position
fields that differ from PostgreSQL 17. The validator now compares exact text
within each grammar and removes only those source positions for AST comparison;
the final run passed both grammars. SQL files were unchanged during that fix.

No SQL was executed, no database connection was used and no production
credentials were accessed for this validation. Hosted catalog resolution,
permissions, row completeness, statement timing, SQL Editor result visibility
and transaction cleanup remain UNKNOWN pending Owner approval/execution.

Review limitation: split files use separate snapshots. Approval of the original
single catalog transaction does not authorize these variants automatically.
Scripts 03–07, migrations and deployments remain on hold.
