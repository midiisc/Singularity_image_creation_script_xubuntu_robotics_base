#!/bin/bash
#===============================================================================
# CENTRALIZED CONFIGURATION
# Single source of truth for all software versions, URLs, and parameters
#===============================================================================
# Purpose: Centralize all version numbers and URLs for easy maintenance
# Usage: Source this file at the beginning of build and post scripts
#        source "$(dirname "$0")/config.sh"
#===============================================================================

#===============================================================================
# BASE SYSTEM CONFIGURATION
#===============================================================================
export BASE_OS="ubuntu"
export BASE_OS_VERSION="24.04"
export BASE_OS_CODENAME="noble"
export SYSTEM_PYTHON_VER="3.12"
export ROS_DISTRO="jazzy"

#===============================================================================
# BUILD LOGGING CONFIGURATION
#===============================================================================
# Number of log files to keep (includes current run)
# n=2 means current run + 1 previous run
# n=3 means current run + 2 previous runs, etc.
export BUILD_LOG_KEEP_COUNT=2

# Log file directory (relative to workspace root)
export BUILD_LOG_DIR="build_logs"

# Log file prefix (timestamp will be appended)
# Timestamp format: YYYYMMDD_Day_HHMM_AMPM (e.g., 20241027_Sun_1430_PM)
export BUILD_LOG_PREFIX="singularity_build"

# Sync interval (seconds) - how often to flush log to disk
# Lower = better crash protection, slightly more I/O overhead
# Higher = less I/O overhead, slightly more data at risk if crashed
# Recommended: 30-120 seconds, default: 60
export BUILD_LOG_SYNC_INTERVAL=60

# Base Docker/Singularity Image
export BASE_IMAGE_REPO="osrf/ros"
export BASE_IMAGE_VARIANT="desktop-full"
export BASE_IMAGE="${BASE_IMAGE_REPO}:${ROS_DISTRO}-${BASE_IMAGE_VARIANT}-${BASE_OS_CODENAME}"

#===============================================================================
# SOFTWARE VERSIONS
#===============================================================================

# Python/Conda
export MINIFORGE_VER="25.3.1-0"
export MICROMAMBA_VER="2.3.2-0"

# Python Packages (Data Formats)
export H5PY_VERSION="3.9.0"
export ZARR_VERSION="2.16.0"

# Python Packages (Messaging/IPC)
export PYZMQ_VERSION="25.1.0"
export MSGPACK_VERSION="1.0.7"

# Python Packages (Julia Bridge)
export JULIACALL_VERSION="0.9.14"
export JULIAPKG_VERSION="0.1.10"

# Remote Desktop
export TURBOVNC_VER="3.2.1"
export VIRTUALGL_VER="3.1.4"
export NOVNC_VER="1.6.0"

# Development Tools
export YQ_VER="v4.48.1"
export JULIA_LTS_VER="1.10.5"

# SLAM/Robotics Libraries
export CERES_VERSION="2.2.0"
export PYCERES_VERSION="2.5"
export G2O_VERSION="20241228_git"
export GTSAM_VERSION="4.2.0"
export OPENCV_VERSION="4.12.0"

# 3D Reconstruction / SfM / NeRF
export COLMAP_VERSION="3.12.6"
export OPEN3D_VERSION="0.19.0"
export OPEN3D_WEBRTC_VER="60e6748"

# NVIDIA Video Codec SDK
export NVIDIA_VIDEO_SDK_VERSION="12.1.14"

# Desktop Applications
export FREECAD_VERSION="1.0.2"
export KASMVNC_VERSION="1.3.1"

# Modern CLI Tools (Rust-based) - all compiled from source
# Updated to latest compatible versions as of 2025-11-03
export BAT_VERSION="0.26.0"
export FD_VERSION="10.3.0"
export RIPGREP_VERSION="15.1.0"
export EZA_VERSION="0.23.4"
export BOTTOM_VERSION="0.11.2"
export PROCS_VERSION="0.14.10"
export ZELLIJ_VERSION="0.43.1"
export DU_DUST_VERSION="1.2.3"
export OX_VERSION="latest"  # no version pinning for ox

# Middleware
export ZENOH_VERSION="1.6.2"
export ZENOH_ROS2DDS_VERSION="1.6.2"  # ROS 2 DDS bridge plugin version

# GPU/CUDA
export NVIDIA_KEYRING_VER="1.1-1"
export CUDA_VERSION="12.6"
export CUDA_MAJOR="12"
export CUDNN_VER="9.14.0.64-1"  # CUDA 12.x compatible version (verified from repo)
# Note: Available cuDNN versions: 9.14.0.64-1 (CUDA 13/12), 9.10.2.21-1 (CUDA 11)
# If specific version not found, fallback logic will install latest compatible version
export CUDA_ARCH="8.6"  # NVIDIA A6000 architecture

#===============================================================================
# DOWNLOAD URLS (Constructed from versions)
#===============================================================================

# Miniforge
export MINIFORGE_SH="Miniforge3-${MINIFORGE_VER}-Linux-x86_64.sh"
export MINIFORGE_URL="https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VER}/${MINIFORGE_SH}"

# Micromamba
export MICROMAMBA_BIN="micromamba-linux-64"
export MICROMAMBA_URL="https://github.com/mamba-org/micromamba-releases/releases/download/${MICROMAMBA_VER}/${MICROMAMBA_BIN}"

# TurboVNC
export TURBOVNC_DEB="turbovnc_${TURBOVNC_VER}_amd64.deb"
export TURBOVNC_URL="https://github.com/TurboVNC/turbovnc/releases/download/${TURBOVNC_VER}/${TURBOVNC_DEB}"

# VirtualGL
export VIRTUALGL_DEB="virtualgl_${VIRTUALGL_VER}_amd64.deb"
export VIRTUALGL_URL="https://github.com/VirtualGL/virtualgl/releases/download/${VIRTUALGL_VER}/${VIRTUALGL_DEB}"

# yq (YAML processor)
export YQ_BIN="yq_linux_amd64"
export YQ_URL="https://github.com/mikefarah/yq/releases/download/${YQ_VER}/${YQ_BIN}"

# Julia
export JULIA_TARBALL="julia-${JULIA_LTS_VER}-linux-x86_64.tar.gz"
export JULIA_URL="https://julialang-s3.julialang.org/bin/linux/x64/${JULIA_LTS_VER%.*}/${JULIA_TARBALL}"
export JULIA_ASC_URL="https://julialang-s3.julialang.org/bin/linux/x64/${JULIA_LTS_VER%.*}/${JULIA_TARBALL}.asc"

# Drake
export DRAKE_ASC_URL="https://drake-apt.csail.mit.edu/drake.asc"
export DRAKE_KEY_URL="https://drake-apt.csail.mit.edu/drake.asc"

# NVIDIA
export NVIDIA_KEYRING_DEB="cuda-keyring_${NVIDIA_KEYRING_VER}_all.deb"
export NVIDIA_KEYRING_URL="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/${NVIDIA_KEYRING_DEB}"

# Zenoh
# Using standalone variant for container builds (self-contained, no system dependencies)
# Alternative: debian variant contains .deb packages for APT installation
export ZENOH_FILE="zenoh-${ZENOH_VERSION}-x86_64-unknown-linux-gnu-standalone.zip"
export ZENOH_URL="https://github.com/eclipse-zenoh/zenoh/releases/download/${ZENOH_VERSION}/${ZENOH_FILE}"

# Zenoh ROS 2 DDS Bridge Plugin
# Enables communication between Zenoh and ROS 2 DDS systems
export ZENOH_ROS2DDS_FILE="zenoh-plugin-ros2dds-${ZENOH_ROS2DDS_VERSION}-x86_64-unknown-linux-gnu-standalone.zip"
export ZENOH_ROS2DDS_URL="https://github.com/eclipse-zenoh/zenoh-plugin-ros2dds/releases/download/${ZENOH_ROS2DDS_VERSION}/${ZENOH_ROS2DDS_FILE}"

# Open3D WebRTC (prebuilt binaries for Open3D 0.19.0 with GLIBCXX_USE_CXX11_ABI=ON)
export OPEN3D_WEBRTC_FILE="webrtc_${OPEN3D_WEBRTC_VER}_cxx-abi-1.tar.gz"
export OPEN3D_WEBRTC_URL="https://github.com/isl-org/open3d_downloads/releases/download/webrtc-v3/${OPEN3D_WEBRTC_FILE}"

#===============================================================================
# SHA256 CHECKSUMS
#===============================================================================
export MINIFORGE_SHA256="376b160ed8130820db0ab0f3826ac1fc85923647f75c1b8231166e3d559ab768"
export MICROMAMBA_SHA256="ffc3cb8d52d4d6b354bdbb979c407719c485392b74e462cbd50811aa88e58f85"
export YQ_SHA256="99df6047f5b577a9d25f969f7c3823ada3488de2e2115b30a0abb10d9324fd9f"
export JULIA_SHA256="33497b93cf9dd65e8431024fd1db19cbfbe30bd796775a59d53e2df9a8de6dc0"
export OPEN3D_WEBRTC_SHA256="0d98ddbc4164b9e7bfc50b7d4eaa912a753dabde0847d85a64f93a062ae4c335"

#===============================================================================
# GPG KEY IDS AND URLS
#===============================================================================
export JULIA_GPG_KEY_ID="3673DF529D9049477F76B37566E3C7DC03D6E495"
export JULIA_GPG_KEY_URL="https://julialang.org/assets/juliareleases.asc"

# VirtualGL and TurboVNC use the same GPG signing key (v2.6.5+/v2.2.6+)
# Official documentation: https://virtualgl.org/Downloads/DigitalSignatures
# Key ID (short form): 4BACCAB36E7FE9A1
# Full fingerprint: 0xae1a7ba4efff9a9987e1474c4baccab36e7fe9a1
export VIRTUALGL_TURBOVNC_GPG_KEY_ID="4BACCAB36E7FE9A1"
export VIRTUALGL_TURBOVNC_GPG_KEY_URL="https://raw.githubusercontent.com/VirtualGL/repo/main/VGL-GPG-KEY"
export VIRTUALGL_TURBOVNC_GPG_KEY_URL_ALT="https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xae1a7ba4efff9a9987e1474c4baccab36e7fe9a1"

#===============================================================================
# BUILD PARAMETERS
#===============================================================================
export DISK_SPACE_REQUIRED_GB=150
# Host-side log retention (in build_logs/ directory)
# LOG_RETENTION_COUNT=1 means keep only the current run (delete all old logs)
# LOG_RETENTION_COUNT=2 means keep current run + 1 previous run (RECOMMENDED)
# LOG_RETENTION_COUNT=3 means keep current run + 2 previous runs, etc.
export LOG_RETENTION_COUNT=2
export PARALLEL_DOWNLOADS=4
export CACHE_KEEP_VERSIONS=2

#===============================================================================
# CACHE DIRECTORY STRUCTURE
#===============================================================================
export CACHE_DIR="${CACHE_DIR:-${PWD}/container_cache}"
export BIN_CACHE="${CACHE_DIR}/binaries"
export DEB_CACHE="${CACHE_DIR}/debs"
export APT_CACHE="${CACHE_DIR}/apt"
export APT_ARCHIVE_CACHE="${CACHE_DIR}/apt/archives"
export CONDA_CACHE="${CACHE_DIR}/conda_pkgs"
export JULIA_CACHE="${CACHE_DIR}/julia_pkgs"
export WHEELS_CACHE="${CACHE_DIR}/wheels"

#===============================================================================
# OUTPUT FILE NAMES
#===============================================================================
export SIF_NAME="${SIF_NAME:-xubuntu_base_image_complete.sif}"
export DEF_NAME="${DEF_NAME:-xubuntu_base_image_complete.def}"

#===============================================================================
# CONTAINER-INTERNAL PATHS
#===============================================================================
# These paths are used INSIDE the Singularity container after %files section copies
# They correspond to the mount points defined in the %files section of the .def file
# NOTE: These are different from host-side cache paths (BIN_CACHE, DEB_CACHE, etc.)

export CONTAINER_CACHE_ROOT="/container_cache"
export CONTAINER_BIN_CACHE="${CONTAINER_CACHE_ROOT}/binaries"
export CONTAINER_DEB_CACHE="${CONTAINER_CACHE_ROOT}/debs"
export CONTAINER_APT_CACHE="${CONTAINER_CACHE_ROOT}/apt/archives"
export CONTAINER_CONDA_CACHE="${CONTAINER_CACHE_ROOT}/conda_pkgs"
export CONTAINER_WHEELS_CACHE="${CONTAINER_CACHE_ROOT}/wheels"
export CONTAINER_JULIA_CACHE="${CONTAINER_CACHE_ROOT}/julia_pkgs"

#===============================================================================
# INSTALLATION PATHS (Container-Internal Directories)
#===============================================================================
# These paths define where software is installed inside the container
# Default: /opt is used for optional/add-on software per FHS standards

export INSTALL_PREFIX="/opt"
export RUST_HOME="${INSTALL_PREFIX}/rust"
export ZENOH_HOME="${INSTALL_PREFIX}/zenoh"
export DRAKE_HOME="${INSTALL_PREFIX}/drake"
export TURBOVNC_HOME="${INSTALL_PREFIX}/turbovnc"
export VIRTUALGL_HOME="${INSTALL_PREFIX}/VirtualGL"
export MINIFORGE_HOME="${INSTALL_PREFIX}/conda"
export JULIA_HOME="${INSTALL_PREFIX}/julia"
export MAMBA_ENVS="${INSTALL_PREFIX}/mamba-envs"
export JULIA_ENVS="${INSTALL_PREFIX}/juliaenvs"

# Container Build Temporary Directory (used during %post section)
# Note: This is INSIDE the container, not the host BUILD_TMP_DIR
export CONTAINER_BUILD_TMPDIR="/tmp/build-temp"

#===============================================================================
# END OF CONFIGURATION
#===============================================================================

