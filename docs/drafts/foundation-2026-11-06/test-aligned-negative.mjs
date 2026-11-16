// Mutated filesystem fixtures fed to the real static checker. No DB/network calls.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {directory,read} from './source-contract.mjs';
const temporary=fs.mkdtempSync(path.join(os.tmpdir(),'gymforce-aligned-'));
const baseline=JSON.parse(read(directory+'/aligned-schema-contract.json'));
const cases=[
 ['verified-check-expression',c=>c.tables.flatMap(t=>t.constraints).find(k=>k.kind==='c').catalog_definition+=' or true','CONTRACT_tables'],
 ['verified-exclusion-opclass',c=>c.tables.flatMap(t=>t.constraints).find(k=>k.kind==='x').exclusion.opclasses[0].schema='public','CONTRACT_tables'],
 ['index-key-opclass',c=>c.indexes[0].keys[0].opclass='text_pattern_ops','CONTRACT_indexes'],
 ['index-key-null-order',c=>c.indexes[0].keys[0].options=2,'CONTRACT_indexes'],
 ['column-verified-default',c=>c.tables[0].columns[0].catalog_default='null','CONTRACT_tables'],
 ['routine-verified-default',c=>c.routines[0].catalog_argument_defaults='true','CONTRACT_routines'],
 ['unexpected-browser-default',c=>c.default_privileges.non_owner_grants.push({role:'anon',privilege:'EXECUTE'}),'CONTRACT_default_privileges'],
 ['unexpected-executable-routine',c=>c.native_exposed_routines.push('public.unexpected()'),'CONTRACT_native_exposed_routines'],
 ['unexpected-trigger',c=>c.triggers.push({...c.triggers[0],name:'unexpected'}),'CONTRACT_triggers']
];
try{
 for(const [id,mutate,reason] of cases){const c=structuredClone(baseline);mutate(c);if(JSON.stringify(c)===JSON.stringify(baseline))throw Error('NO_MUTATION');
  const file=path.join(temporary,id+'.json');fs.writeFileSync(file,JSON.stringify(c));
  const child=spawnSync(process.execPath,[directory+'/check-offline.mjs','--candidate',file],{encoding:'utf8',timeout:20000});
  if(child.status!==1||!child.stderr.includes('REFUSED: '+reason))throw Error('UNEXPECTED_NEGATIVE_RESULT');console.log(id+': exit 1');
 }
 const original=read(directory+'/20261106120000_owner_executor_foundation.sql.draft');
 for(const [id,from,to] of [['rule-detection-removed','WHERE ev_class=obj','WHERE false'],['key-opclass-check-removed','AND oc.opcdefault','AND true']]){
  const altered=original.replace(from,to);if(altered===original)throw Error('NO_SQL_MUTATION');
  const file=path.join(temporary,id+'.sql.draft');fs.writeFileSync(file,altered);
  const child=spawnSync(process.execPath,[directory+'/check-offline.mjs','--migration',file],{encoding:'utf8',timeout:20000});
  if(child.status!==1||!child.stderr.includes('REFUSED: STATEMENT_'))throw Error('UNEXPECTED_SQL_NEGATIVE_RESULT');console.log(id+': exit 1');
 }
 console.log('PASS: 11 added aligned/security negative subprocesses refused.');
}catch{console.error('REFUSED: ALIGNED_NEGATIVE_SUITE');process.exitCode=1;}
finally{for(const name of fs.readdirSync(temporary))fs.unlinkSync(path.join(temporary,name));fs.rmdirSync(temporary);}
