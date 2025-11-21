#!/usr/bin/env bash
# VirtualGL Test and Debug Script

set -euo pipefail

# Configuration
VGL_DISPLAY="${VGL_DISPLAY:-:1}"
VGL_VERBOSE="${VGL_VERBOSE:-1}"
VGL_DEBUG="${VGL_DEBUG:-1}"

echo "=========================================="
echo "VirtualGL Test and Debug Script"
echo "=========================================="
echo ""

# Test 1: Check VirtualGL installation
echo "1. Checking VirtualGL installation..."
if command -v vglrun >/dev/null 2>&1; then
  VGLRUN_PATH=$(command -v vglrun)
  echo "  ✓ vglrun found: ${VGLRUN_PATH}"
  vglrun --version 2>/dev/null || echo "  ⚠ Could not get version"
else
  echo "  ✗ vglrun not found"
  exit 1
fi

# Test 2: Check display
echo ""
echo "2. Checking display configuration..."
echo "  VGL_DISPLAY: ${VGL_DISPLAY}"
echo "  DISPLAY: ${DISPLAY:-not set}"

VGL_X_SOCKET="/tmp/.X11-unix/X${VGL_DISPLAY#:}"
if [ -S "${VGL_X_SOCKET}" ]; then
  echo "  ✓ X socket found: ${VGL_X_SOCKET}"
else
  echo "  ✗ X socket not found: ${VGL_X_SOCKET}"
fi

# Test 3: Test VirtualGL connection
echo ""
echo "3. Testing VirtualGL connection..."
if vglrun -d "${VGL_DISPLAY}" glxinfo >/dev/null 2>&1; then
  echo "  ✓ VirtualGL can access display ${VGL_DISPLAY}"
else
  echo "  ✗ VirtualGL cannot access display ${VGL_DISPLAY}"
  echo "  Trying to get more info..."
  vglrun -d "${VGL_DISPLAY}" glxinfo 2>&1 | head -10
fi

# Test 4: Check OpenGL rendering
echo ""
echo "4. Checking OpenGL rendering..."
if vglrun -d "${VGL_DISPLAY}" glxinfo | grep -q "OpenGL renderer"; then
  echo "  ✓ OpenGL rendering available"
  OPENGL_RENDERER=$(
    vglrun -d "${VGL_DISPLAY}" glxinfo \
      | awk -F': ' '/OpenGL renderer/{print $2; exit}' \
      || true
  )
  OPENGL_VERSION=$(
    vglrun -d "${VGL_DISPLAY}" glxinfo \
      | awk -F': ' '/OpenGL version/{print $2; exit}' \
      || true
  )
  echo "  OpenGL renderer: ${OPENGL_RENDERER}"
  echo "  OpenGL version: ${OPENGL_VERSION}"
else
  echo "  ✗ OpenGL rendering not available"
fi

# Test 5: Test glxspheres64
echo ""
echo "5. Testing glxspheres64..."
if command -v glxspheres64 >/dev/null 2>&1; then
  echo "  ✓ glxspheres64 found"
  echo "  Running glxspheres64 test (5 seconds)..."
  timeout 5s vglrun -d "${VGL_DISPLAY}" glxspheres64 2>&1 | head -10 || echo "  ⚠ glxspheres64 test timed out or failed"
else
  echo "  ✗ glxspheres64 not found"
fi

# Test 6: Environment variables
echo ""
echo "6. VirtualGL environment variables:"
echo "  VGL_DISPLAY: ${VGL_DISPLAY:-not set}"
echo "  VGL_COMPRESS: ${VGL_COMPRESS:-not set}"
echo "  VGL_READBACK: ${VGL_READBACK:-not set}"
echo "  VGL_LOGO: ${VGL_LOGO:-not set}"
echo "  VGL_FPS: ${VGL_FPS:-not set}"
echo "  VGL_VERBOSE: ${VGL_VERBOSE:-not set}"

# Test 7: X11 authentication
echo ""
echo "7. Checking X11 authentication..."
if [ -f "${HOME}/.Xauthority" ]; then
  echo "  ✓ .Xauthority file found"
  if xauth list 2>/dev/null | grep -q "${VGL_DISPLAY}"; then
    echo "  ✓ X11 auth for display ${VGL_DISPLAY} found"
  else
    echo "  ⚠ X11 auth for display ${VGL_DISPLAY} not found"
  fi
else
  echo "  ⚠ .Xauthority file not found"
fi

echo ""
echo "=========================================="
echo "VirtualGL test completed"
echo "=========================================="
