// Derives review criteria only. No live fixture creation or scenario execution.
import fs from 'node:fs';
import {directory,read,digest} from '../source-contract.mjs';
const source=read(directory+'/executor-acceptance-fixtures.json'),f=JSON.parse(source);
const criteria=f.cases.map(c=>({id:c.id,category:c.category,actor:c.actor,status:'NOT_EXECUTED_NOT_INCLUDED_IN_CATALOGUE_CANDIDATE',
 preconditions:['Fresh strict cluster/endpoint/database/SCRAM identity verification','Reviewed proposed owners/ACLs/RLS active in explicitly approved isolation','Owner-approved restore evidence, fixture collision checks and unique synthetic IDs','No live or pre-existing member/payment/PIN rows reused',...(c.category==='concurrency'?['Separately approved committed isolated state visible to both sessions','Explicit barriers, lock/statement timeouts, bounded retry policy']:[]),...(['sequences','nested_rpc','triggers','rollback'].includes(c.category)?['Owner-approved nonzero sequence budget and protected baseline capture']:[])],
 steps:c.steps,pass_criteria:c.expect,
 fail_criteria:['Any mismatched SQLSTATE, unexpected success, unauthorized row or unexpected zero-row write','Any unexplained business/audit/sequence/schema/default-ACL change','Any unsupported/omitted step; never report partial scenario as PASS'],
 catalogue_subset:['rls','role_escalation','sequences'].includes(c.category)?'Candidate catalog assertions check declared ACL/role/RLS metadata only; no runtime behavior evidence':'None; full scenario deferred'}));
fs.writeFileSync(directory+'/controlled-pilot/scenario-checklist.json',JSON.stringify({source_sha256:digest(source),scope:'Declarative review only; every executor scenario remains NOT RUN',cases:criteria},null,2)+'\n');
console.log('Prepared explicit prerequisites/pass/fail criteria for all 16 deferred executor scenarios.');
