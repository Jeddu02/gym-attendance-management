"""Synthetic-only rehearsal of the production 20 -> 24 prefix and post-core hardening.
No hosted connection mode. Never use a real database or real data.
"""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
BASE = "6298d2ece6d71bf3eeb08d893c763de9cf0eeca2"
spec = importlib.util.spec_from_file_location("staging_runner", ROOT / "scripts/recovery/rehearse-or-deploy-staging.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
HISTORY = runner.HISTORY
ROLE_NAMES = "('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor')"

def source(path, sha=None):
    p = ROOT / path
    raw = p.read_bytes()
    pinned = subprocess.check_output(["git", "show", f"{BASE}:{path}"], cwd=ROOT)
    if raw != pinned:
        raise ValueError("Source differs from accepted Git blob")
    if sha and hashlib.sha256(raw).hexdigest() != sha:
        raise ValueError("Additive source hash mismatch")
    return raw.decode("utf-8-sig")

def body(sql):
    sql = sql.replace("\r\n", "\n")
    # Permit comments before the unique top-level BEGIN. Source bytes pinned above.
    if len(re.findall(r"^BEGIN;$",sql,re.M)) != 1 or len(re.findall(r"^COMMIT;$",sql,re.M)) != 1 or not sql.endswith("COMMIT;\n"):
        raise ValueError("Unexpected transaction boundaries")
    return sql[:sql.rindex("COMMIT;\n")].replace("BEGIN;\n","",1)

def run(sql):
    runner.psql(runner.connection(True), sql)

def guard_prefix(expected):
    rows = ",".join(f"({runner.literal(v)},{runner.literal(n)})" for v,n in expected)
    return f"""DO $prefix$ BEGIN
    IF current_database()<>'postgres' OR current_user<>'postgres' OR session_user<>'postgres'
      OR current_setting('server_version_num')::int/10000<>17
      OR (SELECT count(*) FROM {HISTORY})<>{len(expected)}
      OR EXISTS(SELECT 1 FROM (VALUES {rows}) wanted(v,n)
         WHERE (SELECT count(*) FROM {HISTORY} h WHERE h.version=wanted.v AND h.name=wanted.n)<>1)
      OR EXISTS(SELECT 1 FROM pg_roles WHERE rolname IN {ROLE_NAMES})
      OR EXISTS(SELECT 1 FROM auth.users)
      THEN RAISE EXCEPTION 'Disposable production-prefix baseline differs'; END IF;
    END $prefix$;"""

def prefix():
    baseline,steps,checked=runner.verified_package()
    expected=[tuple(name.split("_",1)) for name,_ in baseline[:20]]
    run("BEGIN READ ONLY;\n"+guard_prefix(expected)+"\nROLLBACK;")
    # Model the observed pre-existing plan routines and index without recording history.
    plan_path="supabase/migrations/"+baseline[20][0]+".sql"
    plan=source(plan_path)
    run("BEGIN;\nSET LOCAL lock_timeout='2s';\nSET LOCAL statement_timeout='30s';\n"+guard_prefix(expected)+"\n"+body(plan)+"\nCOMMIT;")
    print("Synthetic fixture: unrecorded plan objects created.",flush=True)
    for name,_ in baseline[20:24]:
        v,n=name.split("_",1)
        sql=source("supabase/migrations/"+name+".sql")
        insert=f"INSERT INTO {HISTORY}(version,name,statements) VALUES ({runner.literal(v)},{runner.literal(n)},ARRAY[{runner.stored_source(sql)}]);"
        run("BEGIN;\nSET LOCAL lock_timeout='2s';\nSET LOCAL statement_timeout='30s';\n"+f"LOCK TABLE {HISTORY} IN SHARE ROW EXCLUSIVE MODE;\n"+guard_prefix(expected)+"\n"+body(sql)+"\n"+insert+"\nCOMMIT;")
        expected.append((v,n))
        run("BEGIN READ ONLY;\n"+guard_prefix(expected)+f"\nDO $record$ BEGIN IF NOT EXISTS(SELECT 1 FROM {HISTORY} WHERE version={runner.literal(v)} AND name={runner.literal(n)} AND cardinality(statements)=1 AND encode(sha256(convert_to(statements[1],'UTF8')),'hex')={runner.literal(hashlib.sha256(sql.encode()).hexdigest())}) THEN RAISE EXCEPTION 'Exact source history missing'; END IF; END $record$;\nROLLBACK;")
        print("PASS prefix "+v,flush=True)
    # Full conditional payment checks are now executable, after P04.
    q=source("docs/production-preflight/07-lifecycle-payment-blockers.sql")
    # The query returns only PASS/FAIL; convert its final SELECT into an assertion.
    old="SELECT x.check_name,CASE WHEN v.complete IS DISTINCT FROM true THEN 'UNKNOWN'\n WHEN x.ok THEN 'PASS' ELSE 'FAIL' END AS result\nFROM visibility v CROSS JOIN facts f CROSS JOIN LATERAL (VALUES"
    new="SELECT x.check_name,CASE WHEN v.complete IS DISTINCT FROM true THEN 'UNKNOWN'\n WHEN x.ok THEN 'PASS' ELSE 'FAIL' END AS result\nFROM visibility v CROSS JOIN facts f CROSS JOIN LATERAL (VALUES"
    # Use the reviewed query unchanged, verify output in a separate bounded call.
    if old not in q: raise ValueError("Payment check shape changed")
    env={k:v for k,v in os.environ.items() if not k.startswith("PG")}
    env.update(PGPASSWORD=runner.connection(True)[4],PGSSLMODE="disable",PGCONNECT_TIMEOUT="10")
    out=subprocess.check_output(["psql","-X","-w","-qAt","-v","ON_ERROR_STOP=1","-h","127.0.0.1","-p","54322","-U","postgres","-d","postgres"],input=q,text=True,env=env)
    rows=out.strip().splitlines()
    if len(rows)!=5 or any(not line.endswith("|PASS") for line in rows): raise ValueError("Conditional payment prerequisites failed")
    print("PASS all five conditional lifecycle/payment checks after P04.",flush=True)

def graph():
    return f"""DO $graph$ BEGIN
    IF current_database()<>'postgres' OR current_user<>'postgres' OR session_user<>'postgres'
     OR current_setting('server_version_num')::int/10000<>17
     OR NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname=current_user AND NOT rolsuper AND rolcreaterole)
     OR (SELECT count(*) FROM {HISTORY})<>37
     OR (SELECT count(*) FROM pg_roles WHERE rolname IN {ROLE_NAMES})<>4
     OR EXISTS(SELECT 1 FROM pg_roles r WHERE r.rolname IN {ROLE_NAMES} AND (rolcanlogin OR rolsuper OR rolcreatedb OR rolcreaterole OR rolinherit OR rolreplication OR rolbypassrls OR pg_has_role('postgres',r.oid,'SET') OR pg_has_role('postgres',r.oid,'USAGE')))
     OR EXISTS(SELECT 1 FROM pg_auth_members m WHERE (m.roleid IN (SELECT oid FROM pg_roles WHERE rolname IN {ROLE_NAMES}) OR m.member IN (SELECT oid FROM pg_roles WHERE rolname IN {ROLE_NAMES})) AND NOT (m.roleid IN (SELECT oid FROM pg_roles WHERE rolname IN {ROLE_NAMES}) AND m.member='postgres'::regrole AND m.grantor='supabase_admin'::regrole AND m.admin_option AND NOT m.set_option AND NOT m.inherit_option))
     OR EXISTS(SELECT 1 FROM pg_roles r WHERE r.rolname IN {ROLE_NAMES} AND (SELECT count(*) FROM pg_auth_members m WHERE m.roleid=r.oid AND m.member='postgres'::regrole AND m.grantor='supabase_admin'::regrole AND m.admin_option AND NOT m.set_option AND NOT m.inherit_option)<>1)
     OR EXISTS(SELECT 1 FROM pg_roles r CROSS JOIN pg_namespace n WHERE r.rolname IN {ROLE_NAMES} AND n.nspname IN ('private','api','public','extensions') AND has_schema_privilege(r.oid,n.oid,'CREATE'))
     OR EXISTS(SELECT 1 FROM pg_policy WHERE polname IN ('gf_compatibility_read','gf_recovery_review_read'))
     THEN RAISE EXCEPTION 'Unexpected isolated authority/history boundary'; END IF;
    END $graph$;"""

def defaults():
    # Global PUBLIC EXECUTE only; no existing-object grants or provider defaults changed.
    run("BEGIN;\nSET LOCAL statement_timeout='30s'; SET LOCAL lock_timeout='2s'; SET LOCAL search_path=pg_catalog;\n"+graph()+"""
    CREATE TEMP TABLE gf_acl_before ON COMMIT DROP AS SELECT oid,proacl FROM pg_proc;
    ALTER DEFAULT PRIVILEGES FOR ROLE postgres REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
    CREATE FUNCTION private.gf_review_acl_probe() RETURNS integer LANGUAGE sql AS 'SELECT 1';
    DO $verify$ BEGIN
      IF EXISTS(SELECT 1 FROM pg_temp.gf_acl_before b LEFT JOIN pg_proc p USING(oid) WHERE p.oid IS NULL OR b.proacl IS DISTINCT FROM p.proacl)
       OR EXISTS(SELECT 1 FROM aclexplode((SELECT defaclacl FROM pg_default_acl WHERE defaclrole='postgres'::regrole AND defaclnamespace=0 AND defaclobjtype='f')) a WHERE a.grantee=0 AND a.privilege_type='EXECUTE')
       OR has_function_privilege('anon','private.gf_review_acl_probe()','EXECUTE')
       OR has_function_privilege('authenticated','private.gf_review_acl_probe()','EXECUTE')
       OR has_function_privilege('service_role','private.gf_review_acl_probe()','EXECUTE')
       THEN RAISE EXCEPTION 'Default privilege correction failed'; END IF;
    END $verify$;
    DROP FUNCTION private.gf_review_acl_probe();
    COMMIT;""")
    print("PASS global postgres future-function PUBLIC revoke; existing ACLs unchanged.",flush=True)

def addon(path,sha,ingress=False):
    sql=source(path,sha)
    preparation="""GRANT gym_data_owner,gym_public_executor TO postgres WITH ADMIN FALSE, INHERIT TRUE, SET TRUE GRANTED BY postgres;
    GRANT CREATE ON SCHEMA private TO gym_data_owner;
    GRANT CREATE ON SCHEMA api TO gym_public_executor;"""
    maintenance="""CREATE POLICY gf_recovery_review_read ON private.walkin_creation_operations FOR SELECT TO postgres USING (current_user='postgres'::name AND session_user='postgres'::name);""" if ingress else ""
    cleanup=("DROP POLICY gf_recovery_review_read ON private.walkin_creation_operations;\n" if ingress else "")+"""
    REVOKE CREATE ON SCHEMA private FROM gym_data_owner;
    REVOKE CREATE ON SCHEMA api FROM gym_public_executor;
    REVOKE gym_data_owner,gym_public_executor FROM postgres GRANTED BY postgres;"""
    run("BEGIN;\nSET LOCAL statement_timeout='30s'; SET LOCAL lock_timeout='2s'; SET LOCAL search_path=pg_catalog;\n"+graph()+"\n"+preparation+"\n"+maintenance+"\n"+body(sql)+"\n"+cleanup+"\n"+graph()+"\nCOMMIT;")
    print("PASS synthetic additive migration and privilege closure: "+Path(path).name,flush=True)

def postcore():
    runner.verified_package()
    defaults()
    addon("supabase/recovery/phase61/001-public-walkin-recovery.sql","abd015b369a7e3c78b269df9133ca1d3895afe109c292cf3c7b6e8b789955ab3")
    addon("supabase/recovery/phase61b/002-public-ingress.sql","6b46a533005eb43e5a1dc2777ab51063d6e1b32c7ae7a4447795830eeb0ce7cb",True)
    # These reviewed assertions are read-only; the final one contains psql echo.
    for path in ("supabase/recovery/compatibility/review/final_security_assertions.sql",):
        run(source(path))
    print("PASS post-additive core security assertions. Hosted release gate remains closed.",flush=True)

if __name__=="__main__":
    if os.environ.get("GITHUB_ACTIONS")!="true" or os.environ.get("GITHUB_REF")!="refs/heads/validation/recovery-rehearsal":
        raise SystemExit("Refusing: isolated GitHub rehearsal branch only.")
    if len(sys.argv)!=2 or sys.argv[1] not in ("prefix","postcore"):
        raise SystemExit("Only disposable prefix/postcore modes exist.")
    try:
        (prefix if sys.argv[1]=="prefix" else postcore)()
    except (ValueError,KeyError,OSError,subprocess.CalledProcessError):
        raise SystemExit("Synthetic rehearsal stopped; no hosted release authorized.") from None
