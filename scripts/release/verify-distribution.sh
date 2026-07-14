#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=scripts/release/lib.sh
source "$SCRIPT_DIR/lib.sh"
cd "$ROOT_DIR"

mode="${1:-}"

if [[ "$mode" == "tagged-aur" ]]; then
  release_require_env TAG
  release_require_env GITHUB_WORKSPACE
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  (
    cd "$tmp"
    # The release PKGBUILD is executable input to this isolated package check.
    # shellcheck disable=SC1091
    source "$GITHUB_WORKSPACE/packaging/aur/PKGBUILD"
    # shellcheck disable=SC2154 # pkgver is loaded from the PKGBUILD.
    [[ "$TAG" == "v$pkgver" ]] || {
      echo "Release tag $TAG does not match PKGBUILD version $pkgver." >&2
      exit 1
    }

    curl --retry 3 --retry-all-errors --connect-timeout 10 --max-time 60 -fsSL \
      "https://raw.githubusercontent.com/Ducksss/codex-profiles/$TAG/bin/codex-profile" \
      -o "codex-profile-$pkgver"
    curl --retry 3 --retry-all-errors --connect-timeout 10 --max-time 60 -fsSL \
      "https://raw.githubusercontent.com/Ducksss/codex-profiles/$TAG/LICENSE" \
      -o "LICENSE-$pkgver"
    # shellcheck disable=SC2154 # sha256sums is loaded from the PKGBUILD.
    printf '%s  %s\n' \
      "${sha256sums[0]}" "codex-profile-$pkgver" \
      "${sha256sums[1]}" "LICENSE-$pkgver" \
      | sha256sum --check --strict -

    # shellcheck disable=SC2034 # package() consumes makepkg's pkgdir variable.
    pkgdir="$tmp/pkg"
    package
  )
  canonical="$tmp/pkg/usr/bin/codex-profile"
  alias="$tmp/pkg/usr/bin/codex-profiles"
  [[ -f "$canonical" && -x "$canonical" && ! -L "$canonical" ]] || {
    echo "Tagged AUR package has no regular executable codex-profile command." >&2
    exit 1
  }
  [[ -L "$alias" && "$(readlink "$alias")" == codex-profile ]] || {
    echo "Tagged AUR package must install a relative codex-profiles alias." >&2
    exit 1
  }
  [[ "$("$canonical" version 2>&1)" == "codex-profile ${TAG#v}" ]] || {
    echo "Tagged AUR canonical command reported the wrong version." >&2
    exit 1
  }
  [[ "$("$alias" version 2>&1)" == "codex-profile ${TAG#v}" ]] || {
    echo "Tagged AUR plural command reported the wrong version." >&2
    exit 1
  }
  exit 0
fi

if [[ "$mode" == "standalone" ]]; then
  release_require_env TAG
  release_require_env V
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  installer="$tmp/install.sh"
  curl --retry 3 --retry-all-errors --connect-timeout 10 --max-time 60 -fsSL \
    "https://raw.githubusercontent.com/Ducksss/codex-profiles/$TAG/install.sh" \
    -o "$installer"

  verify_installed_prefix() {
    local prefix="$1"
    local canonical="$prefix/bin/codex-profile"
    local alias="$prefix/bin/codex-profiles"
    local canonical_output
    local alias_output

    [[ -f "$canonical" && -x "$canonical" && ! -L "$canonical" ]] || return 1
    [[ -L "$alias" ]] || return 1
    [[ "$(readlink "$alias")" == "codex-profile" ]] || return 1
    canonical_output="$("$canonical" version 2>&1)" || return 1
    [[ "$canonical_output" == "codex-profile $V" ]] || return 1
    alias_output="$("$alias" version 2>&1)" || return 1
    [[ "$alias_output" == "codex-profile $V" ]] || return 1
  }

  standalone_verified=false
  for attempt in {1..5}; do
    prefix="$(mktemp -d "$tmp/prefix-$attempt.XXXXXX")"
    if env -u CODEX_PROFILE_VERSION CODEX_PROFILE_PREFIX="$prefix" sh "$installer" \
      && verify_installed_prefix "$prefix"; then
      standalone_verified=true
      break
    fi
    rm -rf "$prefix"
    if [[ "$attempt" -lt 5 ]]; then
      sleep "$((attempt * 2))"
    fi
  done
  [[ "$standalone_verified" == "true" ]] || {
    echo "The public standalone installer did not install codex-profile $V after 5 attempts." >&2
    exit 1
  }
  exit 0
fi

release_die "Usage: scripts/release/verify-distribution.sh {tagged-aur|standalone}"
