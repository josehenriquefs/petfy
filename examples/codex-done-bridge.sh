#!/bin/zsh
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
bridge_dir="$(cd "$script_dir/../bridge" && pwd)"

if [ "$#" -gt 0 ]; then
  event_json="$1"
else
  event_json="{\"type\":\"agent-turn-complete\",\"cwd\":\"$PWD\"}"
fi

node "$bridge_dir/src/cli.js" notify "$event_json"
