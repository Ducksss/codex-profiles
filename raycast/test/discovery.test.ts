import assert from "node:assert/strict";
import { describe, test } from "node:test";
import { readFileSync } from "node:fs";
import {
  augmentedPath,
  augmentedPathEntries,
  bundledExecutableCandidates,
  cliEnvironment,
  executableCandidates,
  expandHome,
  isBundledExecutable,
  lastAbsolutePath,
  preferencePath,
  sortNodeVersionsDescending,
  standardExecutableCandidates,
} from "../src/lib/discovery.ts";

const HOME = "/Users/me";

describe("discovery", () => {
  test("expands a leading tilde only", () => {
    assert.equal(expandHome("~/.local/bin/codex-profile", HOME), "/Users/me/.local/bin/codex-profile");
    assert.equal(expandHome("~", HOME), HOME);
    assert.equal(expandHome("/opt/homebrew/bin/codex-profile", HOME), "/opt/homebrew/bin/codex-profile");
    assert.equal(expandHome("~other/bin", HOME), "~other/bin");
  });

  test("accepts only absolute codex-profile path preferences", () => {
    assert.deepEqual(preferencePath(" ~/.local/bin/codex-profile ", HOME), {
      path: "/Users/me/.local/bin/codex-profile",
      absolute: true,
    });
    assert.deepEqual(preferencePath("/opt/homebrew/bin/codex-profile", HOME), {
      path: "/opt/homebrew/bin/codex-profile",
      absolute: true,
    });
    for (const relative of ["codex-profile", "bin/codex-profile", "./codex-profile", "~other/bin/codex-profile"]) {
      assert.equal(preferencePath(relative, HOME).absolute, false, relative);
    }
  });

  test("falls back to the menu bar app's bundled codex-profile after every PATH location", () => {
    const bundled = [
      "/Applications/Codex Profiles.app/Contents/Resources/bin/codex-profile",
      "/Users/me/Applications/Codex Profiles.app/Contents/Resources/bin/codex-profile",
    ];
    assert.deepEqual(bundledExecutableCandidates(HOME), bundled);
    const candidates = executableCandidates(HOME, ["v22.22.0"]);
    assert.deepEqual(candidates.slice(-2), bundled);
    assert.ok(
      candidates.indexOf("/Users/me/.nvm/versions/node/v22.22.0/bin/codex-profile") < candidates.indexOf(bundled[0]),
    );
    assert.ok(candidates.indexOf("/usr/bin/codex-profile") < candidates.indexOf(bundled[0]));
    assert.equal(isBundledExecutable(bundled[0]), true);
    assert.equal(isBundledExecutable("/opt/homebrew/bin/codex-profile"), false);
  });

  test("matches where the menu bar app build puts its CLI", () => {
    const build = readFileSync(new URL("../../scripts/macos/build-menu-app.sh", import.meta.url), "utf8");
    assert.match(build, /APP_DIR="\$OUTPUT_DIR\/Codex Profiles\.app"/);
    assert.match(build, /"\$CONTENTS_DIR\/Resources\/bin\/codex-profile"/);
  });

  test("probes the documented install locations first", () => {
    assert.deepEqual(standardExecutableCandidates(HOME), [
      "/Users/me/.local/bin/codex-profile",
      "/opt/homebrew/bin/codex-profile",
      "/usr/local/bin/codex-profile",
    ]);
    const candidates = executableCandidates(HOME, ["v20.1.0", "v22.22.0"]);
    assert.deepEqual(candidates.slice(0, 3), standardExecutableCandidates(HOME));
    assert.equal(new Set(candidates).size, candidates.length, "no duplicates");
    assert.ok(
      candidates.indexOf("/Users/me/.nvm/versions/node/v22.22.0/bin/codex-profile") <
        candidates.indexOf("/Users/me/.nvm/versions/node/v20.1.0/bin/codex-profile"),
    );
  });

  test("sorts nvm versions newest first", () => {
    assert.deepEqual(sortNodeVersionsDescending(["v18.20.0", "v22.9.0", "garbage", "v22.22.0"]), [
      "v22.22.0",
      "v22.9.0",
      "v18.20.0",
      "garbage",
    ]);
  });

  test("builds a PATH that finds Homebrew, user and Node installs", () => {
    const entries = augmentedPathEntries({
      home: HOME,
      currentPath: "/usr/bin:/bin:/custom/bin:/opt/homebrew/bin",
      executableDirectory: "/Users/me/.nvm/versions/node/v22.22.0/bin",
      nvmVersions: ["v22.22.0"],
    });
    assert.equal(entries[0], "/Users/me/.nvm/versions/node/v22.22.0/bin");
    for (const expected of ["/opt/homebrew/bin", "/usr/local/bin", "/Users/me/.local/bin", "/custom/bin", "/usr/bin"]) {
      assert.ok(entries.includes(expected), `PATH includes ${expected}`);
    }
    assert.equal(new Set(entries).size, entries.length, "no duplicates");
    assert.ok(entries.indexOf("/opt/homebrew/bin") < entries.indexOf("/custom/bin"));
    assert.deepEqual(entries.slice(-2), ["/usr/sbin", "/sbin"]);
  });

  test("drops user directories that do not exist but keeps the inherited PATH", () => {
    const path = augmentedPath({
      home: HOME,
      currentPath: "/custom/bin",
      exists: (directory) => directory === "/opt/homebrew/bin",
    });
    assert.equal(path, "/opt/homebrew/bin:/custom/bin:/usr/bin:/bin:/usr/sbin:/sbin");
  });

  test("takes the last absolute path from login-shell output", () => {
    assert.equal(lastAbsolutePath("Welcome!\n/opt/homebrew/bin/codex-profile\n"), "/opt/homebrew/bin/codex-profile");
    assert.equal(lastAbsolutePath("codex-profile: aliased to foo"), undefined);
    assert.equal(lastAbsolutePath(""), undefined);
  });

  test("never forwards credential overrides to codex-profile", () => {
    const base = {
      HOME: "",
      PATH: "/usr/bin",
      CODEX_ACCESS_TOKEN: "x",
      CODEX_API_KEY: "y",
      OPENAI_API_KEY: "z",
      LANG: "en_US.UTF-8",
    };
    const environment = cliEnvironment(base, "/opt/homebrew/bin:/usr/bin", HOME);
    assert.equal(environment.CODEX_ACCESS_TOKEN, undefined);
    assert.equal(environment.CODEX_API_KEY, undefined);
    assert.equal(environment.OPENAI_API_KEY, undefined);
    assert.equal(environment.PATH, "/opt/homebrew/bin:/usr/bin");
    assert.equal(environment.HOME, HOME);
    assert.equal(environment.LANG, "en_US.UTF-8");
    assert.equal(environment.CODEX_PROFILE_NO_UPDATE_CHECK, "1");
    assert.equal(base.CODEX_ACCESS_TOKEN, "x", "the caller's environment is not modified");
  });
});
