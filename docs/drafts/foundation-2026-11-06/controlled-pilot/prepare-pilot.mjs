// Filesystem/offline parser only. Never starts psql, contacts PostgreSQL or promotes originals.
import fs from 'node:fs';
import path from 'node:path';
import {directory,read,digest,buildContract} from '../source-contract.mjs';
import {loadParser} from '../offline-parser.mjs';
const folder=path.join(directory,'controlled-pilot'),spec=JSON.parse(read(folder+'/pilot-spec.json'));
const {parser}=await loadParser('pg18');
const prior=JSON.parse(read(directory+'/accelerated-review/change-inventory.json')).drafts;
const originals=['default-function-privileges.sql.draft','20261106120000_owner_executor_foundation.sql.draft','foundation_assertions.sql.draft'];
const hashes=Object.fromEntries(originals.map(file=>{const sql=read(directory+'/'+file),sha=digest(sql);if(prior.find(r=>r.file===file)?.sha256!==sha)throw Error('ORIGINAL_DRAFT_DRIFT');return [file,sha];}));
const revision=digest(JSON.stringify({spec,hashes}));
function payload(file){
 const sql=read(directory+'/'+file),bytes=Buffer.from(sql),ast=parser.parseSync(sql).stmts;
 if(ast[0].stmt.TransactionStmt?.kind!=='TRANS_STMT_BEGIN'||ast.at(-1).stmt.TransactionStmt?.kind!=='TRANS_STMT_COMMIT'||!ast[1].stmt.DoStmt)throw Error('UNEXPECTED_SOURCE_BOUNDARIES');
 const blocker=ast[1].stmt.DoStmt.args.map(x=>x.DefElem).find(x=>x.defname==='as')?.arg.String.sval;
 if(!blocker?.includes("RAISE EXCEPTION 'DRAFT ONLY:"))throw Error('SOURCE_BLOCKER_MISSING');
 return ast.slice(2,-1).map(s=>{
  if(s.stmt.TransactionStmt)throw Error('EMBEDDED_SOURCE_TRANSACTION');
  const start=s.stmt_location??0,end=s.stmt_len?start+s.stmt_len:bytes.length;
  return bytes.subarray(start,end).toString().trim()+';';
 }).join('\n');
}
const t=spec.target;
const guard=`DO $pilot_gate$
BEGIN
 IF current_database() IS DISTINCT FROM '${t.database}' OR inet_server_addr() IS DISTINCT FROM '${t.host}'::inet
 OR inet_server_port() IS DISTINCT FROM ${t.port} OR current_user IS DISTINCT FROM 'postgres' OR session_user IS DISTINCT FROM 'postgres'
 OR NOT COALESCE((SELECT rolsuper FROM pg_catalog.pg_roles WHERE rolname=current_user),false)
 OR current_setting('server_version_num')::integer / 10000 <> 18
 OR current_setting('gymforce.test_cluster_marker',true) IS DISTINCT FROM '${t.marker}'
 OR (pg_catalog.pg_control_system()).system_identifier::text IS DISTINCT FROM '${t.system_identifier}'
 OR lower(rtrim(replace(current_setting('data_directory'),E'\\\\','/'),'/')) IS DISTINCT FROM 'c:/users/banco-sual/appdata/local/gymforce-pg18-test/data'
 THEN RAISE EXCEPTION 'LOCAL-TEST-ONLY identity refusal'; END IF;
 IF current_setting('gymforce.pilot.approved_revision',true) IS DISTINCT FROM '${revision}'
 OR current_setting('gymforce.pilot.backup_verified',true) IS DISTINCT FROM 'true'
 OR current_setting('gymforce.pilot.maintenance_approved',true) IS DISTINCT FROM 'true'
 THEN RAISE EXCEPTION 'LOCAL-TEST-ONLY approval or recovery evidence missing'; END IF;
 IF EXISTS (SELECT 1 FROM pg_catalog.pg_stat_activity WHERE datname=current_database() AND pid<>pg_backend_pid() AND backend_type='client backend')
 THEN RAISE EXCEPTION 'LOCAL-TEST-ONLY requires exclusive client maintenance window'; END IF;
END;
$pilot_gate$;`;
const candidate=`-- LOCAL-TEST-ONLY CANDIDATE. NOT AUTHORIZED TO RUN. No hosted target or business fixtures.
-- Fresh psql connection; -X -w -v ON_ERROR_STOP=1 mandatory. Approval/recovery gate is deliberate.
BEGIN;
SET LOCAL search_path=pg_catalog;
SET LOCAL lock_timeout='3s';
SET LOCAL statement_timeout='30s';
${guard}
-- Five default corrections and postconditions precede foundation preconditions.
${payload(originals[0])}
-- Exact original foundation payload; only its outer transaction/blocker omitted in this separate copy.
${payload(originals[1])}
ROLLBACK;
`;
fs.writeFileSync(folder+'/LOCAL-TEST-ONLY.catalogue-pilot.sql',candidate);
const dependencies=JSON.parse(read(directory+'/dependent-objects.json'));
fs.writeFileSync(folder+'/candidate-manifest.json',JSON.stringify({revision,spec_sha256:digest(read(folder+'/pilot-spec.json')),originals:hashes,candidate_sha256:digest(candidate),affected:{tables:buildContract().tables.map(t=>t.name),routines:buildContract().routines.map(r=>r.signature),sequences:JSON.parse(read(directory+'/object-manifest.json')).sequences,policies:JSON.parse(read(directory+'/object-manifest.json')).permissions.map(p=>({table:p.table,policy:p.policy})),default_creators:buildContract().creators,schema_acl_objects:['private','public','api','extensions'],extension_function_acl_only:'extensions.digest(bytea,text)',dependent_indexes:dependencies.indexes,dependent_types:dependencies.types,toast:'Implicit table-owner effects; exact auxiliary names require future permitted read-only inventory, not guessed offline'},payload_order:originals.slice(0,2),removed_in_copy_only:['two outer BEGINs','two unconditional draft blockers','two terminal COMMITs'],limitations:['No data-producing executor or concurrency scenarios implemented','Original-baseline post-rollback verifier and executable client remain blocked by recovery/isolation decisions; not prepared']},null,2)+'\n');
console.log('Prepared gated LOCAL-TEST-ONLY catalogue candidate only. Original blocked drafts unchanged. No SQL executed.');
