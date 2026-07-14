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
check_source="$(<"$CHECK")"
assert_contains "$list_output" $'shell\tbin/codex-profile' "runtime inventory"
assert_contains "$list_output" $'shell\tinstall.sh' "installer inventory"
assert_contains "$list_output" $'shell\tscripts/check' "dispatcher inventory"
assert_contains "$list_output" $'shell\tscripts/update-homebrew-formula' "extensionless script inventory"
assert_contains "$list_output" $'shell\tscripts/aur/lib.sh' "AUR helper inventory"
assert_contains "$list_output" $'shell\tscripts/aur/prepare.sh' "AUR prepare inventory"
assert_contains "$list_output" $'shell\tscripts/aur/verify.sh' "AUR verify inventory"
assert_contains "$list_output" $'bash-test\ttest/install/check-test.sh' "Bash test inventory"
assert_contains "$list_output" $'bash-test\ttest/install/dispatcher-input-test.sh' "dispatcher isolation inventory"
assert_contains "$list_output" $'shell\ttest/lib/assertions.sh' "Bash helper inventory"
for obsolete_helper in test/lib/assertions.mjs test/lib/fixtures.mjs; do
  if [[ "$list_output" == *$'\t'"$obsolete_helper"* ]]; then
    fail "unused Node helper remains in inventory: $obsolete_helper"
  fi
done
assert_contains "$list_output" $'bash-test\ttest/install/standalone-test.sh' "standalone test inventory"
assert_contains "$list_output" $'bash-test\ttest/install/makefile-test.sh' "Make test inventory"
assert_contains "$list_output" $'bash-test\ttest/install/npm-package-test.sh' "npm test inventory"
assert_contains "$list_output" $'bash-test\ttest/packaging/metadata-test.sh' "metadata test inventory"
assert_contains "$list_output" $'node-test\ttest/packaging/aur-test.mjs' "AUR test inventory"
assert_contains "$list_output" $'node-test\ttest/site/geo-test.mjs' "site test inventory"
assert_contains "$list_output" $'node-test\ttest/outreach/tracker-test.mjs' "outreach tracker inventory"
assert_contains "$list_output" $'node-test\ttest/outreach/agent-test.mjs' "outreach agent inventory"
assert_contains "$list_output" $'node-test\ttest/outreach/skills-test.mjs' "outreach skills inventory"

release_suites=(
  test/release/source-test.sh
  test/release/state-test.sh
  test/release/npm-test.sh
  test/release/github-test.sh
  test/release/distribution-test.sh
  test/release/homebrew-test.sh
  test/release/pages-test.sh
  test/release/workflow-contract-test.mjs
)
for suite in "${release_suites[@]}"; do
  if [[ "$suite" == *.mjs ]]; then
    assert_contains "$list_output" $'node-test\t'"$suite" "release suite inventory"
  else
    assert_contains "$list_output" $'bash-test\t'"$suite" "release suite inventory"
  fi
done

release_scripts=(
  scripts/release/lib.sh
  scripts/release/verify-source.sh
  scripts/release/preflight.sh
  scripts/release/verify-state.sh
  scripts/release/publish-tag.sh
  scripts/release/publish-npm.sh
  scripts/release/publish-github.sh
  scripts/release/verify-distribution.sh
  scripts/release/update-homebrew.sh
  scripts/release/deploy-pages.sh
)
for script in "${release_scripts[@]}"; do
  assert_contains "$list_output" $'shell\t'"$script" "release script inventory"
done
for old_path in test/release-workflow-test.sh test/release-helper-test.sh; do
  if [[ "$list_output" == *$'\t'"$old_path"* ]]; then
    fail "obsolete release test remains in inventory: $old_path"
  fi
done

cli_suites=(
  test/cli/profiles-test.sh
  test/cli/desktop-test.sh
  test/cli/workspace-test.sh
  test/cli/status-json-test.sh
  test/cli/shell-test.sh
  test/cli/upgrade-test.sh
)
for suite in "${cli_suites[@]}"; do
  assert_contains "$list_output" $'bash-test\t'"$suite" "CLI suite inventory"
done
if [[ "$list_output" == *$'\ttest/codex-profile-test.sh'* ]]; then
  fail "obsolete CLI monolith remains in inventory"
fi

if [[ "$list_output" == *'test/fixtures/'* ]]; then
  fail "fixture files must not appear in the executable inventory"
fi
assert_contains "$check_source" 'done < <(list_tests)' "globally sorted test execution"
run_tests_source="$(awk '
  /^run_tests\(\) \{/ { capture = 1 }
  capture { print }
  capture && /^}$/ { exit }
' "$CHECK")"
if [[ "$run_tests_source" == *'list_bash_tests'* \
  || "$run_tests_source" == *'list_node_tests'* ]]; then
  fail "test execution must not group suites by runtime"
fi
ripgrep_command="r""g "
if [[ "$(<"$ROOT_DIR/test/install/check-test.sh")" == *"$ripgrep_command"* ]]; then
  fail "dispatcher contracts must not require ripgrep"
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
agents_guide="$(<"$ROOT_DIR/AGENTS.md")"
contributing="$(<"$ROOT_DIR/CONTRIBUTING.md")"
readme="$(<"$ROOT_DIR/README.md")"
changelog="$(<"$ROOT_DIR/CHANGELOG.md")"

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
assert_contains "$agents_guide" 'make check' "agent verification entrypoint"
assert_contains "$contributing" 'make check' "contributor verification entrypoint"
assert_contains "$readme" 'make check' "README verification entrypoint"
assert_contains "$changelog" 'scripts/check' "check architecture changelog"
assert_contains "$changelog" 'directly tested channel scripts' "release architecture changelog"

set +e
assertion_probe="$({
  bash -c 'source "$1"; assert_equals "probe label" expected actual' \
    _ "$ROOT_DIR/test/lib/assertions.sh"
} 2>&1)"
assertion_status=$?
set -e
[[ "$assertion_status" -ne 0 ]] || fail "assert_equals mismatch must fail"
assert_contains "$assertion_probe" 'FAIL: probe label' "shared assertion failure"

definition_names="$TMP_ROOT/cli-definitions"
invocation_names="$TMP_ROOT/cli-invocations"
awk '
  /^[A-Za-z0-9_]+\(\) \{$/ && /^test_/ {
    name = $0
    sub(/\(\) \{$/, "", name)
    print name
  }
' "${cli_suites[@]/#/$ROOT_DIR/}" | LC_ALL=C sort > "$definition_names"
awk '/^test_[A-Za-z0-9_]+$/ { print }' \
  "${cli_suites[@]/#/$ROOT_DIR/}" | LC_ALL=C sort > "$invocation_names"
diff -u "$definition_names" "$invocation_names" \
  || fail "every CLI test must be defined and invoked exactly once"

duplicate_test="$(uniq -d "$definition_names" | sed -n '1p')"
[[ -z "$duplicate_test" ]] || fail "duplicate CLI test definition: $duplicate_test"

printf '%s\n' 'Check dispatcher tests passed.'
