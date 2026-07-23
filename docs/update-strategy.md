# Petfy Update Strategy

Petfy should eventually notify users when a newer release is available and guide them to a safe install flow for their OS.

## Goal

The updater should be conservative:

- Never silently replace binaries in the background.
- Never edit Codex config during an update without user approval.
- Prefer "download and run installer" for early releases.
- Verify version and checksum metadata before offering an update.
- Keep diagnostics available if update setup fails.

## Phases

### Phase 1: Update Feed

Status: published and validated for `josehenriquefs/petfy`.

Publish a static JSON feed with each release:

```text
dist/update/latest.json
```

The feed includes:

- latest version;
- release notes URL;
- artifact names;
- artifact URLs;
- SHA256 checksums when available;
- minimum supported app version;
- whether the update is mandatory.

This phase does not auto-install anything. It gives the app and website a stable source of truth.

### Phase 2: In-App Update Check

Status: implemented as a safe handoff flow.

Add a Settings action:

```text
Check for updates
```

The app should:

1. Fetch `latest.json`.
2. Compare semantic version against the current app version.
3. Show one of:
   - up to date;
   - update available;
   - unable to check;
   - update required.
4. Open the release page or download URL.
5. Offer direct artifact download only when the current OS artifact includes a checksum.

The feed URL can be compiled into the Flutter build with:

```text
--dart-define=PETFY_UPDATE_FEED_URL=https://raw.githubusercontent.com/josehenriquefs/petfy/main/dist/update/latest.json
```

Local development builds fall back to `dist/update/latest.json` when that file exists.

### Phase 3: Guided Installer Handoff

Status: initial implementation.

When an update is available:

- macOS: open the signed/notarized `.dmg` or GitHub release page.
- Windows: open the signed `.exe` installer or GitHub release page.
- Linux: open AppImage/tarball instructions or GitHub release page.

The app should not self-overwrite while running in this phase.

### Phase 4: Native Auto-Updater

Only after packages are signed and stable:

- macOS: consider Sparkle or a signed helper.
- Windows: consider Squirrel, WinSparkle, MSIX, or installer-managed updates.
- Linux: prefer AppImage update flow or package-manager updates if `.deb`/`.rpm` exists.

This phase depends on signing and public release infrastructure.

## Feed Shape

Example:

```json
{
  "product": "Petfy",
  "version": "0.0.1",
  "tag": "v0.0.1",
  "mandatory": false,
  "minimumSupportedVersion": "0.0.1",
  "releaseNotesUrl": "https://github.com/josehenriquefs/petfy/releases/tag/v0.0.1",
  "artifacts": [
    {
      "os": "macos",
      "arch": "universal",
      "name": "Petfy-macos-universal-v0.0.1.zip",
      "url": "https://github.com/josehenriquefs/petfy/releases/download/v0.0.1/Petfy-macos-universal-v0.0.1.zip",
      "sha256": "..."
    }
  ]
}
```

## Current Next Steps

1. Commit and publish `dist/update/latest.json` on `main`.
2. Publish the matching artifact in a GitHub Release.
3. Validate the public raw feed and the release download URL.
4. Add native auto-update only after signing/notarization is ready.
