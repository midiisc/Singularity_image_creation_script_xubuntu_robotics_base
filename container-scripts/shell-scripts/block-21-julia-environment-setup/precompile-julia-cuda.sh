#!/usr/bin/env bash
set -euo pipefail

JULIA_BIN="${JULIA_BIN:-${JULIA_HOME}/bin/julia}"
if ! command -v "$JULIA_BIN" >/dev/null 2>&1; then
  # A5a: Use printf instead of echo (POSIX-compliant, no flag interpretation)
  printf '%s\n' "[precompile_julia_cuda] ${JULIA_BIN:-} not found; skipping."
  exit 0
fi

if ! command -v nvidia-smi >/dev/null 2>&1; then
  # A5a: Use printf instead of echo (POSIX-compliant, no flag interpretation)
  printf '%s\n' "[precompile_julia_cuda] no NVIDIA GPU visible; skipping."
  exit 0
fi

ENV_DIR="${1:-${JULIA_HOME}envs/robotics-cuda}"
PROJECT_OPT="-e"
if [ -d "${ENV_DIR}" ]; then
  PROJECT_OPT="--project=${ENV_DIR}"
fi

"${JULIA_BIN}" "${PROJECT_OPT}" -e '
  try
    using Pkg
    Pkg.instantiate()
    @info "Touching CUDA packages for GPU precompile..."
    using CUDA
    CUDA.versioninfo()
    using KernelAbstractions
    using Flux
    println("GPU precompile completed.")
  catch e
    @warn "GPU precompile failed" exception=e
  end
'
