import test from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { mkdtempSync, mkdirSync, copyFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
const require=createRequire(import.meta.url);
const loader=require('../scripts/recovery/parser.cjs');
test('explicit pinned parsers work and unsupported majors refuse without cache fallback',async()=>{
  assert.throws(()=>loader(16),/Unsupported parser major/);
  for(const major of [17,18]) {
    const parser=loader(major); await parser.loadModule();
    assert.equal(parser.parseSync('SELECT 1;').stmts.length,1);
    assert.throws(()=>parser.parseSync('SELECT FROM ;'));
  }
});
test('stale installed parser version refuses before loading executable module',()=>{
  const root=resolve(import.meta.dirname,'..');
  mkdirSync(resolve(root,'.cache'),{recursive:true});
  const fresh=mkdtempSync(resolve(root,'.cache/parser-loader-negative-'));
  mkdirSync(resolve(fresh,'scripts/recovery'),{recursive:true});
  mkdirSync(resolve(fresh,'tools/recovery-parser/node_modules/pg17'),{recursive:true});
  copyFileSync(resolve(root,'scripts/recovery/parser.cjs'),resolve(fresh,'scripts/recovery/parser.cjs'));
  copyFileSync(resolve(root,'tools/recovery-parser/package-lock.json'),resolve(fresh,'tools/recovery-parser/package-lock.json'));
  writeFileSync(resolve(fresh,'tools/recovery-parser/node_modules/pg17/package.json'),JSON.stringify({version:'0.0.0'}));
  assert.throws(()=>require(resolve(fresh,'scripts/recovery/parser.cjs'))(17),/Installed parser version differs/);
});
