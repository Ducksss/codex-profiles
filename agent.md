# Install and set up codex-profiles

Use this file when a user asks an AI assistant to install or configure
`codex-profiles`. This is the public setup entry point. Repository maintenance
instructions are in `AGENTS.md`; project-internal outreach operations are under
`ops/outreach/` and are not part of installation.

## Goal

Install the `codex-profile` wrapper, verify its prerequisites, and create only
the profiles the user requests. Keep existing Codex and ChatGPT state intact.

`codex-profiles` is a community-maintained Bash wrapper, not an official OpenAI
project. It provides named Codex homes and named ChatGPT windows with separate
local state. It does not install Codex itself and it does not require the
repository's Node, Neon, release, test, or outreach tooling at runtime.

## 1. Inspect before changing anything

Run read-only checks first:

```sh
uname -s
command -v codex-profile || true
command -v codex || true
command -v brew || true
command -v npm || true
```

On macOS, also check for `/Applications/ChatGPT.app` only if the user wants
named Desktop windows. Do not open or inspect `auth.json`, cookies, sessions,
keychains, or other credentials.

If `codex-profile` is already installed, report its version and use the
installation's package manager for upgrades:

```sh
codex-profile version
codex-profile doctor
```

## 2. Install one way

Honor the user's requested package manager. Otherwise, prefer a package manager
already in use on the machine and execute only one of these methods.

Homebrew on macOS:

```sh
brew install Ducksss/tap/codex-profile
```

npm on macOS or Linux:

```sh
npm install -g codex-profile
```

The npm package name is singular. It installs both `codex-profile` and
`codex-profiles`; the plural npm package belongs to another project.

For the standalone, Nix, or source installation, use the current commands in
the [README](README.md#install). Do not clone the repository merely to install
the command when a supported package or standalone method is available.

The runtime needs Bash. CLI workflows also need a healthy upstream Codex CLI,
either on `PATH` or bundled with a detected ChatGPT app. If verification reports
that Codex is missing, explain that it is a separate OpenAI prerequisite and
ask before installing it. Follow the current
[official Codex CLI guide](https://learn.chatgpt.com/docs/codex/cli).

The ChatGPT desktop app is optional and is needed only for this project's
macOS `app` and `launcher create` workflows. If the user wants those workflows
and the app is missing, use the
[official ChatGPT desktop guide](https://learn.chatgpt.com/docs/app).

## 3. Verify the installation

```sh
codex-profile version
codex-profile doctor
```

Resolve a missing shell `PATH` entry or upstream Codex prerequisite before
creating profiles. Do not claim a healthy setup when `doctor` still reports a
required component as missing.

## 4. Create only requested profiles

Ask for profile names if the user did not provide them. `init` is the only
command that creates a profile:

```sh
codex-profile init personal
codex-profile init work
```

Authentication is interactive and belongs to the user:

```sh
codex-profile login personal
codex-profile login work
```

Do not copy authentication from another profile. When the user explicitly
wants shared non-secret configuration, use the built-in allowlist:

```sh
codex-profile init personal-2 --share-with personal
```

On macOS, after the requested profile exists:

```sh
codex-profile app default
codex-profile app personal
```

`app default` preserves the stock ChatGPT session. A named `app` launch selects
matching `CODEX_HOME` and Electron data for the whole ChatGPT window across
Chat, Work, and Codex.

## 5. Report the result

Tell the user:

- which installation method and version were used;
- which profiles were created, if any;
- whether `doctor` passed and what remains unresolved;
- whether an interactive Codex or ChatGPT sign-in is still required.

Never print credential contents. Never copy or link `auth.json`, `sessions/`,
`state_5.sqlite`, logs, cookies, or Electron data between profiles. Local-state
separation is not an account, OS, or server-side boundary.
