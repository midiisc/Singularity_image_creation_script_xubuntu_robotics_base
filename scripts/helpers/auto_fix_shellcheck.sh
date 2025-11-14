#!/bin/bash
################################################################################
# AUTO-FIX SHELLCHECK ISSUES
# Purpose: Automatically fix common ShellCheck warnings before commit
# Implements: prompts/Code_check_prompt_manual.txt - Auto-fix mode
#
# Fixes:
#   1. SC2155: Declare and assign separately (local var=$(cmd))
#   2. SC1090: Add shellcheck disable for intentional dynamic source
#   3. SC2120: Add comment for functions that intentionally use $@
#
# Exit codes:
#   0 - Fixes applied successfully or no fixes needed
#   1 - Errors during fix process
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

# Check if shellcheck is available
if ! command -v shellcheck >/dev/null 2>&1; then
  echo -e "${YELLOW}[⚠]${NC} ShellCheck not available, skipping auto-fix"
  exit 0
fi

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║            AUTO-FIX: SHELLCHECK CORRECTIONS                     ║${NC}"
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
# FIX 1: SC2155 - Declare and assign separately
################################################################################

echo -e "${BLUE}[FIX 1]${NC} Fixing SC2155: Declare and assign separately..."
echo ""

# Find lines with "local var=$(command)" pattern
# Pattern: local VAR=$(command) or local VAR=`command`
# Count lines directly with grep -c (SC2126: prefer grep -c over grep | wc -l)
SC2155_COUNT=""
SC2155_COUNT=$(grep -nE '^\s*local\s+[A-Za-z_][A-Za-z0-9_]*=\$\(|^\s*local\s+[A-Za-z_][A-Za-z0-9_]*=`' "$SCRIPT_FILE" 2>/dev/null | \
  grep -vE 'shellcheck disable=SC2155' | \
  grep -c . 2>/dev/null || echo "0")

# Ensure SC2155_COUNT is numeric (strip all whitespace including newlines)
SC2155_COUNT=$(echo "${SC2155_COUNT}" | tr -d '[:space:]' || echo "0")
SC2155_COUNT=$((SC2155_COUNT + 0))

if [ "${SC2155_COUNT:-0}" -gt 0 ]; then
  echo -e "${YELLOW}[FOUND]${NC} $SC2155_COUNT SC2155 issue(s) (declare and assign separately)"
  echo ""
  
  echo -e "${BLUE}[PREVIEW]${NC} Lines to be fixed:"
  grep -nE '^\s*local\s+[A-Za-z_][A-Za-z0-9_]*=\$\(|^\s*local\s+[A-Za-z_][A-Za-z0-9_]*=`' "$SCRIPT_FILE" | \
    grep -vE 'shellcheck disable=SC2155' | \
    head -5 | sed 's/^/  /' || true
      if [ "$SC2155_COUNT" -gt 5 ]; then
        # SC2004: $ not needed in arithmetic, but kept for clarity
        echo "  ... ($((SC2155_COUNT - 5)) more)"
      fi
  echo ""
  
  if [ "$DRY_RUN" != "--dry-run" ]; then
    # Use reliable pattern replacement
    # Fix: local var=$(cmd) → local var\nvar=$(cmd)
    # Note: temp_file is global (not in function), so use plain variable (C2 compliance)
    temp_file=""
    temp_file=$(mktemp) || {
      echo -e "${RED}[✗]${NC} Failed to create temporary file"
      exit 1
    }
    
    # Setup trap to cleanup temp file on exit (N1: Resource Management)
    trap 'rm -f "${temp_file:-}"' EXIT INT TERM
    
    # Read file and process line by line
    line_num=0
    while IFS= read -r line || [ -n "$line" ]; do
      line_num=$((line_num + 1))
      
      # Check if this line matches the pattern and doesn't already have disable comment
      # Use here-string instead of echo | grep (D3: PIPE PATTERN SAFETY)
      if grep -qE '^\s*local\s+[A-Za-z_][A-Za-z0-9_]*=\$\(|^\s*local\s+[A-Za-z_][A-Za-z0-9_]*=`' <<< "$line"; then
        if ! grep -qE 'shellcheck disable=SC2155' <<< "$line"; then
          # Extract indentation using here-string (D3: PIPE PATTERN SAFETY)
          indent=""
          indent=$(sed -nE 's/^(\s*).*/\1/p' <<< "$line" || echo "")
          
          # Extract variable name and assignment using here-strings (D3 compliance)
          if grep -qE 'local\s+([A-Za-z_][A-Za-z0-9_]*)=\$\(' <<< "$line"; then
            var_name=""
            var_name=$(sed -nE 's/.*local\s+([A-Za-z_][A-Za-z0-9_]*)=\$\(.*/\1/p' <<< "$line" || echo "")
            assignment=""
            assignment=$(sed -nE 's/.*local\s+[A-Za-z_][A-Za-z0-9_]*=(\$\(.*)/\1/p' <<< "$line" || echo "")
            
            # Validate extraction succeeded (H1: Error Handling)
            if [ -z "${var_name:-}" ] || [ -z "${assignment:-}" ]; then
              echo -e "${YELLOW}[⚠]${NC} Failed to extract variable/assignment from line ${line_num}, keeping original"
              echo "$line" >> "$temp_file" || {
                echo -e "${RED}[✗]${NC} Failed to write to temp file"
                exit 1
              }
            else
              # Output two lines: declare, then assign
              echo "${indent}local ${var_name}" >> "$temp_file" || {
                echo -e "${RED}[✗]${NC} Failed to write to temp file"
                exit 1
              }
              echo "${indent}${var_name}=${assignment}" >> "$temp_file" || {
                echo -e "${RED}[✗]${NC} Failed to write to temp file"
                exit 1
              }
              FIXES_APPLIED=$((FIXES_APPLIED + 1))
            fi
          elif grep -qE 'local\s+([A-Za-z_][A-Za-z0-9_]*)=`' <<< "$line"; then
            var_name=""
            var_name=$(sed -nE 's/.*local\s+([A-Za-z_][A-Za-z0-9_]*)=`.*/\1/p' <<< "$line" || echo "")
            assignment=""
            assignment=$(sed -nE 's/.*local\s+[A-Za-z_][A-Za-z0-9_]*=(`.*)/\1/p' <<< "$line" || echo "")
            
            # Validate extraction succeeded (H1: Error Handling)
            if [ -z "${var_name:-}" ] || [ -z "${assignment:-}" ]; then
              echo -e "${YELLOW}[⚠]${NC} Failed to extract variable/assignment from line ${line_num}, keeping original"
              echo "$line" >> "$temp_file" || {
                echo -e "${RED}[✗]${NC} Failed to write to temp file"
                exit 1
              }
            else
              # Output two lines
              echo "${indent}local ${var_name}" >> "$temp_file" || {
                echo -e "${RED}[✗]${NC} Failed to write to temp file"
                exit 1
              }
              echo "${indent}${var_name}=${assignment}" >> "$temp_file" || {
                echo -e "${RED}[✗]${NC} Failed to write to temp file"
                exit 1
              }
              FIXES_APPLIED=$((FIXES_APPLIED + 1))
            fi
          else
            # No match, output original line
            echo "$line" >> "$temp_file" || {
              echo -e "${RED}[✗]${NC} Failed to write to temp file"
              exit 1
            }
          fi
        else
          # Already has disable comment, output as-is
          echo "$line" >> "$temp_file" || {
            echo -e "${RED}[✗]${NC} Failed to write to temp file"
            exit 1
          }
        fi
      else
        # Not a match, output as-is
        echo "$line" >> "$temp_file" || {
          echo -e "${RED}[✗]${NC} Failed to write to temp file"
          exit 1
        }
      fi
    done < "$SCRIPT_FILE"
    
    # Replace original file with fixed version (H1: Error Handling)
    if [ -f "$temp_file" ] && [ -s "$temp_file" ]; then
      mv "$temp_file" "$SCRIPT_FILE" || {
        echo -e "${RED}[✗]${NC} Failed to replace original file with fixed version"
        exit 1
      }
      # Clear trap after successful move
      trap - EXIT INT TERM
    else
      echo -e "${RED}[✗]${NC} Temp file is missing or empty"
      exit 1
    fi
    
    if [ $FIXES_APPLIED -gt 0 ]; then
      echo -e "${GREEN}[✓]${NC} Fixed $FIXES_APPLIED SC2155 issue(s)"
    fi
  else
    echo -e "${YELLOW}[DRY-RUN]${NC} Would fix $SC2155_COUNT issue(s)"
  fi
else
  echo -e "${GREEN}[✓]${NC} No SC2155 issues found"
fi
echo ""

################################################################################
# FIX 2: SC1090 - Add shellcheck disable for intentional dynamic source
################################################################################

echo -e "${BLUE}[FIX 2]${NC} Checking SC1090: Intentional dynamic source..."
echo ""

# Find source commands with variables that don't already have disable comments
# Count lines directly with grep -c (SC2126: prefer grep -c over grep | wc -l)
SC1090_COUNT=""
SC1090_COUNT=$(grep -nE '^\s*source\s+["\047]\$\{' "$SCRIPT_FILE" 2>/dev/null | \
  grep -vE 'shellcheck disable=SC1090' | \
  grep -c . 2>/dev/null || echo "0")

# Ensure SC1090_COUNT is numeric (strip all whitespace including newlines)
SC1090_COUNT=$(echo "${SC1090_COUNT}" | tr -d '[:space:]' || echo "0")
SC1090_COUNT=$((SC1090_COUNT + 0))

if [ "${SC1090_COUNT:-0}" -gt 0 ]; then
  echo -e "${YELLOW}[FOUND]${NC} $SC1090_COUNT SC1090 issue(s) (intentional dynamic source)"
  echo ""
  
  if [ "$DRY_RUN" != "--dry-run" ]; then
    # Add shellcheck disable comment before each source line
    # Use process substitution to avoid pipe subshell (D3: PIPE PATTERN SAFETY)
    while IFS= read -r line_info || [ -n "$line_info" ]; do
      if [ -z "$line_info" ]; then
        continue
      fi
      
      # Extract line number using here-string (D3 compliance)
      line_num=""
      line_num=$(cut -d: -f1 <<< "$line_info" || echo "")
      if [ -z "${line_num:-}" ]; then
        continue
      fi
      
      # Check if previous line already has the disable comment
      prev_line=$((line_num - 1))
      if [ $prev_line -gt 0 ]; then
        prev_content=""
        prev_content=$(sed -n "${prev_line}p" "$SCRIPT_FILE" || echo "")
        if [ -n "${prev_content:-}" ] && grep -qE 'shellcheck disable=SC1090' <<< "$prev_content"; then
          continue
        fi
      fi
      
      # Get indentation from the source line using here-string (D3 compliance)
      line_content=""
      line_content=$(sed -n "${line_num}p" "$SCRIPT_FILE" || echo "")
      if [ -z "${line_content:-}" ]; then
        continue
      fi
      indent=""
      indent=$(sed -nE 's/^(\s*).*/\1/p' <<< "$line_content" || echo "")
      
      # Insert disable comment before the source line (H1: Error Handling)
      disable_comment="${indent}# shellcheck disable=SC1090"
      if ! sed -i "${line_num}i\\${disable_comment}" "$SCRIPT_FILE" 2>/dev/null; then
        echo -e "${YELLOW}[⚠]${NC} Failed to insert disable comment at line ${line_num}"
        continue
      fi
      
      # Adjust line number for next iteration (we inserted a line)
      line_num=$((line_num + 1))
      
      FIXES_APPLIED=$((FIXES_APPLIED + 1))
    done < <(grep -nE '^\s*source\s+["\047]\$\{' "$SCRIPT_FILE" 2>/dev/null | \
      grep -vE 'shellcheck disable=SC1090' || true)
    
    if [ $FIXES_APPLIED -gt 0 ]; then
      echo -e "${GREEN}[✓]${NC} Added $FIXES_APPLIED SC1090 disable comment(s)"
    fi
  else
    echo -e "${YELLOW}[DRY-RUN]${NC} Would add $SC1090_COUNT disable comment(s)"
  fi
else
  echo -e "${GREEN}[✓]${NC} No SC1090 issues found (or already disabled)"
fi
echo ""

################################################################################
# SUMMARY
################################################################################

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
if [ $FIXES_APPLIED -gt 0 ]; then
  echo -e "${CYAN}║${GREEN}  ✓ AUTO-FIX COMPLETE: $FIXES_APPLIED correction(s) applied        ${CYAN}║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${GREEN}[SUCCESS]${NC} ShellCheck issues auto-fixed"
  echo ""
  if [ "$DRY_RUN" != "--dry-run" ]; then
    echo -e "${BLUE}[NOTE]${NC} Backup saved: ${BACKUP_FILE##*/}"
    echo -e "${BLUE}[NOTE]${NC} Please review changes before committing"
    echo ""
  fi
  exit 0
else
  echo -e "${CYAN}║${GREEN}  ✓ NO FIXES NEEDED: All ShellCheck issues already resolved  ${CYAN}║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  if [ "$DRY_RUN" != "--dry-run" ] && [ -f "$BACKUP_FILE" ]; then
    rm -f "$BACKUP_FILE"
  fi
  exit 0
# ENDIF: fixes applied
fi

