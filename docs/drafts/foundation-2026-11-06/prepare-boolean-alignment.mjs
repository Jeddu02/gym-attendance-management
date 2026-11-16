// Filesystem only. Approved source expectations in; fixed comparison SQL out.
// Never connects, executes SQL, installs a parser or removes draft blockers.
import fs from 'node:fs';
import path from 'node:path';
import {directory,read,json,buildContract,canonical} from './source-contract.mjs';
import {typedTextDefault,typedRoutineDefaults} from './approved-text-casts.mjs';
const c=buildContract(),m=json(path.join(directory,'object-manifest.json'));
const target=path.join(directory,'boolean-alignment');fs.mkdirSync(target,{recursive:true});
const guard=read(path.join(directory,'minimal-catalog/01-identity-counts.sql')).split('SELECT current_database() database')[0];
const quote=x=>x===null?'NULL':"'"+String(x).replaceAll("'","''")+"'";
const array=a=>a.length?'ARRAY['+a.map(quote).join(',')+']::text[]':'ARRAY[]::text[]';
const values=rows=>rows.map(r=>'('+r.map(quote).join(',')+')').join(',\n');
// Preserves quoted literals/case, parentheses, casts and operators. No semantic erasure.
const pattern=`'(?:''|[^'])*'|"(?:""|[^"])*"|[a-zA-Z_][a-zA-Z_0-9]*|[0-9]+(?:\\.[0-9]+)?|::|<>|<=|>=|&&|!=|\\|\\||[^[:space:]]`;
const norm=x=>`(SELECT string_agg(CASE WHEN left(part[1],1) IN ('''','"') THEN part[1] ELSE lower(part[1]) END,' ' ORDER BY ordinal) FROM regexp_matches(${x},$lex$${pattern}$lex$,'g') WITH ORDINALITY token(part,ordinal))`;
const write=(name,body)=>fs.writeFileSync(path.join(target,name+'.sql'),guard+body+'\nROLLBACK;\n');
const routineRows=c.routines.map(r=>{
 const baseline=m.routines.find(x=>x.signature===r.signature);
 const modes=r.output_types.length?[...r.input_types.map(()=>'i'),...r.output_types.map(()=>'t')]:[];
 return `(${[r.name,r.signature,r.result,r.volatility,r.parallel,r.language].map(quote).join(',')},${array(r.argument_names)},${array([...r.input_types,...r.output_types])},${array(modes)},${baseline.prosecdef},${r.strict},${r.returns_set},${r.input_types.length},${r.default_count})`;
});
write('12-routine-identities',`WITH expected(name,signature,result,volatility,parallel,language,arg_names,arg_types,arg_modes,definer,strict,returns_set,input_count,default_count) AS (VALUES
${routineRows.join(',\n')})
SELECT e.name routine_name,p.oid IS NOT NULL identity_exists,
 COALESCE(p.prokind='f' AND p.pronargs=e.input_count AND p.pronargdefaults=e.default_count,false) identity_shape_matches,
 COALESCE(COALESCE(p.proargnames,ARRAY[]::text[])=e.arg_names,false) argument_names_match,
 COALESCE((SELECT COALESCE(array_agg(format_type(a.type_oid,NULL) ORDER BY a.ord),ARRAY[]::text[])
 FROM unnest(COALESCE(p.proallargtypes,p.proargtypes::oid[])) WITH ORDINALITY a(type_oid,ord))=e.arg_types,false) argument_types_match,
 COALESCE(COALESCE(p.proargmodes::text[],ARRAY[]::text[])=e.arg_modes,false) argument_modes_match,
 COALESCE(regexp_replace(lower(pg_get_function_result(p.oid)),'[[:space:]]','','g')=regexp_replace(lower(e.result),'[[:space:]]','','g'),false) result_matches,
 COALESCE(p.provolatile::text=e.volatility AND p.proparallel::text=e.parallel AND l.lanname=e.language
 AND p.prosecdef=e.definer AND p.proisstrict=e.strict AND p.proretset=e.returns_set AND NOT p.proleakproof,false) security_metadata_matches,
 COALESCE(p.proconfig=ARRAY['search_path=""']::text[],false) search_path_matches
FROM expected e LEFT JOIN pg_proc p ON p.oid=to_regprocedure(e.signature)
 LEFT JOIN pg_language l ON l.oid=p.prolang ORDER BY e.name;`);
for(const kind of ['p','u','f','c','x']) {
 const rows=c.tables.flatMap(t=>t.constraints.filter(k=>k.kind===kind).map(k=>[t.name,k.name,k.definition]));
 write('13-constraints-'+kind,`WITH expected(table_name,constraint_name,definition) AS (VALUES
${values(rows)})
SELECT e.table_name,e.constraint_name,k.oid IS NOT NULL identity_exists,
 COALESCE(k.contype=${quote(kind)} AND k.convalidated AND NOT k.condeferrable AND NOT k.condeferred,false) structural_flags_match,
 ${norm('pg_get_constraintdef(k.oid,false)')} IS NOT DISTINCT FROM e.definition exact_source_definition_matches
FROM expected e LEFT JOIN pg_constraint k ON k.conrelid=to_regclass(e.table_name) AND k.conname=e.constraint_name ORDER BY 1,2;`);
}
write('14-index-definitions',`WITH expected(index_name,parent_name,definition) AS (VALUES
${values(c.indexes.map(i=>[i.name,i.parent,i.definition]))})
SELECT e.index_name,i.indexrelid IS NOT NULL identity_exists,
 COALESCE(i.indrelid=to_regclass(e.parent_name) AND i.indisvalid AND i.indisready AND i.indislive,false) structural_flags_match,
 ${norm('pg_get_indexdef(i.indexrelid,0,false)')} IS NOT DISTINCT FROM e.definition exact_source_definition_matches
FROM expected e LEFT JOIN pg_index i ON i.indexrelid=to_regclass(e.index_name) ORDER BY 1;`);
write('15-column-expressions',`WITH expected(table_name,column_name,expression,identity_kind,generated_kind) AS (VALUES
${values(c.tables.flatMap(t=>t.columns.map(col=>[t.name,col.name,col.default,col.identity,col.generated])))})
SELECT e.table_name,e.column_name,a.attnum IS NOT NULL identity_exists,
 COALESCE(a.attidentity::text=e.identity_kind AND a.attgenerated::text=e.generated_kind,false) generated_identity_matches,
 ${norm('pg_get_expr(d.adbin,d.adrelid,false)')} IS NOT DISTINCT FROM e.expression exact_source_expression_matches
FROM expected e LEFT JOIN pg_attribute a ON a.attrelid=to_regclass(e.table_name) AND a.attname=e.column_name AND a.attnum>0 AND NOT a.attisdropped
 LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum ORDER BY 1,2;`);
write('16-trigger-definitions',`WITH expected(table_name,trigger_name,definition) AS (VALUES
${values(m.triggers.map(t=>[t.table_name,t.name,canonical(t.definition)]))})
SELECT e.table_name,e.trigger_name,t.oid IS NOT NULL identity_exists,
 COALESCE(t.tgenabled='O' AND NOT t.tgisinternal,false) enabled_matches,
 ${norm('pg_get_triggerdef(t.oid,false)')} IS NOT DISTINCT FROM e.definition exact_source_definition_matches
FROM expected e LEFT JOIN pg_trigger t ON t.tgrelid=to_regclass(e.table_name) AND t.tgname=e.trigger_name ORDER BY 1,2;`);
write('17-routine-defaults',`WITH expected(routine_name,signature,defaults) AS (VALUES
${values(c.routines.map(r=>[r.name,r.signature,r.argument_defaults]))})
SELECT e.routine_name,p.oid IS NOT NULL identity_exists,
 COALESCE(${norm("pg_get_expr(p.proargdefaults,0,false)")},'')=e.defaults exact_source_defaults_match
FROM expected e LEFT JOIN pg_proc p ON p.oid=to_regprocedure(e.signature) ORDER BY 1;`);
const castColumns=c.tables.flatMap(t=>t.columns.filter(col=>typedTextDefault(col.default,col.type)!==col.default)
 .map(col=>[t.name,col.name,typedTextDefault(col.default,col.type)]));
const castRoutines=c.routines.filter(r=>typedRoutineDefaults(r)!==r.argument_defaults);
write('18-approved-text-casts',`WITH expected_columns(table_name,column_name,expression) AS (VALUES
${values(castColumns)}), expected_routines(name,signature,defaults) AS (VALUES
${values(castRoutines.map(r=>[r.name,r.signature,typedRoutineDefaults(r)]))})
SELECT 'column' category,e.table_name||'.'||e.column_name object_name,
 a.attnum IS NOT NULL identity_exists,
 ${norm('pg_get_expr(d.adbin,d.adrelid,false)')} IS NOT DISTINCT FROM e.expression approved_text_cast_matches
FROM expected_columns e LEFT JOIN pg_attribute a ON a.attrelid=to_regclass(e.table_name) AND a.attname=e.column_name AND a.attnum>0 AND NOT a.attisdropped
 LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum
UNION ALL
SELECT 'routine',e.name,p.oid IS NOT NULL,
 COALESCE(${norm('pg_get_expr(p.proargdefaults,0,false)')},'')=e.defaults
FROM expected_routines e LEFT JOIN pg_proc p ON p.oid=to_regprocedure(e.signature) ORDER BY 1,2;`);
write('19-approved-body-equality',`WITH expected(name,signature,approved_digest) AS (VALUES
${values(c.routines.map(r=>[r.name,r.signature,r.body_md5]))})
SELECT e.name routine_name,p.oid IS NOT NULL identity_exists,
 COALESCE(md5(p.prosrc)=e.approved_digest,false) approved_source_body_matches
FROM expected e LEFT JOIN pg_proc p ON p.oid=to_regprocedure(e.signature) ORDER BY 1;`);
console.log('Prepared twelve fixed boolean comparison queries from approved source metadata. No connections or SQL execution.');
