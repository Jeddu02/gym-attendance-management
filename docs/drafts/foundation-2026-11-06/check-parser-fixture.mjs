// Independent process entrypoint; synthetic fixtures only, never SQL execution.
import {directory,read} from './source-contract.mjs';
import {loadParser,validateSql} from './offline-parser.mjs';
try{
 const fixture=JSON.parse(read(directory+'/parser-fixtures.json')).find(x=>x.id===process.argv[2]);
 if(!fixture)throw Error('UNKNOWN_FIXTURE');
 const {parser}=await loadParser('pg18');
 const r=validateSql(fixture.sql,parser);
 if(fixture.bodies!==undefined&&r.procedural_bodies_checked!==fixture.bodies)throw Error('SKIPPED_BODY');
 console.log('PASS: COMPLETE_PROCEDURAL_PARSE');
}catch{console.error('REFUSED: PROCEDURAL_SQL_OR_COVERAGE');process.exitCode=2;}
