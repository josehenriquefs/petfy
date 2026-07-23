import assert from "node:assert/strict";
import test from "node:test";
import { normalizeCodexEvent } from "../src/event-normalizer.js";

test("uses the explicit hook type over a payload type", () => {
  const event = normalizeCodexEvent(
    {
      type: "agent-turn-complete",
      cwd: "/work/petfy",
      thread_id: "thread_1",
      turn_id: "turn_1",
      message: "Implement dashboard"
    },
    { PETFY_EVENT_TYPE: "UserPromptSubmit" }
  );

  assert.equal(event.type, "task.started");
  assert.equal(event.rawType, "UserPromptSubmit");
  assert.equal(event.source, "hook");
});

test("normalizes notification hooks as attention events", () => {
  const event = normalizeCodexEvent(
    {
      cwd: "/work/petfy",
      thread_id: "thread_1",
      turn_id: "turn_1",
      message: "Approval required to run a command"
    },
    { PETFY_EVENT_TYPE: "Notification" }
  );

  assert.equal(event.type, "task.waiting_approval");
  assert.equal(event.rawType, "Notification");
});

test("keeps notify completion behavior", () => {
  const event = normalizeCodexEvent(
    {
      type: "agent-turn-complete",
      cwd: "/work/petfy",
      "thread-id": "thread_1",
      "turn-id": "turn_1",
      "last-assistant-message": "Done"
    },
    { PETFY_EVENT_TYPE: "agent-turn-complete" }
  );

  assert.equal(event.type, "task.completed");
  assert.equal(event.source, "notify");
  assert.equal(event.threadId, "thread_1");
  assert.equal(event.turnId, "turn_1");
});
