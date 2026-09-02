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
github_output="$TMP_ROOT/github-output"
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
case "$*" in
  *repos/*/releases/tags/*)
    printf '%s\t%s\t%s\t%s\n' \
      "${PAGES_SOURCE_TAG:-v1.2.3}" \
      "${PAGES_SOURCE_IMMUTABLE:-true}" \
      "${PAGES_SOURCE_DRAFT:-false}" \
      "${PAGES_SOURCE_PRERELEASE:-false}"
    ;;
  *repos/*/git/ref/tags/*)
    printf 'refs/tags/%s\t%s\t%s\n' \
      "${PAGES_SOURCE_TAG:-v1.2.3}" \
      "${PAGES_SOURCE_OBJECT_TYPE:-tag}" \
      "${PAGES_SOURCE_OBJECT_SHA:-1111111111111111111111111111111111111111}"
    ;;
  *repos/*/git/tags/*)
    printf '%s\t%s\n' \
      "${PAGES_SOURCE_PEELED_TYPE:-commit}" \
      "${PAGES_SOURCE_TAG_COMMIT:-2222222222222222222222222222222222222222}"
    ;;
  *repos/*/compare/*)
    printf '%s\t%s\t%s\t%s\n' \
      "${PAGES_SOURCE_COMPARE_STATUS:-ahead}" \
      "${PAGES_SOURCE_COMPARE_BASE:-${PAGES_SOURCE_TAG_COMMIT:-2222222222222222222222222222222222222222}}" \
      "${PAGES_SOURCE_MERGE_BASE:-${PAGES_SOURCE_TAG_COMMIT:-2222222222222222222222222222222222222222}}" \
      "${PAGES_SOURCE_BEHIND_BY:-0}"
    ;;
  *)
    printf 'unexpected gh invocation: %s\n' "$*" >&2
    exit 1
    ;;
esac
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
: > "$github_output"
run_verify refs/heads/main ""
assert_status 0
[[ ! -s "$log_file" ]] || fail "main documentation deployment queried a release"
[[ ! -s "$github_output" ]] || fail "main documentation deployment emitted a release commit"

run_verify refs/heads/feature ""
assert_status 1
assert_contains "Pages must run from main"

run_verify refs/heads/main release-latest
assert_status 1
assert_contains "must exactly match vX.Y.Z"

run_verify refs/heads/main v1.2.3 env GITHUB_OUTPUT="$github_output"
assert_status 0
grep -F 'repos/Ducksss/codex-profiles/releases/tags/v1.2.3' "$log_file" >/dev/null \
  || fail "release validation queried the wrong tag"
grep -F 'repos/Ducksss/codex-profiles/git/ref/tags/v1.2.3' "$log_file" >/dev/null \
  || fail "release validation did not resolve the exact Git tag"
grep -F 'repos/Ducksss/codex-profiles/compare/2222222222222222222222222222222222222222...main' \
  "$log_file" >/dev/null \
  || fail "release validation did not compare the resolved tag commit with main"
grep -Fx 'commit=2222222222222222222222222222222222222222' \
  "$github_output" >/dev/null \
  || fail "release validation did not emit the resolved tag commit"

: > "$log_file"
: > "$github_output"
run_verify refs/heads/main v1.2.3 env \
  GITHUB_OUTPUT="$github_output" \
  PAGES_SOURCE_OBJECT_TYPE=commit \
  PAGES_SOURCE_OBJECT_SHA=4444444444444444444444444444444444444444 \
  PAGES_SOURCE_COMPARE_BASE=4444444444444444444444444444444444444444 \
  PAGES_SOURCE_MERGE_BASE=4444444444444444444444444444444444444444
assert_status 0
if grep -F 'repos/Ducksss/codex-profiles/git/tags/' "$log_file" >/dev/null; then
  fail "lightweight Git tag unexpectedly queried an annotated tag object"
fi
grep -F 'repos/Ducksss/codex-profiles/compare/4444444444444444444444444444444444444444...main' \
  "$log_file" >/dev/null \
  || fail "lightweight Git tag did not use its exact commit"
grep -Fx 'commit=4444444444444444444444444444444444444444' \
  "$github_output" >/dev/null \
  || fail "lightweight Git tag did not emit its exact commit"

run_verify refs/heads/main v1.2.3 env PAGES_SOURCE_IMMUTABLE=false
assert_status 1
assert_contains "not an immutable final GitHub Release"

run_verify refs/heads/main v1.2.3 env \
  PAGES_SOURCE_COMPARE_STATUS=diverged \
  PAGES_SOURCE_MERGE_BASE=3333333333333333333333333333333333333333 \
  PAGES_SOURCE_BEHIND_BY=1
assert_status 1
assert_contains "not contained in main"

printf '%s\n' 'Pages source validation tests passed.'
