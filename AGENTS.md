# AGENTS.md

Guidance for AI coding agents (Codex, Claude Code, Cursor, and similar) working
in this repository. Humans should start with [README.md](README.md).

> Not to be confused with [`agent.md`](agent.md), which is a separate operator
> prompt for the project's outreach automation, not instructions for agents
> editing this codebase.

## What this project is

`codex-profiles` is a single-file, dependency-free Bash CLI for named Codex
homes and named ChatGPT windows with separate local state. Every profile
selects a `CODEX_HOME`; named macOS Desktop launches additionally select
Electron user data for the entire ChatGPT window across Chat, Work, and Codex.
The whole program is [`bin/codex-profile`](bin/codex-profile).

It is community-maintained and is **not** an official OpenAI project.

## Repository layout

- `bin/codex-profile` — the entire CLI (Bash). Edit this for behavior changes.
- `.agents/skills/` — repo-local Codex outreach workflow skills.
- `test/codex-profile-test.sh` — Bash behavior test suite.
- `test/package-metadata-test.sh` — release metadata and packaging alias checks.
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
codex-profile app default ~/Dev/project  # stock ChatGPT session (macOS)
codex-profile app work ~/Dev/project     # named ChatGPT window with separate local state
codex-profile status                     # read-only Codex-local overview
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
- Bump the version together in `bin/codex-profile`, `package.json`, both
  `package-lock.json` version fields, `docs/index.html`,
  `packaging/aur/PKGBUILD`, and `packaging/aur/.SRCINFO`. CI and the GEO test
  enforce this synchronization.
- Document user-facing changes under `## Unreleased` in `CHANGELOG.md`.
- Keep the scope contract explicit: `cli`/`login`/`env`/`use` are Codex-only;
  `app default` preserves stock ChatGPT Desktop state; named `app` launches use
  matching `CODEX_HOME` and Electron data for the entire ChatGPT window.
- Desktop code must launch the original signed bundle. Do not reintroduce app
  clones, metadata patching, ad-hoc signing, global quitting, or broad kills.
- Keep `--instance`, `--rebuild`, and `app-instance` as deprecated
  compatibility spellings until a documented breaking release.

## Outreach ledger

When doing outreach, directory submissions, PR distribution, or follow-up work,
keep Airtable as the durable source of truth. Preserve existing platform
records; do not delete or overwrite history. For meaningful updates, update the
target row's status, last-checked date, next action, and notes, then append a
log entry with the exact outcome, reason, and relevant link.

## Safety boundaries (state these accurately)

- CLI-oriented commands select `CODEX_HOME`; named Desktop launches also select
  per-profile Electron user data. The tool never reads, copies, prints, parses,
  compares, or migrates `auth.json` tokens or ChatGPT cookies.
- `clone-config` copies only an allowlist of non-secret root config files and
  refuses sensitive-looking key names.
- `init --share-with` links only the documented configuration allowlist. It
  keeps auth, sessions, logs, Electron data, caches, skills, and connector/app
  state separate and never reads or copies authentication data; linked config
  and plugins remain mutually visible.
- `status` is Codex-local. Account equality between CLI and Desktop is not
  inspected or verified.
- Local-state separation is not an account, OS, or server-side boundary. SSH
  keys, keychains, external CLI credentials, and other state remain shared by
  the OS user. For strict separation, use separate OS users.
