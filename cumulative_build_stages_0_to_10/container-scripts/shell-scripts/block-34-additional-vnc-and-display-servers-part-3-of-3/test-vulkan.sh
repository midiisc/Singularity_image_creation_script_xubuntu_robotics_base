#!/usr/bin/env bash
# Test Vulkan support

set -euo pipefail

if ! command -v vulkaninfo >/dev/null 2>&1; then
  echo "ERROR: vulkaninfo command not found. Install vulkan-tools." >&2
  exit 1
fi

echo "Vulkan Instance Version:"
vulkaninfo --summary 2>/dev/null | grep "Vulkan Instance Version" || echo "  ⚠ Unable to determine instance version"

echo ""
echo "Available Vulkan Devices:"
if ! vulkaninfo 2>/dev/null | grep -A 5 "GPU id"; then
  echo "  ⚠ No Vulkan devices detected"
fi

echo ""
echo "Running vulkan cube demo (vglrun required if VirtualGL active)..."
if command -v vkcube >/dev/null 2>&1; then
  if command -v vglrun >/dev/null 2>&1; then
    vglrun vkcube || echo "  ⚠ vkcube failed under VirtualGL"
  else
    vkcube || echo "  ⚠ vkcube failed"
  fi
else
  echo "  ⚠ vkcube command not available"
fi
