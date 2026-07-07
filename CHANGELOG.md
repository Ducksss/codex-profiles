# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows semantic versioning for tagged releases.

## Unreleased

### Added

- Repo-local GitHub pipeline skill set for lead generation, lead
  qualification, closing drafts, and monitoring, with Airtable handoffs and
  approval-gated external actions enforced by tests.
- Repo-local `github-lead-gen` skill for GitHub candidate discovery, with
  Airtable-only intake boundaries and search-lane references.
- Airtable-first GitHub lead workflow instructions for the outreach agent,
  including repository-first qualification, ICP/truthfulness gates,
  approval-gated external actions, pipeline views, and a regression test that
  keeps `agent.md` aligned with the workflow.
- Additional install channels: a `curl | sh` installer (`install.sh`, fetches
  the latest release into `~/.local/bin`), a Nix flake
  (`nix run github:Ducksss/codex-profiles`), and an AUR `PKGBUILD` under
  `packaging/aur/`. The installer and flake track the current version
  automatically (the flake reads `package.json`), so they add no release drift;
  `install.sh` is covered by ShellCheck in CI.

## 0.6.0 - 2026-07-01

### Changed

- Parallel Codex Desktop launch is now an opt-in flag on the primary command:
  `codex-profile app <profile> --instance` (with `--rebuild` still available,
  only valid together with `--instance`). Plain `codex-profile app` remains the
  cheap, notarized single-app switcher and stays the default. This collapses the
  two co-equal launch commands into one verb with an advanced flag, matching how
  GUI apps (Firefox `-no-remote`, Chrome/VS Code `--user-data-dir`) expose
  parallel-instance launching, and keeps the `--instance` naming consistent with
  the existing `logs <profile> --instance` and `CODEX_PROFILE_APP_INSTANCE_ROOT`.
- Help, examples, and shell completions now lead with `app` and present
  `--instance`/`--rebuild` as its flags; `app-instance` is no longer advertised.

### Deprecated

- `codex-profile app-instance <profile>` is now a deprecated, undocumented alias
  for `codex-profile app <profile> --instance`. Existing scripts and muscle
  memory keep working; prefer the flag form going forward.

## 0.5.0 - 2026-07-01

### Changed

- The release workflow now updates the Homebrew tap (`Ducksss/homebrew-tap`)
  after publishing, so `brew` installs track the latest version. Requires a
  `TAP_TOKEN` repo secret with write access to the tap; the step is skipped
  when the secret is absent.
- Release workflow runs on `actions/setup-node@v6` / Node 22, clearing the
  Node 20 runtime deprecation warning.

## 0.4.2 - 2026-07-01

### Fixed

- The fish `use` wrapper emitted by `shell-init fish` piped `env ... | source`,
  so it returned `source`'s exit status (always 0) and swallowed `env`'s
  failure — `use <invalid>` or `use` with no argument reported success in fish
  while bash/zsh correctly returned non-zero. It now captures `env`'s output and
  propagates the failure status, restoring cross-shell parity.

## 0.4.1 - 2026-07-01

### Added

- In-shell activation. `env <profile>` prints shell code (`export CODEX_HOME=...`,
  or `set -gx ...` with `--shell fish`) to evaluate so the current shell is pinned
  to a profile without prefixing every command; it also exports an informational
  `CODEX_PROFILE_NAME` marker (never read by the tool) for prompts. `shell-init
  <bash|zsh|fish>` prints a shell wrapper that enables the shorter `use <profile>`
  verb; run without the wrapper, `use` prints setup guidance instead of failing.
  Both stay within the existing boundary — the tool only ever sets `CODEX_HOME`.
  Uninitialized profiles warn on stderr so evaluated stdout stays clean. Completion
  generators, README, and `docs/llms.txt` updated for the new commands.

### Changed

- Releases are now automated. Pushing a change under `bin/**` to `main` (or a
  manual workflow dispatch) auto-increments the patch version, bumps every
  version file in lockstep, runs `make test`, commits, tags, publishes to npm,
  and creates the GitHub Release. Replaces the tag-triggered publish workflow.
  A workflow-dispatch `version` input can force a minor/major bump.

## 0.4.0 - 2026-07-01

### Added

- Update check: interactive runs query the npm registry at most once per day
  (in the background, result cached) and print a one-line notice to stderr when
  a newer release is available. It stays silent in non-interactive use (scripts,
  pipes, CI, `--json`) and can be disabled with `CODEX_PROFILE_NO_UPDATE_CHECK`
  or `DO_NOT_TRACK`. See README "Update Checks" and SECURITY.md "Network
  Activity".
- GitHub Actions workflow that publishes the `codex-profile` npm package on
  `v*` tag pushes (or manual dispatch), gated on `make test` and verifying the
  tag matches `package.json`, with npm provenance.
- Release-drift guard: `make test` now asserts that `bin/codex-profile`'s
  `VERSION` matches `package.json` (which already had to match the docs
  `softwareVersion`), so a version bump can't ship a CLI that reports a stale
  version. Added `doctor` happy-path and `upgrade` missing-Makefile test cases.

### Changed

- `clone-config` allowlist now matches current Codex instruction-file
  conventions: dropped the obsolete `instructions.md` and
  `custom-instructions.md` entries, leaving `config.toml` and the global
  `AGENTS.md` (Codex consolidated global user instructions onto `AGENTS.md`).
- `app` and `app-instance` now fail with a clear "only available on macOS"
  message on non-macOS systems instead of a Codex-path "not found" error.
- `help` is now listed in `codex-profile help` output, and the README
  Platform Support list includes `version` and `help`.

## 0.3.0 - 2026-06-30

### Added

- AI-native onboarding: a root `AGENTS.md` that gives AI coding agents working in
  the repository the project overview, setup, test, run, convention, and safety
  guidance in the format Codex and similar agents read automatically.
- README "Run It With an AI Assistant" section with a ready-to-paste prompt for
  chatbots and an expandable copy-paste answer block for "how do I run this?".
- `llms.txt` "How to run" answer template and an AI-assistant FAQ entry on the
  GitHub Pages project page.
- npm package metadata and public install documentation for the published
  `codex-profile` package.
- Experimental `app-instance` command for launching profile-specific Codex
  Desktop app clones with isolated `CODEX_HOME`, Electron user data, and
  profile-local instance logs.
- `logs <profile> --instance` for reading experimental app-instance logs.
- Branded README demo asset showing two scoped Codex Desktop profile instances
  side by side.
- README launch-mode and isolation-boundary tables for the experimental
  parallel Desktop workflow.
- README origin-story section explaining the real multi-account workflow that
  motivated the project.
- GitHub Pages-ready GEO documentation with canonical metadata, JSON-LD,
  `robots.txt`, `sitemap.xml`, `llms.txt`, a public audit matrix, and a
  measurement plan.
- Pages deployment workflow for publishing the static GEO documentation.

### Changed

- Refreshed README positioning around profile-scoped Codex Desktop instances
  and included media assets in the npm package file list.
- Updated package homepage and package file list so the AI-readable docs ship
  with npm metadata.

### Fixed

- Desktop profile switching now escalates to a forced quit if Codex does not
  close cleanly after the initial quit request.
- Fixed experimental app-instance launches on macOS by preserving Codex's
  `CFBundleName` for Electron helper lookup and launching cloned bundles
  through `open -a` with workspace folders passed as documents.

### Tests

- Added npm package installation coverage.
- Added coverage for app-instance launch isolation, app clone rebuilds, and
  completion/help output.
- Added GEO documentation tests for canonical URLs, indexability directives,
  robots, sitemap, FAQ/schema alignment, `llms.txt`, measurement docs, and
  Pages deployment wiring.

## 0.2.0 - 2026-05-21

### Added

- `init` command for explicit profile home creation.
- `remove` command with profile-name confirmation and `--yes` automation mode.
- `logs` command for printing, tailing, or locating profile-local desktop logs.
- `clone-config` command for copying known non-secret config files between
  profiles without copying auth, sessions, plugins, logs, or caches.
- `status --json` and `doctor --json` for script-friendly diagnostics.
- `completions` command for Bash, Zsh, and Fish completion generation.
- `list` command for read-only initialized profile discovery.
- `version` and `--version` output.
- `upgrade` command for source-style self-updates from the project git
  repository, including `--dry-run`, `--prefix`, `--ref`, unversioned-candidate
  refusal, older-version refusal, and branch, tag, or commit-SHA refs.

### Changed

- Profile path mapping now treats only `default` as special. Every other valid
  name, including `dev`, `main`, and `edu`, maps directly to
  `.codex-<profile>`.
- All-profile `status` now skips invalid `.codex-*` directory names during
  discovery.
- `doctor` now accepts options and can emit machine-readable output.

### Tests

- Added coverage for CLI/login argument pass-through, invalid profile names,
  direct profile-name path mapping, list output, version output, hardened
  status discovery, JSON diagnostics, profile lifecycle commands, log
  inspection, completion generation, source upgrades, dirty upgrade checkout
  protection, commit-SHA refs, unversioned-candidate refusal, older-version
  refusal, and safe config cloning.

## 0.1.1 - 2026-04-25

### Fixed

- Desktop app switching now waits for both the main Codex app process and the
  bundled Codex app-server process to stop before launching a new profile.
- Profile directory permission setup now fails loudly if private permissions
  cannot be applied.
- `status` no longer creates missing profile directories.
- `status` now propagates unexpected Codex CLI failures while still treating
  "Not logged in" as a normal status result.

## 0.1.0 - 2026-04-25

### Added

- Initial `codex-profile` CLI.
- Profile-aware commands for Codex CLI, Codex Desktop, login, status, path, and
  doctor workflows.
- macOS and Ubuntu CI smoke tests.
- Profile-local desktop log handling.
- Public README with installation, usage, FAQ, and security boundary sections.
- Contribution and security documentation.
- GitHub issue and pull request templates.
