# Project Plan

## Working Objective

Build a polished, installable desktop pet for Codex users that surfaces task completion, required attention, and optionally running tasks across Codex CLI, Codex Desktop, and the VS Code extension.

## Product Direction

The pet should feel lightweight, useful, and charming without becoming noisy.

Core jobs:

- Notify when Codex finishes a task.
- Show when Codex needs approval or user interaction.
- Let the user jump back to the correct project.
- Stay out of the way when there is nothing to show.

Future mascot direction:

- Animated pug.
- Idle, working, completed, and attention states.
- Configurable size and sound.

## Name Decision

Project name: `Petfy`

Tagline: `a desktop pet for Codex`

Why:

- Short and memorable.
- Connects the pug mascot to Codex.
- Distinct enough for GitHub/search.
- Works with the tagline: "a desktop pet for Codex".

Alternates:

- `Codex Pug`
- `PugPing`
- `PugPilot`
- `TaskPug`
- `Codex Buddy`

## MVP Definition

The first public MVP is ready when:

- The app runs as a floating desktop pet on macOS.
- Completion events work with Codex CLI/Desktop/VS Code through the user's Codex hook setup.
- Notifications can be cleared.
- Clicking a single completed task opens the project in VS Code.
- Multiple events show in a popover.
- The app can be installed without cloning Flutter manually.
- A first-run setup command/app flow can install or repair hooks.
- The app can start on login.
- README explains install, troubleshooting, and architecture.

## Release 0.1: Local Developer MVP

Status: mostly done.

Current tagged baseline: `v0.0.1`

Done:

- Flutter macOS floating window.
- File-based event bridge.
- Completion events through global Codex `notify` and Petfy-owned hook scripts.
- Clear notifications.
- Open project in VS Code.
- Basic animated pet.
- macOS sounds.
- Local Flutter SDK wrapper.
- Empty-state popover when there are no active tasks.
- Local macOS install command.
- LaunchAgent autostart command.

Remaining:

- Add visible settings/about surface.
- Add release build/package command.
- Add robust first-run installer for non-developer users.
- Confirm attention/running hook behavior in real Codex sessions.

## Release 0.2: Installable macOS App

Deliverables:

- Built `.app` artifact.
- Local install command that copies the app to `~/Applications/Petfy.app`.
- Local package command that builds a shareable zip with `install.command`.
- LaunchAgent install/start/stop/uninstall commands.
- `install.sh` or packaged installer for non-developer users.
- First-run setup screen or command:
  - install Codex hooks;
  - preserve existing hooks;
  - detect active Petfy `notify` and hooks;
  - test bridge write permissions;
  - show setup status.
- LaunchAgent or native login item for autostart.
- Troubleshooting command:
  - hook status;
  - last event;
  - bridge log;
  - Codex config paths;
- VS Code CLI status.

## Near-Term Roadmap

Priority order:

1. Harden real Codex events across VS Code extension and CLI.
   - Install Petfy as global `notify` in `~/.codex/config.toml` for broad completion coverage.
   - Keep direct Petfy hooks for completion, attention, and future event types.
   - Use `UserPromptSubmit` as the first `task.started` source for VS Code and CLI.
   - Leave Desktop running-state detection for a later pass.
   - Add diagnostics that show whether hooks are installed and events are being written.
2. First-run setup and diagnostics inside the app.
   - Show runtime, bridge, hook script, Codex hooks, Node.js, state directory, and login item status.
   - Add a repair action that reinstalls hooks.
   - Later add open logs and uninstall/restore actions.
3. Improve the local macOS installer.
   - Add `uninstall.command`.
   - Add `diagnose.command`.
   - Generate a local `.dmg`.
   - Improve copy for users blocked by Gatekeeper.
4. Event reliability.
   - Better duplicate handling.
   - Persist dismissed task keys.
   - Improve thread/project identification.
   - Verify `Notification` and `UserPromptSubmit` in VS Code, Desktop, and CLI.
5. Settings.
   - Sound on/off.
   - Launch at login on/off.
   - Pug size.
   - Always on top.
   - Reset position.
6. Mascot assets.
   - Replace the current painter with pug assets or Lottie animations.
   - Keep four states: idle, working, completed, attention.
7. GitHub readiness.
   - Add screenshots/GIF.
   - Add issue templates.
   - Add `CONTRIBUTING.md`.
   - Add release workflow.
   - Keep local paths out of public docs.
8. Public macOS release.
   - Apple Developer account.
   - Developer ID signing.
   - Notarization and stapling.
   - Public `.dmg`.
9. Windows MVP.
   - Windows floating window.
   - Startup integration.
   - `code.cmd` focus path.
   - Windows installer.

## Current Execution Checklist

Completed:

- [x] Isolate dark/light panel colors in `panel_theme.dart`.
- [x] Fix dark mode panel titles and settings labels.
- [x] Improve running-task detection from Codex session files.
- [x] Add configurable pet size.
- [x] Add configurable startup position.
- [x] Add configurable sounds for completed and attention events.
- [x] Improve mascot behavior with lightweight animated transitions.
- [x] Add onboarding/setup guide and diagnostics repair flow.
- [x] Add event logs behind a settings toggle.
- [x] Add debug logs behind a settings toggle.
- [x] Add telemetry-free diagnostics status inside the app.
- [x] Add Linux packaging/setup scripts.
- [x] Add Windows packaging/setup scripts.
- [x] Define final installer strategy for macOS, Windows, and Linux.
- [x] Add GitHub Releases artifact naming and checksum manifest.
- [x] Add static update feed manifest generation.
- [x] Add in-app update check and installer/release handoff.
- [x] Add checksum-aware update handoff before direct artifact download.
- [x] Configure the update feed for `github.com/josehenriquefs/petfy`.
- [x] Publish the initial GitHub commit and `v0.0.1` release, then validate the public update feed.
- [x] Add multiple mascot support with Pug, Lumo, and a classic ET, plus a user-facing selector.
- [x] Add non-blocking diagnostics for real start and attention event capture.

Active next candidates:

- [ ] Validate `task.started` and attention events in real VS Code and CLI sessions.
- [ ] Add a better animated pug mascot asset pipeline.
- [ ] Improve first-run setup copy and failure recovery.

Later backlog:

- [ ] Signed/notarized macOS release.
- [ ] Windows build validation.
- [ ] Linux build validation.
- [ ] GitHub release workflow.
- [ ] Native auto-updater after signing is stable.
- [ ] Export/import settings.
- [ ] Task details view.

## Release 0.3: Pug Mascot

Deliverables:

- Replace the current drawn avatar with a pug mascot.
- Add animations:
  - idle breathing/blink;
  - working loop;
  - completion celebration;
  - attention badge/pose.
- Keep animations lightweight and readable at small sizes.
- Add user controls:
  - mascot size;
  - sound on/off;
  - always-on-top on/off;
  - clear notifications;
  - start at login.

## Release 0.4: Windows

Deliverables:

- Windows floating window behavior.
- Focus VS Code project through `code.cmd`.
- Windows startup integration.
- Windows notification/sound support.
- Installer packaging.

## Event Strategy

Reliable today:

- `notify` / `task.completed` for broad completion coverage.
- `Stop` / `task.completed` where direct hooks are emitted.

Desired:

- `UserPromptSubmit` / `task.started` for working state in VS Code and CLI first.
- `Notification` / `task.waiting_approval` for approval/interaction state.

Open question:

- Whether all Codex surfaces emit the same hook events and whether the hook trust flow is consistent across CLI, Desktop, and VS Code.

Near-term approach:

- Keep completion as the reliable primary feature.
- Instrument hook status and logs.
- Treat working/attention as progressive enhancement until verified.

## Installer Strategy

The installer should be conservative:

- Never delete user hooks.
- Always backup `~/.codex/hooks.json` before editing.
- Preserve existing `notify` config.
- Prefer adding a single Pet bridge hook or integrating with an existing trusted completion hook.
- Provide `uninstall` or `restore` instructions.

Planned commands:

```sh
petfy install
petfy uninstall
petfy doctor
petfy clear
petfy logs
```

## Autostart Strategy

macOS:

- MVP: create a LaunchAgent plist in `~/Library/LaunchAgents`.
- Later: native login item from the packaged app.

Windows:

- MVP: startup folder shortcut or scheduled task.
- Later: installer-managed startup option.

## GitHub Readiness Checklist

- Pick final name.
- Add license.
- Add screenshots/GIF.
- Add installation instructions.
- Add architecture diagram.
- Add `CHANGELOG.md`.
- Add `CONTRIBUTING.md`.
- Add issue templates.
- Add release build script.
- Add GitHub Actions for tests/builds.
- Remove local machine-specific paths from public docs where possible.
- Keep local development notes in a separate document.

## Current Risks

- Codex hook trust behavior is not fully documented in this repo.
- `Notification` and `UserPromptSubmit` need real-world validation in every Codex surface.
- The current app is macOS-first despite Flutter scaffolding for Windows/Linux.
- Public distribution will require packaging and signing decisions.
