#!/usr/bin/env node
import process from "node:process";
import { focusProject } from "./focus.js";
import { normalizeCodexEvent } from "./event-normalizer.js";
import { saveEvent } from "./state-store.js";

const [, , command, ...args] = process.argv;

try {
  if (command === "notify") {
    await notify(args);
  } else if (command === "focus") {
    await focus(args);
  } else if (command === "serve") {
    servePlaceholder();
  } else {
    usage();
    process.exitCode = 1;
  }
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
}

async function notify(args) {
  const rawEvent = parseEventArg(args[0]);
  const event = normalizeCodexEvent(rawEvent);
  const paths = await saveEvent(event);

  console.log(JSON.stringify({ ok: true, event, paths }, null, 2));
}

async function focus(args) {
  const result = await focusProject(args[0]);
  console.log(JSON.stringify(result, null, 2));
}

function servePlaceholder() {
  console.log("Bridge server placeholder. Next step: add localhost WebSocket for Flutter.");
}

function parseEventArg(value) {
  if (!value) {
    return { type: "agent-turn-complete", cwd: process.env.PWD || process.cwd() };
  }

  try {
    return JSON.parse(value);
  } catch {
    return {
      type: "agent-turn-complete",
      cwd: process.env.PWD || process.cwd(),
      message: value
    };
  }
}

function usage() {
  console.error(`Usage:
  petfy-bridge notify '<codex-json>'
  petfy-bridge focus '/path/to/project'
  petfy-bridge serve`);
}
