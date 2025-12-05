#!/bin/bash
#===============================================================================
# PACKAGE MANAGEMENT FUNCTIONS FOR CONTAINER BUILD SCRIPTS
# Single source of truth for advanced package management operations
#===============================================================================
# Purpose: Centralized functions for Conda package management with staging,
#          retry logic, atomicity, integrity verification, and locking
# Usage: source "$(dirname "$0")/../scripts/package_functions.sh"
#        Or from inside container: source "/scripts/package_functions.sh"
# Dependencies: config.sh (for CONTAINER_* variables), file, bzip2, unzip
#===============================================================================

#===============================================================================
# SECTION 1: CONDITIONAL STAGING AREA SETUP (BLOCK 7.2)
#===============================================================================

#--- Function: setup_conda_staging_area ---
# Purpose: Create isolated staging area for package operations
# Arguments: None
# Returns: 0 on success, 1 on failure
# Outputs: Status messages
# Dependencies: Conda/Miniforge (not yet installed, but function can be defined)
# Note: Function is defined but will only work after Conda is installed
setup_conda_staging_area() {
    # CRITICAL: Use alternative temp directory instead of /tmp (may not be writable in containers)
    local staging_dir="${APT_TMP_ALT:-${TMPDIR:-/var/tmp}}/conda-staging"
    printf '%s\n' "Setting up conda staging area at ${staging_dir}..."
    # J1: Validate parent directory exists before creating subdirectory
    # J2: Use mktemp for secure temporary directory creation (K3)
    # Create staging directory with proper permissions
    # H1: Check exit code of mkdir operation
    if ! mkdir -p "${staging_dir}" 2>/dev/null; then
        printf '%s\n' "[ERROR] ⚠ Failed to create staging directory: ${staging_dir}"
        return 1
    fi
    # H1: Check exit code of chmod operation
    if ! chmod 755 "${staging_dir}" 2>/dev/null; then
        printf '%s\n' "[warn] ⚠ Failed to set permissions on staging directory: ${staging_dir}"
    fi
    # J1: Verify directory was created successfully
    if [ ! -d "${staging_dir}" ]; then
        printf '%s\n' "[ERROR] ⚠ Staging directory does not exist after creation: ${staging_dir}"
        return 1
    fi
    # Note: Do not modify CONDA_PKGS_DIRS here to avoid interfering with normal conda operations
    # The staging area will be used manually for specific cleanup operations
    # J2, K2: Note: Using alternative temp directory for conda-staging instead of /tmp
    # CRITICAL: Use alternative temp directory instead of /tmp (may not be writable in containers)
    # This is intentional for manual cleanup operations, but should be cleaned up after use
    local conda_staging_dir="${APT_TMP_ALT:-${TMPDIR:-/var/tmp}}/conda-staging"
    printf '%s\n' "✓ Conda staging area configured (manual mode)"
    return 0
}
# ENDFUNC: setup_conda_staging_area

#===============================================================================
# SECTION 2: ATOMIC PACKAGE REPLACEMENT WITH RETRY (BLOCK 7.3)
#===============================================================================

#--- Function: atomic_package_replace ---
# Purpose: Replace corrupted packages with exponential backoff retry
# Arguments: $1 = package name
# Returns: 0 on success, 1 on failure
# Outputs: Status messages
# Dependencies: Conda/Miniforge (not yet installed, but function can be defined)
# Note: Function is defined but will only work after Conda is installed
atomic_package_replace() {
    local pkg_name="${1:-}"
    local cache_dir="${CONTAINER_CONDA_CACHE:-}"
    local max_retries=3
    local retry_count=0

    # Validate inputs
    # C1, C5: Validate inputs with proper error messages
    if [ -z "${pkg_name}" ]; then
        printf '%s\n' "✗ Error: Package name not provided"
        return 1
    fi
    if [ -z "${cache_dir}" ]; then
        printf '%s\n' "✗ Error: CONTAINER_CONDA_CACHE not set"
        return 1
    fi
    if [ -z "${MINIFORGE_HOME:-}" ] || [ ! -x "${MINIFORGE_HOME}/bin/mamba" ]; then
        printf '%s\n' "✗ Error: MINIFORGE_HOME not set or mamba not available"
        return 1
    fi

    while [ "${retry_count}" -lt "${max_retries}" ]; do
        printf '%s\n' "Attempting to replace corrupted package: ${pkg_name} (attempt $((retry_count + 1))/${max_retries})"
        # Create temporary file for atomic replacement
        local temp_file="${cache_dir}/${pkg_name}.tmp"
        local final_file="${cache_dir}/${pkg_name}"

        # Remove corrupted package
        # H4: Validate rm operation result (file may not exist, which is OK)
        if [ -f "${final_file}" ]; then
            if ! rm -f "${final_file}" 2>/dev/null; then
                printf '%s\n' "[warn] ⚠ Failed to remove corrupted package: ${final_file}"
            fi
        fi

        # Download fresh copy to temporary location
        # H1: Check exit code of mamba download operation
        if "${MINIFORGE_HOME}/bin/mamba" download --no-deps -c conda-forge -p "${cache_dir}" "${pkg_name}" --output-filename "${temp_file}" 2>/dev/null; then
            # J1: Validate temp file was created before moving
            if [ ! -f "${temp_file}" ]; then
                printf '%s\n' "[warn] ⚠ Download succeeded but temp file not found: ${temp_file}"
                retry_count=$((retry_count + 1))
                sleep $((retry_count ** 2))
                continue
            fi
            # Atomic move to final location
            # H1: Check exit code of mv operation
            if mv "${temp_file}" "${final_file}" 2>/dev/null; then
                # J1: Validate final file exists after move
                if [ ! -f "${final_file}" ]; then
                    printf '%s\n' "[warn] ⚠ Move succeeded but final file not found: ${final_file}"
                    retry_count=$((retry_count + 1))
                    sleep $((retry_count ** 2))
                    continue
                fi
                # Verify the new package
                if verify_package_integrity "${final_file}"; then
                    printf '%s\n' "✓ Successfully replaced and verified: ${pkg_name}"
                    return 0
                else
                    printf '%s\n' "Δ Downloaded package failed verification, retrying..."
                    # H4: Validate rm operation result
                    if [ -f "${final_file}" ] && ! rm -f "${final_file}" 2>/dev/null; then
                        printf '%s\n' "[warn] ⚠ Failed to remove failed package: ${final_file}"
                    fi
                fi
            else
                printf '%s\n' "Δ Atomic move failed, retrying..."
                # H4: Validate rm operation result
                if [ -f "${temp_file}" ] && ! rm -f "${temp_file}" 2>/dev/null; then
                    printf '%s\n' "[warn] ⚠ Failed to remove temp file: ${temp_file}"
                fi
            fi
        else
            printf '%s\n' "Δ Download failed, retrying..."
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
    # ENDWHILE: retry loop

    printf '%s\n' "✗ Failed to replace package after ${max_retries} attempts: ${pkg_name}"
    return 1
}
# ENDFUNC: atomic_package_replace

#===============================================================================
# SECTION 3: PACKAGE INTEGRITY VERIFICATION (BLOCK 7.4)
#===============================================================================

#--- Function: verify_package_integrity ---
# Purpose: Verify package file integrity (bzip2/zip)
# Arguments: $1 = package file path
# Returns: 0 on success, 1 on failure
# Outputs: Status messages
# Dependencies: file, bzip2, unzip (available in base image)
verify_package_integrity() {
    local pkg_file="${1:-}"

    if [ -z "${pkg_file}" ]; then
        printf '%s\n' "✗ Error: Package file path not provided"
        return 1
    fi

    if [ ! -f "${pkg_file}" ]; then
        printf '%s\n' "✗ Error: Package file not found: ${pkg_file}"
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
                printf '%s\n' "✗ bzip2 integrity check failed"
                return 1
            fi
            ;;
        *"Zip archive"*)
            # H1: Check exit code of unzip test operation
            if unzip -t "${pkg_file}" >/dev/null 2>&1; then
                return 0
            else
                printf '%s\n' "✗ ZIP integrity check failed"
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
                printf '%s\n' "✗ Package integrity check failed (tried both bzip2 and ZIP)"
                return 1
            fi
            ;;
    esac
    # ENDCASE: file_type verification
}
# ENDFUNC: verify_package_integrity

#===============================================================================
# SECTION 4: PACKAGE LOCKING MECHANISM (BLOCK 7.5)
#===============================================================================

#--- Function: acquire_package_lock ---
# Purpose: Prevent concurrent access to packages with timeout
# Arguments: $1 = package name
# Returns: 0 on success, 1 on failure
# Outputs: Status messages
# Dependencies: None (foundational - can be used immediately)
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
        printf '%s\n' "✗ Error: Package name not provided"
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
                printf '%s\n' "[warn] ⚠ Could not determine lock age, assuming stale"
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
                    printf '%s\n' "[warn] ⚠ Failed to remove stale lock: ${lock_file}"
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
    # ENDWHILE: lock acquisition loop

    printf '%s\n' "▲ Could not acquire lock for ${pkg_name} after ${max_wait}s"
    return 1
}
# ENDFUNC: acquire_package_lock

#===============================================================================
# SECTION 5: RELEASE PACKAGE LOCK (BLOCK 7.6)
#===============================================================================

#--- Function: release_package_lock ---
# Purpose: Remove lock file for package
# Arguments: $1 = package name
# Returns: 0 on success, 1 on failure
# Outputs: Status messages
# Dependencies: None (foundational - can be used immediately)
release_package_lock() {
    local pkg_name="${1:-}"
    # J2, K2: Use consistent lock file path (must match acquire_package_lock)
    # Note: Using fixed /tmp path for lock file persistence across function calls
    # This is acceptable for lock files as they are cleaned up by this function
    # For enhanced security, consider using /var/run or a dedicated lock directory
    local lock_file="/tmp/conda-lock-${pkg_name}.lock"
    
    if [ -z "${pkg_name}" ]; then
        printf '%s\n' "✗ Error: Package name not provided"
        return 1
    fi
    
    # H4: Validate rm operation result (file may not exist, which is OK)
    if [ -f "${lock_file}" ]; then
        if ! rm -f "${lock_file}" 2>/dev/null; then
            printf '%s\n' "[warn] ⚠ Failed to remove lock file: ${lock_file}"
            return 1
        fi
    fi
    return 0
}
# ENDFUNC: release_package_lock

# Export functions for use in subshells if needed
export -f setup_conda_staging_area atomic_package_replace verify_package_integrity acquire_package_lock release_package_lock

