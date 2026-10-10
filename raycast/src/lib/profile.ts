// Pure helpers shared by every command. No Raycast or Node imports, so the
// test suite can load this file directly with `node --test`.

/** The same rule as `is_valid_profile_name` in bin/codex-profile. */
const PROFILE_NAME = /^[A-Za-z0-9][A-Za-z0-9._-]*$/;

export function isValidProfileName(name: string): boolean {
  return PROFILE_NAME.test(name);
}

/** Workspace paths come from the CLI; still refuse anything it would reject. */
export function isUsableWorkspacePath(path: string): boolean {
  // eslint-disable-next-line no-control-regex
  return path.startsWith("/") && !/[\u0000-\u001f\u007f]/.test(path);
}

/** "/Users/me/Dev/app" -> "~/Dev/app" when it is inside the home directory. */
export function displayPath(path: string, home: string): string {
  const trimmedHome = home.replace(/\/+$/, "");
  if (!trimmedHome) return path;
  if (path === trimmedHome) return "~";
  if (path.startsWith(`${trimmedHome}/`)) return `~${path.slice(trimmedHome.length)}`;
  return path;
}

/** The last path component, or the path itself for "/". */
export function folderName(path: string): string {
  const parts = path.split("/").filter(Boolean);
  return parts.length > 0 ? parts[parts.length - 1] : path;
}

/** Profile names from `codex-profile list`, one per line; anything else is ignored. */
export function parseProfileList(stdout: string): string[] {
  const seen = new Set<string>();
  for (const line of stdout.split(/\r?\n/)) {
    const name = line.trim();
    if (isValidProfileName(name)) seen.add(name);
  }
  return [...seen];
}

export interface WorkspaceBinding {
  path: string;
  profile: string;
  pathExists: boolean;
  profileExists: boolean;
}

export interface WorkspaceList {
  guardMode: string;
  bindings: WorkspaceBinding[];
}

/** Parses `codex-profile workspace list --json`. Malformed rows are skipped. */
export function parseWorkspaceList(stdout: string): WorkspaceList {
  let value: unknown;
  try {
    value = JSON.parse(stdout);
  } catch {
    throw new Error("codex-profile workspace list returned output that is not JSON.");
  }
  if (!isRecord(value) || !Array.isArray(value.bindings)) {
    throw new Error("codex-profile workspace list returned JSON without a bindings list.");
  }
  const bindings: WorkspaceBinding[] = [];
  for (const row of value.bindings) {
    if (!isRecord(row)) continue;
    const { path, profile } = row;
    if (typeof path !== "string" || typeof profile !== "string") continue;
    if (!isUsableWorkspacePath(path) || !isValidProfileName(profile)) continue;
    bindings.push({
      path,
      profile,
      pathExists: row.path_exists === true,
      profileExists: row.profile_exists === true,
    });
  }
  return { guardMode: typeof value.guard_mode === "string" ? value.guard_mode : "warn", bindings };
}

/** Why a binding cannot open, or undefined when it can. */
export function bindingProblem(binding: WorkspaceBinding): string | undefined {
  if (!binding.pathExists && !binding.profileExists) return "Folder and profile are missing";
  if (!binding.pathExists) return "Folder is missing";
  if (!binding.profileExists) return `Profile ${binding.profile} is missing`;
  return undefined;
}

export interface CommandOutput {
  stdout: string;
  stderr: string;
  code: number | null;
  timedOut?: boolean;
}

/** The most useful line to show when a CLI call fails. */
export function failureMessage(result: CommandOutput): string {
  if (result.timedOut) return "codex-profile did not finish in time.";
  const lines = result.stderr
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
  // Warnings may precede the fatal line; `die` always prefixes it with "Error:".
  const fatal = [...lines].reverse().find((line) => line.startsWith("Error:"));
  if (fatal) return fatal.replace(/^Error:\s*/, "");
  if (lines.length > 0) return lines.join("\n");
  const stdout = result.stdout.trim();
  if (stdout) return stdout;
  return result.code === null
    ? "codex-profile stopped before it finished."
    : `codex-profile exited with status ${result.code}.`;
}

export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
