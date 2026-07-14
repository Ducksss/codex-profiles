#!/usr/bin/env bash

set -euo pipefail

# A test process must never inherit scripts/check's inventory stream. If it
# does, this read consumes the next test path and proves later suites can be
# skipped silently. Interactive direct runs have no dispatcher stream.
if [[ ! -t 0 ]] && IFS= read -r leaked_stdin; then
  printf 'FAIL: test process inherited dispatcher inventory on stdin: %s\n' \
    "$leaked_stdin" >&2
  exit 1
fi

printf '%s\n' 'Test process input is isolated from dispatcher inventory.'
