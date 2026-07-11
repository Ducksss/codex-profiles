#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT_DIR/install.sh"
VERSION="0.7.0"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

fake_bin="$tmp_dir/fake-bin"
mkdir -p "$fake_bin" "$tmp_dir/home"

cat > "$fake_bin/curl" <<'FAKE_CURL'
#!/bin/sh

set -eu

for argument do
  url="$argument"
done

case "$url" in
  https://api.github.com/repos/Ducksss/codex-profiles/releases/latest)
    printf '%s\n' '{"tag_name":"v0.7.0"}'
    ;;
  https://raw.githubusercontent.com/Ducksss/codex-profiles/v0.7.0/bin/codex-profile)
    cat "$INSTALL_TEST_CLI_FIXTURE"
    ;;
  *)
    printf 'unexpected installer URL: %s\n' "$url" >&2
    exit 22
    ;;
esac
FAKE_CURL
chmod 755 "$fake_bin/curl"

prefix="$tmp_dir/prefix"
PATH="$fake_bin:$PATH" \
  HOME="$tmp_dir/home" \
  CODEX_PROFILE_PREFIX="$prefix" \
  INSTALL_TEST_CLI_FIXTURE="$ROOT_DIR/bin/codex-profile" \
  sh "$INSTALLER" >/dev/null

[[ -x "$prefix/bin/codex-profile" ]] || fail "standalone installer did not install an executable"
[[ -L "$prefix/bin/codex-profiles" ]] || fail "standalone installer did not install the plural symlink"
"$prefix/bin/codex-profile" version | grep -Fx "codex-profile $VERSION" >/dev/null \
  || fail "standalone installer installed the wrong CLI version"
"$prefix/bin/codex-profiles" help >/dev/null \
  || fail "standalone installer plural alias could not run help"

invalid_fixture="$tmp_dir/invalid-codex-profile"
invalid_prefix="$tmp_dir/invalid-prefix"
printf '%s\n' 'not a codex-profile executable' > "$invalid_fixture"

set +e
PATH="$fake_bin:$PATH" \
  HOME="$tmp_dir/home" \
  CODEX_PROFILE_PREFIX="$invalid_prefix" \
  INSTALL_TEST_CLI_FIXTURE="$invalid_fixture" \
  sh "$INSTALLER" >"$tmp_dir/invalid-install.out" 2>&1
status=$?
set -e

[[ "$status" -ne 0 ]] || fail "standalone installer accepted an invalid download"
[[ ! -e "$invalid_prefix/bin/codex-profile" ]] \
  || fail "standalone installer left an executable after rejecting an invalid download"

printf '%s\n' 'Standalone installer tests passed.'
