import fs from "node:fs";
import { spawnSync } from "node:child_process";
import process from "node:process";
import { pathToFileURL } from "node:url";

export function focusProject(projectPath, platform = process.platform) {
  if (!projectPath) {
    return Promise.resolve({ ok: false, reason: "missing_project_path" });
  }

  if (!fs.existsSync(projectPath)) {
    return Promise.resolve({
      ok: false,
      reason: "project_path_not_found",
      projectPath
    });
  }

  const candidates = focusCandidates(projectPath, platform);
  const attempted = [];

  for (const candidate of candidates) {
    const result = run(candidate.command, candidate.args);
    attempted.push(candidate.label);
    if (result.ok) {
      return Promise.resolve({
        ok: true,
        method: candidate.label,
        projectPath,
        attempted
      });
    }
  }

  return Promise.resolve({
    ok: false,
    reason: "no_focus_method_available",
    projectPath,
    attempted
  });
}

function focusCandidates(projectPath, platform) {
  const fileUri = `vscode://file${pathToFileURL(projectPath).pathname}`;

  if (platform === "darwin") {
    return [
      {
        label: "VS Code CLI",
        command: "code",
        args: ["--reuse-window", projectPath]
      },
      {
        label: "VS Code CLI absolute Apple Silicon",
        command: "/opt/homebrew/bin/code",
        args: ["--reuse-window", projectPath]
      },
      {
        label: "VS Code CLI absolute Intel",
        command: "/usr/local/bin/code",
        args: ["--reuse-window", projectPath]
      },
      {
        label: "VS Code Insiders CLI",
        command: "code-insiders",
        args: ["--reuse-window", projectPath]
      },
      {
        label: "VS Code bundle id",
        command: "open",
        args: ["-b", "com.microsoft.VSCode", projectPath]
      },
      {
        label: "VS Code app name",
        command: "open",
        args: ["-a", "Visual Studio Code", projectPath]
      },
      {
        label: "VS Code file URI",
        command: "open",
        args: [fileUri]
      }
    ];
  }

  if (platform === "win32") {
    return [
      {
        label: "VS Code CLI",
        command: "cmd.exe",
        args: ["/c", "code.cmd", "--reuse-window", projectPath]
      },
      {
        label: "VS Code Insiders CLI",
        command: "cmd.exe",
        args: ["/c", "code-insiders.cmd", "--reuse-window", projectPath]
      },
      {
        label: "VS Code file URI",
        command: "cmd.exe",
        args: ["/c", "start", "", fileUri]
      },
      {
        label: "Explorer fallback",
        command: "explorer.exe",
        args: [projectPath]
      }
    ];
  }

  return [
    {
      label: "VS Code CLI",
      command: "code",
      args: ["--reuse-window", projectPath]
    },
    {
      label: "VS Code Insiders CLI",
      command: "code-insiders",
      args: ["--reuse-window", projectPath]
    },
    {
      label: "VS Code file URI",
      command: "xdg-open",
      args: [fileUri]
    },
    {
      label: "File manager fallback",
      command: "xdg-open",
      args: [projectPath]
    }
  ];
}

function run(command, args) {
  const result = spawnSync(command, args, {
    encoding: "utf8",
    stdio: "ignore"
  });
  return { ok: result.status === 0 };
}
