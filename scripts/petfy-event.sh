#!/bin/sh
set -u

script_path="$0"
repo_root="$(cd "$(dirname "$script_path")/.." && pwd)"
bridge_cli="$repo_root/bridge/src/cli.js"
fallback_type="${1:-}"
raw_arg="${2:-}"
log_dir="${PETFY_STATE_DIR:-$HOME/.petfy}"
log_file="$log_dir/bridge.log"

mkdir -p "$log_dir"

find_node() {
  if [ -n "${NODE:-}" ] && [ -x "$NODE" ]; then
    echo "$NODE"
    return 0
  fi

  if command -v node >/dev/null 2>&1; then
    command -v node
    return 0
  fi

  for candidate in /opt/homebrew/bin/node /usr/local/bin/node /usr/bin/node; do
    if [ -x "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

stdin_payload="$(cat 2>/dev/null || true)"

if [ -n "$raw_arg" ]; then
  payload="$raw_arg"
elif [ -n "$stdin_payload" ]; then
  payload="$stdin_payload"
else
  escaped_cwd="$(printf '%s' "$PWD" | sed 's/\\/\\\\/g; s/"/\\"/g')"
  payload="{\"type\":\"${fallback_type:-agent-turn-complete}\",\"cwd\":\"$escaped_cwd\"}"
fi

node_bin="$(find_node || true)"
if [ -z "$node_bin" ]; then
  printf '%s missing node executable\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "$log_file"
  exit 0
fi

PETFY_EVENT_TYPE="$fallback_type" "$node_bin" "$bridge_cli" notify "$payload" >> "$log_file" 2>&1
