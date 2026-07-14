#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/test/lib/assertions.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
source "$ROOT_DIR/test/lib/cli-fixtures.sh"

test_status_does_not_create_missing_profile_home() {
  local tmp fake_codex
  tmp="$(mktemp -d)"
  fake_codex="$tmp/codex"
  printf '#!/usr/bin/env bash\nprintf "fake codex should not run\\n" >&2\nexit 99\n' > "$fake_codex"
  chmod 755 "$fake_codex"

  run_cmd env HOME="$tmp/home" CODEX_CLI="$fake_codex" "$SCRIPT" status personal

  assert_status 0
  assert_contains "personal ($tmp/home/.codex-personal): Not initialized"
  assert_not_contains "fake codex should not run"
  [[ ! -e "$tmp/home/.codex-personal" ]] || fail "status created a missing profile home"

  rm -rf "$tmp"
}

test_status_all_reports_missing_default_without_creating_it() {
  local tmp fake_codex
  tmp="$(mktemp -d)"
  fake_codex="$tmp/codex"
  write_fake_codex "$fake_codex"
  mkdir -p "$tmp/home/.codex-personal"

  run_cmd env HOME="$tmp/home" CODEX_CLI="$fake_codex" "$SCRIPT" status

  assert_status 0
  assert_contains "default ($tmp/home/.codex): Not initialized"
  assert_contains "personal ($tmp/home/.codex-personal): login status"
  [[ ! -e "$tmp/home/.codex" ]] || fail "status created the default profile home"

  rm -rf "$tmp"
}

test_status_reports_arbitrary_discovered_profiles_and_skips_invalid_dirs() {
  local tmp fake_codex
  tmp="$(mktemp -d)"
  fake_codex="$tmp/codex"
  write_fake_codex "$fake_codex"
  mkdir -p "$tmp/home/.codex" \
    "$tmp/home/.codex-personal" \
    "$tmp/home/.codex-dev" \
    "$tmp/home/.codex-main" \
    "$tmp/home/.codex-edu" \
    "$tmp/home/.codex-.bad"

  run_cmd env HOME="$tmp/home" CODEX_CLI="$fake_codex" "$SCRIPT" status

  assert_status 0
  assert_contains "default ($tmp/home/.codex): login status"
  assert_contains "personal ($tmp/home/.codex-personal): login status"
  assert_contains "dev ($tmp/home/.codex-dev): login status"
  assert_contains "main ($tmp/home/.codex-main): login status"
  assert_contains "edu ($tmp/home/.codex-edu): login status"
  assert_not_contains ".bad"

  rm -rf "$tmp"
}

test_status_treats_not_logged_in_as_normal_status() {
  local tmp fake_codex
  tmp="$(mktemp -d)"
  fake_codex="$tmp/codex"
  cat > "$fake_codex" <<'FAKE_CODEX'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  printf 'fake-codex 1.0\n'
  exit 0
fi
printf 'You are not logged in. Run codex login.\n'
exit 1
FAKE_CODEX
  chmod 755 "$fake_codex"
  mkdir -p "$tmp/home/.codex-personal"

  run_cmd env HOME="$tmp/home" CODEX_CLI="$fake_codex" "$SCRIPT" status personal

  assert_status 0
  assert_contains "personal ($tmp/home/.codex-personal): You are not logged in"

  rm -rf "$tmp"
}

test_status_propagates_unexpected_cli_failure() {
  local tmp fake_codex
  tmp="$(mktemp -d)"
  fake_codex="$tmp/codex"
  cat > "$fake_codex" <<'FAKE_CODEX'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  printf 'fake-codex 1.0\n'
  exit 0
fi
printf 'database exploded\n' >&2
exit 7
FAKE_CODEX
  chmod 755 "$fake_codex"
  mkdir -p "$tmp/home/.codex-personal"

  run_cmd env HOME="$tmp/home" CODEX_CLI="$fake_codex" "$SCRIPT" status personal

  assert_status 7
  assert_contains "personal ($tmp/home/.codex-personal): database exploded"

  rm -rf "$tmp"
}

test_doctor_skips_status_when_cli_missing() {
  local tmp
  tmp="$(mktemp -d)"

  run_cmd env HOME="$tmp/home" CODEX_CLI=/no/such/codex "$SCRIPT" doctor

  assert_status 0
  assert_contains "CLI: missing"
  assert_contains "Status: skipped"

  rm -rf "$tmp"
}

test_status_json_reports_profiles_without_creating_missing_default() {
  local tmp fake_codex
  tmp="$(mktemp -d)"
  fake_codex="$tmp/codex"
  write_fake_codex "$fake_codex"
  mkdir -p "$tmp/home/.codex-personal"

  run_cmd env HOME="$tmp/home" CODEX_CLI="$fake_codex" "$SCRIPT" status --json

  assert_status 0
  assert_contains '"profiles":['
  assert_contains '"name":"default"'
  assert_contains '"home":"'"$tmp"'/home/.codex"'
  assert_contains '"state":"not_initialized"'
  assert_contains '"name":"personal"'
  assert_contains '"home":"'"$tmp"'/home/.codex-personal"'
  assert_contains '"state":"ok"'
  assert_contains '"status":"login status"'
  [[ ! -e "$tmp/home/.codex" ]] || fail "status --json created missing default profile home"

  rm -rf "$tmp"
}

test_status_json_treats_not_logged_in_as_normal_status() {
  local tmp fake_codex
  tmp="$(mktemp -d)"
  fake_codex="$tmp/codex"
  cat > "$fake_codex" <<'FAKE_CODEX'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  printf 'fake-codex 1.0\n'
  exit 0
fi
printf 'No login credentials found for this profile.\n'
exit 1
FAKE_CODEX
  chmod 755 "$fake_codex"
  mkdir -p "$tmp/home/.codex-personal"

  run_cmd env HOME="$tmp/home" CODEX_CLI="$fake_codex" "$SCRIPT" status personal --json

  assert_status 0
  assert_contains '"name":"personal"'
  assert_contains '"state":"not_logged_in"'
  assert_contains '"exit_code":1'
  assert_contains ']}'

  rm -rf "$tmp"
}

test_status_json_escapes_control_characters() {
  local tmp fake_codex
  tmp="$(mktemp -d)"
  fake_codex="$tmp/codex"
  cat > "$fake_codex" <<'FAKE_CODEX'
#!/usr/bin/env bash
printf 'ok\001\b\f\nend'
FAKE_CODEX
  chmod 755 "$fake_codex"
  mkdir -p "$tmp/home/.codex-personal"

  run_cmd env HOME="$tmp/home" CODEX_CLI="$fake_codex" "$SCRIPT" status personal --json

  assert_status 0
  assert_contains '"status":"ok\u0001\b\f\nend"'

  rm -rf "$tmp"
}

test_doctor_json_reports_missing_cli_and_skips_status() {
  local tmp
  tmp="$(mktemp -d)"

  run_cmd env HOME="$tmp/home" CODEX_CLI=/no/such/codex "$SCRIPT" doctor --json

  assert_status 0
  assert_contains '"desktop":{'
  assert_contains '"cli":{"found":false'
  assert_contains '"status":{"skipped":true'

  rm -rf "$tmp"
}

test_json_commands_never_emit_update_notices() {
  local tmp cache fake_codex now
  tmp="$(mktemp -d)"
  cache="$tmp/update-check"
  fake_codex="$tmp/codex"
  now="$(date +%s)"
  printf '%s 9.9.9\n' "$now" > "$cache"
  write_fake_codex "$fake_codex"
  mkdir -p "$tmp/home/.codex-personal"

  run_cmd env HOME="$tmp/home" CODEX_CLI="$fake_codex" \
    CODEX_PROFILE_FORCE_UPDATE_CHECK=1 CODEX_PROFILE_UPDATE_CACHE="$cache" \
    "$SCRIPT" status --json personal

  assert_status 0
  assert_not_contains "available"
  [[ "$output" == \{*\} ]] || fail "status --json was polluted by non-JSON output"

  run_cmd env HOME="$tmp/home" CODEX_CLI="$fake_codex" \
    CODEX_PROFILE_FORCE_UPDATE_CHECK=1 CODEX_PROFILE_UPDATE_CACHE="$cache" \
    "$SCRIPT" doctor --json

  assert_status 0
  assert_not_contains "available"
  [[ "$output" == \{*\} ]] || fail "doctor --json was polluted by non-JSON output"

  rm -rf "$tmp"
}

test_status_does_not_create_missing_profile_home
test_status_all_reports_missing_default_without_creating_it
test_status_reports_arbitrary_discovered_profiles_and_skips_invalid_dirs
test_status_treats_not_logged_in_as_normal_status
test_status_propagates_unexpected_cli_failure
test_doctor_skips_status_when_cli_missing
test_status_json_reports_profiles_without_creating_missing_default
test_status_json_treats_not_logged_in_as_normal_status
test_status_json_escapes_control_characters
test_doctor_json_reports_missing_cli_and_skips_status
test_json_commands_never_emit_update_notices
