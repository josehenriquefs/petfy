# Petfy Current Status

Last updated: 2026-07-27

Use this document as the starting point when resuming work on Petfy.

## Product Snapshot

Petfy is a Flutter desktop companion for Codex. It receives normalized Codex
events through a local Node bridge, shows a floating mascot, keeps a task
popover, and can focus the related VS Code project.

The active local application is installed at `~/Applications/Petfy.app` on
macOS. The repository uses a local Flutter SDK under `.tooling/flutter`.

## What Works Today

- Floating, draggable macOS pet window with adaptive popover placement.
- Pet task panel with activity, completed notifications, clear/dismiss actions,
  settings, diagnostics, and optional raw event/debug logs.
- Focus a task workspace in VS Code.
- Completion event bridge through Codex `notify` and direct Petfy hooks.
- Baseline running-state capture from `UserPromptSubmit` for CLI and VS Code.
- Event reconciliation that resolves a completed turn, retains a newer
  follow-up turn, and hides working turns stale for more than 15 minutes.
- Attention event normalization when the Codex surface emits `Notification`.
- First-run setup, diagnostics, repair action, auto-start, local updater handoff,
  package scripts, and local macOS installation.
- Linux and Windows install/package scripts exist but have not been validated on
  real target desktops.
- Settings for mascot, size, startup position, sounds, auto-clear, dark panel,
  launch at login, animations, diagnostics, and logs.
- An Animation Preview subpanel in Settings > Appearance. It reuses the
  production mascot renderer to review each mascot, state, and supported
  transition without emitting test Codex events.

## Mascots And Animation State

Available mascots:

- Pug: authored idle, working, completed, and attention loops plus state
  timelines.
- Lumo: authored idle, working, and completed pose loops plus state timelines.
- Classic ET: authored idle, working, and completed pose loops plus state timelines.

For all current mascots:

- `idle -> working`: picks up and opens a laptop.
- `working -> completed`: closes the laptop and celebrates.
- `completed -> working`: uses the completion timeline in reverse.
- `completed -> idle`: returns through the work and idle timeline.
- Idle, working, and completed loops wait before a brief action. The Pug uses
  a slower 42-second ambient cycle; Lumo and classic ET use 20-second cycles.
- Attention has authored immediate two-pose loops for classic ET and Lumo,
  alongside the orange app-level badge. The loop intentionally has no long
  ambient delay because it represents a pending user action.

Lumo and classic ET mount one PNG at a time. The Pug uses a short, no-scale
cross-fade with per-frame origin offsets to soften authored pose changes while
avoiding the apparent camera zoom caused by mismatched sprite canvases.

## Event Coverage And Limitations

Reliable primary behavior:

- `task.completed` from `notify` and `Stop` hooks.
- CLI `task.started` and `task.completed` have been validated in a real session.

Still needs validation:

- `Notification` / `task.waiting_approval` in a real approval flow.
- Desktop running-state and attention coverage. Desktop completion is supported,
  but running detection is not a current promise.
- Cross-surface duplicate and stale-working-task behavior after longer usage.

Treat completed notifications as the production-ready feature. Working and
attention are progressive enhancements until validated per Codex surface.

## Local Commands

Run from repository root:

```sh
./pet dev
./pet analyze
./pet test
npm run test:bridge
./pet install-app
./pet start-app
./pet doctor
./pet latest
./pet clear
./pet open
```

Recommended validation after app changes:

```sh
./pet analyze
./pet test
npm run test:bridge
./pet install-app
./pet start-app
```

Use real Codex activity for event validation. Do not rely on test events to
confirm hook coverage.

## Priority Checklist

### Next Up

- [x] Add authored attention poses and a short immediate attention loop for
  classic ET and Lumo.
- [x] Add an animation preview/debug surface in Settings so each mascot state
  and transition can be reviewed without creating fake Codex events.
- [x] Validate `task.started` in a real VS Code session.
- [x] Improve stale or duplicate task handling based on those real sessions.

### Animation Follow-up

- [x] Add authored pose timelines for the Pug: idle, working, completed, and
  attention.
- [x] Compress and resize mascot assets for distribution. Active assets now
  use a 512 px maximum and reduced the local macOS build from 112.6 MB to
  58.1 MB.
- [ ] Consider a rigged/Rive animation pipeline only after the current sprite
  workflow has been evaluated for quality, size, and maintainability.

### Product And Distribution

- [ ] Validate attention in a real approval-required Codex session.
- [ ] Improve first-run setup copy and recovery for non-developer users.
- [ ] Validate Linux build, desktop entry, and autostart on a real Linux desktop.
- [ ] Validate Windows build, startup integration, and VS Code focus on Windows.
- [ ] Add screenshots/GIF, `CONTRIBUTING.md`, issue templates, and an explicit
  license before wider public use.
- [ ] Add a GitHub Actions release workflow that builds and attaches artifacts.
- [ ] Obtain Apple Developer ID signing, notarize macOS releases, and publish a
  user-facing installer.
- [ ] Decide and implement the Windows and Linux signing/package strategy.
- [ ] Add a native auto-updater only after signed releases are stable.

## Key Files

- `app/lib/main.dart`: floating-pet UI, state selection, pose timelines, and
  settings UI.
- `bridge/`: Node event normalization and project focus helper.
- `scripts/`: Codex hooks, local runtime helpers, and installers.
- `docs/event-contract.md`: normalized event schema.
- `docs/roadmap-checklist.md`: broad release/distribution checklist.
- `docs/project-plan.md`: historical product plan and longer-term context.

## Resume Order

1. Read this file and `docs/event-contract.md`.
2. Run `./pet doctor` and `./pet latest` to confirm local integration health.
3. Run the validation commands above before changing behavior.
4. Take the first unchecked item from **Next Up** unless a real event reliability
   issue is blocking the core completion workflow.
