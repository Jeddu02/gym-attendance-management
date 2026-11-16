// Source-only, conservative normalization candidates. Never strips grouping/casts.
import {tokens,split} from './source-contract.mjs';
export function typedTextDefault(expression,type) {
  if(expression===null||type!=='text')return expression;
  const t=tokens(expression);
  return t.length===1&&(t[0]==='null'||/^'(?:''|[^'])*'$/.test(t[0]))
    ?t[0]+' :: text':expression;
}
export function typedRoutineDefaults(routine) {
  if(!routine.default_count)return routine.argument_defaults;
  const defaults=split(tokens(routine.argument_defaults));
  if(defaults.length!==routine.default_count)throw Error('DEFAULT_COUNT_MISMATCH');
  const types=routine.input_types.slice(-routine.default_count);
  return defaults.map((t,i)=>typedTextDefault(t.join(' '),types[i])).join(' , ');
}
