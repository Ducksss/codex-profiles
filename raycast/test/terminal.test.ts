import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { chmodSync, existsSync, mkdirSync, mkdtempSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, describe, test } from "node:test";
import {
  AUTOMATION_DENIED_MESSAGE,
  cliCommand,
  cliLaunchArguments,
  isAutomationDenied,
  loginCommand,
  loginLaunchArguments,
  shellQuote,
  TERMINAL_SCRIPT,
  TERMINAL_TIMEOUT_MESSAGE,
  terminalErrorMessage,
} from "../src/lib/terminal.ts";

const onMac = process.platform === "darwin";

describe("Terminal scripts", () => {
  test("pass the quoted command as one osascript argument", () => {
    const args = cliLaunchArguments("/opt/homebrew/bin/codex-profile", "work", "/Users/me/My App");
    assert.deepEqual(args, [
      "-e",
      TERMINAL_SCRIPT,
      "cd '/Users/me/My App' && exec /opt/homebrew/bin/codex-profile cli work",
    ]);
    assert.ok(
      !TERMINAL_SCRIPT.includes("My App") && !TERMINAL_SCRIPT.includes("work"),
      "values never enter script source",
    );
    assert.match(TERMINAL_SCRIPT, /tell application "Terminal"/);
    assert.match(TERMINAL_SCRIPT, /do script \(item 1 of argv\)/);
    assert.deepEqual(loginLaunchArguments("/bin/codex-profile", "work"), [
      "-e",
      TERMINAL_SCRIPT,
      "exec /bin/codex-profile login work",
    ]);
  });

  test("explain a denied Automation permission", () => {
    const denied = "0:120: execution error: Not authorized to send Apple events to Terminal. (-1743)";
    assert.equal(isAutomationDenied(denied), true);
    assert.equal(terminalErrorMessage(denied), AUTOMATION_DENIED_MESSAGE);
    assert.match(AUTOMATION_DENIED_MESSAGE, /Privacy & Security › Automation/);
    assert.equal(terminalErrorMessage("Terminal got an error."), "Terminal got an error.");
    assert.equal(terminalErrorMessage("  "), "Terminal could not be opened.");
  });

  test("explain a Terminal timeout as a possible Automation prompt", () => {
    assert.equal(terminalErrorMessage("", true), TERMINAL_TIMEOUT_MESSAGE);
    assert.equal(terminalErrorMessage("anything", true), TERMINAL_TIMEOUT_MESSAGE);
    assert.match(TERMINAL_TIMEOUT_MESSAGE, /control Terminal/);
    assert.match(TERMINAL_TIMEOUT_MESSAGE, /Privacy & Security › Automation/);
    assert.doesNotMatch(TERMINAL_TIMEOUT_MESSAGE, /codex-profile/);
  });
});

describe("shellQuote", () => {
  test("round-trips through /bin/sh", () => {
    for (const value of [
      "work",
      "/Users/me/My App",
      "it's",
      "$(touch nope)",
      'a"b',
      "",
      "semi;colon",
      "a\\b",
      "end\\",
    ]) {
      const output = execFileSync("/bin/sh", ["-c", `printf '%s' ${shellQuote(value)}`], { encoding: "utf8" });
      assert.equal(output, value);
    }
    assert.equal(shellQuote("work"), "work");
    assert.equal(shellQuote("it's"), "'it'\\''s'");
    assert.equal(shellQuote("a\\b"), "'a'\\\\'b'");
  });
});

describe("Terminal commands", () => {
  const root = mkdtempSync(join(tmpdir(), "codex-profile-raycast-"));
  after(() => rmSync(root, { recursive: true, force: true }));

  // A stand-in codex-profile that reports where it ran and what it received.
  const toolDirectory = join(root, "bin dir's");
  mkdirSync(toolDirectory);
  const tool = join(toolDirectory, "codex-profile");
  writeFileSync(tool, '#!/bin/sh\nprintf "%s\\n" "$PWD" "$@"\n');
  chmodSync(tool, 0o755);
  const workspaces = [
    join(root, 'My "quoted" project\'s $HOME'),
    // fish reads \' and \\ inside single quotes as escapes; neither may end the
    // quoted path or run the rest of it as a command.
    join(root, "a\\';touch PWNED;#"),
    join(root, "x\\\\y"),
    join(root, "trailing\\"),
  ];
  for (const workspace of workspaces) mkdirSync(workspace);
  const shells = ["/bin/sh", "/bin/zsh", "/bin/bash", "/opt/homebrew/bin/fish", "/usr/local/bin/fish"].filter((shell) =>
    existsSync(shell),
  );

  test("start codex-profile cli in the workspace in every shell", () => {
    for (const workspace of workspaces) {
      for (const shell of shells) {
        const output = execFileSync(shell, ["-c", cliCommand(tool, "work", workspace)], {
          encoding: "utf8",
          cwd: root,
        }).split("\n");
        assert.ok([workspace, realpathSync(workspace)].includes(output[0]), `${shell} changed into ${workspace}`);
        assert.deepEqual(output.slice(1, 3), ["cli", "work"], shell);
      }
    }
    assert.equal(existsSync(join(root, "PWNED")), false, "no shell ran text from the workspace path");
  });

  test("start codex-profile login", () => {
    for (const shell of shells) {
      const output = execFileSync(shell, ["-c", loginCommand(tool, "personal-2")], {
        encoding: "utf8",
        cwd: root,
      }).split("\n");
      assert.deepEqual(output.slice(1, 3), ["login", "personal-2"], shell);
    }
  });

  test("compile the Terminal script", { skip: onMac ? false : "needs macOS osacompile" }, () => {
    const compiled = join(root, "terminal.scpt");
    execFileSync("/usr/bin/osacompile", ["-o", compiled, "-e", TERMINAL_SCRIPT]);
    assert.equal(existsSync(compiled), true);
  });
});
