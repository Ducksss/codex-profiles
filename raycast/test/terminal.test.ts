import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { chmodSync, mkdirSync, mkdtempSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, describe, test } from "node:test";
import {
  AUTOMATION_DENIED_MESSAGE,
  cliLaunchArguments,
  isAutomationDenied,
  loginLaunchArguments,
  shellQuote,
  terminalCommandScript,
  terminalErrorMessage,
  terminalScript,
} from "../src/lib/terminal.ts";

const onMac = process.platform === "darwin";

describe("Terminal scripts", () => {
  test("pass every value as an osascript argument", () => {
    const args = cliLaunchArguments("/opt/homebrew/bin/codex-profile", "work", "/Users/me/My App");
    assert.deepEqual(args.slice(2), ["/opt/homebrew/bin/codex-profile", "work", "/Users/me/My App"]);
    assert.equal(args[0], "-e");
    assert.ok(!args[1].includes("My App") && !args[1].includes('work"'), "values never enter script source");
    assert.match(args[1], /tell application "Terminal"/);
    assert.match(args[1], /do script launchCommand/);
    assert.equal((terminalScript("cli").match(/quoted form of/g) ?? []).length, 3);
    assert.deepEqual(loginLaunchArguments("/bin/codex-profile", "work").slice(2), ["/bin/codex-profile", "work"]);
    assert.match(terminalScript("login"), / login " & quoted form of profileName/);
  });

  test("explain a denied Automation permission", () => {
    const denied = "0:120: execution error: Not authorized to send Apple events to Terminal. (-1743)";
    assert.equal(isAutomationDenied(denied), true);
    assert.equal(terminalErrorMessage(denied), AUTOMATION_DENIED_MESSAGE);
    assert.match(AUTOMATION_DENIED_MESSAGE, /Privacy & Security › Automation/);
    assert.equal(terminalErrorMessage("Terminal got an error."), "Terminal got an error.");
    assert.equal(terminalErrorMessage("  "), "Terminal could not be opened.");
  });
});

describe("shellQuote", () => {
  test("round-trips through /bin/sh", () => {
    for (const value of ["work", "/Users/me/My App", "it's", "$(touch nope)", 'a"b', "", "semi;colon"]) {
      const output = execFileSync("/bin/sh", ["-c", `printf '%s' ${shellQuote(value)}`], { encoding: "utf8" });
      assert.equal(output, value);
    }
    assert.equal(shellQuote("work"), "work");
    assert.equal(shellQuote("it's"), "'it'\\''s'");
  });
});

describe("Terminal commands built by AppleScript", { skip: onMac ? false : "needs macOS osascript" }, () => {
  const root = mkdtempSync(join(tmpdir(), "codex-profile-raycast-"));
  after(() => rmSync(root, { recursive: true, force: true }));

  // A stand-in codex-profile that reports where it ran and what it received.
  const toolDirectory = join(root, "bin dir's");
  mkdirSync(toolDirectory);
  const tool = join(toolDirectory, "codex-profile");
  writeFileSync(tool, '#!/bin/sh\nprintf "%s\\n" "$PWD" "$@"\n');
  chmodSync(tool, 0o755);
  const workspace = join(root, 'My "quoted" project\'s $HOME');
  mkdirSync(workspace);

  const commandFor = (action: "cli" | "login", args: string[]) =>
    execFileSync("/usr/bin/osascript", ["-e", terminalCommandScript(action), ...args], { encoding: "utf8" }).trim();

  test("start codex-profile cli in the workspace", () => {
    const command = commandFor("cli", [tool, "work", workspace]);
    for (const shell of ["/bin/sh", "/bin/zsh", "/bin/bash"]) {
      const output = execFileSync(shell, ["-c", command], { encoding: "utf8", cwd: root }).split("\n");
      assert.ok([workspace, realpathSync(workspace)].includes(output[0]), `${shell} changed into the workspace`);
      assert.deepEqual(output.slice(1, 3), ["cli", "work"], shell);
    }
  });

  test("start codex-profile login", () => {
    const command = commandFor("login", [tool, "personal-2"]);
    const output = execFileSync("/bin/sh", ["-c", command], { encoding: "utf8", cwd: root }).split("\n");
    assert.deepEqual(output.slice(1, 3), ["login", "personal-2"]);
  });

  test("match the script that drives Terminal", () => {
    for (const action of ["cli", "login"] as const) {
      const prelude = terminalCommandScript(action).split("\n    return launchCommand")[0];
      assert.ok(terminalScript(action).startsWith(prelude), `${action} scripts share their command builder`);
    }
  });
});
