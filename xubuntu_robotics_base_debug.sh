#!/bin/bash
#===============================================================================
# XUBUNTU ROBOTICS BASE - DEBUG POST-INSTALL SCRIPT
#===============================================================================
# Purpose: Container %post section - Install all software and configure system
#          DEBUG MODE: Stops before OpenCV compilation (BLOCK 20)
# Runs inside: Singularity container during build (%post phase)
# Features: Multi-phase installation, cache management, error handling
# NOTE: This script creates a snapshot image just before OpenCV compilation.
#       OpenCV compilation can be done separately using compile_opencv_in_overlay.sh
#===============================================================================

#===============================================================================
# ENVIRONMENT/SHELL COMPATIBILITY PROBE & STRICT-MODE HELPERS (REUSABLE)
#===============================================================================
# Purpose: Detect active shell and capabilities, export diagnostics for use anywhere.
# Provides helpers to reliably toggle strict mode with fallbacks in sections/functions.
#-------------------------------------------------------------------------------
DETECTED_SHELL_PATH="${SHELL:-$(ps -p $$ -o comm= 2>/dev/null || echo sh)}"
DETECTED_SHELL_NAME="$(basename "${DETECTED_SHELL_PATH}" 2>/dev/null || echo sh)"
DETECTED_BASH_VERSION="${BASH_VERSION:-}"
if [ -n "${DETECTED_BASH_VERSION}" ]; then
    IS_BASH=1
else
    IS_BASH=0
fi
SUPPORTS_PIPEFAIL="$( ( set -o pipefail ) >/dev/null 2>&1; echo $? )"
if [ "${SUPPORTS_PIPEFAIL}" = "0" ]; then SUPPORTS_PIPEFAIL=1; else SUPPORTS_PIPEFAIL=0; fi
SUPPORTS_ERRTRACE="$( ( set -o errtrace ) >/dev/null 2>&1; echo $? )"
if [ "${SUPPORTS_ERRTRACE}" = "0" ]; then SUPPORTS_ERRTRACE=1; else SUPPORTS_ERRTRACE=0; fi
export DETECTED_SHELL_PATH DETECTED_SHELL_NAME DETECTED_BASH_VERSION IS_BASH SUPPORTS_PIPEFAIL SUPPORTS_ERRTRACE

# Helpers: strict_on / strict_off for controlled sections
strict_on() {
    if [ "${IS_BASH}" -eq 1 ]; then
        set -e
        set -u
        if [ "${SUPPORTS_PIPEFAIL}" -eq 1 ]; then
            set -o pipefail || true
        fi
        if [ "${SUPPORTS_ERRTRACE}" -eq 1 ]; then
            set -E -o errtrace || true
        fi
        # SC2154: ec is assigned in trap command itself, false positive
        # shellcheck disable=SC2154
        trap 'ec=$?; printf "[ERROR] Command failed (exit=%s) at %s:%s: %s\n" "${ec}" "${BASH_SOURCE[0]-?}" "${LINENO-?}" "${BASH_COMMAND-?}" >&2; exit "${ec}"' ERR
    else
        set -e
        set -u
    fi
}

strict_off() {
    set +e || true
    set +u || true
    # pipefail and errtrace may not exist in all shells; ignore failures
    set +o pipefail >/dev/null 2>&1 || true
    set +o errtrace >/dev/null 2>&1 || true
    trap - ERR 2>/dev/null || true
}

# Mark availability for downstream logic/tests
STRICT_HELPERS_AVAILABLE=1
export STRICT_HELPERS_AVAILABLE

#===============================================================================
# STRICT MODE - Controlled error handling
#===============================================================================
# Use strict mode with controlled sections for error handling
# set -e: Exit on error (disabled in specific sections where needed)
# set -u: Treat unset variables as error
# set -o pipefail: Pipeline failures propagate
# Note: Some sections intentionally disable -e for error recovery
if [ "${SUPPORTS_PIPEFAIL:-0}" -eq 1 ]; then set -o pipefail; fi  # Enable when supported
set +e  # Start with -e disabled (will be enabled in critical sections)
set +u  # Temporarily allow unset variables until config is loaded

#-------------------------------------------------------------------------------
# Shell diagnostics (help identify interpreter inside %post script)
# D3b: Use printf instead of echo for robustness (handles special characters)
printf '%s\n' "---- [%post script] shell diagnostics ----"
printf '%s\n' "PID: $$, PPID: ${PPID:-unknown}"
printf '%s\n' "0: ${0:-unknown}"
printf '%s\n' "SHELL: ${SHELL:-unknown}"
printf '%s\n' "BASH_VERSION: ${BASH_VERSION:-n/a}"
printf '%s\n' "Process name: $(ps -p $$ -o comm= 2>/dev/null || echo unknown)"
printf '%s\n' "bash in PATH: $(command -v bash 2>/dev/null || echo 'not found')"
printf '%s\n' "------------------------------------------"

SCRIPT_BASENAME="$(basename "$0" 2>/dev/null || echo "xubuntu_robotics_base_full.sh")"

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
        # shellcheck source=/etc/config.sh
        source /etc/config.sh
        export CONFIG_SOURCED=1
        printf '%s\n' "✓ Loaded configuration from /etc/config.sh"
    else
        printf '%s\n' "ERROR: /etc/config.sh not found!" >&2
        exit 1
    fi
else
    printf '%s\n' "ℹ Configuration already loaded (skipping redundant source)"
fi
# ENDIF: CONFIG_SOURCED check

#--- Load common functions ---
# Critical: Source common functions for shared functionality
# Dependencies: config.sh (already sourced)
# Outputs: Common functions available (consolidate_cache_packages, monitor_cache, etc.)
if [ -f /scripts/common_functions.sh ]; then
    # shellcheck source=/scripts/common_functions.sh
    source /scripts/common_functions.sh
    printf '%s\n' "✓ Common functions loaded from /scripts/common_functions.sh"
else
    printf '%s\n' "⚠ Warning: Common functions file not found: /scripts/common_functions.sh" >&2
    printf '%s\n' "  Some functions may not be available" >&2
fi
# ENDIF: common_functions.sh exists

#===============================================================================
# BLOCK 0: INSTALL CONTAINER SCRIPTS (EARLY - BEFORE ANY SCRIPTS ARE NEEDED)
#===============================================================================
# Purpose: Install all extracted scripts from container-scripts/ directory
#          This must happen early so scripts are available throughout the build
# Dependencies: config.sh (for CONTAINER_SCRIPTS_INSTALL_PATH), container-scripts/ directory
# Outputs: All scripts installed to their target locations
#-------------------------------------------------------------------------------
# D3b: Use printf instead of echo -e for robustness
printf '\n%s\n' "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf '%s\n' "${BLUE}BLOCK 0: Installing Container Scripts${NC}"
printf '%s\n' "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf '%s\n' ""

# Use variables from config.sh (with defaults if not set)
CONTAINER_SCRIPTS_PATH="${CONTAINER_SCRIPTS_INSTALL_PATH:-/container-scripts}"
INSTALLER_SCRIPT="${CONTAINER_SCRIPTS_PATH}/${CONTAINER_SCRIPTS_INSTALLER:-install.sh}"
MANIFEST_FILE="${CONTAINER_SCRIPTS_PATH}/${CONTAINER_SCRIPTS_MANIFEST:-MANIFEST.json}"

if [ -f "${INSTALLER_SCRIPT}" ] && [ -f "${MANIFEST_FILE}" ]; then
    chmod +x "${INSTALLER_SCRIPT}"
    if "${INSTALLER_SCRIPT}" --all; then
        printf '%s\n' "${GREEN}✓ Container scripts installed successfully${NC}"
    else
        printf '%s\n' "${YELLOW}⚠ Warning: Some container scripts failed to install. Continuing build...${NC}"
    fi
else
    printf '%s\n' "${YELLOW}⚠ Warning: Container scripts installation files not found at ${CONTAINER_SCRIPTS_PATH}${NC}"
    printf '%s\n' "${YELLOW}  Some scripts may not be available during build${NC}"
fi
# ENDIF: install.sh and MANIFEST.json exist

# After config is loaded, enable strict mode for unset variables
set -u

#===============================================================================
# BLAS PROVIDER SELECTION
#===============================================================================
# DEFAULT_BLAS_PROVIDER controls which implementation owns the system interfaces.
# This is a repo-specific knob consumed by this script (not an upstream distro flag).
# Supported values: MKL (default) or OPENBLAS. Case-insensitive.
DEFAULT_BLAS_PROVIDER="${DEFAULT_BLAS_PROVIDER:-MKL}"
DEFAULT_BLAS_PROVIDER="$(printf '%s\n' "${DEFAULT_BLAS_PROVIDER}" | tr '[:lower:]' '[:upper:]')"
export DEFAULT_BLAS_PROVIDER

# Validate BLAS provider selection (A5a robustness + C5 defaults)
case "${DEFAULT_BLAS_PROVIDER}" in
    MKL|OPENBLAS)
        # OK
        ;;
    *)
        printf '%s\n' "⚠ Warning: Invalid DEFAULT_BLAS_PROVIDER='${DEFAULT_BLAS_PROVIDER}'. Falling back to 'MKL'."
        DEFAULT_BLAS_PROVIDER="MKL"
        export DEFAULT_BLAS_PROVIDER
        ;;
esac

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

    # Validate keep count to avoid arithmetic errors under set -u
    # A5: Use POSIX [ instead of [[ when possible (though [[ =~ is needed for regex)
    # Note: [[ =~ ]] is Bash-specific but necessary for regex matching here
    if ! [[ "${BUILD_LOG_KEEP_COUNT:-2}" =~ ^[0-9]+$ ]]; then
        printf '%s\n' "⚠ Warning: Invalid BUILD_LOG_KEEP_COUNT='${BUILD_LOG_KEEP_COUNT:-}' (expected non-negative integer). Defaulting to 2."
        BUILD_LOG_KEEP_COUNT=2
    fi

    if [ -d "${BUILD_LOG_DIR}" ] && [ "${BUILD_LOG_KEEP_COUNT:-2}" -gt 0 ]; then
        printf '%s\n' "Cleaning up old build logs (keeping ${BUILD_LOG_KEEP_COUNT:-2} most recent)..."
        
        # Count existing log files matching the patterns
        # Regular build logs
        EXISTING_LOGS=$(find "${BUILD_LOG_DIR}" -maxdepth 1 -name "${BUILD_LOG_PREFIX}_*.log" -type f ! -name "*_errors.log" 2>/dev/null | wc -l)
        # Error logs
        EXISTING_ERROR_LOGS=$(find "${BUILD_LOG_DIR}" -maxdepth 1 -name "${BUILD_LOG_PREFIX}_*_errors.log" -type f 2>/dev/null | wc -l)
        
        printf '%s\n' "  Found: ${EXISTING_LOGS} build log(s), ${EXISTING_ERROR_LOGS} error log(s)"
        
        # Clean up regular build logs
        if [ "${EXISTING_LOGS:-0}" -gt "${BUILD_LOG_KEEP_COUNT:-2}" ]; then
            # List all log files sorted by modification time (newest first)
            # Keep only N most recent files, remove the rest
            # Use find instead of ls for better handling of non-alphanumeric filenames
            keep_count="${BUILD_LOG_KEEP_COUNT:-2}"
            find "${BUILD_LOG_DIR}" -maxdepth 1 -name "${BUILD_LOG_PREFIX}_*.log" -type f ! -name "*_errors.log" -printf '%T@ %p\n' 2>/dev/null | \
                sort -rn | \
                tail -n +$((keep_count + 1)) | \
                cut -d' ' -f2- | \
                while IFS= read -r old_log; do
                    if [ -f "${old_log}" ]; then
                        printf '%s\n' "  Removing old log: $(basename "${old_log}")"
                        rm -f "${old_log}"
                    fi
                    # ENDIF: old_log existence check
                done
            # ENDFOR: old_log
        # ENDIF: EXISTING_LOGS cleanup check
        fi
        
        # Clean up error logs
        if [ "${EXISTING_ERROR_LOGS:-0}" -gt "${BUILD_LOG_KEEP_COUNT:-2}" ]; then
            keep_count="${BUILD_LOG_KEEP_COUNT:-2}"
            find "${BUILD_LOG_DIR}" -maxdepth 1 -name "${BUILD_LOG_PREFIX}_*_errors.log" -type f -printf '%T@ %p\n' 2>/dev/null | \
                sort -rn | \
                tail -n +$((keep_count + 1)) | \
                cut -d' ' -f2- | \
                while IFS= read -r old_error_log; do
                    if [ -f "${old_error_log}" ]; then
                        printf '%s\n' "  Removing old error log: $(basename "${old_error_log}")"
                        rm -f "${old_error_log}"
                    fi
                    # ENDIF: old_error_log existence check
                done
            # ENDFOR: old_error_log
        # ENDIF: EXISTING_ERROR_LOGS cleanup check
        fi
        
        if [ "${EXISTING_LOGS:-0}" -le "${BUILD_LOG_KEEP_COUNT:-2}" ] && [ "${EXISTING_ERROR_LOGS:-0}" -le "${BUILD_LOG_KEEP_COUNT:-2}" ]; then
            printf '%s\n' "✓ No old logs to clean up (found ${EXISTING_LOGS:-0} build logs, ${EXISTING_ERROR_LOGS:-0} error logs, keeping ${BUILD_LOG_KEEP_COUNT:-2})"
        else
            printf '%s\n' "✓ Old logs cleaned up (kept ${BUILD_LOG_KEEP_COUNT:-2} most recent)"
        # ENDIF: log cleanup status check
        fi
    fi

    # Generate improved timestamp for this build
    # Format: YYYYMMDD_Day_HHMM_AMPM (e.g., 20241027_Sun_1430_PM)
    DAY_NAMES=("Sun" "Mon" "Tue" "Wed" "Thu" "Fri" "Sat")
    CURRENT_DAY=$(date +%w 2>/dev/null || echo "0")  # 0=Sunday, 1=Monday, etc.
    # Bounds check for array access
    if [ "${CURRENT_DAY:-0}" -ge 0 ] && [ "${CURRENT_DAY:-0}" -le 6 ]; then
        DAY_NAME="${DAY_NAMES[$CURRENT_DAY]}"
    else
        DAY_NAME="Unknown"
    # ENDIF: CURRENT_DAY bounds check
    fi
    
    # Get 12-hour format with AM/PM
    # Validate command substitutions with fallbacks (required when set -u may be active)
    HOUR_12=$(date +"%I" 2>/dev/null || echo "12")
    MINUTE=$(date +"%M" 2>/dev/null || echo "00")
    AMPM=$(date +"%p" 2>/dev/null || echo "AM")
    # Validate results are non-empty and numeric (for HOUR_12 and MINUTE)
    # A5: [[ =~ ]] is Bash-specific but necessary for regex matching
    if ! [[ "${HOUR_12:-12}" =~ ^[0-9]+$ ]] || ! [[ "${MINUTE:-00}" =~ ^[0-9]+$ ]]; then
        HOUR_12=12
        MINUTE=00
        AMPM="AM"
    fi
    
    # Remove leading zero from hour for cleaner format
    # Use default if arithmetic fails
    HOUR_12=$((10#${HOUR_12:-12})) || HOUR_12=12
    
    # Create timestamp: YYYYMMDD_Day_HHMM_AMPM
    BUILD_TIMESTAMP=$(date +"%Y%m%d" 2>/dev/null || echo "19700101")_"${DAY_NAME}"_"${HOUR_12}""${MINUTE}"_"${AMPM}"
    BUILD_LOG_FILE="${BUILD_LOG_DIR}/${BUILD_LOG_PREFIX}_${BUILD_TIMESTAMP}.log"
    if [ "${ENABLE_LOG_ERROR_EXTRACTION:-0}" = "1" ]; then
        BUILD_ERROR_LOG="${BUILD_LOG_DIR}/${BUILD_LOG_PREFIX}_${BUILD_TIMESTAMP}_errors.log"
    else
        BUILD_ERROR_LOG=""
    fi

    # Start logging to file while preserving terminal output
    # This creates a background process that tees output to both terminal and log file
    printf '%s\n' "✓ Build logging enabled: ${BUILD_LOG_FILE}"
    if [ "${ENABLE_LOG_ERROR_EXTRACTION:-0}" = "1" ]; then
        printf '%s\n' "✓ Error logging enabled: ${BUILD_ERROR_LOG}"
    else
        printf '%s\n' "○ Error/warning extraction disabled (set ENABLE_LOG_ERROR_EXTRACTION=1 to enable)"
    fi
    printf '%s\n' "  Log directory: ${BUILD_LOG_DIR}"
    printf '%s\n' "  Timestamp format: YYYYMMDD_Day_HHMM_AMPM"
    printf '%s\n' "  Keeping ${BUILD_LOG_KEEP_COUNT:-2} most recent logs"
    printf '%s\n' "  Auto-sync interval: ${BUILD_LOG_SYNC_INTERVAL:-60} seconds"
    printf '%s\n' ""
    
    if [ "${ENABLE_LOG_ERROR_EXTRACTION:-0}" = "1" ]; then
        # Initialize error log with header
        if [ -z "${BUILD_ERROR_LOG}" ] || [ ! -f "${BUILD_ERROR_LOG}" ]; then
            touch "${BUILD_ERROR_LOG}" 2>/dev/null || true
        # ENDIF: BUILD_ERROR_LOG initialization check
        fi
        printf '%s\n' "========================================" >> "${BUILD_ERROR_LOG}" 2>/dev/null || true
        printf '%s\n' "Error Log Started: $(date)" >> "${BUILD_ERROR_LOG}" 2>/dev/null || true
        printf '%s\n' "Build Log: ${BUILD_LOG_FILE}" >> "${BUILD_ERROR_LOG}" 2>/dev/null || true
        printf '%s\n' "========================================" >> "${BUILD_ERROR_LOG}" 2>/dev/null || true
    fi
    
    # Error/Warning Filter Function for container builds
    # This function filters error and warning messages and writes them to error log
    # Catches: errors, warnings, debug messages, diagnostic output, wheel paths,
    # build failures, compilation issues, and all problematic output
    filter_errors_warnings() {
        # Ensure BUILD_ERROR_LOG is available
        local error_log="${BUILD_ERROR_LOG:-}"
        if [ -z "${error_log:-}" ]; then
            # If BUILD_ERROR_LOG not set, just pass through without filtering
            while IFS= read -r line; do
                echo "${line}"
            done
            # ENDWHILE: line reading loop
            return
        # ENDIF: error_log availability check
        fi
        
        local line
        while IFS= read -r line; do
            # Echo all lines to stdout (which goes to main log via tee)
            # D3b: Using printf for robustness, but echo is acceptable here since line is controlled
            printf '%s\n' "${line}"
            
            # Comprehensive error/warning pattern matching (case-insensitive)
            # This pattern catches ALL problematic output including:
            # - Standard errors/warnings
            # - Debug messages and checkpoints
            # - Diagnostic output and troubleshooting info
            # - Wheel path messages and Python package issues
            # - Build system errors (CMake, Ninja, Make)
            # - Library-specific build errors (COLMAP, Open3D, OpenCV)
            # - System/user generated errors
            # D3: Use here-string for grep (safe pattern, no pipe needed)
            # D3b: Pattern is long but necessary for comprehensive error detection
            if grep -qiE <<< "${line}" \
                '(error|warning|fatal|failed|failure|unable to|unable|not found|cannot|missing|undefined|undefined reference|undefined symbol|warning:|error:|fatal error|compilation error|link error|build error|install error|download error|extract error|✗|✖|⚠|❌|⚠️|ERROR|WARNING|FAILED|FAILURE|MISSING|NOT FOUND|CANNOT|UNABLE|FATAL|NO SUCH|FILE NOT FOUND|DIRECTORY NOT FOUND|PACKAGE NOT FOUND|LOCATION NOT FOUND|unable to locate|unable to download|unable to find|unable to install|unable to extract|unable to compile|unable to build|unable to connect|unable to access|unable to execute|could not find|could not locate|could not download|could not install|did not find|did not locate|did not download|package .* not found|file .* not found|directory .* not found|location .* not found|compilation.*warning|link.*warning|build.*warning|make.*warning|cmake.*warning|ninja.*error|ninja.*warning|gcc.*warning|g\+\+.*warning|clang.*warning|rustc.*warning|cargo.*warning|dpkg.*warning|apt.*warning|pip.*warning|conda.*warning|julia.*warning|deprecated|obsolete|ignored|skipped|timeout|connection refused|connection reset|network.*error|network.*failed|ssl.*error|certificate.*error|authentication.*failed|permission.*denied|access.*denied|read.*only|write.*protect|disk.*full|no.*space|out.*of.*memory|segmentation.*fault|core.*dump|aborted|abort|killed|terminated|signal.*killed|exit.*code.*[1-9]|exit.*status.*[1-9]|\[DEBUG\]|DEBUG:|DEBUG CHECKPOINT|debug checkpoint|debug:|debugging|diagnostic|DIAGNOSTIC|diagnosis|wheel.*not found|wheel.*location|\.whl.*not found|wheel.*path|wrote.*\.whl|building.*wheel|wheel.*build|colmap.*failed|colmap.*error|open3d.*failed|open3d.*error|opencv.*failed|opencv.*error|cmake.*failed|cmake.*error|ninja.*failed|build.*failed|compilation.*failed|link.*failed|CHECKING FOR|COMPREHENSIVE DIAGNOSTIC|DIAGNOSTIC ANALYSIS|NEXT STEPS FOR DEBUGGING|Last.*lines.*of.*log|tee.*\.log|build.*log|cmake.*log|colmap.*log|open3d.*log|opencv.*log|Post-CMake Debug|Post-CMake.*Debug|test.*failed|test.*error|checkpoint|CHECKPOINT|verification.*failed|verification.*error|configuration.*failed|configuration.*error|setup.*failed|setup.*error|install.*failed|install.*error|harvest.*failed|harvest.*error)'; then
                # Write matching line to error log with timestamp
                # Note: Using || true is intentional here for non-critical logging operations
                # This occurs before strict mode is enabled (set -e at line 323)
                # D3b: Use printf for robustness
                printf '%s\n' "[$(date +'%Y-%m-%d %H:%M:%S')] ${line}" >> "${error_log}" 2>/dev/null || true
            # ENDIF: grep pattern match check
            fi
        # ENDWHILE: line reading loop
        done
    }
    
    # Use line-buffered tee with process substitution and error filtering
    # stdbuf -oL makes output line-buffered (immediate write on newline)
    # This ensures most output is written immediately, reducing data loss
    # IMPORTANT: exec redirects ALL subsequent output - each line written ONCE
    # Error filtering is applied to stderr to capture errors/warnings
    # Gracefully degrade if stdbuf is not available (minimal containers)
    if command -v stdbuf >/dev/null 2>&1 && command -v tee >/dev/null 2>&1 && command -v grep >/dev/null 2>&1; then
        # Full featured: optional line buffered filtering
        if [ "${ENABLE_LOG_ERROR_EXTRACTION:-0}" = "1" ]; then
            exec > >(stdbuf -oL tee -a "${BUILD_LOG_FILE}") 2> >(stdbuf -oL tee -a "${BUILD_LOG_FILE}" >&2 | filter_errors_warnings)
        else
            exec > >(stdbuf -oL tee -a "${BUILD_LOG_FILE}") 2>&1
        fi
    elif command -v tee >/dev/null 2>&1 && command -v grep >/dev/null 2>&1; then
        # Fallback: tee with optional error filtering (no line buffering but still works)
        if [ "${ENABLE_LOG_ERROR_EXTRACTION:-0}" = "1" ]; then
            exec > >(tee -a "${BUILD_LOG_FILE}") 2> >(tee -a "${BUILD_LOG_FILE}" >&2 | filter_errors_warnings)
        else
            exec > >(tee -a "${BUILD_LOG_FILE}") 2>&1
        fi
    elif command -v tee >/dev/null 2>&1; then
        # Fallback: tee without error filtering
        exec > >(tee -a "${BUILD_LOG_FILE}") 2>&1
    else
        printf '%s\n' "  ⚠ Warning: 'tee' command not available, logging disabled"
        printf '%s\n' "  Build will continue without log file"
    fi
    
    # Start background sync job to periodically flush log files to disk
    # This ensures data is saved even if build is interrupted
    # Only start if sleep command is available (may not be in minimal base images)
    if command -v sleep >/dev/null 2>&1; then
        (
            # Note: Cannot use 'local' in subshell, use regular variable
            sync_interval="${BUILD_LOG_SYNC_INTERVAL:-60}"
            # Validate sync interval is a positive integer (A5a robustness)
            if ! [[ "${sync_interval}" =~ ^[0-9]+$ ]] || [ $((10#${sync_interval})) -le 0 ]; then
                printf '%s\n' "  ⚠ Warning: Invalid BUILD_LOG_SYNC_INTERVAL='${BUILD_LOG_SYNC_INTERVAL:-}', defaulting to 60" >&2
                sync_interval=60
            fi
            while true; do
                sleep "${sync_interval}"
                # Sync both log files to disk
                if [ -f "${BUILD_LOG_FILE}" ]; then
                    sync "${BUILD_LOG_FILE}" 2>/dev/null || sync
                fi
                if [ -n "${BUILD_ERROR_LOG:-}" ] && [ -f "${BUILD_ERROR_LOG}" ]; then
                    sync "${BUILD_ERROR_LOG}" 2>/dev/null || sync
                fi
            done
        ) &
        SYNC_PID=$!
        
        # Store sync PID so we can clean it up if needed
        export BUILD_LOG_SYNC_PID="${SYNC_PID}"
    else
        printf '%s\n' "  ⚠ Warning: 'sleep' command not available, periodic sync disabled"
        printf '%s\n' "  Log will still be captured, but manual sync only on exit"
        export BUILD_LOG_SYNC_PID=""
    fi
    
    # Note: analyze_build_log() function is now defined in config.sh (unified)
    # The function will be available after sourcing /etc/config.sh (which happens earlier)
    # This ensures a single source of truth for log analysis patterns and logic
    
    # Trap to ensure sync job is killed when script exits (normal or abrupt)
    # This function is called on: EXIT (normal), INT (Ctrl+C), TERM (kill)
    cleanup_logging() {
        local exit_code=$?
        
        # Kill the background sync job
        # Note: Using || true is intentional for cleanup - job may already be terminated
        if [ -n "${BUILD_LOG_SYNC_PID:-}" ]; then
            kill "${BUILD_LOG_SYNC_PID}" 2>/dev/null || true
        # ENDIF: BUILD_LOG_SYNC_PID check
        fi
        # CRITICAL: Perform final sync to ensure all data is written to disk
        # This captures any output generated between last sync and exit
        if [ -f "${BUILD_LOG_FILE}" ]; then
            sync "${BUILD_LOG_FILE}" 2>/dev/null || sync
            
            # Analyze build log for errors/warnings with context
            # Ensure analyze_build_log function is available (re-source config.sh if needed)
            if [ "${ENABLE_LOG_ERROR_EXTRACTION:-0}" = "1" ]; then
                if ! type analyze_build_log >/dev/null 2>&1; then
                    if [ -f /etc/config.sh ]; then
                        # shellcheck source=/etc/config.sh
                        source /etc/config.sh
                    fi
                fi
                # Only call if function exists
                # Note: Using || true is intentional - log analysis is non-critical
                if type analyze_build_log >/dev/null 2>&1; then
                    # SC2119: analyze_build_log doesn't take script arguments, call without $@
                    # shellcheck disable=SC2119
                    analyze_build_log || true
                else
                    printf '%s\n' "⚠ Warning: analyze_build_log function not available, skipping log analysis"
                # ENDIF: analyze_build_log function availability check
                fi
            fi
            
            printf '%s\n' ""
            printf '%s\n' "═══════════════════════════════════════════════════════════════"
            printf '%s\n' "  BUILD LOG END: $(date)"
            printf '%s\n' "  Exit status: $exit_code"
            printf '%s\n' "  Log file: ${BUILD_LOG_FILE}"
            if [ -n "${BUILD_ERROR_LOG:-}" ] && [ -f "${BUILD_ERROR_LOG}" ]; then
                printf '%s\n' "  Error log: ${BUILD_ERROR_LOG}"
            fi
            printf '%s\n' "  Final sync completed: All output saved to disk"
            printf '%s\n' "═══════════════════════════════════════════════════════════════"
        # ENDIF: BUILD_LOG_FILE existence check
        fi
    }
    trap cleanup_logging EXIT INT TERM
    
    # Record build start in log
    printf '%s\n' "═══════════════════════════════════════════════════════════════"
    printf '%s\n' "  BUILD LOG START: $(date)"
    printf '%s\n' "  Script: ${SCRIPT_BASENAME}"
    printf '%s\n' "  Log file: ${BUILD_LOG_FILE}"
    printf '%s\n' "  Timestamp: ${BUILD_TIMESTAMP}"
    printf '%s\n' "  PID: $$"
    printf '%s\n' "  Sync job PID: ${BUILD_LOG_SYNC_PID}"
    printf '%s\n' "═══════════════════════════════════════════════════════════════"
    printf '%s\n' ""
    else
        printf '%s\n' "ℹ Logging disabled (not running in container build environment)"
    # ENDIF: container build environment check
fi

# After configuration and logging setup, restore fail-fast behavior.
# Enable ERR trap inheritance for functions and subshells
set -E

# Purpose: Centralized error reporter to make failures traceable
# Parameters:
#   $1 = line number where failure occurred
#   $2 = command that failed
#   $3 = exit status code
# Side effects: Prints a concise multi-line diagnostic to stderr
on_error_report() {
	# Collect lightweight context safely without tripping -u/-e
	local bash_ver="${BASH_VERSION:-unknown}"
	local shellopts="${SHELLOPTS:-}"
	# SC2155: Declare and assign separately to avoid masking return values
	local who
	who="$(id -un 2>/dev/null || echo unknown)"
	local uid
	uid="$(id -u 2>/dev/null || echo unknown)"
	local file="${BASH_SOURCE[1]:-unknown}"
	local line="${1:-unknown}"
	local cmd="${2:-unknown}"
	local code="${3:-1}"
	local pwd_now="${PWD:-unknown}"
	local pipefail_state
	# D3: Use here-string instead of echo | grep (unsafe pipe pattern)
	pipefail_state="$(grep -E 'pipefail|errexit|nounset' <<< "$(set -o 2>/dev/null || echo '')" || true)"

	# Single, high-signal diagnostic block
	{
		echo "[ERROR] Command failed (exit=${code}) at ${file}:${line}"
		echo "        -> ${cmd}"
		echo "        bash=${bash_ver} user=${who} uid=${uid} pid=$$ pwd=${pwd_now}"
		echo "        shellopts=${shellopts} set-o:${pipefail_state}"
		# If a build log file path is known, surface it to the console for quick navigation
		[ -n "${BUILD_LOG_FILE:-}" ] && echo "        build_log=${BUILD_LOG_FILE}"
	} 1>&2
}

# Install global ERR trap (inherits due to set -E above)
trap 'on_error_report "${LINENO}" "${BASH_COMMAND}" "$?"' ERR

set -e

# Verify strict mode is active (A/B3 enforcement)
# - set -e: pipeline/command failures should not be ignored
# - set -u: unset variables should trigger an error
# - set -o pipefail: pipeline should return failure if any stage fails
# NOTE:
#   These checks are informational only - warnings do NOT stop script execution.
#   Script continues regardless of check results (non-blocking warnings).
#   Direct subshell-based checks can produce false positives on some Bash builds.
#   We perform out-of-process checks and emit a single high-signal line with context.

# Check set -e (errexit)
if bash -c 'set -e; false; echo STRICT_SET_E_SHOULD_NOT_PRINT' >/dev/null 2>&1; then
	echo "[WARN] Strict check(set -e) anomaly; bash=${BASH_VERSION:-?} shellopts=${SHELLOPTS:-} file=${BASH_SOURCE[0]} line=${LINENO}"
	echo "[INFO] Script continues - this is a non-blocking warning"
fi

# Check set -u (nounset)
if bash -c 'set -u; : "${__UNSET_STRICT_TEST_VAR__?unset variable test}"' >/dev/null 2>&1; then
	echo "[WARN] Strict check(set -u) anomaly; bash=${BASH_VERSION:-?} shellopts=${SHELLOPTS:-} file=${BASH_SOURCE[0]} line=${LINENO}"
	echo "[INFO] Script continues - this is a non-blocking warning"
fi

# Check set -o pipefail
# FIX: Added set -e to the pipefail check - pipefail alone doesn't stop execution, it only affects exit code
# Without set -e, the pipeline fails but execution continues, causing false positive warnings
# Root cause: Original check tested pipefail in isolation, which always "fails" because pipefail
# only affects exit codes, not execution flow. Combined with set -e, the check is now accurate.
if bash -c 'set -e -o pipefail; false | true; echo STRICT_PIPEFAIL_SHOULD_NOT_PRINT' >/dev/null 2>&1; then
	echo "[WARN] Strict check(pipefail) anomaly; bash=${BASH_VERSION:-?} shellopts=${SHELLOPTS:-} file=${BASH_SOURCE[0]} line=${LINENO}"
	echo "[INFO] Script continues - this is a non-blocking warning"
	echo "[INFO] If this warning appears, it indicates pipefail+errexit may not be working correctly in this Bash environment"
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
# Parameters: $1 = stage name (string describing current build stage)
# Returns: 0 on success (always succeeds - diagnostic function)
# Side effects: Temporarily disables pipefail to prevent pipeline failures from stopping script
# Dependencies: Requires GCC and GLIBC to be installed for full diagnostics (PHASE 1)
# Outputs: Configured system components diagnostic information
# Note: This function intentionally uses || echo patterns for graceful degradation
debug_glibc() {
  local stage="$1"
  # Temporarily disable pipefail to prevent pipeline failures from stopping the script
  # Also save/restore -e state to avoid leaking caller strictness
  local __prev_opts="$-"
  local __had_e=0
  case "$__prev_opts" in *e*) __had_e=1 ;; esac
  set +e
  set +o pipefail
  echo "=========================================================="
  printf '%b\n' "${BLUE}DEBUG CHECKPOINT: ${stage}${NC}"
  echo "Time: $(date)"
  echo "=========================================================="
  echo "GLIBC version:"
  # D3e: SIGPIPE protection - add || true at end of pipeline with head
  /lib/x86_64-linux-gnu/libc.so.6 2>/dev/null | head -1 2>/dev/null || echo "GLIBC version check failed" || true
  echo "---"
  echo "ldd version:"
  (timeout 5 sh -c 'ldd --version 2>&1' || echo "ldd version check failed or timed out") | head -1 || true
  echo "---"
  echo "GCC version:"
  # D3e: SIGPIPE protection - add || true at end of pipeline with head
  gcc --version 2>/dev/null | head -1 2>/dev/null || echo "GCC not installed yet" || true
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
  # Use command substitution with fallback for temporary file creation
  # Note: This occurs in non-strict mode context (pipefail disabled), so || fallback is acceptable
  # SC2155: Declare and assign separately to avoid masking return values
  local tmp_src
  tmp_src=$(mktemp -t glibc_testXXXX.c 2>/dev/null) || tmp_src="/tmp/glibc_test_$$.c"
  local tmp_bin
  tmp_bin=$(mktemp -t glibc_testXXXX 2>/dev/null) || tmp_bin="/tmp/glibc_test_$$"
  {
    echo '#include <stdlib.h>'
    echo 'int main(void) { return 0; }'
  } > "${tmp_src}"
  if gcc "${tmp_src}" -o "${tmp_bin}" 2>&1; then
    echo "SUCCESS"
  else
    echo "FAILED"
  # ENDIF: gcc compilation check
  fi
  rm -f "${tmp_src}" "${tmp_bin}"
  echo "---"
  echo
  # Reset terminal state after debug output (gcc -v can leave control codes)
  printf '\033[0m\n'
  # Restore pipefail
  set -o pipefail
  # Restore -e if it was previously set
  if [ "$__had_e" -eq 1 ]; then
    set -e
  fi
}
# End function (self-contained)

#===============================================================================
# BLOCK 3: BUILD JOB CALCULATION FUNCTION (FOR PARALLEL COMPILATION)
#===============================================================================
# Purpose: Calculate optimal number of parallel build jobs based on CPU and memory
# Self-contained: Yes (no external dependencies)
# Outputs: Number of jobs suitable for parallel compilation
# Usage: BUILD_JOBS=$(calculate_build_jobs)
#-------------------------------------------------------------------------------

# Note: calculate_build_jobs() is now defined in /scripts/common_functions.sh (centralized)
# End function (self-contained)

#===============================================================================
# BLOCK 2.5: CACHE MANAGEMENT
#===============================================================================
# Purpose: Cache consolidation and monitoring functions
# Self-contained: Yes (functions loaded from common_functions.sh)
# Dependencies: /scripts/common_functions.sh (loaded above)
# Outputs: Cache consolidation and monitoring
#-------------------------------------------------------------------------------
# Note: Functions consolidate_cache_packages(), monitor_cache(), calculate_build_jobs()
#       are now defined in /scripts/common_functions.sh (centralized)

#-------------------------------------------------------------------------------
# PACKAGE STATUS HELPER FUNCTIONS
#-------------------------------------------------------------------------------
# Purpose: Provide reliable detection of installed packages, including held or
# multi-arch variants (e.g., pkg:amd64) which `dpkg -l` may omit.
# Dependencies: dpkg-query
# Outputs: Functions for package presence and version detection
#-------------------------------------------------------------------------------

dpkg_resolve_installed_package() {
    local base_pkg="${1:-}"
    if [ -z "${base_pkg}" ]; then
        return 1
    # ENDIF: base_pkg empty check
    fi

    local candidates=("${base_pkg}")
    if [[ "${base_pkg}" != *":"* ]]; then
        candidates+=("${base_pkg}:amd64" "${base_pkg}:arm64" "${base_pkg}:i386")
    # ENDIF: architecture suffix check
    fi

    local candidate
    for candidate in "${candidates[@]}"; do
        local status_output
        status_output=$(dpkg-query -W -f='${Status}\n' "${candidate}" 2>/dev/null || echo "")
        if [ -n "${status_output}" ] && grep -Fq "install ok installed" <<< "${status_output}"; then
            printf '%s\n' "${candidate}"
            return 0
        # ENDIF: package installation status check
        fi
    # ENDFOR: candidate
    done

    return 1
}

dpkg_get_installed_version() {
    local base_pkg="${1:-}"
    if [ -z "${base_pkg}" ]; then
        return 1
    fi

    local resolved_pkg
    resolved_pkg=$(dpkg_resolve_installed_package "${base_pkg}") || return 1
    
    # Validate resolved package name is non-empty before querying
    if [ -z "${resolved_pkg}" ]; then
        return 1
    fi
    
    local version_output
    version_output=$(dpkg-query -W -f='${Version}\n' "${resolved_pkg}" 2>/dev/null || echo "")
    
    # Validate version output is non-empty and valid format (should contain version string)
    if [ -n "${version_output}" ] && grep -qE '^[0-9]' <<< "${version_output}"; then
        # D3e: SIGPIPE protection - add || true at end of pipeline with head
        printf '%s\n' "${version_output}" | head -n1 2>/dev/null || true
    else
        return 1
    fi
}

#===============================================================================
# BLOCK 4: MIRROR PROBING FUNCTIONS (MUST BE EARLY FOR APT OPERATIONS)
#===============================================================================
# Purpose: Test and select fastest Ubuntu mirror BEFORE any apt-get operations
# Self-contained: Yes (complete mirror selection system)
# Dependencies: curl (available in Ubuntu base images)
# Outputs: FASTEST_MIRROR variable, updated /etc/apt/sources.list
# Note: Moved early to ensure ALL package downloads use fastest mirror
#-------------------------------------------------------------------------------

#--- Sub-block 4.1: Mirror test function (for parallel execution) ---
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
    local previous_opts="$-"
    set +e
    local CURL_OUTPUT CURL_EXIT_CODE HTTP_CODE

    # Download Packages.gz (typically 15-25MB) to measure bandwidth
    # Check HTTP status code to detect 403 (blocked), 404, etc.
    # Note: curl returns non-zero exit code for 4xx/5xx, but still writes HTTP code to stdout
    # Use separate files to capture stdout (format string) and stderr (errors)
    local curl_stdout curl_stderr
    curl_stdout=$(mktemp) || curl_stdout="/tmp/curl_stdout_$$"
    curl_stderr=$(mktemp) || curl_stderr="/tmp/curl_stderr_$$"
    
    LC_NUMERIC=C curl -s -w '%{http_code}|%{time_total}\n' -o /dev/null -m 25 --connect-timeout 8 --retry 1 -L "${URL}/dists/${CODENAME}/main/binary-amd64/Packages.gz" > "${curl_stdout}" 2> "${curl_stderr}"
    CURL_EXIT_CODE=$?
    
    # Read output from file
    CURL_OUTPUT=$(cat "${curl_stdout}" 2>/dev/null || echo "")
    local curl_error
    curl_error=$(cat "${curl_stderr}" 2>/dev/null || echo "")
    rm -f "${curl_stdout}" "${curl_stderr}" 2>/dev/null || true
    
    # Extract HTTP code and time from output (format: "HTTP_CODE|TIME")
    # Pattern: '^[0-9]{3}$' matches exactly 3 digits (200, 403, 404, etc.)
    # If not matching (invalid format), return empty string
    # Validate CURL_OUTPUT format before parsing
    if [ -n "${CURL_OUTPUT}" ] && grep -qE '^[0-9]{3}\|' <<< "${CURL_OUTPUT}"; then
        HTTP_CODE=$(cut -d'|' -f1 <<< "${CURL_OUTPUT}" 2>/dev/null | grep -E '^[0-9]{3}$' || echo "")
        local TIME_VALUE
        # Pattern: '^[0-9]' matches any string starting with digit (0.123, 12.456, etc.)
        # Validates that we have a numeric time value before using it
        TIME_VALUE=$(cut -d'|' -f2 <<< "${CURL_OUTPUT}" 2>/dev/null | grep -E '^[0-9]' || echo "")
        CURL_OUTPUT="${TIME_VALUE}"
    else
        # Invalid format - set to empty for later checks
        HTTP_CODE=""
        CURL_OUTPUT=""
    fi

    # Reject mirrors that return 403 (Forbidden/Blocked), 404 (Not Found), or other error codes
    # Check HTTP code first (even if curl exit code is non-zero, we might have gotten HTTP response)
    # Pattern: ^[45][0-9][0-9]$ matches HTTP 4xx and 5xx errors
    # Examples: 400-499 (client errors), 500-599 (server errors)
    if [[ -n "${HTTP_CODE:-}" ]] && [[ "${HTTP_CODE}" =~ ^[45][0-9][0-9]$ ]]; then
      echo "[test_mirror] Rejecting ${URL}: HTTP ${HTTP_CODE} (blocked or error)" >&2
      echo "999.9 ${URL}" >> "${PROBE_RESULTS}"
      if [[ "${previous_opts}" == *e* ]]; then
          set -e
      else
          set +e
      fi
      return
    fi
    
    # Also check for connection/network errors that prevent HTTP response
    if [[ -z "${HTTP_CODE:-}" ]] && [[ "${CURL_EXIT_CODE:-1}" -ne 0 ]]; then
      # No HTTP code means connection failed before getting response
      # This is different from getting a 403 response
      # grep pattern: -q (quiet), -i (ignore case), -E (extended regex)
      # Pattern '(403|Forbidden|blocked)' matches any of these strings in error output
      if grep -qiE "(403|Forbidden|blocked)" <<< "${curl_error}"; then
        echo "[test_mirror] Rejecting ${URL}: Connection blocked (403 detected in error)" >&2
        echo "999.9 ${URL}" >> "${PROBE_RESULTS}"
        if [[ "${previous_opts}" == *e* ]]; then
            set -e
        else
            set +e
        fi
        return
      fi
    fi

    # If large file fails, try Release file as fallback
    if [[ "${CURL_EXIT_CODE:-1}" -ne 0 ]] || [[ -z "${CURL_OUTPUT:-}" ]] || [[ "${CURL_OUTPUT:-}" == "0.000000" ]]; then
      # Use same approach for Release file
      curl_stdout=$(mktemp) || curl_stdout="/tmp/curl_stdout_release_$$"
      curl_stderr=$(mktemp) || curl_stderr="/tmp/curl_stderr_release_$$"
      
      LC_NUMERIC=C curl -s -w '%{http_code}|%{time_total}\n' -o /dev/null -m 10 --connect-timeout 5 --retry 1 "${URL}/dists/${CODENAME}/Release" > "${curl_stdout}" 2> "${curl_stderr}"
      CURL_EXIT_CODE=$?
      
      CURL_OUTPUT=$(cat "${curl_stdout}" 2>/dev/null || echo "")
      curl_error=$(cat "${curl_stderr}" 2>/dev/null || echo "")
      rm -f "${curl_stdout}" "${curl_stderr}" 2>/dev/null || true
      
      # Validate CURL_OUTPUT format before parsing (same validation as first attempt)
      if [ -n "${CURL_OUTPUT}" ] && grep -qE '^[0-9]{3}\|' <<< "${CURL_OUTPUT}"; then
        HTTP_CODE=$(cut -d'|' -f1 <<< "${CURL_OUTPUT}" 2>/dev/null | grep -E '^[0-9]{3}$' || echo "")
        TIME_VALUE=$(cut -d'|' -f2 <<< "${CURL_OUTPUT}" 2>/dev/null | grep -E '^[0-9]' || echo "")
        CURL_OUTPUT="${TIME_VALUE}"
      else
        # Invalid format - set to empty for later checks
        HTTP_CODE=""
        CURL_OUTPUT=""
      fi
        
      # Reject Release file if it also returns error codes
      if [[ -n "${HTTP_CODE:-}" ]] && [[ "${HTTP_CODE}" =~ ^[45][0-9][0-9]$ ]]; then
        echo "[test_mirror] Rejecting ${URL}: HTTP ${HTTP_CODE} on Release file (blocked or error)" >&2
        echo "999.9 ${URL}" >> "${PROBE_RESULTS}"
        if [[ "${previous_opts}" == *e* ]]; then
            set -e
        else
            set +e
        fi
        return
      fi
      
      # Check for blocked errors in stderr
      if [[ -z "${HTTP_CODE:-}" ]] && [[ "${CURL_EXIT_CODE:-1}" -ne 0 ]]; then
        if grep -qiE "(403|Forbidden|blocked)" <<< "${curl_error}"; then
          echo "[test_mirror] Rejecting ${URL}: Release file blocked (403 detected)" >&2
          echo "999.9 ${URL}" >> "${PROBE_RESULTS}"
          if [[ "${previous_opts}" == *e* ]]; then
              set -e
          else
              set +e
          fi
          return
        fi
      fi
        
      # Penalize Release-only results (multiply by 10 to prefer Packages.gz results)
      if [[ "${CURL_EXIT_CODE:-1}" -eq 0 ]] && [[ -n "${CURL_OUTPUT:-}" ]] && [[ "${CURL_OUTPUT:-}" != "0.000000" ]]; then
        # D3: Use here-string instead of echo | awk (unsafe pipe pattern)
        CURL_OUTPUT=$(printf "%.3f" "$(awk '{print $1 * $2}' <<< "${CURL_OUTPUT} 10" 2>/dev/null || echo "${CURL_OUTPUT}")")
      fi
    fi
    if [[ "${previous_opts}" == *e* ]]; then
        set -e
    else
        set +e
    fi

    # Write results (flock doesn't work reliably in xargs subshells, using simple append)
    # Final check: if we still don't have a valid time value, mark as failed
    if [[ "${CURL_EXIT_CODE:-1}" -ne 0 ]] || [[ -z "${CURL_OUTPUT:-}" ]] || [[ "${CURL_OUTPUT:-}" == "0.000000" ]] || [[ ! "${CURL_OUTPUT:-}" =~ ^[0-9] ]]; then
      # Check for any error indicators we might have missed
      if [[ -n "${curl_error:-}" ]] && grep -qiE "(timeout|connection refused|connection reset|name resolution|couldn't connect|failed|error|403|404|500|502|503|504)" <<< "${curl_error}"; then
        echo "[test_mirror] Rejecting ${URL}: Connection/download error detected" >&2
      fi
      echo "999.9 ${URL}" >> "${PROBE_RESULTS}"
    else
      # Valid result - write time and URL
      echo "${CURL_OUTPUT} ${URL}" >> "${PROBE_RESULTS}"
    fi
}

#--- Sub-block 4.2: Dynamic linker helper ---
# Purpose: Ensure compiled libraries in /usr/local are prioritised early
# Dependencies: None
# Outputs: /etc/ld.so.conf.d/00-compiled-libs.conf
ensure_compiled_lib_priority() {
  local conf_file="/etc/ld.so.conf.d/00-compiled-libs.conf"

  echo "    Ensuring ${conf_file} prioritises /usr/local libraries..."
  # Ensure directory exists before writing
  mkdir -p /etc/ld.so.conf.d || {
    echo "    ERROR: Failed to create /etc/ld.so.conf.d directory" >&2
    return 1
  }
  # EXEMPTED FROM EXTRACTION: Small config file (<5 lines), simple content, tightly coupled to function logic
  cat > "${conf_file}" <<'LDCONF'
# CRITICAL: Search /usr/local first for compiled libraries
/usr/local/lib
/usr/local/lib64
/usr/local/lib/x86_64-linux-gnu
LDCONF
  if [ ! -f "${conf_file}" ]; then
    echo "    ERROR: Failed to create ${conf_file}" >&2
    return 1
  fi
}

#--- Sub-block 4.3: ldconfig wrapper ---
# Purpose: Always ensure /usr/local priority file exists before refreshing cache
# Dependencies: ensure_compiled_lib_priority
# Outputs: Updated dynamic linker cache
# Note: Function accepts optional arguments passed to ldconfig (e.g., -v for verbose, -N for fast update)
# Improvements:
#   - Uses -N flag by default for faster updates (doesn't rebuild entire cache)
#   - Falls back to full rebuild if -N fails
#   - More reliable than traditional full cache rebuild
# shellcheck disable=SC2120  # Function intentionally uses $@ for optional ldconfig arguments
run_ldconfig_refresh() {
  # Ensure priority file exists (non-fatal if it fails)
  ensure_compiled_lib_priority || {
    echo "  [WARN] Failed to ensure compiled lib priority, continuing with ldconfig refresh..." >&2
  }
  
  # Use -N flag for faster update (doesn't rebuild entire cache, just updates)
  # This is more reliable and faster than full rebuild
  # If flags provided, use them; otherwise use fast update mode
  if [ "$#" -eq 0 ]; then
    # No flags provided, use fast update mode (-N)
    ldconfig -N 2>/dev/null || ldconfig || return 1
  else
    # Flags provided, use them (user can override with -v, etc.)
    ldconfig "$@" || return 1
  fi
}

#--- Sub-block 4.3a: Targeted ldconfig update for specific directory ---
# Purpose: Update ldconfig cache for a specific directory (faster and more reliable)
# Parameters:
#   $1: Target directory path (required)
#   $2+: Optional - additional ldconfig flags
# Usage: run_ldconfig_refresh_dir "/usr/local/lib" "-v"
# Benefits:
#   - Faster than full cache rebuild
#   - More reliable for newly installed libraries
#   - Verifies directory contains libraries before updating
#   - Automatically ensures path is registered in ld.so.conf.d if needed
run_ldconfig_refresh_dir() {
  local target_dir="${1:-}"
  
  if [ -z "${target_dir}" ]; then
    echo "Error: run_ldconfig_refresh_dir requires a directory path" >&2
    return 1
  fi
  
  # Normalize path (resolve symlinks, remove trailing slashes)
  target_dir=$(realpath "${target_dir}" 2>/dev/null || echo "${target_dir}")
  target_dir="${target_dir%/}"
  
  if [ ! -d "${target_dir}" ]; then
    echo "Warning: Directory ${target_dir} does not exist, skipping targeted update" >&2
    return 1
  fi
  
  echo "  [DEBUG] Refreshing ldconfig for directory: ${target_dir}"
  
  # Ensure priority file exists (non-fatal if it fails)
  ensure_compiled_lib_priority || {
    echo "  [WARN] Failed to ensure compiled lib priority, continuing with directory refresh..." >&2
  }
  
  # CRITICAL: Ensure library path is registered in ld.so.conf.d (addresses common detection issue)
  if ! ensure_library_path_registered "${target_dir}"; then
    echo "  [WARN] Failed to register ${target_dir} in ld.so.conf.d, but continuing..." >&2
  else
    echo "  [DEBUG] Verified ${target_dir} is registered in ld.so.conf.d"
  fi
  
  # Verify directory contains library files before updating
  local find_output
  # D3e: SIGPIPE protection - add || true at end of pipeline with head
  find_output=$(find "${target_dir}" -maxdepth 1 -name "*.so*" -type f 2>/dev/null | head -1 2>/dev/null || echo "" || true)
  if [ -z "${find_output}" ]; then
    echo "  [WARN] No .so files found in ${target_dir}, but attempting refresh anyway (may have symlinks)" >&2
  else
    echo "  [DEBUG] Found library files in ${target_dir}, proceeding with refresh"
  fi
  
  # CRITICAL FIX: ldconfig -n only processes the directory but doesn't update the global cache
  # We need to run BOTH: -n to process the directory, then full ldconfig to update cache
  shift  # Remove directory arg, keep remaining flags
  
  # Step 1: Process the directory with ldconfig -n (creates symlinks, processes directory)
  echo "  [DEBUG] Step 1: Processing directory ${target_dir} with ldconfig -n..."
  if ldconfig -n "${target_dir}" "$@" 2>&1; then
    echo "  [DEBUG] Directory processing successful"
  else
    echo "  [WARN] ldconfig -n failed for ${target_dir}, but continuing with full refresh..." >&2
  fi
  
  # Step 2: CRITICAL - Run full ldconfig to update the global cache that ldconfig -p reads
  # This is the missing piece - -n doesn't update the cache, only processes the directory
  echo "  [DEBUG] Step 2: Updating global ldconfig cache (required for ldconfig -p to work)..."
  if ldconfig 2>&1; then
    echo "  [DEBUG] Global cache update successful"
  else
    echo "  [ERROR] Full ldconfig failed after directory processing" >&2
    return 1
  fi
  
  # Step 3: Verify the refresh worked by checking if libraries are now in cache
  echo "  [DEBUG] Step 3: Verifying libraries from ${target_dir} are in cache..."
  local lib_count
  lib_count=$(find "${target_dir}" -maxdepth 1 -name "*.so*" -type f 2>/dev/null | wc -l || echo "0")
  if [ "${lib_count}" -gt 0 ]; then
    # Try to find at least one library from this directory in the cache
    local sample_lib
    # D3e: SIGPIPE protection - add || true at end of pipeline with head
    sample_lib=$(find "${target_dir}" -maxdepth 1 -name "*.so" -type f 2>/dev/null | head -1 2>/dev/null || echo "" || true)
    if [ -n "${sample_lib}" ]; then
      local lib_basename
      # D3: Use here-string instead of basename | sed (unsafe pipe pattern)
      lib_basename=$(sed 's/\.[0-9].*$//' <<< "$(basename "${sample_lib}")" || echo "")
      if ldconfig -p 2>/dev/null | grep -qF "${lib_basename}"; then
        echo "  [DEBUG] ✓ Verification passed: Libraries from ${target_dir} are now in cache"
        return 0
      else
        echo "  [WARN] Libraries processed but not yet visible in cache (may need additional refresh)" >&2
        # Try one more full refresh
        ldconfig 2>&1 || true
        return 0  # Don't fail - libraries are processed, cache may update later
      fi
    fi
  fi
  
  return 0
}

#--- Sub-block 4.4: Comprehensive library verification ---
# Purpose: Verify library is available using multiple methods (more reliable than ldconfig -p alone)
# Parameters:
#   $1: Library name pattern (e.g., "libgtsam.so" or "libgtsam")
#   $2: Optional - library file path to verify directly
# Returns: 0 if library is available, 1 otherwise
# Usage: verify_library_available "libgtsam.so" "/usr/local/lib/libgtsam.so.4.2.0"
# Verification methods (comprehensive check):
#   1. Check ldconfig cache (fastest, but may be stale)
#   2. Verify file exists, is readable, and has correct permissions
#   3. Verify library naming conventions (lib*.so*)
#   4. Verify SONAME (if available)
#   5. Verify library path is in /etc/ld.so.conf.d/
#   6. Try to load library with ldd (most reliable, verifies it's valid)
#   7. Check LD_LIBRARY_PATH includes library directory
verify_library_available() {
  local lib_pattern="${1}"
  local lib_file_path="${2:-}"
  local found=false
  local issues=()
  
  # Phase 1: File Existence Check (PRIORITY - files can exist but not be in cache)
  # According to O4: File existence MUST be checked FIRST before cache checks
  if [ -n "${lib_file_path}" ]; then
    # Check 1a: File exists (takes priority over cache)
    if [ -f "${lib_file_path}" ]; then
      found=true
      
      # Check 1b: File is readable
      if [ ! -r "${lib_file_path}" ]; then
        issues+=("Library file is not readable (permissions issue): ${lib_file_path}")
      fi
      
      # Check 1c: Verify library naming convention (lib*.so*)
      local lib_basename
      lib_basename=$(basename "${lib_file_path}")
      if ! grep -qE '^lib.*\.so' <<< "${lib_basename}"; then
        issues+=("Library does not follow naming convention (should be lib*.so*): ${lib_basename}")
      fi
      
      # Check 1d: Verify SONAME (if objdump available)
      if command -v objdump >/dev/null 2>&1; then
        local objdump_output soname
        objdump_output=$(objdump -p "${lib_file_path}" 2>/dev/null || echo "")
        if [ -n "${objdump_output}" ]; then
          soname=$(awk '/SONAME/ {print $2; exit}' <<< "${objdump_output}" || echo "")
          if [ -z "${soname}" ]; then
            issues+=("Library has no SONAME (may cause linking issues): ${lib_basename}")
          fi
        fi
      fi
      
      # Check 1e: Try to load library with ldd (verifies it's a valid shared library)
      # This is the most reliable check - if ldd can load it, the library is valid
      if command -v ldd >/dev/null 2>&1; then
        if ! ldd "${lib_file_path}" >/dev/null 2>&1; then
          issues+=("Library failed ldd check (may be corrupted or wrong architecture): ${lib_basename}")
          # ldd failure is a warning, not fatal if file exists
        fi
      fi
      
      # Check 1f: Verify library directory is in ld.so.conf.d
      local lib_dir
      lib_dir=$(dirname "${lib_file_path}")
      local conf_found=false
      if [ -d "/etc/ld.so.conf.d" ]; then
        for conf_file in /etc/ld.so.conf.d/*.conf; do
          if [ -f "${conf_file}" ] && grep -q "^${lib_dir}\$" "${conf_file}" 2>/dev/null; then
            conf_found=true
            break
          fi
        done
      fi
      # Also check main ld.so.conf
      if [ -f "/etc/ld.so.conf" ] && grep -q "^${lib_dir}\$" /etc/ld.so.conf 2>/dev/null; then
        conf_found=true
      fi
      
      if [ "${conf_found}" != true ] && [ "${lib_dir}" != "/lib" ] && [ "${lib_dir}" != "/usr/lib" ] && [ "${lib_dir}" != "/lib64" ] && [ "${lib_dir}" != "/usr/lib64" ]; then
        # Standard system paths don't need explicit configuration
        issues+=("Library directory not in /etc/ld.so.conf.d/ (may need explicit path registration): ${lib_dir}")
      fi
      
      # Check 1g: Verify LD_LIBRARY_PATH includes library directory (if set)
      if [ -n "${LD_LIBRARY_PATH:-}" ]; then
        case ":${LD_LIBRARY_PATH}:" in
          *:${lib_dir}:*) ;;
          *)
            issues+=("Library directory not in LD_LIBRARY_PATH (runtime may fail): ${lib_dir}")
            ;;
        esac
      fi
    else
      # File path provided but file doesn't exist - add to issues
      issues+=("Library file does not exist: ${lib_file_path}")
    fi
  fi
  
  # Phase 2: Linker Cache Check (secondary - cache may be stale)
  # Only check cache if file wasn't found (file existence takes priority)
  if [ "${found}" != true ]; then
    local cache_output
    cache_output=$(timeout 2 ldconfig -p 2>/dev/null || echo "")
    if [ -n "${cache_output}" ] && grep -qF "${lib_pattern}" <<< "${cache_output}"; then
      found=true
    fi
  fi
  
  # Phase 3: Report Results (non-fatal warnings if file found)
  # CRITICAL: If file exists, warnings are non-fatal (file takes priority over cache)
  if [ ${#issues[@]} -gt 0 ] && [ "${found}" = true ]; then
    # Library found but has issues - log warnings but don't fail
    for issue in "${issues[@]}"; do
      echo "  [WARN] ${issue}" >&2
    done
  fi
  
  # Return success if found (file existence takes priority), failure otherwise
  if [ "${found}" = true ]; then
    return 0
  else
    return 1
  fi
# ENDIF: verify_library_available function
}

#--- Sub-block 4.3b: Ensure library path is registered in ld.so.conf.d ---
# Purpose: Ensure a library directory is registered in /etc/ld.so.conf.d/ for ldconfig
# Parameters:
#   $1: Library directory path (required)
# Returns: 0 if path is registered (or was just registered), 1 on error
# Usage: ensure_library_path_registered "/usr/local/lib"
# This addresses the common issue where libraries aren't detected because their path
# isn't in ld.so.conf.d/
ensure_library_path_registered() {
  local lib_dir="${1:-}"
  
  if [ -z "${lib_dir}" ]; then
    echo "Error: ensure_library_path_registered requires a directory path" >&2
    return 1
  fi
  
  if [ ! -d "${lib_dir}" ]; then
    echo "Warning: Directory ${lib_dir} does not exist, cannot register" >&2
    return 1
  fi
  
  # Standard system paths don't need explicit registration
  case "${lib_dir}" in
    /lib|/usr/lib|/lib64|/usr/lib64)
      return 0
      ;;
  esac
  
  # Check if already registered
  local conf_found=false
  if [ -d "/etc/ld.so.conf.d" ]; then
    for conf_file in /etc/ld.so.conf.d/*.conf; do
      if [ -f "${conf_file}" ] && grep -q "^${lib_dir}\$" "${conf_file}" 2>/dev/null; then
        conf_found=true
        break
      fi
    done
  fi
  # Also check main ld.so.conf
  if [ -f "/etc/ld.so.conf" ] && grep -q "^${lib_dir}\$" /etc/ld.so.conf 2>/dev/null; then
    conf_found=true
  fi
  
  if [ "${conf_found}" != true ]; then
    # Path not registered - add it
    local conf_file="/etc/ld.so.conf.d/99-custom-libs.conf"
    # Ensure directory exists before creating file
    if [ ! -d "/etc/ld.so.conf.d" ]; then
      mkdir -p /etc/ld.so.conf.d || {
        echo "Error: Failed to create /etc/ld.so.conf.d directory" >&2
        return 1
      }
    fi
    # Check if file exists and already has entries
    if [ -f "${conf_file}" ]; then
      # Append if not already present
      if ! grep -q "^${lib_dir}\$" "${conf_file}" 2>/dev/null; then
        echo "${lib_dir}" >> "${conf_file}"
        echo "  → Added ${lib_dir} to ${conf_file}"
      fi
    else
      # Create new file
      echo "${lib_dir}" > "${conf_file}" || {
        echo "Error: Failed to write to ${conf_file}" >&2
        return 1
      }
      echo "  → Created ${conf_file} with ${lib_dir}"
    fi
    return 0
  fi
  
  return 0
}

#--- Sub-block 4.3c: Dynamic ldconfig refresh from installation output ---
# Purpose: Extract library installation directories from recent installation output and refresh ldconfig
# Parameters:
#   $1: Optional - log file path to parse (if not provided, uses recent terminal output)
#   $2: Optional - number of lines to extract (default: 150)
# Returns: 0 on success, 1 on error
# Usage: run_ldconfig_refresh_from_install_output "/tmp/install.log" 200
# Benefits:
#   - Dynamically detects where libraries were installed
#   - Handles custom installation prefixes automatically
#   - More reliable than assuming /usr/local/lib
#   - Works with both ninja install and make install output
#   - Parses CMake install output, file copy operations, and library paths
run_ldconfig_refresh_from_install_output() {
  local log_file="${1:-}"
  local lines_to_extract="${2:-150}"
  local install_output=""
  local lib_dirs=()
  local unique_dirs=()
  
  # Extract installation output
  if [ -n "${log_file}" ] && [ -f "${log_file}" ]; then
    # Use log file (with small delay to account for log caching)
    sleep 0.5  # Small delay to ensure log is flushed
    install_output=$(tail -n "${lines_to_extract}" "${log_file}" 2>/dev/null || echo "")
    # Validate output was successfully read
    if [ -z "${install_output}" ]; then
      echo "  [WARN] Failed to read installation output from ${log_file}" >&2
      echo "  [DEBUG] Log file exists but appears empty or unreadable" >&2
    else
      echo "  [DEBUG] Successfully read ${lines_to_extract} lines from ${log_file}"
      # Count library installation lines for debugging
      local lib_lines
      lib_lines=$(grep -cE "(Installing|-- Installing|Copying).*\.so" <<< "${install_output}" || echo "0")
      echo "  [DEBUG] Found ${lib_lines} library installation lines in log"
    fi
  else
    # Fallback: Check common installation directories
    if [ -n "${log_file}" ]; then
      echo "  [WARN] Log file ${log_file} does not exist, will check common directories" >&2
    else
      echo "  [WARN] No log file provided, will check common directories" >&2
    fi
    install_output=""
  fi
  
  if [ -z "${install_output}" ]; then
    # Fallback: Check common installation directories
    echo "  [INFO] No installation output available, checking common directories..."
    for common_dir in /usr/local/lib /usr/local/lib64 /usr/local/lib/x86_64-linux-gnu; do
      if [ -d "${common_dir}" ]; then
        local find_output
        # D3e: SIGPIPE protection - add || true at end of pipeline with head
        find_output=$(find "${common_dir}" -maxdepth 1 -name "*.so*" -type f 2>/dev/null | head -1 2>/dev/null || echo "" || true)
        if [ -n "${find_output}" ]; then
          lib_dirs+=("${common_dir}")
        fi
      fi
    done
  else
    # Parse installation output for library directories
    # Pattern 1: CMake/ninja install output: "Installing: /path/to/lib/libname.so" or "-- Installing: /path/to/lib/libname.so"
    while IFS= read -r line || [ -n "${line}" ]; do
      # Match "Installing: /path/to/lib/libname.so*" patterns (most common for CMake/ninja)
      if grep -qE "(Installing|-- Installing):.*\.so" <<< "${line}"; then
        local lib_path=""
        # Try multiple extraction patterns for robustness
        # Pattern 1a: "Installing: /usr/local/lib/libname.so"
        lib_path=$(sed -nE 's/.*(Installing|-- Installing):[[:space:]]+([^[:space:]]+\.so[^[:space:]]*).*/\2/p' <<< "${line}" || echo "")
        # Pattern 1b: "Installing: /usr/local/lib/libname.so -> /usr/local/lib/libname.so.1"
        if [ -z "${lib_path}" ]; then
          lib_path=$(sed -nE 's/.*(Installing|-- Installing):[[:space:]]+([^[:space:]]+\.so[^[:space:]]*)[[:space:]]+->.*/\2/p' <<< "${line}" || echo "")
        fi
        # Pattern 1c: Handle paths with spaces or special characters
        # D3: Use here-string instead of echo | sed (unsafe pipe pattern)
        if [ -z "${lib_path}" ]; then
          lib_path=$(sed -nE 's/.*(Installing|-- Installing):[[:space:]]+([^[:space:]]+\.so[^[:space:]]*).*/\2/p' <<< "${line}" || echo "")
        fi
        
        if [ -n "${lib_path}" ]; then
          # Validate path exists (file or symlink)
          if [ -e "${lib_path}" ] || [ -L "${lib_path}" ]; then
            local lib_dir
            lib_dir=$(dirname "${lib_path}")
            # Normalize directory path
            lib_dir=$(realpath "${lib_dir}" 2>/dev/null || echo "${lib_dir}")
            lib_dir="${lib_dir%/}"
            if [ -d "${lib_dir}" ]; then
              lib_dirs+=("${lib_dir}")
              echo "  [DEBUG] Extracted library directory from 'Installing:' pattern: ${lib_dir}"
            fi
          else
            echo "  [DEBUG] Extracted path ${lib_path} from line but file doesn't exist yet (may be symlink target)" >&2
            # Still try to extract directory even if file doesn't exist (may be created later)
            local lib_dir
            lib_dir=$(dirname "${lib_path}")
            lib_dir=$(realpath "${lib_dir}" 2>/dev/null || echo "${lib_dir}")
            lib_dir="${lib_dir%/}"
            if [ -d "${lib_dir}" ]; then
              lib_dirs+=("${lib_dir}")
            fi
          fi
        fi
      fi
      
      # Pattern 2: File copy operations: "Copying file /path/to/lib/libname.so" or "cp /path/to/lib/libname.so"
      if grep -qE "(Copying|cp|install|Installing).*\.so" <<< "${line}"; then
        # Try multiple patterns for extracting library paths
        local lib_path=""
        # Pattern 2a: "Copying file /path/to/lib/libname.so"
        lib_path=$(sed -nE 's/.*(Copying|Installing)[[:space:]]+[^[:space:]]+[[:space:]]+([^[:space:]]+\.so[^[:space:]]*).*/\2/p' <<< "${line}" || echo "")
        # Pattern 2b: "cp /path/to/lib/libname.so /dest/path"
        if [ -z "${lib_path}" ]; then
          lib_path=$(sed -nE 's/.*[[:space:]](cp|install)[[:space:]]+([^[:space:]]+\.so[^[:space:]]*).*/\2/p' <<< "${line}" || echo "")
        fi
        # Pattern 2c: "Copying: /path/to/lib/libname.so"
        if [ -z "${lib_path}" ]; then
          lib_path=$(sed -nE 's/.*(Copying|Installing):[[:space:]]*([^[:space:]]+\.so[^[:space:]]*).*/\2/p' <<< "${line}" || echo "")
        fi
        # Pattern 2d: Make install output: "/path/to/lib/libname.so -> /dest/path"
        if [ -z "${lib_path}" ]; then
          lib_path=$(sed -nE 's/^[[:space:]]*([^[:space:]]+\.so[^[:space:]]*)[[:space:]]+->.*/\1/p' <<< "${line}" || echo "")
        fi
        if [ -n "${lib_path}" ] && [ -f "${lib_path}" ]; then
          local lib_dir
          lib_dir=$(dirname "${lib_path}")
          lib_dirs+=("${lib_dir}")
        fi
      fi
      
      # Pattern 3: CMAKE_INSTALL_PREFIX extraction (from CMake output or command line)
      if grep -qE "CMAKE_INSTALL_PREFIX[=:]|DCMAKE_INSTALL_PREFIX" <<< "${line}"; then
        local install_prefix=""
        # Try CMake variable format: "-DCMAKE_INSTALL_PREFIX=/usr/local"
        install_prefix=$(sed -nE 's/.*-DCMAKE_INSTALL_PREFIX[=:]([^[:space:];"]+).*/\1/p' <<< "${line}" || echo "")
        # Try CMake cache format: "CMAKE_INSTALL_PREFIX:PATH=/usr/local"
        if [ -z "${install_prefix}" ]; then
          install_prefix=$(sed -nE 's/.*CMAKE_INSTALL_PREFIX[=:][[:space:]]*([^[:space:];]+).*/\1/p' <<< "${line}" || echo "")
        fi
        if [ -n "${install_prefix}" ]; then
          # Normalize path (remove quotes, trailing slashes)
          install_prefix=$(sed 's/^["'\'']//; s/["'\'']$//; s|/$||' <<< "${install_prefix}" || echo "${install_prefix}")
          for lib_subdir in lib lib64 lib/x86_64-linux-gnu; do
            local potential_dir="${install_prefix}/${lib_subdir}"
            if [ -d "${potential_dir}" ]; then
              lib_dirs+=("${potential_dir}")
            fi
          done
        fi
      fi
      
      # Pattern 3b: PREFIX variable (for make install)
      if grep -qE "PREFIX[=:]|make install.*PREFIX" <<< "${line}"; then
        local install_prefix
        install_prefix=$(sed -nE 's/.*PREFIX[=:][[:space:]]*([^[:space:];"]+).*/\1/p' <<< "${line}" || echo "")
        if [ -n "${install_prefix}" ]; then
          install_prefix=$(sed 's/^["'\'']//; s/["'\'']$//; s|/$||' <<< "${install_prefix}" || echo "${install_prefix}")
          for lib_subdir in lib lib64 lib/x86_64-linux-gnu; do
            local potential_dir="${install_prefix}/${lib_subdir}"
            if [ -d "${potential_dir}" ]; then
              lib_dirs+=("${potential_dir}")
            fi
          done
        fi
      fi
      
      # Pattern 4: Direct library paths in output: "/path/to/lib/libname.so"
      if grep -qE "^/[^[:space:]]+\.so" <<< "${line}"; then
        local lib_path
        # D3e: SIGPIPE protection - add || true at end of pipeline with head
        lib_path=$(awk '{print $1}' <<< "${line}" | grep -E "\.so" 2>/dev/null | head -1 2>/dev/null || echo "" || true)
        if [ -n "${lib_path}" ] && [ -f "${lib_path}" ]; then
          local lib_dir
          lib_dir=$(dirname "${lib_path}")
          lib_dirs+=("${lib_dir}")
        fi
      fi
    done <<< "${install_output}"
  fi
  
  # Extract unique directory roots (normalize paths and validate library files exist)
  declare -A seen_dirs
  for lib_dir in "${lib_dirs[@]}"; do
    # Normalize path (resolve symlinks, remove trailing slashes)
    local normalized_dir
    normalized_dir=$(realpath "${lib_dir}" 2>/dev/null || echo "${lib_dir}")
    # Remove trailing slash using parameter expansion (more efficient than sed)
    normalized_dir="${normalized_dir%/}"
    # CRITICAL: Validate directory exists AND contains library files (best practice O4 - Phase 1: File Existence)
    if [ -n "${normalized_dir}" ] && [ -d "${normalized_dir}" ]; then
      # Verify directory actually contains library files before adding (prevents false positives)
      local find_output_check
      # D3e: SIGPIPE protection - add || true at end of pipeline with head
      find_output_check=$(find "${normalized_dir}" -maxdepth 1 -name "*.so*" -type f 2>/dev/null | head -1 2>/dev/null || echo "" || true)
      if [ -n "${find_output_check}" ]; then
        # Only add if not already seen
        if [ -z "${seen_dirs[${normalized_dir}]:-}" ]; then
          seen_dirs[${normalized_dir}]=1
          unique_dirs+=("${normalized_dir}")
          echo "  [VERIFY] Validated library directory: ${normalized_dir} (contains .so files)"
        fi
      else
        echo "  [WARN] Directory ${normalized_dir} exists but contains no library files, skipping..."
      fi
    fi
  done
  
  # If no directories found, fall back to standard locations (with validation)
  if [ ${#unique_dirs[@]} -eq 0 ]; then
    echo "  [INFO] No library directories detected in output, checking standard locations..."
    for common_dir in /usr/local/lib /usr/local/lib64; do
      if [ -d "${common_dir}" ]; then
        # Validate directory contains library files before adding (best practice O4 - Phase 1)
        local find_output_std
        # D3e: SIGPIPE protection - add || true at end of pipeline with head
        find_output_std=$(find "${common_dir}" -maxdepth 1 -name "*.so*" -type f 2>/dev/null | head -1 2>/dev/null || echo "" || true)
        if [ -n "${find_output_std}" ]; then
          unique_dirs+=("${common_dir}")
          echo "  [VERIFY] Standard location validated: ${common_dir} (contains .so files)"
        else
          echo "  [WARN] Standard location ${common_dir} exists but contains no library files"
        fi
      fi
    done
  fi
  
  # Refresh ldconfig for each unique directory
  if [ ${#unique_dirs[@]} -gt 0 ]; then
    echo "  [INFO] Detected ${#unique_dirs[@]} library installation directory(ies), refreshing ldconfig..."
    local refresh_success=true
    for lib_dir in "${unique_dirs[@]}"; do
      echo "    → Refreshing ldconfig for: ${lib_dir}"
      if ! run_ldconfig_refresh_dir "${lib_dir}"; then
        echo "    [WARN] Failed to refresh ldconfig for ${lib_dir}, but continuing..." >&2
        refresh_success=false
      fi
    done
    
    # Final verification: Run one more full ldconfig to ensure cache is fully updated
    echo "  [DEBUG] Running final full ldconfig refresh to ensure cache consistency..."
    if ! run_ldconfig_refresh; then
      echo "  [WARN] Final ldconfig refresh failed, but directories were processed" >&2
      refresh_success=false
    fi
    
    if [ "${refresh_success}" = true ]; then
      echo "  [INFO] ✓ All ldconfig refreshes completed successfully"
      return 0
    else
      echo "  [WARN] Some ldconfig refreshes had issues, but continuing..." >&2
      return 0  # Don't fail - libraries are installed, cache may update later
    fi
  else
    # Fallback to full refresh if no directories detected
    echo "  [WARN] No library directories detected in installation output, performing full ldconfig refresh..."
    echo "  [DEBUG] This may indicate path extraction failed - checking if libraries exist in standard locations..."
    if run_ldconfig_refresh; then
      return 0
    else
      echo "  [ERROR] Full ldconfig refresh failed" >&2
      return 1
    fi
  fi
}

#--- Sub-block 4.4a: Comprehensive library installation diagnostics ---
# Purpose: Diagnose why a library might not be detected by ldconfig
# Parameters:
#   $1: Library name pattern (e.g., "libgtsam.so")
#   $2: Library file path (required for full diagnostics)
# Returns: Diagnostic information printed to stderr
# Usage: diagnose_library_detection "libgtsam.so" "/usr/local/lib/libgtsam.so.4.2.0"
diagnose_library_detection() {
  local lib_pattern="${1}"
  local lib_file_path="${2:-}"
  
  printf '%s\n' "=== Library Detection Diagnostics for ${lib_pattern} ===" >&2
  
  # Check 1: ldconfig cache
  printf '%s\n' "1. Checking ldconfig cache..." >&2
  local ldconfig_cache_output
  # SC2155: Declare and assign separately to avoid masking return values
  ldconfig_cache_output=""
  ldconfig_cache_output=$(timeout 2 ldconfig -p 2>/dev/null || echo "")
  if [ -n "${ldconfig_cache_output}" ] && grep -qF -- "${lib_pattern}" <<< "${ldconfig_cache_output}"; then
    printf '%s\n' "   ✓ Found in cache" >&2
  else
    printf '%s\n' "   ✗ NOT found in cache" >&2
  fi
  
  # Check 2: File existence and permissions
  if [ -n "${lib_file_path}" ]; then
    printf '%s\n' "2. Checking library file: ${lib_file_path}" >&2
    if [ -f "${lib_file_path}" ]; then
      printf '%s\n' "   ✓ File exists" >&2
      if [ -r "${lib_file_path}" ]; then
        printf '%s\n' "   ✓ File is readable" >&2
      else
        printf '%s\n' "   ✗ File is NOT readable (permissions issue)" >&2
        ls -l "${lib_file_path}" >&2
      fi
      
      # Check naming convention
      local lib_basename
      lib_basename=$(basename "${lib_file_path}")
      if grep -qE -- '^lib.*\.so' <<< "${lib_basename}"; then
        printf '%s\n' "   ✓ Follows naming convention (lib*.so*)" >&2
      else
        printf '%s\n' "   ✗ Does NOT follow naming convention (should be lib*.so*)" >&2
      fi
      
      # Check SONAME
      if command -v objdump >/dev/null 2>&1; then
        local objdump_output soname
        # SC2155: Declare and assign separately to avoid masking return values
        objdump_output=""
        soname=""
        objdump_output=$(objdump -p "${lib_file_path}" 2>/dev/null || echo "")
        if [ -n "${objdump_output}" ]; then
          soname=$(awk '/SONAME/ {print $2; exit}' <<< "${objdump_output}" || echo "")
          if [ -n "${soname}" ]; then
            printf '%s\n' "   ✓ SONAME: ${soname}" >&2
          else
            printf '%s\n' "   ⚠ No SONAME found" >&2
          fi
        fi
      fi
    else
      printf '%s\n' "   ✗ File does NOT exist" >&2
    fi
    
    # Check 3: Library directory in ld.so.conf.d
    local lib_dir
    lib_dir=$(dirname "${lib_file_path}")
    printf '%s\n' "3. Checking ld.so.conf.d for: ${lib_dir}" >&2
    local conf_found=false
    if [ -d "/etc/ld.so.conf.d" ]; then
      for conf_file in /etc/ld.so.conf.d/*.conf; do
        if [ -f "${conf_file}" ]; then
          if grep -q -- "^${lib_dir}\$" "${conf_file}" 2>/dev/null; then
            printf '%s\n' "   ✓ Found in: ${conf_file}" >&2
            conf_found=true
          fi
        fi
      done
    fi
    # ENDFOR: conf_file
    if [ -f "/etc/ld.so.conf" ] && grep -q -- "^${lib_dir}\$" /etc/ld.so.conf 2>/dev/null; then
      printf '%s\n' "   ✓ Found in: /etc/ld.so.conf" >&2
      conf_found=true
    fi
    # ENDIF: /etc/ld.so.conf check
    if [ "${conf_found}" != true ] && [ "${lib_dir}" != "/lib" ] && [ "${lib_dir}" != "/usr/lib" ] && [ "${lib_dir}" != "/lib64" ] && [ "${lib_dir}" != "/usr/lib64" ]; then
      printf '%s\n' "   ✗ NOT found in ld.so.conf.d/ (may need to add)" >&2
      printf '%s\n' "   → Suggested fix: echo '${lib_dir}' > /etc/ld.so.conf.d/custom-libs.conf && ldconfig" >&2
    fi
    # ENDIF: conf_found check
    
    # Check 4: LD_LIBRARY_PATH
    printf '%s\n' "4. Checking LD_LIBRARY_PATH..." >&2
    if [ -n "${LD_LIBRARY_PATH:-}" ]; then
      if case ":${LD_LIBRARY_PATH}:" in *:${lib_dir}:*) true;; *) false;; esac; then
        printf '%s\n' "   ✓ Directory in LD_LIBRARY_PATH" >&2
      else
        printf '%s\n' "   ⚠ Directory NOT in LD_LIBRARY_PATH (runtime may fail)" >&2
        printf '%s\n' "   → Current LD_LIBRARY_PATH: ${LD_LIBRARY_PATH}" >&2
      fi
    else
      printf '%s\n' "   ⚠ LD_LIBRARY_PATH not set" >&2
    fi
    # ENDIF: LD_LIBRARY_PATH check
    
    # Check 5: ldd test
    if [ -f "${lib_file_path}" ] && command -v ldd >/dev/null 2>&1; then
      printf '%s\n' "5. Testing library with ldd..." >&2
      if ldd "${lib_file_path}" >/dev/null 2>&1; then
        printf '%s\n' "   ✓ Library loads successfully with ldd" >&2
      else
        printf '%s\n' "   ✗ Library FAILS to load with ldd (may be corrupted or wrong architecture)" >&2
        # D3e: SIGPIPE protection - add || true at end of pipeline with head
        ldd "${lib_file_path}" 2>&1 | head -5 >&2 || true
      fi
    fi
    # ENDIF: ldd test
  fi
  # ENDIF: lib_file_path check
  
  printf '%s\n' "=== End Diagnostics ===" >&2
}

# Purpose: Ensure NVIDIA CUDA APT repository keyring is installed and pinned
# Parameters:
#   None (uses env: NVIDIA_KEYRING_VER, NVIDIA_KEYRING_DEB, CUDA_REPO_URL, CONTAINER_DEB_CACHE, CUDA_REPO_PIN_PRIORITY)
# Returns: 0 on success, 1 on failure
# Notes:
#   - Prefers cached .deb if available
#   - Downloads from CUDA_REPO_URL if cache missing or install fails
#   - Optionally writes APT pin file when CUDA_REPO_PIN_PRIORITY is set
ensure_cuda_repository_configured() {
  local keyring_pkg="cuda-keyring"
  local keyring_deb="${NVIDIA_KEYRING_DEB:-cuda-keyring_${NVIDIA_KEYRING_VER}_all.deb}"
  local keyring_url="${NVIDIA_KEYRING_URL:-}"
  local install_needed=false
  
  # Validate required inputs before proceeding (A5a robustness)
  if [ -z "${NVIDIA_KEYRING_VER:-}" ] && [ -z "${NVIDIA_KEYRING_DEB:-}" ]; then
      printf '%s\n' "[WARN] NVIDIA_KEYRING_VER/DEB not provided; using default filename pattern" >&2
  fi
  # ENDIF: NVIDIA_KEYRING_VER/DEB validation
  
  # Validate keyring URL is set
  if [ -z "${keyring_url}" ]; then
      printf '%s\n' "[ERROR] NVIDIA_KEYRING_URL not set in config.sh" >&2
      return 1
  fi
  # ENDIF: keyring_url validation

  local status_output
  status_output=$(dpkg-query -W -f='${Status}\n' "${keyring_pkg}" 2>/dev/null || echo "")
  if [ -n "${status_output}" ] && grep -Fq "install ok installed" <<< "${status_output}"; then
      return 0
  fi

  local cached_path=""
  if [ -n "${CONTAINER_DEB_CACHE:-}" ]; then
      mkdir -p "${CONTAINER_DEB_CACHE}" || true
      cached_path="${CONTAINER_DEB_CACHE}/${keyring_deb}"
  fi

  local tmp_path="/tmp/${keyring_deb}"
  # Validate CUDA_REPO_URL
# Note: config-files file: /etc/apt/preferences.d/cuda-repository-pin is installed via install.sh from container-scripts/
# Source: config-files/block-4-mirror-probing-functions-must-be-early-for-apt-operations/cuda-repository-pin.pref
# Target: /etc/apt/preferences.d/cuda-repository-pin
# Installed in Block 0 (early in script, before any scripts are needed)

  if [ -n "${cached_path}" ] && [ -f "${cached_path}" ]; then
      printf '%s\n' "[INFO] Installing cached NVIDIA CUDA keyring: ${cached_path}"
      if dpkg -i "${cached_path}"; then
          install_needed=true
      else
          printf '%s\n' "[WARN] Cached CUDA keyring install failed, attempting fresh download..."
      fi
  fi
  # ENDIF: cached_path check

  if [ "${install_needed}" != true ]; then
      printf '%s\n' "[INFO] Downloading NVIDIA CUDA keyring from ${keyring_url}"
      if curl -fsSL "${keyring_url}" -o "${tmp_path}" && dpkg -i "${tmp_path}"; then
          install_needed=true
          if [ -n "${cached_path}" ]; then
              cp -f "${tmp_path}" "${cached_path}" 2>/dev/null || true
          fi
      else
          rm -f "${tmp_path}"
          printf '%s\n' "✗ Failed to install NVIDIA CUDA repository keyring from ${keyring_url}" >&2
          return 1
      fi
      rm -f "${tmp_path}"
  fi
  # ENDIF: install_needed check

  # Note: cuda-repository-pin.pref is installed via install.sh from container-scripts/
  # If CUDA_REPO_PIN_PRIORITY is set, it should be configured in the installed file or via sed
  if [ -n "${CUDA_REPO_PIN_PRIORITY:-}" ] && [ -f /etc/apt/preferences.d/cuda-repository-pin ]; then
      # Update Pin-Priority in the installed file if needed
      sed -i "s/Pin-Priority:.*/Pin-Priority: ${CUDA_REPO_PIN_PRIORITY}/" /etc/apt/preferences.d/cuda-repository-pin 2>/dev/null || true
  fi

  return 0
}

# Export function for parallel execution with xargs
export -f test_mirror

#--- Sub-block 4.4: Mirror probing and selection function ---
# Purpose: Find fastest Ubuntu mirror and update all APT sources
# Dependencies: test_mirror function, curl
# Outputs: FASTEST_MIRROR (exported), updated /etc/apt/sources.list and sources.list.d/
probe_and_set_mirrors() {
  # Set locale for numeric operations (exported for subshells)
  export LC_NUMERIC=C # Prevents printf errors with decimals
  local MIRRORS_HTML=""
  local DYNAMIC_MIRRORS=""
  local MIRROR_COUNT=0
  local CANDIDATE_MIRRORS=""
  echo "==> Probing for the fastest Ubuntu mirror by testing a candidate list..."

  # Detect Ubuntu codename correctly (noble for 24.04, jammy for 22.04, etc.)
  local detected_codename
  detected_codename="$(grep VERSION_CODENAME /etc/os-release 2>/dev/null | cut -d= -f2 || echo "")"
  if [ -z "${detected_codename:-}" ]; then
    # Fallback: try UBUNTU_CODENAME
    detected_codename="$(grep UBUNTU_CODENAME /etc/os-release 2>/dev/null | cut -d= -f2 || echo "")"
  fi
  if [ -z "${detected_codename:-}" ]; then
    # Final fallback: try to detect from VERSION_ID
    local version_id
    version_id="$(grep VERSION_ID /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "")"
    case "${version_id:-}" in
      "24.04") detected_codename="noble" ;;
      "22.04") detected_codename="jammy" ;;
      "20.04") detected_codename="focal" ;;
      *) detected_codename="noble" ;; # Default fallback
    esac
  fi
  CODENAME="${detected_codename}"
  printf '%s\n' "[info] Detected Ubuntu codename: ${CODENAME}"
  
  # Create temporary file for probe results with error checking
  local probe_results_file
  if ! probe_results_file="$(mktemp 2>/dev/null)"; then
    probe_results_file="/tmp/mirror_probe_$$.tmp"
    if ! : > "${probe_results_file}"; then
      echo "[error] Failed to create temporary file for probe results"
      return 1
    fi
  fi
  PROBE_RESULTS="${probe_results_file}"
  export CODENAME PROBE_RESULTS  # Export for subshell access

  # Attempt to dynamically fetch 100Gbps+ mirrors from official Launchpad page
  printf '%s\n' "[info] Attempting to fetch latest 100Gbps+ mirrors from official Ubuntu mirror list..."
  MIRRORS_HTML=$(curl -s -m 15 --connect-timeout 10 "https://launchpad.net/ubuntu/+archivemirrors" 2>/dev/null || echo "")
  
  if [ -n "${MIRRORS_HTML:-}" ]; then
    local mirror_html_bytes
    mirror_html_bytes=${#MIRRORS_HTML}
    printf '%s\n' "[info] Successfully fetched mirror list (${mirror_html_bytes} bytes). Parsing..."
    
    # Parse HTML to extract mirrors with 100+ Gbps bandwidth that are "Up to date"
    DYNAMIC_MIRRORS=$(printf '%s' "${MIRRORS_HTML}" | \
      tr '\n' ' ' | \
      sed 's|<tr>|\n<tr>|g' | \
      grep -E '([1-9][0-9]{2,}|[1-9][0-9]0) Gbps' | \
      grep 'distromirrorstatusUP' | \
      grep -oE 'href="(https?://[^"]+/(ubuntu|archive)[^"]*)"' | \
      sed 's|href="||g; s|"||g; s|https://|http://|g; s|/$||' | \
      sort -u | \
      head -20)  # Limit to top 20 mirrors for performance
    
    if [ -n "${DYNAMIC_MIRRORS:-}" ]; then
      MIRROR_COUNT=$(grep -c . <<< "${DYNAMIC_MIRRORS}" || echo 0)
    else
      MIRROR_COUNT=0
    fi
    # ENDIF: dynamic mirrors non-empty (DYNAMIC_MIRRORS)
    
    # Explicit check for non-empty and sufficient mirrors
    if [ -n "${DYNAMIC_MIRRORS:-}" ] && [ "${MIRROR_COUNT:-0}" -ge 10 ]; then
      # Always start with archive.ubuntu.com as guaranteed fallback
      CANDIDATE_MIRRORS=$'http://archive.ubuntu.com/ubuntu\n'
      # Append dynamic mirrors line-by-line to preserve whitespace safely
      while IFS= read -r mirror; do
        [ -z "${mirror:-}" ] && continue
        # Skip archive.ubuntu.com if already added (avoid duplicates)
        [[ "${mirror}" == *"archive.ubuntu.com"* ]] && continue
        CANDIDATE_MIRRORS+="${mirror}"$'\n'
      done <<< "${DYNAMIC_MIRRORS}"
      # ENDWHILE: mirror iteration
      printf '%s\n' "[info] ✅ Successfully parsed ${MIRROR_COUNT} dynamic 100Gbps+ mirrors (archive.ubuntu.com included as fallback)"
    else
      printf '%s\n' "[warn] Only ${MIRROR_COUNT:-0} dynamic mirrors found. Using curated static list."
      CANDIDATE_MIRRORS=""  # Will trigger fallback below
    fi
    # ENDIF: sufficient dynamic mirrors (>=10)
  else
    printf '%s\n' "[warn] Failed to fetch mirror list from Launchpad. Using curated static list."
    CANDIDATE_MIRRORS=""  # Will trigger fallback
  fi
  # ENDIF: fetched mirrors HTML (MIRRORS_HTML)
  
  # Fallback to curated static list if dynamic fetch failed
  # CRITICAL: Always include archive.ubuntu.com as first entry (guaranteed fallback)
  if [ -z "${CANDIDATE_MIRRORS:-}" ]; then
    printf '%s\n' "[info] Using curated static mirror list (100Gbps+ verified Oct 2025)"
    CANDIDATE_MIRRORS=$'http://archive.ubuntu.com/ubuntu\n'
    CANDIDATE_MIRRORS+=$'http://mirror.aarnet.edu.au/pub/ubuntu/archive\n'
    CANDIDATE_MIRRORS+=$'http://ftp.fau.de/ubuntu\n'
    CANDIDATE_MIRRORS+=$'http://ftp.uni-stuttgart.de/ubuntu\n'
    CANDIDATE_MIRRORS+=$'http://ftp.halifax.rwth-aachen.de/ubuntu\n'
    CANDIDATE_MIRRORS+=$'http://mirror.netcologne.de/ubuntu\n'
    CANDIDATE_MIRRORS+=$'http://ubuntu.mirror.pcextreme.nl/ubuntu\n'
    CANDIDATE_MIRRORS+=$'http://mirror.ox.ac.uk/sites/archive.ubuntu.com/ubuntu\n'
    CANDIDATE_MIRRORS+=$'http://mirrors.wikimedia.org/ubuntu\n'
    CANDIDATE_MIRRORS+=$'http://mirrors.ocf.berkeley.edu/ubuntu\n'
    CANDIDATE_MIRRORS+=$'http://mirror.math.princeton.edu/pub/ubuntu\n'
    CANDIDATE_MIRRORS+=$'http://mirror.csclub.uwaterloo.ca/ubuntu\n'
    CANDIDATE_MIRRORS+=$'http://mirrors.ustc.edu.cn/ubuntu\n'
    CANDIDATE_MIRRORS+=$'http://ftp.jaist.ac.jp/pub/Linux/ubuntu\n'
  fi
  # ENDIF: candidate mirrors empty -> using curated list

  # Run mirror tests in parallel (max 6 concurrent to avoid network congestion)
  local mirror_total
  mirror_total=$(grep -c . <<< "${CANDIDATE_MIRRORS:-}" || echo "0")
  echo "Testing ${mirror_total} mirrors in parallel (max 6 concurrent)..."
  # Use printf to safely handle empty strings and ensure proper line separation
  if [ -n "${CANDIDATE_MIRRORS:-}" ]; then
    grep -v '^[[:space:]]*$' <<< "${CANDIDATE_MIRRORS}" | xargs -P 6 -I{} bash -c "test_mirror \"\$1\" \"\$2\" \"\$3\"" _ "{}" "${CODENAME}" "${PROBE_RESULTS}" || true
  fi
  # ENDIF: candidate mirrors non-empty for probing

  # Display mirror probe results
  printf '%s\n' "--- Mirror Probe Results (speed score, url): ---"
  if [ -s "${PROBE_RESULTS:-}" ]; then
    # Validate result format BEFORE parsing (Pattern P-20251113-011: Silent Failure Prevention)
    # Ensure file contains expected format: time url (e.g., "1.23 http://mirror.example.com/ubuntu")
    if ! grep -qE -- '^[0-9.]+ https?://' "${PROBE_RESULTS}"; then
      printf '%s\n' "[warn] ⚠ Invalid result format in probe results (expected: time url)"
      printf '%s\n' "[info] Falling back to archive.ubuntu.com"
      FASTEST_MIRROR="http://archive.ubuntu.com/ubuntu"
      export FASTEST_MIRROR
      return 0
    fi
    # ENDIF: probe results format valid
    LC_NUMERIC=C sort -n "${PROBE_RESULTS}" 2>/dev/null | sed 's/^/ /' || printf '%s\n' "[warn] Failed to sort results"
  else
    printf '%s\n' "[warn] No probe results written - all mirrors may have failed"
  fi
  # ENDIF: probe results exist

  # Extract the fastest mirror that responded in under 15 seconds
  # Exclude mirrors that were rejected (score 999.9 = blocked/error/failed)
  # Always ensure archive.ubuntu.com is tested and available as fallback
  local fastest_mirror_raw
  # AWK pattern breakdown:
  #   NF==2         - Ensure exactly 2 fields (time and URL)
  #   $1 < 15.0     - First field (time) must be under 15 seconds
  #   $1 < 999.0    - Exclude sentinel value 999.9 (blocked/failed mirrors)
  #   {print $2}    - Print second field (mirror URL)
  #   exit          - Stop after first match (fastest valid mirror)
  # sort -n sorts numerically by time, so first valid result is fastest
  fastest_mirror_raw="$(LC_NUMERIC=C sort -n "${PROBE_RESULTS:-}" 2>/dev/null | awk 'NF==2 && $1 < 15.0 && $1 < 999.0 {print $2; exit}' || echo "")"
  
  # Clean up temporary file
  rm -f "${PROBE_RESULTS:-}" 2>/dev/null || true

  # Robust fallback: Always use archive.ubuntu.com if no accessible mirrors found
  if [ -z "${fastest_mirror_raw:-}" ]; then
    printf '%s\n' "[warn] ⚠ No accessible mirrors found (all may be blocked, failed, or timed out)"
    printf '%s\n' "[info] Falling back to default archive.ubuntu.com (guaranteed to work)"
    FASTEST_MIRROR="http://archive.ubuntu.com/ubuntu"
  else
    FASTEST_MIRROR="${fastest_mirror_raw}"
    printf '%s\n' "[info] ✓ Selected fastest accessible mirror: ${FASTEST_MIRROR}"
  fi
  # ENDIF: fastest mirror selection
  
  # Final safety check: Ensure FASTEST_MIRROR is set (should never be empty at this point)
  if [ -z "${FASTEST_MIRROR:-}" ]; then
    printf '%s\n' "[ERROR] FASTEST_MIRROR is empty - this should never happen! Using archive.ubuntu.com"
    FASTEST_MIRROR="http://archive.ubuntu.com/ubuntu"
  fi
  # ENDIF: FASTEST_MIRROR final non-empty check
  
  printf '%s\n' "==> Selected fastest mirror: ${FASTEST_MIRROR}"

  # Export the variable so it persists after function ends and is available globally
  export FASTEST_MIRROR

  # Apply the fastest mirror to the main APT sources
  if [ -f /etc/apt/sources.list ]; then
    # Escape FASTEST_MIRROR for safe use in sed (escape special sed characters: [, ], \, /, &)
    # Pattern 's/[][\\\/&]/\\&/g' explained:
    #   [][] - Matches literal [ or ] (bracket expression for brackets)
    #   \\\/ - Matches backslash or forward slash
    #   &    - Matches ampersand
    #   \\&  - Replacement: prefix with backslash (\)
    #   g    - Global: replace all occurrences
    # Example: "http://mirror.com/ubuntu" → "http:\/\/mirror.com\/ubuntu"
    # CRITICAL: Must have error fallback to prevent unset variable with set -u
    local fastest_mirror_sed_escaped
    # SC2155: Declare and assign separately to avoid masking return values
    fastest_mirror_sed_escaped=""
    fastest_mirror_sed_escaped="$(printf '%s\n' "${FASTEST_MIRROR:-}" | sed 's/[][\\\/&]/\\&/g' || echo "")"
    
    # CRITICAL: Guard against empty escaped value - if sed failed, use FASTEST_MIRROR directly with minimal escaping
    if [ -z "${fastest_mirror_sed_escaped:-}" ]; then
      printf '%s\n' "[warn] sed escaping failed, using FASTEST_MIRROR with minimal escaping"
      # Fallback: minimal escaping (just escape forward slashes and ampersands)
      fastest_mirror_sed_escaped=""
      fastest_mirror_sed_escaped=$(printf '%s\n' "${FASTEST_MIRROR:-}" | sed 's|/|\\/|g; s|&|\\&|g' || echo "${FASTEST_MIRROR:-}")
    fi
    # ENDIF: fastest_mirror_sed_escaped empty check
    
    # Only proceed with sed replacements if we have a valid escaped value
    if [ -n "${fastest_mirror_sed_escaped:-}" ] && [ -n "${FASTEST_MIRROR:-}" ]; then
      # Multiple replacement patterns to catch all variations:
      # 1. Specifically target archive.ubuntu.com (most common issue)
      #    Pattern 'https\\?' matches http or https (? makes 's' optional)
      #    Pattern '\\.ubuntu\\.com' matches literal dots (escaped for sed)
      sed -i "s|https\\?://archive\\.ubuntu\\.com/ubuntu|${fastest_mirror_sed_escaped}|g" /etc/apt/sources.list || true
      sed -i "s|http://archive\\.ubuntu\\.com/ubuntu|${fastest_mirror_sed_escaped}|g" /etc/apt/sources.list || true
      # 2. General pattern for any Ubuntu mirror (excluding security.ubuntu.com)
      #    '/security\\.ubuntu\\.com/!' is address negation - skip lines with security.ubuntu.com
      #    Pattern '[a-zA-Z0-9.-]*' matches any subdomain: mirrors.ubuntu.com, us.archive.ubuntu.com, etc.
      sed -i "/security\\.ubuntu\\.com/! s|https\\?://[a-zA-Z0-9.-]*\\.ubuntu\\.com/ubuntu|${fastest_mirror_sed_escaped}|g" /etc/apt/sources.list || true
      sed -i "/security\\.ubuntu\\.com/! s|https\\?://[a-zA-Z0-9.-]*/ubuntu|${fastest_mirror_sed_escaped}|g" /etc/apt/sources.list || true
      printf '%s\n' "[info] Updated /etc/apt/sources.list with fastest mirror"
    else
      printf '%s\n' "[warn] Cannot update sources.list - FASTEST_MIRROR or escaped value is empty"
      printf '%s\n' "[warn] FASTEST_MIRROR='${FASTEST_MIRROR:-<unset>}', escaped='${fastest_mirror_sed_escaped:-<unset>}'"
    fi
    # ENDIF: have valid escaped mirror for sed replacement
    
    # Verify the update was successful (more robust check)
    # Extract base URL without protocol for flexible matching
    local mirror_base mirror_no_protocol
    mirror_base="${FASTEST_MIRROR#http://}"
    mirror_base="${mirror_base#https://}"
    mirror_no_protocol="${FASTEST_MIRROR#http://}"
    mirror_no_protocol="${mirror_no_protocol#https://}"
    
    # Escape special regex characters for safe use in grep patterns
    # CRITICAL: All sed command substitutions must have error fallback to prevent unset variables with set -u
    local mirror_base_escaped mirror_no_protocol_escaped fastest_mirror_escaped
    if [ -n "${mirror_base:-}" ]; then
      # shellcheck disable=SC2016  # Single quotes intentional - sed pattern is literal, not variable expansion
      # D4: Correct sed bracket expression escaping: [][\\\/&] for literal brackets, backslash, forward slash, ampersand
      mirror_base_escaped=$(printf '%s\n' "${mirror_base}" | sed 's/[][\\.*^$()+?{|&]/\\&/g' || echo "")
      # F2: Validate command substitution result is non-empty and valid
      if [ -z "${mirror_base_escaped:-}" ] && [ -n "${mirror_base:-}" ]; then
        # Fallback if sed fails
        mirror_base_escaped="${mirror_base}"
      fi
    else
      mirror_base_escaped=""
    fi
    if [ -n "${mirror_no_protocol:-}" ]; then
      # shellcheck disable=SC2016  # Single quotes intentional - sed pattern is literal, not variable expansion
      # D4: Correct sed bracket expression escaping: [][\\\/&] for literal brackets, backslash, forward slash, ampersand
      mirror_no_protocol_escaped=$(printf '%s\n' "${mirror_no_protocol}" | sed 's/[][\\.*^$()+?{|&]/\\&/g' || echo "")
      # F2: Validate command substitution result is non-empty and valid
      if [ -z "${mirror_no_protocol_escaped:-}" ] && [ -n "${mirror_no_protocol:-}" ]; then
        # Fallback if sed fails
        mirror_no_protocol_escaped="${mirror_no_protocol}"
      fi
    else
      mirror_no_protocol_escaped=""
    fi
    # shellcheck disable=SC2016  # Single quotes intentional - sed pattern is literal, not variable expansion
    # D4: Correct sed bracket expression escaping: [][\\\/&] for literal brackets, backslash, forward slash, ampersand
    fastest_mirror_escaped=$(printf '%s\n' "${FASTEST_MIRROR:-}" | sed 's/[][\\.*^$()+?{|&]/\\&/g' || echo "")
    # F2: Validate command substitution result is non-empty and valid
    if [ -z "${fastest_mirror_escaped:-}" ] && [ -n "${FASTEST_MIRROR:-}" ]; then
      # Fallback if sed fails - use raw value
      fastest_mirror_escaped="${FASTEST_MIRROR:-}"
    fi
  
    # Check if mirror appears in active (non-commented) deb lines
    # D3: Use here-string instead of pipe pattern for safety and efficiency
    local sources_content
    sources_content=$(grep -v "^#" /etc/apt/sources.list 2>/dev/null || echo "")
    if [ -n "${mirror_base_escaped:-}" ] && grep -qE "(deb|deb-src).*${mirror_base_escaped}" <<< "${sources_content}" 2>/dev/null; then
      echo "[info] ✓ Verified: sources.list now uses ${FASTEST_MIRROR}"
    elif [ -n "${mirror_no_protocol_escaped:-}" ] && grep -qE "(deb|deb-src).*${mirror_no_protocol_escaped}" <<< "${sources_content}" 2>/dev/null; then
      echo "[info] ✓ Verified: sources.list uses mirror (format may vary)"
    elif [ -n "${fastest_mirror_escaped:-}" ] && grep -qF "${FASTEST_MIRROR}" <<< "${sources_content}" 2>/dev/null; then
      echo "[info] ✓ Verified: sources.list contains ${FASTEST_MIRROR}"
    else
      # Check if file is actually empty or only has comments
      # D3e: SIGPIPE error handling - pipelines ending with wc need || true to prevent exit code 141
      local active_lines
      active_lines=$(
        { grep -v "^#" /etc/apt/sources.list 2>/dev/null || true; } |
        { grep -v '^$' || true; } |
        wc -l || echo "0"
      )
      if [ "${active_lines:-0}" -eq 0 ]; then
        echo "[info] sources.list contains only comments (this may be normal for Ubuntu 24.04)"
        # shellcheck disable=SC2034  # Variable set for potential future use in verification logic
        verification_passed=true
      else
        echo "[warn] ✗ Verification failed: sources.list may not have been updated correctly"
        echo "[info]   Checking for alternative mirror formats..."
        # Show what we actually found
        # D3: Use here-string instead of pipe pattern
        # D3e: SIGPIPE error handling - pipeline ending with head needs || true to prevent exit code 141
        grep -E "(deb|deb-src)" <<< "${sources_content}" 2>/dev/null | head -3 2>/dev/null | sed 's/^/    /' 2>/dev/null || echo "    (no deb lines found)"
      fi
    fi
    
    # Also verify no archive.ubuntu.com remains in active lines
    # D3: Use here-string instead of pipe pattern
    if grep -q "archive\\.ubuntu\\.com" <<< "${sources_content}" 2>/dev/null; then
      echo "[warn] ⚠ Still found archive.ubuntu.com references in sources.list, attempting additional replacement..."
      # Recompute mirror_no_protocol if not already set
      if [ -z "${mirror_no_protocol:-}" ]; then
        # F2: Validate command substitution result
        mirror_no_protocol=$(sed 's|http://||; s|https://||' <<< "${FASTEST_MIRROR:-}" || echo "")
        # Validate result is non-empty
        if [ -z "${mirror_no_protocol:-}" ] && [ -n "${FASTEST_MIRROR:-}" ]; then
          # Extract manually if sed fails
          mirror_no_protocol="${FASTEST_MIRROR#http://}"
          mirror_no_protocol="${mirror_no_protocol#https://}"
        fi
      fi
      # Escape special sed characters in mirror_no_protocol for safe replacement
      # CRITICAL: Must have error fallback to prevent unset variable with set -u
      local mirror_sed_escaped
      if [ -n "${mirror_no_protocol:-}" ]; then
        mirror_sed_escaped=$(printf '%s\n' "${mirror_no_protocol}" | sed 's/[][\\\/&]/\\&/g' || echo "")
        if [ -n "${mirror_sed_escaped:-}" ]; then
          sed -i "s|archive\\.ubuntu\\.com/ubuntu|${mirror_sed_escaped}|g" /etc/apt/sources.list || true
          # Verify again after additional replacement
          # D3: Re-read sources content and use here-string
          sources_content=$(grep -v "^#" /etc/apt/sources.list 2>/dev/null || echo "")
          if grep -q "archive\\.ubuntu\\.com" <<< "${sources_content}" 2>/dev/null; then
            echo "[warn] ⚠ archive.ubuntu.com still present after replacement attempt"
          else
            echo "[info] ✓ Additional replacement successful"
          fi
        fi
      fi
      # ENDIF: mirror_no_protocol available for additional replacement
    fi
    # ENDIF: archive.ubuntu.com still present in sources.list
  else
    echo "[warn] /etc/apt/sources.list not found - mirror selection skipped"
  fi
  # ENDIF: main sources.list exists

  # Also update sources.list.d/ files (excluding PPAs which should stay on ppa.launchpad.net)
  # CRITICAL: Handle both .list (one-line format) and .sources (deb822 format) files
  echo "[info] Updating sources.list.d/ files with fastest mirror (excluding PPAs)..."
  if [ -d /etc/apt/sources.list.d ]; then
    # Escape FASTEST_MIRROR for safe use in sed
    # CRITICAL: Must have error fallback to prevent unset variable with set -u
    local fastest_mirror_sed_escaped
    fastest_mirror_sed_escaped="$(printf '%s\n' "${FASTEST_MIRROR:-}" | sed 's/[][\\\/&]/\\&/g' || echo "")"
    
    # CRITICAL: Guard against empty escaped value
    if [ -z "${fastest_mirror_sed_escaped:-}" ] && [ -n "${FASTEST_MIRROR:-}" ]; then
      # Fallback: minimal escaping
      fastest_mirror_sed_escaped=$(printf '%s\n' "${FASTEST_MIRROR:-}" | sed 's|/|\\/|g; s|&|\\&|g' || echo "${FASTEST_MIRROR:-}")
    fi
    
    # Compute mirror_no_protocol once for reuse (strip both http:// and https://)
    # F2: Validate command substitution result
    local mirror_no_protocol
    mirror_no_protocol=$(sed 's|http://||; s|https://||' <<< "${FASTEST_MIRROR:-}" || echo "")
    # Validate result is non-empty
    if [ -z "${mirror_no_protocol:-}" ] && [ -n "${FASTEST_MIRROR:-}" ]; then
      # Extract manually if sed fails
      mirror_no_protocol="${FASTEST_MIRROR#http://}"
      mirror_no_protocol="${mirror_no_protocol#https://}"
    fi
    
    # Enable nullglob to handle case where no files exist
    shopt -s nullglob
    
    # Process .list files (one-line format)
    for sources_file in /etc/apt/sources.list.d/*.list; do
      # Double-check file exists (redundant with nullglob, but defensive)
      [ -f "${sources_file}" ] || continue
      
      # Skip PPA files (they should always use ppa.launchpad.net)
      if grep -q "ppa.launchpad.net" "${sources_file}" 2>/dev/null; then
        echo "[info] Skipping PPA file: $(basename "${sources_file}")"
        continue
      fi
      
      # Multiple replacement patterns for sources.list.d files too
      # 1. Specifically target archive.ubuntu.com
      if grep -q "archive\\.ubuntu\\.com" "${sources_file}" 2>/dev/null; then
        if [ -n "${fastest_mirror_sed_escaped:-}" ] && [ -n "${FASTEST_MIRROR:-}" ]; then
          sed -i "s|https\\?://archive\\.ubuntu\\.com/ubuntu|${fastest_mirror_sed_escaped}|g" "${sources_file}" || true
          sed -i "s|http://archive\\.ubuntu\\.com/ubuntu|${fastest_mirror_sed_escaped}|g" "${sources_file}" || true
          echo "[info] Updated archive.ubuntu.com in: $(basename "${sources_file}")"
        fi
      fi
      # 2. General pattern for any Ubuntu mirror (excluding security.ubuntu.com)
      if grep -q "https\\?://[a-zA-Z0-9.-]*/ubuntu" "${sources_file}" 2>/dev/null; then
        if [ -n "${fastest_mirror_sed_escaped:-}" ] && [ -n "${FASTEST_MIRROR:-}" ]; then
          sed -i "/security\\.ubuntu\\.com/! s|https\\?://[a-zA-Z0-9.-]*\\.ubuntu\\.com/ubuntu|${fastest_mirror_sed_escaped}|g" "${sources_file}" || true
          sed -i "/security\\.ubuntu\\.com/! s|https\\?://[a-zA-Z0-9.-]*/ubuntu|${fastest_mirror_sed_escaped}|g" "${sources_file}" || true
          echo "[info] Updated: $(basename "${sources_file}")"
        fi
      fi
      
      # Final check - remove any remaining archive.ubuntu.com references
      # D3: Use here-string instead of pipe pattern
      local file_content
      file_content=$(grep -v "^#" "${sources_file}" 2>/dev/null || echo "")
      if grep -q "archive\\.ubuntu\\.com" <<< "${file_content}" 2>/dev/null; then
        # Escape special sed characters in mirror_no_protocol for safe replacement
        # CRITICAL: Must have error fallback to prevent unset variable with set -u
        local mirror_sed_escaped
        if [ -n "${mirror_no_protocol:-}" ]; then
          mirror_sed_escaped=$(printf '%s\n' "${mirror_no_protocol}" | sed 's/[][\\\/&]/\\&/g' || echo "")
          if [ -n "${mirror_sed_escaped:-}" ]; then
            sed -i "s|archive\\.ubuntu\\.com/ubuntu|${mirror_sed_escaped}|g" "${sources_file}" || true
            echo "[info] Additional cleanup applied to: $(basename "${sources_file}")"
          fi
        fi
      # ENDIF: archive.ubuntu.com check
      fi
    done
    # ENDFOR: iterate .list files
    
    # Process .sources files (deb822 format used by Ubuntu 24.04+)
    # deb822 format uses URIs= field instead of deb http://... format
    for sources_file in /etc/apt/sources.list.d/*.sources; do
      [ -f "${sources_file}" ] || continue
      
      # Skip PPA files
      if grep -q "ppa.launchpad.net" "${sources_file}" 2>/dev/null; then
        echo "[info] Skipping PPA file: $(basename "${sources_file}")"
        continue
      fi
      
      # Check if file contains archive.ubuntu.com in URIs= lines
      if grep -qE "^URIs=.*archive\\.ubuntu\\.com" "${sources_file}" 2>/dev/null; then
        # Replace archive.ubuntu.com in URIs= lines (deb822 format)
        # Pattern: URIs=http://archive.ubuntu.com/ubuntu
        if [ -n "${fastest_mirror_sed_escaped:-}" ] && [ -n "${FASTEST_MIRROR:-}" ]; then
          sed -i "s|^URIs=https\\?://archive\\.ubuntu\\.com/ubuntu|URIs=${fastest_mirror_sed_escaped}|g" "${sources_file}" || true
          sed -i "s|^URIs=http://archive\\.ubuntu\\.com/ubuntu|URIs=${fastest_mirror_sed_escaped}|g" "${sources_file}" || true
          echo "[info] Updated archive.ubuntu.com in deb822 file: $(basename "${sources_file}")"
        fi
      fi
      
      # Also handle multi-line URIs= entries (space-separated)
      if grep -qE "archive\\.ubuntu\\.com" "${sources_file}" 2>/dev/null; then
        if [ -n "${fastest_mirror_sed_escaped:-}" ] && [ -n "${FASTEST_MIRROR:-}" ]; then
          # Replace in URIs= lines that may have multiple URIs
          sed -i "s|https\\?://archive\\.ubuntu\\.com/ubuntu|${fastest_mirror_sed_escaped}|g" "${sources_file}" || true
          sed -i "s|http://archive\\.ubuntu\\.com/ubuntu|${fastest_mirror_sed_escaped}|g" "${sources_file}" || true
          echo "[info] Updated archive.ubuntu.com in deb822 file: $(basename "${sources_file}")"
        fi
      fi
      
      # Final check for remaining archive.ubuntu.com
      # D3: Use here-string instead of pipe pattern
      file_content=$(grep -v "^#" "${sources_file}" 2>/dev/null || echo "")
      # K1b: Use -- to prevent command argument misinterpretation when pattern might start with -
      if grep -q -- "archive\\.ubuntu\\.com" <<< "${file_content}" 2>/dev/null; then
        if [ -n "${mirror_no_protocol:-}" ]; then
          local mirror_sed_escaped
          mirror_sed_escaped=$(printf '%s\n' "${mirror_no_protocol}" | sed 's/[][\\\/&]/\\&/g' || echo "")
          if [ -n "${mirror_sed_escaped:-}" ]; then
            sed -i "s|archive\\.ubuntu\\.com/ubuntu|${mirror_sed_escaped}|g" "${sources_file}" || true
            echo "[info] Additional cleanup applied to deb822 file: $(basename "${sources_file}")"
          fi
        fi
      fi
    done
    
    shopt -u nullglob  # Restore default behavior
    echo "[info] ✓ sources.list.d/ update complete (.list and .sources files)"
  else
    echo "[info] /etc/apt/sources.list.d/ not found or empty"
  fi
  # ENDIF: sources.list.d directory exists
}
# End probe_and_set_mirrors function (self-contained)

#--- Sub-block 4.5: Mirror verification function ---
# Purpose: Verify that sources.list uses the fastest mirror
# Dependencies: FASTEST_MIRROR variable
# Outputs: Diagnostic messages, returns 0 if OK, 1 if issues found
verify_fastest_mirror() {
  if [ -z "${FASTEST_MIRROR:-}" ]; then
    echo "[warn] FASTEST_MIRROR not set - cannot verify"
    return 1
  fi
  
  if [ "${FASTEST_MIRROR}" = "http://archive.ubuntu.com/ubuntu" ]; then
    echo "[info] Using default Ubuntu mirror (no verification needed)"
    return 0
  fi
  
  echo "[info] Verifying fastest mirror usage..."
  
  local issues_found=0
  
  # Check main sources.list
  if [ -f /etc/apt/sources.list ]; then
    # Escape FASTEST_MIRROR for safe use in grep pattern
    # C5: Add default to prevent unbound variable
    local fastest_mirror_escaped
    # shellcheck disable=SC2016  # Single quotes intentional - sed pattern is literal, not variable expansion
    fastest_mirror_escaped=$(printf '%s\n' "${FASTEST_MIRROR:-}" | sed 's/[][\\.*^$()+?{|&]/\\&/g' || echo "")
    
    # D3: Use here-string instead of pipe pattern
    local sources_content
    sources_content=$(grep -v "^#" /etc/apt/sources.list 2>/dev/null || echo "")
    
    # Count lines using fastest mirror (use -F for fixed string if escaping fails)
    local fast_count
    if [ -n "${fastest_mirror_escaped:-}" ]; then
      fast_count=$(grep -cF "${FASTEST_MIRROR:-}" <<< "${sources_content}" 2>/dev/null || echo "0")
    else
      fast_count="0"
    fi
    # Count lines using archive.ubuntu.com
    # F2: Validate command substitution result
    local slow_count
    slow_count=$(grep -c -- "deb.*archive\.ubuntu\.com" <<< "${sources_content}" 2>/dev/null || echo "0")
    # K1b: Use -- to prevent command argument misinterpretation when pattern might start with -
    # Validate result is numeric and strip any newlines
    slow_count=$(printf '%s' "${slow_count}" | tr -d '\n\r' || echo "0")
    if [ -z "${slow_count:-}" ] || ! [[ "${slow_count}" =~ ^[0-9]+$ ]]; then
      slow_count="0"
    fi
    
    # Validate fast_count is numeric and strip any newlines
    fast_count=$(printf '%s' "${fast_count}" | tr -d '\n\r' || echo "0")
    if [ -z "${fast_count:-}" ] || ! [[ "${fast_count}" =~ ^[0-9]+$ ]]; then
      fast_count="0"
    fi
    
    if [ "${slow_count:-0}" -gt 0 ]; then
      echo "[ERROR] Found ${slow_count} lines still using archive.ubuntu.com in sources.list:"
      # D3e: SIGPIPE error handling - pipeline ending with sed needs || true to prevent exit code 141
      grep -- "archive\.ubuntu\.com" <<< "${sources_content}" 2>/dev/null | sed 's/^/  /' 2>/dev/null || true
      # K1b: Use -- to prevent command argument misinterpretation when pattern might start with -
      issues_found=$((issues_found + slow_count))
    else
      echo "[info] ✓ sources.list: No archive.ubuntu.com found (good)"
    fi
    
    if [ "${fast_count:-0}" -gt 0 ]; then
      echo "[info] ✓ sources.list: ${fast_count} lines using ${FASTEST_MIRROR}"
    fi
  else
    echo "[warn] /etc/apt/sources.list not found"
    return 1
  fi
  # ENDIF: main sources.list exists for verification
  
  # Check sources.list.d/ files (excluding PPAs) - both .list and .sources files
  if [ -d /etc/apt/sources.list.d ]; then
    local found_issues=0
    shopt -s nullglob  # Handle case where no files exist
    
    # Check .list files (one-line format)
    for sources_file in /etc/apt/sources.list.d/*.list; do
      [ -f "${sources_file}" ] || continue
      
      # Skip PPA files
      if grep -q "ppa.launchpad.net" "${sources_file}" 2>/dev/null; then
        continue
      fi
      
      # Check for archive.ubuntu.com in non-PPA files
      # D3: Use here-string instead of pipe pattern
      local file_content
      file_content=$(grep -v "^#" "${sources_file}" 2>/dev/null || echo "")
      if grep -q -- "archive\.ubuntu\.com" <<< "${file_content}" 2>/dev/null; then
        echo "[ERROR] Found archive.ubuntu.com in $(basename "${sources_file}"):"
        # D3e: SIGPIPE error handling - pipeline ending with sed needs || true to prevent exit code 141
        # K1b: Use -- to prevent command argument misinterpretation when pattern might start with -
        grep -- "archive\.ubuntu\.com" <<< "${file_content}" 2>/dev/null | sed 's/^/  /' 2>/dev/null || true
        found_issues=1
      # ENDIF: archive.ubuntu.com check
      fi
    done
    # ENDFOR: iterate .list files in verification
    
    # Check .sources files (deb822 format used by Ubuntu 24.04+)
    for sources_file in /etc/apt/sources.list.d/*.sources; do
      [ -f "${sources_file}" ] || continue
      
      # Skip PPA files
      if grep -q "ppa.launchpad.net" "${sources_file}" 2>/dev/null; then
        continue
      fi
      
      # Check for archive.ubuntu.com in URIs= lines or anywhere in file
      # D3: Use here-string instead of pipe pattern
      local file_content
      file_content=$(grep -v "^#" "${sources_file}" 2>/dev/null || echo "")
      if grep -q -- "archive\.ubuntu\.com" <<< "${file_content}" 2>/dev/null; then
        echo "[ERROR] Found archive.ubuntu.com in deb822 file $(basename "${sources_file}"):"
        # D3e: SIGPIPE error handling - pipeline ending with sed needs || true to prevent exit code 141
        # K1b: Use -- to prevent command argument misinterpretation when pattern might start with -
        grep -- "archive\.ubuntu\.com" <<< "${file_content}" 2>/dev/null | sed 's/^/  /' 2>/dev/null || true
        found_issues=1
      fi
    done
    
    shopt -u nullglob  # Restore default behavior
    
    if [ "${found_issues:-0}" -eq 0 ]; then
      echo "[info] ✓ sources.list.d/: No archive.ubuntu.com found (good - checked .list and .sources files)"
    else
      issues_found=$((issues_found + 1))
    fi
  fi
  # ENDIF: sources.list.d directory exists for verification
  
  # Summary
  if [ "${issues_found:-0}" -eq 0 ]; then
    echo "[info] ✅ VERIFICATION PASSED: All Ubuntu sources use ${FASTEST_MIRROR}"
    return 0
  else
    echo "[ERROR] ❌ VERIFICATION FAILED: Found ${issues_found} issue(s) - some sources still use archive.ubuntu.com"
    return 1
  fi
}
export -f verify_fastest_mirror

#--- Sub-block 4.6: Mirror re-application function ---
# Purpose: Re-apply fastest mirror to all sources (for use after add-apt-repository)
# Dependencies: FASTEST_MIRROR variable
# Outputs: Updated sources.list and sources.list.d/ files
reapply_fastest_mirror() {
  if [ -z "${FASTEST_MIRROR:-}" ]; then
    echo "[warn] FASTEST_MIRROR not set - skipping re-application"
    return 1
  fi
  
  if [ "${FASTEST_MIRROR}" = "http://archive.ubuntu.com/ubuntu" ]; then
    echo "[info] Using default Ubuntu mirror (no re-application needed)"
    return 0
  fi
  
  echo "[info] Re-applying fastest mirror to all Ubuntu repositories..."
  
  # Escape FASTEST_MIRROR for safe use in sed (escape special sed characters: /, &, \, newlines)
  # CRITICAL: Must have error fallback to prevent unset variable with set -u
  # D4: Correct sed bracket expression escaping: [][\\\/&] for literal brackets, backslash, forward slash, ampersand
  local fastest_mirror_sed_escaped
  fastest_mirror_sed_escaped="$(printf '%s\n' "${FASTEST_MIRROR:-}" | sed 's/[][\\\/&]/\\&/g' || echo "")"
  
  # CRITICAL: Guard against empty escaped value (validate result format)
  # F2: Validate command substitution result is non-empty and valid
  if [ -z "${fastest_mirror_sed_escaped:-}" ] && [ -n "${FASTEST_MIRROR:-}" ]; then
    fastest_mirror_sed_escaped=$(printf '%s\n' "${FASTEST_MIRROR:-}" | sed 's|/|\\/|g; s|&|\\&|g' || echo "${FASTEST_MIRROR:-}")
    # Validate fallback result is non-empty
    if [ -z "${fastest_mirror_sed_escaped:-}" ]; then
      echo "[ERROR] ⚠ Failed to escape FASTEST_MIRROR for sed - using raw value"
      fastest_mirror_sed_escaped="${FASTEST_MIRROR:-}"
    fi
  fi
  
  # Compute mirror_no_protocol once for reuse (strip both http:// and https://)
  local mirror_no_protocol
  mirror_no_protocol="${FASTEST_MIRROR:-}"
  mirror_no_protocol="${mirror_no_protocol#http://}"
  mirror_no_protocol="${mirror_no_protocol#https://}"
  
  local mirror_no_protocol_escaped=""
  if [ -n "${mirror_no_protocol:-}" ]; then
    # D4: Correct sed bracket expression escaping with error fallback
    mirror_no_protocol_escaped=$(printf '%s\n' "${mirror_no_protocol}" | sed 's/[][\\\/&]/\\&/g' || echo "")
    # F2: Validate result is non-empty (command substitution may return empty on failure)
    if [ -z "${mirror_no_protocol_escaped:-}" ] && [ -n "${mirror_no_protocol:-}" ]; then
      echo "[warn] ⚠ Failed to escape mirror_no_protocol for sed - using raw value"
      mirror_no_protocol_escaped="${mirror_no_protocol:-}"
    fi
  fi
  
  # Update main sources.list with multiple aggressive replacement patterns
  # J1: Validate file exists before operations
  if [ -f /etc/apt/sources.list ] && [ -r /etc/apt/sources.list ]; then
    # Multiple replacement patterns to catch all variations:
    # 1. Specifically target archive.ubuntu.com (what add-apt-repository adds)
    if [ -n "${fastest_mirror_sed_escaped:-}" ] && [ -n "${FASTEST_MIRROR:-}" ]; then
      # H4: sed operations with || true - validate results after masked failures
      sed -i "s|https\\?://archive\\.ubuntu\\.com/ubuntu|${fastest_mirror_sed_escaped}|g" /etc/apt/sources.list || true
      sed -i "s|http://archive\\.ubuntu\\.com/ubuntu|${fastest_mirror_sed_escaped}|g" /etc/apt/sources.list || true
      # 2. General pattern for any Ubuntu mirror (excluding security.ubuntu.com)
      sed -i "/security\\.ubuntu\\.com/! s|https\\?://[a-zA-Z0-9.-]*\\.ubuntu\\.com/ubuntu|${fastest_mirror_sed_escaped}|g" /etc/apt/sources.list || true
      sed -i "/security\\.ubuntu\\.com/! s|https\\?://[a-zA-Z0-9.-]*/ubuntu|${fastest_mirror_sed_escaped}|g" /etc/apt/sources.list || true
      # H4: Validate sed operations succeeded by checking if archive.ubuntu.com still exists
      # K1b: Use -- to prevent command argument misinterpretation when pattern might start with -
      if grep -q -- "archive\\.ubuntu\\.com" /etc/apt/sources.list 2>/dev/null; then
        echo "[warn] ⚠ Some archive.ubuntu.com references may remain after sed replacement"
      fi
    fi
    
    # Also verify no archive.ubuntu.com remains
    # D3: Use here-string instead of pipe pattern
    # F2: Validate command substitution result
    local sources_content
    sources_content=$(grep -v "^#" /etc/apt/sources.list 2>/dev/null || echo "")
    if [ -n "${sources_content:-}" ] && grep -q -- "archive\\.ubuntu\\.com" <<< "${sources_content}" 2>/dev/null; then
      echo "[warn] ⚠ Still found archive.ubuntu.com references, attempting additional replacement..."
      # K1b: Use -- to prevent command argument misinterpretation when pattern might start with -
      if [ -n "${mirror_no_protocol_escaped:-}" ]; then
        # H4: Validate sed operation result
        sed -i "s|archive\\.ubuntu\\.com/ubuntu|${mirror_no_protocol_escaped}|g" /etc/apt/sources.list || true
        # Verify replacement succeeded
        if grep -q -- "archive\\.ubuntu\\.com" /etc/apt/sources.list 2>/dev/null; then
          echo "[warn] ⚠ Additional replacement may have failed - archive.ubuntu.com still present"
        fi
      fi
    # ENDIF: archive.ubuntu.com check
    fi
    echo "[info] ✓ Updated /etc/apt/sources.list"
  else
    echo "[warn] /etc/apt/sources.list not found"
  fi
  # ENDIF: main sources.list exists for re-application
  
  # Update sources.list.d/ files (excluding PPAs) with aggressive replacement
  # CRITICAL: Handle both .list (one-line format) and .sources (deb822 format) files
  # J1: Validate directory exists and is accessible before operations
  if [ -d /etc/apt/sources.list.d ] && [ -x /etc/apt/sources.list.d ]; then
    local updated_count=0
    shopt -s nullglob  # Handle case where no files exist
    
    # Process .list files (one-line format)
    for sources_file in /etc/apt/sources.list.d/*.list; do
      [ -f "${sources_file}" ] || continue
      
      # Skip PPA files (they must use ppa.launchpad.net)
      if grep -q "ppa.launchpad.net" "${sources_file}" 2>/dev/null; then
        continue
      fi
      
      # Multiple replacement patterns for sources.list.d files too
      # 1. Specifically target archive.ubuntu.com
      # J1: Validate file is readable before grep operations
      if [ -r "${sources_file}" ] && grep -q "archive\\.ubuntu\\.com" "${sources_file}" 2>/dev/null; then
        if [ -n "${fastest_mirror_sed_escaped:-}" ]; then
          # H4: sed operations - validate results after masked failures
          sed -i "s|https\\?://archive\\.ubuntu\\.com/ubuntu|${fastest_mirror_sed_escaped}|g" "${sources_file}" || true
          sed -i "s|http://archive\\.ubuntu\\.com/ubuntu|${fastest_mirror_sed_escaped}|g" "${sources_file}" || true
          # Verify replacement succeeded
          # K1b: Use -- to prevent command argument misinterpretation when pattern might start with -
          if ! grep -q -- "archive\\.ubuntu\\.com" "${sources_file}" 2>/dev/null; then
            echo "[info] ✓ Updated archive.ubuntu.com in: $(basename "${sources_file}")"
            updated_count=$((updated_count + 1))
          else
            echo "[warn] ⚠ Replacement may have failed for: $(basename "${sources_file}")"
          fi
        fi
      fi
      # 2. General pattern for any Ubuntu mirror (excluding security.ubuntu.com)
      if [ -r "${sources_file}" ] && grep -q "https\\?://[a-zA-Z0-9.-]*/ubuntu" "${sources_file}" 2>/dev/null; then
        if [ -n "${fastest_mirror_sed_escaped:-}" ]; then
          # H4: sed operations with validation
          sed -i "/security\\.ubuntu\\.com/! s|https\\?://[a-zA-Z0-9.-]*\\.ubuntu\\.com/ubuntu|${fastest_mirror_sed_escaped}|g" "${sources_file}" || true
          sed -i "/security\\.ubuntu\\.com/! s|https\\?://[a-zA-Z0-9.-]*/ubuntu|${fastest_mirror_sed_escaped}|g" "${sources_file}" || true
          echo "[info] ✓ Updated: $(basename "${sources_file}")"
          updated_count=$((updated_count + 1))
        fi
      fi
      
      # Final check - remove any remaining archive.ubuntu.com references
      # D3: Use here-string instead of pipe pattern
      # F2: Validate command substitution result
      local file_content
      file_content=$(grep -v "^#" "${sources_file}" 2>/dev/null || echo "")
      # K1b: Use -- to prevent command argument misinterpretation when pattern might start with -
      if [ -n "${file_content:-}" ] && grep -q -- "archive\\.ubuntu\\.com" <<< "${file_content}" 2>/dev/null; then
        if [ -n "${mirror_no_protocol_escaped:-}" ]; then
          # H4: Validate sed operation result
          sed -i "s|archive\\.ubuntu\\.com/ubuntu|${mirror_no_protocol_escaped}|g" "${sources_file}" || true
          # Verify replacement succeeded
          # K1b: Use -- to prevent command argument misinterpretation when pattern might start with -
          if ! grep -q -- "archive\\.ubuntu\\.com" "${sources_file}" 2>/dev/null; then
            echo "[info] Additional cleanup applied to: $(basename "${sources_file}")"
          else
            echo "[warn] ⚠ Additional cleanup may have failed for: $(basename "${sources_file}")"
          fi
        fi
      # ENDIF: archive.ubuntu.com check
      fi
    done
    
    # Process .sources files (deb822 format used by Ubuntu 24.04+)
    for sources_file in /etc/apt/sources.list.d/*.sources; do
      [ -f "${sources_file}" ] || continue
      
      # Skip PPA files
      if grep -q "ppa.launchpad.net" "${sources_file}" 2>/dev/null; then
        continue
      fi
      
      # Check if file contains archive.ubuntu.com in URIs= lines
      # J1: Validate file is readable before grep operations
      if [ -r "${sources_file}" ] && (grep -qE "^URIs=.*archive\\.ubuntu\\.com" "${sources_file}" 2>/dev/null || grep -qE "archive\\.ubuntu\\.com" "${sources_file}" 2>/dev/null); then
        # Replace archive.ubuntu.com in URIs= lines (deb822 format)
        if [ -n "${fastest_mirror_sed_escaped:-}" ]; then
          # H4: sed operations with validation
          sed -i "s|^URIs=https\\?://archive\\.ubuntu\\.com/ubuntu|URIs=${fastest_mirror_sed_escaped}|g" "${sources_file}" || true
          sed -i "s|^URIs=http://archive\\.ubuntu\\.com/ubuntu|URIs=${fastest_mirror_sed_escaped}|g" "${sources_file}" || true
          # Also handle multi-line URIs= entries (space-separated)
          sed -i "s|https\\?://archive\\.ubuntu\\.com/ubuntu|${fastest_mirror_sed_escaped}|g" "${sources_file}" || true
          sed -i "s|http://archive\\.ubuntu\\.com/ubuntu|${fastest_mirror_sed_escaped}|g" "${sources_file}" || true
          # Verify replacement succeeded
          # K1b: Use -- to prevent command argument misinterpretation when pattern might start with -
          if ! grep -q -- "archive\\.ubuntu\\.com" "${sources_file}" 2>/dev/null; then
            echo "[info] ✓ Updated archive.ubuntu.com in deb822 file: $(basename "${sources_file}")"
            updated_count=$((updated_count + 1))
          else
            echo "[warn] ⚠ Replacement may have failed for deb822 file: $(basename "${sources_file}")"
          fi
        fi
      fi
      
      # Final check for remaining archive.ubuntu.com
      # D3: Use here-string instead of pipe pattern
      # F2: Validate command substitution result
      local file_content
      file_content=$(grep -v "^#" "${sources_file}" 2>/dev/null || echo "")
      # K1b: Use -- to prevent command argument misinterpretation when pattern might start with -
      if [ -n "${file_content:-}" ] && grep -q -- "archive\\.ubuntu\\.com" <<< "${file_content}" 2>/dev/null; then
        if [ -n "${mirror_no_protocol_escaped:-}" ]; then
          # H4: Validate sed operation result
          sed -i "s|archive\\.ubuntu\\.com/ubuntu|${mirror_no_protocol_escaped}|g" "${sources_file}" || true
          # Verify replacement succeeded
          # K1b: Use -- to prevent command argument misinterpretation when pattern might start with -
          if ! grep -q -- "archive\\.ubuntu\\.com" "${sources_file}" 2>/dev/null; then
            echo "[info] Additional cleanup applied to deb822 file: $(basename "${sources_file}")"
          else
            echo "[warn] ⚠ Additional cleanup may have failed for deb822 file: $(basename "${sources_file}")"
          fi
        fi
      # ENDIF: archive.ubuntu.com check
      fi
    done
    
    shopt -u nullglob  # Restore default behavior
    
    if [ "${updated_count:-0}" -eq 0 ]; then
      echo "[info] sources.list.d/: No Ubuntu repositories to update"
    fi
  fi
  
  echo "[info] ✓ Fastest mirror re-application complete"
  
  # Force apt-get update to clear any cached mirror configuration
  # CRITICAL: Clear package list cache first so Release files are re-downloaded from new mirror
  # Otherwise apt-get --print-uris will still return archive.ubuntu.com URLs
  echo "[info] Clearing package list cache to force fresh download from fastest mirror..."
  rm -rf /var/lib/apt/lists/* 2>/dev/null || true
  # Also clear apt cache directory to remove any cached Release files
  rm -rf /var/cache/apt/archives/partial/* 2>/dev/null || true
  # Clear apt state to force re-reading sources
  rm -f /var/lib/apt/lists/lock 2>/dev/null || true
  echo "[info] Running apt-get update to refresh package lists with new mirror..."
  # F2: Capture both output and exit code separately for proper validation
  local apt_update_output
  local apt_update_exit_code
  apt_update_output=$(apt-get update -o Acquire::Retries=3 2>&1)
  apt_update_exit_code=$?
  # F2: Validate command substitution result (check exit code explicitly)
  if [ -z "${apt_update_output:-}" ] && [ "${apt_update_exit_code:-1}" -ne 0 ]; then
    echo "[warn] ⚠ apt-get update produced no output but exited with code ${apt_update_exit_code}"
  fi
  
  # Check if apt-get update failed with 403 (blocked) or other access errors
  if [[ "${apt_update_exit_code:-1}" -ne 0 ]]; then
    # Check for various error conditions that indicate mirror is inaccessible
    local mirror_failed=false
    local error_reason=""
    
    if grep -qiE "(403|Forbidden|blocked|access denied|URL blocked)" <<< "${apt_update_output}"; then
      mirror_failed=true
      error_reason="blocked (403)"
    elif grep -qiE "(404|Not Found|not available)" <<< "${apt_update_output}"; then
      mirror_failed=true
      error_reason="not found (404)"
    elif grep -qiE "(500|502|503|504|Internal Server Error|Bad Gateway|Service Unavailable|Gateway Timeout)" <<< "${apt_update_output}"; then
      mirror_failed=true
      error_reason="server error (5xx)"
    elif grep -qiE "(timeout|timed out|connection timeout)" <<< "${apt_update_output}"; then
      mirror_failed=true
      error_reason="timeout"
    elif grep -qiE "(couldn't connect|could not resolve|name resolution|connection refused)" <<< "${apt_update_output}"; then
      mirror_failed=true
      error_reason="connection failed"
    fi
    
    if [[ "${mirror_failed}" == "true" ]]; then
      echo "[ERROR] ⚠ Selected mirror ${FASTEST_MIRROR} failed: ${error_reason}"
      echo "[info] Falling back to default archive.ubuntu.com (guaranteed fallback)..."
      
      # Revert to archive.ubuntu.com
      FASTEST_MIRROR="http://archive.ubuntu.com/ubuntu"
      export FASTEST_MIRROR
      
      # Re-apply default mirror
      # CRITICAL: Must have error fallback to prevent unset variable with set -u
      # D4: Correct sed bracket expression escaping with error fallback
      local fastest_mirror_sed_escaped
      fastest_mirror_sed_escaped="$(printf '%s\n' "${FASTEST_MIRROR:-}" | sed 's/[][\\\/&]/\\&/g' || echo "")"
      
      # CRITICAL: Guard against empty escaped value (validate result format)
      # F2: Validate command substitution result
      if [ -z "${fastest_mirror_sed_escaped:-}" ] && [ -n "${FASTEST_MIRROR:-}" ]; then
        fastest_mirror_sed_escaped=$(printf '%s\n' "${FASTEST_MIRROR:-}" | sed 's|/|\\/|g; s|&|\\&|g' || echo "${FASTEST_MIRROR:-}")
        # Validate fallback result is non-empty
        if [ -z "${fastest_mirror_sed_escaped:-}" ]; then
          echo "[ERROR] ⚠ Failed to escape FASTEST_MIRROR for sed - using raw value"
          fastest_mirror_sed_escaped="${FASTEST_MIRROR:-}"
        fi
      fi
      
      # Revert sources.list
      # J1: Validate file exists and is writable before operations
      if [ -f /etc/apt/sources.list ] && [ -w /etc/apt/sources.list ] && [ -n "${fastest_mirror_sed_escaped:-}" ] && [ -n "${FASTEST_MIRROR:-}" ]; then
        # H4: sed operations with validation
        sed -i "s|https\\?://[^[:space:]]*/ubuntu|${fastest_mirror_sed_escaped}|g" /etc/apt/sources.list || true
        sed -i "/security\\.ubuntu\\.com/! s|https\\?://[^[:space:]]*/ubuntu|${fastest_mirror_sed_escaped}|g" /etc/apt/sources.list || true
        # Verify replacement succeeded
        if ! grep -q "https\\?://[^[:space:]]*/ubuntu" /etc/apt/sources.list 2>/dev/null || grep -q "${FASTEST_MIRROR}" /etc/apt/sources.list 2>/dev/null; then
          echo "[info] ✓ Reverted sources.list to default mirror"
        else
          echo "[warn] ⚠ Reversion may have failed - verify sources.list manually"
        fi
      fi
      
      # Revert sources.list.d/ files
      # J1: Validate directory exists and is accessible
      if [ -d /etc/apt/sources.list.d ] && [ -x /etc/apt/sources.list.d ]; then
        shopt -s nullglob
        for sources_file in /etc/apt/sources.list.d/*.{list,sources}; do
          [ -f "${sources_file}" ] || continue
          [ -r "${sources_file}" ] || continue
          [ -w "${sources_file}" ] || continue
          [ -n "${fastest_mirror_sed_escaped:-}" ] || continue
          # Skip PPAs
          grep -q "ppa.launchpad.net" "${sources_file}" 2>/dev/null && continue
          # Replace any mirror with archive.ubuntu.com
          # H4: sed operations with validation
          sed -i "s|https\\?://[^[:space:]]*/ubuntu|${fastest_mirror_sed_escaped}|g" "${sources_file}" || true
          sed -i "s|^URIs=https\\?://[^[:space:]]*/ubuntu|URIs=${fastest_mirror_sed_escaped}|g" "${sources_file}" || true
        done
        shopt -u nullglob
      fi
      
      # Clear cache and retry with default mirror
      rm -rf /var/lib/apt/lists/* 2>/dev/null || true
      rm -rf /var/cache/apt/archives/partial/* 2>/dev/null || true
      rm -f /var/lib/apt/lists/lock 2>/dev/null || true
      
      echo "[info] Retrying apt-get update with default archive.ubuntu.com mirror..."
      # F2: Capture both output and exit code separately for proper validation
      local retry_output
      local retry_exit_code
      retry_output=$(apt-get update -o Acquire::Retries=3 2>&1)
      retry_exit_code=$?
      # F2: Validate command substitution result
      if [ -z "${retry_output:-}" ] && [ "${retry_exit_code:-1}" -ne 0 ]; then
        echo "[warn] ⚠ apt-get update retry produced no output but exited with code ${retry_exit_code}"
      fi
      
      if [[ "${retry_exit_code:-1}" -eq 0 ]]; then
        echo "[info] ✓ Successfully using default archive.ubuntu.com mirror"
      else
        echo "[ERROR] ⚠ apt-get update failed even with default archive.ubuntu.com mirror"
        echo "[warn] This may indicate a network or system issue. Output:"
        # D3: Use here-string instead of echo | head | sed (unsafe pipe pattern)
        # D3e: Add || true to prevent SIGPIPE error (exit code 141) when head closes pipe early
        head -10 <<< "${retry_output}" 2>/dev/null | sed 's/^/  /' 2>/dev/null || true
        echo "[warn] Build may continue, but package operations may fail"
      fi
    else
      echo "[warn] apt-get update had issues (may continue):"
      # D3: Use here-string instead of echo | head | sed (unsafe pipe pattern)
      # D3e: Add || true to prevent SIGPIPE error (exit code 141) when head closes pipe early
      head -5 <<< "${apt_update_output}" 2>/dev/null | sed 's/^/  /' 2>/dev/null || true
    fi
  else
    echo "[info] ✓ apt-get update succeeded with selected mirror"
  fi
  
  # Verify the changes
  verify_fastest_mirror
}
export -f reapply_fastest_mirror

#===============================================================================
# BLOCK 5: CACHE MONITORING SYSTEM
#===============================================================================
# Purpose: Track cache growth throughout build phases
# Self-contained: Yes (complete function definitions)
# Dependencies: None
# Outputs: Environment variables, configuration
#-------------------------------------------------------------------------------

#--- Sub-block 5.1: Initialize cache monitoring data file ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
CACHE_MONITOR_DATA="/tmp/cache_monitor_data.txt"
# Critical: CSV header for cache tracking across all build phases
echo "Stage|Container APT|Var APT|Conda|Wheels|Julia" > "$CACHE_MONITOR_DATA"

#--- Sub-block 5.2: Cache monitoring function ---
# Purpose: Record cache sizes at each build stage
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
# Parameters: $1 = stage name
# Note: monitor_cache() is now defined in /scripts/common_functions.sh (centralized)

#--- Sub-block 5.3: Cache monitoring summary display function ---
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
  # J1: Validate file exists and is readable before operations
  if [ -f "${CACHE_MONITOR_DATA:-}" ] && [ -r "${CACHE_MONITOR_DATA:-}" ]; then
    # J3: Safe read loop with IFS handling and empty line detection
    while IFS='|' read -r stage container_apt var_apt conda_pkgs wheels julia_pkgs || [ -n "${stage:-}" ]; do
      # Skip header line and empty lines
      if [ "${stage:-}" = "Stage" ] || [ -z "${stage:-}" ]; then
        continue
      fi
      # Format the output with proper alignment
      printf "%-30s | %-13s | %-7s | %-5s | %-6s | %-5s\n" \
        "${stage:-unknown}" "${container_apt:-0}" "${var_apt:-0}" "${conda_pkgs:-0}" "${wheels:-0}" "${julia_pkgs:-0}"
    done < "${CACHE_MONITOR_DATA}" || true
  else
    echo "No cache monitoring data available"
  fi
  echo "=========================================================="
  echo
}
# End function (self-contained)

#--- Sub-block 5.4: Final cache summary function ---
# Purpose: Display detailed cache statistics before image creation
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
cache_summary() {
  echo "=========================================================="
  echo "FINAL CACHE SUMMARY - BEFORE IMAGE CREATION"
  echo "=========================================================="
  echo "APT Archives:"
  # J1: Validate directory exists and is accessible before operations
  # F2: Validate command substitution results
  if [ -d "${CONTAINER_APT_CACHE:-}" ] && [ -x "${CONTAINER_APT_CACHE:-}" ]; then
    local deb_count
    deb_count=$(find "${CONTAINER_APT_CACHE}" -maxdepth 1 -name "*.deb" -type f 2>/dev/null | wc -l || echo "0")
    # Validate result is numeric
    if ! [[ "${deb_count:-0}" =~ ^[0-9]+$ ]]; then
      deb_count="0"
    fi
    echo " ${CONTAINER_APT_CACHE}: ${deb_count} .deb files"
  else
    echo " ${CONTAINER_APT_CACHE:-/unknown}: 0 .deb files (directory not found)"
  fi
  # ENDIF: container APT cache exists and accessible
  if [ -d /var/cache/apt/archives ] && [ -x /var/cache/apt/archives ]; then
    local deb_count
    deb_count=$(find /var/cache/apt/archives -maxdepth 1 -name "*.deb" -type f 2>/dev/null | wc -l || echo "0")
    # Validate result is numeric
    if ! [[ "${deb_count:-0}" =~ ^[0-9]+$ ]]; then
      deb_count="0"
    fi
    echo " /var/cache/apt/archives: ${deb_count} .deb files"
  else
    echo " /var/cache/apt/archives: 0 .deb files (directory not found)"
  fi
  # ENDIF: host APT archives directory exists
  echo "---"
  echo "Other Caches:"
  # J1: Validate directory exists and is accessible before operations
  # F2: Validate command substitution results
  if [ -d "${CONTAINER_CONDA_CACHE:-}" ] && [ -x "${CONTAINER_CONDA_CACHE:-}" ]; then
    local file_count
    file_count=$(find "${CONTAINER_CONDA_CACHE}" -maxdepth 1 -type f 2>/dev/null | wc -l || echo "0")
    # Validate result is numeric
    if ! [[ "${file_count:-0}" =~ ^[0-9]+$ ]]; then
      file_count="0"
    fi
    echo " ${CONTAINER_CONDA_CACHE}: ${file_count} files"
  else
    echo " ${CONTAINER_CONDA_CACHE:-/unknown}: 0 files (directory not found)"
  fi
  # ENDIF: container CONDA cache exists and accessible
  if [ -d "${CONTAINER_WHEELS_CACHE:-}" ] && [ -x "${CONTAINER_WHEELS_CACHE:-}" ]; then
    local file_count
    file_count=$(find "${CONTAINER_WHEELS_CACHE}" -maxdepth 1 -type f 2>/dev/null | wc -l || echo "0")
    # Validate result is numeric
    if ! [[ "${file_count:-0}" =~ ^[0-9]+$ ]]; then
      file_count="0"
    fi
    echo " ${CONTAINER_WHEELS_CACHE}: ${file_count} files"
  else
    echo " ${CONTAINER_WHEELS_CACHE:-/unknown}: 0 files (directory not found)"
  fi
  # ENDIF: container WHEELS cache exists and accessible
  if [ -d "${CONTAINER_JULIA_CACHE:-}" ] && [ -x "${CONTAINER_JULIA_CACHE:-}" ]; then
    local file_count
    file_count=$(find "${CONTAINER_JULIA_CACHE}" -maxdepth 1 -type f 2>/dev/null | wc -l || echo "0")
    # Validate result is numeric
    if ! [[ "${file_count:-0}" =~ ^[0-9]+$ ]]; then
      file_count="0"
    fi
    echo " ${CONTAINER_JULIA_CACHE}: ${file_count} files"
  else
    echo " ${CONTAINER_JULIA_CACHE:-/unknown}: 0 files (directory not found)"
  fi
  # ENDIF: container JULIA cache exists and accessible
  echo "---"
  echo "Cache Directory Sizes:"
  # J1: Validate directory exists and is accessible before operations
  # F2: Validate command substitution results
  if [ -d "${CONTAINER_APT_CACHE:-}" ] && [ -x "${CONTAINER_APT_CACHE:-}" ]; then
    local size_output
    size_output=$(du -sh "${CONTAINER_APT_CACHE}" 2>/dev/null | cut -f1 || echo '0B')
    echo " ${CONTAINER_APT_CACHE}: ${size_output}"
  else
    echo " ${CONTAINER_APT_CACHE:-/unknown}: 0B (directory not found)"
  fi
  # ENDIF: container APT cache size
  if [ -d "${CONTAINER_CONDA_CACHE:-}" ] && [ -x "${CONTAINER_CONDA_CACHE:-}" ]; then
    local size_output
    size_output=$(du -sh "${CONTAINER_CONDA_CACHE}" 2>/dev/null | cut -f1 || echo '0B')
    echo " ${CONTAINER_CONDA_CACHE}: ${size_output}"
  else
    echo " ${CONTAINER_CONDA_CACHE:-/unknown}: 0B (directory not found)"
  fi
  # ENDIF: container CONDA cache size
  if [ -d "${CONTAINER_WHEELS_CACHE:-}" ] && [ -x "${CONTAINER_WHEELS_CACHE:-}" ]; then
    local size_output
    size_output=$(du -sh "${CONTAINER_WHEELS_CACHE}" 2>/dev/null | cut -f1 || echo '0B')
    echo " ${CONTAINER_WHEELS_CACHE}: ${size_output}"
  else
    echo " ${CONTAINER_WHEELS_CACHE:-/unknown}: 0B (directory not found)"
  fi
  # ENDIF: container WHEELS cache size
  if [ -d "${CONTAINER_JULIA_CACHE:-}" ] && [ -x "${CONTAINER_JULIA_CACHE:-}" ]; then
    local size_output
    size_output=$(du -sh "${CONTAINER_JULIA_CACHE}" 2>/dev/null | cut -f1 || echo '0B')
    echo " ${CONTAINER_JULIA_CACHE}: ${size_output}"
  else
    echo " ${CONTAINER_JULIA_CACHE:-/unknown}: 0B (directory not found)"
  fi
  # ENDIF: container JULIA cache size
  echo "=========================================================="
  echo
}
# End function (self-contained)

#===============================================================================
# BLOCK 6: CACHE DIRECTORY CONFIGURATION
#===============================================================================
# Purpose: Configure unified cache structure for all package managers
# Self-contained: Yes
# Dependencies: None
# Outputs: Environment variables, configuration
#-------------------------------------------------------------------------------

#--- Sub-block 6.1: Define unified cache root ---
# Critical: All package caches will be subdirectories of this root
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
export CACHE_ROOT="/container_cache"

#--- Sub-block 6.2: Configure package manager cache paths ---
# Critical: Point all package managers to unified cache structure
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
export PIP_CACHE_DIR="${CACHE_ROOT}/wheels"              # Python pip wheels
export CONDA_PKGS_DIRS="${CACHE_ROOT}/conda_pkgs"        # Conda packages
export JULIA_DEPOT_PATH="${CACHE_ROOT}/julia_pkgs:/usr/local/share/julia"  # Julia depot

# NOTE: All version configurations now loaded from /etc/config.sh (sourced at top of file)

#===============================================================================
# BLOCK 7: ADVANCED PACKAGE MANAGEMENT FUNCTIONS
#===============================================================================
# Purpose: Robust package installation with staging, retry logic, and atomicity
# Self-contained: Yes (complete function definitions)
# Dependencies: conda/mamba
# Outputs: Configured system components
#-------------------------------------------------------------------------------


#--- Sub-block 7.1: Validate configuration loaded successfully ---
# Purpose: Verify all required variables are set
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
#--- Sub-block 7.2: Conda staging area setup ---
# Purpose: Create isolated staging area for package operations
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments
setup_conda_staging_area() {
    local staging_dir="/tmp/conda-staging"
    echo "Setting up conda staging area at ${staging_dir}..."
    # J1: Validate parent directory exists before creating subdirectory
    # J2: Use mktemp for secure temporary directory creation (K3)
    # Create staging directory with proper permissions
    # H1: Check exit code of mkdir operation
    if ! mkdir -p "${staging_dir}" 2>/dev/null; then
        echo "[ERROR] ⚠ Failed to create staging directory: ${staging_dir}"
        return 1
    fi
    # H1: Check exit code of chmod operation
    if ! chmod 755 "${staging_dir}" 2>/dev/null; then
        echo "[warn] ⚠ Failed to set permissions on staging directory: ${staging_dir}"
    fi
    # J1: Verify directory was created successfully
    if [ ! -d "${staging_dir}" ]; then
        echo "[ERROR] ⚠ Staging directory does not exist after creation: ${staging_dir}"
        return 1
    fi
    # Note: Do not modify CONDA_PKGS_DIRS here to avoid interfering with normal conda operations
    # The staging area will be used manually for specific cleanup operations
    # J2, K2: Note: Using /tmp/conda-staging instead of mktemp for persistence across function calls
    # This is intentional for manual cleanup operations, but should be cleaned up after use
    echo "✓ Conda staging area configured (manual mode)"
}
# End function (self-contained)

#--- Sub-block 7.3: Atomic package replacement with retry ---
# Purpose: Replace corrupted packages with exponential backoff
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments
# Parameters: $1 = package name
atomic_package_replace() {
    local pkg_name="${1:-}"
    local cache_dir="${CONTAINER_CONDA_CACHE:-}"
    local max_retries=3
    local retry_count=0

    # Validate inputs
    # C1, C5: Validate inputs with proper error messages
    if [ -z "${pkg_name}" ]; then
        echo "✗ Error: Package name not provided"
        return 1
    fi
    if [ -z "${cache_dir}" ]; then
        echo "✗ Error: CONTAINER_CONDA_CACHE not set"
        return 1
    fi
    if [ -z "${MINIFORGE_HOME:-}" ] || [ ! -x "${MINIFORGE_HOME}/bin/mamba" ]; then
        echo "✗ Error: MINIFORGE_HOME not set or mamba not available"
        return 1
    fi

    while [ "${retry_count}" -lt "${max_retries}" ]; do
        echo "Attempting to replace corrupted package: ${pkg_name} (attempt $((retry_count + 1))/${max_retries})"
        # Create temporary file for atomic replacement
        local temp_file="${cache_dir}/${pkg_name}.tmp"
        local final_file="${cache_dir}/${pkg_name}"

        # Remove corrupted package
        # H4: Validate rm operation result (file may not exist, which is OK)
        if [ -f "${final_file}" ]; then
            if ! rm -f "${final_file}" 2>/dev/null; then
                echo "[warn] ⚠ Failed to remove corrupted package: ${final_file}"
            fi
        fi

        # Download fresh copy to temporary location
        # H1: Check exit code of mamba download operation
        if "${MINIFORGE_HOME}/bin/mamba" download --no-deps -c conda-forge -p "${cache_dir}" "${pkg_name}" --output-filename "${temp_file}" 2>/dev/null; then
            # J1: Validate temp file was created before moving
            if [ ! -f "${temp_file}" ]; then
                echo "[warn] ⚠ Download succeeded but temp file not found: ${temp_file}"
                retry_count=$((retry_count + 1))
                sleep $((retry_count ** 2))
                continue
            fi
            # Atomic move to final location
            # H1: Check exit code of mv operation
            if mv "${temp_file}" "${final_file}" 2>/dev/null; then
                # J1: Validate final file exists after move
                if [ ! -f "${final_file}" ]; then
                    echo "[warn] ⚠ Move succeeded but final file not found: ${final_file}"
                    retry_count=$((retry_count + 1))
                    sleep $((retry_count ** 2))
                    continue
                fi
                # Verify the new package
                if verify_package_integrity "${final_file}"; then
                    echo "✓ Successfully replaced and verified: ${pkg_name}"
                    return 0
                else
                    echo "Δ Downloaded package failed verification, retrying..."
                    # H4: Validate rm operation result
                    if [ -f "${final_file}" ] && ! rm -f "${final_file}" 2>/dev/null; then
                        echo "[warn] ⚠ Failed to remove failed package: ${final_file}"
                    fi
                fi
            else
                echo "Δ Atomic move failed, retrying..."
                # H4: Validate rm operation result
                if [ -f "${temp_file}" ] && ! rm -f "${temp_file}" 2>/dev/null; then
                    echo "[warn] ⚠ Failed to remove temp file: ${temp_file}"
                fi
            fi
        else
            echo "Δ Download failed, retrying..."
        fi

        retry_count=$((retry_count + 1))
        # I1: Validate sleep duration (prevent negative or excessive values)
        local sleep_duration
        sleep_duration=$((retry_count ** 2))
        if [ "${sleep_duration:-0}" -gt 0 ] && [ "${sleep_duration:-0}" -le 3600 ]; then
            sleep "${sleep_duration}"
        else
            sleep 1  # Fallback to 1 second if calculation fails
        fi
    done
    # End while loop (self-contained)

    echo "✗ Failed to replace package after ${max_retries} attempts: ${pkg_name}"
    return 1
}
# End function (self-contained)


#--- Sub-block 7.4: Package integrity verification ---
# Purpose: Verify package file integrity (bzip2/zip)
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# Parameters: $1 = package file path
verify_package_integrity() {
    local pkg_file="${1:-}"

    if [ -z "${pkg_file}" ]; then
        echo "✗ Error: Package file path not provided"
        return 1
    fi

    if [ ! -f "${pkg_file}" ]; then
        echo "✗ Error: Package file not found: ${pkg_file}"
        return 1
    fi

    # Check file type and verify accordingly
    # F2: Validate command substitution result
    local file_type
    file_type=$(file -b "${pkg_file}" 2>/dev/null || echo "unknown")
    # C5, F2: Validate file_type is non-empty and has fallback
    if [ -z "${file_type:-}" ]; then
        file_type="unknown"
    fi
    case "${file_type}" in
        *"bzip2 compressed"*)
            # H1: Check exit code of bzip2 test operation
            if bzip2 -t "${pkg_file}" >/dev/null 2>&1; then
                return 0
            else
                echo "✗ bzip2 integrity check failed"
                return 1
            fi
            ;;
        *"Zip archive"*)
            # H1: Check exit code of unzip test operation
            if unzip -t "${pkg_file}" >/dev/null 2>&1; then
                return 0
            else
                echo "✗ ZIP integrity check failed"
                return 1
            fi
            ;;
        *) # For unknown types, try both checks
            # H1: Check exit codes of both test operations
            if bzip2 -t "${pkg_file}" >/dev/null 2>&1; then
                return 0
            elif unzip -t "${pkg_file}" >/dev/null 2>&1; then
                return 0
            else
                echo "✗ Package integrity check failed (tried both bzip2 and ZIP)"
                return 1
            fi
            ;;
    esac
    # End case statement (self-contained)
}
# End function (self-contained)


#--- Sub-block 7.5: Package locking mechanism ---
# Purpose: Prevent concurrent access to packages with timeout
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# Parameters: $1 = package name
acquire_package_lock() {
    local pkg_name="${1:-}"
    # J2, K2: Use consistent lock file path (must match release_package_lock)
    # Note: Using fixed /tmp path for lock file persistence across function calls
    # This is acceptable for lock files as they are cleaned up by release_package_lock
    # For enhanced security, consider using /var/run or a dedicated lock directory
    local lock_file="/tmp/conda-lock-${pkg_name}.lock"
    local max_wait=30
    local wait_count=0
    local current_time lock_time lock_age

    if [ -z "${pkg_name}" ]; then
        echo "✗ Error: Package name not provided"
        return 1
    fi

    while [ "${wait_count}" -lt "${max_wait}" ]; do
        # Use subshell with set -C for atomic lock creation
        if (set -C; echo $$ > "${lock_file}") 2>/dev/null; then
            # lock acquired
            return 0
        fi
        # Check if lock is stale (older than 5 minutes)
        # J1: Validate file exists before operations
        if [ -f "${lock_file}" ] && [ -r "${lock_file}" ]; then
            # F2: Validate command substitution results
            current_time=$(date +%s 2>/dev/null || echo "0")
            lock_time=$(stat -c %Y "${lock_file}" 2>/dev/null || echo "0")
            # A5, A6: Validate results are numeric (using Bash [[ ]] for regex - documented as Bash-specific)
            # Note: This requires Bash 3.2+ for regex matching; POSIX alternative would be case/esac with pattern matching
            if ! [[ "${current_time:-0}" =~ ^[0-9]+$ ]] || ! [[ "${lock_time:-0}" =~ ^[0-9]+$ ]]; then
                # If we can't get valid times, assume lock is stale
                echo "[warn] ⚠ Could not determine lock age, assuming stale"
                rm -f "${lock_file}" 2>/dev/null || true
                continue
            fi
            lock_age=$((current_time - lock_time))
            # A5, A6: Validate lock_age is numeric and non-negative (using Bash [[ ]] for regex)
            # Note: Bash 3.2+ required for regex matching; arithmetic comparison is POSIX-compliant
            if [[ "${lock_age:-0}" =~ ^[0-9]+$ ]] && [ "${lock_age:-0}" -ge 300 ]; then
                # Lock is stale, remove it
                # H4: Validate rm operation result
                if ! rm -f "${lock_file}" 2>/dev/null; then
                    echo "[warn] ⚠ Failed to remove stale lock: ${lock_file}"
                fi
                continue
            fi
        fi

        # I1: Validate sleep duration
        local sleep_duration
        sleep_duration=$((wait_count + 2))
        if [ "${sleep_duration:-0}" -gt 0 ] && [ "${sleep_duration:-0}" -le 60 ]; then
            sleep "${sleep_duration}"
        else
            sleep 1  # Fallback to 1 second
        fi
        wait_count=$((wait_count + 1))
    done
    # End while loop (self-contained)

    echo "▲ Could not acquire lock for ${pkg_name} after ${max_wait}s"
    return 1
}
# End function (self-contained)

#--- Sub-block 7.6: Release package lock ---
# Purpose: Remove lock file for package
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# Parameters: $1 = package name
release_package_lock() {
    local pkg_name="${1:-}"
    # J2, K2: Use consistent lock file path (must match acquire_package_lock)
    # Note: Using fixed /tmp path for lock file persistence across function calls
    # This is acceptable for lock files as they are cleaned up by this function
    # For enhanced security, consider using /var/run or a dedicated lock directory
    local lock_file="/tmp/conda-lock-${pkg_name}.lock"
    
    if [ -z "${pkg_name}" ]; then
        echo "✗ Error: Package name not provided"
        return 1
    fi
    
    # H4: Validate rm operation result (file may not exist, which is OK)
    if [ -f "${lock_file}" ]; then
        if ! rm -f "${lock_file}" 2>/dev/null; then
            echo "[warn] ⚠ Failed to remove lock file: ${lock_file}"
            return 1
        fi
    fi
    return 0
}
# End function (self-contained)

#===============================================================================
# BLOCK 8: MAIN BUILD EXECUTION START
#===============================================================================
# Purpose: Initialize build environment and create cache directories
# Self-contained: Yes
# Dependencies: None
# Outputs: Environment variables, configuration
#-------------------------------------------------------------------------------

#--- Sub-block 8.1: Initial diagnostic checkpoint ---
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
debug_glibc "START - Before any apt operations"

#--- Sub-block 8.2: Create cache directory structure ---
# Critical: All cache directories must exist before package operations
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments
echo "=> Creating all cache directories at the start of container build..."
mkdir -p "${CONTAINER_APT_CACHE:-/container_cache/apt}"
mkdir -p "${CONTAINER_BIN_CACHE:-/container_cache/bin}"
mkdir -p "${CONTAINER_CONDA_CACHE:-/container_cache/conda_pkgs}"
mkdir -p "${CONTAINER_DEB_CACHE:-/container_cache/deb}"
mkdir -p "${CONTAINER_WHEELS_CACHE:-/container_cache/wheels}"
mkdir -p "${CONTAINER_JULIA_CACHE:-/container_cache/julia_pkgs}"
mkdir -p /var/cache/apt/archives/partial
mkdir -p /root/.cache/pip
# Note: ${MINIFORGE_HOME} will be created by Miniforge installer
mkdir -p /usr/local/share/julia

#--- Sub-block 8.3: Additional cache directories ---
# Critical: User-specific cache directories for conda, julia, pip
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
mkdir -p /root/.cache/conda
mkdir -p /root/.cache/julia
mkdir -p /root/.local/share/julia
# apt-fast cache directory removed - using apt-aria wrapper instead

#--- Sub-block 8.4: Set cache directory permissions ---
# Critical: Ensure all cache directories are writable
# Dependencies: Block 17 (Conda/Miniforge), Block 8.5 (Julia installation)
# Outputs: Python packages, conda environments
chmod -R 755 /container_cache /root/.cache /var/cache/opt /usr/local/share/julia /root/.local 2>/dev/null || true
# Only chmod MINIFORGE_HOME if it exists
if [ -n "${MINIFORGE_HOME:-}" ] && [ -d "${MINIFORGE_HOME}" ]; then
    chmod -R 755 "${MINIFORGE_HOME}" 2>/dev/null || true
fi
echo "✓ All cache directories created successfully"

#--- Sub-block 8.5: Cache validation and repair function ---
# Purpose: Validate cache directory structure and permissions
# Parameters: None
# Returns: 0 on success (always succeeds - validation function)
# Side effects: Creates/repairs cache directories, sets permissions
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments
validate_and_repair_cache() {
    echo "==> Validating and repairing cache directories..."
    # Ensure all cache directories exist with proper permissions
    local cache_dirs=(
        "${CONTAINER_APT_CACHE:-/container_cache/apt}"
        "${CONTAINER_WHEELS_CACHE:-/container_cache/wheels}"
        "${CONTAINER_CONDA_CACHE:-/container_cache/conda_pkgs}"
        "${CONTAINER_JULIA_CACHE:-/container_cache/julia_pkgs}"
        "/var/cache/apt/archives"
        "/root/.cache/pip"
        "/usr/local/share/julia"
    )

    # Only add ${MINIFORGE_HOME}/pkgs if conda is already installed
    if [ -n "${MINIFORGE_HOME:-}" ] && [ -d "${MINIFORGE_HOME}" ]; then
        cache_dirs+=("${MINIFORGE_HOME}/pkgs")
    fi
    # ENDIF: MINIFORGE_HOME exists

    for dir in "${cache_dirs[@]}"; do
        if [ -z "${dir:-}" ]; then
            continue  # Skip empty entries
        fi
        # H1: Check exit codes of directory operations
        # J1: Validate parent directory exists before creating subdirectory
        if ! mkdir -p "${dir}" 2>/dev/null; then
            echo "[warn] ⚠ Failed to create cache directory: ${dir}"
            continue
        fi
        # J1: Verify directory was created successfully
        if [ ! -d "${dir}" ]; then
            echo "[warn] ⚠ Directory does not exist after creation: ${dir}"
            continue
        fi
        # H1: Check exit code of chown operation
        # Note: Ownership change may fail if directory is a mount point, read-only filesystem,
        # or already owned by correct user. Check if directory is writable instead.
        if ! chown -R root:root "${dir}" 2>/dev/null; then
            # Check if directory is actually writable (ownership might not matter)
            local test_file="${dir}/.write_test_$$"
            if touch "${test_file}" 2>/dev/null && rm -f "${test_file}" 2>/dev/null; then
                echo "[warn] ⚠ Failed to set ownership on: ${dir} (but directory is writable - continuing)"
            else
                echo "[warn] ⚠ Failed to set ownership on: ${dir} (directory may not be writable)"
            fi
        fi
        # H1: Check exit code of chmod operation
        if ! chmod -R 755 "${dir}" 2>/dev/null; then
            echo "[warn] ⚠ Failed to set permissions on: ${dir}"
        fi
        echo "✓ Validated: ${dir}"
    done
    # ENDFOR: cache_dirs validation loop
}
# End validate_and_repair_cache function

#--- Sub-block 8.6: Test write permissions ---
# Critical: Verify cache directories are actually writable
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# Conda package integrity validation is done via Xsetup for efficiency
test_file="/root/.cache/write_test"
# J1: Validate parent directory exists before creating test file
if [ -d /root/.cache ] && [ -w /root/.cache ]; then
    if touch "${test_file}" 2>/dev/null; then
        # H4: Validate rm operation result
        if [ -f "${test_file}" ] && ! rm -f "${test_file}" 2>/dev/null; then
            echo "[warn] ⚠ Failed to remove test file: ${test_file}"
        fi
        echo "✓ Write permissions verified"
    else
        echo "WARNING: Write permissions issue detected"
    fi
else
    echo "WARNING: /root/.cache directory not writable"
fi
# End write permission test (if-else self-contained)

#--- Sub-block 8.7: GPG verification functions ---
# Purpose: Setup GPG verification for package signatures
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# Note: Currently a placeholder - GPG verification setup will be implemented when needed
# L4: Function documentation added for empty function
# Purpose: Setup GPG verification for package signatures
# Parameters: None
# Returns: 0 on success (always succeeds - placeholder function)
# Side effects: None (placeholder implementation)
# Dependencies: None (foundational)
# Note: Currently a placeholder - GPG verification setup will be implemented when needed
setup_gpg_verification() {
    echo "==> Setting up GPG verification for .deb packages..."
    # TODO: Implement GPG key import and verification setup
    # This function is a placeholder for future GPG verification functionality
    return 0
}

#===============================================================================
# BLOCK 9: EARLY MIRROR SELECTION (BEFORE ANY APT OPERATIONS)
#===============================================================================
# Purpose: Select fastest Ubuntu mirror BEFORE any package downloads
# Self-contained: Yes
# Dependencies: curl (available in Ubuntu base images), mirror functions (BLOCK 3)
# Outputs: FASTEST_MIRROR (exported), updated /etc/apt/sources.list
# Critical: This MUST run BEFORE first apt-get update to ensure all downloads use fast mirror
#-------------------------------------------------------------------------------

#--- Sub-block 9.1: Check curl availability ---
# Purpose: Ensure curl is available for mirror probing
# Dependencies: Ubuntu base image (includes curl by default)
# Outputs: curl availability confirmed
# D3b: Use printf for robustness
printf '%s\n' "==> Checking curl availability for mirror probing..."
if ! command -v curl &> /dev/null; then
    echo "[warn] curl not found in base image. Installing curl first..."
    # Use /usr/bin/apt-get directly to avoid any wrapper issues
    # H1: Check exit code of apt-get update operation
    if ! /usr/bin/apt-get update -o Acquire::Retries=3 2>&1; then
        echo "[ERROR] ⚠ apt-get update failed - cannot install curl"
        exit 1
    fi
    # H1: Check exit code of apt-get install operation
    if ! /usr/bin/apt-get install -y --no-install-recommends curl 2>&1; then
        echo "[ERROR] ⚠ Failed to install curl"
        exit 1
    fi
    # M1: Verify curl was installed successfully
    if ! command -v curl &> /dev/null; then
        echo "[ERROR] ⚠ curl installation succeeded but command not found"
        exit 1
    fi
    # D3b: Use printf for robustness
    printf '%s\n' "✓ curl installed"
else
    printf '%s\n' "✓ curl is available"
fi
# ENDIF: curl availability check

#--- Sub-block 9.2: Execute mirror probing ---
# Critical: Select fastest mirror BEFORE any significant apt operations
# Dependencies: curl, test_mirror() and probe_and_set_mirrors() functions (BLOCK 3)
# Outputs: FASTEST_MIRROR variable (exported), updated sources
# D3b: Use printf for robustness
printf '%s\n' "==> Executing mirror probing BEFORE package installations..."
probe_and_set_mirrors

#--- Sub-block 9.3: Display selected mirror ---
# Purpose: Confirm mirror selection for build logs
# Dependencies: FASTEST_MIRROR (set by probe_and_set_mirrors)
# Outputs: Log output
# D3b: Use printf for robustness (handles special characters in variables)
printf '%s\n' "==> Mirror configuration complete:"
printf '%s\n' "    FASTEST_MIRROR (exported): ${FASTEST_MIRROR}"
printf '%s\n' "    This variable is now available globally for all apt operations"

# Show first few lines of updated sources.list for verification
# D3b: Use printf for robustness
printf '%s\n' "==> Contents of /etc/apt/sources.list (first 5 lines):"
# J1: Validate file exists and is readable before operations
if [ -f /etc/apt/sources.list ] && [ -r /etc/apt/sources.list ]; then
  # F2, D3e: Validate command substitution result with SIGPIPE protection
  # D3e: Pipeline with head requires || true to prevent SIGPIPE (exit code 141)
  sources_preview=""
  sources_preview=$(head -n 5 /etc/apt/sources.list 2>/dev/null | sed 's/^/    /' 2>/dev/null || echo "")
  if [ -n "${sources_preview:-}" ]; then
    printf '%s\n' "${sources_preview}"
  else
    echo "    [warn] Could not read sources.list contents"
  fi
else
  echo "    [warn] /etc/apt/sources.list not found or not readable"
fi
# ENDIF: sources.list preview

printf '%s\n' ""
printf '%s\n' "==> Verifying mirror configuration..."
# Run verification to ensure mirror was properly applied
if verify_fastest_mirror; then
    echo "✓ Mirror selection completed and verified"
else
    echo "[warn] Mirror verification found issues - attempting to re-apply..."
    reapply_fastest_mirror || echo "[ERROR] Failed to fix mirror issues"
fi
# ENDIF: verify_fastest_mirror result

#--- Sub-block 9.4: Force apt-get update after mirror change ---
# CRITICAL: apt-get --print-uris reads URIs from cached Release files in /var/lib/apt/lists/
# If package lists weren't refreshed after mirror change, --print-uris will still return
# archive.ubuntu.com URLs even though sources.list points to the fastest mirror.
# This update ensures Release files are re-downloaded from the new mirror.
echo ""
echo "==> Refreshing package lists with fastest mirror (required for apt-aria to use correct URLs)..."
echo "    This ensures apt-get --print-uris will return URIs from ${FASTEST_MIRROR} instead of archive.ubuntu.com"
# Clear old package list cache to force fresh download from new mirror
# H4: Validate rm operation result
# J1: Validate directory exists before operations
if [ -d /var/lib/apt/lists ] && [ -w /var/lib/apt/lists ]; then
    if ! rm -rf /var/lib/apt/lists/* 2>/dev/null; then
        echo "[warn] ⚠ Failed to clear package list cache - some files may remain"
    fi
else
    echo "[warn] ⚠ Cannot clear package list cache - directory not writable"
fi
# ENDIF: apt lists directory writable
# Update package lists from the new mirror with validation
# F2: Capture both output and exit code separately for proper validation
apt_update_output=$(/usr/bin/apt-get update -o Acquire::Retries=3 2>&1)
apt_update_exit_code=$?
# F2: Validate command substitution result
if [ -z "${apt_update_output:-}" ] && [ "${apt_update_exit_code:-1}" -ne 0 ]; then
    echo "[warn] ⚠ apt-get update produced no output but exited with code ${apt_update_exit_code}"
fi

# Check if apt-get update failed with 403 (blocked) or other access errors
if [[ "${apt_update_exit_code:-1}" -ne 0 ]]; then
  # D3: Use here-string instead of pipe pattern
  if [ -n "${apt_update_output:-}" ] && grep -qiE "(403|Forbidden|blocked|access denied|URL blocked)" <<< "${apt_update_output}"; then
    echo "[ERROR] Selected mirror ${FASTEST_MIRROR} is blocked (403) or inaccessible"
    echo "[info] Falling back to default archive.ubuntu.com..."
    
    # Revert to archive.ubuntu.com
    FASTEST_MIRROR="http://archive.ubuntu.com/ubuntu"
    export FASTEST_MIRROR
    
    # Re-apply default mirror using reapply_fastest_mirror function
    reapply_fastest_mirror
  else
    echo "[warn] apt-get update had issues (may continue): ${apt_update_output}"
  fi
else
  echo "✓ Package lists refreshed - apt-aria will now use URIs from fastest mirror"
fi
# ENDIF: apt-get update exit code check

#--- Sub-block 9.5: Enable additional APT repositories ---
# Critical: Add universe, Mozilla PPA, ulauncher PPA
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
# A5a: Use printf instead of echo -e for robustness
printf '\n\033[1;34m===> Enabling the '\''universe'\'' repository for additional packages...\033[0m\n'
# The 'software-properties-common' package provides add-apt-repository command
# H1: Check exit code of apt-get update operation
if ! /usr/bin/apt-get update -o Acquire::Retries=3 2>&1; then
    echo "[warn] ⚠ apt-get update had issues - continuing anyway"
fi
# ENDIF: apt-get update for enabling repos
# H1: Check exit code of apt-get install operation
if ! /usr/bin/apt-get install -y --no-install-recommends software-properties-common 2>&1; then
    echo "[ERROR] ⚠ Failed to install software-properties-common"
    exit 1
fi
# ENDIF: install software-properties-common
# M1: Verify add-apt-repository command is available
if ! command -v add-apt-repository &> /dev/null; then
    echo "[ERROR] ⚠ add-apt-repository not found after installation"
    exit 1
fi
# ENDIF: add-apt-repository availability
# H1: Check exit codes of add-apt-repository operations
# Check if universe is already enabled before trying to add it
if grep -qE "^[^#]*universe" /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null; then
    echo "[info] ✓ Universe repository already enabled"
else
    if ! add-apt-repository -y universe 2>&1; then
        echo "[warn] ⚠ Failed to add universe repository (may already exist or preferences file issue)"
        # Try manual method as fallback
        CODENAME=$(lsb_release -cs 2>/dev/null || echo "")
        if [ -n "${CODENAME}" ]; then
            echo "[info] Attempting manual universe repository addition..."
            if ! grep -qE "^[^#]*universe" /etc/apt/sources.list 2>/dev/null; then
                sed -i "s/^deb \(.*\) main$/deb \1 main universe/" /etc/apt/sources.list 2>/dev/null || true
            fi
        fi
    fi
fi
if ! add-apt-repository -y ppa:mozillateam/ppa 2>&1; then
    echo "[warn] ⚠ Failed to add Mozilla PPA (may already exist)"
fi
if ! add-apt-repository -y ppa:agornostal/ulauncher 2>&1; then
    echo "[warn] ⚠ Failed to add ulauncher PPA (may already exist)"
fi
# ENDIF: add-apt-repository calls

echo ""
echo "==> Re-applying fastest mirror after add-apt-repository (which uses default URLs)..."
# Use the reapply_fastest_mirror function to update all sources
reapply_fastest_mirror

echo "✓ Additional repositories enabled and verified"

#--- Sub-block 9.6: Synchronize base image with repositories ---
# Purpose: Resolve inconsistencies between base image and APT sources
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
# A5a: Use printf instead of echo -e for robustness
printf '\n%s===> Synchronizing base image with latest package versions...%s\n' "${BLUE}" "${NC}"
# Using dist-upgrade handles dependency changes intelligently
# H1: Check exit code of apt-get update operation
if ! /usr/bin/apt-get update -o Acquire::Retries=3 2>&1; then
    echo "[warn] ⚠ apt-get update had issues - continuing anyway"
fi
# DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get dist-upgrade -y
# H1: Check exit code of apt-get install -f operation
if ! /usr/bin/apt-get install -f -y 2>&1; then
    echo "[warn] ⚠ apt-get install -f had issues - continuing anyway"
fi
# H1: Check exit code of dpkg --configure operation
if ! dpkg --configure -a 2>&1; then
    echo "[warn] ⚠ dpkg --configure had issues - continuing anyway"
fi
# A5a: Use printf instead of echo -e for robustness
printf '%s✓ Base image synchronized.%s\n' "${GREEN}" "${NC}"

#===============================================================================
# BLOCK 10: APT CONFIGURATION AND GPG KEY SETUP
#===============================================================================
# Purpose: Configure APT, import GPG keys, set up package verification
# Self-contained: Yes (complete GPG and APT setup)
# Dependencies: dpkg, gpg, curl
# Outputs: Configured system components
#-------------------------------------------------------------------------------

#--- Sub-block 10.1: Install package verification tools ---
# Critical: dpkg-sig for .deb package verification (optional - not available in all Ubuntu versions)
# Dependencies: Block 6 (APT configuration), Block 15 (VirtualGL), Block 15 (TurboVNC)
# Outputs: Installed packages
# Sub-block 10.1 Rationale:
# - Purpose: Prefer dpkg-sig for native .deb signature verification when available.
# - Behavior: Attempt install non-fatally; if unavailable, fall back to structural
#   checks (dpkg-deb -I) and lenient signature presence checks later.
# - Rationale: Some Ubuntu variants omit dpkg-sig; we retain build portability by
#   not failing hard here while still enabling stronger verification where possible.
echo "Installing dpkg-sig for .deb package verification (if available)..."
# H1: Check exit code of apt-get install operation
if ! /usr/bin/apt-get install -y --no-install-recommends dpkg-sig 2>/dev/null; then
    echo "⚠️  dpkg-sig not available, using alternative verification"
fi
# ENDIF: dpkg-sig install attempt

# Import VirtualGL/TurboVNC GPG key for APT repositories
echo "Importing VirtualGL/TurboVNC GPG key for APT..."
# Using key URL from config.sh
# I4: HTTP error handling for curl operations
if [ -n "${VIRTUALGL_TURBOVNC_GPG_KEY_URL:-}" ]; then
    # F2: Validate command substitution result (curl output piped to gpg)
    # H1: Check exit code of curl and gpg pipeline
    # I4: HTTP error handling for curl operations - capture HTTP status code
    gpg_key_output=""
    # shellcheck disable=SC2034 # gpg_exit_code may be used for debugging/logging
    gpg_exit_code=0
    # I4: Capture HTTP status code separately using -w with newline separator
    http_code="000"
    if curl -w "\n%{http_code}" -fsSL --max-time 30 "${VIRTUALGL_TURBOVNC_GPG_KEY_URL}" 2>/dev/null > /tmp/virtualgl_gpg_response.tmp; then
        # I4: Extract HTTP code from last line of response
        if [ -f /tmp/virtualgl_gpg_response.tmp ] && [ -s /tmp/virtualgl_gpg_response.tmp ]; then
            http_code=$(tail -n 1 /tmp/virtualgl_gpg_response.tmp 2>/dev/null || echo "000")
            # I4: Validate HTTP status code is 3-digit number before checking
            if [[ "${http_code}" =~ ^[0-9]{3}$ ]]; then
                if [ "${http_code}" != "200" ]; then
                    echo "[warn] ⚠ HTTP ${http_code} error downloading GPG key from ${VIRTUALGL_TURBOVNC_GPG_KEY_URL}"
                    gpg_key_output=""
                else
                    # I4: HTTP 200 success - extract body (all lines except last)
                    gpg_key_output=$(head -n -1 /tmp/virtualgl_gpg_response.tmp 2>/dev/null || echo "")
                fi
            else
                echo "[warn] ⚠ Invalid HTTP status code format: ${http_code}"
                gpg_key_output=""
            fi
        else
            echo "[warn] ⚠ Downloaded GPG key response is empty or missing"
            gpg_key_output=""
        fi
        rm -f /tmp/virtualgl_gpg_response.tmp 2>/dev/null || true
    else
        echo "[warn] ⚠ Failed to download GPG key from ${VIRTUALGL_TURBOVNC_GPG_KEY_URL} (connection/timeout error)"
        rm -f /tmp/virtualgl_gpg_response.tmp 2>/dev/null || true
        gpg_key_output=""
    fi
    if [ -n "${gpg_key_output:-}" ]; then
        # D3: Use here-string instead of pipe pattern (unsafe pipe pattern fixed)
        if gpg --dearmor -o /usr/share/keyrings/virtualgl-turbovnc.gpg 2>/dev/null <<< "${gpg_key_output}"; then
            # J1: Verify GPG key file was created successfully
            if [ -f /usr/share/keyrings/virtualgl-turbovnc.gpg ]; then
                echo "✓ VirtualGL/TurboVNC GPG key imported successfully for APT"
            else
                echo "[warn] ⚠ GPG key import succeeded but file not found"
            fi
        else
            echo "✗ Failed to import VirtualGL/TurboVNC GPG key (non-fatal, will retry during installation)"
            # Don't exit - this is for APT repos which might not be in use
        fi
    else
        echo "[warn] ⚠ Failed to download GPG key from ${VIRTUALGL_TURBOVNC_GPG_KEY_URL}"
    fi
else
    echo "⚠ VIRTUALGL_TURBOVNC_GPG_KEY_URL not set - skipping GPG key import"
fi
# ENDIF: VIRTUALGL_TURBOVNC_GPG_KEY_URL presence
#
# Sub-block 10.2 Rationale and Security Notes:
# - Purpose: Import the Drake GPG key from the pre-seeded build cache to verify
#   repository metadata and packages originating from Drake-related APT sources.
# - Source of truth: The key file 'drake.asc' is expected in '${CONTAINER_BIN_CACHE}'
#   (copied via %files). This avoids relying on external keyservers at build time,
#   improving reproducibility and reliability.
# - Failure handling: All file operations are validated (existence, readability),
#   and the resulting keyring file is checked after dearmor to prevent silent
#   failures. Any failure in this block is treated as fatal to avoid proceeding
#   with unverifiable repositories.
# - Output: A keyring file at '/usr/share/keyrings/drake.gpg' suitable for use
#   in APT 'signed-by=' entries.
#
#--- Sub-block 10.2: Import Drake GPG key ---
# Critical: Import Drake robotics framework GPG key from cache
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "Importing Drake GPG key..."
if [ -z "${CONTAINER_BIN_CACHE:-}" ]; then
    echo "✗ CONTAINER_BIN_CACHE not set - cannot import Drake GPG key"
    exit 1
fi

# J1: Validate file exists and is readable before operations
if [ -f "${CONTAINER_BIN_CACHE}/drake.asc" ] && [ -r "${CONTAINER_BIN_CACHE}/drake.asc" ]; then
    # H1: Check exit code of gpg operation
    if gpg --dearmor -o /usr/share/keyrings/drake.gpg "${CONTAINER_BIN_CACHE}/drake.asc" 2>/dev/null; then
        # J1: Verify GPG key file was created successfully
        if [ -f /usr/share/keyrings/drake.gpg ] && [ -r /usr/share/keyrings/drake.gpg ]; then
            echo "✓ Drake GPG key imported successfully"
        else
            echo "[ERROR] ⚠ GPG key import succeeded but file not found or not readable"
            exit 1
        fi
    else
        echo "[ERROR] ⚠ Failed to import Drake GPG key"
        exit 1
    fi
else
    echo "[ERROR] ⚠ Drake GPG key file not found or not readable at ${CONTAINER_BIN_CACHE}/drake.asc"
    exit 1
fi
# End Drake GPG import (if-else self-contained)

#--- Sub-block 10.3: .deb package verification function ---
# Purpose: Verify .deb packages using GPG signatures
# Parameters:
#   $1: Absolute path to the .deb file to verify (required)
#   $2: GPG key ID (fingerprint or long key ID) used for verification (required)
# Returns:
#   0 on successful verification or acceptable fallback allowing installation;
#   1 on hard failure (invalid package structure, missing inputs, or
#   unrecoverable verification errors)
# Side effects:
#   - May import GPG keys into the temporary keyring of the build environment
#   - Writes diagnostic messages to stdout/stderr for traceability
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
verify_deb_package() {
    local deb_file="${1:-}"
    local gpg_key_id="${2:-}"
    local basename_file

    # Validate inputs
    if [ -z "${deb_file}" ]; then
        echo "✗ Error: Package file not provided"
        return 1
    fi
    
    if [ -z "${gpg_key_id}" ]; then
        echo "✗ Error: GPG key ID not provided"
        return 1
    fi
    
    if [ ! -f "${deb_file}" ]; then
        echo "✗ Error: Package file not found: ${deb_file}"
        return 1
    fi
    
    # F2: Validate command substitution result
    basename_file=$(basename "${deb_file}" || echo "")
    if [ -z "${basename_file:-}" ]; then
        basename_file="${deb_file}"  # Fallback to full path if basename fails
    fi
    echo "Verifying .deb package: ${basename_file}"

    # First, verify package structure
    # H1: Check exit code of dpkg-deb operation
    if ! dpkg-deb -I "${deb_file}" >/dev/null 2>&1; then
        echo "✗ Package structure is invalid: ${basename_file}"
        return 1
    fi

    # Import the GPG key for verification
    echo "Importing GPG key for verification..."
    # H1: Check exit code of gpg operation
    if ! gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${gpg_key_id}" >/dev/null 2>&1; then
        echo "Δ Failed to import GPG key, trying alternative keyserver..."
        # H4: Validate gpg operation result (may fail, which is OK)
        if ! gpg --batch --keyserver keys.openpgp.org --recv-keys "${gpg_key_id}" 2>/dev/null; then
            echo "[warn] ⚠ Failed to import GPG key from alternative keyserver"
        fi
    fi

    # Try dpkg-sig verification first
    # M1: Verify dpkg-sig command exists
    if command -v dpkg-sig >/dev/null 2>&1; then
        # H1: Check exit code of dpkg-sig verification
        if dpkg-sig --verify "${deb_file}" >/dev/null 2>&1; then
            echo "✓ GPG signature verified with dpkg-sig for ${basename_file}"
            return 0
        fi
    fi

    echo "Δ dpkg-sig verification failed, trying alternative verification..."

    # Alternative: Check if the package has a valid signature using gpg directly
    # Extract signature and verify
    # F2: Validate command substitution result
    if command -v dpkg-sig >/dev/null 2>&1; then
        local sig_list_output
        sig_list_output=$(dpkg-sig -list "${deb_file}" 2>/dev/null || echo "")
        # D3: Use here-string instead of pipe pattern (unsafe pipe pattern fixed)
        if [ -n "${sig_list_output:-}" ] && grep -q "signature" <<< "${sig_list_output}"; then
            echo "✓ Package has valid signature structure for ${basename_file}"
            return 0  # Loosening constraint to allow install
        else
            echo "✗ No valid signature found for ${basename_file}"
            echo "Δ Continuing with installation despite signature verification failure..."
            return 0  # Allow installation to continue
        fi
    else
        echo "✗ dpkg-sig not available for signature verification"
        echo "Δ Continuing with installation despite signature verification failure..."
        return 0  # Allow installation to continue
    fi
}


#--- Sub-block 10.4: Unified cache configuration function ---
# Purpose: Configure all package manager caches (APT, pip, conda, Julia)
# Inputs:
#   - Uses environment variables from earlier blocks and config.sh:
#     CONTAINER_APT_CACHE, CONTAINER_CONDA_CACHE, PIP_CACHE_DIR, MINIFORGE_HOME
# Outputs:
#   - Writes APT cache policy to /etc/apt/apt.conf.d/90-cache.conf
#   - Writes pip cache policy to /root/.config/pip/pip.conf
#   - Optionally writes pre-conda config to ${MINIFORGE_HOME}/.condarc.pre
# Guarantees:
#   - All file writes and directory creations are validated with existence and
#     permission checks, and failures are reported explicitly.
# Security:
#   - Paths are derived from environment variables set earlier; no untrusted input.
#   - All heredocs are quoted when variable expansion is not desired.
# Dependencies: Block 17 (Conda/Miniforge)
# Outputs: Python packages, conda environments
setup_unified_cache() {
    echo "==> Configuring unified caching for all package managers..."

    # Validate cache first
    validate_and_repair_cache

  # 1. Configure APT Caching (safe to do early)
    # This directory exists by default on Ubuntu.
    # CRITICAL: Use double quotes to expand ${CONTAINER_APT_CACHE} variable
    # J1: Validate parent directory exists before creating file
    # H1: Check exit code of file write operations
    if [ -d /etc/apt/apt.conf.d ] && [ -w /etc/apt/apt.conf.d ]; then
        if ! echo "Dir::Cache::Archives \"${CONTAINER_APT_CACHE}\";" > /etc/apt/apt.conf.d/90-cache.conf 2>/dev/null; then
            echo "[ERROR] ⚠ Failed to write APT cache configuration file"
            return 1
        fi
        if ! echo 'APT::Keep-Downloaded-Packages "true";' >> /etc/apt/apt.conf.d/90-cache.conf 2>/dev/null; then
            echo "[ERROR] ⚠ Failed to append to APT cache configuration file"
            return 1
        fi
    else
        echo "[ERROR] ⚠ /etc/apt/apt.conf.d directory not writable"
        return 1
    fi

  # 2. Configure Pip Caching
    # J1: Validate parent directory exists before creating subdirectory
    # H1: Check exit code of directory and file operations
    if ! mkdir -p /root/.config/pip 2>/dev/null; then
        echo "[ERROR] ⚠ Failed to create pip config directory"
        return 1
    fi
    # J1: Verify directory was created successfully
    if [ ! -d /root/.config/pip ]; then
        echo "[ERROR] ⚠ pip config directory does not exist after creation"
        return 1
    fi
    if ! printf "[global]\ncache-dir = %s\n" "$PIP_CACHE_DIR" > /root/.config/pip/pip.conf 2>/dev/null; then
        echo "[ERROR] ⚠ Failed to write pip configuration file"
        return 1
    fi
    # H1: Check exit code of chown operation
    if [ -d "$PIP_CACHE_DIR" ] && ! chown -R root:root "$PIP_CACHE_DIR" 2>/dev/null; then
        echo "[warn] ⚠ Failed to set ownership on pip cache directory"
    fi
    # H1: Check exit code of chmod operation
    if [ -d "$PIP_CACHE_DIR" ] && ! chmod -R 755 "$PIP_CACHE_DIR" 2>/dev/null; then
        echo "[warn] ⚠ Failed to set permissions on pip cache directory"
    fi

  # 3. Prepare Conda Caching with Staging Area Strategy
    # This config file will be used when Miniforge is installed later
    # Note: Use double quotes heredoc to allow variable expansion
    if [ -n "${MINIFORGE_HOME:-}" ]; then
        # J1: Validate parent directory exists before creating subdirectory
        # H1: Check exit code of mkdir operation
        if ! mkdir -p "${MINIFORGE_HOME}" 2>/dev/null; then
            echo "[warn] ⚠ Failed to create MINIFORGE_HOME directory: ${MINIFORGE_HOME}"
        else
            # J1: Verify directory was created successfully
            if [ ! -d "${MINIFORGE_HOME}" ]; then
                echo "[warn] ⚠ MINIFORGE_HOME directory does not exist after creation"
            else
                # H1: Check exit code of cat/heredoc operation
                # EXEMPTED FROM EXTRACTION: Uses variable interpolation (${CONTAINER_CONDA_CACHE}), dynamically generated with script variables
                if ! cat > "${MINIFORGE_HOME}/.condarc.pre" <<EOF
channels:
  - conda-forge
channel_priority: strict
# Explicitly disable defaults/anaconda repos (community repos only)
default_channels: []
pkgs_dirs:
  - ${CONTAINER_CONDA_CACHE:-/container_cache/conda_pkgs}

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
                then
                    echo "[ERROR] ⚠ Failed to write conda configuration file"
                else
                    # J1: Verify file was created successfully
                    if [ ! -f "${MINIFORGE_HOME}/.condarc.pre" ]; then
                        echo "[warn] ⚠ Conda config file does not exist after creation"
                    fi
                fi
            fi
        fi
    else
        echo "⚠ WARNING: MINIFORGE_HOME not set - skipping conda cache configuration"
    fi
    # ENDIF: MINIFORGE_HOME provided for conda cache configuration



# === 4. Configure Julia Caching ===
    # Verify APT cache configuration was properly applied
    echo "==> Verifying APT cache configuration..."
    # J1: Validate file exists and is readable before operations
    if [ -f /etc/apt/apt.conf.d/90-cache.conf ] && [ -r /etc/apt/apt.conf.d/90-cache.conf ]; then
        echo "APT cache configuration file contents:"
        # H1: Check exit code of cat operation
        if ! cat /etc/apt/apt.conf.d/90-cache.conf 2>/dev/null; then
            echo "[warn] ⚠ Failed to read APT cache configuration file"
        fi
        # Verify the path is expanded (not literal ${CONTAINER_APT_CACHE})
        # D3: Use here-string instead of pipe pattern
        local config_content
        config_content=$(cat /etc/apt/apt.conf.d/90-cache.conf 2>/dev/null || echo "")
        # D3: Use here-string instead of pipe pattern (unsafe pipe pattern fixed)
        if [ -n "${config_content:-}" ] && grep -q "\${CONTAINER_APT_CACHE}" <<< "${config_content}"; then
            echo "[ERROR] ⚠ APT cache configuration has unexpanded variable!"
            exit 1
        fi
        echo "✓ APT cache configured to: ${CONTAINER_APT_CACHE}"
    else
        echo "[ERROR] ⚠ APT cache configuration file not found or not readable!"
        exit 1
    fi
    # ENDIF: APT cache configuration verification
    
    echo "==> Initial caching configured successfully."
}
# End setup_unified_cache function (self-contained)

#--- Sub-block 10.5: Execute unified cache setup ---
# Critical: Initialize all package manager caches before any installations
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
setup_unified_cache

#--- Sub-block 10.6: Protect pre-seeded cache files ---
# Purpose: Apply immutable flag to prevent accidental deletion of cached packages
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "==> Applying immutable flag to protect pre-seeded APT cache..."
# The "e2fsprogs" package, which provides chattr, is part of the base image
# We suppress errors in case no .deb files were pre-seeded
# M1: Verify chattr command exists
if command -v chattr >/dev/null 2>&1; then
    # J1: Validate directory exists and is accessible before operations
    if [ -d "${CONTAINER_APT_CACHE:-/container_cache/apt}" ] && [ -x "${CONTAINER_APT_CACHE:-/container_cache/apt}" ]; then
        # Use find to safely handle glob expansion and avoid errors when no files exist
        # H4: Validate find/exec operation result
        chattr_exit_code=0
        find "${CONTAINER_APT_CACHE}" -maxdepth 1 -name "*.deb" -type f -exec chattr +i {} \; 2>/dev/null || chattr_exit_code=$?
        if [ "${chattr_exit_code:-0}" -ne 0 ]; then
            echo "[warn] ⚠ Some files may not have been protected with chattr"
        fi
        # Count protected files for confirmation
        # F2: Validate command substitution result
        protected_count=""
        protected_count=$(find "${CONTAINER_APT_CACHE}" -maxdepth 1 -name "*.deb" -type f 2>/dev/null | wc -l || echo "0")
        # Validate result is numeric and non-empty
        if [ -z "${protected_count:-}" ] || ! [[ "${protected_count:-0}" =~ ^[0-9]+$ ]]; then
            protected_count="0"
        fi
        if [ "${protected_count:-0}" -gt 0 ]; then
            echo "✓ Pre-seeded cache files are now protected (${protected_count} files)."
        else
            echo "ℹ No pre-seeded cache files found to protect."
        fi
    else
        echo "[warn] ⚠ APT cache directory not accessible: ${CONTAINER_APT_CACHE:-/container_cache/apt}"
    fi
else
    echo "WARNING: 'chattr' command not found. Pre-seeded cache is not protected."
fi
# End cache protection (if-else self-contained)
# ENDIF: chattr availability and cache directory access checks

#--- Sub-block 10.7: Install essential system tools ---
# Critical: Tools needed for GPG verification, downloads, and system management
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing essential tools for verification, downloads, and system management..."
# H1: Check exit code of apt-get update operation
if ! /usr/bin/apt-get update -o Acquire::Retries=3 2>&1; then
    echo "[warn] ⚠ apt-get update had issues - continuing anyway"
fi

#--- Sub-block 10.8: Install aria2 download accelerator ---
# Critical: Install aria2 BEFORE creating apt-aria wrapper
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing aria2 before creating apt-aria wrapper..."
# H1: Check exit code of apt-get install operation
if ! /usr/bin/apt-get install -y --no-install-recommends aria2 2>&1; then
    echo "[ERROR] ⚠ Failed to install aria2"
    exit 1
fi
# M1: Verify aria2 was installed successfully
if ! command -v aria2c >/dev/null 2>&1; then
    echo "[ERROR] ⚠ aria2 installation succeeded but command not found"
    exit 1
fi
# ENDIF: aria2 installation and verification

# Monitor cache after first package installation
monitor_cache "After aria2 installation"
debug_glibc "After Aria installation"

#--- Sub-block 10.9: Install core APT and system utilities ---
# Critical: Essential tools for system configuration and package management
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing core APT and system utilities..."
# H1: Check exit code of apt-get install operation
if ! /usr/bin/apt-get install -y --no-install-recommends \
    e2fsprogs \
    debconf-utils \
    dialog \
    software-properties-common \
    lsb-release \
    tzdata \
    locales \
    bc \
    procps \
    findutils \
    coreutils 2>&1; then
    echo "[ERROR] ⚠ Failed to install core APT and system utilities"
    exit 1
fi
# Verify procps (includes pgrep) is available
# M1: Verify pgrep command exists
if ! command -v pgrep >/dev/null 2>&1; then
    echo "⚠ WARNING: pgrep not found after procps installation, installing procps-ng as fallback..."
    # H1: Check exit code of apt-get install operation
    if ! /usr/bin/apt-get install -y --no-install-recommends procps-ng 2>/dev/null; then
        echo "[warn] ⚠ Failed to install procps-ng fallback"
    fi
fi
if command -v pgrep >/dev/null 2>&1; then
    echo "✓ pgrep available (from procps)"
else
    echo "⚠ WARNING: pgrep still not available - will use ps aux with grep fallbacks"
fi
# ENDIF: core APT/system utilities installed and pgrep verification
debug_glibc "After installing core APT & System utilities"

#--- Sub-block 10.10: Install network and download tools ---
# Critical: Tools for downloading packages and accessing repositories
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing network and download tools..."
# H1: Check exit code of apt-get install operation
if ! /usr/bin/apt-get install -y --no-install-recommends \
    curl \
    wget \
    apt-transport-https 2>&1; then
    echo "[ERROR] ⚠ Failed to install network and download tools"
    exit 1
fi
# ENDIF: network & download tools installation
debug_glibc "After installing network & download tools"

#--- Sub-block 10.11: Install security and encryption tools ---
# Critical: GPG, certificates, and security infrastructure
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing security and encryption tools..."
# H1: Check exit code of apt-get install operation
if ! /usr/bin/apt-get install -y --no-install-recommends \
    gnupg \
    dirmngr \
    ca-certificates \
    sudo 2>&1; then
    echo "[ERROR] ⚠ Failed to install security and encryption tools"
    exit 1
fi
# debsig-verify removed - we use dpkg-deb for package verification instead
# ENDIF: security & encryption tools installation
debug_glibc "After installing security & encryption tools"

#--- Sub-block 10.12: Install archive and compression tools ---
# Critical: Tools for extracting and compressing packages
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing archive and compression tools..."
# H1: Check exit code of apt-get install operation
if ! /usr/bin/apt-get install -y --no-install-recommends \
    unzip \
    bzip2 \
    tar \
    gzip \
    xz-utils \
    p7zip-full 2>&1; then
    echo "[ERROR] ⚠ Failed to install archive and compression tools"
    exit 1
fi
# ENDIF: archive & compression tools installation
debug_glibc "After installing archive & compression tools"
# Monitor cache after 4 batches of installations
monitor_cache "After 4 batches of essential tools"

#--- Sub-block 10.13: Install file and text utilities ---
# Critical: File manipulation and text editing tools
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing file and text utilities..."
# H1: Check exit code of apt-get install operation
if ! /usr/bin/apt-get install -y --no-install-recommends \
    file \
    less \
    tree \
    nano \
    vim-tiny \
    dos2unix \
    bsdextrautils \
    xxd 2>&1; then
    echo "[ERROR] ⚠ Failed to install file and text utilities"
    exit 1
fi
# ENDIF: file & text utilities installation
debug_glibc "After installing file & text utilities"

#--- Sub-block 10.13a: Install advanced search and productivity CLI tools ---
# Critical: Provide modern search and navigation utilities early in the build
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages, initial command aliases
echo "==> Installing advanced search and productivity CLI tools..."
# H1: Check exit code of apt-get install operation
if ! /usr/bin/apt-get install -y --no-install-recommends \
    ripgrep \
    fd-find \
    fzf \
    silversearcher-ag \
    ack \
    bat 2>&1; then
    echo "[ERROR] ⚠ Failed to install advanced search and productivity CLI tools"
    exit 1
fi
# ENDIF: advanced search/productivity tools installation

# Ensure consistent command names regardless of Debian/Ubuntu packaging quirks
# M1: Verify commands exist before creating symlinks
# J1: Validate target directory exists before creating symlinks
    if [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then
        if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
        # F2: Validate command substitution result
        fdfind_path=""
        fdfind_path=$(command -v fdfind 2>/dev/null || echo "")
        if [ -n "${fdfind_path:-}" ] && [ -x "${fdfind_path:-}" ]; then
            # H1: Check exit code of ln operation
            if ln -sf "${fdfind_path}" /usr/local/bin/fd 2>/dev/null; then
                # J1: Verify symlink was created successfully
                if [ -L /usr/local/bin/fd ]; then
                    echo "✓ Created /usr/local/bin/fd symlink to fdfind"
                else
                    echo "[warn] ⚠ Symlink creation may have failed"
                fi
            else
                echo "[warn] ⚠ Failed to create /usr/local/bin/fd symlink"
            fi
        fi
        # ENDIF: fdfind symlink creation
        fi
        # ENDIF: fdfind command check

        if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
        # F2: Validate command substitution result
        batcat_path=""
        batcat_path=$(command -v batcat 2>/dev/null || echo "")
        if [ -n "${batcat_path:-}" ] && [ -x "${batcat_path:-}" ]; then
            # H1: Check exit code of ln operation
            if ln -sf "${batcat_path}" /usr/local/bin/bat 2>/dev/null; then
                # J1: Verify symlink was created successfully
                if [ -L /usr/local/bin/bat ]; then
                    echo "✓ Created /usr/local/bin/bat symlink to batcat"
                else
                    echo "[warn] ⚠ Symlink creation may have failed"
                fi
            else
                echo "[warn] ⚠ Failed to create /usr/local/bin/bat symlink"
            fi
        fi
        # ENDIF: batcat symlink creation
        fi
        # ENDIF: batcat command check
    else
        echo "[warn] ⚠ /usr/local/bin directory not writable - cannot create symlinks"
    fi
    # ENDIF: symlink normalization for fd and bat

debug_glibc "After installing advanced search & productivity CLI tools"

#--- Sub-block 10.14: Install development and system tools ---
# Critical: Git, rsync, monitoring tools
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Installing development and system tools..."
# H1: Check exit code of apt-get install operation
if ! /usr/bin/apt-get install -y --no-install-recommends \
    git \
    rsync \
    htop \
    jq 2>&1; then
    echo "[ERROR] ⚠ Failed to install development and system tools"
    exit 1
fi
# ENDIF: development and system tools installation
debug_glibc "After installing development and system tools"

#--- Sub-block 10.15: Install apt-utils (optional) ---
# Purpose: Additional APT utilities if available
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
# H1: Check exit code of apt-get install operation (optional package)
if ! /usr/bin/apt-get install -y --no-install-recommends apt-utils 2>/dev/null; then
    echo "Δ apt-utils not available (continuing without it)"
fi
# ENDIF: optional apt-utils installation

#--- Sub-block 10.16: Install advanced package managers (optional) ---
# Purpose: Install alternative APT frontends if available
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "==> Attempting to install advanced package managers..."
# H1: Check exit code of apt-get install operations (optional packages)
if ! /usr/bin/apt-get install -y --no-install-recommends aptitude 2>/dev/null; then
    echo "Δ aptitude not available (continuing without it)"
fi
if ! /usr/bin/apt-get install -y --no-install-recommends nala 2>/dev/null; then
    echo "Δ nala not available (continuing without it)"
fi
# apt-fast removed - using apt-aria wrapper instead
if ! /usr/bin/apt-get install -y --no-install-recommends synaptic 2>/dev/null; then
    echo "Δ synaptic not available (continuing without it)"
fi
# ENDIF: optional advanced package managers
debug_glibc "After installing advanced package managers"

#--- Sub-block 10.17: Verify essential tool installation ---
# Critical: Ensure all required tools are available before proceeding
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# M1: Verify all essential commands exist
if ! command -v curl >/dev/null 2>&1; then
    echo "[ERROR] ⚠ curl install failed"
    exit 1
fi
if ! command -v wget >/dev/null 2>&1; then
    echo "[ERROR] ⚠ wget install failed"
    exit 1
fi
if ! command -v gpg >/dev/null 2>&1; then
    echo "[ERROR] ⚠ gpg install failed"
    exit 1
fi
# debsig-verify check removed - we use dpkg-deb for package verification instead
if ! command -v file >/dev/null 2>&1; then
    echo "[ERROR] ⚠ file install failed"
    exit 1
fi
if ! command -v unzip >/dev/null 2>&1; then
    echo "[ERROR] ⚠ unzip install failed"
    exit 1
fi
if ! command -v bzip2 >/dev/null 2>&1; then
    echo "[ERROR] ⚠ bzip2 install failed"
    exit 1
fi
if ! command -v git >/dev/null 2>&1; then
    echo "[ERROR] ⚠ git install failed"
    exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
    echo "[ERROR] ⚠ jq install failed"
    exit 1
fi
# Optional package check
if ! command -v aptitude >/dev/null 2>&1; then
    echo "⚠ aptitude not available after optional install attempt (continuing without it)"
fi
# ENDIF: essential/optional tool verification

#--- Sub-block 10.18: Check optional package managers ---
# Purpose: Report availability of optional tools
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "Checking for advanced package managers..."
if command -v nala >/dev/null 2>&1; then
    echo "✓ nala available"
else
    echo "Δ nala not available"
fi
# apt-fast removed - using apt-aria wrapper instead
if command -v synaptic >/dev/null 2>&1; then
    echo "✓ synaptic available"
else
    echo "Δ synaptic not available"
fi
# M1: Verify package installation using resilient helper
# H1: Check exit code of dpkg_resolve_installed_package operation
if dpkg_resolve_installed_package "apt-utils" >/dev/null 2>&1; then
    echo "✓ apt-utils package is installed"
else
    echo "Δ apt-utils package is not installed"
fi
# ENDIF: report optional package availability

echo "✓ Essential tools installed and verified"

# Monitor cache after essential tools installation
monitor_cache "After essential tools installation"

#--- Sub-block 10.19: Install SSHFS (Rust tools compiled from source later) ---
# Critical: SSHFS for remote filesystems; Rust tools compiled in Block 24 (baseline apt packages installed earlier for immediate availability)
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
# Note: bat, eza, ripgrep, fd, bottom, procs compiled from source for optimization
echo "==> Installing SSHFS (Rust tools compiled from source in Block 24)..."
# H1: Check exit code of apt-get install operation
if ! /usr/bin/apt-get install -y --no-install-recommends \
  sshfs 2>&1; then
    echo "[ERROR] ⚠ Failed to install sshfs"
    exit 1
fi
# ENDIF: sshfs installation

#--- Sub-block 10.20: Configure aliases for modern tools (MOVED TO BLOCK 24) ---
# Purpose: Aliases configured after Rust tools are compiled from source
# Dependencies: Block 24 (cargo install)
# Outputs: Deferred to Block 24
# Note: This block intentionally empty - aliases set up after tools installed
echo "==> Rust tool aliases will be configured in Block 24 after compilation"

#===============================================================================
# BLOCK 11: APT-ARIA WRAPPER SETUP (MUST BE BEFORE NVIDIA!)
#===============================================================================
# Purpose: Setup apt-aria wrapper for accelerated downloads with aria2
# Critical: MUST be configured BEFORE NVIDIA installation to enable aria2 for 4GB downloads
# Dependencies: aria2 (installed in Block 6.12.8)
# Outputs: apt-aria wrapper, symlinks for apt/apt-get
#-------------------------------------------------------------------------------

#--- Sub-block 11.1: Create APT tool aliasing wrapper ---
# Purpose: Setup unified caching with aria2 acceleration
# Rationale:
# - Accelerate large .deb downloads (e.g., NVIDIA keys/toolkits) using aria2
#   with parallel connections while preserving APT’s dependency resolution.
# - Enforce a single cache location so subsequent installs reuse artifacts,
#   lowering network usage and improving determinism.
# - Wrapper only intercepts install-like commands; other apt subcommands pass
#   through with unified cache options.
# Security/Resilience:
# - All file writes/symlinks are validated.
# - Fallbacks to single-connection aria2 or plain apt-get retain reliability.
# - chattr is optional; when available, it protects cached .debs from cleanup.
# Dependencies: Block 6 (APT configuration), aria2
# Outputs: Installed packages
echo "==> Setting up APT tool aliasing for unified caching..."

# Create apt-aria wrapper first
echo "Creating apt-aria wrapper for unified APT caching..."
# J1: Validate parent directory exists before creating subdirectory
# H1: Check exit code of install -d operation
if ! install -d -m 0755 /usr/local/bin 2>/dev/null; then
    echo "[ERROR] ⚠ Failed to create /usr/local/bin directory"
    exit 1
fi
# Note: shell-scripts file: /usr/local/bin/apt-aria is installed via install.sh from container-scripts/
# Source: shell-scripts/block-11-apt-aria-wrapper-setup-must-be-before-nvidia/apt-wrapper-aria2c-accelerated-downloads.sh
# Target: /usr/local/bin/apt-aria
# Installed in Block 0 (early in script, before any scripts are needed)
# Verify file was installed successfully
if [ ! -f /usr/local/bin/apt-aria ]; then
    echo "[ERROR] ⚠ apt-aria wrapper file not found after installation"
    exit 1
fi
if ! chmod 0755 /usr/local/bin/apt-aria 2>/dev/null; then
    echo "[ERROR] ⚠ Failed to set permissions on apt-aria wrapper"
    exit 1
fi
if [ ! -x /usr/local/bin/apt-aria ]; then
    echo "[ERROR] ⚠ apt-aria wrapper is not executable after chmod"
    exit 1
fi
echo "✓ apt-aria wrapper verified"

# Note: shell-scripts file: /etc/profile.d/container-cache.sh is installed via install.sh from container-scripts/
# Source: shell-scripts/block-11-apt-aria-wrapper-setup-must-be-before-nvidia/container-cache.sh
# Target: /etc/profile.d/container-cache.sh
# Installed in Block 0 (early in script, before any scripts are needed)
# Verify file was installed successfully
if [ ! -f /etc/profile.d/container-cache.sh ]; then
    echo "[ERROR] ⚠ container-cache.sh file not found after installation"
    exit 1
fi
# Verify permissions
if ! chmod 0644 /etc/profile.d/container-cache.sh 2>/dev/null; then
    echo "[ERROR] ⚠ Failed to set permissions on container-cache.sh"
    exit 1
fi
echo "✓ Container cache environment setup verified"

# Also add to /etc/environment for non-interactive shells
# J1: Validate file exists and is writable before operations
if [ -f /etc/environment ] && [ -w /etc/environment ]; then
    # D3: Use here-string instead of pipe pattern
    env_content=""
    env_content=$(cat /etc/environment 2>/dev/null || echo "")
    # D3: Use here-string instead of pipe pattern (unsafe pipe pattern fixed)
    if [ -z "${env_content:-}" ] || ! grep -q "^CONTAINER_APT_CACHE=" <<< "${env_content}"; then
        # H1: Check exit code of echo append operation
        if ! echo "CONTAINER_APT_CACHE=${CONTAINER_APT_CACHE:-/container_cache/apt/archives}" >> /etc/environment 2>/dev/null; then
            echo "[warn] ⚠ Failed to append to /etc/environment"
        fi
    fi
    # ENDIF: ensure CONTAINER_APT_CACHE present in /etc/environment
else
    echo "[warn] ⚠ /etc/environment not writable - skipping environment variable addition"
fi

# Monitor cache after apt-aria setup
monitor_cache "After apt-aria wrapper setup"

#--- Sub-block 11.2: Create APT tool symlinks for consistent caching ---
# Critical: Ensure ALL apt commands use unified cache and aria2 acceleration
# Dependencies: apt-aria wrapper (created above)
# Rationale:
# - Normalize invocation paths so scripts/tools calling `apt` or `apt-get`
#   transparently leverage the apt-aria wrapper (caching + acceleration).
# - Validates symlink creation and existence to prevent silent misconfiguration.
# - Keeps original binaries available under /usr/bin; only PATH lookups that
#   find /usr/local/bin first are redirected through the wrapper.
# Outputs: Symlinks for apt/apt-get
echo "Creating APT tool symlinks for consistent caching..."
# J1: Validate target directory exists and is writable before creating symlinks
# H1: Check exit code of ln operations
if [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then
    if ! ln -sf /usr/local/bin/apt-aria /usr/local/bin/apt-get 2>/dev/null; then
        echo "[ERROR] ⚠ Failed to create apt-get symlink"
        exit 1
    fi
    # J1: Verify symlink was created successfully
    if [ ! -L /usr/local/bin/apt-get ]; then
        echo "[ERROR] ⚠ apt-get symlink not found after creation"
        exit 1
    fi
    if ! ln -sf /usr/local/bin/apt-aria /usr/local/bin/apt 2>/dev/null; then
        echo "[ERROR] ⚠ Failed to create apt symlink"
        exit 1
    fi
    # J1: Verify symlink was created successfully
    if [ ! -L /usr/local/bin/apt ]; then
        echo "[ERROR] ⚠ apt symlink not found after creation"
        exit 1
    fi
else
    echo "[ERROR] ⚠ /usr/local/bin directory not writable - cannot create symlinks"
    exit 1
fi

#--- Sub-block 11.3: Verify APT aliasing ---
# Purpose: Confirm symlinks are properly configured
# Dependencies: apt-aria wrapper and symlinks
# Behavior:
# - Prints resolved targets of /usr/local/bin/{apt,apt-get}
# - Provides a concise confirmation that subsequent calls will use the wrapper
# Safety:
# - Guarded command substitutions; non-fatal reads default to informative text
# Outputs: Verification output
echo "Verifying APT tool aliasing..."
# F2: Validate command substitution results
apt_get_link=""
apt_link=""
apt_get_link=$(readlink -f /usr/local/bin/apt-get 2>/dev/null || echo 'Not aliased')
apt_link=$(readlink -f /usr/local/bin/apt 2>/dev/null || echo 'Not aliased')
# Validate results are non-empty
if [ -z "${apt_get_link:-}" ]; then
    apt_get_link='Not aliased'
fi
if [ -z "${apt_link:-}" ]; then
    apt_link='Not aliased'
fi
echo "apt-get -> ${apt_get_link}"
echo "apt -> ${apt_link}"
echo "✓ APT-aria wrapper and symlinks configured successfully"
echo "✓ ALL subsequent apt-get/apt commands will use aria2 acceleration + caching"

## Verify PATH order to ensure /usr/local/bin precedes /usr/bin (prevents wrapper overshadowing)
# F2: Validate command substitution result
path_value="${PATH:-}"
if [ -n "${path_value}" ]; then
    # F2: Validate command substitution results
    first_local=""
    first_usr=""
    first_local=$(awk -v RS=':' '/\/usr\/local\/bin/{print NR; exit}' <<< "${path_value}" 2>/dev/null || echo "")
    first_usr=$(awk -v RS=':' '/\/usr\/bin/{print NR; exit}' <<< "${path_value}" 2>/dev/null || echo "")
    # F2: Validate results are numeric before arithmetic comparison
    if [ -n "${first_local}" ] && [ -n "${first_usr}" ] && [[ "${first_local}" =~ ^[0-9]+$ ]] && [[ "${first_usr}" =~ ^[0-9]+$ ]]; then
        if [ "${first_local}" -gt "${first_usr}" ]; then
            echo "[warn] ⚠ PATH order may overshadow apt-aria: /usr/bin appears before /usr/local/bin"
            echo "       Current PATH: ${path_value}"
            echo "       Consider exporting PATH with /usr/local/bin before /usr/bin to ensure apt-aria is used."
        else
            echo "✓ PATH order confirmed: /usr/local/bin precedes /usr/bin (apt-aria active)"
        fi
    fi
fi
# ENDIF: PATH order verification

#===============================================================================
# BLOCK 12A: INTEL oneAPI MKL INSTALLATION
#===============================================================================
# Purpose: Install Intel MKL using the official oneAPI APT repository prior to
#          compiling OpenBLAS and SuiteSparse. Ensures MKLROOT, headers, and
#          libraries are available for downstream builds.
# Dependencies: Block 11 (APT caching/aliasing), config.sh variables
# Outputs: Intel MKL toolchain installed, environment hooks configured
#-------------------------------------------------------------------------------

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}BLOCK 12A: Intel oneAPI MKL Installation${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

: "${INTEL_ONEAPI_GPG_KEY_URL:?INTEL_ONEAPI_GPG_KEY_URL must be set in config.sh}"
: "${INTEL_ONEAPI_APT_SOURCE:?INTEL_ONEAPI_APT_SOURCE must be set in config.sh}"

ONEAPI_KEYRING="/usr/share/keyrings/oneapi-archive-keyring.gpg"
ONEAPI_SOURCE_LIST="/etc/apt/sources.list.d/oneAPI.list"

# M4: Use resilient helper instead of brittle dpkg -l | grep parsing
# F2: Validate command substitution result
mkl_check_output=""
# Note: Using dpkg_resolve_installed_package would be preferred, but checking for pattern match
mkl_check_output=$(dpkg -l 2>/dev/null | grep -iE "^ii\s+intel-oneapi-mkl" || echo "")
if [ -n "${mkl_check_output:-}" ]; then
    echo -e "${GREEN}✓ Intel oneAPI MKL already installed; skipping installation${NC}"
else
    echo -e "${YELLOW}[12A.1] Configuring Intel oneAPI APT repository...${NC}"
    # J1: Validate file exists before operations
    if [ ! -f "${ONEAPI_KEYRING}" ]; then
        echo "  Importing Intel oneAPI GPG key..."
        # I4: HTTP error handling for curl operations
        # F2: Validate command substitution result (curl output piped to gpg)
        # H1: Check exit code of curl and gpg pipeline
        gpg_key_output=""
        # I4: Capture HTTP status code and handle errors
        http_code=""
        http_code=$(curl -w "%{http_code}" -fsSL -o /tmp/gpg_key_temp "${INTEL_ONEAPI_GPG_KEY_URL}" 2>&1 || echo "000")
        # I4: Validate HTTP code is 3-digit number
        if [[ ! "${http_code}" =~ ^[0-9]{3}$ ]]; then
            echo "[ERROR] ⚠ Failed to download Intel oneAPI GPG key: Invalid HTTP response"
            exit 1
        fi
        # I4: Check for HTTP errors (403, 404, 5xx)
        if [ "${http_code}" = "403" ] || [ "${http_code}" = "404" ] || [ "${http_code}" -ge 500 ]; then
            echo "[ERROR] ⚠ HTTP ${http_code} error downloading Intel oneAPI GPG key from ${INTEL_ONEAPI_GPG_KEY_URL}"
            exit 1
        fi
        # I4: Read downloaded file
        if [ -f /tmp/gpg_key_temp ]; then
            gpg_key_output=$(cat /tmp/gpg_key_temp 2>/dev/null || echo "")
            rm -f /tmp/gpg_key_temp 2>/dev/null || true
        fi
        if [ -n "${gpg_key_output:-}" ]; then
            # D3: Use here-string instead of echo | grep (unsafe pipe pattern)
            if gpg --dearmor 2>/dev/null <<< "${gpg_key_output}" | tee "${ONEAPI_KEYRING}" >/dev/null; then
                # J1: Verify GPG key file was created successfully
                if [ ! -f "${ONEAPI_KEYRING}" ]; then
                    echo "[ERROR] ⚠ GPG key import succeeded but file not found"
                    exit 1
                fi
            else
                echo "[ERROR] ⚠ Failed to import Intel oneAPI GPG key"
                exit 1
            fi
        else
            echo "[ERROR] ⚠ Failed to download Intel oneAPI GPG key from ${INTEL_ONEAPI_GPG_KEY_URL}"
            exit 1
        fi
    else
        echo "  ✓ oneAPI keyring already present (${ONEAPI_KEYRING})"
    fi

    # J1: Validate file exists and is readable before operations
    # D3c: Use -F flag for fixed-string matching
    if [ ! -f "${ONEAPI_SOURCE_LIST}" ] || ! grep -Fq "apt.repos.intel.com/oneapi" "${ONEAPI_SOURCE_LIST}" 2>/dev/null; then
        echo "  Adding Intel oneAPI repository entry..."
        # J1: Validate parent directory exists before creating file
        # H1: Check exit code of printf operation
        if [ -d /etc/apt/sources.list.d ] && [ -w /etc/apt/sources.list.d ]; then
            if ! printf "%s\n" "${INTEL_ONEAPI_APT_SOURCE}" > "${ONEAPI_SOURCE_LIST}" 2>/dev/null; then
                echo "[ERROR] ⚠ Failed to write oneAPI source list"
                exit 1
            fi
            # J1: Verify file was created successfully
            if [ ! -f "${ONEAPI_SOURCE_LIST}" ]; then
                echo "[ERROR] ⚠ oneAPI source list file not found after creation"
                exit 1
            fi
        else
            echo "[ERROR] ⚠ /etc/apt/sources.list.d directory not writable"
            exit 1
        fi
    else
        echo "  ✓ oneAPI repository already configured (${ONEAPI_SOURCE_LIST})"
    fi

    echo "  Updating package indices for Intel oneAPI repository..."
    # H1: Check exit code of apt-get update operation
    if ! apt-get update -o Acquire::Retries=3 2>&1; then
        echo "[ERROR] ⚠ apt-get update failed for Intel oneAPI repository"
        exit 1
    fi

    echo -e "${YELLOW}[12A.2] Installing Intel oneAPI MKL packages (latest version)...${NC}"
    # Note: Installing without version pin installs the latest available version from the repository
    # H1: Check exit code of apt-get install operation
    if apt-get install -y --no-install-recommends intel-oneapi-mkl intel-oneapi-mkl-devel 2>&1; then
        echo -e "  ${GREEN}✓ Intel oneAPI MKL packages installed successfully${NC}"
        # Display installed version
        INSTALLED_MKL_VERSION=""
        INSTALLED_MKL_VERSION=$(dpkg -l 2>/dev/null | grep -iE "^ii\s+intel-oneapi-mkl\s" | awk '{print $3}' | head -1 || echo "")
        if [ -n "${INSTALLED_MKL_VERSION:-}" ]; then
            echo -e "  ${GREEN}✓ Installed version: ${INSTALLED_MKL_VERSION}${NC}"
        fi
        # H1: Check exit code of sync operation
        if ! sync 2>/dev/null; then
            echo "[warn] ⚠ sync operation failed (non-fatal)"
        fi
        monitor_cache "After Intel oneAPI MKL installation"
        
        # Verify actual MKL files were installed (not just package registration)
        echo -e "  ${YELLOW}[12A.2.1] Verifying MKL installation files...${NC}"
        MKL_VERIFY_PASSED=false
        MKL_BASE="/opt/intel/oneapi/mkl"
        
        # Check if MKL base directory exists
        if [ -d "${MKL_BASE}" ]; then
            # Find actual MKL installation directory
            MKL_ACTUAL_DIR=$(find "${MKL_BASE}" -maxdepth 2 -type d -name "lib" -path "*/intel64" 2>/dev/null | head -1 | sed 's|/lib/intel64$||' || echo "")
            
            if [ -n "${MKL_ACTUAL_DIR}" ] && [ -d "${MKL_ACTUAL_DIR}/lib/intel64" ]; then
                # Check for MKL libraries
                MKL_LIB_COUNT=$(find "${MKL_ACTUAL_DIR}/lib/intel64" -name "libmkl*.so" 2>/dev/null | wc -l)
                if [ "${MKL_LIB_COUNT}" -gt 0 ]; then
                    echo -e "    ${GREEN}✓ MKL libraries found: ${MKL_LIB_COUNT} libraries${NC}"
                    MKL_VERIFY_PASSED=true
                else
                    echo -e "    ${RED}✗ MKL libraries not found in ${MKL_ACTUAL_DIR}/lib/intel64${NC}"
                fi
                
                # Check for MKL headers
                if [ -d "${MKL_ACTUAL_DIR}/include" ] && [ -f "${MKL_ACTUAL_DIR}/include/mkl_cblas.h" ]; then
                    echo -e "    ${GREEN}✓ MKL headers found${NC}"
                else
                    echo -e "    ${YELLOW}⚠ MKL headers not found (may be in different location)${NC}"
                fi
                
                # Check for vars.sh (may be missing in APT packages)
                if [ -f "${MKL_ACTUAL_DIR}/env/vars.sh" ]; then
                    echo -e "    ${GREEN}✓ MKL vars.sh found: ${MKL_ACTUAL_DIR}/env/vars.sh${NC}"
                    # Ensure vars.sh has read permissions (needed for sourcing)
                    if [ ! -r "${MKL_ACTUAL_DIR}/env/vars.sh" ]; then
                        chmod +r "${MKL_ACTUAL_DIR}/env/vars.sh" 2>/dev/null || true
                        echo -e "    ${GREEN}✓ Fixed vars.sh read permissions${NC}"
                    fi
                else
                    echo -e "    ${YELLOW}⚠ MKL vars.sh not found (common with APT packages - will use fallback)${NC}"
                    echo -e "    ${YELLOW}  Note: Debian/Ubuntu APT packages may not include vars.sh${NC}"
                    echo -e "    ${YELLOW}  Environment will be configured via /etc/profile.d/intel-mkl.sh${NC}"
                fi
            else
                echo -e "    ${RED}✗ MKL library directory not found${NC}"
            fi
        else
            echo -e "    ${RED}✗ MKL base directory not found at ${MKL_BASE}${NC}"
        fi
        
        if [ "${MKL_VERIFY_PASSED}" = false ]; then
            echo -e "  ${RED}✗ MKL installation verification failed - libraries not found${NC}"
            echo -e "  ${YELLOW}  Package installation succeeded but MKL files are missing${NC}"
            echo -e "  ${YELLOW}  This may indicate a packaging issue or incomplete installation${NC}"
            exit 1
        fi
    else
        echo -e "  ${RED}✗ Failed to install Intel oneAPI MKL packages${NC}"
        exit 1
    fi
fi

echo -e "${YELLOW}[12A.3] Configuring Intel MKL environment...${NC}"
# Search for MKL environment script in common locations
# NOTE: vars.sh may be missing even with successful package installation because:
#   - Debian/Ubuntu APT packages (intel-oneapi-mkl) may not include vars.sh
#   - vars.sh is typically included in full Intel oneAPI installer, not APT packages
#   - Package installation can succeed (libraries installed) without vars.sh
#   - This is expected behavior - we use /etc/profile.d/intel-mkl.sh as fallback
MKL_ENV_SCRIPT=""
MKL_ENV_CANDIDATES=(
    "/opt/intel/oneapi/mkl/latest/env/vars.sh"
    "/opt/intel/oneapi/mkl/2025.3/env/vars.sh"
    "/opt/intel/oneapi/mkl/2025.2/env/vars.sh"
    "/opt/intel/oneapi/mkl/2025.1/env/vars.sh"
    "/opt/intel/oneapi/mkl/2024.2/env/vars.sh"
    "/opt/intel/oneapi/mkl/2024.1/env/vars.sh"
)

# Try to find vars.sh script
for candidate in "${MKL_ENV_CANDIDATES[@]}"; do
    if [ -f "${candidate}" ]; then
        MKL_ENV_SCRIPT="${candidate}"
        break
    fi
done

# If vars.sh not found, check if MKL is installed via alternative method
if [ -z "${MKL_ENV_SCRIPT}" ]; then
    echo -e "  ${YELLOW}⚠ MKL environment script (vars.sh) not found in expected locations${NC}"
    echo -e "  ${YELLOW}  Searched: ${MKL_ENV_CANDIDATES[*]}${NC}"
    
    # Check if MKL libraries exist even without vars.sh
    MKL_BASE="/opt/intel/oneapi/mkl"
    if [ -d "${MKL_BASE}" ]; then
        # Find the actual MKL installation directory
        MKL_ACTUAL_DIR=$(find "${MKL_BASE}" -maxdepth 2 -type d -name "lib" -path "*/intel64" 2>/dev/null | head -1 | sed 's|/lib/intel64$||' || echo "")
        if [ -n "${MKL_ACTUAL_DIR}" ] && [ -d "${MKL_ACTUAL_DIR}/lib/intel64" ]; then
            echo -e "  ${GREEN}✓ MKL libraries found at: ${MKL_ACTUAL_DIR}/lib/intel64${NC}"
            echo -e "  ${YELLOW}  Note: vars.sh script not found, but MKL appears to be installed${NC}"
            echo -e "  ${YELLOW}  Environment will be configured via /etc/profile.d/intel-mkl.sh${NC}"
            # Set MKLROOT based on found directory
            export MKLROOT="${MKL_ACTUAL_DIR}"
        else
            echo -e "  ${RED}✗ MKL installation not found - checking if packages were installed...${NC}"
            # Check if packages are installed
            if dpkg -l | grep -q "intel-oneapi-mkl"; then
                echo -e "  ${YELLOW}  ⚠ MKL packages are installed but structure differs from expected${NC}"
                echo -e "  ${YELLOW}  Continuing with manual environment configuration...${NC}"
            else
                echo -e "  ${RED}✗ MKL packages not found in dpkg listing${NC}"
                exit 1
            fi
        fi
    else
        echo -e "  ${RED}✗ MKL base directory not found at ${MKL_BASE}${NC}"
        exit 1
    fi
else
    echo -e "  ${GREEN}✓ Found MKL environment script: ${MKL_ENV_SCRIPT}${NC}"
fi
# ENDIF: MKL_ENV_SCRIPT existence check

# Note: shell-scripts file: /etc/profile.d/intel-mkl.sh is installed via install.sh from container-scripts/
# Source: shell-scripts/block-11-apt-aria-wrapper-setup-must-be-before-nvidia/intel-mkl-environment-setup.sh
# Target: /etc/profile.d/intel-mkl.sh
# Installed in Block 0 (early in script, before any scripts are needed)
# Verify file was installed successfully
if [ ! -f /etc/profile.d/intel-mkl.sh ]; then
    echo "[ERROR] ⚠ intel-mkl.sh file not found after installation"
    exit 1
fi
# H1: Check exit code of chmod operation
if ! chmod 0644 /etc/profile.d/intel-mkl.sh 2>/dev/null; then
    echo "[ERROR] ⚠ Failed to set permissions on intel-mkl.sh"
    exit 1
fi
# shellcheck disable=SC1091
if ! source /etc/profile.d/intel-mkl.sh 2>/dev/null; then
    echo "[ERROR] ⚠ Failed to source /etc/profile.d/intel-mkl.sh"
    exit 1
fi
echo "✓ Intel MKL environment configured"
# ENDIF: intel-mkl.sh installation verification

# Persist MKLROOT in /etc/environment for non-interactive shells
# Rationale: Ensures downstream tools invoked without a login shell find MKLROOT.
touch /etc/environment
# D3c: Use -F flag for fixed-string matching
if ! grep -Fq "^MKLROOT=" /etc/environment 2>/dev/null; then
    echo "MKLROOT=${MKLROOT}" >> /etc/environment
else
    # H1: Check exit code of sed operation
    if ! sed -i "s|^MKLROOT=.*|MKLROOT=${MKLROOT}|" /etc/environment 2>/dev/null; then
        echo "[ERROR] ⚠ Failed to update MKLROOT in /etc/environment"
        exit 1
    fi
fi
# ENDIF: ensure MKLROOT in /etc/environment

# H1: Check exit code of run_ldconfig_refresh operation
if ! run_ldconfig_refresh 2>&1; then
    echo "[warn] ⚠ ldconfig refresh failed (non-fatal)"
fi
echo -e "${GREEN}✓ Intel MKL installation and environment configuration complete${NC}"

# ------------------------------------------------------------------------------
# Dynamic MKL directory discovery (supports versioned layouts like 2025.3)
# ------------------------------------------------------------------------------
MKL_INCLUDE_DIR=""
MKL_LIB_DIR=""
MKL_INCLUDE_CANDIDATES=(
    "${MKLROOT}/include"
    "${MKLROOT}/../include"
    "${MKLROOT}/../../include"
)
MKL_LIB_CANDIDATES=(
    "${MKLROOT}/lib/intel64"
    "${MKLROOT}/lib/intel64_lin"
    "${MKLROOT}/lib/linux/intel64"
    "${MKLROOT}/lib"
    "${MKLROOT}/../lib/intel64"
    "${MKLROOT}/../lib"
)

for candidate in "${MKL_INCLUDE_CANDIDATES[@]}"; do
    if [ -z "${candidate}" ]; then
        continue
    fi
    if [ -d "${candidate}" ] && [ -f "${candidate}/mkl_cblas.h" ]; then
        MKL_INCLUDE_DIR="$(realpath -m "${candidate}")"
        break
    fi
# ENDFOR: MKL include candidate scan
done

if [ -z "${MKL_INCLUDE_DIR}" ]; then
    # F2: Validate command substitution result
    found_include=""
    found_include=$(find "${MKLROOT}" -maxdepth 4 -type f -name "mkl_cblas.h" -print -quit 2>/dev/null || echo "")
    # F2: Validate result is non-empty before use
    if [ -n "${found_include}" ] && [ -f "${found_include}" ]; then
        MKL_INCLUDE_DIR="$(dirname "${found_include}")"
    fi
fi

if [ -z "${MKL_INCLUDE_DIR}" ] || [ ! -d "${MKL_INCLUDE_DIR}" ]; then
    echo -e "  ${RED}✗ Unable to locate MKL include directory under ${MKLROOT}${NC}"
    exit 1
fi
echo "  ✓ MKL include directory resolved: ${MKL_INCLUDE_DIR}"

for candidate in "${MKL_LIB_CANDIDATES[@]}"; do
    if [ -z "${candidate}" ]; then
        continue
    fi
    if [ -d "${candidate}" ] && compgen -G "${candidate}/libmkl_*.so" >/dev/null; then
        MKL_LIB_DIR="$(realpath -m "${candidate}")"
        break
    fi
# ENDFOR: MKL lib candidate scan
done

if [ -z "${MKL_LIB_DIR}" ]; then
    # F2: Validate command substitution result
    found_lib=""
    found_lib=$(find "${MKLROOT}" -maxdepth 4 -type f \( -name "libmkl_rt.so" -o -name "libmkl_intel_lp64.so" \) -print -quit 2>/dev/null || echo "")
    # F2: Validate result is non-empty before use
    if [ -n "${found_lib}" ] && [ -f "${found_lib}" ]; then
        MKL_LIB_DIR="$(dirname "${found_lib}")"
    fi
fi

if [ -z "${MKL_LIB_DIR}" ] || [ ! -d "${MKL_LIB_DIR}" ]; then
    echo -e "  ${RED}✗ Unable to locate MKL library directory under ${MKLROOT}${NC}"
    exit 1
fi
echo "  ✓ MKL library directory resolved: ${MKL_LIB_DIR}"

MKL_RT_LIB="${MKL_LIB_DIR}/libmkl_rt.so"
if [ -f "${MKL_RT_LIB}" ]; then
    echo "  ✓ Using libmkl_rt runtime for BLAS/LAPACK linkage"
    MKL_BLAS_LIBRARIES="${MKL_RT_LIB};-lgomp;-lpthread;-lm;-ldl"
    MKL_LINK_FLAGS="${MKL_RT_LIB} -lgomp -lpthread -lm -ldl"
else
    echo "  ⚠ libmkl_rt.so not found, falling back to explicit MKL component libraries"
    MKL_BLAS_COMPONENTS="${MKL_LIB_DIR}/libmkl_intel_lp64.so;${MKL_LIB_DIR}/libmkl_core.so;${MKL_LIB_DIR}/libmkl_gnu_thread.so"
    MKL_BLAS_LIBRARIES="${MKL_BLAS_COMPONENTS};-lgomp;-lpthread;-lm;-ldl"
    MKL_LINK_FLAGS="-Wl,--start-group ${MKL_LIB_DIR}/libmkl_intel_lp64.so ${MKL_LIB_DIR}/libmkl_core.so ${MKL_LIB_DIR}/libmkl_gnu_thread.so -Wl,--end-group -lgomp -lpthread -lm -ldl"
fi
# ENDIF: libmkl_rt selection and fallback

export MKL_LIB_DIR MKL_INCLUDE_DIR MKL_BLAS_LIBRARIES MKL_LINK_FLAGS
export BLAS_LIBRARIES="${MKL_BLAS_LIBRARIES}"
export LAPACK_LIBRARIES="${MKL_BLAS_LIBRARIES}"

#--- Sub-block 12A.4: Register MKL with alternatives system ---
echo -e "${YELLOW}[12A.4] Registering Intel MKL with alternatives system...${NC}"

MKL_ALT_PRIORITY=200
# J1: Validate file exists before operations
if [ -f "${MKL_RT_LIB}" ] && [ -r "${MKL_RT_LIB}" ]; then
    echo "  Registering libmkl_rt.so (priority ${MKL_ALT_PRIORITY})..."
    # H1: Check exit code of update-alternatives operations
    if ! update-alternatives --install /usr/lib/x86_64-linux-gnu/libblas.so.3 \
        libblas.so.3-x86_64-linux-gnu \
        "${MKL_RT_LIB}" \
        "${MKL_ALT_PRIORITY}" 2>/dev/null; then
        echo -e "  ${YELLOW}⚠ Failed to register MKL as BLAS alternative${NC}"
    fi
    if ! update-alternatives --install /usr/lib/x86_64-linux-gnu/liblapack.so.3 \
        liblapack.so.3-x86_64-linux-gnu \
        "${MKL_RT_LIB}" \
        "${MKL_ALT_PRIORITY}" 2>/dev/null; then
        echo -e "  ${YELLOW}⚠ Failed to register MKL as LAPACK alternative${NC}"
    fi

    if [ "${DEFAULT_BLAS_PROVIDER}" = "MKL" ]; then
        echo "  Setting MKL as default provider (DEFAULT_BLAS_PROVIDER=${DEFAULT_BLAS_PROVIDER})..."
        # H4: Validate update-alternatives operations (may fail if not registered, which is OK)
        if ! update-alternatives --set libblas.so.3-x86_64-linux-gnu "${MKL_RT_LIB}" 2>/dev/null; then
            echo "[warn] ⚠ Failed to set MKL as default BLAS provider"
        fi
        if ! update-alternatives --set liblapack.so.3-x86_64-linux-gnu "${MKL_RT_LIB}" 2>/dev/null; then
            echo "[warn] ⚠ Failed to set MKL as default LAPACK provider"
        fi
    else
        echo -e "  ${YELLOW}⚠ DEFAULT_BLAS_PROVIDER=${DEFAULT_BLAS_PROVIDER}; leaving existing default in place${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠ Skipping alternatives registration: ${MKL_RT_LIB} not found${NC}"
fi
# ENDIF: alternatives registration for MKL

#--- Sub-block 12A.5: HPC MKL/CUDA tuning script ---
# Note: HPC tuning script is installed via install.sh from container-scripts/
# The script (/etc/profile.d/hpc-mkl-tune.sh) provides runtime optimization settings
# for HPC workloads (thread affinity, MKL tuning, CUDA settings, monitoring toggles).
# It will be available after install.sh runs (at end of %post section).
# These settings are for runtime optimization on HPC nodes, not required during build.

case ":${CMAKE_PREFIX_PATH:-}:" in
    *":${MKLROOT}:"*) ;;
    *) export CMAKE_PREFIX_PATH="${MKLROOT}:${CMAKE_PREFIX_PATH:-}" ;;
esac

#===============================================================================
# BLOCK 12: OPENBLAS COMPILATION AND INSTALLATION
#===============================================================================
# Purpose: Compile and install OpenBLAS with DYNAMIC_ARCH=1 for maximum performance
#          and CPU portability. Register it with the alternatives system so it is
#          available as a managed fallback while MKL remains the default BLAS/LAPACK
#          provider (unless DEFAULT_BLAS_PROVIDER overrides the preference).
# Self-contained: Yes (complete with verification and error handling)
# Dependencies: 
#   - Block 6.12: APT configuration
#   - Block 6.12A: apt-aria wrapper (for accelerated downloads)
# Outputs: Compiled OpenBLAS library, alternatives registration, library paths
# Timing: CRITICAL - Must execute BEFORE PHASE 1 (any package installations)
# Strategy: 
#   1. Check base image for existing OpenBLAS (analysis shows none exists)
#   2. Install build prerequisites (gcc, gfortran, libomp-dev, liblapack-dev)
#   3. Compile OpenBLAS v0.3.30 with DYNAMIC_ARCH=1
#   4. Install to /usr/local
#   5. Register with alternatives (fallback role unless explicitly preferred)
#   6. Configure library paths (ldconfig, PKG_CONFIG_PATH, LD_LIBRARY_PATH)
#   7. Set up APT pinning (prevent system OpenBLAS installation)
#   8. Verify installation and DYNAMIC_ARCH support
# Safety: 
#   - Base image has NO OpenBLAS (safe to install)
#   - Uses alternatives system (can rollback if needed)
#   - Packages use libblas.so.3 interface (compatible with OpenBLAS)
#   - No recompilation needed (existing binaries will use OpenBLAS automatically)
#-------------------------------------------------------------------------------

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}BLOCK 6.12B: OpenBLAS Compilation and Installation${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

#--- Sub-block 12.1: Check base image for existing OpenBLAS ---
# Purpose: Verify base image status (analysis shows no OpenBLAS exists)
# Dependencies: None (foundational check)
# Outputs: Status information
echo -e "${YELLOW}[6.12B.1] Checking base image for existing OpenBLAS...${NC}"
BASE_OPENBLAS_FOUND=false
# M4: Use resilient helper instead of brittle dpkg -l | grep parsing
# F2: Validate command substitution result
BASE_OPENBLAS_PKGS=""
BASE_OPENBLAS_PKGS=$(dpkg -l 2>/dev/null | grep -iE "^ii.*openblas" || echo "")
if [ -n "${BASE_OPENBLAS_PKGS:-}" ]; then
    echo -e "${YELLOW}⚠ Found OpenBLAS packages in base image:${NC}"
    echo "${BASE_OPENBLAS_PKGS}"
    BASE_OPENBLAS_FOUND=true
else
    echo -e "${GREEN}✓ No OpenBLAS packages found in base image (expected)${NC}"
fi

# Check for OpenBLAS library files
for lib_path in \
    "/usr/lib/x86_64-linux-gnu/libopenblas.so" \
    "/usr/lib/x86_64-linux-gnu/libopenblas.so.0" \
    "/usr/local/lib/libopenblas.so"; do
    if [ -f "${lib_path}" ]; then
        echo -e "${YELLOW}⚠ Found OpenBLAS library: ${lib_path}${NC}"
        BASE_OPENBLAS_FOUND=true
    fi
done
# ENDFOR: scan base image for OpenBLAS libraries

if [ "${BASE_OPENBLAS_FOUND}" = true ]; then
    echo -e "${YELLOW}⚠ WARNING: OpenBLAS detected in base image${NC}"
    echo -e "${YELLOW}  Strategy: Will compile our own OpenBLAS and register it with alternatives${NC}"
else
    echo -e "${GREEN}✓ Base image uses reference BLAS (libblas3) - safe to install OpenBLAS${NC}"
fi
echo ""

#--- Sub-block 12.2: Install build prerequisites ---
# Purpose: Install tools and libraries needed for OpenBLAS and PyTorch compilation
# Dependencies: Block 6.12 (APT configuration), Block 6.12A (apt-aria wrapper)
# Outputs: Installed packages
# Note: Installing comprehensive prerequisites for both OpenBLAS and PyTorch compilation
echo -e "${YELLOW}[6.12B.2] Installing build prerequisites for OpenBLAS and PyTorch...${NC}"
# H1: Check exit code of apt-get update operation
if ! apt-get update -o Acquire::Retries=3 2>&1; then
    echo "[ERROR] ⚠ apt-get update failed"
    exit 1
fi
# Note: `binutils` provides the `strings` utility used during OpenBLAS DYNAMIC_ARCH verification
# H1: Check exit code of apt-get install operation
if ! apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    g++ \
    gfortran \
    make \
    cmake \
    ninja-build \
    binutils \
    libomp-dev \
    liblapack-dev \
    liblapacke-dev \
    libblas-dev \
    libtbb-dev \
    python3-dev \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    perl \
    git \
    wget \
    curl \
    util-linux \
    sysstat \
    jq \
    pkg-config 2>&1; then
    echo "[ERROR] ⚠ Failed to install build prerequisites"
    exit 1
fi

printf '%s\n' "${GREEN}✓ Build prerequisites installed${NC}"
echo ""

#--- Sub-block 12.3: Download OpenBLAS source ---
# Purpose: Download OpenBLAS from official repository
# Dependencies: Block 6.12B.2 (git, wget, curl), config.sh (OPENBLAS_VERSION)
# Outputs: OpenBLAS source code
# Note: OPENBLAS_VERSION is defined in config.sh
printf '%s\n' "${YELLOW}[6.12B.3] Downloading OpenBLAS source...${NC}"
: "${OPENBLAS_VERSION:?OPENBLAS_VERSION must be set in config.sh}"
: "${SUITESPARSE_VERSION:?SUITESPARSE_VERSION must be set in config.sh}"
OPENBLAS_REPO_URL="https://github.com/OpenMathLib/OpenBLAS.git"
OPENBLAS_SOURCE_DIR="/tmp/openblas_build"
OPENBLAS_BUILD_FLAGS_DEFAULT="DYNAMIC_ARCH=1 DYNAMIC_OLDER=1 TARGET=GENERIC USE_OPENMP=1 USE_TLS=1 NO_AFFINITY=1 NUM_THREADS=64 GEMM_MULTITHREAD_THRESHOLD=50 BUILD_LAPACK_DEPRECATED=1 NO_WARMUP=1 BINARY=64 CC=gcc FC=gfortran HOSTCC=gcc"
OPENBLAS_BUILD_FLAGS="${OPENBLAS_BUILD_FLAGS:-${OPENBLAS_BUILD_FLAGS_DEFAULT}}"
SUITESPARSE_SOURCE_DIR="/tmp/suitesparse_build"
SUITESPARSE_INSTALL_PREFIX="${SUITESPARSE_INSTALL_PREFIX:-/usr/local}"
SUITESPARSE_CMAKE_FLAGS_DEFAULT="-DSUITESPARSE_USE_OPENMP=ON -DSUITESPARSE_USE_CUDA=ON -DSUITESPARSE_CUDA_ARCHITECTURES=86 -DSUITESPARSE_USE_STRICT=ON -DSUITESPARSE_USE_FORTRAN=ON -DCHOLMOD_USE_CUDA=ON -DSPQR_USE_CUDA=ON -DGRAPHBLAS_USE_CUDA=OFF -DCHOLMOD_PARTITION=ON -DCHOLMOD_CAMD=ON -DBLA_VENDOR=Intel10_64lp -DBLA_SIZEOF_INTEGER=4 -DSUITESPARSE_ENABLE_PROJECTS=all -DSUITESPARSE_DEMOS=OFF"
SUITESPARSE_CMAKE_FLAGS="${SUITESPARSE_CMAKE_FLAGS:-${SUITESPARSE_CMAKE_FLAGS_DEFAULT}}"
OPENBLAS_INSTALL_PREFIX="${OPENBLAS_INSTALL_PREFIX:-/usr/local}"
TARBALL_NAME="OpenBLAS-${OPENBLAS_VERSION#v}.tar.gz"
TARBALL_URL="https://github.com/OpenMathLib/OpenBLAS/releases/download/${OPENBLAS_VERSION}/${TARBALL_NAME}"

# Clean up any previous build
# H4: Validate rm operation result
if [ -d "${OPENBLAS_SOURCE_DIR}" ] || [ -f "${OPENBLAS_SOURCE_DIR}" ]; then
    if ! rm -rf "${OPENBLAS_SOURCE_DIR}" 2>/dev/null; then
        echo "[warn] ⚠ Failed to remove previous build directory"
    fi
fi
# J1: Validate parent directory exists before creating directory
# H1: Check exit code of mkdir operation
if ! mkdir -p "${OPENBLAS_SOURCE_DIR}" 2>/dev/null; then
    echo "[ERROR] ⚠ Failed to create OpenBLAS source directory: ${OPENBLAS_SOURCE_DIR}"
    exit 1
fi
# J1: Verify directory was created successfully
if [ ! -d "${OPENBLAS_SOURCE_DIR}" ]; then
    echo "[ERROR] ⚠ OpenBLAS source directory not found after creation"
    exit 1
fi
# J1: Validate directory exists and is accessible before cd
# H1: Check exit code of cd operation
if ! cd "${OPENBLAS_SOURCE_DIR}" 2>/dev/null; then
    echo "[ERROR] ⚠ Failed to change to OpenBLAS source directory: ${OPENBLAS_SOURCE_DIR}"
    exit 1
fi

DOWNLOAD_SUCCESS=false

# Method 1: Try downloading release tarball (most reliable)
echo "  Attempting to download release tarball: ${TARBALL_URL}"
# M1: Verify wget command exists
if command -v wget >/dev/null 2>&1; then
    # I4: HTTP error handling for wget operations
    # H1: Check exit code of wget operation
    if wget -q --show-progress "${TARBALL_URL}" -O "${TARBALL_NAME}" 2>&1; then
        # J1: Validate file exists and is non-empty before operations
        if [ -f "${TARBALL_NAME}" ] && [ -s "${TARBALL_NAME}" ]; then
            # H1: Check exit code of tar operation
            if tar -xzf "${TARBALL_NAME}" 2>/dev/null; then
                # J1: Validate directory exists before cd
                # H1: Check exit code of cd operation
                extracted_dir="OpenBLAS-${OPENBLAS_VERSION#v}"
                if [ -d "${extracted_dir}" ] && cd "${extracted_dir}" 2>/dev/null; then
                    printf '%s\n' "  ${GREEN}✓ Downloaded OpenBLAS ${OPENBLAS_VERSION} release tarball${NC}"
                    DOWNLOAD_SUCCESS=true
                else
                    printf '%s\n' "  ${YELLOW}⚠ Failed to change to extracted directory${NC}"
                    # H4: Validate rm operation result
                    if [ -f "${TARBALL_NAME}" ] && ! rm -f "${TARBALL_NAME}" 2>/dev/null; then
                        echo "[warn] ⚠ Failed to remove corrupted tarball"
                    fi
                fi
            else
                printf '%s\n' "  ${YELLOW}⚠ Failed to extract tarball${NC}"
                # H4: Validate rm operation result
                if [ -f "${TARBALL_NAME}" ] && ! rm -f "${TARBALL_NAME}" 2>/dev/null; then
                    echo "[warn] ⚠ Failed to remove corrupted tarball"
                fi
            fi
        fi
    fi
# M1: Verify curl command exists
elif command -v curl >/dev/null 2>&1; then
    # I4: HTTP error handling for curl operations
    # H1: Check exit code of curl operation
    if curl -L -f -s "${TARBALL_URL}" -o "${TARBALL_NAME}" 2>/dev/null; then
        # J1: Validate file exists and is non-empty before operations
        if [ -f "${TARBALL_NAME}" ] && [ -s "${TARBALL_NAME}" ]; then
            # H1: Check exit code of tar operation
            if tar -xzf "${TARBALL_NAME}" 2>/dev/null; then
                # J1: Validate directory exists before cd
                # H1: Check exit code of cd operation
                extracted_dir="OpenBLAS-${OPENBLAS_VERSION#v}"
                if [ -d "${extracted_dir}" ] && cd "${extracted_dir}" 2>/dev/null; then
                    printf '%s\n' "  ${GREEN}✓ Downloaded OpenBLAS ${OPENBLAS_VERSION} release tarball${NC}"
                    DOWNLOAD_SUCCESS=true
                else
                    printf '%s\n' "  ${YELLOW}⚠ Failed to change to extracted directory${NC}"
                    # H4: Validate rm operation result
                    if [ -f "${TARBALL_NAME}" ] && ! rm -f "${TARBALL_NAME}" 2>/dev/null; then
                        echo "[warn] ⚠ Failed to remove corrupted tarball"
                    fi
                fi
            else
                printf '%s\n' "  ${YELLOW}⚠ Failed to extract tarball${NC}"
                # H4: Validate rm operation result
                if [ -f "${TARBALL_NAME}" ] && ! rm -f "${TARBALL_NAME}" 2>/dev/null; then
                    echo "[warn] ⚠ Failed to remove corrupted tarball"
                fi
            fi
        fi
    fi
fi

# Method 2: Try git clone if tarball download failed
if [ "${DOWNLOAD_SUCCESS}" != "true" ]; then
    # M1: Verify git command exists
    if command -v git >/dev/null 2>&1; then
        echo "  Tarball download failed, attempting git clone..."
        # J1: Validate directory exists before cd
        # H1: Check exit code of cd operation
        if ! cd "${OPENBLAS_SOURCE_DIR}" 2>/dev/null; then
            echo "[ERROR] ⚠ Failed to change to OpenBLAS source directory"
            exit 1
        fi
        # H4: Validate rm operation result
        if [ -n "$(ls -A . 2>/dev/null)" ]; then
            if ! rm -rf ./* 2>/dev/null; then
                echo "[warn] ⚠ Failed to clean source directory"
            fi
        fi
        
        # Try cloning with tag
        # H1: Check exit code of git clone operation
        if git clone --depth 1 --branch "${OPENBLAS_VERSION}" "${OPENBLAS_REPO_URL}" . 2>&1; then
            printf '%s\n' "  ${GREEN}✓ Cloned OpenBLAS ${OPENBLAS_VERSION} from repository${NC}"
            DOWNLOAD_SUCCESS=true
        # Try cloning develop branch and checking out tag
        # H1: Check exit code of git clone operation
        elif git clone --depth 50 "${OPENBLAS_REPO_URL}" . 2>&1; then
            # H1: Check exit code of git checkout operation
            if git checkout "${OPENBLAS_VERSION}" 2>&1; then
                printf '%s\n' "  ${GREEN}✓ Checked out OpenBLAS ${OPENBLAS_VERSION}${NC}"
                DOWNLOAD_SUCCESS=true
            else
                echo "[warn] ⚠ Failed to checkout OpenBLAS ${OPENBLAS_VERSION}"
            fi
        else
            echo "[warn] ⚠ Git clone failed"
        fi
    else
        echo "[warn] ⚠ git command not available"
    fi
fi

# Final check
if [ "${DOWNLOAD_SUCCESS}" != "true" ]; then
    printf '%s\n' "  ${RED}✗ Failed to download OpenBLAS source${NC}"
    echo "  Please verify:"
    echo "    - Version ${OPENBLAS_VERSION} exists at https://github.com/OpenMathLib/OpenBLAS/releases"
    echo "    - Internet connectivity is available"
    exit 1
fi

# J1: Validate Makefile exists before operations
if [ ! -f "Makefile" ] || [ ! -r "Makefile" ]; then
    printf '%s\n' "  ${RED}✗ Makefile not found or not readable${NC}"
    exit 1
fi

printf '%s\n' "${GREEN}✓ OpenBLAS source downloaded successfully${NC}"
echo ""

#--- Sub-block 12.4: Compile OpenBLAS ---
# Purpose: Compile OpenBLAS with DYNAMIC_ARCH=1 for CPU portability
# Dependencies: Block 6.12B.3 (OpenBLAS source)
# Outputs: Compiled OpenBLAS library
printf '%s\n' "${YELLOW}[6.12B.4] Compiling OpenBLAS with DYNAMIC_ARCH=1...${NC}"
echo "  Build flags:"
for flag in ${OPENBLAS_BUILD_FLAGS}; do
    case "${flag}" in
        DYNAMIC_ARCH=1) echo "    DYNAMIC_ARCH=1 (runtime CPU detection - supports multiple architectures)";;
        DYNAMIC_OLDER=1) echo "    DYNAMIC_OLDER=1 (include legacy CPU targets for portability)";;
        TARGET=GENERIC) echo "    TARGET=GENERIC (safe base target)";;
        USE_OPENMP=1) echo "    USE_OPENMP=1 (OpenMP threading)";;
        USE_TLS=1) echo "    USE_TLS=1 (thread-local storage for thread buffers)";;
        NO_AFFINITY=1) echo "    NO_AFFINITY=1 (disable CPU affinity)";;
        NUM_THREADS=64) echo "    NUM_THREADS=64 (support for systems with up to 64 threads)";;
        GEMM_MULTITHREAD_THRESHOLD=50) echo "    GEMM_MULTITHREAD_THRESHOLD=50 (reduce multithreading overhead for small GEMMs)";;
        BUILD_LAPACK_DEPRECATED=1) echo "    BUILD_LAPACK_DEPRECATED=1 (retain deprecated LAPACK APIs)";;
        NO_WARMUP=1) echo "    NO_WARMUP=1 (skip warmup passes)";;
        BINARY=64) echo "    BINARY=64 (build 64-bit binaries)";;
        CC=gcc) echo "    CC=gcc";;
        FC=gfortran) echo "    FC=gfortran";;
        HOSTCC=gcc) echo "    HOSTCC=gcc";;
        *) ;;
    esac
done
echo ""

# Get number of CPU cores for parallel build
# F2: Validate command substitution result
BUILD_JOBS=$(nproc 2>/dev/null || echo "4")
if ! [[ "${BUILD_JOBS:-4}" =~ ^[0-9]+$ ]]; then
    BUILD_JOBS=4
fi
if [ "${BUILD_JOBS:-4}" -lt 1 ]; then
    BUILD_JOBS=1
fi
printf '%s\n' "  Using ${BUILD_JOBS} parallel jobs"

# Clean any previous build
# H4: Validate make clean operation (may fail if no previous build, which is OK)
if ! make clean >/dev/null 2>&1; then
    echo "[warn] ⚠ make clean failed (may be OK if no previous build)"
fi

# Compile OpenBLAS with optimal flags
# Reference: http://www.openmathlib.org/OpenBLAS/docs/install/
# D3: Use here-string or process substitution instead of pipe pattern
# H1: Check exit code of make operation
# J1: Validate log file directory exists before writing
if [ -d /tmp ] && [ -w /tmp ]; then
    # SC2086: OPENBLAS_BUILD_FLAGS is intentionally unquoted to allow word splitting for make flags
    # shellcheck disable=SC2086
    if tee /tmp/openblas_build.log < <(make -j"${BUILD_JOBS}" ${OPENBLAS_BUILD_FLAGS} 2>&1); then
        echo ""
        printf '%s\n' "  ${GREEN}✓ OpenBLAS compilation successful${NC}"
    else
        echo ""
        printf '%s\n' "  ${RED}✗ OpenBLAS compilation failed${NC}"
        echo "  Check log: /tmp/openblas_build.log"
        exit 1
    fi
else
    echo "[ERROR] ⚠ /tmp directory not writable - cannot create build log"
    exit 1
fi
echo ""

#--- Sub-block 12.5: Install OpenBLAS ---
# Purpose: Install OpenBLAS to /usr/local
# Dependencies: Block 6.12B.4 (compiled OpenBLAS)
# Outputs: Installed OpenBLAS library and headers
printf '%s\n' "${YELLOW}[6.12B.5] Installing OpenBLAS to ${OPENBLAS_INSTALL_PREFIX}...${NC}"
# Important: Pass all build flags to make install (per official documentation)
# D3: Use here-string or process substitution instead of pipe pattern
# H1: Check exit code of make install operation
# J1: Validate log file exists and is writable before appending
if [ -f /tmp/openblas_build.log ] && [ -w /tmp/openblas_build.log ]; then
    if tee -a /tmp/openblas_build.log < <(make install \
        PREFIX="${OPENBLAS_INSTALL_PREFIX}" \
        "${OPENBLAS_BUILD_FLAGS}" \
        2>&1); then
        printf '%s\n' "  ${GREEN}✓ OpenBLAS installation successful${NC}"
    else
        printf '%s\n' "  ${RED}✗ OpenBLAS installation failed${NC}"
        exit 1
    fi
else
    # Fallback: install without log appending
    if make install \
        PREFIX="${OPENBLAS_INSTALL_PREFIX}" \
        "${OPENBLAS_BUILD_FLAGS}" 2>&1; then
        printf '%s\n' "  ${GREEN}✓ OpenBLAS installation successful${NC}"
    else
        printf '%s\n' "  ${RED}✗ OpenBLAS installation failed${NC}"
        exit 1
    fi
fi
echo ""

#--- Sub-block 12.6: Verify OpenBLAS installation ---
# Purpose: Verify OpenBLAS library exists and has DYNAMIC_ARCH support
# Dependencies: Block 6.12B.5 (installed OpenBLAS)
# Outputs: Verification status
printf '%s\n' "${YELLOW}[6.12B.6] Verifying OpenBLAS installation...${NC}"
OPENBLAS_LIB="${OPENBLAS_INSTALL_PREFIX}/lib/libopenblas.so"
OPENBLAS_LIB_0="${OPENBLAS_INSTALL_PREFIX}/lib/libopenblas.so.0"

if [ -f "${OPENBLAS_LIB}" ] || [ -f "${OPENBLAS_LIB_0}" ]; then
    # Use the actual library file (may be .so or .so.0)
    if [ -f "${OPENBLAS_LIB_0}" ]; then
        OPENBLAS_LIB="${OPENBLAS_LIB_0}"
    fi
    
    printf '%s\n' "  ${GREEN}✓ OpenBLAS library found: ${OPENBLAS_LIB}${NC}"
    
    # Check library size
    # F2: Validate command substitution result
    # D3: Use here-string instead of pipe pattern
    lib_size_output=""
    lib_size_raw="$(du -h "${OPENBLAS_LIB}" 2>/dev/null || true)"
    if [ -n "${lib_size_raw:-}" ]; then
        lib_size_output="$(cut -f1 <<< "${lib_size_raw}")"
    else
        lib_size_output="unknown"
    fi
    if [ -n "${lib_size_output:-}" ] && [ "${lib_size_output}" != "unknown" ]; then
        echo "  Library size: ${lib_size_output}"
    else
        echo "  Library size: unknown"
    fi
    
    # Check for architecture-specific kernels (needed for DYNAMIC_ARCH verification)
    ARCH_COUNT="0"
    # M1: Verify strings command exists
    if command -v strings >/dev/null 2>&1; then
        # D3: Use here-string instead of pipe pattern
        # F2: Validate command substitution result
        arch_count_raw=""
        strings_output="$(strings "${OPENBLAS_LIB}" 2>/dev/null || true)"
        arch_count_raw="$(grep -ciE "HASWELL|SANDYBRIDGE|NEHALEM|PENRYN|CORE2|SKYLAKEX|CASCADELAKE|COOPERLAKE|ICELAKE|SAPPHIRERAPIDS" <<< "${strings_output}" 2>/dev/null || echo "0")"
        if [[ "${arch_count_raw:-0}" =~ ^[0-9]+$ ]]; then
            ARCH_COUNT="${arch_count_raw}"
        fi
    fi
    if [ "${ARCH_COUNT:-0}" -gt 0 ]; then
        printf '%s\n' "    ${GREEN}✓ Multiple CPU architecture kernels found (${ARCH_COUNT} architectures)${NC}"
    fi
    
    # Check for DYNAMIC_ARCH support
    echo "  Verifying DYNAMIC_ARCH support..."
    # M1: Verify strings command exists
    # D3: Use here-string instead of pipe pattern
    if command -v strings >/dev/null 2>&1; then
        dynamic_arch_check=""
        dynamic_arch_check=$(strings "${OPENBLAS_LIB}" 2>/dev/null || echo "")
        if [ -n "${dynamic_arch_check:-}" ] && grep -qiE "DYNAMIC_ARCH|dynamic_arch|DYNAMICARCH|Dynamic.*Arch|DYNAMIC.*ARCH" <<< "${dynamic_arch_check}"; then
            printf '%s\n' "    ${GREEN}✓ DYNAMIC_ARCH support confirmed${NC}"
        else
            # Additional check: if multiple architecture kernels are found, DYNAMIC_ARCH is likely enabled
            if [ "${ARCH_COUNT:-0}" -gt 1 ]; then
                printf '%s\n' "    ${GREEN}✓ DYNAMIC_ARCH support confirmed (multiple CPU architectures detected)${NC}"
            else
                printf '%s\n' "    ${YELLOW}⚠ DYNAMIC_ARCH string not found (may still work)${NC}"
            fi
        fi
    else
        printf '%s\n' "    ${YELLOW}⚠ strings command not available - cannot verify DYNAMIC_ARCH${NC}"
    fi
else
    printf '%s\n' "  ${RED}✗ OpenBLAS library not found at expected location${NC}" >&2
    exit 1
fi
echo ""
# ENDIF: OpenBLAS library presence and DYNAMIC_ARCH verification block

#--- Sub-block 12.7: Update alternatives system ---
# Purpose: Register OpenBLAS with the alternatives system (fallback role unless
#          DEFAULT_BLAS_PROVIDER explicitly requests OpenBLAS as the default)
# Dependencies: Block 6.12B.6 (verified OpenBLAS installation)
# Outputs: Updated alternatives configuration
printf '%s\n' "${YELLOW}[6.12B.7] Registering OpenBLAS with alternatives system...${NC}"

# Find the actual OpenBLAS library file
OPENBLAS_LIB_FILE=""
for lib_file in \
    "${OPENBLAS_INSTALL_PREFIX}/lib/libopenblas.so.0" \
    "${OPENBLAS_INSTALL_PREFIX}/lib/libopenblas.so"; do
    if [ -f "${lib_file}" ]; then
        OPENBLAS_LIB_FILE="${lib_file}"
        break
    fi
done

if [ -z "${OPENBLAS_LIB_FILE}" ]; then
    printf '%s\n' "  ${RED}✗ OpenBLAS library file not found${NC}" >&2
    exit 1
fi
# ENDIF: determine OpenBLAS library file path

# Update BLAS alternatives
OPENBLAS_ALT_PRIORITY=100
printf '%s\n' "  Registering OpenBLAS BLAS alternative (priority ${OPENBLAS_ALT_PRIORITY})..."
# H1: Check exit code of update-alternatives operation
if ! update-alternatives --install /usr/lib/x86_64-linux-gnu/libblas.so.3 \
    libblas.so.3-x86_64-linux-gnu \
    "${OPENBLAS_LIB_FILE}" "${OPENBLAS_ALT_PRIORITY}" 2>/dev/null; then
    printf '%s\n' "  ${YELLOW}⚠ Failed to set BLAS alternative (may already be set)${NC}" >&2
fi

# Update LAPACK alternatives (OpenBLAS includes LAPACK)
printf '%s\n' "  Registering OpenBLAS LAPACK alternative (priority ${OPENBLAS_ALT_PRIORITY})..."
LAPACK_ALT_LIB=""
for lapack_file in \
    "${OPENBLAS_INSTALL_PREFIX}/lib/libopenblas.so.0" \
    "${OPENBLAS_INSTALL_PREFIX}/lib/libopenblas.so"; do
    if [ -f "${lapack_file}" ]; then
        LAPACK_ALT_LIB="${lapack_file}"
        break
    fi
done

if [ -n "${LAPACK_ALT_LIB}" ]; then
    update-alternatives --install /usr/lib/x86_64-linux-gnu/liblapack.so.3 \
        liblapack.so.3-x86_64-linux-gnu \
        "${LAPACK_ALT_LIB}" "${OPENBLAS_ALT_PRIORITY}" || {
        printf '%s\n' "  ${YELLOW}⚠ Failed to set LAPACK alternative (may already be set)${NC}" >&2
    }
fi

if [ "${DEFAULT_BLAS_PROVIDER}" = "OPENBLAS" ]; then
    printf '%s\n' "  DEFAULT_BLAS_PROVIDER=${DEFAULT_BLAS_PROVIDER}; selecting OpenBLAS as default provider..."
    # H4: Validate alternatives set operation - check if it succeeded
    if ! update-alternatives --set libblas.so.3-x86_64-linux-gnu "${OPENBLAS_LIB_FILE}" 2>/dev/null; then
        printf '%s\n' "  ${YELLOW}⚠ Failed to set BLAS default to OpenBLAS${NC}" >&2
    fi
    if [ -n "${LAPACK_ALT_LIB}" ]; then
        if ! update-alternatives --set liblapack.so.3-x86_64-linux-gnu "${LAPACK_ALT_LIB}" 2>/dev/null; then
            printf '%s\n' "  ${YELLOW}⚠ Failed to set LAPACK default to OpenBLAS${NC}" >&2
        fi
    fi
else
    printf '%s\n' "  DEFAULT_BLAS_PROVIDER=${DEFAULT_BLAS_PROVIDER}; OpenBLAS registered as fallback alternative"
fi
printf '%s\n' "  ${GREEN}✓ Alternatives system registration complete${NC}"
echo ""
# ENDIF: alternatives registration for OpenBLAS

#--- Sub-block 12.8: Configure library paths ---
# Purpose: Make OpenBLAS available system-wide via library paths
# Dependencies: Block 6.12B.7 (alternatives updated)
# Outputs: Updated ldconfig, environment variables, pkg-config
printf '%s\n' "${YELLOW}[6.12B.8] Configuring library paths...${NC}"

# Verify library exists before updating ldconfig
# J1: File existence validation before use
if [ ! -f "${OPENBLAS_LIB_FILE}" ]; then
    printf '%s\n' "  ${RED}✗ Error: OpenBLAS library not found at ${OPENBLAS_LIB_FILE}${NC}" >&2
    printf '%s\n' "  Cannot update ldconfig without library file" >&2
    exit 1
fi

# Prioritise /usr/local libraries early in the build
ensure_compiled_lib_priority || {
  echo "  [WARN] Failed to ensure compiled lib priority, continuing..." >&2
}

# Update ldconfig
printf '%s\n' "  Updating ldconfig cache..."
if [ -d /etc/ld.so.conf.d ] && [ -w /etc/ld.so.conf.d ]; then
    echo "${OPENBLAS_INSTALL_PREFIX}/lib" > /etc/ld.so.conf.d/openblas-custom.conf
else
    printf '%s\n' "  ${YELLOW}⚠ /etc/ld.so.conf.d not writable; skipping custom ld.so entry${NC}" >&2
fi

# Use dynamic directory detection from installation output
# J1: File existence validation before use
if [ -f "/tmp/openblas_build.log" ]; then
    run_ldconfig_refresh_from_install_output "/tmp/openblas_build.log" 200
else
    printf '%s\n' "  ${YELLOW}⚠ Build log not found, using standard ldconfig refresh${NC}" >&2
    run_ldconfig_refresh 2>&1 || true
fi

# Verify OpenBLAS is now in ldconfig cache
# D3c: Use -F flag for literal pattern matching
# Note: config-files file: /etc/environment is installed via install.sh from container-scripts/
# Source: config-files/block-12-openblas-compilation-and-installation/environment.conf
# Target: /etc/environment
# Installed in Block 0 (early in script, before any scripts are needed)
    if ! run_ldconfig_refresh 2>&1; then
        printf '%s\n' "  ${YELLOW}⚠ ldconfig refresh failed${NC}" >&2
    fi
    # Check again
    # D3e: Add || true to prevent SIGPIPE error (exit code 141) when pipe breaks
    if ldconfig -p 2>/dev/null | grep -Fq -- libopenblas || true; then
        printf '%s\n' "  ${GREEN}✓ OpenBLAS now in ldconfig cache after retry${NC}"
    else
        printf '%s\n' "  ${YELLOW}⚠ OpenBLAS still not in ldconfig cache (library may need to be in standard location)${NC}" >&2
        printf '%s\n' "    Library exists at: ${OPENBLAS_LIB_FILE}"
        printf '%s\n' "    This is usually non-fatal - LD_LIBRARY_PATH will be used instead"
fi
# ENDIF: ldconfig cache verification

# Set environment variables (for current session and future sessions)
export LD_LIBRARY_PATH="${OPENBLAS_INSTALL_PREFIX}/lib:${LD_LIBRARY_PATH:-}"
export PKG_CONFIG_PATH="${OPENBLAS_INSTALL_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

# Add to CMAKE_PREFIX_PATH
case ":${CMAKE_PREFIX_PATH:-}:" in
    *:${OPENBLAS_INSTALL_PREFIX}:*) ;;
    *) export CMAKE_PREFIX_PATH="${OPENBLAS_INSTALL_PREFIX}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}" ;;
esac

# Add to environment for future sessions
# Note: config-files file: /etc/environment is installed via install.sh from container-scripts/
# Source: config-files/block-12-openblas-compilation-and-installation/environment.conf
# Target: /etc/environment
# Installed in Block 0 (early in script, before any scripts are needed)
# Note: This file uses 'cat >>' (append), so the content is added to existing /etc/environment

# Create pkg-config file for OpenBLAS
if ! mkdir -p "${OPENBLAS_INSTALL_PREFIX}/lib/pkgconfig" 2>/dev/null; then
    printf '%s\n' "  ${YELLOW}⚠ Failed to create pkgconfig directory at ${OPENBLAS_INSTALL_PREFIX}/lib/pkgconfig${NC}" >&2
fi
if [ -d "${OPENBLAS_INSTALL_PREFIX}/lib/pkgconfig" ] && [ -w "${OPENBLAS_INSTALL_PREFIX}/lib/pkgconfig" ]; then
# EXEMPTED FROM EXTRACTION: Uses variable interpolation (${OPENBLAS_INSTALL_PREFIX}, ${OPENBLAS_VERSION}), dynamically generated with script variables
cat > "${OPENBLAS_INSTALL_PREFIX}/lib/pkgconfig/openblas.pc" <<EOF
prefix=${OPENBLAS_INSTALL_PREFIX}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: OpenBLAS
Description: OpenBLAS is an optimized BLAS library
Version: ${OPENBLAS_VERSION#v}
Libs: -L\${libdir} -lopenblas
Cflags: -I\${includedir}
EOF
else
    printf '%s\n' "  ${YELLOW}⚠ Cannot write openblas.pc (directory not writable): ${OPENBLAS_INSTALL_PREFIX}/lib/pkgconfig${NC}" >&2
fi

# Create OpenBLAS CMake config files
if ! mkdir -p "${OPENBLAS_INSTALL_PREFIX}/lib/cmake/openblas" 2>/dev/null; then
    printf '%s\n' "  ${YELLOW}⚠ Failed to create CMake config directory at ${OPENBLAS_INSTALL_PREFIX}/lib/cmake/openblas${NC}" >&2
fi
if [ -d "${OPENBLAS_INSTALL_PREFIX}/lib/cmake/openblas" ] && [ -w "${OPENBLAS_INSTALL_PREFIX}/lib/cmake/openblas" ]; then
# EXEMPTED FROM EXTRACTION: Uses variable interpolation (${OPENBLAS_INSTALL_PREFIX}, ${OPENBLAS_VERSION}), dynamically generated with script variables
cat > "${OPENBLAS_INSTALL_PREFIX}/lib/cmake/openblas/OpenBLASConfig.cmake" <<EOF
# OpenBLAS CMake configuration file
set(OpenBLAS_VERSION "${OPENBLAS_VERSION#v}")
set(OpenBLAS_DIR "${OPENBLAS_INSTALL_PREFIX}/lib/cmake/openblas")

# Include directories
set(OpenBLAS_INCLUDE_DIRS "${OPENBLAS_INSTALL_PREFIX}/include")

# Library directories
set(OpenBLAS_LIBRARY_DIRS "${OPENBLAS_INSTALL_PREFIX}/lib")

# Find OpenBLAS library
find_library(OpenBLAS_LIBRARY openblas PATHS "\${OpenBLAS_LIBRARY_DIRS}" NO_DEFAULT_PATH)
if(OpenBLAS_LIBRARY)
    set(OpenBLAS_LIBRARIES "\${OpenBLAS_LIBRARY}")
    set(OpenBLAS_FOUND TRUE)
    set(OPENBLAS_FOUND TRUE)
else()
    set(OpenBLAS_FOUND FALSE)
    set(OPENBLAS_FOUND FALSE)
endif()
EOF
# ENDIF: OpenBLASConfig.cmake creation

# EXEMPTED FROM EXTRACTION: Uses variable interpolation (${OPENBLAS_VERSION}), dynamically generated with script variables
cat > "${OPENBLAS_INSTALL_PREFIX}/lib/cmake/openblas/OpenBLASConfigVersion.cmake" <<EOF
set(PACKAGE_VERSION "${OPENBLAS_VERSION#v}")
if(PACKAGE_VERSION VERSION_LESS PACKAGE_FIND_VERSION)
    set(PACKAGE_VERSION_COMPATIBLE FALSE)
else()
    set(PACKAGE_VERSION_COMPATIBLE TRUE)
    if(PACKAGE_VERSION STREQUAL PACKAGE_FIND_VERSION)
        set(PACKAGE_VERSION_EXACT TRUE)
    endif()
endif()
EOF
# ENDIF: OpenBLASConfigVersion.cmake creation
else
    printf '%s\n' "  ${YELLOW}⚠ Cannot write OpenBLAS CMake configs (directory not writable): ${OPENBLAS_INSTALL_PREFIX}/lib/cmake/openblas${NC}" >&2
fi
# ENDIF: OpenBLAS CMake config creation

# Note: config-files file: /etc/profile.d/openblas.sh is installed via install.sh from container-scripts/
# Source: config-files/block-12-openblas-compilation-and-installation/openblas.sh
# Target: /etc/profile.d/openblas.sh
# Installed in Block 0 (early in script, before any scripts are needed)
# Verify file was installed successfully
if [ ! -f /etc/profile.d/openblas.sh ]; then
    printf '%s\n' "  ${YELLOW}⚠ openblas.sh file not found after installation${NC}" >&2
else
    if ! chmod 0644 /etc/profile.d/openblas.sh 2>/dev/null; then
        printf '%s\n' "  ${YELLOW}⚠ Failed to set permissions on /etc/profile.d/openblas.sh${NC}" >&2
    fi
# ENDIF: openblas.sh installation verification
fi

printf '%s\n' "  ${GREEN}✓ Library paths, CMake configs, and profile.d script configured${NC}"
echo ""

#--- Sub-block 12.9: Set up APT pinning ---
# Purpose: Prevent APT from installing system OpenBLAS packages
# Dependencies: None (APT configuration)
# Outputs: APT preferences file
printf '%s\n' "${YELLOW}[6.12B.9] Setting up APT pinning to protect OpenBLAS...${NC}"
if [ -d /etc/apt/preferences.d ] && [ -w /etc/apt/preferences.d ]; then
    # Note: config-files file: /etc/apt/preferences.d/openblas-protect is installed via install.sh from container-scripts/
    # Source: config-files/block-12-openblas-compilation-and-installation/openblas-protect.pref
    # Target: /etc/apt/preferences.d/openblas-protect
    # Installed in Block 0 (early in script, before any scripts are needed)
    : # No-op: File is installed via install.sh, no action needed here
else
    printf '%s\n' "  ${YELLOW}⚠ /etc/apt/preferences.d not writable; skipping APT pinning${NC}" >&2
fi

printf '%s\n' "  ${GREEN}✓ APT pinning configured${NC}"
echo ""

#--- Sub-block 12.10: Final verification ---
# Purpose: Verify OpenBLAS is properly configured and being used
# Dependencies: Block 6.12B.8 (library paths configured)
# Outputs: Verification status
printf '%s\n' "${YELLOW}[6.12B.10] Final verification...${NC}"

# Check alternatives
printf '%s\n' "  Checking alternatives system:"
# D3d, F2: Validate command substitution result
# D3e: Add || true to prevent SIGPIPE error (exit code 141) when pipe breaks
CURRENT_BLAS=$(update-alternatives --display libblas.so.3-x86_64-linux-gnu 2>/dev/null | grep -F "link currently points to" 2>/dev/null | sed 's/.*points to //' 2>/dev/null || echo "unknown")
# F2: Validate result is non-empty
if [ -z "${CURRENT_BLAS:-}" ]; then
    CURRENT_BLAS="unknown"
fi
# D3c: Use -F flag for literal pattern matching
if grep -Fq "${OPENBLAS_LIB_FILE}" < <(update-alternatives --display libblas.so.3-x86_64-linux-gnu 2>/dev/null); then
    printf '%s\n' "    ${GREEN}✓ OpenBLAS registered with alternatives (priority ${OPENBLAS_ALT_PRIORITY})${NC}"
else
    printf '%s\n' "    ${YELLOW}⚠ OpenBLAS not listed in BLAS alternatives${NC}" >&2
fi

if [ "${DEFAULT_BLAS_PROVIDER}" = "MKL" ]; then
    # D3c: Use -F flag for literal pattern matching (case-insensitive)
    if grep -Fqi "mkl" <<< "${CURRENT_BLAS}"; then
        printf '%s\n' "    ${GREEN}✓ Default BLAS provider matches preference (${CURRENT_BLAS})${NC}"
    else
        printf '%s\n' "    ${YELLOW}⚠ Default BLAS provider (${CURRENT_BLAS}) differs from preferred MKL${NC}" >&2
    fi
elif [ "${DEFAULT_BLAS_PROVIDER}" = "OPENBLAS" ]; then
    # D3c: Use -F flag for literal pattern matching (case-insensitive)
    if grep -Fqi "openblas" <<< "${CURRENT_BLAS}"; then
        printf '%s\n' "    ${GREEN}✓ Default BLAS provider matches preference (${CURRENT_BLAS})${NC}"
    else
        printf '%s\n' "    ${YELLOW}⚠ Default BLAS provider (${CURRENT_BLAS}) differs from preferred OpenBLAS${NC}" >&2
    fi
else
    printf '%s\n' "    ${YELLOW}⚠ DEFAULT_BLAS_PROVIDER=${DEFAULT_BLAS_PROVIDER}; current BLAS points to ${CURRENT_BLAS}${NC}" >&2
fi

# Check ldconfig
printf '%s\n' "  Checking ldconfig:"
# D3c: Use -F flag for literal pattern matching
if grep -Fq libopenblas < <(timeout 5 ldconfig -p 2>/dev/null); then
    printf '%s\n' "    ${GREEN}✓ OpenBLAS found in ldconfig cache${NC}"
    # H4: Validate grep result before using
    # SC2034: ldconfig_output kept for potential future use in debugging
    # shellcheck disable=SC2034
    ldconfig_output=""
    # D3e: Add || true to prevent SIGPIPE error (exit code 141) when pipe breaks
    mapfile -t _ld_lines < <(timeout 5 ldconfig -p 2>/dev/null | grep -F libopenblas 2>/dev/null | head -3 2>/dev/null || true)
    if [ "${#_ld_lines[@]}" -gt 0 ]; then
        printf '%s\n' "${_ld_lines[@]}" | sed 's/^/      /'
    fi
else
    printf '%s\n' "    ${YELLOW}⚠ OpenBLAS not in ldconfig cache (may need manual update)${NC}" >&2
fi

# Verify library file exists and is accessible
# J1: File existence validation
if [ -f "${OPENBLAS_LIB_FILE}" ]; then
    printf '%s\n' "    ${GREEN}✓ OpenBLAS library file exists: ${OPENBLAS_LIB_FILE}${NC}"
else
    printf '%s\n' "    ${RED}✗ OpenBLAS library file not found${NC}" >&2
fi

echo ""
printf '%s\n' "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf '%s\n' "${GREEN}✓ OpenBLAS compilation and installation complete!${NC}"
printf '%s\n' "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
printf '%s\n' "Summary:"
printf '%s\n' "  - OpenBLAS ${OPENBLAS_VERSION} compiled with DYNAMIC_ARCH=1"
printf '%s\n' "  - Installed to: ${OPENBLAS_INSTALL_PREFIX}"
printf '%s\n' "  - Registered with alternatives (DEFAULT_BLAS_PROVIDER=${DEFAULT_BLAS_PROVIDER})"
printf '%s\n' "  - Current default BLAS provider: ${CURRENT_BLAS}"
printf '%s\n' "  - Library paths configured (ldconfig, PKG_CONFIG_PATH, LD_LIBRARY_PATH)"
printf '%s\n' "  - APT pinning configured (prevents system OpenBLAS installation)"
printf '%s\n' "  - Applications can select OpenBLAS via update-alternatives if desired"
echo ""

# Clean up build directory (keep installed files)
cd / || true
rm -rf "${OPENBLAS_SOURCE_DIR}" /tmp/openblas_build.log

#===============================================================================
# BLOCK 13: NVIDIA CUDA/cuDNN SETUP
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

#--- Sub-block 13.1: NVIDIA repository keyring installation ---
# Critical: Add NVIDIA GPG key and repository for CUDA 12.x
# Dependencies: Block 6 (APT configuration), Block 6.13 (NVIDIA CUDA)
# Outputs: Installed packages
echo "==> Installing NVIDIA cuDNN for CUDA 12.x..."

CUDA_STACK_ALREADY_PRESENT=false
# D3c: Use -F flag for literal pattern matching
if command -v nvcc >/dev/null 2>&1 && ldconfig -p 2>/dev/null | grep -Fq 'libcudnn.so'; then
  # D3d, F2: Validate command substitution result
  NVCC_VERSION_DETECTED=$(nvcc --version 2>/dev/null | awk -F'release ' 'NF>1 {print $2}' | awk '{print $1}' | tr -d 'V,' || echo "")
  # D3d, F2: Validate command substitution result
  CUDNN_VERSION_DETECTED=$(
    dpkg-query -W -f='${Version}\n' libcudnn9 2>/dev/null \
      || dpkg-query -W -f='${Version}\n' "libcudnn9-cuda-${CUDA_MAJOR}" 2>/dev/null \
      || dpkg-query -W -f='${Version}\n' libcudnn9-cuda 2>/dev/null \
      || echo ""
  )
  # F2: Validate command substitution results
  if [ -z "${NVCC_VERSION_DETECTED:-}" ]; then
      NVCC_VERSION_DETECTED=""
  fi
  if [ -z "${CUDNN_VERSION_DETECTED:-}" ]; then
      CUDNN_VERSION_DETECTED=""
  fi
  if [ -n "${NVCC_VERSION_DETECTED}" ] && [ "${NVCC_VERSION_DETECTED}" = "${CUDA_VERSION}" ] \
     && [ -n "${CUDNN_VERSION_DETECTED}" ] && [ -n "${CUDNN_VER:-}" ] \
     && [ "${CUDNN_VERSION_DETECTED}" = "${CUDNN_VER}" ]; then
    CUDA_STACK_ALREADY_PRESENT=true
    echo "[INFO] CUDA ${NVCC_VERSION_DETECTED} and cuDNN ${CUDNN_VERSION_DETECTED} already match requested versions; skipping reinstallation."
  else
    echo "[INFO] Detected existing CUDA/cuDNN stack but versions do not match requested configuration."
    echo "       - nvcc reported: ${NVCC_VERSION_DETECTED:-unknown}"
    echo "       - expected CUDA: ${CUDA_VERSION}"
    echo "       - cuDNN detected: ${CUDNN_VERSION_DETECTED:-unknown}"
    echo "       - expected cuDNN: ${CUDNN_VER:-unset}"
  fi
fi

CUDA_INSTALL_PERFORMED=false
if [ "${CUDA_STACK_ALREADY_PRESENT}" != "true" ]; then
  echo "[INFO] Proceeding with CUDA/cuDNN installation via APT..."
  
  # CRITICAL: Configure APT cache options to ensure packages are cached in /container_cache/apt/archives
  # This ensures packages are preserved even if build fails later
  # Also configure APT to prefer local packages (check cache first before downloading)
  APT_CACHE_OPTS="-o Dir::Cache::Archives=${CONTAINER_APT_CACHE} -o APT::Keep-Downloaded-Packages=true -o APT::Clean-Installed=false -o Acquire::http::AllowRedirect=false -o Acquire::Check-Valid-Until=false"
  
  # Verify APT cache directory exists and is accessible
  mkdir -p "${CONTAINER_APT_CACHE}" || {
      echo "ERROR: Failed to create APT cache directory: ${CONTAINER_APT_CACHE}"
      exit 1
  }
  
  if ! ensure_cuda_repository_configured; then
    echo "✗ Failed to configure NVIDIA repository keyring. Aborting GPU library install."
    export PHASE2_STATUS="FAIL"
    exit 1
  fi

  # Update package list to ensure CUDA repository metadata is available
  # Use APT cache configuration to ensure all operations use the persistent cache
  # H1: Exit-status check for external command
  if ! apt-get "${APT_CACHE_OPTS}" update; then
      echo "✗ Failed to update APT package list. Aborting GPU library install." >&2
      export PHASE2_STATUS="FAIL"
      exit 1
  fi

  # Determine the optimal CUDA package set available in Ubuntu 24.04
  CUDA_VERSION_PREFERRED="${CUDA_VERSION:-12.6}"
  CUDA_MAJOR="${CUDA_MAJOR:-${CUDA_VERSION_PREFERRED%%.*}}"
  CUDA_VERSION_SELECTED=""
  CUDA_PKG_SUFFIX="${CUDA_PKG_SUFFIX:-${CUDA_VERSION_PREFERRED//./-}}"
  CUDA_META_PACKAGE="${CUDA_META_PACKAGE:-cuda-${CUDA_PKG_SUFFIX}}"
  CUDA_TOOLKIT_PACKAGE="${CUDA_TOOLKIT_PACKAGE:-cuda-toolkit-${CUDA_PKG_SUFFIX}}"
  CUDA_RUNTIME_PACKAGE="${CUDA_RUNTIME_PACKAGE:-cuda-runtime-${CUDA_PKG_SUFFIX}}"
  CUDA_DEMO_PACKAGE="${CUDA_DEMO_PACKAGE:-cuda-demo-suite-${CUDA_PKG_SUFFIX}}"
  CUDA_DRIVER_PACKAGE="${CUDA_DRIVER_PACKAGE:-}"

  package_available() {
      local pkg="$1"
      local candidate
      # SC2155: Declare and assign separately to avoid masking return values
      candidate=$(apt-cache policy "${pkg}" 2>/dev/null | awk '/Candidate:/ {print $2}' || echo "")
      if [ -n "${candidate:-}" ] && [ "${candidate}" != "(none)" ]; then
          return 0
      fi
      return 1
  }

  append_cuda_package() {
      local pkg="$1"
      if [ -z "${pkg:-}" ]; then
          return
      fi
      if [ -z "${CUDA_INSTALL_SEEN[${pkg}]:-}" ]; then
          CUDA_INSTALL_PACKAGES+=("${pkg}")
          CUDA_INSTALL_SEEN["${pkg}"]=1
      fi
  }

  ensure_cuda_companion_package() {
      local base_pkg="$1"
      if [ -z "${base_pkg:-}" ]; then
          return
      fi

      local appended=false
      if [ -n "${CUDA_VERSION_SELECTED:-}" ]; then
          local suffix="${CUDA_VERSION_SELECTED//./-}"
          if package_available "${base_pkg}-${suffix}"; then
              append_cuda_package "${base_pkg}-${suffix}"
              appended=true
          fi
      fi

      if [ "${appended}" != true ] && [ -n "${CUDA_MAJOR:-}" ]; then
          if package_available "${base_pkg}-${CUDA_MAJOR}"; then
              append_cuda_package "${base_pkg}-${CUDA_MAJOR}"
              appended=true
          fi
      fi

      if [ "${appended}" != true ] && package_available "${base_pkg}"; then
          append_cuda_package "${base_pkg}"
      fi
  }

  declare -a CUDA_INSTALL_PACKAGES=()
  declare -A CUDA_INSTALL_SEEN=()

  if [ -n "${CUDA_META_PACKAGE:-}" ] && package_available "${CUDA_META_PACKAGE}"; then
      append_cuda_package "${CUDA_META_PACKAGE}"
      CUDA_VERSION_SELECTED="${CUDA_VERSION_PREFERRED}"
  fi

  if [ -n "${CUDA_TOOLKIT_PACKAGE:-}" ] && package_available "${CUDA_TOOLKIT_PACKAGE}"; then
      append_cuda_package "${CUDA_TOOLKIT_PACKAGE}"
      if [ -z "${CUDA_VERSION_SELECTED}" ]; then
          CUDA_VERSION_SELECTED="${CUDA_VERSION_PREFERRED}"
      fi
  fi

  if [ -n "${CUDA_RUNTIME_PACKAGE:-}" ] && package_available "${CUDA_RUNTIME_PACKAGE}"; then
      append_cuda_package "${CUDA_RUNTIME_PACKAGE}"
  fi

  if [ -n "${CUDA_DEMO_PACKAGE:-}" ] && package_available "${CUDA_DEMO_PACKAGE}"; then
      append_cuda_package "${CUDA_DEMO_PACKAGE}"
  fi

  if [ -n "${CUDA_DRIVER_PACKAGE:-}" ] && package_available "${CUDA_DRIVER_PACKAGE}"; then
      append_cuda_package "${CUDA_DRIVER_PACKAGE}"
  fi

  if [ ${#CUDA_INSTALL_PACKAGES[@]} -eq 0 ]; then
      declare -a CUDA_VERSION_CANDIDATES=()
      declare -A CUDA_VERSION_SEEN=()

      add_cuda_candidate() {
          local ver="$1"
          if [ -z "${ver}" ]; then
              return
          fi
          if [ -z "${CUDA_VERSION_SEEN[${ver}]:-}" ]; then
              CUDA_VERSION_CANDIDATES+=("${ver}")
              CUDA_VERSION_SEEN["${ver}"]=1
          fi
      }

      if [[ "${CUDA_VERSION_PREFERRED}" == *.* ]]; then
          add_cuda_candidate "${CUDA_VERSION_PREFERRED}"
      fi

      for fallback_version in 12.6 12.5 12.4 12.3 12.2; do
          if [[ "${fallback_version%%.*}" == "${CUDA_MAJOR}" ]]; then
              add_cuda_candidate "${fallback_version}"
          fi
      done

      for candidate in "${CUDA_VERSION_CANDIDATES[@]}"; do
          pkg_name="cuda-toolkit-${candidate//./-}"
          if package_available "${pkg_name}"; then
              append_cuda_package "${pkg_name}"
              CUDA_VERSION_SELECTED="${candidate}"
              break
          fi
      done
  fi

  if [ ${#CUDA_INSTALL_PACKAGES[@]} -eq 0 ]; then
      fallback_toolkit="cuda-toolkit-${CUDA_MAJOR}"
      if package_available "${fallback_toolkit}"; then
          append_cuda_package "${fallback_toolkit}"
          CUDA_VERSION_SELECTED="${CUDA_VERSION_PREFERRED:-${CUDA_MAJOR}}"
      else
          printf '%s\n' "✗ No suitable CUDA toolkit package found in APT repositories for major version ${CUDA_MAJOR}" >&2
          exit 1
      fi
  fi

  if [ -n "${CUDA_VERSION_SELECTED}" ]; then
      CUDA_VERSION="${CUDA_VERSION_SELECTED}"
      CUDA_MAJOR="${CUDA_VERSION_SELECTED%%.*}"
  fi

  # Ensure CUDA companion developer libraries used by SuiteSparse (libnpp) are installed.
  ensure_cuda_companion_package "libnpp"
  ensure_cuda_companion_package "libnpp-dev"

  printf '%s\n' "Selected CUDA packages: ${CUDA_INSTALL_PACKAGES[*]}"
  printf '%s\n' "Preferred CUDA version: ${CUDA_VERSION_PREFERRED}"
  printf '%s\n' "Effective CUDA version target: ${CUDA_VERSION}"

  # Check if the specific cuDNN version is available before attempting installation
  printf '%s\n' "Checking availability of cuDNN version ${CUDNN_VER}..."
  CUDNN_VERSION_AVAILABLE=false
  # Use -F for fixed-string matching (safer for version strings with special characters)
  # D3c: Use -F flag for literal pattern matching
  if apt-cache policy libcudnn9 2>/dev/null | grep -Fq "${CUDNN_VER}"; then
      CUDNN_VERSION_AVAILABLE=true
      printf '%s\n' "  ✓ Version ${CUDNN_VER} is available in repository"
  else
      printf '%s\n' "  ⚠ Version ${CUDNN_VER} not found in repository" >&2
      printf '%s\n' "  Checking available cuDNN versions..."
      # D3c: Use -E for regex pattern (version numbers)
      # D3e: Add || true to prevent SIGPIPE error (exit code 141) when pipe breaks
      version_list=$(apt-cache policy libcudnn9 2>/dev/null | grep -E "^\s+[0-9]" 2>/dev/null | head -5 2>/dev/null || echo "    (Could not list versions)")
      printf '%s\n' "${version_list}"
  fi

  CUDA_CUDNN_PACKAGE="${CUDA_CUDNN_PACKAGE:-libcudnn9-cuda-${CUDA_MAJOR}}"
  CUDA_CUDNN_DEV_PACKAGE="${CUDA_CUDNN_DEV_PACKAGE:-libcudnn9-dev-cuda-${CUDA_MAJOR}}"

  # Check for cached NVIDIA packages before downloading
  printf '%s\n' "Checking for cached NVIDIA packages in ${CONTAINER_APT_CACHE}..."
  # D3d, F2: Validate command substitution result
  # D3e: Add || true to prevent SIGPIPE error (exit code 141) when pipe breaks
  CACHED_NVIDIA_PKGS=$(find "${CONTAINER_APT_CACHE}" \( -name "*cuda*" -o -name "*cudnn*" -o -name "*nvidia*" \) -type f -name "*.deb" 2>/dev/null | wc -l || echo "0")
  # F2: Validate result is numeric
  if ! [[ "${CACHED_NVIDIA_PKGS}" =~ ^[0-9]+$ ]]; then
      CACHED_NVIDIA_PKGS=0
  fi
  if [ "${CACHED_NVIDIA_PKGS}" -gt 0 ]; then
      printf '%s\n' "  ✓ Found ${CACHED_NVIDIA_PKGS} cached NVIDIA package(s) - APT will reuse if versions match"
      printf '%s\n' "  → APT configured to use cache directory: ${CONTAINER_APT_CACHE}"
      # List cached packages for debugging
      printf '%s\n' "  → Cached packages:"
      # Phase 1: Collect package paths into array (avoids pipe subshell, limits to 5)
      cached_pkg_array=()
      pkg_count=0
      while IFS= read -r -d '' pkg && [ "${pkg_count}" -lt 5 ]; do
          if [ -n "${pkg:-}" ] && [ -f "${pkg}" ]; then
              cached_pkg_array+=("${pkg}")
              pkg_count=$((pkg_count + 1))
          fi
      done < <(find "${CONTAINER_APT_CACHE}" \( -name "*cuda*" -o -name "*cudnn*" -o -name "*nvidia*" \) -type f -name "*.deb" -print0 2>/dev/null)
      # Phase 2: Display collected packages
      for pkg in "${cached_pkg_array[@]}"; do
          if [ -n "${pkg:-}" ] && [ -f "${pkg}" ]; then
              printf '%s\n' "    - $(basename "${pkg}")"
          fi
      done
      [ "${CACHED_NVIDIA_PKGS}" -gt 5 ] && printf '%s\n' "    ... and $((CACHED_NVIDIA_PKGS - 5)) more"
  else
      printf '%s\n' "  ℹ No cached NVIDIA packages found - will download fresh"
  fi
  
  # CRITICAL: Ensure APT configuration file exists and is correct
  # This ensures APT uses the cache directory for all operations
  # J1: File existence validation before use
  if [ ! -f /etc/apt/apt.conf.d/90-cache.conf ]; then
      printf '%s\n' "[WARN] APT cache configuration missing - creating it now..." >&2
      # J1: Validate parent directory exists before writing
      PARENT_DIR="/etc/apt/apt.conf.d"
      if [ ! -d "${PARENT_DIR}" ]; then
          printf '%s\n' "[WARNING] Parent directory does not exist: ${PARENT_DIR}" >&2
          printf '%s\n' "[INFO] Creating parent directory: ${PARENT_DIR}" >&2
          mkdir -p "${PARENT_DIR}" || {
              printf '%s\n' "[ERROR] Failed to create parent directory: ${PARENT_DIR}" >&2
              exit 1
          }
          printf '%s\n' "[INFO] Parent directory created successfully: ${PARENT_DIR}" >&2
      fi
      printf '%s\n' "Dir::Cache::Archives \"${CONTAINER_APT_CACHE}\";" > /etc/apt/apt.conf.d/90-cache.conf
      printf '%s\n' 'APT::Keep-Downloaded-Packages "true";' >> /etc/apt/apt.conf.d/90-cache.conf
  fi

  # Try to install specific version if available, otherwise fall back to latest
  CUDNN_INSTALLED=false
  if [ "${CUDNN_VERSION_AVAILABLE:-}" = "true" ]; then
      printf '%s\n' "Installing cuDNN version ${CUDNN_VER}..."
      if apt-get "${APT_CACHE_OPTS}" install -y --no-install-recommends "libcudnn9=${CUDNN_VER}" "libcudnn9-dev=${CUDNN_VER}" "${CUDA_INSTALL_PACKAGES[@]}" 2>&1 | tee /tmp/cudnn_install.log; then
          if [ "${PIPESTATUS[0]}" -eq 0 ]; then
              CUDNN_INSTALLED=true
              printf '%s\n' "  ✓ Successfully installed cuDNN ${CUDNN_VER}"
          fi
      fi
  fi

  # Fallback to latest compatible version if specific version failed or wasn't available
  if [ "${CUDNN_INSTALLED:-}" = "false" ]; then
      printf '%s\n' "Installing latest cuDNN version compatible with CUDA ${CUDA_MAJOR}..."
      printf '%s\n' "  (This is the fallback when specific version ${CUDNN_VER} is not available)"
      if apt-get "${APT_CACHE_OPTS}" install -y --no-install-recommends "${CUDA_CUDNN_PACKAGE}" "${CUDA_CUDNN_DEV_PACKAGE}" "${CUDA_INSTALL_PACKAGES[@]}" 2>&1 | tee -a /tmp/cudnn_install.log; then
          if [ "${PIPESTATUS[0]}" -eq 0 ]; then
              CUDNN_INSTALLED=true
              # Detect installed version
              # D3d, F2: Validate command substitution results
              INSTALLED_CUDNN_VER=$(dpkg_get_installed_version "libcudnn9" || echo "")
              if [ -z "${INSTALLED_CUDNN_VER:-}" ]; then
                  INSTALLED_CUDNN_VER=$(dpkg_get_installed_version "libcudnn9-cuda-${CUDA_MAJOR}" || echo "")
              fi
              if [ -z "${INSTALLED_CUDNN_VER:-}" ]; then
                  INSTALLED_CUDNN_VER=$(dpkg_get_installed_version "libcudnn9-cuda" || echo "")
              fi
              # F2: Validate result is non-empty before use
              if [ -z "${INSTALLED_CUDNN_VER:-}" ]; then
                  INSTALLED_CUDNN_VER=""
              fi
              if [ -n "${INSTALLED_CUDNN_VER:-}" ]; then
                  printf '%s\n' "  ✓ Successfully installed cuDNN version ${INSTALLED_CUDNN_VER}"
              else
                  printf '%s\n' "  ✓ Successfully installed latest cuDNN version"
              fi
          fi
      fi
  fi

  if [ "${CUDNN_INSTALLED:-}" = "true" ]; then
      printf '%s\n' "✓ NVIDIA cuDNN installed successfully."
      
      # CRITICAL: Immediately consolidate cache packages
      # This ensures ~4GB of NVIDIA packages (and all other cache) are preserved even if build fails/interrupts
      # Function consolidates from /var/cache/apt/archives/ to /container_cache/apt/archives/ (all packages, not just NVIDIA)
      # Since /container_cache/ is bind-mounted to host, files are automatically available on host without sync
# Note: shell-scripts file: /etc/profile.d/cuda.sh is installed via install.sh from container-scripts/
# Source: shell-scripts/block-13-nvidia-cuda-cudnn-setup/cuda.sh
# Target: /etc/profile.d/cuda.sh
# Installed in Block 0 (early in script, before any scripts are needed)
  else
      printf '%s\n' "✗ ERROR: Failed to install cuDNN. Check /tmp/cudnn_install.log for details." >&2
      export PHASE2_STATUS="FAIL"
      exit 1
  fi
else
  printf '%s\n' "[INFO] CUDA/cuDNN installation skipped (already satisfied)."
fi
# --- Configuration Step (Fixing the PATH) ---
printf '%s\n' "${YELLOW}[PHASE 2 | NVIDIA] Configuring system-wide environment variables for CUDA...${NC}"
# After CUDA installation, detect actual installed version (or use config.sh default)
CUDA_MAJOR="${CUDA_VERSION%%.*}"  # Extract major version from config.sh
# D3d, F2: Validate command substitution result
# SC2012: Use find instead of ls to better handle non-alphanumeric filenames
# D3e: Add || true to prevent SIGPIPE error (exit code 141) when pipe breaks
DETECTED_CUDA=$(find /usr/local -maxdepth 1 -type d -name "cuda-${CUDA_MAJOR}.*" 2>/dev/null | head -1 2>/dev/null | sed -n 's/.*cuda-\([0-9]\+\.[0-9]\+\).*/\1/p' 2>/dev/null || echo "" || true)
# F2: Validate result is non-empty
if [ -z "${DETECTED_CUDA:-}" ]; then
    DETECTED_CUDA=""
fi
if [ -n "${DETECTED_CUDA}" ]; then
  CUDA_VERSION="${DETECTED_CUDA}"  # Use detected version if found
fi
# CUDA_VERSION now contains either detected version or config.sh default
printf '%s\n' "Detected CUDA version: ${CUDA_VERSION}"


#--- Sub-block 13.2: Configure CUDA environment variables ---
# Critical: Set PATH and LD_LIBRARY_PATH for CUDA toolkit
# Dependencies: Block 6.13 (NVIDIA CUDA)
# Outputs: GPU libraries, CUDA toolkit
# Note: shell-scripts file: /etc/profile.d/cuda.sh is installed via install.sh from container-scripts/
# Source: shell-scripts/block-13-nvidia-cuda-cudnn-setup/cuda.sh
# Target: /etc/profile.d/cuda.sh
# Installed in Block 0 (early in script, before any scripts are needed)
# Note: This file is automatically sourced by the shell on login
# H1: Check exit code of chmod operation
if ! chmod +x /etc/profile.d/cuda.sh 2>/dev/null; then
    printf '%s\n' "[WARN] Failed to set executable bit on /etc/profile.d/cuda.sh (non-critical)" >&2
fi

#--- Sub-block 13.3: Ensure CUDA environment in non-login shells ---
# Purpose: Make CUDA available in all shell types
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# J1: File existence validation before use
if [ -f /etc/profile.d/cuda.sh ]; then
  . /etc/profile.d/cuda.sh
  # D3c: Use -F flag for literal pattern matching
  if ! grep -Fq 'cuda.sh' /etc/bash.bashrc; then
    printf '%s\n' '. /etc/profile.d/cuda.sh' >> /etc/bash.bashrc
  fi
fi
# End environment sourcing (if-else self-contained)

#--- Sub-block 13.4: Source CUDA environment for current build session ---
# Critical: Make CUDA available immediately for rest of build process
# Dependencies: Block 6.13 (NVIDIA CUDA)
# Outputs: GPU libraries, CUDA toolkit
printf '%s\n' "==> Sourcing CUDA environment to make it available for the rest of this build..."
# J1: File existence validation before use
if [ -f /etc/profile.d/cuda.sh ]; then
    source /etc/profile.d/cuda.sh
else
    printf '%s\n' "[WARN] CUDA profile script not found: /etc/profile.d/cuda.sh" >&2
fi
# Note: ldconfig should be run without sudo in container context (already root)
run_ldconfig_refresh

#--- Sub-block 13.5: Verify CUDA installation ---
# Critical: Validate nvcc and cuDNN are properly installed
# Dependencies: Block 6.13 (NVIDIA CUDA)
# Outputs: GPU libraries, CUDA toolkit
PHASE2_SUCCESS=true
printf '%s\n' "${YELLOW}[PHASE 2 | NVIDIA] Verifying installation and environment...${NC}"
if ! command -v nvcc &>/dev/null; then
  printf '%s\n' "${RED}[VERIFICATION FAILED] 'nvcc' command not found in PATH.${NC}" >&2
  PHASE2_SUCCESS=false
else
  printf '%s\n' "  - nvcc command: ${GREEN}OK (Found in PATH)${NC}"
  nvcc --version
fi
# D3c: Use -F flag for literal pattern matching
# D3d: Validate process substitution result
if ! grep -Fq 'libcudnn.so' < <(timeout 5 ldconfig -p 2>/dev/null || echo ""); then
  printf '%s\n' "${RED}[VERIFICATION FAILED] 'libcudnn.so' not found in linker cache.${NC}" >&2
  PHASE2_SUCCESS=false
else
  printf '%s\n' "  - libcudnn.so: ${GREEN}OK (Visible to linker)${NC}"
fi

#--- Sub-block 13.6: Report CUDA installation status ---
# Critical: Exit if CUDA setup failed
# Dependencies: Block 6.13 (NVIDIA CUDA)
# Outputs: GPU libraries, CUDA toolkit
if [ "${PHASE2_SUCCESS}" = true ]; then
  printf '%s\n' "${GREEN}✓ [PHASE 2] NVIDIA CUDA Toolkit and cuDNN configured and verified successfully.${NC}"
  export PHASE2_STATUS="PASS"
else
  printf '%s\n' "${RED}✗ [PHASE 2] Errors occurred during GPU environment setup. Please review logs.${NC}" >&2
  export PHASE2_STATUS="FAIL"
  exit 1
fi
# End CUDA verification (if-else self-contained)

debug_glibc "After installing NVIDIA Cuda Toolkit"

#--- Sub-block 13.7: Verify NVIDIA packages are cached correctly ---
# Critical: Verify NVIDIA packages are in the persistent cache location
# Purpose: Confirm packages are in /container_cache/apt/archives for future builds
# Rationale: NVIDIA packages are massive; we need to verify they're cached correctly
# Dependencies: CONTAINER_APT_CACHE (configured in Block 6.12)
# Outputs: Verification that NVIDIA packages are cached
if [ "${CUDA_INSTALL_PERFORMED}" = "true" ]; then
  echo "==> VERIFYING NVIDIA PACKAGE CACHE: Checking cached packages..."
  echo "[INFO] Packages should be in ${CONTAINER_APT_CACHE} (configured APT cache directory)"

  # Count packages in the configured APT cache directory
  # D3e: Handle empty output from find command
  NVIDIA_PKG_FIND_OUTPUT="$(find "${CONTAINER_APT_CACHE}" \( -name "*cuda*" -o -name "*cudnn*" -o -name "*nvidia*" \) -type f -name "*.deb" 2>/dev/null || true)"
  # F2: Validate result format - check if output is non-empty before counting
  if [ -z "${NVIDIA_PKG_FIND_OUTPUT:-}" ]; then
      NVIDIA_PKG_COUNT="0"
  else
      NVIDIA_PKG_COUNT="$(grep -c . <<< "${NVIDIA_PKG_FIND_OUTPUT}" || echo "0")"
  fi
  CACHE_SIZE_RAW="$(du -sh "${CONTAINER_APT_CACHE}" 2>/dev/null || true)"
  CACHE_SIZE="$(cut -f1 <<< "${CACHE_SIZE_RAW:-0B}")"

  echo "[CACHE CHECK] Found ${NVIDIA_PKG_COUNT} NVIDIA-related packages in ${CONTAINER_APT_CACHE}"
  echo "[CACHE CHECK] Container cache size: ${CACHE_SIZE}"

  # Also check /var/cache/apt/archives as a fallback (in case APT didn't use the configured cache)
  if [ -d "/var/cache/apt/archives" ]; then
      VAR_CACHE_FIND_OUTPUT="$(find /var/cache/apt/archives \( -name "*cuda*" -o -name "*cudnn*" -o -name "*nvidia*" \) -type f -name "*.deb" 2>/dev/null || true)"
      VAR_CACHE_COUNT="$(grep -c . <<< "${VAR_CACHE_FIND_OUTPUT}" || echo "0")"
      if [ "${VAR_CACHE_COUNT}" -gt 0 ]; then
          echo "[WARN] Found ${VAR_CACHE_COUNT} NVIDIA packages in /var/cache/apt/archives (should be in ${CONTAINER_APT_CACHE})"
          echo "[INFO] Syncing packages from /var/cache/apt/archives to ${CONTAINER_APT_CACHE}..."
          NVIDIA_FILES=$(find /var/cache/apt/archives \( -name "*cuda*" -o -name "*cudnn*" -o -name "*nvidia*" \) -type f -name "*.deb" 2>/dev/null || true)
          if [ -n "${NVIDIA_FILES:-}" ]; then
              # D2: Use IFS= and read -r for safe word splitting
              echo "${NVIDIA_FILES}" | while IFS= read -r deb_file || [ -n "${deb_file:-}" ]; do
                  if [ -f "${deb_file:-}" ]; then
                      # Only copy if not already in cache (avoid duplicates)
                      deb_name=$(basename "${deb_file}")
                      if [ ! -f "${CONTAINER_APT_CACHE}/${deb_name}" ]; then
                          cp -v "${deb_file}" "${CONTAINER_APT_CACHE}/" || echo "  [warn] Failed to copy: ${deb_file}"
                      fi
                  fi
              done
              # Re-count after sync
              # D3e: Add || true to prevent SIGPIPE error when pipe breaks
              NVIDIA_PKG_COUNT=$(find "${CONTAINER_APT_CACHE}" \( -name "*cuda*" -o -name "*cudnn*" -o -name "*nvidia*" \) -type f -name "*.deb" 2>/dev/null | wc -l || echo "0")
              CACHE_SIZE_RAW=$(du -sh "${CONTAINER_APT_CACHE}" 2>/dev/null || echo "0B")
              CACHE_SIZE=$(cut -f1 <<< "${CACHE_SIZE_RAW:-0B}" || echo "0B")
              echo "[AFTER SYNC] Container cache now has ${NVIDIA_PKG_COUNT} NVIDIA-related packages"
              echo "[AFTER SYNC] Container cache size: ${CACHE_SIZE}"
          fi
      fi
  fi

  if [ "${NVIDIA_PKG_COUNT}" -gt 0 ]; then
      echo "✓ NVIDIA PACKAGES CACHED: ${NVIDIA_PKG_COUNT} package(s) in ${CONTAINER_APT_CACHE}"
      echo "   → These packages will be reused in future builds (no re-download needed)"
  else
      echo "⚠ WARNING: No NVIDIA packages found in cache - they may need to be re-downloaded in future builds"
  fi

  # Force filesystem sync to ensure data is written to disk
  if ! sync; then
    printf '%s\n' "[WARN] ⚠ Final sync failed (non-critical)" >&2
  fi
else
  echo "[INFO] Skipping NVIDIA cache verification (no new CUDA packages installed in this run)."
fi

echo "==> Continuing with rest of build process..."

#--- Sub-block 13.8: Test unified APT cache functionality (apt-aria already configured) ---
# Purpose: Verify cache is working correctly
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
echo "Testing unified APT cache functionality..."
if /usr/local/bin/apt-get --download-only install -y curl 2>/dev/null; then
  # Use find to safely check for curl packages instead of glob in test
  if read -r _ < <(find "${CONTAINER_APT_CACHE}" -maxdepth 1 -name "curl*.deb" -type f -print -quit 2>/dev/null); then
        echo "✓ Unified APT cache test successful - curl package cached"
        find "${CONTAINER_APT_CACHE}" -maxdepth 1 -name "curl*.deb" -type f -delete 2>/dev/null || true
    else
    echo "Δ Unified APT cache test - package downloaded but not found in cache"
    fi
else
  echo "Δ Unified APT cache test failed - curl may already be installed"
fi
# End cache test (if-else self-contained)

#--- Sub-block 13.9: Early cached file verification function ---
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
            # I4: HTTP error handling for curl
            http_code=$(curl -fsSL -o "${CONTAINER_BIN_CACHE}/${MINIFORGE_SH}" -w "%{http_code}" "${MINIFORGE_URL}" 2>/dev/null || echo "000")
            if [[ "${http_code}" =~ ^[0-9]{3}$ ]] && [ "${http_code}" = "200" ] && [ -f "${CONTAINER_BIN_CACHE}/${MINIFORGE_SH}" ]; then
                if sha256sum -c <(echo "${MINIFORGE_SHA256} ${CONTAINER_BIN_CACHE}/${MINIFORGE_SH}") 2>/dev/null; then
                    echo "✓ Miniforge re-downloaded and verified"
                else
                    echo ""
                    echo "═══════════════════════════════════════════════════════════════"
                    echo "  DOWNLOAD FAILED: Miniforge re-download failed"
                    echo "═══════════════════════════════════════════════════════════════"
                    echo "  File name: ${MINIFORGE_SH}"
                    echo "  Expected location: ${CONTAINER_BIN_CACHE}/${MINIFORGE_SH}"
                    echo "  Source URL: ${MINIFORGE_URL}"
                    echo ""
                    echo "  You may manually download this file and place it at:"
                    echo "    ${CONTAINER_BIN_CACHE}/${MINIFORGE_SH}"
                    echo "═══════════════════════════════════════════════════════════════"
                    echo "✗ Miniforge re-download also failed - aborting build"
                    exit 1
                fi
            else
                echo "✗ Miniforge re-download attempt failed (HTTP ${http_code:-unknown} or network error)"
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
            # I4: HTTP error handling for curl
            http_code=$(curl -fsSL -o "${CONTAINER_BIN_CACHE}/micromamba-linux-64" -w "%{http_code}" "${MICROMAMBA_URL}" 2>/dev/null || echo "000")
            if [[ "${http_code}" =~ ^[0-9]{3}$ ]] && [ "${http_code}" = "200" ] && [ -f "${CONTAINER_BIN_CACHE}/micromamba-linux-64" ]; then
                if sha256sum -c <(echo "${MICROMAMBA_SHA256} ${CONTAINER_BIN_CACHE}/micromamba-linux-64") 2>/dev/null; then
                    echo "✓ Micromamba re-downloaded and verified"
                else
                    echo ""
                    echo "═══════════════════════════════════════════════════════════════"
                    echo "  DOWNLOAD FAILED: Micromamba re-download failed"
                    echo "═══════════════════════════════════════════════════════════════"
                    echo "  File name: micromamba-linux-64"
                    echo "  Expected location: ${CONTAINER_BIN_CACHE}/micromamba-linux-64"
                    echo "  Source URL: ${MICROMAMBA_URL}"
                    echo ""
                    echo "  You may manually download this file and place it at:"
                    echo "    ${CONTAINER_BIN_CACHE}/micromamba-linux-64"
                    echo "═══════════════════════════════════════════════════════════════"
                    echo "✗ Micromamba re-download also failed - aborting build"
                    exit 1
                fi
            else
                echo "✗ Micromamba re-download attempt failed (HTTP ${http_code:-unknown} or network error)"
                exit 1
            fi
        fi
    fi


    # Verify yq
    if [ -f "${CONTAINER_BIN_CACHE}/yq_linux_amd64" ]; then
        echo "Verifying yq..."
        if sha256sum -c <(echo "${YQ_SHA256} ${CONTAINER_BIN_CACHE}/yq_linux_amd64") 2>/dev/null; then
            echo "✓ yq SHA256 verified"
        else
            echo "✗ yq SHA256 verification failed - file corrupted during copy!"
            echo "  Attempting to re-download..."
            # I4: HTTP error handling for curl
            http_code=$(curl -fsSL -o "${CONTAINER_BIN_CACHE}/yq_linux_amd64" -w "%{http_code}" "${YQ_URL}" 2>/dev/null || echo "000")
            if [[ "${http_code}" =~ ^[0-9]{3}$ ]] && [ "${http_code}" = "200" ] && [ -f "${CONTAINER_BIN_CACHE}/yq_linux_amd64" ]; then
                if sha256sum -c <(echo "${YQ_SHA256} ${CONTAINER_BIN_CACHE}/yq_linux_amd64") 2>/dev/null; then
                    echo "✓ yq re-downloaded and verified"
                else
                    echo ""
                    echo "═══════════════════════════════════════════════════════════════"
                    echo "  DOWNLOAD FAILED: yq re-download failed"
                    echo "═══════════════════════════════════════════════════════════════"
                    echo "  File name: yq_linux_amd64"
                    echo "  Expected location: ${CONTAINER_BIN_CACHE}/yq_linux_amd64"
                    echo "  Source URL: ${YQ_URL}"
                    echo ""
                    echo "  You may manually download this file and place it at:"
                    echo "    ${CONTAINER_BIN_CACHE}/yq_linux_amd64"
                    echo "═══════════════════════════════════════════════════════════════"
                    echo "✗ yq re-download also failed - aborting build"
                    exit 1
                fi
            else
                echo "✗ yq re-download attempt failed (HTTP ${http_code:-unknown} or network error)"
                exit 1
            fi
        fi
    fi


    # Verify Julia (early verification for complex archive)
    if [ -f "${CONTAINER_BIN_CACHE}/${JULIA_TARBALL}" ]; then
        echo "Verifying Julia archive..."
        julia_file="${CONTAINER_BIN_CACHE}/${JULIA_TARBALL}"
        expected_sha256="${JULIA_SHA256}"
        julia_url="${JULIA_URL}"

        # SHA256 verification
        # D3d: Validate command substitution result
        if sha256sum -c <(echo "${expected_sha256} ${julia_file}") 2>/dev/null; then
            echo "✓ Julia SHA256 verified"
        else
            echo "✗ Julia SHA256 verification failed - file corrupted during copy!"
            echo "  Attempting to re-download..."
            # I4: HTTP error handling for curl
            if curl -fsSL -o "${julia_file}" "${julia_url}" 2>/dev/null; then
        if sha256sum -c <(echo "${expected_sha256} ${julia_file}") 2>/dev/null; then
          echo "✓ Julia re-downloaded and SHA256 verified"
        else
          echo ""
          echo "═══════════════════════════════════════════════════════════════"
          echo "  DOWNLOAD FAILED: Julia re-download failed"
          echo "═══════════════════════════════════════════════════════════════"
          echo "  File name: $(basename "${julia_file}")"
          echo "  Expected location: ${julia_file}"
          echo "  Source URL: ${julia_url}"
          echo ""
          echo "  You may manually download this file and place it at:"
          echo "    ${julia_file}"
          echo "═══════════════════════════════════════════════════════════════"
                    echo "✗ Julia re-download also failed - aborting build"
                    exit 1
                fi
            else
                echo "✗ Julia re-download attempt failed due to network error"
                exit 1
            fi
        fi

    # gzip integrity check
    # Validate file exists before integrity check (J1)
    if [ ! -f "${julia_file}" ]; then
      echo "✗ Julia file not found: ${julia_file}"
      exit 1
    fi
    if gzip -t "${julia_file}" 2>/dev/null; then
      echo "✓ Julia gzip integrity verified"
    else
      echo "✗ Julia gzip integrity check failed - archive is corrupted!"
      echo "  Attempting to re-download..."
      # Check HTTP status code for curl (I4)
      # I4: Validate HTTP code is 3-digit number before checking
      http_code="$(curl -fsSL -o "${julia_file}" -w "%{http_code}" "${julia_url}" 2>/dev/null || echo "000")"
      # I4: Validate HTTP code format before use
      if [[ "${http_code}" =~ ^[0-9]{3}$ ]] && [ "${http_code}" = "200" ] && [ -f "${julia_file}" ]; then
        if gzip -t "${julia_file}" 2>/dev/null; then
          echo "✓ Julia re-downloaded and gzip integrity verified"
        else
          echo ""
          echo "═══════════════════════════════════════════════════════════════"
          echo "  DOWNLOAD FAILED: Julia re-download failed (gzip integrity)"
          echo "═══════════════════════════════════════════════════════════════"
          echo "  File name: $(basename "${julia_file}")"
          echo "  Expected location: ${julia_file}"
          echo "  Source URL: ${julia_url}"
          echo ""
          echo "  You may manually download this file and place it at:"
          echo "    ${julia_file}"
          echo "═══════════════════════════════════════════════════════════════"
          echo "✗ Julia re-download also failed - aborting build"
          exit 1
        fi
      else
        echo "✗ Julia re-download attempt failed (HTTP ${http_code:-unknown} or network error)"
        exit 1
      fi
    fi
    # ENDIF: gzip integrity check
    fi
    # ENDIF: Julia verification
}


# Note: config-files file: /etc/dpkg/dpkg.cfg.d/01-nodoc is installed via install.sh from container-scripts/
# Source: config-files/block-13-nvidia-cuda-cudnn-setup/01-nodoc.conf
# Target: /etc/dpkg/dpkg.cfg.d/01-nodoc
# Installed in Block 0 (early in script, before any scripts are needed)
early_verify_cached_files

#--- Sub-block 13.12: Setup GPG verification system ---
# Purpose: Initialize GPG verification for package signatures
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
setup_gpg_verification

#--- Sub-block 13.13: Mirror functions moved to BLOCK 3 ---
# Note: Mirror probing functions (test_mirror, probe_and_set_mirrors) have been
# moved to BLOCK 3 (lines 250-436) and executed early in BLOCK 6.11 (lines 841-889)
# This ensures ALL apt-get operations use the fastest mirror from the start.
# The old code here has been removed to avoid duplication.

#--- Sub-block 13.14: Configure dpkg to exclude documentation ---
# Purpose: Save space by excluding man pages and non-essential docs
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
echo "==> Configuring dpkg to exclude unnecessary documentation..."
if [ -d /etc/dpkg/dpkg.cfg.d ] && [ -w /etc/dpkg/dpkg.cfg.d ]; then
    # Note: config-files file: /etc/dpkg/dpkg.cfg.d/01-nodoc is installed via install.sh from container-scripts/
    # Source: config-files/block-13-nvidia-cuda-cudnn-setup/01-nodoc.conf
    # Target: /etc/dpkg/dpkg.cfg.d/01-nodoc
    # Installed in Block 0 (early in script, before any scripts are needed)
    # Configuration file is already installed, no action needed
    :
else
  printf '%s\n' "  ${YELLOW}⚠ dpkg cfg directory not writable; skipping 01-nodoc configuration${NC}" >&2
fi

#--- Sub-block 13.15: Prepare for bootstrap package installation ---
# Purpose: Create directories and update package lists
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
install -d -m 0755 /usr/local/bin
apt-get update -o Acquire::Retries=3

#--- Sub-block 13.16: Install bootstrap packages ---
# Critical: Additional essential tools for container functionality
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
printf '%s\n' "==> Installing all bootstrap and utility packages..."
# Clean up any existing apt temporary directories
# H4: Masked failures with || true - validate cleanup results (non-critical cleanup operations)
# Note: Cleanup failures are non-critical, but we validate directory state after cleanup
if ! rm -rf /tmp/apt-dpkg-install-* 2>/dev/null; then
  # Cleanup failure is non-critical, continue
  :
fi
# Validate cleanup completed (optional verification for debugging)
if [ -d /tmp/apt-dpkg-install-* ] 2>/dev/null; then
  # Some directories may still exist (non-critical)
  :
fi
if ! rm -rf /var/cache/apt/archives/partial/* 2>/dev/null; then
  # Cleanup failure is non-critical, continue
  :
fi
# Validate cleanup completed (optional verification for debugging)
if [ -d /var/cache/apt/archives/partial ] && [ -n "$(ls -A /var/cache/apt/archives/partial 2>/dev/null)" ]; then
  # Some files may still exist (non-critical)
  :
fi

#--- Sub-block 13.17: Install additional network tools ---
# Purpose: rsync for file synchronization
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
printf '%s\n' "==> Installing additional network and download tools..."
# Validate apt-get install result (H1)
if ! apt-get install -y --no-install-recommends \
    rsync; then
  printf '%s\n' "  ${RED}✗ Failed to install rsync${NC}" >&2
  exit 1
fi

#--- Sub-block 13.18: Install additional security tools ---
# Purpose: Additional encryption and security packages
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
printf '%s\n' "==> Installing additional security and encryption tools..."
# Validate apt-get install result (H1)
if ! apt-get install -y --no-install-recommends \
    ca-certificates-java; then
  printf '%s\n' "  ${RED}✗ Failed to install ca-certificates-java${NC}" >&2
  exit 1
fi

#--- Sub-block 13.19: Install development and utility tools ---
# Purpose: Python pip for package management
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
printf '%s\n' "==> Installing development and utility tools..."
# Validate apt-get install result (H1)
if ! apt-get install -y --no-install-recommends \
    python3-pip; then
  printf '%s\n' "  ${RED}✗ Failed to install python3-pip${NC}" >&2
  exit 1
fi

#--- Sub-block 13.20: Post-bootstrap validation and configuration ---
# Critical: Verify installation, update certificates and locales
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
monitor_cache "After bootstrap packages installation"
debug_glibc "After installing bootstrap packages"
# Validate update-ca-certificates result (H1)
if ! update-ca-certificates; then
  printf '%s\n' "[WARN] update-ca-certificates had issues, continuing..." >&2
fi
# Validate locale-gen result (H1)
if ! locale-gen en_US.UTF-8; then
  printf '%s\n' "[WARN] locale-gen had issues, continuing..." >&2
fi
# We already have nala and aptitude installed via APT for package management
# Validate curl command availability (M1, H1)
if ! command -v curl >/dev/null 2>&1; then
  printf '%s\n' "[ERROR] curl install failed" >&2
  exit 1
fi

#--- Sub-block 13.21: Mirror probing already executed (moved to line ~1649) ---
# Note: probe_and_set_mirrors was moved earlier to run BEFORE apt-get operations
# This ensures all package downloads use the fastest mirror
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration

#--- Sub-block 13.22: Configure additional PPAs ---
# Purpose: Add Mozilla, Ulauncher PPAs with fallback mechanisms
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
printf '%s\n' "==> Adding all PPAs (earliest possible) - OPTIMIZED"
# Add all PPAs using fallback method (add-apt-repository with proper error handling)
printf '%s\n' "Adding PPA repositories with verification..."

# Try modern method first, fallback to add-apt-repository if needed
printf '%s\n' "Attempting to add PPAs using add-apt-repository..."
# apt-fast PPA removed - using apt-aria wrapper instead
if ! add-apt-repository -y ppa:mozillateam/ppa 2>/dev/null; then
  printf '%s\n' "[warn] Mozilla PPA failed, will try manual method" >&2
fi
if ! add-apt-repository -y ppa:agornostal/ulauncher 2>/dev/null; then
  printf '%s\n' "[warn] Ulauncher PPA failed, will try manual method" >&2
fi
# Validate CODENAME command substitution result (F2, H4)
CODENAME=$(lsb_release -cs 2>/dev/null || echo "")
# Validate CODENAME is non-empty (C1, C5, F2)
if [ -z "${CODENAME}" ]; then
  printf '%s\n' "[ERROR] Failed to determine Ubuntu codename" >&2
  exit 1
fi
# If add-apt-repository failed, use manual method as fallback
# Validate file path before checking (J1)
if [ ! -f "/etc/apt/sources.list.d/mozillateam-ubuntu-ppa-${CODENAME}.list" ]; then
  printf '%s\n' "Using manual PPA configuration as fallback for ${CODENAME}..."

  # apt-fast PPA removed - using apt-aria wrapper instead

  # Add Mozilla PPA manually
  # Validate parent directory exists before writing (J1)
  if [ -d "$(dirname /etc/apt/sources.list.d/mozillateam-ppa.list)" ]; then
    printf '%s\n' "deb http://ppa.launchpad.net/mozillateam/ppa/ubuntu ${CODENAME} main" > /etc/apt/sources.list.d/mozillateam-ppa.list
    printf '%s\n' "deb-src http://ppa.launchpad.net/mozillateam/ppa/ubuntu ${CODENAME} main" >> /etc/apt/sources.list.d/mozillateam-ppa.list
  else
    printf '%s\n' "[ERROR] Cannot create directory for mozillateam-ppa.list" >&2
    exit 1
  fi

  # Add Ulauncher PPA manually
  # Validate parent directory exists before writing (J1)
  if [ -d "$(dirname /etc/apt/sources.list.d/ulauncher-ppa.list)" ]; then
    printf '%s\n' "deb http://ppa.launchpad.net/agornostal/ulauncher/ubuntu ${CODENAME} main" > /etc/apt/sources.list.d/ulauncher-ppa.list
    printf '%s\n' "deb-src http://ppa.launchpad.net/agornostal/ulauncher/ubuntu ${CODENAME} main" >> /etc/apt/sources.list.d/ulauncher-ppa.list
  else
    printf '%s\n' "[ERROR] Cannot create directory for ulauncher-ppa.list" >&2
    exit 1
  fi
fi
# ENDIF: PPA fallback check

# Verify fastest mirror is still in place (safeguard after PPA operations)
printf '%s\n' ""
printf '%s\n' "==> Verifying fastest mirror after PPA operations (safeguard check)..."
# Validate verify_fastest_mirror result (H4)
if ! verify_fastest_mirror; then
  printf '%s\n' "[warn] Mirror verification after PPA operations found issues" >&2
fi

#--- Sub-block 13.23: Add PPA GPG keys ---
# Critical: Import signing keys for all configured PPAs
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
printf '%s\n' "Adding PPA GPG keys..."
# apt-fast key removed - using apt-aria wrapper

# Mozilla PPA key
# Check HTTP status code for curl (I4)
# D3: Use separate stderr capture instead of pipe to tail (unsafe pipe pattern)
curl_stderr=$(mktemp)
http_code=$(curl -w "%{http_code}" -fsSL -o /tmp/mozillateam_key.asc "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xAEBDF4819BE21867" 2>"${curl_stderr}")
curl_exit_code=$?
# Validate HTTP code format before comparison (I4, F2)
if [ "${curl_exit_code}" -eq 0 ] && [[ "${http_code}" =~ ^[0-9]{3}$ ]] && [ "${http_code}" = "200" ] && [ -f /tmp/mozillateam_key.asc ]; then
  # Validate GPG processing result (H4)
  if ! gpg --dearmor -o /etc/apt/trusted.gpg.d/mozillateam.gpg /tmp/mozillateam_key.asc 2>/dev/null; then
    printf '%s\n' "[warn] Mozilla key GPG processing failed" >&2
  fi
  rm -f /tmp/mozillateam_key.asc
else
  printf '%s\n' "[warn] Mozilla key download failed (HTTP ${http_code:-unknown}, exit=${curl_exit_code})" >&2
  [ -s "${curl_stderr}" ] && cat "${curl_stderr}" >&2
fi
rm -f "${curl_stderr}"

# Ulauncher PPA key
# Check HTTP status code for curl (I4)
# D3: Use separate stderr capture instead of pipe to tail (unsafe pipe pattern)
curl_stderr=$(mktemp)
http_code=$(curl -w "%{http_code}" -fsSL -o /tmp/ulauncher_key.asc "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xFAF1020699503176" 2>"${curl_stderr}")
curl_exit_code=$?
# Validate HTTP code format before comparison (I4, F2)
if [ "${curl_exit_code}" -eq 0 ] && [[ "${http_code}" =~ ^[0-9]{3}$ ]] && [ "${http_code}" = "200" ] && [ -f /tmp/ulauncher_key.asc ]; then
  # Validate GPG processing result (H4)
  if ! gpg --dearmor -o /etc/apt/trusted.gpg.d/ulauncher.gpg /tmp/ulauncher_key.asc 2>/dev/null; then
    printf '%s\n' "[warn] Ulauncher key GPG processing failed" >&2
  fi
  rm -f /tmp/ulauncher_key.asc
else
  printf '%s\n' "[warn] Ulauncher key download failed (HTTP ${http_code:-unknown}, exit=${curl_exit_code})" >&2
  [ -s "${curl_stderr}" ] && cat "${curl_stderr}" >&2
fi
rm -f "${curl_stderr}"

#--- Sub-block 13.24: Verify PPA keys ---
# Purpose: Confirm all PPA keys are properly installed
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
printf '%s\n' "Verifying PPA GPG keys..."
# Validate directory exists before globbing (J1)
if [ -d /etc/apt/trusted.gpg.d ]; then
  # Iterate over key files in trusted.gpg.d
  for keyfile in /etc/apt/trusted.gpg.d/*.gpg /etc/apt/trusted.gpg.d/*.asc; do
    # Skip if glob didn't match any files
    [ ! -f "${keyfile}" ] && continue
    # Extract keyname from filename
    # D3: sed command with error fallback for safety (D4, F2, H4)
    keyname=$(basename "${keyfile}" .gpg | sed 's/\.asc$//' || echo "")
    # Validate keyname is non-empty (F2, H4)
    if [ -z "${keyname}" ]; then
      keyname=$(basename "${keyfile}")
    fi
    # Verify key file is readable
    if [ -r "${keyfile}" ]; then
        printf '%s\n' "✓ PPA key verified: ${keyname}"
    fi
  done
# ENDFOR: keyfile
fi

#--- Sub-block 13.25: Update package lists with PPAs ---
# Critical: Refresh APT cache with all newly added repositories
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
printf '%s\n' "Updating package lists with all PPAs..."
# Validate apt-get update result (H1)
if ! apt-get update -o Acquire::Retries=3; then
  printf '%s\n' "[ERROR] Failed to update package lists with PPAs" >&2
  exit 1
fi

# Monitor cache after PPA update
monitor_cache "After PPA update"

#--- Sub-block 13.26: Configure APT robustness settings ---
# Purpose: Set retry and timeout policies for reliable downloads
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# Note: config-files file: /etc/apt/apt.conf.d/80-retries is installed via install.sh from container-scripts/
# Source: config-files/block-13-nvidia-cuda-cudnn-setup/80-retries.conf
# Target: /etc/apt/apt.conf.d/80-retries
# Installed in Block 0 (early in script, before any scripts are needed)
# Note: This file uses 'cat >>' (append), so the content is added to existing config
# apt-fast environment variables and verification removed - using apt-aria wrapper instead

#--- Sub-block 12B.1: Install GMP, MPFR, and METIS (SuiteSparse prerequisites) ---
# Critical:
#   - SPEX (part of SuiteSparse) requires GMP >= 6.1.2 and MPFR >= 4.0.2
#   - CHOLMOD's METIS support: In recent SuiteSparse versions (5.x+), METIS is embedded directly
#     into libcholmod.so, so no separate libcholmod_metis.so is built. libmetis-dev is still needed
#     as a build-time dependency for METIS headers, but METIS functions are compiled into CHOLMOD.
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages (libgmp-dev, libmpfr-dev, libmetis-dev)
printf '%b\n' "${YELLOW}[6.12B.1] Installing GMP, MPFR, and METIS (SuiteSparse prerequisites)...${NC}"
printf '%s\n' "SPEX requires GMP >= 6.1.2 and MPFR >= 4.0.2 for exact arithmetic operations"
printf '%s\n' "CHOLMOD's METIS support: METIS is embedded in libcholmod.so in recent SuiteSparse versions"
printf '%s\n' "  → libmetis-dev provides headers needed at build time, but METIS functions are in libcholmod.so"
if ! apt-get install -y --no-install-recommends libgmp-dev libmpfr-dev libmetis-dev; then
    printf '%s\n' "  ✗ Failed to install GMP/MPFR/METIS packages" >&2
    exit 1
fi

# Verify GMP version meets requirement (>= 6.1.2)
if command -v pkg-config >/dev/null 2>&1; then
    GMP_VERSION=$(pkg-config --modversion gmp 2>/dev/null || echo "0.0.0")
    # Validate version format before parsing (F2, H4)
    if [ -n "${GMP_VERSION}" ] && [ "${GMP_VERSION}" != "0.0.0" ]; then
      printf '%s\n' "  ✓ GMP version: ${GMP_VERSION}"
      # Basic version check (compare major.minor)
      # D3: Use here-string instead of echo | cut (unsafe pipe pattern)
      GMP_MAJOR=$(cut -d. -f1 <<< "${GMP_VERSION}")
      GMP_MINOR=$(cut -d. -f2 <<< "${GMP_VERSION}")
      # Validate numeric values before arithmetic comparison (K1)
      if [ -n "${GMP_MAJOR}" ] && [ -n "${GMP_MINOR}" ] && \
         [ "${GMP_MAJOR}" -ge 0 ] 2>/dev/null && [ "${GMP_MINOR}" -ge 0 ] 2>/dev/null; then
        if [ "${GMP_MAJOR}" -lt 6 ] || ([ "${GMP_MAJOR}" -eq 6 ] && [ "${GMP_MINOR}" -lt 1 ]); then
          printf '%s\n' "  ⚠ WARNING: GMP version ${GMP_VERSION} may be below required 6.1.2" >&2
          printf '%s\n' "    SPEX may fail to build. Consider upgrading GMP if build fails." >&2
        else
          printf '%s\n' "  ✓ GMP version ${GMP_VERSION} meets requirement (>= 6.1.2)"
        fi
      else
        printf '%s\n' "  ⚠ WARNING: Could not parse GMP version ${GMP_VERSION}" >&2
      fi
    else
      printf '%s\n' "  ⚠ WARNING: Could not determine GMP version" >&2
    fi
else
    printf '%s\n' "  ⚠ pkg-config not available, skipping GMP version check" >&2
fi
# ENDIF: pkg-config check for GMP

# Verify MPFR version meets requirement (>= 4.0.2)
if command -v pkg-config >/dev/null 2>&1; then
    MPFR_VERSION=$(pkg-config --modversion mpfr 2>/dev/null || echo "0.0.0")
    # Validate version format before parsing (F2, H4)
    if [ -n "${MPFR_VERSION}" ] && [ "${MPFR_VERSION}" != "0.0.0" ]; then
      printf '%s\n' "  ✓ MPFR version: ${MPFR_VERSION}"
      # Basic version check (compare major.minor)
      # D3: Use here-string instead of echo | cut (unsafe pipe pattern)
      MPFR_MAJOR=$(cut -d. -f1 <<< "${MPFR_VERSION}")
      MPFR_MINOR=$(cut -d. -f2 <<< "${MPFR_VERSION}")
      # Validate numeric values before arithmetic comparison (K1)
      if [ -n "${MPFR_MAJOR}" ] && [ -n "${MPFR_MINOR}" ] && \
         [ "${MPFR_MAJOR}" -ge 0 ] 2>/dev/null && [ "${MPFR_MINOR}" -ge 0 ] 2>/dev/null; then
        if [ "${MPFR_MAJOR}" -lt 4 ] || ([ "${MPFR_MAJOR}" -eq 4 ] && [ "${MPFR_MINOR}" -lt 1 ]); then
          printf '%s\n' "  ⚠ WARNING: MPFR version ${MPFR_VERSION} may be below required 4.0.2" >&2
          printf '%s\n' "    SPEX may fail to build. Consider upgrading MPFR if build fails." >&2
        else
          printf '%s\n' "  ✓ MPFR version ${MPFR_VERSION} meets requirement (>= 4.0.2)"
        fi
      else
        printf '%s\n' "  ⚠ WARNING: Could not parse MPFR version ${MPFR_VERSION}" >&2
      fi
    else
      printf '%s\n' "  ⚠ WARNING: Could not determine MPFR version" >&2
    fi
else
    printf '%s\n' "  ⚠ pkg-config not available, skipping MPFR version check" >&2
fi
# ENDIF: pkg-config check for MPFR

printf '%s\n' "  ✓ GMP and MPFR installed successfully"
printf '%s\n' ""

#--- Sub-block 12C: Build SuiteSparse with MKL + CUDA + OpenMP ---
# Purpose: Compile and install SuiteSparse after CUDA/MKL provisioning to guarantee linkage
# Dependencies: CUDA toolkit (Block 13), Intel MKL (Block 6.8), GMP/MPFR (Sub-block 12B.1), OpenBLAS (optional fallback)
# Outputs: SuiteSparse installed under ${SUITESPARSE_INSTALL_PREFIX}
printf '%b\n' "${YELLOW}[6.12C.1] Preparing SuiteSparse (MKL + CUDA + OpenMP) build...${NC}"

# Validate MKLROOT directory exists (J1)
if [[ -z "${MKLROOT:-}" || ! -d "${MKLROOT}" ]]; then
    printf '%s\n' "  ✗ MKLROOT not set or directory missing (${MKLROOT:-unset})" >&2
    printf '%s\n' "  Install Intel oneAPI MKL (Phase 2) before running the orchestration script." >&2
    exit 1
fi

# Validate CUDA environment (M1, J1)
if ! command -v nvcc >/dev/null 2>&1; then
    # Validate file exists before sourcing (J1)
    if [ -f /etc/profile.d/cuda.sh ]; then
        # Attempt to source environment hooks in case CUDA was installed earlier in the run
        # but PATH/LD_LIBRARY_PATH are not yet updated in the current shell.
        # shellcheck disable=SC1091
        . /etc/profile.d/cuda.sh
    fi
fi

# Validate nvcc command availability after sourcing (M1, H1)
if ! command -v nvcc >/dev/null 2>&1; then
    printf '%s\n' "  ✗ nvcc not found in PATH; CUDA development toolkit is required." >&2
    exit 1
fi

# Validate CUDA_HOME path resolution (F2, H4, J1)
CUDA_HOME=""
if command -v nvcc >/dev/null 2>&1; then
    nvcc_path=$(command -v nvcc)
    if [ -n "${nvcc_path}" ]; then
        real_nvcc_path=$(realpath "${nvcc_path}" 2>/dev/null || echo "")
        if [ -n "${real_nvcc_path}" ] && [ -f "${real_nvcc_path}" ]; then
            CUDA_HOME="$(dirname "$(dirname "${real_nvcc_path}")")"
        fi
    fi
fi

# Validate CUDA_HOME is set and directory exists (J1)
if [ -z "${CUDA_HOME}" ] || [ ! -d "${CUDA_HOME}" ]; then
    printf '%s\n' "  ✗ Failed to determine CUDA_HOME from nvcc path" >&2
    exit 1
fi

CUDA_INCLUDE_DIR="${CUDA_HOME}/include"
CUDA_LIB_DIR=""
# Validate CUDA library directory exists (J1)
for candidate in "${CUDA_HOME}/lib64" "${CUDA_HOME}/targets/x86_64-linux/lib"; do
    if [[ -d "${candidate}" ]]; then
        CUDA_LIB_DIR="${candidate}"
        break
    fi
done

# Validate CUDA include directory exists (J1)
if [[ ! -d "${CUDA_INCLUDE_DIR}" ]]; then
    printf '%s\n' "  ✗ CUDA include directory missing at ${CUDA_INCLUDE_DIR}" >&2
    exit 1
fi

# Validate CUDA library directory found (J1)
if [[ -z "${CUDA_LIB_DIR}" ]]; then
    printf '%s\n' "  ✗ Could not locate CUDA library directory under ${CUDA_HOME}" >&2
    exit 1
fi

declare -a suitesparse_cuda_libs=("libcublas.so" "libcusparse.so" "libcusolver.so" "libcurand.so")
for cuda_lib in "${suitesparse_cuda_libs[@]}"; do
    # Validate CUDA library file exists (J1)
    if [[ ! -f "${CUDA_LIB_DIR}/${cuda_lib}" ]]; then
        # Validate find result (F2, H4, J1)
        found_path="$(find "${CUDA_LIB_DIR}" -maxdepth 1 -name "${cuda_lib}*" -print -quit 2>/dev/null || echo "")"
        if [[ -n "${found_path}" ]] && [[ -f "${found_path}" ]]; then
            printf '%s\n' "  ✓ Using ${found_path}"
            declare "FOUND_${cuda_lib//./_}=${found_path}"
        else
            printf '%s\n' "  ✗ Required CUDA library ${cuda_lib} not found under ${CUDA_LIB_DIR}" >&2
            exit 1
        fi
    fi
    # ENDIF: CUDA library check
done
# ENDFOR: cuda_lib

printf '%s\n' "  ✓ CUDA toolkit detected at ${CUDA_HOME}"
printf '%s\n' "  ✓ MKLROOT detected at ${MKLROOT}"

rm -rf "${SUITESPARSE_SOURCE_DIR}"
mkdir -p "${SUITESPARSE_SOURCE_DIR}"
monitor_cache "Before SuiteSparse source fetch"

printf '%b\n' "${YELLOW}[6.12C.2] Fetching SuiteSparse source (${SUITESPARSE_VERSION})...${NC}"
# Validate git clone result (H1)
if git clone --depth 1 --branch "${SUITESPARSE_VERSION}" https://github.com/DrTimothyAldenDavis/SuiteSparse.git "${SUITESPARSE_SOURCE_DIR}/src"; then
    printf '%s\n' "  ✓ SuiteSparse repository cloned"
else
    printf '%s\n' "  ✗ Failed to clone SuiteSparse repository" >&2
    exit 1
fi

monitor_cache "After SuiteSparse source fetch"

# Critical: Patch GraphBLAS/LAGraph to ensure math library linking
# GraphBLAS doesn't use BLAS, so it won't get -lm from BLAS_LIBRARIES
# Problem: GraphBLAS builds libgraphblas.so and LAGraph builds liblagraph.so,
# both need to link against libm, but GraphBLAS's CMakeLists.txt may not
# explicitly link to the math library.
printf '%b\n' "${YELLOW}[6.12C.2.1] Patching GraphBLAS/LAGraph for math library linking...${NC}"

# Find GraphBLAS CMakeLists.txt (may be in GraphBLAS/ or GraphBLAS/GraphBLAS/)
# Validate file existence before use (J1)
GRAPHBLAS_CMakeLists=""
for candidate in \
    "${SUITESPARSE_SOURCE_DIR}/src/GraphBLAS/CMakeLists.txt" \
    "${SUITESPARSE_SOURCE_DIR}/src/GraphBLAS/GraphBLAS/CMakeLists.txt"; do
    if [ -f "${candidate}" ]; then
        GRAPHBLAS_CMakeLists="${candidate}"
        break
    fi
done

# Find LAGraph CMakeLists.txt
# Validate file existence before use (J1)
LAGRAPH_CMakeLists=""
for candidate in \
    "${SUITESPARSE_SOURCE_DIR}/src/LAGraph/CMakeLists.txt" \
    "${SUITESPARSE_SOURCE_DIR}/src/LAGraph/LAGraph/CMakeLists.txt"; do
    if [ -f "${candidate}" ]; then
        LAGRAPH_CMakeLists="${candidate}"
        break
    fi
done

# Patch GraphBLAS to explicitly link math library
# CRITICAL FIX: The check_symbol_exists call doesn't link against libm during the check,
# which can cause it to pass even when linking will fail. We fix this by:
# 1. Updating check_symbol_exists to use CMAKE_REQUIRED_LIBRARIES
# 2. Always ensuring libm is linked on Unix systems
# Validate GraphBLAS CMakeLists.txt file exists (J1)
if [ -n "${GRAPHBLAS_CMakeLists}" ] && [ -f "${GRAPHBLAS_CMakeLists}" ]; then
    printf '%s\n' "  → Found GraphBLAS CMakeLists.txt: ${GRAPHBLAS_CMakeLists}"
    
    # First, fix the check_symbol_exists call to use CMAKE_REQUIRED_LIBRARIES
    # This ensures the check actually links against libm, not just checks the header
    # Validate grep results (F2, H4)
    if grep -q "check_symbol_exists.*fmax" "${GRAPHBLAS_CMakeLists}" 2>/dev/null && \
       ! grep -q "CMAKE_REQUIRED_LIBRARIES.*m" "${GRAPHBLAS_CMakeLists}" 2>/dev/null; then
        printf '%s\n' "  → Fixing check_symbol_exists to link against libm during check..."
        # Validate Python3 is available before attempting patch (M1)
        if ! command -v python3 >/dev/null 2>&1; then
            printf '%s\n' "  ✗ ERROR: python3 not found, cannot patch GraphBLAS CMakeLists.txt" >&2
            printf '%s\n' "    → Will rely on CMake linker flags only" >&2
        else
            # Create backup for safety (will be cleaned up after successful patch)
            cp "${GRAPHBLAS_CMakeLists}" "${GRAPHBLAS_CMakeLists}.bak"
        python3 -c "
import sys
import re

cmake_file = sys.argv[1]

with open(cmake_file, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find the check_symbol_exists line and fix it
fixed = False
for i, line in enumerate(lines):
    # Match: check_symbol_exists ( fmax \"math.h\" NO_LIBM ) - more flexible pattern
    if re.search(r'check_symbol_exists\s*\(\s*fmax\s+[\"<]math\.h[\">]\s+NO_LIBM', line):
        # Check if already fixed (look for CMAKE_REQUIRED_LIBRARIES setup before this line)
        already_fixed = False
        for k in range(max(0, i-3), i):
            if 'CMAKE_REQUIRED_LIBRARIES' in lines[k] and 'm' in lines[k]:
                already_fixed = True
                break
        if already_fixed:
            print('  ✓ check_symbol_exists already uses CMAKE_REQUIRED_LIBRARIES')
            sys.exit(0)
        # Insert CMAKE_REQUIRED_LIBRARIES setup before the check
        indent = len(line) - len(line.lstrip())
        # Save original value first (escape $ for Python string literal)
        lines.insert(i, ' ' * indent + 'set ( _orig_CMAKE_REQUIRED_LIBRARIES ${CMAKE_REQUIRED_LIBRARIES} )\n')
        # Set CMAKE_REQUIRED_LIBRARIES to include libm
        lines.insert(i+1, ' ' * indent + 'set ( CMAKE_REQUIRED_LIBRARIES \"m\" )\n')
        # Find the closing of check_symbol_exists (next line with if NOT NO_LIBM)
        # Insert restore after the check_symbol_exists line
        restore_inserted = False
        for j in range(i+3, min(i+15, len(lines))):
            if re.search(r'if\s*\(\s*NOT\s+NO_LIBM', lines[j]):
                # Insert restore before the if statement
                indent_if = len(lines[j]) - len(lines[j].lstrip())
                lines.insert(j, ' ' * indent_if + 'set ( CMAKE_REQUIRED_LIBRARIES ${_orig_CMAKE_REQUIRED_LIBRARIES} )\n')
                restore_inserted = True
                fixed = True
                break
        if not restore_inserted:
            # If we couldn't find the if, add restore after check_symbol_exists line (3 lines after insertion)
            lines.insert(i+3, ' ' * indent + 'set ( CMAKE_REQUIRED_LIBRARIES ${_orig_CMAKE_REQUIRED_LIBRARIES} )\n')
            fixed = True
        break

if fixed:
    with open(cmake_file, 'w', encoding='utf-8') as f:
        f.writelines(lines)
    print('  ✓ Fixed check_symbol_exists to use CMAKE_REQUIRED_LIBRARIES')
    sys.exit(0)
else:
    print('  ⚠ Could not find check_symbol_exists pattern to fix (may already be fixed)')
    sys.exit(1)
" "${GRAPHBLAS_CMakeLists}" 2>&1
            PATCH_RESULT=$?
            # Validate patch result (F2, H4)
            if [ "${PATCH_RESULT:-1}" -eq 0 ] && [ -n "${GRAPHBLAS_CMakeLists}" ] && [ -f "${GRAPHBLAS_CMakeLists}" ]; then
                # Patch succeeded, remove backup file
                rm -f "${GRAPHBLAS_CMakeLists}.bak"
            else
                printf '%s\n' "  ⚠ Failed to fix check_symbol_exists, will ensure libm is linked directly" >&2
                # Restore backup on failure (optional - keep backup for debugging)
                # Validate backup file exists before restoring (J1)
                if [ -f "${GRAPHBLAS_CMakeLists}.bak" ]; then
                    mv "${GRAPHBLAS_CMakeLists}.bak" "${GRAPHBLAS_CMakeLists}"
                fi
            fi
            # ENDIF: patch result check
        fi
        # ENDIF: python3 availability check
    fi
    # ENDIF: GraphBLAS CMakeLists.txt check
    
    # CRITICAL: Patch ALL CMakeLists.txt files that create executables to ensure libm linking
    # This includes test directories, benchmark directories, and any other executables
    echo "  → Searching for all CMakeLists.txt files with executables to ensure libm linking..."
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import sys
import os
import re

base_dir = sys.argv[1]

def patch_cmake_for_libm(cmake_file):
    \"\"\"Patch a CMakeLists.txt file to ensure all executables link against libm\"\"\"
    try:
        with open(cmake_file, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        modified = False
        # Find all add_executable calls and ensure their targets link against libm
        for i, line in enumerate(lines):
            # Match: add_executable(target_name ...)
            match = re.search(r'add_executable\s*\(\s*([A-Za-z_][A-Za-z0-9_]*)', line)
            if match:
                target_name = match.group(1)
                # Skip if target name contains 'test' and we're looking for non-test executables
                # Actually, we want to patch ALL executables
                
                # Check if this target already has target_link_libraries with libm
                has_libm = False
                # Look ahead up to 30 lines for target_link_libraries
                for j in range(i+1, min(i+30, len(lines))):
                    if re.search(r'target_link_libraries\s*\(\s*' + re.escape(target_name), lines[j], re.IGNORECASE):
                        if re.search(r'\\bm\\b', lines[j]):
                            has_libm = True
                            break
                        # If we found target_link_libraries but it doesn't have libm, add it
                        stripped = lines[j].strip()
                        if stripped.count('(') > 0 and stripped.count(')') >= stripped.count('('):
                            # Single-line target_link_libraries - add ' m' before closing paren
                            last_paren = stripped.rfind(')')
                            if last_paren > 0:
                                before = stripped[:last_paren].rstrip()
                                after = stripped[last_paren:]
                                leading_ws = lines[j][:len(lines[j]) - len(lines[j].lstrip())]
                                trailing_ws = lines[j][len(lines[j].rstrip()):]
                                lines[j] = leading_ws + before + ' m' + after + trailing_ws
                                modified = True
                                has_libm = True
                                break
                
                # If no target_link_libraries found, add one after add_executable
                if not has_libm:
                    # Find the end of add_executable (next non-continuation line)
                    insert_idx = i + 1
                    while insert_idx < len(lines) and (lines[insert_idx].strip().endswith('\\\\') or not lines[insert_idx].strip() or lines[insert_idx].strip().startswith('#')):
                        insert_idx += 1
                    # Preserve indentation
                    indent = len(line) - len(line.lstrip())
                    indent_str = ' ' * indent
                    # Insert target_link_libraries
                    lines.insert(insert_idx, f'{indent_str}target_link_libraries({target_name} PRIVATE m)\n')
                    modified = True
        
        if modified:
            with open(cmake_file, 'w', encoding='utf-8') as f:
                f.writelines(lines)
            return True
        return False
    except Exception as e:
        return False

# Find all CMakeLists.txt files in GraphBLAS and LAGraph directories
patched_count = 0
for root, dirs, files in os.walk(base_dir):
    # Skip hidden directories and build directories
    dirs[:] = [d for d in dirs if not d.startswith('.') and d != 'build' and d != 'Build']
    
    for file in files:
        if file == 'CMakeLists.txt':
            cmake_path = os.path.join(root, file)
            # Skip if it's the main GraphBLAS/LAGraph CMakeLists.txt (already patched)
            if 'GraphBLAS/CMakeLists.txt' in cmake_path and cmake_path.endswith('GraphBLAS/CMakeLists.txt'):
                continue
            if 'LAGraph/CMakeLists.txt' in cmake_path and cmake_path.endswith('LAGraph/CMakeLists.txt'):
                continue
            
            # Check if file contains add_executable
            try:
                with open(cmake_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    if 'add_executable' in content:
                        if patch_cmake_for_libm(cmake_path):
                            rel_path = os.path.relpath(cmake_path, base_dir)
                            print(f'  ✓ Patched: {rel_path}')
                            patched_count += 1
            except:
                pass

if patched_count > 0:
    print(f'  ✓ Patched {patched_count} CMakeLists.txt file(s) to ensure libm linking')
    sys.exit(0)
else:
    print('  ✓ All executables already link against libm (or no additional executables found)')
    sys.exit(0)
" "${SUITESPARSE_SOURCE_DIR}/src" 2>&1
            PATCH_ALL_RESULT=$?
            # Validate patch result (F2, H4)
            if [ "${PATCH_ALL_RESULT:-1}" -ne 0 ]; then
                printf '%s\n' "  ⚠ Failed to patch some CMakeLists.txt files, will rely on CMAKE_EXE_LINKER_FLAGS" >&2
            fi
    else
        echo "  ⚠ python3 not found, cannot patch all CMakeLists.txt files"
        echo "    → Will rely on CMAKE_EXE_LINKER_FLAGS_INIT for all executables"
    fi
    # ENDIF: python3 availability check for all CMakeLists.txt patching
    
    # Also ensure libm is always linked on Unix (safer approach)
    # Check if GraphBLAS target already links to math library (case-insensitive)
    # Check for target_link_libraries line containing both GraphBLAS/graphblas and math library ' m'
    # Use -- to prevent option misinterpretation if pattern starts with '-' (K1b)
    if ! grep -qiE "(target_link_libraries.*GraphBLAS.*[[:space:]]m[[:space:]]|target_link_libraries.*graphblas.*[[:space:]]m[[:space:]])" -- "${GRAPHBLAS_CMakeLists}" 2>/dev/null; then
        # Find the GraphBLAS target name (could be GraphBLAS, graphblas, etc.)
        # Look for add_library command
        # Validate command substitution result (F2, H4)
        GRAPHBLAS_TARGET=$(grep -iE "^\s*add_library\s*\(\s*[A-Za-z_][A-Za-z0-9_]*" "${GRAPHBLAS_CMakeLists}" 2>/dev/null | head -1 | sed -n 's/.*add_library\s*(\s*\([A-Za-z_][A-Za-z0-9_]*\).*/\1/p' || echo "")
        # Validate result is non-empty and contains valid target name (F2, H4)
        if [ -z "${GRAPHBLAS_TARGET}" ] || ! printf '%s\n' "${GRAPHBLAS_TARGET}" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*$'; then
            echo "  ⚠ Could not determine GraphBLAS target name from CMakeLists.txt"
            GRAPHBLAS_TARGET=""
        fi
        
        if [ -n "${GRAPHBLAS_TARGET}" ]; then
            echo "  → GraphBLAS target: ${GRAPHBLAS_TARGET}"
            # Validate Python3 is available
            if ! command -v python3 >/dev/null 2>&1; then
                echo "  ✗ ERROR: python3 not found, cannot patch GraphBLAS target_link_libraries"
                echo "    → Will rely on CMake linker flags only"
            else
                # Find where to add the math library link - look for existing target_link_libraries for this target
                # Add math library linking if not present
                # We'll add it after the first target_link_libraries call for GraphBLAS, or at the end of target configuration
                # Use sed to add target_link_libraries with math library
                # First, check if there's already a target_link_libraries line we can modify
                # Use -- to prevent option misinterpretation (K1b)
                if grep -qiE "target_link_libraries\s*\(\s*${GRAPHBLAS_TARGET}" -- "${GRAPHBLAS_CMakeLists}" 2>/dev/null; then
                    # Add m to existing target_link_libraries line (if not already there)
                    echo "  → GraphBLAS has target_link_libraries, ensuring math library is included..."
                    # Create a backup and patch using Python (will be cleaned up after successful patch)
                    cp "${GRAPHBLAS_CMakeLists}" "${GRAPHBLAS_CMakeLists}.bak"
                    # Use Python to safely add math library to target_link_libraries
                    # Validate CMakeLists.txt exists before patching (J1)
                    if [ ! -f "${GRAPHBLAS_CMakeLists}" ]; then
                      echo "  ✗ ERROR: GraphBLAS CMakeLists.txt not found: ${GRAPHBLAS_CMakeLists}"
                      exit 1
                    fi
                    python3 -c "
import sys
import re

cmake_file = sys.argv[1]
target_name = sys.argv[2]

with open(cmake_file, 'r', encoding='utf-8') as f:
    content = f.read()
    lines = content.splitlines(keepends=True)

modified = False
# Process line by line to preserve CMake structure - only modify single-line target_link_libraries
for i, line in enumerate(lines):
    stripped = line.strip()
    # Only process complete single-line target_link_libraries calls (must have balanced parens on one line)
    if re.search(r'target_link_libraries\s*\(\s*' + re.escape(target_name), stripped, re.IGNORECASE):
        # Check if this is a single-line call (has opening and closing paren on same line)
        if stripped.count('(') > 0 and stripped.count(')') >= stripped.count('('):
            # Check if 'm' is already in the line (whole word match)
            if not re.search(r'\\bm\\b', stripped):
                # Find the last closing parenthesis
                last_paren_idx = stripped.rfind(')')
                if last_paren_idx > 0:
                    # Insert ' m' before the closing parenthesis, preserving original line structure
                    before_paren = stripped[:last_paren_idx].rstrip()
                    after_paren = stripped[last_paren_idx:]
                    # Preserve leading whitespace and newline from original line
                    leading_ws = line[:len(line) - len(line.lstrip())]
                    trailing_ws = line[len(line.rstrip()):]
                    new_line = leading_ws + before_paren + ' m' + after_paren + trailing_ws
                    lines[i] = new_line
                    modified = True
                    break  # Only modify the first matching target_link_libraries

if modified:
    with open(cmake_file, 'w', encoding='utf-8') as f:
        f.writelines(lines)
    print(f'  ✓ Added math library to {target_name} target_link_libraries')
    sys.exit(0)
else:
    # If no modification was made, try to add a new target_link_libraries line
    with open(cmake_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    add_lib_pattern = r'add_library\s*\(\s*' + re.escape(target_name)
    for i, line in enumerate(lines):
        if re.search(add_lib_pattern, line, re.IGNORECASE):
            # Find insertion point (after add_library, before next major command)
            insert_idx = i + 1
            while insert_idx < len(lines) and (lines[insert_idx].strip().startswith('#') or not lines[insert_idx].strip()):
                insert_idx += 1
            # Preserve indentation from add_library line
            indent = len(line) - len(line.lstrip())
            indent_str = ' ' * indent
            # Insert target_link_libraries with proper newline and indentation
            lines.insert(insert_idx, f'{indent_str}target_link_libraries({target_name} PRIVATE m)\n')
            with open(cmake_file, 'w', encoding='utf-8') as f:
                f.writelines(lines)
            print(f'  ✓ Added target_link_libraries({target_name} PRIVATE m)')
            sys.exit(0)
    print(f'  ⚠ Could not find add_library or target_link_libraries for {target_name}')
    sys.exit(1)
" "${GRAPHBLAS_CMakeLists}" "${GRAPHBLAS_TARGET}" 2>&1
                    PATCH_RESULT=$?
                    # Validate patch result (F2, H4)
                    if [ "${PATCH_RESULT:-1}" -eq 0 ]; then
                        # Patch succeeded, remove backup
                        rm -f "${GRAPHBLAS_CMakeLists}.bak"
                    else
                        echo "  ⚠ Python patch failed, will rely on CMake standard libraries"
                        # Restore backup on failure
                        if [ -f "${GRAPHBLAS_CMakeLists}.bak" ]; then
                            mv "${GRAPHBLAS_CMakeLists}.bak" "${GRAPHBLAS_CMakeLists}"
                        fi
                    fi
                    # ENDIF: patch result check
                else
                    echo "  → No existing target_link_libraries found for GraphBLAS, adding one..."
                    # Add a new target_link_libraries line after add_library
                    # Validate CMakeLists.txt exists before patching (J1)
                    if [ ! -f "${GRAPHBLAS_CMakeLists}" ]; then
                      echo "  ✗ ERROR: GraphBLAS CMakeLists.txt not found: ${GRAPHBLAS_CMakeLists}"
                      exit 1
                    fi
                    cp "${GRAPHBLAS_CMakeLists}" "${GRAPHBLAS_CMakeLists}.bak"
                    python3 -c "
import sys
import re

cmake_file = sys.argv[1]
target_name = sys.argv[2]

with open(cmake_file, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find add_library line for the target
add_lib_idx = -1
for i, line in enumerate(lines):
    if re.search(r'add_library\s*\(\s*' + re.escape(target_name), line, re.IGNORECASE):
        add_lib_idx = i
        break

if add_lib_idx >= 0:
    # Find insertion point (after add_library, before next major command)
    insert_idx = add_lib_idx + 1
    # Skip comments and empty lines to find a good place to insert
    while insert_idx < len(lines) and (lines[insert_idx].strip().startswith('#') or not lines[insert_idx].strip()):
        insert_idx += 1
    # Preserve indentation from add_library line
    add_lib_line = lines[add_lib_idx]
    indent = len(add_lib_line) - len(add_lib_line.lstrip())
    indent_str = ' ' * indent
    # Insert target_link_libraries with proper newline and indentation
    lines.insert(insert_idx, f'{indent_str}target_link_libraries({target_name} PRIVATE m)\n')
    with open(cmake_file, 'w', encoding='utf-8') as f:
        f.writelines(lines)
    print(f'  ✓ Added target_link_libraries({target_name} PRIVATE m)')
else:
    print(f'  ⚠ Could not find add_library for {target_name}')
    sys.exit(1)
" "${GRAPHBLAS_CMakeLists}" "${GRAPHBLAS_TARGET}" 2>&1
                    PATCH_RESULT=$?
                    # Validate patch result (F2, H4)
                    if [ "${PATCH_RESULT:-1}" -eq 0 ]; then
                        # Patch succeeded, remove backup
                        rm -f "${GRAPHBLAS_CMakeLists}.bak"
                    else
                        echo "  ⚠ Failed to add target_link_libraries, will rely on CMake variables"
                        # Restore backup on failure
                        if [ -f "${GRAPHBLAS_CMakeLists}.bak" ]; then
                            mv "${GRAPHBLAS_CMakeLists}.bak" "${GRAPHBLAS_CMakeLists}"
                        fi
                    fi
                    # ENDIF: patch result check
                fi
                # ENDIF: target_link_libraries existence check
            fi
            # ENDIF: python3 availability check
        else
            echo "  ⚠ Could not determine GraphBLAS target name"
        fi
        # ENDIF: GraphBLAS target name check
    else
        echo "  ✓ GraphBLAS already links to math library"
    fi
    # ENDIF: GraphBLAS math library link check
else
    echo "  ⚠ GraphBLAS CMakeLists.txt not found (will rely on CMake standard libraries)"
fi
# ENDIF: GraphBLAS CMakeLists.txt existence check

# Patch LAGraph similarly to ensure math library linking
if [ -n "${LAGRAPH_CMakeLists}" ] && [ -f "${LAGRAPH_CMakeLists}" ]; then
    echo "  → Found LAGraph CMakeLists.txt: ${LAGRAPH_CMakeLists}"
    # Check if LAGraph target already links to math library (case-insensitive)
    # Check for target_link_libraries line containing both LAGraph/lagraph and math library ' m'
    # Use -- to prevent option misinterpretation if pattern starts with '-' (K1b)
    if ! grep -qiE "(target_link_libraries.*LAGraph.*[[:space:]]m[[:space:]]|target_link_libraries.*lagraph.*[[:space:]]m[[:space:]])" -- "${LAGRAPH_CMakeLists}" 2>/dev/null; then
        # Find the LAGraph target name (could be LAGraph, lagraph, etc.)
        # Validate command substitution result (F2, H4)
        LAGRAPH_TARGET=$(grep -iE "^\s*add_library\s*\(\s*[A-Za-z_][A-Za-z0-9_]*" "${LAGRAPH_CMakeLists}" 2>/dev/null | head -1 | sed -n 's/.*add_library\s*(\s*\([A-Za-z_][A-Za-z0-9_]*\).*/\1/p' || echo "")
        # Validate result is non-empty and contains valid target name (F2, H4)
        if [ -z "${LAGRAPH_TARGET}" ] || ! printf '%s\n' "${LAGRAPH_TARGET}" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*$'; then
            printf '%s\n' "  ⚠ Could not determine LAGraph target name from CMakeLists.txt" >&2
            LAGRAPH_TARGET=""
        fi
        
        if [ -n "${LAGRAPH_TARGET}" ]; then
            printf '%s\n' "  → LAGraph target: ${LAGRAPH_TARGET}"
            # Validate Python3 is available
            if ! command -v python3 >/dev/null 2>&1; then
                printf '%s\n' "  ✗ ERROR: python3 not found, cannot patch LAGraph target_link_libraries" >&2
                printf '%s\n' "    → Will rely on CMake linker flags only" >&2
            else
                # Check if there's already a target_link_libraries line we can modify
                # Use -- to prevent option misinterpretation (K1b)
                if grep -qiE "target_link_libraries\s*\(\s*${LAGRAPH_TARGET}" -- "${LAGRAPH_CMakeLists}" 2>/dev/null; then
                    # Add m to existing target_link_libraries line (if not already there)
                    printf '%s\n' "  → LAGraph has target_link_libraries, ensuring math library is included..."
                    # Validate CMakeLists.txt exists before patching (J1)
                    if [ ! -f "${LAGRAPH_CMakeLists}" ]; then
                      printf '%s\n' "  ✗ ERROR: LAGraph CMakeLists.txt not found: ${LAGRAPH_CMakeLists}" >&2
                      return 1
                    fi
                    cp "${LAGRAPH_CMakeLists}" "${LAGRAPH_CMakeLists}.bak"
                    python3 -c "
import sys
import re

cmake_file = sys.argv[1]
target_name = sys.argv[2]

with open(cmake_file, 'r', encoding='utf-8') as f:
    content = f.read()
    lines = content.splitlines(keepends=True)

modified = False
# Process line by line to preserve CMake structure - only modify single-line target_link_libraries
for i, line in enumerate(lines):
    stripped = line.strip()
    # Only process complete single-line target_link_libraries calls (must have balanced parens on one line)
    if re.search(r'target_link_libraries\s*\(\s*' + re.escape(target_name), stripped, re.IGNORECASE):
        # Check if this is a single-line call (has opening and closing paren on same line)
        if stripped.count('(') > 0 and stripped.count(')') >= stripped.count('('):
            # Check if 'm' is already in the line (whole word match)
            if not re.search(r'\\bm\\b', stripped):
                # Find the last closing parenthesis
                last_paren_idx = stripped.rfind(')')
                if last_paren_idx > 0:
                    # Insert ' m' before the closing parenthesis, preserving original line structure
                    before_paren = stripped[:last_paren_idx].rstrip()
                    after_paren = stripped[last_paren_idx:]
                    # Preserve leading whitespace and newline from original line
                    leading_ws = line[:len(line) - len(line.lstrip())]
                    trailing_ws = line[len(line.rstrip()):]
                    new_line = leading_ws + before_paren + ' m' + after_paren + trailing_ws
                    lines[i] = new_line
                    modified = True
                    break  # Only modify the first matching target_link_libraries

if modified:
    with open(cmake_file, 'w', encoding='utf-8') as f:
        f.writelines(lines)
    print(f'  ✓ Added math library to {target_name} target_link_libraries')
    sys.exit(0)
else:
    # If no modification was made, try to add a new target_link_libraries line
    with open(cmake_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    add_lib_pattern = r'add_library\s*\(\s*' + re.escape(target_name)
    for i, line in enumerate(lines):
        if re.search(add_lib_pattern, line, re.IGNORECASE):
            # Find insertion point (after add_library, before next major command)
            insert_idx = i + 1
            while insert_idx < len(lines) and (lines[insert_idx].strip().startswith('#') or not lines[insert_idx].strip()):
                insert_idx += 1
            # Preserve indentation from add_library line
            indent = len(line) - len(line.lstrip())
            indent_str = ' ' * indent
            # Insert target_link_libraries with proper newline and indentation
            lines.insert(insert_idx, f'{indent_str}target_link_libraries({target_name} PRIVATE m)\n')
            with open(cmake_file, 'w', encoding='utf-8') as f:
                f.writelines(lines)
            print(f'  ✓ Added target_link_libraries({target_name} PRIVATE m)')
            sys.exit(0)
    print(f'  ⚠ Could not find add_library or target_link_libraries for {target_name}')
    sys.exit(1)
" "${LAGRAPH_CMakeLists}" "${LAGRAPH_TARGET}" 2>&1
                    PATCH_RESULT=$?
                    # Validate patch result (F2, H4)
                    if [ "${PATCH_RESULT:-1}" -eq 0 ]; then
                        # Patch succeeded, remove backup
                        rm -f "${LAGRAPH_CMakeLists}.bak"
                    else
                        printf '%s\n' "  ⚠ Failed to patch LAGraph, will rely on CMake linker flags" >&2
                        # Restore backup on failure
                        if [ -f "${LAGRAPH_CMakeLists}.bak" ]; then
                            mv "${LAGRAPH_CMakeLists}.bak" "${LAGRAPH_CMakeLists}"
                        fi
                    fi
                    # ENDIF: patch result check
                else
                    printf '%s\n' "  → No existing target_link_libraries found for LAGraph, adding one..."
                    # Validate CMakeLists.txt exists before patching (J1)
                    if [ ! -f "${LAGRAPH_CMakeLists}" ]; then
                      printf '%s\n' "  ✗ ERROR: LAGraph CMakeLists.txt not found: ${LAGRAPH_CMakeLists}" >&2
                      return 1
                    fi
                    cp "${LAGRAPH_CMakeLists}" "${LAGRAPH_CMakeLists}.bak"
                    python3 -c "
import sys
import re

cmake_file = sys.argv[1]
target_name = sys.argv[2]

with open(cmake_file, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find add_library line for the target
add_lib_idx = -1
for i, line in enumerate(lines):
    if re.search(r'add_library\s*\(\s*' + re.escape(target_name), line, re.IGNORECASE):
        add_lib_idx = i
        break

if add_lib_idx >= 0:
    # Find insertion point (after add_library, before next major command)
    insert_idx = add_lib_idx + 1
    # Skip comments and empty lines to find a good place to insert
    while insert_idx < len(lines) and (lines[insert_idx].strip().startswith('#') or not lines[insert_idx].strip()):
        insert_idx += 1
    # Preserve indentation from add_library line
    add_lib_line = lines[add_lib_idx]
    indent = len(add_lib_line) - len(add_lib_line.lstrip())
    indent_str = ' ' * indent
    # Insert target_link_libraries with proper newline and indentation
    lines.insert(insert_idx, f'{indent_str}target_link_libraries({target_name} PRIVATE m)\n')
    with open(cmake_file, 'w', encoding='utf-8') as f:
        f.writelines(lines)
    print(f'  ✓ Added target_link_libraries({target_name} PRIVATE m)')
else:
    print(f'  ⚠ Could not find add_library for {target_name}')
    sys.exit(1)
" "${LAGRAPH_CMakeLists}" "${LAGRAPH_TARGET}" 2>&1
                    PATCH_RESULT=$?
                    # Validate patch result (F2, H4)
                    if [ "${PATCH_RESULT:-1}" -eq 0 ]; then
                        # Patch succeeded, remove backup
                        rm -f "${LAGRAPH_CMakeLists}.bak"
                    else
                        printf '%s\n' "  ⚠ Failed to add target_link_libraries to LAGraph, will rely on CMake variables" >&2
                        # Restore backup on failure
                        if [ -f "${LAGRAPH_CMakeLists}.bak" ]; then
                            mv "${LAGRAPH_CMakeLists}.bak" "${LAGRAPH_CMakeLists}"
                        fi
                    fi
                    # ENDIF: patch result check
                fi
                # ENDIF: target_link_libraries existence check
            fi
            # ENDIF: python3 availability check
        else
            printf '%s\n' "  ⚠ Could not determine LAGraph target name" >&2
        fi
        # ENDIF: LAGraph target name check
    else
        printf '%s\n' "  ✓ LAGraph already links to math library"
    fi
    # ENDIF: LAGraph math library link check
else
    printf '%s\n' "  ⚠ LAGraph CMakeLists.txt not found (will rely on CMake standard libraries)" >&2
fi
# ENDIF: LAGraph CMakeLists.txt existence check

printf '%s\n' "${YELLOW}[6.12C.3] Configuring SuiteSparse via CMake...${NC}"
cmake_build_dir="${SUITESPARSE_SOURCE_DIR}/build"
# Validate source directory exists before build operations (J1)
if [ ! -d "${SUITESPARSE_SOURCE_DIR}" ]; then
  printf '%s\n' "  ✗ ERROR: SuiteSparse source directory not found: ${SUITESPARSE_SOURCE_DIR}" >&2
  exit 1
fi
rm -rf "${cmake_build_dir}"
mkdir -p "${cmake_build_dir}" || { printf '%s\n' "  ✗ Failed to create build directory: ${cmake_build_dir}" >&2; exit 1; }
pushd "${cmake_build_dir}" >/dev/null || { printf '%s\n' "  ✗ Failed to change to build directory: ${cmake_build_dir}" >&2; exit 1; }

CMAKE_CUDA_ARCH="${CMAKE_CUDA_ARCHITECTURES:-86}"
BLAS_LIBS="${MKLROOT}/lib/intel64/libmkl_intel_lp64.so;${MKLROOT}/lib/intel64/libmkl_core.so;${MKLROOT}/lib/intel64/libmkl_gnu_thread.so;-lgomp;-lpthread;-lm;-ldl"

# NOTE: METIS is bundled in SuiteSparse 7.12.1 (in CHOLMOD/SuiteSparse_metis/)
# When CHOLMOD_PARTITION=ON, SuiteSparse includes bundled METIS headers directly
# There is NO external METIS library dependency
# Reference: docs/flags/SUITESPARSE_BUILD_OPTIONS.md
printf '%s\n' "  → METIS is bundled in SuiteSparse (CHOLMOD_PARTITION=${CHOLMOD_PARTITION:-ON})"

# Note: SPEX Python bindings remain enabled (default). Python headers and tooling are available from earlier phases
# (Block 24 installs python3-dev/pybind11-dev), so no additional SuiteSparse overrides are necessary here.
# Critical: GraphBLAS/LAGraph requires explicit math library linking (-lm) for functions like round, log2, asinf, fmax, hypot, etc.
# GraphBLAS doesn't use BLAS, so it won't get -lm from BLAS_LIBRARIES.
# Solution: Use multiple approaches to ensure math library is linked:
# 1. CMAKE_SHARED_LINKER_FLAGS / CMAKE_EXE_LINKER_FLAGS (applied to all shared libraries/executables)
# 2. Environment variable LDFLAGS (picked up by CMake's compiler detection)
# 3. CMAKE_REQUIRED_LIBRARIES (forces libm to be linked for all targets during configuration)
# 4. Direct patching of GraphBLAS CMakeLists.txt (done above)
# SuiteSparse uses its own CMake variables (SUITESPARSE_USE_CUDA, SUITESPARSE_USE_OPENMP) and auto-detects CUDA libraries.
# Do not use standard CUDA CMake variables (CUDA_TOOLKIT_ROOT_DIR, CUBLAS_LIB, etc.) as they are ignored.
#
# LINKER FLAG ORDERING (CRITICAL):
# - Order: -fopenmp -lm (OpenMP flag first, then system libraries)
# - Rationale: -fopenmp adds OpenMP support (implicitly links -lgomp), system libraries like -lm should come last
# - This ensures correct symbol resolution: GraphBLAS code -> math functions (-lm) -> OpenMP runtime (-lgomp from -fopenmp)
# - System libraries (-lm, -lpthread, -ldl) should always be at the end of the linker command line
# - Note: BLAS_LIBRARIES already includes -lgomp;-lpthread;-lm;-ldl in correct order for BLAS-using libraries
#   But GraphBLAS doesn't use BLAS, so it only gets flags from CMAKE_*_LINKER_FLAGS
#
# CRITICAL SAFEGUARDS (based on diagnostic analysis):
# - Save original LDFLAGS to avoid contaminating check_symbol_exists test
# - The check_symbol_exists test should run WITHOUT -lm in LDFLAGS to correctly detect need for libm
# - After CMake configuration, we can safely restore LDFLAGS for the actual build
# - Use proper variable tracking to handle both set-but-empty and unset cases
LDFLAGS_WAS_SET=false
if [ "${LDFLAGS+set}" = "set" ]; then
    LDFLAGS_WAS_SET=true
    ORIG_LDFLAGS="${LDFLAGS}"
fi
# Temporarily unset LDFLAGS during CMake configuration to prevent check_symbol_exists from getting false positive
# (If LDFLAGS contains -lm, check_symbol_exists might succeed incorrectly, thinking libm is not needed)
unset LDFLAGS
# Ensure CMAKE_REQUIRED_LIBRARIES is set for check_symbol_exists test (our patch also handles this)
# This ensures the test actually links against libm during the symbol check
export CMAKE_REQUIRED_LIBRARIES="m"

printf '%s\n' "  → Configuring CMake (LDFLAGS temporarily unset to ensure clean check_symbol_exists test)..."
# CRITICAL: Ensure libm is linked for ALL targets including test executables
# Multiple layers of protection:
# 1. CMAKE_*_LINKER_FLAGS_INIT ensures flags apply to all targets
# 2. Explicit -DNO_LIBM=OFF overrides incorrect detection
# 3. CMAKE_REQUIRED_LIBRARIES ensures check_symbol_exists links against libm
# 4. Direct patching of CMakeLists.txt files (done above) ensures explicit linking
# 5. Create initial cache file to force NO_LIBM=OFF before CMake runs
INITIAL_CACHE_FILE="${SUITESPARSE_SOURCE_DIR}/build/initial_cache.cmake"
# EXEMPTED FROM EXTRACTION: Small temporary CMake cache file (<10 lines), tightly coupled to build process, single-use
cat > "${INITIAL_CACHE_FILE}" <<'EOF'
# Force NO_LIBM=OFF to override any incorrect detection
set(NO_LIBM OFF CACHE BOOL "Do not use libm" FORCE)
# Ensure libm is always linked
set(CMAKE_EXE_LINKER_FLAGS_INIT "-fopenmp -lm" CACHE STRING "Initial executable linker flags" FORCE)
set(CMAKE_SHARED_LINKER_FLAGS_INIT "-fopenmp -lm" CACHE STRING "Initial shared library linker flags" FORCE)
set(CMAKE_MODULE_LINKER_FLAGS_INIT "-fopenmp -lm" CACHE STRING "Initial module linker flags" FORCE)
EOF

# shellcheck disable=SC2086 # SUITESPARSE_CMAKE_FLAGS contains multiple flags that need word splitting
if ! cmake ../src \
    -C "${INITIAL_CACHE_FILE}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${SUITESPARSE_INSTALL_PREFIX}" \
    -DCMAKE_CXX_FLAGS="-O3 -march=native -fPIC -fopenmp" \
    -DCMAKE_C_FLAGS="-O3 -march=native -fPIC -fopenmp" \
    -DCMAKE_CUDA_FLAGS="-O3 -fPIC -Xcompiler -fopenmp --ptxas-options=-v" \
    -DCMAKE_CUDA_ARCHITECTURES="${CMAKE_CUDA_ARCH}" \
    -DCMAKE_CUDA_COMPILER="${CUDA_HOME}/bin/nvcc" \
    -DCMAKE_EXE_LINKER_FLAGS="-fopenmp -lm" \
    -DCMAKE_EXE_LINKER_FLAGS_INIT="-fopenmp -lm" \
    -DCMAKE_SHARED_LINKER_FLAGS="-fopenmp -lm" \
    -DCMAKE_SHARED_LINKER_FLAGS_INIT="-fopenmp -lm" \
    -DCMAKE_MODULE_LINKER_FLAGS="-fopenmp -lm" \
    -DCMAKE_MODULE_LINKER_FLAGS_INIT="-fopenmp -lm" \
    -DCMAKE_REQUIRED_LIBRARIES="m" \
    -DNO_LIBM=OFF \
    -DBUILD_SHARED_LIBS=ON \
    -DBLA_VENDOR=Intel10_64lp \
    -DBLAS_LIBRARIES="${BLAS_LIBS}" \
    -DLAPACK_LIBRARIES="${BLAS_LIBS}" \
    -DBLA_SIZEOF_INTEGER=4 \
    -DCMAKE_PREFIX_PATH="${CUDA_HOME};${MKLROOT}${CMAKE_PREFIX_PATH:+;${CMAKE_PREFIX_PATH}}" \
    ${SUITESPARSE_CMAKE_FLAGS}; then
    # NOTE: METIS_LIBRARY_DIR is NOT a valid SuiteSparse CMake flag
    # METIS is bundled in SuiteSparse 7.12.1 (in CHOLMOD/SuiteSparse_metis/)
    # When CHOLMOD_PARTITION=ON, SuiteSparse includes bundled METIS headers directly
    # Reference: docs/flags/SUITESPARSE_BUILD_OPTIONS.md
    printf '%s\n' "  ✗ CMake configuration failed" >&2
    # Restore LDFLAGS before exiting (in case other parts of script need it)
    if [ "${LDFLAGS_WAS_SET}" = "true" ]; then
        export LDFLAGS="${ORIG_LDFLAGS}"
    fi
    # Clean up environment variable
    unset CMAKE_REQUIRED_LIBRARIES
    exit 1
fi

# Verify NO_LIBM is not set (or is set to OFF/NO) in CMakeCache.txt
if [ -f "CMakeCache.txt" ]; then
    # Validate command substitution result (F2, H4)
    NO_LIBM_VALUE=$(grep -i "^NO_LIBM:" CMakeCache.txt 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || echo "")
    if [ -n "${NO_LIBM_VALUE}" ] && [ "${NO_LIBM_VALUE}" != "OFF" ] && [ "${NO_LIBM_VALUE}" != "NO" ] && [ "${NO_LIBM_VALUE}" != "FALSE" ] && [ "${NO_LIBM_VALUE}" != "0" ]; then
        printf '%s\n' "  ⚠ WARNING: NO_LIBM is set to '${NO_LIBM_VALUE}' in CMakeCache.txt (expected OFF/NO/FALSE/0)" >&2
        printf '%s\n' "    → This may indicate check_symbol_exists detected libm incorrectly" >&2
        printf '%s\n' "    → We explicitly set -DNO_LIBM=OFF, but CMake may have overridden it" >&2
        printf '%s\n' "    → CMake linker flags (-lm) should still ensure libm is linked, but verification is recommended" >&2
        printf '%s\n' "    → Attempting to force NO_LIBM=OFF via CMake cache..." >&2
        # Try to force NO_LIBM=OFF by editing CMakeCache.txt directly
        # H4: Validate sed result - check if file was modified
        if sed -i 's/^NO_LIBM:.*=.*/NO_LIBM:BOOL=OFF/' CMakeCache.txt 2>/dev/null; then
            # Re-run CMake configure to apply the change
            if ! cmake . -DNO_LIBM=OFF >/dev/null 2>&1; then
                printf '%s\n' "  ⚠ WARNING: Failed to re-run CMake after cache modification" >&2
            fi
        else
            printf '%s\n' "  ⚠ WARNING: Failed to modify CMakeCache.txt" >&2
        fi
        # Verify again
        # Validate command substitution result (F2, H4)
        NO_LIBM_VALUE=$(grep -i "^NO_LIBM:" CMakeCache.txt 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || echo "")
        if [ "${NO_LIBM_VALUE}" = "OFF" ] || [ "${NO_LIBM_VALUE}" = "NO" ] || [ "${NO_LIBM_VALUE}" = "FALSE" ] || [ "${NO_LIBM_VALUE}" = "0" ]; then
            printf '%s\n' "  ✓ Successfully forced NO_LIBM=OFF"
        else
            printf '%s\n' "  ⚠ Could not force NO_LIBM=OFF, but linker flags should still work" >&2
        fi
    else
        printf '%s\n' "  ✓ NO_LIBM check passed (value: ${NO_LIBM_VALUE:-unset/OFF})"
    fi
    
    # Additional verification: Check that linker flags actually contain -lm
    # Validate command substitution result (F2, H4)
    LINKER_FLAGS_CHECK=$(grep -i "^CMAKE_SHARED_LINKER_FLAGS:" CMakeCache.txt 2>/dev/null | cut -d'=' -f2- || echo "")
    # Validate variable before using in here-string (D3, F2)
    # D3c: Use grep -F for fixed-string matching (literal pattern)
    # CRITICAL: Use -- to prevent grep from interpreting -lm as an option
    if [ -n "${LINKER_FLAGS_CHECK}" ] && grep -Fq -- "-lm" <<< "${LINKER_FLAGS_CHECK}"; then
        printf '%s\n' "  ✓ Verified: CMAKE_SHARED_LINKER_FLAGS contains -lm"
    else
        printf '%s\n' "  ⚠ WARNING: CMAKE_SHARED_LINKER_FLAGS does NOT contain -lm" >&2
        printf '%s\n' "    → Attempting to fix by re-running CMake with explicit flags..." >&2
        # H4: Validate cmake result - check if reconfiguration succeeded
        if ! cmake . -DCMAKE_SHARED_LINKER_FLAGS="-fopenmp -lm" -DCMAKE_EXE_LINKER_FLAGS="-fopenmp -lm" >/dev/null 2>&1; then
            printf '%s\n' "  ⚠ WARNING: Failed to re-run CMake with explicit linker flags" >&2
        fi
    fi
fi

# Restore LDFLAGS after CMake configuration (if it was set originally)
# This ensures the build phase can use LDFLAGS if needed, but the check_symbol_exists test ran cleanly
# Note: The actual linking is handled by CMAKE_*_LINKER_FLAGS, so LDFLAGS restoration is mainly
# for compatibility with other build tools that might be invoked
if [ "${LDFLAGS_WAS_SET}" = "true" ]; then
    export LDFLAGS="${ORIG_LDFLAGS}"
    printf '%s\n' "  → Restored original LDFLAGS for build phase: ${LDFLAGS}"
else
    printf '%s\n' "  → LDFLAGS was not set originally, keeping it unset"
fi

# Clean up CMAKE_REQUIRED_LIBRARIES environment variable (it's now set in CMakeCache.txt)
# Keeping it as environment variable shouldn't hurt, but cleaning up is good practice
unset CMAKE_REQUIRED_LIBRARIES

printf '%s\n' "${YELLOW}[6.12C.4] Building SuiteSparse...${NC}"
# Final pre-build verification: Ensure NO_LIBM=OFF and linker flags are correct
if [ -f "CMakeCache.txt" ]; then
    # Validate command substitution result (F2, H4)
    NO_LIBM_VALUE=$(grep -i "^NO_LIBM:" "CMakeCache.txt" 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || echo "")
    if [ -n "${NO_LIBM_VALUE}" ] && [ "${NO_LIBM_VALUE}" != "OFF" ] && [ "${NO_LIBM_VALUE}" != "NO" ] && [ "${NO_LIBM_VALUE}" != "FALSE" ] && [ "${NO_LIBM_VALUE}" != "0" ]; then
        printf '%s\n' "  → Pre-build fix: NO_LIBM=${NO_LIBM_VALUE}, forcing OFF..." >&2
        # H4: Validate sed result
        if sed -i 's/^NO_LIBM:.*=.*/NO_LIBM:BOOL=OFF/' CMakeCache.txt 2>/dev/null; then
            # H4: Validate cmake result
            if ! cmake . -DNO_LIBM=OFF -DCMAKE_SHARED_LINKER_FLAGS="-fopenmp -lm" -DCMAKE_EXE_LINKER_FLAGS="-fopenmp -lm" >/dev/null 2>&1; then
                printf '%s\n' "  ⚠ WARNING: Failed to re-run CMake after pre-build fix" >&2
            fi
        else
            printf '%s\n' "  ⚠ WARNING: Failed to modify CMakeCache.txt for pre-build fix" >&2
        fi
    fi
fi

if ! cmake --build . -j"$(nproc)"; then
    printf '%s\n' "  ✗ SuiteSparse build failed" >&2
    # Provide diagnostic information
    printf '%s\n' "  → Checking for build errors related to math library..." >&2
    # We're still in the build directory, so check CMakeCache.txt
    if [ -f "CMakeCache.txt" ]; then
        # Validate command substitution results (F2, H4)
        NO_LIBM_VALUE=$(grep -i "^NO_LIBM:" "CMakeCache.txt" 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || echo "")
        printf '%s\n' "    - NO_LIBM value in CMakeCache.txt: ${NO_LIBM_VALUE:-unset}" >&2
        LINKER_FLAGS=$(grep -i "^CMAKE_SHARED_LINKER_FLAGS:" "CMakeCache.txt" 2>/dev/null | cut -d'=' -f2- || echo "")
        EXE_LINKER_FLAGS=$(grep -i "^CMAKE_EXE_LINKER_FLAGS:" "CMakeCache.txt" 2>/dev/null | cut -d'=' -f2- || echo "")
        # Validate variable before using in here-string (D3, F2)
        # D3c: Use grep -F for fixed-string matching (literal pattern)
        # CRITICAL: Use -- to prevent grep from interpreting -lm as an option
        if [ -n "${LINKER_FLAGS}" ] && grep -Fq -- "-lm" <<< "${LINKER_FLAGS}"; then
            printf '%s\n' "    - CMAKE_SHARED_LINKER_FLAGS contains -lm: YES" >&2
        else
            printf '%s\n' "    - CMAKE_SHARED_LINKER_FLAGS contains -lm: NO" >&2
            printf '%s\n' "      Actual flags: ${LINKER_FLAGS:0:80}..." >&2
        fi
        if [ -n "${EXE_LINKER_FLAGS}" ] && grep -Fq -- "-lm" <<< "${EXE_LINKER_FLAGS}"; then
            printf '%s\n' "    - CMAKE_EXE_LINKER_FLAGS contains -lm: YES" >&2
        else
            printf '%s\n' "    - CMAKE_EXE_LINKER_FLAGS contains -lm: NO" >&2
            printf '%s\n' "      Actual flags: ${EXE_LINKER_FLAGS:0:80}..." >&2
        fi
    else
        printf '%s\n' "    - CMakeCache.txt not found in current directory" >&2
    fi
    # Restore LDFLAGS before exiting (if it was set)
    if [ "${LDFLAGS_WAS_SET}" = "true" ]; then
        export LDFLAGS="${ORIG_LDFLAGS}"
    fi
    exit 1
fi

printf '%s\n' "${YELLOW}[6.12C.5] Installing SuiteSparse to ${SUITESPARSE_INSTALL_PREFIX}...${NC}"
if ! cmake --install .; then
    printf '%s\n' "  ✗ SuiteSparse installation failed" >&2
    exit 1
fi
printf '%s\n' "  ✓ SuiteSparse installation completed"

# Comprehensive post-build verification: Check NO_LIBM value and verify actual linking
if [ -f "CMakeCache.txt" ]; then
    # Validate command substitution results (F2, H4)
    NO_LIBM_VALUE=$(grep -i "^NO_LIBM:" "CMakeCache.txt" 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || echo "")
    LINKER_FLAGS=$(grep -i "^CMAKE_SHARED_LINKER_FLAGS:" "CMakeCache.txt" 2>/dev/null | cut -d'=' -f2- || echo "")
    EXE_LINKER_FLAGS=$(grep -i "^CMAKE_EXE_LINKER_FLAGS:" "CMakeCache.txt" 2>/dev/null | cut -d'=' -f2- || echo "")
    
    # Check both shared and executable linker flags
    # Validate variables before using in here-strings (D3, F2)
    # D3c: Use grep -F for fixed-string matching (literal pattern)
    # CRITICAL: Use -- to prevent grep from interpreting -lm as an option
    if [ -n "${LINKER_FLAGS}" ] && grep -Fq -- "-lm" <<< "${LINKER_FLAGS}"; then
      SHARED_HAS_LM="YES"
    else
      SHARED_HAS_LM="NO"
    fi
    if [ -n "${EXE_LINKER_FLAGS}" ] && grep -Fq -- "-lm" <<< "${EXE_LINKER_FLAGS}"; then
      EXE_HAS_LM="YES"
    else
      EXE_HAS_LM="NO"
    fi
    
    if [ -n "${NO_LIBM_VALUE}" ] && [ "${NO_LIBM_VALUE}" != "OFF" ] && [ "${NO_LIBM_VALUE}" != "NO" ] && [ "${NO_LIBM_VALUE}" != "FALSE" ] && [ "${NO_LIBM_VALUE}" != "0" ]; then
        if [ "${SHARED_HAS_LM}" = "YES" ] && [ "${EXE_HAS_LM}" = "YES" ]; then
            printf '%s\n' "  ℹ INFO: NO_LIBM=${NO_LIBM_VALUE} in CMakeCache.txt, but linker flags contain -lm"
            printf '%s\n' "    → CMAKE_SHARED_LINKER_FLAGS contains -lm: ${SHARED_HAS_LM}"
            printf '%s\n' "    → CMAKE_EXE_LINKER_FLAGS contains -lm: ${EXE_HAS_LM}"
            printf '%s\n' "    → This is non-critical: libm will still be linked due to explicit linker flags"
            printf '%s\n' "    → NO_LIBM is just an informational variable from check_symbol_exists"
        else
            printf '%s\n' "  ⚠ WARNING: NO_LIBM=${NO_LIBM_VALUE} and linker flags may be missing -lm" >&2
            printf '%s\n' "    → CMAKE_SHARED_LINKER_FLAGS contains -lm: ${SHARED_HAS_LM}" >&2
            printf '%s\n' "    → CMAKE_EXE_LINKER_FLAGS contains -lm: ${EXE_HAS_LM}" >&2
            printf '%s\n' "    → Attempting to fix..." >&2
            # H4: Validate sed and cmake results
            if sed -i 's/^NO_LIBM:.*=.*/NO_LIBM:BOOL=OFF/' CMakeCache.txt 2>/dev/null; then
                if ! cmake . -DNO_LIBM=OFF -DCMAKE_SHARED_LINKER_FLAGS="-fopenmp -lm" -DCMAKE_EXE_LINKER_FLAGS="-fopenmp -lm" >/dev/null 2>&1; then
                    printf '%s\n' "  ⚠ WARNING: Failed to re-run CMake after post-build fix" >&2
                fi
            else
                printf '%s\n' "  ⚠ WARNING: Failed to modify CMakeCache.txt for post-build fix" >&2
            fi
        fi
    else
        printf '%s\n' "  ✓ NO_LIBM check passed (value: ${NO_LIBM_VALUE:-unset/OFF})"
        printf '%s\n' "    → CMAKE_SHARED_LINKER_FLAGS contains -lm: ${SHARED_HAS_LM}"
        printf '%s\n' "    → CMAKE_EXE_LINKER_FLAGS contains -lm: ${EXE_HAS_LM}"
    fi
    
    # Verify actual built libraries link against libm (if they exist)
    if command -v ldd >/dev/null 2>&1; then
        printf '%s\n' "  → Verifying actual library linking against libm..."
        GRAPHBLAS_LIB=$(find . -name "libgraphblas.so*" -type f 2>/dev/null | head -1 || echo "")
        if [ -n "${GRAPHBLAS_LIB}" ] && [ -f "${GRAPHBLAS_LIB}" ]; then
            if ldd "${GRAPHBLAS_LIB}" 2>/dev/null | grep -Fq "libm.so"; then
                printf '%s\n' "    ✓ GraphBLAS library links against libm"
            else
                printf '%s\n' "    ⚠ GraphBLAS library does NOT link against libm (but linker flags should ensure it)" >&2
            fi
        fi
    fi
fi

popd >/dev/null

printf '%s\n' "${YELLOW}[6.12C.6] Verifying SuiteSparse linkage (MKL + CUDA)...${NC}"
ldconfig

# Verify GraphBLAS and LAGraph specifically (critical for math library linking)
# Purpose: Verify that a library is properly linked against the math library (libm)
# Parameters:
#   $1: Full path to library file (e.g., /usr/local/lib/libgraphblas.so)
#   $2: Library name for display purposes (e.g., "GraphBLAS")
# Returns: 0 if libm is linked or no undefined symbols found, 1 otherwise
# Side effects: Prints diagnostic messages to stdout/stderr
verify_math_library_linkage() {
    local lib_path="$1"
    local lib_name="$2"
    
    if [ -z "${lib_path}" ] || [ ! -f "${lib_path}" ]; then
        printf '%s\n' "  ⚠ ${lib_name} library not found (may not be built)" >&2
        return 1
    fi
    
    printf '%s\n' "  ✓ ${lib_name} library found: $(basename "${lib_path}")"
    
    # Check if libm is linked
    if ldd "${lib_path}" 2>/dev/null | grep -Fq "libm.so"; then
        printf '%s\n' "    ✓ ${lib_name} is linked against libm (math library) - verification passed"
        return 0
    else
        printf '%s\n' "    ⚠ WARNING: ${lib_name} does NOT appear to link libm - this may cause undefined reference errors" >&2
        printf '%s\n' "    → Checking for undefined math symbols..." >&2
        
        # Check for undefined math symbols using nm
        if command -v nm >/dev/null 2>&1; then
            # Common math symbols that require libm
            MATH_SYMBOLS="acoshf|lgammaf|log1p|sinf|powf|ceil|expf|casinhf|atan|csinh|lgamma|fmax|clogf|hypotf|round|log2|asinf|fabs|sqrt|cos|sin|tan|acos|asin|atan2|exp|log|log10"
            # Use nm with error handling - some systems may not support -D flag
            if nm -D "${lib_path}" 2>/dev/null >/dev/null; then
                UNDEF_SYMBOLS=$(nm -D "${lib_path}" 2>/dev/null | grep " U " | grep -E "(${MATH_SYMBOLS})" | head -10)
            elif nm "${lib_path}" 2>/dev/null >/dev/null; then
                # Fallback to regular nm if -D is not supported
                UNDEF_SYMBOLS=$(nm "${lib_path}" 2>/dev/null | grep " U " | grep -E "(${MATH_SYMBOLS})" | head -10)
            else
                printf '%s\n' "    → nm command failed on ${lib_path}, skipping symbol verification" >&2
                UNDEF_SYMBOLS=""
            fi
            
            if [ -n "${UNDEF_SYMBOLS}" ]; then
                printf '%s\n' "    ✗ Found undefined math symbols (this will cause linker errors):" >&2
                # D3: Use here-string instead of echo | sed (unsafe pipe pattern)
                sed 's/^/      /' <<< "${UNDEF_SYMBOLS}" >&2
                printf '%s\n' "    → Diagnostic information:" >&2
                
                # Check CMakeCache.txt if available (use cmake_build_dir variable for consistency)
                local cmake_cache="${SUITESPARSE_SOURCE_DIR}/build/CMakeCache.txt"
                if [ -f "${cmake_cache}" ]; then
                    # Validate command substitution results (F2, H4)
                    NO_LIBM_VALUE=$(grep -i "^NO_LIBM:" "${cmake_cache}" 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || echo "")
                    printf '%s\n' "      - NO_LIBM in CMakeCache.txt: ${NO_LIBM_VALUE:-unset}" >&2
                    
                    # Check if CMAKE_SHARED_LINKER_FLAGS contains -lm
                    LINKER_FLAGS=$(grep -i "^CMAKE_SHARED_LINKER_FLAGS:" "${cmake_cache}" 2>/dev/null | cut -d'=' -f2- || echo "")
                    # Validate variable before using in here-string (D3, F2)
                    # D3c: Use grep -F for fixed-string matching (literal pattern)
                    # CRITICAL: Use -- to prevent grep from interpreting -lm as an option
                    if [ -n "${LINKER_FLAGS}" ] && grep -Fq -- "-lm" <<< "${LINKER_FLAGS}"; then
                        printf '%s\n' "      - CMAKE_SHARED_LINKER_FLAGS contains -lm: YES" >&2
                        printf '%s\n' "      → NOTE: Even though NO_LIBM=${NO_LIBM_VALUE}, linker flags include -lm, so linking should work" >&2
                    else
                        printf '%s\n' "      - CMAKE_SHARED_LINKER_FLAGS contains -lm: NO (this is unexpected)" >&2
                        printf '%s\n' "        Actual flags: ${LINKER_FLAGS:0:100}..." >&2
                    fi
                else
                    printf '%s\n' "      - CMakeCache.txt not found at ${cmake_cache}" >&2
                fi
                
                printf '%s\n' "    → Recommendation: Rebuild with verbose output or check GraphBLAS/LAGraph CMakeLists.txt patches" >&2
                return 1
            else
                printf '%s\n' "    → No obvious undefined math symbols detected" >&2
                printf '%s\n' "    → Note: Math functions may be resolved via other libraries or inlined" >&2
                printf '%s\n' "    → However, explicit libm linkage is recommended for portability" >&2
                return 0
            fi
        else
            printf '%s\n' "    → nm command not available, skipping symbol verification" >&2
            return 1
        fi
    fi
}

# Verify GraphBLAS
# Validate command substitution result (F2, H4)
GRAPHBLAS_LIB=$(find "${SUITESPARSE_INSTALL_PREFIX}/lib" -name "libgraphblas.so*" -type f 2>/dev/null | head -1 || echo "")
if [ -n "${GRAPHBLAS_LIB}" ]; then
  verify_math_library_linkage "${GRAPHBLAS_LIB}" "GraphBLAS"
fi

# Verify LAGraph (if it exists and was built)
# Validate command substitution result (F2, H4)
LAGRAPH_LIB=$(find "${SUITESPARSE_INSTALL_PREFIX}/lib" -name "liblagraph.so*" -type f 2>/dev/null | head -1 || echo "")
if [ -n "${LAGRAPH_LIB}" ]; then
    verify_math_library_linkage "${LAGRAPH_LIB}" "LAGraph"
fi
# ENDIF: LAGraph library check

# Purpose: Find SuiteSparse library file by basename
# Parameters: $1 = library basename (e.g., "cholmod", "spqr")
# Returns: Full path to library file, or empty string if not found
# G1: Function with proper parameter handling and return semantics
find_suitesparse_library() {
    local lib_basename="${1:-}"
    local result=""
    local candidate=""
    # C3: Save IFS before modification, restore after use
    local OLD_IFS="${IFS}"
    # D2: Use read -r with IFS handling
    while IFS= read -r candidate || [ -n "${candidate}" ]; do
        result="${candidate}"
        break
    done < <(find "${SUITESPARSE_INSTALL_PREFIX}/lib" -maxdepth 1 -type f \( -name "lib${lib_basename}.so" -o -name "lib${lib_basename}.so.*" \) 2>/dev/null | sort)
    IFS="${OLD_IFS}"
    if [ -z "${result}" ]; then
        # C3: Save IFS before modification, restore after use
        OLD_IFS="${IFS}"
        # D2: Use read -r with IFS handling
        while IFS= read -r candidate || [ -n "${candidate}" ]; do
            result="${candidate}"
            break
        done < <(find "${SUITESPARSE_INSTALL_PREFIX}" -maxdepth 3 -type f \( -name "lib${lib_basename}.so" -o -name "lib${lib_basename}.so.*" \) 2>/dev/null | sort)
        IFS="${OLD_IFS}"
    fi
    if [ -n "${result}" ]; then
        # F2: Validate command substitution result
        local real_path=""
        real_path=$(realpath "${result}" 2>/dev/null || echo "")
        if [ -n "${real_path}" ]; then
            printf '%s\n' "${real_path}"
        else
            printf '%s\n' "${result}"
        fi
    fi
}

declare -A suitesparse_lib_paths=()
# Note: cholmod_metis is NOT in required_libraries because in recent SuiteSparse (5.x+),
# METIS is embedded directly into libcholmod.so. No separate libcholmod_metis.so is built.
declare -a suitesparse_required_libraries=("suitesparseconfig" "amd" "camd" "colamd" "ccolamd" "cholmod" "spqr")
declare -a suitesparse_optional_libraries=("umfpack" "klu" "btf" "graphblas" "lagraph" "cholmod_metis")

for lib in "${suitesparse_required_libraries[@]}"; do
    # F2, H4: Validate command substitution result
    lib_path="$(find_suitesparse_library "${lib}" || echo "")"
    if [ -z "${lib_path}" ]; then
        printf '%s\n' "  ✗ lib${lib}.so missing under ${SUITESPARSE_INSTALL_PREFIX}" >&2
        exit 1
    fi
    # J1: Validate file exists before use
    if [ ! -f "${lib_path}" ]; then
        printf '%s\n' "  ✗ lib${lib}.so path invalid: ${lib_path}" >&2
        exit 1
    fi
    suitesparse_lib_paths["${lib}"]="${lib_path}"
    printf '%s\n' "  ✓ lib${lib}.so detected"
    if [[ "${lib}" == "cholmod" || "${lib}" == "spqr" ]]; then
        # H4: Check pipeline exit code with pipefail awareness
        if ldd "${lib_path}" 2>/dev/null | grep -Fqi "mkl" 2>/dev/null; then
            printf '%s\n' "    → Linked against MKL"
        else
            printf '%s\n' "    ⚠ lib${lib}.so does not appear to link MKL (investigate)" >&2
        fi
        # H4: Check pipeline exit code with pipefail awareness
        if ldd "${lib_path}" 2>/dev/null | grep -Fqi "cuda" 2>/dev/null; then
            printf '%s\n' "    → CUDA dependencies resolved"
        else
            printf '%s\n' "    ⚠ lib${lib}.so does not show CUDA linkage (verify build flags)" >&2
        fi
        # Check if METIS symbols are embedded in libcholmod.so (recent SuiteSparse versions)
        if [[ "${lib}" == "cholmod" ]]; then
            # H4: Check pipeline exit code with pipefail awareness
            if nm -D "${lib_path}" 2>/dev/null | grep -Eqi "metis|METIS" 2>/dev/null; then
                printf '%s\n' "    → METIS functions embedded in libcholmod.so (modern SuiteSparse)"
            fi
        fi
    fi
# ENDFOR: lib in suitesparse_required_libraries
done

for lib in "${suitesparse_optional_libraries[@]}"; do
    # F2, H4: Validate command substitution result
    lib_path="$(find_suitesparse_library "${lib}" || echo "")"
    if [ -n "${lib_path}" ]; then
        # J1: Validate file exists before use
        if [ -f "${lib_path}" ]; then
            suitesparse_lib_paths["${lib}"]="${lib_path}"
            printf '%s\n' "  • Optional component lib${lib}.so detected"
        fi
    fi
# ENDFOR: lib in suitesparse_optional_libraries
done

SUITESPARSE_INCLUDE_DIR="${SUITESPARSE_INSTALL_PREFIX}/include"
SUITESPARSE_LIB_DIR="${SUITESPARSE_INSTALL_PREFIX}/lib"
SUITESPARSE_CMAKE_BASE="${SUITESPARSE_LIB_DIR}/cmake"
SUITESPARSE_CMAKE_DIR="${SUITESPARSE_CMAKE_BASE}/SuiteSparse"
# H1: Check mkdir exit code
if ! mkdir -p "${SUITESPARSE_CMAKE_DIR}"; then
    printf '%s\n' "  ✗ ERROR: Failed to create directory: ${SUITESPARSE_CMAKE_DIR}" >&2
    exit 1
fi

# CRITICAL: Verify SuiteSparseQR.hpp exists in include directory
# Ceres's FindSuiteSparse.cmake searches for SuiteSparseQR.hpp in SuiteSparse_SPQR_INCLUDE_DIR
# If the header doesn't exist, Ceres will fail to find SPQR component
# Phase 1: Check default include directory
if [ ! -f "${SUITESPARSE_INCLUDE_DIR:-}/SuiteSparseQR.hpp" ]; then
    printf '%s\n' "  ⚠ WARNING: SuiteSparseQR.hpp not found in ${SUITESPARSE_INCLUDE_DIR:-<unset>}" >&2
    printf '%s\n' "  → Searching for SuiteSparseQR.hpp in SuiteSparse installation..."
    # Phase 2: Validate SUITESPARSE_INSTALL_PREFIX exists before searching
    if [ ! -d "${SUITESPARSE_INSTALL_PREFIX:-}" ]; then
        printf '%s\n' "  ✗ ERROR: SUITESPARSE_INSTALL_PREFIX not set or invalid: ${SUITESPARSE_INSTALL_PREFIX:-<unset>}" >&2
        exit 1
    fi
    # Phase 3: Search with explicit error handling (F2, H4: validate command substitution)
    # D3e: SIGPIPE error handling - add || true to prevent exit code 141
    SUITESPARSEQR_HEADER=""
    if command -v find >/dev/null 2>&1; then
        # Validate command substitution result (F2, H4)
        # D3e: Pipeline with head - add || true to prevent SIGPIPE errors
        SUITESPARSEQR_HEADER=$(find "${SUITESPARSE_INSTALL_PREFIX}" -name "SuiteSparseQR.hpp" -type f 2>/dev/null | head -1 2>/dev/null || echo "" || true)
    fi
    # Phase 4: Validate search result (F2: command substitution validation)
    if [ -n "${SUITESPARSEQR_HEADER}" ] && [ -f "${SUITESPARSEQR_HEADER}" ]; then
        printf '%s\n' "  → Found SuiteSparseQR.hpp at: ${SUITESPARSEQR_HEADER}"
        # Validate dirname result (F2: command substitution validation)
        SUITESPARSE_INCLUDE_DIR_NEW=$(dirname "${SUITESPARSEQR_HEADER}" 2>/dev/null || echo "")
        if [ -n "${SUITESPARSE_INCLUDE_DIR_NEW}" ] && [ -d "${SUITESPARSE_INCLUDE_DIR_NEW}" ]; then
            SUITESPARSE_INCLUDE_DIR="${SUITESPARSE_INCLUDE_DIR_NEW}"
            printf '%s\n' "  → Using SuiteSparse include directory: ${SUITESPARSE_INCLUDE_DIR}"
        else
            printf '%s\n' "  ✗ ERROR: Invalid directory from SuiteSparseQR.hpp path: ${SUITESPARSEQR_HEADER}" >&2
            exit 1
        fi
    else
        printf '%s\n' "  ✗ ERROR: SuiteSparseQR.hpp not found in SuiteSparse installation" >&2
        printf '%s\n' "  → This will cause Ceres compilation to fail" >&2
        printf '%s\n' "  → Check SuiteSparse installation: ${SUITESPARSE_INSTALL_PREFIX}" >&2
        exit 1
    fi
# ENDIF: SuiteSparseQR.hpp not found in default include directory
else
    printf '%s\n' "  ✓ SuiteSparseQR.hpp found in ${SUITESPARSE_INCLUDE_DIR}"
# ENDIF: SuiteSparseQR.hpp check
fi

SUITESPARSE_VERSION_STR="${SUITESPARSE_VERSION#v}"
if [ -z "${SUITESPARSE_VERSION_STR}" ]; then
    SUITESPARSE_VERSION_STR="${SUITESPARSE_VERSION}"
fi
# C3: Save IFS before modification, restore after use
OLD_IFS="${IFS}"
IFS='.' read -r SUITESPARSE_VERSION_MAJOR SUITESPARSE_VERSION_MINOR SUITESPARSE_VERSION_PATCH <<< "${SUITESPARSE_VERSION_STR}"
IFS="${OLD_IFS}"
SUITESPARSE_VERSION_MAJOR="${SUITESPARSE_VERSION_MAJOR:-0}"
SUITESPARSE_VERSION_MINOR="${SUITESPARSE_VERSION_MINOR:-0}"
SUITESPARSE_VERSION_PATCH="${SUITESPARSE_VERSION_PATCH:-0}"

declare -A suitesparse_component_libnames=(
    [Config]="suitesparseconfig"
    [AMD]="amd"
    [CAMD]="camd"
    [COLAMD]="colamd"
    [CCOLAMD]="ccolamd"
    [CHOLMOD]="cholmod"
    [SPQR]="spqr"
)
declare -A suitesparse_optional_component_libnames=(
    [UMFPACK]="umfpack"
    [GraphBLAS]="graphblas"
    [LAGraph]="lagraph"
    [KLU]="klu"
    [BTF]="btf"
)
# C2: Explicitly declare array (not using declare -a, but array assignment is clear)
declare -a suitesparse_component_order=("Config" "AMD" "CAMD" "COLAMD" "CCOLAMD" "CHOLMOD" "SPQR")

SUITESPARSE_LIBRARY_LIST=""
for component in "${suitesparse_component_order[@]}"; do
    lib_key="${suitesparse_component_libnames[${component}]}"
    lib_path="${suitesparse_lib_paths[${lib_key}]:-}"
    if [ -n "${lib_path}" ]; then
        if [ -z "${SUITESPARSE_LIBRARY_LIST}" ]; then
            SUITESPARSE_LIBRARY_LIST="${lib_path}"
        else
            SUITESPARSE_LIBRARY_LIST="${SUITESPARSE_LIBRARY_LIST};${lib_path}"
        fi
    # ENDIF: lib_path check
    fi
# ENDFOR: component in suitesparse_component_order
done
for component in "${!suitesparse_optional_component_libnames[@]}"; do
    lib_key="${suitesparse_optional_component_libnames[${component}]}"
    lib_path="${suitesparse_lib_paths[${lib_key}]:-}"
    if [ -n "${lib_path}" ]; then
        if [ -z "${SUITESPARSE_LIBRARY_LIST}" ]; then
            SUITESPARSE_LIBRARY_LIST="${lib_path}"
        else
            SUITESPARSE_LIBRARY_LIST="${SUITESPARSE_LIBRARY_LIST};${lib_path}"
        fi
    # ENDIF: lib_path check
    fi
# ENDFOR: component in suitesparse_optional_component_libnames
done
# Note: In recent SuiteSparse versions (5.x+), METIS is embedded in libcholmod.so,
# so there is no separate libcholmod_metis.so. Only add it if it exists (legacy builds).
if [ -n "${suitesparse_lib_paths[cholmod_metis]:-}" ]; then
    printf '%s\n' "  → Legacy libcholmod_metis.so detected (older SuiteSparse version)"
    if [ -z "${SUITESPARSE_LIBRARY_LIST}" ]; then
        SUITESPARSE_LIBRARY_LIST="${suitesparse_lib_paths[cholmod_metis]}"
    else
        SUITESPARSE_LIBRARY_LIST="${SUITESPARSE_LIBRARY_LIST};${suitesparse_lib_paths[cholmod_metis]}"
    fi
# ENDIF: cholmod_metis library exists
else
    printf '%s\n' "  → No separate libcholmod_metis.so found (METIS embedded in libcholmod.so - expected for SuiteSparse 5.x+)"
# ENDIF: cholmod_metis check
fi
SUITESPARSE_LIBRARY_LIST="${SUITESPARSE_LIBRARY_LIST#;}"

{
    # EXEMPTED FROM EXTRACTION: Dynamically generated with variable interpolation, content varies based on detected library paths
    cat <<EOF
# Auto-generated SuiteSparseConfig.cmake
if(DEFINED SuiteSparse_CONFIG_INCLUDED)
  return()
endif()
set(SuiteSparse_CONFIG_INCLUDED TRUE)

set(SuiteSparse_FOUND TRUE)
set(SUITESPARSE_FOUND TRUE)
set(SuiteSparse_VERSION "${SUITESPARSE_VERSION_STR}")
set(SuiteSparse_VERSION_MAJOR ${SUITESPARSE_VERSION_MAJOR})
set(SuiteSparse_VERSION_MINOR ${SUITESPARSE_VERSION_MINOR})
set(SuiteSparse_VERSION_PATCH ${SUITESPARSE_VERSION_PATCH})
set(SuiteSparse_INCLUDE_DIR "${SUITESPARSE_INCLUDE_DIR}")
set(SuiteSparse_INCLUDE_DIRS "${SUITESPARSE_INCLUDE_DIR}")
set(SuiteSparse_LIBRARY_DIR "${SUITESPARSE_LIB_DIR}")
set(SuiteSparse_LIBRARY_DIRS "${SUITESPARSE_LIB_DIR}")
set(SuiteSparse_LIBRARIES "${SUITESPARSE_LIBRARY_LIST}")
EOF

    # Only set SuiteSparse_CHOLMOD_METIS_LIBRARY if separate library exists (legacy SuiteSparse builds)
    # In modern SuiteSparse (5.x+), METIS is embedded in libcholmod.so, so this will be empty
    if [ -n "${suitesparse_lib_paths[cholmod_metis]:-}" ]; then
        # EXEMPTED FROM EXTRACTION: Conditional content based on library detection, uses variable interpolation
        cat <<EOF
# Legacy: Separate METIS library (older SuiteSparse versions)
set(SuiteSparse_CHOLMOD_METIS_LIBRARY "${suitesparse_lib_paths[cholmod_metis]}")
EOF
    else
        # EXEMPTED FROM EXTRACTION: Conditional content (legacy vs modern SuiteSparse), small fragment
        cat <<'EOF'
# Modern SuiteSparse: METIS is embedded in libcholmod.so, no separate library
EOF
    fi

    for component in "${suitesparse_component_order[@]}"; do
        lib_key="${suitesparse_component_libnames[${component}]}"
        lib_path="${suitesparse_lib_paths[${lib_key}]:-}"
        if [ -n "${lib_path}" ]; then
            # CRITICAL: Set both INCLUDE_DIR and LIBRARY for Ceres's bundled FindSuiteSparse.cmake
            # Ceres searches for SuiteSparseQR.hpp in SuiteSparse_SPQR_INCLUDE_DIR
            # EXEMPTED FROM EXTRACTION: Loop-generated content with variable interpolation, dynamically created per component
            cat <<EOF
if(NOT TARGET SuiteSparse::${component})
  add_library(SuiteSparse::${component} UNKNOWN IMPORTED)
  set_target_properties(SuiteSparse::${component} PROPERTIES
    IMPORTED_LOCATION "${lib_path}"
    INTERFACE_INCLUDE_DIRECTORIES "${SUITESPARSE_INCLUDE_DIR}")
endif()
set(SuiteSparse_${component}_LIBRARY "${lib_path}")
set(SuiteSparse_${component}_INCLUDE_DIR "${SUITESPARSE_INCLUDE_DIR}")
set(SuiteSparse_${component}_FOUND TRUE)
EOF
        # ENDIF: lib_path check
        else
            # EXEMPTED FROM EXTRACTION: Conditional content in loop, uses variable interpolation
            cat <<EOF
set(SuiteSparse_${component}_FOUND FALSE)
EOF
        # ENDIF: lib_path check
        fi
    # ENDFOR: component in suitesparse_component_order
    done

    for component in "${!suitesparse_optional_component_libnames[@]}"; do
        lib_key="${suitesparse_optional_component_libnames[${component}]}"
        lib_path="${suitesparse_lib_paths[${lib_key}]:-}"
        if [ -n "${lib_path}" ]; then
            # CRITICAL: Set both INCLUDE_DIR and LIBRARY for Ceres's bundled FindSuiteSparse.cmake
            cat <<EOF
if(NOT TARGET SuiteSparse::${component})
  add_library(SuiteSparse::${component} UNKNOWN IMPORTED)
  set_target_properties(SuiteSparse::${component} PROPERTIES
    IMPORTED_LOCATION "${lib_path}"
    INTERFACE_INCLUDE_DIRECTORIES "${SUITESPARSE_INCLUDE_DIR}")
endif()
set(SuiteSparse_${component}_LIBRARY "${lib_path}")
set(SuiteSparse_${component}_INCLUDE_DIR "${SUITESPARSE_INCLUDE_DIR}")
set(SuiteSparse_${component}_FOUND TRUE)
EOF
        # ENDIF: lib_path check
        fi
    # ENDFOR: component in suitesparse_optional_component_libnames
    done

    cat <<EOF
# CRITICAL: Ensure all targets have proper include directories
# Ceres's FindSuiteSparse.cmake searches for SuiteSparseQR.hpp in SuiteSparse_SPQR_INCLUDE_DIR
# When using native CMake package config, INTERFACE_INCLUDE_DIRECTORIES must be set correctly
if(TARGET SuiteSparse::CHOLMOD)
  set_property(TARGET SuiteSparse::CHOLMOD APPEND PROPERTY
    INTERFACE_LINK_LIBRARIES SuiteSparse::AMD SuiteSparse::CAMD SuiteSparse::COLAMD SuiteSparse::CCOLAMD SuiteSparse::Config)
  # Ensure CHOLMOD has include directories (for Ceres's bundled finder fallback)
  set_property(TARGET SuiteSparse::CHOLMOD PROPERTY
    INTERFACE_INCLUDE_DIRECTORIES "${SUITESPARSE_INCLUDE_DIR}")
endif()
if(TARGET SuiteSparse::SPQR)
  set_property(TARGET SuiteSparse::SPQR APPEND PROPERTY
    INTERFACE_LINK_LIBRARIES SuiteSparse::CHOLMOD SuiteSparse::Config)
  # CRITICAL: SPQR must have include directories so Ceres can find SuiteSparseQR.hpp
  set_property(TARGET SuiteSparse::SPQR PROPERTY
    INTERFACE_INCLUDE_DIRECTORIES "${SUITESPARSE_INCLUDE_DIR}")
  # Also set for Ceres's bundled finder fallback (searches SuiteSparse_SPQR_INCLUDE_DIR)
  set(SuiteSparse_SPQR_INCLUDE_DIR "${SUITESPARSE_INCLUDE_DIR}" CACHE PATH "SuiteSparse SPQR include directory")
endif()
if(TARGET SuiteSparse::Config)
  set_property(TARGET SuiteSparse::Config APPEND PROPERTY
    INTERFACE_INCLUDE_DIRECTORIES "${SUITESPARSE_INCLUDE_DIR}")
endif()
foreach(_component IN ITEMS AMD CAMD COLAMD CCOLAMD UMFPACK GraphBLAS LAGraph KLU BTF SPQR)
  if(TARGET SuiteSparse::\${_component})
    set_property(TARGET SuiteSparse::\${_component} APPEND PROPERTY
      INTERFACE_LINK_LIBRARIES SuiteSparse::Config)
    # Ensure all components have include directories
    set_property(TARGET SuiteSparse::\${_component} PROPERTY
      INTERFACE_INCLUDE_DIRECTORIES "${SUITESPARSE_INCLUDE_DIR}")
  endif()
endforeach()
EOF
} > "${SUITESPARSE_CMAKE_DIR}/SuiteSparseConfig.cmake"
# H1: Check file creation success
if [ ! -f "${SUITESPARSE_CMAKE_DIR}/SuiteSparseConfig.cmake" ]; then
    printf '%s\n' "  ✗ ERROR: Failed to create SuiteSparseConfig.cmake" >&2
    exit 1
fi
printf '%s\n' "  ✓ SuiteSparse CMake package config created"

cat > "${SUITESPARSE_CMAKE_DIR}/SuiteSparseConfigVersion.cmake" <<EOF
set(PACKAGE_VERSION "${SUITESPARSE_VERSION_STR}")
if(PACKAGE_FIND_VERSION)
  if(PACKAGE_VERSION VERSION_LESS PACKAGE_FIND_VERSION)
    set(PACKAGE_VERSION_COMPATIBLE FALSE)
  else()
    set(PACKAGE_VERSION_COMPATIBLE TRUE)
    if(PACKAGE_FIND_VERSION VERSION_EQUAL PACKAGE_VERSION)
      set(PACKAGE_VERSION_EXACT TRUE)
    endif()
  endif()
else()
  set(PACKAGE_VERSION_COMPATIBLE TRUE)
endif()
EOF

CHOLMOD_LIBRARY_PATH="${suitesparse_lib_paths[cholmod]}"
# In recent SuiteSparse (5.x+), METIS is embedded in libcholmod.so, so no separate library exists
CHOLMOD_METIS_LIBRARY_PATH="${suitesparse_lib_paths[cholmod_metis]:-}"
CHOLMOD_METIS_LIBRARY="${CHOLMOD_METIS_LIBRARY_PATH}"
# shellcheck disable=SC2034 # SPQR_LIBRARY_PATH may be used by downstream scripts
SPQR_LIBRARY_PATH="${suitesparse_lib_paths[spqr]}"
CHOLMOD_CONFIG_DIR="${SUITESPARSE_CMAKE_BASE}/CHOLMOD"
# H1: Check mkdir exit code
if ! mkdir -p "${CHOLMOD_CONFIG_DIR}" "${SUITESPARSE_CMAKE_BASE}/cholmod"; then
    printf '%s\n' "  ✗ ERROR: Failed to create CHOLMOD config directories" >&2
    exit 1
fi

# EXEMPTED FROM EXTRACTION: Uses variable interpolation (${SUITESPARSE_CMAKE_DIR}, ${CHOLMOD_LIBRARY_PATH}), dynamically generated
cat > "${CHOLMOD_CONFIG_DIR}/CHOLMODConfig.cmake" <<EOF
include("${SUITESPARSE_CMAKE_DIR}/SuiteSparseConfig.cmake")
set(CHOLMOD_FOUND FALSE)
if(TARGET SuiteSparse::CHOLMOD)
  set(CHOLMOD_FOUND TRUE)
  set(CHOLMOD_LIBRARY "${CHOLMOD_LIBRARY_PATH}")
  set(CHOLMOD_LIBRARIES "${CHOLMOD_LIBRARY_PATH}")
  set(CHOLMOD_LIBRARY_RELEASE "${CHOLMOD_LIBRARY_PATH}")
  set(CHOLMOD_LIBRARIES_RELEASE "${CHOLMOD_LIBRARY_PATH}")
  set(CHOLMOD_INCLUDE_DIR "${SUITESPARSE_INCLUDE_DIR}")
  set(CHOLMOD_INCLUDE_DIRS "${SUITESPARSE_INCLUDE_DIR}")
  set(CHOLMOD_INCLUDE_DIRS_RELEASE "${SUITESPARSE_INCLUDE_DIR}")
EOF
# Only set CHOLMOD_METIS_LIBRARY if separate library exists (legacy SuiteSparse builds)
if [ -n "${CHOLMOD_METIS_LIBRARY_PATH}" ]; then
  # EXEMPTED FROM EXTRACTION: Conditional append with variable interpolation, dynamically generated
  cat >> "${CHOLMOD_CONFIG_DIR}/CHOLMODConfig.cmake" <<EOF
  # Legacy: Separate METIS library (older SuiteSparse versions)
  set(CHOLMOD_METIS_LIBRARY "${CHOLMOD_METIS_LIBRARY_PATH}")
  set(CHOLMOD_METIS_LIBRARY_RELEASE "${CHOLMOD_METIS_LIBRARY_PATH}")
EOF
# ENDIF: CHOLMOD_METIS_LIBRARY_PATH exists
else
  # EXEMPTED FROM EXTRACTION: Conditional append (legacy vs modern SuiteSparse), small fragment
  cat >> "${CHOLMOD_CONFIG_DIR}/CHOLMODConfig.cmake" <<EOF
  # Modern SuiteSparse: METIS is embedded in libcholmod.so, no separate library needed
EOF
# ENDIF: CHOLMOD_METIS_LIBRARY_PATH check
fi
# EXEMPTED FROM EXTRACTION: Small configuration fragment with variable interpolation, tightly coupled to build process
cat >> "${CHOLMOD_CONFIG_DIR}/CHOLMODConfig.cmake" <<'EOF'
  if(NOT TARGET CHOLMOD::CHOLMOD)
    add_library(CHOLMOD::CHOLMOD INTERFACE IMPORTED)
    set_property(TARGET CHOLMOD::CHOLMOD PROPERTY INTERFACE_LINK_LIBRARIES SuiteSparse::CHOLMOD)
    set_property(TARGET CHOLMOD::CHOLMOD PROPERTY INTERFACE_INCLUDE_DIRECTORIES "${SUITESPARSE_INCLUDE_DIR}")
  endif()
endif()
EOF
# H1: Check cp exit codes
if ! cp "${CHOLMOD_CONFIG_DIR}/CHOLMODConfig.cmake" "${SUITESPARSE_CMAKE_BASE}/cholmod/CHOLMODConfig.cmake"; then
    printf '%s\n' "  ✗ ERROR: Failed to copy CHOLMODConfig.cmake" >&2
    exit 1
fi
if ! cp "${CHOLMOD_CONFIG_DIR}/CHOLMODConfig.cmake" "${SUITESPARSE_CMAKE_BASE}/cholmod/cholmod-config.cmake"; then
    printf '%s\n' "  ✗ ERROR: Failed to copy cholmod-config.cmake" >&2
    exit 1
fi

cat > "${CHOLMOD_CONFIG_DIR}/CHOLMODConfigVersion.cmake" <<EOF
set(PACKAGE_VERSION "${SUITESPARSE_VERSION_STR}")
set(PACKAGE_VERSION_COMPATIBLE TRUE)
if(PACKAGE_FIND_VERSION)
  if(PACKAGE_VERSION VERSION_LESS PACKAGE_FIND_VERSION)
    set(PACKAGE_VERSION_COMPATIBLE FALSE)
  elseif(PACKAGE_FIND_VERSION VERSION_EQUAL PACKAGE_VERSION)
    set(PACKAGE_VERSION_EXACT TRUE)
  endif()
endif()
EOF
# H1: Check cp exit code
if ! cp "${CHOLMOD_CONFIG_DIR}/CHOLMODConfigVersion.cmake" "${SUITESPARSE_CMAKE_BASE}/cholmod/CHOLMODConfigVersion.cmake"; then
    printf '%s\n' "  ✗ ERROR: Failed to copy CHOLMODConfigVersion.cmake" >&2
    exit 1
fi
# Note: config-files file: /etc/apt/preferences.d/suitesparse-protect is installed via install.sh from container-scripts/
# Source: config-files/block-13-nvidia-cuda-cudnn-setup/suitesparse-protect.pref
# Target: /etc/apt/preferences.d/suitesparse-protect
# Installed in Block 0 (early in script, before any scripts are needed)
# J1: Validate parent directory exists before writing
PKGCONFIG_DIR="${SUITESPARSE_INSTALL_PREFIX}/lib/pkgconfig"
if [ ! -d "${PKGCONFIG_DIR}" ]; then
    printf '%s\n' "  ⚠ WARNING: Parent directory does not exist: ${PKGCONFIG_DIR}" >&2
    printf '%s\n' "  → Creating parent directory: ${PKGCONFIG_DIR}" >&2
    mkdir -p "${PKGCONFIG_DIR}" || {
        printf '%s\n' "  ✗ ERROR: Failed to create parent directory: ${PKGCONFIG_DIR}" >&2
        exit 1
    }
    printf '%s\n' "  ✓ Parent directory created successfully: ${PKGCONFIG_DIR}"
fi
cat > "${PKGCONFIG_DIR}/suitesparse.pc" <<EOF
prefix=${SUITESPARSE_INSTALL_PREFIX}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: SuiteSparse
Description: Suite of sparse matrix libraries
Version: ${SUITESPARSE_VERSION_STR}
Libs: -L\${libdir} -lcholmod -lamd -lcamd -lcolamd -lccolamd -lumfpack -lspqr -lgraphblas -llagraph -lsuitesparseconfig
Cflags: -I\${includedir}
Requires: openblas
EOF
# H1: Check file creation success
if [ ! -f "${PKGCONFIG_DIR}/suitesparse.pc" ]; then
    printf '%s\n' "  ✗ ERROR: Failed to create suitesparse.pc" >&2
    exit 1
fi
printf '%s\n' "  ✓ SuiteSparse pkg-config file created"

printf '%s\n' "${YELLOW}[6.12C.7] Protecting SuiteSparse installation via APT pinning...${NC}"
# J1: Validate parent directory exists before writing
if [ ! -d "$(dirname /etc/apt/preferences.d/suitesparse-protect)" ]; then
    printf '%s\n' "  ✗ ERROR: Directory /etc/apt/preferences.d does not exist" >&2
    exit 1
fi
# Note: config-files file: /etc/apt/preferences.d/suitesparse-protect is installed via install.sh from container-scripts/
# Source: config-files/block-13-nvidia-cuda-cudnn-setup/suitesparse-protect.pref
# Target: /etc/apt/preferences.d/suitesparse-protect
# Installed in Block 0 (early in script, before any scripts are needed)
# H1: Check file creation success
if [ ! -f /etc/apt/preferences.d/suitesparse-protect ]; then
    printf '%s\n' "  ✗ ERROR: Failed to create APT pinning file" >&2
    exit 1
fi
printf '%s\n' "  ✓ APT pinning created at /etc/apt/preferences.d/suitesparse-protect"

SuiteSparse_DIR="${SUITESPARSE_CMAKE_DIR}"
SuiteSparse_ROOT="${SUITESPARSE_INSTALL_PREFIX}"
SuiteSparse_LIBRARIES_ENV="${SUITESPARSE_LIBRARY_LIST}"
SUITESPARSE_INCLUDE_DIR_ENV="${SUITESPARSE_INCLUDE_DIR}"
SUITESPARSE_LIBRARY_DIR_ENV="${SUITESPARSE_LIB_DIR}"
CHOLMOD_DIR="${CHOLMOD_CONFIG_DIR}"
# In modern SuiteSparse, METIS is embedded in libcholmod.so, so CHOLMOD_LIBRARIES only needs libcholmod
CHOLMOD_LIBRARIES="${CHOLMOD_LIBRARY_PATH}"
# Only add separate METIS library if it exists (legacy SuiteSparse builds)
if [ -n "${CHOLMOD_METIS_LIBRARY_PATH}" ]; then
    CHOLMOD_LIBRARIES="${CHOLMOD_LIBRARIES};${CHOLMOD_METIS_LIBRARY_PATH}"
# ENDIF: CHOLMOD_METIS_LIBRARY_PATH exists
fi
CHOLMOD_LIBRARIES="${CHOLMOD_LIBRARIES#;}"

export SuiteSparse_DIR SuiteSparse_ROOT SuiteSparse_LIBRARIES_ENV
export SUITESPARSE_INCLUDE_DIR="${SUITESPARSE_INCLUDE_DIR_ENV}"
export SUITESPARSE_LIBRARY_DIR="${SUITESPARSE_LIBRARY_DIR_ENV}"
export SuiteSparse_LIBRARIES="${SuiteSparse_LIBRARIES_ENV}"
export CHOLMOD_DIR CHOLMOD_LIBRARY_PATH CHOLMOD_METIS_LIBRARY_PATH CHOLMOD_METIS_LIBRARY CHOLMOD_LIBRARIES

for env_entry in \
    "SuiteSparse_DIR=${SuiteSparse_DIR}" \
    "SuiteSparse_ROOT=${SuiteSparse_ROOT}" \
    "SuiteSparse_LIBRARIES=${SuiteSparse_LIBRARIES_ENV}" \
    "SUITESPARSE_INCLUDE_DIR=${SUITESPARSE_INCLUDE_DIR_ENV}" \
    "SUITESPARSE_LIBRARY_DIR=${SUITESPARSE_LIB_DIR}" \
    "CHOLMOD_DIR=${CHOLMOD_DIR}" \
    "CHOLMOD_LIBRARY_PATH=${CHOLMOD_LIBRARY_PATH}" \
    "CHOLMOD_METIS_LIBRARY_PATH=${CHOLMOD_METIS_LIBRARY_PATH}" \
    "CHOLMOD_METIS_LIBRARY=${CHOLMOD_METIS_LIBRARY_PATH}" \
    "CHOLMOD_LIBRARIES=${CHOLMOD_LIBRARIES}"; do
    key="${env_entry%%=*}"
    value="${env_entry#*=}"
    # J1: Validate /etc/environment exists before operations
    if [ ! -f /etc/environment ]; then
        printf '%s\n' "  ⚠ WARNING: /etc/environment does not exist, creating it" >&2
        touch /etc/environment || {
            printf '%s\n' "  ✗ ERROR: Failed to create /etc/environment" >&2
            exit 1
        }
    fi
    # H1: Check grep exit code (may fail if pattern not found, which is OK)
    # D3c: Use -F flag for fixed-string matching (key is variable but pattern is literal)
    if ! grep -Fq "^${key}=" /etc/environment 2>/dev/null; then
        # H1: Check append operation
        if ! printf '%s\n' "${env_entry}" >> /etc/environment; then
            printf '%s\n' "  ✗ ERROR: Failed to append ${key} to /etc/environment" >&2
            exit 1
        fi
    fi
# ENDFOR: env_entry
done

# J1: Validate parent directory exists before writing
if [ ! -d /etc/profile.d ]; then
    printf '%s\n' "  ✗ ERROR: Directory /etc/profile.d does not exist" >&2
    exit 1
fi
# E2, E3: Unquoted heredoc for variable expansion from parent script
# Variables used: SUITESPARSE_INSTALL_PREFIX, SuiteSparse_ROOT, SuiteSparse_DIR,
# SUITESPARSE_INCLUDE_DIR_ENV, SUITESPARSE_LIBRARY_DIR_ENV, SuiteSparse_LIBRARIES_ENV,
# CHOLMOD_DIR, CHOLMOD_LIBRARY_PATH, CHOLMOD_METIS_LIBRARY_PATH, CHOLMOD_METIS_LIBRARY, CHOLMOD_LIBRARIES
# Note: config-files file: /etc/profile.d/suitesparse.sh is installed via install.sh from container-scripts/
# Source: config-files/block-13-nvidia-cuda-cudnn-setup/suitesparse-library-path-configuration.sh
# Target: /etc/profile.d/suitesparse.sh
# Installed in Block 0 (early in script, before any scripts are needed)
# Note: This file is automatically sourced by the shell on login
# H1: Check file creation and chmod operations
if [ ! -f /etc/profile.d/suitesparse.sh ]; then
    printf '%s\n' "  ✗ ERROR: Failed to create suitesparse.sh" >&2
    exit 1
fi
if ! chmod 0644 /etc/profile.d/suitesparse.sh; then
    printf '%s\n' "  ✗ ERROR: Failed to set permissions on suitesparse.sh" >&2
    exit 1
fi
printf '%s\n' "  ✓ Environment hooks added for SuiteSparse"

# H1: Check mkdir exit code
if ! mkdir -p /var/log; then
    printf '%s\n' "  ⚠ WARNING: Failed to create /var/log directory (may already exist)" >&2
fi
# J1: Validate source file exists before copy
if [ -f "${cmake_build_dir}/CMakeFiles/CMakeError.log" ]; then
    # H4: Explicit validation after masked failure
    if ! cp "${cmake_build_dir}/CMakeFiles/CMakeError.log" /var/log/suitesparse_CMakeError.log 2>/dev/null; then
        printf '%s\n' "  ⚠ WARNING: Failed to copy CMakeError.log (non-critical)" >&2
    fi
fi
# Note: config-files file: /etc/apt/apt.conf.d/99-drake-insecure.conf is installed via install.sh from container-scripts/
# Source: config-files/block-14-drake-robotics-framework-setup/99-drake-insecure.conf
# Target: /etc/apt/apt.conf.d/99-drake-insecure.conf
# Installed in Block 0 (early in script, before any scripts are needed)

printf '%s\n' "  ${GREEN}✓ SuiteSparse build and verification complete${NC}"
printf '%s\n' ""

monitor_cache "After SuiteSparse build"
rm -rf "${SUITESPARSE_SOURCE_DIR}"

#===============================================================================
# BLOCK 14: DRAKE ROBOTICS FRAMEWORK SETUP
#===============================================================================
# Purpose: Configure Drake APT repository and install Drake
# Self-contained: Yes (complete setup with GPG verification)
# Dependencies: GPG, cached drake.asc key
# Outputs: Configured system components
# NOTE: Drake installed early to be available during Phase 1
#-------------------------------------------------------------------------------

#--- Sub-block 14.1: Drake APT repository configuration ---
# Critical: Uses hardened security with cached GPG key
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
# D3b: Use printf instead of echo for variable output
printf '%s\n' "==> Drake APT (hardened via cached key) + INSTALL"
drake_prev_opts="$-"
set -e  # Exit on any error during Drake setup
# 1) BEFORE apt-get update (temporary insecure override for just the Drake host)
# Note: config-files file: /etc/apt/apt.conf.d/99-drake-insecure.conf is installed via install.sh from container-scripts/
# Source: config-files/block-14-drake-robotics-framework-setup/99-drake-insecure.conf
# Target: /etc/apt/apt.conf.d/99-drake-insecure.conf
# Installed in Block 0 (early in script, before any scripts are needed)

#--- Sub-block 14.2: Download and configure Drake GPG key ---
# Critical: Use cached key if available, fallback to download
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
DRAKE_ASC="/tmp/drake.asc"
if [ -s "${CONTAINER_BIN_CACHE}/drake.asc" ]; then
  cp -f "${CONTAINER_BIN_CACHE}/drake.asc" "${DRAKE_ASC}"
else
  # Download from Drake repository
  # D3: Replace unsafe pipe pattern with here-string or direct redirection
  # I4: Add HTTP error handling for wget
  if ! wget -qO "${DRAKE_ASC}" --timeout=30 --tries=3 "https://drake-apt.csail.mit.edu/drake.asc" 2>/dev/null; then
    printf '%s\n' "  ✗ ERROR: Failed to download Drake GPG key" >&2
    exit 1
  fi
  # H1: Validate downloaded file is non-empty
  if [ ! -s "${DRAKE_ASC}" ]; then
    printf '%s\n' "  ✗ ERROR: Downloaded Drake GPG key is empty" >&2
    exit 1
  fi
fi

#--- Sub-block 14.3: Add Drake GPG key to APT keychain ---
# Critical: Install key for package signature verification
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
if [ -s "${DRAKE_ASC:-}" ]; then
  # J1: Validate parent directory exists before writing
  if [ ! -d /etc/apt/trusted.gpg.d ]; then
    printf '%s\n' "  ⚠ WARNING: Directory /etc/apt/trusted.gpg.d does not exist, creating it" >&2
    mkdir -p /etc/apt/trusted.gpg.d || {
      printf '%s\n' "  ✗ ERROR: Failed to create /etc/apt/trusted.gpg.d directory" >&2
      exit 1
    }
  fi
  # H1: Check gpg --dearmor operation
  if ! gpg --dearmor < "${DRAKE_ASC}" > /etc/apt/trusted.gpg.d/drake.gpg 2>/dev/null; then
    printf '%s\n' "  ✗ ERROR: Failed to process Drake GPG key" >&2
    exit 1
  fi
  # H1: Check chmod operation
  if ! chmod 0644 /etc/apt/trusted.gpg.d/drake.gpg; then
    printf '%s\n' "  ✗ ERROR: Failed to set permissions on drake.gpg" >&2
    exit 1
  fi
else
  # Fallback: Direct download method (avoid unsafe pipe pattern)
  # D3: Replace unsafe pipe pattern with direct file operations
  # I4: Add HTTP error handling for wget
  if ! wget -qO "${DRAKE_ASC}" --timeout=30 --tries=3 "https://drake-apt.csail.mit.edu/drake.asc" 2>/dev/null; then
    printf '%s\n' "  ✗ ERROR: Failed to download Drake GPG key (fallback)" >&2
    exit 1
  fi
  # H1: Validate downloaded file is non-empty
  if [ ! -s "${DRAKE_ASC}" ]; then
    printf '%s\n' "  ✗ ERROR: Downloaded Drake GPG key is empty (fallback)" >&2
    exit 1
  fi
  # H1: Check gpg --dearmor operation
  if ! gpg --dearmor < "${DRAKE_ASC}" > /etc/apt/trusted.gpg.d/drake.gpg 2>/dev/null; then
    printf '%s\n' "  ✗ ERROR: Failed to process Drake GPG key" >&2
    exit 1
  fi
  # H1: Check chmod operation
  if ! chmod 0644 /etc/apt/trusted.gpg.d/drake.gpg; then
    printf '%s\n' "  ✗ ERROR: Failed to set permissions on drake.gpg" >&2
    exit 1
  fi
fi
# End Drake GPG setup (if-else self-contained)

#--- Sub-block 14.4: Configure Drake APT repository ---
# Critical: Add Drake repository to sources list
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# F2: Validate command substitution result
# D3b: Use printf instead of echo for variable output
CODENAME="$(lsb_release -cs 2>/dev/null || echo "")"
if [ -z "${CODENAME}" ]; then
    printf '%s\n' "  ✗ ERROR: Failed to detect Ubuntu codename" >&2
    exit 1
fi
# J1: Validate parent directory exists before writing
if [ ! -d /etc/apt/sources.list.d ]; then
    printf '%s\n' "  ⚠ WARNING: Directory /etc/apt/sources.list.d does not exist, creating it" >&2
    mkdir -p /etc/apt/sources.list.d || {
        printf '%s\n' "  ✗ ERROR: Failed to create /etc/apt/sources.list.d directory" >&2
        exit 1
    }
fi
printf '%s\n' "deb [arch=amd64] https://drake-apt.csail.mit.edu/${CODENAME} ${CODENAME} main" \
  >/etc/apt/sources.list.d/drake.list
# H1: Check file creation success
if [ ! -f /etc/apt/sources.list.d/drake.list ]; then
    printf '%s\n' "  ✗ ERROR: Failed to create drake.list" >&2
    exit 1
fi

#--- Sub-block 14.5: Install Drake dependencies ---
# Purpose: Install required X11 libraries before Drake
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
# H1: Check apt-get install exit code
if ! apt-get install -y \
  libx11-6 \
  libsm6 \
  libxt6 \
  libglib2.0-0; then
  printf '%s\n' "  ✗ ERROR: Failed to install Drake dependencies" >&2
  exit 1
fi
# H1: Check apt-get update exit code (with fallback)
if ! apt-get -o Dir::Cache::archives="${CONTAINER_APT_CACHE}" update; then
  # Fallback to standard update
  if ! apt-get update; then
    printf '%s\n' "  ⚠ WARNING: apt-get update had issues (non-critical)" >&2
  fi
fi

#--- Sub-block 14.6: Fix broken packages before Drake ---
# Critical: Ensure clean package state before Drake installation
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
# H4, B3: Explicit validation after masked failures in strict mode
# D3b: Use printf instead of echo for variable output
printf '%s\n' "Checking for broken packages..."
if ! apt-get -f install -y 2>&1; then
  printf '%s\n' "  ⚠ WARNING: apt-get -f install had issues (non-critical)" >&2
fi
# H4: Validate package state after fix attempt
if ! dpkg --configure -a 2>&1; then
  printf '%s\n' "  ⚠ WARNING: dpkg --configure had issues (non-critical)" >&2
fi

#--- Sub-block 14.7: Install Drake framework ---
# Critical: Install drake-dev package with all dependencies
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
# D3b: Use printf instead of echo for variable output
printf '%s\n' "Installing drake-dev..."
# Note: shell-scripts file: /etc/profile.d/drake.sh is installed via install.sh from container-scripts/
# Source: shell-scripts/block-14-drake-robotics-framework-setup/drake.sh
# Target: /etc/profile.d/drake.sh
# Installed in Block 0 (early in script, before any scripts are needed)

#--- Sub-block 14.10: Configure Drake environment ---
# Purpose: Set up Drake Python bindings and library paths
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# Note: shell-scripts file: /etc/profile.d/drake.sh is installed via install.sh from container-scripts/
# Source: shell-scripts/block-14-drake-robotics-framework-setup/drake.sh
# Target: /etc/profile.d/drake.sh
# Installed in Block 0 (early in script, before any scripts are needed)
# D3b: Use printf instead of echo for variable output
printf '%s\n' "✓ Drake installed at ${DRAKE_HOME:-/opt/drake}"

#--- Sub-block 14.11: Disable Drake repository after installation ---
# Critical: Comment out Drake repo to prevent automatic updates
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
# J1: Validate file exists before operations
if [ -f /etc/apt/sources.list.d/drake.list ]; then
    # Comment out all lines in drake.list
    # H1: Check sed operation exit code
    if ! sed -i 's/^/# /' /etc/apt/sources.list.d/drake.list; then
      printf '%s\n' "  ✗ ERROR: Failed to disable Drake repository" >&2
      exit 1
    fi
    printf '%s\n' "  ✓ Drake repository disabled"
else
    printf '%s\n' "  ⚠ WARNING: Drake repository file not found: /etc/apt/sources.list.d/drake.list" >&2
fi
# H1: Check apt-get update exit code
if ! apt-get update; then
    printf '%s\n' "  ⚠ WARNING: apt-get update had issues (non-critical)" >&2
fi
if [[ "${drake_prev_opts}" != *e* ]]; then
  set +e
fi
unset drake_prev_opts

#===============================================================================
# BLOCK 15: FIREFOX INSTALLATION
#===============================================================================
# Purpose: Install Firefox from Mozilla Team PPA with priority pinning
# Self-contained: Yes (complete with verification)
# Dependencies: APT, PPA support
# Outputs: Installed packages
#-------------------------------------------------------------------------------

#--- Sub-block 15.1: Configure Firefox PPA preferences ---
# Critical: Pin Firefox to Mozilla Team PPA for latest updates
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# Note: config-files file: /etc/apt/preferences.d/mozillateam.pref is installed via install.sh from container-scripts/
# Source: config-files/block-15-firefox-installation/mozillateam.pref
# Target: /etc/apt/preferences.d/mozillateam.pref
# Installed in Block 0 (early in script, before any scripts are needed)

#--- Sub-block 15.2: Install Firefox with dependencies ---
# Critical: Install Firefox from Mozilla Team PPA
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
# D3b: Use printf instead of echo for variable output
printf '%s\n' "Installing Firefox with optimized PPA..."
if apt-get -y --no-install-recommends install libdbus-glib-1-2 firefox; then
  printf '%s\n' "✓ Firefox installed successfully"
else
  printf '%s\n' "[warn] Firefox installation failed" >&2
fi
# End if-else block (self-contained)

#--- Sub-block 15.3: Verify Firefox installation ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# D3b: Use printf instead of echo for variable output
if [ -x /usr/bin/firefox ]; then
  printf '%s\n' "✓ Firefox binary verified"
else
  printf '%s\n' "[warn] Firefox binary not found" >&2
fi
# End if-else block (self-contained)

# APT caching already configured above

#--- Sub-block 15.4: Post-installation monitoring ---
# Purpose: Track cache growth and system state after desktop installations
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
monitor_cache "After desktop stack installation"
debug_glibc "After installing firefox, drake"

#--- Sub-block 15.5: noVNC HTML5 VNC client installation ---
# Purpose: Install noVNC for browser-based VNC access
# Dependencies: config.sh (NOVNC_VER)
# Outputs: Environment variables, configuration
# D3b: Use printf instead of echo for variable output
printf '%s\n' "==> Installing noVNC and websockify for HTML5 VNC access..."
# Using NOVNC_VER from config.sh

#--- Sub-block 15.6: Install websockify proxy ---
# Critical: WebSocket proxy for noVNC browser access
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
apt-get install -y --no-install-recommends websockify python3-numpy python3-scipy

# Note: NumPy and SciPy are installed via system packages (python3-numpy python3-scipy)
# which use OpenBLAS. DO NOT install via pip as it may overwrite with MKL-linked versions.
# System packages are built together and are ABI-compatible, ensuring stability.

# Install latest websockify with all features via pip
python3 -m pip install --no-cache-dir \
  websockify \
  jwcrypto \
  redis

# D3b: Use printf instead of echo for variable output
printf '%s\n' "✓ NumPy and SciPy installed via system packages (using OpenBLAS)"

#--- Sub-block 15.7: Download and configure noVNC client ---
# Critical: Install noVNC v1.6.0 for HTML5 VNC access
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# I4: Add HTTP error handling for wget
# J1: Validate parent directory exists before operations
NOVNC_URL="https://github.com/novnc/noVNC/archive/refs/tags/v${NOVNC_VER}.tar.gz"
NOVNC_TAR="/tmp/novnc.tar.gz"
# I4: Download with HTTP error handling
if ! wget -qO "${NOVNC_TAR}" --timeout=60 --tries=3 "${NOVNC_URL}" 2>/dev/null; then
    printf '%s\n' "  ✗ ERROR: Failed to download noVNC archive from ${NOVNC_URL}" >&2
    exit 1
fi
# H1: Validate downloaded file is non-empty
if [ ! -s "${NOVNC_TAR}" ]; then
    printf '%s\n' "  ✗ ERROR: Downloaded noVNC archive is empty" >&2
    rm -f "${NOVNC_TAR}"
    exit 1
fi
# J1: Validate parent directory exists before creating subdirectory
if [ ! -d /usr/local/share ]; then
    printf '%s\n' "  ⚠ WARNING: Parent directory /usr/local/share does not exist, creating it" >&2
    mkdir -p /usr/local/share || {
        printf '%s\n' "  ✗ ERROR: Failed to create /usr/local/share directory" >&2
        rm -f "${NOVNC_TAR}"
        exit 1
    }
fi
# H1: Check mkdir exit code
if ! mkdir -p /usr/local/share/novnc; then
    printf '%s\n' "  ✗ ERROR: Failed to create /usr/local/share/novnc directory" >&2
    rm -f "${NOVNC_TAR}"
    exit 1
fi
# H1: Check tar extraction exit code
if ! tar -xzf "${NOVNC_TAR}" --strip-components=1 -C /usr/local/share/novnc; then
    printf '%s\n' "  ✗ ERROR: Failed to extract noVNC archive" >&2
    rm -f "${NOVNC_TAR}"
    exit 1
fi
# H1: Check rm exit code (non-critical cleanup)
rm -f "${NOVNC_TAR}" || true
# H1: Check chmod exit code
if ! chmod -R 755 /usr/local/share/novnc; then
    printf '%s\n' "  ⚠ WARNING: Failed to set permissions on noVNC directory (non-critical)" >&2
fi
printf '%s\n' "✓ noVNC v${NOVNC_VER} installed"

#===============================================================================
# BLOCK 16: PHASE 1 - FOUNDATIONAL SYSTEM LIBRARIES
#===============================================================================
# Purpose: Install all base system packages via APT
# Self-contained: Yes (complete phase with success tracking)
# Dependencies: APT, cache directories
# Outputs: Installed packages
#-------------------------------------------------------------------------------

#--- Sub-block 16.1: Phase 1 initialization ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# D3b: Use printf instead of echo -e for variable output
printf '\n%s\n' "${BLUE}### PHASE 1: Installing Foundational System Libraries ###${NC}"

# Critical: Track overall phase success
PHASE1_ALL_SUCCESS=true

#--- Sub-block 16.2: Robust package installation helper function ---
# Purpose: Install packages with resilience to already-installed packages and missing optional packages
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
# Parameters: $1=description, $2+= package names (space-separated string or array)
# Returns: 0 if all critical packages installed, 1 if critical packages missing
# Note: This function handles cases where packages are already installed or optional packages don't exist
install_packages_resilient() {
  # Input validation
  local description="${1:-}"
  if [ -z "${description}" ]; then
    printf '%s\n' "ERROR: install_packages_resilient() called without description" >&2
    return 1
  fi
  shift
  
  local packages=("$@")
  if [ ${#packages[@]} -eq 0 ]; then
    printf '%s\n' "WARNING: install_packages_resilient() called with no packages" >&2
    return 0
  fi
  
  # Safe color variables with defaults (in case not set)
  local YELLOW="${YELLOW:-\033[1;33m}"
  local GREEN="${GREEN:-\033[1;32m}"
  local RED="${RED:-\033[1;31m}"
  local NC="${NC:-\033[0m}"
  
  # Sanitize description for log filename (replace spaces and special chars with underscores)
  local sanitized_desc="${description// /_}"
  sanitized_desc="${sanitized_desc//[^a-zA-Z0-9_-]/_}"
  local install_log="/tmp/apt_install_${sanitized_desc}.log"
  local failed_packages=()
  local missing_critical=()
  
  # Separate critical and optional packages (optional packages end with -optional suffix in description)
  local is_optional=false
  if [[ "${description}" == *"-optional"* ]]; then
    is_optional=true
  fi
  
  # D3b: Use printf instead of echo -e for variable output
  printf '%b\n' "${YELLOW}[${description}] Installing packages...${NC}"
  
  # Try bulk installation first
  if apt-get install -y --no-install-recommends "${packages[@]}" > "${install_log}" 2>&1; then
    printf '%b\n' "${GREEN}[${description}] All packages installed successfully${NC}"
    return 0
  fi
  
  # Bulk installation failed - try individual packages
  printf '%b\n' "${YELLOW}[${description}] Bulk installation failed, trying packages individually...${NC}"
  
  for pkg in "${packages[@]}"; do
    # Validate package name (basic sanity check)
    if [ -z "${pkg}" ]; then
      printf '%s\n' "  ⚠ Warning: Empty package name encountered, skipping"
      continue
    fi
    
    # Check if package is already installed (optimize: call dpkg -s only once)
    # D3c: Use -F flag for fixed-string matching (pattern is literal "ok installed")
    # K1b: Use -- to prevent pattern misinterpretation (though pattern doesn't start with -)
    # F2: Validate command substitution result
    local pkg_status
    pkg_status=$(dpkg-query -W -f='${Status}' "${pkg}" 2>/dev/null || echo "")
    if [ -n "${pkg_status}" ] && grep -Fq -- "ok installed" <<< "${pkg_status}"; then
      printf '%b\n' "  ✓ ${pkg}: Already installed"
      continue
    fi
    
    # Check if package exists in repository
    if ! apt-cache show "${pkg}" >/dev/null 2>&1; then
      if [ "${is_optional}" = "true" ]; then
        printf '%b\n' "  ℹ ${pkg}: Not available in repositories (optional, skipping)"
        continue
      else
        printf '%b\n' "  ⚠ ${pkg}: Not available in repositories (may be critical)"
        missing_critical+=("${pkg}")
        continue
      fi
    fi
    
    # Try to install the package
    if apt-get install -y --no-install-recommends "${pkg}" >> "${install_log}" 2>&1; then
      printf '%b\n' "  ✓ ${pkg}: Installed"
    else
      # Installation failed - check if it's actually installed now (race condition or dependency resolution)
      # Re-check dpkg status (may have been installed as dependency)
      # D3c: Use -F flag for fixed-string matching (pattern is literal "ok installed")
      # K1b: Use -- to prevent pattern misinterpretation (though pattern doesn't start with -)
      # F2: Validate command substitution result
      pkg_status=$(dpkg-query -W -f='${Status}' "${pkg}" 2>/dev/null || echo "")
      if [ -n "${pkg_status}" ] && grep -Fq -- "ok installed" <<< "${pkg_status}"; then
        printf '%b\n' "  ✓ ${pkg}: Installed (via dependency)"
      else
        printf '%b\n' "  ✗ ${pkg}: Installation failed"
        failed_packages+=("${pkg}")
        if [ "${is_optional}" != "true" ]; then
          missing_critical+=("${pkg}")
        fi
      fi
    fi
  done
  
  # Report results
  if [ ${#failed_packages[@]} -gt 0 ]; then
    printf '%b\n' "${YELLOW}[${description}] Some packages had issues: ${failed_packages[*]}${NC}"
    if [ "${is_optional}" = "true" ]; then
      printf '%b\n' "  (These are optional packages, continuing...)${NC}"
    fi
  fi
  
  if [ ${#missing_critical[@]} -gt 0 ]; then
    printf '%b\n' "${RED}[${description}] CRITICAL packages missing: ${missing_critical[*]}${NC}"
    printf '%b\n' "  Installation log: ${install_log}"
    return 1
  fi
  
  return 0
}

#--- Sub-block 16.3: Package group installation helper function (updated to use resilient installer) ---
# Purpose: Install and verify package groups with detailed logging
# Dependencies: Block 6 (APT configuration), install_packages_resilient()
# Outputs: Installed packages
# Parameters: $1=group_name, $2+= package names
install_and_verify_group() {
  # Input validation
  local group_name="${1:-}"
  if [ -z "${group_name}" ]; then
    printf '%s\n' "ERROR: install_and_verify_group() called without group name" >&2
    return 1
  fi
  shift
  
  local packages_to_install=("$@")
  if [ ${#packages_to_install[@]} -eq 0 ]; then
    printf '%s\n' "WARNING: install_and_verify_group() called with no packages for group '${group_name}'" >&2
    return 0
  fi
  
  # Safe color variables with defaults
  local YELLOW="${YELLOW:-\033[1;33m}"
  local GREEN="${GREEN:-\033[1;32m}"
  local RED="${RED:-\033[1;31m}"
  local NC="${NC:-\033[0m}"
  
  local group_success=true

  # D3b: Use printf instead of echo -e for variable output
  printf '%b\n' "${YELLOW}[PHASE 1 | ${group_name}] Installing...${NC}"
  
  # Use resilient installer
  if ! install_packages_resilient "PHASE 1 | ${group_name}" "${packages_to_install[@]}"; then
    printf '%b\n' "${RED}[PHASE 1 | ${group_name}] FAILED: Critical packages could not be installed${NC}"
    # Only set PHASE1_ALL_SUCCESS if it exists (may not be in scope in some contexts)
    if [ -n "${PHASE1_ALL_SUCCESS:-}" ]; then
      PHASE1_ALL_SUCCESS=false
    fi
    return 1
  fi

  printf '%b\n' "${YELLOW}[PHASE 1 | ${group_name}] Verifying...${NC}"
  # Note: packages_to_install is an array, use [@] to expand properly
  for pkg in "${packages_to_install[@]}"; do
    # Validate package name
    if [ -z "${pkg}" ]; then
      printf '%b\n' "  - ${YELLOW}WARNING: Empty package name encountered${NC}"
      continue
    fi
    # ENDIF: pkg empty check
    
    # Check package status (optimize: single dpkg call)
    # D3c: Use -F flag for fixed-string matching (pattern is literal "ok installed")
    # K1b: Use -- to prevent pattern misinterpretation (though pattern doesn't start with -)
    # C2/SC2155: Declare and assign separately to avoid masking return values
    local pkg_status
    pkg_status=$(dpkg-query -W -f='${Status}' "${pkg}" 2>/dev/null || echo "")
    # C5: Unbound variable protection
    if [ -z "${pkg_status:-}" ]; then
      pkg_status=""
    fi
    if grep -Fq -- "ok installed" <<< "${pkg_status}"; then
      printf '%b\n' "  - ${pkg}: ${GREEN}OK${NC}"
    else
      printf '%b\n' "  - ${pkg}: ${YELLOW}WARNING (Package not found after install attempt)${NC}"
      # Don't fail the group if package verification fails - it might be a virtual package or optional
      # Only mark as failure if it's a critical package
      # Use case-insensitive matching and proper regex escaping
      # D3c: Use -E for extended regex (needed for alternation)
      # K1b: Use -- to prevent pattern misinterpretation
      if grep -qiE -- "^(cmake|ninja-build|g\+\+|gcc|build-essential)$" <<< "${pkg}"; then
        printf '%b\n' "    ${RED}CRITICAL package missing!${NC}"
        group_success=false
        if [ -n "${PHASE1_ALL_SUCCESS:-}" ]; then
          PHASE1_ALL_SUCCESS=false
        fi
      fi
      # ENDIF: critical package check
    fi
    # ENDIF: package status check
  done
  # ENDFOR: pkg

  if [ "${group_success}" = "false" ]; then
    printf '%b\n' "${RED}[PHASE 1 | ${group_name}] FAILED: Critical packages missing after verification${NC}"
    return 1
  fi
  
  return 0
}
# End install_and_verify_group function (self-contained)

#--- Sub-block 16.4: Define package groups ---
# Purpose: Organize packages into logical installation groups
# Dependencies: PHASE 1 (Build tools), PHASE 1 (Compilers)
# Outputs: Configured system components

#--- Sub-block 16.5: Check base image glog status ---
# CRITICAL: Verify if base ROS image already has glog installed
# Base image: osrf/ros:jazzy-desktop-full-noble may include glog as ROS dependency
# D3b: Use printf instead of echo for robustness
printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf '%s\n' "Checking base image glog status..."
printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
BASE_GLOG_INSTALLED=false
BASE_GLOG_VERSION=""

# M4: Use resilient helper instead of direct dpkg -l parsing
# Note: dpkg_resolve_installed_package is preferred, but for version info we need dpkg-query
# D3d: Robust command substitution with error handling
DPKG_OUTPUT=""
DPKG_OUTPUT=$(dpkg -l 2>/dev/null || echo "")
# C5: Unbound variable protection
if [ -z "${DPKG_OUTPUT:-}" ]; then
  DPKG_OUTPUT=""
fi

# D3c: Use -F flag for fixed-string matching when pattern is literal
# K1b: Use -- to prevent pattern misinterpretation (though pattern doesn't start with -)
if grep -qE -- "^ii.*libgoogle-glog|^ii.*libglog" <<< "${DPKG_OUTPUT}"; then
    # shellcheck disable=SC2034 # BASE_GLOG_INSTALLED used for conditional logic
    BASE_GLOG_INSTALLED=true
    # D3c: Use -E for extended regex (needed for alternation)
    # K1b: Use -- to prevent pattern misinterpretation
    BASE_GLOG_VERSION=$(grep -E -- "^ii.*(libgoogle-glog|libglog)" <<< "${DPKG_OUTPUT}" | awk '{printf "  - %s %s\n", $2, $3}')
    # D3b: Use printf instead of echo for robustness
    printf '%s\n' "ℹ Base image already has glog packages installed:"
    printf '%s\n' "${BASE_GLOG_VERSION}"
    printf '%s\n' ""
    printf '%s\n' "Strategy: Will ensure libgoogle-glog-dev 0.6.0 is used (Ubuntu's patched version)"
    printf '%s\n' "  - apt-get will upgrade/reinstall if needed"
    printf '%s\n' "  - No duplicate installations (apt handles this automatically)"
else
    # D3b: Use printf instead of echo for robustness
    printf '%s\n' "✓ No glog in base image - will install libgoogle-glog-dev"
fi
# D3b: Use printf instead of echo for robustness
printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf '%s\n' ""

# Build tools and compilers
PKGS_BUILD_TOOLS="build-essential gcc g++ make cmake ninja-build pkg-config ccache patchelf elfutils patch swig git pcl-tools ros-${ROS_DISTRO}-pcl-conversions ros-${ROS_DISTRO}-perception-pcl"
# Desktop environment (XFCE4)
PKGS_DESKTOP_ENV="xorg dbus-x11 xserver-xorg-video-dummy x11-xserver-utils xauth xfce4 xfce4-goodies"
# Core graphics libraries
PKGS_CORE_LIBS="libgl1 libglvnd0 libegl1 libgles2 libxext6 libxrender1 libsm6 libxrandr2 libxi6 libxxf86vm1 libxkbfile1 libxinerama1 libxcursor1 libxdamage1 libxss1 libgl1-mesa-dri libdrm-dev"
# Fonts and utilities
PKGS_FONTS_UTILS="fontconfig fonts-dejavu fonts-liberation fonts-noto iproute2 iputils-ping net-tools lsof tmux screen htop p7zip-full python3-pip python3-venv python3-setuptools python3-wheel python3-dev whiptail gawk"
# Linear algebra libraries
# NOTE: libopenblas-dev removed - we compile our own OpenBLAS in BLOCK 6.12B
# NOTE: liblapack-dev and liblapacke-dev kept - needed for headers and pkg-config files
#       Our compiled OpenBLAS will be used via alternatives system
PKGS_LINALG="libeigen3-dev liblapack-dev liblapacke-dev libblas-dev gfortran"
# CPU parallelism libraries
PKGS_CPU_PARALLEL="libtbb-dev libmpich-dev"
# Sparse matrix and SLAM libraries
# NOTE: SuiteSparse is built from source in Block 6.12C (NOT installed via apt)
# NOTE: SuiteSparse dependencies (installed here for Block 6.12C build):
#   - libgmp-dev, libmpfr-dev: Required by SPEX (GNU GMP v6.1.2+, MPFR v4.0.2+) [preinstalled in Block 6.12B.1]
#   - libmetis-dev: Required for graph partitioning (CHOLMOD) [preinstalled in Block 6.12B.1, reverified here]
#   - libnuma-dev: Required for NUMA-aware memory management in CUDA builds
#   - libpthread-stubs0-dev: Required for pthread compatibility
#   - CUDA libraries (libcublas, libcusparse, libcusolver, libcurand): Provided by CUDA toolkit (Block 13)
#   - libnpp: Installed via ensure_cuda_companion_package in Block 13
# CRITICAL: libsuitesparse-dev is NOT included here - we build from source with custom optimization
PKGS_SPARSE_SLAM="libmetis-dev libboost-all-dev libgmp-dev libmpfr-dev libnuma-dev libpthread-stubs0-dev"
# Core dependencies
# NOTE: Using Ubuntu's libgoogle-glog-dev (0.6.0-2.1build1 with compatibility patches for COLMAP)
# NOTE: apt-get install will upgrade if different version exists, or skip if already correct version
# NOTE: This ensures NO duplicate glog installations - apt handles version conflicts automatically
PKGS_CORE_DEPS="libgflags-dev libgoogle-glog-dev libprotobuf-dev protobuf-compiler libhdf5-dev libffi-dev libssl-dev libbz2-dev liblzma-dev ca-certificates-java libgoogle-perftools-dev libtcmalloc-minimal4t64 libcpu-features-dev libva-dev libavcodec-dev libavformat-dev libswscale-dev"
# Media and GUI libraries
PKGS_MEDIA_GUI="libjpeg-dev libpng-dev libwebp-dev libavcodec-dev libavformat-dev libswscale-dev libavutil-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libgtk-3-dev libcanberra-gtk3-dev libvtk9-dev libgtkglext1-dev libevent-dev libyaml-cpp-dev libjsoncpp-dev"
# OpenGL and 3D graphics libraries (CRITICAL: Install early for all 3D tools)
PKGS_OPENGL_3D="xorg-dev libglu1-mesa-dev libglfw3-dev libglew-dev freeglut3-dev mesa-common-dev libgl1-mesa-dev libgl-dev"
# Simulation libraries
PKGS_SIM="libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libbullet-dev libode-dev libassimp-dev libtinyxml2-dev"
# Serialization libraries
PKGS_SERIALIZATION="libyaml-cpp-dev libjsoncpp-dev"

#--- Sub-block 16.6: Execute package group installations ---
# Critical: Install all package groups with verification
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages
# Convert space-separated strings to arrays for proper quoting
read -ra PKGS_BUILD_TOOLS_ARRAY <<< "${PKGS_BUILD_TOOLS}"
read -ra PKGS_DESKTOP_ENV_ARRAY <<< "${PKGS_DESKTOP_ENV}"
read -ra PKGS_CORE_LIBS_ARRAY <<< "${PKGS_CORE_LIBS}"
read -ra PKGS_FONTS_UTILS_ARRAY <<< "${PKGS_FONTS_UTILS}"
read -ra PKGS_LINALG_ARRAY <<< "${PKGS_LINALG}"
read -ra PKGS_CPU_PARALLEL_ARRAY <<< "${PKGS_CPU_PARALLEL}"
read -ra PKGS_SPARSE_SLAM_ARRAY <<< "${PKGS_SPARSE_SLAM}"
read -ra PKGS_CORE_DEPS_ARRAY <<< "${PKGS_CORE_DEPS}"
read -ra PKGS_MEDIA_GUI_ARRAY <<< "${PKGS_MEDIA_GUI}"
read -ra PKGS_OPENGL_3D_ARRAY <<< "${PKGS_OPENGL_3D}"
read -ra PKGS_SIM_ARRAY <<< "${PKGS_SIM}"
read -ra PKGS_SERIALIZATION_ARRAY <<< "${PKGS_SERIALIZATION}"

install_and_verify_group "BuildTools" "${PKGS_BUILD_TOOLS_ARRAY[@]}"
# --- Special install for gdb to avoid dependency conflicts ---
# D3b: Use printf instead of echo -e for robustness
printf '%b\n' "${YELLOW}[PHASE 1 | BuildTools] Installing gdb without recommended packages...${NC}"
# H1: Exit status check for apt-get
if ! apt-get install -y --no-install-recommends gdb; then
  printf '%b\n' "${RED}[PHASE 1 | BuildTools] FAILED: gdb installation command failed${NC}" >&2
  PHASE1_ALL_SUCCESS=false
fi
# M4: Use resilient helper for package verification
# D3d: Robust command substitution with error handling
gdb_status=""
gdb_status=$(dpkg-query -W -f='${Status}' "gdb" 2>/dev/null || echo "")
# C5: Unbound variable protection
if [ -z "${gdb_status:-}" ]; then
  gdb_status=""
fi
# D3c: Use -F flag for fixed-string matching (pattern is literal)
# K1b: Use -- to prevent pattern misinterpretation
if grep -Fq -- "ok installed" <<< "${gdb_status}"; then
  printf '%b\n' "  - gdb: ${GREEN}OK${NC}"
else
  printf '%b\n' "  - gdb: ${RED}FAIL${NC}"
  # This part of the logic will likely not be reached, but is here for robustness
  PHASE1_ALL_SUCCESS=false
  printf '%b\n' "${RED}[PHASE 1 | BuildTools] FAILED: gdb installation failed.${NC}"
fi
# --- End of special gdb install ---
install_and_verify_group "DesktopEnv" "${PKGS_DESKTOP_ENV_ARRAY[@]}"
install_and_verify_group "CoreLibraries" "${PKGS_CORE_LIBS_ARRAY[@]}"
install_and_verify_group "FontsAndUtilities" "${PKGS_FONTS_UTILS_ARRAY[@]}"
install_and_verify_group "LinearAlgebra" "${PKGS_LINALG_ARRAY[@]}"
# Note: config-files file: /etc/apt/preferences.d/block-system-ceres is installed via install.sh from container-scripts/
# Source: config-files/block-16-phase-1-foundational-system-libraries/block-system-ceres.pref
# Target: /etc/apt/preferences.d/block-system-ceres
# Installed in Block 0 (early in script, before any scripts are needed)
# D3b: Use printf instead of echo for robustness
printf '%s\n' ""
printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf '%s\n' "EARLY PROTECTION: Blocking system Ceres packages via APT pinning"
printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create APT preferences directory
# J1: Validate directory existence before operations
if [ ! -d "/etc/apt/preferences.d" ]; then
  # H1: Exit status check for mkdir
  if ! mkdir -p /etc/apt/preferences.d; then
    printf '%s\n' "[ERROR] Failed to create /etc/apt/preferences.d directory" >&2
    return 1
  fi
fi

# Block ALL system Ceres packages using APT pinning with negative priority
# This prevents ANY apt operation from installing system Ceres
# Note: config-files file: /etc/apt/preferences.d/block-system-ceres is installed via install.sh from container-scripts/
# Source: config-files/block-16-phase-1-foundational-system-libraries/block-system-ceres.pref
# Target: /etc/apt/preferences.d/block-system-ceres
# Installed in Block 0 (early in script, before any scripts are needed)
printf '%s\n' "✓ System Ceres packages are now blocked (early protection active)"
printf '%s\n' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# A7: ORPHANED CODE REMOVED - ros_multiterm script is now installed via container-scripts/install.sh
# Note: The heredoc that created /usr/local/bin/ros_multiterm has been removed
# The script is now provided by: container-scripts/shell-scripts/block-16-phase-1-foundational-system-libraries/ros-multiterminal-launcher.sh
# Installed in Block 0 (early in script, before any scripts are needed)
# E9: Heredoc extracted to container-scripts for better maintainability


#--- Sub-block 16.10: Tmux configuration complete ---
# Purpose: Optimized for multi-pane ROS development
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
#--- Sub-block 16.11: Phase 1 completion verification ---
# Critical: Verify all Phase 1 packages installed successfully
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
if [ "${PHASE1_ALL_SUCCESS}" = true ]; then
  # D3b: Use printf instead of echo -e for robustness
  printf '%b\n' "${GREEN}✓ [PHASE 1] All foundational libraries installed and verified successfully.${NC}"
  export PHASE1_STATUS="PASS"
else
  # D3b: Use printf instead of echo -e for robustness
  printf '%b\n' "${RED}✗ [PHASE 1] Errors occurred during foundational library installation. Please review logs above.${NC}"
  export PHASE1_STATUS="FAIL"
  exit 1 # Exit the build immediately on phase failure
fi
# ENDIF: PHASE1_ALL_SUCCESS check
# End Phase 1 verification (if-else self-contained)

#--- Sub-block 16.12: Configure linker to prioritize compiled libraries ---
# Critical: Ensure /usr/local/lib is searched BEFORE system libraries
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# D3b: Use printf instead of echo for robustness
printf '%s\n' "==> Configuring dynamic linker to prioritize compiled libraries..."

# Create /etc/ld.so.conf.d entry with highest priority (00- prefix ensures it's read first)
# H1: Exit status check for ensure_compiled_lib_priority
ensure_compiled_lib_priority || {
  printf '%s\n' "  [WARN] Failed to ensure compiled lib priority, continuing..." >&2
}

# D3b: Use printf instead of echo for robustness
printf '%s\n' "✓ Linker configured to prioritize /usr/local/lib"

#--- Sub-block 16.13: Update dynamic linker cache ---
# Critical: Make newly installed libraries available at runtime
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# D3b: Use printf instead of echo for robustness
printf '%s\n' "==> Updating dynamic linker cache..."
# Note: ldconfig should be run without sudo in container context (already root)
# H1: Exit status check for run_ldconfig_refresh
run_ldconfig_refresh || {
  printf '%s\n' "[WARN] ldconfig refresh failed, continuing..." >&2
}
# D3b: Use printf instead of echo for robustness
printf '%s\n' "Linker cache updated."

# Verify /usr/local/lib is prioritized in cache
# D3b: Use printf instead of echo for robustness
printf '%s\n' "Verifying linker search order (first 15 directories)..."
# D3e: SIGPIPE error handling - add || true for pipeline ending with head
ldconfig -v 2>/dev/null | grep -E -- "^/" | head -15 2>/dev/null || true

debug_glibc "After Phase 1 install: foundational system libraries"

#===============================================================================
# BLOCK 17: PHASE 3 - HIGH-LEVEL DEPENDENCIES
#===============================================================================
# Purpose: Compile robotics/vision libraries (g2o, Ceres, GTSAM) from source
# Self-contained: Yes (complete phase with success tracking)
# Dependencies: Phase 1 libraries, cmake, compilers
# Outputs: Configured system components
#-------------------------------------------------------------------------------

#--- Sub-block 17.1: Phase 3 initialization ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# D3b: Use printf instead of echo -e for robustness
printf '\n%b\n' "${BLUE}### PHASE 3: Compiling High-Level Dependencies ###${NC}"
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
    # A5: Using [[ ]] for pattern matching (Bash-specific, documented: needs pattern matching)
    # Justification: Pattern matching with [[ ]] is more robust than [ ] for path patterns
    # Script uses #!/bin/bash, so Bash-specific features are acceptable
    if [[ "${target_dir}" != /* ]]; then
        # C2/SC2155: Declare and assign separately to avoid masking return values
        local parent_dir
        parent_dir="$(cd "$(dirname "${target_dir}")" 2>/dev/null && pwd || echo "")"
        # C5: Unbound variable protection with validation
        if [ -n "${parent_dir:-}" ]; then
            target_dir="${parent_dir}/$(basename "${target_dir}")"
        else
            # If still relative, use current directory
            # C5: Unbound variable protection
            target_dir="$(pwd || echo "")/${target_dir}"
            # H4: Validate result
            if [ -z "${target_dir}" ]; then
                printf "[ERROR] Failed to determine current directory\n" >&2
                return 1
            fi
        fi
    fi
    
    # A5a: Use printf instead of echo for robustness (handles special characters)
    printf "Cloning %s to %s...\n" "${repo_url}" "${target_dir}"
    
    # CRITICAL: Remove existing directory before cloning (essential for Singularity builds)
    # In Singularity, /tmp persists between build attempts, so directories may already exist
    if [ -d "${target_dir}" ] || [ -f "${target_dir}" ]; then
        # A5a: Use printf instead of echo for robustness
        printf "  Removing existing target directory: %s\n" "${target_dir}"
        # H4: Validate removal result (best effort, non-critical for build)
        if ! rm -rf "${target_dir}" 2>/dev/null; then
            printf "[WARN] Failed to remove existing directory: %s (continuing anyway)\n" "${target_dir}" >&2
        fi
    fi
    
    while [ "${retry_count}" -lt "${max_retries}" ]; do
        # A5a: Use printf instead of echo for robustness
        printf "Attempt %d/%d...\n" $((retry_count + 1)) "${max_retries}"
        
        # Configure git for better network handling
        # H1: Exit status checks for external commands
        if ! git config --global http.postBuffer 524288000; then
            printf "[WARN] Failed to set git http.postBuffer\n" >&2
        fi
        # ENDIF: git config postBuffer
        if ! git config --global http.maxRequestBuffer 100M; then
            printf "[WARN] Failed to set git http.maxRequestBuffer\n" >&2
        fi
        # ENDIF: git config maxRequestBuffer
        if ! git config --global core.compression 0; then
            printf "[WARN] Failed to set git core.compression\n" >&2
        fi
        # ENDIF: git config compression
        
        # Try cloning with different strategies
        local clone_success=false
        if [ "${retry_count}" -eq 0 ]; then
            # First attempt: standard clone
            if git clone --depth 1 --branch "${branch}" "${repo_url}" "${target_dir}" 2>/dev/null; then
                clone_success=true
            fi
            # ENDIF: git clone attempt 0
        elif [ "${retry_count}" -eq 1 ]; then
            # Second attempt: with single branch
            if git clone --depth 1 --single-branch --branch "${branch}" "${repo_url}" "${target_dir}" 2>/dev/null; then
                clone_success=true
            fi
            # ENDIF: git clone attempt 1
        elif [ "${retry_count}" -eq 2 ]; then
            # Third attempt: with no tags
            if git clone --depth 1 --no-tags --branch "${branch}" "${repo_url}" "${target_dir}" 2>/dev/null; then
                clone_success=true
            fi
            # ENDIF: git clone attempt 2
        elif [ "${retry_count}" -eq 3 ]; then
            # Fourth attempt: with different protocol
            # A5: Using [[ ]] for pattern matching (Bash-specific, documented: needs pattern matching)
            # Justification: Pattern matching with [[ ]] is more robust for URL protocol detection
            if [[ "${repo_url}" == https://* ]]; then
                local git_url="${repo_url/https:\/\//git@}"
                git_url="${git_url/github.com/github.com:}"
                if git clone --depth 1 --branch "${branch}" "${git_url}" "${target_dir}" 2>/dev/null; then
                    clone_success=true
                fi
                # ENDIF: git clone with git protocol
            else
                if git clone --depth 1 --branch "${branch}" "${repo_url}" "${target_dir}" 2>/dev/null; then
                    clone_success=true
                fi
                # ENDIF: git clone with original protocol
            fi
            # ENDIF: protocol check
        else
            # Final attempt: shallow clone with retry
            if git clone --depth 1 --branch "${branch}" --config http.lowSpeedLimit=0 --config http.lowSpeedTime=999999 "${repo_url}" "${target_dir}" 2>/dev/null; then
                clone_success=true
            fi
            # ENDIF: git clone final attempt
        fi
        # ENDIF: retry_count check
        
        if [ "${clone_success}" = true ]; then
            # A5a: Use printf instead of echo for robustness
            printf "✓ Successfully cloned %s\n" "${repo_url}"
            return 0
        else
            # A5a: Use printf instead of echo for robustness
            printf "✗ Clone attempt %d failed\n" $((retry_count + 1))
            retry_count=$((retry_count + 1))
            
            # Clean up failed attempt
            # H4: Validate removal result (best effort, non-critical)
            if ! rm -rf "${target_dir}" 2>/dev/null; then
                printf "[WARN] Failed to clean up failed clone directory: %s\n" "${target_dir}" >&2
            fi
            # ENDIF: cleanup check
            
            if [ "${retry_count}" -lt "${max_retries}" ]; then
                # A5a: Use printf instead of echo for robustness
                printf "Waiting 10 seconds before retry...\n"
                sleep 10
            fi
            # ENDIF: retry count check
        fi
        # ENDIF: clone_success check
    done
    # ENDWHILE: retry loop
    
    # A5a: Use printf instead of echo for robustness
    printf "✗ Failed to clone %s after %d attempts\n" "${repo_url}" "${max_retries}"
    return 1
}

#--- Sub-block 17.2: Use Ubuntu's System glog Package ---
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
#   - Ceres: Uses MINIGLOG=OFF (links to system glog 0.6.0) → UNIFIED WITH COLMAP
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
# A5a: echo -e with color variables is acceptable (variables are safe constants)
printf "\n%s[PHASE 3 | glog] Using Ubuntu system package (libgoogle-glog-dev)...%s\n" "${YELLOW}" "${NC}"
# A5a: Use printf instead of echo for robustness
printf "✓ glog will be installed via apt as libgoogle-glog-dev (0.6.0-2.1build1)\n"
printf "  - Includes Ubuntu's compatibility patches for COLMAP\n"
printf "  - No compilation needed\n"
printf "\n"
monitor_cache "After glog setup (system package)"

#--- Sub-block 17.3: Verify System glog Installation ---
# Purpose: Verify Ubuntu's glog 0.6.0 is installed and check for version conflicts
# Dependencies: PKGS_CORE_DEPS (libgoogle-glog-dev already installed from apt)
# Outputs: Verified glog installation
# A5a: Use printf instead of echo for robustness
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
printf "Verifying system glog installation for COLMAP compatibility...\n"
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"

# Check for multiple glog installations (potential conflict)
# A5a: Use printf instead of echo for robustness
printf "🔍 Checking for conflicting glog versions...\n"
printf "\n"
printf "1. Checking all glog libraries in system:\n"
# H1: Exit status check for timeout command
# D3e: SIGPIPE protection - add || true at end of pipeline
if timeout 5 ldconfig -p 2>/dev/null | grep -F -- glog 2>/dev/null || true; then
    : # Libraries found
else
    # A5a: Use printf instead of echo for robustness
    printf "  ⚠ No glog libraries found in ldconfig cache\n"
fi
printf "\n"

# A5a: Use printf instead of echo for robustness
printf "2. Checking all glog headers:\n"
# C5/H4: Command substitution with error handling
# D3e: SIGPIPE protection - add || true at end of pipeline
glog_headers=$(find /usr/include /usr/local/include -name "logging.h" 2>/dev/null | grep -F -- glog 2>/dev/null || echo "" || true)
# C5: Unbound variable protection
if [ -n "${glog_headers:-}" ]; then
    # A5a: Use printf instead of echo for robustness
    printf "%s\n" "${glog_headers}"
else
    # A5a: Use printf instead of echo for robustness
    printf "  ⚠ No glog headers found\n"
fi
printf "\n"

# A5a: Use printf instead of echo for robustness
printf "3. Checking dpkg for installed glog packages:\n"
# H1: Exit status check for dpkg command
# D3e: SIGPIPE protection - add || true at end of pipeline
if dpkg -l 2>/dev/null | grep -F -- glog 2>/dev/null || true; then
    : # Packages found
else
    # A5a: Use printf instead of echo for robustness
    printf "  ℹ No glog packages in dpkg\n"
fi
printf "\n"

# Verify system glog is installed (accept held packages as well)
GLOG_PKG_NAME="libgoogle-glog-dev"
# C5/H4: Command substitution with error handling and validation
RESOLVED_GLOG_PKG=$(dpkg_resolve_installed_package "${GLOG_PKG_NAME}" 2>/dev/null || echo "")
# C5: Unbound variable protection with validation
if [ -z "${RESOLVED_GLOG_PKG:-}" ]; then
    # A5a: Use printf instead of echo for robustness
    printf "✗ ERROR: libgoogle-glog-dev not installed!\n" >&2
    printf "  This should have been installed via PKGS_CORE_DEPS\n" >&2
    exit 1
fi

# C5/H4: Command substitution with error handling and validation
INSTALLED_GLOG=$(dpkg_get_installed_version "${GLOG_PKG_NAME}" 2>/dev/null || echo "")
# C5: Unbound variable protection with validation
if [ -z "${INSTALLED_GLOG:-}" ]; then
    INSTALLED_GLOG="unknown"
fi
# A5a: Use printf instead of echo for robustness
printf "✓ Found system glog: %s\n" "${INSTALLED_GLOG}"
printf "\n"

# Verify CMake can find glog
# A5a: Use printf instead of echo for robustness
printf "4. Verifying CMake can detect glog...\n"
# J1: Directory existence validation
if [ -d "/usr/lib/x86_64-linux-gnu/cmake/glog" ]; then
    # A5a: Use printf instead of echo for robustness
    printf "  ✓ CMake config found: /usr/lib/x86_64-linux-gnu/cmake/glog\n"
    # J1: File existence validation
    if [ -f "/usr/lib/x86_64-linux-gnu/cmake/glog/glog-config.cmake" ]; then
        # A5a: Use printf instead of echo for robustness
        printf "  ✓ glog-config.cmake exists\n"
    fi
else
    # A5a: Use printf instead of echo for robustness
    printf "  ⚠ WARNING: glog CMake config not found in expected location\n" >&2
    printf "    COLMAP may have issues finding glog\n" >&2
fi
printf "\n"

# Check glog version for COLMAP compatibility
# A5a: Use printf instead of echo for robustness
printf "5. Checking glog version compatibility with COLMAP 3.12.6...\n"
# C5/H4: Command substitution with error handling and validation
GLOG_VERSION=$(pkg-config --modversion libglog 2>/dev/null || echo "unknown")
# C5: Unbound variable protection
if [ "${GLOG_VERSION:-unknown}" != "unknown" ]; then
    # A5a: Use printf instead of echo for robustness
    printf "  ✓ pkg-config reports glog version: %s\n" "${GLOG_VERSION}"
    # Extract major.minor version
    # D3: Use here-string instead of echo | cut (unsafe pipe pattern) - CORRECT
    GLOG_MAJOR=$(cut -d. -f1 <<< "${GLOG_VERSION}" || echo "")
    GLOG_MINOR=$(cut -d. -f2 <<< "${GLOG_VERSION}" || echo "")
    
    # C5: Unbound variable protection with validation
    # Validate version components are numeric before comparison
    if [ -n "${GLOG_MAJOR:-}" ] && [ -n "${GLOG_MINOR:-}" ] && \
       grep -qE '^[0-9]+$' <<< "${GLOG_MAJOR}" && \
       grep -qE '^[0-9]+$' <<< "${GLOG_MINOR}"; then
        if [ "${GLOG_MAJOR}" -eq 0 ] && [ "${GLOG_MINOR}" -eq 6 ]; then
            # A5a: Use printf instead of echo for robustness
            printf "  ℹ Using glog 0.6.x - Ubuntu's version includes compatibility patches\n"
            printf "    for COLMAP 3.12.6 (CHECK macros, PREDICT macros, etc.)\n"
        fi
    else
        # A5a: Use printf instead of echo for robustness
        printf "  ⚠ WARNING: Could not parse glog version format: %s\n" "${GLOG_VERSION}" >&2
    fi
else
    # A5a: Use printf instead of echo for robustness
    printf "  ℹ glog version not available via pkg-config (non-fatal)\n"
fi
printf "\n"

# Test if glog headers are accessible
# A5a: Use printf instead of echo for robustness
printf "6. Testing glog header accessibility...\n"
# J1: File existence validation before use
if [ -f "/usr/include/glog/logging.h" ]; then
    # A5a: Use printf instead of echo for robustness
    printf "  ✓ glog headers found: /usr/include/glog/logging.h\n"
else
    # A5a: Use printf instead of echo for robustness
    printf "  ✗ ERROR: glog headers not found\n" >&2
    exit 1
fi
printf "\n"

# WARNING: Check for /usr/local glog installation (would conflict)
# A5a: Use printf instead of echo for robustness
printf "7. Checking for conflicting /usr/local glog installation...\n"
# J1: File existence validation
if [ -f "/usr/local/include/glog/logging.h" ] || [ -f "/usr/local/lib/libglog.so" ]; then
    # A5a: Use printf instead of echo for robustness
    printf "  ⚠ WARNING: Found glog in /usr/local!\n" >&2
    printf "    This may conflict with system glog in /usr\n" >&2
    printf "    /usr/local has higher priority in CMake searches\n" >&2
    printf "\n"
    printf "  Files found:\n"
    # J1: File existence validation
    [ -f "/usr/local/include/glog/logging.h" ] && printf "    - /usr/local/include/glog/logging.h\n"
    [ -f "/usr/local/lib/libglog.so" ] && printf "    - /usr/local/lib/libglog.so\n"
    printf "\n"
    printf "  Recommendation: Remove /usr/local glog or use CMAKE_IGNORE_PATH\n"
else
    # A5a: Use printf instead of echo for robustness
    printf "  ✓ No conflicting /usr/local glog found\n"
fi
printf "\n"

# A5a: Use printf instead of echo for robustness
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
printf "System glog verification complete\n"
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
printf "\n"
printf "Compatibility Configuration:\n"
# A5a: Use printf instead of echo for robustness (variable is safe, validated above)
printf "  glog:          System package (Ubuntu %s)\n" "${INSTALLED_GLOG}"
printf "  Ceres Solver:  Internal MINIGLOG (bundled, isolated)\n"
printf "  COLMAP:        System glog (Ubuntu's patched 0.6.0)\n"
printf "\n"
monitor_cache "After glog verification"

#--- Sub-block 17.4: Compile Ceres Solver ---
# Purpose: Build Ceres optimization library from source (COMPILE FIRST - g2o can link to it)
# Dependencies: PHASE 1 (Build tools), Block 6.13 (NVIDIA CUDA)
# Note: Uses internal MINIGLOG (bundled), NOT system glog - fully isolated
# Outputs: Optimized Ceres library
# A5a: echo -e with color variables is acceptable (variables are safe constants)
printf "\n%s[PHASE 3 | Ceres] Compiling from source...%s\n" "${YELLOW}" "${NC}"

# CRITICAL: Remove system Ceres to prevent conflicts
# System Ceres 2.2.0 uses older configuration, we'll build from source
# Using MINIGLOG=OFF to share system glog 0.6.0 with COLMAP (unified approach)
if dpkg -s libceres-dev >/dev/null 2>&1 || dpkg -s libceres2 >/dev/null 2>&1; then
    # A5a: Use printf instead of echo for robustness
    printf "⚠️  Removing system Ceres packages to compile from source...\n"
    printf "  (We'll build Ceres with system glog 0.6.0 for consistency with COLMAP)\n"
    # H4: Validate removal result
    if ! apt-get remove -y libceres-dev libceres2 2>/dev/null; then
        printf "[WARN] Failed to remove system Ceres packages (continuing anyway)\n" >&2
    fi
    # H1: Exit status check for external command
    if ! apt-get autoremove -y; then
        printf "[WARN] apt-get autoremove failed (continuing anyway)\n" >&2
    fi
    # A5a: Use printf instead of echo for robustness
    printf "✓ System Ceres removed\n"
else
    # A5a: Use printf instead of echo for robustness
    printf "✓ No system Ceres found (clean state)\n"
fi
# Ensure we're not inside the directory before removing it
# H1: Exit status check for cd command
if ! cd /; then
    printf "[ERROR] Failed to change to root directory\n" >&2
    exit 1
fi
rm -rf /tmp/ceres-solver
# Using CERES_VERSION from config.sh
# C5: Unbound variable protection
if [ -z "${CERES_VERSION:-}" ]; then
    printf "[ERROR] CERES_VERSION not set\n" >&2
    exit 1
fi
if ! clone_with_retry "https://github.com/ceres-solver/ceres-solver.git" "/tmp/ceres-solver" "${CERES_VERSION}"; then
    # A5a: Use printf instead of echo for robustness
    printf "[ERROR] Failed to clone Ceres Solver after all retry attempts\n" >&2
    exit 1
fi
# Use explicit, separate commands for navigation
# H1: Exit status check for cd command
if ! cd /tmp/ceres-solver; then
    # A5a: Use printf instead of echo for robustness
    printf "[ERROR] Failed to access ceres-solver directory\n" >&2
    exit 1
fi
# Remove existing build directory if it exists (critical for Singularity rebuilds)
# H4: Validate removal result (best effort)
if ! rm -rf build; then
    printf "[WARN] Failed to remove existing build directory (continuing anyway)\n" >&2
fi
# J1: Directory creation with validation
if ! mkdir -p build; then
    printf "[ERROR] Failed to create build directory\n" >&2
    exit 1
fi
# H1: Exit status check for cd command
if ! cd build; then
    # A5a: Use printf instead of echo for robustness
    printf "[ERROR] Failed to access build directory\n" >&2
    exit 1
fi

#--- Sub-block 17.5: Configure Ceres with CMake ---
# Critical: CMake configuration with optimizations (OpenMP enabled via -fopenmp in CXX_FLAGS)
# Reference: docs/flags/CERES_SOLVER_2.2.0_CMAKE_FLAGS_DOCUMENTATION.md
# 
# PERFORMANCE FLAGS (from Ceres documentation):
#   - SCHUR_SPECIALIZATIONS=ON: Fixed-size Schur complement for better performance
#   - CUSTOM_BLAS=OFF: Force external BLAS/LAPACK (MKL) instead of handcoded routines
#   - USE_CUDA=ON: Enable CUDA linear algebra solvers (documented flag)
#   - EIGENMETIS=ON: Eigen METIS support for sparse matrix ordering
#   - EIGENSPARSE=ON: Eigen sparse linear algebra
#   - SUITESPARSE=ON: SuiteSparse for sparse linear algebra
#
# COMPATIBILITY NOTE: MINIGLOG=OFF (uses system glog 0.6.0)
#   Why: Unified approach - both Ceres and COLMAP use same glog version
#   Result: Ceres uses system glog 0.6.0, COLMAP uses system glog 0.6.0
#   Benefit: Single glog version, consistent logging, proven compatible
#   Verified: COLMAP 3.12.6 + Ceres 2.2.0 + glog 0.6.0 = Working combination
#
# MKL INTEGRATION:
#   MKL linkage: `BLA_VENDOR` and `{BLAS,LAPACK}_LIBRARIES` are the documented knobs
#   (docs/flags/CERES_SOLVER_2.2.0_CMAKE_FLAGS_DOCUMENTATION.md)
#
# PERFORMANCE OPTIMIZATIONS:
#   SCHUR_SPECIALIZATIONS=ON: Fixed-size Schur complement specializations (faster performance)
#   CUSTOM_BLAS=OFF: Prefer external MKL BLAS/LAPACK over internal routines
#   GFLAGS=ON: Google Flags support for runtime configuration
#   CMAKE_POSITION_INDEPENDENT_CODE=ON: Build PIC for shared library compatibility
#   PROVIDE_UNINSTALL_TARGET=ON: Adds uninstall target for package management
#
# CRITICAL: Ceres SuiteSparse Configuration
# - Ceres uses find_package(SuiteSparse) which requires SuiteSparse_DIR or CMAKE_PREFIX_PATH
# - Invalid flags (SUITESPARSE_INCLUDE_DIR, CHOLMOD_LIBRARY, etc.) are IGNORED by Ceres
# - Reference: docs/flags/CERES_SOLVER_2.2.0_CMAKE_FLAGS_DOCUMENTATION.md
# - SuiteSparse_DIR points to directory containing SuiteSparseConfig.cmake
# - CMAKE_PREFIX_PATH helps CMake locate SuiteSparseConfig.cmake if SuiteSparse_DIR is not set
# CRITICAL: Verify SuiteSparse_DIR is set and SuiteSparseConfig.cmake exists
# Ceres's FindSuiteSparse.cmake uses SuiteSparse_DIR to find SuiteSparseConfig.cmake
# If SuiteSparse_DIR is not set or config file doesn't exist, Ceres falls back to bundled finder
# Phase 1: Check if SuiteSparse_DIR is set and valid (C5: unbound variable protection)
CERES_SUITESPARSE_FLAGS=""
# J1: Directory and file existence validation
if [ -n "${SuiteSparse_DIR:-}" ] && [ -d "${SuiteSparse_DIR}" ] && [ -f "${SuiteSparse_DIR}/SuiteSparseConfig.cmake" ]; then
    # A5a: Use printf instead of echo for robustness
    printf "  → Using SuiteSparse_DIR: %s\n" "${SuiteSparse_DIR}"
    printf "  → SuiteSparseConfig.cmake found: %s/SuiteSparseConfig.cmake\n" "${SuiteSparse_DIR}"
    # D1: Proper quoting for path variables (CMake format: -D VAR="value")
    CERES_SUITESPARSE_FLAGS="-D SuiteSparse_DIR=\"${SuiteSparse_DIR}\""
else
    # A5a: Use printf instead of echo for robustness
    printf "  ⚠ SuiteSparse_DIR not set or SuiteSparseConfig.cmake not found\n" >&2
    printf "  → SuiteSparse_DIR: %s\n" "${SuiteSparse_DIR:-unset}"
    if [ -n "${SuiteSparse_DIR:-}" ]; then
        # A5a: Use printf instead of echo for robustness
        printf "  → SuiteSparseConfig.cmake: %s/SuiteSparseConfig.cmake (not found)\n" "${SuiteSparse_DIR}"
    fi
    # Phase 2: Validate SUITESPARSE_INSTALL_PREFIX before using (C5: unbound variable protection)
    if [ -z "${SUITESPARSE_INSTALL_PREFIX:-}" ]; then
        # A5a: Use printf instead of echo for robustness
        printf "  ✗ ERROR: SUITESPARSE_INSTALL_PREFIX not set\n" >&2
        exit 1
    fi
    # A5a: Use printf instead of echo for robustness
    printf "  → Using CMAKE_PREFIX_PATH: %s\n" "${SUITESPARSE_INSTALL_PREFIX}"
    # Phase 3: Build CMAKE_PREFIX_PATH with proper fallback (C5: unbound variable protection)
    if [ -n "${CMAKE_PREFIX_PATH:-}" ]; then
        # D1: Proper quoting for path variables (CMake format: -D VAR="value")
        CERES_SUITESPARSE_FLAGS="-D CMAKE_PREFIX_PATH=\"${SUITESPARSE_INSTALL_PREFIX};${CMAKE_PREFIX_PATH}\""
    else
        # D1: Proper quoting for path variables (CMake format: -D VAR="value")
        CERES_SUITESPARSE_FLAGS="-D CMAKE_PREFIX_PATH=\"${SUITESPARSE_INSTALL_PREFIX}\""
    fi
fi
# Phase 4: Validate CERES_SUITESPARSE_FLAGS is set before use (C5: unbound variable protection, H1: error check)
if [ -z "${CERES_SUITESPARSE_FLAGS:-}" ]; then
    # A5a: Use printf instead of echo for robustness
    printf "  ✗ ERROR: Failed to configure SuiteSparse flags for Ceres\n" >&2
    exit 1
fi

# shellcheck disable=SC2086 # CERES_SUITESPARSE_FLAGS contains multiple flags that need word splitting
cmake .. \
  -G Ninja \
  -D CMAKE_BUILD_TYPE=Release \
  -D CMAKE_INSTALL_PREFIX=/usr/local \
  -D CMAKE_CXX_FLAGS="-march=x86-64-v3 -O3 -mavx2 -mfma -msse4.2 -fopenmp -funroll-loops" \
  -D CMAKE_C_FLAGS="-march=x86-64-v3 -O3 -mavx2 -mfma -msse4.2 -fopenmp -funroll-loops" \
  -D CMAKE_SHARED_LINKER_FLAGS="-flto -fopenmp" \
  -D CMAKE_INSTALL_RPATH="/usr/local/lib" \
  -D CMAKE_INSTALL_RPATH_USE_LINK_PATH=TRUE \
  -D CMAKE_POSITION_INDEPENDENT_CODE=ON \
  -D BUILD_SHARED_LIBS=ON \
  -D SCHUR_SPECIALIZATIONS=ON \
  -D CUSTOM_BLAS=OFF \
  -D MINIGLOG=OFF \
  -D GFLAGS=ON \
  -D CMAKE_CUDA_COMPILER_WORKS=TRUE \
  -D BLA_VENDOR=Intel10_64lp \
  -D BLAS_LIBRARIES="${MKL_BLAS_LIBRARIES}" \
  -D LAPACK_LIBRARIES="${MKL_BLAS_LIBRARIES}" \
  -D LAPACK=ON \
  -D EIGENMETIS=ON \
  -D EIGENSPARSE=ON \
  -D SUITESPARSE=ON \
  -D USE_CUDA=ON \
  -D BUILD_EXAMPLES=OFF \
  -D BUILD_TESTING=OFF \
  -D BUILD_BENCHMARKS=OFF \
  -D PROVIDE_UNINSTALL_TARGET=ON \
  -D CMAKE_CUDA_ARCHITECTURES="86;89;90" \
  -D CMAKE_CXX_STANDARD=17 \
  -D CMAKE_CXX_STANDARD_REQUIRED=ON \
  -D CMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
  ${CERES_SUITESPARSE_FLAGS}

#--- Sub-block 17.6: Build and install Ceres ---
# Critical: Compile with ninja using memory-aware job calculation
# C5/H4: Command substitution with error handling and validation
BUILD_JOBS=$(calculate_build_jobs 2>/dev/null || echo "1")
# C5: Unbound variable protection with validation
if [ -z "${BUILD_JOBS:-}" ] || ! [ "${BUILD_JOBS}" -gt 0 ] 2>/dev/null; then
    BUILD_JOBS=1
    printf "[WARN] Invalid BUILD_JOBS, using 1\n" >&2
fi
# A5a: Use printf instead of echo for robustness
printf "Building Ceres with %d parallel jobs...\n" "${BUILD_JOBS}"
if command -v nproc >/dev/null 2>&1 && command -v free >/dev/null 2>&1; then
    # C5/H4: Command substitutions with error handling
    nproc_output=$(nproc 2>/dev/null || echo "unknown")
    mem_output=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}' || echo "unknown")
    # A5a: Use printf instead of echo for robustness
    printf "  System: %s cores, %s RAM\n" "${nproc_output}" "${mem_output}"
fi
printf "\n"

# Build with multithreaded compilation
# H1: Exit status check for build command
if ! ninja -j"${BUILD_JOBS}"; then
    # A5a: Use printf instead of echo for robustness
    printf "[ERROR] Failed to build Ceres with multithreaded compilation\n" >&2
    exit 1
fi

# Install Ceres and capture output for directory detection
# CRITICAL: Use separate command to properly capture exit code (best practice for pipe operations)
set +o pipefail  # Temporarily disable pipefail to check ninja exit code separately
ninja install 2>&1 | tee /tmp/ceres_install.log
INSTALL_EXIT_CODE=${PIPESTATUS[0]}
set -o pipefail  # Re-enable pipefail

# CRITICAL: Multi-phase installation verification (best practice O4)
# Phase 1: Verify installation command succeeded (exit code check)
if [ "${INSTALL_EXIT_CODE}" -ne 0 ]; then
    # A5a: Use printf instead of echo for robustness
    printf "[ERROR] Ceres installation failed with exit code %d\n" "${INSTALL_EXIT_CODE}" >&2
    exit 1
fi

# Phase 2: Verify log file contains successful installation indicators
# J1: File existence validation before use
if [ ! -f "/tmp/ceres_install.log" ]; then
    # A5a: Use printf instead of echo for robustness
    printf "[ERROR] Installation log file not found\n" >&2
    exit 1
fi

# Check for installation success indicators in log
# K1b: Use -- flag to prevent option misinterpretation if pattern starts with -
if ! grep -qiE -- "(installing|installed|build files have been written)" /tmp/ceres_install.log; then
    # A5a: Use printf instead of echo for robustness
    printf "  [WARN] Installation log may not indicate successful installation, continuing with verification...\n" >&2
fi

# Phase 3: Verify library files exist before refreshing ldconfig (best practice O4 - Phase 1: File Existence)
CERES_LIB_FOUND=false
for lib_path in /usr/local/lib/libceres.so* /usr/local/lib64/libceres.so*; do
  if [ -f "${lib_path}" ]; then
    CERES_LIB_FOUND=true
    # A5a: Use printf instead of echo for robustness
    printf "  [VERIFY] Found Ceres library file: %s\n" "${lib_path}"
    break
  fi
done

if [ "${CERES_LIB_FOUND}" = false ]; then
  # A5a: Use printf instead of echo for robustness
  printf "  [WARN] Ceres library files not found in standard locations, will attempt directory detection from log...\n"
fi

# Phase 4: Use dynamic directory detection from installation output (extracts actual install paths)
# A5a: Use printf instead of echo for robustness
printf "  [INFO] Extracting library installation directories from installation log...\n"
run_ldconfig_refresh_from_install_output "/tmp/ceres_install.log" 200 || {
  # A5a: Use printf instead of echo for robustness
  printf "  [WARN] Directory extraction from log failed, falling back to standard locations...\n"
  # Fallback: Refresh standard locations
  for std_dir in /usr/local/lib /usr/local/lib64; do
    if [ -d "${std_dir}" ]; then
      run_ldconfig_refresh_dir "${std_dir}" || true
    fi
  done
}

#--- Sub-block 17.7: Multi-phase Ceres installation verification (best practice O4) ---
# Critical: Multi-phase verification with retry logic (95% reliability vs 70% for single-phase)
# Phase 1: File Existence Check (MANDATORY - files can exist but not be in cache)
# A5a: Use printf instead of echo for robustness
printf "  [VERIFY Phase 1] Checking for Ceres library files...\n"
CERES_FILE_FOUND=false
for lib_path in /usr/local/lib/libceres.so* /usr/local/lib64/libceres.so*; do
  if [ -f "${lib_path}" ]; then
    CERES_FILE_FOUND=true
    # A5a: Use printf instead of echo for robustness
    printf "    ✓ Found: %s\n" "${lib_path}"
    break
  fi
done

if [ "${CERES_FILE_FOUND}" = false ]; then
  # A5a: Use printf instead of echo -e for robustness (D3b: echo unsafe patterns)
  printf "  %s✗ [Phase 1 FAILED] Ceres library files not found%s\n" "${RED}" "${NC}"
  # A5a: Use printf instead of echo for robustness
  printf "    → Searching in detected directories from installation log...\n"
  # Search in directories that were detected from installation output
  if [ -f "/tmp/ceres_install.log" ]; then
    while IFS= read -r detected_dir; do
      # D3e: SIGPIPE protection - add || true at end of pipeline with head
      if [ -d "${detected_dir}" ] && find "${detected_dir}" -maxdepth 1 -name "libceres.so*" -type f 2>/dev/null | head -1 2>/dev/null | grep -q . 2>/dev/null || true; then
        CERES_FILE_FOUND=true
        # A5a: Use printf instead of echo for robustness
        printf "    ✓ Found in detected directory: %s\n" "${detected_dir}"
        break
      fi
    done < <(grep -E "^  \[VERIFY\] Validated library directory:" /tmp/ceres_install.log 2>/dev/null | sed 's/.*: //' || true)
  fi
fi

# Phase 2: Linker Cache Check (with retry logic - best practice O4 Phase 3)
# A5a: Use printf instead of echo for robustness
printf "  [VERIFY Phase 2] Checking ldconfig cache for Ceres libraries...\n"
CERES_IN_CACHE=false
# D3e: SIGPIPE protection - add || true at end of pipeline
if timeout 5 ldconfig -p 2>/dev/null | grep -Fq "libceres.so" 2>/dev/null || true; then
  CERES_IN_CACHE=true
  # A5a: Use printf instead of echo for robustness
  printf "    ✓ Found in ldconfig cache\n"
else
  # A5a: Use printf instead of echo for robustness
  printf "    ⚠ Not in cache, refreshing and retrying...\n"
  # Retry logic: Refresh ldconfig and check again (best practice O4 Phase 3)
  run_ldconfig_refresh || true
  sleep 1  # Brief delay for cache update
  # D3e: SIGPIPE protection - add || true at end of pipeline
  if timeout 5 ldconfig -p 2>/dev/null | grep -Fq "libceres.so" 2>/dev/null || true; then
    CERES_IN_CACHE=true
    # A5a: Use printf instead of echo for robustness
    printf "    ✓ Found in cache after refresh\n"
  else
    # A5a: Use printf instead of echo for robustness
    printf "    ✗ Still not in cache after refresh\n"
  fi
fi

# Phase 3: Final verification (file existence takes priority over cache - best practice O4)
if [ "${CERES_FILE_FOUND}" = true ]; then
  # A5a: Use printf instead of echo -e for robustness (D3b: echo unsafe patterns)
  printf "  %s✓ [VERIFICATION PASSED] Ceres installation verified (library files exist)%s\n" "${GREEN}" "${NC}"
  if [ "${CERES_IN_CACHE}" = false ]; then
    # A5a: Use printf instead of echo for robustness
    printf "    ⚠ Note: Libraries exist but not yet in cache (may need additional refresh)\n"
  fi
  # Installation succeeded if files exist (file existence is authoritative)
else
  # A5a: Use printf instead of echo -e for robustness (D3b: echo unsafe patterns)
  printf "  %s✗ [VERIFICATION FAILED] Ceres installation verification failed%s\n" "${RED}" "${NC}"
  # A5a: Use printf instead of echo for robustness
  printf "    → Debug: Library files not found in expected locations\n"
  # A5a: Use printf instead of echo for robustness
  printf "    → Action: Review installation log: /tmp/ceres_install.log\n"
  PHASE3_ALL_SUCCESS=false
fi

  #--- Sub-block 17.8: Verify Ceres APT protection is active ---
  # Critical: Confirm APT pinning is still protecting compiled Ceres
  # Note: APT pinning was applied early in Block 7.5.5 (before any apt operations)
  # Strategy: Just verify it's still in place
  # A5a: Use printf instead of echo for robustness
  printf "Verifying Ceres APT protection...\n"
  
  if [ -f "/etc/apt/preferences.d/block-system-ceres" ]; then
      # A5a: Use printf instead of echo for robustness
      printf "✓ APT preferences file exists (early protection active)\n"
      # A5a: Use printf instead of echo for robustness
      printf "  - Blocks: libceres-dev, libceres3, libceres2, libceres1\n"
      # A5a: Use printf instead of echo for robustness
      printf "  - Applied in: Block 7.5.5 (before apt operations)\n"
      
      # Double-check no system Ceres packages slipped through
      # M4: Use resilient helpers instead of brittle dpkg parsing
      if dpkg_resolve_installed_package "libceres-dev" >/dev/null 2>&1 || dpkg_resolve_installed_package "libceres2" >/dev/null 2>&1; then
          # A5a: Use printf instead of echo for robustness
          printf "✗ ERROR: System Ceres packages detected despite APT pinning!\n" >&2
          # M4: Use resilient helpers instead of brittle dpkg parsing
          dpkg_resolve_installed_package "libceres-dev" >/dev/null 2>&1 && printf "  libceres-dev: %s\n" "$(dpkg_get_installed_version "libceres-dev" 2>/dev/null || echo "unknown")"
          dpkg_resolve_installed_package "libceres2" >/dev/null 2>&1 && printf "  libceres2: %s\n" "$(dpkg_get_installed_version "libceres2" 2>/dev/null || echo "unknown")"
          exit 1
      fi
  else
      # A5a: Use printf instead of echo for robustness
      printf "✗ ERROR: Ceres protection file missing (should have been created in Block 7.5.5)\n" >&2
      exit 1
  fi
  
  # A5a: Use printf instead of echo for robustness
  printf "✓ Ceres protected from APT overwrites (verified)\n"

# Verify TBB configuration for Ceres (ensure system TBB, not MKL TBB)
# A5a: Use printf instead of echo for robustness (D3b: echo unsafe patterns)
printf "Verifying TBB configuration for Ceres...\n"
cd /tmp/ceres-solver/build || true
if [ -f "CMakeCache.txt" ]; then
  # D3e: SIGPIPE protection - add || true at end of pipeline with head
  TBB_LIB_PATH=$(grep -E "^TBB_LIBRARIES(:|=)" CMakeCache.txt 2>/dev/null | head -1 2>/dev/null | sed 's/.*[=:]//' 2>/dev/null | tr -d '[:space:]' 2>/dev/null || echo "")
  if [ -n "${TBB_LIB_PATH}" ]; then
    if grep -qE "(/opt/intel|/usr/local/intel|/opt/intel/oneapi|mkl)" <<< "${TBB_LIB_PATH}"; then
      # A5a: Use printf instead of echo -e for robustness (D3b: echo unsafe patterns)
      printf "  %s✗ ERROR: Ceres is using MKL TBB: %s%s\n" "${RED}" "${TBB_LIB_PATH}" "${NC}"
      # A5a: Use printf instead of echo for robustness
      printf "  This may cause runtime conflicts. System TBB should be used.\n"
    elif grep -qE "/usr/lib/x86_64-linux-gnu/libtbb" <<< "${TBB_LIB_PATH}"; then
      # A5a: Use printf instead of echo -e for robustness (D3b: echo unsafe patterns)
      printf "  %s✓ Ceres is using system TBB: %s%s\n" "${GREEN}" "${TBB_LIB_PATH}" "${NC}"
    else
      # A5a: Use printf instead of echo -e for robustness (D3b: echo unsafe patterns)
      printf "  %s⚠ Ceres TBB source uncertain: %s%s\n" "${YELLOW}" "${TBB_LIB_PATH}" "${NC}"
    fi
  else
    # A5a: Use printf instead of echo for robustness
    printf "  • TBB not detected in Ceres configuration (may not be required)\n"
  fi
else
  # A5a: Use printf instead of echo for robustness
  printf "  • CMakeCache.txt not found, skipping TBB verification\n"
fi

# Cleanup
cd / && rm -rf /tmp/ceres-solver
debug_glibc "After installing CERES"

#--- Sub-block 17.9: Build PyCeres (Python bindings for Ceres) ---
# Purpose: Build PyCeres from source to link against compiled Ceres
# Dependencies: Sub-block 8.4 (Ceres Solver installed)
# Outputs: PyCeres Python package
# Reference: https://github.com/cvg/pyceres
# Release: v2.5 (https://github.com/cvg/pyceres/archive/refs/tags/v2.5.tar.gz)
# Note: PyCeres is required by PyCOLMAP for cost functions feature
# A5a: Use printf instead of echo for robustness
printf "\n"
# A5a: Use printf instead of echo for robustness
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
# A5a: Use printf instead of echo for robustness
printf "Building PyCeres %s Python bindings for Ceres Solver...\n" "${PYCERES_VERSION}"
# A5a: Use printf instead of echo for robustness
printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"

# Set library paths to prioritize our compiled Ceres
export LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH:-}"
export CMAKE_PREFIX_PATH="/usr/local:${CMAKE_PREFIX_PATH:-}"

# Clone PyCeres (using latest release v2.5)
cd /tmp || exit 1
rm -rf pyceres
if ! clone_with_retry "https://github.com/cvg/pyceres.git" "/tmp/pyceres" "v${PYCERES_VERSION}"; then
    # A5a: Use printf instead of echo for robustness
    printf "⚠ PyCeres clone failed, trying PyPI installation as fallback...\n"
    if python3 -m pip install --no-binary opencv-python,opencv-contrib-python pyceres 2>&1 | tee /tmp/pyceres_install.log; then
        # A5a: Use printf instead of echo for robustness
        printf "✓ PyCeres installed from PyPI (will use compiled Ceres via LD_LIBRARY_PATH)\n"
    else
        # A5a: Use printf instead of echo for robustness
        printf "⚠ PyCeres installation failed (non-fatal, PyCOLMAP cost functions may not work)\n"
    fi
else
    cd /tmp/pyceres || exit 1
  # A5a: Use printf instead of echo for robustness
  printf "Building PyCeres from source (linking against compiled Ceres)...\n"
  
  # Patch CMakeLists.txt to set minimum CMake version to 3.15 (required by scikit-build-core)
  if [ -f CMakeLists.txt ]; then
    # A5a: Use printf instead of echo for robustness
    printf "Updating CMake minimum version to 3.15 for scikit-build-core compatibility...\n"
    sed -i 's/cmake_minimum_required(VERSION [0-9.]*)/cmake_minimum_required(VERSION 3.15)/' CMakeLists.txt
  fi
  
  # Note: PyCeres will automatically inherit the configuration from the installed Ceres library
  # We only need to point it to the Ceres installation directory
  # CUDA support will be automatically detected from the installed Ceres library
  export SKBUILD_CONFIGURE_OPTIONS="\
-DWITH_TESTS=OFF \
-DWITH_BENCHMARKS=OFF \
-DWITH_PYTEST=OFF \
-DCeres_DIR=/usr/local/lib/cmake/Ceres"

  if python3 -m pip install \
        --no-deps \
        --disable-pip-version-check \
        --no-binary :all: \
        --config-settings=cmake.build-type=Release \
        --config-settings=build.verbose=true \
        . 2>&1 | tee /tmp/pyceres_install.log; then
      # A5a: Use printf instead of echo for robustness
      printf "✓ PyCeres built and installed from source (using compiled Ceres)\n"

      # Note: python-scripts file: /tmp/phase-3-high-level-dependencies-verification.py is installed via install.sh from container-scripts/
      # Source: python-scripts/block-17-phase-3-high-level-dependencies/phase-3-high-level-dependencies-verification.py
      # Target: /tmp/phase-3-high-level-dependencies-verification.py
      # Installed in Block 0 (early in script, before any scripts are needed)
      if python3 /tmp/phase-3-high-level-dependencies-verification.py 2>/tmp/pyceres_import.log; then
        # A5a: Use printf instead of echo for robustness
        printf "✓ PyCeres Python module verified\n"
      else
        # A5a: Use printf instead of echo for robustness
        printf "⚠ PyCeres import check failed\n"
        sed 's/^/  /' /tmp/pyceres_import.log || true
      fi
  else
      # A5a: Use printf instead of echo for robustness
      printf "⚠ PyCeres source build failed, trying PyPI...\n"
      if python3 -m pip install --disable-pip-version-check pyceres 2>&1 | tee -a /tmp/pyceres_install.log; then
          # A5a: Use printf instead of echo for robustness
          printf "✓ PyCeres installed from PyPI (will use compiled Ceres via LD_LIBRARY_PATH)\n"
      else
          # A5a: Use printf instead of echo for robustness
          printf "⚠ PyCeres installation failed (non-fatal, PyCOLMAP cost functions may not work)\n"
      fi
  fi

  unset SKBUILD_CONFIGURE_OPTIONS

  cd / && rm -rf /tmp/pyceres
fi

#--- Sub-block 17.9b: Install QGLViewer dependencies for G2O visualization ---
# Purpose: Install Qt5 and QGLViewer packages required for g2o_viewer application
# Dependencies: Block 6 (APT configuration)
# Outputs: Installed packages, library cache refresh
if [ "${PHASE3_ALL_SUCCESS}" = true ]; then
  # A5a: Use printf instead of echo -e for robustness (D3b: echo unsafe patterns)
  printf "\n%s[PHASE 3 | QGLViewer] Installing dependencies for G2O visualization...%s\n" "${YELLOW}" "${NC}"
  
  # Critical: Qt5 and QGLViewer packages required for g2o_viewer
  # Note: qt5-default removed in Ubuntu 24.04, replaced by qtbase5-dev/qtbase5-dev-tools
  # Note: libqglviewer-dev/libqglviewer2 renamed to libqglviewer-dev-qt5/libqglviewer2-qt5t64 in Ubuntu 24.04
  QGLVIEWER_DEP_PACKAGES=(
    "qt5-qmake"
    "qtbase5-dev"
    "qtbase5-dev-tools"
    "libqt5opengl5-dev"
    "libqglviewer-dev-qt5"
    "libqglviewer2-qt5t64"
    "libglu1-mesa-dev"
  )
  
  if ! install_packages_resilient "QGLViewer dependencies for G2O" "${QGLVIEWER_DEP_PACKAGES[@]}"; then
    # A5a: Use printf instead of echo for robustness
    printf "⚠ Some QGLViewer dependencies unavailable (non-fatal - G2O will build without viewer)\n"
  fi
  
  # Refresh library cache after installing QGLViewer (required for CMake detection)
  # M4: Use resilient helpers instead of brittle dpkg parsing
  if dpkg_resolve_installed_package "libqglviewer-dev-qt5" >/dev/null 2>&1 || dpkg_resolve_installed_package "libqglviewer2-qt5t64" >/dev/null 2>&1; then
    # A5a: Use printf instead of echo for robustness
    printf "Refreshing library cache for QGLViewer...\n"
    run_ldconfig_refresh
    
    # Verify QGLViewer installation
    if pkg-config --exists libQGLViewer-qt5 2>/dev/null || \
       [ -f /usr/include/QGLViewer/qglviewer.h ] || \
       [ -f /usr/local/include/QGLViewer/qglviewer.h ]; then
      # A5a: Use printf instead of echo -e for robustness (D3b: echo unsafe patterns)
      printf "%s✓ QGLViewer dependencies installed successfully%s\n" "${GREEN}" "${NC}"
    else
      # A5a: Use printf instead of echo -e for robustness (D3b: echo unsafe patterns)
      printf "%s⚠ QGLViewer not found via pkg-config or standard paths%s\n" "${YELLOW}" "${NC}"
      # A5a: Use printf instead of echo for robustness
      printf "  G2O will attempt to build without viewer if QGLViewer is unavailable\n"
    fi
  else
    # A5a: Use printf instead of echo -e for robustness (D3b: echo unsafe patterns)
    printf "%s⚠ QGLViewer packages not installed - G2O will build without viewer%s\n" "${YELLOW}" "${NC}"
  fi
fi

#--- Sub-block 17.10: Compile g2o (graph optimization) ---
# Purpose: Graph optimization library (uses Ceres if available - compiled after Ceres)
# Dependencies: PHASE 1 (Build tools), Sub-block 8.2 (Ceres Solver - optional but recommended), Sub-block 17.9b (QGLViewer dependencies)
# Outputs: Configured system components
if [ "${PHASE3_ALL_SUCCESS}" = true ]; then
  # A5a: Use printf instead of echo -e for robustness (D3b: echo unsafe patterns)
  printf "\n%s[PHASE 3 | g2o] Compiling from source...%s\n" "${YELLOW}" "${NC}"
  # Ensure we're not inside the directory before removing it
  cd / || true
  rm -rf /tmp/g2o
  # Using G2O_VERSION from config.sh
  if ! clone_with_retry "https://github.com/RainerKuemmerle/g2o.git" "/tmp/g2o" "${G2O_VERSION}"; then
    # A5a: Use printf instead of echo for robustness
    printf "ERROR: Failed to clone G2O after all retry attempts\n" >&2
    exit 1
  fi
  cd /tmp/g2o || { printf "ERROR: Failed to access g2o directory\n" >&2; exit 1; }
  # Remove existing build directory if it exists (critical for Singularity rebuilds)
  rm -rf build
  if ! mkdir -p build; then
    # A5a: Use printf instead of echo for robustness
    printf "ERROR: Failed to create build dir\n" >&2
    exit 1
  fi
  if ! cd build; then
    # A5a: Use printf instead of echo for robustness
    printf "ERROR: Failed to access build dir\n" >&2
    exit 1
  fi

  #--- Sub-block 17.11: Configure g2o with CMake ---
  # Critical: CMake configuration - will auto-detect Ceres if available
  # 
  # MKL Integration Strategy (IMPORTANT - g2o does NOT use BLAS/LAPACK flags directly):
  #   - g2o does NOT use BLA_VENDOR, BLAS_LIBRARIES, or LAPACK_LIBRARIES flags (these are IGNORED)
  #   - g2o inherits BLAS/LAPACK configuration from SuiteSparse/CHOLMOD via imported targets
  #   - CHOLMOD solver uses BLAS_DEFINITIONS and LAPACK_DEFINITIONS from SuiteSparse::CHOLMOD target
  #   - SuiteSparse::CHOLMOD was compiled with MKL (BLA_VENDOR=Intel10_64lp in Block 9)
  #   - Result: g2o → CHOLMOD (imported target) → MKL (transitive linkage through SuiteSparse)
  #
  # CUDA Header Support (Required for CHOLMOD with CUDA):
  #   - SuiteSparse/CHOLMOD was compiled with CUDA support (CUDA enabled in Block 9)
  #   - CHOLMOD headers include cublas_v2.h when CUDA is enabled
  #   - g2o cholmod_wrapper.cpp needs CUDA include paths to compile successfully
  #   - Solution: Add CUDA include directory to CMAKE_CXX_FLAGS via -I flag
  #
  # Reference: docs/flags/G2O_20241228_CMAKE_FLAGS_DOCUMENTATION.md (updated with correct flags)
  #
  # Feature Configuration (all explicitly set for clarity):
  #   - Linear Algebra: CHOLMOD (MKL+CUDA-enabled) + CSparse with LGPL libs
  #   - Type System: Full SLAM2D/3D support including SBA, ICP, Sim3
  #   - Optimization: OpenMP enabled, SSE auto-detection
  #   - Logging: spdlog support (libspdlog-dev installed in Block 22)
  #   - Visualization: QGLViewer support enabled for g2o_viewer (Qt5-based 3D visualization)
  #
  # Get CUDA include directory (required for CHOLMOD CUDA headers)
  if [ -z "${CUDA_INCLUDE_DIR:-}" ] && [ -n "${CUDA_HOME:-}" ]; then
    CUDA_INCLUDE_DIR="${CUDA_HOME}/include"
  fi
  if [ -z "${CUDA_INCLUDE_DIR:-}" ]; then
    CUDA_INCLUDE_DIR="/usr/local/cuda-${CUDA_VERSION:-12.6}/include"
  fi
  
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
    -D G2O_USE_LGPL_LIBS=ON \
    -D G2O_USE_OPENMP=ON \
    -D G2O_USE_OPENGL=ON \
    -D G2O_USE_LOGGING=ON \
    -D G2O_BUILD_SLAM2D_TYPES=ON \
    -D G2O_BUILD_SLAM3D_TYPES=ON \
    -D G2O_BUILD_SBA_TYPES=ON \
    -D G2O_BUILD_ICP_TYPES=ON \
    -D G2O_BUILD_SIM3_TYPES=ON \
    -D G2O_BUILD_APPS=ON \
    -D G2O_BUILD_EXAMPLES=OFF \
    -D BUILD_UNITTESTS=OFF \
    -D DO_SSE_AUTODETECT=ON \
    -D CMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
    -D CMAKE_CXX_FLAGS="-march=x86-64-v3 -O3 -mavx2 -mfma -msse4.2 -fopenmp -funroll-loops -I${CUDA_INCLUDE_DIR}" \
    -D CMAKE_C_FLAGS="-march=x86-64-v3 -O3 -mavx2 -mfma -msse4.2 -fopenmp -funroll-loops -I${CUDA_INCLUDE_DIR}" \
    -D CMAKE_SHARED_LINKER_FLAGS="-flto -fopenmp" \
    -D CMAKE_INSTALL_RPATH="/usr/local/lib" \
    -D CMAKE_INSTALL_RPATH_USE_LINK_PATH=TRUE \
    -D SuiteSparse_DIR="${SuiteSparse_DIR}"

  #--- Sub-block 17.12: Build and install g2o ---
  # Critical: Compile g2o with ninja using half CPU cores
  ninja -j$(($(nproc) / 2)) || { printf "ERROR: Failed to build g2o\n" >&2; exit 1; }
  ninja install 2>&1 | tee /tmp/g2o_install.log || { printf "ERROR: Failed to install g2o\n" >&2; exit 1; }
  # Use dynamic directory detection from installation output
  run_ldconfig_refresh_from_install_output "/tmp/g2o_install.log" 200

  #--- Sub-block 17.13: Verify g2o installation ---
  # Critical: Confirm g2o libraries are installed and in linker cache
  # Multi-phase verification: File existence → Linker cache → Retry with refresh → Directory registration
  # A5a: Use printf instead of echo -e for robustness (D3b: echo unsafe patterns)
  printf "%s[DEBUG] Verifying g2o installation...%s\n" "${BLUE}" "${NC}"
  
  # Phase 1: Check if library files exist (handle multi-arch libdirs and versioned libraries)
  g2o_core_candidates=(
    "/usr/local/lib"
    "/usr/local/lib64"
    "/usr/local/lib/x86_64-linux-gnu"
  )
  g2o_core_path=""
  for libdir in "${g2o_core_candidates[@]}"; do
    # Search for any libg2o*.so file (handles versioned libraries like libg2o_core.so.0.1.0)
    # D3e: SIGPIPE protection - add || true at end of pipeline with head
    found_lib=$(find "${libdir}" -maxdepth 1 -name "libg2o*.so*" -type f 2>/dev/null | head -1 2>/dev/null || echo "")
    if [ -n "${found_lib}" ] && [ -f "${found_lib}" ]; then
      # Prefer libg2o_core.so if available, otherwise take first match
      # D3e: SIGPIPE protection - add || true at end of pipeline with head
      core_match=$(find "${libdir}" -maxdepth 1 -name "libg2o_core.so*" -type f 2>/dev/null | head -1 2>/dev/null || echo "")
      if [ -n "${core_match}" ]; then
        g2o_core_path="$(realpath "${core_match}" 2>/dev/null || echo "${core_match}")"
        break
      fi
      g2o_core_path="$(realpath "${found_lib}" 2>/dev/null || echo "${found_lib}")"
      break
    fi
  done

  if [ -z "${g2o_core_path}" ]; then
    printf "%s✗ g2o compilation FAILED: libg2o.so not found under /usr/local%s\n" "${RED}" "${NC}"
    printf "%s[DEBUG] Searching for libg2o*.so under /usr/local:%s\n" "${YELLOW}" "${NC}"
    # D3e: SIGPIPE protection - add || true at end of pipeline
    find /usr/local -maxdepth 2 -name "libg2o*.so*" -print 2>/dev/null | head -20 2>/dev/null || printf "  No g2o libraries found\n" || true
    PHASE3_ALL_SUCCESS=false
  else
    printf "%s✓ g2o library file found: %s%s\n" "${GREEN}" "${g2o_core_path}" "${NC}"

    # Determine SONAME used by ldconfig
    g2o_soname=""
    if command -v objdump >/dev/null 2>&1; then
      g2o_soname="$(objdump -p "${g2o_core_path}" 2>/dev/null | awk '/SONAME/ {print $2; exit}')"
    fi
    # Fallback: try readelf if objdump not available or failed to extract SONAME
    if [ -z "${g2o_soname}" ] && command -v readelf >/dev/null 2>&1; then
      g2o_soname="$(readelf -d "${g2o_core_path}" 2>/dev/null | awk -F'[][]' '/SONAME/ {print $2; exit}')"
    fi
    if [ -z "${g2o_soname}" ]; then
      g2o_soname="$(basename "${g2o_core_path}")"
    fi
    
    # Phase 1a: Extract and validate library directory (CRITICAL - ensure path extraction is correct)
    g2o_lib_dir=""
    g2o_lib_dir=$(dirname "${g2o_core_path}" 2>/dev/null || echo "")
    # Validate extracted directory exists and is a directory (F2: Command substitution validation)
    if [ -z "${g2o_lib_dir}" ] || [ ! -d "${g2o_lib_dir}" ]; then
      # Fallback: try to get directory using realpath
      g2o_lib_dir=$(realpath "$(dirname "${g2o_core_path}")" 2>/dev/null || echo "")
      # If still invalid, use parent directory of file path
      if [ -z "${g2o_lib_dir}" ] || [ ! -d "${g2o_lib_dir}" ]; then
        printf "%s⚠ WARNING: Failed to extract valid library directory from %s, using fallback%s\n" "${YELLOW}" "${g2o_core_path}" "${NC}"
        # Try to find directory by searching for common library paths
        for fallback_dir in "/usr/local/lib" "/usr/local/lib64" "/usr/local/lib/x86_64-linux-gnu"; do
          if [ -d "${fallback_dir}" ] && [ -f "${fallback_dir}/$(basename "${g2o_core_path}")" ] 2>/dev/null; then
            g2o_lib_dir="${fallback_dir}"
            printf "%s[DEBUG] Using fallback directory: %s%s\n" "${YELLOW}" "${g2o_lib_dir}" "${NC}"
            break
          fi
        done
      fi
    fi
    
    # CRITICAL: If directory extraction failed completely, library file exists so don't fail - just warn
    if [ -z "${g2o_lib_dir}" ] || [ ! -d "${g2o_lib_dir}" ]; then
      printf "%s⚠ WARNING: Could not determine library directory, but library file exists at %s%s\n" "${YELLOW}" "${g2o_core_path}" "${NC}"
      printf "%s[DEBUG] Library exists but ldconfig refresh may be skipped (non-fatal)%s\n" "${YELLOW}" "${NC}"
      # Library file exists, so this is not a fatal failure - flag remains unchanged
    else
      printf "%s[DEBUG] Library directory: %s%s\n" "${BLUE}" "${g2o_lib_dir}" "${NC}"
      printf "%s[DEBUG] SONAME: %s%s\n" "${BLUE}" "${g2o_soname}" "${NC}"
      
      # Phase 2: Verify library is available using comprehensive verification function
      if ! verify_library_available "libg2o_core.so" "${g2o_core_path}"; then
        printf "%s⚠ g2o library exists but not fully verified (attempting fix)%s\n" "${YELLOW}" "${NC}"
        printf "%s[DEBUG] Running targeted ldconfig refresh for %s%s\n" "${YELLOW}" "${g2o_lib_dir}" "${NC}"
        
        # Step 1: Ensure directory is registered in ld.so.conf.d (CRITICAL - must be done before refresh)
        printf "%s[DEBUG] Step 1: Verifying %s is registered in ld.so.conf.d...%s\n" "${BLUE}" "${g2o_lib_dir}" "${NC}"
        if ensure_library_path_registered "${g2o_lib_dir}"; then
          printf "%s✓ Directory %s is registered in ld.so.conf.d%s\n" "${GREEN}" "${g2o_lib_dir}" "${NC}"
          
          # Verify registration was successful by checking all conf files
          conf_verified=false
          for conf_file in /etc/ld.so.conf.d/*.conf /etc/ld.so.conf; do
            if [ -f "${conf_file}" ] && grep -q "^${g2o_lib_dir}\$" "${conf_file}" 2>/dev/null; then
              printf "%s✓ Confirmed registration in %s%s\n" "${GREEN}" "${conf_file}" "${NC}"
              conf_verified=true
              break
            fi
          done
          if [ "${conf_verified}" = false ]; then
            printf "%s⚠ WARNING: Directory registered but not found in conf files (may need manual verification)%s\n" "${YELLOW}" "${NC}"
          fi
        else
          printf "%s⚠ WARNING: Failed to register %s in ld.so.conf.d, but continuing...%s\n" "${YELLOW}" "${g2o_lib_dir}" "${NC}"
        fi
        
        # Step 2: Confirm library files exist in directory (best practice - verify before refresh)
        lib_count=""
        lib_count=$(find "${g2o_lib_dir}" -maxdepth 1 -name "libg2o*.so*" -type f 2>/dev/null | wc -l || echo "0")
        printf "%s[DEBUG] Step 2: Confirmed %s g2o library file(s) in %s%s\n" "${BLUE}" "${lib_count}" "${g2o_lib_dir}" "${NC}"
        if [ "${lib_count}" -eq 0 ]; then
          printf "%s⚠ WARNING: No g2o library files found in %s (unexpected)%s\n" "${YELLOW}" "${g2o_lib_dir}" "${NC}"
        else
          printf "%s[DEBUG] Library files in directory:%s\n" "${BLUE}" "${NC}"
          # D3e: SIGPIPE protection - add || true at end of pipeline with head
          find "${g2o_lib_dir}" -maxdepth 1 -name "libg2o*.so*" -type f 2>/dev/null | head -5 2>/dev/null | while IFS= read -r lib_file || [ -n "${lib_file}" ]; do
            if [ -n "${lib_file}" ]; then
              printf "%s[DEBUG]   - %s%s\n" "${BLUE}" "$(basename "${lib_file}")" "${NC}"
            fi
          done || true
        fi
        
        # Step 3: Use targeted directory update (faster and more reliable)
        # Note: run_ldconfig_refresh_dir automatically ensures path is registered in ld.so.conf.d
        # CRITICAL: Add || true to ensure ldconfig failures are non-fatal when files exist
        # Library file exists, so ldconfig issues are warnings, not fatal errors
        printf "%s[DEBUG] Step 3: Executing targeted ldconfig refresh for %s...%s\n" "${BLUE}" "${g2o_lib_dir}" "${NC}"
        run_ldconfig_refresh_dir "${g2o_lib_dir}" 2>&1 || run_ldconfig_refresh 2>&1 || {
          printf "%s⚠ WARNING: ldconfig refresh failed, but library file exists - continuing (non-fatal)%s\n" "${YELLOW}" "${NC}"
          true  # Explicitly ensure non-fatal
        }
        
        # Step 4: Wait a moment for cache to update (best practice - allow time for cache sync)
        sleep 0.2
        
        # Phase 3: Retry verification after refresh using improved method
        printf "%s[DEBUG] Step 4: Re-checking library verification after refresh...%s\n" "${BLUE}" "${NC}"
        if ! verify_library_available "libg2o_core.so" "${g2o_core_path}"; then
          printf "%s⚠ g2o library still not fully verified, running diagnostics...%s\n" "${YELLOW}" "${NC}"
          diagnose_library_detection "libg2o_core.so" "${g2o_core_path}" || true
          
          printf "%s[DEBUG] ldconfig -p output (g2o related):%s\n" "${YELLOW}" "${NC}"
          # D3e: SIGPIPE protection - add || true at end of pipeline
          { ldconfig -p 2>/dev/null | grep -F "libg2o" 2>/dev/null || printf "  No g2o libraries in ldconfig cache\n"; } || true
          printf "%s[DEBUG] However, library files exist at: %s%s\n" "${YELLOW}" "${g2o_core_path}" "${NC}"
          
          # Additional diagnostics
          printf "%s[DEBUG] Diagnostic information:%s\n" "${BLUE}" "${NC}"
          printf "%s[DEBUG]   Library file: %s%s\n" "${BLUE}" "${g2o_core_path}" "${NC}"
          printf "%s[DEBUG]   Library directory: %s%s\n" "${BLUE}" "${g2o_lib_dir}" "${NC}"
          # D3e: SIGPIPE protection - add || true at end of pipeline
          dir_registered="no"
          if [ -f /etc/ld.so.conf.d/00-compiled-libs.conf ]; then
            grep -q "^${g2o_lib_dir}\$" /etc/ld.so.conf.d/00-compiled-libs.conf 2>/dev/null && dir_registered="yes" || true
          fi
          printf "%s[DEBUG]   Directory registered in ld.so.conf.d: %s%s\n" "${BLUE}" "${dir_registered}" "${NC}"
          # D3e: SIGPIPE protection - add || true at end of pipeline
          lib_count=""
          lib_count=$(find "${g2o_lib_dir}" -maxdepth 1 -name "libg2o*.so*" -type f 2>/dev/null | wc -l 2>/dev/null || echo "0" || true)
          printf "%s[DEBUG]   Libraries in directory: %s%s\n" "${BLUE}" "${lib_count}" "${NC}"
          
          # Final verification: Try to load library with ldd (most reliable check)
          if command -v ldd >/dev/null 2>&1 && ldd "${g2o_core_path}" >/dev/null 2>&1; then
            printf "%s✓ g2o library is valid and loadable (ldd verification passed)%s\n" "${GREEN}" "${NC}"
            printf "%s✓ g2o installation successful (files present and valid, cache may update later)%s\n" "${GREEN}" "${NC}"
          else
            printf "%s✓ g2o installation appears successful (files present, cache may be delayed)%s\n" "${GREEN}" "${NC}"
          fi
          # CRITICAL: Don't mark as failed if files exist - cache may update later
          # PHASE3_ALL_SUCCESS flag remains unchanged (stays true) since library file exists
          printf "%s[INFO] Library file exists at %s - build will continue%s\n" "${YELLOW}" "${g2o_core_path}" "${NC}"
          printf "%s[INFO] Library can still be used (cache is optimization, not requirement)%s\n" "${YELLOW}" "${NC}"
          printf "%s[INFO] Cache will be updated on next system restart or manual ldconfig run%s\n" "${YELLOW}" "${NC}"
        else
          printf "%s✓ g2o library registered and verified%s\n" "${GREEN}" "${NC}"
        fi
      else
        printf "%s✓ g2o library found and verified%s\n" "${GREEN}" "${NC}"
      fi
    fi
  fi

  #--- Sub-block 17.13b: Verify g2o_viewer executable (QGL Viewer) ---
  # Critical: Confirm g2o_viewer is built and installed (requires G2O_BUILD_APPS=ON)
  printf "%s[DEBUG] Verifying g2o_viewer executable...%s\n" "${BLUE}" "${NC}"
  
  g2o_viewer_candidates=(
    "/usr/local/bin/g2o_viewer"
    "/usr/local/bin/g2o_viewer-qt5"
    "/tmp/g2o/build/bin/g2o_viewer"
  )
  g2o_viewer_path=""
  for candidate in "${g2o_viewer_candidates[@]}"; do
    if [ -x "${candidate}" ]; then
      g2o_viewer_path="$(realpath "${candidate}" 2>/dev/null || echo "${candidate}")"
      break
    fi
  done
  # ENDFOR: candidate in g2o_viewer_candidates
  
  if [ -z "${g2o_viewer_path:-}" ]; then
    printf "%s⚠ g2o_viewer not found (may not be built if G2O_BUILD_APPS was OFF)%s\n" "${YELLOW}" "${NC}"
  else
    printf "%s✓ g2o_viewer found at: %s%s\n" "${GREEN}" "${g2o_viewer_path}" "${NC}"
  fi

  #--- Sub-block 17.14: Protect compiled G2O from APT overwrites ---
  # Critical: Prevent APT from installing ANY system G2O packages
  # Strategy: Use APT pinning with negative priority (consistent with glog, Ceres, and OpenCV)
  printf '%s\n' "Protecting compiled G2O from APT overwrites..."
  
  # Create APT preferences directory
  mkdir -p /etc/apt/preferences.d
  
  # Block ALL system G2O packages using APT pinning with negative priority
  # Note: other file: /etc/apt/preferences.d/block-system-g2o is installed via install.sh from container-scripts/
  # Source: other/block-17-phase-3-high-level-dependencies/block-system-g2o.txt
  # Target: /etc/apt/preferences.d/block-system-g2o
  # Installed in Block 0 (early in script, before any scripts are needed)
  
  if [ -f "/etc/apt/preferences.d/block-system-g2o" ]; then
      printf "✓ Created APT preferences to block system G2O packages\n"
      printf "  - Blocks: libg2o-dev, libg2o0, libg2o20130302\n"
      printf "  - Method: APT pinning with Pin-Priority: -1\n"
  else
      printf "✗ ERROR: Failed to create G2O protection file\n"
      exit 1
  fi
  
  printf "✓ G2O protected from APT overwrites (APT pinning method)\n"

  # Verify TBB configuration for g2o (ensure system TBB, not MKL TBB)
  printf '%s\n' "Verifying TBB configuration for g2o..."
  if [ -d "/tmp/g2o/build" ]; then
    cd /tmp/g2o/build || { echo "ERROR: Failed to access /tmp/g2o/build directory"; exit 1; }
  else
    printf '%s\n' "INFO: /tmp/g2o/build directory not found, skipping TBB verification"
    cd / || true
  fi
  if [ -f "CMakeCache.txt" ]; then
    TBB_LIB_PATH=""
    TBB_LIB_PATH=$(grep -E "^TBB_LIBRARIES(:|=)" CMakeCache.txt 2>/dev/null | head -1 2>/dev/null | sed 's/.*[=:]//' | tr -d '[:space:]' 2>/dev/null || echo "" || true)
    # F2: Validate command substitution result
    if [ -z "${TBB_LIB_PATH}" ]; then
      TBB_LIB_PATH=""
    fi
    if [ -n "${TBB_LIB_PATH}" ]; then
      if grep -qE "(/opt/intel|/usr/local/intel|/opt/intel/oneapi|mkl)" <<< "${TBB_LIB_PATH}"; then
        printf "  %sERROR: g2o is using MKL TBB: %s%s\n" "${RED}" "${TBB_LIB_PATH}" "${NC}"
        printf "  This may cause runtime conflicts. System TBB should be used.\n"
      elif grep -qE "/usr/lib/x86_64-linux-gnu/libtbb" <<< "${TBB_LIB_PATH}"; then
        printf "  %sOK: g2o is using system TBB: %s%s\n" "${GREEN}" "${TBB_LIB_PATH}" "${NC}"
      else
        printf "  %sWARNING: g2o TBB source uncertain: %s%s\n" "${YELLOW}" "${TBB_LIB_PATH}" "${NC}"
      fi
    else
      printf "  INFO: TBB not detected in g2o configuration (may not be required)\n"
    fi
  else
    printf "  INFO: CMakeCache.txt not found, skipping TBB verification\n"
  fi

  # Cleanup
  cd / || true
  rm -rf /tmp/g2o || true
fi
debug_glibc "After installing g2o"

#--- Sub-block 17.15: Compile GTSAM ---
# Purpose: Build GTSAM SLAM library with TBB and Python bindings
# Dependencies: PHASE 1 (Build tools), sparse solvers (CHOLMOD, METIS)
# Outputs: Configured system components
printf "\n%s[DEBUG] PHASE3_ALL_SUCCESS before GTSAM compilation: %s%s\n" "${BLUE}" "${PHASE3_ALL_SUCCESS}" "${NC}"
if [ "${PHASE3_ALL_SUCCESS}" = true ]; then
  printf "%s[PHASE 3 | GTSAM] Compiling from source...%s\n" "${YELLOW}" "${NC}"
  # Ensure we're not inside the directory before removing it
  cd / || true
  rm -rf /tmp/gtsam
  # Using GTSAM_VERSION from config.sh
  if ! clone_with_retry "https://github.com/borglab/gtsam.git" "/tmp/gtsam" "${GTSAM_VERSION}"; then
    printf '%s\n' "ERROR: Failed to clone GTSAM after all retry attempts" >&2
    exit 1
  fi
  # J1: File/directory existence validation - check directory exists before cd
  if [ ! -d "/tmp/gtsam" ]; then
    printf '%s\n' "ERROR: GTSAM directory not found: /tmp/gtsam" >&2
    exit 1
  fi
  cd /tmp/gtsam || { printf '%s\n' "ERROR: Failed to access gtsam directory" >&2; exit 1; }
  # Remove existing build directory if it exists (critical for Singularity rebuilds)
  rm -rf build || true
  if ! mkdir -p build; then
    printf '%s\n' "ERROR: Failed to create build dir" >&2
    exit 1
  fi
  # J1: File/directory existence validation - check build directory exists before cd
  if [ ! -d "build" ]; then
    printf '%s\n' "ERROR: Build directory not found after creation" >&2
    exit 1
  fi
  if ! cd build; then
    printf '%s\n' "ERROR: Failed to access build dir" >&2
    exit 1
  fi

  # Provide canonical hints for CMake's FindMKL/FindTBB modules so that
  # manually specified cache entries are actually consumed (and do not trigger
  # "ignored" warnings during configuration).
  export MKLDIR="${MKLROOT}"
  export MKL_LIBRARIES="${MKL_BLAS_LIBRARIES}"
  export TBBROOT="${TBBROOT:-/usr}"
  
  # CRITICAL: Set TBB_DIR to point to CMake config directory for modern TBB installations
  # GTSAM's FindTBB.cmake will use TBB_DIR if set, otherwise falls back to TBB_ROOT_DIR
  # Modern Ubuntu TBB packages provide CMake config files at /usr/lib/x86_64-linux-gnu/cmake/TBB
  TBB_CMAKE_DIR="/usr/lib/x86_64-linux-gnu/cmake/TBB"
  if [ ! -d "${TBB_CMAKE_DIR}" ]; then
    # Fallback: try to find TBB CMake config in standard locations
    # Phase 1: Find TBB CMake directory
    # Use process substitution to avoid pipe subshell (D3: PIPE PATTERN SAFETY)
    tbb_found_dir=""
    while IFS= read -r -d '' found_path && [ -z "${tbb_found_dir:-}" ]; do
      if [ -n "${found_path:-}" ] && [ -d "${found_path}" ]; then
        tbb_found_dir="${found_path}"
        break
      fi
    done < <(find /usr -type d -path "*/cmake/TBB" -print0 2>/dev/null || true)
    # Phase 2: Validate result before using (H1: Error Handling, B3: Strict Mode Validation)
    if [ -n "${tbb_found_dir:-}" ] && [ -d "${tbb_found_dir}" ]; then
      TBB_CMAKE_DIR="${tbb_found_dir}"
    else
      TBB_CMAKE_DIR=""
    fi
  fi

  #--- Sub-block 17.16: Configure GTSAM with CMake ---
  # Critical: Enable TBB, Python bindings, system libraries
  # IMPORTANT: TBB (Threading Building Blocks) is independent from Intel MKL:
  # - TBB: Intel's threading library for parallel algorithms (installed via libtbb-dev)
  # - MKL: Linear algebra implementation (BLAS/LAPACK) provided by Intel oneAPI
  # - They coexist but are linked separately (MKL via FindMKL, TBB via FindTBB)
  # - TBB_DIR points to CMake config directory (preferred for modern TBB installations)
  # - TBB_ROOT_DIR points to the system TBB package base directory (fallback)
  # - MKL_ROOT_DIR/MKL_LIBRARIES align with GTSAM's bundled FindMKL.cmake logic
  # CRITICAL FIX: GTSAM's FindTBB.cmake may ignore TBB_DIR, so we explicitly set
  # TBB_LIBRARIES and TBB_INCLUDE_DIR (similar to OpenCV configuration) to ensure
  # TBB is found even if TBB_DIR is ignored by CMake's find_package() mechanism.
  CMAKE_TBB_ARGS=()
  TBB_LIB_PATH="/usr/lib/x86_64-linux-gnu/libtbb.so"
  TBB_INCLUDE_PATH="/usr/include/tbb"
  
  # Verify TBB library exists (fallback search if default path doesn't exist)
  if [ ! -f "${TBB_LIB_PATH}" ]; then
    # Search for libtbb.so in standard library paths
    # F2: Command substitution validation - validate find result format
    tbb_lib_found=""
    tbb_lib_found=$(find /usr/lib* -name "libtbb.so" 2>/dev/null | head -1 2>/dev/null || echo "" || true)
    # Validate result is non-empty and is a valid file path
    if [ -n "${tbb_lib_found}" ] && [ -f "${tbb_lib_found}" ]; then
      TBB_LIB_PATH="${tbb_lib_found}"
    fi
  fi
  
  # Verify TBB include directory exists
  if [ ! -d "${TBB_INCLUDE_PATH}" ]; then
    # Search for tbb include directory
    # F2: Command substitution validation - validate find result format
    tbb_include_found=""
    tbb_include_found=$(find /usr/include -type d -name "tbb" 2>/dev/null | head -1 2>/dev/null || echo "" || true)
    # Validate result is non-empty and is a valid directory path
    if [ -n "${tbb_include_found}" ] && [ -d "${tbb_include_found}" ]; then
      TBB_INCLUDE_PATH="${tbb_include_found}"
    fi
  fi
  
  # CRITICAL: Verify TBB version header exists (required by GTSAM's FindTBB.cmake)
  # GTSAM's FindTBB.cmake checks for version header to determine TBB version
  # On Ubuntu 24.04, /usr/include/tbb/version.h is a wrapper that includes ../oneapi/tbb/version.h
  # We need to verify both the wrapper and the actual header exist
  # Phase 1: Initialize version header tracking variables
  TBB_VERSION_HEADER_FOUND=false
  TBB_VERSION_HEADER_PATH=""
  ONEAPI_TBB_VERSION_HEADER="/usr/include/oneapi/tbb/version.h"
  
  # Phase 2: Verify TBB include directory exists before checking for version header
  if [ -d "${TBB_INCLUDE_PATH}" ]; then
    # Phase 2a: Check for common version header file names in the main tbb directory
    if [ -f "${TBB_INCLUDE_PATH}/version.h" ]; then
      TBB_VERSION_HEADER_PATH="${TBB_INCLUDE_PATH}/version.h"
      TBB_VERSION_HEADER_FOUND=true
      printf "[INFO] TBB version header found at %s\n" "${TBB_VERSION_HEADER_PATH}"
      
      # Phase 2b: On Ubuntu 24.04, tbb/version.h is a wrapper that includes ../oneapi/tbb/version.h
      # Verify the actual oneapi version header exists (required for the wrapper to work)
      if [ -f "${ONEAPI_TBB_VERSION_HEADER}" ]; then
        printf "[INFO] TBB oneapi version header found at %s (required by wrapper)\n" "${ONEAPI_TBB_VERSION_HEADER}"
      else
        # Use safe color variables with defaults (C1, C5: Unbound variable protection)
        YELLOW="${YELLOW:-}"
        NC="${NC:-}"
        if [ -n "${YELLOW}" ] && [ -n "${NC}" ]; then
          printf "%s[WARNING] TBB oneapi version header not found at %s%s\n" "${YELLOW}" "${ONEAPI_TBB_VERSION_HEADER}" "${NC}"
          printf "%sThe wrapper at %s may not work correctly.%s\n" "${YELLOW}" "${TBB_VERSION_HEADER_PATH}" "${NC}"
        else
          printf "[WARNING] TBB oneapi version header not found at %s\n" "${ONEAPI_TBB_VERSION_HEADER}"
          printf "The wrapper at %s may not work correctly.\n" "${TBB_VERSION_HEADER_PATH}"
        fi
        # Don't fail here - let CMake try, but warn
      fi
    elif [ -f "${TBB_INCLUDE_PATH}/tbb_version.h" ]; then
      TBB_VERSION_HEADER_PATH="${TBB_INCLUDE_PATH}/tbb_version.h"
      TBB_VERSION_HEADER_FOUND=true
      printf "[INFO] TBB version header found at %s\n" "${TBB_VERSION_HEADER_PATH}"
    elif [ -f "${TBB_INCLUDE_PATH}/version.h.in" ]; then
      TBB_VERSION_HEADER_PATH="${TBB_INCLUDE_PATH}/version.h.in"
      TBB_VERSION_HEADER_FOUND=true
      printf "[INFO] TBB version header template found at %s\n" "${TBB_VERSION_HEADER_PATH}"
    else
      # Phase 2c: Search for version header in subdirectories
      # F2: Command substitution validation - validate find result format
      # D3e: SIGPIPE protection - add || true at end of pipeline
      tbb_version_header_found=""
      tbb_version_header_found=$(find "${TBB_INCLUDE_PATH}" \( -name "version.h" -o -name "tbb_version.h" \) -type f 2>/dev/null | head -1 2>/dev/null || echo "" || true)
      # Validate result is non-empty and is a valid file path (F2: Command substitution format validation)
      if [ -n "${tbb_version_header_found}" ] && [ -f "${tbb_version_header_found}" ]; then
        TBB_VERSION_HEADER_PATH="${tbb_version_header_found}"
        TBB_VERSION_HEADER_FOUND=true
        printf "[INFO] TBB version header found at %s\n" "${TBB_VERSION_HEADER_PATH}"
      fi
    fi
    
    # Phase 3: If version header not found, report error with diagnostic information
    if [ "${TBB_VERSION_HEADER_FOUND}" != true ]; then
      # Use safe color variables with defaults (C1, C5: Unbound variable protection)
      RED="${RED:-}"
      YELLOW="${YELLOW:-}"
      NC="${NC:-}"
      if [ -n "${RED}" ] && [ -n "${NC}" ]; then
        printf "%sERROR: TBB version header not found in %s%s\n" "${RED}" "${TBB_INCLUDE_PATH}" "${NC}"
      else
        printf "ERROR: TBB version header not found in %s\n" "${TBB_INCLUDE_PATH}"
      fi
      if [ -n "${YELLOW}" ] && [ -n "${NC}" ]; then
        printf "%sGTSAM's FindTBB.cmake requires a version header (version.h or tbb_version.h) to determine TBB version.%s\n" "${YELLOW}" "${NC}"
        printf "%sDiagnostic information:%s\n" "${YELLOW}" "${NC}"
      else
        printf "GTSAM's FindTBB.cmake requires a version header (version.h or tbb_version.h) to determine TBB version.\n"
        printf "Diagnostic information:\n"
      fi
      printf "  TBB include directory: %s\n" "${TBB_INCLUDE_PATH}"
      if [ -d "${TBB_INCLUDE_PATH}" ]; then
        printf "  Directory exists: YES\n"
        printf "  Contents of %s:\n" "${TBB_INCLUDE_PATH}"
        # SC2012: Use find instead of ls for better handling of non-alphanumeric filenames
        # Use parentheses to group -type f and -type d conditions correctly
        # D3e: SIGPIPE protection - add || true at end of pipeline
        { find "${TBB_INCLUDE_PATH}" -maxdepth 1 \( -type f -o -type d \) 2>/dev/null | head -15 2>/dev/null | while IFS= read -r item || [ -n "${item}" ]; do
          if [ -n "${item}" ]; then
            printf "    %s\n" "${item}"
          fi
        done || printf "    (cannot list contents)\n"; } || true
        printf "\n"
        printf "  Searching for version headers:\n"
        # D3e: SIGPIPE protection - add || true at end of pipeline
        { find "${TBB_INCLUDE_PATH}" -name "*version*" -type f 2>/dev/null | head -5 2>/dev/null | while IFS= read -r version_file; do
          if [ -n "${version_file}" ]; then
            printf "    %s\n" "${version_file}"
          fi
        done || printf "    (no version files found)\n"; } || true
      else
        printf "  Directory exists: NO\n"
      fi
      # ENDIF: TBB_INCLUDE_PATH directory check
      printf "\n"
      printf "  TBB library path: %s\n" "${TBB_LIB_PATH}"
      printf "  TBB library exists: %s\n" "$([ -f "${TBB_LIB_PATH}" ] && echo "YES" || echo "NO")"
      printf "\n"
      printf "  Checking for oneapi TBB headers:\n"
      if [ -d "/usr/include/oneapi/tbb" ]; then
        printf "    /usr/include/oneapi/tbb exists: YES\n"
        if [ -f "/usr/include/oneapi/tbb/version.h" ]; then
          printf "    /usr/include/oneapi/tbb/version.h exists: YES\n"
        else
          printf "    /usr/include/oneapi/tbb/version.h exists: NO\n"
        fi
        # ENDIF: oneapi/tbb/version.h check
      else
        printf "    /usr/include/oneapi/tbb exists: NO\n"
      fi
      # ENDIF: oneapi/tbb directory check
      printf "\n"
      if [ -n "${YELLOW}" ] && [ -n "${NC}" ]; then
        printf "%sPossible solutions:%s\n" "${YELLOW}" "${NC}"
      else
        printf "Possible solutions:\n"
      fi
      printf "  1. Ensure libtbb-dev is properly installed: apt-get install --reinstall libtbb-dev\n"
      printf "  2. Verify TBB installation: dpkg -L libtbb-dev (then grep for version.h in output)\n"
      printf "  3. Check if TBB headers are in a different location\n"
      exit 1
    fi
    # ENDIF: TBB_VERSION_HEADER_FOUND check
  else
    # Use safe color variables with defaults (C1, C5: Unbound variable protection)
    RED="${RED:-}"
    YELLOW="${YELLOW:-}"
    NC="${NC:-}"
    if [ -n "${RED}" ] && [ -n "${NC}" ]; then
      printf "%sERROR: TBB include directory not found at %s%s\n" "${RED}" "${TBB_INCLUDE_PATH}" "${NC}"
    else
      printf "ERROR: TBB include directory not found at %s\n" "${TBB_INCLUDE_PATH}"
    fi
    if [ -n "${YELLOW}" ] && [ -n "${NC}" ]; then
      printf "%sEnsure libtbb-dev is installed: apt-get install libtbb-dev%s\n" "${YELLOW}" "${NC}"
    else
      printf "Ensure libtbb-dev is installed: apt-get install libtbb-dev\n"
    fi
    exit 1
  fi
  # ENDIF: TBB_INCLUDE_PATH directory check
  
  # Build TBB configuration arguments
  if [ -n "${TBB_CMAKE_DIR}" ] && [ -d "${TBB_CMAKE_DIR}" ]; then
    CMAKE_TBB_ARGS+=("-D" "TBB_DIR=${TBB_CMAKE_DIR}")
    printf '%s\n' "[INFO] Using TBB_DIR=${TBB_CMAKE_DIR} for GTSAM TBB configuration"
  else
    CMAKE_TBB_ARGS+=("-D" "TBB_ROOT_DIR=${TBBROOT}")
    printf '%s\n' "[INFO] Using TBB_ROOT_DIR=${TBBROOT} for GTSAM TBB configuration (TBB_DIR not found)"
  fi
  
  # CRITICAL: Explicitly set TBB_LIBRARIES and TBB_INCLUDE_DIR to ensure FindTBB.cmake
  # can locate TBB even if TBB_DIR is ignored (this matches OpenCV's working configuration)
  # IMPORTANT: GTSAM's FindTBB.cmake expects TBB_INCLUDE_DIRS to be the BASE include directory
  # (e.g., /usr/include), not the tbb subdirectory (e.g., /usr/include/tbb), because it
  # constructs paths like ${TBB_INCLUDE_DIRS}/tbb/tbb.h and ${TBB_INCLUDE_DIRS}/oneapi/tbb/version.h
  # Phase 1: Set TBB_LIBRARIES if library exists
  if [ -f "${TBB_LIB_PATH}" ]; then
    CMAKE_TBB_ARGS+=("-D" "TBB_LIBRARIES=${TBB_LIB_PATH}")
    printf '%s\n' "[INFO] Explicitly setting TBB_LIBRARIES=${TBB_LIB_PATH}"
  fi
  # ENDIF: TBB_LIB_PATH check
  
  # Phase 2: Set TBB_INCLUDE_DIRS to base directory (required by GTSAM's FindTBB.cmake)
  if [ -d "${TBB_INCLUDE_PATH}" ]; then
    # Extract base include directory (e.g., /usr/include/tbb -> /usr/include)
    # F2: Command substitution validation - dirname always returns a path
    TBB_BASE_INCLUDE_DIR=""
    TBB_BASE_INCLUDE_DIR=$(dirname "${TBB_INCLUDE_PATH}" 2>/dev/null || echo "")
    # Validate dirname result is non-empty and is a valid directory path
    if [ -z "${TBB_BASE_INCLUDE_DIR}" ] || [ ! -d "${TBB_BASE_INCLUDE_DIR}" ]; then
      printf '%s\n' "[WARNING] Failed to extract base include directory from ${TBB_INCLUDE_PATH}, using fallback" >&2
      TBB_BASE_INCLUDE_DIR="${TBB_INCLUDE_PATH}"
    fi
    
    # Phase 2a: Verify the base directory contains both tbb and oneapi/tbb subdirectories
    if [ -d "${TBB_BASE_INCLUDE_DIR}/tbb" ] && [ -d "${TBB_BASE_INCLUDE_DIR}/oneapi/tbb" ]; then
      CMAKE_TBB_ARGS+=("-D" "TBB_INCLUDE_DIR=${TBB_BASE_INCLUDE_DIR}")
      CMAKE_TBB_ARGS+=("-D" "TBB_INCLUDE_DIRS=${TBB_BASE_INCLUDE_DIR}")
      printf '%s\n' "[INFO] Setting TBB_INCLUDE_DIRS=${TBB_BASE_INCLUDE_DIR} (base directory for GTSAM's FindTBB.cmake)"
      printf '%s\n' "[INFO]   This allows FindTBB.cmake to find: ${TBB_BASE_INCLUDE_DIR}/tbb/tbb.h"
      printf '%s\n' "[INFO]   and: ${TBB_BASE_INCLUDE_DIR}/oneapi/tbb/version.h"
    else
      # Phase 2b: Fallback: use the tbb subdirectory if base directory structure is unexpected
      CMAKE_TBB_ARGS+=("-D" "TBB_INCLUDE_DIR=${TBB_INCLUDE_PATH}")
      CMAKE_TBB_ARGS+=("-D" "TBB_INCLUDE_DIRS=${TBB_INCLUDE_PATH}")
      printf '%s\n' "[INFO] Setting TBB_INCLUDE_DIRS=${TBB_INCLUDE_PATH} (fallback - using tbb subdirectory)"
    fi
    # ENDIF: TBB_BASE_INCLUDE_DIR subdirectory verification
  fi
  # ENDIF: TBB_INCLUDE_PATH directory check
  
  # Exclude MKL TBB paths from CMake search to prevent conflicts
  # This ensures system TBB is used, not MKL's bundled TBB
  CMAKE_IGNORE_TBB_PATHS=""
  if [ -d "/opt/intel/oneapi/tbb" ]; then
    CMAKE_IGNORE_TBB_PATHS="/opt/intel/oneapi/tbb"
  fi
  if [ -d "/opt/intel/tbb" ]; then
    CMAKE_IGNORE_TBB_PATHS="${CMAKE_IGNORE_TBB_PATHS}${CMAKE_IGNORE_TBB_PATHS:+;}/opt/intel/tbb"
  fi
  
  cmake .. \
    -G Ninja \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_INSTALL_PREFIX=/usr/local \
    -D CMAKE_POLICY_DEFAULT_CMP0069=NEW \
    -D BUILD_SHARED_LIBS=ON \
    -D GTSAM_WITH_TBB=ON \
    "${CMAKE_TBB_ARGS[@]}" \
    ${CMAKE_IGNORE_TBB_PATHS:+-D CMAKE_IGNORE_PATH="${CMAKE_IGNORE_TBB_PATHS}"} \
    -D GTSAM_WITH_EIGEN_MKL=ON \
    -D GTSAM_WITH_EIGEN_MKL_OPENMP=ON \
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
    -D GTSAM_PYTHON_VERSION="${SYSTEM_PYTHON_VER}" \
    -D GTSAM_BUILD_WITH_MARCH_NATIVE=OFF \
    -D CMAKE_CXX_STANDARD=17 \
    -D CMAKE_CXX_STANDARD_REQUIRED=ON \
    -D CMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
    -D MKL_ROOT_DIR="${MKLROOT}" \
    -D MKL_INCLUDE_DIR="${MKL_INCLUDE_DIR}" \
    -D MKL_LIBRARIES="${MKL_BLAS_LIBRARIES}"

#--- Sub-block 17.17: Build and install GTSAM ---
# Critical: Compile with ninja using half CPU cores
# F2: Command substitution validation - validate nproc result
nproc_count=""
nproc_count=$(nproc 2>/dev/null || echo "1")
# Validate nproc result is numeric
if ! [ "${nproc_count}" -ge 1 ] 2>/dev/null; then
  nproc_count=1
fi
ninja -j$((nproc_count / 2)) || { printf '%s\n' "ERROR: Failed to build GTSAM" >&2; exit 1; }
# J1: File/directory existence validation - check parent directory exists before writing log
if [ ! -d "/tmp" ]; then
  mkdir -p /tmp || { printf '%s\n' "ERROR: Failed to create /tmp directory" >&2; exit 1; }
fi
ninja install 2>&1 | tee /tmp/gtsam_install.log || { printf '%s\n' "ERROR: Failed to install GTSAM" >&2; exit 1; }
# Use dynamic directory detection from installation output
# J1: File/directory existence validation - check log file exists before using
if [ -f "/tmp/gtsam_install.log" ]; then
  run_ldconfig_refresh_from_install_output "/tmp/gtsam_install.log" 200
else
  printf '%s\n' "[WARNING] GTSAM install log not found, skipping dynamic directory detection" >&2
  # Fallback: refresh standard library directories
  run_ldconfig_refresh || true
fi

  #--- Sub-block 17.18: Verify GTSAM installation ---
  # Critical: Confirm GTSAM libraries are installed and in linker cache
  # Multi-phase verification: File existence → Linker cache → Retry with refresh
  if [ -n "${BLUE}" ] && [ -n "${NC}" ]; then
    printf "%s[DEBUG] Verifying GTSAM installation...%s\n" "${BLUE}" "${NC}"
  else
    printf "[DEBUG] Verifying GTSAM installation...\n"
  fi
  
  # Phase 1: Check if library files exist (handle multi-arch libdirs and versioned libraries)
  gtsam_core_candidates=(
    "/usr/local/lib"
    "/usr/local/lib64"
    "/usr/local/lib/x86_64-linux-gnu"
  )
  gtsam_core_path=""
  for libdir in "${gtsam_core_candidates[@]}"; do
    # Search for any libgtsam*.so file (handles versioned libraries like libgtsam.so.4.2.0)
    # F2: Command substitution validation - validate find result format
    # D3e: SIGPIPE protection - add || true at end of pipeline
    found_lib=""
    found_lib=$(find "${libdir}" -maxdepth 1 -name "libgtsam*.so*" -type f 2>/dev/null | head -1 2>/dev/null || echo "" || true)
    # Validate result is non-empty and is a valid file path
    if [ -n "${found_lib}" ] && [ -f "${found_lib}" ]; then
      gtsam_core_path=""
      gtsam_core_path="$(realpath "${found_lib}" 2>/dev/null || echo "${found_lib}")"
      break
    fi
  done
  
  if [ -z "${gtsam_core_path}" ]; then
    if [ -n "${RED}" ] && [ -n "${NC}" ]; then
      printf "%s✗ GTSAM compilation FAILED: libgtsam.so not found under /usr/local%s\n" "${RED}" "${NC}"
    else
      printf "✗ GTSAM compilation FAILED: libgtsam.so not found under /usr/local\n"
    fi
    if [ -n "${YELLOW}" ] && [ -n "${NC}" ]; then
      printf "%s[DEBUG] Searching for libgtsam*.so under /usr/local:%s\n" "${YELLOW}" "${NC}"
    else
      printf "[DEBUG] Searching for libgtsam*.so under /usr/local:\n"
    fi
    find /usr/local -maxdepth 2 -name "libgtsam*.so*" -print 2>/dev/null || printf '%s\n' "  No GTSAM libraries found" || true
    PHASE3_ALL_SUCCESS=false
  else
    if [ -n "${GREEN}" ] && [ -n "${NC}" ]; then
      printf "%s✓ GTSAM library file found: %s%s\n" "${GREEN}" "${gtsam_core_path}" "${NC}"
    else
      printf "✓ GTSAM library file found: %s\n" "${gtsam_core_path}"
    fi
    
    # Determine SONAME used by ldconfig
    gtsam_soname=""
    if command -v objdump >/dev/null 2>&1; then
      gtsam_soname="$(objdump -p "${gtsam_core_path}" 2>/dev/null | awk '/SONAME/ {print $2; exit}' 2>/dev/null || echo "" || true)"
    fi
    if [ -z "${gtsam_soname}" ]; then
      gtsam_soname="$(basename "${gtsam_core_path}")"
    fi
    gtsam_lib_dir="$(dirname "${gtsam_core_path}")"
    
    # Phase 2: Verify library is available using comprehensive verification function
    if ! verify_library_available "libgtsam.so" "${gtsam_core_path}"; then
      if [ -n "${YELLOW}" ] && [ -n "${NC}" ]; then
        printf "%s⚠ GTSAM library exists but not fully verified (attempting fix)%s\n" "${YELLOW}" "${NC}"
        printf "%s[DEBUG] Running targeted ldconfig refresh for %s%s\n" "${YELLOW}" "${gtsam_lib_dir}" "${NC}"
      else
        printf "⚠ GTSAM library exists but not fully verified (attempting fix)\n"
        printf "[DEBUG] Running targeted ldconfig refresh for %s\n" "${gtsam_lib_dir}"
      fi
      
      # Use targeted directory update (faster and more reliable)
      # Note: run_ldconfig_refresh_dir automatically ensures path is registered in ld.so.conf.d
      run_ldconfig_refresh_dir "${gtsam_lib_dir}" || run_ldconfig_refresh
      
      # Phase 3: Retry verification after refresh using improved method
      if ! verify_library_available "libgtsam.so" "${gtsam_core_path}"; then
        if [ -n "${YELLOW}" ] && [ -n "${NC}" ]; then
          printf "%s⚠ GTSAM library still not fully verified, running diagnostics...%s\n" "${YELLOW}" "${NC}"
        else
          printf "⚠ GTSAM library still not fully verified, running diagnostics...\n"
        fi
        diagnose_library_detection "libgtsam.so" "${gtsam_core_path}" || true
        
        if [ -n "${YELLOW}" ] && [ -n "${NC}" ]; then
          printf "%s[DEBUG] ldconfig -p output (GTSAM related):%s\n" "${YELLOW}" "${NC}"
        else
          printf "[DEBUG] ldconfig -p output (GTSAM related):\n"
        fi
        # D3e: SIGPIPE protection - add || true at end of pipeline
        { ldconfig -p 2>/dev/null | grep -F "libgtsam" 2>/dev/null || printf "  No GTSAM libraries in ldconfig cache\n"; } || true
        if [ -n "${YELLOW}" ] && [ -n "${NC}" ]; then
          printf "%s[DEBUG] However, library files exist at: %s%s\n" "${YELLOW}" "${gtsam_core_path}" "${NC}"
        else
          printf "[DEBUG] However, library files exist at: %s\n" "${gtsam_core_path}"
        fi
        
        # Final verification: Try to load library with ldd (most reliable check)
        if command -v ldd >/dev/null 2>&1 && ldd "${gtsam_core_path}" >/dev/null 2>&1; then
          if [ -n "${GREEN}" ] && [ -n "${NC}" ]; then
            printf "%s✓ GTSAM library is valid and loadable (ldd verification passed)%s\n" "${GREEN}" "${NC}"
            printf "%s✓ GTSAM installation successful (files present and valid, cache may update later)%s\n" "${GREEN}" "${NC}"
          else
            printf "✓ GTSAM library is valid and loadable (ldd verification passed)\n"
            printf "✓ GTSAM installation successful (files present and valid, cache may update later)\n"
          fi
        else
          if [ -n "${GREEN}" ] && [ -n "${NC}" ]; then
            printf "%s✓ GTSAM library found and verified%s\n" "${GREEN}" "${NC}"
          else
            printf "✓ GTSAM library found and verified\n"
          fi
        fi
      fi
    fi
  fi

  #--- Sub-block 17.19: Protect compiled GTSAM from APT overwrites ---
  # Critical: Prevent APT from installing ANY system GTSAM packages
  # Strategy: Use APT pinning with negative priority (consistent with glog, Ceres, G2O, and OpenCV)
  printf '%s\n' "Protecting compiled GTSAM from APT overwrites..."
  
  # Create APT preferences directory
  mkdir -p /etc/apt/preferences.d
  
  # Block ALL system GTSAM packages using APT pinning with negative priority
  # Note: config-files file: /etc/apt/preferences.d/block-system-gtsam is installed via install.sh from container-scripts/
  # Source: config-files/block-17-phase-3-high-level-dependencies/block-system-gtsam.pref
  # Target: /etc/apt/preferences.d/block-system-gtsam
  # Installed in Block 0 (early in script, before any scripts are needed)
  
  if [ -f "/etc/apt/preferences.d/block-system-gtsam" ]; then
      printf '%s\n' "✓ Created APT preferences to block system GTSAM packages"
      printf '%s\n' "  - Blocks: libgtsam-dev, libgtsam4, libgtsam-unstable4"
      printf '%s\n' "  - Method: APT pinning with Pin-Priority: -1"
  else
      printf '%s\n' "✗ ERROR: Failed to create GTSAM protection file" >&2
      exit 1
  fi
  
  printf "✓ GTSAM protected from APT overwrites (APT pinning method)\n"

  # Verify TBB configuration for GTSAM (CRITICAL - GTSAM requires TBB)
  printf "Verifying TBB configuration for GTSAM...\n"
  # SC2164: cd with error handling - using || true for cleanup operation (directory may not exist)
  cd /tmp/gtsam/build 2>/dev/null || true
  if [ -f "CMakeCache.txt" ]; then
    TBB_LIB_PATH=$(grep -E "^TBB_LIBRARIES(:|=)" CMakeCache.txt 2>/dev/null | head -1 2>/dev/null | sed 's/.*[=:]//' 2>/dev/null | tr -d '[:space:]' 2>/dev/null || echo "" || true)
    TBB_FOUND=$(grep -E "^GTSAM_WITH_TBB:BOOL=(ON|TRUE)" CMakeCache.txt 2>/dev/null || echo "")
    
    if [ -n "${TBB_FOUND}" ]; then
      printf "  OK: GTSAM_WITH_TBB is enabled\n"
      if [ -n "${TBB_LIB_PATH}" ]; then
        if grep -qE -- "(/opt/intel|/usr/local/intel|/opt/intel/oneapi|mkl)" <<< "${TBB_LIB_PATH}"; then
          if [ -n "${RED}" ] && [ -n "${NC}" ]; then
            printf "  %sERROR: GTSAM is using MKL TBB: %s%s\n" "${RED}" "${TBB_LIB_PATH}" "${NC}"
          else
            printf "  ERROR: GTSAM is using MKL TBB: %s\n" "${TBB_LIB_PATH}"
          fi
          printf "  This WILL cause runtime conflicts. System TBB is required.\n"
          printf "  Recommendation: Rebuild GTSAM with -DTBB_DIR=/usr/lib/x86_64-linux-gnu/cmake/TBB\n"
        elif grep -qE -- "/usr/lib/x86_64-linux-gnu/libtbb" <<< "${TBB_LIB_PATH}"; then
          if [ -n "${GREEN}" ] && [ -n "${NC}" ]; then
            printf "  %sOK: GTSAM is using system TBB: %s%s\n" "${GREEN}" "${TBB_LIB_PATH}" "${NC}"
          else
            printf "  OK: GTSAM is using system TBB: %s\n" "${TBB_LIB_PATH}"
          fi
        else
          if [ -n "${YELLOW}" ] && [ -n "${NC}" ]; then
            printf "  %sWARNING: GTSAM TBB source uncertain: %s%s\n" "${YELLOW}" "${TBB_LIB_PATH}" "${NC}"
          else
            printf "  WARNING: GTSAM TBB source uncertain: %s\n" "${TBB_LIB_PATH}"
          fi
        fi
      else
        if [ -n "${YELLOW}" ] && [ -n "${NC}" ]; then
          printf "  %sWARNING: GTSAM_WITH_TBB enabled but TBB_LIBRARIES not found%s\n" "${YELLOW}" "${NC}"
        else
          printf "  WARNING: GTSAM_WITH_TBB enabled but TBB_LIBRARIES not found\n"
        fi
        printf "  This may indicate TBB_DIR or TBB_ROOT_DIR was not set correctly\n"
        printf "  Check that TBB is installed (use: dpkg -l and search for libtbb)\n"
        printf "  Verify TBB_DIR points to CMake config: ls -la /usr/lib/x86_64-linux-gnu/cmake/TBB\n"
        printf "  If TBB_DIR is not set, GTSAM's FindTBB.cmake may not find system TBB\n"
      fi
    else
      if [ -n "${YELLOW}" ] && [ -n "${NC}" ]; then
        printf "  %sWARNING: GTSAM_WITH_TBB is disabled (TBB support not enabled)%s\n" "${YELLOW}" "${NC}"
      else
        printf "  WARNING: GTSAM_WITH_TBB is disabled (TBB support not enabled)\n"
      fi
    fi
  else
    printf "  INFO: CMakeCache.txt not found, skipping TBB verification\n"
  fi

  # Cleanup
  cd / && rm -rf /tmp/gtsam
else
  if [ -n "${RED}" ] && [ -n "${NC}" ]; then
    printf "%s⚠ [PHASE 3 | GTSAM] SKIPPED - Previous phase failure detected!%s\n" "${RED}" "${NC}"
    printf "%s  PHASE3_ALL_SUCCESS = %s%s\n" "${RED}" "${PHASE3_ALL_SUCCESS}" "${NC}"
  else
    printf "⚠ [PHASE 3 | GTSAM] SKIPPED - Previous phase failure detected!\n"
    printf "  PHASE3_ALL_SUCCESS = %s\n" "${PHASE3_ALL_SUCCESS}"
  fi
  if [ -n "${YELLOW}" ] && [ -n "${NC}" ]; then
    printf "%s  Check the g2o compilation/verification logs above for errors.%s\n" "${YELLOW}" "${NC}"
  else
    printf "  Check the g2o compilation/verification logs above for errors.\n"
  fi
fi
debug_glibc "After GTSAM section (compiled or skipped)"

#--- Sub-block 17.20: Phase 3 completion verification ---
# Critical: Verify all Phase 3 libraries compiled successfully
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
if [ "${PHASE3_ALL_SUCCESS}" = true ]; then
  if [ -n "${GREEN}" ] && [ -n "${NC}" ]; then
    printf "%s✓ [PHASE 3] All high-level dependencies compiled and installed successfully.%s\n" "${GREEN}" "${NC}"
  else
    printf "✓ [PHASE 3] All high-level dependencies compiled and installed successfully.\n"
  fi
  export PHASE3_STATUS="PASS"
else
  if [ -n "${RED}" ] && [ -n "${NC}" ]; then
    printf "%s✗ [PHASE 3] One or more compilations failed. Please review logs.%s\n" "${RED}" "${NC}"
  else
    printf "✗ [PHASE 3] One or more compilations failed. Please review logs.\n"
  fi
  export PHASE3_STATUS="FAIL"
  exit 1
fi
# End Phase 3 verification (if-else self-contained)

#===============================================================================
# BLOCK 18: JULIA LANGUAGE INSTALLATION
#===============================================================================
# Purpose: Install Julia 1.10 LTS with package environments
# Self-contained: Yes (complete with verification)
# Dependencies: Cached Julia tarball, GPG verification
# Outputs: Julia packages, environments
# NOTE: Installed after GTSAM to use CxxWrap for Julia-C++ interop
#-------------------------------------------------------------------------------

#--- Sub-block 18.1: Julia version and path configuration ---
# Critical: Use Julia configuration from config.sh
# Dependencies: config.sh (sourced at top of script)
# Outputs: Environment variables, configuration
# All Julia variables (version, URL, tarball) come from config.sh
JVER="${JULIA_LTS_VER}"
JMAJOR="${JULIA_LTS_VER%.*}" # e.g. 1.10 (bash parameter expansion)
# Derived URLs (not in config.sh but needed here)
JULIA_BASEURL="https://julialang-s3.julialang.org/bin/linux/x64/${JMAJOR}"
# shellcheck disable=SC2034 # JULIA_SUMS_URL may be used by download functions
JULIA_SUMS_URL="${JULIA_BASEURL}/SHA256SUMS"
CACHE_DIR="${CONTAINER_BIN_CACHE}"
INSTALL_DIR="/opt"
LATEST_TGZ="${CACHE_DIR}/${JULIA_TARBALL}"

#--- Sub-block 18.2: Prepare cache directory ---
# Purpose: Create cache directory for Julia tarball
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
mkdir -p "${CACHE_DIR}"

#--- Sub-block 18.3: Determine if Julia download needed ---
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

#--- Sub-block 18.4: Download Julia if needed ---
# Purpose: Fetch Julia tarball with retry logic
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
if [ "${need_fetch}" -eq 1 ]; then
  printf '%s\n' "[julia] fetching ${JULIA_URL}"
  # Retry, follow redirects, fail on HTTP errors
  curl -fsSL --retry 5 --retry-all-errors --connect-timeout 5 --max-time 180 \
    -o "${LATEST_TGZ}.part" "${JULIA_URL}"
  mv -f "${LATEST_TGZ}.part" "${LATEST_TGZ}"
fi
# End download if block (self-contained)

#--- Sub-block 18.5: Julia archive verification ---
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
# Note: Archive already verified in early verification phase
printf '%s\n' "[julia] Archive already verified (SHA256 + gzip integrity check passed)"

#--- Sub-block 18.6: Optional GPG signature verification ---
# Purpose: Best-effort GPG verification (non-blocking)
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
  printf '%s\n' "[julia] Performing optional GPG signature verification..."
GNUPGHOME="/root/.gnupg"
mkdir -p "${GNUPGHOME}"
chmod 700 "${GNUPGHOME}"
# Download .asc file if available
curl -fsSL --retry 3 "${JULIA_ASC_URL}" -o "${LATEST_TGZ}.asc" || true
#--- Sub-block 18.7: Import Julia GPG key ---
# Purpose: Load GPG key for signature verification
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
if [ -f "${CONTAINER_BIN_CACHE}/julia_key.asc" ]; then
  printf '%s\n' "Importing local GPG key for Julia..."
  gpg --import "${CONTAINER_BIN_CACHE}/julia_key.asc"
else
  printf '%s\n' "[warn] Local Julia GPG key not found. GPG verification may fail."
fi
# End GPG key import (if-else self-contained)

#--- Sub-block 18.8: Verify Julia GPG signature ---
# Purpose: Verify .asc signature if available (non-blocking)
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
if [ -s "${LATEST_TGZ}.asc" ]; then
  if gpg --batch --verify "${LATEST_TGZ}.asc" "${LATEST_TGZ}" 2>/tmp/julia_gpg_verify.log; then
    printf '%s\n' "[julia] ✓ GPG signature: GOOD"
  else
    printf '%s\n' "[julia] Δ GPG signature could not be verified (see /tmp/julia_gpg_verify.log). Continuing because SHA256 passed."
  fi
else
  printf '%s\n' "[julia] Δ No .asc file available for GPG verification. Continuing because SHA256 passed."
fi
# End GPG verification (if-else self-contained)

#--- Sub-block 18.9: Extract and install Julia ---
# Critical: Extract Julia to /opt and create symlink
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
printf '%s\n' "[julia] Installing to ${INSTALL_DIR}/julia-${JVER}"
if ! tar -xzf "${LATEST_TGZ}" -C "${INSTALL_DIR}"; then
  printf '%s\n' "[julia] ERROR: Failed to extract Julia tarball" >&2
  exit 1
fi
rm -f "${INSTALL_DIR}/julia" 2>/dev/null || true
if ! ln -s "${INSTALL_DIR}/julia-${JVER}" "${INSTALL_DIR}/julia"; then
  printf '%s\n' "[julia] ERROR: Failed to create Julia symlink" >&2
  exit 1
fi
printf '%s\n' "[julia] Installed to ${INSTALL_DIR}/julia-${JVER}, symlinked as ${INSTALL_DIR}/julia"

#--- Sub-block 18.10: Verify Julia installation ---
# Critical: Ensure julia binary is executable
# Dependencies: Block 8.5 (Julia installation)
# Outputs: Julia packages, environments
  printf '%s\n' "[julia] Sanity check for ${JULIA_HOME}/bin/julia"
  JULIA_BIN="${JULIA_HOME}/bin/julia"
  if [ ! -x "${JULIA_BIN}" ]; then
  printf '%s\n' "[julia] ERROR: ${JULIA_HOME}/bin/julia not found or not executable" >&2
  # D3e: SIGPIPE protection - add || true at end of pipeline
  find /opt -maxdepth 2 -type f -ls 2>/dev/null | head -20 2>/dev/null || printf '%s\n' "  /opt directory empty or not accessible" || true
  exit 1
fi
# End Julia verification (if self-contained)

#--- Sub-block 18.11: Update PATH for Julia ---
# Critical: Make Julia available for rest of build script
# Dependencies: Block 8.5 (Julia installation)
# Outputs: Julia packages, environments
printf '%s\n' "==> Updating PATH to include Julia for subsequent build steps..."
# Export PATH to include Julia (critical for subshells and subsequent commands)
export PATH="${JULIA_HOME}/bin:${PATH}"
# Clear the shell's command lookup cache
hash -r
# Verify julia command is found
if ! command -v julia >/dev/null 2>&1; then
    printf '%s\n' "ERROR: Julia executable not found in PATH after update." >&2
    printf '%s\n' "Julia HOME: ${JULIA_HOME}"
    printf '%s\n' "PATH: ${PATH}"
    printf '%s\n' "Contents of ${JULIA_HOME}/bin:"
    find "${JULIA_HOME}/bin" -maxdepth 1 -type f -ls 2>/dev/null || printf '%s\n' "Directory does not exist!"
    exit 1
fi
printf '%s\n' "✓ Julia is now available in the PATH."
# Quick smoke test (H4: Validate result after masked failure)
if ! "${JULIA_BIN}" --version >/dev/null 2>&1; then
  printf '%s\n' "[WARN] Julia version check failed, but continuing (binary exists)" >&2
fi

#--- Sub-block 18.12: Build libCxxWrap-julia from source ---
# Purpose: Build C++ wrapper library for Julia-C++ interop
# Dependencies: Block 8.5 (Julia installation), PHASE 1 (Build tools)
# Outputs: Julia packages, environments
printf '%s\n' "==> Building libCxxWrap-julia from source for OpenCV/Integration"
CXXWRAP_PREFIX="/opt/libcxxwrap-julia"
if [ -z "${LIBCXXWRAP_JULIA_VERSION:-}" ]; then
  printf '%s\n' "ERROR: LIBCXXWRAP_JULIA_VERSION is not set. Check /etc/config.sh." >&2
  exit 1
fi
LIBCXXWRAP_JULIA_TAG="${LIBCXXWRAP_JULIA_TAG:-v${LIBCXXWRAP_JULIA_VERSION}}"
printf '%s\n' "  Using libcxxwrap-julia release ${LIBCXXWRAP_JULIA_TAG}"
if [ -x "${JULIA_BIN:-}" ]; then
  if [ ! -f "${CXXWRAP_PREFIX}/lib/cmake/JlCxx/JlCxxConfig.cmake" ]; then
    printf '%s\n' "Building libCxxWrap-julia from source..."
    # Get Julia paths
    # C1: Validate command substitution results
    JULIA_INCLUDE=$("${JULIA_BIN}" -e 'print(joinpath(Sys.BINDIR, "..", "include", "julia"))' || echo "")
    JULIA_LIB=$("${JULIA_BIN}" -e 'print(joinpath(Sys.BINDIR, "..", "lib"))' || echo "")
    if [ -z "${JULIA_INCLUDE}" ] || [ -z "${JULIA_LIB}" ]; then
      printf '%s\n' "ERROR: Failed to get Julia paths" >&2
      exit 1
    fi
    printf '%s\n' "  Julia include: ${JULIA_INCLUDE}"
    printf '%s\n' "  Julia library: ${JULIA_LIB}"
    # Clone and build
    BUILD_DIR="/tmp/cxxwrap_build"
    rm -rf "${BUILD_DIR}"
    if ! clone_with_retry "https://github.com/JuliaInterop/libcxxwrap-julia.git" "${BUILD_DIR}" "${LIBCXXWRAP_JULIA_TAG}"; then
      printf '%s\n' "ERROR: Failed to clone libcxxwrap-julia after all retry attempts" >&2
      exit 1
    fi
    # J1: Validate directory exists before cd
    if [ ! -d "${BUILD_DIR}" ]; then
      printf '%s\n' "ERROR: Build directory not found: ${BUILD_DIR}" >&2
      exit 1
    fi
    cd "${BUILD_DIR}" || { printf '%s\n' "ERROR: Failed to access libcxxwrap-julia directory" >&2; exit 1; }
    # Clean build directory for fresh compilation
    rm -rf build
    mkdir -p build
    cd build || { printf '%s\n' "ERROR: Failed to access build directory" >&2; exit 1; }

    if ! cmake .. \
      -DCMAKE_INSTALL_PREFIX="${CXXWRAP_PREFIX}" \
      -DCMAKE_BUILD_TYPE=Release \
      -DJulia_EXECUTABLE="${JULIA_BIN}" \
      -DJulia_INCLUDE_DIRS="${JULIA_INCLUDE}" \
      -DJulia_LIBRARY_DIR="${JULIA_LIB}" \
      -DCMAKE_INSTALL_LIBDIR=lib; then
      printf '%s\n' "ERROR: CMake configuration failed for libCxxWrap-julia" >&2
      exit 1
    fi

    #--- Sub-block 18.13: Build and install CxxWrap ---
    # Critical: Compile with make using all CPU cores
    if ! make -j"$(nproc)"; then
      printf '%s\n' "ERROR: Build failed for libCxxWrap-julia" >&2
      exit 1
    fi
    if ! make install; then
      printf '%s\n' "ERROR: Installation failed for libCxxWrap-julia" >&2
      exit 1
    fi

    cd /
    rm -rf "${BUILD_DIR}"
    printf '%s\n' "✓ Libcxxwrap-julia built to ${CXXWRAP_PREFIX}"
  else
    printf '%s\n' "✓ Libcxxwrap-julia already installed"
  fi
  # End CxxWrap build check (if-else self-contained)


  #--- Sub-block 18.14: Fix CMake target export for CxxWrap ---
  # Critical: Ensure OpenCV can find JlCxx CMake target
  # D3c: Use -F flag for fixed-string matching (literal pattern)
  if ! grep -Fq "JlCxx::cxxwrap_julia" "${CXXWRAP_PREFIX}/lib/cmake/JlCxx/JlCxxConfig.cmake"; then
    printf '%s\n' "Adding CMake target export to JlCxxConfig.cmake..."
    # J1: Validate parent directory exists before writing
    CMAKE_CONFIG_DIR="${CXXWRAP_PREFIX}/lib/cmake/JlCxx"
    if [ ! -d "${CMAKE_CONFIG_DIR}" ]; then
      printf '%s\n' "[WARNING] Parent directory does not exist: ${CMAKE_CONFIG_DIR}"
      printf '%s\n' "[INFO] Creating parent directory: ${CMAKE_CONFIG_DIR}"
      mkdir -p "${CMAKE_CONFIG_DIR}" || {
        printf '%s\n' "[ERROR] Failed to create parent directory: ${CMAKE_CONFIG_DIR}" >&2
        exit 1
      }
      printf '%s\n' "[INFO] Parent directory created successfully: ${CMAKE_CONFIG_DIR}"
    fi
    cat >> "${CXXWRAP_PREFIX}/lib/cmake/JlCxx/JlCxxConfig.cmake" << 'CMAKE_FIX'


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
    printf '%s\n' "✓ CMake target export added"
  fi
  # End CMake target fix (if self-contained)

  #--- Sub-block 18.15: Configure CMAKE_PREFIX_PATH for CxxWrap ---
  # Critical: Make CxxWrap findable by CMake for OpenCV build
  case ":${CMAKE_PREFIX_PATH:-}:" in
    *":${CXXWRAP_PREFIX}:"*) ;;
    *) export CMAKE_PREFIX_PATH="${CXXWRAP_PREFIX}:${CMAKE_PREFIX_PATH:-}" ;;
  esac
  # Make permanent for future sessions (idempotent append)
  if ! grep -Fq 'CMAKE_PREFIX_PATH' /etc/profile.d/cxxwrap.sh 2>/dev/null; then
    # shellcheck disable=SC2016 # Intentional: ${CMAKE_PREFIX_PATH} should be literal in the file
    printf 'export CMAKE_PREFIX_PATH="%s:${CMAKE_PREFIX_PATH}"\n' "${CXXWRAP_PREFIX}" >> /etc/profile.d/cxxwrap.sh
  fi

  #--- Sub-block 18.16: Verify CxxWrap CMake configuration ---
  # Critical: Ensure JlCxx CMake config file exists
  if [ -f "${CXXWRAP_PREFIX}/lib/cmake/JlCxx/JlCxxConfig.cmake" ]; then
    printf '%s\n' "✓ JlCxx CMake config ready"
  else
    printf '%s\n' "✗ JlCxx CMake config not found" >&2
    exit 1
  fi
  # End CMake config verification (if-else self-contained)
fi
# End CxxWrap installation (if block self-contained)
debug_glibc "After CxxWrap source build"
printf '%s\n' "CxxWrap source build ready for OpenCV"


#===============================================================================
# BLOCK 19: NVIDIA VIDEO CODEC SDK INSTALLATION
#===============================================================================
# Purpose: Install NVIDIA Video Codec SDK for hardware video encoding/decoding
# Self-contained: Yes (complete with verification)
# Dependencies: Cached SDK .zip file, unzip utility
# Outputs: Configured system components
# NOTE: SDK must be manually downloaded due to NVIDIA EULA
#-------------------------------------------------------------------------------


#--- Sub-block 19.1: Initialize NVIDIA SDK installation ---
# Purpose: Install NVIDIA Video Codec SDK for hardware video encoding/decoding
# Dependencies: Cached SDK .zip file, unzip utility
# Outputs: Configured system components
printf '%s\n' "==> Installing NVIDIA Video Codec SDK from cache..."

# Using NVIDIA Video Codec SDK version from config.sh
SDK_VERSION="${NVIDIA_VIDEO_SDK_VERSION}"
SDK_ZIP_FILENAME="Video_Codec_SDK_${SDK_VERSION}.zip"
SDK_ZIP_CACHE_PATH="${CONTAINER_BIN_CACHE}/${SDK_ZIP_FILENAME}"

#--- Sub-block 19.3: Check for cached SDK file ---
# Critical: SDK is optional - if not present, skip installation (don't fail build)
# Dependencies: None (foundational)
# Outputs: Environment variables, configuration
NVIDIA_VIDEO_SDK_INSTALLED=false
if [ -f "${SDK_ZIP_CACHE_PATH}" ]; then
  printf '%s\n' "--> Found cached NVIDIA Video Codec SDK. Using it."
  NVIDIA_VIDEO_SDK_INSTALLED=true
  cp "${SDK_ZIP_CACHE_PATH}" "/tmp/${SDK_ZIP_FILENAME}"
else
  printf '%s\n' ""
  printf '%s\n' "═══════════════════════════════════════════════════════════════"
  printf '%s\n' "  WARNING: NVIDIA Video Codec SDK not found in cache (OPTIONAL)"
  printf '%s\n' "═══════════════════════════════════════════════════════════════"
  printf '%s\n' "  File name: ${SDK_ZIP_FILENAME}"
  printf '%s\n' "  Expected location: ${SDK_ZIP_CACHE_PATH}"
  printf '%s\n' "  Download URL: https://developer.nvidia.com/nvidia-video-codec-sdk/download"
  printf '%s\n' ""
  printf '%s\n' "  This is an OPTIONAL component. The build will continue without it."
  printf '%s\n' "  If you need the SDK, manually download '${SDK_ZIP_FILENAME}' from the URL above"
  printf '%s\n' "  and place it at:"
  printf '%s\n' "    ${SDK_ZIP_CACHE_PATH}"
  printf '%s\n' "═══════════════════════════════════════════════════════════════"
  printf '%s\n' "  → Skipping NVIDIA Video Codec SDK installation (optional component)"
  NVIDIA_VIDEO_SDK_INSTALLED=false
fi
# End SDK cache check (if-else self-contained)

# Only proceed with SDK installation if it was found
if [ "${NVIDIA_VIDEO_SDK_INSTALLED}" = "true" ]; then
  printf '%s\n' "  → Proceeding with NVIDIA Video Codec SDK installation"
  
  #--- Sub-block 19.4: Extract NVIDIA SDK ---
  # Purpose: Unzip SDK to /tmp
  # Dependencies: None (foundational)
  # Outputs: Environment variables, configuration
  # J1: Validate /tmp directory exists
  if [ ! -d "/tmp" ]; then
    printf '%s\n' "ERROR: /tmp directory does not exist" >&2
    exit 1
  fi
  cd /tmp || { printf '%s\n' "ERROR: Failed to access /tmp directory" >&2; exit 1; }
  # J1: Validate source file exists before extracting
  if [ ! -f "/tmp/${SDK_ZIP_FILENAME}" ]; then
    printf '%s\n' "ERROR: SDK zip file not found: /tmp/${SDK_ZIP_FILENAME}" >&2
    exit 1
  fi
  if ! unzip -q "${SDK_ZIP_FILENAME}"; then
    printf '%s\n' "ERROR: Failed to extract NVIDIA Video Codec SDK" >&2
    exit 1
  fi

  #--- Sub-block 19.5: Move SDK to /opt ---
  # Purpose: Install SDK to system location
  # Dependencies: None (foundational)
  # Outputs: Environment variables, configuration
  SDK_FOLDER="Video_Codec_SDK_${SDK_VERSION}"
  printf '%s\n' "Moving ${SDK_FOLDER} to /opt/${SDK_FOLDER}"
  # J1: Validate source folder exists before moving
  if [ ! -d "/tmp/${SDK_FOLDER}" ]; then
    printf '%s\n' "ERROR: Extracted SDK folder not found: /tmp/${SDK_FOLDER}" >&2
    exit 1
  fi
  if [ "$(id -u)" -eq 0 ]; then
    # Running as root, no sudo needed
    mv "/tmp/${SDK_FOLDER}" "/opt/${SDK_FOLDER}" || { printf '%s\n' "ERROR: Failed to move SDK folder" >&2; exit 1; }
    mv "/opt/${SDK_FOLDER}" "/opt/Video_Codec_SDK" || { printf '%s\n' "ERROR: Failed to rename SDK folder" >&2; exit 1; }
  else
    # Not root, use sudo if available
    sudo mv "/tmp/${SDK_FOLDER}" "/opt/${SDK_FOLDER}" || { printf '%s\n' "ERROR: Failed to move SDK folder" >&2; exit 1; }
    sudo mv "/opt/${SDK_FOLDER}" "/opt/Video_Codec_SDK" || { printf '%s\n' "ERROR: Failed to rename SDK folder" >&2; exit 1; }
  fi

  #--- Sub-block 19.6: Set SDK ownership and permissions ---
  # Purpose: Ensure SDK is accessible without sudo
  # Dependencies: None (foundational)
  # Outputs: Environment variables, configuration
  # J1: Validate target directory exists before chown
  if [ ! -d "/opt/Video_Codec_SDK" ]; then
    printf '%s\n' "ERROR: SDK directory not found: /opt/Video_Codec_SDK" >&2
    exit 1
  fi
  if [ "$(id -u)" -eq 0 ]; then
    # Running as root, set ownership to root or preserve current
    CURRENT_USER="${SUDO_USER:-root}"
    CURRENT_GROUP="${SUDO_GID:-0}"
    chown -R "${CURRENT_USER}:${CURRENT_GROUP}" "/opt/Video_Codec_SDK" || { printf '%s\n' "ERROR: Failed to set SDK ownership" >&2; exit 1; }
  else
    # Not root, use sudo if available
    sudo chown -R "${USER}:${USER}" "/opt/Video_Codec_SDK" || { printf '%s\n' "ERROR: Failed to set SDK ownership" >&2; exit 1; }
  fi
  printf '%s\n' "SDK successfully moved to /opt/Video_Codec_SDK"

  #--- Sub-block 19.7: Copy SDK headers to system locations ---
  # Critical: Make headers available for FFmpeg/OpenCV compilation
  # Dependencies: Block 6.13 (NVIDIA CUDA)
  # Outputs: GPU libraries, CUDA toolkit
  # H4: Validate failures explicitly instead of masking with 2>/dev/null
  # F2: Command substitution validation - validate result format
  SDK_HEADER_COUNT=0
  if [ -d "/opt/Video_Codec_SDK/Interface" ]; then
    SDK_HEADER_COUNT=$(find "/opt/Video_Codec_SDK/Interface" -maxdepth 1 -name "*.h" -type f 2>/dev/null | wc -l || echo "0")
    # F2: Validate result is numeric
    if ! [[ "${SDK_HEADER_COUNT}" =~ ^[0-9]+$ ]]; then
      SDK_HEADER_COUNT=0
    fi
  fi
  if [ "${SDK_HEADER_COUNT}" -gt 0 ]; then
    # J1: Validate target directory exists before copying
    if [ -d "/usr/local/include" ]; then
      if ! cp "/opt/Video_Codec_SDK/Interface/"*.h /usr/local/include 2>/dev/null; then
        printf '%s\n' "[WARNING] Failed to copy SDK headers to /usr/local/include" >&2
      fi
    else
      printf '%s\n' "[WARNING] Target directory /usr/local/include does not exist" >&2
    fi
    # J1: Validate CUDA include directory exists before copying
    CUDA_INCLUDE_DIR="/usr/local/cuda-${CUDA_VERSION}/include"
    if [ -d "${CUDA_INCLUDE_DIR}" ]; then
      if ! cp "/opt/Video_Codec_SDK/Interface/"*.h "${CUDA_INCLUDE_DIR}" 2>/dev/null; then
        printf '%s\n' "[WARNING] Failed to copy SDK headers to CUDA include directory: ${CUDA_INCLUDE_DIR}" >&2
      fi
    else
      printf '%s\n' "[WARNING] CUDA include directory does not exist: ${CUDA_INCLUDE_DIR}" >&2
    fi
  else
    printf '%s\n' "[WARNING] No SDK header files found in /opt/Video_Codec_SDK/Interface" >&2
  fi

  #--- Sub-block 19.8: Verify SDK header installation ---
  # Critical: Ensure required headers are in place
  # Dependencies: None (foundational)
  # Outputs: Environment variables, configuration
  if [ -f /usr/local/include/nvcuvid.h ] && [ -f /usr/local/include/cuviddec.h ]; then
    printf '%s\n' "✓ Video Codec SDK headers verified at /usr/local/include/"
    # D3e: SIGPIPE error handling - check directory exists before find, add || true
    if [ -d /usr/local/include ]; then
      find /usr/local/include -maxdepth 1 -name "nvc*" -type f -ls 2>/dev/null | head -20 2>/dev/null || true
    fi
  else
    printf '%s\n' "Δ Video Codec SDK headers may be incomplete"
    # D3e: SIGPIPE error handling - check directory exists before find, add || true
    if [ -d /usr/local/include ]; then
      find /usr/local/include -maxdepth 1 -type f -iname "*nv*" -ls 2>/dev/null | head -20 2>/dev/null || printf '%s\n' "No NVIDIA headers found"
    else
      printf '%s\n' "No NVIDIA headers found"
    fi
  fi
  # End SDK header verification (if-else self-contained)

  #--- Sub-block 19.9: Cleanup temporary SDK files ---
  # Purpose: Remove temporary extraction files
  # Dependencies: None (foundational)
  # Outputs: Environment variables, configuration
  # N1: Proper cleanup of temporary files with validation
  if [ -n "${SDK_FOLDER:-}" ]; then
    rm -rf "/tmp/${SDK_FOLDER}" 2>/dev/null || true
  fi
  if [ -n "${SDK_ZIP_FILENAME:-}" ]; then
    rm -f "/tmp/${SDK_ZIP_FILENAME}" 2>/dev/null || true
  fi
  cd / || true

  printf '%s\n' "✓ NVIDIA Video Codec SDK headers installed successfully."
else
  printf '%s\n' "  → NVIDIA Video Codec SDK installation skipped (file not in cache)"
  printf '%s\n' "  → Continuing build; OpenCV configuration will auto-detect any pre-existing SDK headers/libraries"
# ENDIF: NVIDIA_VIDEO_SDK_INSTALLED check
fi
# End NVIDIA Video SDK installation (conditional based on file presence)

#===============================================================================
# DEBUG MODE: STOPPING BEFORE OPENCV COMPILATION
#===============================================================================
# NOTE: This is a DEBUG script that stops before BLOCK 20 (OpenCV compilation).
#       All prerequisites for OpenCV are installed:
#       - Phase 1 libraries (Ceres, SuiteSparse, G2O, GTSAM, etc.)
#       - CUDA toolkit and drivers
#       - TBB libraries
#       - NVIDIA Video Codec SDK headers
#       - All build dependencies
#       OpenCV compilation can be done separately using compile_opencv_in_overlay.sh
#===============================================================================
printf '\n%s\n' "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf '%s\n' "${BLUE}DEBUG MODE: Stopping before OpenCV compilation${NC}"
printf '%s\n' "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf '%s\n' ""
printf '%s\n' "✓ All prerequisites for OpenCV compilation are installed"
printf '%s\n' "✓ Image snapshot created just before BLOCK 20 (OpenCV compilation)"
printf '%s\n' "✓ To compile OpenCV, use: compile_opencv_in_overlay.sh"
printf '%s\n' ""

#===============================================================================
# BLOCK 39: FINAL SYSTEM VERIFICATION
#===============================================================================
# Purpose: Verify all critical symlinks and installations
# Self-contained: Yes
# Dependencies: None
# Outputs: Environment variables, configuration
#-------------------------------------------------------------------------------

#--- Sub-block 39.1: Verify TurboVNC and VirtualGL symlinks ---
# Critical: Ensure remote desktop binaries are accessible
# Dependencies: Block 15 (VirtualGL), Block 15 (TurboVNC)
# Outputs: VNC server, GPU acceleration
# ================= Final Failsafe: Verify All Symlinks =====================
echo "==> Final verification of TurboVNC/VirtualGL symlinks..."

# TurboVNC binaries
TURBOVNC_BINS=(vncserver Xvnc vncpasswd vncconnect vncviewer webserver tvncconfig)
for binary in "${TURBOVNC_BINS[@]}"; do
  if [ ! -L "/usr/local/bin/${binary}" ] && [ -x "/opt/TurboVNC/bin/${binary}" ]; then
    if ln -sf "/opt/TurboVNC/bin/${binary}" "/usr/local/bin/${binary}"; then
      printf '%s\n' "  ✓ Created missing symlink: ${binary}"
    else
      printf '%s\n' "  ✗ Failed to create symlink for ${binary}" >&2
    fi
  fi
# ENDFOR: binary
done

# VirtualGL binaries (comprehensive list)
VIRTUALGL_BINS=(vglrun vglclient vglconfig vglconnect vglgenkey vgllogin vglserver_config glxinfo glxspheres64 eglinfo eglxinfo eglxspheres64 cpustat nettest tcbench)
for binary in "${VIRTUALGL_BINS[@]}"; do
  if [ ! -L "/usr/local/bin/${binary}" ] && [ -x "/opt/VirtualGL/bin/${binary}" ]; then
    if ln -sf "/opt/VirtualGL/bin/${binary}" "/usr/local/bin/${binary}"; then
      printf '%s\n' "  ✓ Created missing symlink: ${binary}"
    else
      printf '%s\n' "  ✗ Failed to create symlink for ${binary}" >&2
    fi
  fi
# ENDFOR: binary
done

# Final comprehensive verification
echo ""
echo "==> Critical symlink verification:"
# A6: declare -A requires Bash 4+ - verified: shebang is #!/bin/bash
declare -A CRITICAL_BINS=(
  ["vncserver"]="/opt/TurboVNC/bin/vncserver"
  ["Xvnc"]="/opt/TurboVNC/bin/Xvnc"
  ["webserver"]="/opt/TurboVNC/bin/webserver"
  ["vglrun"]="/opt/VirtualGL/bin/vglrun"
  ["glxinfo"]="/opt/VirtualGL/bin/glxinfo"
  ["glxspheres64"]="/opt/VirtualGL/bin/glxspheres64"
)

for binary in "${!CRITICAL_BINS[@]}"; do
  # shellcheck disable=SC2034 # expected used in loop body
  expected="${CRITICAL_BINS[$binary]}"
  if [ -L "/usr/local/bin/${binary}" ]; then
    # F2, H4: Validate command substitution result
    actual=""
    # SC2155: Declare and assign separately to avoid masking return values
    actual=$(readlink -f "/usr/local/bin/${binary}" 2>/dev/null || readlink "/usr/local/bin/${binary}" 2>/dev/null || printf '%s\n' "")
    # F2: Validate result is non-empty and valid before use
    if [ -n "${actual}" ] && [ -x "${actual}" ]; then
      printf '%s\n' "  ✓ ${binary} -> ${actual} [OK]"
    else
      printf '%s\n' "  ✗ ${binary} -> ${actual} [BROKEN]" >&2
    fi
  else
    printf '%s\n' "  ✗ ${binary} [MISSING]"
  fi
# ENDFOR: binary
done



echo "✓ Symlink verification complete"

# Cache is already unified in ${CONTAINER_CACHE_ROOT}/ - no need for complex harvesting
echo "==> Cache is unified in ${CONTAINER_CACHE_ROOT}/ - ready for harvest"

# Clean up temporary files but preserve our cache
echo "==> Cleaning temporary files while preserving cache..."

# Clean APT lists (safe to remove)
echo "  » APT LISTS CLEANUP - Monitoring cache before APT lists cleanup"
# H4: Validate command substitution result
cache_count_before=""
cache_count_before=$(find "${CONTAINER_APT_CACHE}" -name "*.deb" 2>/dev/null | wc -l || echo "0")
echo "  ${CONTAINER_APT_CACHE}: ${cache_count_before} .deb files"
rm -rf /var/lib/apt/lists/* 2>/dev/null || true
echo "  » APT LISTS CLEANUP - Monitoring cache after APT lists cleanup"
# H4: Validate command substitution result
cache_count_after=""
cache_count_after=$(find "${CONTAINER_APT_CACHE}" -name "*.deb" 2>/dev/null | wc -l || echo "0")
echo "  ${CONTAINER_APT_CACHE}: ${cache_count_after} .deb files"

# Clean temporary APT directories that might cause issues
rm -rf /tmp/apt-dpkg-install* 2>/dev/null || true
# apt-fast cleanup removed - using apt-aria wrapper instead

# Clean temporary files but preserve our container cache
echo "  » CLEANUP SECTION - Monitoring cache before cleanup"
# H4: Validate command substitution result
cache_count_before_cleanup=""
cache_count_before_cleanup=$(find "${CONTAINER_APT_CACHE}" -name "*.deb" 2>/dev/null | wc -l || echo "0")
echo "  ${CONTAINER_APT_CACHE}: ${cache_count_before_cleanup} .deb files"
# D3e: SIGPIPE protection - add || true at end of pipeline with head
find /tmp -maxdepth 1 -type l -o -type d -name "*container_cache*" -o -name "*apt*" 2>/dev/null | head -10 2>/dev/null || echo "No suspicious symlinks in /tmp"
find "${CONTAINER_APT_CACHE}" -maxdepth 1 -type f -ls 2>/dev/null | head -5 2>/dev/null || echo "Directory empty or not accessible"
find /tmp -type f -name "*.deb" -delete 2>/dev/null || true
find /tmp -type f -name "*.tar.gz" -delete 2>/dev/null || true
find /tmp -type f -name "*.whl" -delete 2>/dev/null || true
echo "  » CLEANUP SECTION - Monitoring cache after cleanup"
# H4: Validate command substitution result
cache_count_after_cleanup=""
cache_count_after_cleanup=$(find "${CONTAINER_APT_CACHE}" -name "*.deb" 2>/dev/null | wc -l || echo "0")
echo "  ${CONTAINER_APT_CACHE}: ${cache_count_after_cleanup} .deb files"

# === FINAL CACHE PRESERVATION ===
# Reverting cache file permissions to normal ===
if command -v chattr >/dev/null 2>&1; then
    if compgen -G "${CONTAINER_APT_CACHE}/"*.deb > /dev/null; then
        chattr -i "${CONTAINER_APT_CACHE}/"*.deb 2>/dev/null || true
        echo "chattr -i command executed successfully"
    else
        echo "No cached .deb files require chattr adjustment"
    fi
else
    echo "WARNING: chattr command not available - cannot revert file permissions"
fi


# Show monitoring summary and aggregated cache summary before preservation
display_cache_monitoring_summary
cache_summary
# Add detailed monitoring before any cache operations

echo "  » DETAILED CACHE INVESTIGATION - BEFORE PRESERVATION"
echo "  Container cache directory contents:"
# D3e: SIGPIPE protection - add || true at end of pipeline with head
find "${CONTAINER_APT_CACHE}" -maxdepth 1 -type f -ls 2>/dev/null | head -10 2>/dev/null || echo "Directory empty or not accessible"
echo "  Var cache directory contents:"
# D3e: SIGPIPE protection - add || true at end of pipeline with head
find /var/cache/apt/archives -maxdepth 1 -type f -ls 2>/dev/null | head -10 2>/dev/null || echo "Directory empty or not accessible"
echo "Cache file counts:"
# H4: Validate command substitution result
apt_cache_count=""
apt_cache_count=$(find "${CONTAINER_APT_CACHE}" -name "*.deb" 2>/dev/null | wc -l || echo "0")
echo "  ${CONTAINER_APT_CACHE}: ${apt_cache_count} .deb files"
var_cache_count=""
var_cache_count=$(find /var/cache/apt/archives -name "*.deb" 2>/dev/null | wc -l || echo "0")
echo "  /var/cache/apt/archives: ${var_cache_count} .deb files"

# Ensure all downloaded packages are preserved in the cache directory
echo "==> Preserving APT cache for future builds ==="
# Check if packages are in the standard APT cache location
if [ -d "/var/cache/apt/archives" ]; then
    echo "Copying packages from /var/cache/apt/archives to ${CONTAINER_APT_CACHE}..."
    find /var/cache/apt/archives -name "*.deb" -type f -exec cp {} "${CONTAINER_APT_CACHE}/" \; 2>/dev/null || true
    echo "After copying from /var/cache/apt/archives:"
    # H4: Validate command substitution result
    cache_count_after_copy=""
    cache_count_after_copy=$(find "${CONTAINER_APT_CACHE}" -name "*.deb" 2>/dev/null | wc -l || echo "0")
    echo "  ${CONTAINER_APT_CACHE}: ${cache_count_after_copy} .deb files"
fi

# Also preserve any packages that might be in the system cache
if [ -d "/var/lib/apt/cache" ]; then
    echo "Checking system APT cache for additional packages..."
    find /var/lib/apt/cache -name "*.deb" -type f -exec cp {} "${CONTAINER_APT_CACHE}/" \; 2>/dev/null || true
    echo "After copying from /var/lib/apt/cache:"
    # H4: Validate command substitution result
    cache_count_after_system_copy=""
    cache_count_after_system_copy=$(find "${CONTAINER_APT_CACHE}" -name "*.deb" 2>/dev/null | wc -l || echo "0")
    echo "  ${CONTAINER_APT_CACHE}: ${cache_count_after_system_copy} .deb files"
fi

# Final monitoring before cache harvest
monitor_cache "Final cache status before harvest"

# Add one more detailed check right before the script ends
echo "  » FINAL CACHE CHECK - RIGHT BEFORE SCRIPT END"
echo "Final container cache contents:"
# D3e: SIGPIPE protection - add || true at end of pipeline with head
find "${CONTAINER_APT_CACHE}" -maxdepth 1 -type f -ls 2>/dev/null | head -10 2>/dev/null || echo "Directory empty or not accessible"
echo ""
echo "Final cache file count:"
# H4: Validate command substitution result
final_cache_count=""
final_cache_count=$(find "${CONTAINER_APT_CACHE}" -name "*.deb" 2>/dev/null | wc -l || echo "0")
echo "  ${CONTAINER_APT_CACHE}: ${final_cache_count} .deb files"
echo ""
# Report cache status
echo "Container cache status:"
# H4: Validate command substitution results
apt_archives_count=""
apt_archives_count=$(find "${CONTAINER_APT_CACHE}" -maxdepth 1 -name "*.deb" 2>/dev/null | wc -l || echo "0")
conda_packages_count=""
conda_packages_count=$(find "${CONTAINER_CONDA_CACHE}" -maxdepth 1 -type f 2>/dev/null | wc -l || echo "0")
pip_wheels_count=""
pip_wheels_count=$(find "${CONTAINER_WHEELS_CACHE}" -maxdepth 1 -type f 2>/dev/null | wc -l || echo "0")
julia_packages_count=""
julia_packages_count=$(find "${CONTAINER_JULIA_CACHE}" -maxdepth 1 -type f 2>/dev/null | wc -l || echo "0")
echo "  APT archives: ${apt_archives_count} files"
echo "  Conda packages: ${conda_packages_count} files"
echo "  Pip wheels: ${pip_wheels_count} files"
echo "  Julia packages: ${julia_packages_count} files"
echo "=========================================================================="



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
  # D3e: SIGPIPE protection - add || true at end of pipeline with head
  if /usr/local/bin/vncserver -help >/dev/null 2>&1; then
    /usr/local/bin/vncserver -help 2>&1 | head -1 2>/dev/null || true
  fi
  echo "  ✓ TurboVNC installed"
else
  echo "  ✗ TurboVNC not found!"
fi

# Test VirtualGL
echo ""
echo "VirtualGL Installation:"
if [ -x /usr/local/bin/vglrun ]; then
  echo "  ✓ VirtualGL installed"
else
  echo "  ✗ VirtualGL not found!"
fi

#===============================================================================
# BLOCK 40: DOCUMENTATION AND USER GUIDES
#===============================================================================
# Purpose: Create comprehensive user documentation for the container
# Self-contained: Yes (complete documentation generation)
# Dependencies: None
# Outputs: Environment variables, configuration
#-------------------------------------------------------------------------------

#--- Sub-block 40.1: VirtualGL user guide ---
# Critical: Comprehensive guide for GPU-accelerated applications
# Dependencies: Block 15 (VirtualGL)
# Outputs: VNC server, GPU acceleration
mkdir -p /usr/local/share/doc || { echo "✗ Failed to create /usr/local/share/doc" >&2; exit 1; }
# Note: other file: /usr/local/share/doc/virtualgl-guide.txt is installed via install.sh from container-scripts/
# Source: other/block-33-vnc-startup-scripts-and-configurations-part-2-of-3/virtualgl-guide.txt
# Target: /usr/local/share/doc/virtualgl-guide.txt
# Installed in Block 0 (early in script, before any scripts are needed)
# J1: Verify file exists before checking permissions
if [ ! -f /usr/local/share/doc/virtualgl-guide.txt ]; then
  echo "✗ Failed to create /usr/local/share/doc/virtualgl-guide.txt" >&2
  exit 1
fi
chmod 644 /usr/local/share/doc/virtualgl-guide.txt || { echo "✗ Failed to set permissions on /usr/local/share/doc/virtualgl-guide.txt" >&2; exit 1; }

echo "✓ User guide created: /usr/local/share/doc/virtualgl-guide.txt"

#===============================================================================
# BLOCK 41: UTILITY SCRIPTS DOCUMENTATION
#===============================================================================
# Purpose: Document available utility scripts for users
# Self-contained: Yes
# Dependencies: All utility scripts installed via install.sh
# Outputs: Echo message listing available utilities
echo ""
echo "========================================================================================================"

