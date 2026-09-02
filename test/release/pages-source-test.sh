#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/test/lib/assertions.sh"
source "$ROOT_DIR/test/lib/command-shims.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM

VERIFY="$ROOT_DIR/scripts/release/verify-pages-source.sh"
fake_bin="$TMP_ROOT/bin"
log_file="$TMP_ROOT/gh.log"
output=""
status=0

run_cmd() {
  set +e
  output="$("$@" 2>&1)"
  status=$?
  set -e
}

mkdir -p "$fake_bin"
write_command_shim "$fake_bin/gh" <<'SH'
set -eu
printf '%s\n' "$*" >> "$PAGES_SOURCE_TEST_LOG"
printf '%s\t%s\t%s\t%s\n' \
  "${PAGES_SOURCE_TAG:-v1.2.3}" \
  "${PAGES_SOURCE_IMMUTABLE:-true}" \
  "${PAGES_SOURCE_DRAFT:-false}" \
  "${PAGES_SOURCE_PRERELEASE:-false}"
SH

run_verify() {
  local ref="$1"
  local tag="$2"
  shift 2
  run_cmd env PATH="$fake_bin:$PATH" PAGES_SOURCE_TEST_LOG="$log_file" \
    GITHUB_REF="$ref" GITHUB_REPOSITORY="Ducksss/codex-profiles" RELEASE_TAG="$tag" \
    "$@" "$VERIFY"
}

: > "$log_file"
run_verify refs/heads/main ""
assert_status 0
[[ ! -s "$log_file" ]] || fail "main documentation deployment queried a release"

run_verify refs/heads/feature ""
assert_status 1
assert_contains "Pages must run from main"

run_verify refs/heads/main release-latest
assert_status 1
assert_contains "must exactly match vX.Y.Z"

run_verify refs/heads/main v1.2.3
assert_status 0
grep -F 'repos/Ducksss/codex-profiles/releases/tags/v1.2.3' "$log_file" >/dev/null \
  || fail "release validation queried the wrong tag"

run_verify refs/heads/main v1.2.3 env PAGES_SOURCE_IMMUTABLE=false
assert_status 1
assert_contains "not an immutable final GitHub Release"

printf '%s\n' 'Pages source validation tests passed.'
