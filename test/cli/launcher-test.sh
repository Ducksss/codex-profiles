#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/test/lib/assertions.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
source "$ROOT_DIR/test/lib/cli-fixtures.sh"

write_fake_launcher_tools() {
  local fake_bin="$1"

  cat > "$fake_bin/uname" <<'FAKE_UNAME'
#!/usr/bin/env bash
printf 'Darwin\n'
FAKE_UNAME
  chmod 755 "$fake_bin/uname"

  cat > "$fake_bin/sips" <<'FAKE_SIPS'
#!/usr/bin/env bash
destination=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -o|--out) destination="$2"; shift ;;
  esac
  shift
done
[[ -n "$destination" ]] || exit 2
printf 'fake png\n' > "$destination"
FAKE_SIPS
  chmod 755 "$fake_bin/sips"

cat > "$fake_bin/qlmanage" <<'FAKE_QLMANAGE'
#!/usr/bin/env bash
[[ -z "${FAKE_QLMANAGE_EXIT:-}" ]] || exit "$FAKE_QLMANAGE_EXIT"
output_dir=""
svg=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -o) output_dir="$2"; shift ;;
    *.svg) svg="$1" ;;
  esac
  shift
done
[[ -n "$output_dir" && -n "$svg" ]] || exit 2
printf 'fake tinted png\n' > "$output_dir/${svg##*/}.png"
FAKE_QLMANAGE
  chmod 755 "$fake_bin/qlmanage"

  cat > "$fake_bin/iconutil" <<'FAKE_ICONUTIL'
#!/usr/bin/env bash
destination=""
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -o) destination="$2"; shift ;;
  esac
  shift
done
[[ -n "$destination" ]] || exit 2
printf 'fake icns\n' > "$destination"
FAKE_ICONUTIL
  chmod 755 "$fake_bin/iconutil"
}

launcher_env() {
  local tmp="$1"
  shift
  env HOME="$tmp/home" \
    PATH="$tmp/bin:$PATH" \
    CHATGPT_APP="$tmp/ChatGPT.app" \
    CODEX_PROFILE_CONFIG_HOME="$tmp/config" \
    CODEX_PROFILE_LAUNCHER_ROOT="$tmp/apps" \
    CODEX_PROFILE_NO_UPDATE_CHECK=1 \
    "$@"
}

prepare_launcher_test() {
  local tmp="$1" profile="$2"

  mkdir -p "$tmp/home/.codex-$profile"
  write_fake_chatgpt_app_bundle "$tmp/ChatGPT.app" "unused"
  write_fake_chatgpt_open_tools "$tmp/bin"
  write_fake_launcher_tools "$tmp/bin"
}

test_launcher_create_list_and_path_are_deterministic() {
  local tmp app before after
  tmp="$(mktemp -d)"
  app="$tmp/apps/ChatGPT Personal.app"
  prepare_launcher_test "$tmp" personal
  before="$(cksum "$tmp/ChatGPT.app/Contents/Info.plist" "$tmp/ChatGPT.app/Contents/Resources/icon-chatgpt.png")"

  run_cmd launcher_env "$tmp" "$SCRIPT" launcher create personal --name "ChatGPT Personal" --color blue

  assert_status 0
  assert_contains "Created launcher for personal: $app"
  [[ -x "$app/Contents/MacOS/launch-profile" ]] || fail "launcher executable is missing"
  [[ -f "$app/Contents/Resources/AppIcon.icns" ]] || fail "launcher icon is missing"
  grep -Fq '<string>ChatGPT Personal</string>' "$app/Contents/Info.plist" || fail "display name missing from plist"
  grep -Fq '<string>io.github.ducksss.codex-profile.launcher.p706572736f6e616c</string>' "$app/Contents/Info.plist" || fail "bundle identifier is not deterministic"
  grep -Fq "app 'personal' \"\$HOME\"" "$app/Contents/MacOS/launch-profile" || fail "launcher does not route to the selected profile"
  after="$(cksum "$tmp/ChatGPT.app/Contents/Info.plist" "$tmp/ChatGPT.app/Contents/Resources/icon-chatgpt.png")"
  [[ "$before" == "$after" ]] || fail "source ChatGPT app changed"

  run_cmd launcher_env "$tmp" "$SCRIPT" launcher path personal
  assert_status 0
  assert_equals "$app"

  run_cmd launcher_env "$tmp" "$SCRIPT" launcher list --json
  assert_status 0
  assert_contains '"profile":"personal"'
  assert_contains '"name":"ChatGPT Personal"'
  assert_contains '"color":"blue"'

  rm -rf "$tmp"
}

test_launcher_create_is_idempotent_and_force_replaces_managed_bundle() {
  local tmp old_app new_app
  tmp="$(mktemp -d)"
  old_app="$tmp/apps/ChatGPT Work.app"
  new_app="$tmp/apps/ChatGPT Office.app"
  prepare_launcher_test "$tmp" work

  run_cmd launcher_env "$tmp" "$SCRIPT" launcher create work --name "ChatGPT Work" --color green
  assert_status 0
  run_cmd launcher_env "$tmp" "$SCRIPT" launcher create work --name "ChatGPT Work" --color green
  assert_status 0
  assert_contains "Already created launcher for work"

  printf 'tampered\n' > "$old_app/Contents/Resources/codex-profile/color"
  run_cmd launcher_env "$tmp" "$SCRIPT" launcher create work --name "ChatGPT Work" --color green --force
  assert_status 0
  [[ "$(cat "$old_app/Contents/Resources/codex-profile/color")" == "green" ]] || fail "force did not rebuild an otherwise identical launcher"

  run_cmd launcher_env "$tmp" "$SCRIPT" launcher create work --name "ChatGPT Office" --color purple
  assert_status 1
  assert_contains "use --force to replace it"

  run_cmd launcher_env "$tmp" "$SCRIPT" launcher create work --name "ChatGPT Office" --color purple --force
  assert_status 0
  [[ ! -e "$old_app" ]] || fail "force replacement kept the old launcher"
  [[ -d "$new_app" ]] || fail "force replacement did not create the new launcher"
  [[ "$(cat "$new_app/Contents/Resources/codex-profile/color")" == "purple" ]] || fail "force replacement kept the old color"

  rm -rf "$tmp"
}

test_launcher_refuses_invalid_inputs_and_unmanaged_collisions() {
  local tmp
  tmp="$(mktemp -d)"
  prepare_launcher_test "$tmp" personal

  run_cmd launcher_env "$tmp" "$SCRIPT" launcher create missing --name "ChatGPT Missing" --color blue
  assert_status 1
  assert_contains "is not initialized"

  run_cmd launcher_env "$tmp" "$SCRIPT" launcher create personal --name "../Unsafe" --color blue
  assert_status 1
  assert_contains "Invalid launcher name"

  run_cmd launcher_env "$tmp" "$SCRIPT" launcher create personal --name "ChatGPT Personal" --color cyan
  assert_status 1
  assert_contains "Unsupported launcher color 'cyan'"

  mkdir -p "$tmp/apps/ChatGPT Personal.app"
  run_cmd launcher_env "$tmp" "$SCRIPT" launcher create personal --name "ChatGPT Personal" --color blue
  assert_status 1
  assert_contains "Refusing to replace unmanaged app"

  rm -rf "$tmp"
}

test_launcher_cleans_up_a_failed_icon_build() {
  local tmp
  tmp="$(mktemp -d)"
  prepare_launcher_test "$tmp" personal

  run_cmd launcher_env "$tmp" env FAKE_QLMANAGE_EXIT=71 \
    "$SCRIPT" launcher create personal --name "ChatGPT Personal" --color blue

  assert_status 1
  assert_contains "Cannot build launcher for profile 'personal'"
  [[ ! -e "$tmp/apps/ChatGPT Personal.app" ]] || fail "failed build installed a launcher"
  if find "$tmp/apps" -maxdepth 1 -name '.codex-profile-launcher.*' | grep -q .; then
    fail "failed build left a temporary launcher directory"
  fi

  rm -rf "$tmp"
}

test_launcher_remove_preserves_profile_data() {
  local tmp profile_home
  tmp="$(mktemp -d)"
  profile_home="$tmp/home/.codex-personal"
  prepare_launcher_test "$tmp" personal
  printf 'keep me\n' > "$profile_home/auth.json"
  run_cmd launcher_env "$tmp" "$SCRIPT" launcher create personal --name "ChatGPT Personal" --color blue
  assert_status 0

  run_cmd launcher_env "$tmp" "$SCRIPT" launcher remove personal --yes
  assert_status 0
  assert_contains "Profile data was preserved"
  [[ ! -e "$tmp/apps/ChatGPT Personal.app" ]] || fail "launcher bundle was not removed"
  [[ -f "$profile_home/auth.json" ]] || fail "profile data was removed with launcher"

  rm -rf "$tmp"
}

test_profile_remove_refuses_managed_launcher_orphans() {
  local tmp profile_home app
  tmp="$(mktemp -d)"
  profile_home="$tmp/home/.codex-personal"
  app="$tmp/apps/ChatGPT Personal.app"
  prepare_launcher_test "$tmp" personal

  run_cmd launcher_env "$tmp" "$SCRIPT" launcher create personal --name "ChatGPT Personal" --color blue
  assert_status 0

  run_cmd launcher_env "$tmp" "$SCRIPT" remove personal --yes
  assert_status 1
  assert_contains "managed launcher exists at $app"
  assert_contains "launcher remove personal"
  [[ -d "$profile_home" && -d "$app" ]] || fail "refused profile removal changed profile or launcher data"

  run_cmd launcher_env "$tmp" "$SCRIPT" launcher remove personal --yes
  assert_status 0
  run_cmd launcher_env "$tmp" "$SCRIPT" remove personal --yes
  assert_status 0
  [[ ! -e "$profile_home" && ! -e "$app" ]] || fail "explicit launcher and profile removal left managed state"

  rm -rf "$tmp"
}

test_launcher_recovers_after_the_bundle_is_deleted_outside_the_cli() {
  local tmp stale_app healthy_app json
  tmp="$(mktemp -d)"
  stale_app="$tmp/apps/Stale App.app"
  healthy_app="$tmp/apps/Healthy App.app"
  prepare_launcher_test "$tmp" personal
  mkdir -p "$tmp/home/.codex-work"

  run_cmd launcher_env "$tmp" "$SCRIPT" launcher create personal --name "Stale App" --color blue
  assert_status 0
  run_cmd launcher_env "$tmp" "$SCRIPT" launcher create work --name "Healthy App" --color red
  assert_status 0

  # The ordinary way a macOS user removes an app: drag the bundle to the Trash.
  rm -rf "$stale_app"

  # One stale record must not hide the launchers that are still healthy.
  run_cmd launcher_env "$tmp" "$SCRIPT" launcher list
  assert_status 0
  assert_contains "Skipping personal"
  assert_contains "work"$'\t'"Healthy App"

  # --json keeps stdout parseable even while a record is stale.
  json="$(launcher_env "$tmp" "$SCRIPT" launcher list --json 2> /dev/null)"
  assert_equals "stale launcher json" '[{"profile":"work","name":"Healthy App","color":"red","path":"'"$healthy_app"'"}]' "$json"

  # path explains how to recover instead of dead-ending.
  run_cmd launcher_env "$tmp" "$SCRIPT" launcher path personal
  assert_status 1
  assert_contains "to recreate it"

  # create heals the record rather than refusing it.
  run_cmd launcher_env "$tmp" "$SCRIPT" launcher create personal --name "Stale App" --color blue
  assert_status 0
  assert_contains "Recorded launcher for personal is gone"
  [[ -d "$stale_app" ]] || fail "create did not recreate a deleted launcher"

  # remove clears a record whose bundle is already gone.
  rm -rf "$stale_app"
  run_cmd launcher_env "$tmp" "$SCRIPT" launcher remove personal --yes
  assert_status 0
  assert_contains "was already gone"
  [[ ! -e "$tmp/config/launchers/personal.state" ]] || fail "stale launcher state survived removal"
  run_cmd launcher_env "$tmp" "$SCRIPT" launcher list
  assert_status 0
  assert_not_contains "Skipping personal"

  rm -rf "$tmp"
}

test_launcher_create_list_and_path_are_deterministic
test_launcher_create_is_idempotent_and_force_replaces_managed_bundle
test_launcher_refuses_invalid_inputs_and_unmanaged_collisions
test_launcher_cleans_up_a_failed_icon_build
test_launcher_remove_preserves_profile_data
test_profile_remove_refuses_managed_launcher_orphans
test_launcher_recovers_after_the_bundle_is_deleted_outside_the_cli

printf 'launcher tests passed\n'
