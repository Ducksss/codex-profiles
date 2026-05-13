# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows semantic versioning once tagged releases begin.

## Unreleased

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

### Changed

- All-profile `status` now skips unmanaged reserved-alias directories and
  invalid `.codex-*` directory names during discovery.
- `doctor` now accepts options and can emit machine-readable output.

### Tests

- Added coverage for CLI/login argument pass-through, invalid profile names,
  list output, version output, hardened status discovery, JSON diagnostics,
  profile lifecycle commands, log inspection, completion generation, and safe
  config cloning.

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
