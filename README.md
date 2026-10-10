<a id="readme-top"></a>

<div align="center">
  <img src="https://github.com/Ducksss/codex-profiles/raw/refs/heads/main/macos/CodexProfilesMenu/Previews/app-icon.png" alt="Codex Profiles app icon" width="96" height="96">

  <h1>Codex Profiles</h1>

  <p>
    <strong>A native macOS menu bar app for your Codex profiles.</strong>
    <br />
    Open separate ChatGPT windows, check Codex quota and get back to your projects.
  </p>

  <p>
    <a href="#getting-started"><strong>Build the macOS app »</strong></a>
    &middot;
    <a href="https://github.com/Ducksss/codex-profiles/blob/main/macos/README.md">App guide</a>
    &middot;
    <a href="#command-line-usage">CLI</a>
  </p>

  <p>
    <a href="https://github.com/Ducksss/codex-profiles/actions/workflows/ci.yml"><img src="https://github.com/Ducksss/codex-profiles/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
    <a href="#prerequisites"><img src="https://img.shields.io/badge/macOS-13%2B-lightgrey.svg" alt="macOS 13 or newer"></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT licence"></a>
  </p>
</div>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://github.com/Ducksss/codex-profiles/raw/refs/heads/main/macos/CodexProfilesMenu/Previews/menu-dark.png">
    <img src="https://github.com/Ducksss/codex-profiles/raw/refs/heads/main/macos/CodexProfilesMenu/Previews/menu-light.png" width="440" alt="Codex Profiles menu bar with personal and work profiles, remaining Codex quota, reset times and pinned project shortcuts.">
  </picture>
  <br />
  <sub>Actual AppKit view with sample quota values. Light and dark appearance follow macOS.</sub>
</p>

<details>
<summary>Table of contents</summary>

- [About the project](#about-the-project)
- [Getting started](#getting-started)
- [Usage](#usage)
- [How separation works](#how-separation-works)
- [Command-line usage](#command-line-usage)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)
- [Acknowledgements](#acknowledgements)

</details>

## About the project

Keep personal, work and client profiles within reach. **Codex Profiles.app**
lets you open ChatGPT windows side by side or launch Codex in Terminal,
with a profile's quota and project shortcuts in the same menu.

| In the menu | What you can do |
| --- | --- |
| **Profiles** | Create a profile and open it in ChatGPT or Terminal, with no project folder required. |
| **Codex quota** | See remaining CLI limits, low-quota warnings and reset times for each profile. |
| **Projects** | Bind folders to profiles, pin favourites and find them with search or keyboard shortcuts. |

The app bundles the `codex-profile` CLI engine. Both use the same profiles
and project bindings. This is a community project, unaffiliated with OpenAI.

### Built with

**Swift and AppKit** for the native macOS interface, **Bash and standard
system tools** for profile operations. The app follows macOS appearance,
accent colours and accessibility preferences.

## Getting started

**Build from source for now.** A signed app download is planned. npm and
Homebrew install the [CLI](#command-line-usage) only.

### Prerequisites

- **macOS 13+**, on Apple silicon or Intel.
- **Xcode Command Line Tools** with Swift. Install with `xcode-select --install`.
- The official **ChatGPT desktop app** for ChatGPT windows. Terminal launches
  and quota readings need the official **Codex CLI**, installed separately or
  available inside ChatGPT.

### Installation

```sh
git clone https://github.com/Ducksss/codex-profiles.git
cd codex-profiles
make menu-app
open build/macos
```

Drag **Codex Profiles.app** to **Applications**, then open it. The app includes
this project's CLI, so no separate npm or Homebrew installation is needed.

Local builds are unsigned development builds. For a DMG, signing and
notarisation, see the [macOS build guide](https://github.com/Ducksss/codex-profiles/blob/main/macos/README.md#build-locally).

<a id="menu-bar-app-macos"></a>

## Usage

### Open your first profile

1. Click the menu bar icon. Existing profiles appear automatically.
2. Choose **New profile…** in the gear menu, or **Create profile…** if the list
   is empty. Give it a name such as `personal` or `work`.
3. Select **ChatGPT**, click **Open** beside the profile and sign in inside
   that window when prompted. Choose **Terminal** to start Codex CLI instead.

Different names can stay open side by side. Reopening a name keeps its local
data, and `default` opens your normal ChatGPT session. Enable **Open at Login**
in the gear menu to keep the app available after you log in.

### Check quota before opening a profile

**Codex left** shows remaining CLI quota. Low readings turn orange or red
and show their reset time. Hover for details or press **⌘R** to refresh.

For an unavailable reading, use **Sign in to Codex CLI…** in that profile's
actions menu, then refresh. Quota follows the profile's **CLI sign-in**.
ChatGPT can use a different account, and the app does not compare accounts.
A missing reading never prevents you from opening a profile. See the
[quota guide](https://github.com/Ducksss/codex-profiles/blob/main/macos/README.md#codex-usage-beside-each-profile)
for supported accounts and troubleshooting.

### Open a project with its profile

Choose **Add workspace…**, select a folder and assign a profile. Pin the
projects you use often, then search and click **Open** to return to them.
The row's actions menu lets you change the profile, repair a moved folder or
remove the shortcut. Bindings are local metadata and do not change project files.

<details>
<summary>Keyboard shortcuts and macOS controls</summary>

| Shortcut | Action |
| --- | --- |
| ↑ / ↓, then Return | Select and open a profile or project |
| ⌘1–9 | Open the corresponding visible row |
| ⌘K | Focus search |
| ⌘R | Refresh profiles, projects and quota |
| Escape | Clear search, then close the menu |

Opening the app again from Finder or Spotlight shows the menu. Terminal
actions may request macOS Automation permission on first use. The
[app guide](https://github.com/Ducksss/codex-profiles/blob/main/macos/README.md)
covers all controls and accessibility details.

</details>

### Raycast

The [Raycast](https://www.raycast.com) extension opens profiles and bound
projects in ChatGPT or Terminal and shows each profile's remaining Codex quota.
Like the menu bar app, it runs every action through `codex-profile`. It isn't
in the Raycast Store yet, so build it from a source checkout with Node.js. See
the [extension guide](raycast/README.md).

```sh
cd raycast && npm install && npm run dev
```

## How separation works

| Profile | Codex home | ChatGPT window |
| --- | --- | --- |
| `default` | `~/.codex` | Your normal Desktop session |
| `work` | `~/.codex-work` | Separate local state, including `electron-user-data/` in that home |
| Any other name | `~/.codex-<name>` | Its own local state, kept when reopened |

A named window's state covers **Chat, Work and Codex**. CLI commands such as
`cli`, `login`, `env` and `use` select Codex state only and do not switch an
open ChatGPT window. Profiles do not inherit from `default`.

The tool opens the original signed ChatGPT app and does not read or copy
authentication file contents or ChatGPT cookies. Desktop launch refuses a
non-empty `CODEX_ACCESS_TOKEN` override. **Local-state separation is not an
account, OS or server-side security boundary.** Use separate OS users for a
stronger boundary. Read the [security model](SECURITY.md) and
[configuration-sharing guide](USAGE.md#share-configuration-not-identity-or-runtime-state).

## Command-line usage

The same profiles work from the terminal on **macOS and Linux**. You need
Bash and the official Codex CLI, on `PATH` or discoverable inside ChatGPT.

### Quick start

```sh
npm install -g codex-profile
codex-profile setup work
codex-profile cli work
```

`setup` guides you through profile creation and offers sign-in, project
binding and shell integration. Optional extras default to no, and shell
startup changes are shown for approval first. For scripts, use `init`,
`login` and `cli` separately.

Install **`codex-profile`** (singular). It provides both `codex-profile` and
`codex-profiles` commands. The plural npm package is another project.

### Install

<details>
<summary>Homebrew, source, standalone and Nix</summary>

```sh
brew install Ducksss/tap/codex-profile
```

From a source checkout, run `make install`.

The pinned standalone and Nix commands below require the `v1.3.0` release
tag, which has not been published yet. Use npm, Homebrew or source until then.

```sh
curl -fsSL https://raw.githubusercontent.com/Ducksss/codex-profiles/v1.3.0/install.sh \
  | CODEX_PROFILE_VERSION=v1.3.0 sh
```

```sh
nix run github:Ducksss/codex-profiles/v1.3.0
nix profile install github:Ducksss/codex-profiles/v1.3.0
```

Check your installation with `codex-profile doctor`.

</details>

### Everyday workflows

<details>
<summary>Launch profiles and projects from the terminal</summary>

```sh
codex-profile cli work exec "review this repo"
codex-profile app work
codex-profile workspace bind . work
codex-profile run
codex-profile run --app
```

Run `codex-profile cli` without a name for the profile picker. `app work`
opens a named ChatGPT window on macOS. `run` uses the nearest project binding.

</details>

### Command reference

Run `codex-profile help` for all commands or `codex-profile help app` for
one command. `codex-profile status` reports Codex-local status only.

[Full manual and FAQ](USAGE.md) · [Shell integration](USAGE.md#activate-a-codex-home-in-the-current-shell) ·
[Completions](USAGE.md#shell-completions) · [Environment overrides](USAGE.md#environment-overrides)

For agent-led setup, use [agent.md](agent.md) or the
[machine-readable guide](https://ducksss.github.io/codex-profiles/llms.txt).

### Platform support

CLI commands work on macOS and Linux. `app` and `launcher create` require
macOS. Shell integration supports Bash, Zsh and Fish. `NO_COLOR=1` disables
terminal colours, and piped help is plain text.

## Roadmap

- [x] Native menu bar app with profile, quota and project controls.
- [x] Universal app and DMG builds with signing and notarisation support.
- [ ] Published signed and notarised macOS app download.

See the [changelog](CHANGELOG.md) and [open issues](https://github.com/Ducksss/codex-profiles/issues).

## Contributing

Start with the [contributor guide](https://github.com/Ducksss/codex-profiles/blob/main/CONTRIBUTING.md)
and [coding-agent instructions](https://github.com/Ducksss/codex-profiles/blob/main/AGENTS.md).
Before opening a pull request, run `make check` for syntax, behaviour,
packaging, native macOS tests and ShellCheck. Native builds are skipped
on hosts without macOS and Swift.

## License

[MIT](LICENSE).

## Contact

[Report a bug](https://github.com/Ducksss/codex-profiles/issues/new?template=bug_report.yml) ·
[Request a feature](https://github.com/Ducksss/codex-profiles/issues/new?template=feature_request.yml) ·
[Discuss a workflow](https://github.com/Ducksss/codex-profiles/discussions) ·
[Project site](https://ducksss.github.io/codex-profiles/)

For security reports, follow [SECURITY.md](SECURITY.md).

## Acknowledgements

[Best-README-Template](https://github.com/othneildrew/Best-README-Template)
for the structure, and [contributors](https://github.com/Ducksss/codex-profiles/graphs/contributors)
for improving the app and CLI.

<p align="right"><a href="#readme-top">Back to top ↑</a></p>
