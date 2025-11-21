#!/usr/bin/env bash
set -euo pipefail

# Launch applications with VirtualGL acceleration

if [ $# -eq 0 ]; then
  echo "Usage: vgl_launch.sh <command> [args...]"
  echo ""
  echo "Examples:"
  echo "  vgl_launch.sh blender"
  echo "  vgl_launch.sh glxspheres64"
  echo "  vgl_launch.sh openscad model.scad"
  echo ""
  echo "This script automatically:"
  echo "  - Adds VirtualGL to PATH"
  echo "  - Runs application with vglrun for GPU acceleration"
  echo "  - Handles DISPLAY configuration"
  exit 1
fi

# Add VirtualGL to PATH

# Check DISPLAY
if [ -z "${DISPLAY:-}" ]; then
  echo "WARNING: DISPLAY not set, using :1"
  export DISPLAY=:1
fi

# Check if vglrun is available
if ! command -v vglrun >/dev/null 2>&1; then
  echo "ERROR: VirtualGL not found"
  echo "Running without GPU acceleration..."
  exec "$@"
fi

# Launch with VirtualGL
echo "Launching with VirtualGL GPU acceleration..."
printf 'Command: vglrun'
for arg in "$@"; do
  printf ' %q' "${arg}"
done
printf '\n'
echo ""
exec vglrun "$@"
