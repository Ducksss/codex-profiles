#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/test/lib/assertions.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
source "$ROOT_DIR/test/lib/cli-fixtures.sh"

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

test_completions_generate_shell_scripts() {
  run_cmd "$SCRIPT" help

  assert_status 0
  assert_contains "--instance"
  assert_contains "--share-with"
  assert_contains "workspace bind <path> <profile> [--force]"
  assert_contains "workspace guard [off|warn|strict]"
  assert_contains "run [--] [codex-args...]"
  assert_contains "run --app [workspace]"
  assert_contains "launcher create <profile>"
  assert_contains "CODEX_PROFILE_CONFIG_HOME"
  assert_contains "CODEX_PROFILE_LAUNCHER_ROOT"

  run_cmd "$SCRIPT" completions bash

  assert_status 0
  assert_contains "complete -F _codex_profile codex-profile codex-profiles"
  assert_contains 'compgen -W "app app-instance cli login init remove launcher workspace run status path env use logs clone-config list doctor completions shell-init upgrade version help"'
  assert_contains 'launcher_commands="create list path remove"'
  assert_contains 'blue green teal purple pink red orange graphite'
  assert_contains 'workspace_commands="bind unbind list status guard"'
  # shellcheck disable=SC2016 # matching literal generated completion text
  assert_contains 'compgen -W "$workspace_commands"'
  assert_contains 'compgen -W "--app"'
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
  assert_contains "app app-instance cli login init remove launcher workspace run status path env use logs clone-config list doctor completions shell-init upgrade version help"
  assert_contains "launcher_commands=(create list path remove)"
  assert_contains "launcher_colors=(blue green teal purple pink red orange graphite)"
  assert_contains "workspace_commands=(bind unbind list status guard)"
  assert_contains "run_flags=(--app)"
  assert_contains "workspace_json_flags=(--json)"
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
  assert_contains "-a 'app app-instance cli login init remove launcher workspace run status path env use logs clone-config list doctor completions shell-init upgrade version help'"
  assert_contains "-a 'create list path remove'"
  assert_contains "-a 'blue green teal purple pink red orange graphite'"
  assert_contains "-a 'bind unbind list status guard'"
  assert_contains "-l app"
  assert_contains "test (count (commandline -opc)) -eq 2"
  assert_contains "__fish_seen_subcommand_from bind; and test (count (commandline -opc)) -eq 4"
  assert_contains "-F"
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

test_logs_prints_path_and_contents
test_logs_prints_instance_path_and_contents
test_logs_reports_missing_log_file
test_completions_generate_shell_scripts
test_env_prints_posix_exports_for_profile
test_env_emits_fish_syntax
test_env_warns_to_stderr_without_polluting_stdout_when_uninitialized
test_env_rejects_invalid_profile_and_unsupported_shell
test_use_without_wrapper_explains_shell_init
test_shell_init_emits_use_wrapper
test_shell_init_use_activates_profile_in_current_shell
