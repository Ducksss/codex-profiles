#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=scripts/release/lib.sh
source "$SCRIPT_DIR/lib.sh"
cd "$ROOT_DIR"

release_require_env TAG
release_require_env TAG_EXISTS
release_require_env VERIFIED_SHA

set -euo pipefail
if [[ "$TAG_EXISTS" == "true" ]]; then
  echo "$TAG already exists at this commit; continuing the release."
  exit 0
fi
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git tag -a "$TAG" -m "codex-profile $TAG"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
push_error="$tmp/tag-push.err"
if git push origin "$TAG" 2> "$push_error"; then
  exit 0
fi

tag_error="$tmp/tag-lookup.err"
set +e
git ls-remote --exit-code --tags origin "refs/tags/$TAG" \
  > /dev/null 2> "$tag_error"
tag_status=$?
set -e
tag_published_after_failure=false
if [[ "$tag_status" -eq 0 ]]; then
  remote_tag_ref="refs/codex-profile-release-check/$TAG"
  git fetch --no-tags --force origin \
    "refs/tags/$TAG:$remote_tag_ref"
  remote_tag_sha="$(git rev-list -n 1 "$remote_tag_ref")"
  git update-ref -d "$remote_tag_ref"
  if [[ "$remote_tag_sha" == "$VERIFIED_SHA" ]]; then
    tag_published_after_failure=true
  fi
fi
[[ "$tag_published_after_failure" == "true" ]] || {
  cat "$push_error" >&2
  cat "$tag_error" >&2
  echo "Could not publish or verify $TAG at $VERIFIED_SHA." >&2
  exit 1
}
echo "$TAG was published concurrently; continuing the release."
