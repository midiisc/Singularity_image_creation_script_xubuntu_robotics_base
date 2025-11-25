#!/usr/bin/env bash
set -euo pipefail

# Display comprehensive OpenGL/VirtualGL information


echo "=========================================="
echo "OpenGL & VirtualGL Information"
echo "=========================================="
echo ""

# System info
display_value="${DISPLAY:-NOT SET}"
echo "Display: ${display_value}"
echo "Hostname: $(hostname)"
echo ""

# GPU info
echo "GPU Information:"
if command -v nvidia-smi >/dev/null 2>&1; then
  if ! { nvidia-smi --query-gpu=index,name,driver_version,memory.total,memory.used \
    --format=csv,noheader | nl; }; then
    echo "  ⚠ Unable to query GPU information"
  fi
else
  echo "  No NVIDIA GPU detected"
fi
echo ""

# OpenGL info (software rendering)
echo "OpenGL (Software Rendering):"
if [ -n "${DISPLAY:-}" ] && command -v glxinfo >/dev/null 2>&1; then
  if ! { glxinfo | grep -E "OpenGL (vendor|renderer|version|shading)" | sed 's/^/  /'; }; then
    echo "  ⚠ Unable to query OpenGL information (software rendering)"
  fi
else
  echo "  Cannot query (DISPLAY not set or glxinfo not found)"
fi
echo ""

# OpenGL info (with VirtualGL)
echo "OpenGL (VirtualGL/GPU Rendering):"
if [ -n "${DISPLAY:-}" ] && command -v vglrun >/dev/null 2>&1 && command -v glxinfo >/dev/null 2>&1; then
  if ! { vglrun glxinfo | grep -E "OpenGL (vendor|renderer|version|shading)" | sed 's/^/  /'; }; then
    echo "  ⚠ Unable to query VirtualGL OpenGL information"
  fi
else
  echo "  Cannot query (VirtualGL not available)"
fi
echo ""



# VirtualGL status
echo "VirtualGL Status:"
if command -v vglrun >/dev/null 2>&1; then
  vglrun_path="$(command -v vglrun)"
  echo "  ✓ VirtualGL installed: ${vglrun_path}"
  if ! vglrun --version 2>&1 | head -1 | sed 's/^/  /'; then
    echo "  ⚠ Unable to read VirtualGL version"
  fi
else
  echo "  ✗ VirtualGL not found"
fi
echo ""

# Available tools
echo "Available Utilities:"
for tool in vglrun glxinfo glxspheres64 eglinfo cpustat nettest tcbench; do
  if command -v "${tool}" >/dev/null 2>&1; then
    echo "  ✓ ${tool}"
  else
    echo "  ✗ ${tool} (not found)"
  fi
done

echo ""
echo "=========================================="
