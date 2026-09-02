#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/test/lib/assertions.sh"
source "$ROOT_DIR/test/lib/command-shims.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM

fake_bin="$TMP_ROOT/bin"
log_file="$TMP_ROOT/pages.log"

write_command_shim "$fake_bin/gh" <<'SH'
set -eu
printf 'gh:%s\n' "$*" >> "$RELEASE_TEST_LOG"
case "${1:-}:${2:-}" in
  workflow:run)
    case " $* " in
      *' -f release_correlation=release-123-4 '*) ;;
      *) exit 65 ;;
    esac
    case " $* " in *' --ref main '*) ;; *) exit 66 ;; esac
    case " $* " in *' -f release_tag=v0.7.0 '*) ;; *) exit 67 ;; esac
    ;;
  run:list)
    case " $* " in *' --commit '*) exit 68 ;; esac
    count="$(grep -c '^gh:run list' "$RELEASE_TEST_LOG" || true)"
    if [ "$FAKE_PAGES_SCENARIO" = missing ]; then
      exit 0
    fi
    if [ "$count" -ge 3 ]; then
      printf '%s\n' 4242
    fi
    ;;
  run:watch)
    [ "$FAKE_PAGES_SCENARIO" != watch-failure ]
    ;;
  *) exit 64 ;;
esac
SH

write_command_shim "$fake_bin/curl" <<'SH'
set -eu
printf 'curl:%s\n' "$*" >> "$RELEASE_TEST_LOG"
count="$(grep -c '^curl:' "$RELEASE_TEST_LOG" || true)"
if [ "$count" -ge 2 ]; then
  printf '%s\n' '<span>v0.7.0</span>'
else
  printf '%s\n' '<span>v0.6.0</span>'
fi
SH

write_command_shim "$fake_bin/sleep" <<'SH'
printf '%s\n' sleep >> "$RELEASE_TEST_LOG"
SH

run_pages() {
  local scenario="$1"
  local expected_status="$2"
  local expected_lists="$3"
  local expected_watches="$4"
  local expected_curls="$5"
  local status actual

  : > "$log_file"
  set +e
  PATH="$fake_bin:$PATH" \
    RELEASE_TEST_LOG="$log_file" \
    FAKE_PAGES_SCENARIO="$scenario" \
    TAG="v0.7.0" \
    V="0.7.0" \
    GITHUB_RUN_ID="123" \
    GITHUB_RUN_ATTEMPT="4" \
    GITHUB_REPOSITORY="Ducksss/codex-profiles" \
    "$ROOT_DIR/scripts/release/deploy-pages.sh" \
      >"$TMP_ROOT/pages-$scenario.out" 2>&1
  status=$?
  set -e

  if [[ "$expected_status" = success ]]; then
    if [[ "$status" -ne 0 ]]; then
      cat "$TMP_ROOT/pages-$scenario.out" >&2
      cat "$log_file" >&2
      fail "Pages $scenario scenario failed"
    fi
  else
    [[ "$status" -ne 0 ]] || fail "Pages $scenario scenario unexpectedly succeeded"
  fi

  actual="$(grep -c '^gh:run list' "$log_file" || true)"
  [[ "$actual" -eq "$expected_lists" ]] \
    || fail "Pages $scenario listed runs $actual times; expected $expected_lists"
  actual="$(grep -c '^gh:run watch' "$log_file" || true)"
  [[ "$actual" -eq "$expected_watches" ]] \
    || fail "Pages $scenario watched $actual runs; expected $expected_watches"
  actual="$(grep -c '^curl:' "$log_file" || true)"
  [[ "$actual" -eq "$expected_curls" ]] \
    || fail "Pages $scenario fetched the site $actual times; expected $expected_curls"
  if [[ "$expected_curls" -gt 0 ]]; then
    actual="$(grep -c '^curl:--connect-timeout 10 --max-time 30 -fsSL ' "$log_file" || true)"
    [[ "$actual" -eq "$expected_curls" ]] \
      || fail "Pages $scenario did not bound every site request"
  fi
}

run_pages eventual success 3 1 2
run_pages missing failure 30 0 0
run_pages watch-failure failure 3 1 0

printf '%s\n' 'Pages release tests passed.'
