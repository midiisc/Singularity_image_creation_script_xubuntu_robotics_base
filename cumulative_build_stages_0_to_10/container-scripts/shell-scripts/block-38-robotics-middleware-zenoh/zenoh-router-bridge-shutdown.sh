#!/bin/bash
# Stop all Zenoh processes

set -euo pipefail

echo "Stopping Zenoh infrastructure..."
pids_terminated=false
if pkill -f zenohd >/dev/null 2>&1; then
  pids_terminated=true
fi
if pkill -f zenoh-bridge-ros2dds >/dev/null 2>&1; then
  pids_terminated=true
fi
if pkill -f zenoh-bridge-dds >/dev/null 2>&1; then
  pids_terminated=true
fi
if pkill -f zenoh-bridge >/dev/null 2>&1; then
  pids_terminated=true
fi

if [ "${pids_terminated}" = false ]; then
  echo "  No Zenoh processes were running"
fi
echo "✓ Zenoh stopped"
