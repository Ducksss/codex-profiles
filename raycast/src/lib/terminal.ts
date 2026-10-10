// Terminal launches, copied from the menu-bar app (CLIClient.swift): values
// travel as osascript arguments and AppleScript's `quoted form of` builds the
// shell command, so nothing is interpolated into script source. Pure module.

export type TerminalAction = "cli" | "login";

/** AppleScript lines that set `launchCommand` from `argv`. */
const COMMAND_BUILDERS: Record<TerminalAction, string> = {
  cli: [
    "    set toolPath to item 1 of argv",
    "    set profileName to item 2 of argv",
    "    set workspacePath to item 3 of argv",
    '    set launchCommand to "cd " & quoted form of workspacePath & " && exec " & quoted form of toolPath & " cli " & quoted form of profileName',
  ].join("\n"),
  login: [
    "    set toolPath to item 1 of argv",
    "    set profileName to item 2 of argv",
    '    set launchCommand to "exec " & quoted form of toolPath & " login " & quoted form of profileName',
  ].join("\n"),
};

/** Opens a new Terminal window running the command. */
export function terminalScript(action: TerminalAction): string {
  return [
    "on run argv",
    COMMAND_BUILDERS[action],
    '    tell application "Terminal"',
    "        activate",
    "        do script launchCommand",
    "    end tell",
    "end run",
  ].join("\n");
}

/** Returns the command Terminal would run, without opening Terminal. Used by tests. */
export function terminalCommandScript(action: TerminalAction): string {
  return ["on run argv", COMMAND_BUILDERS[action], "    return launchCommand", "end run"].join("\n");
}

/** osascript arguments for `codex-profile cli <profile>` started in `workspace`. */
export function cliLaunchArguments(toolPath: string, profile: string, workspace: string): string[] {
  return ["-e", terminalScript("cli"), toolPath, profile, workspace];
}

/** osascript arguments for `codex-profile login <profile>`. */
export function loginLaunchArguments(toolPath: string, profile: string): string[] {
  return ["-e", terminalScript("login"), toolPath, profile];
}

/** osascript reports a denied Automation permission as error -1743. */
export function isAutomationDenied(message: string): boolean {
  return message.includes("(-1743)") || /not authori[sz]ed to send apple events/i.test(message);
}

export const AUTOMATION_DENIED_MESSAGE =
  "Raycast isn’t allowed to control Terminal. Turn it on in System Settings › Privacy & Security › Automation, then try again.";

export function terminalErrorMessage(message: string): string {
  return isAutomationDenied(message) ? AUTOMATION_DENIED_MESSAGE : message.trim() || "Terminal could not be opened.";
}

/** POSIX single quoting for a command the person copies into a shell. */
export function shellQuote(value: string): string {
  if (/^[A-Za-z0-9_./:=@%+-]+$/.test(value)) return value;
  return `'${value.replace(/'/g, `'\\''`)}'`;
}
