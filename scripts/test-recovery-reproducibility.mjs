// Fresh, allowlisted workspace and empty npm cache; never copies .env or root dependencies.
import { mkdtempSync, mkdirSync, copyFileSync, cpSync, writeFileSync, existsSync, readdirSync, readFileSync, realpathSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { resolve } from 'node:path';
const root=resolve(import.meta.dirname,'..');
mkdirSync(resolve(root,'.cache'),{recursive:true});
if(realpathSync(resolve(root,'.cache')).toLowerCase()!==resolve(root,'.cache').toLowerCase()) throw Error('Redirected cache refused');
const fresh=mkdtempSync(resolve(root,'.cache/parser-repro-'));
for(const folder of ['scripts/recovery','supabase/migrations','supabase/recovery','supabase/tests','supabase/functions','docs/production-preflight']) {
  cpSync(resolve(root,folder),resolve(fresh,folder),{recursive:true});
}
mkdirSync(resolve(fresh,'tools/recovery-parser'),{recursive:true});
mkdirSync(resolve(fresh,'tests'));
for(const file of ['package.json','package-lock.json']) copyFileSync(resolve(root,'tools/recovery-parser',file),resolve(fresh,'tools/recovery-parser',file));
for(const file of ['recovery.test.mjs','recovery-sql.test.mjs','recovery-compatibility.test.mjs','recovery-tooling.test.mjs','recovery-integrity.test.mjs']) copyFileSync(resolve(root,'tests',file),resolve(fresh,'tests',file));
writeFileSync(resolve(fresh,'package.json'),JSON.stringify({private:true,type:'module'}));
if(existsSync(resolve(fresh,'.cache'))||existsSync(resolve(fresh,'node_modules'))) throw Error('Clean-room prerequisites violated');
execFileSync('cmd.exe',['/d','/s','/c','npm.cmd ci --prefix tools/recovery-parser --ignore-scripts --no-audit --no-fund --registry https://registry.npmjs.org --cache npm-empty-cache'],{cwd:fresh,stdio:'inherit'});
const artifacts=()=>Object.fromEntries(['review','synthetic'].flatMap(mode=>{
  const dir=resolve(fresh,'supabase/recovery/compatibility',mode);
  return readdirSync(dir).filter(f=>f.endsWith('.sql')||f==='manifest.json').sort().map(file=>[mode+'/'+file,createHash('sha256').update(readFileSync(resolve(dir,file))).digest('hex')]);
}));
const before=JSON.stringify(artifacts());
for(const args of [
  ['--test','tests/recovery.test.mjs','tests/recovery-sql.test.mjs','tests/recovery-compatibility.test.mjs','tests/recovery-tooling.test.mjs','tests/recovery-integrity.test.mjs'],
  ['scripts/recovery/validate-source.mjs'],['scripts/recovery/build-compatibility.mjs'],
  ['scripts/recovery/build-compatibility.mjs','--synthetic'],['docs/production-preflight/sql-editor/validate.cjs']
]) execFileSync(process.execPath,args,{cwd:fresh,stdio:'inherit'});
if(before!==JSON.stringify(artifacts())) throw Error('Clean-room generator changed reviewed artifact bytes');
console.log('PASS clean-room recovery suite: pinned npm ci/SRI, no root node_modules or historical parser cache. Evidence: '+fresh);
