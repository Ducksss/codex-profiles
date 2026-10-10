// Locating codex-profile and building the environment it runs in. Raycast
// starts extensions with a minimal PATH, so both need help. Pure functions
// only; file-system checks are passed in by the caller.

export const EXECUTABLE_NAME = "codex-profile";

/** Expands a leading "~" or "~/" in a user-entered path. */
export function expandHome(path: string, home: string): string {
  if (path === "~") return home;
  if (path.startsWith("~/")) return `${home.replace(/\/+$/, "")}/${path.slice(2)}`;
  return path;
}

/** Fixed install locations, checked in order: source/standalone, Homebrew (Apple silicon, then Intel). */
export function standardExecutableCandidates(home: string): string[] {
  return [
    `${home}/.local/bin/${EXECUTABLE_NAME}`,
    `/opt/homebrew/bin/${EXECUTABLE_NAME}`,
    `/usr/local/bin/${EXECUTABLE_NAME}`,
  ];
}

/** "v22.11.0" -> [22, 11, 0]; anything unparseable sorts last. */
function versionParts(version: string): number[] {
  const match = /^v?(\d+)\.(\d+)\.(\d+)/.exec(version);
  return match ? match.slice(1).map(Number) : [-1, -1, -1];
}

/** Newest first, so the most recent Node's global bin wins. */
export function sortNodeVersionsDescending(versions: string[]): string[] {
  return [...versions].sort((left, right) => {
    const a = versionParts(left);
    const b = versionParts(right);
    for (let index = 0; index < 3; index += 1) {
      if (a[index] !== b[index]) return b[index] - a[index];
    }
    return left.localeCompare(right);
  });
}

export interface PathOptions {
  home: string;
  /** The PATH Raycast gave the extension. */
  currentPath?: string;
  /** Directory of the resolved codex-profile; searched first. */
  executableDirectory?: string;
  /** Installed nvm versions (directory names under ~/.nvm/versions/node). */
  nvmVersions?: string[];
  /** Keeps only directories that exist; defaults to keeping all. */
  exists?: (directory: string) => boolean;
}

/** User-level bin directories where codex-profile or codex is commonly installed. */
export function userBinDirectories(home: string, nvmVersions: string[] = []): string[] {
  return [
    `${home}/.local/bin`,
    "/opt/homebrew/bin",
    "/opt/homebrew/sbin",
    "/usr/local/bin",
    `${home}/.npm-global/bin`,
    `${home}/.volta/bin`,
    `${home}/.bun/bin`,
    `${home}/Library/pnpm`,
    `${home}/.local/share/pnpm`,
    `${home}/.asdf/shims`,
    `${home}/.local/share/mise/shims`,
    ...sortNodeVersionsDescending(nvmVersions).map((version) => `${home}/.nvm/versions/node/${version}/bin`),
    `${home}/Library/Application Support/fnm/aliases/default/bin`,
    `${home}/.local/share/fnm/aliases/default/bin`,
    "/opt/local/bin",
  ];
}

const SYSTEM_DIRECTORIES = ["/usr/bin", "/bin", "/usr/sbin", "/sbin"];

/**
 * An ordered, de-duplicated PATH: the CLI's own directory, common user bins
 * (Homebrew, ~/.local/bin, npm/nvm/Volta/pnpm/Bun/asdf/mise/fnm), whatever
 * PATH Raycast provided, then the system directories.
 */
export function augmentedPathEntries(options: PathOptions): string[] {
  const exists = options.exists ?? (() => true);
  const result: string[] = [];
  const add = (directory: string | undefined, mustExist: boolean) => {
    if (!directory || !directory.startsWith("/") || result.includes(directory)) return;
    if (mustExist && !exists(directory)) return;
    result.push(directory);
  };
  add(options.executableDirectory, false);
  for (const directory of userBinDirectories(options.home, options.nvmVersions)) add(directory, true);
  for (const directory of (options.currentPath ?? "").split(":")) add(directory, false);
  for (const directory of SYSTEM_DIRECTORIES) add(directory, false);
  return result;
}

export function augmentedPath(options: PathOptions): string {
  return augmentedPathEntries(options).join(":");
}

/** Every place to look for codex-profile before asking a login shell. */
export function executableCandidates(
  home: string,
  nvmVersions: string[] = [],
  exists?: (directory: string) => boolean,
): string[] {
  const candidates = [...standardExecutableCandidates(home)];
  for (const directory of augmentedPathEntries({ home, nvmVersions, exists })) {
    const candidate = `${directory}/${EXECUTABLE_NAME}`;
    if (!candidates.includes(candidate)) candidates.push(candidate);
  }
  return candidates;
}

/** The last absolute path printed by `command -v` in a login shell. */
export function lastAbsolutePath(output: string): string | undefined {
  const lines = output
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.startsWith("/"));
  return lines.length > 0 ? lines[lines.length - 1] : undefined;
}

/**
 * Variables that could substitute an inherited credential for the selected
 * profile's own sign-in. They are never forwarded to codex-profile.
 */
export const CREDENTIAL_OVERRIDE_VARIABLES = ["CODEX_ACCESS_TOKEN", "CODEX_API_KEY", "OPENAI_API_KEY"] as const;

/** The environment for background codex-profile calls. */
export function cliEnvironment(
  base: Record<string, string | undefined>,
  path: string,
  home: string,
): Record<string, string | undefined> {
  const environment: Record<string, string | undefined> = { ...base };
  for (const name of CREDENTIAL_OVERRIDE_VARIABLES) delete environment[name];
  environment.PATH = path;
  environment.HOME = base.HOME || home;
  // Background calls never prompt, colour output or check for updates.
  environment.CODEX_PROFILE_NO_UPDATE_CHECK = "1";
  environment.NO_COLOR = "1";
  return environment;
}
