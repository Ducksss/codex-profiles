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

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
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

node - <<'NODE'
const pkg = require('./package.json');
for (const keyword of ['codex-account-switcher', 'multiple-accounts']) {
  if (pkg.keywords.includes(keyword)) {
    throw new Error(`unverified account-switching keyword must be removed: ${keyword}`);
  }
}
if (!pkg.description.includes('separate local ChatGPT desktop state')) {
  throw new Error('package description must state the local-state boundary');
}
NODE

changelog_version="${version//./\.}"
grep -Eq "^## $changelog_version - [0-9]{4}-[0-9]{2}-[0-9]{2}$" CHANGELOG.md \
  || fail "CHANGELOG.md has no dated $version release section"

# shellcheck disable=SC2016 # fixed strings intentionally contain shell variables
grep -F 'ln -s codex-profile "$staged_alias"' install.sh > /dev/null \
  || fail "standalone installer does not stage a relative plural alias"
# shellcheck disable=SC2016 # fixed strings intentionally contain shell variables
grep -F 'mv "$staged_alias" "$alias"' install.sh > /dev/null \
  || fail "standalone installer does not transactionally install the plural alias"
# shellcheck disable=SC2016 # fixed strings intentionally contain shell variables
grep -F '[ -L "$alias" ] && [ "$(readlink "$alias")" = codex-profile ]' install.sh > /dev/null \
  || fail "standalone installer does not verify the relative plural alias"
# shellcheck disable=SC2016 # fixed strings intentionally contain Nix shell variables
grep -F 'ln -s codex-profile "$out/bin/codex-profiles"' flake.nix > /dev/null \
  || fail "Nix package does not create the plural alias"
[[ -f flake.lock ]] || fail "Nix flake inputs must be locked"
node - <<'NODE'
const fs = require('fs');
const lock = JSON.parse(fs.readFileSync('flake.lock', 'utf8'));
if (lock.version !== 7 || lock.root !== 'root') {
  throw new Error('flake.lock must use the current lock schema and root node');
}
for (const name of ['nixpkgs', 'flake-utils', 'systems']) {
  const input = lock.nodes?.[name]?.locked;
  if (!input || !/^[0-9a-f]{40}$/.test(input.rev ?? '')) {
    throw new Error(`${name} must resolve to an immutable 40-hex revision`);
  }
  if (!/^sha256-[A-Za-z0-9+/]+=*$/.test(input.narHash ?? '')) {
    throw new Error(`${name} must include a NAR integrity hash`);
  }
}
NODE
grep -F 'nix build .# --no-update-lock-file --print-build-logs' .github/workflows/ci.yml > /dev/null \
  || fail "Nix CI must build the committed lock without updating it"
grep -F 'git diff --exit-code -- flake.lock' .github/workflows/ci.yml > /dev/null \
  || fail "Nix CI must verify that the lockfile remained unchanged"
# shellcheck disable=SC2016 # fixed strings intentionally contain PKGBUILD variables
grep -F 'ln -s codex-profile "$pkgdir/usr/bin/codex-profiles"' packaging/aur/PKGBUILD > /dev/null \
  || fail "Arch package does not create the plural alias"

cli_sha256="$(sha256_file bin/codex-profile)"
license_sha256="$(sha256_file LICENSE)"
script_source="codex-profile-$version::https://raw.githubusercontent.com/Ducksss/codex-profiles/v$version/bin/codex-profile"
license_source="LICENSE-$version::https://raw.githubusercontent.com/Ducksss/codex-profiles/v$version/LICENSE"

(
  source=()
  sha256sums=()
  # shellcheck source=../packaging/aur/PKGBUILD disable=SC1091
  source packaging/aur/PKGBUILD
  [[ "${source[*]}" != *'git+'* ]] || fail "AUR source must not use VCS checkout"
  [[ "${sha256sums[*]}" != *'SKIP'* ]] || fail "AUR source checksums must not be skipped"
  [[ "${#source[@]}" -eq 2 && "${#sha256sums[@]}" -eq 2 ]] || fail "AUR must pin script and license"
  [[ "${source[0]}" == "$script_source" ]] || fail "AUR script source mismatch"
  [[ "${source[1]}" == "$license_source" ]] || fail "AUR license source mismatch"
  [[ "${sha256sums[0]}" == "$cli_sha256" ]] || fail "CLI checksum mismatch"
  [[ "${sha256sums[1]}" == "$license_sha256" ]] || fail "license checksum mismatch"
)

assert_equals ".SRCINFO source count" "2" "$(grep -c $'^\tsource = ' packaging/aur/.SRCINFO)"
assert_equals ".SRCINFO checksum count" "2" "$(grep -c $'^\tsha256sums = ' packaging/aur/.SRCINFO)"
grep -F $'\tsource = '"$script_source" packaging/aur/.SRCINFO > /dev/null \
  || fail ".SRCINFO script source mismatch"
grep -F $'\tsource = '"$license_source" packaging/aur/.SRCINFO > /dev/null \
  || fail ".SRCINFO license source mismatch"
grep -F $'\tsha256sums = '"$cli_sha256" packaging/aur/.SRCINFO > /dev/null \
  || fail ".SRCINFO CLI checksum mismatch"
grep -F $'\tsha256sums = '"$license_sha256" packaging/aur/.SRCINFO > /dev/null \
  || fail ".SRCINFO license checksum mismatch"
if grep -F $'\tmakedepends = git' packaging/aur/.SRCINFO > /dev/null; then
  fail ".SRCINFO must not require git"
fi

if install --version 2> /dev/null | grep -q 'GNU coreutils'; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  cp "$ROOT_DIR/bin/codex-profile" "$tmp/codex-profile-$version"
  cp "$ROOT_DIR/LICENSE" "$tmp/LICENSE-$version"
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
