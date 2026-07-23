# Petfy vX.Y.Z

Petfy is a floating desktop pet for Codex task notifications.

## Downloads

Choose the artifact for your OS:

| OS | Download | Install |
| --- | --- | --- |
| macOS | `Petfy-macos-universal-vX.Y.Z.zip` | Unzip and open `install.command` |
| Windows | `Petfy-windows-x64-vX.Y.Z.zip` | Unzip and double-click `install.cmd` |
| Linux | `Petfy-linux-x64-vX.Y.Z.tar.gz` | Extract and run `./install.sh` |

## Requirements

- Codex CLI, Codex Desktop, or the Codex VS Code extension.
- Node.js available on the machine.
- VS Code CLI is recommended for opening projects from Petfy.

Platform notes:

- macOS: local packages may show a security warning until signed/notarized releases are available.
- Windows: unsigned packages may trigger SmartScreen until signed releases are available.
- Linux: desktop autostart support depends on the user's desktop environment.

## Install

### macOS

1. Download `Petfy-macos-universal-vX.Y.Z.zip`.
2. Unzip it.
3. Open `install.command`.
4. If macOS blocks it, right-click `install.command` and choose Open.

### Windows

1. Download `Petfy-windows-x64-vX.Y.Z.zip`.
2. Unzip it.
3. Double-click `install.cmd`.

### Linux

1. Download `Petfy-linux-x64-vX.Y.Z.tar.gz`.
2. Extract it.
3. Run:

```sh
./install.sh
```

## Diagnostics

Run the diagnostics helper included with your download:

- macOS: `diagnostics.command`
- Windows: `diagnostics.cmd`
- Linux: `diagnostics.sh`

Diagnostics checks:

- app install path;
- runtime bridge;
- Codex hooks;
- Codex notify config;
- startup/autostart registration;
- recent app logs.

## Uninstall

Run the uninstall helper included with your download:

- macOS: `uninstall.command`
- Windows: `uninstall.cmd`
- Linux: `uninstall.sh`

Uninstall removes the app/runtime/startup entry. Local event history is kept under the user's home directory unless manually deleted.

## Security Notes

- Petfy edits user-level Codex config under the user's Codex home.
- Petfy stores local event state under `~/.petfy` or `%USERPROFILE%\.petfy`.
- Petfy does not require admin/root privileges for the current package flow.
- Petfy is independent and not affiliated with, endorsed by, or sponsored by OpenAI.

## Changes

### Added

- ...

### Changed

- ...

### Fixed

- ...

## Known Issues

- Windows and Linux packages must be validated on their target OS before public release.
- Unsigned macOS/Windows builds can trigger OS trust warnings.

## Checksums

```text
SHA256 checksums will be attached as SHA256SUMS.txt.
```
