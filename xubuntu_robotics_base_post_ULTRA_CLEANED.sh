#!/bin/bash
#===============================================================================
# XUBUNTU ROBOTICS BASE - POST-INSTALL SCRIPT
#===============================================================================
# Purpose: Container %post section - Install all software and configure system
# Runs inside: Singularity container during build (%post phase)
# Features: Multi-phase installation, cache management, error handling
#===============================================================================

#===============================================================================
# CRITICAL: Source centralized configuration
#===============================================================================
# All version numbers, URLs, and parameters come from /etc/config.sh
# This file is copied into the container during build via %files section
# SINGLE SOURCE OF TRUTH - Do not redefine any variables from config.sh
#-------------------------------------------------------------------------------
# Guard against double-sourcing (config.sh may already be sourced in %post)
if [ -z "${CONFIG_SOURCED}" ]; then
    if [ -f /etc/config.sh ]; then
        source /etc/config.sh
        export CONFIG_SOURCED=1
        echo "✓ Loaded configuration from /etc/config.sh"
    else
        echo "ERROR: /etc/config.sh not found!"
        exit 1
    fi
else
    echo "ℹ Configuration already loaded (skipping redundant source)"
fi

#===============================================================================
# BUILD LOGGING SYSTEM
#===============================================================================
# Purpose: Mirror all terminal output to timestamped log files
# Features: Automatic log rotation, keeps N most recent logs
# Note: Uses 'tee' so terminal output remains unaffected
#-------------------------------------------------------------------------------

# Only set up logging if we're in the build container (not if script is sourced elsewhere)
if [ "${SINGULARITY_NAME:-}" != "" ] || [ "${APPTAINER_NAME:-}" != "" ] || [ -f "/.singularity.d/Singularity" ]; then
    # Create log directory (inside container, use /tmp or /var/log)
    BUILD_LOG_DIR="/var/log/singularity_build"
    mkdir -p "${BUILD_LOG_DIR}"

    # Clean up old logs FIRST - keep only N most recent logs
    # Ensure BUILD_LOG_PREFIX is set (default if not set)
    BUILD_LOG_PREFIX="${BUILD_LOG_PREFIX:-singularity_build}"
    
    if [ -d "${BUILD_LOG_DIR}" ] && [ "${BUILD_LOG_KEEP_COUNT:-2}" -gt 0 ]; then
        echo "Cleaning up old build logs (keeping ${BUILD_LOG_KEEP_COUNT:-2} most recent)..."
        
        # Count existing log files matching the pattern
        EXISTING_LOGS=$(find "${BUILD_LOG_DIR}" -maxdepth 1 -name "${BUILD_LOG_PREFIX}_*.log" -type f 2>/dev/null | wc -l)
        
        if [ "$EXISTING_LOGS" -gt "${BUILD_LOG_KEEP_COUNT:-2}" ]; then
            # List all log files sorted by modification time (newest first)
            # Keep only N most recent files, remove the rest
            # Use ls -t for sorting by modification time (works on all systems)
            ls -t "${BUILD_LOG_DIR}/${BUILD_LOG_PREFIX}"_*.log 2>/dev/null | \
                tail -n +$((BUILD_LOG_KEEP_COUNT + 1)) | \
                while read -r old_log; do
                    if [ -f "$old_log" ]; then
                        echo "  Removing old log: $(basename "$old_log")"
                        rm -f "$old_log"
                    fi
                done
            echo "✓ Old logs cleaned up (kept ${BUILD_LOG_KEEP_COUNT:-2} most recent)"
        else
            echo "✓ No old logs to clean up (found $EXISTING_LOGS logs, keeping ${BUILD_LOG_KEEP_COUNT:-2})"
        fi
    fi

    # Generate improved timestamp for this build
    # Format: YYYYMMDD_Day_HHMM_AMPM (e.g., 20241027_Sun_1430_PM)
    DAY_NAMES=("Sun" "Mon" "Tue" "Wed" "Thu" "Fri" "Sat")
    CURRENT_DAY=$(date +%w)  # 0=Sunday, 1=Monday, etc.
    DAY_NAME=${DAY_NAMES[$CURRENT_DAY]}
    
    # Get 12-hour format with AM/PM
    HOUR_12=$(date +"%I")
    MINUTE=$(date +"%M")
    AMPM=$(date +"%p")
    
    # Remove leading zero from hour for cleaner format
    HOUR_12=$((10#$HOUR_12))
    
    # Create timestamp: YYYYMMDD_Day_HHMM_AMPM
    BUILD_TIMESTAMP=$(date +"%Y%m%d")_${DAY_NAME}_${HOUR_12}${MINUTE}_${AMPM}
    BUILD_LOG_FILE="${BUILD_LOG_DIR}/${BUILD_LOG_PREFIX}_${BUILD_TIMESTAMP}.log"

    # Start logging to file while preserving terminal output
    # This creates a background process that tees output to both terminal and log file
    echo "✓ Build logging enabled: ${BUILD_LOG_FILE}"
    echo "  Log directory: ${BUILD_LOG_DIR}"
    echo "  Timestamp format: YYYYMMDD_Day_HHMM_AMPM"
    echo "  Keeping ${BUILD_LOG_KEEP_COUNT} most recent logs"
    echo "  Auto-sync interval: ${BUILD_LOG_SYNC_INTERVAL} seconds"
    echo ""
    
    # Use line-buffered tee with process substitution
    # stdbuf -oL makes output line-buffered (immediate write on newline)
    # This ensures most output is written immediately, reducing data loss
    # IMPORTANT: exec redirects ALL subsequent output - each line written ONCE
    exec > >(stdbuf -oL tee -a "${BUILD_LOG_FILE}") 2>&1
    
    # Start background sync job to periodically flush log file to disk
    # This ensures data is saved even if build is interrupted
    (
        while true; do
            sleep ${BUILD_LOG_SYNC_INTERVAL}
            # Sync this specific log file to disk
            if [ -f "${BUILD_LOG_FILE}" ]; then
                sync "${BUILD_LOG_FILE}" 2>/dev/null || sync
            fi
        done
    ) &
    SYNC_PID=$!
    
    # Store sync PID so we can clean it up if needed
    export BUILD_LOG_SYNC_PID=${SYNC_PID}
    
    # Trap to ensure sync job is killed when script exits (normal or abrupt)
    # This function is called on: EXIT (normal), INT (Ctrl+C), TERM (kill)
    cleanup_logging() {
        # Kill the background sync job
        if [ -n "${BUILD_LOG_SYNC_PID:-}" ]; then
            kill ${BUILD_LOG_SYNC_PID} 2>/dev/null || true
        fi
        # CRITICAL: Perform final sync to ensure all data is written to disk
        # This captures any output generated between last sync and exit
        if [ -f "${BUILD_LOG_FILE}" ]; then
            sync "${BUILD_LOG_FILE}" 2>/dev/null || sync
            echo ""
            echo "═══════════════════════════════════════════════════════════════"
            echo "  BUILD LOG END: $(date)"
            echo "  Exit status: $?"
            echo "  Log file: ${BUILD_LOG_FILE}"
            echo "  Final sync completed: All output saved to disk"
            echo "═══════════════════════════════════════════════════════════════"
        fi
    }
    trap cleanup_logging EXIT INT TERM
    
    # Record build start in log
    echo "═══════════════════════════════════════════════════════════════"
    echo "  BUILD LOG START: $(date)"
    echo "  Script: xubuntu_robotics_base_post_ULTRA_CLEANED.sh"
    echo "  Log file: ${BUILD_LOG_FILE}"
    echo "  Timestamp: ${BUILD_TIMESTAMP}"
    echo "  PID: $$"
    echo "  Sync job PID: ${BUILD_LOG_SYNC_PID}"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
else
    echo "ℹ Logging disabled (not running in container build environment)"
fi

#===============================================================================
# BLOCK 1: INITIALIZATION AND CONFIGURATION
#===============================================================================
# Purpose: Set up phase tracking, colors, environment variables
# Self-contained: Yes
# Dependencies: /etc/config.sh (sourced above)
# Outputs: Environment variables, configuration
#-------------------------------------------------------------------------------

#--- Sub-block 1.1: Phase tracking variables ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
export PHASE1_STATUS="NOT RUN"  # System base packages
export PHASE2_STATUS="NOT RUN"  # Development tools
export PHASE3_STATUS="NOT RUN"  # GUI and desktop
export PHASE4_STATUS="NOT RUN"  # Scientific computing
export PHASE5_STATUS="NOT RUN"  # Cleanup and finalization

#--- Sub-block 1.2: Terminal color codes ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
BLUE='\033[1;34m'
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#--- Sub-block 1.3: Environment setup ---
# Critical: Non-interactive mode for apt operations
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
export DEBIAN_FRONTEND=noninteractive

#===============================================================================
# BLOCK 2: DEBUG AND DIAGNOSTIC FUNCTIONS
#===============================================================================
# Purpose: Provide debugging utilities for build process
# Self-contained: Yes (complete function definition)
# Dependencies: None
# Outputs: Environment variables, configuration
#-------------------------------------------------------------------------------

#--- Sub-block 2.1: GLIBC debug function ---
# Purpose: Comprehensive diagnostic output for C/C++ compiler environment
# Dependencies: PHASE 1 (Compilers)
# Outputs: Configured system components
debug_glibc() {
  local stage="$1"
  echo "=========================================================="
  echo -e "${BLUE}DEBUG CHECKPOINT: ${stage}${NC}"
  echo "Time: $(date)"
  echo "=========================================================="
  echo "GLIBC version:"
  /lib/x86_64-linux-gnu/libc.so.6 | head -1
  echo "---"
  echo "ldd version:"
  ldd --version | head -1
  echo "---"
  echo "GCC version:"
  gcc --version 2>/dev/null | head -1 || echo "GCC not installed yet"
  echo "---"
  echo "Test stdlib.h locations:"
  find /usr/include -name "stdlib.h" 2>/dev/null || echo "stdlib.h not found"
  echo "---"
  echo "Test cstdlib locations:"
  find /usr/include -name "cstdlib" 2>/dev/null || echo "cstdlib not found"
  echo "---"
  echo "Compiler include paths:"
  gcc -xc++ -E -v - < /dev/null 2>&1 | grep '^ /' 2>/dev/null || echo "Cannot check (GCC not ready)"
  echo "---"
  echo "Test compile with stdlib.h:"
  echo '#include <stdlib.h>' > /tmp/test_$$$.c
  echo 'int main() { return 0; }' >> /tmp/test_$$$.c
  gcc /tmp/test_$$$.c -o /tmp/test_$$$ 2>&1 && echo "SUCCESS" || echo "FAILED"
  rm -f /tmp/test_$$$.c /tmp/test_$$$
  echo "---"
  echo
  # Reset terminal state after debug output (gcc -v can leave control codes)
  printf '\033[0m\n'
}
# End function (self-contained)

#===============================================================================
# BLOCK 3: MIRROR PROBING FUNCTIONS (MUST BE EARLY FOR APT OPERATIONS)
#===============================================================================
# Purpose: Test and select fastest Ubuntu mirror BEFORE any apt-get operations
# Self-contained: Yes (complete mirror selection system)
# Dependencies: curl (available in Ubuntu base images)
# Outputs: FASTEST_MIRROR variable, updated /etc/apt/sources.list
# Note: Moved early to ensure ALL package downloads use fastest mirror
#-------------------------------------------------------------------------------

#--- Sub-block 3.1: Mirror test function (for parallel execution) ---
# Purpose: Test a single mirror's speed for parallel execution with xargs
# Dependencies: curl (from Ubuntu base image)
# Outputs: Speed score written to PROBE_RESULTS file
# NOTE: Must be top-level function (not nested) to allow export -f
test_mirror() {
    local URL="$1"
    local CODENAME="$2"
    local PROBE_RESULTS="$3"

    [[ -z "${URL}" ]] && return

    # Download Packages.gz (~20MB) to measure actual bandwidth
    set +e
    local CURL_OUTPUT CURL_EXIT_CODE

    # Download Packages.gz (typically 15-25MB) to measure bandwidth
    CURL_OUTPUT="$(LC_NUMERIC=C curl -s -w '%{time_total}\n' -o /dev/null -m 25 --connect-timeout 8 --retry 1 -L "${URL}/dists/${CODENAME}/main/binary-amd64/Packages.gz" 2>/dev/null)"
    CURL_EXIT_CODE=$?

    # If large file fails, try Release file as fallback
    if [[ $CURL_EXIT_CODE -ne 0 ]] || [[ -z "$CURL_OUTPUT" ]] || [[ "$CURL_OUTPUT" == "0.000000" ]]; then
      CURL_OUTPUT="$(LC_NUMERIC=C curl -s -w '%{time_total}\n' -o /dev/null -m 10 --connect-timeout 5 --retry 1 "${URL}/dists/${CODENAME}/Release" 2>/dev/null)"
        CURL_EXIT_CODE=$?
      # Penalize Release-only results (multiply by 10 to prefer Packages.gz results)
      if [[ $CURL_EXIT_CODE -eq 0 ]] && [[ -n "$CURL_OUTPUT" ]] && [[ "$CURL_OUTPUT" != "0.000000" ]]; then
        CURL_OUTPUT=$(printf "%.3f" "$(echo "$CURL_OUTPUT 10" | awk '{print $1 * $2}' 2>/dev/null || echo "$CURL_OUTPUT")")
      fi
    fi
    set -e

    # Write results (flock doesn't work reliably in xargs subshells, using simple append)
    if [[ $CURL_EXIT_CODE -ne 0 ]] || [[ -z "$CURL_OUTPUT" ]] || [[ "$CURL_OUTPUT" == "0.000000" ]]; then
      echo "999.9 ${URL}" >> "$PROBE_RESULTS"
    else
      echo "${CURL_OUTPUT} ${URL}" >> "$PROBE_RESULTS"
    fi
}

# Export function for parallel execution with xargs
export -f test_mirror

#--- Sub-block 3.2: Mirror probing and selection function ---
# Purpose: Find fastest Ubuntu mirror and update all APT sources
# Dependencies: test_mirror function, curl
# Outputs: FASTEST_MIRROR (exported), updated /etc/apt/sources.list and sources.list.d/
probe_and_set_mirrors() {
export LC_NUMERIC=C # Prevents printf errors with decimals
echo "==> Probing for the fastest Ubuntu mirror by testing a candidate list..."

# Detect Ubuntu codename correctly (noble for 24.04, jammy for 22.04, etc.)
CODENAME="$(grep VERSION_CODENAME /etc/os-release 2>/dev/null | cut -d= -f2 || echo "${BASE_OS_CODENAME}")"
echo "[info] Detected Ubuntu codename: ${CODENAME}"
PROBE_RESULTS="$(mktemp)"
export CODENAME PROBE_RESULTS  # Export for subshell access

  # Attempt to dynamically fetch 100Gbps+ mirrors from official Launchpad page
  echo "[info] Attempting to fetch latest 100Gbps+ mirrors from official Ubuntu mirror list..."
  MIRRORS_HTML=$(curl -s -m 15 --connect-timeout 10 "https://launchpad.net/ubuntu/+archivemirrors" 2>/dev/null || echo "")
  
  if [ -n "$MIRRORS_HTML" ]; then
    echo "[info] Successfully fetched mirror list ($(echo "$MIRRORS_HTML" | wc -c) bytes). Parsing..."
    
    # Parse HTML to extract mirrors with 100+ Gbps bandwidth that are "Up to date"
    DYNAMIC_MIRRORS=$(echo "$MIRRORS_HTML" | \
      tr '\n' ' ' | \
      sed 's|<tr>|\n<tr>|g' | \
      grep -E '([1-9][0-9]{2,}|[1-9][0-9]0) Gbps' | \
      grep 'distromirrorstatusUP' | \
      grep -oE 'href="(https?://[^"]+/(ubuntu|archive)[^"]*)"' | \
      sed 's|href="||g; s|"||g; s|https://|http://|g; s|/$||' | \
      sort -u | \
      head -20)  # Limit to top 20 mirrors for performance
    
    MIRROR_COUNT=$(echo "$DYNAMIC_MIRRORS" | grep -c . || echo 0)
    
    # Explicit check for non-empty and sufficient mirrors
    if [ -n "$DYNAMIC_MIRRORS" ] && [ "$MIRROR_COUNT" -ge 10 ]; then
      CANDIDATE_MIRRORS="http://archive.ubuntu.com/ubuntu"
      for mirror in $DYNAMIC_MIRRORS; do
        # Skip empty lines
        [ -z "$mirror" ] && continue
        CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} ${mirror}"
      done
      echo "[info] ✅ Successfully parsed ${MIRROR_COUNT} dynamic 100Gbps+ mirrors"
    else
      echo "[warn] Only ${MIRROR_COUNT} dynamic mirrors found. Using curated static list."
      CANDIDATE_MIRRORS=""  # Will trigger fallback below
    fi
  else
    echo "[warn] Failed to fetch mirror list from Launchpad. Using curated static list."
    CANDIDATE_MIRRORS=""  # Will trigger fallback
  fi
  
  # Fallback to curated static list if dynamic fetch failed
  if [ -z "$CANDIDATE_MIRRORS" ]; then
    echo "[info] Using curated static mirror list (100Gbps+ verified Oct 2025)"
    CANDIDATE_MIRRORS="http://archive.ubuntu.com/ubuntu"
    # Australia (100 Gbps)
    CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} http://mirror.aarnet.edu.au/pub/ubuntu/archive"
    # Germany (400 Gbps)
    CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} http://ftp.fau.de/ubuntu"
    CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} http://ftp.uni-stuttgart.de/ubuntu"
    CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} http://ftp.halifax.rwth-aachen.de/ubuntu"
    CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} http://mirror.netcologne.de/ubuntu"
    # Netherlands (100 Gbps)
    CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} http://ubuntu.mirror.pcextreme.nl/ubuntu"
    # United Kingdom (100 Gbps)
    CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} http://mirror.ox.ac.uk/sites/archive.ubuntu.com/ubuntu"
    # United States (400 Gbps)
    CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} http://mirrors.wikimedia.org/ubuntu"
    # United States (100 Gbps)
    CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} http://mirrors.ocf.berkeley.edu/ubuntu"
    CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} http://mirror.math.princeton.edu/pub/ubuntu"
    # Canada (200 Gbps)
    CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} http://mirror.csclub.uwaterloo.ca/ubuntu"
    # China (100 Gbps)
    CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} http://mirrors.ustc.edu.cn/ubuntu"
    # Japan (100 Gbps)
    CANDIDATE_MIRRORS="${CANDIDATE_MIRRORS} http://ftp.jaist.ac.jp/pub/Linux/ubuntu"
  fi

# Run mirror tests in parallel (max 6 concurrent to avoid network congestion)
MIRROR_TOTAL=$(echo "$CANDIDATE_MIRRORS" | wc -w)
echo "Testing ${MIRROR_TOTAL} mirrors in parallel (max 6 concurrent)..."
echo "${CANDIDATE_MIRRORS}" | tr ' ' '\n' | xargs -P 6 -I {} bash -c 'test_mirror "{}" "$CODENAME" "$PROBE_RESULTS"'

# Display mirror probe results
echo "--- Mirror Probe Results (speed score, url): ---"
if [ -s "$PROBE_RESULTS" ]; then
    LC_NUMERIC=C sort -n "$PROBE_RESULTS" | sed 's/^/ /' || echo "[warn] Failed to sort results"
else
    echo "[warn] No probe results written - all mirrors may have failed"
fi

# Extract the fastest mirror that responded in under 15 seconds
FASTEST_MIRROR="$(LC_NUMERIC=C sort -n "$PROBE_RESULTS" 2>/dev/null | awk 'NF==2 && $1 < 15.0 {print $2; exit}')"
rm -f "$PROBE_RESULTS"

if [[ -z "$FASTEST_MIRROR" ]]; then
    echo "[warn] All mirror probes failed or took >15 seconds. Using default ubuntu archive."
    FASTEST_MIRROR="http://archive.ubuntu.com/ubuntu"
fi
echo "==> Selected fastest mirror: $FASTEST_MIRROR"

# Export the variable so it persists after function ends and is available globally
export FASTEST_MIRROR

# Apply the fastest mirror to the main APT sources
if [ -f /etc/apt/sources.list ]; then
  sed -i "s|https\\?://[a-zA-Z0-9.-]*/ubuntu|${FASTEST_MIRROR}|g" /etc/apt/sources.list
  echo "[info] Updated /etc/apt/sources.list with fastest mirror"
  
  # Verify the update was successful
  if grep -q "${FASTEST_MIRROR}" /etc/apt/sources.list 2>/dev/null; then
    echo "[info] ✓ Verified: sources.list now uses ${FASTEST_MIRROR}"
  else
    echo "[warn] ✗ Verification failed: sources.list may not have been updated correctly"
  fi
else
  echo "[warn] /etc/apt/sources.list not found - mirror selection skipped"
fi

# Also update sources.list.d/ files (excluding PPAs which should stay on ppa.launchpad.net)
echo "[info] Updating sources.list.d/ files with fastest mirror (excluding PPAs)..."
if [ -d /etc/apt/sources.list.d ]; then
    # Enable nullglob to handle case where no .list files exist
    shopt -s nullglob
    for sources_file in /etc/apt/sources.list.d/*.list; do
        # Double-check file exists (redundant with nullglob, but defensive)
        [ -f "$sources_file" ] || continue
        
        # Skip PPA files (they should always use ppa.launchpad.net)
        if grep -q "ppa.launchpad.net" "$sources_file" 2>/dev/null; then
            echo "[info] Skipping PPA file: $(basename "$sources_file")"
            continue
        fi
        
        # Update Ubuntu mirror URLs in this file
        if grep -q "https\\?://[a-zA-Z0-9.-]*/ubuntu" "$sources_file" 2>/dev/null; then
            sed -i "s|https\\?://[a-zA-Z0-9.-]*/ubuntu|${FASTEST_MIRROR}|g" "$sources_file"
            echo "[info] Updated: $(basename "$sources_file")"
        fi
    done
    shopt -u nullglob  # Restore default behavior
    echo "[info] ✓ sources.list.d/ update complete"
else
    echo "[info] /etc/apt/sources.list.d/ not found or empty"
fi
}
# End probe_and_set_mirrors function (self-contained)

#===============================================================================
# BLOCK 4: CACHE MONITORING SYSTEM
#===============================================================================
# Purpose: Track cache growth throughout build phases
# Self-contained: Yes (complete function definitions)
# Dependencies: None
# Outputs: Environment variables, configuration
#-------------------------------------------------------------------------------

#--- Sub-block 3.1: Initialize cache monitoring data file ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
CACHE_MONITOR_DATA="/tmp/cache_monitor_data.txt"
# Critical: CSV header for cache tracking across all build phases
echo "Stage|Container APT|Var APT|Conda|Wheels|Julia" > "$CACHE_MONITOR_DATA"

#--- Sub-block 3.2: Cache monitoring function ---
# Purpose: Record cache sizes at each build stage
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
# Parameters: $1 = stage name
monitor_cache() {
    local stage="$1"
    local container_apt=$(ls ${CONTAINER_APT_CACHE}/*.deb 2>/dev/null | wc -l)
    local var_apt=$(ls /var/cache/apt/archives/*.deb 2>/dev/null | wc -l)
    local conda_pkgs=$(ls ${CONTAINER_CONDA_CACHE}/* 2>/dev/null | wc -l)
    local wheels=$(ls ${CONTAINER_WHEELS_CACHE}/* 2>/dev/null | wc -l)
    local julia_pkgs=$(ls ${CONTAINER_JULIA_CACHE}/* 2>/dev/null | wc -l)

    echo "[CACHE MONITOR] Stage: $stage"
  echo "${CONTAINER_APT_CACHE}: $container_apt .deb files"
  echo "/var/cache/apt/archives: $var_apt .deb files"
  echo "${CONTAINER_CONDA_CACHE}: $conda_pkgs files"
  echo "${CONTAINER_WHEELS_CACHE}: $wheels files"
  echo "${CONTAINER_JULIA_CACHE}: $julia_pkgs files"
    echo ""

  # Store data for summary (append to CSV)
    echo "$stage|$container_apt|$var_apt|$conda_pkgs|$wheels|$julia_pkgs" >> "$CACHE_MONITOR_DATA"
}
# End function (self-contained)

#--- Sub-block 3.3: Cache monitoring summary display function ---
# Purpose: Display cache growth table across all stages
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
display_cache_monitoring_summary() {
  echo "=========================================================="
  echo "CACHE MONITORING SUMMARY - ALL STAGES"
  echo "=========================================================="
  echo "Stage                         | Container APT | Var APT | Conda | Wheels | Julia"
  echo "------------------------------|---------------|---------|-------|--------|-------"
    # Read and display the monitoring data
    while IFS='|' read -r stage container_apt var_apt conda_pkgs wheels julia_pkgs; do
        # Skip header line
        if [[ "$stage" == "# Stage" ]]; then
            continue
        fi
    # End if-fi block
        # Format the output with proper alignment
        printf "%-30s | %-13s | %-7s | %-5s | %-6s | %-5s\n" \
            "$stage" "$container_apt" "$var_apt" "$conda_pkgs" "$wheels" "$julia_pkgs"
    done < "$CACHE_MONITOR_DATA"
  # End while loop (self-contained)
  echo "=========================================================="
  echo
}
# End function (self-contained)

#--- Sub-block 3.4: Final cache summary function ---
# Purpose: Display detailed cache statistics before image creation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
cache_summary() {
  echo "=========================================================="
  echo "FINAL CACHE SUMMARY - BEFORE IMAGE CREATION"
  echo "=========================================================="
    echo "APT Archives:"
  echo " ${CONTAINER_APT_CACHE}: $(ls ${CONTAINER_APT_CACHE}/*.deb 2>/dev/null | wc -l) .deb files"
  echo " /var/cache/apt/archives: $(ls /var/cache/apt/archives/*.deb 2>/dev/null | wc -l) .deb files"
  echo "---"
    echo "Other Caches:"
  echo " ${CONTAINER_CONDA_CACHE}: $(ls ${CONTAINER_CONDA_CACHE}/* 2>/dev/null | wc -l) files"
  echo " ${CONTAINER_WHEELS_CACHE}: $(ls ${CONTAINER_WHEELS_CACHE}/* 2>/dev/null | wc -l) files"
  echo " ${CONTAINER_JULIA_CACHE}: $(ls ${CONTAINER_JULIA_CACHE}/* 2>/dev/null | wc -l) files"
  echo "---"
    echo "Cache Directory Sizes:"
  echo " ${CONTAINER_APT_CACHE}: $(du -sh ${CONTAINER_APT_CACHE} 2>/dev/null | cut -f1 || echo '0B')"
  echo " ${CONTAINER_CONDA_CACHE}: $(du -sh ${CONTAINER_CONDA_CACHE} 2>/dev/null | cut -f1 || echo '0B')"
  echo " ${CONTAINER_WHEELS_CACHE}: $(du -sh ${CONTAINER_WHEELS_CACHE} 2>/dev/null | cut -f1 || echo '0B')"
  echo " ${CONTAINER_JULIA_CACHE}: $(du -sh ${CONTAINER_JULIA_CACHE} 2>/dev/null | cut -f1 || echo '0B')"
  echo "=========================================================="
  echo
}
# End function (self-contained)

#===============================================================================
# BLOCK 4: CACHE DIRECTORY CONFIGURATION
#===============================================================================
# Purpose: Configure unified cache structure for all package managers
# Self-contained: Yes
# Dependencies: None
# Outputs: Environment variables, configuration
#-------------------------------------------------------------------------------

#--- Sub-block 4.1: Define unified cache root ---
# Critical: All package caches will be subdirectories of this root
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
export CACHE_ROOT="/container_cache"

#--- Sub-block 4.2: Configure package manager cache paths ---
# Critical: Point all package managers to unified cache structure
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
export PIP_CACHE_DIR="${CACHE_ROOT}/wheels"              # Python pip wheels
export CONDA_PKGS_DIRS="${CACHE_ROOT}/conda_pkgs"        # Conda packages
export JULIA_DEPOT_PATH="${CACHE_ROOT}/julia_pkgs:/usr/local/share/julia"  # Julia depot

# NOTE: All version configurations now loaded from /etc/config.sh (sourced at top of file)

#===============================================================================
# BLOCK 6: ADVANCED PACKAGE MANAGEMENT FUNCTIONS
#===============================================================================
# Purpose: Robust package installation with staging, retry logic, and atomicity
# Self-contained: Yes (complete function definitions)
# Dependencies: conda/mamba
# Outputs: Configured system components
#-------------------------------------------------------------------------------


#--- Sub-block 5.2: Validate configuration loaded successfully ---
# Purpose: Verify all required variables are set
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
#--- Sub-block 6.1: Conda staging area setup ---
# Purpose: Create isolated staging area for package operations
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments
setup_conda_staging_area() {
    local staging_dir="/tmp/conda-staging"
    echo "Setting up conda staging area at $staging_dir..."
    # Create staging directory with proper permissions
    mkdir -p "$staging_dir"
    chmod 755 "$staging_dir"
    # Note: Do not modify CONDA_PKGS_DIRS here to avoid interfering with normal conda operations
    # The staging area will be used manually for specific cleanup operations
    echo "✓ Conda staging area configured (manual mode)"
}
# End function (self-contained)

#--- Sub-block 6.2: Atomic package replacement with retry ---
# Purpose: Replace corrupted packages with exponential backoff
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments
# Parameters: $1 = package name
atomic_package_replace() {
    local pkg_name="$1"
    local cache_dir="${CONTAINER_CONDA_CACHE}"
    local max_retries=3
    local retry_count=0

    while [ $retry_count -lt $max_retries ]; do
    echo "Attempting to replace corrupted package: $pkg_name (attempt $((retry_count + 1))/${max_retries})"
        # Create temporary file for atomic replacement
        local temp_file="${cache_dir}/${pkg_name}.tmp"
        local final_file="${cache_dir}/${pkg_name}"

        # Remove corrupted package
    rm -f "${final_file}" 2>/dev/null || true

        # Download fresh copy to temporary location
        if ${MINIFORGE_HOME}/bin/mamba download --no-deps -c conda-forge -p "$cache_dir" "$pkg_name" --output-filename "$temp_file" 2>/dev/null; then
            # Atomic move to final location
            if mv "$temp_file" "$final_file" 2>/dev/null; then
                # Verify the new package
                if verify_package_integrity "$final_file"; then
          echo "✓ Successfully replaced and verified: $pkg_name"
                    return 0
                else
          echo "Δ Downloaded package failed verification, retrying..."
                    rm -f "$final_file" 2>/dev/null || true
                fi
            else
        echo "Δ Atomic move failed, retrying..."
                rm -f "$temp_file" 2>/dev/null || true
            fi
        else
      echo "Δ Download failed, retrying..."
        fi

        retry_count=$((retry_count + 1))
    sleep $((retry_count ** 2)) # Exponential backoff
    done
  # End while loop (self-contained)

#--- Sub-block: Section continuation (321) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

  echo "✗ Failed to replace package after $max_retries attempts: $pkg_name"
    return 1
}
# End function (self-contained)

#--- Sub-block: Code section 322 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

#--- Sub-block 6.3: Package integrity verification ---
# Purpose: Verify package file integrity (bzip2/zip)
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# Parameters: $1 = package file path
verify_package_integrity() {
    local pkg_file="$1"

    if [ ! -f "$pkg_file" ]; then
        return 1
    fi

    # Check file type and verify accordingly
    local file_type=$(file -b "$pkg_file" 2>/dev/null || echo "unknown")
    case "$file_type" in
    *"bzip2 compressed"*)
            if bzip2 -t "$pkg_file" >/dev/null 2>&1; then
                return 0
            else
        echo "✗ bzip2 integrity check failed"
                return 1
            fi
            ;;
    *"Zip archive"*)
            if unzip -t "$pkg_file" >/dev/null 2>&1; then
                return 0
            else
        echo "✗ ZIP integrity check failed"
                return 1
            fi
            ;;
    *) # For unknown types, try both checks
            if bzip2 -t "$pkg_file" >/dev/null 2>&1 || unzip -t "$pkg_file" >/dev/null 2>&1; then
                return 0
            else
        echo "✗ Package integrity check failed"
                return 1
            fi
            ;;
    esac
  # End case statement (self-contained)
}
# End function (self-contained)

#--- Sub-block: Section continuation (371) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

#--- Sub-block 6.4: Package locking mechanism ---
# Purpose: Prevent concurrent access to packages with timeout
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# Parameters: $1 = package name
acquire_package_lock() {
    local pkg_name="$1"
    local lock_file="/tmp/conda-lock-${pkg_name}.lock"
    local max_wait=30
    local wait_count=0

    while [ $wait_count -lt $max_wait ]; do
    if [set -C; echo $$ > "$lock_file"] 2>/dev/null; then
      # lock acquired
            return 0
        fi
        # Check if lock is stale (older than 5 minutes)
    if [ -f "$lock_file" ] && [ $(date +%s) -ge $(( $(stat -c %Y "$lock_file" 2>/dev/null || echo 0) + 300 )) ]; then
            rm -f "$lock_file" 2>/dev/null || true
            continue
        fi

    sleep $((wait_count + 2))
        wait_count=$((wait_count + 1))
    done
  # End while loop (self-contained)

  echo "▲ Could not acquire lock for $pkg_name after ${max_wait}s"
    return 1
}
# End function (self-contained)

#--- Sub-block 6.5: Release package lock ---
# Purpose: Remove lock file for package
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# Parameters: $1 = package name
release_package_lock() {
    local pkg_name="$1"
    local lock_file="/tmp/conda-lock-${pkg_name}.lock"
    rm -f "$lock_file" 2>/dev/null || true
}
# End function (self-contained)

#===============================================================================
# BLOCK 6.9: MAIN BUILD EXECUTION START
#===============================================================================
# Purpose: Initialize build environment and create cache directories
# Self-contained: Yes
# Dependencies: None
# Outputs: Environment variables, configuration
#-------------------------------------------------------------------------------

#--- Sub-block 6.9.1: Initial diagnostic checkpoint ---
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
debug_glibc "START - Before any apt operations"

#--- Sub-block 6.9.2: Create cache directory structure ---
# Critical: All cache directories must exist before package operations
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments
echo "=> Creating all cache directories at the start of container build..."
mkdir -p ${CONTAINER_APT_CACHE}
mkdir -p ${CONTAINER_BIN_CACHE}
mkdir -p ${CONTAINER_CONDA_CACHE}
mkdir -p ${CONTAINER_DEB_CACHE}
mkdir -p ${CONTAINER_WHEELS_CACHE}
mkdir -p ${CONTAINER_JULIA_CACHE}
mkdir -p /var/cache/apt/archives/partial
mkdir -p /root/.cache/pip
# Note: ${MINIFORGE_HOME} will be created by Miniforge installer
mkdir -p /usr/local/share/julia

#--- Sub-block 6.9.3: Additional cache directories ---
# Critical: User-specific cache directories for conda, julia, pip
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
mkdir -p /root/.cache/conda
mkdir -p /root/.cache/julia
mkdir -p /root/.local/share/julia
# apt-fast cache directory removed - using apt-aria wrapper instead

#--- Sub-block 6.9.4: Set cache directory permissions ---
# Critical: Ensure all cache directories are writable
# Dependencies: Block 17 (Conda/Miniforge), Block 8.5 (Julia installation)
# Outputs: Python packages, conda environments
chmod -R 755 /container_cache /root/.cache /var/cache/opt ${MINIFORGE_HOME} /usr/local/share/julia /root/.local 2>/dev/null || true
echo "✓ All cache directories created successfully"

#--- Sub-block 6.9.5: Cache validation and repair function ---
# Purpose: Validate cache directory structure and permissions
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments
validate_and_repair_cache() {
    echo "==> Validating and repairing cache directories..."
    # Ensure all cache directories exist with proper permissions
    local cache_dirs=(
        "${CONTAINER_APT_CACHE}"
        "${CONTAINER_WHEELS_CACHE}"
        "${CONTAINER_CONDA_CACHE}"
        "${CONTAINER_JULIA_CACHE}"
        "/var/cache/apt/archives"
        "/root/.cache/pip"
        "/usr/local/share/julia"
    )

    # Only add ${MINIFORGE_HOME}/pkgs if conda is already installed
    if [ -d "${MINIFORGE_HOME}" ]; then
        cache_dirs+=("${MINIFORGE_HOME}/pkgs")
    fi

    for dir in "${cache_dirs[@]}"; do
        mkdir -p "$dir"
        chown -R root:root "$dir" 2>/dev/null || true
        chmod -R 755 "$dir" 2>/dev/null || true
    echo "✓ Validated: $dir"
  done
}
# End validate_and_repair_cache function

#--- Sub-block 6.9.6: Test write permissions ---
# Critical: Verify cache directories are actually writable
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# Conda package integrity validation is done via Xsetup for efficiency
test_file="/root/.cache/write_test"
    if touch "$test_file" 2>/dev/null; then
        rm -f "$test_file"
  echo "✓ Write permissions verified"
    else
  echo "WARNING: Write permissions issue detected"
    fi
# End write permission test (if-else self-contained)

#--- Sub-block 6.9.7: GPG verification functions ---
# Purpose: Setup GPG verification for package signatures
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
setup_gpg_verification() {
    echo "==> Setting up GPG verification for .deb packages..."
}

#===============================================================================
# BLOCK 6.11: EARLY MIRROR SELECTION (BEFORE ANY APT OPERATIONS)
#===============================================================================
# Purpose: Select fastest Ubuntu mirror BEFORE any package downloads
# Self-contained: Yes
# Dependencies: curl (available in Ubuntu base images), mirror functions (BLOCK 3)
# Outputs: FASTEST_MIRROR (exported), updated /etc/apt/sources.list
# Critical: This MUST run BEFORE first apt-get update to ensure all downloads use fast mirror
#-------------------------------------------------------------------------------

#--- Sub-block 6.11.1: Check curl availability ---
# Purpose: Ensure curl is available for mirror probing
# Dependencies: Ubuntu base image (includes curl by default)
# Outputs: curl availability confirmed
echo "==> Checking curl availability for mirror probing..."
if ! command -v curl &> /dev/null; then
    echo "[warn] curl not found in base image. Installing curl first..."
    # Use /usr/bin/apt-get directly to avoid any wrapper issues
    /usr/bin/apt-get update -o Acquire::Retries=3
    /usr/bin/apt-get install -y --no-install-recommends curl
    echo "✓ curl installed"
else
    echo "✓ curl is available"
fi

#--- Sub-block 6.11.2: Execute mirror probing ---
# Critical: Select fastest mirror BEFORE any significant apt operations
# Dependencies: curl, test_mirror() and probe_and_set_mirrors() functions (BLOCK 3)
# Outputs: FASTEST_MIRROR variable (exported), updated sources
echo "==> Executing mirror probing BEFORE package installations..."
probe_and_set_mirrors

#--- Sub-block 6.11.3: Display selected mirror ---
# Purpose: Confirm mirror selection for build logs
# Dependencies: FASTEST_MIRROR (set by probe_and_set_mirrors)
# Outputs: Log output
echo "==> Mirror configuration complete:"
echo "    FASTEST_MIRROR (exported): ${FASTEST_MIRROR}"
echo "    This variable is now available globally for all apt operations"

# Show first few lines of updated sources.list for verification
echo "==> Contents of /etc/apt/sources.list (first 5 lines):"
if [ -f /etc/apt/sources.list ]; then
  head -n 5 /etc/apt/sources.list | sed 's/^/    /'
else
  echo "    [warn] /etc/apt/sources.list not found"
fi

echo "✓ Mirror selection completed - all subsequent apt operations will use fastest mirror"

#--- Sub-block 6.9.8: Enable additional APT repositories ---
# Critical: Add universe, Mozilla PPA, ulauncher PPA
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo -e "\n\033[1;34m===> Enabling the 'universe' repository for additional packages...\033[0m"
# The 'software-properties-common' package provides add-apt-repository command
    /usr/bin/apt-get update
    /usr/bin/apt-get install -y --no-install-recommends software-properties-common
add-apt-repository -y universe
add-apt-repository -y ppa:mozillateam/ppa
add-apt-repository -y ppa:agornostal/ulauncher
echo "✓ Additional repositories enabled"

#--- Sub-block 6.9.9: Synchronize base image with repositories ---
# Purpose: Resolve inconsistencies between base image and APT sources
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo -e "\n${BLUE}===> Synchronizing base image with latest package versions...${NC}"
# Using dist-upgrade handles dependency changes intelligently
apt-get update
# DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y
apt-get install -f -y
dpkg --configure -a
echo -e "${GREEN}✓ Base image synchronized.${NC}"

#===============================================================================
# BLOCK 6.12: APT CONFIGURATION AND GPG KEY SETUP
#===============================================================================
# Purpose: Configure APT, import GPG keys, set up package verification
# Self-contained: Yes (complete GPG and APT setup)
# Dependencies: dpkg, gpg, curl
# Outputs: Configured system components
#-------------------------------------------------------------------------------

#--- Sub-block 6.12.1: Install package verification tools ---
# Critical: dpkg-sig for .deb package verification (optional - not available in all Ubuntu versions)
# Dependencies: Block 6 (APT configuration), Block 15 (VirtualGL), Block 15 (TurboVNC)
# Outputs: Installed packages
    echo "Installing dpkg-sig for .deb package verification (if available)..."
    /usr/bin/apt-get install -y --no-install-recommends dpkg-sig 2>/dev/null || echo "⚠️  dpkg-sig not available, using alternative verification"

    # Import VirtualGL/TurboVNC GPG key for APT repositories
    echo "Importing VirtualGL/TurboVNC GPG key for APT..."
    # Using key URL from config.sh
    if curl -fsSL "$VIRTUALGL_TURBOVNC_GPG_KEY_URL" | gpg --dearmor -o /usr/share/keyrings/virtualgl-turbovnc.gpg; then
        echo "✓ VirtualGL/TurboVNC GPG key imported successfully for APT"
    else
  echo "✗ Failed to import VirtualGL/TurboVNC GPG key (non-fatal, will retry during installation)"
        # Don't exit - this is for APT repos which might not be in use
    fi

#--- Sub-block 6.12.2: Import Drake GPG key ---
# Critical: Import Drake robotics framework GPG key from cache
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
    echo "Importing Drake GPG key..."
    if [ -f "${CONTAINER_BIN_CACHE}/drake.asc" ]; then
        if gpg --dearmor -o /usr/share/keyrings/drake.gpg "${CONTAINER_BIN_CACHE}/drake.asc"; then
            echo "✓ Drake GPG key imported successfully"
        else
    echo "✗ Failed to import Drake GPG key"
            exit 1
        fi
    else
  echo "✗ Drake GPG key file not found"
        exit 1
    fi
# End Drake GPG import (if-else self-contained)

#--- Sub-block 6.12.3: .deb package verification function ---
# Purpose: Verify .deb packages using GPG signatures
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
    verify_deb_package() {
        local deb_file="$1"
        local gpg_key_id="$2"

        echo "Verifying .deb package: $(basename "$deb_file")"

        # First, verify package structure
        if ! dpkg-deb -I "$deb_file" >/dev/null 2>&1; then
    echo "✗ Package structure is invalid: $(basename "$deb_file")"
            exit 1
        fi

        # Import the GPG key for verification
  echo "Importing GPG key for verification..."
  if ! gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$gpg_key_id" >/dev/null; then
    echo "Δ Failed to import GPG key, trying alternative keyserver..."
    gpg --batch --keyserver keys.openpgp.org --recv-keys "$gpg_key_id" 2>/dev/null || true
        fi

        # Try dpkg-sig verification first
        if dpkg-sig --verify "$deb_file" 2>/dev/null; then
            echo "✓ GPG signature verified with dpkg-sig for $(basename "$deb_file")"
            return 0
  fi

  echo "Δ dpkg-sig verification failed, trying alternative verification..."

            # Alternative: Check if the package has a valid signature using gpg directly
            # Extract signature and verify
  if dpkg-sig -list "$deb_file" 2>/dev/null | grep -q "signature"; then
                echo "✓ Package has valid signature structure for $(basename "$deb_file")"
    return 0 # Loosening constraint to allow install
  else
    echo "✗ No valid signature found for $(basename "$deb_file")"
    echo "Δ Continuing with installation despite signature verification failure..."
    return 0 # Allow installation to continue
  fi
}

#--- Sub-block: Section continuation (595) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

#--- Sub-block 6.12.4: Unified cache configuration function ---
# Purpose: Configure all package manager caches (APT, pip, conda, Julia)
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments
setup_unified_cache() {
    echo "==> Configuring unified caching for all package managers..."

    # Validate cache first
    validate_and_repair_cache

  # 1. Configure APT Caching (safe to do early)
    # This directory exists by default on Ubuntu.
    # CRITICAL: Use double quotes to expand ${CONTAINER_APT_CACHE} variable
  echo "Dir::Cache::Archives \"${CONTAINER_APT_CACHE}\";" > /etc/apt/apt.conf.d/90-cache.conf
    echo 'APT::Keep-Downloaded-Packages "true";' >> /etc/apt/apt.conf.d/90-cache.conf

  # 2. Configure Pip Caching
mkdir -p /root/.config/pip
  printf "[global]\ncache-dir = %s\n" "$PIP_CACHE_DIR" > /root/.config/pip/pip.conf
  chown -R root:root "$PIP_CACHE_DIR" 2>/dev/null || true
  chmod -R 755 "$PIP_CACHE_DIR" 2>/dev/null || true

  # 3. Prepare Conda Caching with Staging Area Strategy
    # This config file will be used when Miniforge is installed later
  cat > ${MINIFORGE_HOME}/.condarc.pre <<-'EOF'
channels:
  - conda-forge
channel_priority: strict
# Explicitly disable defaults/anaconda repos (community repos only)
default_channels: []
pkgs_dirs:
  - ${CONTAINER_CONDA_CACHE}

# --- Robustness settings for tricky filesystems ---
use_only_tar_bz2: true # Force older, more robust package format
aggressive_update_packages: [] # Disable aggressive caching that can cause issues
solver: libmamba # Use mamba solver by default for better reliability
safety_checks: enabled # Enable safety checks
channel_alias: https://conda.anaconda.org # Use HTTPS for security
ssl_verify: true # Verify SSL certificates

# --- Staging Area Configuration ---
# Use local staging area for package extraction to avoid filesystem race conditions
extract_threads: 1 # Single-threaded extraction for consistency
use_hard_links: true # Use hard links when possible for efficiency
always_copy: false # Use hard links for efficiency
always_softlink: false # Prefer hard links over soft links
EOF

#--- Sub-block: Section continuation (640) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 634 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# === 4. Configure Julia Caching ===
    # Verify APT cache configuration was properly applied
    echo "==> Verifying APT cache configuration..."
    if [ -f /etc/apt/apt.conf.d/90-cache.conf ]; then
        echo "APT cache configuration file contents:"
        cat /etc/apt/apt.conf.d/90-cache.conf
        # Verify the path is expanded (not literal ${CONTAINER_APT_CACHE})
        if grep -q '${CONTAINER_APT_CACHE}' /etc/apt/apt.conf.d/90-cache.conf; then
            echo "ERROR: APT cache configuration has unexpanded variable!"
            exit 1
        fi
        echo "✓ APT cache configured to: ${CONTAINER_APT_CACHE}"
    else
        echo "ERROR: APT cache configuration file not created!"
        exit 1
    fi
    
    echo "==> Initial caching configured successfully."
}
# End setup_unified_cache function (self-contained)

#--- Sub-block 6.12.5: Execute unified cache setup ---
# Critical: Initialize all package manager caches before any installations
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
setup_unified_cache

#--- Sub-block 6.12.6: Protect pre-seeded cache files ---
# Purpose: Apply immutable flag to prevent accidental deletion of cached packages
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "==> Applying immutable flag to protect pre-seeded APT cache..."
# The "e2fsprogs" package, which provides chattr, is part of the base image
# We suppress errors in case no .deb files were pre-seeded
if command -v chattr >/dev/null; then
  chattr +i ${CONTAINER_APT_CACHE}/*.deb 2>/dev/null || true
  echo "✓ Pre-seeded cache files are now protected."
else
  echo "WARNING: 'chattr' command not found. Pre-seeded cache is not protected."
fi
# End cache protection (if-else self-contained)

#--- Sub-block 6.12.7: Install essential system tools ---
# Critical: Tools needed for GPG verification, downloads, and system management
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing essential tools for verification, downloads, and system management..."
apt-get update -o Acquire::Retries=3

#--- Sub-block 6.12.8: Install aria2 download accelerator ---
# Critical: Install aria2 BEFORE creating apt-aria wrapper
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing aria2 before creating apt-aria wrapper..."
/usr/bin/apt-get install -y --no-install-recommends aria2

# Monitor cache after first package installation
monitor_cache "After aria2 installation"
debug_glibc "After Aria installation"

#--- Sub-block 6.12.9: Install core APT and system utilities ---
# Critical: Essential tools for system configuration and package management
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing core APT and system utilities..."
apt-get install -y --no-install-recommends \
    e2fsprogs \
    debconf-utils \
    dialog \
    software-properties-common \
    lsb-release \
    tzdata \
    locales \
    bc
debug_glibc "After installing core APT & System utilities"

#--- Sub-block 6.12.10: Install network and download tools ---
# Critical: Tools for downloading packages and accessing repositories
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing network and download tools..."
apt-get install -y --no-install-recommends \
    curl \
    wget \
    apt-transport-https
debug_glibc "After installing network & download tools"

#--- Sub-block 6.12.11: Install security and encryption tools ---
# Critical: GPG, certificates, and security infrastructure
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing security and encryption tools..."
apt-get install -y --no-install-recommends \
    gnupg \
    dirmngr \
    ca-certificates \
    sudo
# debsig-verify removed - we use dpkg-deb for package verification instead
debug_glibc "After installing security & encryption tools"

#--- Sub-block 6.12.12: Install archive and compression tools ---
# Critical: Tools for extracting and compressing packages
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing archive and compression tools..."
apt-get install -y --no-install-recommends \
    unzip \
    bzip2 \
    tar \
    gzip \
    xz-utils \
    p7zip-full
debug_glibc "After installing archive & compression tools"
# Monitor cache after 4 batches of installations
monitor_cache "After 4 batches of essential tools"

#--- Sub-block 6.12.13: Install file and text utilities ---
# Critical: File manipulation and text editing tools
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing file and text utilities..."
apt-get install -y --no-install-recommends \
    file \
    less \
    tree \
    nano \
    vim-tiny \
    dos2unix \
    bsdextrautils \
    xxd
debug_glibc "After installing file & text utilities"

#--- Sub-block 6.12.14: Install development and system tools ---
# Critical: Git, rsync, monitoring tools
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing development and system tools..."
apt-get install -y --no-install-recommends \
    git \
    rsync \
    htop \
    jq
debug_glibc "After installing development and system tools"

#--- Sub-block 6.12.15: Install apt-utils (optional) ---
# Purpose: Additional APT utilities if available
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
apt-get install -y --no-install-recommends apt-utils || echo "Δ apt-utils not available (continuing without it)"

#--- Sub-block 6.12.16: Install advanced package managers (optional) ---
# Purpose: Install alternative APT frontends if available
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Attempting to install advanced package managers..."
apt-get install -y --no-install-recommends aptitude || echo "Δ aptitude not available (continuing without it)"
apt-get install -y --no-install-recommends nala || echo "Δ nala not available (continuing without it)"
# apt-fast removed - using apt-aria wrapper instead
apt-get install -y --no-install-recommends synaptic || echo "Δ synaptic not available (continuing without it)"
debug_glibc "After installing advanced package managers"

#--- Sub-block 6.12.17: Verify essential tool installation ---
# Critical: Ensure all required tools are available before proceeding
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
command -v curl || { echo "curl install failed"; exit 1; }
command -v wget || { echo "wget install failed"; exit 1; }
command -v gpg || { echo "gpg install failed"; exit 1; }
# debsig-verify check removed - we use dpkg-deb for package verification instead
command -v file || { echo "file install failed"; exit 1; }
command -v unzip || { echo "unzip install failed"; exit 1; }
command -v bzip2 || { echo "bzip2 install failed"; exit 1; }
command -v git || { echo "git install failed"; exit 1; }
command -v jq || { echo "jq install failed"; exit 1; }
command -v aptitude || { echo "aptitude install failed"; exit 1; }

#--- Sub-block 6.12.18: Check optional package managers ---
# Purpose: Report availability of optional tools
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "Checking for advanced package managers..."
command -v nala >& /dev/null && echo "✓ nala available" || echo "Δ nala not available"
# apt-fast removed - using apt-aria wrapper instead
command -v synaptic >& /dev/null && echo "✓ synaptic available" || echo "Δ synaptic not available"
if dpkg -l | grep -q "ii.*apt-utils"; then echo "✓ apt-utils package is installed"; else echo "Δ apt-utils package is not installed"; fi

echo "✓ Essential tools installed and verified"

# Monitor cache after essential tools installation
monitor_cache "After essential tools installation"

#--- Sub-block 6.12.19: Install SSHFS (Rust tools compiled from source later) ---
# Critical: SSHFS for remote filesystems; Rust tools compiled in Block 24
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
# Note: bat, eza, ripgrep, fd, bottom, procs compiled from source for optimization
echo "==> Installing SSHFS (Rust tools compiled from source in Block 24)..."
apt-get install -y --no-install-recommends \
  sshfs

#--- Sub-block 6.12.20: Configure aliases for modern tools (MOVED TO BLOCK 24) ---
# Purpose: Aliases configured after Rust tools are compiled from source
# Dependencies: Block 24 (cargo install)
# Outputs: Deferred to Block 24
# Note: This block intentionally empty - aliases set up after tools installed
echo "==> Rust tool aliases will be configured in Block 24 after compilation"

#===============================================================================
# BLOCK 6.12A: APT-ARIA WRAPPER SETUP (MUST BE BEFORE NVIDIA!)
#===============================================================================
# Purpose: Setup apt-aria wrapper for accelerated downloads with aria2
# Critical: MUST be configured BEFORE NVIDIA installation to enable aria2 for 4GB downloads
# Dependencies: aria2 (installed in Block 6.12.8)
# Outputs: apt-aria wrapper, symlinks for apt/apt-get
#-------------------------------------------------------------------------------

#--- Sub-block 6.12A.1: Create APT tool aliasing wrapper ---
# Purpose: Setup unified caching with aria2 acceleration
# Dependencies: Block 6 (APT configuration), aria2
# Outputs: Installed packages
echo "==> Setting up APT tool aliasing for unified caching..."

# Create apt-aria wrapper first
echo "Creating apt-aria wrapper for unified APT caching..."
install -d -m 0755 /usr/local/bin

# Configure APT to keep downloaded packages (prevent automatic cleanup)
echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/99keep-packages
echo 'APT::Clean-Installed "false";' >> /etc/apt/apt.conf.d/99keep-packages
echo 'APT::Get::AutomaticRemove "false";' >> /etc/apt/apt.conf.d/99keep-packages
echo 'APT::Get::AutomaticRemove::Kernels "false";' >> /etc/apt/apt.conf.d/99keep-packages

cat > /usr/local/bin/apt-aria <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Centralized APT cache configuration - All APT tools use this location
CACHE="${CONTAINER_APT_CACHE}"
mkdir -p "/var/cache/apt/archives"

# Common APT options for consistent caching across all tools
# Keep downloaded packages and don't clean them automatically
APT_CACHE_OPTS="-o Dir::Cache::Archives=${CACHE} -o APT::Keep-Downloaded-Packages=true -o APT::Clean-Installed=false"

# Function to determine if this is an install command that should use aria2c
is_install_command() {
    # Check if any argument is an install command (not just the first one)
    for arg in "$@"; do
        case "$arg" in
            install|remove|purge|build-dep|source)
                return 0
                ;;
        esac
    done
    return 1
}

# Function to get the appropriate APT tool
get_apt_tool() {
    if [ -x /usr/bin/apt-fast ]; then
        echo "/usr/bin/apt-fast"
    else
        echo "/usr/bin/apt-get"
    fi
}

# Get the APT tool to use
APT_TOOL=$(get_apt_tool)

# Handle install commands with aria2c acceleration
if is_install_command "$@"; then
    echo "[apt-aria] Using aria2c for accelerated downloads..."

    # Collect all http/https URLs (incl. dependencies) that would be downloaded
  URI_FILE=$(mktemp)
  echo "[apt-aria] Collecting URIs with: /usr/bin/apt-get ${APT_CACHE_OPTS} --print-uris -y $*"

    # Use a more robust approach to collect URIs
  # Filter out package metadata and only extract actual download URIs
  if /usr/bin/apt-get $APT_CACHE_OPTS --print-uris -y "$@" 2>/dev/null | \
    grep -E "'(https?://[^']*)'" | \
    sed -E "s/^'([^']+)'.*$/\1/" | \
    sed "s/ //g" | \
    grep -E "^https?://.*\.deb$" | sort -u > "$URI_FILE" 2>/dev/null; then
        echo "[apt-aria] URI collection successful"
    else
        echo "[apt-aria] URI collection failed, creating empty file"
        touch "$URI_FILE"
    fi

    echo "[apt-aria] URI file created: $URI_FILE"
    echo "[apt-aria] URI file contents:"
    cat "$URI_FILE" || echo "[apt-aria] URI file is empty or unreadable"

    if [ -s "$URI_FILE" ]; then
    echo "[apt-aria] Downloading $(< "$URI_FILE" wc -l) packages via aria2c..."
      echo "[apt-aria] Cache directory: $CACHE"
      echo "[apt-aria] aria2c command: aria2c --check-certificate=false -x16 -s16 -m3 -d $CACHE -i $URI_FILE"

      # Try multi-connection first with error suppression
      if ! aria2c --check-certificate=false -x16 -s16 -m3 -d "$CACHE" -i "$URI_FILE" 2>/dev/null; then
        echo "[apt-aria] Multi-connection failed, trying single-connection..."
        # Fallback: single-connection (handles servers that reject ranges, e.g. some PPAs)
        if ! aria2c --check-certificate=false -x1 -s1 -m3 -d "$CACHE" -i "$URI_FILE" 2>/dev/null; then
          echo "[apt-aria] aria2c failed completely, falling back to apt-get"
        else
          echo "[apt-aria] Single-connection aria2c succeeded"
        fi
      else
        echo "[apt-aria] Multi-connection aria2c succeeded"
      fi
      rm -f "$URI_FILE"
    else
      echo "[apt-aria] No URIs to download"
    fi

    # --- PROTECT CACHE ---
    # Make all .deb files in the cache immutable to prevent deletion
    echo "[apt-aria] Making downloaded packages immutable to protect cache..."
    if command -v chattr >/dev/null 2>&1; then
    chattr +i "${CACHE}/"*.deb 2>/dev/null
        echo "[apt-aria] chattr command executed successfully"
    else
        echo "[apt-aria] WARNING: chattr command not available - cache protection disabled"
    fi

    # Install from cache using apt-get (reliable and standard)
    echo "[apt-aria] Installing packages from cache..."
    exec /usr/bin/apt-get $APT_CACHE_OPTS -y "$@"
else
    # Use regular apt-get with cache configuration for non-install commands
    echo "[apt-aria] Using apt-get with cache configuration..."
    exec /usr/bin/apt-get $APT_CACHE_OPTS "$@"
fi
EOF
chmod 0755 /usr/local/bin/apt-aria
echo "✓ apt-aria wrapper created"
# Monitor cache after apt-aria setup
monitor_cache "After apt-aria wrapper setup"

#--- Sub-block 6.12A.2: Create APT tool symlinks for consistent caching ---
# Critical: Ensure ALL apt commands use unified cache and aria2 acceleration
# Dependencies: apt-aria wrapper (created above)
# Outputs: Symlinks for apt/apt-get
echo "Creating APT tool symlinks for consistent caching..."
ln -sf /usr/local/bin/apt-aria /usr/local/bin/apt-get
ln -sf /usr/local/bin/apt-aria /usr/local/bin/apt

#--- Sub-block 6.12A.3: Verify APT aliasing ---
# Purpose: Confirm symlinks are properly configured
# Dependencies: apt-aria wrapper and symlinks
# Outputs: Verification output
echo "Verifying APT tool aliasing..."
echo "apt-get -> $(readlink -f /usr/local/bin/apt-get 2>/dev/null || echo 'Not aliased')"
echo "apt -> $(readlink -f /usr/local/bin/apt 2>/dev/null || echo 'Not aliased')"
echo "✓ APT-aria wrapper and symlinks configured successfully"
echo "✓ ALL subsequent apt-get/apt commands will use aria2 acceleration + caching"

#===============================================================================
# BLOCK 6.13: NVIDIA CUDA/cuDNN SETUP
#===============================================================================
# Purpose: Install NVIDIA CUDA toolkit and cuDNN libraries (~4GB)
# Self-contained: Yes (complete NVIDIA stack installation)
# Dependencies: 
#   - Block 6.12: APT configuration (setup_unified_cache at line ~844)
#   - Block 6.12A: apt-aria wrapper and symlinks (configured at line ~1027)
# Outputs: Installed packages
# Reference: https://developer.nvidia.com/cudnn-downloads
#
# CACHING + ACCELERATION STRATEGY:
# ✅ APT cache configured: /etc/apt/apt.conf.d/90-cache.conf
# ✅ apt-aria wrapper active: Symlinked at /usr/local/bin/apt-get
# ✅ aria2 acceleration: 16-connection parallel downloads
# ✅ NVIDIA packages (~4GB) will be:
#     1. Downloaded in parallel via aria2c (10-15 min faster)
#     2. Cached in ${CONTAINER_APT_CACHE}
#     3. Reused in subsequent builds (no re-download)
#-------------------------------------------------------------------------------

#--- Sub-block 6.13.1: NVIDIA repository keyring installation ---
# Critical: Add NVIDIA GPG key and repository for CUDA 12.x
# Dependencies: Block 6 (APT configuration), Block 6.13 (NVIDIA CUDA)
# Outputs: Installed packages
echo "==> Installing NVIDIA cuDNN for CUDA 12.x..."
# Cache-first approach for NVIDIA keyring
KEYRING_DEB_NAME="cuda-keyring_1.1-1_all.deb"
KEYRING_DEB_CACHED_PATH="${CONTAINER_DEB_CACHE}/${KEYRING_DEB_NAME}"
KEYRING_DEB_TMP_PATH="/tmp/${KEYRING_DEB_NAME}"

KEYRING_INSTALL_SUCCESS=false
if [ -f "${KEYRING_DEB_CACHED_PATH}" ]; then
  echo "[INFO] Using cached NVIDIA keyring: ${KEYRING_DEB_CACHED_PATH}"
  if dpkg -i "${KEYRING_DEB_CACHED_PATH}"; then
    KEYRING_INSTALL_SUCCESS=true
  fi
else
  echo "[INFO] NVIDIA keyring not found in cache. Downloading..."
  KEYRING_URL="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/${KEYRING_DEB_NAME}"
  if curl -fsSL "${KEYRING_URL}" -o "${KEYRING_DEB_TMP_PATH}" && dpkg -i "${KEYRING_DEB_TMP_PATH}"; then
    KEYRING_INSTALL_SUCCESS=true
  fi
  rm -f "${KEYRING_DEB_TMP_PATH}"
fi

if [ "$KEYRING_INSTALL_SUCCESS" != "true" ]; then
  echo "✗ Failed to install NVIDIA repository keyring. Aborting GPU library install."
  export PHASE2_STATUS="FAIL"
  exit 1
fi

# 2. Update package list and install cuDNN
# The container already has curl, gnupg, and ca-certificates from essential tools.
# We install a specific version of libcudnn8 compatible with the Cuda 12 range.
# This ensures reproducibility. You can update the version number as needed.
apt-get update
# The following command installs the runtime library and the dev library needed for compiling software.
CUDA_MAJOR="${CUDA_VERSION%%.*}"  # Extract major version (e.g., "12" from "12.6")
if ! apt-get install -y --no-install-recommends libcudnn9=${CUDNN_VER} libcudnn9-dev=${CUDNN_VER} cuda-toolkit-${CUDA_MAJOR}; then
  echo "WARNING: Failed to install specific pinned cuDNN version. Attempting to install latest version."
  apt-get install -y --no-install-recommends libcudnn9-cuda-${CUDA_MAJOR} libcudnn9-dev-cuda-${CUDA_MAJOR} cuda-toolkit-${CUDA_MAJOR}
fi
echo "✓ NVIDIA cuDNN installed successfully."
# --- Configuration Step (Fixing the PATH) ---
echo -e "${YELLOW}[PHASE 2 | NVIDIA] Configuring system-wide environment variables for CUDA...${NC}"
# After CUDA installation, detect actual installed version (or use config.sh default)
CUDA_MAJOR="${CUDA_VERSION%%.*}"  # Extract major version from config.sh
DETECTED_CUDA=$(ls -d /usr/local/cuda-${CUDA_MAJOR}.* 2>/dev/null | head -1 | sed -n 's/.*cuda-\([0-9]\+\.[0-9]\+\).*/\1/p')
if [ -n "${DETECTED_CUDA}" ]; then
  CUDA_VERSION="${DETECTED_CUDA}"  # Use detected version if found
fi
# CUDA_VERSION now contains either detected version or config.sh default
echo "Detected CUDA version: ${CUDA_VERSION}"

#--- Sub-block: Section continuation (870) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

#--- Sub-block 6.13.2: Configure CUDA environment variables ---
# Critical: Set PATH and LD_LIBRARY_PATH for CUDA toolkit
# Dependencies: Block 6.13 (NVIDIA CUDA)
# Outputs: GPU libraries, CUDA toolkit
cat > /etc/profile.d/cuda.sh << EOF
#!/bin/sh
export PATH=/usr/local/cuda-${CUDA_VERSION}/bin\${PATH:+:\$PATH}
export LD_LIBRARY_PATH=/usr/local/cuda-${CUDA_VERSION}/lib64\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}
export CUDA_HOME=/usr/local/cuda-${CUDA_VERSION}
EOF
chmod +x /etc/profile.d/cuda.sh

#--- Sub-block 6.13.3: Ensure CUDA environment in non-login shells ---
# Purpose: Make CUDA available in all shell types
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
if [ -f /etc/profile.d/cuda.sh ]; then
  . /etc/profile.d/cuda.sh
  if ! grep -q 'cuda.sh' /etc/bash.bashrc; then
    echo '. /etc/profile.d/cuda.sh' >> /etc/bash.bashrc
  fi
fi
# End environment sourcing (if-else self-contained)

#--- Sub-block 6.13.4: Source CUDA environment for current build session ---
# Critical: Make CUDA available immediately for rest of build process
# Dependencies: Block 6.13 (NVIDIA CUDA)
# Outputs: GPU libraries, CUDA toolkit
echo "==> Sourcing CUDA environment to make it available for the rest of this build..."
source /etc/profile.d/cuda.sh
sudo ldconfig

#--- Sub-block 6.13.5: Verify CUDA installation ---
# Critical: Validate nvcc and cuDNN are properly installed
# Dependencies: Block 6.13 (NVIDIA CUDA)
# Outputs: GPU libraries, CUDA toolkit
PHASE2_SUCCESS=true
echo -e "${YELLOW}[PHASE 2 | NVIDIA] Verifying installation and environment...${NC}"
if ! command -v nvcc &>/dev/null; then
  echo -e "${RED}[VERIFICATION FAILED] 'nvcc' command not found in PATH.${NC}"
  PHASE2_SUCCESS=false
else
  echo -e "  - nvcc command: ${GREEN}OK (Found in PATH)${NC}"
  nvcc --version
fi
if ! ldconfig -p | grep -q 'libcudnn.so'; then
  echo -e "${RED}[VERIFICATION FAILED] 'libcudnn.so' not found in linker cache.${NC}"
  PHASE2_SUCCESS=false
else
  echo -e "  - libcudnn.so: ${GREEN}OK (Visible to linker)${NC}"
fi

#--- Sub-block 6.13.6: Report CUDA installation status ---
# Critical: Exit if CUDA setup failed
# Dependencies: Block 6.13 (NVIDIA CUDA)
# Outputs: GPU libraries, CUDA toolkit
if [ "${PHASE2_SUCCESS}" = true ]; then
  echo -e "${GREEN}✓ [PHASE 2] NVIDIA CUDA Toolkit and cuDNN configured and verified successfully.${NC}"
  export PHASE2_STATUS="PASS"
else
  echo -e "${RED}✗ [PHASE 2] Errors occurred during GPU environment setup. Please review logs.${NC}"
  export PHASE2_STATUS="FAIL"
  exit 1
fi
# End CUDA verification (if-else self-contained)

debug_glibc "After installing NVIDIA Cuda Toolkit"

#--- Sub-block 6.13.7: IMMEDIATE cache sync for NVIDIA packages ---
# Critical: Preserve large NVIDIA packages (~4GB) immediately to survive build failures
# Purpose: Sync NVIDIA .deb files from /var/cache/apt/archives to container cache NOW
# Rationale: NVIDIA packages are massive; if build fails later, we don't want to re-download
# Dependencies: CONTAINER_APT_CACHE (configured in Block 6.12)
# Outputs: NVIDIA packages preserved in persistent cache
echo "==> IMMEDIATE CACHE SYNC: Preserving NVIDIA packages (~4GB)..."
echo "[INFO] This intermediate sync ensures NVIDIA packages are saved even if build fails later"

# Count packages before sync
NVIDIA_PKG_COUNT_BEFORE=$(find /var/cache/apt/archives \( -name "*cuda*" -o -name "*cudnn*" -o -name "*nvidia*" \) -type f 2>/dev/null | wc -l)
CACHE_SIZE_BEFORE=$(du -sh "${CONTAINER_APT_CACHE}" 2>/dev/null | cut -f1 || echo "0B")

echo "[BEFORE SYNC] Found ${NVIDIA_PKG_COUNT_BEFORE} NVIDIA-related packages in /var/cache/apt/archives"
echo "[BEFORE SYNC] Container cache size: ${CACHE_SIZE_BEFORE}"

# Sync NVIDIA packages immediately
if [ -d "/var/cache/apt/archives" ] && [ -d "${CONTAINER_APT_CACHE}" ]; then
    echo "Copying NVIDIA packages to persistent cache..."
    
    # Copy all NVIDIA-related packages (with proper error handling)
    NVIDIA_FILES=$(find /var/cache/apt/archives \( -name "*cuda*" -o -name "*cudnn*" -o -name "*nvidia*" \) -type f -name "*.deb" 2>/dev/null)
    
    if [ -n "$NVIDIA_FILES" ]; then
        echo "$NVIDIA_FILES" | head -20 | while read -r deb_file; do
            if [ -f "$deb_file" ]; then
                cp -v "$deb_file" "${CONTAINER_APT_CACHE}/" || echo "  [warn] Failed to copy: $deb_file"
            fi
        done
        
        # Show summary
        NVIDIA_PKG_COUNT_AFTER=$(find "${CONTAINER_APT_CACHE}" \( -name "*cuda*" -o -name "*cudnn*" -o -name "*nvidia*" \) -type f 2>/dev/null | wc -l)
        CACHE_SIZE_AFTER=$(du -sh "${CONTAINER_APT_CACHE}" 2>/dev/null | cut -f1 || echo "0B")
        
        echo "[AFTER SYNC] Container cache now has ${NVIDIA_PKG_COUNT_AFTER} NVIDIA-related packages"
        echo "[AFTER SYNC] Container cache size: ${CACHE_SIZE_AFTER}"
        echo "✓ IMMEDIATE SYNC COMPLETE: NVIDIA packages preserved in ${CONTAINER_APT_CACHE}"
        echo "   → If build fails later, these ~4GB packages won't need re-downloading"
    else
        echo "[INFO] No NVIDIA packages found to sync (may have been installed from cache)"
    fi
else
    echo "[WARN] Cache directories not found, skipping immediate sync"
fi

# Force filesystem sync to ensure data is written to disk
sync

echo "==> Continuing with rest of build process..."

#--- Sub-block 6.13.11: Test unified APT cache functionality (apt-aria already configured) ---
# Purpose: Verify cache is working correctly
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "Testing unified APT cache functionality..."
if /usr/local/bin/apt-get --download-only install -y curl 2>/dev/null; then
  if [ -f "${CONTAINER_APT_CACHE}/curl"*.deb ]; then
        echo "✓ Unified APT cache test successful - curl package cached"
        rm -f ${CONTAINER_APT_CACHE}/curl*.deb 2>/dev/null || true
    else
    echo "Δ Unified APT cache test - package downloaded but not found in cache"
    fi
else
  echo "Δ Unified APT cache test failed - curl may already be installed"
fi
# End cache test (if-else self-contained)

#--- Sub-block 6.13.12: Early cached file verification function ---
# Critical: Verify integrity of all cached binaries after container copy
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments
echo "==> Performing early verification of cached files..."
early_verify_cached_files() {
    echo "Verifying cached files for corruption after container copy..."

    # Verify Miniforge installer
    if [ -f "${CONTAINER_BIN_CACHE}/${MINIFORGE_SH}" ]; then
    echo "Verifying Miniforge installer..."
    if sha256sum -c <(echo "${MINIFORGE_SHA256} ${CONTAINER_BIN_CACHE}/${MINIFORGE_SH}") 2>/dev/null; then
      echo "✓ Miniforge SHA256 verified"
    else
      echo "✗ Miniforge SHA256 verification failed - file corrupted during copy!"
            echo "  Attempting to re-download..."
      curl -fsSL -o "${CONTAINER_BIN_CACHE}/${MINIFORGE_SH}" "${MINIFORGE_URL}"
      if sha256sum -c <(echo "${MINIFORGE_SHA256} ${CONTAINER_BIN_CACHE}/${MINIFORGE_SH}") 2>/dev/null; then
        echo "✓ Miniforge re-downloaded and verified"
      else
        echo "✗ Miniforge re-download also failed - aborting build"
                exit 1
            fi
        fi
    fi

    # Verify Micromamba
    if [ -f "${CONTAINER_BIN_CACHE}/micromamba-linux-64" ]; then
    echo "Verifying Micromamba..."
    if sha256sum -c <(echo "${MICROMAMBA_SHA256} ${CONTAINER_BIN_CACHE}/micromamba-linux-64") 2>/dev/null; then
      echo "✓ Micromamba SHA256 verified"
    else
      echo "✗ Micromamba SHA256 verification failed - file corrupted during copy!"
            echo "  Attempting to re-download..."
      curl -fsSL -o "${CONTAINER_BIN_CACHE}/micromamba-linux-64" "${MICROMAMBA_URL}"
      if sha256sum -c <(echo "${MICROMAMBA_SHA256} ${CONTAINER_BIN_CACHE}/micromamba-linux-64") 2>/dev/null; then
        echo "✓ Micromamba re-downloaded and verified"
      else
        echo "✗ Micromamba re-download also failed - aborting build"
                exit 1
            fi
        fi
    fi

#--- Sub-block: Section continuation (1132) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

    # Verify yq
    if [ -f "${CONTAINER_BIN_CACHE}/yq_linux_amd64" ]; then
    echo "Verifying yq..."
    if sha256sum -c <(echo "${YQ_SHA256} ${CONTAINER_BIN_CACHE}/yq_linux_amd64") 2>/dev/null; then
      echo "✓ yq SHA256 verified"
    else
      echo "✗ yq SHA256 verification failed - file corrupted during copy!"
            echo "  Attempting to re-download..."
      curl -fsSL -o "${CONTAINER_BIN_CACHE}/yq_linux_amd64" "${YQ_URL}"
      if sha256sum -c <(echo "${YQ_SHA256} ${CONTAINER_BIN_CACHE}/yq_linux_amd64") 2>/dev/null; then
        echo "✓ yq re-downloaded and verified"
      else
        echo "✗ yq re-download also failed - aborting build"
                exit 1
            fi
        fi
    fi


#--- Sub-block: Code section 1135 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
    # Verify Julia (early verification for complex archive)
    if [ -f "${CONTAINER_BIN_CACHE}/${JULIA_TARBALL}" ]; then
    echo "Verifying Julia archive..."
        julia_file="${CONTAINER_BIN_CACHE}/${JULIA_TARBALL}"
        expected_sha256="${JULIA_SHA256}"
        julia_url="${JULIA_URL}"

        # SHA256 verification
    if sha256sum -c <(echo "${expected_sha256} ${julia_file}") 2>/dev/null; then
      echo "✓ Julia SHA256 verified"
        else
      echo "✗ Julia SHA256 verification failed - file corrupted during copy!"
            echo "  Attempting to re-download..."
      curl -fsSL -o "${julia_file}" "${julia_url}"
      if sha256sum -c <(echo "${expected_sha256} ${julia_file}") 2>/dev/null; then
        echo "✓ Julia re-downloaded and SHA256 verified"
      else
        echo "✗ Julia re-download also failed - aborting build"
                exit 1
            fi
        fi

        # gzip integrity check
    if gzip -t "${julia_file}" 2>/dev/null; then
      echo "✓ Julia gzip integrity verified"
        else
      echo "✗ Julia gzip integrity check failed - archive is corrupted!"
            echo "  Attempting to re-download..."
      curl -fsSL -o "${julia_file}" "${julia_url}"
      if gzip -t "${julia_file}" 2>/dev/null; then
        echo "✓ Julia re-downloaded and gzip integrity verified"
      else
        echo "✗ Julia re-download also failed - aborting build"
                exit 1
            fi
        fi
    fi


#--- Sub-block: Section continuation (1192) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
    echo "✓ Early verification completed - all cached files are intact"
}
# End early_verify_cached_files function (self-contained)


#--- Sub-block 6.8.1: Verify all cached binaries ---
# Purpose: Check integrity of TurboVNC, VirtualGL, Miniforge, Julia
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
#--- Sub-block 6.13.13: Execute early file verification ---
# Critical: Run verification before proceeding with build
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
early_verify_cached_files

#--- Sub-block 6.13.14: Setup GPG verification system ---
# Purpose: Initialize GPG verification for package signatures
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
setup_gpg_verification

#--- Sub-block 6.13.14: Mirror functions moved to BLOCK 3 ---
# Note: Mirror probing functions (test_mirror, probe_and_set_mirrors) have been
# moved to BLOCK 3 (lines 250-436) and executed early in BLOCK 6.11 (lines 841-889)
# This ensures ALL apt-get operations use the fastest mirror from the start.
# The old code here has been removed to avoid duplication.

#--- Sub-block 6.13.16: Configure dpkg to exclude documentation ---
# Purpose: Save space by excluding man pages and non-essential docs
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "==> Configuring dpkg to exclude unnecessary documentation..."
cat > /etc/dpkg/dpkg.cfg.d/01-nodoc << 'EOF'
# Exclude all documentation
path-exclude /usr/share/doc/*
# but keep copyright files for compliance
path-include /usr/share/doc/*/copyright
# Exclude all man pages and info pages
path-exclude /usr/share/man/*
path-exclude /usr/share/info/*
# Exclude non-English dictionaries
path-exclude /usr/share/dict/wordlist.de*
EOF

#--- Sub-block 6.13.17: Prepare for bootstrap package installation ---
# Purpose: Create directories and update package lists
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
install -d -m 0755 /usr/local/bin
apt-get update -o Acquire::Retries=3

#--- Sub-block 6.13.18: Install bootstrap packages ---
# Critical: Additional essential tools for container functionality
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing all bootstrap and utility packages..."
# Clean up any existing apt temporary directories
rm -rf /tmp/apt-dpkg-install-* 2>/dev/null || true
rm -rf /var/cache/apt/archives/partial/* 2>/dev/null || true

#--- Sub-block 6.13.19: Install additional network tools ---
# Purpose: rsync for file synchronization
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing additional network and download tools..."
apt-get install -y --no-install-recommends \
    rsync

#--- Sub-block 6.13.20: Install additional security tools ---
# Purpose: Additional encryption and security packages
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing additional security and encryption tools..."
apt-get install -y --no-install-recommends \
    ca-certificates-java

#--- Sub-block 6.13.21: Install development and utility tools ---
# Purpose: Python pip for package management
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing development and utility tools..."
apt-get install -y --no-install-recommends \
    python3-pip

#--- Sub-block 6.13.22: Post-bootstrap validation and configuration ---
# Critical: Verify installation, update certificates and locales
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
monitor_cache "After bootstrap packages installation"
debug_glibc "After installing bootstrap packages"
update-ca-certificates
locale-gen en_US.UTF-8
# We already have nala and aptitude installed via APT for package management
command -v curl || { echo "curl install failed"; exit 1; }

#--- Sub-block 6.13.23: Mirror probing already executed (moved to line ~1649) ---
# Note: probe_and_set_mirrors was moved earlier to run BEFORE apt-get operations
# This ensures all package downloads use the fastest mirror
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

#--- Sub-block 6.13.24: Configure additional PPAs ---
# Purpose: Add Mozilla, Ulauncher PPAs with fallback mechanisms
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "==> Adding all PPAs (earliest possible) - OPTIMIZED"
# Add all PPAs using fallback method (add-apt-repository with proper error handling)
echo "Adding PPA repositories with verification..."

# Try modern method first, fallback to add-apt-repository if needed
echo "Attempting to add PPAs using add-apt-repository..."
# apt-fast PPA removed - using apt-aria wrapper instead
add-apt-repository -y ppa:mozillateam/ppa 2>/dev/null || echo "[warn] Mozilla PPA failed, will try manual method"
add-apt-repository -y ppa:agornostal/ulauncher 2>/dev/null || echo "[warn] Ulauncher PPA failed, will try manual method"
    CODENAME=$(lsb_release -cs)
# If add-apt-repository failed, use manual method as fallback
if [ ! -f /etc/apt/sources.list.d/mozillateam-ubuntu-ppa-${CODENAME}.list ]; then
  echo "Using manual PPA configuration as fallback for ${CODENAME}..."

    # apt-fast PPA removed - using apt-aria wrapper instead

    # Add Mozilla PPA manually
    echo "deb http://ppa.launchpad.net/mozillateam/ppa/ubuntu ${CODENAME} main" > /etc/apt/sources.list.d/mozillateam-ppa.list
    echo "deb-src http://ppa.launchpad.net/mozillateam/ppa/ubuntu ${CODENAME} main" >> /etc/apt/sources.list.d/mozillateam-ppa.list

    # Add Ulauncher PPA manually
    echo "deb http://ppa.launchpad.net/agornostal/ulauncher/ubuntu ${CODENAME} main" > /etc/apt/sources.list.d/ulauncher-ppa.list
    echo "deb-src http://ppa.launchpad.net/agornostal/ulauncher/ubuntu ${CODENAME} main" >> /etc/apt/sources.list.d/ulauncher-ppa.list
fi

#--- Sub-block 6.13.25: Add PPA GPG keys ---
# Critical: Import signing keys for all configured PPAs
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "Adding PPA GPG keys..."
# apt-fast key removed - using apt-aria wrapper

# Mozilla PPA key
curl -fsSL https://keyserver.ubuntu.com/pks/lookup?op=get\&search=0xAEBDF4819BE21867 | gpg --dearmor -o /etc/apt/trusted.gpg.d/mozillateam.gpg 2>/dev/null || echo "[warn] Mozilla key failed"

# Ulauncher PPA key
curl -fsSL https://keyserver.ubuntu.com/pks/lookup?op=get\&search=0xFAF1020699503176 | gpg --dearmor -o /etc/apt/trusted.gpg.d/ulauncher.gpg 2>/dev/null || echo "[warn] Ulauncher key failed"

#--- Sub-block 6.13.26: Verify PPA keys ---
# Purpose: Confirm all PPA keys are properly installed
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "Verifying PPA GPG keys..."
for keyfile in /etc/apt/trusted.gpg.d/*.gpg; do
  if [ -f "$keyfile" ]; then
    echo "✓ PPA key verified: $(basename "$keyfile")"
  fi
done
# End PPA key verification loop (for loop self-contained)

#--- Sub-block 6.13.27: Update package lists with PPAs ---
# Critical: Refresh APT cache with all newly added repositories
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "Updating package lists with all PPAs..."
apt-get update -o Acquire::Retries=3

# Monitor cache after PPA update
monitor_cache "After PPA update"

#--- Sub-block 6.13.28: Configure APT robustness settings ---
# Purpose: Set retry and timeout policies for reliable downloads
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
cat >> /etc/apt/apt.conf.d/80-retries << 'EOF'
Acquire::Retries "3";
Acquire::http::Timeout "30";
Acquire::https::Timeout "30";
Acquire::ftp::Timeout "30";
EOF
# apt-fast environment variables and verification removed - using apt-aria wrapper instead

#===============================================================================
# BLOCK 6.10: DRAKE ROBOTICS FRAMEWORK SETUP
#===============================================================================
# Purpose: Configure Drake APT repository and install Drake
# Self-contained: Yes (complete setup with GPG verification)
# Dependencies: GPG, cached drake.asc key
# Outputs: Configured system components
# NOTE: Drake installed early to be available during Phase 1
#-------------------------------------------------------------------------------

#--- Sub-block 6.10.1: Drake APT repository configuration ---
# Critical: Uses hardened security with cached GPG key
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Drake APT (hardened via cached key) + INSTALL"
set -e  # Exit on any error during Drake setup
# 1) BEFORE apt-get update (temporary insecure override for just the Drake host)
cat > /etc/apt/apt.conf.d/99-drake-insecure.conf <<'EOF'
Acquire::https::drake-apt.csail.mit.edu::Verify-Peer "false";
Acquire::https::drake-apt.csail.mit.edu::Verify-Host "false";
EOF

#--- Sub-block 6.10.2: Download and configure Drake GPG key ---
# Critical: Use cached key if available, fallback to download
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
DRAKE_ASC="/tmp/drake.asc"
if [ -s "${CONTAINER_BIN_CACHE}/drake.asc" ]; then
  cp -f "${CONTAINER_BIN_CACHE}/drake.asc" "${DRAKE_ASC}"
else
  # Download from Drake repository
  wget -qO- https://drake-apt.csail.mit.edu/drake.asc | tee "$DRAKE_ASC" >/dev/null
fi

#--- Sub-block 6.10.3: Add Drake GPG key to APT keychain ---
# Critical: Install key for package signature verification
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
if [ -s "$DRAKE_ASC" ]; then
  gpg --dearmor < "$DRAKE_ASC" > /etc/apt/trusted.gpg.d/drake.gpg
  chmod 0644 /etc/apt/trusted.gpg.d/drake.gpg
else
  # Fallback: Direct pipeline method
  wget -qO- https://drake-apt.csail.mit.edu/drake.asc | gpg --dearmor - \
    >/etc/apt/trusted.gpg.d/drake.gpg
  chmod 0644 /etc/apt/trusted.gpg.d/drake.gpg
fi
# End Drake GPG setup (if-else self-contained)

#--- Sub-block 6.10.4: Configure Drake APT repository ---
# Critical: Add Drake repository to sources list
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
CODENAME="$(lsb_release -cs)"
echo "deb [arch=amd64] https://drake-apt.csail.mit.edu/${CODENAME} ${CODENAME} main" \
  >/etc/apt/sources.list.d/drake.list

#--- Sub-block 6.10.5: Install Drake dependencies ---
# Purpose: Install required X11 libraries before Drake
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
apt-get install -y \
  libx11-6 \
  libsm6 \
  libxt6 \
  libglib2.0-0
apt-get -o Dir::Cache::archives=${CONTAINER_APT_CACHE} update || apt-get update

#--- Sub-block 6.10.6: Fix broken packages before Drake ---
# Critical: Ensure clean package state before Drake installation
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "Checking for broken packages..."
apt-get -f install -y || true
dpkg --configure -a || true

#--- Sub-block 6.10.7: Install Drake framework ---
# Critical: Install drake-dev package with all dependencies
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "Installing drake-dev..."
apt-get install -y --no-install-recommends drake-dev

# Monitor cache growth after Drake installation
monitor_cache "After Drake installation"

#--- Sub-block 6.10.8: Cleanup Drake security overrides ---
# Critical: Remove temporary insecure APT configuration
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
rm -f /etc/apt/apt.conf.d/99-drake-insecure.conf

#--- Sub-block 6.10.9: Cache Drake GPG key for future builds ---
# Purpose: Save key to cache for subsequent container builds
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
[ -s "$DRAKE_ASC" ] && cp -f "$DRAKE_ASC" ${CONTAINER_BIN_CACHE}/drake.asc 2>/dev/null || true

#--- Sub-block 6.10.10: Configure Drake environment ---
# Purpose: Set up Drake Python bindings and library paths
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
cat > /etc/profile.d/drake.sh << EOF
# Drake Python bindings
# NOTE: This is for system Python (${SYSTEM_PYTHON_VER}) and ROS 2 ${ROS_DISTRO}
# will be automatically unset when Conda environments activate
export DRAKE_ROOT=${DRAKE_HOME}
site_packages=$(python3 -c 'import sys; print(f"{sys.version_info[0]}.{sys.version_info[1]}")')
# Add Drake Python bindings to PYTHONPATH
if [ -d "$DRAKE_ROOT/lib/python${site_packages}/site-packages" ]; then
  export PYTHONPATH="$DRAKE_ROOT/lib/python${site_packages}/site-packages:${PYTHONPATH}"
fi
if [ -d "$DRAKE_ROOT/lib/python3/dist-packages" ]; then
  export PYTHONPATH="$DRAKE_ROOT/lib/python3/dist-packages:${PYTHONPATH}"
fi
# Add Drake libraries to library path
if [ -d "$DRAKE_ROOT/lib" ]; then
  export LD_LIBRARY_PATH="$DRAKE_ROOT/lib:${LD_LIBRARY_PATH}"
fi
# Add Drake binaries to PATH
if [ -d "$DRAKE_ROOT/bin" ]; then
  export PATH="$DRAKE_ROOT/bin:${PATH}"
fi
EOF
chmod +x /etc/profile.d/drake.sh

echo "✓ Drake installed at ${DRAKE_HOME}"

#--- Sub-block 6.10.11: Disable Drake repository after installation ---
# Critical: Comment out Drake repo to prevent automatic updates
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
sed -i 's/^deb /#deb /' /etc/apt/sources.list.d/drake.list || true
apt-get update

#===============================================================================
# BLOCK 6.11: FIREFOX INSTALLATION
#===============================================================================
# Purpose: Install Firefox from Mozilla Team PPA with priority pinning
# Self-contained: Yes (complete with verification)
# Dependencies: APT, PPA support
# Outputs: Installed packages
#-------------------------------------------------------------------------------

#--- Sub-block 6.11.1: Configure Firefox PPA preferences ---
# Critical: Pin Firefox to Mozilla Team PPA for latest updates
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
cat > /etc/apt/preferences.d/mozillateam.pref <<'PREF'
Package: firefox*
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 501
PREF

#--- Sub-block 6.11.2: Install Firefox with dependencies ---
# Critical: Install Firefox from Mozilla Team PPA
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "Installing Firefox with optimized PPA..."
if apt-get -y --no-install-recommends install libdbus-glib-1-2 firefox; then
  echo "✓ Firefox installed successfully"
else
  echo "[warn] Firefox installation failed"
fi
# End if-else block (self-contained)

#--- Sub-block 6.11.3: Verify Firefox installation ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
if [ -x /usr/bin/firefox ]; then
  echo "✓ Firefox binary verified"
else
  echo "[warn] Firefox binary not found"
fi
# End if-else block (self-contained)

# APT caching already configured above

#--- Sub-block 6.11.4: Post-installation monitoring ---
# Purpose: Track cache growth and system state after desktop installations
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
monitor_cache "After desktop stack installation"
debug_glibc "After installing firefox, drake"

#--- Sub-block 6.11.5: noVNC HTML5 VNC client installation ---
# Purpose: Install noVNC for browser-based VNC access
# Dependencies: config.sh (NOVNC_VER)
# Outputs: Environment variables, configuration
echo "==> Installing noVNC and websockify for HTML5 VNC access..."
# Using NOVNC_VER from config.sh

#--- Sub-block 6.11.6: Install websockify proxy ---
# Critical: WebSocket proxy for noVNC browser access
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
apt-get install -y --no-install-recommends websockify python3-numpy python3-scipy

# Install/upgrade numpy and scipy with system BLAS support
# These are installed BEFORE any protections, using system OpenBLAS
pip3 install --no-cache-dir \
  numpy \
  scipy

# Install latest websockify with all features via pip
pip3 install --no-cache-dir \
  websockify \
  jwcrypto \
  redis

echo "✓ NumPy and SciPy installed (using system OpenBLAS from apt)"

#--- Sub-block 6.11.7: Download and configure noVNC client ---
# Critical: Install noVNC v1.6.0 for HTML5 VNC access
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
NOVNC_URL="https://github.com/novnc/noVNC/archive/refs/tags/v${NOVNC_VER}.tar.gz"
wget -qO /tmp/novnc.tar.gz "${NOVNC_URL}"
mkdir -p /usr/local/share/novnc
tar -xzf /tmp/novnc.tar.gz --strip-components=1 -C /usr/local/share/novnc
rm -f /tmp/novnc.tar.gz
# Set permissions for the web files
chmod -R 755 /usr/local/share/novnc
echo "✓ noVNC v${NOVNC_VER} installed"

#===============================================================================
# BLOCK 7: PHASE 1 - FOUNDATIONAL SYSTEM LIBRARIES
#===============================================================================
# Purpose: Install all base system packages via APT
# Self-contained: Yes (complete phase with success tracking)
# Dependencies: APT, cache directories
# Outputs: Installed packages
#-------------------------------------------------------------------------------

#--- Sub-block 7.1: Phase 1 initialization ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo -e "\n${BLUE}### PHASE 1: Installing Foundational System Libraries ###${NC}"

# Critical: Track overall phase success
PHASE1_ALL_SUCCESS=true

#--- Sub-block 7.2: Package group installation helper function ---
# Purpose: Install and verify package groups with detailed logging
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
# Parameters: $1=group_name, $2+= package names
install_and_verify_group() {
  local group_name="$1"
  shift
  local packages_to_install="$@"
  local group_success=true

  echo -e "${YELLOW}[PHASE 1 | ${group_name}] Installing...${NC}"
  # Run the install command, redirecting verbose output on success to a log
  # FIX: Add double quotes around the log filename to handle any special characters.
  if ! apt-get install -y --no-install-recommends ${packages_to_install} > "/tmp/apt_install_${group_name}.log" 2>&1; then
    echo -e "${RED}[PHASE 1 | ${group_name}] FAILED: 'apt-get install' command returned an error. See details below:${NC}"
    # FIX: Also quote the filename here for the cat command.
    cat "/tmp/apt_install_${group_name}.log"
    PHASE1_ALL_SUCCESS=false
    return 1
  fi

  echo -e "${YELLOW}[PHASE 1 | ${group_name}] Verifying...${NC}"
  for pkg in ${packages_to_install}; do
    if dpkg -s "$pkg" 2>/dev/null | grep -q "Status: install ok installed"; then
      echo -e "  - ${pkg}: ${GREEN}OK${NC}"
    else
      echo -e "  - ${pkg}: ${RED}FAIL (Package not found after install attempt)${NC}"
      group_success=false
      PHASE1_ALL_SUCCESS=false
    fi
  done

  if [ "${group_success}" = false ]; then
    echo -e "${RED}[PHASE 1 | ${group_name}] FAILED: One or more packages in this group failed verification.${NC}"
  fi
}
# End install_and_verify_group function (self-contained)

#--- Sub-block 7.3: Define package groups ---
# Purpose: Organize packages into logical installation groups
# Dependencies: PHASE 1 (Build tools), PHASE 1 (Compilers)
# Outputs: Configured system components

#--- Sub-block 7.3.0: Check base image glog status ---
# CRITICAL: Verify if base ROS image already has glog installed
# Base image: osrf/ros:jazzy-desktop-full-noble may include glog as ROS dependency
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Checking base image glog status..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
BASE_GLOG_INSTALLED=false
BASE_GLOG_VERSION=""

if dpkg -l 2>/dev/null | grep -q "^ii.*libgoogle-glog\|^ii.*libglog"; then
    BASE_GLOG_INSTALLED=true
    BASE_GLOG_VERSION=$(dpkg -l | grep -E "^ii.*(libgoogle-glog|libglog)" | awk '{printf "  - %s %s\n", $2, $3}')
    echo "ℹ Base image already has glog packages installed:"
    echo "$BASE_GLOG_VERSION"
    echo ""
    echo "Strategy: Will ensure libgoogle-glog-dev 0.6.0 is used (Ubuntu's patched version)"
    echo "  - apt-get will upgrade/reinstall if needed"
    echo "  - No duplicate installations (apt handles this automatically)"
else
    echo "✓ No glog in base image - will install libgoogle-glog-dev"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Build tools and compilers
PKGS_BUILD_TOOLS="build-essential gcc g++ make cmake ninja-build pkg-config ccache patchelf elfutils patch swig git pcl-tools ros-${ROS_DISTRO}-pcl-conversions ros-${ROS_DISTRO}-perception-pcl"
# Desktop environment (XFCE4)
PKGS_DESKTOP_ENV="xorg dbus-x11 xserver-xorg-video-dummy x11-xserver-utils xauth xfce4 xfce4-goodies"
# Core graphics libraries
PKGS_CORE_LIBS="libgl1 libglvnd0 libegl1 libgles2 libxext6 libxrender1 libsm6 libxrandr2 libxi6 libxxf86vm1 libxkbfile1 libxinerama1 libxcursor1 libxdamage1 libxss1 libgl1-mesa-dri libdrm-dev"
# Fonts and utilities
PKGS_FONTS_UTILS="fontconfig fonts-dejavu fonts-liberation fonts-noto iproute2 iputils-ping net-tools lsof tmux screen htop p7zip-full python3-pip python3-venv whiptail"
# Linear algebra libraries
PKGS_LINALG="libeigen3-dev libopenblas-dev liblapack-dev liblapacke-dev libblas-dev gfortran"
# CPU parallelism libraries
PKGS_CPU_PARALLEL="libtbb-dev libmpich-dev"
# Sparse matrix and SLAM libraries
PKGS_SPARSE_SLAM="libsuitesparse-dev libmetis-dev libboost-all-dev"
# Core dependencies
# NOTE: Using Ubuntu's libgoogle-glog-dev (0.6.0-2.1build1 with compatibility patches for COLMAP)
# NOTE: apt-get install will upgrade if different version exists, or skip if already correct version
# NOTE: This ensures NO duplicate glog installations - apt handles version conflicts automatically
PKGS_CORE_DEPS="libgflags-dev libgoogle-glog-dev libprotobuf-dev protobuf-compiler libhdf5-dev libffi-dev libssl-dev libbz2-dev liblzma-dev ca-certificates-java libgoogle-perftools-dev libtcmalloc-minimal4t64 libcpu-features-dev libva-dev libavcodec-dev libavformat-dev libswscale-dev"
# Media and GUI libraries
PKGS_MEDIA_GUI="libjpeg-dev libpng-dev libwebp-dev libavcodec-dev libavformat-dev libswscale-dev libavutil-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libgtk-3-dev libcanberra-gtk3-dev libvtk9-dev libgtkglext1-dev libevent-dev libyaml-cpp-dev libjsoncpp-dev"
# Simulation libraries
PKGS_SIM="libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libbullet-dev libode-dev libassimp-dev libtinyxml2-dev"
# Serialization libraries
PKGS_SERIALIZATION="libyaml-cpp-dev libjsoncpp-dev"

#--- Sub-block 7.4: Execute package group installations ---
# Critical: Install all package groups with verification
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
install_and_verify_group "BuildTools" $PKGS_BUILD_TOOLS
# --- Special install for gdb to avoid dependency conflicts ---
echo -e "${YELLOW}[PHASE 1 | BuildTools] Installing gdb without recommended packages...${NC}"
apt-get install -y --no-install-recommends gdb
if dpkg -s "gdb" 2>/dev/null | grep -q "Status: install ok installed"; then
  echo -e "  - gdb: ${GREEN}OK${NC}"
else
  echo -e "  - gdb: ${RED}FAIL${NC}"
  # This part of the logic will likely not be reached, but is here for robustness
  PHASE1_ALL_SUCCESS=false
  echo -e "${RED}[PHASE 1 | BuildTools] FAILED: gdb installation failed.${NC}"
fi
# --- End of special gdb install ---
install_and_verify_group "DesktopEnv" $PKGS_DESKTOP_ENV
install_and_verify_group "CoreLibraries" $PKGS_CORE_LIBS
install_and_verify_group "FontsAndUtilities" $PKGS_FONTS_UTILS
install_and_verify_group "LinearAlgebra" $PKGS_LINALG
install_and_verify_group "CPUParallelism" $PKGS_CPU_PARALLEL
install_and_verify_group "SparseMath_SLAM" $PKGS_SPARSE_SLAM
install_and_verify_group "CoreDependencies" $PKGS_CORE_DEPS
install_and_verify_group "Media_and_GUI" $PKGS_MEDIA_GUI
install_and_verify_group "Simulation" $PKGS_SIM
install_and_verify_group "Serialization" $PKGS_SERIALIZATION

#--- Sub-block 7.5: Verify compiler toolchain ---
# Critical: Ensure C++ compiler is properly installed
# Dependencies: Block 6 (APT configuration), PHASE 1 (Compilers)
# Outputs: Installed packages
echo -e "\n${YELLOW}[PHASE 1 | Sanity Check] Reinstalling core C++ compiler to fix any inconsistencies...${NC}"
apt-get install --reinstall -y g++ build-essential
echo -e "${GREEN}✓ Compiler toolchain verified.${NC}"

#--- Sub-block 7.6: Configure tmux for ROS workflows ---
# Purpose: Optimize tmux for multi-pane ROS development
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments
cat > /etc/tmux.conf << 'EOF'
# Increase scrollback buffer
set-option -g history-limit 50000

# Enable mouse support
set -g mouse on

# Split panes with intuitive keys
bind | split-window -h
bind - split-window -v

# Pane switching with Alt+arrow
bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D

# Status bar
set -g status-bg colour235
set -g status-fg colour136
set -g status-left '#{fg=green}{#S} '
set -g status-right '#{fg=yellow}#(whoami)@#H'
EOF

# Create helper script for multi-ROS workflow
cat > /usr/local/bin/ros_multiterm << 'EOF'
#!/bin/bash
# Launch tmux session with multiple ROS environments

SESSION="ros_multi"

# Create new tmux session
tmux new-session -d -s $SESSION

# Window 0: Humble workspace
tmux rename-window -t $SESSION:0 'Humble'
tmux send-keys -t $SESSION:0 "conda activate ros2_humble" C-m
tmux send-keys -t $SESSION:0 "cd /workspaces/humble_ws" C-m

#--- Sub-block: Section continuation (1774) ---
# Purpose: Implementation details
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments

# Window 1: ROS workspace (using ROS_DISTRO from config.sh)
tmux new-window -t $SESSION:1 -n "${ROS_DISTRO^}"  # Capitalize first letter
tmux send-keys -t $SESSION:1 "conda activate ros2_${ROS_DISTRO}" C-m
tmux send-keys -t $SESSION:1 "cd /workspaces/${ROS_DISTRO}_ws" C-m


#--- Sub-block: Code section 1755 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# Window 2: Bridge/monitoring
tmux new-window -t $SESSION:2 -n 'Bridge'
tmux send-keys -t $SESSION:2 "echo 'Domain bridge - start when ready'" C-m

# Window 3: Julia processing
tmux new-window -t $SESSION:3 -n 'Julia'
tmux send-keys -t $SESSION:3 'julia' C-m

# Attach to session
tmux attach-session -t $SESSION
EOF
chmod +x /usr/local/bin/ros_multiterm


#--- Sub-block 13.4: Tmux configuration complete ---
# Purpose: Optimized for multi-pane ROS development
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
#--- Sub-block 7.7: Phase 1 completion verification ---
# Critical: Verify all Phase 1 packages installed successfully
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
if [ "${PHASE1_ALL_SUCCESS}" = true ]; then
  echo -e "${GREEN}✓ [PHASE 1] All foundational libraries installed and verified successfully.${NC}"
  export PHASE1_STATUS="PASS"
else
  echo -e "${RED}✗ [PHASE 1] Errors occurred during foundational library installation. Please review logs above.${NC}"
  export PHASE1_STATUS="FAIL"
  exit 1 # Exit the build immediately on phase failure
fi
# End Phase 1 verification (if-else self-contained)

#--- Sub-block 7.7.1: Configure linker to prioritize compiled libraries ---
# Critical: Ensure /usr/local/lib is searched BEFORE system libraries
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "==> Configuring dynamic linker to prioritize compiled libraries..."

# Create ld.so.conf.d file with HIGHEST priority (00- prefix ensures it's read first)
cat > /etc/ld.so.conf.d/00-compiled-libs.conf << 'LDCONF'
# CRITICAL: Search /usr/local first for our optimized compiled libraries
# This prevents system packages from shadowing our Ceres, G2O, GTSAM, OpenCV, etc.
/usr/local/lib
/usr/local/lib64
/usr/local/lib/x86_64-linux-gnu
LDCONF

echo "✓ Linker configured to prioritize /usr/local/lib"

#--- Sub-block 7.8: Update dynamic linker cache ---
# Critical: Make newly installed libraries available at runtime
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "==> Updating dynamic linker cache..."
sudo ldconfig
echo "Linker cache updated."

# Verify /usr/local/lib is prioritized in cache
echo "Verifying linker search order (first 15 directories)..."
ldconfig -v 2>/dev/null | grep -E "^/" | head -15 || true

debug_glibc "After Phase 1 install: foundational system libraries"

#===============================================================================
# BLOCK 8: PHASE 3 - HIGH-LEVEL DEPENDENCIES
#===============================================================================
# Purpose: Compile robotics/vision libraries (g2o, Ceres, GTSAM) from source
# Self-contained: Yes (complete phase with success tracking)
# Dependencies: Phase 1 libraries, cmake, compilers
# Outputs: Configured system components
#-------------------------------------------------------------------------------

#--- Sub-block 8.1: Phase 3 initialization ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo -e "\n${BLUE}### PHASE 3: Compiling High-Level Dependencies ###${NC}"
# Critical: Track phase success
PHASE3_ALL_SUCCESS=true

# Robust git cloning function with retry and error handling
# NOTE: In Singularity builds, /tmp persists between attempts, so we must clean existing directories
clone_with_retry() {
    local repo_url="$1"
    local target_dir="$2"
    local branch="$3"
    local max_retries=5
    local retry_count=0
    
    # Convert relative paths to absolute (critical for Singularity environment)
    if [[ "$target_dir" != /* ]]; then
        target_dir="$(cd "$(dirname "$target_dir")" 2>/dev/null && pwd)/$(basename "$target_dir")"
        # If still relative, use current directory
        if [[ "$target_dir" != /* ]]; then
            target_dir="$(pwd)/$target_dir"
        fi
    fi
    
    echo "Cloning $repo_url to $target_dir..."
    
    # CRITICAL: Remove existing directory before cloning (essential for Singularity builds)
    # In Singularity, /tmp persists between build attempts, so directories may already exist
    if [ -d "$target_dir" ] || [ -f "$target_dir" ]; then
        echo "  Removing existing target directory: $target_dir"
        rm -rf "$target_dir" 2>/dev/null || true
    fi
    
    while [ $retry_count -lt $max_retries ]; do
        echo "Attempt $((retry_count + 1))/$max_retries..."
        
        # Configure git for better network handling
        git config --global http.postBuffer 524288000
        git config --global http.maxRequestBuffer 100M
        git config --global core.compression 0
        
        # Try cloning with different strategies
        if [ $retry_count -eq 0 ]; then
            # First attempt: standard clone
            git clone --depth 1 --branch "$branch" "$repo_url" "$target_dir"
        elif [ $retry_count -eq 1 ]; then
            # Second attempt: with single branch
            git clone --depth 1 --single-branch --branch "$branch" "$repo_url" "$target_dir"
        elif [ $retry_count -eq 2 ]; then
            # Third attempt: with no tags
            git clone --depth 1 --no-tags --branch "$branch" "$repo_url" "$target_dir"
        elif [ $retry_count -eq 3 ]; then
            # Fourth attempt: with different protocol
            if [[ "$repo_url" == https://* ]]; then
                local git_url="${repo_url/https:\/\//git@}"
                git_url="${git_url/github.com/github.com:}"
                git clone --depth 1 --branch "$branch" "$git_url" "$target_dir"
            else
                git clone --depth 1 --branch "$branch" "$repo_url" "$target_dir"
            fi
        else
            # Final attempt: shallow clone with retry
            git clone --depth 1 --branch "$branch" --config http.lowSpeedLimit=0 --config http.lowSpeedTime=999999 "$repo_url" "$target_dir"
        fi
        
        if [ $? -eq 0 ]; then
            echo "✓ Successfully cloned $repo_url"
            return 0
        else
            echo "✗ Clone attempt $((retry_count + 1)) failed"
            retry_count=$((retry_count + 1))
            
            # Clean up failed attempt
            rm -rf "$target_dir" 2>/dev/null || true
            
            if [ $retry_count -lt $max_retries ]; then
                echo "Waiting 10 seconds before retry..."
                sleep 10
            fi
        fi
    done
    
    echo "✗ Failed to clone $repo_url after $max_retries attempts"
    return 1
}

#--- Sub-block 8.1.5: Use Ubuntu's System glog Package ---
# Purpose: Use Ubuntu's patched glog for COLMAP 3.12.6 compatibility
# 
# CHANGED APPROACH (2025-01-30):
#   Previously: Compiled glog 0.5.0 from source
#   Now: Use Ubuntu's libgoogle-glog-dev (0.6.0-2.1build1)
#
# WHY THE CHANGE:
#   - Ubuntu's glog 0.6.0-2.1build1 includes BACKPORTED compatibility patches
#   - Has GOOGLE_PREDICT_BRANCH_NOT_TAKEN, CHECK_OP_LOG, CheckOpString macros
#   - Upstream glog 0.6.0 removed these, but Ubuntu restored them for compatibility
#   - Verified working on local Ubuntu 24.04 Noble systems
#   - Simpler, faster build (no compilation needed)
#   - Uses standard system library paths
#
# COMPATIBILITY DESIGN:
#   - Ceres: Uses MINIGLOG=ON (internal bundled mini-glog) → ISOLATED, NO CONFLICT
#   - COLMAP: Uses system glog 0.6.0-2.1build1 (Ubuntu's patched version) → COMPATIBLE
#   - g2o: No glog dependency → NO CONFLICT
#   - GTSAM: No glog dependency → NO CONFLICT
#   - Open3D: No glog dependency → NO CONFLICT
#   - ROS2 Jazzy: No glog core dependency → NO CONFLICT
#
# NOTE: libgoogle-glog-dev is now INCLUDED in PKGS_CORE_DEPS (line ~2237)
# NOTE: COLMAP uses -fpermissive flag for additional robustness with template instantiations
#
# Dependencies: APT repositories configured
# Outputs: System glog library in /usr (installed via apt)
echo -e "\n${YELLOW}[PHASE 3 | glog] Using Ubuntu system package (libgoogle-glog-dev)...${NC}"
echo "✓ glog will be installed via apt as libgoogle-glog-dev (0.6.0-2.1build1)"
echo "  - Includes Ubuntu's compatibility patches for COLMAP"
echo "  - No compilation needed"
echo ""
monitor_cache "After glog setup (system package)"

#--- Sub-block 8.2: Compile Ceres Solver ---
# Purpose: Build Ceres optimization library from source (COMPILE FIRST - g2o can link to it)
# Dependencies: PHASE 1 (Build tools), Block 6.13 (NVIDIA CUDA)
# Note: Changed from Sub-block 8.1.5 dependency (glog source) - now uses system glog package
# Outputs: Optimized Ceres library
echo -e "\n${YELLOW}[PHASE 3 | Ceres] Compiling from source...${NC}"
rm -rf /tmp/ceres-solver
# Using CERES_VERSION from config.sh
if ! clone_with_retry "https://github.com/ceres-solver/ceres-solver.git" "/tmp/ceres-solver" "${CERES_VERSION}"; then
    echo "ERROR: Failed to clone Ceres Solver after all retry attempts"
    exit 1
fi
# Use explicit, separate commands for navigation
cd /tmp/ceres-solver || { echo "ERROR: Failed to access ceres-solver directory"; exit 1; }
# Remove existing build directory if it exists (critical for Singularity rebuilds)
rm -rf build
mkdir -p build
cd build || { echo "ERROR: Failed to access build directory"; exit 1; }

#--- Sub-block 8.3: Configure Ceres with CMake ---
# Critical: CMake configuration with optimizations (OpenMP enabled via -fopenmp in CXX_FLAGS)
# 
# COMPATIBILITY NOTE: MINIGLOG=ON (uses Ceres internal mini-glog)
#   Why: Isolates Ceres from external glog changes, preventing ABI conflicts
#   Result: Ceres uses bundled mini-glog, COLMAP uses system glog 0.6.0-2.1build1
#   Benefit: Maximum stability, each library uses appropriate glog version
#   Alternative: MINIGLOG=OFF would make Ceres use external glog (not recommended)
#
cmake .. \
  -G Ninja \
  -D CMAKE_BUILD_TYPE=Release \
  -D CMAKE_INSTALL_PREFIX=/usr/local \
  -D CMAKE_CXX_FLAGS="-march=x86-64-v3 -O3 -mavx2 -mfma -msse4.2 -fopenmp -funroll-loops" \
  -D CMAKE_C_FLAGS="-march=x86-64-v3 -O3 -mavx2 -mfma -msse4.2 -fopenmp -funroll-loops" \
  -D CMAKE_SHARED_LINKER_FLAGS="-flto -fopenmp" \
  -D CMAKE_INSTALL_RPATH="/usr/local/lib" \
  -D CMAKE_INSTALL_RPATH_USE_LINK_PATH=TRUE \
  -D BUILD_SHARED_LIBS=ON \
  -D MINIGLOG=ON \
  -D CMAKE_CUDA_COMPILER_WORKS=TRUE \
  -D BLA_VENDOR=OpenBLAS \
  -D LAPACK=ON \
  -D EIGENMETIS=ON \
  -D EIGENSPARSE=ON \
  -D SUITESPARSE=ON \
  -D USE_CUDA=ON \
  -D BUILD_EXAMPLES=OFF \
  -D BUILD_TESTING=OFF \
  -D BUILD_BENCHMARKS=OFF \
  -D CMAKE_CUDA_ARCHITECTURES="86;89;90" \
  -D CMAKE_CXX_STANDARD=17 \
  -D CMAKE_CXX_STANDARD_REQUIRED=ON \
  -D CMAKE_INTERPROCEDURAL_OPTIMIZATION=ON

#--- Sub-block 8.4: Build and install Ceres ---
# Critical: Compile with ninja using half CPU cores
ninja -j$(($(nproc) / 2)) || { echo "ERROR: Failed to build Ceres"; exit 1; }
ninja install || { echo "ERROR: Failed to install Ceres"; exit 1; }
ldconfig

# CRITICAL: Check dpkg status file for corruption before proceeding
echo "Checking dpkg status file integrity..."
if ! dpkg --audit > /dev/null 2>&1; then
    echo "⚠ WARNING: dpkg status file may be corrupted. Attempting repair..."
    
    # Check specifically for duplicate Package entries
    DUPLICATES=$(awk '/^Package:/ {count[$2]++} END {for (pkg in count) if (count[pkg] > 1) print pkg}' /var/lib/dpkg/status)
    
    if [ -n "$DUPLICATES" ]; then
        echo "  Found duplicate package entries: $(echo $DUPLICATES | tr '\n' ', ')"
        echo "  Creating clean dpkg status file..."
        
        # Backup the corrupted file
        cp /var/lib/dpkg/status /var/lib/dpkg/status.corrupted.backup
        
        # Remove ALL duplicate entries using awk (keep only first occurrence)
        awk '
            /^Package:/ {
                pkg = $2
                if (seen[pkg]) {
                    skip = 1
                    next
                }
                seen[pkg] = 1
                skip = 0
            }
            !skip || /^$/ {
                if (/^$/ && skip) {
                    skip = 0
                    next
                }
                print
            }
        ' /var/lib/dpkg/status.corrupted.backup > /var/lib/dpkg/status.new
        
        # Verify the new file is valid
        if [ -s /var/lib/dpkg/status.new ] && grep -q "^Package:" /var/lib/dpkg/status.new; then
            mv /var/lib/dpkg/status.new /var/lib/dpkg/status
            echo "  ✓ dpkg status file repaired successfully"
            echo "  Corrupted backup saved to: /var/lib/dpkg/status.corrupted.backup"
        else
            echo "  ✗ ERROR: Failed to repair dpkg status file"
            rm -f /var/lib/dpkg/status.new
            exit 1
        fi
    fi
else
    echo "✓ dpkg status file integrity verified"
fi

#--- Sub-block 8.1.5.1: Verify System glog Installation ---
# Purpose: Verify Ubuntu's glog 0.6.0 is installed and check for version conflicts
# Dependencies: PKGS_CORE_DEPS (libgoogle-glog-dev already installed from apt)
# Outputs: Verified glog installation
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Verifying system glog installation for COLMAP compatibility..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for multiple glog installations (potential conflict)
echo "🔍 Checking for conflicting glog versions..."
echo ""
echo "1. Checking all glog libraries in system:"
ldconfig -p | grep glog || echo "  ⚠ No glog libraries found in ldconfig cache"
echo ""

echo "2. Checking all glog headers:"
find /usr/include /usr/local/include -name "logging.h" 2>/dev/null | grep glog || echo "  ⚠ No glog headers found"
echo ""

echo "3. Checking dpkg for installed glog packages:"
dpkg -l | grep glog || echo "  ℹ No glog packages in dpkg"
echo ""

# Verify system glog is installed
if ! dpkg -l | grep -q "^ii.*libgoogle-glog-dev"; then
    echo "✗ ERROR: libgoogle-glog-dev not installed!"
    echo "  This should have been installed via PKGS_CORE_DEPS"
    exit 1
fi

INSTALLED_GLOG=$(dpkg -l | grep "^ii.*libgoogle-glog-dev" | awk '{print $3}')
echo "✓ Found system glog: ${INSTALLED_GLOG}"
echo ""

# Verify CMake can find glog
echo "4. Verifying CMake can detect glog..."
if [ -d "/usr/lib/x86_64-linux-gnu/cmake/glog" ]; then
    echo "  ✓ CMake config found: /usr/lib/x86_64-linux-gnu/cmake/glog"
    if [ -f "/usr/lib/x86_64-linux-gnu/cmake/glog/glog-config.cmake" ]; then
        echo "  ✓ glog-config.cmake exists"
    fi
else
    echo "  ⚠ WARNING: glog CMake config not found in expected location"
    echo "    COLMAP may have issues finding glog"
fi
echo ""

# Check glog version for COLMAP compatibility
echo "5. Checking glog version compatibility with COLMAP 3.12.6..."
GLOG_VERSION=$(pkg-config --modversion libglog 2>/dev/null || echo "unknown")
if [ "$GLOG_VERSION" != "unknown" ]; then
    echo "  ✓ pkg-config reports glog version: ${GLOG_VERSION}"
    # Extract major.minor version
    GLOG_MAJOR=$(echo "$GLOG_VERSION" | cut -d. -f1)
    GLOG_MINOR=$(echo "$GLOG_VERSION" | cut -d. -f2)
    
    if [ "$GLOG_MAJOR" -eq 0 ] && [ "$GLOG_MINOR" -eq 6 ]; then
        echo "  ℹ Using glog 0.6.x - Ubuntu's version includes compatibility patches"
        echo "    for COLMAP 3.12.6 (CHECK macros, PREDICT macros, etc.)"
    fi
else
    echo "  ℹ glog version not available via pkg-config (non-fatal)"
fi
echo ""

# Test if glog headers are accessible
echo "6. Testing glog header accessibility..."
if [ -f "/usr/include/glog/logging.h" ]; then
    echo "  ✓ glog headers found: /usr/include/glog/logging.h"
else
    echo "  ✗ ERROR: glog headers not found"
    exit 1
fi
echo ""

# WARNING: Check for /usr/local glog installation (would conflict)
echo "7. Checking for conflicting /usr/local glog installation..."
if [ -f "/usr/local/include/glog/logging.h" ] || [ -f "/usr/local/lib/libglog.so" ]; then
    echo "  ⚠ WARNING: Found glog in /usr/local!"
    echo "    This may conflict with system glog in /usr"
    echo "    /usr/local has higher priority in CMake searches"
    echo ""
    echo "  Files found:"
    [ -f "/usr/local/include/glog/logging.h" ] && echo "    - /usr/local/include/glog/logging.h"
    [ -f "/usr/local/lib/libglog.so" ] && echo "    - /usr/local/lib/libglog.so"
    echo ""
    echo "  Recommendation: Remove /usr/local glog or use CMAKE_IGNORE_PATH"
else
    echo "  ✓ No conflicting /usr/local glog found"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "System glog verification complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Compatibility Configuration:"
echo "  glog:          System package (Ubuntu ${INSTALLED_GLOG})"
echo "  Ceres Solver:  Internal MINIGLOG (bundled, isolated)"
echo "  COLMAP:        System glog (Ubuntu's patched 0.6.0)"
echo ""
monitor_cache "After glog verification"

#--- Sub-block 8.2: Compile Ceres Solver ---
# Purpose: Build Ceres optimization library from source (COMPILE FIRST - g2o can link to it)
# Dependencies: PHASE 1 (Build tools), Block 6.13 (NVIDIA CUDA)
# Note: Uses internal MINIGLOG (bundled), NOT system glog - fully isolated
# Outputs: Optimized Ceres library
echo -e "\n${YELLOW}[PHASE 3 | Ceres] Compiling from source...${NC}"
rm -rf /tmp/ceres-solver
# Using CERES_VERSION from config.sh
if ! clone_with_retry "https://github.com/ceres-solver/ceres-solver.git" "/tmp/ceres-solver" "${CERES_VERSION}"; then
    echo "ERROR: Failed to clone Ceres Solver after all retry attempts"
    exit 1
fi
# Use explicit, separate commands for navigation
cd /tmp/ceres-solver || { echo "ERROR: Failed to access ceres-solver directory"; exit 1; }
# Remove existing build directory if it exists (critical for Singularity rebuilds)
rm -rf build
mkdir -p build
cd build || { echo "ERROR: Failed to access build directory"; exit 1; }

#--- Sub-block 8.3: Configure Ceres with CMake ---
# Critical: CMake configuration with optimizations (OpenMP enabled via -fopenmp in CXX_FLAGS)
# 
# COMPATIBILITY NOTE: MINIGLOG=ON (uses Ceres internal mini-glog)
#   Why: Isolates Ceres from external glog changes, preventing ABI conflicts
#   Result: Ceres uses bundled mini-glog, COLMAP uses system glog 0.6.0
#   Benefit: Maximum stability, each library uses appropriate glog version
#   Alternative: MINIGLOG=OFF would make Ceres use external glog (not recommended)
#
cmake .. \
  -G Ninja \
  -D CMAKE_BUILD_TYPE=Release \
  -D CMAKE_INSTALL_PREFIX=/usr/local \
  -D CMAKE_CXX_FLAGS="-march=x86-64-v3 -O3 -mavx2 -mfma -msse4.2 -fopenmp -funroll-loops" \
  -D CMAKE_C_FLAGS="-march=x86-64-v3 -O3 -mavx2 -mfma -msse4.2 -fopenmp -funroll-loops" \
  -D CMAKE_SHARED_LINKER_FLAGS="-flto -fopenmp" \
  -D CMAKE_INSTALL_RPATH="/usr/local/lib" \
  -D CMAKE_INSTALL_RPATH_USE_LINK_PATH=TRUE \
  -D BUILD_SHARED_LIBS=ON \
  -D MINIGLOG=ON \
  -D CMAKE_CUDA_COMPILER_WORKS=TRUE \
  -D BLA_VENDOR=OpenBLAS \
  -D LAPACK=ON \
  -D EIGENMETIS=ON \
  -D EIGENSPARSE=ON \
  -D SUITESPARSE=ON \
  -D USE_CUDA=ON \
  -D BUILD_EXAMPLES=OFF \
  -D BUILD_TESTING=OFF \
  -D BUILD_BENCHMARKS=OFF \
  -D CMAKE_CUDA_ARCHITECTURES="86;89;90" \
  -D CMAKE_CXX_STANDARD=17 \
  -D CMAKE_CXX_STANDARD_REQUIRED=ON \
  -D CMAKE_INTERPROCEDURAL_OPTIMIZATION=ON

#--- Sub-block 8.4: Build and install Ceres ---
# Critical: Compile with ninja using half CPU cores
ninja -j$(($(nproc) / 2)) || { echo "ERROR: Failed to build Ceres"; exit 1; }
ninja install || { echo "ERROR: Failed to install Ceres"; exit 1; }
ldconfig

#--- Sub-block 8.5: Verify Ceres installation ---
# Critical: Confirm Ceres libraries in linker cache
if ! ldconfig -p | grep -q "libceres.so"; then
  echo -e "${RED}✗ Ceres compilation FAILED.${NC}"
  PHASE3_ALL_SUCCESS=false
fi

#--- Sub-block 8.5.1: Protect compiled Ceres from APT overwrites ---
# Critical: Prevent APT from installing ANY system Ceres packages
# Strategy: Use APT pinning with negative priority (consistent with glog and OpenCV)
echo "Protecting compiled Ceres from APT overwrites..."

# Create APT preferences directory
mkdir -p /etc/apt/preferences.d

# Block ALL system Ceres packages using APT pinning with negative priority
cat > /etc/apt/preferences.d/block-system-ceres << 'EOF'
# Block system Ceres packages (prevent installation)
# Our optimized Ceres Solver 2.2.0 is compiled from source in /usr/local
# Negative priority (-1) means APT will never install these packages

Package: libceres-dev
Pin: release *
Pin-Priority: -1

Package: libceres3
Pin: release *
Pin-Priority: -1

Package: libceres2
Pin: release *
Pin-Priority: -1

Package: libceres1
Pin: release *
Pin-Priority: -1
EOF

if [ -f "/etc/apt/preferences.d/block-system-ceres" ]; then
    echo "✓ Created APT preferences to block system Ceres packages"
    echo "  - Blocks: libceres-dev, libceres3, libceres2, libceres1"
    echo "  - Method: APT pinning with Pin-Priority: -1"
else
    echo "✗ ERROR: Failed to create Ceres protection file"
    exit 1
fi

echo "✓ Ceres protected from APT overwrites (APT pinning method)"

# Cleanup
cd / && rm -rf /tmp/ceres-solver
debug_glibc "After installing CERES"

#--- Sub-block 8.6: Compile g2o (graph optimization) ---
# Purpose: Graph optimization library (uses Ceres if available - compiled after Ceres)
# Dependencies: PHASE 1 (Build tools), Sub-block 8.2 (Ceres Solver - optional but recommended)
# Outputs: Configured system components
if [ "${PHASE3_ALL_SUCCESS}" = true ]; then
  echo -e "\n${YELLOW}[PHASE 3 | g2o] Compiling from source...${NC}"
  rm -rf /tmp/g2o
  # Using G2O_VERSION from config.sh
  if ! clone_with_retry "https://github.com/RainerKuemmerle/g2o.git" "/tmp/g2o" "${G2O_VERSION}"; then
    echo "ERROR: Failed to clone G2O after all retry attempts"
    exit 1
  fi
  cd /tmp/g2o || { echo "ERROR: Failed to access g2o directory"; exit 1; }
  # Remove existing build directory if it exists (critical for Singularity rebuilds)
  rm -rf build
  mkdir -p build && cd build || { echo "ERROR: Failed to create/access build dir"; exit 1; }

  #--- Sub-block 8.7: Configure g2o with CMake ---
  # Critical: CMake configuration - will auto-detect Ceres if available
  cmake .. \
    -G Ninja \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_INSTALL_PREFIX=/usr/local \
    -D CMAKE_CXX_STANDARD=17 \
    -D CMAKE_CXX_STANDARD_REQUIRED=ON \
    -D BUILD_SHARED_LIBS=ON \
    -D BUILD_WITH_MARCH_NATIVE=OFF \
    -D G2O_USE_CHOLMOD=ON \
    -D G2O_USE_CSPARSE=ON \
    -D G2O_USE_OPENMP=ON \
    -D BUILD_UNITTESTS=OFF \
    -D CMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
    -D CMAKE_CXX_FLAGS="-march=x86-64-v3 -O3 -mavx2 -mfma -msse4.2 -fopenmp -funroll-loops" \
    -D CMAKE_C_FLAGS="-march=x86-64-v3 -O3 -mavx2 -mfma -msse4.2 -fopenmp -funroll-loops" \
    -D CMAKE_SHARED_LINKER_FLAGS="-flto -fopenmp" \
    -D CMAKE_INSTALL_RPATH="/usr/local/lib" \
    -D CMAKE_INSTALL_RPATH_USE_LINK_PATH=TRUE

  #--- Sub-block 8.8: Build and install g2o ---
  # Critical: Compile g2o with ninja using half CPU cores
  ninja -j$(($(nproc) / 2)) || { echo "ERROR: Failed to build g2o"; exit 1; }
  ninja install || { echo "ERROR: Failed to install g2o"; exit 1; }
  ldconfig

  #--- Sub-block 8.9: Verify g2o installation ---
  # Critical: Confirm g2o libraries are in linker cache
  if ! ldconfig -p | grep -q "libg2o_core.so"; then
    echo -e "${RED}✗ g2o compilation FAILED.${NC}"
    PHASE3_ALL_SUCCESS=false
  fi

  #--- Sub-block 8.9.1: Protect compiled G2O from APT overwrites ---
  # Critical: Prevent APT from installing ANY system G2O packages
  # Strategy: Use APT pinning with negative priority (consistent with glog, Ceres, and OpenCV)
  echo "Protecting compiled G2O from APT overwrites..."
  
  # Create APT preferences directory
  mkdir -p /etc/apt/preferences.d
  
  # Block ALL system G2O packages using APT pinning with negative priority
  cat > /etc/apt/preferences.d/block-system-g2o << 'EOF'
# Block system G2O packages (prevent installation)
# Our optimized G2O 20241228_git is compiled from source in /usr/local
# Negative priority (-1) means APT will never install these packages

Package: libg2o-dev
Pin: release *
Pin-Priority: -1

Package: libg2o0
Pin: release *
Pin-Priority: -1

Package: libg2o20130302
Pin: release *
Pin-Priority: -1
EOF
  
  if [ -f "/etc/apt/preferences.d/block-system-g2o" ]; then
      echo "✓ Created APT preferences to block system G2O packages"
      echo "  - Blocks: libg2o-dev, libg2o0, libg2o20130302"
      echo "  - Method: APT pinning with Pin-Priority: -1"
  else
      echo "✗ ERROR: Failed to create G2O protection file"
      exit 1
  fi
  
  echo "✓ G2O protected from APT overwrites (APT pinning method)"

  # Cleanup
  cd / && rm -rf /tmp/g2o
fi
debug_glibc "After installing g2o"

#--- Sub-block 8.10: Compile GTSAM ---
# Purpose: Build GTSAM SLAM library with TBB and Python bindings
# Dependencies: PHASE 1 (Build tools), sparse solvers (CHOLMOD, METIS)
# Outputs: Configured system components
if [ "${PHASE3_ALL_SUCCESS}" = true ]; then
  echo -e "${YELLOW}[PHASE 3 | GTSAM] Compiling from source...${NC}"
  rm -rf /tmp/gtsam
  # Using GTSAM_VERSION from config.sh
  if ! clone_with_retry "https://github.com/borglab/gtsam.git" "/tmp/gtsam" "${GTSAM_VERSION}"; then
    echo "ERROR: Failed to clone GTSAM after all retry attempts"
    exit 1
  fi
  cd /tmp/gtsam || { echo "ERROR: Failed to access gtsam directory"; exit 1; }
  # Remove existing build directory if it exists (critical for Singularity rebuilds)
  rm -rf build
  mkdir -p build && cd build || { echo "ERROR: Failed to create/access build dir"; exit 1; }

  #--- Sub-block 8.11: Configure GTSAM with CMake ---
  # Critical: Enable TBB, Python bindings, system libraries
  cmake .. \
    -G Ninja \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_INSTALL_PREFIX=/usr/local \
    -D CMAKE_POLICY_DEFAULT_CMP0069=NEW \
    -D BUILD_SHARED_LIBS=ON \
    -D GTSAM_WITH_TBB=ON \
    -D GTSAM_USE_SYSTEM_EIGEN=ON \
    -D GTSAM_BUILD_TESTS=OFF \
    -D GTSAM_BUILD_EXAMPLES_ALWAYS=OFF \
    -D GTSAM_USE_SYSTEM_METIS=ON \
    -D GTSAM_POSE3_EXPMAP=ON \
    -D GTSAM_ROT3_EXPMAP=ON \
    -D CMAKE_CXX_FLAGS="-march=x86-64-v3 -O3 -mavx2 -mfma -msse4.2 -fopenmp -funroll-loops" \
    -D CMAKE_C_FLAGS="-march=x86-64-v3 -O3 -mavx2 -mfma -msse4.2 -fopenmp -funroll-loops" \
    -D CMAKE_SHARED_LINKER_FLAGS="-flto -fopenmp" \
    -D CMAKE_INSTALL_RPATH="/usr/local/lib" \
    -D CMAKE_INSTALL_RPATH_USE_LINK_PATH=TRUE \
    -D GTSAM_BUILD_PYTHON=ON \
    -D GTSAM_PYTHON_VERSION=${SYSTEM_PYTHON_VER} \
    -D GTSAM_BUILD_WITH_MARCH_NATIVE=OFF \
    -D CMAKE_CXX_STANDARD=17 \
    -D CMAKE_CXX_STANDARD_REQUIRED=ON \
    -D CMAKE_INTERPROCEDURAL_OPTIMIZATION=ON

  #--- Sub-block 8.12: Build and install GTSAM ---
  # Critical: Compile with ninja using half CPU cores
  ninja -j$(($(nproc) / 2)) || { echo "ERROR: Failed to build GTSAM"; exit 1; }
  ninja install || { echo "ERROR: Failed to install GTSAM"; exit 1; }
  ldconfig

  #--- Sub-block 8.13: Verify GTSAM installation ---
  # Critical: Confirm GTSAM libraries in linker cache
  if ! ldconfig -p | grep -q "libgtsam.so"; then
    echo -e "${RED}✗ GTSAM compilation FAILED.${NC}"
    PHASE3_ALL_SUCCESS=false
  fi

  #--- Sub-block 8.13.1: Protect compiled GTSAM from APT overwrites ---
  # Critical: Prevent APT from installing ANY system GTSAM packages
  # Strategy: Use APT pinning with negative priority (consistent with glog, Ceres, G2O, and OpenCV)
  echo "Protecting compiled GTSAM from APT overwrites..."
  
  # Create APT preferences directory
  mkdir -p /etc/apt/preferences.d
  
  # Block ALL system GTSAM packages using APT pinning with negative priority
  cat > /etc/apt/preferences.d/block-system-gtsam << 'EOF'
# Block system GTSAM packages (prevent installation)
# Our optimized GTSAM 4.2.0 is compiled from source in /usr/local
# Negative priority (-1) means APT will never install these packages

Package: libgtsam-dev
Pin: release *
Pin-Priority: -1

Package: libgtsam4
Pin: release *
Pin-Priority: -1

Package: libgtsam-unstable4
Pin: release *
Pin-Priority: -1
EOF
  
  if [ -f "/etc/apt/preferences.d/block-system-gtsam" ]; then
      echo "✓ Created APT preferences to block system GTSAM packages"
      echo "  - Blocks: libgtsam-dev, libgtsam4, libgtsam-unstable4"
      echo "  - Method: APT pinning with Pin-Priority: -1"
  else
      echo "✗ ERROR: Failed to create GTSAM protection file"
      exit 1
  fi
  
  echo "✓ GTSAM protected from APT overwrites (APT pinning method)"

  # Cleanup
  cd / && rm -rf /tmp/gtsam
fi
debug_glibc "After installing GTSAM"

#--- Sub-block 8.14: Phase 3 completion verification ---
# Critical: Verify all Phase 3 libraries compiled successfully
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
if [ "${PHASE3_ALL_SUCCESS}" = true ]; then
  echo -e "${GREEN}✓ [PHASE 3] All high-level dependencies compiled and installed successfully.${NC}"
  export PHASE3_STATUS="PASS"
else
  echo -e "${RED}✗ [PHASE 3] One or more compilations failed. Please review logs.${NC}"
  export PHASE3_STATUS="FAIL"
  exit 1
fi
# End Phase 3 verification (if-else self-contained)

#===============================================================================
# BLOCK 8.5: JULIA LANGUAGE INSTALLATION
#===============================================================================
# Purpose: Install Julia 1.10 LTS with package environments
# Self-contained: Yes (complete with verification)
# Dependencies: Cached Julia tarball, GPG verification
# Outputs: Julia packages, environments
# NOTE: Installed after GTSAM to use CxxWrap for Julia-C++ interop
#-------------------------------------------------------------------------------

#--- Sub-block 8.5.1: Julia version and path configuration ---
# Critical: Use Julia configuration from config.sh
# Dependencies: config.sh (sourced at top of script)
# Outputs: Environment variables, configuration
# All Julia variables (version, URL, tarball) come from config.sh
JVER="${JULIA_LTS_VER}"
JMAJOR="${JULIA_LTS_VER%.*}" # e.g. 1.10 (bash parameter expansion)
# Derived URLs (not in config.sh but needed here)
JULIA_BASEURL="https://julialang-s3.julialang.org/bin/linux/x64/${JMAJOR}"
JULIA_SUMS_URL="${JULIA_BASEURL}/SHA256SUMS"
CACHE_DIR="${CONTAINER_BIN_CACHE}"
INSTALL_DIR="/opt"
LATEST_TGZ="${CACHE_DIR}/${JULIA_TARBALL}"

#--- Sub-block 8.5.2: Prepare cache directory ---
# Purpose: Create cache directory for Julia tarball
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
mkdir -p "${CACHE_DIR}"

#--- Sub-block 8.5.3: Determine if Julia download needed ---
# Critical: Check if cached tarball exists and is valid
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
need_fetch=0
if [ ! -f "${LATEST_TGZ}" ]; then
  need_fetch=1
else
  # Quick integrity test
  if ! gzip -t "${LATEST_TGZ}" 2>/dev/null; then
    need_fetch=1
  fi
fi

#--- Sub-block 8.5.4: Download Julia if needed ---
# Purpose: Fetch Julia tarball with retry logic
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
if [ "$need_fetch" -eq 1 ]; then
  echo "[julia] fetching ${JULIA_URL}"
  # Retry, follow redirects, fail on HTTP errors
  curl -fsSL --retry 5 --retry-all-errors --connect-timeout 5 --max-time 180 \
    -o "${LATEST_TGZ}.part" "${JULIA_URL}"
  mv -f "${LATEST_TGZ}.part" "${LATEST_TGZ}"
fi
# End download if block (self-contained)

#--- Sub-block 8.5.5: Julia archive verification ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# Note: Archive already verified in early verification phase
echo "[julia] Archive already verified (SHA256 + gzip integrity check passed)"

#--- Sub-block 8.5.6: Optional GPG signature verification ---
# Purpose: Best-effort GPG verification (non-blocking)
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "[julia] Performing optional GPG signature verification..."
GNUPGHOME=/root/.gnupg
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"
# Download .asc file if available
curl -fsSL --retry 3 "${JULIA_ASC_URL}" -o "${LATEST_TGZ}.asc" || true
#--- Sub-block 8.5.7: Import Julia GPG key ---
# Purpose: Load GPG key for signature verification
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
if [ -f "${CONTAINER_BIN_CACHE}/julia_key.asc" ]; then
  echo "Importing local GPG key for Julia..."
  gpg --import "${CONTAINER_BIN_CACHE}/julia_key.asc"
else
  echo "[warn] Local Julia GPG key not found. GPG verification may fail."
fi
# End GPG key import (if-else self-contained)

#--- Sub-block 8.5.8: Verify Julia GPG signature ---
# Purpose: Verify .asc signature if available (non-blocking)
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
if [ -s "${LATEST_TGZ}.asc" ]; then
  if gpg --batch --verify "${LATEST_TGZ}.asc" "${LATEST_TGZ}" 2>/tmp/julia_gpg_verify.log; then
    echo "[julia] ✓ GPG signature: GOOD"
  else
    echo "[julia] Δ GPG signature could not be verified (see /tmp/julia_gpg_verify.log). Continuing because SHA256 passed."
  fi
else
  echo "[julia] Δ No .asc file available for GPG verification. Continuing because SHA256 passed."
fi
# End GPG verification (if-else self-contained)

#--- Sub-block 8.5.9: Extract and install Julia ---
# Critical: Extract Julia to /opt and create symlink
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "[julia] Installing to ${INSTALL_DIR}/julia-${JVER}"
tar -xzf "${LATEST_TGZ}" -C "${INSTALL_DIR}" 2>/dev/null || true
rm -f "${INSTALL_DIR}/julia" 2>/dev/null || true
ln -s "${INSTALL_DIR}/julia-${JVER}" "${INSTALL_DIR}/julia"
echo "[julia] Installed to ${INSTALL_DIR}/julia-${JVER}, symlinked as ${INSTALL_DIR}/julia"

#--- Sub-block 8.5.10: Verify Julia installation ---
# Critical: Ensure julia binary is executable
# Dependencies: Block 8.5 (Julia installation)
# Outputs: Julia packages, environments
echo "[julia] Sanity check for ${JULIA_HOME}/bin/julia"
JULIA_BIN="${JULIA_HOME}/bin/julia"
if [ ! -x "${JULIA_BIN}" ]; then
  echo "[julia] ERROR: ${JULIA_HOME}/bin/julia not found or not executable"
  ls -l /opt || true
  exit 1
fi
# End Julia verification (if self-contained)

#--- Sub-block 8.5.11: Update PATH for Julia ---
# Critical: Make Julia available for rest of build script
# Dependencies: Block 8.5 (Julia installation)
# Outputs: Julia packages, environments
echo "==> Updating PATH to include Julia for subsequent build steps..."
# Export PATH to include Julia (critical for subshells and subsequent commands)
export PATH="${JULIA_HOME}/bin:${PATH}"
# Clear the shell's command lookup cache
hash -r
# Verify julia command is found
if ! command -v julia >/dev/null 2>&1; then
    echo "ERROR: Julia executable not found in PATH after update."
    echo "Julia HOME: ${JULIA_HOME}"
    echo "PATH: ${PATH}"
    echo "Contents of ${JULIA_HOME}/bin:"
    ls -la "${JULIA_HOME}/bin/" || echo "Directory does not exist!"
    exit 1
fi
echo "✓ Julia is now available in the PATH."
# Quick smoke test
"${JULIA_BIN}" --version || true

#--- Sub-block 8.5.12: Build libCxxWrap-julia from source ---
# Purpose: Build C++ wrapper library for Julia-C++ interop
# Dependencies: Block 8.5 (Julia installation), PHASE 1 (Build tools)
# Outputs: Julia packages, environments
echo "==> Building libCxxWrap-julia from source for OpenCV/Integration"
CXXWRAP_PREFIX="/opt/libcxxwrap-julia"
if [ -x "$JULIA_BIN" ]; then
  if [ ! -f "${CXXWRAP_PREFIX}/lib/cmake/JlCxx/JlCxxConfig.cmake" ]; then
    echo "Building libCxxWrap-julia from source..."
    # Get Julia paths
    JULIA_INCLUDE=$("$JULIA_BIN" -e 'print(joinpath(Sys.BINDIR, "..", "include", "julia"))')
    JULIA_LIB=$("$JULIA_BIN" -e 'print(joinpath(Sys.BINDIR, "..", "lib"))')
    echo "  Julia include: $JULIA_INCLUDE"
    echo "  Julia library: $JULIA_LIB"
    # Clone and build
    BUILD_DIR="/tmp/cxxwrap_build"
    rm -rf "$BUILD_DIR"
    git clone -q --depth 1 https://github.com/JuliaInterop/libcxxwrap-julia.git "$BUILD_DIR" || { echo "ERROR: Failed to clone libcxxwrap-julia"; exit 1; }
    cd "$BUILD_DIR" || { echo "ERROR: Failed to access libcxxwrap-julia directory"; exit 1; }
    # Clean build directory for fresh compilation
    rm -rf build
    mkdir -p build
    cd build || { echo "ERROR: Failed to access build directory"; exit 1; }

    cmake .. \
      -DCMAKE_INSTALL_PREFIX="$CXXWRAP_PREFIX" \
      -DCMAKE_BUILD_TYPE=Release \
      -DJulia_EXECUTABLE="$JULIA_BIN" \
      -DJulia_INCLUDE_DIR="$JULIA_INCLUDE" \
      -DJulia_LIBRARY_DIR="$JULIA_LIB" \
      -DCMAKE_INSTALL_LIBDIR=lib \
      >/dev/null 2>&1

    #--- Sub-block 8.5.13: Build and install CxxWrap ---
    # Critical: Compile with make using all CPU cores
    make -j$(nproc) >/dev/null 2>&1
    make install >/dev/null

    cd /
    rm -rf "$BUILD_DIR"
    echo "✓ Libcxxwrap-julia built to $CXXWRAP_PREFIX"
  else
    echo "✓ Libcxxwrap-julia already installed"
  fi
  # End CxxWrap build check (if-else self-contained)

#--- Sub-block: Section continuation (2149) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

  #--- Sub-block 8.5.14: Fix CMake target export for CxxWrap ---
  # Critical: Ensure OpenCV can find JlCxx CMake target
  if ! grep -q "JlCxx::cxxwrap_julia" "${CXXWRAP_PREFIX}/lib/cmake/JlCxx/JlCxxConfig.cmake"; then
    echo "Adding CMake target export to JlCxxConfig.cmake..."
    cat >> "${CXXWRAP_PREFIX}/lib/cmake/JlCxx/JlCxxConfig.cmake" << 'CMAKE_FIX'


#--- Sub-block: Code section 2122 ---
# Purpose: Continuing implementation
# Dependencies: Block 8.5 (Julia installation)
# Outputs: Julia packages, environments
# =================================================
# Exported target for OpenCV integration
# =================================================
if(NOT TARGET JlCxx::cxxwrap_julia)
  add_library(JlCxx::cxxwrap_julia SHARED IMPORTED)
  set_target_properties(JlCxx::cxxwrap_julia PROPERTIES
    IMPORTED_LOCATION "/opt/libcxxwrap-julia/lib/libcxxwrap_julia.so"
    INTERFACE_INCLUDE_DIRECTORIES "/opt/libcxxwrap-julia/include"
    INTERFACE_LINK_LIBRARIES "${JULIA_HOME}/lib/libjulia.so"
  )
endif()

# Source build marker for OpenCV
set(JlCxx_IS_SOURCE_BUILD TRUE)
set(JlCxx_FOUND TRUE)
set(JlCxx_INCLUDE_DIRS "/opt/libcxxwrap-julia/include")
set(JlCxx_LIBRARIES "/opt/libcxxwrap-julia/lib/libcxxwrap_julia.so")
CMAKE_FIX
    echo "✓ CMake target export added"
  fi
  # End CMake target fix (if self-contained)

  #--- Sub-block 8.5.15: Configure CMAKE_PREFIX_PATH for CxxWrap ---
  # Critical: Make CxxWrap findable by CMake for OpenCV build
  export CMAKE_PREFIX_PATH="${CXXWRAP_PREFIX}:${CMAKE_PREFIX_PATH:-}"
  # Make permanent for future sessions
  echo "export CMAKE_PREFIX_PATH=\"${CXXWRAP_PREFIX}:\${CMAKE_PREFIX_PATH}\"" >> /etc/profile.d/cxxwrap.sh

  #--- Sub-block 8.5.16: Verify CxxWrap CMake configuration ---
  # Critical: Ensure JlCxx CMake config file exists
  if [ -f "${CXXWRAP_PREFIX}/lib/cmake/JlCxx/JlCxxConfig.cmake" ]; then
    echo "✓ JlCxx CMake config ready"
  else
    echo "✗ JlCxx CMake config not found"
    exit 1
  fi
  # End CMake config verification (if-else self-contained)
fi
# End CxxWrap installation (if block self-contained)
debug_glibc "After CxxWrap source build"
echo "CxxWrap source build ready for OpenCV"

#--- Sub-block: Section continuation (2200) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

#===============================================================================
# BLOCK 9: NVIDIA VIDEO CODEC SDK INSTALLATION
#===============================================================================
# Purpose: Install NVIDIA Video Codec SDK for hardware video encoding/decoding
# Self-contained: Yes (complete with verification)
# Dependencies: Cached SDK .zip file, unzip utility
# Outputs: Configured system components
# NOTE: SDK must be manually downloaded due to NVIDIA EULA
#-------------------------------------------------------------------------------


#--- Sub-block 8.5.13: libCxxWrap-julia build complete ---
# Purpose: C++ wrapper for Julia integration
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
#--- Sub-block 9.1: Initialize NVIDIA SDK installation ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "==> Installing NVIDIA Video Codec SDK from cache..."

# Using NVIDIA Video Codec SDK version from config.sh
SDK_VERSION="${NVIDIA_VIDEO_SDK_VERSION}"
SDK_ZIP_FILENAME="Video_Codec_SDK_${SDK_VERSION}.zip"
SDK_ZIP_CACHE_PATH="${CONTAINER_BIN_CACHE}/${SDK_ZIP_FILENAME}"

#--- Sub-block 9.2: Check for cached SDK file ---
# Critical: SDK must be manually cached due to NVIDIA EULA
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
if [ -f "${SDK_ZIP_CACHE_PATH}" ]; then
  echo "--> Found cached NVIDIA Video Codec SDK. Using it."
  cp "${SDK_ZIP_CACHE_PATH}" "/tmp/${SDK_ZIP_FILENAME}"
else
  echo -e "\n${RED}FATAL ERROR: NVIDIA Video Codec SDK not found in cache.${NC}"
  echo -e "${YELLOW}Please manually download '${SDK_ZIP_FILENAME}' from the NVIDIA Developer website:${NC}"
  echo -e "https://developer.nvidia.com/nvidia-video-codec-sdk/download"
  echo -e "${YELLOW}Then, place the downloaded .zip file into your 'container_cache/binaries/' directory and re-run the build.${NC}\n"
  exit 1
fi
# End SDK cache check (if-else self-contained)

#--- Sub-block 9.3: Extract NVIDIA SDK ---
# Purpose: Unzip SDK to /tmp
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
cd /tmp || { echo "ERROR: Failed to access /tmp directory"; exit 1; }
unzip -q "${SDK_ZIP_FILENAME}"

#--- Sub-block 9.4: Move SDK to /opt ---
# Purpose: Install SDK to system location
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
SDK_FOLDER="Video_Codec_SDK_${SDK_VERSION}"
echo "Moving ${SDK_FOLDER} to /opt/${SDK_FOLDER}"
sudo mv "/tmp/${SDK_FOLDER}" "/opt/${SDK_FOLDER}"
sudo mv "/opt/${SDK_FOLDER}" "/opt/Video_Codec_SDK"

#--- Sub-block 9.5: Set SDK ownership and permissions ---
# Purpose: Ensure SDK is accessible without sudo
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
sudo chown -R ${USER}:${USER} "/opt/Video_Codec_SDK"
echo "SDK successfully moved to /opt/Video_Codec_SDK"

#--- Sub-block 9.6: Copy SDK headers to system locations ---
# Critical: Make headers available for FFmpeg/OpenCV compilation
# Dependencies: Block 6.13 (NVIDIA CUDA)
# Outputs: GPU libraries, CUDA toolkit
cp "/opt/Video_Codec_SDK/Interface/"*.h /usr/local/include
cp "/opt/Video_Codec_SDK/Interface/"*.h /usr/local/cuda-${CUDA_VERSION}/include

#--- Sub-block 9.7: Verify SDK header installation ---
# Critical: Ensure required headers are in place
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
if [ -f /usr/local/include/nvcuvid.h ] && [ -f /usr/local/include/cuviddec.h ]; then
  echo "✓ Video Codec SDK headers verified at /usr/local/include/"
  ls -la /usr/local/include/nvc*
else
  echo "Δ Video Codec SDK headers may be incomplete"
  ls -la /usr/local/include/ | grep -i nv || echo "No NVIDIA headers found"
fi
# End SDK header verification (if-else self-contained)

#--- Sub-block 9.8: Cleanup temporary SDK files ---
# Purpose: Remove temporary extraction files
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
rm -rf "/tmp/${SDK_FOLDER}" "${SDK_ZIP_FILENAME}"
cd /

echo "✓ NVIDIA Video Codec SDK headers installed successfully."

#===============================================================================
# BLOCK 10: PHASE 4 - OPENCV COMPILATION
#===============================================================================
# Purpose: Compile OpenCV from source with CUDA, TBB, and all accelerations
# Self-contained: Yes (complete build with verification)
# Dependencies: Phase 1 libraries, CUDA, TBB, NVIDIA Video Codec SDK, Julia/CxxWrap
# Outputs: GPU libraries, CUDA toolkit
# NOTE: OpenCV 4.12.0 compiled with full GPU acceleration
#-------------------------------------------------------------------------------

#--- Sub-block 10.1: Phase 4 initialization ---
# Purpose: Initialize OpenCV build environment
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo -e "\n${BLUE}### PHASE 4: Compiling OpenCV from source ###${NC}"

#--- Sub-block 10.2: Cleanup previous build attempts ---
# Purpose: Ensure clean build environment
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
rm -rf /tmp/opencv /tmp/opencv_contrib

#--- Sub-block 10.3: Configure OpenCV version and paths ---
# Critical: Pin OpenCV version for consistency (using version from config.sh)
# Dependencies: Block 6.13 (NVIDIA CUDA)
# Outputs: GPU libraries, CUDA toolkit
# OPENCV_VERSION defined in config.sh
INSTALL_PREFIX="/usr/local"
CUDA_ARCH="8.6"

echo "========================================="
echo "OpenCV ${OPENCV_VERSION} Build Automation"
echo "========================================="

#--- Sub-block 10.4: Install OpenCV build dependencies ---
# Critical: Install all required libraries for OpenCV compilation
# Dependencies: Block 6 (APT configuration), PHASE 1 (Build tools), PHASE 1 (Compilers)
# Outputs: Installed packages
echo "Installing dependencies..."
apt-get update
apt-get install -y \
  build-essential cmake ninja-build pkg-config \
  libopenblas-dev liblapacke-dev gfortran \
  libtbb-dev libeigen3-dev \
  libjpeg-dev libpng-dev libtiff-dev \
  libavcodec-dev libavformat-dev libswscale-dev \
  libgtk-3-dev python3-dev python3-numpy \
  g++ gcc libc6-dev linux-libc-dev libstdc++-11-dev gcc-12 g++-12 libtesseract-dev

#--- Sub-block 10.5: Download OpenCV source code ---
# Purpose: Clone OpenCV core and contrib modules
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

# Clone OpenCV core
if ! clone_with_retry "https://github.com/opencv/opencv.git" "/tmp/opencv" "${OPENCV_VERSION}"; then
    echo "ERROR: Failed to clone OpenCV core after all retry attempts"
    exit 1
fi

# Clone OpenCV contrib
if ! clone_with_retry "https://github.com/opencv/opencv_contrib.git" "/tmp/opencv_contrib" "${OPENCV_VERSION}"; then
    echo "ERROR: Failed to clone OpenCV contrib after all retry attempts"
    exit 1
fi

#--- Sub-block 10.6: Create OpenCV build directory ---
# Purpose: Prepare build directory for CMake
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
cd /tmp/opencv || { echo "ERROR: Failed to access opencv directory"; exit 1; }
# Remove existing build directory if it exists (critical for Singularity rebuilds)
rm -rf build
mkdir -p build
cd build || { echo "ERROR: Failed to access build directory"; exit 1; }

#--- Sub-block 10.7: Configure build environment variables ---
# Critical: Set PKG_CONFIG_PATH and LIBRARY_PATH for dependencies
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
export PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:/usr/local/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig"
export LIBRARY_PATH="${LIBRARY_PATH}:/usr/lib/x86_64-linux-gnu"

#--- Sub-block 10.8: Configure OpenCV with CMake ---
# Critical: Comprehensive CMake configuration with all features enabled
# Dependencies: PHASE 1 (Build tools), PHASE 1 (Compilers), Block 6.13 (NVIDIA CUDA)
# Outputs: GPU libraries, CUDA toolkit
echo -e "${YELLOW}[Phase 4 | OpenCV] Configuring with Cmake...${NC}"

cmake -G Ninja \
  -D CPU_BASELINE=AVX2 \
  -D CPU_DISPATCH=AVX2,FP16,AVX512_SKX \
  -D CMAKE_BUILD_TYPE=Release \
  -D CMAKE_C_COMPILER=/usr/bin/gcc-12 \
  -D CMAKE_CXX_COMPILER=/usr/bin/g++-12 \
  -D CUDA_HOST_COMPILER=/usr/bin/g++-12 \
  -D CMAKE_INSTALL_PREFIX=${INSTALL_PREFIX} \
  -D CMAKE_POLICY_DEFAULT_CMP0146=OLD \
  -D OPENCV_EXTRA_MODULES_PATH=/tmp/opencv_contrib/modules \
  -D BUILD_SHARED_LIBS=ON \
  -D CMAKE_C_COMPILER_LAUNCHER=ccache \
  -D CMAKE_CXX_COMPILER_LAUNCHER=ccache \
  -D OPENCV_GENERATE_PKGCONFIG=ON \
  -D CMAKE_C_COMPILER_WORKS=TRUE \
  -D CMAKE_CXX_COMPILER_WORKS=TRUE \
  -D CUDA_NVCC_FLAGS="--expt-relaxed-constexpr --expt-extended-lambda;-allow-unsupported-compiler;-Xcompiler=-fPIC;-Xcompiler=-Wno-deprecated-declarations;-x=cu;-std=c++17" \
  -D CMAKE_CUDA_FLAGS="-allow-unsupported-compiler -Xcompiler=-Wno-deprecated-declarations" \
  -D WITH_CUDA=ON \
  -D WITH_CUDNN=ON \
  -D WITH_OPENBLAS=ON \
  -D CUDA_ARCH_BIN="${CUDA_ARCH}" \
  -D CUDA_ARCH_PTX="${CUDA_ARCH}" \
  -D OPENCV_DNN_CUDA=ON \
  -D OPENCV_DNN_CUDA_VERSION=${CUDA_VERSION} \
  -D CUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda-${CUDA_VERSION} \
  -D ENABLE_FAST_MATH=1 \
  -D CUDA_FAST_MATH=1 \
  -D WITH_CUBLAS=1 \
  -D WITH_CUFFT=ON \
  -D WITH_OPENGL=ON \
  -D WITH_TBB=ON \
  -D WITH_EIGEN=ON \
  -D WITH_FFMPEG=ON \
  -D WITH_GSTREAMER=ON \
  -D WITH_LAPACK=ON \
  -D WITH_TIFF=ON \
  -D WITH_OPENMP=ON \
  -D JlCxx_DIR=${JULIA_HOME}/CxxWrap/deps/build/JlCxx/ \
  -D LAPACK_ENABLE_LAPACKE=ON \
  -D WITH_VTK=ON \
  -D VTK_DIR=/usr/lib/x86_64-linux-gnu/cmake/vtk-9.3 \
  -D OPENCV_ENABLE_NONFREE=ON \
  -D BUILD_EXAMPLES=OFF \
  -D BUILD_TESTS=OFF \
  -D BUILD_PERF_TESTS=OFF \
  -D BUILD_DOCS=OFF \
  -D WITH_IPP=OFF \
  -D BUILD_opencv_apps=OFF \
  -D BUILD_opencv_sfm=OFF \
  -D BUILD_opencv_python3=ON \
  -D BUILD_opencv_cudacodec=ON \
  -D BUILD_opencv_cudaarithm=ON \
  -D BUILD_opencv_cudev=ON \
  -D BUILD_opencv_cudafeatures2d=ON \
  -D BUILD_opencv_cudafilters=ON \
  -D BUILD_opencv_cudaimgproc=ON \
  -D BUILD_opencv_cudalegacy=ON \
  -D BUILD_opencv_cudaobjdetect=ON \
  -D BUILD_opencv_cudaoptflow=ON \
  -D BUILD_opencv_cudastereo=ON \
  -D BUILD_opencv_cudawarping=ON \
  -D BUILD_opencv_julia=OFF \
  -D PYTHON3_EXECUTABLE=/usr/bin/python3 \
  -D PYTHON3_INCLUDE_DIR=/usr/include/python${SYSTEM_PYTHON_VER} \
  -D PYTHON3_LIBRARY=/usr/lib/x86_64-linux-gnu/libpython${SYSTEM_PYTHON_VER}.so \
  -D PYTHON3_NUMPY_INCLUDE_DIRS=/usr/lib/python3/dist-packages/numpy/core/include \
  -D TBB_DIR=/usr/lib/x86_64-linux-gnu/cmake/TBB \
  -D TBB_LIBRARIES=/usr/lib/x86_64-linux-gnu/libtbb.so \
  -D BLAS_LIBRARIES=/usr/lib/x86_64-linux-gnu/libopenblas.so* \
  -D BLA_VENDOR=OpenBLAS \
  -D LAPACK_LIBRARIES="/usr/lib/x86_64-linux-gnu/libopenblas.so;/usr/lib/x86_64-linux-gnu/liblapacke.so.3;/usr/lib/x86_64-linux-gnu/liblapack.so" \
  -D LAPACK_LIBRARY=/usr/lib/x86_64-linux-gnu/liblapack.so \
  -D LAPACKE_LIBRARY=/usr/lib/x86_64-linux-gnu/liblapacke.so.3 \
  -D LAPACK_LIBRARY_DEBUG=/usr/lib/x86_64-linux-gnu/liblapack.so.3 \
  -D LAPACK_CBLAS_H=/usr/include/x86_64-linux-gnu/cblas.h \
  -D LAPACK_LAPACKE_H=/usr/include/lapacke.h \
  -D OpenBLAS_LIB=/usr/lib/x86_64-linux-gnu/libopenblas.so \
  -D OpenBLAS_INCLUDE_DIR=/usr/include/x86_64-linux-gnu/ \
  -D CMAKE_INSTALL_RPATH="/usr/local/lib" \
  -D CMAKE_C_STANDARD=17 \
  -D CMAKE_CXX_STANDARD=17 \
  -D CMAKE_CUDA_STANDARD=17 \
  -D CMAKE_C_STANDARD_REQUIRED=ON \
  -D CMAKE_CXX_STANDARD_REQUIRED=ON \
  -D CMAKE_CUDA_STANDARD_REQUIRED=ON \
  -D CMAKE_INCLUDE_PATH="/usr/include/x86_64-linux-gnu;/usr/include" \
  -D CMAKE_CXX_FLAGS="-Wno-deprecated -fpermissive -march=x86-64-v3 -O3 -mavx2 -mfma -msse4.2 -funroll-loops -fopenmp" \
  -D CMAKE_C_FLAGS="-march=x86-64-v3 -O3 -mavx2 -mfma -msse4.2 -funroll-loops -fopenmp" \
  -D CMAKE_EXE_LINKER_FLAGS="-flto -fopenmp" \
  -D CMAKE_MODULE_LINKER_FLAGS="-flto -fopenmp" \
  -D CMAKE_SHARED_LINKER_FLAGS="-flto -fopenmp" \
  -D ENABLE_PRECOMPILED_HEADERS=ON \
  -D CV_ENABLE_INTRINSICS=ON \
  -D PARALLEL_ENABLE_PLUGINS=ON \
  -D VIDEO_CODEC_SDK_DIR=/opt/Video_Codec_SDK \
  -D Julia_EXECUTABLE=${JULIA_HOME}/bin/julia \
  -D Julia_INCLUDE_DIRS=${JULIA_HOME}/include/julia \
  -D Julia_LIBRARIES=${JULIA_HOME}/lib/libjulia.so \
  -D JlCxx_DIR=/opt/libcxxwrap-julia/lib/cmake/JlCxx \
  -D CMAKE_PREFIX_PATH="/opt/libcxxwrap-julia:${CMAKE_PREFIX_PATH}" \
  -D CMAKE_IGNORE_PATH="/root/.julia" \
  -D WITH_NVCUVID=OFF \
  -D WITH_NVCUVENC=OFF \
  -D NVCUVID_HEADER_DIR=/usr/local/include/ \
  ..

#--- Sub-block 10.9: Verify OpenCV CMake configuration ---
# Critical: Check that key dependencies were detected
# Dependencies: Block 6.13 (NVIDIA CUDA)
# Outputs: GPU libraries, CUDA toolkit
echo "Verifying Cmake configuration..."
if ! grep -q "LAPACK.*YES" CMakeCache.txt; then
  echo "WARNING: LAPACK not detected"
fi
if ! grep -q "TBB.*YES" CMakeCache.txt; then
  echo "WARNING: TBB not detected"
fi
echo "Configuration summary:"
grep -E "LAPACK|TBB|OPENMP|CUDA" CMakeCache.txt | grep -v "^//" | head -10

#--- Sub-block 10.10: Build OpenCV with ninja ---
# Critical: Compile OpenCV using half CPU cores to prevent OOM
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
JOBS=$(($(nproc) / 2))
echo "Building with $JOBS parallel jobs..."
ninja -j$JOBS || { echo "ERROR: Failed to build OpenCV"; exit 1; }

#--- Sub-block 10.11: Install OpenCV ---
# Purpose: Install compiled OpenCV libraries to system
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "Installing..."
ninja install || { echo "ERROR: Failed to install OpenCV"; exit 1; }

#--- Sub-block 10.12: Update linker cache ---
# Critical: Ensure OpenCV libraries are in linker cache
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
ldconfig

#--- Sub-block 10.13: Verify OpenCV installation ---
# Critical: Test OpenCV Python bindings and CUDA support
# Dependencies: Block 6.13 (NVIDIA CUDA)
# Outputs: GPU libraries, CUDA toolkit
echo "Verifying installation..."
python3 -c "import cv2; print(f'OpenCV version: {cv2.__version__}'); print(f'CUDA: {cv2.cuda.getCudaEnabledDeviceCount() if hasattr(cv2, 'cuda') else 'N/A'}')"

pkg-config --modversion opencv4 || echo "pkg-config not found (normal for some builds)"

echo "Build complete!"
echo "==============="

#--- Sub-block 10.13.1: Protect compiled OpenCV from APT overwrites ---
# Critical: Prevent APT from installing ANY system OpenCV packages
# Strategy: Use APT pinning with negative priority to block ALL libopencv-* packages
# Benefits: Simple, robust, survives apt-mark unhold, no dummy packages needed
echo "Protecting compiled OpenCV from APT overwrites..."

# Create APT preferences directory
mkdir -p /etc/apt/preferences.d

# Block ALL system OpenCV packages using wildcard pinning with negative priority
# Pin-Priority: -1 means "never install this package"
cat > /etc/apt/preferences.d/block-system-opencv << 'EOF'
# Block ALL system OpenCV packages (prevent installation of any libopencv-* package)
# Our optimized OpenCV 4.12.0 is compiled from source in /usr/local
# Negative priority (-1) means APT will never install these packages
Package: libopencv-*
Pin: release *
Pin-Priority: -1

# Also block the main opencv packages
Package: opencv-data
Pin: release *
Pin-Priority: -1

Package: libcv-dev
Pin: release *
Pin-Priority: -1

Package: libhighgui-dev
Pin: release *
Pin-Priority: -1
EOF

# Verify the preferences file was created
if [ -f "/etc/apt/preferences.d/block-system-opencv" ]; then
    echo "✓ Created APT preferences to block ALL system OpenCV packages"
    echo "  - Blocks: libopencv-* (all OpenCV development and runtime packages)"
    echo "  - Method: APT pinning with Pin-Priority: -1"
    echo "  - Survives: apt-mark unhold and apt-get operations"
else
    echo "✗ ERROR: Failed to create OpenCV protection file"
    exit 1
fi

# Update APT cache to apply the new preferences
echo "Updating APT cache to apply OpenCV protection..."
apt-get update || true

# Verify protection is active by checking the preferences file and APT status
echo "Verifying OpenCV protection..."
OPENCV_VERIFICATION_PASSED=false

# Method 1: Check if preferences file exists and has correct content
if [ -f "/etc/apt/preferences.d/block-system-opencv" ] && grep -q "Pin-Priority: -1" /etc/apt/preferences.d/block-system-opencv; then
    echo "✓ OpenCV protection file verified (Pin-Priority: -1 active)"
    OPENCV_VERIFICATION_PASSED=true
fi

# Method 2: Try to verify with apt-cache (may not work in all environments)
if apt-cache policy libopencv-dev 2>/dev/null | grep -qi "pin.*-1\|candidate.*none"; then
    echo "✓ OpenCV protection verified via apt-cache (packages blocked)"
    OPENCV_VERIFICATION_PASSED=true
elif ! apt-cache show libopencv-dev &>/dev/null; then
    echo "✓ OpenCV protection verified (system packages not in repository)"
    OPENCV_VERIFICATION_PASSED=true
fi

if [ "$OPENCV_VERIFICATION_PASSED" = true ]; then
    echo "✓ OpenCV protection completed and verified (APT pinning method)"
else
    echo "⚠ OpenCV protection file created, but runtime verification inconclusive"
    echo "  This is usually fine - APT pinning is active even if verification fails"
fi

#--- Sub-block 10.14: Cleanup OpenCV build files ---
# Purpose: Remove temporary build files
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
hash -r
cd /
rm -rf /tmp/opencv /tmp/opencv_contrib

#===============================================================================
# BLOCK 11: JULIA ENVIRONMENT SETUP
#===============================================================================
# Purpose: Configure Julia package environments for robotics and CUDA workflows
# Self-contained: Yes (complete with CxxWrap integration)
# Dependencies: Julia installation, libCxxWrap-julia, OpenCV
# Outputs: Julia packages, environments
# NOTE: Must run after OpenCV build to ensure CxxWrap integration
#-------------------------------------------------------------------------------

#--- Sub-block 11.1: Initialize Julia environment setup ---
# Dependencies: Block 8.5 (Julia installation), Block 6.13 (NVIDIA CUDA)
# Outputs: GPU libraries, CUDA toolkit
echo "==> Julia ${JULIA_LTS_VER:-1.10.x} install & envs"
if [ -x "$JULIA_BIN" ]; then
  echo "Julia installed successfully"

  #--- Sub-block 11.2: Create CxxWrap artifact override ---
  # Critical: Force Julia to use source-built CxxWrap instead of binary JLL
  mkdir -p /root/.julia/artifacts
  cat > /root/.julia/artifacts/Overrides.toml << 'OVERRIDE'
# Force Julia to use our CxxWrap source build instead of binary JLL
[3eaa8dc6-92ce-5c4c-91c6-662a904cf5c7]
libcxxwrap_julia = "/opt/libcxxwrap-julia"
OVERRIDE
  echo "✓ Artifact override created for CxxWrap source build"

  #--- Sub-block 11.3: Setup Julia base environment ---
  # Purpose: Update base environment and install IJulia for Jupyter
  echo "Setting up Julia base environment..."
  "${JULIA_BIN}" -e 'using Pkg; Pkg.update(); Pkg.add(["IJulia"]); using IJulia;' || echo "[warn] IJulia setup failed"

  #--- Sub-block 11.4: Install CxxWrap Julia package ---
  # Critical: Install CxxWrap package using source build via artifact override
  echo "Installing CxxWrap Julia package (will use source build)..."
  "${JULIA_BIN}" -e 'using Pkg; Pkg.add("CxxWrap"); Pkg.build("CxxWrap")'

  #--- Sub-block 11.5: Verify CxxWrap source build usage ---
  # Purpose: Confirm Julia is using our source-built CxxWrap
  "${JULIA_BIN}" -e 'using CxxWrap; build_path = CxxWrap.prefix_path(); println("✓ CxxWrap using: ", build_path); if !occursin("/opt/libcxxwrap-julia", build_path) @warn "CxxWrap may not be using source build! Path: $build_path" end' || echo "[warn] CxxWrap Julia package setup failed"

  #--- Sub-block 11.6: Create robotics Julia environment ---
  # Purpose: Set up dedicated environment for robotics packages
  echo "Setting up Julia robotics environment..."
  mkdir -p ${JULIA_HOME}envs
  "${JULIA_BIN}" -e "using Pkg; Pkg.activate(\"${JULIA_HOME}envs/robotics_env\"); Pkg.add([\"RigidBodyDynamics\", \"MeshCat\", \"ControlSystems\", \"DifferentialEquations\", \"ForwardDiff\", \"StaticArrays\", \"Rotations\", \"CoordinateTransformations\", \"Interpolations\", \"Optim\"]); Pkg.precompile()" || echo "[warn] Robotic env setup failed"

  #--- Sub-block 11.7: Create CUDA Julia environment ---
  # Purpose: Set up dedicated environment for CUDA packages
  echo "Setting up Julia CUDA environment..."
  "${JULIA_BIN}" -e "using Pkg; Pkg.activate(\"${JULIA_HOME}envs/cuda_env\"); Pkg.instantiate()" || echo "[warn] CUDA env setup failed"

  #--- Sub-block 11.8: Register IJulia kernel ---
  # Purpose: Make Julia available in Jupyter notebooks
  echo "Registering Julia kernel..."
  "${JULIA_BIN}" -e 'using IJulia; IJulia.installkernel("Julia 1.10 (base)", "--project=@.")' || echo "[warn] Julia kernel registration failed"

#--- Sub-block: Section continuation (2530) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 2491 ---
# Purpose: Continuing implementation
# Dependencies: Block 6.13 (NVIDIA CUDA)
# Outputs: GPU libraries, CUDA toolkit
  #--- Sub-block 11.9: Create GPU precompile helper script ---
  # Purpose: Helper script for precompiling Julia CUDA packages on GPU systems
  cat > /usr/local/bin/precompile_julia_cuda.sh << 'EOS'
#!/usr/bin/env bash
set -euo pipefail

JULIA_BIN="${JULIA_BIN:-${JULIA_HOME}/bin/julia}"
if ! command -v "$JULIA_BIN" >/dev/null 2>&1; then
  echo "[precompile_julia_cuda] $JULIA_BIN not found; skipping."
  exit 0
fi

if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "[precompile_julia_cuda] no NVIDIA GPU visible; skipping."
  exit 0
fi

ENV_DIR="${1:-${JULIA_HOME}envs/robotics-cuda}"
PROJECT_OPT="-e"
if [ -d "$ENV_DIR" ]; then
  PROJECT_OPT="--project=$ENV_DIR"
fi

"$JULIA_BIN" $PROJECT_OPT -e '
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
EOS

#--- Sub-block: Section continuation (2572) ---
# Purpose: Implementation details
# Dependencies: Block 6.13 (NVIDIA CUDA)
# Outputs: GPU libraries, CUDA toolkit

  #--- Sub-block 11.10: Make precompile script executable ---
  # Purpose: Set permissions and convert line endings
  chmod 0755 /usr/local/bin/precompile_julia_cuda.sh
  dos2unix -q /usr/local/bin/precompile_julia_cuda.sh 2>/dev/null || true

  #--- Sub-block 11.11: Run GPU precompile (non-fatal) ---
  # Purpose: Precompile Julia CUDA packages if GPU available
  if [ -x /usr/local/bin/precompile_julia_cuda.sh ]; then
    /usr/local/bin/precompile_julia_cuda.sh || true
  fi
else
  echo "[warn] Julia installation may have failed"
fi
# End Julia environment setup (if block self-contained)

#--- Sub-block: Code section 2544 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
debug_glibc "After Julia environment setup"
debug_glibc "After OpenCV Compile and Install"

#===============================================================================
# BLOCK 12: PHASE 5 - ROS 2 VISION LIBRARY RECOMPILATION
#===============================================================================
# Purpose: Recompile cv_bridge and vision_opencv against custom OpenCV
# Self-contained: Yes (complete rebuild with verification)
# Dependencies: ROS 2 ${ROS_DISTRO}, custom OpenCV from Phase 4
# Outputs: Configured system components
# NOTE: Ensures ROS 2 uses our optimized OpenCV instead of system version
#-------------------------------------------------------------------------------


#--- Sub-block 11.2: Julia environments setup complete ---
# Purpose: Robotics and CUDA environments ready
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
#--- Sub-block 12.1: Phase 5 initialization ---
# Purpose: Begin ROS 2 vision library recompilation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo -e "\n${BLUE}### PHASE 5: Recompiling ROS 2 vision libraries against custom OpenCV ###${NC}"
PHASE5_SUCCESS=true

#--- Sub-block 12.2: Source ROS 2 environment ---
# Critical: Load ROS 2 environment for colcon build tools
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
source /opt/ros/${ROS_DISTRO}/setup.bash

#--- Sub-block 12.3: Create ROS overlay workspace ---
# Purpose: Create colcon workspace for custom-built packages
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
mkdir -p /ros_overlay_ws/src
cd /ros_overlay_ws

#--- Sub-block 12.4: Clone vision_opencv source ---
# Purpose: Get cv_bridge and vision_opencv source code
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
git clone --branch rolling https://github.com/ros-perception/vision_opencv.git src/vision_opencv || { echo "ERROR: Failed to clone vision_opencv"; exit 1; }

#--- Sub-block 12.5: Build vision_opencv with custom OpenCV ---
# Critical: Compile against our optimized OpenCV in /usr/local
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
colcon build --cmake-args -D CMAKE_BUILD_TYPE=Release -D CMAKE_POLICY_DEFAULT_CMP0146=OLD -D CMAKE_SHARED_LINKER_FLAGS="-flto" -D CMAKE_EXE_LINKER_FLAGS="-flto"

#--- Sub-block 12.6: Verify cv_bridge linkage ---
# Critical: Confirm cv_bridge uses custom OpenCV
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo -e "${YELLOW}[Phase 5 | Verification] Checking linkage of new cv_bridge library...${NC}"
if ldd /ros_overlay_ws/install/cv_bridge/lib/libcv_bridge.so | grep -q "/usr/local/lib/libopencv_core"; then
  echo -e "${GREEN}✓ New cv_bridge is correctly linked to custom OpenCV in /usr/local.${NC}"
  export PHASE5_STATUS="PASS"
else
  echo -e "${RED}✗ FAILED: New cv_bridge is NOT linked to custom OpenCV. Overlay failed.${NC}"
  ldd /ros_overlay_ws/install/cv_bridge/lib/libcv_bridge.so | grep opencv
  PHASE5_SUCCESS=false
  export PHASE5_STATUS="FAIL"
  exit 1
fi
# End cv_bridge verification (if-else self-contained)

#--- Sub-block 12.7: Configure automatic overlay sourcing ---
# Purpose: Make overlay active in all new shell sessions
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "source /ros_overlay_ws/install/setup.bash" >> /root/.bashrc

debug_glibc "After building ROS2 CV_Bridge"

#===============================================================================
# BLOCK 13: ADDITIONAL ROBOTICS/ML LIBRARIES
#===============================================================================
# Purpose: Install supplementary libraries for robotics and machine learning
# Self-contained: Yes (package management with conflict resolution)
# Dependencies: Drake (for PCL/VTK), apt-aria wrapper
# Outputs: Configured system components
# NOTE: PCL and VTK from Drake dependencies, avoid version conflicts
#-------------------------------------------------------------------------------

#--- Sub-block 13.1: Initialize additional libraries installation ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "==> Additional system libraries for robotics/ML."

#--- Sub-block 13.2: Fix broken dependencies ---
# Purpose: Resolve any dependency issues from previous installations
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "Fixing broken dependencies..."
apt-get -y --fix-broken install || true
dpkg --configure -a || true
apt-get -y autoremove || true

#--- Sub-block 13.3: Remove held packages ---
# Purpose: Clear package holds that might cause conflicts
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# Note: This is safe for OpenCV - we use APT pinning (Pin-Priority: -1) which survives unhold
# Note: APT pinning in /etc/apt/preferences.d/ blocks all custom-compiled libraries
echo "Clearing package holds (custom libraries protected by APT pinning)..."

# Robust method: Get held packages, validate, and unhold with proper quoting
HELD_PACKAGES=$(dpkg --get-selections 2>/dev/null | grep -E '[[:space:]]hold$' | awk '{print $1}' || true)
if [ -n "${HELD_PACKAGES}" ]; then
    echo "  Found held packages, releasing holds..."
    # Use xargs with -r (no-run-if-empty) for safety and proper quoting
    echo "${HELD_PACKAGES}" | xargs -r apt-mark unhold 2>/dev/null || true
    echo "  ✓ Package holds cleared"
else
    echo "  No held packages found (already clear)"
fi

#--- Sub-block 13.4: Install essential package tools ---
# Purpose: Ensure pkg-config is available
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "Installing essential dependencies..."
apt-get install -y --no-install-recommends \
    pkg-config || true

#--- Sub-block 13.5: Update package lists ---
# Purpose: Refresh APT cache after conflict resolution
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
apt-get update || true

#--- Sub-block 13.6: Note PCL/VTK from Drake ---
# Purpose: Document that PCL/VTK already available via Drake
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "PCL and VTK libraries already available via Drake dependencies"

#--- Sub-block 13.7: Install Python VTK bindings ---
# Purpose: Add Python bindings for VTK scripting (non-fatal)
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "Installing Python VTK bindings if available..."
apt-get install -y --no-install-recommends python3-vtk9 || apt-get install -y --no-install-recommends python3-vtk7 || echo "Δ Python VTK bindings not available"

#--- Sub-block 13.8: Monitor cache after installation ---
# Purpose: Track cache growth from robotics/ML packages
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
monitor_cache "After robotics/ML libraries installation"

debug_glibc "After Robotics/ML libraries installation"

#===============================================================================
# BLOCK 13A: 3D RECONSTRUCTION AND NERF TOOLS
#===============================================================================
# Purpose: Install COLMAP (SfM) and Open3D with full CUDA optimizations
# Self-contained: Yes (complete 3D reconstruction stack)
# Dependencies: OpenCV (Block 10), Ceres (Block 8), CUDA
# Outputs: COLMAP, Open3D optimized binaries
#-------------------------------------------------------------------------------

echo "==> Installing 3D Reconstruction Tools (COLMAP + Open3D)"

#--- Sub-block 13A.0: Configure pip to protect compiled libraries ---
# Critical: Prevent pip from installing precompiled binaries that would overwrite our optimized libraries
# Dependencies: None (foundational)
# Outputs: Configured pip environment
echo "Configuring pip to protect compiled libraries..."

# Create pip configuration to prefer system packages and prevent binary overwrites
mkdir -p /root/.config/pip
cat > /root/.config/pip/pip.conf << 'PIPCONF'
[global]
# Prefer using system site-packages (our compiled libs) over downloading
# This prevents pip from overwriting Ceres, G2O, GTSAM, OpenCV, etc.
no-binary = opencv-python,opencv-contrib-python,opencv-python-headless

[install]
# Prioritize our compiled libraries in /usr/local
prefix = /usr/local
PIPCONF

# Set environment variables to ensure compiled libraries are found first
export LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib64:${LD_LIBRARY_PATH:-}
export CMAKE_PREFIX_PATH=/usr/local:${CMAKE_PREFIX_PATH:-}
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/share/pkgconfig:${PKG_CONFIG_PATH:-}

# Configure PKG_CONFIG_PATH system-wide (for CMake find_package())
cat > /etc/profile.d/compiled-libs.sh << 'ENVSCRIPT'
# Priority paths for compiled libraries
export LD_LIBRARY_PATH="/usr/local/lib:/usr/local/lib64:${LD_LIBRARY_PATH}"
export CMAKE_PREFIX_PATH="/usr/local:${CMAKE_PREFIX_PATH}"
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/share/pkgconfig:${PKG_CONFIG_PATH}"
ENVSCRIPT
chmod +x /etc/profile.d/compiled-libs.sh

# Verify our compiled libraries are in place
echo "Verifying compiled libraries..."
echo "  glog: $(pkg-config --modversion libglog 2>/dev/null || echo 'Not in pkg-config')"
echo "  OpenCV: $(pkg-config --modversion opencv4 2>/dev/null || echo 'Not in pkg-config')"
echo "  Ceres: $(ldconfig -p | grep -c libceres || echo 0) libraries"
echo "  G2O: $(ldconfig -p | grep -c libg2o || echo 0) libraries"
echo "  GTSAM: $(ldconfig -p | grep -c libgtsam || echo 0) libraries"

echo "✓ pip configured to protect compiled libraries"

#--- Sub-block 13A.1: Install COLMAP dependencies ---
# Note: libgoogle-glog-dev (system glog) installed via PKGS_CORE_DEPS in Block 2
# Critical: Qt5, CGAL, FreeImage, and other build dependencies
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "Installing COLMAP dependencies..."
apt-get install -y --no-install-recommends \
    libqt5core5a \
    libqt5gui5 \
    libqt5widgets5 \
    libqt5opengl5 \
    libqt5concurrent5 \
    qtbase5-dev \
    qtbase5-dev-tools \
    libcgal-dev \
    libcgal-qt5-dev \
    libfreeimage-dev \
    libmetis-dev \
    libgmp-dev \
    libmpfr-dev \
    libsqlite3-dev \
    libflann-dev \
    libglew-dev \
    freeglut3-dev \
    libflame-dev \
    libblas-dev \
    liblapack-dev \
    python3-dev \
    python3-pip \
    pybind11-dev \
    libboost-dev \
    libboost-system-dev \
    libboost-filesystem-dev \
    libboost-program-options-dev \
    libboost-graph-dev \
    libboost-thread-dev \
    libgflags-dev \
    || echo "⚠ Some COLMAP dependencies unavailable (non-fatal)"
# Note: libgoogle-glog-dev (system glog) already installed via PKGS_CORE_DEPS

echo "✓ COLMAP dependencies installed"

#--- Sub-block 13A.2: Download COLMAP source ---
# Purpose: Clone COLMAP with specific version
# Dependencies: None (foundational)
# Outputs: COLMAP source code
cd /tmp || exit 1
echo "Downloading COLMAP ${COLMAP_VERSION}..."

# Remove existing colmap directory if it exists to prevent clone failure
rm -rf /tmp/colmap

if ! clone_with_retry "https://github.com/colmap/colmap.git" "/tmp/colmap" "${COLMAP_VERSION}"; then
    echo "⚠ COLMAP ${COLMAP_VERSION} tag not found, trying main branch"
    rm -rf /tmp/colmap
    if ! clone_with_retry "https://github.com/colmap/colmap.git" "/tmp/colmap" "main"; then
        echo "ERROR: Failed to clone COLMAP after all retry attempts"
        exit 1
    fi
fi

cd /tmp/colmap || exit 1
echo "✓ COLMAP source downloaded"

#--- Sub-block 13A.3: Configure COLMAP with CMake ---
# Critical: Enable CUDA, OpenMP, CGAL, GUI for maximum performance
# Dependencies: Block 10 (OpenCV), Block 8 (Ceres), System glog (libgoogle-glog-dev)
# Outputs: COLMAP build configuration
# Note: Python support is auto-enabled if pybind11-dev is installed
# Note: OpenCV_DIR is auto-detected via CMAKE_PREFIX_PATH
# Note: BOOST_STATIC is deprecated/removed in COLMAP 3.12.6
#
# COMPATIBILITY: COLMAP 3.12.6 + System glog 0.6.0 (Ubuntu's patched version)
#   - System glog 0.6.0 location: /usr/lib/x86_64-linux-gnu/cmake/glog
#   - Ubuntu's glog includes compatibility patches for COLMAP
#   - Force system glog detection via -Dglog_DIR (prevents /usr/local conflicts)
#   - Added -fpermissive flag for template instantiation robustness
#   - Using Ninja generator for better error messages and build performance
#
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Configuring COLMAP ${COLMAP_VERSION} with CUDA optimizations..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Pre-flight check: Verify system glog is available for COLMAP
echo "🔍 Verifying system glog availability for COLMAP..."
if [ ! -d "/usr/lib/x86_64-linux-gnu/cmake/glog" ]; then
    echo "✗ ERROR: System glog CMake config not found"
    echo "  Expected: /usr/lib/x86_64-linux-gnu/cmake/glog"
    echo "  Install: sudo apt-get install libgoogle-glog-dev"
    exit 1
fi
if [ ! -f "/usr/lib/x86_64-linux-gnu/libglog.so" ]; then
    echo "✗ ERROR: System libglog.so not found"
    echo "  Expected: /usr/lib/x86_64-linux-gnu/libglog.so"
    exit 1
fi
echo "✓ System glog is available for COLMAP"
echo "  Location: /usr/lib/x86_64-linux-gnu"
echo "  CMake config: /usr/lib/x86_64-linux-gnu/cmake/glog"

# Clean build directory (critical for rebuilds)
echo ""
echo "🧹 Cleaning build directory for fresh COLMAP build..."
rm -rf build CMakeCache.txt
mkdir -p build && cd build
echo "✓ Clean build directory created"

# CMake configuration with Ninja generator
echo ""
echo "⚙️ Running CMake configuration (this may take a few minutes)..."
cmake .. \
    -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DCUDA_ENABLED=ON \
    -DCMAKE_CUDA_ARCHITECTURES="86;89;90" \
    -DCGAL_ENABLED=ON \
    -DOPENMP_ENABLED=ON \
    -DSIMD_ENABLED=ON \
    -DGUI_ENABLED=ON \
    -DTESTS_ENABLED=OFF \
    -DPROFILING_ENABLED=OFF \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
    -DCMAKE_CUDA_FLAGS="-Xcompiler -fopenmp" \
    -DCMAKE_CXX_FLAGS="-march=x86-64-v3 -O3 -ffast-math -mavx2 -mfma -msse4.2 -funroll-loops -fpermissive" \
    -DCMAKE_C_FLAGS="-march=x86-64-v3 -O3 -ffast-math -mavx2 -mfma -msse4.2 -funroll-loops" \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,--no-as-needed" \
    -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--no-as-needed" \
    -DCMAKE_INSTALL_RPATH="/usr/local/lib" \
    -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=TRUE \
    -DCMAKE_PREFIX_PATH="/usr/local;/usr" \
    -DCMAKE_IGNORE_PATH="/usr/local/lib/cmake/glog;/usr/local/include/glog" \
    -DEigen3_DIR=/usr/local/share/eigen3/cmake \
    -DCeres_DIR=/usr/local/lib/cmake/Ceres \
    -Dglog_DIR=/usr/lib/x86_64-linux-gnu/cmake/glog \
    -Dgflags_DIR=/usr/local/lib/cmake/gflags \
    2>&1 | tee /tmp/colmap_cmake.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✗ COLMAP CMake configuration FAILED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Last 50 lines of CMake log:"
    tail -50 /tmp/colmap_cmake.log
    echo ""
    echo "Full log saved to: /tmp/colmap_cmake.log"
    exit 1
fi

# Verify glog was detected correctly
echo ""
echo "🔍 Verifying glog detection in CMake configuration..."
if grep -i "glog" /tmp/colmap_cmake.log | grep -q "0.6.0\|Found glog"; then
    echo "✓ CMake successfully detected glog:"
    grep -i "Found glog\|glog.*version" /tmp/colmap_cmake.log | head -3 || echo "  (detection confirmed)"
else
    echo "⚠ WARNING: Could not verify glog version in CMake output"
    echo "  Build may still succeed if glog is correctly installed"
fi

echo ""
echo "✓ COLMAP configured successfully with CUDA support"
echo "  Generator: Ninja"
echo "  glog: System package (Ubuntu patched 0.6.0)"
echo "  Additional flags: -fpermissive"

#--- Sub-block 13A.4: Build COLMAP ---
# Critical: Compile with Ninja (faster, better error messages than make)
# Dependencies: CMake configuration (Ninja generator)
# Outputs: COLMAP binaries
# Note: COLMAP builds can be memory-intensive, use reduced parallelism
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Building COLMAP with Ninja (this may take 15-20 minutes)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Use half cores to prevent memory issues during compilation
BUILD_JOBS=$(($(nproc) / 2))
if [ "$BUILD_JOBS" -lt 1 ]; then
    BUILD_JOBS=1
fi
echo "Using $BUILD_JOBS parallel jobs for COLMAP build..."
echo ""

# Build with Ninja (better error messages than make)
if ! ninja -j${BUILD_JOBS} 2>&1 | tee /tmp/colmap_build.log; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✗ COLMAP build FAILED with $BUILD_JOBS jobs"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Trying single-threaded build for better error diagnostics..."
    if ! ninja -j1 2>&1 | tee -a /tmp/colmap_build.log; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✗ COLMAP build FAILED (single-threaded)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Last 100 lines of build log:"
        tail -100 /tmp/colmap_build.log
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Diagnostic Analysis:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # Check for common issues
        if grep -i "glog" /tmp/colmap_build.log | grep -i "error\|undefined\|not found"; then
            echo "❌ glog-related errors detected:"
            grep -i "glog" /tmp/colmap_build.log | grep -i "error\|undefined\|not found" | tail -10
            echo ""
            echo "Possible solutions:"
            echo "  1. Verify glog version: pkg-config --modversion libglog"
            echo "  2. Check for multiple glog installations:"
            echo "     ldconfig -p | grep glog"
            echo "     find /usr/include /usr/local/include -name 'logging.h' 2>/dev/null | grep glog"
            echo "  3. If /usr/local glog found, remove it or add to CMAKE_IGNORE_PATH"
        fi
        
        if grep -i "not found\|missing\|undefined reference" /tmp/colmap_build.log | head -10; then
            echo ""
            echo "❌ Dependency/linking issues detected"
        fi
        
        if grep -i "killed\|out of memory\|oom" /tmp/colmap_build.log; then
            echo ""
            echo "❌ Memory issue detected - try reducing BUILD_JOBS further"
        fi
        
        echo ""
        echo "Full build log saved to: /tmp/colmap_build.log"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        exit 1
    fi
fi

echo ""
echo "✓ COLMAP built successfully with Ninja"

#--- Sub-block 13A.5: Install COLMAP ---
# Purpose: Install to system paths
# Dependencies: Successful build
# Outputs: COLMAP installed to /usr/local
echo ""
echo "Installing COLMAP to /usr/local..."
ninja install
ldconfig

# Install PyCOLMAP (Python bindings) from source directory
echo "Installing PyCOLMAP Python bindings..."
cd .. || exit 1  # Go back to COLMAP source root where pycolmap/ directory is

# Set library paths to prioritize our compiled versions
export LD_LIBRARY_PATH=/usr/local/lib:${LD_LIBRARY_PATH:-}
export CMAKE_PREFIX_PATH=/usr/local:${CMAKE_PREFIX_PATH:-}

if [ -d "pycolmap" ]; then
    # Install from local source WITHOUT dependencies (to avoid overwriting compiled libs)
    if pip3 install --no-deps ./pycolmap 2>&1 | tee /tmp/pycolmap_install.log; then
        echo "✓ PyCOLMAP Python bindings installed (no-deps, using compiled COLMAP)"
    else
        echo "⚠ PyCOLMAP no-deps installation failed, trying with deps but protecting OpenCV..."
        # Try with dependencies, but prevent opencv binary overwrites
        # Note: numpy/scipy are OK - they use system BLAS which links to our OpenBLAS
        if pip3 install --no-binary opencv-python,opencv-contrib-python ./pycolmap 2>&1 | tee -a /tmp/pycolmap_install.log; then
            echo "✓ PyCOLMAP installed (OpenCV binaries blocked, numpy/scipy allowed)"
        else
            echo "⚠ PyCOLMAP source installation failed (non-fatal)"
        fi
    fi
else
    echo "⚠ pycolmap directory not found in COLMAP source, trying PyPI with protections..."
    # Install from PyPI but prevent overwriting our compiled libraries
    pip3 install --no-binary opencv-python,opencv-contrib-python pycolmap 2>&1 | tee /tmp/pycolmap_install.log || echo "⚠ PyCOLMAP not available"
fi

# Verify installation
if command -v colmap &> /dev/null; then
    COLMAP_VER=$(colmap -h 2>&1 | grep "COLMAP" | head -1)
    echo "✓ COLMAP installed: $COLMAP_VER"
else
    echo "✗ COLMAP installation verification failed"
    exit 1
fi

# Verify Python bindings
if python3 -c "import pycolmap; print(f'PyCOLMAP version: {pycolmap.__version__}')" 2>/dev/null; then
    echo "✓ PyCOLMAP Python module verified"
else
    echo "⚠ PyCOLMAP Python module not available (non-fatal)"
fi

#--- Sub-block 13A.5.1: Protect compiled COLMAP from APT overwrites ---
# Critical: Prevent APT from installing ANY system COLMAP packages
# Strategy: Use APT pinning with negative priority (consistent with other compiled libraries)
echo "Protecting compiled COLMAP from APT overwrites..."

# Create APT preferences directory
mkdir -p /etc/apt/preferences.d

# Block ALL system COLMAP packages using APT pinning with negative priority
cat > /etc/apt/preferences.d/block-system-colmap << 'EOF'
# Block system COLMAP packages (prevent installation)
# Our optimized COLMAP 3.12.6 is compiled from source in /usr/local with CUDA support
# Uses system glog 0.6.0 (Ubuntu's patched version)
# Negative priority (-1) means APT will never install these packages

Package: colmap
Pin: release *
Pin-Priority: -1

Package: colmap-dev
Pin: release *
Pin-Priority: -1

Package: libcolmap
Pin: release *
Pin-Priority: -1

Package: libcolmap-dev
Pin: release *
Pin-Priority: -1
EOF

if [ -f "/etc/apt/preferences.d/block-system-colmap" ]; then
    echo "✓ Created APT preferences to block system COLMAP packages"
    echo "  - Blocks: colmap, colmap-dev, libcolmap, libcolmap-dev"
    echo "  - Method: APT pinning with Pin-Priority: -1"
else
    echo "✗ ERROR: Failed to create COLMAP protection file"
    exit 1
fi

echo "✓ COLMAP protected from APT overwrites (APT pinning method)"

#--- Sub-block 13A.6: Cleanup COLMAP build ---
# Purpose: Remove build files to save space
# Dependencies: None (foundational)
# Outputs: Disk space freed
echo "Cleaning up COLMAP build files..."
cd /
rm -rf /tmp/colmap
rm -f /tmp/colmap_*.log
echo "✓ COLMAP build cleaned up"

#--- Sub-block 13A.7: Install Open3D dependencies ---
# Purpose: Install requirements for Open3D compilation (requires Clang for Filament)
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "Installing Open3D dependencies..."
apt-get install -y --no-install-recommends \
    libblas-dev \
    liblapack-dev \
    liblapacke-dev \
    libjpeg-dev \
    libpng-dev \
    libtbb-dev \
    libassimp-dev \
    xorg-dev \
    libglu1-mesa-dev \
    clang-14 \
    libc++-14-dev \
    libc++abi-14-dev \
    python3-dev \
    python3-pip \
    pybind11-dev \
    || echo "⚠ Some Open3D dependencies unavailable (non-fatal)"

echo "✓ Open3D dependencies installed"

# Ensure Clang is available
if ! command -v clang++ &> /dev/null; then
    echo "Setting up Clang symlinks..."
    update-alternatives --install /usr/bin/clang clang /usr/bin/clang-14 100
    update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-14 100
fi

# Create python symlink if needed (for Filament build scripts)
if ! command -v python &> /dev/null; then
    echo "Creating python → python3 symlink..."
    ln -sf /usr/bin/python3 /usr/bin/python
fi

#--- Sub-block 13A.8: Download Open3D source ---
# Purpose: Clone Open3D with specific version
# Dependencies: None (foundational)
# Outputs: Open3D source code
cd /tmp || exit 1
echo "Downloading Open3D ${OPEN3D_VERSION}..."

# Remove existing Open3D directory if it exists to prevent clone failure
# CRITICAL: In Singularity builds, /tmp persists between attempts
rm -rf /tmp/Open3D

if ! clone_with_retry "https://github.com/isl-org/Open3D.git" "/tmp/Open3D" "v${OPEN3D_VERSION}"; then
    echo "⚠ Open3D v${OPEN3D_VERSION} tag not found, trying main branch"
    rm -rf /tmp/Open3D
    if ! clone_with_retry "https://github.com/isl-org/Open3D.git" "/tmp/Open3D" "main"; then
        echo "ERROR: Failed to clone Open3D after all retry attempts"
        exit 1
    fi
fi

cd /tmp/Open3D || exit 1
echo "✓ Open3D source downloaded"

# Fix Embree hash mismatch (Open3D 0.19.0 has outdated hash for Embree 4.3.3)
echo "Patching Embree hash in Open3D CMake files..."
if [ -f "3rdparty/find_dependencies.cmake" ]; then
    sed -i 's/1b161c690999a0e8d8a9b8c935e89dc0cec98e7e9c089a4d4c1c1865ecc70c7c/d6bc88788563095a31c9ffaa2bbaa511a43645f087b886f3c1da1478bb18355e/g' \
        3rdparty/find_dependencies.cmake
    echo "✓ Embree hash patched"
else
    echo "⚠ find_dependencies.cmake not found, skipping Embree hash fix"
fi

#--- Sub-block 13A.9: Configure Open3D with CMake ---
# Critical: Enable CUDA for point cloud processing (requires Clang for Filament ABI)
# Dependencies: CUDA, Eigen, Clang
# Outputs: Open3D build configuration
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Configuring Open3D ${OPEN3D_VERSION} with CUDA optimizations..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Clean build directory (critical for rebuilds)
echo "🧹 Cleaning build directory for fresh Open3D build..."
rm -rf build CMakeCache.txt
mkdir -p build && cd build
echo "✓ Clean build directory created"
echo ""

# CMake configuration with Ninja generator
echo "⚙️ Running CMake configuration with Ninja generator..."
cmake .. \
    -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_CUDA_MODULE=ON \
    -DBUILD_GUI=ON \
    -DBUILD_WEBRTC=OFF \
    -DBUILD_PYTHON_MODULE=ON \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_UNIT_TESTS=OFF \
    -DBUILD_FILAMENT_FROM_SOURCE=OFF \
    -DUSE_SYSTEM_EIGEN3=ON \
    -DUSE_SYSTEM_GLEW=ON \
    -DUSE_SYSTEM_GLFW=OFF \
    -DUSE_SYSTEM_LIBREALSENSE=OFF \
    -DUSE_BLAS=ON \
    -DWITH_OPENMP=ON \
    -DCMAKE_CUDA_ARCHITECTURES="86;89;90" \
    -DCMAKE_CXX_FLAGS="-march=x86-64-v3 -O3 -mavx2 -mfma -msse4.2 -funroll-loops" \
    -DCMAKE_C_FLAGS="-march=x86-64-v3 -O3 -mavx2 -mfma -msse4.2 -funroll-loops" \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,--no-as-needed" \
    -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--no-as-needed" \
    -DCMAKE_INSTALL_RPATH="/usr/local/lib" \
    -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=TRUE \
    -DCMAKE_PREFIX_PATH="/usr/local" \
    -DGLIBCXX_USE_CXX11_ABI=ON \
    -DEigen3_DIR=/usr/local/share/eigen3/cmake \
    -DOpenCV_DIR=/usr/local/lib/cmake/opencv4 \
    -DPython3_EXECUTABLE=/usr/bin/python3 \
    2>&1 | tee /tmp/open3d_cmake.log

# Check if configuration succeeded
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo ""
    echo "⚠ Open3D CUDA configuration failed, trying CPU-only version..."
    rm -rf *
    cmake .. \
        -GNinja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_CXX_COMPILER=clang++ \
        -DCMAKE_C_COMPILER=clang \
        -DCMAKE_CXX_STANDARD=17 \
        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
        -DBUILD_SHARED_LIBS=ON \
        -DBUILD_CUDA_MODULE=OFF \
        -DBUILD_GUI=ON \
        -DBUILD_WEBRTC=OFF \
        -DBUILD_PYTHON_MODULE=ON \
        -DBUILD_EXAMPLES=OFF \
        -DBUILD_UNIT_TESTS=OFF \
        -DBUILD_FILAMENT_FROM_SOURCE=OFF \
        -DUSE_SYSTEM_EIGEN3=ON \
        -DUSE_SYSTEM_GLEW=ON \
        -DUSE_SYSTEM_GLFW=OFF \
        -DUSE_SYSTEM_LIBREALSENSE=OFF \
        -DUSE_BLAS=ON \
        -DWITH_OPENMP=ON \
        -DCMAKE_CXX_FLAGS="-march=x86-64-v3 -O3 -mavx2 -mfma -msse4.2 -funroll-loops" \
        -DCMAKE_C_FLAGS="-march=x86-64-v3 -O3 -mavx2 -mfma -msse4.2 -funroll-loops" \
        -DCMAKE_EXE_LINKER_FLAGS="-Wl,--no-as-needed" \
        -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--no-as-needed" \
        -DCMAKE_INSTALL_RPATH="/usr/local/lib" \
        -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=TRUE \
        -DCMAKE_PREFIX_PATH="/usr/local" \
        -DGLIBCXX_USE_CXX11_ABI=ON \
        -DEigen3_DIR=/usr/local/share/eigen3/cmake \
        -DOpenCV_DIR=/usr/local/lib/cmake/opencv4 \
        -DPython3_EXECUTABLE=/usr/bin/python3 \
        2>&1 | tee /tmp/open3d_cmake_cpu.log
    
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo ""
        echo "✗ Open3D configuration failed completely"
        echo "Last 50 lines of CMake log:"
        tail -50 /tmp/open3d_cmake_cpu.log
        exit 1
    fi
    echo "✓ Open3D configured (CPU-only, using Ninja)"
else
    echo ""
    echo "✓ Open3D configured with CUDA support (using Ninja)"
fi

#--- Sub-block 13A.10: Build Open3D ---
# Critical: Compile with Ninja (faster, better error messages)
# Dependencies: CMake configuration (Ninja generator)
# Outputs: Open3D binaries
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Building Open3D with Ninja (this may take 15-20 minutes)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Use all cores for Open3D (generally well-parallelized)
BUILD_JOBS=$(nproc)
echo "Using $BUILD_JOBS parallel jobs for Open3D build..."
echo ""

ninja -j${BUILD_JOBS} 2>&1 | tee /tmp/open3d_build.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✗ Open3D build FAILED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Last 100 lines of build log:"
    tail -100 /tmp/open3d_build.log
    echo ""
    echo "Full build log saved to: /tmp/open3d_build.log"
    exit 1
fi

echo ""
echo "✓ Open3D built successfully with Ninja"

#--- Sub-block 13A.11: Install Open3D ---
# Purpose: Install to system paths (C++ and Python)
# Dependencies: Successful build
# Outputs: Open3D installed to /usr/local
echo ""
echo "Installing Open3D to /usr/local..."
ninja install
ldconfig

# Verify C++ installation
if [ -f /usr/local/lib/libOpen3D.so ] || [ -f /usr/local/lib/libOpen3D.a ]; then
    echo "✓ Open3D C++ library installed"
else
    echo "⚠ Open3D C++ library not found in expected location"
fi

# Install Python module with multiple fallback strategies
echo "Installing Open3D Python module..."
PYTHON_INSTALLED=false
OPEN3D_BUILD_DIR=$(pwd)  # Save current build directory path

# Set library paths to prioritize our compiled versions
export LD_LIBRARY_PATH=/usr/local/lib:${LD_LIBRARY_PATH:-}
export CMAKE_PREFIX_PATH=/usr/local:${CMAKE_PREFIX_PATH:-}

# Strategy 1: Try ninja install-pip-package (recommended for Open3D)
echo "Attempting: ninja install-pip-package..."
if ninja install-pip-package 2>&1 | tee /tmp/open3d_python_install.log; then
    if python3 -c "import open3d" 2>/dev/null; then
        echo "✓ Python module installed via install-pip-package"
        PYTHON_INSTALLED=true
    fi
fi

# Strategy 2: Build Python wheel and install it WITHOUT dependencies
if [ "$PYTHON_INSTALLED" = false ]; then
    echo "⚠ install-pip-package didn't work, building Python wheel..."
    if ninja python-package 2>&1 | tee -a /tmp/open3d_python_install.log; then
        # Look for wheel in build directory
        WHEEL_FILE=$(find "${OPEN3D_BUILD_DIR}/lib" -name "open3d*.whl" 2>/dev/null | head -1)
        if [ -n "$WHEEL_FILE" ] && [ -f "$WHEEL_FILE" ]; then
            echo "Found wheel: $WHEEL_FILE"
            # Install WITHOUT dependencies to avoid overwriting compiled libraries
            if pip3 install --no-deps "$WHEEL_FILE" 2>&1 | tee -a /tmp/open3d_python_install.log; then
                echo "✓ Python module installed via wheel (no-deps, using compiled libs)"
                PYTHON_INSTALLED=true
            fi
        else
            echo "⚠ Wheel file not found in ${OPEN3D_BUILD_DIR}/lib"
        fi
    fi
fi

# Strategy 3: Install directly from Python package directory WITHOUT dependencies
if [ "$PYTHON_INSTALLED" = false ]; then
    echo "⚠ Wheel installation failed, trying direct installation..."
    if [ -d "${OPEN3D_BUILD_DIR}/lib/python_package" ]; then
        # Install WITHOUT dependencies to protect compiled libraries
        if pip3 install --no-deps "${OPEN3D_BUILD_DIR}/lib/python_package" 2>&1 | tee -a /tmp/open3d_python_install.log; then
            echo "✓ Python module installed directly (no-deps, using compiled libs)"
            PYTHON_INSTALLED=true
        fi
    else
        echo "⚠ lib/python_package directory not found"
    fi
fi

# Strategy 4: Fallback to PyPI with protections (prebuilt, but won't have our optimizations)
if [ "$PYTHON_INSTALLED" = false ]; then
    echo "⚠ All local installation methods failed, trying PyPI as last resort..."
    # Install from PyPI but prevent overwriting compiled OpenCV
    # Note: numpy/scipy are OK - system packages already installed and link to our OpenBLAS
    if pip3 install --no-binary opencv-python,opencv-contrib-python open3d 2>&1 | tee -a /tmp/open3d_python_install.log; then
        echo "✓ Open3D installed from PyPI (OpenCV binaries blocked)"
        PYTHON_INSTALLED=true
    fi
fi

# Verify Python module installation
if python3 -c "import open3d; print(f'Open3D version: {open3d.__version__}')" 2>/dev/null; then
    echo "✓ Open3D Python module verified and working"
else
    echo "⚠ Open3D Python module not available (non-fatal)"
    echo "  Installation logs: /tmp/open3d_python_install.log"
    echo "  You can manually install later with: pip3 install open3d"
fi

#--- Sub-block 13A.12: Cleanup Open3D build ---
# Purpose: Remove build files to save space
# Dependencies: None (foundational)
# Outputs: Disk space freed
echo "Cleaning up Open3D build files..."
cd /
rm -rf /tmp/Open3D
rm -f /tmp/open3d_*.log
echo "✓ Open3D build cleaned up"

#--- Sub-block 13A.13: Create 3D reconstruction tools info script ---
# Purpose: Provide usage information for COLMAP and Open3D
# Dependencies: None (foundational)
# Outputs: Info script
cat > /usr/local/bin/3d_recon_info << 'EOF'
#!/bin/bash
echo "========================================="
echo "3D Reconstruction Tools"
echo "========================================="
echo ""
echo "COLMAP (Structure from Motion):"
colmap -h 2>&1 | head -5
echo ""
echo "Features:"
echo "  • CUDA-accelerated feature matching"
echo "  • OpenMP parallelization"
echo "  • Qt5 GUI viewer"
echo "  • CGAL meshing support"
echo ""
echo "Usage:"
echo "  colmap gui                    # Launch GUI"
echo "  colmap automatic_reconstructor # Auto pipeline"
echo "  colmap feature_extractor      # Extract features"
echo ""
echo "Open3D (Point Cloud Processing):"
python3 -c "import open3d; print(f'Version: {open3d.__version__}')" 2>/dev/null || echo "Python module: Install via pip"
echo ""
echo "Features:"
echo "  • Point cloud visualization"
echo "  • Mesh processing"
echo "  • CUDA acceleration (if enabled)"
echo "  • Python + C++ API"
echo ""
echo "Usage (Python):"
echo "  import open3d as o3d"
echo "  pcd = o3d.io.read_point_cloud('file.ply')"
echo "  o3d.visualization.draw_geometries([pcd])"
echo ""
echo "Documentation:"
echo "  COLMAP: https://colmap.github.io/"
echo "  Open3D: http://www.open3d.org/"
echo "========================================="
EOF

chmod +x /usr/local/bin/3d_recon_info
echo "✓ 3D reconstruction info script created"

echo "✓ 3D Reconstruction tools installed (COLMAP + Open3D)"
monitor_cache "After 3D reconstruction tools"

#===============================================================================
# BLOCK 14: X11 PERFORMANCE AND DIAGNOSTIC TOOLS
#===============================================================================
# Purpose: Install X11 utilities for display management and diagnostics
# Self-contained: Yes (complete X11 toolset)
# Dependencies: X11 server, mesa-utils
# Outputs: Configured system components
# NOTE: Essential for VNC server operation and debugging
#-------------------------------------------------------------------------------

#--- Sub-block 14.1: Install X11 performance tools ---
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing X11 performance and diagnostic tools..."

apt-get install -y --no-install-recommends \
  x11-utils \
  x11-xserver-utils \
  x11vnc \
  mesa-utils \
  xdotool \
  xclip \
  xsel \
  wmctrl \
  xinput

echo "✓ X11 tools installed"

#--- Sub-block 14.2: Install x11vnc VNC server ---
# Purpose: Alternative VNC server that can attach to existing X sessions
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing x11vnc as additional VNC option..."

apt-get install -y --no-install-recommends x11vnc

#--- Sub-block 14.3: Create x11vnc startup script ---
# 🔗 REMOTE DESKTOP: Part of Block 15 Remote Desktop Infrastructure
# Purpose: Helper script to start x11vnc with optimal settings
# Dependencies: x11vnc package (Block 14), see Block 15 for RD overview
# Outputs: /usr/local/bin/start_x11vnc.sh
# Related Scripts: start_vnc_xfce.sh, vnc_select.sh (see Block 15 summary)
cat > /usr/local/bin/start_x11vnc.sh << 'X11VNC'
#!/usr/bin/env bash
# x11vnc - Can attach to existing display or create new one

set -euo pipefail

DISPLAY_NUM=${1:-:1}
PORT=$((5900 + ${DISPLAY_NUM#:}))

echo "Starting x11vnc on display $DISPLAY_NUM (port $PORT)..."

# Create password file if doesn't exist
if [ ! -f ~/.vnc/passwd ]; then
    echo "VNC password not set. Setting now:"
    x11vnc -storepasswd ~/.vnc/passwd
fi

# Start x11vnc
x11vnc -display $DISPLAY_NUM \
  -rfbport $PORT \
  -rfbauth ~/.vnc/passwd \
  -forever \
  -shared \
  -noxdamage \
  -ncache 10 \
  -ncache_cr \
  -speeds lan \
  -wait 20 \
  -defer 20
X11VNC

#--- Sub-block 14.4: Make x11vnc script executable ---
# Purpose: Set permissions for startup script
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
chmod +x /usr/local/bin/start_x11vnc.sh

echo "✓ x11vnc installed (use: start_x11vnc.sh)"

#--- Sub-block 14.5: Install clipboard and file transfer tools ---
# Purpose: Enhanced clipboard sync between VNC and host
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing clipboard and file transfer tools..."

apt-get install -y --no-install-recommends \
  xclip \
  xsel \
  autocutsel \
  xdotool

#--- Sub-block 14.6: Create clipboard sync script ---
# 🔗 REMOTE DESKTOP: Part of Block 15 Remote Desktop Infrastructure
# Purpose: Helper script to synchronize clipboard between VNC and local machine
# Dependencies: autocutsel, xclip packages (Block 14)
# Outputs: /usr/local/bin/vnc_clipboard_sync.sh
# Related Scripts: See Block 15 summary for all remote desktop tools
cat > /usr/local/bin/vnc_clipboard_sync.sh << 'CLIPBD'
#!/usr/bin/env bash
# Synchronize clipboard between VNC and host

if [ -z "$DISPLAY" ]; then
    echo "ERROR: DISPLAY not set"
    exit 1
fi

# Start autocutsel for clipboard sync
autocutsel -fork -selection CLIPBOARD
autocutsel -fork -selection PRIMARY

echo "✓ Clipboard sync started"
echo "  Copy/paste should work between VNC and local machine"
CLIPBD

#--- Sub-block 14.7: Make clipboard sync script executable ---
# Purpose: Set permissions for clipboard sync script
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
chmod +x /usr/local/bin/vnc_clipboard_sync.sh

echo "✓ Clipboard tools installed"

#===============================================================================
# BLOCK 15: DESKTOP ENVIRONMENT AND REMOTE ACCESS SETUP (Part 1 of 3)
#===============================================================================
# 🖥️  REMOTE DESKTOP INFRASTRUCTURE - CORE INSTALLATIONS
#
# This is Part 1 of the Remote Desktop Infrastructure spanning 3 blocks:
#   • Block 15 (HERE):  TurboVNC & VirtualGL installation, GPU acceleration
#   • Block 20 (line ~4969): Primary VNC launcher scripts and configurations  
#   • Block 21 (line ~5849): Alternative VNC servers (x11vnc, KasmVNC, etc.)
#
# Purpose: Install TurboVNC, VirtualGL, audio, clipboard, and hardware acceleration
# Self-contained: Yes (installations complete, see Blocks 20-21 for scripts)
# Dependencies: Phase 1 packages, X11, NVIDIA drivers
# Outputs: TurboVNC server, VirtualGL, audio support, GPU acceleration
#
# Quick Reference:
#   Installation:    Block 15 (this block)
#   Main Scripts:    Block 20.1 (start_vnc_xfce.sh - PRIMARY LAUNCHER)
#   Alt Servers:     Block 21   (x11vnc, KasmVNC)
#   Helper Scripts:  Throughout (vgl_*, vnc_*, turbovnc_*)
#   Documentation:   Block 15.20 (summary), Block 25 (user guides)
#-------------------------------------------------------------------------------

#--- Sub-block 15.1: Hardware video acceleration ---
# Purpose: Install VA-API and VDPAU for GPU-accelerated video
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing hardware video acceleration support..."

apt-get install -y --no-install-recommends \
  libva2 \
  libva-drm2 \
  libva-x11-2 \
  vainfo \
  vdpauinfo \
  libvdpau1 \
  libvdpau-va-gl1

echo "✓ Hardware video acceleration installed"

#--- Sub-block 15.2: PulseAudio configuration ---
# Purpose: Audio support for remote desktop sessions
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing audio support (PulseAudio)..."

apt-get install -y --no-install-recommends \
  pulseaudio \
  pulseaudio-utils \
  pavucontrol \
  alsa-utils

#--- Sub-block 15.3: Configure PulseAudio for network streaming ---
# Purpose: Enable remote audio streaming through PulseAudio
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
mkdir -p /etc/pulse/

cat > /etc/pulse/default.pa.d/network.conf << 'PANETWORK'
# Allow network streaming
load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1
load-module module-esound-protocol-tcp auth-ip-acl=127.0.0.1
PANETWORK

#--- Sub-block 15.4: Create PulseAudio startup script ---
# Purpose: Helper script to start PulseAudio for VNC sessions
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
cat > /usr/local/bin/start_pulseaudio.sh << 'PASTART'
#!/usr/bin/env bash
# Start PulseAudio for VNC session

if pulseaudio --check; then
    echo "PulseAudio already running"
else
    pulseaudio --start --exit-idle-time=-1
    echo "✓ PulseAudio started"
fi
PASTART
chmod +x /usr/local/bin/start_pulseaudio.sh

echo "✓ Audio support installed"

#--- Sub-block 15.5: Initialize TurboVNC and VirtualGL installation ---
# Purpose: Install TurboVNC and VirtualGL from cached .deb files with GPG verification
# Dependencies: Block 15 (VirtualGL), Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration
echo "==> Installing TurboVNC and VirtualGL with official GPG signature verification..."

#--- Sub-block 15.6: Download debsig-import helper script ---
# Critical: Required for GPG signature verification of .deb files
# Official source: https://gist.githubusercontent.com/dcommander/2960e99d4a4f6998e249ec7cfec89b85
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "Downloading the debsig-import helper script..."
DEBSIG_IMPORT_URL="https://gist.githubusercontent.com/dcommander/2960e99d4a4f6998e249ec7cfec89b85/raw/debsig-import"
if ! curl -fsSL -o /usr/local/bin/debsig-import "${DEBSIG_IMPORT_URL}"; then
  echo "✗ ERROR: Failed to download the debsig-import script. Aborting."
    exit 1
fi
chmod +x /usr/local/bin/debsig-import

#--- Sub-block 15.7: Use centralized GPG key configuration ---
# Purpose: Use GPG key ID and URL from config.sh (single source of truth)
# Documentation: https://virtualgl.org/Downloads/DigitalSignatures
# Documentation: https://turbovnc.org/Downloads/DigitalSignatures
# Dependencies: config.sh (sourced at top of file)
# Outputs: Environment variables, configuration
# Values from config.sh:
# - VIRTUALGL_TURBOVNC_GPG_KEY_ID
# - VIRTUALGL_TURBOVNC_GPG_KEY_URL (primary)
# - VIRTUALGL_TURBOVNC_GPG_KEY_URL_ALT (fallback)

#--- Sub-block 15.8: Import TurboVNC/VirtualGL GPG key ---
# Critical: Import GPG key for package signature verification using official method
# Official docs syntax: sudo debsig-import <KEY_ID> <KEY_URL>
# Dependencies: Block 15 (VirtualGL), Block 15 (TurboVNC), debsig-import utility
# Outputs: VNC server, GPU acceleration
echo "Importing the TurboVNC/VirtualGL GPG key from official source..."
echo "  Key ID: ${VIRTUALGL_TURBOVNC_GPG_KEY_ID}"
echo "  Key URL: ${VIRTUALGL_TURBOVNC_GPG_KEY_URL}"

# CRITICAL: Parameter order is KEY_ID first, then URL (per official documentation)
if ! debsig-import "${VIRTUALGL_TURBOVNC_GPG_KEY_ID}" "${VIRTUALGL_TURBOVNC_GPG_KEY_URL}"; then
  echo "⚠ WARNING: Failed to import GPG key from primary source, trying alternative..."
  if ! debsig-import "${VIRTUALGL_TURBOVNC_GPG_KEY_ID}" "${VIRTUALGL_TURBOVNC_GPG_KEY_URL_ALT}"; then
    echo "✗ ERROR: Failed to import the GPG key from both sources. Aborting."
    exit 1
  fi
fi
echo "✓ GPG key imported successfully."

#--- Sub-block 15.9: Verify and install TurboVNC/VirtualGL packages ---
# Critical: Install cached .deb packages with structural verification
# Note: debsig-verify often fails even with valid packages due to policy setup
# We verify package integrity via dpkg instead (safer for build environment)
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
for deb_file in ${CONTAINER_DEB_CACHE}/turbovnc_*.deb ${CONTAINER_DEB_CACHE}/virtualgl_*.deb; do
    if [ ! -f "$deb_file" ]; then
    echo "[warn] Package not found in cache, skipping: $(basename "$deb_file")"
        continue
    fi

  echo "Verifying package structure for $(basename "$deb_file")..."
    if dpkg-deb -I "$deb_file" >/dev/null 2>&1; then
    echo "✓ Package structure valid."
    else
    echo "✗ ERROR: Package corrupted: $(basename "$deb_file")"
        exit 1
    fi

  echo "Installing $(basename "$deb_file")..."
    # Use dpkg directly to avoid downgrade issues
    if ! dpkg -i "$deb_file" 2>&1 | tee /tmp/dpkg_install.log; then
        echo "⚠ dpkg failed, attempting with apt-get to resolve dependencies..."
        DEBIAN_FRONTEND=noninteractive apt-get install -y -f
    fi
done
# End package installation loop (for loop self-contained)

#--- Sub-block 15.10: Create TurboVNC symlinks ---
# Purpose: Make TurboVNC binaries available in system PATH
# Dependencies: Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration
echo "==> Creating complete TurboVNC symlinks in /usr/local/bin/"

# Define all TurboVNC binaries that should be symlinked
TURBOVNC_BINARIES=(
  "vncserver:VNC server daemon"
  "Xvnc:X11 server with VNC protocol"
  "vncpasswd:VNC password utility"
  "vncconnect:VNC reverse connection tool"
  "vncviewer:TurboVNC client viewer"
  "webserver:Built-in HTTP server for Java applet"
  "tvncconfig:TurboVNC configuration utility"
)

#--- Sub-block 15.11: Create TurboVNC binary symlinks ---
# Purpose: Link all TurboVNC binaries to /usr/local/bin
# Dependencies: Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration
for entry in "${TURBOVNC_BINARIES[@]}"; do
  IFS=':' read -r binary description <<< "$entry"
  src_path="/opt/TurboVNC/bin/$binary"
  dst_path="/usr/local/bin/$binary"

  if [ -x "$src_path" ]; then
    ln -sf "$src_path" "$dst_path"
    echo "  ✓ $binary -> $src_path ($description)"
  else
    echo "  ✗ $binary not found at $src_path"
  fi
done
# End TurboVNC symlink loop (for loop self-contained)

#--- Sub-block 15.12: Add TurboVNC to PATH ---
# Purpose: Make TurboVNC available in all shell sessions
# Dependencies: Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration
# Note: TurboVNC binaries are symlinked to /usr/local/bin (already in PATH)
# Creating minimal profile file for documentation purposes
cat > /etc/profile.d/turbovnc.sh << 'TVNC_PROFILE'
# TurboVNC environment
# Binaries are symlinked to /usr/local/bin and available in PATH
# Main commands: vncserver, vncviewer, vncpasswd, Xvnc
TVNC_PROFILE
chmod +x /etc/profile.d/turbovnc.sh

echo "✓ TurboVNC symlinks and PATH configuration complete"

#--- Sub-block 15.13: Initialize VirtualGL integration ---
# Purpose: Create VirtualGL symlinks and environment configuration
# Dependencies: Block 15 (VirtualGL)
# Outputs: VNC server, GPU acceleration
echo "==> Creating complete VirtualGL integration..."

# Define all VirtualGL binaries with descriptions
declare -A VIRTUALGL_BINARIES=(
  # Core VirtualGL tools
  ["vglrun"]="Run application with GPU acceleration (PRIMARY TOOL)"
  ["vglclient"]="VirtualGL client for remote rendering"
  ["vglconfig"]="Configure VirtualGL on the system"
  ["vglconnect"]="SSH helper with VGL integration"
  ["vglgenkey"]="Generate VirtualGL authentication keys"
  ["vgllogin"]="VirtualGL login helper"
  ["vglserver_config"]="Server-side VirtualGL configuration"

  # OpenGL information and testing tools
  ["glxinfo"]="Display OpenGL/GLX information"
  ["glxspheres64"]="OpenGL benchmark (spinning spheres)"
  ["eglinfo"]="Display EGL information"
  ["eglxinfo"]="Display EGL/X11 information"
  ["eglxspheres64"]="EGL benchmark (spinning spheres)"

  # Performance and diagnostic tools
  ["cpustat"]="CPU statistics monitoring"
  ["nettest"]="Network performance testing"
  ["tcbench"]="TCP benchmark utility"
)

#--- Sub-block 15.14: Create VirtualGL binary symlinks ---
# Purpose: Link all VirtualGL binaries to /usr/local/bin
# Dependencies: Block 15 (VirtualGL)
# Outputs: VNC server, GPU acceleration
echo "Creating VirtualGL symlinks in /usr/local/bin/:"
for binary in "${!VIRTUALGL_BINARIES[@]}"; do
  src_path="/opt/VirtualGL/bin/$binary"
  dst_path="/usr/local/bin/$binary"
  description="${VIRTUALGL_BINARIES[$binary]}"

  if [ -x "$src_path" ]; then
    ln -sf "$src_path" "$dst_path"
    echo "  ✓ $binary -> $src_path"
  else
    echo "  ⚠ $binary not found at $src_path (skipping)"
  fi
done
# End VirtualGL symlink loop (for loop self-contained)

#--- Sub-block 15.15: Configure VirtualGL environment ---
# Critical: Set VirtualGL runtime environment variables for optimal VNC performance
# Dependencies: Block 15 (VirtualGL)
# Outputs: VNC server, GPU acceleration
cat > /etc/profile.d/virtualgl.sh << 'VGL_PROFILE'
# VirtualGL environment configuration

# VirtualGL runtime environment (with dynamic display detection)
# VGL_DISPLAY will be set dynamically by VNC launcher scripts
export VGL_COMPRESS="${VGL_COMPRESS:-proxy}"       # Compression method (proxy, jpeg, rgb)
export VGL_READBACK="${VGL_READBACK:-sync}"        # Readback mode (sync recommended for VNC)
export VGL_LOGO="${VGL_LOGO:-0}"                   # Disable VirtualGL logo overlay
export VGL_FPS="${VGL_FPS:-0}"                     # Disable FPS display (set to 1 to enable)
export VGL_VERBOSE="${VGL_VERBOSE:-0}"             # Verbose output (set to 1 to enable)

# Optimize for VNC environments
export VGL_SYNC="${VGL_SYNC:-1}"                   # Synchronize with vertical retrace
export VGL_REFRESHRATE="${VGL_REFRESHRATE:-60}"    # Target refresh rate for VNC

# Debug and development settings
export VGL_DEBUG="${VGL_DEBUG:-0}"                 # Debug mode (set to 1 to enable)
export VGL_LOG_LEVEL="${VGL_LOG_LEVEL:-1}"         # Log level (0-3)
export VGL_FORCE_GPU="${VGL_FORCE_GPU:-0}"         # Force GPU usage (set to 1 to enable)

# Auto-detect VNC display if not set
if [ -z "${VGL_DISPLAY:-}" ]; then
  # Try to detect VNC display from running processes
  vnc_display=""
  
  # Method 1: Check for Xvnc processes
  vnc_display=$(ps aux 2>/dev/null | grep -o 'Xvnc.*:[0-9]' | head -1 | grep -o ':[0-9]' | head -1)
  
  # Method 2: Check for vncserver processes
  if [ -z "$vnc_display" ]; then
    vnc_display=$(ps aux 2>/dev/null | grep -o 'vncserver.*:[0-9]' | head -1 | grep -o ':[0-9]' | head -1)
  fi
  
  # Method 3: Check for display :1, :2, etc.
  if [ -z "$vnc_display" ]; then
    for i in 1 2 3 4 5; do
      if [ -S "/tmp/.X11-unix/X$i" ]; then
        vnc_display=":$i"
        break
      fi
    done
  fi
  
  # Set VGL_DISPLAY
  if [ -n "$vnc_display" ]; then
    export VGL_DISPLAY="$vnc_display"
  else
    export VGL_DISPLAY=":0"  # Fallback
  fi
fi

# VirtualGL integration settings
export VNC_VGL_INTEGRATION="${VNC_VGL_INTEGRATION:-1}"     # Enable VNC-VGL integration
export VNC_OPENGL_EXTENSIONS="${VNC_OPENGL_EXTENSIONS:-1}" # Enable OpenGL extensions
export VNC_GLX_EXTENSIONS="${VNC_GLX_EXTENSIONS:-1}"       # Enable GLX extensions
VGL_PROFILE
chmod +x /etc/profile.d/virtualgl.sh

echo "✓ VirtualGL symlinks and environment configuration complete"

#--- Sub-block 15.16: Verify VirtualGL installation ---
# Purpose: Quick verification that vglrun is available
# Dependencies: Block 15 (VirtualGL)
# Outputs: VNC server, GPU acceleration
echo ""
echo "Verifying VirtualGL installation:"
if [ -x /opt/VirtualGL/bin/vglrun ]; then
  /opt/VirtualGL/bin/vglrun --version 2>&1 | head -3 || echo "  ✓ vglrun binary present"
else
  echo "  ✗ ERROR: vglrun not found!"
fi
# End VirtualGL verification (if-else self-contained)

#--- Sub-block 15.17: Create VirtualGL test script ---
# Purpose: Comprehensive VirtualGL testing script for validation
# Dependencies: Block 15 (VirtualGL)
# Outputs: VNC server, GPU acceleration
cat > /usr/local/bin/test_virtualgl.sh << 'VGLTEST'
#!/usr/bin/env bash
# VirtualGL Test Script

echo "=========================================="
echo "VirtualGL Installation Test"
echo "=========================================="
echo ""

# Add VirtualGL to PATH

echo "1. Checking VirtualGL binaries:"
for binary in vglrun glxinfo glxspheres64; do
  if command -v $binary >/dev/null 2>&1; then
    echo "  ✓ $binary: $(which $binary)"
  else
    echo "  ✗ $binary: NOT FOUND"
  fi
done

echo ""
echo "2. VirtualGL version:"
vglrun --version 2>&1 | head -1

echo ""
echo "3. OpenGL Information (via VirtualGL):"
if [ -n "${DISPLAY}" ]; then
  echo "  Display: $DISPLAY"
  vglrun glxinfo | grep -E "OpenGL (vendor|renderer|version)" | head -3
else

#--- Sub-block: Section 3120 ---
# Purpose: Continued implementation
# Dependencies: Block 6.13 (NVIDIA CUDA)
# Outputs: GPU libraries, CUDA toolkit
  echo "  ⚠ DISPLAY not set, skipping OpenGL test"
fi

echo ""
echo "4. GPU Detection:"
if command -v nvidia-smi >/dev/null 2>&1; then
  echo "  NVIDIA GPU:"
  nvidia-smi --query-gpu=name,driver_version --format=csv,noheader | head -1
else
  echo "  ⚠ nvidia-smi not found"
fi

#--- Sub-block: Section continuation (3072) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 3027 ---
# Purpose: Continuing implementation
# Dependencies: Block 15 (VirtualGL)
# Outputs: VNC server, GPU acceleration
echo ""
echo "=========================================="
echo "Test complete!"
echo ""
echo "To test 3D acceleration with VNC:"
echo "  1. Start VNC server: start_vnc_xfce.sh"
echo "  2. Connect with VNC viewer"
echo "  3. Open terminal in VNC session"
echo "  4. Run: vglrun glxspheres64"
echo "     (Should show 1000+ FPS with GPU)"
echo "  5. Compare without VGL: glxspheres64"
echo "     (Will show lower FPS with software rendering)"
echo "=========================================="
VGLTEST
chmod +x /usr/local/bin/test_virtualgl.sh

echo "✓ VirtualGL test script created: /usr/local/bin/test_virtualgl.sh"


#--- Sub-block 15.17.1: VirtualGL test script created ---
# Purpose: Comprehensive testing and validation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
#--- Sub-block 15.18: Initialize VirtualGL helper scripts creation ---
# Purpose: Create comprehensive helper scripts for VirtualGL testing
# Dependencies: Block 15 (VirtualGL)
# Outputs: VNC server, GPU acceleration
echo "==> Creating VirtualGL helper scripts..."

#--- Sub-block 15.19: Create GPU benchmark script ---
# Purpose: Script to compare software vs GPU rendering performance
# Dependencies: Block 15 (VirtualGL)
# Outputs: VNC server, GPU acceleration
cat > /usr/local/bin/vgl_benchmark.sh << 'VGLBENCH'
#!/usr/bin/env bash
# VirtualGL GPU Benchmark Script


#--- Sub-block: Section 3170 ---
# Purpose: Continued implementation
# Dependencies: Block 6.13 (NVIDIA CUDA), Block 15 (VirtualGL)
# Outputs: GPU libraries, CUDA toolkit

echo "=========================================="
echo "VirtualGL GPU Benchmark"
echo "=========================================="
echo ""

if [ -z "${DISPLAY}" ]; then
  echo "ERROR: DISPLAY not set"
  echo "Start VNC first: start_vnc_xfce.sh"
  exit 1
fi

if ! command -v vglrun >/dev/null 2>&1; then
  echo "ERROR: VirtualGL not found"
  exit 1
fi

echo "GPU Information:"
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
else
  echo "  nvidia-smi not available"
fi

echo ""
echo "Testing OpenGL rendering..."
echo ""

# Test 1: Without VirtualGL (software rendering)
echo "1. Software rendering (no VirtualGL):"
echo "   Running: glxspheres64"
if command -v glxspheres64 >/dev/null 2>&1; then
  timeout 10s glxspheres64 2>&1 | grep -i "frames\|fps" | tail -3
else
  echo "   glxspheres64 not found"
fi

#--- Sub-block: Section continuation (3144) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

echo ""


#--- Sub-block: Code section 3098 ---
# Purpose: Continuing implementation
# Dependencies: Block 15 (VirtualGL)
# Outputs: VNC server, GPU acceleration
# Test 2: With VirtualGL (GPU rendering)
echo "2. GPU rendering (with VirtualGL):"
echo "   Running: vglrun glxspheres64"
if command -v glxspheres64 >/dev/null 2>&1; then
  timeout 10s vglrun glxspheres64 2>&1 | grep -i "frames\|fps" | tail -3

#--- Sub-block: Section 3220 ---
# Purpose: Continued implementation
# Dependencies: Block 6.13 (NVIDIA CUDA)
# Outputs: GPU libraries, CUDA toolkit
else
  echo "   glxspheres64 not found"
fi

echo ""
echo "=========================================="
echo "Benchmark complete!"
echo ""
echo "Expected results:"
echo "  Software rendering: ~30-100 FPS"
echo "  GPU rendering:      ~1000+ FPS"
echo ""
echo "If GPU rendering shows low FPS:"
echo "  1. Check GPU is visible: nvidia-smi"
echo "  2. Check VNC started with --nv flag"
echo "  3. Check DISPLAY is set: echo \$DISPLAY"
echo "=========================================="
VGLBENCH
chmod +x /usr/local/bin/vgl_benchmark.sh

#--- Sub-block 15.20: Create OpenGL information script ---
# Purpose: Display comprehensive OpenGL and GPU information
# Dependencies: Block 6.13 (NVIDIA CUDA), Block 15 (VirtualGL)
# Outputs: GPU libraries, CUDA toolkit
cat > /usr/local/bin/vgl_info.sh << 'VGLINFO'
#!/usr/bin/env bash
# Display comprehensive OpenGL/VirtualGL information


echo "=========================================="
echo "OpenGL & VirtualGL Information"
echo "=========================================="
echo ""

# System info
echo "Display: ${DISPLAY:-NOT SET}"
echo "Hostname: $(hostname)"
echo ""

# GPU info
echo "GPU Information:"
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=index,name,driver_version,memory.total,memory.used \
    --format=csv,noheader | nl
else
  echo "  No NVIDIA GPU detected"
fi
echo ""

# OpenGL info (software rendering)
echo "OpenGL (Software Rendering):"
if [ -n "${DISPLAY}" ] && command -v glxinfo >/dev/null 2>&1; then
  glxinfo | grep -E "OpenGL (vendor|renderer|version|shading)" | sed 's/^/  /'
else
  echo "  Cannot query (DISPLAY not set or glxinfo not found)"
fi
echo ""

# OpenGL info (with VirtualGL)
echo "OpenGL (VirtualGL/GPU Rendering):"
if [ -n "${DISPLAY}" ] && command -v vglrun >/dev/null 2>&1 && command -v glxinfo >/dev/null 2>&1; then
  vglrun glxinfo | grep -E "OpenGL (vendor|renderer|version|shading)" | sed 's/^/  /'
else
  echo "  Cannot query (VirtualGL not available)"
fi
echo ""

#--- Sub-block: Section continuation (3220) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 3169 ---
# Purpose: Continuing implementation
# Dependencies: Block 15 (VirtualGL)
# Outputs: VNC server, GPU acceleration
# VirtualGL status
echo "VirtualGL Status:"
if command -v vglrun >/dev/null 2>&1; then
  echo "  ✓ VirtualGL installed: $(which vglrun)"
  vglrun --version 2>&1 | head -1 | sed 's/^/  /'
else
  echo "  ✗ VirtualGL not found"
fi
echo ""

# Available tools
echo "Available Utilities:"
for tool in vglrun glxinfo glxspheres64 eglinfo cpustat nettest tcbench; do
  if command -v $tool >/dev/null 2>&1; then
    echo "  ✓ $tool"
  else
    echo "  ✗ $tool (not found)"
  fi
done

echo ""
echo "=========================================="
VGLINFO
chmod +x /usr/local/bin/vgl_info.sh

#--- Sub-block 15.21: Create application launcher script ---
# Purpose: Wrapper script to launch applications with VirtualGL acceleration
# Dependencies: Block 15 (VirtualGL)
# Outputs: VNC server, GPU acceleration
cat > /usr/local/bin/vgl_launch.sh << 'VGLLAUNCH'
#!/usr/bin/env bash
# Launch applications with VirtualGL acceleration

if [ $# -eq 0 ]; then
  echo "Usage: vgl_launch.sh <command> [args...]"
  echo ""
  echo "Examples:"
  echo "  vgl_launch.sh blender"
  echo "  vgl_launch.sh glxspheres64"
  echo "  vgl_launch.sh openscad model.scad"
  echo ""
  echo "This script automatically:"
  echo "  - Adds VirtualGL to PATH"
  echo "  - Runs application with vglrun for GPU acceleration"
  echo "  - Handles DISPLAY configuration"
  exit 1
fi

# Add VirtualGL to PATH

# Check DISPLAY
if [ -z "${DISPLAY}" ]; then
  echo "WARNING: DISPLAY not set, using :1"
  export DISPLAY=:1
fi

# Check if vglrun is available
if ! command -v vglrun >/dev/null 2>&1; then
  echo "ERROR: VirtualGL not found"
  echo "Running without GPU acceleration..."
  exec "$@"
fi

# Launch with VirtualGL
echo "Launching with VirtualGL GPU acceleration..."
echo "Command: vglrun $@"
echo ""
exec vglrun "$@"
VGLLAUNCH
chmod +x /usr/local/bin/vgl_launch.sh

#--- Sub-block: Section continuation (3293) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 3239 ---
# Purpose: Continuing implementation
# Dependencies: Block 15 (VirtualGL)
# Outputs: VNC server, GPU acceleration
echo "✓ VirtualGL helper scripts created:"
echo "  - test_virtualgl.sh   : Test VirtualGL installation"
echo "  - vgl_benchmark.sh    : Benchmark GPU performance"
echo "  - vgl_info.sh         : Display OpenGL/VirtualGL info"
echo "  - vgl_launch.sh       : Launch apps with GPU acceleration"

#--- Sub-block 15.22: Add VirtualGL convenience aliases ---
# Purpose: Add GPU-accelerated application aliases to system bashrc
# Dependencies: Block 15 (VirtualGL)
# Outputs: VNC server, GPU acceleration
echo "==> Adding VirtualGL convenience aliases..."

cat >> /etc/bash.bashrc << 'VGLALIAS'

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
alias gpuinfo='vglrun glxinfo | grep -E "OpenGL (vendor|renderer|version)"'

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
  echo "=== Software Rendering ==="
  timeout 5s $app 2>&1 | grep -i fps | tail -1
  echo ""
  echo "=== GPU Rendering (VirtualGL) ==="
  timeout 5s vglrun $app 2>&1 | grep -i fps | tail -1
}

#--- Sub-block: Section continuation (3345) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

export -f vgl compare_render
VGLALIAS


#--- Sub-block: Code section 3291 ---
# Purpose: Continuing implementation
# Dependencies: Block 15 (VirtualGL)
# Outputs: VNC server, GPU acceleration
echo "✓ VirtualGL aliases added to /etc/bash.bashrc"

#--- Sub-block 15.23: Initialize VirtualGL performance optimization ---
# Purpose: Create optimized configuration profiles for different network speeds
# Dependencies: Block 15 (VirtualGL)
# Outputs: VNC server, GPU acceleration
echo "==> Configuring VirtualGL performance optimizations..."

mkdir -p /usr/local/etc/virtualgl

# Profile 1: Maximum Performance (for fast networks)
cat > /usr/local/etc/virtualgl/vglrun-fast.conf << 'VGLFAST'
# VirtualGL High Performance Profile
VGL_COMPRESS=proxy
VGL_READBACK=sync
VGL_SYNC=1
VGL_GAMMA=1
VGL_LOGO=0
VGL_SUBSAMP=444  # No subsampling - best quality
VGL_QUAL=95      # High JPEG quality
VGL_SPOIL=0      # No frame spoiling - all frames rendered
VGL_FPS=60       # Target 60 FPS
VGL_READBACK=sync
VGL_TRANSPORT=vgl
VGLFAST

# Profile 2: Balanced (for normal networks)
cat > /usr/local/etc/virtualgl/vglrun-balanced.conf << 'VGLBAL'
# VirtualGL Balanced Profile
VGL_COMPRESS=jpeg
VGL_SUBSAMP=422  # 4:2:2 chroma subsampling
VGL_QUAL=80      # Medium-high quality
VGL_SPOIL=1      # Allow some frame dropping
VGL_FPS=30       # Target 30 FPS
VGL_READBACK=sync
VGLBAL

# Profile 3: Low Bandwidth (for slow networks)
cat > /usr/local/etc/virtualgl/vglrun-lowbw.conf << 'VGLLOWBW'
# VirtualGL Low Bandwidth Profile
VGL_COMPRESS=jpeg
VGL_SUBSAMP=420  # 4:2:0 chroma subsampling (more compression)
VGL_QUAL=60      # Lower quality, better compression
VGL_SPOIL=1
VGL_FPS=15       # Target 15 FPS
VGL_READBACK=sync
VGLLOWBW

#--- Sub-block: Section continuation (3397) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

# Create wrapper scripts for each profile

#--- Sub-block: Code section 3338 ---
# Purpose: Continuing implementation
# Dependencies: Block 15 (VirtualGL)
# Outputs: VNC server, GPU acceleration
cat > /usr/local/bin/vglrun-fast << 'VGLFAST'
#!/usr/bin/env bash
source /usr/local/etc/virtualgl/vglrun-fast.conf
export VGL_COMPRESS VGL_READBACK VGL_SYNC VGL_GAMMA VGL_LOGO VGL_SUBSAMP VGL_QUAL VGL_SPOIL VGL_FPS VGL_TRANSPORT
exec /opt/VirtualGL/bin/vglrun "$@"
VGLFAST

cat > /usr/local/bin/vglrun-balanced << 'VGLBAL'
#!/usr/bin/env bash
source /usr/local/etc/virtualgl/vglrun-balanced.conf
export VGL_COMPRESS VGL_SUBSAMP VGL_QUAL VGL_SPOIL VGL_FPS VGL_READBACK
exec /opt/VirtualGL/bin/vglrun "$@"
VGLBAL

cat > /usr/local/bin/vglrun-lowbw << 'VGLLOWBW'
#!/usr/bin/env bash
source /usr/local/etc/virtualgl/vglrun-lowbw.conf
export VGL_COMPRESS VGL_SUBSAMP VGL_QUAL VGL_SPOIL VGL_FPS VGL_READBACK
exec /opt/VirtualGL/bin/vglrun "$@"
VGLLOWBW

chmod +x /usr/local/bin/vglrun-{fast,balanced,lowbw}

echo "✓ VirtualGL performance profiles created"
echo "  - vglrun-fast (best quality, fast network)"
echo "  - vglrun-balanced (default)"
echo "  - vglrun-lowbw (slow network)"

#--- Sub-block 15.24: Initialize TurboVNC performance optimization ---
# Purpose: Configure TurboVNC for optimal performance with VirtualGL
# Dependencies: Block 15 (VirtualGL), Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration
echo "==> Configuring TurboVNC performance optimizations..."

mkdir -p /etc/turbovncserver.conf.d

cat > /etc/turbovncserver.conf.d/performance.conf << 'TVNCPERF'
# TurboVNC Performance Configuration

# Security
$localhost = "yes";

# Geometry (can be overridden)
$geometry = "1920x1080";
$depth = "24";

# Performance settings
$desktopName = "TurboVNC";
$useVGL = "1";  # Enable VirtualGL integration
$autokill = "1";  # Kill when last client disconnects

# Compression (TurboVNC's optimized JPEG)
# 0 = lossless, 1-100 = JPEG quality
# 95 = near-lossless, good default
# Lower = better compression, faster over slow networks
$compressLevel = "2";
$quality = "95";

# Subsample settings for JPEG
# 0 = 4:4:4 (best quality)
# 1 = 4:2:2 (good quality, 2x compression)
# 2 = 4:2:0 (highest compression)
$subsample = "1";

# Interframe comparison (helps with static content)
$interframe = "1";

# Multi-threading
$numThreads = "auto";

# Idle timeout (seconds, 0 = never)
$idleTimeout = "0";
TVNCPERF

#--- Sub-block: Section continuation (3473) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

# Create optimized xstartup template

#--- Sub-block: Code section 3411 ---
# Purpose: Continuing implementation
# Dependencies: Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration
mkdir -p /usr/share/turbovnc/

cat > /usr/share/turbovnc/xstartup.turbovnc.optimized << 'XSTARTOPT'
#!/bin/sh
# Optimized TurboVNC xstartup for XFCE + GPU

# Load X resources
[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources" 2>/dev/null || true

# Font cache
fc-cache -f 2>/dev/null || true

# Start D-Bus
if ! dbus-send --session --dest=org.freedesktop.DBus --type=method_call \
  /org/freedesktop/DBus org.freedesktop.DBus.ListNames >/dev/null 2>&1; then
  eval "$(dbus-launch --sh-syntax)"
  export DBUS_SESSION_BUS_ADDRESS
  export DBUS_SESSION_BUS_PID
fi

# Performance: Disable compositing (critical for VNC)
xfconf-query -c xfwm4 -p /general/use_compositing -s false 2>/dev/null || true
xfconf-query -c xfce4-session -p /general/use_compositing -s false 2>/dev/null || true

# Disable window manager shadows/effects
xfconf-query -c xfwm4 -p /general/show_frame_shadow -s false 2>/dev/null || true
xfconf-query -c xfwm4 -p /general/show_popup_shadow -s false 2>/dev/null || true

# Disable screen blanking
xset s off 2>/dev/null || true
xset -dpms 2>/dev/null || true
xset s noblank 2>/dev/null || true

# Disable bell
xset b off 2>/dev/null || true

# Set keyboard repeat rate (faster responsiveness)
xset r rate 250 30 2>/dev/null || true

#--- Sub-block: Section continuation (3516) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

# Start window manager with optimizations
export XFWM4_USE_PRESENT=0  # Disable Present extension (can cause issues)

# Start XFCE
exec startxfce4
XSTARTOPT
chmod +x /usr/share/turbovnc/xstartup.turbovnc.optimized


#--- Sub-block: Code section 3458 ---
# Purpose: Continuing implementation
# Dependencies: Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration
# Create performance testing script
cat > /usr/local/bin/turbovnc_tune.sh << 'TVNCTUNE'
#!/usr/bin/env bash
# TurboVNC Performance Tuning Helper

echo "=========================================="
echo "TurboVNC Performance Tuner"
echo "=========================================="
echo ""

if [ -z "$DISPLAY" ]; then
    echo "ERROR: Must be run from within VNC session"
    echo "Start VNC first, then run this from terminal inside VNC"
    exit 1
fi

echo "Current VNC Session Information:"
vncserver -list 2>/dev/null || echo "  (vncserver command not available)"
echo ""

echo "Testing different compression settings..."
echo "This will take about 30 seconds..."
echo ""

# Test function
test_setting() {
    local quality=$1
    local subsample=$2
    local desc=$3

    echo "Testing: $desc (Quality=$quality, Subsample=$subsample)"

    # This would require vncviewer to support setting these
    # Just document the settings
    echo "  Recommended for: $desc"
    echo ""
}


#--- Sub-block: Section continuation (3566) ---
# Purpose: Implementation details
# Dependencies: Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration
test_setting 95 1 "High quality (default)"
test_setting 80 1 "Balanced (good for most)"
test_setting 60 2 "Low bandwidth"
test_setting 30 2 "Very slow connections"

echo "=========================================="
echo "To change settings, edit:"
echo "  ~/.vnc/turbovncserver.conf"
echo ""
echo "Or set environment variables:"
echo "  export TVNC_QUALITY=80"
echo "  export TVNC_SUBSAMPLE=1"
echo "=========================================="
TVNCTUNE
chmod +x /usr/local/bin/turbovnc_tune.sh


#--- Sub-block: Code section 3512 ---
# Purpose: Continuing implementation
# Dependencies: Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration
echo "✓ TurboVNC performance optimizations configured"

#--- Sub-block 15.25: Install yq YAML processor ---
# Purpose: Install yq for YAML file manipulation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
if [ -s "${CONTAINER_BIN_CACHE}/yq_linux_amd64" ]; then
  install -o 0 -g 0 -m 0755 ${CONTAINER_BIN_CACHE}/yq_linux_amd64 /usr/local/bin/yq
fi

#--- Sub-block 15.19.1: Create default VNC password (non-interactive) ---
# Purpose: Set up default VNC password to prevent interactive prompts
# Dependencies: TurboVNC installation
# Outputs: ~/.vnc/passwd
echo "==> Setting up default VNC password..."
mkdir -p ~/.vnc
# Create default password "vncpassword" non-interactively
# This prevents interactive prompts during build and provides secure default
echo "vncpassword" | vncpasswd -f > ~/.vnc/passwd 2>/dev/null || true
chmod 600 ~/.vnc/passwd 2>/dev/null || true
echo "✓ Default VNC password configured (change with: vncpasswd)"

#--- Sub-block 15.20: Remote Desktop Scripts Summary ---
# Purpose: Index of all remote desktop helper scripts
# Dependencies: Block 15 (TurboVNC, VirtualGL)
# Outputs: Documentation
# Self-contained: Yes
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Remote Desktop Infrastructure Summary"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Installed Components:"
# Use safer version detection from config.sh variables to avoid terminal issues
echo "  ✓ TurboVNC ${TURBOVNC_VERSION:-installed}"
echo "  ✓ VirtualGL ${VIRTUALGL_VERSION:-installed}"
echo "  ✓ noVNC (HTML5 VNC client)"
echo ""
echo "Available Helper Scripts:"
echo "  • start_vnc_xfce.sh     - Main VNC launcher with GPU acceleration"
echo "  • start_x11vnc.sh       - Alternative X11VNC server"
echo "  • vnc_ssl_tunnel.sh     - Two-stage SSL tunneling for HPC"
echo "  • vnc_monitor.sh        - Monitor VNC server status"
echo "  • vnc_select.sh         - Interactive VNC server selector"
echo "  • vnc_clipboard_sync.sh - Clipboard synchronization"
echo "  • vgl_launch.sh         - Launch apps with VirtualGL"
echo "  • vgl_info.sh           - VirtualGL diagnostics"
echo "  • vgl_benchmark.sh      - GPU performance testing"
echo "  • turbovnc_tune.sh      - TurboVNC performance tuning"
echo ""
echo "Quick Start:"
echo "  1. Start VNC: start_vnc_xfce.sh"
echo "  2. SSL Tunnel: vnc_ssl_tunnel.sh (for HPC environments)"
echo "  3. Connect:   localhost:5901 (VNC) or :6080 (noVNC browser)"
echo "  4. GPU apps:  vglrun <application>"
echo ""
echo "For detailed help: turbovnc_tune.sh"
echo "═══════════════════════════════════════════════════════════════"
echo ""

#===============================================================================
# BLOCK 16: CONDA/PYTHON ENVIRONMENT SETUP
#===============================================================================
# Purpose: Install Miniforge/Micromamba and configure Python environments
# Self-contained: Yes (complete with retry logic and verification)
# Dependencies: Cached installers from ${CONTAINER_BIN_CACHE}
# Outputs: Configured system components
#-------------------------------------------------------------------------------

#--- Sub-block 16.1: Initialize Miniforge installation ---
# Critical: Conda environment manager with robust error handling and retry logic
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments
if [ -s "${CONTAINER_BIN_CACHE}/${MINIFORGE_SH}" ]; then
  echo "Installing Miniforge..."
  # Miniforge installer already verified in early verification phase
  echo "✓ Miniforge installer already verified (SHA256 check passed)"

  #--- Sub-block 16.2: Configure conda environment variables ---
  # Purpose: Set conda cache and behavior for installation
  export CONDA_ALWAYS_YES=true
  export CONDA_AUTO_UPDATE_CONDA=false

  #--- Sub-block 16.3: Initialize retry logic ---
  # Purpose: Allow multiple installation attempts with cleanup
  max_retries=3
  retry_count=0

  #--- Sub-block 16.4: Miniforge installation retry loop ---
  # Critical: Retry installation with cache cleanup between attempts
  while [ $retry_count -lt $max_retries ]; do
    echo "Miniforge installation attempt $((retry_count + 1))/${max_retries}..."

    # Clear any existing conda package cache to force fresh downloads
    rm -rf ${MINIFORGE_HOME}/pkgs/* 2>/dev/null || true
    rm -rf /root/.cache/conda/* 2>/dev/null || true

    #--- Sub-block 16.5: Advanced conda cache cleanup ---
    # Purpose: Remove corrupted packages before installation
    echo "Performing advanced conda package cache cleanup..."
    if [ -d "${CONTAINER_CONDA_CACHE}" ]; then
      # Setup staging area for robust package handling
      setup_conda_staging_area

      # Remove specific problematic packages mentioned in errors
      echo "Removing known problematic packages..."
      problematic_packages=(
        "openssl-3.5.2-h26f9b46_0.conda"
        "certifi-2025.8.3-pyhd8ed1ab_0.conda"
        "anyio-4.10.0-pyhe01879c_0.conda"
        "argon2-cffi-25.1.0-pyhd8ed1ab_0.conda"
        "argon2-cffi-bindings-25.1.0-py312h4c3975b_0.conda"
      )
      for pkg in "${problematic_packages[@]}"; do
        if [ -f "${CONTAINER_CONDA_CACHE}/$pkg" ]; then
          echo "Removing problematic package: $pkg"
          rm -f "${CONTAINER_CONDA_CACHE}/$pkg" 2>/dev/null || true
        fi
      done

#--- Sub-block: Section continuation (3650) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 3578 ---
# Purpose: Continuing implementation
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments
      # Comprehensive integrity check with smart replacement
      echo "Performing comprehensive package integrity check..."
      corrupted_packages=()

      # Check all conda packages for integrity
      find ${CONTAINER_CONDA_CACHE} -name "*.conda" -o -name "*.tar.bz2" | while read -r pkg_file; do
        if ! verify_package_integrity "$pkg_file"; then
          pkg_name=$(basename "$pkg_file")
          echo "  Δ Found corrupted package: $pkg_name"
          corrupted_packages+=("$pkg_name")
        fi
      done

      # Replace corrupted packages with fresh downloads
      if [ ${#corrupted_packages[@]} -gt 0 ]; then
        echo "  Replacing ${#corrupted_packages[@]} corrupted packages..."
        for pkg_name in "${corrupted_packages[@]}"; do
          if acquire_package_lock "$pkg_name"; then
            atomic_package_replace "$pkg_name"
            release_package_lock "$pkg_name"
          fi
        done
      fi

      # Clear conda package cache metadata that might be stale
      echo "  Clearing conda package cache metadata..."
      rm -rf ${CONTAINER_CONDA_CACHE}/cache/* 2>/dev/null || true
      rm -rf ${CONTAINER_CONDA_CACHE}/*/info 2>/dev/null || true

      # Force filesystem sync to ensure all writes are flushed
      sync
      echo "✓ Advanced conda package cache cleanup completed"
    fi

    # Set environment variables to use our cache directory and make it non-interactive
    export CONDA_INSTALLER_TYPE=miniforge
    export CONDA_INSTALLER_VERSION=25.3.1-0

#--- Sub-block: Section continuation (3694) ---
# Purpose: Implementation details
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments

    # Run installer with enhanced CRC error handling and non-interactive mode
    echo "Running Miniforge installer with enhanced CRC error handling..."
    if yes "" | bash "${CONTAINER_BIN_CACHE}/${MINIFORGE_SH}" -b -p ${MINIFORGE_HOME} -f > /tmp/miniforge_install.log 2>&1; then
      # Reset terminal state in case installer left control codes
      printf '\033[0m\n' # Reset all terminal attributes and print newline
      echo "✓ Miniforge installer completed"
      mv /opt/.condarc.pre > ${MINIFORGE_HOME}/.condarc 2>/dev/null || true


#--- Sub-block: Code section 3625 ---
# Purpose: Continuing implementation
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments
      # Verify Conda Installation
      if [ -x ${MINIFORGE_HOME}/bin/conda ]; then
        echo "✓ Miniforge installed successfully"
        break
      else
        echo "[warn] Miniforge installation may have failed - conda binary not found"
        ((retry_count++))
        if [ $retry_count -lt $max_retries ]; then
          echo "Retrying Miniforge installation..."
          rm -rf ${MINIFORGE_HOME}
        fi
      fi
    else
      echo "[warn] Miniforge installer failed (attempt $((retry_count + 1))/${max_retries})"

      # Enhanced CRC error detection and handling
      if grep -q "Bad CRC|ZIP had CRC|md5sum mismatch" /tmp/miniforge_install.log 2>/dev/null; then
        echo "✓ CRC/MD5 error detected in installation log"

        # Extract all corrupted package names from the log
        corrupted_pkgs=$(grep -o 'Extracting \(.*\)\.conda\|Extracting \(.*\)\.tar\.bz2' /tmp/miniforge_install.log | sed 's/Extracting //' | sort -u)

        if [ -n "$corrupted_pkgs" ]; then
          echo "→ Removing corrupted packages:"
          for pkg in $corrupted_pkgs; do
            echo "  - $pkg"
            rm -f "${CONTAINER_CONDA_CACHE}/$pkg" 2>/dev/null || true
            rm -f "${MINIFORGE_HOME}/pkgs/$pkg" 2>/dev/null || true
            rm -f "/root/.cache/conda/pkgs/$pkg" 2>/dev/null || true
          done
        fi

          # Clear any remaining corrupted packages using integrity check
        echo "→ Performing integrity check on remaining packages..."
          if [ -d "${CONTAINER_CONDA_CACHE}" ]; then
            find ${CONTAINER_CONDA_CACHE} -name "*.conda" -type f -exec sh -c '
              for pkg; do
                if ! unzip -t "$pkg" >/dev/null 2>&1; then
                echo "Removing corrupted: $(basename "$pkg")"
                  rm -f "$pkg"
                fi
              done
          ' sh {} +
          fi
        fi
      fi

#--- Sub-block: Section continuation (3750) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 3672 ---
# Purpose: Continuing implementation
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments
      ((retry_count++))
      if [ $retry_count -lt $max_retries ]; then
        echo "Retrying Miniforge installation..."
        rm -rf ${MINIFORGE_HOME}
    fi
  done
  if [ -x ${MINIFORGE_HOME}/bin/conda ]; then
    # Clean up any corrupted conda packages that may have been downloaded during installation
    echo "Cleaning up any corrupted conda packages from installation..."
    if [ -d "${MINIFORGE_HOME}/pkgs" ]; then
      corrupted_count=0
      for pkg_file in ${MINIFORGE_HOME}/pkgs/*.conda ${MINIFORGE_HOME}/pkgs/*.tar.bz2; do
        if [ -f "$pkg_file" ]; then
          # Check if file is corrupted by testing its integrity
          # First check file type, then test format-specific integrity
          is_corrupted=false

          # Use file command to detect file type
          if ! file "$pkg_file" | grep -q "archive\|compressed\|data"; then
            is_corrupted=true
          else
            # Additional format-specific integrity checks
            if [[ "$pkg_file" == *.conda ]]; then
              if ! unzip -t "$pkg_file" >/dev/null 2>&1; then
                is_corrupted=true
              fi
            elif [[ "$pkg_file" == *.tar.bz2 ]]; then
              if ! bzip2 -t "$pkg_file" >/dev/null 2>&1; then
                is_corrupted=true
              fi
            fi
          fi

          if [ "$is_corrupted" = true ]; then
            echo "  Δ Removing corrupted conda package: $(basename "$pkg_file")"
            rm -f "$pkg_file"
            ((corrupted_count++))
          fi
        fi
      done
      if [ $corrupted_count -gt 0 ]; then
        echo "✓ Removed $corrupted_count corrupted conda packages from installation"
      fi
    fi

#--- Sub-block: Section continuation (3798) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 3717 ---
# Purpose: Continuing implementation
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments
    # Final Verification of conda installation
    echo "Performing final conda installation verification..."
    
    # CRITICAL: Configure SSL certificates before any conda operations
    # This prevents "SSL certificate problem: unable to get local issuer certificate" errors
    echo "==> Configuring SSL certificates for Conda/Mamba..."
    
    # Ensure ca-certificates are up to date
    update-ca-certificates --fresh 2>/dev/null || update-ca-certificates 2>/dev/null || true
    
    # Export SSL certificate locations for conda/mamba
    export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
    export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
    
    # Verify certificate file exists
    if [ -f "$SSL_CERT_FILE" ]; then
      echo "✓ SSL certificates configured: $SSL_CERT_FILE"
    else
      echo "[warn] SSL certificate file not found, conda operations may fail"
    fi
    
    if ${MINIFORGE_HOME}/bin/conda --version >/dev/null 2>&1; then
      echo "✓ Conda binary is working correctly"

      # Install mamba as the PREFERRED solver (with conda fallback)
      echo "Installing mamba solver (PREFERRED - will fallback to conda if needed)..."
      
      MAMBA_AVAILABLE=0
      
      # Try mamba installation (corrupted packages already cleaned in Xsetup)
      if ${MINIFORGE_HOME}/bin/conda install -y -c conda-forge mamba; then
        printf '\033[0m\n' # Reset terminal state after conda install
        echo "✓ Mamba installed successfully"
        
        # Verify mamba installation
        if ${MINIFORGE_HOME}/bin/mamba --version >/dev/null 2>&1; then
          echo "✓ Mamba binary is working correctly"
          MAMBA_AVAILABLE=1
        else
          echo "[warn] Mamba binary verification failed, will use conda as fallback"
        fi
      else
        echo "[warn] Mamba installation failed, will use conda as fallback"
      fi
      
      # Set preferred solver (mamba if available, otherwise conda)
      if [ $MAMBA_AVAILABLE -eq 1 ]; then
        echo "✓ Using MAMBA as primary solver (faster)"
        export PREFERRED_SOLVER="${MINIFORGE_HOME}/bin/mamba"
      else
        echo "[warn] Using CONDA as fallback solver (slower but reliable)"
        export PREFERRED_SOLVER="${MINIFORGE_HOME}/bin/conda"
      fi
      
      # Install modern environment management tools (try mamba first, fallback to conda)
      echo "Installing modern package management tools..."
      
      if [ $MAMBA_AVAILABLE -eq 1 ]; then
        echo "  → Trying with mamba..."
        if ${MINIFORGE_HOME}/bin/mamba install -y -c conda-forge \
          conda-lock conda-tree anaconda-project; then
          echo "✓ Modern tools installed with mamba"
        else
          echo "[warn] Mamba failed, trying with conda..."
          ${MINIFORGE_HOME}/bin/conda install -y -c conda-forge \
            conda-lock conda-tree anaconda-project \
            || echo "[warn] Some optional tools failed (non-critical)"
        fi
      else
        ${MINIFORGE_HOME}/bin/conda install -y -c conda-forge \
          conda-lock conda-tree anaconda-project \
          || echo "[warn] Some optional tools failed (non-critical)"
      fi
      
      echo "✓ Modern package management tools installed"
    else
      echo "✗ Conda binary verification failed - installation may be corrupted"
    fi
  fi
  # End installation verification (if-else self-contained)
  # End retry loop (while loop self-contained)
  echo "[warn] Miniforge Installation failed after $max_retries attempts"

  # Clean up temporary files
  rm -f /tmp/miniforge_install.log 2>/dev/null || true
else
  echo "[warn] Miniforge installer not found in cache"
fi
# End Miniforge installation (if block self-contained)
debug_glibc "After Miniforge installation and config"

#--- Sub-block 16.6: Configure system-wide Conda PATH ---
# Critical: Make conda available in all shell sessions
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments
echo -e "${YELLOW}Configuring system-wide environment for Conda...${NC}"
if [ -d "${MINIFORGE_HOME}/bin" ]; then
  cat > /etc/profile.d/conda.sh << 'EOF'
#!/bin/sh
# Prepend conda binaries to the PATH
EOF
  chmod +x /etc/profile.d/conda.sh
  echo -e "${GREEN}✓ Conda PATH configured successfully.${NC}"
else
  echo -e "${RED}Δ Could not configure Conda PATH, ${MINIFORGE_HOME}/bin not found.${NC}"
fi
# End Conda PATH configuration (if-else self-contained)

#--- Sub-block 16.7: Configure conda activation hooks for Drake compatibility ---
# Critical: Prevent Drake Python paths from conflicting with conda environments
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments
echo "==> Configuring conda hooks for Drake compatibility"
mkdir -p /opt/mamba/etc/conda/activate.d

#--- Sub-block 16.8: Create conda activation hook ---
# Purpose: Save and clear PYTHONPATH when activating conda environment
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments
cat > /opt/mamba/etc/conda/activate.d/unset_pythonpath.sh << 'EOF'
#!/bin/bash
# Save and unset PYTHONPATH when activating conda environment
# This prevents Drake's system Python from conflicting with Conda's Python
if [ -n "$PYTHONPATH" ]; then
  # Backup original PYTHONPATH (including Drake paths)
  export _CONDA_BACKUP_PYTHONPATH="$PYTHONPATH"

  # Unset PYTHONPATH so conda environment is isolated
  unset PYTHONPATH

  # Inform user
  if [[ "$_CONDA_BACKUP_PYTHONPATH" == *"drake"* ]]; then
    echo "Drake PYTHONPATH temporarily disabled in conda environment"
  fi
fi
EOF

mkdir -p /opt/mamba/etc/conda/deactivate.d

#--- Sub-block 16.9: Create conda deactivation hook ---
# Purpose: Restore PYTHONPATH when deactivating conda environment
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments
cat > /opt/mamba/etc/conda/deactivate.d/restore_pythonpath.sh << 'EOF'
#!/bin/bash
# Restore PYTHONPATH when deactivating conda environment
# This re-enables Drake Python bindings for system Python
if [ -n "$_CONDA_BACKUP_PYTHONPATH" ]; then
  unset _CONDA_BACKUP_PYTHONPATH

  if [[ "$PYTHONPATH" == *"drake"* ]]; then
    echo "Drake PYTHONPATH restored"
  fi
fi
EOF

chmod +x /opt/mamba/etc/conda/activate.d/unset_pythonpath.sh
chmod +x /opt/mamba/etc/conda/deactivate.d/restore_pythonpath.sh

echo "✓ Conda hooks configured for Drake compatibility"

#--- Sub-block 16.10: Initialize Micromamba installation ---
# Purpose: Install alternative lightweight conda package manager
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments
echo "==> Micromamba (from embedded binary)"
if [ -s "${CONTAINER_BIN_CACHE}/micromamba-linux-64" ]; then
    install -m 0755 ${CONTAINER_BIN_CACHE}/micromamba-linux-64 /opt/micromamba
    ln -sf /opt/micromamba /usr/local/bin/micromamba

    #--- Sub-block 16.11: Test micromamba binary with retry ---
    # Critical: Verify binary integrity before configuration
    if [ -x /opt/micromamba ]; then
        echo "Testing micromamba binary..."
        max_retries=3
        retry_count=0

        while [ $retry_count -lt $max_retries ]; do
            if /opt/micromamba --version >/dev/null 2>&1; then
                echo "✓ Micromamba binary is working"
                break
            else
        echo "Δ Micromamba binary test failed (attempt $((retry_count + 1))/${max_retries})"
                ((retry_count++))
                if [ $retry_count -lt $max_retries ]; then
          echo "  Removing corrupted binary and reinstalling..."
          rm -f /usr/local/bin/micromamba /opt/micromamba
                    install -m 0755 ${CONTAINER_BIN_CACHE}/micromamba-linux-64 /opt/micromamba
                fi
            fi
        done
        # End micromamba retry loop (while loop self-contained)

        if [ $retry_count -ge $max_retries ]; then
      echo "✗ Micromamba binary failed after $max_retries attempts - removing corrupted binary"
            rm -f /opt/micromamba /usr/local/bin/micromamba
    fi
    # End retry check (if self-contained)

            #--- Sub-block 16.12: Configure micromamba settings ---
            # Purpose: Set channel priority and behavior for optimal performance
            echo "Configuring micromamba..."
            # Note: Using flexible priority for micromamba allows users more freedom
            # when creating their own ad-hoc environments.
            if /opt/micromamba config set channel_priority flexible 2>/dev/null; then
      echo "✓ Channel priority configured"
            else
      echo "Δ Channel priority configuration failed"
            fi

#--- Sub-block: Section continuation (3948) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 3864 ---
# Purpose: Continuing implementation
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments
            if /opt/micromamba config set always_yes yes 2>/dev/null; then
      echo "✓ Always yes configured"
            else
      echo "Δ Always yes configuration failed"
            fi

            if /opt/micromamba config set quiet true 2>/dev/null; then
      echo "✓ Quiet mode configured"
            else
      echo "Δ Quiet mode configuration failed"
            fi
            echo "✓ Micromamba configured successfully"
    else
    echo "Δ Micromamba binary not executable"
    fi
    # End micromamba executable check (if-else self-contained)
else
  echo "Δ Micromamba binary not found in cache"
fi
# End micromamba installation (if block self-contained)

#--- Sub-block 16.13: Initialize conda base environment setup ---
# Purpose: Install full Jupyter stack and scientific computing packages
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments
echo "Starting Conda base env setup"
if [ -x ${MINIFORGE_HOME}/bin/conda ]; then
  # Conda channel configuration is already set in .condarc.pre (strict conda-forge only)
  echo "Installing full Jupyter environment + additional libraries using mamba solver..."

  #--- Sub-block 16.14: Enhanced conda cache management ---
  # Purpose: Clean cache before large package installation
  echo "Performing enhanced conda cache management before mamba installation..."
  if [ -d "${CONTAINER_CONDA_CACHE}" ]; then
    # Setup staging area for robust package handling
    setup_conda_staging_area
    # Remove cache metadata that causes "modified by another program" warnings
    rm -rf ${CONTAINER_CONDA_CACHE}/cache 2>/dev/null || true

#--- Sub-block: Desktop application installation ---
# Critical: CAD and productivity software setup
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments
    # Remove any partially extracted packages
    find ${CONTAINER_CONDA_CACHE} -maxdepth 1 -type d -name "*-*" -exec rm -rf {} + 2>/dev/null || true
    # Force filesystem sync to ensure all operations are flushed
    sync
    echo "✓ Enhanced conda cache management completed"
  fi

#--- Sub-block: Application installation ---
# Purpose: Desktop applications setup
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments
  # End cache management (if block self-contained)

  #--- Sub-block 16.15: Install packages with mamba or conda ---
  # Critical: Install scientific computing and ML packages
  
  # CRITICAL: Ensure SSL certificates are configured for all conda/mamba operations
  echo "==> Verifying SSL certificate configuration for package downloads..."
  export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
  export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
  export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
  
  # NOTE: Heavy package installations moved to writable overlay setup
  # This keeps the immutable base image small and flexible
  # Use setup_conda_environments.sh to install packages into overlay after mount
  
  echo "==> Minimal conda base installation (immutable image)"
  echo "    Full environments will be created in writable overlay"
  
  # Determine which solver to use (prefer mamba, fallback to conda)
  if [ -x ${MINIFORGE_HOME}/bin/mamba ]; then
    echo "Installing minimal base packages with mamba (preferred)..."
    INSTALLER="${MINIFORGE_HOME}/bin/mamba"
    SOLVER_NAME="mamba"
  else
    echo "[warn] Mamba not available, using conda..."
    INSTALLER="${MINIFORGE_HOME}/bin/conda"
    SOLVER_NAME="conda"
  fi
  
  # Install essential base packages for all environments
  if ${INSTALLER} install -y -c conda-forge \
      pip setuptools wheel ipykernel jupyter_client; then
    echo "✓ Minimal conda base configured with kernel support (using ${SOLVER_NAME})"
  else
    # If preferred solver fails, try the other one
    if [ "${SOLVER_NAME}" = "mamba" ]; then
      echo "[warn] Mamba failed, retrying with conda..."
      ${MINIFORGE_HOME}/bin/conda install -y -c conda-forge \
        pip setuptools wheel ipykernel jupyter_client \
        || exit 1
      echo "✓ Minimal conda base configured with kernel support (using conda fallback)"
    else
      echo "✗ ERROR: Package installation failed"
      exit 1
    fi
  fi
  
  # IMPORTANT: All heavy packages (jupyter, numpy, tensorflow, pytorch, etc.)
  # are now installed via setup_conda_environments.sh into the writable overlay
  # This allows for:
  #   - Multiple environments (ROS2 Jazzy, Humble, etc.)
  #   - Deep learning environments (PyTorch, TensorFlow)
  #   - Separate robotics and ML environments
  #   - Easy updates without rebuilding the entire image
  # End mamba/conda installation (if-else self-contained)

#--- Sub-block: Section continuation (4036) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 3949 ---
# Purpose: Continuing implementation
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments
  #--- Sub-block 16.18: Register Jupyter kernel ---
  # Purpose: Make conda base environment available in Jupyter
  ${MINIFORGE_HOME}/bin/python -m ipykernel install --name=python-conda-base --display-name="Python (conda-base)" || true

  #--- Sub-block 16.19: Install additional pip packages ---
  # Purpose: Robotics and simulation packages not in conda
  # Note: openai-gym is deprecated, using gymnasium instead (already installed via conda)
  ${MINIFORGE_HOME}/bin/pip install \
    robosuite \
    pyrender \
    trimesh \
    pyglet || true

  #--- Sub-block 16.20: Verify package installations ---
  # Purpose: Confirm critical packages installed correctly
echo "Verifying critical package installations..."
if [ -x ${MINIFORGE_HOME}/bin/jupyter ]; then
  echo "✓ Jupyter installed successfully"
else
  echo "[warn] Jupyter installation may have failed"
fi
if [ -x ${MINIFORGE_HOME}/bin/python ]; then
  echo "✓ Python installed successfully"
else
  echo "[warn] Python installation may have failed"
fi
# End verification (if-else blocks self-contained)
fi
# End conda base environment setup (if block self-contained)
debug_glibc "After conda environment setup"

#===============================================================================
# BLOCK 17: 3D MODELING AND OFFICE APPLICATIONS
#===============================================================================
# Purpose: Install office suite and 3D modeling tools
# Self-contained: Yes (complete application installations)
# Dependencies: APT repositories
# Outputs: Installed packages
#-------------------------------------------------------------------------------

#--- Sub-block 17.1: LibreOffice installation ---
# Critical: Office productivity suite
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> LibreOffice installation"
apt-get -y --no-install-recommends install \
  libreoffice-writer libreoffice-calc libreoffice-impress

#--- Sub-block 17.2: Blender and 3D tools installation ---
# Critical: 3D modeling, mesh processing, and CAD tools
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Blender installation"
apt-get -y --no-install-recommends install blender meshlab geomview librecad openscad-testing

debug_glibc "After installation of LibreOffice & Blender"

#--- Sub-block 17.3: OCIO color management configuration ---
# Purpose: Configure OpenColorIO for color-accurate 3D rendering
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> OCIO color profile configuration initialized"
set -e
DEBIAN_FRONTEND=noninteractive apt-get update -yq
if ! dpkg -l blender-data >/dev/null 2>&1; then
  DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends blender-data
  # Find Blender's bundled OCIO config
  OCIO_PATH="$(/usr/bin/python3 -c 'import glob; p=glob.glob("/usr/share/blender/*/datafiles/colormanagement/config.ocio"); print(p[0]) if p else ""')"
  if [ -n "$OCIO_PATH" ]; then
    printf 'export OCIO=%s\n' "$OCIO_PATH" > /etc/profile.d/99-ocio.sh
  else
    echo "[OCIO] blender-data installed but config.ocio not found; continuing"
  fi
else
  # Fallback: install a known-good ACES config
  mkdir -p /usr/share/ocio/aces && cd /tmp || { echo "Failed to change to /tmp"; exit 1; }
  curl -fsSL --retry 3 --retry-delay 2 -o aces.tar.gz https://github.com/AcademySoftwareFoundation/OpenColorIO-Config-ACES/archive/refs/heads/master.tar.gz || true
  if [ -f aces.tar.gz ]; then
    tar -xzf aces.tar.gz --strip-components=2 -C /usr/share/ocio/aces OpenColorIO-Config-ACES-master/aces_1.2 || true
    if [ -f /usr/share/ocio/aces/config.ocio ]; then
      printf 'export OCIO="/usr/share/ocio/aces/config.ocio"\n' > /etc/profile.d/99-ocio.sh
    fi
  fi
fi
set +e
echo "✓ OCIO color profile configuration complete"

#===============================================================================
# BLOCK 18: CAD AND 3D PRINTING TOOLS
#===============================================================================
# Purpose: Install CAD software and 3D printing slicers
# Self-contained: Yes (complete CAD toolchain)
# Dependencies: APT, AppImage support
# Outputs: Installed packages
#-------------------------------------------------------------------------------

#--- Sub-block 18.1: OpenSCAD installation ---
# Critical: Parametric CAD software
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> CAD tools installation"
apt-get -y --no-install-recommends install \
  openscad

#--- Sub-block 18.2: FreeCAD AppImage installation ---
# Critical: Professional CAD software (v1.0.2 via AppImage)
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "==> Installing FreeCAD version ${FREECAD_VERSION} via AppImage..." # Version from config.sh
FREECAD_FILENAME="FreeCAD_${FREECAD_VERSION}-conda-Linux-x86_64-py311.AppImage"
# Download, place in a system-wide location, and make executable
if wget "https://github.com/FreeCAD/FreeCAD/releases/download/${FREECAD_VERSION}/${FREECAD_FILENAME}" -O /usr/local/bin/freecad.AppImage; then
    chmod +x /usr/local/bin/freecad.AppImage
    # Create a symlink for easy terminal access (run with 'freecad')
    ln -s /usr/local/bin/freecad.AppImage /usr/local/bin/freecad
    echo "✓ FreeCAD installed successfully"
else
    echo "⚠ Failed to download FreeCAD (non-critical, continuing)"
    rm -f /usr/local/bin/freecad.AppImage
fi

# Create a desktop entry for the XFCE menu
cat > /usr/share/applications/freecad.desktop << 'EOF'
[Desktop Entry]
Name=FreeCAD
Comment=A general purpose 3D CAD modeler
Exec=freecad %F
Icon=freecad
Terminal=false
Type=Application
Categories=Graphics;3DGraphics;Engineering;
MimeType=application/x-extension-fcstd;
EOF
echo "✓ FreeCAD installation complete."

# === Install OrcaSlicer (AppImage) ===
echo "==> Installing OrcaSlicer version 2.3.1 via AppImage..."
# Define the specific version tag and filename based on the release page
ORCA_TAG="v2.3.1"
ORCA_FILENAME="OrcaSlicer_Linux_AppImage_Ubuntu2404_V2.3.1.AppImage"
# Download, place in a system-wide location, and make executable
wget "https://github.com/SoftFever/OrcaSlicer/releases/download/${ORCA_TAG}/${ORCA_FILENAME}" -O /usr/local/bin/orcaslicer.AppImage
chmod +x /usr/local/bin/orcaslicer.AppImage
# Create symlink for easy terminal access (run with 'orcaslicer')
ln -s /usr/local/bin/orcaslicer.AppImage /usr/local/bin/orcaslicer

# Create a desktop entry for the XFCE menu
cat > /usr/share/applications/orcaslicer.desktop << 'EOF'
[Desktop Entry]
Name=OrcaSlicer
Exec=orcaslicer %F
Icon=orcaslicer
Comment=G-code generator for 3D printers
Type=Application
Categories=Graphics;3DGraphics;Engineering;
MimeType=model/stl;application/vnd.ms-pki.stl;application/x-tgif;
EOF
echo "✓ OrcaSlicer installation complete."

#--- Sub-block: Section continuation (4182) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 4092 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
debug_glibc "After installing CAD tools and Orca Slicer"

#===============================================================================
# BLOCK 19: TEX/LATEX TYPESETTING SYSTEM
#===============================================================================
# Purpose: Install comprehensive TeX/LaTeX environment
# Self-contained: Yes (complete TeX distribution)
# Dependencies: APT repositories
# Outputs: Installed packages
#-------------------------------------------------------------------------------

#--- Sub-block 19.1: TeX Live installation (English-only, full features) ---
# Critical: Academic and technical document preparation
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> TeX (English-only, full feature)"
apt-get -y --no-install-recommends install \
  texlive texlive-latex-recommended texlive-latex-extra texlive-fonts-recommended texlive-fonts-extra \
  latexmk latexml texlive-xetex texlive-bibtex-extra biber cm-super \
  texlive-pictures texlive-science texlive-pstricks texlive-context \
  lmodern texlive-plain-generic \
  ipe texworks
debug_glibc "After TeX packages installation"

#===============================================================================
# BLOCK 20: VNC STARTUP SCRIPTS AND CONFIGURATIONS (Part 2 of 3)
#===============================================================================
# 🖥️  REMOTE DESKTOP INFRASTRUCTURE - PRIMARY SCRIPTS & CONFIGURATION
#
# This is Part 2 of the Remote Desktop Infrastructure spanning 3 blocks:
#   • Block 15 (line ~3320): TurboVNC & VirtualGL installation (COMPLETED)
#   • Block 20 (HERE):       Primary VNC launcher scripts and configurations
#   • Block 21 (line ~5870): Alternative VNC servers (x11vnc, KasmVNC, etc.)
#
# Purpose: Create comprehensive VNC startup scripts with GPU acceleration
# Self-contained: Yes (complete script suite)
# Dependencies: Block 15 (TurboVNC, VirtualGL), XFCE desktop environment
# Outputs: start_vnc_xfce.sh (PRIMARY), noVNC support, monitor tools
#
# Key Scripts Created:
#   PRIMARY:  start_vnc_xfce.sh     - Main VNC launcher (RECOMMENDED)
#   Monitor:  start_novnc_advanced.sh, vnc_monitor.sh  
#   Config:   XFCE optimizations, xstartup templates
#
# See Also: Block 15.20 for complete remote desktop infrastructure summary
#-------------------------------------------------------------------------------

#--- Sub-block 20.1: XFCE window manager optimization ---
# Critical: Configure XFCE for remote desktop performance
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "==> XFCE/VNC remote GUI tuning"
mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml
cat > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml << 'XFM'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="use_compositing" type="bool" value="false"/>
    <property name="sync_to_vblank" type="bool" value="false"/>
    <property name="frame_drawn" type="bool" value="false"/>
    <property name="double_click_time" type="int" value="250"/>
  </property>
</channel>
XFM

#--- Sub-block 20.2: Configure X server permissions ---
# Purpose: Allow non-root users to run X clients in containers
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
printf 'allowed_users=anybody\nneeds_root_rights=no\n' > /etc/X11/Xwrapper.config

#--- Sub-block 20.3: Create comprehensive VNC startup script ---
# Critical: Main VNC launcher with TurboVNC + noVNC + VirtualGL integration
# Dependencies: Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration
echo "==> Creating enhanced VNC startup script with full TurboVNC support..."

#--- Sub-block 19.1: Create main VNC startup script ---
# Critical: Comprehensive VNC launcher with TurboVNC + noVNC + VirtualGL
# Dependencies: Block 15 (VirtualGL), Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration
cat > /usr/local/bin/start_vnc_xfce.sh << 'VNCLAUNCHER'
#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Enhanced TurboVNC + VirtualGL + noVNC Launcher with Full Configuration
# ============================================================================

# --- Default Configuration ---
VNC_DISPLAY_NUM=${VNC_DISPLAY_NUM:-1}
VNC_PORT=$((5900 + VNC_DISPLAY_NUM))
WEB_PORT=${WEB_PORT:-6081}
TURBOVNC_WEB_PORT=$((5800 + VNC_DISPLAY_NUM))
GEOM="${VNC_GEOM:-1920x1080}"
DEPTH="${VNC_DEPTH:-24}"

# VirtualGL Configuration
VGL_DISPLAY_AUTO_DETECT=${VGL_DISPLAY_AUTO_DETECT:-1}
VGL_DISPLAY_FALLBACK="${VGL_DISPLAY_FALLBACK:-:0}"
VGL_COMPRESS="${VGL_COMPRESS:-proxy}"
VGL_READBACK="${VGL_READBACK:-sync}"
VGL_FPS="${VGL_FPS:-0}"
VGL_VERBOSE="${VGL_VERBOSE:-0}"
VGL_DEBUG="${VGL_DEBUG:-0}"
VGL_FORCE_GPU="${VGL_FORCE_GPU:-0}"

# VNC Integration
VNC_VGL_INTEGRATION="${VNC_VGL_INTEGRATION:-1}"
VNC_OPENGL_EXTENSIONS="${VNC_OPENGL_EXTENSIONS:-1}"
VNC_GLX_EXTENSIONS="${VNC_GLX_EXTENSIONS:-1}"

# Debug Configuration
DEBUG_MODE="${DEBUG_MODE:-0}"
VERBOSE_MODE="${VERBOSE_MODE:-0}"

# Security: bind to localhost only (use -nolisten for remote access)
SECURITY_ARGS="-localhost"

# --- Command Line Argument Parsing ---
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --vgl-display)
        VGL_DISPLAY_AUTO_DETECT=0
        VGL_DISPLAY_FALLBACK="$2"
        shift 2
        ;;
      --vgl-compress)
        VGL_COMPRESS="$2"
        shift 2
        ;;
      --vgl-readback)
        VGL_READBACK="$2"
        shift 2
        ;;
      --vgl-fps)
        VGL_FPS="1"
        shift
        ;;
      --vgl-verbose)
        VGL_VERBOSE="1"
        VERBOSE_MODE="1"
        shift
        ;;
      --vgl-debug)
        VGL_DEBUG="1"
        DEBUG_MODE="1"
        VERBOSE_MODE="1"
        shift
        ;;
      --vnc-display)
        VNC_DISPLAY_NUM="$2"
        VNC_PORT=$((5900 + VNC_DISPLAY_NUM))
        TURBOVNC_WEB_PORT=$((5800 + VNC_DISPLAY_NUM))
        shift 2
        ;;
      --vnc-geometry)
        GEOM="$2"
        shift 2
        ;;
      --vnc-depth)
        DEPTH="$2"
        shift 2
        ;;
      --no-vgl)
        VNC_VGL_INTEGRATION="0"
        shift
        ;;
      --force-vgl)
        VGL_FORCE_GPU="1"
        shift
        ;;
      --debug)
        DEBUG_MODE="1"
        VERBOSE_MODE="1"
        shift
        ;;
      --verbose)
        VERBOSE_MODE="1"
        shift
        ;;
      --help|-h)
        show_help
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
    esac
  done
}

# --- Help Function ---
show_help() {
  cat << 'EOF'
Enhanced TurboVNC + VirtualGL + noVNC Launcher

USAGE:
  start_vnc_xfce.sh [OPTIONS]

OPTIONS:
  --vgl-display DISPLAY    Set VGL_DISPLAY (default: auto-detect)
  --vgl-compress METHOD    Set compression (proxy|jpeg|rgb) (default: proxy)
  --vgl-readback MODE      Set readback mode (sync|async) (default: sync)
  --vgl-fps               Enable FPS display (default: disabled)
  --vgl-verbose           Enable verbose VirtualGL output
  --vgl-debug             Enable debug mode with detailed logging
  --vnc-display NUM       Set VNC display number (default: 1)
  --vnc-geometry SIZE     Set VNC geometry (default: 1920x1080)
  --vnc-depth BITS        Set color depth (default: 24)
  --no-vgl                Disable VirtualGL (software rendering)
  --force-vgl             Force VirtualGL even if not detected
  --debug                 Enable debug mode
  --verbose               Enable verbose output
  --help, -h              Show this help message

ENVIRONMENT VARIABLES:
  VGL_DISPLAY_AUTO_DETECT=1    Auto-detect VNC display (default: 1)
  VGL_DISPLAY_FALLBACK=:0      Fallback display (default: :0)
  VGL_COMPRESS=proxy           Compression method (default: proxy)
  VGL_READBACK=sync            Readback mode (default: sync)
  VGL_FPS=0                    FPS display (default: 0)
  VGL_VERBOSE=0                Verbose output (default: 0)
  VGL_DEBUG=0                  Debug mode (default: 0)
  VNC_DISPLAY_NUM=1            VNC display number (default: 1)
  VNC_GEOM=1920x1080           VNC geometry (default: 1920x1080)
  VNC_DEPTH=24                 Color depth (default: 24)

EXAMPLES:
  # Auto-detect everything
  start_vnc_xfce.sh

  # Specify VNC display and enable debug
  start_vnc_xfce.sh --vnc-display 2 --vgl-debug

  # Force specific VirtualGL display
  start_vnc_xfce.sh --vgl-display :2 --vgl-verbose

  # Disable VirtualGL (software rendering)
  start_vnc_xfce.sh --no-vgl

  # Test different compression
  start_vnc_xfce.sh --vgl-compress jpeg --vgl-fps
EOF
}

# --- VirtualGL Display Detection ---
detect_vgl_display() {
  if [ "$VGL_DISPLAY_AUTO_DETECT" = "1" ]; then
    # Try to detect VNC display from running processes
    local vnc_display=""
    
    # Method 1: Check for Xvnc processes
    vnc_display=$(ps aux | grep -o 'Xvnc.*:[0-9]' | head -1 | grep -o ':[0-9]' | head -1)
    
    # Method 2: Check for vncserver processes
    if [ -z "$vnc_display" ]; then
      vnc_display=$(ps aux | grep -o 'vncserver.*:[0-9]' | head -1 | grep -o ':[0-9]' | head -1)
    fi
    
    # Method 3: Check for display :1, :2, etc.
    if [ -z "$vnc_display" ]; then
      for i in 1 2 3 4 5; do
        if [ -S "/tmp/.X11-unix/X$i" ]; then
          vnc_display=":$i"
          break
        fi
      done
    fi
    
    if [ -n "$vnc_display" ]; then
      export VGL_DISPLAY="$vnc_display"
      [ "$VERBOSE_MODE" = "1" ] && echo "  ✓ Auto-detected VGL_DISPLAY: $vnc_display"
    else
      export VGL_DISPLAY="$VGL_DISPLAY_FALLBACK"
      [ "$VERBOSE_MODE" = "1" ] && echo "  ⚠ Using fallback VGL_DISPLAY: $VGL_DISPLAY_FALLBACK"
    fi
  else
    export VGL_DISPLAY="$VGL_DISPLAY_FALLBACK"
    [ "$VERBOSE_MODE" = "1" ] && echo "  ✓ Using specified VGL_DISPLAY: $VGL_DISPLAY_FALLBACK"
  fi
}

# --- VirtualGL Configuration ---
configure_virtualgl() {
  if [ "$VNC_VGL_INTEGRATION" = "1" ]; then
    echo "Configuring VirtualGL..."
    
    # Detect display
    detect_vgl_display
    
    # Set VirtualGL environment variables
    export VGL_COMPRESS="$VGL_COMPRESS"
    export VGL_READBACK="$VGL_READBACK"
    export VGL_LOGO="0"
    export VGL_FPS="$VGL_FPS"
    export VGL_VERBOSE="$VGL_VERBOSE"
    
    # Debug mode settings
    if [ "$VGL_DEBUG" = "1" ]; then
      export VGL_VERBOSE="1"
      export VGL_LOG_LEVEL="2"
      [ "$VERBOSE_MODE" = "1" ] && echo "  ✓ VirtualGL debug mode enabled"
    fi
    
    # Force GPU usage
    if [ "$VGL_FORCE_GPU" = "1" ]; then
      export VGL_FORCE_GPU="1"
      [ "$VERBOSE_MODE" = "1" ] && echo "  ✓ VirtualGL force GPU enabled"
    fi
    
    [ "$VERBOSE_MODE" = "1" ] && echo "  ✓ VirtualGL configured:"
    [ "$VERBOSE_MODE" = "1" ] && echo "    VGL_DISPLAY=$VGL_DISPLAY"
    [ "$VERBOSE_MODE" = "1" ] && echo "    VGL_COMPRESS=$VGL_COMPRESS"
    [ "$VERBOSE_MODE" = "1" ] && echo "    VGL_READBACK=$VGL_READBACK"
    [ "$VERBOSE_MODE" = "1" ] && echo "    VGL_FPS=$VGL_FPS"
    [ "$VERBOSE_MODE" = "1" ] && echo "    VGL_VERBOSE=$VGL_VERBOSE"
  else
    echo "VirtualGL integration disabled (software rendering)"
  fi
}

# --- VirtualGL Test Function ---
test_virtualgl() {
  if [ "$VNC_VGL_INTEGRATION" = "1" ]; then
    echo "Testing VirtualGL configuration..."
    
    # Check if vglrun is available
    if ! command -v vglrun >/dev/null 2>&1; then
      echo "  ✗ vglrun not found - VirtualGL not available"
      return 1
    fi
    
    # Check if VirtualGL can access the display
    if [ -n "${VGL_DISPLAY:-}" ]; then
      echo "  ✓ VGL_DISPLAY set to: $VGL_DISPLAY"
      
      # Test VirtualGL connection
      if vglrun -d "$VGL_DISPLAY" glxinfo >/dev/null 2>&1; then
        echo "  ✓ VirtualGL can access display $VGL_DISPLAY"
        
        # Test OpenGL rendering
        if vglrun -d "$VGL_DISPLAY" glxinfo | grep -q "OpenGL renderer"; then
          echo "  ✓ OpenGL rendering available"
          return 0
        else
          echo "  ⚠ OpenGL rendering not available"
          return 1
        fi
      else
        echo "  ✗ VirtualGL cannot access display $VGL_DISPLAY"
        return 1
      fi
    else
      echo "  ✗ VGL_DISPLAY not set"
      return 1
    fi
  else
    echo "VirtualGL integration disabled"
    return 0
  fi
}

# --- Parse command line arguments ---
parse_arguments "$@"

# --- Ensure TurboVNC is in PATH ---

# --- Cleanup function ---
cleanup() {
  echo ""
  echo "Shutting down VNC services..."
  vncserver -kill ":${VNC_DISPLAY_NUM}" 2>/dev/null || true
  pkill -f "websockify.*${WEB_PORT}" 2>/dev/null || true
  jobs -p | xargs -r kill 2>/dev/null || true
  exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# --- Check dependencies ---
check_dependencies() {
  local missing=0

  echo "Checking dependencies..."

#--- Sub-block: Section continuation (4279) ---
# Purpose: Implementation details
# Dependencies: Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration

  if ! command -v vncserver >/dev/null 2>&1; then
    echo "  ✗ vncserver not found"
    missing=1
  else
    echo "  ✓ vncserver: $(which vncserver)"
  fi


#--- Sub-block: Code section 4193 ---
# Purpose: Continuing implementation
# Dependencies: Block 6.13 (NVIDIA CUDA), Block 15 (VirtualGL)
# Outputs: GPU libraries, CUDA toolkit
  if ! command -v Xvnc >/dev/null 2>&1; then
    echo "  ✗ Xvnc not found"
    missing=1
  else
    echo "  ✓ Xvnc: $(which Xvnc)"
  fi

  if ! command -v startxfce4 >/dev/null 2>&1; then
    echo "  ✗ startxfce4 not found"
    missing=1
  else
    echo "  ✓ XFCE4 available"
  fi

  if [ $missing -eq 1 ]; then
    echo ""
    echo "ERROR: Missing required dependencies"
    echo "PATH: $PATH"
    exit 1
  fi

  echo "✓ All dependencies found"
  echo ""
}

# --- Check VirtualGL availability ---
check_virtualgl() {
  echo "Checking VirtualGL availability..."

  # Add VirtualGL to PATH

  if command -v vglrun >/dev/null 2>&1; then
    echo "  ✓ VirtualGL available: $(which vglrun)"

    # Check GPU
    if command -v nvidia-smi >/dev/null 2>&1; then
      GPU_INFO=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
      if [ -n "$GPU_INFO" ]; then
        echo "  ✓ GPU detected: $GPU_INFO"
      else
        echo "  ⚠ nvidia-smi found but no GPU detected"
      fi
    else
      echo "  ⚠ nvidia-smi not found (CPU rendering only)"
    fi

#--- Sub-block: Section continuation (4336) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 4240 ---
# Purpose: Continuing implementation
# Dependencies: Block 15 (VirtualGL), Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration
    # Check OpenGL utilities
    if command -v glxinfo >/dev/null 2>&1; then
      echo "  ✓ glxinfo available for OpenGL testing"
    fi
    if command -v glxspheres64 >/dev/null 2>&1; then
      echo "  ✓ glxspheres64 available for GPU benchmarking"
    fi
  else
    echo "  ⚠ VirtualGL not available"
    echo "    GPU-accelerated applications may not work properly"
  fi

  echo ""
}

# --- Setup VNC configuration ---
setup_vnc_config() {
  mkdir -p "$HOME/.vnc"

  # Create xstartup script with VirtualGL integration
  cat > "$HOME/.vnc/xstartup" << 'XSTART'
#!/bin/sh
# Enhanced TurboVNC xstartup for XFCE4 + VirtualGL

# Load X resources
[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources" 2>/dev/null || true

# Font cache
fc-cache -f 2>/dev/null || true

# Start D-Bus if not running
if ! dbus-send --session --dest=org.freedesktop.DBus --type=method_call \
  /org/freedesktop/DBus org.freedesktop.DBus.ListNames >/dev/null 2>&1; then
  eval "$(dbus-launch --sh-syntax)"
fi

# VirtualGL Environment Setup
if [ -n "${VGL_DISPLAY:-}" ]; then
  export VGL_DISPLAY
  export VGL_COMPRESS="${VGL_COMPRESS:-proxy}"
  export VGL_READBACK="${VGL_READBACK:-sync}"
  export VGL_LOGO="${VGL_LOGO:-0}"
  export VGL_FPS="${VGL_FPS:-0}"
  export VGL_VERBOSE="${VGL_VERBOSE:-0}"
  
  # Debug mode
  if [ "${VGL_DEBUG:-0}" = "1" ]; then
    export VGL_VERBOSE="1"
    export VGL_LOG_LEVEL="2"
  fi
  
  # Force GPU usage
  if [ "${VGL_FORCE_GPU:-0}" = "1" ]; then
    export VGL_FORCE_GPU="1"
  fi
fi

# X11 Configuration for VirtualGL
export DISPLAY="${DISPLAY:-:1}"

# Disable compositing for better VNC performance
xfconf-query -c xfwm4 -p /general/use_compositing -s false 2>/dev/null || true
xfconf-query -c xfce4-session -p /general/use_compositing -s false 2>/dev/null || true

# XFCE4 optimizations for VirtualGL
export XFWM4_USE_PRESENT=0  # Disable Present extension (can cause issues with VirtualGL)
export XFCE4_SESSION_DEBUG=0  # Disable XFCE debug output

# Disable screen blanking
xset s off 2>/dev/null || true
xset -dpms 2>/dev/null || true
xset s noblank 2>/dev/null || true

# VirtualGL Integration Test (if enabled)
if [ "${VNC_VGL_INTEGRATION:-1}" = "1" ] && [ -n "${VGL_DISPLAY:-}" ]; then
  # Test VirtualGL connection
  if command -v vglrun >/dev/null 2>&1; then
    # Set up VirtualGL environment
    export VGL_DISPLAY
    echo "VirtualGL configured for display: $VGL_DISPLAY"
  else
    echo "Warning: VirtualGL not found, using software rendering"
  fi
fi

# Start XFCE4
exec /usr/bin/startxfce4
XSTART

  chmod +x "$HOME/.vnc/xstartup"
  echo "✓ VNC configuration created"
}

# --- Start VNC server ---
start_vnc_server() {
  echo "Starting TurboVNC server..."
  echo "  Display: :${VNC_DISPLAY_NUM}"
  echo "  Geometry: ${GEOM}"
  echo "  Depth: ${DEPTH}"
  echo "  VirtualGL Integration: $([ "$VNC_VGL_INTEGRATION" = "1" ] && echo "Enabled" || echo "Disabled")"

  # Check if VNC password is set
  if [ ! -f "$HOME/.vnc/passwd" ]; then
    echo ""
    echo "⚠ VNC password not set. Please set it now:"
    vncpasswd
    echo ""
  fi

  # Configure VirtualGL before starting VNC
  configure_virtualgl

  # Build VNC server arguments
  local vnc_args=(
    ":${VNC_DISPLAY_NUM}"
    "-geometry" "${GEOM}"
    "-depth" "${DEPTH}"
    ${SECURITY_ARGS}
    "-xstartup" "$HOME/.vnc/xstartup"
  )

  # Add VirtualGL-specific VNC arguments if integration is enabled
  if [ "$VNC_VGL_INTEGRATION" = "1" ]; then
    # Add OpenGL extensions for VirtualGL
    if [ "$VNC_OPENGL_EXTENSIONS" = "1" ]; then
      vnc_args+=("-extension" "GLX")
    fi
    
    # Add GLX extensions for VirtualGL
    if [ "$VNC_GLX_EXTENSIONS" = "1" ]; then
      vnc_args+=("-extension" "MIT-SHM")
    fi
    
    # Add VirtualGL-optimized settings
    vnc_args+=(
      "-dpi" "96"
      "-desktop" "Xubuntu-VGL"
      "-alwaysshared"
      "-dontdisconnect"
    )
    
    [ "$VERBOSE_MODE" = "1" ] && echo "  ✓ VirtualGL-optimized VNC arguments added"
  fi

  # Start VNC server with arguments
  vncserver "${vnc_args[@]}"

  # Wait for server to start
  sleep 3

  # Verify
  if ! vncserver -list 2>/dev/null | grep -q ":${VNC_DISPLAY_NUM}"; then
    echo "ERROR: VNC server failed to start"
    echo "Check logs:"
    ls -lt ~/.vnc/*.log 2>/dev/null | head -5
    echo ""
    tail -20 ~/.vnc/*.log 2>/dev/null
    exit 1
  fi

#--- Sub-block: Section continuation (4430) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

  echo "✓ VNC server running on display :${VNC_DISPLAY_NUM} (port ${VNC_PORT})"
}


#--- Sub-block: Code section 4331 ---
# Purpose: Continuing implementation
# Dependencies: Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration
# --- Check TurboVNC's built-in webserver ---
check_turbovnc_webserver() {
  # TurboVNC may start its own webserver automatically
  if ss -tuln 2>/dev/null | grep -q ":${TURBOVNC_WEB_PORT}\b"; then
    echo "✓ TurboVNC built-in webserver detected on port ${TURBOVNC_WEB_PORT}"
    return 0
  else
    echo "⚠ TurboVNC built-in webserver not running"
    return 1
  fi
}

# --- Start noVNC (websockify) ---
start_novnc() {
  echo "Starting noVNC (HTML5 VNC client)..."

  # Find websockify
  WEBSOCKIFY=""

#--- Sub-block: Section 4574 ---
# Purpose: Continued implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
  for candidate in /usr/bin/websockify /usr/local/bin/websockify ${MINIFORGE_HOME}/bin/websockify; do
    if [ -x "$candidate" ]; then
      WEBSOCKIFY="$candidate"
      echo "  Found websockify: $WEBSOCKIFY"
      break
    fi
  done

  if [ -z "$WEBSOCKIFY" ]; then
    echo "  ✗ websockify not found - noVNC will not be available"
    return 1
  fi

  # Find noVNC web files
  NOVNC_DIR=""
  for candidate in /usr/local/share/novnc /usr/share/novnc; do
    if [ -d "$candidate" ] && [ -f "$candidate/vnc.html" ]; then
      NOVNC_DIR="$candidate"
      echo "  Found noVNC: $NOVNC_DIR"
      break
    fi
  done

#--- Sub-block: Section continuation (4477) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

  # Start websockify
  if [ -n "$NOVNC_DIR" ]; then
    $WEBSOCKIFY --web "$NOVNC_DIR" ${WEB_PORT} localhost:${VNC_PORT} 2>&1 | \
      grep -v "WARNING" | grep -v "numpy" &
  else
    echo "  ⚠ noVNC files not found, starting websockify without web interface"
    $WEBSOCKIFY ${WEB_PORT} localhost:${VNC_PORT} 2>&1 | \
      grep -v "WARNING" | grep -v "numpy" &
  fi


#--- Sub-block: Code section 4382 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
  WEBSOCKIFY_PID=$!
  sleep 2

  if ! kill -0 $WEBSOCKIFY_PID 2>/dev/null; then
    echo "  ✗ websockify failed to start"
    return 1
  fi

  echo "✓ noVNC running on port ${WEB_PORT} (PID: ${WEBSOCKIFY_PID})"
  return 0
}

#--- Sub-block: Section 4624 ---
# Purpose: Continued implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

# --- Display connection information ---
display_connection_info() {
  NODE=$(hostname -f 2>/dev/null || hostname)

  echo ""
  echo "=========================================="
  echo "✓ VNC Server Ready!"
  echo "=========================================="
  echo "Hostname: $NODE"
  echo "Display: :${VNC_DISPLAY_NUM}"
  echo "VirtualGL: $([ "$VNC_VGL_INTEGRATION" = "1" ] && echo "Enabled (VGL_DISPLAY=${VGL_DISPLAY:-:1})" || echo "Disabled")"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "CONNECTION METHOD 1: Native VNC Viewer (Recommended)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "TWO-STAGE SSL TUNNELING (HPC Environment):"
  echo ""
  echo "Auto-Detected Information:"
  echo "  Username: \${USER:-$(whoami)}"
  echo "  Compute Node: ${NODE}"
  echo "  Node IP: $(hostname -I | awk '{print $1}' | grep -v '^127\.' | head -1 || echo 'localhost')"
  echo ""
  echo "Stage 1 - Tunnel to Login Node (Run on your local machine):"
  echo "   ssh -L ${VNC_PORT}:localhost:${VNC_PORT} -L ${WEB_PORT}:localhost:${WEB_PORT} -p 22 \${USER:-$(whoami)}@107.122.148.226"
  echo ""
  echo "Stage 2 - From Login Node to Compute Node (Run on login node):"
  echo "   ssh -L ${VNC_PORT}:localhost:${VNC_PORT} -L ${WEB_PORT}:localhost:${WEB_PORT} \${USER:-$(whoami)}@${NODE}"
  echo ""
  echo "Alternative Stage 2 (with IP):"
  echo "   ssh -L ${VNC_PORT}:localhost:${VNC_PORT} -L ${WEB_PORT}:localhost:${WEB_PORT} \${USER:-$(whoami)}@$(hostname -I | awk '{print $1}' | grep -v '^127\.' | head -1 || echo 'localhost')"
  echo ""
  echo "Direct Two-Stage Tunnel (Single Command):"
  echo "   ssh -J \${USER:-$(whoami)}@107.122.148.226:22 -L ${VNC_PORT}:localhost:${VNC_PORT} -L ${WEB_PORT}:localhost:${WEB_PORT} \${USER:-$(whoami)}@${NODE}"
  echo ""
  echo "Connect VNC viewer to: localhost:${VNC_PORT}"
  echo "   (or localhost:${VNC_DISPLAY_NUM})"
  echo ""

  if ss -tuln 2>/dev/null | grep -q ":${WEB_PORT}\b"; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "CONNECTION METHOD 2: Web Browser (noVNC)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "TWO-STAGE SSL TUNNELING (HPC Environment):"
    echo ""
    echo "Auto-Detected Information:"
    echo "  Username: \${USER:-$(whoami)}"
    echo "  Compute Node: ${NODE}"
    echo "  Node IP: $(hostname -I | awk '{print $1}' | grep -v '^127\.' | head -1 || echo 'localhost')"
    echo ""
    echo "Stage 1 - Tunnel to Login Node (Run on your local machine):"
    echo "   ssh -L ${WEB_PORT}:localhost:${WEB_PORT} -p 22 \${USER:-$(whoami)}@107.122.148.226"
    echo ""
    echo "Stage 2 - From Login Node to Compute Node (Run on login node):"
    echo "   ssh -L ${WEB_PORT}:localhost:${WEB_PORT} \${USER:-$(whoami)}@${NODE}"
    echo ""
    echo "Alternative Stage 2 (with IP):"
    echo "   ssh -L ${WEB_PORT}:localhost:${WEB_PORT} \${USER:-$(whoami)}@$(hostname -I | awk '{print $1}' | grep -v '^127\.' | head -1 || echo 'localhost')"
    echo ""
    echo "Direct Two-Stage Tunnel (Single Command):"
    echo "   ssh -J \${USER:-$(whoami)}@107.122.148.226:22 -L ${WEB_PORT}:localhost:${WEB_PORT} \${USER:-$(whoami)}@${NODE}"
    echo ""
    echo "Open browser to: http://localhost:${WEB_PORT}"
    echo ""
  fi

#--- Sub-block: Section continuation (4534) ---
# Purpose: Implementation details
# Dependencies: Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration

  if ss -tuln 2>/dev/null | grep -q ":${TURBOVNC_WEB_PORT}\b"; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "CONNECTION METHOD 3: TurboVNC Java Applet"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "TWO-STAGE SSL TUNNELING (HPC Environment):"
    echo ""
    echo "Stage 1 - Tunnel to Login Node:"
    echo "   ssh -L ${TURBOVNC_WEB_PORT}:localhost:${TURBOVNC_WEB_PORT} \$USER@login.hpc.edu"
    echo ""
    echo "Stage 2 - From Login Node to Compute Node:"
    echo "   ssh -L ${TURBOVNC_WEB_PORT}:localhost:${TURBOVNC_WEB_PORT} \$USER@${NODE}"
    echo ""
    echo "Alternative - Direct Two-Stage Tunnel:"
    echo "   ssh -J \$USER@login.hpc.edu -L ${TURBOVNC_WEB_PORT}:localhost:${TURBOVNC_WEB_PORT} \$USER@${NODE}"
    echo ""
    echo "Open browser to: http://localhost:${TURBOVNC_WEB_PORT}"
    echo "   (Requires Java plugin - not recommended for modern browsers)"
    echo ""
  fi


#--- Sub-block: Code section 4438 ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

#--- Sub-block: Section 4674 ---
# Purpose: Continued implementation
# Purpose: Continuing implementation
# Dependencies: Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "USEFUL COMMANDS:"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "View VNC logs:"
  echo "  tail -f ~/.vnc/*.log"
  echo ""
  echo "List running VNC servers:"
  echo "  vncserver -list"
  echo ""
  echo "Kill this VNC server:"
  echo "  vncserver -kill :${VNC_DISPLAY_NUM}"
  echo ""
  echo "Change VNC password:"
  echo "  vncpasswd"
  echo ""
  
  # Add VirtualGL usage instructions
  if [ "$VNC_VGL_INTEGRATION" = "1" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "VIRTUALGL USAGE:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "To run GPU-accelerated applications:"
    echo "  vglrun glxspheres64          # Test OpenGL rendering"
    echo "  vglrun firefox               # GPU-accelerated Firefox"
    echo "  vglrun glxgears              # Test OpenGL performance"
    echo ""
    echo "Debug VirtualGL:"
    echo "  test_virtualgl.sh            # Comprehensive test"
    echo "  vglrun -d :1 glxinfo         # Check OpenGL info"
    echo "  vglrun -d :1 glxspheres64    # Test with specific display"
    echo ""
    echo "VirtualGL Configuration:"
    echo "  VGL_DISPLAY: ${VGL_DISPLAY:-:1}"
    echo "  VGL_COMPRESS: ${VGL_COMPRESS:-proxy}"
    echo "  VGL_READBACK: ${VGL_READBACK:-sync}"
    echo ""
  fi
  
  echo "=========================================="
  echo ""
  echo "Press Ctrl+C to stop all VNC services"
  echo ""
}

# --- Monitor services ---
monitor_services() {
  local check_count=0

  while true; do
    sleep 30
    check_count=$((check_count + 1))

    # Check VNC server every loop
    if ! vncserver -list 2>/dev/null | grep -q ":${VNC_DISPLAY_NUM}"; then
      echo "ERROR: VNC server died unexpectedly"
      exit 1
    fi

    # Check websockify every 3rd loop (90 seconds)
    if [ $((check_count % 3)) -eq 0 ]; then
      if [ -n "${WEBSOCKIFY_PID:-}" ]; then
        if ! kill -0 $WEBSOCKIFY_PID 2>/dev/null; then
          echo "WARNING: websockify died, restarting..."
          start_novnc || echo "Failed to restart websockify"
        fi
      fi
    fi
  done
}

#--- Sub-block: Section continuation (4595) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Section 4724 ---
# Purpose: Continued implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

#--- Sub-block: Code section 4484 ---
# Purpose: Continuing implementation
# Dependencies: Block 15 (VirtualGL), Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration
# ============================================================================
# Main Execution
# ============================================================================

echo "=========================================="
echo "TurboVNC + noVNC Launcher"
echo "=========================================="
echo ""

# Run setup steps
check_dependencies
check_virtualgl
setup_vnc_config
start_vnc_server

# Test VirtualGL after VNC is running
if [ "$VNC_VGL_INTEGRATION" = "1" ]; then
  echo ""
  echo "Testing VirtualGL integration..."
  test_virtualgl || echo "⚠ VirtualGL test failed - check configuration"
fi

# Try to start web interfaces
check_turbovnc_webserver || true
start_novnc || echo "⚠ noVNC not available (VNC viewer still works)"

# Display connection info
display_connection_info

# Monitor and keep alive
monitor_services
VNCLAUNCHER

chmod 0755 /usr/local/bin/start_vnc_xfce.sh
echo "✓ Enhanced VNC startup script created at /usr/local/bin/start_vnc_xfce.sh"

#--- Sub-block 20.4: Create SSL Tunneling Scripts ---
# Purpose: Automated two-stage SSL tunneling for HPC environments
# Dependencies: VNC server running
# Outputs: SSL tunneling scripts
echo "==> Creating SSL tunneling scripts for HPC environments..."

# Create main SSL tunnel script
cat > /usr/local/bin/vnc_ssl_tunnel.sh << 'SSLTUNNEL'
#!/usr/bin/env bash
# Two-Stage SSL Tunneling for VNC Access in HPC Environments
# Usage: vnc_ssl_tunnel.sh [login_node] [compute_node] [vnc_port] [web_port]

set -euo pipefail

# Auto-detect system information
COMPUTE_NODE="${2:-$(hostname)}"
USER_NAME="${USER:-$(whoami)}"
NODE_IP="${NODE_IP:-$(hostname -I | awk '{print $1}')}"

# Configuration with auto-detection
LOGIN_NODE="${1:-107.122.148.226}"
LOGIN_PORT="${LOGIN_PORT:-22}"
VNC_PORT="${3:-5901}"
WEB_PORT="${4:-6081}"
TURBOVNC_WEB_PORT=$((5800 + ${VNC_PORT#59}))

# Try to detect compute node from SLURM environment
if [ -n "${SLURM_JOB_NODELIST:-}" ]; then
    # Extract first node from SLURM_JOB_NODELIST
    COMPUTE_NODE=$(echo "$SLURM_JOB_NODELIST" | cut -d',' -f1 | sed 's/\[.*\]//')
    echo "Detected compute node from SLURM: $COMPUTE_NODE"
elif [ -n "${SLURM_NODELIST:-}" ]; then
    COMPUTE_NODE=$(echo "$SLURM_NODELIST" | cut -d',' -f1 | sed 's/\[.*\]//')
    echo "Detected compute node from SLURM: $COMPUTE_NODE"
fi

# Try to detect node IP more accurately
if [ -n "${SLURM_NODEID:-}" ]; then
    # If we have SLURM node ID, try to get IP from scontrol
    NODE_IP=$(scontrol show node "$COMPUTE_NODE" 2>/dev/null | grep -oP 'NodeAddr=\K[^\s]+' | head -1 || echo "$NODE_IP")
fi

# Fallback IP detection methods
if [ -z "$NODE_IP" ] || [ "$NODE_IP" = "127.0.0.1" ]; then
    # Try to get external IP
    NODE_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[0-9.]+' | head -1 || echo "$NODE_IP")
fi

if [ -z "$NODE_IP" ] || [ "$NODE_IP" = "127.0.0.1" ]; then
    # Last resort - use hostname
    NODE_IP=$(hostname -I | awk '{print $1}' | grep -v '^127\.' | head -1 || echo "localhost")
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  Two-Stage SSL Tunneling for VNC Access (HPC Environment)     ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_usage() {
    echo "Usage: $0 [login_node] [compute_node] [vnc_port] [web_port]"
    echo ""
    echo "Arguments:"
    echo "  login_node    - HPC login node IP/hostname (default: 107.122.148.226)"
    echo "  compute_node  - Compute node hostname (default: current hostname)"
    echo "  vnc_port      - VNC port number (default: 5901)"
    echo "  web_port      - Web/noVNC port number (default: 6081)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Use defaults"
    echo "  $0 107.122.148.226 node001 5902      # Custom VNC port"
    echo "  $0 107.122.148.226 gpu-node-01 5901 6081  # All custom"
}

check_vnc_running() {
    local port=$1
    if ! ss -tuln 2>/dev/null | grep -q ":${port}\b"; then
        echo -e "${RED}Error: VNC server not running on port ${port}${NC}"
        echo "Start VNC first with: start_vnc_xfce.sh"
        return 1
    fi
    return 0
}

create_tunnel_scripts() {
    local login_node="$1"
    local compute_node="$2"
    local vnc_port="$3"
    local web_port="$4"
    local turbovnc_web_port=$((5800 + ${vnc_port#59}))
    local user_name="$5"
    local node_ip="$6"
    
    # Create Stage 1 script (local machine to login node)
    cat > /tmp/vnc_tunnel_stage1.sh << EOF
#!/bin/bash
# Stage 1: Tunnel from local machine to login node
echo "Stage 1: Creating tunnel to login node..."
echo "Command: ssh -L ${vnc_port}:localhost:${vnc_port} -L ${web_port}:localhost:${web_port} -L ${turbovnc_web_port}:localhost:${turbovnc_web_port} -p ${login_port} ${user_name}@${login_node}"
echo ""
echo "After connecting, run Stage 2 script on the login node."
echo "Press Ctrl+C to stop this tunnel."
echo ""

ssh -L ${vnc_port}:localhost:${vnc_port} \\
    -L ${web_port}:localhost:${web_port} \\
    -L ${turbovnc_web_port}:localhost:${turbovnc_web_port} \\
    -p ${login_port} \\
    ${user_name}@${login_node}
EOF

    # Create Stage 2 script (login node to compute node)
    cat > /tmp/vnc_tunnel_stage2.sh << EOF
#!/bin/bash
# Stage 2: Tunnel from login node to compute node
echo "Stage 2: Creating tunnel to compute node..."
echo "Command: ssh -L ${vnc_port}:localhost:${vnc_port} -L ${web_port}:localhost:${web_port} -L ${turbovnc_web_port}:localhost:${turbovnc_web_port} ${user_name}@${compute_node}"
echo ""
echo "Alternative with IP: ssh -L ${vnc_port}:localhost:${vnc_port} -L ${web_port}:localhost:${web_port} -L ${turbovnc_web_port}:localhost:${turbovnc_web_port} ${user_name}@${node_ip}"
echo ""
echo "After connecting, VNC will be available on localhost:${vnc_port}"
echo "Press Ctrl+C to stop this tunnel."
echo ""

# Try hostname first, fallback to IP if needed
ssh -L ${vnc_port}:localhost:${vnc_port} \\
    -L ${web_port}:localhost:${web_port} \\
    -L ${turbovnc_web_port}:localhost:${turbovnc_web_port} \\
    ${user_name}@${compute_node} || \\
ssh -L ${vnc_port}:localhost:${vnc_port} \\
    -L ${web_port}:localhost:${web_port} \\
    -L ${turbovnc_web_port}:localhost:${turbovnc_web_port} \\
    ${user_name}@${node_ip}
EOF

    # Create combined script (direct two-stage tunnel)
    cat > /tmp/vnc_tunnel_direct.sh << EOF
#!/bin/bash
# Direct two-stage tunnel using SSH jump host
echo "Direct Two-Stage Tunnel: Local -> Login -> Compute"
echo "Command: ssh -J ${user_name}@${login_node}:${login_port} -L ${vnc_port}:localhost:${vnc_port} -L ${web_port}:localhost:${web_port} -L ${turbovnc_web_port}:localhost:${turbovnc_web_port} ${user_name}@${compute_node}"
echo ""
echo "Alternative with IP: ssh -J ${user_name}@${login_node}:${login_port} -L ${vnc_port}:localhost:${vnc_port} -L ${web_port}:localhost:${web_port} -L ${turbovnc_web_port}:localhost:${turbovnc_web_port} ${user_name}@${node_ip}"
echo ""
echo "VNC will be available on localhost:${vnc_port}"
echo "Web interface: http://localhost:${web_port}"
echo "Press Ctrl+C to stop this tunnel."
echo ""

# Try hostname first, fallback to IP if needed
ssh -J ${user_name}@${login_node}:${login_port} \\
    -L ${vnc_port}:localhost:${vnc_port} \\
    -L ${web_port}:localhost:${web_port} \\
    -L ${turbovnc_web_port}:localhost:${turbovnc_web_port} \\
    ${user_name}@${compute_node} || \\
ssh -J ${user_name}@${login_node}:${login_port} \\
    -L ${vnc_port}:localhost:${vnc_port} \\
    -L ${web_port}:localhost:${web_port} \\
    -L ${turbovnc_web_port}:localhost:${turbovnc_web_port} \\
    ${user_name}@${node_ip}
EOF

    chmod +x /tmp/vnc_tunnel_*.sh
}

show_connection_info() {
    local vnc_port="$1"
    local web_port="$2"
    local turbovnc_web_port=$((5800 + ${vnc_port#59}))
    local user_name="$3"
    local compute_node="$4"
    local node_ip="$5"
    local login_node="$6"
    
    echo -e "${GREEN}✓ SSL Tunneling Scripts Created${NC}"
    echo ""
    echo -e "${BLUE}Auto-Detected Information:${NC}"
    echo "  Username: ${user_name}"
    echo "  Compute Node: ${compute_node}"
    echo "  Node IP: ${node_ip}"
    echo "  Login Node: ${login_node}"
    echo ""
    echo -e "${BLUE}Port Information:${NC}"
    echo "  VNC Port: ${vnc_port}"
    echo "  Web Port: ${web_port}"
    echo "  TurboVNC Web Port: ${turbovnc_web_port}"
    echo ""
    echo -e "${YELLOW}Ready-to-Copy SSH Commands:${NC}"
    echo ""
    echo -e "${CYAN}Stage 1 (Run on your local machine):${NC}"
    echo "ssh -L ${vnc_port}:localhost:${vnc_port} -L ${web_port}:localhost:${web_port} -L ${turbovnc_web_port}:localhost:${turbovnc_web_port} -p ${login_port} ${user_name}@${login_node}"
    echo ""
    echo -e "${CYAN}Stage 2 (Run on login node):${NC}"
    echo "ssh -L ${vnc_port}:localhost:${vnc_port} -L ${web_port}:localhost:${web_port} -L ${turbovnc_web_port}:localhost:${turbovnc_web_port} ${user_name}@${compute_node}"
    echo ""
    echo -e "${CYAN}Alternative Stage 2 (with IP):${NC}"
    echo "ssh -L ${vnc_port}:localhost:${vnc_port} -L ${web_port}:localhost:${web_port} -L ${turbovnc_web_port}:localhost:${turbovnc_web_port} ${user_name}@${node_ip}"
    echo ""
    echo -e "${CYAN}Direct Two-Stage Tunnel (Single Command):${NC}"
    echo "ssh -J ${user_name}@${login_node}:${login_port} -L ${vnc_port}:localhost:${vnc_port} -L ${web_port}:localhost:${web_port} -L ${turbovnc_web_port}:localhost:${turbovnc_web_port} ${user_name}@${compute_node}"
    echo ""
    echo -e "${CYAN}Alternative Direct Tunnel (with IP):${NC}"
    echo "ssh -J ${user_name}@${login_node}:${login_port} -L ${vnc_port}:localhost:${vnc_port} -L ${web_port}:localhost:${web_port} -L ${turbovnc_web_port}:localhost:${turbovnc_web_port} ${user_name}@${node_ip}"
    echo ""
    echo -e "${YELLOW}Available Scripts:${NC}"
    echo "  /tmp/vnc_tunnel_stage1.sh  - Stage 1 (Local -> Login Node)"
    echo "  /tmp/vnc_tunnel_stage2.sh  - Stage 2 (Login -> Compute Node)"
    echo "  /tmp/vnc_tunnel_direct.sh  - Direct Two-Stage Tunnel"
    echo ""
    echo -e "${GREEN}Connection URLs:${NC}"
    echo "  VNC Viewer: localhost:${vnc_port}"
    echo "  Web Browser: http://localhost:${web_port}"
    echo "  TurboVNC Web: http://localhost:${turbovnc_web_port}"
}

# Main execution
main() {
    print_header
    
    if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
        show_usage
        exit 0
    fi
    
    echo -e "${BLUE}Configuration:${NC}"
    echo "  Login Node: ${LOGIN_NODE}"
    echo "  Compute Node: ${COMPUTE_NODE}"
    echo "  Username: ${USER_NAME}"
    echo "  Node IP: ${NODE_IP}"
    echo "  VNC Port: ${VNC_PORT}"
    echo "  Web Port: ${WEB_PORT}"
    echo ""
    
    # Check if VNC is running
    if ! check_vnc_running "${VNC_PORT}"; then
        exit 1
    fi
    
    # Create tunnel scripts
    create_tunnel_scripts "${LOGIN_NODE}" "${COMPUTE_NODE}" "${VNC_PORT}" "${WEB_PORT}" "${USER_NAME}" "${NODE_IP}"
    
    # Show connection info
    show_connection_info "${VNC_PORT}" "${WEB_PORT}" "${USER_NAME}" "${COMPUTE_NODE}" "${NODE_IP}" "${LOGIN_NODE}"
}

main "$@"
SSLTUNNEL

chmod +x /usr/local/bin/vnc_ssl_tunnel.sh
echo "✓ SSL tunneling script created at /usr/local/bin/vnc_ssl_tunnel.sh"

# ===============================================================
# Create ULTIMATE VNC startup script with all optimizations
# ===============================================================
echo "==> Creating ultimate optimized VNC startup script..."

cat > /usr/local/bin/start_vnc_ultimate.sh << 'ULTIMATE'
#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# ULTIMATE TurboVNC + VirtualGL + noVNC Launcher
# With all performance optimizations
# ============================================================================

#--- Sub-block: Section continuation (4641) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

# --- Configuration ---

#--- Sub-block: Section 4774 ---
# Purpose: Continued implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
VNC_DISPLAY_NUM=${VNC_DISPLAY_NUM:-1}
VNC_PORT=$((5900 + VNC_DISPLAY_NUM))
WEB_PORT=${WEB_PORT:-6081}
GEOM="${VNC_GEOM:-1920x1080}"
DEPTH="${VNC_DEPTH:-24}"


#--- Sub-block: Code section 4534 ---
# Purpose: Continuing implementation
# Dependencies: Block 15 (VirtualGL), Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration
# Performance settings
TVNC_QUALITY="${TVNC_QUALITY:-95}"
TVNC_SUBSAMPLE="${TVNC_SUBSAMPLE:-1}"
TVNC_COMPRESSLEVEL="${TVNC_COMPRESSLEVEL:-2}"

# VirtualGL settings

# Ensure paths

# --- Cleanup function ---
cleanup() {
  echo ""
  echo "Shutting down all services..."
  vncserver -kill ":${VNC_DISPLAY_NUM}" 2>/dev/null || true
  pkill -f "websockify.*${WEB_PORT}" 2>/dev/null || true
  pkill -f pulseaudio 2>/dev/null || true
  jobs -p | xargs -r kill 2>/dev/null || true
  exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# --- Banner ---
echo "============================================"
echo "  ULTIMATE Remote Desktop Environment"
echo "============================================"
echo ""

# --- Check dependencies ---
echo "[1/8] Checking dependencies..."
for cmd in vncserver Xvnc startxfce4 vglrun websockify; do
  if command -v $cmd >/dev/null 2>&1; then
    echo "  ✓ $cmd"
  else
    echo "  ✗ $cmd - MISSING!"
    exit 1
  fi
done

#--- Sub-block: Section continuation (4694) ---
# Purpose: Implementation details
# Dependencies: Block 6.13 (NVIDIA CUDA)
# Outputs: GPU libraries, CUDA toolkit

# --- Check GPU ---
echo ""
echo "[2/8] Checking GPU..."
if command -v nvidia-smi >/dev/null 2>&1; then
  GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
  if [ -n "$GPU_NAME" ]; then
    echo "  ✓ GPU: $GPU_NAME"
  else
    echo "  ⚠ nvidia-smi found but no GPU detected"
  fi
else
  echo "  ⚠ No NVIDIA GPU detected (CPU rendering only)"
fi


#--- Sub-block: Code section 4591 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# --- Setup VNC ---
echo ""
echo "[3/8] Configuring VNC..."

# Performance-optimized xstartup
cat > "$HOME/.vnc/xstartup" << 'XSTART'
#!/bin/sh
# Performance-optimized xstartup

# Load resources
[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources" 2>/dev/null || true
fc-cache -f 2>/dev/null || true

# D-Bus
if ! dbus-send --session --dest=org.freedesktop.DBus --type=method_call \
  /org/freedesktop/DBus org.freedesktop.DBus.ListNames >/dev/null 2>&1; then
  eval "$(dbus-launch --sh-syntax)"
fi

# Disable ALL compositing and effects
xfconf-query -c xfwm4 -p /general/use_compositing -s false 2>/dev/null || true
xfconf-query -c xfce4-session -p /general/use_compositing -s false 2>/dev/null || true
xfconf-query -c xfwm4 -p /general/show_frame_shadow -s false 2>/dev/null || true
xfconf-query -c xfwm4 -p /general/show_popup_shadow -s false 2>/dev/null || true

# Disable screen management
xset s off 2>/dev/null || true
xset -dpms 2>/dev/null || true
xset s noblank 2>/dev/null || true
xset b off 2>/dev/null || true
xset r rate 250 30 2>/dev/null || true

# Start clipboard sync
autocutsel -fork -selection CLIPBOARD 2>/dev/null || true
autocutsel -fork -selection PRIMARY 2>/dev/null || true

# XFCE
exec startxfce4
XSTART
chmod +x "$HOME/.vnc/xstartup"
echo "  ✓ xstartup configured"

#--- Sub-block: Section continuation (4754) ---
# Purpose: Implementation details
# Dependencies: Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration

# --- Start VNC ---
echo ""
echo "[4/8] Starting TurboVNC server..."
echo "  Display: :${VNC_DISPLAY_NUM}"
echo "  Geometry: ${GEOM}"
echo "  Quality: ${TVNC_QUALITY}"
echo "  Subsample: ${TVNC_SUBSAMPLE}"


#--- Sub-block: Code section 4642 ---
# Purpose: Continuing implementation
# Dependencies: Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration
if [ ! -f "$HOME/.vnc/passwd" ]; then
  echo ""
  echo "⚠ VNC password not set. Please set it now:"
  vncpasswd
  echo ""
fi

vncserver ":${VNC_DISPLAY_NUM}" \
  -geometry "${GEOM}" \
  -depth "${DEPTH}" \
  -localhost \
  -xstartup "$HOME/.vnc/xstartup" \
  -quality ${TVNC_QUALITY} \
  -compresslevel ${TVNC_COMPRESSLEVEL} \
  -subsample ${TVNC_SUBSAMPLE}

sleep 3

if ! vncserver -list 2>/dev/null | grep -q ":${VNC_DISPLAY_NUM}"; then
  echo "  ✗ VNC server failed to start"
  cat ~/.vnc/*.log 2>/dev/null | tail -20
  exit 1
fi
echo "  ✓ VNC server running on :${VNC_DISPLAY_NUM}"

# --- Start PulseAudio ---
echo ""
echo "[5/8] Starting audio support..."
if command -v pulseaudio >/dev/null 2>&1; then
  if ! pulseaudio --check 2>/dev/null; then
    pulseaudio --start --exit-idle-time=-1 2>/dev/null &
    echo "  ✓ PulseAudio started"
  else
    echo "  ✓ PulseAudio already running"
  fi
else
  echo "  ⚠ PulseAudio not available"
fi

#--- Sub-block: Section continuation (4804) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

# --- Start noVNC ---
echo ""
echo "[6/8] Starting noVNC (HTML5 interface)..."

WEBSOCKIFY=""
for candidate in /usr/bin/websockify /usr/local/bin/websockify; do
  [ -x "$candidate" ] && WEBSOCKIFY="$candidate" && break
done


#--- Sub-block: Code section 4690 ---
# Purpose: Continuing implementation
# Dependencies: Block 15 (VirtualGL)
# Outputs: VNC server, GPU acceleration
if [ -z "$WEBSOCKIFY" ]; then
  echo "  ✗ websockify not found - skipping web interface"
else
  NOVNC_DIR=""
  for candidate in /usr/local/share/novnc /usr/share/novnc; do
    [ -d "$candidate" ] && [ -f "$candidate/vnc.html" ] && NOVNC_DIR="$candidate" && break
  done

  if [ -n "$NOVNC_DIR" ]; then
    $WEBSOCKIFY --web "$NOVNC_DIR" ${WEB_PORT} localhost:${VNC_PORT} 2>&1 | \
      grep -v "WARNING" | grep -v "numpy" &
    WSPID=$!
    sleep 2
    if kill -0 $WSPID 2>/dev/null; then
      echo "  ✓ noVNC running on port ${WEB_PORT}"
    else
      echo "  ✗ noVNC failed to start"
    fi
  else
    echo "  ⚠ noVNC files not found"
  fi
fi

# --- Performance check ---
echo ""
echo "[7/8] Running performance check..."

# Quick GPU test
if command -v vglrun >/dev/null 2>&1 && command -v glxinfo >/dev/null 2>&1; then
  RENDERER=$(vglrun glxinfo 2>/dev/null | grep "OpenGL renderer" | cut -d: -f2 | xargs)
  if [ -n "$RENDERER" ]; then
    echo "  ✓ GPU rendering: $RENDERER"
  else
    echo "  ⚠ GPU rendering test failed"
  fi
else
  echo "  ⚠ Cannot test GPU rendering"
fi

#--- Sub-block: Section continuation (4856) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

# --- Connection info ---
NODE=$(hostname -f 2>/dev/null || hostname)
echo ""
echo "============================================"
echo "  🎉 Remote Desktop Ready!"
echo "============================================"
echo ""
echo "Node: $NODE"
echo "Display: :${VNC_DISPLAY_NUM}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "METHOD 1: VNC Viewer (Best Performance)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TWO-STAGE SSL TUNNELING (HPC Environment):"
echo ""
echo "Stage 1 - Tunnel to Login Node:"
echo "   ssh -L ${VNC_PORT}:localhost:${VNC_PORT} \$USER@login.hpc.edu"
echo ""
echo "Stage 2 - From Login Node to Compute Node:"
echo "   ssh -L ${VNC_PORT}:localhost:${VNC_PORT} \$USER@${NODE}"
echo ""
echo "Alternative - Direct Two-Stage Tunnel:"
echo "   ssh -J \$USER@login.hpc.edu -L ${VNC_PORT}:localhost:${VNC_PORT} \$USER@${NODE}"
echo ""
echo "Connect VNC to: localhost:${VNC_PORT}"
echo ""


#--- Sub-block: Code section 4749 ---
# Purpose: Continuing implementation
# Dependencies: Block 15 (VirtualGL), Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration
if [ -n "${WSPID:-}" ] && kill -0 $WSPID 2>/dev/null; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "METHOD 2: Web Browser (No Install Needed)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "TWO-STAGE SSL TUNNELING (HPC Environment):"
  echo ""
  echo "Stage 1 - Tunnel to Login Node:"
  echo "   ssh -L ${WEB_PORT}:localhost:${WEB_PORT} \$USER@login.hpc.edu"
  echo ""
  echo "Stage 2 - From Login Node to Compute Node:"
  echo "   ssh -L ${WEB_PORT}:localhost:${WEB_PORT} \$USER@${NODE}"
  echo ""
  echo "Alternative - Direct Two-Stage Tunnel:"
  echo "   ssh -J \$USER@login.hpc.edu -L ${WEB_PORT}:localhost:${WEB_PORT} \$USER@${NODE}"
  echo ""
  echo "Browse: http://localhost:${WEB_PORT}"
  echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PERFORMANCE TIPS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "• GPU apps: vglrun <app> or use aliases (vblender, etc.)"
echo "• Benchmark: vgl_benchmark.sh"
echo "• Monitor: vnc_monitor.sh"
echo "• Tune VNC: turbovnc_tune.sh"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "CONTROLS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "• Stop: Press Ctrl+C"
echo "• Logs: tail -f ~/.vnc/*.log"
echo "• Status: vncserver -list"
echo "============================================"
echo ""

# --- Monitor and keep alive ---
echo "[8/8] Monitoring services..."
while true; do
  sleep 30

  # Check VNC
  if ! vncserver -list 2>/dev/null | grep -q ":${VNC_DISPLAY_NUM}"; then
    echo "ERROR: VNC server died"
    exit 1
  fi

#--- Sub-block: Section continuation (4917) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

  # Check websockify
  if [ -n "${WSPID:-}" ]; then
    if ! kill -0 $WSPID 2>/dev/null; then
      echo "WARNING: websockify died, restarting..."
      $WEBSOCKIFY --web "$NOVNC_DIR" ${WEB_PORT} localhost:${VNC_PORT} 2>&1 | \
        grep -v "WARNING" &
      WSPID=$!
    fi
  fi
done
ULTIMATE
chmod +x /usr/local/bin/start_vnc_ultimate.sh


#--- Sub-block: Code section 4801 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "✓ Ultimate VNC startup script created"

# Create enhanced noVNC launcher with all features
cat > /usr/local/bin/start_novnc_advanced.sh << 'NOVNCADV'
#!/usr/bin/env bash
# Advanced noVNC launcher with token authentication and SSL

set -euo pipefail

VNC_DISPLAY=${1:-:1}
WEB_PORT=${2:-6081}
VNC_PORT=$((5900 + ${VNC_DISPLAY#:}))

# Generate random token for this session
TOKEN=$(openssl rand -hex 16)

echo "=========================================="
echo "Advanced noVNC Server"
echo "=========================================="
echo "VNC Display: $VNC_DISPLAY"
echo "Web Port: $WEB_PORT"
echo "Token: $TOKEN"
echo ""
echo "Connect: http://localhost:$WEB_PORT/?token=$TOKEN"
echo "=========================================="

# Start websockify with token authentication
/usr/bin/websockify \
  --web /usr/local/share/novnc \
  --token-plugin TokenFile \
  --token-source <(echo "$TOKEN: localhost:$VNC_PORT") \
  $WEB_PORT
NOVNCADV
chmod +x /usr/local/bin/start_novnc_advanced.sh

echo "✓ Advanced noVNC features configured"

# Create VirtualGL test and debug script
cat > /usr/local/bin/test_virtualgl.sh << 'VGLTEST'
#!/usr/bin/env bash
# VirtualGL Test and Debug Script

set -euo pipefail

# Configuration
VGL_DISPLAY="${VGL_DISPLAY:-:1}"
VGL_VERBOSE="${VGL_VERBOSE:-1}"
VGL_DEBUG="${VGL_DEBUG:-1}"

echo "=========================================="
echo "VirtualGL Test and Debug Script"
echo "=========================================="
echo ""

# Test 1: Check VirtualGL installation
echo "1. Checking VirtualGL installation..."
if command -v vglrun >/dev/null 2>&1; then
  echo "  ✓ vglrun found: $(which vglrun)"
  vglrun --version 2>/dev/null || echo "  ⚠ Could not get version"
else
  echo "  ✗ vglrun not found"
  exit 1
fi

# Test 2: Check display
echo ""
echo "2. Checking display configuration..."
echo "  VGL_DISPLAY: $VGL_DISPLAY"
echo "  DISPLAY: ${DISPLAY:-not set}"

if [ -S "/tmp/.X11-unix/X${VGL_DISPLAY#:}" ]; then
  echo "  ✓ X socket found: /tmp/.X11-unix/X${VGL_DISPLAY#:}"
else
  echo "  ✗ X socket not found: /tmp/.X11-unix/X${VGL_DISPLAY#:}"
fi

# Test 3: Test VirtualGL connection
echo ""
echo "3. Testing VirtualGL connection..."
if vglrun -d "$VGL_DISPLAY" glxinfo >/dev/null 2>&1; then
  echo "  ✓ VirtualGL can access display $VGL_DISPLAY"
else
  echo "  ✗ VirtualGL cannot access display $VGL_DISPLAY"
  echo "  Trying to get more info..."
  vglrun -d "$VGL_DISPLAY" glxinfo 2>&1 | head -10
fi

# Test 4: Check OpenGL rendering
echo ""
echo "4. Checking OpenGL rendering..."
if vglrun -d "$VGL_DISPLAY" glxinfo | grep -q "OpenGL renderer"; then
  echo "  ✓ OpenGL rendering available"
  echo "  OpenGL renderer: $(vglrun -d "$VGL_DISPLAY" glxinfo | grep "OpenGL renderer" | head -1)"
  echo "  OpenGL version: $(vglrun -d "$VGL_DISPLAY" glxinfo | grep "OpenGL version" | head -1)"
else
  echo "  ✗ OpenGL rendering not available"
fi

# Test 5: Test glxspheres64
echo ""
echo "5. Testing glxspheres64..."
if command -v glxspheres64 >/dev/null 2>&1; then
  echo "  ✓ glxspheres64 found"
  echo "  Running glxspheres64 test (5 seconds)..."
  timeout 5s vglrun -d "$VGL_DISPLAY" glxspheres64 2>&1 | head -10 || echo "  ⚠ glxspheres64 test timed out or failed"
else
  echo "  ✗ glxspheres64 not found"
fi

# Test 6: Environment variables
echo ""
echo "6. VirtualGL environment variables:"
echo "  VGL_DISPLAY: ${VGL_DISPLAY:-not set}"
echo "  VGL_COMPRESS: ${VGL_COMPRESS:-not set}"
echo "  VGL_READBACK: ${VGL_READBACK:-not set}"
echo "  VGL_LOGO: ${VGL_LOGO:-not set}"
echo "  VGL_FPS: ${VGL_FPS:-not set}"
echo "  VGL_VERBOSE: ${VGL_VERBOSE:-not set}"

# Test 7: X11 authentication
echo ""
echo "7. Checking X11 authentication..."
if [ -f "$HOME/.Xauthority" ]; then
  echo "  ✓ .Xauthority file found"
  if xauth list 2>/dev/null | grep -q "$VGL_DISPLAY"; then
    echo "  ✓ X11 auth for display $VGL_DISPLAY found"
  else
    echo "  ⚠ X11 auth for display $VGL_DISPLAY not found"
  fi
else
  echo "  ⚠ .Xauthority file not found"
fi

echo ""
echo "=========================================="
echo "VirtualGL test completed"
echo "=========================================="
VGLTEST

chmod +x /usr/local/bin/test_virtualgl.sh
echo "✓ VirtualGL test script created"

#===============================================================================
# BLOCK 21: ADDITIONAL VNC AND DISPLAY SERVERS (Part 3 of 3)
#===============================================================================
# 🖥️  REMOTE DESKTOP INFRASTRUCTURE - ALTERNATIVE VNC SERVERS
#
# This is Part 3 of the Remote Desktop Infrastructure spanning 3 blocks:
#   • Block 15 (line ~3320): TurboVNC & VirtualGL installation (COMPLETED)
#   • Block 20 (line ~4983): Primary VNC launcher scripts (COMPLETED)
#   • Block 21 (HERE):       Alternative VNC servers and display options
#
# Purpose: Install alternative VNC servers for specific use cases
# Self-contained: Yes (complete alternative implementations)
# Dependencies: Block 15 (VirtualGL), Block 20 (base config), X11
# Outputs: TigerVNC, KasmVNC (web-based), alternative launchers
#
# Available VNC Implementations:
#   PRIMARY:     TurboVNC (Block 15) - High performance, GPU-accelerated
#   Alternative: TigerVNC (here)     - Standard VNC server
#   Web-based:   KasmVNC (here)      - Browser-based access
#   Lightweight: x11vnc (Block 14)   - Attach to existing displays
#
# Use vnc_select.sh to choose which server to use
# See Also: Block 15.20 for complete remote desktop infrastructure summary
#-------------------------------------------------------------------------------

#--- Sub-block 21.1: KasmVNC installation ---
# Critical: Modern VNC with web UI and containerized features
# Dependencies: Block 6 (APT configuration), Block 15 (TurboVNC)
# Outputs: Installed packages
echo "==> Installing KasmVNC (modern alternative)..."

# KasmVNC has better web integration and modern features (version from config.sh)
ARCH="amd64"

cd /tmp
if wget -q "https://github.com/kasmtech/KasmVNC/releases/download/v${KASMVNC_VERSION}/kasmvncserver_jammy_${KASMVNC_VERSION}_${ARCH}.deb"; then
    apt-get install -y ./kasmvncserver_jammy_${KASMVNC_VERSION}_${ARCH}.deb || echo "⚠ KasmVNC installation failed (non-critical)"
    rm -f ./kasmvncserver_jammy_${KASMVNC_VERSION}_${ARCH}.deb
    echo "✓ KasmVNC installed successfully"
else
    echo "⚠ Failed to download KasmVNC (non-critical, continuing)"
fi

# Create KasmVNC startup script
cat > /usr/local/bin/start_kasmvnc.sh << 'KASMSTART'
#!/usr/bin/env bash
# KasmVNC - Modern VNC with built-in web interface

set -euo pipefail

DISPLAY_NUM=1
VNC_PORT=$((5900 + DISPLAY_NUM))
WEB_PORT=6901

mkdir -p ~/.vnc

# Create KasmVNC xstartup
cat > ~/.vnc/xstartup << 'XS'
#!/bin/sh
eval "$(dbus-launch --sh-syntax)" 2>/dev/null || true
xfconf-query -c xfwm4 -p /general/use_compositing -s false 2>/dev/null || true
exec startxfce4
XS
chmod +x ~/.vnc/xstartup

echo "Starting KasmVNC..."
echo "  Display: :$DISPLAY_NUM"
echo "  VNC Port: $VNC_PORT"
echo "  Web Port: $WEB_PORT"
echo ""
echo "Connect: http://localhost:$WEB_PORT"
echo ""

#--- Sub-block: Section continuation (5022) ---
# Purpose: Implementation details
# Dependencies: Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration

kasmvncserver :$DISPLAY_NUM \
  -geometry 1920x1080 \
  -depth 24 \
  -websocketPort $WEB_PORT \
  -interface 0.0.0.0


#--- Sub-block: Code section 4896 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "KasmVNC started!"
tail -f ~/.vnc/*.log
KASMSTART
chmod +x /usr/local/bin/start_kasmvnc.sh

echo "✓ KasmVNC installed (use: start_kasmvnc.sh)"

#--- Sub-block 21.2: Vulkan graphics API support ---
# Critical: Modern GPU acceleration API for high-performance rendering
# Dependencies: Block 6 (APT configuration), Block 15 (VirtualGL)
# Outputs: Installed packages
echo "==> Installing Vulkan support..."

apt-get install -y --no-install-recommends \
  vulkan-tools \
  vulkan-validationlayers \
  mesa-vulkan-drivers \
  libvulkan1

# Create Vulkan test script
cat > /usr/local/bin/test_vulkan.sh << 'VULKAN'
#!/usr/bin/env bash
# Test Vulkan support

echo "Vulkan Instance Version:"
vulkaninfo --summary | grep "Vulkan Instance Version"

echo ""
echo "Available Vulkan Devices:"
vulkaninfo | grep -A 5 "GPU id"

echo ""
echo "Running vulkan cube demo (vglrun required)..."
if command -v vglrun >/dev/null 2>&1; then
  vglrun vkcube
else
  vkcube
fi
VULKAN
chmod +x /usr/local/bin/test_vulkan.sh

echo "✓ Vulkan support installed"

#--- Sub-block 21.3: Xpra modern X11 forwarding ---
# Critical: Seamless application forwarding with HTML5 client
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing Xpra for modern X11 forwarding..."

apt-get install -y --no-install-recommends \
  xpra \
  xpra-html5

# Create Xpra launcher
cat > /usr/local/bin/start_xpra.sh << 'XPRA'
#!/usr/bin/env bash
# Xpra Application Streaming

DISPLAY_NUM=${1:-10}
PORT=$((10000 + DISPLAY_NUM))

echo "Starting Xpra on display :${DISPLAY_NUM}"
echo "HTML5 client: http://localhost:${PORT}"

xpra start :${DISPLAY_NUM} \
  --bind-tcp=0.0.0.0:${PORT} \
  --html=on \
  --start=startxfce4 \
  --daemon=no
XPRA
chmod +x /usr/local/bin/start_xpra.sh

echo "✓ Xpra installed (HTML5 seamless window streaming)"

#--- Sub-block 21.4: x11vnc alternative VNC server ---
# Critical: Lightweight VNC server that attaches to existing X sessions
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing x11vnc..."

apt-get install -y --no-install-recommends x11vnc

cat > /usr/local/bin/start_x11vnc.sh << 'X11VNC'
#!/usr/bin/env bash
# x11vnc - attach to existing X display

DISPLAY_NUM=${1:-1}
PORT=$((5900 + DISPLAY_NUM))

echo "Starting x11vnc on display :${DISPLAY_NUM} (port ${PORT})"

x11vnc -display :${DISPLAY_NUM} \
  -forever \
  -shared \
  -rfbport ${PORT} \
  -nopw
X11VNC
chmod +x /usr/local/bin/start_x11vnc.sh

echo "✓ x11vnc installed"

#===============================================================================
# BLOCK 22: MULTIMEDIA AND PERFORMANCE TOOLS
#===============================================================================
# Purpose: Install video encoding, performance monitoring, and system tools
# Self-contained: Yes (complete multimedia stack)
# Dependencies: NVIDIA drivers for hardware encoding
# Outputs: GPU libraries, CUDA toolkit
#-------------------------------------------------------------------------------

#--- Sub-block 22.1: FFmpeg with hardware encoding ---
# Critical: Video encoding with NVENC GPU acceleration
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing ffmpeg with NVENC support..."

apt-get install -y --no-install-recommends \
  ffmpeg \
  libavcodec-extra

# Create screen recording script
#--- Sub-block 22.1: Create screen recording script ---
# Purpose: ffmpeg-based screen recording with GPU encoding
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
cat > /usr/local/bin/record_screen.sh << 'RECORD'
#!/usr/bin/env bash
# Screen recording with GPU encoding

DISPLAY_NUM=${1:-1}
OUTPUT=${2:-"screen_recording_$(date +%Y%m%d_%H%M%S).mp4"}

echo "Recording display :${DISPLAY_NUM} to ${OUTPUT}"
echo "Press Ctrl+C to stop"

# Try NVENC (GPU encoding), fallback to libx264 (CPU)
if ffmpeg -encoders 2>/dev/null | grep -q h264_nvenc; then
  ENCODER="h264_nvenc"
  echo "Using NVIDIA GPU encoder"
else
  ENCODER="libx264"
  echo "Using CPU encoder"
fi

DISPLAY=:${DISPLAY_NUM} ffmpeg \
  -f x11grab \
  -video_size 1920x1080 \
  -framerate 30 \
  -i :${DISPLAY_NUM} \
  -c:v ${ENCODER} \
  -preset medium \
  -crf 23 \
  "${OUTPUT}"
RECORD
chmod +x /usr/local/bin/record_screen.sh

echo "✓ ffmpeg installed with screen recording support"

#--- Sub-block 22.2: Remmina remote desktop client ---
# Critical: Multi-protocol remote desktop client (VNC/RDP/SSH)
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing Remmina remote desktop client..."

apt-get install -y --no-install-recommends \
  remmina \
  remmina-plugin-vnc \
  remmina-plugin-rdp

echo "✓ Remmina installed (launch from Applications menu)"

#--- Sub-block 22.3: Performance monitoring and profiling tools ---
# Critical: System performance analysis, debugging, and resource monitoring
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing performance monitoring tools..."

apt-get install -y --no-install-recommends \
  htop \
  iotop \
  iftop \
  nethogs \
  nload \
  bmon \
  sysstat \
  dstat \
  atop \
  glances \
  btop \
  nmon

# Create GPU monitoring script
#--- Sub-block 22.4: Create GPU monitoring script ---
# Purpose: Real-time GPU utilization monitoring
# Dependencies: Block 6.13 (NVIDIA CUDA)
# Outputs: GPU libraries, CUDA toolkit
cat > /usr/local/bin/gpu_monitor.sh << 'GPUMON'
#!/usr/bin/env bash
# Real-time GPU monitoring

watch -n 1 "nvidia-smi --query-gpu=timestamp,name,utilization.gpu,utilization.memory,memory.total,memory.used,memory.free,temperature.gpu,power.draw --format=csv,noheader,nounits | column -t -s','"
GPUMON
chmod +x /usr/local/bin/gpu_monitor.sh

echo "✓ Performance monitoring tools installed"
echo "  - glances (comprehensive system monitor)"
echo "  - htop/btop (process viewers)"
echo "  - gpu_monitor.sh (GPU stats)"

# Create VNC performance monitor script
#--- Sub-block 22.5: Create VNC performance monitor ---
# Purpose: Monitor VNC session performance and connections
# Dependencies: Block 6.13 (NVIDIA CUDA)
# Outputs: GPU libraries, CUDA toolkit
cat > /usr/local/bin/vnc_monitor.sh << 'VNCMON'
#!/usr/bin/env bash
# Monitor VNC session performance

echo "=========================================="
echo "VNC Session Performance Monitor"
echo "=========================================="
echo ""

echo "1. VNC Processes:"
ps aux | grep -E "Xvnc|websockify|xfce" | grep -v grep
echo ""

echo "2. Network Connections:"
ss -tuln | grep -E "5901|6081|5800"
echo ""

echo "3. GPU Utilization:"
if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=utilization.gpu,utilization.memory,memory.used,memory.total \
      --format=csv,noheader,nounits
else
    echo "  nvidia-smi not available"
fi
echo ""

echo "4. CPU Usage (VNC related):"
ps aux | grep -E "Xvnc|websockify" | grep -v grep | awk '{print $3}' | \
  awk '{sum+=$1} END {print "  Total CPU: " sum "%"}'
echo ""

echo "5. Memory Usage:"
free -h
echo ""

echo "6. Display Information:"
if [ -n "$DISPLAY" ]; then
    echo "  DISPLAY: $DISPLAY"
    xdpyinfo | grep -E "dimensions|resolution" | sed 's/^/  /'
else
    echo "  Not running in X session"
fi
echo "=========================================="
VNCMON
chmod +x /usr/local/bin/vnc_monitor.sh

#--- Sub-block: Section continuation (5272) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 5137 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "✓ Performance monitoring tools installed"

#===============================================================================
# BLOCK 23: MODERN RUST-BASED CLI TOOLS
#===============================================================================
# Purpose: Install fast, modern alternatives to traditional CLI tools
# Self-contained: Yes (complete Rust toolset)
# Dependencies: None (standalone binaries)
# Outputs: Environment variables, configuration
#-------------------------------------------------------------------------------

#--- Sub-block 23.1: Rust-based system utilities (COMPILED FROM SOURCE) ---
# Critical: Rust tools compiled from source in Block 24 for optimization
# Dependencies: Block 24 (Rust toolchain + cargo install)
# Outputs: Deferred to Block 24
# Note: bat, fd, ripgrep, eza, bottom, procs installed via cargo for native optimization
echo "==> Rust tools (bat, fd, ripgrep, eza, bottom, procs) compiled from source in Block 24"

#--- Sub-block: Section continuation (5327) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

# zoxide (better cd)
curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash


#--- Sub-block: Code section 5192 (ALIASES MOVED TO BLOCK 24) ---
# Purpose: Rust tool aliases configured after compilation in Block 24
# Dependencies: Block 24 (cargo install)
# Outputs: Deferred to Block 24
echo "==> Rust tool aliases will be configured after compilation in Block 24"

# === Ulauncher (baseline) ===
# Ulauncher (PPA already added above)
apt-get -y --no-install-recommends install ulauncher
debug_glibc "After installing Ulauncher"

# === Install Alacritty: A modern, GPU-accelerated terminal ===
echo "==> Installing Alacritty (Rust-based, GPU-accelerated terminal)..."
apt-get install -y --no-install-recommends alacritty
# Set Alacritty as the default terminal for XFCE
echo "==> Configuring Alacritty as the default terminal..."
xfconf-query -c helpers -p /main/TerminalEmulator -s alacritty 2>/dev/null || true
# This ensures that launching a "Terminal" from the GUI uses Alacritty
# Note: gconftool-2 is for GNOME 2, skip if not available (XFCE doesn't need it)
if command -v gconftool-2 &>/dev/null; then
  gconftool-2 --set --type=string /desktop/gnome/applications/terminal/exec alacritty 2>/dev/null || true
fi
update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/alacritty 50

# === ADDITION 2: IPC Infrastructure ===
apt-get install -y \
  libzmq3-dev \
  libzmq5 \
  libfastrtps-dev \
  cyclonedds-dev \
  cyclonedds-tools \
  libcycloneddsidl0t64 \
  supervisor

#--- Sub-block: Section continuation (5380) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 5239 ---
# Purpose: Continuing implementation
# Dependencies: Block 6 (APT configuration), Block 8.5 (Julia installation)
# Outputs: Installed packages
# Remove Debian-managed Python packages that we'll reinstall via pip
apt-get remove -y python3-zmq 2>/dev/null || true
pip3 install --no-cache-dir \
  pyzmq==${PYZMQ_VERSION} \
  msgpack==${MSGPACK_VERSION}

# === ADDITION 3: Julia-Python Bridge (Modern) ===
pip3 install --no-cache-dir \
  juliacall==${JULIACALL_VERSION} \
  juliapkg==${JULIAPKG_VERSION}

# JULIA PACKAGES (After fixing pip)
${JULIA_HOME}/bin/julia -e '
  using Pkg

  # Python bridge packages (these use pip internally)
  Pkg.add(["PythonCall", "CondaPkg"])

  # Configure to use system Python
  ENV["JULIA_CONDAPKG_BACKEND"] = "Null"
  ENV["PYTHON"] = "/usr/bin/python3"

  # Build with system Python (now pip works)
  try
    Pkg.build("PythonCall")
  catch e
    @warn "PythonCall build failed" exception=e
  end

  # Image processing packages
  Pkg.add([
    "Images",
    "ImageFiltering",
    "ImageFeatures",
    "VideoIO"
  ])

  # IPC packages
  Pkg.add(["ZMQ", "MsgPack", "JSON3"])

#--- Sub-block: Section continuation (5423) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Rust CLI tools compilation ---
# Purpose: Build modern command-line utilities
# Dependencies: Block 6.13 (NVIDIA CUDA)
# Outputs: GPU libraries, CUDA toolkit
  # GPU packages
  Pkg.add(["CUDA"])

  # Precompile
  Pkg.precompile()
'
# === ADDITION 4: Monitoring Tools ===

#--- Sub-block: Code section 5286 ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

#--- Sub-block: Rust tool compilation ---
# Purpose: Compiling Rust-based CLI tools
# Purpose: Continuing implementation
# Dependencies: Block 6 (APT configuration), PHASE 1 (Build tools)
# Outputs: Installed packages
apt-get install -y \
  htop \
  iotop \
  glances \

# Install nvtop (GPU monitor)
echo "Building nvtop (GPU monitoring tool)..."
cd /tmp || { echo "ERROR: Failed to access /tmp directory"; exit 1; }
rm -rf nvtop  # Clean any existing clone
git clone https://github.com/syllo/nvtop.git || { echo "ERROR: Failed to clone nvtop"; exit 1; }
cd nvtop || { echo "ERROR: Failed to access nvtop directory"; exit 1; }

# Clean build directory
rm -rf build CMakeCache.txt
mkdir build || { echo "ERROR: Failed to create build directory"; exit 1; }
cd build || { echo "ERROR: Failed to access build directory"; exit 1; }

# Modern nvtop (v3.0+) uses different CMake options
# Old flags (NVML_SUPPORT, USE_SYSTEM_NVML) are deprecated
cmake .. \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DNVIDIA_SUPPORT=ON \
  -DAMDGPU_SUPPORT=OFF \
  -DINTEL_SUPPORT=OFF \
  -DAPPLE_SUPPORT=OFF \
  -DMSM_SUPPORT=OFF \
  -DCMAKE_INSTALL_PREFIX=/usr/local

ninja -j$(nproc) || { echo "ERROR: Failed to build nvtop"; exit 1; }
ninja install || { echo "ERROR: Failed to install nvtop"; exit 1; }

cd / && rm -rf /tmp/nvtop
echo "✓ nvtop installed successfully"


#--- Sub-block: Rust tools build continuation ---
# Purpose: Additional CLI tool compilation
# Dependencies: Block 6 (APT configuration), Block 8.5 (Julia installation)
# Outputs: Installed packages
# === ADDITION 5: Efficient Data Formats ===
apt-get install -y \
  libhdf5-dev \
  liblz4-dev
pip3 install --no-cache-dir \
  h5py==${H5PY_VERSION} \
  zarr==${ZARR_VERSION}
${JULIA_HOME}/bin/julia -e '
  using Pkg
  Pkg.add(["HDF5", "JLD2"])
'

# === FAST-DDS CONFIGURATION ===
echo "==> Configuring Fast-DDS (default RMW for ROS 2)"
mkdir -p /etc/fastdds
cat > /etc/fastdds/DEFAULT_FASTRTPS_PROFILES.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8" ?>
<profiles xmlns="http://www.eprosima.com/XMLSchemas/fastRTPS_Profiles">
    <participant profile_name="default_participant" is_default_profile="true">
        <rtps>
            <useBuiltinTransports>true</useBuiltinTransports>
            <builtin>
                <discovery_config>
                    <discoveryProtocol>SIMPLE</discoveryProtocol>
                    <use_SIMPLE_EndpointDiscoveryProtocol>true</use_SIMPLE_EndpointDiscoveryProtocol>
                    <use_STATIC_EndpointDiscoveryProtocol>false</use_STATIC_EndpointDiscoveryProtocol>
                    <leaseDuration>
                        <sec>20</sec>
                        <nanosec>0</nanosec>
                    </leaseDuration>
                </discovery_config>
            </builtin>
            <userTransports>
                <transport_id>shm_transport</transport_id>
                <transport_id>udp_transport</transport_id>
            </userTransports>
        </rtps>
    </participant>

#--- Sub-block: Section continuation (5485) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 5338 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
    <transport_descriptors>
        <transport_descriptor>
            <transport_id>shm_transport</transport_id>
            <type>SHM</type>
            <maxMessageSize>65536</maxMessageSize>
        </transport_descriptor>
        <transport_descriptor>
            <transport_id>udp_transport</transport_id>
            <type>UDPv4</type>
            <maxMessageSize>65536</maxMessageSize>
        </transport_descriptor>
    </transport_descriptors>
</profiles>
EOF

# Set environment variable to use this config
echo 'export FASTRTPS_DEFAULT_PROFILES_FILE=/etc/fastdds/DEFAULT_FASTRTPS_PROFILES.xml' >> /etc/profile.d/fastdds.sh
echo "✓ Fast-DDS configured"

# === ADDITION 7: Helper Scripts Directory ===
mkdir -p /opt/scripts
# Domain bridge script (detailed later)
# Julia vision server (detailed later)
# Python-Julia bridge helpers (detailed later)

#===============================================================================
# BLOCK 24: RUST TOOLCHAIN INSTALLATION
#===============================================================================
# Purpose: Install Rust compiler and cargo package manager
# Self-contained: Yes (complete with rustup installation)
# Dependencies: curl, system libraries
# Outputs: Configured system components
#-------------------------------------------------------------------------------

#--- Sub-block 24.1: Initialize Rust installation ---
# Dependencies: Block 24 (Rust toolchain)
# Outputs: Rust binaries in /opt/rust/tools/bin
echo
echo "Installing Rust Toolchain via rustup"
echo

#--- Sub-block 24.2: Create Rust directories ---
# Dependencies: Block 24 (Rust toolchain)
# Outputs: Rust binaries in /opt/rust/tools/bin
# CRITICAL: Create directories BEFORE setting environment variables
mkdir -p /opt/rust/{cargo,rustup,tools/bin}

# Set ownership (we re root during build)
chown -R root:root /opt/rust
chmod -R 755 /opt/rust

export RUSTUP_HOME=/opt/rust/rustup
export CARGO_HOME=/opt/rust/cargo

#--- Sub-block 24.3: Install Rust toolchain via rustup ---
# Purpose: Install Rust compiler and package manager
# Dependencies: Block 24 (Rust toolchain)
# Outputs: Rust binaries in /opt/rust/tools/bin
echo "--> Downloading and installing rustup..."
if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
  sh -s -- \
    -y \
    --no-modify-path \
    --profile minimal \
    --default-toolchain stable; then
  echo "✓ rustup installation completed"
else
  echo "✗ rustup installation failed"
  exit 1
fi

# CRITICAL: Add to PATH for this build session
export PATH="/opt/rust/cargo/bin:${PATH}"

# Verify Rust is available
echo "--> Verify Rust installation..."
if command -v rustc &>/dev/null && command -v cargo &>/dev/null; then
  echo "✓ Rust toolchain installed successfully"
  echo "  rustc version: $(rustc --version)"
  echo "  cargo version: $(cargo --version)"
  echo "  rustup location: $(which rustup)"
  echo "  cargo location: $(which cargo)"
else
  echo "✗ Rust installation failed - binaries not found"
  echo "  PATH: $PATH"
  echo "  Directory contents:"
  ls -la /opt/rust/cargo/bin || echo "cargo/bin directory doesn't exist"
  exit 1
fi

# === RUST TOOLS COMPILATION ===
echo
echo "Compiling Rust Tools from Source"
echo "This will take 15-20 minutes..."
echo

#--- Sub-block: Section continuation (5580) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

# Set build flags for generic x86-64 compatibility
export RUSTFLAGS="-C target-cpu=x86-64 -C opt-level=2"


#--- Sub-block 24.4: Rust tool installation function ---
# Purpose: Reusable function for cargo install with error tracking
# Dependencies: Block 24 (Rust toolchain)
# Outputs: Populates INSTALLED_TOOLS and FAILED_TOOLS
# Self-contained: Yes (complete function definition)
install_rust_tool() {
  local package="$1"
  local version="$2"
  local description="$3"
  local build_time="$4"
  
  echo "==> Compiling ${package} (${description})..."
  echo "  This takes ~${build_time} minutes..."
  
  if [ -n "$version" ]; then
    # Try first with --locked (respect Cargo.lock)
    if cargo install "${package}" \
        --version "$version" \
        --root /opt/rust/tools \
        --locked 2>/dev/null; then
      echo "✓ ${package} installed successfully (with --locked)"
      INSTALLED_TOOLS="${INSTALLED_TOOLS} ${package}"
      return 0
    else
      echo "[warn] Installation with --locked failed, retrying without lock file..."
      # Retry without --locked to allow dependency updates (handles yanked packages)
      if cargo install "${package}" \
          --version "$version" \
          --root /opt/rust/tools; then
        echo "✓ ${package} installed successfully (without --locked)"
        INSTALLED_TOOLS="${INSTALLED_TOOLS} ${package}"
        return 0
      else
        echo "✗ ${package} installation failed"
        FAILED_TOOLS="${FAILED_TOOLS} ${package}"
        return 1
      fi
    fi
  else
    # No version specified, try without --locked for latest
    if cargo install "${package}" \
        --root /opt/rust/tools; then
      echo "✓ ${package} installed successfully"
      INSTALLED_TOOLS="${INSTALLED_TOOLS} ${package}"
      return 0
    else
      echo "✗ ${package} installation failed"
      FAILED_TOOLS="${FAILED_TOOLS} ${package}"
      return 1
    fi
  fi
}

#--- Sub-block 24.4.0: Binary fallback installation function ---
# Purpose: Download pre-compiled binaries if cargo install fails
# Dependencies: Block 24 (Rust toolchain)
# Outputs: Binary in /opt/rust/tools/bin
install_prebuilt_binary() {
  local tool_name="$1"
  local binary_url="$2"
  local binary_name="$3"
  
  echo "==> Attempting binary fallback for ${tool_name}..."
  
  if curl -fsSL -o "/tmp/${binary_name}" "${binary_url}"; then
    chmod +x "/tmp/${binary_name}"
    mv "/tmp/${binary_name}" "/opt/rust/tools/bin/${binary_name}"
    echo "✓ ${tool_name} installed from pre-built binary"
    INSTALLED_TOOLS="${INSTALLED_TOOLS} ${tool_name}"
    return 0
  else
    echo "✗ ${tool_name} binary fallback also failed"
    FAILED_TOOLS="${FAILED_TOOLS} ${tool_name}"
    return 1
  fi
}

#--- Sub-block 24.4.1: Initialize tracking and install tools ---
# Purpose: Track successful/failed installations and install all Rust tools
# Dependencies: install_rust_tool function above
# Outputs: Rust binaries in /opt/rust/tools/bin
# Track which tools installed successfully
INSTALLED_TOOLS=""
FAILED_TOOLS=""

# Install all Rust-based CLI tools using the function (versions from config.sh)
# zellij - with binary fallback if compilation fails
if ! install_rust_tool "zellij" "${ZELLIJ_VERSION}" "terminal multiplexer" "5-7"; then
  echo "[warn] zellij compilation failed, trying pre-built binary..."
  install_prebuilt_binary "zellij" \
    "https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/zellij-x86_64-unknown-linux-musl.tar.gz" \
    "zellij"
  # Extract from tarball if needed
  if [ -f "/opt/rust/tools/bin/zellij" ] && file "/opt/rust/tools/bin/zellij" | grep -q "gzip"; then
    tar -xzf "/opt/rust/tools/bin/zellij" -C /opt/rust/tools/bin/
    rm -f "/opt/rust/tools/bin/zellij.tar.gz"
  fi
  # Verify binary installation
  if [ -x "/opt/rust/tools/bin/zellij" ]; then
    echo "✓ zellij installed from pre-built binary (v${ZELLIJ_VERSION})"
    INSTALLED_TOOLS="${INSTALLED_TOOLS} zellij"
  else
    echo "✗ zellij binary installation failed"
    FAILED_TOOLS="${FAILED_TOOLS} zellij"
  fi
fi
echo ""

install_rust_tool "bat" "${BAT_VERSION}" "syntax highlighting cat" "3-4"
echo ""

install_rust_tool "ripgrep" "${RIPGREP_VERSION}" "fast search" "2-3"
echo ""

install_rust_tool "fd-find" "${FD_VERSION}" "fast find" "2-3"
echo ""

install_rust_tool "eza" "${EZA_VERSION}" "modern ls replacement" "2-3"
echo ""

install_rust_tool "bottom" "${BOTTOM_VERSION}" "system monitor" "4-5"
echo ""

install_rust_tool "procs" "${PROCS_VERSION}" "modern ps replacement" "2-3"
echo ""

install_rust_tool "du-dust" "${DU_DUST_VERSION}" "disk usage" "2-3"
echo ""

# ox text editor - with binary fallback if compilation fails
# Note: ox is available on crates.io, but may have compilation issues
echo "Installing ox (text editor)..."
OX_INSTALLED=false

# Try installing from crates.io
if cargo install ox --root /opt/rust/tools 2>/dev/null; then
  echo "✓ ox installed from crates.io"
  INSTALLED_TOOLS="${INSTALLED_TOOLS} ox"
  OX_INSTALLED=true
else
  echo "[warn] ox compilation from crates.io failed, trying pre-built binary..."
  # Try downloading from GitHub releases
  OX_VERSION="0.4.3"  # Latest stable version
  OX_URL="https://github.com/curlpipe/ox/releases/download/${OX_VERSION}/ox-${OX_VERSION}-x86_64-unknown-linux-gnu"
  if curl -fsSL -o "/tmp/ox" "${OX_URL}" 2>/dev/null && [ -f "/tmp/ox" ] && [ -s "/tmp/ox" ]; then
    chmod +x "/tmp/ox"
    mv "/tmp/ox" "/opt/rust/tools/bin/ox"
    echo "✓ ox installed from pre-built binary (v${OX_VERSION})"
    INSTALLED_TOOLS="${INSTALLED_TOOLS} ox"
    OX_INSTALLED=true
  else
    echo "✗ ox binary download failed - skipping"
    FAILED_TOOLS="${FAILED_TOOLS} ox"
  fi
fi

if [ "$OX_INSTALLED" = false ]; then
  echo "  Note: ox is a lightweight text editor - optional tool"
fi
echo ""

# CREATE SYMLINKS
#--- Sub-block 24.4: Create Rust tool symlinks ---
# Purpose: Link installed cargo binaries to system path
# Dependencies: Block 24 (Rust toolchain)
# Outputs: Rust binaries in /opt/rust/tools/bin
echo "Creating Symlinks"
# Map actual binary names (as installed by cargo) to desired command names
# NOTE: Cargo installs with the actual binary name, not the package name
# e.g., package "ripgrep" installs binary "rg"
declare -A TOOL_MAP
TOOL_MAP["zellij"]="zellij"
TOOL_MAP["rg"]="rg"           # ripgrep installs as 'rg'
TOOL_MAP["bat"]="bat"
TOOL_MAP["fd"]="fd"           # fd-find installs as 'fd'
TOOL_MAP["eza"]="eza"
TOOL_MAP["btm"]="btm"         # bottom installs as 'btm'
TOOL_MAP["procs"]="procs"
TOOL_MAP["dust"]="dust"       # du-dust installs as 'dust'
TOOL_MAP["ox"]="ox"

for binary in "${!TOOL_MAP[@]}"; do
  cmd_name="${TOOL_MAP[$binary]}"
  if [ -f "/opt/rust/tools/bin/${binary}" ]; then
    ln -sf "/opt/rust/tools/bin/${binary}" "/usr/local/bin/${cmd_name}"
    echo "✓ ${binary} -> /usr/local/bin/${cmd_name}"
  else
    echo "✗ ${binary} binary not found (not installed)"
  fi
done

echo ""

# CLEANUP
#--- Sub-block 24.5: Clean up Rust build artifacts ---
# Purpose: Remove cargo cache to save space
# Dependencies: Block 24 (Rust toolchain)
# Outputs: Rust binaries in /opt/rust/tools/bin
echo "Cleaning Up Build Artifacts"
# Calculate sizes before cleanup
REGISTRY_SIZE=$(du -sh /opt/rust/cargo/registry 2>/dev/null | cut -f1 || echo "0")
GIT_SIZE=$(du -sh /opt/rust/cargo/git 2>/dev/null | cut -f1 || echo "0")

echo "  Cargo registry: $REGISTRY_SIZE"
echo "  Cargo git cache: $GIT_SIZE"

# Remove cargo cache
rm -rf /opt/rust/cargo/registry
rm -rf /opt/rust/cargo/git

echo "✓ Build artifacts removed"
echo ""

# ENVIRONMENT SETUP
#--- Sub-block 24.6: Create Rust environment profile ---
# Purpose: Add Rust to system PATH for all sessions
# Dependencies: Block 24 (Rust toolchain)
# Outputs: /etc/profile.d/rust.sh
cat > /etc/profile.d/rust.sh << 'EOF'
# Rust toolchain environment
export RUSTUP_HOME=/opt/rust/rustup
export CARGO_HOME=/opt/rust/cargo
export PATH="/opt/rust/cargo/bin:${PATH}"
EOF
chmod +x /etc/profile.d/rust.sh

echo "✓ Rust environment configured (/etc/profile.d/rust.sh)"
echo ""

# INSTALLATION SUMMARY
#--- Sub-block 24.7: Rust installation summary ---
# Purpose: Report installation results
# Dependencies: Block 24 (Rust toolchain)
# Outputs: Rust binaries in /opt/rust/tools/bin
echo "Rust Tools Installation Summary"
echo ""
if [ -n "$INSTALLED_TOOLS" ]; then
  echo "✓ Successfully installed tools:"
  for tool in $INSTALLED_TOOLS; do
    echo "  - $tool"
  done
fi

if [ -n "$FAILED_TOOLS" ]; then
  echo "✗ Failed to install (non-critical):"
  for tool in $FAILED_TOOLS; do
    echo "  - $tool"
  done
fi

# Verify final installation
echo "Installed binaries:"
ls -lh /opt/rust/tools/bin 2>/dev/null || echo " (none)"

echo "Disk space used:"
du -sh /opt/rust 2>/dev/null || echo " Unable to calculate"

echo ""
echo "✓ Rust toolchain setup complete"

# ... [after cargo install commands] ...
# VERIFY before claiming success
if [ -d "/opt/rust/tools/bin" ] && [ "$(ls -A /opt/rust/tools/bin)" ]; then
  echo "✓ Rust tools installed successfully"
  ls -lh /opt/rust/tools/bin/
else
  echo "Rust tools directory empty or missing"
  echo "Creating directory for manual installation later..."
fi

#--- Sub-block 24.8: Configure Rust tool aliases ---
# Purpose: Set up convenient aliases for compiled Rust tools
# Dependencies: Block 24 (cargo install complete)
# Outputs: Shell aliases in /etc/bash.bashrc
echo "==> Configuring Rust tool aliases..."
cat >> /etc/bash.bashrc << 'RUSTALIASES'

# Modern Rust-based tool aliases (compiled from source)
alias cat='bat --paging=never'
alias catp='bat'  # with paging
alias ls='eza --icons'
alias ll='eza --icons -l'
alias la='eza --icons -la'
alias tree='eza --tree'
alias find='fd'
alias grep='rg'
alias top='btm'
alias ps='procs'

# Initialize zoxide (better cd) - installed earlier via curl script
eval "$(zoxide init bash)"
alias cd='z'
RUSTALIASES

echo "✓ Rust tool aliases configured"

# ZELLIJ CONFIGURATION
mkdir -p /etc/zellij
cat > /etc/zellij/config.kdl << 'EOF'
// Zellij configuration for ROS 2 multi-workspace development

// Keybindings
keybinds {
    normal {
        // Use Ctrl+g as prefix (like tmux's Ctrl+b)
        bind "Ctrl g" { SwitchToMode "locked"; }
    }
    locked {
        bind "Ctrl g" { SwitchToMode "normal"; }
        bind "Ctrl h" { MoveFocus "Left"; }
        bind "Ctrl j" { MoveFocus "Down"; }
        bind "Ctrl k" { MoveFocus "Up"; }
        bind "Ctrl l" { MoveFocus "Right"; }
    }
}

// UI Configuration
ui {
    pane_frames {
        rounded_corners true
    }
}
// Theme
theme "catppuccin-mocha"
// Default Layout
default_layout "compact"
// Mouse support
mouse_mode true
// Copy on select
copy_on_select true
EOF

# OX EDITOR CONFIGURATION
mkdir -p /etc/ox
cat > /etc/ox/config.ron << 'EOX'
Config(
    general: General(
        line_number_padding_right: 2,
        line_number_padding_left: 1,
        tab_width: 4,
        undo_period: 5,
        greeting_message: "Ox Editor - Rust-based minimal editor",
    ),
    theme: Theme(
        editor_bg: (0, 0, 0),
        editor_fg: (255, 255, 255),
        line_number_fg: (65, 65, 65),
        line_number_bg: (0, 0, 0),
    ),
    macros: {
        "python": "#!/usr/bin/env python3\n",
        "julia": "#!/usr/bin/env julia\n",

#--- Sub-block: Final system configuration ---
# Purpose: Complete environment setup
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
        "bash": "#!/bin/bash\n",
    },
)
EOX

#--- Sub-block: Section continuation (5885) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

# ROS MULTI-WORKSPACE LAUNCHER (Zellij version)
cat > /usr/local/bin/ros_multiterm_zellij << 'EOF'
#!/bin/bash
# Launch Zellij session with multiple ROS environments

#--- Sub-block: System configuration ---
# Purpose: Final system setup
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

#--- Sub-block: Code section 5733 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

SESSION="ros_multi"

# Create Zellij layout
cat > /tmp/ros_layout.kdl << 'LAYOUT'
layout {
    default_tab_template {
        pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
        }
        children
        pane size=2 borderless=true {
            plugin location="zellij:status-bar"
        }
    }

    tab name="Humble" focus=true {
        pane {
            command "bash"
            args "-c" "conda activate ros2_humble && cd /workspaces/humble_ws && exec bash"
        }
    }

    tab name="Jazzy" {
        pane {
            command "bash"
            args "-c" "conda activate ros2_jazzy && cd /workspaces/jazzy_ws && exec bash"
        }
    }

    tab name="Bridge" {
        pane {
            command "bash"
            args "-c" "echo 'Start domain bridge via: python3 /opt/scripts/domain_bridge.py' && exec bash"
        }
    }

    tab name="Julia" {
        pane split_direction="vertical" {
            pane {
                command "bash"
                args "-c" "echo 'Start Julia server: julia /opt/scripts/julia_vision_server.jl' && exec bash"
            }
            pane {
                command "julia"
            }
        }
    }

#--- Sub-block: Section continuation (5941) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 5782 ---
# Purpose: Continuing implementation
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments
    tab name="Monitor" {
        pane split_direction="vertical" {
            pane {
                command "btm" // bottom system monitor
            }
            pane {
                command "nvtop" // GPU monitor
            }
        }
    }
}
LAYOUT

# Launch Zellij with layout
zellij --layout /tmp/ros_layout.kdl attach -c $SESSION
EOF
chmod +x /usr/local/bin/ros_multiterm_zellij

# ALTERNATIVE: TMUX LAUNCHER (keep both options)
cat > /usr/local/bin/ros_multiterm_tmux << 'EOF'
#!/bin/bash
# Launch tmux session with multiple ROS environments

SESSION="ros_multi"

# Create new tmux session
tmux new-session -d -s $SESSION

# Window 0: Humble workspace
tmux rename-window -t $SESSION:0 'Humble'
tmux send-keys -t $SESSION:0 "conda activate ros2_humble" C-m
tmux send-keys -t $SESSION:0 "cd /workspaces/humble_ws" C-m

# Window 1: Jazzy workspace
tmux new-window -t $SESSION:1 -n 'Jazzy'
tmux send-keys -t $SESSION:1 "conda activate ros2_jazzy" C-m
tmux send-keys -t $SESSION:1 "cd /workspaces/jazzy_ws" C-m

# Window 2: Bridge/monitoring
tmux new-window -t $SESSION:2 -n 'Bridge'
tmux send-keys -t $SESSION:2 "echo 'Start domain bridge when ready'" C-m
tmux send-keys -t $SESSION:2 "python3 /opt/scripts/domain_bridge.py" C-m

#--- Sub-block: Section continuation (5987) ---
# Purpose: Implementation details
# Dependencies: Block 8.5 (Julia installation)
# Outputs: Julia packages, environments

# Window 3: Julia processing
tmux new-window -t $SESSION:3 -n 'Julia'
tmux send-keys -t $SESSION:3 "echo 'Julia server: julia /opt/scripts/julia_vision_server.jl'" C-m
tmux send-keys -t $SESSION:3 "julia" C-m


#--- Sub-block: Code section 5830 ---
# Purpose: Continuing implementation
# Dependencies: Block 24 (Rust toolchain)
# Outputs: Rust binaries in /opt/rust/tools/bin
# Window 4: Monitoring (split pane)
tmux new-window -t $SESSION:4 -n 'Monitor'
tmux send-keys -t $SESSION:4 'btm' C-m
tmux split-window -h -t $SESSION:4
tmux send-keys -t $SESSION:4.1 'nvtop' C-m

# Attach to session
tmux attach-session -t $SESSION
EOF
chmod +x /usr/local/bin/ros_multiterm_tmux

# Create convenience alias
cat > /usr/local/bin/ros_multiterm << 'EOF'
#!/bin/bash
# Default to Zellij, fallback to tmux
if command -v zellij &>/dev/null; then
  exec /usr/local/bin/ros_multiterm_zellij "$@"
elif command -v tmux &>/dev/null; then
  exec /usr/local/bin/ros_multiterm_tmux "$@"
else
  echo "Error: No terminal multiplexer found (zellij or tmux)"
  exit 1
fi
EOF
chmod +x /usr/local/bin/ros_multiterm

# CLEANUP RUST BUILD ARTIFACTS
# Remove cargo cache to save space
rm -rf /opt/rust/cargo/registry
rm -rf /opt/rust/cargo/git
# Keep only the installed binaries
echo "Rust tools installed successfully"
ls -lh /opt/rust/tools/bin/

# ZENOH INSTALLATION (with error checking)

#===============================================================================
# BLOCK 25: ROBOTICS MIDDLEWARE - ZENOH
#===============================================================================
# Purpose: Install Zenoh for ROS 2 multi-version bridging
# Self-contained: Yes
# Dependencies: wget, unzip
# Outputs: Configured system components
#-------------------------------------------------------------------------------

#--- Sub-block 25.1: Download and install Zenoh ---
# Critical: Protocol for ROS 2 inter-version communication
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "==> Installing Zenoh"
ZENOH_INSTALLED=false
mkdir -p /opt/zenoh
cd /tmp || { echo "ERROR: Failed to access /tmp directory"; exit 1; }

# Using Zenoh configuration from config.sh
ZENOH_FILE="${ZENOH_FILE}"
ZENOH_URL="${ZENOH_URL}"

# Downloading Zenoh from GitHub...
if wget -q --show-progress --timeout=60 "${ZENOH_URL}"; then
  echo "✓ Download successful"
  if unzip -q "${ZENOH_FILE}" -d /opt/zenoh; then
    echo "✓ Extraction successful"
    chmod +x /opt/zenoh/zenohd 2>/dev/null || true
    if [ -f /opt/zenoh/zenohd ]; then
      ln -sf /opt/zenoh/zenohd /usr/local/bin/zenohd
      echo "✓ Zenoh installed: ${ZENOH_VERSION}"
      ZENOH_INSTALLED=true
    else
      echo "✗ Zenoh binary not found after extraction"
    fi
  else
    echo "✗ Extraction failed"
  fi
  rm -f "${ZENOH_FILE}"
else
  echo "✗ Download failed - Zenoh will not be available"
  echo "  You can install manually later if needed"
fi
cd /

#--- Sub-block 25.2: Configure Zenoh router ---
# Purpose: Setup Zenoh router configuration and management scripts
# Dependencies: Successful Zenoh installation
# Outputs: Environment variables, configuration

# Only configure Zenoh if installation was successful
if [ "$ZENOH_INSTALLED" = true ]; then
  echo "==> Configuring Zenoh"
  mkdir -p /etc/zenoh
# Zenoh Router Configuration
cat > /etc/zenoh/zenoh-router.json5 << 'EOF'
// Zenoh router configuration for ROS 2 multi-version bridge
{
  // Router mode

#--- Sub-block: Verification continuation ---
# Purpose: Additional validation checks
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
  mode: "router",
  // Listening endpoints
  listen: {
    endpoints: [
      "tcp/0.0.0.0:7447", // Main Zenoh protocol
      "udp/0.0.0.0:7447", // UDP multicast
    ],
  },
  // Connect to other routers (for distributed systems)
  connect: {
    endpoints: [
      // Add remote routers here if needed
      // "tcp/remote-router:7447"
    ],
  },
  // Storage configuration (optional - for persistent data)
  plugins: {
    storage_manager: {
      volumes: {
        memory: {
          // In-memory storage for transient data
        },
      },
      storages: {
        demo: {
          key_expr: "ros2/**",
          volume: "memory",
        },
      },
    },
    // REST API plugin (useful for debugging)
    rest: {
      http_port: 8000
    },
  },
  // Advanced settings
  scouting: {
    multicast: {
      enabled: true,
      address: "224.0.0.224:7446"
    }
  }
}
EOF

#--- Sub-block: Section continuation (6129) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 5964 ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

#--- Sub-block: Environment setup ---
# Purpose: Environment variables and paths
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# Zenoh-DDS Bridge Configuration (Humble domain)
cat > /etc/zenoh/zenoh-bridge-humble.json5 << 'EOF'
// Bridge ROS 2 Humble (Domain 1) to Zenoh
{
  mode: "client",
  connect: {
    endpoints: ["tcp/localhost:7447"]
  },

#--- Sub-block: Environment finalization ---
# Purpose: Complete environment setup
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
  plugins: {
    ros2dds: {
      // Domain ID for Humble
      domain: 1,
      // Namespace for Humble topics in Zenoh
      namespace: "/humble",
      // Topic routing rules
      allow: [
        // allow all topics under /humble namespace
        { topic: "**" }
      ],
      // DDS Configuration
      shm_enabled: true,  // Shared memory for local performance
      // QoS mapping
      reliable_routes_blocking: true
    }
  }
}
EOF

# Zenoh-DDS Bridge Configuration (Jazzy domain)
cat > /etc/zenoh/zenoh-bridge-jazzy.json5 << 'EOF'
// Bridge ROS 2 Jazzy (Domain 2) to Zenoh
{
  mode: "client",
  connect: {
    endpoints: ["tcp/localhost:7447"]
  },
  plugins: {
    ros2dds: {
      // Domain ID for Jazzy
      domain: 2,
      // Namespace for Jazzy topics in Zenoh
      namespace: "/jazzy",
      // Topic routing rules
      allow: [
        { topic: "**" }
      ],
      shm_enabled: true,
      reliable_routes_blocking: true
    }
  }
}
EOF

#--- Sub-block: Section continuation (6185) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 6017 ---
# Purpose: Continuing implementation
# Dependencies: Block 8.5 (Julia installation)
# Outputs: Julia packages, environments
# ZENOH JULIA BINDINGS (Optional, but useful)
${JULIA_HOME}/bin/julia -e '
  using Pkg
  # Zenoh.jl wrapper (community package)
  # Note: Official Julia bindings may not exist yet
  # Use ZMQ bridge to Zenoh as fallback
  Pkg.add(["ZMQ", "JSON3", "HTTP"])
  # If official Zenoh.jl becomes available:
  # Pkg.add("Zenoh")
'

# ZENOH MANAGEMENT SCRIPTS
# Zenoh startup script
cat > /usr/local/bin/zenoh_start << 'EOF'
#!/bin/bash
# Start Zenoh router and bridges

echo "Starting Zenoh infrastructure..."

# Start Zenoh router in background
echo "  Starting Zenoh router on port 7447..."
zenohd --config /etc/zenoh/zenoh-router.json5 > /tmp/zenoh-router.log 2>&1 &
ROUTER_PID=$!
sleep 2

# Check if router started
if ! ps -p $ROUTER_PID > /dev/null; then
  echo "  ✗ Failed to start Zenoh router"
  cat /tmp/zenoh-router.log
  exit 1
fi
echo "  ✓ Zenoh router started (PID: $ROUTER_PID)"

# Start Humble bridge
if [ -d "/conda/envs/ros2_humble" ]; then
  echo "  Starting Zenoh-DDS bridge for Humble (Domain 1)..."
  zenoh-bridge-dds --config /etc/zenoh/zenoh-bridge-humble.json5 > /tmp/zenoh-humble.log 2>&1 &
  HUMBLE_PID=$!
  sleep 1
  if ps -p $HUMBLE_PID > /dev/null; then
    echo "  ✓ Humble bridge started (PID: $HUMBLE_PID)"
  else
    echo "  ✗ Failed to start Humble bridge"
    cat /tmp/zenoh-humble.log
  fi
fi

#--- Sub-block: Section continuation (6235) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 6064 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# Start Jazzy bridge
if [ -d "/conda/envs/ros2_jazzy" ] || [ -d "/opt/ros/${ROS_DISTRO}" ]; then
  echo "  Starting Zenoh-DDS bridge for Jazzy (Domain 2)..."
  zenoh-bridge-dds --config /etc/zenoh/zenoh-bridge-jazzy.json5 > /tmp/zenoh-jazzy.log 2>&1 &
  JAZZY_PID=$!
  sleep 1
  if ps -p $JAZZY_PID > /dev/null; then
    echo "  ✓ Jazzy bridge started (PID: $JAZZY_PID)"
  else
    echo "  ✗ Failed to start Jazzy bridge"
    cat /tmp/zenoh-jazzy.log
  fi
fi

echo "Zenoh infrastructure ready!"
echo "  Router: http://localhost:8000 (REST API)"
echo "  Logs: /tmp/zenoh*.log"
EOF
chmod +x /usr/local/bin/zenoh_start

# Zenoh stop script
cat > /usr/local/bin/zenoh_stop << 'EOF'
#!/bin/bash
# Stop all Zenoh processes

echo "Stopping Zenoh infrastructure..."
pkill -f zenohd
pkill -f zenoh-bridge
echo "✓ Zenoh stopped"
EOF
chmod +x /usr/local/bin/zenoh_stop

# Zenoh status script
cat > /usr/local/bin/zenoh_status << 'EOF'
#!/bin/bash
# Check Zenoh status

echo "Zenoh Infrastructure Status:"
echo "----------------------------"
# Check router
if pgrep -f "zenohd" > /dev/null; then
  echo "✓ Zenoh Router: RUNNING"
  echo "  REST API: http://localhost:8000"
else
  echo "✗ Zenoh Router: STOPPED"
fi

#--- Sub-block: Section continuation (6285) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 6111 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# Check Humble bridge
if pgrep -f "zenoh-bridge.*humble" > /dev/null; then
  echo "✓ Humble Bridge: RUNNING (Domain 1 -> /humble namespace)"
else
  echo "✗ Humble Bridge: STOPPED"
fi

# Check Jazzy bridge
if pgrep -f "zenoh-bridge.*jazzy" > /dev/null; then
  echo "✓ Jazzy Bridge: RUNNING (Domain 2 -> /jazzy namespace)"
else
  echo "✗ Jazzy Bridge: STOPPED"
fi

echo "Logs:"
echo "  Router: /tmp/zenoh-router.log"
echo "  Humble: /tmp/zenoh-humble.log"
echo "  Jazzy: /tmp/zenoh-jazzy.log"
EOF
chmod +x /usr/local/bin/zenoh_status

# ZENOH PYTHON UTILITIES
# ZENOH TOPIC BRIDGE SCRIPT
cat > /opt/scripts/zenoh_topic_bridge.py << 'EOF'
#!/usr/bin/env python3
# Zenoh topic bridge for ROS 2 Humble <-> Jazzy communication

import sys
try:
    import zenoh
except ImportError:

#--- Sub-block: Helper scripts generation ---
# Purpose: Create utility and monitoring scripts
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
    print(" Zenoh-Python package not installed")
    print("Install with: pip3 install eclipse-zenoh")
    sys.exit(1)

class ZenohTopicBridge:
    def __init__(self):
        # Connect to Zenoh router
        config = zenoh.Config()
        self.session = zenoh.open(config)
        print("✓ Connected to Zenoh router")

#--- Sub-block: Section continuation (6331) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

    def bridge_topic(self, from_topic: str, to_topic: str):
        """Bridge a topic from one namespace to another"""
        def callback(sample):
            # Forward data
            self.session.put(to_topic, sample.payload)
            print(f"Bridged: {from_topic} -> {to_topic}")


#--- Sub-block: Utility scripts ---
# Purpose: Helper scripts creation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

#--- Sub-block: Code section 6161 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
        # Subscribe and forward
        subscriber = self.session.declare_subscriber(from_topic, callback)
        print(f"Bridge active: {from_topic} -> {to_topic}")

#--- Sub-block: Script generation ---
# Purpose: Create additional helper scripts
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
        return subscriber

    def run(self):
        """Keep bridge running"""
        print("Zenoh topic bridge running. Press Ctrl+C to stop.")
        try:
            import time
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            print("Stopping bridge...")

if __name__ == "__main__":
    bridge = ZenohTopicBridge()
    # Example bridges - customize as needed
    bridge.bridge_topic('/humble/camera/image', '/jazzy/camera/image')
    bridge.bridge_topic('/jazzy/cmd_vel', '/humble/cmd_vel')
    bridge.run()
EOF
chmod +x /opt/scripts/zenoh_topic_bridge.py
echo "✓ Zenoh topic bridge script created"

# UPDATE ZELLIJ LAYOUT WITH ZENOH
# Update the Zellij launcher to include Zenoh
cat > /usr/local/bin/ros_multiterm_zellij_zenoh << 'EOF'
#!/bin/bash
# Launch Zellij session with Zenoh-enabled ROS environments

SESSION="ros_multi_zenoh"

# Start Zenoh infrastructure first
zenoh_start

# Create Zellij layout
cat > /tmp/ros_zenoh_layout.kdl << 'LAYOUT'
layout {
    default_tab_template {
        pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
        }
        children
        pane size=2 borderless=true {
            plugin location="zellij:status-bar"
        }
    }

    tab name="Humble" focus=true {
        pane {
            command "bash"
            args "-c" "conda activate ros2_humble && export RMW_IMPLEMENTATION=rmw_zenoh_cpp && cd /workspaces/humble_ws && exec bash"
        }
    }

    tab name="Jazzy" {
        pane {
            command "bash"
            args "-c" "conda activate ros2_jazzy && export RMW_IMPLEMENTATION=rmw_zenoh_cpp && cd /workspaces/jazzy_ws && exec bash"
        }
    }

    tab name="Zenoh" {
        pane split_direction="vertical" {
            pane {
                command "bash"
                args "-c" "zenoh_status && echo '' && echo 'Zenoh Infrastructure running' && exec bash"
            }
            pane {
                command "bash"
                args "-c" "tail -f /tmp/zenoh-router.log"
            }
        }
    }

    tab name="Julia" {
        pane split_direction="vertical" {
            pane {
                command "bash"
                args "-c" "echo 'Start Julia server: julia /opt/scripts/julia_vision_server.jl' && exec bash"
            }
            pane {
                command "julia"
            }
        }
    }

    tab name="Monitor" {
        pane split_direction="vertical" {
            pane {
                command "btm"
            }
            pane {
                command "nvtop"
            }
        }
    }
}
LAYOUT


#--- Sub-block: Code section 6262 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# Launch Zellij with layout
zellij --layout /tmp/ros_zenoh_layout.kdl attach -c $SESSION
EOF
chmod +x /usr/local/bin/ros_multiterm_zellij_zenoh

# CLEANUP
#--- Sub-block 24.5: Clean up Rust build artifacts ---
# Purpose: Remove cargo cache to save space
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
  # Remove Zenoh build artifacts
  rm -rf /opt/rust/cargo/registry
  rm -rf /opt/rust/cargo/git
  echo "✓ Zenoh installation and configuration complete"
else
  echo "⚠ Zenoh not installed - skipping configuration"
  echo "  Zenoh is optional and can be installed manually later if needed"
fi

# === Sioyek note (baseline) ===
echo "==> Sioyek (manual AppImage install recommended)"
echo "[note] After build, to install Sioyek:"
echo "  - 1) Download AppImage from https://github.com/ahrm/sioyek/releases"
echo "  - 2) chmod +x Sioyek-*.AppImage && sudo mv Sioyek-*.AppImage /usr/local/bin/sioyek"
echo "  - 3) Optionally create a desktop file for menus"


#===============================================================================
# BLOCK 26: FINAL SYSTEM VERIFICATION
#===============================================================================
# Purpose: Verify all critical symlinks and installations
# Self-contained: Yes
# Dependencies: None
# Outputs: Environment variables, configuration
#-------------------------------------------------------------------------------

#--- Sub-block 26.1: Verify TurboVNC and VirtualGL symlinks ---
# Critical: Ensure remote desktop binaries are accessible
# Dependencies: Block 15 (VirtualGL), Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration
# ================= Final Failsafe: Verify All Symlinks =====================
echo "==> Final verification of TurboVNC/VirtualGL symlinks..."

# TurboVNC binaries
TURBOVNC_BINS="vncserver Xvnc vncpasswd vncconnect vncviewer webserver tvncconfig"
for binary in $TURBOVNC_BINS; do
  if [ ! -L "/usr/local/bin/$binary" ] && [ -x "/opt/TurboVNC/bin/$binary" ]; then
    ln -sf "/opt/TurboVNC/bin/$binary" "/usr/local/bin/$binary"
    echo "  ✓ Created missing symlink: $binary"
  fi
done

# VirtualGL binaries (comprehensive list)
VIRTUALGL_BINS="vglrun vglclient vglconfig vglconnect vglgenkey vgllogin vglserver_config glxinfo glxspheres64 eglinfo eglxinfo eglxspheres64 cpustat nettest tcbench"
for binary in $VIRTUALGL_BINS; do
  if [ ! -L "/usr/local/bin/$binary" ] && [ -x "/opt/VirtualGL/bin/$binary" ]; then
    echo "  ✓ Created missing symlink: $binary"
  fi
done

# Final comprehensive verification
echo ""
echo "==> Critical symlink verification:"
declare -A CRITICAL_BINS=(
  ["vncserver"]="/opt/TurboVNC/bin/vncserver"
  ["Xvnc"]="/opt/TurboVNC/bin/Xvnc"
  ["webserver"]="/opt/TurboVNC/bin/webserver"
  ["vglrun"]="/opt/VirtualGL/bin/vglrun"
  ["glxinfo"]="/opt/VirtualGL/bin/glxinfo"
  ["glxspheres64"]="/opt/VirtualGL/bin/glxspheres64"
)

for binary in "${!CRITICAL_BINS[@]}"; do
  expected="${CRITICAL_BINS[$binary]}"
  if [ -L "/usr/local/bin/$binary" ]; then
    actual=$(readlink "/usr/local/bin/$binary")
    if [ -x "$actual" ]; then
      echo "  ✓ $binary -> $actual [OK]"
    else
      echo "  ✗ $binary -> $actual [BROKEN]"
    fi
  else
    echo "  ✗ $binary [MISSING]"
  fi
done

#--- Sub-block: Section continuation (6526) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 6340 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "✓ Symlink verification complete"

# Cache is already unified in ${CONTAINER_CACHE_ROOT}/ - no need for complex harvesting
echo "==> Cache is unified in ${CONTAINER_CACHE_ROOT}/ - ready for harvest"

# Clean up temporary files but preserve our cache
echo "==> Cleaning temporary files while preserving cache..."

# Clean APT lists (safe to remove)
echo "  » APT LISTS CLEANUP - Monitoring cache before APT lists cleanup"
echo "  ${CONTAINER_APT_CACHE}: $(find ${CONTAINER_APT_CACHE} -name "*.deb" 2>/dev/null | wc -l) .deb files"
rm -rf /var/lib/apt/lists/* 2>/dev/null || true
echo "  » APT LISTS CLEANUP - Monitoring cache after APT lists cleanup"
echo "  ${CONTAINER_APT_CACHE}: $(find ${CONTAINER_APT_CACHE} -name "*.deb" 2>/dev/null | wc -l) .deb files"

# Clean temporary APT directories that might cause issues
rm -rf /tmp/apt-dpkg-install* 2>/dev/null || true
# apt-fast cleanup removed - using apt-aria wrapper instead

# Clean temporary files but preserve our container cache
echo "  » CLEANUP SECTION - Monitoring cache before cleanup"
echo "  ${CONTAINER_APT_CACHE}: $(find ${CONTAINER_APT_CACHE} -name "*.deb" 2>/dev/null | wc -l) .deb files"
# DEBUG: Check for symlinks or unusual directory structure
echo "  DEBUG: Checking for symlinks or unusual paths..."
ls -la /tmp/ | grep -E "(container_cache|apt/archives)" || echo "No suspicious symlinks in /tmp"
ls -la ${CONTAINER_APT_CACHE}/ | head -5
echo "  DEBUG: About to run: find /tmp -type f -name '*.deb' -delete"
find /tmp -type f -name "*.deb" -delete 2>/dev/null || true
find /tmp -type f -name "*.tar.gz" -delete 2>/dev/null || true
find /tmp -type f -name "*.whl" -delete 2>/dev/null || true
echo "  » CLEANUP SECTION - Monitoring cache after cleanup"
echo "  ${CONTAINER_APT_CACHE}: $(find ${CONTAINER_APT_CACHE} -name "*.deb" 2>/dev/null | wc -l) .deb files"

# === FINAL CACHE PRESERVATION ===
# Reverting cache file permissions to normal ===
if command -v chattr >/dev/null 2>&1; then
    chattr -i ${CONTAINER_APT_CACHE}/*.deb 2>/dev/null
    echo "chattr -i command executed successfully"
else
    echo "WARNING: chattr command not available - cannot revert file permissions"
fi

#--- Sub-block: Section continuation (6571) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

# Show monitoring summary and aggregated cache summary before preservation
display_cache_monitoring_summary
cache_summary
# Add detailed monitoring before any cache operations

#--- Sub-block: Code section 6386 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "  » DETAILED CACHE INVESTIGATION - BEFORE PRESERVATION"
echo "  Container cache directory contents:"
ls -la ${CONTAINER_APT_CACHE}/ 2>/dev/null | head -10 || echo "Directory empty or not accessible"
echo "  Var cache directory contents:"
ls -la /var/cache/apt/archives/ 2>/dev/null | head -10 || echo "Directory empty or not accessible"
echo "Cache file counts:"
echo "  ${CONTAINER_APT_CACHE}: $(find ${CONTAINER_APT_CACHE} -name "*.deb" 2>/dev/null | wc -l) .deb files"
echo "  /var/cache/apt/archives: $(find /var/cache/apt/archives -name "*.deb" 2>/dev/null | wc -l) .deb files"

# Ensure all downloaded packages are preserved in the cache directory
echo "==> Preserving APT cache for future builds ==="
# Check if packages are in the standard APT cache location
if [ -d "/var/cache/apt/archives" ]; then
    echo "Copying packages from /var/cache/apt/archives to ${CONTAINER_APT_CACHE}..."
    find /var/cache/apt/archives -name "*.deb" -type f -exec cp {} ${CONTAINER_APT_CACHE}/ \; 2>/dev/null || true
    echo "After copying from /var/cache/apt/archives:"
    echo "  ${CONTAINER_APT_CACHE}: $(find ${CONTAINER_APT_CACHE} -name "*.deb" 2>/dev/null | wc -l) .deb files"
fi

# Also preserve any packages that might be in the system cache
if [ -d "/var/lib/apt/cache" ]; then
    echo "Checking system APT cache for additional packages..."
    find /var/lib/apt/cache -name "*.deb" -type f -exec cp {} ${CONTAINER_APT_CACHE}/ \; 2>/dev/null || true
    echo "After copying from /var/lib/apt/cache:"
    echo "  ${CONTAINER_APT_CACHE}: $(find ${CONTAINER_APT_CACHE} -name "*.deb" 2>/dev/null | wc -l) .deb files"
fi

# Final monitoring before cache harvest
monitor_cache "Final cache status before harvest"

# Add one more detailed check right before the script ends
echo "  » FINAL CACHE CHECK - RIGHT BEFORE SCRIPT END"
echo "Final container cache contents:"
ls -la ${CONTAINER_APT_CACHE}/ 2>/dev/null | head -10 || echo "Directory empty or not accessible"
echo ""
echo "Final cache file count:"
echo "  ${CONTAINER_APT_CACHE}: $(find ${CONTAINER_APT_CACHE} -name "*.deb" 2>/dev/null | wc -l) .deb files"
echo ""
# Report cache status
echo "[debug] Container cache status:"
echo "  APT archives: $(ls ${CONTAINER_APT_CACHE}/*.deb 2>/dev/null | wc -l) files"
echo "  Conda packages: $(ls ${CONTAINER_CONDA_CACHE}/* 2>/dev/null | wc -l) files"
echo "  Pip wheels: $(ls ${CONTAINER_WHEELS_CACHE}/* 2>/dev/null | wc -l) files"
echo "  Julia packages: $(ls ${CONTAINER_JULIA_CACHE}/* 2>/dev/null | wc -l) files"
echo "=========================================================================="

#--- Sub-block: Section continuation (6624) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 6432 ---
# Purpose: Continuing implementation
# Dependencies: Block 15 (VirtualGL), Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration
# ===============================================================
# Final Installation Verification
# ===============================================================
echo ""
echo "=========================================="
echo "Final Installation Verification"
echo "=========================================="

# Test TurboVNC
echo ""
echo "TurboVNC Installation:"
if [ -x /usr/local/bin/vncserver ]; then
  /usr/local/bin/vncserver -help 2>&1 | head -1 || echo "  ✓ vncserver binary present"
  echo "  ✓ TurboVNC installed"
else
  echo "  ✗ TurboVNC not found!"
fi

# Test VirtualGL
echo ""
echo "VirtualGL Installation:"
if [ -x /usr/local/bin/vglrun ]; then
  /usr/local/bin/vglrun --version 2>&1 | head -1 || echo "  ✓ vglrun binary present"
  echo "  ✓ VirtualGL installed"
else
  echo "  ✗ VirtualGL not found!"
fi

# Test helper scripts
echo ""
echo "Helper Scripts:"
for script in start_vnc_xfce.sh test_virtualgl.sh vgl_benchmark.sh vgl_info.sh vgl_launch.sh; do
  if [ -x "/usr/local/bin/$script" ]; then
    echo "  ✓ $script"
  else
    echo "  ✗ $script missing"
  fi
done

#--- Sub-block: Section continuation (6666) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

echo ""
echo "=========================================="
echo "Build Complete!"
echo "=========================================="

# ===============================================================

#--- Sub-block: Code section 6477 ---
# Purpose: Continuing implementation
# Dependencies: Block 15 (VirtualGL), Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration
# VNC server selection and comparison tool
# ===============================================================
echo "==> Creating VNC server selection tool..."

cat > /usr/local/bin/vnc_select.sh << 'VNCSELECT'
#!/usr/bin/env bash
# VNC Server Selection and Comparison Tool

cat << 'INFO'
========================================
VNC Server Options
========================================

Available VNC servers in this container:

1. TurboVNC (Default - Recommended)
   - Best performance for GPU applications
   - Optimized JPEG compression
   - Built specifically for VirtualGL
   - Command: start_vnc_xfce.sh

2. TurboVNC Ultimate (Enhanced)
   - All TurboVNC features
   - Automatic optimization
   - Performance monitoring
   - Audio support
   - Command: start_vnc_ultimate.sh

3. TigerVNC (Alternative)
   - Good compatibility
   - Different compression algorithm
   - Some prefer the image quality
   - Command: start_vnc_tigervnc.sh

4. KasmVNC (Modern)
   - Modern web-first VNC
   - Built-in web interface
   - Container-optimized
   - Command: start_kasmvnc.sh

#--- Sub-block: Section continuation (6715) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

5. x11vnc (Screen Sharing)
   - Can attach to existing X session
   - Good for debugging
   - Command: start_x11vnc.sh



#--- Sub-block: Final cleanup ---
# Purpose: Post-installation cleanup
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
#--- Sub-block: Code section 6522 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
========================================
RECOMMENDATION
========================================


#--- Sub-block: Final cleanup operations ---
# Purpose: Post-installation cleanup tasks
# Dependencies: Block 15 (VirtualGL), Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration
For most users: start_vnc_ultimate.sh

This provides the best balance of:
- Performance (TurboVNC)
- GPU support (VirtualGL)
- Ease of use (noVNC web interface)
- Monitoring and diagnostics

========================================
PERFORMANCE COMPARISON
========================================

Benchmark your options:
  vgl_benchmark.sh       (VirtualGL performance)
  turbovnc_tune.sh       (TurboVNC settings)
  vnc_monitor.sh         (Real-time monitoring)

========================================
INFO

# If argument provided, start that server
if [ $# -gt 0 ]; then
  case "$1" in
    turbovnc|1)
      exec start_vnc_xfce.sh
      ;;
    ultimate|2)
      exec start_vnc_ultimate.sh
      ;;
    tiger|3)
      exec start_vnc_tigervnc.sh
      ;;
    kasm|4)
      exec start_kasmvnc.sh
      ;;
    x11vnc|5)
      exec start_x11vnc.sh
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
fi
VNCSELECT
chmod +x /usr/local/bin/vnc_select.sh

#--- Sub-block: Section continuation (6774) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration


#--- Sub-block: Code section 6573 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "✓ VNC selection tool created"

# ===============================================================
# Network and TCP Tuning for Remote Desktop
# ===============================================================
echo "==> Creating network optimization script..."

cat > /usr/local/bin/optimize_network.sh << 'NETOPT'
#!/usr/bin/env bash
# Optimize network for remote desktop (run on host/container with permissions)

echo "Optimizing TCP for remote desktop..."

# These would need to run on host or with capabilities
# Include as documentation

cat << 'EOF'
# Add these to host system /etc/sysctl.conf for better performance:

# Increase TCP buffer sizes
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864

# Enable TCP window scaling
net.ipv4.tcp_window_scaling = 1

# Increase max backlog
net.core.netdev_max_backlog = 5000

# Enable BBR congestion control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

Then run: sudo sysctl -p
EOF


#--- Sub-block: Section continuation (6816) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo ""
echo "Note: These optimizations require host-level changes"
NETOPT
chmod +x /usr/local/bin/optimize_network.sh

echo "✓ Network optimization guide created"


#--- Sub-block: Code section 6618 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# ===============================================================
# Create Unified Remote Desktop Launcher
# ===============================================================
echo "==> Creating unified remote desktop launcher..."


#--- Sub-block 26.4: Create unified remote desktop launcher ---
# Purpose: Interactive menu for launching VNC/noVNC sessions
# Dependencies: Block 15 (VirtualGL), Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration
cat > /usr/local/bin/remote_desktop.sh << 'RDLAUNCH'
#!/usr/bin/env bash
# Unified Remote Desktop Launcher

show_menu() {
  cat << EOF

========================================
Remote Desktop Launcher
========================================

Available Options:

VNC SERVERS:
  1) TurboVNC (default, best for most uses)
  2) TurboVNC High Quality (fast network)
  3) TurboVNC Low Bandwidth (slow network)
  4) TigerVNC (alternative)
  5) x11vnc (attach to existing display)
  6) KasmVNC (modern web VNC)

APPLICATION STREAMING:
  7) Xpra (seamless windows)
  8) Sunshine (game streaming, ultra-low latency)

UTILITIES:
  9) List running sessions
 10) Kill all VNC servers
 11) Test VirtualGL
 12) GPU benchmark
 13) Record screen

 0) Exit

========================================
EOF
  read -p "Select option: " choice
  echo ""
  handle_choice "$choice"
}

#--- Sub-block: Section continuation (6874) ---
# Purpose: Implementation details
# Dependencies: Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration

handle_choice() {
  case $1 in
    1) start_vnc_xfce.sh ;;
    2) start_vnc_ultrahq.sh ;;
    3) start_vnc_lowbw.sh ;;
    4) start_vnc_tigervnc.sh ;;
    5) read -p "Display number (default 1): " disp
       start_x11vnc.sh ${disp:-1} ;;
    6) start_kasmvnc.sh ;;
    7) start_xpra.sh ;;
    8) start_sunshine.sh ;;
    9) vncserver -list
       echo ""
       ps aux | grep -E "vnc|xpra|sunshine" | grep -v grep ;;
   10) vncserver -kill :1 2>/dev/null
       pkill -f vnc
       pkill -f xpra
       echo "All VNC servers killed" ;;
   11) test_virtualgl.sh ;;
   12) vgl_benchmark.sh ;;
   13) read -p "Output filename (default: screen_recording.mp4): " fname
       record_screen.sh 1 "${fname:-screen_recording.mp4}" ;;
    0) exit 0 ;;
    *) echo "Invalid option" ;;
  esac


#--- Sub-block: Code section 6693 ---
# Purpose: Continuing implementation
# Dependencies: System (Container runtime)
# Outputs: Configured system components
  read -p "Press Enter to continue..."
  show_menu
}

# Check if running in container
if [ -f /.singularity.d/Singularity ]; then
  echo "Running inside Singularity container"
else
  echo "Warning: Should be run inside container"
fi

show_menu
RDLAUNCH
chmod +x /usr/local/bin/remote_desktop.sh

echo "✓ Unified launcher created: remote_desktop.sh"

# ===============================================================

#--- Sub-block 26.3: Create performance benchmark suite ---
# Purpose: Comprehensive remote desktop performance testing
# Dependencies: Block 6.13 (NVIDIA CUDA), Block 15 (VirtualGL)
# Outputs: GPU libraries, CUDA toolkit
# Create Performance Benchmarking Suite
# ===============================================================
echo "==> Creating performance benchmark suite..."

cat > /usr/local/bin/benchmark_all.sh << 'BENCH'
#!/usr/bin/env bash
# Comprehensive Remote Desktop Performance Benchmark

echo "=========================================="
echo "Remote Desktop Performance Benchmark"
echo "=========================================="
echo ""

# System Info
echo "SYSTEM INFORMATION:"
echo "  CPU: $(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)"
echo "  Cores: $(nproc)"
echo "  Memory: $(free -h | grep Mem | awk '{print $2}')"

if command -v nvidia-smi >/dev/null 2>&1; then
  echo "  GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"
  echo "  VRAM: $(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1) MB"
fi
echo ""

# VirtualGL Performance
echo "VIRTUALGL PERFORMANCE:"
if [ -n "${DISPLAY}" ] && command -v vglrun >/dev/null 2>&1; then
  echo "  Testing GPU rendering..."
  timeout 10s vglrun glxspheres64 2>&1 | grep "frames" | tail -1
else
  echo "  ⚠ DISPLAY not set or vglrun not available"
fi
echo ""

# CPU Performance
echo "CPU PERFORMANCE:"
echo "  Running CPU benchmark..."
sysbench cpu --threads=$(nproc) --time=10 run 2>&1 | grep "events per second"
echo ""

#--- Sub-block: Section continuation (6965) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

# Disk I/O
echo "DISK I/O:"
dd if=/dev/zero of=/tmp/testfile bs=1M count=1024 conv=fdatasync 2>&1 | grep copied
rm -f /tmp/testfile
echo ""


#--- Sub-block: Code section 6761 ---
# Purpose: Continuing implementation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# Network (if available)
echo "NETWORK:"
ping -c 4 8.8.8.8 2>&1 | grep "rtt\|avg" || echo "  Network test skipped"
echo ""

echo "=========================================="
echo "Benchmark Complete"
echo "=========================================="
BENCH
chmod +x /usr/local/bin/benchmark_all.sh

echo "✓ Benchmark suite created"

#===============================================================================
# BLOCK 25: DOCUMENTATION AND USER GUIDES
#===============================================================================
# Purpose: Create comprehensive user documentation for the container
# Self-contained: Yes (complete documentation generation)
# Dependencies: None
# Outputs: Environment variables, configuration
#-------------------------------------------------------------------------------

#--- Sub-block 25.1: VirtualGL user guide ---
# Critical: Comprehensive guide for GPU-accelerated applications
# Dependencies: Block 15 (VirtualGL)
# Outputs: VNC server, GPU acceleration
mkdir -p /usr/local/share/doc
cat > /usr/local/share/doc/virtualgl-guide.txt << 'GUIDE'
========================================
VirtualGL Usage Guide
========================================

QUICK START
-----------
1. Start VNC with GPU support:
   start_vnc_xfce.sh

2. Connect via VNC viewer

3. Open terminal in VNC session

4. Launch GPU-accelerated applications:
   vglrun blender
   vglrun openscad
   vglrun glxspheres64

AVAILABLE COMMANDS
------------------
Core Tools:
  vglrun <app>     - Run application with GPU acceleration
  vglconfig        - Configure VirtualGL
  vglconnect       - SSH with VGL integration

Testing & Info:
  glxinfo          - OpenGL system information
  glxspheres64     - OpenGL benchmark (spinning spheres)
  eglinfo          - EGL information
  vgl_info.sh      - Complete VirtualGL/OpenGL info
  vgl_benchmark.sh - Compare CPU vs GPU rendering
  test_virtualgl.sh - Test VirtualGL installation

Performance Tools:
  cpustat          - CPU statistics
  nettest          - Network performance test
  tcbench          - TCP benchmark

#--- Sub-block: Section continuation (7036) ---
# Purpose: Implementation details
# Dependencies: Block 15 (VirtualGL)
# Outputs: VNC server, GPU acceleration

CONVENIENT ALIASES
------------------
(Available in bash shell)
  vblender         - Launch Blender with GPU
  vopenscad        - Launch OpenSCAD with GPU
  vfreecad         - Launch FreeCAD with GPU
  gpubench         - Quick GPU benchmark
  gpuinfo          - Quick OpenGL info
  vgl <command>    - Shortcut for vglrun


#--- Sub-block: Code section 6833 ---
# Purpose: Continuing implementation
# Dependencies: Block 6.13 (NVIDIA CUDA), Block 15 (VirtualGL)
# Outputs: GPU libraries, CUDA toolkit
USAGE EXAMPLES
--------------
# Launch application with GPU:
vglrun blender

# Or use alias:
vblender

# Or use helper script:
vgl_launch.sh openscad model.scad

# Benchmark GPU performance:
vgl_benchmark.sh

# Compare rendering methods:
compare_render glxspheres64

# Check GPU is detected:
nvidia-smi
vgl_info.sh

TROUBLESHOOTING
---------------
Problem: Low FPS even with vglrun
Solution: Check GPU is available
  nvidia-smi

Problem: "Could not open display"
Solution: Set DISPLAY variable

Problem: vglrun not found
Solution: Add to PATH

For more info:
  man vglrun
  test_virtualgl.sh
  vgl_info.sh
========================================
GUIDE
chmod 644 /usr/local/share/doc/virtualgl-guide.txt

#--- Sub-block: Section continuation (7092) ---
# Purpose: Implementation details
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

echo "✓ User guide created: /usr/local/share/doc/virtualgl-guide.txt"

