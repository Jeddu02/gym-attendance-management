// Source-only metadata expectations. Never connects to PostgreSQL.
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import {directory,root,read,buildContract} from './source-contract.mjs';
const require=createRequire(import.meta.url),p=require(path.join(root,'.cache/foundation-parser/node_modules/pg18'));await p.loadModule();
const c=buildContract(),q=s=>"'"+s.replaceAll("'","''")+"'",rows=[];
const classes={text:'text_ops',uuid:'uuid_ops',date:'date_ops',bigint:'int8_ops','timestamp with time zone':'timestamptz_ops'};
for(const i of c.indexes){const n=p.parseSync(i.definition).stmts[0].stmt.IndexStmt,t=c.tables.find(t=>t.name===i.parent);
 for(const [pos,{IndexElem:k}] of n.indexParams.entries()){
  const column=k.name??k.expr?.ColumnRef?.fields?.[0]?.String?.sval??'',type=column?t.columns.find(c=>c.name===column).type:'text';
  if(!classes[type])throw Error('UNKNOWN_INDEX_KEY_TYPE');
  rows.push([q(i.name),q(i.parent),String(pos+1),q(column),q(type),q(classes[type]),String(k.ordering==='SORTBY_DESC'?3:0),String(n.unique??false),String(n.indexParams.length)]);
 }
}
const guard=read(path.join(directory,'minimal-catalog/01-identity-counts.sql')).split('SELECT current_database() database')[0];
const sql=guard+`WITH expected(index_name,parent_name,key_position,column_name,type_name,opclass_name,options,is_unique,key_count) AS (VALUES
${rows.map(r=>'('+r.join(',')+')').join(',\n')})
SELECT e.index_name,e.key_position,
 COALESCE(i.indrelid=to_regclass(e.parent_name) AND i.indisvalid AND i.indisready AND i.indislive AND i.indisunique=e.is_unique AND NOT i.indisprimary AND NOT i.indisexclusion AND i.indimmediate AND NOT i.indnullsnotdistinct AND i.indnkeyatts=e.key_count AND i.indnatts=e.key_count,false) index_flags_match,
 COALESCE(i.indkey[e.key_position-1]=CASE WHEN e.column_name='' THEN 0 ELSE a.attnum END,false) key_identity_matches,
 COALESCE(ka.atttypid=to_regtype(e.type_name),false) key_type_matches,
 COALESCE(o.opcname=e.opclass_name AND ns.nspname='pg_catalog' AND am.amname='btree' AND o.opcdefault,false) default_operator_class_matches,
 COALESCE(i.indoption[e.key_position-1]=e.options,false) key_order_nulls_match,
 COALESCE(i.indcollation[e.key_position-1]=CASE WHEN e.type_name='text' THEN 'pg_catalog."default"'::regcollation::oid ELSE 0::oid END,false) collation_matches
FROM expected e LEFT JOIN pg_index i ON i.indexrelid=to_regclass(e.index_name)
LEFT JOIN pg_attribute a ON a.attrelid=i.indrelid AND a.attname=e.column_name AND a.attnum>0 AND NOT a.attisdropped
LEFT JOIN pg_attribute ka ON ka.attrelid=i.indexrelid AND ka.attnum=e.key_position AND NOT ka.attisdropped
LEFT JOIN pg_opclass o ON o.oid=i.indclass[e.key_position-1]
LEFT JOIN pg_namespace ns ON ns.oid=o.opcnamespace
LEFT JOIN pg_am am ON am.oid=o.opcmethod
ORDER BY 1,2;
ROLLBACK;
`;
fs.writeFileSync(path.join(directory,'semantic-alignment/24-index-metadata.sql'),sql);
fs.writeFileSync(path.join(directory,'semantic-alignment/index-key-expectations.json'),JSON.stringify(rows.map(r=>({index_name:r[0].slice(1,-1),key_position:r[2]})),null,2)+'\n');
console.log('Prepared fixed metadata comparisons for '+rows.length+' explicit-index keys. No SQL executed.');
