#!/bin/bash
################################################################################
# SED PATTERN VALIDATOR
# Purpose: Detect malformed sed bracket expressions and missing error fallbacks
# Implements: prompts/Code_check_prompt_manual.txt (D4)
# 
# Detects:
#   1. Malformed bracket classes: sed 's/[[' pattern
#   2. Missing error fallbacks: $(sed ...) without || echo ""
#
# Exit codes:
#   0 - All checks passed
#   1 - Validation errors found
################################################################################

set -euo pipefail

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Script to validate
SCRIPT_FILE="${1:-}"
STRICT_MODE="${2:---strict}"

if [ -z "$SCRIPT_FILE" ]; then
  echo -e "${RED}[✗]${NC} Usage: $0 <script-file> [--strict|--warn]"
  exit 1
fi

if [ ! -f "$SCRIPT_FILE" ]; then
  echo -e "${RED}[✗]${NC} File not found: $SCRIPT_FILE"
  exit 1
fi

echo -e "${BLUE}[→]${NC} Validating sed patterns in: ${SCRIPT_FILE##*/}"
echo ""

ERRORS_FOUND=0
WARNINGS_FOUND=0

################################################################################
# CHECK 1: Detect malformed sed bracket classes
################################################################################

echo -e "${BLUE}[CHECK 1]${NC} Scanning for malformed sed bracket classes..."

# Pattern: sed 's/[[...' (double opening bracket is malformed)
# Exclude: sed 's/[[:space:]]' (POSIX character classes are valid)
MALFORMED_PATTERNS=$(grep -nE "sed 's/\[\[" "$SCRIPT_FILE" | grep -v '\[:' || true)

if [ -n "$MALFORMED_PATTERNS" ]; then
  ERRORS_FOUND=$((ERRORS_FOUND + 1))
  echo -e "${RED}[✗]${NC} CRITICAL: Malformed sed bracket expressions detected!"
  echo ""
  echo -e "${YELLOW}ISSUE:${NC} Found 'sed s/[[...' patterns (invalid bracket class)"
  echo -e "${YELLOW}FIX:${NC} Use 'sed s/[][]...' to match literal [ or ]"
  echo ""
  echo -e "${YELLOW}AFFECTED LINES:${NC}"
  echo "$MALFORMED_PATTERNS" | sed 's/^/  /'
  echo ""
  echo -e "${YELLOW}EXPLANATION:${NC}"
  echo "  - WRONG: sed 's/[[\/&]/\\&/g'  # Malformed bracket class"
  echo "  - RIGHT: sed 's/[][\\\/&]/\\&/g'  # Correct: [][] matches [ or ]"
  echo ""
else
  echo -e "${GREEN}[✓]${NC} No malformed bracket expressions found"
fi

################################################################################
# CHECK 2: Detect command substitutions with sed lacking error fallbacks
################################################################################

echo -e "${BLUE}[CHECK 2]${NC} Checking for sed without error fallbacks..."

# Find command substitutions containing sed
CMD_SUBS_WITH_SED=$(grep -nE '\$\([^)]*sed[^)]*\)' "$SCRIPT_FILE" || true)

if [ -n "$CMD_SUBS_WITH_SED" ]; then
  # Filter out lines that have the error fallback
  MISSING_FALLBACK=$(echo "$CMD_SUBS_WITH_SED" | grep -vE '\|\| echo ""|\|\| true|\|\| return' || true)
  
  if [ -n "$MISSING_FALLBACK" ]; then
    # Additional check: exclude simple sed operations that don't need fallbacks
    # (e.g., sed 's|http://||' in middle of pipeline)
    CRITICAL_MISSING=$(echo "$MISSING_FALLBACK" | grep -E 'sed.*\)(\s*$|[^|])' || true)
    
    if [ -n "$CRITICAL_MISSING" ]; then
      WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
      echo -e "${YELLOW}[⚠]${NC} WARNING: Command substitutions with sed lack error fallbacks"
      echo ""
      echo -e "${YELLOW}ISSUE:${NC} When 'set -u' is active, sed failures leave variables unset"
      echo -e "${YELLOW}FIX:${NC} Add '|| echo \"\"' to prevent unbound variable errors"
      echo ""
      echo -e "${YELLOW}AFFECTED LINES:${NC}"
      echo "$CRITICAL_MISSING" | head -10 | sed 's/^/  /'
      # Quote command substitution to prevent word splitting (SC2046)
      if [ "$(echo "$CRITICAL_MISSING" | wc -l)" -gt 10 ]; then
        echo "  ... ($(echo "$CRITICAL_MISSING" | wc -l) total instances)"
      fi
      echo ""
      echo -e "${YELLOW}EXAMPLE FIX:${NC}"
      echo "  - UNSAFE: var=\"\$(echo \"\${url}\" | sed 's/http/https/')\""
      echo "  - SAFE:   var=\"\$(echo \"\${url}\" | sed 's/http/https/' || echo \"\")\""
      echo ""
    else
      echo -e "${GREEN}[✓]${NC} All sed patterns have appropriate error handling"
    fi
  else
    echo -e "${GREEN}[✓]${NC} All command substitutions with sed have error fallbacks"
  fi
else
  echo -e "${GREEN}[✓]${NC} No command substitutions with sed found"
fi

################################################################################
# CHECK 3: Validate bracket class consistency
################################################################################

echo -e "${BLUE}[CHECK 3]${NC} Checking for inconsistent sed escaping patterns..."

# Find all sed escaping patterns (excluding POSIX classes)
ESCAPING_PATTERNS=$(grep -nE "sed 's/\[.*\]/\\\\&/g'" "$SCRIPT_FILE" | grep -v '\[:' || true)

if [ -n "$ESCAPING_PATTERNS" ]; then
  # Extract unique patterns
  UNIQUE_PATTERNS=$(echo "$ESCAPING_PATTERNS" | sed -E "s/.*sed 's\/([^']+)'*/\1/" | sort -u)
  PATTERN_COUNT=$(echo "$UNIQUE_PATTERNS" | wc -l)
  
  if [ "$PATTERN_COUNT" -gt 3 ]; then
    WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
    echo -e "${YELLOW}[⚠]${NC} WARNING: Multiple different escaping patterns detected"
    echo ""
    echo -e "${YELLOW}ISSUE:${NC} Found $PATTERN_COUNT different sed escaping patterns"
    echo -e "${YELLOW}RECOMMENDATION:${NC} Standardize on a single pattern for consistency"
    echo ""
    echo -e "${YELLOW}PATTERNS FOUND:${NC}"
    echo "$UNIQUE_PATTERNS" | sed 's/^/  /'
    echo ""
  else
    echo -e "${GREEN}[✓]${NC} Sed escaping patterns are consistent"
  fi
else
  echo -e "${GREEN}[✓]${NC} No sed escaping patterns found"
fi

################################################################################
# FINAL VERDICT
################################################################################

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ $ERRORS_FOUND -gt 0 ]; then
  echo -e "${RED}[✗] VALIDATION FAILED: $ERRORS_FOUND critical error(s) found${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "${YELLOW}REQUIRED ACTIONS:${NC}"
  echo "  1. Fix malformed sed bracket expressions"
  echo "  2. Use [][] to match literal [ or ] characters"
  echo "  3. Add || echo \"\" fallbacks to command substitutions"
  echo ""
  echo -e "${YELLOW}REFERENCE:${NC}"
  echo "  See: prompts/Code_check_prompt_manual.txt (Section D4)"
  echo ""
  exit 1
elif [ $WARNINGS_FOUND -gt 0 ]; then
  if [ "$STRICT_MODE" = "--strict" ]; then
    echo -e "${YELLOW}[⚠] VALIDATION WARNING: $WARNINGS_FOUND warning(s) found${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}NOTE:${NC} Warnings should be addressed for best practices"
    echo -e "${YELLOW}TO BYPASS:${NC} Use --warn mode instead of --strict"
    echo ""
    exit 1
  else
    echo -e "${GREEN}[✓] VALIDATION PASSED (with $WARNINGS_FOUND warning(s))${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    exit 0
  fi
else
  echo -e "${GREEN}[✓] VALIDATION PASSED: All sed patterns are correct${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  exit 0
fi
