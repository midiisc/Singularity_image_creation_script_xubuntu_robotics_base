#!/usr/bin/env bash
set -euo pipefail

# Centralized APT cache configuration - All APT tools use this location
if [ -z "${CONTAINER_APT_CACHE:-}" ]; then
    echo "[apt-aria] ERROR: CONTAINER_APT_CACHE is not set"
    exit 1
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
    APT_OUTPUT=$(/usr/bin/apt-get ${APT_CACHE_OPTS} --print-uris -y "$@" 2>&1)
    APT_EXIT_CODE=$?
    
    # Check if packages are already installed or nothing to download (benign case)
    if echo "${APT_OUTPUT}" | grep -qiE "(already the newest|0 upgraded|0 to install|already installed)"; then
        echo "[apt-aria] Packages already installed or up-to-date - no downloads needed"
        touch "${URI_FILE}"
    # Check if there's an actual error (not just "no URIs")
    elif [ "${APT_EXIT_CODE}" -ne 0 ] && ! echo "${APT_OUTPUT}" | grep -qiE "(already the newest|0 upgraded|0 to install)"; then
        echo "[apt-aria] WARNING: apt-get --print-uris failed (exit code: ${APT_EXIT_CODE})"
        echo "[apt-aria] Error output: $(echo "${APT_OUTPUT}" | head -3)"
        echo "[apt-aria] Falling back to standard apt-get (without aria2c acceleration)"
        touch "${URI_FILE}"
    # Try to extract URIs from the output
    elif echo "${APT_OUTPUT}" | grep -E "'(https?://[^']*)'" | \
        sed -E "s/^'([^']+)'.*$/\1/" | \
        sed "s/ //g" | \
        grep -E "^https?://.*\.deb$" | sort -u > "${URI_FILE}" 2>/dev/null && [ -s "${URI_FILE}" ]; then
        echo "[apt-aria] URI collection successful ($(wc -l < "${URI_FILE}") packages)"
    else
        # No URIs found, but not an error - likely already cached or installed
        echo "[apt-aria] No URIs to download (packages may be cached or already installed)"
        touch "${URI_FILE}"
    fi

    echo "[apt-aria] URI file created: ${URI_FILE}"
    echo "[apt-aria] URI file contents:"
    cat "${URI_FILE}" || echo "[apt-aria] URI file is empty or unreadable"

    if [ -s "${URI_FILE}" ]; then
    echo "[apt-aria] Downloading $(wc -l < "${URI_FILE}") packages via aria2c..."
      echo "[apt-aria] Cache directory: ${CACHE}"
      echo "[apt-aria] aria2c command: aria2c --check-certificate=false -x16 -s16 -m3 -d ${CACHE} -i ${URI_FILE}"

      # Try multi-connection first with error suppression
      if ! aria2c --check-certificate=false -x16 -s16 -m3 -d "${CACHE}" -i "${URI_FILE}" 2>/dev/null; then
        echo "[apt-aria] Multi-connection failed, trying single-connection..."
        # Fallback: single-connection (handles servers that reject ranges, e.g. some PPAs)
        if ! aria2c --check-certificate=false -x1 -s1 -m3 -d "${CACHE}" -i "${URI_FILE}" 2>/dev/null; then
          echo "[apt-aria] aria2c failed completely, falling back to apt-get"
        else
          echo "[apt-aria] Single-connection aria2c succeeded"
        fi
      else
        echo "[apt-aria] Multi-connection aria2c succeeded"
      fi
      rm -f "${URI_FILE}"
    else
      echo "[apt-aria] No URIs to download"
      rm -f "${URI_FILE}"
    fi

    # --- PROTECT CACHE ---
    # Make all .deb files in the cache immutable to prevent deletion
    echo "[apt-aria] Making downloaded packages immutable to protect cache..."
    if command -v chattr >/dev/null 2>&1; then
        # Use find to safely handle glob expansion
        find "${CACHE}" -maxdepth 1 -name "*.deb" -type f -exec chattr +i {} + 2>/dev/null || true
        echo "[apt-aria] chattr command executed successfully"
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
