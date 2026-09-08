#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/test/lib/assertions.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
source "$ROOT_DIR/test/lib/cli-fixtures.sh"
HOST_SYSTEM="$(uname -s)"

prepare_interactive_test() {
  tmp="$(mktemp -d "$TMP_ROOT/case.XXXXXX")"
  tmp="$(cd "$tmp" && pwd -P)"
  mkdir -p "$tmp/home" "$tmp/bin" "$tmp/workspace"
  cat > "$tmp/bin/codex" <<'CODEX'
#!/usr/bin/env bash
if [[ "${1:-}" == --version ]]; then
  printf 'fake-codex 1.0\n'
  exit 0
fi
printf 'CODEX_HOME=%s ARGS=%s\n' "$CODEX_HOME" "$*" >> "$FAKE_TOOL_LOG"
[[ "${1:-}" != login ]] || exit "${FAKE_LOGIN_EXIT:-0}"
CODEX
  cat > "$tmp/bin/uname" <<'UNAME'
#!/usr/bin/env bash
printf '%s\n' "${FAKE_SYSTEM:-Linux}"
UNAME
  chmod 755 "$tmp/bin/codex" "$tmp/bin/uname"
  TEST_ENV=(env HOME="$tmp/home" PATH="$tmp/bin:$PATH"
    CODEX_CLI="$tmp/bin/codex" CODEX_PROFILE_CONFIG_HOME="$tmp/config"
    CODEX_PROFILE_LAUNCHER_ROOT="$tmp/apps" CODEX_PROFILE_NO_UPDATE_CHECK=1
    CHATGPT_APP="$tmp/ChatGPT.app" FAKE_TOOL_LOG="$tmp/tool.log")
}

# BSD and util-linux script differ in command syntax and exit propagation.
# Record the child status explicitly and keep stdin open until it exits: BSD
# script can otherwise inject EOF before the piped answers reach the child.
run_interactive() {
  local input="$1" runner ready result attempt command_text
  shift
  runner="$(mktemp "$tmp/runner.XXXXXX")"
  ready="$runner.ready"
  result="$runner.status"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'cd %q || exit 1\n' "$tmp/workspace"
    printf ': > %q\n' "$ready"
    printf '%q ' "${TEST_ENV[@]}" "$@"
    printf '\nprintf "%%s\\n" "$?" > %q\n' "$result"
  } > "$runner"
  printf -v command_text 'bash %q' "$runner"
  set +e
  output="$({
    for ((attempt = 0; attempt < 100; attempt++)); do
      [[ ! -f "$ready" ]] || break
      sleep 0.05
    done
    printf '%b' "$input"
    for ((attempt = 0; attempt < 200; attempt++)); do
      [[ ! -f "$result" ]] || break
      sleep 0.05
    done
  } | if [[ "$HOST_SYSTEM" == Darwin ]]; then
    script -q /dev/null bash "$runner"
  else
    script -q -c "$command_text" /dev/null
  fi 2>&1)"
  set -e
  [[ -f "$result" ]] || fail "interactive command did not finish: $output"
  status="$(cat "$result")"
  output="${output//$'\r'/}"
}

test_interactive_commands_require_terminal_before_mutation() {
  local subcommand
  prepare_interactive_test
  for subcommand in cli app; do
    run_cmd_with_input '1\n' "${TEST_ENV[@]}" "$SCRIPT" "$subcommand"
    assert_status 1
    assert_contains 'terminal'
  done
  run_cmd_with_input 'n\nn\n' "${TEST_ENV[@]}" "$SCRIPT" setup work
  assert_status 1
  assert_contains 'terminal'
  [[ ! -e "$tmp/home/.codex-work" && ! -e "$tmp/config" ]] || fail 'noninteractive setup mutated state'
  run_cmd "${TEST_ENV[@]}" "$SCRIPT" cli ''
  assert_status 1
  assert_not_contains 'Choose'
  run_cmd "${TEST_ENV[@]}" "$SCRIPT" app ''
  assert_status 1
  assert_not_contains 'Choose'
  run_cmd "${TEST_ENV[@]}" "$SCRIPT" setup
  assert_status 1
  assert_contains 'Usage:'
  run_cmd "${TEST_ENV[@]}" "$SCRIPT" setup work extra
  assert_status 1
  assert_contains 'Usage:'
  [[ ! -e "$tmp/home/.codex-work" ]] || fail 'invalid setup arguments initialized profile'
}

test_picker_selection_retries_and_excludes_symlinks() {
  prepare_interactive_test
  mkdir -p "$tmp/home/.codex" "$tmp/home/.codex-work" "$tmp/home/.codex-.invalid" "$tmp/outside"
  ln -s "$tmp/outside" "$tmp/home/.codex-link"
  # shellcheck disable=SC2016 # Deliberately submit literal command substitution.
  run_interactive '\n0\n999999999999999999999999999999\na[$(touch "'"$tmp"'/injected")]\n2\n' "$SCRIPT" cli
  assert_status 0
  assert_contains 'default'
  assert_contains 'work'
  assert_not_contains '.invalid'
  assert_not_contains 'link'
  [[ ! -e "$tmp/injected" ]] || fail 'picker evaluated arithmetic or shell input'
  [[ "$(cat "$tmp/tool.log")" == "CODEX_HOME=$tmp/home/.codex-work ARGS=" ]] || fail 'picker launched wrong profile or passed menu text as arguments'
}

test_picker_workspace_default_and_launch_guard() {
  prepare_interactive_test
  mkdir -p "$tmp/home/.codex" "$tmp/home/.codex-work"
  run_cmd "${TEST_ENV[@]}" "$SCRIPT" workspace bind "$tmp/workspace" work
  assert_status 0
  run_interactive '\n' "$SCRIPT" cli
  assert_status 0
  assert_contains 'work (workspace)'
  assert_contains "$(cat "$tmp/tool.log")" "CODEX_HOME=$tmp/home/.codex-work" 'selected workspace profile'
  run_cmd "${TEST_ENV[@]}" "$SCRIPT" workspace guard strict
  assert_status 0
  run_interactive '1\n' "$SCRIPT" cli
  assert_status 1
  [[ "$(wc -l < "$tmp/tool.log" | tr -d ' ')" == 1 ]] || fail 'picker bypassed workspace launch guard'
}

test_picker_cancellation_eof_and_no_profiles() {
  local input
  prepare_interactive_test
  run_interactive 'q\n' "$SCRIPT" cli
  assert_status 1
  [[ ! -e "$tmp/config" && ! -e "$tmp/tool.log" ]] || fail 'empty picker mutated state'
  mkdir -p "$tmp/home/.codex-work"
  for input in 'q\n' 'Q\n' '\004'; do
    run_interactive "$input" "$SCRIPT" cli
    assert_status 1
    [[ ! -e "$tmp/tool.log" ]] || fail 'cancelled picker launched CLI'
  done
}

test_app_picker_uses_existing_launch_and_current_workspace() {
  prepare_interactive_test
  mkdir -p "$tmp/home/.codex-work"
  write_fake_chatgpt_app_bundle "$tmp/ChatGPT.app" 'picked app'
  write_fake_chatgpt_open_tools "$tmp/bin"
  run_interactive '1\n' env FAKE_SYSTEM=Darwin "$SCRIPT" app
  assert_status 0
  assert_contains "$(cat "$tmp/tool.log")" "files=$tmp/workspace" 'app workspace defaults to PWD'
  assert_contains "$(cat "$tmp/home/.codex-work/logs/desktop.log")" "CODEX_HOME=$tmp/home/.codex-work" 'app selected profile'
}

test_setup_defaults_login_and_continues_to_binding() {
  prepare_interactive_test
  run_interactive '\ny\n\n' "$SCRIPT" setup work
  assert_status 0
  [[ -d "$tmp/home/.codex-work" ]] || fail 'setup did not initialize profile'
  [[ "$(mode_of "$tmp/home/.codex-work")" == 700 ]] || fail 'setup profile is not private'
  assert_contains "$(cat "$tmp/tool.log")" "CODEX_HOME=$tmp/home/.codex-work ARGS=login" 'setup login'
  assert_not_contains 'launcher'
  run_cmd "${TEST_ENV[@]}" "$SCRIPT" workspace status --json "$tmp/workspace"
  assert_status 0
  assert_contains '"profile":"work"'
}

test_setup_existing_profile_skips_steps_and_retries_invalid_answers() {
  prepare_interactive_test
  mkdir -p "$tmp/home/.codex-work"
  printf 'keep this config\n' > "$tmp/home/.codex-work/config.toml"
  run_interactive 'maybe\nn\n\n' "$SCRIPT" setup work
  assert_status 0
  assert_contains 'Already initialized work'
  [[ "$(cat "$tmp/home/.codex-work/config.toml")" == 'keep this config' ]] || fail 'setup overwrote existing config'
  [[ ! -e "$tmp/tool.log" && ! -e "$tmp/config/workspaces.tsv" ]] || fail 'skipped setup steps still ran'
}

test_setup_login_failure_and_cancellation_keep_completed_steps() {
  local input
  prepare_interactive_test
  run_interactive 'y\ny\n\n' env FAKE_LOGIN_EXIT=23 "$SCRIPT" setup work
  [[ "$status" -ne 0 ]] || fail 'setup ignored failed login'
  [[ -d "$tmp/home/.codex-work" ]] || fail 'login failure removed initialized profile'
  [[ ! -e "$tmp/config/workspaces.tsv" ]] || fail 'setup continued after login failure'
  assert_not_contains 'Bind a workspace'
  for input in 'q\n' '\004' 'n\nq\n' 'n\ny\n\004'; do
    prepare_interactive_test
    run_interactive "$input" "$SCRIPT" setup work
    assert_status 1
    [[ -d "$tmp/home/.codex-work" ]] || fail 'cancelled setup removed initialized profile'
    [[ ! -e "$tmp/tool.log" && ! -e "$tmp/config/workspaces.tsv" ]] || fail 'cancelled setup ran later steps'
  done
}

test_setup_binding_conflict_preserves_original_profile() {
  prepare_interactive_test
  mkdir -p "$tmp/home/.codex-existing"
  run_cmd "${TEST_ENV[@]}" "$SCRIPT" workspace bind "$tmp/workspace" existing
  assert_status 0
  run_interactive 'n\ny\n\n' "$SCRIPT" setup work
  assert_status 1
  [[ -d "$tmp/home/.codex-work" ]] || fail 'binding failure removed initialized profile'
  run_cmd "${TEST_ENV[@]}" "$SCRIPT" workspace status --json "$tmp/workspace"
  assert_status 0
  assert_contains '"profile":"existing"'
}

test_setup_macos_offers_optional_launcher() {
  prepare_interactive_test
  run_interactive 'n\nn\n\n' env FAKE_SYSTEM=Darwin "$SCRIPT" setup work
  assert_status 0
  assert_contains 'launcher'
  [[ ! -e "$tmp/apps" ]] || fail 'setup created skipped launcher'
  # An unmanaged launcher collision exercises the real create path without
  # duplicating icon-generation fixtures covered by launcher-test.sh.
  mkdir -p "$tmp/apps/ChatGPT work.app"
  printf 'preserve\n' > "$tmp/apps/ChatGPT work.app/marker"
  run_interactive 'n\nn\ny\n' env FAKE_SYSTEM=Darwin "$SCRIPT" setup work
  assert_status 1
  assert_contains 'unmanaged'
  [[ "$(cat "$tmp/apps/ChatGPT work.app/marker")" == preserve ]] || fail 'setup overwrote existing launcher'
}

test_setup_creates_launcher_and_binds_explicit_workspace() {
  local tool
  prepare_interactive_test
  mkdir -p "$tmp/another workspace"
  write_fake_chatgpt_app_bundle "$tmp/ChatGPT.app" 'setup app'
  write_fake_chatgpt_open_tools "$tmp/bin"
  for tool in sips qlmanage iconutil; do
    cat > "$tmp/bin/$tool" <<'ICON_TOOL'
#!/usr/bin/env bash
destination=''
source_svg=''
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -o|--out) destination="$2"; shift ;;
    *.svg) source_svg="$1" ;;
  esac
  shift
done
[[ -n "$destination" ]] || exit 2
if [[ "${0##*/}" == qlmanage ]]; then
  destination="$destination/${source_svg##*/}.png"
fi
printf 'fake icon\n' > "$destination"
ICON_TOOL
    chmod 755 "$tmp/bin/$tool"
  done
  run_interactive 'n\ny\n'"$tmp"'/another workspace\ny\n' env FAKE_SYSTEM=Darwin "$SCRIPT" setup work
  assert_status 0
  [[ -x "$tmp/apps/ChatGPT work.app/Contents/MacOS/launch-profile" ]] || fail 'setup did not create launcher'
  run_cmd "${TEST_ENV[@]}" "$SCRIPT" workspace status --json "$tmp/another workspace"
  assert_status 0
  assert_contains '"profile":"work"'
}

test_interactive_commands_require_terminal_before_mutation
test_picker_selection_retries_and_excludes_symlinks
test_picker_workspace_default_and_launch_guard
test_picker_cancellation_eof_and_no_profiles
test_app_picker_uses_existing_launch_and_current_workspace
test_setup_defaults_login_and_continues_to_binding
test_setup_existing_profile_skips_steps_and_retries_invalid_answers
test_setup_login_failure_and_cancellation_keep_completed_steps
test_setup_binding_conflict_preserves_original_profile
test_setup_macos_offers_optional_launcher
test_setup_creates_launcher_and_binds_explicit_workspace
