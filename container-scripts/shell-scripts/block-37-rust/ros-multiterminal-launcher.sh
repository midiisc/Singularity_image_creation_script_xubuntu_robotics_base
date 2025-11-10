#!/bin/bash
# Default to Zellij, fallback to tmux
set -euo pipefail
if command -v zellij >/dev/null 2>&1; then
  exec /usr/local/bin/ros_multiterm_zellij "$@"
elif command -v tmux >/dev/null 2>&1; then
  exec /usr/local/bin/ros_multiterm_tmux "$@"
else
  echo "Error: No terminal multiplexer found (zellij or tmux)" >&2
  exit 1
fi
