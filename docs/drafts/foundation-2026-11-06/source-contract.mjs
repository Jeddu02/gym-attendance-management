// Filesystem only: a deliberately limited lexer/extractor for this pinned source set.
// Not a PostgreSQL parser. Unknown schema-changing forms throw instead of guessing.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
export const directory = path.dirname(fileURLToPath(import.meta.url));
export const root = path.resolve(directory, '../../..');
export const read = p => fs.readFileSync(p, 'utf8');
export const json = p => JSON.parse(read(p));
export const digest = s => crypto.createHash('sha256').update(s).digest('hex');
export function tokens(sql) {
  const result = [];
  const rx = /\s+|--[^\r\n]*(?:\r?\n|$)|\/\*[\s\S]*?\*\/|\$[a-z_]*\$|'(?:''|[^'])*'|"(?:""|[^"])*"|[a-z_][a-z_0-9]*|\d+(?:\.\d+)?|::|<>|<=|>=|&&|!=|\|\||[^\s]/giy;
  let i = 0;
  while (i < sql.length) {
    rx.lastIndex = i;
    const m = rx.exec(sql);
    if (!m || m.index !== i) throw Error('Unrecognized SQL token');
    i = rx.lastIndex;
    let t = m[0];
    if (/^\s|^--|^\/\*/.test(t)) continue;
    if (/^\$[a-z_]*\$$/i.test(t)) {
      const end = sql.indexOf(t, i);
      if (end < 0) throw Error('Unclosed dollar body');
      t += sql.slice(i, end) + t; i = end + m[0].length;
    } else if (!/^["']/.test(t)) t = t.toLowerCase();
    result.push(t);
  }
  return result;
}
export const canonical = s => tokens(s).join(' ');
export function split(ts, separator = ',') {
  const out = []; let start = 0; let depth = 0;
  ts.forEach((t, i) => {
    if (t === '(') depth++;
    if (t === ')') depth--;
    if (depth < 0) throw Error('Unbalanced parentheses');
    if (t === separator && depth === 0) { out.push(ts.slice(start, i)); start = i + 1; }
  });
  if (depth !== 0) throw Error('Unbalanced parentheses');
  if (start < ts.length) out.push(ts.slice(start));
  return out;
}
export const statements = s => split(tokens(s), ';');
const text = t => t.join(' ');
const qualified = (t, i) => t.slice(i, i + 3).join('');
function close(t, start) {
  let depth = 0;
  for (let i = start; i < t.length; i++) {
    if (t[i] === '(') depth++;
    if (t[i] === ')' && --depth === 0) return i;
  }
  throw Error('Unclosed parenthesis');
}
function typeName(ts) {
  return text(ts).replace(/\btimestamptz\b/g, 'timestamp with time zone').replace(/\bint\b/g, 'integer');
}
export function buildContract() {
  const manifest = json(path.join(directory, 'object-manifest.json'));
  const tables = new Map(); const routines = new Map(); const indexes = new Map();
  const sources = manifest.baseline_migrations.map(m => {
    const source = read(path.join(root, 'supabase/migrations', m.name));
    if (digest(source) !== m.sha256) throw Error('Migration hash mismatch: ' + m.name);
    return { name: m.name, source };
  });
  function constraint(table, ts, column = null) {
    let name;
    if (ts[0] === 'constraint') { name = ts[1]; ts = ts.slice(2); }
    const kind = ({ primary: 'p', unique: 'u', references: 'f', foreign: 'f', check: 'c', exclude: 'x' })[ts[0]];
    if (!kind) throw Error('Unsupported constraint: ' + text(ts));
    const short = table.name.split('.')[1];
    let definition = text(ts);
    if (column && kind === 'p') { name ??= short + '_pkey'; definition = `primary key ( ${column} )`; }
    if (column && kind === 'u') { name ??= `${short}_${column}_key`; definition = `unique ( ${column} )`; }
    if (column && kind === 'f') { name ??= `${short}_${column}_fkey`; definition = `foreign key ( ${column} ) ${definition}`; }
    if (!name) throw Error('Unnamed table constraint requires explicit review: ' + table.name);
    table.constraints.push({ name, kind, definition, validated: true, deferrable: false, deferred: false });
  }
  function column(table, ts) {
    const name = ts[0]; let end = 1; let depth = 0;
    while (end < ts.length) {
      if (depth === 0 && ['primary','not','default','unique','references','generated','check','constraint'].includes(ts[end])) break;
      if (ts[end] === '(') depth++; if (ts[end] === ')') depth--; end++;
    }
    const c = { name, type: typeName(ts.slice(1, end)), not_null: false, default: null, identity: '', generated: '' };
    let rest = ts.slice(end);
    while (rest.length) {
      if (rest[0] === 'not' && rest[1] === 'null') { c.not_null = true; rest = rest.slice(2); }
      else if (rest[0] === 'primary' && rest[1] === 'key') { c.not_null = true; constraint(table, rest.slice(0,2), name); rest = rest.slice(2); }
      else if (rest[0] === 'unique') { constraint(table, ['unique'], name); rest = rest.slice(1); }
      else if (rest[0] === 'references') { constraint(table, rest, name); rest = []; }
      else if (rest[0] === 'default') {
        const next = rest.findIndex((v,i) => i > 1 && ['not','primary','unique','references','constraint'].includes(v));
        c.default = text(rest.slice(1, next < 0 ? rest.length : next)); rest = next < 0 ? [] : rest.slice(next);
      } else if (text(rest.slice(0,4)) === 'generated always as identity') {
        c.identity = 'a'; c.not_null = true; rest = rest.slice(4);
      } else if (text(rest.slice(0,3)) === 'generated always as' && rest[3] === '(') {
        const e = close(rest,3); if (rest[e+1] !== 'stored') throw Error('Unsupported generated property');
        c.generated = 's'; c.default = text(rest.slice(3,e+1)); rest = rest.slice(e+2);
      } else throw Error('Unsupported column clause: ' + text(rest));
    }
    table.columns.push(c);
  }
  for (const { source } of sources) for (let ts of statements(source)) {
    const head = text(ts);
    if (head.startsWith('create table ')) {
      if (text(ts.slice(2,5)) === 'if not exists') ts = [...ts.slice(0,2),...ts.slice(5)];
      const name = qualified(ts,2); if (ts[5] !== '(' || ts.at(-1) !== ')') throw Error('Unsupported CREATE TABLE: '+head.slice(0,100));
      const table = { name, columns: [], constraints: [] }; tables.set(name,table);
      for (const item of split(ts.slice(6,-1))) {
        if (['constraint','primary','unique','foreign','check','exclude'].includes(item[0])) constraint(table,item);
        else column(table,item);
      }
    } else if (head.startsWith('drop table ')) {
      let at = ts[2] === 'if' ? 4 : 2; tables.delete(qualified(ts,at));
    } else if (head.startsWith('alter table ')) {
      const name = qualified(ts,2); const table = tables.get(name);
      if (!table) throw Error('Unknown ALTER TABLE target: ' + name);
      for (const action of split(ts.slice(5))) {
        if (action[0] === 'add' && action[1] === 'column') column(table,action.slice(2));
        else if (action[0] === 'add' && action[1] === 'constraint') constraint(table,action.slice(1));
        else if (text(action).match(/^alter column [a-z_]+ set not null$/)) {
          const c=table.columns.find(c=>c.name===action[2]); if (!c) throw Error('Unknown column'); c.not_null=true;
        } else if (!text(action).match(/^(enable|force) row level security$/)) throw Error('Unsupported ALTER action: ' + text(action));
      }
    } else if (/^create (unique )?index /.test(head)) {
      let at=ts[1]==='unique'?3:2; const unique=ts[1]==='unique';
      if (ts[at]==='if') at+=3;
      const name=ts[at++]; if (ts[at++]!=='on') throw Error('Unsupported index');
      const parent=qualified(ts,at); at+=3;
      indexes.set(parent.split('.')[0]+'.'+name,{ name:parent.split('.')[0]+'.'+name, parent, unique, definition: `create ${unique?'unique ':''}index ${name} on ${parent} using btree ${text(ts.slice(at))}`, valid:true, ready:true });
    }
  }
  // Extract complete latest CREATE FUNCTION declarations without interpreting bodies.
  for (const { source } of sources) {
    const rx = /create\s+(?:or\s+replace\s+)?function\s+([a-z_]+\.[a-z_]+)\s*\(([\s\S]*?)\)\s*returns\s+([\s\S]*?)\bas\s+(\$[a-z_]*\$)([\s\S]*?)\4\s*;/gi;
    for (const m of source.matchAll(rx)) {
      const name=m[1].toLowerCase(); const header=tokens(m[3]); const langAt=header.indexOf('language');
      if (langAt<0) throw Error('Missing language');
      const returns=header.slice(0,langAt); const args=split(tokens(m[2]));
      const argNames=args.map(a=>a[0]); const defaults=args.filter(a=>a.includes('default')).map(a=>text(a.slice(a.indexOf('default')+1)));
      const out=returns[0]==='table'?split(returns.slice(2,-1)):[];
      const language=header[langAt+1];
      routines.set(name,{ name, kind:'f', language, argument_names:[...argNames,...out.map(a=>a[0])],
        input_types:args.map(a=>typeName(a.slice(1,a.includes('default')?a.indexOf('default'):a.length))),
        output_types:out.map(a=>typeName(a.slice(1))), argument_defaults:defaults.join(' , '), default_count:defaults.length,
        result:typeName(returns), returns_set:returns[0]==='table'||returns[0]==='setof',
        strict:header.includes('strict'), volatility:header.includes('immutable')?'i':header.includes('stable')?'s':'v',
        parallel:'u', leakproof:false, support:'-', variadic:'-', transforms:[], cost:100, rows:returns[0]==='table'?1000:0,
        body_md5:crypto.createHash('md5').update(m[5]).digest('hex'), extension:null });
    }
  }
  const selected=manifest.tables.map(t=>{ const v=tables.get(t.name); if(!v) throw Error('Missing expected table'); return v; });
  const routineList=manifest.routines.map(r=>{const v=routines.get(r.signature.split('(')[0]);if(!v||v.body_md5!==r.body_md5)throw Error('Routine body/declaration mismatch: '+r.signature);return {...v,signature:r.signature,proposed_owner:r.owner,proposed_definer:r.definer,callers:r.callers,search_path:''};});
  const explicitIndexes=[...indexes.values()].filter(i=>tables.has(i.parent)).map(i=>({...i,definition:canonical(i.definition)}));
  const expected = {
    format:1, origin:'Pinned migration source; strict lexical definitions, NOT a server catalog export',
    native_exposed_routines:[],
    hosted:{ supported:false, reason:'Provider metadata/version/ACL inventory not approved', documented_candidate:'graphql_public.graphql(text,text,jsonb,jsonb); pg_graphql-owned SECURITY INVOKER; NOT an allowed exception' },
    creators:['postgres','gym_data_owner','gym_owner_executor','gym_public_executor','gym_registration_login'],
    default_privileges:{ scopes:['global','private','api','public','graphql_public'], kinds:['r','S','f','T'], non_owner_grants:[], implicit_public_type_usage:'allow_only_unmodified_builtin_without_explicit_global_entry' },
    tables:selected, indexes:explicitIndexes, routines:routineList,
    triggers:manifest.triggers, permissions:manifest.permissions, sequence_runtime_grants:[],
    provider_profile:'native_only', executor_memberships:[]
  };
  return expected;
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const contract=buildContract();
  fs.writeFileSync(path.join(directory,'schema-contract.json'),JSON.stringify(contract,null,2)+'\n');
  console.log(`Source contract: ${contract.tables.length} tables, ${contract.tables.reduce((n,t)=>n+t.constraints.length,0)} constraints, ${contract.indexes.length} explicit indexes, ${contract.routines.length} routines`);
}
