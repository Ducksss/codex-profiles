# AGENTS.md

Guidance for AI coding agents (Codex, Claude Code, Cursor, and similar) working
in this repository. Humans should start with [README.md](README.md).

> Not to be confused with [`agent.md`](agent.md), which is a separate operator
> prompt for the project's outreach automation, not instructions for agents
> editing this codebase.

## What this project is

`codex-profiles` is a single-file, dependency-free Bash CLI that runs Codex CLI
and Codex Desktop with isolated `CODEX_HOME` directories, so each account
(personal, work, school, client) keeps its own auth, config, sessions, plugins,
caches, and logs. The whole program is [`bin/codex-profile`](bin/codex-profile).

It is community-maintained and is **not** an official OpenAI project.

## Repository layout

- `bin/codex-profile` — the entire CLI (Bash). Edit this for behavior changes.
- `test/codex-profile-test.sh` — Bash behavior test suite.
- `test/geo-site-test.mjs` — validates the AI-readable `docs/` site (Node, no deps).
- `docs/` — GitHub Pages site plus `llms.txt`, `robots.txt`, `sitemap.xml`, GEO docs.
- `Makefile` — `install`, `uninstall`, `lint`, `test`, `npm-package-test`.
- `CHANGELOG.md` — Keep a Changelog format; add entries under `## Unreleased`.

## Setup, build, and test

There is no build step. Run the full test suite (Bash syntax checks, CLI
behavior, install smoke tests, the npm package smoke test, and the GEO docs
validator):

```sh
make test
```

Lint the shell sources (requires ShellCheck):

```sh
make lint
```

Install locally from source (copies `bin/codex-profile` to `~/.local/bin`):

```sh
make install
```

## How to run the tool

```sh
codex-profile init work                  # create the work profile's CODEX_HOME
codex-profile login work                 # authenticate that profile once
codex-profile cli work                   # Codex CLI on the work profile
codex-profile cli work exec "run tests"  # one-shot Codex CLI command
codex-profile app work ~/Dev/project     # Codex Desktop on a profile (macOS)
codex-profile app-instance work ~/Dev/p  # parallel Desktop instance (macOS, experimental)
codex-profile status                     # read-only profile overview
codex-profile doctor                     # environment diagnostics
```

Profile-to-path mapping: `default -> ~/.codex`; any other name `<x> -> ~/.codex-<x>`.

## Conventions for changes

- Keep the CLI dependency-free: Bash plus standard POSIX/macOS tools only. Do not
  add a runtime users would have to install.
- Run `make test` and `make lint` before proposing changes; both must pass.
- Match the existing Bash style in `bin/codex-profile`: `set -euo pipefail`,
  `command_*` functions for subcommands, and the `die`/`note` helpers.
- If you change the command surface, update `usage()` in `bin/codex-profile`,
  the README command reference, the shell completion generators, and
  `docs/llms.txt` so all four stay in sync.
- Bump the version in three places together — `VERSION` in `bin/codex-profile`,
  `version` in `package.json`, and `softwareVersion` in `docs/index.html`.
  `test/geo-site-test.mjs` asserts the docs version matches `package.json`.
- Document user-facing changes under `## Unreleased` in `CHANGELOG.md`.

## Safety boundaries (state these accurately)

- The tool only sets `CODEX_HOME`. It never reads, copies, prints, parses, or
  migrates `auth.json` tokens.
- `clone-config` copies only an allowlist of non-secret root config files and
  refuses sensitive-looking key names.
- Profile isolation covers Codex local state, not the operating system. SSH
  keys, GitHub CLI auth, browser cookies, and other credentials are still shared
  by the OS user. For strict separation, use separate OS users.
