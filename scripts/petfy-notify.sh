#!/bin/sh
set -u

script_path="$0"
script_dir="$(cd "$(dirname "$script_path")" && pwd)"
event_script="$script_dir/petfy-event.sh"
log_dir="${PETFY_STATE_DIR:-$HOME/.petfy}"
log_file="$log_dir/notify.log"

mkdir -p "$log_dir"

payload=""
for arg in "$@"; do
  case "$arg" in
  \{*)
    payload="$arg"
    ;;
  esac
done

stdin_payload="$(cat 2>/dev/null || true)"
if [ -z "$payload" ] && [ -n "$stdin_payload" ]; then
  payload="$stdin_payload"
fi

if [ -x "$event_script" ]; then
  if [ -n "$payload" ]; then
    "$event_script" agent-turn-complete "$payload" >> "$log_file" 2>&1 || true
  else
    "$event_script" agent-turn-complete >> "$log_file" 2>&1 || true
  fi
else
  printf '%s missing event script: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$event_script" >> "$log_file"
fi
