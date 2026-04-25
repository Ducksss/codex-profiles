# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows semantic versioning once tagged releases begin.

## Unreleased

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
