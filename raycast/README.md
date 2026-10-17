# Codex Profiles for Raycast

Open named [codex-profiles](https://github.com/Ducksss/codex-profiles)
profiles and the projects bound to them from Raycast, in ChatGPT or in
Terminal, and see how much Codex quota each profile has left.

Community-maintained; not affiliated with OpenAI.

## Commands

### Open Profile

Lists initialized profiles. Return opens the profile's ChatGPT window;
⌘Return opens Codex CLI for it in Terminal. It also copies the profile's
`CODEX_HOME` path, shows it in Finder, or starts Codex CLI sign-in, and shows
each profile's lowest remaining quota when a reading is available.

Uses `list`, `path <profile>`, `app <profile>`, `cli <profile>`,
`login <profile>` and `usage --json`.

### Open Workspace

Lists workspace bindings, most used first, with a profile filter. Opens the
folder with its bound profile in ChatGPT or Terminal. Missing folders and
profiles say why and cannot open.

Uses `workspace list --json`, `app <profile> <folder>` and `cli <profile>`.

### Codex Usage

Shows every quota window for every profile, such as
`5h: 8% left · resets in 1h 12m`, with **Low** (25% or less), **Critical**
(10% or less) and **Limit reached** (0%) tags. Profiles that are not signed in
offer **Sign in to Codex CLI**. When a reading is unavailable, for example
for a profile that uses an API key, the row shows codex-profile's reason
instead.

Uses `usage --json` and `login <profile>`.

### Profiles and accounts

`default` opens the stock ChatGPT session. Any other name opens a separate
ChatGPT window with its own local state across Chat, Work and Codex.
Terminal launches start in the workspace folder, or in your home folder for a
profile on its own.

The extension never switches profiles or accounts by itself. It shows the
numbers; you choose what to open.

## Requirements

- macOS with [codex-profile](https://github.com/Ducksss/codex-profiles#install)
  installed, or the Codex Profiles menu bar app, which includes it, and at
  least one profile created (`codex-profile setup work`).
- The ChatGPT desktop app for ChatGPT launches, and OpenAI's Codex CLI for
  Terminal launches, sign-in and quota readings.
- **Codex Usage**, and quota in **Open Profile**, need a codex-profile release
  that includes `codex-profile usage`. With an older release, Codex Usage
  explains how to update: `codex-profile upgrade` for source and standalone
  installs, `npm install -g codex-profile@latest` for npm,
  `brew upgrade codex-profile` for Homebrew, or a newer app release for the
  copy inside the menu bar app.

The first Terminal launch asks for permission to control Terminal. If you
decline, turn it on later in **System Settings › Privacy & Security ›
Automation**.

## Preferences

**codex-profile Path** is empty by default. The extension then looks in
`~/.local/bin`, `/opt/homebrew/bin`, `/usr/local/bin` and common npm, nvm,
Volta, pnpm, Bun, asdf and mise locations, then in the menu bar app
(`/Applications/Codex Profiles.app` or `~/Applications/Codex Profiles.app`),
then asks your login shell (`command -v codex-profile`). To use a specific
install, set a full path that starts with `/` or `~/`, such as
`~/.local/bin/codex-profile`.

Raycast starts extensions with a minimal `PATH`, so the extension adds those
same locations to the `PATH` it gives codex-profile. That lets codex-profile
find `codex`; it can also use the Codex CLI inside the ChatGPT app.

## Quota readings

Readings come from `codex-profile usage --json`, which asks each profile's
Codex CLI for its rate limits. A reading belongs to that profile's **Codex
CLI** sign-in; its ChatGPT window may be signed in to a different account,
and nothing compares the two. Readings are shared by both commands and
reused for a minute, or until a reported limit resets; **Refresh** (⌘R) reads
again. A window whose reset time has passed reads _awaiting a fresh reading_
until you refresh.

## Safety

Background calls (profile and workspace lists, paths, quota and ChatGPT
launches) run
`codex-profile` directly with an argument list, never through a shell, and
without `CODEX_ACCESS_TOKEN`, `CODEX_API_KEY` or `OPENAI_API_KEY`. Terminal
launches ask Terminal to run `codex-profile cli` or `codex-profile login` in
a new window, in your own shell and its environment; profile names and
folder paths are single-quoted the way sh, bash, zsh and fish all read
literally, so they are never interpreted by the shell. When no install is found in the usual
locations, discovery runs your login shell with the fixed command
`command -v codex-profile`.

The extension never reads `~/.codex*` files, `auth.json`, tokens or cookies.
Local-state separation is not an account, OS or server-side security
boundary; see the project's
[security model](https://github.com/Ducksss/codex-profiles/blob/main/SECURITY.md).

## Development

From a checkout of the codex-profiles repository, with Node.js 22.22.2 or newer:

```sh
cd raycast
npm install
npm run dev        # load the extension into Raycast
npm run typecheck  # TypeScript, including the tests
npm test           # pure-logic tests; no Raycast app needed
npm run build      # ray build -e dist
npx prettier --check .
npm run lint       # Raycast's manifest, ESLint and Prettier checks
```

`npm run lint` fails until `author` in `package.json` is a real Raycast
username; the placeholder `ducksss` is not a registered Raycast user. Until
then, check code style with `npx eslint src test` and `npx prettier --check .`.

The tests run with Node's built-in test runner and TypeScript type stripping.
They cover usage parsing and wording, CLI discovery and `PATH`, profile-name
validation against `bin/codex-profile`, and Terminal command quoting.
