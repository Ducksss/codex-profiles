# Workspace-Aware Profile Routing Design

## Summary

Add explicit workspace-to-profile bindings so `codex-profiles` can select the
right profile from a project directory and detect explicit profile mistakes.
Bindings remain local to the OS user, contain no credentials, and never modify
the bound repository.

The feature adds a `workspace` command family, a profile-resolving `run`
command, and optional mismatch guards for existing commands. It preserves the
project's single-file, dependency-free Bash architecture and does not turn
local state separation into an account or security boundary.

## Goals

- Let a user bind an existing directory to an existing Codex profile.
- Resolve the nearest binding for a directory, including nested workspaces.
- Launch the bound CLI or ChatGPT window without repeating the profile name.
- Warn about or reject an explicitly selected profile that conflicts with a
  binding.
- Provide human-readable and JSON inspection for scripts and diagnostics.
- Keep binding state private, atomic, deterministic, and credential-free.

## Non-goals

- Do not inspect, compare, copy, import, or export authentication or cookies.
- Do not modify repositories or introduce a checked-in `.codex-profile` file.
- Do not infer whether CLI and Desktop sessions use the same account.
- Do not parse upstream Codex arguments such as `-C` to infer another working
  directory.
- Do not automatically mutate the caller's shell. Existing `env` and `use`
  behavior remains explicit.
- Do not add cross-tool profiles, usage/quota monitoring, or configuration
  sharing in this release.

## Command Surface

```text
codex-profile workspace bind <path> <profile> [--force]
codex-profile workspace unbind <path>
codex-profile workspace list [--json]
codex-profile workspace status [--json] [path]
codex-profile workspace guard [off|warn|strict]
codex-profile run [--] [codex-args...]
codex-profile run --app [workspace]
```

`workspace bind` requires an existing directory and a discovered profile. It
stores the directory's physical canonical path. Rebinding an exact path to a
different profile fails unless `--force` is present; repeating the same binding
is an idempotent success.

`workspace unbind` removes only an exact canonical-path binding. It does not
remove a profile or any workspace files.

`workspace list` shows every binding, the global guard mode, and whether each
path and profile still exist. `workspace status` resolves the supplied path or
the current directory and reports the winning binding, selected profile, and
guard mode. A missing binding is a successful inspection result, not an error.

`workspace guard` prints the current mode when no value is supplied. The
default is `warn`: once a binding exists, an explicit mismatch produces a
concise stderr warning but still runs. `strict` rejects the mismatch before
launch or shell output, and `off` disables mismatch checks. A directory with no
matching binding behaves exactly as it does today in every mode.

`run` resolves the current directory and passes all remaining arguments to
`cli <resolved-profile>`. A leading `--` is removed so an upstream argument can
be protected from wrapper parsing. `run --app` resolves its optional workspace
or the current directory, then launches `app <resolved-profile>` with that
canonical workspace. Both forms fail with a binding command example if no
profile is bound.

The usage text and Bash, Zsh, and Fish completions expose the new commands and
their fixed options.

## Persistence and Resolution

Binding state lives under:

```text
${CODEX_PROFILE_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/codex-profile}/
  workspaces.tsv
  guard-mode
```

`CODEX_PROFILE_CONFIG_HOME` is the documented test/automation override. The
directory is mode `0700`; state files are mode `0600`. Mutations write a
same-directory temporary file, set its permissions, and rename it over the
destination so readers never observe a partial registry.

Each registry line is a physical canonical path, one tab, and a validated
profile name. Bind rejects paths containing tab, carriage-return, or newline
characters so the transparent format is unambiguous. Empty lines are ignored;
any other malformed line makes mutating commands fail closed and makes
inspection or `doctor` report the corrupt line without evaluating it as shell
code.

Resolution compares canonical directory boundaries, not string prefixes. An
exact match wins; otherwise the longest ancestor binding wins, allowing a
specific nested repository to override a broader workspace binding. Symlinked
input paths resolve to the same physical binding. Selection is independent of
registry order.

Human output is stable and concise. Machine output uses these shapes:

```json
{
  "guard_mode": "warn",
  "bindings": [
    {
      "path": "/Users/example/Dev/client-a",
      "profile": "client-a",
      "path_exists": true,
      "profile_exists": true
    }
  ]
}
```

```json
{
  "path": "/Users/example/Dev/client-a/service",
  "binding_path": "/Users/example/Dev/client-a",
  "profile": "client-a",
  "guard_mode": "warn"
}
```

For an unbound status, `binding_path` and `profile` are JSON `null`.

## Guard and Lifecycle Integration

Mismatch guards apply to the commands that select a profile for work in a
directory:

- `cli`, `env`, and `use` check the physical current directory.
- `app` checks its workspace argument when present, otherwise the physical
  current directory.
- `run` already selects the resolved profile and never mismatches.

Warnings go only to stderr. `status --json`, `doctor --json`, completion
generation, update checks, and other machine-readable paths remain clean.
`login`, `logs`, `path`, `clone-config`, and other non-workspace operations do
not apply guards.

Removing a named profile also removes all registry entries that target that
profile, after the existing confirmation succeeds and the profile directory is
removed. This prevents successful profile removal from leaving broken
bindings. Removing a workspace binding never deletes profile or project data.

`doctor` reports the registry path, guard mode, malformed rows, missing bound
directories, and missing bound profiles. JSON diagnostics gain corresponding
workspace fields without changing existing field meanings.

## Error Handling and Safety

- Missing/non-directory bind targets, unknown profiles, invalid modes, invalid
  options, and control characters fail with actionable errors.
- A corrupt registry is never sourced or evaluated. Mutations refuse to
  overwrite it until the user repairs or removes the bad row.
- `strict` is a guardrail, not a security boundary; users can disable it or
  invoke upstream Codex directly.
- The registry contains only local paths and profile names. It never reads or
  stores `auth.json`, cookies, sessions, MCP credentials, logs, or tokens.
- No command performs network access for binding resolution or guarding.
- The implementation remains compatible with macOS Bash 3.2 and Ubuntu Bash;
  it must not require associative arrays, `readarray`, GNU-only `realpath`, or
  a new runtime dependency.

## Testing and Documentation

Behavior tests use isolated `HOME` and `XDG_CONFIG_HOME` directories and real
CLI/app stubs. Tests cover bind/idempotence/forced replacement, exact unbind,
nested resolution, path-boundary correctness, symlink canonicalization,
spaces, rejected control characters, stale and corrupt registry rows, file
permissions, JSON escaping and nulls, all guard modes, CLI/app `run`, argument
forwarding, missing bindings, profile removal cleanup, doctor output, and quiet
machine-readable commands.

The full `make test` and `make lint` suites must pass on the supported shell
surface. User-facing documentation is updated under `CHANGELOG.md` Unreleased,
the README workflows and command reference, `docs/llms.txt`, environment
overrides, safety language, and every completion generator. The feature does
not bump the release version in this pull request.

## Acceptance Criteria

- A user can bind `~/Dev/client-a` to `client-a`, enter any descendant, and run
  `codex-profile run` to launch the Codex CLI with that profile's `CODEX_HOME`.
- `codex-profile run --app` opens the original signed ChatGPT bundle with the
  resolved profile and canonical workspace.
- An explicit mismatch warns by default, blocks in strict mode, and is ignored
  in off mode without contaminating stdout.
- Nested bindings select the nearest ancestor and never match sibling paths
  that merely share a string prefix.
- Registry writes are private and atomic; corrupt state is reported and never
  executed or silently discarded.
- Removing a profile cleans its bindings while preserving all unrelated
  bindings and workspace files.
- Existing commands retain their behavior when no binding matches.
