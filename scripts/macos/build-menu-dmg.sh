#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT_DIR="${MENU_APP_BUILD_DIR:-$ROOT_DIR/build/macos}"
SIGNING_IDENTITY="${MENU_APP_SIGNING_IDENTITY:-}"
NOTARY_PROFILE="${MENU_APP_NOTARY_PROFILE:-}"

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

[[ $# -eq 0 ]] || die 'Usage: build-menu-dmg.sh (configure release signing with MENU_APP_SIGNING_IDENTITY and MENU_APP_NOTARY_PROFILE)'
[[ "$(uname -s)" == Darwin ]] || die 'DMG packaging requires macOS.'
[[ -z "$NOTARY_PROFILE" || -n "$SIGNING_IDENTITY" ]] \
  || die 'MENU_APP_NOTARY_PROFILE requires MENU_APP_SIGNING_IDENTITY.'
[[ -z "$SIGNING_IDENTITY" || "$SIGNING_IDENTITY" == 'Developer ID Application: '* ]] \
  || die 'Release signing requires a Developer ID Application identity; ad hoc signing is not supported.'

MENU_APP_BUILD_DIR="$OUTPUT_DIR" "$ROOT_DIR/scripts/macos/build-menu-app.sh"
APP_DIR="$OUTPUT_DIR/Codex Profiles.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")"
DMG_NAME="Codex-Profiles-$VERSION-universal.dmg"
TMP_DIR="$(mktemp -d "$OUTPUT_DIR/.menu-dmg.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM
STAGING_DIR="$TMP_DIR/volume"
mkdir "$STAGING_DIR"
ditto "$APP_DIR" "$STAGING_DIR/Codex Profiles.app"

if [[ -n "$SIGNING_IDENTITY" ]]; then
  codesign --force --sign "$SIGNING_IDENTITY" --timestamp --options runtime \
    --entitlements "$ROOT_DIR/macos/CodexProfilesMenu/Release.entitlements" \
    "$STAGING_DIR/Codex Profiles.app"
  codesign --verify --deep --strict "$STAGING_DIR/Codex Profiles.app"
fi

ln -s /Applications "$STAGING_DIR/Applications"
install -m 644 "$ROOT_DIR/LICENSE" "$STAGING_DIR/License.txt"
cat > "$STAGING_DIR/Read Me.txt" <<'EOF'
Drag Codex Profiles.app to Applications, then open it.
Use Add Workspace to create a profile and choose a project folder.
Open that workspace in ChatGPT and sign in there if prompted.
Install the official ChatGPT desktop app to use ChatGPT launching.
Terminal launching and CLI sign-in require the official Codex CLI.

Codex Profiles is community-maintained, not an official OpenAI product.
https://github.com/Ducksss/codex-profiles
EOF
if [[ -z "$SIGNING_IDENTITY" ]]; then
  printf '\nUnsigned development build: this image is not ready for public distribution.\n' \
    >> "$STAGING_DIR/Read Me.txt"
fi

hdiutil create -quiet -volname 'Codex Profiles' -srcfolder "$STAGING_DIR" \
  -format UDZO "$TMP_DIR/$DMG_NAME"

if [[ -n "$SIGNING_IDENTITY" ]]; then
  codesign --sign "$SIGNING_IDENTITY" --timestamp \
    --identifier dev.ducksss.codex-profiles.menu.dmg "$TMP_DIR/$DMG_NAME"
  codesign --verify --strict "$TMP_DIR/$DMG_NAME"
fi

if [[ -n "$NOTARY_PROFILE" ]]; then
  NOTARY_RESULT="$OUTPUT_DIR/$DMG_NAME.notarization.plist"
  xcrun notarytool submit "$TMP_DIR/$DMG_NAME" --keychain-profile "$NOTARY_PROFILE" \
    --wait --output-format plist > "$NOTARY_RESULT"
  STATUS="$(/usr/libexec/PlistBuddy -c 'Print :status' "$NOTARY_RESULT")"
  [[ "$STATUS" == Accepted ]] || die "Notarization returned $STATUS. See $NOTARY_RESULT."
  xcrun stapler staple "$TMP_DIR/$DMG_NAME"
  xcrun stapler validate "$TMP_DIR/$DMG_NAME"
  spctl --assess --type open --context context:primary-signature --verbose "$TMP_DIR/$DMG_NAME"
fi

(
  cd "$TMP_DIR"
  shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256"
)
mv -f "$TMP_DIR/$DMG_NAME" "$TMP_DIR/$DMG_NAME.sha256" "$OUTPUT_DIR/"
printf 'Built %s\n' "$OUTPUT_DIR/$DMG_NAME"
if [[ -z "$SIGNING_IDENTITY" ]]; then
  printf 'Unsigned development build; public releases require Developer ID signing and notarization.\n'
elif [[ -z "$NOTARY_PROFILE" ]]; then
  printf 'Signed build; public releases still require notarization.\n'
fi
