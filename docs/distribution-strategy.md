# Petfy Distribution Strategy

Petfy should be installable by regular Codex users without cloning the repo, installing Flutter, or editing Codex config files manually.

## Target Experience

The final release experience should be:

- User downloads one artifact for their OS from GitHub Releases.
- User opens or runs the installer.
- Installer copies the app and runtime bridge.
- Installer configures startup integration.
- First run verifies or repairs Codex hooks/notify after user approval.
- App opens as a floating pet and shows diagnostics if setup is incomplete.

Terminal usage should be optional. It is acceptable for Linux to offer a one-command install path when that is the normal distro convention, but macOS and Windows should prefer double-clickable installers.

## Artifact Naming

Use stable, predictable names:

```text
Petfy-macos-universal-v0.0.1.zip
Petfy-windows-x64-v0.0.1.zip
Petfy-linux-x64-v0.0.1.tar.gz
```

Future signed/package-native names:

```text
Petfy-macos-universal-v0.0.1.dmg
Petfy-windows-x64-v0.0.1.exe
Petfy-linux-x64-v0.0.1.AppImage
Petfy-linux-amd64-v0.0.1.deb
```

## macOS

Current state:

- `./pet package-macos` creates an ad-hoc signed zip.
- Package includes `install.command`, `diagnostics.command`, and `uninstall.command`.
- Installer copies app to `~/Applications`, runtime files to `~/Library/Application Support/Petfy`, installs Codex integration, enables LaunchAgent autostart, and opens Petfy.

Public target:

- Signed and notarized `.dmg` or `.zip`.
- Prefer `.dmg` for the most familiar Finder flow.
- Keep `diagnostics.command` and `uninstall.command` inside the image or app support docs.

Signing requirements:

- Apple Developer Program.
- Developer ID Application certificate.
- Notarization credentials.
- Hardened runtime.

Current command:

```sh
./pet package-macos-signed
```

Open decision:

- Use `.zip` first because the current script already supports notarized app zips.
- Add `.dmg` after signing is stable.

## Windows

Current state:

- `pet.cmd package-windows` is planned for native Windows.
- Package script creates a zip with `install.cmd`, `diagnostics.cmd`, and `uninstall.cmd`.
- Installer copies app to `%LOCALAPPDATA%\Petfy`, creates `%LOCALAPPDATA%\Petfy\petfy.cmd`, installs a Startup folder shortcut, installs Codex integration, and starts Petfy.
- Windows hooks use the Node event handler `scripts/petfy-event.js` instead of shell scripts.

Public target:

- Signed `.exe` installer.
- Keep portable zip as an advanced/manual fallback.

Recommended installer path:

1. Keep zip + `install.cmd` for internal validation.
2. Add Inno Setup or WiX Toolset after Windows behavior is validated.
3. Sign installer and app executable when ready for public distribution.

Signing requirements:

- Code signing certificate for Windows.
- Timestamping server.
- SmartScreen reputation will still require time/download history unless using EV signing.

Open decision:

- Use Inno Setup first for speed and a friendly installer.
- Consider MSIX later only if Store-style packaging becomes important.

## Linux

Current state:

- `./pet package-linux` is planned for native Linux.
- Package script creates a tarball with `install.sh`, `diagnostics.sh`, and `uninstall.sh`.
- Installer copies app to `~/.local/share/petfy`, creates `~/.local/bin/petfy`, creates a `.desktop` launcher, creates an autostart `.desktop`, installs Codex integration, and starts Petfy.

Public target:

- AppImage for broad desktop compatibility.
- Keep `.tar.gz` as a fallback.
- Add `.deb` later if there is demand from Ubuntu/Debian users.

Recommended installer path:

1. Validate tarball installer.
2. Add AppImage packaging.
3. Consider `.deb` only after AppImage works.

Signing requirements:

- No universal Linux code-signing equivalent.
- Checksums and GitHub release provenance are important.
- Future: publish SHA256 checksums for all Linux artifacts.

Open decision:

- AppImage first for public Linux release.
- Avoid distro-specific package maintenance until usage justifies it.

## GitHub Releases

Each release should include:

- macOS artifact.
- Windows artifact.
- Linux artifact.
- SHA256 checksums.
- Release notes.
- Minimum requirements.
- Install steps.
- Diagnostics and uninstall steps.
- Known trust/security warnings.

Release metadata is tracked in:

- `docs/release-artifacts.json`
- `docs/release-notes-template.md`

Generate local artifact status and checksums with:

```sh
./pet release-manifest
```

Release notes template:

```md
# Petfy vX.Y.Z

## Downloads

- macOS: `Petfy-macos-universal-vX.Y.Z.zip`
- Windows: `Petfy-windows-x64-vX.Y.Z.zip`
- Linux: `Petfy-linux-x64-vX.Y.Z.tar.gz`

## Install

### macOS
Unzip, open `install.command`, then approve macOS prompts if shown.

### Windows
Unzip, double-click `install.cmd`.

### Linux
Extract, run `./install.sh`.

## Diagnostics

- macOS: `diagnostics.command`
- Windows: `diagnostics.cmd`
- Linux: `diagnostics.sh`

## Uninstall

- macOS: `uninstall.command`
- Windows: `uninstall.cmd`
- Linux: `uninstall.sh`

## Security Notes

- Petfy edits user-level Codex config under the user's Codex home.
- Petfy stores local event state under the user's home directory.
- Petfy does not require admin/root privileges.

## Changes

- ...
```

## Workflow Plan

Phase 1: manual artifacts.

- Build macOS on macOS.
- Build Windows on Windows.
- Build Linux on Linux.
- Upload artifacts manually to GitHub Releases.

Phase 2: GitHub Actions.

- `macos-latest`: build/package macOS.
- `windows-latest`: build/package Windows.
- `ubuntu-latest`: build/package Linux.
- Upload artifacts to draft release.
- Generate SHA256 checksums.

Phase 3: signed public releases.

- macOS Developer ID signing and notarization.
- Windows code signing.
- Linux checksums and AppImage.

## Validation Matrix

Before publishing a release:

| OS | Build | Install | Autostart | Codex hooks | Completion event | Focus project | Diagnostics | Uninstall |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| macOS | Required | Required | Required | Required | Required | Required | Required | Required |
| Windows | Required | Required | Required | Required | Required | Required | Required | Required |
| Linux | Required | Required | Required | Required | Required | Required | Required | Required |

## Current Next Steps

1. Validate Windows package on Windows.
2. Validate Linux package on Linux.
3. Add GitHub release artifact naming/checksum script.
4. Add GitHub Actions release workflow in draft mode.
5. Add signing/notarization only after unsigned packages work reliably.
