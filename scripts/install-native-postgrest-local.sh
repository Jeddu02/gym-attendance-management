#!/usr/bin/env bash
# Download an official PostgREST Linux binary into the repo-local ignored cache.
# Does not start PostgREST, configure JWTs, connect to a DB, or alter production.
set -euo pipefail
cd "$(dirname "$0")/.."
for cmd in curl python3 tar sha256sum uname; do command -v "$cmd" >/dev/null || { echo "BLOCKED: missing $cmd"; exit 2; }; done
[[ "$(uname -s)" == Linux ]] || { echo 'BLOCKED: Linux only'; exit 2; }
[[ "$(uname -m)" == x86_64 ]] || { echo 'BLOCKED: x86_64 only'; exit 2; }
[[ -z "${DATABASE_URL:-}${SUPABASE_DB_URL:-}${SUPABASE_SERVICE_ROLE_KEY:-}" ]] || { echo 'BLOCKED: inherited database/service credentials'; exit 2; }
root="$(pwd -P)"
[[ ! -L .cache ]] || { echo 'BLOCKED: .cache symlink'; exit 2; }
mkdir -p .cache/gymforce-postgrest
target="$root/.cache/gymforce-postgrest"
[[ ! -L "$target" ]] || { echo 'BLOCKED: redirected install target'; exit 2; }
metadata="$(mktemp)"
archive="$(mktemp)"
trap 'rm -f "$metadata" "$archive"' EXIT
echo '=== Fetching official release metadata ==='
if ! curl --fail --silent --show-error --location --retry 2 --max-time 30 \
  -H 'Accept: application/vnd.github+json' \
  -H 'User-Agent: GYMFORCE-local-postgrest-installer' \
  'https://api.github.com/repos/PostgREST/postgrest/releases/latest' -o "$metadata"; then
  echo 'BLOCKED: GitHub release metadata request failed. No binary installed.'
  exit 2
fi
mapfile -t asset < <(python3 - "$metadata" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
items=[a for a in r.get('assets',[]) if a.get('name','').endswith('.tar.xz') and 'linux' in a.get('name','').lower() and any(x in a.get('name','').lower() for x in ('static-x64','x86_64','linux-x64'))]
if len(items)!=1: raise SystemExit('BLOCKED: cannot unambiguously select official Linux x86_64 tarball: '+repr([a.get('name') for a in r.get('assets',[])]))
a=items[0]
digest=a.get('digest','')
if not digest.startswith('sha256:') or len(digest)!=71: raise SystemExit('BLOCKED: release asset has no SHA256 digest')
url=a.get('browser_download_url','')
if not url.startswith('https://github.com/PostgREST/postgrest/releases/download/'): raise SystemExit('BLOCKED: unexpected download origin')
print(r['tag_name']);print(a['name']);print(url);print(digest[7:])
PY
)
[[ "${#asset[@]}" == 4 ]] || { echo 'BLOCKED: incomplete asset metadata'; exit 2; }
echo "Official PostgREST release: ${asset[0]} / ${asset[1]}"
echo "=== Downloading verified release asset: ${asset[1]} ==="
if ! curl --fail --silent --show-error --location --retry 2 --max-time 180 \
  -H "User-Agent: GYMFORCE-local-postgrest-installer" "${asset[2]}" -o "$archive"; then
  echo "BLOCKED: official GitHub release asset download failed (possibly network policy)."
  echo "No alternate unverified mirror was used. No binary installed."
  exit 2
fi
printf '%s  %s\n' "${asset[3]}" "$archive" | sha256sum --check --status || { echo 'BLOCKED: SHA256 mismatch'; exit 2; }
mapfile -t entries < <(tar -tJf "$archive")
[[ "${#entries[@]}" == 1 && ("${entries[0]}" == postgrest || "${entries[0]}" == ./postgrest) ]] || { echo 'BLOCKED: unexpected archive entries'; exit 2; }
tar -xJOf "$archive" "${entries[0]}" > "$target/postgrest.tmp"
chmod 700 "$target/postgrest.tmp"
"$target/postgrest.tmp" --version
mv -f "$target/postgrest.tmp" "$target/postgrest"
echo "PASS: verified official binary at $target/postgrest"
echo 'NOT RUN: JWT verification, PostgREST server, RPC integration, and any database mutation.'
