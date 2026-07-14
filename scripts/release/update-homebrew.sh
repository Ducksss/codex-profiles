#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=scripts/release/lib.sh
source "$SCRIPT_DIR/lib.sh"
cd "$ROOT_DIR"

release_require_env TAP_TOKEN
release_require_env V

set -euo pipefail
tarball="https://github.com/Ducksss/codex-profiles/archive/refs/tags/v$V.tar.gz"
if command -v sha256sum >/dev/null 2>&1; then
  hash_command=(sha256sum)
elif command -v shasum >/dev/null 2>&1; then
  hash_command=(shasum -a 256)
else
  release_die "sha256sum or shasum is required"
fi
sha="$(
  curl --retry 3 --retry-all-errors --connect-timeout 10 --max-time 120 -fsSL "$tarball" \
    | "${hash_command[@]}" \
    | awk '{ print $1 }'
)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git clone --depth 1 \
  "https://x-access-token:${TAP_TOKEN}@github.com/Ducksss/homebrew-tap.git" \
  "$tmp/tap"
formula="$tmp/tap/Formula/codex-profile.rb"
scripts/update-homebrew-formula "$formula" "$V" "$sha"
ruby -c "$formula"

git -C "$tmp/tap" config user.name "github-actions[bot]"
git -C "$tmp/tap" config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git -C "$tmp/tap" add -A
if git -C "$tmp/tap" diff --cached --quiet; then
  echo "Homebrew formula already matches v$V."
else
  git -C "$tmp/tap" commit -m "codex-profile $V"
  git -C "$tmp/tap" push
fi
