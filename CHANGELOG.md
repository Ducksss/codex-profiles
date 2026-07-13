# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows semantic versioning for tagged releases.

## Unreleased

### Changed

- Added practical GitHub Q&A guides for separate Codex CLI profiles, named
  ChatGPT Desktop windows, and the local-state isolation boundary.

## 0.7.0 - 2026-07-13

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
- A permanent [AUR publication and update runbook](packaging/aur/README.md)
  covering dedicated credentials, immutable tagged inputs, clean non-root Arch
  builds, metadata and alias validation, first publication, subsequent updates,
  and public post-push verification.

### Changed

- Adapted Desktop launching to OpenAI's integrated ChatGPT app. `app default`
  launches the original signed application with `CODEX_HOME=~/.codex` and no
  custom Electron user-data directory, preserving the stock ChatGPT session.
- Named `app <profile>` launches now use both `~/.codex-<profile>` and matching
  `electron-user-data` for the entire ChatGPT window across Chat, Work, and
  Codex. Different names can coexist; reopening one name reuses its context.
- Desktop discovery now prefers `CHATGPT_APP`, accepts legacy `CODEX_APP`, and
  detects `/Applications/ChatGPT.app` before legacy `Codex.app`.
- CLI resolution now validates candidates: an explicit `CODEX_CLI` must be
  healthy; otherwise the wrapper can fall back from `PATH` to an explicit
  bundled candidate or the CLI inside the detected Desktop app.
- Documentation, security guidance, support templates, GEO structured data,
  launch copy, and AI-readable facts now distinguish Codex-only commands from
  whole-window ChatGPT Desktop profiles.
- Version metadata is aligned on `0.7.0` without changing the project,
  repository, npm package, commands, or profile-directory names.
- Source, standalone, npm, Nix, AUR, and Homebrew release paths now preserve
  both `codex-profile` and `codex-profiles` command spellings. CI validates the
  aliases and synchronized package metadata on Linux and macOS.
- Releases are now explicit, version-validated workflow dispatches from
  `main`; the workflow verifies the dated changelog, publishes idempotently,
  updates Homebrew, and deploys Pages from the immutable release tag.
- The npm tarball excludes historical pre-v0.7 screenshot and video assets;
  those files remain in the repository for release-history context.
- Clarified current product copy, CLI diagnostics, and package metadata to
  describe local-state separation without implying a verified account or
  security boundary.
- Expanded the default release dry run to rehearse the standalone installer,
  npm package, Homebrew helper, and pinned AUR package paths. Live releases now
  require a strict, sanitized signed-app version/bundle attestation,
  preflight the npm owner identity and reported GitHub account access, recheck
  main and tag state immediately before tagging, and verify the published npm
  aliases with bounded registry retries, the exact immutable GitHub Release as
  latest with non-empty notes, the public standalone installer's latest-release
  path in a fresh prefix, and a newly dispatched Pages run and version; external
  AUR publication remains a maintainer action.
- Split default release verification into a credentialless, read-only job and
  live publication into a separately gated write job that revalidates
  `origin/main` and remote tag state. Registry, tag, and GitHub Release lookups
  now fail closed while safely accepting only exact-version concurrent results.
- Made the standalone installer validate exact release tags and payload
  versions, then replace both installed command aliases transactionally with
  rollback if any late install or verification step fails.

### Removed

- Removed Desktop app copying, bundle metadata patching, ad-hoc signing,
  canonical-app quitting, and broad process-kill behavior. The installed signed
  application is never modified or replaced.
- Removed stale clone-based screenshot and video references from primary
  documentation. Historical release and outreach records remain intact.

### Deprecated

- `app --instance`, `app --rebuild`, and `app-instance` remain accepted
  compatibility spellings but use the ordinary named launcher. Named launches
  are already parallel-capable, and `--rebuild` is now a no-op because no app
  clone exists.
- `CODEX_APP_BIN` remains a compatibility override only for an executable
  inside an application bundle. Prefer the `CHATGPT_APP` bundle override.

### Fixed

- Corrected the AI-readable profile graph so `personal` maps to
  `~/.codex-personal` rather than `~/.codex`; `default` remains the only name
  mapped to `~/.codex`.
- Clarified that `status` describes Codex-local authentication and that the
  tool does not inspect or verify equality between CLI and Desktop accounts.
- Normalized current logged-out CLI messages, prevented update notices from
  polluting `status --json` and `doctor --json`, and expanded doctor output
  with detected app metadata, CLI source/health, and explicit scope fields.
- Rejected symlinked managed profile and Electron user-data directories before
  creating files or changing permissions.
- Made source installs refuse command-directory and canonical-symlink
  destinations, verify both installed aliases, and smoke-test updates without
  masking producer failures.
- Restored deprecated `app-instance` discovery in all shell completions,
  registered completions for both executable aliases, and rejected legacy
  `CODEX_APP_BIN` values that do not name the bundle's declared executable.

### Security

- Replaced overbroad isolation claims with an explicit local-state model.
  Named Electron data is not an operating-system sandbox or a server-side
  ChatGPT workspace boundary; keychains, external credentials, filesystem
  access, and OpenAI-managed state remain shared or outside the tool's control.
- Desktop launch now refuses an inherited `CODEX_ACCESS_TOKEN` so a shell
  access token cannot silently override the selected window's authentication
  context.

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
