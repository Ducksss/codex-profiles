# Repository Maintenance Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reorganize repository-only checks, tests, release automation, and AUR operations around directly tested responsibility-based scripts without changing the shipped CLI or public behavior.

**Architecture:** Keep `bin/codex-profile` as the entire runtime. Add one deterministic repository check dispatcher, mirror tests to product and operational responsibilities, move release behavior from GitHub Actions YAML into scripts, and replace executable AUR Markdown with tested preparation and verification commands.

**Tech Stack:** Bash 3.2-compatible shell, POSIX shell for `install.sh`, Node.js built-ins, GNU Make, GitHub Actions YAML, ShellCheck, git, npm, gh, curl, and existing JSON fixtures; no new dependency.

## Global Constraints

- `bin/codex-profile` remains the complete installed runtime.
- Public commands, output formats, completion behavior, profile mapping, workspace routing, update behavior, package names, installers, compatibility spellings, and safety boundaries do not change.
- Runtime remains Bash plus standard POSIX/macOS tools; no runtime or development package dependency is added.
- Version remains `0.7.0`; do not edit synchronized version declarations.
- No npm, GitHub, Homebrew, AUR, or Pages publication occurs during implementation or tests.
- Release dry runs perform no external mutation.
- Tests use disposable homes, fixtures, and command shims and never inspect real authentication, cookies, account identifiers, keychains, or application state.
- Make targets `test`, `lint`, `install`, `uninstall`, `path-smoke-test`, `install-smoke-test`, and `npm-package-test` remain available.
- Repo-local outreach skills and Airtable ownership remain unchanged except for test-path integration.
- Each task uses red-green-refactor and ends with an independently passing deliverable.

---

### Task 1: Canonical repository check dispatcher

**Files:**
- Create: `scripts/check`
- Create: `test/install/check-test.sh`
- Modify: `Makefile`
- Modify: `.github/workflows/ci.yml`
- Modify: `package.json`
- Modify: `test/makefile-smoke-test.sh`

**Interfaces:**
- Consumes: repository naming conventions `*-test.sh`, `*-test.mjs`, `.sh`, `.mjs`, `bin/codex-profile`, and `install.sh`.
- Produces: `scripts/check {list|syntax|test|lint|all}`, `make check`, and one deterministic source/test inventory used by Make and CI.

- [ ] **Step 1: Write the dispatcher contract test**

Create `test/install/check-test.sh` with `set -euo pipefail`. Resolve the root with `$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)`. Assert:

```bash
list_output="$($ROOT_DIR/scripts/check list)"
[[ "$list_output" == *$'shell\tbin/codex-profile'* ]]
[[ "$list_output" == *$'shell\tinstall.sh'* ]]
[[ "$list_output" == *$'shell\tscripts/check'* ]]
[[ "$list_output" == *$'bash-test\ttest/install/check-test.sh'* ]]
[[ "$list_output" == *$'node-test\ttest/geo-site-test.mjs'* ]]
[[ "$list_output" != *'test/fixtures/'* ]]

sorted="$(printf '%s\n' "$list_output" | LC_ALL=C sort)"
[[ "$list_output" == "$sorted" ]]

set +e
unknown_output="$($ROOT_DIR/scripts/check unsupported 2>&1)"
unknown_status=$?
set -e
[[ "$unknown_status" -ne 0 ]]
[[ "$unknown_output" == *'Usage: scripts/check {list|syntax|test|lint|all}'* ]]
```

The test must also create a temporary fake `shellcheck` earlier on `PATH`, run `scripts/check lint`, record every argument, and assert the recorded list equals the `shell` records from `scripts/check list` except `install.sh`, which is included as a POSIX shell source.

- [ ] **Step 2: Run the focused test and verify RED**

Run: `bash test/install/check-test.sh`

Expected: exit nonzero because `scripts/check` does not exist.

- [ ] **Step 3: Implement `scripts/check`**

Use this dispatcher shape, with repository-relative paths and NUL-safe `find` loops converted into sorted newline inventories only after rejecting embedded newlines:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

list_shell_sources() {
  {
    printf '%s\n' bin/codex-profile install.sh scripts/check
    find scripts test -type f -name '*.sh' -print
  } | LC_ALL=C sort -u
}

list_node_sources() {
  find scripts test -type f -name '*.mjs' -print | LC_ALL=C sort -u
}

list_bash_tests() {
  find test -type f -name '*-test.sh' -print | LC_ALL=C sort
}

list_node_tests() {
  find test -type f -name '*-test.mjs' -print | LC_ALL=C sort
}

list_all() {
  list_shell_sources | while IFS= read -r path; do printf 'shell\t%s\n' "$path"; done
  list_bash_tests | while IFS= read -r path; do printf 'bash-test\t%s\n' "$path"; done
  list_node_tests | while IFS= read -r path; do printf 'node-test\t%s\n' "$path"; done
  list_node_sources | while IFS= read -r path; do printf 'node\t%s\n' "$path"; done
}

run_syntax() {
  list_shell_sources | while IFS= read -r path; do
    if [[ "$path" == install.sh ]]; then sh -n "$path"; else bash -n "$path"; fi
  done
  list_node_sources | while IFS= read -r path; do node --check "$path"; done
}

run_tests() {
  run_syntax
  list_bash_tests | while IFS= read -r path; do bash "$path"; done
  list_node_tests | while IFS= read -r path; do node "$path"; done
}

run_lint() {
  command -v shellcheck >/dev/null 2>&1 || {
    printf '%s\n' 'Error: shellcheck is required for lint.' >&2
    return 1
  }
  mapfile_compat=()
  while IFS= read -r path; do mapfile_compat+=("$path"); done < <(list_shell_sources)
  shellcheck "${mapfile_compat[@]}"
}

usage() { printf '%s\n' 'Usage: scripts/check {list|syntax|test|lint|all}' >&2; }

case "${1:-}" in
  list) list_all | LC_ALL=C sort ;;
  syntax) run_syntax ;;
  test) run_tests ;;
  lint) run_lint ;;
  all) run_tests; run_lint ;;
  *) usage; exit 2 ;;
esac
```

Replace the temporary array name with a normal Bash indexed array; do not use `mapfile` because macOS Bash 3.2 lacks it. Reject newline-bearing discovered paths before printing them.

- [ ] **Step 4: Delegate Make, npm, and CI**

Make these exact target bodies:

```make
.PHONY: install uninstall lint test check path-smoke-test install-smoke-test npm-package-test outreach

lint:
	scripts/check lint

test:
	scripts/check test

check:
	scripts/check all
```

Keep existing install/smoke/outreach bodies. Leave `package.json` test as `make test` and add `"check": "make check"`. In Linux CI replace the separate test, lint, and package-metadata steps with one `make check` step. Keep macOS `make test`; remove only the install block already covered by `install-smoke-test` after the Make smoke test proves parity.

Rewrite `test/makefile-smoke-test.sh` to require delegation literals and retain mutation coverage for the three smoke targets; it must no longer require manual syntax/test lists.

- [ ] **Step 5: Verify GREEN**

Run:

```sh
bash test/install/check-test.sh
bash test/makefile-smoke-test.sh
scripts/check syntax
make test
make lint
make check
```

Expected: all commands exit 0; each test runs once per `scripts/check test` invocation; no tracked or untracked artifacts remain except plan/spec work.

- [ ] **Step 6: Commit**

Stage the six task files and commit with subject `build(refactor): centralize repository checks`. The body records deterministic discovery, CI deduplication, and all commands from Step 5.

---

### Task 2: Responsibility-based non-CLI test layout

**Files:**
- Create: `test/lib/assertions.sh`
- Create: `test/lib/assertions.mjs`
- Create: `test/lib/fixtures.mjs`
- Move: `test/install-script-test.sh` -> `test/install/standalone-test.sh`
- Move: `test/makefile-smoke-test.sh` -> `test/install/makefile-test.sh`
- Create: `test/install/npm-package-test.sh`
- Move: `test/package-metadata-test.sh` -> `test/packaging/metadata-test.sh`
- Move: `test/aur-runbook-test.mjs` -> `test/packaging/aur-test.mjs`
- Move: `test/geo-site-test.mjs` -> `test/site/geo-test.mjs`
- Move: `test/outreach-tracker-test.mjs` -> `test/outreach/tracker-test.mjs`
- Move: `test/outreach-agent-test.mjs` -> `test/outreach/agent-test.mjs`
- Move: `test/github-pipeline-skills-test.mjs` -> `test/outreach/skills-test.mjs`
- Modify: `scripts/check`
- Modify: `Makefile`
- Modify: `.github/workflows/pages.yml`
- Modify: `.github/workflows/release.yml`
- Modify: `AGENTS.md`
- Modify: `CONTRIBUTING.md`

**Interfaces:**
- Consumes: Task 1 discovery and existing standalone, packaging, site, outreach, and smoke behaviors.
- Produces: independent domain suites, shared assertion helpers, and an explicit npm package behavior test used by the Make smoke target.

- [ ] **Step 1: Add shared-helper tests and verify RED**

Extend `test/install/check-test.sh` to require `test/lib/assertions.sh`, `test/lib/assertions.mjs`, and `test/lib/fixtures.mjs` in syntax listings. Add a temporary Bash probe that sources `assertions.sh`, invokes `assert_equals label expected actual`, and verifies mismatches exit nonzero with `FAIL: label`.

Run: `bash test/install/check-test.sh`

Expected: FAIL because shared helpers do not exist.

- [ ] **Step 2: Implement minimal shared helpers**

`test/lib/assertions.sh` exports `fail`, `assert_status`, `assert_equals`, `assert_contains`, and `assert_not_contains` with the existing CLI-test message formats. `test/lib/assertions.mjs` exports `assertIncludes`, `assertExcludes`, and `assertFileExists` using `node:assert/strict`. `test/lib/fixtures.mjs` exports `makeTempRoot(prefix)` and `writeExecutable(path, body)` using Node built-ins and mode `0o755`.

- [ ] **Step 3: Move suites with history and correct root resolution**

Use `git mv` for every listed existing suite. Change Bash roots to `../..` and Node roots to `new URL('../..', import.meta.url)`. Update literal test paths in the Makefile, Pages workflow, release workflow, AGENTS, CONTRIBUTING, and metadata assertions only where the path is an actual interface.

Use shared helpers only where two or more suites have byte-for-byte equivalent infrastructure. Keep domain assertions local.

- [ ] **Step 4: Extract npm package smoke behavior**

Move the body of `npm-package-test` into `test/install/npm-package-test.sh`. The script accepts `PREFIX_ROOT` as an optional disposable root for mutation tests, otherwise creates one, performs `npm pack --json`, global-prefix installation, canonical/alias/runtime/package-content assertions, and cleanup. The Make target becomes `bash test/install/npm-package-test.sh`.

- [ ] **Step 5: Verify focused and discovered execution**

Run every moved test directly, then:

```sh
scripts/check list
make test
make lint
```

Expected: all moved paths are discovered; no old test path remains in `rg -n 'test/(install-script|makefile-smoke|package-metadata|aur-runbook|geo-site|outreach-tracker|outreach-agent|github-pipeline-skills)-test' .`.

- [ ] **Step 6: Commit**

Commit with subject `tests(refactor): organize repository suites by domain` and record the direct focused commands plus `make test` and `make lint`.

---

### Task 3: Split the CLI behavior monolith

**Files:**
- Create: `test/lib/cli-fixtures.sh`
- Create: `test/cli/profiles-test.sh`
- Create: `test/cli/desktop-test.sh`
- Create: `test/cli/workspace-test.sh`
- Create: `test/cli/status-json-test.sh`
- Create: `test/cli/shell-test.sh`
- Create: `test/cli/upgrade-test.sh`
- Delete: `test/codex-profile-test.sh`
- Modify: `scripts/check`
- Modify: `AGENTS.md`

**Interfaces:**
- Consumes: Task 2 Bash assertions and every existing `test_*` function from `test/codex-profile-test.sh`.
- Produces: six directly runnable suites with private temp roots and a shared fixture library containing no test cases.

- [ ] **Step 1: Add suite-boundary contract and verify RED**

Extend `test/install/check-test.sh` to require all six files and reject `test/codex-profile-test.sh`. Require each suite to contain `source "$ROOT_DIR/test/lib/cli-fixtures.sh"`, its own `TMP_ROOT="$(mktemp -d)"`, and a trap.

Run: `bash test/install/check-test.sh`

Expected: FAIL because the split files do not exist.

- [ ] **Step 2: Extract the fixture library**

Move command capture, assertion-neutral CLI execution, fake Codex construction, fake upgrade repository construction, fake signed ChatGPT bundle construction, and fake `open`/`pgrep` tools into `test/lib/cli-fixtures.sh`. The library requires `ROOT_DIR`, `TMP_ROOT`, and sourced assertions from the caller; it defines no trap and invokes no tests.

- [ ] **Step 3: Move tests by exact ownership**

Move each whole function and its invocation once:

- profiles: version, cli/login forwarding, validation/path/list, init/share, removal, clone-config;
- desktop: app launch/discovery/compatibility/symlink/token/failure and Desktop doctor;
- workspace: every `workspace_*`, `run`, guard, removal-cleanup, and workspace-doctor case;
- status-json: status human/JSON, JSON escaping, logged-out/unexpected failure, missing-CLI doctor;
- shell: env/use/shell-init/completions/logs;
- upgrade: upgrade checkout/version/cache plus all update-check cases.

Each file starts with:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/test/lib/assertions.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT
source "$ROOT_DIR/test/lib/cli-fixtures.sh"
```

The bottom of each file explicitly invokes only functions defined in that file. Do not use function-name reflection or order-dependent shared state.

- [ ] **Step 4: Prove one-to-one coverage**

Before deleting the monolith, capture sorted old and new test names with:

```sh
name_root="$(mktemp -d)"
trap 'rm -rf "$name_root"' EXIT
rg -o -P '^test_[A-Za-z0-9_]+(?=\(\))' test/codex-profile-test.sh | sort > "$name_root/old.names"
rg -o -P '^test_[A-Za-z0-9_]+(?=\(\))' test/cli -g '*-test.sh' | sed 's/.*://' | sort > "$name_root/new.names"
diff -u "$name_root/old.names" "$name_root/new.names"
```

Use disposable paths for the inventories and require an empty diff, no duplicate names, and equal invocation counts. Then delete the old file.

- [ ] **Step 5: Run every suite independently and full verification**

Run all six files directly, followed by `make test` and `make lint`.

Expected: every command exits 0 and `rg -n 'codex-profile-test\.sh' .` has no result.

- [ ] **Step 6: Commit**

Commit with subject `tests(refactor): split CLI behavior by responsibility`.

---

### Task 4: Extract release source, preflight, state, and tag scripts

**Files:**
- Create: `scripts/release/lib.sh`
- Create: `scripts/release/verify-source.sh`
- Create: `scripts/release/preflight.sh`
- Create: `scripts/release/verify-state.sh`
- Create: `scripts/release/publish-tag.sh`
- Create: `test/lib/command-shims.sh`
- Create: `test/release/source-test.sh`
- Create: `test/release/state-test.sh`
- Modify: `.github/workflows/release.yml`
- Modify: `test/release-workflow-test.sh`

**Interfaces:**
- Consumes: workflow inputs/environment and Task 2 assertions.
- Produces: direct scripts for tracked-version/source validation, credential identity checks, live-state revalidation, and idempotent tag publication.

- [ ] **Step 1: Write direct RED tests from existing scenarios**

Move the source-version, attestation, branch/ref, credential, tag-state, and tag-race scenario harnesses from `test/release-workflow-test.sh` into `source-test.sh` and `state-test.sh`. Replace workflow-step extraction with explicit script paths. Preserve every existing scenario and expected command count.

Run both new tests.

Expected: FAIL because release scripts do not exist.

- [ ] **Step 2: Implement the shared release library**

`lib.sh` defines exact `X.Y.Z` validation, `require_command`, `retry <attempts> <delay> <command...>`, `release_temp_dir`, and `release_die`. It has no top-level mutation. `retry` preserves the last nonzero status and rejects nonpositive counts.

- [ ] **Step 3: Extract four scripts without behavior drift**

Use the current workflow blocks as the canonical bodies:

- `Validate release source and tracked versions` -> `verify-source.sh`;
- `Preflight release credential identities` -> `preflight.sh`;
- `Revalidate live release state` -> `verify-state.sh`;
- `Create and push tag` -> `publish-tag.sh`.

Each script sources `lib.sh`, validates required environment at startup, writes machine outputs only to the explicit `GITHUB_OUTPUT` file when present, sends diagnostics to stderr, and retains all existing exact-state/race checks. Workflow steps keep their existing names and environment mapping but their run bodies become one script invocation.

- [ ] **Step 4: Reduce old workflow tests to wiring for extracted steps**

Delete migrated behavior harnesses from the old file. Keep assertions that the step exists, runs the correct script, maps required secrets/inputs, has the same live-only condition, and preserves permissions.

- [ ] **Step 5: Verify**

Run source/state tests, the remaining workflow contract test, `make test`, and `make lint`.

Expected: all pass; the extracted workflow bodies no longer appear inline.

- [ ] **Step 6: Commit**

Commit with subject `ci(refactor): extract release source and state checks`.

---

### Task 5: Extract publication channels and split release tests

**Files:**
- Create: `scripts/release/publish-npm.sh`
- Create: `scripts/release/publish-github.sh`
- Create: `scripts/release/verify-distribution.sh`
- Create: `scripts/release/update-homebrew.sh`
- Create: `scripts/release/deploy-pages.sh`
- Create: `test/release/npm-test.sh`
- Create: `test/release/github-test.sh`
- Create: `test/release/distribution-test.sh`
- Create: `test/release/pages-test.sh`
- Create: `test/release/workflow-contract-test.mjs`
- Move: `test/release-helper-test.sh` -> `test/release/homebrew-test.sh`
- Delete: `test/release-workflow-test.sh`
- Modify: `.github/workflows/release.yml`
- Modify: `scripts/check`

**Interfaces:**
- Consumes: Task 4 release primitives and existing workflow scenario fixtures.
- Produces: directly tested channel scripts and a workflow containing orchestration-only shell.

- [ ] **Step 1: Move channel scenarios and verify RED**

Move all existing npm publication/integrity, GitHub Release creation/finality, standalone installation, Homebrew tap, and Pages dispatch/deployment scenarios into the five owning shell tests. Keep exact success, retry, race, malformed response, mismatch, credential, and failed postcondition cases.

Run the five tests.

Expected: FAIL because channel scripts do not exist.

- [ ] **Step 2: Extract channel scripts**

Map existing workflow steps exactly:

- publish/verify npm -> `publish-npm.sh {publish|verify}`;
- create/verify GitHub Release -> `publish-github.sh {publish|verify}`;
- tagged AUR and standalone installer verification -> `verify-distribution.sh {tagged-aur|standalone}`;
- Homebrew tap update -> `update-homebrew.sh`;
- Pages dispatch/watch/public-version verification -> `deploy-pages.sh`.

Preserve existing bounded retries, exact version/SHA/integrity checks, alias checks, immutable-release checks, same-result race acceptance, conflicting-result rejection, and summaries. Each workflow run body contains only the script invocation and summary-only formatting that genuinely belongs to Actions.

- [ ] **Step 3: Replace the structural test with Node built-ins**

`workflow-contract-test.mjs` reads YAML as text and asserts dispatch inputs, permissions, concurrency, two job names, live-only condition, environment mappings, pinned action SHAs, output wiring, and one invocation for every release script. It rejects `run: |` blocks longer than 20 nonblank lines and rejects inline `npm publish`, `gh release create`, `git push origin`, and tap mutation commands.

- [ ] **Step 4: Delete obsolete harnesses**

Delete the old workflow test only after the union of new test scenario names equals the old behavior scenario inventory and all new tests pass directly.

- [ ] **Step 5: Verify**

Run every `test/release/*-test.sh`, the Node workflow contract, `make test`, `make lint`, and `git diff --check`.

Expected: all pass; `.github/workflows/release.yml` contains orchestration rather than channel programs.

- [ ] **Step 6: Commit**

Commit with subject `ci(refactor): make release channels directly testable`.

---

### Task 6: Script AUR preparation and verification

**Files:**
- Create: `scripts/aur/prepare.sh`
- Create: `scripts/aur/verify.sh`
- Modify: `test/packaging/aur-test.mjs`
- Modify: `packaging/aur/README.md`
- Modify: `scripts/check`

**Interfaces:**
- Consumes: tracked PKGBUILD/`.SRCINFO`, immutable release archives, existing AUR RPC/release fixtures, optional Docker, curl, git, and makepkg.
- Produces: non-pushing `prepare.sh`, read-only/local `verify.sh`, and a concise operator guide.

- [ ] **Step 1: Convert extracted-block tests to script contracts and verify RED**

Change the AUR test to invoke scripts with fixture URLs/JSON and fake `curl`, `git`, `docker`, `makepkg`, and `ssh`. Preserve all eleven runbook behaviors, four RPC fixtures, four release fixtures, ownership checks, checksum checks, source immutability, alias checks, and no-push assertion.

Run: `node test/packaging/aur-test.mjs`

Expected: FAIL because AUR scripts do not exist.

- [ ] **Step 2: Implement `prepare.sh`**

Accept `--version`, `--release-json`, `--archive`, and `--output`. Validate exact release/tag/SHA256 metadata, tracked package version/source/checksum synchronization, safe disposable output, and exact staged PKGBUILD/`.SRCINFO` content. Print a review summary and never invoke `git push`, `ssh`, or write outside the output root.

- [ ] **Step 3: Implement `verify.sh`**

Accept `--version`, `--checkout`, optional `--rpc-json`, and `--container {auto|always|never}`. Validate ownership/version/source/checksums/aliases locally and from RPC data. In `auto`, use Docker only when available; `always` fails clearly when unavailable; `never` performs deterministic metadata tests without claiming container validation.

- [ ] **Step 4: Rewrite the runbook**

Keep prerequisites, credential boundary, first publication, update, explicit manual commit/push, public verification, recovery, and troubleshooting. Replace embedded executable implementations with exact `scripts/aur/prepare.sh` and `scripts/aur/verify.sh` invocations. Include no shell block longer than 15 lines and no duplicated validation function.

- [ ] **Step 5: Verify**

Run AUR tests, both scripts against fixtures, `make test`, `make lint`, and `rg -n 'aur-runbook-test|--extract' .`.

Expected: all tests pass and the final search has no result.

- [ ] **Step 6: Commit**

Commit with subject `release(refactor): script AUR preparation and checks`.

---

### Task 7: Documentation, consistency, and final verification

**Files:**
- Modify: `AGENTS.md`
- Modify: `CONTRIBUTING.md`
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/llms.txt` only if it names moved repository commands
- Modify: all files still containing obsolete paths found by the consistency scan

**Interfaces:**
- Consumes: final repository structure and all preserved public behavior.
- Produces: accurate audience-specific repository guidance and a clean, fully verified worktree.

- [ ] **Step 1: Add documentation contract assertions**

Extend packaging/site tests to require `make check`, `scripts/check`, the new test directories, release script directory, AUR commands, unchanged version `0.7.0`, and unchanged public CLI command lists. Reject old test paths, executable-Markdown extraction, and claims that any implementation step published externally.

Run focused tests and verify they fail on stale docs.

- [ ] **Step 2: Update contributor and agent documentation**

Document the final tree, `make test`, `make lint`, `make check`, focused direct test execution, test placement rules, release-script ownership, AUR operator boundary, and no-new-dependency rule. Keep README user-focused and limit its development section to canonical entrypoints and links.

Add an Unreleased Changed entry describing repository check consolidation, responsibility-based tests, directly tested release scripts, and scripted AUR verification. Do not bump a version.

- [ ] **Step 3: Run the obsolete-path and duplication scan**

Run:

```sh
rg -n 'test/(codex-profile|release-workflow|release-helper|aur-runbook|geo-site|package-metadata|install-script|makefile-smoke)-test' .
rg -n 'aur-runbook-test|--extract' .
rg -n 'npm publish|gh release create|git push origin' .github/workflows/release.yml
rg -n 'bash test/|node test/' Makefile .github/workflows package.json README.md CONTRIBUTING.md AGENTS.md
```

Expected: no obsolete paths or implementation commands; direct focused examples are allowed only in contributor documentation and must name current paths.

- [ ] **Step 4: Run complete verification**

Run:

```sh
make test
make lint
make check
make path-smoke-test
make install-smoke-test
make npm-package-test
git diff --check
git status --short
```

Expected: every command exits 0; the status contains only intentional source/docs/test changes and no build, npm, cache, temp, or result artifacts.

- [ ] **Step 5: Review the complete diff against the spec**

Check every acceptance criterion in `docs/superpowers/specs/2026-07-15-repository-maintenance-architecture-design.md`, compare test scenario inventories before/after, inspect executable permissions, and confirm `git diff -- bin/codex-profile` is empty.

- [ ] **Step 6: Commit**

Commit with subject `docs(refactor): document repository maintenance workflow`. Include complete verification commands in the body.

- [ ] **Step 7: Final verification from committed state**

Re-run `make check`, `git diff --check HEAD^..HEAD`, and `git status --short`. Expected: checks pass and the worktree is clean.

## Final implementation note

The final simplicity review removed `test/lib/assertions.mjs`,
`test/lib/fixtures.mjs`, and unused release-library primitives after proving
that no real suite or release script consumed them. This intentional deviation
keeps the design rule that shared helpers must serve more than one caller; Node
suites continue to use built-in assertions and domain-local fixtures.
