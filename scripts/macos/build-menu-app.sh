#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT_DIR="${MENU_APP_BUILD_DIR:-$ROOT_DIR/build/macos}"
APP_DIR="$OUTPUT_DIR/Codex Profiles.app"

[[ "$(uname -s)" == "Darwin" ]] || {
  printf 'Error: the native menu app can only be built on macOS.\n' >&2
  exit 1
}

command -v swiftc >/dev/null 2>&1 || {
  printf 'Error: Swift is required to build the native menu app.\n' >&2
  exit 1
}

mkdir -p "$OUTPUT_DIR"
TMP_DIR="$(mktemp -d "$OUTPUT_DIR/.menu-app.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM
CONTENTS_DIR="$TMP_DIR/Codex Profiles.app/Contents"
install -d "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources/bin"
SOURCE_DIR="$TMP_DIR/Sources"
ditto "$ROOT_DIR/macos/CodexProfilesMenu/Sources/CodexProfilesMenu" "$SOURCE_DIR"
install -m 755 "$ROOT_DIR/bin/codex-profile" "$CONTENTS_DIR/Resources/bin/codex-profile"
VERSION="$(sed -n 's/^VERSION="\([^"]*\)"$/\1/p' "$CONTENTS_DIR/Resources/bin/codex-profile")"
install -m 644 "$ROOT_DIR/macos/CodexProfilesMenu/Info.plist" "$CONTENTS_DIR/Info.plist"

for architecture in arm64 x86_64; do
  swiftc \
    -target "$architecture-apple-macosx13.0" \
    -module-cache-path "$TMP_DIR/module-cache" \
    -parse-as-library \
    -O \
    -whole-module-optimization \
    -framework AppKit \
    "$SOURCE_DIR"/*.swift \
    -o "$TMP_DIR/CodexProfilesMenu-$architecture"
done
lipo -create "$TMP_DIR/CodexProfilesMenu-arm64" "$TMP_DIR/CodexProfilesMenu-x86_64" \
  -output "$CONTENTS_DIR/MacOS/CodexProfilesMenu"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$CONTENTS_DIR/Info.plist"
install -m 644 "$ROOT_DIR/LICENSE" "$CONTENTS_DIR/Resources/License.txt"

swiftc -target "$(uname -m)-apple-macosx13.0" -parse-as-library -O \
  -module-cache-path "$TMP_DIR/module-cache" \
  -framework AppKit "$ROOT_DIR/scripts/macos/render-app-icon.swift" -o "$TMP_DIR/render-icon"
"$TMP_DIR/render-icon" "$TMP_DIR/AppIcon.iconset"
iconutil -c icns "$TMP_DIR/AppIcon.iconset" -o "$CONTENTS_DIR/Resources/AppIcon.icns"

rm -rf "$APP_DIR"
mv "$TMP_DIR/Codex Profiles.app" "$APP_DIR"

printf 'Built %s\n' "$APP_DIR"
