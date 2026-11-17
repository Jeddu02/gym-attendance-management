// Offline, explicitly pinned parser only. No database access or SQL execution.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);

for (const major of [17, 18]) {
  test(`new hosted diagnostics have only READ ONLY transaction, local settings, SELECT and ROLLBACK (PG${major} grammar)`, async () => {
    const parser = require('../scripts/recovery/parser.cjs')(major);
    await parser.loadModule();
    for (const file of ['history.sql', 'diagnostics/legacy-dependencies.sql', 'diagnostics/migration-authority.sql', 'diagnostics/compatibility-authority.sql', 'effective-privileges.sql']) {
      const sql = readFileSync(new URL('../supabase/recovery/' + file, import.meta.url), 'utf8');
      const statements = parser.parseSync(sql).stmts.map(x => x.stmt);
      assert.equal(statements.length, 6, file);
      assert.deepEqual(statements.map(x => Object.keys(x)[0]),
        ['TransactionStmt', 'VariableSetStmt', 'VariableSetStmt', 'VariableSetStmt', 'SelectStmt', 'TransactionStmt']);
      assert.match(sql, /BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;/);
      assert.match(sql, /ROLLBACK;\s*$/);
      const inspect = node => {
        if (!node || typeof node !== 'object') return;
        assert.equal(Object.hasOwn(node, 'intoClause'), false, 'SELECT INTO forbidden');
        assert.equal(Object.hasOwn(node, 'lockingClause'), false, 'Row locks forbidden');
        assert.equal(Object.hasOwn(node, 'InsertStmt') || Object.hasOwn(node, 'UpdateStmt') || Object.hasOwn(node, 'DeleteStmt'), false);
        if (node.RangeVar) {
          const { schemaname, relname } = node.RangeVar;
          if (schemaname) assert.ok(schemaname === 'pg_catalog' || schemaname === 'supabase_migrations');
          else assert.ok(relname.startsWith('pg_') || ['target', 'findings', 'creators', 'risks', 'actor', 'reserved', 'names', 'edges', 'fixture'].includes(relname));
        }
        Object.values(node).forEach(inspect);
      };
      inspect(statements[4]);
    }
  });
}
