#!/usr/bin/env bash
# Read-only diagnostics for the known isolated native PostgreSQL test cluster.
set -euo pipefail
cd "$(dirname "$0")/.."
root="$(pwd -P)/.cache/gymforce-native-23c0b94e3cec48efa403ab08a37a4937"
[[ ! -L .cache && ! -L "$root" && -d "$root" ]] || { echo "BLOCKED: isolated cluster root absent/redirected"; exit 2; }
[[ "$(sudo -n stat -c '%U:%G' "$root")" == postgres:postgres ]] || { echo "BLOCKED: unexpected owner"; exit 2; }
echo "=== Isolated cluster metadata ==="
sudo -n stat -c '%A %U:%G %n' "$root" "$root/data" "$root/postgresql.test.conf"
echo "=== PostgreSQL cluster state ==="
sudo -n /usr/sbin/runuser -u postgres -- /usr/lib/postgresql/17/bin/pg_controldata "$root/data" | grep -E 'Database cluster state:|Database system identifier:|Catalog version number:'
echo "=== PostgreSQL startup log (last 60 lines) ==="
if sudo -n /usr/sbin/runuser -u postgres -- test -f "$root/server.log"; then
  sudo -n /usr/sbin/runuser -u postgres -- tail -n 60 "$root/server.log"
else
  echo "No server.log present"
fi
echo "=== Isolated PostgreSQL config syntax ==="
sudo -n /usr/sbin/runuser -u postgres -- /usr/lib/postgresql/17/bin/postgres -D "$root/data" -C listen_addresses -c "config_file=$root/postgresql.test.conf"
echo "PASS: diagnostic completed without starting or modifying a database"
