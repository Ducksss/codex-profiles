# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows semantic versioning for tagged releases.

## Unreleased

### Added

- GitHub Actions workflow that publishes the `codex-profile` npm package on
  `v*` tag pushes (or manual dispatch), gated on `make test` and verifying the
  tag matches `package.json`, with npm provenance.

### Changed

- `clone-config` allowlist now tracks current Codex instruction-file
  conventions: dropped the obsolete `instructions.md` and
  `custom-instructions.md` (Codex consolidated on `AGENTS.md`) and added
  `AGENTS.override.md`.

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
