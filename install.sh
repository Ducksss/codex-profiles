#!/bin/sh
# codex-profile installer — fetch the latest release and install the CLI.
#
#   curl -fsSL https://raw.githubusercontent.com/Ducksss/codex-profiles/main/install.sh | sh
#
# Environment:
#   CODEX_PROFILE_PREFIX   Install prefix (default: $HOME/.local; binaries go in $PREFIX/bin).
#   CODEX_PROFILE_VERSION  Install a specific tag (e.g. v0.5.0) instead of the latest release.
set -eu

REPO="Ducksss/codex-profiles"
PREFIX="${CODEX_PROFILE_PREFIX:-$HOME/.local}"
BINDIR="$PREFIX/bin"

say() { printf '%s\n' "$*"; }
err() { printf 'install: %s\n' "$*" >&2; exit 1; }

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

url="https://raw.githubusercontent.com/$REPO/$tag/bin/codex-profile"
say "Installing codex-profile $tag to $BINDIR"

mkdir -p "$BINDIR" || err "cannot create $BINDIR"
tmp="$(mktemp)" || err "cannot create a temporary file"
trap 'rm -f "$tmp"' EXIT
dl "$url" > "$tmp" || err "download failed: $url"
head -n 1 "$tmp" | grep -q '^#!/usr/bin/env bash' || err "downloaded file does not look like codex-profile"

chmod 755 "$tmp"
mv "$tmp" "$BINDIR/codex-profile" || err "cannot install to $BINDIR"
trap - EXIT
ln -sf codex-profile "$BINDIR/codex-profiles"

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
