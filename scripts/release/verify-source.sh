#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=scripts/release/lib.sh
source "$SCRIPT_DIR/lib.sh"
cd "$ROOT_DIR"

release_require_env INPUT_VERSION
release_require_env DRY_RUN
release_require_env GITHUB_REF
release_require_env GITHUB_SHA
release_require_env GITHUB_OUTPUT

if [[ "$GITHUB_REF" != "refs/heads/main" ]]; then
  echo "Releases must be dispatched from the main branch, not $GITHUB_REF." >&2
  exit 1
fi

if [[ "$DRY_RUN" != "true" ]]; then
  desktop_smoke_attestation="${DESKTOP_SMOKE_ATTESTATION:-}"
  [[ -n "$desktop_smoke_attestation" ]] || {
    echo "Signed-app smoke attestation is required for a live release." >&2
    exit 1
  }
  [[ "$desktop_smoke_attestation" == *ChatGPT* ]] || {
    echo "Signed-app smoke attestation must contain the tested ChatGPT version." >&2
    exit 1
  }
  [[ "$desktop_smoke_attestation" == *com.openai.* ]] || {
    echo "Signed-app smoke attestation must contain the tested bundle ID beginning with com.openai." >&2
    exit 1
  }
  attestation_pattern='^ChatGPT version [0-9]+\.[0-9]+(\.[0-9]+)?; bundle ID com\.openai\.[A-Za-z0-9]+([.-][A-Za-z0-9]+)*$'
  if ! [[ "$desktop_smoke_attestation" =~ $attestation_pattern ]]; then
    echo "Signed-app smoke attestation must exactly match: ChatGPT version X.Y[.Z]; bundle ID com.openai.<identifier>." >&2
    exit 1
  fi

  release_require_env GITHUB_STEP_SUMMARY
  sanitized_attestation="$(
    printf '%s' "$desktop_smoke_attestation" \
      | tr '\r\n' '  ' \
      | sed 's/[[:cntrl:]]//g; s/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
  )"
  printf 'Signed-app smoke attestation: <code>%s</code>\n' \
    "$sanitized_attestation" >> "$GITHUB_STEP_SUMMARY"
fi

version="$INPUT_VERSION"
if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version '$version' is not an exact X.Y.Z release version." >&2
  exit 1
fi

check_version() {
  local source="$1"
  local declared="$2"
  if [[ "$declared" != "$version" ]]; then
    printf '%s declares %q; expected %q.\n' "$source" "$declared" "$version" >&2
    exit 1
  fi
}

check_version package.json "$(node -p "require('./package.json').version")"
check_version package-lock.json "$(node -p "require('./package-lock.json').version")"
check_version package-lock-root "$(node -p "require('./package-lock.json').packages[''].version")"
check_version bin/codex-profile "$(sed -n 's/^VERSION="\([^"]*\)"/\1/p' bin/codex-profile | head -n 1)"
check_version docs/index.html "$(sed -n 's/.*"softwareVersion": "\([^"]*\)".*/\1/p' docs/index.html | head -n 1)"
check_version docs-visible-version "$(sed -n 's|.*<span>v\([0-9][^<]*\)</span>.*|\1|p' docs/index.html | head -n 1)"
check_version packaging/aur/PKGBUILD "$(sed -n 's/^pkgver=//p' packaging/aur/PKGBUILD | head -n 1)"
check_version packaging/aur/.SRCINFO "$(sed -n 's/^\tpkgver = //p' packaging/aur/.SRCINFO | head -n 1)"
grep -F "https://raw.githubusercontent.com/Ducksss/codex-profiles/v$version/install.sh" README.md >/dev/null \
  || { echo "README.md standalone installer must use immutable v$version." >&2; exit 1; }
grep -F "CODEX_PROFILE_VERSION=v$version sh" README.md >/dev/null \
  || { echo "README.md standalone installer must request v$version." >&2; exit 1; }
grep -F "github:Ducksss/codex-profiles/v$version" README.md >/dev/null \
  || { echo "README.md Nix commands must use immutable v$version." >&2; exit 1; }
grep -F "https://raw.githubusercontent.com/Ducksss/codex-profiles/v$version/install.sh" docs/llms.txt >/dev/null \
  || { echo "docs/llms.txt standalone installer must use immutable v$version." >&2; exit 1; }
grep -F "CODEX_PROFILE_VERSION=v$version sh" docs/llms.txt >/dev/null \
  || { echo "docs/llms.txt standalone installer must request v$version." >&2; exit 1; }
grep -F "github:Ducksss/codex-profiles/v$version" docs/llms.txt >/dev/null \
  || { echo "docs/llms.txt Nix command must use immutable v$version." >&2; exit 1; }
grep -F "https://raw.githubusercontent.com/Ducksss/codex-profiles/v$version/install.sh" install.sh >/dev/null \
  || { echo "install.sh usage must use immutable v$version." >&2; exit 1; }
for public_document in README.md docs/llms.txt install.sh; do
  while IFS= read -r installer_reference; do
    [[ "$installer_reference" == "https://raw.githubusercontent.com/Ducksss/codex-profiles/v$version/install.sh" ]] \
      || { echo "$public_document publishes non-release installer reference $installer_reference." >&2; exit 1; }
  done < <(grep -Eo 'https://raw\.githubusercontent\.com/Ducksss/codex-profiles/[^[:space:]]+' "$public_document" || true)
  while IFS= read -r nix_reference; do
    [[ "$nix_reference" == "github:Ducksss/codex-profiles/v$version" ]] \
      || { echo "$public_document publishes non-release Nix reference $nix_reference." >&2; exit 1; }
  done < <(grep -Eo 'github:Ducksss/codex-profiles[^[:space:]]*' "$public_document" || true)
done

changelog_version="${version//./\.}"
if ! grep -Eq "^## $changelog_version - [0-9]{4}-[0-9]{2}-[0-9]{2}$" CHANGELOG.md; then
  echo "CHANGELOG.md must contain a dated '## $version - YYYY-MM-DD' section before release." >&2
  exit 1
fi

node - <<'NODE'
const pkg = require('./package.json');
const lock = require('./package-lock.json');
if (pkg.name !== 'codex-profile') {
  throw new Error(`package name must remain codex-profile, got ${pkg.name}`);
}
if (lock.name !== pkg.name || lock.packages?.['']?.name !== pkg.name) {
  throw new Error('package-lock.json package names must match package.json');
}
for (const command of ['codex-profile', 'codex-profiles']) {
  if (pkg.bin?.[command] !== 'bin/codex-profile') {
    throw new Error(`${command} must map to bin/codex-profile`);
  }
}
NODE

# shellcheck disable=SC2016
grep -F 'ln -s codex-profile "$staged_alias"' install.sh >/dev/null
# shellcheck disable=SC2016
grep -F 'mv "$staged_alias" "$alias"' install.sh >/dev/null
# shellcheck disable=SC2016
grep -F 'if [ ! -L "$alias" ] || [ "$(readlink "$alias")" != codex-profile ]; then' install.sh >/dev/null
grep -F "ln -s codex-profile \"\$out/bin/codex-profiles\"" flake.nix >/dev/null
grep -F "ln -s codex-profile \"\$pkgdir/usr/bin/codex-profiles\"" packaging/aur/PKGBUILD >/dev/null

git fetch --no-tags origin main
head_commit="$(git rev-parse HEAD)"
main_commit="$(git rev-parse origin/main)"
if [[ "$head_commit" != "$main_commit" ]]; then
  echo "The checked-out commit is not the current origin/main tip." >&2
  exit 1
fi
if [[ "$GITHUB_SHA" != "$head_commit" ]]; then
  echo "Workflow commit $GITHUB_SHA does not match the checked-out commit $head_commit." >&2
  exit 1
fi

tag="v$version"
tag_exists=false
if git show-ref --verify --quiet "refs/tags/$tag"; then
  tag_exists=true
  if [[ "$(git rev-list -n 1 "$tag")" != "$head_commit" ]]; then
    echo "$tag already points to a different commit; refusing to move it." >&2
    exit 1
  fi
fi

{
  echo "version=$version"
  echo "tag=$tag"
  echo "tag_exists=$tag_exists"
  echo "commit=$head_commit"
} >> "$GITHUB_OUTPUT"
echo "Validated tracked release $tag at $head_commit."
