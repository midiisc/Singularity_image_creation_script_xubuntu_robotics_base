#!/bin/bash
################################################################################
# AUTO-FIX SED PATTERNS
# Purpose: Automatically fix malformed sed patterns and missing error fallbacks
# Implements: prompts/Code_check_prompt_manual.txt (Master entry point - loads all parts sequentially)
# Section D4 in PART2 (D. Quoting & Expansion Safety) - Auto-fix mode
#
# Fixes:
#   1. Malformed bracket classes: sed 's/[[...' → sed 's/[][...'
#   2. Missing error fallbacks: $(sed ...) → $(sed ... || echo "")
#
# Exit codes:
#   0 - Fixes applied successfully
#   1 - No fixes needed
#   2 - Errors during fix process
################################################################################

set -euo pipefail

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

SCRIPT_FILE="${1:-}"
DRY_RUN="${2:-}"

if [ -z "$SCRIPT_FILE" ]; then
  echo -e "${RED}[✗]${NC} Usage: $0 <script-file> [--dry-run]"
  exit 1
fi

if [ ! -f "$SCRIPT_FILE" ]; then
  echo -e "${RED}[✗]${NC} File not found: $SCRIPT_FILE"
  exit 1
fi

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              AUTO-FIX: SED PATTERN CORRECTIONS                 ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}[→]${NC} Target file: ${SCRIPT_FILE}"
echo ""

# Create backup
BACKUP_FILE="${SCRIPT_FILE}.backup.$(date +%s)"
if [ "$DRY_RUN" != "--dry-run" ]; then
  cp "$SCRIPT_FILE" "$BACKUP_FILE"
  echo -e "${GREEN}[✓]${NC} Backup created: ${BACKUP_FILE##*/}"
else
  echo -e "${YELLOW}[DRY-RUN]${NC} No backup created (dry-run mode)"
fi
echo ""

FIXES_APPLIED=0

################################################################################
# FIX 1: Malformed sed bracket classes using Perl
################################################################################

echo -e "${BLUE}[FIX 1]${NC} Correcting malformed sed bracket classes..."
echo ""

# Count malformed patterns (excluding POSIX classes like [[:space:]])
MALFORMED_COUNT=$(grep -E "sed 's/\[\[" "$SCRIPT_FILE" | grep -v '\[:' | wc -l || echo "0")

if [ "$MALFORMED_COUNT" -gt 0 ]; then
  echo -e "${YELLOW}[FOUND]${NC} $MALFORMED_COUNT malformed sed bracket expression(s)"
  echo ""
  
  # Show what will be fixed
  echo -e "${BLUE}[PREVIEW]${NC} Lines to be fixed:"
  grep -nE "sed 's/\[\[" "$SCRIPT_FILE" | grep -v '\[:' | head -5 | sed 's/^/  /' || true
  if [ "$MALFORMED_COUNT" -gt 5 ]; then
    echo "  ... ($(($MALFORMED_COUNT - 5)) more)"
  fi
  echo ""
  
  if [ "$DRY_RUN" != "--dry-run" ]; then
    # Use Perl for more reliable pattern replacement
    # Replace sed 's/[[.../' with sed 's/[][].../'
    perl -i -pe "s/(sed\\s+'s\\/)\[\[/\$1\[\]\[/g" "$SCRIPT_FILE"
    
    # Also handle double-quoted strings
    perl -i -pe 's/(sed\s+"s\/)\[\[/$1\[\]\[/g' "$SCRIPT_FILE"
    
    FIXES_APPLIED=$((FIXES_APPLIED + MALFORMED_COUNT))
    echo -e "${GREEN}[✓]${NC} Fixed $MALFORMED_COUNT malformed bracket class(es)"
  else
    echo -e "${YELLOW}[DRY-RUN]${NC} Would fix $MALFORMED_COUNT pattern(s)"
  fi
else
  echo -e "${GREEN}[✓]${NC} No malformed bracket classes found"
fi
echo ""

################################################################################
# FIX 2: Missing error fallbacks using Perl
################################################################################

echo -e "${BLUE}[FIX 2]${NC} Adding error fallbacks to command substitutions..."
echo ""

# Find command substitutions with sed that lack error handling
# More precise pattern matching using multiple greps
MISSING_FALLBACKS=$(grep -nE '\$\([^)]*sed[^)]*\)' "$SCRIPT_FILE" | \
  grep -vE '\|\|\s*(echo|true|return)' | \
  wc -l || echo "0")

if [ "$MISSING_FALLBACKS" -gt 0 ]; then
  echo -e "${YELLOW}[FOUND]${NC} $MISSING_FALLBACKS command substitution(s) lacking error fallbacks"
  echo ""
  
  echo -e "${BLUE}[PREVIEW]${NC} Lines to be fixed:"
  grep -nE '\$\([^)]*sed[^)]*\)' "$SCRIPT_FILE" | \
    grep -vE '\|\|\s*(echo|true|return)' | \
    head -5 | sed 's/^/  /' || true
  if [ "$MISSING_FALLBACKS" -gt 5 ]; then
    echo "  ... ($(($MISSING_FALLBACKS - 5)) more)"
  fi
  echo ""
  
  if [ "$DRY_RUN" != "--dry-run" ]; then
    # Use Perl for precise pattern matching
    # Match $(...sed...) and add || echo "" before closing )
    # Pattern: $(command with sed) → $(command with sed || echo "")
    
    # Handle cases where ) is at end of line
    perl -i -pe 's/\$\(([^)]*sed[^)]*?)\)(\s*)$/\$(\1 || echo "")\2/g unless /\|\|\s*(echo|true|return)/' "$SCRIPT_FILE"
    
    # Handle cases where ) is followed by other characters (quotes, semicolons, etc)
    perl -i -pe 's/\$\(([^)]*sed[^)]*?)\)(\s*["\047;])$/\$(\1 || echo "")\2/g unless /\|\|\s*(echo|true|return)/' "$SCRIPT_FILE"
    
    FIXES_APPLIED=$((FIXES_APPLIED + MISSING_FALLBACKS))
    echo -e "${GREEN}[✓]${NC} Added $MISSING_FALLBACKS error fallback(s)"
  else
    echo -e "${YELLOW}[DRY-RUN]${NC} Would add $MISSING_FALLBACKS fallback(s)"
  fi
else
  echo -e "${GREEN}[✓]${NC} All command substitutions have error fallbacks"
fi
echo ""

################################################################################
# SUMMARY
################################################################################

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"

if [ "$DRY_RUN" = "--dry-run" ]; then
  echo -e "${CYAN}║${YELLOW}  DRY-RUN COMPLETE: No changes made                            ${CYAN}║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${YELLOW}[DRY-RUN SUMMARY]${NC}"
  echo "  Would fix: $MALFORMED_COUNT malformed bracket class(es)"
  echo "  Would add: $MISSING_FALLBACKS error fallback(s)"
  echo ""
  echo -e "${YELLOW}[NEXT STEP]${NC}"
  echo "  Run without --dry-run to apply fixes:"
  echo "  $0 $SCRIPT_FILE"
  echo ""
  exit 0
elif [ $FIXES_APPLIED -gt 0 ]; then
  echo -e "${CYAN}║${GREEN}  ✓ AUTO-FIX COMPLETE: $FIXES_APPLIED fix(es) applied                  ${CYAN}║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${GREEN}[SUCCESS]${NC} Fixes applied successfully"
  echo ""
  echo -e "${BLUE}[SUMMARY]${NC}"
  echo "  Fixed: $MALFORMED_COUNT malformed bracket class(es)"
  echo "  Added: $MISSING_FALLBACKS error fallback(s)"
  echo "  Total fixes: $FIXES_APPLIED"
  echo ""
  echo -e "${BLUE}[BACKUP]${NC}"
  echo "  Original saved to: ${BACKUP_FILE}"
  echo "  To restore: mv ${BACKUP_FILE} ${SCRIPT_FILE}"
  echo ""
  echo -e "${BLUE}[VERIFICATION]${NC}"
  echo "  Running validation to confirm fixes..."
  echo ""
  
  # Run validator to confirm fixes
  VALIDATOR="${SCRIPT_FILE%/*}/../helpers/validate_sed_patterns.sh"
  if [ -x "$VALIDATOR" ]; then
    if "$VALIDATOR" "$SCRIPT_FILE" --warn 2>&1 | tail -5; then
      echo ""
      echo -e "${GREEN}[✓]${NC} Validation confirmed: All fixes successful"
    fi
  fi
  echo ""
  exit 0
else
  echo -e "${CYAN}║${GREEN}  ✓ NO FIXES NEEDED: Script is already compliant              ${CYAN}║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  # Remove backup if no fixes were needed
  rm -f "$BACKUP_FILE"
  exit 1
fi
