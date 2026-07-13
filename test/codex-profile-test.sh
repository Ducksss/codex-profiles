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
  local declared expected
  declared="$(sed -n 's/^VERSION="\([^"]*\)".*/\1/p' "$SCRIPT" | sed -n '1p')"
  [[ -n "$declared" ]] || fail "could not read VERSION from $SCRIPT"
  expected="codex-profile $declared"

  run_cmd "$SCRIPT" version

  assert_status 0
  assert_equals "$expected"

  run_cmd "$SCRIPT" --version

  assert_status 0
  assert_equals "$expected"
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

  run_cmd env HOME="$tmp/home" CODEX_CLI="$fake_codex" "$SCRIPT" login work --device-auth

  assert_status 0
  assert_contains "CODEX_HOME=$tmp/home/.codex-work"
  assert_contains "ARGS=login --device-auth"
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

write_fake_chatgpt_app_bundle() {
  local app="$1"
  local message="$2"

  mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
  cat > "$app/Contents/Info.plist" <<'FAKE_PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>ChatGPT</string>
  <key>CFBundleExecutable</key>
  <string>ChatGPT</string>
  <key>CFBundleIdentifier</key>
  <string>com.openai.codex</string>
  <key>CFBundleName</key>
  <string>ChatGPT</string>
</dict>
</plist>
FAKE_PLIST

  cat > "$app/Contents/MacOS/ChatGPT" <<FAKE_CHATGPT_APP
#!/usr/bin/env bash
if [[ "\${OPEN_LAUNCHED:-}" != "yes" ]]; then
  printf 'not launched through open\n' >&2
  exit 64
fi
printf 'MESSAGE=%s\n' "$message"
printf 'CODEX_HOME=%s\n' "\$CODEX_HOME"
printf 'ARGS=%s\n' "\$*"
FAKE_CHATGPT_APP
  chmod 755 "$app/Contents/MacOS/ChatGPT"

  cat > "$app/Contents/Resources/codex" <<'FAKE_BUNDLED_CODEX'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  printf 'bundled-codex 1.0\n'
  exit 0
fi
if [[ -n "${FAKE_TOOL_LOG:-}" ]]; then
  printf 'bundled codex called: %s\n' "$*" >> "$FAKE_TOOL_LOG"
fi
printf 'BUNDLED_CODEX_HOME=%s\n' "${CODEX_HOME:-}"
printf 'BUNDLED_ARGS=%s\n' "$*"
FAKE_BUNDLED_CODEX
  chmod 755 "$app/Contents/Resources/codex"
}

write_fake_chatgpt_open_tools() {
  local fake_bin="$1"
  local tool

  mkdir -p "$fake_bin"

  cat > "$fake_bin/plutil" <<'FAKE_PLUTIL'
#!/usr/bin/env bash
if [[ "${1:-}" != "-extract" ]]; then
  printf 'unexpected plutil mutation: %s\n' "$*" >&2
  exit 99
fi
key="${2:-}"
plist="${!#}"
awk -v target="$key" '
  /<key>.*<\/key>/ {
    current = $0
    sub(/^.*<key>/, "", current)
    sub(/<\/key>.*$/, "", current)
    waiting = current == target
    next
  }
  waiting && /<string>/ {
    value = $0
    gsub(/^[[:space:]]*<string>/, "", value)
    gsub(/<\/string>[[:space:]]*$/, "", value)
    print value
    found = 1
    exit
  }
  END { if (!found) exit 1 }
' "$plist"
FAKE_PLUTIL
  chmod 755 "$fake_bin/plutil"

  for tool in codesign osascript pgrep pkill cp; do
    cat > "$fake_bin/$tool" <<'FAKE_FORBIDDEN_TOOL'
#!/usr/bin/env bash
printf 'forbidden tool %s was called: %s\n' "${0##*/}" "$*" >> "${FAKE_TOOL_LOG:?}"
exit 99
FAKE_FORBIDDEN_TOOL
    chmod 755 "$fake_bin/$tool"
  done

  cat > "$fake_bin/open" <<'FAKE_OPEN'
#!/usr/bin/env bash
if [[ -n "${FAKE_OPEN_EXIT:-}" ]]; then
  printf 'open failed intentionally\n' >&2
  exit "$FAKE_OPEN_EXIT"
fi
stdout="/dev/null"
stderr="/dev/null"
app=""
env_args=()
file_args=()
app_args=()

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -n|--new)
      shift
      ;;
    --env)
      env_args+=("$2")
      shift 2
      ;;
    --stdout)
      stdout="$2"
      shift 2
      ;;
    --stderr)
      stderr="$2"
      shift 2
      ;;
    -a)
      app="$2"
      shift 2
      ;;
    --args)
      shift
      app_args=("$@")
      break
      ;;
    *)
      file_args+=("$1")
      shift
      ;;
  esac
done

printf 'open -a %s files=%s args=%s\n' "$app" "${file_args[*]}" "${app_args[*]}" >> "${FAKE_TOOL_LOG:?}"
executable="$(plutil -extract CFBundleExecutable raw -o - "$app/Contents/Info.plist")"

if [[ "$stdout" == "$stderr" ]]; then
  env OPEN_LAUNCHED=yes "${env_args[@]}" bash "$app/Contents/MacOS/$executable" "${app_args[@]}" > "$stdout" 2>&1
else
  env OPEN_LAUNCHED=yes "${env_args[@]}" bash "$app/Contents/MacOS/$executable" "${app_args[@]}" > "$stdout" 2> "$stderr"
fi
FAKE_OPEN
  chmod 755 "$fake_bin/open"
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

  run_cmd env HOME="$tmp/home" PATH="$fake_bin:$PATH" FAKE_TOOL_LOG="$tool_log" \
    CHATGPT_APP="$chatgpt_app" "$SCRIPT" app default "$tmp/workspace"

  assert_status 0
  assert_contains "Desktop scope: stock ChatGPT session"
  assert_not_contains "Electron user data:"
  grep -Fqx "MESSAGE=default ChatGPT launch" "$log_file" || fail "default profile did not launch ChatGPT.app"
  grep -Fqx "CODEX_HOME=$profile_home" "$log_file" || fail "default profile did not pass CODEX_HOME"
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
  mkdir -p "$fake_bin"
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
  mkdir -p "$fake_bin"
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

  run_cmd env HOME="$tmp/home" PATH="$fake_bin:$PATH" FAKE_TOOL_LOG="$tool_log" \
    CHATGPT_APP="$chatgpt_app" CODEX_ACCESS_TOKEN=secret "$SCRIPT" app work

  assert_status 1
  assert_contains "Refusing Desktop launch while CODEX_ACCESS_TOKEN is set"
  [[ ! -e "$tool_log" ]] || ! grep -q '^open ' "$tool_log" || fail "Desktop launched with an auth environment override"

  rm -rf "$tmp"
}

test_profile_home_symlinks_are_refused() {
  local tmp target
  tmp="$(mktemp -d)"
  target="$tmp/elsewhere"
  mkdir -p "$tmp/home" "$target"
  ln -s "$target" "$tmp/home/.codex-work"

  run_cmd env HOME="$tmp/home" "$SCRIPT" init work

  assert_status 1
  assert_contains "Refusing symlinked managed directory: $tmp/home/.codex-work"

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

test_app_propagates_open_failures() {
  local tmp chatgpt_app fake_bin tool_log
  tmp="$(mktemp -d)"
  chatgpt_app="$tmp/ChatGPT.app"
  fake_bin="$tmp/bin"
  tool_log="$tmp/tool.log"
  write_fake_chatgpt_app_bundle "$chatgpt_app" "should not launch"
  write_fake_chatgpt_open_tools "$fake_bin"

  run_cmd env HOME="$tmp/home" PATH="$fake_bin:$PATH" FAKE_TOOL_LOG="$tool_log" \
    FAKE_OPEN_EXIT=70 CHATGPT_APP="$chatgpt_app" "$SCRIPT" app work

  assert_status 1
  assert_contains "Cannot launch ChatGPT app"

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

test_init_share_with_links_only_existing_allowlisted_config() {
  local tmp source_home target_home source_override minimal_source minimal_target
  tmp="$(mktemp -d)"
  source_home="$tmp/home/.codex-personal"
  target_home="$tmp/home/.codex-personal-2"
  source_override="$source_home/shared-override.md"
  mkdir -p "$source_home/rules" "$source_home/plugins" \
    "$source_home/sessions" "$source_home/logs" \
    "$source_home/electron-user-data" "$source_home/cache" \
    "$source_home/caches" "$source_home/connectors" \
    "$source_home/connector-data" "$source_home/apps" \
    "$source_home/skills"
  printf 'model = "gpt-5"\n' > "$source_home/config.toml"
  printf '# Shared agents\n' > "$source_home/AGENTS.md"
  printf '# Shared override\n' > "$source_override"
  ln -s "$source_override" "$source_home/AGENTS.override.md"
  printf '# Legacy instructions\n' > "$source_home/instructions.md"
  printf '# Legacy shared instructions\n' > "$source_home/custom-instructions.md"
  printf 'allow_rule = true\n' > "$source_home/rules/default.rules"
  printf 'plugin\n' > "$source_home/plugins/example.txt"
  printf '{"token":"source-secret"}\n' > "$source_home/auth.json"
  printf 'private session\n' > "$source_home/sessions/session.json"
  printf 'private log\n' > "$source_home/logs/codex.log"
  printf 'private desktop state\n' > "$source_home/electron-user-data/state"
  printf 'private cache\n' > "$source_home/cache/state"
  printf 'private caches\n' > "$source_home/caches/state"
  printf 'private connector\n' > "$source_home/connectors/state"
  printf 'private connector data\n' > "$source_home/connector-data/state"
  printf 'private app data\n' > "$source_home/apps/state"
  printf 'not allowlisted\n' > "$source_home/skills/example.txt"

  run_cmd env HOME="$tmp/home" CODEX_CLI=/no/such/codex \
    "$SCRIPT" init personal-2 --share-with personal

  assert_status 0
  assert_contains "Initialized personal-2 ($target_home)"
  assert_contains "Sharing configuration with personal ($source_home)"
  [[ -d "$target_home" && ! -L "$target_home" ]] ||
    fail "shared init target must be a real directory"
  [[ "$(mode_of "$target_home")" == "700" ]] ||
    fail "shared init target is not private"

  local entry
  for entry in config.toml AGENTS.md AGENTS.override.md instructions.md custom-instructions.md rules plugins; do
    [[ -L "$target_home/$entry" ]] || fail "shared init did not link $entry"
    [[ "$(readlink "$target_home/$entry")" == "$source_home/$entry" ]] ||
      fail "shared init linked $entry to the wrong source"
  done

  for entry in auth.json sessions logs electron-user-data cache caches connectors connector-data apps skills; do
    [[ ! -e "$target_home/$entry" && ! -L "$target_home/$entry" ]] ||
      fail "shared init linked private or non-allowlisted state: $entry"
  done

  printf '{"token":"target-secret"}\n' > "$target_home/auth.json"
  [[ "$(cat "$source_home/auth.json")" == '{"token":"source-secret"}' ]] ||
    fail "target auth write changed source auth"

  minimal_source="$tmp/home/.codex-minimal"
  minimal_target="$tmp/home/.codex-minimal-2"
  mkdir -p "$minimal_source"
  printf 'model = "gpt-5"\n' > "$minimal_source/config.toml"

  run_cmd env HOME="$tmp/home" "$SCRIPT" init minimal-2 --share-with minimal

  assert_status 0
  [[ -L "$minimal_target/config.toml" ]] ||
    fail "minimal shared init did not link existing config.toml"
  for entry in AGENTS.md AGENTS.override.md instructions.md custom-instructions.md rules plugins; do
    [[ ! -e "$minimal_target/$entry" && ! -L "$minimal_target/$entry" ]] ||
      fail "minimal shared init created a dangling link: $entry"
  done

  rm -rf "$tmp"
}

test_init_share_with_rejects_invalid_sources_and_usage() {
  local tmp source_home outside
  tmp="$(mktemp -d)"
  source_home="$tmp/home/.codex-personal"
  outside="$tmp/outside-source"
  mkdir -p "$source_home" "$outside"

  run_cmd env HOME="$tmp/home" "$SCRIPT" init personal --share-with personal

  assert_status 1
  assert_contains "Source and target profiles must be different"

  run_cmd env HOME="$tmp/home" "$SCRIPT" init personal-2 --share-with missing

  assert_status 1
  assert_contains "Shared profile source is not initialized"
  [[ ! -e "$tmp/home/.codex-personal-2" ]] ||
    fail "missing source created target profile"

  rm -rf "$source_home"
  ln -s "$outside" "$source_home"
  run_cmd env HOME="$tmp/home" "$SCRIPT" init personal-2 --share-with personal

  assert_status 1
  assert_contains "Refusing symlinked shared profile source"
  [[ ! -e "$tmp/home/.codex-personal-2" ]] ||
    fail "symlinked source created target profile"

  run_cmd env HOME="$tmp/home" "$SCRIPT" init personal-2 --share-with

  assert_status 1
  assert_contains "Usage:"

  run_cmd env HOME="$tmp/home" "$SCRIPT" init personal-2 --unknown

  assert_status 1
  assert_contains "Usage:"

  rm -rf "$tmp"
}

test_init_share_with_refuses_every_existing_target_path() {
  local tmp source_home target_home
  tmp="$(mktemp -d)"
  source_home="$tmp/home/.codex-personal"
  target_home="$tmp/home/.codex-personal-2"
  mkdir -p "$source_home" "$target_home"
  printf 'model = "gpt-5"\n' > "$source_home/config.toml"

  run_cmd env HOME="$tmp/home" "$SCRIPT" init personal-2 --share-with personal

  assert_status 1
  assert_contains "Target profile path already exists"
  [[ -d "$target_home" ]] || fail "shared init removed existing target directory"

  rmdir "$target_home"
  printf 'existing file\n' > "$target_home"
  run_cmd env HOME="$tmp/home" "$SCRIPT" init personal-2 --share-with personal

  assert_status 1
  assert_contains "Target profile path already exists"
  [[ "$(cat "$target_home")" == "existing file" ]] ||
    fail "shared init changed existing target file"

  rm -f "$target_home"
  ln -s "$tmp/missing-target" "$target_home"
  run_cmd env HOME="$tmp/home" "$SCRIPT" init personal-2 --share-with personal

  assert_status 1
  assert_contains "Target profile path already exists"
  [[ -L "$target_home" ]] || fail "shared init removed existing dangling target symlink"

  rm -rf "$tmp"
}

test_init_share_with_cleans_up_after_link_failure() {
  local tmp source_home target_home real_ln
  tmp="$(mktemp -d)"
  source_home="$tmp/home/.codex-personal"
  target_home="$tmp/home/.codex-personal-2"
  real_ln="$(command -v ln)"
  mkdir -p "$source_home" "$tmp/bin"
  printf 'model = "gpt-5"\n' > "$source_home/config.toml"
  printf '# Shared agents\n' > "$source_home/AGENTS.md"
  cat > "$tmp/bin/ln" <<'FAKE_LN'
#!/usr/bin/env bash
count=0
if [[ -f "$FAKE_LN_COUNT" ]]; then
  read -r count < "$FAKE_LN_COUNT"
fi
count=$((count + 1))
printf '%s\n' "$count" > "$FAKE_LN_COUNT"
if [[ "$count" -eq 2 ]]; then
  exit 73
fi
exec "$REAL_LN" "$@"
FAKE_LN
  chmod 755 "$tmp/bin/ln"

  run_cmd env HOME="$tmp/home" PATH="$tmp/bin:$PATH" \
    REAL_LN="$real_ln" FAKE_LN_COUNT="$tmp/ln-count" \
    "$SCRIPT" init personal-2 --share-with personal

  assert_status 1
  assert_contains "Cannot link shared entry AGENTS.md"
  [[ ! -e "$target_home" && ! -L "$target_home" ]] ||
    fail "shared init left a partially populated target after link failure"
  [[ -f "$source_home/config.toml" && -f "$source_home/AGENTS.md" ]] ||
    fail "shared init cleanup changed the source profile"

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

test_workspace_bind_list_status_and_nested_resolution() {
  local tmp config dev client service sibling link
  tmp="$(mktemp -d)"
  tmp="$(cd "$tmp" && pwd -P)"
  config="$tmp/config"
  dev="$tmp/Dev"
  client="$dev/client one"
  service="$client/service"
  sibling="$dev/client one-more"
  link="$tmp/client-link"
  mkdir -p "$tmp/home/.codex-work" "$tmp/home/.codex-client" \
    "$dev" "$service" "$sibling"
  ln -s "$client" "$link"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace bind "$dev" work

  assert_status 0
  assert_contains "Bound $dev to profile work"
  [[ "$(mode_of "$config")" == "700" ]] || fail "workspace config directory is not private"
  [[ "$(mode_of "$config/workspaces.tsv")" == "600" ]] || fail "workspace registry is not private"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace bind "$dev" work

  assert_status 0
  assert_contains "Already bound $dev to profile work"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace bind "$client" client

  assert_status 0
  assert_contains "Bound $client to profile client"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace status --json "$service"

  assert_status 0
  assert_contains '"path":"'"$service"'"'
  assert_contains '"binding_path":"'"$client"'"'
  assert_contains '"profile":"client"'
  assert_contains '"guard_mode":"warn"'
  JSON_PAYLOAD="$output" node -e 'JSON.parse(process.env.JSON_PAYLOAD)'

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace status --json "$link/service"

  assert_status 0
  assert_contains '"path":"'"$service"'"'
  assert_contains '"binding_path":"'"$client"'"'
  assert_contains '"profile":"client"'

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace status --json "$sibling"

  assert_status 0
  assert_contains '"binding_path":"'"$dev"'"'
  assert_contains '"profile":"work"'
  assert_not_contains '"profile":"client"'

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace list --json

  assert_status 0
  assert_contains '"guard_mode":"warn"'
  assert_contains '"path":"'"$client"'"'
  assert_contains '"profile":"client"'
  assert_contains '"path_exists":true'
  assert_contains '"profile_exists":true'
  JSON_PAYLOAD="$output" node -e 'JSON.parse(process.env.JSON_PAYLOAD)'

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace unbind "$client"

  assert_status 0
  assert_contains "Unbound $client"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace status --json "$service"

  assert_status 0
  assert_contains '"binding_path":"'"$dev"'"'
  assert_contains '"profile":"work"'

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace status --json "$tmp"

  assert_status 0
  assert_contains '"binding_path":null'
  assert_contains '"profile":null'

  rm -rf "$tmp"
}

test_workspace_bind_rejects_unsafe_state_and_reports_stale_bindings() {
  local tmp config workspace quoted outside
  tmp="$(mktemp -d)"
  tmp="$(cd "$tmp" && pwd -P)"
  config="$tmp/config"
  workspace="$tmp/workspace"
  quoted="$tmp/quoted \"workspace\""
  outside="$tmp/outside-registry"
  mkdir -p "$tmp/home/.codex-work" "$tmp/home/.codex-client" \
    "$workspace" "$quoted"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace bind "$workspace" work
  assert_status 0

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace bind "$workspace" client
  assert_status 1
  assert_contains "already bound to profile work"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace bind "$workspace" client --force
  assert_status 0
  assert_contains "Rebound $workspace from profile work to client"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace bind "$quoted" work
  assert_status 0

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace list --json
  assert_status 0
  JSON_PAYLOAD="$output" node -e 'JSON.parse(process.env.JSON_PAYLOAD)'
  assert_contains '\"workspace\"'

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace bind "$tmp/missing" work
  assert_status 1
  assert_contains "Workspace directory does not exist"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace bind "$workspace" ghost --force
  assert_status 1
  assert_contains "Profile 'ghost' is not initialized"

  mkdir -p "$tmp/tab"$'\t'"workspace" "$tmp/newline"$'\n'"workspace"
  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace bind "$tmp/tab"$'\t'"workspace" work
  assert_status 1
  assert_contains "control characters"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace bind "$tmp/newline"$'\n'"workspace" work
  assert_status 1
  assert_contains "control characters"

  printf '%s\t%s\n' "$tmp/stale-path" work >> "$config/workspaces.tsv"
  printf '%s\t%s\n' "$workspace" ghost >> "$config/workspaces.tsv"
  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace list --json
  assert_status 0
  assert_contains '"path_exists":false'
  assert_contains '"profile_exists":false'

  printf 'malformed row\n' > "$config/workspaces.tsv"
  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace list
  assert_status 1
  assert_contains "Malformed workspace registry line 1"

  printf 'outside\n' > "$outside"
  rm -f "$config/workspaces.tsv"
  ln -s "$outside" "$config/workspaces.tsv"
  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace list
  assert_status 1
  assert_contains "Refusing symlinked workspace registry"
  [[ "$(cat "$outside")" == "outside" ]] || fail "workspace registry followed a symlink"

  rm -rf "$tmp"
}

test_workspace_uses_xdg_config_and_manages_guard_mode() {
  local tmp config workspace
  tmp="$(mktemp -d)"
  tmp="$(cd "$tmp" && pwd -P)"
  config="$tmp/xdg/codex-profile"
  workspace="$tmp/workspace"
  mkdir -p "$tmp/home/.codex-work" "$workspace"

  run_cmd env HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/xdg" \
    "$SCRIPT" workspace bind "$workspace" work
  assert_status 0
  [[ -f "$config/workspaces.tsv" ]] || fail "workspace binding ignored XDG_CONFIG_HOME"

  run_cmd env HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/xdg" \
    "$SCRIPT" workspace guard
  assert_status 0
  assert_equals "warn"

  run_cmd env HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/xdg" \
    "$SCRIPT" workspace guard strict
  assert_status 0
  assert_contains "Workspace guard mode: strict"
  [[ "$(mode_of "$config/guard-mode")" == "600" ]] || fail "workspace guard state is not private"

  run_cmd env HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/xdg" \
    "$SCRIPT" workspace guard
  assert_status 0
  assert_equals "strict"

  run_cmd env HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/xdg" \
    "$SCRIPT" workspace guard off
  assert_status 0
  assert_contains "Workspace guard mode: off"

  run_cmd env HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/xdg" \
    "$SCRIPT" workspace guard invalid
  assert_status 1
  assert_contains "Use off, warn, or strict"

  run_cmd env HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/xdg" \
    "$SCRIPT" workspace unbind "$tmp/missing"
  assert_status 1
  assert_contains "No exact workspace binding"

  if find "$config" -maxdepth 1 -name '*.tmp.*' | grep -q .; then
    fail "workspace mutation left temporary files behind"
  fi

  rm -rf "$tmp"
}

test_workspace_run_routes_cli_and_signed_app() {
  local tmp config workspace service fake_codex chatgpt_app fake_bin tool_log
  tmp="$(mktemp -d)"
  tmp="$(cd "$tmp" && pwd -P)"
  config="$tmp/config"
  workspace="$tmp/client"
  service="$workspace/service"
  fake_codex="$tmp/codex"
  chatgpt_app="$tmp/ChatGPT.app"
  fake_bin="$tmp/bin"
  tool_log="$tmp/tool.log"
  mkdir -p "$tmp/home/.codex-client" "$service"
  cat > "$fake_codex" <<'FAKE_CODEX'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  printf 'fake-codex 1.0\n'
  exit 0
fi
printf 'CODEX_HOME=%s\n' "$CODEX_HOME"
printf 'ARGS=%s\n' "$*"
FAKE_CODEX
  chmod 755 "$fake_codex"
  write_fake_chatgpt_app_bundle "$chatgpt_app" "bound ChatGPT launch"
  write_fake_chatgpt_open_tools "$fake_bin"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace bind "$workspace" client
  assert_status 0

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    CODEX_CLI="$fake_codex" bash -c \
    'cd "$1" && exec "$2" run -- exec "run tests"' _ "$service" "$SCRIPT"

  assert_status 0
  assert_contains "CODEX_HOME=$tmp/home/.codex-client"
  assert_contains "ARGS=exec run tests"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    CODEX_CLI="$fake_codex" bash -c \
    'cd "$1" && exec "$2" run -- --app' _ "$service" "$SCRIPT"

  assert_status 0
  assert_contains "ARGS=--app"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    PATH="$fake_bin:$PATH" FAKE_TOOL_LOG="$tool_log" CHATGPT_APP="$chatgpt_app" \
    "$SCRIPT" run --app "$service"

  assert_status 0
  assert_contains "Launching ChatGPT for profile client"
  grep -Fqx "open -a $chatgpt_app files=$service args=--user-data-dir=$tmp/home/.codex-client/electron-user-data" "$tool_log" || \
    fail "run --app did not launch the signed app with the bound profile"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    CODEX_CLI="$fake_codex" bash -c \
    'cd "$1" && exec "$2" run' _ "$tmp" "$SCRIPT"

  assert_status 1
  assert_contains "No workspace profile is bound"
  assert_contains "workspace bind"

  rm -rf "$tmp"
}

test_workspace_guards_explicit_profile_commands() {
  local tmp config workspace service unbound fake_codex marker out err chatgpt_app fake_bin tool_log
  tmp="$(mktemp -d)"
  tmp="$(cd "$tmp" && pwd -P)"
  config="$tmp/config"
  workspace="$tmp/client"
  service="$workspace/service"
  unbound="$tmp/unbound"
  fake_codex="$tmp/codex"
  marker="$tmp/codex-runs"
  out="$tmp/out"
  err="$tmp/err"
  chatgpt_app="$tmp/ChatGPT.app"
  fake_bin="$tmp/bin"
  tool_log="$tmp/tool.log"
  mkdir -p "$tmp/home/.codex-client" "$tmp/home/.codex-personal" "$service" "$unbound"
  cat > "$fake_codex" <<'FAKE_CODEX'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  printf 'fake-codex 1.0\n'
  exit 0
fi
printf 'ran %s\n' "$*" >> "${FAKE_CODEX_MARKER:?}"
printf 'CODEX_HOME=%s\n' "$CODEX_HOME"
printf 'ARGS=%s\n' "$*"
FAKE_CODEX
  chmod 755 "$fake_codex"
  write_fake_chatgpt_app_bundle "$chatgpt_app" "guarded ChatGPT launch"
  write_fake_chatgpt_open_tools "$fake_bin"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace bind "$workspace" client
  assert_status 0

  set +e
  env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" CODEX_CLI="$fake_codex" \
    FAKE_CODEX_MARKER="$marker" bash -c \
    'cd "$1" && exec "$2" cli personal exec check' _ "$service" "$SCRIPT" \
    > "$out" 2> "$err"
  status=$?
  set -e
  [[ "$status" -eq 0 ]] || fail "warn-mode CLI mismatch should run"
  [[ "$(cat "$out")" == *"CODEX_HOME=$tmp/home/.codex-personal"* ]] || \
    fail "warn-mode CLI did not use the explicit profile"
  [[ "$(cat "$out")" != *"Warning:"* ]] || fail "workspace warning polluted stdout"
  [[ "$(cat "$err")" == *"bound to profile 'client'"* ]] || fail "warn mode omitted expected profile"
  [[ "$(cat "$err")" == *"selected profile is 'personal'"* ]] || fail "warn mode omitted selected profile"

  : > "$err"
  set +e
  env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" CODEX_CLI="$fake_codex" \
    FAKE_CODEX_MARKER="$marker" bash -c \
    'cd "$1" && exec "$2" cli client exec check' _ "$service" "$SCRIPT" \
    > "$out" 2> "$err"
  status=$?
  set -e
  [[ "$status" -eq 0 ]] || fail "matching CLI profile should run"
  [[ ! -s "$err" ]] || fail "matching CLI profile emitted a warning"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace guard strict
  assert_status 0
  : > "$marker"

  set +e
  env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" CODEX_CLI="$fake_codex" \
    FAKE_CODEX_MARKER="$marker" bash -c \
    'cd "$1" && exec "$2" cli personal exec blocked' _ "$service" "$SCRIPT" \
    > "$out" 2> "$err"
  status=$?
  set -e
  [[ "$status" -eq 1 ]] || fail "strict-mode CLI mismatch was not rejected"
  [[ ! -s "$marker" ]] || fail "strict-mode CLI mismatch invoked Codex"
  [[ "$(cat "$err")" == *"refusing selected profile 'personal'"* ]] || fail "strict CLI error is not actionable"

  set +e
  env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    bash -c 'cd "$1" && exec "$2" env personal' _ "$service" "$SCRIPT" \
    > "$out" 2> "$err"
  status=$?
  set -e
  [[ "$status" -eq 1 ]] || fail "strict-mode env mismatch was not rejected"
  [[ ! -s "$out" ]] || fail "strict-mode env mismatch emitted eval-able stdout"

  rm -f "$tool_log"
  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    PATH="$fake_bin:$PATH" FAKE_TOOL_LOG="$tool_log" CHATGPT_APP="$chatgpt_app" \
    "$SCRIPT" app personal "$service"
  assert_status 1
  assert_contains "refusing selected profile 'personal'"
  [[ ! -e "$tool_log" ]] || fail "strict-mode app mismatch invoked macOS open"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace guard off
  assert_status 0
  : > "$err"
  set +e
  env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" CODEX_CLI="$fake_codex" \
    FAKE_CODEX_MARKER="$marker" bash -c \
    'cd "$1" && exec "$2" cli personal exec allowed' _ "$service" "$SCRIPT" \
    > "$out" 2> "$err"
  status=$?
  set -e
  [[ "$status" -eq 0 ]] || fail "off-mode CLI mismatch should run"
  [[ ! -s "$err" ]] || fail "off-mode CLI mismatch emitted a warning"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" CODEX_CLI="$fake_codex" \
    FAKE_CODEX_MARKER="$marker" bash -c \
    'cd "$1" && exec "$2" cli personal exec unbound' _ "$unbound" "$SCRIPT"
  assert_status 0
  assert_not_contains "Warning:"

  rm -rf "$tmp"
}

test_remove_cleans_workspace_bindings_without_touching_projects() {
  local tmp config personal_one personal_two work_space ghost_space marker
  tmp="$(mktemp -d)"
  tmp="$(cd "$tmp" && pwd -P)"
  config="$tmp/config"
  personal_one="$tmp/projects/personal-one"
  personal_two="$tmp/projects/personal-two"
  work_space="$tmp/projects/work"
  ghost_space="$tmp/projects/ghost"
  marker="$personal_one/keep.txt"
  mkdir -p "$tmp/home/.codex-personal" "$tmp/home/.codex-work" \
    "$tmp/home/.codex-ghost" "$personal_one" "$personal_two" "$work_space" "$ghost_space"
  printf 'keep project data\n' > "$marker"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace bind "$personal_one" personal
  assert_status 0
  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace bind "$personal_two" personal
  assert_status 0
  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace bind "$work_space" work
  assert_status 0
  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace bind "$ghost_space" ghost
  assert_status 0

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" remove personal --yes

  assert_status 0
  assert_contains "Removed personal"
  [[ -f "$marker" ]] || fail "profile removal deleted bound project data"
  [[ -d "$personal_two" ]] || fail "profile removal deleted a bound workspace"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace list --json
  assert_status 0
  assert_not_contains '"profile":"personal"'
  assert_contains '"profile":"work"'
  assert_contains '"profile":"ghost"'

  rm -rf "$tmp/home/.codex-ghost"
  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" remove ghost --yes
  assert_status 0
  assert_contains "Not initialized ghost"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace list --json
  assert_status 0
  assert_not_contains '"profile":"ghost"'
  assert_contains '"profile":"work"'

  printf 'malformed registry\n' > "$config/workspaces.tsv"
  mkdir -p "$tmp/home/.codex-client"
  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" remove client --yes
  assert_status 1
  assert_contains "Malformed workspace registry line 1"
  [[ -d "$tmp/home/.codex-client" ]] || fail "remove deleted a profile before validating binding cleanup"

  rm -rf "$tmp"
}

test_doctor_reports_workspace_binding_health_in_human_and_json_output() {
  local tmp config existing_one existing_two missing
  tmp="$(mktemp -d)"
  tmp="$(cd "$tmp" && pwd -P)"
  config="$tmp/config"
  existing_one="$tmp/projects/one"
  existing_two="$tmp/projects/two"
  missing="$tmp/projects/missing"
  mkdir -p "$tmp/home/.codex-work" "$existing_one" "$existing_two" "$config"
  chmod 700 "$config"
  printf '%s\t%s\n' "$existing_one" work > "$config/workspaces.tsv"
  printf '%s\t%s\n' "$missing" work >> "$config/workspaces.tsv"
  printf '%s\t%s\n' "$existing_two" ghost >> "$config/workspaces.tsv"
  chmod 600 "$config/workspaces.tsv"
  printf 'strict\n' > "$config/guard-mode"
  chmod 600 "$config/guard-mode"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    CODEX_CLI=/no/such/codex "$SCRIPT" doctor

  assert_status 0
  assert_contains "Workspace registry: $config/workspaces.tsv"
  assert_contains "Workspace guard mode: strict"
  assert_contains "Workspace bindings: 3"
  assert_contains "Missing workspace paths: 1"
  assert_contains "Missing workspace profiles: 1"
  assert_contains "CLI: missing"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    CODEX_CLI=/no/such/codex "$SCRIPT" doctor --json

  assert_status 0
  assert_contains '"workspaces":{'
  assert_contains '"guard_mode":"strict"'
  assert_contains '"registry_valid":true'
  assert_contains '"binding_count":3'
  assert_contains '"missing_paths":1'
  assert_contains '"missing_profiles":1'
  JSON_PAYLOAD="$output" node -e 'JSON.parse(process.env.JSON_PAYLOAD)'

  printf 'malformed registry\n' > "$config/workspaces.tsv"
  printf 'dangerous\n' > "$config/guard-mode"
  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    CODEX_CLI=/no/such/codex "$SCRIPT" doctor --json

  assert_status 0
  assert_contains '"guard_mode":null'
  assert_contains '"registry_valid":false'
  assert_contains '"binding_count":0'
  JSON_PAYLOAD="$output" node -e 'JSON.parse(process.env.JSON_PAYLOAD)'

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
  local tmp log_file legacy_log_file
  tmp="$(mktemp -d)"
  log_file="$tmp/home/.codex-personal/logs/desktop.log"
  legacy_log_file="$tmp/home/.codex-personal/logs/desktop-instance.log"
  mkdir -p "${log_file%/*}"
  printf 'canonical first\ncanonical second\n' > "$log_file"
  printf 'legacy first\nlegacy second\n' > "$legacy_log_file"

  run_cmd env HOME="$tmp/home" "$SCRIPT" logs personal --instance --path

  assert_status 0
  assert_equals "$log_file"

  run_cmd env HOME="$tmp/home" "$SCRIPT" logs personal --instance --tail 1

  assert_status 0
  assert_equals "canonical second"

  rm -f "$log_file"
  run_cmd env HOME="$tmp/home" "$SCRIPT" logs personal --instance --path

  assert_status 0
  assert_equals "$legacy_log_file"

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

test_completions_generate_shell_scripts() {
  run_cmd "$SCRIPT" help

  assert_status 0
  assert_contains "--instance"
  assert_contains "--share-with"

  run_cmd "$SCRIPT" completions bash

  assert_status 0
  assert_contains "complete -F _codex_profile codex-profile codex-profiles"
  assert_contains 'compgen -W "app app-instance cli login init remove status path env use logs clone-config list doctor completions shell-init upgrade version help"'
  assert_contains "clone-config"
  assert_contains "upgrade"
  assert_contains "--instance"
  assert_contains "app-instance"
  assert_contains "env"
  assert_contains "use"
  assert_contains "shell-init"
  assert_contains "--share-with"

  run_cmd "$SCRIPT" completions zsh

  assert_status 0
  assert_contains "#compdef codex-profile codex-profiles"
  assert_contains "app app-instance cli login init remove status path env use logs clone-config list doctor completions shell-init upgrade version help"
  assert_contains "logs"
  assert_contains "upgrade"
  assert_contains "--instance"
  assert_contains "app-instance"
  assert_contains "shell-init"
  assert_contains "--share-with"

  run_cmd "$SCRIPT" completions fish

  assert_status 0
  assert_contains "for codex_profile_command in codex-profile codex-profiles"
  assert_contains "complete -c \$codex_profile_command"
  assert_contains "-a 'app app-instance cli login init remove status path env use logs clone-config list doctor completions shell-init upgrade version help'"
  assert_contains "remove"
  assert_contains "upgrade"
  assert_contains "-l instance"
  assert_contains "-l rebuild"
  assert_contains "app-instance"
  assert_contains "shell-init"
  assert_contains "-l share-with"
  assert_not_contains "Codex Desktop clone"
  assert_not_contains "Rebuild the app --instance clone"
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

test_upgrade_refuses_checkout_missing_makefile() {
  local tmp repo cache prefix
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  cache="$tmp/cache/source"
  prefix="$tmp/prefix"
  mkdir -p "$repo/bin"
  init_git_main_branch "$repo"
  cat > "$repo/bin/codex-profile" <<'FAKE_PROFILE'
#!/usr/bin/env bash
VERSION="9.9.9"
printf 'codex-profile %s\n' "$VERSION"
FAKE_PROFILE
  chmod 755 "$repo/bin/codex-profile"
  git -C "$repo" add .
  git -C "$repo" -c user.name=test -c user.email=test@example.com commit -m "no makefile" >/dev/null

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_UPGRADE_REPO="$repo" CODEX_PROFILE_UPGRADE_CACHE="$cache" "$SCRIPT" upgrade --prefix "$prefix"

  assert_status 1
  assert_contains "Upgrade checkout is missing Makefile"
  [[ ! -e "$prefix/bin/codex-profile" ]] || fail "upgrade installed despite missing Makefile"

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

test_update_check_notifies_when_newer_version_is_cached() {
  local tmp cache stub now
  tmp="$(mktemp -d)"
  cache="$tmp/update-check"
  stub="$tmp/latest.json"
  printf '{"version":"9.9.9"}\n' > "$stub"
  now="$(date +%s)"
  printf '%s 9.9.9\n' "$now" > "$cache"

  run_cmd env HOME="$tmp/home" \
    CODEX_PROFILE_FORCE_UPDATE_CHECK=1 \
    CODEX_PROFILE_UPDATE_CACHE="$cache" \
    CODEX_PROFILE_UPDATE_URL="$stub" \
    "$SCRIPT" list

  assert_status 0
  assert_contains "9.9.9 available"

  rm -rf "$tmp"
}

test_update_check_is_silent_when_up_to_date() {
  local tmp cache stub now
  tmp="$(mktemp -d)"
  cache="$tmp/update-check"
  stub="$tmp/latest.json"
  printf '{"version":"0.0.1"}\n' > "$stub"
  now="$(date +%s)"
  printf '%s 0.0.1\n' "$now" > "$cache"

  run_cmd env HOME="$tmp/home" \
    CODEX_PROFILE_FORCE_UPDATE_CHECK=1 \
    CODEX_PROFILE_UPDATE_CACHE="$cache" \
    CODEX_PROFILE_UPDATE_URL="$stub" \
    "$SCRIPT" list

  assert_status 0
  assert_not_contains "available"

  rm -rf "$tmp"
}

test_update_check_respects_disable_env() {
  local tmp cache stub now
  tmp="$(mktemp -d)"
  cache="$tmp/update-check"
  stub="$tmp/latest.json"
  printf '{"version":"9.9.9"}\n' > "$stub"
  now="$(date +%s)"
  printf '%s 9.9.9\n' "$now" > "$cache"

  run_cmd env HOME="$tmp/home" \
    CODEX_PROFILE_FORCE_UPDATE_CHECK=1 \
    CODEX_PROFILE_NO_UPDATE_CHECK=1 \
    CODEX_PROFILE_UPDATE_CACHE="$cache" \
    CODEX_PROFILE_UPDATE_URL="$stub" \
    "$SCRIPT" list

  assert_status 0
  assert_not_contains "available"

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

test_update_check_is_silent_without_a_terminal() {
  local tmp cache stub now
  tmp="$(mktemp -d)"
  cache="$tmp/update-check"
  stub="$tmp/latest.json"
  printf '{"version":"9.9.9"}\n' > "$stub"
  now="$(date +%s)"
  printf '%s 9.9.9\n' "$now" > "$cache"

  # No force hook: run_cmd captures stdout through a pipe, so it is not a
  # terminal and the check must stay silent.
  run_cmd env HOME="$tmp/home" \
    CODEX_PROFILE_UPDATE_CACHE="$cache" \
    CODEX_PROFILE_UPDATE_URL="$stub" \
    "$SCRIPT" list

  assert_status 0
  assert_not_contains "available"

  rm -rf "$tmp"
}

test_update_check_refreshes_cache_from_source() {
  local tmp cache stub cached_version cached_epoch
  tmp="$(mktemp -d)"
  cache="$tmp/nested/update-check"
  stub="$tmp/latest.json"
  printf '{"version":"9.9.9"}\n' > "$stub"

  run_cmd env HOME="$tmp/home" \
    CODEX_PROFILE_FORCE_UPDATE_CHECK=1 \
    CODEX_PROFILE_UPDATE_SYNC=1 \
    CODEX_PROFILE_UPDATE_CACHE="$cache" \
    CODEX_PROFILE_UPDATE_URL="$stub" \
    "$SCRIPT" list

  assert_status 0
  [[ -f "$cache" ]] || fail "update check did not write its cache file"
  read -r cached_epoch cached_version < "$cache"
  [[ "$cached_version" == "9.9.9" ]] || fail "update cache did not record fetched version (got '$cached_version')"
  [[ "$cached_epoch" =~ ^[0-9]+$ ]] || fail "update cache did not record a numeric timestamp (got '$cached_epoch')"

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

test_env_prints_posix_exports_for_profile() {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/home/.codex" "$tmp/home/.codex-work"

  run_cmd env HOME="$tmp/home" "$SCRIPT" env work

  assert_status 0
  assert_contains "export CODEX_HOME='$tmp/home/.codex-work'"
  assert_contains "export CODEX_PROFILE_NAME='work'"
  assert_not_contains "not initialized"

  run_cmd env HOME="$tmp/home" "$SCRIPT" env default

  assert_status 0
  assert_contains "export CODEX_HOME='$tmp/home/.codex'"

  rm -rf "$tmp"
}

test_env_emits_fish_syntax() {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/home/.codex-work"

  run_cmd env HOME="$tmp/home" "$SCRIPT" env work --shell fish

  assert_status 0
  assert_contains "set -gx CODEX_HOME '$tmp/home/.codex-work'"
  assert_contains "set -gx CODEX_PROFILE_NAME 'work'"
  assert_not_contains "export CODEX_HOME"

  rm -rf "$tmp"
}

test_env_warns_to_stderr_without_polluting_stdout_when_uninitialized() {
  local tmp out err
  tmp="$(mktemp -d)"

  set +e
  out="$(env HOME="$tmp/home" "$SCRIPT" env ghost 2> "$tmp/err")"
  status=$?
  set -e
  err="$(cat "$tmp/err")"

  [[ "$status" -eq 0 ]] || fail "env should still emit exports for an uninitialized profile"
  [[ "$out" == "export CODEX_HOME='$tmp/home/.codex-ghost'"* ]] || fail "env stdout must carry eval-safe export lines"
  [[ "$out" != *"not initialized"* ]] || fail "env stdout must stay eval-safe (warning must not land on stdout)"
  [[ "$err" == *"profile 'ghost' is not initialized"* ]] || fail "env should warn on stderr for an uninitialized profile"

  rm -rf "$tmp"
}

test_env_rejects_invalid_profile_and_unsupported_shell() {
  local tmp
  tmp="$(mktemp -d)"

  run_cmd env HOME="$tmp/home" "$SCRIPT" env ../bad

  assert_status 1
  assert_contains "Invalid profile '../bad'"

  mkdir -p "$tmp/home/.codex-work"
  run_cmd env HOME="$tmp/home" "$SCRIPT" env work --shell tcsh

  assert_status 1
  assert_contains "Unsupported shell 'tcsh'"

  rm -rf "$tmp"
}

test_use_without_wrapper_explains_shell_init() {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/home/.codex-work"

  run_cmd env HOME="$tmp/home" "$SCRIPT" use work

  assert_status 1
  assert_contains "shell-init"
  assert_contains "eval"
  assert_contains "codex-profile env work"

  rm -rf "$tmp"
}

test_shell_init_emits_use_wrapper() {
  run_cmd "$SCRIPT" shell-init bash

  assert_status 0
  assert_contains "codex-profile() {"
  assert_contains "command codex-profile env"
  # shellcheck disable=SC2016 # matching the literal wrapper text, not expanding
  assert_contains 'eval "$__codex_profile_env"'

  run_cmd "$SCRIPT" shell-init zsh

  assert_status 0
  assert_contains "codex-profile() {"

  run_cmd "$SCRIPT" shell-init fish

  assert_status 0
  assert_contains "function codex-profile"
  assert_contains "env --shell fish"
  assert_contains "| source"
  # the fish wrapper must propagate env's failure status, not source's
  assert_contains "or return \$status"

  run_cmd "$SCRIPT" shell-init tcsh

  assert_status 1
  assert_contains "Unsupported shell 'tcsh'"

  run_cmd "$SCRIPT" shell-init

  assert_status 1
  assert_contains "Usage:"
}

test_shell_init_use_activates_profile_in_current_shell() {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/home/.codex-work" "$tmp/bin"
  ln -s "$SCRIPT" "$tmp/bin/codex-profile"

  # shellcheck disable=SC2016 # the child bash must expand these, not this shell
  run_cmd env HOME="$tmp/home" PATH="$tmp/bin:$PATH" bash -c '
    eval "$(codex-profile shell-init bash)"
    codex-profile use work
    printf "HOME_IS=%s\n" "$CODEX_HOME"
    printf "NAME_IS=%s\n" "$CODEX_PROFILE_NAME"
    codex-profile path work
  '

  assert_status 0
  assert_contains "HOME_IS=$tmp/home/.codex-work"
  assert_contains "NAME_IS=work"
  assert_contains "$tmp/home/.codex-work"

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
test_profile_home_symlinks_are_refused
test_named_app_user_data_symlinks_are_refused
test_app_propagates_open_failures
test_doctor_skips_status_when_cli_missing
test_doctor_reports_desktop_and_cli_when_present
test_init_creates_private_profile_home_without_codex
test_init_share_with_links_only_existing_allowlisted_config
test_init_share_with_rejects_invalid_sources_and_usage
test_init_share_with_refuses_every_existing_target_path
test_init_share_with_cleans_up_after_link_failure
test_remove_aborts_when_confirmation_does_not_match
test_remove_yes_deletes_profile_home
test_remove_yes_deletes_profiles_named_like_common_aliases
test_workspace_bind_list_status_and_nested_resolution
test_workspace_bind_rejects_unsafe_state_and_reports_stale_bindings
test_workspace_uses_xdg_config_and_manages_guard_mode
test_workspace_run_routes_cli_and_signed_app
test_workspace_guards_explicit_profile_commands
test_remove_cleans_workspace_bindings_without_touching_projects
test_doctor_reports_workspace_binding_health_in_human_and_json_output
test_env_prints_posix_exports_for_profile
test_env_emits_fish_syntax
test_env_warns_to_stderr_without_polluting_stdout_when_uninitialized
test_env_rejects_invalid_profile_and_unsupported_shell
test_use_without_wrapper_explains_shell_init
test_shell_init_emits_use_wrapper
test_shell_init_use_activates_profile_in_current_shell
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
test_upgrade_refuses_checkout_missing_makefile
test_clone_config_copies_safe_files_and_never_auth_files
test_clone_config_refuses_sensitive_looking_config
test_clone_config_refuses_symlinked_config_files
test_clone_config_refuses_symlinked_target_files_even_with_force
test_clone_config_refuses_to_overwrite_without_force
test_update_check_notifies_when_newer_version_is_cached
test_update_check_is_silent_when_up_to_date
test_update_check_respects_disable_env
test_json_commands_never_emit_update_notices
test_update_check_is_silent_without_a_terminal
test_update_check_refreshes_cache_from_source
