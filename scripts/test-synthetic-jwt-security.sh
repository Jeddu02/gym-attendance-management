#!/usr/bin/env bash
# GYMFORCE: synthetic JWT signature/claims tests with Node built-in crypto.
# No Supabase secrets, no database access, no network, no server.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -z "${SUPABASE_SERVICE_ROLE_KEY:-}${SUPABASE_JWT_SECRET:-}${PGRST_JWT_SECRET:-}${DATABASE_URL:-}${SUPABASE_DB_URL:-}" ]] || { echo 'BLOCKED: inherited production credentials'; exit 2; }
node --input-type=module <<'NODE'
import { createHmac, randomBytes, timingSafeEqual } from 'node:crypto';
import assert from 'node:assert/strict';
const key=randomBytes(48);
const b64=x=>Buffer.from(typeof x==='string'?x:JSON.stringify(x)).toString('base64url');
const sign=(claims,header={alg:'HS256',typ:'JWT'})=>{
 const body=b64(header)+'.'+b64(claims);
 return body+'.'+createHmac('sha256',key).update(body).digest('base64url');
};
const verify=(token,now)=>{
 const parts=token.split('.');
 if(parts.length!==3)throw Error('malformed');
 const header=JSON.parse(Buffer.from(parts[0],'base64url').toString());
 const claims=JSON.parse(Buffer.from(parts[1],'base64url').toString());
 if(header.alg!=='HS256'||header.typ!=='JWT')throw Error('algorithm');
 const expected=createHmac('sha256',key).update(parts[0]+'.'+parts[1]).digest();
 const actual=Buffer.from(parts[2],'base64url');
 if(actual.length!==expected.length||!timingSafeEqual(actual,expected))throw Error('signature');
 if(typeof claims.exp!=='number'||now>=claims.exp)throw Error('expired');
 if(typeof claims.nbf==='number'&&now<claims.nbf)throw Error('not yet valid');
 if(!['anon','authenticated','service_role'].includes(claims.role))throw Error('role');
 return claims;
};
const now=Math.floor(Date.now()/1000);
const good=sign({role:'authenticated',sub:'synthetic-user',iat:now,exp:now+300});
const tests=[
 ['valid HS256',()=>assert.equal(verify(good,now).role,'authenticated')],
 ['expired token rejected',()=>assert.throws(()=>verify(sign({role:'authenticated',exp:now-1}),now))],
 ['future nbf rejected',()=>assert.throws(()=>verify(sign({role:'authenticated',exp:now+300,nbf:now+60}),now))],
 ['wrong algorithm rejected',()=>assert.throws(()=>verify(sign({role:'authenticated',exp:now+300},{alg:'none',typ:'JWT'}),now))],
 ['tampered payload rejected',()=>{const p=good.split('.');p[1]=b64({role:'service_role',exp:now+300});assert.throws(()=>verify(p.join('.'),now))}],
 ['wrong signature rejected',()=>{const p=good.split('.');p[2]=b64(randomBytes(32));assert.throws(()=>verify(p.join('.'),now))}],
 ['unknown role rejected',()=>assert.throws(()=>verify(sign({role:'postgres',exp:now+300}),now))],
 ['malformed token rejected',()=>assert.throws(()=>verify('abc.def',now))]
];
for(const [name,run] of tests){run();console.log('PASS: '+name)}
console.log('PASS: 8/8 synthetic JWT crypto/claims tests; ephemeral key never printed or saved');
console.log('NOT VERIFIED: PostgREST JWT validation, real Supabase Auth, or HTTP RPC behavior');
NODE
