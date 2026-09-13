# codex-profiles

**Named Codex homes. Separate ChatGPT windows.**

Keep personal, work, and client Codex profiles organized. Open named ChatGPT
windows on macOS, and bind projects to the profile they use.

[![CI](https://github.com/Ducksss/codex-profiles/actions/workflows/ci.yml/badge.svg)](https://github.com/Ducksss/codex-profiles/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/Ducksss/codex-profiles?sort=semver)](https://github.com/Ducksss/codex-profiles/releases)
[![npm](https://img.shields.io/npm/v/codex-profile.svg)](https://www.npmjs.com/package/codex-profile)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

[Quick start](#quick-start) · [Workflows](#everyday-workflows) ·
[Manual](USAGE.md) · [Project site](https://ducksss.github.io/codex-profiles/)

![Actual codex-profiles welcome screen: overlapping terminal windows, the Codex Profiles wordmark, and commands for setup, CLI, Desktop, and workspace binding.](docs/welcome.svg)

*The CLI's welcome screen. Run `codex-profile` to see it in your terminal.*

- **Choose a profile:** each name selects its own Codex home, login, and sessions.
- **Keep windows separate:** named macOS launches select local state for the whole ChatGPT window.
- **Remember your project:** bind a directory once, then launch its profile with `run`.

A single Bash script with no runtime dependencies beyond standard system tools.
Community-maintained; not an official OpenAI project.

## Quick start

You need Bash and a working Codex CLI (on `PATH`, or discoverable from the
installed macOS app). Desktop launches also require the installed ChatGPT app.
The npm installation below requires npm; a standalone installer is available
under [other installation methods](#install).

```sh
npm install -g codex-profile
codex-profile setup work
codex-profile cli work
```

`setup work` creates the profile and offers Codex CLI login. Accept the login
prompt and authenticate with the account you want for this profile. Setup also
offers optional project binding and, on macOS, a launcher; both default to no.
It requires an interactive terminal and can reuse an existing profile.

The npm package is **`codex-profile`** (singular). It installs both
`codex-profile` and `codex-profiles`; the plural npm package is another project.

For scripts or manual setup:

```sh
codex-profile init work
codex-profile login work
codex-profile cli work
```

Initialize a name before launching it. Commands refuse unknown profiles so a
typo does not silently create another home.

### Let your agent set it up

Copy this prompt into your coding agent:

```text
Install and configure codex-profiles using this guide:
https://github.com/Ducksss/codex-profiles/blob/main/agent.md

Ask me which profile names I want. Guide me through signing in.
```

[Read the agent setup guide](agent.md).

## Everyday workflows

### Switch between personal and work

After setting up `work` above, add your personal profile:

```sh
codex-profile setup personal
codex-profile cli personal
codex-profile cli work exec "review this repo"
```

Run `codex-profile cli` without a name for an interactive picker. In scripts,
pass the name explicitly. Each profile authenticates independently.

To label terminal tabs and receive one-shot completion notifications, opt in:

```sh
export CODEX_PROFILE_TERMINAL_TITLE=1 CODEX_PROFILE_NOTIFY=1
codex-profile cli work exec "run tests"
```

Titles identify the profile and launch directory. Notifications require a
compatible terminal. [Terminal feedback details](USAGE.md#terminal-titles-and-completion-notifications).

### Let the project choose its profile

From your project directory, bind the initialized `work` profile:

```sh
codex-profile workspace bind . work
codex-profile run
codex-profile run exec "run tests and summarize failures"
```

The nearest bound parent directory wins, so subprojects can use different
profiles. Bindings are private local metadata; no project files are changed.
Explicitly launching a different profile warns by default.
[Workspace rules and strict mode](USAGE.md#bind-projects-to-profiles).

### Open a named ChatGPT window on macOS

Using the initialized `work` profile:

```sh
codex-profile app work
```

Sign into ChatGPT in the named window when prompted. Desktop and CLI sign-in
are separate; the tool does not verify that they use the same account.
Different names can run side by side, and reopening a name reuses its process
and local data. The selected local state covers **Chat, Work, and Codex**.

To open your normal stock session:

```sh
codex-profile init default
codex-profile app default
```

To open the profile bound to your current project:

```sh
codex-profile run --app
```

The original signed app stays untouched. For a named, colored shortcut in
Finder or the Dock, see [macOS launchers](USAGE.md#add-named-color-coded-macos-launchers).

## How separation works

| Selection | Local state used |
| --- | --- |
| `default` | `~/.codex`; `app default` preserves the stock ChatGPT Desktop session. |
| Any other name, such as `work` | `~/.codex-work`; `app work` also uses that home's `electron-user-data/`. |
| `cli`, `login`, `env`, `use` | Codex-only selection; these do not switch an open ChatGPT window. |

Profiles do not inherit from `default`. Explicit configuration sharing is
available through [`init --share-with`](USAGE.md#share-configuration-not-identity-or-runtime-state).
Profile names such as `work` are your labels, independent of ChatGPT's Work mode.

The tool never reads or copies authentication tokens or ChatGPT cookies.
**Local-state separation is not an account, OS, or server-side security
boundary.** OS credentials, external tools, and server-side policies remain
outside its control. Use separate OS users when you need a stronger boundary.
See the [security model](SECURITY.md) and [profile layout](USAGE.md#how-profiles-map-to-disk).

## Install

The npm command in [Quick start](#quick-start) is the shortest path for npm users.

<details>
<summary>Other installation methods: standalone, Homebrew, Nix, and source</summary>

With Homebrew:

```sh
brew install Ducksss/tap/codex-profile
```

With the standalone installer:

```sh
curl -fsSL https://raw.githubusercontent.com/Ducksss/codex-profiles/v1.0.0/install.sh \
  | CODEX_PROFILE_VERSION=v1.0.0 sh
```

With Nix:

```sh
nix run github:Ducksss/codex-profiles/v1.0.0
nix profile install github:Ducksss/codex-profiles/v1.0.0
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

</details>

## Command reference

Run `codex-profile` for the welcome screen or `codex-profile help` for all commands.

| Task | Command |
| --- | --- |
| Guided setup | `codex-profile setup work` |
| Choose a CLI profile | `codex-profile cli` |
| Choose a ChatGPT window (macOS) | `codex-profile app` |
| List profiles | `codex-profile list` |
| Inspect Codex-local status | `codex-profile status` |
| Check your installation | `codex-profile doctor` |
| Launch this project's profile | `codex-profile run` |
| Find a profile's home | `codex-profile path work` |

[Full command syntax](USAGE.md#command-reference) ·
[Shell integration](USAGE.md#activate-a-codex-home-in-the-current-shell) ·
[Completions](USAGE.md#shell-completions) ·
[Environment overrides](USAGE.md#environment-overrides)

## Platform support

CLI commands work on macOS and Linux. `app` and `launcher create` require macOS.
The CLI can use Bash, Zsh, or Fish shell integration. Terminal artwork adapts to
width and UTF-8 support; `NO_COLOR=1` disables colors, and piped help is plain text.

## Help and documentation

- [Full manual and FAQ](USAGE.md): advanced workflows, upgrades, and troubleshooting.
- [Work and personal CLI guide](https://github.com/Ducksss/codex-profiles/discussions/28).
- [Named ChatGPT windows guide](https://github.com/Ducksss/codex-profiles/discussions/29).
- [What stays separate and what remains shared](https://github.com/Ducksss/codex-profiles/discussions/30).
- [Report a bug](https://github.com/Ducksss/codex-profiles/issues) or [discuss a workflow](https://github.com/Ducksss/codex-profiles/discussions).
- [Agent setup instructions](agent.md) and [machine-readable summary](https://ducksss.github.io/codex-profiles/llms.txt).

Upstream Codex's `--profile` selects configuration within one home; this tool
selects the home itself. `status` reports Codex-local status, not the account
shown in a Desktop window. See the [FAQ](USAGE.md#faq) for more.

## Contributing

See the [contributor guide](https://github.com/Ducksss/codex-profiles/blob/main/CONTRIBUTING.md)
and [coding-agent instructions](https://github.com/Ducksss/codex-profiles/blob/main/AGENTS.md).
There is no build step. Run the complete local gate before submitting changes:

```sh
make check
```

## License

[MIT](LICENSE)
