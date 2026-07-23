#!/usr/bin/env node
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { normalizeCodexEvent } from "../bridge/src/event-normalizer.js";
import { saveEvent } from "../bridge/src/state-store.js";

const fallbackType = process.argv[2] || "";
const rawArg = process.argv.slice(3).find((arg) => arg.trim().startsWith("{")) || "";
const stateDir = process.env.PETFY_STATE_DIR || path.join(os.homedir(), ".petfy");
const logFile = path.join(stateDir, "bridge.log");

await fs.promises.mkdir(stateDir, { recursive: true });

try {
  const stdinPayload = readStdin();
  const payload = rawArg || stdinPayload || fallbackPayload(fallbackType);
  const rawEvent = parsePayload(payload);
  const event = normalizeCodexEvent(rawEvent, {
    ...process.env,
    PETFY_EVENT_TYPE: fallbackType || process.env.PETFY_EVENT_TYPE || ""
  });
  const paths = await saveEvent(event);
  await appendLog({ ok: true, event, paths });
} catch (error) {
  await appendLog({
    ok: false,
    error: error instanceof Error ? error.message : String(error)
  });
}

function readStdin() {
  try {
    if (process.stdin.isTTY) {
      return "";
    }
    return fs.readFileSync(0, "utf8").trim();
  } catch {
    return "";
  }
}

function fallbackPayload(type) {
  return {
    type: type || "agent-turn-complete",
    cwd: process.env.PWD || process.cwd()
  };
}

function parsePayload(payload) {
  if (typeof payload === "object") {
    return payload;
  }
  try {
    return JSON.parse(payload);
  } catch {
    return {
      type: fallbackType || "agent-turn-complete",
      cwd: process.env.PWD || process.cwd(),
      message: payload
    };
  }
}

async function appendLog(entry) {
  await fs.promises.appendFile(logFile, `${JSON.stringify(entry, null, 2)}\n`);
}
