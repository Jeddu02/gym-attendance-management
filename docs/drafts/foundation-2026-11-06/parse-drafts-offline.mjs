// Offline SQL and full-boundary PL/pgSQL checks. Never executes SQL.
import fs from 'node:fs';
import path from 'node:path';
import {directory,read,digest} from './source-contract.mjs';
import {loadParser,validateSql} from './offline-parser.mjs';
const results=[];
try{
 for(const alias of ['pg18','pg17']){
  const {parser,package_version,grammar}=await loadParser(alias);
  for(const file of ['20261106120000_owner_executor_foundation.sql.draft','foundation_assertions.sql.draft','default-function-privileges.sql.draft']){
   const sql=read(path.join(directory,file)),r={parser:alias,package_version,grammar,file,sha256:digest(sql),sql:false,plpgsql:alias==='pg18'?false:'UNAVAILABLE'};
   try{Object.assign(r,validateSql(sql,parser,{procedural:alias==='pg18'}));r.sql=true;if(alias==='pg18')r.plpgsql=true;else r.limitation='PG17 binding SQL-only; PG18 checks every procedural body; no PG17 procedural/runtime certification';}
   catch{r.failure='SQL_OR_PROCEDURAL_REFUSAL';process.exitCode=2;}
   results.push(r);
  }
 }
 const target=path.join(directory,'accelerated-review');fs.mkdirSync(target,{recursive:true});
 fs.writeFileSync(path.join(target,'parser-results.json'),JSON.stringify(results,null,2)+'\n');
 for(const r of results)console.log(`${r.parser} ${r.file}: SQL ${r.sql?'PASS':'REFUSED'}, PL/pgSQL ${r.plpgsql}; ${r.procedural_bodies_checked??0}/${r.procedural_body_count??'?'} bodies checked`);
}catch{console.error('REFUSED: OFFLINE_PARSER_SETUP_OR_COVERAGE');process.exitCode=2;}
