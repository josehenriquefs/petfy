#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const packageJson = JSON.parse(fs.readFileSync(path.join(repoRoot, "package.json"), "utf8"));
const version = packageJson.version || "0.0.0";
const builtBundle = path.join(repoRoot, "app", "build", "windows", "x64", "runner", "Release");
const builtExecutable = path.join(builtBundle, "petfy.exe");
const distDir = path.join(repoRoot, "dist", "windows");
const packageDir = path.join(distDir, `Petfy-windows-x64-v${version}`);
const payloadDir = path.join(packageDir, "payload");
const appPayloadDir = path.join(payloadDir, "app");
const supportDir = path.join(payloadDir, "support");
const archivePath = path.join(distDir, `Petfy-windows-x64-v${version}.zip`);

if (!fs.existsSync(builtExecutable)) {
  fail(`Built Windows bundle not found: ${builtBundle}\nRun this on Windows: .\\pet package-windows`);
}

fs.rmSync(packageDir, { recursive: true, force: true });
fs.rmSync(archivePath, { force: true });
fs.mkdirSync(appPayloadDir, { recursive: true });
fs.mkdirSync(supportDir, { recursive: true });

copyDirectory(builtBundle, appPayloadDir);
copyDirectory(path.join(repoRoot, "bridge"), path.join(supportDir, "bridge"));
fs.mkdirSync(path.join(supportDir, "scripts"), { recursive: true });
copyRuntimeScript("petfy-event.sh");
copyRuntimeScript("petfy-event.js");
copyRuntimeScript("petfy-notify.sh");
copyRuntimeScript("install-codex-integration.js");
copyFile("README.md");
copyFile("LICENSE");
copyFile("CHANGELOG.md");

fs.writeFileSync(path.join(packageDir, "install.cmd"), installerScript());
fs.writeFileSync(path.join(packageDir, "diagnostics.cmd"), diagnosticsScript());
fs.writeFileSync(path.join(packageDir, "uninstall.cmd"), uninstallScript());
fs.writeFileSync(path.join(packageDir, "README-INSTALL.txt"), installReadme());

zipPackage();
fs.rmSync(packageDir, { recursive: true, force: true });
removeBuildArtifact();

console.log(`Created zip: ${archivePath}`);
console.log("");
console.log("Share the zip. The user should unzip it and double-click install.cmd.");

function copyFile(fileName) {
  fs.copyFileSync(path.join(repoRoot, fileName), path.join(packageDir, fileName));
}

function copyRuntimeScript(fileName) {
  fs.copyFileSync(
    path.join(repoRoot, "scripts", fileName),
    path.join(supportDir, "scripts", fileName)
  );
}

function copyDirectory(from, to) {
  fs.cpSync(from, to, { recursive: true, force: true, verbatimSymlinks: true });
}

function removeBuildArtifact() {
  if (!builtBundle.includes(`${path.sep}app${path.sep}build${path.sep}`)) {
    return;
  }
  fs.rmSync(builtBundle, { recursive: true, force: true });
}

function zipPackage() {
  const script = [
    "Compress-Archive",
    "-Path",
    JSON.stringify(packageDir),
    "-DestinationPath",
    JSON.stringify(archivePath),
    "-Force"
  ].join(" ");
  run("powershell.exe", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script]);
}

function installerScript() {
  return `@echo off
setlocal EnableExtensions

set "PACKAGE_DIR=%~dp0"
set "PAYLOAD_DIR=%PACKAGE_DIR%payload"
set "APP_SOURCE=%PAYLOAD_DIR%\\app"
set "SUPPORT_SOURCE=%PAYLOAD_DIR%\\support"
set "INSTALL_ROOT=%LOCALAPPDATA%\\Petfy"
set "APP_DEST=%INSTALL_ROOT%\\app"
set "STATE_DIR=%USERPROFILE%\\.petfy"
set "LAUNCHER=%INSTALL_ROOT%\\petfy.cmd"
set "STARTUP_DIR=%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs\\Startup"
set "STARTUP_SHORTCUT=%STARTUP_DIR%\\Petfy.lnk"
set "LOG_PATH=%STATE_DIR%\\install.log"

where node.exe >nul 2>nul
if errorlevel 1 (
  echo Node.js was not found.
  echo Install Node.js, then run this installer again.
  pause
  exit /b 1
)
for /f "usebackq delims=" %%N in (\`where node.exe\`) do (
  set "NODE_BIN=%%N"
  goto :found_node
)
:found_node

if not exist "%INSTALL_ROOT%" mkdir "%INSTALL_ROOT%"
if not exist "%STATE_DIR%" mkdir "%STATE_DIR%"
if not exist "%STARTUP_DIR%" mkdir "%STARTUP_DIR%"

echo Installing Petfy ${version}>>"%LOG_PATH%"
echo Package: %PACKAGE_DIR%>>"%LOG_PATH%"
echo Node.js: %NODE_BIN%>>"%LOG_PATH%"

taskkill /IM petfy.exe /F >nul 2>nul
rmdir /S /Q "%APP_DEST%" >nul 2>nul
rmdir /S /Q "%INSTALL_ROOT%\\bridge" >nul 2>nul
rmdir /S /Q "%INSTALL_ROOT%\\scripts" >nul 2>nul

xcopy "%APP_SOURCE%" "%APP_DEST%\\" /E /I /Y >nul
xcopy "%SUPPORT_SOURCE%\\bridge" "%INSTALL_ROOT%\\bridge\\" /E /I /Y >nul
xcopy "%SUPPORT_SOURCE%\\scripts" "%INSTALL_ROOT%\\scripts\\" /E /I /Y >nul

(
  echo @echo off
  echo setlocal
  echo set "PETFY_ROOT=%INSTALL_ROOT%"
  echo if "%%PETFY_STATE_DIR%%"=="" set "PETFY_STATE_DIR=%%USERPROFILE%%\\.petfy"
  echo if "%%PETFY_NODE_PATH%%"=="" set "PETFY_NODE_PATH=%NODE_BIN%"
  echo if not exist "%%PETFY_STATE_DIR%%" mkdir "%%PETFY_STATE_DIR%%"
  echo start "" "%APP_DEST%\\petfy.exe"
) > "%LAUNCHER%"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$shell = New-Object -ComObject WScript.Shell; $shortcut = $shell.CreateShortcut('%STARTUP_SHORTCUT%'); $shortcut.TargetPath = '%LAUNCHER%'; $shortcut.WorkingDirectory = '%INSTALL_ROOT%'; $shortcut.WindowStyle = 7; $shortcut.Save()"

set "PETFY_NODE_PATH=%NODE_BIN%"
"%NODE_BIN%" "%INSTALL_ROOT%\\scripts\\install-codex-integration.js"
call "%LAUNCHER%"

echo Petfy installed.
echo App: %APP_DEST%
echo Runtime: %INSTALL_ROOT%
echo State: %STATE_DIR%
echo.
pause
`;
}

function diagnosticsScript() {
  return `@echo off
setlocal EnableExtensions

set "INSTALL_ROOT=%LOCALAPPDATA%\\Petfy"
set "APP_DEST=%INSTALL_ROOT%\\app"
set "STATE_DIR=%USERPROFILE%\\.petfy"
set "LAUNCHER=%INSTALL_ROOT%\\petfy.cmd"
set "STARTUP_SHORTCUT=%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs\\Startup\\Petfy.lnk"

echo Petfy Windows diagnostics
echo.
if exist "%APP_DEST%" (echo ok  App: %APP_DEST%) else (echo miss App: %APP_DEST%)
if exist "%APP_DEST%\\petfy.exe" (echo ok  Executable) else (echo miss Executable)
if exist "%INSTALL_ROOT%\\bridge\\src\\cli.js" (echo ok  Bridge) else (echo miss Bridge)
if exist "%INSTALL_ROOT%\\scripts\\petfy-event.sh" (echo ok  Hook script) else (echo miss Hook script)
if exist "%LAUNCHER%" (echo ok  Launcher: %LAUNCHER%) else (echo miss Launcher: %LAUNCHER%)
if exist "%STARTUP_SHORTCUT%" (echo ok  Startup shortcut: %STARTUP_SHORTCUT%) else (echo miss Startup shortcut: %STARTUP_SHORTCUT%)
if exist "%STATE_DIR%" (echo ok  State: %STATE_DIR%) else (echo miss State: %STATE_DIR%)
tasklist /FI "IMAGENAME eq petfy.exe" | findstr /I "petfy.exe" >nul && echo ok  Running process || echo miss Running process
if exist "%USERPROFILE%\\.codex\\hooks.json" (findstr /C:"petfy" "%USERPROFILE%\\.codex\\hooks.json" >nul && echo ok  Codex hooks || echo miss Codex hooks) else echo miss Codex hooks
if exist "%USERPROFILE%\\.codex\\config.toml" (findstr /C:"petfy-notify" "%USERPROFILE%\\.codex\\config.toml" >nul && echo ok  Codex notify || echo miss Codex notify) else echo miss Codex notify
where node.exe >nul 2>nul && echo ok  Node.js || echo warn Node.js not found in PATH
echo.
pause
`;
}

function uninstallScript() {
  return `@echo off
setlocal EnableExtensions

set "INSTALL_ROOT=%LOCALAPPDATA%\\Petfy"
set "STARTUP_SHORTCUT=%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs\\Startup\\Petfy.lnk"

taskkill /IM petfy.exe /F >nul 2>nul
del /F /Q "%STARTUP_SHORTCUT%" >nul 2>nul
rmdir /S /Q "%INSTALL_ROOT%" >nul 2>nul

echo Petfy Windows app and startup shortcut removed.
echo User event history was kept at: %USERPROFILE%\\.petfy
pause
`;
}

function installReadme() {
  return `Petfy Windows installer

1. Extract this zip.
2. Double-click install.cmd.
3. The installer copies Petfy to %LOCALAPPDATA%\\Petfy, creates a startup shortcut, installs Codex hooks, and starts Petfy.

Included helpers:

- diagnostics.cmd: verifies app, runtime, hooks, notify, launcher, and startup shortcut.
- uninstall.cmd: removes the app and startup shortcut while keeping %USERPROFILE%\\.petfy event history.

Requirements:

- Windows desktop session.
- Node.js available in PATH.
`;
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
