import assert from "node:assert/strict";
import { stat } from "node:fs/promises";

export function assertIncludes(haystack, needle, label = "value") {
  assert.ok(haystack.includes(needle), `${label} should contain ${needle}`);
}

export function assertExcludes(haystack, needle, label = "value") {
  assert.ok(!haystack.includes(needle), `${label} should not contain ${needle}`);
}

export async function assertFileExists(path, label = path) {
  const metadata = await stat(path);
  assert.ok(metadata.isFile(), `${label} should be a file`);
}
