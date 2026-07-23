#!/usr/bin/env node
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const manifestPath = path.join(repoRoot, "docs", "release-artifacts.json");
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
const distRoot = path.join(repoRoot, "dist");
const checksumPath = path.join(distRoot, "SHA256SUMS.txt");

const rows = [];
for (const artifact of manifest.artifacts) {
  const currentPath = path.join(distRoot, artifact.os, artifact.currentName);
  const targetPath = path.join(distRoot, artifact.os, artifact.targetName);
  const existingPath = fs.existsSync(targetPath)
    ? targetPath
    : fs.existsSync(currentPath)
      ? currentPath
      : "";

  rows.push({
    ...artifact,
    path: existingPath,
    exists: Boolean(existingPath),
    sha256: existingPath ? sha256(existingPath) : ""
  });
}

printSummary(rows);
writeChecksums(rows);

function printSummary(items) {
  console.log(`Petfy ${manifest.tag} release artifacts`);
  console.log("");
  for (const item of items) {
    console.log(`${item.exists ? "ok " : "miss"} ${item.os}/${item.arch}: ${item.targetName}`);
    if (item.exists) {
      console.log(`    path: ${relative(item.path)}`);
      console.log(`    sha256: ${item.sha256}`);
    } else {
      console.log(`    status: ${item.status}`);
    }
  }
}

function writeChecksums(items) {
  const existing = items.filter((item) => item.exists);
  if (existing.length === 0) {
    return;
  }

  fs.mkdirSync(distRoot, { recursive: true });
  const body = existing
    .map((item) => `${item.sha256}  ${path.relative(distRoot, item.path)}`)
    .join("\n");
  fs.writeFileSync(checksumPath, `${body}\n`);
  console.log("");
  console.log(`Wrote ${relative(checksumPath)}`);
}

function sha256(filePath) {
  const hash = crypto.createHash("sha256");
  hash.update(fs.readFileSync(filePath));
  return hash.digest("hex");
}

function relative(filePath) {
  return path.relative(repoRoot, filePath);
}
