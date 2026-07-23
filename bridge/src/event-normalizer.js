import path from "node:path";

export function normalizeCodexEvent(rawEvent, env = process.env) {
  const codexType = getEventType(rawEvent, env);
  const cwd =
    rawEvent.cwd ||
    rawEvent.workspace ||
    rawEvent.workspaceRoot ||
    rawEvent.project_path ||
    rawEvent.projectPath ||
    env.PWD ||
    process.cwd();
  const projectName = rawEvent.projectName || path.basename(cwd);

  return {
    schemaVersion: 1,
    type: mapCodexType(codexType),
    source: inferSource(rawEvent, env),
    cwd,
    projectName,
    threadId:
      rawEvent["thread-id"] || rawEvent.threadId || rawEvent.thread_id || null,
    turnId: rawEvent["turn-id"] || rawEvent.turnId || rawEvent.turn_id || null,
    message:
      rawEvent["last-assistant-message"] ||
      rawEvent.lastAssistantMessage ||
      rawEvent.prompt ||
      rawEvent.reason ||
      rawEvent.message ||
      rawEvent.notification ||
      "",
    rawType: codexType,
    timestamp: new Date().toISOString()
  };
}

function inferSource(rawEvent, env) {
  const rawSource = rawEvent.source;
  const originator = String(rawEvent.originator || rawEvent.origin || "").toLowerCase();
  const sourceText = typeof rawSource === "string" ? rawSource.toLowerCase() : "";
  const eventType = String(env.PETFY_EVENT_TYPE || rawEvent.type || "").toLowerCase();

  if (sourceText.includes("vscode") || originator.includes("vscode")) {
    return "vscode";
  }

  if (sourceText.includes("desktop") || originator.includes("desktop")) {
    return "desktop";
  }

  if (sourceText.includes("cli") || originator.includes("cli")) {
    return "cli";
  }

  if (eventType === "agent-turn-complete") {
    return "notify";
  }

  if (eventType) {
    return "hook";
  }

  return "codex";
}

function getEventType(rawEvent, env) {
  return (
    env.PETFY_EVENT_TYPE ||
    rawEvent.type ||
    rawEvent.hook_event_name ||
    rawEvent.hookEventName ||
    rawEvent.event ||
    rawEvent.name ||
    "agent-turn-complete"
  );
}

function mapCodexType(codexType) {
  switch (String(codexType).toLowerCase()) {
    case "agent-turn-complete":
    case "stop":
      return "task.completed";
    case "approval-requested":
    case "approval_requested":
    case "notification":
    case "needs-approval":
    case "needs_approval":
      return "task.waiting_approval";
    case "agent-turn-start":
    case "userpromptsubmit":
    case "user-prompt-submit":
    case "user_prompt_submit":
      return "task.started";
    default:
      return `codex.${codexType}`;
  }
}
