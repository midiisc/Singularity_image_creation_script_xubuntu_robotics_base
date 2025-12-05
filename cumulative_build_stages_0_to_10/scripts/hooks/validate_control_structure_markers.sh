#!/bin/bash
################################################################################
# CONTROL STRUCTURE MARKER VALIDATION
# Purpose: Ensure if-fi, for-done, while-done, case-esac pairs have comment markers
# Format: # ENDIF: <description> or # ENDFOR: <description> or # ENDWHILE: <description>
# Rationale: Helps debug missing pairings and track which closing statement belongs to which opening
################################################################################

set -euo pipefail

# SCRIPT_DIR kept for consistency with other scripts (may be used in future)
# Currently unused - ShellCheck warning SC2034 is acceptable
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# REPO_ROOT unused - removed to fix SC2034

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# File to check
TARGET_FILE="${1:-}"

if [ -z "$TARGET_FILE" ]; then
    echo "Usage: $0 <file>"
    exit 1
fi

if [ ! -f "$TARGET_FILE" ]; then
    echo "Error: File not found: $TARGET_FILE"
    exit 1
fi

FILE_EXT="${TARGET_FILE##*.}"
FIXES_APPLIED=0
ISSUES_FOUND=0

# Only check shell scripts
if [[ ! "$FILE_EXT" =~ ^(sh|bash)$ ]]; then
    exit 0
fi

echo -e "${BLUE}[CONTROL STRUCTURE MARKERS]${NC} Checking: $TARGET_FILE"
echo ""

################################################################################
# CHECK: if-fi pairs have markers
################################################################################

check_if_fi_markers() {
    local file="$1"
    local missing_markers=0
    
    # Find all 'if' statements
    while IFS= read -r if_line; do
        local if_num
        if_num=$(echo "$if_line" | cut -d: -f1)
        local if_content
        if_content=$(echo "$if_line" | cut -d: -f2-)
        
        # Extract condition/keyword for marker
        local condition
        condition=$(echo "$if_content" | sed -E 's/^[[:space:]]*if[[:space:]]+\[\[?[[:space:]]*(.*)[[:space:]]*\]\]?[[:space:]]*;?[[:space:]]*then.*$/\1/' | head -c 40)
        
        # Find matching 'fi' (simplified - looks for next unindented fi)
        local fi_num
        fi_num=$(awk -v start="$if_num" '
            NR > start {
                if (/^[[:space:]]*fi[[:space:]]*$/) {
                    print NR
                    exit
                }
            }
        ' "$file" | head -1)
        
        if [ -n "$fi_num" ] && [ "$fi_num" -gt "$if_num" ]; then
            # Check if fi has marker comment
            local prev_line
            prev_line=$(sed -n "$((fi_num - 1))p" "$file")
            if ! echo "$prev_line" | grep -qE "^[[:space:]]*#.*ENDIF|^[[:space:]]*#.*fi.*:"; then
                echo -e "${YELLOW}[⚠]${NC} Line $fi_num: Missing marker for 'if' at line $if_num"
                echo "      Condition: ${condition}..."
                missing_markers=$((missing_markers + 1))
                
                # Auto-fix if enabled
                if [ "${AUTO_FIX:-0}" = "1" ]; then
                    local marker_comment="# ENDIF: ${condition}..."
                    local temp_file="${file}.tmp"
                    awk -v fi_line="$fi_num" -v marker="$marker_comment" '
                        NR == fi_line - 1 { print marker }
                        { print }
                    ' "$file" > "$temp_file"
                    mv "$temp_file" "$file"
                    FIXES_APPLIED=$((FIXES_APPLIED + 1))
                    echo -e "${GREEN}[✓]${NC} Auto-added marker: $marker_comment"
                # ENDIF: AUTO_FIX enabled
                fi
            # ENDIF: marker check
            fi
        # ENDIF: fi found
        fi
    # ENDWHILE: if_line loop
    done < <(grep -nE '^[[:space:]]*if[[:space:]]+\[|^[[:space:]]*if[[:space:]]+\[\[|^[[:space:]]*if[[:space:]]+command' "$file" 2>/dev/null || true)
    
    if [ $missing_markers -gt 0 ] && [ "${AUTO_FIX:-0}" != "1" ]; then
        ISSUES_FOUND=$((ISSUES_FOUND + missing_markers))
        return 1
    else
        echo -e "${GREEN}[✓]${NC} if-fi markers validated"
        return 0
    # ENDIF: missing markers check
    fi
}

################################################################################
# CHECK: for-done pairs have markers
################################################################################

check_for_done_markers() {
    local file="$1"
    local missing_markers=0
    
    # Find all 'for' loops
    while IFS= read -r for_line; do
        local for_num
        for_num=$(echo "$for_line" | cut -d: -f1)
        local for_content
        for_content=$(echo "$for_line" | cut -d: -f2-)
        
        # Extract loop variable/range for marker
        local loop_var
        loop_var=$(echo "$for_content" | sed -E 's/^[[:space:]]*for[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*).*$/\1/' | head -c 30)
        
        # Find matching 'done'
        local done_num
        done_num=$(awk -v start="$for_num" '
            NR > start {
                if (/^[[:space:]]*done[[:space:]]*$/) {
                    print NR
                    exit
                }
            }
        ' "$file" | head -1)
        
        if [ -n "$done_num" ] && [ "$done_num" -gt "$for_num" ]; then
            # Check if done has marker comment
            local prev_line
            prev_line=$(sed -n "$((done_num - 1))p" "$file")
            if ! echo "$prev_line" | grep -qE "^[[:space:]]*#.*ENDFOR|^[[:space:]]*#.*done.*:"; then
                echo -e "${YELLOW}[⚠]${NC} Line $done_num: Missing marker for 'for' at line $for_num"
                echo "      Loop variable: ${loop_var}..."
                missing_markers=$((missing_markers + 1))
                
                # Auto-fix if enabled
                if [ "${AUTO_FIX:-0}" = "1" ]; then
                    local marker_comment="# ENDFOR: ${loop_var}..."
                    local temp_file="${file}.tmp"
                    awk -v done_line="$done_num" -v marker="$marker_comment" '
                        NR == done_line - 1 { print marker }
                        { print }
                    ' "$file" > "$temp_file"
                    mv "$temp_file" "$file"
                    FIXES_APPLIED=$((FIXES_APPLIED + 1))
                    echo -e "${GREEN}[✓]${NC} Auto-added marker: $marker_comment"
                # ENDIF: AUTO_FIX enabled
                fi
            # ENDIF: marker check
            fi
        # ENDIF: done found
        fi
    # ENDWHILE: for_line loop
    done < <(grep -nE '^[[:space:]]*for[[:space:]]+' "$file" 2>/dev/null || true)
    
    if [ $missing_markers -gt 0 ] && [ "${AUTO_FIX:-0}" != "1" ]; then
        ISSUES_FOUND=$((ISSUES_FOUND + missing_markers))
        return 1
    else
        echo -e "${GREEN}[✓]${NC} for-done markers validated"
        return 0
    # ENDIF: missing markers check
    fi
}

################################################################################
# CHECK: while-done pairs have markers
################################################################################

check_while_done_markers() {
    local file="$1"
    local missing_markers=0
    
    # Find all 'while' loops
    while IFS= read -r while_line; do
        local while_num
        while_num=$(echo "$while_line" | cut -d: -f1)
        local while_content
        while_content=$(echo "$while_line" | cut -d: -f2-)
        
        # Extract condition for marker
        local condition
        condition=$(echo "$while_content" | sed -E 's/^[[:space:]]*while[[:space:]]+\[\[?[[:space:]]*(.*)[[:space:]]*\]\]?.*$/\1/' | head -c 40)
        
        # Find matching 'done'
        local done_num
        done_num=$(awk -v start="$while_num" '
            NR > start {
                if (/^[[:space:]]*done[[:space:]]*$/) {
                    print NR
                    exit
                }
            }
        ' "$file" | head -1)
        
        if [ -n "$done_num" ] && [ "$done_num" -gt "$while_num" ]; then
            # Check if done has marker comment
            local prev_line
            prev_line=$(sed -n "$((done_num - 1))p" "$file")
            if ! echo "$prev_line" | grep -qE "^[[:space:]]*#.*ENDWHILE|^[[:space:]]*#.*done.*:"; then
                echo -e "${YELLOW}[⚠]${NC} Line $done_num: Missing marker for 'while' at line $while_num"
                echo "      Condition: ${condition}..."
                missing_markers=$((missing_markers + 1))
                
                # Auto-fix if enabled
                if [ "${AUTO_FIX:-0}" = "1" ]; then
                    local marker_comment="# ENDWHILE: ${condition}..."
                    local temp_file="${file}.tmp"
                    awk -v done_line="$done_num" -v marker="$marker_comment" '
                        NR == done_line - 1 { print marker }
                        { print }
                    ' "$file" > "$temp_file"
                    mv "$temp_file" "$file"
                    FIXES_APPLIED=$((FIXES_APPLIED + 1))
                    echo -e "${GREEN}[✓]${NC} Auto-added marker: $marker_comment"
                # ENDIF: AUTO_FIX enabled
                fi
            # ENDIF: marker check
            fi
        # ENDIF: done found
        fi
    # ENDWHILE: while_line loop
    done < <(grep -nE '^[[:space:]]*while[[:space:]]+' "$file" 2>/dev/null || true)
    
    if [ $missing_markers -gt 0 ] && [ "${AUTO_FIX:-0}" != "1" ]; then
        ISSUES_FOUND=$((ISSUES_FOUND + missing_markers))
        return 1
    else
        echo -e "${GREEN}[✓]${NC} while-done markers validated"
        return 0
    # ENDIF: missing markers check
    fi
}

################################################################################
# CHECK: case-esac pairs have markers
################################################################################

check_case_esac_markers() {
    local file="$1"
    local missing_markers=0
    
    # Find all 'case' statements
    while IFS= read -r case_line; do
        local case_num
        case_num=$(echo "$case_line" | cut -d: -f1)
        local case_content
        case_content=$(echo "$case_line" | cut -d: -f2-)
        
        # Extract case variable/pattern for marker
        local case_var
        case_var=$(echo "$case_content" | sed -E 's/^[[:space:]]*case[[:space:]]+([^[:space:]]+).*$/\1/' | head -c 30)
        
        # Find matching 'esac'
        local esac_num
        esac_num=$(awk -v start="$case_num" '
            NR > start {
                if (/^[[:space:]]*esac[[:space:]]*$/) {
                    print NR
                    exit
                }
            }
        ' "$file" | head -1)
        
        if [ -n "$esac_num" ] && [ "$esac_num" -gt "$case_num" ]; then
            # Check if esac has marker comment
            local prev_line
            prev_line=$(sed -n "$((esac_num - 1))p" "$file")
            if ! echo "$prev_line" | grep -qE "^[[:space:]]*#.*ENDCASE|^[[:space:]]*#.*esac.*:"; then
                echo -e "${YELLOW}[⚠]${NC} Line $esac_num: Missing marker for 'case' at line $case_num"
                echo "      Case variable: ${case_var}..."
                missing_markers=$((missing_markers + 1))
                
                # Auto-fix if enabled
                if [ "${AUTO_FIX:-0}" = "1" ]; then
                    local marker_comment="# ENDCASE: ${case_var}..."
                    local temp_file="${file}.tmp"
                    awk -v esac_line="$esac_num" -v marker="$marker_comment" '
                        NR == esac_line - 1 { print marker }
                        { print }
                    ' "$file" > "$temp_file"
                    mv "$temp_file" "$file"
                    FIXES_APPLIED=$((FIXES_APPLIED + 1))
                    echo -e "${GREEN}[✓]${NC} Auto-added marker: $marker_comment"
                # ENDIF: AUTO_FIX enabled
                fi
            # ENDIF: marker check
            fi
        # ENDIF: esac found
        fi
    # ENDWHILE: case_line loop
    done < <(grep -nE '^[[:space:]]*case[[:space:]]+' "$file" 2>/dev/null || true)
    
    if [ $missing_markers -gt 0 ] && [ "${AUTO_FIX:-0}" != "1" ]; then
        ISSUES_FOUND=$((ISSUES_FOUND + missing_markers))
        return 1
    else
        echo -e "${GREEN}[✓]${NC} case-esac markers validated"
        return 0
    # ENDIF: missing markers check
    fi
}

################################################################################
# MAIN EXECUTION
################################################################################

main() {
    echo "Running control structure marker validation..."
    echo ""
    
    # Run checks
    check_if_fi_markers "$TARGET_FILE"
    check_for_done_markers "$TARGET_FILE"
    check_while_done_markers "$TARGET_FILE"
    check_case_esac_markers "$TARGET_FILE"
    
    # Summary
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "Control Structure Marker Validation Summary:"
    echo "  Issues found: $ISSUES_FOUND"
    echo "  Fixes applied: $FIXES_APPLIED"
    
    if [ $ISSUES_FOUND -eq 0 ]; then
        echo -e "${GREEN}[✓]${NC} All control structure markers validated"
        return 0
    elif [ $FIXES_APPLIED -gt 0 ]; then
        echo -e "${YELLOW}[⚠]${NC} Some markers auto-added, review remaining issues"
        return 0
    else
        echo -e "${RED}[✗]${NC} Missing control structure markers (use AUTO_FIX=1 to auto-fix)"
        return 1
    # ENDIF: issues summary
    fi
}

main "$@"

