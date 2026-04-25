#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/bin/codex-profile"

output=""
status=0

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

run_cmd() {
  set +e
  output="$("$@" 2>&1)"
  status=$?
  set -e
}

assert_status() {
  local expected="$1"

  if [[ "$status" -ne "$expected" ]]; then
    printf '%s\n' "$output" >&2
    fail "expected exit $expected, got $status"
  fi
}

assert_contains() {
  local needle="$1"

  if [[ "$output" != *"$needle"* ]]; then
    printf '%s\n' "$output" >&2
    fail "expected output to contain: $needle"
  fi
}

assert_not_contains() {
  local needle="$1"

  if [[ "$output" == *"$needle"* ]]; then
    printf '%s\n' "$output" >&2
    fail "expected output not to contain: $needle"
  fi
}

mode_of() {
  if stat -f '%Lp' "$1" > /dev/null 2>&1; then
    stat -f '%Lp' "$1"
  else
    stat -c '%a' "$1"
  fi
}

write_fake_codex() {
  local path="$1"

  cat > "$path" <<'FAKE_CODEX'
#!/usr/bin/env bash

if [[ "${1:-}" == "--version" ]]; then
  printf 'fake-codex 1.0\n'
  exit 0
fi

if [[ ! -d "${CODEX_HOME:-}" ]]; then
  printf 'CODEX_HOME missing: %s\n' "${CODEX_HOME:-}" >&2
  exit 42
fi

printf '%s\n' "$*"
FAKE_CODEX
  chmod 755 "$path"
}

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

test_status_treats_not_logged_in_as_normal_status() {
  local tmp fake_codex
  tmp="$(mktemp -d)"
  fake_codex="$tmp/codex"
  cat > "$fake_codex" <<'FAKE_CODEX'
#!/usr/bin/env bash
printf 'Not logged in\n'
exit 1
FAKE_CODEX
  chmod 755 "$fake_codex"
  mkdir -p "$tmp/home/.codex-personal"

  run_cmd env HOME="$tmp/home" CODEX_CLI="$fake_codex" "$SCRIPT" status personal

  assert_status 0
  assert_contains "personal ($tmp/home/.codex-personal): Not logged in"

  rm -rf "$tmp"
}

test_status_propagates_unexpected_cli_failure() {
  local tmp fake_codex
  tmp="$(mktemp -d)"
  fake_codex="$tmp/codex"
  cat > "$fake_codex" <<'FAKE_CODEX'
#!/usr/bin/env bash
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

test_app_logs_stay_under_profile_home() {
  local tmp fake_bin log_file log_dir
  tmp="$(mktemp -d)"
  fake_bin="$tmp/bin"
  mkdir -p "$fake_bin" "$tmp/home"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$fake_bin/pgrep"
  chmod 755 "$fake_bin/pgrep"

  run_cmd env HOME="$tmp/home" PATH="$fake_bin:$PATH" CODEX_APP_BIN=/bin/echo "$SCRIPT" app personal "$tmp/workspace"

  log_dir="$tmp/home/.codex-personal/logs"
  log_file="$log_dir/desktop.log"
  assert_status 0
  assert_contains "Log: $log_file"
  assert_not_contains "/tmp/codex-personal.log"

  for _ in {1..20}; do
    [[ -f "$log_file" ]] && break
    sleep 0.1
  done

  [[ -f "$log_file" ]] || fail "desktop log was not created"
  [[ "$(mode_of "$log_dir")" == "700" ]] || fail "log directory is not private"
  [[ "$(mode_of "$log_file")" == "600" ]] || fail "desktop log is not private"

  rm -rf "$tmp"
}

test_app_refuses_to_launch_when_app_server_is_still_running() {
  local tmp fake_bin fake_codex
  tmp="$(mktemp -d)"
  fake_bin="$tmp/bin"
  fake_codex="$tmp/codex"
  mkdir -p "$fake_bin" "$tmp/home"

  cat > "$fake_bin/pgrep" <<'FAKE_PGREP'
#!/usr/bin/env bash
if [[ "${1:-}" == "-x" && "${2:-}" == "Codex" ]]; then
  exit 1
fi

if [[ "${1:-}" == "-f" && "${2:-}" == *"app-server"* ]]; then
  exit 0
fi

exit 1
FAKE_PGREP
  chmod 755 "$fake_bin/pgrep"

  printf '#!/usr/bin/env bash\nexit 0\n' > "$fake_bin/osascript"
  chmod 755 "$fake_bin/osascript"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$fake_codex"
  chmod 755 "$fake_codex"

  run_cmd env HOME="$tmp/home" PATH="$fake_bin:$PATH" CODEX_APP_BIN=/bin/echo CODEX_BUNDLED_CLI="$fake_codex" CODEX_PROFILE_QUIT_ATTEMPTS=1 CODEX_PROFILE_QUIT_SLEEP=0 "$SCRIPT" app personal "$tmp/workspace"

  assert_status 1
  assert_contains "Codex or its app-server is still running"

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

test_status_does_not_create_missing_profile_home
test_status_all_reports_missing_default_without_creating_it
test_status_treats_not_logged_in_as_normal_status
test_status_propagates_unexpected_cli_failure
test_app_logs_stay_under_profile_home
test_app_refuses_to_launch_when_app_server_is_still_running
test_doctor_skips_status_when_cli_missing
