#!/usr/bin/env bash
set -euo pipefail

# VirtualGL GPU Benchmark Script

TIMEOUT_BIN=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_BIN="$(command -v timeout)"
else
  echo "⚠ 'timeout' utility not available; timed benchmark samples will be skipped."
fi

echo "=========================================="
echo "VirtualGL GPU Benchmark"
echo "=========================================="
echo ""

if [ -z "${DISPLAY:-}" ]; then
  echo "ERROR: DISPLAY not set"
  echo "Start VNC first: start_vnc_xfce.sh"
  exit 1
fi

if ! command -v vglrun >/dev/null 2>&1; then
  echo "ERROR: VirtualGL not found"
  exit 1
fi

collect_samples() {
  local duration="$1"
  shift
  local run_output=""

  if [ -z "${TIMEOUT_BIN}" ]; then
    echo "   ⚠ Skipping '${*}' sample (timeout utility not available)"
    return 0
  fi

  run_output="$(${TIMEOUT_BIN} "${duration}" "$@" 2>&1 || true)"

  grep -Ei "frames|fps" <<< "${run_output}" | tail -3 || true
}

echo "GPU Information:"
if command -v nvidia-smi >/dev/null 2>&1; then
  if ! nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader; then
    echo "  ⚠ Unable to query GPU information"
  fi
else
  echo "  nvidia-smi not available"
fi

echo ""
echo "Testing OpenGL rendering..."
echo ""

# Test 1: Without VirtualGL (software rendering)
echo "1. Software rendering (no VirtualGL):"
echo "   Running: glxspheres64"
if command -v glxspheres64 >/dev/null 2>&1; then
  collect_samples 10 glxspheres64
else
  echo "   glxspheres64 not found"
fi

echo ""

# Test 2: With VirtualGL (GPU rendering)
echo "2. GPU rendering (with VirtualGL):"
echo "   Running: vglrun glxspheres64"
if command -v glxspheres64 >/dev/null 2>&1; then
  collect_samples 10 vglrun glxspheres64
else
  echo "   glxspheres64 not found"
fi

echo ""
echo "=========================================="
echo "Benchmark complete!"
echo ""
echo "Expected results:"
echo "  Software rendering: ~30-100 FPS"
echo "  GPU rendering:      ~1000+ FPS"
echo ""
echo "If GPU rendering shows low FPS:"
echo "  1. Check GPU is visible: nvidia-smi"
echo "  2. Check VNC started with --nv flag"
echo "  3. Check DISPLAY is set: echo \$DISPLAY"
echo "=========================================="
