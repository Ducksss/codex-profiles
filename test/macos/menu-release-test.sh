#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/test/lib/assertions.sh"

if [[ "$(uname -s)" != Darwin ]]; then
  printf 'Skipping release boundary tests outside macOS.\n'
  exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM
FIXTURE_ROOT="$TMP_DIR/repository with spaces"
FAKE_BIN="$TMP_DIR/fake-bin"
mkdir -p "$FIXTURE_ROOT/scripts/macos" "$FIXTURE_ROOT/macos/CodexProfilesMenu" "$FAKE_BIN"
cp "$ROOT_DIR/scripts/macos/build-menu-dmg.sh" "$FIXTURE_ROOT/scripts/macos/"
cp "$ROOT_DIR/macos/CodexProfilesMenu/Release.entitlements" "$FIXTURE_ROOT/macos/CodexProfilesMenu/"
cp "$ROOT_DIR/macos/CodexProfilesMenu/Info.plist" "$FIXTURE_ROOT/Info.plist"
cp "$ROOT_DIR/LICENSE" "$FIXTURE_ROOT/LICENSE"

# Exercise the real release script; only compilation and OS/service boundaries are faked.
cat > "$FIXTURE_ROOT/scripts/macos/build-menu-app.sh" <<'APP_BUILDER'
#!/usr/bin/env bash
set -euo pipefail
fixture_root="$(cd "$(dirname "$0")/../.." && pwd)"
mkdir -p "$MENU_APP_BUILD_DIR/Codex Profiles.app/Contents"
cp "$fixture_root/Info.plist" "$MENU_APP_BUILD_DIR/Codex Profiles.app/Contents/Info.plist"
APP_BUILDER
chmod 755 "$FIXTURE_ROOT/scripts/macos/build-menu-app.sh"

cat > "$FAKE_BIN/release-boundary" <<'BOUNDARY'
#!/usr/bin/env bash
set -euo pipefail
tool="${0##*/}"
case "$tool:$1:${2:-}" in
  codesign:--force:*) stage=app-sign ;;
  codesign:--verify:*)
    if [[ "${!#}" == *.app ]]; then stage=app-verify; else stage=dmg-verify; fi
    ;;
  codesign:--sign:*) stage=dmg-sign ;;
  hdiutil:create:*) stage=dmg-create ;;
  xcrun:notarytool:submit) stage=notary-submit ;;
  xcrun:stapler:staple) stage=staple ;;
  xcrun:stapler:validate) stage=staple-validate ;;
  spctl:--assess:*) stage=assess ;;
  *) printf 'Unexpected release command: %s %s\n' "$tool" "$*" >&2; exit 90 ;;
esac
printf '%s\n' "$stage" >> "$RELEASE_TEST_EVENTS"
{
  printf '%s' "$stage"
  printf '|%s' "$@"
  printf '\n'
} >> "$RELEASE_TEST_ARGUMENTS"
[[ "$stage" != "${RELEASE_TEST_FAILURE:-}" ]] || exit 91
case "$stage" in
  dmg-create) printf 'DMG fixture\n' > "${!#}" ;;
  notary-submit)
    cat <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>status</key><string>${RELEASE_TEST_NOTARY_STATUS:-Accepted}</string>
</dict></plist>
PLIST
    ;;
esac
BOUNDARY
chmod 755 "$FAKE_BIN/release-boundary"
for tool in codesign hdiutil xcrun spctl; do
  ln -s release-boundary "$FAKE_BIN/$tool"
done

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$FIXTURE_ROOT/Info.plist")"
DMG_NAME="Codex-Profiles-$VERSION-universal.dmg"
SIGNING_IDENTITY='Developer ID Application: Test Fixture (TESTTEAM)'
BUILD_SCRIPT="$FIXTURE_ROOT/scripts/macos/build-menu-dmg.sh"

run_release() {
  PATH="$FAKE_BIN:$PATH" MENU_APP_BUILD_DIR="$OUTPUT_DIR" \
    MENU_APP_SIGNING_IDENTITY="$SIGNING_IDENTITY" MENU_APP_NOTARY_PROFILE='test profile' \
    RELEASE_TEST_EVENTS="$TMP_DIR/events" RELEASE_TEST_ARGUMENTS="$TMP_DIR/arguments" \
    RELEASE_TEST_NOTARY_STATUS="$1" RELEASE_TEST_FAILURE="${2:-}" \
    "$BUILD_SCRIPT" > "$TMP_DIR/output" 2>&1
}

OUTPUT_DIR="$TMP_DIR/accepted output"
run_release Accepted
[[ -s "$OUTPUT_DIR/$DMG_NAME" && -s "$OUTPUT_DIR/$DMG_NAME.sha256" ]]
(
  cd "$OUTPUT_DIR"
  shasum -a 256 -c "$DMG_NAME.sha256"
)
assert_equals 'release order' $'app-sign\napp-verify\ndmg-create\ndmg-sign\ndmg-verify\nnotary-submit\nstaple\nstaple-validate\nassess' "$(< "$TMP_DIR/events")"
arguments="$(< "$TMP_DIR/arguments")"
assert_contains "$arguments" "app-sign|--force|--sign|$SIGNING_IDENTITY|--timestamp|--options|runtime|--entitlements|$FIXTURE_ROOT/macos/CodexProfilesMenu/Release.entitlements|" 'hardened runtime signing'
assert_contains "$arguments" 'app-verify|--verify|--deep|--strict|' 'app signature verification'
assert_contains "$arguments" "dmg-sign|--sign|$SIGNING_IDENTITY|--timestamp|--identifier|dev.ducksss.codex-profiles.menu.dmg|" 'DMG signature'
assert_contains "$arguments" 'dmg-verify|--verify|--strict|' 'DMG signature verification'
assert_contains "$arguments" '|--keychain-profile|test profile|--wait|--output-format|plist' 'notarization profile and wait'
assert_contains "$arguments" 'assess|--assess|--type|open|--context|context:primary-signature|--verbose|' 'Gatekeeper assessment'

for preserve_existing in no yes; do
  OUTPUT_DIR="$TMP_DIR/rejected-$preserve_existing output"
  mkdir -p "$OUTPUT_DIR"
  if [[ "$preserve_existing" == yes ]]; then
    printf 'previous image\n' > "$OUTPUT_DIR/$DMG_NAME"
    printf 'previous checksum\n' > "$OUTPUT_DIR/$DMG_NAME.sha256"
  fi
  : > "$TMP_DIR/events"
  if run_release Invalid; then fail 'Rejected notarization unexpectedly published a DMG'; fi
  assert_contains "$(< "$TMP_DIR/output")" 'Notarization returned Invalid' 'rejection diagnostics'
  assert_equals 'rejected release order' $'app-sign\napp-verify\ndmg-create\ndmg-sign\ndmg-verify\nnotary-submit' "$(< "$TMP_DIR/events")"
  [[ -s "$OUTPUT_DIR/$DMG_NAME.notarization.plist" ]]
  if [[ "$preserve_existing" == yes ]]; then
    assert_equals 'previous image' 'previous image' "$(< "$OUTPUT_DIR/$DMG_NAME")"
    assert_equals 'previous checksum' 'previous checksum' "$(< "$OUTPUT_DIR/$DMG_NAME.sha256")"
  else
    [[ ! -e "$OUTPUT_DIR/$DMG_NAME" && ! -e "$OUTPUT_DIR/$DMG_NAME.sha256" ]]
  fi
done

for failed_stage in app-sign app-verify dmg-sign dmg-verify notary-submit staple staple-validate assess; do
  OUTPUT_DIR="$TMP_DIR/failed-$failed_stage output"
  : > "$TMP_DIR/events"
  if run_release Accepted "$failed_stage"; then fail "$failed_stage failure unexpectedly published a DMG"; fi
  assert_equals 'last release operation' "$failed_stage" "$(tail -n 1 "$TMP_DIR/events")"
  [[ ! -e "$OUTPUT_DIR/$DMG_NAME" && ! -e "$OUTPUT_DIR/$DMG_NAME.sha256" ]]
done

printf 'Signing and notarization boundary tests passed without credentials or uploads.\n'
