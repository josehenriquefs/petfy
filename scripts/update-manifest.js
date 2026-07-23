#!/usr/bin/env node
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const releaseManifestPath = path.join(repoRoot, "docs", "release-artifacts.json");
const releaseManifest = JSON.parse(fs.readFileSync(releaseManifestPath, "utf8"));
const distRoot = path.join(repoRoot, "dist");
const updateDir = path.join(distRoot, "update");
const updatePath = path.join(updateDir, "latest.json");
const releaseBaseUrl =
  process.env.PETFY_RELEASE_BASE_URL ||
  `https://github.com/josehenriquefs/petfy/releases/download/${releaseManifest.tag}`;
const releaseNotesUrl =
  process.env.PETFY_RELEASE_NOTES_URL ||
  `https://github.com/josehenriquefs/petfy/releases/tag/${releaseManifest.tag}`;

const artifacts = releaseManifest.artifacts.map((artifact) => {
  const existingPath = existingArtifactPath(artifact);
  return {
    os: artifact.os,
    arch: artifact.arch,
    name: artifact.targetName,
    currentName: artifact.currentName,
    format: artifact.format,
    installer: artifact.installer,
    diagnostics: artifact.diagnostics,
    uninstall: artifact.uninstall,
    url: `${releaseBaseUrl}/${encodeURIComponent(artifact.targetName)}`,
    sha256: existingPath ? sha256(existingPath) : "",
    status: artifact.status,
    notes: artifact.notes
  };
});

const updateManifest = {
  product: releaseManifest.product,
  version: releaseManifest.version,
  tag: releaseManifest.tag,
  mandatory: false,
  minimumSupportedVersion: releaseManifest.version,
  releaseNotesUrl,
  generatedAt: new Date().toISOString(),
  artifacts
};

fs.mkdirSync(updateDir, { recursive: true });
fs.writeFileSync(updatePath, `${JSON.stringify(updateManifest, null, 2)}\n`);

console.log(`Wrote ${path.relative(repoRoot, updatePath)}`);
for (const artifact of artifacts) {
  console.log(`${artifact.sha256 ? "ok " : "miss"} ${artifact.os}/${artifact.arch}: ${artifact.name}`);
}

function existingArtifactPath(artifact) {
  const targetPath = path.join(distRoot, artifact.os, artifact.targetName);
  const currentPath = path.join(distRoot, artifact.os, artifact.currentName);
  if (fs.existsSync(targetPath)) {
    return targetPath;
  }
  if (fs.existsSync(currentPath)) {
    return currentPath;
  }
  return "";
}

function sha256(filePath) {
  const hash = crypto.createHash("sha256");
  hash.update(fs.readFileSync(filePath));
  return hash.digest("hex");
}
