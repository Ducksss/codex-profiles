#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/test/lib/assertions.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
source "$ROOT_DIR/test/lib/cli-fixtures.sh"

test_upgrade_dry_run_reports_plan_without_mutating_files() {
  local tmp repo cache prefix
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  cache="$tmp/cache/source"
  prefix="$tmp/prefix"
  write_fake_upgrade_repo "$repo" "9.9.9"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_UPGRADE_REPO="$repo" CODEX_PROFILE_UPGRADE_CACHE="$cache" "$SCRIPT" upgrade --dry-run --prefix "$prefix"

  assert_status 0
  assert_contains "Upgrade plan"
  assert_contains "Repository: $repo"
  assert_contains "Ref: main"
  assert_contains "Install prefix: $prefix"
  [[ ! -e "$cache" ]] || fail "upgrade --dry-run created the cache checkout"
  [[ ! -e "$prefix" ]] || fail "upgrade --dry-run created the install prefix"

  rm -rf "$tmp"
}

test_upgrade_fetches_newest_ref_and_installs_to_prefix() {
  local tmp repo cache prefix installed
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  cache="$tmp/cache/source"
  prefix="$tmp/prefix"
  installed="$prefix/bin/codex-profile"
  mkdir -p "$repo"
  init_git_main_branch "$repo"
  write_fake_upgrade_repo "$repo" "1.0.0"
  git -C "$repo" add .
  git -C "$repo" -c user.name=test -c user.email=test@example.com commit -m "v1" >/dev/null

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_UPGRADE_REPO="$repo" CODEX_PROFILE_UPGRADE_CACHE="$cache" "$SCRIPT" upgrade --prefix "$prefix"

  assert_status 0
  assert_contains "Installed codex-profile 1.0.0"
  [[ -x "$installed" ]] || fail "upgrade did not install codex-profile"

  write_fake_upgrade_repo "$repo" "1.0.1"
  git -C "$repo" add .
  git -C "$repo" -c user.name=test -c user.email=test@example.com commit -m "v2" >/dev/null

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_UPGRADE_REPO="$repo" CODEX_PROFILE_UPGRADE_CACHE="$cache" "$SCRIPT" upgrade --prefix "$prefix"

  assert_status 0
  assert_contains "Installed codex-profile 1.0.1"
  run_cmd "$installed" version
  assert_status 0
  assert_equals "codex-profile 1.0.1"

  rm -rf "$tmp"
}

test_upgrade_installs_commit_sha_ref_on_fresh_cache() {
  local tmp repo cache prefix installed sha
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  cache="$tmp/cache/source"
  prefix="$tmp/prefix"
  installed="$prefix/bin/codex-profile"
  mkdir -p "$repo"
  init_git_main_branch "$repo"
  write_fake_upgrade_repo "$repo" "1.0.0"
  git -C "$repo" add .
  git -C "$repo" -c user.name=test -c user.email=test@example.com commit -m "v1" >/dev/null
  sha="$(git -C "$repo" rev-parse HEAD)"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_UPGRADE_REPO="$repo" CODEX_PROFILE_UPGRADE_CACHE="$cache" "$SCRIPT" upgrade --prefix "$prefix" --ref "$sha"

  assert_status 0
  assert_contains "Installed codex-profile 1.0.0"
  run_cmd "$installed" version
  assert_status 0
  assert_equals "codex-profile 1.0.0"

  rm -rf "$tmp"
}

test_upgrade_refuses_dirty_cached_checkout() {
  local tmp repo cache prefix
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  cache="$tmp/cache/source"
  prefix="$tmp/prefix"
  mkdir -p "$repo"
  init_git_main_branch "$repo"
  write_fake_upgrade_repo "$repo" "1.0.0"
  git -C "$repo" add .
  git -C "$repo" -c user.name=test -c user.email=test@example.com commit -m "v1" >/dev/null
  git clone "$repo" "$cache" >/dev/null 2>&1
  printf 'local edit\n' >> "$cache/bin/codex-profile"

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_UPGRADE_REPO="$repo" CODEX_PROFILE_UPGRADE_CACHE="$cache" "$SCRIPT" upgrade --prefix "$prefix"

  assert_status 1
  assert_contains "Cached upgrade checkout has local changes"
  [[ ! -e "$prefix/bin/codex-profile" ]] || fail "upgrade installed from a dirty cache"

  rm -rf "$tmp"
}

test_upgrade_refuses_to_install_older_version() {
  local tmp repo cache prefix
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  cache="$tmp/cache/source"
  prefix="$tmp/prefix"
  mkdir -p "$repo"
  init_git_main_branch "$repo"
  write_fake_upgrade_repo "$repo" "0.1.1"
  git -C "$repo" add .
  git -C "$repo" -c user.name=test -c user.email=test@example.com commit -m "old" >/dev/null

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_UPGRADE_REPO="$repo" CODEX_PROFILE_UPGRADE_CACHE="$cache" "$SCRIPT" upgrade --prefix "$prefix"

  assert_status 1
  assert_contains "Refusing to install older codex-profile 0.1.1"
  [[ ! -e "$prefix/bin/codex-profile" ]] || fail "upgrade installed an older codex-profile"

  rm -rf "$tmp"
}

test_upgrade_refuses_unversioned_candidate() {
  local tmp repo cache prefix
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  cache="$tmp/cache/source"
  prefix="$tmp/prefix"
  mkdir -p "$repo/bin"
  init_git_main_branch "$repo"
  cat > "$repo/bin/codex-profile" <<'FAKE_PROFILE'
#!/usr/bin/env bash
printf 'old unversioned codex-profile\n'
FAKE_PROFILE
  chmod 755 "$repo/bin/codex-profile"
  cat > "$repo/Makefile" <<'FAKE_MAKEFILE'
PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin

.PHONY: install

install:
	install -d "$(BINDIR)"
	install -m 755 bin/codex-profile "$(BINDIR)/codex-profile"
FAKE_MAKEFILE
  git -C "$repo" add .
  git -C "$repo" -c user.name=test -c user.email=test@example.com commit -m "unversioned" >/dev/null

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_UPGRADE_REPO="$repo" CODEX_PROFILE_UPGRADE_CACHE="$cache" "$SCRIPT" upgrade --prefix "$prefix"

  assert_status 1
  assert_contains "Refusing to install candidate without a declared VERSION"
  [[ ! -e "$prefix/bin/codex-profile" ]] || fail "upgrade installed an unversioned codex-profile"

  rm -rf "$tmp"
}

test_upgrade_refuses_checkout_missing_makefile() {
  local tmp repo cache prefix
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  cache="$tmp/cache/source"
  prefix="$tmp/prefix"
  mkdir -p "$repo/bin"
  init_git_main_branch "$repo"
  cat > "$repo/bin/codex-profile" <<'FAKE_PROFILE'
#!/usr/bin/env bash
VERSION="9.9.9"
printf 'codex-profile %s\n' "$VERSION"
FAKE_PROFILE
  chmod 755 "$repo/bin/codex-profile"
  git -C "$repo" add .
  git -C "$repo" -c user.name=test -c user.email=test@example.com commit -m "no makefile" >/dev/null

  run_cmd env HOME="$tmp/home" CODEX_PROFILE_UPGRADE_REPO="$repo" CODEX_PROFILE_UPGRADE_CACHE="$cache" "$SCRIPT" upgrade --prefix "$prefix"

  assert_status 1
  assert_contains "Upgrade checkout is missing Makefile"
  [[ ! -e "$prefix/bin/codex-profile" ]] || fail "upgrade installed despite missing Makefile"

  rm -rf "$tmp"
}

test_update_check_notifies_when_newer_version_is_cached() {
  local tmp cache stub now
  tmp="$(mktemp -d)"
  cache="$tmp/update-check"
  stub="$tmp/latest.json"
  printf '{"version":"9.9.9"}\n' > "$stub"
  now="$(date +%s)"
  printf '%s 9.9.9\n' "$now" > "$cache"

  run_cmd env HOME="$tmp/home" \
    CODEX_PROFILE_FORCE_UPDATE_CHECK=1 \
    CODEX_PROFILE_UPDATE_CACHE="$cache" \
    CODEX_PROFILE_UPDATE_URL="$stub" \
    "$SCRIPT" list

  assert_status 0
  assert_contains "9.9.9 available"

  rm -rf "$tmp"
}

test_update_check_is_silent_when_up_to_date() {
  local tmp cache stub now
  tmp="$(mktemp -d)"
  cache="$tmp/update-check"
  stub="$tmp/latest.json"
  printf '{"version":"0.0.1"}\n' > "$stub"
  now="$(date +%s)"
  printf '%s 0.0.1\n' "$now" > "$cache"

  run_cmd env HOME="$tmp/home" \
    CODEX_PROFILE_FORCE_UPDATE_CHECK=1 \
    CODEX_PROFILE_UPDATE_CACHE="$cache" \
    CODEX_PROFILE_UPDATE_URL="$stub" \
    "$SCRIPT" list

  assert_status 0
  assert_not_contains "available"

  rm -rf "$tmp"
}

test_update_check_respects_disable_env() {
  local tmp cache stub now
  tmp="$(mktemp -d)"
  cache="$tmp/update-check"
  stub="$tmp/latest.json"
  printf '{"version":"9.9.9"}\n' > "$stub"
  now="$(date +%s)"
  printf '%s 9.9.9\n' "$now" > "$cache"

  run_cmd env HOME="$tmp/home" \
    CODEX_PROFILE_FORCE_UPDATE_CHECK=1 \
    CODEX_PROFILE_NO_UPDATE_CHECK=1 \
    CODEX_PROFILE_UPDATE_CACHE="$cache" \
    CODEX_PROFILE_UPDATE_URL="$stub" \
    "$SCRIPT" list

  assert_status 0
  assert_not_contains "available"

  rm -rf "$tmp"
}

test_update_check_is_silent_without_a_terminal() {
  local tmp cache stub now
  tmp="$(mktemp -d)"
  cache="$tmp/update-check"
  stub="$tmp/latest.json"
  printf '{"version":"9.9.9"}\n' > "$stub"
  now="$(date +%s)"
  printf '%s 9.9.9\n' "$now" > "$cache"

  # No force hook: run_cmd captures stdout through a pipe, so it is not a
  # terminal and the check must stay silent.
  run_cmd env HOME="$tmp/home" \
    CODEX_PROFILE_UPDATE_CACHE="$cache" \
    CODEX_PROFILE_UPDATE_URL="$stub" \
    "$SCRIPT" list

  assert_status 0
  assert_not_contains "available"

  rm -rf "$tmp"
}

test_update_check_refreshes_cache_from_source() {
  local tmp cache stub cached_version cached_epoch
  tmp="$(mktemp -d)"
  cache="$tmp/nested/update-check"
  stub="$tmp/latest.json"
  printf '{"version":"9.9.9"}\n' > "$stub"

  run_cmd env HOME="$tmp/home" \
    CODEX_PROFILE_FORCE_UPDATE_CHECK=1 \
    CODEX_PROFILE_UPDATE_SYNC=1 \
    CODEX_PROFILE_UPDATE_CACHE="$cache" \
    CODEX_PROFILE_UPDATE_URL="$stub" \
    "$SCRIPT" list

  assert_status 0
  [[ -f "$cache" ]] || fail "update check did not write its cache file"
  read -r cached_epoch cached_version < "$cache"
  [[ "$cached_version" == "9.9.9" ]] || fail "update cache did not record fetched version (got '$cached_version')"
  [[ "$cached_epoch" =~ ^[0-9]+$ ]] || fail "update cache did not record a numeric timestamp (got '$cached_epoch')"

  rm -rf "$tmp"
}

test_upgrade_dry_run_reports_plan_without_mutating_files
test_upgrade_fetches_newest_ref_and_installs_to_prefix
test_upgrade_installs_commit_sha_ref_on_fresh_cache
test_upgrade_refuses_dirty_cached_checkout
test_upgrade_refuses_to_install_older_version
test_upgrade_refuses_unversioned_candidate
test_upgrade_refuses_checkout_missing_makefile
test_update_check_notifies_when_newer_version_is_cached
test_update_check_is_silent_when_up_to_date
test_update_check_respects_disable_env
test_update_check_is_silent_without_a_terminal
test_update_check_refreshes_cache_from_source
