#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAKEFILE="$ROOT_DIR/Makefile"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

for target in path-smoke-test install-smoke-test npm-package-test; do
  grep -Eq "^${target}:" "$MAKEFILE" || {
    printf 'FAIL: missing %s target\n' "$target" >&2
    exit 1
  }
done

strict_count="$(grep -c 'set -eu;.*mktemp -d' "$MAKEFILE" || true)"
[[ "$strict_count" -eq 3 ]] || {
  printf 'FAIL: expected three strict temporary-directory smoke recipes\n' >&2
  exit 1
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

fake_npm_dir="$tmp_dir/fake-npm-bin"
mkdir -p "$fake_npm_dir"
cat > "$fake_npm_dir/npm" <<'FAKE_NPM'
#!/bin/sh

set -eu

case "${1:-}" in
  pack)
    exit 0
    ;;
  install)
    shift
    prefix=""
    while [ "$#" -gt 0 ]; do
      if [ "$1" = "--prefix" ]; then
        prefix="$2"
        shift 2
      else
        shift
      fi
    done
    [ -n "$prefix" ]
    make install PREFIX="$prefix" >/dev/null
    ;;
  *)
    exit 64
    ;;
esac
FAKE_NPM
chmod 755 "$fake_npm_dir/npm"

mutate_recipe() {
  local target="$1"
  local assertion="$2"
  local mutated="$tmp_dir/${target}.mk"
  local rewritten="$mutated.rewritten"
  local line
  local matches=0

  cp "$MAKEFILE" "$mutated"
  : > "$rewritten"

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "$assertion" ]]; then
      printf '\t\tfalse; \\\n' >> "$rewritten"
      matches=$((matches + 1))
    else
      printf '%s\n' "$line" >> "$rewritten"
    fi
  done < "$mutated"

  [[ "$matches" -eq 1 ]] || fail "expected one assertion to mutate for $target, found $matches"
  mv "$rewritten" "$mutated"
  printf '%s\n' "$mutated"
}

require_target_success() {
  local target="$1"
  local command_path="${2:-$PATH}"

  PATH="$command_path" make -C "$ROOT_DIR" -f "$MAKEFILE" "$target" >/dev/null
}

require_mutation_failure() {
  local target="$1"
  local assertion="$2"
  local command_path="${3:-$PATH}"
  local mutated

  mutated="$(mutate_recipe "$target" "$assertion")"
  if PATH="$command_path" make -C "$ROOT_DIR" -f "$mutated" "$target" >/dev/null 2>&1; then
    fail "$target returned success after its assertion was replaced with false"
  fi
}

for target in path-smoke-test install-smoke-test npm-package-test; do
  require_target_success "$target"
done

require_mutation_failure \
  path-smoke-test \
  $'\t\tHOME="$$tmp_home" bin/codex-profile path default | grep -E \'/\\.codex$$\' >/dev/null; \\'
require_mutation_failure \
  install-smoke-test \
  $'\t\ttest -x "$$tmp_prefix/bin/codex-profile"; \\'
require_target_success npm-package-test "$fake_npm_dir:$PATH"
require_mutation_failure \
  npm-package-test \
  $'\t\t\tnpm pack --dry-run --silent >/dev/null; \\' \
  "$fake_npm_dir:$PATH"

printf '%s\n' 'Makefile smoke tests passed.'
