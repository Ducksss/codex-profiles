#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/test/lib/assertions.sh"
source "$ROOT_DIR/test/lib/command-shims.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM
cd "$ROOT_DIR"
REPOSITORY_VERSION="$(node -p "require('./package.json').version")"

standalone_fake_bin="$tmp_dir/standalone-fake-bin"
standalone_installer_fixture="$tmp_dir/standalone-install.sh"
mkdir -p "$standalone_fake_bin"

cat > "$standalone_installer_fixture" <<'FAKE_STANDALONE_INSTALLER'
#!/bin/sh

set -eu

if [ "${CODEX_PROFILE_VERSION+x}" = x ]; then
  printf '%s\n' 'version-override-present' >> "$RELEASE_WORKFLOW_TEST_LOG"
  exit 70
fi

: "${CODEX_PROFILE_PREFIX:?}"
printf 'prefix:%s\n' "$CODEX_PROFILE_PREFIX" >> "$RELEASE_WORKFLOW_TEST_LOG"
latest_json="$(
  curl -fsSL \
    'https://api.github.com/repos/Ducksss/codex-profiles/releases/latest'
)"
latest_tag="$(
  printf '%s\n' "$latest_json" \
    | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    | head -n 1
)"
[ "$latest_tag" = 'v0.7.0' ]

mkdir -p "$CODEX_PROFILE_PREFIX/bin"
cat > "$CODEX_PROFILE_PREFIX/bin/codex-profile" <<'FAKE_STANDALONE_COMMAND'
#!/bin/sh

set -eu

case "${1:-}" in
  version)
    command_name="${0##*/}"
    printf 'version:%s\n' "$command_name" >> "$RELEASE_WORKFLOW_TEST_LOG"
    if [ "$command_name" = 'codex-profiles' ]; then
      reported_version="$FAKE_STANDALONE_ALIAS_VERSION"
    else
      reported_version="$FAKE_STANDALONE_CANONICAL_VERSION"
    fi
    printf 'codex-profile %s\n' "$reported_version"
    ;;
  *) exit 64 ;;
esac
FAKE_STANDALONE_COMMAND
chmod 755 "$CODEX_PROFILE_PREFIX/bin/codex-profile"

if [ "$FAKE_STANDALONE_SCENARIO" = 'canonical_symlink' ]; then
  mv \
    "$CODEX_PROFILE_PREFIX/bin/codex-profile" \
    "$CODEX_PROFILE_PREFIX/bin/codex-profile-real"
  ln -s codex-profile-real "$CODEX_PROFILE_PREFIX/bin/codex-profile"
fi

case "$FAKE_STANDALONE_SCENARIO" in
  missing_alias)
    ;;
  wrong_symlink)
    ln -s somewhere-else "$CODEX_PROFILE_PREFIX/bin/codex-profiles"
    ;;
  absolute_symlink)
    ln -s \
      "$CODEX_PROFILE_PREFIX/bin/codex-profile" \
      "$CODEX_PROFILE_PREFIX/bin/codex-profiles"
    ;;
  *)
    ln -s codex-profile "$CODEX_PROFILE_PREFIX/bin/codex-profiles"
    ;;
esac
FAKE_STANDALONE_INSTALLER

cat > "$standalone_fake_bin/curl" <<'FAKE_STANDALONE_CURL'
#!/bin/sh

set -eu

output=''
url=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      output="$2"
      shift 2
      ;;
    https://*)
      url="$1"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

case "$url" in
  https://raw.githubusercontent.com/Ducksss/codex-profiles/v0.7.0/install.sh)
    [ -n "$output" ]
    printf 'installer:%s\n' "$url" >> "$RELEASE_WORKFLOW_TEST_LOG"
    cp "$STANDALONE_INSTALLER_FIXTURE" "$output"
    ;;
  https://api.github.com/repos/Ducksss/codex-profiles/releases/latest)
    [ -z "$output" ]
    printf 'latest:%s\n' "${CODEX_PROFILE_PREFIX:-unset}" \
      >> "$RELEASE_WORKFLOW_TEST_LOG"
    latest_count="$(
      grep -c '^latest:' "$RELEASE_WORKFLOW_TEST_LOG" 2>/dev/null || true
    )"
    case "$FAKE_STANDALONE_SCENARIO" in
      retry)
        [ "$latest_count" -gt 2 ] || exit 22
        ;;
      unavailable)
        exit 22
        ;;
    esac
    printf '%s\n' '{"tag_name":"v0.7.0"}'
    ;;
  *)
    printf 'unexpected curl URL: %s\n' "$url" >&2
    exit 64
    ;;
esac
FAKE_STANDALONE_CURL

cat > "$standalone_fake_bin/sleep" <<'FAKE_STANDALONE_SLEEP'
#!/bin/sh

printf '%s\n' 'sleep' >> "$RELEASE_WORKFLOW_TEST_LOG"
FAKE_STANDALONE_SLEEP
chmod 755 \
  "$standalone_installer_fixture" \
  "$standalone_fake_bin/curl" \
  "$standalone_fake_bin/sleep"

standalone_verification_script=("$ROOT_DIR/scripts/release/verify-distribution.sh" standalone)
require_standalone_scenario() {
  local scenario="$1"
  local canonical_version="$2"
  local alias_version="$3"
  local expected_status="$4"
  local expected_attempts="$5"
  local expected_sleeps="$6"
  local expected_canonical_checks="$7"
  local expected_alias_checks="$8"
  local log="$tmp_dir/standalone-$scenario.log"
  local output="$tmp_dir/standalone-$scenario.out"
  local status
  local actual
  local unique_prefixes

  : > "$log"
  set +e
  PATH="$standalone_fake_bin:$PATH" \
    RELEASE_WORKFLOW_TEST_LOG="$log" \
    STANDALONE_INSTALLER_FIXTURE="$standalone_installer_fixture" \
    FAKE_STANDALONE_SCENARIO="$scenario" \
    FAKE_STANDALONE_CANONICAL_VERSION="$canonical_version" \
    FAKE_STANDALONE_ALIAS_VERSION="$alias_version" \
    CODEX_PROFILE_VERSION="v9.9.9" \
    TAG="v0.7.0" \
    V="0.7.0" \
    "${standalone_verification_script[@]}" > "$output" 2>&1
  status=$?
  set -e

  if [[ "$expected_status" == "success" ]]; then
    if [[ "$status" -ne 0 ]]; then
      cat "$output" >&2
      fail "standalone installer $scenario scenario unexpectedly failed"
    fi
  elif [[ "$status" -eq 0 ]]; then
    fail "standalone installer $scenario scenario unexpectedly succeeded"
  fi

  grep -Fx \
    'installer:https://raw.githubusercontent.com/Ducksss/codex-profiles/v0.7.0/install.sh' \
    "$log" >/dev/null \
    || fail "standalone installer $scenario scenario did not use the immutable tag"
  if grep -Fqx 'version-override-present' "$log"; then
    fail "standalone installer $scenario scenario received CODEX_PROFILE_VERSION"
  fi

  actual="$(grep -c '^prefix:' "$log" || true)"
  [[ "$actual" -eq "$expected_attempts" ]] \
    || fail "standalone installer $scenario used $actual prefixes; expected $expected_attempts"
  unique_prefixes="$(
    sed -n 's/^prefix://p' "$log" | sort -u | awk 'END { print NR + 0 }'
  )"
  [[ "$unique_prefixes" -eq "$expected_attempts" ]] \
    || fail "standalone installer $scenario reused an attempt prefix"
  actual="$(grep -c '^latest:' "$log" || true)"
  [[ "$actual" -eq "$expected_attempts" ]] \
    || fail "standalone installer $scenario queried releases/latest $actual times; expected $expected_attempts"
  actual="$(grep -Fxc 'sleep' "$log" || true)"
  [[ "$actual" -eq "$expected_sleeps" ]] \
    || fail "standalone installer $scenario slept $actual times; expected $expected_sleeps"
  actual="$(grep -Fxc 'version:codex-profile' "$log" || true)"
  [[ "$actual" -eq "$expected_canonical_checks" ]] \
    || fail "standalone installer $scenario checked the canonical command $actual times; expected $expected_canonical_checks"
  actual="$(grep -Fxc 'version:codex-profiles' "$log" || true)"
  [[ "$actual" -eq "$expected_alias_checks" ]] \
    || fail "standalone installer $scenario checked the plural command $actual times; expected $expected_alias_checks"
}

require_standalone_scenario success 0.7.0 0.7.0 success 1 0 1 1
require_standalone_scenario retry 0.7.0 0.7.0 success 3 2 1 1
require_standalone_scenario unavailable 0.7.0 0.7.0 failure 5 4 0 0
require_standalone_scenario wrong_canonical 0.6.0 0.7.0 failure 5 4 5 0
require_standalone_scenario wrong_alias 0.7.0 0.6.0 failure 5 4 5 5
require_standalone_scenario missing_alias 0.7.0 0.7.0 failure 5 4 0 0
require_standalone_scenario wrong_symlink 0.7.0 0.7.0 failure 5 4 0 0
require_standalone_scenario absolute_symlink 0.7.0 0.7.0 failure 5 4 0 0
require_standalone_scenario canonical_symlink 0.7.0 0.7.0 failure 5 4 0 0

aur_fake_bin="$tmp_dir/aur-fake-bin"
write_command_shim "$aur_fake_bin/curl" <<'SH'
set -eu
output=''
url=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o) output="$2"; shift 2 ;;
    https://*) url="$1"; shift ;;
    *) shift ;;
  esac
done
case "$url" in
  */bin/codex-profile) cp "$RELEASE_ROOT/bin/codex-profile" "$output" ;;
  */LICENSE) cp "$RELEASE_ROOT/LICENSE" "$output" ;;
  *) exit 64 ;;
esac
SH
write_command_shim "$aur_fake_bin/sha256sum" <<'SH'
set -eu
cat >/dev/null
SH
write_command_shim "$aur_fake_bin/install" <<'SH'
set -eu
mode="$1"
source_file="$2"
destination="$3"
mkdir -p "$(dirname "$destination")"
cp "$source_file" "$destination"
case "$mode" in
  -Dm755) chmod 755 "$destination" ;;
  -Dm644) chmod 644 "$destination" ;;
  *) exit 64 ;;
esac
SH

PATH="$aur_fake_bin:$PATH" \
  RELEASE_ROOT="$ROOT_DIR" \
  GITHUB_WORKSPACE="$ROOT_DIR" \
  TAG="v$REPOSITORY_VERSION" \
  "$ROOT_DIR/scripts/release/verify-distribution.sh" tagged-aur

set +e
tag_mismatch_output="$({
  PATH="$aur_fake_bin:$PATH" \
    RELEASE_ROOT="$ROOT_DIR" \
    GITHUB_WORKSPACE="$ROOT_DIR" \
    TAG="v9.9.9" \
    "$ROOT_DIR/scripts/release/verify-distribution.sh" tagged-aur
} 2>&1)"
tag_mismatch_status=$?
set -e
[[ "$tag_mismatch_status" -ne 0 ]] || fail "tagged AUR accepted a mismatched version"
[[ "$tag_mismatch_output" == *'does not match PKGBUILD version'* ]] \
  || fail "tagged AUR mismatch error is not actionable"

printf '%s\n' 'Release distribution tests passed.'
