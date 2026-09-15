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
    SHELL=/bin/bash ZDOTDIR="$tmp/home" TERM=dumb
    CODEX_CLI="$tmp/bin/codex" CODEX_PROFILE_CONFIG_HOME="$tmp/config"
    CODEX_PROFILE_LAUNCHER_ROOT="$tmp/apps" CODEX_PROFILE_NO_UPDATE_CHECK=1
    CHATGPT_APP="$tmp/ChatGPT.app" FAKE_TOOL_LOG="$tmp/tool.log")
}

test_picker_names_and_shell_default() {
  prepare_interactive_test
  mkdir -p "$tmp/home/.codex-personal" "$tmp/home/.codex-work"
  run_interactive 'work\nq\n' "$SCRIPT" cli
  assert_status 0
  assert_contains "$(cat "$tmp/tool.log")" 'home/.codex-work' 'named selection'
  run_interactive '\nq\n' env CODEX_PROFILE_NAME=work CODEX_HOME="$tmp/home/.codex-work" "$SCRIPT" cli
  assert_status 0
  assert_contains 'work (shell)'
  run_interactive '\nq\n' env CODEX_PROFILE_NAME=work CODEX_HOME="$tmp/home/.codex-personal" "$SCRIPT" cli
  assert_status 1
  assert_not_contains '(shell)'
  assert_not_contains 'Error:'
  run_cmd "${TEST_ENV[@]}" "$SCRIPT" workspace bind "$tmp/workspace" personal
  run_interactive '\nq\n' env CODEX_PROFILE_NAME=work CODEX_HOME="$tmp/home/.codex-work" "$SCRIPT" cli
  assert_status 0
  assert_contains 'personal (workspace)'
  assert_contains "$(tail -n 1 "$tmp/tool.log")" 'home/.codex-personal' 'workspace takes priority'
  rmdir "$tmp/home/.codex-personal"
  run_interactive '\nq\n' env CODEX_PROFILE_NAME=work CODEX_HOME="$tmp/home/.codex-work" "$SCRIPT" cli
  assert_status 1
  assert_not_contains '[1]'
  assert_not_contains 'Error:'
}

test_picker_keyboard_navigation_and_filter() {
  local INTERACTIVE_WAIT_FOR='Filter:'
  prepare_interactive_test
  mkdir -p "$tmp/home/.codex-personal" "$tmp/home/.codex-work" "$tmp/home/.codex-workshop"
  run_interactive '\033[B\n' env TERM=xterm-256color "$SCRIPT" cli
  assert_status 0
  assert_contains "$(tail -n 1 "$tmp/tool.log")" 'home/.codex-work ARGS=' 'down selects next profile'
  run_interactive '\033[A\n' env TERM=xterm-256color "$SCRIPT" cli
  assert_status 0
  assert_contains "$(tail -n 1 "$tmp/tool.log")" 'home/.codex-workshop ARGS=' 'up wraps to last profile'
  run_interactive 'ork\033[B\n' env TERM=xterm-256color NO_COLOR=1 "$SCRIPT" cli
  assert_status 0
  assert_contains "$(tail -n 1 "$tmp/tool.log")" 'home/.codex-workshop ARGS=' 'arrows navigate filtered matches'
  assert_not_contains $'\033[1;36m'
  run_interactive 'zz\177\177personal\n' env TERM=xterm-256color "$SCRIPT" cli
  assert_status 0
  assert_contains 'No matching profiles'
  assert_contains "$(tail -n 1 "$tmp/tool.log")" 'home/.codex-personal ARGS=' 'backspace recovers from no matches'
  run_interactive '#2\n' env TERM=xterm-256color "$SCRIPT" cli
  assert_status 0
  assert_contains "$(tail -n 1 "$tmp/tool.log")" 'home/.codex-work ARGS=' 'explicit menu number works'
  run_interactive '\n' env TERM=xterm-256color CODEX_PROFILE_NAME=work CODEX_HOME="$tmp/home/.codex-work" "$SCRIPT" cli
  assert_status 0
  assert_contains "$(tail -n 1 "$tmp/tool.log")" 'home/.codex-work ARGS=' 'shell default in arrow picker'
  prepare_interactive_test
  mkdir -p "$tmp/home/.codex-12" "$tmp/home/.codex-2" "$tmp/home/.codex-my-work" "$tmp/home/.codex-work"
  run_interactive '2\n' env TERM=xterm-256color "$SCRIPT" cli
  assert_status 0
  assert_contains "$(tail -n 1 "$tmp/tool.log")" 'home/.codex-2 ARGS=' 'exact numeric name beats earlier substring'
  run_interactive 'work\n' env TERM=xterm-256color "$SCRIPT" cli
  assert_status 0
  assert_contains "$(tail -n 1 "$tmp/tool.log")" 'home/.codex-work ARGS=' 'exact name beats earlier substring'
  run_interactive '4\n' env TERM=xterm-256color "$SCRIPT" cli
  assert_status 0
  assert_contains "$(tail -n 1 "$tmp/tool.log")" 'home/.codex-work ARGS=' 'menu number selects original index'
}

test_picker_restores_terminal() {
  local input expected INTERACTIVE_WAIT_FOR='Filter:'
  for input in 'work\n' '\033' '\003' '\004' 'q\n'; do
    prepare_interactive_test
    mkdir -p "$tmp/home/.codex-work"
    expected=1
    [[ "$input" != 'work\n' ]] || expected=0
    [[ "$input" != '\003' ]] || expected=130
    # shellcheck disable=SC2016 # The child shell compares its terminal state.
    run_interactive "$input" env TERM=xterm-256color bash -c '
      trap : INT
      # macOS may set the transient PENDIN bit when queued input is retyped.
      before=$(stty -a | sed "s/-\{0,1\}pendin//g")
      "$1" cli
      result=$?
      after=$(stty -a | sed "s/-\{0,1\}pendin//g")
      [[ "$after" == "$before" ]] || { printf "terminal before=%s after=%s\n" "$before" "$after"; exit 99; }
      exit "$result"
    ' _ "$SCRIPT"
    assert_status "$expected"
    if [[ "$expected" != 0 ]]; then
      [[ ! -e "$tmp/tool.log" ]] || fail 'cancelled arrow picker launched CLI'
    fi
  done
}

test_picker_cancellation_status_reaches_all_commands() {
  local command input expected INTERACTIVE_WAIT_FOR='Filter:'
  local -a args
  for command in cli app run 'run --app'; do
    read -r -a args <<< "$command"
    for input in '\003' '\033' '\004' 'q\n'; do
      prepare_interactive_test
      mkdir -p "$tmp/home/.codex-work"
      expected=1
      [[ "$input" != '\003' ]] || expected=130
      # Deliver Ctrl-C as a byte so process-group SIGINT cannot mask a caller
      # incorrectly replacing the picker's exit status with 1.
      # shellcheck disable=SC2016 # The child shell checks its own terminal.
      run_interactive "$input" env TERM=xterm-256color bash -c '
        stty intr undef
        before=$(stty -a | sed "s/-\{0,1\}pendin//g")
        "$@"
        result=$?
        after=$(stty -a | sed "s/-\{0,1\}pendin//g")
        [[ "$after" == "$before" ]] || exit 99
        exit "$result"
      ' _ "$SCRIPT" "${args[@]}"
      assert_status "$expected"
      [[ ! -e "$tmp/tool.log" && ! -e "$tmp/config" ]] || fail "cancelled $command launched or saved state"
    done
  done
}

test_welcome_project_and_shell_context() {
  prepare_interactive_test
  mkdir -p "$tmp/home/.codex-personal" "$tmp/home/.codex-work"
  run_cmd "${TEST_ENV[@]}" "$SCRIPT" workspace bind "$tmp/workspace" work
  run_interactive '' env TERM=xterm-256color NO_COLOR=1 CODEX_PROFILE_NAME=personal CODEX_HOME="$tmp/home/.codex-personal" "$SCRIPT"
  assert_status 0
  assert_contains 'Bound profile'
  assert_contains 'Shell profile'
  assert_contains 'personal'
  assert_contains 'Launch this project:'
  assert_contains 'codex-profile run'
  [[ ! -e "$tmp/tool.log" ]] || fail 'welcome probed login or launched CLI'
  run_interactive '' env TERM=dumb "$SCRIPT"
  assert_status 0
  assert_not_contains 'Bound profile'
  run_cmd "${TEST_ENV[@]}" TERM=xterm-256color "$SCRIPT"
  assert_status 0
  assert_not_contains 'Bound profile'
}

test_run_recovers_unbound_workspace() {
  prepare_interactive_test
  mkdir -p "$tmp/home/.codex-work"
  run_interactive 'work\nn\n' "$SCRIPT" run exec check
  assert_status 0
  assert_contains "$(cat "$tmp/tool.log")" 'ARGS=exec check' 'unbound launch arguments'
  [[ ! -e "$tmp/config/workspaces.tsv" ]] || fail 'declined binding still saved'
  run_interactive 'work\ny\n' "$SCRIPT" run
  assert_status 0
  run_cmd "${TEST_ENV[@]}" "$SCRIPT" workspace status --json "$tmp/workspace"
  assert_contains '"profile":"work"'
  prepare_interactive_test
  mkdir -p "$tmp/home/.codex-work"
  run_interactive 'work\nq\n' "$SCRIPT" run
  assert_status 1
  assert_not_contains 'Error:'
  [[ ! -e "$tmp/tool.log" && ! -e "$tmp/config/workspaces.tsv" ]] || fail 'cancelled run changed state'
  run_cmd "${TEST_ENV[@]}" "$SCRIPT" run
  assert_status 1
  assert_contains 'No workspace profile is bound'
  assert_not_contains 'Choose a profile'
}

test_setup_terminal_integration() {
  local shell startup
  for shell in bash zsh fish; do
    prepare_interactive_test
    case "$shell" in
      bash) startup="$tmp/home/.bashrc" ;;
      zsh) startup="$tmp/home/.zshrc" ;;
      fish) startup="$tmp/home/.config/fish/config.fish" ;;
    esac
    mkdir -p "${startup%/*}"
    printf '# preserve existing settings\n' > "$startup"
    run_interactive 'n\nn\ny\n' env SHELL="/bin/$shell" XDG_CONFIG_HOME="$tmp/home/.config" "$SCRIPT" setup work
    assert_status 0
    assert_contains 'shell-init'
    assert_contains 'CODEX_PROFILE_NOTIFY'
    assert_contains "$(cat "$startup")" '# preserve existing settings' 'preserved shell settings'
    assert_contains "$(cat "$startup")" "shell-init $shell --prompt --completions" 'installed shell integration'
    assert_contains "$(cat "$startup")" 'CODEX_PROFILE_TERMINAL_TITLE' 'installed titles'
    run_interactive 'n\nn\n' env SHELL="/bin/$shell" XDG_CONFIG_HOME="$tmp/home/.config" "$SCRIPT" setup work
    assert_status 0
    [[ "$(grep -c 'shell-init' "$startup")" -eq 1 ]] || fail 'setup duplicated integration'
  done
}

test_picker_numeric_names_and_cancel() {
  prepare_interactive_test
  mkdir -p "$tmp/home/.codex-2" "$tmp/home/.codex-q" "$tmp/home/.codex-work"
  run_interactive '2\nq\n' "$SCRIPT" cli
  assert_status 0
  assert_contains "$(tail -n 1 "$tmp/tool.log")" 'home/.codex-2' 'exact numeric name takes precedence'
  run_interactive '#2\nq\n' "$SCRIPT" cli
  assert_status 0
  assert_contains "$(tail -n 1 "$tmp/tool.log")" 'home/.codex-q' 'explicit menu number resolves numeric-name collision'
  run_interactive '\nq\n' env CODEX_PROFILE_NAME=work CODEX_HOME="$tmp/home/.codex-work" "$SCRIPT" cli
  assert_status 0
  assert_contains "$(tail -n 1 "$tmp/tool.log")" 'home/.codex-work' 'Enter selects default profile'
  run_interactive 'q\n' "$SCRIPT" app
  assert_status 1
  assert_not_contains 'Error:'
}

test_run_app_recovers_requested_workspace() {
  prepare_interactive_test
  mkdir -p "$tmp/home/.codex-work" "$tmp/another workspace"
  write_fake_chatgpt_app_bundle "$tmp/ChatGPT.app" 'recovered app'
  write_fake_chatgpt_open_tools "$tmp/bin"
  run_interactive 'work\ny\n' env FAKE_SYSTEM=Darwin "$SCRIPT" run --app "$tmp/another workspace"
  assert_status 0
  assert_contains "$(cat "$tmp/tool.log")" "files=$tmp/another workspace" 'recovered app directory'
  run_cmd "${TEST_ENV[@]}" "$SCRIPT" workspace status --json "$tmp/another workspace"
  assert_contains '"profile":"work"'
  run_cmd "${TEST_ENV[@]}" "$SCRIPT" workspace status --json "$tmp/workspace"
  assert_contains '"profile":null'
}

test_run_recovery_preserves_streams_and_rejects_invalid_state() {
  prepare_interactive_test
  mkdir -p "$tmp/home/.codex-work"
  cat > "$tmp/bin/codex" <<'CODEX'
#!/usr/bin/env bash
[[ "${1:-}" != --version ]] || { printf 'fake-codex 1.0\n'; exit 0; }
printf '{"result":"ok"}\n'
exit 7
CODEX
  # shellcheck disable=SC2016 # Expanded in the terminal child.
  run_interactive 'work\ny\n' bash -c '"$1" run -- exec --json > "$2"' _ "$SCRIPT" "$tmp/stdout"
  assert_status 7
  [[ "$(cat "$tmp/stdout")" == '{"result":"ok"}' ]] || fail 'interactive binding polluted stdout'
  printf 'invalid state\n' > "$tmp/config/workspaces.tsv"
  run_interactive 'work\ny\n' "$SCRIPT" run
  assert_status 1
  assert_contains 'Malformed workspace registry'
  assert_not_contains 'Choose a profile'
}

test_setup_terminal_integration_safe_append() {
  prepare_interactive_test
  printf 'keep without newline' > "$tmp/home/.bashrc"
  run_interactive 'n\nn\n\n' "$SCRIPT" setup work
  assert_status 0
  [[ "$(cat "$tmp/home/.bashrc")" == 'keep without newline' ]] || fail 'declined integration changed startup'
  run_interactive 'n\nn\ny\n' "$SCRIPT" setup work
  assert_status 0
  assert_contains "$(cat "$tmp/home/.bashrc")" $'keep without newline\n' 'append separates existing last line'
  # A partially configured shell gets only the missing lines.
  # shellcheck disable=SC2016 # Store literal startup configuration.
  printf '%s\n' 'eval "$(codex-profile shell-init bash --prompt --completions)"' > "$tmp/home/.bashrc"
  run_interactive 'n\nn\ny\n' "$SCRIPT" setup work
  assert_status 0
  [[ "$(grep -c 'shell-init' "$tmp/home/.bashrc")" -eq 1 ]] || fail 'partial repair duplicated shell-init'
  assert_contains "$(cat "$tmp/home/.bashrc")" 'CODEX_PROFILE_NOTIFY=1' 'partial repair adds feedback'
  rm "$tmp/home/.bashrc"
  # shellcheck disable=SC2016 # Expanded in the terminal child.
  run_interactive 'n\nn\ny\n' bash -c '"$1" setup work > "$2"' _ "$SCRIPT" "$tmp/setup.out"
  assert_status 0
  assert_contains 'shell-init bash --prompt --completions'
  assert_contains 'CODEX_PROFILE_NOTIFY=1'
  assert_contains 'Append the missing lines'
  rm "$tmp/home/.bashrc"
  printf 'private existing config\n' > "$tmp/outside"
  ln -s "$tmp/outside" "$tmp/home/.bashrc"
  run_interactive 'n\nn\n' "$SCRIPT" setup work
  assert_status 0
  assert_contains 'manually'
  assert_not_contains 'private existing config'
  [[ "$(cat "$tmp/outside")" == 'private existing config' ]] || fail 'setup wrote linked startup'
  rm "$tmp/home/.bashrc"
  ln "$tmp/outside" "$tmp/home/.bashrc"
  run_interactive 'n\nn\n' "$SCRIPT" setup work
  assert_status 0
  assert_contains 'multiply-linked'
  [[ "$(cat "$tmp/outside")" == 'private existing config' ]] || fail 'setup wrote hard-linked startup'
}

test_setup_macos_bash_preserves_login_startup() {
  prepare_interactive_test
  printf '# existing login settings\n' > "$tmp/home/.profile"
  run_interactive 'n\nn\nn\ny\n' env FAKE_SYSTEM=Darwin "$SCRIPT" setup work
  assert_status 0
  [[ ! -e "$tmp/home/.bash_profile" ]] || fail 'setup shadowed existing login file'
  assert_contains "$(cat "$tmp/home/.profile")" '# existing login settings' 'preserved login settings'
  # shellcheck disable=SC2016 # Match the guard evaluated by the login shell.
  assert_contains "$(cat "$tmp/home/.profile")" '[ -z "${BASH_VERSION:-}" ] || eval' 'Bash-only profile integration'
}

# BSD and util-linux script differ in command syntax and exit propagation.
# Record the child status explicitly and keep stdin open until it exits: BSD
# script can otherwise inject EOF before the piped answers reach the child.
run_interactive() {
  local input="$1" runner ready result attempt command_text transcript
  shift
  runner="$(mktemp "$tmp/runner.XXXXXX")"
  ready="$runner.ready"
  result="$runner.status"
  transcript="$runner.transcript"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'trap : INT\n'
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
    if [[ -n "${INTERACTIVE_WAIT_FOR:-}" ]]; then
      for ((attempt = 0; attempt < 200; attempt++)); do
        if [[ -f "$transcript" ]] && grep -Fq "$INTERACTIVE_WAIT_FOR" "$transcript"; then break; fi
        sleep 0.05
      done
    fi
    # A command with no selectable profiles can exit before consuming input.
    printf '%b' "$input" 2>/dev/null || true
    for ((attempt = 0; attempt < 200; attempt++)); do
      [[ ! -f "$result" ]] || break
      sleep 0.05
    done
  } | if [[ "$HOST_SYSTEM" == Darwin ]]; then
    script -q -F "$transcript" bash "$runner"
  else
    script -q -f -c "$command_text" "$transcript"
  fi 2>&1)"
  set -e
  [[ -f "$result" ]] || fail "interactive command did not finish: $output"
  status="$(cat "$result")"
  output="${output//$'\r'/}"
}

test_cli_terminal_feedback() {
  local subcommand
  prepare_interactive_test
  mkdir -p "$tmp/home/.codex-work"
  cat > "$tmp/bin/codex" <<'CODEX'
#!/usr/bin/env bash
[[ "${1:-}" != --version ]] || { printf 'fake-codex 1.0\n'; exit 0; }
printf 'stdout:%s\n' "$*"
printf 'stderr:codex\n' >&2
[[ "${FAKE_SIGNAL:-}" != TERM ]] || kill -TERM "$$"
exit "${FAKE_EXIT:-0}"
CODEX
  run_interactive '' env TERM=xterm-256color "$SCRIPT" cli work exec check
  assert_status 0
  assert_not_contains $'\033]'

  run_interactive '' env TERM=xterm-256color CODEX_PROFILE_TERMINAL_TITLE=1 "$SCRIPT" cli work
  assert_status 0
  assert_contains $'\033]2;work · workspace\007'
  assert_not_contains $'\033]9;'

  run_interactive '' env TERM=xterm-256color CODEX_PROFILE_NOTIFY=1 "$SCRIPT" cli work exec check
  assert_status 0
  assert_contains $'\033]9;work / workspace: finished\007'
  assert_not_contains $'\033]2;'

  run_cmd "${TEST_ENV[@]}" "$SCRIPT" workspace bind "$tmp/workspace" work
  assert_status 0
  run_interactive '' env TERM=xterm-256color CODEX_PROFILE_TERMINAL_TITLE=1 CODEX_PROFILE_NOTIFY=1 FAKE_EXIT=23 "$SCRIPT" run exec check
  assert_status 23
  assert_contains $'\033]2;work · workspace\007'
  assert_contains $'\033]9;work / workspace: failed (exit 23)\007'
  assert_contains 'stdout:exec check'
  assert_contains 'stderr:codex'

  run_interactive '' env TERM=xterm-256color CODEX_PROFILE_NOTIFY=1 FAKE_SIGNAL=TERM "$SCRIPT" cli work exec check
  assert_status 143
  assert_contains $'\033]9;work / workspace: failed (exit 143)\007'

  run_interactive '' env TERM=xterm-256color CODEX_PROFILE_TERMINAL_TITLE=0 CODEX_PROFILE_NOTIFY=0 "$SCRIPT" cli work exec check
  assert_status 0
  assert_not_contains $'\033]'

  for subcommand in '' login resume; do
    run_interactive '' env TERM=xterm-256color CODEX_PROFILE_NOTIFY=1 "$SCRIPT" cli work "$subcommand"
    assert_status 0
    assert_not_contains $'\033]9;'
  done
  run_interactive '' env TERM=dumb CODEX_PROFILE_TERMINAL_TITLE=1 CODEX_PROFILE_NOTIFY=1 "$SCRIPT" cli work exec check
  assert_status 0
  assert_not_contains $'\033]'
  run_cmd "${TEST_ENV[@]}" TERM=xterm-256color CODEX_PROFILE_TERMINAL_TITLE=1 CODEX_PROFILE_NOTIFY=1 FAKE_EXIT=23 "$SCRIPT" cli work exec check
  assert_status 23
  assert_not_contains $'\033]'
}

test_terminal_feedback_sanitizes_labels_and_preserves_streams() {
  prepare_interactive_test
  mkdir -p "$tmp/home/.codex-work"
  mv "$tmp/workspace" "$tmp/project"$'\007\033\302\235'"[31m"
  ln -s "$tmp/project"$'\007\033\302\235'"[31m" "$tmp/workspace"
  cat > "$tmp/bin/codex" <<'CODEX'
#!/usr/bin/env bash
[[ "${1:-}" != --version ]] || { printf 'fake-codex 1.0\n'; exit 0; }
IFS= read -r line
printf 'input:%s\n' "$line"
printf 'stderr:codex\n' >&2
exit 7
CODEX
  # shellcheck disable=SC2016 # Expanded inside the terminal child.
  run_interactive '' env TERM=xterm-256color CODEX_PROFILE_TERMINAL_TITLE=1 CODEX_PROFILE_NOTIFY=1 bash -c \
    'cd -P .; printf "hello\n" | "$1" cli work e - > "$2"' _ "$SCRIPT" "$tmp/stdout"
  assert_status 7
  assert_contains $'\033]2;work · project[31m\007'
  assert_contains $'\033]9;work / project[31m: failed (exit 7)\007'
  assert_not_contains $'\033[31m'
  [[ "$(cat "$tmp/stdout")" == 'input:hello' ]] || fail 'feedback corrupted stdout or stdin'
  assert_contains 'stderr:codex'
}

test_terminal_help_presentation() {
  local plain
  prepare_interactive_test
  run_interactive '' env -u NO_COLOR -u LC_ALL -u LC_CTYPE LANG=en_US.UTF-8 TERM=xterm-256color COLUMNS=80 "$SCRIPT"
  assert_status 0
  assert_contains '╭────────╮'
  assert_contains '█▀▀ █▀█ █▀▄ █▀▀ ▀▄▀'
  assert_contains 'P R O F I L E S'
  assert_contains $'\033[1;36m'
  assert_contains 'setup work'
  run_interactive '' env -u LC_ALL -u LC_CTYPE LANG=en_US.UTF-8 TERM=xterm-256color COLUMNS=80 NO_COLOR=1 "$SCRIPT"
  assert_status 0
  assert_contains '╭────────╮'
  assert_not_contains $'\033'
  run_interactive '' env TERM=xterm-256color COLUMNS=40 NO_COLOR=1 "$SCRIPT" help
  assert_status 0
  assert_not_contains '╭────────╮'
  assert_not_contains $'\033'
  assert_contains 'CODEX_PROFILE_UPGRADE_RELEASE_URL'
  plain="$output"
  printf '%s\n' "$plain" | LC_ALL=C awk 'length > 40 { exit 1 }' \
    || fail 'narrow help exceeds terminal width'
  # Test actual terminal dimensions with COLUMNS absent, not only its override.
  # shellcheck disable=SC2016 # The child expands the script argument.
  run_interactive '' env TERM=xterm-256color NO_COLOR=1 bash -c \
    'stty cols 40; unset COLUMNS; exec "$1" help' _ "$SCRIPT"
  assert_status 0
  assert_equals "$plain"
  run_interactive '' env TERM=xterm-256color COLUMNS=20 NO_COLOR=1 "$SCRIPT"
  assert_status 0
  printf '%s\n' "$output" | LC_ALL=C awk 'length > 20 { exit 1 }' \
    || fail 'compact header exceeds terminal width'
  run_interactive '' env TERM=dumb COLUMNS=80 "$SCRIPT"
  assert_status 0
  assert_not_contains '╭────────╮'
  assert_not_contains $'\033'
  run_interactive '' env TERM=xterm-256color LC_ALL=C COLUMNS=80 "$SCRIPT"
  assert_status 0
  assert_not_contains '╭────────╮'
  [[ ! -e "$tmp/config" && ! -e "$tmp/tool.log" ]] || fail 'help mutated profile state'
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
  run_interactive '\ny\n\n\n' "$SCRIPT" setup work
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
  run_interactive 'maybe\nn\n\n\n' "$SCRIPT" setup work
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
  run_interactive 'n\nn\n\n\n' env FAKE_SYSTEM=Darwin "$SCRIPT" setup work
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
  run_interactive 'n\ny\n'"$tmp"'/another workspace\ny\n\n' env FAKE_SYSTEM=Darwin "$SCRIPT" setup work
  assert_status 0
  [[ -x "$tmp/apps/ChatGPT work.app/Contents/MacOS/launch-profile" ]] || fail 'setup did not create launcher'
  run_cmd "${TEST_ENV[@]}" "$SCRIPT" workspace status --json "$tmp/another workspace"
  assert_status 0
  assert_contains '"profile":"work"'
}

test_picker_cancellation_status_reaches_all_commands
test_picker_keyboard_navigation_and_filter
test_picker_restores_terminal
test_picker_numeric_names_and_cancel
test_run_app_recovers_requested_workspace
test_run_recovery_preserves_streams_and_rejects_invalid_state
test_setup_terminal_integration_safe_append
test_setup_macos_bash_preserves_login_startup
test_picker_names_and_shell_default
test_welcome_project_and_shell_context
test_run_recovers_unbound_workspace
test_setup_terminal_integration
test_cli_terminal_feedback
test_terminal_feedback_sanitizes_labels_and_preserves_streams
test_terminal_help_presentation
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
