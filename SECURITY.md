# Security Policy

## Supported Versions

`codex-profiles` is a small script project. Security fixes are made on `main`
and included in the next tagged release.

## Reporting a Vulnerability

Please do not open a public issue for vulnerabilities that expose credentials,
tokens, or private account data.

Report privately through GitHub's private vulnerability reporting if available,
or contact the maintainer through the GitHub profile linked from this repository.

Include:

- A clear description of the issue.
- Steps to reproduce.
- Impact.
- A suggested fix, if you have one.

Do not include real `auth.json` contents, OpenAI tokens, GitHub tokens, OAuth
codes, connector credentials, or private logs.

## Project Security Boundaries

`codex-profiles` does not read or copy Codex auth tokens. It only sets
`CODEX_HOME` before launching Codex.

The experimental `app-instance` command also creates profile-specific Codex app
clones and launches them with separate Electron user data directories. That is
profile-level process isolation for Codex Desktop state, not OS-level
isolation.

It does not isolate non-Codex credentials such as SSH keys, GitHub CLI auth,
cloud CLI credentials, browser cookies, or OS keychain items. Use separate OS
users for stronger isolation.
