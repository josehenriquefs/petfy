#!/usr/bin/env node
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const home = os.homedir();
const localAppData = process.env.LOCALAPPDATA || path.join(home, "AppData", "Local");
const appName = "Petfy";
const builtBundle = path.join(repoRoot, "app", "build", "windows", "x64", "runner", "Release");
const installRoot = path.join(localAppData, "Petfy");
const installedAppDir = path.join(installRoot, "app");
const bridgeDir = path.join(installRoot, "bridge");
const supportScriptsDir = path.join(installRoot, "scripts");
const launcherPath = path.join(installRoot, "petfy.cmd");
const stateDir = process.env.PETFY_STATE_DIR || path.join(home, ".petfy");
const startupDir = path.join(
  process.env.APPDATA || path.join(home, "AppData", "Roaming"),
  "Microsoft",
  "Windows",
  "Start Menu",
  "Programs",
  "Startup"
);
const startupShortcut = path.join(startupDir, "Petfy.lnk");

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
  if (!fs.existsSync(path.join(builtBundle, "petfy.exe"))) {
    fail(`Built Windows bundle not found: ${builtBundle}\nRun this on Windows: .\\pet install-windows`);
  }

  fs.mkdirSync(installRoot, { recursive: true });
  fs.mkdirSync(stateDir, { recursive: true });
  fs.mkdirSync(startupDir, { recursive: true });

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

  const nodeBin = findNode();
  fs.writeFileSync(launcherPath, launcherScript(nodeBin));
  createStartupShortcut();

  if (!nodeBin) {
    console.warn("Warning: Node.js was not found. Codex hooks were not installed.");
  } else {
    run(nodeBin, [path.join(supportScriptsDir, "install-codex-integration.js")], {
      env: { ...process.env, PETFY_NODE_PATH: nodeBin }
    });
  }

  console.log(`Installed app: ${installedAppDir}`);
  console.log(`Installed launcher: ${launcherPath}`);
  console.log(`Installed startup shortcut: ${startupShortcut}`);
  console.log("Run '.\\pet start-windows' or double-click the Petfy startup shortcut.");
}

function start() {
  if (!fs.existsSync(launcherPath)) {
    fail(`Launcher not found: ${launcherPath}\nRun: .\\pet install-windows`);
  }
  const result = spawnSync("cmd.exe", ["/c", "start", "", launcherPath], {
    detached: true,
    stdio: "ignore"
  });
  if (result.error) {
    fail(result.error.message);
  }
  console.log("Petfy launch requested.");
}

function stop() {
  spawnSync("taskkill.exe", ["/IM", "petfy.exe", "/F"], { encoding: "utf8" });
  console.log("Petfy stop requested.");
}

function uninstall() {
  stop();
  fs.rmSync(startupShortcut, { force: true });
  fs.rmSync(installRoot, { recursive: true, force: true });
  console.log("Removed Petfy Windows app and startup shortcut.");
  console.log(`User event history was kept at: ${stateDir}`);
}

function status() {
  const checks = [
    ["Installed app", installedAppDir],
    ["Executable", path.join(installedAppDir, "petfy.exe")],
    ["Bridge", path.join(bridgeDir, "src", "cli.js")],
    ["Hook script", path.join(supportScriptsDir, "petfy-event.sh")],
    ["Launcher", launcherPath],
    ["Startup shortcut", startupShortcut],
    ["State dir", stateDir],
    ["Latest event", path.join(stateDir, "latest-event.json")],
    ["History", path.join(stateDir, "events.jsonl")]
  ];

  for (const [name, target] of checks) {
    console.log(`${fs.existsSync(target) ? "ok " : "miss"} ${name}: ${target}`);
  }

  const tasklist = spawnSync("tasklist.exe", ["/FI", "IMAGENAME eq petfy.exe"], {
    encoding: "utf8"
  });
  console.log(
    `${tasklist.stdout?.includes("petfy.exe") ? "ok " : "miss"} Running process: petfy.exe`
  );

  const codexHome = process.env.CODEX_HOME || path.join(home, ".codex");
  const hooksPath = path.join(codexHome, "hooks.json");
  const configPath = path.join(codexHome, "config.toml");
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

function copyDirectory(from, to) {
  fs.cpSync(from, to, { recursive: true, force: true, verbatimSymlinks: true });
}

function findNode() {
  const explicit = process.env.PETFY_NODE_PATH;
  if (explicit && fs.existsSync(explicit)) {
    return explicit;
  }
  for (const command of ["node.exe", "node"]) {
    const result = spawnSync("where.exe", [command], { encoding: "utf8" });
    if (result.status === 0) {
      return result.stdout.split(/\r?\n/).find(Boolean) || "";
    }
  }
  return "";
}

function launcherScript(nodeBin) {
  return `@echo off
setlocal
set "PETFY_ROOT=${installRoot}"
if "%PETFY_STATE_DIR%"=="" set "PETFY_STATE_DIR=%USERPROFILE%\\.petfy"
if "%PETFY_NODE_PATH%"=="" set "PETFY_NODE_PATH=${nodeBin}"
if not exist "%PETFY_STATE_DIR%" mkdir "%PETFY_STATE_DIR%"
start "" "${path.join(installedAppDir, "petfy.exe")}"
`;
}

function createStartupShortcut() {
  const script = [
    "$shell = New-Object -ComObject WScript.Shell",
    `$shortcut = $shell.CreateShortcut(${JSON.stringify(startupShortcut)})`,
    `$shortcut.TargetPath = ${JSON.stringify(launcherPath)}`,
    `$shortcut.WorkingDirectory = ${JSON.stringify(installRoot)}`,
    "$shortcut.WindowStyle = 7",
    "$shortcut.Save()"
  ].join("; ");
  run("powershell.exe", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script]);
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
