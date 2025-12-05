#!/usr/bin/env bash
# Purpose: Run the 4-part code check sequentially and non-interactively over a target file
#          in fixed-size line windows (default 500), applying fixes without producing reports.
# Description:
#   - Iterates over a specified file in windows of N lines (default: 500).
#   - For each window, exports scoping environment variables so downstream validators
#     (e.g., enforce_pre_commit_validation.sh and any called tools) can limit work to that region.
#   - Invokes the repository enforcement script non-interactively to run PART1→PART4 sequentially,
#     applying corrections and re-validating before proceeding to the next window.
#   - Produces no user-facing reports by default; exits non-zero on failure unless continue-on-error is set.
# Notes:
#   - If the enforcement script/tools do not consume the scoping variables, execution still remains safe:
#     they will process the broader context without generating chat output or report artifacts.
#   - This script itself does not stage/commit/push; it only runs validation/fix cycles.
#
# Usage:
#   scripts/helpers/run_sequential_chunked_review.sh -f <file> [-w 500] [-o 0] [--continue-on-error]
#     -f|--file                Absolute or relative path to the file to process (required)
#     -w|--window              Window size (lines), default: 500
#     -o|--overlap             Overlap size (lines) between consecutive windows, default: 0
#     --continue-on-error      Do not exit on first failure; continue through all windows
#     --dry-run                Export scope vars and print actions but do not invoke enforcement
#     --enforcement-script     Path to enforcement script; default:
#                              scripts/helpers/enforce_pre_commit_validation.sh
#
# Environment variables consumed by downstream tools (best-effort scoping hints):
#   CODE_CHECK_SCOPE_FILE           Absolute path to target file
#   CODE_CHECK_SCOPE_START_LINE     Start line of current window (1-based)
#   CODE_CHECK_SCOPE_END_LINE       End line of current window (inclusive)
#   CODE_CHECK_SEQUENTIAL           "1" to enforce one-part-at-a-time processing
#   CODE_CHECK_ASSUME_YES           "1" to skip mid-process confirmations
#   CODE_CHECK_NO_REPORT            "1" to disable generating user-facing reports
#   CODE_CHECK_CHUNKED_MODE         "1" to indicate chunked processing
#   CODE_CHECK_TOTAL_WINDOWS        Total number of windows planned
#   CODE_CHECK_CURRENT_WINDOW       1-based index of the current window
#
set -euo pipefail

# Purpose: Print usage/help text
print_usage() {
  cat <<'USAGE'
Run sequential 4-part code check over a file in fixed-size line windows.

Options:
  -f, --file <path>            Target file (required)
  -w, --window <n>             Window size in lines (default: 500)
  -o, --overlap <n>            Overlap between windows in lines (default: 0)
      --continue-on-error      Continue processing remaining windows on error
      --dry-run                Do not invoke enforcement; only print actions
      --enforcement-script     Path to enforcement script (default:
                               scripts/helpers/enforce_pre_commit_validation.sh)
  -h, --help                   Show this help and exit
USAGE
}
# ENDIF: print_usage helper

# Purpose: Resolve a path to absolute form (without relying on external realpath)
# Parameters:
#   $1 = input path
# Returns:
#   echoes absolute path
to_abs_path() {
  # Use subshell to avoid altering caller's PWD
  (
    cd "$(dirname -- "$1")" >/dev/null 2>&1 || exit 1
    printf "%s/%s" "$(pwd -P)" "$(basename -- "$1")"
  )
}
# ENDIF: to_abs_path helper

TARGET_FILE=""
WINDOW_SIZE=500
OVERLAP_SIZE=0
CONTINUE_ON_ERROR=0
DRY_RUN=0
ENFORCEMENT_SCRIPT_DEFAULT="scripts/helpers/enforce_pre_commit_validation.sh"
ENFORCEMENT_SCRIPT="$ENFORCEMENT_SCRIPT_DEFAULT"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--file)
      TARGET_FILE="${2:-}"; shift 2 ;;
    -w|--window)
      WINDOW_SIZE="${2:-}"; shift 2 ;;
    -o|--overlap)
      OVERLAP_SIZE="${2:-}"; shift 2 ;;
    --continue-on-error)
      CONTINUE_ON_ERROR=1; shift ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    --enforcement-script)
      ENFORCEMENT_SCRIPT="${2:-}"; shift 2 ;;
    -h|--help)
      print_usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      print_usage
      exit 2 ;;
  esac
done

if [[ -z "${TARGET_FILE}" ]]; then
  echo "Error: --file is required" >&2
  print_usage
  exit 2
fi

if [[ ! -f "${TARGET_FILE}" ]]; then
  echo "Error: Target file not found: ${TARGET_FILE}" >&2
  exit 2
fi

if [[ ! -x "${ENFORCEMENT_SCRIPT}" ]]; then
  # Try repo-root relative fallback
  if [[ -x "./${ENFORCEMENT_SCRIPT_DEFAULT}" ]]; then
    ENFORCEMENT_SCRIPT="./${ENFORCEMENT_SCRIPT_DEFAULT}"
  else
    echo "Error: Enforcement script not found or not executable: ${ENFORCEMENT_SCRIPT}" >&2
    exit 2
  fi
fi

# Normalize numerics
if ! [[ "${WINDOW_SIZE}" =~ ^[0-9]+$ ]] || [[ "${WINDOW_SIZE}" -le 0 ]]; then
  echo "Error: --window must be a positive integer" >&2
  exit 2
fi
if ! [[ "${OVERLAP_SIZE}" =~ ^[0-9]+$ ]]; then
  echo "Error: --overlap must be a non-negative integer" >&2
  exit 2
fi
if [[ "${OVERLAP_SIZE}" -ge "${WINDOW_SIZE}" ]]; then
  echo "Error: --overlap (${OVERLAP_SIZE}) must be less than --window (${WINDOW_SIZE})" >&2
  exit 2
fi

ABS_TARGET_FILE="$(to_abs_path "${TARGET_FILE}")"
TOTAL_LINES="$(wc -l < "${TARGET_FILE}" | awk '{print $1}')"
if ! [[ "${TOTAL_LINES}" =~ ^[0-9]+$ ]]; then
  echo "Error: Unable to determine total lines for ${TARGET_FILE}" >&2
  exit 2
fi

# Purpose: Compute total windows given total lines, window, and overlap
# Returns:
#   echoes the number of windows
compute_total_windows() {
  local total_lines="$1"
  local win="$2"
  local olap="$3"
  local step=$((win - olap))
  local count=0
  local start=1
  while [[ "${start}" -le "${total_lines}" ]]; do
    count=$((count + 1))
    start=$((start + step))
  done
  echo "${count}"
}
# ENDIF: compute_total_windows helper

TOTAL_WINDOWS="$(compute_total_windows "${TOTAL_LINES}" "${WINDOW_SIZE}" "${OVERLAP_SIZE}")"

echo "Chunked sequential review starting"
echo "  File: ${ABS_TARGET_FILE}"
echo "  Total lines: ${TOTAL_LINES}"
echo "  Window size: ${WINDOW_SIZE}"
echo "  Overlap: ${OVERLAP_SIZE}"
echo "  Windows: ${TOTAL_WINDOWS}"
echo "  Enforcement: ${ENFORCEMENT_SCRIPT}"
[[ "${DRY_RUN}" -eq 1 ]] && echo "  Mode: DRY-RUN (no enforcement invocation)"

# Purpose: Run enforcement for a single window
# Parameters:
#   $1 = start line (1-based)
#   $2 = end line (inclusive)
#   $3 = window index (1-based)
# Returns:
#   0 on success, non-zero on failure
run_window() {
  local start_line="$1"
  local end_line="$2"
  local window_idx="$3"

  export CODE_CHECK_SCOPE_FILE="${ABS_TARGET_FILE}"
  export CODE_CHECK_SCOPE_START_LINE="${start_line}"
  export CODE_CHECK_SCOPE_END_LINE="${end_line}"
  export CODE_CHECK_SEQUENTIAL="1"
  export CODE_CHECK_ASSUME_YES="1"
  export CODE_CHECK_NO_REPORT="1"
  export CODE_CHECK_CHUNKED_MODE="1"
  export CODE_CHECK_TOTAL_WINDOWS="${TOTAL_WINDOWS}"
  export CODE_CHECK_CURRENT_WINDOW="${window_idx}"

  echo "Window ${window_idx}/${TOTAL_WINDOWS}: lines ${start_line}-${end_line}"
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    return 0
  fi

  # Invoke enforcement script; it should handle PART1→PART4 sequentially, auto-fixing between parts.
  # If it ignores scope variables, it will still run safely without generating reports.
  if ! "${ENFORCEMENT_SCRIPT}"; then
    return 1
  fi
  return 0
}
# ENDIF: run_window helper

# Phase 1: Iterate windows and enforce
step_size=$((WINDOW_SIZE - OVERLAP_SIZE))
current_start=1
window_index=0

while [[ "${current_start}" -le "${TOTAL_LINES}" ]]; do
  window_index=$((window_index + 1))
  current_end=$((current_start + WINDOW_SIZE - 1))
  if [[ "${current_end}" -gt "${TOTAL_LINES}" ]]; then
    current_end="${TOTAL_LINES}"
  fi

  if ! run_window "${current_start}" "${current_end}" "${window_index}"; then
    echo "Failure in window ${window_index}/${TOTAL_WINDOWS} (lines ${current_start}-${current_end})" >&2
    if [[ "${CONTINUE_ON_ERROR}" -eq 0 ]]; then
      echo "Stopping due to failure (use --continue-on-error to proceed through all windows)" >&2
      exit 1
    fi
  fi

  # Move to next window
  current_start=$((current_start + step_size))
# ENDWHILE: iterate windows
done

echo "Chunked sequential review completed for ${ABS_TARGET_FILE}"
exit 0


