#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/test/lib/assertions.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
source "$ROOT_DIR/test/lib/cli-fixtures.sh"
source "$ROOT_DIR/test/lib/command-shims.sh"

CLI_VERSION="$(sed -n 's/^VERSION="\([^"]*\)"$/\1/p' "$SCRIPT")"
TAG="v$CLI_VERSION"
APP_NAME="Codex Profiles.app"
BUNDLE_ID="dev.ducksss.codex-profiles.menu"

# Apple's build tools are faked so the suite runs on Linux and on Macs without
# the Command Line Tools. git, cmp and the build orchestration stay real.
write_fake_menu_tools() {
  local fake_bin="$1"
  local tool

  write_command_shim "$fake_bin/uname" <<'FAKE_UNAME'
printf '%s\n' "${FAKE_UNAME:-Darwin}"
FAKE_UNAME
  write_command_shim "$fake_bin/xcode-select" <<'FAKE_XCODE_SELECT'
if [ -n "${FAKE_CLT_MISSING:-}" ]; then
  printf 'xcode-select: error: unable to get active developer directory\n' >&2
  exit 2
fi
printf '/Library/Developer/CommandLineTools\n'
FAKE_XCODE_SELECT
  write_command_shim "$fake_bin/xcrun" <<'FAKE_XCRUN'
[ -z "${FAKE_CLT_MISSING:-}" ] || exit 1
printf '/Library/Developer/CommandLineTools/usr/bin/swiftc\n'
FAKE_XCRUN
  # A local build needs no signing and no quarantine changes.
  for tool in codesign spctl xattr sudo; do
    write_command_shim "$fake_bin/$tool" <<'FAKE_FORBIDDEN_TOOL'
printf 'forbidden tool %s was called: %s\n' "${0##*/}" "$*" >> "${FAKE_TOOL_LOG:?}"
exit 99
FAKE_FORBIDDEN_TOOL
  done
  if ! command -v plutil > /dev/null 2>&1 && [[ ! -x /usr/libexec/PlistBuddy ]]; then
    write_fake_plutil "$fake_bin/plutil"
  fi
  if ! command -v ditto > /dev/null 2>&1; then
    write_command_shim "$fake_bin/ditto" <<'FAKE_DITTO'
exec cp -R "$1" "$2"
FAKE_DITTO
  fi
}

write_menu_app_plist() {
  local plist="$1"
  local bundle_id="$2"
  local version="$3"

  cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>$bundle_id</string>
  <key>CFBundleShortVersionString</key>
  <string>$version</string>
</dict>
</plist>
PLIST
}

# The tagged commit declares `declared`; main then moves past the tag so an
# install that followed the branch would bundle 9.9.9 instead.
write_fake_menu_repo() {
  local repo="$1"
  local declared="$2"

  mkdir -p "$repo/scripts/macos"
  init_git_main_branch "$repo"
  write_fake_upgrade_repo "$repo" "$declared"
  cat > "$repo/scripts/macos/build-menu-app.sh" <<'FAKE_BUILD'
#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ -n "${FAKE_MENU_BUILD_FAIL:-}" ]]; then
  printf 'swiftc: fake compile error\n' >&2
  exit 1
fi
app="$MENU_APP_BUILD_DIR/Codex Profiles.app"
version="$(sed -n 's/^VERSION="\([^"]*\)"$/\1/p' "$root/bin/codex-profile")"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/bin"
cp "$root/bin/codex-profile" "$app/Contents/Resources/bin/codex-profile"
[[ -z "${FAKE_MENU_BUNDLED_CLI_EDIT:-}" ]] || printf '# edited\n' >> "$app/Contents/Resources/bin/codex-profile"
printf '#!/bin/sh\n' > "$app/Contents/MacOS/CodexProfilesMenu"
chmod 755 "$app/Contents/MacOS/CodexProfilesMenu"
printf 'new\n' > "$app/Contents/Resources/marker"
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>${FAKE_MENU_BUNDLE_ID:-dev.ducksss.codex-profiles.menu}</string>
  <key>CFBundleShortVersionString</key>
  <string>$version</string>
</dict>
</plist>
PLIST
printf 'Built %s\n' "$app"
FAKE_BUILD
  chmod 755 "$repo/scripts/macos/build-menu-app.sh"
  git -C "$repo" add .
  git -C "$repo" -c user.name=test -c user.email=test@example.com commit -m "release" > /dev/null
  git -C "$repo" tag "$TAG"
  write_fake_upgrade_repo "$repo" "9.9.9"
  git -C "$repo" -c user.name=test -c user.email=test@example.com commit -am "after release" > /dev/null
}

write_release_json() {
  printf '{"tag_name":"%s","immutable":%s,"draft":false,"prerelease":false}\n' "$2" "$3" > "$1"
}

write_installed_menu_app() {
  local app="$1"
  local bundle_id="$2"

  mkdir -p "$app/Contents"
  write_menu_app_plist "$app/Contents/Info.plist" "$bundle_id" "0.0.1"
  printf 'old\n' > "$app/Contents/marker"
}

new_menu_case() {
  local tmp

  tmp="$(mktemp -d "$TMP_ROOT/case.XXXXXX")"
  mkdir -p "$tmp/home" "$tmp/tmp"
  write_fake_menu_tools "$tmp/bin"
  write_fake_menu_repo "$tmp/repo" "${1:-$CLI_VERSION}"
  write_release_json "$tmp/release.json" "$TAG" true
  printf '%s\n' "$tmp"
}

menu_cmd() {
  local tmp="$1"
  shift

  run_cmd env HOME="$tmp/home" PATH="$tmp/bin:$PATH" TMPDIR="$tmp/tmp" \
    CODEX_PROFILE_NO_UPDATE_CHECK=1 FAKE_TOOL_LOG="$tmp/tools.log" \
    CODEX_PROFILE_UPGRADE_REPO="$tmp/repo" CODEX_PROFILE_UPGRADE_CACHE="$tmp/cache" \
    CODEX_PROFILE_MENU_RELEASE_URL="$tmp/release.json" "$@"
}

assert_no_menu_leftovers() {
  local tmp="$1"
  local apps="$2"

  [[ -z "$(find "$tmp/tmp" -mindepth 1 -print -quit)" ]] || fail "menu install left a build folder: $(ls -A "$tmp/tmp")"
  if [[ -d "$apps" ]]; then
    [[ -z "$(find "$apps" -mindepth 1 -maxdepth 1 -name '.codex-profile-menu.*' -print -quit)" ]] \
      || fail "menu install left a staging folder in $apps"
  fi
  [[ ! -s "$tmp/tools.log" ]] || fail "menu install called a forbidden tool: $(cat "$tmp/tools.log")"
}

test_menu_install_dry_run_reports_plan_without_side_effects() {
  local tmp
  tmp="$(new_menu_case)"

  menu_cmd "$tmp" CODEX_PROFILE_MENU_RELEASE_URL="$tmp/missing.json" "$SCRIPT" menu install --dry-run --dir "$tmp/Apps"

  assert_status 0
  assert_contains "Menu-bar app install plan"
  assert_contains "Version: codex-profile $CLI_VERSION"
  assert_contains "Repository: $tmp/repo"
  assert_contains "Ref: $TAG"
  assert_contains "Cache: $tmp/cache"
  assert_contains "Install: $tmp/Apps/$APP_NAME"
  assert_contains "Release policy: immutable final GitHub Release"
  [[ ! -e "$tmp/cache" ]] || fail "menu install --dry-run created the cache checkout"
  [[ ! -e "$tmp/Apps" ]] || fail "menu install --dry-run created the install folder"

  set +e
  output="$(cd "$tmp" && env HOME="$tmp/home" PATH="$tmp/bin:$PATH" CODEX_PROFILE_NO_UPDATE_CHECK=1 \
    "$SCRIPT" menu install -n --dir Apps 2>&1)"
  status=$?
  set -e
  assert_status 0
  assert_contains "Install: $tmp/Apps/$APP_NAME"
}

test_menu_install_defaults_to_the_existing_copy() {
  local tmp expected
  if [[ -e "/Applications/$APP_NAME" ]]; then
    printf 'SKIP: /Applications already holds %s on this host\n' "$APP_NAME"
    return 0
  fi
  tmp="$(new_menu_case)"

  expected="$tmp/home/Applications"
  [[ ! -d /Applications || ! -w /Applications ]] || expected=/Applications
  menu_cmd "$tmp" "$SCRIPT" menu install --dry-run
  assert_status 0
  assert_contains "Install: $expected/$APP_NAME"

  write_installed_menu_app "$tmp/home/Applications/$APP_NAME" "$BUNDLE_ID"
  menu_cmd "$tmp" "$SCRIPT" menu install --dry-run
  assert_status 0
  assert_contains "Install: $tmp/home/Applications/$APP_NAME"
}

test_menu_install_builds_the_matching_release() {
  local tmp app
  tmp="$(new_menu_case)"
  app="$tmp/Apps/$APP_NAME"

  menu_cmd "$tmp" "$SCRIPT" menu install --dir "$tmp/Apps"

  assert_status 0
  assert_contains "Building $APP_NAME from $TAG"
  assert_contains "Installed Codex Profiles $CLI_VERSION to $app"
  assert_contains "Bundled CLI: codex-profile $CLI_VERSION"
  [[ -x "$app/Contents/MacOS/CodexProfilesMenu" ]] || fail "menu install did not install the app executable"
  [[ "$(cat "$app/Contents/Resources/marker")" == new ]] || fail "menu install did not install the new build"
  run_cmd "$app/Contents/Resources/bin/codex-profile" version
  assert_status 0
  assert_equals "codex-profile $CLI_VERSION"
  [[ "$(git -C "$tmp/cache" describe --tags --exact-match)" == "$TAG" ]] \
    || fail "menu install did not build from the detached $TAG tag"
  [[ -z "$(git -C "$tmp/cache" status --porcelain)" ]] || fail "menu install built inside the cache checkout"
  assert_no_menu_leftovers "$tmp" "$tmp/Apps"
}

test_menu_install_replaces_an_existing_copy_in_place() {
  local tmp app
  tmp="$(new_menu_case)"
  app="$tmp/Apps/$APP_NAME"
  write_installed_menu_app "$app" "$BUNDLE_ID"

  menu_cmd "$tmp" "$SCRIPT" menu install --dir "$tmp/Apps"

  assert_status 0
  [[ "$(cat "$app/Contents/Resources/marker")" == new ]] || fail "menu install kept the previous build"
  [[ ! -e "$app/Contents/marker" ]] || fail "menu install merged the new build into the previous copy"
  [[ "$(find "$tmp/Apps" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" == 1 ]] \
    || fail "menu install left extra entries in the install folder: $(ls -A "$tmp/Apps")"
  assert_no_menu_leftovers "$tmp" "$tmp/Apps"
}

test_menu_install_refuses_to_replace_other_bundles() {
  local tmp app
  tmp="$(new_menu_case)"
  app="$tmp/Apps/$APP_NAME"
  write_installed_menu_app "$app" com.example.other

  menu_cmd "$tmp" "$SCRIPT" menu install --dir "$tmp/Apps"
  assert_status 1
  assert_contains "Refusing to replace $app: it is not Codex Profiles."
  [[ "$(cat "$app/Contents/marker")" == old ]] || fail "menu install changed a foreign bundle"
  [[ ! -e "$tmp/cache" ]] || fail "menu install fetched source before checking the destination"

  rm -rf "$app"
  mkdir -p "$tmp/elsewhere"
  ln -s "$tmp/elsewhere" "$app"
  menu_cmd "$tmp" "$SCRIPT" menu install --dir "$tmp/Apps"
  assert_status 1
  assert_contains "Refusing to replace $app: it is not an app bundle."
  [[ -L "$app" ]] || fail "menu install replaced a symlinked destination"
}

test_menu_install_requires_macos_and_command_line_tools() {
  local tmp
  tmp="$(new_menu_case)"

  menu_cmd "$tmp" FAKE_UNAME=Linux "$SCRIPT" menu install --dry-run
  assert_status 1
  assert_contains "menu install is only available on macOS"

  menu_cmd "$tmp" FAKE_CLT_MISSING=1 "$SCRIPT" menu install --dir "$tmp/Apps"
  assert_status 1
  assert_contains "needs Apple's Command Line Tools"
  assert_contains "xcode-select --install"
  [[ ! -e "$tmp/cache" ]] || fail "menu install fetched source without the Command Line Tools"
  [[ ! -e "$tmp/Apps" ]] || fail "menu install created the install folder without the Command Line Tools"
}

test_menu_install_requires_the_immutable_matching_release() {
  local tmp
  tmp="$(new_menu_case)"

  write_release_json "$tmp/release.json" "$TAG" false
  menu_cmd "$tmp" "$SCRIPT" menu install --dir "$tmp/Apps"
  assert_status 1
  assert_contains "GitHub Release $TAG is not immutable and final."

  write_release_json "$tmp/release.json" v0.0.1 true
  menu_cmd "$tmp" "$SCRIPT" menu install --dir "$tmp/Apps"
  assert_status 1
  assert_contains "Release metadata does not describe $TAG"

  menu_cmd "$tmp" CODEX_PROFILE_MENU_RELEASE_URL=--config=/tmp/unsafe "$SCRIPT" menu install --dir "$tmp/Apps"
  assert_status 1
  assert_contains "Cannot fetch release metadata for $TAG"
  [[ ! -e "$tmp/cache" ]] || fail "menu install fetched source for an unverified release"
  [[ ! -e "$tmp/Apps/$APP_NAME" ]] || fail "menu install installed an unverified release"
}

test_menu_install_refuses_a_tag_declaring_another_version() {
  local tmp
  tmp="$(new_menu_case 9.9.8)"

  menu_cmd "$tmp" "$SCRIPT" menu install --dir "$tmp/Apps"
  assert_status 1
  assert_contains "Refusing release $TAG because its bin/codex-profile does not declare $CLI_VERSION."
  [[ ! -e "$tmp/Apps/$APP_NAME" ]] || fail "menu install installed a mismatched release"
}

test_menu_install_keeps_the_existing_copy_when_the_build_fails() {
  local tmp app
  tmp="$(new_menu_case)"
  app="$tmp/Apps/$APP_NAME"
  write_installed_menu_app "$app" "$BUNDLE_ID"

  menu_cmd "$tmp" FAKE_MENU_BUILD_FAIL=1 "$SCRIPT" menu install --dir "$tmp/Apps"
  assert_status 1
  assert_contains "swiftc: fake compile error"
  assert_contains "The menu-bar app build failed; $app was not changed."
  [[ "$(cat "$app/Contents/marker")" == old ]] || fail "a failed build changed the installed app"
  assert_no_menu_leftovers "$tmp" "$tmp/Apps"

  menu_cmd "$tmp" FAKE_MENU_BUNDLE_ID=com.example.other "$SCRIPT" menu install --dir "$tmp/Apps"
  assert_status 1
  assert_contains "The build did not produce Codex Profiles"
  [[ "$(cat "$app/Contents/marker")" == old ]] || fail "a foreign build replaced the installed app"

  menu_cmd "$tmp" FAKE_MENU_BUNDLED_CLI_EDIT=1 "$SCRIPT" menu install --dir "$tmp/Apps"
  assert_status 1
  assert_contains "The built app does not bundle the $TAG codex-profile."
  [[ "$(cat "$app/Contents/marker")" == old ]] || fail "a build with another CLI replaced the installed app"
  assert_no_menu_leftovers "$tmp" "$tmp/Apps"
}

test_menu_rejects_unknown_arguments() {
  local tmp
  tmp="$(new_menu_case)"

  menu_cmd "$tmp" "$SCRIPT" menu
  assert_status 1
  assert_contains "Usage: codex-profile menu install [--dry-run] [--dir <path>]"
  menu_cmd "$tmp" "$SCRIPT" menu remove
  assert_status 1
  assert_contains "Unknown menu command 'remove'. Use install."
  menu_cmd "$tmp" "$SCRIPT" menu install --dir
  assert_status 1
  assert_contains "Usage: codex-profile menu install [--dry-run] [--dir <path>]"
  menu_cmd "$tmp" "$SCRIPT" menu install --ref main
  assert_status 1
  assert_contains "Usage: codex-profile menu install [--dry-run] [--dir <path>]"
}

test_menu_install_dry_run_reports_plan_without_side_effects
test_menu_install_defaults_to_the_existing_copy
test_menu_install_builds_the_matching_release
test_menu_install_replaces_an_existing_copy_in_place
test_menu_install_refuses_to_replace_other_bundles
test_menu_install_requires_macos_and_command_line_tools
test_menu_install_requires_the_immutable_matching_release
test_menu_install_refuses_a_tag_declaring_another_version
test_menu_install_keeps_the_existing_copy_when_the_build_fails
test_menu_rejects_unknown_arguments

printf 'PASS: menu install\n'
