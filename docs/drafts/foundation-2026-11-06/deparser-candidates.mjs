// Source-only, deliberately partial ruleutils renderer, NOT a general SQL normalizer.
// Actual expressions are never fed here. Unknown AST nodes/types fail closed.
import {canonical} from './source-contract.mjs';
const strings=xs=>xs.map(x=>x.String.sval);
const literal=s=>"'"+s.replaceAll("'","''")+"'";
export function renderExpression(node,columns) {
 const render=n=>renderExpression(n,columns);
 if(node.ColumnRef){const names=strings(node.ColumnRef.fields);if(names.length!==1||!columns[names[0]])throw Error('UNKNOWN_COLUMN');return names[0];}
 if(node.A_Const){const c=node.A_Const;if(c.sval)return literal(c.sval.sval)+'::text';if(c.ival)return String(c.ival.ival??0);throw Error('UNSUPPORTED_CONSTANT');}
 if(node.NullTest){const n=node.NullTest;if(!['IS_NULL','IS_NOT_NULL'].includes(n.nulltesttype))throw Error('UNKNOWN_NULL_TEST');return '('+render(n.arg)+(n.nulltesttype==='IS_NULL'?' IS NULL':' IS NOT NULL')+')';}
 if(node.BoolExpr){const n=node.BoolExpr;if(n.boolop==='NOT_EXPR'&&n.args.length===1)return '(NOT '+render(n.args[0])+')';if(!['AND_EXPR','OR_EXPR'].includes(n.boolop))throw Error('UNKNOWN_BOOL');return '('+n.args.map(render).join(n.boolop==='AND_EXPR'?' AND ':' OR ')+')';}
 if(node.A_Expr){const n=node.A_Expr,op=strings(n.name).join('.');
  if(n.kind==='AEXPR_NULLIF'&&op==='=')return 'NULLIF('+render(n.lexpr)+', '+render(n.rexpr)+')';
  if(n.kind==='AEXPR_IN'){
   const col=n.lexpr.ColumnRef?.fields?.[0]?.String?.sval;
   if(op!=='='||columns[col]!=='text'||!n.rexpr.List?.items.every(x=>x.A_Const?.sval))throw Error('UNSUPPORTED_IN');
   return '('+render(n.lexpr)+' = ANY (ARRAY['+n.rexpr.List.items.map(render).join(', ')+']))';
  }
  if(n.kind!=='AEXPR_OP'||!['=','<>','>','>='].includes(op))throw Error('UNSUPPORTED_OPERATOR');
  let right=render(n.rexpr);const col=n.lexpr.ColumnRef?.fields?.[0]?.String?.sval;
  if(n.rexpr.A_Const?.ival&&columns[col]?.startsWith('numeric'))right='('+right+')::numeric';
  return '('+render(n.lexpr)+' '+op+' '+right+')';
 }
 if(node.FuncCall){const n=node.FuncCall,names=strings(n.funcname),name=names.at(-1),args=n.args??[];
  if(Object.keys(n).some(k=>!['funcname','args','funcformat','location'].includes(k)))throw Error('UNSUPPORTED_FUNCTION_OPTION');
  if(names.length>2||(names.length===2&&names[0]!=='pg_catalog')||!['length','btrim','octet_length','lower','regexp_replace','daterange'].includes(name))throw Error('UNSUPPORTED_FUNCTION');
  if(name==='btrim'&&n.funcformat==='COERCE_SQL_SYNTAX'&&args.length===1)return 'TRIM(BOTH FROM '+render(args[0])+')';
  return name+'('+args.map(render).join(', ')+')';
 }
 if(node.NullIfExpr)return 'NULLIF('+node.NullIfExpr.args.map(render).join(', ')+')';
 throw Error('UNSUPPORTED_AST_NODE');
}
export function checkCandidate(parse,definition,columns){
 if(!definition.startsWith('check ( ')||!definition.endsWith(' )'))throw Error('NOT_CHECK');
 const ast=parse('SELECT '+definition.slice(8,-2));
 return canonical('CHECK ('+renderExpression(ast.stmts[0].stmt.SelectStmt.targetList[0].ResTarget.val,columns)+')');
}
export function indexCandidate(parse,definition,columns){
 const n=parse(definition).stmts[0].stmt.IndexStmt;
 if(!n||n.accessMethod!=='btree'||n.indexIncludingParams?.length||n.options?.length||n.tableSpace||n.excludeOpNames?.length||n.nulls_not_distinct||n.concurrent||n.isconstraint||n.deferrable||n.initdeferred||n.relation.inh===false)throw Error('UNSUPPORTED_INDEX');
 const keys=n.indexParams.map(({IndexElem:k})=>{
  if(k.opclass?.length||k.collation?.length||k.nulls_ordering!=='SORTBY_NULLS_DEFAULT')throw Error('UNSUPPORTED_INDEX_KEY');
  const val=k.name??renderExpression(k.expr,columns);
  if(!['SORTBY_DEFAULT','SORTBY_DESC'].includes(k.ordering))throw Error('UNSUPPORTED_ORDER');
  return val+(k.ordering==='SORTBY_DESC'?' DESC':'');
 });
 return canonical('CREATE '+(n.unique?'UNIQUE ':'')+'INDEX '+n.idxname+' ON '+n.relation.schemaname+'.'+n.relation.relname+' USING btree ('+keys.join(', ')+')'+(n.whereClause?' WHERE '+renderExpression(n.whereClause,columns):''));
}
