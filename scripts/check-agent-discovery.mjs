// Optional local smoke test: Node.js + installed Codex/Claude CLI.
// Initializes discovery only; sends no model prompt and executes no Git action.
import { spawn } from "node:child_process";
import { mkdtemp, rmdir } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

const products = process.argv.slice(2);
if (!products.length) products.push("codex", "claude");
if (products.some(p => !["codex", "claude"].includes(p))) {
  throw new Error("Usage: node scripts/check-agent-discovery.mjs [codex|claude]");
}
const cwd = await mkdtemp(join(tmpdir(), "xian-discovery-"));

function check(product) {
  return new Promise((resolve, reject) => {
    const args = product === "codex"
      ? ["app-server", "--stdio"]
      : ["--print", "--input-format", "stream-json", "--output-format", "stream-json",
         "--verbose", "--setting-sources", "user", "--settings", '{"disableAllHooks":true}',
         "--strict-mcp-config", "--mcp-config", '{"mcpServers":{}}', "--tools", ""];
    const child = spawn(product, args, { cwd, stdio: ["pipe", "pipe", "ignore"] });
    let buffer = "", outcome = null, error = null;
    const timer = setTimeout(() => {
      error = new Error(`${product}: discovery timed out`);
      child.kill("SIGKILL");
    }, 15000);
    const send = value => child.stdin.write(JSON.stringify(value) + "\n");
    child.on("error", err => { error = err; });
    child.stdin.on("error", err => { error = err; });
    child.stdout.on("data", chunk => {
      buffer += chunk;
      let end;
      while ((end = buffer.indexOf("\n")) >= 0) {
        const line = buffer.slice(0, end);
        buffer = buffer.slice(end + 1);
        let message;
        try { message = JSON.parse(line); } catch { continue; }
        if (product === "codex" && message.id === 1) {
          send({ method: "initialized" });
          send({ id: 2, method: "skills/list", params: { cwds: [cwd], forceReload: true } });
        }
        const response = product === "codex"
          ? message.id === 2
          : message.type === "control_response";
        if (!response) continue;
        const skills = product === "codex"
          ? (message.result?.data ?? []).flatMap(d => d.skills)
          : message.response?.response?.commands ?? [];
        const skill = skills.find(s => s.name === "xian-commit" && s.enabled !== false);
        outcome = { product, discovered: Boolean(skill), scope: skill?.scope,
                    path: skill?.path, modelInvocation: "not-tested" };
        child.kill();
      }
    });
    child.on("close", () => {
      clearTimeout(timer);
      if (outcome) resolve(outcome);
      else reject(error ?? new Error(`${product}: no discovery response`));
    });
    send(product === "codex"
      ? { id: 1, method: "initialize", params: {
          clientInfo: { name: "xian-commit-discovery", version: "1.0.0" },
          capabilities: { experimentalApi: true } } }
      : { type: "control_request", request_id: "xian-commit-discovery",
          request: { subtype: "initialize" } });
  });
}

try {
  for (const product of products) {
    try {
      const result = await check(product);
      console.log(JSON.stringify(result));
      if (!result.discovered) process.exitCode = 1;
    } catch (error) {
      console.error(`${product}: ${error.message}`);
      process.exitCode = 1;
    }
  }
} finally {
  // Never recursively remove an Agent's files if it unexpectedly wrote here.
  await rmdir(cwd).catch(() => console.error(`Temporary directory retained: ${cwd}`));
}
