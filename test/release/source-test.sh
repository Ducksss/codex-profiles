#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/test/lib/assertions.sh"
source "$ROOT_DIR/test/lib/command-shims.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM

VERIFY_SOURCE="$ROOT_DIR/scripts/release/verify-source.sh"
FAKE_SHA="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
export FAKE_SHA

[[ -x "$VERIFY_SOURCE" ]] || fail "missing executable scripts/release/verify-source.sh"

fake_bin="$TMP_ROOT/bin"
mkdir -p "$fake_bin"
write_command_shim "$fake_bin/git" <<'SH'
set -eu
printf '%s\n' "$*" >> "$RELEASE_TEST_LOG"
case "${1:-}" in
  fetch) ;;
  rev-parse)
    printf '%s\n' "$FAKE_SHA"
    ;;
  show-ref)
    exit 1
    ;;
  rev-list)
    printf '%s\n' "$FAKE_SHA"
    ;;
  *)
    printf 'unexpected git command: %s\n' "$*" >&2
    exit 64
    ;;
esac
SH

output_file="$TMP_ROOT/output"
summary_file="$TMP_ROOT/summary"
log_file="$TMP_ROOT/git.log"
: > "$output_file"
: > "$summary_file"
: > "$log_file"

PATH="$fake_bin:$PATH" \
  RELEASE_TEST_LOG="$log_file" \
  INPUT_VERSION="0.7.0" \
  DRY_RUN="true" \
  DESKTOP_SMOKE_ATTESTATION="" \
  GITHUB_REF="refs/heads/main" \
  GITHUB_SHA="$FAKE_SHA" \
  GITHUB_OUTPUT="$output_file" \
  GITHUB_STEP_SUMMARY="$summary_file" \
  "$VERIFY_SOURCE"

for expected in \
  'version=0.7.0' \
  'tag=v0.7.0' \
  'tag_exists=false' \
  "commit=$FAKE_SHA"; do
  grep -Fx "$expected" "$output_file" >/dev/null \
    || fail "verify-source output is missing $expected"
done

set +e
invalid_output="$({
  INPUT_VERSION="v0.7.0" \
    DRY_RUN="true" \
    DESKTOP_SMOKE_ATTESTATION="" \
    GITHUB_REF="refs/heads/main" \
    GITHUB_SHA="$FAKE_SHA" \
    GITHUB_OUTPUT="$TMP_ROOT/invalid-output" \
    GITHUB_STEP_SUMMARY="$TMP_ROOT/invalid-summary" \
    "$VERIFY_SOURCE"
} 2>&1)"
invalid_status=$?
set -e
[[ "$invalid_status" -ne 0 ]] || fail "prefixed release version must fail"
assert_contains "$invalid_output" 'not an exact X.Y.Z release version' "invalid version error"

set +e
attestation_output="$({
  INPUT_VERSION="0.7.0" \
    DRY_RUN="false" \
    DESKTOP_SMOKE_ATTESTATION="" \
    GITHUB_REF="refs/heads/main" \
    GITHUB_SHA="$FAKE_SHA" \
    GITHUB_OUTPUT="$TMP_ROOT/attestation-output" \
    GITHUB_STEP_SUMMARY="$TMP_ROOT/attestation-summary" \
    "$VERIFY_SOURCE"
} 2>&1)"
attestation_status=$?
set -e
[[ "$attestation_status" -ne 0 ]] || fail "live release without attestation must fail"
assert_contains "$attestation_output" \
  'Signed-app smoke attestation is required for a live release' \
  "missing attestation error"

printf '%s\n' 'Release source tests passed.'
