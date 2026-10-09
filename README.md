# codex-profiles

**Named Codex homes. Separate ChatGPT windows.**

Use personal, work, and client accounts on one computer without signing out.
Each profile gets its own Codex CLI home and, on macOS, its own ChatGPT
window. Bind a project to the profile it uses, or switch from the menu bar.

[![CI](https://github.com/Ducksss/codex-profiles/actions/workflows/ci.yml/badge.svg)](https://github.com/Ducksss/codex-profiles/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/Ducksss/codex-profiles?sort=semver)](https://github.com/Ducksss/codex-profiles/releases)
[![npm](https://img.shields.io/npm/v/codex-profile.svg)](https://www.npmjs.com/package/codex-profile)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

[![Animated codex-profiles overview: personal, work, and client Codex homes, followed by separate named ChatGPT windows.](https://github.com/Ducksss/codex-profiles/raw/refs/heads/main/docs/launch-preview.gif)](https://github.com/Ducksss/codex-profiles/blob/main/docs/launch.mp4)

*10-second looping overview; desktop UI is illustrative.
[Watch the full 30-second video with sound](https://github.com/Ducksss/codex-profiles/blob/main/docs/launch.mp4).*

- **Choose a profile:** each name selects its own Codex home, login, and sessions.
- **Keep windows separate:** named macOS launches select local state for the whole ChatGPT window.
- **Remember your project:** bind a directory once, then launch its profile with `run`.
- **Switch from the menu bar:** a [native macOS app](#menu-bar-app-macos) shows each profile's remaining Codex quota and opens it in one click.

The CLI is a single Bash script with no runtime dependencies beyond standard
system tools. Community-maintained; not an official OpenAI project.

[Quick start](#quick-start) · [Workflows](#everyday-workflows) ·
[Menu-bar app](#menu-bar-app-macos) · [Manual](USAGE.md) ·
[Project site](https://ducksss.github.io/codex-profiles/)

## Quick start

You need Bash and OpenAI's Codex CLI, either on `PATH` or inside the installed
ChatGPT app. Opening ChatGPT windows also needs the ChatGPT desktop app on
macOS. Without npm, use [another installation method](#install).

```sh
npm install -g codex-profile
codex-profile setup work
codex-profile cli work
```

`setup work` creates the `work` profile and offers to sign in to the Codex
CLI; use the account you want for this profile. It then offers three optional
extras, each defaulting to no:

- a project binding;
- shell integration: a profile label in your prompt, completions, tab titles
  and completion notifications, shown for approval before your startup file
  changes (open a new shell to use it);
- a macOS launcher.

Setup needs an interactive terminal and can reuse an existing profile.

**Note:** the npm package is **`codex-profile`** (singular) and installs both
the `codex-profile` and `codex-profiles` commands. The plural npm package is a
different project.

For scripts or manual setup:

```sh
codex-profile init work
codex-profile login work
codex-profile cli work
```

Initialize a name before launching it. Commands refuse unknown profiles, so a
typo can't silently create another home.

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

Run `codex-profile cli` without a name to pick a profile: use the arrow keys
and Enter, type to filter, or enter a name or menu number. The picker
preselects the current project's bound profile, or your shell's current
profile when there is no binding, and marks both. In scripts, pass the name
explicitly. Each profile signs in independently.

For a profile label and completions in your current shell:

```sh
# For Bash, replace zsh with bash.
eval "$(codex-profile shell-init zsh --prompt --completions)"
codex-profile use work
```

Fish and persistent setup are covered in [shell integration](USAGE.md#activate-a-codex-home-in-the-current-shell).

To label terminal tabs and get a notification when a one-shot command finishes:

```sh
export CODEX_PROFILE_TERMINAL_TITLE=1 CODEX_PROFILE_NOTIFY=1
codex-profile cli work exec "run tests"
```

Titles show the profile and launch directory; notifications need a compatible
terminal. See [terminal feedback](USAGE.md#terminal-titles-and-completion-notifications).

### Let the project choose its profile

From your project directory, bind the initialized `work` profile:

```sh
codex-profile workspace bind . work
codex-profile run
codex-profile run exec "run tests and summarize failures"
```

The nearest bound parent directory wins, so subprojects can use different
profiles. Bindings are private local metadata; no project files change. In an
unbound directory, `run` in a terminal offers to pick a profile and bind it;
declining the binding still launches the profile. Explicitly launching a
profile other than the bound one warns by default. See
[workspace rules and strict mode](USAGE.md#bind-projects-to-profiles).

### Open a named ChatGPT window on macOS

Using the initialized `work` profile:

```sh
codex-profile app work
```

Sign in to ChatGPT in the named window when prompted. Desktop and CLI sign-in
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

## Menu-bar app (macOS)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://github.com/Ducksss/codex-profiles/raw/refs/heads/main/macos/CodexProfilesMenu/Previews/menu-dark.png">
  <img src="https://github.com/Ducksss/codex-profiles/raw/refs/heads/main/macos/CodexProfilesMenu/Previews/menu-light.png" width="400" alt="Codex Profiles menu-bar app: three profiles with remaining Codex quota meters, one low in orange and one critical in red with its reset time, followed by pinned and recent workspaces with Open buttons.">
</picture>

*The app's actual view, rendered with sample quota values.*

**Codex Profiles.app** keeps every profile one click away:

- **Open anything fast:** open a profile, or a project bound to one, in
  ChatGPT or Terminal. Search, filter, pin projects, or press ⌘1–9.
- **See quota before you switch:** each profile shows its remaining Codex CLI
  quota as meters that turn orange or red when low, with the reset time.
- **Set up without the terminal:** create profiles, sign in to the Codex CLI,
  and add, reassign or repair project bindings. No project folder is required.
- **Native on macOS:** it follows light/dark mode, accent colour, contrast,
  transparency and Reduce Motion. **Open at Login** keeps it in the menu bar.

Build it from a source checkout on macOS 13 or newer (building needs Swift),
then move it to Applications to keep it, especially before turning on Open at
Login:

```sh
make menu-app
open "build/macos/Codex Profiles.app"
```

- **Includes `codex-profile`:** the app carries its own copy of this tool and
  runs on Apple silicon and Intel, so you don't need to install
  codex-profiles separately.
- **Needs OpenAI's Codex CLI** for Terminal launches, CLI sign-in and quota
  readings, either on `PATH` or inside the ChatGPT app. ChatGPT launches need
  the ChatGPT desktop app.
- **Quota follows the CLI sign-in:** each reading belongs to that profile's
  Codex CLI account; its ChatGPT window may be signed in to a different one.
- **No signed download yet:** `make menu-dmg` builds an unsigned disk image.

The [macOS guide](macos/README.md) covers keyboard shortcuts, quota details,
and Developer ID signing.

## How separation works

| Selection | Local state used |
| --- | --- |
| `default` | `~/.codex`; `app default` preserves the stock ChatGPT Desktop session. |
| Any other name, such as `work` | `~/.codex-work`; `app work` also uses that home's `electron-user-data/`. |
| `cli`, `login`, `env`, `use` | Codex-only selection; these do not switch an open ChatGPT window. |

Profiles do not inherit from `default`. Explicit configuration sharing is
available through [`init --share-with`](USAGE.md#share-configuration-not-identity-or-runtime-state).
Profile names such as `work` are your labels, independent of ChatGPT's Work mode.

Codex's own `--profile` option selects configuration within one home; this
tool selects the home itself, including its sign-in and sessions. `status`
reports Codex-local status, not the account shown in a Desktop window.

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
curl -fsSL https://raw.githubusercontent.com/Ducksss/codex-profiles/v1.3.0/install.sh \
  | CODEX_PROFILE_VERSION=v1.3.0 sh
```

With Nix:

```sh
nix run github:Ducksss/codex-profiles/v1.3.0
nix profile install github:Ducksss/codex-profiles/v1.3.0
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

Run `codex-profile` for the welcome screen. In an interactive terminal it also
shows your profiles, this project's binding, your shell's current profile, the
workspace guard mode, and relevant launch commands. Run `codex-profile help`
for every command, or `codex-profile help app` for one command's options and
examples.

<details>
<summary>See the welcome screen</summary>

![Actual codex-profiles welcome screen: overlapping terminal windows, the Codex Profiles wordmark, and commands for setup, CLI, Desktop, and workspace binding.](docs/welcome.svg)

</details>

| Task | Command |
| --- | --- |
| Guided setup | `codex-profile setup work` |
| Choose a CLI profile | `codex-profile cli` |
| Choose a ChatGPT window (macOS) | `codex-profile app` |
| List profiles | `codex-profile list` |
| View profile homes, projects, and launchers | `codex-profile list --details` |
| Inspect Codex-local status | `codex-profile status` |
| Check your installation | `codex-profile doctor` |
| Launch this project's profile | `codex-profile run` |
| Find a profile's home | `codex-profile path work` |
| Print shell integration | `codex-profile shell-init <bash\|zsh\|fish> [--prompt] [--completions]` |
| Get help for a command | `codex-profile help app` |

[Full command syntax](USAGE.md#command-reference) ·
[Shell integration](USAGE.md#activate-a-codex-home-in-the-current-shell) ·
[Completions](USAGE.md#shell-completions) ·
[Environment overrides](USAGE.md#environment-overrides)

## Platform support

CLI commands work on macOS and Linux. `app` and `launcher create` require
macOS, and the menu-bar app requires macOS 13 or newer. Shell integration
supports Bash, Zsh, and Fish. Terminal artwork adapts to width and UTF-8
support; `NO_COLOR=1` disables colors, and piped help is plain text.

## Help and documentation

- [Full manual and FAQ](USAGE.md): advanced workflows, upgrades, and troubleshooting.
- [Work and personal CLI guide](https://github.com/Ducksss/codex-profiles/discussions/28).
- [Named ChatGPT windows guide](https://github.com/Ducksss/codex-profiles/discussions/29).
- [What stays separate and what remains shared](https://github.com/Ducksss/codex-profiles/discussions/30).
- [Report a bug](https://github.com/Ducksss/codex-profiles/issues) or [discuss a workflow](https://github.com/Ducksss/codex-profiles/discussions).
- [Agent setup instructions](agent.md) and [machine-readable summary](https://ducksss.github.io/codex-profiles/llms.txt).

## Contributing

See the [contributor guide](https://github.com/Ducksss/codex-profiles/blob/main/CONTRIBUTING.md)
and [coding-agent instructions](https://github.com/Ducksss/codex-profiles/blob/main/AGENTS.md).
The CLI has no build step; the macOS app builds with `make menu-app`. Run the
complete local gate before submitting changes:

```sh
make check
```

## License

[MIT](LICENSE)
