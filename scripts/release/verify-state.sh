#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=scripts/release/lib.sh
source "$SCRIPT_DIR/lib.sh"
cd "$ROOT_DIR"

release_require_env TAG
release_require_env VERIFIED_SHA
release_require_env GITHUB_OUTPUT

git fetch --no-tags origin main
[[ "$(git rev-parse origin/main)" == "$VERIFIED_SHA" ]] || {
  echo "origin/main moved during preflight; refusing to publish $TAG." >&2
  exit 1
}

tag_exists=false
tag_error="$(mktemp)"
trap 'rm -f "$tag_error"' EXIT
set +e
git ls-remote --exit-code --tags origin "refs/tags/$TAG" \
  > /dev/null 2> "$tag_error"
tag_status=$?
set -e
case "$tag_status" in
  0)
    tag_exists=true
    git fetch --no-tags origin "refs/tags/$TAG:refs/tags/$TAG"
    [[ "$(git rev-list -n 1 "$TAG")" == "$VERIFIED_SHA" ]] || {
      echo "$TAG exists but does not point to verified commit $VERIFIED_SHA." >&2
      exit 1
    }
    ;;
  2)
    ;;
  *)
    cat "$tag_error" >&2
    echo "Could not establish whether $TAG already exists." >&2
    exit 1
    ;;
esac
echo "tag_exists=$tag_exists" >> "$GITHUB_OUTPUT"
