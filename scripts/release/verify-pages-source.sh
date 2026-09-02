#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/release/lib.sh
source "$SCRIPT_DIR/lib.sh"

release_require_env GITHUB_REF
release_require_env GITHUB_REPOSITORY
[[ "$GITHUB_REF" == "refs/heads/main" ]] \
  || release_die "Pages must run from main, not $GITHUB_REF"

release_tag="${RELEASE_TAG:-}"
[[ -n "$release_tag" ]] || exit 0
[[ "$release_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] \
  || release_die "Pages release tag must exactly match vX.Y.Z"
command -v gh >/dev/null 2>&1 || release_die "gh is required to validate a Pages release tag"

state="$(gh api "repos/$GITHUB_REPOSITORY/releases/tags/$release_tag" \
  --jq '[.tag_name, (.immutable|tostring), (.draft|tostring), (.prerelease|tostring)] | @tsv')" \
  || release_die "Could not load GitHub Release $release_tag"
IFS=$'\t' read -r tag immutable draft prerelease <<< "$state"
[[ "$tag" == "$release_tag" && "$immutable" == true \
  && "$draft" == false && "$prerelease" == false ]] \
  || release_die "Pages source $release_tag is not an immutable final GitHub Release"
