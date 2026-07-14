import { chmod, mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

export function makeTempRoot(prefix) {
  return mkdtemp(join(tmpdir(), prefix));
}

export async function writeExecutable(path, body) {
  await writeFile(path, body, "utf8");
  await chmod(path, 0o755);
}
