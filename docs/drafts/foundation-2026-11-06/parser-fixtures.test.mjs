import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {directory,read} from './source-contract.mjs';
import {loadParser,validateSql} from './offline-parser.mjs';
for(const f of JSON.parse(read(directory+'/parser-fixtures.json')))test('parser native exit: '+f.id,()=>{
 const child=spawnSync(process.execPath,[directory+'/check-parser-fixture.mjs',f.id],{encoding:'utf8',timeout:20000});
 assert.equal(child.status,f.accept?0:2,child.stderr);
 if(!f.accept)assert.match(child.stderr,/REFUSED: PROCEDURAL_SQL_OR_COVERAGE/);
});
test('body-skipping parser response refuses',async()=>{
 const {parser}=await loadParser('pg18');
 const fake={...parser,parsePlPgSQLSync:()=>({plpgsql_funcs:[]})};
 assert.throws(()=>validateSql('DO $$ BEGIN NULL; END $$;',fake),/PROCEDURAL_BODY_SKIPPED/);
});
test('unavailable procedural parser refuses instead of SQL-only fallback',async()=>{
 const {parser}=await loadParser('pg18');
 assert.throws(()=>validateSql('DO $$ BEGIN NULL; END $$;',{...parser,parsePlPgSQLSync:undefined}),/PROCEDURAL_PARSER_UNAVAILABLE/);
});
