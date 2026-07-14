#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/test/lib/assertions.sh"
source "$ROOT_DIR/test/lib/command-shims.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM

PREFLIGHT="$ROOT_DIR/scripts/release/preflight.sh"
VERIFY_STATE="$ROOT_DIR/scripts/release/verify-state.sh"
PUBLISH_TAG="$ROOT_DIR/scripts/release/publish-tag.sh"
VERIFIED_SHA="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

for script in "$PREFLIGHT" "$VERIFY_STATE" "$PUBLISH_TAG"; do
  [[ -x "$script" ]] || fail "missing executable ${script#"$ROOT_DIR/"}"
done

fake_bin="$TMP_ROOT/bin"
log_file="$TMP_ROOT/commands.log"
mkdir -p "$fake_bin"

write_command_shim "$fake_bin/npm" <<'SH'
set -eu
printf 'npm:%s\n' "$*" >> "$RELEASE_TEST_LOG"
[ "${NODE_AUTH_TOKEN:-}" = "npm-token" ] || exit 65
case "${1:-}" in
  whoami) printf '%s\n' release-owner ;;
  owner) printf '%s\n' 'release-owner <owner@example.invalid>' ;;
  *) exit 64 ;;
esac
SH

write_command_shim "$fake_bin/gh" <<'SH'
set -eu
printf 'gh:%s\n' "$*" >> "$RELEASE_TEST_LOG"
[ "${GH_TOKEN:-}" = "tap-token" ] || exit 65
printf '%s\n' true
SH

write_command_shim "$fake_bin/git" <<'SH'
set -eu
printf 'git:%s\n' "$*" >> "$RELEASE_TEST_LOG"
case "${1:-}" in
  fetch|config|tag|update-ref) ;;
  rev-parse)
    if [ "${FAKE_RELEASE_SCENARIO:-}" = "main-moved" ]; then
      printf '%s\n' bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
    else
      printf '%s\n' "$VERIFIED_SHA"
    fi
    ;;
  ls-remote)
    case "${FAKE_RELEASE_SCENARIO:-}" in
      absent) exit 2 ;;
      transient) exit 128 ;;
      *) printf '%s\n' 'remote tag exists' ;;
    esac
    ;;
  rev-list)
    if [ "${FAKE_RELEASE_SCENARIO:-}" = "conflict" ]; then
      printf '%s\n' bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
    else
      printf '%s\n' "$VERIFIED_SHA"
    fi
    ;;
  push)
    case "${FAKE_RELEASE_SCENARIO:-}" in
      publish) exit 0 ;;
      race-same|conflict|transient) exit 1 ;;
      *) exit 64 ;;
    esac
    ;;
  *) exit 64 ;;
esac
SH

: > "$log_file"
PATH="$fake_bin:$PATH" \
  RELEASE_TEST_LOG="$log_file" \
  NPM_TOKEN="npm-token" \
  TAP_TOKEN="tap-token" \
  "$PREFLIGHT"
grep -F 'npm:whoami --registry' "$log_file" >/dev/null || fail "preflight skipped npm identity"
grep -F 'npm:owner ls codex-profile --registry' "$log_file" >/dev/null || fail "preflight skipped npm ownership"
grep -F 'gh:api repos/Ducksss/homebrew-tap' "$log_file" >/dev/null || fail "preflight skipped tap access"

set +e
missing_secret_output="$({
  PATH="$fake_bin:$PATH" RELEASE_TEST_LOG="$log_file" NPM_TOKEN="" TAP_TOKEN="tap-token" "$PREFLIGHT"
} 2>&1)"
missing_secret_status=$?
set -e
[[ "$missing_secret_status" -ne 0 ]] || fail "preflight accepted missing npm token"
[[ "$missing_secret_output" != *'tap-token'* ]] || fail "preflight leaked tap token"

run_verify_state() {
  local scenario="$1"
  local expected_status="$2"
  local expected_tag_exists="$3"
  local output_file="$TMP_ROOT/state-$scenario.output"
  local status

  : > "$output_file"
  set +e
  PATH="$fake_bin:$PATH" \
    RELEASE_TEST_LOG="$log_file" \
    FAKE_RELEASE_SCENARIO="$scenario" \
    GITHUB_OUTPUT="$output_file" \
    TAG="v0.7.0" \
    VERIFIED_SHA="$VERIFIED_SHA" \
    "$VERIFY_STATE" >"$TMP_ROOT/state-$scenario.log" 2>&1
  status=$?
  set -e

  if [[ "$expected_status" = success ]]; then
    [[ "$status" -eq 0 ]] || fail "verify-state $scenario failed"
    grep -Fx "tag_exists=$expected_tag_exists" "$output_file" >/dev/null \
      || fail "verify-state $scenario emitted wrong tag state"
  else
    [[ "$status" -ne 0 ]] || fail "verify-state $scenario unexpectedly succeeded"
  fi
}

run_verify_state absent success false
run_verify_state present success true
run_verify_state main-moved failure ignored
run_verify_state conflict failure ignored
run_verify_state transient failure ignored

run_publish_tag() {
  local scenario="$1"
  local tag_exists="$2"
  local expected_status="$3"
  local before_pushes after_pushes status

  before_pushes="$(grep -c '^git:push ' "$log_file" || true)"
  set +e
  PATH="$fake_bin:$PATH" \
    RELEASE_TEST_LOG="$log_file" \
    FAKE_RELEASE_SCENARIO="$scenario" \
    TAG="v0.7.0" \
    TAG_EXISTS="$tag_exists" \
    VERIFIED_SHA="$VERIFIED_SHA" \
    "$PUBLISH_TAG" >"$TMP_ROOT/tag-$scenario.log" 2>&1
  status=$?
  set -e
  after_pushes="$(grep -c '^git:push ' "$log_file" || true)"

  if [[ "$expected_status" = success ]]; then
    [[ "$status" -eq 0 ]] || fail "publish-tag $scenario failed"
  else
    [[ "$status" -ne 0 ]] || fail "publish-tag $scenario unexpectedly succeeded"
  fi

  if [[ "$tag_exists" = true ]]; then
    [[ "$after_pushes" -eq "$before_pushes" ]] || fail "existing tag was pushed again"
  else
    [[ "$after_pushes" -eq $((before_pushes + 1)) ]] || fail "new tag was not pushed once"
  fi
}

run_publish_tag present true success
run_publish_tag publish false success
run_publish_tag race-same false success
run_publish_tag conflict false failure
run_publish_tag transient false failure

printf '%s\n' 'Release state tests passed.'
