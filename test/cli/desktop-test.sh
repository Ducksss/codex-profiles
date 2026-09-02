#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/test/lib/assertions.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
source "$ROOT_DIR/test/lib/cli-fixtures.sh"

test_app_requires_an_initialized_profile() {
  local tmp chatgpt_app fake_bin tool_log
  tmp="$(mktemp -d)"
  chatgpt_app="$tmp/ChatGPT.app"
  fake_bin="$tmp/bin"
  tool_log="$tmp/tool.log"
  write_fake_chatgpt_app_bundle "$chatgpt_app" "must not launch"
  write_fake_chatgpt_open_tools "$fake_bin"

  run_cmd env HOME="$tmp/home" PATH="$fake_bin:$PATH" FAKE_TOOL_LOG="$tool_log" \
    CHATGPT_APP="$chatgpt_app" "$SCRIPT" app typo

  assert_status 1
  assert_contains "Profile 'typo' is not initialized"
  [[ ! -e "$tmp/home/.codex-typo" ]] || fail "app created an uninitialized profile"
  [[ ! -e "$tool_log" ]] || ! grep -q '^open ' "$tool_log" || fail "app launched an uninitialized profile"

  rm -rf "$tmp"
}

test_app_named_profile_uses_separate_local_state_for_the_whole_chatgpt_window() {
  local tmp chatgpt_app ignored_app fake_bin tool_log profile_home user_data_dir log_file
  tmp="$(mktemp -d)"
  chatgpt_app="$tmp/Application Support/ChatGPT.app"
  ignored_app="$tmp/ignored/Codex.app"
  fake_bin="$tmp/bin"
  tool_log="$tmp/tool.log"
  profile_home="$tmp/home/.codex-personal"
  user_data_dir="$profile_home/electron-user-data"
  log_file="$profile_home/logs/desktop.log"
  write_fake_chatgpt_app_bundle "$chatgpt_app" "named ChatGPT launch"
  write_fake_chatgpt_app_bundle "$ignored_app" "wrong legacy app"
  write_fake_chatgpt_open_tools "$fake_bin"
  mkdir -p "$profile_home"

  run_cmd env HOME="$tmp/home" PATH="$fake_bin:$PATH" FAKE_TOOL_LOG="$tool_log" \
    CHATGPT_APP="$chatgpt_app" CODEX_APP="$ignored_app" \
    "$SCRIPT" app personal "$tmp/work space"

  assert_status 0
  assert_contains "Launching ChatGPT for profile personal"
  assert_contains "Desktop scope: separate Electron state for this named ChatGPT window (separate local state across Chat, Work, and Codex)"
  assert_not_contains "isolated ChatGPT window"
  assert_contains "Electron user data: $user_data_dir"
  assert_contains "Log: $log_file"
  [[ -d "$user_data_dir" ]] || fail "named app profile did not create separate Electron user data"
  [[ "$(mode_of "$profile_home")" == "700" ]] || fail "named app profile home is not private"
  [[ "$(mode_of "$user_data_dir")" == "700" ]] || fail "named app user data is not private"
  [[ "$(mode_of "$log_file")" == "600" ]] || fail "named app desktop log is not private"
  grep -Fqx "MESSAGE=named ChatGPT launch" "$log_file" || fail "named profile did not launch ChatGPT.app"
  grep -Fqx "CODEX_HOME=$profile_home" "$log_file" || fail "named profile did not pass CODEX_HOME"
  grep -Fqx "CODEX_ELECTRON_USER_DATA_PATH=$user_data_dir" "$log_file" || fail "named profile did not mirror Electron state through the environment"
  grep -Fqx "ARGS=--user-data-dir=$user_data_dir" "$log_file" || fail "named profile did not select separate Electron state"
  grep -Fqx "open -a $chatgpt_app files=$tmp/work space args=--user-data-dir=$user_data_dir" "$tool_log" || fail "named profile used the wrong open invocation"
  ! grep -q '^forbidden tool ' "$tool_log" || fail "named app launch mutated or stopped another app"
  ! grep -q '^bundled codex called:' "$tool_log" || fail "Desktop launch delegated back through codex app"
  [[ ! -e "$tmp/instances" ]] || fail "named app launch created an app clone"

  rm -rf "$tmp"
}

test_app_default_reuses_the_stock_chatgpt_session() {
  local tmp chatgpt_app fake_bin tool_log profile_home log_file
  tmp="$(mktemp -d)"
  chatgpt_app="$tmp/ChatGPT.app"
  fake_bin="$tmp/bin"
  tool_log="$tmp/tool.log"
  profile_home="$tmp/home/.codex"
  log_file="$profile_home/logs/desktop.log"
  write_fake_chatgpt_app_bundle "$chatgpt_app" "default ChatGPT launch"
  write_fake_chatgpt_open_tools "$fake_bin"
  mkdir -p "$profile_home"

  run_cmd env HOME="$tmp/home" PATH="$fake_bin:$PATH" FAKE_TOOL_LOG="$tool_log" \
    CHATGPT_APP="$chatgpt_app" CODEX_ELECTRON_USER_DATA_PATH="$tmp/inherited-electron-user-data" \
    "$SCRIPT" app default "$tmp/workspace"

  assert_status 0
  assert_contains "Desktop scope: stock ChatGPT session"
  assert_not_contains "Electron user data:"
  grep -Fqx "MESSAGE=default ChatGPT launch" "$log_file" || fail "default profile did not launch ChatGPT.app"
  grep -Fqx "CODEX_HOME=$profile_home" "$log_file" || fail "default profile did not pass CODEX_HOME"
  grep -Fqx "CODEX_ELECTRON_USER_DATA_PATH=" "$log_file" || fail "default profile unexpectedly set Electron state through the environment"
  grep -Fqx "ARGS=" "$log_file" || fail "default profile unexpectedly changed ChatGPT browser state"
  grep -Fqx "open -a $chatgpt_app files=$tmp/workspace args=" "$tool_log" || fail "default profile passed a named user-data directory"
  [[ ! -e "$profile_home/electron-user-data" ]] || fail "default app profile created named Electron user data"

  rm -rf "$tmp"
}

test_app_legacy_instance_flags_use_the_same_signed_app_launcher() {
  local tmp chatgpt_app fake_bin tool_log profile_home user_data_dir
  tmp="$(mktemp -d)"
  chatgpt_app="$tmp/ChatGPT.app"
  fake_bin="$tmp/bin"
  tool_log="$tmp/tool.log"
  profile_home="$tmp/home/.codex-work"
  user_data_dir="$profile_home/electron-user-data"
  write_fake_chatgpt_app_bundle "$chatgpt_app" "compatibility launch"
  write_fake_chatgpt_open_tools "$fake_bin"
  mkdir -p "$profile_home"

  run_cmd env HOME="$tmp/home" PATH="$fake_bin:$PATH" FAKE_TOOL_LOG="$tool_log" \
    CHATGPT_APP="$chatgpt_app" CODEX_PROFILE_APP_INSTANCE_ROOT="$tmp/instances" \
    "$SCRIPT" app work --instance --rebuild "$tmp/workspace"

  assert_status 0
  assert_contains "Compatibility: --instance is no longer needed"
  assert_contains "Compatibility: --rebuild no longer rebuilds an app clone"
  grep -Fqx "open -a $chatgpt_app files=$tmp/workspace args=--user-data-dir=$user_data_dir" "$tool_log" || fail "legacy flags did not use signed ChatGPT.app"
  [[ ! -e "$tmp/instances" ]] || fail "legacy flags still created an app clone"
  ! grep -q '^forbidden tool ' "$tool_log" || fail "legacy flags mutated or stopped another app"

  : > "$tool_log"
  run_cmd env HOME="$tmp/home" PATH="$fake_bin:$PATH" FAKE_TOOL_LOG="$tool_log" \
    CHATGPT_APP="$chatgpt_app" CODEX_PROFILE_APP_INSTANCE_ROOT="$tmp/instances" \
    "$SCRIPT" app-instance work --rebuild "$tmp/workspace-2"

  assert_status 0
  assert_contains "Compatibility: app-instance is now an alias for app"
  grep -Fqx "open -a $chatgpt_app files=$tmp/workspace-2 args=--user-data-dir=$user_data_dir" "$tool_log" || fail "app-instance alias did not use signed ChatGPT.app"
  [[ ! -e "$tmp/instances" ]] || fail "app-instance alias still created an app clone"

  rm -rf "$tmp"
}

test_app_rebuild_is_accepted_as_a_compatibility_noop() {
  local tmp chatgpt_app fake_bin tool_log
  tmp="$(mktemp -d)"
  chatgpt_app="$tmp/ChatGPT.app"
  fake_bin="$tmp/bin"
  tool_log="$tmp/tool.log"
  write_fake_chatgpt_app_bundle "$chatgpt_app" "rebuild compatibility launch"
  write_fake_chatgpt_open_tools "$fake_bin"
  mkdir -p "$tmp/home/.codex-work"

  run_cmd env HOME="$tmp/home" PATH="$fake_bin:$PATH" FAKE_TOOL_LOG="$tool_log" \
    CHATGPT_APP="$chatgpt_app" "$SCRIPT" app work --rebuild "$tmp/workspace"

  assert_status 0
  assert_contains "Compatibility: --rebuild no longer rebuilds an app clone"

  rm -rf "$tmp"
}

test_cli_falls_back_to_the_bundled_cli_when_path_codex_is_broken() {
  local tmp chatgpt_app fake_bin broken_codex
  tmp="$(mktemp -d)"
  chatgpt_app="$tmp/ChatGPT.app"
  fake_bin="$tmp/bin"
  broken_codex="$fake_bin/codex"
  mkdir -p "$fake_bin" "$tmp/home/.codex-work"
  write_fake_chatgpt_app_bundle "$chatgpt_app" "unused"
  cat > "$broken_codex" <<'BROKEN_CODEX'
#!/usr/bin/env bash
printf 'broken PATH codex\n' >&2
exit 72
BROKEN_CODEX
  chmod 755 "$broken_codex"

  run_cmd env HOME="$tmp/home" PATH="$fake_bin:$PATH" CHATGPT_APP="$chatgpt_app" \
    "$SCRIPT" cli work exec "run tests"

  assert_status 0
  assert_contains "BUNDLED_CODEX_HOME=$tmp/home/.codex-work"
  assert_contains "BUNDLED_ARGS=exec run tests"
  assert_not_contains "broken PATH codex"

  rm -rf "$tmp"
}

test_healthy_path_cli_keeps_priority_over_the_bundled_cli() {
  local tmp chatgpt_app fake_bin path_codex
  tmp="$(mktemp -d)"
  chatgpt_app="$tmp/ChatGPT.app"
  fake_bin="$tmp/bin"
  path_codex="$fake_bin/codex"
  mkdir -p "$fake_bin" "$tmp/home/.codex-work"
  write_fake_chatgpt_app_bundle "$chatgpt_app" "unused"
  cat > "$path_codex" <<'PATH_CODEX'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  printf 'path-codex 1.0\n'
  exit 0
fi
printf 'PATH_CODEX_HOME=%s\n' "${CODEX_HOME:-}"
printf 'PATH_ARGS=%s\n' "$*"
PATH_CODEX
  chmod 755 "$path_codex"

  run_cmd env HOME="$tmp/home" PATH="$fake_bin:$PATH" CHATGPT_APP="$chatgpt_app" \
    "$SCRIPT" cli work exec "run tests"

  assert_status 0
  assert_contains "PATH_CODEX_HOME=$tmp/home/.codex-work"
  assert_contains "PATH_ARGS=exec run tests"
  assert_not_contains "BUNDLED_CODEX_HOME"

  rm -rf "$tmp"
}

test_legacy_codex_app_bin_locates_its_signed_app_bundle() {
  local tmp chatgpt_app fake_bin tool_log executable
  tmp="$(mktemp -d)"
  chatgpt_app="$tmp/Legacy Location/ChatGPT.app"
  fake_bin="$tmp/bin"
  tool_log="$tmp/tool.log"
  executable="$chatgpt_app/Contents/MacOS/ChatGPT"
  write_fake_chatgpt_app_bundle "$chatgpt_app" "legacy executable override"
  write_fake_chatgpt_open_tools "$fake_bin"
  mkdir -p "$tmp/home/.codex"

  run_cmd env HOME="$tmp/home" PATH="$fake_bin:$PATH" FAKE_TOOL_LOG="$tool_log" \
    CODEX_APP_BIN="$executable" "$SCRIPT" app default "$tmp/workspace"

  assert_status 0
  assert_contains "App bundle: $chatgpt_app"
  grep -Fqx "open -a $chatgpt_app files=$tmp/workspace args=" "$tool_log" || fail "CODEX_APP_BIN did not resolve its containing app bundle"

  rm -rf "$tmp"
}

test_legacy_codex_app_bin_rejects_a_different_executable_in_the_bundle() {
  local tmp chatgpt_app fake_bin tool_log wrong_executable
  tmp="$(mktemp -d)"
  chatgpt_app="$tmp/ChatGPT.app"
  fake_bin="$tmp/bin"
  tool_log="$tmp/tool.log"
  wrong_executable="$chatgpt_app/Contents/MacOS/wrong-name"
  write_fake_chatgpt_app_bundle "$chatgpt_app" "must not launch"
  write_fake_chatgpt_open_tools "$fake_bin"
  mkdir -p "$tmp/home/.codex"
  printf '#!/bin/sh\nexit 0\n' > "$wrong_executable"
  chmod 755 "$wrong_executable"

  run_cmd env HOME="$tmp/home" PATH="$fake_bin:$PATH" FAKE_TOOL_LOG="$tool_log" \
    CODEX_APP_BIN="$wrong_executable" "$SCRIPT" app default "$tmp/workspace"

  assert_status 1
  assert_contains "CODEX_APP_BIN must be an executable inside a usable .app bundle"
  [[ ! -e "$tool_log" ]] || ! grep -q '^open ' "$tool_log" \
    || fail "mismatched CODEX_APP_BIN launched the bundle's declared executable"

  rm -rf "$tmp"
}

test_invalid_chatgpt_app_override_does_not_fall_back_silently() {
  local tmp fallback_app fake_bin tool_log
  tmp="$(mktemp -d)"
  fallback_app="$tmp/Codex.app"
  fake_bin="$tmp/bin"
  tool_log="$tmp/tool.log"
  write_fake_chatgpt_app_bundle "$fallback_app" "must not launch"
  write_fake_chatgpt_open_tools "$fake_bin"
  mkdir -p "$tmp/home/.codex"

  run_cmd env HOME="$tmp/home" PATH="$fake_bin:$PATH" FAKE_TOOL_LOG="$tool_log" \
    CHATGPT_APP="$tmp/missing/ChatGPT.app" CODEX_APP="$fallback_app" \
    "$SCRIPT" app default

  assert_status 1
  assert_contains "CHATGPT_APP is not a usable desktop app bundle"
  [[ ! -e "$tool_log" ]] || ! grep -q '^open ' "$tool_log" || fail "invalid CHATGPT_APP silently fell back to CODEX_APP"

  rm -rf "$tmp"
}

test_explicit_codex_cli_must_be_healthy() {
  local tmp broken_codex
  tmp="$(mktemp -d)"
  broken_codex="$tmp/codex"
cat > "$broken_codex" <<'BROKEN_CODEX'
#!/usr/bin/env bash
exit 72
BROKEN_CODEX
  chmod 755 "$broken_codex"
  mkdir -p "$tmp/home/.codex-work"

  run_cmd env HOME="$tmp/home" CODEX_CLI="$broken_codex" "$SCRIPT" cli work

  assert_status 1
  assert_contains "CODEX_CLI is set but unhealthy"

  rm -rf "$tmp"
}

test_app_refuses_access_token_override() {
  local tmp chatgpt_app fake_bin tool_log
  tmp="$(mktemp -d)"
  chatgpt_app="$tmp/ChatGPT.app"
  fake_bin="$tmp/bin"
  tool_log="$tmp/tool.log"
  write_fake_chatgpt_app_bundle "$chatgpt_app" "should not launch"
  write_fake_chatgpt_open_tools "$fake_bin"
  mkdir -p "$tmp/home/.codex-work"

  run_cmd env HOME="$tmp/home" PATH="$fake_bin:$PATH" FAKE_TOOL_LOG="$tool_log" \
    CHATGPT_APP="$chatgpt_app" CODEX_ACCESS_TOKEN=secret "$SCRIPT" app work

  assert_status 1
  assert_contains "Refusing Desktop launch while CODEX_ACCESS_TOKEN is set"
  [[ ! -e "$tool_log" ]] || ! grep -q '^open ' "$tool_log" || fail "Desktop launched with an auth environment override"

  rm -rf "$tmp"
}

test_named_app_user_data_symlinks_are_refused() {
  local tmp chatgpt_app fake_bin tool_log outside profile_home
  tmp="$(mktemp -d)"
  chatgpt_app="$tmp/ChatGPT.app"
  fake_bin="$tmp/bin"
  tool_log="$tmp/tool.log"
  outside="$tmp/outside"
  profile_home="$tmp/home/.codex-work"
  write_fake_chatgpt_app_bundle "$chatgpt_app" "should not launch"
  write_fake_chatgpt_open_tools "$fake_bin"
  mkdir -p "$profile_home" "$outside"
  ln -s "$outside" "$profile_home/electron-user-data"

  run_cmd env HOME="$tmp/home" PATH="$fake_bin:$PATH" FAKE_TOOL_LOG="$tool_log" \
    CHATGPT_APP="$chatgpt_app" "$SCRIPT" app work

  assert_status 1
  assert_contains "Refusing symlinked managed directory: $profile_home/electron-user-data"
  [[ ! -e "$tool_log" ]] || ! grep -q '^open ' "$tool_log" || fail "Desktop launched through a symlinked user-data directory"

  rm -rf "$tmp"
}

test_app_refuses_linked_desktop_logs_without_touching_the_target() {
  local tmp chatgpt_app fake_bin tool_log profile_home log_file victim
  tmp="$(mktemp -d)"
  chatgpt_app="$tmp/ChatGPT.app"
  fake_bin="$tmp/bin"
  tool_log="$tmp/tool.log"
  profile_home="$tmp/home/.codex-work"
  log_file="$profile_home/logs/desktop.log"
  victim="$tmp/must-survive"
  write_fake_chatgpt_app_bundle "$chatgpt_app" "should not launch"
  write_fake_chatgpt_open_tools "$fake_bin"
  mkdir -p "${log_file%/*}"
  printf 'must survive\n' > "$victim"
  ln -s "$victim" "$log_file"

  run_cmd env HOME="$tmp/home" PATH="$fake_bin:$PATH" FAKE_TOOL_LOG="$tool_log" \
    CHATGPT_APP="$chatgpt_app" "$SCRIPT" app work

  assert_status 1
  assert_contains "Refusing symlinked desktop log: $log_file"
  [[ "$(cat "$victim")" == "must survive" ]] || fail "symlinked desktop log target was modified"
  [[ ! -e "$tool_log" ]] || ! grep -q '^open ' "$tool_log" || fail "Desktop launched with a symlinked log"

  rm -f "$log_file"
  ln "$victim" "$log_file"
  run_cmd env HOME="$tmp/home" PATH="$fake_bin:$PATH" FAKE_TOOL_LOG="$tool_log" \
    CHATGPT_APP="$chatgpt_app" "$SCRIPT" app work

  assert_status 1
  assert_contains "Refusing multiply-linked desktop log: $log_file"
  [[ "$(cat "$victim")" == "must survive" ]] || fail "multiply-linked desktop log target was modified"
  [[ ! -e "$tool_log" ]] || ! grep -q '^open ' "$tool_log" || fail "Desktop launched with a multiply-linked log"

  rm -rf "$tmp"
}

test_app_propagates_open_failures() {
  local tmp chatgpt_app fake_bin tool_log
  tmp="$(mktemp -d)"
  chatgpt_app="$tmp/ChatGPT.app"
  fake_bin="$tmp/bin"
  tool_log="$tmp/tool.log"
  write_fake_chatgpt_app_bundle "$chatgpt_app" "should not launch"
  write_fake_chatgpt_open_tools "$fake_bin"
  mkdir -p "$tmp/home/.codex-work"

  run_cmd env HOME="$tmp/home" PATH="$fake_bin:$PATH" FAKE_TOOL_LOG="$tool_log" \
    FAKE_OPEN_EXIT=70 CHATGPT_APP="$chatgpt_app" "$SCRIPT" app work

  assert_status 1
  assert_contains "Cannot launch ChatGPT app"

  rm -rf "$tmp"
}

test_doctor_reports_desktop_and_cli_when_present() {
  local tmp fake_codex chatgpt_app fake_bin tool_log executable
  tmp="$(mktemp -d)"
  fake_codex="$tmp/codex"
  chatgpt_app="$tmp/ChatGPT.app"
  fake_bin="$tmp/bin"
  tool_log="$tmp/tool.log"
  executable="$chatgpt_app/Contents/MacOS/ChatGPT"
  cat > "$fake_codex" <<'FAKE_CODEX'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  printf 'version warning from wrapper\n' >&2
  printf 'fake-codex 1.0\n'
  exit 0
fi
printf 'login status\n'
FAKE_CODEX
  chmod 755 "$fake_codex"
  write_fake_chatgpt_app_bundle "$chatgpt_app" "doctor"
  write_fake_chatgpt_open_tools "$fake_bin"
  mkdir -p "$tmp/home/.codex-personal"

  run_cmd env HOME="$tmp/home" PATH="$fake_bin:$PATH" FAKE_TOOL_LOG="$tool_log" \
    CODEX_CLI="$fake_codex" CHATGPT_APP="$chatgpt_app" "$SCRIPT" doctor

  assert_status 0
  assert_contains "Desktop product: ChatGPT"
  assert_contains "Desktop app: $chatgpt_app"
  assert_contains "Desktop executable: $executable"
  assert_contains "Desktop bundle ID: com.openai.codex"
  assert_contains "Desktop scope: default uses the stock ChatGPT session; named ChatGPT windows use separate local state"
  assert_not_contains "isolated ChatGPT window"
  assert_contains "Boundary: local-state separation is not an account, OS, or server-side boundary"
  assert_contains "CLI: $fake_codex (source: CODEX_CLI)"
  assert_contains "CLI scope: Codex commands only; Desktop and CLI accounts must be verified separately"
  assert_contains "fake-codex 1.0"
  assert_contains "login status"

  run_cmd env HOME="$tmp/home" PATH="$fake_bin:$PATH" FAKE_TOOL_LOG="$tool_log" \
    CODEX_CLI="$fake_codex" CHATGPT_APP="$chatgpt_app" "$SCRIPT" doctor --json

  assert_status 0
  assert_contains '"desktop":{"found":true'
  assert_contains '"path":"'"$executable"'"'
  assert_contains '"app_path":"'"$chatgpt_app"'"'
  assert_contains '"product":"ChatGPT"'
  assert_contains '"bundle_id":"com.openai.codex"'
  assert_contains '"scope":"default:stock_chatgpt_session;named:separate_local_state"'
  assert_contains '"account_identity":"unverified"'
  assert_contains '"cli":{"found":true'
  assert_contains '"source":"CODEX_CLI"'
  assert_contains '"healthy":true'
  assert_contains '"scope":"codex_only"'
  assert_contains '"account_identity":"unverified_against_desktop"'
  assert_contains '"version":"fake-codex 1.0"'
  assert_not_contains "version warning from wrapper"

  rm -rf "$tmp"
}

test_app_requires_an_initialized_profile
test_app_named_profile_uses_separate_local_state_for_the_whole_chatgpt_window
test_app_default_reuses_the_stock_chatgpt_session
test_app_legacy_instance_flags_use_the_same_signed_app_launcher
test_app_rebuild_is_accepted_as_a_compatibility_noop
test_cli_falls_back_to_the_bundled_cli_when_path_codex_is_broken
test_healthy_path_cli_keeps_priority_over_the_bundled_cli
test_legacy_codex_app_bin_locates_its_signed_app_bundle
test_legacy_codex_app_bin_rejects_a_different_executable_in_the_bundle
test_invalid_chatgpt_app_override_does_not_fall_back_silently
test_explicit_codex_cli_must_be_healthy
test_app_refuses_access_token_override
test_named_app_user_data_symlinks_are_refused
test_app_refuses_linked_desktop_logs_without_touching_the_target
test_app_propagates_open_failures
test_doctor_reports_desktop_and_cli_when_present
