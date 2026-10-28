#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/test/lib/assertions.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
source "$ROOT_DIR/test/lib/cli-fixtures.sh"

appearance_env() {
  local tmp="$1"
  shift
  env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$tmp/config" CODEX_PROFILE_NO_UPDATE_CHECK=1 "$@"
}

test_automatic_appearance_is_stable_and_graphite_for_default() {
  local tmp="$TMP_ROOT/automatic"
  mkdir -p "$tmp/home/.codex" "$tmp/home/.codex-work" "$tmp/home/.codex-personal"

  run_cmd appearance_env "$tmp" "$SCRIPT" appearance
  assert_status 0
  # These match ProfileAppearance.automatic in the menu-bar app.
  assert_equals $'default: graphite monogram (automatic)\npersonal: pink monogram (automatic)\nwork: indigo monogram (automatic)'
  [[ ! -e "$tmp/config/appearance.tsv" ]] || fail "reading an appearance must not create the registry"

  run_cmd appearance_env "$tmp" "$SCRIPT" appearance work --json
  assert_status 0
  assert_equals '{"profiles":[{"profile":"work","color":"indigo","symbol":"monogram","automatic":true}]}'
}

test_choices_persist_privately_and_reset() {
  local tmp="$TMP_ROOT/choices"
  mkdir -p "$tmp/home/.codex-work" "$tmp/home/.codex-personal"

  run_cmd appearance_env "$tmp" "$SCRIPT" appearance work --color teal --symbol flask
  assert_status 0
  assert_equals 'work: teal flask'
  [[ "$(mode_of "$tmp/config")" == 700 ]] || fail "config directory is not private"
  [[ "$(mode_of "$tmp/config/appearance.tsv")" == 600 ]] || fail "appearance registry is not private"

  run_cmd appearance_env "$tmp" "$SCRIPT" appearance work --symbol house
  assert_status 0
  assert_equals 'work: teal house'
  run_cmd appearance_env "$tmp" "$SCRIPT" appearance personal --color green
  assert_status 0
  run_cmd appearance_env "$tmp" "$SCRIPT" appearance --json
  assert_status 0
  assert_equals '{"profiles":[{"profile":"personal","color":"green","symbol":"monogram","automatic":false},{"profile":"work","color":"teal","symbol":"house","automatic":false}]}'

  run_cmd appearance_env "$tmp" "$SCRIPT" appearance work --reset
  assert_status 0
  assert_equals 'work: indigo monogram (automatic)'
  [[ "$(cat "$tmp/config/appearance.tsv")" == $'personal\tgreen\tmonogram' ]] || fail "reset touched another profile's entry"
}

test_invalid_requests_are_refused() {
  local tmp="$TMP_ROOT/invalid"
  mkdir -p "$tmp/home/.codex-work"

  run_cmd appearance_env "$tmp" "$SCRIPT" appearance work --color red
  assert_status 1
  assert_contains "Unsupported color 'red'"
  run_cmd appearance_env "$tmp" "$SCRIPT" appearance work --symbol rocket
  assert_status 1
  assert_contains "Unsupported symbol 'rocket'"
  run_cmd appearance_env "$tmp" "$SCRIPT" appearance missing --color teal
  assert_status 1
  assert_contains "Profile 'missing' is not initialized"
  run_cmd appearance_env "$tmp" "$SCRIPT" appearance work --reset --color teal
  assert_status 1
  assert_contains 'Use --reset on its own'
  run_cmd appearance_env "$tmp" "$SCRIPT" appearance --color teal
  assert_status 1
  assert_contains 'Usage:'
  run_cmd appearance_env "$tmp" "$SCRIPT" appearance work --tint teal
  assert_status 1
  assert_contains 'Usage:'
  [[ ! -e "$tmp/config/appearance.tsv" ]] || fail "a refused request wrote the registry"
}

test_damaged_entries_fall_back_and_symlinks_are_refused() {
  local tmp="$TMP_ROOT/damaged"
  mkdir -p "$tmp/home/.codex-work" "$tmp/config"
  printf 'work\tcrimson\tflask\nbad name\tteal\tflask\n' > "$tmp/config/appearance.tsv"

  run_cmd appearance_env "$tmp" "$SCRIPT" appearance work
  assert_status 0
  assert_equals 'work: indigo monogram (automatic)'
  run_cmd appearance_env "$tmp" "$SCRIPT" appearance work --color teal
  assert_status 0
  [[ "$(cat "$tmp/config/appearance.tsv")" == $'work\tteal\tmonogram' ]] || fail "a rewrite kept damaged entries"

  rm "$tmp/config/appearance.tsv"
  ln -s "$tmp/elsewhere" "$tmp/config/appearance.tsv"
  run_cmd appearance_env "$tmp" "$SCRIPT" appearance work --color green
  assert_status 1
  assert_contains 'Refusing symlinked appearance registry'
  [[ ! -e "$tmp/elsewhere" ]] || fail "a symlinked registry was written through"
}

test_env_exports_the_colour_and_remove_forgets_it() {
  local tmp="$TMP_ROOT/env"
  mkdir -p "$tmp/home/.codex-work"

  run_cmd appearance_env "$tmp" "$SCRIPT" appearance work --color brown
  assert_status 0
  run_cmd appearance_env "$tmp" "$SCRIPT" env work
  assert_status 0
  assert_contains 'export CODEX_PROFILE_COLOR=brown'
  run_cmd appearance_env "$tmp" "$SCRIPT" env work --shell fish
  assert_status 0
  assert_contains 'set -gx CODEX_PROFILE_COLOR brown'

  run_cmd appearance_env "$tmp" "$SCRIPT" remove work --yes
  assert_status 0
  [[ ! -s "$tmp/config/appearance.tsv" ]] || fail "remove kept the profile's appearance"
}

test_automatic_appearance_is_stable_and_graphite_for_default
test_choices_persist_privately_and_reset
test_invalid_requests_are_refused
test_damaged_entries_fall_back_and_symlinks_are_refused
test_env_exports_the_colour_and_remove_forgets_it

printf 'appearance tests passed\n'
