// Every profile operation goes through the codex-profile CLI. This module
// never reads ~/.codex* files, auth.json, tokens or cookies.

import { Cache, getPreferenceValues } from "@raycast/api";
import { execFile } from "node:child_process";
import { accessSync, constants, readdirSync, statSync } from "node:fs";
import { homedir, userInfo } from "node:os";
import { dirname } from "node:path";
import { augmentedPath, cliEnvironment, executableCandidates, expandHome, lastAbsolutePath } from "./lib/discovery";
import {
  failureMessage,
  isUsableWorkspacePath,
  isValidProfileName,
  parseProfileList,
  parseWorkspaceList,
  type CommandOutput,
  type WorkspaceList,
} from "./lib/profile";
import { cliLaunchArguments, loginLaunchArguments, terminalErrorMessage } from "./lib/terminal";
import { interpretUsageOutput, isSnapshotFresh, type UsageSnapshot } from "./lib/usage";

export const INSTALL_URL = "https://github.com/Ducksss/codex-profiles#install";
export const SITE_URL = "https://ducksss.github.io/codex-profiles/";
export const UPGRADE_URL = "https://github.com/Ducksss/codex-profiles/blob/main/USAGE.md#upgrade-a-source-installation";

interface Preferences {
  codexProfilePath?: string;
}

export type CliResolution =
  { kind: "found"; path: string } | { kind: "invalid-preference"; path: string } | { kind: "missing" };

interface RunResult extends CommandOutput {
  timedOut: boolean;
}

const HOME = homedir();

function isExecutableFile(path: string): boolean {
  try {
    if (!statSync(path).isFile()) return false;
    accessSync(path, constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

function isDirectory(path: string): boolean {
  try {
    return statSync(path).isDirectory();
  } catch {
    return false;
  }
}

function nvmVersions(): string[] {
  try {
    return readdirSync(`${HOME}/.nvm/versions/node`);
  } catch {
    return [];
  }
}

function loginShell(): string {
  try {
    const shell = userInfo().shell;
    if (shell && shell.startsWith("/")) return shell;
  } catch {
    // Fall through to the macOS default.
  }
  return process.env.SHELL?.startsWith("/") ? process.env.SHELL : "/bin/zsh";
}

/** Runs a program with an argument array (no shell) and never rejects on a non-zero exit. */
function run(
  file: string,
  args: string[],
  options: { env?: NodeJS.ProcessEnv; timeout?: number; signal?: AbortSignal } = {},
): Promise<RunResult> {
  return new Promise((resolve, reject) => {
    const child = execFile(
      file,
      args,
      {
        // Profile-only launches must not inherit a project binding from
        // wherever Raycast started the extension.
        cwd: HOME,
        env: options.env,
        timeout: options.timeout ?? 30_000,
        signal: options.signal,
        maxBuffer: 8 * 1024 * 1024,
        encoding: "utf8",
      },
      (error, stdout, stderr) => {
        if (!error) {
          resolve({ stdout, stderr, code: 0, timedOut: false });
          return;
        }
        if (error.name === "AbortError") {
          reject(error);
          return;
        }
        if (typeof error.code === "string") {
          // Spawn failures such as ENOENT or EACCES.
          reject(new Error(`Could not run ${file}: ${error.message}`));
          return;
        }
        resolve({
          stdout,
          stderr,
          code: typeof error.code === "number" ? error.code : null,
          timedOut: error.killed === true && error.signal === "SIGTERM" && !options.signal?.aborted,
        });
      },
    );
    // Nothing is ever sent on stdin; closing it keeps every call non-interactive.
    child.stdin?.end();
  });
}

let resolved: Promise<CliResolution> | undefined;

async function findWithLoginShell(): Promise<string | undefined> {
  try {
    const result = await run(loginShell(), ["-l", "-c", "command -v codex-profile"], {
      env: { ...process.env, HOME },
      timeout: 5_000,
    });
    const path = result.code === 0 ? lastAbsolutePath(result.stdout) : undefined;
    return path && isExecutableFile(path) ? path : undefined;
  } catch {
    return undefined;
  }
}

/** Finds codex-profile: the preference, then standard locations, then a login shell. */
export function resolveCli(): Promise<CliResolution> {
  resolved ??= (async (): Promise<CliResolution> => {
    const preference = getPreferenceValues<Preferences>().codexProfilePath?.trim();
    if (preference) {
      const path = expandHome(preference, HOME);
      return isExecutableFile(path) ? { kind: "found", path } : { kind: "invalid-preference", path };
    }
    for (const candidate of executableCandidates(HOME, nvmVersions(), isDirectory)) {
      if (isExecutableFile(candidate)) return { kind: "found", path: candidate };
    }
    const fromShell = await findWithLoginShell();
    return fromShell ? { kind: "found", path: fromShell } : { kind: "missing" };
  })();
  // A failed lookup is retried next time instead of being remembered.
  resolved.then(
    (result) => {
      if (result.kind !== "found") resolved = undefined;
    },
    () => {
      resolved = undefined;
    },
  );
  return resolved;
}

function environmentFor(cli: string): NodeJS.ProcessEnv {
  const path = augmentedPath({
    home: HOME,
    currentPath: process.env.PATH,
    executableDirectory: dirname(cli),
    nvmVersions: nvmVersions(),
    exists: isDirectory,
  });
  return cliEnvironment(process.env, path, HOME) as NodeJS.ProcessEnv;
}

function runCli(cli: string, args: string[], options: { timeout?: number; signal?: AbortSignal } = {}) {
  return run(cli, args, { ...options, env: environmentFor(cli) });
}

function assertProfile(profile: string): void {
  if (!isValidProfileName(profile)) {
    throw new Error(`“${profile}” is not a valid profile name.`);
  }
}

function assertWorkspace(path: string): void {
  if (!isUsableWorkspacePath(path)) {
    throw new Error(`“${path}” is not an absolute folder path.`);
  }
}

export interface ProfileEntry {
  name: string;
  /** CODEX_HOME, as printed by `codex-profile path`. */
  home?: string;
}

/** `codex-profile list`, then `codex-profile path <name>` for each initialized profile. */
export async function loadProfiles(cli: string, signal?: AbortSignal): Promise<ProfileEntry[]> {
  const result = await runCli(cli, ["list"], { signal });
  if (result.code !== 0) throw new Error(failureMessage(result));
  const names = parseProfileList(result.stdout);
  return Promise.all(
    names.map(async (name): Promise<ProfileEntry> => {
      const path = await runCli(cli, ["path", name], { signal });
      const home = path.code === 0 ? path.stdout.trim().split(/\r?\n/).pop() : undefined;
      return { name, home: home && home.startsWith("/") ? home : undefined };
    }),
  );
}

/** `codex-profile workspace list --json`. */
export async function loadWorkspaces(cli: string, signal?: AbortSignal): Promise<WorkspaceList> {
  const result = await runCli(cli, ["workspace", "list", "--json"], { signal });
  if (result.code !== 0) throw new Error(failureMessage(result));
  return parseWorkspaceList(result.stdout);
}

const usageCache = new Cache({ namespace: "codex-usage" });
const USAGE_SNAPSHOT_KEY = "snapshot-v1";

function cachedUsage(): UsageSnapshot | undefined {
  const raw = usageCache.get(USAGE_SNAPSHOT_KEY);
  if (!raw) return undefined;
  try {
    return JSON.parse(raw) as UsageSnapshot;
  } catch {
    return undefined;
  }
}

/**
 * `codex-profile usage --json`. Readings are shared by both commands and
 * reused for a minute; `force` (the Refresh action) always reads again.
 */
export async function loadUsage(
  cli: string,
  options: { force?: boolean; signal?: AbortSignal } = {},
): Promise<UsageSnapshot> {
  const cached = cachedUsage();
  if (!options.force && cached && cached.cliPath === cli && isSnapshotFresh(cached, Date.now())) {
    return cached;
  }
  const result = await runCli(cli, ["usage", "--json"], { timeout: 90_000, signal: options.signal });
  const snapshot: UsageSnapshot = { checkedAt: Date.now(), cliPath: cli, outcome: interpretUsageOutput(result) };
  usageCache.set(USAGE_SNAPSHOT_KEY, JSON.stringify(snapshot));
  return snapshot;
}

/** `codex-profile app <profile> [workspace]`: the profile's ChatGPT window. */
export async function openInChatGPT(cli: string, profile: string, workspace?: string): Promise<void> {
  assertProfile(profile);
  if (workspace !== undefined) assertWorkspace(workspace);
  const result = await runCli(cli, ["app", profile, ...(workspace === undefined ? [] : [workspace])]);
  if (result.code !== 0) throw new Error(failureMessage(result));
}

async function runTerminal(args: string[]): Promise<void> {
  const result = await run("/usr/bin/osascript", args, { timeout: 30_000 });
  if (result.code !== 0) throw new Error(terminalErrorMessage(failureMessage(result)));
}

/** Terminal running `codex-profile cli <profile>` in the workspace, or the home directory. */
export async function openInTerminal(cli: string, profile: string, workspace?: string): Promise<void> {
  assertProfile(profile);
  if (workspace !== undefined) assertWorkspace(workspace);
  await runTerminal(cliLaunchArguments(cli, profile, workspace ?? HOME));
}

/** Terminal running `codex-profile login <profile>`. */
export async function signInInTerminal(cli: string, profile: string): Promise<void> {
  assertProfile(profile);
  await runTerminal(loginLaunchArguments(cli, profile));
}

export { HOME };
