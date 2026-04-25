# codex-profiles

[![CI](https://github.com/Ducksss/codex-profiles/actions/workflows/ci.yml/badge.svg)](https://github.com/Ducksss/codex-profiles/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Run Codex with isolated account profiles.

`codex-profiles` is a tiny Bash helper for people who use more than one Codex
account. It launches the Codex CLI or Codex Desktop app with a selected
`CODEX_HOME`, so auth, config, sessions, plugins, and local Codex state live in
separate directories.

## Why

Codex supports `CODEX_HOME`, but switching profiles manually gets old:

```sh
CODEX_HOME="$HOME/.codex-personal" codex
CODEX_HOME="$HOME/.codex-work" codex exec "review this repo"
CODEX_HOME="$HOME/.codex-edu" /Applications/Codex.app/Contents/MacOS/Codex
```

This project turns that into:

```sh
codex-profile cli personal
codex-profile cli work exec "review this repo"
codex-profile app edu
```

## Install

```sh
git clone https://github.com/Ducksss/codex-profiles.git
cd codex-profiles
make install
```

Make sure `~/.local/bin` is on your `PATH`.

## Quick Start

Log into each profile once:

```sh
codex-profile login personal
codex-profile login work
codex-profile login edu
```

Run the CLI:

```sh
codex-profile cli personal
codex-profile cli work exec "run tests and summarize failures"
codex-profile cli edu review
```

Run the desktop app:

```sh
codex-profile app personal
codex-profile app work ~/Dev/my-project
codex-profile app edu
```

Check status:

```sh
codex-profile status
codex-profile doctor
```

## Profile Paths

Built-in profile mappings:

```text
default, dev, main  -> ~/.codex
edu, education      -> ~/.codex-education
any other name      -> ~/.codex-<profile>
```

Examples:

```text
personal -> ~/.codex-personal
work     -> ~/.codex-work
edu      -> ~/.codex-education
```

## Shell Aliases

Optional aliases:

```sh
alias codex-personal='codex-profile cli personal'
alias codex-work='codex-profile cli work'
alias codex-edu='codex-profile cli edu'

alias codex-app-personal='codex-profile app personal'
alias codex-app-work='codex-profile app work'
alias codex-app-edu='codex-profile app edu'
```

## Desktop App Notes

Codex Desktop should run one profile at a time. `codex-profile app <profile>`
asks the running Codex app to quit, waits for it to close, and then launches the
app with the selected `CODEX_HOME`.

For best isolation, launch the desktop app through this tool instead of Dock or
Spotlight.

## Security Model

This tool does not copy, parse, print, or manage auth tokens. It only selects a
`CODEX_HOME` directory before running Codex.

This is better than swapping `auth.json` files because each profile gets its own
Codex state directory. It is still not the same as full OS-level isolation:
external credentials such as SSH keys, GitHub CLI auth, browser cookies, npm,
AWS, or Google Cloud credentials are still shared by your operating system user.

For strict work/personal separation, use separate OS users.

## Commands

```text
codex-profile app <profile> [workspace]
codex-profile cli <profile> [codex-args...]
codex-profile login <profile> [codex-login-args...]
codex-profile status [profile]
codex-profile path <profile>
codex-profile doctor
```

## Environment Overrides

```text
CODEX_APP       Override Codex.app path
CODEX_APP_BIN   Override Codex Desktop binary path
CODEX_CLI       Override Codex CLI binary path
```

## License

MIT
