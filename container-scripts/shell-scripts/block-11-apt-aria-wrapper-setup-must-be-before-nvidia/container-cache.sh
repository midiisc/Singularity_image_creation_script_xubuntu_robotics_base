#!/usr/bin/env bash
# shellcheck shell=bash
# Purpose: Container cache environment variables
# These ensure apt-aria wrapper and other tools can find cache directories
#
# Rationale:
# - Provide cache locations in login shells and interactive sessions to ensure
#   uniform behavior when tools are invoked outside the main build flow.
# - Directories are created best-effort with errors suppressed to avoid
#   blocking non-critical initialization paths.
#
# NOTE: This script is sourced, so strict mode (set -euo pipefail) is not enabled
# to allow graceful handling when commands fail in interactive shells.
# Individual operations use explicit error suppression (|| true) where appropriate.

# Set default cache root if not already set
export CONTAINER_CACHE_ROOT="${CONTAINER_CACHE_ROOT:-/container_cache}"

# Set APT cache location
export CONTAINER_APT_CACHE="${CONTAINER_APT_CACHE:-${CONTAINER_CACHE_ROOT}/apt/archives}"

# Other cache locations
export CONTAINER_BIN_CACHE="${CONTAINER_BIN_CACHE:-${CONTAINER_CACHE_ROOT}/binaries}"
export CONTAINER_DEB_CACHE="${CONTAINER_DEB_CACHE:-${CONTAINER_CACHE_ROOT}/debs}"
export CONTAINER_CONDA_CACHE="${CONTAINER_CONDA_CACHE:-${CONTAINER_CACHE_ROOT}/conda_pkgs}"
export CONTAINER_WHEELS_CACHE="${CONTAINER_WHEELS_CACHE:-${CONTAINER_CACHE_ROOT}/wheels}"
export CONTAINER_JULIA_CACHE="${CONTAINER_JULIA_CACHE:-${CONTAINER_CACHE_ROOT}/julia_pkgs}"

# Ensure cache directories exist
mkdir -p "${CONTAINER_APT_CACHE}" "${CONTAINER_BIN_CACHE}" "${CONTAINER_DEB_CACHE}" \
         "${CONTAINER_CONDA_CACHE}" "${CONTAINER_WHEELS_CACHE}" "${CONTAINER_JULIA_CACHE}" 2>/dev/null || true
