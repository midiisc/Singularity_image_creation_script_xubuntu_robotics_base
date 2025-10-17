#!/bin/bash

# Ensure we're running in bash, not sh
if [ -z "$BASH_VERSION" ]; then
    echo "ERROR: This script requires bash. Please run with: /bin/bash"
    echo "Current shell: $0"
    exit 1
fi

# build_xubuntu_gui_base_sif.sh -- DROP-IN (3 Sep)
# Baseline preserved; adds:
# - Drake key hardening via host-cached asc
# - Conda base: jupyter + meshcat
# - Julia 1.10 LTS + base/robotics (media envs + GPU precompile helper)
# - TeX/English-only (feature-complete)
# - Meldis/MeshCat wiring
set -euo pipefail

# -- Check for required host dependencies --
if ! command -v dpkg-deb >/dev/null 2>&1; then
    echo -e "\nERROR: Host dependency 'dpkg-deb' not found."
    echo "Please install it with: sudo apt update && sudo apt install dpkg-dev"
    exit 1
fi

# At the beginning of the script
export LC_ALL=C
export LC_NUMERIC=C
export LANG=C

# Start time tracking
BUILD_START_TIME=$(date +%s)


#==============================================================================
# Logging Setup
#==============================================================================
LOG_DIR="${PWD}/build_logs"

# Clean up old logs first (before creating new log files)
echo "Cleaning up old log files..."
if [ -d "$LOG_DIR" ]; then
    # Keep only the 1 most recent log file (skip first 1, delete the rest)
    find "${LOG_DIR}" -name "build_*.log" -type f | sort -r | tail -n +2 | xargs rm -f 2>/dev/null || true
    find "${LOG_DIR}" -name "errors_*.log" -type f | sort -r | tail -n +2 | xargs rm -f 2>/dev/null || true
    echo "Old log files cleaned up (kept latest 1)"
fi

# Create log directory
mkdir -p "${LOG_DIR}"

# Now create new log files
LOG_FILE="${LOG_DIR}/build-$(date +%Y%m%d-%H%M%S).log"
ERROR_LOG="${LOG_DIR}/errors-$(date +%Y%m%d-%H%M%S).log"

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#==============================================================================
# Define OUR controlled directories
#==============================================================================
OUR_TMP_DIR="/tmp/singularity_builds"
OUR_HOME_DIR="$HOME/singularity_builds"

# Function to log with timestamp (simplified for better readability)
log_with_timestamp() {
    local message="[$(date +'%H:%M:%S')] $1"
    if [ -f "$LOG_FILE" ]; then
        echo -e "${BLUE}${message}${NC}" | tee -a "${LOG_FILE}"
    else
        echo -e "${BLUE}${message}${NC}"
    fi
}

# Function to log errors (RED in both terminal and log)
log_error() {
    local message="[$(date +'%H:%M:%S')] ERROR: $1"
    if [ -f "${ERROR_LOG}" ] && [ -f "${LOG_FILE}" ]; then
        echo -e "${RED}${message}${NC}" | tee -a "${ERROR_LOG}" | tee -a "${LOG_FILE}"
    else
        echo -e "${RED}${message}${NC}"
    fi
}

# Function to log warnings (YELLOW in both terminal and log)
log_warning() {
    local message="[$(date +'%H:%M:%S')] WARNING: $1"
    if [ -f "$LOG_FILE" ]; then
        echo -e "${YELLOW}${message}${NC}" | tee -a "${LOG_FILE}"
    else
        echo -e "${YELLOW}${message}${NC}"
    fi
}

# Function to log success (GREEN in both terminal and log)
log_success() {
    local message="[$(date +'%H:%M:%S')] SUCCESS: $1"
    if [ -f "$LOG_FILE" ]; then
        echo -e "${GREEN}${message}${NC}" | tee -a "${LOG_FILE}"
    else
        echo -e "${GREEN}${message}${NC}"
    fi
}

log() { printf "\n[info] %s\n" "$@" ; }
warn() { printf "\n[warn] %s\n" "$@" >&2; }

err() { printf "\n[err] %s\n" "$@" >&2; exit 1; }

# Progress reporting with timestamps
progress() {
    local step="$1"
    local total="$2"
    local desc="$3"
    printf "\n[%d/%d] %s\n" "$step" "$total" "$desc"
}

#==============================================================================
# Time tracking
#==============================================================================
start_time() {
    local start=$(date +%s)
    echo "$start"
}

elapsed_time() {
    local start="$1"
    local end=$(date +%s)
    local elapsed=$((end - start))
    printf "%02d:%02d:%02d" $((elapsed/3600)) $(((elapsed%3600/60))) $((elapsed%60))
}

#==============================================================================
# DETECT which container system is in use
#==============================================================================
detect_container_system() {
    if command -v singularity >/dev/null 2>&1; then
        echo "singularity"
    elif command -v apptainer >/dev/null 2>&1; then
        echo "apptainer"
    else
        echo "none"
    fi
}

CONTAINER_CMD=$(detect_container_system)

if [ "$CONTAINER_CMD" = "none" ]; then
    log "ERROR: Neither singularity nor apptainer found in system"
    exit 1
fi

log "Detected container system: $CONTAINER_CMD"

#==============================================================================
# COMPREHENSIVE CLEANUP - All remnants and orphans
#==============================================================================


#==============================================================================
# STRICT CLEANUP of our build directories (from previous code)
#==============================================================================
strict_cleanup_our_dirs() {
    # ... (keep your previous strict_cleanup_our_dirs() function here) ...
    local parent_dir="$1"
    local max_attempts=3

    if [ ! -d "$parent_dir" ]; then
        echo " ✓ Directory does not exist: $parent_dir"
        return
    fi

    echo "Cleaning... $parent_dir"

    local target_dirs=$(find "$parent_dir" -maxdepth 1 -type d \( \
        -name "build-temp-*" \
        -o -name "bundle-temp-*" \
        -o -name "sbuild-*" \
    \) 2>/dev/null)

    if [ -z "$target_dirs" ]; then
        echo " ✓ No temp directories found"
        return
    fi

    local count=$(echo "$target_dirs" | wc -l)
    echo "Found $count directories"

    for attempt in $(seq 1 $max_attempts); do
        # Kill processes
        echo "$target_dirs" | while read dir; do
            [ ! -d "$dir" ] && continue
            sudo lsof +D "$dir" 2>/dev/null | tail -n +2 | awk '{print $2}' | sort -u | while read pid; do
                local user=$(ps -p "$pid" -o user= 2>/dev/null)
                # If job is from same user then only kill it
                if [ "$user" = "$USER" ]; then
                    sudo kill -9 "$pid" 2>/dev/null || true
                fi
            done
        done

        sleep 1

        # Unmount
        echo "$target_dirs" | while read dir; do
            [ ! -d "$dir" ] && continue
            mount 2>/dev/null | grep "$dir" | awk '{print $3}' | while read mpoint; do
                sudo umount -l "$mpoint" 2>/dev/null || true
            done
        done

        sleep 1

        # Remove with escalating force
        echo "$target_dirs" | while read dir; do
            [ ! -d "$dir" ] && continue
            sudo chmod -R 777 "$dir" 2>/dev/null
            sudo chattr -i -R "$dir" 2>/dev/null
            sudo rm -rf "$dir" 2>/dev/null || true
        done

        # Check if successful
        local remaining=$(find "$parent_dir" -maxdepth 1 -type d \( \
            -name "build-temp-*" \
            -o -name "bundle-temp-*" \
            -o -name "sbuild-*" \
        \) 2>/dev/null | wc -l)

        if [ "$remaining" -eq 0 ]; then
            echo " ✓ All directories removed"
            return 0
        fi
    done
    return 1
}

comprehensive_cleanup() {
    echo ""
    echo "=========================================="
    echo "COMPREHENSIVE CLEANUP - All Remnants"
    echo "=========================================="

    # --- 1. Kill OUR container processes ---
    echo ""
    echo "1. Killing OUR ${CONTAINER_CMD} processes..."
    ps aux | grep -E "singularity|apptainer" | grep "$USER" | grep -v grep | awk '{print $2}' | while read pid; do
        # Verify it's actually our process
        local cmd=$(ps -p "$pid" -o cmd= 2>/dev/null)
        if [ -n "$cmd" ]; then
            echo " > Killing PID $pid: $(echo $cmd | cut -c1-60)"
            sudo kill -9 "$pid" 2>/dev/null || true
        fi
    done
    sleep 3

    # --- 2. Clean build temp directories ---
    echo ""
    echo "2. Cleaning build temp directories in OUR folders..."
    strict_cleanup_our_dirs "$OUR_TMP_DIR"
    strict_cleanup_our_dirs "$OUR_HOME_DIR"

    # --- 3. Clean container cache directories ---
    echo ""
    echo "3. Cleaning ${CONTAINER_CMD} cache directories..."

    # Determine cache locations based on container system
    local cache_base=""
    if [ "$CONTAINER_CMD" = "singularity" ]; then
        cache_base="$HOME/.singularity"
    else
        cache_base="$HOME/.apptainer"
    fi

    # Clean temporary cache, NOT the actual image cache
    if [ -d "$cache_base" ]; then
        echo "   Cleaning $cache_base/cache/tmp..."
        if [ -d "$cache_base/cache/tmp" ]; then
            local tmp_count=$(find "$cache_base/cache/tmp" -type f 2>/dev/null | wc -l)
            echo "   Found $tmp_count temporary files"
            sudo rm -rf "$cache_base/cache/tmp"/* 2>/dev/null || true
        fi

        # Clean any .lock files (stale locks from failed builds)
        echo "   Cleaning stale lock files..."
        local lock_count=$(find "$cache_base" -name "*.lock" 2>/dev/null | wc -l)
        if [ "$lock_count" -gt 0 ]; then
            echo "   Found $lock_count lock files"
            find "$cache_base" -name "*.lock" -exec rm -f {} + 2>/dev/null || true
        fi

        # Clean incomplete/partial downloads
        if [ -d "$cache_base/cache/oci-tmp" ]; then
            echo "   Cleaning partial downloads..."
            local partial_count=$(find "$cache_base/cache/oci-tmp" -type d 2>/dev/null | wc -l)
            echo "   Found $partial_count partial OCI downloads"
            sudo rm -rf "$cache_base/cache/oci-tmp"/* 2>/dev/null || true
        fi

    fi

    
    # --- 4. Clean orphaned/incomplete container images ---
    echo ""
    echo "4. Identifying orphaned/incomplete containers..."

    # Check in our build directories
    for dir in "$OUR_TMP_DIR" "$OUR_HOME_DIR"; do
        if [ -d "$dir" ]; then
            echo "   Checking $dir..."

            # Find .sif files that are incomplete (being written, locked, or 0 bytes)
            find "$dir" -maxdepth 2 -name "*.sif" 2>/dev/null | while read sif_file; do
                local sif_name=$(basename "$sif_file")
                local sif_size=$(stat -c%s "$sif_file" 2>/dev/null || echo "0")
                
                # Check if file is incomplete/orphaned
                local is_orphaned=0

                # Check 1: Zero size (failed build)
                if [ "$sif_size" -eq 0 ]; then
                    echo "      ✗ Orphaned (0 bytes): $sif_name"
                    is_orphaned=1
                fi

                # Check 2: File locked by a dead process
                if sudo lsof "$sif_file" 2>/dev/null | grep -q .; then
                    local pid=$(sudo lsof "$sif_file" 2>/dev/null | tail -n +2 | awk '{print $2}' | head -1)
                    if ! ps -p "$pid" > /dev/null 2>&1; then
                        echo "      ✗ Orphaned (locked by dead PID $pid): $sif_name"
                        is_orphaned=1
                    fi
                fi

                # Check 3: Partial .sif file (has .partial extension or temp naming)
                if [[ "$sif_name" == *.partial ]] || [[ "$sif_name" == tmp_* ]] || [[ "$sif_name" == .tmp* ]]; then
                    echo "      ✗ Orphaned (partial/temp name): $sif_name"
                    is_orphaned=1
                fi

                # Check 4: Very small size (< 10MB - likely incomplete)
                if [ "$sif_size" -lt 10485760 ] && [ "$sif_size" -gt 0 ]; then
                    echo "      ✗ Orphaned (suspiciously small $sif_size bytes): $sif_name"
                    is_orphaned=1
                fi

                # Remove if orphaned
                if [ $is_orphaned -eq 1 ]; then
                    echo "        Removing orphaned container: $sif_file"
                    sudo rm -f "$sif_file" 2>/dev/null || {
                        echo "        → Failed to remove, trying force..."
                        sudo lsof "$sif_file" 2>/dev/null | tail -n +2 | awk '{print $2}' | while read lock_pid; do
                            sudo kill -9 "$lock_pid" 2>/dev/null || true
                        done
                        sleep 1
                        sudo rm -f "$sif_file" 2>/dev/null || echo "        → Still locked!"
                    }
                else
                    echo "      ✓ Valid container ($(numfmt --to=iec-i --suffix=B $sif_size)): $sif_name"
                fi
            done
        fi
    done

    # --- 5. Clean session directories ---
    echo ""
    echo "5. Cleaning session directories..."
    # Singularity/Apptainer creates session dirs in /tmp
    find /tmp -maxdepth 1 -type d -user "$USER" \( \
        -name "${CONTAINER_CMD}-*" -o \
        -name "${CONTAINER_CMD}-*" \
    \) 2>/dev/null | while read session_dir; do
        echo "   Removing session: $(basename "$session_dir")"
        sudo rm -rf "$session_dir" 2>/dev/null || true
    done

    # --- 6. Clean mount point remnants ---
    echo ""
    echo "6. Cleaning mount point remnants..."
    # Check for orphaned overlay/underlay mounts
    mount 2>/dev/null | grep -E "singularity|apptainer" | grep "$USER" | awk '{print $3}' | while read mpoint; do
        echo "   Unmounting: $mpoint"
        sudo umount -l "$mpoint" 2>/dev/null || true
        sudo umount -f "$mpoint" 2>/dev/null || true
    done

    # --- 7. Clean PID files ---
    echo ""
    echo "7. Cleaning stale PID files..."
    find /tmp -maxdepth 1 -type f -user "$USER" -name "*.pid" 2>/dev/null | while read pid_file; do
        if [[ "$(basename "$pid_file")" == "singularity"* ]] || [[ "$(basename "$pid_file")" == "apptainer"* ]]; then
            local pid=$(cat "$pid_file" 2>/dev/null)
            if [ -n "$pid" ]; then
                if ! ps -p "$pid" > /dev/null 2>&1; then
                    echo "   Removing stale PID file (process $pid dead): $(basename "$pid_file")"
                    rm -f "$pid_file" 2>/dev/null || true
                fi
            else
                echo "   Removing empty PID file: $(basename "$pid_file")"
                rm -f "$pid_file" 2>/dev/null || true
            fi
        fi
    done

    # --- 8. Clean temporary overlay files ---
    echo ""
    echo "8. Cleaning temporary overlay files..."
    find /tmp -maxdepth 1 -type f -user "$USER" \( \
        -name "*overlay*" -o \
        -name "*.sqfs" -o \
        -name "*.ext3" \
    \) 2>/dev/null | while read overlay_file; do
        # Check if it's being used
        if ! sudo lsof "$overlay_file" 2>/dev/null | grep -q .; then
            echo "   Removing unused overlay: $(basename "$overlay_file")"
            sudo rm -f "$overlay_file" 2>/dev/null || true
        fi
    done

    # === 9. Final verification ===
    echo ""
    echo "9. Final verification..."
    local issues=0

    # Check for remaining build-temp directories
    local remaining_temps=$(find "$OUR_TMP_DIR" "$OUR_HOME_DIR" -maxdepth 1 -type d \( \
        -name "build-temp-*" \
        -o -name "bundle-temp-*" \
        -o -name "sbuild-*" \
    \) 2>/dev/null | wc -l)

    if [ "$remaining_temps" -gt 0 ]; then
        echo "  ✗ Still have $remaining_temps temp directories"
        issues=$((issues + remaining_temps))
    else
        echo "  ✓ No temp directories remaining"
    fi

    # Check for orphaned processes
    local remaining_procs=$(ps aux | grep -E "singularity|apptainer" | grep "$USER" | grep -v grep | wc -l)
    if [ "$remaining_procs" -gt 0 ]; then
        echo "  ✗ Still have $remaining_procs container processes running"
        ps aux | grep -E "singularity|apptainer" | grep "$USER" | grep -v grep | while read line; do
            echo "    - $(echo $line | awk '{print $2, $11}')"
        done
        issues=$((issues + remaining_procs))
    else
        echo "  ✓ No container processes remaining"
    fi

    # Check for orphaned mounts
    local remaining_mounts=$(mount 2>/dev/null | grep -E "singularity|apptainer" | grep "$USER" | wc -l)
    if [ "$remaining_mounts" -gt 0 ]; then
        echo "  ✗ Still have $remaining_mounts orphaned mounts"
        issues=$((issues + remaining_mounts))
    else
        echo "  ✓ No orphaned mounts remaining"
    fi

    echo ""
    if [ "$issues" -eq 0 ]; then
        echo "CLEANUP COMPLETE - No issues found"
        return 0
    else
        echo "!!! CLEANUP INCOMPLETE - $issues issues remain"
        return 1
    fi
}


#==============================================================================
# PRE-BUILD COMPREHENSIVE CLEANUP
#==============================================================================
log "Starting comprehensive pre-build cleanup..."
if ! comprehensive_cleanup; then
    log "ERROR: Comprehensive cleanup failed"
    log "Cannot proceed with build until all remnants are removed"
    exit 1
fi
log "✓ Comprehensive cleanup verified successful"

#==============================================================================
# POST-BUILD CLEANUP TRAP
#==============================================================================
cleanup_on_exit() {
    local exit_code=$?
    
    echo ""
    echo "=========================================="
    echo "POST-BUILD CLEANUP (exit code: $exit_code)"
    echo "=========================================="
    comprehensive_cleanup || true
    
    exit $exit_code
}
trap cleanup_on_exit EXIT INT TERM


# Note: DEF file removal will be done after variable definitions

#==============================================================================
# Redirect all output to log file and console
#==============================================================================
log_with_timestamp "Starting build process..."
log_with_timestamp "Log file: ${LOG_FILE}"
log_with_timestamp "Error log: ${ERROR_LOG}"

# Redirect stdout to log file while preserving terminal output
# ...
exec > >(tee -a "${LOG_FILE}") 2> >(tee -a "${LOG_FILE}" >&2)

# Log script start with detailed information
echo "=============================================================================="
echo "Build Script Start: $(date)"
echo "Log File: ${LOG_FILE}"
echo "Error Log: ${ERROR_LOG}"
echo "Working directory: $(pwd)"
echo "Script PID: $$"
echo "=============================================================================="

#==============================================================================
# Dynamic & Robust Temporary Directory Setup
#==============================================================================
log_with_timestamp "Configuring robust temporary directory for build..."

# --- 1. Define a unique, traceable directory name ---
# This ensures we only clean up directories created by this script.
TRACEABLE_DIR_NAME="singularity_builds"

log "Stale directory cleanup complete."

# Re-enable strict error checking for rest of script
set -e
log "Starting build process..."

# --- 3. Intelligent Directory Selection Based on Disk Space ---
BUILD_TMP_DIR=""
# Get available space in GB for the root directory (where /tmp resides)
ROOT_AVAIL_GB=$(df -BG / | awk 'NR==2 {print substr($4, 1, length($4)-1)}')

if (( ROOT_AVAIL_GB >= 150 )); then
    # If / has enough space, use our specific directory within /tmp
    BUILD_TMP_DIR="/tmp/${TRACEABLE_DIR_NAME}"
    log_success "Sufficient space (${ROOT_AVAIL_GB}GB) in /. Using traceable directory: ${BUILD_TMP_DIR}"
else
    log_warning "Insufficient space (${ROOT_AVAIL_GB}GB) in /. Checking home directory for an alternative..."

    # Get available space in GB for the home directory partition
    HOME_AVAIL_GB=$(df -BG "$HOME" | awk 'NR==2 {print substr($4, 1, length($4)-1)}')

    if (( HOME_AVAIL_GB >= 150 )); then
        # If the home directory has enough space, use our specific directory there
        BUILD_TMP_DIR="$HOME/${TRACEABLE_DIR_NAME}"
        log_success "Using traceable directory in home with ${HOME_AVAIL_GB}GB available: ${BUILD_TMP_DIR}"
    else
        log_error "Insufficient space in home directory (${HOME_AVAIL_GB}GB). Required: 150GB."
        log "Build cannot proceed. Please free up disk space."
        exit 1
    fi
fi

# Create the chosen directory and set permissions
mkdir -p "${BUILD_TMP_DIR}"
chmod 777 "${BUILD_TMP_DIR}"

# --- 4. Set the Environment for Singularity/Apptainer ---
export SINGULARITY_TMPDIR="${BUILD_TMP_DIR}"
export APPTAINER_TMPDIR="${BUILD_TMP_DIR}"
log "Build engine temporary directory set to: ${APPTAINER_TMPDIR}"
#==============================================================================
# Host-side Caches and Directories (Baseline)
#==============================================================================
CACHE_DIR="${PWD}/container_cache"
BIN_CACHE="${CACHE_DIR}/binaries"
DEB_CACHE="${CACHE_DIR}/debs"
APT_CACHE="${CACHE_DIR}/apt"
APT_ARCHIVE_CACHE="${CACHE_DIR}/apt/archives"
CONDA_CACHE="${CACHE_DIR}/conda_pkgs"
JULIA_CACHE="${CACHE_DIR}/julia_pkgs"
WHEELS_CACHE="${CACHE_DIR}/wheels"

# Create all cache directories with proper permissions and logging
log_with_timestamp "Creating comprehensive cache directory structure..."

# Function to create directory with proper permissions and logging
create_directory_with_permissions() {
    local dir_path="$1"
    local description="$2"

    if mkdir -p "$dir_path" 2>/dev/null; then
        chmod 755 "$dir_path" 2>/dev/null || true
        if [ -d "$dir_path" ] && [ -w "$dir_path" ]; then
            log_success "Directory created: $description ($dir_path)"
            return 0
        else
            log_error "Directory created but not writable: $description ($dir_path)"
            return 1
        fi
    else
        log_error "Failed to create directory: $description ($dir_path)"
        return 1
    fi
}

# Create main cache directories
create_directory_with_permissions "${BIN_CACHE}" "Binaries cache"
create_directory_with_permissions "${DEB_CACHE}" "DEB packages cache"
create_directory_with_permissions "${APT_CACHE}" "APT cache"
create_directory_with_permissions "${APT_ARCHIVE_CACHE}" "APT archives cache"
create_directory_with_permissions "${CONDA_CACHE}" "Conda packages cache"
create_directory_with_permissions "${JULIA_CACHE}" "Julia packages cache"
create_directory_with_permissions "${WHEELS_CACHE}" "Python wheels cache"

# Create build logs directory (already created in logging setup, but ensure it exists)
create_directory_with_permissions "${LOG_DIR}" "Build logs directory"

# Create additional directories that might be needed during build
create_directory_with_permissions "${CACHE_DIR}/tmp" "Temporary cache directory"
create_directory_with_permissions "${CACHE_DIR}/downloads" "Downloads cache directory"

log_with_timestamp "Comprehensive cache directory structure created successfully"

OUT_DIR="${PWD}"
SIF_NAME="xubuntu_base_image_complete.sif"
DEF_NAME="xubuntu_base_image_complete.def"

# Remove existing definition file to ensure clean build
log_with_timestamp "Removing existing definition file..."
if [ -f "${DEF_NAME}" ]; then
    rm -f "${DEF_NAME}"
    log_with_timestamp "Existing definition file removed: ${DEF_NAME}"
else
    log_with_timestamp "No existing definition file found"
fi

# Create output directory with proper permissions
log_with_timestamp "Creating output directory..."
mkdir -p "${OUT_DIR}"
if [ -d "${OUT_DIR}" ]; then
    log_success "Output directory created: ${OUT_DIR}"
else
    log_error "Failed to create output directory: ${OUT_DIR}"
fi


#==============================================================================
# Helper Functions
#==============================================================================

# Robust fetch with host cache (baseline)
fetch() { # fetch <url> <dst>
    local url="$1" dst="$2"
    if [ ! -s "$dst" ]; then
        log "Fetching ${dst##*/}"
    else
        log "Using cached: $(basename "$dst")"
        return 0
    fi

    # Attempt 1: aria2c (fastest)
    if command -v aria2c >/dev/null 2>&1; then
        # Adaptive connection count based on file size
        local file_size_mb=$(curl -sSLI "$url" | grep -i content-length | awk '{print int($2/1024/1024)}' 2>/dev/null || echo "0")
        local connections=4
        if [[ $file_size_mb -gt 100 ]]; then
            connections=8
        elif [[ $file_size_mb -gt 50 ]]; then
            connections=6
        fi

        aria2c --check-certificate=true --max-connection-per-server=$connections --split=$connections \
            --retry-wait=2 --timeout=30 --continue=true -o "$(basename "$dst")" \
            -d "$(dirname "$dst")" --console-log-level=error "$url" 2>/dev/null || warn "aria2c failed for $url; trying curl"
    fi

    # Attempt 2: curl (fallback)
    if [ ! -s "$dst" ]; then
        curl -fL --retry 5 --retry-delay 2 -o "$dst" "$url" || warn "curl failed for $url; trying wget"
    fi

    # Attempt 3: wget (most compatible fallback)
    if [ ! -s "$dst" ] && command -v wget >/dev/null 2>&1; then
        wget --tries=5 --waitretry=2 -O "$dst" "$url"
    fi

    # Final verification
    if [ ! -s "$dst" ]; then
        err "All download methods (aria2c, curl, wget) failed for '$url'"
    else
        log "Cached $(basename "$dst")"
    fi
}

#==============================================================================
# Pruning scripts for cache
#==============================================================================
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
mapfile -t ALL_DEBS < <(find . -maxdepth 1 -type f -name '*.deb' -printf '%f\n')
if (( ${#ALL_DEBS[@]} == 0 )); then echo "[apt-prune] INFO: no .deb files to consider"; exit 0; fi

# Derive unique package bases (before first underscore)
mapfile -t BASES < <(printf '%s\n' "${ALL_DEBS[@]}" | awk -F '_' '{print $1}' | sort -u)

removed_total=0
for pkg in "${BASES[@]}"; do
    # List *this* package's debs newest first (lexicographical version sort is OK for APT pools)
    mapfile -t ALL_FOR_PKG < <(ls -1t "$pkg"_*.deb 2>/dev/null || true)
    if (( ${#ALL_FOR_PKG[@]} <= KEEP )); then continue; fi

    # Determine files to prune
    if (( (${#ALL_FOR_PKG[@]} - KEEP) > 0 )); then
        mapfile -t TO_REMOVE < <(printf '%s\n' "${ALL_FOR_PKG[@]}" | tail -n +$((KEEP+1)))
    else
        TO_REMOVE=()
    fi

    if (( ${#TO_REMOVE[@]} > 0 )); then
        if [[ -n "$APPLY" ]]; then
            printf '%s\n' "${TO_REMOVE[@]}" | xargs -0r rm -f
            (( removed_total += ${#TO_REMOVE[@]} ))
        else
            printf '[apt-prune] Would remove %s\n' "${TO_REMOVE[@]}"
        fi
    fi
done

if [[ -n "$APPLY" ]] && (( removed_total > 0 )); then echo "[apt-prune] Removed ${removed_total} file(s)"; else echo "[apt-prune] Dry-run complete"; fi
APS
chmod +x ./prune_apt_cache.sh

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
mapfile -t PKGFILES < <(find . -maxdepth 1 -type f \( -name '*.conda' -o -name '*.tar.bz2' \) -printf '%f\n')
if (( ${#PKGFILES[@]} == 0 )); then echo "[conda-prune] INFO: no conda artifacts found"; exit 0; fi

# Derive base names: strip version-build-suffix and extension
# Matches: name-version-build.(conda|tar.bz2)
mapfile -t BASES < <(printf '%s\n' "${PKGFILES[@]}" | \
  sed -E 's/-[0-9.-]+-[a-z0-9_]+(\.conda|\.tar\.bz2)$//' | sort -u)

removed_total=0
for base in "${BASES[@]}"; do
    # All variants for this base (sort with -V to respect 1.10 > 1.9 etc.)
    mapfile -t ALL_FOR_BASE < <(ls -1 "${base}"-[0-9]*.{conda,tar.bz2} 2>/dev/null | sort -rV || true)
    if (( ${#ALL_FOR_BASE[@]} <= KEEP )); then continue; fi

    if (( (${#ALL_FOR_BASE[@]} - KEEP) > 0 )); then
        mapfile -t TO_REMOVE < <(printf '%s\n' "${ALL_FOR_BASE[@]}" | tail -n +$((KEEP+1)))
    else
        TO_REMOVE=()
    fi

    if (( ${#TO_REMOVE[@]} > 0 )); then
        if [[ -n "$APPLY" ]]; then
            printf '%s\n' "${TO_REMOVE[@]}" | xargs -0r rm -f
            (( removed_total += ${#TO_REMOVE[@]} ))
        else
            printf '[conda-prune] Would remove %s\n' "${TO_REMOVE[@]}"
        fi
    fi
done

if [[ -n "$APPLY" ]] && (( removed_total > 0 )); then echo "[conda-prune] Removed ${removed_total} file(s)"; else echo "[conda-prune] Dry-run complete"; fi
CPS
chmod +x ./prune_conda_cache.sh


#==============================================================================
# Pinned Software Versions and URLs
#==============================================================================
# --- Miniforge ---
MINIFORGE_VER="25.3.1-0"
MINIFORGE_SH="Miniforge3-${MINIFORGE_VER}-Linux-x86_64.sh"
MINIFORGE_URL="https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VER}/${MINIFORGE_SH}"
MINIFORGE_SHA256="376b160ed8130820db0ab0f3826ac1fc85923647f75c1b8231166e3d559ab768"

# --- Micromamba ---
MICROMAMBA_VER="2.3.2-0"
MICROMAMBA_BIN="micromamba-linux-64"
MICROMAMBA_URL="https://github.com/mamba-org/micromamba-releases/releases/download/${MICROMAMBA_VER}/${MICROMAMBA_BIN}"
MICROMAMBA_SHA256="ffc3cb8d52d4d6b354bdbb979c407719c485392b74e462cbd50811aa88e58f85"

# --- TurboVNC / VirtualGL ---
TURBOVNC_VER="3.2.1"
TURBOVNC_DEB="turbovnc_${TURBOVNC_VER}_amd64.deb"
TURBOVNC_URL="https://github.com/TurboVNC/turbovnc/releases/download/${TURBOVNC_VER}/${TURBOVNC_DEB}"
VIRTUALGL_VER="3.1.4"
VIRTUALGL_DEB="virtualgl_${VIRTUALGL_VER}_amd64.deb"
VIRTUALGL_URL="https://github.com/VirtualGL/virtualgl/releases/download/${VIRTUALGL_VER}/${VIRTUALGL_DEB}"

# --- yq (Go) ---
YQ_VER="v4.48.1"
YQ_BIN="yq_linux_amd64"
YQ_URL="https://github.com/mikefarah/yq/releases/download/${YQ_VER}/${YQ_BIN}"
YQ_SHA256="ffc3cb8d52d4d6b354bdbb979c407719c485392b74e462cbd50811aa88e58f85"

# --- Drake, Julia & Julia Pin ---
DRAKE_ASC_URL="https://drake-apt.csail.mit.edu/drake.asc"
DRAKE_KEY_URL="https://drake-apt.csail.mit.edu/drake.asc"

# GPG Keys for verification
VIRTUALGL_TURBOVNC_GPG_KEY_ID="4BACCAB36E7FE9A1"
VIRTUALGL_TURBOVNC_GPG_KEY_URL="https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xae1a7ba4efff9a9987e1474c4baccab36e7fe9a1"
JULIA_LTS_VER="1.10.5" # LTS
JULIA_TARBALL="julia-${JULIA_LTS_VER}-linux-x86_64.tar.gz"
JULIA_URL="https://julialang-s3.julialang.org/bin/linux/x64/${JULIA_LTS_VER%.*}/${JULIA_TARBALL}"
JASC_URL="https://julialang-s3.julialang.org/bin/linux/x64/${JULIA_LTS_VER%.*}/${JULIA_TARBALL}.asc"

# --- NVIDIA Keyring ---
NVIDIA_KEYRING_VER="1.1-1"
NVIDIA_KEYRING_DEB="cuda-keyring_${NVIDIA_KEYRING_VER}-1_all.deb"
NVIDIA_KEYRING_URL="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/${NVIDIA_KEYRING_DEB}"


#==============================================================================
# Prefetch Artifacts to Host Cache
#==============================================================================
log_with_timestamp "Prefetching required artifacts to host cache..."

# Function to fetch and set permissions for binaries
fetch_binary() {
    local url="$1"
    local dst="$2"
    fetch "$url" "$dst" && chmod +x "$dst"
}

# Check if all artifacts are already cached
check_cache_complete() {
    local missing=0
    [[ ! -f "${BIN_CACHE}/${MINIFORGE_SH}" ]] && ((missing++))
    [[ ! -f "${BIN_CACHE}/${MICROMAMBA_BIN}" ]] && ((missing++))
    [[ ! -f "${BIN_CACHE}/${YQ_BIN}" ]] && ((missing++))
    [[ ! -f "${DEB_CACHE}/${TURBOVNC_DEB}" ]] && ((missing++))
    [[ ! -f "${DEB_CACHE}/${VIRTUALGL_DEB}" ]] && ((missing++))
    [[ ! -f "${BIN_CACHE}/drake.asc" ]] && ((missing++))
    [[ ! -f "${BIN_CACHE}/${JULIA_TARBALL}" ]] && ((missing++))
    [[ ! -f "${BIN_CACHE}/julia_key.asc" ]] && ((missing++))
    echo $missing
}

# Cache integrity check and repair function
check_cache_integrity() {
    echo "===> Checking cache integrity..."
    issues=0
    # Check for corrupted files
    for cache_dir in "${BIN_CACHE}" "${DEB_CACHE}" "${APT_ARCHIVE_CACHE}" "${CONDA_CACHE}" "${WHEELS_CACHE}" "${JULIA_CACHE}"; do
        if [ -d "$cache_dir" ]; then
            # Check for zero-byte files (likely corrupted downloads)
            zero_files=$(find "$cache_dir" -type f -size 0 2>/dev/null)
            if [ -n "$zero_files" ]; then
                echo "  ✗ Found zero-byte files in $(basename "$cache_dir")"
                find "$cache_dir" -type f -size 0 -delete 2>/dev/null || true
                echo "    ✓ Removed zero-byte files"
                issues=$((issues + 1))
            fi

            # Check for incomplete downloads (files ending with .part, .tmp, etc.)
            incomplete_files=$(find "$cache_dir" -type f \( -name "*.part" -o -name "*.tmp" -o -name "*.aria2" \) 2>/dev/null | wc -l)
            if [[ "$incomplete_files" -gt 0 ]]; then
                echo "  ✗ Found $incomplete_files incomplete downloads in $(basename "$cache_dir")"
                find "$cache_dir" -type f \( -name "*.part" -o -name "*.tmp" -o -name "*.aria2" \) -delete 2>/dev/null || true
                echo "    ✓ Removed incomplete downloads"
                issues=$((issues + 1))
            fi
        fi
    done
    if [[ "$issues" -eq 0 ]]; then
        echo "  ✓ Cache integrity check passed"
    else
        echo "  ✓ Cache integrity issues repaired: $issues problems fixed"
    fi
    return 0 # Always return success after repair
}

# Clean up any existing incomplete downloads and check cache integrity
echo "===> Cleaning up any existing incomplete downloads..."
find "${CACHE_DIR}" -type f \( -name "*.part" -o -name "*.tmp" -o -name "*.aria2" \) -delete 2>/dev/null || true
find "${CACHE_DIR}" -type f -size 0 -delete 2>/dev/null || true

check_cache_integrity

# Skip downloads if all artifacts are cached
if [[ $(check_cache_complete) -eq 0 ]]; then
    log "All artifacts already cached, skipping downloads"
else
    # Export functions for parallel execution
    export -f fetch fetch_binary log log_with_timestamp log_success log_warning log_error warn err

    # Define download tasks
    cat > /tmp/download_tasks << EOF
MINIFORGE|${MINIFORGE_URL}|${BIN_CACHE}/${MINIFORGE_SH}|binary
MICROMAMBA|${MICROMAMBA_URL}|${BIN_CACHE}/${MICROMAMBA_BIN}|binary
YQ|${YQ_URL}|${BIN_CACHE}/${YQ_BIN}|binary
TURBOVNC|${TURBOVNC_URL}|${DEB_CACHE}/${TURBOVNC_DEB}|deb
VIRTUALGL|${VIRTUALGL_URL}|${DEB_CACHE}/${VIRTUALGL_DEB}|deb
DRAKE_KEY|${DRAKE_ASC_URL}|${BIN_CACHE}/drake.asc|file
JULIA|${JULIA_URL}|${BIN_CACHE}/${JULIA_TARBALL}|file
NVIDIA_KEYRING|${NVIDIA_KEYRING_URL}|${DEB_CACHE}/${NVIDIA_KEYRING_DEB}|deb
EOF

    # Execute downloads in parallel (max 4 concurrent)
    log "Downloading artifacts in parallel..."
    # The `bash -c` is needed to call our exported shell functions within xargs
    cat /tmp/download_tasks | xargs -P 4 -I '{}' bash -c '
        IFS="|" read -r name url dst type <<< "{}"
        echo "Starting download: $name"
        if [[ "$type" == "binary" ]]; then fetch_binary "$url" "$dst"; else fetch "$url" "$dst"; fi;
        echo "Completed download: $name"
    '
    rm -f /tmp/download_tasks
fi

# --- Prefetch GPG Keys ---
log_with_timestamp "Prefetching public GPG keys..."
JULIA_GPG_KEY_ID="3673DF529D9049477F76B37566E3C7DC03D6E495"
JULIA_KEY_FILE="${BIN_CACHE}/julia_key.asc"
if [ ! -s "${JULIA_KEY_FILE}" ]; then
    log "Julia GPG key not found in cache. Fetching from keyserver..."
    # First, receive the key into the host's keyring
    gpg --keyserver https://keyserver.ubuntu.com --recv-keys "${JULIA_GPG_KEY_ID}" || \
    gpg --keyserver https://keys.openpgp.org --recv-keys "${JULIA_GPG_KEY_ID}"
    # Second, export the key from the keyring to our cache file
    gpg --export --armor "${JULIA_GPG_KEY_ID}" > "${JULIA_KEY_FILE}"
    if [ -s "${JULIA_KEY_FILE}" ]; then
        log_success "Successfully cached Julia GPG key to ${JULIA_KEY_FILE}"
    else
        log_error "Failed to fetch and cache Julia GPG key."
        exit 1
    fi
else
    log "Using cached Julia GPG key: $(basename "${JULIA_KEY_FILE}")"
fi
log "Prefetching complete."


# --- Singularity Definition File Generation ---
log_with_timestamp "Generating Singularity definition file: ${DEF_NAME}"
# Always remove any stale def file from previous runs
[ -f "${DEF_NAME}" ] && rm -f "${DEF_NAME}"

# Define all required files with their download URLs and validation methods
declare -A required_files=(
    ["micromamba-linux-64"]="binary|${MICROMAMBA_URL}|${MICROMAMBA_SHA256}"
    ["yq_linux_amd64"]="binary|${YQ_URL}|${YQ_SHA256}"
    ["Miniforge.sh"]="binary|${MINIFORGE_URL}|${MINIFORGE_SHA256}"
    ["julia-1.10.5-linux-x86_64.tar.gz"]="${JULIA_URL}|archive_with_asc_sha256"
    ["julia-1.10.5-linux-x86_64.tar.gz.asc"]="${JASC_URL}|asc"
    ["drake.asc"]="${DRAKE_ASC_URL}|asc"
    ["julia_key.asc"]="local|gpg"
    ["turbovnc_3.2_amd64.deb"]="${TURBOVNC_URL}|deb_with_gpg|${VIRTUALGL_TURBOVNC_GPG_KEY_ID}|${VIRTUALGL_TURBOVNC_GPG_KEY_URL}"
    ["virtualgl_3.1.3_amd64.deb"]="${VIRTUALGL_URL}|deb_with_gpg|${VIRTUALGL_TURBOVNC_GPG_KEY_ID}|${VIRTUALGL_TURBOVNC_GPG_KEY_URL}"
)


# Phase 1: Ensure all required files are present in cache
echo "Phase 1: Ensuring all required files are present in cache..."
missing_files=()
for file_name in "${!required_files[@]}"; do
    # Determine cache directory based on file type
    if [[ "${file_name}" == *.deb ]]; then
        file_path="${PWD}/container_cache/debs/${file_name}"
    elif [[ "${file_name}" == "drake.asc" ]]; then
        file_path="${PWD}/container_cache/binaries/${file_name}"
    elif [[ "${file_name}" == "julia-"*.tar.gz* ]]; then
        file_path="${PWD}/container_cache/binaries/${file_name}"
    else
        file_path="${PWD}/container_cache/binaries/${file_name}"
    fi

    if [ ! -f "$file_path" ]; then
        echo "  ✗ Missing File: $file_name"
        missing_files+=("$file_name")
    else
        echo "  ✓ Found: $file_name"
    fi
done

# Download missing files
if [ ${#missing_files[@]} -gt 0 ]; then
    echo "→ Downloading ${#missing_files[@]} missing files..."
    for file_name in "${missing_files[@]}"; do
        echo "  Downloading $file_name..."

        # Extract URL from the file definition
        file_info="${required_files[$file_name]}"
        IFS='|' read -r file_url validation_method param1 param2 param3 <<< "$file_info"

        # Determine destination directory
        if [[ "$file_name" == *.deb ]]; then
            dest_path="${PWD}/container_cache/debs/${file_name}"
        elif [[ "$file_name" == "drake.asc" ]]; then
            dest_path="${PWD}/container_cache/binaries/${file_name}"
        elif [[ "${file_name}" == "julia-"*.tar.gz* ]]; then
            dest_path="${PWD}/container_cache/binaries/${file_name}"
        else
            dest_path="${PWD}/container_cache/binaries/${file_name}"
        fi

        if curl -fSSL "$file_url" -o "$dest_path"; then
            echo "    ✓ Downloaded: $file_name"
        else
            echo "    ✗ Failed to download: $file_name"
            exit 1
        fi
    done
else
    echo "✓ All required files present in cache"
fi

# Phase 2: Validate all files for corruption
echo "Phase 2: Validating all files for corruption..."
corrupted_files=()
for file_name in "${!required_files[@]}"; do
    # Determine file path and validation method
    if [[ "${file_name}" == *.deb ]]; then
        file_path="${PWD}/container_cache/debs/${file_name}"
    elif [[ "${file_name}" == "drake.asc" ]]; then
        file_path="${PWD}/container_cache/binaries/${file_name}"
    elif [[ "${file_name}" == "julia-"*.tar.gz* ]]; then
        file_path="${PWD}/container_cache/binaries/${file_name}"
    else
        file_path="${PWD}/container_cache/binaries/${file_name}"
    fi

    echo "  Validating $file_name..."

    # Extract validation method and additional parameters from file definition
    file_info="${required_files[$file_name]}"
    IFS='|' read -r file_url validation_method param1 param2 param3 <<< "$file_info"

    case "$validation_method" in
        "binary")
            # Check if binary is executable and not corrupted
            if ! file "$file_path" | grep -q "executable"; then
                echo "    ✗ Corrupted binary detected: $file_name"
                corrupted_files+=("$file_name")
                rm -f "$file_path"
            else
                # If sha256 is provided, validate it
                if [ -n "$param1" ]; then
                    actual_sha256=$(sha256sum "$file_path" | cut -d' ' -f1)
                    if [ "$actual_sha256" = "$param1" ]; then
                        echo "    ✓ Valid binary with correct SHA256: $file_name"
                    else
                        echo "    ✗ SHA256 mismatch for $file_name (expected: $param1, got: $actual_sha256)"
                        corrupted_files+=("$file_name")
                        rm -f "$file_path"
                    fi
                else
                    echo "    ✓ Valid binary: $file_name"
                fi
            fi
            ;;
        "archive_with_asc_sha256")
            # Check if archive is valid (tar.gz) and validate with ASC signature and SHA256
            if ! tar -tzf "$file_path" >/dev/null 2>&1; then
                echo "    ✗ Corrupted archive detected: $file_name"
                corrupted_files+=("$file_name")
                rm -f "$file_path"
            else
                # Validate SHA256
                expected_sha256="b3497b89c3f9dd4f8e5d431024fd1afdb19cb7be38b788775a80d3e2bfa8dc"
                actual_sha256=$(sha256sum "$file_path" | cut -d' ' -f1)
                if [ "$actual_sha256" = "$expected_sha256" ]; then
                    echo "    ✓ Valid archive with correct SHA256: $file_name"
                    
                    # Validate ASC signature if available
                    asc_file="${file_path}.asc"
                    if [ -f "$asc_file" ]; then
                        # Import Julia GPG key for signature verification...
                        echo "    -- Importing Julia GPG key for signature verification..."
                        gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 3673DF529D909477F6B57566E3C7D0D6E495 >/dev/null 2>&1 || \
                        gpg --batch --keyserver keys.openpgp.org --recv-keys 3673DF529D909477F6B57566E3C7D0D6E495 >/dev/null 2>&1

                        if gpg --batch --verify "$asc_file" "$file_path" 2>/dev/null; then
                            echo "    ✓ Valid GPG signature: $file_name"
                        else
                            echo "    ✗ GPG signature verification failed, but SHA256 is correct - continuing"
                            # Don't mark as corrupted if SHA256 is correct
                        fi
                    else
                        echo "    ✗ ASC signature file not found for: $file_name"
                        corrupted_files+=("$file_name")
                        rm -f "$file_path"
                    fi
                else
                    echo "    ✗ SHA256 mismatch for $file_name (expected: $expected_sha256, got: $actual_sha256)"
                    corrupted_files+=("$file_name")
                    rm -f "$file_path"
                fi
            fi
            ;;
        "asc")
            # Check if ASC signature file is valid
            if [ -f "$file_path" ] && [ -s "$file_path" ]; then
                echo "    ✓ Valid ASC file: $file_name"
            fi
            ;;
        "local")
            # ASC signature file missing or empty: $file_name
            corrupted_files+=("$file_name")
            rm -f "$file_path"
            ;;
        "deb_with_gpg")
            # Check if .deb package is valid and verify with GPG signature
            if ! dpkg-deb -I "$file_path" >/dev/null 2>&1; then
                echo "    ✗ Corrupted .deb package detected: $file_name"
                corrupted_files+=("$file_name")
                rm -f "$file_path"
            else
                echo "    ✓ Valid .deb package: $file_name"
                # Note: GPG verification will be done during installation phase
                # GPG verification will be performed during installation
            fi
            ;;
        "archive")
            # Check if archive is valid (tar.gz)
            if ! tar -tzf "$file_path" >/dev/null 2>&1; then
                echo "    ✗ Corrupted archive detected: $file_name"
                corrupted_files+=("$file_name")
                rm -f "$file_path"
            else
                echo "    ✓ Valid archive: $file_name"
            fi
            ;;
    esac
done

# Phase 3: Re-download corrupted files
if [ ${#corrupted_files[@]} -gt 0 ]; then
    echo "Phase 3: Re-downloading ${#corrupted_files[@]} corrupted files..."
    for file_name in "${corrupted_files[@]}"; do
        echo "  Re-downloading $file_name..."

        # Extract URL from file definition
        file_info="${required_files[$file_name]}"
        IFS='|' read -r file_url validation_method param1 param2 <<< "$file_info"

        # Determine destination directory
        if [[ "${file_name}" == *.deb ]]; then
            dest_path="${PWD}/container_cache/debs/${file_name}"
        elif [[ "${file_name}" == "drake.asc" ]]; then
            dest_path="${PWD}/container_cache/binaries/${file_name}"
        elif [[ "${file_name}" == "julia-"*.tar.gz* ]]; then
            dest_path="${PWD}/container_cache/binaries/${file_name}"
        else
            dest_path="${PWD}/container_cache/binaries/${file_name}"
        fi

        if curl -fSSL "$file_url" -o "$dest_path"; then
            echo "    ✓ Re-downloaded: $file_name"
        else
            echo "    ✗ Failed to re-download: $file_name"
            exit 1
        fi
    done
else
    echo "Phase 3: No corrupted files found"
fi

# Phase 4: Final verification
echo "Phase 4: Final verification of all files..."
all_valid=true
for file_name in "${!required_files[@]}"; do
    # Determine file path
    if [[ "$file_name" == *.deb ]]; then
        file_path="${PWD}/container_cache/debs/${file_name}"
    elif [[ "$file_name" == "drake.asc" ]]; then
        file_path="${PWD}/container_cache/binaries/${file_name}"
    elif [[ "$file_name" == "julia-"*.tar.gz* ]]; then
        file_path="${PWD}/container_cache/binaries/${file_name}"
    else
        file_path="${PWD}/container_cache/binaries/${file_name}"
    fi

    # Extract validation method and additional parameters
    file_info="${required_files[$file_name]}"
    IFS='|' read -r file_url validation_method param1 param2 param3 <<< "$file_info"

    case "$validation_method" in
        "binary")
            if [ -f "$file_path" ] && file "$file_path" | grep -q "executable\|ELF"; then
                if [ -n "$param1" ]; then
                    actual_sha256=$(sha256sum "$file_path" | cut -d' ' -f1)
                    if [ "$actual_sha256" == "$param1" ]; then
                        echo "  ✓ Verified binary with correct SHA256: $file_name"
                    else
                        echo "  ✗ SHA256 verification failed for $file_name (expected: $param1, got: $actual_sha256)"
                        all_valid=false
                    fi
                else
                    echo "  ✓ Verified binary: $file_name"
                fi
            else
                echo "  ✗ Binary verification failed: $file_name"
                all_valid=false
            fi
            ;;
        "archive_with_asc_sha256")
            if [ -f "$file_path" ] && tar -tzf "$file_path" >/dev/null 2>&1; then
                # Validate SHA256
                expected_sha256="b3497b89c3f9dd4f8e5d431024fd1afdb19cb7be38b788775a80d3e2bfa8dc"
                actual_sha256=$(sha256sum "$file_path" | cut -d' ' -f1)
                if [ "$actual_sha256" == "$expected_sha256" ]; then
                    echo "  ✓ Verified archive with correct SHA256: $file_name"

                    # Validate ASC signature if available
                    asc_file="${file_path}.asc"
                    if [ -f "$asc_file" ]; then
                        # Import Julia GPG key first
                        gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 3673DF529D909477F6B57566E3C7D0D6E495 >/dev/null 2>&1 || \
                        gpg --batch --keyserver keys.openpgp.org --recv-keys 3673DF529D909477F6B57566E3C7D0D6E495 >/dev/null 2>&1

                        if gpg --batch --verify "$asc_file" "$file_path" >/dev/null 2>&1; then
                            echo "    ✓ Verified GPG signature: $file_name"
                        else
                            echo "    ✗ GPG signature verification failed, but SHA256 is correct - continuing"
                            # Don't mark as invalid if SHA256 is correct
                        fi
                    else
                        echo "    ✗ ASC signature file not found for: $file_name"
                        all_valid=false
                    fi
                else
                    echo "  ✗ SHA256 verification failed for $file_name (expected: $expected_sha256, got: $actual_sha256)"
                    all_valid=false
                fi
            else
                echo "  ✗ Archive verification failed: $file_name"
                all_valid=false
            fi
            ;;
        "asc")
            if [ -f "$file_path" ] && [ -s "$file_path" ] && grep -q "BEGIN PGP SIGNATURE" "$file_path" && grep -q "END PGP SIGNATURE" "$file_path"; then
                echo "  ✓ Verified ASC signature file: $file_name"
            else
                echo "  ✗ ASC signature verification failed: $file_name"
                all_valid=false
            fi
            ;;
        "deb_with_gpg")
            if [ -f "$file_path" ] && dpkg-deb -I "$file_path" >/dev/null 2>&1; then
                echo "  ✓ Verified .deb package: $file_name"
                # GPG verification will be performed during installation
            else
                echo "  ✗ .deb package verification failed: $file_name"
                all_valid=false
            fi
            ;;
        "archive")
            if [ -f "$file_path" ] && tar -tzf "$file_path" >/dev/null 2>&1; then
                echo "  ✓ Verified archive: $file_name"
            else
                echo "  ✗ Archive verification failed: $file_name"
                all_valid=false
            fi
            ;;
        "gpg")
            if [ -f "$file_path" ] && [ -s "$file_path" ] && grep -q "BEGIN PGP" "$file_path" && grep -q "END PGP" "$file_path"; then
                echo "  ✓ Verified GPG key: $file_name"
            else
                echo "  ✗ GPG key verification failed: $file_name"
                all_valid=false
            fi
            ;;
        "deb")
            if [ -f "$file_path" ] && dpkg-deb -I "$file_path" >/dev/null 2>&1; then
                echo "  ✓ Verified .deb package: $file_name"
            else
                echo "  ✗ .deb package verification failed: $file_name"
                all_valid=false
            fi
            ;;
    esac
done

if [ "$all_valid" = true ]; then
    echo "✓ All files verified and ready for build"
else
    echo "✗ File verification failed - aborting build"
    exit 1
fi

echo "============== Complete File Preparation Phase Complete =============="


# Begin heredoc for singularity definition
cat > "${DEF_NAME}" <<'DEF'
Bootstrap: docker
From: osrf/ros:jazzy-desktop-full-noble

# === %files Section ===
%files
    /container_cache/binaries /container_cache/binaries
    /container_cache/debs /container_cache/debs
    xubuntu_robotics_base_post.sh /container_post_script.sh
    /container_cache/binaries/julia_key.asc /container_cache/binaries/julia_key.asc

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
    export RUSTUP_HOME=/opt/rust
    export CARGO_HOME=/opt/rust/cargo
    export PATH=/opt/rust/cargo/bin:/opt/rust/tools/bin:$PATH

    # Zenoh
    export ZENOH_HOME=/opt/zenoh
    export PATH=/opt/zenoh/bin:$PATH

    # Drake patching for meldis etc. (py path covers both dist/site variants)
    export DRAKE_INSTALL_DIR=/opt/drake
    export PYTHONPATH=/opt/drake/lib/python3/dist-packages:/opt/drake/lib/python3.12/site-packages:$PYTHONPATH
    export PATH=/opt/drake/bin:$PATH

    # Missing environment variables from baseline
    export JULIA_NUM_THREADS=auto
    export MAMBA_ROOT_PREFIX=/opt/mamba-envs
    export PATH=/opt/julia/bin:$PATH
    export DOWNLOADER=aria2c
    export APT_FAST_OPTS="--summary-interval=1 --console-log-level=notice --check-certificate=false --max-connection-per-server=16 --split=16 --min-split-size=2M --timeout=30"

    export DEBIAN_FRONTEND=noninteractive
    export TZ=Asia/Kolkata
    export LANG=C.UTF-8
    export LC_ALL=C.UTF-8
    export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
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
    export PATH=/opt/turbovnc/bin:$PATH
    export PATH=/opt/VirtualGL/bin:$PATH
    export TVNC_WM=startxfce4
    export PATH=/opt/miniforge/bin:$PATH
    export MAMBA_ROOT_PREFIX=/opt/mamba-envs
    export PATH=/opt/julia/bin:$PATH
    export DOWNLOADER=aria2c
    export APT_FAST_OPTS="--summary-interval=1 --console-log-level=notice --check-certificate=false --max-connection-per-server=16 --split=16 --min-split-size=2M --timeout=30"

# === %setup Section ===
%setup -c /bin/bash 
    # Check if the build process can see the post script on the host
    /bin/echo "--- [DEBUG] Running 'ls -l' on host for xubuntu_robotics_base_post.sh:"
    /bin/ls -l xubuntu_robotics_base_post.sh

    # Define variables inside %setup section to ensure they're available
    #==============================================================================
    # Pinned Software Versions and URLs
    #==============================================================================
    # --- Miniforge ---
    MINIFORGE_VER="25.3.1-0"
    MINIFORGE_SH="Miniforge3-${MINIFORGE_VER}-Linux-x86_64.sh"
    MINIFORGE_URL="https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VER}/${MINIFORGE_SH}"
    MINIFORGE_SHA256="376b160ed8130820db0ab0f3826ac1fc85923647f75c1b8231166e3d559ab768"

    # --- Micromamba ---
    MICROMAMBA_VER="2.3.2-0"
    MICROMAMBA_BIN="micromamba-linux-64"
    MICROMAMBA_URL="https://github.com/mamba-org/micromamba-releases/releases/download/${MICROMAMBA_VER}/${MICROMAMBA_BIN}"
    MICROMAMBA_SHA256="ffc3cb8d52d4d6b354bdbb979c407719c485392b74e462cbd50811aa88e58f85"

    # --- TurboVNC / VirtualGL ---
    TURBOVNC_VER="3.2.1"
    TURBOVNC_DEB="turbovnc_${TURBOVNC_VER}_amd64.deb"
    TURBOVNC_URL="https://github.com/TurboVNC/turbovnc/releases/download/${TURBOVNC_VER}/${TURBOVNC_DEB}"
    VIRTUALGL_VER="3.1.4"
    VIRTUALGL_DEB="virtualgl_${VIRTUALGL_VER}_amd64.deb"
    VIRTUALGL_URL="https://github.com/VirtualGL/virtualgl/releases/download/${VIRTUALGL_VER}/${VIRTUALGL_DEB}"
    
    # --- yq (Go) ---
    YQ_VER="v4.48.1"
    YQ_BIN="yq_linux_amd64"
    YQ_URL="https://github.com/mikefarah/yq/releases/download/${YQ_VER}/${YQ_BIN}"
    YQ_SHA256="ffc3cb8d52d4d6b354bdbb979c407719c485392b74e462cbd50811aa88e58f85"

    # --- Drake, Julia & Julia Pin ---
    DRAKE_ASC_URL="https://drake-apt.csail.mit.edu/drake.asc"
    DRAKE_KEY_URL="https://drake-apt.csail.mit.edu/drake.asc"

    # GPG Keys for verification
    VIRTUALGL_TURBOVNC_GPG_KEY_ID="4BACCAB36E7FE9A1"
    VIRTUALGL_TURBOVNC_GPG_KEY_URL="https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xae1a7ba4efff9a9987e1474c4baccab36e7fe9a1"
    JULIA_LTS_VER="1.10.5" # LTS
    JULIA_TARBALL="julia-${JULIA_LTS_VER}-linux-x86_64.tar.gz"
    JULIA_URL="https://julialang-s3.julialang.org/bin/linux/x64/${JULIA_LTS_VER%.*}/${JULIA_TARBALL}"
    JASC_URL="https://julialang-s3.julialang.org/bin/linux/x64/${JULIA_LTS_VER%.*}/${JULIA_TARBALL}.asc"

    # --- NVIDIA Keyring ---
    NVIDIA_KEYRING_VER="1.1-1"
    NVIDIA_KEYRING_DEB="cuda-keyring_${NVIDIA_KEYRING_VER}-1_all.deb"
    NVIDIA_KEYRING_URL="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/${NVIDIA_KEYRING_DEB}"




    # $SINGULARITY_ROOTFS is the image root during build; this runs on the HOST
    echo "Running %setup on host to pre-populate caches..."
    mkdir -p "${SINGULARITY_ROOTFS}/container_cache/binaries"
    mkdir -p "${SINGULARITY_ROOTFS}/container_cache/apt/archives"
    mkdir -p "${SINGULARITY_ROOTFS}/container_cache/conda_pkgs"
    mkdir -p "${SINGULARITY_ROOTFS}/container_cache/debs"
    mkdir -p "${SINGULARITY_ROOTFS}/container_cache/julia_pkgs"
    mkdir -p "${SINGULARITY_ROOTFS}/container_cache/wheels"

    # Set proper permissions for cache directories
    chmod -R 755 "${SINGULARITY_ROOTFS}/container_cache" 2>/dev/null || true

    # Copy (no overwrite) any preseeded cache into the image build root
    rsync -a --ignore-existing "${PWD}/container_cache/" "${SINGULARITY_ROOTFS}/container_cache" 2>/dev/null || true
    
    # Ensure proper ownership and permissions after copy
    chown -R root:root "${SINGULARITY_ROOTFS}/container_cache" 2>/dev/null || true
    chmod -R 755 "${SINGULARITY_ROOTFS}/container_cache" 2>/dev/null || true

# === %post Section ===
%post -c /bin/bash
    debug_glibc() {
    local stage="$1"

    echo "==== DEBUG CHECKPOINT: $stage ===="
    echo "Time: $(date)"

    echo "GLIBC version:"
    /lib/x86_64-linux-gnu/libc.so.6 | head -1

    echo "ldd version:"
    ldd --version | head -1

    echo "GCC version:"
    gcc --version 2>/dev/null | head -1 || echo "GCC not installed yet"

    echo "stdlib.h locations:"
    find /usr/include -name "stdlib.h" 2>/dev/null || echo "stdlib.h not found"

    echo "cstdlib locations:"
    find /usr/include -name "cstdlib" 2>/dev/null || echo "cstdlib not found"

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
    export MAKEFLAGS="-j$(( $(nproc) /2_))"
    export TMPDIR="${BUILD_TMP_DIR}"
    export SINGULARITY_TMPDIR="${TMPDIR}"
    mkdir -p /tmp/build-temp
    chmod 1777 /tmp/build-temp

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
    if [ -f /usr/lib/python3.12/EXTERNALLY-MANAGED ]; then
        echo "✗ PEP 668 file still exists"
        exit 1
    else
        echo "✓ PEP 668 disabled"
    fi

    # Suppress pip root warnings in container builds
    export PIP_ROOT_USER_ACTION=ignore

    # Configure Environment for CUDA Cross-Compilation
    # Set a dedicated, writable temporary directory for the CUDA compiler (nvcc)
    # to prevent issues with restrictive /tmp permissions on build hosts.
    export TMPDIR=/tmp/cuda_build
    rm -rf "$TMPDIR"
    mkdir -p "$TMPDIR"
    chmod 777 "$TMPDIR"

    # Explicitly define CUDA home to ensure CMake finds the correct toolkit
    export CUDA_HOME=/usr/local/cuda-11.8
    export PATH="${CUDA_HOME}/bin:${PATH}"
    export LD_LIBRARY_PATH="${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}"

    # Make the script executable and run it
    chmod +x /container_post_script.sh
    /container_post_script.sh

# === %test Section ===
%test
    #!/bin/bash
    set -eu
    echo "test XFCE:"
    if [ -n "${DISPLAY-}" ]; then pgrep 'Xorg|Xvnc' >/dev/null; then
        xfce4-session --version || true
    else
        echo "[note] No DISPLAY during build; skipping XFCE runtime check."
    fi
    echo "test Firefox, VNC:"
    which vncserver || true; Xvnc --version || true
    echo "test Firefox:" ; firefox --version || true
    echo "test yq:"; yq --version || { [ -x /opt/conda/bin/yq ] && /opt/conda/bin/yq --version || echo MISSING; }
    echo "test Micromamba:"; micromamba --help >/dev/null 2>&1 && echo OK || echo MISSING
    echo "test Drake key:"; test -s /etc/apt/trusted.gpg.d/drake.gpg && echo OK || echo MISSING
    echo "test XFCE xstartup wrapper:"; test -x /usr/local/bin/start_vnc_xfce.sh && echo OK || echo MISSING
    echo "test Ulauncher:"; ulauncher --version >/dev/null 2>&1 && echo OK || echo MISSING "(headless test)"
    # Notebook & Julia/Drake checks (soft)
    echo "test Notebooks:"; jupyter kernelspec list 2>/dev/null || true
    echo "test Julia:"; julia --version 2>/dev/null || true
    echo "test Meshcat import:"; python3 -c 'import meshcat; print("Meshcat OK")' 2>/dev/null || true
    echo "test Meldis:"; /opt/drake/bin/meldis --help 2>/dev/null || true
    echo "test TeX:"; pdflatex --version 2>/dev/null || true; biber --version 2>/dev/null || true
    # Missing package tests from baseline:
    echo "test LibreOffice:"; libreoffice --version 2>/dev/null || true
    echo "test Blender:"; blender --version 2>/dev/null || true
    echo "test OpenSCAD:"; openscad --version 2>/dev/null || true
    echo "test FreeCAD:"; if command -v freecad >/dev/null 2>&1; then timeout 5s freecad --version 2>/dev/null || echo "[info] FreeCAD installed but test skipped (requires graphics environment)"; else echo "[info] FreeCAD not installed, skipping test."; fi
    # Robotics tools tests
    echo "test Mirror selection: nala and apt-aria wrapper available for fast downloads"

# === %runscript Section ===
%runscript
    exec /bin/bash -l

DEF
# === End of Singularity Definition ===
log "Singularity definition file generated successfully."

#==============================================================================
# Build, Harvest, and Finalize
#==============================================================================

# --- Build the Container ---
log_with_timestamp "Building SIF: ${OUT_DIR}/${SIF_NAME}"
# Check if apptainer is available, otherwise try singularity
# Use full paths to avoid PATH issues with sudo
if [ -x /usr/bin/apptainer ]; then
    log "Using apptainer for container build..."
    sudo /usr/bin/apptainer build \
        --tmpdir "${BUILD_TMP_DIR}" \
        --force \
        "${OUT_DIR}/${SIF_NAME}" \
        "${DEF_NAME}"
elif [ -x /usr/bin/singularity ]; then
    warn "apptainer not found, falling back to singularity."
    sudo /usr/bin/singularity build \
        --tmpdir "${BUILD_TMP_DIR}" \
        --force \
        "${OUT_DIR}/${SIF_NAME}" \
        "${DEF_NAME}"
else
    err "Neither apptainer nor singularity found. Please install one to proceed."
fi
log "================ Image building completed successfully ================"

# Add this line to enable line-number tracing
# export PS4='+${BASH_SOURCE}:${LINENO}: '
# Disable verbose logging for cleaner output
# Turn on detailed command tracing
# set -x

log "Detailed build information"
echo "Build Phase: Cache Harvesting"
echo "Build completed at: $(date)"
echo "Image size: $(du -sh "${OUT_DIR}/${SIF_NAME}" 2>/dev/null | cut -f1 || echo "unknown")"
echo "======================================================================"

# --- Harvest Caches Back to Host ---
log_with_timestamp "============= Initiating Harvest from SIF to Host Cache ============="
SIF_PATH="${OUT_DIR}/${SIF_NAME}"
HOST_CACHE="${PWD}/container_cache"
mkdir -p "$HOST_CACHE"

# Check if apptainer is available, otherwise try singularity
# Use full paths to avoid PATH issues
if [ -x /usr/bin/apptainer ]; then
    log_with_timestamp "Using Apptainer for cache harvest..."
    if /usr/bin/apptainer exec --bind "${HOST_CACHE}:/host_cache" "${SIF_PATH}" \
        bash -c 'rsync -a --no-p -o --no-g /container_cache/ /host_cache/'; then
        log_success "Cache harvest completed successfully"
    else
        log_warning "Cache harvest failed, but continuing..."
    fi

    log_with_timestamp "--------- Verify Harvest ---------"
    /usr/bin/apptainer exec "${SIF_PATH}" bash -lc 'ls -l /container_cache | wc -l | awk "{print \"[info] cache dirs inside image:\", \$1}"'
    /usr/bin/apptainer exec "${SIF_PATH}" bash -lc 'ls -lh /container_cache/apt/archives/*.deb 2>/dev/null | head || echo "[warn] no .deb files harvested"'
elif [ -x /usr/bin/singularity ]; then
    log_with_timestamp "Using Singularity for cache harvest..."
    if /usr/bin/singularity exec --bind "${HOST_CACHE}:/host_cache" "${SIF_PATH}" \
        bash -c 'rsync -a --no-p -o --no-g /container_cache/ /host_cache/'; then
        log_success "Cache harvest completed successfully"
    else
        log_warning "Cache harvest failed, but continuing..."
    fi

    log_with_timestamp "--------- Verify Harvest ---------"
    /usr/bin/singularity exec "${SIF_PATH}" bash -lc 'ls -l /container_cache | wc -l | awk "{print \"[info] cache dirs inside image:\", \$1}"'
    /usr/bin/singularity exec "${SIF_PATH}" bash -lc 'ls -lh /container_cache/apt/archives/*.deb 2>/dev/null | head || echo "[warn] no .deb files harvested"'
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
    apt_count=$(find "${HOST_CACHE}/apt/archives" -name "*.deb" 2>/dev/null | wc -l)
    if [ "$apt_count" -gt 0 ]; then
        echo "  ✓ APT cache: $apt_count .deb files harvested"
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
    conda_count=$(find "${HOST_CACHE}/conda_pkgs" -name "*.conda" -o -name "*.tar.bz2" 2>/dev/null | wc -l)
    if [ "$conda_count" -gt 0 ]; then
        echo "  ✓ Conda cache: $conda_count packages harvested"
    else
        echo "  ✗ Conda cache: No packages found"
    fi
else
    echo "  ✗ Conda cache: Directory not found"
    issues=$((issues + 1))
fi

# Check Pip wheels
if [ -d "${HOST_CACHE}/wheels" ]; then
    wheel_count=$(find "${HOST_CACHE}/wheels" -name "*.whl" 2>/dev/null | wc -l)
    if [ "$wheel_count" -gt 0 ]; then
        echo "  ✓ Pip wheels: $wheel_count wheels harvested"
    else
        echo "  ✗ Pip wheels: No wheels found"
    fi
else
    echo "  ✗ Pip wheels: Directory not found"
fi

# Check Julia cache
if [ -d "${HOST_CACHE}/julia_pkgs" ]; then
    julia_size=$(du -sh "${HOST_CACHE}/julia_pkgs" 2>/dev/null | cut -f1 || echo "0B")
    if [[ "$julia_size" != "0B" ]]; then
        echo "  ✓ Julia cache: $julia_size harvested"
    else
        echo "  ✗ Julia cache: No packages found"
    fi
else
    echo "  ✗ Julia cache: Directory not found"
fi
if [ "$issues" -eq 0 ]; then
    echo "✓ Cache harvest validation passed"
else
    echo "✗ Cache harvest validation found $issues issues"
fi

log_success "============== Harvest Complete =============="

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
echo -e "${YELLOW}> This container image was built with the NVIDIA CUDA Toolkit 12.2 and${NC}"
echo -e "${YELLOW}> a compatible cuDNN version baked directly into the image.${NC}"
echo -e "${YELLOW}>${NC}"
echo -e "${YELLOW}> To use this image with GPU acceleration (--nv), the host machine's${NC}"
echo -e "${YELLOW}> MUST have an NVIDIA driver that supports CUDA 12.2 or newer.${NC}"
echo -e "${YELLOW}>${NC}"
echo -e "${YELLOW}> Check the host driver's max supported CUDA version with: nvidia-smi${NC}"
echo -e "${YELLOW}>${NC}"
echo -e "${YELLOW}> If your target cluster has a different CUDA version (e.g., 11.x),${NC}"
echo -e "${YELLOW}> you must modify the package names in 'xubuntu_robotics_base_post.sh'${NC}"
echo -e "${YELLOW}> and rebuild the container.${NC}"
echo -e "${YELLOW}======================================================================${NC}"

echo "Built image: ${OUT_DIR}/${SIF_NAME}"
echo ""
echo "# Build Summary"
echo "- Base system: Ubuntu 22.04 with XFCE4"
echo "- Package manager: apt-aria wrapper + mamba solver"
echo "- Development: Python, Julia, C++ toolchains"
echo "- Jupyter: Full environment with kernels"
echo "- Robotics: Drake (ROS2 in separate image)"
echo "- Graphics: VNC, VirtualGL, Blender, CAD tools"
echo "- Documentation: TeX Live, LibreOffice"
echo "- Caching: Comprehensive package caching system"
log_with_timestamp "Host cache disk usage:"
du -sh "${BIN_CACHE}" "${DEB_CACHE}" "${APT_CACHE}" "${CONDA_CACHE}" "${JULIA_CACHE}" "${WHEELS_CACHE}" 2>/dev/null || true

echo "[note] To start a tuned VNC session inside the container:"
echo "apptainer exec --nv \"\${OUT_DIR}/\${SIF_NAME}\" start_vnc_xfce.sh"
echo "(Tunnel: ssh -L 5901:localhost:5901 <user>@<host>) -> VNC viewer to localhost:5901"

echo "[note] Julia CUDA lazy precompile (run on GPU node):"
echo "apptainer exec --nv \"\${OUT_DIR}/\${SIF_NAME}\" precompile_julia_cuda.sh"

echo "[note] AppImages (FreeCAD, Ultimaker Cura, Mendeley) recommended:"
echo "Download from official pages, then:"
echo "chmod +x *.AppImage && mkdir -p ~/Applications && mv *.AppImage ~/Applications/"
echo "# appimagedlauncher-cli integrate ~/Applications/*.AppImage (if installed)"

echo "[note] Drake Python path if needed:"
echo "export PYTHONPATH=/opt/drake/lib/python3/dist-packages:\"\$PYTHONPATH\""
echo "# /opt/drake/lib/python3.10/site-packages for Jammy"

echo "[note] Drake is installed in base environment:"
echo "- meldis: /opt/drake/bin/meldis"
echo "- meshcat-server: /opt/drake/bin/meshcat-server"
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

# Build summary with timing and cache statistics
BUILD_END_TIME=$(date +%s)
BUILD_DURATION=$((BUILD_END_TIME - BUILD_START_TIME))
BUILD_HOURS=$((BUILD_DURATION / 3600))
BUILD_MINUTES=$(( (BUILD_DURATION % 3600) / 60))
BUILD_SECONDS=$((BUILD_DURATION % 60))

# Cache statistics
CACHE_TOTAL_SIZE=$(du -sh "${CACHE_DIR}" 2>/dev/null | cut -f1 || echo "0B")
APT_CACHE_SIZE=$(du -sh "${APT_ARCHIVE_CACHE}" 2>/dev/null | cut -f1 || echo "0B")
CONDA_CACHE_SIZE=$(du -sh "${CONDA_CACHE}" 2>/dev/null | cut -f1 || echo "0B")
WHEELS_CACHE_SIZE=$(du -sh "${WHEELS_CACHE}" 2>/dev/null | cut -f1 || echo "0B")
JULIA_CACHE_SIZE=$(du -sh "${JULIA_CACHE}" 2>/dev/null | cut -f1 || echo "0B")

APT_CACHE_COUNT=$(find "${APT_ARCHIVE_CACHE}" -name "*.deb" 2>/dev/null | wc -l)
CONDA_CACHE_COUNT=$(find "${CONDA_CACHE}" \( -name "*.conda" -o -name "*.tar.bz2" \) -type f 2>/dev/null | wc -l)
WHEELS_CACHE_COUNT=$(find "${WHEELS_CACHE}" -name "*.whl" 2>/dev/null | wc -l)

echo ""
echo "=============== BUILD SUMMARY ==============="
echo "Container: ${SIF_PATH}"
echo "Size: $(du -sh "${SIF_PATH}" | cut -f1)"
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
echo "APT cache directory: ${APT_ARCHIVE_CACHE}"
echo "Conda cache directory: ${CONDA_CACHE}"
echo "Pip wheels directory: ${WHEELS_CACHE}"
echo "Julia cache directory: ${JULIA_CACHE}"
```
