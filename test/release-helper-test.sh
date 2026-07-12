#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT_DIR/scripts/update-homebrew-formula"
VERSION="0.7.0"
SHA="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
DESCRIPTION="Named Codex CLI profiles with separate local ChatGPT desktop state"
URL="https://github.com/Ducksss/codex-profiles/archive/refs/tags/v$VERSION.tar.gz"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

write_valid_formula() {
  local formula="$1"

  cat > "$formula" <<'RUBY'
class CodexProfile < Formula
  desc "Old description"
  homepage "https://github.com/Ducksss/codex-profiles"
  url "https://example.invalid/old.tar.gz"
  sha256 "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

  def install
    bin.install "bin/codex-profile"
  end

  test do
    system bin/"codex-profile", "help"
  end
end
RUBY
}

assert_line_count() {
  local expected_count="$1"
  local line="$2"
  local file="$3"
  local actual_count

  actual_count="$(grep -Fxc "$line" "$file" || true)"
  [[ "$actual_count" -eq "$expected_count" ]] \
    || fail "expected $expected_count occurrence(s) of '$line', found $actual_count"
}

assert_output_equals() {
  local expected="$1"
  local actual="$2"

  [[ "$actual" == "$expected" ]] \
    || fail "expected output '$expected', got '$actual'"
}

require_missing_anchor_failure() {
  local label="$1"
  local anchor="$2"
  local formula="$tmp_dir/missing-$label.rb"
  local rewritten="$formula.rewritten"
  local before="$formula.before"
  local output
  local status

  write_valid_formula "$formula"
  awk -v anchor="$anchor" '$0 != anchor' "$formula" > "$rewritten"
  mv "$rewritten" "$formula"
  cp "$formula" "$before"

  set +e
  output="$("$HELPER" "$formula" "$VERSION" "$SHA" 2>&1)"
  status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "missing $label anchor unexpectedly succeeded"
  assert_output_equals "Missing Homebrew formula anchor: $label" "$output"
  cmp -s "$before" "$formula" \
    || fail "formula was mutated before the missing $label anchor was reported"
}

require_duplicate_anchor_failure() {
  local label="$1"
  local insertion_anchor="$2"
  local duplicated_line="$3"
  local copies_to_add="$4"
  local formula="$tmp_dir/duplicate-$label.rb"
  local rewritten="$formula.rewritten"
  local before="$formula.before"
  local output
  local status

  write_valid_formula "$formula"
  awk \
    -v insertion_anchor="$insertion_anchor" \
    -v duplicated_line="$duplicated_line" \
    -v copies_to_add="$copies_to_add" '
      {
        print
        if ($0 == insertion_anchor) {
          for (copy = 0; copy < copies_to_add; copy++) {
            print duplicated_line
          }
        }
      }
    ' "$formula" > "$rewritten"
  mv "$rewritten" "$formula"
  cp "$formula" "$before"

  set +e
  output="$("$HELPER" "$formula" "$VERSION" "$SHA" 2>&1)"
  status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "duplicate $label anchor unexpectedly succeeded"
  assert_output_equals "Duplicate Homebrew formula anchor: $label" "$output"
  cmp -s "$before" "$formula" \
    || fail "formula was mutated before the duplicate $label anchor was reported"
}

require_misplaced_anchor_failure() {
  local label="$1"
  local moved_line="$2"
  local wrong_block_start="$3"
  local formula="$tmp_dir/misplaced-$label.rb"
  local rewritten="$formula.rewritten"
  local before="$formula.before"
  local output
  local status

  write_valid_formula "$formula"
  "$HELPER" "$formula" "$VERSION" "$SHA"
  awk -v moved_line="$moved_line" -v wrong_block_start="$wrong_block_start" '
    $0 == moved_line { found += 1; next }
    {
      print
      if ($0 == wrong_block_start) {
        print moved_line
        inserted += 1
      }
    }
    END {
      if (found != 1 || inserted != 1) exit 42
    }
  ' "$formula" > "$rewritten" || fail "could not move $label into the wrong block"
  mv "$rewritten" "$formula"
  cp "$formula" "$before"

  set +e
  output="$("$HELPER" "$formula" "$VERSION" "$SHA" 2>&1)"
  status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "misplaced $label anchor unexpectedly succeeded"
  assert_output_equals "Misplaced Homebrew formula anchor: $label" "$output"
  cmp -s "$before" "$formula" \
    || fail "formula was mutated before the misplaced $label anchor was reported"
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

formula="$tmp_dir/codex-profile.rb"
expected="$tmp_dir/expected.rb"
first_update="$tmp_dir/first-update.rb"

write_valid_formula "$formula"
"$HELPER" "$formula" "$VERSION" "$SHA"

cat > "$expected" <<RUBY
class CodexProfile < Formula
  desc "$DESCRIPTION"
  homepage "https://github.com/Ducksss/codex-profiles"
  url "$URL"
  sha256 "$SHA"

  def install
    bin.install "bin/codex-profile"
    bin.install_symlink bin/"codex-profile" => "codex-profiles"
  end

  test do
    system bin/"codex-profile", "help"
    system bin/"codex-profiles", "version"
  end
end
RUBY

cmp -s "$expected" "$formula" || fail "valid formula did not match the exact expected update"
assert_line_count 1 "  desc \"$DESCRIPTION\"" "$formula"
assert_line_count 1 "  url \"$URL\"" "$formula"
assert_line_count 1 "  sha256 \"$SHA\"" "$formula"
assert_line_count 1 '    bin.install_symlink bin/"codex-profile" => "codex-profiles"' "$formula"
assert_line_count 1 '    system bin/"codex-profiles", "version"' "$formula"

if command -v ruby >/dev/null 2>&1; then
  ruby -c "$formula" >/dev/null
fi

cp "$formula" "$first_update"
"$HELPER" "$formula" "$VERSION" "$SHA"
cmp -s "$first_update" "$formula" || fail "second formula update was not idempotent"
assert_line_count 1 '    bin.install_symlink bin/"codex-profile" => "codex-profiles"' "$formula"
assert_line_count 1 '    system bin/"codex-profiles", "version"' "$formula"

require_missing_anchor_failure desc '  desc "Old description"'
require_missing_anchor_failure url '  url "https://example.invalid/old.tar.gz"'
require_missing_anchor_failure sha256 '  sha256 "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'
require_missing_anchor_failure primary-install '    bin.install "bin/codex-profile"'
require_missing_anchor_failure primary-test '    system bin/"codex-profile", "help"'

require_duplicate_anchor_failure \
  desc \
  '  desc "Old description"' \
  '  desc "Old description"' \
  1
require_duplicate_anchor_failure \
  url \
  '  url "https://example.invalid/old.tar.gz"' \
  '  url "https://example.invalid/old.tar.gz"' \
  1
require_duplicate_anchor_failure \
  sha256 \
  '  sha256 "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' \
  '  sha256 "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' \
  1
require_duplicate_anchor_failure \
  primary-install \
  '    bin.install "bin/codex-profile"' \
  '    bin.install "bin/codex-profile"' \
  1
require_duplicate_anchor_failure \
  primary-test \
  '    system bin/"codex-profile", "help"' \
  '    system bin/"codex-profile", "help"' \
  1
require_duplicate_anchor_failure \
  alias-install \
  '    bin.install "bin/codex-profile"' \
  '    bin.install_symlink bin/"codex-profile" => "codex-profiles"' \
  2
require_duplicate_anchor_failure \
  alias-test \
  '    system bin/"codex-profile", "help"' \
  '    system bin/"codex-profiles", "version"' \
  2

require_misplaced_anchor_failure \
  primary-install \
  '    bin.install "bin/codex-profile"' \
  '  test do'
require_misplaced_anchor_failure \
  alias-install \
  '    bin.install_symlink bin/"codex-profile" => "codex-profiles"' \
  '  test do'
require_misplaced_anchor_failure \
  primary-test \
  '    system bin/"codex-profile", "help"' \
  '  def install'
require_misplaced_anchor_failure \
  alias-test \
  '    system bin/"codex-profiles", "version"' \
  '  def install'

invalid_formula="$tmp_dir/invalid-input.rb"
invalid_before="$tmp_dir/invalid-input.before"
write_valid_formula "$invalid_formula"
cp "$invalid_formula" "$invalid_before"

set +e
output="$("$HELPER" "$invalid_formula" "v$VERSION" "$SHA" 2>&1)"
status=$?
set -e
[[ "$status" -ne 0 ]] || fail "invalid release version unexpectedly succeeded"
assert_output_equals "Invalid release version: v$VERSION" "$output"
cmp -s "$invalid_before" "$invalid_formula" || fail "invalid version mutated the formula"

set +e
output="$("$HELPER" "$invalid_formula" "$VERSION" "${SHA%?}g" 2>&1)"
status=$?
set -e
[[ "$status" -ne 0 ]] || fail "invalid SHA-256 unexpectedly succeeded"
assert_output_equals "Invalid SHA-256: ${SHA%?}g" "$output"
cmp -s "$invalid_before" "$invalid_formula" || fail "invalid SHA-256 mutated the formula"

missing_formula="$tmp_dir/does-not-exist.rb"
set +e
output="$("$HELPER" "$missing_formula" "$VERSION" "$SHA" 2>&1)"
status=$?
set -e
[[ "$status" -ne 0 ]] || fail "missing formula unexpectedly succeeded"
assert_output_equals "Missing Homebrew formula: $missing_formula" "$output"

printf '%s\n' 'Homebrew release helper tests passed.'
