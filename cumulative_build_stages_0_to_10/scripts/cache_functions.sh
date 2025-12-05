#!/bin/bash
#===============================================================================
# CACHE MONITORING AND CONFIGURATION FUNCTIONS FOR CONTAINER BUILD SCRIPTS
# Single source of truth for cache monitoring and unified cache configuration
#===============================================================================
# Purpose: Centralized cache monitoring and configuration functions
# Usage: source "$(dirname "$0")/../scripts/cache_functions.sh"
#        Or from inside container: source "/scripts/cache_functions.sh"
# Dependencies: config.sh (for CONTAINER_* variables)
#===============================================================================

#===============================================================================
# SECTION 1: CACHE MONITORING FUNCTIONS (BLOCK 5)
#===============================================================================

#--- Function: display_cache_monitoring_summary ---
# Purpose: Display cache growth table across all stages
# Dependencies: CACHE_MONITOR_DATA file (created in BLOCK 5.1)
# Returns: 0 on success, 1 on failure
# Outputs: Prints formatted cache monitoring table
display_cache_monitoring_summary() {
    printf '%s\n' "=========================================================="
    printf '%s\n' "CACHE MONITORING SUMMARY - ALL STAGES"
    printf '%s\n' "=========================================================="
    printf '%s\n' "Stage                         | Container APT | Var APT | Conda | Wheels | Julia"
    printf '%s\n' "------------------------------|---------------|---------|-------|--------|-------"
    
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
        printf '%s\n' "No cache monitoring data available"
    fi
    # ENDIF: CACHE_MONITOR_DATA file exists and is readable
    
    printf '%s\n' "=========================================================="
    printf '%s\n' ""
    return 0
}
# ENDFUNC: display_cache_monitoring_summary

#--- Function: cache_summary ---
# Purpose: Display detailed cache statistics before image creation
# Dependencies: CONTAINER_* cache variables from config.sh
# Returns: 0 on success
# Outputs: Prints detailed cache statistics
cache_summary() {
    printf '%s\n' "=========================================================="
    printf '%s\n' "FINAL CACHE SUMMARY - BEFORE IMAGE CREATION"
    printf '%s\n' "=========================================================="
    printf '%s\n' "APT Archives:"
    
    # J1: Validate directory exists and is accessible before operations
    # F2: Validate command substitution results
    if [ -d "${CONTAINER_APT_CACHE:-}" ] && [ -x "${CONTAINER_APT_CACHE:-}" ]; then
        local deb_count
        deb_count=$(find "${CONTAINER_APT_CACHE}" -maxdepth 1 -name "*.deb" -type f 2>/dev/null | wc -l || echo "0")
        # Validate result is numeric
        if ! [[ "${deb_count:-0}" =~ ^[0-9]+$ ]]; then
            deb_count="0"
        fi
        printf '%s\n' " ${CONTAINER_APT_CACHE}: ${deb_count} .deb files"
    else
        printf '%s\n' " ${CONTAINER_APT_CACHE:-/unknown}: 0 .deb files (directory not found)"
    fi
    # ENDIF: container APT cache exists and accessible
    
    if [ -d /var/cache/apt/archives ] && [ -x /var/cache/apt/archives ]; then
        local deb_count
        deb_count=$(find /var/cache/apt/archives -maxdepth 1 -name "*.deb" -type f 2>/dev/null | wc -l || echo "0")
        # Validate result is numeric
        if ! [[ "${deb_count:-0}" =~ ^[0-9]+$ ]]; then
            deb_count="0"
        fi
        printf '%s\n' " /var/cache/apt/archives: ${deb_count} .deb files"
    else
        printf '%s\n' " /var/cache/apt/archives: 0 .deb files (directory not found)"
    fi
    # ENDIF: host APT archives directory exists
    
    printf '%s\n' "---"
    printf '%s\n' "Other Caches:"
    
    # J1: Validate directory exists and is accessible before operations
    # F2: Validate command substitution results
    if [ -d "${CONTAINER_CONDA_CACHE:-}" ] && [ -x "${CONTAINER_CONDA_CACHE:-}" ]; then
        local file_count
        file_count=$(find "${CONTAINER_CONDA_CACHE}" -maxdepth 1 -type f 2>/dev/null | wc -l || echo "0")
        # Validate result is numeric
        if ! [[ "${file_count:-0}" =~ ^[0-9]+$ ]]; then
            file_count="0"
        fi
        printf '%s\n' " ${CONTAINER_CONDA_CACHE}: ${file_count} files"
    else
        printf '%s\n' " ${CONTAINER_CONDA_CACHE:-/unknown}: 0 files (directory not found)"
    fi
    # ENDIF: container CONDA cache exists and accessible
    
    if [ -d "${CONTAINER_WHEELS_CACHE:-}" ] && [ -x "${CONTAINER_WHEELS_CACHE:-}" ]; then
        local file_count
        file_count=$(find "${CONTAINER_WHEELS_CACHE}" -maxdepth 1 -type f 2>/dev/null | wc -l || echo "0")
        # Validate result is numeric
        if ! [[ "${file_count:-0}" =~ ^[0-9]+$ ]]; then
            file_count="0"
        fi
        printf '%s\n' " ${CONTAINER_WHEELS_CACHE}: ${file_count} files"
    else
        printf '%s\n' " ${CONTAINER_WHEELS_CACHE:-/unknown}: 0 files (directory not found)"
    fi
    # ENDIF: container WHEELS cache exists and accessible
    
    if [ -d "${CONTAINER_JULIA_CACHE:-}" ] && [ -x "${CONTAINER_JULIA_CACHE:-}" ]; then
        local file_count
        file_count=$(find "${CONTAINER_JULIA_CACHE}" -maxdepth 1 -type f 2>/dev/null | wc -l || echo "0")
        # Validate result is numeric
        if ! [[ "${file_count:-0}" =~ ^[0-9]+$ ]]; then
            file_count="0"
        fi
        printf '%s\n' " ${CONTAINER_JULIA_CACHE}: ${file_count} files"
    else
        printf '%s\n' " ${CONTAINER_JULIA_CACHE:-/unknown}: 0 files (directory not found)"
    fi
    # ENDIF: container JULIA cache exists and accessible
    
    printf '%s\n' "---"
    printf '%s\n' "Cache Directory Sizes:"
    
    # J1: Validate directory exists and is accessible before operations
    # F2: Validate command substitution results
    if [ -d "${CONTAINER_APT_CACHE:-}" ] && [ -x "${CONTAINER_APT_CACHE:-}" ]; then
        local size_output
        size_output=$(du -sh "${CONTAINER_APT_CACHE}" 2>/dev/null | cut -f1 || echo '0B')
        printf '%s\n' " ${CONTAINER_APT_CACHE}: ${size_output}"
    else
        printf '%s\n' " ${CONTAINER_APT_CACHE:-/unknown}: 0B (directory not found)"
    fi
    # ENDIF: container APT cache size
    
    if [ -d "${CONTAINER_CONDA_CACHE:-}" ] && [ -x "${CONTAINER_CONDA_CACHE:-}" ]; then
        local size_output
        size_output=$(du -sh "${CONTAINER_CONDA_CACHE}" 2>/dev/null | cut -f1 || echo '0B')
        printf '%s\n' " ${CONTAINER_CONDA_CACHE}: ${size_output}"
    else
        printf '%s\n' " ${CONTAINER_CONDA_CACHE:-/unknown}: 0B (directory not found)"
    fi
    # ENDIF: container CONDA cache size
    
    if [ -d "${CONTAINER_WHEELS_CACHE:-}" ] && [ -x "${CONTAINER_WHEELS_CACHE:-}" ]; then
        local size_output
        size_output=$(du -sh "${CONTAINER_WHEELS_CACHE}" 2>/dev/null | cut -f1 || echo '0B')
        printf '%s\n' " ${CONTAINER_WHEELS_CACHE}: ${size_output}"
    else
        printf '%s\n' " ${CONTAINER_WHEELS_CACHE:-/unknown}: 0B (directory not found)"
    fi
    # ENDIF: container WHEELS cache size
    
    if [ -d "${CONTAINER_JULIA_CACHE:-}" ] && [ -x "${CONTAINER_JULIA_CACHE:-}" ]; then
        local size_output
        size_output=$(du -sh "${CONTAINER_JULIA_CACHE}" 2>/dev/null | cut -f1 || echo '0B')
        printf '%s\n' " ${CONTAINER_JULIA_CACHE}: ${size_output}"
    else
        printf '%s\n' " ${CONTAINER_JULIA_CACHE:-/unknown}: 0B (directory not found)"
    fi
    # ENDIF: container JULIA cache size
    
    printf '%s\n' "=========================================================="
    printf '%s\n' ""
    return 0
}
# ENDFUNC: cache_summary

#===============================================================================
# SECTION 2: CACHE CONFIGURATION FUNCTIONS (BLOCK 6)
#===============================================================================

#--- Function: validate_and_repair_cache ---
# Purpose: Validate and repair cache directories before configuration
# Dependencies: CONTAINER_* cache variables from config.sh
# Returns: 0 on success
# Outputs: Prints validation status for each cache directory
validate_and_repair_cache() {
    printf '%s\n' "==> Validating and repairing cache directories..."
    
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
            printf '%s\n' "[warn] ⚠ Failed to create cache directory: ${dir}"
            continue
        fi
        # J1: Verify directory was created successfully
        if [ ! -d "${dir}" ]; then
            printf '%s\n' "[warn] ⚠ Directory does not exist after creation: ${dir}"
            continue
        fi
        # H1: Check exit code of chown operation
        # Note: Ownership change may fail if directory is a mount point, read-only filesystem,
        # or already owned by correct user. Check if directory is writable instead.
        if ! chown -R root:root "${dir}" 2>/dev/null; then
            # Check if directory is actually writable (ownership might not matter)
            local test_file="${dir}/.write_test_$$"
            if touch "${test_file}" 2>/dev/null && rm -f "${test_file}" 2>/dev/null; then
                printf '%s\n' "[warn] ⚠ Failed to set ownership on: ${dir} (but directory is writable - continuing)"
            else
                printf '%s\n' "[warn] ⚠ Failed to set ownership on: ${dir} (directory may not be writable)"
            fi
        fi
        # H1: Check exit code of chmod operation
        if ! chmod -R 755 "${dir}" 2>/dev/null; then
            printf '%s\n' "[warn] ⚠ Failed to set permissions on: ${dir}"
        fi
        printf '%s\n' "✓ Validated: ${dir}"
    done
    # ENDFOR: cache_dirs validation loop
    
    return 0
}
# ENDFUNC: validate_and_repair_cache

#--- Function: setup_unified_cache ---
# Purpose: Configure unified caching for all package managers
# Dependencies: validate_and_repair_cache(), CONTAINER_* variables from config.sh
# Returns: 0 on success, 1 on failure
# Outputs: Prints configuration status
setup_unified_cache() {
    printf '%s\n' "==> Configuring unified caching for all package managers..."
    
    # Validate cache first
    validate_and_repair_cache
    
    # 1. Configure APT Caching (safe to do early)
    # This directory exists by default on Ubuntu.
    # CRITICAL: Use double quotes to expand ${CONTAINER_APT_CACHE} variable
    # J1: Validate parent directory exists before creating file
    # H1: Check exit code of file write operations
    if [ -d /etc/apt/apt.conf.d ] && [ -w /etc/apt/apt.conf.d ]; then
        if ! printf '%s\n' "Dir::Cache::Archives \"${CONTAINER_APT_CACHE}\";" > /etc/apt/apt.conf.d/90-cache.conf 2>/dev/null; then
            printf '%s\n' "[ERROR] ⚠ Failed to write APT cache configuration file" >&2
            return 1
        fi
        if ! printf '%s\n' 'APT::Keep-Downloaded-Packages "true";' >> /etc/apt/apt.conf.d/90-cache.conf 2>/dev/null; then
            printf '%s\n' "[ERROR] ⚠ Failed to append to APT cache configuration file" >&2
            return 1
        fi
    else
        printf '%s\n' "[ERROR] ⚠ /etc/apt/apt.conf.d directory not writable" >&2
        return 1
    fi
    # ENDIF: /etc/apt/apt.conf.d is writable
    
    # 2. Configure Pip Caching
    # J1: Validate parent directory exists before creating subdirectory
    # H1: Check exit code of directory and file operations
    if ! mkdir -p /root/.config/pip 2>/dev/null; then
        printf '%s\n' "[ERROR] ⚠ Failed to create pip config directory" >&2
        return 1
    fi
    # J1: Verify directory was created successfully
    if [ ! -d /root/.config/pip ]; then
        printf '%s\n' "[ERROR] ⚠ pip config directory does not exist after creation" >&2
        return 1
    fi
    if ! printf '[global]\ncache-dir = %s\n' "${PIP_CACHE_DIR}" > /root/.config/pip/pip.conf 2>/dev/null; then
        printf '%s\n' "[ERROR] ⚠ Failed to write pip configuration file" >&2
        return 1
    fi
    # H1: Check exit code of chown operation
    if [ -d "${PIP_CACHE_DIR}" ] && ! chown -R root:root "${PIP_CACHE_DIR}" 2>/dev/null; then
        printf '%s\n' "[warn] ⚠ Failed to set ownership on pip cache directory" >&2
    fi
    # H1: Check exit code of chmod operation
    if [ -d "${PIP_CACHE_DIR}" ] && ! chmod -R 755 "${PIP_CACHE_DIR}" 2>/dev/null; then
        printf '%s\n' "[warn] ⚠ Failed to set permissions on pip cache directory" >&2
    fi
    
    # 3. Prepare Conda Caching with Staging Area Strategy
    # This config file will be used when Miniforge is installed later
    # Note: Only create if MINIFORGE_HOME is set (conda may not be installed yet)
    if [ -n "${MINIFORGE_HOME:-}" ]; then
        # J1: Validate parent directory exists before creating subdirectory
        # H1: Check exit code of mkdir operation
        if ! mkdir -p "${MINIFORGE_HOME}" 2>/dev/null; then
            printf '%s\n' "[warn] ⚠ Failed to create MINIFORGE_HOME directory: ${MINIFORGE_HOME}" >&2
        else
            # J1: Verify directory was created successfully
            if [ ! -d "${MINIFORGE_HOME}" ]; then
                printf '%s\n' "[warn] ⚠ MINIFORGE_HOME directory does not exist after creation" >&2
            else
                # H1: Check exit code of cat/heredoc operation
                # Create conda config file with proper variable expansion
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
                    printf '%s\n' "[ERROR] ⚠ Failed to write conda configuration file" >&2
                else
                    # J1: Verify file was created successfully
                    if [ ! -f "${MINIFORGE_HOME}/.condarc.pre" ]; then
                        printf '%s\n' "[warn] ⚠ Conda config file does not exist after creation" >&2
                    fi
                fi
            fi
        fi
    else
        printf '%s\n' "⚠ WARNING: MINIFORGE_HOME not set - skipping conda cache configuration"
    fi
    # ENDIF: MINIFORGE_HOME provided for conda cache configuration
    
    # 4. Configure Julia Caching
    # Julia uses JULIA_DEPOT_PATH environment variable (already set in BLOCK 6.2)
    # No additional configuration file needed - environment variable is sufficient
    
    # Verify APT cache configuration was properly applied
    printf '%s\n' "==> Verifying APT cache configuration..."
    # J1: Validate file exists and is readable before operations
    if [ -f /etc/apt/apt.conf.d/90-cache.conf ] && [ -r /etc/apt/apt.conf.d/90-cache.conf ]; then
        printf '%s\n' "APT cache configuration file contents:"
        # H1: Check exit code of cat operation
        if ! cat /etc/apt/apt.conf.d/90-cache.conf 2>/dev/null; then
            printf '%s\n' "[warn] ⚠ Failed to read APT cache configuration file" >&2
        fi
        # Verify the path is expanded (not literal ${CONTAINER_APT_CACHE})
        # D3: Use here-string instead of pipe pattern
        local config_content
        config_content=$(cat /etc/apt/apt.conf.d/90-cache.conf 2>/dev/null || echo "")
        # D3: Use here-string instead of pipe pattern (unsafe pipe pattern fixed)
        if [ -n "${config_content:-}" ] && grep -q "\${CONTAINER_APT_CACHE}" <<< "${config_content}"; then
            printf '%s\n' "[ERROR] ⚠ APT cache configuration has unexpanded variable!" >&2
            return 1
        fi
        printf '%s\n' "✓ APT cache configured to: ${CONTAINER_APT_CACHE}"
    else
        printf '%s\n' "[ERROR] ⚠ APT cache configuration file not found or not readable!" >&2
        return 1
    fi
    # ENDIF: APT cache configuration verification
    
    printf '%s\n' "==> Initial caching configured successfully."
    return 0
}
# ENDFUNC: setup_unified_cache

# Export functions for use in subshells if needed
export -f display_cache_monitoring_summary cache_summary validate_and_repair_cache setup_unified_cache

