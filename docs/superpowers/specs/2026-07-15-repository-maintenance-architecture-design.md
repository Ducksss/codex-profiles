# Repository Maintenance Architecture Design

## Summary

Reorganize the repository-only development, test, packaging, and release
tooling around small responsibility-based scripts and a single verification
entrypoint. Preserve `bin/codex-profile` as the complete dependency-free
runtime and preserve every public command, compatibility spelling,
installation method, state boundary, and safety guarantee.

The refactor removes duplicated command inventories and workflow logic,
replaces executable documentation with tested scripts, and splits oversized
test suites by product area. It does not add user-facing behavior or publish
to any external service.

## Current State

At the start of this work, `origin/main` is `316dcb9` and the clean baseline
passes:

```sh
make test
make lint
git diff --check
```

The repository already has strong behavior and release coverage. Its primary
maintenance costs are structural:

- `Makefile` repeats shell-source and test-file inventories across syntax,
  lint, and test targets.
- CI repeats checks already included in `make test`.
- `.github/workflows/release.yml` contains about 900 lines, most of which are
  inline Bash that can only be tested indirectly.
- `test/release-workflow-test.sh` is about 1,450 lines because it must extract,
  inspect, and simulate inline workflow programs.
- `test/codex-profile-test.sh` has grown beyond 2,500 lines and now covers
  unrelated profile, Desktop, workspace, JSON, shell, and upgrade domains.
- `packaging/aur/README.md` contains more than 600 lines and eleven executable
  Bash blocks whose behavior is validated by extracting Markdown.
- Bash and Node test suites repeat assertion, fixture, and command-shim code.

The goal is to preserve the existing rigor while making each guarantee live in
one authoritative, directly testable location.

## Goals

- Keep the shipped CLI as one dependency-free Bash file.
- Give contributors one discoverable local verification interface.
- Make Make, npm, CI, and release workflows delegate to that interface instead
  of maintaining parallel command lists.
- Organize tests by product or operational responsibility.
- Share only genuinely common test infrastructure.
- Move release behavior from workflow YAML into versioned, directly tested
  scripts.
- Keep GitHub Actions focused on permissions, secrets, job dependencies,
  runner setup, and sequencing.
- Replace executable AUR documentation with reusable preparation and
  verification scripts plus a concise operator guide.
- Preserve fail-closed release behavior, idempotency, post-publication
  verification, and credential boundaries.
- Improve contributor and agent documentation so repository responsibilities
  and commands are easy to find.
- Remove obsolete tests and duplicated logic only after their replacements
  pass.

## Non-goals

- Do not split or source runtime libraries from `bin/codex-profile`.
- Do not change the command surface, output formats, completion behavior,
  profile mapping, workspace routing, or update behavior.
- Do not change the standalone installer or package names.
- Do not bump the release version.
- Do not add a runtime or development package dependency.
- Do not publish npm, GitHub, Homebrew, AUR, or Pages artifacts while
  implementing this refactor.
- Do not weaken release validation, remove compatibility spellings, or reduce
  security and privacy coverage.
- Do not move or redesign the Airtable outreach ledger or repo-local outreach
  skills beyond integrating their tests with the common check runner.
- Do not make broad cosmetic changes to the product website.

## Repository Architecture

The intended responsibility boundaries are:

```text
bin/
  codex-profile

scripts/
  check
  update-homebrew-formula
  outreach-tracker.mjs
  release/
    lib.sh
    verify-source.sh
    preflight.sh
    verify-state.sh
    publish-tag.sh
    publish-npm.sh
    publish-github.sh
    verify-distribution.sh
    update-homebrew.sh
    deploy-pages.sh
  aur/
    prepare.sh
    verify.sh

test/
  lib/
    assertions.sh
    cli-fixtures.sh
    command-shims.sh
  cli/
    profiles-test.sh
    desktop-test.sh
    workspace-test.sh
    status-json-test.sh
    shell-test.sh
    upgrade-test.sh
  install/
    standalone-test.sh
    makefile-test.sh
    npm-package-test.sh
  release/
    source-test.sh
    state-test.sh
    npm-test.sh
    github-test.sh
    distribution-test.sh
    homebrew-test.sh
    pages-test.sh
    workflow-contract-test.mjs
  packaging/
    metadata-test.sh
    aur-test.mjs
  site/
    geo-test.mjs
  outreach/
    tracker-test.mjs
    agent-test.mjs
    skills-test.mjs
  fixtures/
    aur-rpc/
      exact-final-version.json
      expected-owner.json
      unclaimed.json
      unexpected-owner.json
    github-release-contract.json
```

This tree is the implementation target. The architectural rules are:

1. Runtime behavior remains entirely in `bin/codex-profile`.
2. Repository automation lives under `scripts/` and is callable outside CI.
3. Tests mirror the responsibility they validate.
4. Shared helpers contain infrastructure, not product expectations.
5. Every executable behavior has one authoritative implementation.

Moving files must preserve useful Git history with `git mv` where practical.

## Verification Interface

`scripts/check` is the canonical repository check dispatcher. It supports:

```text
scripts/check test
scripts/check lint
scripts/check syntax
scripts/check all
scripts/check list
```

The commands have these contracts:

- `test` discovers `test/**/*-test.sh` and `test/**/*-test.mjs`, sorts paths
  bytewise, and runs each test in a fresh process from the repository root.
- `syntax` validates every maintained shell source and Node module, including
  helper files that are not standalone tests.
- `lint` runs ShellCheck over the same discovered shell-source inventory used
  by `syntax`.
- `all` runs syntax, tests, and lint, stopping on the first failure.
- `list` prints the discovered sources and tests without running them so file
  inventory behavior is itself testable.

Discovery is limited to explicit repository roots and filename conventions.
It ignores fixtures, generated files, npm pack output, `.git`, and worktree
metadata. Paths are sorted with a stable locale. Missing tools produce a clear
error except that the existing npm package smoke behavior may continue to skip
when npm is unavailable.

The public Make targets become small delegates:

```text
make test    -> scripts/check test
make lint    -> scripts/check lint
make check   -> scripts/check all
```

Install, uninstall, path, source-install, and npm-package smoke targets remain
available for direct use. Their implementation may move into scripts when that
removes Make quoting or mutation-test complexity, but their names and behavior
remain stable.

`npm test` continues to use `make test`, so package contributors do not need
ShellCheck merely to run behavior tests. Linux CI uses `make check`; macOS CI
uses `make test` plus any platform-specific verification not covered by the
common suite.

## Test Organization

The current CLI behavior suite is split along stable product boundaries:

- profiles: path mapping, discovery, initialization, removal, shared config,
  config cloning, and core CLI/login forwarding;
- Desktop: signed app discovery, named Electron state, compatibility options,
  access-token rejection, and app failures;
- workspaces: binding persistence, resolution, guard modes, routing, lifecycle
  integration, and diagnostics;
- status and JSON: human status, JSON escaping, machine-output cleanliness,
  list, and doctor schemas;
- shell integration: `env`, `use`, shell initialization, completions, and logs;
- upgrade: checkout selection, version ordering, update checks, cache behavior,
  and installation.

Each suite owns its temporary root and cleanup. Shared Bash helpers provide:

- command capture and status assertions;
- string and path assertions;
- safe temporary-directory lifecycle;
- fake Codex and signed ChatGPT bundle factories;
- reusable command shims for network and release tools.

Helpers never hide the behavior under test. Domain-specific expected output,
security assertions, and scenario setup remain in the owning suite. Node tests
use the built-in `node:assert` module and share only filesystem or process
fixtures that otherwise appear in more than one file.

Tests remain independent and may be run directly. No test relies on a previous
test's filesystem, environment, or process state.

## Release Automation

The release workflow retains two GitHub jobs: source verification and live
publication. It remains manually dispatched, fail closed, concurrency-locked,
and limited to `main` for release actions.

Workflow YAML owns:

- dispatch inputs;
- job and step permissions;
- GitHub environment and secret mapping;
- checkout and tool setup;
- dry-run versus live job conditions;
- job outputs and dependencies;
- human-readable step summaries.

Repository scripts own:

- version and metadata synchronization;
- immutable source and branch checks;
- attestation validation and sanitization;
- release credential identity preflight;
- release-state revalidation;
- tag creation race handling;
- npm publication and integrity verification;
- GitHub Release creation and public verification;
- standalone installer verification;
- Homebrew formula updates and postconditions;
- Pages dispatch and deployed-version verification.

Scripts receive explicit arguments and documented environment variables. They
do not infer hidden workflow context when an argument can be passed directly.
Machine-readable outputs use stable `key=value` lines or explicit output-file
arguments. Human diagnostics go to stderr so callers can safely capture
outputs.

`scripts/release/lib.sh` contains only release-wide primitives used by at
least two scripts, such as exact semantic-version validation, bounded retry,
safe temporary-directory setup, and common command requirements. Channel
behavior stays in the channel script rather than accumulating in the library.

Every mutating release script validates its prerequisites before the first
mutation and verifies the external postcondition afterward. Re-running a step
accepts an existing result only when it exactly matches the requested version,
commit, integrity, and publication state. Races that converge on the same
immutable result succeed; conflicting state fails.

## AUR Operations

The AUR flow remains outside the GitHub release workflow because its SSH
credential and maintainer-account boundary is deliberately operator-owned.

`scripts/aur/prepare.sh`:

- accepts an exact release tag or version;
- obtains or validates an immutable release archive;
- verifies tracked PKGBUILD and `.SRCINFO` metadata;
- prepares a disposable AUR checkout or staging directory;
- prints the exact files and commit state that an operator would publish;
- never pushes.

`scripts/aur/verify.sh`:

- validates a prepared checkout;
- supports the existing clean Arch container check when Docker is available;
- verifies public AUR RPC state from supplied or fetched JSON;
- validates ownership, version, source URL, checksums, and installed aliases;
- never logs credentials or private SSH configuration.

The AUR README becomes a concise operator runbook that explains prerequisites,
credential ownership, first publication, updates, the explicit commit/push
step, and rollback or recovery. It calls the scripts instead of embedding
parallel implementations in Markdown. Tests invoke the scripts with fixtures;
they no longer extract executable blocks from documentation.

## Error Handling and Safety

- Bash automation uses `set -euo pipefail`; POSIX installer code retains
  `set -eu` where Bash is not part of its contract.
- Temporary paths are created beneath controlled disposable roots, cleaned by
  traps, and validated before any recursive deletion.
- Script arguments, versions, refs, paths, URLs, JSON fields, and external
  command results are validated before use.
- Secrets are passed only to the step or process that needs them and are never
  echoed, placed in command-line diagnostics, persisted in fixtures, or added
  to summaries.
- Network retries are bounded and distinguish eventual consistency from
  malformed or conflicting state.
- Cleanup cannot replace an earlier nonzero status with success.
- Workflow dry runs perform no tag, registry, release, tap, AUR, or Pages
  mutation.
- Tests use fake commands, local fixtures, and disposable homes. They never
  inspect real Codex authentication, ChatGPT cookies, account identifiers,
  keychains, or user application state.
- Runtime safety contracts for profile homes, shared configuration, workspace
  registries, Desktop state, and signed app launching remain unchanged.

## Documentation

- `README.md` remains the end-user entrypoint and does not absorb internal
  implementation detail.
- `CONTRIBUTING.md` explains `make test`, `make lint`, `make check`, focused
  test execution, test placement, and release rehearsal.
- `AGENTS.md` maps the new repository layout and preserves all behavioral and
  safety instructions.
- Release and AUR operator documentation names the script that implements each
  step and clearly labels external mutations.
- `CHANGELOG.md` records the maintenance and release-infrastructure refactor
  under `Unreleased` without claiming a user-facing feature or version bump.
- `docs/llms.txt` and product command references change only if repository
  instructions they expose become stale; the CLI command surface is unchanged.

## Migration Strategy

Implementation proceeds in behavior-preserving slices:

1. Add and test the check dispatcher while it still runs the existing suites.
2. Make Make, npm, and CI delegate to the new interface and remove only proven
   duplicate invocations.
3. Add shared test infrastructure and split CLI tests one responsibility at a
   time, running both focused and full suites after each move.
4. Extract release source and state validation, then each publication channel,
   replacing the matching workflow block only after direct tests pass.
5. Reduce workflow contract tests to GitHub-specific structure and wiring.
6. Extract AUR preparation and verification, migrate its fixtures, and shorten
   the runbook only after script parity is demonstrated.
7. Update contributor, agent, release, and changelog documentation.
8. Run the complete cross-repository verification and inspect the final diff
   for duplicated or dead infrastructure.

No compatibility bridge is needed for internal file paths. Public Make targets
and package scripts remain compatible. Obsolete internal test paths and
wrappers are deleted after all callers use the new structure.

## Verification Strategy

Every structural slice follows red-green-refactor testing:

- add a focused test for the new dispatcher or extracted script;
- demonstrate that it fails without the new implementation;
- implement the smallest complete behavior;
- run the focused test;
- run the affected domain suite;
- run `make test` and `make lint` before removing the old implementation.

Final verification includes:

```sh
make test
make lint
make check
git diff --check
```

It also includes direct focused execution of every release and AUR test,
standalone and npm installation smoke tests, package metadata validation, and
clean-worktree checks that prove verification does not leave artifacts.

## Acceptance Criteria

- `bin/codex-profile` remains the complete installed runtime and passes all
  existing CLI, Desktop, workspace, shell, JSON, and upgrade behavior tests.
- All public Make targets and npm command aliases retain their behavior.
- One discovery implementation determines maintained shell sources and test
  files; Make, CI, and documentation do not duplicate that inventory.
- Every test suite can run independently from the repository root.
- No CLI test file mixes unrelated profile, Desktop, workspace, shell, status,
  and upgrade responsibilities.
- Shared helpers remove repeated infrastructure without hiding expected
  behavior or coupling suite state.
- Release workflow YAML contains GitHub orchestration rather than embedded
  channel implementations.
- Release behavior is directly covered with command shims and fixtures,
  including success, idempotent retry, convergent race, conflicting state,
  malformed response, missing credential, transient failure, and failed
  postcondition scenarios.
- Dry-run release verification performs no external mutation.
- AUR preparation and verification are reusable scripts, and the operator
  guide contains no duplicated executable implementation.
- CI runs each required check once per appropriate platform unless a repeated
  run validates a genuinely different package or platform boundary.
- No new runtime or development dependency is introduced.
- No secret, authentication token, cookie, account identifier, or live user
  state is read or written by tests or migration tooling.
- `make test`, `make lint`, `make check`, and `git diff --check` all pass from a
  clean checkout on the supported development environment.
- The final repository has no obsolete test wrappers, extracted-Markdown test
  machinery, repeated workflow programs, or undocumented maintenance scripts.
