#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=scripts/release/lib.sh
source "$SCRIPT_DIR/lib.sh"
cd "$ROOT_DIR"

release_require_env TAG
release_require_env V
release_require_env GITHUB_RUN_ID
release_require_env GITHUB_RUN_ATTEMPT
release_require_env GITHUB_REPOSITORY
release_require_env GITHUB_SHA

set -euo pipefail
pages_correlation="release-$GITHUB_RUN_ID-$GITHUB_RUN_ATTEMPT"
pages_run_title="Deploy Pages from $TAG ($pages_correlation)"
gh workflow run pages.yml --repo "$GITHUB_REPOSITORY" --ref "$TAG" \
  -f release_correlation="$pages_correlation"
run_id=""
for _attempt in {1..30}; do
  run_id="$(gh run list --repo "$GITHUB_REPOSITORY" --workflow pages.yml \
    --commit "$GITHUB_SHA" --event workflow_dispatch --limit 20 \
    --json databaseId,displayTitle \
    --jq "map(select(.displayTitle == \"$pages_run_title\"))[0].databaseId // empty")"
  [[ -z "$run_id" ]] || break
  sleep 2
done
[[ -n "$run_id" ]] || {
  echo "Pages run was not created for $TAG." >&2
  exit 1
}
gh run watch "$run_id" --repo "$GITHUB_REPOSITORY" --exit-status

site_url="https://ducksss.github.io/codex-profiles/"
deployed=false
for _attempt in {1..30}; do
  if curl -fsSL "$site_url" | grep -F "<span>v$V</span>" >/dev/null; then
    deployed=true
    break
  fi
  sleep 2
done
[[ "$deployed" == "true" ]] || {
  echo "Pages did not report the exact visible v$V marker at $site_url." >&2
  exit 1
}
echo "Verified deployed documentation v$V at $site_url."
