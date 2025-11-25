#!/usr/bin/env bash
set -euo pipefail

# VirtualGL Test Script

echo "=========================================="
echo "VirtualGL Installation Test"
echo "=========================================="
echo ""

vgl_available="no"
if command -v vglrun >/dev/null 2>&1; then
  vgl_available="yes"
fi

timeout_available="no"
if command -v timeout >/dev/null 2>&1; then
  timeout_available="yes"
fi

echo "1. Checking VirtualGL binaries:"
for binary in vglrun glxinfo glxspheres64; do
  if command -v "${binary}" >/dev/null 2>&1; then
    binary_path="$(command -v "${binary}")"
    printf '  ✓ %s: %s\n' "${binary}" "${binary_path}"
  else
    printf '  ✗ %s: NOT FOUND\n' "${binary}"
  fi
done

echo ""
echo "2. VirtualGL version:"
if [ "${vgl_available}" = "yes" ]; then
  if ! vglrun --version 2>&1 | head -1; then
    echo "  ⚠ Unable to read VirtualGL version"
  fi
else
  echo "  ⚠ VirtualGL not found"
fi

echo ""
echo "3. OpenGL Information (via VirtualGL):"
if [ -n "${DISPLAY:-}" ]; then
  echo "  Display: ${DISPLAY}"
  if [ "${vgl_available}" = "yes" ] && command -v glxinfo >/dev/null 2>&1; then
    if ! { vglrun glxinfo 2>/dev/null | grep -E "OpenGL (vendor|renderer|version)" | head -3; }; then
      echo "  ⚠ Unable to query VirtualGL OpenGL information"
    fi
  else
    echo "  ⚠ glxinfo or VirtualGL unavailable; skipping GPU OpenGL query"
  fi
else
  echo "  ⚠ DISPLAY not set, skipping OpenGL test"
fi

echo ""
echo "4. GPU Detection:"
if command -v nvidia-smi >/dev/null 2>&1; then
  gpu_info=""
  if [ "${timeout_available}" = "yes" ]; then
    gpu_info="$(timeout 5 nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null || true)"
  else
    gpu_info="$(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null || true)"
  fi

  if [ -n "${gpu_info}" ]; then
    echo "  NVIDIA GPU:"
    printf '%s\n' "${gpu_info}" | sed 's/^/  /'
  else
    echo "  ⚠ GPU info unavailable"
  fi
else
  echo "  ⚠ nvidia-smi not found"
fi

echo ""
echo "=========================================="
echo "Test complete!"
echo ""
echo "To test 3D acceleration with VNC:"
echo "  1. Start VNC server: start_vnc_xfce.sh"
echo "  2. Connect with VNC viewer"
echo "  3. Open terminal in VNC session"
echo "  4. Run: vglrun glxspheres64"
echo "     (Should show 1000+ FPS with GPU)"
echo "  5. Compare without VGL: glxspheres64"
echo "     (Will show lower FPS with software rendering)"
echo "=========================================="
