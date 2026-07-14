#!/usr/bin/env bash

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_status() {
  local expected="$1"
  local actual="${2:-${status:-}}"
  local captured="${output:-}"

  [[ -n "$actual" ]] || fail "assert_status requires a status"
  if [[ "$actual" -ne "$expected" ]]; then
    [[ -z "$captured" ]] || printf '%s\n' "$captured" >&2
    fail "expected exit $expected, got $actual"
  fi
}

assert_equals() {
  local label expected actual

  if [[ "$#" -eq 1 ]]; then
    label="exact output"
    expected="$1"
    actual="${output:-}"
  elif [[ "$#" -eq 3 ]]; then
    label="$1"
    expected="$2"
    actual="$3"
  else
    fail "assert_equals requires EXPECTED or LABEL EXPECTED ACTUAL"
  fi

  [[ "$actual" == "$expected" ]] \
    || fail "$label is '$actual'; expected '$expected'"
}

assert_contains() {
  local label haystack needle

  if [[ "$#" -eq 1 ]]; then
    label="output"
    haystack="${output:-}"
    needle="$1"
  elif [[ "$#" -eq 3 ]]; then
    haystack="$1"
    needle="$2"
    label="$3"
  else
    fail "assert_contains requires NEEDLE or HAYSTACK NEEDLE LABEL"
  fi

  [[ "$haystack" == *"$needle"* ]] \
    || fail "$label does not contain: $needle"
}

assert_not_contains() {
  local label haystack needle

  if [[ "$#" -eq 1 ]]; then
    label="output"
    haystack="${output:-}"
    needle="$1"
  elif [[ "$#" -eq 3 ]]; then
    haystack="$1"
    needle="$2"
    label="$3"
  else
    fail "assert_not_contains requires NEEDLE or HAYSTACK NEEDLE LABEL"
  fi

  [[ "$haystack" != *"$needle"* ]] \
    || fail "$label unexpectedly contains: $needle"
}
