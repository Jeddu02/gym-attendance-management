#!/usr/bin/env bash
# Read-only discovery of the migration-backed owner authorization fixture.
# Never connects to production, creates users, or prints credentials.
set -euo pipefail
cd "$(dirname "$0")/.."
for name in DATABASE_URL SUPABASE_DB_URL PGHOST PGHOSTADDR PGPORT PGDATABASE PGUSER PGSERVICE SUPABASE_URL SUPABASE_SERVICE_ROLE_KEY SUPABASE_JWT_SECRET PGRST_DB_URI PGRST_JWT_SECRET; do
  [[ -z "${!name:-}" ]] || { echo "BLOCKED: inherited $name"; exit 2; }
done
socket=/tmp/gf-pg-23c0b94e
port=55439
db=gymforce_integration_test
[[ -S "$socket/.s.PGSQL.$port" ]] || { echo 'BLOCKED: expected isolated PostgreSQL Unix socket absent'; exit 2; }
echo '=== Isolated owner authorization dependency inventory ==='
sudo -n /usr/sbin/runuser -u postgres -- /usr/bin/env -u PGHOST -u PGHOSTADDR -u PGPORT -u PGDATABASE -u PGUSER -u PGSERVICE -u DATABASE_URL -u SUPABASE_DB_URL /usr/lib/postgresql/17/bin/psql -X -w -v ON_ERROR_STOP=1 -h "$socket" -p "$port" -U postgres -d "$db" <<'SQL'
BEGIN READ ONLY;
SELECT 'owner_rpc' AS kind, p.proname AS object,
       pg_get_function_arguments(p.oid) AS detail
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='api' AND p.proname LIKE 'owner_%'
ORDER BY p.proname;
SELECT 'identity_relation' AS kind, n.nspname||'.'||c.relname AS object,
       string_agg(a.attname||' '||format_type(a.atttypid,a.atttypmod),', ' ORDER BY a.attnum) AS detail
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
JOIN pg_attribute a ON a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped
WHERE c.relkind IN ('r','p','v') AND n.nspname IN ('auth','public','private')
AND (c.relname ~* 'owner|staff|profile|user|role|member|payment|purchase')
GROUP BY n.nspname,c.relname ORDER BY object;
SELECT 'owner_function_dependency' AS kind, p.proname AS object,
       substring(pg_get_functiondef(p.oid) from 1 for 10000) AS detail
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='api' AND p.proname IN
 ('owner_approve_member','owner_record_membership_payment','owner_confirm_membership_payment','owner_activate_membership_purchase')
ORDER BY p.proname;
ROLLBACK;
SQL
echo 'PASS: isolated owner authorization catalog inspected read-only; no identities created or database changes.'
echo 'NEXT: design an authorized synthetic owner fixture based on actual role and membership tables, not JWT metadata.'
