#!/usr/bin/env bash
# shellcheck shell=bash
# Purpose: VirtualGL convenience aliases and functions
# This file is sourced to provide VirtualGL aliases and helper functions
# ============================================================================
# VirtualGL Convenience Aliases and Functions
# ============================================================================
#
# NOTE: This script is sourced, so strict mode (set -euo pipefail) is not enabled
# to allow graceful handling when commands fail in interactive shells.
# Individual functions use explicit error handling.

# Ensure VirtualGL is in PATH

# Quick GPU-accelerated application launches
alias vblender='vglrun blender'
alias vopenscad='vglrun openscad'
alias vfreecad='vglrun freecad'
alias vmeshlab='vglrun meshlab'

# Quick benchmark
alias gpubench='vglrun glxspheres64'

# Purpose: Query GPU OpenGL information using VirtualGL
# Returns: 0 on success, 1 on failure
gpuinfo() {
  if ! command -v vglrun >/dev/null 2>&1; then
    echo "VirtualGL not found"
    return 1
  fi
  if ! command -v glxinfo >/dev/null 2>&1; then
    echo "glxinfo not found"
    return 1
  fi
  # D3: Use here-string instead of unsafe pipe pattern
  local glx_output
  glx_output=$(vglrun glxinfo 2>&1 || echo "")
  if [ -z "${glx_output:-}" ]; then
    echo "Unable to query GPU OpenGL information"
    return 1
  fi
  if ! grep -E "OpenGL (vendor|renderer|version)" <<< "${glx_output}"; then
    echo "Unable to query GPU OpenGL information"
    return 1
  fi
}

# Purpose: Launch any application with VirtualGL
# Parameters: $@ = command and arguments to run with vglrun
# Returns: Exit code from vglrun command
vgl() {
  # D1-D4: Quote positional parameters
  if [ "$#" -eq 0 ]; then
    echo "Usage: vgl <command> [args...]"
    echo "Example: vgl blender"
    return 1
  fi
  vglrun "$@"
}

# Purpose: Compare software vs GPU rendering performance
# Parameters: $1 = application name (default: glxspheres64)
# Returns: 0 on success, 1 on failure
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
      # F2: Capture both output and exit code separately
      output="$(timeout 5 "${app}" 2>&1 || true)"
      # D3: Use here-string instead of pipe pattern
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
      # F2: Capture both output and exit code separately
      output="$(timeout 5 vglrun "${app}" 2>&1 || true)"
      # D3: Use here-string instead of pipe pattern
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
