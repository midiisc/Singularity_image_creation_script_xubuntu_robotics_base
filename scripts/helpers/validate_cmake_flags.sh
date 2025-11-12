#!/bin/bash
################################################################################
# CMAKE FLAG VALIDATOR
# Purpose: Extract and validate all CMake flags against documentation
# Usage: ./validate_cmake_flags.sh <script_file> [--strict] [--report-only]
#
# Implements requirements from:
#   - prompts/Code_check_prompt_manual.txt (M8, M9, M10)
#   - Prevents invalid/undocumented CMake flags from being used
#
# Exit codes:
#   0 = All flags valid
#   1 = Invalid flags found (strict mode) or script errors
#   2 = Documentation missing (strict mode)
################################################################################

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WORKSPACE_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
DOCS_FLAGS_DIR="${WORKSPACE_ROOT}/docs/flags"

# Command line options
STRICT_MODE=false
REPORT_ONLY=false
TARGET_SCRIPT=""

# Statistics
TOTAL_CMAKE_COMMANDS=0
TOTAL_FLAGS_FOUND=0
VALID_FLAGS=0
INVALID_FLAGS=0
UNDOCUMENTED_LIBRARIES=0

################################################################################
# HELPER FUNCTIONS
################################################################################

print_usage() {
  cat <<EOF
Usage: ${0##*/} <script_file> [OPTIONS]

Validates all CMake flags in a build script against documentation.

OPTIONS:
  --strict         Exit with error if any invalid flags or missing docs found
  --report-only    Generate report without validation (check extraction only)
  --help           Show this help message

EXAMPLES:
  ${0##*/} xubuntu_robotics_base_post_ULTRA_CLEANED.sh
  ${0##*/} build_script.sh --strict
  ${0##*/} test.sh --report-only

EXIT CODES:
  0 = All flags valid (or report-only mode)
  1 = Invalid flags found (strict mode) or errors
  2 = Documentation missing (strict mode)
EOF
}

log_info() {
  echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_success() {
  echo -e "${GREEN}[✓]${NC} $*" >&2
}

log_warning() {
  echo -e "${YELLOW}[⚠]${NC} $*" >&2
}

log_error() {
  echo -e "${RED}[✗]${NC} $*" >&2
}

################################################################################
# CMAKE COMMAND EXTRACTION
################################################################################

extract_cmake_commands() {
  local script_file="$1"
  local temp_output
  temp_output=$(mktemp)
  
  log_info "Extracting CMake commands from ${script_file##*/}..."
  
  # Extract cmake commands (handle multi-line with backslash continuation)
  # Match cmake configuration commands: cmake .. OR cmake . OR cmake -D OR cmake "${
  # Exclude: cmake --build, cmake./, bare "cmake" as package name
  grep -n "^[[:space:]]*cmake[[:space:]]" "$script_file" | \
    grep -v "cmake --build" | \
    grep -v "cmake\./" | \
    grep -v "^[0-9]*:[[:space:]]*cmake[[:space:]]*\\$" | \
    cut -d: -f1 > "${temp_output}.lines"
  
  # For each line number, extract the full cmake command (handle continuations)
  while read -r line_num; do
    awk -v start="$line_num" '
      NR == start {
        cmd = $0
        while (cmd ~ /\\[[:space:]]*$/ && getline > 0) {
          sub(/\\[[:space:]]*$/, "", cmd)
          cmd = cmd " " $0
        }
        print start ":" cmd
      }
    ' "$script_file"
  done < "${temp_output}.lines" > "$temp_output"
  
  rm -f "${temp_output}.lines"
  
  local count=$(wc -l < "$temp_output")
  log_info "Found ${count} cmake command(s)"
  
  # Output: count|filepath (so caller can parse both)
  echo "${count}|$temp_output"
}

################################################################################
# FLAG EXTRACTION
################################################################################

extract_flags_from_cmake_command() {
  local cmake_cmd="$1"
  
  # Extract all -D FLAG=VALUE or -DFLAG=VALUE patterns
  # Handle both formats: -D FLAG=VALUE and -DFLAG=VALUE
  # Use sed instead of grep with lookbehind to avoid variable-length lookbehind issues
  echo "$cmake_cmd" | grep -oE '\-D[[:space:]]*[A-Z_][A-Z0-9_]*=' | sed 's/-D[[:space:]]*//; s/=$//' || true
}

################################################################################
# LIBRARY DETECTION
################################################################################

detect_library_from_context() {
  local script_file="$1"
  local line_num="$2"
  
  # Look backward from the cmake command to find library name comments
  # Search up to 50 lines back for context
  local start_line=$((line_num - 50))
  [ "$start_line" -lt 1 ] && start_line=1
  
  local context
  context=$(awk -v start="$start_line" -v end="$line_num" '
    NR >= start && NR < end {
      if (/[Cc]eres|[Ss]olver/) library = "ceres"
      else if (/g2o|G2O/) library = "g2o"
      else if (/GTSAM|gtsam/) library = "gtsam"
      else if (/[Oo]pen[Cc][Vv]|OpenCV|opencv/) library = "opencv"
      else if (/[Oo]pen3[Dd]|Open3D/) library = "open3d"
      else if (/COLMAP|[Cc]olmap/) library = "colmap"
      else if (/[Oo]pen[Bb][Ll][Aa][Ss]|OpenBLAS/) library = "openblas"
      else if (/[Ss]uite[Ss]parse|SuiteSparse/) library = "suitesparse"
      else if (/nvtop|NVTOP/) library = "nvtop"
    }
    END { print library }
  ' "$script_file")
  
  echo "$context"
}

################################################################################
# DOCUMENTATION LOOKUP
################################################################################

find_flag_documentation() {
  local library_name="$1"
  local flag_name="$2"
  
  # Find most recent documentation file for this library
  local doc_files
  doc_files=$(find "$DOCS_FLAGS_DIR" -type f -iname "*${library_name}*CMAKE*FLAGS*.md" 2>/dev/null | sort -r)
  
  if [ -z "$doc_files" ]; then
    echo "NO_DOCS"
    return 1
  fi
  
  local latest_doc
  latest_doc=$(echo "$doc_files" | head -1)
  
  # Search for the flag in the documentation
  # Patterns to match:
  #   - ### `FLAG_NAME`
  #   - ### FLAG_NAME
  #   - -DFLAG_NAME=
  #   - option(FLAG_NAME
  if grep -qiP "(^###\s+\`?${flag_name}\`?|^###\s+${flag_name}|\-D${flag_name}=|option\(${flag_name})" "$latest_doc" 2>/dev/null; then
    echo "$latest_doc"
    return 0
  else
    echo "NOT_FOUND"
    return 1
  fi
}

################################################################################
# VALIDATION
################################################################################

validate_flags() {
  local cmake_commands_file="$1"
  local script_file="$2"
  
  log_info "Validating CMake flags against documentation..."
  echo ""
  
  local cmd_count=0
  local current_library=""
  local current_doc=""
  local line_num=""
  local cmake_cmd=""
  
  while IFS=: read -r line_num cmake_cmd; do
    ((cmd_count++)) || true
    
    # Detect library context
    current_library=$(detect_library_from_context "$script_file" "$line_num")
    
    if [ -n "$current_library" ]; then
      echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
      echo -e "${BLUE}Library: ${current_library^^} (line $line_num)${NC}"
      echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    else
      echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
      echo -e "${YELLOW}Library: UNKNOWN (line $line_num)${NC}"
      echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    fi
    
    # Extract flags from this cmake command
    local flags
    flags=$(extract_flags_from_cmake_command "$cmake_cmd")
    
    if [ -z "$flags" ]; then
      log_warning "No -D flags found in cmake command"
      echo ""
      continue
    fi
    
    # Validate each flag
    while IFS= read -r flag; do
      [ -z "$flag" ] && continue
      ((TOTAL_FLAGS_FOUND++)) || true
      
      if [ -n "$current_library" ]; then
        local doc_result
        doc_result=$(find_flag_documentation "$current_library" "$flag")
        
        case "$doc_result" in
          NO_DOCS)
            log_error "Flag: ${flag} - Documentation missing for ${current_library}"
            ((UNDOCUMENTED_LIBRARIES++)) || true
            ((INVALID_FLAGS++)) || true
            ;;
          NOT_FOUND)
            log_error "Flag: ${flag} - NOT documented in ${current_library} flags"
            ((INVALID_FLAGS++)) || true
            ;;
          *)
            log_success "Flag: ${flag} - Documented in ${doc_result##*/}"
            ((VALID_FLAGS++)) || true
            ;;
        esac
      else
        log_warning "Flag: ${flag} - Cannot validate (unknown library context)"
        ((INVALID_FLAGS++)) || true
      fi
    done <<< "$flags"
    
    echo ""
  done < "$cmake_commands_file"
}

################################################################################
# REPORT GENERATION
################################################################################

generate_report() {
  echo ""
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}         CMAKE FLAG VALIDATION REPORT${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "Script Analyzed: ${TARGET_SCRIPT}"
  echo "Validation Date: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""
  echo "STATISTICS:"
  echo "  CMake Commands Found: ${TOTAL_CMAKE_COMMANDS}"
  echo "  Total Flags Found:    ${TOTAL_FLAGS_FOUND}"
  echo "  Valid Flags:          ${VALID_FLAGS}"
  echo "  Invalid Flags:        ${INVALID_FLAGS}"
  echo "  Undocumented Libs:    ${UNDOCUMENTED_LIBRARIES}"
  echo ""
  
  local success_rate=0
  if [ "$TOTAL_FLAGS_FOUND" -gt 0 ]; then
    success_rate=$((VALID_FLAGS * 100 / TOTAL_FLAGS_FOUND))
  fi
  
  echo "SUCCESS RATE: ${success_rate}%"
  echo ""
  
  if [ "$INVALID_FLAGS" -eq 0 ] && [ "$UNDOCUMENTED_LIBRARIES" -eq 0 ]; then
    echo -e "${GREEN}✓ ALL FLAGS VALIDATED SUCCESSFULLY${NC}"
    echo ""
    return 0
  else
    echo -e "${RED}✗ VALIDATION FAILURES DETECTED${NC}"
    echo ""
    
    if [ "$UNDOCUMENTED_LIBRARIES" -gt 0 ]; then
      echo -e "${YELLOW}RECOMMENDATIONS:${NC}"
      echo "  1. Generate missing flag documentation using:"
      echo "     ./analyze-library.sh --library <name>"
      echo ""
    fi
    
    if [ "$INVALID_FLAGS" -gt 0 ]; then
      echo -e "${YELLOW}ACTIONS REQUIRED:${NC}"
      echo "  1. Review invalid flags listed above"
      echo "  2. Check docs/flags/*.md for correct flag names"
      echo "  3. Update build script with documented flags"
      echo "  4. Re-run validator to confirm"
      echo ""
    fi
    
    return 1
  fi
}

################################################################################
# MAIN
################################################################################

main() {
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --strict)
        STRICT_MODE=true
        shift
        ;;
      --report-only)
        REPORT_ONLY=true
        shift
        ;;
      --help|-h)
        print_usage
        exit 0
        ;;
      -*)
        log_error "Unknown option: $1"
        print_usage
        exit 1
        ;;
      *)
        if [ -z "$TARGET_SCRIPT" ]; then
          TARGET_SCRIPT="$1"
        else
          log_error "Multiple script files specified"
          print_usage
          exit 1
        fi
        shift
        ;;
    esac
  done
  
  # Validate inputs
  if [ -z "$TARGET_SCRIPT" ]; then
    log_error "No script file specified"
    print_usage
    exit 1
  fi
  
  if [ ! -f "$TARGET_SCRIPT" ]; then
    log_error "Script file not found: $TARGET_SCRIPT"
    exit 1
  fi
  
  if [ ! -d "$DOCS_FLAGS_DIR" ]; then
    log_error "Documentation directory not found: $DOCS_FLAGS_DIR"
    exit 1
  fi
  
  # Main workflow
  echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║     CMAKE FLAG VALIDATOR v1.0                      ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
  echo ""
  
  local cmake_commands_file
  local extraction_result
  extraction_result=$(extract_cmake_commands "$TARGET_SCRIPT")
  
  # Parse result: count|filepath
  TOTAL_CMAKE_COMMANDS=$(echo "$extraction_result" | cut -d'|' -f1)
  cmake_commands_file=$(echo "$extraction_result" | cut -d'|' -f2)
  
  if [ "$TOTAL_CMAKE_COMMANDS" -eq 0 ]; then
    log_warning "No cmake commands found in script"
    rm -f "$cmake_commands_file"
    exit 0
  fi
  
  if [ "$REPORT_ONLY" = true ]; then
    log_info "Report-only mode: Showing extracted flags without validation"
    echo ""
    cat "$cmake_commands_file"
    rm -f "$cmake_commands_file"
    exit 0
  fi
  
  validate_flags "$cmake_commands_file" "$TARGET_SCRIPT"
  
  local validation_result
  generate_report
  validation_result=$?
  
  # Cleanup
  rm -f "$cmake_commands_file"
  
  # Exit based on mode
  if [ "$STRICT_MODE" = true ]; then
    if [ "$validation_result" -ne 0 ]; then
      log_error "Validation failed in strict mode"
      exit 1
    fi
    
    if [ "$UNDOCUMENTED_LIBRARIES" -gt 0 ]; then
      log_error "Undocumented libraries found in strict mode"
      exit 2
    fi
  fi
  
  exit 0
}

main "$@"
