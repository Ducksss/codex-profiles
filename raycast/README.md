# Codex Profiles for Raycast

Open named [codex-profiles](https://github.com/Ducksss/codex-profiles)
profiles and the projects bound to them from Raycast, in ChatGPT or in
Terminal, and see how much Codex quota each profile has left.

Community-maintained; not affiliated with OpenAI.

## Commands

| Command | What it does | codex-profile commands used |
| --- | --- | --- |
| **Open Profile** | Lists initialized profiles. Return opens the profile's ChatGPT window; ⌘Return opens Codex CLI for it in Terminal. Also copies the profile's `CODEX_HOME` path, shows it in Finder, or starts Codex CLI sign-in. Shows each profile's lowest remaining quota when a reading is available. | `list`, `path <profile>`, `app <profile>`, `cli <profile>`, `login <profile>`, `usage --json` |
| **Open Workspace** | Lists workspace bindings, most used first, with a profile filter. Opens the folder with its bound profile in ChatGPT or Terminal. Missing folders and profiles say why and cannot open. | `workspace list --json`, `app <profile> <folder>`, `cli <profile>` |
| **Codex Usage** | Shows every quota window for every profile, such as `5h: 8% left · resets in 1h 12m`, with **Low** (25% or less) and **Critical** (10% or less) tags. Profiles that are not signed in offer **Sign in to Codex CLI**. | `usage --json`, `login <profile>` |

`default` opens the stock ChatGPT session. Any other name opens a separate
ChatGPT window with its own local state across Chat, Work and Codex.
Terminal launches start in the workspace folder, or in your home folder for a
profile on its own.

The extension never switches profiles or accounts by itself. It shows the
numbers; you choose what to open.

## Requirements

- macOS with [codex-profile](https://github.com/Ducksss/codex-profiles#install)
  installed and at least one profile created (`codex-profile setup work`).
- The ChatGPT desktop app for ChatGPT launches, and OpenAI's Codex CLI for
  Terminal launches, sign-in and quota readings.
- **Codex Usage**, and quota in **Open Profile**, need a codex-profile release
  that includes `codex-profile usage`. With an older release, Codex Usage
  explains how to update: `codex-profile upgrade` for source and standalone
  installs, `npm install -g codex-profile@latest` for npm, or
  `brew upgrade codex-profile` for Homebrew.

The first Terminal launch asks for permission to control Terminal. If you
decline, turn it on later in **System Settings › Privacy & Security ›
Automation**.

## Preferences

| Preference | Default |
| --- | --- |
| **codex-profile Path** | Empty: looks in `~/.local/bin`, `/opt/homebrew/bin`, `/usr/local/bin`, common npm, nvm, Volta, pnpm, Bun, asdf and mise locations, then asks your login shell (`command -v codex-profile`). Set a full path, such as `~/.local/bin/codex-profile`, to use a specific install. |

Raycast starts extensions with a minimal `PATH`, so the extension adds those
same locations to the `PATH` it gives codex-profile. That lets codex-profile
find `codex`; it can also use the Codex CLI inside the ChatGPT app.

## Quota readings

Readings come from `codex-profile usage --json`, which asks each profile's
Codex CLI for its rate limits. A reading belongs to that profile's **Codex
CLI** sign-in; its ChatGPT window may be signed in to a different account,
and nothing compares the two. Readings are shared by both commands and
reused for a minute, or until a reported limit resets; **Refresh** (⌘R) reads
again. A window whose reset time has passed reads *awaiting a fresh reading*
until you refresh.

## Safety

Every profile operation delegates to the `codex-profile` CLI with an argument
list; nothing goes through a shell. The extension never reads `~/.codex*`
files, `auth.json`, tokens or cookies, and it does not forward
`CODEX_ACCESS_TOKEN`, `CODEX_API_KEY` or `OPENAI_API_KEY` to the CLI.
Local-state separation is not an account, OS or server-side security
boundary; see the project's
[security model](https://github.com/Ducksss/codex-profiles/blob/main/SECURITY.md).

## Development

From a checkout of the codex-profiles repository, with Node.js 22.22.2 or newer:

```sh
cd raycast
npm install
npm run dev        # load the extension into Raycast
npm run lint       # Raycast's manifest, ESLint and Prettier checks
npm run typecheck  # TypeScript, including the tests
npm test           # pure-logic tests; no Raycast app needed
npm run build      # ray build -e dist
```

The tests run with Node's built-in test runner and TypeScript type stripping.
They cover usage parsing and wording, CLI discovery and `PATH`, profile-name
validation against `bin/codex-profile`, and Terminal command quoting.
