#!/usr/bin/env node
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const home = os.homedir();
const appName = "Petfy";
const label = "dev.petfy.pet";
const builtBundle = path.join(repoRoot, "app", "build", "linux", "x64", "release", "bundle");
const installRoot = path.join(home, ".local", "share", "petfy");
const installedAppDir = path.join(installRoot, "app");
const supportScriptsDir = path.join(installRoot, "scripts");
const bridgeDir = path.join(installRoot, "bridge");
const launcherPath = path.join(home, ".local", "bin", "petfy");
const applicationsDir = path.join(home, ".local", "share", "applications");
const autostartDir = path.join(home, ".config", "autostart");
const desktopPath = path.join(applicationsDir, `${label}.desktop`);
const autostartPath = path.join(autostartDir, `${label}.desktop`);
const stateDir = process.env.PETFY_STATE_DIR || path.join(home, ".petfy");

const command = process.argv[2] || "status";

switch (command) {
  case "install":
    install();
    break;
  case "start":
    start();
    break;
  case "stop":
    stop();
    break;
  case "uninstall":
    uninstall();
    break;
  case "status":
    status();
    break;
  default:
    console.error(`Unknown command: ${command}`);
    process.exitCode = 1;
}

function install() {
  if (!fs.existsSync(path.join(builtBundle, "petfy"))) {
    fail(`Built Linux bundle not found: ${builtBundle}\nRun this on Linux: ./pet install-linux`);
  }

  fs.mkdirSync(installRoot, { recursive: true });
  fs.mkdirSync(path.dirname(launcherPath), { recursive: true });
  fs.mkdirSync(applicationsDir, { recursive: true });
  fs.mkdirSync(autostartDir, { recursive: true });
  fs.mkdirSync(stateDir, { recursive: true });

  stop();
  fs.rmSync(installedAppDir, { recursive: true, force: true });
  fs.rmSync(bridgeDir, { recursive: true, force: true });
  fs.rmSync(supportScriptsDir, { recursive: true, force: true });

  copyDirectory(builtBundle, installedAppDir);
  copyDirectory(path.join(repoRoot, "bridge"), bridgeDir);
  fs.mkdirSync(supportScriptsDir, { recursive: true });
  copyRuntimeScript("petfy-event.sh");
  copyRuntimeScript("petfy-event.js");
  copyRuntimeScript("petfy-notify.sh");
  copyRuntimeScript("install-codex-integration.js");
  chmodRuntimeScripts();

  fs.writeFileSync(launcherPath, launcherScript(), { mode: 0o755 });
  fs.writeFileSync(desktopPath, desktopEntry({ autostart: false }));
  fs.writeFileSync(autostartPath, desktopEntry({ autostart: true }));

  const nodeBin = findNode();
  if (!nodeBin) {
    console.warn("Warning: Node.js was not found. Codex hooks were not installed.");
  } else {
    run(nodeBin, [path.join(supportScriptsDir, "install-codex-integration.js")], {
      env: { ...process.env, PETFY_NODE_PATH: nodeBin }
    });
  }

  console.log(`Installed app: ${installedAppDir}`);
  console.log(`Installed launcher: ${launcherPath}`);
  console.log(`Installed desktop entry: ${desktopPath}`);
  console.log(`Installed autostart entry: ${autostartPath}`);
  console.log("Run './pet start-linux' or launch Petfy from your desktop menu.");
}

function start() {
  if (!fs.existsSync(launcherPath)) {
    fail(`Launcher not found: ${launcherPath}\nRun: ./pet install-linux`);
  }
  const result = spawnSync(launcherPath, [], {
    detached: true,
    stdio: "ignore"
  });
  if (result.error) {
    fail(result.error.message);
  }
  console.log("Petfy launch requested.");
}

function stop() {
  spawnSync("pkill", ["-x", "petfy"], { encoding: "utf8" });
  spawnSync("pkill", ["-x", appName], { encoding: "utf8" });
  console.log("Petfy stop requested.");
}

function uninstall() {
  stop();
  fs.rmSync(desktopPath, { force: true });
  fs.rmSync(autostartPath, { force: true });
  fs.rmSync(launcherPath, { force: true });
  fs.rmSync(installRoot, { recursive: true, force: true });
  console.log("Removed Petfy Linux app, launcher, and autostart entry.");
  console.log(`User event history was kept at: ${stateDir}`);
}

function status() {
  const checks = [
    ["Installed app", installedAppDir],
    ["Executable", path.join(installedAppDir, "petfy")],
    ["Bridge", path.join(bridgeDir, "src", "cli.js")],
    ["Hook script", path.join(supportScriptsDir, "petfy-event.sh")],
    ["Launcher", launcherPath],
    ["Desktop entry", desktopPath],
    ["Autostart entry", autostartPath],
    ["State dir", stateDir],
    ["Latest event", path.join(stateDir, "latest-event.json")],
    ["History", path.join(stateDir, "events.jsonl")]
  ];

  for (const [name, target] of checks) {
    console.log(`${fs.existsSync(target) ? "ok " : "miss"} ${name}: ${target}`);
  }

  const pgrep = spawnSync("pgrep", ["-x", "petfy"], { encoding: "utf8" });
  console.log(`${pgrep.status === 0 ? "ok " : "miss"} Running process: petfy`);

  const hooksPath = path.join(home, ".codex", "hooks.json");
  const configPath = path.join(home, ".codex", "config.toml");
  console.log(
    `${fileContains(hooksPath, "petfy") ? "ok " : "miss"} Codex hooks: ${hooksPath}`
  );
  console.log(
    `${fileContains(configPath, "petfy-notify") ? "ok " : "miss"} Codex notify: ${configPath}`
  );
}

function copyRuntimeScript(fileName) {
  fs.copyFileSync(
    path.join(repoRoot, "scripts", fileName),
    path.join(supportScriptsDir, fileName)
  );
}

function chmodRuntimeScripts() {
  for (const fileName of ["petfy-event.sh", "petfy-notify.sh"]) {
    fs.chmodSync(path.join(supportScriptsDir, fileName), 0o755);
  }
}

function copyDirectory(from, to) {
  fs.cpSync(from, to, { recursive: true, force: true, verbatimSymlinks: true });
}

function findNode() {
  const explicit = process.env.PETFY_NODE_PATH;
  if (explicit && fs.existsSync(explicit)) {
    return explicit;
  }
  const result = spawnSync("sh", ["-lc", "command -v node"], { encoding: "utf8" });
  return result.status === 0 ? result.stdout.trim() : "";
}

function launcherScript() {
  return `#!/bin/sh
set -eu

export PETFY_ROOT="${installRoot}"
export PETFY_STATE_DIR="\${PETFY_STATE_DIR:-$HOME/.petfy}"
export PETFY_NODE_PATH="\${PETFY_NODE_PATH:-$(command -v node 2>/dev/null || true)}"

mkdir -p "$PETFY_STATE_DIR"
exec "${path.join(installedAppDir, "petfy")}" >> "$PETFY_STATE_DIR/petfy.out.log" 2>> "$PETFY_STATE_DIR/petfy.err.log"
`;
}

function desktopEntry({ autostart }) {
  return `[Desktop Entry]
Type=Application
Name=Petfy
Comment=Floating Codex task pet
Exec=${launcherPath}
Terminal=false
Categories=Utility;Development;
StartupNotify=false
X-GNOME-Autostart-enabled=${autostart ? "true" : "false"}
`;
}

function fileContains(filePath, pattern) {
  return fs.existsSync(filePath) && fs.readFileSync(filePath, "utf8").includes(pattern);
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { encoding: "utf8", ...options });
  if (result.status !== 0) {
    fail(result.stderr || result.stdout || `${command} ${args.join(" ")} failed`);
  }
  return result;
}

function fail(message) {
  console.error(message);
  process.exit(1);
}
