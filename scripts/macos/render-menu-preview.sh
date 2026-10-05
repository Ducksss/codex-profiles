#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_DIR="$ROOT_DIR/macos/CodexProfilesMenu/Sources/CodexProfilesMenu"
PREVIEW_SOURCE="$ROOT_DIR/macos/CodexProfilesMenu/Previews/RenderPreview.swift"
OUTPUT_PATH="${1:-$ROOT_DIR/build/macos/Codex-Profiles-preview.png}"
BUILD_DIR="${MENU_APP_PREVIEW_BUILD_DIR:-$ROOT_DIR/build/macos/preview}"
SWIFT_TARGET="$(uname -m)-apple-macosx13.0"

[[ "$(uname -s)" == "Darwin" ]] || {
  printf 'Error: the native menu preview can only be rendered on macOS.\n' >&2
  exit 1
}

command -v swiftc >/dev/null 2>&1 || {
  printf 'Error: Swift is required to render the native menu preview.\n' >&2
  exit 1
}

mkdir -p "$BUILD_DIR" "$(dirname "$OUTPUT_PATH")"

swiftc \
  -target "$SWIFT_TARGET" \
  -module-cache-path "$BUILD_DIR/module-cache" \
  -DTESTING \
  -parse-as-library \
  -framework AppKit \
  "$SOURCE_DIR"/*.swift \
  "$PREVIEW_SOURCE" \
  -o "$BUILD_DIR/RenderPreview"

if [[ $# -gt 0 ]]; then shift; fi
"$BUILD_DIR/RenderPreview" "$OUTPUT_PATH" "$@"
printf 'Rendered %s\n' "$OUTPUT_PATH"
