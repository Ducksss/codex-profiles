#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_equals() {
  local label="$1"
  local expected="$2"
  local actual="$3"

  [[ "$actual" == "$expected" ]] || fail "$label is '$actual'; expected '$expected'"
}

version="$(node -p "require('./package.json').version")"
assert_equals "package-lock version" "$version" "$(node -p "require('./package-lock.json').version")"
assert_equals "package-lock root version" "$version" "$(node -p "require('./package-lock.json').packages[''].version")"
assert_equals "CLI version" "$version" "$(sed -n 's/^VERSION="\([^"]*\)"/\1/p' bin/codex-profile | head -n 1)"
assert_equals "docs softwareVersion" "$version" "$(sed -n 's/.*"softwareVersion": "\([^"]*\)".*/\1/p' docs/index.html | head -n 1)"
assert_equals "docs visible version" "$version" "$(sed -n 's|.*<span>v\([0-9][^<]*\)</span>.*|\1|p' docs/index.html | head -n 1)"
assert_equals "PKGBUILD version" "$version" "$(sed -n 's/^pkgver=//p' packaging/aur/PKGBUILD | head -n 1)"
assert_equals ".SRCINFO version" "$version" "$(sed -n 's/^\tpkgver = //p' packaging/aur/.SRCINFO | head -n 1)"

node - <<'NODE'
const pkg = require('./package.json');
const lock = require('./package-lock.json');

if (pkg.name !== 'codex-profile') throw new Error(`unexpected package name: ${pkg.name}`);
if (lock.name !== pkg.name || lock.packages?.['']?.name !== pkg.name) {
  throw new Error('package-lock names do not match package.json');
}
for (const command of ['codex-profile', 'codex-profiles']) {
  if (pkg.bin?.[command] !== 'bin/codex-profile') {
    throw new Error(`${command} must map to bin/codex-profile`);
  }
}
if (pkg.files.some((entry) => entry === 'media' || entry.startsWith('media/'))) {
  throw new Error('historical media must not ship in the npm package');
}
NODE

changelog_version="${version//./\.}"
grep -Eq "^## $changelog_version - [0-9]{4}-[0-9]{2}-[0-9]{2}$" CHANGELOG.md \
  || fail "CHANGELOG.md has no dated $version release section"

# shellcheck disable=SC2016 # fixed strings intentionally contain shell variables
grep -F 'ln -sf codex-profile "$BINDIR/codex-profiles"' install.sh > /dev/null \
  || fail "standalone installer does not create the plural alias"
# shellcheck disable=SC2016 # fixed strings intentionally contain Nix shell variables
grep -F 'ln -s codex-profile "$out/bin/codex-profiles"' flake.nix > /dev/null \
  || fail "Nix package does not create the plural alias"
# shellcheck disable=SC2016 # fixed strings intentionally contain PKGBUILD variables
grep -F 'ln -s codex-profile "$pkgdir/usr/bin/codex-profiles"' packaging/aur/PKGBUILD > /dev/null \
  || fail "Arch package does not create the plural alias"

if install --version 2> /dev/null | grep -q 'GNU coreutils'; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  ln -s "$ROOT_DIR" "$tmp/codex-profiles"
  (
    cd "$tmp"
    # shellcheck disable=SC2034 # consumed by the sourced PKGBUILD package() function
    pkgdir="$tmp/pkg"
    # shellcheck source=../packaging/aur/PKGBUILD disable=SC1091
    source "$ROOT_DIR/packaging/aur/PKGBUILD"
    package
  )

  [[ -x "$tmp/pkg/usr/bin/codex-profile" ]] || fail "Arch package omitted codex-profile"
  [[ -x "$tmp/pkg/usr/bin/codex-profiles" ]] || fail "Arch package omitted codex-profiles"
  "$tmp/pkg/usr/bin/codex-profile" version | grep -F "codex-profile $version" > /dev/null \
    || fail "Arch package installed the wrong version"
fi

printf 'Package metadata and install aliases are consistent for %s.\n' "$version"
