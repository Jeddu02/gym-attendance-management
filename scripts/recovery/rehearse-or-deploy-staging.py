"""Apply the 13 reviewed Supabase compatibility artifacts with psql."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT / "supabase/recovery/compatibility/review"
MANIFEST_SHA256 = "a2eb9a493ab59819e2846bd43d75b22f2aa03df4028abed9d32c78d435571093"
STAGING = "yucmfsjvjskefrxfhtbd"
HISTORY = "supabase_migrations.schema_migrations"


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def literal(value):
    return "'" + value.replace("'", "''") + "'"


def stored_source(sql):
    tag = "$gymforce_reviewed_artifact$"
    if tag in sql:
        raise ValueError("Artifact collides with the history SQL delimiter")
    return f"{tag}{sql}{tag}"


def verified_package():
    raw = (REVIEW / "manifest.json").read_bytes()
    if sha256(raw) != MANIFEST_SHA256:
        raise ValueError("Reviewed manifest fingerprint mismatch")
    manifest = json.loads(raw)
    source = manifest["sourceManifest"]
    if len(source) != 37:
        raise ValueError("Expected 37 historical migration identities")
    baseline = []
    for item in source[:24]:
        path = ROOT / "supabase/migrations" / item["file"]
        baseline.append((path.stem, sha256(path.read_bytes().removeprefix(b"\xef\xbb\xbf"))))
    checked = {}
    for item in manifest["records"]:
        path = REVIEW / item["file"]
        raw_sql = path.read_bytes()
        if sha256(raw_sql) != item["compatibilitySha256"]:
            raise ValueError(f"Artifact fingerprint mismatch for {path.name}")
        checked[path.name] = (item, raw_sql.decode("utf-8"))
    steps = []
    for source_item in source[24:]:
        filename = source_item["file"]
        item, sql = checked[filename]
        body_hash = item["compatibilitySha256"]
        if item["originalSha256"] != source_item["sha256"] or (
            f"source SHA-256={source_item['sha256']}\n" not in sql
        ):
            raise ValueError(f"Source provenance mismatch for {filename}")
        if len(re.findall(r"^BEGIN;$", sql, re.M)) != 1 or (
            len(re.findall(r"^COMMIT;$", sql, re.M)) != 1 or not sql.endswith("COMMIT;\n")
        ):
            raise ValueError(f"Unexpected transaction boundary in {filename}")
        steps.append((Path(filename).stem, body_hash, sql))
    return baseline, steps, checked


def connection(disposable):
    if disposable:
        return "127.0.0.1", "postgres", "54322", "disable", os.environ["GYMFORCE_DISPOSABLE_DB_PASSWORD"]
    address = urlsplit(os.environ["GYMFORCE_STAGING_DB_URL"])
    if (address.scheme not in ("postgres", "postgresql") or address.port != 5432
            or address.path != "/postgres" or address.fragment or not address.password):
        raise ValueError("Expected the staging direct or session-mode PostgreSQL URL")
    user, host = address.username, address.hostname
    direct = user == "postgres" and host == f"db.{STAGING}.supabase.co"
    session = user == f"postgres.{STAGING}" and re.fullmatch(
        r"aws-[0-9]+-ap-northeast-1\.pooler\.supabase\.com", host or ""
    )
    if not (direct or session):
        raise ValueError("Connection identity does not match the Tokyo staging project")
    return host, user, "5432", "verify-full", unquote(address.password)


def psql(session, sql):
    host, user, port, sslmode, password = session
    env = {name: value for name, value in os.environ.items() if not name.startswith("PG")}
    env.update(PGPASSWORD=password, PGSSLMODE=sslmode, PGCONNECT_TIMEOUT="10",
               PGSSLROOTCERT=str(ROOT / "scripts/recovery/certs/supabase-root-2021-ca.crt"))
    subprocess.run(
        ["psql", "-X", "-w", "-qAt", "-v", "ON_ERROR_STOP=1", "-v", "VERBOSITY=sqlstate",
         "-h", host, "-p", port, "-U", user, "-d", "postgres", "--file=-"],
        input=sql, text=True, env=env, check=True,
        stdout=subprocess.DEVNULL,
    )


def history_check(baseline, finished, disposable):
    expected = [(name, digest) for name, digest in baseline + finished]
    if disposable:
        # Local Supabase CLI stores baseline names without their version prefix
        # and splits the executed SQL into an array of individual statements.
        expected = [(name.split("_", 1)[1], None) for name, _ in baseline] + finished
    expected_rows = ", ".join(
        f"({literal(name)}, {literal(digest) if digest else 'NULL'}::text)"
        for name, digest in expected
    )
    return f"""
DO $gf_history_check$ BEGIN
  IF (SELECT count(*) FROM {HISTORY}) <> {len(expected)}
     OR EXISTS (
      SELECT 1 FROM (VALUES {expected_rows}) AS wanted(name, digest)
      WHERE (SELECT count(*) FROM {HISTORY} AS actual
             WHERE actual.name=wanted.name
               AND (wanted.digest IS NULL OR
                 (cardinality(actual.statements)=1 AND
                  encode(sha256(convert_to(actual.statements[1], 'UTF8')), 'hex')=wanted.digest))) <> 1
     ) THEN
    RAISE EXCEPTION 'Migration history differs from the reviewed prefix';
  END IF;
END $gf_history_check$;
"""


def verify_target():
    return """
DO $gf_target$ BEGIN
  IF current_database()<>'postgres' OR current_user<>'postgres' OR session_user<>'postgres'
     OR current_setting('server_version_num')::int / 10000 <> 17
     OR NOT has_table_privilege(current_user, 'supabase_migrations.schema_migrations', 'INSERT')
     OR (SELECT count(*) FROM pg_roles WHERE rolname IN
         ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor')) <> 0
     OR (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
         WHERE n.nspname IN ('api','private')) <> 25
     OR (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
         WHERE n.nspname='private' AND c.relkind='S') <> 3
     OR (SELECT count(*) FROM public.gym_settings) <> 2
     OR (SELECT count(*) FROM auth.users) <> 0 THEN
    RAISE EXCEPTION 'Unexpected PostgreSQL identity or baseline';
  END IF;
END $gf_target$;
"""


def history_insert(name, sql):
    return f"""
SET LOCAL TIME ZONE 'UTC';
INSERT INTO {HISTORY}(version, name, statements)
SELECT to_char(greatest(date_trunc('second', clock_timestamp()),
              to_timestamp(max(version), 'YYYYMMDDHH24MISS') + interval '1 second')
              AT TIME ZONE 'UTC', 'YYYYMMDDHH24MISS'),
       {literal(name)}, ARRAY[{stored_source(sql)}]
FROM {HISTORY};
"""


def postcondition(sql, index):
    role_count = 4 if index >= 7 else 3
    names = set(re.findall(r"(?im)^CREATE (?:OR REPLACE )?FUNCTION (api|private)\.(\w+)\s*\(", sql))
    tables = set(re.findall(r"(?im)^CREATE TABLE (private)\.(\w+)\s*\(", sql))
    routine_checks = "\n".join(
        f"IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace "
        f"WHERE n.nspname={literal(schema)} AND p.proname={literal(name)}) THEN "
        f"RAISE EXCEPTION 'Reviewed routine missing after commit'; END IF;"
        for schema, name in sorted(names)
    )
    table_checks = "\n".join(
        f"IF NOT EXISTS (SELECT 1 FROM pg_class WHERE oid=to_regclass({literal(schema + '.' + name)}) "
        f"AND relrowsecurity AND relforcerowsecurity AND relowner='gym_data_owner'::regrole) THEN "
        f"RAISE EXCEPTION 'Reviewed table or its security attributes missing after commit'; END IF;"
        for schema, name in sorted(tables)
    )
    return f"""
DO $gf_closure$ BEGIN
  IF (SELECT count(*) FROM pg_roles WHERE rolname IN
      ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor')) <> {role_count}
     OR EXISTS (
       SELECT 1 FROM pg_roles r
       WHERE r.rolname IN ('gym_data_owner','gym_owner_executor','gym_public_executor','gym_checkin_executor')
         AND (r.rolcanlogin OR r.rolsuper OR r.rolcreatedb OR r.rolcreaterole OR
              r.rolinherit OR r.rolreplication OR r.rolbypassrls OR
              pg_has_role('postgres',r.oid,'SET') OR pg_has_role('postgres',r.oid,'USAGE'))
     )
     OR EXISTS (SELECT 1 FROM pg_policy WHERE polname='gf_compatibility_read') THEN
    RAISE EXCEPTION 'Temporary migration authority or unexpected role attributes after commit';
  END IF;
  {routine_checks}
  {table_checks}
END $gf_closure$;
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("verify", "staging-preflight", "staging-apply", "disposable"))
    mode = parser.parse_args().mode
    baseline, steps, checked = verified_package()
    print("Verified 13 migration artifact checksums and their pinned source references.", flush=True)
    if mode == "verify":
        return
    disposable = mode == "disposable"
    session = connection(disposable)
    first_check = verify_target() + history_check(baseline, [], disposable)
    psql(session, "BEGIN READ ONLY;\n" + first_check + "\nCOMMIT;")
    print("Verified execution identity and the 24-entry baseline.", flush=True)
    if mode == "staging-preflight":
        return
    finished = []
    browser_assertions = (ROOT / "supabase/tests/staging_privilege_regression.sql").read_text()
    for index, (name, digest, sql) in enumerate(steps, 1):
        print(f"Applying {index}/13 {name} ({digest})", flush=True)
        lock = f"SET LOCAL lock_timeout='5s';\nLOCK TABLE {HISTORY} IN SHARE ROW EXCLUSIVE MODE;\n"
        check = history_check(baseline, finished, disposable)
        if index == 1:
            check += verify_target()
        reviewed_body = sql.removesuffix("COMMIT;\n").replace("BEGIN;\n", "BEGIN;\n" + lock + check, 1)
        psql(session, reviewed_body + history_insert(name, sql) + "COMMIT;\n")
        finished.append((name, digest))
        checks = (history_check(baseline, finished, disposable) + postcondition(sql, index) + browser_assertions)
        psql(session, "BEGIN READ ONLY;\n" + checks + "\nCOMMIT;")
        if index == 1:
            psql(session, checked["executor_hardening_assertions.sql"][1])
        print(f"Verified commit, history checksum and catalog for {name}", flush=True)
    psql(session, checked["final_security_assertions.sql"][1])
    print("Verified all 37 history entries and final security assertions.", flush=True)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError):
        # Connection parameters can contain credentials. Keep traceback and
        # connection input out of CI output. psql reports SQLSTATE and line.
        raise SystemExit("GYMFORCE stopped. Reconcile staging history and catalog before retrying.") from None
