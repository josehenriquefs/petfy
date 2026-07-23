# Petfy

Floating desktop companion for Codex task notifications.

Petfy is a small Flutter desktop app that stays above your windows, listens for Codex lifecycle events, and lets you jump back to the project that just finished. It is built for people who use Codex across the CLI, Desktop app, and VS Code extension and want one lightweight visual signal for completed work or required attention.

Current version: `v0.0.1`

## Project Documents

- [Current status and resume checklist](docs/current-status.md)
- [Roadmap checklist](docs/roadmap-checklist.md)
- [Event contract](docs/event-contract.md)
- [Distribution strategy](docs/distribution-strategy.md)

Petfy is an independent project and is not affiliated with, endorsed by, or sponsored by OpenAI.

## Current Status

This is an early macOS-first MVP with Linux and Windows setup scripts now available for validation on their target desktops.

Implemented:

- Floating transparent pet window.
- Drag to reposition.
- Completion notifications from the existing trusted Codex hook.
- Local event bridge that writes to `~/.petfy`.
- Click the pet to open the completed project in VS Code.
- Popover for multiple tasks.
- Clear notifications from the app or terminal.
- Different visual state for completed, working, and attention events.
- Native macOS sounds for completed and attention events.
- First-run setup, diagnostics, and repair from inside the app.
- Settings for sounds, animations, pet bubble, dark panel, launch at login, and auto-clear duration.
- Local macOS package with install, diagnostics, and uninstall commands.
- Linux local install/package scripts with desktop entry and autostart.
- Windows local install/package scripts with startup shortcut.

In progress:

- Better animated pug mascot.
- Signed/releasable macOS app.
- Linux build validation on real Linux desktops.
- Windows build validation on real Windows desktops.
- Reliable live running/attention events across all Codex surfaces.

## How It Works

```text
Codex CLI / Desktop / VS Code
        |
        | hooks / notify scripts
        v
petfy bridge
        |
        | ~/.petfy/latest-event.json
        | ~/.petfy/events.jsonl
        v
Flutter floating pet
```

The current completion path uses the direct Petfy `Stop` hook. The bridge normalizes that event into:

```json
{
  "type": "task.completed",
  "cwd": "/path/to/project",
  "projectName": "project"
}
```

The Flutter app watches the event files and updates the pet.

## Repository

```text
app/       Flutter desktop app
bridge/    Node-based event normalizer and focus helper
scripts/   Codex integration and local Flutter wrapper
docs/      Architecture, contracts, and project planning
examples/  Sample Codex configuration
pet        Project command wrapper
```

Flutter is installed locally under `.tooling/flutter` for this repository. You do not need a global Flutter install for local development.

## Development

From the project root:

```sh
./pet dev
./pet dev-linux
./pet dev-windows
./pet analyze
./pet test
./pet clear
./pet latest
./pet doctor
./pet doctor-linux
./pet doctor-windows
```

Open in VS Code:

```sh
./pet open
```

Run the macOS app:

```sh
./pet dev
```

Use `./pet dev` instead of calling `flutter run` directly. It passes the repository and state paths into the macOS app so it reads `~/.petfy/latest-event.json` instead of a sandbox container path.

If `xcodebuild` fails inside a sandboxed Codex session, run the same command in a normal macOS terminal.

## Real Codex Events

Install the current local Codex hooks:

```sh
./pet install-codex
```

This installs Petfy integration in two layers:

- `notify` in `~/.codex/config.toml` for broad task-complete coverage across Codex surfaces.
- hooks in `~/.codex/hooks.json` for completion, running, and attention events when the client emits them.

The integration scripts are isolated inside this repository so the app can evolve toward macOS, Windows, and Linux without depending on platform-specific notification tools. `task.started` currently comes from `UserPromptSubmit`, which is the path being validated first for VS Code and CLI. Desktop running-state detection is planned for a later pass.

Events are stored in:

```text
~/.petfy/latest-event.json
~/.petfy/events.jsonl
~/.petfy/bridge.log
```

Clear active notifications:

```sh
./pet clear
```

Regenerate the local app icons:

```sh
./pet icons
```

## Local macOS Install

For your own machine, the current MVP can be installed without publishing a package:

```sh
./pet install-app
./pet start-app
./pet doctor
```

This copies the release macOS build to:

```text
~/Applications/Petfy.app
```

and installs a LaunchAgent:

```text
~/Library/LaunchAgents/dev.petfy.pet.plist
```

The LaunchAgent starts the pet on login and injects the right `PETFY_ROOT` and `PETFY_STATE_DIR` environment variables.

The local installer also applies an ad-hoc signature. That is enough for your own development builds, but it does not make the app an identified public developer build. To distribute Petfy to other macOS users without Gatekeeper warnings, the release build needs an Apple Developer ID certificate, notarization with Apple, and stapling.

After the app is installed, start it manually with:

```sh
./pet start-app
```

or open:

```text
~/Applications/Petfy.app
```

To generate and install a new local build after code changes:

```sh
./pet install-app
./pet start-app
```

`install-app` rebuilds the macOS app and replaces the local `~/Applications/Petfy.app` copy.

Use `./pet dev` for debug builds while developing. The installed app uses a release build so it stays significantly smaller than Flutter's debug bundle.

## Local Linux Install

Run these commands on a Linux desktop with Flutter Linux dependencies and Node.js installed:

```sh
./pet install-linux
./pet start-linux
./pet doctor-linux
```

This builds the Linux release bundle and installs Petfy to:

```text
~/.local/share/petfy
```

It also creates:

```text
~/.local/bin/petfy
~/.local/share/applications/dev.petfy.pet.desktop
~/.config/autostart/dev.petfy.pet.desktop
```

The launcher injects `PETFY_ROOT`, `PETFY_STATE_DIR`, and `PETFY_NODE_PATH`, writes logs to `~/.petfy`, and starts Petfy at desktop login.

Remove the local Linux install:

```sh
./pet stop-linux
./pet uninstall-linux
```

## Local Linux Package

Generate a shareable Linux package from a Linux machine:

```sh
./pet package-linux
```

This creates:

```text
dist/linux/Petfy-linux-x64-v0.0.1.tar.gz
```

The archive contains:

- Linux Flutter release bundle.
- `install.sh`
- `diagnostics.sh`
- `uninstall.sh`
- Petfy bridge/runtime scripts
- README, changelog, and license

The user extracts it and runs:

```sh
./install.sh
```

The Linux package is not validated from macOS because Flutter Linux desktop builds must run on Linux.

## Local Windows Install

Run these commands on a Windows desktop with Flutter Windows dependencies and Node.js installed:

```bat
pet.cmd install-windows
pet.cmd start-windows
pet.cmd doctor-windows
```

This builds the Windows release bundle and installs Petfy to:

```text
%LOCALAPPDATA%\Petfy
```

It also creates:

```text
%LOCALAPPDATA%\Petfy\petfy.cmd
%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Petfy.lnk
```

The launcher injects `PETFY_ROOT`, `PETFY_STATE_DIR`, and `PETFY_NODE_PATH`, writes logs to `%USERPROFILE%\.petfy`, and starts Petfy at login through the Startup folder shortcut.

Remove the local Windows install:

```bat
pet.cmd stop-windows
pet.cmd uninstall-windows
```

## Local Windows Package

Generate a shareable Windows package from a Windows machine:

```bat
pet.cmd package-windows
```

This creates:

```text
dist\windows\Petfy-windows-x64-v0.0.1.zip
```

The zip contains:

- Windows Flutter release bundle.
- `install.cmd`
- `diagnostics.cmd`
- `uninstall.cmd`
- Petfy bridge/runtime scripts
- README, changelog, and license

The user extracts it and double-clicks:

```text
install.cmd
```

The Windows package is not validated from macOS because Flutter Windows desktop builds must run on Windows.

## Local macOS Package

Generate a shareable local macOS package:

```sh
./pet package-macos
```

This creates:

```text
dist/macos/Petfy-macos-v0.0.1/
dist/macos/Petfy-macos-v0.0.1.zip
```

The zip contains:

- `Petfy.app`
- `install.command`
- `diagnostics.command`
- `uninstall.command`
- Petfy bridge/runtime scripts
- README, changelog, and license

The user unzips it and double-clicks `install.command`. The installer stops any old Petfy process, copies the app to `~/Applications`, copies runtime files to `~/Library/Application Support/Petfy`, installs Codex hooks, enables launch at login, opens Petfy, and prints basic setup checks.

`diagnostics.command` verifies the installed app, runtime, hooks, notify config, and LaunchAgent. `uninstall.command` removes the app, runtime, and LaunchAgent while keeping event history in `~/.petfy`.

This package is for local/testing distribution. Public macOS distribution still needs Developer ID signing and notarization.

## Signed macOS Package

For public macOS distribution, configure Apple Developer ID credentials and run:

```sh
export PETFY_MACOS_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export PETFY_NOTARY_KEYCHAIN_PROFILE="petfy-notary"
./pet package-macos-signed
```

The signed flow uses hardened runtime, submits the zip to Apple notarization, staples the ticket to `Petfy.app`, and recreates the zip.

See [docs/macos-signing-notarization.md](docs/macos-signing-notarization.md).

## Diagnostics

Open the Petfy popover, then use Settings > Diagnostics.

Diagnostics currently check:

- runtime path;
- bridge script;
- hook script;
- state directory;
- update feed;
- Node.js;
- Codex hooks;
- Codex notify;
- macOS login item.

Use `Repair` to reinstall/update the Codex hooks from inside the app.

To stop or remove the local install:

```sh
./pet stop-app
./pet uninstall-app
```

## Packaging Goal

The first public release should install as a normal desktop app:

- macOS: signed and notarized `.dmg` or `.app`.
- Windows: installer or portable build.
- Linux: AppImage or simple archive/package.
- First-run setup: configure Codex hooks automatically.
- Autostart: launch the pet at login.
- Settings screen: enable/disable sounds, autostart, hook install, clear history, mascot size.

See [docs/distribution-strategy.md](docs/distribution-strategy.md) for the cross-platform installer and GitHub Releases plan.

Release metadata lives in:

- [docs/release-artifacts.json](docs/release-artifacts.json)
- [docs/release-notes-template.md](docs/release-notes-template.md)

Generate a local artifact/checksum summary:

```sh
./pet release-manifest
```

Generate the static update feed used by in-app update checks:

```sh
./pet update-manifest
```

See [docs/update-strategy.md](docs/update-strategy.md) for the updater rollout plan.

In development, Petfy reads `dist/update/latest.json` when it exists. Public builds should compile the feed URL into the app:

```sh
flutter build macos --dart-define=PETFY_UPDATE_FEED_URL=https://raw.githubusercontent.com/josehenriquefs/petfy/main/dist/update/latest.json
```

## Project Plan

See [docs/project-plan.md](docs/project-plan.md).

## Mascot States

The current mascot is a code-drawn pug with four base states:

- **Idle**: waiting without active notifications.
- **Working**: Codex is running or a task is in progress.
- **Completed**: a task finished successfully.
- **Attention**: user action or approval is needed.

Later releases can replace the code-drawn mascot with sprite or Lottie assets while keeping the same state model.

Current recommendation: **Petfy** for the product, with "a desktop pet for Codex" as the tagline.

## License

MIT License.

Copyright (c) 2026 Jose Henrique F. S.
