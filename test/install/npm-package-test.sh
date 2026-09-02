#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_PREFIX="$(mktemp -d)"
trap 'rm -rf "$TMP_PREFIX"' EXIT HUP INT TERM

cd "$ROOT_DIR"

if ! command -v npm >/dev/null 2>&1; then
  printf '%s\n' 'npm not found; skipping npm package smoke test.'
  exit 0
fi

pack_json="$(npm pack --json \
  --cache "$TMP_PREFIX/npm-cache" \
  --pack-destination "$TMP_PREFIX")"
tarball_name="$(
  node -e '
    const value = JSON.parse(process.argv[1]);
    if (!Array.isArray(value) || value.length !== 1 || typeof value[0].filename !== "string") {
      process.exit(1);
    }
    process.stdout.write(value[0].filename);
  ' "$pack_json"
)"

case "$tarball_name" in
  ''|*/*) exit 1 ;;
esac

tarball="$TMP_PREFIX/$tarball_name"
[[ -f "$tarball" ]]

npm install -g \
  --prefix "$TMP_PREFIX" \
  --cache "$TMP_PREFIX/npm-cache" \
  "$tarball" >/dev/null

[[ -x "$TMP_PREFIX/bin/codex-profile" ]]
[[ -x "$TMP_PREFIX/bin/codex-profiles" ]]
[[ ! -L "$TMP_PREFIX/lib/node_modules/codex-profile" ]]
[[ -f "$TMP_PREFIX/lib/node_modules/codex-profile/bin/codex-profile" ]]
[[ -f "$TMP_PREFIX/lib/node_modules/codex-profile/agent.md" ]]
[[ -f "$TMP_PREFIX/lib/node_modules/codex-profile/docs/llms.txt" ]]
[[ ! -e "$TMP_PREFIX/lib/node_modules/codex-profile/docs/index.html" ]]
[[ ! -e "$TMP_PREFIX/lib/node_modules/codex-profile/media" ]]
[[ ! -e "$TMP_PREFIX/lib/node_modules/codex-profile/ops" ]]

"$TMP_PREFIX/bin/codex-profile" help >/dev/null
version_output="$("$TMP_PREFIX/bin/codex-profiles" version)"
expected_version="$(node -p "require('./package.json').version")"
[[ "$version_output" == "codex-profile $expected_version" ]]

printf '%s\n' 'npm package smoke test passed.'
