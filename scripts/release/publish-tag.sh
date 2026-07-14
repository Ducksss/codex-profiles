#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=scripts/release/lib.sh
source "$SCRIPT_DIR/lib.sh"
cd "$ROOT_DIR"

release_require_env TAG
release_require_env TAG_EXISTS
release_require_env VERIFIED_SHA

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
push_error="$tmp/tag-push.err"
tag_error="$tmp/tag-lookup.err"
verify_remote_tag() {
  local tag_status
  local remote_tag_ref="refs/codex-profile-release-check/$TAG"
  local remote_tag_sha

  : > "$tag_error"
  set +e
  git ls-remote --exit-code --tags origin "refs/tags/$TAG" \
    > /dev/null 2> "$tag_error"
  tag_status=$?
  set -e
  [[ "$tag_status" -eq 0 ]] || return 1
  git fetch --no-tags --force origin \
    "refs/tags/$TAG:$remote_tag_ref" 2>> "$tag_error" || return 1
  remote_tag_sha="$(git rev-list -n 1 "$remote_tag_ref" 2>> "$tag_error")" \
    || return 1
  git update-ref -d "$remote_tag_ref" 2>> "$tag_error" || return 1
  [[ "$remote_tag_sha" == "$VERIFIED_SHA" ]]
}

if [[ "$TAG_EXISTS" == "true" ]]; then
  verify_remote_tag || {
    cat "$tag_error" >&2
    echo "Could not verify existing $TAG at $VERIFIED_SHA." >&2
    exit 1
  }
  echo "$TAG already exists at this commit; continuing the release."
  exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git tag -a "$TAG" "$VERIFIED_SHA" -m "codex-profile $TAG"
push_succeeded=false
if git push origin "$TAG" 2> "$push_error"; then
  push_succeeded=true
fi

verify_remote_tag || {
  cat "$push_error" >&2
  cat "$tag_error" >&2
  echo "Could not publish or verify $TAG at $VERIFIED_SHA." >&2
  exit 1
}
if [[ "$push_succeeded" == "true" ]]; then
  echo "Published and verified $TAG at $VERIFIED_SHA."
else
  echo "$TAG was published concurrently; continuing the release."
fi
