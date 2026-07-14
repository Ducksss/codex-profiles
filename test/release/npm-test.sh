#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/test/lib/assertions.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM
cd "$ROOT_DIR"

npm_fake_bin="$tmp_dir/npm-fake-bin"
mkdir -p "$npm_fake_bin"
cat > "$npm_fake_bin/npm" <<'FAKE_NPM'
#!/bin/sh

set -eu

local_integrity='sha512-dGVzdC1jb2RleC1wcm9maWxl'

case "${1:-}" in
  pack)
    printf '%s\n' 'pack' >> "$RELEASE_WORKFLOW_TEST_LOG"
    shift
    destination=''
    while [ "$#" -gt 0 ]; do
      if [ "$1" = '--pack-destination' ]; then
        destination="$2"
        shift 2
      else
        shift
      fi
    done
    [ -n "$destination" ]
    tarball="$destination/codex-profile-0.7.0.tgz"
    printf '%s\n' 'fixture tarball' > "$tarball"
    printf '[{"name":"codex-profile","version":"0.7.0","filename":"codex-profile-0.7.0.tgz","integrity":"%s"}]\n' \
      "$local_integrity"
    ;;
  view)
    if [ "${2:-}" = 'codex-profile' ] && [ "${3:-}" = 'versions' ]; then
      printf '%s\n' 'view:versions' >> "$RELEASE_WORKFLOW_TEST_LOG"
      case "$FAKE_NPM_SCENARIO" in
        present|mismatch|malformed_integrity)
          printf '%s\n' '["0.6.0", "0.7.0"]'
          ;;
        absent|race)
          if grep -Fqx 'publish' "$RELEASE_WORKFLOW_TEST_LOG"; then
            printf '%s\n' '["0.6.0", "0.7.0"]'
          else
            printf '%s\n' '["0.6.0"]'
          fi
          ;;
        malformed_versions)
          printf '%s\n' '{"unexpected":true}'
          ;;
        transient)
          printf '%s\n' 'npm error code E503' >&2
          exit 1
          ;;
        *) exit 64 ;;
      esac
    elif [ "${2:-}" = 'codex-profile@0.7.0' ] && [ "${3:-}" = 'dist.integrity' ]; then
      printf '%s\n' 'view:integrity' >> "$RELEASE_WORKFLOW_TEST_LOG"
      case "$FAKE_NPM_SCENARIO" in
        present|absent|race)
          printf '"%s"\n' "$local_integrity"
          ;;
        mismatch)
          printf '%s\n' '"sha512-ZGlmZmVyZW50LWFydGlmYWN0"'
          ;;
        malformed_integrity)
          printf '%s\n' '{"unexpected":true}'
          ;;
        *) exit 64 ;;
      esac
    else
      printf 'unexpected npm view invocation: %s\n' "$*" >&2
      exit 64
    fi
    ;;
  publish)
    printf '%s\n' 'publish' >> "$RELEASE_WORKFLOW_TEST_LOG"
    [ -f "${2:-}" ] || {
      printf 'publish did not receive the packed tarball: %s\n' "${2:-}" >&2
      exit 65
    }
    case "$FAKE_NPM_SCENARIO" in
      race) exit 1 ;;
      absent) ;;
      *) exit 64 ;;
    esac
    ;;
  *)
    printf 'unexpected npm invocation: %s\n' "$*" >&2
    exit 64
    ;;
esac
FAKE_NPM

cat > "$npm_fake_bin/sleep" <<'FAKE_SLEEP'
#!/bin/sh

printf '%s\n' 'sleep' >> "$RELEASE_WORKFLOW_TEST_LOG"
FAKE_SLEEP
chmod 755 "$npm_fake_bin/npm" "$npm_fake_bin/sleep"

npm_publish_script="$ROOT_DIR/scripts/release/publish-npm.sh publish"
require_npm_publish_scenario() {
  local scenario="$1"
  local expected_status="$2"
  local expected_packs="$3"
  local expected_version_views="$4"
  local expected_integrity_views="$5"
  local expected_publishes="$6"
  local expected_sleeps="$7"
  local log="$tmp_dir/npm-$scenario.log"
  local status
  local actual

  : > "$log"
  set +e
  PATH="$npm_fake_bin:$PATH" \
    RELEASE_WORKFLOW_TEST_LOG="$log" \
    FAKE_NPM_SCENARIO="$scenario" \
    V="0.7.0" \
    bash -c "$npm_publish_script" >"$tmp_dir/npm-$scenario.out" 2>&1
  status=$?
  set -e

  if [[ "$expected_status" == "success" ]]; then
    [[ "$status" -eq 0 ]] || fail "npm $scenario lookup unexpectedly failed"
  else
    [[ "$status" -ne 0 ]] || fail "npm $scenario lookup unexpectedly succeeded"
  fi

  actual="$(grep -Fxc 'pack' "$log" || true)"
  [[ "$actual" -eq "$expected_packs" ]] \
    || fail "npm $scenario packed $actual time(s); expected $expected_packs"
  actual="$(grep -Fxc 'view:versions' "$log" || true)"
  [[ "$actual" -eq "$expected_version_views" ]] \
    || fail "npm $scenario version lookup ran $actual time(s); expected $expected_version_views"
  actual="$(grep -Fxc 'view:integrity' "$log" || true)"
  [[ "$actual" -eq "$expected_integrity_views" ]] \
    || fail "npm $scenario integrity lookup ran $actual time(s); expected $expected_integrity_views"
  actual="$(grep -Fxc 'publish' "$log" || true)"
  [[ "$actual" -eq "$expected_publishes" ]] \
    || fail "npm $scenario published $actual time(s); expected $expected_publishes"
  actual="$(grep -Fxc 'sleep' "$log" || true)"
  [[ "$actual" -eq "$expected_sleeps" ]] \
    || fail "npm $scenario backoff ran $actual time(s); expected $expected_sleeps"
}

require_npm_publish_scenario present success 1 1 1 0 0
require_npm_publish_scenario absent success 1 2 1 1 0
require_npm_publish_scenario race success 1 2 1 1 0
require_npm_publish_scenario transient failure 1 5 0 0 4
require_npm_publish_scenario malformed_versions failure 1 5 0 0 4
require_npm_publish_scenario malformed_integrity failure 1 5 5 0 4
require_npm_publish_scenario mismatch failure 1 5 5 0 4

npm_verify_bin="$tmp_dir/npm-verify-bin"
mkdir -p "$npm_verify_bin"
cat > "$npm_verify_bin/npm" <<'FAKE_NPM_VERIFY'
#!/bin/sh
set -eu

[ "${1:-}" = install ] || exit 64
printf '%s\n' install >> "$RELEASE_WORKFLOW_TEST_LOG"
attempt="$(grep -Fxc install "$RELEASE_WORKFLOW_TEST_LOG")"
if [ "$FAKE_NPM_VERIFY_SCENARIO" = retry ] && [ "$attempt" -lt 3 ]; then
  exit 1
fi
if [ "$FAKE_NPM_VERIFY_SCENARIO" = unavailable ]; then
  exit 1
fi

shift
prefix=''
while [ "$#" -gt 0 ]; do
  if [ "$1" = --prefix ]; then
    prefix="$2"
    shift 2
  else
    shift
  fi
done
[ -n "$prefix" ]
mkdir -p "$prefix/bin"
cat > "$prefix/bin/codex-profile" <<'FAKE_INSTALLED_COMMAND'
#!/bin/sh
case "${1:-}" in
  help) exit 0 ;;
  version) printf '%s\n' 'codex-profile 0.7.0' ;;
  *) exit 64 ;;
esac
FAKE_INSTALLED_COMMAND
chmod 755 "$prefix/bin/codex-profile"
ln -s codex-profile "$prefix/bin/codex-profiles"
FAKE_NPM_VERIFY

cat > "$npm_verify_bin/sleep" <<'FAKE_NPM_VERIFY_SLEEP'
#!/bin/sh
printf '%s\n' sleep >> "$RELEASE_WORKFLOW_TEST_LOG"
FAKE_NPM_VERIFY_SLEEP
chmod 755 "$npm_verify_bin/npm" "$npm_verify_bin/sleep"

run_npm_verify() {
  local scenario="$1"
  local expected_status="$2"
  local expected_installs="$3"
  local expected_sleeps="$4"
  local log="$tmp_dir/npm-verify-$scenario.log"
  local status actual

  : > "$log"
  set +e
  PATH="$npm_verify_bin:$PATH" \
    RELEASE_WORKFLOW_TEST_LOG="$log" \
    FAKE_NPM_VERIFY_SCENARIO="$scenario" \
    V="0.7.0" \
    "$ROOT_DIR/scripts/release/publish-npm.sh" verify \
      >"$tmp_dir/npm-verify-$scenario.out" 2>&1
  status=$?
  set -e

  if [[ "$expected_status" = success ]]; then
    [[ "$status" -eq 0 ]] || fail "npm verify $scenario failed"
  else
    [[ "$status" -ne 0 ]] || fail "npm verify $scenario unexpectedly succeeded"
  fi
  actual="$(grep -Fxc install "$log" || true)"
  [[ "$actual" -eq "$expected_installs" ]] \
    || fail "npm verify $scenario installed $actual times; expected $expected_installs"
  actual="$(grep -Fxc sleep "$log" || true)"
  [[ "$actual" -eq "$expected_sleeps" ]] \
    || fail "npm verify $scenario slept $actual times; expected $expected_sleeps"
}

run_npm_verify retry success 3 2
run_npm_verify unavailable failure 10 9

printf '%s\n' 'npm release tests passed.'
