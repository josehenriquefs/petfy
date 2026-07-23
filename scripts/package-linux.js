#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const packageJson = JSON.parse(fs.readFileSync(path.join(repoRoot, "package.json"), "utf8"));
const version = packageJson.version || "0.0.0";
const builtBundle = path.join(repoRoot, "app", "build", "linux", "x64", "release", "bundle");
const builtExecutable = path.join(builtBundle, "petfy");
const distDir = path.join(repoRoot, "dist", "linux");
const packageDir = path.join(distDir, `Petfy-linux-x64-v${version}`);
const payloadDir = path.join(packageDir, "payload");
const appPayloadDir = path.join(payloadDir, "app");
const supportDir = path.join(payloadDir, "support");
const archivePath = path.join(distDir, `Petfy-linux-x64-v${version}.tar.gz`);

if (!fs.existsSync(builtExecutable)) {
  fail(`Built Linux bundle not found: ${builtBundle}\nRun this on Linux: ./pet package-linux`);
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

fs.writeFileSync(path.join(packageDir, "install.sh"), installerScript(), { mode: 0o755 });
fs.writeFileSync(path.join(packageDir, "diagnostics.sh"), diagnosticsScript(), { mode: 0o755 });
fs.writeFileSync(path.join(packageDir, "uninstall.sh"), uninstallScript(), { mode: 0o755 });
fs.writeFileSync(path.join(packageDir, "README-INSTALL.txt"), installReadme());

run("tar", ["-czf", archivePath, "-C", distDir, path.basename(packageDir)]);
fs.rmSync(packageDir, { recursive: true, force: true });
removeBuildArtifact();

console.log(`Created archive: ${archivePath}`);
console.log("");
console.log("Share the archive. The user should extract it and run ./install.sh.");

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

function installerScript() {
  return `#!/bin/sh
set -eu

package_dir="$(cd "$(dirname "$0")" && pwd)"
payload_dir="$package_dir/payload"
app_source="$payload_dir/app"
support_source="$payload_dir/support"
install_root="$HOME/.local/share/petfy"
app_dest="$install_root/app"
support_dest="$install_root"
state_dir="\${PETFY_STATE_DIR:-$HOME/.petfy}"
launcher_path="$HOME/.local/bin/petfy"
applications_dir="$HOME/.local/share/applications"
autostart_dir="$HOME/.config/autostart"
desktop_path="$applications_dir/dev.petfy.pet.desktop"
autostart_path="$autostart_dir/dev.petfy.pet.desktop"
log_path="$state_dir/install.log"

find_node() {
  if [ -n "\${PETFY_NODE_PATH:-}" ] && [ -x "$PETFY_NODE_PATH" ]; then
    echo "$PETFY_NODE_PATH"
    return 0
  fi

  if command -v node >/dev/null 2>&1; then
    command -v node
    return 0
  fi

  return 1
}

node_bin="$(find_node || true)"
if [ -z "$node_bin" ]; then
  echo "Node.js was not found."
  echo "Install Node.js, then run this installer again."
  exit 1
fi

mkdir -p "$install_root" "$state_dir" "$HOME/.local/bin" "$applications_dir" "$autostart_dir"
exec >> "$log_path" 2>&1

echo "Installing Petfy ${version}"
echo "Package: $package_dir"
echo "Node.js: $node_bin"

pkill -x petfy >/dev/null 2>&1 || true
rm -rf "$app_dest" "$support_dest/bridge" "$support_dest/scripts"
cp -R "$app_source" "$app_dest"
cp -R "$support_source/bridge" "$support_dest/bridge"
cp -R "$support_source/scripts" "$support_dest/scripts"
chmod +x "$support_dest/scripts/petfy-event.sh" "$support_dest/scripts/petfy-notify.sh"

cat > "$launcher_path" <<LAUNCHER
#!/bin/sh
set -eu
export PETFY_ROOT="$support_dest"
export PETFY_STATE_DIR="\\\${PETFY_STATE_DIR:-$HOME/.petfy}"
export PETFY_NODE_PATH="\\\${PETFY_NODE_PATH:-$node_bin}"
mkdir -p "\\$PETFY_STATE_DIR"
exec "$app_dest/petfy" >> "\\$PETFY_STATE_DIR/petfy.out.log" 2>> "\\$PETFY_STATE_DIR/petfy.err.log"
LAUNCHER
chmod +x "$launcher_path"

cat > "$desktop_path" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Petfy
Comment=Floating Codex task pet
Exec=$launcher_path
Terminal=false
Categories=Utility;Development;
StartupNotify=false
X-GNOME-Autostart-enabled=false
DESKTOP

cp "$desktop_path" "$autostart_path"
sed -i 's/X-GNOME-Autostart-enabled=false/X-GNOME-Autostart-enabled=true/' "$autostart_path" 2>/dev/null || true

PETFY_NODE_PATH="$node_bin" "$node_bin" "$support_dest/scripts/install-codex-integration.js"
nohup "$launcher_path" >/dev/null 2>&1 &

echo "Petfy installed."
echo "App: $app_dest"
echo "Runtime: $support_dest"
echo "State: $state_dir"
echo "Launcher: $launcher_path"
`;
}

function diagnosticsScript() {
  return `#!/bin/sh
set -eu

install_root="$HOME/.local/share/petfy"
app_dest="$install_root/app"
state_dir="\${PETFY_STATE_DIR:-$HOME/.petfy}"
launcher_path="$HOME/.local/bin/petfy"
desktop_path="$HOME/.local/share/applications/dev.petfy.pet.desktop"
autostart_path="$HOME/.config/autostart/dev.petfy.pet.desktop"

echo "Petfy Linux diagnostics"
echo ""
[ -d "$app_dest" ] && echo "ok  App: $app_dest" || echo "miss App: $app_dest"
[ -x "$app_dest/petfy" ] && echo "ok  Executable" || echo "miss Executable"
[ -f "$install_root/bridge/src/cli.js" ] && echo "ok  Bridge" || echo "miss Bridge"
[ -f "$install_root/scripts/petfy-event.sh" ] && echo "ok  Hook script" || echo "miss Hook script"
[ -x "$launcher_path" ] && echo "ok  Launcher: $launcher_path" || echo "miss Launcher: $launcher_path"
[ -f "$desktop_path" ] && echo "ok  Desktop entry: $desktop_path" || echo "miss Desktop entry: $desktop_path"
[ -f "$autostart_path" ] && echo "ok  Autostart: $autostart_path" || echo "miss Autostart: $autostart_path"
[ -d "$state_dir" ] && echo "ok  State: $state_dir" || echo "miss State: $state_dir"
pgrep -x petfy >/dev/null 2>&1 && echo "ok  Running process" || echo "miss Running process"
[ -f "$HOME/.codex/hooks.json" ] && grep -q "petfy" "$HOME/.codex/hooks.json" && echo "ok  Codex hooks" || echo "miss Codex hooks"
[ -f "$HOME/.codex/config.toml" ] && grep -q "petfy-notify" "$HOME/.codex/config.toml" && echo "ok  Codex notify" || echo "miss Codex notify"
command -v node >/dev/null 2>&1 && echo "ok  Node.js: $(command -v node)" || echo "warn Node.js not found in PATH"
echo ""
echo "Recent app log:"
tail -n 20 "$state_dir/petfy.err.log" 2>/dev/null || echo "No error log yet."
`;
}

function uninstallScript() {
  return `#!/bin/sh
set -eu

install_root="$HOME/.local/share/petfy"
launcher_path="$HOME/.local/bin/petfy"
desktop_path="$HOME/.local/share/applications/dev.petfy.pet.desktop"
autostart_path="$HOME/.config/autostart/dev.petfy.pet.desktop"

pkill -x petfy >/dev/null 2>&1 || true
rm -f "$launcher_path" "$desktop_path" "$autostart_path"
rm -rf "$install_root"

echo "Petfy Linux app, launcher, and autostart entry removed."
echo "User event history was kept at: $HOME/.petfy"
`;
}

function installReadme() {
  return `Petfy Linux installer

1. Extract this archive.
2. Run ./install.sh from a terminal.
3. The installer copies Petfy to ~/.local/share/petfy, creates ~/.local/bin/petfy, installs Codex hooks, enables desktop autostart, and starts Petfy.

Included helpers:

- diagnostics.sh: verifies app, runtime, hooks, notify, launcher, and autostart.
- uninstall.sh: removes the app, launcher, and autostart while keeping ~/.petfy event history.

Requirements:

- Linux desktop session with Flutter Linux runtime dependencies available.
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
