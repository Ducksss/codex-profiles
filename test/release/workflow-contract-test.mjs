#!/usr/bin/env node

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const workflow = readFileSync(".github/workflows/release.yml", "utf8");

function stepBlock(name) {
  const marker = `      - name: ${name}\n`;
  const start = workflow.indexOf(marker);
  assert.notEqual(start, -1, `release workflow should define the ${name} step`);
  const next = workflow.indexOf("\n      - name: ", start + marker.length);
  return workflow.slice(start, next === -1 ? workflow.length : next);
}

function jobBlock(name) {
  const jobsStart = workflow.indexOf("jobs:\n");
  assert.notEqual(jobsStart, -1, "release workflow should define jobs");
  const marker = `  ${name}:\n`;
  const start = workflow.indexOf(marker, jobsStart);
  assert.notEqual(start, -1, `release workflow should define the ${name} job`);
  const remainder = workflow.slice(start + marker.length);
  const next = remainder.search(/^  [A-Za-z0-9_-]+:\n/m);
  return workflow.slice(start, next === -1 ? workflow.length : start + marker.length + next);
}

const requiredLiterals = [
  "workflow_dispatch:",
  "version:",
  "dry_run:",
  "desktop_smoke_attestation:",
  "skip_homebrew:",
  "group: release",
  "cancel-in-progress: false",
  "needs: verify",
  "make check",
  "if: ${{ ! inputs.dry_run }}",
  "scripts/release/verify-source.sh",
  "scripts/release/preflight.sh",
  "scripts/release/verify-state.sh",
  "scripts/release/publish-tag.sh",
  "scripts/release/verify-distribution.sh tagged-aur",
  "scripts/release/publish-npm.sh publish",
  "scripts/release/publish-npm.sh verify",
  "scripts/release/publish-github.sh publish",
  "scripts/release/publish-github.sh verify",
  "scripts/release/verify-distribution.sh standalone",
  "scripts/release/update-homebrew.sh",
  "scripts/release/deploy-pages.sh",
];

for (const literal of requiredLiterals) {
  assert.ok(workflow.includes(literal), `release workflow should contain ${literal}`);
}

const verifyJob = jobBlock("verify");
const publishJob = jobBlock("publish");
assert.ok(verifyJob.includes("    permissions:\n      contents: read"));
for (const permission of ["contents: write", "id-token: write", "actions: write"]) {
  assert.ok(!verifyJob.includes(permission), `verify job must not grant ${permission}`);
  assert.ok(publishJob.includes(`      ${permission}`), `publish job should grant ${permission}`);
}

// A dry run must prove a live run could authenticate, so the always-running
// verify job preflights the publish credentials too.
const credentialPreflight = stepBlock("Preflight publish credentials");
assert.ok(
  verifyJob.includes("      - name: Preflight publish credentials"),
  "verify job should preflight publish credentials so dry runs catch missing secrets",
);
for (const literal of ["NPM_TOKEN: ${{ secrets.NPM_TOKEN }}", "TAP_TOKEN: ${{ secrets.TAP_TOKEN }}"]) {
  assert.ok(credentialPreflight.includes(literal), `credential preflight should read ${literal}`);
}
assert.ok(
  !credentialPreflight.includes("if: ${{ ! inputs.dry_run }}"),
  "credential preflight must also run for dry runs",
);
// Job-level secrets would be readable by `make check`, which runs the whole
// test suite. Keep them scoped to the preflight step.
const verifyJobConfig = verifyJob.slice(0, verifyJob.indexOf("    steps:"));
for (const secret of ["NPM_TOKEN", "TAP_TOKEN"]) {
  assert.ok(
    !verifyJobConfig.includes(secret),
    `verify job must not expose ${secret} to every step; scope it to the preflight step`,
  );
}
for (const secret of ["NPM_TOKEN", "TAP_TOKEN"]) {
  assert.ok(
    !stepBlock("Run full verification").includes(secret),
    `full verification must not receive ${secret}`,
  );
}

const publishSteps = [
  "Validate live release source",
  "Preflight release credential identities",
  "Revalidate live release state",
  "Create and push tag",
  "Verify tagged AUR release files",
  "Publish to npm",
  "Verify published npm package",
  "Create GitHub Release",
  "Verify GitHub Release",
  "Verify public standalone installer",
  "Update Homebrew tap",
  "Deploy and verify release documentation",
  "Release summary",
];
let previousStep = -1;
for (const name of publishSteps) {
  const position = workflow.indexOf(`      - name: ${name}\n`);
  assert.ok(position > previousStep, `${name} should preserve publication order`);
  previousStep = position;
}

for (const [name, literals] of Object.entries({
  "Run full verification": ["make check", "git diff --exit-code", "git status --porcelain=v1"],
  "Preflight release credential identities": ["NPM_TOKEN: ${{ secrets.NPM_TOKEN }}", "TAP_TOKEN: ${{ secrets.TAP_TOKEN }}"],
  "Revalidate live release state": ["TAG: ${{ needs.verify.outputs.tag }}", "VERIFIED_SHA: ${{ needs.verify.outputs.commit }}"],
  "Create and push tag": ["TAG_EXISTS: ${{ steps.live.outputs.tag_exists }}"],
  "Publish to npm": ["NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}", "V: ${{ needs.verify.outputs.version }}"],
  "Create GitHub Release": ["GH_TOKEN: ${{ github.token }}", "TAG: ${{ needs.verify.outputs.tag }}"],
  "Update Homebrew tap": ["TAP_TOKEN: ${{ secrets.TAP_TOKEN }}", "V: ${{ needs.verify.outputs.version }}"],
  "Deploy and verify release documentation": ["GH_TOKEN: ${{ github.token }}", "V: ${{ needs.verify.outputs.version }}"],
})) {
  const block = stepBlock(name);
  for (const literal of literals) {
    assert.ok(block.includes(literal), `${name} should contain ${literal}`);
  }
}

for (const name of publishSteps.slice(1, -1)) {
  assert.match(
    stepBlock(name),
    /if: \$\{\{ ! inputs\.dry_run( &&[^}]*)? \}\}/,
    `${name} should remain live-only`,
  );
}

// skip_homebrew lets a release publish npm, the GitHub Release, and Pages while
// leaving the tap on its current version. Both preflights must learn about it,
// or a skipped release would still demand tap credentials.
for (const name of ["Preflight publish credentials", "Preflight release credential identities"]) {
  assert.ok(
    stepBlock(name).includes("SKIP_HOMEBREW: ${{ inputs.skip_homebrew }}"),
    `${name} should receive skip_homebrew`,
  );
}
assert.ok(
  stepBlock("Update Homebrew tap").includes("if: ${{ ! inputs.dry_run && ! inputs.skip_homebrew }}"),
  "the tap update should be skipped when skip_homebrew is set",
);
for (const name of ["Verification summary", "Release summary"]) {
  assert.ok(
    stepBlock(name).includes("SKIP_HOMEBREW: ${{ inputs.skip_homebrew }}"),
    `${name} should report whether the tap was skipped`,
  );
}

const verificationBlock = stepBlock("Run full verification");
for (const duplicate of ["make test", "make lint", "make npm-package-test", "bash test/"]) {
  assert.ok(!verificationBlock.includes(duplicate), `full verification should not duplicate ${duplicate}`);
}

for (const script of [
  "verify-source.sh",
  "preflight.sh",
  "verify-state.sh",
  "publish-tag.sh",
  "verify-distribution.sh",
  "publish-npm.sh",
  "publish-github.sh",
  "update-homebrew.sh",
  "deploy-pages.sh",
]) {
  const matches = workflow.match(new RegExp(`scripts/release/${script.replace(".", "\\.")}`, "g")) ?? [];
  const expected = ["verify-distribution.sh", "publish-npm.sh", "publish-github.sh", "preflight.sh"].includes(script)
    ? 2
    : 1;
  assert.equal(matches.length, expected, `${script} should be wired ${expected} time(s)`);
}

for (const script of [
  "verify-source.sh",
  "preflight.sh",
  "verify-state.sh",
  "publish-tag.sh",
  "verify-distribution.sh",
  "publish-npm.sh",
  "publish-github.sh",
  "update-homebrew.sh",
  "deploy-pages.sh",
]) {
  const source = readFileSync(`scripts/release/${script}`, "utf8");
  assert.match(
    source,
    /^#!\/usr\/bin\/env bash\n\nset -euo pipefail\n/,
    `${script} should enable strict mode before setup`,
  );
}

const prohibitedInlineCommands = [
  "npm publish",
  "gh release create",
  "git push origin",
  "scripts/update-homebrew-formula",
  "gh workflow run pages.yml",
];
for (const command of prohibitedInlineCommands) {
  assert.ok(!workflow.includes(command), `release workflow should not inline ${command}`);
}

const runBlocks = [...workflow.matchAll(/^        run: \|\n((?:^          .*\n|^\n)*)/gm)];
for (const match of runBlocks) {
  const nonblankLines = match[1].split("\n").filter((line) => line.trim()).length;
  assert.ok(nonblankLines <= 20, `workflow run block has ${nonblankLines} nonblank lines`);
}

const actionLines = workflow.match(/^\s*uses: .*$/gm) ?? [];
assert.ok(actionLines.length > 0, "release workflow should use pinned actions");
for (const line of actionLines) {
  assert.match(line, /@[0-9a-f]{40}\s+# v[0-9]+$/, `action should be pinned: ${line.trim()}`);
}

console.log("Release workflow wiring tests passed.");
