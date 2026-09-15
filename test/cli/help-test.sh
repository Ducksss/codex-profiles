#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/test/lib/assertions.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
source "$ROOT_DIR/test/lib/cli-fixtures.sh"

help_cmd() {
  run_cmd env HOME="$TMP_ROOT/empty-home" CODEX_PROFILE_CONFIG_HOME="$TMP_ROOT/empty-state" \
    CODEX_CLI="$TMP_ROOT/forbidden-codex" CODEX_PROFILE_NO_UPDATE_CHECK=1 TERM=dumb \
    "$SCRIPT" "$@"
}

test_command_help_is_scoped_and_read_only() {
  local topic flag reference
  cat > "$TMP_ROOT/forbidden-codex" <<'FORBIDDEN_CODEX'
#!/usr/bin/env bash
printf '%s\n' 'upstream CLI must not run for help' >&2
exit 87
FORBIDDEN_CODEX
  chmod 755 "$TMP_ROOT/forbidden-codex"

  for topic in app app-instance cli login run setup init detach clone-config remove list path \
    workspace launcher status doctor logs upgrade version env use completions shell-init help; do
    help_cmd help "$topic"
    assert_status 0
    assert_contains "Usage: codex-profile $topic"
    assert_contains 'Examples:'
    assert_not_contains 'Environment:'
    assert_not_contains $'\033'
    reference="$output"
    for flag in --help -h; do
      help_cmd "$topic" "$flag"
      assert_status 0
      assert_equals "$reference"
    done
    printf '%s\n' "$output" | LC_ALL=C awk 'length > 80 { exit 1 }' \
      || fail "$topic help exceeds 80 columns"
  done
  [[ ! -e "$TMP_ROOT/empty-home" ]] || fail 'help created a home directory'
  [[ ! -e "$TMP_ROOT/empty-state" ]] || fail 'help created control state'

  help_cmd app --help
  assert_contains 'stock session'
  assert_contains 'separate local state'
  assert_contains 'codex-profile app work ~/Dev/project'
  assert_not_contains 'upgrade [--dry-run]'
  help_cmd list --help
  assert_contains '--details'
  assert_contains 'bound projects'
  help_cmd run --help
  assert_contains 'codex-profile run -- --help'
}

test_nested_command_help() {
  local topic subcommand reference flag
  for topic in workspace launcher; do
    if [[ "$topic" == workspace ]]; then
      set -- bind unbind list status guard
    else
      set -- create list path remove
    fi
    for subcommand in "$@"; do
      help_cmd help "$topic" "$subcommand"
      assert_status 0
      assert_contains "Usage: codex-profile $topic $subcommand"
      assert_contains 'Examples:'
      reference="$output"
      for flag in --help -h; do
        help_cmd "$topic" "$subcommand" "$flag"
        assert_status 0
        assert_equals "$reference"
      done
    done
  done
  help_cmd workspace guard --help
  assert_contains 'strict'
  assert_contains 'Refuse mismatched profiles.'
  help_cmd launcher create --help
  assert_contains '--name <display-name>'
  assert_contains '--color <color>'
  assert_contains '--force'
}

test_unknown_help_topics_fail() {
  help_cmd help nonexistent
  assert_status 1
  assert_contains 'Unknown help topic'
  help_cmd help workspace nonexistent
  assert_status 1
  assert_contains 'Unknown help topic'
  help_cmd launcher nonexistent --help
  assert_status 1
  assert_contains 'Unknown help topic'
  help_cmd help app extra
  assert_status 1
  assert_contains 'Unknown help topic'
  help_cmd help workspace bind extra
  assert_status 1
  assert_contains 'Usage:'
}

test_upstream_help_is_forwarded_after_profile_or_separator() {
  local home="$TMP_ROOT/forward-home" state="$TMP_ROOT/forward-state" project="$TMP_ROOT/project"
  mkdir -p "$home/.codex-work" "$project"
  write_fake_codex "$TMP_ROOT/codex"
  run_cmd env HOME="$home" CODEX_PROFILE_CONFIG_HOME="$state" CODEX_PROFILE_NO_UPDATE_CHECK=1 \
    "$SCRIPT" workspace bind "$project" work
  assert_status 0
  run_cmd env HOME="$home" CODEX_PROFILE_CONFIG_HOME="$state" CODEX_CLI="$TMP_ROOT/codex" \
    CODEX_PROFILE_NO_UPDATE_CHECK=1 "$SCRIPT" cli work --help
  assert_status 0
  assert_equals '--help'
  run_cmd env HOME="$home" CODEX_PROFILE_CONFIG_HOME="$state" CODEX_CLI="$TMP_ROOT/codex" \
    CODEX_PROFILE_NO_UPDATE_CHECK=1 "$SCRIPT" login work --help
  assert_status 0
  assert_equals 'login --help'
  (
    cd "$project"
    run_cmd env HOME="$home" CODEX_PROFILE_CONFIG_HOME="$state" CODEX_CLI="$TMP_ROOT/codex" \
      CODEX_PROFILE_NO_UPDATE_CHECK=1 "$SCRIPT" run -- --help
    assert_status 0
    assert_equals '--help'
    run_cmd env HOME="$home" CODEX_PROFILE_CONFIG_HOME="$state" CODEX_CLI="$TMP_ROOT/codex" \
      CODEX_PROFILE_NO_UPDATE_CHECK=1 "$SCRIPT" run exec --help
    assert_status 0
    assert_equals 'exec --help'
  )
}

test_shell_wrappers_keep_use_help() {
  local shell script
  for shell in bash zsh fish; do
    command -v "$shell" >/dev/null 2>&1 || continue
    if [[ "$shell" == fish ]]; then
      # shellcheck disable=SC2016 # evaluated by the selected shell
      script='"$SCRIPT" shell-init fish | source; codex-profile use --help; or exit $status; test -z "$CODEX_PROFILE_NAME"'
    else
      # shellcheck disable=SC2016 # evaluated by the selected shell
      script='eval "$("$SCRIPT" shell-init "$HELP_SHELL")"; codex-profile use --help; result=$?; [[ "$result" -eq 0 && -z "${CODEX_PROFILE_NAME:-}" ]]'
    fi
    run_cmd env HOME="$TMP_ROOT/empty-home" CODEX_PROFILE_CONFIG_HOME="$TMP_ROOT/empty-state" \
      CODEX_PROFILE_NO_UPDATE_CHECK=1 TERM=dumb CODEX_PROFILE_NAME= CODEX_HOME= \
      PATH="$ROOT_DIR/bin:$PATH" SCRIPT="$SCRIPT" HELP_SHELL="$shell" "$shell" -c "$script"
    assert_status 0
    assert_contains 'Usage: codex-profile use <profile>'
    assert_not_contains 'Usage: codex-profile env'
  done
}

test_command_help_is_scoped_and_read_only
test_nested_command_help
test_unknown_help_topics_fail
test_upstream_help_is_forwarded_after_profile_or_separator
test_shell_wrappers_keep_use_help
printf '%s\n' 'Command help tests passed.'
