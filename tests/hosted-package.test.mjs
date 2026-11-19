import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { inventory, inspectSql, validatePackage } from '../scripts/recovery/validate-hosted-package.mjs';
const require = createRequire(import.meta.url);
const plan = readFileSync('docs/HOSTED-READINESS-DIAGNOSTIC-PLAN.md', 'utf8');
const form = readFileSync('docs/HOSTED-DIAGNOSTIC-AUTHORIZATION-FORM.md', 'utf8');
const read = path => readFileSync(path);

test('all 30 real candidates match exact hashes, scope and conditional execution order', async () => {
  const units = await validatePackage();
  assert.equal(units.length, 30);
  assert.equal(units.filter(x => x.scope === 'D-META').length, 25);
  assert.deepEqual(units.filter(x => x.conditional).map(x => x.order), [29, 30]);
  assert.equal(units[0].id, 'H01');
  assert.equal(units[18].id.endsWith('02-01-unrecorded-object-markers.sql'), true);
  assert.equal(units[25].id, 'H03');
});
test('hash, duplicate inventory, scope and form mismatch fail closed', () => {
  assert.throws(() => inventory(plan, form, file => Buffer.concat([read(file), Buffer.from('\n')])));
  assert.throws(() => inventory(plan, form.replace('D-DATA | `H03`', 'D-META | `H03`'), read));
  assert.throws(() => inventory(plan.replace('| `H01` |', '| `H02` |'), form, read));
  assert.throws(() => inventory(plan, form.replace('`7f6aea263b9d7305bd60554e398dd607e426c80774bd92875975429e468804be`', '`' + '0'.repeat(64) + '`'), read));
});
for (const major of [17, 18]) {
  test(`PG${major} rejects nested DML, unsafe SELECT functions, row locks, mutation DO and wrapper changes`, async () => {
    const parser = require('../scripts/recovery/parser.cjs')(major);
    await parser.loadModule();
    const base = inventory(plan, form, read)[0].sql;
    const prefix = base.slice(0, base.indexOf('SELECT jsonb_build_object'));
    for (const sql of [
      base.replace('READ ONLY', 'READ WRITE'), base.replace("'30s'", "'300s'"),
      base.replace('SET LOCAL lock_timeout', 'SET lock_timeout'), base.replace('ROLLBACK;', 'COMMIT;'),
      `${prefix}SELECT api.owner_register_member(); ROLLBACK;`,
      `${prefix}SELECT pg_catalog.set_config('search_path','public',false); ROLLBACK;`,
      `${prefix}WITH x AS (DELETE FROM private.members RETURNING id) SELECT count(*) FROM x; ROLLBACK;`,
      `${prefix}SELECT * INTO unexpected FROM pg_roles; ROLLBACK;`,
      `${prefix}SELECT * FROM private.members FOR UPDATE; ROLLBACK;`,
      `${prefix}DO $$ BEGIN DELETE FROM private.members; END $$; ROLLBACK;`,
    ]) assert.throws(() => inspectSql(sql, parser, true));
    const last = inventory(plan, form, read).at(-1).sql;
    assert.doesNotThrow(() => inspectSql(last, parser, true));
    assert.throws(() => inspectSql(last + '\n', parser, true), 'Even the visibility DO exception is exact-byte pinned');
  });
}
