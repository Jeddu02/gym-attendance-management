// Validate declarative test design only. Does NOT execute any case.
import {directory,read,buildContract} from './source-contract.mjs';
try{
 const f=JSON.parse(read(directory+'/executor-acceptance-fixtures.json')),c=buildContract();
 if(JSON.stringify(f.categories)!==JSON.stringify(['nested_rpc','triggers','row_locks','rls','role_escalation','rollback','sequences','concurrency']))throw Error('CATEGORY_ALLOWLIST');
 if(f.status!=='DRAFT_ONLY_NOT_AUTHORIZED_TO_EXECUTE'||f.autorun!==false||f.cases.length!==16||new Set(f.cases.map(x=>x.id)).size!==16)throw Error('FIXTURE_CONTAINMENT');
 if(f.target.database!=='gymforce_pg18_test'||f.target.host!=='127.0.0.1'||f.target.port!==55432||f.target.system_identifier!=='7704603813616068820'||f.target.marker!=='f497fabb-a12f-4068-b745-8b0729279276'||f.target.data_directory!=='C:\\Users\\Banco-Sual\\AppData\\Local\\GYMFORCE-PG18-TEST\\data')throw Error('FIXTURE_TARGET');
 const names=new Set(c.routines.map(r=>r.name));
 for(const category of f.categories)if(f.cases.filter(x=>x.category===category).length!==2)throw Error('MISSING_CATEGORY_CASE');
 for(const x of f.cases)if(!f.categories.includes(x.category)||!x.steps.length||!x.expect.length||x.routines.some(n=>!names.has(n)))throw Error('INVALID_CASE_OR_ROUTINE');
 if(f.fixture_design.activation_date!==null||f.fixture_design.expiry_date!==null||f.fixture_design.confirmed_purchase_status!=='pending_activation'||!f.fixture_design.collision_check_required||!f.fixture_design.existing_records_must_not_be_reused)throw Error('LIFECYCLE_OR_ISOLATION');
 console.log('PASS: 16 declarative executor scenarios across all eight categories. NOT EXECUTED.');
}catch{console.error('REFUSED: EXECUTOR_FIXTURE_DESIGN');process.exitCode=1;}
