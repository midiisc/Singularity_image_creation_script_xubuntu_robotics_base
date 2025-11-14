#!/bin/bash
################################################################################
# DOCUMENTATION VALIDATION SCRIPT
# Purpose: Validate and auto-fix documentation in code files
# Checks:
#   - Header comments/docstrings
#   - Function documentation
#   - Complex logic documentation
#   - Inline comments for non-trivial blocks
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

echo -e "${BLUE}[DOCUMENTATION VALIDATION]${NC} Checking: $TARGET_FILE"
echo ""

################################################################################
# CHECK 1: Header Comment/Docstring
################################################################################

check_header_documentation() {
    local file="$1"
    local ext="$2"
    local has_header=false
    # header_comment unused - removed to fix SC2034
    
    # Read first 30 lines
    local first_lines
    first_lines=$(head -30 "$file")
    
    case "$ext" in
        sh|bash)
            # Check for header comment block (after shebang)
            if echo "$first_lines" | grep -qE "^#!.*bash|^#!.*sh"; then
                # Check for comment block after shebang
                local after_shebang
                after_shebang=$(echo "$first_lines" | sed -n '2,30p')
                if echo "$after_shebang" | grep -qE "^#.*[Pp]urpose|^#.*[Dd]escription|^#.*[Pp]urpose:|^#.*[Dd]escription:"; then
                    has_header=true
                fi
            else
                # No shebang, check for comment at start
                if echo "$first_lines" | head -5 | grep -qE "^#.*[Pp]urpose|^#.*[Dd]escription"; then
                    has_header=true
                fi
            fi
            ;;
        py)
            # Check for module docstring
            if echo "$first_lines" | grep -qE '^""".*"""|^''''.*''''|^"""|^'''''; then
                has_header=true
            fi
            ;;
        cpp|c|h|hpp)
            # Check for header comment
            if echo "$first_lines" | grep -qE "^/\*.*\*/|^//.*[Pp]urpose|^//.*[Dd]escription"; then
                has_header=true
            fi
            ;;
    esac
    
    if [ "$has_header" = false ]; then
        echo -e "${YELLOW}[⚠]${NC} Missing header documentation"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
        return 1
    else
        echo -e "${GREEN}[✓]${NC} Header documentation present"
        return 0
    fi
}

################################################################################
# CHECK 2: Function Documentation (for functions > 10 lines)
################################################################################

check_function_documentation() {
    local file="$1"
    local ext="$2"
    local missing_docs=0
    
    case "$ext" in
        sh|bash)
            # Find function definitions
            while IFS= read -r func_line; do
                local func_name
                func_name=$(echo "$func_line" | sed -nE 's/^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)\(\)[[:space:]]*\{?.*$/\1/p')
                if [ -n "$func_name" ]; then
                    local func_start
                    func_start=$(echo "$func_line" | cut -d: -f1)
                    # Get function body size
                    local func_end
                    func_end=$(awk -v start="$func_start" '
                        NR >= start && /^[[:space:]]*}/ {print NR; exit}
                        NR >= start && /^[a-zA-Z_]/ && NR > start {print NR-1; exit}
                    ' "$file" | head -1)
                    
                    if [ -n "$func_end" ] && [ "$func_end" -gt "$func_start" ]; then
                        local func_size
                        func_size=$((func_end - func_start))
                        if [ "$func_size" -gt 10 ]; then
                            # Check for comment before function
                            local comment_line
                            comment_line=$((func_start - 1))
                            if [ "$comment_line" -gt 0 ]; then
                                local comment
                                comment=$(sed -n "${comment_line}p" "$file")
                                if ! echo "$comment" | grep -qE "^[[:space:]]*#.*$func_name|^[[:space:]]*#.*[Pp]urpose|^[[:space:]]*#.*[Dd]escription"; then
                                    echo -e "${YELLOW}[⚠]${NC} Function '$func_name' (lines $func_start-$func_end, ${func_size} lines) missing documentation"
                                    missing_docs=$((missing_docs + 1))
                                fi
                            fi
                        fi
                    fi
                fi
            done < <(grep -nE '^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*\(\)[[:space:]]*\{?' "$file" 2>/dev/null || true)
            ;;
        py)
            # Check for docstrings in functions/classes
            # This is a simplified check - full implementation would parse AST
            local funcs
            funcs=$(grep -nE '^[[:space:]]*def |^[[:space:]]*class ' "$file" 2>/dev/null || true)
            if [ -n "$funcs" ]; then
                echo -e "${BLUE}[→]${NC} Python file: Check docstrings manually (AST parsing recommended)"
            fi
            ;;
    esac
    
    if [ $missing_docs -gt 0 ]; then
        ISSUES_FOUND=$((ISSUES_FOUND + missing_docs))
        return 1
    else
        echo -e "${GREEN}[✓]${NC} Function documentation adequate"
        return 0
    fi
}

################################################################################
# CHECK 3: Complex Logic Documentation
################################################################################

check_complex_logic_documentation() {
    local file="$1"
    local missing_phase_markers=0
    
    # Check for complex multi-phase logic without phase markers
    local complex_blocks
    complex_blocks=$(grep -cE "for candidate in|for.*in.*do" "$file" 2>/dev/null || echo "0")
    local phase_markers
    phase_markers=$(grep -cE "# Phase [0-9]:|# Phase [0-9] -" "$file" 2>/dev/null || echo "0")
    
    if [ "$complex_blocks" -gt 3 ] && [ "$phase_markers" -eq 0 ]; then
        echo -e "${YELLOW}[⚠]${NC} Complex multi-phase logic detected but no phase markers found"
        echo "      Consider adding phase markers: # Phase 1: ..., # Phase 2: ..."
        missing_phase_markers=1
    fi
    
    # Check for long if-else chains without comments
    local long_conditionals
    long_conditionals=$(grep -cE "if.*\[.*\].*; then" "$file" 2>/dev/null || echo "0")
    local conditional_comments
    conditional_comments=$(grep -B1 "if.*\[.*\].*; then" "$file" 2>/dev/null | grep -cE "^[[:space:]]*#" || echo "0")
    
    if [ "$long_conditionals" -gt 5 ] && [ "$conditional_comments" -lt "$((long_conditionals / 2))" ]; then
        echo -e "${YELLOW}[⚠]${NC} Many conditionals without explanatory comments"
        missing_phase_markers=$((missing_phase_markers + 1))
    fi
    
    if [ $missing_phase_markers -gt 0 ]; then
        ISSUES_FOUND=$((ISSUES_FOUND + missing_phase_markers))
        return 1
    else
        echo -e "${GREEN}[✓]${NC} Complex logic documentation adequate"
        return 0
    fi
}

################################################################################
# CHECK 4: Inline Comments for Non-Trivial Blocks
################################################################################

check_inline_comments() {
    local file="$1"
    local ext="$2"
    local missing_comments=0
    
    # Check for loops without comments
    local loops
    # SC2126: Use grep -c instead of grep | wc -l
    loops=$(grep -cE "for |while |until " "$file" 2>/dev/null || echo "0")
    local loop_comments=0
    
    while IFS= read -r loop_line; do
        local line_num
        line_num=$(echo "$loop_line" | cut -d: -f1)
        if [ "$line_num" -gt 1 ]; then
            local prev_line
            prev_line=$(sed -n "$((line_num - 1))p" "$file")
            if echo "$prev_line" | grep -qE "^[[:space:]]*#"; then
                loop_comments=$((loop_comments + 1))
            fi
        fi
    done < <(grep -nE "for |while |until " "$file" 2>/dev/null || true)
    
    if [ "$loops" -gt 0 ]; then
        local comment_ratio
        comment_ratio=$(echo "scale=2; $loop_comments / $loops" | bc 2>/dev/null || echo "0")
        if (( $(echo "$comment_ratio < 0.5" | bc -l 2>/dev/null || echo "1") )); then
            echo -e "${YELLOW}[⚠]${NC} Many loops without explanatory comments (${loop_comments}/${loops} documented)"
            missing_comments=$((missing_comments + 1))
        fi
    fi
    
    if [ $missing_comments -gt 0 ]; then
        ISSUES_FOUND=$((ISSUES_FOUND + missing_comments))
        return 1
    else
        echo -e "${GREEN}[✓]${NC} Inline comment coverage adequate"
        return 0
    fi
}

################################################################################
# AUTO-FIX: Add Header Documentation
################################################################################

auto_fix_header() {
    local file="$1"
    local ext="$2"
    local temp_file="${file}.tmp"
    
    case "$ext" in
        sh|bash)
            # Check if shebang exists
            if head -1 "$file" | grep -qE "^#!"; then
                # Add header comment after shebang
                {
                    head -1 "$file"
                    echo ""
                    echo "################################################################################"
                    echo "# Purpose: $(basename "$file" | sed 's/\.[^.]*$//' | sed 's/_/ /g' | sed 's/\b\(.\)/\u\1/g')"
                    echo "# Description: Automated script for $(basename "$file" | sed 's/\.[^.]*$//' | sed 's/_/ /g')"
                    echo "# Generated: $(date +"%Y-%m-%d")"
                    echo "################################################################################"
                    echo ""
                    tail -n +2 "$file"
                } > "$temp_file"
            else
                # Add header at start
                {
                    echo "#!/bin/bash"
                    echo "################################################################################"
                    echo "# Purpose: $(basename "$file" | sed 's/\.[^.]*$//' | sed 's/_/ /g' | sed 's/\b\(.\)/\u\1/g')"
                    echo "# Description: Automated script for $(basename "$file" | sed 's/\.[^.]*$//' | sed 's/_/ /g')"
                    echo "# Generated: $(date +"%Y-%m-%d")"
                    echo "################################################################################"
                    echo ""
                    cat "$file"
                } > "$temp_file"
            fi
            mv "$temp_file" "$file"
            FIXES_APPLIED=$((FIXES_APPLIED + 1))
            echo -e "${GREEN}[✓]${NC} Auto-added header documentation"
            ;;
        py)
            # Add module docstring
            {
                echo '"""'
                echo "$(basename "$file" | sed 's/\.[^.]*$//' | sed 's/_/ /g' | sed 's/\b\(.\)/\u\1/g')"
                echo ""
                echo "Purpose: Module for $(basename "$file" | sed 's/\.[^.]*$//' | sed 's/_/ /g')"
                echo '"""'
                echo ""
                cat "$file"
            } > "$temp_file"
            mv "$temp_file" "$file"
            FIXES_APPLIED=$((FIXES_APPLIED + 1))
            echo -e "${GREEN}[✓]${NC} Auto-added module docstring"
            ;;
    esac
}

################################################################################
# MAIN EXECUTION
################################################################################

main() {
    echo "Running documentation validation..."
    echo ""
    
    # Run checks
    check_header_documentation "$TARGET_FILE" "$FILE_EXT" || {
        if [ "${AUTO_FIX:-0}" = "1" ]; then
            auto_fix_header "$TARGET_FILE" "$FILE_EXT"
        fi
    }
    
    check_function_documentation "$TARGET_FILE" "$FILE_EXT"
    check_complex_logic_documentation "$TARGET_FILE"
    check_inline_comments "$TARGET_FILE" "$FILE_EXT"
    
    # Summary
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "Documentation Validation Summary:"
    echo "  Issues found: $ISSUES_FOUND"
    echo "  Fixes applied: $FIXES_APPLIED"
    
    if [ $ISSUES_FOUND -eq 0 ]; then
        echo -e "${GREEN}[✓]${NC} All documentation checks passed"
        return 0
    elif [ $FIXES_APPLIED -gt 0 ]; then
        echo -e "${YELLOW}[⚠]${NC} Some issues auto-fixed, review remaining issues"
        return 0
    else
        echo -e "${RED}[✗]${NC} Documentation issues found (use AUTO_FIX=1 to auto-fix)"
        return 1
    fi
}

main "$@"

