import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import { verifySourceManifest } from '../scripts/recovery/compare-catalog.mjs';
import { verifyReviewedSource } from '../scripts/recovery/source-bytes.mjs';
const require = createRequire(import.meta.url);
const parser = require('../scripts/recovery/parser.cjs')(17);
await parser.loadModule();
const root = new URL('../',import.meta.url);
const load = path => readFileSync(new URL(path,root),'utf8');
const sha = text => createHash('sha256').update(text).digest('hex');
const normal = x => Array.isArray(x) ? x.map(normal) : x && typeof x==='object'
  ? Object.fromEntries(Object.entries(x).filter(([k]) => !['location','stmt_location','stmt_len'].includes(k)).map(([k,v]) => [k,normal(v)]))
  : typeof x==='string' ? x.replace(/\r\n/g,'\n') : x;
const functions = sql => parser.parseSync(sql.replace(/^\uFEFF/,'')).stmts.filter(x => x.stmt.CreateFunctionStmt).map(x => normal(x.stmt.CreateFunctionStmt));

for (const mode of ['review','synthetic']) {
  const base = 'supabase/recovery/compatibility/'+mode+'/';
  const manifest = JSON.parse(load(base+'manifest.json'));
  test(`${mode}: compatibility source fingerprints and every application function AST match`, () => {
    verifySourceManifest(manifest.sourceManifest);
    const migrations = manifest.records.filter(x => /^\d{14}_/.test(x.file));
    assert.equal(migrations.length,13);
    for (const record of manifest.records) {
      const sql = load(base+record.file);
      assert.equal(sha(sql),record.compatibilitySha256,record.file);
      assert.doesNotMatch(sql, /[\t ]+$/m, `${record.file}: generated trailing whitespace`);
      if (!/^\d{14}_/.test(record.file)) continue;
      const original = verifyReviewedSource('supabase/migrations/'+record.file,record.originalSha256).bytes;
      assert.deepEqual(functions(sql),functions(original.toString('utf8')),record.file);
      assert.equal(record.historyAction,'NONE');
      assert.match(sql,/Customer PG17 migration identity required/);
      assert.match(sql,/Temporary migration authority leaked/);
      assert.match(sql,/REVOKE %I FROM postgres GRANTED BY postgres/);
      assert.doesNotMatch(sql,/NO FORCE ROW LEVEL SECURITY|DISABLE ROW LEVEL SECURITY|SET LOCAL ROLE supabase_admin/i);
    }
    assert.equal(manifest.productionAuthorization,false);
    assert.equal(manifest.provider,mode==='review'?'supabase_admin':'gf_provider_admin');
  });
  test(`${mode}: maintenance SELECT is limited to reviewed guard tables and no persisted runner`, () => {
    const expected = new Map([
      ['20261110103000',['audit_events','audit_chain_heads']],
      ['20261110110000',['members','membership_purchases','payment_records','payment_allocations','payment_events']],
      ['20261110160000',['membership_purchases']],['20261110170000',['cash_drawer_sessions']]
    ]);
    for (const record of manifest.records.filter(x => /^\d{14}_/.test(x.file))) {
      const sql=load(base+record.file), names=expected.get(record.file.slice(0,14));
      if (!names) assert.doesNotMatch(sql,/CREATE POLICY gf_compatibility_read/);
      else {
        assert.match(sql,/FOR SELECT TO postgres USING/);
        assert.match(sql,/SESSION_USER = ''postgres''::name/);
        assert.match(sql,/Unreviewed restrictive policy prevents full-visibility proof/);
        assert.ok(sql.includes("c.relname IN ("+names.map(x=>"'"+x+"'").join(',')+")"));
      }
      assert.ok(functions(sql).every(fn=>!JSON.stringify(fn.funcname).includes('compatibility')));
    }
  });
}
