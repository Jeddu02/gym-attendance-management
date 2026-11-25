"""Disposable local PostgREST qualification. Never contacts hosted services."""
import importlib.util
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import time
import urllib.error
import urllib.request

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location("candidate",ROOT/"scripts/recovery/rehearse-production-candidate.py")
candidate=importlib.util.module_from_spec(spec)
spec.loader.exec_module(candidate)
SIGNATURES=("public_walkin_admit()","public_walkin_bind(uuid,bytea,text,text)","public_walkin_execute(uuid,bytea,text,text)","public_walkin_finish(uuid,text)","public_walkin_observe(text)")
PROBES=("gf_review_sleep_probe()","gf_review_lock_probe()")
HOST="http://127.0.0.1:54321"
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,*args,**kwargs):
        return None
OPENER=urllib.request.build_opener(urllib.request.ProxyHandler({}),NoRedirect())

def local_keys():
    s=subprocess.check_output(["supabase","status","-o","env"],cwd=ROOT,text=True,stderr=subprocess.DEVNULL)
    vals={}
    for line in s.splitlines():
        k,eq,v=line.partition("=")
        if eq and k in ("API_URL","ANON_KEY","SERVICE_ROLE_KEY"):
            parsed=shlex.split(v)
            if len(parsed)!=1: raise ValueError("Unexpected local status")
            vals[k]=parsed[0]
    if vals.get("API_URL") not in (HOST,"http://localhost:54321"):
        raise ValueError("Unexpected local API target")
    if any(not vals.get(k) for k in ("ANON_KEY","SERVICE_ROLE_KEY")):
        raise ValueError("Disposable JWTs unavailable")
    return vals

def rpc(key,name,args):
    if not re.fullmatch(r"[a-z_]+",name): raise ValueError("Unapproved RPC route")
    req=urllib.request.Request(HOST+"/rest/v1/rpc/"+name,
        data=json.dumps(args).encode(),headers={"apikey":key,"Authorization":"Bearer "+key,
        "Content-Type":"application/json","Accept-Profile":"api","Content-Profile":"api"},method="POST")
    try:
        with OPENER.open(req,timeout=8) as response:
            b=response.read(65536)
            return response.status,json.loads(b) if b else None
    except urllib.error.HTTPError as e:
        b=e.read(65536)
        try: error=json.loads(b)
        except ValueError: error={}
        return e.code,{"code":error.get("code")}
def expect(result,status,code=None):
    if result[0]!=status or (code is not None and result[1].get("code")!=code):
        raise ValueError("Unexpected sanitized HTTP result: status="+str(result[0])+" code="+str(result[1].get("code") if isinstance(result[1],dict) else None))
    return result[1]
def configure():
    pre="""GRANT gym_public_executor TO postgres WITH ADMIN FALSE, INHERIT TRUE, SET TRUE GRANTED BY postgres;
    GRANT CREATE ON SCHEMA api TO gym_public_executor;"""
    post="""REVOKE CREATE ON SCHEMA api FROM gym_public_executor;
    REVOKE gym_public_executor FROM postgres GRANTED BY postgres;"""
    alter=[]
    for name in SIGNATURES+PROBES:
        ms,lock=(5000,500) if name.startswith("public_walkin_execute(") else (1000,100)
        alter.extend([f"ALTER FUNCTION api.{name} SET statement_timeout TO '{ms}ms';",
                      f"ALTER FUNCTION api.{name} SET lock_timeout TO '{lock}ms';"])
    sql="""BEGIN;
    SET LOCAL search_path=pg_catalog; SET LOCAL statement_timeout='30s'; SET LOCAL lock_timeout='2s';
    """+candidate.graph()+"\n"+pre+"""
    CREATE FUNCTION api.gf_review_sleep_probe() RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $p$
    BEGIN PERFORM pg_catalog.pg_sleep(2); RETURN true; END $p$;
    CREATE FUNCTION api.gf_review_lock_probe() RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $p$
    BEGIN PERFORM pg_catalog.pg_advisory_xact_lock(7459911); RETURN true; END $p$;
    ALTER FUNCTION api.gf_review_sleep_probe() OWNER TO gym_public_executor;
    ALTER FUNCTION api.gf_review_lock_probe() OWNER TO gym_public_executor;
    REVOKE ALL ON FUNCTION api.gf_review_sleep_probe(),api.gf_review_lock_probe() FROM PUBLIC,anon,authenticated,service_role;
    GRANT EXECUTE ON FUNCTION api.gf_review_sleep_probe(),api.gf_review_lock_probe() TO service_role;
    """+"\n".join(alter)+"\n"+post+"\n"+candidate.graph()+"""
    -- Disposable project only. Keep existing default hoisted settings, add lock_timeout.
    -- Do not infer that this customer setting is available in a hosted project.
    ALTER ROLE authenticator SET pgrst.db_hoisted_tx_settings='statement_timeout,plan_filter.statement_cost_limit,default_transaction_isolation,lock_timeout';
    NOTIFY pgrst,'reload config';
    NOTIFY pgrst,'reload schema';
    COMMIT;"""
    candidate.run(sql)
def cleanup():
    candidate.run("BEGIN;\n"+candidate.graph()+"""
    GRANT gym_public_executor TO postgres WITH ADMIN FALSE, INHERIT TRUE, SET TRUE GRANTED BY postgres;
    DROP FUNCTION api.gf_review_sleep_probe(),api.gf_review_lock_probe();
    REVOKE gym_public_executor FROM postgres GRANTED BY postgres;
    """+candidate.graph()+"\nNOTIFY pgrst,'reload schema';\nCOMMIT;")
def blocker():
    env={k:v for k,v in os.environ.items() if not k.startswith("PG")}
    env.update(PGPASSWORD=candidate.runner.connection(True)[4],PGSSLMODE="disable",PGCONNECT_TIMEOUT="10")
    p=subprocess.Popen(["psql","-X","-w","-qAt","-v","ON_ERROR_STOP=1","-h","127.0.0.1","-p","54322","-U","postgres","-d","postgres"],
                       text=True,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,env=env,bufsize=1)
    p.stdin.write("SELECT 'READY' FROM pg_advisory_lock(7459911);\n")
    p.stdin.flush()
    import select
    end=time.monotonic()+8
    while time.monotonic()<end:
        ready,_,_=select.select([p.stdout],[],[],max(0,end-time.monotonic()))
        if not ready: break
        line=p.stdout.readline()
        if line.strip()=="READY": return p
        if p.poll() is not None: break
    p.kill();p.wait()
    raise ValueError("Disposable lock holder did not become ready")

def synthetic_owner(service):
    import secrets
    import uuid
    req=urllib.request.Request(HOST+"/auth/v1/admin/users",method="POST",
        headers={"apikey":service,"Authorization":"Bearer "+service,"Content-Type":"application/json"},
        data=json.dumps({"email":f"gymforce-ci-{uuid.uuid4().hex}@example.invalid",
                         "password":secrets.token_urlsafe(32),"email_confirm":True}).encode())
    with OPENER.open(req,timeout=8) as response:
        actor=json.loads(response.read(65536))["id"]
    if str(uuid.UUID(actor))!=actor:raise ValueError("Unexpected synthetic Auth user")
    candidate.run("BEGIN;\nSET LOCAL search_path=pg_catalog;\n"+candidate.graph()+"""
    GRANT gym_data_owner TO postgres WITH ADMIN FALSE, INHERIT TRUE, SET TRUE GRANTED BY postgres;
    DO $fixture$ BEGIN
      IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname=current_user AND rolbypassrls)
        OR row_security_active('private.owner_access'::regclass)
        THEN RAISE EXCEPTION 'Synthetic fixture visibility unavailable'; END IF;
    END $fixture$;
    INSERT INTO private.owner_access(user_id,is_active) VALUES ("""+candidate.runner.literal(actor)+""",true);
    REVOKE gym_data_owner FROM postgres GRANTED BY postgres;
    """+candidate.graph()+"\nCOMMIT;")
    expect(rpc(service,"owner_set_walkin_fee",{"p_actor_user_id":actor,"p_fee_php":125,"p_reason":"Synthetic integration fixture"}),200)

def snapshot():
    env={k:v for k,v in os.environ.items() if not k.startswith("PG")}
    env.update(PGPASSWORD=candidate.runner.connection(True)[4],PGSSLMODE="disable",PGCONNECT_TIMEOUT="10")
    names=("payment_records","payment_allocations","payment_events","attendance_checkins","audit_events","members","membership_purchases")
    hash_queries=",".join("(SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.id),'[]'::jsonb) FROM private."+n+" x)" for n in names)
    q="BEGIN;\nSET LOCAL search_path=pg_catalog;\n"+candidate.graph()+"""
    GRANT gym_data_owner TO postgres WITH ADMIN FALSE, INHERIT TRUE, SET TRUE GRANTED BY postgres;
    DO $fixture$ BEGIN
      IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname=current_user AND rolbypassrls)
        OR EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
             WHERE n.nspname='private' AND c.relkind IN ('r','p') AND row_security_active(c.oid))
      THEN RAISE EXCEPTION 'Incomplete synthetic fixture visibility'; END IF;
    END $fixture$;
    SELECT jsonb_build_object('requests',(SELECT count(*) FROM private.walkin_requests),
      'bindings',(SELECT count(*) FROM private.walkin_creation_operations),
      'protected_digest',encode(sha256(convert_to(jsonb_build_array("""+hash_queries+""")::text,'UTF8')),'hex'),
      'attempts',(SELECT day_attempts FROM private.walkin_ingress_state WHERE id=1));
    ROLLBACK;"""
    out=subprocess.check_output(["psql","-X","-w","-qAt","-v","ON_ERROR_STOP=1","-h","127.0.0.1","-p","54322","-U","postgres","-d","postgres"],input=q,text=True,env=env)
    return json.loads(out)

def native_edge(service):
    import base64
    synthetic_owner(service)
    before=snapshot()
    entry=ROOT/"supabase/functions/public-walkin-recovery/index.ts"
    # The exact loopback-restricted handler is unchanged. Dependency acquisition
    # happens before runtime; execution is restricted to the local HTTP stack.
    candidate.source("supabase/functions/public-walkin-recovery/index.ts")
    subprocess.run(["deno","cache","--frozen",str(entry)],cwd=ROOT,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=True)
    env={k:v for k,v in os.environ.items() if k in ("PATH","HOME","DENO_DIR","TMPDIR")}
    origin="http://127.0.0.1:3000"
    env.update(APP_ORIGIN=origin,SUPABASE_URL=HOST,SUPABASE_SERVICE_ROLE_KEY=service,
               PUBLIC_WALKIN_ENABLED="true",WALKIN_REQUEST_LIMIT_PER_MINUTE="10")
    server=subprocess.Popen(["deno","run","--frozen","--cached-only",
        "--allow-net=0.0.0.0:8000,127.0.0.1:54321",
        "--allow-env=APP_ORIGIN,SUPABASE_URL,SUPABASE_SERVICE_ROLE_KEY,PUBLIC_WALKIN_ENABLED,WALKIN_REQUEST_LIMIT_PER_MINUTE",
        str(entry)],cwd=ROOT,env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    def edge(data=None,method="POST",allowed_origin=origin):
        req=urllib.request.Request("http://127.0.0.1:8000/public-walkin-recovery",method=method,
            headers={"Origin":allowed_origin,"Content-Type":"application/json"},
            data=json.dumps(data).encode() if data is not None else None)
        try:
            with OPENER.open(req,timeout=12) as response:
                b=response.read(65536)
                return response.status,json.loads(b) if b else None
        except urllib.error.HTTPError as e:
            b=e.read(65536)
            try: body=json.loads(b)
            except ValueError: body={}
            return e.code,body
    def edge_expect(data,status):
        result=edge(data)
        if result[0]!=status:raise ValueError("Native Edge unexpected HTTP status "+str(result[0]))
        return result[1]
    def key(n):return base64.urlsafe_b64encode(bytes([n])*32).decode().rstrip("=")
    try:
        for _ in range(30):
            if server.poll() is not None:raise ValueError("Native Edge exited during startup")
            try:
                if edge(method="OPTIONS")[0]==204:break
            except urllib.error.URLError:pass
            time.sleep(.5)
        else:raise ValueError("Native Edge loopback startup failed")
        if edge({"action":"lookup","capability":key(9)},allowed_origin="https://invalid.example")[0]!=403:
            raise ValueError("Cross-origin refusal missing")
        cash={"action":"create","capability":key(7),"paymentMethod":"cash"}
        first=edge_expect(cash,201)
        if first.get("classification")!="PROVISIONAL_CREATED" or first.get("success") is not True:
            raise ValueError("Unexpected first classification")
        if set(first["request"])!={"id","feePhp","currency","paymentMethod","createdAt","expiresAt"}:
            raise ValueError("Provisional response shape changed")
        if first["request"]["feePhp"]!="125.00" or first["request"]["paymentMethod"]!="cash":
            raise ValueError("Server fee or payment method mismatch")
        replay=edge_expect(cash,200)
        if replay.get("classification")!="PROVISIONAL_RECOVERED" or replay["request"]!=first["request"]:
            raise ValueError("Cash replay did not recover the same operation")
        conflict=edge_expect(dict(cash,paymentMethod="gcash"),409)
        if conflict!={"error":"OPERATION_CONFLICT"}:raise ValueError("Conflicting method exposed a snapshot")
        gcash={"action":"create","capability":key(8),"paymentMethod":"gcash"}
        second=edge_expect(gcash,201)
        if second["request"]["paymentMethod"]!="gcash" or second["request"]["id"]==first["request"]["id"]:
            raise ValueError("GCash creation identity invalid")
        if edge_expect(gcash,200)["request"]!=second["request"]:
            raise ValueError("GCash replay mismatch")
        # The three-token local key bucket must refill before another cash lookup.
        time.sleep(5.5)
        if edge_expect({"action":"lookup","capability":key(7)},200)["request"]!=first["request"]:
            raise ValueError("Lookup changed immutable snapshot")
        if edge_expect({"action":"lookup","capability":key(9)},404)!={"error":"NO_RECOVERABLE_OUTCOME"}:
            raise ValueError("Unknown capability disclosed data")
        edge_expect({"action":"create"},400)
        after=snapshot()
        if after["requests"]!=before["requests"]+2 or after["bindings"]!=before["bindings"]+2 or after["protected_digest"]!=before["protected_digest"]:
            raise ValueError("Unexpected persisted request or protected-record changes")
        if after["attempts"]!=before["attempts"]+8:
            raise ValueError("All-attempt charge mismatch")
        print("PASS native unchanged Edge handler -> real PostgREST -> persisted SQL: cash/GCash creation and same-key replay, conflicting method, lookup, malformed input and CORS refusal; exactly two provisional requests, no financial/attendance/audit changes.",flush=True)
    finally:
        server.terminate()
        try:server.wait(timeout=5)
        except subprocess.TimeoutExpired:server.kill();server.wait()

def main():
    if os.environ.get("GITHUB_ACTIONS")!="true" or os.environ.get("GITHUB_REF")!="refs/heads/validation/recovery-rehearsal":
        raise ValueError("Isolated CI only")
    keys=local_keys()
    service=keys["SERVICE_ROLE_KEY"]
    anon=keys["ANON_KEY"]
    configure()
    # Cache reload is asynchronous; retry only this non-mutating probe on missing routine.
    for _ in range(12):
        start=time.monotonic()
        result=rpc(service,"gf_review_sleep_probe",{})
        if result[0]==404 and result[1].get("code")=="PGRST202":
            time.sleep(1);continue
        expect(result,500,"57014")
        if time.monotonic()-start>=2: raise ValueError("Statement deadline did not cancel the actual query")
        break
    else: raise ValueError("PostgREST cache did not reload")
    print("PASS PostgREST actual statement timeout cancels sleeping SQL, not just the HTTP client.",flush=True)
    p=blocker()
    try:
        start=time.monotonic()
        expect(rpc(service,"gf_review_lock_probe",{}),500,"55P03")
        if time.monotonic()-start>=1: raise ValueError("Lock timeout did not bound actual lock wait")
    finally:
        p.stdin.close()
        try:p.wait(timeout=3)
        except subprocess.TimeoutExpired:p.kill();p.wait()
    print("PASS PostgREST actual lock timeout under a competing database session.",flush=True)
    # Real RPCs, separate HTTP requests and commits. Unknown-key lookup requires no fee or Owner fixture.
    admission=expect(rpc(service,"public_walkin_admit",{}),200)
    if admission.get("status")!="allowed" or not re.fullmatch(r"[0-9a-f-]{36}",admission.get("ticket","")):
        raise ValueError("Admission not granted")
    args={"p_ticket":admission["ticket"],"p_digest":"\\x"+"a7"*32,"p_action":"lookup","p_method":None}
    if expect(rpc(service,"public_walkin_bind",args),200).get("status")!="allowed":
        raise ValueError("Binding failed")
    if expect(rpc(service,"public_walkin_execute",args),200)!={"classification":"NO_RECOVERABLE_OUTCOME"}:
        raise ValueError("Unknown key leaked or created an operation")
    reused=rpc(service,"public_walkin_execute",args)
    if reused[0] not in (401,403) or reused[1].get("code")!="42501":
        raise ValueError("Consumed ticket was not denied")
    if rpc(anon,"public_walkin_admit",{})[0] not in (401,403,404):
        raise ValueError("Anonymous caller obtained admission")
    if rpc(service,"public_create_walkin_request",{"p_payment_method":"cash","p_request_limit":10})[0] not in (401,403,404):
        raise ValueError("Legacy ungated transport remained accessible")
    print("PASS actual PostgREST independent admission/bind/execute, unknown-key privacy, consumed-ticket denial, anonymous and old-route refusal.",flush=True)
    cleanup()
    candidate.run(candidate.source("supabase/recovery/compatibility/review/final_security_assertions.sql"))
    print("PASS final security after probe cleanup. No hosted or Edge deployment.",flush=True)
    native_edge(service)
    candidate.run(candidate.source("supabase/recovery/compatibility/review/final_security_assertions.sql"))
if __name__=="__main__":
    try:main()
    except (ValueError,KeyError,OSError,subprocess.CalledProcessError) as e:
        # Do not output credentials, request URLs from exceptions, or response bodies.
        if isinstance(e,ValueError): print(str(e),flush=True)
        raise SystemExit("Local HTTP qualification stopped. Hosted gate remains closed.") from None
