#!/bin/sh
# codex-profile installer — fetch the latest release and install the CLI.
#
#   curl -fsSL https://raw.githubusercontent.com/Ducksss/codex-profiles/main/install.sh | sh
#
# Environment:
#   CODEX_PROFILE_PREFIX   Install prefix (default: $HOME/.local; binaries go in $PREFIX/bin).
#   CODEX_PROFILE_VERSION  Install an exact release tag in vX.Y.Z form.
set -eu

REPO="Ducksss/codex-profiles"
PREFIX="${CODEX_PROFILE_PREFIX:-$HOME/.local}"
BINDIR="$PREFIX/bin"

say() { printf '%s\n' "$*"; }
err() { printf 'install: %s\n' "$*" >&2; exit 1; }

valid_release_tag() {
  printf '%s\n' "$1" | LC_ALL=C grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$'
}

path_exists() {
  [ -e "$1" ] || [ -L "$1" ]
}

declared_version() {
  version_file="$1"
  assignment_count="$(grep -c '^VERSION=' "$version_file" || true)"
  [ "$assignment_count" -eq 1 ] || return 1

  sed -n 's/^VERSION="\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)"$/\1/p' \
    "$version_file"
}

if command -v curl > /dev/null 2>&1; then
  dl() { curl -fsSL "$1"; }
elif command -v wget > /dev/null 2>&1; then
  dl() { wget -qO- "$1"; }
else
  err "need curl or wget to download codex-profile"
fi

command -v bash > /dev/null 2>&1 || say "warning: codex-profile needs bash at runtime; install bash to use it."

tag="${CODEX_PROFILE_VERSION:-}"
if [ -z "$tag" ]; then
  tag="$(dl "https://api.github.com/repos/$REPO/releases/latest" \
    | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
  [ -n "$tag" ] || err "could not determine the latest release"
fi
valid_release_tag "$tag" || err "invalid release tag '$tag'; expected vX.Y.Z"

version="${tag#v}"

url="https://raw.githubusercontent.com/$REPO/$tag/bin/codex-profile"
say "Installing codex-profile $tag to $BINDIR"

mkdir -p "$BINDIR" || err "cannot create $BINDIR"
canonical="$BINDIR/codex-profile"
alias="$BINDIR/codex-profiles"

[ ! -d "$canonical" ] || err "refusing directory destination: $canonical"
[ ! -d "$alias" ] || err "refusing directory destination: $alias"

canonical_existed=no
alias_existed=no
if path_exists "$canonical"; then
  canonical_existed=yes
fi
if path_exists "$alias"; then
  alias_existed=yes
fi

transaction="$(mktemp -d "$BINDIR/.codex-profile-install.XXXXXX")" \
  || err "cannot create a transaction directory in $BINDIR"
staged_canonical="$transaction/codex-profile"
staged_alias="$transaction/codex-profiles"
saved_canonical="$transaction/original-codex-profile"
saved_alias="$transaction/original-codex-profiles"
committed=no

remove_install_path() {
  remove_path="$1"
  path_exists "$remove_path" || return 0
  [ ! -d "$remove_path" ] || return 1
  rm -f "$remove_path"
}

rollback_install_path() {
  rollback_path="$1"
  rollback_saved_path="$2"
  rollback_had_original="$3"

  if [ "$rollback_had_original" = yes ]; then
    if path_exists "$rollback_saved_path"; then
      remove_install_path "$rollback_path" || return 1
      mv "$rollback_saved_path" "$rollback_path"
    else
      path_exists "$rollback_path"
    fi
  else
    remove_install_path "$rollback_path"
  fi
}

cleanup_transaction() {
  cleanup_status=$?
  trap - 0
  trap '' HUP INT TERM
  set +e
  rollback_failed=no

  if [ "$committed" != yes ]; then
    rollback_install_path "$canonical" "$saved_canonical" "$canonical_existed" \
      || rollback_failed=yes
    rollback_install_path "$alias" "$saved_alias" "$alias_existed" \
      || rollback_failed=yes
  fi

  if [ "$rollback_failed" = no ] && [ -n "${transaction:-}" ]; then
    rm -rf "$transaction" || rollback_failed=yes
  fi

  if [ "$rollback_failed" = yes ]; then
    printf 'install: rollback failed; recovery files remain in %s\n' \
      "$transaction" >&2
    [ "$cleanup_status" -ne 0 ] || cleanup_status=1
  fi

  exit "$cleanup_status"
}

trap cleanup_transaction 0
trap 'exit 1' HUP INT TERM

dl "$url" > "$staged_canonical" || err "download failed: $url"
head -n 1 "$staged_canonical" | grep -q '^#!/usr/bin/env bash' \
  || err "downloaded file does not look like codex-profile"

payload_version="$(declared_version "$staged_canonical" || true)"
[ -n "$payload_version" ] \
  || err "downloaded file must contain exactly one static VERSION assignment"
[ "$payload_version" = "$version" ] \
  || err "downloaded version $payload_version does not match release $tag"

chmod 755 "$staged_canonical" || err "cannot make downloaded command executable"
ln -s codex-profile "$staged_alias" || err "cannot stage codex-profiles alias"

if path_exists "$canonical"; then
  mv "$canonical" "$saved_canonical" || err "cannot preserve existing $canonical"
fi
if path_exists "$alias"; then
  mv "$alias" "$saved_alias" || err "cannot preserve existing $alias"
fi

mv "$staged_canonical" "$canonical" || err "cannot install $canonical"
mv "$staged_alias" "$alias" || err "cannot install $alias"

if [ ! -f "$canonical" ] || [ ! -x "$canonical" ] || [ -L "$canonical" ]; then
  err "installed canonical command is not a regular executable: $canonical"
fi
if [ ! -L "$alias" ] || [ "$(readlink "$alias")" != codex-profile ]; then
  err "installed plural command is not the expected relative symlink: $alias"
fi

installed_version="$(declared_version "$canonical" || true)"
[ "$installed_version" = "$version" ] \
  || err "installed canonical command does not declare version $version"
expected_output="codex-profile $version"
canonical_output="$("$canonical" version 2>&1)" \
  || err "installed canonical command failed its version check"
[ "$canonical_output" = "$expected_output" ] \
  || err "installed canonical command reported '$canonical_output'; expected '$expected_output'"
alias_output="$("$alias" version 2>&1)" \
  || err "installed plural command failed its version check"
[ "$alias_output" = "$expected_output" ] \
  || err "installed plural command reported '$alias_output'; expected '$expected_output'"

committed=yes
rm -rf "$transaction" || err "cannot remove completed transaction: $transaction"
transaction=""
trap - 0 HUP INT TERM

say "Installed $BINDIR/codex-profile (and codex-profiles alias)"
case ":$PATH:" in
  *":$BINDIR:"*) ;;
  *)
    say ""
    say "$BINDIR is not on your PATH. Add it:"
    say "  export PATH=\"$BINDIR:\$PATH\""
    ;;
esac
say "Next: codex-profile doctor"
