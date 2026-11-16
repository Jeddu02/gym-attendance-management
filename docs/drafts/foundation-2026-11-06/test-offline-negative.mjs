// Child-process tests of the real checker. No database/network tools invoked.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { directory, json, read } from './source-contract.mjs';
const temporary=fs.mkdtempSync(path.join(os.tmpdir(),'gymforce-offline-'));
const results=[];
function check(args,expected,reason,id) {
  const r=spawnSync(process.execPath,[path.join(directory,'check-offline.mjs'),...args],{encoding:'utf8',timeout:20000});
  if (r.error || r.signal || r.status!==expected || (reason&&!r.stderr.includes('REFUSED: '+reason))) throw Error('Unexpected process result: '+id);
  results.push({id,exit:r.status}); console.log(`${id}: exit ${r.status}`);
}
try {
  check([],0,null,'positive-control');
  const baseline=json(path.join(directory,'aligned-schema-contract.json'));
  for(const fixture of json(path.join(directory,'offline-negative-fixtures.json'))) {
    const copy=structuredClone(baseline); let parent=copy;
    for(const key of fixture.path.slice(0,-1)) parent=parent[key];
    const key=fixture.path.at(-1);
    if(fixture.action==='set') parent[key]=fixture.value;
    else if(fixture.action==='append') parent[key].push(fixture.value);
    else if(fixture.action==='remove-last') parent[key].pop();
    else throw Error('Unknown fixture action');
    if(JSON.stringify(copy)===JSON.stringify(baseline)) throw Error('Fixture made no change: '+fixture.id);
    const candidate=path.join(temporary,fixture.id+'.json'); fs.writeFileSync(candidate,JSON.stringify(copy));
    check(['--candidate',candidate],1,fixture.reason,fixture.id);
  }
  const original=read(path.join(directory,'20261106120000_owner_executor_foundation.sql.draft'));
  for (const [id,sql,reason] of [
    ['extra-grant-sql',original+'\nGRANT SELECT ON private.members TO authenticated;\n','STATEMENT_COUNT'],
    ['altered-policy-sql',original.replace("USING (CURRENT_USER = 'gym_owner_executor'::name)",'USING (true)'),'STATEMENT_'],
    ['missing-guard-sql',original.replace("RAISE EXCEPTION 'DRAFT ONLY:","RAISE NOTICE 'DRAFT ONLY:"),'BLOCKER'],
    ['disabled-default-acl-guard-sql',original.replace('WHERE acl.grantee<>creator_oid','WHERE false'),'STATEMENT_'],
    ['disabled-constraint-validation-sql',original.replace('AND c.convalidated AND c.conislocal','AND true AND c.conislocal'),'STATEMENT_'],
    ['disabled-nullability-guard-sql',original.replace("AND a.attnotnull=(col->>'not_null')::boolean",'AND true'),'STATEMENT_']
  ]) {
    if(sql===original) throw Error('SQL fixture made no change: '+id);
    const candidate=path.join(temporary,id+'.sql.draft'); fs.writeFileSync(candidate,sql);
    check(['--migration',candidate],1,reason,id);
  }
  console.log(`PASS: ${results.length-1} negative subprocesses exited 1 for the expected reason; positive control exited 0.`);
} catch(error) { console.error(error.message); process.exitCode=1; }
finally {
  // Only explicitly created files, no recursive delete or computed directory tree removal.
  for(const name of fs.readdirSync(temporary)) fs.unlinkSync(path.join(temporary,name));
  fs.rmdirSync(temporary);
}
