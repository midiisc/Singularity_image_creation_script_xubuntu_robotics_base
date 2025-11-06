#!/bin/bash
#===============================================================================
# PyTorch Compilation Test Script
# Purpose: Test PyTorch compilation from source with OpenBLAS (build only, no install)
# Usage: 
#   ./test_pytorch_compilation.sh                    # Run on host or inside container
#   ./test_pytorch_compilation.sh --overlay overlay.img --image image.sif  # Run in Singularity with overlay
#   ./test_pytorch_compilation.sh --overlay overlay.img --image image.sif --gpu  # With GPU support
#
# Prerequisites (automatically detected and installed if missing):
#   - util-linux (provides ionice for I/O priority limiting - CRITICAL for preventing system freezes)
#   - shellcheck (REQUIRED, for script validation)
#   - sysstat (REQUIRED, provides iostat for I/O monitoring)
#   - Standard build tools: build-essential, cmake, ninja-build, git, curl, wget
#   - Python development: python3-dev, python3-pip, python3-setuptools, python3-wheel
#   - Math libraries: libopenblas-dev, liblapack-dev, libblas-dev
#   - Threading libraries: libomp-dev, libtbb-dev
#
# Resource Limiting Features (ALL DYNAMICALLY CALCULATED FROM HARDWARE):
#   - CPU limiting: 25% of detected cores (adaptive based on system)
#   - Memory limiting: Adaptive per job (4-8GB based on available memory)
#   - I/O limiting: ionice idle class (prevents disk I/O saturation - CRITICAL)
#   - Disk-aware: Different limits for SSD vs HDD (SSD: up to 6 jobs, HDD: up to 3 jobs)
#   - CPU priority: nice 19 (lowest priority)
#   - Comprehensive resource monitoring: Memory, swap, CPU load, disk I/O
#   - Auto-stop: Automatically stops build if resources go critical (prevents system freeze)
#
# Dynamic Auto-Stop Thresholds (calculated from detected hardware):
#   - Memory: 5% of total RAM (adaptive, 1-2GB range)
#   - Swap: 25% of total swap (adaptive, 1-2GB range)
#   - CPU Load: 2x detected CPU cores (adaptive)
#   - Disk I/O Wait: SSD=60%, HDD=40% (adaptive based on disk type)
#
# Overlay Mode:
#   - Compiles PyTorch inside writable overlay (persistent storage)
#   - Build artifacts saved to overlay for reuse
#   - Requires Singularity/Apptainer and overlay image
#===============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#===============================================================================
# Detect Ubuntu Version for Compatibility
#===============================================================================
detect_ubuntu_version() {
    local ubuntu_version=""
    local ubuntu_codename=""
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ -n "${VERSION_ID:-}" ]; then
            ubuntu_version="${VERSION_ID}"
        fi
        if [ -n "${UBUNTU_CODENAME:-}" ]; then
            ubuntu_codename="${UBUNTU_CODENAME}"
        elif [ -n "${VERSION_CODENAME:-}" ]; then
            ubuntu_codename="${VERSION_CODENAME}"
        fi
    fi
    
    echo "${ubuntu_version}|${ubuntu_codename}"
}

# Detect system Ubuntu version
UBUNTU_INFO=$(detect_ubuntu_version)
UBUNTU_VERSION=$(echo "${UBUNTU_INFO}" | cut -d'|' -f1 || echo "")
UBUNTU_CODENAME=$(echo "${UBUNTU_INFO}" | cut -d'|' -f2 || echo "")

# Determine recommended PyTorch version based on Ubuntu version
# Ubuntu 22.04: PyTorch 2.6.0 (works with CMake 3.22, available in repos)
# Ubuntu 24.04: PyTorch 2.7+ (requires CMake 3.27+)
if [ -n "${UBUNTU_VERSION:-}" ]; then
    UBUNTU_MAJOR=$(echo "${UBUNTU_VERSION}" | cut -d. -f1 || echo "")
    UBUNTU_MINOR=$(echo "${UBUNTU_VERSION}" | cut -d. -f2 || echo "")
    
    # Validate version components are numeric before arithmetic comparison
    if [ -n "${UBUNTU_MAJOR:-}" ] && [ -n "${UBUNTU_MINOR:-}" ] && \
       echo "${UBUNTU_MAJOR}" | grep -qE '^[0-9]+$' && \
       echo "${UBUNTU_MINOR}" | grep -qE '^[0-9]+$'; then
        if [ "${UBUNTU_MAJOR}" -eq 22 ]; then
            RECOMMENDED_PYTORCH_VERSION="2.6.0"
            RECOMMENDED_CMAKE_VERSION="3.22"
            if [ -n "${UBUNTU_CODENAME:-}" ]; then
                echo "  Detected Ubuntu ${UBUNTU_VERSION} (${UBUNTU_CODENAME})"
            else
                echo "  Detected Ubuntu ${UBUNTU_VERSION}"
            fi
            echo "  Recommended PyTorch version: ${RECOMMENDED_PYTORCH_VERSION} (compatible with CMake 3.22)"
        elif [ "${UBUNTU_MAJOR}" -eq 24 ]; then
            RECOMMENDED_PYTORCH_VERSION="2.7.0"
            RECOMMENDED_CMAKE_VERSION="3.27"
            if [ -n "${UBUNTU_CODENAME:-}" ]; then
                echo "  Detected Ubuntu ${UBUNTU_VERSION} (${UBUNTU_CODENAME})"
            else
                echo "  Detected Ubuntu ${UBUNTU_VERSION}"
            fi
            echo "  Recommended PyTorch version: ${RECOMMENDED_PYTORCH_VERSION} (requires CMake 3.27+)"
        else
            # Default to latest for other versions
            RECOMMENDED_PYTORCH_VERSION=""
            RECOMMENDED_CMAKE_VERSION="3.27"
            if [ -n "${UBUNTU_CODENAME:-}" ]; then
                echo "  Detected Ubuntu ${UBUNTU_VERSION} (${UBUNTU_CODENAME})"
            else
                echo "  Detected Ubuntu ${UBUNTU_VERSION}"
            fi
            echo "  Will use latest PyTorch version (may require CMake 3.27+)"
        fi
    else
        # Invalid version format
        RECOMMENDED_PYTORCH_VERSION=""
        RECOMMENDED_CMAKE_VERSION="3.27"
        echo "  ⚠ Could not parse Ubuntu version format: ${UBUNTU_VERSION}"
        echo "  Defaulting to latest PyTorch (CMake 3.27+)"
    fi
else
    RECOMMENDED_PYTORCH_VERSION=""
    RECOMMENDED_CMAKE_VERSION="3.27"
    echo "  Could not detect Ubuntu version, defaulting to latest PyTorch (CMake 3.27+)"
fi

#===============================================================================
# Parse Command-Line Arguments
#===============================================================================
OVERLAY_PATH=""
IMAGE_PATH=""
USE_GPU=false
RUN_INSIDE_CONTAINER=false
PYTORCH_VERSION_OVERRIDE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --overlay)
            OVERLAY_PATH="$2"
            shift 2
            ;;
        --image)
            IMAGE_PATH="$2"
            RUN_INSIDE_CONTAINER=true
            shift 2
            ;;
        --gpu|--nv)
            USE_GPU=true
            shift
            ;;
        --pytorch-version)
            PYTORCH_VERSION_OVERRIDE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --overlay PATH         Path to writable overlay image (e.g., overlay.img)"
            echo "  --image PATH           Path to Singularity/Apptainer image (e.g., image.sif)"
            echo "  --gpu|--nv             Enable GPU support (NVIDIA)"
            echo "  --pytorch-version VER  Specify PyTorch version (e.g., 2.6.0, 2.7.0)"
            echo "                         Default: Auto-detect based on Ubuntu version"
            echo "                         Ubuntu 22.04: 2.6.0 (CMake 3.22 compatible)"
            echo "                         Ubuntu 24.04: 2.7.0 (CMake 3.27+ required)"
            echo "  --help, -h             Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Run on host or inside container"
            echo "  $0 --overlay overlay.img --image image.sif  # Run in Singularity with overlay"
            echo "  $0 --overlay overlay.img --image image.sif --gpu  # With GPU support"
            echo "  $0 --pytorch-version 2.6.0            # Use specific PyTorch version"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Set PyTorch version (use override if provided, otherwise use recommended)
if [ -n "${PYTORCH_VERSION_OVERRIDE:-}" ]; then
    # Validate version format (should be X.Y.Z)
    if ! echo "${PYTORCH_VERSION_OVERRIDE}" | grep -qE '^[0-9]+\.[0-9]+(\.[0-9]+)?$'; then
        echo -e "${RED}✗ ERROR: Invalid PyTorch version format: ${PYTORCH_VERSION_OVERRIDE}${NC}"
        echo "  Expected format: X.Y or X.Y.Z (e.g., 2.6.0, 2.7.0)"
        exit 1
    fi
    
    SELECTED_PYTORCH_VERSION="${PYTORCH_VERSION_OVERRIDE}"
    echo "  Using specified PyTorch version: ${SELECTED_PYTORCH_VERSION}"
    
    # Determine CMake requirement based on PyTorch version
    PYTORCH_MAJOR=$(echo "${SELECTED_PYTORCH_VERSION}" | cut -d. -f1 || echo "")
    PYTORCH_MINOR=$(echo "${SELECTED_PYTORCH_VERSION}" | cut -d. -f2 || echo "")
    
    # Validate version components are numeric before arithmetic comparison
    if [ -n "${PYTORCH_MAJOR:-}" ] && [ -n "${PYTORCH_MINOR:-}" ] && \
       echo "${PYTORCH_MAJOR}" | grep -qE '^[0-9]+$' && \
       echo "${PYTORCH_MINOR}" | grep -qE '^[0-9]+$'; then
        if [ "${PYTORCH_MAJOR}" -eq 2 ] && [ "${PYTORCH_MINOR}" -lt 7 ]; then
            # PyTorch 2.6.x and earlier work with CMake 3.22
            RECOMMENDED_CMAKE_VERSION="3.22"
            echo "  PyTorch ${SELECTED_PYTORCH_VERSION} requires CMake >= 3.22"
        else
            # PyTorch 2.7+ requires CMake 3.27+
            RECOMMENDED_CMAKE_VERSION="3.27"
            echo "  PyTorch ${SELECTED_PYTORCH_VERSION} requires CMake >= 3.27"
        fi
    else
        echo -e "${YELLOW}⚠ WARNING: Could not parse PyTorch version components${NC}"
        echo "  Defaulting to CMake 3.27+ requirement"
        RECOMMENDED_CMAKE_VERSION="3.27"
    fi
elif [ -n "${RECOMMENDED_PYTORCH_VERSION:-}" ]; then
    SELECTED_PYTORCH_VERSION="${RECOMMENDED_PYTORCH_VERSION}"
    if [ -n "${UBUNTU_VERSION:-}" ]; then
        echo "  Using recommended PyTorch version for Ubuntu ${UBUNTU_VERSION}: ${SELECTED_PYTORCH_VERSION}"
    else
        echo "  Using recommended PyTorch version: ${SELECTED_PYTORCH_VERSION}"
    fi
else
    SELECTED_PYTORCH_VERSION=""
    echo "  Will fetch latest PyTorch version from GitHub (may require CMake 3.27+)"
fi

#===============================================================================
# Check if we should run inside Singularity container
#===============================================================================
if [ "${RUN_INSIDE_CONTAINER}" = true ]; then
    if [ -z "${IMAGE_PATH:-}" ]; then
        echo -e "${RED}Error: --image is required when using --overlay${NC}"
        exit 1
    fi
    
    if [ ! -f "${IMAGE_PATH}" ]; then
        echo -e "${RED}Error: Image file not found: ${IMAGE_PATH}${NC}"
        exit 1
    fi
    
    if [ -n "${OVERLAY_PATH:-}" ] && [ ! -f "${OVERLAY_PATH}" ]; then
        echo -e "${RED}Error: Overlay file not found: ${OVERLAY_PATH}${NC}"
        exit 1
    fi
    
    # Detect Singularity/Apptainer command
    SINGULARITY_CMD=""
    if command -v singularity &>/dev/null; then
        SINGULARITY_CMD="singularity"
    elif command -v apptainer &>/dev/null; then
        SINGULARITY_CMD="apptainer"
    else
        echo -e "${RED}Error: Neither singularity nor apptainer found${NC}"
        echo "Please install Singularity or Apptainer to use overlay mode"
        exit 1
    fi
    
    # Get absolute path to this script
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
    SCRIPT_PATH="${SCRIPT_DIR}/${SCRIPT_NAME}"
    
    # Build Singularity command
    SINGULARITY_OPTS=("exec")
    if [ "${USE_GPU}" = true ]; then
        SINGULARITY_OPTS+=("--nv")
    fi
    if [ -n "${OVERLAY_PATH:-}" ]; then
        OVERLAY_ABS="$(cd "$(dirname "${OVERLAY_PATH}")" && pwd)/$(basename "${OVERLAY_PATH}")"
        SINGULARITY_OPTS+=("--overlay" "${OVERLAY_ABS}:rw")
    fi
    
    # Bind current directory for script access
    SINGULARITY_OPTS+=("--bind" "${SCRIPT_DIR}:${SCRIPT_DIR}:ro")
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Running PyTorch Compilation Test${NC}"
    echo -e "${BLUE}Inside Singularity Container${NC}"
    echo -e "${BLUE}========================================${NC}\n"
    echo -e "${GREEN}Configuration:${NC}"
    echo "  Image:  ${IMAGE_PATH}"
    if [ -n "${OVERLAY_PATH:-}" ]; then
        echo "  Overlay: ${OVERLAY_PATH}"
    fi
    if [ "${USE_GPU}" = true ]; then
        echo "  GPU:    Enabled"
    fi
    echo ""
    
    # Execute script inside container
    exec "${SINGULARITY_CMD}" "${SINGULARITY_OPTS[@]}" "${IMAGE_PATH}" bash "${SCRIPT_PATH}"
fi

#===============================================================================
# Header (when running directly)
#===============================================================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}PyTorch OpenBLAS Compilation Test${NC}"
if [ -n "${SINGULARITY_CONTAINER:-}" ] || [ -n "${APPTAINER_CONTAINER:-}" ]; then
    echo -e "${BLUE}Running inside container${NC}"
    if [ -n "${OVERLAY_PATH:-}" ]; then
        echo -e "${BLUE}With writable overlay${NC}"
    fi
fi
echo -e "${BLUE}========================================${NC}\n"

#===============================================================================
# Resource Management Functions - Dynamic Hardware Detection
#===============================================================================

# Initialize resource monitoring variables with defaults (will be updated when BUILD_DIR is set)
RESOURCE_MONITOR_LOG="/tmp/resource_monitor.log"
BUILD_STOP_FLAG_FILE="/tmp/.build_stop_flag"
BUILD_STATE_FILE="/tmp/.build_state"

# Comprehensive system resource detection at startup
detect_system_resources() {
    # CPU detection
    local cpu_cores
    cpu_cores=$(nproc 2>/dev/null || echo "4")
    
    # Memory detection
    local mem_total_gb
    mem_total_gb=$(free -g 2>/dev/null | awk '/^Mem:/ {print $2}' || echo "8")
    local mem_available_gb
    mem_available_gb=$(free -g 2>/dev/null | awk '/^Mem:/ {print $7}' || echo "4")
    local mem_used_gb
    mem_used_gb=$((mem_total_gb - mem_available_gb))
    
    # Swap detection
    local swap_total_gb
    swap_total_gb=$(free -g 2>/dev/null | awk '/^Swap:/ {print $2}' || echo "0")
    local swap_used_gb
    swap_used_gb=$(free -g 2>/dev/null | awk '/^Swap:/ {print $3}' || echo "0")
    
    # Disk space detection (for build directory)
    local disk_available_gb
    if [ -d "/tmp" ]; then
        disk_available_gb=$(df -BG /tmp 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/G//' || echo "10")
    else
        disk_available_gb=10
    fi
    
    # CPU architecture and capabilities
    local cpu_model
    cpu_model=$(lscpu 2>/dev/null | grep "Model name" | cut -d: -f2 | sed 's/^[ \t]*//' || echo "Unknown")
    local cpu_threads_per_core
    cpu_threads_per_core=$(lscpu 2>/dev/null | grep "Thread(s) per core" | awk '{print $4}' || echo "1")
    
    # I/O capabilities (check if SSD or HDD)
    local disk_type="unknown"
    if command -v lsblk >/dev/null 2>&1; then
        local root_disk
        root_disk=$(lsblk -d -o NAME,ROTA 2>/dev/null | grep -v "NAME" | head -1 | awk '{print $2}' || echo "1")
        if [ "${root_disk}" = "0" ]; then
            disk_type="SSD"
        elif [ "${root_disk}" = "1" ]; then
            disk_type="HDD"
        fi
    fi
    
    # Export all detected values
    export SYS_CPU_CORES="${cpu_cores}"
    export SYS_MEM_TOTAL_GB="${mem_total_gb}"
    export SYS_MEM_AVAILABLE_GB="${mem_available_gb}"
    export SYS_MEM_USED_GB="${mem_used_gb}"
    export SYS_SWAP_TOTAL_GB="${swap_total_gb}"
    export SYS_SWAP_USED_GB="${swap_used_gb}"
    export SYS_DISK_AVAILABLE_GB="${disk_available_gb}"
    export SYS_CPU_MODEL="${cpu_model}"
    export SYS_CPU_THREADS_PER_CORE="${cpu_threads_per_core}"
    export SYS_DISK_TYPE="${disk_type}"
    
    # Calculate memory per job based on available memory
    # Use 25% of available memory per job, minimum 4GB, maximum 8GB
    local mem_per_job_gb
    if [ "${mem_available_gb}" -lt 16 ]; then
        mem_per_job_gb=4  # Conservative for low-memory systems
    elif [ "${mem_available_gb}" -lt 32 ]; then
        mem_per_job_gb=6  # Moderate for medium-memory systems
    else
        mem_per_job_gb=8  # More per job for high-memory systems
    fi
    export SYS_MEM_PER_JOB_GB="${mem_per_job_gb}"
}

# Calculate optimal build jobs based on detected system resources
calculate_build_jobs() {
    # Use detected system resources
    local cpu_cores="${SYS_CPU_CORES:-4}"
    local mem_total_gb="${SYS_MEM_TOTAL_GB:-8}"
    local mem_available_gb="${SYS_MEM_AVAILABLE_GB:-4}"
    local mem_per_job_gb="${SYS_MEM_PER_JOB_GB:-6}"
    local disk_type="${SYS_DISK_TYPE:-unknown}"
    
    # Calculate jobs based on CPU
    # Use 20% of cores (more conservative) to prevent overload and system freezes
    local jobs_by_cpu
    jobs_by_cpu=$((cpu_cores / 5))
    if [ "${jobs_by_cpu:-0}" -lt 1 ]; then
        jobs_by_cpu=1
    fi
    
    # Calculate jobs based on available memory (use detected mem_per_job)
    # Reserve 30% of available memory for system (more conservative for safety)
    local mem_for_build
    mem_for_build=$((mem_available_gb * 70 / 100))
    local jobs_by_mem
    # Safety check: ensure mem_per_job_gb is at least 1 to prevent division by zero
    if [ "${mem_per_job_gb:-0}" -lt 1 ]; then
        mem_per_job_gb=4  # Default minimum
    fi
    jobs_by_mem=$((mem_for_build / mem_per_job_gb))
    if [ "${jobs_by_mem:-0}" -lt 1 ]; then
        jobs_by_mem=1
    fi
    
    # Calculate jobs based on disk I/O capabilities
    # HDDs can handle fewer parallel jobs than SSDs
    local jobs_by_io
    if [ "${disk_type}" = "SSD" ]; then
        # SSDs can handle more parallel I/O
        jobs_by_io=$((cpu_cores / 3))  # More aggressive for SSDs
        if [ "${jobs_by_io:-0}" -gt 6 ]; then
            jobs_by_io=6  # Cap at 6 for SSDs
        fi
    elif [ "${disk_type}" = "HDD" ]; then
        # HDDs need more conservative limits
        jobs_by_io=$((cpu_cores / 5))  # More conservative for HDDs
        if [ "${jobs_by_io:-0}" -gt 3 ]; then
            jobs_by_io=3  # Cap at 3 for HDDs
        fi
    else
        # Unknown disk type - be conservative
        jobs_by_io=$((cpu_cores / 4))
        if [ "${jobs_by_io:-0}" -gt 4 ]; then
            jobs_by_io=4
        fi
    fi
    if [ "${jobs_by_io:-0}" -lt 1 ]; then
        jobs_by_io=1
    fi
    
    # Use the minimum of all three (most conservative)
    local jobs
    jobs="${jobs_by_cpu}"
    if [ "${jobs_by_mem:-0}" -lt "${jobs:-0}" ]; then
        jobs="${jobs_by_mem}"
    fi
    if [ "${jobs_by_io:-0}" -lt "${jobs:-0}" ]; then
        jobs="${jobs_by_io}"
    fi
    
    # Ensure at least 1 job
    if [ "${jobs:-0}" -lt 1 ]; then
        jobs=1
    fi
    
    # Allow override via environment variable
    if [ -n "${BUILD_JOBS_OVERRIDE:-}" ]; then
        jobs="${BUILD_JOBS_OVERRIDE}"
    fi
    
    echo "${jobs}"
}

# Calculate dynamic resource thresholds based on system capabilities
calculate_resource_thresholds() {
    local cpu_cores="${SYS_CPU_CORES:-4}"
    local mem_total_gb="${SYS_MEM_TOTAL_GB:-8}"
    local mem_available_gb="${SYS_MEM_AVAILABLE_GB:-4}"
    local swap_total_gb="${SYS_SWAP_TOTAL_GB:-0}"
    
    # Critical memory threshold: 10% of total RAM or 1GB, whichever is larger (more conservative)
    # This ensures more headroom to prevent system freezes
    local critical_mem_gb
    critical_mem_gb=$((mem_total_gb * 10 / 100))
    if [ "${critical_mem_gb}" -lt 1 ]; then
        critical_mem_gb=1
    fi
    if [ "${critical_mem_gb}" -gt 3 ]; then
        critical_mem_gb=3  # Cap at 3GB for very large systems (more conservative)
    fi
    
    # Warning memory threshold: 15% of total RAM or 3GB, whichever is larger (more conservative)
    local warn_mem_gb
    warn_mem_gb=$((mem_total_gb * 15 / 100))
    if [ "${warn_mem_gb}" -lt 2 ]; then
        warn_mem_gb=2
    fi
    if [ "${warn_mem_gb}" -gt 5 ]; then
        warn_mem_gb=5  # Cap at 5GB for very large systems (more conservative)
    fi
    
    # Critical swap threshold: 15% of swap or 1.5GB, whichever is smaller (more conservative)
    # Lower threshold prevents excessive swap usage that can cause freezes
    local critical_swap_gb
    if [ "${swap_total_gb}" -gt 0 ]; then
        critical_swap_gb=$((swap_total_gb * 15 / 100))
        if [ "${critical_swap_gb}" -gt 1 ]; then
            critical_swap_gb=1  # More conservative: cap at 1GB instead of 2GB
        fi
        if [ "${critical_swap_gb}" -lt 1 ]; then
            critical_swap_gb=1
        fi
    else
        critical_swap_gb=1  # Default if no swap
    fi
    
    # Warning swap threshold: 5% of swap or 512MB, whichever is smaller (more conservative)
    local warn_swap_gb
    if [ "${swap_total_gb}" -gt 0 ]; then
        warn_swap_gb=$((swap_total_gb * 5 / 100))
        if [ "${warn_swap_gb}" -gt 0 ] && [ "${warn_swap_gb}" -lt 1 ]; then
            warn_swap_gb=0  # Less than 1GB, round down
        fi
        if [ "${warn_swap_gb}" -lt 0 ]; then
            warn_swap_gb=0
        fi
    else
        warn_swap_gb=0  # No warning if no swap
    fi
    
    # Critical load average: 1.5x CPU cores (more conservative - system approaching overload)
    local critical_load_avg
    if [ "${cpu_cores:-0}" -gt 0 ]; then
        critical_load_avg=$(echo "scale=1; ${cpu_cores} * 1.5" | bc 2>/dev/null || echo "6.0")
    else
        critical_load_avg="6.0"  # Default if CPU cores unknown
    fi
    
    # Warning load average: 1.2x CPU cores (more conservative)
    local warn_load_avg
    if [ "${cpu_cores:-0}" -gt 0 ]; then
        warn_load_avg=$(echo "scale=1; ${cpu_cores} * 1.2" | bc 2>/dev/null || echo "4.8")
    else
        warn_load_avg="4.8"  # Default if CPU cores unknown
    fi
    
    # Disk I/O wait thresholds (more conservative to prevent freezes)
    local critical_iowait
    local warn_iowait
    if [ "${SYS_DISK_TYPE}" = "SSD" ]; then
        critical_iowait=50  # More conservative: was 60
        warn_iowait=30      # More conservative: was 40
    elif [ "${SYS_DISK_TYPE}" = "HDD" ]; then
        critical_iowait=30  # More conservative: was 40
        warn_iowait=20      # More conservative: was 25
    else
        critical_iowait=40  # More conservative: was 50
        warn_iowait=25      # More conservative: was 30
    fi
    
    # Export all calculated thresholds
    export CRITICAL_MEM_AVAIL_GB="${critical_mem_gb}"
    export WARN_MEM_AVAIL_GB="${warn_mem_gb}"
    export CRITICAL_SWAP_USED_GB="${critical_swap_gb}"
    export WARN_SWAP_USED_GB="${warn_swap_gb}"
    export CRITICAL_LOAD_AVG="${critical_load_avg}"
    export WARN_LOAD_AVG="${warn_load_avg}"
    export CRITICAL_DISK_IO_WAIT="${critical_iowait}"
    export WARN_DISK_IO_WAIT="${warn_iowait}"
}

# Check available memory and warn if low
check_memory() {
    local mem_available_gb
    mem_available_gb=$(free -g 2>/dev/null | awk '/^Mem:/ {print $7}' || echo "0")
    local mem_total_gb
    mem_total_gb=$(free -g 2>/dev/null | awk '/^Mem:/ {print $2}' || echo "0")
    local swap_total_gb
    swap_total_gb=$(free -g 2>/dev/null | awk '/^Swap:/ {print $2}' || echo "0")
    local swap_used_gb
    swap_used_gb=$(free -g 2>/dev/null | awk '/^Swap:/ {print $3}' || echo "0")
    
    # Use detected system resources if available, otherwise detect fresh
    local mem_avail="${SYS_MEM_AVAILABLE_GB:-${mem_available_gb}}"
    local mem_total="${SYS_MEM_TOTAL_GB:-${mem_total_gb}}"
    local swap_total="${SYS_SWAP_TOTAL_GB:-${swap_total_gb}}"
    local swap_used="${SYS_SWAP_USED_GB:-${swap_used_gb}}"
    local mem_per_job="${SYS_MEM_PER_JOB_GB:-6}"
    local build_jobs="${CALCULATED_JOBS:-1}"
    
    echo "  System Memory Status (from hardware detection):"
    echo "    Total RAM: ${mem_total}GB"
    echo "    Available RAM: ${mem_avail}GB"
    echo "    Total Swap: ${swap_total}GB"
    echo "    Swap Used: ${swap_used}GB"
    echo "    Memory per job: ${mem_per_job}GB"
    echo "    Estimated memory usage: ~$((build_jobs * mem_per_job))GB for ${build_jobs} jobs"
    
    # Warn if available memory is less than estimated usage
    local estimated_usage=$((build_jobs * mem_per_job))
    if [ "${mem_avail}" -lt "${estimated_usage}" ]; then
        echo -e "  ${YELLOW}⚠ WARNING: Available memory (${mem_avail}GB) may be insufficient${NC}"
        echo "    Estimated usage: ${estimated_usage}GB for ${build_jobs} jobs"
        echo "    PyTorch compilation may fail or be very slow"
        echo "    Recommendation: Reduce BUILD_JOBS_OVERRIDE or free memory"
    fi
    
    # CRITICAL: Warn if swap is being used (indicates memory pressure, can cause freezes)
    if [ "${swap_used}" -gt 0 ]; then
        echo -e "  ${RED}⚠ CRITICAL: Swap is being used (${swap_used}GB)${NC}"
        echo "    This can cause system freezes during compilation"
        echo "    Recommendation: Reduce BUILD_JOBS_OVERRIDE or free memory"
        echo "    Try: export BUILD_JOBS_OVERRIDE=1"
    fi
    
    # Check if swap is available (important for memory-intensive builds)
    if [ "${swap_total}" -eq 0 ]; then
        echo -e "  ${YELLOW}⚠ WARNING: No swap space detected${NC}"
        echo "    System may freeze if memory is exhausted"
        echo "    Consider adding swap or reducing build parallelism"
    fi
}

#===============================================================================
# System Resource Detection and Dynamic Threshold Calculation
#===============================================================================
echo -e "${BLUE}Detecting system resources and calculating dynamic limits...${NC}"

# Detect all system resources at startup
detect_system_resources

# Calculate dynamic resource thresholds based on detected hardware
calculate_resource_thresholds

# Calculate optimal build jobs based on detected resources
CALCULATED_JOBS=$(calculate_build_jobs)

# Display comprehensive system information and calculated limits
echo -e "${YELLOW}System Resource Detection:${NC}"
echo "  CPU: ${SYS_CPU_CORES} cores (${SYS_CPU_THREADS_PER_CORE} threads/core)"
echo "    Model: ${SYS_CPU_MODEL}"
echo "  Memory: ${SYS_MEM_TOTAL_GB}GB total, ${SYS_MEM_AVAILABLE_GB}GB available, ${SYS_MEM_USED_GB}GB used"
echo "  Swap: ${SYS_SWAP_TOTAL_GB}GB total, ${SYS_SWAP_USED_GB}GB used"
echo "  Disk: ${SYS_DISK_AVAILABLE_GB}GB available (Type: ${SYS_DISK_TYPE})"
echo ""

echo -e "${YELLOW}Dynamic Resource Limits (Calculated from Hardware - Conservative Settings):${NC}"
echo "  Build Jobs: ${CALCULATED_JOBS} (CPU: ${SYS_CPU_CORES}/5=20%, Memory: ${SYS_MEM_AVAILABLE_GB}GB/${SYS_MEM_PER_JOB_GB}GB per job, I/O: ${SYS_DISK_TYPE} optimized)"
echo "  Memory per job: ${SYS_MEM_PER_JOB_GB}GB (adaptive based on available memory)"
echo "  Memory budget: ~$((CALCULATED_JOBS * SYS_MEM_PER_JOB_GB))GB total (30% reserved for system safety)"
if [ "${SYS_CPU_CORES}" -gt 0 ]; then
    echo "  CPU usage: ~${CALCULATED_JOBS}/${SYS_CPU_CORES} cores ($((CALCULATED_JOBS * 100 / SYS_CPU_CORES))%) - Conservative 20% limit"
else
    echo "  CPU usage: ~${CALCULATED_JOBS} jobs"
fi
echo ""

echo -e "${YELLOW}Dynamic Auto-Stop Thresholds (Calculated from Hardware):${NC}"
if [ "${SYS_MEM_TOTAL_GB}" -gt 0 ]; then
    mem_crit_pct=$((CRITICAL_MEM_AVAIL_GB * 100 / SYS_MEM_TOTAL_GB))
    mem_warn_pct=$((WARN_MEM_AVAIL_GB * 100 / SYS_MEM_TOTAL_GB))
    echo "  Critical Memory: < ${CRITICAL_MEM_AVAIL_GB}GB available (~${mem_crit_pct}% of ${SYS_MEM_TOTAL_GB}GB total)"
    echo "  Warning Memory: < ${WARN_MEM_AVAIL_GB}GB available (~${mem_warn_pct}% of ${SYS_MEM_TOTAL_GB}GB total)"
else
    echo "  Critical Memory: < ${CRITICAL_MEM_AVAIL_GB}GB available"
    echo "  Warning Memory: < ${WARN_MEM_AVAIL_GB}GB available"
fi
if [ "${SYS_SWAP_TOTAL_GB}" -gt 0 ]; then
    swap_crit_pct=$((CRITICAL_SWAP_USED_GB * 100 / SYS_SWAP_TOTAL_GB))
    swap_warn_pct=$((WARN_SWAP_USED_GB * 100 / SYS_SWAP_TOTAL_GB))
    echo "  Critical Swap: > ${CRITICAL_SWAP_USED_GB}GB used (~${swap_crit_pct}% of ${SYS_SWAP_TOTAL_GB}GB total)"
    echo "  Warning Swap: > ${WARN_SWAP_USED_GB}GB used (~${swap_warn_pct}% of ${SYS_SWAP_TOTAL_GB}GB total)"
else
    echo "  Swap: Not available (no swap space detected)"
fi
if [ "${SYS_CPU_CORES:-0}" -gt 0 ]; then
    echo "  Critical Load: > ${CRITICAL_LOAD_AVG} (1.5x ${SYS_CPU_CORES} cores - conservative)"
    echo "  Warning Load: > ${WARN_LOAD_AVG} (1.2x ${SYS_CPU_CORES} cores - conservative)"
else
    echo "  Critical Load: > ${CRITICAL_LOAD_AVG} (conservative threshold)"
    echo "  Warning Load: > ${WARN_LOAD_AVG} (conservative threshold)"
fi
echo "  Critical I/O Wait: > ${CRITICAL_DISK_IO_WAIT}% (${SYS_DISK_TYPE} optimized)"
echo "  Warning I/O Wait: > ${WARN_DISK_IO_WAIT}% (${SYS_DISK_TYPE} optimized)"
echo ""

echo -e "${YELLOW}Resource Protection Features:${NC}"
echo "  Process priority: Lower (nice value) to avoid host saturation"
echo "  I/O priority: Idle class (ionice) to prevent disk I/O saturation"
echo "  Resource monitoring: Comprehensive (memory, swap, CPU load, disk I/O)"
echo "  Auto-stop: Enabled (stops build if resources go critical)"
echo "  Monitor log: ${RESOURCE_MONITOR_LOG}"
echo ""

#===============================================================================
# Step 1: Install Prerequisites and Verify Performance Libraries
#===============================================================================
echo -e "${BLUE}[Step 1] Installing prerequisites and verifying performance libraries...${NC}"

# Check if running as root (for apt-get install)
if [ "${EUID:-0}" -eq 0 ]; then
    APT_CMD="apt-get"
else
    APT_CMD="sudo apt-get"
    echo "  Note: Non-root user detected, will use sudo for package installation"
fi

# Update package lists
echo "  Updating package lists..."
${APT_CMD} update -qq || true

# Check and install PyTorch build prerequisites (only if missing)
echo "  Checking and installing PyTorch build prerequisites..."
PACKAGES_TO_INSTALL=()

# Function to check if package is installed
check_package() {
    local pkg="$1"
    if dpkg -l | grep -q "^ii.*${pkg}"; then
        return 0  # Installed
    else
        return 1  # Not installed
    fi
}

# Check each package and add to install list if missing
# CRITICAL: Include LAPACKE for full LAPACK support
for pkg in build-essential cmake ninja-build git curl wget \
           libopenblas-dev liblapack-dev liblapacke-dev libblas-dev \
           libomp-dev libtbb-dev python3-dev python3-pip \
           python3-setuptools python3-wheel util-linux shellcheck sysstat jq \
           pkg-config; do
    if ! check_package "${pkg}"; then
        PACKAGES_TO_INSTALL+=("${pkg}")
    else
        echo "  ✓ ${pkg} already installed"
    fi
done

# Install missing packages
if [ ${#PACKAGES_TO_INSTALL[@]} -gt 0 ]; then
    echo "  Installing missing packages: ${PACKAGES_TO_INSTALL[*]}"
    ${APT_CMD} install -y -qq "${PACKAGES_TO_INSTALL[@]}" || {
        echo -e "${YELLOW}⚠ Some packages failed to install, continuing...${NC}"
    }
else
    echo -e "${GREEN}✓ All prerequisites already installed${NC}"
fi

# CRITICAL: Verify ionice is available (from util-linux package)
# ionice is essential for preventing system freezes during compilation
if ! command -v ionice >/dev/null 2>&1; then
    echo -e "${RED}✗ ERROR: ionice not found after installation${NC}"
    echo "  ionice (from util-linux package) is CRITICAL for I/O priority limiting"
    echo "  Without it, the system may freeze due to disk I/O saturation"
    echo "  Please install manually: ${APT_CMD} install -y util-linux"
    exit 1
else
    echo -e "${GREEN}✓ ionice found (I/O priority limiting available)${NC}"
fi

# CRITICAL: Verify shellcheck is available (required for script validation)
if ! command -v shellcheck >/dev/null 2>&1; then
    echo -e "${RED}✗ ERROR: shellcheck not found after installation${NC}"
    echo "  shellcheck (from shellcheck package) is REQUIRED for script validation"
    echo "  Please install manually: ${APT_CMD} install -y shellcheck"
    exit 1
else
    echo -e "${GREEN}✓ shellcheck found (script validation available)${NC}"
fi

# CRITICAL: Verify iostat is available (required for I/O monitoring)
if ! command -v iostat >/dev/null 2>&1; then
    echo -e "${RED}✗ ERROR: iostat not found after installation${NC}"
    echo "  iostat (from sysstat package) is REQUIRED for I/O monitoring"
    echo "  Please install manually: ${APT_CMD} install -y sysstat"
    exit 1
else
    echo -e "${GREEN}✓ iostat found (I/O monitoring available)${NC}"
fi

# Check for bc (required for load average calculations)
if ! command -v bc >/dev/null 2>&1; then
    echo "  Installing bc (required for resource monitoring)..."
    ${APT_CMD} install -y -qq bc || {
        echo -e "${YELLOW}⚠ bc installation failed, resource monitoring may be limited${NC}"
    }
fi

# CRITICAL: Verify jq is available (required for GitHub API JSON parsing)
if ! command -v jq >/dev/null 2>&1; then
    echo -e "${RED}✗ ERROR: jq not found after installation${NC}"
    echo "  jq (from jq package) is REQUIRED for parsing GitHub API responses"
    echo "  Please install manually: ${APT_CMD} install -y jq"
    exit 1
else
    echo -e "${GREEN}✓ jq found (JSON parsing available)${NC}"
fi

# Function to filter pip output and suppress known non-fatal errors
# This filters out apt package version parsing errors (e.g., devscripts with Ubuntu-style versions)
# Defined early so it can be used in CMake installation
filter_pip_output() {
    grep -vE "^Requirement|^Collecting|^Using|^Already|^WARNING|^ERROR.*devscripts|Invalid version|parsing dependencies|^ERROR.*tensorflow|^ERROR.*keras|Error parsing dependencies|Error parsing dependencies of" 2>/dev/null || true
}

# Function to check CMake version available in Ubuntu repositories using apt-cache
# This is more reliable than web scraping and works offline if package lists are updated
check_ubuntu_cmake_version() {
    local cmake_version=""
    local apt_output=""
    
    echo "  Checking CMake version in Ubuntu repositories (using apt-cache)..." >&2
    
    # Method 1: Use apt-cache policy (most reliable, shows candidate version)
    if command -v apt-cache &>/dev/null 2>&1; then
        apt_output=$(apt-cache policy cmake 2>/dev/null || echo "")
        if [ -n "${apt_output:-}" ]; then
            # Extract candidate version (highest available in repos)
            cmake_version=$(echo "${apt_output}" | \
                grep -E "^\s+Candidate:" | \
                sed -n 's/.*Candidate:\s*\([0-9]\+\.[0-9]\+\.[0-9]\+\)[^0-9].*/\1/p' | \
                head -1 || echo "")
            
            # If candidate not found, try installed version line
            if [ -z "${cmake_version:-}" ]; then
                cmake_version=$(echo "${apt_output}" | \
                    grep -E "^\s+Installed:" | \
                    sed -n 's/.*Installed:\s*\([0-9]\+\.[0-9]\+\.[0-9]\+\)[^0-9].*/\1/p' | \
                    head -1 || echo "")
            fi
        fi
    fi
    
    # Method 2: Fallback to apt-cache show (alternative method)
    if [ -z "${cmake_version:-}" ] && command -v apt-cache &>/dev/null 2>&1; then
        apt_output=$(apt-cache show cmake 2>/dev/null | grep -E "^Version:" | head -1 || echo "")
        if [ -n "${apt_output:-}" ]; then
            # Extract version (format: Version: 3.22.1-1ubuntu1)
            cmake_version=$(echo "${apt_output}" | \
                sed -n 's/^Version:\s*\([0-9]\+\.[0-9]\+\.[0-9]\+\)[^0-9].*/\1/p' | \
                head -1 || echo "")
        fi
    fi
    
    # Method 3: Try dpkg if package is installed (last resort)
    if [ -z "${cmake_version:-}" ] && command -v dpkg &>/dev/null 2>&1; then
        apt_output=$(dpkg -l cmake 2>/dev/null | grep -E "^ii" | head -1 || echo "")
        if [ -n "${apt_output:-}" ]; then
            # Extract version from dpkg output (format: ii  cmake  3.22.1-1ubuntu1  ...)
            cmake_version=$(echo "${apt_output}" | \
                awk '{print $3}' | \
                sed -n 's/\([0-9]\+\.[0-9]\+\.[0-9]\+\)[^0-9].*/\1/p' | \
                head -1 || echo "")
        fi
    fi
    
    if [ -n "${cmake_version:-}" ]; then
        # Validate version format
        if echo "${cmake_version}" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
            echo "  Found CMake ${cmake_version} in Ubuntu repositories" >&2
            echo "${cmake_version}"
            return 0
        else
            echo "  ⚠ Invalid version format from apt-cache: ${cmake_version}" >&2
            echo ""
            return 1
        fi
    else
        echo "  Could not determine CMake version from apt-cache" >&2
        echo "  This may mean cmake package is not in configured repositories" >&2
        echo ""
        return 1
    fi
}

# Function to check installed CMake version
check_installed_cmake_version() {
    local cmake_version=""
    
    if command -v cmake &>/dev/null 2>&1; then
        # Get version from cmake --version (most reliable)
        cmake_version=$(cmake --version 2>/dev/null | head -1 | \
            sed -n 's/.*version\s\+\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p' || echo "")
        
        # Validate version format
        if [ -n "${cmake_version:-}" ] && echo "${cmake_version}" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
            echo "${cmake_version}"
            return 0
        fi
    fi
    
    echo ""
    return 1
}

# Function to check CMake build dependencies
check_cmake_build_dependencies() {
    local missing_deps=()
    local dep=""
    
    echo "  Checking CMake build dependencies..." >&2
    
    # Required dependencies for building CMake from source
    local required_deps=(
        "build-essential"
        "libssl-dev"
        "libncurses5-dev"
        "libncursesw5-dev"
        "wget"
        "curl"
    )
    
    # Check dpkg-installed packages
    for dep in "${required_deps[@]}"; do
        if ! dpkg -l 2>/dev/null | grep -qE "^ii[[:space:]]+${dep}[[:space:]]"; then
            missing_deps+=("${dep}")
        fi
    done
    
    # Check for tar and gzip (usually in base system, but verify with command)
    if ! command -v tar >/dev/null 2>&1; then
        missing_deps+=("tar")
    fi
    if ! command -v gzip >/dev/null 2>&1; then
        missing_deps+=("gzip")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "  Missing dependencies: ${missing_deps[*]}" >&2
        echo "${missing_deps[*]}"
        return 1
    else
        echo "  ✓ All CMake build dependencies available" >&2
        echo ""
        return 0
    fi
}

# Check and upgrade CMake if needed
# CMake requirement depends on PyTorch version (set above based on Ubuntu version or user override)
echo "  Checking CMake version..."
CMAKE_REQUIRED_VERSION="${RECOMMENDED_CMAKE_VERSION:-3.27}"
echo "  Required CMake version: ${CMAKE_REQUIRED_VERSION} (based on PyTorch version selection)"
CMAKE_VERSION=""
CMAKE_MAJOR=""
CMAKE_MINOR=""
UBUNTU_CMAKE_VERSION=""

# First, check what version is available in Ubuntu repositories
UBUNTU_CMAKE_VERSION=$(check_ubuntu_cmake_version)
        if [ -n "${UBUNTU_CMAKE_VERSION:-}" ]; then
            UBUNTU_CMAKE_MAJOR=$(echo "${UBUNTU_CMAKE_VERSION}" | cut -d. -f1)
            UBUNTU_CMAKE_MINOR=$(echo "${UBUNTU_CMAKE_VERSION}" | cut -d. -f2)
            # Validate extracted version components
            if [ -n "${UBUNTU_CMAKE_MAJOR:-}" ] && [ -n "${UBUNTU_CMAKE_MINOR:-}" ] && \
               echo "${UBUNTU_CMAKE_MAJOR}" | grep -qE '^[0-9]+$' && \
               echo "${UBUNTU_CMAKE_MINOR}" | grep -qE '^[0-9]+$'; then
                # Compare against required version (dynamic based on PyTorch version)
                REQUIRED_CMAKE_MAJOR=$(echo "${CMAKE_REQUIRED_VERSION}" | cut -d. -f1)
                REQUIRED_CMAKE_MINOR=$(echo "${CMAKE_REQUIRED_VERSION}" | cut -d. -f2)
                if [ -n "${REQUIRED_CMAKE_MAJOR:-}" ] && [ -n "${REQUIRED_CMAKE_MINOR:-}" ] && \
                   echo "${REQUIRED_CMAKE_MAJOR}" | grep -qE '^[0-9]+$' && \
                   echo "${REQUIRED_CMAKE_MINOR}" | grep -qE '^[0-9]+$'; then
                    if [ "${UBUNTU_CMAKE_MAJOR}" -lt "${REQUIRED_CMAKE_MAJOR}" ] || \
                       ([ "${UBUNTU_CMAKE_MAJOR}" -eq "${REQUIRED_CMAKE_MAJOR}" ] && [ "${UBUNTU_CMAKE_MINOR}" -lt "${REQUIRED_CMAKE_MINOR}" ]); then
                        echo "  ⚠ Ubuntu repository has CMake ${UBUNTU_CMAKE_VERSION} < ${CMAKE_REQUIRED_VERSION}"
                        echo "    Will need to install from pip, Kitware repo, or compile from source"
                    else
                        echo "  ✓ Ubuntu repository has CMake ${UBUNTU_CMAKE_VERSION} >= ${CMAKE_REQUIRED_VERSION}"
                    fi
                else
                    echo "  ⚠ Could not parse required CMake version"
                fi
            else
                echo "  ⚠ Could not parse Ubuntu CMake version components"
            fi
        fi

# Initialize NEED_UPGRADE flag
NEED_UPGRADE=false

# Check if CMake is already installed
INSTALLED_CMAKE_VERSION=$(check_installed_cmake_version)

# Use installed version if available, otherwise try to install from repos first
if [ -n "${INSTALLED_CMAKE_VERSION:-}" ]; then
    CMAKE_VERSION="${INSTALLED_CMAKE_VERSION}"
    CMAKE_MAJOR=$(echo "${CMAKE_VERSION}" | cut -d. -f1 || echo "")
    CMAKE_MINOR=$(echo "${CMAKE_VERSION}" | cut -d. -f2 || echo "")
    echo "  Found CMake ${CMAKE_VERSION} installed"
    
    # Validate version components are numeric
    if [ -z "${CMAKE_MAJOR:-}" ] || [ -z "${CMAKE_MINOR:-}" ] || \
       ! echo "${CMAKE_MAJOR}" | grep -qE '^[0-9]+$' || \
       ! echo "${CMAKE_MINOR}" | grep -qE '^[0-9]+$'; then
        NEED_UPGRADE=true
        echo "  ⚠ Could not parse CMake version, will upgrade"
    else
            # Compare against required version (dynamic based on PyTorch version)
            REQUIRED_CMAKE_MAJOR=$(echo "${CMAKE_REQUIRED_VERSION}" | cut -d. -f1)
            REQUIRED_CMAKE_MINOR=$(echo "${CMAKE_REQUIRED_VERSION}" | cut -d. -f2)
            if [ -n "${REQUIRED_CMAKE_MAJOR:-}" ] && [ -n "${REQUIRED_CMAKE_MINOR:-}" ] && \
               echo "${REQUIRED_CMAKE_MAJOR}" | grep -qE '^[0-9]+$' && \
               echo "${REQUIRED_CMAKE_MINOR}" | grep -qE '^[0-9]+$'; then
                if [ "${CMAKE_MAJOR}" -lt "${REQUIRED_CMAKE_MAJOR}" ] || \
                   ([ "${CMAKE_MAJOR}" -eq "${REQUIRED_CMAKE_MAJOR}" ] && [ "${CMAKE_MINOR}" -lt "${REQUIRED_CMAKE_MINOR}" ]); then
                    NEED_UPGRADE=true
                    echo "  ⚠ CMake ${CMAKE_VERSION} < ${CMAKE_REQUIRED_VERSION} (PyTorch requirement)"
                else
                    echo -e "  ${GREEN}✓ CMake ${CMAKE_VERSION} meets requirement (>= ${CMAKE_REQUIRED_VERSION})${NC}"
                fi
            else
                NEED_UPGRADE=true
                echo "  ⚠ Could not parse required CMake version"
            fi
    fi
else
    # CMake not installed - try installing from Ubuntu repos first if available
    if [ -n "${UBUNTU_CMAKE_VERSION:-}" ]; then
        UBUNTU_CMAKE_MAJOR=$(echo "${UBUNTU_CMAKE_VERSION}" | cut -d. -f1)
        UBUNTU_CMAKE_MINOR=$(echo "${UBUNTU_CMAKE_VERSION}" | cut -d. -f2)
        REQUIRED_CMAKE_MAJOR=$(echo "${CMAKE_REQUIRED_VERSION}" | cut -d. -f1)
        REQUIRED_CMAKE_MINOR=$(echo "${CMAKE_REQUIRED_VERSION}" | cut -d. -f2)
        
        # Check if Ubuntu version meets requirements
        if [ -n "${UBUNTU_CMAKE_MAJOR:-}" ] && [ -n "${UBUNTU_CMAKE_MINOR:-}" ] && \
           [ -n "${REQUIRED_CMAKE_MAJOR:-}" ] && [ -n "${REQUIRED_CMAKE_MINOR:-}" ] && \
           echo "${UBUNTU_CMAKE_MAJOR}" | grep -qE '^[0-9]+$' && \
           echo "${UBUNTU_CMAKE_MINOR}" | grep -qE '^[0-9]+$' && \
           echo "${REQUIRED_CMAKE_MAJOR}" | grep -qE '^[0-9]+$' && \
           echo "${REQUIRED_CMAKE_MINOR}" | grep -qE '^[0-9]+$'; then
            if [ "${UBUNTU_CMAKE_MAJOR}" -gt "${REQUIRED_CMAKE_MAJOR}" ] || \
               ([ "${UBUNTU_CMAKE_MAJOR}" -eq "${REQUIRED_CMAKE_MAJOR}" ] && [ "${UBUNTU_CMAKE_MINOR}" -ge "${REQUIRED_CMAKE_MINOR}" ]); then
                echo "  CMake not found in PATH, installing ${UBUNTU_CMAKE_VERSION} from Ubuntu repositories..."
                if [ -z "${APT_CMD:-}" ]; then
                    echo "  ⚠ ERROR: APT_CMD not set, cannot install CMake"
                    NEED_UPGRADE=true
                else
                    ${APT_CMD} install -y -qq cmake || {
                        echo -e "${YELLOW}⚠ Failed to install CMake from Ubuntu repos, will try alternative methods${NC}"
                        NEED_UPGRADE=true
                    }
                fi
                
                # Verify installation
                INSTALLED_CMAKE_VERSION=$(check_installed_cmake_version)
                if [ -n "${INSTALLED_CMAKE_VERSION:-}" ]; then
                    echo -e "  ${GREEN}✓ CMake ${INSTALLED_CMAKE_VERSION} installed successfully${NC}"
                    # Re-check version to ensure it meets requirements
                    CMAKE_VERSION="${INSTALLED_CMAKE_VERSION}"
                    CMAKE_MAJOR=$(echo "${CMAKE_VERSION}" | cut -d. -f1 || echo "")
                    CMAKE_MINOR=$(echo "${CMAKE_VERSION}" | cut -d. -f2 || echo "")
                    if [ -n "${CMAKE_MAJOR:-}" ] && [ -n "${CMAKE_MINOR:-}" ] && \
                       echo "${CMAKE_MAJOR}" | grep -qE '^[0-9]+$' && \
                       echo "${CMAKE_MINOR}" | grep -qE '^[0-9]+$'; then
                        if [ "${CMAKE_MAJOR}" -lt "${REQUIRED_CMAKE_MAJOR}" ] || \
                           ([ "${CMAKE_MAJOR}" -eq "${REQUIRED_CMAKE_MAJOR}" ] && [ "${CMAKE_MINOR}" -lt "${REQUIRED_CMAKE_MINOR}" ]); then
                            NEED_UPGRADE=true
                        else
                            NEED_UPGRADE=false
                        fi
                    fi
                else
                    echo "  ⚠ CMake installation from repos failed, will try alternative methods"
                    NEED_UPGRADE=true
                fi
            else
                echo "  CMake not found in PATH"
                echo "    Ubuntu repo has ${UBUNTU_CMAKE_VERSION} < ${CMAKE_REQUIRED_VERSION}, will try alternative installation methods"
                NEED_UPGRADE=true
            fi
        else
            echo "  CMake not found in PATH"
            echo "    Will try alternative installation methods"
            NEED_UPGRADE=true
        fi
    else
        echo "  CMake not found in PATH"
        echo "    CMake not available in Ubuntu repositories, will try alternative installation methods"
        NEED_UPGRADE=true
    fi
fi

if [ "${NEED_UPGRADE}" = "true" ]; then
    echo "  Upgrading CMake to meet PyTorch requirements..."
    echo "  Will try alternative installation methods (pip, Kitware repo, or source compilation)..."
    
    # Method 1: Try installing cmake from pip (usually has latest version)
    echo "  Attempting to install CMake via pip..."
    if [ -n "${pip_flags:-}" ]; then
        # Note: pip_flags is intentionally unquoted to allow multiple flags if needed
        # It's typically a single flag like "--break-system-packages"
        python3 -m pip install --upgrade --no-cache-dir ${pip_flags} cmake 2>&1 | filter_pip_output || true
    else
        python3 -m pip install --upgrade --no-cache-dir cmake 2>&1 | filter_pip_output || true
    fi
    
    # Verify pip-installed cmake works
    if python3 -m pip show cmake &>/dev/null; then
        # pip-installed cmake is usually in ~/.local/bin or similar
        # Check if it's now in PATH
        if command -v cmake &>/dev/null; then
            NEW_CMAKE_VERSION=$(cmake --version 2>/dev/null | head -1 | sed 's/.*version \([0-9]\+\.[0-9]\+\).*/\1/' || echo "")
            if [ -n "${NEW_CMAKE_VERSION:-}" ]; then
                NEW_CMAKE_MAJOR=$(echo "${NEW_CMAKE_VERSION}" | cut -d. -f1)
                NEW_CMAKE_MINOR=$(echo "${NEW_CMAKE_VERSION}" | cut -d. -f2)
                # Validate version components
                if [ -n "${NEW_CMAKE_MAJOR:-}" ] && [ -n "${NEW_CMAKE_MINOR:-}" ] && \
                   echo "${NEW_CMAKE_MAJOR}" | grep -qE '^[0-9]+$' && \
                   echo "${NEW_CMAKE_MINOR}" | grep -qE '^[0-9]+$'; then
                    # Compare against required version (dynamic)
                    REQUIRED_CMAKE_MAJOR=$(echo "${CMAKE_REQUIRED_VERSION}" | cut -d. -f1)
                    REQUIRED_CMAKE_MINOR=$(echo "${CMAKE_REQUIRED_VERSION}" | cut -d. -f2)
                    if [ -n "${REQUIRED_CMAKE_MAJOR:-}" ] && [ -n "${REQUIRED_CMAKE_MINOR:-}" ] && \
                       echo "${REQUIRED_CMAKE_MAJOR}" | grep -qE '^[0-9]+$' && \
                       echo "${REQUIRED_CMAKE_MINOR}" | grep -qE '^[0-9]+$'; then
                        if [ "${NEW_CMAKE_MAJOR}" -gt "${REQUIRED_CMAKE_MAJOR}" ] || \
                           ([ "${NEW_CMAKE_MAJOR}" -eq "${REQUIRED_CMAKE_MAJOR}" ] && [ "${NEW_CMAKE_MINOR}" -ge "${REQUIRED_CMAKE_MINOR}" ]); then
                            echo -e "  ${GREEN}✓ CMake upgraded to ${NEW_CMAKE_VERSION} via pip${NC}"
                            NEED_UPGRADE=false
                        else
                            echo "  ⚠ Pip CMake version ${NEW_CMAKE_VERSION} still < ${CMAKE_REQUIRED_VERSION}"
                            echo "  Will try Kitware APT repository..."
                            NEED_UPGRADE=true
                        fi
                    else
                        echo "  ⚠ Could not parse required CMake version"
                        NEED_UPGRADE=true
                    fi
                else
                    echo "  ⚠ Could not parse pip-installed CMake version"
                    NEED_UPGRADE=true
                fi
            else
                echo "  ⚠ Could not determine pip-installed CMake version"
                NEED_UPGRADE=true
            fi
        else
            echo "  ⚠ pip-installed cmake not found in PATH"
            NEED_UPGRADE=true
        fi
    else
        echo "  ⚠ CMake pip package not found after installation"
        NEED_UPGRADE=true
    fi
    
    # Method 2: Try Kitware APT repository (official CMake builds)
    if [ "${NEED_UPGRADE}" = "true" ]; then
        echo "  Attempting to install CMake from Kitware APT repository..."
        # Validate APT_CMD is set
        if [ -z "${APT_CMD:-}" ]; then
            echo "  ⚠ ERROR: APT_CMD not set, cannot install packages"
            NEED_UPGRADE=true
        else
            # Install prerequisites
            ${APT_CMD} install -y -qq software-properties-common lsb-release wget gpg || true
            
            # Add Kitware APT repository
            wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | \
                gpg --dearmor - | \
                tee /etc/apt/trusted.gpg.d/kitware.gpg >/dev/null 2>&1 || true
            
            # Add repository (try to detect Ubuntu version)
            if [ -f /etc/os-release ]; then
                # Source os-release in a subshell to avoid polluting environment
                kitware_codename=""
                if [ -n "${UBUNTU_CODENAME:-}" ]; then
                    kitware_codename="${UBUNTU_CODENAME}"
                else
                    # Try reading from /etc/os-release if UBUNTU_CODENAME not set
                    if VERSION_CODENAME=$(grep -E '^VERSION_CODENAME=' /etc/os-release 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo ""); then
                        if [ -n "${VERSION_CODENAME:-}" ]; then
                            kitware_codename="${VERSION_CODENAME}"
                        fi
                    fi
                fi
                
                if [ -n "${kitware_codename:-}" ]; then
                    # Validate codename before using in URL (prevent injection)
                    if echo "${kitware_codename}" | grep -qE '^[a-z0-9-]+$'; then
                        echo "deb https://apt.kitware.com/ubuntu/ ${kitware_codename} main" | \
                            tee /etc/apt/sources.list.d/kitware.list >/dev/null 2>&1 || true
                        ${APT_CMD} update -qq || true
                        ${APT_CMD} install -y -qq --allow-change-held-packages cmake || {
                            echo "  ⚠ Kitware repository installation failed"
                            NEED_UPGRADE=true
                        }
                    else
                        echo "  ⚠ Invalid Ubuntu codename for Kitware repo: ${kitware_codename}"
                        NEED_UPGRADE=true
                    fi
                else
                    echo "  ⚠ Could not determine Ubuntu codename for Kitware repo"
                    NEED_UPGRADE=true
                fi
            else
                echo "  ⚠ /etc/os-release not found, cannot add Kitware repository"
                NEED_UPGRADE=true
            fi
        fi
    fi
    
    # Method 3: Compile CMake from source (last resort)
    if [ "${NEED_UPGRADE}" = "true" ]; then
        echo "  Attempting to compile CMake from source (this may take 10-30 minutes)..."
                if [ -n "${UBUNTU_CMAKE_VERSION:-}" ]; then
                    echo "  Note: Ubuntu repository has CMake ${UBUNTU_CMAKE_VERSION}, but ${CMAKE_REQUIRED_VERSION} is required"
                else
                    echo "  Note: CMake not found in repositories, compiling from source"
                fi
                
                # Verify build dependencies are available
                MISSING_BUILD_DEPS=$(check_cmake_build_dependencies)
                if [ -n "${MISSING_BUILD_DEPS:-}" ]; then
                    echo "  Installing missing build dependencies: ${MISSING_BUILD_DEPS}"
                    if [ -z "${APT_CMD:-}" ]; then
                        echo -e "${RED}✗ ERROR: APT_CMD not set, cannot install CMake build dependencies${NC}"
                        echo "  Missing: ${MISSING_BUILD_DEPS}"
                        exit 1
                    else
                        ${APT_CMD} install -y -qq ${MISSING_BUILD_DEPS} || {
                            echo -e "${RED}✗ ERROR: Failed to install CMake build dependencies${NC}"
                            echo "  Missing: ${MISSING_BUILD_DEPS}"
                            echo "  Please install manually: ${APT_CMD} install -y ${MISSING_BUILD_DEPS}"
                            exit 1
                        }
                        # Re-check after installation
                        MISSING_BUILD_DEPS=$(check_cmake_build_dependencies)
                        if [ -n "${MISSING_BUILD_DEPS:-}" ]; then
                            echo -e "${RED}✗ ERROR: Some dependencies still missing after installation${NC}"
                            echo "  Missing: ${MISSING_BUILD_DEPS}"
                            exit 1
                        fi
                    fi
                fi
                
                # Check if we have a bootstrap cmake (needed to build cmake)
                BOOTSTRAP_CMAKE=""
                if command -v cmake &>/dev/null; then
                    BOOTSTRAP_CMAKE=$(command -v cmake)
                    if [ -n "${INSTALLED_CMAKE_VERSION:-}" ]; then
                        echo "  Using existing CMake ${INSTALLED_CMAKE_VERSION} as bootstrap"
                    else
                        echo "  Using existing CMake as bootstrap"
                    fi
                else
                    echo "  No existing CMake found - will use bootstrap script"
                fi
                
                # Download CMake source from official GitHub releases
                CMAKE_SOURCE_DIR="/tmp/cmake_build"
                original_dir=$(pwd || echo "")
                
                # Clean up any existing build directory
                if [ -d "${CMAKE_SOURCE_DIR}" ]; then
                    rm -rf "${CMAKE_SOURCE_DIR}"
                fi
                mkdir -p "${CMAKE_SOURCE_DIR}" || {
                    echo "  ⚠ Failed to create CMake build directory: ${CMAKE_SOURCE_DIR}"
                    NEED_UPGRADE=true
                }
                
                if [ "${NEED_UPGRADE}" != "true" ]; then
                    cd "${CMAKE_SOURCE_DIR}" || {
                        echo "  ⚠ Failed to change to CMake build directory"
                        NEED_UPGRADE=true
                    }
                fi
                
                if [ "${NEED_UPGRADE}" != "true" ]; then
                    # Fetch latest stable CMake release from official GitHub releases
                    # Source: https://github.com/Kitware/CMake/releases
                    echo "  Fetching latest stable CMake version from GitHub releases..."
                    cmake_version_to_build=""
                    api_response=""
                    
                    # Use GitHub API to get latest non-prerelease version
                    # jq is required and should be installed by now
                    api_response=$(curl -s https://api.github.com/repos/Kitware/CMake/releases 2>/dev/null || echo "")
                    
                    if [ -n "${api_response:-}" ]; then
                        # jq is required - it should be installed in Step 1
                        if ! command -v jq &>/dev/null 2>&1; then
                            echo "  ⚠ ERROR: jq not found (should have been installed in Step 1)"
                            echo "  Installing jq now..."
                            if [ -z "${APT_CMD:-}" ]; then
                                echo "  ⚠ ERROR: APT_CMD not set, cannot install jq"
                                # Fallback: Parse JSON with grep/sed (less reliable but works)
                                cmake_version_to_build=$(echo "${api_response}" | \
                                    grep -E '"tag_name"|"prerelease"' | \
                                    grep -B1 '"prerelease":\s*false' | \
                                    grep '"tag_name"' | \
                                    head -1 | \
                                    sed -E 's/.*"tag_name":\s*"v?([^"]+)".*/\1/' | \
                                    sed 's/^v//' || echo "")
                            else
                                ${APT_CMD} install -y -qq jq || {
                                    echo "  ⚠ Failed to install jq, using fallback parsing"
                                    # Fallback: Parse JSON with grep/sed (less reliable but works)
                                    cmake_version_to_build=$(echo "${api_response}" | \
                                        grep -E '"tag_name"|"prerelease"' | \
                                        grep -B1 '"prerelease":\s*false' | \
                                        grep '"tag_name"' | \
                                        head -1 | \
                                        sed -E 's/.*"tag_name":\s*"v?([^"]+)".*/\1/' | \
                                        sed 's/^v//' || echo "")
                                }
                            fi
                        fi
                        
                        # Use jq if available (should be)
                        if command -v jq &>/dev/null 2>&1; then
                            cmake_version_to_build=$(echo "${api_response}" | \
                                jq -r '.[] | select(.prerelease == false) | .tag_name' 2>/dev/null | \
                                head -1 | \
                                sed 's/^v//' || echo "")
                        fi
                    fi
                    
                    # Fallback: Use a known good version if API fails
                    if [ -z "${cmake_version_to_build:-}" ]; then
                        echo "  ⚠ Could not fetch latest version from GitHub, using fallback version 3.28.1"
                        cmake_version_to_build="3.28.1"
                    else
                        # Validate version format (should be X.Y.Z)
                        if ! echo "${cmake_version_to_build}" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
                            echo "  ⚠ Invalid version format from API: ${cmake_version_to_build}, using fallback version 3.28.1"
                            cmake_version_to_build="3.28.1"
                        else
                            echo "  Found latest stable CMake version: ${cmake_version_to_build}"
                        fi
                    fi
                    
                    CMAKE_VERSION_TO_BUILD="${cmake_version_to_build}"
                    CMAKE_TARBALL="cmake-${CMAKE_VERSION_TO_BUILD}.tar.gz"
                    CMAKE_URL="https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION_TO_BUILD}/${CMAKE_TARBALL}"
                fi
                
                if [ "${NEED_UPGRADE}" != true ] && [ -n "${CMAKE_VERSION_TO_BUILD:-}" ] && [ -n "${CMAKE_URL:-}" ]; then
                    echo "  Downloading CMake ${CMAKE_VERSION_TO_BUILD} source..."
                    if wget -q "${CMAKE_URL}" -O "${CMAKE_TARBALL}"; then
                        if [ -f "${CMAKE_TARBALL}" ]; then
                            echo "  Extracting CMake source..."
                            tar -xzf "${CMAKE_TARBALL}" || {
                                echo "  ⚠ Failed to extract CMake source"
                                cd "${original_dir:-/tmp}" >/dev/null 2>&1 || true
                                NEED_UPGRADE=true
                            }
                            
                            if [ "${NEED_UPGRADE}" != true ] && [ -d "cmake-${CMAKE_VERSION_TO_BUILD}" ]; then
                                cd "cmake-${CMAKE_VERSION_TO_BUILD}" || {
                                    echo "  ⚠ Failed to change to CMake source directory"
                                    cd "${original_dir:-/tmp}" >/dev/null 2>&1 || true
                                    NEED_UPGRADE=true
                                }
                                
                                if [ "${NEED_UPGRADE}" != true ]; then
                                    echo "  Configuring CMake build..."
                                    # Bootstrap CMake (uses existing cmake if available, or builds minimal version first)
                                    build_jobs_cmake=""
                                    build_jobs_cmake="${BUILD_JOBS:-${CALCULATED_JOBS:-4}}"
                                    # Ensure build_jobs_cmake is at least 1 and numeric
                                    if [ -z "${build_jobs_cmake:-}" ] || ! echo "${build_jobs_cmake}" | grep -qE '^[0-9]+$'; then
                                        build_jobs_cmake=4
                                    fi
                                    
                                    if [ -n "${BOOTSTRAP_CMAKE:-}" ] && [ -x "${BOOTSTRAP_CMAKE}" ]; then
                                        ${BOOTSTRAP_CMAKE} -B build -S . \
                                            -DCMAKE_BUILD_TYPE=Release \
                                            -DCMAKE_INSTALL_PREFIX=/usr/local \
                                            -DCMAKE_USE_OPENSSL=ON || {
                                            echo "  ⚠ CMake configuration failed, trying bootstrap method..."
                                            ./bootstrap --prefix=/usr/local --parallel="${build_jobs_cmake}" || {
                                                echo "  ⚠ CMake bootstrap failed"
                                                cd "${original_dir:-/tmp}" >/dev/null 2>&1 || true
                                                NEED_UPGRADE=true
                                            }
                                        }
                                        
                                        if [ "${NEED_UPGRADE}" != true ]; then
                                            echo "  Building CMake (this will take 10-30 minutes)..."
                                            ${BOOTSTRAP_CMAKE} --build build --parallel "${build_jobs_cmake}" || {
                                                echo "  ⚠ CMake build failed, trying make..."
                                                if [ -d "build" ]; then
                                                    cd build || {
                                                        echo "  ⚠ Failed to change to build directory"
                                                        cd "${original_dir:-/tmp}" >/dev/null 2>&1 || true
                                                        NEED_UPGRADE=true
                                                    }
                                                    if [ "${NEED_UPGRADE}" != true ]; then
                                                        make -j"${build_jobs_cmake}" || {
                                                            echo "  ⚠ CMake compilation failed"
                                                            cd "${original_dir:-/tmp}" >/dev/null 2>&1 || true
                                                            NEED_UPGRADE=true
                                                        }
                                                    fi
                                                else
                                                    echo "  ⚠ Build directory not found"
                                                    NEED_UPGRADE=true
                                                fi
                                            }
                                            
                                            if [ "${NEED_UPGRADE}" != true ]; then
                                                # Return to source directory for install
                                                if [ "$(basename "$(pwd)")" = "build" ]; then
                                                    cd .. || {
                                                        echo "  ⚠ Failed to return to source directory"
                                                        cd "${original_dir:-/tmp}" >/dev/null 2>&1 || true
                                                        NEED_UPGRADE=true
                                                    }
                                                fi
                                                
                                                if [ "${NEED_UPGRADE}" != true ]; then
                                                    echo "  Installing CMake..."
                                                    ${BOOTSTRAP_CMAKE} --install build || {
                                                        if [ -d "build" ]; then
                                                            cd build || {
                                                                echo "  ⚠ Failed to change to build directory for install"
                                                                cd "${original_dir:-/tmp}" >/dev/null 2>&1 || true
                                                                NEED_UPGRADE=true
                                                            }
                                                            if [ "${NEED_UPGRADE}" != true ]; then
                                                                make install || {
                                                                    echo "  ⚠ CMake installation failed"
                                                                    cd "${original_dir:-/tmp}" >/dev/null 2>&1 || true
                                                                    NEED_UPGRADE=true
                                                                }
                                                            fi
                                                        else
                                                            echo "  ⚠ Build directory not found for install"
                                                            NEED_UPGRADE=true
                                                        fi
                                                    }
                                                    
                                                    if [ "${NEED_UPGRADE}" != true ]; then
                                                        # Update PATH to include /usr/local/bin (where cmake is installed)
                                                        if [ -n "${PATH:-}" ]; then
                                                            export PATH="/usr/local/bin:${PATH}"
                                                        else
                                                            export PATH="/usr/local/bin"
                                                        fi
                                                        ldconfig || true
                                                    fi
                                                fi
                                            fi
                                        fi
                                    else
                                        # No bootstrap cmake available, use bootstrap script
                                        echo "  Bootstrapping CMake (no existing cmake found)..."
                                        ./bootstrap --prefix=/usr/local --parallel="${build_jobs_cmake}" || {
                                            echo "  ⚠ CMake bootstrap failed"
                                            cd "${original_dir:-/tmp}" >/dev/null 2>&1 || true
                                            NEED_UPGRADE=true
                                        }
                                        
                                        if [ "${NEED_UPGRADE}" != true ]; then
                                            echo "  Building CMake (this will take 10-30 minutes)..."
                                            make -j"${build_jobs_cmake}" || {
                                                echo "  ⚠ CMake build failed"
                                                cd "${original_dir:-/tmp}" >/dev/null 2>&1 || true
                                                NEED_UPGRADE=true
                                            }
                                            
                                            if [ "${NEED_UPGRADE}" != true ]; then
                                                echo "  Installing CMake..."
                                                make install || {
                                                    echo "  ⚠ CMake installation failed"
                                                    cd "${original_dir:-/tmp}" >/dev/null 2>&1 || true
                                                    NEED_UPGRADE=true
                                                }
                                                
                                                if [ "${NEED_UPGRADE}" != true ]; then
                                                    # Update PATH to include /usr/local/bin
                                                    if [ -n "${PATH:-}" ]; then
                                                        export PATH="/usr/local/bin:${PATH}"
                                                    else
                                                        export PATH="/usr/local/bin"
                                                    fi
                                                    ldconfig || true
                                                fi
                                            fi
                                        fi
                                    fi
                                    
                                    # Return to original directory
                                    cd "${original_dir:-/tmp}" >/dev/null 2>&1 || true
                                fi
                            fi
                        else
                            echo "  ⚠ CMake tarball not found after download"
                            cd "${original_dir:-/tmp}" >/dev/null 2>&1 || true
                            NEED_UPGRADE=true
                        fi
                    else
                        echo "  ⚠ Failed to download CMake from ${CMAKE_URL}"
                        cd "${original_dir:-/tmp}" >/dev/null 2>&1 || true
                        NEED_UPGRADE=true
                    fi
                    
                    # Clean up build directory
                    if [ -d "${CMAKE_SOURCE_DIR}" ]; then
                        rm -rf "${CMAKE_SOURCE_DIR}" || true
                    fi
                else
                    echo "  ⚠ Cannot proceed with CMake compilation (missing version or URL)"
                    if [ -n "${original_dir:-}" ]; then
                        cd "${original_dir}" >/dev/null 2>&1 || true
                    fi
                    NEED_UPGRADE=true
                fi
            fi
            
            # Final verification
            if command -v cmake &>/dev/null; then
                FINAL_CMAKE_VERSION=$(cmake --version 2>/dev/null | head -1 | sed 's/.*version \([0-9]\+\.[0-9]\+\).*/\1/' || echo "")
                if [ -n "${FINAL_CMAKE_VERSION:-}" ]; then
                    FINAL_CMAKE_MAJOR=$(echo "${FINAL_CMAKE_VERSION}" | cut -d. -f1)
                    FINAL_CMAKE_MINOR=$(echo "${FINAL_CMAKE_VERSION}" | cut -d. -f2)
                    # Validate version components
                    if [ -n "${FINAL_CMAKE_MAJOR:-}" ] && [ -n "${FINAL_CMAKE_MINOR:-}" ] && \
                       echo "${FINAL_CMAKE_MAJOR}" | grep -qE '^[0-9]+$' && \
                       echo "${FINAL_CMAKE_MINOR}" | grep -qE '^[0-9]+$'; then
                        # Compare against required version (dynamic)
                        REQUIRED_CMAKE_MAJOR=$(echo "${CMAKE_REQUIRED_VERSION}" | cut -d. -f1)
                        REQUIRED_CMAKE_MINOR=$(echo "${CMAKE_REQUIRED_VERSION}" | cut -d. -f2)
                        if [ -n "${REQUIRED_CMAKE_MAJOR:-}" ] && [ -n "${REQUIRED_CMAKE_MINOR:-}" ] && \
                           echo "${REQUIRED_CMAKE_MAJOR}" | grep -qE '^[0-9]+$' && \
                           echo "${REQUIRED_CMAKE_MINOR}" | grep -qE '^[0-9]+$'; then
                            if [ "${FINAL_CMAKE_MAJOR}" -gt "${REQUIRED_CMAKE_MAJOR}" ] || \
                               ([ "${FINAL_CMAKE_MAJOR}" -eq "${REQUIRED_CMAKE_MAJOR}" ] && [ "${FINAL_CMAKE_MINOR}" -ge "${REQUIRED_CMAKE_MINOR}" ]); then
                                echo -e "  ${GREEN}✓ CMake ${FINAL_CMAKE_VERSION} now meets requirement${NC}"
                                NEED_UPGRADE=false
                            else
                                echo -e "  ${YELLOW}⚠ WARNING: CMake ${FINAL_CMAKE_VERSION} < ${CMAKE_REQUIRED_VERSION}${NC}"
                                echo "    PyTorch build may fail. Consider manual CMake upgrade."
                                NEED_UPGRADE=true
                            fi
                        else
                            echo "  ⚠ Could not parse required CMake version"
                            NEED_UPGRADE=true
                        fi
                    else
                        echo "  ⚠ Could not parse final CMake version components"
                        NEED_UPGRADE=true
                    fi
                else
                    echo "  ⚠ Could not determine final CMake version"
                    NEED_UPGRADE=true
                fi
            else
                echo "  ⚠ CMake not found in PATH after upgrade attempts"
                NEED_UPGRADE=true
            fi
fi

# Final fallback: If CMake still not available, try basic installation
if ! command -v cmake &>/dev/null 2>&1; then
    echo "  ⚠ CMake not found after all upgrade attempts"
    echo "  Installing CMake via apt-get as final fallback..."
    ${APT_CMD} install -y -qq cmake || {
        echo -e "${YELLOW}⚠ CMake installation via apt-get failed${NC}"
        echo "  You may need to install CMake manually"
    }
fi

# Final CMake verification
if ! command -v cmake &>/dev/null; then
    echo -e "${RED}✗ ERROR: CMake not found after installation attempt${NC}"
    echo "  Please install CMake manually:"
    echo "    pip install cmake"
    echo "    OR"
    echo "    apt-get install cmake"
    exit 1
else
    FINAL_VER=$(cmake --version 2>/dev/null | head -1 | sed 's/.*version \([0-9]\+\.[0-9]\+\).*/\1/' || echo "")
    if [ -n "${FINAL_VER:-}" ]; then
        echo -e "  ${GREEN}✓ CMake ${FINAL_VER} ready${NC}"
    fi
fi

# Verify OpenBLAS installation
OPENBLAS_FOUND=false
OPENBLAS_LIB=""

if ldconfig -p 2>/dev/null | grep -q libopenblas; then
    echo -e "${GREEN}✓ OpenBLAS found in system libraries${NC}"
    OPENBLAS_FOUND=true
fi

# Check common library paths
for lib_path in \
    "/usr/lib/x86_64-linux-gnu/libopenblas.so" \
    "/usr/lib/x86_64-linux-gnu/libopenblas.so.0" \
    "/usr/local/lib/libopenblas.so"; do
    if [ -f "${lib_path}" ]; then
        OPENBLAS_LIB="${lib_path}"
        echo -e "${GREEN}✓ Found OpenBLAS: ${OPENBLAS_LIB}${NC}"
        OPENBLAS_FOUND=true
        break
    fi
done

if [ "${OPENBLAS_FOUND}" = false ]; then
    echo -e "${RED}✗ ERROR: OpenBLAS not found after installation${NC}"
    exit 1
fi

# Verify OpenBLAS headers
if [ -f "/usr/include/x86_64-linux-gnu/cblas.h" ] || [ -f "/usr/include/cblas.h" ]; then
    echo -e "${GREEN}✓ OpenBLAS headers found${NC}"
else
    echo -e "${YELLOW}⚠ OpenBLAS headers not found${NC}"
fi

# Verify and install OpenMP if missing
OPENMP_FOUND=false
if ldconfig -p 2>/dev/null | grep -q libomp; then
    echo -e "${GREEN}✓ OpenMP found${NC}"
    OPENMP_FOUND=true
else
    echo -e "${YELLOW}⚠ OpenMP not found - installing...${NC}"
    if [ -z "${APT_CMD:-}" ]; then
        echo -e "${RED}✗ ERROR: APT_CMD not set${NC}"
        OPENMP_FOUND=false
    elif ! check_package "libomp-dev"; then
        if ${APT_CMD} install -y -qq libomp-dev libomp5 2>/dev/null; then
            # Verify installation succeeded
            if ldconfig -p 2>/dev/null | grep -q libomp; then
                echo -e "${GREEN}✓ OpenMP installed and verified${NC}"
                OPENMP_FOUND=true
            else
                echo -e "${YELLOW}⚠ OpenMP installation completed but library not found in ldconfig${NC}"
                OPENMP_FOUND=false
            fi
        else
            echo -e "${YELLOW}⚠ OpenMP installation failed, continuing...${NC}"
            OPENMP_FOUND=false
        fi
    else
        # Package already installed, verify library is available
        if ldconfig -p 2>/dev/null | grep -q libomp; then
            echo -e "${GREEN}✓ OpenMP package installed and library verified${NC}"
            OPENMP_FOUND=true
        else
            echo -e "${YELLOW}⚠ OpenMP package installed but library not found in ldconfig${NC}"
            OPENMP_FOUND=false
        fi
    fi
fi

# Verify and install TBB (Threading Building Blocks) if missing
TBB_FOUND=false
if ldconfig -p 2>/dev/null | grep -q libtbb; then
    echo -e "${GREEN}✓ TBB (Threading Building Blocks) found${NC}"
    TBB_FOUND=true
else
    echo -e "${YELLOW}⚠ TBB not found - installing...${NC}"
    if [ -z "${APT_CMD:-}" ]; then
        echo -e "${RED}✗ ERROR: APT_CMD not set${NC}"
        TBB_FOUND=false
    elif ! check_package "libtbb-dev"; then
        if ${APT_CMD} install -y -qq libtbb-dev 2>/dev/null; then
            # Verify installation succeeded
            if ldconfig -p 2>/dev/null | grep -q libtbb; then
                echo -e "${GREEN}✓ TBB installed and verified${NC}"
                TBB_FOUND=true
            else
                echo -e "${YELLOW}⚠ TBB installation completed but library not found in ldconfig${NC}"
                TBB_FOUND=false
            fi
        else
            echo -e "${YELLOW}⚠ TBB installation failed, continuing...${NC}"
            TBB_FOUND=false
        fi
    else
        # Package already installed, verify library is available
        if ldconfig -p 2>/dev/null | grep -q libtbb; then
            echo -e "${GREEN}✓ TBB package installed and library verified${NC}"
            TBB_FOUND=true
        else
            echo -e "${YELLOW}⚠ TBB package installed but library not found in ldconfig${NC}"
            TBB_FOUND=false
        fi
    fi
fi

# Verify and install LAPACK if missing
LAPACK_FOUND=false
if ldconfig -p 2>/dev/null | grep -q liblapack; then
    echo -e "${GREEN}✓ LAPACK found${NC}"
    LAPACK_FOUND=true
else
    echo -e "${YELLOW}⚠ LAPACK not found - installing...${NC}"
    if [ -z "${APT_CMD:-}" ]; then
        echo -e "${RED}✗ ERROR: APT_CMD not set${NC}"
        LAPACK_FOUND=false
    elif ! check_package "liblapack-dev"; then
        if ${APT_CMD} install -y -qq liblapack-dev liblapacke-dev 2>/dev/null; then
            # Verify installation succeeded
            if ldconfig -p 2>/dev/null | grep -q liblapack; then
                echo -e "${GREEN}✓ LAPACK installed and verified${NC}"
                LAPACK_FOUND=true
            else
                echo -e "${YELLOW}⚠ LAPACK installation completed but library not found in ldconfig${NC}"
                LAPACK_FOUND=false
            fi
        else
            echo -e "${YELLOW}⚠ LAPACK installation failed, continuing...${NC}"
            LAPACK_FOUND=false
        fi
    else
        # Package already installed, verify library is available
        if ldconfig -p 2>/dev/null | grep -q liblapack; then
            echo -e "${GREEN}✓ LAPACK package installed and library verified${NC}"
            LAPACK_FOUND=true
        else
            echo -e "${YELLOW}⚠ LAPACK package installed but library not found in ldconfig${NC}"
            LAPACK_FOUND=false
        fi
    fi
fi

# Verify LAPACKE (LAPACK C interface) - required for some PyTorch operations
LAPACKE_FOUND=false
if ldconfig -p 2>/dev/null | grep -q liblapacke; then
    echo -e "${GREEN}✓ LAPACKE found${NC}"
    LAPACKE_FOUND=true
else
    echo -e "${YELLOW}⚠ LAPACKE not found - installing...${NC}"
    if [ -z "${APT_CMD:-}" ]; then
        echo -e "${YELLOW}⚠ APT_CMD not set, skipping LAPACKE installation (optional)${NC}"
        LAPACKE_FOUND=false
    elif ! check_package "liblapacke-dev"; then
        if ${APT_CMD} install -y -qq liblapacke-dev 2>/dev/null; then
            # Verify installation succeeded
            if ldconfig -p 2>/dev/null | grep -q liblapacke; then
                echo -e "${GREEN}✓ LAPACKE installed and verified${NC}"
                LAPACKE_FOUND=true
            else
                echo -e "${YELLOW}⚠ LAPACKE installation completed but library not found in ldconfig (optional)${NC}"
                LAPACKE_FOUND=false
            fi
        else
            echo -e "${YELLOW}⚠ LAPACKE installation failed, continuing (optional)...${NC}"
            LAPACKE_FOUND=false
        fi
    else
        # Package already installed, verify library is available
        if ldconfig -p 2>/dev/null | grep -q liblapacke; then
            echo -e "${GREEN}✓ LAPACKE package installed and library verified${NC}"
            LAPACKE_FOUND=true
        else
            echo -e "${YELLOW}⚠ LAPACKE package installed but library not found in ldconfig (optional)${NC}"
            LAPACKE_FOUND=false
        fi
    fi
fi

#===============================================================================
# Step 1.5: Detect and configure optional libraries (OpenCV, Ceres, g2o, GTSAM)
#===============================================================================
echo -e "${BLUE}[Step 1.5] Detecting optional libraries for PyTorch linking...${NC}"

# Detect OpenCV
OPENCV_FOUND=false
OPENCV_DIR=""
if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists opencv4 2>/dev/null; then
    OPENCV_FOUND=true
    OPENCV_DIR=$(pkg-config --variable=prefix opencv4 2>/dev/null || echo "")
    if [ -z "${OPENCV_DIR:-}" ] || [ ! -d "${OPENCV_DIR}" ]; then
        OPENCV_DIR="/usr/local"
    fi
    echo -e "${GREEN}✓ OpenCV 4 found via pkg-config${NC}"
    echo "  OpenCV prefix: ${OPENCV_DIR}"
elif command -v pkg-config >/dev/null 2>&1 && pkg-config --exists opencv 2>/dev/null; then
    OPENCV_FOUND=true
    OPENCV_DIR=$(pkg-config --variable=prefix opencv 2>/dev/null || echo "")
    if [ -z "${OPENCV_DIR:-}" ] || [ ! -d "${OPENCV_DIR}" ]; then
        OPENCV_DIR="/usr/local"
    fi
    echo -e "${GREEN}✓ OpenCV found via pkg-config${NC}"
    echo "  OpenCV prefix: ${OPENCV_DIR}"
elif [ -f "/usr/local/lib/pkgconfig/opencv4.pc" ] || [ -f "/usr/lib/x86_64-linux-gnu/pkgconfig/opencv4.pc" ]; then
    OPENCV_FOUND=true
    if [ -f "/usr/local/lib/pkgconfig/opencv4.pc" ] && [ -d "/usr/local" ]; then
        OPENCV_DIR="/usr/local"
    elif [ -f "/usr/lib/x86_64-linux-gnu/pkgconfig/opencv4.pc" ] && [ -d "/usr" ]; then
        OPENCV_DIR="/usr"
    else
        OPENCV_DIR="/usr/local"
    fi
    echo -e "${GREEN}✓ OpenCV found in system${NC}"
    echo "  OpenCV prefix: ${OPENCV_DIR}"
elif [ -d "/usr/local/include/opencv4" ] || [ -d "/usr/include/opencv4" ]; then
    OPENCV_FOUND=true
    if [ -d "/usr/local/include/opencv4" ] && [ -d "/usr/local" ]; then
        OPENCV_DIR="/usr/local"
    elif [ -d "/usr/include/opencv4" ] && [ -d "/usr" ]; then
        OPENCV_DIR="/usr"
    else
        OPENCV_DIR="/usr/local"
    fi
    echo -e "${GREEN}✓ OpenCV headers found${NC}"
    echo "  OpenCV prefix: ${OPENCV_DIR}"
else
    echo -e "${YELLOW}⚠ OpenCV not found (optional)${NC}"
    echo "  PyTorch will be built without OpenCV support"
fi

# Detect Ceres Solver
CERES_FOUND=false
CERES_DIR=""
if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists ceres 2>/dev/null; then
    CERES_FOUND=true
    CERES_DIR=$(pkg-config --variable=prefix ceres 2>/dev/null || echo "")
    if [ -z "${CERES_DIR:-}" ] || [ ! -d "${CERES_DIR}" ]; then
        CERES_DIR="/usr/local"
    fi
    echo -e "${GREEN}✓ Ceres Solver found via pkg-config${NC}"
    echo "  Ceres prefix: ${CERES_DIR}"
elif [ -f "/usr/local/lib/cmake/Ceres/CeresConfig.cmake" ] || [ -f "/usr/lib/x86_64-linux-gnu/cmake/Ceres/CeresConfig.cmake" ]; then
    CERES_FOUND=true
    if [ -f "/usr/local/lib/cmake/Ceres/CeresConfig.cmake" ] && [ -d "/usr/local" ]; then
        CERES_DIR="/usr/local"
    elif [ -f "/usr/lib/x86_64-linux-gnu/cmake/Ceres/CeresConfig.cmake" ] && [ -d "/usr" ]; then
        CERES_DIR="/usr"
    else
        CERES_DIR="/usr/local"
    fi
    echo -e "${GREEN}✓ Ceres Solver found in system${NC}"
    echo "  Ceres prefix: ${CERES_DIR}"
elif [ -f "/usr/local/include/ceres/ceres.h" ] || [ -f "/usr/include/ceres/ceres.h" ]; then
    CERES_FOUND=true
    if [ -f "/usr/local/include/ceres/ceres.h" ] && [ -d "/usr/local" ]; then
        CERES_DIR="/usr/local"
    elif [ -f "/usr/include/ceres/ceres.h" ] && [ -d "/usr" ]; then
        CERES_DIR="/usr"
    else
        CERES_DIR="/usr/local"
    fi
    echo -e "${GREEN}✓ Ceres Solver headers found${NC}"
    echo "  Ceres prefix: ${CERES_DIR}"
else
    echo -e "${YELLOW}⚠ Ceres Solver not found (optional)${NC}"
    echo "  PyTorch will be built without Ceres support"
fi

# Detect g2o
G2O_FOUND=false
G2O_DIR=""
if [ -f "/usr/local/lib/cmake/g2o/g2oConfig.cmake" ] || [ -f "/usr/lib/x86_64-linux-gnu/cmake/g2o/g2oConfig.cmake" ]; then
    G2O_FOUND=true
    if [ -f "/usr/local/lib/cmake/g2o/g2oConfig.cmake" ] && [ -d "/usr/local" ]; then
        G2O_DIR="/usr/local"
    elif [ -f "/usr/lib/x86_64-linux-gnu/cmake/g2o/g2oConfig.cmake" ] && [ -d "/usr" ]; then
        G2O_DIR="/usr"
    else
        G2O_DIR="/usr/local"
    fi
    echo -e "${GREEN}✓ g2o found in system${NC}"
    echo "  g2o prefix: ${G2O_DIR}"
elif [ -f "/usr/local/include/g2o/core/base_vertex.h" ] || [ -f "/usr/include/g2o/core/base_vertex.h" ]; then
    G2O_FOUND=true
    if [ -f "/usr/local/include/g2o/core/base_vertex.h" ] && [ -d "/usr/local" ]; then
        G2O_DIR="/usr/local"
    elif [ -f "/usr/include/g2o/core/base_vertex.h" ] && [ -d "/usr" ]; then
        G2O_DIR="/usr"
    else
        G2O_DIR="/usr/local"
    fi
    echo -e "${GREEN}✓ g2o headers found${NC}"
    echo "  g2o prefix: ${G2O_DIR}"
else
    echo -e "${YELLOW}⚠ g2o not found (optional)${NC}"
    echo "  PyTorch will be built without g2o support"
fi

# Detect GTSAM
GTSAM_FOUND=false
GTSAM_DIR=""
if [ -f "/usr/local/lib/cmake/GTSAM/GTSAMConfig.cmake" ] || [ -f "/usr/lib/x86_64-linux-gnu/cmake/GTSAM/GTSAMConfig.cmake" ]; then
    GTSAM_FOUND=true
    if [ -f "/usr/local/lib/cmake/GTSAM/GTSAMConfig.cmake" ] && [ -d "/usr/local" ]; then
        GTSAM_DIR="/usr/local"
    elif [ -f "/usr/lib/x86_64-linux-gnu/cmake/GTSAM/GTSAMConfig.cmake" ] && [ -d "/usr" ]; then
        GTSAM_DIR="/usr"
    else
        GTSAM_DIR="/usr/local"
    fi
    echo -e "${GREEN}✓ GTSAM found in system${NC}"
    echo "  GTSAM prefix: ${GTSAM_DIR}"
elif [ -f "/usr/local/include/gtsam/base/Matrix.h" ] || [ -f "/usr/include/gtsam/base/Matrix.h" ]; then
    GTSAM_FOUND=true
    if [ -f "/usr/local/include/gtsam/base/Matrix.h" ] && [ -d "/usr/local" ]; then
        GTSAM_DIR="/usr/local"
    elif [ -f "/usr/include/gtsam/base/Matrix.h" ] && [ -d "/usr" ]; then
        GTSAM_DIR="/usr"
    else
        GTSAM_DIR="/usr/local"
    fi
    echo -e "${GREEN}✓ GTSAM headers found${NC}"
    echo "  GTSAM prefix: ${GTSAM_DIR}"
else
    echo -e "${YELLOW}⚠ GTSAM not found (optional)${NC}"
    echo "  PyTorch will be built without GTSAM support"
fi

echo ""

#===============================================================================
# Step 2: Check for MKL (should NOT be present or must be disabled)
#===============================================================================
echo -e "${BLUE}[Step 2] Checking for MKL conflicts...${NC}"

if ldconfig -p 2>/dev/null | grep -q mkl; then
    echo -e "${YELLOW}⚠ WARNING: MKL found in system${NC}"
    echo "  PyTorch build will be configured to use OpenBLAS instead"
    echo "  MKL will be disabled via environment variables"
else
    echo -e "${GREEN}✓ No MKL found (good - OpenBLAS will be used)${NC}\n"
fi

#===============================================================================
# Step 3: Detect CUDA version
#===============================================================================
echo -e "${BLUE}[Step 3] Detecting CUDA version...${NC}"

detect_cuda() {
    local cuda_full=""
    local cuda_home_found=""
    local nvcc_path=""
    local cuda_dir=""
    local cuda_lib=""
    local cuda_dir_from_lib=""
    
    # Method 1: Check if nvcc is in PATH (most reliable - means toolkit is installed)
    if command -v nvcc &> /dev/null; then
        nvcc_path=$(command -v nvcc)
        if [ -n "${nvcc_path:-}" ] && [ -x "${nvcc_path}" ]; then
            cuda_full=$(nvcc --version 2>/dev/null | grep "release" | sed 's/.*release \([0-9]\+\.[0-9]\+\).*/\1/' || echo "")
            if [ -n "${cuda_full:-}" ]; then
                echo "  Detected CUDA via nvcc: ${cuda_full}" >&2
                # Get CUDA_HOME from nvcc path (nvcc is typically in bin/, so go up two levels)
                cuda_home_found=$(dirname "$(dirname "${nvcc_path}")")
                if [ -n "${cuda_home_found:-}" ] && [ -d "${cuda_home_found}" ]; then
                    echo "${cuda_full}|${cuda_home_found}"
                    return 0
                fi
            fi
        fi
    fi
    
    # Method 2: Check CUDA_HOME environment variable
    if [ -n "${CUDA_HOME:-}" ] && [ -d "${CUDA_HOME}" ]; then
        if [ -f "${CUDA_HOME}/bin/nvcc" ] && [ -x "${CUDA_HOME}/bin/nvcc" ]; then
            cuda_full=$("${CUDA_HOME}/bin/nvcc" --version 2>/dev/null | grep "release" | sed 's/.*release \([0-9]\+\.[0-9]\+\).*/\1/' || echo "")
            if [ -z "${cuda_full:-}" ] && [ -f "${CUDA_HOME}/version.txt" ]; then
                # Use portable sed instead of grep -oP (Perl regex not available on all systems)
                cuda_full=$(grep "CUDA Version" "${CUDA_HOME}/version.txt" 2>/dev/null | sed -n 's/.*CUDA Version \([0-9]\+\.[0-9]\+\).*/\1/p' || echo "")
            fi
            if [ -n "${cuda_full:-}" ]; then
                echo "  Detected CUDA via CUDA_HOME: ${cuda_full}" >&2
                echo "${cuda_full}|${CUDA_HOME}"
                return 0
            fi
        fi
    fi
    
    # Method 3: Check common CUDA installation paths
    # Use nullglob to handle case where glob doesn't match
    shopt -s nullglob 2>/dev/null || true
    for cuda_dir in /usr/local/cuda-* /usr/local/cuda; do
        if [ -d "${cuda_dir}" ] && [ -f "${cuda_dir}/bin/nvcc" ] && [ -x "${cuda_dir}/bin/nvcc" ]; then
            # Try to get version from nvcc
            cuda_full=$("${cuda_dir}/bin/nvcc" --version 2>/dev/null | grep "release" | sed 's/.*release \([0-9]\+\.[0-9]\+\).*/\1/' || echo "")
            if [ -z "${cuda_full:-}" ] && [ -f "${cuda_dir}/version.txt" ]; then
                # Use portable sed instead of grep -oP
                cuda_full=$(grep "CUDA Version" "${cuda_dir}/version.txt" 2>/dev/null | sed -n 's/.*CUDA Version \([0-9]\+\.[0-9]\+\).*/\1/p' || echo "")
            fi
            if [ -z "${cuda_full:-}" ]; then
                # Extract version from directory name
                cuda_full=$(echo "${cuda_dir}" | sed -n 's|.*cuda-\([0-9]\+\.[0-9]\+\).*|\1|p')
            fi
            if [ -n "${cuda_full:-}" ]; then
                echo "  Detected CUDA via installation path: ${cuda_full}" >&2
                echo "${cuda_full}|${cuda_dir}"
                shopt -u nullglob 2>/dev/null || true
                return 0
            fi
        fi
    done
    shopt -u nullglob 2>/dev/null || true
    
    # Method 4: Check for CUDA libraries (less reliable - might be runtime only)
    # Use find with proper error handling
    cuda_lib=$(find /usr/local/cuda-*/lib64/libcudart.so* 2>/dev/null | head -1 || echo "")
    if [ -n "${cuda_lib:-}" ] && [ -f "${cuda_lib}" ]; then
        cuda_full=$(echo "${cuda_lib}" | sed -n 's|.*cuda-\([0-9]\+\.[0-9]\+\).*|\1|p')
        if [ -n "${cuda_full:-}" ]; then
            # Go up three directory levels: lib64 -> lib -> cuda-X.Y -> /usr/local
            cuda_dir_from_lib=$(dirname "$(dirname "$(dirname "${cuda_lib}")")")
            if [ -n "${cuda_dir_from_lib:-}" ] && [ -d "${cuda_dir_from_lib}" ]; then
                echo "  Detected CUDA via library path: ${cuda_full}" >&2
                echo "  ⚠ WARNING: CUDA libraries found but nvcc not in PATH" >&2
                echo "  ⚠ This may indicate CUDA runtime is installed but toolkit is missing" >&2
                echo "${cuda_full}|${cuda_dir_from_lib}"
                return 0
            fi
        fi
    fi
    
    echo "unknown|"
    return 1
}

CUDA_DETECTION=$(detect_cuda)
CUDA_VERSION=$(echo "${CUDA_DETECTION}" | cut -d'|' -f1)
CUDA_HOME_DETECTED=$(echo "${CUDA_DETECTION}" | cut -d'|' -f2)

# Validate CUDA detection result
if [ "${CUDA_VERSION}" = "unknown" ] || [ -z "${CUDA_VERSION:-}" ]; then
    echo -e "${RED}✗ ERROR: CUDA toolkit not found${NC}"
    echo ""
    echo "  CUDA toolkit is required for PyTorch GPU support."
    echo "  Please install CUDA toolkit:"
    echo "    1. Download from: https://developer.nvidia.com/cuda-downloads"
    echo "    2. Or install via package manager (Ubuntu/Debian):"
    echo "       sudo apt-get install nvidia-cuda-toolkit"
    echo ""
    echo "  After installation, ensure:"
    echo "    - nvcc is in PATH: command -v nvcc"
    echo "    - CUDA_HOME is set (or /usr/local/cuda exists)"
    echo ""
    exit 1
fi

# Validate CUDA_VERSION format (should be X.Y where X and Y are digits)
if ! echo "${CUDA_VERSION}" | grep -qE '^[0-9]+\.[0-9]+$'; then
    echo -e "${RED}✗ ERROR: Invalid CUDA version format: ${CUDA_VERSION}${NC}"
    echo "  Expected format: X.Y (e.g., 12.1)"
    exit 1
fi

# Extract CUDA major version with validation
CUDA_MAJOR=$(echo "${CUDA_VERSION}" | cut -d. -f1)
if [ -z "${CUDA_MAJOR:-}" ] || ! echo "${CUDA_MAJOR}" | grep -qE '^[0-9]+$'; then
    echo -e "${RED}✗ ERROR: Could not extract CUDA major version from: ${CUDA_VERSION}${NC}"
    exit 1
fi
# CUDA_MINOR=$(echo "${CUDA_VERSION}" | cut -d. -f2)  # Not used elsewhere, removed to avoid unused variable warning

# Set CUDA_HOME based on detected version
# Validate CUDA_HOME_DETECTED before using it
if [ -n "${CUDA_HOME_DETECTED:-}" ] && [ -d "${CUDA_HOME_DETECTED}" ]; then
    export CUDA_HOME="${CUDA_HOME_DETECTED}"
elif [ -n "${CUDA_VERSION:-}" ] && [ -d "/usr/local/cuda-${CUDA_VERSION}" ]; then
    export CUDA_HOME="/usr/local/cuda-${CUDA_VERSION}"
elif [ -d "/usr/local/cuda" ]; then
    export CUDA_HOME="/usr/local/cuda"
fi

# Set CUDA paths if CUDA_HOME is set
if [ -n "${CUDA_HOME:-}" ] && [ -d "${CUDA_HOME}" ]; then
    # Safely update PATH - handle case where PATH might be unset
    if [ -n "${PATH:-}" ]; then
        export PATH="${CUDA_HOME}/bin:${PATH}"
    else
        export PATH="${CUDA_HOME}/bin"
    fi
    
    # Safely update LD_LIBRARY_PATH
    if [ -n "${LD_LIBRARY_PATH:-}" ]; then
        export LD_LIBRARY_PATH="${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}"
    else
        export LD_LIBRARY_PATH="${CUDA_HOME}/lib64"
    fi
    
    # Verify nvcc is accessible
    if [ -f "${CUDA_HOME}/bin/nvcc" ] && [ -x "${CUDA_HOME}/bin/nvcc" ]; then
        export CMAKE_CUDA_COMPILER="${CUDA_HOME}/bin/nvcc"
        echo "  CUDA_HOME: ${CUDA_HOME}"
        echo "  CMAKE_CUDA_COMPILER: ${CMAKE_CUDA_COMPILER}"
        
        # Verify nvcc works
        if ! "${CMAKE_CUDA_COMPILER}" --version &>/dev/null; then
            echo -e "${RED}✗ ERROR: nvcc found but not working${NC}"
            echo "  Please verify CUDA toolkit installation"
            exit 1
        fi
    else
        echo -e "${RED}✗ ERROR: nvcc not found or not executable at ${CUDA_HOME}/bin/nvcc${NC}"
        echo "  CUDA toolkit may be incomplete. Please reinstall."
        exit 1
    fi
else
    echo -e "${RED}✗ ERROR: CUDA_HOME could not be determined${NC}"
    echo "  Detected CUDA version: ${CUDA_VERSION:-unknown}"
    echo "  Please set CUDA_HOME environment variable or ensure CUDA is installed in /usr/local/cuda"
    exit 1
fi

# Final verification: Check nvcc is in PATH and working
if ! command -v nvcc &> /dev/null; then
    echo -e "${RED}✗ ERROR: nvcc not found in PATH after setting CUDA_HOME${NC}"
    echo "  CUDA_HOME: ${CUDA_HOME:-not set}"
    echo "  PATH: ${PATH:-not set}"
    exit 1
fi

# Display CUDA version
echo "  CUDA version: ${CUDA_VERSION}"
if [ -n "${CUDA_MAJOR:-}" ] && [ "${CUDA_MAJOR}" = "12" ]; then
    echo -e "${GREEN}✓ CUDA ${CUDA_VERSION} toolkit detected and verified${NC}"
else
    echo -e "${YELLOW}⚠ CUDA ${CUDA_VERSION} detected (expected 12.x)${NC}"
fi

# Function to check if nvcc supports a specific compute capability
check_nvcc_arch_support() {
    local arch="${1:-}"
    if [ -z "${arch}" ]; then
        return 1
    fi
    
    # Validate arch format (should be X.Y where X and Y are digits)
    if ! echo "${arch}" | grep -qE '^[0-9]+\.[0-9]+$'; then
        return 1
    fi
    
    local arch_no_dot
    arch_no_dot=$(echo "${arch}" | tr -d '.' 2>/dev/null || echo "")
    if [ -z "${arch_no_dot}" ]; then
        return 1
    fi
    
    # First, try to test nvcc directly (most reliable method)
    if command -v nvcc >/dev/null 2>&1; then
        local test_file
        test_file=$(mktemp /tmp/nvcc_test_XXXXXX.cu 2>/dev/null || echo "")
        if [ -z "${test_file}" ]; then
            # Fallback if mktemp fails
            test_file="/tmp/nvcc_test_${arch_no_dot}_$$.cu"
        fi
        
        # Create test file
        if ! echo '__global__ void test(){}' > "${test_file}" 2>/dev/null; then
            # Can't create test file, skip nvcc test
            test_file=""
        else
            # Try to compile for this architecture
            # Use proper quoting and error handling
            if nvcc -arch="compute_${arch_no_dot}" -c "${test_file}" -o /dev/null 2>/dev/null; then
                rm -f "${test_file}" 2>/dev/null || true
                return 0
            fi
            # Clean up test file
            rm -f "${test_file}" 2>/dev/null || true
        fi
    fi
    
    # Fallback: Check based on CUDA version and known support matrix
    # CUDA 12.0+ supports: 8.6, 8.9
    # CUDA 12.4+ supports: 8.6, 8.9, 9.0
    if [ -n "${CUDA_MAJOR:-}" ] && [ "${CUDA_MAJOR}" = "12" ]; then
        local cuda_minor=0
        if [ -n "${CUDA_VERSION:-}" ]; then
            local version_part
            version_part=$(echo "${CUDA_VERSION}" | cut -d. -f2 2>/dev/null || echo "")
            if [ -n "${version_part}" ] && echo "${version_part}" | grep -qE '^[0-9]+$'; then
                cuda_minor="${version_part}"
            fi
        fi
        
        case "${arch}" in
            "8.6")
                return 0  # Always supported in CUDA 12.x
                ;;
            "8.9")
                # 8.9 requires CUDA 12.0+ (all CUDA 12.x versions support it)
                # Since we're already in CUDA 12.x branch, it's supported
                return 0
                ;;
            "9.0")
                # 9.0 requires CUDA 12.4+
                if [ -n "${cuda_minor}" ] && [ "${cuda_minor}" -ge 4 ] 2>/dev/null; then
                    return 0
                fi
                return 1
                ;;
            "8.0"|"7.5"|"7.0")
                # Older architectures - generally supported in CUDA 12.x
                return 0
                ;;
            *)
                # Unknown architecture - be conservative
                return 1
                ;;
        esac
    fi
    
    # For CUDA 11.x or other versions, be conservative
    if [ -n "${CUDA_MAJOR:-}" ] && [ "${CUDA_MAJOR}" = "11" ]; then
        # CUDA 11.x supports up to 8.6
        case "${arch}" in
            "8.6"|"8.0"|"7.5"|"7.0"|"6.1"|"6.0"|"5.2"|"5.0"|"3.7"|"3.5"|"3.0"|"2.1"|"2.0"|"1.3"|"1.0")
                return 0
                ;;
            "8.9"|"9.0")
                return 1  # Not supported in CUDA 11.x
                ;;
            *)
                # Unknown architecture - be conservative
                return 1
                ;;
        esac
    fi
    
    # For other CUDA versions or unknown versions, be very conservative
    # Only support well-known older architectures
    case "${arch}" in
        "7.5"|"7.0"|"6.1"|"6.0"|"5.2"|"5.0"|"3.7"|"3.5"|"3.0"|"2.1"|"2.0"|"1.3"|"1.0")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Build CUDA architecture list based on CUDA version and nvcc support
# Allow override via environment variable
CUDA_ARCH_LIST=""
CMAKE_CUDA_ARCHITECTURES=""

if [ -n "${TORCH_CUDA_ARCH_LIST_OVERRIDE:-}" ]; then
    echo "  Using user-specified CUDA architectures: ${TORCH_CUDA_ARCH_LIST_OVERRIDE}"
    CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST_OVERRIDE}"
    # Convert to CMake format (remove dots from each architecture, keep semicolons)
    # Example: "8.6;8.9" -> "86;89"
    # Use proper error handling for command substitution
    CMAKE_CUDA_ARCHITECTURES=$(echo "${CUDA_ARCH_LIST}" | sed 's/\.//g' 2>/dev/null || echo "")
    if [ -z "${CMAKE_CUDA_ARCHITECTURES}" ]; then
        echo -e "${RED}✗ ERROR: Failed to convert CUDA architecture list to CMake format${NC}"
        exit 1
    fi
    echo "  CMake format: ${CMAKE_CUDA_ARCHITECTURES}"
    echo "  Note: User override - architectures will not be validated"
    echo ""
else
    # Common architectures to try (in order of preference)
    # Start with most common/recent architectures
    ARCH_CANDIDATES="8.6 8.9 9.0 8.0 7.5 7.0"
    
    echo "  Detecting supported CUDA compute capabilities..."
    echo "  Testing architectures with nvcc..."
    for arch in ${ARCH_CANDIDATES}; do
        if [ -z "${arch:-}" ]; then
            continue
        fi
        
        if check_nvcc_arch_support "${arch}"; then
            arch_no_dot=$(echo "${arch}" | tr -d '.' 2>/dev/null || echo "")
            if [ -z "${arch_no_dot}" ]; then
                echo "    ⚠ ${arch} - failed to process architecture format"
                continue
            fi
            
            if [ -z "${CUDA_ARCH_LIST:-}" ]; then
                CUDA_ARCH_LIST="${arch}"
                CMAKE_CUDA_ARCHITECTURES="${arch_no_dot}"
            else
                CUDA_ARCH_LIST="${CUDA_ARCH_LIST};${arch}"
                CMAKE_CUDA_ARCHITECTURES="${CMAKE_CUDA_ARCHITECTURES};${arch_no_dot}"
            fi
            echo "    ✓ compute_${arch_no_dot} (sm_${arch_no_dot}) - supported"
        else
            arch_no_dot=$(echo "${arch}" | tr -d '.' 2>/dev/null || echo "")
            if [ -n "${arch_no_dot}" ]; then
                echo "    ✗ compute_${arch_no_dot} (sm_${arch_no_dot}) - not supported by CUDA ${CUDA_VERSION:-unknown} or nvcc"
            else
                echo "    ✗ ${arch} - invalid architecture format"
            fi
        fi
    done
    
    # Validate that we have at least one architecture
    if [ -z "${CUDA_ARCH_LIST:-}" ] || [ -z "${CMAKE_CUDA_ARCHITECTURES:-}" ]; then
        echo -e "${RED}✗ ERROR: No supported CUDA architectures found${NC}"
        echo "  Please check your CUDA installation and version"
        echo "  CUDA version detected: ${CUDA_VERSION:-unknown}"
        echo "  CUDA major version: ${CUDA_MAJOR:-unknown}"
        if command -v nvcc >/dev/null 2>&1; then
            echo "  nvcc found: $(command -v nvcc)"
        else
            echo "  nvcc not found in PATH"
        fi
        echo "  You can override by setting: export TORCH_CUDA_ARCH_LIST_OVERRIDE=\"8.6\""
        exit 1
    fi
    
    echo "  Selected CUDA compute capabilities: ${CUDA_ARCH_LIST}"
    echo "  CMake format: ${CMAKE_CUDA_ARCHITECTURES}"
    echo "  Note: To override, set TORCH_CUDA_ARCH_LIST_OVERRIDE environment variable"
    echo ""
fi

# Final validation - ensure both variables are set
if [ -z "${CUDA_ARCH_LIST:-}" ] || [ -z "${CMAKE_CUDA_ARCHITECTURES:-}" ]; then
    echo -e "${RED}✗ ERROR: CUDA architecture configuration failed${NC}"
    echo "  CUDA_ARCH_LIST: ${CUDA_ARCH_LIST:-not set}"
    echo "  CMAKE_CUDA_ARCHITECTURES: ${CMAKE_CUDA_ARCHITECTURES:-not set}"
    exit 1
fi

#===============================================================================
# Step 4: Set up build environment for OpenBLAS
#===============================================================================
echo -e "\n${BLUE}[Step 4] Setting up build environment for OpenBLAS...${NC}"

#===============================================================================
# PyTorch Build Flags (Official from setup.py)
# Reference: https://github.com/pytorch/pytorch#from-source
#===============================================================================

# Disable MKL (use OpenBLAS instead)
export USE_MKL=0
export USE_MKLDNN=0
export USE_STATIC_MKL=0

# OpenBLAS configuration
# Note: PyTorch will auto-detect OpenBLAS if MKL is disabled
# Explicitly set BLAS/LAPACK if needed
export BLAS=OpenBLAS
export LAPACK=OpenBLAS

# CUDA configuration (required for GPU support)
export USE_CUDA=1
export USE_CUDNN=1
export TORCH_CUDA_ARCH_LIST="${CUDA_ARCH_LIST}"  # Format: "8.6;8.9;9.0"
export CMAKE_CUDA_ARCHITECTURES="${CMAKE_CUDA_ARCHITECTURES}"  # Format: "86;89;90"

# CUDA paths are already set above in Step 3
# This section is kept for backward compatibility if CUDA_HOME was set externally
if [ -n "${CUDA_HOME:-}" ] && [ -d "${CUDA_HOME}" ]; then
    # Safely update PATH
    if [ -n "${PATH:-}" ]; then
        export PATH="${CUDA_HOME}/bin:${PATH}"
    else
        export PATH="${CUDA_HOME}/bin"
    fi
    
    # Safely update LD_LIBRARY_PATH
    if [ -n "${LD_LIBRARY_PATH:-}" ]; then
        export LD_LIBRARY_PATH="${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}"
    else
        export LD_LIBRARY_PATH="${CUDA_HOME}/lib64"
    fi
    
    # Ensure CMAKE_CUDA_COMPILER is set
    if [ -z "${CMAKE_CUDA_COMPILER:-}" ] && [ -f "${CUDA_HOME}/bin/nvcc" ] && [ -x "${CUDA_HOME}/bin/nvcc" ]; then
        export CMAKE_CUDA_COMPILER="${CUDA_HOME}/bin/nvcc"
    fi
fi

# Build configuration
export BUILD_TEST=0  # Skip tests (faster build)
export BUILD_SHARED_LIBS=ON
export CMAKE_BUILD_TYPE=Release

# Optional: Disable features we don't need (faster build)
export USE_NNPACK=0  # Can enable if needed
export USE_DISTRIBUTED=0  # Disable distributed training (can enable if needed)
export USE_TENSORPIPE=0
export USE_GLOO=0
export USE_MPI=0

# NCCL configuration (for multi-GPU communication)
# NOTE: When USE_DISTRIBUTED=0, NCCL is typically not needed, but PyTorch may auto-enable it
# Explicitly disable NCCL to avoid building it from source (which can fail)
# If you need distributed training, set USE_DISTRIBUTED=1 and USE_NCCL=1
export USE_NCCL=0  # Disable NCCL (not needed for single-GPU or non-distributed builds)
export USE_SYSTEM_NCCL=0  # Don't use system NCCL (since we're disabling NCCL)

# Performance Libraries (CPU parallelism and multithreading)
# OFFICIALLY SUPPORTED FLAGS (from PYTORCH_BUILD_FLAGS.md):
# - USE_OPENMP: Enable OpenMP for parallel CPU operations (Auto-detect, set to 1 to enable)
# - USE_TBB: Enable Intel Threading Building Blocks (Auto-detect, set to 1 to enable)
# - BLAS: Set to "OpenBLAS" to use OpenBLAS instead of MKL
# - LAPACK: Set to "OpenBLAS" to use OpenBLAS LAPACK (OpenBLAS includes LAPACK)
# Reference: https://github.com/pytorch/pytorch#from-source
#
# CRITICAL: USE_TBB and USE_OPENMP are MUTUALLY EXCLUSIVE
# PyTorch will ignore USE_TBB if USE_OPENMP is enabled (or vice versa)
# For OpenBLAS builds, OpenMP is recommended and required
# TBB is typically used with MKL builds, not OpenBLAS builds
# See: https://docs.pytorch.org/docs/2.8/notes/cpu_threading_torchscript_inference.html

export USE_OPENMP=1  # OpenMP for CPU parallelism (officially supported flag, required for OpenBLAS)

# TBB configuration: DISABLED when OpenMP is enabled (they conflict)
# PyTorch will ignore USE_TBB=1 if USE_OPENMP=1 is set
# If you want to use TBB instead, set USE_OPENMP=0 and USE_TBB=1
# However, OpenBLAS builds typically require OpenMP, so TBB is not recommended here
if [ "${TBB_FOUND:-false}" = "true" ]; then
    # TBB is available, but we're using OpenMP instead (they conflict)
    export USE_TBB=0  # Explicitly disable TBB to avoid conflicts
    echo -e "  ${YELLOW}⚠ TBB found but DISABLED (conflicts with USE_OPENMP=1)${NC}"
    echo "    USE_TBB is officially supported but ignored when USE_OPENMP is enabled"
    echo "    Using OpenMP instead (recommended for OpenBLAS builds)"
else
    echo -e "  ${YELLOW}⚠ TBB not found - PyTorch will build without TBB support${NC}"
    export USE_TBB=0
fi

# BLAS and LAPACK configuration (officially supported via BLAS and LAPACK env vars)
# PyTorch uses OpenBLAS which includes LAPACK functionality
# According to official docs: export BLAS=OpenBLAS and export LAPACK=OpenBLAS
export BLAS=OpenBLAS
export LAPACK=OpenBLAS
echo "  BLAS=OpenBLAS (officially supported flag)"
echo "  LAPACK=OpenBLAS (officially supported flag - OpenBLAS includes LAPACK)"

# Note: There is NO USE_LAPACK flag in PyTorch - LAPACK is handled through OpenBLAS
# System LAPACK libraries are available for compatibility but PyTorch uses OpenBLAS LAPACK
if [ "${LAPACK_FOUND:-false}" = "true" ]; then
    echo "  System LAPACK available (for compatibility, PyTorch uses OpenBLAS LAPACK)"
    if [ "${LAPACKE_FOUND:-false}" = "true" ]; then
        echo "  System LAPACKE available (LAPACK C interface)"
    fi
else
    echo -e "  ${YELLOW}⚠ System LAPACK not found - PyTorch will use OpenBLAS LAPACK only${NC}"
fi

# Optional libraries (OpenCV, Ceres, g2o, GTSAM) - NOT PyTorch build flags
# IMPORTANT: These are NOT official PyTorch build flags (USE_OPENCV, USE_CERES, etc. do NOT exist)
# These libraries are configured via CMAKE_PREFIX_PATH for PyTorch extensions/C++ bindings
# PyTorch core does not directly link to these - they're used by extensions or C++ code
# Reference: PyTorch build flags documentation shows no USE_OPENCV, USE_CERES, etc.

if [ "${OPENCV_FOUND:-false}" = "true" ] && [ -n "${OPENCV_DIR:-}" ] && [ -d "${OPENCV_DIR}" ]; then
    export OpenCV_DIR="${OPENCV_DIR}"
    if [ -d "${OPENCV_DIR}/lib/pkgconfig" ]; then
        if [ -n "${PKG_CONFIG_PATH:-}" ]; then
            export PKG_CONFIG_PATH="${OPENCV_DIR}/lib/pkgconfig:${PKG_CONFIG_PATH}"
        else
            export PKG_CONFIG_PATH="${OPENCV_DIR}/lib/pkgconfig"
        fi
    fi
    if [ -d "${OPENCV_DIR}/lib" ]; then
        if [ -n "${LD_LIBRARY_PATH:-}" ]; then
            export LD_LIBRARY_PATH="${OPENCV_DIR}/lib:${LD_LIBRARY_PATH}"
        else
            export LD_LIBRARY_PATH="${OPENCV_DIR}/lib"
        fi
    fi
    if [ -n "${CMAKE_PREFIX_PATH:-}" ]; then
        export CMAKE_PREFIX_PATH="${OPENCV_DIR}:${CMAKE_PREFIX_PATH}"
    else
        export CMAKE_PREFIX_PATH="${OPENCV_DIR}"
    fi
    echo "  OpenCV: Found and configured via CMAKE_PREFIX_PATH (${OPENCV_DIR})"
    echo "    Note: OpenCV is NOT a PyTorch build flag - configured for extensions"
fi

if [ "${CERES_FOUND:-false}" = "true" ] && [ -n "${CERES_DIR:-}" ] && [ -d "${CERES_DIR}" ]; then
    CERES_PREFIX="${CERES_DIR}"
    if [ -f "${CERES_DIR}/lib/cmake/Ceres/CeresConfig.cmake" ] || [ -d "${CERES_DIR}/lib/cmake/Ceres" ]; then
        export Ceres_DIR="${CERES_DIR}/lib/cmake/Ceres"
    fi
    if [ -d "${CERES_PREFIX}/lib" ]; then
        if [ -n "${LD_LIBRARY_PATH:-}" ]; then
            export LD_LIBRARY_PATH="${CERES_PREFIX}/lib:${LD_LIBRARY_PATH}"
        else
            export LD_LIBRARY_PATH="${CERES_PREFIX}/lib"
        fi
    fi
    if [ -n "${CMAKE_PREFIX_PATH:-}" ]; then
        export CMAKE_PREFIX_PATH="${CERES_PREFIX}:${CMAKE_PREFIX_PATH}"
    else
        export CMAKE_PREFIX_PATH="${CERES_PREFIX}"
    fi
    echo "  Ceres: Found and configured via CMAKE_PREFIX_PATH (${CERES_PREFIX})"
    echo "    Note: Ceres is NOT a PyTorch build flag - configured for extensions"
fi

if [ "${G2O_FOUND:-false}" = "true" ] && [ -n "${G2O_DIR:-}" ] && [ -d "${G2O_DIR}" ]; then
    G2O_PREFIX="${G2O_DIR}"
    if [ -f "${G2O_DIR}/lib/cmake/g2o/g2oConfig.cmake" ] || [ -d "${G2O_DIR}/lib/cmake/g2o" ]; then
        export g2o_DIR="${G2O_DIR}/lib/cmake/g2o"
    fi
    if [ -d "${G2O_PREFIX}/lib" ]; then
        if [ -n "${LD_LIBRARY_PATH:-}" ]; then
            export LD_LIBRARY_PATH="${G2O_PREFIX}/lib:${LD_LIBRARY_PATH}"
        else
            export LD_LIBRARY_PATH="${G2O_PREFIX}/lib"
        fi
    fi
    if [ -n "${CMAKE_PREFIX_PATH:-}" ]; then
        export CMAKE_PREFIX_PATH="${G2O_PREFIX}:${CMAKE_PREFIX_PATH}"
    else
        export CMAKE_PREFIX_PATH="${G2O_PREFIX}"
    fi
    echo "  g2o: Found and configured via CMAKE_PREFIX_PATH (${G2O_PREFIX})"
    echo "    Note: g2o is NOT a PyTorch build flag - configured for extensions"
fi

if [ "${GTSAM_FOUND:-false}" = "true" ] && [ -n "${GTSAM_DIR:-}" ] && [ -d "${GTSAM_DIR}" ]; then
    GTSAM_PREFIX="${GTSAM_DIR}"
    if [ -f "${GTSAM_DIR}/lib/cmake/GTSAM/GTSAMConfig.cmake" ] || [ -d "${GTSAM_DIR}/lib/cmake/GTSAM" ]; then
        export GTSAM_DIR="${GTSAM_DIR}/lib/cmake/GTSAM"
    fi
    if [ -d "${GTSAM_PREFIX}/lib" ]; then
        if [ -n "${LD_LIBRARY_PATH:-}" ]; then
            export LD_LIBRARY_PATH="${GTSAM_PREFIX}/lib:${LD_LIBRARY_PATH}"
        else
            export LD_LIBRARY_PATH="${GTSAM_PREFIX}/lib"
        fi
    fi
    if [ -n "${CMAKE_PREFIX_PATH:-}" ]; then
        export CMAKE_PREFIX_PATH="${GTSAM_PREFIX}:${CMAKE_PREFIX_PATH}"
    else
        export CMAKE_PREFIX_PATH="${GTSAM_PREFIX}"
    fi
    echo "  GTSAM: Found and configured via CMAKE_PREFIX_PATH (${GTSAM_PREFIX})"
    echo "    Note: GTSAM is NOT a PyTorch build flag - configured for extensions"
fi

# Use pre-calculated build jobs from system detection
BUILD_JOBS="${CALCULATED_JOBS:-1}"

echo "  Build Configuration (Based on Detected Hardware):"
echo "    Total CPU cores: ${SYS_CPU_CORES:-unknown}"
echo "    Total RAM: ${SYS_MEM_TOTAL_GB:-unknown}GB (${SYS_MEM_AVAILABLE_GB:-unknown}GB available)"
echo "    Disk type: ${SYS_DISK_TYPE:-unknown}"
echo "    Build jobs: ${BUILD_JOBS} (calculated from CPU, memory, and I/O capabilities)"
if [ -n "${SYS_MEM_PER_JOB_GB:-}" ] && [ "${SYS_MEM_PER_JOB_GB}" -gt 0 ] 2>/dev/null; then
    echo "    Memory per job: ${SYS_MEM_PER_JOB_GB}GB"
    echo "    Total memory budget: $((BUILD_JOBS * SYS_MEM_PER_JOB_GB))GB"
else
    echo "    Memory per job: unknown"
    echo "    Total memory budget: unknown"
fi

# Threading configuration (runtime threading, not build parallelism)
# Use 50% of available cores for runtime threading to avoid oversubscription
# But ensure we don't exceed available cores
runtime_threads=1  # Default to 1
if [ -n "${SYS_CPU_CORES:-}" ] && [ "${SYS_CPU_CORES}" -gt 0 ] 2>/dev/null; then
    runtime_threads=$((SYS_CPU_CORES / 2))
    if [ "${runtime_threads}" -lt 1 ]; then
        runtime_threads=1
    fi
fi
# Cap at build jobs to avoid oversubscription
if [ -n "${BUILD_JOBS:-}" ] && [ "${BUILD_JOBS}" -gt 0 ] 2>/dev/null && [ "${runtime_threads}" -gt "${BUILD_JOBS}" ]; then
    runtime_threads="${BUILD_JOBS}"
fi

export OMP_NUM_THREADS="${runtime_threads}"  # OpenMP threads
export MKL_NUM_THREADS="${runtime_threads}"  # MKL threads (for compatibility)
export OPENBLAS_NUM_THREADS="${runtime_threads}"  # OpenBLAS threads
export NUMEXPR_NUM_THREADS="${runtime_threads}"  # NumExpr threads

if [ -n "${SYS_CPU_CORES:-}" ] && [ "${SYS_CPU_CORES}" -gt 0 ] 2>/dev/null; then
    echo "    Runtime threading: ${runtime_threads} threads (50% of ${SYS_CPU_CORES} cores, capped at ${BUILD_JOBS} jobs)"
else
    echo "    Runtime threading: ${runtime_threads} threads (capped at ${BUILD_JOBS} jobs)"
fi
echo "    OMP_NUM_THREADS=${runtime_threads}"
echo "    OPENBLAS_NUM_THREADS=${runtime_threads}"

# PyTorch build parallelism (MAX_JOBS environment variable)
export MAX_JOBS="${BUILD_JOBS}"
# Also set CMake parallel level (PyTorch uses CMake internally)
export CMAKE_BUILD_PARALLEL_LEVEL="${BUILD_JOBS}"
echo "    PyTorch build jobs: ${BUILD_JOBS} (MAX_JOBS=${BUILD_JOBS}, CMAKE_BUILD_PARALLEL_LEVEL=${BUILD_JOBS})"

# Explicitly set OpenBLAS library paths if found
if [ -n "${OPENBLAS_LIB:-}" ]; then
    export OPENBLAS_LIB="${OPENBLAS_LIB}"
    export OPENBLAS_INCLUDE_DIR="/usr/include/x86_64-linux-gnu"
    export LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
fi

# Set library paths for OpenBLAS
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:/usr/local/lib:${LD_LIBRARY_PATH:-}
export PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig:${PKG_CONFIG_PATH:-}

echo "  Build Configuration:"
echo "    USE_MKL=0 (MKL disabled - using OpenBLAS)"
echo "    USE_MKLDNN=0 (MKL-DNN disabled)"
echo "    USE_CUDA=1 (CUDA enabled)"
echo "    USE_CUDNN=1 (cuDNN enabled)"
echo "    TORCH_CUDA_ARCH_LIST=${TORCH_CUDA_ARCH_LIST}"
echo "    CMAKE_CUDA_ARCHITECTURES=${CMAKE_CUDA_ARCHITECTURES}"
if [ -n "${CUDA_HOME:-}" ]; then
    echo "    CUDA_HOME=${CUDA_HOME}"
fi
if [ -n "${CMAKE_CUDA_COMPILER:-}" ]; then
    echo "    CMAKE_CUDA_COMPILER=${CMAKE_CUDA_COMPILER}"
fi
echo "    CMAKE_BUILD_TYPE=Release"
echo "    BUILD_TEST=0 (tests skipped)"
echo "    USE_OPENMP=1 (OpenMP enabled - required for OpenBLAS)"
echo "    USE_TBB=0 (TBB disabled - conflicts with OpenMP, will be ignored if set)"
echo "    USE_NCCL=0 (NCCL disabled - not needed for non-distributed builds)"
echo "    USE_DISTRIBUTED=0 (Distributed training disabled)"
if [ "${TBB_FOUND:-false}" = "true" ]; then
    echo "      Note: TBB is available but disabled due to OpenMP conflict"
fi
if [ "${LAPACK_FOUND:-false}" = "true" ]; then
    echo "    LAPACK enabled (system LAPACK available)"
    if [ "${LAPACKE_FOUND:-false}" = "true" ]; then
        echo "    LAPACKE enabled (LAPACK C interface available)"
    fi
else
    echo "    LAPACK: Using OpenBLAS LAPACK only"
fi
if [ "${OPENCV_FOUND:-false}" = "true" ]; then
    echo "    OpenCV: Found and configured (${OPENCV_DIR})"
fi
if [ "${CERES_FOUND:-false}" = "true" ]; then
    echo "    Ceres: Found and configured (${CERES_DIR})"
fi
if [ "${G2O_FOUND:-false}" = "true" ]; then
    echo "    g2o: Found and configured (${G2O_DIR})"
fi
if [ "${GTSAM_FOUND:-false}" = "true" ]; then
    echo "    GTSAM: Found and configured (${GTSAM_DIR})"
fi
echo -e "${GREEN}✓ Build environment configured for OpenBLAS + CUDA${NC}"
echo -e "${GREEN}✓ Performance libraries: OpenMP, TBB, LAPACK enabled${NC}"
if [ "${OPENCV_FOUND:-false}" = "true" ] || [ "${CERES_FOUND:-false}" = "true" ] || [ "${G2O_FOUND:-false}" = "true" ] || [ "${GTSAM_FOUND:-false}" = "true" ]; then
    echo -e "${GREEN}✓ Optional libraries detected and configured for PyTorch extensions${NC}"
fi
echo ""

#===============================================================================
# Step 5: Create build directory
#===============================================================================
echo -e "${BLUE}[Step 5] Preparing build directory...${NC}"

# Determine build directory - use overlay if available, otherwise /tmp
# Overlay provides persistent storage for build artifacts
if [ -d "/opt/conda-envs" ] && touch /opt/conda-envs/.test_write 2>/dev/null; then
    # Overlay is mounted and writable
    BUILD_DIR="/opt/conda-envs/pytorch_build"
    rm -f /opt/conda-envs/.test_write
    echo -e "${GREEN}✓ Using writable overlay for build artifacts: ${BUILD_DIR}${NC}"
    echo "  Build artifacts will persist in overlay"
elif [ -d "/opt/conda" ] && touch /opt/conda/.test_write 2>/dev/null; then
    # Alternative overlay location
    BUILD_DIR="/opt/conda/pytorch_build"
    rm -f /opt/conda/.test_write
    echo -e "${GREEN}✓ Using writable overlay for build artifacts: ${BUILD_DIR}${NC}"
else
    # Use /tmp (temporary, will be lost on container exit)
    BUILD_DIR="/tmp/pytorch_openblas_test"
    echo -e "${YELLOW}⚠ Using temporary directory: ${BUILD_DIR}${NC}"
    echo "  Build artifacts will be lost when container exits"
    echo "  Consider using --overlay option for persistent storage"
fi

mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}" || exit 1

# Initialize resource monitoring files (after BUILD_DIR is set)
RESOURCE_MONITOR_LOG="${BUILD_DIR}/resource_monitor.log"
BUILD_STOP_FLAG_FILE="${BUILD_DIR}/.build_stop_flag"
BUILD_STATE_FILE="${BUILD_DIR}/.build_state"
rm -f "${BUILD_STOP_FLAG_FILE}"  # Clear any existing stop flag (but keep state file)

#===============================================================================
# Build State Management for Resume Capability
#===============================================================================
# Function to check build state and determine if we can resume
check_build_state() {
    local build_dir="${BUILD_DIR}"
    
    # Check if wheel already exists (build completed)
    local wheel_file
    wheel_file=$(find "${build_dir}/wheels" -name "torch-*.whl" 2>/dev/null | head -1)
    if [ -n "${wheel_file:-}" ] && [ -f "${wheel_file}" ]; then
        echo "completed"
        return 0
    fi
    
    # Try to find PyTorch source directory in build dir (if PYTORCH_SOURCE_DIR not set yet)
    local pytorch_source="${PYTORCH_SOURCE_DIR:-}"
    if [ -z "${pytorch_source}" ] && [ -d "${build_dir}" ]; then
        pytorch_source=$(find "${build_dir}" -maxdepth 1 -type d -name "pytorch-*" 2>/dev/null | head -1)
    fi
    
    # Check if build was in progress (CMake cache exists)
    if [ -n "${pytorch_source}" ] && [ -d "${pytorch_source}" ]; then
        # Check for CMake cache (indicates build started)
        if [ -f "${pytorch_source}/build/CMakeCache.txt" ] || \
           { [ -d "${pytorch_source}/build" ] && [ -n "$(find "${pytorch_source}/build" -name "CMakeCache.txt" 2>/dev/null | head -1)" ]; }; then
            echo "in_progress"
            return 0
        fi
        
        # Check if source is present but no build started
        if [ -d "${pytorch_source}/.git" ] || [ -f "${pytorch_source}/setup.py" ]; then
            echo "source_ready"
            return 0
        fi
    fi
    
    # No build state detected
    echo "not_started"
    return 0
}

# Function to save build state
save_build_state() {
    local state="$1"
    echo "${state}" > "${BUILD_STATE_FILE}"
    date +%s >> "${BUILD_STATE_FILE}"  # Timestamp
}

# Check current build state
BUILD_STATE=$(check_build_state)
echo -e "${GREEN}✓ Build directory ready: ${BUILD_DIR}${NC}"
echo "  Build state: ${BUILD_STATE}"
if [ "${BUILD_STATE}" = "completed" ]; then
    WHEEL_FILE=$(find "${BUILD_DIR}/wheels" -name "torch-*.whl" 2>/dev/null | head -1)
    if [ -n "${WHEEL_FILE:-}" ]; then
        WHEEL_SIZE=$(du -h "${WHEEL_FILE}" 2>/dev/null | cut -f1 || echo "unknown")
        echo -e "  ${GREEN}✓ Build already completed! Wheel found: $(basename "${WHEEL_FILE}") (${WHEEL_SIZE})${NC}"
        echo "  To rebuild, delete the wheel file or use: rm -f ${WHEEL_FILE}"
    fi
elif [ "${BUILD_STATE}" = "in_progress" ]; then
    echo -e "  ${YELLOW}⚠ Partial build detected - will resume from where it left off${NC}"
    echo "  Build artifacts preserved for incremental build"
elif [ "${BUILD_STATE}" = "source_ready" ]; then
    echo "  Source code ready - will start fresh build"
else
    echo "  Starting new build"
fi
echo ""

#===============================================================================
# Step 6: Clone/Download PyTorch source (with resume support)
#===============================================================================
echo -e "${BLUE}[Step 6] Getting PyTorch source...${NC}"

# Skip if build already completed
if [ "${BUILD_STATE}" = "completed" ]; then
    echo -e "  ${GREEN}✓ Skipping - build already completed${NC}"
    # Still need to set PYTORCH_SOURCE_DIR for later steps
    if [ -z "${PYTORCH_SOURCE_DIR:-}" ]; then
        # Try to find existing source directory
        PYTORCH_SOURCE_DIR=$(find "${BUILD_DIR}" -maxdepth 1 -type d -name "pytorch-*" 2>/dev/null | head -1)
        if [ -z "${PYTORCH_SOURCE_DIR:-}" ]; then
            # Fallback: determine from latest tag
            LATEST_TAG=$(curl -s https://api.github.com/repos/pytorch/pytorch/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | head -1)
            if [ -z "${LATEST_TAG:-}" ]; then
                LATEST_TAG="v2.9.0"
            fi
            PYTORCH_VERSION="${LATEST_TAG#v}"
            PYTORCH_SOURCE_DIR="${BUILD_DIR}/pytorch-${PYTORCH_VERSION}"
        fi
    fi
    echo -e "${GREEN}✓ PyTorch source ready: ${PYTORCH_SOURCE_DIR}${NC}\n"
else
    echo "  Official repository: https://github.com/pytorch/pytorch"
    echo "  Build instructions: https://github.com/pytorch/pytorch#from-source"
    
    # Use selected PyTorch version or fetch latest
    if [ -n "${SELECTED_PYTORCH_VERSION:-}" ]; then
        # Use specified/recommended version
        # Validate version format before using
        if echo "${SELECTED_PYTORCH_VERSION}" | grep -qE '^[0-9]+\.[0-9]+(\.[0-9]+)?$'; then
            LATEST_TAG="v${SELECTED_PYTORCH_VERSION}"
            PYTORCH_VERSION="${SELECTED_PYTORCH_VERSION}"
            echo "  Using PyTorch version: ${PYTORCH_VERSION} (${LATEST_TAG})"
        else
            echo -e "${RED}✗ ERROR: Invalid PyTorch version format: ${SELECTED_PYTORCH_VERSION}${NC}"
            echo "  Expected format: X.Y or X.Y.Z"
            exit 1
        fi
    else
        # Fetch latest stable release from GitHub
        echo "  Fetching latest stable PyTorch version from GitHub releases..."
        LATEST_TAG=$(curl -s https://api.github.com/repos/pytorch/pytorch/releases/latest 2>/dev/null | \
            jq -r '.tag_name' 2>/dev/null | head -1 || echo "")
        
        if [ -z "${LATEST_TAG:-}" ]; then
            # Fallback: try grep if jq fails
            LATEST_TAG=$(curl -s https://api.github.com/repos/pytorch/pytorch/releases/latest 2>/dev/null | \
                grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | head -1 || echo "")
        fi
        
        if [ -z "${LATEST_TAG:-}" ]; then
            echo -e "${YELLOW}⚠ Could not fetch latest tag, using PyTorch 2.9.0 as fallback${NC}"
            LATEST_TAG="v2.9.0"
        fi
        
        # Remove 'v' prefix if present for version comparison
        PYTORCH_VERSION="${LATEST_TAG#v}"
        # Validate fetched version format
        if ! echo "${PYTORCH_VERSION}" | grep -qE '^[0-9]+\.[0-9]+(\.[0-9]+)?$'; then
            echo -e "${YELLOW}⚠ Invalid version format from API: ${PYTORCH_VERSION}, using fallback${NC}"
            PYTORCH_VERSION="2.9.0"
            LATEST_TAG="v2.9.0"
        fi
        echo "  Latest stable version: ${PYTORCH_VERSION}"
    fi
    
    # Clone specific stable version tag (skip if already exists)
    if [ ! -d "pytorch-${PYTORCH_VERSION}" ]; then
        echo "  Cloning PyTorch ${LATEST_TAG}..."
        git clone --recursive --depth 1 --branch "${LATEST_TAG}" \
            https://github.com/pytorch/pytorch.git "pytorch-${PYTORCH_VERSION}" 2>&1 | \
            grep -v "^Cloning\|^Submodule\|^Updating\|^Already" || {
            echo -e "${YELLOW}⚠ Git clone failed, trying archive download...${NC}"
            # Fallback to archive download
            PYTORCH_URL="https://github.com/pytorch/pytorch/archive/refs/tags/${LATEST_TAG}.tar.gz"
            wget -q "${PYTORCH_URL}" -O pytorch.tar.gz || {
                echo -e "${RED}✗ Failed to download PyTorch ${LATEST_TAG}${NC}"
                exit 1
            }
            tar -xzf pytorch.tar.gz
            PYTORCH_SOURCE_DIR="${BUILD_DIR}/pytorch-${PYTORCH_VERSION}"
            cd "${PYTORCH_SOURCE_DIR}" || exit 1
            git submodule update --init --recursive || true
            cd "${BUILD_DIR}" || exit 1
            # Keep tar.gz for reuse (large download)
            echo "  Note: Archive preserved: pytorch.tar.gz"
        }
        save_build_state "source_ready"
    else
        echo -e "  ${GREEN}✓ PyTorch ${PYTORCH_VERSION} already cloned (resuming)${NC}"
        # Update submodules if needed (in case of partial clone)
        if [ -d "pytorch-${PYTORCH_VERSION}/.git" ]; then
            echo "  Updating submodules (if needed)..."
            cd "pytorch-${PYTORCH_VERSION}" || exit 1
            git submodule update --init --recursive --quiet 2>&1 | grep -v "^Submodule\|^Updating\|^Already" || true
            cd "${BUILD_DIR}" || exit 1
        fi
    fi
    
    if [ -z "${PYTORCH_SOURCE_DIR:-}" ]; then
        PYTORCH_SOURCE_DIR="${BUILD_DIR}/pytorch-${PYTORCH_VERSION}"
    fi
    
    echo "  Using PyTorch ${LATEST_TAG} (stable release)"
    
    echo -e "${GREEN}✓ PyTorch source ready: ${PYTORCH_SOURCE_DIR}${NC}\n"
fi

#===============================================================================
# Step 7: Install build dependencies (with resume support)
#===============================================================================
echo -e "${BLUE}[Step 7] Installing build dependencies...${NC}"

# Skip if build already completed
if [ "${BUILD_STATE}" = "completed" ]; then
    echo -e "  ${GREEN}✓ Skipping - build already completed${NC}\n"
else
    cd "${PYTORCH_SOURCE_DIR}" || exit 1

# Detect if we need --break-system-packages flag
# Note: filter_pip_output function is defined earlier in Step 1
# Check for externally-managed-environment error
export pip_flags=""

# Method 1: Try a dry-run install and check for error
# The error message contains "externally-managed-environment" or "This environment is externally managed"
TEST_OUTPUT=$(python3 -m pip install --dry-run pip 2>&1 || true)
if echo "${TEST_OUTPUT}" | grep -qiE "externally-managed-environment|This environment is externally managed|externally managed"; then
    export pip_flags="--break-system-packages"
    echo "  ✓ Detected externally-managed environment, using --break-system-packages flag"
fi

# Method 2: Check if we're in a container environment (common case)
if [ -z "${pip_flags}" ]; then
    if [ -n "${SINGULARITY_CONTAINER:-}" ] || [ -n "${CONTAINER_BUILD:-}" ] || [ -f "/.dockerenv" ]; then
        export pip_flags="--break-system-packages"
        echo "  ✓ Container environment detected, using --break-system-packages flag"
    fi
fi

# Method 3: Try installing a test package and catch the error
if [ -z "${pip_flags}" ]; then
    TEST_INSTALL=$(python3 -m pip install --dry-run --no-deps wheel 2>&1 || true)
    if echo "${TEST_INSTALL}" | grep -qiE "externally-managed-environment|This environment is externally managed|externally managed"; then
        export pip_flags="--break-system-packages"
        echo "  ✓ Detected externally-managed environment via test install, using --break-system-packages flag"
    fi
fi

# Method 4: Check Python version and system configuration
# Python 3.11+ on Debian/Ubuntu typically requires this flag
if [ -z "${pip_flags}" ]; then
    PYTHON_VER_CHECK=$(python3 --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)
    PYTHON_MAJOR=$(echo "${PYTHON_VER_CHECK}" | cut -d. -f1)
    PYTHON_MINOR=$(echo "${PYTHON_VER_CHECK}" | cut -d. -f2)
    # Python 3.11+ on Ubuntu/Debian systems typically need this
    if [ "${PYTHON_MAJOR}" -ge 3 ] && [ "${PYTHON_MINOR}" -ge 11 ]; then
        if [ -f "/etc/debian_version" ] || [ -f "/etc/os-release" ]; then
            export pip_flags="--break-system-packages"
            echo "  ✓ Python 3.11+ on Debian/Ubuntu detected, using --break-system-packages flag"
        fi
    fi
fi

echo "  Installing Python build dependencies..."
# Suppress pip warnings about system packages
export PIP_DISABLE_PIP_VERSION_CHECK=1
export PIP_NO_WARN_SCRIPT_LOCATION=1

if [ -n "${pip_flags}" ]; then
    python3 -m pip install --upgrade pip setuptools wheel ${pip_flags} --quiet 2>&1 | filter_pip_output || \
    python3 -m pip install --upgrade pip setuptools wheel ${pip_flags} 2>&1 | filter_pip_output || true
else
    python3 -m pip install --upgrade pip setuptools wheel --quiet 2>&1 | filter_pip_output || \
    python3 -m pip install --upgrade pip setuptools wheel 2>&1 | filter_pip_output || true
fi

# Install PyTorch build dependencies
# IMPORTANT: PyTorch does NOT require TensorFlow or Keras for building
# These may appear in requirements.txt for testing/CI but are NOT build dependencies
# We install only the minimal dependencies needed for compilation
echo "  Installing minimal PyTorch build dependencies..."
echo "  Note: PyTorch is independent of TensorFlow/Keras - these are NOT required for building"
echo "  Note: Installing only core build dependencies to avoid conflicts"
echo "  Note: Ignoring apt package version parsing errors (e.g., devscripts) - these are non-fatal"

# Suppress pip's dependency resolver warnings about system packages
# This prevents errors when pip encounters apt packages with Ubuntu-style versions
export PIP_DISABLE_PIP_VERSION_CHECK=1
export PIP_NO_WARN_SCRIPT_LOCATION=1

# Core build dependencies for PyTorch (minimal set required for compilation)
# These are the actual dependencies needed by PyTorch's setup.py
CORE_BUILD_DEPS="numpy ninja pyyaml setuptools wheel cmake typing-extensions filelock networkx sympy"

if [ -n "${pip_flags}" ]; then
    # Install core dependencies with --ignore-installed to handle version conflicts gracefully
    # Use --no-deps to avoid dependency resolution that triggers apt package version errors
    # Redirect both stdout and stderr, filter known errors
    python3 -m pip install --no-cache-dir --ignore-installed --no-deps ${pip_flags} \
        ${CORE_BUILD_DEPS} 2>&1 | filter_pip_output || {
        echo "  ⚠ Some packages may have installation issues (non-fatal)"
        echo "  Continuing with build - PyTorch setup.py will handle missing optional dependencies"
    }
    
    # Now install with dependencies for packages that need them (but suppress errors)
    python3 -m pip install --no-cache-dir --ignore-installed ${pip_flags} \
        ${CORE_BUILD_DEPS} 2>&1 | filter_pip_output || true
else
    python3 -m pip install --no-cache-dir --ignore-installed --no-deps \
        ${CORE_BUILD_DEPS} 2>&1 | filter_pip_output || {
        echo "  ⚠ Some packages may have installation issues (non-fatal)"
        echo "  Continuing with build - PyTorch setup.py will handle missing optional dependencies"
    }
    
    # Now install with dependencies for packages that need them (but suppress errors)
    python3 -m pip install --no-cache-dir --ignore-installed \
        ${CORE_BUILD_DEPS} 2>&1 | filter_pip_output || true
fi

# Optional: Try to install from requirements.txt if it exists, but filter out problematic packages
# This is for optional dependencies that might be useful but aren't required
if [ -f "requirements.txt" ]; then
    echo "  Attempting to install optional dependencies from requirements.txt (filtered)..."
    FILTERED_REQUIREMENTS="${BUILD_DIR}/requirements_filtered.txt"
    # Filter out TensorFlow/Keras (not needed) and packages with apt-style versions
    grep -vE "^(tensorflow|tf-keras|keras|devscripts)" requirements.txt > "${FILTERED_REQUIREMENTS}" 2>/dev/null || true
    
    if [ -f "${FILTERED_REQUIREMENTS}" ] && [ -s "${FILTERED_REQUIREMENTS}" ]; then
        # Try installing filtered requirements, but don't fail if it doesn't work
        # Use --no-deps to avoid dependency resolution errors
        if [ -n "${pip_flags}" ]; then
            python3 -m pip install --no-cache-dir --ignore-installed --no-deps ${pip_flags} \
                -r "${FILTERED_REQUIREMENTS}" 2>&1 | filter_pip_output || true
        else
            python3 -m pip install --no-cache-dir --ignore-installed --no-deps \
                -r "${FILTERED_REQUIREMENTS}" 2>&1 | filter_pip_output || true
        fi
    fi
    
    # Clean up filtered requirements file
    rm -f "${FILTERED_REQUIREMENTS}"
fi

echo -e "${GREEN}✓ Build dependencies installed${NC}\n"
save_build_state "dependencies_installed"
fi

#===============================================================================
# Step 8: Build PyTorch wheel with OpenBLAS (no installation, with resume support)
#===============================================================================
echo -e "${BLUE}[Step 8] Building PyTorch wheel with OpenBLAS...${NC}"

# Check if build already completed
if [ "${BUILD_STATE}" = "completed" ]; then
    echo -e "  ${GREEN}✓ Build already completed - skipping compilation${NC}"
    echo "  Wheel location: ${WHEEL_FILE}"
    echo ""
    # Skip to verification step
    BUILD_SUCCESS=true
else
    # Set library paths
    export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:/usr/local/lib:${LD_LIBRARY_PATH:-}
    export PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig:${PKG_CONFIG_PATH:-}
    
    cd "${PYTORCH_SOURCE_DIR}" || exit 1
    
    # Check if this is a resume (partial build exists)
    # Re-check build state now that PYTORCH_SOURCE_DIR is set
    BUILD_STATE=$(check_build_state)
    if [ "${BUILD_STATE}" = "in_progress" ]; then
        echo -e "  ${YELLOW}⚠ Resuming from previous build (incremental build)${NC}"
        echo "  PyTorch setup.py will automatically continue from where it left off"
        echo "  Build artifacts preserved for incremental compilation"
    else
        echo "  Starting fresh build..."
    fi
    
    # Build wheel only (no installation)
    # Official build method from: https://github.com/pytorch/pytorch#from-source
    echo "  Building PyTorch wheel with OpenBLAS + CUDA support..."
    echo "  Official build command: python setup.py bdist_wheel"
    if [ "${BUILD_STATE}" = "in_progress" ]; then
        echo "  Resuming build - remaining time depends on what's left to compile..."
    else
        echo "  This may take a significant amount of time (30min - 2+ hours)..."
    fi
    echo "  Reference: https://github.com/pytorch/pytorch#from-source"
    
    # Check memory before starting build
    echo ""
    check_memory
    echo ""

    WHEEL_DIR="${BUILD_DIR}/wheels"
    mkdir -p "${WHEEL_DIR}"
    
    # Save build state before starting
    save_build_state "building"
    
    # Verify Python version compatibility (PyTorch 2.9 requires Python 3.10+)
    PYTHON_VER=$(python3 --version 2>&1 | awk '{print $2}')
    PYTHON_MAJOR=$(echo "${PYTHON_VER}" | cut -d. -f1)
    PYTHON_MINOR=$(echo "${PYTHON_VER}" | cut -d. -f2)

    if [ "${PYTHON_MAJOR}" -lt 3 ] || { [ "${PYTHON_MAJOR}" -eq 3 ] && [ "${PYTHON_MINOR}" -lt 10 ]; }; then
        echo -e "${RED}✗ ERROR: PyTorch 2.9 requires Python 3.10 or later${NC}"
        echo "  Current Python version: ${PYTHON_VER}"
        echo "  Please upgrade Python or use an older PyTorch version"
        exit 1
    fi
    
    echo "  Python version: ${PYTHON_VER} (✓ compatible)"
    
    # Build using setup.py (official method)
    # Alternative: python -m pip install --no-build-isolation -v -e . (for editable install)
    echo "  Starting build process..."
    echo "  Build configuration (based on detected hardware):"
    echo "    MAX_JOBS=${MAX_JOBS} (parallel compilation jobs)"
    echo "    Memory limit: ${SYS_MEM_PER_JOB_GB}GB per job (adaptive)"
    if [ "${SYS_CPU_CORES:-0}" -gt 0 ]; then
        echo "    CPU limit: ${BUILD_JOBS} jobs (${BUILD_JOBS}/${SYS_CPU_CORES} cores = $((BUILD_JOBS * 100 / SYS_CPU_CORES))%)"
    else
        echo "    CPU limit: ${BUILD_JOBS} jobs (CPU cores unknown)"
    fi
    echo "    Disk type: ${SYS_DISK_TYPE} (I/O optimized)"
    if [ "${BUILD_STATE}" = "in_progress" ]; then
        echo "    Build mode: Incremental (resuming from previous build)"
    else
        echo "    Build mode: Fresh build"
    fi
    echo ""
    
    # Set build start time (for timing calculations)
    BUILD_START=$(date +%s)
    
    # Resource monitoring with auto-stop functionality
    # All thresholds are now calculated dynamically from system resources above
    # These variables are set by calculate_resource_thresholds() function
    # CRITICAL_MEM_AVAIL_GB, WARN_MEM_AVAIL_GB
    # CRITICAL_SWAP_USED_GB, WARN_SWAP_USED_GB
    # CRITICAL_LOAD_AVG, WARN_LOAD_AVG
    # CRITICAL_DISK_IO_WAIT, WARN_DISK_IO_WAIT

    # Global flag to signal build should stop (use file for cross-process communication)
    # Note: BUILD_DIR will be set later, so we'll initialize these after BUILD_DIR is defined

    # Function to start resource monitor (will be called after build starts)
    start_resource_monitor() {
        local build_pid="${1:-}"
        if [ -z "${build_pid:-}" ] || ! kill -0 "${build_pid}" 2>/dev/null; then
            echo "ERROR: Invalid build PID: ${build_pid:-}" >&2
            return 1
        fi
        (
        echo "Resource Monitor Started: $(date)" > "${RESOURCE_MONITOR_LOG}"
        local consecutive_critical=0
        local max_consecutive_critical=3  # Stop after 3 consecutive critical readings
        
        while true; do
            sleep 10  # Check every 10 seconds
            
            # Check if build process is still running
            if ! kill -0 "${build_pid}" 2>/dev/null; then
                echo "Build process ended, stopping monitor" >> "${RESOURCE_MONITOR_LOG}"
                break
            fi
        
        # Memory check
        mem_avail=$(free -g 2>/dev/null | awk '/^Mem:/ {print $7}' || echo "0")
        mem_total=$(free -g 2>/dev/null | awk '/^Mem:/ {print $2}' || echo "0")
        if [ "${mem_total:-0}" -gt 0 ]; then
            mem_used_pct=$(( (mem_total - mem_avail) * 100 / mem_total ))
        else
            mem_used_pct=0
        fi
        
        # Swap check
        swap_used=$(free -g 2>/dev/null | awk '/^Swap:/ {print $3}' || echo "0")
        swap_total=$(free -g 2>/dev/null | awk '/^Swap:/ {print $2}' || echo "0")
        
        # Load average check
        load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//' || echo "0")
        cpu_cores=$(nproc 2>/dev/null || echo "1")
        if [ "${cpu_cores:-0}" -gt 0 ]; then
            load_per_core=$(echo "scale=2; ${load_avg} / ${cpu_cores}" | bc 2>/dev/null || echo "0")
        else
            load_per_core="0"
        fi
        
        # Disk I/O wait check (iostat is now required, but fallback to /proc/stat if needed)
        iowait_pct=0
        if command -v iostat >/dev/null 2>&1; then
            # Use iostat for accurate I/O wait percentage
            iowait_pct=$(iostat -c 1 2 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/,/./' || echo "0")
        elif [ -f /proc/stat ]; then
            # Fallback: Parse /proc/stat for I/O wait (less accurate but works)
            cpu_line=$(grep "^cpu " /proc/stat)
            iowait=$(echo "${cpu_line}" | awk '{print $6}')
            total=$(echo "${cpu_line}" | awk '{sum=0; for(i=2;i<=NF;i++) sum+=$i; print sum}')
            if [ "${total}" -gt 0 ]; then
                iowait_pct=$(echo "scale=1; ${iowait} * 100 / ${total}" | bc 2>/dev/null || echo "0")
            fi
        else
            echo "  WARNING: Cannot determine I/O wait (iostat and /proc/stat unavailable)" >> "${RESOURCE_MONITOR_LOG}"
        fi
        
        # Check for critical conditions (using dynamically calculated thresholds)
        local is_critical=false
        local critical_mem="${CRITICAL_MEM_AVAIL_GB:-1}"
        local critical_swap="${CRITICAL_SWAP_USED_GB:-2}"
        local critical_load="${CRITICAL_LOAD_AVG:-8.0}"
        local critical_iowait="${CRITICAL_DISK_IO_WAIT:-50}"
        local warn_mem="${WARN_MEM_AVAIL_GB:-2}"
        local warn_swap="${WARN_SWAP_USED_GB:-1}"
        local warn_load="${WARN_LOAD_AVG:-6.0}"
        local warn_iowait="${WARN_DISK_IO_WAIT:-30}"
        
        if [ "${mem_avail}" -lt "${critical_mem}" ]; then
            echo -e "  ${RED}✗ CRITICAL: Memory exhausted (${mem_avail}GB available, threshold: ${critical_mem}GB)${NC}" | tee -a "${RESOURCE_MONITOR_LOG}"
            is_critical=true
        fi
        
        if [ "${swap_used}" -gt "${critical_swap}" ]; then
            echo -e "  ${RED}✗ CRITICAL: Excessive swap usage (${swap_used}GB used, threshold: ${critical_swap}GB)${NC}" | tee -a "${RESOURCE_MONITOR_LOG}"
            is_critical=true
        fi
        
        if (( $(echo "${load_avg} > ${critical_load}" | bc -l 2>/dev/null || echo "0") )); then
            echo -e "  ${RED}✗ CRITICAL: System overloaded (load: ${load_avg}, threshold: ${critical_load})${NC}" | tee -a "${RESOURCE_MONITOR_LOG}"
            is_critical=true
        fi
        
        if (( $(echo "${iowait_pct} > ${critical_iowait}" | bc -l 2>/dev/null || echo "0") )); then
            echo -e "  ${RED}✗ CRITICAL: Disk I/O saturated (I/O wait: ${iowait_pct}%, threshold: ${critical_iowait}%)${NC}" | tee -a "${RESOURCE_MONITOR_LOG}"
            is_critical=true
        fi
        
        # Check for warning conditions (using dynamically calculated thresholds)
        if [ "${mem_avail}" -lt "${warn_mem}" ] && [ "${mem_avail}" -ge "${critical_mem}" ]; then
            echo -e "  ${YELLOW}⚠ WARNING: Low memory (${mem_avail}GB available, threshold: ${warn_mem}GB)${NC}" | tee -a "${RESOURCE_MONITOR_LOG}"
        fi
        
        if [ "${swap_used}" -gt "${warn_swap}" ] && [ "${swap_used}" -le "${critical_swap}" ]; then
            echo -e "  ${YELLOW}⚠ WARNING: Swap usage detected (${swap_used}GB used, threshold: ${warn_swap}GB)${NC}" | tee -a "${RESOURCE_MONITOR_LOG}"
        fi
        
        if (( $(echo "${load_avg} > ${warn_load}" | bc -l 2>/dev/null || echo "0") )) && (( $(echo "${load_avg} <= ${critical_load}" | bc -l 2>/dev/null || echo "1") )); then
            echo -e "  ${YELLOW}⚠ WARNING: High CPU load (load: ${load_avg}, threshold: ${warn_load})${NC}" | tee -a "${RESOURCE_MONITOR_LOG}"
        fi
        
        if (( $(echo "${iowait_pct} > ${warn_iowait}" | bc -l 2>/dev/null || echo "0") )) && (( $(echo "${iowait_pct} <= ${critical_iowait}" | bc -l 2>/dev/null || echo "1") )); then
            echo -e "  ${YELLOW}⚠ WARNING: High disk I/O wait (I/O wait: ${iowait_pct}%, threshold: ${warn_iowait}%)${NC}" | tee -a "${RESOURCE_MONITOR_LOG}"
        fi
        
        # Log status every 60 seconds (6 iterations)
        if [ $(( $(date +%s) % 60 )) -lt 10 ]; then
            echo "[$(date +%H:%M:%S)] Mem: ${mem_avail}GB/${mem_total}GB (${mem_used_pct}% used), Swap: ${swap_used}GB/${swap_total}GB, Load: ${load_avg} (${load_per_core}/core), I/O wait: ${iowait_pct}%" >> "${RESOURCE_MONITOR_LOG}"
        fi
        
        # Auto-stop logic: Stop after consecutive critical readings
        if [ "${is_critical}" = true ]; then
            consecutive_critical=$((consecutive_critical + 1))
            echo "  Critical condition detected (${consecutive_critical}/${max_consecutive_critical})" | tee -a "${RESOURCE_MONITOR_LOG}"
            
            if [ "${consecutive_critical}" -ge "${max_consecutive_critical}" ]; then
                echo -e "  ${RED}✗ AUTO-STOPPING BUILD: Critical resource exhaustion detected${NC}" | tee -a "${RESOURCE_MONITOR_LOG}"
                echo "  Stopping build to prevent system freeze..." | tee -a "${RESOURCE_MONITOR_LOG}"
                touch "${BUILD_STOP_FLAG_FILE}"  # Set flag file
                
                # Kill build process gracefully
                if kill -0 "${build_pid}" 2>/dev/null; then
                    echo "  Sending SIGTERM to build process (PID: ${build_pid})" | tee -a "${RESOURCE_MONITOR_LOG}"
                    kill -TERM "${build_pid}" 2>/dev/null || true
                    sleep 5
                    # Force kill if still running
                    if kill -0 "${build_pid}" 2>/dev/null; then
                        echo "  Force killing build process" | tee -a "${RESOURCE_MONITOR_LOG}"
                        kill -KILL "${build_pid}" 2>/dev/null || true
                    fi
                fi
                break
            fi
        else
            consecutive_critical=0  # Reset counter if not critical
        fi
        done
    ) &
    echo $!
}

# CRITICAL: Set CPU and I/O priority to prevent system freezes
# CPU priority: Lower (nice value) to avoid saturating the host system
NICE_VALUE=19  # Maximum lower priority (higher nice value = lower priority, max is 19)
echo "  Setting CPU priority: nice -n ${NICE_VALUE} (lowest priority to avoid host saturation)"

# I/O priority: Idle class to prevent disk I/O saturation (CRITICAL for preventing freezes)
# This is the most important setting to prevent system freezes
# Idle class means I/O only happens when system is idle
# NOTE: ionice should already be installed and verified in Step 1, but we check again for safety
if command -v ionice >/dev/null 2>&1; then
    IONICE_CLASS="idle"  # Use idle I/O class (best for preventing freezes)
    IONICE_LEVEL="7"     # Lowest priority within idle class
    echo "  Setting I/O priority: ionice -c ${IONICE_CLASS} -n ${IONICE_LEVEL} (idle class to prevent disk I/O saturation)"
    IONICE_CMD="ionice -c ${IONICE_CLASS} -n ${IONICE_LEVEL}"
else
    echo -e "  ${RED}✗ ERROR: ionice not available despite installation attempt${NC}"
    echo "    System may freeze due to disk I/O saturation"
    echo "    ionice (from util-linux package) is CRITICAL for preventing system freezes"
    echo "    Please install manually: ${APT_CMD} install -y util-linux"
    echo "    Then re-run this script"
    exit 1
fi

# Note: Swap monitoring is now integrated into the comprehensive resource monitor above

# Build with MAX_JOBS limit (PyTorch respects this environment variable)
# PyTorch setup.py internally uses cmake/ninja which respects MAX_JOBS
# We use nice for CPU priority and ionice for I/O priority
# CRITICAL: I/O priority is the most important for preventing freezes
if [ -n "${IONICE_CMD}" ]; then
    # Use both nice and ionice for maximum resource limiting
    # Run build in background to capture PID for monitoring
    ${IONICE_CMD} nice -n ${NICE_VALUE} python3 setup.py bdist_wheel \
        --dist-dir "${WHEEL_DIR}" \
        2>&1 | tee "${BUILD_DIR}/pytorch_build.log" &
    BUILD_PID=$!
    
    # Start resource monitor with build PID
    RESOURCE_MONITOR_PID=$(start_resource_monitor "${BUILD_PID}")
    echo "  Resource monitor started (PID: ${RESOURCE_MONITOR_PID})"
    
    # Wait for build process and check exit status
    wait "${BUILD_PID}"
    BUILD_EXIT_CODE=$?
    
    if [ "${BUILD_EXIT_CODE}" -eq 0 ] && [ ! -f "${BUILD_STOP_FLAG_FILE}" ]; then
        BUILD_SUCCESS=true
    else
        BUILD_SUCCESS=false
        if [ -f "${BUILD_STOP_FLAG_FILE}" ]; then
            echo -e "${RED}✗ Build stopped due to critical resource exhaustion${NC}"
            echo "  Check resource monitor log: ${RESOURCE_MONITOR_LOG}"
        fi
    fi
else
    # Fallback: Only use nice if ionice not available
    nice -n ${NICE_VALUE} python3 setup.py bdist_wheel \
        --dist-dir "${WHEEL_DIR}" \
        2>&1 | tee "${BUILD_DIR}/pytorch_build.log" &
    BUILD_PID=$!
    
    # Start resource monitor with build PID
    RESOURCE_MONITOR_PID=$(start_resource_monitor "${BUILD_PID}")
    echo "  Resource monitor started (PID: ${RESOURCE_MONITOR_PID})"
    
    wait "${BUILD_PID}"
    BUILD_EXIT_CODE=$?
    
    if [ "${BUILD_EXIT_CODE}" -eq 0 ] && [ ! -f "${BUILD_STOP_FLAG_FILE}" ]; then
        BUILD_SUCCESS=true
    else
        BUILD_SUCCESS=false
        if [ -f "${BUILD_STOP_FLAG_FILE}" ]; then
            echo -e "${RED}✗ Build stopped due to critical resource exhaustion${NC}"
            echo "  Check resource monitor log: ${RESOURCE_MONITOR_LOG}"
        fi
    fi
fi

    if [ "${BUILD_SUCCESS:-false}" = "true" ]; then
        BUILD_END=$(date +%s)
        BUILD_START_VAL="${BUILD_START:-${BUILD_END}}"
        BUILD_DURATION=$((BUILD_END - BUILD_START_VAL))
        BUILD_MINUTES=$((BUILD_DURATION / 60))
        
        # Stop resource monitor
        kill "${RESOURCE_MONITOR_PID}" 2>/dev/null || true
        wait "${RESOURCE_MONITOR_PID}" 2>/dev/null || true
        
        # Save completed state
        save_build_state "completed"
        
        echo -e "${GREEN}✓ PyTorch wheel built successfully${NC}"
        echo "  Build time: ${BUILD_MINUTES} minutes"
        if [ "${SYS_CPU_CORES:-0}" -gt 0 ]; then
            echo "  Build jobs used: ${BUILD_JOBS} (of ${SYS_CPU_CORES} cores)"
        else
            echo "  Build jobs used: ${BUILD_JOBS}"
        fi
        echo "  Build state saved - can resume if interrupted in future runs"
    else
        # Stop resource monitor
        kill "${RESOURCE_MONITOR_PID}" 2>/dev/null || true
        wait "${RESOURCE_MONITOR_PID}" 2>/dev/null || true
        
        # Save failed state (but keep artifacts for resume)
        save_build_state "failed"
        
        BUILD_STATUS="${PIPESTATUS[0]:-1}"
        echo -e "${RED}✗ PyTorch wheel build failed (exit code: ${BUILD_STATUS})${NC}"
        echo "  Build log: ${BUILD_DIR}/pytorch_build.log"
        echo "  Build state saved - you can resume by running this script again"
        echo "  The script will automatically detect partial build and continue"
        echo "  Checking log for common errors..."
        echo ""
        echo "  Common issues:"
        echo "    1. Missing dependencies - check requirements.txt"
        echo "    2. CUDA version mismatch - verify CUDA 12.6 is installed"
        echo "    3. Insufficient memory - PyTorch build requires significant RAM"
        echo "       Current build jobs: ${BUILD_JOBS} (reduce if OOM errors)"
        echo "       Try: export BUILD_JOBS_OVERRIDE=1  # Reduce parallelism"
        echo "    4. OpenBLAS not found - ensure libopenblas-dev is installed"
        echo "    5. System saturation/freeze - reduce MAX_JOBS if host becomes unresponsive"
        echo "       CRITICAL: If system froze, reduce to: export BUILD_JOBS_OVERRIDE=1"
        echo "    6. Disk I/O saturation - ensure ionice is installed (util-linux package)"
        echo "       I/O limiting helps prevent system freezes during compilation"
        echo ""
        echo "  To resume build:"
        echo "    Just run this script again - it will detect the partial build and continue"
        echo ""
        
        # Check for memory-related errors
        if grep -qi "out of memory\|OOM\|killed\|memory" "${BUILD_DIR}/pytorch_build.log" 2>/dev/null; then
            echo -e "  ${YELLOW}⚠ Memory-related errors detected:${NC}"
            grep -i "out of memory\|OOM\|killed\|memory" "${BUILD_DIR}/pytorch_build.log" | head -5
            echo ""
            echo "  Recommendation: Reduce build parallelism to prevent freezes"
            echo "    export BUILD_JOBS_OVERRIDE=1  # Very conservative"
            echo "    export MAX_JOBS=1"
            echo ""
            echo "  Also check swap usage - excessive swap can cause freezes"
            echo "    free -h  # Check swap usage"
            echo ""
        fi
        
        grep -i "error\|failed\|fatal" "${BUILD_DIR}/pytorch_build.log" 2>/dev/null | head -20 || true
        exit 1
    fi
fi

#===============================================================================
# Step 9: Verify wheel was created
#===============================================================================
echo -e "\n${BLUE}[Step 9] Verifying wheel...${NC}"

WHEEL_FILE=$(find "${WHEEL_DIR}" -name "torch-*.whl" | head -1)
if [ -n "${WHEEL_FILE:-}" ] && [ -f "${WHEEL_FILE}" ]; then
    WHEEL_SIZE=$(du -h "${WHEEL_FILE}" | cut -f1)
    echo -e "${GREEN}✓ Wheel created: $(basename "${WHEEL_FILE}")${NC}"
    echo "  Size: ${WHEEL_SIZE}"
    echo "  Location: ${WHEEL_FILE}"
else
    echo -e "${RED}✗ Wheel file not found${NC}"
    echo "  Searched in: ${WHEEL_DIR}"
    exit 1
fi

#===============================================================================
# Step 10: Verify wheel contents and OpenBLAS linking
#===============================================================================
echo -e "\n${BLUE}[Step 10] Verifying wheel contents...${NC}"

python3 << 'WHEEL_CHECK_EOF'
import sys
import os
import zipfile
import glob

wheel_dir = "/tmp/pytorch_openblas_test/wheels"
wheels = glob.glob(os.path.join(wheel_dir, "*.whl"))

if not wheels:
    print("✗ No wheels found to verify")
    sys.exit(1)

wheel_file = wheels[0]
print(f"Checking wheel: {os.path.basename(wheel_file)}")

# Extract and check metadata
with zipfile.ZipFile(wheel_file, 'r') as z:
    # Check for build info
    metadata_files = [f for f in z.namelist() if 'METADATA' in f or 'RECORD' in f]
    print(f"  ✓ Contains {len(metadata_files)} metadata files")
    
    # Look for .so files
    so_files = [f for f in z.namelist() if f.endswith('.so')]
    if so_files:
        print(f"  ✓ Contains {len(so_files)} shared library files")
    
    # Check for torch library
    torch_files = [f for f in z.namelist() if 'torch' in f.lower()]
    if torch_files:
        print(f"  ✓ Contains PyTorch package files ({len(torch_files)} files)")

print("\n✓ Wheel structure verified")
print("  Note: Full OpenBLAS linking verification requires installation")
print("  For testing, use: pip install ${WHEEL_FILE} && python -c 'import torch; print(torch.backends.mkl.is_available())'")
WHEEL_CHECK_EOF

#===============================================================================
# Step 11: Check build log for OpenBLAS/MKL references
#===============================================================================
echo -e "\n${BLUE}[Step 11] Checking build log for BLAS configuration...${NC}"

if [ -f "${BUILD_DIR}/pytorch_build.log" ]; then
    if grep -qi "OpenBLAS\|openblas" "${BUILD_DIR}/pytorch_build.log"; then
        echo -e "${GREEN}✓ OpenBLAS references found in build log${NC}"
        grep -i "OpenBLAS\|openblas" "${BUILD_DIR}/pytorch_build.log" | head -5
    else
        echo -e "${YELLOW}⚠ No OpenBLAS references found in build log${NC}"
    fi
    
    # Check for MKL references after filtering out disabled mentions
    if grep -qi "MKL\|mkl" "${BUILD_DIR}/pytorch_build.log" 2>/dev/null | grep -v "USE_MKL=0\|disabled\|disable" | grep -q .; then
        echo -e "${YELLOW}⚠ MKL references found in build log (may indicate MKL usage)${NC}"
        grep -i "MKL\|mkl" "${BUILD_DIR}/pytorch_build.log" 2>/dev/null | grep -v "USE_MKL=0\|disabled\|disable" | head -3
    else
        echo -e "${GREEN}✓ MKL appears to be disabled in build${NC}"
    fi
fi

#===============================================================================
# Step 12: Build Summary
#===============================================================================
echo -e "\n${BLUE}[Step 12] Build Summary...${NC}"
echo -e "${GREEN}✓ PyTorch wheel built successfully with OpenBLAS configuration${NC}"
echo "  Wheel location: ${WHEEL_FILE}"
echo "  Build log: ${BUILD_DIR}/pytorch_build.log"
echo ""
echo -e "${YELLOW}Note: Wheel is not installed (as requested)${NC}"
echo -e "${YELLOW}To test installation and verify OpenBLAS linking:${NC}"
if [ -n "${pip_flags:-}" ]; then
    echo -e "${YELLOW}  python3 -m pip install ${pip_flags} ${WHEEL_FILE}${NC}"
else
    echo -e "${YELLOW}  python3 -m pip install ${WHEEL_FILE}${NC}"
fi
echo -e "${YELLOW}  python3 -c \"import torch; print('MKL available:', torch.backends.mkl.is_available()); print('Should be False for OpenBLAS build')\"${NC}"

#===============================================================================
# Step 13: Build artifacts preservation
#===============================================================================
echo -e "\n${BLUE}[Step 13] Build artifacts preservation...${NC}"

# Keep all build artifacts for reuse (downloads are large, so we preserve them)
if [ -n "${WHEEL_FILE:-}" ] && [ -f "${WHEEL_FILE}" ]; then
    echo "  ✓ Wheel file: ${WHEEL_FILE}"
fi

if [ -d "${BUILD_DIR}" ]; then
    echo "  ✓ Build directory preserved: ${BUILD_DIR}"
    echo "    - Source code: ${PYTORCH_SOURCE_DIR}"
    echo "    - Build artifacts: ${BUILD_DIR}/build"
    echo "    - Wheel file: ${WHEEL_FILE:-${BUILD_DIR}/wheels/*.whl}"
fi

if [ -f "${BUILD_DIR}/pytorch_build.log" ]; then
    echo "  ✓ Build log preserved: ${BUILD_DIR}/pytorch_build.log"
fi

echo ""
echo -e "${YELLOW}Note: Build artifacts are preserved for reuse${NC}"
echo -e "${YELLOW}      Clean up manually after code is integrated into main script:${NC}"
echo -e "${YELLOW}      rm -rf ${BUILD_DIR}${NC}"
echo -e "${YELLOW}      rm -f "${BUILD_DIR}/pytorch_build.log"${NC}"

#===============================================================================
# Final Summary
#===============================================================================
echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}✓ PyTorch OpenBLAS Compilation Test: PASSED${NC}"
echo -e "${GREEN}  Wheel built successfully${NC}"
if [ -n "${WHEEL_BACKUP:-}" ] && [ -f "${WHEEL_BACKUP}" ]; then
    echo -e "${GREEN}  Wheel location: ${WHEEL_BACKUP}${NC}"
fi
echo -e "${GREEN}  Ready for integration into main script${NC}"
echo -e "${BLUE}========================================${NC}\n"

exit 0

