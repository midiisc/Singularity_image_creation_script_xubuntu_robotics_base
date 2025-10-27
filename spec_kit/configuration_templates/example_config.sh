# Example Configuration Template
# Copy this file and modify as needed for your specific requirements

# Base system configuration
export BASE_OS="ubuntu"
export BASE_OS_VERSION="24.04"
export BASE_OS_CODENAME="noble"
export SYSTEM_PYTHON_VER="3.12"
export ROS_DISTRO="jazzy"

# Build parameters
export DISK_SPACE_REQUIRED_GB=150
export PARALLEL_DOWNLOADS=4
export CACHE_KEEP_VERSIONS=2

# Software versions (modify as needed)
export COLMAP_VERSION="3.12.6"
export OPEN3D_VERSION="0.19.0"
export OPENCV_VERSION="4.12.0"
export CERES_VERSION="2.2.0"
export G2O_VERSION="20241228_git"
export GTSAM_VERSION="4.2.0"

# CUDA configuration
export CUDA_VERSION="12.6"
export CUDA_ARCH="8.6"  # Adjust for your GPU

# Remote desktop
export TURBOVNC_VER="3.2.1"
export VIRTUALGL_VER="3.1.4"

# Usage:
# 1. Copy this file to your project directory
# 2. Modify the values as needed
# 3. Source the file in your build script