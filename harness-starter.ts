// harness-starter.ts
// Loaded with:
//   bun --preload ./harness-starter.ts node_modules/next/dist/bin/next start --hostname 0.0.0.0
import { createRequire } from "node:module";
import { basename, dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn as originalSpawn, spawnSync } from "node:child_process";
import type * as childProcess from "node:child_process";

const AGENT_BINS = new Set([
  "claude",
  "openclaude",
  "codex",
  "cursor-agent",
  "gemini",
  "copilot",
  "opencode",
  "opencode-cli",
  "qwen",
  "qodercli",
  "deepseek",
  "aider",
  "openclaw",
  "hermes",
  "kimi",
  "devin",
  "kiro-cli",
  "kilo",
  "vibe-acp",
  "pi",
]);

function isAgent(cmd: unknown): boolean {
  return typeof cmd === "string" && AGENT_BINS.has(basename(cmd));
}

function drainChunk(stream: "stdout" | "stderr", chunk: unknown) {
  const raw =
    typeof chunk === "string"
      ? chunk
      : Buffer.isBuffer(chunk)
        ? chunk.toString("utf8")
        : String(chunk);
  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    if (stream === "stderr") {
      console.error(`[harness] stderr: ${trimmed}`);
    } else {
      console.log(`[harness] stdout: ${trimmed}`);
    }
  }
}

function wrapAgentChild(
  child: childProcess.ChildProcess,
  cmd: string,
  args: readonly string[],
) {
  console.log(`[harness] start bin=${cmd} argv=${JSON.stringify(args)}`);
  if (child.stdout) {
    child.stdout.setEncoding?.("utf8");
    child.stdout.on("data", (chunk) => drainChunk("stdout", chunk));
  }
  if (child.stderr) {
    child.stderr.setEncoding?.("utf8");
    child.stderr.on("data", (chunk) => drainChunk("stderr", chunk));
  }
  child.on("close", (code) => {
    console.log(`[harness] done bin=${cmd} exit=${code ?? "?"}`);
  });
}

// Patch spawn before Next.js loads any route modules.
const require = createRequire(import.meta.url);
const cp = require("node:child_process") as typeof childProcess;

function patchedSpawn(...args: unknown[]): childProcess.ChildProcess {
  const cmd = args[0];
  const child = (originalSpawn as (...params: unknown[]) => childProcess.ChildProcess)(
    ...args,
  );
  if (isAgent(cmd)) {
    const spawnArgs = Array.isArray(args[1]) ? args[1] : [];
    wrapAgentChild(child, String(cmd), spawnArgs);
  }
  return child;
}

// Cast required because the runtime spawn signature preserves non-null stdio
// types, while our generic passthrough returns the wider ChildProcess type.
cp.spawn = patchedSpawn as unknown as typeof cp.spawn;

// Startup diagnostics.
function checkedVersion(name: string): string {
  try {
    const result = spawnSync(name, ["--version"], {
      encoding: "utf8",
      timeout: 5000,
    });
    return (result.stdout ?? result.stderr ?? "").trim() || "no output";
  } catch (err) {
    return `not available (${err instanceof Error ? err.message : String(err)})`;
  }
}

function checkedPath(name: string): string {
  const result = spawnSync("command", ["-v", name], {
    encoding: "utf8",
    shell: true,
    timeout: 5000,
  });
  return (result.stdout ?? "").trim() || "not on PATH";
}

console.log("[harness] container starting");
console.log(`[harness] opencode: ${checkedVersion("opencode")}`);
console.log(`[harness] pi: ${checkedVersion("pi")}`);
console.log(`[harness] opencode path: ${checkedPath("opencode")}`);
console.log(`[harness] pi path: ${checkedPath("pi")}`);

// Next.js expects to run from the app package directory.
process.chdir(join(dirname(fileURLToPath(import.meta.url)), "next"));
