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

run_cmd_with_input() {
  local input="$1"
  shift

  set +e
  output="$(printf '%b' "$input" | "$@" 2>&1)"
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

assert_equals() {
  local expected="$1"

  if [[ "$output" != "$expected" ]]; then
    printf '%s\n' "$output" >&2
    fail "expected exact output: $expected"
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

test_version_prints_script_version() {
  run_cmd "$SCRIPT" version

  assert_status 0
  assert_equals "codex-profile 0.1.2-dev"

  run_cmd "$SCRIPT" --version

  assert_status 0
  assert_equals "codex-profile 0.1.2-dev"
}

test_cli_passes_profile_home_and_args() {
  local tmp fake_codex
  tmp="$(mktemp -d)"
  fake_codex="$tmp/codex"
  cat > "$fake_codex" <<'FAKE_CODEX'
#!/usr/bin/env bash
printf 'CODEX_HOME=%s\n' "$CODEX_HOME"
printf 'ARGS=%s\n' "$*"
FAKE_CODEX
  chmod 755 "$fake_codex"

  run_cmd env HOME="$tmp/home" CODEX_CLI="$fake_codex" "$SCRIPT" cli personal exec "run tests"

  assert_status 0
  assert_contains "CODEX_HOME=$tmp/home/.codex-personal"
  assert_contains "ARGS=exec run tests"
  [[ -d "$tmp/home/.codex-personal" ]] || fail "cli did not initialize profile home"

  rm -rf "$tmp"
}

test_login_passes_profile_home_and_login_args() {
  local tmp fake_codex
  tmp="$(mktemp -d)"
  fake_codex="$tmp/codex"
  cat > "$fake_codex" <<'FAKE_CODEX'
#!/usr/bin/env bash
printf 'CODEX_HOME=%s\n' "$CODEX_HOME"
printf 'ARGS=%s\n' "$*"
FAKE_CODEX
  chmod 755 "$fake_codex"

  run_cmd env HOME="$tmp/home" CODEX_CLI="$fake_codex" "$SCRIPT" login work --device-code

  assert_status 0
  assert_contains "CODEX_HOME=$tmp/home/.codex-work"
  assert_contains "ARGS=login --device-code"
  [[ -d "$tmp/home/.codex-work" ]] || fail "login did not initialize profile home"

  rm -rf "$tmp"
}

test_invalid_profile_names_are_rejected() {
  local tmp
  tmp="$(mktemp -d)"

  run_cmd env HOME="$tmp/home" "$SCRIPT" path ../bad

  assert_status 1
  assert_contains "Invalid profile '../bad'"

  rm -rf "$tmp"
}

test_list_reports_initialized_managed_profiles_without_cli() {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/home/.codex" \
    "$tmp/home/.codex-personal" \
    "$tmp/home/.codex-work" \
    "$tmp/home/.codex-dev" \
    "$tmp/home/.codex-main" \
    "$tmp/home/.codex-edu" \
    "$tmp/home/.codex-.bad"

  run_cmd env HOME="$tmp/home" CODEX_CLI=/no/such/codex "$SCRIPT" list

  assert_status 0
  assert_contains "default"
  assert_contains "personal"
  assert_contains "work"
  assert_not_contains "dev"
  assert_not_contains "main"
  assert_not_contains "edu"
  assert_not_contains ".bad"

  rm -rf "$tmp"
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

test_status_skips_unmanaged_and_invalid_discovered_dirs() {
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
  assert_not_contains "dev ($tmp/home/.codex-dev):"
  assert_not_contains "main ($tmp/home/.codex-main):"
  assert_not_contains "edu ($tmp/home/.codex-edu):"
  assert_not_contains ".bad"

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

test_init_creates_private_profile_home_without_codex() {
  local tmp profile_home
  tmp="$(mktemp -d)"
  profile_home="$tmp/home/.codex-personal"

  run_cmd env HOME="$tmp/home" CODEX_CLI=/no/such/codex "$SCRIPT" init personal

  assert_status 0
  assert_contains "Initialized personal ($profile_home)"
  [[ -d "$profile_home" ]] || fail "init did not create profile home"
  [[ "$(mode_of "$profile_home")" == "700" ]] || fail "profile home is not private"

  run_cmd env HOME="$tmp/home" CODEX_CLI=/no/such/codex "$SCRIPT" init personal

  assert_status 0
  assert_contains "Already initialized personal ($profile_home)"

  rm -rf "$tmp"
}

test_remove_aborts_when_confirmation_does_not_match() {
  local tmp profile_home
  tmp="$(mktemp -d)"
  profile_home="$tmp/home/.codex-personal"
  mkdir -p "$profile_home"

  run_cmd_with_input "wrong\n" env HOME="$tmp/home" "$SCRIPT" remove personal

  assert_status 1
  assert_contains "Confirmation did not match"
  [[ -d "$profile_home" ]] || fail "remove deleted profile after bad confirmation"

  rm -rf "$tmp"
}

test_remove_yes_deletes_profile_home() {
  local tmp profile_home
  tmp="$(mktemp -d)"
  profile_home="$tmp/home/.codex-personal"
  mkdir -p "$profile_home/logs"
  printf 'log\n' > "$profile_home/logs/desktop.log"

  run_cmd env HOME="$tmp/home" "$SCRIPT" remove personal --yes

  assert_status 0
  assert_contains "Removed personal ($profile_home)"
  [[ ! -e "$profile_home" ]] || fail "remove --yes did not delete profile home"

  rm -rf "$tmp"
}

test_remove_aliases_for_default_profile_are_rejected() {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/home/.codex"

  run_cmd env HOME="$tmp/home" "$SCRIPT" remove dev --yes

  assert_status 1
  assert_contains "Use 'default' to remove the default profile"
  [[ -d "$tmp/home/.codex" ]] || fail "remove dev deleted default profile"

  rm -rf "$tmp"
}

test_logs_prints_path_and_contents() {
  local tmp log_file
  tmp="$(mktemp -d)"
  log_file="$tmp/home/.codex-personal/logs/desktop.log"
  mkdir -p "${log_file%/*}"
  printf 'first line\nsecond line\n' > "$log_file"

  run_cmd env HOME="$tmp/home" "$SCRIPT" logs personal --path

  assert_status 0
  assert_equals "$log_file"

  run_cmd env HOME="$tmp/home" "$SCRIPT" logs personal

  assert_status 0
  assert_contains "first line"
  assert_contains "second line"

  rm -rf "$tmp"
}

test_logs_reports_missing_log_file() {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/home/.codex-personal"

  run_cmd env HOME="$tmp/home" "$SCRIPT" logs personal

  assert_status 1
  assert_contains "No desktop log for personal"

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
printf 'Not logged in\n'
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

test_completions_generate_shell_scripts() {
  run_cmd "$SCRIPT" completions bash

  assert_status 0
  assert_contains "complete -F _codex_profile codex-profile"
  assert_contains "clone-config"

  run_cmd "$SCRIPT" completions zsh

  assert_status 0
  assert_contains "#compdef codex-profile"
  assert_contains "logs"

  run_cmd "$SCRIPT" completions fish

  assert_status 0
  assert_contains "complete -c codex-profile"
  assert_contains "remove"
}

test_clone_config_copies_safe_files_and_never_auth_files() {
  local tmp source_home target_home
  tmp="$(mktemp -d)"
  source_home="$tmp/home/.codex-work"
  target_home="$tmp/home/.codex-personal"
  mkdir -p "$source_home/sessions"
  printf 'model = "gpt-5"\n' > "$source_home/config.toml"
  printf '# Instructions\n' > "$source_home/AGENTS.md"
  printf '{"token":"secret"}\n' > "$source_home/auth.json"
  printf 'private session\n' > "$source_home/sessions/session.json"

  run_cmd env HOME="$tmp/home" "$SCRIPT" clone-config work personal

  assert_status 0
  assert_contains "Copied config.toml"
  assert_contains "Copied AGENTS.md"
  [[ -f "$target_home/config.toml" ]] || fail "clone-config did not copy config.toml"
  [[ -f "$target_home/AGENTS.md" ]] || fail "clone-config did not copy AGENTS.md"
  [[ ! -e "$target_home/auth.json" ]] || fail "clone-config copied auth.json"
  [[ ! -e "$target_home/sessions" ]] || fail "clone-config copied sessions"

  rm -rf "$tmp"
}

test_clone_config_refuses_sensitive_looking_config() {
  local tmp source_home target_home
  tmp="$(mktemp -d)"
  source_home="$tmp/home/.codex-work"
  target_home="$tmp/home/.codex-personal"
  mkdir -p "$source_home"
  printf 'openai_api_key = "secret"\n' > "$source_home/config.toml"

  run_cmd env HOME="$tmp/home" "$SCRIPT" clone-config work personal

  assert_status 1
  assert_contains "Refusing to copy config.toml because it contains sensitive-looking keys"
  [[ ! -e "$target_home/config.toml" ]] || fail "clone-config copied sensitive-looking config"

  rm -rf "$tmp"
}

test_clone_config_refuses_symlinked_config_files() {
  local tmp source_home target_home outside_file
  tmp="$(mktemp -d)"
  source_home="$tmp/home/.codex-work"
  target_home="$tmp/home/.codex-personal"
  outside_file="$tmp/outside-config.toml"
  mkdir -p "$source_home"
  printf 'model = "gpt-5"\n' > "$outside_file"
  ln -s "$outside_file" "$source_home/config.toml"

  run_cmd env HOME="$tmp/home" "$SCRIPT" clone-config work personal

  assert_status 1
  assert_contains "Refusing to copy config.toml because it is a symlink"
  [[ ! -e "$target_home/config.toml" ]] || fail "clone-config copied symlinked config.toml"

  rm -rf "$tmp"
}

test_clone_config_refuses_symlinked_target_files_even_with_force() {
  local tmp source_home target_home outside_file
  tmp="$(mktemp -d)"
  source_home="$tmp/home/.codex-work"
  target_home="$tmp/home/.codex-personal"
  outside_file="$tmp/outside-target.toml"
  mkdir -p "$source_home" "$target_home"
  printf 'model = "gpt-5"\n' > "$source_home/config.toml"
  printf 'do not overwrite\n' > "$outside_file"
  ln -s "$outside_file" "$target_home/config.toml"

  run_cmd env HOME="$tmp/home" "$SCRIPT" clone-config work personal --force

  assert_status 1
  assert_contains "Refusing to overwrite config.toml because the target is a symlink"
  [[ "$(cat "$outside_file")" == "do not overwrite" ]] || fail "clone-config wrote through target symlink"

  rm -rf "$tmp"
}

test_clone_config_refuses_to_overwrite_without_force() {
  local tmp source_home target_home
  tmp="$(mktemp -d)"
  source_home="$tmp/home/.codex-work"
  target_home="$tmp/home/.codex-personal"
  mkdir -p "$source_home" "$target_home"
  printf 'model = "gpt-5"\n' > "$source_home/config.toml"
  printf 'model = "old"\n' > "$target_home/config.toml"

  run_cmd env HOME="$tmp/home" "$SCRIPT" clone-config work personal

  assert_status 1
  assert_contains "Refusing to overwrite config.toml"
  assert_contains "Use --force to overwrite"
  [[ "$(cat "$target_home/config.toml")" == 'model = "old"' ]] || fail "clone-config changed config.toml without --force"

  run_cmd env HOME="$tmp/home" "$SCRIPT" clone-config work personal --force

  assert_status 0
  assert_contains "Copied config.toml"
  [[ "$(cat "$target_home/config.toml")" == 'model = "gpt-5"' ]] || fail "clone-config --force did not overwrite config.toml"

  rm -rf "$tmp"
}

test_version_prints_script_version
test_cli_passes_profile_home_and_args
test_login_passes_profile_home_and_login_args
test_invalid_profile_names_are_rejected
test_list_reports_initialized_managed_profiles_without_cli
test_status_does_not_create_missing_profile_home
test_status_all_reports_missing_default_without_creating_it
test_status_skips_unmanaged_and_invalid_discovered_dirs
test_status_treats_not_logged_in_as_normal_status
test_status_propagates_unexpected_cli_failure
test_app_logs_stay_under_profile_home
test_app_refuses_to_launch_when_app_server_is_still_running
test_doctor_skips_status_when_cli_missing
test_init_creates_private_profile_home_without_codex
test_remove_aborts_when_confirmation_does_not_match
test_remove_yes_deletes_profile_home
test_remove_aliases_for_default_profile_are_rejected
test_logs_prints_path_and_contents
test_logs_reports_missing_log_file
test_status_json_reports_profiles_without_creating_missing_default
test_status_json_treats_not_logged_in_as_normal_status
test_status_json_escapes_control_characters
test_doctor_json_reports_missing_cli_and_skips_status
test_completions_generate_shell_scripts
test_clone_config_copies_safe_files_and_never_auth_files
test_clone_config_refuses_sensitive_looking_config
test_clone_config_refuses_symlinked_config_files
test_clone_config_refuses_symlinked_target_files_even_with_force
test_clone_config_refuses_to_overwrite_without_force
