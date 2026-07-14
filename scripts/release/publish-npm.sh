#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=scripts/release/lib.sh
source "$SCRIPT_DIR/lib.sh"
cd "$ROOT_DIR"

mode="${1:-}"
NPM_REGISTRY="https://registry.npmjs.org/"

if [[ "$mode" == "publish" ]]; then
release_require_env V
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
pack_json="$tmp/npm-pack.json"
pack_fields="$tmp/npm-pack-fields"
versions_file="$tmp/npm-versions.json"
integrity_file="$tmp/npm-integrity.json"
lookup_error="$tmp/npm-lookup.err"

npm pack --json --pack-destination "$tmp" > "$pack_json"
node - "$V" "$pack_json" > "$pack_fields" <<'NODE'
const fs = require('fs');
const path = require('path');
const [, , version, file] = process.argv;
const packed = JSON.parse(fs.readFileSync(file, 'utf8'));
if (!Array.isArray(packed) || packed.length !== 1) {
  throw new Error('npm pack must produce exactly one artifact');
}
const [artifact] = packed;
if (artifact.name !== 'codex-profile' || artifact.version !== version) {
  throw new Error('npm pack returned the wrong package identity');
}
if (typeof artifact.filename !== 'string'
    || path.basename(artifact.filename) !== artifact.filename
    || !artifact.filename.endsWith('.tgz')) {
  throw new Error('npm pack returned an unsafe tarball filename');
}
if (typeof artifact.integrity !== 'string'
    || !/^sha512-[A-Za-z0-9+/]+={0,2}$/.test(artifact.integrity)) {
  throw new Error('npm pack returned an invalid SHA-512 integrity');
}
process.stdout.write(`${artifact.filename}\n${artifact.integrity}\n`);
NODE
artifact_line_count="$(awk 'END { print NR + 0 }' "$pack_fields")"
artifact_filename="$(sed -n '1p' "$pack_fields")"
local_integrity="$(sed -n '2p' "$pack_fields")"
[[ "$artifact_line_count" -eq 2 \
  && -n "$artifact_filename" \
  && -n "$local_integrity" ]] || {
  echo "Could not parse the packed npm artifact." >&2
  exit 1
}
tarball="$tmp/$artifact_filename"
[[ -f "$tarball" && ! -L "$tarball" ]] || {
  echo "npm pack did not create the expected tarball: $tarball" >&2
  exit 1
}

lookup_npm_artifact() {
  npm view codex-profile versions --json --registry "$NPM_REGISTRY" \
    > "$versions_file" 2> "$lookup_error" \
    || return 1
  membership="$(node - "$V" "$versions_file" 2>> "$lookup_error" <<'NODE'
const fs = require('fs');
const [, , version, file] = process.argv;
const versions = JSON.parse(fs.readFileSync(file, 'utf8'));
if (!Array.isArray(versions) || versions.some((item) => typeof item !== 'string')) {
  throw new Error('npm versions response must be an array of strings');
}
process.stdout.write(versions.includes(version) ? 'present' : 'absent');
NODE
  )" || return 1
  if [[ "$membership" == "absent" ]]; then
    printf '%s\n' absent
    return 0
  fi

  npm view "codex-profile@$V" dist.integrity --json --registry "$NPM_REGISTRY" \
    > "$integrity_file" 2>> "$lookup_error" || return 1
  node - "$V" "$local_integrity" "$integrity_file" \
    2>> "$lookup_error" <<'NODE'
const fs = require('fs');
const [, , version, expectedIntegrity, file] = process.argv;
const registryIntegrity = JSON.parse(fs.readFileSync(file, 'utf8'));
if (typeof registryIntegrity !== 'string'
    || !/^sha512-[A-Za-z0-9+/]+={0,2}$/.test(registryIntegrity)) {
  throw new Error(`npm registry returned invalid integrity for codex-profile@${version}`);
}
if (registryIntegrity !== expectedIntegrity) {
  throw new Error(`npm registry integrity mismatch for codex-profile@${version}`);
}
process.stdout.write('matching');
NODE
}

npm_lookup_succeeded=false
npm_artifact_state=""
for attempt in {1..5}; do
  : > "$lookup_error"
  if npm_artifact_state="$(lookup_npm_artifact)"; then
    npm_lookup_succeeded=true
    break
  fi
  if [[ "$attempt" -lt 5 ]]; then
    sleep "$((attempt * 2))"
  fi
done
[[ "$npm_lookup_succeeded" == "true" ]] || {
  cat "$lookup_error" >&2
  echo "Could not establish whether codex-profile@$V is published." >&2
  exit 1
}

if [[ "$npm_artifact_state" == "matching" ]]; then
  echo "codex-profile@$V already matches the packed artifact; continuing the release."
else
  publish_error="$tmp/npm-publish.err"
  npm_publish_succeeded=false
  if npm publish "$tarball" --provenance --access public --registry "$NPM_REGISTRY" \
    2> "$publish_error"; then
    npm_publish_succeeded=true
  fi

  npm_artifact_verified_after_publish=false
  for attempt in {1..5}; do
    : > "$lookup_error"
    if npm_artifact_state="$(lookup_npm_artifact)" \
      && [[ "$npm_artifact_state" == "matching" ]]; then
      npm_artifact_verified_after_publish=true
      break
    fi
    if [[ "$attempt" -lt 5 ]]; then
      sleep "$((attempt * 2))"
    fi
  done
  [[ "$npm_artifact_verified_after_publish" == "true" ]] || {
    if [[ "$npm_publish_succeeded" != "true" ]]; then
      cat "$publish_error" >&2
    fi
    cat "$lookup_error" >&2
    echo "Could not publish or verify the exact npm artifact for codex-profile@$V." >&2
    exit 1
  }
  if [[ "$npm_publish_succeeded" == "true" ]]; then
    echo "Published and verified the exact npm artifact for codex-profile@$V."
  else
    echo "The exact npm artifact for codex-profile@$V was published concurrently; continuing the release."
  fi
fi
exit 0
fi

if [[ "$mode" == "verify" ]]; then
release_require_env V
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
prefix="$tmp/prefix"
cache="$tmp/npm-cache"
npm_installed=false
for attempt in {1..10}; do
  if npm install -g --prefix "$prefix" --cache "$cache" \
    --registry "$NPM_REGISTRY" "codex-profile@$V"; then
    npm_installed=true
    break
  fi
  rm -rf "$prefix"
  if [[ "$attempt" -lt 10 ]]; then
    sleep "$((attempt * 2))"
  fi
done
[[ "$npm_installed" == "true" ]] || {
  echo "codex-profile@$V was not installable after 10 attempts." >&2
  exit 1
}
"$prefix/bin/codex-profile" help >/dev/null
"$prefix/bin/codex-profile" version | grep -Fx "codex-profile $V" >/dev/null
"$prefix/bin/codex-profiles" help >/dev/null
"$prefix/bin/codex-profiles" version | grep -Fx "codex-profile $V" >/dev/null
exit 0
fi

release_die "Usage: scripts/release/publish-npm.sh {publish|verify}"
