#!/usr/bin/env node
import childProcess from "node:child_process";
import fs from "node:fs";
import path from "node:path";

const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const sourceIcon = path.join(repoRoot, "app", "assets", "brand", "petfy-app-icon-source.png");
const iconDir = path.join(
  repoRoot,
  "app",
  "macos",
  "Runner",
  "Assets.xcassets",
  "AppIcon.appiconset"
);

const icons = [
  ["app_icon_16.png", 16],
  ["app_icon_32.png", 32],
  ["app_icon_64.png", 64],
  ["app_icon_128.png", 128],
  ["app_icon_256.png", 256],
  ["app_icon_512.png", 512],
  ["app_icon_1024.png", 1024]
];

if (!fs.existsSync(sourceIcon)) {
  throw new Error(`Petfy icon source was not found: ${sourceIcon}`);
}

fs.mkdirSync(iconDir, { recursive: true });
for (const [fileName, size] of icons) {
  childProcess.execFileSync(
    "sips",
    ["--resampleHeightWidth", String(size), String(size), sourceIcon, "--out", path.join(iconDir, fileName)],
    { stdio: "inherit" }
  );
}

console.log(`Generated ${icons.length} Petfy macOS app icons from ${sourceIcon}`);
