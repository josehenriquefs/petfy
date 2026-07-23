# Changelog

## Unreleased

### Fixed

- `UserPromptSubmit` now takes precedence over a generic payload type, so a new
  task is recorded as `Working` rather than `Completed`.
- Task reconciliation now resolves lifecycle events per turn before workspace,
  avoiding stale activity and hiding valid completions from other turns.

### Added

- Bridge lifecycle tests for started, attention, and completion events.
- `./pet test-start` for a local Working-state smoke test.

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
