# Changelog

## v0.0.2-beta.8 - 2026-07-28

### Fixed

- Windows now resolves the installed Petfy runtime directory correctly before
  writing Codex hooks and `notify`, so `task.started` and completion events can
  reach the local bridge.
- The Windows installer stops and points to its log when Codex integration
  setup fails instead of silently launching an unconfigured app.
- Windows diagnostics now recognizes the JavaScript notify handler actually
  configured by the installer.
- Opening a Windows panel now prepares the resized window before showing it,
  avoiding the empty-frame flash and brief freeze during the opening animation.

## v0.0.2-beta.7 - 2026-07-28

### Fixed

- Windows native window dimensions now honor the monitor DPI, keeping Working,
  Done, and Settings panels readable at 125%, 150%, and higher display scale.
- Opening and closing panels no longer force a native non-client frame rebuild,
  avoiding the opening visual glitch.

## v0.0.2-beta.6 - 2026-07-27

### Fixed

- Windows no longer attaches Petfy to the installer's console, so closing the
  terminal does not close the pet.
- Successful Windows installs now close their command window automatically.
- Windows panel placement now preserves the pet anchor and clamps Settings and
  other expanded panels inside the visible desktop area.

## v0.0.2-beta.5 - 2026-07-27

### Fixed

- Windows now uses a borderless, compact native Petfy window instead of the
  default Flutter `app` host window.
- The Windows pet stays on top, expands for the task panel, and supports drag,
  reset-position, and startup-position controls through the native channel.

## v0.0.2-beta.4 - 2026-07-27

### Fixed

- Windows diagnostics now recognizes the JavaScript hook and notify bridge used
  by the native Windows installer.
- Repair no longer treats the integration installer's regular text output as a
  JSON response.

## v0.0.2-beta.3 - 2026-07-27

### Fixed

- Windows now resolves Codex files from `USERPROFILE` when `HOME` is absent,
  instead of incorrectly looking inside the Petfy installation directory.
- Installed launchers now override a build-time Node.js path, preventing repair
  and focus actions from trying to execute the GitHub Actions Node binary.

## v0.0.2-beta.2 - 2026-07-27

### Added

- One GitHub Actions workflow that natively builds macOS, Windows, and Linux
  packages for the same tag and publishes their checksums together.

### Fixed

- Linux packaging and installation now use Flutter's generated `app` binary.
- Release scripts can use the Flutter runtime provided by GitHub Actions when
  the project's local Flutter runtime is unavailable.

## v0.0.2-beta.1 - 2026-07-27

### Fixed

- Pug assets are preloaded and retain a visible fallback during rapid state
  transitions, preventing the mascot from briefly disappearing or stacking
  multiple mood frames.
- The drawn fallback is now removed as soon as a PNG frame is ready, so it
  cannot be visible behind transparent areas of the mascot asset.
- macOS reinstall now stops the existing Petfy process before replacing its
  bundle, preventing a stale process from serving old assets.
- `UserPromptSubmit` now takes precedence over a generic payload type, so a new
  task is recorded as `Working` rather than `Completed`.
- Task reconciliation now resolves lifecycle events per turn before workspace,
  avoiding stale activity and hiding valid completions from other turns.

### Added

- Windows tester packaging workflow. It builds a downloadable ZIP on GitHub
  Actions with `install.cmd`, `test-event.cmd`, diagnostics, and uninstall.
- Task reconciliation tests covering completion, follow-up turns, stale work,
  and completion events without turn metadata.
- Authored Pug state timelines and compressed 512 px mascot assets, reducing
  the local macOS build from 112.6 MB to 58.1 MB.
- Bridge lifecycle tests for started, attention, and completion events.
- `./pet test-start` for a local Working-state smoke test.
- A selectable ET mascot with idle, working, completed, and attention states.
- Persistent mascot choice in Settings; Pug remains the default.

## v0.0.1 - 2026-07-13

First local MVP.

### Added

- Floating macOS pet window.
- File-based Codex event bridge.
- Completion notifications through direct Petfy Codex hooks.
- Popover with task details, workspace path, refresh, clear, and open-project actions.
- Clear notifications from the app or with `./pet clear`.
- Local macOS install flow:
  - `./pet install-app`
  - `./pet package-macos`
  - `./pet start-app`
  - `./pet stop-app`
  - `./pet uninstall-app`
  - `./pet doctor`
- LaunchAgent autostart for local macOS install.
- Shareable local macOS zip package with `install.command`.
- Shareable package helpers: `diagnostics.command` and `uninstall.command`.
- Package installer now stops old Petfy instances, opens the app after install, writes an install log, and prints setup checks.
- Optional Developer ID signing and Apple notarization flow through `./pet package-macos-signed`.
- `./pet install-app` now installs a release macOS build instead of the much larger debug bundle.
- Basic animated pet face and badges.
- Pug-based app icon generated into the macOS `AppIcon` asset catalog.
- Four base pug mascot states: idle, working, completed, and attention.
- macOS bundle identity changed from the Flutter default `app` to `Petfy`.
- Local ad-hoc code signing during `./pet install-app`.
- `./pet install-codex` removes old local completion hooks from the active Codex hook config.
- Native macOS sounds for completed and attention events.
- Settings menu with `Quit Petfy`.
- Settings for sounds, animations, pet bubble, dark panel, launch at login, reset position, event log, and auto-clear delay.
- Diagnostics panel with setup checks and repair action.
- Global Codex `notify` integration through `petfy-notify.sh`.
- Task popover available for single-task notifications.
- Opening a project no longer clears the notification automatically; dismiss and clear are independent actions.
- Cross-platform-oriented Codex integration through Petfy-owned scripts.
- Diagnostics panel can be closed and scrolls inside the task popover.
- Task popover opens even without active tasks so settings and diagnostics are always reachable.
- MIT license.

### Notes

- This is a developer/local install release, not a signed public package.
- Signed packaging requires Apple Developer credentials configured through environment variables.
- Completion events are handled through Codex `notify` plus direct Petfy hooks where available.
- Running events are currently based on `UserPromptSubmit` and are being validated first for Codex CLI and the VS Code extension.
