// Evidence verifier only. Never grants execution approval or contacts a database.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {directory,read,buildContract,digest} from './source-contract.mjs';
const folder=path.join(directory,'semantic-alignment');
export function parseBooleanCsv(text,ids,flags){
 // These exports allow identifiers/booleans only, no quoted/free-form fields.
 const lines=text.replace(/^\uFEFF/,'').trimEnd().split(/\r?\n/),head=lines.shift().split(',');
 if(head.join('|')!==[...ids,...flags].join('|'))throw Error('OUTPUT_FIELD_ALLOWLIST');
 return lines.map(line=>{const cells=line.split(',');if(cells.length!==head.length)throw Error('CSV_SHAPE');
  const row=Object.fromEntries(head.map((h,i)=>[h,cells[i]]));
  if(!ids.every(k=>(k==='key_position'?/^[1-9][0-9]*$/:/^[a-z_][a-z_0-9.]*$/).test(row[k]))||!flags.every(k=>['t','f'].includes(row[k])))throw Error('INVALID_SAFE_FIELD');return row;});
}
export function verifyRows(rows,expected,ids,flags){
 const key=r=>ids.map(k=>r[k]).join('|');
 if(rows.length!==expected.length||new Set(rows.map(key)).size!==expected.length||new Set(expected.map(key)).size!==expected.length)throw Error('OBJECT_COUNT_OR_DUPLICATE');
 const want=new Set(expected.map(key));if(rows.some(r=>!want.has(key(r))))throw Error('UNEXPECTED_OBJECT');
 if(rows.some(r=>flags.some(k=>r[k]!=='t')))throw Error('UNRESOLVED_DEFINITION');
}
export function verifySemanticEvidence(){
 const c=buildContract(),cs=c.tables.flatMap(t=>t.constraints.filter(k=>k.kind==='c').map(k=>({table_name:t.name,object_name:k.name}))),xs=c.tables.flatMap(t=>t.constraints.filter(k=>k.kind==='x').map(k=>({object_name:k.name})));
 const flags=['identity_exists','structural_flags_match','approved_candidate_matches'];
 const cases=[['20-observed.csv',cs,['table_name','object_name'],flags],['21-observed.csv',c.indexes.map(i=>({table_name:i.parent,object_name:i.name})),['table_name','object_name'],flags],['23-observed.csv',xs,['object_name'],['core_flags_match','exclusion_is_non_inheritable','default_opclass_omission_candidate_matches','uuid_opclass_matches','range_opclass_matches','operators_match','backing_index_matches']]];
 cases.push(['24-observed.csv',JSON.parse(read(path.join(folder,'index-key-expectations.json'))),['index_name','key_position'],['index_flags_match','key_identity_matches','key_type_matches','default_operator_class_matches','key_order_nulls_match','collation_matches']]);
 for(const [file,expected,ids,cols] of cases)verifyRows(parseBooleanCsv(read(path.join(folder,file)),ids,cols),expected,ids,cols);
 const pins=JSON.parse(read(path.join(folder,'evidence-pins.json')));
 for(const [file,hash] of Object.entries(pins))if(digest(read(path.join(directory,file)))!==hash)throw Error('EVIDENCE_OR_TOOL_DRIFT');
 return {resolved_check_definitions:cs.length,resolved_exclusion_definitions:xs.length,resolved_explicit_indexes:c.indexes.length,remaining_constraint_mismatches:0,remaining_index_mismatches:0,scope:'Recorded read-only definition evidence only; NOT execution readiness'};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{const result=verifySemanticEvidence();fs.writeFileSync(path.join(folder,'findings.json'),JSON.stringify(result,null,2)+'\n');console.log('PASS: 52 CHECK/exclusion and 28 explicit-index definitions aligned; no unresolved definitions. NOT execution approval.');}
 catch(e){console.error('REFUSED: '+(/^[A-Z_]+$/.test(e.message)?e.message:'INVALID_EVIDENCE'));process.exitCode=2;}
}
