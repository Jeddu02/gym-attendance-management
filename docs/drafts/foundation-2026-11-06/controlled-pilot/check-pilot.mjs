// Independent offline verifier. No PostgreSQL client, network or SQL execution.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {isDeepStrictEqual} from 'node:util';
import {directory,read,digest,statements,tokens,buildContract} from '../source-contract.mjs';
import {loadParser,validateSql} from '../offline-parser.mjs';
const folder=directory+'/controlled-pilot';
const arg=(key,fallback)=>{const at=process.argv.indexOf(key);return at<0?fallback:process.argv[at+1];};
const must=(ok,reason)=>{if(!ok)throw Error(reason);};
export function verifySpec(s){
 must(s.target?.database==='gymforce_pg18_test','WRONG_DATABASE');
 must(s.target.host==='127.0.0.1'&&s.target.port===55432,'WRONG_ENDPOINT');
 must(s.target.marker==='f497fabb-a12f-4068-b745-8b0729279276'&&s.target.system_identifier==='7704603813616068820'&&s.target.data_directory==='C:\\Users\\Banco-Sual\\AppData\\Local\\GYMFORCE-PG18-TEST\\data'&&s.target.major===18,'WRONG_CLUSTER_IDENTITY');
 must(s.connection_role==='postgres','WRONG_EXECUTION_ROLE');
 must(s.mode==='LOCAL-TEST-ONLY-CATALOGUE-ROLLBACK'&&s.execution_authorized===false&&s.sequence_budget===0&&s.fixtures.startsWith('NONE;'),'UNSAFE_SCOPE');
}
export function verifyOutcome(o){
 if(o.sql_exit!==0){const e=Error('FAILED_ASSERTION_OR_CLIENT');e.exit=Number.isInteger(o.sql_exit)&&o.sql_exit>0&&o.sql_exit<126?o.sql_exit:2;throw e;}
 must(o.fresh_identity_verified===true,'POST_IDENTITY_UNVERIFIED');
 must(o.rollback_verified===true,'INCOMPLETE_ROLLBACK');
 must(o.schema_acl_roles_defaults_restored===true,'UNEXPECTED_SCHEMA_MUTATION');
 must(o.sequence_state_unchanged===true,'UNEXPECTED_SEQUENCE_ADVANCEMENT');
 must(o.business_fixtures_created===false,'UNEXPECTED_FIXTURE');
}
function protectedArtifact(file,hash){
 must(typeof file==='string'&&path.isAbsolute(file)&&/^[a-f0-9]{64}$/.test(hash??''),'MISSING_BACKUP');
 const stat=fs.lstatSync(file);must(stat.isFile()&&!stat.isSymbolicLink()&&stat.size>0,'INVALID_BACKUP_ARTIFACT');
 must(crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')===hash,'BACKUP_HASH_MISMATCH');
}
export function verifyApproval(a,revision){
 must(a.approved_by_owner===true&&a.revision===revision&&a.scope==='LOCAL-TEST-ONLY-CATALOGUE-ROLLBACK'&&a.exclusive_window_attested===true,'MISSING_APPROVAL');
 const now=Date.now(),start=Date.parse(a.window_start_utc),end=Date.parse(a.window_end_utc);
 must(Number.isFinite(start)&&Number.isFinite(end)&&start<=now&&end>now&&end-start<=3600000,'INVALID_MAINTENANCE_WINDOW');
 const b=a.backup;must(b?.owner_attested===true&&b.source_database==='gymforce_pg18_test'&&b.source_system_identifier==='7704603813616068820','MISSING_BACKUP');
 protectedArtifact(b.path,b.sha256);protectedArtifact(b.restore_proof_path,b.restore_proof_sha256);
 // These verify declared evidence/file integrity, NOT that a restore actually succeeded or Owner consent exists.
}
try{
 const spec=JSON.parse(read(arg('--spec',folder+'/pilot-spec.json')));verifySpec(spec);
 const manifest=JSON.parse(read(folder+'/candidate-manifest.json'));
 const scenarios=JSON.parse(read(folder+'/scenario-checklist.json'));
 const scenarioSource=read(directory+'/executor-acceptance-fixtures.json'),originalCases=JSON.parse(scenarioSource).cases;
 must(scenarios.source_sha256===digest(scenarioSource)&&scenarios.cases.length===16&&new Set(scenarios.cases.map(c=>c.id)).size===16,'SCENARIO_INVENTORY_DRIFT');
 for(const c of scenarios.cases){const source=originalCases.find(x=>x.id===c.id);must(source&&c.actor===source.actor&&c.category===source.category&&c.status==='NOT_EXECUTED_NOT_INCLUDED_IN_CATALOGUE_CANDIDATE'&&c.preconditions.length>=4&&c.fail_criteria.length>=3&&isDeepStrictEqual(c.steps,source.steps)&&isDeepStrictEqual(c.pass_criteria,source.expect),'SCENARIO_CRITERIA_DRIFT');}
 const contract=buildContract(),objects=JSON.parse(read(directory+'/object-manifest.json')),dependent=JSON.parse(read(directory+'/dependent-objects.json'));
 must(isDeepStrictEqual(manifest.affected,{tables:contract.tables.map(t=>t.name),routines:contract.routines.map(r=>r.signature),sequences:objects.sequences,policies:objects.permissions.map(p=>({table:p.table,policy:p.policy})),default_creators:contract.creators,schema_acl_objects:['private','public','api','extensions'],extension_function_acl_only:'extensions.digest(bytea,text)',dependent_indexes:dependent.indexes,dependent_types:dependent.types,toast:'Implicit table-owner effects; exact auxiliary names require future permitted read-only inventory, not guessed offline'}),'AFFECTED_OBJECT_INVENTORY_DRIFT');
 must(isDeepStrictEqual(spec,JSON.parse(read(folder+'/pilot-spec.json'))),'SPEC_DRIFT');
 must(digest(read(folder+'/pilot-spec.json'))===manifest.spec_sha256,'SPEC_PIN_DRIFT');
 const sourceFiles=['default-function-privileges.sql.draft','20261106120000_owner_executor_foundation.sql.draft','foundation_assertions.sql.draft'];
 const prior=JSON.parse(read(directory+'/accelerated-review/change-inventory.json')).drafts;
 for(const f of sourceFiles)must(digest(read(directory+'/'+f))===manifest.originals[f]&&manifest.originals[f]===prior.find(p=>p.file===f)?.sha256,'ORIGINAL_DRAFT_DRIFT');
 must(manifest.revision===digest(JSON.stringify({spec,hashes:manifest.originals})),'REVISION_DRIFT');
 const sql=read(arg('--candidate',folder+'/LOCAL-TEST-ONLY.catalogue-pilot.sql'));
 const {parser}=await loadParser('pg18');const syntax18=validateSql(sql,parser);
 const ast=parser.parseSync(sql).stmts;
 const tx=ast.map(s=>s.stmt.TransactionStmt).filter(Boolean);
 must(tx.length===2&&tx[0].kind==='TRANS_STMT_BEGIN'&&tx[1].kind==='TRANS_STMT_ROLLBACK'&&ast[0].stmt.TransactionStmt&&ast.at(-1).stmt.TransactionStmt,'TRANSACTION_BOUNDARY');
 const actual=statements(sql);
 must(actual[0].join(' ')==='begin'&&actual.at(-1).join(' ')==='rollback','INCOMPLETE_ROLLBACK');
 const prefix=['set local search_path = pg_catalog',"set local lock_timeout = '3s'","set local statement_timeout = '30s'"];
 prefix.forEach((s,i)=>must(actual[i+1].join(' ')===s,'TIMEOUT_OR_SEARCH_PATH'));
 const body=ast[4].stmt.DoStmt?.args.map(x=>x.DefElem).find(x=>x.defname==='as')?.arg.String.sval;
 must(body&&actual[4][0]==='do','MISSING_APPROVAL_GATE');
 // Entire independently specified gate, not substring tests or trusting generator output.
 const expected=`BEGIN
 IF current_database() IS DISTINCT FROM 'gymforce_pg18_test' OR inet_server_addr() IS DISTINCT FROM '127.0.0.1'::inet
 OR inet_server_port() IS DISTINCT FROM 55432 OR current_user IS DISTINCT FROM 'postgres' OR session_user IS DISTINCT FROM 'postgres'
 OR NOT COALESCE((SELECT rolsuper FROM pg_catalog.pg_roles WHERE rolname=current_user),false)
 OR current_setting('server_version_num')::integer / 10000 <> 18
 OR current_setting('gymforce.test_cluster_marker',true) IS DISTINCT FROM 'f497fabb-a12f-4068-b745-8b0729279276'
 OR (pg_catalog.pg_control_system()).system_identifier::text IS DISTINCT FROM '7704603813616068820'
 OR lower(rtrim(replace(current_setting('data_directory'),E'\\\\','/'),'/')) IS DISTINCT FROM 'c:/users/banco-sual/appdata/local/gymforce-pg18-test/data'
 THEN RAISE EXCEPTION 'LOCAL-TEST-ONLY identity refusal'; END IF;
 IF current_setting('gymforce.pilot.approved_revision',true) IS DISTINCT FROM '${manifest.revision}'
 OR current_setting('gymforce.pilot.backup_verified',true) IS DISTINCT FROM 'true'
 OR current_setting('gymforce.pilot.maintenance_approved',true) IS DISTINCT FROM 'true'
 THEN RAISE EXCEPTION 'LOCAL-TEST-ONLY approval or recovery evidence missing'; END IF;
 IF EXISTS (SELECT 1 FROM pg_catalog.pg_stat_activity WHERE datname=current_database() AND pid<>pg_backend_pid() AND backend_type='client backend')
 THEN RAISE EXCEPTION 'LOCAL-TEST-ONLY requires exclusive client maintenance window'; END IF;
END;`;
 must(isDeepStrictEqual(tokens(body),tokens(expected)),'IDENTITY_OR_APPROVAL_GATE_DRIFT');
 const payload=sourceFiles.slice(0,2).flatMap(f=>statements(read(directory+'/'+f)).slice(2,-1));
 must(actual.length===payload.length+6,'UNEXPECTED_SCHEMA_MUTATION');
 payload.forEach((s,i)=>must(isDeepStrictEqual(actual[i+5],s),'PAYLOAD_OR_PRIVILEGE_DRIFT'));
 must(digest(sql)===manifest.candidate_sha256,'CANDIDATE_PIN_DRIFT');
 const {parser:p17}=await loadParser('pg17');const syntax17=validateSql(sql,p17,{procedural:false});
 if(arg('--approval'))verifyApproval(JSON.parse(read(arg('--approval'))),manifest.revision);
 if(arg('--outcomes'))verifyOutcome(JSON.parse(read(arg('--outcomes'))));
 if(process.argv.includes('--write-report')){
  fs.mkdirSync(folder+'/local',{recursive:true});
  fs.writeFileSync(folder+'/local/syntax-results.json',JSON.stringify({scope:'OFFLINE ONLY',pg18:syntax18,pg17:syntax17,candidate_sha256:digest(sql),execution_ready:false},null,2)+'\n');
 }
 console.log('PASS: OFFLINE candidate/source/boundary/gate checks only. Execution NOT authorized; recovery and runtime remain unverified.');
}catch(e){console.error('REFUSED: '+(/^[A-Z_]+$/.test(e.message)?e.message:'INVALID_OFFLINE_EVIDENCE'));process.exitCode=e.exit??2;}
