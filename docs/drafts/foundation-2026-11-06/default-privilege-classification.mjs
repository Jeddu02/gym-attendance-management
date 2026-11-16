// Pure classification of safe Q10 booleans; never connects or changes privileges.
export function classifyDefaultObservation(row) {
  const keys=['explicit_global_entry','equals_builtin_acl','public_builtin_privilege','explicit_browser_grant','other_or_escalated_grant'];
  if(!['f','T'].includes(row.kind)||keys.some(k=>!['t','f'].includes(row[k]))||!/^\d+$/.test(row.schema_entry_count)) throw Error('INVALID_DEFAULT_OBSERVATION');
  if(row.explicit_browser_grant==='t'||row.other_or_escalated_grant==='t'||row.schema_entry_count!=='0') return 'requires_explicit_privilege_review';
  if(row.public_builtin_privilege==='f') return 'owner_only_non_owner_defaults_absent';
  if(row.kind==='T'&&row.explicit_global_entry==='f'&&row.equals_builtin_acl==='t') return 'acceptable_implicit_public_type_usage';
  if(row.kind==='f') return 'future_function_execution_hardening_required';
  return 'requires_explicit_privilege_review';
}
