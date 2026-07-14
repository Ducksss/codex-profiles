# Contributing

Thanks for helping improve `codex-profiles`.

## Local setup

```sh
git clone https://github.com/Ducksss/codex-profiles.git
cd codex-profiles
make check
```

`make check` is the canonical local gate: it runs syntax validation, all Bash
and Node behavior suites, and ShellCheck from one deterministic file inventory.
If ShellCheck is unavailable, run `make test` and state the missing lint result
explicitly in the pull request.

## Product contract

Changes must preserve the distinction between two scopes:

- `cli`, `login`, `env`, and `use` select Codex-local state through
  `CODEX_HOME`. They do not switch ChatGPT Desktop.
- `app default` preserves the stock ChatGPT session and uses `~/.codex`.
- A named `app <profile>` launch uses matching `CODEX_HOME` and separate
  Electron state for that named ChatGPT window across Chat, Work, and Codex.
- The tool does not inspect or claim equality between CLI and Desktop accounts.
- Local-state separation is not an account, OS, or server-side boundary.

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
- Do not read, copy, print, parse, upload, compare, or migrate authentication
  tokens or ChatGPT cookies. Do not inspect or compare account identifiers.
- Keep human and JSON output explicit about whether a fact concerns Codex-local
  state or a ChatGPT Desktop window.
- Add regression tests for every observable behavior change.
- Update CLI help, README, completions, `docs/llms.txt`, structured data, and
  `CHANGELOG.md` together when the public surface changes.
- Keep `bin/codex-profile`, npm/package-lock, docs, PKGBUILD, and `.SRCINFO`
  versions in sync. A release also requires a dated changelog section.

## Repository automation and test placement

- Keep installed behavior in the single `bin/codex-profile` file. Repository
  automation belongs under `scripts/` and must not enter the npm package.
- `scripts/check` owns source and test discovery. Make, npm, CI, and release
  verification delegate to it rather than copying file lists.
- Put tests beside their responsibility: `test/cli`, `test/install`,
  `test/packaging`, `test/release`, `test/site`, or `test/outreach`.
- Put only reusable test infrastructure in `test/lib`; product expectations
  stay in the owning suite. Tests must be independently runnable and use
  disposable state.
- Keep GitHub workflow files focused on permissions, secrets, runner setup, and
  sequencing. Release behavior belongs in directly tested `scripts/release`
  commands.
- `scripts/aur/prepare.sh` and `scripts/aur/verify.sh` never publish. The AUR
  credential, reviewed commit, and push remain maintainer-owned steps in the
  [AUR runbook](packaging/aur/README.md).

Useful focused commands include:

```sh
bash test/cli/workspace-test.sh
bash test/release/npm-test.sh
node test/packaging/aur-test.mjs
node test/site/geo-test.mjs
scripts/check list
```

## Testing Desktop changes

Automated tests should use disposable fake app bundles and temporary homes.
They must assert exact arguments and environment without opening or modifying a
real installed app.

The following six-case matrix is required before every live release. Test the
current signed ChatGPT app with non-sensitive accounts:

1. Confirm `app default` keeps the existing stock session.
2. Confirm a named profile persists across relaunches.
3. Confirm two different names can run concurrently without state crossover.
4. Confirm Chat, Work, and Codex remain in the same named window context.
5. Confirm CLI actions do not switch any open Desktop window.
6. Confirm the installed app bundle remains byte-for-byte untouched by the
   launcher.

Never publish screenshots, logs, account names, histories, or tokens from this
test without explicit sanitization.

## Release rehearsal and attestation

Dispatch the `Release` workflow from the current `main` commit with the exact
tracked version. Its default `dry_run: true` path requires no Desktop
attestation and makes no tag, registry, release, tap, or Pages changes. The
always-run rehearsal invokes the same canonical `make check` gate used locally,
then requires a clean checkout with no unstaged, staged, or untracked artifacts.
This verification job has read-only repository permissions, and its checkout
does not persist a GitHub credential.

Only after the six cases above pass may a maintainer dispatch with
`dry_run: false`. The `desktop_smoke_attestation` value may contain exactly two
public app facts, in this form:

```text
ChatGPT version 1.2026.168; bundle ID com.openai.codex
```

Substitute the installed public values. The version must have two or three
dot-separated numeric components. The bundle ID must begin `com.openai.` and
use only alphanumeric segments separated by dots or hyphens. Leading or trailing
whitespace, newlines, and extra text are rejected. Do not add an account name or
identifier, email address, screenshot, token, cookie, history, log, private
path, or other account data. The workflow converts the validated value to a
single escaped summary line and rejects a missing or malformed attestation
before any live release step.

The separate live-only job receives the write permissions. Before its first
external mutation, it checks out the verified commit again, preflights the npm
token's owner identity and the tap token's reported GitHub account access, then
re-fetches the current `origin/main` tip and exact remote tag state immediately
before tagging. Stale verification outputs cannot authorize a release after
either has moved. These read-only identity checks cannot prove a granular
token's write scope: configure `NPM_TOKEN` for `codex-profile` publication and
use a dedicated fine-grained `TAP_TOKEN` limited to `Ducksss/homebrew-tap` with
Contents read/write. Do not reuse a broad personal or organization token; the
actual npm publish and tap push remain the authoritative write checks.

After publication, the workflow retries npm installation with bounded backoff
into a fresh prefix and checks `help` and `version` through both command aliases.
It then verifies the exact GitHub Release tag, downloads `install.sh` from that
immutable tag, and exercises its public `releases/latest` path in fresh prefixes
until both aliases report the exact version and the plural alias is the expected
relative symlink. The workflow also requires a newly created Pages run from the
tag to succeed and polls the public site for the exact visible version. Homebrew
formula validation completes before the tap push. Tracked AUR metadata and
tagged files are validated fail-closed here, but publication to the external
AUR repository remains a maintainer action.
Maintainers performing that handoff must follow the
[AUR publication and update runbook](packaging/aur/README.md), including its
dedicated-key, immutable-tag, clean-build, and public-verification requirements.

## Pull requests

Before opening a pull request:

```sh
make check
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
