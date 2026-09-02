#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/test/lib/assertions.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
source "$ROOT_DIR/test/lib/cli-fixtures.sh"

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
  mkdir -p "$tmp/home/.codex-personal"
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
  [[ -d "$tmp/home/.codex-personal" ]] || fail "cli removed the initialized profile home"

  rm -rf "$tmp"
}

test_login_passes_profile_home_and_login_args() {
  local tmp fake_codex
  tmp="$(mktemp -d)"
  fake_codex="$tmp/codex"
  mkdir -p "$tmp/home/.codex-work"
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
  [[ -d "$tmp/home/.codex-work" ]] || fail "login removed the initialized profile home"

  rm -rf "$tmp"
}

test_profile_commands_require_explicit_initialization() {
  local tmp fake_codex
  tmp="$(mktemp -d)"
  fake_codex="$tmp/codex"
  write_fake_codex "$fake_codex"

  run_cmd env HOME="$tmp/home" CODEX_CLI="$fake_codex" "$SCRIPT" cli typo exec check
  assert_status 1
  assert_contains "Profile 'typo' is not initialized"
  [[ ! -e "$tmp/home/.codex-typo" ]] || fail "cli created an uninitialized profile"

  run_cmd env HOME="$tmp/home" CODEX_CLI="$fake_codex" "$SCRIPT" login typo
  assert_status 1
  assert_contains "Profile 'typo' is not initialized"
  [[ ! -e "$tmp/home/.codex-typo" ]] || fail "login created an uninitialized profile"

  mkdir -p "$tmp/home/.codex-source"
  printf 'model = "gpt-5"\n' > "$tmp/home/.codex-source/config.toml"
  run_cmd env HOME="$tmp/home" "$SCRIPT" clone-config source typo
  assert_status 1
  assert_contains "Profile 'typo' is not initialized"
  [[ ! -e "$tmp/home/.codex-typo" ]] || fail "clone-config created an uninitialized target profile"

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

test_init_creates_private_profile_home_without_codex() {
  local tmp profile_home
  tmp="$(mktemp -d)"
  profile_home="$tmp/home/.codex-personal"

  run_cmd env HOME="$tmp/home" CODEX_CLI=/no/such/codex "$SCRIPT" init personal

  assert_status 0
  assert_contains "Initialized personal ($profile_home)"
  [[ -d "$profile_home" ]] || fail "init did not create profile home"
  [[ "$(mode_of "$profile_home")" == "700" ]] || fail "profile home is not private"
  [[ "$(cat "$tmp/home/.config/codex-profile/state-version")" == "1" ]] || \
    fail "init did not record the state schema version"
  [[ ! -e "$tmp/home/.config/codex-profile/mutation.lock" ]] || \
    fail "init left its state mutation lock behind"

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

test_remove_refuses_profiles_with_shared_configuration_dependents() {
  local tmp source_home target_home
  tmp="$(mktemp -d)"
  source_home="$tmp/home/.codex-personal"
  target_home="$tmp/home/.codex-personal-2"
  mkdir -p "$source_home"
  printf 'model = "gpt-5"\n' > "$source_home/config.toml"

  run_cmd env HOME="$tmp/home" "$SCRIPT" init personal-2 --share-with personal
  assert_status 0

  run_cmd env HOME="$tmp/home" "$SCRIPT" remove personal --yes
  assert_status 1
  assert_contains "shared configuration is still used by: personal-2"
  [[ -d "$source_home" && -L "$target_home/config.toml" ]] || \
    fail "refused source removal changed linked profiles"

  run_cmd env HOME="$tmp/home" "$SCRIPT" remove personal-2 --yes
  assert_status 0
  run_cmd env HOME="$tmp/home" "$SCRIPT" remove personal --yes
  assert_status 0
  [[ ! -e "$source_home" ]] || fail "source profile remained after its dependent was removed"

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

test_clone_config_copies_safe_files_and_never_auth_files() {
  local tmp source_home target_home
  tmp="$(mktemp -d)"
  source_home="$tmp/home/.codex-work"
  target_home="$tmp/home/.codex-personal"
  mkdir -p "$source_home/sessions" "$target_home"
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
  mkdir -p "$source_home" "$target_home"
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
  mkdir -p "$source_home" "$target_home"
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
test_profile_commands_require_explicit_initialization
test_invalid_profile_names_are_rejected
test_profile_path_mapping_only_special_cases_default
test_list_reports_initialized_managed_profiles_without_cli
test_init_creates_private_profile_home_without_codex
test_init_share_with_links_only_existing_allowlisted_config
test_init_share_with_rejects_invalid_sources_and_usage
test_init_share_with_refuses_every_existing_target_path
test_init_share_with_cleans_up_after_link_failure
test_remove_aborts_when_confirmation_does_not_match
test_remove_yes_deletes_profile_home
test_remove_yes_deletes_profiles_named_like_common_aliases
test_remove_refuses_profiles_with_shared_configuration_dependents
test_profile_home_symlinks_are_refused
test_clone_config_copies_safe_files_and_never_auth_files
test_clone_config_refuses_sensitive_looking_config
test_clone_config_refuses_symlinked_config_files
test_clone_config_refuses_symlinked_target_files_even_with_force
test_clone_config_refuses_to_overwrite_without_force
