#!/usr/bin/env bash
# Start only the previously provisioned, explicitly identified isolated PG17 cluster.
# Creates a synthetic local database; never connects to 17/main or hosted services.
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/check-native-postgres-local.sh
[[ -z "${DATABASE_URL:-}${SUPABASE_DB_URL:-}${PGHOST:-}${PGHOSTADDR:-}${PGSERVICE:-}${PGDATABASE:-}${PGUSER:-}${PGPORT:-}" ]] || { echo "BLOCKED: inherited DB connection override"; exit 2; }
runid="23c0b94e3cec48efa403ab08a37a4937"
root="$(pwd -P)/.cache/gymforce-native-$runid"
[[ ! -L .cache && ! -L "$root" ]] || { echo "BLOCKED: isolated path redirected"; exit 2; }
[[ -d "$root" ]] || { echo "BLOCKED: expected isolated cluster root absent"; exit 2; }
# postgres owns this directory with mode 0700. The codespace user cannot
# traverse it; test its children as postgres rather than using shell -d/-f.
sudo -n /usr/sbin/runuser -u postgres -- test -d "$root/data" || { echo "BLOCKED: isolated data directory absent"; exit 2; }
sudo -n /usr/sbin/runuser -u postgres -- test -f "$root/postgresql.test.conf" || { echo "BLOCKED: isolated configuration absent"; exit 2; }
sudo -n /usr/sbin/runuser -u postgres -- test ! -L "$root/data" || { echo "BLOCKED: redirected data directory"; exit 2; }
sudo -n /usr/sbin/runuser -u postgres -- test ! -L "$root/postgresql.test.conf" || { echo "BLOCKED: redirected configuration"; exit 2; }
[[ "$(sudo -n stat -c '%U:%G' "$root")" == postgres:postgres ]] || { echo "BLOCKED: unexpected cluster ownership"; exit 2; }
[[ "$(sudo -n stat -c '%U:%G' "$root/data")" == postgres:postgres ]] || { echo "BLOCKED: unexpected data ownership"; exit 2; }
[[ "$(sudo -n /usr/sbin/runuser -u postgres -- /usr/lib/postgresql/17/bin/pg_controldata "$root/data" | sed -n 's/^Database cluster state: *//p')" == "shut down" ]] || { echo "BLOCKED: cluster not cleanly shut down (may already be running)"; exit 2; }
config="$(sudo -n /usr/sbin/runuser -u postgres -- cat "$root/postgresql.test.conf")"
echo "Isolated PostgreSQL config (escaped for diagnosis):"
printf '%s\n' "$config" | sed -n l
grep -Fxq "listen_addresses = ''" <<<"$config" || { echo "BLOCKED: expected listen_addresses = two single quotes; configuration differs"; exit 2; }
grep -Fxq "port = 55439" <<<"$config" || { echo "BLOCKED: unexpected port"; exit 2; }
grep -Fxq "unix_socket_directories = '$root'" <<<"$config" || { echo "BLOCKED: unexpected socket directory"; exit 2; }
[[ ! -e "$root/.s.PGSQL.55439" && ! -e "$root/.s.PGSQL.55439.lock" ]] || { echo "BLOCKED: existing socket or lock"; exit 2; }
echo "Starting isolated PG17 cluster over private Unix socket only..."
sudo -n /usr/sbin/runuser -u postgres -- /usr/lib/postgresql/17/bin/pg_ctl -D "$root/data" -o "-c config_file=$root/postgresql.test.conf" -l "$root/server.log" -w start
psql=(sudo -n /usr/sbin/runuser -u postgres -- /usr/bin/env -u PGHOST -u PGHOSTADDR -u PGPORT -u PGDATABASE -u PGUSER -u PGSERVICE -u DATABASE_URL -u SUPABASE_DB_URL /usr/lib/postgresql/17/bin/psql -X -w -v ON_ERROR_STOP=1 -h "$root" -p 55439 -U postgres)
identity="$("${psql[@]}" -At -d postgres -c "select current_user || '|' || current_database() || '|' || current_setting('data_directory') || '|' || current_setting('listen_addresses')")"
[[ "$identity" == "postgres|postgres|$root/data|" ]] || { echo "BLOCKED: isolated identity mismatch: $identity"; exit 2; }
echo "Verified isolated identity: $identity"
if [[ "$("${psql[@]}" -At -d postgres -c "select count(*) from pg_database where datname='gymforce_integration_test'")" == "0" ]]; then
  "${psql[@]}" -d postgres -c 'CREATE DATABASE gymforce_integration_test'
else
  echo "Synthetic database already exists; no changes made"
fi
echo "PASS: isolated local PostgreSQL server started and synthetic database present; no GYMFORCE migrations executed"
echo "To stop: sudo -n /usr/sbin/runuser -u postgres -- /usr/lib/postgresql/17/bin/pg_ctl -D '$root/data' -m fast -w stop"
