#!/usr/bin/env bash
set -euo pipefail

SESSION="ros_multi"
CONDA_SH="/etc/profile.d/conda.sh"

if ! command -v tmux >/dev/null 2>&1; then
  echo "[ros_multiterm] tmux is not installed. Install tmux before running this helper." >&2
  exit 1
fi

# Allow re-attachment if the session already exists
if ! tmux has-session -t "${SESSION}" 2>/dev/null; then
  tmux new-session -d -s "${SESSION}"
else
  echo "[ros_multiterm] Session '${SESSION}' already exists; attaching..."
  tmux attach-session -t "${SESSION}"
  exit 0
fi

# Helper to prefix each tmux pane with conda initialization if available
tmux_conda_prefix() {
  local target="$1"
  if [ -f "${CONDA_SH}" ]; then
    tmux send-keys -t "${target}" "source ${CONDA_SH} >/dev/null 2>&1 || true" C-m
  fi
}

# Window 0: Humble workspace
tmux rename-window -t "${SESSION}:0" 'Humble'
tmux_conda_prefix "${SESSION}:0"
tmux send-keys -t "${SESSION}:0" "conda activate ros2_humble >/dev/null 2>&1 || true" C-m
tmux send-keys -t "${SESSION}:0" "cd /workspaces/humble_ws" C-m

# Window 1: ROS workspace (using ROS_DISTRO from environment/config.sh)
ROS_WINDOW_NAME="${ROS_DISTRO:-jazzy}"
# A6: Use POSIX-compliant uppercase first character (Bash 4+ ${var^} not portable)
# Extract first character, uppercase it, then append rest using POSIX-compliant commands
first_char=$(printf '%s' "${ROS_WINDOW_NAME}" | cut -c1)
rest_chars=$(printf '%s' "${ROS_WINDOW_NAME}" | cut -c2-)
ROS_WINDOW_NAME="$(printf '%s%s' "$(printf '%s' "${first_char}" | tr '[:lower:]' '[:upper:]')" "${rest_chars}")"
tmux new-window -t "${SESSION}:1" -n "${ROS_WINDOW_NAME}"
tmux_conda_prefix "${SESSION}:1"
tmux send-keys -t "${SESSION}:1" "conda activate ros2_${ROS_DISTRO:-jazzy} >/dev/null 2>&1 || true" C-m
tmux send-keys -t "${SESSION}:1" "cd /workspaces/${ROS_DISTRO:-jazzy}_ws" C-m

# Window 2: Bridge/monitoring
tmux new-window -t "${SESSION}:2" -n 'Bridge'
tmux_conda_prefix "${SESSION}:2"
tmux send-keys -t "${SESSION}:2" "echo 'Domain bridge - start when ready'" C-m

# Window 3: Julia processing
tmux new-window -t "${SESSION}:3" -n 'Julia'
tmux send-keys -t "${SESSION}:3" 'julia' C-m

tmux attach-session -t "${SESSION}"
