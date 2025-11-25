#!/usr/bin/env bash
# shellcheck shell=bash
# Purpose: HPC MKL/CUDA Runtime Tuning
# This file is sourced to configure thread affinity, MKL threading, and CUDA settings
# Optimized for A6000 GPU and multi-core CPU systems
#
# NOTE: This script is sourced, so strict mode (set -euo pipefail) is not enabled
# to allow graceful handling when commands fail in interactive shells.
# All operations are environment variable exports, which are safe without strict mode.

# Thread Affinity Settings (OpenMP)
# close: Bind threads close to the master thread
export OMP_PROC_BIND="${OMP_PROC_BIND:-close}"
# cores: Bind threads to CPU cores (not hardware threads)
export OMP_PLACES="${OMP_PLACES:-cores}"
# Default to 32 threads (adjust based on your CPU)
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-32}"

# MKL Threading Configuration
# Use GNU OpenMP (libgomp) for compatibility with GCC toolchain
export MKL_THREADING_LAYER="${MKL_THREADING_LAYER:-GNU}"
# Match OpenMP thread count
export MKL_NUM_THREADS="${MKL_NUM_THREADS:-32}"
# Disable dynamic threading for consistent performance on HPC
export MKL_DYNAMIC="${MKL_DYNAMIC:-FALSE}"

# Intel MKL Thread Affinity (for compatibility with Intel OpenMP)
# granularity=fine: Fine-grained thread placement
# compact: Pack threads close together
# 1,0: Offset for thread placement
export KMP_AFFINITY="${KMP_AFFINITY:-granularity=fine,compact,1,0}"

# CUDA Device Configuration
# Maximum number of concurrent kernel launches per device
export CUDA_DEVICE_MAX_CONNECTIONS="${CUDA_DEVICE_MAX_CONNECTIONS:-1}"
# Set to 1 for debugging (synchronous kernel launches), 0 for performance
export CUDA_LAUNCH_BLOCKING="${CUDA_LAUNCH_BLOCKING:-0}"

# Monitoring Toggles (disabled by default, enable when needed)
# Set to 1 to enable MKL verbose output (for debugging)
export MKL_VERBOSE="${MKL_VERBOSE:-0}"
# Set to TRUE to display OpenMP environment at startup
export OMP_DISPLAY_ENV="${OMP_DISPLAY_ENV:-FALSE}"

# Performance Hints
# LP64: 64-bit integers, 32-bit pointers (standard)
# ILP64: 64-bit integers, 64-bit pointers (for large arrays)
export MKL_INTERFACE_LAYER="${MKL_INTERFACE_LAYER:-LP64,ILP64}"

# Optional: Display configuration in interactive shells
# A5a: Use printf instead of echo for robustness
if [ -n "${PS1:-}" ]; then
    printf '%s\n' "✅ HPC MKL/CUDA tuning configured"
    printf '%s\n' "   OMP Threads: ${OMP_NUM_THREADS}"
    printf '%s\n' "   MKL Threads: ${MKL_NUM_THREADS}"
    printf '%s\n' "   MKL Dynamic: ${MKL_DYNAMIC}"
    printf '%s\n' "   CUDA Connections: ${CUDA_DEVICE_MAX_CONNECTIONS}"
fi

