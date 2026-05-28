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

write_fake_upgrade_repo() {
  local repo="$1"
  local version="$2"

  mkdir -p "$repo/bin"

  cat > "$repo/bin/codex-profile" <<FAKE_PROFILE
#!/usr/bin/env bash
VERSION="$version"
if [[ "\${1:-}" == "version" || "\${1:-}" == "--version" ]]; then
  printf 'codex-profile %s\n' "\$VERSION"
  exit 0
fi
printf 'fake codex-profile %s\n' "\$VERSION"
FAKE_PROFILE
  chmod 755 "$repo/bin/codex-profile"

  cat > "$repo/Makefile" <<'FAKE_MAKEFILE'
PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin

.PHONY: install

install:
	install -d "$(BINDIR)"
	install -m 755 bin/codex-profile "$(BINDIR)/codex-profile"
FAKE_MAKEFILE
}

init_git_main_branch() {
  local repo="$1"

  if git -C "$repo" init -b main >/dev/null 2>&1; then
    return 0
  fi

  git -C "$repo" init >/dev/null
  git -C "$repo" checkout -b main >/dev/null 2>&1
}

test_version_prints_script_version() {
  run_cmd "$SCRIPT" version

  assert_status 0
  assert_equals "codex-profile 0.2.0"

  run_cmd "$SCRIPT" --version

  assert_status 0
  assert_equals "codex-profile 0.2.0"
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

test_profile_path_mapping_only_special_cases_default() {
  local tmp
  tmp="$(mktemp -d)"

  run_cmd env HOME="$tmp/home" "$SCRIPT" path default

  assert_status 0
  assert_equals "$tmp/home/.codex"

  run_cmd env HOME="$tmp/home" "$SCRIPT" path dev

  assert_status 0
  assert_equals "$tmp/home/.codex-dev"

  run_cmd env HOME="$tmp/home" "$SCRIPT" path main

  assert_status 0
  assert_equals "$tmp/home/.codex-main"

  run_cmd env HOME="$tmp/home" "$SCRIPT" path edu

  assert_status 0
  assert_equals "$tmp/home/.codex-edu"

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
  assert_contains "dev"
  assert_contains "main"
  assert_contains "edu"
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

write_fake_codex_app_bundle() {
  local app="$1"
  local message="$2"

  mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
  cat > "$app/Contents/Info.plist" <<'FAKE_PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>Codex</string>
  <key>CFBundleExecutable</key>
  <string>Codex</string>
  <key>CFBundleIdentifier</key>
  <string>com.openai.codex</string>
  <key>CFBundleName</key>
  <string>Codex</string>
</dict>
</plist>
FAKE_PLIST

  cat > "$app/Contents/MacOS/Codex" <<FAKE_CODEX_APP
#!/usr/bin/env bash
printf 'MESSAGE=%s\n' "$message"
printf 'CODEX_HOME=%s\n' "\$CODEX_HOME"
printf 'ARGS=%s\n' "\$*"
FAKE_CODEX_APP
  chmod 755 "$app/Contents/MacOS/Codex"
}

write_fake_macos_bundle_tools() {
  local fake_bin="$1"

  mkdir -p "$fake_bin"
  cat > "$fake_bin/plutil" <<'FAKE_PLUTIL'
#!/usr/bin/env bash
printf 'plutil %s\n' "$*" >> "${FAKE_TOOL_LOG:?}"
exit 0
FAKE_PLUTIL
  chmod 755 "$fake_bin/plutil"

  cat > "$fake_bin/codesign" <<'FAKE_CODESIGN'
#!/usr/bin/env bash
printf 'codesign %s\n' "$*" >> "${FAKE_TOOL_LOG:?}"
exit 0
FAKE_CODESIGN
  chmod 755 "$fake_bin/codesign"

  cat > "$fake_bin/osascript" <<'FAKE_OSASCRIPT'
#!/usr/bin/env bash
printf 'osascript should not be called\n' >&2
exit 99
FAKE_OSASCRIPT
  chmod 755 "$fake_bin/osascript"

  cat > "$fake_bin/pgrep" <<'FAKE_PGREP'
#!/usr/bin/env bash
printf 'pgrep should not be called\n' >&2
exit 99
FAKE_PGREP
  chmod 755 "$fake_bin/pgrep"
}

test_app_instance_launches_parallel_profile_without_quitting_existing_app() {
  local tmp fake_app fake_bin tool_log instance_root instance_app log_file user_data_dir
  tmp="$(mktemp -d)"
  fake_app="$tmp/Codex.app"
  fake_bin="$tmp/bin"
  tool_log="$tmp/tool.log"
  instance_root="$tmp/instances"
  instance_app="$instance_root/personal/Codex personal.app"
  log_file="$tmp/home/.codex-personal/logs/desktop-instance.log"
  user_data_dir="$tmp/home/.codex-personal/electron-user-data"
  write_fake_codex_app_bundle "$fake_app" "parallel launch"
  write_fake_macos_bundle_tools "$fake_bin"

  run_cmd env HOME="$tmp/home" PATH="$fake_bin:$PATH" FAKE_TOOL_LOG="$tool_log" CODEX_APP="$fake_app" CODEX_PROFILE_APP_INSTANCE_ROOT="$instance_root" "$SCRIPT" app-instance personal "$tmp/workspace"

  assert_status 0
  assert_contains "Launching experimental Codex Desktop instance for personal"
  assert_contains "App bundle: $instance_app"
  assert_contains "Electron user data: $user_data_dir"
  assert_contains "Log: $log_file"
  [[ -x "$instance_app/Contents/MacOS/Codex" ]] || fail "app-instance did not create executable app clone"
  [[ -d "$user_data_dir" ]] || fail "app-instance did not create isolated Electron user data directory"
  [[ "$(mode_of "$tmp/home/.codex-personal")" == "700" ]] || fail "profile home is not private"
  [[ "$(mode_of "$user_data_dir")" == "700" ]] || fail "Electron user data directory is not private"

  for _ in {1..20}; do
    [[ -f "$log_file" ]] && grep -q "parallel launch" "$log_file" && break
    sleep 0.1
  done

  [[ -f "$log_file" ]] || fail "desktop instance log was not created"
  assert_not_contains "osascript should not be called"
  assert_not_contains "pgrep should not be called"
  grep -q "MESSAGE=parallel launch" "$log_file" || fail "app-instance did not launch cloned Codex app"
  grep -q "CODEX_HOME=$tmp/home/.codex-personal" "$log_file" || fail "app-instance did not pass profile CODEX_HOME"
  grep -q "ARGS=--user-data-dir=$user_data_dir $tmp/workspace" "$log_file" || fail "app-instance did not pass isolated user-data dir before workspace"
  grep -q "CFBundleIdentifier" "$tool_log" || fail "app-instance did not patch bundle identifier"
  grep -q "CFBundleDisplayName" "$tool_log" || fail "app-instance did not patch display name"
  grep -q "codesign --force --deep --sign -" "$tool_log" || fail "app-instance did not re-sign patched bundle"

  rm -rf "$tmp"
}

test_app_instance_rebuild_replaces_existing_profile_app_clone() {
  local tmp fake_app fake_bin tool_log instance_root instance_app stale_file log_file
  tmp="$(mktemp -d)"
  fake_app="$tmp/Codex.app"
  fake_bin="$tmp/bin"
  tool_log="$tmp/tool.log"
  instance_root="$tmp/instances"
  instance_app="$instance_root/work/Codex work.app"
  stale_file="$instance_app/stale"
  log_file="$tmp/home/.codex-work/logs/desktop-instance.log"
  write_fake_codex_app_bundle "$fake_app" "rebuilt launch"
  write_fake_macos_bundle_tools "$fake_bin"
  mkdir -p "$instance_app"
  printf 'stale\n' > "$stale_file"

  run_cmd env HOME="$tmp/home" PATH="$fake_bin:$PATH" FAKE_TOOL_LOG="$tool_log" CODEX_APP="$fake_app" CODEX_PROFILE_APP_INSTANCE_ROOT="$instance_root" "$SCRIPT" app-instance work --rebuild "$tmp/workspace"

  assert_status 0
  assert_contains "Rebuilding app instance for work"
  [[ ! -e "$stale_file" ]] || fail "app-instance --rebuild did not remove stale app clone"
  [[ -x "$instance_app/Contents/MacOS/Codex" ]] || fail "app-instance --rebuild did not recreate app clone"

  for _ in {1..20}; do
    [[ -f "$log_file" ]] && grep -q "rebuilt launch" "$log_file" && break
    sleep 0.1
  done

  grep -q "MESSAGE=rebuilt launch" "$log_file" || fail "rebuilt app instance did not launch"

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

test_remove_yes_deletes_profiles_named_like_common_aliases() {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/home/.codex" "$tmp/home/.codex-dev"

  run_cmd env HOME="$tmp/home" "$SCRIPT" remove dev --yes

  assert_status 0
  assert_contains "Removed dev ($tmp/home/.codex-dev)"
  [[ -d "$tmp/home/.codex" ]] || fail "remove dev deleted default profile"
  [[ ! -e "$tmp/home/.codex-dev" ]] || fail "remove dev did not delete the dev profile"

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

test_logs_prints_instance_path_and_contents() {
  local tmp log_file
  tmp="$(mktemp -d)"
  log_file="$tmp/home/.codex-personal/logs/desktop-instance.log"
  mkdir -p "${log_file%/*}"
  printf 'instance first\ninstance second\n' > "$log_file"

  run_cmd env HOME="$tmp/home" "$SCRIPT" logs personal --instance --path

  assert_status 0
  assert_equals "$log_file"

  run_cmd env HOME="$tmp/home" "$SCRIPT" logs personal --instance --tail 1

  assert_status 0
  assert_equals "instance second"

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
  run_cmd "$SCRIPT" help

  assert_status 0
  assert_contains "app-instance"

  run_cmd "$SCRIPT" completions bash

  assert_status 0
  assert_contains "complete -F _codex_profile codex-profile"
  assert_contains "clone-config"
  assert_contains "upgrade"
  assert_contains "app-instance"

  run_cmd "$SCRIPT" completions zsh

  assert_status 0
  assert_contains "#compdef codex-profile"
  assert_contains "logs"
  assert_contains "upgrade"
  assert_contains "app-instance"

  run_cmd "$SCRIPT" completions fish

  assert_status 0
  assert_contains "complete -c codex-profile"
  assert_contains "remove"
  assert_contains "upgrade"
  assert_contains "app-instance"
}

test_upgrade_dry_run_reports_plan_without_mutating_files() {
  local tmp repo cache prefix
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  cache="$tmp/cache/source"
  prefix="$tmp/prefix"
  write_fake_upgrade_repo "$repo" "9.9.9"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_UPGRADE_REPO="$repo" CODEX_PROFILE_UPGRADE_CACHE="$cache" "$SCRIPT" upgrade --dry-run --prefix "$prefix"

  assert_status 0
  assert_contains "Upgrade plan"
  assert_contains "Repository: $repo"
  assert_contains "Ref: main"
  assert_contains "Install prefix: $prefix"
  [[ ! -e "$cache" ]] || fail "upgrade --dry-run created the cache checkout"
  [[ ! -e "$prefix" ]] || fail "upgrade --dry-run created the install prefix"

  rm -rf "$tmp"
}

test_upgrade_fetches_newest_ref_and_installs_to_prefix() {
  local tmp repo cache prefix installed
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  cache="$tmp/cache/source"
  prefix="$tmp/prefix"
  installed="$prefix/bin/codex-profile"
  mkdir -p "$repo"
  init_git_main_branch "$repo"
  write_fake_upgrade_repo "$repo" "1.0.0"
  git -C "$repo" add .
  git -C "$repo" -c user.name=test -c user.email=test@example.com commit -m "v1" >/dev/null

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_UPGRADE_REPO="$repo" CODEX_PROFILE_UPGRADE_CACHE="$cache" "$SCRIPT" upgrade --prefix "$prefix"

  assert_status 0
  assert_contains "Installed codex-profile 1.0.0"
  [[ -x "$installed" ]] || fail "upgrade did not install codex-profile"

  write_fake_upgrade_repo "$repo" "1.0.1"
  git -C "$repo" add .
  git -C "$repo" -c user.name=test -c user.email=test@example.com commit -m "v2" >/dev/null

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_UPGRADE_REPO="$repo" CODEX_PROFILE_UPGRADE_CACHE="$cache" "$SCRIPT" upgrade --prefix "$prefix"

  assert_status 0
  assert_contains "Installed codex-profile 1.0.1"
  run_cmd "$installed" version
  assert_status 0
  assert_equals "codex-profile 1.0.1"

  rm -rf "$tmp"
}

test_upgrade_installs_commit_sha_ref_on_fresh_cache() {
  local tmp repo cache prefix installed sha
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  cache="$tmp/cache/source"
  prefix="$tmp/prefix"
  installed="$prefix/bin/codex-profile"
  mkdir -p "$repo"
  init_git_main_branch "$repo"
  write_fake_upgrade_repo "$repo" "1.0.0"
  git -C "$repo" add .
  git -C "$repo" -c user.name=test -c user.email=test@example.com commit -m "v1" >/dev/null
  sha="$(git -C "$repo" rev-parse HEAD)"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_UPGRADE_REPO="$repo" CODEX_PROFILE_UPGRADE_CACHE="$cache" "$SCRIPT" upgrade --prefix "$prefix" --ref "$sha"

  assert_status 0
  assert_contains "Installed codex-profile 1.0.0"
  run_cmd "$installed" version
  assert_status 0
  assert_equals "codex-profile 1.0.0"

  rm -rf "$tmp"
}

test_upgrade_refuses_dirty_cached_checkout() {
  local tmp repo cache prefix
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  cache="$tmp/cache/source"
  prefix="$tmp/prefix"
  mkdir -p "$repo"
  init_git_main_branch "$repo"
  write_fake_upgrade_repo "$repo" "1.0.0"
  git -C "$repo" add .
  git -C "$repo" -c user.name=test -c user.email=test@example.com commit -m "v1" >/dev/null
  git clone "$repo" "$cache" >/dev/null 2>&1
  printf 'local edit\n' >> "$cache/bin/codex-profile"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_UPGRADE_REPO="$repo" CODEX_PROFILE_UPGRADE_CACHE="$cache" "$SCRIPT" upgrade --prefix "$prefix"

  assert_status 1
  assert_contains "Cached upgrade checkout has local changes"
  [[ ! -e "$prefix/bin/codex-profile" ]] || fail "upgrade installed from a dirty cache"

  rm -rf "$tmp"
}

test_upgrade_refuses_to_install_older_version() {
  local tmp repo cache prefix
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  cache="$tmp/cache/source"
  prefix="$tmp/prefix"
  mkdir -p "$repo"
  init_git_main_branch "$repo"
  write_fake_upgrade_repo "$repo" "0.1.1"
  git -C "$repo" add .
  git -C "$repo" -c user.name=test -c user.email=test@example.com commit -m "old" >/dev/null

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_UPGRADE_REPO="$repo" CODEX_PROFILE_UPGRADE_CACHE="$cache" "$SCRIPT" upgrade --prefix "$prefix"

  assert_status 1
  assert_contains "Refusing to install older codex-profile 0.1.1"
  [[ ! -e "$prefix/bin/codex-profile" ]] || fail "upgrade installed an older codex-profile"

  rm -rf "$tmp"
}

test_upgrade_refuses_unversioned_candidate() {
  local tmp repo cache prefix
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  cache="$tmp/cache/source"
  prefix="$tmp/prefix"
  mkdir -p "$repo/bin"
  init_git_main_branch "$repo"
  cat > "$repo/bin/codex-profile" <<'FAKE_PROFILE'
#!/usr/bin/env bash
printf 'old unversioned codex-profile\n'
FAKE_PROFILE
  chmod 755 "$repo/bin/codex-profile"
  cat > "$repo/Makefile" <<'FAKE_MAKEFILE'
PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin

.PHONY: install

install:
	install -d "$(BINDIR)"
	install -m 755 bin/codex-profile "$(BINDIR)/codex-profile"
FAKE_MAKEFILE
  git -C "$repo" add .
  git -C "$repo" -c user.name=test -c user.email=test@example.com commit -m "unversioned" >/dev/null

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_UPGRADE_REPO="$repo" CODEX_PROFILE_UPGRADE_CACHE="$cache" "$SCRIPT" upgrade --prefix "$prefix"

  assert_status 1
  assert_contains "Refusing to install candidate without a declared VERSION"
  [[ ! -e "$prefix/bin/codex-profile" ]] || fail "upgrade installed an unversioned codex-profile"

  rm -rf "$tmp"
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
test_profile_path_mapping_only_special_cases_default
test_list_reports_initialized_managed_profiles_without_cli
test_status_does_not_create_missing_profile_home
test_status_all_reports_missing_default_without_creating_it
test_status_reports_arbitrary_discovered_profiles_and_skips_invalid_dirs
test_status_treats_not_logged_in_as_normal_status
test_status_propagates_unexpected_cli_failure
test_app_logs_stay_under_profile_home
test_app_refuses_to_launch_when_app_server_is_still_running
test_app_instance_launches_parallel_profile_without_quitting_existing_app
test_app_instance_rebuild_replaces_existing_profile_app_clone
test_doctor_skips_status_when_cli_missing
test_init_creates_private_profile_home_without_codex
test_remove_aborts_when_confirmation_does_not_match
test_remove_yes_deletes_profile_home
test_remove_yes_deletes_profiles_named_like_common_aliases
test_logs_prints_path_and_contents
test_logs_prints_instance_path_and_contents
test_logs_reports_missing_log_file
test_status_json_reports_profiles_without_creating_missing_default
test_status_json_treats_not_logged_in_as_normal_status
test_status_json_escapes_control_characters
test_doctor_json_reports_missing_cli_and_skips_status
test_completions_generate_shell_scripts
test_upgrade_dry_run_reports_plan_without_mutating_files
test_upgrade_fetches_newest_ref_and_installs_to_prefix
test_upgrade_installs_commit_sha_ref_on_fresh_cache
test_upgrade_refuses_dirty_cached_checkout
test_upgrade_refuses_to_install_older_version
test_upgrade_refuses_unversioned_candidate
test_clone_config_copies_safe_files_and_never_auth_files
test_clone_config_refuses_sensitive_looking_config
test_clone_config_refuses_symlinked_config_files
test_clone_config_refuses_symlinked_target_files_even_with_force
test_clone_config_refuses_to_overwrite_without_force
