#!/usr/bin/env node
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const packageJson = JSON.parse(fs.readFileSync(path.join(repoRoot, "package.json"), "utf8"));
const appName = "Petfy";
const bundleName = `${appName}.app`;
const version = packageJson.version || "0.0.0";
const productsDir = path.join(repoRoot, "app", "build", "macos", "Build", "Products", "Release");
const builtApp = path.join(productsDir, bundleName);
const distDir = path.join(repoRoot, "dist", "macos");
const packageDir = path.join(distDir, `Petfy-macos-v${version}`);
const payloadDir = path.join(packageDir, "payload");
const supportDir = path.join(payloadDir, "support");
const appPayloadDir = path.join(payloadDir, "app");
const zipPath = path.join(distDir, `Petfy-macos-v${version}.zip`);
const signedMode = process.argv.includes("--signed");
const notarizeMode = process.argv.includes("--notarize") || process.env.PETFY_MACOS_NOTARIZE === "1";
const signIdentity = process.env.PETFY_MACOS_SIGN_IDENTITY || "";
const keychainProfile = process.env.PETFY_NOTARY_KEYCHAIN_PROFILE || "";
const appleId = process.env.PETFY_NOTARY_APPLE_ID || "";
const appleTeamId = process.env.PETFY_NOTARY_TEAM_ID || "";
const applePassword = process.env.PETFY_NOTARY_PASSWORD || "";
const entitlementsPath = path.join(repoRoot, "app", "macos", "Runner", "Release.entitlements");

if (!fs.existsSync(builtApp)) {
  fail(`Built release app not found: ${builtApp}\nRun: ./pet package-macos`);
}
if (signedMode && !signIdentity) {
  fail("Missing PETFY_MACOS_SIGN_IDENTITY. Example: Developer ID Application: Your Name (TEAMID)");
}
if (notarizeMode && !signedMode) {
  fail("Notarization requires --signed.");
}
if (notarizeMode && !hasNotaryCredentials()) {
  fail(
    "Missing notarization credentials. Set PETFY_NOTARY_KEYCHAIN_PROFILE or PETFY_NOTARY_APPLE_ID, PETFY_NOTARY_TEAM_ID, and PETFY_NOTARY_PASSWORD."
  );
}

fs.rmSync(packageDir, { recursive: true, force: true });
fs.rmSync(zipPath, { force: true });
fs.mkdirSync(appPayloadDir, { recursive: true });
fs.mkdirSync(supportDir, { recursive: true });

copyDirectory(builtApp, path.join(appPayloadDir, bundleName));
copyDirectory(path.join(repoRoot, "bridge"), path.join(supportDir, "bridge"));
fs.mkdirSync(path.join(supportDir, "scripts"), { recursive: true });
copyRuntimeScript("petfy-event.sh");
copyRuntimeScript("petfy-event.js");
copyRuntimeScript("petfy-notify.sh");
copyRuntimeScript("install-codex-integration.js");
copyFile("README.md");
copyFile("LICENSE");
copyFile("CHANGELOG.md");

fs.writeFileSync(path.join(packageDir, "install.command"), installerScript(), { mode: 0o755 });
fs.writeFileSync(path.join(packageDir, "diagnostics.command"), diagnosticsScript(), { mode: 0o755 });
fs.writeFileSync(path.join(packageDir, "uninstall.command"), uninstallScript(), { mode: 0o755 });
fs.writeFileSync(path.join(packageDir, "README-INSTALL.txt"), installReadme());

const packagedApp = path.join(appPayloadDir, bundleName);
if (signedMode) {
  developerIdSign(packagedApp);
} else {
  adHocSign(packagedApp);
}

createZip();
if (notarizeMode) {
  notarizeZip();
  stapleApp(packagedApp);
  fs.rmSync(zipPath, { force: true });
  createZip();
}
fs.rmSync(packageDir, { recursive: true, force: true });
removeBuildArtifact(builtApp);

console.log(`Created zip: ${zipPath}`);
console.log("");
if (signedMode && notarizeMode) {
  console.log("Created signed and notarized package.");
} else if (signedMode) {
  console.log("Created signed package. Notarization was not requested.");
} else {
  console.log("Share the zip. The user should unzip it and double-click install.command.");
}

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

function adHocSign(appPath) {
  const result = spawnSync("codesign", ["--force", "--deep", "--sign", "-", appPath], {
    encoding: "utf8"
  });
  if (result.status === 0) {
    console.log("Applied local ad-hoc code signature to packaged app.");
    return;
  }
  console.warn("Warning: could not ad-hoc sign packaged app.");
  console.warn(result.stderr || result.stdout || "codesign failed");
}

function developerIdSign(appPath) {
  const args = [
    "--force",
    "--deep",
    "--options",
    "runtime",
    "--timestamp",
    "--entitlements",
    entitlementsPath,
    "--sign",
    signIdentity,
    appPath
  ];
  run("codesign", args);
  run("codesign", ["--verify", "--deep", "--strict", "--verbose=2", appPath]);
  console.log(`Applied Developer ID signature: ${signIdentity}`);
}

function hasNotaryCredentials() {
  if (keychainProfile) {
    return true;
  }
  return Boolean(appleId && appleTeamId && applePassword);
}

function notaryArgs() {
  if (keychainProfile) {
    return ["--keychain-profile", keychainProfile];
  }
  return ["--apple-id", appleId, "--team-id", appleTeamId, "--password", applePassword];
}

function notarizeZip() {
  run("xcrun", ["notarytool", "submit", zipPath, "--wait", ...notaryArgs()]);
  console.log("Notarization accepted.");
}

function stapleApp(appPath) {
  run("xcrun", ["stapler", "staple", appPath]);
  run("xcrun", ["stapler", "validate", appPath]);
  console.log("Stapled notarization ticket to app.");
}

function createZip() {
  run("ditto", ["-c", "-k", "--norsrc", "--keepParent", packageDir, zipPath]);
}

function removeBuildArtifact(appPath) {
  if (!appPath.includes(`${path.sep}app${path.sep}build${path.sep}`)) {
    return;
  }
  fs.rmSync(appPath, { recursive: true, force: true });
  fs.rmSync(`${appPath}.dSYM`, { recursive: true, force: true });
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { encoding: "utf8", ...options });
  if (result.status !== 0) {
    fail(result.stderr || result.stdout || `${command} ${args.join(" ")} failed`);
  }
  return result;
}

function installerScript() {
  return `#!/bin/zsh
set -euo pipefail

package_dir="$(cd "$(dirname "$0")" && pwd)"
payload_dir="$package_dir/payload"
app_source="$payload_dir/app/${bundleName}"
support_source="$payload_dir/support"
app_dest="$HOME/Applications/${bundleName}"
support_dest="$HOME/Library/Application Support/Petfy"
state_dir="$HOME/.petfy"
launch_agents_dir="$HOME/Library/LaunchAgents"
plist_path="$launch_agents_dir/dev.petfy.pet.plist"
log_path="$state_dir/install.log"
node_path="\${PETFY_NODE_PATH:-}"

find_node() {
  if [ -n "$node_path" ] && [ -x "$node_path" ]; then
    echo "$node_path"
    return 0
  fi

  for candidate in \\
    /opt/homebrew/bin/node \\
    /usr/local/bin/node \\
    /usr/bin/node \\
    /Applications/ChatGPT.app/Contents/Resources/cua_node/bin/node; do
    if [ -x "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  done

  if command -v node >/dev/null 2>&1; then
    command -v node
    return 0
  fi

  return 1
}

node_bin="$(find_node || true)"
if [ -z "$node_bin" ]; then
  echo "Node.js was not found."
  echo "Install Node.js or ChatGPT/Codex Desktop, then run this installer again."
  exit 1
fi

mkdir -p "$HOME/Applications" "$support_dest" "$state_dir" "$launch_agents_dir"
exec > >(tee -a "$log_path") 2>&1

echo "Installing Petfy ${version}"
echo "Package: $package_dir"
echo "Node.js: $node_bin"

launchctl bootout "gui/$(id -u)/dev.petfy.pet" >/dev/null 2>&1 || true
pkill -x Petfy >/dev/null 2>&1 || true

rm -rf "$app_dest"
cp -R "$app_source" "$app_dest"
rm -rf "$support_dest/bridge" "$support_dest/scripts"
cp -R "$support_source/bridge" "$support_dest/bridge"
cp -R "$support_source/scripts" "$support_dest/scripts"
chmod +x "$support_dest/scripts/petfy-event.sh"
chmod +x "$support_dest/scripts/petfy-notify.sh"

/usr/bin/codesign --force --deep --sign - "$app_dest" >/dev/null 2>&1 || true

cat > "$plist_path" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>dev.petfy.pet</string>
  <key>ProgramArguments</key>
  <array>
    <string>$app_dest/Contents/MacOS/Petfy</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PETFY_ROOT</key>
    <string>$support_dest</string>
    <key>PETFY_STATE_DIR</key>
    <string>$state_dir</string>
    <key>PETFY_NODE_PATH</key>
    <string>$node_bin</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <false/>
  <key>StandardOutPath</key>
  <string>$state_dir/petfy.out.log</string>
  <key>StandardErrorPath</key>
  <string>$state_dir/petfy.err.log</string>
</dict>
</plist>
PLIST

PETFY_NODE_PATH="$node_bin" "$node_bin" "$support_dest/scripts/install-codex-integration.js"
launchctl bootstrap "gui/$(id -u)" "$plist_path" >/dev/null 2>&1 || true
launchctl kickstart "gui/$(id -u)/dev.petfy.pet" >/dev/null 2>&1 || true
open "$app_dest" >/dev/null 2>&1 || true

echo ""
echo "Petfy installed."
echo "App: $app_dest"
echo "Runtime: $support_dest"
echo "State: $state_dir"
echo "Log: $log_path"
echo ""
echo "Checks:"
[ -d "$app_dest" ] && echo "ok  App installed" || echo "miss App installed"
[ -x "$app_dest/Contents/MacOS/Petfy" ] && echo "ok  Executable" || echo "miss Executable"
[ -f "$plist_path" ] && echo "ok  LaunchAgent" || echo "miss LaunchAgent"
[ -f "$HOME/.codex/hooks.json" ] && grep -q "petfy" "$HOME/.codex/hooks.json" && echo "ok  Codex hooks" || echo "miss Codex hooks"
[ -f "$HOME/.codex/config.toml" ] && grep -q "petfy-notify" "$HOME/.codex/config.toml" && echo "ok  Codex notify" || echo "miss Codex notify"
echo ""
echo "You can close this window."
`;
}

function diagnosticsScript() {
  return `#!/bin/zsh
set -euo pipefail

app_dest="$HOME/Applications/${bundleName}"
support_dest="$HOME/Library/Application Support/Petfy"
state_dir="$HOME/.petfy"
plist_path="$HOME/Library/LaunchAgents/dev.petfy.pet.plist"

echo "Petfy diagnostics"
echo ""
[ -d "$app_dest" ] && echo "ok  App: $app_dest" || echo "miss App: $app_dest"
[ -x "$app_dest/Contents/MacOS/Petfy" ] && echo "ok  Executable" || echo "miss Executable"
[ -d "$support_dest" ] && echo "ok  Runtime: $support_dest" || echo "miss Runtime: $support_dest"
[ -f "$support_dest/bridge/src/cli.js" ] && echo "ok  Bridge" || echo "miss Bridge"
[ -f "$support_dest/scripts/petfy-event.sh" ] && echo "ok  Hook script" || echo "miss Hook script"
[ -d "$state_dir" ] && echo "ok  State: $state_dir" || echo "miss State: $state_dir"
[ -f "$plist_path" ] && echo "ok  LaunchAgent: $plist_path" || echo "miss LaunchAgent: $plist_path"
launchctl print "gui/$(id -u)/dev.petfy.pet" >/dev/null 2>&1 && echo "ok  LaunchAgent loaded" || echo "miss LaunchAgent loaded"
[ -f "$HOME/.codex/hooks.json" ] && grep -q "petfy" "$HOME/.codex/hooks.json" && echo "ok  Codex hooks" || echo "miss Codex hooks"
[ -f "$HOME/.codex/config.toml" ] && grep -q "petfy-notify" "$HOME/.codex/config.toml" && echo "ok  Codex notify" || echo "miss Codex notify"
command -v node >/dev/null 2>&1 && echo "ok  Node.js: $(command -v node)" || echo "warn Node.js not found in PATH"
echo ""
echo "Recent app log:"
tail -n 20 "$state_dir/petfy.err.log" 2>/dev/null || echo "No error log yet."
echo ""
echo "You can close this window."
`;
}

function uninstallScript() {
  return `#!/bin/zsh
set -euo pipefail

app_dest="$HOME/Applications/${bundleName}"
support_dest="$HOME/Library/Application Support/Petfy"
plist_path="$HOME/Library/LaunchAgents/dev.petfy.pet.plist"

launchctl bootout "gui/$(id -u)/dev.petfy.pet" >/dev/null 2>&1 || true
pkill -x Petfy >/dev/null 2>&1 || true
rm -f "$plist_path"
rm -rf "$app_dest"
rm -rf "$support_dest"

echo "Petfy app, runtime, and LaunchAgent removed."
echo "User event history was kept at: $HOME/.petfy"
echo "Codex hook entries are kept so reinstalling can repair them cleanly."
echo "You can close this window."
`;
}

function installReadme() {
  return `Petfy macOS installer

1. Double-click install.command.
2. If macOS blocks it, right-click install.command and choose Open.
3. The installer stops any old Petfy process, copies Petfy.app to ~/Applications, installs Codex hooks, enables launch at login, and opens Petfy.

Included helpers:

- diagnostics.command: verifies app, runtime, hooks, notify, and LaunchAgent.
- uninstall.command: removes the app, runtime, and LaunchAgent while keeping ~/.petfy event history.

This local package is ad-hoc signed for testing. Public distribution still requires Apple Developer ID signing and notarization.
`;
}

function fail(message) {
  console.error(message);
  process.exit(1);
}
