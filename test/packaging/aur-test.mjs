#!/usr/bin/env node

import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import {
  chmodSync,
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const testDir = dirname(fileURLToPath(import.meta.url));
const rootDir = dirname(dirname(testDir));
const prepare = join(rootDir, "scripts", "aur", "prepare.sh");
const verify = join(rootDir, "scripts", "aur", "verify.sh");
const runbookPath = join(rootDir, "packaging", "aur", "README.md");
const fixturesDir = join(rootDir, "test", "fixtures");
const trackedPkgbuild = readFileSync(join(rootDir, "packaging", "aur", "PKGBUILD"), "utf8");
const packageVersion = trackedPkgbuild.match(/^pkgver=(.+)$/m)?.[1];

assert.ok(packageVersion, "tracked PKGBUILD must declare pkgver");

assert.ok(existsSync(prepare), "scripts/aur/prepare.sh must exist");
assert.ok(existsSync(verify), "scripts/aur/verify.sh must exist");

const tempRoot = mkdtempSync(join(tmpdir(), "codex-profile-aur-test."));
process.on("exit", () => rmSync(tempRoot, { recursive: true, force: true }));

function run(script, args, env = {}) {
  return spawnSync("bash", [script, ...args], {
    cwd: rootDir,
    encoding: "utf8",
    env: { ...process.env, ...env },
  });
}

function assertSuccess(result, label) {
  assert.equal(
    result.status,
    0,
    `${label} failed:\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`,
  );
}

function assertFailure(result, label, expectedMessage) {
  assert.notEqual(result.status, 0, `${label} should fail`);
  if (expectedMessage) {
    assert.ok(
      `${result.stdout}\n${result.stderr}`.includes(expectedMessage),
      `${label} should report ${expectedMessage}:\n${result.stderr}`,
    );
  }
}

function writeJson(path, value) {
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
}

function releaseSource(path) {
  const tag = `v${packageVersion}`;
  const tagged = spawnSync("git", ["show", `${tag}:${path}`], {
    cwd: rootDir,
    encoding: null,
  });
  if (tagged.status === 0) return tagged.stdout;
  const shallow = spawnSync("git", ["rev-parse", "--is-shallow-repository"], {
    cwd: rootDir,
    encoding: "utf8",
  });
  assert.notEqual(
    shallow.stdout.trim(),
    "true",
    `release tag ${tag} is unavailable in a shallow checkout; fetch tags`,
  );
  return readFileSync(join(rootDir, path));
}

const releaseFixtures = JSON.parse(
  readFileSync(join(fixturesDir, "github-release-contract.json"), "utf8"),
);
const releaseJson = join(tempRoot, "release.json");
writeJson(releaseJson, releaseFixtures.immutableFinal);

function createArchive(name, mutate = () => {}, prefix = "") {
  const fixtureRoot = join(tempRoot, `${name}-root`);
  const contentRoot = prefix ? join(fixtureRoot, prefix) : fixtureRoot;
  const archive = join(tempRoot, `${name}.tar`);
  mkdirSync(join(contentRoot, "packaging", "aur"), { recursive: true });
  mkdirSync(join(contentRoot, "bin"), { recursive: true });
  for (const path of ["PKGBUILD", ".SRCINFO"]) {
    cpSync(
      join(rootDir, "packaging", "aur", path),
      join(contentRoot, "packaging", "aur", path),
    );
  }
  writeFileSync(join(contentRoot, "bin", "codex-profile"), releaseSource("bin/codex-profile"));
  writeFileSync(join(contentRoot, "LICENSE"), releaseSource("LICENSE"));
  mutate(contentRoot);
  const archivePaths = [
    "packaging/aur/PKGBUILD",
    "packaging/aur/.SRCINFO",
    "bin/codex-profile",
    "LICENSE",
  ].map((path) => (prefix ? `${prefix}/${path}` : path));
  execFileSync(
    "tar",
    ["-cf", archive, "--", ...archivePaths],
    { cwd: fixtureRoot },
  );
  return archive;
}

const archive = createArchive("release");
const prepared = join(tempRoot, "prepared");
const prepareArgs = [
  "--version",
  "0.9.1",
  "--release-json",
  releaseJson,
  "--archive",
  archive,
  "--output",
  prepared,
];

const preparedResult = run(prepare, prepareArgs);
assertSuccess(preparedResult, "immutable release preparation");
assert.match(preparedResult.stdout, /Prepared codex-profile 0\.9\.1-1/);
assert.deepEqual(readdirSync(prepared).sort(), [".SRCINFO", "LICENSE", "PKGBUILD"]);
for (const file of ["PKGBUILD", ".SRCINFO", "LICENSE"]) {
  assert.equal(
    readFileSync(join(prepared, file), "utf8"),
    file === "LICENSE"
      ? releaseSource("LICENSE").toString("utf8")
      : readFileSync(join(rootDir, "packaging", "aur", file), "utf8"),
    `${file} should be staged byte-for-byte from the immutable archive`,
  );
  assert.equal(statSync(join(prepared, file)).mode & 0o777, 0o644, `${file} mode`);
}

const prefixedArchive = createArchive("prefixed-release", () => {}, "codex-profiles-0.9.1");
assertSuccess(
  run(prepare, [
    "--version",
    "0.9.1",
    "--release-json",
    releaseJson,
    "--archive",
    prefixedArchive,
    "--output",
    join(tempRoot, "prefixed-output"),
  ]),
  "GitHub-style prefixed archive",
);

const optionLikeArchive = createArchive("option-like-release", () => {}, "--checkpoint=1");
assertFailure(
  run(prepare, [
    "--version",
    "0.9.1",
    "--release-json",
    releaseJson,
    "--archive",
    optionLikeArchive,
    "--output",
    join(tempRoot, "option-like-output"),
  ]),
  "option-like archive member",
  "option-like archive member",
);

for (const [name, fixture] of Object.entries(releaseFixtures)) {
  const fixturePath = join(tempRoot, `release-${name}.json`);
  writeJson(fixturePath, fixture);
  const result = run(prepare, [
    "--version",
    "0.9.1",
    "--release-json",
    fixturePath,
    "--archive",
    archive,
    "--output",
    join(tempRoot, `release-${name}-output`),
  ]);
  if (name === "immutableFinal") {
    assertSuccess(result, `${name} release fixture`);
  } else {
    assertFailure(result, `${name} release fixture`, "immutable final GitHub Release");
  }
}

assertFailure(
  run(prepare, ["--version", "v0.9.1", ...prepareArgs.slice(2, -1), join(tempRoot, "bad-version")]),
  "prefixed version",
  "exact X.Y.Z version",
);
assertFailure(run(prepare, prepareArgs), "existing output", "must not already exist");

const tamperedArchive = createArchive("tampered-source", (fixtureRoot) => {
  writeFileSync(join(fixtureRoot, "bin", "codex-profile"), "tampered\n");
});
assertFailure(
  run(prepare, [
    "--version",
    "0.9.1",
    "--release-json",
    releaseJson,
    "--archive",
    tamperedArchive,
    "--output",
    join(tempRoot, "tampered-source-output"),
  ]),
  "tampered source archive",
  "checksum",
);

const mismatchedMetadataArchive = createArchive("mismatched-metadata", (fixtureRoot) => {
  const path = join(fixtureRoot, "packaging", "aur", "PKGBUILD");
  writeFileSync(path, readFileSync(path, "utf8").replace("pkgver=0.9.1", "pkgver=0.9.2"));
});
assertFailure(
  run(prepare, [
    "--version",
    "0.9.1",
    "--release-json",
    releaseJson,
    "--archive",
    mismatchedMetadataArchive,
    "--output",
    join(tempRoot, "mismatched-metadata-output"),
  ]),
  "mismatched package metadata",
  "PKGBUILD version",
);

const fakeBin = join(tempRoot, "bin");
const commandLog = join(tempRoot, "commands.log");
mkdirSync(fakeBin);
function writeExecutable(name, body) {
  const path = join(fakeBin, name);
  writeFileSync(path, `#!/usr/bin/env bash\nset -euo pipefail\n${body}\n`);
  chmodSync(path, 0o755);
}

writeExecutable(
  "curl",
  `
output=
url=
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -o) output="$2"; shift 2 ;;
    http*) url="$1"; shift ;;
    *) shift ;;
  esac
done
case "$url" in
  */bin/codex-profile) cp "$AUR_TEST_SOURCE_ROOT/bin/codex-profile" "$output" ;;
  */LICENSE) cp "$AUR_TEST_SOURCE_ROOT/LICENSE" "$output" ;;
  */rpc/v5/info) cp "$AUR_TEST_RPC_JSON" "$output" ;;
  *) echo "unexpected curl URL: $url" >&2; exit 2 ;;
esac
`,
);
writeExecutable(
  "docker",
  `
printf 'docker %s\\n' "$*" >> "$AUR_TEST_COMMAND_LOG"
case "\${1:-}" in
  info) [[ "\${AUR_TEST_DOCKER_AVAILABLE:-1}" == 1 ]] ;;
  run) cat >/dev/null ;;
  *) exit 2 ;;
esac
`,
);
for (const command of ["git", "ssh"]) {
  writeExecutable(
    command,
    `printf '${command} %s\\n' "$*" >> "$AUR_TEST_COMMAND_LOG"; exit 97`,
  );
}

const rpcDir = join(fixturesDir, "aur-rpc");
const publicSourceRoot = join(tempRoot, "public-release-source");
mkdirSync(join(publicSourceRoot, "bin"), { recursive: true });
writeFileSync(join(publicSourceRoot, "bin", "codex-profile"), releaseSource("bin/codex-profile"));
writeFileSync(join(publicSourceRoot, "LICENSE"), releaseSource("LICENSE"));
const verifyEnv = {
  PATH: `${fakeBin}:${process.env.PATH}`,
  AUR_TEST_SOURCE_ROOT: publicSourceRoot,
  AUR_TEST_RPC_JSON: join(rpcDir, "exact-final-version.json"),
  AUR_TEST_COMMAND_LOG: commandLog,
};
const verifyArgs = [
  "--version",
  "0.9.1",
  "--checkout",
  prepared,
  "--expected",
  prepared,
  "--rpc-json",
  join(rpcDir, "exact-final-version.json"),
  "--rpc-state",
  "exact",
  "--container",
  "never",
];
writeFileSync(commandLog, "");
const verifyResult = run(verify, verifyArgs, verifyEnv);
assertSuccess(verifyResult, "prepared checkout verification");
assert.match(verifyResult.stdout, /Metadata, sources, checksums, aliases, and RPC state verified/);
assert.match(verifyResult.stdout, /Container validation: skipped by request/);
assert.equal(readFileSync(commandLog, "utf8"), "", "never mode must not call Docker, Git, or SSH");
assertSuccess(
  run(verify, [...verifyArgs.slice(0, 6), ...verifyArgs.slice(8)], verifyEnv),
  "fetched AUR RPC verification",
);

const unexpectedContent = join(tempRoot, "unexpected-content");
cpSync(prepared, unexpectedContent, { recursive: true });
writeFileSync(
  join(unexpectedContent, "PKGBUILD"),
  `${readFileSync(join(unexpectedContent, "PKGBUILD"), "utf8")}# unexpected\n`,
);
assertFailure(
  run(
    verify,
    verifyArgs.map((arg, index) => (index === 3 ? unexpectedContent : arg)),
    verifyEnv,
  ),
  "checkout with unexpected package content",
  "does not match expected immutable PKGBUILD",
);

const rpcScenarios = [
  ["unclaimed", "unclaimed", true],
  ["expected-owner", "owned", true],
  ["exact-final-version", "exact", true],
  ["unexpected-owner", "owned", false],
  ["expected-owner", "exact", false],
  ["unclaimed", "owned", false],
];
for (const [fixture, state, succeeds] of rpcScenarios) {
  const result = run(
    verify,
    [
      "--version",
      "0.9.1",
      "--checkout",
      prepared,
      "--rpc-json",
      join(rpcDir, `${fixture}.json`),
      "--rpc-state",
      state,
      "--container",
      "never",
    ],
    verifyEnv,
  );
  if (succeeds) assertSuccess(result, `${fixture} RPC fixture as ${state}`);
  else assertFailure(result, `${fixture} RPC fixture as ${state}`, "AUR RPC state");
}

const tamperedSourceRoot = join(tempRoot, "tampered-public-source");
mkdirSync(join(tamperedSourceRoot, "bin"), { recursive: true });
writeFileSync(join(tamperedSourceRoot, "LICENSE"), releaseSource("LICENSE"));
writeFileSync(join(tamperedSourceRoot, "bin", "codex-profile"), "tampered\n");
assertFailure(
  run(verify, verifyArgs, { ...verifyEnv, AUR_TEST_SOURCE_ROOT: tamperedSourceRoot }),
  "public source checksum mismatch",
  "checksum",
);

const brokenAlias = join(tempRoot, "broken-alias");
cpSync(prepared, brokenAlias, { recursive: true });
const brokenPkgbuild = join(brokenAlias, "PKGBUILD");
writeFileSync(
  brokenPkgbuild,
  readFileSync(brokenPkgbuild, "utf8").replace(
    "ln -s codex-profile \"$pkgdir/usr/bin/codex-profiles\"",
    "cp codex-profile \"$pkgdir/usr/bin/codex-profiles\"",
  ),
);
assertFailure(
  run(verify, verifyArgs.map((arg) => (arg === prepared ? brokenAlias : arg)), verifyEnv),
  "broken alias packaging",
  "relative codex-profiles alias",
);

writeFileSync(commandLog, "");
const autoResult = run(
  verify,
  verifyArgs.map((arg) => (arg === "never" ? "auto" : arg)),
  verifyEnv,
);
assertSuccess(autoResult, "automatic container verification");
assert.match(readFileSync(commandLog, "utf8"), /^docker info\ndocker run /m);
assert.match(autoResult.stdout, /Container validation: passed/);

writeFileSync(commandLog, "");
const unavailableAuto = run(
  verify,
  verifyArgs.map((arg) => (arg === "never" ? "auto" : arg)),
  { ...verifyEnv, AUR_TEST_DOCKER_AVAILABLE: "0" },
);
assertSuccess(unavailableAuto, "automatic verification without Docker daemon");
assert.match(unavailableAuto.stdout, /Docker unavailable; metadata verification only/);

const unavailableAlways = run(
  verify,
  verifyArgs.map((arg) => (arg === "never" ? "always" : arg)),
  { ...verifyEnv, AUR_TEST_DOCKER_AVAILABLE: "0" },
);
assertFailure(unavailableAlways, "required container without Docker daemon", "Docker is required");

for (const path of [prepare, verify]) {
  const source = readFileSync(path, "utf8");
  assert.doesNotMatch(source, /\bgit\s+[^\n]*\bpush\b/, `${path} must never push`);
  assert.doesNotMatch(source, /\bssh\s+[^\n]*aur\.archlinux\.org/, `${path} must not use AUR credentials`);
}
const verifySource = readFileSync(verify, "utf8");
assert.equal(
  (verifySource.match(/--connect-timeout 10 --max-time 60/g) ?? []).length,
  3,
  "every AUR verification request should have bounded timeouts",
);
for (const contract of [
  "makepkg --printsrcinfo",
  "makepkg --verifysource",
  "makepkg --cleanbuild",
  "namcap PKGBUILD",
  '[[ "$(readlink "$alias")" == codex-profile ]]',
]) {
  assert.ok(verifySource.includes(contract), `container verifier should contain ${contract}`);
}

const runbook = readFileSync(runbookPath, "utf8");
assert.ok(runbook.includes("scripts/aur/prepare.sh"), "runbook should call prepare.sh");
assert.ok(runbook.includes("scripts/aur/verify.sh"), "runbook should call verify.sh");
assert.ok(
  runbook.includes('--expected "$WORK_ROOT/staged"'),
  "public verification should bind the checkout to the prepared release files",
);
assert.ok(runbook.includes("git -C \"$AUR_DIR\" push origin master"), "manual push must stay explicit");
assert.ok(runbook.includes("official AUR homepage"), "host-key trust source must remain documented");
assert.ok(runbook.includes("never"), "credential and mutation boundaries must remain explicit");
assert.ok(!runbook.includes("--extract"), "runbook tests must not extract executable Markdown");
const bashBlocks = [...runbook.matchAll(/^```bash\s*\n([\s\S]*?)^```\s*$/gm)];
for (const [, block] of bashBlocks) {
  const lines = block.split("\n").filter((line) => line.trim());
  assert.ok(lines.length <= 15, `runbook Bash block has ${lines.length} nonblank lines`);
  const syntax = spawnSync("bash", ["-n"], { input: block, encoding: "utf8" });
  assert.equal(syntax.status, 0, `runbook Bash block has invalid syntax:\n${syntax.stderr}`);
}

console.log("AUR preparation, verification, and operator-runbook tests passed.");
