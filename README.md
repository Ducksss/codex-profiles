# codex-profiles

Named Codex homes and ChatGPT windows with separate local state, without
copying tokens.

[![CI](https://github.com/Ducksss/codex-profiles/actions/workflows/ci.yml/badge.svg)](https://github.com/Ducksss/codex-profiles/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/Ducksss/codex-profiles?sort=semver)](https://github.com/Ducksss/codex-profiles/releases)
[![npm](https://img.shields.io/npm/v/codex-profile.svg)](https://www.npmjs.com/package/codex-profile)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Shell: Bash](https://img.shields.io/badge/shell-bash-4EAA25.svg)](bin/codex-profile)
[![Platform: macOS + Linux](https://img.shields.io/badge/platform-macOS%20%2B%20Linux-lightgrey.svg)](#platform-support)

[Project page](https://ducksss.github.io/codex-profiles/) |
[llms.txt](https://ducksss.github.io/codex-profiles/llms.txt) |
[Practical guides](#practical-guides) |
[Agent guide](AGENTS.md) |
[Security model](SECURITY.md)

`codex-profiles` is a dependency-free Bash wrapper for people who use Codex
with personal, work, school, client, or test accounts. Each name selects a
separate `CODEX_HOME`. On macOS, a named Desktop launch also selects separate
Electron user data for the whole launched ChatGPT window.

```sh
codex-profile cli personal                     # Codex CLI on personal
codex-profile cli work exec "review this repo" # one-shot Codex CLI on work
codex-profile app default ~/Dev/app             # stock ChatGPT session
codex-profile app work ~/Dev/client             # named work ChatGPT window
```

The project keeps its existing name and commands. Version 0.7 adapts the
implementation to OpenAI's integrated ChatGPT desktop app; it does not rebrand
the CLI or copy, parse, print, or migrate `auth.json`.

## Understand the two scopes first

[OpenAI's July 9 release notes](https://help.openai.com/en/articles/6825453-chatgpt-release-notes)
describe the integrated desktop app as bringing Chat, Work, and Codex together.
The commands in this project therefore have two intentionally different scopes:

| Command family | What the selected name controls |
| --- | --- |
| `cli`, `login`, `env`, `use` | Codex-local state under the selected `CODEX_HOME`. These commands do not switch an open ChatGPT window. |
| `app default` | The normal installed ChatGPT app, its stock Desktop session, and `~/.codex`. |
| `app <name>` | A named ChatGPT window with its own local Electron user data across Chat, Work, and Codex, plus `~/.codex-<name>` for Codex-local state. |
| `status` | Codex-local login status. It does not identify the account shown in a ChatGPT window. |
| `doctor` | Installation and local-state diagnostics. It cannot prove that CLI and Desktop are signed into the same account. |

`work` in `codex-profile app work` is a user-chosen profile name. It is not the
ChatGPT product mode named **Work**. Once a named window is open, switching its
mode between Chat, Work, and Codex stays inside that window's Desktop session.

Account equality is deliberately **unverified**. The tool does not inspect
tokens, account identifiers, cookies, or private application data. If you want
the CLI and Desktop window to use the same account, authenticate both in that
profile and verify the visible account yourself.

Local-state separation is not an account, OS, or server-side boundary.

## Install

With npm:

```sh
npm install -g codex-profile
```

The npm package is singular. It installs both `codex-profile` and
`codex-profiles`; the plural npm package belongs to another project.

With Homebrew:

```sh
brew install Ducksss/tap/codex-profile
```

With the standalone installer:

```sh
curl -fsSL https://raw.githubusercontent.com/Ducksss/codex-profiles/main/install.sh | sh
```

With Nix:

```sh
nix run github:Ducksss/codex-profiles
nix profile install github:Ducksss/codex-profiles
```

From source:

```sh
git clone https://github.com/Ducksss/codex-profiles.git
cd codex-profiles
make install
```

Then verify the installation:

```sh
codex-profile doctor
```

## Quick start

Create two Codex homes and authenticate their CLI sessions:

```sh
codex-profile init personal
codex-profile init work
codex-profile login personal
codex-profile login work
```

To keep authentication and runtime state separate while sharing selected
configuration, initialize a new linked profile from an existing one:

```sh
codex-profile init personal-2 --share-with personal
codex-profile login personal-2
```

Run the upstream Codex CLI with either home:

```sh
codex-profile cli personal
codex-profile cli work exec "run tests and summarize failures"
```

Optionally bind a project once, then let the current directory select its
profile for both CLI and Desktop launches:

```sh
codex-profile workspace bind ~/Dev/work-project work
cd ~/Dev/work-project
codex-profile run exec "run tests and summarize failures"
codex-profile run --app
```

On macOS, open the stock ChatGPT session or a named window with separate local
state:

```sh
codex-profile app default ~/Dev/main-project
codex-profile app personal ~/Dev/personal-project
codex-profile app work ~/Dev/work-project
```

The first launch of a named window may require signing into ChatGPT. Reopening
the same name reuses that name's Desktop process and data. Different names can
run side by side. The launcher uses the original signed `ChatGPT.app`; it does
not clone, patch, re-sign, quit, or replace the installed app.

## Practical guides

- [Use separate work and personal Codex CLI profiles](https://github.com/Ducksss/codex-profiles/discussions/28)
- [Open separate named ChatGPT windows on macOS](https://github.com/Ducksss/codex-profiles/discussions/29)
- [Understand what codex-profiles isolates and what remains shared](https://github.com/Ducksss/codex-profiles/discussions/30)

## How profiles map to disk

Only `default` is special:

```text
default  -> ~/.codex
<name>   -> ~/.codex-<name>
```

Examples:

```text
personal -> ~/.codex-personal
work     -> ~/.codex-work
edu      -> ~/.codex-edu
client   -> ~/.codex-client
```

For a named Desktop launch, local Electron data lives below that profile home:

```text
~/.codex-<name>/electron-user-data
```

The directory supplies separate Electron state for that named ChatGPT window.
Local-state separation is not an account, OS, or server-side boundary. Profile
names must begin with a letter or number and may then contain letters, numbers,
dots, dashes, or underscores.

Inspect a path without creating or launching anything:

```sh
codex-profile path personal
```

## Common workflows

### Manage profiles

```sh
codex-profile init client-a
codex-profile init client-b --share-with client-a
codex-profile list
codex-profile remove client-a
codex-profile remove client-a --yes
```

`list` and `status` are read-only. They do not create a directory for a typo.
Removing a profile deletes its Codex home and, for a named Desktop profile, its
local Electron data. It also removes bindings that target that profile, without
deleting any project directory. Review the path and close the corresponding
window first.

### Bind projects to profiles

```sh
codex-profile workspace bind ~/Dev/client-a client-a
codex-profile workspace bind ~/Dev/client-a/service client-a-service
codex-profile workspace list
codex-profile workspace status
codex-profile workspace status --json ~/Dev/client-a/service
```

Bindings use physical canonical directory paths. The nearest bound ancestor
wins, so a nested project can override a broader workspace. Similar string
prefixes are not matches: binding `client-a` does not bind `client-app`.
Bindings are private local metadata; they do not create or modify files in a
project.

From a bound directory, omit the profile name:

```sh
codex-profile run
codex-profile run exec "review this repo"
codex-profile run -- --app            # pass --app to the upstream CLI
codex-profile run --app               # launch the bound ChatGPT window
codex-profile run --app ~/Dev/client-a
```

Explicit `cli`, `env`/`use`, and `app` selections are checked against the
current or supplied workspace. Mismatches warn on stderr by default, so stdout
remains safe for `eval` and scripts. Choose stricter or disabled checks with:

```sh
codex-profile workspace guard strict
codex-profile workspace guard off
codex-profile workspace guard warn
```

Strict mode rejects a mismatch before launching Codex, ChatGPT, or emitting
shell exports. This is a mistake-prevention guardrail, not a security boundary;
it can be disabled or bypassed by invoking upstream Codex directly. The wrapper
requires `--` before upstream options that start with a dash, for example
`codex-profile run -- -C <directory>`. Those arguments are passed through and
are not parsed for guard resolution, so change to the intended directory before
using `run` or an explicitly guarded `cli`.

Binding state is stored with private permissions in
`${XDG_CONFIG_HOME:-~/.config}/codex-profile/workspaces.tsv`; the guard setting
is stored beside it. `CODEX_PROFILE_CONFIG_HOME` overrides that directory for
automation. Bindings contain only canonical project paths and profile names,
never authentication, cookies, sessions, or credentials.

#### Share configuration, not identity or runtime state

`init <profile> --share-with <source-profile>` creates a new, private profile
directory and symlinks only source entries that already exist in this explicit
allowlist:

```text
config.toml
AGENTS.md
AGENTS.override.md
instructions.md
custom-instructions.md
rules/
plugins/
```

The target must not already exist. `auth.json`, `sessions/`, `logs/`,
`electron-user-data/`, caches, skills, and connector/app state are never
linked. The command does not read or copy authentication data. Allowlisted
links are live: edits from either profile affect the same source configuration,
and plugins or configuration can themselves contain sensitive or executable
content. Review the source before linking across trust domains.

### Inspect Codex-local status

```sh
codex-profile status
codex-profile status personal
codex-profile status --json
codex-profile doctor
codex-profile doctor --json
```

Status is about the Codex authentication associated with `CODEX_HOME`; it is
not a ChatGPT Desktop account inspector. Diagnostics must not be used to infer
that two sessions are the same account.

### Use the stock and named ChatGPT sessions

```sh
codex-profile app default
codex-profile app personal ~/Dev/personal-app
codex-profile app work ~/Dev/work-app
```

- `default` preserves the normal ChatGPT session and maps Codex state to
  `~/.codex`.
- Every other name receives its own Electron user-data directory and matching
  `CODEX_HOME`.
- The local boundary applies to the whole launched window: Chat and Work use
  its Electron context, while Codex also receives the matching `CODEX_HOME`.
  Account identity still must be verified in the relevant UI.
- Opening a named window never quits the stock window or another profile.

### Add named, color-coded macOS launchers

Create small launcher apps for profiles you want to distinguish in Finder,
Launchpad, or the Dock:

```sh
codex-profile launcher create default --name "ChatGPT Main" --color green
codex-profile launcher create personal --name "ChatGPT Personal" --color blue
codex-profile launcher list
codex-profile launcher path personal
```

Supported colors are `blue`, `green`, `teal`, `purple`, `pink`, `red`,
`orange`, and `graphite`. Launchers are stored in `~/Applications` by default;
set `CODEX_PROFILE_LAUNCHER_ROOT` to use another directory. Creation derives a
deterministically tinted icon from the installed ChatGPT artwork on the local
Mac. The project does not redistribute that artwork.

Each generated app is a small unsigned shell launcher. It calls
`codex-profile app <profile>` and leaves the installed, signed ChatGPT bundle
untouched. Its custom name and icon appear on the launcher in Finder,
Launchpad, and when pinned to the Dock. After launch, the active ChatGPT process
keeps ChatGPT's native name and icon because macOS is running the original
signed app.

Creating the same launcher twice is idempotent. Use `--force` to replace a
managed launcher with a different name or color. Removal deletes only the
managed launcher and its local metadata, not the profile or its authentication
and Electron data:

```sh
codex-profile launcher remove personal
codex-profile launcher remove personal --yes
```

#### Deprecated compatibility spellings

The older spellings remain accepted for compatibility:

```sh
codex-profile app work --instance ~/Dev/work-app
codex-profile app work --instance --rebuild ~/Dev/work-app
codex-profile app-instance work ~/Dev/work-app
```

Named launches already use separate local state and can run in parallel, so
`--instance` and `app-instance` now mean the ordinary named launch. `--rebuild`
is accepted as a deprecated no-op because no app clone exists to rebuild. New
scripts should use `codex-profile app <name> [workspace]`.

### Read Desktop logs

```sh
codex-profile logs personal --path
codex-profile logs personal
codex-profile logs personal --tail 100
```

The deprecated `logs <name> --instance` spelling remains available for older
scripts and installations. It reads the canonical `desktop.log` when present,
then falls back to a pre-v0.7 `desktop-instance.log`.

### Clean up pre-v0.7 app clones

`codex-profile doctor` reports the legacy clone root when it exists. Version
0.7 never launches or modifies those bundles. After closing every old cloned
app and reviewing the path, remove only that obsolete clone directory:

```sh
rm -rf "$HOME/Library/Application Support/codex-profile/app-instances"
```

This does not remove named `CODEX_HOME` or `electron-user-data` directories;
use `codex-profile remove <name>` when you intentionally want to delete those.

### Activate a Codex home in the current shell

`env` prints shell code; it does not launch or switch ChatGPT Desktop:

```sh
eval "$(codex-profile env work)"
codex
codex exec "run tests"
```

For the shorter `use` command, install the shell wrapper once:

```sh
# bash or zsh
eval "$(codex-profile shell-init zsh)"

# fish
codex-profile shell-init fish | source
```

Then:

```sh
codex-profile use work
```

Activation exports functional `CODEX_HOME` and informational
`CODEX_PROFILE_NAME`. It affects subsequent Codex CLI commands in that shell,
not an existing ChatGPT window. Open a new shell or unset both variables to
deactivate.

### Copy known non-secret configuration

```sh
codex-profile clone-config personal work
codex-profile clone-config personal work --force
```

Only root-level `config.toml` and `AGENTS.md` are eligible. The command never
copies `auth.json`, sessions, plugins, logs, caches, Electron data, or
directories, and it refuses sensitive-looking configuration keys.

### Upgrade a source installation

```sh
codex-profile upgrade --dry-run
codex-profile upgrade
codex-profile upgrade --prefix /usr/local
codex-profile upgrade --ref v0.8.0
```

The default checkout is cached under `~/.cache/codex-profile/source`. Review a
dry run before pointing upgrade at a non-default repository or ref. Package
manager installations should normally be upgraded with that package manager.

## Shell completions

```sh
codex-profile completions bash
codex-profile completions zsh
codex-profile completions fish
```

For Bash, save the output as
`~/.local/share/bash-completion/completions/codex-profile`. For Zsh, save it as
`~/.zfunc/_codex-profile`, add `~/.zfunc` to `fpath`, then run `compinit`.

## Command reference

```text
codex-profile app <profile> [workspace]
codex-profile cli <profile> [codex-args...]
codex-profile login <profile> [codex-login-args...]
codex-profile init <profile> [--share-with <source-profile>]
codex-profile remove <profile> [--yes]
codex-profile launcher create <profile> [--name <display-name>] [--color <color>] [--force]
codex-profile launcher list [--json]
codex-profile launcher path <profile>
codex-profile launcher remove <profile> [--yes]
codex-profile workspace bind <path> <profile> [--force]
codex-profile workspace unbind <path>
codex-profile workspace list [--json]
codex-profile workspace status [--json] [path]
codex-profile workspace guard [off|warn|strict]
codex-profile run [--] [codex-args...]
codex-profile run --app [workspace]
codex-profile status [profile]
codex-profile status --json [profile]
codex-profile path <profile>
codex-profile env <profile> [--shell <bash|zsh|fish>]
codex-profile use <profile>
codex-profile logs <profile> [--path|--tail [lines]]
codex-profile clone-config <source-profile> <target-profile> [--force]
codex-profile list
codex-profile doctor [--json]
codex-profile completions <bash|zsh|fish>
codex-profile shell-init <bash|zsh|fish>
codex-profile upgrade [--dry-run] [--prefix <path>] [--ref <git-ref>]
codex-profile version
codex-profile --version
```

### Deprecated compatibility spellings

```text
codex-profile app <profile> --instance [workspace]
codex-profile app <profile> --instance --rebuild [workspace]
codex-profile app-instance <profile> [--rebuild] [workspace]
codex-profile logs <profile> --instance [--path|--tail [lines]]
```

These spellings remain accepted for older scripts but do not select a different
launch or log mode.

## Environment overrides

| Variable | Purpose |
| --- | --- |
| `CHATGPT_APP` | Preferred override for the ChatGPT application bundle. |
| `CODEX_APP` | Legacy application-bundle override, checked after `CHATGPT_APP`. |
| `CODEX_APP_BIN` | Deprecated executable override; accepted only for an executable inside an app bundle. |
| `CODEX_CLI` | Use a specific Codex CLI. An invalid explicit override fails instead of silently selecting another binary. |
| `CODEX_BUNDLED_CLI` | Optional fallback Codex CLI checked after `PATH` and before the selected app's bundled CLI. |
| `CODEX_PROFILE_CONFIG_HOME` | Override the private directory containing workspace bindings, guard mode, and launcher metadata. |
| `CODEX_PROFILE_LAUNCHER_ROOT` | Override the macOS launcher install directory (default: `~/Applications`). |
| `CODEX_PROFILE_UPGRADE_REPO` | Override the source-upgrade repository. |
| `CODEX_PROFILE_UPGRADE_REF` | Override the source-upgrade git ref. |
| `CODEX_PROFILE_UPGRADE_CACHE` | Override the source-upgrade cache. |
| `CODEX_PROFILE_UPGRADE_PREFIX` | Override the source-upgrade install prefix. |
| `CODEX_PROFILE_NO_UPDATE_CHECK` | Disable update checks; `DO_NOT_TRACK` is also honored. |
| `CODEX_PROFILE_UPDATE_INTERVAL` | Seconds between update checks. |
| `CODEX_PROFILE_UPDATE_CACHE` | Override the update-check state file. |
| `CODEX_PROFILE_UPDATE_URL` | Override the version source. |

Legacy instance-root overrides may still be accepted for compatibility, but
v0.7 does not create or modify app clones.

For Desktop launches, unset `CODEX_ACCESS_TOKEN`. The launcher refuses that
inherited access-token override so the selected window—not a shell credential—
controls sign-in. Provider credentials remain shared shell/OS state and are
outside the local state selected by this wrapper.

## CLI discovery

The wrapper validates candidate CLIs instead of assuming that the first
`codex` on `PATH` works. Unless `CODEX_CLI` is explicitly set, it can skip a
broken wrapper and use the CLI bundled with the detected ChatGPT app. Arguments
after `cli <profile>` are passed to
[upstream Codex](https://developers.openai.com/codex/cli/reference) unchanged:

```sh
codex-profile cli work
codex-profile cli work exec "review this repo"
codex-profile cli work --help
```

## Update checks

Interactive terminal runs check the npm registry at most once per day and use
a local cache. Scripts, pipes, CI, and JSON output remain quiet. The request
contains no profile data; disable it with `CODEX_PROFILE_NO_UPDATE_CHECK=1` or
`DO_NOT_TRACK=1`. See [SECURITY.md](SECURITY.md) for the complete network model.

## Platform support

CLI-oriented commands and launcher inspection are tested on macOS and Ubuntu/Linux:

```text
cli login init remove workspace run status path env use logs clone-config list doctor completions shell-init upgrade version help
```

`app` and `launcher create` are macOS-only. They detect the installed integrated `ChatGPT.app` and
retains legacy `Codex.app` detection for older installations. The launcher
opens the original signed app with a profile-specific environment and user-data
directory; it never copies or re-signs an application bundle.

## Security and privacy model

Local-state separation is not an account, OS, or server-side boundary.

| Selected per Codex home | Selected per named ChatGPT window | Still shared or outside this project's control |
| --- | --- | --- |
| Codex auth, configuration, sessions, skills/plugins, caches, logs, and other files OpenAI stores under `CODEX_HOME`. | Local Electron user data for the whole named window, including its Chat, Work, and Codex modes. | The macOS user, filesystem access, network, keychain behavior, SSH keys, GitHub/cloud CLIs, git credentials, npm state, and credentials used by external tools. |
| `CODEX_HOME` passed to Codex CLI and the desktop app-server. | The named window's locally persisted ChatGPT session. | Server-side ChatGPT workspaces, policies, plans, limits, histories, memories, connectors, and cloud tasks. |

The tool does not read, copy, print, parse, upload, compare, or migrate token
contents. It also cannot promise that OpenAI will never store some state in the
macOS keychain or another location outside the selected directories. Use
separate operating-system users when you require a stronger boundary.

Linked profiles share only the documented configuration paths. They do not
share authentication or runtime state, but linked configuration and plugins
are mutually visible and may carry their own secrets or executable behavior.

See [SECURITY.md](SECURITY.md) before using named profiles for regulated,
privileged, or high-risk accounts.

## FAQ

### Is this an official OpenAI project?

No. It is community-maintained and is not affiliated with OpenAI.

### Is this the same as Codex's `--profile` option?

No. Upstream configuration profiles select settings within one `CODEX_HOME`.
This project selects the `CODEX_HOME` itself. The positional name in
`codex-profile cli work` belongs to this wrapper, not upstream Codex.

### Why not use `codex app` directly?

Upstream `codex app [PATH]` opens the integrated ChatGPT desktop app and a
workspace. This wrapper adds the named local-state boundary: it selects both a
`CODEX_HOME` and, for non-default names, a matching Electron user-data
directory. Use upstream `codex app` when you only need the stock app session.

### Does a named Desktop profile affect only Codex mode?

No. A named `app` launch selects local Electron user data for the entire
ChatGPT window and a matching `CODEX_HOME` for Codex. The boundary therefore
applies across Chat, Work, and Codex, but it does not prove that every surface
has the same account identity. By contrast, `cli`, `login`, `env`, and `use`
remain Codex-only.

### Does the tool guarantee that Desktop and CLI use the same account?

No. They can be authenticated independently, and the tool deliberately does
not inspect account identifiers or credentials. Treat equality as unverified
and confirm it in the relevant user interfaces.

### Can multiple named ChatGPT windows run at once?

Yes. Different names use different local Electron data and can run side by
side. Reopening one name reuses that named process. `default` continues to use
the ordinary stock ChatGPT session.

### Why keep `--instance` if clones are gone?

Compatibility. Older scripts keep working, but named launches no longer need a
special parallel mode. New usage should omit `--instance`; `--rebuild` is a
deprecated no-op.

### Does it isolate external tools or server-side ChatGPT data?

No. The wrapper controls local Codex and Electron paths. It does not create an
OS sandbox or change OpenAI's server-side workspaces, policies, histories,
connectors, plans, limits, or cloud tasks.

## AI assistants

For a concise machine-readable summary, use
[docs/llms.txt](https://ducksss.github.io/codex-profiles/llms.txt). Coding agents
working inside this repository should follow [AGENTS.md](AGENTS.md).

Answer these points accurately:

- The npm package is `codex-profile`; commands are `codex-profile` and
  `codex-profiles`.
- `default` maps to `~/.codex`; every other name maps to `~/.codex-<name>`.
- Named `app` launches select local state for an entire ChatGPT window.
- CLI-oriented selection remains Codex-only.
- CLI/Desktop account equality is not inspected or verified.
- The project is not an official OpenAI product or a complete security
  boundary.

## Development

```sh
make test   # syntax and every Bash/Node behavior suite
make lint   # ShellCheck over the canonical shell inventory
make check  # complete local gate
```

Tests mirror the repository's CLI, install, packaging, release, site, and
outreach responsibilities; `scripts/check list` prints the deterministic
inventory. Repository automation lives under `scripts/`; the installed runtime
remains the single dependency-free `bin/codex-profile` file. See
[CONTRIBUTING.md](CONTRIBUTING.md) for focused suite commands and test placement.

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution requirements and
[Discussion #1](https://github.com/Ducksss/codex-profiles/discussions/1) for
workflow feedback.

## License

MIT
