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
    shift
    destination=""
    while [ "$#" -gt 0 ]; do
      if [ "$1" = "--pack-destination" ]; then
        destination="$2"
        shift 2
      else
        shift
      fi
    done
    [ -n "$destination" ]
    : > "$destination/codex-profile-0.7.0.tgz"
    printf '%s\n' '[{"filename":"codex-profile-0.7.0.tgz"}]'
    ;;
  install)
    shift
    prefix=""
    archive=""
    while [ "$#" -gt 0 ]; do
      if [ "$1" = "--prefix" ]; then
        prefix="$2"
        shift 2
      elif [ "${1#-}" = "$1" ]; then
        archive="$1"
        shift
      else
        shift
      fi
    done
    [ -n "$prefix" ]
    [ -f "$archive" ]
    case "$archive" in
      *.tgz) ;;
      *) exit 65 ;;
    esac
    make install PREFIX="$prefix" >/dev/null
    mkdir -p "$prefix/lib/node_modules/codex-profile/bin"
    cp bin/codex-profile "$prefix/lib/node_modules/codex-profile/bin/codex-profile"
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

require_print_then_fail_mutation() {
  local mutated="$tmp_dir/path-smoke-producer.mk"
  local original replacement

  original=$'\t\toutput="$$(HOME="$$tmp_home" bin/codex-profile path default)"; \\'
  replacement=$'\t\toutput="$$(printf \'%s\\n\' "$$tmp_home/.codex"; exit 23)"; \\'
  awk -v original="$original" -v replacement="$replacement" '
    $0 == original { print replacement; replaced += 1; next }
    { print }
    END { if (replaced != 1) exit 42 }
  ' "$MAKEFILE" > "$mutated" || fail "could not create producer-failure mutation"

  if make -C "$ROOT_DIR" -f "$mutated" path-smoke-test >/dev/null 2>&1; then
    fail "path-smoke-test masked a producer that printed a match and exited non-zero"
  fi
}

require_install_destination_safety() {
  local prefix before

  prefix="$tmp_dir/install-canonical-directory"
  mkdir -p "$prefix/bin/codex-profile"
  if make -C "$ROOT_DIR" -f "$MAKEFILE" install PREFIX="$prefix" >/dev/null 2>&1; then
    fail "make install accepted a canonical command directory"
  fi
  [[ -d "$prefix/bin/codex-profile" ]] \
    || fail "make install removed the canonical command directory"
  [[ -z "$(find "$prefix/bin/codex-profile" -mindepth 1 -print -quit)" ]] \
    || fail "make install wrote inside the canonical command directory"
  [[ ! -e "$prefix/bin/codex-profiles" && ! -L "$prefix/bin/codex-profiles" ]] \
    || fail "make install created an alias after rejecting the canonical directory"

  prefix="$tmp_dir/install-canonical-symlink"
  before="$tmp_dir/install-canonical-symlink.before"
  mkdir -p "$prefix/bin"
  printf '%s\n' 'preserve this symlink target' > "$prefix/original-command"
  cp "$prefix/original-command" "$before"
  ln -s ../original-command "$prefix/bin/codex-profile"
  if make -C "$ROOT_DIR" -f "$MAKEFILE" install PREFIX="$prefix" >/dev/null 2>&1; then
    fail "make install accepted a canonical command symlink"
  fi
  [[ -L "$prefix/bin/codex-profile" ]] \
    || fail "make install replaced the canonical command symlink"
  [[ "$(readlink "$prefix/bin/codex-profile")" == ../original-command ]] \
    || fail "make install changed the canonical command symlink target"
  cmp -s "$before" "$prefix/original-command" \
    || fail "make install mutated the canonical symlink target before refusing it"
  [[ ! -e "$prefix/bin/codex-profiles" && ! -L "$prefix/bin/codex-profiles" ]] \
    || fail "make install created an alias after rejecting the canonical symlink"

  prefix="$tmp_dir/install-alias-directory"
  before="$tmp_dir/install-alias-directory.before"
  mkdir -p "$prefix/bin/codex-profiles"
  printf '%s\n' 'preserve this existing canonical command' > "$prefix/bin/codex-profile"
  cp "$prefix/bin/codex-profile" "$before"
  if make -C "$ROOT_DIR" -f "$MAKEFILE" install PREFIX="$prefix" >/dev/null 2>&1; then
    fail "make install accepted a plural command directory"
  fi
  cmp -s "$before" "$prefix/bin/codex-profile" \
    || fail "make install mutated the canonical command before rejecting the alias directory"
  [[ -d "$prefix/bin/codex-profiles" ]] \
    || fail "make install removed the plural command directory"
  [[ -z "$(find "$prefix/bin/codex-profiles" -mindepth 1 -print -quit)" ]] \
    || fail "make install wrote inside the plural command directory"

  prefix="$tmp_dir/install-existing-files"
  mkdir -p "$prefix/bin"
  printf '%s\n' 'old command' > "$prefix/bin/codex-profile"
  ln -s old-target "$prefix/bin/codex-profiles"
  make -C "$ROOT_DIR" -f "$MAKEFILE" install PREFIX="$prefix" >/dev/null
  cmp -s "$ROOT_DIR/bin/codex-profile" "$prefix/bin/codex-profile" \
    || fail "make install did not replace an existing regular command"
  [[ -L "$prefix/bin/codex-profiles" ]] \
    || fail "make install did not replace the existing alias symlink"
  [[ "$(readlink "$prefix/bin/codex-profiles")" == codex-profile ]] \
    || fail "make install did not create the expected relative alias"
}

for target in path-smoke-test install-smoke-test npm-package-test; do
  require_target_success "$target"
done

require_mutation_failure \
  path-smoke-test \
  $'\t\ttest "$$output" = "$$tmp_home/.codex"; \\'
require_print_then_fail_mutation
require_install_destination_safety
require_mutation_failure \
  install-smoke-test \
  $'\t\ttest -x "$$tmp_prefix/bin/codex-profile"; \\'
require_target_success npm-package-test "$fake_npm_dir:$PATH"
require_mutation_failure \
  npm-package-test \
  $'\t\t\tpack_json="$$(npm pack --json --pack-destination "$$tmp_prefix")"; \\' \
  "$fake_npm_dir:$PATH"

printf '%s\n' 'Makefile smoke tests passed.'
