# Release Hardening Design

## Goal

Make the v0.7 ChatGPT Desktop migration safe to release by eliminating
false-green smoke tests, making package sources and release transformations
verifiable, requiring a recorded signed-app check, and aligning public copy
with the project's actual local-state boundary.

## Chosen approach

Keep the existing dependency-free Bash CLI and GitHub Actions release design,
then add focused guards and regression tests at each failure boundary. This is
preferred over rewriting release automation into another language because the
current implementation is understandable and already well covered. It is also
preferred over dropping AUR or Homebrew because those are supported install
channels and can be made deterministic without changing the CLI.

The alternatives considered were:

1. Move all packaging and release logic into a new script or release framework.
   This would centralize logic, but adds a runtime/tooling surface and a larger
   migration than the demonstrated risks require.
2. Remove the AUR and Homebrew channels. This would reduce release work, but
   breaks supported installation paths and avoids rather than solves the
   integrity problems.
3. Add targeted shell strictness, immutable inputs, postcondition assertions,
   and workflow tests. This is the selected option because it preserves the
   current architecture and directly prevents every observed failure mode.

## Public contract

- `codex-profile` remains the canonical installed command and npm package.
- `codex-profiles` remains the project name and installed compatibility alias.
- The project never installs an executable named `codex`; that name remains
  reserved for OpenAI's CLI.
- `app default` preserves the stock ChatGPT Desktop state.
- A named `app <profile>` launch selects matching `CODEX_HOME` and Electron
  user data for that local ChatGPT window across Chat, Work, and Codex.
- Local-state separation is not described as verified account isolation, an
  operating-system sandbox, or a server-side ChatGPT workspace boundary.
- The original signed ChatGPT application remains untouched.
- Version 0.7.0 and the existing command surface remain unchanged.

## Components

### Deterministic smoke harness

Every multi-command Make recipe must enter strict shell mode before its first
assertion and install an `EXIT` cleanup trap immediately after creating its
temporary directory. A failed path assertion, install, executable check,
alias check, uninstall check, npm pack, or npm install must make the target
fail even when cleanup succeeds.

A regression test must execute deliberately failing Make recipes derived from
the real targets and prove they return non-zero. The same test must exercise
the successful source and npm install paths so the hardening cannot be
satisfied merely by making the recipes always fail.

### Immutable AUR source

The stable AUR package must fetch the versioned `bin/codex-profile` and
`LICENSE` release files instead of cloning a Git tag. Both files must have real
SHA-256 digests in `sha256sums`, and `.SRCINFO` must match. The package function
installs only those verified files. Tests must reject VCS sources, `SKIP`,
mismatched `.SRCINFO`, and placeholder digests.

The file digests are computable before release because they cover tracked
release content rather than an as-yet-unpublished GitHub-generated archive.
After creating or validating the tag, the release workflow must download both
tagged files and verify the tracked digests before declaring the tracked AUR
metadata releasable. Moving a tag to different content therefore makes
package verification fail instead of changing what users install. Publishing
to the external AUR repository remains a maintainer-controlled step because
this repository has no AUR credential or remote configured.

### Homebrew transformation postconditions

After updating the formula description, URL, digest, plural alias, and alias
test, the release workflow must assert every expected line exists. A missing
`sed` anchor must therefore stop the release. The transformation must be
extracted into a repository-owned, dependency-free shell script so it can be
tested against disposable formulas before a release. Tests must cover both a
current formula and a malformed formula missing each insertion anchor.

### Release dry run and signed-app gate

The default dry run must rehearse local, non-publishing transformations:

- build and install the npm tarball into a temporary prefix;
- package the current AUR source tree and validate both aliases;
- transform and syntax-check a fixture Homebrew formula;
- exercise the standalone installer against a local pinned fixture; and
- run the same version, metadata, lint, and behavior checks as CI.

Publishing remains restricted to a non-dry run from the exact current `main`
commit. A non-dry run must require the operator to provide a signed-app smoke
attestation containing the tested ChatGPT version and bundle identifier. The
workflow records that attestation in the job summary; it never receives
account names, screenshots, tokens, cookies, histories, or private paths.

The manual matrix remains:

1. `app default` preserves the existing stock session.
2. A named profile persists across relaunches.
3. Two names run concurrently without local-state crossover.
4. Chat, Work, and Codex remain in the same named window context.
5. CLI commands do not switch open Desktop windows.
6. The installed signed application is unchanged after the test.

### Post-publish verification

The release workflow must verify artifacts after publication where the
channel permits it. At minimum it must install the just-published npm package
into a fresh prefix, run both command aliases, verify the GitHub release, and
validate the deployed documentation version. Homebrew and AUR publication
steps must validate their generated package metadata before any external push;
where a channel is not published by this repository, its tracked metadata must
still pass the same local package checks.

### Terminology and support files

Machine-facing descriptions, package metadata, launch copy, media guidance,
and contributor templates must use precise terms such as “named ChatGPT
windows with separate local state.” Search keywords that imply verified
account switching must be removed. The bug and pull-request templates must
distinguish `app default`, named Desktop profiles, and Codex-only commands and
must state the complete token/cookie handling prohibition.

## Error handling

- Every release helper uses `set -euo pipefail` in Bash or `set -eu` in POSIX
  shell as appropriate.
- Temporary state is removed with traps and cannot overwrite the real user
  home, application bundle, package manager prefix, or tap checkout.
- Missing anchors, mismatched versions, mutable sources, placeholder digests,
  missing attestation, and failed post-publish checks terminate the workflow.
- Re-running a partially completed release remains safe: existing matching
  tags, npm versions, and GitHub releases are accepted only when they match the
  requested version and commit.

## Test strategy

The implementation follows red-green testing for each behavioral guard:

- add metadata tests that fail on the current mutable AUR source;
- add smoke-harness tests that reproduce cleanup masking an earlier failure;
- add Homebrew helper tests that fail because no helper/postcondition exists;
- add workflow contract tests that fail without dry-run rehearsal and signed
  app attestation;
- add terminology checks that fail on prohibited account-isolation claims;
- implement the smallest change that makes each focused test pass;
- run `make test`, `make lint`, `git diff --check`, npm package installation,
  package metadata checks, and available workflow syntax validation;
- run an independent whole-diff code review before integration.

Automated tests continue to use disposable fake app bundles and never launch,
modify, or inspect the real signed ChatGPT app or real account data.

## Shipping boundary

The implementation is complete when all automated gates pass, the branch has
an independent clean review, and the release workflow is ready to accept the
sanitized signed-app attestation. Publishing v0.7.0 is a separate external
state change performed only from `main` through the protected release
workflow after the manual matrix passes.
