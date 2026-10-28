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
- Update CLI help, the `USAGE.md` command reference, README, completions,
  `docs/llms.txt`, structured data, and `CHANGELOG.md` together when the
  public surface changes.
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

The following six-case matrix is required before a live release unless the
maintainer explicitly waives it using the release input documented below. Test
the current signed ChatGPT app with non-sensitive accounts:

1. Confirm `app default` keeps the existing stock session.
2. Confirm a named profile persists across relaunches.
3. Confirm two different names can run concurrently without state crossover.
4. Confirm Chat, Work, and Codex remain in the same named window context.
5. Confirm CLI actions do not switch any open Desktop window.
6. Confirm the installed app bundle remains byte-for-byte untouched by the
   launcher.

Never publish screenshots, logs, account names, histories, or tokens from this
test without explicit sanitization.

## Search and AI discovery

The public site is static HTML in `docs/index.html`. Keep product definitions,
platform limits, installation paths and FAQ answers readable without JavaScript.
Use `docs/llms.txt` to link the maintained guides rather than creating duplicate
documentation pages. JSON-LD must describe visible facts and real identities;
do not add ratings, testimonials or an organization that the project cannot
substantiate. The GEO test compares FAQ answers against the visible articles,
checks metadata and graph references, and validates local discovery assets.

For a substantive page edit, update the visible `Page updated` date, JSON-LD
`WebPage.dateModified` and the homepage's sitemap `lastmod` together. Use the
actual editorial date, not the release, build or deployment date. The release
version and date remain sourced from `package.json` and `CHANGELOG.md`.
The sitemap lists canonical HTML pages; text references are linked from HTML
and `llms.txt`. GitHub's existing release Atom feed supplies publication dates.

Run `node test/site/geo-test.mjs`, then `make check`. Preview `docs/` locally and
check desktop and mobile layouts, JavaScript disabled, WebGL unavailable,
reduced motion, and keyboard navigation including the Menu bar / Terminal
switch. Essential answers must remain visible without JavaScript, and the ASCII
art must stand in for each WebGL scene. The terminal panel is real
`codex-profile usage` and `workspace list` output with sample quota; capture it
again if their output changes.

After an approved Pages deployment, compare the live response with the deployed
commit and check redirects, MIME types and indexing headers:

```sh
curl -fsSI https://ducksss.github.io/codex-profiles/
curl -fsS https://ducksss.github.io/codex-profiles/sitemap.xml
curl -fsS https://ducksss.github.io/codex-profiles/llms.txt
curl -sSI https://ducksss.github.io/robots.txt
curl -fsS -A Googlebot https://ducksss.github.io/codex-profiles/
curl -fsS -A OAI-SearchBot https://ducksss.github.io/codex-profiles/
```

GitHub Pages hosts this project under `/codex-profiles/`. Its nested
`docs/robots.txt` is only a policy template: crawlers consult
`https://ducksss.github.io/robots.txt` at the **origin root**. A 404 there does
not block Google crawling, but it also does not advertise this sitemap. The
host maintainer can add the sitemap directive to the user-site repository
(`Ducksss/ducksss.github.io`), preserving any existing policy for other projects,
or submit the exact sitemap URL in verified Google Search Console and Bing
Webmaster Tools properties. Do not claim that the nested file controls crawlers.

The maintainer owns console verification, sitemap submission and index coverage
review after deployment, with a monthly recheck for coverage errors and stale
product descriptions. Record the observation date, canonical URL, provider and
evidence; a successful fetch or search sample does not prove complete indexing,
rankings or AI citations. No analytics or account tracking is needed for the
local checks. `OAI-SearchBot` concerns search discovery; `GPTBot` is a separate
training control. Changing either policy requires a deliberate host-level choice.

These practices follow [Google's AI search guidance](https://developers.google.com/search/docs/fundamentals/ai-optimization-guide),
[robots.txt scope](https://developers.google.com/crawling/docs/robots-txt/robots-txt-spec),
and [OpenAI's crawler documentation](https://developers.openai.com/api/docs/bots).
`llms.txt` is an additional reference, not a Google ranking signal or a promise
of AI citations. FAQ markup describes the visible answers; Google [retired FAQ rich results](https://developers.google.com/search/updates)
in May 2026, so it is not a rich-result eligibility claim.

## Release rehearsal and attestation

Dispatch the `Release` workflow from the current `main` commit with the exact
tracked version. Its default `dry_run: true` path requires no Desktop
attestation and makes no tag, registry, release, tap, or Pages changes. The
always-run rehearsal invokes the same canonical `make check` gate used locally,
then requires a clean checkout with no unstaged, staged, or untracked artifacts.
This verification job has read-only repository permissions, and its checkout
does not persist a GitHub credential.

After the six cases above pass, dispatch with `dry_run: false` and set
`desktop_smoke_attestation` to exactly two public app facts, in this form:

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

If the maintainer explicitly chooses to publish without completing the Desktop
checks, use the exact value `waived-by-maintainer` instead. This records the
checks as **unverified** in the workflow summary and public release notes; it
never claims the checks passed. The waiver does not skip automated verification
or publication checks. Separately, `skip_homebrew: true` skips the tap update
and its formula validation, leaving the tap unchanged. Leave the Desktop input
empty to keep failing closed.

`menu_dmg` (default `true`) builds, signs and notarises the menu-bar DMG on
macOS, dry runs included, and attaches it to the GitHub Release. It needs the
Developer ID secrets described in
[macos/README.md](macos/README.md#publish-a-signed-download). Setting it to
`false` publishes a version that can never carry the DMG.

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

npm write tokens expire, so rotate `NPM_TOKEN` before a release when preflight
reports that it cannot authenticate. `scripts/release/set-npm-token.sh` prompts
for the new token without echoing it, or reads it from a pipe such as a
password manager CLI, and runs the same owner checks against an isolated npm
configuration so this machine's own npm login cannot mask a bad token. It then
replaces the repository secret through `gh secret set` on stdin, so the token
never appears in shell history or a process argument list.

`npm publish` can finish before the package becomes publicly available: npm's
[publish-time scanning](https://github.blog/changelog/2026-07-28-npm-publish-time-malware-scanning-and-dual-use-metadata/)
typically takes about five minutes and can take 15 minutes or more. Registry
metadata can appear before the package tarball is downloadable. The workflow
therefore verifies metadata and public installation in separate stages, each
with its own 20-minute wait budget: 41 attempts with 40 sleeps of 30 seconds.
Metadata verification requires the registry's exact SHA-512 integrity to match
the release artifact. Installation verification uses a fresh prefix and checks
`help` and `version` through both command aliases. On either timeout, investigate
npm review notifications and registry status, then rerun the same immutable
release once the exact artifact is publicly installable. Never bypass checks or
move tags to recover. Because every rerun also requires `origin/main` to still
be the verified commit, do not merge to `main` until the release finishes; if
`main` moves after the tag is pushed, the rerun stops at that check and the
remaining channels need a new patch release.

The workflow then verifies the exact GitHub Release tag, downloads `install.sh`
from that immutable tag, and exercises its public `releases/latest` path in
fresh prefixes until both aliases report the exact version and the plural alias
is the expected relative symlink. The workflow also requires a newly created
Pages run from the tag to succeed and polls the public site for the exact visible
version. Homebrew formula validation completes before the tap push. Tracked AUR
metadata and tagged files are validated fail-closed here, but publication to the
external AUR repository remains a maintainer action.
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
