#!/usr/bin/env bash
# GYMFORCE C3.4 — read-only native PostgreSQL identity/loopback check.
# Does not start services, create roles/databases, apply SQL files or use Docker.
set -euo pipefail
if [[ "$(uname -s)" != Linux ]]; then echo "BLOCKED: Linux only"; exit 2; fi
if [[ -n "${PGHOST:-}${PGHOSTADDR:-}${PGPORT:-}${PGDATABASE:-}${PGUSER:-}${PGSERVICE:-}${DATABASE_URL:-}${SUPABASE_DB_URL:-}" ]]; then
  echo "BLOCKED: inherited database connection overrides"; exit 2
fi
if ! command -v pg_lsclusters >/dev/null; then echo "BLOCKED: pg_lsclusters missing"; exit 2; fi
cluster="$(pg_lsclusters -h)"
printf '%s\n' "$cluster"
if ! printf '%s\n' "$cluster" | awk '$1=="17" && $2=="main" && $3=="5432" && $4=="online" {found=1} END{exit !found}'; then
  echo "BLOCKED: PostgreSQL 17/main must be online at port 5432"; exit 2
fi
pg_conftool_bin="$(command -v pg_conftool || true)"
if [[ -z "$pg_conftool_bin" || ! -x "$pg_conftool_bin" ]]; then
  echo "BLOCKED: pg_conftool unavailable"; exit 2
fi
if [[ "$(sudo -n "$pg_conftool_bin" 17 main show listen_addresses | tr -d '[:space:]')" != "listen_addresses=localhost" ]]; then
  echo "BLOCKED: listen_addresses must be localhost"; exit 2
fi
# Explicit absolute executable and empty PG environment, Unix socket peer auth.
# Root is permitted by Codespaces sudoers; runuser switches to postgres.
psql_bin=/usr/lib/postgresql/17/bin/psql
[[ -x "$psql_bin" ]] || { echo "BLOCKED: PostgreSQL 17 psql not installed"; exit 2; }
query="SELECT current_user, current_database(), current_setting('server_version'), current_setting('listen_addresses'), current_setting('port'), current_setting('data_directory');"
result="$(sudo -n /usr/sbin/runuser -u postgres -- /usr/bin/env -u PGHOST -u PGHOSTADDR -u PGPORT -u PGDATABASE -u PGUSER -u PGSERVICE -u DATABASE_URL -u SUPABASE_DB_URL "$psql_bin" -X -w -v ON_ERROR_STOP=1 -F '|' -At -d postgres -c "$query")"
printf 'Local PostgreSQL identity: %s\n' "$result"
IFS='|' read -r actor db version listen port data <<< "$result"
if [[ "$actor" != postgres || "$db" != postgres || "$version" != 17.* || "$listen" != localhost || "$port" != 5432 || "$data" != /var/lib/postgresql/17/main ]]; then
  echo "BLOCKED: unexpected server identity or data directory"; exit 2
fi
echo "PASS: native PostgreSQL 17 local identity verified; no migrations executed"
