#!/usr/bin/env bash

# Replaces the NPM_TOKEN repository secret after checking the new token the
# same way release preflight does. The token is read without echo (or from a
# pipe such as a password manager CLI), reaches npm only through the
# environment of one child process, and reaches GitHub only through stdin, so
# it never appears on screen, in shell history, or in a process argument list.

set -euo pipefail
set +o xtrace

repository="${NPM_TOKEN_REPOSITORY:-Ducksss/codex-profiles}"
package="codex-profile"
registry="https://registry.npmjs.org/"
assume_yes=no

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: scripts/release/set-npm-token.sh [--yes]

Prompts for an npm token without echoing it, confirms that it authenticates
as an owner of $package, then replaces the NPM_TOKEN secret on $repository.
A token can also be piped in, for example from a password manager CLI.

  --yes, -y   Replace the secret without asking for confirmation.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --yes | -y) assume_yes=yes ;;
    --help | -h) usage; exit 0 ;;
    *) die "Unknown option '$1'. See --help." ;;
  esac
  shift
done

command -v gh > /dev/null 2>&1 || die "GitHub CLI (gh) is required."
command -v npm > /dev/null 2>&1 || die "npm is required."
gh auth status > /dev/null 2>&1 || die "Sign in to GitHub first with 'gh auth login'."

token=""
work_dir=""
cleanup() {
  token=""
  unset token
  [[ -z "$work_dir" ]] || rm -rf "$work_dir"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 1' HUP TERM

if [[ -t 0 ]]; then
  printf 'npm token for %s (input hidden): ' "$package" > /dev/tty
  IFS= read -rs token || true
  printf '\n' > /dev/tty
else
  IFS= read -r token || true
fi
# Pasted tokens often carry surrounding whitespace.
token="${token#"${token%%[![:space:]]*}"}"
token="${token%"${token##*[![:space:]]}"}"
[[ -n "$token" ]] || die "No token entered; NPM_TOKEN was not changed."
[[ "$token" =~ ^[[:graph:]]+$ ]] || die "The token contains spaces or control characters; NPM_TOKEN was not changed."
[[ "$token" == npm_* ]] || printf 'Warning: npm tokens normally start with npm_.\n' >&2

# An isolated npm configuration that resolves auth only from NODE_AUTH_TOKEN,
# as setup-node does in CI. Without it, npm could use this machine's own login,
# or an inherited npm_config_* variable, and accept a bad token.
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/set-npm-token.XXXXXX")"
# shellcheck disable=SC2016 # npm expands the placeholder itself
printf '//registry.npmjs.org/:_authToken=${NODE_AUTH_TOKEN}\n' > "$work_dir/npmrc"
: > "$work_dir/global-npmrc"

npm_environment=("PATH=$PATH" "HOME=$work_dir")
for name in TMPDIR HTTPS_PROXY HTTP_PROXY NO_PROXY https_proxy http_proxy no_proxy \
  NODE_EXTRA_CA_CERTS; do
  [[ -z "${!name:-}" ]] || npm_environment+=("$name=${!name}")
done

npm_with_token() {
  (
    cd "$work_dir"
    # A cleared environment keeps npm_config_* variables from overriding the
    # isolated configuration; only the path, proxies and CA bundle carry over.
    env -i "${npm_environment[@]}" NODE_AUTH_TOKEN="$token" \
      NPM_CONFIG_USERCONFIG="$work_dir/npmrc" \
      NPM_CONFIG_GLOBALCONFIG="$work_dir/global-npmrc" \
      npm "$@" --registry "$registry" 2> /dev/null
  )
}

npm_user=""
npm_user="$(npm_with_token whoami)" || npm_user=""
[[ -n "$npm_user" ]] || die "The token could not authenticate with the npm registry; NPM_TOKEN was not changed."

npm_owners=""
npm_owners="$(npm_with_token owner ls "$package")" || \
  die "Could not list $package owners with the token; NPM_TOKEN was not changed."
awk -v expected="$npm_user" '$1 == expected { found = 1 } END { exit(found ? 0 : 1) }' \
  <<< "$npm_owners" || \
  die "npm user '$npm_user' is not an owner of $package; NPM_TOKEN was not changed."

printf 'The token authenticates as %s, an owner of %s.\n' "$npm_user" "$package"
printf 'It must also be allowed to publish %s; npm cannot check that without publishing.\n' "$package"

if [[ "$assume_yes" != yes ]]; then
  [[ -r /dev/tty ]] || die "Cannot ask for confirmation without a terminal; rerun with --yes."
  printf 'Replace the NPM_TOKEN secret on %s? [y/N] ' "$repository" > /dev/tty
  answer=""
  IFS= read -r answer < /dev/tty || true
  case "$answer" in
    y | Y | yes | YES) ;;
    *) die "Cancelled; NPM_TOKEN was not changed." ;;
  esac
fi

# gh reads the value from stdin; printf is a builtin, so no process argument
# ever carries the token.
printf '%s' "$token" | gh secret set NPM_TOKEN --repo "$repository" > /dev/null || \
  die "GitHub did not accept the secret; NPM_TOKEN may be unchanged."
token=""

updated="$(gh secret list --repo "$repository" --json name,updatedAt \
  --jq '.[] | select(.name == "NPM_TOKEN") | .updatedAt' 2> /dev/null || true)"
printf 'Updated NPM_TOKEN on %s%s.\n' "$repository" "${updated:+ at $updated}"
if gh secret list --repo "$repository" --env release --json name \
  --jq '.[].name' 2> /dev/null | grep -qx NPM_TOKEN; then
  printf 'Warning: the release environment has its own NPM_TOKEN, which overrides this repository secret.\n' >&2
fi
printf 'Next: run the Release workflow as a dry run to confirm preflight passes.\n'
