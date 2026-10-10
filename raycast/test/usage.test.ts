import assert from "node:assert/strict";
import { describe, test } from "node:test";
import {
  constrainingWindow,
  describeWindow,
  durationLabel,
  formatCountdown,
  formatResetClock,
  interpretUsageOutput,
  isSnapshotFresh,
  isUnsupportedUsageCommand,
  normalizeState,
  parseUsageJson,
  quotaLevel,
  usageHeadline,
} from "../src/lib/usage.ts";
import type { ProfileUsage, UsageSnapshot, UsageWindow } from "../src/lib/usage.ts";

// 2026-10-11T12:00:00Z
const NOW = Date.UTC(2026, 9, 11, 12, 0, 0);
const NOW_S = NOW / 1000;

const CONTRACT = JSON.stringify({
  profiles: [
    {
      name: "default",
      home: "/Users/x/.codex",
      state: "ok",
      windows: [
        { duration_mins: 300, used_percent: 92, remaining_percent: 8, resets_at: NOW_S + 72 * 60 },
        { duration_mins: 10080, used_percent: 47, remaining_percent: 53, resets_at: NOW_S + 3 * 86400 },
      ],
    },
    {
      name: "work",
      home: "/Users/x/.codex-work",
      state: "unavailable",
      detail: "Codex usage is unavailable. Sign in with 'codex-profile login work' or check your connection.",
      windows: [],
    },
    {
      name: "client",
      home: "/Users/x/.codex-client",
      state: "not_logged_in",
      detail: "Not signed in. Run 'codex-profile login client'.",
      windows: [],
    },
    { name: "old", home: "/Users/x/.codex-old", state: "not_initialized", detail: "Not initialized", windows: [] },
  ],
});

function window(overrides: Partial<UsageWindow> = {}): UsageWindow {
  return { durationMins: 300, usedPercent: 92, remainingPercent: 8, resetsAt: NOW_S + 72 * 60, ...overrides };
}

describe("parseUsageJson", () => {
  test("reads the documented contract", () => {
    const profiles = parseUsageJson(CONTRACT);
    assert.deepEqual(
      profiles.map((profile) => [profile.name, profile.state, profile.windows.length]),
      [
        ["default", "ok", 2],
        ["work", "unavailable", 0],
        ["client", "not_logged_in", 0],
        ["old", "not_initialized", 0],
      ],
    );
    assert.deepEqual(profiles[0].windows[0], {
      durationMins: 300,
      usedPercent: 92,
      remainingPercent: 8,
      resetsAt: NOW_S + 72 * 60,
    });
    assert.equal(profiles[2].detail, "Not signed in. Run 'codex-profile login client'.");
    assert.equal(profiles[0].detail, undefined);
  });

  test("keeps null durations and reset times", () => {
    const [profile] = parseUsageJson(
      JSON.stringify({
        profiles: [
          {
            name: "a",
            home: "/h",
            state: "ok",
            windows: [{ duration_mins: null, used_percent: null, remaining_percent: 40, resets_at: null }],
          },
        ],
      }),
    );
    assert.deepEqual(profile.windows, [
      { durationMins: null, usedPercent: null, remainingPercent: 40, resetsAt: null },
    ]);
  });

  test("treats unknown future states like unavailable", () => {
    const [profile] = parseUsageJson(
      JSON.stringify({ profiles: [{ name: "a", home: "/h", state: "rate_limited", detail: "Later.", windows: [] }] }),
    );
    assert.equal(profile.state, "unavailable");
    assert.equal(profile.detail, "Later.");
    assert.equal(normalizeState(undefined), "unavailable");
    assert.equal(normalizeState("not_logged_in"), "not_logged_in");
  });

  test("clamps percentages and derives a missing remaining value", () => {
    const [profile] = parseUsageJson(
      JSON.stringify({
        profiles: [
          {
            name: "a",
            state: "ok",
            windows: [
              { duration_mins: 300, remaining_percent: 140, resets_at: null },
              { duration_mins: 300, remaining_percent: -3, resets_at: null },
              { duration_mins: 300, used_percent: 70.4, resets_at: null },
              { duration_mins: 300, resets_at: null },
              "junk",
            ],
          },
        ],
      }),
    );
    assert.deepEqual(
      profile.windows.map((entry) => entry.remainingPercent),
      [100, 0, 29],
    );
    assert.equal(profile.home, "");
  });

  test("skips unnamed profiles and rejects documents of the wrong shape", () => {
    assert.deepEqual(parseUsageJson(JSON.stringify({ profiles: [{ state: "ok" }, { name: "" }] })), []);
    assert.throws(() => parseUsageJson("not json"), /not JSON/);
    assert.throws(() => parseUsageJson("{}"), /profiles list/);
  });
});

describe("levels and labels", () => {
  test("uses the menu-bar thresholds", () => {
    assert.equal(quotaLevel(0), "critical");
    assert.equal(quotaLevel(10), "critical");
    assert.equal(quotaLevel(11), "low");
    assert.equal(quotaLevel(25), "low");
    assert.equal(quotaLevel(26), "normal");
    assert.equal(quotaLevel(100), "normal");
  });

  test("names windows from their reported duration", () => {
    assert.equal(durationLabel(300), "5h");
    assert.equal(durationLabel(10080), "7d");
    assert.equal(durationLabel(15), "15m");
    assert.equal(durationLabel(90), "90m");
    assert.equal(durationLabel(null), null);
    assert.equal(durationLabel(0), null);
  });
});

describe("formatCountdown", () => {
  test("rounds up to whole minutes in at most two units", () => {
    assert.equal(formatCountdown(NOW_S + 72 * 60, NOW), "1h 12m");
    assert.equal(formatCountdown(NOW_S + 59 * 60 + 5, NOW), "1h");
    assert.equal(formatCountdown(NOW_S + 30, NOW), "1m");
    assert.equal(formatCountdown(NOW_S + 45 * 60, NOW), "45m");
    assert.equal(formatCountdown(NOW_S + 2 * 86400 + 3 * 3600 + 5 * 60, NOW), "2d 3h");
    assert.equal(formatCountdown(NOW_S + 86400, NOW), "1d");
    assert.equal(formatCountdown(NOW_S - 600, NOW), "1m");
  });

  test("shows a clock time today and a date otherwise", () => {
    const options = { locale: "en-US", timeZone: "UTC" };
    assert.equal(formatResetClock(NOW_S + 3 * 3600 + 40 * 60, NOW, options), "3:40 PM");
    assert.equal(formatResetClock(NOW_S + 86400 + 3 * 3600 + 40 * 60, NOW, options), "Oct 12, 3:40 PM");
  });
});

describe("describeWindow", () => {
  test("matches the documented wording", () => {
    const description = describeWindow(window(), 0, NOW);
    assert.equal(description.summary, "5h: 8% left · resets in 1h 12m");
    assert.equal(description.title, "5h: 8% left");
    assert.equal(description.subtitle, "resets in 1h 12m");
    assert.equal(description.level, "critical");
  });

  test("asks for a fresh reading once the reset time has passed", () => {
    const description = describeWindow(window({ resetsAt: NOW_S - 1 }), 0, NOW);
    assert.equal(description.summary, "5h: awaiting a fresh reading");
    assert.equal(description.reset, true);
    assert.equal(description.level, "normal");
  });

  test("handles unknown reset times and durations", () => {
    assert.equal(describeWindow(window({ resetsAt: null }), 0, NOW).summary, "5h: 8% left");
    assert.equal(
      describeWindow(window({ durationMins: null, remainingPercent: 53 }), 1, NOW).summary,
      "Limit 2: 53% left · resets in 1h 12m",
    );
  });
});

describe("constrainingWindow and usageHeadline", () => {
  const profile = (overrides: Partial<ProfileUsage>): ProfileUsage => ({
    name: "work",
    home: "/h",
    state: "ok",
    windows: [],
    ...overrides,
  });

  test("picks the window that runs out first, skipping expired readings", () => {
    const windows = [
      window({ durationMins: 300, remainingPercent: 5, resetsAt: NOW_S - 10 }),
      window({ durationMins: 10080, remainingPercent: 40 }),
      window({ durationMins: 300, remainingPercent: 60 }),
    ];
    assert.equal(constrainingWindow(windows, NOW)?.index, 1);
    assert.equal(constrainingWindow([window({ resetsAt: NOW_S - 1 })], NOW), undefined);
  });

  test("breaks ties with the later reset", () => {
    const windows = [
      window({ durationMins: 300, remainingPercent: 20, resetsAt: NOW_S + 60 }),
      window({ durationMins: 10080, remainingPercent: 20, resetsAt: NOW_S + 6000 }),
    ];
    assert.equal(constrainingWindow(windows, NOW)?.index, 1);
  });

  test("summarises each state in words", () => {
    const ok = usageHeadline(
      profile({ windows: [window(), window({ durationMins: 10080, remainingPercent: 53 })] }),
      NOW,
    );
    assert.deepEqual(ok && { text: ok.text, level: ok.level }, { text: "5h 8% left", level: "critical" });
    assert.equal(ok?.tooltip, "5h: 8% left · resets in 1h 12m\n7d: 53% left · resets in 1h 12m");

    assert.equal(usageHeadline(profile({ windows: [window({ remainingPercent: 20 })] }), NOW)?.level, "low");
    assert.equal(usageHeadline(profile({ windows: [window({ resetsAt: NOW_S - 1 })] }), NOW)?.text, "Awaiting reading");
    assert.equal(usageHeadline(profile({ windows: [] }), NOW), undefined);

    const signIn = usageHeadline(profile({ state: "not_logged_in", detail: "Not signed in." }), NOW);
    assert.deepEqual(signIn, { text: "Not signed in", level: "normal", tooltip: "Not signed in." });
    assert.equal(usageHeadline(profile({ state: "unavailable" }), NOW)?.text, "Usage unavailable");
    assert.equal(usageHeadline(profile({ state: "error", detail: "Boom" }), NOW)?.tooltip, "Boom");
    assert.equal(usageHeadline(profile({ state: "not_initialized" }), NOW), undefined);
  });
});

describe("interpretUsageOutput", () => {
  test("parses JSON on success", () => {
    const outcome = interpretUsageOutput({ stdout: `${CONTRACT}\n`, stderr: "", code: 0 });
    assert.equal(outcome.kind, "ok");
    assert.equal(outcome.kind === "ok" && outcome.profiles.length, 4);
  });

  test("still parses JSON when a named profile made the exit status non-zero", () => {
    const outcome = interpretUsageOutput({ stdout: CONTRACT, stderr: "", code: 1 });
    assert.equal(outcome.kind, "ok");
  });

  test("recognises an older CLI without the usage command", () => {
    const output = { stdout: "", stderr: "Error: Unknown command 'usage'. See 'codex-profile help'.\n", code: 1 };
    assert.equal(isUnsupportedUsageCommand(output), true);
    assert.deepEqual(interpretUsageOutput(output), {
      kind: "unsupported",
      message: "Unknown command 'usage'. See 'codex-profile help'.",
    });
  });

  test("reports other failures with the CLI's message", () => {
    assert.throws(
      () => interpretUsageOutput({ stdout: "", stderr: "Error: No healthy Codex CLI found.", code: 1 }),
      /^Error: No healthy Codex CLI found\.$/,
    );
    assert.throws(() => interpretUsageOutput({ stdout: "", stderr: "", code: 2 }), /status 2/);
    assert.throws(() => interpretUsageOutput({ stdout: "", stderr: "", code: null, timedOut: true }), /too long/);
    assert.throws(() => interpretUsageOutput({ stdout: "{oops", stderr: "", code: 0 }), /not JSON/);
    assert.throws(() => interpretUsageOutput({ stdout: "", stderr: "", code: 0 }), /no data/);
  });
});

describe("isSnapshotFresh", () => {
  const snapshot = (checkedAt: number, windows: UsageWindow[] = [window()]): UsageSnapshot => ({
    checkedAt,
    cliPath: "/bin/codex-profile",
    outcome: { kind: "ok", profiles: [{ name: "a", home: "/h", state: "ok", windows }] },
  });

  test("reuses a reading for a minute", () => {
    assert.equal(isSnapshotFresh(snapshot(NOW - 59_000), NOW), true);
    assert.equal(isSnapshotFresh(snapshot(NOW - 60_000), NOW), false);
    assert.equal(isSnapshotFresh(snapshot(NOW + 5_000), NOW), false);
  });

  test("reads again after a reported window resets", () => {
    const resetsSoon = [window({ resetsAt: (NOW - 10_000) / 1000 })];
    assert.equal(isSnapshotFresh(snapshot(NOW - 20_000, resetsSoon), NOW), false);
    // A window that had already reset when it was read does not force reads.
    const alreadyReset = [window({ resetsAt: (NOW - 30_000) / 1000 })];
    assert.equal(isSnapshotFresh(snapshot(NOW - 20_000, alreadyReset), NOW), true);
  });

  test("caches an unsupported result for the same minute", () => {
    const unsupported: UsageSnapshot = {
      checkedAt: NOW - 1_000,
      cliPath: "/bin/codex-profile",
      outcome: { kind: "unsupported", message: "Unknown command" },
    };
    assert.equal(isSnapshotFresh(unsupported, NOW), true);
  });
});
