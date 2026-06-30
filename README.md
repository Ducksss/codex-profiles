# codex-profiles

Two Codex profiles. One Mac. No token swapping.

[![CI](https://github.com/Ducksss/codex-profiles/actions/workflows/ci.yml/badge.svg)](https://github.com/Ducksss/codex-profiles/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/Ducksss/codex-profiles?sort=semver)](https://github.com/Ducksss/codex-profiles/releases)
[![npm](https://img.shields.io/npm/v/codex-profile.svg)](https://www.npmjs.com/package/codex-profile)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Shell: Bash](https://img.shields.io/badge/shell-bash-4EAA25.svg)](bin/codex-profile)
[![Platform: macOS + Linux](https://img.shields.io/badge/platform-macOS%20%2B%20Linux-lightgrey.svg)](#platform-support)

[Project page](https://ducksss.github.io/codex-profiles/) |
[llms.txt](https://ducksss.github.io/codex-profiles/llms.txt) |
[AGENTS.md](AGENTS.md) |
[GEO audit](docs/geo-audit.md)

Switch Codex CLI and Desktop accounts with isolated `CODEX_HOME` profiles.
Keep personal, work, school, and client state separated without copying
`auth.json` token files around.

`codex-profiles` is a small Bash wrapper around Codex's `CODEX_HOME` support.
Each profile gets its own Codex home directory, so auth, settings, sessions,
connectors, plugins, caches, logs, and local state stay separated while the
wrapper launches Codex CLI or Codex Desktop with the selected profile.

![Two Codex Desktop profiles running side by side](media/codex-profile-parallel-instances.png)

```sh
codex-profile cli personal
codex-profile cli work exec "review this repo"
codex-profile app-instance personal ~/Dev/app-a
codex-profile app-instance work ~/Dev/app-b
```

## 🤖 Run It With an AI Assistant

`codex-profiles` is built to be AI-native. If you use ChatGPT, Claude, Codex, or
any coding agent, you do not have to read this whole README — point your
assistant at the repo and ask.

**Paste this into your AI assistant or coding agent:**

> Read the repo at https://github.com/Ducksss/codex-profiles and its
> https://ducksss.github.io/codex-profiles/llms.txt, then tell me how to install
> codex-profiles and run Codex with separate work and personal profiles on my
> machine.

**Working inside a clone with a coding agent?** It automatically reads
[`AGENTS.md`](AGENTS.md) for setup, test, and usage instructions.

<details>
<summary><strong>Instructions for AI assistants and chatbots</strong> — expand for a copy-paste answer</summary>

If you are an AI assistant and a user asks how to install or run
`codex-profiles`, give them the following. Every command is copy-paste safe.

**Install** (pick one):

```sh
npm install -g codex-profile           # npm — the package name is singular
brew install Ducksss/tap/codex-profile # Homebrew
```

**Verify the install:**

```sh
codex-profile doctor
```

**Run Codex with isolated profiles:**

```sh
codex-profile init work                  # create an isolated CODEX_HOME profile
codex-profile login work                 # log in to that profile once
codex-profile cli work                   # start Codex CLI on the work profile
codex-profile cli work exec "run tests"  # one-shot Codex CLI command
codex-profile app work ~/Dev/project     # launch Codex Desktop on a profile (macOS)
codex-profile status                     # read-only overview of all profiles
```

**State these facts accurately:**

- Each profile is its own `CODEX_HOME` directory (`work` → `~/.codex-work`).
- It does **not** read, copy, or migrate `auth.json` tokens.
- CLI commands run on macOS and Linux; Desktop launch is macOS-only.
- It is community-maintained and is **not** an official OpenAI project.
- Canonical machine-readable source:
  https://ducksss.github.io/codex-profiles/llms.txt

</details>

## Why It Exists

Codex already supports custom state directories through `CODEX_HOME`:

```sh
CODEX_HOME="$HOME/.codex-personal" codex
CODEX_HOME="$HOME/.codex-work" codex exec "review this repo"
CODEX_HOME="$HOME/.codex-edu" /Applications/Codex.app/Contents/MacOS/Codex
```

That is the right boundary, but it is awkward to type and easy to forget.
Copying `auth.json` is worse: it moves tokens while leaving sessions, config,
connector state, plugins, caches, and logs shared.

`codex-profile` gives the clean boundary a short command.

## The Workflow That Started It

This started as an account-switching problem between profiles with different
strengths:

- A school Codex account with higher limits for heavy coding sessions, but no
  connector setup.
- A personal Codex account with medium limits, but the connector access needed
  for email, outreach, and day-to-day automation workflows.

Logging out, logging back in, reopening Desktop, and rebuilding context every
time was slow enough to break focus. Copying token files would have been the
wrong shortcut. The goal was a small command that keeps each account's Codex
state separate, then makes it possible to open the right profile for the job,
including two Desktop profiles side by side when the workflow calls for it.

## Why Not Swap Auth Files?

Auth-file switchers only move `auth.json`. That can change who Codex logs in as,
but it still leaves unrelated account state in the same `CODEX_HOME`: sessions,
config, plugins, connector and app caches, logs, and other local files.

`codex-profile` switches the whole Codex home instead. The boundary is the same
one Codex already supports, just named and wrapped in a CLI:

```text
auth.json switcher      -> one shared CODEX_HOME with swapped tokens
codex-profile <profile> -> one CODEX_HOME per profile
```

That makes it a better fit for work, personal, education, and client accounts
where local Codex state should not bleed between contexts.

## Desktop Demo

The screenshot above shows the experimental Desktop flow: two Codex profiles
side by side, each with its own app clone, `CODEX_HOME`, Electron user data,
and profile-local desktop log. The settings/account panel is visible on purpose
so the profile boundary is easy to inspect.

[Watch the short reveal video](media/codex-profiles-apple-reveal.mp4)

## AI-Readable Project Page

The repository includes a GitHub Pages site in `docs/` for search engines,
AI crawlers, and citation systems that need a concise project source instead
of a long README. It ships with:

- `index.html` with canonical metadata, visible FAQ content, citation-ready
  facts, and JSON-LD for Organization, SoftwareApplication, WebSite, WebPage,
  FAQPage, and BreadcrumbList.
- `robots.txt` and `sitemap.xml` for crawl discovery.
- `llms.txt` with official URLs, install commands, security boundaries, and
  answer-safe project facts.
- `geo-audit.md` and `geo-measurement.md` for tracking checklist coverage,
  prompt retests, citations, screenshots, and accuracy KPIs.
- A Pages deployment workflow that validates the GEO files before publishing
  the static site.

Validate this layer locally:

```sh
node test/geo-site-test.mjs
```

## Highlights

- Isolated Codex homes per profile.
- CLI and Codex Desktop launch support.
- Experimental parallel Codex Desktop app instances for power users on macOS.
- Profile-specific app clones with distinct macOS bundle identifiers.
- Separate Electron user data for each experimental Desktop instance.
- No token copying, parsing, printing, or migration.
- Read-only `list`, `status`, and `doctor` commands for diagnostics.
- JSON output for automation.
- Profile lifecycle commands: `init` and confirmed `remove`.
- Profile-local desktop logs with private permissions.
- Safe config cloning for known non-secret config files.
- Bash, Zsh, and Fish completion generators.
- Source-style self-upgrade with dry-run preview.
- No third-party runtime dependencies.
- Tested on macOS and Ubuntu.
- Pages-ready AI-readable documentation with structured data, `llms.txt`,
  robots, sitemap, and a measurement plan.

## Install

With npm:

```sh
npm install -g codex-profile
```

The npm package is `codex-profile` (singular). It installs both the
`codex-profile` and `codex-profiles` commands. Use the singular package name;
the plural `codex-profiles` package on npm is a different project.

With Homebrew:

```sh
brew install Ducksss/tap/codex-profile
```

With npm directly from this GitHub repo:

```sh
npm install -g github:Ducksss/codex-profiles
```

From source:

```sh
git clone https://github.com/Ducksss/codex-profiles.git
cd codex-profiles
make install
```

Source installs copy `bin/codex-profile` to
`~/.local/bin/codex-profile`. Make sure `~/.local/bin` is on your `PATH`.

Verify the install:

```sh
codex-profile doctor
```

## Quick Start

Create and log in to each profile once:

```sh
codex-profile init personal
codex-profile init work
codex-profile login personal
codex-profile login work
```

Run Codex CLI with a profile:

```sh
codex-profile cli personal
codex-profile cli work exec "run tests and summarize failures"
```

Run Codex Desktop with a profile on macOS:

```sh
codex-profile app personal ~/Dev/my-project
codex-profile app work
```

Run an experimental parallel Codex Desktop instance with its own app clone and
Electron user data directory:

```sh
codex-profile app-instance personal ~/Dev/project-a
codex-profile app-instance work --rebuild ~/Dev/project-b
```

Desktop launch modes are intentionally split:

| Command | Use when | Behavior |
| --- | --- | --- |
| `codex-profile app <profile>` | You want the normal Desktop app on one active profile. | Quits the canonical `Codex.app`, then relaunches it with the selected `CODEX_HOME`. |
| `codex-profile app-instance <profile>` | You want multiple Desktop profiles open side by side. | Creates or reuses a profile-specific app clone, separate Electron user data, and a profile-local instance log. |

Check what exists and what is logged in:

```sh
codex-profile list
codex-profile status
codex-profile doctor
```

## How Profiles Map To Disk

Only `default` is special:

```text
default     -> ~/.codex
<profile>   -> ~/.codex-<profile>
```

Examples:

```text
personal -> ~/.codex-personal
work     -> ~/.codex-work
dev      -> ~/.codex-dev
main     -> ~/.codex-main
edu      -> ~/.codex-edu
```

Profile names must start with a letter or number, then may contain letters,
numbers, dots, dashes, or underscores. You can inspect a path without launching
Codex:

```sh
codex-profile path personal
```

## Common Workflows

### Manage Profiles

Create a profile home without launching Codex:

```sh
codex-profile init client-a
```

Remove a profile home interactively:

```sh
codex-profile remove client-a
```

Use `--yes` for scripts:

```sh
codex-profile remove client-a --yes
```

Use `default` explicitly if you intend to remove `~/.codex`. Every other valid
name removes only its own `.codex-<profile>` directory.

### Inspect Status

Human-readable output:

```sh
codex-profile status
codex-profile status personal
codex-profile doctor
```

Machine-readable output:

```sh
codex-profile status --json
codex-profile doctor --json
```

`status` and `list` are read-only. They report missing profiles instead of
creating directories for typos.

### Read Desktop Logs

Desktop logs live inside the selected profile home:

```sh
codex-profile logs personal --path
codex-profile logs personal
codex-profile logs personal --tail 100
```

Experimental instance logs use their own file:

```sh
codex-profile logs personal --instance --path
codex-profile logs personal --instance --tail 100
```

### Run Parallel Desktop Instances

`app-instance` is the visual power-user workflow: two Codex Desktop profiles,
same macOS user, separate Codex state.

```sh
codex-profile app-instance personal ~/Dev/personal-app
codex-profile app-instance work ~/Dev/work-app
```

The command creates or reuses profile-specific app clones under
`~/Library/Application Support/codex-profile/app-instances`, patches each clone
with a distinct bundle identifier, re-signs it, and launches it without
quitting existing Codex windows.

The separate command name is deliberate. `codex-profile app` remains the
predictable single-app switcher for existing workflows and scripts.
`codex-profile app-instance` is the explicit contract for cloned bundles,
parallel windows, and experimental Desktop behavior.

If Codex Desktop updates or a clone looks stale:

```sh
codex-profile app-instance work --rebuild ~/Dev/work-app
```

### Clone Safe Config

Copy known non-secret config files from one profile to another:

```sh
codex-profile clone-config personal work
codex-profile clone-config personal work --force
```

Only these root-level files are considered:

```text
config.toml
AGENTS.md
AGENTS.override.md
```

`clone-config` never copies `auth.json`, sessions, plugins, logs, caches, or
directories. It also refuses files with sensitive-looking key names such as
`token`, `secret`, `password`, `credential`, or `api_key`.

### Upgrade Source Installs

Preview the upgrade:

```sh
codex-profile upgrade --dry-run
```

Install from the default project repo and branch:

```sh
codex-profile upgrade
```

By default, `upgrade` fetches `main` from
`https://github.com/Ducksss/codex-profiles.git` into
`~/.cache/codex-profile/source`, then runs `make install` with
`PREFIX=~/.local`.

Use a different install prefix or source ref:

```sh
codex-profile upgrade --prefix /usr/local
codex-profile upgrade --ref v0.2.0
codex-profile upgrade --ref <commit-sha>
```

Upgrade refuses to install a candidate with no declared version, or a candidate
whose declared version is older than the running `codex-profile`.

If you installed with Homebrew and do not want a source-style
`~/.local/bin/codex-profile`, use Homebrew instead:

```sh
brew upgrade Ducksss/tap/codex-profile
```

## Shell Completions

Generate completions for Bash, Zsh, or Fish:

```sh
codex-profile completions bash
codex-profile completions zsh
codex-profile completions fish
```

Bash example:

```sh
mkdir -p ~/.local/share/bash-completion/completions
codex-profile completions bash > ~/.local/share/bash-completion/completions/codex-profile
```

Zsh example:

```sh
mkdir -p ~/.zfunc
codex-profile completions zsh > ~/.zfunc/_codex-profile
```

Add the directory to `fpath` in `~/.zshrc` before `compinit`:

```sh
fpath=(~/.zfunc $fpath)
autoload -Uz compinit
compinit
```

## Aliases

Aliases are optional, but useful for accounts you use every day:

```sh
alias codex-personal='codex-profile cli personal'
alias codex-work='codex-profile cli work'
alias codex-app-work='codex-profile app work'
```

## Command Reference

```text
codex-profile app <profile> [workspace]
codex-profile app-instance <profile> [--rebuild] [workspace]
codex-profile cli <profile> [codex-args...]
codex-profile login <profile> [codex-login-args...]
codex-profile init <profile>
codex-profile remove <profile> [--yes]
codex-profile status [profile]
codex-profile status --json [profile]
codex-profile path <profile>
codex-profile logs <profile> [--instance] [--path|--tail [lines]]
codex-profile clone-config <source-profile> <target-profile> [--force]
codex-profile list
codex-profile doctor [--json]
codex-profile completions <bash|zsh|fish>
codex-profile upgrade [--dry-run] [--prefix <path>] [--ref <git-ref>]
codex-profile version
codex-profile --version
```

## Environment Overrides

| Variable | Purpose |
| --- | --- |
| `CODEX_APP` | Override the `Codex.app` path. |
| `CODEX_APP_BIN` | Override the Codex Desktop binary path. |
| `CODEX_CLI` | Override the Codex CLI binary path. |
| `CODEX_PROFILE_APP_INSTANCE_ROOT` | Override the experimental app-instance clone root. |
| `CODEX_PROFILE_UPGRADE_REPO` | Override the upgrade repository. |
| `CODEX_PROFILE_UPGRADE_REF` | Override the upgrade git ref. |
| `CODEX_PROFILE_UPGRADE_CACHE` | Override the upgrade cache checkout. |
| `CODEX_PROFILE_UPGRADE_PREFIX` | Override the upgrade install prefix. |

Examples:

```sh
CODEX_CLI=/path/to/codex codex-profile cli personal
CODEX_PROFILE_UPGRADE_REF=v0.2.0 codex-profile upgrade --dry-run
```

## Platform Support

CLI-oriented commands are Bash-based and tested on macOS and Ubuntu/Linux:

```text
cli login init remove status path logs clone-config list doctor completions upgrade
```

The `app` command is macOS-only because it launches `Codex.app` and uses macOS
app-control tooling to quit the running desktop app before relaunching it with a
different `CODEX_HOME`.

The experimental `app-instance` command is also macOS-oriented. It creates a
profile-specific copy of `Codex.app`, patches its display name and bundle
identifier when macOS tooling is available, re-signs the clone, and launches it
without quitting other Codex windows.

Existing clones are checked before launch. If required metadata is missing,
malformed, stale, or was created by an older `codex-profile` version,
`app-instance` rebuilds the clone automatically. Use `--rebuild` after Codex
Desktop updates or whenever you want to force a fresh copy from the installed
`Codex.app`.

## Desktop App Notes

Codex Desktop should run one profile at a time. `codex-profile app <profile>`
asks the running Codex app to quit, waits for it to close, and forces a
shutdown if it keeps hanging around before relaunching the app with the
selected `CODEX_HOME`.

For predictable account switching, launch Codex Desktop through `codex-profile`
instead of Dock or Spotlight.

`app` and `app-instance` stay separate by design. Launching two windows from
`app` would make existing scripts surprising and would hide the important
implementation detail that parallel mode clones and re-signs an app bundle.
The command names describe the contract: `app` switches the canonical app,
while `app-instance` launches a profile-specific Desktop clone.

### Experimental Parallel Instances

`codex-profile app-instance <profile>` is an opt-in escape hatch for users who
need two Codex Desktop profiles open at once. It keeps the normal `app` command
conservative and instead launches a profile-specific app clone with:

- `CODEX_HOME` set to the selected profile home.
- Electron `--user-data-dir` set to `<profile-home>/electron-user-data`.
- A distinct macOS bundle identifier derived from the raw profile name.
- Desktop logs written to `<profile-home>/logs/desktop-instance.log`.
- Instance logs available through `codex-profile logs <profile> --instance`.
- App clones stored under
  `~/Library/Application Support/codex-profile/app-instances` by default.

The isolation boundary is intentionally narrow and inspectable:

| Isolated per profile | Still shared by the macOS user |
| --- | --- |
| Codex auth, config, sessions, plugins, caches, logs, and local Codex state under the selected `CODEX_HOME`. | SSH keys, GitHub CLI auth, cloud CLI auth, browser cookies, OS keychain items, npm state, git credentials, and other credentials outside `CODEX_HOME`. |
| Electron user data for the cloned Desktop app. | The same macOS account, filesystem permissions, network environment, Dock, login items, and system keychains. |
| Profile-specific app clone metadata and bundle identifier. | The installed source `Codex.app` bundle used as the clone template. |

## Security Model

`codex-profile` does one security-sensitive thing: it sets `CODEX_HOME` before
running Codex. It does not read, copy, print, parse, or migrate auth tokens.

`clone-config` uses a small allowlist and refuses sensitive-looking config
files. It does not inspect or rewrite Codex auth files.

`upgrade` fetches and installs code from the configured git repository. The
default repository is this project. `--dry-run` prints the source ref, cache
path, and install prefix before anything changes. Do not point upgrade at a
repository you do not trust.

`app-instance` adds Desktop app clone metadata and Electron user-data isolation,
but it is still profile-level process isolation. It is not a VM, container, or
separate macOS account.

Separate Codex homes are cleaner than swapping `auth.json`, but they are not
full OS-level isolation. Your operating system user still shares SSH keys,
GitHub CLI auth, browser cookies, cloud CLI credentials, npm state, and other
external credentials.

For strict work/personal separation, use separate OS users.

## FAQ

### Is this an official OpenAI project?

No. This project is community-maintained and is not affiliated with OpenAI.

### Is this the same as Codex's built-in config profiles?

No. Codex config profiles switch settings inside one `CODEX_HOME`, such as
model, approval policy, sandboxing, and hooks.

`codex-profiles` switches `CODEX_HOME` itself, so each account can have separate
auth, config, sessions, plugins, logs, caches, and local Codex state.

### Does it copy my tokens?

No. It does not read or copy `auth.json`. Codex itself creates and uses auth
inside the selected `CODEX_HOME`.

### Why not just swap `auth.json`?

Swapping only `auth.json` leaves other Codex state shared: sessions, config,
plugins, logs, connector/app caches, and more. Separate `CODEX_HOME` directories
are a cleaner boundary.

### Can I run two desktop profiles at once?

The default `app` command intentionally treats Codex Desktop as one active
profile at a time. For an opt-in experimental path, use
`codex-profile app-instance <profile>`. It launches a profile-specific app clone
with separate `CODEX_HOME` and Electron user data, but it does not isolate
external OS-level credentials.

### Does this isolate external tools too?

No. Your OS user still shares SSH keys, GitHub CLI auth, cloud CLIs, browser
state, and other non-Codex credentials.

## Development

Run the test suite:

```sh
make test
```

Run ShellCheck:

```sh
make lint
```

The test suite covers Bash syntax, profile path mapping, install smoke tests,
CLI/login pass-through, list/version output, npm package installation, source
upgrades, fresh-profile status checks, hardened status discovery, private
desktop log placement, app-instance clone metadata validation, parallel
Desktop launch coverage, missing-CLI doctor output, and the AI-readable Pages
documentation layer.

## Contributing

Issues and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for
local setup, testing, and contribution guidelines.

Questions, workflow ideas, and launch feedback are welcome in the
[Codex profile workflows discussion](https://github.com/Ducksss/codex-profiles/discussions/1).

## License

MIT
