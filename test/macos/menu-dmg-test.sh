#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_SCRIPT="$ROOT_DIR/scripts/macos/build-menu-dmg.sh"

[[ -x "$BUILD_SCRIPT" ]] || { printf 'Missing executable DMG builder.\n' >&2; exit 1; }

if [[ "$(uname -s)" != Darwin ]] || ! command -v swiftc >/dev/null 2>&1; then
  printf 'Skipping DMG build outside a Swift-capable macOS host.\n'
  exit 0
fi

TMP_DIR="$(mktemp -d)"
TMP_DIR="$(cd "$TMP_DIR" && pwd -P)"
MOUNT_DIR="$TMP_DIR/mounted"
detach_test_volume() {
  local attempt
  for ((attempt = 0; attempt < 10; attempt++)); do
    if hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
  done
  hdiutil detach "$MOUNT_DIR" >&2
}
cleanup() {
  if mount | grep -F " on $MOUNT_DIR (" >/dev/null; then
    detach_test_volume || return
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT HUP INT TERM

# Invalid release credentials must fail before building or uploading anything.
if MENU_APP_BUILD_DIR="$TMP_DIR/invalid" MENU_APP_NOTARY_PROFILE=missing \
  "$BUILD_SCRIPT" >"$TMP_DIR/error" 2>&1; then
  printf 'Notarization without a signing identity unexpectedly succeeded.\n' >&2
  exit 1
fi
grep -F 'requires MENU_APP_SIGNING_IDENTITY' "$TMP_DIR/error" >/dev/null
[[ ! -e "$TMP_DIR/invalid" ]]

if MENU_APP_BUILD_DIR="$TMP_DIR/invalid" MENU_APP_SIGNING_IDENTITY=- \
  "$BUILD_SCRIPT" >"$TMP_DIR/error" 2>&1; then
  printf 'Ad hoc release signing unexpectedly succeeded.\n' >&2
  exit 1
fi
grep -F 'Developer ID Application' "$TMP_DIR/error" >/dev/null
[[ ! -e "$TMP_DIR/invalid" ]]

OUTPUT_DIR="$TMP_DIR/output with spaces"
MENU_APP_BUILD_DIR="$OUTPUT_DIR" "$BUILD_SCRIPT"
VERSION="$("$ROOT_DIR/bin/codex-profile" version)"
VERSION="${VERSION#codex-profile }"
DMG="$OUTPUT_DIR/Codex-Profiles-$VERSION-universal.dmg"
[[ -s "$DMG" ]]
(
  cd "$OUTPUT_DIR"
  shasum -a 256 -c "$(basename "$DMG").sha256"
)

mkdir "$MOUNT_DIR"
hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT_DIR" "$DMG" >/dev/null
APP_DIR="$MOUNT_DIR/Codex Profiles.app"
[[ -x "$APP_DIR/Contents/MacOS/CodexProfilesMenu" ]]
[[ -x "$APP_DIR/Contents/Resources/bin/codex-profile" ]]
[[ -s "$APP_DIR/Contents/Resources/AppIcon.icns" ]]
[[ "$(readlink "$MOUNT_DIR/Applications")" == /Applications ]]
[[ -s "$MOUNT_DIR/License.txt" && -s "$MOUNT_DIR/Read Me.txt" ]]
[[ "$("$APP_DIR/Contents/Resources/bin/codex-profile" version)" == "codex-profile $VERSION" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")" == "$VERSION" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_DIR/Contents/Info.plist")" == "$VERSION" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$APP_DIR/Contents/Info.plist")" == AppIcon ]]
ARCHS="$(lipo -archs "$APP_DIR/Contents/MacOS/CodexProfilesMenu")"
[[ " $ARCHS " == *' arm64 '* && " $ARCHS " == *' x86_64 '* ]]
detach_test_volume

printf 'Universal DMG packaging tests passed.\n'
