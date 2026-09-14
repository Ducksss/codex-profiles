#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/test/lib/assertions.sh"
TMP_ROOT="$(mktemp -d /tmp/codex-overview.XXXXXX)"
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
source "$ROOT_DIR/test/lib/cli-fixtures.sh"
HOST_SYSTEM="$(uname -s)"

prepare_overview_test() {
  tmp="$(mktemp -d "$TMP_ROOT/case.XXXXXX")"
  tmp="$(cd "$tmp" && pwd -P)"
  mkdir -p "$tmp/home" "$tmp/bin" "$tmp/workspace"
  cat > "$tmp/bin/codex" <<'CODEX'
#!/usr/bin/env bash
printf 'unexpected codex call: %s\n' "$*" >> "$FAKE_TOOL_LOG"
exit 99
CODEX
  cat > "$tmp/bin/uname" <<'UNAME'
#!/usr/bin/env bash
printf '%s\n' "${FAKE_SYSTEM:-Linux}"
UNAME
  chmod 755 "$tmp/bin/codex" "$tmp/bin/uname"
  TEST_ENV=(env HOME="$tmp/home" PATH="$tmp/bin:$PATH"
    CODEX_HOME="$tmp/home/.codex" CODEX_PROFILE_NAME=''
    CODEX_CLI="$tmp/bin/codex" CODEX_PROFILE_CONFIG_HOME="$tmp/config"
    CODEX_PROFILE_LAUNCHER_ROOT="$tmp/apps" CODEX_PROFILE_NO_UPDATE_CHECK=1
    TERM=xterm-256color NO_COLOR=1 LC_ALL=C COLUMNS=180
    FAKE_TOOL_LOG="$tmp/tool.log")
}

# No input is needed for these overviews. Record status because BSD script
# does not propagate the child exit code like util-linux script does.
run_overview_tty() {
  local runner="$tmp/overview-runner" result="$tmp/overview-status" command_text
  {
    printf '#!/usr/bin/env bash\n'
    printf 'cd -P %q || exit 1\n' "$tmp/workspace"
    printf '%q ' "${TEST_ENV[@]}" "$@"
    printf '\nprintf "%%s\\n" "$?" > %q\n' "$result"
  } > "$runner"
  printf -v command_text 'bash %q' "$runner"
  if [[ "$HOST_SYSTEM" == Darwin ]]; then
    run_cmd script -q /dev/null bash "$runner" </dev/null
  else
    run_cmd script -q -c "$command_text" /dev/null </dev/null
  fi
  [[ -f "$result" ]] || fail "overview did not finish: $output"
  status="$(cat "$result")"
  output="${output//$'\r'/}"
}

assert_no_probe() {
  [[ ! -e "$tmp/tool.log" ]] || fail 'overview called Codex or probed login'
}

card_for() {
  printf '%s\n' "$output" | awk -v profile="$1" '
    { heading = $0; sub(/^ +/, "", heading) }
    heading == profile ":" { inside = 1; next }
    /^  [^ ].*:$/ { inside = 0 }
    inside { $1 = $1; printf "%s ", $0 }
  '
}

write_launcher_state() {
  local profile="$1" name="$2"
  mkdir -p "$tmp/config/launchers"
  printf '%s\n%s\nblue\n%s\n' "$profile" "$name" "$tmp/apps/$name.app" \
    > "$tmp/config/launchers/$profile.state"
}

test_welcome_profiles_guard_and_existing_context() {
  local mode
  prepare_overview_test
  mkdir -p "$tmp/home/.codex-personal" "$tmp/home/.codex-work" "$tmp/outside"
  ln -s "$tmp/outside" "$tmp/home/.codex-linked"
  run_cmd "${TEST_ENV[@]}" "$SCRIPT" workspace bind "$tmp/workspace" work
  assert_status 0
  for mode in warn off strict; do
    run_cmd "${TEST_ENV[@]}" "$SCRIPT" workspace guard "$mode"
    assert_status 0
    run_overview_tty env CODEX_PROFILE_NAME=personal CODEX_HOME="$tmp/home/.codex-personal" "$SCRIPT"
    assert_status 0
    assert_contains 'Profiles'
    assert_contains 'personal'
    assert_contains 'work'
    assert_not_contains 'linked'
    assert_contains 'Guard mode'
    assert_contains "$mode"
    assert_contains 'Project'
    assert_contains 'Bound profile'
    assert_contains 'Shell profile'
    assert_contains 'Launch this project:'
    assert_contains 'codex-profile run'
  done
  assert_no_probe
}

test_static_welcome_and_empty_profile_context() {
  prepare_overview_test
  run_overview_tty "$SCRIPT"
  assert_status 0
  assert_contains 'Profiles'
  assert_contains 'None; run codex-profile setup work'
  assert_contains 'warn'
  [[ ! -e "$tmp/config" ]] || fail 'welcome initialized configuration'

  run_cmd "${TEST_ENV[@]}" "$SCRIPT"
  assert_status 0
  assert_not_contains 'Guard mode'
  assert_not_contains 'None; run codex-profile setup work'
  assert_not_contains 'Bound profile'
  run_overview_tty env TERM=dumb "$SCRIPT"
  assert_status 0
  assert_not_contains 'Guard mode'
  assert_not_contains 'Bound profile'
  assert_no_probe
}

test_details_group_homes_and_all_workspaces_without_probes() {
  local work_card personal_card
  prepare_overview_test
  mkdir -p "$tmp/home/.codex-work" "$tmp/home/.codex-personal" "$tmp/second project" "$tmp/outside"
  ln -s "$tmp/outside" "$tmp/home/.codex-linked"
  run_cmd "${TEST_ENV[@]}" "$SCRIPT" workspace bind "$tmp/workspace" work
  assert_status 0
  run_cmd "${TEST_ENV[@]}" "$SCRIPT" workspace bind "$tmp/second project" work
  assert_status 0
  rmdir "$tmp/second project"
  run_cmd "${TEST_ENV[@]}" "$SCRIPT" list
  assert_status 0
  assert_equals $'personal\nwork'
  run_cmd "${TEST_ENV[@]}" "$SCRIPT" list --details
  assert_status 0
  assert_contains 'personal:'
  assert_contains 'work:'
  assert_not_contains 'linked'
  work_card="$(card_for work)"
  personal_card="$(card_for personal)"
  assert_contains "$work_card" "Home" 'work home label'
  assert_contains "$work_card" "$tmp/home/.codex-work" 'work home'
  assert_contains "$work_card" 'Workspaces' 'workspaces label'
  assert_contains "$work_card" "$tmp/workspace" 'first binding'
  assert_contains "$work_card" "$tmp/second project" 'missing bound directory stays visible'
  assert_contains "$personal_card" "$tmp/home/.codex-personal" 'personal home'
  assert_not_contains "$personal_card" "$tmp/workspace" 'work bindings do not leak to personal'
  assert_contains "$work_card" 'Unsupported' 'nonmacOS launcher status'
  assert_no_probe
}

test_details_report_available_missing_stale_and_absent_launchers() {
  local before after
  prepare_overview_test
  mkdir -p "$tmp/home/.codex-available" "$tmp/home/.codex-missing" "$tmp/home/.codex-stale" "$tmp/home/.codex-none" "$tmp/home/.codex-unmanaged" "$tmp/home/.codex-linked"
  write_launcher_state available 'ChatGPT Available'
  write_launcher_state missing 'ChatGPT Missing'
  write_launcher_state stale 'ChatGPT Stale'
  write_launcher_state unmanaged 'ChatGPT Unmanaged'
  mkdir -p "$tmp/apps/ChatGPT Available.app/Contents/Resources/codex-profile" \
    "$tmp/apps/ChatGPT Available.app/Contents/MacOS"
  printf 'available\n' > "$tmp/apps/ChatGPT Available.app/Contents/Resources/codex-profile/profile"
  printf '#!/bin/sh\nexit 99\n' > "$tmp/apps/ChatGPT Available.app/Contents/MacOS/launch-profile"
  chmod 755 "$tmp/apps/ChatGPT Available.app/Contents/MacOS/launch-profile"
  printf 'malformed state\n' > "$tmp/config/launchers/stale.state"
  mkdir -p "$tmp/apps/ChatGPT Unmanaged.app/Contents/Resources/codex-profile"
  printf 'someone-else\n' > "$tmp/apps/ChatGPT Unmanaged.app/Contents/Resources/codex-profile/profile"
  printf 'private target fixture\n' > "$tmp/outside-state"
  ln -s "$tmp/outside-state" "$tmp/config/launchers/linked.state"
  before="$(find "$tmp/home" "$tmp/config" "$tmp/apps" -print -type f -exec cksum {} \; | LC_ALL=C sort)"
  run_cmd "${TEST_ENV[@]}" FAKE_SYSTEM=Darwin "$SCRIPT" list --details
  assert_status 0
  assert_contains "$(card_for available)" 'Available' 'managed launcher availability'
  assert_contains "$(card_for available)" "$tmp/apps/ChatGPT Available.app" 'managed launcher path'
  assert_contains "$(card_for missing)" 'Missing' 'missing launcher availability'
  assert_contains "$(card_for missing)" "$tmp/apps/ChatGPT Missing.app" 'missing launcher path'
  assert_contains "$(card_for stale)" 'Stale' 'malformed state availability'
  assert_contains "$(card_for none)" 'None' 'absent launcher availability'
  assert_contains "$(card_for unmanaged)" 'Stale or unmanaged' 'wrong-profile launcher rejected'
  assert_contains "$(card_for linked)" 'Stale' 'linked state rejected'
  assert_not_contains 'private target fixture'
  after="$(find "$tmp/home" "$tmp/config" "$tmp/apps" -print -type f -exec cksum {} \; | LC_ALL=C sort)"
  assert_equals 'read-only launcher overview' "$before" "$after"
  assert_no_probe
}

test_details_empty_and_invalid_arguments() {
  prepare_overview_test
  run_cmd "${TEST_ENV[@]}" "$SCRIPT" list --details
  assert_status 0
  assert_contains 'No initialized profiles'
  [[ ! -e "$tmp/config" && ! -e "$tmp/apps" ]] || fail 'empty overview initialized configuration'
  run_cmd "${TEST_ENV[@]}" "$SCRIPT" list
  assert_status 0
  assert_equals ''
  run_cmd "${TEST_ENV[@]}" "$SCRIPT" list --details unexpected
  assert_status 1
  assert_contains 'Usage:'
  run_cmd "${TEST_ENV[@]}" "$SCRIPT" list --unknown
  assert_status 1
  assert_contains 'Usage:'
  assert_no_probe
}

test_overview_sanitizes_terminal_controls() {
  local dangerous
  prepare_overview_test
  dangerous="$tmp/project"$'\007\033[31m'
  mkdir -p "$tmp/home/.codex-work" "$dangerous"
  run_cmd "${TEST_ENV[@]}" "$SCRIPT" workspace bind "$dangerous" work
  assert_status 0
  run_cmd "${TEST_ENV[@]}" "$SCRIPT" list --details
  assert_status 0
  assert_not_contains $'\007'
  assert_not_contains $'\033'
  assert_contains "$tmp/project"
  rmdir "$tmp/workspace"
  ln -s "$dangerous" "$tmp/workspace"
  run_overview_tty "$SCRIPT"
  assert_status 0
  assert_not_contains $'\007'
  assert_not_contains $'\033'
  assert_no_probe
}

test_details_fit_narrow_terminal_without_a_banner() {
  prepare_overview_test
  mkdir -p "$tmp/home/.codex-work" "$tmp/home/.codex-personal"
  run_cmd "${TEST_ENV[@]}" "$SCRIPT" workspace bind "$tmp/workspace" work
  assert_status 0
  # A wide UTF-8 terminal would display the banner unless details suppress it.
  run_overview_tty env -u LC_ALL -u LC_CTYPE LANG=en_US.UTF-8 "$SCRIPT" list --details
  assert_status 0
  assert_not_contains '╭────────╮'
  assert_not_contains 'codex-profiles'
  assert_not_contains $'\033'
  # shellcheck disable=SC2016 # Expanded in the terminal child.
  run_overview_tty bash -c 'stty cols 40; unset COLUMNS; exec "$@"' _ "$SCRIPT" list --details
  assert_status 0
  assert_not_contains 'codex-profiles'
  assert_not_contains $'\033'
  printf '%s\n' "$output" | LC_ALL=C awk 'length > 40 { exit 1 }' \
    || fail 'detailed cards exceed the actual 40-column terminal width'
  [[ "$(printf '%s\n' "$output" | grep -c '^  work:$')" -eq 1 ]] || fail 'work heading is missing or repeated'
  [[ "$(printf '%s\n' "$output" | grep -c '^  personal:$')" -eq 1 ]] || fail 'personal heading is missing or repeated'
  assert_contains "$(card_for work)" 'Workspaces' 'narrow work card retains bindings'
  assert_contains "$(card_for personal)" 'Launcher' 'narrow personal card retains launcher status'
  assert_no_probe
}

test_details_reject_unsafe_registry_without_mutation() {
  local kind before after
  for kind in malformed linked; do
    prepare_overview_test
    mkdir -p "$tmp/home/.codex-work" "$tmp/config"
    printf 'private malformed registry fixture\n' > "$tmp/outside-registry"
    if [[ "$kind" == linked ]]; then
      ln -s "$tmp/outside-registry" "$tmp/config/workspaces.tsv"
    else
      cp "$tmp/outside-registry" "$tmp/config/workspaces.tsv"
    fi
    before="$(find "$tmp/home" "$tmp/config" "$tmp/outside-registry" -print -type f -exec cksum {} \; | LC_ALL=C sort)"
    run_cmd "${TEST_ENV[@]}" "$SCRIPT" list --details
    assert_status 1
    if [[ "$kind" == linked ]]; then
      assert_contains 'Refusing symlinked workspace registry'
    else
      assert_contains 'Malformed workspace registry'
    fi
    assert_not_contains 'private malformed registry fixture'
    assert_not_contains 'work:'
    after="$(find "$tmp/home" "$tmp/config" "$tmp/outside-registry" -print -type f -exec cksum {} \; | LC_ALL=C sort)"
    assert_equals "read-only $kind registry rejection" "$before" "$after"
    assert_no_probe
  done
}

test_welcome_profiles_guard_and_existing_context
test_static_welcome_and_empty_profile_context
test_details_group_homes_and_all_workspaces_without_probes
test_details_report_available_missing_stale_and_absent_launchers
test_details_empty_and_invalid_arguments
test_overview_sanitizes_terminal_controls
test_details_fit_narrow_terminal_without_a_banner
test_details_reject_unsafe_registry_without_mutation
