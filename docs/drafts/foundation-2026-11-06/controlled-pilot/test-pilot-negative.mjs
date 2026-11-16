// Filesystem/subprocess simulations ONLY. Never invokes PostgreSQL or an executable pilot.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {directory,read} from '../source-contract.mjs';
const folder=directory+'/controlled-pilot',temp=fs.mkdtempSync(path.join(os.tmpdir(),'gymforce-pilot-offline-'));
const spec=JSON.parse(read(folder+'/pilot-spec.json')),manifest=JSON.parse(read(folder+'/candidate-manifest.json'));
const results=[];
function run(id,args,expected,wrapper=false){
 const binary=wrapper?'powershell.exe':process.execPath;
 const prefix=wrapper?['-NoProfile','-ExecutionPolicy','Bypass','-File',folder+'/review-pilot.ps1']:[folder+'/check-pilot.mjs'];
 const r=spawnSync(binary,[...prefix,...args],{encoding:'utf8',timeout:20000});
 if(r.error||r.signal||r.status!==expected)throw Error('UNEXPECTED_EXIT_'+id);
 results.push({id,expected_exit:expected,actual_exit:r.status,evidence:'SYNTHETIC_FILESYSTEM_ONLY_NOT_DATABASE_EXECUTION'});console.log(id+': exit '+r.status);
}
function fixture(name,obj){const file=path.join(temp,name+'.json');fs.writeFileSync(file,JSON.stringify(obj));return file;}
try{
 run('positive-offline-artifact',[],0);
 for(const [id,mutate] of [
  ['wrong-database',s=>s.target.database='postgres'],['wrong-endpoint',s=>s.target.host='0.0.0.0'],['wrong-port',s=>s.target.port=5432],
  ['wrong-marker',s=>s.target.marker='00000000-0000-4000-8000-000000000000'],['wrong-system-identity',s=>s.target.system_identifier='0'],
  ['wrong-data-directory',s=>s.target.data_directory='C:\\unapproved'],['wrong-execution-role',s=>s.connection_role='service_role']
 ]){const s=structuredClone(spec);mutate(s);run(id,['--spec',fixture(id,s)],2);}
 const approval={approved_by_owner:true,revision:manifest.revision,scope:spec.mode,exclusive_window_attested:true,window_start_utc:new Date(Date.now()-10000).toISOString(),window_end_utc:new Date(Date.now()+600000).toISOString(),backup:null};
 run('missing-backup',['--approval',fixture('missing-backup',approval)],2);
 run('unapproved-template',['--approval',folder+'/approval.example.json'],2);
 const base={sql_exit:0,fresh_identity_verified:true,rollback_verified:true,schema_acl_roles_defaults_restored:true,sequence_state_unchanged:true,business_fixtures_created:false};
 for(const [id,change,exit] of [
  ['failed-assertion',{sql_exit:3},3],['incomplete-rollback',{rollback_verified:false},2],['unexpected-schema-mutation',{schema_acl_roles_defaults_restored:false},2],
  ['sequence-advanced',{sequence_state_unchanged:false},2],['unexpected-fixture',{business_fixtures_created:true},2],['post-identity-unverified',{fresh_identity_verified:false},2]
 ])run(id,['--outcomes',fixture(id,{...base,...change})],exit);
 const sql=read(folder+'/LOCAL-TEST-ONLY.catalogue-pilot.sql');
 for(const [id,change] of [
  ['terminal-commit',s=>s.replace(/ROLLBACK;\s*$/,'COMMIT;')],
  ['embedded-commit',s=>s.replace('SET LOCAL search_path','COMMIT;\nSET LOCAL search_path')],
  ['unexpected-grant',s=>s.replace(/ROLLBACK;\s*$/,'GRANT SELECT ON private.members TO anon;\nROLLBACK;')],
  ['wrong-sql-identity',s=>s.replace("IS DISTINCT FROM 'gymforce_pg18_test'","IS DISTINCT FROM 'postgres'")],
  ['backup-guard-bypassed',s=>s.replace("current_setting('gymforce.pilot.backup_verified',true) IS DISTINCT FROM 'true'",'false')]
 ]){const altered=change(sql);if(altered===sql)throw Error('NO_MUTATION');const file=path.join(temp,id+'.sql');fs.writeFileSync(file,altered);run(id,['--candidate',file],2);}
 run('wrapper-propagates-assertion-exit',['-Outcomes',fixture('wrapper-failed',{...base,sql_exit:3})],3,true);
 run('wrapper-propagates-rollback-refusal',['-Outcomes',fixture('wrapper-rollback',{...base,rollback_verified:false})],2,true);
 run('execution-switch-refuses',['-Execute'],2,true);
 fs.mkdirSync(folder+'/local',{recursive:true});
 fs.writeFileSync(folder+'/local/negative-results.json',JSON.stringify({scope:'OFFLINE SIMULATIONS ONLY; no SQL guard/runtime outcomes proven',results},null,2)+'\n');
 console.log('PASS: '+(results.length-1)+' offline negative subprocesses refused; positive artifact exit 0.');
}catch{console.error('REFUSED: PILOT_NEGATIVE_SUITE');process.exitCode=1;}
finally{for(const file of fs.readdirSync(temp))fs.unlinkSync(path.join(temp,file));fs.rmdirSync(temp);}
