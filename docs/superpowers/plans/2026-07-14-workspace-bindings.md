# Workspace Bindings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add private workspace-to-profile bindings, bound-profile launches, mismatch guards, lifecycle cleanup, diagnostics, completions, and documentation.

**Architecture:** Keep runtime behavior in `bin/codex-profile`. Store canonical-path bindings in a private tab-separated registry, resolve the longest matching directory ancestor, and reuse that resolver for the new `workspace`/`run` commands and guards around explicit profile commands. Extend the existing Bash behavior suite before each implementation slice.

**Tech Stack:** Bash 3.2-compatible shell, standard macOS/Linux tools, dependency-free Bash tests, ShellCheck, Markdown.

## Global Constraints

- Keep the CLI dependency-free: Bash plus standard POSIX/macOS tools only.
- Never inspect or move authentication, cookies, sessions, MCP credentials, or tokens.
- Launch only the original signed ChatGPT bundle; never clone, patch, sign, quit, or broadly kill apps.
- Preserve every existing behavior when no binding matches.
- Use modes `0700` for the config directory and `0600` for state, written through same-directory temporary files and atomic rename.
- Stay compatible with macOS Bash 3.2: no associative arrays, `readarray`, GNU-only `realpath`, or new dependency.
- Do not bump the release version; document the feature under `CHANGELOG.md` Unreleased.

---

### Task 1: Private Binding Registry and Inspection

**Files:**
- Modify: `test/codex-profile-test.sh`
- Modify: `bin/codex-profile`

**Interfaces:**
- Produces `CODEX_PROFILE_CONFIG_HOME`, `WORKSPACE_REGISTRY`, and `WORKSPACE_GUARD_FILE`.
- Produces `canonical_directory`, `workspace_registry_validate`, `workspace_registry_rewrite`, `workspace_resolve`, `workspace_guard_mode`, and `profile_is_initialized`.
- `workspace_resolve <path>` sets `WORKSPACE_RESOLVED_PATH`, `WORKSPACE_RESOLVED_BINDING`, and `WORKSPACE_RESOLVED_PROFILE`; return 0 means matched and 1 means unbound.
- Produces `command_workspace` with `bind`, `unbind`, `list`, `status`, and `guard`.

- [ ] **Step 1: Write failing registry and resolution tests**

Add isolated-HOME tests with this core contract:

```bash
run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$tmp/config" \
  "$SCRIPT" workspace bind "$tmp/Dev/client" client
assert_status 0
assert_contains "Bound $tmp/Dev/client to profile client"
[[ "$(mode_of "$tmp/config")" == "700" ]] || fail "workspace config directory is not private"
[[ "$(mode_of "$tmp/config/workspaces.tsv")" == "600" ]] || fail "workspace registry is not private"

run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$tmp/config" \
  "$SCRIPT" workspace status --json "$tmp/Dev/client/service"
assert_status 0
assert_contains '"binding_path":"'"$tmp/Dev/client"'"'
assert_contains '"profile":"client"'
```

Cover idempotent bind, replacement rejection/`--force`, exact unbind, nested precedence, sibling-prefix rejection, symlink canonicalization, spaces, missing paths, unknown profiles, control-character rejection, stale rows, list/status JSON validity/nulls, and guard default/set/read.

- [ ] **Step 2: Verify RED**

Run `bash test/codex-profile-test.sh` and expect `Unknown command 'workspace'`.

- [ ] **Step 3: Implement registry and workspace commands**

Add:

```bash
CODEX_PROFILE_CONFIG_HOME="${CODEX_PROFILE_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/codex-profile}"
WORKSPACE_REGISTRY="$CODEX_PROFILE_CONFIG_HOME/workspaces.tsv"
WORKSPACE_GUARD_FILE="$CODEX_PROFILE_CONFIG_HOME/guard-mode"
```

Canonicalize with `(cd -- "$path" && pwd -P)`. Reject non-directories and tab/CR/LF. Refuse symlinked config directories and files. Parse exactly one literal tab per non-empty row using parameter expansion; never `source` or `eval` state. Validate the whole existing registry before mutations, then write with `mktemp`, `chmod 600`, and `mv`.

Resolve exact/ancestor directory boundaries and keep the longest binding:

```bash
if [[ "$candidate" == "$binding" ]] || [[ "$binding" == "/" ]] || \
   [[ "$candidate" == "$binding/"* ]]; then
  if [[ ${#binding} -gt ${#WORKSPACE_RESOLVED_BINDING} ]]; then
    WORKSPACE_RESOLVED_BINDING="$binding"
    WORKSPACE_RESOLVED_PROFILE="$profile"
  fi
fi
```

Emit the approved human/JSON shapes, JSON nulls when unbound, and valid failure output for corrupt state. Register `workspace` in `main` and suppress update notices for its JSON forms.

- [ ] **Step 4: Verify GREEN**

Run `bash test/codex-profile-test.sh`; all tests must pass.

- [ ] **Step 5: Commit**

Commit `bin/codex-profile` and `test/codex-profile-test.sh` as `cli(feat): add private workspace bindings`, with summary, rationale, and test body sections.

### Task 2: Bound Runs and Mismatch Guards

**Files:**
- Modify: `test/codex-profile-test.sh`
- Modify: `bin/codex-profile`

**Interfaces:**
- Consumes Task 1's resolver and guard-mode reader.
- Produces `workspace_guard_profile <selected-profile> <path>` and `command_run`.
- `run [--] [codex-args...]` calls `command_cli`; `run --app [workspace]` calls `command_app` with a canonical workspace.

- [ ] **Step 1: Write failing run and guard tests**

Use the existing fake Codex and signed-app helpers. Verify CLI routing and forwarding:

```bash
run_cmd env HOME="$tmp/home" CODEX_PROFILE_CONFIG_HOME="$tmp/config" \
  CODEX_CLI="$fake_codex" bash -c \
  'cd "$1" && exec "$2" run -- exec "run tests"' _ "$tmp/Dev/client/service" "$SCRIPT"
assert_status 0
assert_contains "CODEX_HOME=$tmp/home/.codex-client"
assert_contains "ARGS=exec run tests"
```

Test `run --app`, missing-binding errors, and warn/strict/off behavior for `cli`, `app`, and `env`. Prove warnings are stderr-only, strict mode runs no side effect or shell output, a matching profile is quiet, and unbound commands are unchanged.

- [ ] **Step 2: Verify RED**

Run `bash test/codex-profile-test.sh` and expect `Unknown command 'run'`.

- [ ] **Step 3: Implement run and guards**

Implement:

```bash
workspace_guard_profile() {
  local selected_profile="$1" path="$2" mode
  mode="$(workspace_guard_mode)"
  [[ "$mode" != "off" ]] || return 0
  workspace_resolve "$path" || return 0
  [[ "$selected_profile" != "$WORKSPACE_RESOLVED_PROFILE" ]] || return 0
  if [[ "$mode" == "strict" ]]; then
    die "Workspace '$WORKSPACE_RESOLVED_BINDING' is bound to profile '$WORKSPACE_RESOLVED_PROFILE'; refusing selected profile '$selected_profile'."
  fi
  printf "Warning: workspace '%s' is bound to profile '%s'; selected profile is '%s'.\n" \
    "$WORKSPACE_RESOLVED_BINDING" "$WORKSPACE_RESOLVED_PROFILE" "$selected_profile" >&2
}
```

Call it before side effects in `command_cli`, `command_env`, and `command_app`. `app` checks its supplied workspace or `$PWD`; shell-wrapper `use` is covered through `env`. Implement the two approved `run` forms, rejecting other wrapper options and stripping only a leading `--` in CLI form. Register `run` in `main`.

- [ ] **Step 4: Verify GREEN**

Run `bash test/codex-profile-test.sh`; all tests must pass.

- [ ] **Step 5: Commit**

Commit the two files as `cli(feat): route bound workspaces safely`, with summary, rationale, and tests.

### Task 3: Lifecycle Cleanup and Doctor Health

**Files:**
- Modify: `test/codex-profile-test.sh`
- Modify: `bin/codex-profile`

**Interfaces:**
- Produces `workspace_remove_profile_bindings <profile>` and `workspace_registry_stats`.
- Extends doctor JSON with top-level `workspaces` containing `config_home`, `registry_path`, `guard_mode`, `registry_valid`, `binding_count`, `missing_paths`, and `missing_profiles`.

- [ ] **Step 1: Write failing lifecycle/doctor tests**

Bind two workspaces to a removed profile and one to another profile; verify only unrelated rows survive and no project file is deleted. Cover cleanup for an already-missing profile. Assert human doctor fields and parse this JSON shape:

```json
"workspaces": {
  "guard_mode": "strict",
  "registry_valid": true,
  "binding_count": 3,
  "missing_paths": 1,
  "missing_profiles": 1
}
```

Verify corrupt rows/guard values are reported and `doctor --json` remains one valid document whether the Codex CLI exists or not.

- [ ] **Step 2: Verify RED**

Run `bash test/codex-profile-test.sh`; expect stale bindings or missing doctor fields.

- [ ] **Step 3: Implement cleanup and health reporting**

Validate registry mutability before removal. After confirmed profile deletion, atomically remove all rows for that profile; also clean stale bindings when the profile is already absent. Compute counts without reading Codex state. Human doctor always reports workspace health. JSON uses `guard_mode: null` and `registry_valid: false` for invalid state, without partial output.

- [ ] **Step 4: Verify GREEN**

Run `bash test/codex-profile-test.sh`; all tests must pass.

- [ ] **Step 5: Commit**

Commit the two files as `cli(feat): diagnose and clean workspace bindings`, with summary, rationale, and tests.

### Task 4: Help, Completions, and Documentation

**Files:**
- Modify: `bin/codex-profile`
- Modify: `test/codex-profile-test.sh`
- Modify: `README.md`
- Modify: `docs/llms.txt`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Adds `workspace` and `run` to usage and Bash/Zsh/Fish completions.
- Documents `CODEX_PROFILE_CONFIG_HOME`, nearest-ancestor routing, guard semantics, persistence, cleanup, and safety limitations.

- [ ] **Step 1: Write failing discovery assertions**

Require every generated completion to contain `workspace` and `run`, workspace subcommands `bind unbind list status guard`, profile completion at the bind profile position, and `--app` for run. Require help to show every new command and environment override.

- [ ] **Step 2: Verify RED**

Run `bash test/codex-profile-test.sh`; expect help/completion assertions to fail.

- [ ] **Step 3: Update command discovery and docs**

Document this exact workflow in README and `docs/llms.txt`:

```sh
codex-profile workspace bind ~/Dev/client-a client-a
cd ~/Dev/client-a
codex-profile run
codex-profile run exec "run tests"
codex-profile run --app
codex-profile workspace guard strict
codex-profile workspace status --json
```

Explain precedence, private global state, default warn mode, strict/off, guarded commands, upstream `-C` non-parsing, cleanup, and non-security-boundary status. Add an Unreleased/Added changelog entry. Keep deprecated spellings in all completions.

- [ ] **Step 4: Verify behavior and GEO docs**

Run `bash test/codex-profile-test.sh` and `node test/geo-site-test.mjs`; both must pass.

- [ ] **Step 5: Commit**

Commit the five files as `docs(feat): document workspace-aware routing`, with summary, rationale, and tests.

### Task 5: Full Verification and Draft PR

**Files:**
- Verify all branch changes and the design/plan documents.

**Interfaces:**
- Produces a pushed `PinZheng/workspace-bindings` branch and draft PR titled `PinZheng(cli): add workspace-aware profile routing`.

- [ ] **Step 1: Run required checks**

```bash
make test
make lint
git diff --check origin/main...HEAD
```

Expected: all exit 0 with no ShellCheck or whitespace findings.

- [ ] **Step 2: Review diff and invariants**

```bash
git status -sb
git diff --stat origin/main...HEAD
rg -n "auth\.json|cookie|token|killall|pkill|codesign|cp -R" bin/codex-profile
```

Confirm there is no credential access, app copying/signing, broad process control, unrelated artifact, or version bump.

- [ ] **Step 3: Push and open the draft PR**

Push with tracking, create a draft PR against the remote default branch using the explicit required title, include behavior/safety/docs/checks in the body, and verify title plus draft state with `gh pr view`.
