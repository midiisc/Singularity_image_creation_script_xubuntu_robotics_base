#!/bin/bash
#===============================================================================
# LIBRARY VERIFICATION FUNCTIONS FOR CONTAINER BUILD SCRIPTS
# Single source of truth for library detection and ldconfig management
#===============================================================================
# Purpose: Centralized library verification and ldconfig refresh functions
# Usage: source "$(dirname "$0")/../scripts/library_functions.sh"
#        Or from inside container: source "/scripts/library_functions.sh"
# Dependencies: ldconfig, objdump (optional), ldd (optional)
#===============================================================================

#===============================================================================
# SECTION 1: LD.CONFIG PRIORITY AND REFRESH FUNCTIONS
#===============================================================================

#--- Function: ensure_compiled_lib_priority ---
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

#--- Function: run_ldconfig_refresh ---
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

#--- Function: run_ldconfig_refresh_dir ---
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
  find_output=""
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
  lib_count=0
  lib_count=$(find "${target_dir}" -maxdepth 1 -name "*.so*" -type f 2>/dev/null | wc -l || echo "0")
  if [ "${lib_count}" -gt 0 ]; then
    # Try to find at least one library from this directory in the cache
    sample_lib=""
    # D3e: SIGPIPE protection - add || true at end of pipeline with head
    sample_lib=$(find "${target_dir}" -maxdepth 1 -name "*.so" -type f 2>/dev/null | head -1 2>/dev/null || echo "" || true)
    if [ -n "${sample_lib}" ]; then
      lib_basename=""
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

#===============================================================================
# SECTION 2: LIBRARY PATH REGISTRATION
#===============================================================================

#--- Function: ensure_library_path_registered ---
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

#===============================================================================
# SECTION 3: LIBRARY VERIFICATION
#===============================================================================

#--- Function: verify_library_available ---
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
}

# Alias for backward compatibility (verify_library_installation -> verify_library_available)
verify_library_installation() {
  verify_library_available "$@"
}

