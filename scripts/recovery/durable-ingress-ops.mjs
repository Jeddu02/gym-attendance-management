// Local synthetic operational control. No default scheduler or external delivery.
import { open, readFile, rename, rm, lstat, realpath } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
const kinds=['denied','unavailable','timeouts','maintenance_unavailable','heartbeat_unavailable'];
const limit=14400; // 5 categories x 2880 minute bins; C1 business evidence untouched.
function validAlert(a) {
  return a && Object.keys(a).sort().join()==='count,key,kind,minute' && kinds.includes(a.kind) &&
    Number.isSafeInteger(a.minute)&&a.minute>=0&&Number.isSafeInteger(a.count)&&a.count>=0&&
    a.key===`${a.minute}:${a.kind}`;
}
export class DurableIngressQueue {
  constructor(directory,lane='worker') {
    if(!['worker','watchdog','sink'].includes(lane))throw Error('OPS_LANE');
    this.directory=resolve(directory);this.lane=lane;
    this.file=resolve(this.directory,lane==='worker'?'aggregate-queue.json':`aggregate-${lane}.json`);
  }
  async transaction(minute, action) {
    if(!Number.isSafeInteger(minute)||minute<0)throw Error('OPS_CLOCK');
    // Caller must create a private, isolated directory. Refuse reparse/symlink paths.
    if((await lstat(this.directory)).isSymbolicLink() || (await realpath(this.directory)).toLowerCase()!==this.directory.toLowerCase())throw Error('OPS_PATH');
    const lock=await open(this.file+'.lock','wx',0o600);
    try {
      let state={version:1,minute,heartbeat:null,records:[]};
      try {
        if((await lstat(this.file)).isSymbolicLink()||(await lstat(this.file)).size>4*1024*1024)throw Error('OPS_STATE');
        state=JSON.parse(await readFile(this.file,'utf8'));
      } catch(e) { if(e.code!=='ENOENT')throw Error('OPS_STATE'); }
      if(Object.keys(state).sort().join()!=='heartbeat,minute,records,version'||state.version!==1||!Number.isSafeInteger(state.minute)||state.minute<0||minute<state.minute||
        (state.heartbeat!==null&&(!Number.isSafeInteger(state.heartbeat)||state.heartbeat<0||state.heartbeat>state.minute))||
        !Array.isArray(state.records)||state.records.length>limit||state.records.some(r=>!r||Object.keys(r).sort().join()!=='ack,alert'||typeof r.ack!=='boolean'||!validAlert(r.alert)||r.alert.minute>state.minute)||
        new Set(state.records.map(r=>r.alert.key)).size!==state.records.length)throw Error('OPS_STATE');
      state.records=state.records.filter(r=>r.alert.minute>minute-2880);state.minute=minute;
      const result=await action(state);
      const temp=this.file+'.tmp';
      const handle=await open(temp,'wx',0o600);
      try {await handle.writeFile(JSON.stringify(state));await handle.sync();}finally{await handle.close();}
      await rename(temp,this.file);
      return result;
    } finally {await lock.close();await rm(this.file+'.lock');}
  }
  enqueue(alert,minute) {
    if(!validAlert(alert)||alert.minute>minute||alert.minute<=minute-2880)throw Error('OPS_ALERT');
    return this.transaction(minute,s=>{
      if(s.records.some(r=>r.alert.key===alert.key))return;
      if(s.records.length>=limit)throw Error('OPS_CAPACITY');
      s.records.push({alert:{...alert},ack:false});
    });
  }
  heartbeat(minute) {return this.transaction(minute,s=>{s.heartbeat=minute;});}
  watchdog(minute) {return this.transaction(minute,s=>{
    if(s.heartbeat!==null&&minute-s.heartbeat<=2)return false;
    const alert={minute,kind:'heartbeat_unavailable',count:1,key:`${minute}:heartbeat_unavailable`};
    if(!s.records.some(r=>r.alert.key===alert.key)){
      if(s.records.length>=limit)throw Error('OPS_CAPACITY');s.records.push({alert,ack:false});
    }return true;
  });}
  async independentWatchdog(minute) {
    if(this.lane!=='watchdog')throw Error('OPS_LANE');
    // Separate writer/lock/journal. A crashed worker holding its lock cannot hide
    // a stale heartbeat. Atomic replacement gives either old or new whole state.
    let heartbeat=null;
    const source=resolve(this.directory,'aggregate-queue.json');
    try {
      const stat=await lstat(source);if(stat.isSymbolicLink()||stat.size>4*1024*1024)throw Error('OPS_STATE');
      const state=JSON.parse(await readFile(source,'utf8'));
      if(state.version!==1||!Number.isSafeInteger(state.minute)||state.minute>minute||
        (state.heartbeat!==null&&(!Number.isSafeInteger(state.heartbeat)||state.heartbeat<0||state.heartbeat>state.minute)))throw Error('OPS_STATE');
      heartbeat=state.heartbeat;
    }catch(e){if(e.code!=='ENOENT')throw Error('OPS_STATE');}
    return this.transaction(minute,s=>{
      if(heartbeat!==null&&minute-heartbeat<=2)return false;
      const alert={minute,kind:'heartbeat_unavailable',count:1,key:`${minute}:heartbeat_unavailable`};
      if(!s.records.some(r=>r.alert.key===alert.key)){
        if(s.records.length>=limit)throw Error('OPS_CAPACITY');s.records.push({alert,ack:false});
      }return true;
    });
  }
  // Lock spans delivery. Unknown delivery -> retry same key, sink must deduplicate.
  flush(minute,deliver) {return this.transaction(minute,async s=>{
    for(const r of s.records)if(!r.ack){await deliver(Object.freeze({...r.alert}));r.ack=true;}
  });}
  inspect(minute) {return this.transaction(minute,s=>({retained:s.records.length,pending:s.records.filter(r=>!r.ack).length,heartbeat:s.heartbeat}));}
}
export function localDestination(url) {
  const u=new URL(url);
  if(u.protocol!=='http:'||u.hostname!=='127.0.0.1'||u.username||u.password||u.pathname!=='/synthetic-alert'||u.search||u.hash)throw Error('OPS_DESTINATION');
  return async alert=>{
    if(!validAlert(alert))throw Error('OPS_ALERT');
    const response=await fetch(u,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(alert),redirect:'error',signal:AbortSignal.timeout(1000)});
    if(!response.ok||await response.text()!==alert.key)throw Error('OPS_DELIVERY');
  };
}
export function scheduleLocalCleanup(tick,{intervalMs=60000,onFailure=()=>{}}={}) {
  if(!Number.isSafeInteger(intervalMs)||intervalMs<25||intervalMs>60000)throw Error('OPS_INTERVAL');
  let stopped=false, timer, running=Promise.resolve();
  const run=()=>{running=(async()=>{try{await tick();}catch{try{onFailure('MAINTENANCE_UNAVAILABLE');}catch{/* No private error logging or unhandled scheduler rejection. */}}
    if(!stopped)timer=setTimeout(run,intervalMs);})();};
  run();return async()=>{stopped=true;clearTimeout(timer);await running;};
}
// Explicit child mode used only by tests; never starts automatically on import.
if(process.argv[1]&&resolve(process.argv[1])===resolve(import.meta.filename)) {
  const [mode,directory,minuteText]=process.argv.slice(2);
  if(mode!=='watchdog'||dirname(resolve(directory))!==resolve('.cache'))throw Error('OPS_CHILD_SCOPE');
  await new DurableIngressQueue(directory,'watchdog').independentWatchdog(Number(minuteText));
}
