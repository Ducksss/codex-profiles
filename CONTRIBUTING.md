# Contributing

Thanks for helping improve `codex-profiles`.

## Local setup

```sh
git clone https://github.com/Ducksss/codex-profiles.git
cd codex-profiles
make test
```

Optional shell linting requires ShellCheck:

```sh
make lint
```

## Product contract

Changes must preserve the distinction between two scopes:

- `cli`, `login`, `env`, and `use` select Codex-local state through
  `CODEX_HOME`. They do not switch ChatGPT Desktop.
- `app default` preserves the stock ChatGPT session and uses `~/.codex`.
- A named `app <profile>` launch uses matching `CODEX_HOME` and Electron user
  data for the entire ChatGPT window across Chat, Work, and Codex.
- The tool does not inspect or claim equality between CLI and Desktop accounts.

The Desktop launcher must use the original signed application. Do not add app
cloning, bundle patching, ad-hoc signing, global app quitting, broad process
killing, token copying, or cookie migration.

## Development guidelines

- Keep the distributed CLI dependency-free: Bash plus standard macOS/POSIX
  tools only.
- Keep macOS-only behavior inside the Desktop launcher.
- Preserve `default -> ~/.codex` and `<name> -> ~/.codex-<name>`.
- Treat `--instance`, `--rebuild`, and `app-instance` as compatibility
  spellings, not distinct launch modes.
- Do not read, copy, print, upload, rewrite, compare, or migrate authentication
  tokens or account identifiers.
- Keep human and JSON output explicit about whether a fact concerns Codex-local
  state or a ChatGPT Desktop window.
- Add regression tests for every observable behavior change.
- Update CLI help, README, completions, `docs/llms.txt`, structured data, and
  `CHANGELOG.md` together when the public surface changes.
- Keep `bin/codex-profile`, npm/package-lock, docs, PKGBUILD, and `.SRCINFO`
  versions in sync. A release also requires a dated changelog section.

## Testing Desktop changes

Automated tests should use disposable fake app bundles and temporary homes.
They must assert exact arguments and environment without opening or modifying a
real installed app.

Before release, test the current signed ChatGPT app with non-sensitive accounts:

1. Confirm `app default` keeps the existing stock session.
2. Confirm a named profile persists across relaunches.
3. Confirm two different names can run concurrently without state crossover.
4. Confirm Chat, Work, and Codex remain in the same named window context.
5. Confirm CLI actions do not switch any open Desktop window.
6. Confirm the installed app bundle remains byte-for-byte untouched by the
   launcher.

Never publish screenshots, logs, account names, histories, or tokens from this
test without explicit sanitization.

## Pull requests

Before opening a pull request:

```sh
make test
make lint
```

If ShellCheck is unavailable, state that clearly. The pull request must include
what changed, why it changed, tests run, supported platforms, and any migration
or compatibility impact. Use the repository template and identify whether the
change affects Codex-local state, Desktop state, or both.

## Security

Do not paste real auth files, access tokens, OAuth codes, cookies, connector
credentials, private logs, or account identifiers into issues, discussions,
pull requests, or test fixtures. Follow [SECURITY.md](SECURITY.md) for private
vulnerability reporting.
