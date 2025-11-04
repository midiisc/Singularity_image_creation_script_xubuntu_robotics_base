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
# NOTE: Check https://github.com/conda-forge/miniforge/releases for latest version
# Current version: 25.3.1-0 (verify at https://github.com/conda-forge/miniforge/releases/latest)
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
export XPRA_VERSION="6.3.5"  # Latest from GitHub: https://github.com/Xpra-org/xpra/releases/latest
export XPRA_HTML5_VERSION="18"  # Latest from GitHub: https://github.com/Xpra-org/xpra-html5/releases/latest

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
export OX_VERSION="0.7.7"  # Latest from GitHub: https://github.com/curlpipe/ox/releases/latest

# Middleware
export ZENOH_VERSION="1.6.2"
export ZENOH_ROS2DDS_VERSION="1.6.2"  # ROS 2 DDS bridge plugin version

# GPU/CUDA
export NVIDIA_KEYRING_VER="1.1-1"
export CUDA_VERSION="12.6"
export CUDA_MAJOR="12"
export CUDNN_VER="9.14.0.64-1"  # CUDA 12.x compatible version (preferred, but may not be available)
# Note: Available cuDNN versions vary by repository. Common versions:
#   - 9.14.0.64-1 (CUDA 13/12) - may not be available in all repositories
#   - 9.10.2.21-1 (CUDA 11)
# If specific version not found, fallback logic will automatically install latest compatible version
# The script checks version availability before attempting installation to avoid errors
export CUDA_ARCH="8.6"  # NVIDIA A6000 architecture

#===============================================================================
# DOWNLOAD URLS (Constructed from versions)
#===============================================================================

# Miniforge
# Official GitHub releases URL: https://github.com/conda-forge/miniforge/releases
# Download URL pattern: https://github.com/conda-forge/miniforge/releases/download/{VERSION}/Miniforge3-{VERSION}-Linux-x86_64.sh
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
# UNIFIED LOG ANALYSIS FUNCTION
#===============================================================================
# Purpose: Analyze build logs to extract errors/warnings with context
# Usage: analyze_build_log <log_file> <error_log>
#        Set LOG_FILE and ERROR_LOG variables before calling
#        For container builds: use BUILD_LOG_FILE and BUILD_ERROR_LOG
#===============================================================================

analyze_build_log() {
    # Determine log and error log file based on context
    local log_file="${1:-${LOG_FILE:-${BUILD_LOG_FILE:-}}}"
    local error_log="${2:-${ERROR_LOG:-${BUILD_ERROR_LOG:-}}}"
    
    if [ -z "$log_file" ] || [ ! -f "$log_file" ]; then
        return 0  # No log file to analyze
    fi
    
    if [ -z "$error_log" ]; then
        return 0  # No error log specified
    fi
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Analyzing build log for errors and warnings..."
    echo "═══════════════════════════════════════════════════════════════"
    
    # Write new header with analysis timestamp
    {
        echo "========================================"
        echo "Error Log Analysis: $(date)"
        echo "Build Log: ${log_file}"
        echo "Analysis Method: Post-build extraction with context"
        echo "========================================"
        echo ""
    } > "${error_log}"
    
    # Context window size (lines before and after error)
    local context_lines=5
    local total_errors=0
    local total_warnings=0
    local total_debug_flags=0
    local total_deprecations=0
    
    # Read log file line by line with line numbers
    local line_num=0
    local error_line_nums=()
    local warning_line_nums=()
    local debug_flag_line_nums=()
    local deprecation_line_nums=()
    local all_lines=()
    local current_context="General Build"
    local context_stack=()
    
    # Context detection patterns (ordered by specificity)
    declare -A context_patterns=(
        ["OpenCV Compilation"]="(PHASE 4.*OpenCV|Compiling OpenCV|Building OpenCV|OpenCV.*Build|cmake.*opencv|ninja.*opencv)"
        ["OpenCV Configuration"]="(Configuring OpenCV|OpenCV.*CMake|OpenCV.*configure|opencv.*cmake config)"
        ["Open3D Compilation"]="(Building Open3D|Compiling Open3D|Open3D.*ninja|ninja.*open3d|open3d.*build)"
        ["Open3D Configuration"]="(Configuring Open3D|Open3D.*CMake|Open3D.*configure|open3d.*cmake config)"
        ["Open3D Python"]="(Open3D.*Python|open3d.*pip|open3d.*wheel|install.*open3d|python.*open3d)"
        ["COLMAP Compilation"]="(Building COLMAP|Compiling COLMAP|COLMAP.*ninja|ninja.*colmap|colmap.*build)"
        ["COLMAP Configuration"]="(Configuring COLMAP|COLMAP.*CMake|COLMAP.*configure|colmap.*cmake config)"
        ["COLMAP Python"]="(PyCOLMAP|pycolmap|COLMAP.*Python|colmap.*pip)"
        ["Ceres Compilation"]="(Building Ceres|Compiling Ceres|Ceres.*ninja|ninja.*ceres|ceres.*build)"
        ["Ceres Configuration"]="(Configuring Ceres|Ceres.*CMake|Ceres.*configure|ceres.*cmake config)"
        ["G2O Compilation"]="(Building g2o|Compiling g2o|g2o.*ninja|ninja.*g2o)"
        ["G2O Configuration"]="(Configuring g2o|g2o.*CMake|g2o.*configure)"
        ["GTSAM Compilation"]="(Building GTSAM|Compiling GTSAM|GTSAM.*ninja|ninja.*gtsam)"
        ["GTSAM Configuration"]="(Configuring GTSAM|GTSAM.*CMake|GTSAM.*configure)"
        ["Conda Installation"]="(Installing.*conda|conda.*install|mamba.*install|Conda.*setup)"
        ["Conda Update"]="(Updating.*conda|conda.*update|mamba.*update)"
        ["Julia Installation"]="(Installing.*Julia|Julia.*install|julia.*setup)"
        ["TurboVNC Installation"]="(Installing.*TurboVNC|TurboVNC.*install|turbovnc)"
        ["VirtualGL Installation"]="(Installing.*VirtualGL|VirtualGL.*install|virtualgl)"
        ["APT Package Installation"]="(apt-get.*install|apt install|Installing.*packages)"
        ["CMake Configuration"]="(CMake.*configuration|cmake.*config|Configuring.*CMake)"
        ["Ninja Build"]="(ninja.*build|Building.*ninja|ninja.*-j)"
        ["Python Package"]="(pip.*install|python.*setup|Installing.*Python)"
        ["GPU/CUDA Setup"]="(CUDA.*setup|GPU.*configuration|NVIDIA.*install)"
        ["Phase 1"]="(PHASE 1|Phase 1|PHASE.*1)"
        ["Phase 2"]="(PHASE 2|Phase 2|PHASE.*2)"
        ["Phase 3"]="(PHASE 3|Phase 3|PHASE.*3)"
        ["Phase 4"]="(PHASE 4|Phase 4|PHASE.*4)"
    )
    
    # First pass: identify all error, warning, debug, and deprecation lines
    while IFS= read -r line || [ -n "$line" ]; do
        line_num=$((line_num + 1))
        all_lines+=("$line")
        
        # Update context based on line content
        for context_name in "${!context_patterns[@]}"; do
            if echo "$line" | grep -qiE "${context_patterns[$context_name]}"; then
                current_context="$context_name"
                context_stack+=("$context_name")
                break
            fi
        done
        
        # Match error patterns (case-insensitive) - most specific first
        if echo "$line" | grep -qiE \
            '(^[[:space:]]*✗[[:space:]]+|^[[:space:]]*✖[[:space:]]+|^[[:space:]]*❌[[:space:]]+|error:|fatal error|compilation error|link error|build error|install error|runtime error|segmentation.*fault|core.*dump|assertion.*failed|assert.*failed|^ERROR|^FATAL|FAILED|FAILURE|unable to|cannot|missing|undefined reference|undefined symbol|NO SUCH|FILE NOT FOUND|DIRECTORY NOT FOUND|PACKAGE NOT FOUND|command not found|No such file|not found in PATH|exit.*code.*[1-9]|exit.*status.*[1-9]|exit code [1-9]|killed|aborted|abort|terminated|signal.*killed|permission.*denied|access.*denied|read.*only|write.*protect|disk.*full|no.*space|out.*of.*memory|OOM|Out of memory|memory.*exhausted|Cannot allocate|allocation.*failed|stack overflow|buffer.*overflow|null pointer|dereference|corruption|corrupted|invalid|malformed|parse.*error|syntax.*error|type.*error|connection.*refused|connection.*reset|bind.*failed|cannot bind|address.*in use|port.*in use|timeout.*error|deadlock|race.*condition|thread.*error|pthread.*error|mutex.*error|lock.*error|glibc.*error|libc.*error|SSL.*error|TLS.*error|certificate.*error|authentication.*failed|authorization.*failed|key.*not found|key.*invalid|signature.*invalid|checksum.*mismatch|hash.*mismatch|integrity.*failed|verification.*failed|CMake.*error|ninja.*error|make.*error|gcc.*error|g\+\+.*error|clang.*error|ld.*error|linker.*error|ar.*error|ranlib.*error|strip.*error|objcopy.*error|dpkg.*error|apt.*error|pip.*error|conda.*error|python.*error|ImportError|ModuleNotFoundError|AttributeError|NameError|TypeError|ValueError|KeyError|IndexError|RuntimeError|SystemError|OSError|IOError|FileNotFoundError|PermissionError|NotADirectoryError|IsADirectoryError)'; then
            error_line_nums+=($line_num)
            total_errors=$((total_errors + 1))
        # Match warning patterns (case-insensitive, but not errors)
        elif echo "$line" | grep -qiE \
            '(^[[:space:]]*⚠[[:space:]]+|^[[:space:]]*⚠️[[:space:]]+|^WARNING|warning:|deprecated|obsolete|ignored|skipped|timeout|connection.*timeout|slow|performance.*issue|inefficient|suboptimal|not.*recommended|discouraged|legacy|old.*version|outdated|consider.*upgrading|future.*removal|will.*be.*removed|will.*stop.*working|may.*fail|might.*fail|potential.*issue|possible.*problem|unexpected|unusual|strange|odd|uncommon|rare|seldom|infrequent|minor.*issue|non.*critical|non.*fatal|low.*priority|low.*severity|SSL.*warning|certificate.*warning|authentication.*warning|security.*warning|trust.*warning|insecure|unencrypted|plaintext|unprotected|vulnerability|vulnerable|CVE|exploit|attack|unsafe|risky|hazard|danger|caution|careful|beware|risk|threat|exposure|leak|leaked|exposed|public|private.*key|password.*visible|credential.*exposed|secret.*exposed|token.*exposed|api.*key.*exposed)'; then
            warning_line_nums+=($line_num)
            total_warnings=$((total_warnings + 1))
        # Match debug flags and diagnostic output (non-fatal but informative)
        elif echo "$line" | grep -qiE \
            '(^\[DEBUG\]|DEBUG:|DEBUG CHECKPOINT|debug checkpoint|debug:|debugging|diagnostic|DIAGNOSTIC|diagnosis|trace|TRACE|tracing|verbose|VERBOSE|VERBOSITY|v=[0-9]|verbosity|log.*level|LOG.*LEVEL|level.*[0-9]|enabling.*debug|debug.*enabled|debug.*mode|development.*mode|dev.*mode|testing.*mode|test.*mode|experimental|EXPERIMENTAL|beta|BETA|alpha|ALPHA|preview|PREVIEW|pre.*release|not.*production|production.*disabled|prod.*disabled|staging|STAGING|unstable|UNSTABLE|work.*in.*progress|WIP|under.*construction|under.*development|TODO|FIXME|XXX|HACK|NOTE:|NOTICE:|INFO:|INFORMATION:|FYI|for.*information|FYI|informational|informational.*message)'; then
            debug_flag_line_nums+=($line_num)
            total_debug_flags=$((total_debug_flags + 1))
        # Match deprecation warnings (specific pattern for future compatibility issues)
        elif echo "$line" | grep -qiE \
            '(deprecated.*version|deprecated.*in.*version|will.*deprecate|deprecation.*warning|deprecated.*API|deprecated.*function|deprecated.*method|deprecated.*class|deprecated.*module|deprecated.*feature|deprecated.*option|deprecated.*flag|deprecated.*parameter|deprecated.*attribute|deprecated.*property|removed.*in|removal.*planned|EOL|end.*of.*life|end.*of.*support|no.*longer.*supported|discontinued|phase.*out|sunset|sunsetted|legacy.*mode|legacy.*support|backward.*compatibility|breaking.*change|incompatible.*change|API.*change|ABI.*change|interface.*change|signature.*change|behavior.*change)'; then
            deprecation_line_nums+=($line_num)
            total_deprecations=$((total_deprecations + 1))
        fi
    done < "$log_file"
    
    # Second pass: extract error/warning blocks with context
    if [ ${#error_line_nums[@]} -gt 0 ] || [ ${#warning_line_nums[@]} -gt 0 ] || [ ${#debug_flag_line_nums[@]} -gt 0 ] || [ ${#deprecation_line_nums[@]} -gt 0 ]; then
        echo "  Found ${total_errors} error(s), ${total_warnings} warning(s), ${total_debug_flags} debug flag(s), ${total_deprecations} deprecation(s)"
        echo ""
        
        # Combine and sort line numbers
        local all_issue_lines=($(printf '%s\n' "${error_line_nums[@]}" "${warning_line_nums[@]}" "${debug_flag_line_nums[@]}" "${deprecation_line_nums[@]}" | sort -n | uniq))
        
        local last_extracted_line=0
        local current_context_line=0
        
        for issue_line in "${all_issue_lines[@]}"; do
            # Skip if we already extracted this area (within context window)
            if [ $issue_line -le $last_extracted_line ]; then
                continue
            fi
            
            # Determine issue type and severity
            local is_error=false
            local is_warning=false
            local is_debug=false
            local is_deprecation=false
            
            for err_line in "${error_line_nums[@]}"; do
                if [ $err_line -eq $issue_line ]; then
                    is_error=true
                    break
                fi
            done
            
            if [ "$is_error" != true ]; then
                for warn_line in "${warning_line_nums[@]}"; do
                    if [ $warn_line -eq $issue_line ]; then
                        is_warning=true
                        break
                    fi
                done
            fi
            
            if [ "$is_error" != true ] && [ "$is_warning" != true ]; then
                for debug_line in "${debug_flag_line_nums[@]}"; do
                    if [ $debug_line -eq $issue_line ]; then
                        is_debug=true
                        break
                    fi
                done
            fi
            
            if [ "$is_error" != true ] && [ "$is_warning" != true ] && [ "$is_debug" != true ]; then
                for dep_line in "${deprecation_line_nums[@]}"; do
                    if [ $dep_line -eq $issue_line ]; then
                        is_deprecation=true
                        break
                    fi
                done
            fi
            
            # Find the most recent context before this line
            local context_for_issue="General Build"
            local i=$((issue_line - 1))
            while [ $i -gt 0 ] && [ $i -gt $((issue_line - 50)) ]; do
                for context_name in "${!context_patterns[@]}"; do
                    if [ $i -le ${#all_lines[@]} ]; then
                        local idx=$((i - 1))
                        if [ $idx -ge 0 ]; then
                            if echo "${all_lines[$idx]}" | grep -qiE "${context_patterns[$context_name]}"; then
                                context_for_issue="$context_name"
                                break 2
                            fi
                        fi
                    fi
                done
                i=$((i - 1))
            done
            
            # Calculate context range
            local start_line=$((issue_line - context_lines))
            if [ $start_line -lt 1 ]; then
                start_line=1
            fi
            local end_line=$((issue_line + context_lines))
            if [ $end_line -gt ${#all_lines[@]} ]; then
                end_line=${#all_lines[@]}
            fi
            
            # Write block header
            {
                echo "───────────────────────────────────────────────────────────"
                if [ "$is_error" = true ]; then
                    echo "[ERROR] Line $issue_line | Context: $context_for_issue"
                elif [ "$is_warning" = true ]; then
                    echo "[WARNING] Line $issue_line | Context: $context_for_issue"
                elif [ "$is_deprecation" = true ]; then
                    echo "[DEPRECATION] Line $issue_line | Context: $context_for_issue"
                elif [ "$is_debug" = true ]; then
                    echo "[DEBUG FLAG] Line $issue_line | Context: $context_for_issue"
                else
                    echo "[ISSUE] Line $issue_line | Context: $context_for_issue"
                fi
                echo "───────────────────────────────────────────────────────────"
                echo ""
                
                # Extract context block (0-indexed array, so subtract 1)
                local i
                for i in $(seq $start_line $end_line); do
                    local idx=$((i - 1))
                    if [ $idx -ge 0 ] && [ $idx -lt ${#all_lines[@]} ]; then
                        local marker=""
                        if [ $i -eq $issue_line ]; then
                            marker=" >>> "
                        elif [ $i -lt $issue_line ]; then
                            marker="     "
                        else
                            marker="     "
                        fi
                        printf "%6d%s%s\n" "$i" "$marker" "${all_lines[$idx]}"
                    fi
                done
                echo ""
                echo ""
            } >> "${error_log}"
            
            last_extracted_line=$end_line
        done
        
        echo "  ✓ Error log analysis complete: ${error_log}"
    else
        echo "  ✓ No errors or warnings found in build log"
        {
            echo "No errors or warnings detected in build log."
            echo ""
            echo "This does not guarantee a successful build - check the full"
            echo "build log for any issues that may not match standard patterns."
        } >> "${error_log}"
    fi
    
    # Append summary
    {
        echo "========================================"
        echo "Summary:"
        echo "  Total errors found: ${total_errors}"
        echo "  Total warnings found: ${total_warnings}"
        echo "  Total debug flags found: ${total_debug_flags}"
        echo "  Total deprecations found: ${total_deprecations}"
        echo "  Log file analyzed: ${log_file}"
        echo "  Analysis completed: $(date)"
        echo "========================================"
    } >> "${error_log}"
    
    # Final sync
    sync "${error_log}" 2>/dev/null || sync
}

#===============================================================================
# END OF CONFIGURATION
#===============================================================================

