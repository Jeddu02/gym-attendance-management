# Reproducible recovery parser tooling

This separate development-only package pins the same already-used libpg-query
versions: PG17 17.8.2 and PG18 18.1.4. It is not bundled into the application.
The lock pins all four package records with npm registry SHA-512 integrity.

From the repository root:

```powershell
npm.cmd ci --prefix tools/recovery-parser --ignore-scripts --no-audit --no-fund
node --test tests/recovery.test.mjs tests/recovery-sql.test.mjs tests/recovery-compatibility.test.mjs tests/recovery-tooling.test.mjs
node scripts/recovery/validate-source.mjs
node docs/production-preflight/sql-editor/validate.cjs
node scripts/test-recovery-reproducibility.mjs
```

The final command constructs a separate allowlisted workspace with no historical
parser cache or root node_modules, installs with a new empty npm cache and the
supplied lock/SRI, runs all recovery tests/validators and both generators. It
requires public npm registry access; offline acquisition is not claimed. All
output stays under ignored .cache. No dependencies or install scripts are added
to the application. The loader checks exact installed versions and refuses
unsupported majors; it never falls back to .cache/foundation-parser. npm ci is
the integrity-checked installation boundary, not a signature or immunity to later
local filesystem tampering. Preserve the lock; do not use npm update for review.
