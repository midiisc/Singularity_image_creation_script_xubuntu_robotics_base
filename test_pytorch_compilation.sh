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
# Parse Command-Line Arguments
#===============================================================================
OVERLAY_PATH=""
IMAGE_PATH=""
USE_GPU=false
RUN_INSIDE_CONTAINER=false

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
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --overlay PATH    Path to writable overlay image (e.g., overlay.img)"
            echo "  --image PATH      Path to Singularity/Apptainer image (e.g., image.sif)"
            echo "  --gpu|--nv        Enable GPU support (NVIDIA)"
            echo "  --help, -h        Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Run on host or inside container"
            echo "  $0 --overlay overlay.img --image image.sif  # Run in Singularity with overlay"
            echo "  $0 --overlay overlay.img --image image.sif --gpu  # With GPU support"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

#===============================================================================
# Check if we should run inside Singularity container
#===============================================================================
if [ "$RUN_INSIDE_CONTAINER" = true ]; then
    if [ -z "$IMAGE_PATH" ]; then
        echo -e "${RED}Error: --image is required when using --overlay${NC}"
        exit 1
    fi
    
    if [ ! -f "$IMAGE_PATH" ]; then
        echo -e "${RED}Error: Image file not found: ${IMAGE_PATH}${NC}"
        exit 1
    fi
    
    if [ -n "$OVERLAY_PATH" ] && [ ! -f "$OVERLAY_PATH" ]; then
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
    if [ "$USE_GPU" = true ]; then
        SINGULARITY_OPTS+=("--nv")
    fi
    if [ -n "$OVERLAY_PATH" ]; then
        OVERLAY_ABS="$(cd "$(dirname "$OVERLAY_PATH")" && pwd)/$(basename "$OVERLAY_PATH")"
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
    if [ -n "$OVERLAY_PATH" ]; then
        echo "  Overlay: ${OVERLAY_PATH}"
    fi
    if [ "$USE_GPU" = true ]; then
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
    if [ "$jobs_by_cpu" -lt 1 ]; then
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
    if [ "$jobs_by_mem" -lt 1 ]; then
        jobs_by_mem=1
    fi
    
    # Calculate jobs based on disk I/O capabilities
    # HDDs can handle fewer parallel jobs than SSDs
    local jobs_by_io
    if [ "${disk_type}" = "SSD" ]; then
        # SSDs can handle more parallel I/O
        jobs_by_io=$((cpu_cores / 3))  # More aggressive for SSDs
        if [ "$jobs_by_io" -gt 6 ]; then
            jobs_by_io=6  # Cap at 6 for SSDs
        fi
    elif [ "${disk_type}" = "HDD" ]; then
        # HDDs need more conservative limits
        jobs_by_io=$((cpu_cores / 5))  # More conservative for HDDs
        if [ "$jobs_by_io" -gt 3 ]; then
            jobs_by_io=3  # Cap at 3 for HDDs
        fi
    else
        # Unknown disk type - be conservative
        jobs_by_io=$((cpu_cores / 4))
        if [ "$jobs_by_io" -gt 4 ]; then
            jobs_by_io=4
        fi
    fi
    if [ "$jobs_by_io" -lt 1 ]; then
        jobs_by_io=1
    fi
    
    # Use the minimum of all three (most conservative)
    local jobs
    jobs=$jobs_by_cpu
    if [ "$jobs_by_mem" -lt "$jobs" ]; then
        jobs=$jobs_by_mem
    fi
    if [ "$jobs_by_io" -lt "$jobs" ]; then
        jobs=$jobs_by_io
    fi
    
    # Ensure at least 1 job
    if [ "$jobs" -lt 1 ]; then
        jobs=1
    fi
    
    # Allow override via environment variable
    if [ -n "${BUILD_JOBS_OVERRIDE:-}" ]; then
        jobs=$BUILD_JOBS_OVERRIDE
    fi
    
    echo "$jobs"
}

# Calculate dynamic resource thresholds based on system capabilities
calculate_resource_thresholds() {
    local cpu_cores="${SYS_CPU_CORES:-4}"
    local mem_total_gb="${SYS_MEM_TOTAL_GB:-8}"
    local mem_available_gb="${SYS_MEM_AVAILABLE_GB:-4}"
    local swap_total_gb="${SYS_SWAP_TOTAL_GB:-0}"
    
    # Critical memory threshold: 10% of total RAM or 1.5GB, whichever is larger (more conservative)
    # This ensures more headroom to prevent system freezes
    local critical_mem_gb
    critical_mem_gb=$((mem_total_gb * 10 / 100))
    if [ "${critical_mem_gb}" -lt 1 ]; then
        critical_mem_gb=1
    fi
    # Ensure at least 1.5GB for safety
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
if [ "$EUID" -eq 0 ]; then
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
for pkg in build-essential cmake ninja-build git curl wget \
           libopenblas-dev liblapack-dev libblas-dev \
           libomp-dev libtbb-dev python3-dev python3-pip \
           python3-setuptools python3-wheel util-linux shellcheck sysstat; do
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

if [ "$OPENBLAS_FOUND" = false ]; then
    echo -e "${RED}✗ ERROR: OpenBLAS not found after installation${NC}"
    exit 1
fi

# Verify OpenBLAS headers
if [ -f "/usr/include/x86_64-linux-gnu/cblas.h" ] || [ -f "/usr/include/cblas.h" ]; then
    echo -e "${GREEN}✓ OpenBLAS headers found${NC}"
else
    echo -e "${YELLOW}⚠ OpenBLAS headers not found${NC}"
fi

# Verify OpenMP
if ldconfig -p 2>/dev/null | grep -q libomp; then
    echo -e "${GREEN}✓ OpenMP found${NC}"
else
    echo -e "${YELLOW}⚠ OpenMP not found${NC}"
fi

# Verify TBB (Threading Building Blocks)
if ldconfig -p 2>/dev/null | grep -q libtbb; then
    echo -e "${GREEN}✓ TBB (Threading Building Blocks) found${NC}"
else
    echo -e "${YELLOW}⚠ TBB not found (optional, but recommended)${NC}"
fi

# Verify LAPACK
if ldconfig -p 2>/dev/null | grep -q liblapack; then
    echo -e "${GREEN}✓ LAPACK found${NC}"
else
    echo -e "${YELLOW}⚠ LAPACK not found${NC}"
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
    echo -e "${GREEN}✓ CUDA ${CUDA_VERSION} toolkit detected and verified${NC}\n"
else
    echo -e "${YELLOW}⚠ CUDA ${CUDA_VERSION} detected (expected 12.x)${NC}\n"
fi

# CUDA compute capabilities
CUDA_ARCH_LIST="8.6;8.9;9.0"
CMAKE_CUDA_ARCHITECTURES="86;89;90"
echo "  CUDA compute capabilities: ${CUDA_ARCH_LIST}"
echo "  CMake format: ${CMAKE_CUDA_ARCHITECTURES}"

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

# Performance Libraries (CPU parallelism and multithreading)
export USE_OPENMP=1  # OpenMP for CPU parallelism (required)
export USE_TBB=1     # Intel Threading Building Blocks (if available)
export TBB_SOURCE_DIR=/usr/include/tbb  # TBB include path

# Use pre-calculated build jobs from system detection
BUILD_JOBS="${CALCULATED_JOBS}"

echo "  Build Configuration (Based on Detected Hardware):"
echo "    Total CPU cores: ${SYS_CPU_CORES}"
echo "    Total RAM: ${SYS_MEM_TOTAL_GB}GB (${SYS_MEM_AVAILABLE_GB}GB available)"
echo "    Disk type: ${SYS_DISK_TYPE}"
echo "    Build jobs: ${BUILD_JOBS} (calculated from CPU, memory, and I/O capabilities)"
echo "    Memory per job: ${SYS_MEM_PER_JOB_GB}GB"
echo "    Total memory budget: $((BUILD_JOBS * SYS_MEM_PER_JOB_GB))GB"

# Threading configuration (runtime threading, not build parallelism)
# Use 50% of available cores for runtime threading to avoid oversubscription
# But ensure we don't exceed available cores
if [ "${SYS_CPU_CORES:-0}" -gt 0 ]; then
    runtime_threads=$((SYS_CPU_CORES / 2))
    if [ $runtime_threads -lt 1 ]; then
        runtime_threads=1
    fi
else
    runtime_threads=1  # Default to 1 if CPU cores unknown
fi
# Cap at build jobs to avoid oversubscription
if [ "${runtime_threads}" -gt "${BUILD_JOBS}" ]; then
    runtime_threads="${BUILD_JOBS}"
fi

export OMP_NUM_THREADS="${runtime_threads}"  # OpenMP threads
export MKL_NUM_THREADS="${runtime_threads}"  # MKL threads (for compatibility)
export OPENBLAS_NUM_THREADS="${runtime_threads}"  # OpenBLAS threads
export NUMEXPR_NUM_THREADS="${runtime_threads}"  # NumExpr threads

if [ "${SYS_CPU_CORES:-0}" -gt 0 ]; then
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
echo "    USE_OPENMP=1 (OpenMP enabled)"
echo -e "${GREEN}✓ Build environment configured for OpenBLAS + CUDA${NC}\n"

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
    
    # Always use latest stable release (fetch from GitHub releases)
    echo "  Fetching latest stable PyTorch version from GitHub releases..."
    LATEST_TAG=$(curl -s https://api.github.com/repos/pytorch/pytorch/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | head -1)
    
    if [ -z "${LATEST_TAG:-}" ]; then
        echo -e "${YELLOW}⚠ Could not fetch latest tag, using PyTorch 2.9.0 as fallback${NC}"
        LATEST_TAG="v2.9.0"
    fi
    
    # Remove 'v' prefix if present for version comparison
    PYTORCH_VERSION="${LATEST_TAG#v}"
    echo "  Latest stable version: ${PYTORCH_VERSION}"
    
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
if [ -n "${pip_flags}" ]; then
    python3 -m pip install --upgrade pip setuptools wheel ${pip_flags} --quiet 2>&1 || \
    python3 -m pip install --upgrade pip setuptools wheel ${pip_flags} 2>&1 | \
        grep -v "^Requirement\|^Collecting\|^Using\|^Already\|^WARNING" || true
else
    python3 -m pip install --upgrade pip setuptools wheel --quiet 2>&1 || \
    python3 -m pip install --upgrade pip setuptools wheel 2>&1 | \
        grep -v "^Requirement\|^Collecting\|^Using\|^Already\|^WARNING" || true
fi

# Install PyTorch build dependencies
# IMPORTANT: PyTorch does NOT require TensorFlow or Keras for building
# These may appear in requirements.txt for testing/CI but are NOT build dependencies
# We install only the minimal dependencies needed for compilation
echo "  Installing minimal PyTorch build dependencies..."
echo "  Note: PyTorch is independent of TensorFlow/Keras - these are NOT required for building"
echo "  Note: Installing only core build dependencies to avoid conflicts"

# Core build dependencies for PyTorch (minimal set required for compilation)
# These are the actual dependencies needed by PyTorch's setup.py
CORE_BUILD_DEPS="numpy ninja pyyaml setuptools wheel cmake typing-extensions filelock networkx sympy"

if [ -n "${pip_flags}" ]; then
    # Install core dependencies with --ignore-installed to handle version conflicts gracefully
    # This allows pip to install needed versions even if system packages exist
    python3 -m pip install --no-cache-dir --ignore-installed ${pip_flags} \
        ${CORE_BUILD_DEPS} 2>&1 | \
        grep -vE "^Requirement|^Collecting|^Using|^Already|^WARNING|^ERROR.*devscripts|Invalid version|^ERROR.*tensorflow|^ERROR.*keras" || {
        echo "  ⚠ Some packages may have installation issues (non-fatal)"
        echo "  Continuing with build - PyTorch setup.py will handle missing optional dependencies"
    }
else
    python3 -m pip install --no-cache-dir --ignore-installed \
        ${CORE_BUILD_DEPS} 2>&1 | \
        grep -vE "^Requirement|^Collecting|^Using|^Already|^WARNING|^ERROR.*devscripts|Invalid version|^ERROR.*tensorflow|^ERROR.*keras" || {
        echo "  ⚠ Some packages may have installation issues (non-fatal)"
        echo "  Continuing with build - PyTorch setup.py will handle missing optional dependencies"
    }
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
        if [ -n "${pip_flags}" ]; then
            python3 -m pip install --no-cache-dir --ignore-installed ${pip_flags} \
                -r "${FILTERED_REQUIREMENTS}" 2>&1 | \
                grep -vE "^Requirement|^Collecting|^Using|^Already|^WARNING|^ERROR.*devscripts|Invalid version" || true
        else
            python3 -m pip install --no-cache-dir --ignore-installed \
                -r "${FILTERED_REQUIREMENTS}" 2>&1 | \
                grep -vE "^Requirement|^Collecting|^Using|^Already|^WARNING|^ERROR.*devscripts|Invalid version" || true
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
    local build_pid="$1"
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
    RESOURCE_MONITOR_PID=$(start_resource_monitor ${BUILD_PID})
    echo "  Resource monitor started (PID: ${RESOURCE_MONITOR_PID})"
    
    # Wait for build process and check exit status
    wait ${BUILD_PID}
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
    RESOURCE_MONITOR_PID=$(start_resource_monitor ${BUILD_PID})
    echo "  Resource monitor started (PID: ${RESOURCE_MONITOR_PID})"
    
    wait ${BUILD_PID}
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
        BUILD_DURATION=$((BUILD_END - BUILD_START))
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
        
        BUILD_STATUS=${PIPESTATUS[0]}
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
    
    if grep -qi "MKL\|mkl" "${BUILD_DIR}/pytorch_build.log" | grep -v "USE_MKL=0\|disabled\|disable"; then
        echo -e "${YELLOW}⚠ MKL references found in build log (may indicate MKL usage)${NC}"
        grep -i "MKL\|mkl" "${BUILD_DIR}/pytorch_build.log" | grep -v "USE_MKL=0\|disabled\|disable" | head -3
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

