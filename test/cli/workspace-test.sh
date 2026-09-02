#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/test/lib/assertions.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
source "$ROOT_DIR/test/lib/cli-fixtures.sh"

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

  rm -rf "$config"
  printf 'not a directory\n' > "$config"
  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace list --json
  assert_status 1
  assert_contains "Workspace config path is not a directory: $config"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    CODEX_CLI=/no/such/codex "$SCRIPT" doctor --json
  assert_status 0
  assert_contains '"guard_mode":null'
  assert_contains '"registry_valid":false'
  JSON_PAYLOAD="$output" node -e 'JSON.parse(process.env.JSON_PAYLOAD)'

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

test_workspace_mutations_are_serialized_and_versioned() {
  local tmp config first second fake_bin fake_mv real_mv first_pid second_pid first_status second_status
  tmp="$(mktemp -d)"
  tmp="$(cd "$tmp" && pwd -P)"
  config="$tmp/config"
  first="$tmp/first"
  second="$tmp/second"
  fake_bin="$tmp/bin"
  fake_mv="$fake_bin/mv"
  real_mv="$(command -v mv)"
  mkdir -p "$tmp/home/.codex-first" "$tmp/home/.codex-second" "$first" "$second" "$fake_bin"
  cat > "$fake_mv" <<'FAKE_MV'
#!/usr/bin/env bash
destination="${!#}"
if [[ "$destination" == */workspaces.tsv ]]; then
  sleep 1
fi
exec "${REAL_MV:?}" "$@"
FAKE_MV
  chmod 755 "$fake_mv"

  env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    PATH="$fake_bin:$PATH" REAL_MV="$real_mv" \
    "$SCRIPT" workspace bind "$first" first > "$tmp/first.out" 2> "$tmp/first.err" &
  first_pid=$!
  env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    PATH="$fake_bin:$PATH" REAL_MV="$real_mv" \
    "$SCRIPT" workspace bind "$second" second > "$tmp/second.out" 2> "$tmp/second.err" &
  second_pid=$!

  set +e
  wait "$first_pid"
  first_status=$?
  wait "$second_pid"
  second_status=$?
  set -e
  [[ "$first_status" -eq 0 ]] || fail "first concurrent bind failed: $(cat "$tmp/first.err")"
  [[ "$second_status" -eq 0 ]] || fail "second concurrent bind failed: $(cat "$tmp/second.err")"
  [[ "$(wc -l < "$config/workspaces.tsv" | tr -d ' ')" == "2" ]] || \
    fail "concurrent workspace mutations lost a binding"
  grep -Fqx "$first"$'\t'first "$config/workspaces.tsv" || fail "first concurrent binding is missing"
  grep -Fqx "$second"$'\t'second "$config/workspaces.tsv" || fail "second concurrent binding is missing"
  [[ "$(cat "$config/state-version")" == "1" ]] || fail "state schema version was not recorded"
  [[ "$(mode_of "$config/state-version")" == "600" ]] || fail "state version file is not private"
  [[ ! -e "$config/mutation.lock" ]] || fail "state mutation lock was not released"

  mkdir "$config/mutation.lock"
  printf '99999999\n' > "$config/mutation.lock/pid"
  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace guard strict
  assert_status 0
  assert_contains "Workspace guard mode: strict"
  [[ ! -e "$config/mutation.lock" ]] || fail "stale state mutation lock was not reclaimed"

  rm -rf "$tmp"
}

test_workspace_rejects_unsupported_state_schema() {
  local tmp config workspace fake_codex
  tmp="$(mktemp -d)"
  tmp="$(cd "$tmp" && pwd -P)"
  config="$tmp/config"
  workspace="$tmp/workspace"
  fake_codex="$tmp/codex"
  mkdir -p "$tmp/home/.codex-work" "$workspace" "$config"
  printf '99\n' > "$config/state-version"
  cat > "$fake_codex" <<'FAKE_CODEX'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  printf 'fake-codex 1.0\n'
  exit 0
fi
printf 'Logged out\n'
FAKE_CODEX
  chmod 755 "$fake_codex"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace list
  assert_status 1
  assert_contains "Unsupported state schema version '99'"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" launcher list --json
  assert_status 1
  assert_contains "Unsupported state schema version '99'"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace guard strict
  assert_status 1
  assert_contains "Unsupported state schema version '99'"
  [[ ! -e "$config/mutation.lock" ]] || fail "schema rejection left the mutation lock behind"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    CODEX_CLI="$fake_codex" "$SCRIPT" doctor --json
  assert_status 0
  assert_contains '"healthy":false'
  assert_contains '"schema_version":"99"'
  assert_contains '"registry_valid":false'
  JSON_PAYLOAD="$output" node -e 'JSON.parse(process.env.JSON_PAYLOAD)'

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    CODEX_CLI="$fake_codex" "$SCRIPT" doctor --json --check
  assert_status 1
  assert_contains '"healthy":false'

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

  # shellcheck disable=SC2016 # the child bash expands positional parameters
  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    CODEX_CLI="$fake_codex" bash -c \
    'cd "$1" && exec "$2" run -- exec "run tests"' _ "$service" "$SCRIPT"

  assert_status 0
  assert_contains "CODEX_HOME=$tmp/home/.codex-client"
  assert_contains "ARGS=exec run tests"

  # shellcheck disable=SC2016 # the child bash expands positional parameters
  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    CODEX_CLI="$fake_codex" bash -c \
    'cd "$1" && exec "$2" run -- --app' _ "$service" "$SCRIPT"

  assert_status 0
  assert_contains "ARGS=--app"

  # shellcheck disable=SC2016 # the child bash expands positional parameters
  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    CODEX_CLI="$fake_codex" bash -c \
    'cd "$1" && exec "$2" run --typo' _ "$service" "$SCRIPT"

  assert_status 1
  assert_contains "Usage: codex-profile run"
  assert_not_contains "ARGS=--typo"

  # shellcheck disable=SC2016 # the child bash expands positional parameters
  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    CODEX_CLI="$fake_codex" bash -c \
    'cd "$1" && exec "$2" run -- --typo' _ "$service" "$SCRIPT"

  assert_status 0
  assert_contains "ARGS=--typo"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    PATH="$fake_bin:$PATH" FAKE_TOOL_LOG="$tool_log" CHATGPT_APP="$chatgpt_app" \
    "$SCRIPT" run --app "$service"

  assert_status 0
  assert_contains "Launching ChatGPT for profile client"
  grep -Fqx "open -a $chatgpt_app files=$service args=--user-data-dir=$tmp/home/.codex-client/electron-user-data" "$tool_log" || \
    fail "run --app did not launch the signed app with the bound profile"

  # shellcheck disable=SC2016 # the child bash expands positional parameters
  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    CODEX_CLI="$fake_codex" bash -c \
    'cd "$1" && exec "$2" run' _ "$tmp" "$SCRIPT"

  assert_status 1
  assert_contains "No workspace profile is bound"
  assert_contains "workspace bind"

  rm -rf "$tmp"
}

test_workspace_resolution_errors_are_not_treated_as_unbound() {
  local tmp config missing
  tmp="$(mktemp -d)"
  tmp="$(cd "$tmp" && pwd -P)"
  config="$tmp/config"
  missing="$tmp/missing"
  mkdir -p "$tmp/home"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" workspace status --json "$missing"

  assert_status 1
  assert_contains "Workspace directory does not exist: $missing"
  assert_not_contains '"binding_path"'

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" \
    "$SCRIPT" run --app "$missing"

  assert_status 1
  assert_contains "Workspace directory does not exist: $missing"
  assert_not_contains "No workspace profile is bound to ''"

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
  # shellcheck disable=SC2016 # the child bash expands positional parameters
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
  # shellcheck disable=SC2016 # the child bash expands positional parameters
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
  # shellcheck disable=SC2016 # the child bash expands positional parameters
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
  # shellcheck disable=SC2016 # the child bash expands positional parameters
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
  # shellcheck disable=SC2016 # the child bash expands positional parameters
  env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$config" CODEX_CLI="$fake_codex" \
    FAKE_CODEX_MARKER="$marker" bash -c \
    'cd "$1" && exec "$2" cli personal exec allowed' _ "$service" "$SCRIPT" \
    > "$out" 2> "$err"
  status=$?
  set -e
  [[ "$status" -eq 0 ]] || fail "off-mode CLI mismatch should run"
  [[ ! -s "$err" ]] || fail "off-mode CLI mismatch emitted a warning"

  # shellcheck disable=SC2016 # the child bash expands positional parameters
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

test_workspace_bind_list_status_and_nested_resolution
test_workspace_bind_rejects_unsafe_state_and_reports_stale_bindings
test_workspace_uses_xdg_config_and_manages_guard_mode
test_workspace_mutations_are_serialized_and_versioned
test_workspace_rejects_unsupported_state_schema
test_workspace_run_routes_cli_and_signed_app
test_workspace_resolution_errors_are_not_treated_as_unbound
test_workspace_guards_explicit_profile_commands
test_remove_cleans_workspace_bindings_without_touching_projects
test_doctor_reports_workspace_binding_health_in_human_and_json_output
