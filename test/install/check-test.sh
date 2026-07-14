#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHECK="$ROOT_DIR/scripts/check"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"

  [[ "$haystack" == *"$needle"* ]] || fail "$label: missing $needle"
}

[[ -x "$CHECK" ]] || fail "missing executable scripts/check"

list_output="$("$CHECK" list)"
assert_contains "$list_output" $'shell\tbin/codex-profile' "runtime inventory"
assert_contains "$list_output" $'shell\tinstall.sh' "installer inventory"
assert_contains "$list_output" $'shell\tscripts/check' "dispatcher inventory"
assert_contains "$list_output" $'bash-test\ttest/install/check-test.sh' "Bash test inventory"
assert_contains "$list_output" $'shell\ttest/lib/assertions.sh' "Bash helper inventory"
assert_contains "$list_output" $'node\ttest/lib/assertions.mjs' "Node assertion inventory"
assert_contains "$list_output" $'node\ttest/lib/fixtures.mjs' "Node fixture inventory"
assert_contains "$list_output" $'bash-test\ttest/install/standalone-test.sh' "standalone test inventory"
assert_contains "$list_output" $'bash-test\ttest/install/makefile-test.sh' "Make test inventory"
assert_contains "$list_output" $'bash-test\ttest/install/npm-package-test.sh' "npm test inventory"
assert_contains "$list_output" $'bash-test\ttest/packaging/metadata-test.sh' "metadata test inventory"
assert_contains "$list_output" $'node-test\ttest/packaging/aur-test.mjs' "AUR test inventory"
assert_contains "$list_output" $'node-test\ttest/site/geo-test.mjs' "site test inventory"
assert_contains "$list_output" $'node-test\ttest/outreach/tracker-test.mjs' "outreach tracker inventory"
assert_contains "$list_output" $'node-test\ttest/outreach/agent-test.mjs' "outreach agent inventory"
assert_contains "$list_output" $'node-test\ttest/outreach/skills-test.mjs' "outreach skills inventory"

if [[ "$list_output" == *'test/fixtures/'* ]]; then
  fail "fixture files must not appear in the executable inventory"
fi

for old_path in \
  test/install-script-test.sh \
  test/makefile-smoke-test.sh \
  test/package-metadata-test.sh \
  test/aur-runbook-test.mjs \
  test/geo-site-test.mjs \
  test/outreach-tracker-test.mjs \
  test/outreach-agent-test.mjs \
  test/github-pipeline-skills-test.mjs; do
  if [[ "$list_output" == *$'\t'"$old_path"* ]]; then
    fail "obsolete test path remains in inventory: $old_path"
  fi
done

sorted_output="$(printf '%s\n' "$list_output" | LC_ALL=C sort)"
[[ "$list_output" == "$sorted_output" ]] || fail "inventory must be bytewise sorted"

set +e
unknown_output="$("$CHECK" unsupported 2>&1)"
unknown_status=$?
set -e
[[ "$unknown_status" -ne 0 ]] || fail "unknown command must fail"
assert_contains "$unknown_output" \
  'Usage: scripts/check {list|syntax|test|lint|all}' \
  "unknown command usage"

fake_bin="$TMP_ROOT/bin"
capture="$TMP_ROOT/shellcheck-arguments"
mkdir -p "$fake_bin"
cat > "$fake_bin/shellcheck" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "$SHELLCHECK_CAPTURE"
SH
chmod +x "$fake_bin/shellcheck"

PATH="$fake_bin:$PATH" SHELLCHECK_CAPTURE="$capture" "$CHECK" lint

expected_shell_paths="$(
  printf '%s\n' "$list_output" \
    | awk -F '\t' '$1 == "shell" { print $2 }'
)"
actual_shell_paths="$(LC_ALL=C sort -u "$capture")"
[[ "$actual_shell_paths" == "$expected_shell_paths" ]] || {
  printf 'Expected ShellCheck inventory:\n%s\n' "$expected_shell_paths" >&2
  printf 'Actual ShellCheck inventory:\n%s\n' "$actual_shell_paths" >&2
  fail "lint must use the canonical shell inventory"
}

makefile="$(<"$ROOT_DIR/Makefile")"
ci_workflow="$(<"$ROOT_DIR/.github/workflows/ci.yml")"
package_json="$(<"$ROOT_DIR/package.json")"

assert_contains "$makefile" $'lint:\n\tscripts/check lint' "Make lint delegation"
assert_contains "$makefile" $'test:\n\tscripts/check test' "Make test delegation"
assert_contains "$makefile" $'check:\n\tscripts/check all' "Make check delegation"
assert_contains "$makefile" 'check path-smoke-test' "Make phony check target"

assert_contains "$ci_workflow" 'run: make check' "Linux CI check delegation"
if [[ "$ci_workflow" == *'run: bash test/package-metadata-test.sh'* ]]; then
  fail "CI must not repeat package metadata already covered by make check"
fi
if [[ "$ci_workflow" == *'name: Verify install target'* ]]; then
  fail "macOS CI must not repeat the Make install smoke test"
fi

assert_contains "$package_json" '"check": "make check"' "npm check alias"

set +e
assertion_probe="$({
  bash -c 'source "$1"; assert_equals "probe label" expected actual' \
    _ "$ROOT_DIR/test/lib/assertions.sh"
} 2>&1)"
assertion_status=$?
set -e
[[ "$assertion_status" -ne 0 ]] || fail "assert_equals mismatch must fail"
assert_contains "$assertion_probe" 'FAIL: probe label' "shared assertion failure"

# shellcheck disable=SC2016 # JavaScript template literal is intentionally quoted from Bash.
node --input-type=module -e '
  import { rm } from "node:fs/promises";
  import { assertIncludes } from "./test/lib/assertions.mjs";
  import { makeTempRoot, writeExecutable } from "./test/lib/fixtures.mjs";
  const root = await makeTempRoot("codex-profile-helper-");
  const executable = `${root}/probe`;
  await writeExecutable(executable, "#!/bin/sh\\nexit 0\\n");
  assertIncludes(executable, root, "fixture path");
  await rm(root, { recursive: true, force: true });
' >/dev/null

printf '%s\n' 'Check dispatcher tests passed.'
