#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=scripts/release/lib.sh
source "$SCRIPT_DIR/lib.sh"
cd "$ROOT_DIR"
[[ -n "${NPM_TOKEN:-}" ]] || { echo "NPM_TOKEN is required." >&2; exit 1; }
[[ -n "${TAP_TOKEN:-}" ]] || { echo "TAP_TOKEN is required." >&2; exit 1; }

registry="https://registry.npmjs.org/"
npm_user=""
if ! npm_user="$(
  NODE_AUTH_TOKEN="$NPM_TOKEN" npm whoami --registry "$registry" 2>/dev/null
)" || [[ -z "$npm_user" ]]; then
  echo "NPM_TOKEN could not authenticate with the npm registry." >&2
  exit 1
fi

npm_owners=""
if ! npm_owners="$(
  NODE_AUTH_TOKEN="$NPM_TOKEN" npm owner ls codex-profile \
    --registry "$registry" 2>/dev/null
)"; then
  echo "NPM_TOKEN could not verify codex-profile ownership." >&2
  exit 1
fi
if ! awk -v expected="$npm_user" '
  $1 == expected { found = 1 }
  END { exit(found ? 0 : 1) }
' <<< "$npm_owners"; then
  echo "The authenticated npm user is not a codex-profile owner." >&2
  exit 1
fi
unset npm_owners npm_user

tap_account_push=""
if ! tap_account_push="$(
  GH_TOKEN="$TAP_TOKEN" gh api repos/Ducksss/homebrew-tap \
    --jq '.permissions.push' 2>/dev/null
)"; then
  echo "TAP_TOKEN could not authenticate for Ducksss/homebrew-tap." >&2
  exit 1
fi
[[ "$tap_account_push" == "true" ]] || {
  echo "The authenticated GitHub account does not report tap push access." >&2
  exit 1
}
echo "Release credential identities passed preflight."
