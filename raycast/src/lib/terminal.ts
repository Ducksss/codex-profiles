// Terminal launches, copied from the menu-bar app (CLIClient.swift): the shell
// command is quoted here and travels as one osascript argument, so nothing is
// interpolated into script source. AppleScript's `quoted form of` is not used
// because fish reads backslashes inside single quotes differently. Pure module.

/** Opens a new Terminal window running the command in `argv`. */
export const TERMINAL_SCRIPT = [
  "on run argv",
  '    tell application "Terminal"',
  "        activate",
  "        do script (item 1 of argv)",
  "    end tell",
  "end run",
].join("\n");

/** The shell command that starts `codex-profile cli <profile>` in `workspace`. */
export function cliCommand(toolPath: string, profile: string, workspace: string): string {
  return `cd ${shellQuote(workspace)} && exec ${shellQuote(toolPath)} cli ${shellQuote(profile)}`;
}

/** The shell command that starts `codex-profile login <profile>`. */
export function loginCommand(toolPath: string, profile: string): string {
  return `exec ${shellQuote(toolPath)} login ${shellQuote(profile)}`;
}

/** osascript arguments for `codex-profile cli <profile>` started in `workspace`. */
export function cliLaunchArguments(toolPath: string, profile: string, workspace: string): string[] {
  return ["-e", TERMINAL_SCRIPT, cliCommand(toolPath, profile, workspace)];
}

/** osascript arguments for `codex-profile login <profile>`. */
export function loginLaunchArguments(toolPath: string, profile: string): string[] {
  return ["-e", TERMINAL_SCRIPT, loginCommand(toolPath, profile)];
}

/** osascript reports a denied Automation permission as error -1743. */
export function isAutomationDenied(message: string): boolean {
  return message.includes("(-1743)") || /not authori[sz]ed to send apple events/i.test(message);
}

export const AUTOMATION_DENIED_MESSAGE =
  "Raycast isn’t allowed to control Terminal. Turn it on in System Settings › Privacy & Security › Automation, then try again.";

/** osascript waits while macOS asks whether Raycast may control Terminal. */
export const TERMINAL_TIMEOUT_MESSAGE =
  "Terminal didn’t respond in time. If macOS asked whether Raycast may control Terminal, allow it there or in System Settings › Privacy & Security › Automation, then try again.";

/** The message for a failed osascript run; a timeout gets its own explanation. */
export function terminalErrorMessage(message: string, timedOut = false): string {
  if (timedOut) return TERMINAL_TIMEOUT_MESSAGE;
  return isAutomationDenied(message) ? AUTOMATION_DENIED_MESSAGE : message.trim() || "Terminal could not be opened.";
}

/**
 * Single quoting that sh, bash, zsh and fish all read the same way. Quotes and
 * backslashes are written outside the quotes, because fish treats `\'` and
 * `\\` inside single quotes as escapes.
 */
export function shellQuote(value: string): string {
  if (/^[A-Za-z0-9_./:=@%+-]+$/.test(value)) return value;
  return `'${value.replace(/['\\]/g, (character) => `'\\${character}'`)}'`;
}
