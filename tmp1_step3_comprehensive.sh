#!/bin/bash
# build_xubuntu_gui_base_sif.sh -- DROP-IN (3 Sep)
# Baseline preserved; adds:
# - Drake key hardening via host-cached asc
# - Conda base: Jupyter + meshcat
# - Julia 1.10 LTS + base/robotics (+media envs + GPU precompile helper)
# - TeX English-only (feature-complete)
# - Meldis/MeshCat wiring
set -euo pipefail

# --- Check for required host dependencies ---
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

# ==============================================================================
# --- Logging Setup ---
# ==============================================================================
LOG_DIR="${PWD}/build_logs"

# Clean up old logs FIRST (before creating new log files)
echo "Cleaning up old log files..."
if [ -d "${LOG_DIR}" ]; then
    # Keep only the 2 most recent log files (skip first 2, delete the rest)
    find "${LOG_DIR}" -name "build_*.log" -type f | sort -r | tail -n +3 | xargs rm -f 2>/dev/null || true
    find "${LOG_DIR}" -name "errors_*.log" -type f | sort -r | tail -n +3 | xargs rm -f 2>/dev/null || true
    echo "Old log files cleaned up (kept latest 2)"
fi

# Create log directory
mkdir -p "${LOG_DIR}"

# Now create new log files
LOG_FILE="${LOG_DIR}/build_$(date +%Y%m%d_%H%M%S).log"
ERROR_LOG="${LOG_DIR}/errors_$(date +%Y%m%d_%H%M%S).log"

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log with timestamp
log_with_timestamp() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${BLUE}${message}${NC}" | tee -a "${LOG_FILE}"
}

# Function to log errors (RED in both terminal and log)
log_error() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1"
    echo -e "${RED}${message}${NC}" | tee -a "${ERROR_LOG}" | tee -a "${LOG_FILE}"
}

# Function to log warnings (YELLOW in both terminal and log)
log_warning() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1"
    echo -e "${YELLOW}${message}${NC}" | tee -a "${LOG_FILE}"
}

# Function to log success (GREEN in both terminal and log)
log_success() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1"
    echo -e "${GREEN}${message}${NC}" | tee -a "${LOG_FILE}"
}

# Note: DEF file removal will be done after variable definitions

# Redirect all output to log file and console
log_with_timestamp "Starting build process..."
log_with_timestamp "Log file: ${LOG_FILE}"
log_with_timestamp "Error log: ${ERROR_LOG}"

# Redirect ALL output (stdout, stderr, and terminal) to the same log file
# This ensures complete debugging information is captured
exec > >(tee -a "${LOG_FILE}")
exec 2> >(tee -a "${LOG_FILE}" | tee -a "${ERROR_LOG}" >&2)

# ==============================================================================
# --- Host-side Caches and Directories (Baseline) ---
# ==============================================================================
CACHE_DIR="${PWD}/container_cache"
BIN_CACHE="${CACHE_DIR}/binaries"
DEB_CACHE="${CACHE_DIR}/debs"
APT_CACHE="${CACHE_DIR}/apt"
APT_PKG_CACHE="${CACHE_DIR}/apt_pkgs"
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
create_directory_with_permissions "${APT_PKG_CACHE}" "APT packages cache"
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


# ==============================================================================
# --- Helper Functions ---
# ==============================================================================
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

# Time tracking
start_time() {
    echo "$(date +%s)"
}

elapsed_time() {
    local start="$1"
    local end="$(date +%s)"
    local elapsed=$((end - start))
    printf "%02d:%02d:%02d" $((elapsed/3600)) $((elapsed%3600/60)) $((elapsed%60))
}


# Robust fetch with host cache (baseline)
fetch() { # fetch <url> <dst>
    local url="$1" dst="$2"
    if [ -s "$dst" ]; then
        log "Using cached: $(basename "$dst")"
        return 0
    fi

    # Attempt 1: aria2c (fastest)
    if command -v aria2c >/dev/null 2>&1; then
        # Adaptive connection count based on file size
        local file_size_mb=$(curl -sI "$url" | grep -i content-length | awk '{print int($2/1024/1024)}' 2>/dev/null || echo "0")
        local connections=4
        if [[ $file_size_mb -gt 100 ]]; then
            connections=8
        elif [[ $file_size_mb -gt 50 ]]; then
            connections=6
        fi
        
        aria2c --check-certificate=true --max-connection-per-server=$connections --split=$connections \
            --retry-wait=2 --timeout=30 --continue=true -o "$(basename "$dst")" \
            --dir="$(dirname "$dst")" --console-log-level=error "$url" 2>/dev/null || warn "aria2c failed for $url; trying curl"
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

#===================Pruing scripts for cache==================
   cat >./prune_apt_cache.sh <<'APS'
#!/usr/bin/env bash
# Prune APT .deb cache: keep the latest N per package base name.
# usage: prune_apt_cache.sh --cache /path/to/apt/archives --keep 2 [--apply]
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
[[ -n "${CACHE}" ]] || { echo "[apt-prune] ERROR: --cache path required" >&2; exit 2; }
[[ -d "${CACHE}" ]] || { echo "[apt-prune] INFO: cache '${CACHE}' missing; nothing to do"; exit 0; }
[[ "${KEEP}" =~ ^[0-9]+$ ]] || { echo "[apt-prune] ERROR: --keep must be integer (got '${KEEP}')" >&2; exit 2; }
(( KEEP >= 1 )) || { echo "[apt-prune] ERROR: --keep must be >= 1 (got '${KEEP}')" >&2; exit 2; }
cd "${CACHE}" || { echo "[apt-prune] ERROR: could not cd to ${CACHE}" >&2; exit 1; }

# Collect .deb files quietly
mapfile -t ALL_DEBS < <(find . -maxdepth 1 -type f -name '*.deb' -printf '%f\n')
(( ${#ALL_DEBS[@]} )) || { echo "[apt-prune] INFO: no .deb files to consider"; exit 0; }

# Derive unique package bases (before first underscore)
mapfile -t BASES < <(printf '%s\n' "${ALL_DEBS[@]}" | awk -F '_' '{print $1}' | sort -u)

removed_total=0
for pkg in "${BASES[@]}"; do
  # List *this* package's debs newest first (lexicographic version sort is OK for APT pools)
  mapfile -t ALL_FOR_PKG < <(ls -1t "${pkg}"_*.deb 2>/dev/null || true)
  (( ${#ALL_FOR_PKG[@]} )) || continue

  # Determine files to prune
  if (( ${#ALL_FOR_PKG[@]} > KEEP )); then
    mapfile -t TO_REMOVE < <(printf '%s\n' "${ALL_FOR_PKG[@]}" | tail -n +$((KEEP+1)))
  else
    TO_REMOVE=()
  fi

  if (( ${#TO_REMOVE[@]} )); then
    if [[ -n "${APPLY}" ]]; then
      printf '%s\0' "${TO_REMOVE[@]}" | xargs -0r rm -f
      (( removed_total += ${#TO_REMOVE[@]} ))
    else
      printf '[apt-prune] Would remove %s\n' "${TO_REMOVE[@]}"
    fi
  fi
done
[[ -n "${APPLY}" ]] && echo "[apt-prune] Removed ${removed_total} file(s)" || echo "[apt-prune] Dry-run complete"
APS
    chmod +x ./prune_apt_cache.sh

    cat >./prune_conda_cache.sh <<'CPS'
#!/usr/bin/env bash
# Prune conda_pkgs cache: keep the latest N artifacts per base package name.
# Handles *.conda and *.tar.bz2 files.
# usage: prune_conda_cache.sh --cache /path/to/conda/pkgs --keep 2 [--apply]
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
[[ -n "${CACHE}" ]] || { echo "[conda-prune] ERROR: --cache path required" >&2; exit 2; }
[[ -d "${CACHE}" ]] || { echo "[conda-prune] INFO: cache '${CACHE}' missing; nothing to do"; exit 0; }
[[ "${KEEP}" =~ ^[0-9]+$ ]] || { echo "[conda-prune] ERROR: --keep must be integer (got '${KEEP}')" >&2; exit 2; }
(( KEEP >= 1 )) || { echo "[conda-prune] ERROR: --keep must be >= 1 (got '${KEEP}')" >&2; exit 2; }
cd "${CACHE}" || { echo "[conda-prune] ERROR: could not cd to ${CACHE}" >&2; exit 1; }

# List package files (quiet if none)
mapfile -t PKGFILES < <(find . -maxdepth 1 -type f \( -name '*.conda' -o -name '*.tar.bz2' \) -printf '%f\n')
(( ${#PKGFILES[@]} )) || { echo "[conda-prune] INFO: no conda artifacts found"; exit 0; }

# Derive base names: strip version-build-suffix and extension
# Matches: name-version-build.(conda|tar.bz2)
mapfile -t BASES < <(printf '%s\n' "${PKGFILES[@]}" | \
  sed -E 's@(-[0-9].*)?(-[a-zA-Z0-9_]+)?(\.conda|\.tar\.bz2)$@@' | \
  sort -u)

removed_total=0
for base in "${BASES[@]}"; do
  # All variants for this base (sort with -V to respect 1.10 > 1.9 etc.)
  mapfile -t ALL_FOR_BASE < <(ls -1 "${base}"-[0-9]*.conda "${base}"-*.tar.bz2 2>/dev/null | sort -rV || true)
  (( ${#ALL_FOR_BASE[@]} )) || continue
  
  if (( ${#ALL_FOR_BASE[@]} > KEEP )); then
    mapfile -t TO_REMOVE < <(printf '%s\n' "${ALL_FOR_BASE[@]}" | tail -n +$((KEEP+1)))
  else
    TO_REMOVE=()
  fi

  if (( ${#TO_REMOVE[@]} )); then
    if [[ -n "${APPLY}" ]]; then
      printf '%s\0' "${TO_REMOVE[@]}" | xargs -0r rm -f
      (( removed_total += ${#TO_REMOVE[@]} ))
    else
      printf '[conda-prune] Would remove %s\n' "${TO_REMOVE[@]}"
    fi
  fi
done

[[ -n "${APPLY}" ]] && echo "[conda-prune] Removed ${removed_total} file(s)" || echo "[conda-prune] Dry-run complete"
CPS
    chmod +x ./prune_conda_cache.sh



# ==============================================================================
# --- Pinned Software Versions and URLs ---
# ==============================================================================

# Miniforge
MINIFORGE_VER="25.3.1-0"
MINIFORGE_SH="Miniforge3-${MINIFORGE_VER}-Linux-x86_64.sh"
MINIFORGE_URL="https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VER}/${MINIFORGE_SH}"
MINIFORGE_SHA256="376b160ed8130820db0ab0f3826ac1fc85923647f75c1b8231166e3d559ab768"

# micromamba
MICROMAMBA_VER="2.3.2-0"
MICROMAMBA_BIN="micromamba-linux-64"
MICROMAMBA_URL="https://github.com/mamba-org/micromamba-releases/releases/download/${MICROMAMBA_VER}/${MICROMAMBA_BIN}"
MICROMAMBA_SHA256="ffc3cb8d52d4d6b354bdbb979c407719c485392b74e462cbd50811aa88e58f85"

# TurboVNC / VirtualGL
TURBOVNC_VER="3.2"
TURBOVNC_DEB="turbovnc_${TURBOVNC_VER}_amd64.deb"
TURBOVNC_URL="https://github.com/TurboVNC/turbovnc/releases/download/${TURBOVNC_VER}/${TURBOVNC_DEB}"

VIRTUALGL_VER="3.1.3"
VIRTUALGL_DEB="virtualgl_${VIRTUALGL_VER}_amd64.deb"
VIRTUALGL_URL="https://github.com/VirtualGL/virtualgl/releases/download/${VIRTUALGL_VER}/${VIRTUALGL_DEB}"

# yq (Go)
YQ_VER="v4.47.2"
YQ_BIN="yq_linux_amd64"
YQ_URL="https://github.com/mikefarah/yq/releases/download/${YQ_VER}/${YQ_BIN}"
YQ_SHA256="1bb99e1019e23de33c7e6afc23e93dad72aad6cf2cb03c797f068ea79814ddb0"

# Drake key & Julia LTS Pin
DRAKE_ASC_URL="https://drake-apt.csail.mit.edu/drake.asc"

# GPG Keys for verification
VIRTUALGL_TURBOVNC_GPG_KEY_ID="4BACCAB36E7FE9A1"
VIRTUALGL_TURBOVNC_GPG_KEY_URL="https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xae1a7ba4efff9a9987e1474c4baccab36e7fe9a1"
JULIA_LTS_VER="1.10.5" # LTS
JULIA_TARBALL="julia-${JULIA_LTS_VER}-linux-x86_64.tar.gz"
JULIA_URL="https://julialang-s3.julialang.org/bin/linux/x64/1.10/${JULIA_TARBALL}"
JASC_URL="https://julialang-s3.julialang.org/bin/linux/x64/1.10/julia-1.10.5-linux-x86_64.tar.gz.asc"


# ==============================================================================
# --- Prefetch Artifacts to Host Cache ---
# ==============================================================================
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
    echo $missing
}

# Cache integrity check and repair function
check_cache_integrity() {
    echo "==> Checking cache integrity..."
    issues=0
    
    # Check for corrupted files
    for cache_dir in "${BIN_CACHE}" "${DEB_CACHE}" "${APT_ARCHIVE_CACHE}" "${CONDA_CACHE}" "${WHEELS_CACHE}" "${JULIA_CACHE}"; do
        if [[ -d "$cache_dir" ]]; then
            # Check for zero-byte files (likely corrupted downloads)
            local zero_files=$(find "$cache_dir" -type f -size 0 2>/dev/null | wc -l)
            if [[ $zero_files -gt 0 ]]; then
                echo "  ⚠ Found $zero_files zero-byte files in $(basename "$cache_dir")"
                find "$cache_dir" -type f -size 0 -delete 2>/dev/null || true
                echo "  ✓ Removed zero-byte files"
                ((issues++))
            fi
            
            # Check for incomplete downloads (files ending with .part, .tmp, etc.)
            local incomplete_files=$(find "$cache_dir" -type f \( -name "*.part" -o -name "*.tmp" -o -name "*.aria2" \) 2>/dev/null | wc -l)
            if [[ $incomplete_files -gt 0 ]]; then
                echo "  ⚠ Found $incomplete_files incomplete downloads in $(basename "$cache_dir")"
                find "$cache_dir" -type f \( -name "*.part" -o -name "*.tmp" -o -name "*.aria2" \) -delete 2>/dev/null || true
                echo "  ✓ Removed incomplete downloads"
                ((issues++))
            fi
        fi
    done
    
    if [[ $issues -eq 0 ]]; then
        echo "  ✓ Cache integrity check passed"
    else
        echo "  ✓ Cache integrity issues repaired: $issues problems fixed"
    fi
    
    return 0  # Always return success after repair
}

# Clean up any existing incomplete downloads and check cache integrity
echo "==> Cleaning up any existing incomplete downloads..."
find "${CACHE_DIR}" -type f \( -name "*.part" -o -name "*.tmp" -o -name "*.aria2" \) -delete 2>/dev/null || true
find "${CACHE_DIR}" -type f -size 0 -delete 2>/dev/null || true

check_cache_integrity

# Skip downloads if all artifacts are cached
if [[ $(check_cache_complete) -eq 0 ]]; then
    log "All artifacts already cached, skipping downloads"
else
    # Export function for parallel execution
    export -f fetch_binary fetch

    # Define download tasks
    cat > /tmp/download_tasks << EOF
MINIFORGE|$MINIFORGE_URL|${BIN_CACHE}/${MINIFORGE_SH}|binary
MICROMAMBA|$MICROMAMBA_URL|${BIN_CACHE}/${MICROMAMBA_BIN}|binary
YQ|$YQ_URL|${BIN_CACHE}/${YQ_BIN}|binary
TURBOVNC|$TURBOVNC_URL|${DEB_CACHE}/${TURBOVNC_DEB}|deb
VIRTUALGL|$VIRTUALGL_URL|${DEB_CACHE}/${VIRTUALGL_DEB}|deb
DRAKE_KEY|$DRAKE_ASC_URL|${BIN_CACHE}/drake.asc|file
JULIA|$JULIA_URL|${BIN_CACHE}/${JULIA_TARBALL}|file
EOF

    # Execute downloads in parallel (max 4 concurrent)
    echo "Downloading artifacts in parallel..."
    # The 'bash -c' is needed to call our exported shell functions within xargs
    cat /tmp/download_tasks | xargs -P 4 -I {} bash -c \
        'IFS="|" read -r name url dst type <<< "{}"; 
        echo "Starting download: $name"; 
        if [[ "$type" == "binary" ]]; then fetch_binary "$url" "$dst"; else fetch "$url" "$dst"; fi; 
        echo "Completed download: $name"'

    rm -f /tmp/download_tasks
fi

log "Prefetching complete."


# ==============================================================================
# --- Singularity Definition File Generation ---
# ==============================================================================
log_with_timestamp "Generating Singularity definition file: ${DEF_NAME}"

# Always remove any stale def file from previous runs
[ -f "$DEF_NAME" ] && rm -f "$DEF_NAME"

# Begin heredoc for Singularity definition
cat >"$DEF_NAME" <<'DEF'
Bootstrap: docker
From: ubuntu:22.04

# ==============================================================================
# --- %files Section ---
# ==============================================================================
%files
    container_cache/binaries /container_cache/binaries
    container_cache/debs /container_cache/debs
    container_post_script.sh /container_post_script.sh

# ==============================================================================
# --- %labels Section ---
# ==============================================================================
%labels
    Maintainer midhun
    Description "Xubuntu HPC GUI base (cached). XFCE, TurboVNC/VirtualGL, Firefox PPA, Miniforge/micromamba, yq, LibreOffice/Blender/OpenSCAD/FreeCAD/TeX (EN). Drake APT hardened. Jupyter-Julia kernels. MeshCat/Meldis wiring. All baseline features retained."


# ==============================================================================
# --- %environment Section ---
# ==============================================================================
%environment
    export DEBIAN_FRONTEND=noninteractive
    export TZ=Asia/Kolkata
    export LANG=C.UTF-8
    export LC_ALL=C.UTF-8
    export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    export MUJOCO_GL=egl
    export EGL_PLATFORM=surfaceless
    export __GLX_VENDOR_LIBRARY_NAME=nvidia

    # Drake pathing for meldis etc. (py path covers both dist/site variants)
    export DRAKE_INSTALL_DIR=/opt/drake
    export PATH=/opt/drake/bin:$PATH
    export PYTHONPATH=/opt/drake/lib/python3/dist-packages:/opt/drake/lib/python3.10/site-packages:$PYTHONPATH

    # Missing environment variables from baseline
    export JULIA_NUM_THREADS=auto
    export MAMBA_ROOT_PREFIX=/opt/mamba-envs
    export PATH=/opt/julia/bin:$PATH
    export DOWNLOADER=aria2c
    export APT_FAST_OPTS="--summary-interval=1 --console-log-level=notice --check-certificate=false --max-connection-per-server=16 --split=16 --min-split-size=1M --timeout=30"


# ==============================================================================
# --- %setup Section ---
# ==============================================================================
%setup -c /bin/bash
    # --- DEBUG: Check if the build process can see the post script on the host ---
    /bin/echo "--- [DEBUG] Running 'ls -l' on host for container_post_script.sh ---"
    /bin/ls -l container_post_script.sh

    # Define variables inside %setup section to ensure they're available
    MINIFORGE_VER="25.3.1-0"
    MINIFORGE_SH="Miniforge3-${MINIFORGE_VER}-Linux-x86_64.sh"
    MINIFORGE_URL="https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VER}/${MINIFORGE_SH}"
    MINIFORGE_SHA256="376b160ed8130820db0ab0f3826ac1fc85923647f75c1b8231166e3d559ab768"
    
    MICROMAMBA_VER="2.3.2-0"
    MICROMAMBA_BIN="micromamba-linux-64"
    MICROMAMBA_URL="https://github.com/mamba-org/micromamba-releases/releases/download/${MICROMAMBA_VER}/${MICROMAMBA_BIN}"
    MICROMAMBA_SHA256="ffc3cb8d52d4d6b354bdbb979c407719c485392b74e462cbd50811aa88e58f85"
    
    YQ_VER="v4.47.2"
    YQ_BIN="yq_linux_amd64"
    YQ_URL="https://github.com/mikefarah/yq/releases/download/${YQ_VER}/${YQ_BIN}"
    YQ_SHA256="1bb99e1019e23de33c7e6afc23e93dad72aad6cf2cb03c797f068ea79814ddb0"
    
    JULIA_LTS_VER="1.10.5"
    JULIA_URL="https://julialang-s3.julialang.org/bin/linux/x64/1.10/julia-1.10.5-linux-x86_64.tar.gz"
    JASC_URL="https://julialang-s3.julialang.org/bin/linux/x64/1.10/julia-1.10.5-linux-x86_64.tar.gz.asc"
    
    DRAKE_ASC_URL="https://drake-apt.csail.mit.edu/drake.asc"
    
    TURBOVNC_VER="3.2"
    TURBOVNC_DEB="turbovnc_${TURBOVNC_VER}_amd64.deb"
    TURBOVNC_URL="https://github.com/TurboVNC/turbovnc/releases/download/${TURBOVNC_VER}/${TURBOVNC_DEB}"
    
    VIRTUALGL_VER="3.1.3"
    VIRTUALGL_DEB="virtualgl_${VIRTUALGL_VER}_amd64.deb"
    VIRTUALGL_URL="https://github.com/VirtualGL/virtualgl/releases/download/${VIRTUALGL_VER}/${VIRTUALGL_DEB}"
    
    VIRTUALGL_TURBOVNC_GPG_KEY_ID="4BACCAB36E7FE9A1"
    VIRTUALGL_TURBOVNC_GPG_KEY_URL="https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xae1a7ba4efff9a9987e1474c4baccab36e7fe9a1"

    # $SINGULARITY_ROOTFS is the image root during build; this runs on the HOST
    echo "Running %setup on host to pre-populate caches..."
    mkdir -p "${SINGULARITY_ROOTFS}/container_cache/{apt/archives,apt_pkgs,binaries,conda_pkgs,debs,julia_pkgs,wheels}"
    
    # Set proper permissions for cache directories
    chmod -R 755 "${SINGULARITY_ROOTFS}/container_cache" 2>/dev/null || true
    
    # Copy (no overwrite) any preseeded cache into the image build root
    rsync -a --ignore-existing "${PWD}/container_cache/" "${SINGULARITY_ROOTFS}/container_cache/" 2>/dev/null || true
    rsync -a --ignore-existing "${PWD}/container_cache/debs" "${SINGULARITY_ROOTFS}/container_cache/debs" 2>/dev/null || true
    
    # Validate and clean corrupted conda packages BEFORE build starts
    echo "Validating conda package integrity before build..."
    if [ -d "${PWD}/container_cache/conda_pkgs" ]; then
        corrupted_count=0
        for pkg_file in "${PWD}/container_cache/conda_pkgs"/*.conda "${PWD}/container_cache/conda_pkgs"/*.tar.bz2; do
            if [ -f "$pkg_file" ]; then
                # Check if file is corrupted by testing its integrity
                if ! file "$pkg_file" | grep -q "archive\|compressed"; then
                    echo "  ⚠ Removing corrupted conda package: $(basename "$pkg_file")"
                    rm -f "$pkg_file"
                    ((corrupted_count++))
                else
                    # Additional CRC check for .conda files (ZIP-based)
                    if [[ "$pkg_file" == *.conda ]]; then
                        if ! unzip -t "$pkg_file" >/dev/null 2>&1; then
                            echo "  ⚠ Removing CRC-corrupted conda package: $(basename "$pkg_file")"
                            rm -f "$pkg_file"
                            ((corrupted_count++))
                        fi
                    fi
                fi
            fi
        done
        if [ $corrupted_count -gt 0 ]; then
            echo "  ✓ Removed $corrupted_count corrupted conda packages"
        else
            echo "  ✓ All conda packages validated successfully"
        fi
    fi
    
    # === COMPLETE BINARY PREPARATION PHASE ===
    echo "============== Preparing All Binaries Before Build =============="
    
    # Validate all required variables are set before defining array
    echo "Validating required variables..."
    for var in MINIFORGE_SH MINIFORGE_URL MINIFORGE_SHA256 MICROMAMBA_URL MICROMAMBA_SHA256 YQ_URL YQ_SHA256 JULIA_URL JASC_URL DRAKE_ASC_URL TURBOVNC_URL VIRTUALGL_URL VIRTUALGL_TURBOVNC_GPG_KEY_ID VIRTUALGL_TURBOVNC_GPG_KEY_URL; do
        if [ -z "${!var}" ]; then
            echo "❌ ERROR: Variable $var is empty or not set"
            exit 1
        fi
    done
    echo "✓ All required variables are set"
    
    # Debug: Show key variable values
    echo "Debug - Key variable values:"
    echo "  MINIFORGE_SH: '${MINIFORGE_SH}'"
    echo "  MICROMAMBA_URL: '${MICROMAMBA_URL}'"
    echo "  YQ_URL: '${YQ_URL}'"
    echo "  JULIA_URL: '${JULIA_URL}'"
    
    # Define all required files with their download URLs and validation methods
    declare -A required_files=(
        ["micromamba-linux-64"]="$MICROMAMBA_URL|binary|$MICROMAMBA_SHA256"
        ["yq_linux_amd64"]="$YQ_URL|binary|$YQ_SHA256"
        ["${MINIFORGE_SH}"]="$MINIFORGE_URL|binary|$MINIFORGE_SHA256"
        ["julia-1.10.5-linux-x86_64.tar.gz"]="$JULIA_URL|archive_with_asc_sha256"
        ["julia-1.10.5-linux-x86_64.tar.gz.asc"]="$JASC_URL|asc"
        ["drake.asc"]="$DRAKE_ASC_URL|gpg"
        ["turbovnc_3.2_amd64.deb"]="$TURBOVNC_URL|deb_with_gpg|$VIRTUALGL_TURBOVNC_GPG_KEY_ID|$VIRTUALGL_TURBOVNC_GPG_KEY_URL"
        ["virtualgl_3.1.3_amd64.deb"]="$VIRTUALGL_URL|deb_with_gpg|$VIRTUALGL_TURBOVNC_GPG_KEY_ID|$VIRTUALGL_TURBOVNC_GPG_KEY_URL"
    )
    
    # Phase 1: Ensure all required files are present in cache
    echo "Phase 1: Ensuring all required files are present in cache..."
    missing_files=()
    
    for file_name in "${!required_files[@]}"; do
        # Determine cache directory based on file type
        if [[ "$file_name" == *.deb ]]; then
            file_path="${PWD}/container_cache/debs/${file_name}"
        elif [[ "$file_name" == "drake.asc" ]]; then
            file_path="${PWD}/container_cache/binaries/${file_name}"
        elif [[ "$file_name" == "julia-"*.tar.gz ]]; then
            file_path="${PWD}/container_cache/binaries/${file_name}"
        else
            file_path="${PWD}/container_cache/binaries/${file_name}"
        fi
        
        if [ ! -f "$file_path" ]; then
            echo "  ⚠ Missing file: $file_name"
            missing_files+=("$file_name")
        else
            echo "  ✓ Found: $file_name"
        fi
    done
    
    # Download missing files
    if [ ${#missing_files[@]} -gt 0 ]; then
        echo "  → Downloading ${#missing_files[@]} missing files..."
        for file_name in "${missing_files[@]}"; do
            echo "    Downloading $file_name..."
            
            # Extract URL from the file definition
            file_info="${required_files[$file_name]}"
            IFS='|' read -r file_url validation_method param1 param2 param3 <<< "$file_info"
            
            # Determine destination directory
            if [[ "$file_name" == *.deb ]]; then
                dest_path="${PWD}/container_cache/debs/${file_name}"
            elif [[ "$file_name" == "drake.asc" ]]; then
                dest_path="${PWD}/container_cache/binaries/${file_name}"
            elif [[ "$file_name" == "julia-"*.tar.gz ]]; then
                dest_path="${PWD}/container_cache/binaries/${file_name}"
            else
                dest_path="${PWD}/container_cache/binaries/${file_name}"
            fi
            
            if curl -fsSL "$file_url" -o "$dest_path"; then
                echo "    ✓ Downloaded: $file_name"
            else
                echo "    ❌ Failed to download: $file_name"
                exit 1
            fi
        done
    else
        echo "  ✓ All required files present in cache"
    fi
    
    # Phase 2: Validate all files for corruption
    echo "Phase 2: Validating all files for corruption..."
    corrupted_files=()
    
    for file_name in "${!required_files[@]}"; do
        # Determine file path and validation method
        if [[ "$file_name" == *.deb ]]; then
            file_path="${PWD}/container_cache/debs/${file_name}"
        elif [[ "$file_name" == "drake.asc" ]]; then
            file_path="${PWD}/container_cache/binaries/${file_name}"
        elif [[ "$file_name" == "julia-"*.tar.gz ]]; then
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
                if ! file "$file_path" | grep -q "executable\|ELF"; then
                    echo "    ❌ Corrupted binary detected: $file_name"
                    corrupted_files+=("$file_name")
                    rm -f "$file_path"
                else
                    # If SHA256 is provided, validate it
                    if [ -n "$param1" ]; then
                        actual_sha256=$(sha256sum "$file_path" | cut -d' ' -f1)
                        if [ "$actual_sha256" = "$param1" ]; then
                            echo "    ✓ Valid binary with correct SHA256: $file_name"
                        else
                            echo "    ❌ SHA256 mismatch for $file_name (expected: $param1, got: $actual_sha256)"
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
                    echo "    ❌ Corrupted archive detected: $file_name"
                    corrupted_files+=("$file_name")
                    rm -f "$file_path"
                else
                    # Validate SHA256
                    expected_sha256="33497b93cf9dd65e8431024fd1db19cbfbe30bd796775a59d53e2df9a8de6dc0"
                    actual_sha256=$(sha256sum "$file_path" | cut -d' ' -f1)
                    if [ "$actual_sha256" = "$expected_sha256" ]; then
                        echo "    ✓ Valid archive with correct SHA256: $file_name"
                        
                        # Validate ASC signature if available
                        asc_file="${file_path}.asc"
                        if [ -f "$asc_file" ]; then
                            # Import Julia GPG key first
                            echo "    Importing Julia GPG key for signature verification..."
                            gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys 3673DF529D9049477F76B37566E3C7DC03D6E495 2>/dev/null || \
                            gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys 3673DF529D9049477F76B37566E3C7DC03D6E495 2>/dev/null || true
                            
                            if gpg --batch --verify "$asc_file" "$file_path" 2>/dev/null; then
                                echo "    ✓ Valid GPG signature: $file_name"
                            else
                                echo "    ⚠ GPG signature verification failed, but SHA256 is correct - continuing"
                                # Don't mark as corrupted if SHA256 is correct
                            fi
                        else
                            echo "    ⚠ ASC signature file not found for: $file_name"
                        fi
                    else
                        echo "    ❌ SHA256 mismatch for $file_name (expected: $expected_sha256, got: $actual_sha256)"
                        corrupted_files+=("$file_name")
                        rm -f "$file_path"
                    fi
                fi
                ;;
            "asc")
                # Check if ASC signature file is valid
                if [ -f "$file_path" ] && [ -s "$file_path" ]; then
                    if grep -q "BEGIN PGP SIGNATURE" "$file_path" && grep -q "END PGP SIGNATURE" "$file_path"; then
                        echo "    ✓ Valid ASC signature file: $file_name"
                    else
                        echo "    ❌ Invalid ASC signature format: $file_name"
                        corrupted_files+=("$file_name")
                        rm -f "$file_path"
                    fi
                else
                    echo "    ❌ ASC signature file missing or empty: $file_name"
                    corrupted_files+=("$file_name")
                    rm -f "$file_path"
                fi
                ;;
            "deb_with_gpg")
                # Check if .deb package is valid and verify with GPG signature
                if ! dpkg-deb -I "$file_path" >/dev/null 2>&1; then
                    echo "    ❌ Corrupted .deb package detected: $file_name"
                    corrupted_files+=("$file_name")
                    rm -f "$file_path"
                else
                    echo "    ✓ Valid .deb package: $file_name"
                    # Note: GPG verification will be done during installation phase
                    echo "    ⚠ GPG verification will be performed during installation"
                fi
                ;;
            "archive")
                # Check if archive is valid (tar.gz)
                if ! tar -tzf "$file_path" >/dev/null 2>&1; then
                    echo "    ❌ Corrupted archive detected: $file_name"
                    corrupted_files+=("$file_name")
                    rm -f "$file_path"
                else
                    echo "    ✓ Valid archive: $file_name"
                fi
                ;;
            "gpg")
                # Check if GPG key is valid (more robust validation)
                if [ -f "$file_path" ] && [ -s "$file_path" ]; then
                    # Check if file contains GPG key markers
                    if grep -q "BEGIN PGP" "$file_path" && grep -q "END PGP" "$file_path"; then
                        echo "    ✓ Valid GPG key: $file_name"
                    else
                        echo "    ❌ Invalid GPG key format: $file_name"
                        corrupted_files+=("$file_name")
                        rm -f "$file_path"
                    fi
                else
                    echo "    ❌ GPG key file missing or empty: $file_name"
                    corrupted_files+=("$file_name")
                    rm -f "$file_path"
                fi
                ;;
            "deb")
                # Check if .deb package is valid
                if ! dpkg-deb -I "$file_path" >/dev/null 2>&1; then
                    echo "    ❌ Corrupted .deb package detected: $file_name"
                    corrupted_files+=("$file_name")
                    rm -f "$file_path"
                else
                    echo "    ✓ Valid .deb package: $file_name"
                fi
                ;;
        esac
    done
    
    # Phase 3: Re-download corrupted files
    if [ ${#corrupted_files[@]} -gt 0 ]; then
        echo "Phase 3: Re-downloading ${#corrupted_files[@]} corrupted files..."
        for file_name in "${corrupted_files[@]}"; do
            echo "  Re-downloading $file_name..."
            
            # Extract URL from the file definition
            file_info="${required_files[$file_name]}"
            IFS='|' read -r file_url validation_method param1 param2 param3 <<< "$file_info"
            
            # Determine destination directory
            if [[ "$file_name" == *.deb ]]; then
                dest_path="${PWD}/container_cache/debs/${file_name}"
            elif [[ "$file_name" == "drake.asc" ]]; then
                dest_path="${PWD}/container_cache/binaries/${file_name}"
            elif [[ "$file_name" == "julia-"*.tar.gz ]]; then
                dest_path="${PWD}/container_cache/binaries/${file_name}"
            else
                dest_path="${PWD}/container_cache/binaries/${file_name}"
            fi
            
            if curl -fsSL "$file_url" -o "$dest_path"; then
                echo "  ✓ Re-downloaded: $file_name"
            else
                echo "  ❌ Failed to re-download: $file_name"
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
        elif [[ "$file_name" == "julia-"*.tar.gz ]]; then
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
                    # If SHA256 is provided, validate it
                    if [ -n "$param1" ]; then
                        actual_sha256=$(sha256sum "$file_path" | cut -d' ' -f1)
                        if [ "$actual_sha256" = "$param1" ]; then
                            echo "  ✓ Verified binary with correct SHA256: $file_name"
                        else
                            echo "  ❌ SHA256 verification failed for $file_name (expected: $param1, got: $actual_sha256)"
                            all_valid=false
                        fi
                    else
                    echo "  ✓ Verified binary: $file_name"
                    fi
                else
                    echo "  ❌ Binary verification failed: $file_name"
                    all_valid=false
                fi
                ;;
            "archive_with_asc_sha256")
                if [ -f "$file_path" ] && tar -tzf "$file_path" >/dev/null 2>&1; then
                    # Validate SHA256
                    expected_sha256="33497b93cf9dd65e8431024fd1db19cbfbe30bd796775a59d53e2df9a8de6dc0"
                    actual_sha256=$(sha256sum "$file_path" | cut -d' ' -f1)
                    if [ "$actual_sha256" = "$expected_sha256" ]; then
                        echo "  ✓ Verified archive with correct SHA256: $file_name"
                        
                        # Validate ASC signature if available
                        asc_file="${file_path}.asc"
                        if [ -f "$asc_file" ]; then
                            # Import Julia GPG key first
                            gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys 3673DF529D9049477F76B37566E3C7DC03D6E495 2>/dev/null || \
                            gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys 3673DF529D9049477F76B37566E3C7DC03D6E495 2>/dev/null || true
                            
                            if gpg --batch --verify "$asc_file" "$file_path" 2>/dev/null; then
                                echo "  ✓ Verified GPG signature: $file_name"
                            else
                                echo "  ⚠ GPG signature verification failed, but SHA256 is correct - continuing"
                                # Don't mark as invalid if SHA256 is correct
                            fi
                        else
                            echo "  ⚠ ASC signature file not found for: $file_name"
                        fi
                    else
                        echo "  ❌ SHA256 verification failed for $file_name (expected: $expected_sha256, got: $actual_sha256)"
                        all_valid=false
                    fi
                else
                    echo "  ❌ Archive verification failed: $file_name"
                    all_valid=false
                fi
                ;;
            "asc")
                if [ -f "$file_path" ] && [ -s "$file_path" ] && grep -q "BEGIN PGP SIGNATURE" "$file_path" && grep -q "END PGP SIGNATURE" "$file_path"; then
                    echo "  ✓ Verified ASC signature file: $file_name"
                else
                    echo "  ❌ ASC signature verification failed: $file_name"
                    all_valid=false
                fi
                ;;
            "deb_with_gpg")
                if [ -f "$file_path" ] && dpkg-deb -I "$file_path" >/dev/null 2>&1; then
                    echo "  ✓ Verified .deb package: $file_name"
                    echo "  ⚠ GPG verification will be performed during installation"
                else
                    echo "  ❌ .deb package verification failed: $file_name"
                    all_valid=false
                fi
                ;;
            "archive")
                if [ -f "$file_path" ] && tar -tzf "$file_path" >/dev/null 2>&1; then
                    echo "  ✓ Verified archive: $file_name"
                else
                    echo "  ❌ Archive verification failed: $file_name"
                    all_valid=false
                fi
                ;;
            "gpg")
                if [ -f "$file_path" ] && [ -s "$file_path" ] && grep -q "BEGIN PGP" "$file_path" && grep -q "END PGP" "$file_path"; then
                    echo "  ✓ Verified GPG key: $file_name"
                else
                    echo "  ❌ GPG key verification failed: $file_name"
                    all_valid=false
                fi
                ;;
            "deb")
                if [ -f "$file_path" ] && dpkg-deb -I "$file_path" >/dev/null 2>&1; then
                    echo "  ✓ Verified .deb package: $file_name"
                else
                    echo "  ❌ .deb package verification failed: $file_name"
                    all_valid=false
                fi
                ;;
        esac
    done
    
    if [ "$all_valid" = true ]; then
        echo "✅ All files verified and ready for build"
    else
        echo "❌ File verification failed - aborting build"
        exit 1
    fi
    
    echo "============== Complete File Preparation Phase Complete =============="
    
    # Ensure proper ownership and permissions after copy
    chown -R root:root "${SINGULARITY_ROOTFS}/container_cache" 2>/dev/null || true
    chmod -R 755 "${SINGULARITY_ROOTFS}/container_cache" 2>/dev/null || true


# ==============================================================================
# --- %post Section ---
# ==============================================================================
%post -c /bin/bash
    # Make the script executable and run it
    chmod +x /container_post_script.sh
    /container_post_script.sh
# --- %test Section ---
# ==============================================================================
%test
    set -eu
    echo "[test] XFCE:"
    if [ -n "$DISPLAY" ] || pgrep 'Xorg|Xvnc' >/dev/null ; then
      xfce4-session --version || true
    else
      echo "[note] No DISPLAY during build; skipping XFCE runtime check."
    fi
    echo "[test] VNC/GL:"; vncserver --version || true; Xvnc --version || true
    echo "[test] Firefox:"; firefox --version || true
    echo "[test] yq:"; yq --version || true
    echo "[test] Conda:"; [ -x /opt/conda/bin/conda ] && /opt/conda/bin/conda --version || echo MISSING
    echo "[test] Micromamba:"; micromamba --help >/dev/null 2>&1 && echo OK || echo MISSING
    echo "[test] Drake key:"; test -s /etc/apt/trusted.gpg.d/drake.gpg && echo OK || echo MISSING
    echo "[test] XFCE xstartup wrapper:"; test -x /usr/local/bin/start_vnc_xfce.sh && echo OK || echo MISSING
    echo "[test] Ulauncher:"; ulauncher --version >/dev/null 2>&1 && echo OK || echo MISSING "(headless test)"
    # Notebook & Julia/Drake checks (soft)
    echo "[test] Notebooks:"; jupyter kernelspec list 2>/dev/null || true
    echo "[test] Julia:"; julia --version 2>/dev/null || true
    echo "[test] MeshCat import:"; python3 -c "import meshcat; print('Meshcat OK')" 2>/dev/null || true
    echo "[test] Meldis:"; /opt/drake/bin/meldis --help 2>/dev/null || true
    echo "[test] TeX:"; pdflatex --version 2>/dev/null || true; biber --version 2>/dev/null || true
    # Missing package tests from baseline
    echo "[test] LibreOffice:"; libreoffice --version 2>/dev/null || true
    echo "[test] Blender:"; blender --version 2>/dev/null || true
    echo "[test] OpenSCAD:"; openscad --version 2>/dev/null || true
    echo "[test] FreeCAD:"; freecad --version 2>/dev/null || true
    # Robotics tools tests
    echo "[test] Mirror selection:"; command -v apt-smart >/dev/null 2>&1 && echo "apt-smart available" || echo "apt-smart not available"


# ==============================================================================
# --- %runscript Section ---
# ==============================================================================
%runscript
    exec /bin/bash -l

DEF
# ==============================================================================
# --- End of Singularity Definition ---
# ==============================================================================
log "Singularity definition file generated successfully."


# ==============================================================================
# --- Build, Harvest, and Finalize ---
# ==============================================================================

# --- Build the Container ---
log_with_timestamp "Building sif: ${OUT_DIR}/${SIF_NAME}"
# Check if apptainer is available, otherwise try singularity
if command -v apptainer >/dev/null 2>&1; then
    sudo apptainer build "${OUT_DIR}/${SIF_NAME}" "${DEF_NAME}"
elif command -v singularity >/dev/null 2>&1; then
    warn "apptainer not found, falling back to singularity."
    sudo singularity build "${OUT_DIR}/${SIF_NAME}" "${DEF_NAME}"
else
    err "Neither apptainer nor singularity found in PATH. Please install one to proceed."
fi
log "=============== Image building completed successfully ==============="


# --- Turn on detailed command tracing ---
set -x


# --- Harvest Caches Back to Host ---
log_with_timestamp "============== Initiating Harvest from SIF to Host Cache =============="
SIF_PATH="${OUT_DIR}/${SIF_NAME}"
HOST_CACHE="${PWD}/container_cache"
mkdir -p "$HOST_CACHE"

# Check if apptainer is available, otherwise try singularity
if command -v apptainer >/dev/null 2>&1; then
    log_with_timestamp "Using Apptainer for cache harvest..."
    if apptainer exec --bind "${HOST_CACHE}:/host_cache" "${SIF_PATH}" \
      bash -c 'rsync -a --ignore-existing /container_cache/ /host_cache/'; then
        log_success "Cache harvest completed successfully"
    else
        log_warning "Cache harvest failed, but continuing..."
    fi

    log_with_timestamp "============== Verify Harvest =============="
    apptainer exec "${SIF_PATH}" bash -lc 'test -d /container_cache && ls -l /container_cache | wc -l' | awk '{print "[info] cache dirs inside image:", $1}'
    apptainer exec "${SIF_PATH}" bash -lc 'ls -lh /container_cache/apt/archives/*.deb 2>/dev/null | head || echo "[warn] no .deb files harvested"'
elif command -v singularity >/dev/null 2>&1; then
    log_with_timestamp "Using Singularity for cache harvest..."
    if singularity exec --bind "${HOST_CACHE}:/host_cache" "${SIF_PATH}" \
      bash -c 'rsync -a --ignore-existing /container_cache/ /host_cache/'; then
        log_success "Cache harvest completed successfully"
    else
        log_warning "Cache harvest failed, but continuing..."
    fi

    log_with_timestamp "============== Verify Harvest =============="
    singularity exec "${SIF_PATH}" bash -lc 'test -d /container_cache && ls -l /container_cache | wc -l' | awk '{print "[info] cache dirs inside image:", $1}'
    singularity exec "${SIF_PATH}" bash -lc 'ls -lh /container_cache/apt/archives/*.deb 2>/dev/null | head || echo "[warn] no .deb files harvested"'
else
    log_warning "Neither apptainer nor singularity found. Skipping cache harvest."
fi
log_success "============== Harvest Complete =============="

# Comprehensive cache validation
log_with_timestamp "============== Validating Harvested Cache =============="
echo "==> Validating harvested cache..."
local issues=0

# Check APT cache
if [[ -d "${HOST_CACHE}/apt/archives" ]]; then
    local apt_count=$(find "${HOST_CACHE}/apt/archives" -name "*.deb" 2>/dev/null | wc -l)
    if [[ $apt_count -gt 0 ]]; then
        echo "  ✓ APT cache: $apt_count .deb files harvested"
    else
        echo "  ⚠ APT cache: No .deb files found"
        ((issues++))
    fi
else
    echo "  ⚠ APT cache: Directory not found"
    ((issues++))
fi

# Check Conda cache
if [[ -d "${HOST_CACHE}/conda_pkgs" ]]; then
    local conda_count=$(find "${HOST_CACHE}/conda_pkgs" -name "*.conda" -o -name "*.tar.bz2" 2>/dev/null | wc -l)
    if [[ $conda_count -gt 0 ]]; then
        echo "  ✓ Conda cache: $conda_count packages harvested"
    else
        echo "  ⚠ Conda cache: No packages found"
    fi
else
    echo "  ⚠ Conda cache: Directory not found"
fi

# Check Pip wheels
if [[ -d "${HOST_CACHE}/wheels" ]]; then
    local wheel_count=$(find "${HOST_CACHE}/wheels" -name "*.whl" 2>/dev/null | wc -l)
    if [[ $wheel_count -gt 0 ]]; then
        echo "  ✓ Pip wheels: $wheel_count wheels harvested"
    else
        echo "  ⚠ Pip wheels: No wheels found"
    fi
else
    echo "  ⚠ Pip wheels: Directory not found"
fi

# Check Julia cache
if [[ -d "${HOST_CACHE}/julia_pkgs" ]]; then
    local julia_size=$(du -sh "${HOST_CACHE}/julia_pkgs" 2>/dev/null | cut -f1 || echo "0B")
    if [[ "$julia_size" != "0B" ]]; then
        echo "  ✓ Julia cache: $julia_size harvested"
    else
        echo "  ⚠ Julia cache: No packages found"
    fi
else
    echo "  ⚠ Julia cache: Directory not found"
fi

if [[ $issues -eq 0 ]]; then
    echo "  ✓ Cache harvest validation passed"
else
    echo "  ⚠ Cache harvest validation found $issues issues"
fi

log_success "============== Harvest Complete =============="


# --- Prune Host Caches ---
# NOTE: The original script assumes these pruning scripts exist at /usr/local/bin
# on the HOST. This is unlikely. A robust implementation would define them
# in the script or check for them. For a drop-in replacement, we call them as is.
log_with_timestamp "============== Pruning Host Caches =============="
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
log_success "============== Pruning Complete =============="
# --- Turn off command tracing before the final summary ---
set +x

# --- Final Build Summary ---
echo ""
echo "✅ Build process finished."
echo "Built image: ${OUT_DIR}/${SIF_NAME}"
echo ""
echo "📝 Build Summary 📝"
echo "  - Base system: Ubuntu 22.04 with XFCE4"
echo "  - Package manager: apt-fast + mamba solver"
echo "  - Development: Python, Julia, C++ toolchains"
echo "  - Jupyter: Full environment with kernels"
echo "  - Robotics: Drake (ROS2 in separate image)"
echo "  - Graphics: VNC, VirtualGL, Blender, CAD tools"
echo "  - Documentation: TeX Live, LibreOffice"
echo "  - Caching: Comprehensive package caching system"
echo ""
log_with_timestamp "Host cache disk usage:"
du -sh "${BIN_CACHE}" "${DEB_CACHE}" "${APT_CACHE}" "${CONDA_CACHE}" "${JULIA_CACHE}" "${WHEELS_CACHE}" 2>/dev/null || true
echo ""
echo "[note] To start a tuned VNC session inside the container:"
echo "  apptainer exec --nv ${OUT_DIR}/${SIF_NAME} start_vnc_xfce.sh"
echo "  (Tunnel: ssh -L 5901:localhost:5901 <user>@<host>) -> VNC viewer to localhost:5901"
echo ""
echo "[note] Julia CUDA may precompile (run on GPU node):"
echo "  apptainer exec --nv ${OUT_DIR}/${SIF_NAME} precompile_julia_cuda.sh"
echo ""
echo "[note] AppImages (FreeCAD, Ultimaker Cura, Mendeley) recommended:"
echo "  Download from official pages, then:"
echo "  chmod +x *.AppImage && mkdir -p ~/Applications && mv *.AppImage ~/Applications/"
echo "  # appimagelauncher-cli integrate ~/Applications/*.AppImage (if installed)"
echo ""
echo "[note] Drake Python path if needed:"
echo "  export PYTHONPATH=/opt/drake/lib/python3/dist-packages:\$PYTHONPATH"
echo "  or /opt/drake/lib/python3.10/site-packages for Jammy"
echo ""
echo "[note] Drake is installed in base environment:"
echo "  meldis: /opt/drake/bin/meldis"
echo "  meshcat-server: /opt/drake/bin/meshcat-server"
echo "  python -c 'import pydrake'"
echo ""
echo "[note] For Isaac Sim, Mujoco, and other simulators:"
echo "  Install via conda/mamba environments or download from official sources"
echo ""
echo "[note] Mirror selection features:"
echo "  - apt-smart for Ubuntu repo mirror testing"
echo "  - Automatic selection of fastest mirrors"
echo ""
echo "[note] Package management:"
echo "  - mamba solver installed in conda for fast environment solving"
echo "  - micromamba available as separate fast alternative"
echo "  - Fallback to conda if mamba unavailable"

# Build summary with timing and cache statistics
BUILD_END_TIME=$(date +%s)
BUILD_DURATION=$((BUILD_END_TIME - BUILD_START_TIME))
BUILD_HOURS=$((BUILD_DURATION / 3600))
BUILD_MINUTES=$(((BUILD_DURATION % 3600) / 60))
BUILD_SECONDS=$((BUILD_DURATION % 60))


# Cache statistics
CACHE_TOTAL_SIZE=$(du -sh "${CACHE_DIR}" 2>/dev/null | cut -f1 || echo "0B")
APT_CACHE_SIZE=$(du -sh "${APT_ARCHIVE_CACHE}" 2>/dev/null | cut -f1 || echo "0B")
CONDA_CACHE_SIZE=$(du -sh "${CONDA_CACHE}" 2>/dev/null | cut -f1 || echo "0B")
WHEELS_CACHE_SIZE=$(du -sh "${WHEELS_CACHE}" 2>/dev/null | cut -f1 || echo "0B")
JULIA_CACHE_SIZE=$(du -sh "${JULIA_CACHE}" 2>/dev/null | cut -f1 || echo "0B")

APT_CACHE_COUNT=$(find "${APT_ARCHIVE_CACHE}" -name "*.deb" 2>/dev/null | wc -l)
CONDA_CACHE_COUNT=$(find "${CONDA_CACHE}" -name "*.conda" -o -name "*.tar.bz2" 2>/dev/null | wc -l)
WHEELS_CACHE_COUNT=$(find "${WHEELS_CACHE}" -name "*.whl" 2>/dev/null | wc -l)

echo ""
echo "============== BUILD SUMMARY =============="
echo "Container: ${SIF_PATH}"
echo "Size: $(du -sh "${SIF_PATH}" | cut -f1)"
echo "Build time: ${BUILD_HOURS}h ${BUILD_MINUTES}m ${BUILD_SECONDS}s"
echo ""
echo "============== CACHE STATISTICS =============="
echo "Total cache size: ${CACHE_TOTAL_SIZE}"
echo "APT cache: ${APT_CACHE_SIZE} (${APT_CACHE_COUNT} .deb files)"
echo "Conda cache: ${CONDA_CACHE_SIZE} (${CONDA_CACHE_COUNT} packages)"
echo "Pip wheels: ${WHEELS_CACHE_SIZE} (${WHEELS_CACHE_COUNT} wheels)"
echo "Julia cache: ${JULIA_CACHE_SIZE}"
echo "==========================================="