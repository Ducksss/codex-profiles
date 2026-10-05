#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_SOURCE_DIR="$ROOT_DIR/macos/CodexProfilesMenu/Sources/CodexProfilesMenu"
APP_PROJECT_DIR="$ROOT_DIR/macos/CodexProfilesMenu"
TEST_SOURCE="$ROOT_DIR/macos/CodexProfilesMenu/Tests/CodexProfilesMenuTests/TestMain.swift"
BUILD_SCRIPT="$ROOT_DIR/scripts/macos/build-menu-app.sh"

[[ -f "$APP_SOURCE_DIR/CodexProfilesMenuApp.swift" ]] || {
  printf 'Missing native menu app entry point.\n' >&2
  exit 1
}
[[ -f "$APP_PROJECT_DIR/Info.plist" ]] || {
  printf 'Missing native menu app Info.plist.\n' >&2
  exit 1
}
[[ -x "$BUILD_SCRIPT" ]] || {
  printf 'Native menu app build script is not executable.\n' >&2
  exit 1
}

if [[ "$(uname -s)" != "Darwin" ]] || ! command -v swiftc >/dev/null 2>&1; then
  printf 'Skipping native Swift build outside a Swift-capable macOS host.\n'
  exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM
SWIFT_TARGET="$(uname -m)-apple-macosx13.0"

swiftc \
  -module-cache-path "$TMP_DIR/module-cache" \
  -target "$SWIFT_TARGET" \
  -DTESTING \
  -parse-as-library \
  "$APP_SOURCE_DIR/WorkspaceModels.swift" \
  "$APP_SOURCE_DIR/CLIClient.swift" \
  "$APP_SOURCE_DIR/AccountUsage.swift" \
  "$APP_SOURCE_DIR/WorkspaceStore.swift" \
  "$TEST_SOURCE" \
  "$APP_PROJECT_DIR/Tests/CodexProfilesMenuTests/UsageTests.swift" \
  -o "$TMP_DIR/CodexProfilesMenuTests"
mkdir "$TMP_DIR/home"
HOME="$TMP_DIR/home" \
  CODEX_ACCESS_TOKEN=usage-test-sentinel \
  CODEX_API_KEY=usage-test-sentinel \
  OPENAI_API_KEY=usage-test-sentinel \
  LIBDISPATCH_COOPERATIVE_POOL_STRICT=1 \
  CODEX_PROFILE_CONFIG_HOME="$TMP_DIR/home/.config/codex-profile" \
  CODEX_PROFILE_NO_UPDATE_CHECK=1 \
  PROFILE_TEST_TMP="$TMP_DIR" \
  PROFILE_TEST_CLI="$ROOT_DIR/bin/codex-profile" \
  "$TMP_DIR/CodexProfilesMenuTests" &
TEST_PID=$!
# Stopping the watchdog must also stop its sleep, which would otherwise
# outlive the test as an orphan.
(
  trap 'kill "$sleeper" 2>/dev/null; exit 0' TERM
  sleep 30 &
  sleeper=$!
  wait "$sleeper"
  kill "$TEST_PID" 2>/dev/null || true
) >/dev/null 2>&1 &
WATCHDOG_PID=$!
if wait "$TEST_PID"; then
  kill "$WATCHDOG_PID" 2>/dev/null || true
  wait "$WATCHDOG_PID" 2>/dev/null || true
else
  kill "$WATCHDOG_PID" 2>/dev/null || true
  wait "$WATCHDOG_PID" 2>/dev/null || true
  printf 'Native unit tests failed or exceeded 30 seconds.\n' >&2
  exit 1
fi

swiftc \
  -module-cache-path "$TMP_DIR/module-cache" \
  -target "$SWIFT_TARGET" \
  -DTESTING \
  -parse-as-library \
  -framework AppKit \
  "$APP_SOURCE_DIR"/*.swift \
  "$APP_PROJECT_DIR/Tests/CodexProfilesMenuTests/MenuInteractionTests.swift" \
  -o "$TMP_DIR/MenuInteractionTests"
"$TMP_DIR/MenuInteractionTests"

swiftc \
  -module-cache-path "$TMP_DIR/module-cache" \
  -target "$SWIFT_TARGET" \
  -DTESTING \
  -parse-as-library \
  -framework AppKit \
  "$APP_SOURCE_DIR"/*.swift \
  "$APP_PROJECT_DIR/Previews/RenderPreview.swift" \
  -o "$TMP_DIR/RenderPreview"
"$TMP_DIR/RenderPreview" "$TMP_DIR/menu-light.png"
"$TMP_DIR/RenderPreview" "$TMP_DIR/menu-dark.png" --dark
printf 'Native light and dark preview backdrop checks passed.\n'

MENU_APP_BUILD_DIR="$TMP_DIR/app-build" "$BUILD_SCRIPT"

APP_DIR="$TMP_DIR/app-build/Codex Profiles.app"
[[ -x "$APP_DIR/Contents/MacOS/CodexProfilesMenu" ]]
[[ -x "$APP_DIR/Contents/Resources/bin/codex-profile" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$APP_DIR/Contents/Info.plist")" == "true" ]]

printf 'Native menu app tests passed.\n'
