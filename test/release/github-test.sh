#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/test/lib/assertions.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM
cd "$ROOT_DIR"

release_fake_bin="$tmp_dir/release-fake-bin"
mkdir -p "$release_fake_bin"
cat > "$release_fake_bin/gh" <<'FAKE_GH_RELEASE'
#!/bin/sh

set -eu

command="${1:-}:${2:-}"
require_repo() {
  case " $* " in
    *' --repo Ducksss/codex-profiles '*) ;;
    *) exit 96 ;;
  esac
}
case "$command" in
  api:--paginate)
    printf '%s\n' 'lookup' >> "$RELEASE_WORKFLOW_TEST_LOG"
    lookup_count="$(grep -Fxc 'lookup' "$RELEASE_WORKFLOW_TEST_LOG")"
    case "$FAKE_GH_RELEASE_SCENARIO" in
      present)
        printf '%s\n' \
          '{"tag_name":"v0.7.0","draft":false,"prerelease":false,"published_at":"2026-07-12T00:00:00Z"}'
        ;;
      absent)
        if grep -Fqx 'create' "$RELEASE_WORKFLOW_TEST_LOG"; then
          printf '%s\n' \
            '{"tag_name":"v0.7.0","draft":false,"prerelease":false,"published_at":"2026-07-12T00:00:00Z"}'
        else
          printf '%s\n' \
            '{"tag_name":"v0.6.0","draft":false,"prerelease":false,"published_at":"2026-07-01T00:00:00Z"}'
        fi
        ;;
      race)
        if grep -Fqx 'create' "$RELEASE_WORKFLOW_TEST_LOG" \
          && [ "$lookup_count" -ge 4 ]; then
          printf '%s\n' \
            '{"tag_name":"v0.7.0","draft":false,"prerelease":false,"published_at":"2026-07-12T00:00:00Z"}'
        else
          printf '%s\n' \
            '{"tag_name":"v0.6.0","draft":false,"prerelease":false,"published_at":"2026-07-01T00:00:00Z"}'
        fi
        ;;
      draft)
        printf '%s\n' \
          '{"tag_name":"v0.7.0","draft":true,"prerelease":false,"published_at":null}'
        ;;
      prerelease)
        printf '%s\n' \
          '{"tag_name":"v0.7.0","draft":false,"prerelease":true,"published_at":"2026-07-12T00:00:00Z"}'
        ;;
      unpublished)
        printf '%s\n' \
          '{"tag_name":"v0.7.0","draft":false,"prerelease":false,"published_at":null}'
        ;;
      transient)
        printf '%s\n' 'HTTP 503: service unavailable' >&2
        exit 1
        ;;
      *) exit 64 ;;
    esac
    ;;
  release:create)
    require_repo "$@"
    case " $* " in
      *' --latest '*) ;;
      *) exit 65 ;;
    esac
    case " $* " in
      *' --verify-tag '*) ;;
      *) exit 66 ;;
    esac
    printf '%s\n' 'create' >> "$RELEASE_WORKFLOW_TEST_LOG"
    case "$FAKE_GH_RELEASE_SCENARIO" in
      absent) ;;
      race) exit 1 ;;
      *) exit 64 ;;
    esac
    ;;
  release:view)
    require_repo "$@"
    printf '%s\n' 'view' >> "$RELEASE_WORKFLOW_TEST_LOG"
    view_count="$(grep -Fxc 'view' "$RELEASE_WORKFLOW_TEST_LOG")"
    case "$FAKE_GH_RELEASE_SCENARIO" in
      present|latest_eventual|latest_malformed|latest_transient|not_latest)
        printf '%s\n' \
          '{"tagName":"v0.7.0","isDraft":false,"isPrerelease":false,"publishedAt":"2026-07-13T00:00:00Z","body":"Release notes","isImmutable":true}'
        ;;
      view_eventual)
        if [ "$view_count" -lt 3 ]; then
          printf '%s\n' 'HTTP 503: service unavailable' >&2
          exit 1
        fi
        printf '%s\n' \
          '{"tagName":"v0.7.0","isDraft":false,"isPrerelease":false,"publishedAt":"2026-07-13T00:00:00Z","body":"Release notes","isImmutable":true}'
        ;;
      draft)
        printf '%s\n' \
          '{"tagName":"v0.7.0","isDraft":true,"isPrerelease":false,"publishedAt":null,"body":"Release notes","isImmutable":true}'
        ;;
      prerelease)
        printf '%s\n' \
          '{"tagName":"v0.7.0","isDraft":false,"isPrerelease":true,"publishedAt":"2026-07-13T00:00:00Z","body":"Release notes","isImmutable":true}'
        ;;
      unpublished)
        printf '%s\n' \
          '{"tagName":"v0.7.0","isDraft":false,"isPrerelease":false,"publishedAt":null,"body":"Release notes","isImmutable":true}'
        ;;
      wrong_tag)
        printf '%s\n' \
          '{"tagName":"v0.6.0","isDraft":false,"isPrerelease":false,"publishedAt":"2026-07-01T00:00:00Z","body":"Release notes","isImmutable":true}'
        ;;
      non_immutable)
        printf '%s\n' \
          '{"tagName":"v0.7.0","isDraft":false,"isPrerelease":false,"publishedAt":"2026-07-13T00:00:00Z","body":"Release notes","isImmutable":false}'
        ;;
      empty_notes)
        printf '%s\n' \
          '{"tagName":"v0.7.0","isDraft":false,"isPrerelease":false,"publishedAt":"2026-07-13T00:00:00Z","body":"   ","isImmutable":true}'
        ;;
      *) exit 64 ;;
    esac
    ;;
  api:*/releases/latest)
    printf '%s\n' 'latest' >> "$RELEASE_WORKFLOW_TEST_LOG"
    latest_count="$(grep -Fxc 'latest' "$RELEASE_WORKFLOW_TEST_LOG")"
    case "$FAKE_GH_RELEASE_SCENARIO" in
      present|view_eventual)
        printf '%s\n' '{"tag_name":"v0.7.0"}'
        ;;
      latest_eventual)
        if [ "$latest_count" -ge 3 ]; then
          printf '%s\n' '{"tag_name":"v0.7.0"}'
        else
          printf '%s\n' '{"tag_name":"v0.6.0"}'
        fi
        ;;
      not_latest)
        printf '%s\n' '{"tag_name":"v0.6.0"}'
        ;;
      latest_malformed)
        printf '%s\n' '{"tag_name":7}'
        ;;
      latest_transient)
        printf '%s\n' 'HTTP 503: service unavailable' >&2
        exit 1
        ;;
      *) exit 64 ;;
    esac
    ;;
  *)
    printf 'unexpected gh invocation: %s\n' "$*" >&2
    exit 64
    ;;
esac
FAKE_GH_RELEASE

cat > "$release_fake_bin/sleep" <<'FAKE_SLEEP'
#!/bin/sh

printf '%s\n' 'sleep' >> "$RELEASE_WORKFLOW_TEST_LOG"
FAKE_SLEEP
chmod 755 "$release_fake_bin/gh" "$release_fake_bin/sleep"

github_release_script=("$ROOT_DIR/scripts/release/publish-github.sh" publish)
require_github_release_scenario() {
  local scenario="$1"
  local expected_status="$2"
  local expected_lookups="$3"
  local expected_creates="$4"
  local expected_sleeps="$5"
  local log="$tmp_dir/release-$scenario.log"
  local status
  local actual

  : > "$log"
  set +e
  PATH="$release_fake_bin:$PATH" \
    RELEASE_WORKFLOW_TEST_LOG="$log" \
    FAKE_GH_RELEASE_SCENARIO="$scenario" \
    GITHUB_REPOSITORY="Ducksss/codex-profiles" \
    TAG="v0.7.0" \
    "${github_release_script[@]}" >"$tmp_dir/release-$scenario.out" 2>&1
  status=$?
  set -e

  if [[ "$expected_status" == "success" ]]; then
    [[ "$status" -eq 0 ]] || fail "GitHub Release $scenario lookup unexpectedly failed"
  else
    [[ "$status" -ne 0 ]] || fail "GitHub Release $scenario lookup unexpectedly succeeded"
  fi

  actual="$(grep -Fxc 'lookup' "$log" || true)"
  [[ "$actual" -eq "$expected_lookups" ]] \
    || fail "GitHub Release $scenario lookup ran $actual time(s); expected $expected_lookups"
  actual="$(grep -Fxc 'create' "$log" || true)"
  [[ "$actual" -eq "$expected_creates" ]] \
    || fail "GitHub Release $scenario create ran $actual time(s); expected $expected_creates"
  actual="$(grep -Fxc 'sleep' "$log" || true)"
  [[ "$actual" -eq "$expected_sleeps" ]] \
    || fail "GitHub Release $scenario backoff ran $actual time(s); expected $expected_sleeps"
}

require_github_release_scenario present success 1 0 0
require_github_release_scenario absent success 2 1 0
require_github_release_scenario race success 4 1 2
require_github_release_scenario transient failure 5 0 4
require_github_release_scenario draft failure 5 0 4
require_github_release_scenario prerelease failure 5 0 4
require_github_release_scenario unpublished failure 5 0 4

github_release_verify_script=("$ROOT_DIR/scripts/release/publish-github.sh" verify)
require_github_release_final_scenario() {
  local scenario="$1"
  local expected_status="$2"
  local expected_latest_calls="$3"
  local expected_sleeps="$4"
  local log="$tmp_dir/release-final-$scenario.log"
  local status
  local actual

  : > "$log"
  set +e
  PATH="$release_fake_bin:$PATH" \
    RELEASE_WORKFLOW_TEST_LOG="$log" \
    FAKE_GH_RELEASE_SCENARIO="$scenario" \
    GITHUB_REPOSITORY="Ducksss/codex-profiles" \
    TAG="v0.7.0" \
    "${github_release_verify_script[@]}" \
      >"$tmp_dir/release-final-$scenario.out" 2>&1
  status=$?
  set -e

  if [[ "$expected_status" == "success" ]]; then
    [[ "$status" -eq 0 ]] || fail "GitHub Release final $scenario verification unexpectedly failed"
  else
    [[ "$status" -ne 0 ]] || fail "GitHub Release final $scenario verification unexpectedly succeeded"
  fi

  actual="$(grep -Fxc 'latest' "$log" || true)"
  [[ "$actual" -eq "$expected_latest_calls" ]] \
    || fail "GitHub Release final $scenario queried latest $actual time(s); expected $expected_latest_calls"
  actual="$(grep -Fxc 'sleep' "$log" || true)"
  [[ "$actual" -eq "$expected_sleeps" ]] \
    || fail "GitHub Release final $scenario slept $actual time(s); expected $expected_sleeps"
  actual="$(grep -Fxc 'view' "$log" || true)"
  if [[ "$scenario" == view_eventual ]]; then
    [[ "$actual" -eq 3 ]] || fail "GitHub Release final view retry ran $actual time(s); expected 3"
  else
    [[ "$actual" -eq 1 ]] || fail "GitHub Release final $scenario viewed $actual time(s); expected 1"
  fi
}

require_github_release_final_scenario present success 1 0
require_github_release_final_scenario view_eventual success 1 2
require_github_release_final_scenario latest_eventual success 3 2
require_github_release_final_scenario draft failure 0 0
require_github_release_final_scenario prerelease failure 0 0
require_github_release_final_scenario unpublished failure 0 0
require_github_release_final_scenario wrong_tag failure 0 0
require_github_release_final_scenario non_immutable failure 0 0
require_github_release_final_scenario empty_notes failure 0 0
require_github_release_final_scenario not_latest failure 5 4
require_github_release_final_scenario latest_malformed failure 5 4
require_github_release_final_scenario latest_transient failure 5 4

printf '%s\n' 'GitHub Release tests passed.'
