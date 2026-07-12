#!/usr/bin/env node

import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const testDir = dirname(fileURLToPath(import.meta.url));
const rootDir = dirname(testDir);
const runbookPath = join(rootDir, "packaging", "aur", "README.md");
const runbook = readFileSync(runbookPath, "utf8");
const bashBlocks = [...runbook.matchAll(/^```bash\s*\n([\s\S]*?)^```\s*$/gm)]
  .map((match) => match[1]);

assert.ok(bashBlocks.length > 0, "AUR runbook must contain Bash code blocks");

const extractedBash = [
  "#!/usr/bin/env bash",
  "# Extracted from packaging/aur/README.md for syntax and lint checks.",
  ...bashBlocks,
].join("\n\n");

if (process.argv.includes("--extract")) {
  process.stdout.write(extractedBash);
  process.exit(0);
}

function assertIncludes(haystack, needle, message) {
  assert.ok(haystack.includes(needle), message ?? `missing: ${needle}`);
}

function assertOrdered(haystack, needles, message) {
  let cursor = -1;
  for (const needle of needles) {
    const next = haystack.indexOf(needle, cursor + 1);
    assert.ok(next > cursor, `${message}: ${needle}`);
    cursor = next;
  }
}

function normalized(value) {
  return value.replace(/\s+/g, " ").trim();
}

const firstCommand = bashBlocks[0]
  .split("\n")
  .map((line) => line.trim())
  .find((line) => line !== "" && !line.startsWith("#"));
assert.equal(
  firstCommand,
  "set -euo pipefail",
  "strict mode must be enabled before the first key-management command",
);

assert.match(
  runbook,
  /if \[\[ ! -f "\$AUR_SSH_KEY" \|\| -L "\$AUR_SSH_KEY" \]\]; then[\s\S]*?exit 1[\s\S]*?fi/,
  "the private-key predicate must fail explicitly",
);
assert.match(
  runbook,
  /if \[\[ ! -f "\$AUR_SSH_KEY\.pub" \|\| ! -s "\$AUR_SSH_KEY\.pub" \|\| -L "\$AUR_SSH_KEY\.pub" \]\]; then[\s\S]*?exit 1[\s\S]*?fi/,
  "the public-key predicate must require a nonempty regular file",
);
assertIncludes(
  runbook,
  "[official AUR homepage](https://aur.archlinux.org/)",
  "host-key verification must link the current official AUR source",
);
assert.match(
  runbook,
  /if \[\[ ! -f "\$AUR_KNOWN_HOSTS" \|\| ! -s "\$AUR_KNOWN_HOSTS" \|\| -L "\$AUR_KNOWN_HOSTS" \]\]; then[\s\S]*?exit 1[\s\S]*?fi/,
  "the dedicated known_hosts predicate must fail explicitly",
);

assert.doesNotMatch(
  extractedBash,
  /\bexport\s+[A-Z][A-Z0-9_]*=.*\$\(/,
  "capture and validate command substitutions before exporting them",
);

assertOrdered(
  extractedBash,
  [
    "REPO_ROOT=",
    'if ! REPO_ROOT="$(git rev-parse --show-toplevel)"; then',
    '[[ -n "$REPO_ROOT"',
    "export REPO_ROOT",
  ],
  "REPO_ROOT must be captured, validated, then exported",
);
assertOrdered(
  extractedBash,
  [
    "WORK_DIR=",
    'if ! WORK_DIR="$(mktemp -d',
    '[[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]',
    'case "$WORK_DIR" in',
    "export WORK_DIR",
    'export EXTRACT_DIR="$WORK_DIR/tag"',
  ],
  "WORK_DIR must be captured and proven safe before derivation",
);
assertOrdered(
  extractedBash,
  [
    'git -C "$AUR_DIR" commit',
    "PUSHED_COMMIT=",
    'if ! PUSHED_COMMIT="$(git -C "$AUR_DIR" rev-parse --verify "HEAD^{commit}")"; then',
    '[[ "$PUSHED_COMMIT" =~ ^[0-9a-f]{40,64}$ ]]',
    "export PUSHED_COMMIT",
    'git -C "$AUR_DIR" push origin master',
  ],
  "PUSHED_COMMIT must be captured and validated before push",
);
assertIncludes(
  extractedBash,
  'TEMP_ROOT_INPUT="${TMPDIR:-/tmp}"',
  "the temporary root must be explicit",
);
assertIncludes(
  extractedBash,
  '"$TEMP_ROOT"/codex-profile-aur.*)',
  "WORK_DIR cleanup must be restricted to the expected temporary prefix",
);
assertIncludes(
  extractedBash,
  '"$TEMP_ROOT" == /',
  "the filesystem root must never be accepted as the temporary root",
);
assertOrdered(
  extractedBash,
  [
    'case "$WORK_DIR" in',
    "cleanup_work_dir() {",
    "trap cleanup_work_dir EXIT",
    "work_dir_physical=",
  ],
  "safe cleanup must be armed before physical-path validation can fail",
);

assert.doesNotMatch(
  extractedBash,
  /(?:export\s+)?GIT_SSH_COMMAND=/,
  "do not interpolate identity paths into GIT_SSH_COMMAND",
);
assertIncludes(
  extractedBash,
  "unset GIT_SSH_COMMAND",
  "an ambient GIT_SSH_COMMAND must not override the isolated wrapper",
);
for (const contract of [
  'export GIT_SSH="$AUR_SSH_WRAPPER"',
  "export GIT_SSH_VARIANT=ssh",
  "ssh -F /dev/null",
  '-i "$AUR_SSH_KEY"',
  "IdentitiesOnly=yes",
  "StrictHostKeyChecking=yes",
  'UserKnownHostsFile="$AUR_KNOWN_HOSTS"',
  'ssh-keygen -F aur.archlinux.org -f "$AUR_KNOWN_HOSTS"',
  '"$AUR_SSH_WRAPPER" aur@aur.archlinux.org help >/dev/null',
]) {
  assertIncludes(extractedBash, contract, `missing isolated SSH contract: ${contract}`);
}

assertOrdered(
  extractedBash,
  [
    "unset GIT_CONFIG GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT GIT_CONFIG_SYSTEM",
    "unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR",
    "unset GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_TEMPLATE_DIR",
    "unset GIT_NAMESPACE GIT_SHALLOW_FILE GIT_QUARANTINE_PATH",
    "unset GIT_CEILING_DIRECTORIES GIT_DISCOVERY_ACROSS_FILESYSTEM",
    "export GIT_CONFIG_NOSYSTEM=1",
    "export GIT_CONFIG_GLOBAL=/dev/null",
    "export GIT_NO_REPLACE_OBJECTS=1",
    "REPO_ROOT=",
  ],
  "ambient Git configuration and repository routing must be disabled before Git use",
);
assert.doesNotMatch(
  extractedBash,
  /env -u GIT_CONFIG/,
  "no later Git command may undo the process-wide isolated configuration",
);

assertIncludes(
  extractedBash,
  "export EXPECTED_AUR_MAINTAINER=Ducksss",
  "the expected AUR account handle must be explicit",
);
assert.ok(
  (extractedBash.match(/\.results\[0\]\.Maintainer == \$maintainer/g) ?? []).length >= 2,
  "update and final RPC checks must both require the expected maintainer",
);

assertIncludes(
  extractedBash,
  "export CANONICAL_REPO_URL=https://github.com/Ducksss/codex-profiles.git",
  "tag retrieval must name the canonical GitHub repository",
);
assertIncludes(
  extractedBash,
  'git -C "$TAG_REPO" fetch --no-tags "$CANONICAL_REPO_URL"',
  "the annotated tag must be fetched from the canonical URL",
);
assert.doesNotMatch(
  extractedBash,
  /fetch --no-tags origin/,
  "an arbitrary origin must not supply the release tag",
);
assertIncludes(
  normalized(extractedBash),
  'git -c init.defaultBranch=master clone "ssh://aur@aur.archlinux.org/$PACKAGE_NAME.git" "$AUR_DIR"',
  "an empty first-publication clone must deterministically use master",
);

for (const releaseContract of [
  'https://api.github.com/repos/Ducksss/codex-profiles/releases/tags/$TAG',
  ".tag_name == $tag",
  ".draft == false",
  ".prerelease == false",
  '.published_at != null',
  '.immutable == true',
]) {
  assertIncludes(
    extractedBash,
    releaseContract,
    `missing immutable GitHub Release contract: ${releaseContract}`,
  );
}
assertOrdered(
  extractedBash,
  [
    'release_payload=',
    'https://api.github.com/repos/Ducksss/codex-profiles/releases/tags/$TAG',
    '.immutable == true',
    'git -C "$TAG_REPO" archive',
  ],
  "the public immutable Release must be verified before tag extraction",
);

const finalRpcBlock = bashBlocks.find((block) => block.includes("rpc_verified=false"));
assert.ok(finalRpcBlock, "missing final AUR RPC polling block");
assertIncludes(
  finalRpcBlock,
  "if (( attempt < 12 )); then",
  "the final failed RPC attempt must not sleep",
);
assertOrdered(
  finalRpcBlock,
  ["if (( attempt < 12 )); then", "sleep 10", "fi"],
  "RPC backoff must be bounded before the final attempt",
);

assertIncludes(
  extractedBash,
  "unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_AUTHOR_DATE",
  "ambient author identity must be removed",
);
assertIncludes(
  extractedBash,
  "unset GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL GIT_COMMITTER_DATE",
  "ambient committer identity must be removed",
);
for (const field of ["%an", "%ae", "%cn", "%ce"]) {
  assertIncludes(extractedBash, field, `pushed commit must verify ${field}`);
}
assertIncludes(
  extractedBash,
  '[[ "$commit_author_name" == "$AUR_GIT_NAME" ]]',
  "the committed author name must match exactly",
);
assertIncludes(
  extractedBash,
  '[[ "$commit_committer_email" == "$AUR_GIT_EMAIL" ]]',
  "the committed committer email must match exactly",
);

const syntaxDir = mkdtempSync(join(tmpdir(), "codex-profile-aur-runbook-test."));
try {
  bashBlocks.forEach((block, index) => {
    const blockPath = join(syntaxDir, `block-${index + 1}.bash`);
    writeFileSync(blockPath, block);
    const result = spawnSync("bash", ["-n", blockPath], { encoding: "utf8" });
    assert.equal(
      result.status,
      0,
      `Bash block ${index + 1} failed syntax validation:\n${result.stderr}`,
    );
  });
} finally {
  rmSync(syntaxDir, { recursive: true, force: true });
}

const fixturesDir = join(testDir, "fixtures", "aur-rpc");
const fixtures = Object.fromEntries(
  ["unclaimed", "expected-owner", "unexpected-owner", "exact-final-version"].map(
    (name) => [name, JSON.parse(readFileSync(join(fixturesDir, `${name}.json`), "utf8"))],
  ),
);

const packageName = "codex-profile";
const maintainer = "Ducksss";
const expectedVersion = "0.7.0-1";
const isUnclaimed = (payload) =>
  payload.resultcount === 0 && Array.isArray(payload.results) && payload.results.length === 0;
const isExpectedUpdate = (payload) =>
  payload.resultcount === 1 &&
  payload.results?.[0]?.Name === packageName &&
  payload.results?.[0]?.PackageBase === packageName &&
  payload.results?.[0]?.Maintainer === maintainer;
const isExactFinal = (payload) =>
  isExpectedUpdate(payload) && payload.results[0].Version === expectedVersion;

assert.equal(isUnclaimed(fixtures.unclaimed), true);
assert.equal(isUnclaimed(fixtures["expected-owner"]), false);
assert.equal(isExpectedUpdate(fixtures["expected-owner"]), true);
assert.equal(isExpectedUpdate(fixtures["unexpected-owner"]), false);
assert.equal(isExactFinal(fixtures["exact-final-version"]), true);
assert.equal(isExactFinal(fixtures["expected-owner"]), false);
assert.equal(isExactFinal(fixtures["unexpected-owner"]), false);

const releaseFixtures = JSON.parse(
  readFileSync(join(testDir, "fixtures", "github-release-contract.json"), "utf8"),
);
const isImmutableFinalRelease = (payload) =>
  payload.tag_name === "v0.7.0" &&
  payload.draft === false &&
  payload.prerelease === false &&
  typeof payload.published_at === "string" &&
  payload.published_at.length > 0 &&
  payload.immutable === true;
assert.equal(isImmutableFinalRelease(releaseFixtures.immutableFinal), true);
assert.equal(isImmutableFinalRelease(releaseFixtures.mutable), false);
assert.equal(isImmutableFinalRelease(releaseFixtures.draft), false);
assert.equal(isImmutableFinalRelease(releaseFixtures.wrongTag), false);

const unclaimedFilter =
  '.resultcount == 0 and (.results | length == 0)';
const updateFilter = `
  .resultcount == 1 and
  .results[0].Name == $name and
  .results[0].PackageBase == $name and
  .results[0].Maintainer == $maintainer
`;
const finalFilter = `
      .resultcount == 1 and
      .results[0].Name == $name and
      .results[0].PackageBase == $name and
      .results[0].Maintainer == $maintainer and
      .results[0].Version == $version
`;
const releaseFilter = `
  .tag_name == $tag and
  .draft == false and
  .prerelease == false and
  .published_at != null and
  (.published_at | type == "string" and length > 0) and
  .immutable == true
`;

assertIncludes(normalized(extractedBash), normalized(unclaimedFilter));
assertIncludes(normalized(extractedBash), normalized(updateFilter));
assertIncludes(normalized(extractedBash), normalized(finalFilter));
assertIncludes(normalized(extractedBash), normalized(releaseFilter));

const jqVersion = spawnSync("jq", ["--version"], { encoding: "utf8" });
if (jqVersion.status === 0) {
  function jqMatches(payload, args, filter) {
    const result = spawnSync("jq", ["-e", ...args, filter], {
      input: JSON.stringify(payload),
      encoding: "utf8",
    });
    assert.ok(
      result.status === 0 || result.status === 1,
      `jq contract failed to execute: ${result.stderr}`,
    );
    return result.status === 0;
  }

  assert.equal(jqMatches(fixtures.unclaimed, [], unclaimedFilter), true);
  assert.equal(jqMatches(fixtures["expected-owner"], [], unclaimedFilter), false);
  assert.equal(
    jqMatches(
      fixtures["expected-owner"],
      ["--arg", "name", packageName, "--arg", "maintainer", maintainer],
      updateFilter,
    ),
    true,
  );
  assert.equal(
    jqMatches(
      fixtures["unexpected-owner"],
      ["--arg", "name", packageName, "--arg", "maintainer", maintainer],
      updateFilter,
    ),
    false,
  );
  assert.equal(
    jqMatches(
      fixtures["exact-final-version"],
      [
        "--arg",
        "name",
        packageName,
        "--arg",
        "maintainer",
        maintainer,
        "--arg",
        "version",
        expectedVersion,
      ],
      finalFilter,
    ),
    true,
  );
  assert.equal(
    jqMatches(
      fixtures["unexpected-owner"],
      [
        "--arg",
        "name",
        packageName,
        "--arg",
        "maintainer",
        maintainer,
        "--arg",
        "version",
        expectedVersion,
      ],
      finalFilter,
    ),
    false,
  );
  assert.equal(
    jqMatches(
      releaseFixtures.immutableFinal,
      ["--arg", "tag", "v0.7.0"],
      releaseFilter,
    ),
    true,
  );
  for (const name of ["mutable", "draft", "wrongTag"]) {
    assert.equal(
      jqMatches(releaseFixtures[name], ["--arg", "tag", "v0.7.0"], releaseFilter),
      false,
    );
  }
} else {
  process.stdout.write("jq not found; pure Node RPC fixture checks passed.\n");
}

process.stdout.write(
  `AUR runbook checks passed (${bashBlocks.length} Bash blocks, 4 RPC fixtures, 4 release fixtures).\n`,
);
