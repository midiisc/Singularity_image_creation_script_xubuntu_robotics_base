#!/usr/bin/env bash
set -eo pipefail  # Removed -u to allow unbound variables with defaults

# Purpose: A lightweight front-end for apt/apt-get that:
#   - Forces a unified cache location across APT tools
#   - Uses aria2c for accelerated downloads on install-like commands
#   - Falls back gracefully to standard apt-get when necessary
# Inputs:
#   - Environment variable CONTAINER_APT_CACHE (optional)
#   - Command-line arguments forwarded to apt/apt-get
# Behavior:
#   - For install/remove/purge/build-dep/source: collect URIs and download via aria2c
#     into the cache, then run apt-get to perform installation from cache
#   - For other commands: pass-through to apt-get with cache options
# Safety:
#   - Validates temporary files and ensures cleanup
#   - Uses guarded command substitutions and here-strings to avoid unsafe pipes
#   - Protects cache with chattr +i when available (best-effort)

# Centralized APT cache configuration - All APT tools use this location
# Set default cache location if not provided via environment variable
if [ -z "${CONTAINER_APT_CACHE:-}" ]; then
    # Try to detect cache location from environment or use sensible default
    if [ -n "${CONTAINER_CACHE_ROOT:-}" ]; then
        CONTAINER_APT_CACHE="${CONTAINER_CACHE_ROOT}/apt/archives"
    elif [ -d "/container_cache/apt" ]; then
        CONTAINER_APT_CACHE="/container_cache/apt"
    elif [ -d "/tmp/container_cache/apt" ]; then
        CONTAINER_APT_CACHE="/tmp/container_cache/apt"
    else
        CONTAINER_APT_CACHE="/var/cache/apt/archives"
    fi
    echo "[apt-aria] WARNING: CONTAINER_APT_CACHE not set, using default: ${CONTAINER_APT_CACHE}"
fi
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
    URI_FILE=$(mktemp) || {
        echo "[apt-aria] ERROR: Failed to create temporary file"
        exit 1
    }
    echo "[apt-aria] Collecting URIs with: /usr/bin/apt-get ${APT_CACHE_OPTS} --print-uris -y $*"

    # Use a more robust approach to collect URIs
    # First, check if there are actually packages to download
    # Split APT_CACHE_OPTS properly to handle multiple arguments
    # Note: This requires proper handling of spaces in APT_CACHE_OPTS
    # Note: APT_CACHE_OPTS is intentionally unquoted to allow word splitting for apt-get
    # F2: Capture both output and exit code separately for proper validation
    APT_OUTPUT=$(/usr/bin/apt-get ${APT_CACHE_OPTS} --print-uris -y "$@" 2>&1)
    APT_EXIT_CODE=$?
    # F2: Validate command substitution result
    if [ -z "${APT_OUTPUT:-}" ] && [ "${APT_EXIT_CODE:-1}" -ne 0 ]; then
        echo "[apt-aria] WARNING: apt-get --print-uris produced no output but exited with code ${APT_EXIT_CODE}"
    fi
    
    # Check if packages are already installed or nothing to download (benign case)
    # D3: Use here-string instead of pipe pattern
    if [ -n "${APT_OUTPUT:-}" ] && grep -qiE "(already the newest|0 upgraded|0 to install|already installed)" <<< "${APT_OUTPUT}"; then
        echo "[apt-aria] Packages already installed or up-to-date - no downloads needed"
        # H1: Check exit code of touch operation
        if ! touch "${URI_FILE}" 2>/dev/null; then
            echo "[apt-aria] WARNING: Failed to create URI file"
        fi
    # Check if there's an actual error (not just "no URIs")
    elif [ "${APT_EXIT_CODE:-1}" -ne 0 ] && [ -n "${APT_OUTPUT:-}" ] && ! grep -qiE "(already the newest|0 upgraded|0 to install)" <<< "${APT_OUTPUT}"; then
        echo "[apt-aria] WARNING: apt-get --print-uris failed (exit code: ${APT_EXIT_CODE})"
        # F2: Validate command substitution result
        # D3: Use here-string instead of echo | head (unsafe pipe pattern)
        error_preview=$(head -3 <<< "${APT_OUTPUT}" || echo "")
        if [ -n "${error_preview:-}" ]; then
            echo "[apt-aria] Error output: ${error_preview}"
        fi
        echo "[apt-aria] Falling back to standard apt-get (without aria2c acceleration)"
        # H1: Check exit code of touch operation
        if ! touch "${URI_FILE}" 2>/dev/null; then
            echo "[apt-aria] WARNING: Failed to create URI file"
        fi
    # Try to extract URIs from the output
    # F2: Validate pipeline result
    elif [ -n "${APT_OUTPUT:-}" ] && grep -E "'(https?://[^']*)'" <<< "${APT_OUTPUT}" | \
        sed -E "s/^'([^']+)'.*$/\1/" | \
        sed "s/ //g" | \
        grep -E "^https?://.*\.deb$" | sort -u > "${URI_FILE}" 2>/dev/null && [ -s "${URI_FILE}" ]; then
        # F2: Validate command substitution result
        uri_count=$(wc -l < "${URI_FILE}" || echo "0")
        if ! [[ "${uri_count:-0}" =~ ^[0-9]+$ ]]; then
            uri_count="0"
        fi
        echo "[apt-aria] URI collection successful (${uri_count} packages)"
    else
        # No URIs found, but not an error - likely already cached or installed
        echo "[apt-aria] No URIs to download (packages may be cached or already installed)"
        # H1: Check exit code of touch operation
        if ! touch "${URI_FILE}" 2>/dev/null; then
            echo "[apt-aria] WARNING: Failed to create URI file"
        fi
    fi

    echo "[apt-aria] URI file created: ${URI_FILE}"
    echo "[apt-aria] URI file contents:"
    # J1: Validate file exists before reading
    # H1: Check exit code of cat operation
    if [ -f "${URI_FILE}" ] && [ -r "${URI_FILE}" ]; then
        if ! cat "${URI_FILE}" 2>/dev/null; then
            echo "[apt-aria] URI file is unreadable"
        fi
    else
        echo "[apt-aria] URI file is empty or unreadable"
    fi

    # J1: Validate file exists and is non-empty before operations
    if [ -s "${URI_FILE}" ]; then
        # F2: Validate command substitution result
        uri_count=$(wc -l < "${URI_FILE}" || echo "0")
        if ! [[ "${uri_count:-0}" =~ ^[0-9]+$ ]]; then
            uri_count="0"
        fi
        echo "[apt-aria] Downloading ${uri_count} packages via aria2c..."
      echo "[apt-aria] Cache directory: ${CACHE}"
      echo "[apt-aria] aria2c command: aria2c --check-certificate=false -x16 -s16 -m3 -d ${CACHE} -i ${URI_FILE}"

      # Try multi-connection first with error suppression
      # H1: Check exit code of aria2c operation
      if ! aria2c --check-certificate=false -x16 -s16 -m3 -d "${CACHE}" -i "${URI_FILE}" 2>/dev/null; then
        echo "[apt-aria] Multi-connection failed, trying single-connection..."
        # Fallback: single-connection (handles servers that reject ranges, e.g. some PPAs)
        # H1: Check exit code of aria2c operation
        if ! aria2c --check-certificate=false -x1 -s1 -m3 -d "${CACHE}" -i "${URI_FILE}" 2>/dev/null; then
          echo "[apt-aria] aria2c failed completely, falling back to apt-get"
        else
          echo "[apt-aria] Single-connection aria2c succeeded"
        fi
      else
        echo "[apt-aria] Multi-connection aria2c succeeded"
      fi
      # H4: Validate rm operation result
      if [ -f "${URI_FILE}" ] && ! rm -f "${URI_FILE}" 2>/dev/null; then
        echo "[apt-aria] WARNING: Failed to remove temporary URI file: ${URI_FILE}"
      fi
    else
      echo "[apt-aria] No URIs to download"
      # H4: Validate rm operation result
      if [ -f "${URI_FILE}" ] && ! rm -f "${URI_FILE}" 2>/dev/null; then
        echo "[apt-aria] WARNING: Failed to remove temporary URI file: ${URI_FILE}"
      fi
    fi

    # --- PROTECT CACHE ---
    # Make all .deb files in the cache immutable to prevent deletion
    echo "[apt-aria] Making downloaded packages immutable to protect cache..."
    # M1: Verify chattr command exists
    if command -v chattr >/dev/null 2>&1; then
        # J1: Validate directory exists before operations
        if [ -d "${CACHE}" ] && [ -x "${CACHE}" ]; then
            # Use find to safely handle glob expansion
            # H4: Validate find/exec operation result
            chattr_exit_code=0
            find "${CACHE}" -maxdepth 1 -name "*.deb" -type f -exec chattr +i {} + 2>/dev/null || chattr_exit_code=$?
            if [ "${chattr_exit_code:-0}" -eq 0 ]; then
                echo "[apt-aria] chattr command executed successfully"
            else
                echo "[apt-aria] WARNING: Some files may not have been protected with chattr"
            fi
        else
            echo "[apt-aria] WARNING: Cache directory not accessible: ${CACHE}"
        fi
    else
        echo "[apt-aria] WARNING: chattr command not available - cache protection disabled"
    fi

    # Install from cache using apt-get (reliable and standard)
    # Note: APT_CACHE_OPTS is intentionally unquoted to allow word splitting for apt-get
    echo "[apt-aria] Installing packages from cache..."
    exec /usr/bin/apt-get ${APT_CACHE_OPTS} -y "$@"
else
    # Use regular apt-get with cache configuration for non-install commands
    # Note: APT_CACHE_OPTS is intentionally unquoted to allow word splitting for apt-get
    echo "[apt-aria] Using apt-get with cache configuration..."
    exec /usr/bin/apt-get ${APT_CACHE_OPTS} "$@"
fi
