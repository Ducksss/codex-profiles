#!/usr/bin/env bash

release_die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

release_require_env() {
  local name="$1"

  [[ -n "${!name:-}" ]] || release_die "$name is required"
}

release_version_is_exact() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

release_require_command() {
  local command_name="$1"

  command -v "$command_name" >/dev/null 2>&1 \
    || release_die "required command not found: $command_name"
}

release_temp_dir() {
  local prefix="${1:-codex-profile-release}"

  mktemp -d "${TMPDIR:-/tmp}/${prefix}.XXXXXX"
}

release_retry() {
  local attempts="$1"
  local delay="$2"
  local attempt status
  shift 2

  [[ "$attempts" =~ ^[1-9][0-9]*$ ]] \
    || release_die "retry attempts must be a positive integer"
  [[ "$delay" =~ ^[0-9]+$ ]] \
    || release_die "retry delay must be a non-negative integer"

  status=1
  for ((attempt = 1; attempt <= attempts; attempt += 1)); do
    set +e
    "$@"
    status=$?
    set -e
    [[ "$status" -ne 0 ]] || return 0
    if [[ "$attempt" -lt "$attempts" && "$delay" -gt 0 ]]; then
      sleep "$delay"
    fi
  done
  return "$status"
}
