# Codex Pet Event Contract

The Flutter app should consume normalized Codex Pet events, not raw Codex hook payloads.

## Event

```json
{
  "schemaVersion": 1,
  "type": "task.completed",
  "source": "codex",
  "cwd": "/Users/example/project",
  "projectName": "project",
  "threadId": "thread_123",
  "turnId": "turn_123",
  "message": "Final assistant message.",
  "rawType": "agent-turn-complete",
  "timestamp": "2026-07-13T13:30:00.000Z"
}
```

## Initial Event Types

- `task.completed`: Codex finished an agent turn.
- `task.started`: emitted from `UserPromptSubmit` and active-session discovery.
- `task.waiting_approval`: emitted from the `Notification` lifecycle hook.
- `codex.<rawType>`: fallback for unmapped Codex event types.

When a lifecycle hook provides an explicit type, Petfy treats it as
authoritative even if the attached payload contains another generic `type`.
That keeps a prompt submission from being misclassified as completion.

## Transport

MVP transport order:

1. Write the latest event to `~/.petfy/latest-event.json`.
2. Append all events to `~/.petfy/events.jsonl`.
3. Add localhost WebSocket once the Flutter app exists.

The file fallback keeps Codex integration useful even when the Flutter app is closed.
