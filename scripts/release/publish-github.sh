#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=scripts/release/lib.sh
source "$SCRIPT_DIR/lib.sh"
cd "$ROOT_DIR"

mode="${1:-}"

if [[ "$mode" == "publish" ]]; then
release_require_env TAG
release_require_env GITHUB_REPOSITORY
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
release_records="$tmp/release-records.jsonl"
lookup_error="$tmp/release-lookup.err"
lookup_release_state() {
  gh api --paginate \
    "/repos/$GITHUB_REPOSITORY/releases?per_page=100" \
    --jq '.[] | @json' > "$release_records" 2> "$lookup_error" \
    || return 1
  node - "$TAG" "$release_records" 2>> "$lookup_error" <<'NODE'
const fs = require('fs');
const [, , expectedTag, file] = process.argv;
const releases = fs.readFileSync(file, 'utf8')
  .split('\n')
  .filter(Boolean)
  .map((line) => JSON.parse(line));
const matching = releases.filter((release) => release.tag_name === expectedTag);
if (matching.length === 0) {
  process.stdout.write('absent');
  process.exit(0);
}
if (matching.length !== 1) {
  throw new Error(`GitHub returned duplicate releases for ${expectedTag}`);
}
const [release] = matching;
if (release.draft !== false) {
  throw new Error(`GitHub Release ${expectedTag} is still a draft`);
}
if (release.prerelease !== false) {
  throw new Error(`GitHub Release ${expectedTag} is still a prerelease`);
}
if (typeof release.published_at !== 'string' || release.published_at.length === 0) {
  throw new Error(`GitHub Release ${expectedTag} has no publication time`);
}
process.stdout.write('public_final');
NODE
}

release_lookup_succeeded=false
release_state=""
for attempt in {1..5}; do
  : > "$lookup_error"
  if release_state="$(lookup_release_state)"; then
    release_lookup_succeeded=true
    break
  fi
  if [[ "$attempt" -lt 5 ]]; then
    sleep "$((attempt * 2))"
  fi
done
[[ "$release_lookup_succeeded" == "true" ]] || {
  cat "$lookup_error" >&2
  echo "Could not establish whether GitHub Release $TAG exists." >&2
  exit 1
}

if [[ "$release_state" == "public_final" ]]; then
  echo "Public final GitHub Release $TAG already exists; continuing the release."
else
  create_error="$tmp/release-create.err"
  release_create_succeeded=false
  if gh release create "$TAG" --repo "$GITHUB_REPOSITORY" \
    --title "codex-profile $TAG" --generate-notes \
    --latest --verify-tag 2> "$create_error"; then
    release_create_succeeded=true
  fi

  release_verified_after_create=false
  for attempt in {1..5}; do
    : > "$lookup_error"
    if release_state="$(lookup_release_state)" \
      && [[ "$release_state" == "public_final" ]]; then
      release_verified_after_create=true
      break
    fi
    if [[ "$attempt" -lt 5 ]]; then
      sleep "$((attempt * 2))"
    fi
  done
  [[ "$release_verified_after_create" == "true" ]] || {
    if [[ "$release_create_succeeded" != "true" ]]; then
      cat "$create_error" >&2
    fi
    cat "$lookup_error" >&2
    echo "Could not create or verify public final GitHub Release $TAG." >&2
    exit 1
  }
  if [[ "$release_create_succeeded" == "true" ]]; then
    echo "Created and verified public final GitHub Release $TAG."
  else
    echo "Public final GitHub Release $TAG was created concurrently; continuing the release."
  fi
fi
exit 0
fi

if [[ "$mode" == "verify" ]]; then
release_require_env TAG
release_require_env GITHUB_REPOSITORY
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
release_json="$tmp/release.json"
release_view_error="$tmp/release-view.err"
release_view_succeeded=false
for attempt in {1..5}; do
  : > "$release_view_error"
  if gh release view "$TAG" --repo "$GITHUB_REPOSITORY" \
    --json tagName,isDraft,isPrerelease,publishedAt,body,isImmutable \
    > "$release_json" 2> "$release_view_error"; then
    release_view_succeeded=true
    break
  fi
  if [[ "$attempt" -lt 5 ]]; then
    sleep "$((attempt * 2))"
  fi
done
[[ "$release_view_succeeded" == "true" ]] || {
  cat "$release_view_error" >&2
  echo "Could not read GitHub Release $TAG after 5 attempts." >&2
  exit 1
}
node - "$TAG" "$release_json" <<'NODE'
const fs = require('fs');
const [, , expectedTag, file] = process.argv;
const release = JSON.parse(fs.readFileSync(file, 'utf8'));
if (release.tagName !== expectedTag) {
  throw new Error(`GitHub Release reported ${release.tagName}; expected ${expectedTag}`);
}
if (release.isDraft !== false) {
  throw new Error(`GitHub Release ${expectedTag} is still a draft`);
}
if (release.isPrerelease !== false) {
  throw new Error(`GitHub Release ${expectedTag} is still a prerelease`);
}
if (typeof release.publishedAt !== 'string' || release.publishedAt.length === 0) {
  throw new Error(`GitHub Release ${expectedTag} has no publication time`);
}
if (release.isImmutable !== true) {
  throw new Error(`GitHub Release ${expectedTag} is not immutable`);
}
if (typeof release.body !== 'string' || release.body.trim().length === 0) {
  throw new Error(`GitHub Release ${expectedTag} has no release notes`);
}
NODE

latest_json="$tmp/latest-release.json"
latest_error="$tmp/latest-release.err"
latest_verified=false
for attempt in {1..5}; do
  : > "$latest_error"
  if gh api "/repos/$GITHUB_REPOSITORY/releases/latest" \
    > "$latest_json" 2> "$latest_error" \
    && node - "$TAG" "$latest_json" 2>> "$latest_error" <<'NODE'
const fs = require('fs');
const [, , expectedTag, file] = process.argv;
const latestRelease = JSON.parse(fs.readFileSync(file, 'utf8'));
if (latestRelease.tag_name !== expectedTag) {
  throw new Error(
    `GitHub latest release reported ${latestRelease.tag_name}; expected ${expectedTag}`,
  );
}
NODE
  then
    latest_verified=true
    break
  fi
  if [[ "$attempt" -lt 5 ]]; then
    sleep "$((attempt * 2))"
  fi
done
[[ "$latest_verified" == "true" ]] || {
  cat "$latest_error" >&2
  echo "GitHub latest release did not resolve to $TAG after 5 attempts." >&2
  exit 1
}
exit 0
fi

release_die "Usage: scripts/release/publish-github.sh {publish|verify}"
