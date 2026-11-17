// Offline parser validation only. No SQL execution, network or database client.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');

const dir = __dirname;
const root = path.resolve(dir, '../../..');
const manifest = JSON.parse(fs.readFileSync(path.join(dir, 'manifest.json'), 'utf8'));
const sha = value => crypto.createHash('sha256').update(value).digest('hex');
const wrapper = `BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '2s';
SET LOCAL search_path=pg_catalog;
SELECT 1;
ROLLBACK;`;
const allowedFunctions = new Set([
  'current_setting', 'pg_get_userbyid', 'pg_get_function_identity_arguments',
  'pg_get_function_result', 'aclexplode', 'acldefault', 'has_function_privilege',
  'has_schema_privilege', 'row_security_active', 'has_table_privilege',
  'has_any_column_privilege', 'unnest', 'format_type', 'to_regclass', 'split_part',
]);
const catalogRelations = new Set([
  'pg_namespace', 'pg_proc', 'pg_language', 'pg_roles', 'pg_default_acl',
  'pg_class', 'pg_policy', 'pg_attribute', 'pg_trigger', 'pg_constraint', 'pg_index',
]);

function normalize(value) {
  if (Array.isArray(value)) return value.map(normalize);
  if (!value || typeof value !== 'object') return value;
  return Object.fromEntries(Object.entries(value)
    .filter(([key]) => !['location', 'stmt_location', 'stmt_len',
      'rexpr_list_start', 'rexpr_list_end', 'list_start', 'list_end'].includes(key))
    .map(([key, child]) => [key, normalize(child)]));
}

function inspect(value) {
  if (!value || typeof value !== 'object') return;
  for (const [key, node] of Object.entries(value)) {
    if (key.endsWith('Stmt')) assert.equal(key, 'SelectStmt', 'Unexpected nested statement');
    assert.ok(!['intoClause', 'lockingClause'].includes(key), 'SELECT INTO/locking forbidden');
    if (key === 'RangeVar') {
      assert.ok((node.schemaname === 'pg_catalog' && catalogRelations.has(node.relname))
        || (node.schemaname === 'supabase_migrations' && node.relname === 'schema_migrations')
        || (!node.schemaname && ['expected', 'observed'].includes(node.relname)),
      'Unexpected relation');
    }
    if (key === 'FuncCall') {
      const names = node.funcname.map(part => part.String.sval);
      assert.ok(names.length === 1 || (names.length === 2 && names[0] === 'pg_catalog'));
      assert.ok(allowedFunctions.has(names.at(-1)), 'Unexpected function');
    }
    inspect(node);
  }
}

function extract(bytes, stmt) {
  const start = stmt.stmt_location || 0;
  return bytes.subarray(start, start + stmt.stmt_len).toString('utf8') + ';';
}

(async () => {
  assert.equal(manifest.files.length, 16);
  assert.equal(new Set(manifest.files.map(file => file.file)).size, 16);
  assert.deepEqual(fs.readdirSync(dir).filter(file => file.endsWith('.sql')).sort(),
    manifest.files.map(file => file.file).sort());
  for (const grammar of ['pg17', 'pg18']) {
    const parser = require(path.join(root, 'scripts/recovery/parser.cjs'))(Number(grammar.slice(2)));
    await parser.loadModule();
    const control = parser.parseSync(wrapper).stmts;
    const sources = new Map();
    for (const source of manifest.sources) {
      const bytes = fs.readFileSync(path.join(dir, '..', source.file));
      assert.equal(sha(bytes), source.sha256, 'Original changed');
      const selects = parser.parseSync(bytes.toString('utf8')).stmts.filter(s => s.stmt.SelectStmt);
      assert.equal(selects.length, source.result_sets);
      sources.set(source.file, { bytes, selects });
    }
    for (const item of manifest.files) {
      const bytes = fs.readFileSync(path.join(dir, item.file));
      assert.equal(sha(bytes), item.sha256, 'Variant changed');
      const ast = parser.parseSync(bytes.toString('utf8')).stmts;
      assert.equal(ast.length, 6, 'Expected BEGIN, three SET LOCAL, SELECT, ROLLBACK');
      for (const index of [0, 1, 2, 3, 5]) {
        assert.deepEqual(normalize(ast[index].stmt), normalize(control[index].stmt));
      }
      const source = sources.get(item.source);
      const original = source.selects[item.result_set - 1];
      const query = extract(source.bytes, original);
      // PG17 locations include preceding comments; PG18 starts at SELECT/WITH.
      // The manifest uses PG17 byte ranges. Both grammars compare their own
      // exact SELECT ranges and full normalized ASTs against the original.
      if (grammar === 'pg17') assert.equal(sha(query), item.select_sha256);
      assert.ok(extract(bytes, ast[4]).endsWith(query), 'Original SELECT text changed');
      assert.deepEqual(normalize(ast[4].stmt), normalize(original.stmt));
      const columns = ast[4].stmt.SelectStmt.targetList.map(({ ResTarget: target }) =>
        target.name || target.val.ColumnRef?.fields.at(-1).String.sval);
      assert.deepEqual(columns, item.columns, 'Output contract changed');
      inspect(ast[4].stmt);
    }
    console.log(`PASS ${grammar}: 16 files; exact SELECTs/ASTs/columns, wrappers, read-only catalog boundaries.`);
  }
  console.log('PASS original source hashes unchanged. No SQL executed. Hosted compatibility remains UNKNOWN.');
})().catch(error => {
  console.error('FAIL static validation:', error.message);
  process.exitCode = 1;
});
