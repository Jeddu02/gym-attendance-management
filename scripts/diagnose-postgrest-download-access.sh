#!/usr/bin/env bash
# GYMFORCE read-only network diagnosis for official PostgREST distribution.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v curl >/dev/null || { echo 'BLOCKED: curl unavailable'; exit 2; }
echo '=== GitHub release access diagnosis (no download or credentials) ==='
for entry in \
  'API|https://api.github.com/repos/PostgREST/postgrest/releases/latest' \
  'Release page|https://github.com/PostgREST/postgrest/releases/latest' \
  'GitHub main|https://github.com/PostgREST/postgrest'; do
  label="${entry%%|*}"
  url="${entry#*|}"
  echo "--- $label ---"
  curl --silent --show-error --location --output /dev/null \
    --connect-timeout 10 --max-time 25 \
    --user-agent 'GYMFORCE-local-compatibility-diagnostic' \
    --write-out 'HTTP=%{http_code} FINAL_HOST=%{url_effective} REMOTE_IP=%{remote_ip}\n' \
    "$url" || echo 'NETWORK_ERROR'
done
echo '=== Proxy variable presence (values never printed) ==='
for name in HTTPS_PROXY HTTP_PROXY ALL_PROXY NO_PROXY; do
  if [[ -n "${!name:-}" ]]; then echo "$name=SET"; else echo "$name=UNSET"; fi
done
echo 'PASS: read-only diagnosis finished; no binary installed, credentials used, or database accessed.'
