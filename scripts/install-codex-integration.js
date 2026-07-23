#!/usr/bin/env node
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const hookScript = path.join(repoRoot, "scripts", "petfy-event.sh");
const hookScriptJs = path.join(repoRoot, "scripts", "petfy-event.js");
const notifyScript = path.join(repoRoot, "scripts", "petfy-notify.sh");
const nodeCommand = process.env.PETFY_NODE_PATH || "node";
const codexHome = process.env.CODEX_HOME || path.join(os.homedir(), ".codex");
const hooksPath = path.join(codexHome, "hooks.json");
const configPath = path.join(codexHome, "config.toml");
const backupPath = `${hooksPath}.petfy-backup-${new Date()
  .toISOString()
  .replace(/[:.]/g, "-")}`;
const configBackupPath = `${configPath}.petfy-backup-${new Date()
  .toISOString()
  .replace(/[:.]/g, "-")}`;

const desiredHooks = [
  {
    eventName: "Stop",
    command: hookCommand("Stop"),
    timeout: 5
  },
  {
    eventName: "Notification",
    command: hookCommand("Notification"),
    timeout: 5
  },
  {
    eventName: "UserPromptSubmit",
    command: hookCommand("UserPromptSubmit"),
    timeout: 5
  }
];
const desiredNotifyScript = process.platform === "win32"
  ? `${nodeCommand} ${quoteArg(hookScriptJs)} agent-turn-complete`
  : notifyScript;

fs.mkdirSync(codexHome, { recursive: true });

installHooks();
installNotify();

console.log("Installed hooks:");
for (const desired of desiredHooks) {
  console.log(`- ${desired.eventName}: ${desired.command}`);
}
console.log(`Installed notify: ${desiredNotifyScript}`);

function hookCommand(eventName) {
  if (process.platform === "win32") {
    return `${nodeCommand} ${quoteArg(hookScriptJs)} ${eventName}`;
  }
  return `${hookScript} ${eventName}`;
}

function quoteArg(value) {
  if (/\s/.test(value)) {
    return `"${value.replace(/"/g, '\\"')}"`;
  }
  return value;
}

function installHooks() {
  const original = readHooksFile(hooksPath);
  const next = structuredClone(original);
  next.hooks ??= {};
  removeLegacyHooks(next);

  for (const desired of desiredHooks) {
    next.hooks[desired.eventName] ??= [];
    if (next.hooks[desired.eventName].length === 0) {
      next.hooks[desired.eventName].push({ hooks: [] });
    }

    const group = next.hooks[desired.eventName][0];
    group.hooks ??= [];

    const exists = group.hooks.some((hook) =>
      String(hook.command || "") === desired.command
    );

    if (!exists) {
      const hook = {
        type: "command",
        command: desired.command,
        timeout: desired.timeout
      };
      if (desired.preferFirst) {
        group.hooks.unshift(hook);
      } else {
        group.hooks.push(hook);
      }
    }
  }

  if (JSON.stringify(original, null, 2) !== JSON.stringify(next, null, 2)) {
    if (fs.existsSync(hooksPath)) {
      fs.copyFileSync(hooksPath, backupPath);
    }
    fs.writeFileSync(hooksPath, `${JSON.stringify(next, null, 2)}\n`);
    console.log(`Updated ${hooksPath}`);
    if (fs.existsSync(backupPath)) {
      console.log(`Backup: ${backupPath}`);
    }
  } else {
    console.log(`${hooksPath} already contains Petfy hooks.`);
  }
}

function removeLegacyHooks(config) {
  const legacyFragments = [
    "codex-done.sh",
    "codex-pet-event.sh",
    "codex-pet-notify.sh",
    "pugdex"
  ];

  for (const groups of Object.values(config.hooks || {})) {
    if (!Array.isArray(groups)) {
      continue;
    }

    for (const group of groups) {
      if (!Array.isArray(group.hooks)) {
        continue;
      }

      group.hooks = group.hooks.filter((hook) => {
        const command = String(hook.command || "");
        return !legacyFragments.some((fragment) => command.includes(fragment));
      });
    }
  }
}

function installNotify() {
  const original = fs.existsSync(configPath) ? fs.readFileSync(configPath, "utf8") : "";
  const notifyLine = process.platform === "win32"
    ? `notify = [${JSON.stringify(nodeCommand)}, ${JSON.stringify(hookScriptJs)}, "agent-turn-complete"]`
    : `notify = [${JSON.stringify(notifyScript)}]`;
  const next = upsertTopLevelTomlArray(original, "notify", notifyLine);

  if (next === original) {
    console.log(`${configPath} already contains Petfy notify.`);
    return;
  }

  if (fs.existsSync(configPath)) {
    fs.copyFileSync(configPath, configBackupPath);
  }
  fs.writeFileSync(configPath, next);
  console.log(`Updated ${configPath}`);
  if (fs.existsSync(configBackupPath)) {
    console.log(`Backup: ${configBackupPath}`);
  }
}

function upsertTopLevelTomlArray(input, key, replacementLine) {
  const lines = input.split(/\r?\n/);
  let inTopLevel = true;
  const output = [];
  let replaced = false;

  for (const line of lines) {
    if (/^\s*\[/.test(line)) {
      inTopLevel = false;
    }

    if (inTopLevel && line.trim().startsWith(`${key} =`)) {
      output.push(replacementLine);
      replaced = true;
      continue;
    }

    output.push(line);
  }

  if (!replaced) {
    const insertion = replacementLine;
    if (output.length === 1 && output[0] === "") {
      return `${insertion}\n`;
    }
    const firstSectionIndex = output.findIndex((line) => /^\s*\[/.test(line));
    if (firstSectionIndex === -1) {
      output.push(insertion);
    } else {
      output.splice(firstSectionIndex, 0, insertion, "");
    }
  }

  return `${output.join("\n").replace(/\n*$/, "")}\n`;
}

function readHooksFile(filePath) {
  if (!fs.existsSync(filePath)) {
    return { hooks: {} };
  }

  const text = fs.readFileSync(filePath, "utf8").trim();
  if (!text) {
    return { hooks: {} };
  }

  return JSON.parse(text);
}
