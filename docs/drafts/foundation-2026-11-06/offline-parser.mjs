// Pure offline parsing. No PostgreSQL client, network, subprocess or body rewriting.
import path from 'node:path';
import {createRequire} from 'node:module';
import {root,read} from './source-contract.mjs';
const require=createRequire(import.meta.url);
export async function loadParser(alias){
 const expected={pg18:{package:'18.1.4',grammar:180004},pg17:{package:'17.8.2',grammar:170007}}[alias];
 if(!expected)throw Error('UNREVIEWED_PARSER');
 const base=path.join(root,'.cache/foundation-parser/node_modules',alias);
 if(JSON.parse(read(path.join(base,'package.json'))).version!==expected.package)throw Error('PARSER_PACKAGE_MISMATCH');
 const parser=require(base);await parser.loadModule();
 if(parser.parseSync('SELECT 1').version!==expected.grammar)throw Error('PARSER_GRAMMAR_MISMATCH');
 return {parser,package_version:expected.package,grammar:expected.grammar};
}
function language(options){return options?.map(x=>x.DefElem).find(x=>x.defname==='language')?.arg?.String?.sval?.toLowerCase();}
export function validateSql(sql,parser,{procedural=true}={}){
 const ast=parser.parseSync(sql),bytes=Buffer.from(sql,'utf8');
 let expected=0,individuallyParsed=0;const boundaries=[];
 for(const [i,s] of ast.stmts.entries()){
  const node=s.stmt,lang=node.DoStmt?language(node.DoStmt.args)??'plpgsql':node.CreateFunctionStmt?language(node.CreateFunctionStmt.options):null;
  if(node.DoStmt&&lang!=='plpgsql')throw Error('UNSUPPORTED_DO_LANGUAGE');
  if(node.CreateFunctionStmt&&!['plpgsql','sql'].includes(lang))throw Error('UNSUPPORTED_ROUTINE_LANGUAGE');
  if(lang!=='plpgsql')continue;
  expected++;
  const start=s.stmt_location??0,end=s.stmt_len?start+s.stmt_len:bytes.length;
  if(start<0||end<=start||end>bytes.length)throw Error('INVALID_STATEMENT_BOUNDARY');
  const original=bytes.subarray(start,end).toString('utf8');
  const standalone=parser.parseSync(original);
  if(standalone.stmts.length!==1||(!standalone.stmts[0].stmt.DoStmt&&!standalone.stmts[0].stmt.CreateFunctionStmt))throw Error('PROCEDURAL_BOUNDARY_DRIFT');
  boundaries.push({statement_index:i,byte_start:start,byte_end:end,language:lang});
  if(procedural){
   if(typeof parser.parsePlPgSQLSync!=='function')throw Error('PROCEDURAL_PARSER_UNAVAILABLE');
   const result=parser.parsePlPgSQLSync(original);
   if(!Array.isArray(result.plpgsql_funcs)||result.plpgsql_funcs.length!==1)throw Error('PROCEDURAL_BODY_SKIPPED');
   individuallyParsed++;
  }
 }
 if(procedural){
  const result=parser.parsePlPgSQLSync(sql);
  if(!Array.isArray(result.plpgsql_funcs)||result.plpgsql_funcs.length!==expected||individuallyParsed!==expected)throw Error('PROCEDURAL_COVERAGE_MISMATCH');
 }
 return {statement_count:ast.stmts.length,procedural_body_count:expected,procedural_bodies_checked:individuallyParsed,boundaries};
}
