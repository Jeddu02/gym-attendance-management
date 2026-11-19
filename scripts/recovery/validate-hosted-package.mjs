// Offline review only. Never opens a database connection or executes SQL.
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
import { readCanonicalSource } from './source-bytes.mjs';
const require = createRequire(import.meta.url);
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const planPath = 'docs/HOSTED-READINESS-DIAGNOSTIC-PLAN.md';
const formPath = 'docs/HOSTED-DIAGNOSTIC-AUTHORIZATION-FORM.md';
const split = ['identity', 'migration-history', 'schemas', 'routines', 'routine-acls',
  'routine-permissions', 'schema-permissions', 'default-acls', 'table-rls',
  'table-permissions', 'policies', 'columns', 'triggers', 'constraints', 'indexes']
  .map((name, i) => `docs/production-preflight/sql-editor/01-${String(i + 1).padStart(2, '0')}-${name}.sql`);
const recovery = name => `supabase/recovery/${name}.sql`;
export const executionOrder = Object.freeze([
  'H01', recovery('history'), recovery('catalog'), ...split,
  'docs/production-preflight/sql-editor/02-01-unrecorded-object-markers.sql',
  recovery('diagnostics/compatibility-authority'), recovery('diagnostics/migration-authority'),
  recovery('effective-privileges'), 'H02', recovery('compatibility/review/effective-privileges'),
  recovery('diagnostics/legacy-dependencies'), 'H03', recovery('diagnostics/registration-plan-cash'),
  recovery('diagnostics/audit'), recovery('diagnostics/lifecycle-payments'),
  recovery('diagnostics/additional-legacy-blockers'),
]);
// Explicit reviewed builtin inventory. SELECT alone does not prove a function is safe.
const functions = new Set(('acldefault aclexplode bool_and btrim clock_timestamp concat_ws convert_to count current_setting '
  + 'daterange encode format_type has_any_column_privilege has_function_privilege has_schema_privilege '
  + 'has_sequence_privilege has_table_privilege jsonb_agg jsonb_build_object lag lower pg_get_constraintdef '
  + 'pg_get_expr pg_get_function_identity_arguments pg_get_function_result pg_get_functiondef pg_get_indexdef '
  + 'pg_get_triggerdef pg_get_userbyid pg_get_viewdef pg_has_role regexp_replace row_security_active sha256 '
  + 'split_part timezone to_char to_jsonb to_regclass to_regprocedure unnest').split(' '));
const visibilityHash = 'd2361a019c4716ea1f5b38bc5c795a384030fd9215d7100c0531f057fd4d5602';
const fail = message => { throw new Error(message); };

export function inventory(plan, form, readBytes) {
  const rows = [...plan.matchAll(/^\| `([^`]+)` \| `([a-f0-9]{64})` \|$/gm)];
  const approvals = [...form.matchAll(/^\| \[ \] \| (D-META|D-DATA) \| `([^`]+)` \| `([a-f0-9]{64})` \|$/gm)];
  if (rows.length !== 30 || approvals.length !== 30 || new Set(rows.map(r => r[1])).size !== 30)
    fail('Incomplete or duplicate candidate inventory');
  const blocks = [...plan.matchAll(/```sql\r?\n([\s\S]*?)\r?\n```/g)];
  if (blocks.length !== 3) fail('Expected exactly three embedded supplements');
  const byId = new Map(rows.map(row => [row[1], row[2]]));
  const data = new Set(executionOrder.slice(25));
  for (const row of approvals) {
    if (byId.get(row[2]) !== row[3] || row[1] !== (data.has(row[2]) ? 'D-DATA' : 'D-META'))
      fail('Form, scope and reviewed hashes disagree');
  }
  if (new Set(approvals.map(r => r[2])).size !== 30) fail('Duplicate form candidate');
  return executionOrder.map((id, i) => {
    const bytes = /^H0[123]$/.test(id)
      ? Buffer.from(blocks[Number(id[2]) - 1][1].replace(/\r\n/g, '\n') + '\n')
      : readBytes(id);
    if (!byId.has(id) || digest(bytes) !== byId.get(id)) fail(`Reviewed bytes mismatch: ${id}`);
    return { id, order: i + 1, scope: data.has(id) ? 'D-DATA' : 'D-META',
      conditional: i >= 28, sql: bytes.toString('utf8'), sha256: byId.get(id) };
  });
}

export function inspectSql(sql, parser, allowVisibilityDo = false) {
  if (!/^\s*(?:--[^\n]*\n\s*)*BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;/i.test(sql)
    || !/ROLLBACK;\s*$/.test(sql)) fail('Required READ ONLY wrapper missing');
  const stmts = parser.parseSync(sql).stmts.map(row => row.stmt);
  const types = stmts.map(stmt => Object.keys(stmt)[0]);
  if (types[0] !== 'TransactionStmt' || types.at(-1) !== 'TransactionStmt'
    || stmts[0].TransactionStmt.kind !== 'TRANS_STMT_BEGIN'
    || stmts.at(-1).TransactionStmt.kind !== 'TRANS_STMT_ROLLBACK') fail('Transaction boundaries changed');
  const settings = stmts.slice(1, 4).map(stmt => stmt.VariableSetStmt);
  for (const [i, [name, value]] of [['statement_timeout', '30s'], ['lock_timeout', '2s'], ['search_path', 'pg_catalog']].entries()) {
    const setting = settings[i];
    if (!setting?.is_local || setting.kind !== 'VAR_SET_VALUE' || setting.name !== name
      || setting.args?.length !== 1 || setting.args[0].A_Const?.sval?.sval !== value) fail('Timeout/search-path settings changed');
  }
  const remaining = stmts.slice(4, -1);
  // The reviewed audit diagnostic additionally pins UTC for inline hash verification.
  if (remaining[0]?.VariableSetStmt) {
    const setting = remaining.shift().VariableSetStmt;
    if (!setting.is_local || setting.kind !== 'VAR_SET_VALUE' || setting.name.toLowerCase() !== 'timezone'
      || setting.args?.length !== 1 || setting.args[0].A_Const?.sval?.sval !== 'UTC') fail('Unexpected additional setting');
  }
  if (!remaining.length) fail('Missing diagnostic result');
  for (const stmt of remaining) {
    if (stmt.DoStmt && allowVisibilityDo && digest(Buffer.from(sql)) === visibilityHash) continue;
    if (!stmt.SelectStmt) fail('Non-SELECT diagnostic statement');
    const walk = node => {
      if (!node || typeof node !== 'object') return;
      if (Object.keys(node).some(key => /^(?:Insert|Update|Delete|Merge|Call|Copy)Stmt$/.test(key)
        || ['intoClause', 'lockingClause'].includes(key))) fail('Mutation or row locking forbidden');
      if (node.FuncCall) {
        const name = node.FuncCall.funcname.map(x => x.String.sval);
        if (name.length > 2 || (name.length === 2 && name[0] !== 'pg_catalog') || !functions.has(name.at(-1)))
          fail('Unreviewed function invocation');
      }
      Object.values(node).forEach(walk);
    };
    walk(stmt);
  }
}

export async function validatePackage() {
  // In a Git checkout these unchanged review documents must also match HEAD.
  const plan = readCanonicalSource(planPath).toString('utf8');
  const form = readCanonicalSource(formPath).toString('utf8');
  const units = inventory(plan, form, file => readFileSync(file));
  for (const major of [17, 18]) {
    const parser = require('./parser.cjs')(major);
    await parser.loadModule();
    for (const unit of units) inspectSql(unit.sql, parser, unit.order === 30);
  }
  return units;
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const units = await validatePackage();
    console.log(`PASS: ${units.length} exact hashes, 25 metadata / 5 data, ordered 1–30; PG17/18 static checks. Units 29–30 conditional. No SQL executed; no authorization inferred.`);
  } catch (error) {
    console.error(`HOLD: ${error.message}. No SQL executed.`);
    process.exitCode = 2;
  }
}
