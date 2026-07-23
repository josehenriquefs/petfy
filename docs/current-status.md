# Petfy Current Status

Last updated: 2026-07-23

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
- Attention event normalization when the Codex surface emits `Notification`.
- First-run setup, diagnostics, repair action, auto-start, local updater handoff,
  package scripts, and local macOS installation.
- Linux and Windows install/package scripts exist but have not been validated on
  real target desktops.
- Settings for mascot, size, startup position, sounds, auto-clear, dark panel,
  launch at login, animations, diagnostics, and logs.

## Mascots And Animation State

Available mascots:

- Pug: four state assets, but no authored pose timelines yet.
- Lumo: authored idle, working, and completed pose loops plus state timelines.
- Classic ET: authored idle, working, and completed pose loops plus state timelines.

For Lumo and classic ET:

- `idle -> working`: picks up and opens a laptop.
- `working -> completed`: closes the laptop and celebrates.
- `completed -> working`: uses the completion timeline in reverse.
- `completed -> idle`: returns through the work and idle timeline.
- Idle, working, and completed loops wait about 16.8 seconds before a brief
  action. A state or mascot change resets that delay.
- Attention currently has a static asset plus the orange app-level badge. It is
  the next state that needs authored mascot poses.

The renderer intentionally mounts only one PNG at a time. A previous crossfade
between generated assets created visible flashing because their lighting and
silhouettes differed. Do not reintroduce crossfading without validating it at
the real floating-pet size.

## Event Coverage And Limitations

Reliable primary behavior:

- `task.completed` from `notify` and `Stop` hooks.
- CLI `task.started` and `task.completed` have been validated in a real session.

Still needs validation:

- `task.started` in a real VS Code extension session.
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

- [ ] Add authored attention poses and a short immediate attention loop for
  classic ET and Lumo.
- [ ] Add an animation preview/debug surface in Settings so each mascot state
  and transition can be reviewed without creating fake Codex events.
- [ ] Validate `task.started` in a real VS Code session.
- [ ] Validate attention in a real approval-required Codex session.
- [ ] Improve stale or duplicate task handling based on those real sessions.

### Animation Follow-up

- [ ] Add authored pose timelines for the Pug: idle, working, completed, and
  attention.
- [ ] Compress and resize mascot assets for distribution. The macOS release
  bundle is currently roughly 90 MB, largely because of the animation PNGs.
- [ ] Consider a rigged/Rive animation pipeline only after the current sprite
  workflow has been evaluated for quality, size, and maintainability.

### Product And Distribution

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
