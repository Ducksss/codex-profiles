# Contributing

Thanks for helping improve `codex-profiles`.

## Local Setup

```sh
git clone https://github.com/Ducksss/codex-profiles.git
cd codex-profiles
make test
```

Optional linting:

```sh
make lint
```

`make lint` requires ShellCheck.

## Development Guidelines

- Keep the project dependency-free unless there is a strong reason not to.
- Keep profile behavior explicit and predictable.
- Do not add code that reads, copies, prints, uploads, or rewrites Codex auth
  tokens.
- Prefer portable Bash for CLI behavior.
- Keep macOS-only behavior isolated to the desktop app launcher path.
- Add or update tests for behavior changes.

## Pull Requests

Before opening a pull request:

```sh
make test
```

If you changed shell code and have ShellCheck installed:

```sh
make lint
```

In the PR description, include:

- What changed.
- Why it changed.
- How you tested it.
- Any platform-specific behavior.

## Security

Do not paste real `auth.json` contents, access tokens, OAuth codes, or connector
credentials into issues, discussions, pull requests, or logs.

If you find a security issue, follow [SECURITY.md](SECURITY.md).
