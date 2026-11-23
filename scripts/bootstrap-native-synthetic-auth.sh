#!/usr/bin/env bash
# GYMFORCE synthetic-only Supabase SQL prerequisites. NOT a Supabase Auth server.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -z "${DATABASE_URL:-}${SUPABASE_DB_URL:-}${PGHOST:-}${PGHOSTADDR:-}${PGSERVICE:-}${PGDATABASE:-}${PGUSER:-}${PGPORT:-}" ]] || { echo "BLOCKED: inherited database override"; exit 2; }
root="$(pwd -P)/.cache/gymforce-native-23c0b94e3cec48efa403ab08a37a4937"
socket="/tmp/gf-pg-23c0b94e"
[[ ! -L .cache && ! -L "$root" && ! -L "$socket" ]] || { echo "BLOCKED: redirected isolated path"; exit 2; }
[[ "$(sudo -n stat -c '%U:%G:%a' "$root")" == "postgres:postgres:700" ]] || { echo "BLOCKED: cluster owner"; exit 2; }
[[ "$(sudo -n stat -c '%U:%G:%a' "$socket")" == "postgres:postgres:700" ]] || { echo "BLOCKED: socket owner"; exit 2; }
psql=(sudo -n /usr/sbin/runuser -u postgres -- /usr/bin/env -u PGHOST -u PGHOSTADDR -u PGPORT -u PGDATABASE -u PGUSER -u PGSERVICE -u DATABASE_URL -u SUPABASE_DB_URL /usr/lib/postgresql/17/bin/psql -X -w -v ON_ERROR_STOP=1 -h "$socket" -p 55439 -U postgres -d gymforce_integration_test)
identity="$("${psql[@]}" -At -c "select current_database() || '|' || current_user || '|' || current_setting('data_directory') || '|' || current_setting('listen_addresses') || '|' || current_setting('server_version_num')")"
[[ "$identity" == "gymforce_integration_test|postgres|$root/data||170012" ]] || { echo "BLOCKED: synthetic identity mismatch"; exit 2; }
# Abort rather than modify a previously initialized app database.
preexisting="$("${psql[@]}" -At -c "select count(*) from pg_namespace where nspname in ('auth','extensions','api','private')")"
[[ "$preexisting" == "0" ]] || { echo "BLOCKED: compatibility schemas already exist; refusing partial/repeated bootstrap"; exit 2; }
echo "Applying synthetic compatibility prerequisites ONLY to isolated test database"
# Run the guard and all changes in a single transaction. NO LOGIN roles cannot authenticate.
cat <<'SQL' | "${psql[@]}" -1 -f -
DO $guard$
BEGIN
 IF current_database() <> 'gymforce_integration_test'
    OR current_user <> 'postgres'
    OR current_setting('server_version_num')::integer / 10000 <> 17
    OR current_setting('listen_addresses') <> ''
    OR current_setting('data_directory') NOT LIKE '%/.cache/gymforce-native-23c0b94e3cec48efa403ab08a37a4937/data'
 THEN RAISE EXCEPTION 'Synthetic compatibility identity mismatch'; END IF;
END
$guard$;
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN;
CREATE ROLE authenticator NOLOGIN;
CREATE ROLE supabase_auth_admin NOLOGIN;
CREATE SCHEMA extensions;
CREATE SCHEMA auth;
CREATE TABLE auth.users (id uuid PRIMARY KEY);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE SET search_path = ''
AS $function$
 SELECT nullif(pg_catalog.current_setting('request.jwt.claim.sub', true), '')::uuid;
$function$;
CREATE EXTENSION pgcrypto WITH SCHEMA extensions;
CREATE EXTENSION btree_gist WITH SCHEMA extensions;
REVOKE ALL ON SCHEMA auth FROM PUBLIC;
REVOKE ALL ON auth.users FROM PUBLIC;
REVOKE ALL ON FUNCTION auth.uid() FROM PUBLIC;
GRANT USAGE ON SCHEMA auth TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated, service_role;
SQL
echo "PASS: synthetic roles, auth fixture, and extensions created in isolated database"
echo "WARNING: auth.users and auth.uid are synthetic fixtures, not real GoTrue or Supabase Auth."
echo "Historical GYMFORCE migrations remain unexecuted."
