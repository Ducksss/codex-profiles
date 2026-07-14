#!/usr/bin/env bash

release_die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

release_require_env() {
  local name="$1"

  [[ -n "${!name:-}" ]] || release_die "$name is required"
}
