#!/usr/bin/env bash
# GYMFORCE Batch B: provision a NEW isolated native PostgreSQL 17 test cluster.
# Never touches existing 17/main, production, or historical migrations.
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/check-native-postgres-local.sh
[[ -z "${DATABASE_URL:-}${SUPABASE_DB_URL:-}${PGHOST:-}${PGHOSTADDR:-}${PGSERVICE:-}${PGDATABASE:-}${PGUSER:-}${PGPORT:-}" ]] || { echo "BLOCKED: inherited database connection override"; exit 2; }
for f in /usr/lib/postgresql/17/bin/initdb /usr/lib/postgresql/17/bin/pg_ctl /usr/lib/postgresql/17/bin/psql; do
  [[ -x "$f" ]] || { echo "BLOCKED: missing $f"; exit 2; }
done
[[ -d .cache ]] || mkdir .cache
git check-ignore -q .cache/gymforce-native-test-probe || { echo "BLOCKED: .cache must be gitignored"; exit 2; }
[[ ! -L .cache ]] || { echo "BLOCKED: redirected .cache"; exit 2; }
umask 077
runid="$(cat /proc/sys/kernel/random/uuid | tr -d '-')"
root="$(pwd -P)/.cache/gymforce-native-$runid"
mkdir -m 700 "$root"
sudo -n chown postgres:postgres "$root"
# Only Unix socket connections, no TCP listener; socket path under this run directory.
sudo -n /usr/sbin/runuser -u postgres -- /usr/lib/postgresql/17/bin/initdb -D "$root/data" -A peer -U postgres --no-instructions >/dev/null
# Write as the owning postgres account; the codespace user cannot write into a 0700 postgres-owned directory.
printf '%s\\n' "listen_addresses = ''" "port = 55439" "unix_socket_directories = '$root'" "fsync = on" | sudo -n /usr/sbin/runuser -u postgres -- tee "$root/postgresql.test.conf" >/dev/null
echo "Created isolated PG17 cluster: $root"
echo "No cluster started, no database/role created, no SQL migration executed."
echo "Cluster is owned by postgres. Keep this directory for reviewed next-stage integration."
