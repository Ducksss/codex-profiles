# Security Policy

## Supported versions

Security fixes are made on `main` and included in the next tagged release.
Use the newest release when relying on separate local state.

## Reporting a vulnerability

Do not open a public issue for a vulnerability that could expose credentials,
tokens, cookies, private account data, or cross-profile state.

Use GitHub private vulnerability reporting when available, or contact the
maintainer through the GitHub profile linked from this repository. Include a
clear description, reproducible steps using test accounts, expected impact,
and a suggested fix if you have one.

Never include real `auth.json` contents, access or refresh tokens, OAuth codes,
cookies, connector credentials, private logs, or account identifiers.

## Local-state boundaries

`codex-profiles` selects two related but different kinds of local state:

1. Every profile selects a `CODEX_HOME`: `default` maps to `~/.codex`; any
   other valid name maps to `~/.codex-<name>`. Codex CLI, login, shell
   activation, and the desktop app-server use that directory.
2. On macOS, named `app` launches create named ChatGPT windows with separate
   local state by selecting `~/.codex-<name>/electron-user-data`. This local
   Electron directory applies to the whole launched window, including Chat,
   Work, and Codex modes. `app default` deliberately omits that override and
   preserves the stock ChatGPT Desktop session.

Local-state separation is not an account, OS, or server-side boundary.

The launcher uses the original signed ChatGPT (or legacy Codex) application.
It does not clone, patch, re-sign, replace, quit, or kill the installed app.
Compatibility spellings such as `--instance`, `--rebuild`, and `app-instance`
do not restore the old clone behavior.

Desktop launch refuses an inherited `CODEX_ACCESS_TOKEN`. This prevents a
shell access token from silently overriding the authentication used by the
launched window. Unset it before `app`; Codex-only `cli` and `login` commands
remain available for explicit access-token workflows. Provider/API credentials
are shared shell or operating-system state outside the local state selected by
this wrapper.

## What the project does not verify

The tool does not read, copy, print, parse, upload, compare, or migrate token
contents. In particular, it does not inspect an account identifier to prove
that a Codex CLI login and a ChatGPT Desktop window use the same account.
Those sessions can be authenticated independently; verify the visible account
in each surface when equality matters.

The selected directories are not a complete description of ChatGPT or Codex
storage. OpenAI or macOS may store some information in the system keychain or
other locations. Server-side workspaces, policies, histories, memories,
connectors, plans, limits, and cloud tasks are controlled by the signed-in
account and OpenAI—not by `CODEX_HOME` or Electron `--user-data-dir`.

## Shared operating-system state

Profiles still run as the same operating-system user. They share filesystem
permissions, processes, network configuration, keychains, SSH keys, GitHub and
cloud CLI credentials, git credential helpers, npm state, and credentials used
by tools that Codex launches. A malicious process running as the same user may
be able to read another profile's files despite private directory permissions.

Use separate operating-system users or separately managed devices for strict,
regulated, privileged, or adversarial separation.

## Configuration copying

`clone-config` considers only an allowlist of root-level non-auth files. It
never copies `auth.json`, sessions, plugins, logs, caches, Electron data, or
directories, and it refuses sensitive-looking keys. The heuristic is a safety
guard, not a proof that arbitrary text is non-secret. Review source files
before copying them between trust domains.

## Configuration linking

`init <profile> --share-with <source-profile>` creates a real, mode-`700`
target directory and symlinks only existing paths from a fixed configuration
allowlist: `config.toml`, `AGENTS.md`, `AGENTS.override.md`,
`instructions.md`, `custom-instructions.md`, `rules/`, and `plugins/`. It
rejects symlinked source homes and every pre-existing target path.

The command never links or reads `auth.json`, sessions, logs, Electron data,
caches, skills, or connector/app state. Linked configuration is live and may
itself contain secrets or executable plugin behavior, so it is not a security
boundary between the linked profiles. Review the source before linking across
trust domains.

## Network activity

The wrapper itself performs network access only for these project-maintenance
features:

- `upgrade` fetches the configured source repository. A non-default repository
  can execute code during installation; use only sources you trust and inspect
  `upgrade --dry-run` first.
- Interactive terminal runs may make one anonymous HTTPS request to the npm
  registry at most once per day to compare versions. Scripts, pipes, CI, and
  JSON output do not perform this check. Disable it with
  `CODEX_PROFILE_NO_UPDATE_CHECK=1` or `DO_NOT_TRACK=1`.

Codex CLI and the ChatGPT app make their own network requests under OpenAI's
behavior and policies. Those requests are outside this wrapper's network
model.
