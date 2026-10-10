// Parsing and wording for `codex-profile usage --json`. Pure functions only:
// no Raycast or Node imports, so `node --test` can load this file directly.

export type UsageState = "ok" | "not_logged_in" | "unavailable" | "not_initialized" | "error";

const KNOWN_STATES: readonly UsageState[] = ["ok", "not_logged_in", "unavailable", "not_initialized", "error"];

export interface UsageWindow {
  durationMins: number | null;
  usedPercent: number | null;
  /** Integer 0-100. */
  remainingPercent: number;
  /** Unix seconds. */
  resetsAt: number | null;
}

export interface ProfileUsage {
  name: string;
  home: string;
  state: UsageState;
  detail?: string;
  windows: UsageWindow[];
}

export type QuotaLevel = "normal" | "low" | "critical";

export type UsageOutcome = { kind: "ok"; profiles: ProfileUsage[] } | { kind: "unsupported"; message: string };

export interface UsageCommandOutput {
  stdout: string;
  stderr: string;
  code: number | null;
  timedOut?: boolean;
}

/** Same thresholds as the menu-bar app: 10% or less is critical, 25% or less is low. */
export function quotaLevel(remainingPercent: number): QuotaLevel {
  if (remainingPercent <= 10) return "critical";
  if (remainingPercent <= 25) return "low";
  return "normal";
}

export function levelLabel(level: QuotaLevel): string | undefined {
  if (level === "critical") return "Critical";
  if (level === "low") return "Low";
  return undefined;
}

/** Unknown future states are shown like `unavailable`, with their detail. */
export function normalizeState(state: unknown): UsageState {
  return KNOWN_STATES.includes(state as UsageState) ? (state as UsageState) : "unavailable";
}

/** "5h", "7d" or "15m" from the reported window length. */
export function durationLabel(minutes: number | null): string | null {
  if (minutes === null || !Number.isFinite(minutes) || minutes <= 0) return null;
  if (minutes % 1440 === 0) return `${minutes / 1440}d`;
  if (minutes % 60 === 0) return `${minutes / 60}h`;
  return `${minutes}m`;
}

export function windowLabel(window: UsageWindow, index: number): string {
  return durationLabel(window.durationMins) ?? `Limit ${index + 1}`;
}

export function hasReset(window: UsageWindow, nowMs: number): boolean {
  return window.resetsAt !== null && window.resetsAt * 1000 <= nowMs;
}

/**
 * Time left, rounded up to whole minutes, in at most two units:
 * "2d 3h", "1h 12m", "45m". Countdowns stay English, like the menu-bar app.
 */
export function formatCountdown(resetsAtSeconds: number, nowMs: number): string {
  const totalMinutes = Math.max(1, Math.ceil((resetsAtSeconds * 1000 - nowMs) / 60_000));
  const days = Math.floor(totalMinutes / 1440);
  const hours = Math.floor((totalMinutes % 1440) / 60);
  const minutes = totalMinutes % 60;
  if (days > 0) return hours > 0 ? `${days}d ${hours}h` : `${days}d`;
  if (hours > 0) return minutes > 0 ? `${hours}h ${minutes}m` : `${hours}h`;
  return `${minutes}m`;
}

export interface ClockOptions {
  locale?: string;
  timeZone?: string;
}

/** A time today ("3:40 PM"), or a date and time otherwise ("Oct 12, 3:40 PM"). */
export function formatResetClock(resetsAtSeconds: number, nowMs: number, options: ClockOptions = {}): string {
  const { locale, timeZone } = options;
  const resetMs = resetsAtSeconds * 1000;
  const day = new Intl.DateTimeFormat("en-CA", { timeZone, year: "numeric", month: "2-digit", day: "2-digit" });
  const sameDay = day.format(resetMs) === day.format(nowMs);
  const format = new Intl.DateTimeFormat(
    locale,
    sameDay
      ? { timeZone, hour: "numeric", minute: "2-digit" }
      : { timeZone, month: "short", day: "numeric", hour: "numeric", minute: "2-digit" },
  );
  return format.format(resetMs);
}

export interface WindowDescription {
  label: string;
  /** "5h: 8% left" or "5h: awaiting a fresh reading". */
  title: string;
  /** "resets in 1h 12m", when a future reset time is known. */
  subtitle?: string;
  /** "5h: 8% left · resets in 1h 12m". */
  summary: string;
  level: QuotaLevel;
  reset: boolean;
}

export function describeWindow(window: UsageWindow, index: number, nowMs: number): WindowDescription {
  const label = windowLabel(window, index);
  if (hasReset(window, nowMs)) {
    const title = `${label}: awaiting a fresh reading`;
    return { label, title, summary: title, level: "normal", reset: true };
  }
  const title = `${label}: ${window.remainingPercent}% left`;
  const subtitle = window.resetsAt === null ? undefined : `resets in ${formatCountdown(window.resetsAt, nowMs)}`;
  return {
    label,
    title,
    subtitle,
    summary: subtitle ? `${title} · ${subtitle}` : title,
    level: quotaLevel(window.remainingPercent),
    reset: false,
  };
}

/** The current window that runs out first; ties go to the one that resets later. */
export function constrainingWindow(
  windows: UsageWindow[],
  nowMs: number,
): { window: UsageWindow; index: number } | undefined {
  let best: { window: UsageWindow; index: number } | undefined;
  for (const [index, window] of windows.entries()) {
    if (hasReset(window, nowMs)) continue;
    if (
      !best ||
      window.remainingPercent < best.window.remainingPercent ||
      (window.remainingPercent === best.window.remainingPercent && (window.resetsAt ?? 0) > (best.window.resetsAt ?? 0))
    ) {
      best = { window, index };
    }
  }
  return best;
}

export interface UsageHeadline {
  /** Short accessory text such as "5h 8% left" or "Not signed in". */
  text: string;
  level: QuotaLevel;
  /** Every window, one per line, or the CLI's detail. */
  tooltip: string;
}

/** A compact one-line reading for a profile row. */
export function usageHeadline(profile: ProfileUsage, nowMs: number): UsageHeadline | undefined {
  switch (profile.state) {
    case "ok": {
      const tooltip =
        profile.windows.length > 0
          ? profile.windows.map((window, index) => describeWindow(window, index, nowMs).summary).join("\n")
          : "No Codex quota windows were reported.";
      const constraining = constrainingWindow(profile.windows, nowMs);
      if (!constraining) {
        return profile.windows.length > 0 ? { text: "Awaiting reading", level: "normal", tooltip } : undefined;
      }
      const { window, index } = constraining;
      return {
        text: `${windowLabel(window, index)} ${window.remainingPercent}% left`,
        level: quotaLevel(window.remainingPercent),
        tooltip,
      };
    }
    case "not_logged_in":
      return { text: "Not signed in", level: "normal", tooltip: profile.detail ?? "Not signed in to Codex CLI." };
    case "not_initialized":
      return undefined;
    default:
      return { text: "Usage unavailable", level: "normal", tooltip: profile.detail ?? "Codex usage is unavailable." };
  }
}

/** Plain-language title for a profile whose state is not `ok`. */
export function stateTitle(state: UsageState): string {
  switch (state) {
    case "ok":
      return "Codex usage";
    case "not_logged_in":
      return "Not signed in to Codex CLI";
    case "not_initialized":
      return "Profile not initialized";
    case "error":
      return "Could not read Codex usage";
    default:
      return "Codex usage unavailable";
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function finiteOrNull(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function clampPercent(value: number): number {
  return Math.min(100, Math.max(0, Math.floor(value)));
}

function parseWindow(value: unknown): UsageWindow | undefined {
  if (!isRecord(value)) return undefined;
  const used = finiteOrNull(value.used_percent);
  const remaining = finiteOrNull(value.remaining_percent);
  let remainingPercent: number;
  if (remaining !== null) remainingPercent = clampPercent(remaining);
  else if (used !== null) remainingPercent = clampPercent(100 - used);
  else return undefined;
  const duration = finiteOrNull(value.duration_mins);
  return {
    durationMins: duration !== null && duration > 0 ? Math.round(duration) : null,
    usedPercent: used,
    remainingPercent,
    resetsAt: finiteOrNull(value.resets_at),
  };
}

/** Parses the `usage --json` document. Throws when it is not the expected shape. */
export function parseUsageJson(text: string): ProfileUsage[] {
  let value: unknown;
  try {
    value = JSON.parse(text);
  } catch {
    throw new Error("codex-profile usage returned output that is not JSON.");
  }
  if (!isRecord(value) || !Array.isArray(value.profiles)) {
    throw new Error("codex-profile usage returned JSON without a profiles list.");
  }
  const profiles: ProfileUsage[] = [];
  for (const entry of value.profiles) {
    if (!isRecord(entry) || typeof entry.name !== "string" || entry.name === "") continue;
    const windows = Array.isArray(entry.windows)
      ? entry.windows.map(parseWindow).filter((window): window is UsageWindow => window !== undefined)
      : [];
    const detail = typeof entry.detail === "string" && entry.detail.trim() ? entry.detail.trim() : undefined;
    profiles.push({
      name: entry.name,
      home: typeof entry.home === "string" ? entry.home : "",
      state: normalizeState(entry.state),
      detail,
      windows,
    });
  }
  return profiles;
}

/** True when an older codex-profile rejected `usage` as an unknown command. */
export function isUnsupportedUsageCommand(output: UsageCommandOutput): boolean {
  return output.code !== 0 && /unknown command/i.test(output.stderr) && !output.stdout.trim().startsWith("{");
}

/**
 * Turns one `usage --json` run into data. A non-zero exit still yields data
 * when stdout holds the JSON document (a named profile may be unavailable).
 */
export function interpretUsageOutput(output: UsageCommandOutput): UsageOutcome {
  const stdout = output.stdout.trim();
  if (stdout.startsWith("{")) {
    try {
      return { kind: "ok", profiles: parseUsageJson(stdout) };
    } catch (error) {
      if (output.code === 0) throw error;
    }
  }
  if (isUnsupportedUsageCommand(output)) {
    const line = output.stderr.trim().split(/\r?\n/).pop() ?? "";
    return { kind: "unsupported", message: line.replace(/^Error:\s*/, "") };
  }
  if (output.timedOut) throw new Error("Reading Codex usage took too long. Try again.");
  if (output.code !== 0) {
    const message = output.stderr.trim().replace(/^Error:\s*/, "");
    throw new Error(message || `codex-profile usage exited with status ${output.code ?? "unknown"}.`);
  }
  throw new Error("codex-profile usage returned no data.");
}

export interface UsageSnapshot {
  /** Milliseconds since the epoch. */
  checkedAt: number;
  cliPath: string;
  outcome: UsageOutcome;
}

export const USAGE_TTL_MS = 60_000;

/** Reuse a reading for a minute, unless a window it reported has since reset. */
export function isSnapshotFresh(snapshot: UsageSnapshot, nowMs: number, ttlMs = USAGE_TTL_MS): boolean {
  if (nowMs - snapshot.checkedAt >= ttlMs || nowMs < snapshot.checkedAt) return false;
  if (snapshot.outcome.kind !== "ok") return true;
  return !snapshot.outcome.profiles.some((profile) =>
    profile.windows.some(
      (window) =>
        window.resetsAt !== null && window.resetsAt * 1000 > snapshot.checkedAt && window.resetsAt * 1000 <= nowMs,
    ),
  );
}
