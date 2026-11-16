// Independent comparator/process entrypoint. Filesystem only; never executes SQL.
import path from 'node:path';
import { isDeepStrictEqual } from 'node:util';
import { directory, root, read, json, statements, digest } from './source-contract.mjs';
import { buildAlignedContract } from './aligned-contract.mjs';
import { hardeningBlock } from './render-hardening.mjs';
function requireCheck(ok, id) { if (!ok) throw Error(id); }
function valueArg(name, fallback) { const i=process.argv.indexOf(name); return i<0?fallback:process.argv[i+1]; }
try {
  const expected=buildAlignedContract();
  const dependencies=json(path.join(directory,'dependent-objects.json'));
  const derivedIndexes=[...expected.indexes.map(i=>({name:i.name,parent:i.parent})),
    ...expected.tables.flatMap(t=>t.constraints.filter(c=>['p','u','x'].includes(c.kind))
      .map(c=>({name:t.name.split('.')[0]+'.'+c.name,parent:t.name})))];
  const byName=items=>items.map(i=>i.name+'|'+i.parent).sort();
  requireCheck(isDeepStrictEqual(byName(derivedIndexes),byName(dependencies.indexes)),'SOURCE_INDEX_BINDINGS');
  const candidate=json(valueArg('--candidate',path.join(directory,'aligned-schema-contract.json')));
  // Exact structured values, not object counts or substring presence.
  for (const key of Object.keys(expected)) requireCheck(isDeepStrictEqual(candidate[key],expected[key]),'CONTRACT_'+key);
  requireCheck(isDeepStrictEqual(Object.keys(candidate).sort(),Object.keys(expected).sort()),'CONTRACT_unknown_fields');
  const reviewed=json(path.join(directory,'statement-manifest.json'));
  for (const [option,file] of [['--migration','20261106120000_owner_executor_foundation.sql.draft'],['--assertions','foundation_assertions.sql.draft']]) {
    const sql=read(valueArg(option,path.join(directory,file)));
    const actual=statements(sql);
    requireCheck(actual[0]?.join(' ').startsWith('begin'),'TRANSACTION_FIRST');
    requireCheck(actual[1]?.[0]==='do' && /^\$draft_only\$\s*BEGIN\s*RAISE EXCEPTION 'DRAFT ONLY:[^']*';\s*END;\s*\$draft_only\$$/.test(actual[1]?.[1]??''),'BLOCKER');
    const expectedDigests=reviewed[file];
    requireCheck(actual.length===expectedDigests.length,'STATEMENT_COUNT');
    actual.forEach((s,i)=>requireCheck(digest(s.join(' '))===expectedDigests[i].sha256,'STATEMENT_'+i));
    const blocks=actual.filter(s=>s[0]==='do'&&s[1]?.startsWith('$offline_contract$'));
    requireCheck(blocks.length===(option==='--migration'?3:1),'HARDENING_COUNT');
    const generated=statements(hardeningBlock(expected))[0].join(' ');
    blocks.forEach(b=>requireCheck(b.join(' ')===generated,'HARDENING_SOURCE_CONTRACT'));
    requireCheck(!/grant\s+usage\s+on\s+sequence/i.test(sql),'SEQUENCE_ESCALATION');
  }
  const sourceManifest=json(path.join(directory,'object-manifest.json'));
  const proposalName='default-function-privileges.sql.draft';
  const proposal=statements(read(path.join(directory,proposalName)));
  const proposalPins=reviewed[proposalName];
  requireCheck(proposal[0]?.join(' ')==='begin'&&proposal[1]?.[0]==='do'&&proposal[1][1].includes("RAISE EXCEPTION 'DRAFT ONLY:"),'DEFAULT_PROPOSAL_BLOCKER');
  requireCheck(proposalPins?.length===proposal.length,'DEFAULT_PROPOSAL_COUNT');
  proposal.forEach((s,i)=>requireCheck(digest(s.join(' '))===proposalPins[i].sha256,'DEFAULT_PROPOSAL_STATEMENT'));
  const changes=proposal.filter(s=>s[0]==='alter').map(s=>s.join(' '));
  requireCheck(isDeepStrictEqual(changes,expected.creators.map(r=>`alter default privileges for role ${r} revoke execute on functions from public`)),'DEFAULT_PROPOSAL_SCOPE');
  for (const protectedFile of sourceManifest.protected_files) {
    requireCheck(digest(read(path.join(root,protectedFile.path)))===protectedFile.sha256,'PROTECTED_SOURCE_HASH');
  }
  console.log('PASS: exact structured source contract, complete reviewed statement inventory, generated guard blocks, source integrity. No SQL executed.');
} catch(error) {
  // Stable reason only; do not dump fixture contents, source or environment.
  console.error('REFUSED: '+(/^(?:CONTRACT_[a-z_]+|[A-Z][A-Z_0-9]+)$/.test(error.message)?error.message:'INVALID_INPUT_OR_SOURCE'));
  process.exitCode=1;
}
