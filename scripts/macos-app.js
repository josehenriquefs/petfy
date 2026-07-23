#!/usr/bin/env node
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const home = os.homedir();
const appName = "Petfy";
const bundleName = `${appName}.app`;
const label = "dev.petfy.pet";
const productsRoot = path.join(repoRoot, "app", "build", "macos", "Build", "Products");
const releaseProductsDir = path.join(productsRoot, "Release");
const debugProductsDir = path.join(productsRoot, "Debug");
const installDir = path.join(home, "Applications");
const installedApp = path.join(installDir, bundleName);
const launchAgentsDir = path.join(home, "Library", "LaunchAgents");
const plistPath = path.join(launchAgentsDir, `${label}.plist`);
const stateDir = process.env.PETFY_STATE_DIR || path.join(home, ".petfy");
const legacyApp = path.join(installDir, "Pugdex.app");
const legacyLabel = "dev.pugdex.pet";
const legacyPlistPath = path.join(launchAgentsDir, `${legacyLabel}.plist`);

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
  const builtApp = findBuiltApp();
  if (!fs.existsSync(builtApp)) {
    fail(`Built app not found in: ${releaseProductsDir}\nRun: ./pet install-app`);
  }

  fs.mkdirSync(installDir, { recursive: true });
  fs.mkdirSync(launchAgentsDir, { recursive: true });
  fs.mkdirSync(stateDir, { recursive: true });

  removeLegacyPugdexInstall();
  fs.rmSync(installedApp, { recursive: true, force: true });
  copyDirectory(builtApp, installedApp);
  adHocSign(installedApp);
  removeBuildArtifact(builtApp);
  fs.writeFileSync(plistPath, launchAgentPlist());

  console.log(`Installed app: ${installedApp}`);
  console.log(`Installed LaunchAgent: ${plistPath}`);
  console.log("Run './pet start-app' to start it now, or log in again to start automatically.");
}

function removeLegacyPugdexInstall() {
  runLaunchctl(["bootout", `gui/${process.getuid()}/${legacyLabel}`], { allowFailure: true });
  spawnSync("pkill", ["-x", "Pugdex"], { encoding: "utf8" });
  fs.rmSync(legacyPlistPath, { force: true });
  fs.rmSync(legacyApp, { recursive: true, force: true });
}

function start() {
  if (!fs.existsSync(plistPath)) {
    fail(`LaunchAgent not found: ${plistPath}\nRun: ./pet install-app`);
  }

  runLaunchctl(["bootstrap", `gui/${process.getuid()}`, plistPath], { allowFailure: true });
  runLaunchctl(["kickstart", `gui/${process.getuid()}/${label}`], { allowFailure: true });
  console.log("Petfy launch requested.");
}

function stop() {
  runLaunchctl(["bootout", `gui/${process.getuid()}/${label}`], { allowFailure: true });
  spawnSync("pkill", ["-x", appName], { encoding: "utf8" });
  console.log("Petfy stop requested.");
}

function uninstall() {
  stop();
  fs.rmSync(plistPath, { force: true });
  fs.rmSync(installedApp, { recursive: true, force: true });
  console.log("Removed Petfy app and LaunchAgent.");
}

function status() {
  const executable = resolveAppExecutable(installedApp, { allowMissing: true });
  const checks = [
    ["Installed app", installedApp],
    ["Executable", executable || path.join(installedApp, "Contents", "MacOS", appName)],
    ["LaunchAgent", plistPath],
    ["State dir", stateDir],
    ["Latest event", path.join(stateDir, "latest-event.json")],
    ["History", path.join(stateDir, "events.jsonl")]
  ];

  for (const [name, target] of checks) {
    console.log(`${fs.existsSync(target) ? "ok " : "miss"} ${name}: ${target}`);
  }

  const launchctl = spawnSync("launchctl", ["print", `gui/${process.getuid()}/${label}`], {
    encoding: "utf8"
  });
  console.log(`${launchctl.status === 0 ? "ok " : "miss"} LaunchAgent loaded: ${label}`);
}

function copyDirectory(from, to) {
  fs.cpSync(from, to, { recursive: true, force: true, verbatimSymlinks: true });
}

function findBuiltApp({ allowMissing = false } = {}) {
  for (const productsDir of [releaseProductsDir, debugProductsDir]) {
    const preferred = path.join(productsDir, bundleName);
    if (fs.existsSync(preferred)) {
      return preferred;
    }

    if (fs.existsSync(productsDir)) {
      const apps = fs
        .readdirSync(productsDir)
        .filter((entry) => entry.endsWith(".app"))
        .map((entry) => path.join(productsDir, entry));
      if (apps.length > 0) {
        return apps[0];
      }
    }
  }

  if (allowMissing) {
    return null;
  }
  return path.join(releaseProductsDir, bundleName);
}

function resolveAppExecutable(appPath, { allowMissing = false } = {}) {
  const macosDir = path.join(appPath, "Contents", "MacOS");
  const preferred = path.join(macosDir, appName);
  if (fs.existsSync(preferred)) {
    return preferred;
  }
  if (fs.existsSync(macosDir)) {
    const executableNames = fs.readdirSync(macosDir).filter((entry) => {
      const target = path.join(macosDir, entry);
      return fs.statSync(target).isFile();
    });
    if (executableNames.length > 0) {
      return path.join(macosDir, executableNames[0]);
    }
  }
  if (allowMissing) {
    return null;
  }
  return preferred;
}

function adHocSign(appPath) {
  const result = spawnSync("codesign", ["--force", "--deep", "--sign", "-", appPath], {
    encoding: "utf8"
  });
  if (result.status === 0) {
    console.log("Applied local ad-hoc code signature.");
    return;
  }
  console.warn("Warning: could not ad-hoc sign the app.");
  console.warn(result.stderr || result.stdout || "codesign failed");
}

function removeBuildArtifact(appPath) {
  if (!appPath.includes(`${path.sep}app${path.sep}build${path.sep}`)) {
    return;
  }
  fs.rmSync(appPath, { recursive: true, force: true });
  fs.rmSync(`${appPath}.dSYM`, { recursive: true, force: true });
}

function runLaunchctl(args, { allowFailure = false } = {}) {
  const result = spawnSync("launchctl", args, { encoding: "utf8" });
  if (result.status !== 0 && !allowFailure) {
    fail(result.stderr || result.stdout || `launchctl ${args.join(" ")} failed`);
  }
}

function launchAgentPlist() {
  const executable = resolveAppExecutable(installedApp);
  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${label}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${escapeXml(executable)}</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PETFY_ROOT</key>
    <string>${escapeXml(repoRoot)}</string>
    <key>PETFY_STATE_DIR</key>
    <string>${escapeXml(stateDir)}</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <false/>
  <key>StandardOutPath</key>
  <string>${escapeXml(path.join(stateDir, "petfy.out.log"))}</string>
  <key>StandardErrorPath</key>
  <string>${escapeXml(path.join(stateDir, "petfy.err.log"))}</string>
</dict>
</plist>
`;
}

function escapeXml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

function fail(message) {
  console.error(message);
  process.exit(1);
}
