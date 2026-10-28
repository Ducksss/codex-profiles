import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { describe, test } from "node:test";
import {
  bindingProblem,
  displayPath,
  failureMessage,
  folderName,
  isUsableWorkspacePath,
  isValidProfileName,
  PROFILE_COLOR_HEX,
  parseAppearances,
  parseProfileList,
  parseWorkspaceList,
} from "../src/lib/profile.ts";

const CLI = new URL("../../bin/codex-profile", import.meta.url);

describe("isValidProfileName", () => {
  const samples = ["work", "default", "a.b-c_d", "1", "Work2", "", "-x", ".x", "_x", "a b", "a/b", "work\nx", "a;b"];

  test("accepts the names the CLI accepts", () => {
    assert.equal(isValidProfileName("work"), true);
    assert.equal(isValidProfileName("a.b-c_d"), true);
    assert.equal(isValidProfileName("-x"), false);
    assert.equal(isValidProfileName("work\n"), false);
    assert.equal(isValidProfileName("ü"), false);
  });

  test("uses the same pattern as bin/codex-profile", () => {
    const source = readFileSync(CLI, "utf8");
    assert.match(source, /\[\[ "\$profile" =~ \^\[A-Za-z0-9\]\[A-Za-z0-9\._-\]\*\$ \]\]/);
  });

  test("agrees with Bash for sample names", () => {
    const script = '[[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] && printf yes || printf no';
    for (const name of samples) {
      const bash = execFileSync("bash", ["-c", script, "_", name], { encoding: "utf8", env: { LC_ALL: "C" } });
      assert.equal(isValidProfileName(name), bash === "yes", `profile name ${JSON.stringify(name)}`);
    }
  });
});

describe("appearances", () => {
  test("maps each profile to its colour and skips anything unknown", () => {
    const colors = parseAppearances(
      JSON.stringify({
        profiles: [
          { profile: "work", color: "teal", symbol: "flask", automatic: false },
          { profile: "default", color: "graphite", symbol: "monogram", automatic: true },
          { profile: "client", color: "crimson", symbol: "monogram", automatic: false },
          { profile: "bad name", color: "teal", symbol: "monogram", automatic: false },
          { profile: "proto", color: "constructor", symbol: "monogram", automatic: false },
          "not an object",
        ],
      }),
    );
    assert.deepEqual(
      [...colors],
      [
        ["work", "#0B7A84"],
        ["default", "#737378"],
      ],
    );
  });

  test("rejects output that is not an appearance list", () => {
    assert.throws(() => parseAppearances("work: teal flask"), /not JSON/);
    assert.throws(() => parseAppearances("{}"), /without a profiles list/);
  });

  test("offers exactly the CLI's colours", () => {
    const source = readFileSync(CLI, "utf8");
    const match = source.match(/^PROFILE_COLORS="([a-z ]+)"$/m);
    assert.ok(match, "bin/codex-profile defines PROFILE_COLORS");
    assert.deepEqual(Object.keys(PROFILE_COLOR_HEX).sort(), match[1].split(" ").sort());
  });

  test("uses the menu-bar app's tile colours", () => {
    const models = readFileSync(
      new URL("../../macos/CodexProfilesMenu/Sources/CodexProfilesMenu/WorkspaceModels.swift", import.meta.url),
      "utf8",
    );
    const hex = (value: string) =>
      Math.round(Number(value) * 255)
        .toString(16)
        .toUpperCase()
        .padStart(2, "0");
    let checked = 0;
    for (const [, name, red, green, blue] of models.matchAll(/case \.(\w+): \(([\d.]+), ([\d.]+), ([\d.]+)\)/g)) {
      assert.equal(PROFILE_COLOR_HEX[name], `#${hex(red)}${hex(green)}${hex(blue)}`, name);
      checked += 1;
    }
    assert.equal(checked, Object.keys(PROFILE_COLOR_HEX).length);
  });
});

describe("paths", () => {
  test("shortens paths inside the home directory", () => {
    assert.equal(displayPath("/Users/me/Dev/app", "/Users/me"), "~/Dev/app");
    assert.equal(displayPath("/Users/me", "/Users/me/"), "~");
    assert.equal(displayPath("/Users/meet/app", "/Users/me"), "/Users/meet/app");
    assert.equal(displayPath("/opt/app", ""), "/opt/app");
  });

  test("names folders by their last component", () => {
    assert.equal(folderName("/Users/me/Dev/app"), "app");
    assert.equal(folderName("/Users/me/Dev/app/"), "app");
    assert.equal(folderName("/"), "/");
  });

  test("accepts only absolute paths without control characters", () => {
    assert.equal(isUsableWorkspacePath("/Users/me/My Project"), true);
    assert.equal(isUsableWorkspacePath("relative/path"), false);
    assert.equal(isUsableWorkspacePath("/tmp/a\nb"), false);
  });
});

describe("CLI output", () => {
  test("reads profile names from list", () => {
    assert.deepEqual(parseProfileList("default\nwork\n\n  personal  \nwork\nnot a name\n"), [
      "default",
      "work",
      "personal",
    ]);
  });

  test("reads workspace bindings and skips malformed rows", () => {
    const list = parseWorkspaceList(
      JSON.stringify({
        guard_mode: "strict",
        bindings: [
          { path: "/Users/me/app", profile: "work", path_exists: true, profile_exists: true },
          { path: "/Users/me/gone", profile: "old", path_exists: false, profile_exists: false },
          { path: "relative", profile: "work", path_exists: true, profile_exists: true },
          { path: "/Users/me/x", profile: "-bad", path_exists: true, profile_exists: true },
          "junk",
        ],
      }),
    );
    assert.equal(list.guardMode, "strict");
    assert.deepEqual(
      list.bindings.map((binding) => [binding.path, bindingProblem(binding)]),
      [
        ["/Users/me/app", undefined],
        ["/Users/me/gone", "Folder and profile are missing"],
      ],
    );
    assert.equal(
      bindingProblem({ path: "/a", profile: "work", pathExists: false, profileExists: true }),
      "Folder is missing",
    );
    assert.equal(
      bindingProblem({ path: "/a", profile: "work", pathExists: true, profileExists: false }),
      "Profile work is missing",
    );
    assert.throws(() => parseWorkspaceList("nope"), /not JSON/);
    assert.throws(() => parseWorkspaceList("{}"), /bindings/);
  });

  test("explains failures with the CLI's own message", () => {
    assert.equal(
      failureMessage({
        stdout: "",
        stderr:
          "Warning: workspace '/a' is bound to profile 'x'; selected profile is 'y'.\nError: Profile 'y' is not initialized.\n",
        code: 1,
      }),
      "Profile 'y' is not initialized.",
    );
    assert.equal(failureMessage({ stdout: "", stderr: "plain problem\n", code: 1 }), "plain problem");
    assert.equal(failureMessage({ stdout: "only stdout", stderr: "", code: 1 }), "only stdout");
    assert.equal(failureMessage({ stdout: "", stderr: "", code: 3 }), "codex-profile exited with status 3.");
    assert.equal(
      failureMessage({ stdout: "", stderr: "", code: null, timedOut: true }),
      "codex-profile did not finish in time.",
    );
  });
});
