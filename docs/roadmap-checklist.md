# Petfy Roadmap Checklist

This checklist tracks the next product improvements. Mark items as done when the implementation is built, installed, and validated.

## Final Distribution Goal

- [ ] One simple installer per OS.
- [ ] macOS installable without terminal, ideally signed/notarized and opened through Finder.
- [ ] Windows installable without terminal, ideally a signed installer or single guided executable.
- [ ] Linux installable with a simple package or one direct command, depending on distro constraints.
- [ ] First-run setup configures Codex hooks/notify automatically after user approval.
- [ ] Releases published through GitHub Releases with macOS, Windows, and Linux artifacts.
- [ ] Release notes include install, diagnostics, uninstall, and trust/security notes for each OS.
- [ ] Automated release workflow builds and attaches artifacts for all supported OS targets.

## Completed

- [x] Floating draggable desktop pet window.
- [x] Codex hooks and notify bridge.
- [x] VS Code / Desktop / CLI event capture baseline.
- [x] Activity and notifications panel.
- [x] Swipe to dismiss notifications.
- [x] Settings screen.
- [x] Diagnostics and repair screen.
- [x] Optional raw Event Log screen.
- [x] Source badges for Desktop, VS Code, CLI, Hook, Notify, and Codex.
- [x] Adaptive popover placement.
- [x] Persisted window position.
- [x] First-run setup guide.
- [x] Stuck working-task fix for aborted turns.
- [x] Pug avatar image assets and animated state transitions.
- [x] Configurable auto-clear duration.
- [x] More complete preferences: sounds, position, animation, theme, startup.
- [x] Polished user installer.
- [x] Refined dark panel colors across tasks, settings, diagnostics, and event log.
- [x] Linux local setup scripts for install, desktop entry, autostart, diagnostics, and package.
- [x] Windows local setup scripts for install, startup shortcut, diagnostics, and package.
- [x] Final installer strategy for macOS, Windows, Linux, and GitHub Releases.
- [x] GitHub Releases artifact naming, release notes template, and checksum manifest.
- [x] Automatic updater strategy and static update feed manifest.

## Current Execution Plan

- [x] Isolate panel theme and fix dark-mode menu/title colors.
- [x] More resilient active-task detection for future Codex session formats.
- [x] Pet size setting.
- [x] Startup position setting.
- [x] Configurable sounds by event type.
- [x] Better mascot animation with real state transitions.
- [x] Better onboarding and first-run setup flow.
- [x] Stronger VS Code/project focus integration.
- [x] Local telemetry/debug mode for hook and event diagnostics.

## Next Execution Plan

- [ ] Validate Windows build and startup integration on a Windows desktop.
- [ ] Validate Linux build and startup integration on a Linux desktop.
- [x] Design final installer strategy for macOS, Windows, and Linux.
- [x] Prepare GitHub Releases artifact naming and release notes template.
- [x] Automatic updater feed foundation.

## Later Backlog

- [ ] Task details screen.
- [ ] Advanced individual cleanup actions.
- [ ] macOS code signing and notarization.
- [ ] GitHub release workflow.
- [ ] Export/import settings.
- [x] Multiple mascots: Pug, Lumo, and a classic ET character.

## Suggested After Current Item

- [ ] In-app update check and installer handoff.
