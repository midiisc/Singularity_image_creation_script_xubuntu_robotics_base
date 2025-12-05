#!/bin/bash
#===============================================================================
# COMMON FUNCTIONS FOR CONTAINER BUILD SCRIPTS
# Single source of truth for shared functions
#===============================================================================
# Purpose: Centralized functions used across build, post, and debug scripts
# Usage: source "$(dirname "$0")/../scripts/common_functions.sh"
#        Or from inside container: source "/scripts/common_functions.sh"
# Dependencies: None (self-contained)
#===============================================================================

#===============================================================================
# SECTION 1: CACHE MANAGEMENT FUNCTIONS
#===============================================================================

#--- Function: consolidate_cache_packages ---
# Purpose: Consolidate downloaded packages from /var/cache/apt/archives/ to /container_cache/
# Since /container_cache/ is bind mounted to host, files automatically appear on host
# Called periodically during build and before purge to ensure all downloads are in cache
# Returns: 0 on success
# Side effects: Moves packages from /var/cache/apt/archives/ to /container_cache/apt/archives/
consolidate_cache_packages() {
    # Consolidate APT packages from /var/cache/apt/archives/ to /container_cache/apt/archives/
    if [ -d "/var/cache/apt/archives" ] && [ -d "${CONTAINER_APT_CACHE:-/container_cache/apt}" ]; then
        printf '\n%s\n' "==> Consolidating packages to /container_cache/..."
        local consolidated=0
        while IFS= read -r -d '' deb_file; do
            if [ -f "${deb_file:-}" ]; then
                local deb_name
                deb_name=$(basename "${deb_file}")
                # Only copy if not already in container cache (incremental)
                if [ ! -f "${CONTAINER_APT_CACHE}/${deb_name}" ]; then
                    if cp -a "${deb_file}" "${CONTAINER_APT_CACHE}/" 2>/dev/null; then
                        consolidated=$((consolidated + 1))
                    fi
                fi
            fi
        done < <(find /var/cache/apt/archives -maxdepth 1 -name "*.deb" -type f -print0 2>/dev/null)
        if [ "${consolidated}" -gt 0 ]; then
            printf '  ✓ Consolidated %d package(s) to /container_cache/\n' "${consolidated}"
        fi
    fi
    
    # Force sync to disk to ensure files are written (important for bind mounts)
    sync 2>/dev/null || true
    printf '  ✓ Cache consolidation complete (%s)\n' "$(date +%Y-%m-%d\ %H:%M:%S)"
    return 0
}

#--- Function: monitor_cache ---
# Purpose: Monitor cache usage across all cache types
# Parameters: $1 = stage name (e.g., "After CUDA installation")
# Returns: 0 on success
# Side effects: Outputs cache statistics to stdout and CSV file if CACHE_MONITOR_DATA is set
monitor_cache() {
    local stage="${1:-unknown}"
    local container_apt var_apt conda_pkgs wheels julia_pkgs
    
    # Safely count files with error handling
    # Use find instead of ls to avoid glob expansion issues
    # J1: Validate directory exists before operations
    # F2: Validate command substitution result
    if [ -d "${CONTAINER_APT_CACHE:-}" ] && [ -x "${CONTAINER_APT_CACHE:-}" ]; then
        container_apt=$(find "${CONTAINER_APT_CACHE}" -maxdepth 1 -name "*.deb" -type f 2>/dev/null | wc -l || echo "0")
        # Validate result is numeric
        if ! [[ "${container_apt:-0}" =~ ^[0-9]+$ ]]; then
            container_apt="0"
        fi
    else
        container_apt="0"
    fi
    # ENDIF: container APT cache exists and accessible
    
    # J1: Validate directory exists before operations
    # F2: Validate command substitution results
    if [ -d /var/cache/apt/archives ] && [ -x /var/cache/apt/archives ]; then
        var_apt=$(find /var/cache/apt/archives -maxdepth 1 -name "*.deb" -type f 2>/dev/null | wc -l || echo "0")
        # Validate result is numeric
        if ! [[ "${var_apt:-0}" =~ ^[0-9]+$ ]]; then
            var_apt="0"
        fi
    else
        var_apt="0"
    fi
    # ENDIF: var APT cache exists and accessible
    
    if [ -d "${CONTAINER_CONDA_CACHE:-}" ] && [ -x "${CONTAINER_CONDA_CACHE:-}" ]; then
        conda_pkgs=$(find "${CONTAINER_CONDA_CACHE}" -maxdepth 1 -type f 2>/dev/null | wc -l || echo "0")
        # Validate result is numeric
        if ! [[ "${conda_pkgs:-0}" =~ ^[0-9]+$ ]]; then
            conda_pkgs="0"
        fi
    else
        conda_pkgs="0"
    fi
    # ENDIF: container CONDA cache exists and accessible
    
    if [ -d "${CONTAINER_WHEELS_CACHE:-}" ] && [ -x "${CONTAINER_WHEELS_CACHE:-}" ]; then
        wheels=$(find "${CONTAINER_WHEELS_CACHE}" -maxdepth 1 -type f 2>/dev/null | wc -l || echo "0")
        # Validate result is numeric
        if ! [[ "${wheels:-0}" =~ ^[0-9]+$ ]]; then
            wheels="0"
        fi
    else
        wheels="0"
    fi
    # ENDIF: container WHEELS cache exists and accessible
    
    if [ -d "${CONTAINER_JULIA_CACHE:-}" ] && [ -x "${CONTAINER_JULIA_CACHE:-}" ]; then
        julia_pkgs=$(find "${CONTAINER_JULIA_CACHE}" -maxdepth 1 -type f 2>/dev/null | wc -l || echo "0")
        # Validate result is numeric
        if ! [[ "${julia_pkgs:-0}" =~ ^[0-9]+$ ]]; then
            julia_pkgs="0"
        fi
    else
        julia_pkgs="0"
    fi
    # ENDIF: container JULIA cache exists and accessible

    echo "[CACHE MONITOR] Stage: ${stage}"
    echo "${CONTAINER_APT_CACHE:-/unknown}: ${container_apt} .deb files"
    echo "/var/cache/apt/archives: ${var_apt} .deb files"
    echo "${CONTAINER_CONDA_CACHE:-/unknown}: ${conda_pkgs} files"
    echo "${CONTAINER_WHEELS_CACHE:-/unknown}: ${wheels} files"
    echo "${CONTAINER_JULIA_CACHE:-/unknown}: ${julia_pkgs} files"
    echo ""

    # Store data for summary (append to CSV)
    if [ -f "${CACHE_MONITOR_DATA:-}" ]; then
        echo "${stage}|${container_apt}|${var_apt}|${conda_pkgs}|${wheels}|${julia_pkgs}" >> "${CACHE_MONITOR_DATA}"
    fi
    # ENDIF: CACHE_MONITOR_DATA file exists
    
    return 0
}
# End function (self-contained)

#===============================================================================
# SECTION 2: CLEANUP FUNCTIONS
#===============================================================================

#--- Function: purge_container_install_artifacts ---
# Purpose: Remove cached installers and temporary build artifacts from container
# Called before final image creation to reduce image size
# Returns: 0 on success
# Side effects: Removes cache directories and build artifacts
purge_container_install_artifacts() {
    local cache_root="${CONTAINER_CACHE_ROOT:-/container_cache}"
    printf '\n%s\n' "==> Final cleanup: removing cached installers and temporary build artifacts"

    if [ -d "${cache_root}" ] && [ "${cache_root}" != "/" ]; then
        find "${cache_root}" -mindepth 1 -maxdepth 1 -print -exec rm -rf {} + 2>/dev/null || true
        printf '  • Cleared container cache root: %s\n' "${cache_root}"
    else
        printf '  • Container cache root not found or invalid (%s)\n' "${cache_root}"
    fi
    # ENDIF: cache_root exists and is valid

    local tmp_dirs=(
        "${CONTAINER_APT_CACHE:-/container_cache/apt}"
        "${CONTAINER_CONDA_CACHE:-/container_cache/conda_pkgs}"
        "${CONTAINER_WHEELS_CACHE:-/container_cache/wheels}"
        "${CONTAINER_JULIA_CACHE:-/container_cache/julia_pkgs}"
    )
    for dir in "${tmp_dirs[@]}"; do
        if [ -n "${dir}" ] && [ -d "${dir}" ] && [ "${dir}" != "/" ]; then
            rm -rf "${dir}" 2>/dev/null || true
            printf '  • Removed cache directory: %s\n' "${dir}"
        fi
    done
    # ENDFOR: dir in tmp_dirs

    if [ -n "${CONTAINER_BUILD_TMPDIR:-}" ] && [ -d "${CONTAINER_BUILD_TMPDIR}" ]; then
        rm -rf "${CONTAINER_BUILD_TMPDIR}" 2>/dev/null || true
        printf '  • Removed build temp directory: %s\n' "${CONTAINER_BUILD_TMPDIR}"
    fi
    # ENDIF: CONTAINER_BUILD_TMPDIR exists

    if [ -n "${TMPDIR:-}" ] && [[ "${TMPDIR}" == /tmp/* ]] && [ -d "${TMPDIR}" ]; then
        rm -rf "${TMPDIR}" 2>/dev/null || true
        printf '  • Removed TMPDIR artifacts: %s\n' "${TMPDIR}"
    fi
    # ENDIF: TMPDIR exists and is in /tmp

    # Recreate empty cache root so future overlay runs have a mount point
    if [ -n "${cache_root}" ] && [ "${cache_root}" != "/" ]; then
        mkdir -p "${cache_root}" 2>/dev/null || true
        chmod 755 "${cache_root}" 2>/dev/null || true
    fi
    # ENDIF: cache_root is valid

    printf '%s\n' "==> Installer cache cleanup complete"
    return 0
}
# End function (self-contained)

#===============================================================================
# SECTION 3: BUILD HELPER FUNCTIONS
#===============================================================================

#--- Function: calculate_build_jobs ---
# Purpose: Calculate optimal number of parallel build jobs based on CPU and memory
# Returns: Number of jobs (echo'd to stdout)
# Side effects: None (pure function)
# Usage: BUILD_JOBS=$(calculate_build_jobs)
calculate_build_jobs() {
    # Get system resources
    # Declare and assign separately to avoid masking return values (SC2155 compliance)
    local mem_gb
    local cpu_cores

    if command -v free >/dev/null 2>&1; then
        mem_gb=$(free -g | awk '/^Mem:/ {print $2}')
    else
        echo "  ⚠ Warning: 'free' command not available, assuming 4GB RAM" >&2
        mem_gb=4
    # ENDIF: free command availability check
    fi

    if command -v nproc >/dev/null 2>&1; then
        cpu_cores=$(nproc)
    else
        echo "  ⚠ Warning: 'nproc' command not available, assuming 1 CPU core" >&2
        cpu_cores=1
    # ENDIF: nproc command availability check
    fi
    
    # Validate numeric values
    if ! [ "${mem_gb:-0}" -ge 0 ] 2>/dev/null; then
        echo "  ⚠ Warning: Invalid memory value '${mem_gb}', defaulting to 4GB" >&2
        mem_gb=4
    # ENDIF: mem_gb validation check
    fi
    if ! [ "${cpu_cores:-0}" -gt 0 ] 2>/dev/null; then
        echo "  ⚠ Warning: Invalid CPU core count '${cpu_cores}', defaulting to 1" >&2
        cpu_cores=1
    # ENDIF: cpu_cores validation check
    fi
    
    # Calculate jobs based on CPU (use half cores to prevent overload)
    local jobs_by_cpu
    jobs_by_cpu=$((cpu_cores / 2))
    
    # Calculate jobs based on memory (assume 3GB per C++ compilation job for safety)
    # This accounts for template-heavy code like COLMAP, Ceres, OpenCV
    local jobs_by_mem
    jobs_by_mem=$((mem_gb / 3))
    
    # Use the minimum of the two (most conservative)
    local jobs
    jobs=$jobs_by_cpu
    if [ "${jobs_by_mem}" -lt "${jobs}" ]; then
        jobs=$jobs_by_mem
        echo "  ℹ Memory-limited: Using ${jobs} jobs (RAM: ${mem_gb}GB allows ~${jobs} parallel C++ jobs)" >&2
    # ENDIF: memory limitation check
    fi
    
    # Ensure at least 1 job
    if [ "${jobs}" -lt 1 ]; then
        jobs=1
    # ENDIF: minimum jobs check
    fi
    
    # Allow override via environment variable (for testing/debugging)
    if [ -n "${BUILD_JOBS_OVERRIDE:-}" ]; then
        # Validate override is numeric (digits only) and positive
        if [[ "${BUILD_JOBS_OVERRIDE}" =~ ^[0-9]+$ ]] && [ $((10#${BUILD_JOBS_OVERRIDE})) -gt 0 ]; then
            jobs="${BUILD_JOBS_OVERRIDE}"
            echo "  ℹ Override: Using BUILD_JOBS_OVERRIDE=${jobs}" >&2
        else
            echo "  ⚠ Warning: Invalid BUILD_JOBS_OVERRIDE='${BUILD_JOBS_OVERRIDE}', ignoring" >&2
        # ENDIF: BUILD_JOBS_OVERRIDE validation check
        fi
    # ENDIF: BUILD_JOBS_OVERRIDE availability check
    fi
    
    echo "${jobs}"
    return 0
}
# End function (self-contained)

#--- Function: analyze_build_log ---
# Purpose: Analyze build log file for errors, warnings, and issues
# Parameters: $1 = log file path (optional, defaults to BUILD_LOG_FILE)
#             $2 = error log output path (optional, defaults to BUILD_ERROR_LOG)
# Returns: 0 on success
# Side effects: Creates error log file with extracted issues and context
analyze_build_log() {
    # Respect global toggle to avoid expensive parsing when disabled
    if [ "${ENABLE_LOG_ERROR_EXTRACTION:-0}" != "1" ]; then
        return 0
    fi
    # ENDIF: ENABLE_LOG_ERROR_EXTRACTION check
    
    # Determine log and error log file based on context
    local log_file="${1:-${LOG_FILE:-${BUILD_LOG_FILE:-}}}"
    local error_log="${2:-${ERROR_LOG:-${BUILD_ERROR_LOG:-}}}"
    
    # D1: Proper quoting for variables
    if [ -z "${log_file}" ] || [ ! -f "${log_file}" ]; then
        return 0  # No log file to analyze
    fi
    # ENDIF: log_file exists check
    
    if [ -z "${error_log}" ]; then
        return 0  # No error log specified
    fi
    # ENDIF: error_log specified check
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Analyzing build log for errors and warnings..."
    echo "═══════════════════════════════════════════════════════════════"
    
    # J1: Validate parent directory exists before writing to error_log
    local error_log_dir
    error_log_dir=$(dirname "${error_log}")
    if [ ! -d "${error_log_dir}" ]; then
        printf '[WARNING] Parent directory does not exist: %s\n' "${error_log_dir}" >&2
        printf '[INFO] Creating parent directory: %s\n' "${error_log_dir}" >&2
        mkdir -p "${error_log_dir}" || {
            printf '[ERROR] Failed to create parent directory: %s\n' "${error_log_dir}" >&2
            return 1
        }
        printf '[INFO] Parent directory created successfully: %s\n' "${error_log_dir}" >&2
    fi
    # ENDIF: error_log_dir exists
    
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
    # current_context kept for potential future use in context reporting
    # shellcheck disable=SC2034
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
    
    # J1: Validate log_file exists and is readable before reading
    if [ ! -r "${log_file}" ]; then
        printf '[ERROR] Log file not readable: %s\n' "${log_file}" >&2
        return 1
    fi
    # ENDIF: log_file is readable
    
    # First pass: identify all error, warning, debug, and deprecation lines
    while IFS= read -r line || [ -n "${line}" ]; do
        line_num=$((line_num + 1))
        all_lines+=("$line")
        
        # Update context based on line content
        # current_context kept for potential future use in context reporting
        # shellcheck disable=SC2034
        for context_name in "${!context_patterns[@]}"; do
            # K1b: Use -- to prevent pattern misinterpretation if pattern starts with -
            if grep -qiE -- "${context_patterns[$context_name]}" <<< "${line}"; then
                current_context="$context_name"
                context_stack+=("$context_name")
                break
            fi
        done
        # ENDFOR: context_name in context_patterns
        
        # Match error patterns (case-insensitive) - most specific first
        # K1b: Use -- to prevent pattern misinterpretation if pattern starts with -
        if grep -qiE -- \
            '(^[[:space:]]*✗[[:space:]]+|^[[:space:]]*✖[[:space:]]+|^[[:space:]]*❌[[:space:]]+|error:|fatal error|compilation error|link error|build error|install error|runtime error|segmentation.*fault|core.*dump|assertion.*failed|assert.*failed|^ERROR|^FATAL|FAILED|FAILURE|unable to|cannot|missing|undefined reference|undefined symbol|NO SUCH|FILE NOT FOUND|DIRECTORY NOT FOUND|PACKAGE NOT FOUND|command not found|No such file|not found in PATH|exit.*code.*[1-9]|exit.*status.*[1-9]|exit code [1-9]|killed|aborted|abort|terminated|signal.*killed|permission.*denied|access.*denied|read.*only|write.*protect|disk.*full|no.*space|out.*of.*memory|OOM|Out of memory|memory.*exhausted|Cannot allocate|allocation.*failed|stack overflow|buffer.*overflow|null pointer|dereference|corruption|corrupted|invalid|malformed|parse.*error|syntax.*error|type.*error|connection.*refused|connection.*reset|bind.*failed|cannot bind|address.*in use|port.*in use|timeout.*error|deadlock|race.*condition|thread.*error|pthread.*error|mutex.*error|lock.*error|glibc.*error|libc.*error|SSL.*error|TLS.*error|certificate.*error|authentication.*failed|authorization.*failed|key.*not found|key.*invalid|signature.*invalid|checksum.*mismatch|hash.*mismatch|integrity.*failed|verification.*failed|CMake.*error|ninja.*error|make.*error|gcc.*error|g\+\+.*error|clang.*error|ld.*error|linker.*error|ar.*error|ranlib.*error|strip.*error|objcopy.*error|dpkg.*error|apt.*error|pip.*error|conda.*error|python.*error|ImportError|ModuleNotFoundError|AttributeError|NameError|TypeError|ValueError|KeyError|IndexError|RuntimeError|SystemError|OSError|IOError|FileNotFoundError|PermissionError|NotADirectoryError|IsADirectoryError)' <<< "${line}"; then
            # SC2206: Quote to prevent word splitting
            error_line_nums+=("$line_num")
            total_errors=$((total_errors + 1))
        # Match warning patterns (case-insensitive, but not errors)
        # K1b: Use -- to prevent pattern misinterpretation if pattern starts with -
        elif grep -qiE -- \
            '(^[[:space:]]*⚠[[:space:]]+|^[[:space:]]*⚠️[[:space:]]+|^WARNING|warning:|deprecated|obsolete|ignored|skipped|timeout|connection.*timeout|slow|performance.*issue|inefficient|suboptimal|not.*recommended|discouraged|legacy|old.*version|outdated|consider.*upgrading|future.*removal|will.*be.*removed|will.*stop.*working|may.*fail|might.*fail|potential.*issue|possible.*problem|unexpected|unusual|strange|odd|uncommon|rare|seldom|infrequent|minor.*issue|non.*critical|non.*fatal|low.*priority|low.*severity|SSL.*warning|certificate.*warning|authentication.*warning|security.*warning|trust.*warning|insecure|unencrypted|plaintext|unprotected|vulnerability|vulnerable|CVE|exploit|attack|unsafe|risky|hazard|danger|caution|careful|beware|risk|threat|exposure|leak|leaked|exposed|public|private.*key|password.*visible|credential.*exposed|secret.*exposed|token.*exposed|api.*key.*exposed)' <<< "${line}"; then
            # SC2206: Quote to prevent word splitting
            warning_line_nums+=("$line_num")
            total_warnings=$((total_warnings + 1))
        # Match debug flags and diagnostic output (non-fatal but informative)
        # K1b: Use -- to prevent pattern misinterpretation if pattern starts with -
        elif grep -qiE -- \
            '(^\[DEBUG\]|DEBUG:|DEBUG CHECKPOINT|debug checkpoint|debug:|debugging|diagnostic|DIAGNOSTIC|diagnosis|trace|TRACE|tracing|verbose|VERBOSE|VERBOSITY|v=[0-9]|verbosity|log.*level|LOG.*LEVEL|level.*[0-9]|enabling.*debug|debug.*enabled|debug.*mode|development.*mode|dev.*mode|testing.*mode|test.*mode|experimental|EXPERIMENTAL|beta|BETA|alpha|ALPHA|preview|PREVIEW|pre.*release|not.*production|production.*disabled|prod.*disabled|staging|STAGING|unstable|UNSTABLE|work.*in.*progress|WIP|under.*construction|under.*development|TODO|FIXME|XXX|HACK|NOTE:|NOTICE:|INFO:|INFORMATION:|FYI|for.*information|FYI|informational|informational.*message)' <<< "${line}"; then
            # SC2206: Quote to prevent word splitting
            debug_flag_line_nums+=("$line_num")
            total_debug_flags=$((total_debug_flags + 1))
        # Match deprecation warnings (specific pattern for future compatibility issues)
        # K1b: Use -- to prevent pattern misinterpretation if pattern starts with -
        elif grep -qiE -- \
            '(deprecated.*version|deprecated.*in.*version|will.*deprecate|deprecation.*warning|deprecated.*API|deprecated.*function|deprecated.*method|deprecated.*class|deprecated.*module|deprecated.*feature|deprecated.*option|deprecated.*flag|deprecated.*parameter|deprecated.*attribute|deprecated.*property|removed.*in|removal.*planned|EOL|end.*of.*life|end.*of.*support|no.*longer.*supported|discontinued|phase.*out|sunset|sunsetted|legacy.*mode|legacy.*support|backward.*compatibility|breaking.*change|incompatible.*change|API.*change|ABI.*change|interface.*change|signature.*change|behavior.*change)' <<< "${line}"; then
            # SC2206: Quote to prevent word splitting
            deprecation_line_nums+=("$line_num")
            total_deprecations=$((total_deprecations + 1))
        fi
        # ENDIF: error/warning/debug/deprecation pattern matching
    done < "${log_file}"
    # ENDWHILE: read log file
    
    # Second pass: extract error/warning blocks with context
    if [ ${#error_line_nums[@]} -gt 0 ] || [ ${#warning_line_nums[@]} -gt 0 ] || [ ${#debug_flag_line_nums[@]} -gt 0 ] || [ ${#deprecation_line_nums[@]} -gt 0 ]; then
        echo "  Found ${total_errors} error(s), ${total_warnings} warning(s), ${total_debug_flags} debug flag(s), ${total_deprecations} deprecation(s)"
        echo ""
        
        # Combine and sort line numbers
        # SC2207: Use mapfile instead of command substitution for array assignment
        # D3e: Add error handling for pipeline to prevent SIGPIPE issues
        local all_issue_lines
        mapfile -t all_issue_lines < <(printf '%s\n' "${error_line_nums[@]}" "${warning_line_nums[@]}" "${debug_flag_line_nums[@]}" "${deprecation_line_nums[@]}" 2>/dev/null | sort -n 2>/dev/null | uniq 2>/dev/null || true)
        
        local last_extracted_line=0
        # current_context_line kept for potential future use in context tracking
        # shellcheck disable=SC2034
        local current_context_line=0
        
        for issue_line in "${all_issue_lines[@]}"; do
            # Skip if we already extracted this area (within context window)
            # SC2086: Quote arithmetic variables for safety
            # J3: Validate numeric values before comparison
            if [ "${issue_line}" -le "${last_extracted_line}" ] 2>/dev/null; then
                continue
            fi
            # ENDIF: skip already extracted lines
            
            # Determine issue type and severity
            local is_error=false
            local is_warning=false
            local is_debug=false
            local is_deprecation=false
            
            for err_line in "${error_line_nums[@]}"; do
                # SC2086: Quote arithmetic variables for safety
                if [ "${err_line}" -eq "${issue_line}" ] 2>/dev/null; then
                    is_error=true
                    break
                fi
            done
            # ENDFOR: err_line in error_line_nums
            
            if [ "${is_error}" != true ]; then
                for warn_line in "${warning_line_nums[@]}"; do
                    # SC2086: Quote arithmetic variables for safety
                    if [ "${warn_line}" -eq "${issue_line}" ] 2>/dev/null; then
                        is_warning=true
                        break
                    fi
                done
                # ENDFOR: warn_line in warning_line_nums
            fi
            # ENDIF: not an error
            
            if [ "${is_error}" != true ] && [ "${is_warning}" != true ]; then
                for debug_line in "${debug_flag_line_nums[@]}"; do
                    # SC2086: Quote arithmetic variables for safety
                    if [ "${debug_line}" -eq "${issue_line}" ] 2>/dev/null; then
                        is_debug=true
                        break
                    fi
                done
                # ENDFOR: debug_line in debug_flag_line_nums
            fi
            # ENDIF: not error or warning
            
            if [ "${is_error}" != true ] && [ "${is_warning}" != true ] && [ "${is_debug}" != true ]; then
                for dep_line in "${deprecation_line_nums[@]}"; do
                    # SC2086: Quote arithmetic variables for safety
                    if [ "${dep_line}" -eq "${issue_line}" ] 2>/dev/null; then
                        is_deprecation=true
                        break
                    fi
                done
                # ENDFOR: dep_line in deprecation_line_nums
            fi
            # ENDIF: not error, warning, or debug
            
            # Find the most recent context before this line
            local context_for_issue="General Build"
            local i
            i=$((issue_line - 1))
            # J3: Validate i and issue_line are numeric before arithmetic
            while [ "${i}" -gt 0 ] 2>/dev/null && [ "${i}" -gt $((issue_line - 50)) ] 2>/dev/null; do
                for context_name in "${!context_patterns[@]}"; do
                    # J3: Validate array bounds before access
                    if [ "${i}" -le ${#all_lines[@]} ] 2>/dev/null && [ "${i}" -ge 1 ] 2>/dev/null; then
                        local idx
                        idx=$((i - 1))
                        if [ "${idx}" -ge 0 ] 2>/dev/null && [ "${idx}" -lt ${#all_lines[@]} ] 2>/dev/null; then
                            # K1b: Use -- to prevent pattern misinterpretation if pattern starts with -
                            if grep -qiE -- "${context_patterns[$context_name]}" <<< "${all_lines[$idx]}" 2>/dev/null; then
                                context_for_issue="${context_name}"
                                break 2
                            fi
                        fi
                    fi
                done
                # ENDFOR: context_name in context_patterns
                i=$((i - 1))
            done
            # ENDWHILE: find context
            
            # Calculate context range
            # J3: Validate arithmetic operations
            local start_line
            if [ "${issue_line}" -ge 1 ] 2>/dev/null && [ "${context_lines}" -ge 0 ] 2>/dev/null; then
                start_line=$((issue_line - context_lines))
                if [ "${start_line}" -lt 1 ] 2>/dev/null; then
                    start_line=1
                fi
            else
                start_line=1
            fi
            # ENDIF: start_line validation
            
            local end_line
            if [ "${issue_line}" -ge 1 ] 2>/dev/null && [ "${context_lines}" -ge 0 ] 2>/dev/null && [ ${#all_lines[@]} -gt 0 ] 2>/dev/null; then
                end_line=$((issue_line + context_lines))
                if [ "${end_line}" -gt ${#all_lines[@]} ] 2>/dev/null; then
                    end_line=${#all_lines[@]}
                fi
            else
                end_line=${#all_lines[@]}
            fi
            # ENDIF: end_line validation
            
            # Write block header (append to error_log)
            # J1: Parent directory already validated above, safe to append
            {
                echo "───────────────────────────────────────────────────────────"
                if [ "${is_error}" = true ]; then
                    echo "[ERROR] Line ${issue_line} | Context: ${context_for_issue}"
                elif [ "${is_warning}" = true ]; then
                    echo "[WARNING] Line ${issue_line} | Context: ${context_for_issue}"
                elif [ "${is_deprecation}" = true ]; then
                    echo "[DEPRECATION] Line ${issue_line} | Context: ${context_for_issue}"
                elif [ "${is_debug}" = true ]; then
                    echo "[DEBUG FLAG] Line ${issue_line} | Context: ${context_for_issue}"
                else
                    echo "[ISSUE] Line ${issue_line} | Context: ${context_for_issue}"
                fi
                echo "───────────────────────────────────────────────────────────"
                echo ""
                
                # Extract context block (0-indexed array, so subtract 1)
                # J3: Validate start_line and end_line are numeric before using in seq
                local i
                if [ "${start_line}" -ge 1 ] && [ "${end_line}" -ge "${start_line}" ] 2>/dev/null; then
                    for i in $(seq "${start_line}" "${end_line}" 2>/dev/null || true); do
                        local idx
                        idx=$((i - 1))
                        if [ "${idx}" -ge 0 ] && [ "${idx}" -lt ${#all_lines[@]} ] 2>/dev/null; then
                            local marker=""
                            if [ "${i}" -eq "${issue_line}" ] 2>/dev/null; then
                                marker=" >>> "
                            elif [ "${i}" -lt "${issue_line}" ] 2>/dev/null; then
                                marker="     "
                            else
                                marker="     "
                            fi
                            printf "%6d%s%s\n" "${i}" "${marker}" "${all_lines[$idx]}"
                        fi
                    done
                    # ENDFOR: i in context range
                fi
                # ENDIF: start_line and end_line validation
                echo ""
                echo ""
            } >> "${error_log}"
            
            # J3: Validate end_line is numeric before assignment
            if [ "${end_line}" -ge 0 ] 2>/dev/null; then
                last_extracted_line=${end_line}
            fi
            # ENDIF: end_line validation
        done
        # ENDFOR: issue_line in all_issue_lines
        
        echo "  ✓ Error log analysis complete: ${error_log}"
    else
        echo "  ✓ No errors or warnings found in build log"
        # J1: Parent directory already validated above, safe to append
        {
            echo "No errors or warnings detected in build log."
            echo ""
            echo "This does not guarantee a successful build - check the full"
            echo "build log for any issues that may not match standard patterns."
        } >> "${error_log}"
    fi
    # ENDIF: issues found
    
    # Append summary
    # J1: Parent directory already validated above, safe to append
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
    return 0
}
# End function (self-contained)

#===============================================================================
# SECTION 6: DIRECTORY WRITABILITY ENFORCEMENT (BLOCK 8.3)
#===============================================================================

#--- Function: ensure_directory_writable ---
# Purpose: Ensure directory is actually writable (not just permission check)
#          Tests actual file creation, not just permission bits
#          Handles container overlay filesystem restrictions
# Arguments: $1 = directory path, $2 = description (optional)
# Returns: 0 on success, 1 on failure
# Side effects: Creates directory, fixes permissions, tests writability
ensure_directory_writable() {
    local dir_path="${1:-}"
    local description="${2:-${dir_path}}"
    
    if [ -z "${dir_path}" ]; then
        printf '%s\n' "[ERROR] ⚠ Directory path not provided" >&2
        return 1
    fi
    
    # Create directory if it doesn't exist
    if [ ! -d "${dir_path}" ]; then
        if ! mkdir -p "${dir_path}" 2>/dev/null; then
            printf '%s\n' "[ERROR] ⚠ Failed to create directory: ${description} (${dir_path})" >&2
            return 1
        fi
    fi
    
    # Ensure parent directory is writable (critical for nested paths)
    local parent_dir
    parent_dir="$(dirname "${dir_path}")"
    if [ "${parent_dir}" != "${dir_path}" ] && [ -d "${parent_dir}" ]; then
        chmod 755 "${parent_dir}" 2>/dev/null || true
        # Test parent writability
        local parent_test="${parent_dir}/.parent_test_$$"
        if ! touch "${parent_test}" 2>/dev/null; then
            printf '%s\n' "[WARN] ⚠ Parent directory may not be writable: ${parent_dir}" >&2
        else
            rm -f "${parent_test}" 2>/dev/null || true
        fi
    fi
    
    # Fix permissions explicitly
    if ! chmod 755 "${dir_path}" 2>/dev/null; then
        printf '%s\n' "[WARN] ⚠ Failed to set permissions on: ${description} (${dir_path})" >&2
    fi
    
    # CRITICAL: Test actual writability (not just permission check)
    # Container overlay filesystems can have correct permissions but fail writes
    local test_file="${dir_path}/.writability_test_$$"
    if ! touch "${test_file}" 2>/dev/null; then
        printf '%s\n' "[ERROR] ⚠ Directory appears writable but test file creation failed: ${description} (${dir_path})" >&2
        printf '%s\n' "  This indicates container mount restrictions - writes will fail silently" >&2
        printf '%s\n' "" >&2
        printf '%s\n' "  === DIAGNOSTIC INFORMATION ===" >&2
        printf '%s\n' "  Directory permissions:" >&2
        ls -ld "${dir_path}" 2>/dev/null || true
        printf '%s\n' "" >&2
        printf '%s\n' "  Filesystem type and mount options:" >&2
        df -T "${dir_path}" 2>/dev/null || true
        printf '%s\n' "" >&2
        printf '%s\n' "  Mount information (all mounts):" >&2
        mount | grep -E "$(echo "${dir_path}" | sed 's|/|\\/|g')" || printf '%s\n' "    (no relevant mounts found)"
        printf '%s\n' "" >&2
        printf '%s\n' "  Parent directory mount info:" >&2
        local parent_dir
        parent_dir="$(dirname "${dir_path}")"
        if [ "${parent_dir}" != "${dir_path}" ]; then
            mount | grep -E "$(echo "${parent_dir}" | sed 's|/|\\/|g')" || printf '%s\n' "    (no relevant mounts found)"
        fi
        printf '%s\n' "" >&2
        printf '%s\n' "  Container detection:" >&2
        if [ -n "${SINGULARITY_NAME:-}" ]; then
            printf '%s\n' "    SINGULARITY_NAME=${SINGULARITY_NAME}"
        fi
        if [ -n "${APPTAINER_NAME:-}" ]; then
            printf '%s\n' "    APPTAINER_NAME=${APPTAINER_NAME}"
        fi
        if [ -f "/.singularity.d/runscript" ]; then
            printf '%s\n' "    Singularity container detected (/.singularity.d/runscript exists)"
        fi
        if [ -f "/.apptainer.d/runscript" ]; then
            printf '%s\n' "    Apptainer container detected (/.apptainer.d/runscript exists)"
        fi
        printf '%s\n' "" >&2
        printf '%s\n' "  === TROUBLESHOOTING ===" >&2
        printf '%s\n' "  If using Singularity/Apptainer, check:" >&2
        printf '%s\n' "    1. Container build command includes --writable or --fakeroot" >&2
        printf '%s\n' "    2. No read-only bind mounts are overriding this directory" >&2
        printf '%s\n' "    3. Overlay filesystem is properly configured" >&2
        printf '%s\n' "    4. User has sufficient permissions in the host filesystem" >&2
        printf '%s\n' "" >&2
        return 1
    fi
    
    # Clean up test file
    rm -f "${test_file}" 2>/dev/null || true
    return 0
}
# ENDFUNC: ensure_directory_writable

# Export function for use in subshells if needed
export -f ensure_directory_writable

#===============================================================================
# END OF COMMON FUNCTIONS
#===============================================================================
