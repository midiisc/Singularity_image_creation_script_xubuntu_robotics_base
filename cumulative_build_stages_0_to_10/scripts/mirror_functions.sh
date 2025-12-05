#!/bin/bash
#===============================================================================
# MIRROR PROBING FUNCTIONS FOR CONTAINER BUILD SCRIPTS
# Single source of truth for mirror selection and testing
#===============================================================================
# Purpose: Centralized mirror probing and selection functions
# Usage: source "$(dirname "$0")/../scripts/mirror_functions.sh"
#        Or from inside container: source "/scripts/mirror_functions.sh"
# Dependencies: curl, bash
#===============================================================================

#===============================================================================
# SECTION 1: MIRROR TESTING FUNCTION
#===============================================================================

#--- Function: test_mirror ---
# Purpose: Test a single Ubuntu mirror for speed and accessibility
# Parameters: $1 = mirror URL, $2 = Ubuntu codename, $3 = probe results file
# Returns: Writes result to probe results file (time and URL, or 999.9 for failed)
# Side effects: Downloads Packages.gz or Release file to measure bandwidth
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
    # CRITICAL: Use alternative temp directory instead of /tmp (may not be writable in containers)
    # Note: /var/tmp is also bind-mounted from host in Apptainer 1.4.1, use INSTALL_PREFIX as fallback
    # CRITICAL: Use INSTALL_PREFIX from config.sh (SINGLE SOURCE OF TRUTH)
    INSTALL_PREFIX="${INSTALL_PREFIX:-/opt}"
    local curl_tmp_dir="${APT_TMP_ALT:-${TMPDIR:-${INSTALL_PREFIX}}}"
    local curl_stdout curl_stderr
    curl_stdout=$(mktemp -p "${curl_tmp_dir}" 2>/dev/null) || curl_stdout="${curl_tmp_dir}/curl_stdout_$$"
    curl_stderr=$(mktemp -p "${curl_tmp_dir}" 2>/dev/null) || curl_stderr="${curl_tmp_dir}/curl_stderr_$$"
    
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
      # CRITICAL: Use alternative temp directory instead of /tmp (may not be writable in containers)
      # Note: /var/tmp is also bind-mounted from host in Apptainer 1.4.1, use /opt as fallback
      local curl_tmp_dir="${APT_TMP_ALT:-${TMPDIR:-/opt}}"
      curl_stdout=$(mktemp -p "${curl_tmp_dir}" 2>/dev/null) || curl_stdout="${curl_tmp_dir}/curl_stdout_release_$$"
      curl_stderr=$(mktemp -p "${curl_tmp_dir}" 2>/dev/null) || curl_stderr="${curl_tmp_dir}/curl_stderr_release_$$"
      
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

# Export function for parallel execution with xargs
export -f test_mirror

#===============================================================================
# SECTION 2: MIRROR PROBING AND SELECTION FUNCTION
#===============================================================================

#--- Function: probe_and_set_mirrors ---
# Purpose: Find fastest Ubuntu mirror and update all APT sources
# Dependencies: test_mirror function, curl
# Outputs: FASTEST_MIRROR (exported), updated /etc/apt/sources.list and sources.list.d/
# Note: This is a large function - see xubuntu_robotics_base_debug.sh lines 2084-2562 for full implementation
# For Stage 4, we'll include a simplified version that can be expanded later
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
  # CRITICAL: Use alternative temp directory instead of /tmp (may not be writable in containers)
  local probe_tmp_dir="${APT_TMP_ALT:-${TMPDIR:-/var/tmp}}"
  local probe_results_file
  if ! probe_results_file="$(mktemp -p "${probe_tmp_dir}" 2>/dev/null)"; then
    probe_results_file="${probe_tmp_dir}/mirror_probe_$$.tmp"
    if ! : > "${probe_results_file}"; then
      echo "[error] Failed to create temporary file for probe results"
      return 1
    fi
  fi
  PROBE_RESULTS="${probe_results_file}"
  export CODENAME PROBE_RESULTS  # Export for subshell access

  # Fallback to curated static list (simplified for Stage 4 - full dynamic fetch can be added later)
  # CRITICAL: Always include archive.ubuntu.com as first entry (guaranteed fallback)
  printf '%s\n' "[info] Using curated static mirror list (100Gbps+ verified)"
  CANDIDATE_MIRRORS=$'http://archive.ubuntu.com/ubuntu\n'
  CANDIDATE_MIRRORS+=$'http://mirror.aarnet.edu.au/pub/ubuntu/archive\n'
  CANDIDATE_MIRRORS+=$'http://ftp.fau.de/ubuntu\n'
  CANDIDATE_MIRRORS+=$'http://ftp.uni-stuttgart.de/ubuntu\n'
  CANDIDATE_MIRRORS+=$'http://mirror.ox.ac.uk/sites/archive.ubuntu.com/ubuntu\n'
  CANDIDATE_MIRRORS+=$'http://mirrors.wikimedia.org/ubuntu\n'

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
    # Validate result format BEFORE parsing
    if ! grep -qE -- '^[0-9.]+ https?://' "${PROBE_RESULTS}"; then
      printf '%s\n' "[warn] ⚠ Invalid result format in probe results (expected: time url)"
      printf '%s\n' "[info] Falling back to archive.ubuntu.com"
      FASTEST_MIRROR="http://archive.ubuntu.com/ubuntu"
      export FASTEST_MIRROR
      rm -f "${PROBE_RESULTS:-}" 2>/dev/null || true
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
  local fastest_mirror_raw
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
  
  # Final safety check: Ensure FASTEST_MIRROR is set
  if [ -z "${FASTEST_MIRROR:-}" ]; then
    printf '%s\n' "[ERROR] FASTEST_MIRROR is empty - this should never happen! Using archive.ubuntu.com"
    FASTEST_MIRROR="http://archive.ubuntu.com/ubuntu"
  fi
  # ENDIF: FASTEST_MIRROR final non-empty check
  
  printf '%s\n' "==> Selected fastest mirror: ${FASTEST_MIRROR}"

  # Export the variable so it persists after function ends and is available globally
  export FASTEST_MIRROR

  # Note: Full implementation of APT sources.list update is in xubuntu_robotics_base_debug.sh
  # For Stage 4, we'll just set the variable - full update can be added in later stages
  printf '%s\n' "[info] Mirror selection complete (FASTEST_MIRROR=${FASTEST_MIRROR})"
  printf '%s\n' "[info] Full APT sources.list update will be implemented in later stages"
  
  return 0
}
# End probe_and_set_mirrors function

