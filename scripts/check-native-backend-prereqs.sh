#!/usr/bin/env bash
# Read-only native PostgreSQL 17 prerequisite check. No Docker, installs, services, SQL or secrets.
set -euo pipefail
. /etc/os-release
if [[ "${ID:-}" != ubuntu || "${VERSION_CODENAME:-}" != noble ]]; then
  echo "BLOCKED: expected Ubuntu 24.04 (noble)"; exit 1
fi
if [[ "$(uname -m)" != x86_64 ]]; then
  echo "BLOCKED: expected x86_64"; exit 1
fi
echo "PASS: Ubuntu noble / x86_64"
echo "User: $(id -un)"
echo "Native PostgreSQL 17:"
if command -v pg_config >/dev/null 2>&1; then pg_config --version; else echo "NOT INSTALLED"; fi
if command -v pg_lsclusters >/dev/null 2>&1; then
  echo "Existing PostgreSQL clusters (inspect before any install):"
  pg_lsclusters
else
  echo "No pg_lsclusters command"
fi
echo "PGDG package candidate:"
apt-cache policy postgresql-17 || true
for tool in psql postgres initdb pg_ctl postgrest deno; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '%s: %s\n' "$tool" "$(command -v "$tool")"
  else
    printf '%s: unavailable on PATH\n' "$tool"
  fi
done
echo "PASS: read-only prerequisite inspection finished"
