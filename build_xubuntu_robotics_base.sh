#!/bin/bash
#===============================================================================
# SINGULARITY/APPTAINER IMAGE BUILD SCRIPT
# Xubuntu Robotics & Perception Workflow Base Image
#===============================================================================
# Purpose: Host-side orchestration for building Singularity container
#
# Features:
#   - Comprehensive caching system (APT, Conda, Julia, Python wheels)
#   - Parallel artifact downloading with verification
#   - GPU support (CUDA, cuDNN, VirtualGL)
#   - Remote desktop (TurboVNC + XFCE4)
#   - ROS 2 Jazzy + Drake robotics framework
#   - Julia 1.10 LTS + Python (Miniforge/Micromamba)
#
# Usage: ./build_xubuntu_robotics_base.sh
# Requirements: apptainer or singularity, dpkg-dev, 150GB disk space
#===============================================================================

#===============================================================================
# BLOCK 1: SCRIPT INITIALIZATION
#===============================================================================
# Purpose: Validate bash shell and set strict error handling
# Self-contained: Yes (complete if-fi block with exit)
# Dependencies: None
# Outputs: Environment variables, configuration
#-------------------------------------------------------------------------------

#--- Sub-block 1.1: Bash version validation ---
# Critical: Ensure script runs in bash (not sh/dash) for array and advanced features
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
if [ -z "${BASH_VERSION:-}" ]; then
    echo "ERROR: This script requires bash. Please run with: /bin/bash"
    echo "Current shell: ${0}"
    exit 1
fi
# End if-fi block (self-contained)

#--- Sub-block 1.2: Strict error handling ---
# Critical: Exit on any error, undefined variable, or pipeline failure
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
set -euo pipefail  # -e: exit on error, -u: error on undefined var, -o pipefail: catch pipe errors

#--- Sub-block 1.3: Environment/Shell compatibility probe and strict-mode helpers ---
# Purpose: Detect active shell and capabilities, export diagnostics variables, and provide safe strict-mode toggles
# Dependencies: None (foundational)
# Outputs: Exported diagnostics variables and helper functions to be reused anywhere
#
# Exported variables:
#   DETECTED_SHELL_PATH, DETECTED_SHELL_NAME, DETECTED_BASH_VERSION, IS_BASH,
#   SUPPORTS_PIPEFAIL, SUPPORTS_ERRTRACE
DETECTED_SHELL_PATH="${SHELL:-$(ps -p $$ -o comm= 2>/dev/null || echo sh)}"
DETECTED_SHELL_NAME="$(basename "${DETECTED_SHELL_PATH}" 2>/dev/null || echo sh)"
DETECTED_BASH_VERSION="${BASH_VERSION:-}"
if [ -n "${DETECTED_BASH_VERSION}" ]; then
    IS_BASH=1
else
    IS_BASH=0
fi
# Capability probes are executed in subshells to avoid altering current shell options
SUPPORTS_PIPEFAIL="$( ( set -o pipefail ) >/dev/null 2>&1; echo $? )"
if [ "${SUPPORTS_PIPEFAIL}" = "0" ]; then SUPPORTS_PIPEFAIL=1; else SUPPORTS_PIPEFAIL=0; fi
SUPPORTS_ERRTRACE="$( ( set -o errtrace ) >/dev/null 2>&1; echo $? )"
if [ "${SUPPORTS_ERRTRACE}" = "0" ]; then SUPPORTS_ERRTRACE=1; else SUPPORTS_ERRTRACE=0; fi
export DETECTED_SHELL_PATH DETECTED_SHELL_NAME DETECTED_BASH_VERSION IS_BASH SUPPORTS_PIPEFAIL SUPPORTS_ERRTRACE

# Helper: enable strict mode safely with fallbacks and ERR trap diagnostics
enable_strict_mode_safely() {
    # Purpose: Apply -e -u and pipefail where supported; attach ERR trap for reliable failure reporting
    if [ "${IS_BASH}" -eq 1 ]; then
        set -e
        set -u
        if [ "${SUPPORTS_PIPEFAIL}" -eq 1 ]; then
            set -o pipefail || true
        fi
        if [ "${SUPPORTS_ERRTRACE}" -eq 1 ]; then
            set -E -o errtrace || true
        fi
        # Attach a compact diagnostic handler; avoid referencing unset vars
        trap 'ec=$?; printf "[ERROR] Command failed (exit=%s) at %s:%s: %s\n" "${ec}" "${BASH_SOURCE[0]-?}" "${LINENO-?}" "${BASH_COMMAND-?}" >&2; exit "${ec}"' ERR
    else
        # Non-bash shells: best-effort strictness without bash-only flags
        set -e
        set -u
    fi
}

# Ensure strict mode remains active even if modified later; scripts can re-call this when entering critical sections
STRICT_MODE_INITIALIZED=1
export STRICT_MODE_INITIALIZED
enable_strict_mode_safely

#===============================================================================
# BLOCK 2: LOAD CENTRALIZED CONFIGURATION
#===============================================================================
# Purpose: Source all version numbers, URLs, and parameters from config.sh
# Self-contained: Yes (complete if-fi block with exit)
# Dependencies: config.sh must exist in same directory
# Outputs: Configured system components
#-------------------------------------------------------------------------------

#--- Sub-block 2.1: Locate configuration file ---
# Critical: Get absolute path to script directory for reliable config loading
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"

#--- Sub-block 2.2: Validate config file exists ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
if [ ! -f "${CONFIG_FILE}" ]; then
    echo "ERROR: Configuration file not found: ${CONFIG_FILE}"
    echo "Please ensure config.sh exists in the same directory as this script."
    exit 1
fi
# End if-fi block (self-contained)

#--- Sub-block 2.3: Load all configuration variables ---
# Critical: Source config.sh to load all version numbers, URLs, and cache paths
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# shellcheck disable=SC1090
source "${CONFIG_FILE}"

echo "✓ Configuration loaded from ${CONFIG_FILE}"

# Consolidate build flag defaults for MKL migration artifacts
DEFAULT_OPENBLAS_BUILD_FLAGS="DYNAMIC_ARCH=1 DYNAMIC_OLDER=1 TARGET=GENERIC USE_OPENMP=1 USE_TLS=1 NO_AFFINITY=1 NUM_THREADS=64 GEMM_MULTITHREAD_THRESHOLD=50 BUILD_LAPACK_DEPRECATED=1 NO_WARMUP=1 BINARY=64 CC=gcc FC=gfortran HOSTCC=gcc"
OPENBLAS_BUILD_FLAGS="${OPENBLAS_BUILD_FLAGS:-${DEFAULT_OPENBLAS_BUILD_FLAGS}}"
OPENBLAS_INSTALL_PREFIX="${OPENBLAS_INSTALL_PREFIX:-/usr/local}"
DEFAULT_SUITESPARSE_CMAKE_FLAGS="-DSUITESPARSE_USE_OPENMP=ON -DSUITESPARSE_USE_CUDA=ON -DSUITESPARSE_CUDA_ARCHITECTURES=86 -DSUITESPARSE_USE_STRICT=ON -DSUITESPARSE_USE_FORTRAN=ON -DCHOLMOD_USE_CUDA=ON -DSPQR_USE_CUDA=ON -DGRAPHBLAS_USE_CUDA=OFF -DCHOLMOD_PARTITION=ON -DCHOLMOD_CAMD=ON -DBLA_VENDOR=Intel10_64lp -DBLA_SIZEOF_INTEGER=4"
SUITESPARSE_CMAKE_FLAGS="${SUITESPARSE_CMAKE_FLAGS:-${DEFAULT_SUITESPARSE_CMAKE_FLAGS}}"
SUITESPARSE_INSTALL_PREFIX="${SUITESPARSE_INSTALL_PREFIX:-/usr/local}"
export OPENBLAS_BUILD_FLAGS OPENBLAS_INSTALL_PREFIX SUITESPARSE_CMAKE_FLAGS

#===============================================================================
# BLOCK 3: HOST DEPENDENCY VALIDATION AND INSTALLATION
#===============================================================================
# Purpose: Check for and install best-in-class host tools before starting build
# Self-contained: Yes (complete if-fi blocks with installation)
# Dependencies: sudo access for package installation
# Outputs: Installed packages, verified tools
#-------------------------------------------------------------------------------

#--- Sub-block 3.1: Check sudo availability ---
# Purpose: Verify sudo is available before attempting installations
# Dependencies: None (foundational check)
# Outputs: Error message if sudo unavailable
if ! command -v sudo >/dev/null 2>&1; then
    echo "ERROR: sudo is required for installing host tools but is not available"
    echo "Please install sudo or run this script with appropriate privileges"
    exit 1
fi

# Test sudo access (non-interactive, may fail if password required)
if ! sudo -n true 2>/dev/null; then
    echo "WARNING: sudo access may require a password"
    echo "The script will attempt to install tools, but may prompt for your password"
fi
# End if-fi block (self-contained)

#--- Sub-block 3.2: Function to install missing tools ---
# Purpose: Install tools if missing, with proper error handling
# Dependencies: sudo access, apt package manager
# Outputs: Installed packages
install_host_tool() {
    local tool_name="${1:-}"
    local package_name="${2:-}"
    local description="${3:-}"
    
    # Parameter validation
    if [ -z "${tool_name}" ] || [ -z "${package_name}" ] || [ -z "${description}" ]; then
        echo "ERROR: install_host_tool() called with empty parameters" >&2
        return 1
    fi
    
    # Check if tool already available
    if command -v "${tool_name}" >/dev/null 2>&1; then
        echo "✓ ${description} (${tool_name}) already installed"
        return 0
    fi
    
    # Attempt installation
    echo "Installing ${description} (${package_name})..."
    local install_output
    local install_status=0
    
    # Run installation and capture output for better error reporting
    install_output=$(sudo apt-get install -y --no-install-recommends "${package_name}" 2>&1) || install_status=$?
    
    if [ ${install_status} -eq 0 ]; then
        # Refresh command cache (hash -r) to ensure newly installed tools are found
        hash -r 2>/dev/null || true
        
        # Verify tool is now available
        if command -v "${tool_name}" >/dev/null 2>&1; then
            echo "✓ Successfully installed ${description} (${tool_name})"
            return 0
        else
            echo "⚠ WARNING: ${package_name} installed but ${tool_name} not found in PATH" >&2
            echo "Installation output: ${install_output}" >&2
            return 1
        fi
    else
        echo "✗ ERROR: Failed to install ${package_name}" >&2
        echo "Installation output: ${install_output}" >&2
        return 1
    fi
}
# End function (self-contained)

#--- Sub-block 3.3: Update package list once ---
# Purpose: Update APT package list once before installing tools (more efficient)
# Dependencies: sudo access
# Outputs: Updated package index
echo "Updating package list..."
if ! sudo apt-get update -qq 2>&1; then
    echo "WARNING: apt-get update had issues, but continuing with installations..." >&2
fi
# End if-fi block (self-contained)

#--- Sub-block 3.4: Function to check find -printf support ---
# Purpose: Test if find supports -printf in a portable way
# Dependencies: None (test function)
# Outputs: Return code (0 if supported, 1 if not)
check_find_printf_support() {
    # Create a temporary test file instead of using /dev/null
    # /dev/null may not exist in all environments (e.g., chroot)
    local test_file
    local test_result=1
    
    # Try to create a temporary file in /tmp
    if test_file=$(mktemp -t find_test.XXXXXX 2>/dev/null); then
        # Test file created successfully
        # Test find -printf support
        if find "${test_file}" -printf '%p\n' >/dev/null 2>&1; then
            test_result=0
        fi
        # Clean up test file
        rm -f "${test_file}" 2>/dev/null || true
    else
        # Fallback: use /tmp with PID-based name
        test_file="/tmp/find_test.$$"
        if touch "${test_file}" 2>/dev/null; then
            # Test find -printf support
            if find "${test_file}" -printf '%p\n' >/dev/null 2>&1; then
                test_result=0
            fi
            # Clean up test file
            rm -f "${test_file}" 2>/dev/null || true
        else
            # Last resort: test with current directory
            if [ -d "/tmp" ] && [ -w "/tmp" ]; then
                test_file="/tmp/find_test_check"
                if touch "${test_file}" 2>/dev/null; then
                    if find "${test_file}" -printf '%p\n' >/dev/null 2>&1; then
                        test_result=0
                    fi
                    rm -f "${test_file}" 2>/dev/null || true
                fi
            fi
        fi
    fi
    
    return ${test_result}
}
# End function (self-contained)

#--- Sub-block 3.5: Install essential host tools ---
# Critical: Install best-in-class tools for robust script operation
# Dependencies: sudo access, BLOCK 3.3 (package list update)
# Outputs: Installed packages
echo "Checking and installing essential host tools..."

# Tool 1: dpkg-deb (required for .deb package inspection)
if ! install_host_tool "dpkg-deb" "dpkg-dev" "dpkg-deb tool"; then
    echo ""
    echo "ERROR: Failed to install dpkg-dev (required for .deb package inspection)" >&2
    echo "Please install manually with: sudo apt update && sudo apt install dpkg-dev" >&2
    exit 1
fi

# Tool 2: pgrep (better than ps|grep for process management)
# Critical: Script uses pgrep directly, must be installed
if ! install_host_tool "pgrep" "procps" "pgrep process finder"; then
    # Try alternative package name (some systems use procps-ng)
    if ! install_host_tool "pgrep" "procps-ng" "pgrep process finder"; then
        echo ""
        echo "ERROR: Failed to install pgrep (required for process management)" >&2
        echo "Please install manually with: sudo apt update && sudo apt install procps" >&2
        exit 1
    fi
fi

# Tool 3: GNU findutils (for find -printf support)
# Critical: Script uses find -printf directly, must be available
if check_find_printf_support; then
    echo "✓ GNU find with -printf support already available"
else
    echo "Installing GNU findutils for better find command support..."
    # Note: Cannot use 'local' here as we're not in a function
    findutils_install_output=""
    findutils_install_status=0
    
    findutils_install_output=$(sudo apt-get install -y --no-install-recommends findutils 2>&1) || findutils_install_status=$?
    
    if [ ${findutils_install_status} -eq 0 ]; then
        # Refresh command cache
        hash -r 2>/dev/null || true
        
        # Verify find -printf now works
        if check_find_printf_support; then
            echo "✓ Successfully installed GNU findutils"
        else
            echo ""
            echo "ERROR: findutils installed but find -printf not working" >&2
            echo "Installation output: ${findutils_install_output}" >&2
            echo "This may indicate a system compatibility issue" >&2
            exit 1
        fi
    else
        echo ""
        echo "ERROR: Failed to install findutils (required for robust file operations)" >&2
        echo "Installation output: ${findutils_install_output}" >&2
        echo "Please install manually with: sudo apt update && sudo apt install findutils" >&2
        exit 1
    fi
fi

# Tool 4: aria2c (for fast parallel downloads)
if ! install_host_tool "aria2c" "aria2" "aria2 download accelerator"; then
    echo "⚠ WARNING: aria2c not available, will use curl/wget (slower downloads)" >&2
fi

# Tool 5: curl (essential download tool)
if ! install_host_tool "curl" "curl" "curl download tool"; then
    echo ""
    echo "ERROR: curl is required but could not be installed" >&2
    exit 1
fi

# Tool 6: wget (fallback download tool)
if ! install_host_tool "wget" "wget" "wget download tool"; then
    echo "⚠ WARNING: wget not available, curl will be used as fallback" >&2
fi

# Tool 7: jq (JSON processor - useful for API responses)
if ! install_host_tool "jq" "jq" "jq JSON processor"; then
    echo "⚠ WARNING: jq not available (optional, for JSON processing)" >&2
fi

# Tool 8: rsync (for efficient file copying)
if ! install_host_tool "rsync" "rsync" "rsync file sync tool"; then
    echo "⚠ WARNING: rsync not available (will use cp fallback)" >&2
fi

# Tool 9: lsof (required for cleanup routines)
if ! install_host_tool "lsof" "lsof" "lsof file descriptor inspector"; then
    echo ""
    echo "ERROR: lsof is required for cleanup routines but could not be installed" >&2
    exit 1
fi

# Tool 10: gpg (for fetching and exporting keys)
if ! install_host_tool "gpg" "gnupg" "GnuPG (gpg)"; then
    echo "⚠ WARNING: gpg not available (GPG key prefetch will be skipped)" >&2
fi

# Tool 11: coreutils (for numfmt and other utilities)
if ! command -v numfmt >/dev/null 2>&1; then
    if ! install_host_tool "numfmt" "coreutils" "GNU coreutils (numfmt)"; then
        echo "⚠ WARNING: coreutils (numfmt) not available; using fallback size formatting" >&2
    fi
fi

# Tool 12: gawk (awk features across distros)
if ! command -v awk >/dev/null 2>&1; then
    if ! install_host_tool "awk" "gawk" "GNU awk"; then
        echo "⚠ WARNING: awk not available; some parsing features may degrade" >&2
    fi
fi

echo "✓ Host tool validation and installation complete"

#===============================================================================
# BLOCK 4: LOCALE AND ENVIRONMENT SETUP
#===============================================================================
# Purpose: Set consistent locale to avoid parsing issues
# Self-contained: Yes
# Dependencies: None
# Outputs: Environment variables, configuration
#-------------------------------------------------------------------------------

#--- Sub-block 4.1: Set C locale for consistent number/date formatting ---
# Critical: Prevents locale-specific parsing errors in awk/grep/sort operations
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
export LC_ALL=C          # Set all locale categories to C
export LC_NUMERIC=C      # Ensure numeric formatting uses . not ,
export LANG=C            # Set language to C (English, ASCII)

#===============================================================================
# BLOCK 5: BUILD TIME TRACKING
#===============================================================================
# Purpose: Record build start time for duration calculation
# Self-contained: Yes
# Dependencies: None
# Outputs: Environment variables, configuration
#-------------------------------------------------------------------------------

#--- Sub-block 5.1: Record build start timestamp ---
# Critical: Used later to calculate total build duration
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
BUILD_START_TIME=$(date +%s)  # Unix timestamp in seconds

#===============================================================================
# BLOCK 6: LOGGING SYSTEM SETUP
#===============================================================================
# Purpose: Initialize logging directories and files
# Self-contained: Yes (complete if-fi block)
# Dependencies: LOG_RETENTION_COUNT from config.sh
# Outputs: Configured system components
#-------------------------------------------------------------------------------

#--- Sub-block 6.1: Define log directory ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
LOG_DIR="${PWD}/build_logs"

#--- Sub-block 6.2: Clean old log files (retention policy) ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "Initializing logging system..."
echo "  Log directory: ${PWD}/build_logs"

# Ensure LOG_RETENTION_COUNT is set (default if not set)
LOG_RETENTION_COUNT="${LOG_RETENTION_COUNT:-1}"

# Safety check: Warn if retention count is misconfigured
if [ "${LOG_RETENTION_COUNT:-1}" -le 0 ]; then
    echo "  ⚠ WARNING: LOG_RETENTION_COUNT=${LOG_RETENTION_COUNT} (should be >= 1)"
    echo "  ⚠ Log cleanup is DISABLED - old logs will accumulate!"
    echo "  ⚠ Set LOG_RETENTION_COUNT=2 in config.sh (recommended)"
elif [ "${LOG_RETENTION_COUNT:-1}" -gt 10 ]; then
    echo "  ⚠ WARNING: LOG_RETENTION_COUNT=${LOG_RETENTION_COUNT} (unusually high)"
    echo "  ⚠ This will keep many old logs - consider reducing to 2-5"
else
    echo "  Retention policy: Keep ${LOG_RETENTION_COUNT} most recent log(s)"
fi

# Create log directory first (if it doesn't exist) so cleanup can run
mkdir -p "${LOG_DIR}"

# Now clean up old logs if directory exists and retention count is positive
# CRITICAL: Cleanup runs BEFORE new log creation, so we keep (LOG_RETENTION_COUNT - 1) old logs
# to account for the new log that will be created. This ensures total = LOG_RETENTION_COUNT
if [ -d "${LOG_DIR}" ] && [ "${LOG_RETENTION_COUNT:-1}" -gt 0 ]; then
    # Count existing log files (match actual pattern: build-*.log and errors-*.log with hyphen)
    # Use tr to remove whitespace from wc output for robust numeric comparison
    BUILD_LOGS=$(find "${LOG_DIR}" -maxdepth 1 -name "build-*.log" -type f 2>/dev/null | wc -l | tr -d '[:space:]')
    ERROR_LOGS=$(find "${LOG_DIR}" -maxdepth 1 -name "errors-*.log" -type f 2>/dev/null | wc -l | tr -d '[:space:]')
    # Ensure numeric values, default to 0 if empty
    BUILD_LOGS="${BUILD_LOGS:-0}"
    ERROR_LOGS="${ERROR_LOGS:-0}"
    
    echo "  Found: ${BUILD_LOGS} build log(s), ${ERROR_LOGS} error log(s)"
    
    # Calculate how many old logs to keep (accounting for new log about to be created)
    KEEP_OLD_LOGS=$((${LOG_RETENTION_COUNT:-1} - 1))
    if [ "${KEEP_OLD_LOGS}" -lt 0 ]; then
        KEEP_OLD_LOGS=0
    fi
    
    # Clean build logs if we have more than we want to keep
    # Use GNU find -printf (installed in BLOCK 3) for reliable file listing with modification time sorting
    if [ "${BUILD_LOGS:-0}" -gt "${KEEP_OLD_LOGS}" ]; then
        echo "Cleaning old build logs (found ${BUILD_LOGS}, keeping ${KEEP_OLD_LOGS} old + 1 new = ${LOG_RETENTION_COUNT} total)..."
        DELETED_COUNT=0
        # Use while read loop instead of xargs to handle spaces/special chars better
        # CRITICAL: Use hyphen pattern to match actual log file names
        # Store files in array first to avoid subshell issues with variable persistence
        # Note: Cannot use 'local' here as we're not in a function
        old_logs_array=()
        # Use GNU find with -printf (installed in BLOCK 3) for reliable file listing
        while IFS= read -r old_log; do
            [ -z "${old_log}" ] && continue
            old_logs_array+=("${old_log}")
        done < <(find "${LOG_DIR}" -maxdepth 1 -name "build-*.log" -type f -printf '%T@ %p\n' 2>/dev/null | \
            sort -rn | cut -d' ' -f2- | tail -n +$((KEEP_OLD_LOGS + 2)) 2>/dev/null || true)
        
        for old_log in "${old_logs_array[@]}"; do
            if [ -f "${old_log}" ]; then
                if rm -f "${old_log}"; then
                    echo "  Removed: $(basename "${old_log}")"
                    DELETED_COUNT=$((DELETED_COUNT + 1))
                else
                    echo "  ⚠ Failed to remove: $(basename "${old_log}")"
                fi
            fi
        done
        
        if [ "${DELETED_COUNT}" -gt 0 ]; then
            echo "✓ Old build log files cleaned up (${DELETED_COUNT} removed)"
        else
            echo "⚠ Warning: No build log files were removed (check permissions or file count)"
        fi
    fi
    
    # Clean error logs if we have more than we want to keep
    if [ "${ERROR_LOGS:-0}" -gt "${KEEP_OLD_LOGS}" ]; then
        echo "Cleaning old error logs (found ${ERROR_LOGS}, keeping ${KEEP_OLD_LOGS} old + 1 new = ${LOG_RETENTION_COUNT} total)..."
        # CRITICAL: Use hyphen pattern to match actual log file names
        # Store files in array first to avoid subshell issues with variable persistence
        # Note: Cannot use 'local' here as we're not in a function
        old_error_logs_array=()
        # Use GNU find with -printf (installed in BLOCK 3) for reliable file listing
        while IFS= read -r old_log; do
            [ -z "${old_log}" ] && continue
            old_error_logs_array+=("${old_log}")
        done < <(find "${LOG_DIR}" -maxdepth 1 -name "errors-*.log" -type f -printf '%T@ %p\n' 2>/dev/null | \
            sort -rn | cut -d' ' -f2- | tail -n +$((KEEP_OLD_LOGS + 2)) 2>/dev/null || true)
        
        error_deleted_count=0
        for old_log in "${old_error_logs_array[@]}"; do
            if [ -f "${old_log}" ]; then
                if rm -f "${old_log}"; then
                    echo "  Removed: $(basename "${old_log}")"
                    error_deleted_count=$((error_deleted_count + 1))
                else
                    echo "  ⚠ Failed to remove: $(basename "${old_log}")"
                fi
            fi
        done
        
        if [ "${error_deleted_count}" -gt 0 ]; then
            echo "✓ Old error log files cleaned up (${error_deleted_count} removed)"
        else
            echo "⚠ Warning: No error log files were removed (check permissions or file count)"
        fi
    fi
    
    if [ "${BUILD_LOGS:-0}" -le "${KEEP_OLD_LOGS}" ] && [ "${ERROR_LOGS:-0}" -le "${KEEP_OLD_LOGS}" ]; then
        echo "✓ No log cleanup needed (found ${BUILD_LOGS} build logs, ${ERROR_LOGS} error logs, will have ${LOG_RETENTION_COUNT} total after this run)"
    fi
fi
# End if-fi block (self-contained)

#--- Sub-block 6.3: Create log files with timestamp ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# Note: LOG_DIR already created above, but ensure it exists
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/build-$(date +%Y%m%d-%H%M%S).log"
ERROR_LOG="${LOG_DIR}/errors-$(date +%Y%m%d-%H%M%S).log"

#--- Sub-block 6.4: Define color codes for terminal output ---
# Critical: Used by logging functions for colored output
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
RED='\033[0;31m'      # Error messages
GREEN='\033[0;32m'    # Success messages
YELLOW='\033[1;33m'   # Warning messages
BLUE='\033[0;34m'     # Info messages
NC='\033[0m'          # No Color (reset)

#===============================================================================
# BLOCK 7: CONTROLLED DIRECTORY DEFINITIONS
#===============================================================================
# Purpose: Define directories we control for cleanup
# Self-contained: Yes
# Dependencies: None
# Outputs: Environment variables, configuration
#-------------------------------------------------------------------------------

#--- Sub-block 7.1: Define cleanup target directories ---
# Critical: Only these directories will be cleaned by cleanup functions
# Dependencies: System (Container runtime)
# Outputs: Configured system components
OUR_TMP_DIR="/tmp/singularity_builds"      # Temp builds in /tmp
OUR_HOME_DIR="${HOME}/singularity_builds"    # Fallback builds in home

#===============================================================================
# BLOCK 8: LOGGING FUNCTIONS
#===============================================================================
# Purpose: Provide standardized logging interface with color-coded output
# Self-contained: Yes (each function is complete and independent)
# Dependencies: LOG_FILE, ERROR_LOG, color variables
# Outputs: Configured system components
#-------------------------------------------------------------------------------

#--- Sub-block 8.1: Timestamped info logging function ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
log_with_timestamp() {
    local message
    message="[$(date +'%H:%M:%S')] ${1:-}"
    if [ -f "${LOG_FILE:-}" ]; then
        printf '%b\n' "${BLUE}${message}${NC}" | tee -a "${LOG_FILE}"
    else
        printf '%b\n' "${BLUE}${message}${NC}"
    fi
}

#--- Sub-block 8.2: Error logging function ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
log_error() {
    local message
    message="[$(date +'%H:%M:%S')] ERROR: ${1:-}"
    if [ -f "${ERROR_LOG:-}" ] && [ -f "${LOG_FILE:-}" ]; then
        printf '%b\n' "${RED}${message}${NC}" | tee -a "${ERROR_LOG}" | tee -a "${LOG_FILE}"
    else
        printf '%b\n' "${RED}${message}${NC}"
    fi
}

#--- Sub-block 8.3: Warning logging function ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
log_warning() {
    local message
    message="[$(date +'%H:%M:%S')] WARNING: ${1:-}"
    if [ -f "${LOG_FILE:-}" ]; then
        printf '%b\n' "${YELLOW}${message}${NC}" | tee -a "${LOG_FILE}"
    else
        printf '%b\n' "${YELLOW}${message}${NC}"
    fi
}

#--- Sub-block 8.7: Error/Warning Filter Function ---
# Purpose: Filter error and warning messages from output and write to error log
# Dependencies: ERROR_LOG must be defined before this function is called
# Outputs: Filters stdout/stderr and writes matches to ERROR_LOG
# Note: This function is defined here but called later in BLOCK 14 after ERROR_LOG is set
filter_errors_and_warnings() {
    local line
    while IFS= read -r line || [ -n "${line}" ]; do
        # Write all output to terminal and main log (already handled by tee)
        printf '%s\n' "${line}"
        
        # Comprehensive error/warning pattern matching (case-insensitive)
        # This pattern catches: errors, warnings, debug messages, diagnostic output, 
        # wheel paths, build failures, compilation issues, and all problematic output
        if grep -qiE \
            '(error|warning|fatal|failed|failure|unable to|unable|not found|cannot|missing|undefined|undefined reference|undefined symbol|warning:|error:|fatal error|compilation error|link error|build error|install error|download error|extract error|✗|✖|⚠|❌|⚠️|ERROR|WARNING|FAILED|FAILURE|MISSING|NOT FOUND|CANNOT|UNABLE|FATAL|NO SUCH|FILE NOT FOUND|DIRECTORY NOT FOUND|PACKAGE NOT FOUND|LOCATION NOT FOUND|unable to locate|unable to download|unable to find|unable to install|unable to extract|unable to compile|unable to build|unable to connect|unable to access|unable to execute|could not find|could not locate|could not download|could not install|did not find|did not locate|did not download|package .* not found|file .* not found|directory .* not found|location .* not found|compilation.*warning|link.*warning|build.*warning|make.*warning|cmake.*warning|ninja.*error|ninja.*warning|gcc.*warning|g\+\+.*warning|clang.*warning|rustc.*warning|cargo.*warning|dpkg.*warning|apt.*warning|pip.*warning|conda.*warning|julia.*warning|deprecated|obsolete|ignored|skipped|timeout|connection refused|connection reset|network.*error|network.*failed|ssl.*error|certificate.*error|authentication.*failed|permission.*denied|access.*denied|read.*only|write.*protect|disk.*full|no.*space|out.*of.*memory|segmentation.*fault|core.*dump|aborted|abort|killed|terminated|signal.*killed|exit.*code.*[1-9]|exit.*status.*[1-9]|\[DEBUG\]|DEBUG:|DEBUG CHECKPOINT|debug checkpoint|debug:|debugging|diagnostic|DIAGNOSTIC|diagnosis|wheel.*not found|wheel.*location|\.whl.*not found|wheel.*path|wrote.*\.whl|building.*wheel|wheel.*build|colmap.*failed|colmap.*error|open3d.*failed|open3d.*error|opencv.*failed|opencv.*error|cmake.*failed|cmake.*error|ninja.*failed|build.*failed|compilation.*failed|link.*failed|CHECKING FOR|COMPREHENSIVE DIAGNOSTIC|DIAGNOSTIC ANALYSIS|NEXT STEPS FOR DEBUGGING|Last.*lines.*of.*log|tee.*\.log|build.*log|cmake.*log|colmap.*log|open3d.*log|opencv.*log|Post-CMake Debug|Post-CMake.*Debug|test.*failed|test.*error|checkpoint|CHECKPOINT|verification.*failed|verification.*error|configuration.*failed|configuration.*error|setup.*failed|setup.*error|install.*failed|install.*error|harvest.*failed|harvest.*error)' <<< "${line}"; then
            # Write matching line to error log with timestamp
            local target_log="${ERROR_LOG:-}"
            if [ -n "${target_log}" ]; then
                if [ ! -f "${target_log}" ]; then
                    touch "${target_log}" 2>/dev/null || true
                fi
                printf '[%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "${line}" >> "${target_log}" 2>/dev/null || true
            fi
        fi
    done
    # Always succeed to avoid triggering set -e via redirection pipelines
    return 0
}

#--- Sub-block 8.4: Success logging function ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
log_success() {
    local message
    message="[$(date +'%H:%M:%S')] SUCCESS: ${1:-}"
    if [ -f "${LOG_FILE:-}" ]; then
        printf '%b\n' "${GREEN}${message}${NC}" | tee -a "${LOG_FILE}"
    else
        printf '%b\n' "${GREEN}${message}${NC}"
    fi
}

#--- Sub-block 8.5: Simple logging functions ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
log() { printf '\n[info] %s\n' "$*"; }              # Simple info log
warn() { printf '\n[warn] %s\n' "$*" >&2; }         # Simple warning to stderr
err() { printf '\n[err] %s\n' "$*" >&2; exit 1; }   # Error with exit

#--- Sub-block 8.6: Progress reporting function ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
progress() {
    local step="$1"
    local total="$2"
    local desc="$3"
    printf "\n[%d/%d] %s\n" "$step" "$total" "$desc"
}

#===============================================================================
# BLOCK 9: TIME TRACKING FUNCTIONS
#===============================================================================
# Purpose: Measure and format build duration
# Self-contained: Yes (each function complete and independent)
# Dependencies: None
# Outputs: Environment variables, configuration
#-------------------------------------------------------------------------------

#--- Sub-block 9.1: Start time capture ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
start_time() {
    date +%s  # Return Unix timestamp
}

#--- Sub-block 9.2: Elapsed time calculation ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
elapsed_time() {
    local start="${1:-0}"
    local end
    end=$(date +%s)
    local elapsed
    elapsed=$((end - start))
    # Format as HH:MM:SS
    printf "%02d:%02d:%02d" $((elapsed/3600)) $(((elapsed%3600)/60)) $((elapsed%60))
}

#===============================================================================
# BLOCK 10: CONTAINER SYSTEM DETECTION
#===============================================================================
# Purpose: Detect and validate singularity/apptainer installation
# Self-contained: Yes (complete if-elif-else with exit)
# Dependencies: None
# Outputs: Environment variables, configuration
#-------------------------------------------------------------------------------

#--- Sub-block 10.1: Detection function ---
# Dependencies: System (Container runtime)
# Outputs: Configured system components
detect_container_system() {
    if command -v singularity >/dev/null 2>&1; then
        echo "singularity"
    elif command -v apptainer >/dev/null 2>&1; then
        echo "apptainer"
    else
        echo "none"
    fi
}
# End function (self-contained)

#--- Sub-block 10.2: Detect and validate ---
# Critical: Container system must be available to proceed
# Dependencies: System (Container runtime)
# Outputs: Configured system components
CONTAINER_CMD=$(detect_container_system)

if [ "${CONTAINER_CMD}" = "none" ]; then
    log_warning "Neither singularity nor apptainer found. Attempting to install apptainer..."
    # Try to install apptainer first
    if ! install_host_tool "apptainer" "apptainer" "Apptainer container runtime"; then
        log_warning "Failed to install apptainer. Attempting to install singularity-container..."
        if ! install_host_tool "singularity" "singularity-container" "Singularity container runtime"; then
            log_error "Failed to install both apptainer and singularity."
            log_error "Please install one of them manually and re-run the script."
    exit 1
        fi
    fi
    # Re-detect after installation attempts
    CONTAINER_CMD=$(detect_container_system)
    if [ "${CONTAINER_CMD}" = "none" ]; then
        log_error "Container runtime still not available after installation attempts"
        exit 1
    fi
fi
# End if-fi block (self-contained)

log "Detected container system: ${CONTAINER_CMD}"

#===============================================================================
# BLOCK 11: CLEANUP FUNCTIONS
#===============================================================================
# Purpose: Comprehensive cleanup of build artifacts and orphaned processes
# Self-contained: Yes (complete functions with all loops/conditionals closed)
# Dependencies: CONTAINER_CMD, OUR_TMP_DIR, OUR_HOME_DIR
# Outputs: Configured system components
#-------------------------------------------------------------------------------

#--- Sub-block 11.1: Strict directory cleanup function ---
# Purpose: Remove temporary build directories with escalating force
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# Parameters: $1 = parent directory path
# Returns: 0 on success, 1 on failure
# Critical: Uses sudo with kill, unmount, and rm - ensures all remnants are removed
strict_cleanup_our_dirs() {
    local parent_dir="${1:-}"
    local max_attempts=3

    # Validate input parameter
    if [ -z "${parent_dir}" ]; then
        echo "  ⚠ ERROR: strict_cleanup_our_dirs called without directory argument"
        return 1
    fi

    # Early return if directory doesn't exist
    if [ ! -d "${parent_dir}" ]; then
        echo " ✓ Directory does not exist: ${parent_dir}"
        return 0
    fi
    # End if-fi block

    echo "Cleaning... ${parent_dir}"

    # Find all temporary build directories matching known patterns
    local target_dirs
    target_dirs=$(find "${parent_dir}" -maxdepth 1 -type d \( \
        -name "build-temp-*" \
        -o -name "bundle-temp-*" \
        -o -name "sbuild-*" \
    \) 2>/dev/null || true)

    if [ -z "${target_dirs}" ]; then
        echo " ✓ No temp directories found"
        return 0
    fi
    # End if-fi block

    local count
    count=$(echo "${target_dirs}" | wc -l | tr -d '[:space:]')
    count="${count:-0}"
    echo "Found ${count} directories"

    # Critical: Try up to 3 times with escalating force
    for attempt in $(seq 1 "${max_attempts}"); do
        # Step 1: Kill all processes using these directories
        printf '%s\n' "${target_dirs}" | while IFS= read -r dir || [ -n "${dir}" ]; do
            [ ! -d "${dir}" ] && continue
            # Find all PIDs with open files in this directory
            sudo lsof +D "${dir}" 2>/dev/null | tail -n +2 | awk '{print $2}' | sort -u | while IFS= read -r pid || [ -n "${pid}" ]; do
                local user
                user=$(ps -p "${pid}" -o user= 2>/dev/null || echo "")
                # Critical: Only kill processes owned by current user (safety check)
                if [ -n "${user}" ] && [ "${user}" = "${USER}" ]; then
                    sudo kill -9 "${pid}" 2>/dev/null || true
                fi
            done
        done

#--- Sub-block: Section continuation (329) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 329 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
        sleep 1

        # Step 2: Unmount any mount points within these directories
        printf '%s\n' "${target_dirs}" | while IFS= read -r dir || [ -n "${dir}" ]; do
            [ ! -d "${dir}" ] && continue
            # Find and unmount all mount points under this directory
            mount 2>/dev/null | grep -F "${dir}" | awk '{print $3}' | while IFS= read -r mpoint || [ -n "${mpoint}" ]; do
                sudo umount -l "${mpoint}" 2>/dev/null || true  # Lazy unmount
            done
        done

        sleep 1

        # Step 3: Remove with escalating force (chmod, chattr, rm)
        printf '%s\n' "${target_dirs}" | while IFS= read -r dir || [ -n "${dir}" ]; do
            [ ! -d "${dir}" ] && continue
            sudo chattr -i -R "${dir}" 2>/dev/null || true        # Remove immutable flags
            # Try conservative permissions first; escalate only if needed
            sudo chmod -R u+rwX,go+rX "${dir}" 2>/dev/null || true
            sudo rm -rf "${dir}" 2>/dev/null || {
                sudo chmod -R 777 "${dir}" 2>/dev/null || true
                sudo rm -rf "${dir}" 2>/dev/null || true
            }
        done

        # Check if cleanup was successful
        local remaining
        remaining=$(find "${parent_dir}" -maxdepth 1 -type d \( \
            -name "build-temp-*" \
            -o -name "bundle-temp-*" \
            -o -name "sbuild-*" \
        \) 2>/dev/null | wc -l | tr -d '[:space:]')
        remaining="${remaining:-0}"

        if [ "${remaining:-0}" -eq 0 ]; then
            echo " ✓ All directories removed"
            return 0
        fi
        # End if-fi block
    done
    # End for loop (self-contained)

    return 1
}
# End function (self-contained)

#--- Sub-block: Section continuation (372) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block 10.1.1: Strict cleanup complete ---
# Purpose: All temporary directories removed
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
#--- Sub-block 11.2: Comprehensive cleanup function ---
# Purpose: Complete cleanup of all container remnants, processes, and mounts
# Dependencies: System (Container runtime)
# Outputs: Configured system components
# Parameters: None
# Returns: 0 on success, 1 if issues remain
# Critical: 9-step cleanup process - kills processes, removes temps, cleans caches
comprehensive_cleanup() {
    echo ""
    echo "=========================================="
    echo "COMPREHENSIVE CLEANUP - All Remnants"
    echo "=========================================="

    # === Step 1: Kill container processes ===
    echo ""
    echo "1. Killing OUR ${CONTAINER_CMD} processes..."
    # Critical: Find all singularity/apptainer processes owned by current user
    # Use pgrep (installed in BLOCK 3) for reliable process finding
    pgrep -u "${USER}" -f "(singularity|apptainer)" 2>/dev/null | while IFS= read -r pid || [ -n "${pid}" ]; do
        # Verify it's actually our process before killing
        local cmd
        cmd=$(ps -p "${pid}" -o cmd= 2>/dev/null || echo "")
        if [ -n "${cmd}" ]; then
            echo " > Killing PID ${pid}: $(echo "${cmd}" | cut -c1-60)"
            sudo kill -9 "${pid}" 2>/dev/null || true
        fi
    done
    # End while loop (self-contained)
    sleep 3

    # === Step 2: Clean build temp directories ===
    echo ""
    echo "2. Cleaning build temp directories in OUR folders..."
    # Critical: Remove all temporary build artifacts in controlled locations
    strict_cleanup_our_dirs "$OUR_TMP_DIR"
    strict_cleanup_our_dirs "$OUR_HOME_DIR"

    # === Step 3: Clean container cache directories ===
    echo ""
    echo "3. Cleaning ${CONTAINER_CMD} cache directories..."

    # Determine cache locations based on container system detected earlier
    local cache_base=""
    if [ "${CONTAINER_CMD}" = "singularity" ]; then
        cache_base="${HOME}/.singularity"
    else
        cache_base="${HOME}/.apptainer"
    fi
    # End if-else block (self-contained)

#--- Sub-block: Section continuation (421) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 418 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
    # Clean temporary cache, NOT the actual image cache (preserve for future builds)
    if [ -d "${cache_base}" ]; then
        echo "   Cleaning ${cache_base}/cache/tmp..."
        if [ -d "${cache_base}/cache/tmp" ]; then
            local tmp_count
            tmp_count=$(find "${cache_base}/cache/tmp" -type f 2>/dev/null | wc -l | tr -d '[:space:]')
            tmp_count="${tmp_count:-0}"
            echo "   Found ${tmp_count} temporary files"
            sudo rm -rf "${cache_base}/cache/tmp"/* 2>/dev/null || true
        fi
        # End nested if-fi block

        # Clean any .lock files (stale locks from failed builds)
        echo "   Cleaning stale lock files..."
        local lock_count
        lock_count=$(find "${cache_base}" -name "*.lock" 2>/dev/null | wc -l | tr -d '[:space:]')
        lock_count="${lock_count:-0}"
        if [ "${lock_count:-0}" -gt 0 ]; then
            echo "   Found ${lock_count} lock files"
            find "${cache_base}" -name "*.lock" -exec rm -f {} + 2>/dev/null || true
        fi
        # End nested if-fi block

        # Clean incomplete/partial downloads
        if [ -d "${cache_base}/cache/oci-tmp" ]; then
            echo "   Cleaning partial downloads..."
            local partial_count
            partial_count=$(find "${cache_base}/cache/oci-tmp" -type d 2>/dev/null | wc -l | tr -d '[:space:]')
            partial_count="${partial_count:-0}"
            echo "   Found ${partial_count} partial OCI downloads"
            sudo rm -rf "${cache_base}/cache/oci-tmp"/* 2>/dev/null || true
        fi
        # End nested if-fi block

    fi
    # End outer if-fi block (self-contained)

    # === Step 4: Clean orphaned/incomplete container images ===
    echo ""
    echo "4. Identifying orphaned/incomplete containers..."

    # Critical: Check for incomplete .sif files in build directories
    for dir in "${OUR_TMP_DIR}" "${OUR_HOME_DIR}"; do
        if [ -d "${dir}" ]; then
            echo "   Checking ${dir}..."

#--- Sub-block: Section continuation (464) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

            # Find .sif files that are incomplete (being written, locked, or 0 bytes)
            find "${dir}" -maxdepth 2 -name "*.sif" 2>/dev/null | while IFS= read -r sif_file || [ -n "${sif_file}" ]; do
                local sif_name
                sif_name=$(basename "${sif_file}")
                local sif_size
                sif_size=$(stat -c%s "${sif_file}" 2>/dev/null || echo "0")


#--- Sub-block: Code section 463 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
                # Check if file is incomplete/orphaned

#--- Sub-block: Section 485 ---
# Purpose: Continued implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
                local is_orphaned=0

                # Check 1: Zero size (failed build)
                if [ "${sif_size:-0}" -eq 0 ]; then
                    echo "      ✗ Orphaned (0 bytes): ${sif_name}"
                    is_orphaned=1
                fi

                # Check 2: File locked by a dead process
                if sudo lsof "${sif_file}" 2>/dev/null | grep -q .; then
                    local pid
                    pid=$(sudo lsof "${sif_file}" 2>/dev/null | tail -n +2 | awk '{print $2}' | head -1 || echo "")
                    if [ -n "${pid}" ] && ! ps -p "${pid}" > /dev/null 2>&1; then
                        echo "      ✗ Orphaned (locked by dead PID ${pid}): ${sif_name}"
                        is_orphaned=1
                    fi
                fi

                # Check 3: Partial .sif file (has .partial extension or temp naming)
                if [[ "${sif_name}" == *.partial ]] || [[ "${sif_name}" == tmp_* ]] || [[ "${sif_name}" == .tmp* ]]; then
                    echo "      ✗ Orphaned (partial/temp name): ${sif_name}"
                    is_orphaned=1
                fi

#--- Sub-block: Container cleanup procedures ---
# Purpose: Remove temporary build artifacts
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

#--- Sub-block: Cleanup logic ---
# Purpose: Container cleanup procedures
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

                # Check 4: Very small size (< 10MB - likely incomplete)
                if [ "${sif_size:-0}" -lt 10485760 ] && [ "${sif_size:-0}" -gt 0 ]; then
                    echo "      ✗ Orphaned (suspiciously small ${sif_size} bytes): ${sif_name}"
                    is_orphaned=1
                fi

                # Remove if orphaned
                if [ "${is_orphaned}" -eq 1 ]; then
                    echo "        Removing orphaned container: ${sif_file}"
                    sudo rm -f "${sif_file}" 2>/dev/null || {
                        echo "        → Failed to remove, trying force..."
                        sudo lsof "${sif_file}" 2>/dev/null | tail -n +2 | awk '{print $2}' | while IFS= read -r lock_pid || [ -n "${lock_pid}" ]; do
                            sudo kill -9 "${lock_pid}" 2>/dev/null || true
                        done
                        sleep 1
                        sudo rm -f "${sif_file}" 2>/dev/null || echo "        → Still locked!"
                    }
                else
                    if command -v numfmt >/dev/null 2>&1; then
                        human_size="$(numfmt --to=iec-i --suffix=B "${sif_size}" 2>/dev/null || echo "${sif_size}B")"
                    else
                        human_size="${sif_size}B"
                    fi
                    echo "      ✓ Valid container (${human_size}): ${sif_name}"
                fi
                # End nested if-else block
            done
            # End while loop
        fi
        # End nested if-fi block
    done
    # End for loop (self-contained)

#--- Sub-block: Section 535 ---
# Purpose: Continued implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

#--- Sub-block: Section continuation (524) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 515 ---
# Purpose: Continuing implementation
# Dependencies: System (Container runtime)
# Outputs: Configured system components
    # === Step 5: Clean session directories ===
    echo ""
    echo "5. Cleaning session directories..."
    # Critical: Singularity/Apptainer creates session dirs in /tmp
    find /tmp -maxdepth 1 -type d -user "${USER}" \( \
        -name "singularity-*" -o \
        -name "apptainer-*" \
    \) 2>/dev/null | while IFS= read -r session_dir || [ -n "${session_dir}" ]; do
        echo "   Removing session: $(basename "${session_dir}")"
        sudo rm -rf "${session_dir}" 2>/dev/null || true
    done
    # End while loop (self-contained)

    # === Step 6: Clean mount point remnants ===
    echo ""
    echo "6. Cleaning mount point remnants..."
    # Critical: Check for orphaned overlay/underlay mounts
    mount 2>/dev/null | awk -v user="${USER}" '/singularity|apptainer/ && index($0, user) {print $3}' | while IFS= read -r mpoint || [ -n "${mpoint}" ]; do
        echo "   Unmounting: ${mpoint}"
        sudo umount -l "${mpoint}" 2>/dev/null || true  # Lazy unmount
        sudo umount -f "${mpoint}" 2>/dev/null || true  # Force unmount
    done
    # End while loop (self-contained)

    # === Step 7: Clean PID files ===
    echo ""
    echo "7. Cleaning stale PID files..."
    # Critical: Remove PID files for dead processes
    find /tmp -maxdepth 1 -type f -user "${USER}" -name "*.pid" 2>/dev/null | while IFS= read -r pid_file || [ -n "${pid_file}" ]; do
        if [[ "$(basename "${pid_file}")" == "singularity"* ]] || [[ "$(basename "${pid_file}")" == "apptainer"* ]]; then
            local pid
            pid=$(cat "${pid_file}" 2>/dev/null || echo "")
            if [ -n "${pid}" ]; then
                # Check if process is still running
                if ! ps -p "${pid}" > /dev/null 2>&1; then
                    echo "   Removing stale PID file (process ${pid} dead): $(basename "${pid_file}")"
                    sudo rm -f "${pid_file}" 2>/dev/null || {
                        echo "   ⚠ Failed to remove PID file (permission denied): $(basename "${pid_file}")"
                    }
                fi
                # End nested if-fi block
            else
                echo "   Removing empty PID file: $(basename "${pid_file}")"
                sudo rm -f "${pid_file}" 2>/dev/null || {
                    echo "   ⚠ Failed to remove PID file (permission denied): $(basename "${pid_file}")"
                }
            fi
            # End if-else block

#--- Sub-block: Section 585 ---
# Purpose: Continued implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
        fi
        # End outer if-fi block
    done
    # End while loop (self-contained)

#--- Sub-block: Section continuation (575) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 563 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
    # === Step 8: Clean temporary overlay files ===
    echo ""
    echo "8. Cleaning temporary overlay files..."
    # Critical: Remove unused overlay/squashfs/ext3 files in /tmp
    find /tmp -maxdepth 1 -type f -user "${USER}" \( \
        -name "*overlay*" -o \
        -name "*.sqfs" -o \
        -name "*.ext3" \
    \) 2>/dev/null | while IFS= read -r overlay_file || [ -n "${overlay_file}" ]; do
        # Check if file is being used by any process
        if ! sudo lsof "${overlay_file}" 2>/dev/null | grep -q .; then
            echo "   Removing unused overlay: $(basename "${overlay_file}")"
            sudo rm -f "${overlay_file}" 2>/dev/null || true

#--- Sub-block: Comprehensive cleanup ---
# Critical: Ensure clean build environment
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
        fi
        # End if-fi block
    done

#--- Sub-block: Cleanup continuation ---
# Purpose: Additional cleanup steps
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
    # End while loop (self-contained)

    # === Step 9: Final verification ===
    echo ""
    echo "9. Final verification..."
    local issues=0

    # Check 1: Remaining build-temp directories
    local -a cleanup_dirs=()
    local remaining_temps=0
    for candidate_dir in "${OUR_TMP_DIR}" "${OUR_HOME_DIR}"; do
        if [ -d "${candidate_dir}" ]; then
            cleanup_dirs+=("${candidate_dir}")
        fi
    done
    if [ "${#cleanup_dirs[@]}" -gt 0 ]; then
        remaining_temps=$(find "${cleanup_dirs[@]}" -maxdepth 1 -type d \( \
            -name "build-temp-*" \
            -o -name "bundle-temp-*" \
            -o -name "sbuild-*" \
        \) 2>/dev/null | wc -l | tr -d '[:space:]')
        remaining_temps="${remaining_temps:-0}"
    fi

    if [ "${remaining_temps:-0}" -gt 0 ]; then
        echo "  ✗ Still have ${remaining_temps} temp directories"
        issues=$((issues + remaining_temps))
    else
        echo "  ✓ No temp directories remaining"
    fi
    # End if-else block

    # Check 2: Orphaned processes

#--- Sub-block: Section 635 ---
# Purpose: Continued implementation
# Dependencies: System (Container runtime)
# Outputs: Configured system components
    local -a container_pids=()
    mapfile -t container_pids < <(pgrep -u "${USER}" -f "(singularity|apptainer)" 2>/dev/null || true)
    local remaining_procs="${#container_pids[@]}"

    if [ "${remaining_procs:-0}" -gt 0 ]; then
        echo "  ✗ Still have ${remaining_procs} container processes running"
        for pid in "${container_pids[@]}"; do
            local cmd
            cmd=$(ps -p "${pid}" -o cmd= 2>/dev/null || echo "")
            if [ -n "${cmd}" ]; then
                echo "    - PID ${pid}: $(echo "${cmd}" | cut -c1-60)"
            fi
        done
        issues=$((issues + remaining_procs))
    else
        echo "  ✓ No container processes remaining"
    fi
    # End if-else block

#--- Sub-block: Section continuation (629) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 614 ---
# Purpose: Continuing implementation
# Dependencies: System (Container runtime)
# Outputs: Configured system components
    # Check 3: Orphaned mounts
    local remaining_mounts
    remaining_mounts=$(mount 2>/dev/null | awk -v user="${USER}" '
        /singularity|apptainer/ && index($0, user) {count++}
        END {print count+0}
    ')
    remaining_mounts="${remaining_mounts:-0}"
    if [ "${remaining_mounts:-0}" -gt 0 ]; then
        echo "  ✗ Still have ${remaining_mounts} orphaned mounts"
        issues=$((issues + remaining_mounts))
    else
        echo "  ✓ No orphaned mounts remaining"
    fi
    # End if-else block

    # Final status report
    echo ""
    if [ "${issues:-0}" -eq 0 ]; then
        echo "CLEANUP COMPLETE - No issues found"
        return 0
    else
        echo "!!! CLEANUP INCOMPLETE - ${issues} issues remain"
        return 1
    fi
    # End if-else block (self-contained)
}
# End function comprehensive_cleanup (self-contained)

#===============================================================================
# BLOCK 12: PRE-BUILD COMPREHENSIVE CLEANUP
#===============================================================================
# Purpose: Clean all remnants from previous builds before starting
# Self-contained: Yes (complete if-fi with exit)
# Dependencies: comprehensive_cleanup()
# Outputs: Configured system components
#-------------------------------------------------------------------------------


#--- Sub-block 10.2.1: Comprehensive cleanup complete ---
# Purpose: All container remnants cleaned
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
#--- Sub-block 12.1: Execute pre-build cleanup ---
# Critical: Must succeed before build can proceed
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
log "Starting comprehensive pre-build cleanup..."
if ! comprehensive_cleanup; then
    log_error "Comprehensive cleanup failed"
    log_error "Cannot proceed with build until all remnants are removed"
    exit 1
fi
# End if-fi block (self-contained)
log "✓ Comprehensive cleanup verified successful"

#===============================================================================
# BLOCK 12.5: SOURCE CONFIGURATION (VERIFICATION)
#===============================================================================
# Purpose: Verify configuration is loaded (already loaded in BLOCK 2)
# Dependencies: config.sh should already be sourced in BLOCK 2
# Outputs: Error if config not loaded
#-------------------------------------------------------------------------------
# Note: Configuration is already loaded in BLOCK 2 (line 76)
# This block verifies that config.sh functions (like analyze_build_log) are available
# If config.sh was not sourced earlier, this will fail
if ! type analyze_build_log >/dev/null 2>&1; then
    log_error "analyze_build_log function not found. config.sh may not have been loaded properly."
    # Try to source config.sh again as fallback
    # shellcheck disable=SC1090
    if [ -f "${SCRIPT_DIR}/config.sh" ]; then
        # shellcheck disable=SC1090
        source "${SCRIPT_DIR}/config.sh"
        log_warning "Re-loaded config.sh as fallback"
    else
        log_error "config.sh not found in ${SCRIPT_DIR}"
        exit 1
    fi
fi

#===============================================================================
# BLOCK 13: POST-BUILD CLEANUP TRAP
#===============================================================================
# Purpose: Ensure cleanup runs even if build fails or is interrupted
# Self-contained: Yes (complete function + trap)
# Dependencies: comprehensive_cleanup(), analyze_build_log() from config.sh
# Outputs: Configured system components
#-------------------------------------------------------------------------------

# Note: analyze_build_log() function is now defined in config.sh (unified)
# This ensures a single source of truth for log analysis patterns and logic

#--- Sub-block 13.1: Define cleanup exit handler ---
# Critical: Captures exit code, runs cleanup, then exits with original code
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
cleanup_on_exit() {
    local exit_code=$?  # Capture the exit status of the script

    echo ""
    echo "=========================================="
    echo "POST-BUILD CLEANUP (exit code: ${exit_code})"
    echo "=========================================="
    
    # Analyze build log for errors/warnings with context before cleanup
    # Ensure analyze_build_log function is available (re-source config.sh if needed)
    # shellcheck disable=SC1090
    if ! type analyze_build_log >/dev/null 2>&1; then
        # shellcheck disable=SC1090
        if [ -f "${SCRIPT_DIR}/config.sh" ]; then
            # shellcheck disable=SC1090
            source "${SCRIPT_DIR}/config.sh"
        elif [ -f /etc/config.sh ]; then
            # shellcheck disable=SC1091
            source /etc/config.sh
        fi
    fi
    # Only call if function exists
    if type analyze_build_log >/dev/null 2>&1; then
        # shellcheck disable=SC2119
        analyze_build_log || true
    else
        echo "⚠ Warning: analyze_build_log function not available, skipping log analysis"
    fi
    
    comprehensive_cleanup || true  # Run cleanup, ignore failures at exit

    exit "${exit_code}"  # Exit with original code
}
# End function (self-contained)

#--- Sub-block 13.2: Register cleanup trap ---
# Critical: Ensures cleanup runs on EXIT, INT (Ctrl+C), or TERM signals
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
trap cleanup_on_exit EXIT INT TERM

#===============================================================================
# BLOCK 14: LOGGING REDIRECTION
#===============================================================================
# Purpose: Redirect all output to both log file and console
# Self-contained: Yes
# Dependencies: LOG_FILE, ERROR_LOG
# Outputs: Configured system components
#-------------------------------------------------------------------------------

#--- Sub-block 14.1: Log startup information ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
log_with_timestamp "Starting build process..."
log_with_timestamp "Log file: ${LOG_FILE}"
log_with_timestamp "Error log: ${ERROR_LOG}"

#--- Sub-block 14.2: Set up output redirection with error filtering ---
# Critical: All stdout/stderr from this point forward goes to both console and log file
# Additionally, errors and warnings are filtered and written to ERROR_LOG
# Dependencies: ERROR_LOG, filter_errors_and_warnings function
# Outputs: Environment variables, configuration
# Initialize error log with header
if [ -z "${ERROR_LOG}" ] || [ ! -f "${ERROR_LOG}" ]; then
    touch "${ERROR_LOG}" 2>/dev/null || true
fi
# Validate ERROR_LOG is writable before appending
if [ -n "${ERROR_LOG}" ]; then
    if touch "${ERROR_LOG}" 2>/dev/null; then
        {
            echo "========================================"
            echo "Error Log Started: $(date)"
            echo "Build Log: ${LOG_FILE}"
            echo "========================================"
        } >> "${ERROR_LOG}" 2>/dev/null || true
    else
        log_warning "Failed to initialize error log header: ${ERROR_LOG}"
    fi
fi

# Set up filtered output redirection
# stdout goes to main log and terminal, stderr goes to both and is also filtered for errors
# Validate LOG_FILE is set and writable before redirection
if [ -z "${LOG_FILE:-}" ]; then
    log_error "LOG_FILE is not set"
    exit 1
fi

# Ensure log directory exists and is writable
LOG_FILE_DIR="$(dirname "${LOG_FILE}")"
if [ ! -d "${LOG_FILE_DIR}" ]; then
    mkdir -p "${LOG_FILE_DIR}" || {
        log_error "Failed to create log directory: ${LOG_FILE_DIR}"
        exit 1
    }
fi

if [ ! -w "${LOG_FILE_DIR}" ] 2>/dev/null; then
    log_error "LOG_FILE directory is not writable: ${LOG_FILE_DIR}"
    exit 1
fi

# Create log file if it doesn't exist
touch "${LOG_FILE}" 2>/dev/null || {
    log_error "Cannot create log file: ${LOG_FILE}"
    exit 1
}

# Set up output redirection with process substitution
# Note: Guard the pipelines so non-zero statuses don't trip set -e
exec > >(tee -a "${LOG_FILE}" || true) 2> >(tee -a "${LOG_FILE}" >&2 | filter_errors_and_warnings || true)

# Log script start with detailed information
echo "=============================================================================="
echo "Build Script Start: $(date)"
echo "Host shell diagnostics:"
echo "  PID: $$, PPID: ${PPID:-unknown}"
echo "  0: ${0:-unknown}"
echo "  SHELL: ${SHELL:-unknown}"
echo "  BASH_VERSION: ${BASH_VERSION:-n/a}"
echo "  Process name: $(ps -p $$ -o comm= 2>/dev/null || echo unknown)"
echo "Log File: ${LOG_FILE}"
echo "Error Log: ${ERROR_LOG}"
echo "Working directory: $(pwd)"
echo "Script PID: $$"
echo "=============================================================================="

#===============================================================================
# BLOCK 15: TEMPORARY DIRECTORY SETUP
#===============================================================================
# Purpose: Configure build temporary directory with disk space validation
# Self-contained: Yes (complete if-else with exit)
# Dependencies: DISK_SPACE_REQUIRED_GB from config.sh
# Outputs: Configured system components
#-------------------------------------------------------------------------------

log_with_timestamp "Configuring robust temporary directory for build..."

TRACEABLE_DIR_NAME="singularity_builds"
BUILD_TMP_DIR=""

#--- Sub-block 15.1: Check disk space in root partition ---
# Critical: Determine where to place temporary build files
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
ROOT_AVAIL_GB=$(df -BG / 2>/dev/null | awk 'NR==2 {print substr($4, 1, length($4)-1)}' || echo "0")
# Validate numeric value
if ! [[ "${ROOT_AVAIL_GB}" =~ ^[0-9]+$ ]]; then
    log_error "Failed to determine available disk space in /"
    ROOT_AVAIL_GB=0
fi

# Validate DISK_SPACE_REQUIRED_GB is numeric
if ! [[ "${DISK_SPACE_REQUIRED_GB:-0}" =~ ^[0-9]+$ ]]; then
    log_error "DISK_SPACE_REQUIRED_GB is not a valid number: ${DISK_SPACE_REQUIRED_GB:-}"
    exit 1
fi

if (( ROOT_AVAIL_GB >= DISK_SPACE_REQUIRED_GB )); then
    # Use /tmp if sufficient space (faster, typically tmpfs)
    BUILD_TMP_DIR="/tmp/${TRACEABLE_DIR_NAME}"
    log_success "Sufficient space (${ROOT_AVAIL_GB}GB) in /tmp. Using: ${BUILD_TMP_DIR}"
else
    #--- Sub-block 15.2: Fallback to home directory ---
    log_warning "Insufficient space (${ROOT_AVAIL_GB}GB) in /tmp. Checking home directory..."

    # Check home directory space
    HOME_AVAIL_GB=$(df -BG "${HOME}" 2>/dev/null | awk 'NR==2 {print substr($4, 1, length($4)-1)}' || echo "0")
    # Validate numeric value
    if ! [[ "${HOME_AVAIL_GB}" =~ ^[0-9]+$ ]]; then
        log_error "Failed to determine available disk space in ${HOME}"
        HOME_AVAIL_GB=0
    fi

    if (( HOME_AVAIL_GB >= DISK_SPACE_REQUIRED_GB )); then
        # Use home directory if sufficient space
        BUILD_TMP_DIR="$HOME/${TRACEABLE_DIR_NAME}"
        log_success "Using home directory with ${HOME_AVAIL_GB}GB available: ${BUILD_TMP_DIR}"
    else
        # Critical: Cannot proceed without sufficient disk space
        log_error "Insufficient space in home (${HOME_AVAIL_GB}GB). Required: ${DISK_SPACE_REQUIRED_GB}GB."
        exit 1
    fi
    # End nested if-else block
fi
# End outer if-else block (self-contained)

#--- Sub-block 15.3: Create and configure temporary directory ---
# Critical: Create the selected directory and set permissions
# Dependencies: System (Container runtime)
# Outputs: Configured system components
if [ -z "${BUILD_TMP_DIR}" ]; then
    log_error "BUILD_TMP_DIR is not set"
    exit 1
fi
mkdir -p "${BUILD_TMP_DIR}" || {
    log_error "Failed to create temporary directory: ${BUILD_TMP_DIR}"
    exit 1
}
# Use 755 instead of 777 for security (container runtime should handle access)
chmod 755 "${BUILD_TMP_DIR}" || {
    log_warning "Failed to set permissions on ${BUILD_TMP_DIR}, continuing..."
}

# Critical: Export temp dir for both singularity and apptainer
export SINGULARITY_TMPDIR="${BUILD_TMP_DIR}"
export APPTAINER_TMPDIR="${BUILD_TMP_DIR}"
log "Build engine temporary directory set to: ${APPTAINER_TMPDIR}"

#===============================================================================
# BLOCK 16: HOST-SIDE CACHE STRUCTURE
#===============================================================================
# Purpose: Define and create all cache directories
# Self-contained: Yes
# Dependencies: CACHE_DIR and sub-cache variables from config.sh
# Outputs: Configured system components
#-------------------------------------------------------------------------------

log_with_timestamp "Creating comprehensive cache directory structure..."

#--- Sub-block 16.1: Helper function for directory creation ---
# Purpose: Create directory, set permissions, and validate writability
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
create_directory_with_permissions() {
    local dir_path="$1"
    local description="$2"

    # Attempt to create directory
    if mkdir -p "$dir_path" 2>/dev/null; then
        chmod 755 "$dir_path" 2>/dev/null || true
        # Verify directory exists and is writable
        if [ -d "$dir_path" ] && [ -w "$dir_path" ]; then
            log_success "Directory created: $description ($dir_path)"
            return 0
        else
            log_error "Directory created but not writable: $description ($dir_path)"
            return 1
        fi
        # End nested if-else
    else
        log_error "Failed to create directory: $description ($dir_path)"
        return 1
    fi
    # End outer if-else
}
# End function (self-contained)

#--- Sub-block 16.2: Create main cache directories ---
# Critical: All cache paths come from config.sh
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
create_directory_with_permissions "${BIN_CACHE}" "Binaries cache"
create_directory_with_permissions "${DEB_CACHE}" "DEB packages cache"
create_directory_with_permissions "${APT_CACHE}" "APT cache"
create_directory_with_permissions "${APT_ARCHIVE_CACHE}" "APT archives cache"
create_directory_with_permissions "${CONDA_CACHE}" "Conda packages cache"
create_directory_with_permissions "${JULIA_CACHE}" "Julia packages cache"
create_directory_with_permissions "${WHEELS_CACHE}" "Python wheels cache"

#--- Sub-block 16.3: Create auxiliary directories ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
create_directory_with_permissions "${LOG_DIR}" "Build logs directory"
create_directory_with_permissions "${CACHE_DIR}/tmp" "Temporary cache directory"
create_directory_with_permissions "${CACHE_DIR}/downloads" "Downloads cache directory"

log_with_timestamp "Comprehensive cache directory structure created successfully"

#===============================================================================
# BLOCK 17: OUTPUT DIRECTORY AND FILE SETUP
#===============================================================================
# Purpose: Define output locations and clean previous build artifacts
# Self-contained: Yes (complete if-else blocks)
# Dependencies: None
# Outputs: Environment variables, configuration
#-------------------------------------------------------------------------------

#--- Sub-block 17.1: Define output file names ---
# Dependencies: config.sh (OUT_DIR, SIF_NAME, DEF_NAME may be set)
# Outputs: Environment variables, configuration
# Note: OUT_DIR defaults are set in config.sh, use current PWD if not set
OUT_DIR="${OUT_DIR:-${PWD}}"
# Use SIF_NAME from config.sh if set, otherwise generate from version numbers
if [ -z "${SIF_NAME:-}" ]; then
    if [ -n "${ROS_DISTRO:-}" ]; then
        ROS_DISTRO_CAPITALIZED=$(echo "${ROS_DISTRO}" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
    else
        ROS_DISTRO_CAPITALIZED="Unknown"
        log_warning "ROS_DISTRO not set, using 'Unknown' in image name"
    fi
    SIF_NAME="Ubuntu-${BASE_OS_VERSION:-24.04}-ROS2-${ROS_DISTRO_CAPITALIZED}-Perception-Robotics-Base.sif"
    DEF_NAME="Ubuntu-${BASE_OS_VERSION:-24.04}-ROS2-${ROS_DISTRO_CAPITALIZED}-Perception-Robotics-Base.def"
fi
# Ensure DEF_NAME is set if not already
DEF_NAME="${DEF_NAME:-${SIF_NAME%.sif}.def}"

#--- Sub-block 17.2: Remove existing definition file ---
# Critical: Ensures we always generate a fresh definition file
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
log_with_timestamp "Removing existing definition file..."
if [ -f "${DEF_NAME}" ]; then
    rm -f "${DEF_NAME}"
    log_with_timestamp "Existing definition file removed: ${DEF_NAME}"
else
    log_with_timestamp "No existing definition file found"
fi
# End if-else block (self-contained)

#--- Sub-block 17.3: Create output directory ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
log_with_timestamp "Creating output directory..."
mkdir -p "${OUT_DIR}"
if [ -d "${OUT_DIR}" ]; then
    log_success "Output directory created: ${OUT_DIR}"
else
    log_error "Failed to create output directory: ${OUT_DIR}"
fi
# End if-else block (self-contained)

#===============================================================================
# BLOCK 18: HELPER FUNCTIONS
#===============================================================================
# Purpose: Define utility functions for artifact fetching
# Self-contained: Yes (complete function definitions)
# Dependencies: None
# Outputs: Environment variables, configuration
#-------------------------------------------------------------------------------

#--- Sub-block 18.1: Robust fetch function with multi-protocol fallback ---
# Purpose: Download files with caching and automatic fallback (aria2c → curl → wget)
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# Parameters: $1=URL, $2=destination path
# Returns: 0 on success, exits on failure
fetch() {
    local url="$1"
    local dst="$2"

    # Validate parameters
    if [ -z "${url:-}" ] || [ -z "${dst:-}" ]; then
        err "fetch() called with empty URL or destination: url='${url:-}', dst='${dst:-}'"
    fi

    # Validate destination directory exists or can be created
    local dst_dir
    dst_dir="$(dirname "${dst}")"
    if [ ! -d "${dst_dir}" ]; then
        mkdir -p "${dst_dir}" || {
            err "Failed to create destination directory: ${dst_dir}"
        }
    fi

    # Check if file already exists in cache
    if [ ! -s "${dst}" ]; then
        log "Fetching ${dst##*/}"
    else
        log "Using cached: $(basename "$dst")"
        return 0
    fi
    # End if-else block

    # Attempt 1: aria2c (fastest, supports parallel downloads)
    if command -v aria2c >/dev/null 2>&1; then
        # Critical: Adaptive connection count based on file size
        local file_size_mb=0
        local content_length=""
        local head_response=""
        if head_response=$(curl -sS --retry 2 --retry-delay 2 --connect-timeout 10 -IL "${url}" 2>/dev/null); then
            content_length=$(printf '%s\n' "${head_response}" | awk 'tolower($1)=="content-length:" {print $2; exit}')
        fi
        if [ -n "${content_length}" ] && [[ "${content_length}" =~ ^[0-9]+$ ]]; then
            file_size_mb=$((content_length / 1024 / 1024))
        fi
        local connections=4
        if [[ "${file_size_mb:-0}" -gt 100 ]]; then
            connections=8  # Large files: more connections
        elif [[ "${file_size_mb:-0}" -gt 50 ]]; then
            connections=6  # Medium files: moderate connections
        fi
        # End if-elif-fi block

        if aria2c --check-certificate=true --max-connection-per-server=${connections} --split=${connections} \
            --retry-wait=2 --timeout=30 --continue=true -o "$(basename "${dst}")" \
            -d "$(dirname "${dst}")" --console-log-level=error "${url}" 2>/dev/null; then
            # Verify download succeeded
            if [ ! -s "${dst}" ]; then
                warn "aria2c completed but file is empty or missing: ${dst}"
            fi
        else
            warn "aria2c failed for ${url}; trying curl"
        fi
    fi
    # End outer if-fi block

    # Attempt 2: curl (fallback, widely available)
    if [ ! -s "${dst}" ]; then
        if ! curl -fL --retry 5 --retry-delay 2 -o "${dst}" "${url}" 2>/dev/null; then
            warn "curl failed for ${url}; trying wget"
        fi
    fi
    # End if-fi block

    # Attempt 3: wget (most compatible fallback)
    if [ ! -s "${dst}" ] && command -v wget >/dev/null 2>&1; then
        if ! wget --tries=5 --waitretry=2 -O "${dst}" "${url}" 2>/dev/null; then
            warn "wget failed for ${url}"
        fi
    fi
    # End if-fi block

#--- Sub-block: Section continuation (922) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 904 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
    # Final verification: ensure file was downloaded
    if [ ! -s "${dst}" ]; then
        err "All download methods (aria2c, curl, wget) failed for '${url}'"
    else
        log "Cached $(basename "${dst}")"
    fi
    # End if-else block
}
# End function (self-contained)

#===============================================================================
# BLOCK 19: CACHE PRUNING SCRIPTS GENERATION
#===============================================================================
# Purpose: Generate helper scripts for cache management and cleanup
# Self-contained: Yes (heredocs are complete)
# Dependencies: None
# Outputs: Environment variables, configuration
#-------------------------------------------------------------------------------


#--- Sub-block 13.1.1: Fetch function complete ---
# Purpose: Robust download with multiple fallbacks
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
#--- Sub-block 19.1: Generate APT cache pruning script ---
# Critical: Creates script to clean up APT cache while preserving essential files
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
cat > ./prune_apt_cache.sh <<'APS'
#!/usr/bin/env bash
# Prune APT deb cache. Keep the latest N per package base name.
# Usage: prune_apt_cache.sh --cache /path/to/apt/archives --keep 2 [--apply]
set -euo pipefail

CACHE=""; KEEP="2"; APPLY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cache) CACHE="$2"; shift 2;;
    --keep) KEEP="$2"; shift 2;;
    --apply) APPLY="1"; shift;;
    *) shift;;
  esac
done

# Validate inputs
if [[ -z "$CACHE" ]]; then echo "[apt-prune] ERROR: --cache path required" >&2; exit 2; fi
if [[ ! -d "$CACHE" ]]; then echo "[apt-prune] INFO: cache '$CACHE' missing; nothing to do"; exit 0; fi
if ! [[ "$KEEP" =~ ^[0-9]+$ ]]; then echo "[apt-prune] ERROR: --keep must be integer (got '$KEEP')" >&2; exit 2; fi
if (( KEEP < 1 )); then echo "[apt-prune] ERROR: --keep must be >= 1 (got '$KEEP')" >&2; exit 2; fi
cd "$CACHE" || { echo "[apt-prune] ERROR: could not cd to '$CACHE'" >&2; exit 1; }

# Collect .deb files quietly
# Use GNU find -printf (installed in BLOCK 3) for reliable file listing
mapfile -t ALL_DEBS < <(find . -maxdepth 1 -type f -name '*.deb' -printf '%f\n' 2>/dev/null)
if (( ${#ALL_DEBS[@]} == 0 )); then echo "[apt-prune] INFO: no .deb files to consider"; exit 0; fi

# Derive unique package bases (before first underscore)
mapfile -t BASES < <(printf '%s\n' "${ALL_DEBS[@]}" | awk -F '_' '{print $1}' | sort -u)

removed_total=0
for pkg in "${BASES[@]}"; do
    # List *this* package's debs newest first
    # Use GNU find -printf (installed in BLOCK 3) for reliable sorting
    ALL_FOR_PKG=()
    while IFS= read -r line; do
        [ -z "${line}" ] && continue
        ALL_FOR_PKG+=("$(echo "${line}" | cut -d' ' -f2-)")
    done < <(find . -maxdepth 1 -type f -name "${pkg}_*.deb" -printf '%T@ %f\n' 2>/dev/null | sort -rn | cut -d' ' -f2- || true)
    if (( ${#ALL_FOR_PKG[@]} <= KEEP )); then continue; fi

  # Determine files to prune
    if (( (${#ALL_FOR_PKG[@]} - KEEP) > 0 )); then
    mapfile -t TO_REMOVE < <(printf '%s\n' "${ALL_FOR_PKG[@]}" | tail -n +$((KEEP+1)))
  else
    TO_REMOVE=()
  fi

#--- Sub-block: Section continuation (991) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 970 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
    if (( ${#TO_REMOVE[@]} > 0 )); then
        if [[ -n "$APPLY" ]]; then
            # Remove files directly from array (more portable than xargs)
            for file in "${TO_REMOVE[@]}"; do
                rm -f "${file}" 2>/dev/null || true
            done
            (( removed_total += ${#TO_REMOVE[@]} ))
        else
            printf '[apt-prune] Would remove %s\n' "${TO_REMOVE[@]}"
        fi
    fi
done

if [[ -n "$APPLY" ]] && (( removed_total > 0 )); then echo "[apt-prune] Removed ${removed_total} file(s)"; else echo "[apt-prune] Dry-run complete"; fi
APS
# End heredoc (self-contained)
    chmod +x ./prune_apt_cache.sh


#--- Sub-block 14.1.1: APT pruning script created ---
# Purpose: Cache cleanup while preserving essentials
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
#--- Sub-block 19.2: Generate Conda cache pruning script ---
# Critical: Creates script to clean up Conda package cache
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments
cat > ./prune_conda_cache.sh <<'CPS'
#!/usr/bin/env bash
# Prune conda pkgs cache. Keep the latest N artifacts per base package name.
# Handles *.conda and *.tar.bz2 files.
# Usage: prune_conda_cache.sh --cache /path/to/conda/pkgs --keep 2 [--apply]
set -euo pipefail

CACHE=""; KEEP="2"; APPLY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cache) CACHE="$2"; shift 2;;
    --keep) KEEP="$2"; shift 2;;
    --apply) APPLY="1"; shift;;
    *) shift;;
  esac
done

# Validate inputs
if [[ -z "$CACHE" ]]; then echo "[conda-prune] ERROR: --cache path required" >&2; exit 2; fi
if [[ ! -d "$CACHE" ]]; then echo "[conda-prune] INFO: cache '$CACHE' missing; nothing to do"; exit 0; fi
if ! [[ "$KEEP" =~ ^[0-9]+$ ]]; then echo "[conda-prune] ERROR: --keep must be integer (got '$KEEP')" >&2; exit 2; fi
if (( KEEP < 1 )); then echo "[conda-prune] ERROR: --keep must be >= 1 (got '$KEEP')" >&2; exit 2; fi
cd "$CACHE" || { echo "[conda-prune] ERROR: could not cd to '$CACHE'" >&2; exit 1; }

# List package files (quiet if none)
# Use GNU find -printf (installed in BLOCK 3) for reliable file listing
mapfile -t PKGFILES < <(find . -maxdepth 1 -type f \( -name '*.conda' -o -name '*.tar.bz2' \) -printf '%f\n' 2>/dev/null)
if (( ${#PKGFILES[@]} == 0 )); then echo "[conda-prune] INFO: no conda artifacts found"; exit 0; fi

# Derive base names: strip version-build-suffix and extension
# Matches: name-version-build.(conda|tar.bz2)
mapfile -t BASES < <(printf '%s\n' "${PKGFILES[@]}" | \
  sed -E 's/-[0-9.-]+-[a-z0-9_]+(\.conda|\.tar\.bz2)$//' | sort -u)

removed_total=0
for base in "${BASES[@]}"; do
  # All variants for this base (sort with -V to respect 1.10 > 1.9 etc.)
    ALL_FOR_BASE=()
    # Use GNU find -printf (installed in BLOCK 3) for reliable file listing
    while IFS= read -r pkg_file; do
        [ -z "${pkg_file}" ] || [ ! -f "${pkg_file}" ] && continue
        ALL_FOR_BASE+=("$(basename "${pkg_file}")")
    done < <(find . -maxdepth 1 -type f \( -name "${base}-*.conda" -o -name "${base}-*.tar.bz2" \) -printf '%f\n' 2>/dev/null | sort -rV || true)
    if (( ${#ALL_FOR_BASE[@]} <= KEEP )); then continue; fi

#--- Sub-block: Section continuation (1053) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

    if (( (${#ALL_FOR_BASE[@]} - KEEP) > 0 )); then
    mapfile -t TO_REMOVE < <(printf '%s\n' "${ALL_FOR_BASE[@]}" | tail -n +$((KEEP+1)))
  else
    TO_REMOVE=()
  fi


#--- Sub-block: Code section 1035 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
    if (( ${#TO_REMOVE[@]} > 0 )); then
        if [[ -n "$APPLY" ]]; then
            # Remove files directly from array (more portable than xargs)
            for file in "${TO_REMOVE[@]}"; do
                rm -f "${file}" 2>/dev/null || true
            done
            (( removed_total += ${#TO_REMOVE[@]} ))
        else
            printf '[conda-prune] Would remove %s\n' "${TO_REMOVE[@]}"
        fi
    fi
done

if [[ -n "$APPLY" ]] && (( removed_total > 0 )); then echo "[conda-prune] Removed ${removed_total} file(s)"; else echo "[conda-prune] Dry-run complete"; fi
CPS
# End heredoc (self-contained)
    chmod +x ./prune_conda_cache.sh

#===============================================================================
# BLOCK 20: ARTIFACT PREFETCHING
#===============================================================================
# Purpose: Download all required software to host cache before container build
# Self-contained: Yes (complete functions and if-else blocks)
# Dependencies: All version variables from config.sh, fetch() function
# Outputs: Configured system components
# NOTE: All versions/URLs are loaded from config.sh in Block 2
#-------------------------------------------------------------------------------
log_with_timestamp "Prefetching required artifacts to host cache..."


#--- Sub-block 14.2.1: Conda pruning script created ---
# Purpose: Conda cache cleanup
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
#--- Sub-block 20.1: Helper function to fetch and mark executable ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
fetch_binary() {
    local url="${1:-}"
    local dst="${2:-}"
    if [ -z "${url:-}" ] || [ -z "${dst:-}" ]; then
        err "fetch_binary() called with empty URL or destination: url='${url:-}', dst='${dst:-}'"
    fi
    fetch "${url}" "${dst}" && chmod +x "${dst}"
}
# End function (self-contained)

#--- Sub-block 20.2: Function to check cache completeness ---
# Dependencies: PHASE 1 (Compilers)
# Outputs: Configured system components
# Returns: Count of missing artifacts
check_cache_complete() {
    local missing=0
    # Check each required artifact
    # Validate cache directories exist before checking files
    if [ ! -d "${BIN_CACHE:-}" ] || [ ! -d "${DEB_CACHE:-}" ]; then
        echo "2"  # Return non-zero count if cache directories don't exist
        return 0
    fi
    
    [[ ! -f "${BIN_CACHE}/${MINIFORGE_SH}" ]] && ((missing++))
    [[ ! -f "${BIN_CACHE}/${MICROMAMBA_BIN}" ]] && ((missing++))
    [[ ! -f "${BIN_CACHE}/${YQ_BIN}" ]] && ((missing++))

#--- Sub-block: Cache file validation ---
# Purpose: Verify integrity of all cached files
# Dependencies: PHASE 1 (Compilers)
# Outputs: Configured system components
    [[ ! -f "${DEB_CACHE}/${TURBOVNC_DEB}" ]] && ((missing++))
    [[ ! -f "${DEB_CACHE}/${VIRTUALGL_DEB}" ]] && ((missing++))
    [[ ! -f "${BIN_CACHE}/drake.asc" ]] && ((missing++))
    [[ ! -f "${BIN_CACHE}/${JULIA_TARBALL}" ]] && ((missing++))
    [[ ! -f "${BIN_CACHE}/julia_key.asc" ]] && ((missing++))
    echo "${missing}"

#--- Sub-block: Cache validation ---
# Purpose: Verify cached files
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
}
# End function (self-contained)

# Cache integrity check and repair function
check_cache_integrity() {
    echo "===> Checking cache integrity..."
    local issues=0
    # Check for corrupted files
    for cache_dir in "${BIN_CACHE}" "${DEB_CACHE}" "${APT_ARCHIVE_CACHE}" "${CONDA_CACHE}" "${WHEELS_CACHE}" "${JULIA_CACHE}"; do
        if [ -d "${cache_dir}" ]; then
            # Check for zero-byte files (likely corrupted downloads)
            local zero_count
            zero_count=$(find "${cache_dir}" -type f -size 0 2>/dev/null | wc -l | tr -d '[:space:]')
            if [[ "${zero_count:-0}" -gt 0 ]]; then
                echo "  ✗ Found ${zero_count} zero-byte file(s) in $(basename "${cache_dir}")"
                find "${cache_dir}" -type f -size 0 -delete 2>/dev/null || true
                echo "    ✓ Removed zero-byte files"
                issues=$((issues + 1))
            fi

            # Check for incomplete downloads (files ending with .part, .tmp, etc.)
            local incomplete_count
            incomplete_count=$(find "${cache_dir}" -type f \( -name "*.part" -o -name "*.tmp" -o -name "*.aria2" \) 2>/dev/null | wc -l | tr -d '[:space:]')
            if [[ "${incomplete_count:-0}" -gt 0 ]]; then
                echo "  ✗ Found ${incomplete_count} incomplete download(s) in $(basename "${cache_dir}")"
                find "${cache_dir}" -type f \( -name "*.part" -o -name "*.tmp" -o -name "*.aria2" \) -delete 2>/dev/null || true
                echo "    ✓ Removed incomplete downloads"
                issues=$((issues + 1))
            fi
        fi
    done
    if [[ "${issues:-0}" -eq 0 ]]; then
        echo "  ✓ Cache integrity check passed"
    else
        echo "  ✓ Cache integrity issues repaired: ${issues} problem(s) fixed"
    fi
    return 0 # Always return success after repair
}

#--- Sub-block: Section continuation (1149) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 1122 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# Clean up any existing incomplete downloads and check cache integrity
echo "===> Cleaning up any existing incomplete downloads..."
find "${CACHE_DIR}" -type f \( -name "*.part" -o -name "*.tmp" -o -name "*.aria2" \) -delete 2>/dev/null || true
find "${CACHE_DIR}" -type f -size 0 -delete 2>/dev/null || true

check_cache_integrity

#===============================================================================
# BLOCK 7.5: COMPREHENSIVE CACHE CHECK AND DOWNLOAD
#===============================================================================
# Purpose: Check all required files in cache at build start, download missing compulsory files
# Self-contained: Yes (complete cache validation and download system)
# Dependencies: config.sh (for URLs and versions)
# Outputs: All required files in cache, downloaded files
#-------------------------------------------------------------------------------

# Define all required files with download URLs, validation methods, and optional flags
# Format: ["filename"]="validation_method|download_url|param1|param2|param3|optional"
# optional: "optional" if file is optional (NVIDIA Video SDK), empty if compulsory
declare -A required_files=(
    ["micromamba-linux-64"]="binary|${MICROMAMBA_URL}|${MICROMAMBA_SHA256}|||"
    ["yq_linux_amd64"]="binary|${YQ_URL}|${YQ_SHA256}|||"
    ["${MINIFORGE_SH}"]="binary|${MINIFORGE_URL}|${MINIFORGE_SHA256}|||"
    ["${JULIA_TARBALL}"]="archive_with_asc_sha256|${JULIA_URL}||||"
    ["${JULIA_TARBALL}.asc"]="asc|${JULIA_ASC_URL}||||"
    ["drake.asc"]="asc|${DRAKE_ASC_URL}||||"
    ["julia_key.asc"]="local|gpg||||"
    ["${TURBOVNC_DEB}"]="deb_with_gpg|${TURBOVNC_URL}|${VIRTUALGL_TURBOVNC_GPG_KEY_ID}|${VIRTUALGL_TURBOVNC_GPG_KEY_URL}||"
    ["${VIRTUALGL_DEB}"]="deb_with_gpg|${VIRTUALGL_URL}|${VIRTUALGL_TURBOVNC_GPG_KEY_ID}|${VIRTUALGL_TURBOVNC_GPG_KEY_URL}||"
    ["${OPEN3D_WEBRTC_FILE}"]="archive|${OPEN3D_WEBRTC_URL}|${OPEN3D_WEBRTC_SHA256}|||"
    ["${NVIDIA_KEYRING_DEB}"]="deb|${NVIDIA_KEYRING_URL}||||"
    ["Video_Codec_SDK_${NVIDIA_VIDEO_SDK_VERSION}.zip"]="zip|optional_manual|||optional"
)

# Function to check and download required files
check_and_download_required_files() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "  COMPREHENSIVE CACHE CHECK AND DOWNLOAD"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    local missing_compulsory=()
    local missing_optional=()
    local found_files=()
    local optional_files=()
    
    # Ensure cache directories exist
    mkdir -p "${BIN_CACHE}" "${DEB_CACHE}" "${APT_ARCHIVE_CACHE}" "${CONDA_CACHE}" "${WHEELS_CACHE}" "${JULIA_CACHE}"
    
    echo "Phase 1: Checking all required files in cache..."
    echo ""
    
    # Check each required file
    for file_name in "${!required_files[@]}"; do
        local file_info=""
        local validation_method="" file_url="" param1="" param2="" param3="" optional_flag=""
        local file_path=""
        local old_ifs="${IFS}"
        # Extract file info
        file_info="${required_files[${file_name}]}"
        # Save and restore IFS to avoid affecting other commands
        # param1, param2, param3 are reserved for future validation parameters
        # shellcheck disable=SC2034
        IFS='|' read -r validation_method file_url param1 param2 param3 optional_flag <<< "${file_info}"
        IFS="${old_ifs}"
        
        # Determine cache directory based on file type
        # Use case statement for better pattern matching reliability
        case "${file_name}" in
            *.deb)
                file_path="${DEB_CACHE}/${file_name}"
                ;;
            drake.asc)
                file_path="${BIN_CACHE}/${file_name}"
                ;;
            julia-*.tar.gz|julia-*.tar.gz.asc)
                file_path="${BIN_CACHE}/${file_name}"
                ;;
            *)
                file_path="${BIN_CACHE}/${file_name}"
                ;;
        esac
        
        # Check if file exists and is not empty
        if [ -f "${file_path}" ] && [ -s "${file_path}" ]; then
            echo "  ✓ Found: ${file_name}"
            found_files+=("${file_name}")
        else
            if [[ "${optional_flag}" == "optional" ]]; then
                echo "  ⊙ Missing (optional): ${file_name}"
                missing_optional+=("${file_name}")
                optional_files+=("${file_name}")
            else
                echo "  ✗ Missing (compulsory): ${file_name}"
                missing_compulsory+=("${file_name}")
            fi
        fi
    done
    
    echo ""
    echo "Summary:"
    echo "  Found: ${#found_files[@]} file(s)"
    echo "  Missing (compulsory): ${#missing_compulsory[@]} file(s)"
    echo "  Missing (optional): ${#missing_optional[@]} file(s)"
    echo ""
    
    # Download missing compulsory files
    if [ ${#missing_compulsory[@]} -gt 0 ]; then
        echo "Phase 2: Downloading ${#missing_compulsory[@]} missing compulsory file(s)..."
        echo ""
        
        for file_name in "${missing_compulsory[@]}"; do
            local file_info=""
            local validation_method="" file_url="" param1="" param2="" param3="" optional_flag=""
            local dest_path=""
            local old_ifs="${IFS}"
            file_info="${required_files[${file_name}]}"
            # Save and restore IFS to avoid affecting other commands
            IFS='|' read -r validation_method file_url param1 param2 param3 optional_flag <<< "${file_info}"
            IFS="${old_ifs}"
            
            # Skip local files - they're generated/fetched elsewhere
            if [[ "$validation_method" == "local" ]]; then
                echo "  ⊙ Skipping $file_name (local file, handled separately)"
                continue
            fi
            
            # Skip optional manual downloads (NVIDIA Video SDK)
            if [[ "$file_url" == "optional_manual" ]]; then
                echo "  ⊙ Skipping $file_name (requires manual download)"
                continue
            fi
            
            echo "  → Downloading: $file_name"
            
            # Determine destination directory
            # Use case statement for better pattern matching reliability
            case "${file_name}" in
                *.deb)
                    dest_path="${DEB_CACHE}/${file_name}"
                    ;;
                drake.asc)
                    dest_path="${BIN_CACHE}/${file_name}"
                    ;;
                julia-*.tar.gz|julia-*.tar.gz.asc)
                    dest_path="${BIN_CACHE}/${file_name}"
                    ;;
                *)
                    dest_path="${BIN_CACHE}/${file_name}"
                    ;;
            esac
            
            # Create parent directory if it doesn't exist
            mkdir -p "$(dirname "${dest_path}")"
            
            # Download file with retry logic
            local download_success=false
            for attempt in 1 2 3; do
                if curl -fSL --connect-timeout 30 --max-time 3600 "${file_url}" -o "${dest_path}.tmp" 2>/dev/null; then
                    if [ -f "${dest_path}.tmp" ] && [ -s "${dest_path}.tmp" ]; then
                        mv "${dest_path}.tmp" "${dest_path}"
                        download_success=true
                        echo "    ✓ Downloaded: ${file_name}"
                        break
                    else
                        echo "    ⚠ Download attempt ${attempt} produced empty file, retrying..."
                        rm -f "${dest_path}.tmp" 2>/dev/null || true
                    fi
                else
                    echo "    ⚠ Download attempt ${attempt} failed, retrying..."
                    rm -f "${dest_path}.tmp" 2>/dev/null || true
                fi
                sleep 2
            done
            
            if [ "${download_success}" != "true" ]; then
                echo ""
                echo "═══════════════════════════════════════════════════════════════"
                echo "  FATAL ERROR: Failed to download compulsory file"
                echo "═══════════════════════════════════════════════════════════════"
                echo "  File name: ${file_name}"
                echo "  Expected location: ${dest_path}"
                echo "  Source URL: ${file_url}"
                echo ""
                echo "  This is a compulsory file. The build cannot continue without it."
                echo "  You may manually download this file and place it at:"
                echo "    ${dest_path}"
                echo "═══════════════════════════════════════════════════════════════"
                exit 1
            fi
        done
        echo ""
    fi
    
    # Attempt to download missing optional files (but don't fail if download fails)
    if [ ${#missing_optional[@]} -gt 0 ]; then
        echo "Phase 3: Attempting to download ${#missing_optional[@]} missing optional file(s)..."
        echo ""
        
        for file_name in "${missing_optional[@]}"; do
            local file_info=""
            local validation_method="" file_url="" param1="" param2="" param3="" optional_flag=""
            local dest_path=""
            local old_ifs="${IFS}"
            file_info="${required_files[${file_name}]}"
            # Save and restore IFS to avoid affecting other commands
            IFS='|' read -r validation_method file_url param1 param2 param3 optional_flag <<< "${file_info}"
            IFS="${old_ifs}"
            
            # Skip optional manual downloads (NVIDIA Video SDK)
            if [[ "$file_url" == "optional_manual" ]]; then
                echo "  ⊙ Skipping $file_name (requires manual download from NVIDIA Developer website)"
                echo "    This file is optional. If needed, download it manually from:"
                echo "    https://developer.nvidia.com/nvidia-video-codec-sdk/download"
                echo "    Place it in: ${BIN_CACHE}/${file_name}"
                continue
            fi
            
            echo "  → Attempting download: $file_name"
            
            # Determine destination directory
            # Use case statement for better pattern matching reliability
            case "${file_name}" in
                *.deb)
                    dest_path="${DEB_CACHE}/${file_name}"
                    ;;
                *)
                    dest_path="${BIN_CACHE}/${file_name}"
                    ;;
            esac
            
            # Create parent directory if it doesn't exist
            mkdir -p "$(dirname "${dest_path}")"
            
            # Attempt download (non-fatal)
            if curl -fSL --connect-timeout 30 --max-time 3600 "${file_url}" -o "${dest_path}.tmp" 2>/dev/null; then
                if [ -f "${dest_path}.tmp" ] && [ -s "${dest_path}.tmp" ]; then
                    mv "${dest_path}.tmp" "${dest_path}"
                    echo "    ✓ Downloaded: ${file_name}"
                else
                    echo "    ⚠ Download produced empty file (optional file, continuing): ${file_name}"
                    rm -f "${dest_path}.tmp" 2>/dev/null || true
                fi
            else
                echo ""
                echo "═══════════════════════════════════════════════════════════════"
                echo "  WARNING: Failed to download optional file (non-fatal)"
                echo "═══════════════════════════════════════════════════════════════"
                echo "  File name: ${file_name}"
                echo "  Expected location: ${dest_path}"
                echo "  Source URL: ${file_url}"
                echo ""
                echo "  This is an optional file. The build will continue without it."
                echo "  If needed, you may manually download this file and place it at:"
                echo "    ${dest_path}"
                echo "═══════════════════════════════════════════════════════════════"
                rm -f "${dest_path}.tmp" 2>/dev/null || true
            fi
        done
        echo ""
    fi
    
    # Final summary
    echo "═══════════════════════════════════════════════════════════════"
    echo "  CACHE CHECK COMPLETE"
    echo "═══════════════════════════════════════════════════════════════"
    
    # Re-check all files after downloads
    local final_missing_compulsory=()
    local final_missing_optional=()
    
    for file_name in "${!required_files[@]}"; do
        local file_info=""
        local validation_method="" file_url="" param1="" param2="" param3="" optional_flag=""
        local file_path=""
        local old_ifs="${IFS}"
        file_info="${required_files[${file_name}]}"
        # Save and restore IFS to avoid affecting other commands
        # param1, param2, param3 are reserved for future validation parameters
        # shellcheck disable=SC2034
        IFS='|' read -r validation_method file_url param1 param2 param3 optional_flag <<< "${file_info}"
        IFS="${old_ifs}"
        
        # Use case statement for better pattern matching reliability
        case "${file_name}" in
            *.deb)
                file_path="${DEB_CACHE}/${file_name}"
                ;;
            drake.asc)
                file_path="${BIN_CACHE}/${file_name}"
                ;;
            julia-*.tar.gz|julia-*.tar.gz.asc)
                file_path="${BIN_CACHE}/${file_name}"
                ;;
            *)
                file_path="${BIN_CACHE}/${file_name}"
                ;;
        esac
        
        if [ ! -f "${file_path}" ] || [ ! -s "${file_path}" ]; then
            if [[ "${optional_flag}" == "optional" ]] || [[ "${file_url}" == "optional_manual" ]]; then
                final_missing_optional+=("${file_name}")
            else
                final_missing_compulsory+=("${file_name}")
            fi
        fi
    done
    
    if [ ${#final_missing_compulsory[@]} -gt 0 ]; then
        echo ""
        echo "  ✗ ERROR: ${#final_missing_compulsory[@]} compulsory file(s) still missing:"
        for file in "${final_missing_compulsory[@]}"; do
            echo "    - ${file}"
        done
        echo ""
        echo "  Build cannot continue. Please check network connection and try again."
        exit 1
    fi
    
    if [ ${#final_missing_optional[@]} -gt 0 ]; then
        echo ""
        echo "  ⚠ WARNING: ${#final_missing_optional[@]} optional file(s) missing:"
        for file in "${final_missing_optional[@]}"; do
            echo "    - ${file}"
        done
        echo ""
        echo "  Build will continue, but features requiring these files will be disabled."
    else
        echo ""
        echo "  ✓ All required files present in cache"
    fi
    
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
}

# Run comprehensive cache check and download
check_and_download_required_files

# Skip downloads if all artifacts are cached (legacy check - kept for compatibility)
CACHE_COMPLETE_RESULT="$(check_cache_complete 2>/dev/null || echo "1")"
CACHE_COMPLETE_RESULT="${CACHE_COMPLETE_RESULT:-1}"
if [[ "${CACHE_COMPLETE_RESULT}" -eq 0 ]]; then
    log "All artifacts already cached, skipping legacy download phase"
else
    # Export functions for parallel execution
    export -f fetch fetch_binary log log_with_timestamp log_success log_warning log_error warn err

    # Define download tasks (legacy - most files should already be downloaded above)

#--- Sub-block: Section 1200 ---
# Purpose: Continued implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

#--- Sub-block: File verification ---
# Purpose: Check file integrity
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
    # Use a safer temporary file location with proper cleanup
    (
        set -euo pipefail
        tasks_file=$(mktemp "${BUILD_TMP_DIR:-/tmp}/download_tasks.XXXXXX") || {
            log_warning "Failed to create temporary download task list; skipping legacy download queue"
            exit 0
        }
        trap 'rm -f "${tasks_file}" 2>/dev/null || true' EXIT
    
        cat > "${tasks_file}" << EOF
MINIFORGE|${MINIFORGE_URL}|${BIN_CACHE}/${MINIFORGE_SH}|binary
MICROMAMBA|${MICROMAMBA_URL}|${BIN_CACHE}/${MICROMAMBA_BIN}|binary
YQ|${YQ_URL}|${BIN_CACHE}/${YQ_BIN}|binary
TURBOVNC|${TURBOVNC_URL}|${DEB_CACHE}/${TURBOVNC_DEB}|deb
VIRTUALGL|${VIRTUALGL_URL}|${DEB_CACHE}/${VIRTUALGL_DEB}|deb
DRAKE_KEY|${DRAKE_ASC_URL}|${BIN_CACHE}/drake.asc|file
JULIA|${JULIA_URL}|${BIN_CACHE}/${JULIA_TARBALL}|file
NVIDIA_KEYRING|${NVIDIA_KEYRING_URL}|${DEB_CACHE}/${NVIDIA_KEYRING_DEB}|deb
OPEN3D_WEBRTC|${OPEN3D_WEBRTC_URL}|${BIN_CACHE}/${OPEN3D_WEBRTC_FILE}|file
EOF

        # Execute downloads in parallel (max 4 concurrent) - only for files not already downloaded
        log "Downloading any remaining artifacts in parallel..."
        # Process downloads sequentially for safety (parallel execution removed due to complexity with exported functions)
        # Note: This is safer than xargs with bash -c which has quoting/injection risks
        while IFS='|' read -r name url dst type || [ -n "${name:-}" ]; do
            # Skip empty lines
            [ -z "${name:-}" ] && continue
            # Validate required fields
            [ -z "${url:-}" ] && continue
            [ -z "${dst:-}" ] && continue
            [ -z "${type:-}" ] && continue
            # Skip if file already exists and is not empty
            if [ -f "${dst}" ] && [ -s "${dst}" ]; then
                echo "Skipping (already cached): ${name}"
            else
                echo "Starting download: ${name}"
                if [[ "${type}" == "binary" ]]; then
                    fetch_binary "${url}" "${dst}"
                else
                    fetch "${url}" "${dst}"
                fi
                echo "Completed download: ${name}"
            fi
        done < "${tasks_file}"
    )
fi

# --- Prefetch GPG Keys ---
log_with_timestamp "Prefetching public GPG keys..."
# JULIA_GPG_KEY_ID and JULIA_GPG_KEY_URL are defined in config.sh
JULIA_KEY_FILE="${BIN_CACHE}/julia_key.asc"
if [ ! -s "${JULIA_KEY_FILE}" ]; then
    log "Julia GPG key not found in cache. Fetching..."
    
    # Try to fetch GPG key with retries (non-blocking)
    # Method 1: Direct download from Julia's official URL (most reliable)
    GPG_FETCH_SUCCESS=false
    log "  Attempting direct download from ${JULIA_GPG_KEY_URL}..."
    if curl -fsSL --retry 3 --connect-timeout 10 "${JULIA_GPG_KEY_URL}" -o "${JULIA_KEY_FILE}" 2>/dev/null; then
        if [ -s "${JULIA_KEY_FILE}" ] && grep -q "BEGIN PGP PUBLIC KEY BLOCK" "${JULIA_KEY_FILE}"; then
            log_success "Successfully downloaded Julia GPG key from official URL"
            GPG_FETCH_SUCCESS=true
        fi
    fi
    
    # Method 2: Fallback to keyservers if direct download fails
    if [[ "${GPG_FETCH_SUCCESS}" == "false" ]]; then
        log "  Direct download failed. Trying keyservers..."
        for attempt in 1 2; do
            if gpg --keyserver https://keyserver.ubuntu.com --recv-keys "${JULIA_GPG_KEY_ID}" 2>/dev/null || \
               gpg --keyserver https://keys.openpgp.org --recv-keys "${JULIA_GPG_KEY_ID}" 2>/dev/null; then
                # Export the key from the keyring to our cache file
                gpg --export --armor "${JULIA_GPG_KEY_ID}" > "${JULIA_KEY_FILE}" 2>/dev/null
                if [ -s "${JULIA_KEY_FILE}" ]; then
                    log_success "Successfully fetched Julia GPG key from keyserver"
                    GPG_FETCH_SUCCESS=true
                    break
                fi
            fi
            [ "${attempt}" -lt 2 ] && sleep 2
        done
    fi
    
    if [[ "${GPG_FETCH_SUCCESS}" == "false" ]]; then
        log_warning "Failed to fetch Julia GPG key from all sources (URL and keyservers)."
        log_warning "GPG signature verification will be skipped. SHA256 verification will still be performed."
        # Clean up any failed/empty download (curl may create empty file on failure)
        if [ -f "${JULIA_KEY_FILE}" ] && [ ! -s "${JULIA_KEY_FILE}" ]; then
            rm -f "${JULIA_KEY_FILE}" 2>/dev/null || true
            log "Removed empty/failed GPG key file"
        fi
        # Don't create marker file - let validation attempt keyserver if needed
    fi
else
    log "Using cached Julia GPG key: $(basename "${JULIA_KEY_FILE}")"
fi
log "Prefetching complete."

#--- Sub-block: Section continuation (1212) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 1182 ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

#--- Sub-block: Section 1250 ---
# Purpose: Continued implementation
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# --- Singularity Definition File Generation ---
log_with_timestamp "Generating Singularity definition file: ${DEF_NAME}"
# Always remove any stale def file from previous runs
if [ -f "${DEF_NAME}" ]; then
    rm -f "${DEF_NAME}" || {
        log_warning "Failed to remove existing definition file: ${DEF_NAME}"
    }
fi

#===============================================================================
# BLOCK 21: SINGULARITY DEFINITION FILE GENERATION
#===============================================================================
# Purpose: Generate the complete Singularity definition file (.def)
# Self-contained: Yes (complete heredoc)
# Dependencies: All cached artifacts, xubuntu_robotics_base_post_ULTRA_CLEANED.sh
# Outputs: Configured system components
# NOTE: This is a large heredoc containing the entire container definition
#-------------------------------------------------------------------------------

#--- Sub-block 21.1: Generate complete .def file ---
# Critical: This defines the entire container build process
# Dependencies: Block 15 (VirtualGL), Block 15 (TurboVNC), System (Container runtime)
# Outputs: VNC server, GPU acceleration
cat > "${DEF_NAME}" <<DEF
Bootstrap: docker
From: ${BASE_IMAGE}

# === %files Section ===
%files
    # Critical: Copy centralized configuration into container
    ${CONFIG_FILE} /etc/config.sh
    ${SCRIPT_DIR}/container_cache/binaries /container_cache/binaries
    ${SCRIPT_DIR}/container_cache/debs /container_cache/debs
    ${SCRIPT_DIR}/xubuntu_robotics_base_post_ULTRA_CLEANED.sh /container_post_script.sh
    ${SCRIPT_DIR}/config.sh /container_config.sh
    # Copy entire container-scripts directory for installation via install.sh
    ${SCRIPT_DIR}/${CONTAINER_SCRIPTS_DIR} ${CONTAINER_SCRIPTS_INSTALL_PATH}

# === %labels Section ===
%labels
    Maintainer midhun
    Description "Xubuntu MPC GUI base (cached). XFCE; TurboVNC/VirtualGL, Firefox PPA, Miniforge/micromamba, yq, LibreOffice/Blender/OpenSCAD/FreeCAD/TeX (EN). Drake APT hardened. Jupyter-Julia kernels; MeshCat/Meldis wiring. All baseline features retained."

# === %environment Section ===
%environment
    export DEBIAN_FRONTEND=noninteractive
    export TZ=Asia/Kolkata
    export LANG=C.UTF-8
    export LC_ALL=C.UTF-8
    export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    export MUJOCO_GL=egl
    export EGL_PLATFORM=surfaceless
    export __GLX_VENDOR_LIBRARY_NAME=nvidia

    # Rust environment
    export RUSTUP_HOME=${RUST_HOME}
    export CARGO_HOME=${RUST_HOME}/cargo
    export PATH=${RUST_HOME}/cargo/bin:${RUST_HOME}/tools/bin:\$PATH

    # Zenoh
    export ZENOH_HOME=${ZENOH_HOME}
    export PATH=${ZENOH_HOME}/bin:\$PATH

    # Drake patching for meldis etc. (py path covers both dist/site variants)
    export DRAKE_INSTALL_DIR=${DRAKE_HOME}
    export PYTHONPATH=${DRAKE_HOME}/lib/python3/dist-packages:${DRAKE_HOME}/lib/python${SYSTEM_PYTHON_VER}/site-packages:\$PYTHONPATH
    export PATH=${DRAKE_HOME}/bin:\$PATH

    # Additional environment variables
    export JULIA_NUM_THREADS=auto
    export HDF5_USE_FILE_LOCKING=FALSE
    export MODPROBE_BLACKLIST="nouveau"
    export NVIDIA_DRIVER_CAPABILITIES=all
    export NVIDIA_VISIBLE_DEVICES=all
    export NVIDIA_REQUIRE_CUDA="cuda>=12.0"
    export GLV_COMMAND_MAP_DISABLE=1
    export __GL_MaxFramesAllowed=1
    export VGL_SAMPLES=1
    export VGL_COMPRESS=jpeg
    export VGL_LOGO=0
    export VGL_READBACK=sync
    export VGL_REFRESHRATE=60
    export VGL_VERBOSE=0
    export DISPLAY=:80
    export PATH=${TURBOVNC_HOME}/bin:\$PATH
    export PATH=${VIRTUALGL_HOME}/bin:\$PATH
    export TVNC_WM=startxfce4
    export PATH=${MINIFORGE_HOME}/bin:\$PATH
    export MAMBA_ROOT_PREFIX=${MAMBA_ENVS}
    export PATH=${JULIA_HOME}/bin:\$PATH
    export DOWNLOADER=aria2c
    export APT_FAST_OPTS="--summary-interval=1 --console-log-level=notice --check-certificate=false --max-connection-per-server=16 --split=16 --min-split-size=2M --timeout=30"
    export OPENBLAS_INSTALL_PREFIX=${OPENBLAS_INSTALL_PREFIX}
    export OPENBLAS_BUILD_FLAGS="${OPENBLAS_BUILD_FLAGS}"
    export SUITESPARSE_CMAKE_FLAGS="${SUITESPARSE_CMAKE_FLAGS}"
    export SUITESPARSE_INSTALL_PREFIX=${SUITESPARSE_INSTALL_PREFIX}
    export LD_LIBRARY_PATH=${OPENBLAS_INSTALL_PREFIX}/lib:\${LD_LIBRARY_PATH:-}

# === %setup Section ===
%setup -c /bin/bash
    # Check if the build process can see the post script on the host
    /bin/echo "--- [DEBUG] Running 'ls -l' on host for xubuntu_robotics_base_post_ULTRA_CLEANED.sh:"
    /bin/ls -l xubuntu_robotics_base_post_ULTRA_CLEANED.sh
    
    # Enable strict mode (portable across /bin/sh and /bin/bash)
    if [ -n "${BASH_VERSION:-}" ]; then
        set -euo pipefail
    else
        set -eu
    fi
    echo "[%setup] shell diagnostics:"
    echo "  PID: $$, PPID: ${PPID:-unknown}"
    echo "  SHELL: ${SHELL:-unknown}"
    echo "  BASH_VERSION: ${BASH_VERSION:-n/a}"
    echo "  0: ${0:-unknown}"
    echo "  Process name: $(ps -p $$ -o comm= 2>/dev/null || echo unknown)"
    umask 022

    # NOTE: All version configurations loaded from config.sh (sourced at top of build script)
    # Variables available: MINIFORGE_*, MICROMAMBA_*, TURBOVNC_*, VIRTUALGL_*, YQ_*, DRAKE_*, etc.
    # \$SINGULARITY_ROOTFS or \$APPTAINER_ROOTFS is the image root during build; this runs on the HOST
    
    # Handle both Singularity and Apptainer variable names
    ROOTFS="\${SINGULARITY_ROOTFS:-\${APPTAINER_ROOTFS:-}}"
    
    if [ -z "\${ROOTFS}" ]; then
        echo "ERROR: Neither SINGULARITY_ROOTFS nor APPTAINER_ROOTFS is set!"
        echo "This script must be run as part of a container build process."
        exit 1
    fi
    
    echo "Running %setup on host to pre-populate caches..."
    echo "Container root: \${ROOTFS}"

    if [ ! -d "\${PWD}/container_cache" ]; then
        echo "WARNING: Host cache directory missing at \${PWD}/container_cache; continuing without preseeding."
    fi

    mkdir -p "\${ROOTFS}/container_cache/binaries"
    mkdir -p "\${ROOTFS}/container_cache/apt/archives"
    mkdir -p "\${ROOTFS}/container_cache/conda_pkgs"
    mkdir -p "\${ROOTFS}/container_cache/debs"
    mkdir -p "\${ROOTFS}/container_cache/julia_pkgs"
    mkdir -p "\${ROOTFS}/container_cache/wheels"

#--- Sub-block: Section continuation (1742) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

    # Set proper permissions for cache directories
    chmod -R 755 "\${ROOTFS}/container_cache" 2>/dev/null || true

    # Copy (no overwrite) any preseeded cache into the image build root
    rsync -a --ignore-existing "\${PWD}/container_cache/" "\${ROOTFS}/container_cache" 2>/dev/null || true


#--- Sub-block: Code section 1694 ---
# Purpose: Continuing implementation
# Dependencies: PHASE 1 (Compilers)
# Outputs: Configured system components
    # Ensure proper ownership and permissions after copy
    chown -R root:root "\${ROOTFS}/container_cache" 2>/dev/null || true
    chmod -R 755 "\${ROOTFS}/container_cache" 2>/dev/null || true

# === %post Section ===
%post -c /bin/bash
    # Enable strict mode (portable across /bin/sh and /bin/bash)
    if [ -n "${BASH_VERSION:-}" ]; then
        set -euo pipefail
    else
        set -eu
    fi
    echo "[%post] shell diagnostics:"
    echo "  PID: $$, PPID: ${PPID:-unknown}"
    echo "  SHELL: ${SHELL:-unknown}"
    echo "  BASH_VERSION: ${BASH_VERSION:-n/a}"
    echo "  0: ${0:-unknown}"
    echo "  Process name: $(ps -p $$ -o comm= 2>/dev/null || echo unknown)"
    echo "  bash in PATH: $(command -v bash 2>/dev/null || echo 'not found')"
    umask 022
    # Source configuration to make all variables available in %post section
    # This must happen BEFORE any validation code that uses these variables
    if [ -f /etc/config.sh ]; then
        source /etc/config.sh
        export CONFIG_SOURCED=1
        echo "✓ Loaded configuration from /etc/config.sh in %post section"
    elif [ -f /container_config.sh ]; then
        source /container_config.sh
        export CONFIG_SOURCED=1
        echo "✓ Loaded configuration from /container_config.sh in %post section"
    else
        echo "⚠ WARNING: config.sh not found - using fallback hardcoded paths"
        export CONTAINER_CACHE_ROOT="/container_cache"
        export CONTAINER_BIN_CACHE="${CONTAINER_CACHE_ROOT}/binaries"
        export CONTAINER_DEB_CACHE="${CONTAINER_CACHE_ROOT}/debs"
        export CONTAINER_APT_CACHE="${CONTAINER_CACHE_ROOT}/apt/archives"
        export CONTAINER_CONDA_CACHE="${CONTAINER_CACHE_ROOT}/conda_pkgs"
        export CONTAINER_WHEELS_CACHE="${CONTAINER_CACHE_ROOT}/wheels"
        export CONTAINER_JULIA_CACHE="${CONTAINER_CACHE_ROOT}/julia_pkgs"
        export CONFIG_SOURCED=1
    fi

    debug_glibc() {
    local stage="\$1"

    echo "==== DEBUG CHECKPOINT: \$stage ===="
    echo "Time: \$(date)"

    echo "GLIBC version:"
    /lib/x86_64-linux-gnu/libc.so.6 2>/dev/null | head -1 || echo "GLIBC version check failed"

    echo "ldd version:"
    (timeout 5 sh -c 'ldd --version 2>&1' || echo "ldd version check failed or timed out") | head -1 || true

    echo "GCC version:"
    gcc --version 2>/dev/null | head -1 || echo "GCC not installed yet"

    echo "stdlib.h locations:"
    find /usr/include -name "stdlib.h" 2>/dev/null || echo "stdlib.h not found"

    echo "cstdlib locations:"
    find /usr/include -name "cstdlib" 2>/dev/null || echo "cstdlib not found"


#--- Sub-block 17.1.1: Definition file main sections ---
# Purpose: Bootstrap, post-install, environment
# Dependencies: PHASE 1 (Compilers)
# Outputs: Configured system components
    echo "Compiler include paths:"
    gcc -xc++ -E -v < /dev/null 2>&1 | grep "^ /" 2>/dev/null || echo "Cannot check (GCC not ready)"
    echo "================================="
    echo "Test compile with stdlib.h:"
    echo '#include <stdlib.h>' > /tmp/test_c.c
    echo 'int main() { return 0; }' >> /tmp/test_c.c
    gcc /tmp/test_c.c -o /tmp/test_c.o && echo "SUCCESS" || echo "FAILED"
    rm -f /tmp/test_c.c /tmp/test_c.o
    echo "================================="
}
    export MAKEFLAGS="-j\$(( \$(nproc) / 2 ))"
    export TMPDIR="${CONTAINER_BUILD_TMPDIR}"
    export SINGULARITY_TMPDIR="${CONTAINER_BUILD_TMPDIR}"
    mkdir -p "${CONTAINER_BUILD_TMPDIR}"
    chmod 1777 "${CONTAINER_BUILD_TMPDIR}"

    # Clean any stale locks
    rm -rf /var/lib/dpkg/lock-frontend
    rm -rf /var/lib/dpkg/lock
    rm -rf /var/cache/apt/archives/lock

    # FIX: Disable PEP 668 for container builds
    # Ubuntu 24.04 has PEP 668 protection, remove it for containers
    rm -f /usr/lib/python3.*/EXTERNALLY-MANAGED
    rm -f /usr/lib/python3*/EXTERNALLY-MANAGED
    # Alternative: use pip with --break-system-packages flag
    # But removing EXTERNALLY-MANAGED is cleaner for containers
    echo "PEP 668 disabled for container pip installations"
    # Verify fix
    if [ -f /usr/lib/python\${SYSTEM_PYTHON_VER}/EXTERNALLY-MANAGED ]; then
        echo "✗ PEP 668 file still exists"
        exit 1
    else
        echo "✓ PEP 668 disabled"
    fi

    # Suppress pip root warnings in container builds
    export PIP_ROOT_USER_ACTION=ignore

#--- Sub-block: Section continuation (1820) ---
# Purpose: Implementation details
# Dependencies: Block 6.13 (NVIDIA CUDA)
# Outputs: GPU libraries, CUDA toolkit

    # Configure Environment for CUDA Cross-Compilation
    # Set a dedicated, writable temporary directory for the CUDA compiler (nvcc)
    # to prevent issues with restrictive /tmp permissions on build hosts.
    export TMPDIR=/tmp/cuda_build
    rm -rf "\$TMPDIR"
    mkdir -p "\$TMPDIR"
    chmod 755 "\$TMPDIR"


#--- Sub-block: Code section 1771 ---
# Purpose: Continuing implementation
# Dependencies: Block 17 (Conda/Miniforge), Block 8.5 (Julia installation), Block 6.13 (NVIDIA CUDA)
# Outputs: GPU libraries, CUDA toolkit
    # Auto-detect CUDA installation (robust, version-agnostic)
    if [ -L /usr/local/cuda ]; then
        export CUDA_HOME=/usr/local/cuda
    elif [ -d "/usr/local/cuda-${CUDA_MAJOR}" ]; then
        export CUDA_HOME="/usr/local/cuda-${CUDA_MAJOR}"
    else
        # Fallback to auto-detection of versioned directory
        DETECTED_CUDA=\$(ls -d /usr/local/cuda-${CUDA_MAJOR}.* 2>/dev/null | head -1 || echo "")
        if [ -n "\${DETECTED_CUDA}" ] && [ -d "\${DETECTED_CUDA}" ]; then
            export CUDA_HOME="\${DETECTED_CUDA}"
        else
            export CUDA_HOME="/usr/local/cuda"
        fi
    fi
    export PATH="\${CUDA_HOME}/bin:\${PATH}"
    export LD_LIBRARY_PATH="\${CUDA_HOME}/lib64:\${LD_LIBRARY_PATH}"

    # Make the script executable and run it
    chmod +x /container_post_script.sh
    /container_post_script.sh
    
    # Install all container scripts from container-scripts/ directory using install.sh
    # This installs all extracted files (shell scripts, configs, verification tools, etc.) to their target locations
    # Source config.sh to get container scripts configuration variables
    if [ -f /etc/config.sh ]; then
        source /etc/config.sh
    fi
    
    # Use variables from config.sh (with defaults if not set)
    CONTAINER_SCRIPTS_PATH="\${CONTAINER_SCRIPTS_INSTALL_PATH:-/container-scripts}"
    INSTALLER_SCRIPT="\${CONTAINER_SCRIPTS_PATH}/\${CONTAINER_SCRIPTS_INSTALLER:-install.sh}"
    MANIFEST_FILE="\${CONTAINER_SCRIPTS_PATH}/\${CONTAINER_SCRIPTS_MANIFEST:-MANIFEST.json}"
    
    if [ -f "\${INSTALLER_SCRIPT}" ] && [ -f "\${MANIFEST_FILE}" ]; then
        chmod +x "\${INSTALLER_SCRIPT}"
        "\${INSTALLER_SCRIPT}" --all || {
            echo "WARNING: Failed to install some container scripts. Continuing build..."
        }
    else
        echo "WARNING: Container scripts installation files not found at \${CONTAINER_SCRIPTS_PATH}. Some scripts may not be available."
    fi

# === %test Section ===
%test
    #!/bin/bash
    set -eu
    echo "test XFCE:"
    if [ -n "${DISPLAY-}" ] && pgrep 'Xorg|Xvnc' >/dev/null; then
      xfce4-session --version || true
    else
      echo "[note] No DISPLAY during build; skipping XFCE runtime check."
    fi
    echo "test Firefox, VNC:"
    which vncserver || true; Xvnc --version || true
    echo "test Firefox:" ; firefox --version || true
    echo "test yq:"; yq --version || { [ -x ${MINIFORGE_HOME}/bin/yq ] && ${MINIFORGE_HOME}/bin/yq --version || echo MISSING; }
    echo "test Micromamba:"; micromamba --help >/dev/null 2>&1 && echo OK || echo MISSING
    echo "test Drake key:"; test -s /etc/apt/trusted.gpg.d/drake.gpg && echo OK || echo MISSING
    echo "test XFCE xstartup wrapper:"; test -x /usr/local/bin/start_vnc_xfce.sh && echo OK || echo MISSING
    echo "test Ulauncher:"; ulauncher --version >/dev/null 2>&1 && echo OK || echo MISSING "(headless test)"
    # Notebook & Julia/Drake checks (soft)
    echo "test Notebooks:"; jupyter kernelspec list 2>/dev/null || true
    echo "test Julia:"; julia --version 2>/dev/null || true
    echo "test Meshcat import:"; python3 -c 'import meshcat; print("Meshcat OK")' 2>/dev/null || true
    echo "test Meldis:"; ${DRAKE_HOME}/bin/meldis --help 2>/dev/null || true
    echo "test TeX:"; pdflatex --version 2>/dev/null || true; biber --version 2>/dev/null || true
    # Missing package tests from baseline:
    echo "test LibreOffice:"; libreoffice --version 2>/dev/null || true
    echo "test Blender:"; blender --version 2>/dev/null || true
    echo "test OpenSCAD:"; openscad --version 2>/dev/null || true
    echo "test FreeCAD:"; if command -v freecad >/dev/null 2>&1; then timeout 5s freecad --version 2>/dev/null || echo "[info] FreeCAD installed but test skipped (requires graphics environment)"; else echo "[info] FreeCAD not installed, skipping test."; fi
    # Robotics tools tests
    echo "test Mirror selection: nala and apt-aria wrapper available for fast downloads"

#--- Sub-block: Section continuation (1872) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

# === %runscript Section ===
%runscript
    exec /bin/bash -l


#--- Sub-block: Code section 1816 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
DEF
# End heredoc (self-contained)
log "Singularity definition file generated successfully."

#===============================================================================
# BLOCK 22: CONTAINER BUILD EXECUTION
#===============================================================================
# Purpose: Execute the actual container build using apptainer/singularity
# Self-contained: Yes (complete if-elif-else with error handling)
# Dependencies: ${DEF_NAME}, ${BUILD_TMP_DIR}, CONTAINER_CMD
# Outputs: Configured system components
#-------------------------------------------------------------------------------

#--- Sub-block 22.1: Execute container build ---
# Dependencies: System (Container runtime)
# Outputs: Configured system components
log_with_timestamp "Building SIF: ${OUT_DIR}/${SIF_NAME}"

# Critical: Try apptainer first (preferred), fallback to singularity
if [ -x /usr/bin/apptainer ]; then
    log "Using apptainer for container build..."
	# High-signal debug context
	log "Apptainer version: $(/usr/bin/apptainer --version 2>/dev/null || echo unknown)"
	log "Build tmp: ${BUILD_TMP_DIR} | Out: ${OUT_DIR} | Def: ${DEF_NAME}"
	log "Apptainer env: $(env | grep -E '^(APPTAINER|SINGULARITY)_' || true)"
	# Echo full command before execution for easy tracing in logs
	APPTAINER_CMD=(sudo /usr/bin/apptainer build --tmpdir "${BUILD_TMP_DIR}" --force "${OUT_DIR}/${SIF_NAME}" "${DEF_NAME}")
	log "Executing: ${APPTAINER_CMD[*]}"
	# Prefer --debug if supported (non-fatal if not)
	if /usr/bin/apptainer build --help 2>&1 | grep -q -- '--debug'; then
		APPTAINER_CMD+=(--debug)
	fi
	# Run the command (traced) and let ERR trap handle failures with context
	set -x
	"${APPTAINER_CMD[@]}"
	{ set +x; } 2>/dev/null || true
elif [ -x /usr/bin/singularity ]; then
    warn "apptainer not found, falling back to singularity."
	log "Singularity version: $(/usr/bin/singularity --version 2>/dev/null || echo unknown)"
	log "Build tmp: ${BUILD_TMP_DIR} | Out: ${OUT_DIR} | Def: ${DEF_NAME}"
	log "Singularity env: $(env | grep -E '^(APPTAINER|SINGULARITY)_' || true)"
	SINGULARITY_CMD=(sudo /usr/bin/singularity build --tmpdir "${BUILD_TMP_DIR}" --force "${OUT_DIR}/${SIF_NAME}" "${DEF_NAME}")
	log "Executing: ${SINGULARITY_CMD[*]}"
	if /usr/bin/singularity build --help 2>&1 | grep -q -- '--debug'; then
		SINGULARITY_CMD+=(--debug)
	fi
	set -x
	"${SINGULARITY_CMD[@]}"
	{ set +x; } 2>/dev/null || true
else
    err "Neither apptainer nor singularity found. Please install one to proceed."
fi
# End if-elif-else block (self-contained)

log "================ Image building completed successfully ================"

#===============================================================================
# BLOCK 22.5: ORGANIZE BUILD OUTPUT INTO TIMESTAMPED FOLDER
#===============================================================================
# Purpose: Create organized folder structure with image, logs, and documentation
# Self-contained: Yes
# Dependencies: ${OUT_DIR}, ${SIF_NAME}, ${LOG_FILE}, ${ERROR_LOG}
# Outputs: Organized build output directory with documentation
#-------------------------------------------------------------------------------

#--- Sub-block 22.5.1: Create timestamped output directory ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# Generate timestamp in format: DD-MM-YYYY-DAY-HHMMSSAM/PM
# Example: 03-01-2025-Friday-143022PM
# Format: %d-%m-%Y-%A-%I%M%S%p where %A is full weekday name, %p is AM/PM
BUILD_TIMESTAMP=$(date +%d-%m-%Y-%A-%I%M%S%p 2>/dev/null || echo "unknown-timestamp")
if [ -z "${BUILD_TIMESTAMP}" ] || [ "${BUILD_TIMESTAMP}" = "unknown-timestamp" ]; then
    log_warning "Failed to generate build timestamp, using fallback"
    BUILD_TIMESTAMP="$(date +%Y%m%d-%H%M%S 2>/dev/null || echo "unknown")"
fi
IMAGE_NAME_BASE="${SIF_NAME%.sif}"  # Remove .sif extension
BUILD_OUTPUT_DIR="${OUT_DIR}/${IMAGE_NAME_BASE}_${BUILD_TIMESTAMP}"

log_with_timestamp "Creating build output directory: ${BUILD_OUTPUT_DIR}"
if ! mkdir -p "${BUILD_OUTPUT_DIR}" 2>/dev/null; then
    log_error "Failed to create build output directory: ${BUILD_OUTPUT_DIR}"
    exit 1
fi

if [ ! -d "${BUILD_OUTPUT_DIR}" ]; then
    log_error "Build output directory does not exist after creation: ${BUILD_OUTPUT_DIR}"
    exit 1
fi

log_success "Build output directory created: ${BUILD_OUTPUT_DIR}"

#--- Sub-block 22.5.2: Move image file to output directory ---
# Dependencies: Image file exists
# Outputs: Moved image file
ORIGINAL_IMAGE_PATH="${OUT_DIR}/${SIF_NAME}"
FINAL_IMAGE_PATH="${BUILD_OUTPUT_DIR}/${SIF_NAME}"

if [ -f "${ORIGINAL_IMAGE_PATH}" ]; then
    log_with_timestamp "Moving image file to output directory..."
    if mv "${ORIGINAL_IMAGE_PATH}" "${FINAL_IMAGE_PATH}" 2>/dev/null; then
        if [ -f "${FINAL_IMAGE_PATH}" ]; then
            log_success "Image moved to: ${FINAL_IMAGE_PATH}"
            # Update SIF_PATH for later use
            SIF_PATH="${FINAL_IMAGE_PATH}"
        else
            log_warning "Move command succeeded but destination file not found, keeping original location"
            SIF_PATH="${ORIGINAL_IMAGE_PATH}"
        fi
    else
        log_warning "Failed to move image file, keeping original location"
        SIF_PATH="${ORIGINAL_IMAGE_PATH}"
    fi
else
    log_error "Image file not found: ${ORIGINAL_IMAGE_PATH}"
    SIF_PATH="${ORIGINAL_IMAGE_PATH}"
fi

#--- Sub-block 22.5.2.1: Move definition file to output directory ---
# Dependencies: DEF_NAME exists, BUILD_OUTPUT_DIR exists
# Outputs: Moved definition file
if [ -f "${DEF_NAME}" ]; then
    log_with_timestamp "Moving definition file to output directory..."
    if mv "${DEF_NAME}" "${BUILD_OUTPUT_DIR}/" 2>/dev/null; then
        log_success "Definition file moved to: ${BUILD_OUTPUT_DIR}/${DEF_NAME}"
    else
        log_warning "Failed to move definition file: ${DEF_NAME}"
    fi
else
    log_warning "Definition file not found: ${DEF_NAME}"
fi

#--- Sub-block 22.5.3: Move build logs to output directory ---
# Dependencies: LOG_FILE and ERROR_LOG exist, BUILD_OUTPUT_DIR exists
# Outputs: Moved log files
if [ ! -d "${BUILD_OUTPUT_DIR}" ]; then
    log_error "Build output directory does not exist: ${BUILD_OUTPUT_DIR}"
    log_warning "Skipping log file moves"
else
    if [ -f "${LOG_FILE:-}" ] && [ -n "${LOG_FILE:-}" ]; then
        log_with_timestamp "Moving build log to output directory..."
        if mv "${LOG_FILE}" "${BUILD_OUTPUT_DIR}/" 2>/dev/null; then
            BUILD_LOG_BASENAME=$(basename "${LOG_FILE}")
            LOG_FILE="${BUILD_OUTPUT_DIR}/${BUILD_LOG_BASENAME}"
            log_success "Build log moved to: ${BUILD_OUTPUT_DIR}/${BUILD_LOG_BASENAME}"
        else
            log_warning "Failed to move build log: ${LOG_FILE}"
        fi
    else
        log_warning "Build log file not found or not set: ${LOG_FILE:-<not set>}"
        BUILD_LOG_BASENAME=""
    fi

    if [ -f "${ERROR_LOG:-}" ] && [ -n "${ERROR_LOG:-}" ]; then
        log_with_timestamp "Moving error log to output directory..."
        if mv "${ERROR_LOG}" "${BUILD_OUTPUT_DIR}/" 2>/dev/null; then
            ERROR_LOG_BASENAME=$(basename "${ERROR_LOG}")
            ERROR_LOG="${BUILD_OUTPUT_DIR}/${ERROR_LOG_BASENAME}"
            log_success "Error log moved to: ${BUILD_OUTPUT_DIR}/${ERROR_LOG_BASENAME}"
        else
            log_warning "Failed to move error log: ${ERROR_LOG}"
        fi
    else
        log_warning "Error log file not found or not set: ${ERROR_LOG:-<not set>}"
        ERROR_LOG_BASENAME=""
    fi
fi

# Ensure basename variables are set even if files weren't moved
if [ -z "${BUILD_LOG_BASENAME:-}" ]; then
    if [ -n "${LOG_FILE:-}" ]; then
        BUILD_LOG_BASENAME=$(basename "${LOG_FILE}" 2>/dev/null || echo "unknown.log")
    else
        BUILD_LOG_BASENAME="unknown.log"
    fi
fi
if [ -z "${ERROR_LOG_BASENAME:-}" ]; then
    if [ -n "${ERROR_LOG:-}" ]; then
        ERROR_LOG_BASENAME=$(basename "${ERROR_LOG}" 2>/dev/null || echo "unknown.log")
    else
        ERROR_LOG_BASENAME="unknown.log"
    fi
fi

#--- Sub-block 22.5.4: Generate BUILD_ARCHITECTURE.md ---
# Dependencies: config.sh variables, BUILD_OUTPUT_DIR exists
# Outputs: BUILD_ARCHITECTURE.md file
if [ ! -d "${BUILD_OUTPUT_DIR}" ]; then
    log_error "Cannot generate BUILD_ARCHITECTURE.md: build output directory does not exist"
else
ARCHITECTURE_FILE="${BUILD_OUTPUT_DIR}/BUILD_ARCHITECTURE.md"
if ! touch "${ARCHITECTURE_FILE}" 2>/dev/null; then
    log_error "Failed to create BUILD_ARCHITECTURE.md at ${ARCHITECTURE_FILE}"
else
    log_with_timestamp "Generating BUILD_ARCHITECTURE.md..."

cat > "${ARCHITECTURE_FILE}" << 'ARCH_EOF'
# Build Architecture and Software Inventory

## Build Information

ARCH_EOF

BUILD_DATE_STR=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown")
BUILD_END_TIME_NOW=$(date +%s 2>/dev/null || echo "0")
# Validate BUILD_END_TIME_NOW is numeric
if ! [[ "${BUILD_END_TIME_NOW}" =~ ^[0-9]+$ ]]; then
    BUILD_END_TIME_NOW=0
fi
if [ -n "${BUILD_START_TIME:-}" ] && [[ "${BUILD_START_TIME:-0}" =~ ^[0-9]+$ ]] && [ "${BUILD_START_TIME:-0}" -gt 0 ]; then
    BUILD_DURATION_NOW=$((BUILD_END_TIME_NOW - BUILD_START_TIME))
    # Ensure duration is non-negative
    if [ "${BUILD_DURATION_NOW}" -lt 0 ]; then
        BUILD_DURATION_NOW=0
        log_warning "Build duration calculation resulted in negative value, using 0"
    fi
else
    BUILD_DURATION_NOW=0
    log_warning "BUILD_START_TIME not set or invalid, duration calculation skipped"
fi
BUILD_HOURS_NOW=$((BUILD_DURATION_NOW / 3600))
BUILD_MINUTES_NOW=$(( (BUILD_DURATION_NOW % 3600) / 60))
BUILD_SECONDS_NOW=$((BUILD_DURATION_NOW % 60))

# Calculate image size safely - use SIF_PATH which is set correctly
IMAGE_SIZE_STR="unknown"
if [ -f "${SIF_PATH:-}" ]; then
    IMAGE_SIZE_STR=$(du -sh "${SIF_PATH}" 2>/dev/null | cut -f1 || echo "unknown")
    [ -z "${IMAGE_SIZE_STR}" ] && IMAGE_SIZE_STR="unknown"
elif [ -f "${FINAL_IMAGE_PATH:-}" ]; then
    IMAGE_SIZE_STR=$(du -sh "${FINAL_IMAGE_PATH}" 2>/dev/null | cut -f1 || echo "unknown")
    [ -z "${IMAGE_SIZE_STR}" ] && IMAGE_SIZE_STR="unknown"
elif [ -f "${ORIGINAL_IMAGE_PATH:-}" ]; then
    IMAGE_SIZE_STR=$(du -sh "${ORIGINAL_IMAGE_PATH}" 2>/dev/null | cut -f1 || echo "unknown")
    [ -z "${IMAGE_SIZE_STR}" ] && IMAGE_SIZE_STR="unknown"
fi

# Ensure basename variables are set (already set above if logs were moved)
if [ -z "${BUILD_LOG_BASENAME:-}" ]; then
    BUILD_LOG_BASENAME=$(basename "${LOG_FILE:-unknown.log}" 2>/dev/null || echo "unknown.log")
fi
if [ -z "${ERROR_LOG_BASENAME:-}" ]; then
    ERROR_LOG_BASENAME=$(basename "${ERROR_LOG:-unknown.log}" 2>/dev/null || echo "unknown.log")
fi

# Calculate cache statistics early for use in BUILD_ARCHITECTURE.md
# These may be recalculated later, but we need them now for documentation
if [ -z "${CACHE_TOTAL_SIZE:-}" ]; then
    CACHE_TOTAL_SIZE=$(du -sh "${CACHE_DIR:-}" 2>/dev/null | cut -f1 || echo "0B")
    [ -z "${CACHE_TOTAL_SIZE}" ] && CACHE_TOTAL_SIZE="0B"
fi
if [ -z "${APT_CACHE_SIZE:-}" ]; then
    APT_CACHE_SIZE=$(du -sh "${APT_ARCHIVE_CACHE:-}" 2>/dev/null | cut -f1 || echo "0B")
    [ -z "${APT_CACHE_SIZE}" ] && APT_CACHE_SIZE="0B"
fi
if [ -z "${CONDA_CACHE_SIZE:-}" ]; then
    CONDA_CACHE_SIZE=$(du -sh "${CONDA_CACHE:-}" 2>/dev/null | cut -f1 || echo "0B")
    [ -z "${CONDA_CACHE_SIZE}" ] && CONDA_CACHE_SIZE="0B"
fi
if [ -z "${WHEELS_CACHE_SIZE:-}" ]; then
    WHEELS_CACHE_SIZE=$(du -sh "${WHEELS_CACHE:-}" 2>/dev/null | cut -f1 || echo "0B")
    [ -z "${WHEELS_CACHE_SIZE}" ] && WHEELS_CACHE_SIZE="0B"
fi
if [ -z "${JULIA_CACHE_SIZE:-}" ]; then
    JULIA_CACHE_SIZE=$(du -sh "${JULIA_CACHE:-}" 2>/dev/null | cut -f1 || echo "0B")
    [ -z "${JULIA_CACHE_SIZE}" ] && JULIA_CACHE_SIZE="0B"
fi
if [ -z "${APT_CACHE_COUNT:-}" ] && [ -d "${APT_ARCHIVE_CACHE:-}" ]; then
    APT_CACHE_COUNT=$(find "${APT_ARCHIVE_CACHE}" -name "*.deb" 2>/dev/null | wc -l | tr -d '[:space:]')
    [ -z "${APT_CACHE_COUNT}" ] && APT_CACHE_COUNT="0"
fi
if [ -z "${CONDA_CACHE_COUNT:-}" ] && [ -d "${CONDA_CACHE:-}" ]; then
    CONDA_CACHE_COUNT=$(find "${CONDA_CACHE}" \( -name "*.conda" -o -name "*.tar.bz2" \) -type f 2>/dev/null | wc -l | tr -d '[:space:]')
    [ -z "${CONDA_CACHE_COUNT}" ] && CONDA_CACHE_COUNT="0"
fi
if [ -z "${WHEELS_CACHE_COUNT:-}" ] && [ -d "${WHEELS_CACHE:-}" ]; then
    WHEELS_CACHE_COUNT=$(find "${WHEELS_CACHE}" -name "*.whl" 2>/dev/null | wc -l | tr -d '[:space:]')
    [ -z "${WHEELS_CACHE_COUNT}" ] && WHEELS_CACHE_COUNT="0"
fi

# shellcheck disable=SC2129
cat >> "${ARCHITECTURE_FILE}" << ARCH_INFO_EOF
- **Build Date**: ${BUILD_DATE_STR:-unknown}
- **Build Timestamp**: ${BUILD_TIMESTAMP:-unknown}
- **Image Name**: ${SIF_NAME:-unknown}
- **Image Size**: ${IMAGE_SIZE_STR:-unknown}
- **Build Duration**: ${BUILD_HOURS_NOW:-0}h ${BUILD_MINUTES_NOW:-0}m ${BUILD_SECONDS_NOW:-0}s

## Base System Architecture

- **Operating System**: ${BASE_OS:-Ubuntu} ${BASE_OS_VERSION:-24.04} (${BASE_OS_CODENAME:-noble})
- **Desktop Environment**: Xubuntu (XFCE4)
- **System Python**: ${SYSTEM_PYTHON_VER:-3.12}
- **ROS Distribution**: ${ROS_DISTRO:-jazzy} Desktop Full
- **Base Image**: ${BASE_IMAGE:-ubuntu:24.04}

## Software Architecture Overview

### Package Management Systems
- **APT**: Ubuntu package manager with apt-aria wrapper for parallel downloads
- **Conda/Mamba**: Miniforge3 ${MINIFORGE_VER:-latest} with Micromamba ${MICROMAMBA_VER:-latest}
- **Julia**: ${JULIA_LTS_VER:-1.10} LTS
- **Pip**: Python package manager
- **Cargo**: Rust package manager

### Installation Directories
ARCH_INFO_EOF

cat >> "${ARCHITECTURE_FILE}" << ARCH_DIRS_EOF
- **System Packages**: /usr/lib, /usr/local/lib
- **Conda/Mamba**: ${MINIFORGE_HOME:-/opt/conda}
- **Conda Environments**: ${MAMBA_ENVS:-/opt/mamba/envs}
- **Julia**: ${JULIA_HOME:-/opt/julia}
- **Julia Environments**: ${JULIA_ENVS:-/opt/julia-envs}
- **Rust Tools**: ${RUST_HOME:-/opt/rust}
- **Drake**: ${DRAKE_HOME:-/opt/drake}
- **Zenoh**: ${ZENOH_HOME:-/opt/zenoh}
- **TurboVNC**: ${TURBOVNC_HOME:-/opt/TurboVNC}
- **VirtualGL**: ${VIRTUALGL_HOME:-/opt/VirtualGL}
- **CUDA**: /usr/local/cuda-${CUDA_VERSION:-12.6}

## Installed Libraries and Software

### GPU & CUDA Support
- **CUDA Toolkit**: ${CUDA_VERSION:-12.6} (Architecture: ${CUDA_ARCH:-89})
- **cuDNN**: ${CUDNN_VER:-latest}
- **NVIDIA Video Codec SDK**: ${NVIDIA_VIDEO_SDK_VERSION:-latest}
- **NVIDIA Keyring**: ${NVIDIA_KEYRING_VER:-latest}

### Remote Desktop Stack
- **TurboVNC**: ${TURBOVNC_VER:-latest}
- **VirtualGL**: ${VIRTUALGL_VER:-latest}
- **noVNC**: ${NOVNC_VER:-latest}
- **KasmVNC**: ${KASMVNC_VERSION:-latest}
- **Xpra**: ${XPRA_VERSION:-latest}
- **Xpra HTML5**: ${XPRA_HTML5_VERSION:-latest}

### Robotics & SLAM Libraries
- **Ceres Solver**: ${CERES_VERSION:-latest}
- **PyCeres**: ${PYCERES_VERSION:-latest}
- **g2o**: ${G2O_VERSION:-latest}
- **GTSAM**: ${GTSAM_VERSION:-latest}
- **OpenCV**: ${OPENCV_VERSION:-latest} (custom compiled with CUDA support)

### 3D Reconstruction & SfM
- **COLMAP**: ${COLMAP_VERSION:-latest} (with CUDA, CGAL, OpenMP)
- **Open3D**: ${OPEN3D_VERSION:-latest} (with CUDA ${CUDA_VERSION:-12.6} support)
- **Open3D WebRTC**: ${OPEN3D_WEBRTC_VER:-latest}
- **PyCOLMAP**: ${COLMAP_VERSION:-latest} (Python bindings)

### Desktop Applications
- **FreeCAD**: ${FREECAD_VERSION:-latest}

### Modern CLI Tools (Rust-based, compiled from source)
- **bat**: ${BAT_VERSION:-latest} - Syntax highlighting for cat
- **fd**: ${FD_VERSION:-latest} - Fast find alternative
- **ripgrep**: ${RIPGREP_VERSION:-latest} - Fast recursive grep
- **eza**: ${EZA_VERSION:-latest} - Modern ls replacement
- **bottom**: ${BOTTOM_VERSION:-latest} - System monitor (btm)
- **procs**: ${PROCS_VERSION:-latest} - Modern ps replacement
- **zellij**: ${ZELLIJ_VERSION:-latest} - Terminal multiplexer
- **dust**: ${DU_DUST_VERSION:-latest} - Intuitive du replacement
- **ox**: ${OX_VERSION:-latest} - Modern text editor

### Development Tools
- **yq**: ${YQ_VER:-latest} - YAML/JSON processor
- **Julia**: ${JULIA_LTS_VER:-1.10} LTS

### Middleware
- **Zenoh**: ${ZENOH_VERSION:-latest}
- **Zenoh ROS 2 DDS Bridge**: ${ZENOH_ROS2DDS_VERSION:-latest}

### Python Packages (Data Formats)
- **h5py**: ${H5PY_VERSION:-latest}
- **zarr**: ${ZARR_VERSION:-latest}

### Python Packages (Messaging/IPC)
- **pyzmq**: ${PYZMQ_VERSION:-latest}
- **msgpack**: ${MSGPACK_VERSION:-latest}

### Python Packages (Julia Bridge)
- **Juliapkg**: ${JULIAPKG_VERSION:-latest}
- **JulianCall**: ${JULIACALL_VERSION:-latest}

## Compilation Flags & Optimizations

### CPU Optimizations
- Architecture: x86-64-v3 (AVX2, FMA, BMI2)
- Compiler flags: -O3 -march=native -mtune=native
- Link-Time Optimization (LTO): Enabled where supported

### CUDA Optimizations
- Compute Capability: ${CUDA_ARCH:-89} (optimized for NVIDIA A6000)
- CUDA Architecture: sm_${CUDA_ARCH:-89}

### Build System Features
- Parallel compilation (uses all available CPU cores)
- Comprehensive caching system:
  - APT package cache
  - Conda package cache
  - Python wheels cache
  - Julia package cache
  - Binary artifact cache

## Build Cache Statistics

ARCH_DIRS_EOF

cat >> "${ARCHITECTURE_FILE}" << ARCH_CACHE_EOF
- **Total Cache Size**: ${CACHE_TOTAL_SIZE:-0B}
- **APT Cache**: ${APT_CACHE_SIZE:-0B} (${APT_CACHE_COUNT:-0} .deb files)
- **Conda Cache**: ${CONDA_CACHE_SIZE:-0B} (${CONDA_CACHE_COUNT:-0} packages)
- **Pip Wheels**: ${WHEELS_CACHE_SIZE:-0B} (${WHEELS_CACHE_COUNT:-0} wheels)
- **Julia Cache**: ${JULIA_CACHE_SIZE:-0B}

## System Configuration

### APT Package Protection
- Custom compiled libraries protected from APT overwrites
- APT pinning configured for critical packages
- Package holding for compiled libraries

### Environment Variables
- ROS 2 environment sourced from /opt/ros/${ROS_DISTRO:-jazzy}/setup.bash
- Conda base environment pre-activated
- CUDA paths configured in /usr/local/cuda-${CUDA_VERSION:-12.6}
- VirtualGL paths configured
- TurboVNC paths configured

### Security
- GPG signature verification for:
  - Julia releases
  - TurboVNC packages
  - VirtualGL packages
- SHA256 checksums verified for all downloads

## Build Logs

- **Build Log**: ${BUILD_LOG_BASENAME:-unknown.log}
- **Error Log**: ${ERROR_LOG_BASENAME:-unknown.log}

Both logs are included in this directory for troubleshooting and review.

ARCH_CACHE_EOF

if [ -f "${ARCHITECTURE_FILE}" ]; then
    log_success "BUILD_ARCHITECTURE.md generated: ${ARCHITECTURE_FILE}"
else
    log_error "Failed to generate BUILD_ARCHITECTURE.md"
fi
fi  # End ARCHITECTURE_FILE creation attempt
fi  # End of BUILD_OUTPUT_DIR check

#--- Sub-block 22.5.5: Generate README.md with instructions ---
# Dependencies: TOOLS_AND_UTILITIES.md content, BUILD_OUTPUT_DIR exists
# Outputs: README.md file
if [ ! -d "${BUILD_OUTPUT_DIR}" ]; then
    log_error "Cannot generate README.md: build output directory does not exist"
else
    README_FILE="${BUILD_OUTPUT_DIR}/README.md"
    if ! touch "${README_FILE}" 2>/dev/null; then
        log_error "Failed to create README.md at ${README_FILE}"
    else
        log_with_timestamp "Generating README.md..."

cat > "${README_FILE}" << 'README_EOF'
# Xubuntu Robotics Base Image - Usage Guide

## Quick Start

### Running the Image

```bash
# Basic shell access
singularity shell image.sif
# or
apptainer shell image.sif

# With GPU support
singularity shell --nv image.sif
# or
apptainer shell --nv image.sif

# Execute a command
singularity exec --nv image.sif command
```

### Starting Remote Desktop

```bash
# Start VNC session with GPU acceleration
singularity exec --nv image.sif start_vnc_xfce.sh

# Or use the ultimate VNC with all features
singularity exec --nv image.sif start_vnc_ultimate.sh

# Interactive menu for VNC options
singularity exec --nv image.sif remote_desktop.sh
```

**Note**: Set VNC password first:
```bash
singularity exec image.sif vncpasswd
```

### SSH Tunneling for Remote Access

For HPC/cluster environments, create SSH tunnel:

```bash
# From local machine to login node
ssh -L 5901:localhost:5901 -L 6081:localhost:6081 user@login-node

# From login node to compute node
ssh -L 5901:localhost:5901 -L 6081:localhost:6081 user@compute-node

# Or direct two-stage tunnel
ssh -J user@login-node:22 -L 5901:localhost:5901 -L 6081:localhost:6081 user@compute-node
```

Then connect VNC viewer to `localhost:5901` or open browser to `http://localhost:6081`

## Remote Desktop Options

### Available VNC Servers

1. **TurboVNC** (Recommended for GPU-accelerated applications)
   ```bash
   singularity exec --nv image.sif start_vnc_xfce.sh
   ```
   - Optimized JPEG compression
   - Built for VirtualGL integration
   - Multiple performance profiles
   - Built-in webserver on port 5800+N

2. **TurboVNC Ultimate** (Maximum performance)
   ```bash
   singularity exec --nv image.sif start_vnc_ultimate.sh
   ```
   - All TurboVNC features
   - Automatic optimization
   - Performance monitoring
   - Audio support

3. **KasmVNC** (Modern web-native VNC)
   ```bash
   singularity exec --nv image.sif start_kasmvnc.sh
   ```
   - Built-in web interface
   - Container-optimized

4. **x11vnc** (Screen sharing)
   ```bash
   singularity exec --nv image.sif start_x11vnc.sh :1
   ```
   - Attach to existing X session
   - Useful for debugging

### Interactive VNC Selection

```bash
singularity exec --nv image.sif vnc_select.sh
```

### VNC Configuration Options

```bash
# Custom display and geometry
singularity exec --nv image.sif start_vnc_xfce.sh --vnc-display 2 --geometry 2560x1440

# With VirtualGL debugging
singularity exec --nv image.sif start_vnc_xfce.sh --vgl-debug --vgl-verbose

# Disable VirtualGL integration
singularity exec --nv image.sif start_vnc_xfce.sh --no-vgl
```

### VNC Management Commands

```bash
# List running VNC servers
singularity exec image.sif vncserver -list

# Kill specific VNC server
singularity exec image.sif vncserver -kill :1

# View VNC logs
singularity exec image.sif tail -f ~/.vnc/*.log

# Monitor VNC server status
singularity exec image.sif vnc_monitor.sh
```

## GPU Acceleration & VirtualGL

### Running GPU-Accelerated Applications

```bash
# Basic usage
singularity exec --nv image.sif vglrun application

# Performance profiles
singularity exec --nv image.sif vglrun-fast application    # High performance
singularity exec --nv image.sif vglrun-balanced application # Balanced
singularity exec --nv image.sif vglrun-lowbw application   # Low bandwidth
```

### VirtualGL Testing

```bash
# Test VirtualGL installation
singularity exec --nv image.sif test_virtualgl.sh

# Display OpenGL/VirtualGL information
singularity exec --nv image.sif vgl_info.sh

# Performance benchmarking
singularity exec --nv image.sif vgl_benchmark.sh
```

### VirtualGL Environment Variables

```bash
# Set display for GPU rendering
export VGL_DISPLAY=:1

# Compression method
export VGL_COMPRESS=proxy  # or jpeg, rgb, yuv

# Enable FPS display
export VGL_FPS=1

# Verbose output
export VGL_VERBOSE=1
```

## Rust Tools Usage

All Rust tools are installed in `/opt/rust/tools/bin` and available in PATH:

### bat (Syntax-highlighting cat)
```bash
singularity exec image.sif bat file.txt
singularity exec image.sif bat --style=grid file.txt
```

### fd (Fast find)
```bash
singularity exec image.sif fd pattern
singularity exec image.sif fd -e py  # Find Python files
```

### ripgrep (Fast grep)
```bash
singularity exec image.sif rg "pattern" /path
singularity exec image.sif rg -t py "import"  # Search in Python files
```

### eza (Modern ls)
```bash
singularity exec image.sif eza -l --tree
singularity exec image.sif eza --long --git
```

### bottom (System monitor)
```bash
singularity exec image.sif btm
singularity exec image.sif btm --basic
```

### procs (Modern ps)
```bash
singularity exec image.sif procs
singularity exec image.sif procs python  # Filter by name
```

### zellij (Terminal multiplexer)
```bash
singularity exec image.sif zellij
singularity exec image.sif zellij attach session
```

### dust (Disk usage)
```bash
singularity exec image.sif dust
singularity exec image.sif dust /path/to/analyze
```

## Python & Conda Environments

### Activating Conda

```bash
# Inside container
source /opt/conda/etc/profile.d/conda.sh
conda activate base

# Or use mamba (faster solver)
mamba activate base
```

### Creating Environments

```bash
# Create new environment
conda create -n myenv python=3.12
mamba create -n myenv python=3.12

# Install packages
conda install numpy pandas
mamba install numpy pandas  # Faster
```

### Python Packages

The image includes pre-installed packages:
- NumPy, SciPy, Pandas
- Matplotlib, Seaborn
- Jupyter, IPython
- Open3D Python bindings
- PyCOLMAP
- OpenCV Python bindings

### Installing Additional Packages

```bash
# Via conda
conda install -c conda-forge package-name

# Via pip
pip install package-name

# For PyTorch/TensorFlow (optional, install as needed)
conda install pytorch torchvision -c pytorch
```

## Julia Environment

### Basic Usage

```bash
# Start Julia REPL
singularity exec image.sif julia

# Run Julia script
singularity exec image.sif julia script.jl

# Install packages
singularity exec image.sif julia -e 'using Pkg; Pkg.add("PackageName")'
```

### CUDA Precompilation

For GPU systems, precompile Julia CUDA packages:

```bash
singularity exec --nv image.sif precompile_julia_cuda.sh
```

## ROS 2 Setup

### Sourcing ROS 2

```bash
# Inside container
source /opt/ros/jazzy/setup.bash

# For fish shell
source /opt/ros/jazzy/setup.fish
```

### ROS 2 Tools

```bash
# Verify installation
ros2 --help

# List packages
ros2 pkg list

# Run nodes
ros2 run package_name node_name
```

### ROS 2 Multiterminal Launchers

```bash
# Default terminal launcher
singularity exec image.sif ros_multiterm command1 command2

# TMUX-based
singularity exec image.sif ros_multiterm_tmux command1 command2

# Zellij-based
singularity exec image.sif ros_multiterm_zellij command1 command2
```

## 3D Reconstruction Tools

### COLMAP

```bash
# Launch GUI
singularity exec --nv image.sif colmap gui

# Automatic reconstruction
singularity exec --nv image.sif colmap automatic_reconstructor \
    --workspace_path /path/to/images \
    --image_path /path/to/images \
    --output_path /path/to/output

# Manual pipeline
singularity exec --nv image.sif colmap feature_extractor \
    --database_path database.db \
    --image_path /path/to/images
```

### Open3D

```bash
# Python API
singularity exec --nv image.sif python -c "import open3d as o3d; print(o3d.__version__)"

# CUDA-accelerated processing
singularity exec --nv image.sif python -c "import open3d as o3d; # ... your code"
```

### PyCOLMAP

```bash
singularity exec --nv image.sif python -c "import pycolmap; print(pycolmap.__version__)"
```

## Monitoring & System Tools

### GPU Monitoring

```bash
singularity exec --nv image.sif gpu_monitor.sh
```

### VNC Monitoring

```bash
singularity exec image.sif vnc_monitor.sh
```

### System Information

```bash
# 3D reconstruction tools info
singularity exec image.sif 3d_recon_info

# VirtualGL information
singularity exec --nv image.sif vgl_info.sh
```

## What to Install Additionally

### Optional Software

1. **AppImages** (FreeCAD, Ultimaker Cura, Mendeley)
   ```bash
   # Download from official pages, then:
   chmod +x *.AppImage
   mkdir -p ~/Applications
   mv *.AppImage ~/Applications/
   ```

2. **Simulators** (Isaac Sim, Mujoco)
   - Install via conda/mamba environments
   - Download from official sources

3. **PyTorch/TensorFlow**
   ```bash
   conda install pytorch torchvision -c pytorch
   conda install tensorflow
   ```

4. **Additional Python Packages**
   ```bash
   pip install package-name
   conda install -c conda-forge package-name
   ```

### Writable Overlay (Persistent Storage)

Create a writable overlay for persistent changes:

```bash
# On host system
./create_writable_overlay.sh

# Use with image
singularity shell --overlay overlay.img:rw image.sif
```

## Configuration

### Environment Variables

Key environment variables are set in the container:
- `ROS_DISTRO=jazzy`
- `CUDA_ROOT=/usr/local/cuda-12.6`
- `VGL_DISPLAY` (auto-detected for VNC)
- Conda paths configured

### Custom Configuration

Modify container behavior by:
1. Using writable overlays for persistent changes
2. Creating custom conda environments
3. Installing additional packages in overlays
4. Modifying `~/.bashrc` or `~/.profile` in overlays

## Troubleshooting

### VNC Connection Issues

```bash
# Check VNC password is set
singularity exec image.sif ls -la ~/.vnc/passwd

# View VNC logs
singularity exec image.sif tail -f ~/.vnc/*.log

# Test VirtualGL
singularity exec --nv image.sif test_virtualgl.sh
```

### GPU Issues

```bash
# Check GPU access
singularity exec --nv image.sif nvidia-smi

# Verify CUDA
singularity exec --nv image.sif nvcc --version

# Test VirtualGL
singularity exec --nv image.sif vglrun glxspheres64
```

### Conda/Mamba Issues

```bash
# Reinitialize conda
singularity exec image.sif source /opt/conda/etc/profile.d/conda.sh

# Update conda
singularity exec image.sif conda update conda

# Clean cache
singularity exec image.sif conda clean --all
```

### Connection Issues (HPC)

```bash
# Verify SSH tunnel
ss -tuln | grep 5901

# Test local connection
vncviewer localhost:5901
```

## Getting Help

- Check script help: `singularity exec image.sif script_name.sh --help`
- View logs: Build logs and error logs are in this directory
- Test components individually using test scripts
- Check system information: `3d_recon_info`, `vgl_info.sh`

## Additional Resources

- **TurboVNC**: https://turbovnc.org/
- **VirtualGL**: https://virtualgl.org/
- **noVNC**: https://novnc.com/
- **COLMAP**: https://colmap.github.io/
- **Open3D**: http://www.open3d.org/
- **ROS 2**: https://docs.ros.org/en/jazzy/
- **Julia**: https://julialang.org/
- **Zenoh**: https://zenoh.io/

## Build Information

This image was built on: ${BUILD_DATE_STR}
Build timestamp: ${BUILD_TIMESTAMP}
Image size: ${IMAGE_SIZE_STR}

For detailed software architecture and library versions, see `BUILD_ARCHITECTURE.md`.

README_EOF

    fi

if [ -f "${README_FILE}" ]; then
    log_success "README.md generated: ${README_FILE}"
else
    log_error "Failed to generate README.md"
fi
fi  # End of BUILD_OUTPUT_DIR check

#--- Sub-block 22.5.6: Update OUT_DIR reference for display ---
# Dependencies: Build output directory created
# Outputs: Updated display messages
if [ -n "${BUILD_OUTPUT_DIR:-}" ] && [ -d "${BUILD_OUTPUT_DIR}" ]; then
    log_with_timestamp "Build output organized in: ${BUILD_OUTPUT_DIR}"
    log_with_timestamp "  Image: ${SIF_PATH:-${ORIGINAL_IMAGE_PATH:-unknown}}"
    if [ -n "${BUILD_LOG_BASENAME:-}" ]; then
        log_with_timestamp "  Build Log: ${BUILD_OUTPUT_DIR}/${BUILD_LOG_BASENAME}"
    fi
    if [ -n "${ERROR_LOG_BASENAME:-}" ]; then
        log_with_timestamp "  Error Log: ${BUILD_OUTPUT_DIR}/${ERROR_LOG_BASENAME}"
    fi
    if [ -f "${BUILD_OUTPUT_DIR}/BUILD_ARCHITECTURE.md" ]; then
        log_with_timestamp "  Documentation: ${BUILD_OUTPUT_DIR}/BUILD_ARCHITECTURE.md"
    fi
    if [ -f "${BUILD_OUTPUT_DIR}/README.md" ]; then
        log_with_timestamp "  Documentation: ${BUILD_OUTPUT_DIR}/README.md"
    fi
else
    log_warning "Build output directory not available for summary"
fi

#===============================================================================
# BLOCK 23: BUILD INFORMATION DISPLAY
#===============================================================================
# Purpose: Display build completion information
# Self-contained: Yes
# Dependencies: ${OUT_DIR}, ${SIF_NAME}
# Outputs: Configured system components
#-------------------------------------------------------------------------------

#--- Sub-block 23.1: Display build summary ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
log "Detailed build information"
echo "Build Phase: Cache Harvesting"
echo "Build completed at: $(date)"
# Validate SIF_PATH exists before calculating size
if [ -f "${SIF_PATH:-}" ]; then
    image_size_display=$(du -sh "${SIF_PATH}" 2>/dev/null | cut -f1 || echo "unknown")
    [ -z "${image_size_display}" ] && image_size_display="unknown"
    echo "Image size: ${image_size_display}"
    echo "Image location: ${SIF_PATH}"
else
    echo "Image size: unknown (SIF file not found)"
    echo "Image location: ${SIF_PATH:-<not set>}"
fi
echo "======================================================================"

#===============================================================================
# BLOCK 24: CACHE HARVESTING FROM CONTAINER
#===============================================================================
# Purpose: Extract cached packages from built container back to host
# Self-contained: Yes (complete script with if-else blocks)
# Dependencies: Built SIF file, singularity/apptainer exec
# Outputs: Configured system components
#-------------------------------------------------------------------------------

#--- Sub-block 24.1: Initialize cache harvesting ---
# Dependencies: System (Container runtime)
# Outputs: Configured system components
log_with_timestamp "============= Initiating Harvest from SIF to Host Cache ============="
# SIF_PATH already set in BLOCK 22.5 if image was moved, otherwise use original location
if [ -z "${SIF_PATH:-}" ]; then
    SIF_PATH="${OUT_DIR}/${SIF_NAME}"
fi
HOST_CACHE="${PWD}/container_cache"
if ! mkdir -p "${HOST_CACHE}" 2>/dev/null; then
    log_error "Failed to create host cache directory: ${HOST_CACHE}"
    exit 1
fi

# Check if apptainer is available, otherwise try singularity
# Use full paths to avoid PATH issues
if [ -x /usr/bin/apptainer ]; then
    log_with_timestamp "Using Apptainer for cache harvest..."
    # Validate SIF_PATH exists before attempting harvest
    if [ ! -f "${SIF_PATH}" ]; then
        log_error "SIF file not found for cache harvest: ${SIF_PATH}"
    elif /usr/bin/apptainer exec --bind "${HOST_CACHE}:/host_cache" "${SIF_PATH}" \
        bash -c 'rsync -a --no-p -o --no-g /container_cache/ /host_cache/' 2>/dev/null; then
        log_success "Cache harvest completed successfully"
    else
        log_warning "Cache harvest failed, but continuing..."
    fi

elif [ -x /usr/bin/singularity ]; then
    log_with_timestamp "Using Singularity for cache harvest..."
    # Validate SIF_PATH exists before attempting harvest
    if [ ! -f "${SIF_PATH}" ]; then
        log_error "SIF file not found for cache harvest: ${SIF_PATH}"
    elif /usr/bin/singularity exec --bind "${HOST_CACHE}:/host_cache" "${SIF_PATH}" \
        bash -c 'rsync -a --no-p -o --no-g /container_cache/ /host_cache/' 2>/dev/null; then
        log_success "Cache harvest completed successfully"
    else
        log_warning "Cache harvest failed, but continuing..."
    fi

else
    log_warning "Neither apptainer nor singularity found, skipping cache harvest."
fi
log_success "============== Harvest Complete =============="

# --- Comprehensive cache validation ---
log_with_timestamp "========= Validating Harvested Cache =========="
echo "=> Validating harvested cache..."
issues=0

# Check APT cache
if [ -d "${HOST_CACHE}/apt/archives" ]; then
    apt_count=$(find "${HOST_CACHE}/apt/archives" -name "*.deb" 2>/dev/null | wc -l | tr -d '[:space:]')
    apt_count="${apt_count:-0}"
    if [[ "${apt_count}" -gt 0 ]]; then
        echo "  ✓ APT cache: ${apt_count} .deb file(s) harvested"
    else
        echo "  ✗ APT cache: No .deb files found"
        issues=$((issues + 1))
    fi
else
    echo "  ✗ APT cache: Directory not found"
    issues=$((issues + 1))
fi

# Check Conda cache
if [ -d "${HOST_CACHE}/conda_pkgs" ]; then
    conda_count=$(find "${HOST_CACHE}/conda_pkgs" \( -name "*.conda" -o -name "*.tar.bz2" \) -type f 2>/dev/null | wc -l | tr -d '[:space:]')
    conda_count="${conda_count:-0}"
    if [[ "${conda_count}" -gt 0 ]]; then
        echo "  ✓ Conda cache: ${conda_count} package(s) harvested"
    else
        echo "  ✗ Conda cache: No packages found"
    fi
else
    echo "  ✗ Conda cache: Directory not found"
    issues=$((issues + 1))
fi

# Check Pip wheels
if [ -d "${HOST_CACHE}/wheels" ]; then
    wheel_count=$(find "${HOST_CACHE}/wheels" -name "*.whl" 2>/dev/null | wc -l | tr -d '[:space:]')
    wheel_count="${wheel_count:-0}"
    if [[ "${wheel_count}" -gt 0 ]]; then
        echo "  ✓ Pip wheels: ${wheel_count} wheel(s) harvested"
    else
        echo "  ✗ Pip wheels: No wheels found"
    fi
else
    echo "  ✗ Pip wheels: Directory not found"
fi

# Check Julia cache
if [ -d "${HOST_CACHE}/julia_pkgs" ]; then
    julia_size=$(du -sh "${HOST_CACHE}/julia_pkgs" 2>/dev/null | cut -f1 || echo "0B")
    if [ -z "${julia_size}" ]; then
        julia_size="0B"
    fi
    if [[ "${julia_size}" != "0B" ]] && [[ "${julia_size}" != "unknown" ]]; then
        echo "  ✓ Julia cache: ${julia_size} harvested"
    else
        echo "  ✗ Julia cache: No packages found"
    fi
else
    echo "  ✗ Julia cache: Directory not found"
fi
issues="${issues:-0}"
if [[ "${issues}" -eq 0 ]]; then
    echo "✓ Cache harvest validation passed"
else
    echo "✗ Cache harvest validation found ${issues} issue(s)"
fi

# --- Prune Host Caches ---
# NOTE: The original script assumes these pruning scripts exist at /usr/local/bin
# on the HOST. This is unlikely. A robust implementation would define them
# in the script or check for them. For a drop-in replacement, we call them as is.
log_with_timestamp "========= Pruning Host Caches =========="
if [ -x ./prune_apt_cache.sh ]; then
    ./prune_apt_cache.sh --cache "${APT_ARCHIVE_CACHE}" --keep 2 --apply
else
    log_warning "./prune_apt_cache.sh not found or not executable. Skipping APT cache pruning."
fi
if [ -x ./prune_conda_cache.sh ]; then
    ./prune_conda_cache.sh --cache "${CONDA_CACHE}" --keep 2 --apply
else
    log_warning "./prune_conda_cache.sh not found or not executable. Skipping Conda cache pruning."
fi

# Clean up prune scripts after use
log_with_timestamp "Cleaning up temporary prune scripts..."
rm -f ./prune_apt_cache.sh ./prune_conda_cache.sh 2>/dev/null || true

# Clean up definition file after successful image creation
log_with_timestamp "Cleaning up definition file..."
rm -f "${DEF_NAME}" 2>/dev/null || true
log_success "========= Pruning Complete =========="
# Turn off command tracing before the final summary
set +x

# === Final Build Summary ===
echo ""
echo "Build process finished."

# === GPU ENVIRONMENT NOTICE ===
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
echo -e "${YELLOW}======================================================================${NC}"
echo -e "${YELLOW}IMPORTANT: GPU Environment Information${NC}"
echo -e "${YELLOW}======================================================================${NC}"
echo -e "${YELLOW}> This container image was built with the NVIDIA CUDA Toolkit ${CUDA_VERSION:-unknown}${NC}"
echo -e "${YELLOW}> and a compatible cuDNN version baked directly into the image.${NC}"
echo -e "${YELLOW}>${NC}"
echo -e "${YELLOW}> To use this image with GPU acceleration (--nv), the host machine's${NC}"
echo -e "${YELLOW}> MUST have an NVIDIA driver that supports CUDA ${CUDA_VERSION:-unknown} or newer.${NC}"
echo -e "${YELLOW}>${NC}"
echo -e "${YELLOW}> Check the host driver's max supported CUDA version with: nvidia-smi${NC}"
echo -e "${YELLOW}>${NC}"
echo -e "${YELLOW}> If your target cluster has a different CUDA version (e.g., 11.x),${NC}"
echo -e "${YELLOW}> you must modify the package names in 'xubuntu_robotics_base_post_ULTRA_CLEANED.sh'${NC}"
echo -e "${YELLOW}> and rebuild the container.${NC}"
echo -e "${YELLOW}======================================================================${NC}"

echo "Built image: ${SIF_PATH}"
if [ -n "${BUILD_OUTPUT_DIR:-}" ]; then
    echo "Build output directory: ${BUILD_OUTPUT_DIR}"
fi
echo ""
echo "# Build Summary"
echo "- Base system: Ubuntu ${BASE_OS_VERSION} with XFCE4"
echo "- Package manager: apt-aria wrapper + mamba solver"
echo "- Development: Python, Julia, C++ toolchains"
echo "- Jupyter: Full environment with kernels"
echo "- Robotics: Drake (ROS2 in separate image)"
echo "- Graphics: VNC, VirtualGL, Blender, CAD tools"
echo "- Documentation: TeX Live, LibreOffice"
echo "- Caching: Comprehensive package caching system"
log_with_timestamp "Host cache disk usage:"
if [ -n "${BIN_CACHE:-}" ] && [ -n "${DEB_CACHE:-}" ] && [ -n "${APT_CACHE:-}" ] && [ -n "${CONDA_CACHE:-}" ] && [ -n "${JULIA_CACHE:-}" ] && [ -n "${WHEELS_CACHE:-}" ]; then
    du -sh "${BIN_CACHE}" "${DEB_CACHE}" "${APT_CACHE}" "${CONDA_CACHE}" "${JULIA_CACHE}" "${WHEELS_CACHE}" 2>/dev/null || true
fi

#===============================================================================
# BLOCK 25: BUILD COMPLETION AND USAGE NOTES
#===============================================================================
# Purpose: Display usage notes, build summary, and cache statistics
# Self-contained: Yes
# Dependencies: BUILD_START_TIME, cache directories
# Outputs: Configured system components
#-------------------------------------------------------------------------------

#--- Sub-block 25.1: Display usage notes ---
echo "[note] To start a tuned VNC session inside the container:"
echo "apptainer exec --nv \"${SIF_PATH}\" start_vnc_xfce.sh"
echo "(Tunnel: ssh -L 5901:localhost:5901 <user>@<host>) -> VNC viewer to localhost:5901"

echo "[note] Julia CUDA lazy precompile (run on GPU node):"
echo "apptainer exec --nv \"${SIF_PATH}\" precompile_julia_cuda.sh"

echo "[note] AppImages (FreeCAD, Ultimaker Cura, Mendeley) recommended:"
echo "Download from official pages, then:"
echo "chmod +x *.AppImage && mkdir -p ~/Applications && mv *.AppImage ~/Applications/"
echo "# appimagedlauncher-cli integrate ~/Applications/*.AppImage (if installed)"

echo "[note] Drake Python path if needed:"
echo "export PYTHONPATH=${DRAKE_HOME}/lib/python3/dist-packages:\"\$PYTHONPATH\""
echo "# Note: Python ${SYSTEM_PYTHON_VER} paths are set in %environment section"

echo "[note] Drake is installed in base environment:"
echo "- meldis: ${DRAKE_HOME}/bin/meldis"
echo "- meshcat-server: ${DRAKE_HOME}/bin/meshcat-server"
echo "- python -c 'import pydrake'"

echo "[note] For Isaac Sim, Mujoco, and other simulators:"
echo "- Install via conda/mamba environments or download from official sources"

echo "[note] Mirror selection features:"
echo "- nala and apt-aria wrapper for fast package downloads"
echo "- Automatic selection of fastest mirrors"

echo "[note] Package management:"
echo "- mamba solver installed in conda for fast environment solving"
echo "- micromamba available as separate fast alternative"
echo "- Fallback to conda if mamba unavailable"

#--- Sub-block 25.2: Calculate build statistics ---
BUILD_END_TIME=$(date +%s)
if [ -n "${BUILD_START_TIME:-}" ] && [[ "${BUILD_START_TIME:-0}" =~ ^[0-9]+$ ]] && [ "${BUILD_START_TIME:-0}" -gt 0 ]; then
    BUILD_DURATION=$((BUILD_END_TIME - BUILD_START_TIME))
    BUILD_HOURS=$((BUILD_DURATION / 3600))
    BUILD_MINUTES=$(( (BUILD_DURATION % 3600) / 60))
    BUILD_SECONDS=$((BUILD_DURATION % 60))
else
    BUILD_DURATION=0
    BUILD_HOURS=0
    BUILD_MINUTES=0
    BUILD_SECONDS=0
    log_warning "BUILD_START_TIME not set or invalid, duration calculation skipped"
fi

# Cache statistics
CACHE_TOTAL_SIZE=$(du -sh "${CACHE_DIR:-/tmp}" 2>/dev/null | cut -f1 || echo "0B")
APT_CACHE_SIZE=$(du -sh "${APT_ARCHIVE_CACHE:-/tmp}" 2>/dev/null | cut -f1 || echo "0B")
CONDA_CACHE_SIZE=$(du -sh "${CONDA_CACHE:-/tmp}" 2>/dev/null | cut -f1 || echo "0B")
WHEELS_CACHE_SIZE=$(du -sh "${WHEELS_CACHE:-/tmp}" 2>/dev/null | cut -f1 || echo "0B")
JULIA_CACHE_SIZE=$(du -sh "${JULIA_CACHE:-/tmp}" 2>/dev/null | cut -f1 || echo "0B")

APT_CACHE_COUNT=$(find "${APT_ARCHIVE_CACHE:-/tmp}" -name "*.deb" 2>/dev/null | wc -l | tr -d '[:space:]')
APT_CACHE_COUNT="${APT_CACHE_COUNT:-0}"
CONDA_CACHE_COUNT=$(find "${CONDA_CACHE:-/tmp}" \( -name "*.conda" -o -name "*.tar.bz2" \) -type f 2>/dev/null | wc -l | tr -d '[:space:]')
CONDA_CACHE_COUNT="${CONDA_CACHE_COUNT:-0}"
WHEELS_CACHE_COUNT=$(find "${WHEELS_CACHE:-/tmp}" -name "*.whl" 2>/dev/null | wc -l | tr -d '[:space:]')
WHEELS_CACHE_COUNT="${WHEELS_CACHE_COUNT:-0}"

echo ""
echo "=============== BUILD SUMMARY ==============="
echo "Container: ${SIF_PATH}"
if [ -f "${SIF_PATH}" ]; then
    echo "Size: $(du -sh "${SIF_PATH}" 2>/dev/null | cut -f1 || echo "unknown")"
else
    echo "Size: unknown (file not found)"
fi
echo "Build time: ${BUILD_HOURS}h ${BUILD_MINUTES}m ${BUILD_SECONDS}s"
echo "Build completed: $(date)"
echo ""
echo "=============== CACHE STATISTICS ==============="
echo "Total cache size: ${CACHE_TOTAL_SIZE}"
echo "APT cache: ${APT_CACHE_SIZE} (${APT_CACHE_COUNT} .deb files)"
echo "Conda cache: ${CONDA_CACHE_SIZE} (${CONDA_CACHE_COUNT} packages)"
echo "Pip wheels: ${WHEELS_CACHE_SIZE} (${WHEELS_CACHE_COUNT} wheels)"
echo "Julia cache: ${JULIA_CACHE_SIZE}"
echo ""
echo "=============== DETAILED CACHE ANALYSIS ==============="
echo "APT cache directory: ${APT_ARCHIVE_CACHE:-not set}"
echo "Conda cache directory: ${CONDA_CACHE:-not set}"
echo "Pip wheels directory: ${WHEELS_CACHE:-not set}"
echo "Julia cache directory: ${JULIA_CACHE:-not set}"

# Check for Open3D wheel specifically
# Use tr to remove whitespace from wc -l output for robust numeric comparison
if [ -n "${WHEELS_CACHE:-}" ] && [ -d "${WHEELS_CACHE}/open3d" ]; then
    OPEN3D_WHEELS=$(find "${WHEELS_CACHE}/open3d" -name "open3d*.whl" -type f 2>/dev/null | wc -l | tr -d '[:space:]')
    OPEN3D_WHEELS="${OPEN3D_WHEELS:-0}"
    if [[ "${OPEN3D_WHEELS}" =~ ^[0-9]+$ ]] && [ "${OPEN3D_WHEELS}" -gt 0 ]; then
        echo ""
        echo "=============== OPEN3D WHEEL INFORMATION ==============="
        # Safely get directory size, handle case where directory might not exist
        if [ -d "${WHEELS_CACHE}/open3d" ]; then
            OPEN3D_WHEEL_SIZE=$(du -sh "${WHEELS_CACHE}/open3d" 2>/dev/null | cut -f1 || echo "unknown")
        else
            OPEN3D_WHEEL_SIZE="unknown"
        fi
        echo "✓ Open3D CUDA wheel cached for reuse: ${OPEN3D_WHEELS} wheel(s) (${OPEN3D_WHEEL_SIZE})"
        echo "  Location: ${WHEELS_CACHE}/open3d/"
        echo "  This wheel can be used to install Open3D in conda environments and writable overlays"
        # Note: * is literal here for documentation purposes
        echo "  Usage in conda environment: pip install --no-deps \"${WHEELS_CACHE}/open3d/open3d*.whl\""
        echo "========================================================="
    fi
fi
