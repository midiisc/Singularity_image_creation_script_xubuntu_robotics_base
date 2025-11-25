#!/bin/bash
# Start Zenoh router and bridges

set -euo pipefail

if ! command -v zenohd >/dev/null 2>&1; then
  echo "✗ zenohd not found. Install Zenoh before running this script." >&2
  exit 1
fi

echo "Starting Zenoh infrastructure..."

# Determine plugin availability
PLUGIN_COUNT=0
if [ -d "/opt/zenoh/plugins" ]; then
  PLUGIN_COUNT=$(find /opt/zenoh/plugins -mindepth 1 -maxdepth 1 -type f -name "*.so" 2>/dev/null | wc -l | tr -d '[:space:]')
fi

PLUGIN_ARGS=()
if [ -d "/opt/zenoh/plugins" ] && [ "${PLUGIN_COUNT}" -gt 0 ]; then
  export ZENOH_PLUGIN_SEARCH_DIR="/opt/zenoh/plugins"
  PLUGIN_ARGS+=(--plugin-search-dir "${ZENOH_PLUGIN_SEARCH_DIR}")
  echo "  Using Zenoh plugins directory: ${ZENOH_PLUGIN_SEARCH_DIR} (${PLUGIN_COUNT} plugin(s))"
fi

ROUTER_LOG="/tmp/zenoh-router.log"

# Start Zenoh router in background
echo "  Starting Zenoh router on port 7447..."
zenohd "${PLUGIN_ARGS[@]}" --config /etc/zenoh/zenoh-router.json5 > "${ROUTER_LOG}" 2>&1 &
ROUTER_PID=$!
sleep 2

# Check if router started
if ! ps -p "${ROUTER_PID}" > /dev/null 2>&1; then
  echo "  ✗ Failed to start Zenoh router"
  cat "${ROUTER_LOG}" 2>/dev/null || true
  exit 1
fi
echo "  ✓ Zenoh router started (PID: ${ROUTER_PID})"

start_bridge() {
  local bridge_name="$1"
  local bridge_config="$2"
  local log_path="$3"

  if ! command -v zenoh-bridge-ros2dds >/dev/null 2>&1 && ! command -v zenoh-bridge-dds >/dev/null 2>&1; then
    echo "  ⚠ No Zenoh bridge binary found - skipping ${bridge_name} bridge"
    echo "    Note: Bridge functionality requires zenoh-plugin-ros2dds installation"
    return 0
  fi

  local bridge_cmd
  if command -v zenoh-bridge-ros2dds >/dev/null 2>&1; then
    bridge_cmd="zenoh-bridge-ros2dds"
  elif command -v zenoh-bridge-dds >/dev/null 2>&1; then
    bridge_cmd="zenoh-bridge-dds"
  else
    bridge_cmd=""
  fi

  if [ -z "${bridge_cmd}" ]; then
    echo "  ⚠ Unable to determine bridge command for ${bridge_name}"
    return 0
  fi

  echo "  Starting Zenoh ROS 2 DDS bridge for ${bridge_name}..."
  local bridge_args=()
  if [ "${#PLUGIN_ARGS[@]}" -gt 0 ]; then
    bridge_args+=("${PLUGIN_ARGS[@]}")
  fi
  bridge_args+=(--config "${bridge_config}")

  "${bridge_cmd}" "${bridge_args[@]}" > "${log_path}" 2>&1 &
  local bridge_pid=$!
  sleep 1
  if ps -p "${bridge_pid}" > /dev/null 2>&1; then
    echo "  ✓ ${bridge_name} bridge started (PID: ${bridge_pid})"
  else
    echo "  ✗ Failed to start ${bridge_name} bridge"
    cat "${log_path}" 2>/dev/null || true
  fi
}

if [ -d "/conda/envs/ros2_humble" ]; then
  start_bridge "Humble (Domain 1)" "/etc/zenoh/zenoh-bridge-humble.json5" "/tmp/zenoh-humble.log"
fi



if [ -d "/conda/envs/ros2_jazzy" ] || ([ -n "${ROS_DISTRO:-}" ] && [ -d "/opt/ros/${ROS_DISTRO}" ]); then
  start_bridge "Jazzy (Domain 2)" "/etc/zenoh/zenoh-bridge-jazzy.json5" "/tmp/zenoh-jazzy.log"
fi

echo "Zenoh infrastructure ready!"
echo "  Router: http://localhost:8000 (REST API)"
echo "  Logs: /tmp/zenoh*.log"
echo ""
echo "To stop everything: zenoh_stop"
echo "To check status:   zenoh_status"
