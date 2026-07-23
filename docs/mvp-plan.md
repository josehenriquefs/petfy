# MVP Plan

## Step 1: Bridge

Build a small local bridge that receives Codex events and writes normalized state.

Done:

- `notify` command.
- event normalization.
- latest event file.
- append-only event history.
- platform focus command skeleton.

Next:

- add WebSocket server on `127.0.0.1`.
- add local token or origin validation before accepting commands.
- add tests for event normalization.

## Step 2: Flutter App

Create the Flutter app after installing Flutter:

```sh
cd /path/to/petfy
scripts/flutter-local create --platforms=macos,windows,linux app
```

Initial screens:

- small always-on-top pet window;
- tray/menu bar entry;
- task history list;
- settings view for bridge path and auto-start.

Initial states:

- idle;
- completed;
- failed;
- waiting approval, once hooks are configured.

## Step 3: Focus Project

Keep focus logic outside Flutter at first.

Platform commands:

- macOS: `open -a "Visual Studio Code" "$cwd"`.
- Windows: `code.cmd "$cwd"`.
- Linux: `code "$cwd"`.

Later improvements:

- use AppleScript on macOS to focus an existing VS Code window more precisely;
- use PowerShell or Win32 APIs on Windows;
- support VS Code Insiders and Cursor as configurable editor targets.

## Step 4: Codex Integration

Start with `notify` because it already covers the completed-task event.

Then add lifecycle hooks for:

- task started;
- approval requested;
- tool failed;
- turn completed.
