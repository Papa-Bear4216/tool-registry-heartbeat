import { createServer } from "node:http";
import { readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const NODE = "tool-registry-heartbeat";
const scriptsDir = join(dirname(fileURLToPath(import.meta.url)), "..", "scripts");

export function isLoopbackAddress(addr) {
  return addr === "127.0.0.1" || addr === "::1" || addr === "::ffff:127.0.0.1";
}

function envelope(body, result) {
  return { v: 1, inReplyTo: body.id, from: NODE, to: body.from, ok: true, result };
}

function inventory() {
  const scripts = readdirSync(scriptsDir).filter((name) => name.endsWith(".ps1")).sort();
  if (scripts.length < 1) return { error: "tool registry scripts are missing" };
  return { scripts };
}

export function handleHeartbeatDelegate(body) {
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return { status: 400, body: { error: "envelope must be a JSON object" } };
  }
  if (body.to !== NODE || body.v !== 1) {
    return { status: 400, body: { error: "envelope is not addressed to tool-registry-heartbeat" } };
  }
  if (body.action === "ping") {
    return { status: 200, body: envelope(body, { node: NODE, action: "ping" }) };
  }
  if (body.action === "inventory") {
    try {
      const listed = inventory();
      if (listed.error) return { status: 500, body: { error: listed.error } };
      return { status: 200, body: envelope(body, { node: NODE, action: "inventory", ...listed }) };
    } catch {
      return { status: 500, body: { error: "tool registry scripts are missing" } };
    }
  }
  return { status: 400, body: { error: "tool-registry-heartbeat accepts ping or inventory" } };
}

function readBody(req, limit) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on("data", (chunk) => {
      size += chunk.length;
      if (size > limit) {
        reject(new Error("delegate body too large"));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    req.on("error", () => reject(new Error("body stream failed")));
  });
}

function send(res, status, body) {
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    "Content-Type": "application/json",
    "Content-Length": Buffer.byteLength(payload),
  });
  res.end(payload);
}

export function startHeartbeatDelegate(port) {
  const server = createServer(async (req, res) => {
    const path = (req.url ?? "/").split("?")[0];
    if (req.method === "GET" && path === "/health") {
      send(res, 200, { ok: true, node: NODE });
      return;
    }
    if (req.method !== "POST" || path !== "/mishmash/delegate") {
      send(res, 404, { error: "Not Found" });
      return;
    }
    if (!isLoopbackAddress(req.socket.remoteAddress)) {
      send(res, 403, { error: "delegate is only accepted from this PC" });
      return;
    }
    try {
      const raw = await readBody(req, 64 * 1024);
      const decoded = raw ? JSON.parse(raw) : {};
      const outcome = handleHeartbeatDelegate(decoded);
      send(res, outcome.status, outcome.body);
    } catch (err) {
      send(res, 400, { error: err instanceof Error ? err.message : "bad body" });
    }
  });
  return new Promise((resolve) => {
    server.listen(port, "127.0.0.1", () => resolve(server));
  });
}

const entry = process.argv[1] ?? "";
if (entry.endsWith("delegate.mjs")) {
  const port = Number(process.env.MISHMASH_PORT || 39405);
  startHeartbeatDelegate(port).then(() => {
    console.log(`tool-registry-heartbeat mishmash on 127.0.0.1:${port}`);
  });
}
