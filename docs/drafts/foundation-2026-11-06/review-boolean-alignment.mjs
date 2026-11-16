// Filesystem-only evidence summary. No SQL execution, baseline refresh or connections.
import fs from 'node:fs';
import path from 'node:path';
import {directory,read,digest} from './source-contract.mjs';
import {verifySemanticEvidence} from './review-semantic-alignment.mjs';
const folder=path.join(directory,'boolean-alignment');
function csv(file) {
 const s=read(path.join(folder,file)).replace(/^\uFEFF/,'');const out=[];let row=[],field='',quoted=false;
 for(let i=0;i<s.length;i++){
  const ch=s[i];if(ch==='"'){if(quoted&&s[i+1]==='"'){field+='"';i++;}else quoted=!quoted;}
  else if(!quoted&&ch===','){row.push(field);field='';}
  else if(!quoted&&ch==='\n'){row.push(field.replace(/\r$/,''));out.push(row);row=[];field='';}else field+=ch;
 }
 if(quoted||field||row.length)throw Error('INVALID_CSV');
 const h=out.shift();if(!h||out.some(r=>r.length!==h.length))throw Error('CSV_SHAPE');
 return out.map(r=>Object.fromEntries(h.map((k,i)=>[k,r[i]])));
}
function must(ok,code){if(!ok)throw Error(code);}
const specs=[
 ['12-observed.csv',25,['routine_name'],['identity_exists','identity_shape_matches','argument_names_match','argument_types_match','argument_modes_match','result_matches','security_metadata_matches','search_path_matches']],
 ...[['p',22],['u',6],['f',30],['c',51],['x',1]].map(([k,n])=>['13-'+k+'-observed.csv',n,['table_name','constraint_name'],['identity_exists','structural_flags_match','exact_source_definition_matches']]),
 ['14-observed.csv',28,['index_name'],['identity_exists','structural_flags_match','exact_source_definition_matches']],
 ['15-observed.csv',149,['table_name','column_name'],['identity_exists','generated_identity_matches','exact_source_expression_matches']],
 ['16-observed.csv',13,['table_name','trigger_name'],['identity_exists','enabled_matches','exact_source_definition_matches']],
 ['17-observed.csv',25,['routine_name'],['identity_exists','exact_source_defaults_match']],
 ['18-observed.csv',14,['category','object_name'],['identity_exists','approved_text_cast_matches']],
 ['19-observed.csv',25,['routine_name'],['identity_exists','approved_source_body_matches']]
];
try{
 const summary=[];
 for(const [file,n,ids,flags] of specs){
  const rows=csv(file);must(rows.length===n,'OBSERVATION_COUNT');
  must(rows.every(r=>Object.keys(r).join('|')===[...ids,...flags].join('|')),'OUTPUT_FIELD_ALLOWLIST');
  must(rows.every(r=>flags.every(f=>['t','f'].includes(r[f]))),'INVALID_BOOLEAN');
  must(new Set(rows.map(r=>ids.map(i=>r[i]).join('|'))).size===n,'DUPLICATE_OBJECT');
  must(rows.every(r=>r.identity_exists==='t'),'MISSING_OBJECT');
  summary.push({file,rows:n,flags:Object.fromEntries(flags.map(f=>[f,{match:rows.filter(r=>r[f]==='t').length,total:n}])),
   unresolved:rows.filter(r=>flags.some(f=>r[f]==='f')).map(r=>Object.fromEntries(ids.map(i=>[i,r[i]])))});
 }
 const files=fs.readdirSync(folder).filter(f=>f.endsWith('.sql')).sort();
 must(files.length===12,'QUERY_COUNT');
 const queryHashes=files.map(file=>{
  const sql=read(path.join(folder,file));
  must(sql.includes('BEGIN READ ONLY;')&&sql.endsWith('ROLLBACK;\n')&&sql.includes("system_identifier::text='7704603813616068820'"),'READ_ONLY_IDENTITY_GUARD');
  return {file,sha256:digest(sql)};
 });
 const rawUnresolvedConstraints=summary.filter(s=>s.file.startsWith('13-')).reduce((n,s)=>n+s.rows-s.flags.exact_source_definition_matches.match,0);
 const indexSummary=summary.find(s=>s.file==='14-observed.csv');
 const rawUnresolvedIndexes=indexSummary.rows-indexSummary.flags.exact_source_definition_matches.match;
 const semantic=verifySemanticEvidence();
 const unresolvedConstraints=semantic.remaining_constraint_mismatches;
 const unresolvedIndexes=semantic.remaining_index_mismatches;
 const castRows=csv('18-observed.csv');
 // Every historical false expression needs its own successful cast evidence.
 for(const [file,ids,flag,category] of [['15-observed.csv',['table_name','column_name'],'exact_source_expression_matches','column'],['17-observed.csv',['routine_name'],'exact_source_defaults_match','routine']]){
  for(const row of csv(file).filter(r=>r[flag]==='f'))must(castRows.some(c=>c.category===category&&c.object_name===ids.map(i=>row[i]).join('.')&&c.identity_exists==='t'&&c.approved_text_cast_matches==='t'),'UNRESOLVED_CAST');
 }
 for(const s of summary)for(const [flag,count] of Object.entries(s.flags)){
  if(flag==='exact_source_definition_matches'&&['13-c-observed.csv','13-x-observed.csv','14-observed.csv'].includes(s.file))continue;
  if(flag==='exact_source_expression_matches'&&s.file==='15-observed.csv')continue;
  if(flag==='exact_source_defaults_match'&&s.file==='17-observed.csv')continue;
  must(count.match===count.total,'UNRESOLVED_METADATA');
 }
 const findings={verdict:'NOT READY',accepted_boolean_queries:12,summary,queryHashes,
  aligned_columns_including_approved_text_casts:149,aligned_routine_defaults_including_approved_text_casts:25,
  raw_source_constraint_mismatches:rawUnresolvedConstraints,raw_source_index_mismatches:rawUnresolvedIndexes,
  semantic_alignment:semantic,unresolved_constraint_definitions:unresolvedConstraints,unresolved_explicit_index_definitions:unresolvedIndexes,
  limitations:['False textual comparisons alone prove neither corruption nor equivalence; approved candidate evidence is separate',
    'MD5 body pin matches are legacy fingerprints, not adversarial tamper-proof evidence',
    'Independent read-only transactions are not an atomic whole-database snapshot',
    'SQL grammar parsing performed separately; PL/pgSQL compilation and runtime executor acceptance remain incomplete']};
 fs.writeFileSync(path.join(folder,'findings.json'),JSON.stringify(findings,null,2)+'\n');
 console.log('PASS: definition evidence aligned, including 52 CHECK/exclusion and 28 explicit indexes. Execution approval and restricted-executor runtime acceptance remain separate.');
 // Evidence generation is not acceptance. Explicit gating must fail nonzero.
 if(process.argv.includes('--require-aligned')&&(unresolvedConstraints||unresolvedIndexes))process.exitCode=2;
}catch(e){console.error('REFUSED: '+(/^[A-Z_]+$/.test(e.message)?e.message:'INVALID_EVIDENCE'));process.exitCode=1;}
