#!/bin/bash
################################################################################
# MANDATORY PRE-COMMIT VALIDATION ENFORCER
# Purpose: ENFORCE local validation before ANY commit attempt
# Usage: This script MUST be called by Cursor IDE agent BEFORE git commit
#
# This script:
#   1. Runs pre-commit hook locally
#   2. Runs comprehensive CI checks
#   3. Runs ShellCheck
#   4. Auto-fixes all issues iteratively
#   5. BLOCKS commit if validation fails after max retries
#
# Exit codes:
#   0 - All validation passed, commit can proceed
#   1 - Validation failed, commit BLOCKED
################################################################################

set -euo pipefail

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m'

# Get repository root
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# SC2015: Use explicit if-then-else instead of A && B || C
if [ -d "${SCRIPT_DIR}/../.." ]; then
  WORKSPACE_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
else
  WORKSPACE_ROOT=$(pwd)
fi

# Validators
PRE_COMMIT_HOOK="${WORKSPACE_ROOT}/.git/hooks/pre-commit"
PRE_COMMIT_HOOK_ALT="${WORKSPACE_ROOT}/scripts/hooks/pre-commit"
CI_CHECKS_RUNNER="${WORKSPACE_ROOT}/scripts/hooks/run_all_ci_checks.sh"
SHELLCHECK_AUTO_FIX="${WORKSPACE_ROOT}/scripts/helpers/auto_fix_shellcheck.sh"

# Configuration
MAX_RETRIES=5
RETRY_COUNT=0
VALIDATION_PASSED=false

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  MANDATORY PRE-COMMIT VALIDATION (ENFORCED BY CURSOR AGENT)   ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}[INFO]${NC} Repository: $(basename "${WORKSPACE_ROOT}") (${WORKSPACE_ROOT})"
echo -e "${BLUE}[INFO]${NC} This validation MUST pass before commit can proceed"
echo ""

################################################################################
# STEP 1: Run Pre-Commit Hook Locally
################################################################################

echo -e "${CYAN}╭────────────────────────────────────────────────────────────────╮${NC}"
echo -e "${CYAN}│  STEP 1: PRE-COMMIT HOOK VALIDATION                            │${NC}"
echo -e "${CYAN}╰────────────────────────────────────────────────────────────────╯${NC}"
echo ""

# Determine which pre-commit hook to use
PRE_COMMIT_SCRIPT=""
if [ -x "$PRE_COMMIT_HOOK" ]; then
  PRE_COMMIT_SCRIPT="$PRE_COMMIT_HOOK"
elif [ -x "$PRE_COMMIT_HOOK_ALT" ]; then
  PRE_COMMIT_SCRIPT="$PRE_COMMIT_HOOK_ALT"
else
  echo -e "${RED}[✗]${NC} Pre-commit hook not found or not executable"
  echo -e "${YELLOW}[ACTION]${NC} Install hook: ln -sf ../../scripts/hooks/pre-commit .git/hooks/pre-commit"
  exit 1
fi

echo -e "${BLUE}[→]${NC} Running pre-commit hook: ${PRE_COMMIT_SCRIPT}"
echo ""

# Run pre-commit hook with retry loop
HOOK_PASSED=false
while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$HOOK_PASSED" != true ]; do
  RETRY_COUNT=$((RETRY_COUNT + 1))
  
  if [ $RETRY_COUNT -gt 1 ]; then
    echo ""
    echo -e "${MAGENTA}[RETRY $RETRY_COUNT/$MAX_RETRIES]${NC} Re-running pre-commit hook after fixes..."
    echo ""
    
    # Re-stage any files that were modified
    STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
    MODIFIED_FILES=$(git diff --name-only 2>/dev/null || true)
    
    if [ -n "$MODIFIED_FILES" ]; then
      echo -e "${BLUE}[GIT]${NC} Re-staging fixed files..."
      for file in $MODIFIED_FILES; do
        if echo "$STAGED_FILES" | grep -q "^${file}$" || git diff --cached --name-only --diff-filter=ACM | grep -q "^${file}$" 2>/dev/null; then
          git add "$file" 2>/dev/null || true
        fi
      done
      echo ""
    fi
  fi
  
  # Run pre-commit hook
  if "$PRE_COMMIT_SCRIPT" 2>&1; then
    HOOK_PASSED=true
    echo ""
    echo -e "${GREEN}[✓]${NC} Pre-commit hook validation PASSED"
    echo ""
    break
  else
    HOOK_EXIT_CODE=$?
    echo ""
    echo -e "${YELLOW}[⚠]${NC} Pre-commit hook failed (exit code: $HOOK_EXIT_CODE)"
    echo -e "${YELLOW}[INFO]${NC} Auto-fixes should have been applied. Re-running validation..."
    echo ""
    
    # Check if files were modified (indicating auto-fixes)
    if ! git diff --quiet 2>/dev/null; then
      echo -e "${BLUE}[INFO]${NC} Files were modified by auto-fixes"
    fi
  fi
done

if [ "$HOOK_PASSED" != true ]; then
  echo -e "${RED}[✗]${NC} Pre-commit hook validation FAILED after $MAX_RETRIES attempts"
  echo ""
  VALIDATION_PASSED=false
else
  VALIDATION_PASSED=true
fi

RETRY_COUNT=0

################################################################################
# STEP 2: Run Comprehensive CI Checks (with Agent-Driven Error Fixing)
################################################################################

if [ "$VALIDATION_PASSED" = true ] && [ -x "$CI_CHECKS_RUNNER" ]; then
  echo -e "${CYAN}╭────────────────────────────────────────────────────────────────╮${NC}"
  echo -e "${CYAN}│  STEP 2: COMPREHENSIVE CI CHECKS                              │${NC}"
  echo -e "${CYAN}╰────────────────────────────────────────────────────────────────╯${NC}"
  echo ""
  echo -e "${BLUE}[→]${NC} Running all CI checks: ${CI_CHECKS_RUNNER}"
  echo -e "${BLUE}[INFO]${NC} Cursor AI agent will parse output and fix errors iteratively"
  echo ""
  
  CI_PASSED=false
  CI_OUTPUT_FILE="${WORKSPACE_ROOT}/.git/.ci-check-output-${RETRY_COUNT}.txt"
  
  while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$CI_PASSED" != true ]; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    CI_OUTPUT_FILE="${WORKSPACE_ROOT}/.git/.ci-check-output-${RETRY_COUNT}.txt"
    
    if [ $RETRY_COUNT -gt 1 ]; then
      echo ""
      echo -e "${MAGENTA}[RETRY $RETRY_COUNT/$MAX_RETRIES]${NC} Re-running CI checks after agent fixes..."
      echo ""
      
      # Re-stage fixed files
      MODIFIED_FILES=$(git diff --name-only 2>/dev/null || true)
      if [ -n "$MODIFIED_FILES" ]; then
        echo -e "${BLUE}[GIT]${NC} Re-staging files fixed by agent..."
        for file in $MODIFIED_FILES; do
          git add "$file" 2>/dev/null || true
        done
        echo ""
      fi
    fi
    
    # Run CI checks and capture ALL output for agent parsing
    echo -e "${BLUE}[RUNNING]${NC} CI checks (output saved for agent analysis)..."
    echo ""
    
    # Capture output to file for agent to parse
    if "$CI_CHECKS_RUNNER" > "$CI_OUTPUT_FILE" 2>&1; then
      CI_PASSED=true
      echo ""
      echo -e "${GREEN}[✓]${NC} All CI checks PASSED"
      echo ""
      rm -f "$CI_OUTPUT_FILE"
      break
    else
      CI_EXIT_CODE=$?
      echo ""
      echo -e "${YELLOW}[⚠]${NC} CI checks failed (exit code: $CI_EXIT_CODE)"
      echo ""
      echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
      echo -e "${CYAN}║  CI CHECK OUTPUT (FOR CURSOR AI AGENT TO PARSE AND FIX)      ║${NC}"
      echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
      echo ""
      # Display output for agent to see
      cat "$CI_OUTPUT_FILE"
      echo ""
      echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
      echo -e "${CYAN}║  AGENT ACTION REQUIRED: Parse errors above and fix code        ║${NC}"
      echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
      echo ""
      echo -e "${YELLOW}[AGENT INSTRUCTIONS]${NC}"
      echo "  1. Review the CI check output above"
      echo "  2. Identify all errors (file:line:error format)"
      echo "  3. Fix each error using code editing tools"
      echo "  4. After fixes, this script will re-run checks automatically"
      echo "  5. Process repeats until all checks pass or max retries reached"
      echo ""
      echo -e "${BLUE}[OUTPUT FILE]${NC} Full output saved to: ${CI_OUTPUT_FILE}"
      echo ""
      
      # Wait for agent to fix errors (agent will see this output and fix issues)
      # The agent should parse the output, fix errors, and the script will re-run
      if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
        echo -e "${BLUE}[→]${NC} Waiting for agent to fix errors... (iteration will continue after fixes)"
        echo ""
      fi
    fi
  done
  
  # Clean up output files
  rm -f "${WORKSPACE_ROOT}/.git/.ci-check-output-"*.txt 2>/dev/null || true
  
  if [ "$CI_PASSED" != true ]; then
    echo -e "${RED}[✗]${NC} CI checks FAILED after $MAX_RETRIES attempts"
    echo -e "${RED}[✗]${NC} Agent could not fix all errors automatically"
    echo ""
    VALIDATION_PASSED=false
  fi
  
  RETRY_COUNT=0
fi

################################################################################
# STEP 3: Run ShellCheck (with Agent-Driven Error Fixing)
################################################################################

if [ "$VALIDATION_PASSED" = true ] && command -v shellcheck >/dev/null 2>&1; then
  echo -e "${CYAN}╭────────────────────────────────────────────────────────────────╮${NC}"
  echo -e "${CYAN}│  STEP 3: SHELLCHECK VALIDATION                               │${NC}"
  echo -e "${CYAN}╰────────────────────────────────────────────────────────────────╯${NC}"
  echo ""
  
  # Get staged shell scripts
  STAGED_SH_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.sh$' || true)
  
  if [ -n "$STAGED_SH_FILES" ]; then
    echo -e "${BLUE}[→]${NC} Running ShellCheck on staged shell scripts..."
    echo -e "${BLUE}[INFO]${NC} Cursor AI agent will parse output and fix errors iteratively"
    echo ""
    
    SHELLCHECK_PASSED=false
    SHELLCHECK_OUTPUT_FILE="${WORKSPACE_ROOT}/.git/.shellcheck-output-${RETRY_COUNT}.txt"
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$SHELLCHECK_PASSED" != true ]; do
      RETRY_COUNT=$((RETRY_COUNT + 1))
      SHELLCHECK_OUTPUT_FILE="${WORKSPACE_ROOT}/.git/.shellcheck-output-${RETRY_COUNT}.txt"
      
      if [ $RETRY_COUNT -gt 1 ]; then
        echo ""
        echo -e "${MAGENTA}[RETRY $RETRY_COUNT/$MAX_RETRIES]${NC} Re-running ShellCheck after agent fixes..."
        echo ""
        
        # Re-stage fixed files
        MODIFIED_FILES=$(git diff --name-only 2>/dev/null || true)
        if [ -n "$MODIFIED_FILES" ]; then
          echo -e "${BLUE}[GIT]${NC} Re-staging files fixed by agent..."
          for file in $MODIFIED_FILES; do
            git add "$file" 2>/dev/null || true
          done
          echo ""
        fi
      fi
      
      # Run ShellCheck and capture output for agent parsing
      echo -e "${BLUE}[RUNNING]${NC} ShellCheck (output saved for agent analysis)..."
      echo ""
      
      SHELLCHECK_ERRORS_FOUND=false
      SHELLCHECK_OUTPUT=""
      
      for file in $STAGED_SH_FILES; do
        file_path="${WORKSPACE_ROOT}/${file}"
        if [ -f "$file_path" ]; then
          echo -e "${BLUE}[CHECKING]${NC} ${file}"
          
          # Run ShellCheck and capture output (only check for errors, not warnings)
          # SC1090 warnings are acceptable for intentional dynamic sources
          # Note: shellcheck_output is not local (we're in a loop, not a function)
          shellcheck_output=""
          if shellcheck_output=$(shellcheck --severity=error -f gcc "$file_path" 2>&1); then
            echo -e "${GREEN}  ✓${NC} No errors found"
          else
            SHELLCHECK_ERRORS_FOUND=true
            SHELLCHECK_OUTPUT+="${shellcheck_output}\n"
            echo -e "${YELLOW}  ⚠${NC} Errors found:"
            echo "$shellcheck_output" | head -10 | sed 's/^/    /'
          fi
        fi
      done
      
      # Save output to file for agent
      echo -e "$SHELLCHECK_OUTPUT" > "$SHELLCHECK_OUTPUT_FILE" 2>/dev/null || true
      
      if [ "$SHELLCHECK_ERRORS_FOUND" != true ]; then
        SHELLCHECK_PASSED=true
        echo ""
        echo -e "${GREEN}[✓]${NC} ShellCheck validation PASSED"
        echo ""
        rm -f "$SHELLCHECK_OUTPUT_FILE"
        break
      else
        echo ""
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║  SHELLCHECK OUTPUT (FOR CURSOR AI AGENT TO PARSE AND FIX)    ║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "$SHELLCHECK_OUTPUT"
        echo ""
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║  AGENT ACTION REQUIRED: Parse errors above and fix code        ║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}[AGENT INSTRUCTIONS]${NC}"
        echo "  1. Review ShellCheck output above (format: file:line:column:code:message)"
        echo "  2. Fix each error using code editing tools"
        echo "  3. Common fixes:"
        echo "     - SC2155: Declare and assign separately"
        echo "     - SC1090: Add shellcheck disable for dynamic source"
        echo "     - SC2120: Add comment for functions using \$@"
        echo "     - D3 violations: Replace echo | grep with here-strings"
        echo "  4. After fixes, this script will re-run ShellCheck automatically"
        echo ""
        echo -e "${BLUE}[OUTPUT FILE]${NC} Full output saved to: ${SHELLCHECK_OUTPUT_FILE}"
        echo ""
        
        # Try auto-fix first (some issues can be auto-fixed)
        if [ -x "$SHELLCHECK_AUTO_FIX" ]; then
          echo -e "${BLUE}[AUTO-FIX]${NC} Attempting automatic fixes..."
          for file in $STAGED_SH_FILES; do
            file_path="${WORKSPACE_ROOT}/${file}"
            if [ -f "$file_path" ]; then
              "$SHELLCHECK_AUTO_FIX" "$file_path" 2>&1 || true
            fi
          done
          echo ""
        fi
        
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
          echo -e "${BLUE}[→]${NC} Waiting for agent to fix remaining errors... (iteration will continue after fixes)"
          echo ""
        fi
      fi
    done
    
    # Clean up output files and backup files after successful validation
    rm -f "${WORKSPACE_ROOT}/.git/.shellcheck-output-"*.txt 2>/dev/null || true
    
    # Clean up any backup files created by auto-fix scripts
    if [ "$SHELLCHECK_PASSED" = true ]; then
      find "${WORKSPACE_ROOT}" -maxdepth 3 -name "*.backup.*" -type f ! -path "${WORKSPACE_ROOT}/.git/*" -delete 2>/dev/null || true
    fi
    
    if [ "$SHELLCHECK_PASSED" != true ]; then
      echo -e "${RED}[✗]${NC} ShellCheck validation FAILED after $MAX_RETRIES attempts"
      echo -e "${RED}[✗]${NC} Agent could not fix all errors automatically"
      echo ""
      VALIDATION_PASSED=false
    fi
    
    RETRY_COUNT=0
  else
    echo -e "${BLUE}[INFO]${NC} No staged shell scripts found, skipping ShellCheck"
    echo ""
  fi
fi

################################################################################
# FINAL VALIDATION RESULT
################################################################################

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"

if [ "$VALIDATION_PASSED" = true ]; then
  echo -e "${CYAN}║${GREEN}  ✓ ALL VALIDATIONS PASSED - COMMIT CAN PROCEED              ${CYAN}║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${GREEN}[SUCCESS]${NC} All pre-commit validations passed"
  echo ""
  echo -e "${BLUE}[SUMMARY]${NC}"
  echo "  - Pre-commit hook: PASSED"
  if [ -x "$CI_CHECKS_RUNNER" ]; then
    echo "  - CI checks: PASSED"
  fi
  if command -v shellcheck >/dev/null 2>&1; then
    echo "  - ShellCheck: PASSED"
  fi
  echo "  - Ready to commit: YES"
  echo ""
  exit 0
else
  echo -e "${CYAN}║${RED}  ✗ VALIDATION FAILED - COMMIT BLOCKED                        ${CYAN}║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${RED}[BLOCKED]${NC} Commit is BLOCKED until all validations pass"
  echo ""
  echo -e "${YELLOW}[ACTION REQUIRED]${NC}"
  echo "  1. Review validation errors above"
  echo "  2. Fix remaining issues manually (if auto-fix couldn't resolve)"
  echo "  3. Re-run validation: ${0}"
  echo "  4. Only then: git commit"
  echo ""
  echo -e "${YELLOW}[TO BYPASS]${NC} (NOT RECOMMENDED - violates code quality standards):"
  echo "  git commit --no-verify"
  echo ""
  exit 1
fi

