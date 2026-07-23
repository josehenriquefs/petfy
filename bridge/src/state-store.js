import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";

const DEFAULT_DIR = path.join(os.homedir(), ".petfy");

export function getStateDir(env = process.env) {
  return env.PETFY_STATE_DIR || DEFAULT_DIR;
}

export async function saveEvent(event, env = process.env) {
  const stateDir = getStateDir(env);
  await fs.mkdir(stateDir, { recursive: true });

  const latestPath = path.join(stateDir, "latest-event.json");
  const historyPath = path.join(stateDir, "events.jsonl");
  const serialized = `${JSON.stringify(event)}\n`;

  await fs.writeFile(latestPath, JSON.stringify(event, null, 2));
  await fs.appendFile(historyPath, serialized);

  return { latestPath, historyPath };
}
