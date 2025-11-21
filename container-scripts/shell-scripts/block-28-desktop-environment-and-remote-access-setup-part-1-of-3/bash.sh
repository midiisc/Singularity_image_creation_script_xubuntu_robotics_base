
# ============================================================================
# VirtualGL Convenience Aliases and Functions
# ============================================================================

# Ensure VirtualGL is in PATH

# Quick GPU-accelerated application launches
alias vblender='vglrun blender'
alias vopenscad='vglrun openscad'
alias vfreecad='vglrun freecad'
alias vmeshlab='vglrun meshlab'

# Quick benchmark
alias gpubench='vglrun glxspheres64'

gpuinfo() {
  if ! command -v vglrun >/dev/null 2>&1; then
    echo "VirtualGL not found"
    return 1
  fi
  if ! command -v glxinfo >/dev/null 2>&1; then
    echo "glxinfo not found"
    return 1
  fi
  if ! { vglrun glxinfo | grep -E "OpenGL (vendor|renderer|version)"; }; then
    echo "Unable to query GPU OpenGL information"
    return 1
  fi
}

# Helper function: launch any app with VirtualGL
vgl() {
  if [ $# -eq 0 ]; then
    echo "Usage: vgl <command> [args...]"
    echo "Example: vgl blender"
    return 1
  fi
  vglrun "$@"
}

# Helper function: compare software vs GPU rendering
compare_render() {
  local app="${1:-glxspheres64}"
  local timeout_available="no"
  local output=""

  echo "=== Software Rendering ==="
  if command -v timeout >/dev/null 2>&1; then
    timeout_available="yes"
  fi

  if [ "${timeout_available}" != "yes" ]; then
    echo "⚠ 'timeout' utility not available; skipping timed FPS comparisons."
  fi

  if command -v "${app}" >/dev/null 2>&1; then
    if [ "${timeout_available}" = "yes" ]; then
      output="$(timeout 5 "${app}" 2>&1 || true)"
      grep -Ei 'fps|frames' <<< "${output}" | tail -1 || true
    else
      echo "   ${app} available but timing skipped (requires 'timeout')"
    fi
  else
    echo "Application ${app} not found"
  fi

  echo ""
  echo "=== GPU Rendering (VirtualGL) ==="
  if ! command -v vglrun >/dev/null 2>&1; then
    echo "VirtualGL not available"
    return 1
  fi

  if command -v "${app}" >/dev/null 2>&1; then
    if [ "${timeout_available}" = "yes" ]; then
      output="$(timeout 5 vglrun "${app}" 2>&1 || true)"
      grep -Ei 'fps|frames' <<< "${output}" | tail -1 || true
    else
      echo "   ${app} with VirtualGL available but timing skipped (requires 'timeout')"
    fi
  else
    echo "Application ${app} not found"
    return 1
  fi
}


export -f vgl compare_render gpuinfo
