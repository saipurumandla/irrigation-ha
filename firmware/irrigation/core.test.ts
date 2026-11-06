// Builds irrigation/test_core.cpp with the PC's g++ and reports each of its checks as a test.
// Skipped where there's no g++.
import { execFileSync, spawnSync } from "node:child_process";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const here = dirname(fileURLToPath(import.meta.url));
const hasGpp = spawnSync("g++", ["--version"]).status === 0;

function run(): { lines: string[]; status: number } {
  const exe = join(mkdtempSync(join(tmpdir(), "irrigation-")), "test_core");
  execFileSync("g++", ["-std=c++17", "-Wall", "-Wextra", "-Werror", "-o", exe, join(here, "test_core.cpp")], { stdio: "pipe" });
  const r = spawnSync(exe, { encoding: "utf8" });
  return { lines: r.stdout.split("\n").filter((l) => /^(ok|FAIL) /.test(l)), status: r.status ?? -1 };
}

describe.skipIf(!hasGpp)("irrigation schedule logic (C++, on the board)", () => {
  const { lines, status } = hasGpp ? run() : { lines: [], status: 0 };
  it("has checks", () => expect(lines.length).toBeGreaterThan(50));
  it.each(lines.map((l) => [l.replace(/^(ok|FAIL) /, ""), l.startsWith("ok ")] as const))("%s", (_name, ok) => {
    expect(ok).toBe(true);
  });
  it("exits cleanly", () => expect(status).toBe(0));
});
