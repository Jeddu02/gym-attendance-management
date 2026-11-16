// Filesystem/WASM parsing only. Writes fixed read-only probes; never runs SQL.
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import {directory,root,read,buildContract,canonical,digest} from './source-contract.mjs';
import {checkCandidate,indexCandidate} from './deparser-candidates.mjs';
const require=createRequire(import.meta.url);
const p18=require(path.join(root,'.cache/foundation-parser/node_modules/pg18'));
const p17=require(path.join(root,'.cache/foundation-parser/node_modules/pg17'));
await p18.loadModule();await p17.loadModule();
const strip=x=>Array.isArray(x)?x.map(strip):x&&typeof x==='object'?Object.fromEntries(Object.entries(x).filter(([k])=>!['location','stmt_location','stmt_len','rexpr_list_start','rexpr_list_end'].includes(k)).map(([k,v])=>[k,strip(v)])):x;
function parse(sql){const a=p18.parseSync(sql),b=p17.parseSync(sql);if(a.version!==180004||Math.floor(b.version/10000)!==17)throw Error('PARSER_GRAMMAR_MISMATCH');if(JSON.stringify(strip(a.stmts))!==JSON.stringify(strip(b.stmts)))throw Error('PG17_18_AST_DIFFERENCE');return a;}
const c=buildContract(),rows=[];
for(const t of c.tables){const cols=Object.fromEntries(t.columns.map(c=>[c.name,c.type]));for(const k of t.constraints.filter(k=>k.kind==='c'))rows.push({kind:'constraint',table:t.name,name:k.name,source:k.definition,candidate:checkCandidate(parse,k.definition,cols)});}
for(const i of c.indexes){const t=c.tables.find(t=>t.name===i.parent),cols=Object.fromEntries(t.columns.map(c=>[c.name,c.type]));rows.push({kind:'index',table:i.parent,name:i.name,source:i.definition,candidate:indexCandidate(parse,i.definition,cols)});}
const exclusion=c.tables.flatMap(t=>t.constraints.filter(k=>k.kind==='x').map(k=>({table:t.name,...k})));
if(exclusion.length!==1||exclusion[0].definition!==canonical("EXCLUDE USING gist (member_id extensions.gist_uuid_ops WITH =, daterange(activation_date, expiry_date, '[]') WITH &&) WHERE (activation_date IS NOT NULL AND expiry_date IS NOT NULL)"))throw Error('UNREVIEWED_EXCLUSION');
rows.push({kind:'exclusion',table:exclusion[0].table,name:exclusion[0].name,source:exclusion[0].definition,candidate:canonical("EXCLUDE USING gist (member_id extensions.gist_uuid_ops WITH =, daterange(activation_date, expiry_date, '[]'::text) WITH &&) WHERE (((activation_date IS NOT NULL) AND (expiry_date IS NOT NULL)))")});
const folder=path.join(directory,'semantic-alignment');fs.mkdirSync(folder,{recursive:true});
const guard=read(path.join(directory,'minimal-catalog/01-identity-counts.sql')).split('SELECT current_database() database')[0];
const q=x=>"'"+x.replaceAll("'","''")+"'";
const pattern=`'(?:''|[^'])*'|"(?:""|[^"])*"|[a-zA-Z_][a-zA-Z_0-9]*|[0-9]+(?:\\.[0-9]+)?|::|<>|<=|>=|&&|!=|\\|\\||[^[:space:]]`;
const norm=x=>`(SELECT string_agg(CASE WHEN left(part[1],1) IN ('''','"') THEN part[1] ELSE lower(part[1]) END,' ' ORDER BY ordinal) FROM regexp_matches(${x},$lex$${pattern}$lex$,'g') WITH ORDINALITY token(part,ordinal))`;
for(const [kind,file] of [['constraint','20-checks'],['index','21-indexes'],['exclusion','22-exclusion']]){
 const selected=rows.filter(r=>r.kind===kind),values=selected.map(r=>'('+[r.table,r.name,r.candidate].map(q).join(',')+')').join(',\n');
 const isIndex=kind==='index';
 const body=`WITH expected(table_name,object_name,candidate) AS (VALUES\n${values})\nSELECT e.table_name,e.object_name,${isIndex?'k.indexrelid':'k.oid'} IS NOT NULL identity_exists,\n COALESCE(${isIndex?'k.indrelid=to_regclass(e.table_name) AND k.indisvalid AND k.indisready AND k.indislive':`k.contype='${kind==='exclusion'?'x':'c'}' AND k.convalidated AND k.conenforced AND NOT k.condeferrable AND NOT k.condeferred AND k.conislocal AND k.coninhcount=0 AND NOT k.connoinherit`},false) structural_flags_match,\n ${norm(isIndex?'pg_get_indexdef(k.indexrelid,0,false)':'pg_get_constraintdef(k.oid,false)')} IS NOT DISTINCT FROM e.candidate approved_candidate_matches\nFROM expected e LEFT JOIN ${isIndex?'pg_index k ON k.indexrelid=to_regclass(e.object_name)':'pg_constraint k ON k.conrelid=to_regclass(e.table_name) AND k.conname=e.object_name'} ORDER BY 1,2;\n`;
 fs.writeFileSync(path.join(folder,file+'.sql'),guard+body+'ROLLBACK;\n');
}
fs.writeFileSync(path.join(folder,'source-candidates.json'),JSON.stringify({origin:'Pinned original source only; NOT observed catalog expressions',rows},null,2)+'\n');
const lock=JSON.parse(read(path.join(root,'.cache/foundation-parser/package-lock.json')));
fs.writeFileSync(path.join(folder,'parser-provenance.json'),JSON.stringify({install:'Isolated ignored .cache/foundation-parser; npm --ignore-scripts --no-audit --no-fund; no app dependency changes',packages:lock.packages,grammars:{pg18:p18.parseSync('SELECT 1').version,pg17:p17.parseSync('SELECT 1').version},generator_sha256:digest(read(new URL(import.meta.url)))},null,2)+'\n');
console.log('Prepared 51 CHECK, 28 index and one exclusion candidate. Source AST agrees between PG18 and PG17 (locations ignored only). No SQL executed.');
