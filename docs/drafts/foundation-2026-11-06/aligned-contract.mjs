// Draft-only derived catalog contract. Original migration/source contract stays intact.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {buildContract,directory,read,canonical} from './source-contract.mjs';
import {verifySemanticEvidence} from './review-semantic-alignment.mjs';
import {typedTextDefault,typedRoutineDefaults} from './approved-text-casts.mjs';
import {checkCandidate,indexCandidate} from './deparser-candidates.mjs';
import {loadParser} from './offline-parser.mjs';
const {parser}=await loadParser('pg18');
const classes={text:'text_ops',uuid:'uuid_ops',date:'date_ops',bigint:'int8_ops','timestamp with time zone':'timestamptz_ops'};
export function buildAlignedContract(){
 verifySemanticEvidence();
 const c=buildContract(),evidence=JSON.parse(read(path.join(directory,'semantic-alignment/source-candidates.json'))).rows;
 const exclusion=JSON.parse(read(path.join(directory,'semantic-alignment/classification.json'))).find(r=>r.kind==='exclusion');
 for(const t of c.tables){const columns=Object.fromEntries(t.columns.map(col=>[col.name,col.type]));
  for(const col of t.columns)col.catalog_default=typedTextDefault(col.default,col.type);
  for(const k of t.constraints){
   k.catalog_definition=k.definition;k.no_inherit=k.kind==='c'?false:k.kind==='x'?true:null;
   if(k.kind==='c')k.catalog_definition=checkCandidate(parser.parseSync,k.definition,columns);
   if(k.kind==='x'){
    if(exclusion?.table!==t.name||exclusion.name!==k.name||exclusion.source!==k.definition)throw Error('UNREVIEWED_EXCLUSION');
    k.catalog_definition=exclusion.candidate;
    k.exclusion={method:'gist',opclasses:[{schema:'extensions',name:'gist_uuid_ops',type:'uuid'},{schema:'pg_catalog',name:'range_ops',type:'anyrange'}],operators:['pg_catalog.=(uuid,uuid)','pg_catalog.&&(anyrange,anyrange)']};
   }
   if(['c','x'].includes(k.kind)){
    const observed=evidence.find(e=>e.table===t.name&&e.name===k.name);
    if(!observed||observed.source!==k.definition||(k.kind==='c'&&observed.candidate!==k.catalog_definition))throw Error('UNVERIFIED_CONSTRAINT_CANDIDATE');
   }
  }
 }
 for(const i of c.indexes){const t=c.tables.find(t=>t.name===i.parent),columns=Object.fromEntries(t.columns.map(col=>[col.name,col.type]));
  i.catalog_definition=indexCandidate(parser.parseSync,i.definition,columns);
  const observed=evidence.find(e=>e.kind==='index'&&e.name===i.name);
  if(observed?.source!==i.definition||observed.candidate!==i.catalog_definition)throw Error('UNVERIFIED_INDEX_CANDIDATE');
  const n=parser.parseSync(i.definition).stmts[0].stmt.IndexStmt;
  i.keys=n.indexParams.map(({IndexElem:k},position)=>{
   const column=k.name??k.expr?.ColumnRef?.fields?.[0]?.String?.sval??'',type=column?columns[column]:'text';
   if(!classes[type])throw Error('UNREVIEWED_KEY_TYPE');
   return {position:position+1,column,type,opclass:classes[type],options:k.ordering==='SORTBY_DESC'?3:0,collation:type==='text'?'pg_catalog."default"':null};
  });
 }
 for(const r of c.routines)r.catalog_argument_defaults=typedRoutineDefaults(r);
 c.catalog_alignment={source:'Original contract preserved with separately verified catalog expectations',constraints:110,explicit_indexes:28,index_keys:40,columns:149,provider:'native_pg18_only'};
 if(c.tables.reduce((n,t)=>n+t.constraints.length,0)!==110||c.indexes.flatMap(i=>i.keys).length!==40)throw Error('ALIGNMENT_INVENTORY_DRIFT');
 // Re-tokenization is whitespace/case only; unknown transforms are never used.
 if(c.tables.some(t=>t.constraints.some(k=>canonical(k.catalog_definition)!==k.catalog_definition)))throw Error('NONCANONICAL_EXPECTATION');
 return c;
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 fs.writeFileSync(path.join(directory,'aligned-schema-contract.json'),JSON.stringify(buildAlignedContract(),null,2)+'\n');
 console.log('Prepared draft aligned contract: 110 constraints, 28 indexes/40 keys, 149 columns. No SQL executed.');
}
