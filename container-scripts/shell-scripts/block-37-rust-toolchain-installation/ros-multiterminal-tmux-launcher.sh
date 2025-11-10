#!/bin/bash
# Launch tmux session with multiple ROS environments

set -euo pipefail

SESSION="ros_multi"

# Create new tmux session
if ! command -v tmux >/dev/null 2>&1; then
  echo "Error: tmux not found. Please install tmux first." >&2
  exit 1
fi

if ! tmux new-session -d -s "${SESSION}" 2>/dev/null; then
  echo "✗ Failed to create tmux session ${SESSION}" >&2
  exit 1
fi

# Window 0: Humble workspace
tmux rename-window -t "${SESSION}:0" 'Humble' 2>/dev/null || true
tmux send-keys -t "${SESSION}:0" "conda activate ros2_humble" C-m 2>/dev/null || true
tmux send-keys -t "${SESSION}:0" "cd /workspaces/humble_ws" C-m 2>/dev/null || true

# Window 1: Jazzy workspace
tmux new-window -t "${SESSION}:1" -n 'Jazzy' 2>/dev/null || true
tmux send-keys -t "${SESSION}:1" "conda activate ros2_jazzy" C-m 2>/dev/null || true
tmux send-keys -t "${SESSION}:1" "cd /workspaces/jazzy_ws" C-m 2>/dev/null || true

# Window 2: Bridge/monitoring
tmux new-window -t "${SESSION}:2" -n 'Bridge' 2>/dev/null || true
tmux send-keys -t "${SESSION}:2" "echo 'Start domain bridge when ready'" C-m 2>/dev/null || true
tmux send-keys -t "${SESSION}:2" "python3 /opt/scripts/domain_bridge.py" C-m 2>/dev/null || true


# Window 3: Julia processing
tmux new-window -t "${SESSION}:3" -n 'Julia' 2>/dev/null || true
tmux send-keys -t "${SESSION}:3" "echo 'Julia server: julia /opt/scripts/julia_vision_server.jl'" C-m 2>/dev/null || true
tmux send-keys -t "${SESSION}:3" "julia" C-m 2>/dev/null || true


# Window 4: Monitoring (split pane)
tmux new-window -t "${SESSION}:4" -n 'Monitor' 2>/dev/null || true
tmux send-keys -t "${SESSION}:4" 'btm' C-m 2>/dev/null || true
tmux split-window -h -t "${SESSION}:4" 2>/dev/null || true
tmux send-keys -t "${SESSION}:4.1" 'nvtop' C-m 2>/dev/null || true

# Attach to session
if ! tmux attach-session -t "${SESSION}"; then
  echo "✗ Failed to attach to tmux session ${SESSION}" >&2
  exit 1
fi
