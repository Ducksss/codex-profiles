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

tag_ref_state="$(gh api "repos/$GITHUB_REPOSITORY/git/ref/tags/$release_tag" \
  --jq '[.ref, .object.type, .object.sha] | @tsv')" \
  || release_die "Could not resolve Git tag $release_tag"
IFS=$'\t' read -r tag_ref object_type object_sha <<< "$tag_ref_state"
[[ "$tag_ref" == "refs/tags/$release_tag" \
  && "$object_type" =~ ^(commit|tag)$ \
  && "$object_sha" =~ ^[0-9a-f]{40,64}$ ]] \
  || release_die "Git tag $release_tag did not resolve to a valid Git object"

# Release automation creates annotated tags, while older repositories may have
# lightweight tags. Resolve either form to an exact commit before comparing it
# with main so a same-named branch cannot influence the ancestry check.
for _depth in 1 2 3 4 5; do
  [[ "$object_type" != commit ]] || break
  [[ "$object_type" == tag ]] \
    || release_die "Git tag $release_tag points to unsupported object type $object_type"

  tag_object_state="$(gh api "repos/$GITHUB_REPOSITORY/git/tags/$object_sha" \
    --jq '[.object.type, .object.sha] | @tsv')" \
    || release_die "Could not resolve annotated Git tag $release_tag"
  IFS=$'\t' read -r object_type object_sha <<< "$tag_object_state"
  [[ "$object_type" =~ ^(commit|tag)$ \
    && "$object_sha" =~ ^[0-9a-f]{40,64}$ ]] \
    || release_die "Git tag $release_tag did not resolve to a valid Git object"
done
[[ "$object_type" == commit ]] \
  || release_die "Git tag $release_tag has too many nested tag objects"

tag_commit="$object_sha"
ancestry_state="$(gh api "repos/$GITHUB_REPOSITORY/compare/$tag_commit...main" \
  --jq '[.status, .base_commit.sha, .merge_base_commit.sha, (.behind_by|tostring)] | @tsv')" \
  || release_die "Could not compare Git tag $release_tag with main"
IFS=$'\t' read -r comparison base_commit merge_base behind_by <<< "$ancestry_state"
[[ ( "$comparison" == ahead || "$comparison" == identical ) \
  && "$base_commit" == "$tag_commit" \
  && "$merge_base" == "$tag_commit" \
  && "$behind_by" == 0 ]] \
  || release_die "Pages source $release_tag is not contained in main"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  printf 'commit=%s\n' "$tag_commit" >> "$GITHUB_OUTPUT"
fi
