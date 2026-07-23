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
- `task.started`: reserved for lifecycle hooks.
- `task.waiting_approval`: reserved for approval hooks.
- `codex.<rawType>`: fallback for unmapped Codex event types.

## Transport

MVP transport order:

1. Write the latest event to `~/.petfy/latest-event.json`.
2. Append all events to `~/.petfy/events.jsonl`.
3. Add localhost WebSocket once the Flutter app exists.

The file fallback keeps Codex integration useful even when the Flutter app is closed.
