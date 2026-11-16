// Filesystem-only comparison of explicitly safe structural CSV observations.
// No PostgreSQL commands; no definition/deparser equivalence is inferred.
import fs from 'node:fs';
import path from 'node:path';
import {directory,json,canonical,read,tokens} from './source-contract.mjs';
import {classifyDefaultObservation} from './default-privilege-classification.mjs';
const folder=path.join(directory,'minimal-catalog');
function csv(file) {
  const input=read(path.join(folder,file)).replace(/^\uFEFF/,'');
  const rows=[]; let row=[],field='',quoted=false;
  for(let i=0;i<input.length;i++) {
    const c=input[i];
    if(c==='"') { if(quoted&&input[i+1]==='"'){field+='"';i++;}else quoted=!quoted; }
    else if(!quoted&&c===','){row.push(field);field='';}
    else if(!quoted&&c==='\n'){row.push(field.replace(/\r$/,''));rows.push(row);row=[];field='';}
    else field+=c;
  }
  if(quoted||row.length||field) throw Error('INVALID_CSV');
  const head=rows.shift();
  if(!head||rows.some(r=>r.length!==head.length)) throw Error('INVALID_CSV_SHAPE');
  return rows.map(r=>Object.fromEntries(head.map((h,i)=>[h,r[i]])));
}
const requireMatch=(ok,code)=>{if(!ok)throw Error(code);};
const bool=v=>{requireMatch(v==='t'||v==='f','INVALID_BOOLEAN');return v==='t';};
try {
  const contract=json(path.join(directory,'schema-contract.json'));
  const manifest=json(path.join(directory,'object-manifest.json'));
  const files=fs.readdirSync(folder).filter(f=>f.endsWith('.sql')).sort();
  requireMatch(files.length===11,'QUERY_INVENTORY');
  requireMatch(read(path.join(directory,'inspect-catalog.sql'))===read(path.join(folder,'01-identity-counts.sql')),'ROOT_QUERY_NOT_MINIMAL');
  for(const file of files) {
    const sql=read(path.join(folder,file));
    requireMatch(!/\b(?:proargdefaults|prosrc|probin|prosqlbody|rolpassword|pg_authid|proargnames|proargtypes|proallargtypes|pg_get_expr|pg_get_functiondef|pg_get_constraintdef|pg_get_triggerdef|pg_get_ruledef|pg_get_indexdef|row_to_json|to_jsonb|jsonb_build_object)\b/i.test(sql),'UNSAFE_METADATA_FIELD');
    requireMatch(sql.startsWith('-- ')&&sql.includes('BEGIN READ ONLY;')&&sql.endsWith('ROLLBACK;\n'),'READ_ONLY_BOUNDARY');
    requireMatch(sql.includes("system_identifier::text='7704603813616068820'")&&sql.includes("current_user='postgres' AND session_user='postgres'"),'IDENTITY_GUARD');
    const ts=tokens(sql);
    requireMatch(!ts.some(t=>['insert','update','delete','create','alter','drop','truncate','copy','call','do','execute'].includes(t)),'NON_READ_ONLY_QUERY');
    for(let i=0;i<ts.length;i++) {
      if(ts[i]==='*') requireMatch(ts[i-2]==='count'&&ts[i-1]==='('&&ts[i+1]===')','WILDCARD_EXPORT');
      if(ts[i]==='proconfig') requireMatch(ts.slice(i,i+10).join(' ')==='proconfig = array [ \'search_path=""\' ] :: text [ ]','RAW_CONFIG');
    }
  }
  const identity=csv('01-observed.csv')[0];
  requireMatch(identity.database==='gymforce_pg18_test'&&identity.host==='127.0.0.1/32'&&identity.port==='55432'&&identity.actor==='postgres'&&identity.read_only==='on','OBSERVED_IDENTITY');
  const tables=csv('02-observed.csv');
  const tableRows=tables.filter(t=>t.kind==='r');
  requireMatch(tableRows.length===22&&tableRows.every(t=>t.owner==='postgres'&&bool(t.rls)&&!bool(t.force_rls)),'CURRENT_TABLE_OWNER_RLS');
  const sameSet=(a,b)=>JSON.stringify(a.slice().sort())===JSON.stringify(b.slice().sort());
  requireMatch(sameSet(tableRows.map(t=>t.schema_name+'.'+t.object_name),contract.tables.map(t=>t.name)),'TABLE_NAMES');
  requireMatch(sameSet(tables.filter(t=>t.kind==='S').map(t=>t.schema_name+'.'+t.object_name),manifest.sequences.map(s=>s.name)),'SEQUENCE_NAMES');
  requireMatch(tables.filter(t=>t.kind==='S').every(t=>t.owner==='postgres'),'SEQUENCE_OWNERS');
  const ci=csv('03-observed.csv'),constraints=ci.filter(c=>c.category==='constraint'),indexes=ci.filter(c=>c.category==='index');
  const expectedConstraints=contract.tables.flatMap(t=>t.constraints.map(c=>({table:t.name,...c})));
  requireMatch(constraints.length===expectedConstraints.length,'CONSTRAINT_COUNT');
  for(const expected of expectedConstraints) {
    const found=constraints.find(c=>c.schema_name+'.'+c.table_name===expected.table&&c.object_name===expected.name);
    requireMatch(found&&found.kind===expected.kind&&bool(found.valid)&&bool(found.deferrable)===expected.deferrable&&bool(found.deferred)===expected.deferred,'CONSTRAINT_STRUCTURE');
  }
  const dependencies=json(path.join(directory,'dependent-objects.json'));
  requireMatch(sameSet(indexes.map(i=>i.schema_name+'.'+i.object_name+'|'+i.schema_name+'.'+i.table_name),dependencies.indexes.map(i=>i.name+'|'+i.parent)),'INDEX_NAMES_BINDINGS');
  requireMatch(indexes.every(i=>bool(i.valid)&&bool(i.ready)),'INDEX_VALIDITY');
  for(const table of contract.tables) for(const constraint of table.constraints.filter(c=>['p','u','x'].includes(c.kind))) {
    const i=indexes.find(i=>i.schema_name+'.'+i.table_name===table.name&&i.object_name===constraint.name);
    requireMatch(i&&bool(i.primary_key)===(constraint.kind==='p')&&bool(i.unique_key)===['p','u'].includes(constraint.kind)&&bool(i.exclusion)===(constraint.kind==='x'),'CONSTRAINT_INDEX_FLAGS');
  }
  for(const expected of contract.indexes) {
    const i=indexes.find(i=>i.schema_name+'.'+i.object_name===expected.name);
    requireMatch(i&&bool(i.unique_key)===expected.unique,'EXPLICIT_INDEX_FLAGS');
  }
  const columns=csv('04-observed.csv'); let columnChecks=0; const normalizations=[];
  requireMatch(columns.length===contract.tables.reduce((n,t)=>n+t.columns.length,0),'COLUMN_COUNT');
  for(const table of contract.tables) for(const [index,expected] of table.columns.entries()) {
    const col=columns.find(c=>c.schema_name+'.'+c.table_name===table.name&&c.column_name===expected.name);
    requireMatch(col&&+col.ordinal===index+1&&canonical(col.type_name)===expected.type&&bool(col.not_null)===expected.not_null&&col.identity_kind===expected.identity&&col.generated_kind===expected.generated&&bool(col.has_default_or_generated_expression)===(expected.default!==null),'COLUMN_STRUCTURE');
    if(col.type_name!==expected.type)normalizations.push({object:table.name+'.'+expected.name,property:'type_spacing',classification:'lexer whitespace only; canonical tokens equal'});
    columnChecks++;
  }
  const routines=csv('05-observed.csv');
  requireMatch(routines.length===25,'ROUTINE_COUNT');
  for(const expected of contract.routines) {
    const matches=routines.filter(r=>r.schema_name+'.'+r.object_name===expected.name);
    requireMatch(matches.length===1,'ROUTINE_NAME_OVERLOAD');
    const r=matches[0],baseline=manifest.routines.find(m=>m.signature===expected.signature);
    requireMatch(r.kind===expected.kind&&r.owner==='postgres'&&r.language_name===expected.language&&bool(r.security_definer)===baseline.prosecdef&&bool(r.strict)===expected.strict&&bool(r.returns_set)===expected.returns_set&&bool(r.leakproof)===expected.leakproof&&r.volatility===expected.volatility&&r.parallel===expected.parallel&&+r.input_count===expected.input_types.length&&+r.default_count===expected.default_count&&bool(r.exact_empty_search_path)&&!bool(r.anon_execute)&&!bool(r.authenticated_execute)&&bool(r.service_execute)===expected.name.startsWith('api.'),'ROUTINE_STRUCTURAL_SECURITY');
  }
  const privileges=csv('06-observed.csv');
  requireMatch(privileges.length===154&&privileges.every(p=>['table_select','table_insert','table_update','table_delete','other_table_privilege','any_column_privilege'].every(k=>!bool(p[k]))),'DIRECT_TABLE_PRIVILEGES');
  const triggers=csv('07-observed.csv');
  requireMatch(triggers.length===13&&triggers.every(t=>t.category==='trigger'&&t.enabled==='O')&&sameSet(triggers.map(t=>t.schema_name+'.'+t.table_name+'|'+t.object_name),manifest.triggers.map(t=>t.table_name+'|'+t.name)),'TRIGGER_RULE_INVENTORY');
  const defaults=csv('08-observed.csv'); requireMatch(defaults.length===20,'DEFAULT_CHECK_COUNT');
  const nonOwnerFlags=defaults.filter(d=>bool(d.non_owner_global_default)||bool(d.non_owner_schema_default));
  const origins=csv('10-observed.csv');
  requireMatch(origins.length===10&&sameSet(origins.map(o=>o.creator+'|'+o.kind),contract.creators.flatMap(c=>[c+'|f',c+'|T'])),'DEFAULT_ORIGIN_INVENTORY');
  requireMatch(origins.every(o=>!bool(o.explicit_global_entry)&&o.schema_entry_count==='0'&&bool(o.equals_builtin_acl)&&bool(o.public_builtin_privilege)&&!bool(o.explicit_browser_grant)&&!bool(o.other_or_escalated_grant)),'DEFAULT_ORIGIN_BASELINE');
  const classifications=origins.map(o=>({creator:o.creator,kind:o.kind,classification:classifyDefaultObservation(o)}));
  const blockers=classifications.filter(o=>o.classification!=='acceptable_implicit_public_type_usage');
  const boundary=csv('11-observed.csv');
  requireMatch(boundary.length===2&&sameSet(boundary.map(b=>b.role_name),['anon','authenticated'])&&boundary.every(b=>b.executable_routines==='0'&&b.schema_reachable_routines==='0'&&b.directly_privileged_tables==='0'),'CURRENT_BROWSER_BOUNDARY');
  const roles=csv('09-observed.csv'); requireMatch(roles.length===28,'ROLE_SCHEMA_COUNT');
  requireMatch(roles.every(r=>!bool(r.superuser)&&!bool(r.createdb)&&!bool(r.createrole)&&!bool(r.inherit)&&!bool(r.replication)&&!bool(r.bypassrls)&&!bool(r.schema_create)&&!bool(r.any_membership_edge)&&bool(r.login)===(r.role_name==='gym_registration_login')),'RESTRICTED_ROLE_SECURITY');
  requireMatch(roles.filter(r=>r.schema_name==='api').every(r=>bool(r.schema_usage)===(r.role_name==='service_role')),'API_SCHEMA_BOUNDARY');
  const findings={status:'NOT READY',accepted_queries:11,rejected_narrowed_queries:0,
    verified:{tables:22,sequences:3,constraints:110,indexes:57,columns:columnChecks,routines:25,user_triggers:13,rules:0,table_role_checks:154,default_checks:20},
    observed_non_owner_default_flags:nonOwnerFlags.length,default_origin_classification:classifications,
    actual_default_precondition_failures:blockers,existing_browser_boundary:boundary,legitimate_type_formatting:normalizations,
    unresolved:['Constraint/index expressions, keys, predicates and FK actions','Column default/generated expression values','Routine signatures, argument/result types/modes/default values, bodies and implementation identity','Sequence privileges and identity bindings','Definition-level trigger/RLS policy behavior','Post-migration restricted-executor behavior; hosted compatibility'],
    observation_scope:'Eleven independent guarded read-only transactions across follow-ups; not an atomic database snapshot or mutation-preservation proof'};
  fs.writeFileSync(path.join(folder,'findings.json'),JSON.stringify(findings,null,2)+'\n');
  console.log(`PASS: structural comparisons. ${blockers.length} actual default-ACL precondition failures; ${normalizations.length} harmless type-format differences. NOT READY.`);
} catch(error){console.error('REFUSED: '+(/^[A-Z_]+$/.test(error.message)?error.message:'INSPECTION_INPUT_INVALID'));process.exitCode=1;}
