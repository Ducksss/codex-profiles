# Release Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the v0.7 ChatGPT Desktop migration into a fail-closed,
cryptographically pinned, fully rehearsed release with precise local-state
claims and recorded signed-app verification.

**Architecture:** Preserve the dependency-free Bash CLI and existing GitHub
Actions workflow. Add small shell regression tests and one repository-owned
Homebrew formula transformer, then make every package/release boundary assert
its postconditions before it can publish or report success.

**Tech Stack:** Bash, POSIX shell, GNU Make, GitHub Actions YAML, Node.js for
the existing documentation validator, Arch PKGBUILD metadata, Ruby syntax
checking for Homebrew formulas.

## Global Constraints

- `codex-profile` remains the canonical installed command and npm package.
- `codex-profiles` remains the project name and installed compatibility alias.
- The project never installs an executable named `codex`.
- `app default` preserves stock ChatGPT Desktop state.
- Named Desktop launches select matching `CODEX_HOME` and Electron user data
  without claiming verified account isolation or an OS/server-side boundary.
- The original signed ChatGPT application is never copied, patched, re-signed,
  quit globally, or killed broadly.
- Version stays `0.7.0`; deprecated `--instance`, `--rebuild`, and
  `app-instance` spellings remain accepted.
- Distributed runtime remains Bash plus standard POSIX/macOS tools; no new
  runtime dependency is introduced.
- Automated tests use fake bundles and fixtures and never inspect or launch a
  real account session.

---

### Task 1: Checkpoint the reviewed v0.7 migration

**Files:**
- Commit: all current migration files already modified in the worktree
- Exclude: `docs/superpowers/specs/2026-07-11-release-hardening-design.md`
  and this plan because they have their own commits

**Interfaces:**
- Consumes: the already-reviewed migration from Codex.app cloning to signed
  ChatGPT.app launches.
- Produces: a clean committed baseline so every hardening task has an isolated
  Git range and reviewable diff.

- [ ] **Step 1: Verify the current migration before checkpointing it**

```sh
make test
make lint
git diff --check
```

Expected: all commands exit 0. The known Make failure-masking defect is
addressed by Task 2; run the source and npm install blocks once under an
explicit `set -eu` shell before committing.

- [ ] **Step 2: Inspect the intended checkpoint scope**

```sh
git status --short
git diff --stat
git diff -- bin/codex-profile test/codex-profile-test.sh Makefile \
  .github/workflows/ci.yml .github/workflows/release.yml
```

Expected: only the v0.7 migration, its tests, packaging, release automation,
and documentation are present; no temporary artifacts or account data exist.

- [ ] **Step 3: Commit the migration baseline**

```sh
git add .github AGENTS.md CHANGELOG.md CONTRIBUTING.md LAUNCH.md Makefile \
  README.md SECURITY.md agent.md bin docs flake.nix install.sh media \
  package-lock.json package.json packaging test
git restore --staged docs/superpowers/specs docs/superpowers/plans
git commit
```

Commit subject: `fullstack(feat): migrate profiles to ChatGPT desktop`

The body must summarize signed-app launching, whole-window local state,
compatibility, CLI fallback, version synchronization, and the tests run.

---

### Task 2: Make every Make smoke recipe fail closed

**Files:**
- Create: `test/makefile-smoke-test.sh`
- Modify: `Makefile`

**Interfaces:**
- Consumes: existing `make test`, `make install`, `make uninstall`, and
  `npm-package-test` targets.
- Produces: `path-smoke-test`, `install-smoke-test`, and
  `npm-package-test` targets whose first failed command is their exit status.

- [ ] **Step 1: Write the failing Make regression test**

Create `test/makefile-smoke-test.sh` with `set -euo pipefail`. It must:

```bash
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAKEFILE="$ROOT_DIR/Makefile"

for target in path-smoke-test install-smoke-test npm-package-test; do
  grep -Eq "^${target}:" "$MAKEFILE" || {
    printf 'FAIL: missing %s target\n' "$target" >&2
    exit 1
  }
done

strict_count="$(grep -c 'set -eu;.*mktemp -d' "$MAKEFILE" || true)"
[[ "$strict_count" -eq 3 ]] || {
  printf 'FAIL: expected three strict temporary-directory smoke recipes\n' >&2
  exit 1
}
```

Add a `mutate_recipe` helper that copies the real Makefile and replaces one
unique assertion line with `false; \` while preserving the rest of the
recipe. For each target, run the mutated target and fail the test if Make
returns zero. Run the unmodified three targets once and require success.

- [ ] **Step 2: Run the test and verify RED**

```sh
bash test/makefile-smoke-test.sh
```

Expected: FAIL because `path-smoke-test` and `install-smoke-test` do not yet
exist and the current inline recipes have no strict-mode/trap contract.

- [ ] **Step 3: Split and harden the recipes**

Modify `Makefile` so `test` ends with:

```make
	$(MAKE) path-smoke-test
	$(MAKE) install-smoke-test
	$(MAKE) npm-package-test
```

Each smoke target must use this shape:

```make
path-smoke-test:
	@set -eu; tmp_home="$$(mktemp -d)"; \
		trap 'rm -rf "$$tmp_home"' EXIT HUP INT TERM; \
		HOME="$$tmp_home" bin/codex-profile path default | grep -E '/\.codex$$' >/dev/null; \
		HOME="$$tmp_home" bin/codex-profile path personal | grep -E '/\.codex-personal$$' >/dev/null; \
		HOME="$$tmp_home" bin/codex-profile path edu | grep -E '/\.codex-edu$$' >/dev/null; \
		HOME="$$tmp_home" bin/codex-profile path education | grep -E '/\.codex-education$$' >/dev/null
```

Use the same `set -eu`, immediate `mktemp`, and trap pattern for source install
and npm pack/install. Never leave `rm -rf` as the final status-bearing command.
Add the new test script to syntax checks, ShellCheck, and `make test` before the
three smoke targets run.

- [ ] **Step 4: Verify GREEN and mutation sensitivity**

```sh
bash test/makefile-smoke-test.sh
make test
make lint
```

Expected: the unmodified targets pass; each deliberately mutated target fails;
the full suite exits 0 with clean output.

- [ ] **Step 5: Commit**

Commit subject: `tests(fix): make smoke recipes fail closed`

---

### Task 3: Enforce precise local-state terminology

**Files:**
- Modify: `test/geo-site-test.mjs`
- Modify: `test/package-metadata-test.sh`
- Modify: `bin/codex-profile`
- Modify: `README.md`, `docs/index.html`, `docs/llms.txt`
- Modify: `LAUNCH.md`, `media/README.md`, `CONTRIBUTING.md`
- Modify: `package.json`, `package-lock.json`, `flake.nix`
- Modify: `packaging/aur/PKGBUILD`, `packaging/aur/.SRCINFO`
- Modify: `.github/PULL_REQUEST_TEMPLATE.md`
- Modify: `.github/ISSUE_TEMPLATE/bug_report.yml`
- Modify: `.github/workflows/release.yml`

**Interfaces:**
- Consumes: the v0.7 scope contract and current structured-data validator.
- Produces: human, CLI, package, and machine-readable copy that says separate
  local state without promising account or security isolation.

- [ ] **Step 1: Add failing terminology assertions**

In `test/geo-site-test.mjs`, assert that current product summaries do not
contain `isolated local ChatGPT`, `isolated ChatGPT desktop sessions`, or
`account isolation`, while requiring `separate local state` in the description
and structured data.

In `test/package-metadata-test.sh`, add:

```bash
node - <<'NODE'
const pkg = require('./package.json');
for (const keyword of ['codex-account-switcher', 'multiple-accounts']) {
  if (pkg.keywords.includes(keyword)) {
    throw new Error(`unverified account-switching keyword must be removed: ${keyword}`);
  }
}
if (!pkg.description.includes('separate local ChatGPT desktop state')) {
  throw new Error('package description must state the local-state boundary');
}
NODE
```

Add focused CLI assertions in `test/codex-profile-test.sh` requiring named
launch/doctor output to say `separate local state` and not `isolated ChatGPT
window`.

- [ ] **Step 2: Run focused tests and verify RED**

```sh
node test/geo-site-test.mjs
bash test/package-metadata-test.sh
bash test/codex-profile-test.sh
```

Expected: all three fail on current isolation/account-switching wording.

- [ ] **Step 3: Apply the terminology sweep**

Use these canonical phrases consistently:

```text
named ChatGPT windows with separate local state
separate Electron state for this named ChatGPT window
local-state separation is not an account, OS, or server-side boundary
```

Change the CLI doctor machine scope from
`named:isolated_chatgpt_window` to `named:separate_local_state` before v0.7 is
released, and update its tests. Replace package keywords with accurate terms
such as `local-state`, `named-profiles`, and `chatgpt-desktop`.

Expand the PR checklist prohibition to cover reading, copying, printing,
parsing, uploading, comparing, or migrating auth tokens and ChatGPT cookies.
Split bug-report scope options into Codex CLI/CODEX_HOME, `app default`, named
Desktop profile, and both/unsure. Change conditional Desktop-version copy to
“For app-launch issues, provide…” and make `make lint` required unless the
environment lacks ShellCheck. Keep deprecated commands in a clearly labeled
compatibility subsection.

- [ ] **Step 4: Verify GREEN**

```sh
node test/geo-site-test.mjs
bash test/package-metadata-test.sh
bash test/codex-profile-test.sh
rg -n 'codex-account-switcher|multiple-accounts|account-isolation test matrix' \
  README.md docs package.json LAUNCH.md media CONTRIBUTING.md .github packaging flake.nix
```

Expected: focused tests pass and `rg` finds no prohibited current-product
claim.

- [ ] **Step 5: Commit**

Commit subject: `docs(fix): clarify local-state separation`

---

### Task 4: Pin and verify AUR release inputs

**Files:**
- Modify: `test/package-metadata-test.sh`
- Modify: `packaging/aur/PKGBUILD`
- Modify: `packaging/aur/.SRCINFO`
- Modify: `.github/workflows/release.yml`

**Interfaces:**
- Consumes: tracked `bin/codex-profile`, `LICENSE`, and version `0.7.0`.
- Produces: two versioned release-file sources with exact SHA-256 values and a
  packaging function that installs only verified inputs.

- [ ] **Step 1: Add failing source-integrity tests**

Add a portable helper to `test/package-metadata-test.sh`:

```bash
sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}
```

Source the PKGBUILD in a subshell and require:

```bash
[[ "${source[*]}" != *'git+'* ]] || fail "AUR source must not use VCS checkout"
[[ "${sha256sums[*]}" != *'SKIP'* ]] || fail "AUR source checksums must not be skipped"
[[ "${#source[@]}" -eq 2 && "${#sha256sums[@]}" -eq 2 ]] || fail "AUR must pin script and license"
[[ "${sha256sums[0]}" == "$(sha256_file bin/codex-profile)" ]] || fail "CLI checksum mismatch"
[[ "${sha256sums[1]}" == "$(sha256_file LICENSE)" ]] || fail "license checksum mismatch"
```

Require `.SRCINFO` to contain the same two sources and digests and no
`makedepends = git`.

- [ ] **Step 2: Run and verify RED**

```sh
bash test/package-metadata-test.sh
```

Expected: FAIL because the current PKGBUILD uses `git+...#tag=v$pkgver` and
`sha256sums=('SKIP')`.

- [ ] **Step 3: Replace the VCS source**

Use this PKGBUILD source structure:

```bash
source=(
  "codex-profile-$pkgver::https://raw.githubusercontent.com/Ducksss/codex-profiles/v$pkgver/bin/codex-profile"
  "LICENSE-$pkgver::https://raw.githubusercontent.com/Ducksss/codex-profiles/v$pkgver/LICENSE"
)

package() {
  install -Dm755 "codex-profile-$pkgver" "$pkgdir/usr/bin/codex-profile"
  ln -s codex-profile "$pkgdir/usr/bin/codex-profiles"
  install -Dm644 "LICENSE-$pkgver" "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
```

Compute the final values after Task 3 with:

```sh
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum bin/codex-profile LICENSE
else
  shasum -a 256 bin/codex-profile LICENSE
fi
```

Write the two reported 64-character lowercase digests, in script/license
order, into a two-entry `sha256sums` array. Regenerate `.SRCINFO` exactly and
run the test to prove the recorded values match the files.

Update the GNU package smoke fixture to copy the tracked script and license to
the source filenames before invoking `package()`.

- [ ] **Step 4: Harden tagged-source verification**

In the non-dry release step, download both `raw.githubusercontent.com` tag URLs
into a temporary directory, verify them with the two tracked PKGBUILD digests,
run `package()`, and execute both installed aliases. The step must use
`set -euo pipefail` and an `EXIT` trap.

- [ ] **Step 5: Verify GREEN**

```sh
bash test/package-metadata-test.sh
make test
```

Expected: metadata, hashes, aliases, and package contents all pass.

- [ ] **Step 6: Commit**

Commit subject: `build(security): pin AUR release sources`

---

### Task 5: Extract and test Homebrew formula transformation

**Files:**
- Create: `scripts/update-homebrew-formula`
- Create: `test/release-helper-test.sh`
- Modify: `Makefile`
- Modify: `.github/workflows/release.yml`

**Interfaces:**
- Consumes: formula path, exact `X.Y.Z` version, and 64-character tarball SHA.
- Produces: an updated formula containing the expected description, URL,
  digest, plural alias install, and plural alias test; exits non-zero when any
  required anchor is absent.

- [ ] **Step 1: Write failing helper tests**

Create a valid disposable formula containing:

```ruby
class CodexProfile < Formula
  desc "Old description"
  homepage "https://github.com/Ducksss/codex-profiles"
  url "https://example.invalid/old.tar.gz"
  sha256 "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

  def install
    bin.install "bin/codex-profile"
  end

  test do
    system bin/"codex-profile", "help"
  end
end
```

Run `scripts/update-homebrew-formula FORMULA 0.7.0` with a known 64-character
digest. Assert exact URL/digest/description, exactly one alias line, exactly
one alias test, and successful `ruby -c` when Ruby exists. Run it twice to
prove idempotency. Create malformed fixtures missing each required anchor and
require non-zero exits with a specific `Missing Homebrew formula anchor`
message.

- [ ] **Step 2: Run and verify RED**

```sh
bash test/release-helper-test.sh
```

Expected: FAIL because `scripts/update-homebrew-formula` does not exist.

- [ ] **Step 3: Implement the portable helper**

The script must begin:

```bash
#!/usr/bin/env bash
set -euo pipefail

formula="${1:-}"
version="${2:-}"
sha="${3:-}"
[[ -f "$formula" ]] || { printf 'Missing Homebrew formula: %s\n' "$formula" >&2; exit 1; }
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'Invalid release version: %s\n' "$version" >&2; exit 1; }
[[ "$sha" =~ ^[0-9a-f]{64}$ ]] || { printf 'Invalid SHA-256: %s\n' "$sha" >&2; exit 1; }
```

Validate the `desc`, `url`, `sha256`, primary install, and primary test anchors
before mutation. Use `awk` plus a temporary file and `trap` rather than
platform-specific `sed -i`. Insert alias lines only when missing, then assert
all five exact postconditions with `grep -Fqx`. Preserve all unrelated formula
content.

- [ ] **Step 4: Wire the helper into tests and release**

Add both new shell files to `bash -n`, ShellCheck, and `make test`. Replace the
inline Homebrew `sed` block in `release.yml` with:

```sh
scripts/update-homebrew-formula "$formula" "$V" "$sha"
ruby -c "$formula"
```

- [ ] **Step 5: Verify GREEN**

```sh
bash test/release-helper-test.sh
make test
make lint
```

Expected: valid and idempotent transformations pass; malformed formulas fail
before mutation; the full suite is clean.

- [ ] **Step 6: Commit**

Commit subject: `ci(fix): verify Homebrew formula updates`

---

### Task 6: Rehearse release paths and require signed-app evidence

**Files:**
- Create: `test/install-script-test.sh`
- Create: `test/release-workflow-test.sh`
- Modify: `Makefile`
- Modify: `.github/workflows/release.yml`
- Modify: `CONTRIBUTING.md`, `LAUNCH.md`, `CHANGELOG.md`

**Interfaces:**
- Consumes: `install.sh`, `make test`, the release workflow, version input,
  dry-run flag, and a sanitized Desktop attestation.
- Produces: a default dry run that exercises every non-publishing transform,
  a non-dry release that refuses missing evidence, and post-publish npm/GitHub
  checks.

- [ ] **Step 1: Write a failing standalone-installer smoke test**

Create a temporary fake `curl` earlier on `PATH`. It must return a fixture
release JSON for the GitHub API URL and the tracked `bin/codex-profile` for the
raw file URL. Run `install.sh` with temporary `HOME` and
`CODEX_PROFILE_PREFIX`, then assert:

```bash
[[ -x "$prefix/bin/codex-profile" ]]
[[ -L "$prefix/bin/codex-profiles" ]]
"$prefix/bin/codex-profile" version | grep -Fx "codex-profile 0.7.0"
"$prefix/bin/codex-profiles" help >/dev/null
```

Also run with an invalid downloaded fixture and require a non-zero exit without
an installed executable.

- [ ] **Step 2: Write failing workflow contract tests**

`test/release-workflow-test.sh` must require all of these literal contracts:

```text
desktop_smoke_attestation
ChatGPT version
bundle ID
Signed-app smoke attestation is required for a live release
npm install -g --prefix
gh release view
scripts/update-homebrew-formula
Verify tagged AUR release files
```

It must also assert that dry-run verification calls the standalone installer,
Homebrew helper test, AUR metadata/package test, npm package smoke, `make lint`,
and `git diff --exit-code` before any live-publish step.

- [ ] **Step 3: Run focused tests and verify RED**

```sh
bash test/install-script-test.sh
bash test/release-workflow-test.sh
```

Expected: the installer characterization test passes against the existing
installer; workflow coverage fails because attestation and post-publish
contracts are absent.

- [ ] **Step 4: Add the attestation gate and dry-run rehearsal**

Add a workflow-dispatch string input:

```yaml
desktop_smoke_attestation:
  description: "Live release only: tested ChatGPT version and bundle ID; no account data."
  required: false
  type: string
```

Export it as `DESKTOP_SMOKE_ATTESTATION`. During source validation, reject an
empty value only when `DRY_RUN != true`, and require the text to contain both
`ChatGPT` and `com.openai.`. Append the sanitized string to the job summary.

The always-run verification stage must explicitly run:

```sh
make test
make lint
bash test/install-script-test.sh
bash test/release-helper-test.sh
bash test/package-metadata-test.sh
make npm-package-test
git diff --exit-code
```

No dry-run step may tag, publish, push, create a release, or deploy Pages.

- [ ] **Step 5: Add post-publish checks**

After npm publication, install `codex-profile@$V` into a fresh temporary prefix
with a separate npm cache and run `help`/`version` through both aliases. After
GitHub Release creation, require `gh release view "$TAG"` to report the exact
tag. Keep Homebrew/AUR verification fail-closed before their external handoff.

Dispatch Pages from the immutable tag, poll for the workflow-dispatch run at
the release commit, and require it to succeed:

```sh
gh workflow run pages.yml --repo "$GITHUB_REPOSITORY" --ref "$TAG"
run_id=""
for attempt in {1..30}; do
  run_id="$(gh run list --repo "$GITHUB_REPOSITORY" --workflow pages.yml \
    --commit "$GITHUB_SHA" --event workflow_dispatch --limit 1 \
    --json databaseId --jq '.[0].databaseId // empty')"
  [[ -z "$run_id" ]] || break
  sleep 2
done
[[ -n "$run_id" ]] || { echo "Pages run was not created for $TAG." >&2; exit 1; }
gh run watch "$run_id" --repo "$GITHUB_REPOSITORY" --exit-status
```

Then poll `https://ducksss.github.io/codex-profiles/` for the exact visible
`v$V` marker, with bounded retries, before reporting deployed documentation.

- [ ] **Step 6: Update release documentation**

Document the required six-case signed-app matrix, exact allowed attestation
contents, dry-run coverage, and post-publish checks. State explicitly that the
AUR metadata is validated here but external AUR publication remains a
maintainer action.

- [ ] **Step 7: Verify GREEN**

```sh
bash test/install-script-test.sh
bash test/release-workflow-test.sh
make test
make lint
git diff --check
```

Expected: all release contracts and the complete project suite pass.

- [ ] **Step 8: Commit**

Commit subject: `ci(test): rehearse and verify releases`

---

### Task 7: Final verification and independent review

**Files:**
- Review: the full branch diff from `origin/main` to `HEAD`
- Modify only if verification or review finds a defect

**Interfaces:**
- Consumes: Tasks 1–6 and the global constraints.
- Produces: a reviewed, release-ready branch; it does not itself publish v0.7.

- [ ] **Step 1: Run the complete verification matrix fresh**

```sh
make test
make lint
git diff --check
bash test/makefile-smoke-test.sh
bash test/package-metadata-test.sh
bash test/release-helper-test.sh
bash test/install-script-test.sh
bash test/release-workflow-test.sh
npm pack --dry-run
```

If `actionlint` is available, run `actionlint`. If Nix is available, run
`nix build .# --print-build-logs` and execute both aliases from `result/bin`.

- [ ] **Step 2: Verify the current installed product without launching it**

```sh
/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' /Applications/ChatGPT.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' /Applications/ChatGPT.app/Contents/Info.plist
/Applications/ChatGPT.app/Contents/Resources/codex --version
```

Expected: a usable ChatGPT bundle, `com.openai.codex`, and a healthy Codex CLI.
Do not count this read-only detection as the six-case signed-app attestation.

- [ ] **Step 3: Request an independent whole-branch review**

Generate a review package for `origin/main..HEAD`. The reviewer must check
public-surface compatibility, false-green resistance, source integrity,
release idempotency, secret handling, test sensitivity, and documentation
accuracy. Fix every Critical or Important finding and re-run its covering
tests before re-review.

- [ ] **Step 4: Confirm release boundary**

Verify the branch is committed and clean. The release workflow must still
require `main`, a matching version, a dated changelog, a sanitized signed-app
attestation, and `dry_run=false`. Do not publish from the feature branch.
