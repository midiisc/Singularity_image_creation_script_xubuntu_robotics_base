#!/bin/bash
################################################################################
# COMPREHENSIVE CI CHECK RUNNER
# Purpose: Run all CI checks locally before commit/push
# Features:
#   - Runs all GitHub Actions checks locally
#   - Auto-fixes fixable issues
#   - Extracts error patterns for prompt enhancement
#   - Updates prompts before commit
#   - Fully automated retry loop
################################################################################

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Build scripts to check
BUILD_SCRIPTS=(
  "xubuntu_robotics_base_post_ULTRA_CLEANED.sh"
  "build_xubuntu_robotics_base.sh"
)

# Check results
declare -A CHECK_RESULTS
declare -A CHECK_ERRORS
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     COMPREHENSIVE CI VALIDATION - ALL CHECKS                   ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

################################################################################
# CHECK 1: Unsafe Pipe Patterns (echo | grep)
################################################################################

check_pipe_patterns() {
  local check_name="check-pipe-patterns"
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  
  echo -e "${BLUE}[CHECK]${NC} Unsafe pipe patterns (echo | grep)..."
  
  local found_patterns=false
  local fixes_applied=0
  
  for script in "${BUILD_SCRIPTS[@]}"; do
    local script_path="${REPO_ROOT}/${script}"
    if [ ! -f "$script_path" ]; then
      continue
    fi
    
    # Find all echo | grep patterns
    while IFS= read -r line_info; do
      if [ -n "$line_info" ]; then
        found_patterns=true
        local line_num=$(echo "$line_info" | cut -d: -f1)
        local line_content=$(echo "$line_info" | cut -d: -f2-)
        
        echo -e "${YELLOW}  →${NC} Found at line $line_num: ${line_content:0:60}..."
        
        # Auto-fix: Replace echo | grep with here-string
        # Extract variable name and pattern
        if echo "$line_content" | grep -qE 'echo\s+"\$\{([^}]+)\}"\s+\|\s+grep'; then
          local var_name=$(echo "$line_content" | sed -nE 's/.*echo\s+"\$\{([^}]+)\}".*/\1/p')
          local grep_pattern=$(echo "$line_content" | sed -nE 's/.*grep\s+(-[a-z]*\s+)?["'\'']?([^"'\'']+)["'\'']?.*/\2/p')
          
          # Create fixed version
          local fixed_line=$(echo "$line_content" | sed -E "s|echo\s+\"\$\{${var_name}\}\"\s+\|\s+grep|grep <<< \"\${${var_name}}\"|g")
          
          # Apply fix using sed
          sed -i "${line_num}s|.*|${fixed_line}|" "$script_path"
          fixes_applied=$((fixes_applied + 1))
          echo -e "${GREEN}    ✓${NC} Fixed: Replaced with here-string"
        fi
      fi
    done < <(grep -n 'echo.*|.*grep' "$script_path" 2>/dev/null || true)
  done
  
  if [ "$found_patterns" = true ] && [ $fixes_applied -gt 0 ]; then
    echo -e "${GREEN}[✓]${NC} Auto-fixed $fixes_applied unsafe pipe patterns"
    CHECK_RESULTS[$check_name]="FIXED"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    return 0
  elif [ "$found_patterns" = true ]; then
    echo -e "${RED}[✗]${NC} Found unsafe pipe patterns (could not auto-fix)"
    CHECK_RESULTS[$check_name]="FAILED"
    CHECK_ERRORS[$check_name]="Unsafe echo | grep patterns found"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    return 1
  else
    echo -e "${GREEN}[✓]${NC} No unsafe pipe patterns found"
    CHECK_RESULTS[$check_name]="PASSED"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    return 0
  fi
}

################################################################################
# CHECK 2: CMake Flag Validation
################################################################################

check_cmake_flags() {
  local check_name="validate-cmake-flags"
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  
  echo -e "${BLUE}[CHECK]${NC} CMake flag validation..."
  
  local cmake_validator="${REPO_ROOT}/scripts/helpers/validate_cmake_flags.sh"
  
  if [ ! -x "$cmake_validator" ]; then
    echo -e "${YELLOW}[⚠]${NC} CMake validator not found, skipping..."
    CHECK_RESULTS[$check_name]="SKIPPED"
    return 0
  fi
  
  local validation_failed=false
  for script in "${BUILD_SCRIPTS[@]}"; do
    local script_path="${REPO_ROOT}/${script}"
    if [ ! -f "$script_path" ]; then
      continue
    fi
    
    if ! "$cmake_validator" "$script_path" --report-only 2>&1; then
      validation_failed=true
    fi
  done
  
  if [ "$validation_failed" = true ]; then
    echo -e "${RED}[✗]${NC} CMake flag validation failed"
    CHECK_RESULTS[$check_name]="FAILED"
    CHECK_ERRORS[$check_name]="Invalid or undocumented CMake flags detected"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    return 1
  else
    echo -e "${GREEN}[✓]${NC} CMake flag validation passed"
    CHECK_RESULTS[$check_name]="PASSED"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    return 0
  fi
}

################################################################################
# CHECK 3: Multi-Phase Logic Documentation
################################################################################

check_multi_phase_docs() {
  local check_name="check-multi-phase-docs"
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  
  echo -e "${BLUE}[CHECK]${NC} Multi-phase logic documentation..."
  
  local complex_blocks=0
  local phase_markers=0
  
  for script in "${BUILD_SCRIPTS[@]}"; do
    local script_path="${REPO_ROOT}/${script}"
    if [ ! -f "$script_path" ]; then
      continue
    fi
    
    complex_blocks=$((complex_blocks + $(grep -c "for candidate in" "$script_path" 2>/dev/null || echo "0")))
    phase_markers=$((phase_markers + $(grep -c "# Phase [0-9]:" "$script_path" 2>/dev/null || echo "0")))
  done
  
  echo "  Found $complex_blocks complex blocks, $phase_markers phase markers"
  
  if [ "$complex_blocks" -gt 0 ] && [ "$phase_markers" -eq 0 ]; then
    echo -e "${YELLOW}[⚠]${NC} Consider adding phase markers to complex detection logic"
    CHECK_RESULTS[$check_name]="WARNING"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    return 0
  else
    echo -e "${GREEN}[✓]${NC} Multi-phase logic appears documented"
    CHECK_RESULTS[$check_name]="PASSED"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    return 0
  fi
}

################################################################################
# CHECK 4: TBB Verification Blocks
################################################################################

check_tbb_verification() {
  local check_name="check-tbb-verification"
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  
  echo -e "${BLUE}[CHECK]${NC} TBB verification blocks..."
  
  local main_script="${REPO_ROOT}/xubuntu_robotics_base_post_ULTRA_CLEANED.sh"
  
  if [ ! -f "$main_script" ]; then
    echo -e "${YELLOW}[⚠]${NC} Main script not found, skipping..."
    CHECK_RESULTS[$check_name]="SKIPPED"
    return 0
  fi
  
  local missing_verifications=()
  
  if ! grep -q "Verifying TBB configuration for Ceres" "$main_script"; then
    missing_verifications+=("Ceres")
  fi
  if ! grep -q "Verifying TBB configuration for g2o" "$main_script"; then
    missing_verifications+=("g2o")
  fi
  if ! grep -q "Verifying TBB configuration for GTSAM" "$main_script"; then
    missing_verifications+=("GTSAM")
  fi
  
  if [ ${#missing_verifications[@]} -gt 0 ]; then
    echo -e "${RED}[✗]${NC} Missing TBB verification for: ${missing_verifications[*]}"
    CHECK_RESULTS[$check_name]="FAILED"
    CHECK_ERRORS[$check_name]="Missing TBB verification blocks: ${missing_verifications[*]}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    return 1
  else
    echo -e "${GREEN}[✓]${NC} TBB verification blocks found for all HPC libraries"
    CHECK_RESULTS[$check_name]="PASSED"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    return 0
  fi
}

################################################################################
# CHECK 5: Heredoc Syntax
################################################################################

check_heredoc_syntax() {
  local check_name="check-heredoc-syntax"
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  
  echo -e "${BLUE}[CHECK]${NC} Heredoc syntax..."
  
  local unquoted_count=0
  
  for script in "${BUILD_SCRIPTS[@]}"; do
    local script_path="${REPO_ROOT}/${script}"
    if [ ! -f "$script_path" ]; then
      continue
    fi
    
    unquoted_count=$((unquoted_count + $(grep -c "<<EOF" "$script_path" 2>/dev/null | grep -v "<<'EOF'" | grep -v "<<\"EOF\"" | wc -l || echo "0")))
  done
  
  if [ "$unquoted_count" -gt 0 ]; then
    echo -e "${YELLOW}[⚠]${NC} Found $unquoted_count potentially unquoted EOF delimiters"
    echo "  Consider using <<'EOF' for literal heredocs"
    CHECK_RESULTS[$check_name]="WARNING"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    return 0
  else
    echo -e "${GREEN}[✓]${NC} Heredoc syntax appears correct"
    CHECK_RESULTS[$check_name]="PASSED"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    return 0
  fi
}

################################################################################
# CHECK 6: Bash Compatibility
################################################################################

check_bash_compatibility() {
  local check_name="check-bash-compatibility"
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  
  echo -e "${BLUE}[CHECK]${NC} Bash compatibility (Bash 4+ features)..."
  
  local found_incompatible=false
  local fixes_applied=0
  
  for script in "${BUILD_SCRIPTS[@]}"; do
    local script_path="${REPO_ROOT}/${script}"
    if [ ! -f "$script_path" ]; then
      continue
    fi
    
    # Check for ${var^^} (uppercase)
    while IFS= read -r line_info; do
      if [ -n "$line_info" ]; then
        found_incompatible=true
        local line_num=$(echo "$line_info" | cut -d: -f1)
        local line_content=$(echo "$line_info" | cut -d: -f2-)
        
        echo -e "${YELLOW}  →${NC} Found Bash 4+ feature at line $line_num"
        
        # Auto-fix: Replace ${var^^} with tr
        if echo "$line_content" | grep -qE '\$\{[^}]+\^\^'; then
          local var_name=$(echo "$line_content" | sed -nE 's/.*\$\{([^}]+)\^\^\}.*/\1/p')
          local fixed_line=$(echo "$line_content" | sed -E "s|\$\{${var_name}\^\^\}|\$(echo \"\${${var_name}}\" | tr '[:lower:]' '[:upper:]')|g")
          sed -i "${line_num}s|.*|${fixed_line}|" "$script_path"
          fixes_applied=$((fixes_applied + 1))
          echo -e "${GREEN}    ✓${NC} Fixed: Replaced with tr command"
        fi
        
        # Auto-fix: Replace ${var,,} with tr
        if echo "$line_content" | grep -qE '\$\{[^}]+,,'; then
          local var_name=$(echo "$line_content" | sed -nE 's/.*\$\{([^}]+),,\}.*/\1/p')
          local fixed_line=$(echo "$line_content" | sed -E "s|\$\{${var_name},,\}|\$(echo \"\${${var_name}}\" | tr '[:upper:]' '[:lower:]')|g")
          sed -i "${line_num}s|.*|${fixed_line}|" "$script_path"
          fixes_applied=$((fixes_applied + 1))
          echo -e "${GREEN}    ✓${NC} Fixed: Replaced with tr command"
        fi
      fi
    done < <(grep -nE '\$\{[^}]+\^\^|\$\{[^}]+,,' "$script_path" 2>/dev/null || true)
  done
  
  if [ "$found_incompatible" = true ] && [ $fixes_applied -gt 0 ]; then
    echo -e "${GREEN}[✓]${NC} Auto-fixed $fixes_applied Bash compatibility issues"
    CHECK_RESULTS[$check_name]="FIXED"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    return 0
  elif [ "$found_incompatible" = true ]; then
    echo -e "${RED}[✗]${NC} Found Bash 4+ features (could not auto-fix)"
    CHECK_RESULTS[$check_name]="FAILED"
    CHECK_ERRORS[$check_name]="Bash 4+ features detected without version checks"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    return 1
  else
    echo -e "${GREEN}[✓]${NC} No Bash 4+ specific features detected"
    CHECK_RESULTS[$check_name]="PASSED"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    return 0
  fi
}

################################################################################
# CHECK 7: ShellCheck Linting
################################################################################

check_shellcheck() {
  local check_name="shellcheck"
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  
  echo -e "${BLUE}[CHECK]${NC} ShellCheck linting..."
  
  if ! command -v shellcheck &> /dev/null; then
    echo -e "${YELLOW}[⚠]${NC} ShellCheck not installed, skipping..."
    echo "  Install with: sudo apt install shellcheck"
    CHECK_RESULTS[$check_name]="SKIPPED"
    return 0
  fi
  
  local shellcheck_failed=false
  local shellcheck_errors=""
  
  for script in "${BUILD_SCRIPTS[@]}"; do
    local script_path="${REPO_ROOT}/${script}"
    if [ ! -f "$script_path" ]; then
      continue
    fi
    
    if ! shellcheck_output=$(shellcheck -f gcc "$script_path" 2>&1); then
      shellcheck_failed=true
      shellcheck_errors+="$shellcheck_output\n"
    fi
  done
  
  if [ "$shellcheck_failed" = true ]; then
    echo -e "${RED}[✗]${NC} ShellCheck found issues:"
    echo -e "$shellcheck_errors" | head -20
    CHECK_RESULTS[$check_name]="FAILED"
    CHECK_ERRORS[$check_name]="ShellCheck linting errors found"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    return 1
  else
    echo -e "${GREEN}[✓]${NC} ShellCheck passed"
    CHECK_RESULTS[$check_name]="PASSED"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    return 0
  fi
}

################################################################################
# MAIN EXECUTION
################################################################################

main() {
  echo "Running all CI checks..."
  echo ""
  
  # Run all checks
  check_pipe_patterns
  check_cmake_flags
  check_multi_phase_docs
  check_tbb_verification
  check_heredoc_syntax
  check_bash_compatibility
  check_shellcheck
  
  # Summary
  echo ""
  echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║     VALIDATION SUMMARY                                           ║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo "Total checks: $TOTAL_CHECKS"
  echo -e "Passed: ${GREEN}$PASSED_CHECKS${NC}"
  echo -e "Failed: ${RED}$FAILED_CHECKS${NC}"
  echo ""
  
  # Print failed checks
  if [ $FAILED_CHECKS -gt 0 ]; then
    echo -e "${RED}Failed checks:${NC}"
    for check in "${!CHECK_RESULTS[@]}"; do
      if [ "${CHECK_RESULTS[$check]}" = "FAILED" ]; then
        echo -e "  ${RED}✗${NC} $check: ${CHECK_ERRORS[$check]}"
      fi
    done
    echo ""
    
    # Export results as JSON for pattern extraction
    if [ -n "${EXPORT_JSON:-}" ]; then
      {
        echo "{"
        echo "  \"results\": {"
        local first=true
        for check in "${!CHECK_RESULTS[@]}"; do
          [ "$first" = false ] && echo ","
          first=false
          echo -n "    \"$check\": \"${CHECK_RESULTS[$check]}\""
        done
        echo ""
        echo "  },"
        echo "  \"errors\": {"
        first=true
        for check in "${!CHECK_ERRORS[@]}"; do
          [ "$first" = false ] && echo ","
          first=false
          local error_msg=$(echo "${CHECK_ERRORS[$check]}" | sed 's/"/\\"/g')
          echo -n "    \"$check\": \"$error_msg\""
        done
        echo ""
        echo "  }"
        echo "}"
      } > "${EXPORT_JSON}"
    fi
    
    return 1
  fi
  
  echo -e "${GREEN}[✓]${NC} All checks passed!"
  return 0
}

# Run main
main "$@"

