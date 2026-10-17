#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT_DIR="${MENU_APP_BUILD_DIR:-$ROOT_DIR/build/macos}"
SIGNING_IDENTITY="${MENU_APP_SIGNING_IDENTITY:-}"
NOTARY_PROFILE="${MENU_APP_NOTARY_PROFILE:-}"
# CI notarises with an App Store Connect API key instead of a Keychain profile.
NOTARY_KEY="${MENU_APP_NOTARY_KEY:-}"
NOTARY_KEY_ID="${MENU_APP_NOTARY_KEY_ID:-}"
NOTARY_ISSUER="${MENU_APP_NOTARY_ISSUER:-}"

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

[[ $# -eq 0 ]] || die 'Usage: build-menu-dmg.sh (configure release signing with MENU_APP_SIGNING_IDENTITY and MENU_APP_NOTARY_PROFILE or MENU_APP_NOTARY_KEY)'
[[ "$(uname -s)" == Darwin ]] || die 'DMG packaging requires macOS.'
[[ -z "$NOTARY_PROFILE" || -z "$NOTARY_KEY" ]] \
  || die 'Set MENU_APP_NOTARY_PROFILE or MENU_APP_NOTARY_KEY, not both.'
[[ -z "$NOTARY_PROFILE$NOTARY_KEY" || -n "$SIGNING_IDENTITY" ]] \
  || die 'Notarization requires MENU_APP_SIGNING_IDENTITY.'
NOTARY_CREDENTIALS=()
if [[ -n "$NOTARY_PROFILE" ]]; then
  NOTARY_CREDENTIALS=(--keychain-profile "$NOTARY_PROFILE")
elif [[ -n "$NOTARY_KEY" ]]; then
  [[ -f "$NOTARY_KEY" && -n "$NOTARY_KEY_ID" && -n "$NOTARY_ISSUER" ]] \
    || die 'MENU_APP_NOTARY_KEY needs an existing key file, MENU_APP_NOTARY_KEY_ID and MENU_APP_NOTARY_ISSUER.'
  NOTARY_CREDENTIALS=(--key "$NOTARY_KEY" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER")
fi
[[ -z "$SIGNING_IDENTITY" || "$SIGNING_IDENTITY" == 'Developer ID Application: '* ]] \
  || die 'Release signing requires a Developer ID Application identity; ad hoc signing is not supported.'

MENU_APP_BUILD_DIR="$OUTPUT_DIR" "$ROOT_DIR/scripts/macos/build-menu-app.sh"
APP_DIR="$OUTPUT_DIR/Codex Profiles.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")"
DMG_NAME="Codex-Profiles-$VERSION-universal.dmg"
TMP_DIR="$(mktemp -d "$OUTPUT_DIR/.menu-dmg.XXXXXX")"
PUBLISHING=0

# A failed or interrupted publication restores the previous image and
# checksum, so a checksum never sits beside an image it does not describe.
cleanup() {
  local artifact
  if ((PUBLISHING)); then
    for artifact in "$DMG_NAME" "$DMG_NAME.sha256"; do
      if [[ -e "$TMP_DIR/previous/$artifact" ]]; then
        mv -f "$TMP_DIR/previous/$artifact" "$OUTPUT_DIR/$artifact"
      elif [[ ! -e "$TMP_DIR/$artifact" ]]; then
        rm -f "$OUTPUT_DIR/$artifact"
      fi
    done
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM

publish() {
  local artifact
  mkdir "$TMP_DIR/previous"
  PUBLISHING=1
  for artifact in "$DMG_NAME" "$DMG_NAME.sha256"; do
    if [[ -e "$OUTPUT_DIR/$artifact" ]]; then
      mv -f "$OUTPUT_DIR/$artifact" "$TMP_DIR/previous/$artifact"
    fi
  done
  mv -f "$TMP_DIR/$DMG_NAME" "$OUTPUT_DIR/$DMG_NAME"
  mv -f "$TMP_DIR/$DMG_NAME.sha256" "$OUTPUT_DIR/$DMG_NAME.sha256"
  PUBLISHING=0
}

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
Open an existing profile, or use Create Profile on first run.
No project folder is required. Add Workspace is an optional shortcut.
Open the profile in ChatGPT and sign in there if prompted.
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

if ((${#NOTARY_CREDENTIALS[@]})); then
  NOTARY_RESULT="$OUTPUT_DIR/$DMG_NAME.notarization.plist"
  xcrun notarytool submit "$TMP_DIR/$DMG_NAME" "${NOTARY_CREDENTIALS[@]}" \
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
publish
printf 'Built %s\n' "$OUTPUT_DIR/$DMG_NAME"
if [[ -z "$SIGNING_IDENTITY" ]]; then
  printf 'Unsigned development build; public releases require Developer ID signing and notarization.\n'
elif ((${#NOTARY_CREDENTIALS[@]} == 0)); then
  printf 'Signed build; public releases still require notarization.\n'
fi
