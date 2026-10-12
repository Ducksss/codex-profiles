#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/test/lib/assertions.sh"
source "$ROOT_DIR/test/lib/command-shims.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM
SCRIPT="$ROOT_DIR/scripts/release/set-npm-token.sh"
fake_bin="$tmp_dir/bin"
log="$tmp_dir/commands.log"
secret="$tmp_dir/secret"

# npm accepts only an isolated config that resolves auth from NODE_AUTH_TOKEN.
# Like real npm, an inherited npm_config_* variable outranks that config.
write_command_shim "$fake_bin/npm" <<'FAKE_NPM'
printf 'npm %s\n' "$*" >> "$TEST_LOG"
if env | grep -q '^npm_config_'; then
  case "$1" in
    whoami) printf 'maintainer\n' ;;
    owner) printf 'maintainer <maintainer@example.com>\n' ;;
  esac
  exit 0
fi
grep -qx '//registry.npmjs.org/:_authToken=${NODE_AUTH_TOKEN}' "$NPM_CONFIG_USERCONFIG" || exit 90
[ ! -s "$NPM_CONFIG_GLOBALCONFIG" ] || exit 91
case "$NODE_AUTH_TOKEN" in
  npm_good) user=maintainer ;;
  npm_stranger) user=stranger ;;
  *) exit 1 ;;
esac
case "$1" in
  whoami) printf '%s\n' "$user" ;;
  owner) printf 'maintainer <maintainer@example.com>\n' ;;
  *) exit 2 ;;
esac
FAKE_NPM

write_command_shim "$fake_bin/gh" <<'FAKE_GH'
printf 'gh %s\n' "$*" >> "$TEST_LOG"
case "$1 $2" in
  'auth status') exit 0 ;;
  'secret set') cat > "$TEST_SECRET" ;;
  'secret list')
    case "$*" in
      *--env*) printf 'TAP_TOKEN\n' ;;
      *) printf '2026-10-12T00:00:00Z\n' ;;
    esac
    ;;
  *) exit 2 ;;
esac
FAKE_GH

run_with_token() {
  local token="$1"
  shift
  : > "$log"
  rm -f "$secret"
  set +e
  output="$(printf '%s\n' "$token" | env PATH="$fake_bin:$PATH" TEST_LOG="$log" \
    TEST_SECRET="$secret" "$SCRIPT" "$@" 2>&1)"
  status=$?
  set -e
}

run_with_token '  npm_good  ' --yes
assert_status 0
assert_contains 'authenticates as maintainer, an owner of codex-profile'
assert_contains 'Updated NPM_TOKEN on Ducksss/codex-profiles at 2026-10-12T00:00:00Z.'
assert_not_contains 'npm_good'
[[ "$(cat "$secret")" == npm_good ]] || fail "gh did not receive the trimmed token on stdin"
! grep -q npm_good "$log" || fail "the token appeared in a command argument list"
grep -qx 'gh secret set NPM_TOKEN --repo Ducksss/codex-profiles' "$log" \
  || fail "the secret was not set on the expected repository"

run_with_token npm_expired --yes
assert_status 1
assert_contains 'could not authenticate with the npm registry; NPM_TOKEN was not changed.'
[[ ! -e "$secret" ]] || fail "a rejected token was stored"

# Inherited npm configuration must not vouch for the candidate token.
: > "$log"
rm -f "$secret"
set +e
output="$(printf 'npm_expired\n' | env PATH="$fake_bin:$PATH" TEST_LOG="$log" \
  TEST_SECRET="$secret" 'npm_config_//registry.npmjs.org/:_authToken=npm_good' \
  npm_config_userconfig=/dev/null "$SCRIPT" --yes 2>&1)"
status=$?
set -e
assert_status 1
assert_contains 'could not authenticate with the npm registry'
[[ ! -e "$secret" ]] || fail "inherited npm configuration let a bad token through"

run_with_token npm_stranger --yes
assert_status 1
assert_contains "npm user 'stranger' is not an owner of codex-profile"
[[ ! -e "$secret" ]] || fail "a non-owner token was stored"

run_with_token '' --yes
assert_status 1
assert_contains 'No token entered; NPM_TOKEN was not changed.'

run_with_token 'npm_good extra' --yes
assert_status 1
assert_contains 'contains spaces or control characters'

run_with_token npm_good --force
assert_status 1
assert_contains "Unknown option '--force'"

printf 'npm token script tests passed.\n'
