#!/usr/bin/env bash
#===============================================================================
# CURSOR SHELL SCRIPT PRE-COMMIT AUDIT
#===============================================================================
# Purpose: Comprehensive shell script audit before git commit
# Features:
#   - ShellCheck linting (industry standard) - all error types
#   - Syntax validation (bash -n)
#   - Variable expansion checks (word splitting, pathname expansion)
#   - Shell expansion checks (brace, tilde, arithmetic, command substitution)
#   - Escape sequence verification
#   - Logical error detection (infinite loops, unreachable code)
#   - Robustness checks (error handling, input validation)
#   - Edge case handling (empty strings, null variables, boundary conditions)
#   - Security checks (command injection, dangerous patterns)
#   - Style and best practices
# Usage: Called automatically by git pre-commit hook
#===============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/audit-config.json"
AUDIT_REPORT="${SCRIPT_DIR}/.audit-report.txt"
FAILED=0

# Load configuration if exists
if [ -f "${CONFIG_FILE}" ]; then
    # Simple JSON parsing (fallback if jq not available)
    if command -v jq >/dev/null 2>&1; then
        SHELLCHECK_LEVEL=$(jq -r '.shellcheck.level // "error"' "${CONFIG_FILE}" 2>/dev/null || echo "error")
        ENABLE_SHELLCHECK=$(jq -r '.shellcheck.enabled // true' "${CONFIG_FILE}" 2>/dev/null || echo "true")
        ENABLE_SYNTAX_CHECK=$(jq -r '.syntax_check.enabled // true' "${CONFIG_FILE}" 2>/dev/null || echo "true")
        EXCLUDED_FILES=$(jq -r '.excluded_files[]?' "${CONFIG_FILE}" 2>/dev/null | tr '\n' '|' || echo "")
    else
        # Fallback: use defaults
        SHELLCHECK_LEVEL="error"
        ENABLE_SHELLCHECK="true"
        ENABLE_SYNTAX_CHECK="true"
        EXCLUDED_FILES=""
    fi
else
    # Defaults
    SHELLCHECK_LEVEL="error"
    ENABLE_SHELLCHECK="true"
    ENABLE_SYNTAX_CHECK="true"
    EXCLUDED_FILES=""
fi

# Initialize report
cat > "${AUDIT_REPORT}" <<EOF
=== CURSOR SHELL AUDIT REPORT ===
Generated: $(date)
Project: ${PROJECT_ROOT}

EOF

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "${AUDIT_REPORT}"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "${AUDIT_REPORT}"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1" | tee -a "${AUDIT_REPORT}"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1" | tee -a "${AUDIT_REPORT}"
    FAILED=1
}

# Check if file should be excluded
is_excluded() {
    local file="$1"
    if [ -n "${EXCLUDED_FILES}" ]; then
        echo "${file}" | grep -qE "${EXCLUDED_FILES}" && return 0
    fi
    return 1
}

# Get staged shell scripts
get_staged_shell_scripts() {
    git diff --cached --name-only --diff-filter=ACM | \
        grep -E '\.(sh|bash)$' | \
        while read -r file; do
            [ -f "${file}" ] && echo "${file}"
        done
}

# Check if shellcheck is available
check_shellcheck() {
    if ! command -v shellcheck >/dev/null 2>&1; then
        log_warning "ShellCheck not found. Install with: sudo apt install shellcheck"
        log_info "  Or: https://github.com/koalaman/shellcheck#installing"
        return 1
    fi
    return 0
}

# Run ShellCheck on file with comprehensive checks
run_shellcheck() {
    local file="$1"
    local level="${SHELLCHECK_LEVEL}"
    
    if [ "${ENABLE_SHELLCHECK}" != "true" ]; then
        return 0
    fi
    
    if ! check_shellcheck; then
        return 0  # Skip if not available
    fi
    
    log_info "Running comprehensive ShellCheck on: ${file}"
    
    # ShellCheck severity levels: error, warning, info, style
    # Use 'all' for comprehensive checking of all error types
    local severity_args=""
    case "${level}" in
        "error")
            severity_args="-S error"
            ;;
        "warning")
            severity_args="-S error -S warning"
            ;;
        "all")
            # Check everything: error, warning, info, style
            severity_args=""
            ;;
        *)
            severity_args="-S error"
            ;;
    esac
    
    # Enable all ShellCheck checks for comprehensive coverage:
    # - SC2001: See if you can use ${var//search/replace} instead
    # - SC2004: $/${} is unnecessary on arithmetic variables
    # - SC2006: Use $(..) instead of legacy `..`
    # - SC2015: Note that &&/|| won't exit properly without set -e
    # - SC2016: Expressions don't expand in single quotes
    # - SC2028: echo may not expand escape sequences
    # - SC2034: Variable appears unused
    # - SC2039: In POSIX sh, X is undefined
    # - SC2046: Quote this to prevent word splitting
    # - SC2086: Double quote to prevent globbing and word splitting
    # - SC2128: Expanding an array without an index gives the first element
    # - SC2154: var is referenced but not assigned
    # - SC2155: Declare and assign separately to avoid masking return values
    # - SC2164: Use 'cd ... || exit' or 'cd ... || return' in case cd fails
    # - SC2181: Check exit code directly with e.g. 'if mycmd;', not indirectly with $?
    # - SC2206: Quote to prevent word splitting/globbing, or split robustly
    # - SC2207: Prefer mapfile or read -a to split command output
    # - SC2230: which is non-standard. Use builtin 'command -v' instead
    
    # Run shellcheck with comprehensive format and all checks
    if shellcheck ${severity_args} -f gcc -e SC1090,SC1091 "${file}" >> "${AUDIT_REPORT}" 2>&1; then
        log_success "ShellCheck passed: ${file}"
        return 0
    else
        log_error "ShellCheck found issues in: ${file}"
        echo "" >> "${AUDIT_REPORT}"
        return 1
    fi
}

# Syntax check using bash -n
syntax_check() {
    local file="$1"
    
    if [ "${ENABLE_SYNTAX_CHECK}" != "true" ]; then
        return 0
    fi
    
    log_info "Checking syntax: ${file}"
    
    # Detect shell type
    local shebang
    shebang=$(head -n 1 "${file}" 2>/dev/null || echo "")
    
    if echo "${shebang}" | grep -qE '^#!/bin/(ba)?sh'; then
        # Use bash -n for syntax checking
        if bash -n "${file}" 2>> "${AUDIT_REPORT}"; then
            log_success "Syntax check passed: ${file}"
            return 0
        else
            log_error "Syntax errors found in: ${file}"
            echo "" >> "${AUDIT_REPORT}"
            return 1
        fi
    else
        log_warning "No shebang found or unsupported shell: ${file}"
        return 0
    fi
}

# Comprehensive variable expansion checks
variable_expansion_check() {
    local file="$1"
    local issues=0
    
    log_info "Checking variable expansion: ${file}"
    
    # Check for unquoted variables that could cause word splitting
    # Pattern: $VAR or ${VAR} not in quotes (excluding comments and echo)
    while IFS= read -r line; do
        local line_num=$(echo "${line}" | cut -d: -f1)
        local line_content=$(echo "${line}" | cut -d: -f2-)
        
        # Skip comments and echo statements (they're often intentionally unquoted)
        if echo "${line_content}" | grep -qE '^\s*#|echo\s+'; then
            continue
        fi
        
        # Check for unquoted $VAR or ${VAR} in assignments or commands
        if echo "${line_content}" | grep -qE '\$[A-Z_][A-Z0-9_]*[^"'\''`]' && \
           ! echo "${line_content}" | grep -qE '["'\''].*\$\{?[A-Z_].*["'\'']'; then
            log_warning "Line ${line_num}: Unquoted variable expansion may cause word splitting"
            echo "  → Line ${line_num}: ${line_content}" >> "${AUDIT_REPORT}"
            echo "    Consider: \"\${VAR}\" instead of \${VAR}" >> "${AUDIT_REPORT}"
            ((issues++)) || true
        fi
    done < <(grep -nE '\$[A-Z_][A-Z0-9_]*' "${file}" 2>/dev/null || true)
    
    # Check for dangerous pathname expansion (unquoted * or ?)
    if grep -nE '[^"'\''`]\*[^"'\''`]|[^"'\''`]\?[^"'\''`]' "${file}" | grep -vE '^\s*#' >/dev/null 2>&1; then
        log_warning "Unquoted glob patterns found in: ${file}"
        echo "  → Unquoted * or ? may cause unexpected pathname expansion" >> "${AUDIT_REPORT}"
        ((issues++)) || true
    fi
    
    # Check for parameter expansion errors (${VAR:} without proper syntax)
    if grep -nE '\$\{[A-Z_][A-Z0-9_]*:[^}]*\}' "${file}" | grep -vE '^\s*#' >/dev/null 2>&1; then
        log_warning "Potential parameter expansion issues in: ${file}"
        echo "  → Check parameter expansion syntax (${VAR:-default}, ${VAR:+value}, etc.)" >> "${AUDIT_REPORT}"
    fi
    
    if [ $issues -eq 0 ]; then
        log_success "Variable expansion checks passed: ${file}"
        return 0
    else
        log_warning "Variable expansion improvements recommended: ${file}"
        return 0  # Don't fail on warnings
    fi
}

# Shell expansion checks (brace, tilde, arithmetic, etc.)
shell_expansion_check() {
    local file="$1"
    local issues=0
    
    log_info "Checking shell expansion: ${file}"
    
    # Check for malformed brace expansion
    if grep -nE '\{[^}]*$|\{[^}]*\{' "${file}" | grep -vE '^\s*#' >/dev/null 2>&1; then
        log_warning "Potential malformed brace expansion in: ${file}"
        echo "  → Check brace expansion syntax: {a,b,c} or {1..10}" >> "${AUDIT_REPORT}"
        ((issues++)) || true
    fi
    
    # Check for arithmetic expansion errors
    if grep -nE '\$\(\([^)]*$|\$\(\([^)]*\)[^)]' "${file}" | grep -vE '^\s*#' >/dev/null 2>&1; then
        log_warning "Potential arithmetic expansion errors in: ${file}"
        echo "  → Check arithmetic expansion syntax: \$((expression))" >> "${AUDIT_REPORT}"
        ((issues++)) || true
    fi
    
    # Check for command substitution errors
    if grep -nE '`[^`]*$|\$\([^)]*$' "${file}" | grep -vE '^\s*#' >/dev/null 2>&1; then
        log_warning "Potential unclosed command substitution in: ${file}"
        echo "  → Check command substitution: \$(command) or \`command\`" >> "${AUDIT_REPORT}"
        ((issues++)) || true
    fi
    
    if [ $issues -eq 0 ]; then
        log_success "Shell expansion checks passed: ${file}"
        return 0
    else
        log_warning "Shell expansion improvements recommended: ${file}"
        return 0
    fi
}

# Escape sequence and character checks
escape_sequence_check() {
    local file="$1"
    local issues=0
    
    log_info "Checking escape sequences: ${file}"
    
    # Check for incorrect escape sequences in echo without -e
    if grep -nE 'echo\s+[^-].*\\[nt]' "${file}" | grep -vE 'echo\s+-e' >/dev/null 2>&1; then
        log_warning "Escape sequences may not work without echo -e in: ${file}"
        echo "  → Use 'echo -e' or printf for escape sequences" >> "${AUDIT_REPORT}"
        ((issues++)) || true
    fi
    
    # Check for unescaped special characters in strings
    if grep -nE '[^\\]\\[^ntr\\$`"]' "${file}" | grep -vE '^\s*#' >/dev/null 2>&1; then
        log_warning "Potential escape sequence issues in: ${file}"
        printf "  → Check escape sequences: \\\\n, \\\\t, \\\\r, \\\\\\\\\\\\, \\\\\$, backtick, \\\\\"\\n" >> "${AUDIT_REPORT}"
    fi
    
    # Check for missing escapes in printf format strings
    if grep -nE 'printf\s+[^"]*%[^snrdx]' "${file}" | grep -vE '^\s*#' >/dev/null 2>&1; then
        log_warning "Potential printf format string issues in: ${file}"
        echo "  → Check printf format specifiers: %s, %d, %n, etc." >> "${AUDIT_REPORT}"
    fi
    
    if [ $issues -eq 0 ]; then
        log_success "Escape sequence checks passed: ${file}"
        return 0
    else
        log_warning "Escape sequence improvements recommended: ${file}"
        return 0
    fi
}

# Logical error checks
logical_error_check() {
    local file="$1"
    local issues=0
    
    log_info "Checking logical errors: ${file}"
    
    # Check for infinite loops (while true without break/exit)
    if grep -nE 'while\s+true|while\s+:\s*;' "${file}" >/dev/null 2>&1; then
        local has_break=false
        local has_exit=false
        if grep -qE 'break|exit\s+[0-9]|exit\s+0' "${file}"; then
            has_break=true
        fi
        if [ "$has_break" = false ]; then
            log_warning "Potential infinite loop: while true without break/exit in: ${file}"
            echo "  → Ensure loop has a break or exit condition" >> "${AUDIT_REPORT}"
            ((issues++)) || true
        fi
    fi
    
    # Check for unreachable code after return/exit
    # This is a basic check - ShellCheck does this better
    if grep -nE 'return\s+[0-9]|exit\s+[0-9]' "${file}" | while IFS= read -r line; do
        local line_num=$(echo "${line}" | cut -d: -f1)
        # Check if next non-comment line exists (basic check)
        local next_line=$((line_num + 1))
        if sed -n "${next_line}p" "${file}" | grep -qvE '^\s*#|^\s*$'; then
            echo "  → Line ${line_num}: Code after return/exit may be unreachable" >> "${AUDIT_REPORT}"
        fi
    done && [ $issues -gt 0 ]; then
        log_warning "Potential unreachable code after return/exit in: ${file}"
        ((issues++)) || true
    fi
    
    # Check for incorrect conditional logic (= vs ==, assignment vs comparison)
    if grep -nE 'if\s+\[.*=\s+[^=]|if\s+\[.*!\s*=\s*[^=]' "${file}" | grep -vE '^\s*#' >/dev/null 2>&1; then
        log_warning "Potential incorrect conditional: use == not = in test/[[ ]] in: ${file}"
        echo "  → Use [[ ]] with == or use [ ] with = (single for string)" >> "${AUDIT_REPORT}"
        ((issues++)) || true
    fi
    
    # Check for missing error handling in critical commands
    if grep -nE '(rm\s+-rf|mv\s+|cp\s+|mkdir\s+)\s+[^&|]' "${file}" | \
       grep -vE '^\s*#|2>/dev/null|\|\|.*exit|\|\|.*return' >/dev/null 2>&1; then
        log_warning "Critical commands may need error handling in: ${file}"
        echo "  → Consider: command || exit 1 or command || return 1" >> "${AUDIT_REPORT}"
    fi
    
    if [ $issues -eq 0 ]; then
        log_success "Logical error checks passed: ${file}"
        return 0
    else
        log_warning "Logical error improvements recommended: ${file}"
        return 0
    fi
}

# Robustness and error handling checks
robustness_check() {
    local file="$1"
    local issues=0
    
    log_info "Checking robustness and error handling: ${file}"
    
    # Check for missing error handling
    if ! grep -qE 'set\s+[+-]e' "${file}" && ! grep -qE 'trap\s+.*ERR|trap\s+.*EXIT' "${file}"; then
        log_warning "Missing error handling: no 'set -e' or trap in: ${file}"
        echo "  → Consider adding: set -euo pipefail or trap handlers" >> "${AUDIT_REPORT}"
        ((issues++)) || true
    fi
    
    # Check for commands that should have error handling
    local critical_commands=("rm" "mv" "cp" "mkdir" "cd" "chmod" "chown")
    for cmd in "${critical_commands[@]}"; do
        if grep -nE "${cmd}\s+[^&|]" "${file}" | \
           grep -vE '^\s*#|2>/dev/null|\|\|.*exit|\|\|.*return|set\s+-e' >/dev/null 2>&1; then
            log_warning "Critical command '${cmd}' may need explicit error handling"
            echo "  → Consider: ${cmd} args || { echo 'Error'; exit 1; }" >> "${AUDIT_REPORT}"
        fi
    done
    
    # Check for missing input validation
    if grep -nE '^\s*\$[0-9]|^\s*\$\{' "${file}" | grep -vE '^\s*#|^\s*if\s+\[.*-z|^\s*if\s+\[.*-n' >/dev/null 2>&1; then
        log_warning "Positional parameters may need validation in: ${file}"
        echo "  → Consider: if [ -z \"\${1:-}\" ]; then echo 'Usage: ...'; exit 1; fi" >> "${AUDIT_REPORT}"
    fi
    
    # Check for missing cleanup (trap EXIT)
    if grep -qE 'mktemp|tempfile|/tmp/' "${file}" && ! grep -qE 'trap.*EXIT|trap.*cleanup' "${file}"; then
        log_warning "Temporary files may need cleanup handlers in: ${file}"
        echo "  → Consider: trap 'rm -f /tmp/file' EXIT" >> "${AUDIT_REPORT}"
        ((issues++)) || true
    fi
    
    if [ $issues -eq 0 ]; then
        log_success "Robustness checks passed: ${file}"
        return 0
    else
        log_warning "Robustness improvements recommended: ${file}"
        return 0
    fi
}

# Edge case and boundary condition checks
edge_case_check() {
    local file="$1"
    local issues=0
    
    log_info "Checking edge cases and boundary conditions: ${file}"
    
    # Check for unhandled empty strings
    if grep -nE '\[.*\$[A-Z_].*\]' "${file}" | grep -vE '\[.*-z\s+\$|\[.*-n\s+\$|\[.*-z\s+"\$' >/dev/null 2>&1; then
        log_warning "Variables in tests may not handle empty strings correctly"
        echo "  → Consider: [ -n \"\${VAR:-}\" ] or [ -z \"\${VAR:-}\" ]" >> "${AUDIT_REPORT}"
        ((issues++)) || true
    fi
    
    # Check for unhandled null/undefined variables
    if grep -nE '\$\{[A-Z_][^}]*\}' "${file}" | grep -vE '\$\{[A-Z_][^}]*:-|\$\{[A-Z_][^}]*:=\}' >/dev/null 2>&1; then
        log_warning "Variables may not handle null/undefined cases"
        echo "  → Consider: \${VAR:-default} or \${VAR:=default}" >> "${AUDIT_REPORT}"
    fi
    
    # Check for division by zero in arithmetic
    if grep -nE '\$\(\(.*/[^/]*\$[A-Z_].*\)\)' "${file}" | grep -vE '^\s*#' >/dev/null 2>&1; then
        log_warning "Potential division by zero in arithmetic expressions"
        echo "  → Check: divisor != 0 before division" >> "${AUDIT_REPORT}"
        ((issues++)) || true
    fi
    
    # Check for array bounds
    if grep -nE '\[.*\$[A-Z_].*\]' "${file}" | grep -qE 'array\[|\[.*\*' && \
       ! grep -qE '\[.*#.*\]|length' "${file}"; then
        log_warning "Array access may be out of bounds"
        echo "  → Consider checking array length before access" >> "${AUDIT_REPORT}"
    fi
    
    if [ $issues -eq 0 ]; then
        log_success "Edge case checks passed: ${file}"
        return 0
    else
        log_warning "Edge case handling improvements recommended: ${file}"
        return 0
    fi
}

# Security checks (enhanced)
security_check() {
    local file="$1"
    local issues=0
    
    log_info "Running security checks: ${file}"
    
    # Check for dangerous patterns
    local dangerous_patterns=(
        "rm -rf /"
        "rm -rf \$HOME"
        "rm -rf \${HOME}"
        "eval \$"
        "curl.*\|.*sh"
        "wget.*\|.*sh"
        "\./.*\$"
    )
    
    for pattern in "${dangerous_patterns[@]}"; do
        if grep -nE "${pattern}" "${file}" >/dev/null 2>&1; then
            log_warning "Potential security issue in ${file}: pattern '${pattern}'"
            echo "  → Security warning: ${pattern}" >> "${AUDIT_REPORT}"
            ((issues++)) || true
        fi
    done
    
    # Check for command injection risks (unquoted user input)
    if grep -nE '\$[0-9]|\$\{1\}|\$\{@\}' "${file}" | \
       grep -vE '^\s*#|^\s*if|^\s*case|echo|printf|["'\''].*\$\{?[0-9@]' >/dev/null 2>&1; then
        log_warning "Potential command injection risk: unquoted user input"
        echo "  → Always quote user input: \"\${1}\" instead of \${1}" >> "${AUDIT_REPORT}"
        ((issues++)) || true
    fi
    
    if [ $issues -eq 0 ]; then
        log_success "Security checks passed: ${file}"
        return 0
    else
        log_warning "Security review recommended for: ${file}"
        return 0  # Don't fail on warnings
    fi
}

# Cursor AI Agent Audit - Semantic code analysis
cursor_ai_audit() {
    local file="$1"
    
    # Skip if Cursor AI audit is disabled
    if [ "${ENABLE_CURSOR_AI:-true}" != "true" ]; then
        return 0
    fi
    
    log_info "Running Cursor AI agent audit: ${file}"
    
    # Get staged diff
    local diff_content
    diff_content=$(git diff --cached "${file}" 2>/dev/null || echo "")
    
    if [ -z "${diff_content}" ]; then
        log_info "No staged changes for AI analysis: ${file}"
        return 0
    fi
    
    # Create AI audit prompt file for Cursor
    local prompt_file="${SCRIPT_DIR}/.cursor-ai-prompt-$$.md"
    
    cat > "${prompt_file}" <<EOF
# Comprehensive Code Audit Prompt for Cursor/AI Agent

## Context

You are an advanced AI code reviewer integrated with Cursor. Your goal is to perform a detailed, systematic, and reliable audit of all newly added or modified code blocks since the latest Git commit. You have access to the full code context in the workspace and can use any reasoning technique (Chain‑of‑Thought, multi‑agent reasoning, and tool‑use integrations like linters or analyzers) to identify and correct problems.

This audit must minimize hallucinations and ground all recommendations strictly in the provided code context and standard language specifications.

## 1. Role and Objective

You act as a senior code audit assistant.

Your primary objective is to deeply analyze every new or changed code segment before commit/push to ensure:

- Functional correctness
- Robustness
- Security
- Performance
- Maintainability
- Style compliance (lint, format)
- Proper error and edge‑case handling

## 2. Input Definition

**File:** \`${file}\`
**Changes:** Staged for commit

### DIFF TO ANALYZE

---START DIFF---

\`\`\`diff
${diff_content}
\`\`\`

---END DIFF---

## 3. Systematic Multi‑Stage Reasoning Flow

Use Chain‑of‑Thought (CoT) reasoning strictly internally (do not expose it).

Break the audit into explicit, sequential stages to prevent oversight. Each stage must be exhaustively checked:

### Stage 1: Context Understanding and Code Parsing
**Objective:** Fully understand the code context and dependencies

- Parse the diff and surrounding code (read at least 50 lines before/after changes)
- Identify affected functions, variables, scripts, and their relationships
- Detect language/environment assumptions (bash version, shell type, dependencies)
- Map variable usage across functions and identify scope issues
- Identify external dependencies and their availability assumptions
- Check for missing shebang lines or incorrect interpreter specifications
- Verify script purpose and intended behavior from comments/documentation

### Stage 2: Syntactic and Structural Audit
**Objective:** Catch all syntax, formatting, and structural errors

**2.1 Syntax Validation:**
- Detect syntax errors (unclosed quotes, brackets, parentheses, braces)
- Verify proper command termination (semicolons, newlines)
- Check for malformed conditionals: \`if [\`, \`if [[\`, \`case\`, \`for\`, \`while\`
- Validate function definitions: \`function name()\` vs \`name()\`
- Check for missing \`do\`/\`done\`, \`then\`/\`fi\`, \`case\`/\`esac\` pairs

**2.2 Formatting and Indentation:**
- Verify consistent indentation (tabs vs spaces)
- Check line length (recommend < 80-100 chars)
- Verify proper spacing around operators and keywords
- Check for trailing whitespace

**2.3 Escape Characters and Quoting:**
- Identify misplaced escape characters (\`\\\\\`, \`\\n\`, \`\\t\`, \`\\r\`)
- Check for incorrect escape sequences in echo without \`-e\` flag
- Verify proper use of single quotes (\`'\`) vs double quotes (\`"\`)
- Check for unescaped special characters in strings: \`$\`, backtick, \`*\`, \`?\`, \`[\`, \`]\`
- Validate printf format strings: \`%s\`, \`%d\`, \`%n\`, \`%x\` (flag invalid specifiers)
- Check for missing escapes in heredoc delimiters

**2.4 Structural Issues:**
- Detect unreachable code after \`return\`/\`exit\` statements
- Check for missing error handling blocks
- Verify proper nesting of control structures

### Stage 3: Semantic and Logical Analysis
**Objective:** Verify code logic, correctness, and intended functionality

**3.1 Logical Correctness:**
- Verify code logic implements intended functionality correctly
- Check for logical fallacies in conditionals (e.g., \`if [ \$var = value ]\` vs \`if [ "\$var" = "value" ]\`)
- Detect incorrect conditional operators: \`=\` vs \`==\` in \`[[ ]]\` vs \`[ ]\`
- Verify arithmetic operations are correct (addition, subtraction, division, modulo)
- Check for off-by-one errors in loops and array access
- Validate boolean logic: \`&&\`, \`||\`, \`!\` usage

**3.2 Control Flow:**
- Verify all code paths are reachable and meaningful
- Check for infinite loops: \`while true\` without \`break\`/\`exit\` conditions
- Detect missing loop termination conditions
- Verify switch/case statements have proper fall-through or breaks
- Check for dead code (unreachable after return/exit)

**3.3 Function and Command Logic:**
- Verify function return values are used correctly
- Check command exit codes are handled (\`\$?\`)
- Validate command chaining: \`&&\`, \`||\`, \`;\` usage
- Ensure control flow gracefully fails when errors occur

**3.4 Critical Command Error Handling:**
- Check for missing error handling in: \`rm\`, \`mv\`, \`cp\`, \`mkdir\`, \`cd\`, \`chmod\`, \`chown\`
- Verify commands that should fail gracefully have: \`|| exit 1\`, \`|| return 1\`, or \`2>/dev/null\`
- Check for dangerous commands without confirmation: \`rm -rf\`, \`mv\` to overwrite

### Stage 4: Shell‑Specific Vulnerability and Expansion Review
**Objective:** Prevent word splitting, pathname expansion, injection, and expansion errors

**4.1 Variable Expansion Safety:**
- **Unquoted Variables:** Check for \`\$VAR\` or \`\${VAR}\` not in quotes (causes word splitting)
  - Pattern: \`\$[A-Z_][A-Z0-9_]*[^"'\''\`]\` outside quotes
  - Exception: Comments and echo statements (often intentionally unquoted)
  - Fix: Use \`"\${VAR}"\` instead of \`\${VAR}\`
- **Pathname Expansion:** Check for unquoted glob patterns
  - Unquoted \`*\` or \`?\` may cause unexpected pathname expansion
  - Pattern: \`[^"'\''\`]\*[^"'\''\`]\` or \`[^"'\''\`]\?[^"'\''\`]\`
  - Fix: Quote patterns or use arrays
- **Parameter Expansion Errors:** Check \`\${VAR:}\` syntax
  - Verify proper syntax: \`\${VAR:-default}\`, \`\${VAR:=default}\`, \`\${VAR:+value}\`, \`\${VAR:?error}\`
  - Pattern: \`\$\{[A-Z_][A-Z0-9_]*:[^}]*\}\`
- **Array Expansion:** Check \`"\${array[@]}"\` vs \`"\${array[*]}"\` usage
  - Use \`"\${array[@]}"\` for proper word splitting
  - Use \`"\${array[*]}"\` only when single string is needed

**4.2 Shell Expansion Types:**
- **Brace Expansion:** Check for malformed \`{a,b,c}\` or \`{1..10}\`
  - Pattern: \`\{[^}]*\$|\{[^}]*\{\` (unclosed or nested incorrectly)
- **Arithmetic Expansion:** Check \`\$((expression))\` syntax
  - Pattern: \`\$\(\([^)]*\$\` or \`\$\(\([^)]*\)[^)]\` (unclosed or malformed)
  - Verify arithmetic operators: \`+\`, \`-\`, \`*\`, \`/\`, \`%\`, \`**\`
- **Command Substitution:** Check \`\$(command)\` or \`\`command\`\` syntax
  - Pattern: \`\`[^\`]*\$\` or \`\$\([^)]*\$\` (unclosed)
  - Prefer \`\$(command)\` over backticks (nesting, readability)
- **Tilde Expansion:** Verify \`~\` and \`~user\` usage
- **Process Substitution:** Check \`<(command)\` and \`>(command)\` syntax

**4.3 Special Variables and Positional Parameters:**
- Check \`\$*\` vs \`"\$@"\` usage (use \`"\$@"\` for proper argument passing)
- Verify \`\$#\`, \`\$?\`, \`\$\$\`, \`\$!\` usage
- Check positional parameters: \`\$1\`, \`\$2\`, etc. are quoted: \`"\$1"\`
- Verify \`\${@:2}\` (slice) and \`\${@: -1}\` (last arg) syntax

**4.4 Shell Options:**
- Recommend \`set -euo pipefail\` if missing (exit on error, undefined vars, pipe failures)
- Check for \`set +e\` that might hide errors (document why if needed)
- Verify \`set -x\` (debug) is not left in production code

### Stage 5: Memory, Resource, and Performance Review
**Objective:** Optimize resource usage and prevent leaks

**5.1 Loop Optimization:**
- Check for unnecessary loops that could be replaced with built-ins
- Detect inefficient nested loops
- Verify loop variables are properly scoped
- Check for loops creating unnecessary subshells (use process substitution if needed)

**5.2 Subshell and Process Management:**
- Flag unnecessary subshells: \`(command)\` vs \`{ command; }\`
- Check for processes not properly closed (background jobs without \`wait\`)
- Verify \`exec\` usage (replaces shell, no return)
- Check for file descriptor leaks (close unused FDs)

**5.3 Memory and Resource Usage:**
- Check for large file operations without streaming (use \`while read\` for large files)
- Verify temporary files are cleaned up
- Check for array operations that could be memory-intensive
- Flag potential memory leaks in long-running scripts

**5.4 I/O and Blocking Operations:**
- Check for blocking I/O that could hang (add timeouts if needed)
- Verify network operations have error handling
- Check for file operations on potentially missing files

### Stage 6: Edge‑Case and Robustness Review
**Objective:** Handle all edge cases and ensure graceful failure

**6.1 Empty String and Null Variable Handling:**
- Check variables in tests handle empty strings: \`[ -n "\${VAR:-}" ]\` or \`[ -z "\${VAR:-}" ]\`
- Pattern: \`\[.*\$[A-Z_].*\]\` without \`-z\`/\`-n\` tests
- Verify default values: \`\${VAR:-default}\`, \`\${VAR:=default}\`
- Check for unhandled null/undefined variables
  - Pattern: \`\$\{[A-Z_][^}]*\}\` without \`:- \` or \`:=\`

**6.2 Boundary Conditions:**
- **Division by Zero:** Check arithmetic division: \`\$((a / b))\`
  - Pattern: \`\$\(\(.*/[^/]*\$[A-Z_].*\)\)\`
  - Fix: Verify divisor != 0 before division
- **Array Bounds:** Check array access: \`array[\$index]\`
  - Pattern: \`\[.*\$[A-Z_].*\]\` with array access
  - Fix: Check array length before access: \`\${#array[@]}\`
- **String Length:** Check substring operations: \`\${var:offset:length}\`
  - Verify offset and length are within bounds

**6.3 Input Validation:**
- Check positional parameters have validation: \`if [ -z "\${1:-}" ]; then ...; fi\`
- Pattern: \`^\s*\$[0-9]\` or \`^\s*\$\{\` without validation
- Verify input type checking (numeric, file exists, directory, etc.)
- Check for sanitization of user input before use

**6.4 File and Path Edge Cases:**
- Check for files that might not exist: \`[ -f "\$file" ]\` before operations
- Verify directory existence: \`[ -d "\$dir" ]\` before \`cd\`
- Check for paths with spaces: always quote paths
- Verify symlink handling (use \`readlink -f\` if needed)
- Check for absolute vs relative path issues

**6.5 Error Recovery and Cleanup:**
- Verify cleanup handlers: \`trap 'cleanup' EXIT\` or \`trap 'cleanup' ERR\`
- Check temporary files have cleanup: \`trap 'rm -f /tmp/file' EXIT\`
  - Pattern: \`mktemp\`, \`tempfile\`, \`/tmp/\` without \`trap.*EXIT\`
- Verify error messages are informative
- Check for proper exit codes: \`exit 0\` (success), \`exit 1\` (failure)

### Stage 7: Security and Compliance Review
**Objective:** Prevent security vulnerabilities and ensure safe practices

**7.1 Command Injection Prevention:**
- **Unquoted User Input:** Check \`\$1\`, \`\$@\` usage without quotes
  - Pattern: \`\$[0-9]\`, \`\$\{1\}\`, \`\$\{@\}\` not in quotes
  - Fix: Always quote: \`"\$1"\`, \`"\$@"\`
- **Eval and Dynamic Execution:** Flag \`eval\`, \`exec\`, \`source\` with user input
  - Pattern: \`eval \$*\`, \`eval "\${1}"\`
  - Verify input is sanitized before eval
- **Command Substitution with User Input:** Check \`\$(user_input)\` or \`\`user_input\`\`

**7.2 Dangerous Patterns:**
- **Destructive Commands:** Flag dangerous patterns:
  - \`rm -rf /\` (should never appear)
  - \`rm -rf \$HOME\` or \`rm -rf \${HOME}\` (verify intent)
  - \`mv\` or \`cp\` without backup on critical files
- **Network Execution:** Flag: \`curl ... | sh\`, \`wget ... | sh\`
  - Pattern: \`curl.*\|.*sh\`, \`wget.*\|.*sh\`
- **Dynamic Script Execution:** Check \`./\${script}\` or \`source \${file}\`
  - Pattern: \`\./.*\$\`, \`source.*\$\`

**7.3 File and Permission Security:**
- Check for insecure temporary file usage: \`/tmp/file\` (use \`mktemp\`)
- Verify file permissions: \`chmod\` usage (avoid \`777\`, prefer \`755\` or \`644\`)
- Check for world-writable files or directories
- Verify sensitive data handling (passwords, keys) - never in plaintext

**7.4 Input Sanitization:**
- Check for filename injection: \`../\`, \`~\`, absolute paths in user input
- Verify regex patterns are safe (ReDoS prevention)
- Check for path traversal vulnerabilities

### Stage 8: Correction and Code Improvement Proposal
**Objective:** Provide actionable, tested improvements

**8.1 For Each Identified Issue:**
- Propose corrected code snippet within the same context block
- Show before/after comparison
- Explain why the change improves safety/maintainability
- Ensure fix preserves original functionality

**8.2 Code Quality Improvements:**
- Suggest better variable names (descriptive, following conventions)
- Recommend function extraction for repeated code
- Suggest comments for complex logic
- Propose consistent coding style

**8.3 Best Practices:**
- Recommend shell best practices (POSIX compliance if needed)
- Suggest use of built-ins over external commands when possible
- Propose error handling patterns: \`set -euo pipefail\`, \`trap\` handlers
- Recommend testing strategies

**8.4 Verification:**
- Each fix must be syntactically correct (validate mentally)
- Preserve functionality while enhancing safety
- Ensure improvements are grounded in original context
- Mark any suggestions as "needs manual verification" if uncertain

## 4. Output Format

Always produce structured, predictable output:

\`\`\`
=== CODE AUDIT REPORT ===

[1] Summary
Briefly describe what the script or code block does, its purpose, and main functionality.

[2] Critical Issues (Must Fix Before Commit)
<list of critical problems including exact line references, explanations, and security risks>
Format: Line X: [Issue Type] Description. Risk: [High/Medium/Low]. Fix: [suggestion]

[3] High-Priority Improvements (Should Fix)
<items that strengthen robustness, safety, or performance>
Format: Line X: [Improvement Type] Description. Benefit: [explanation]. Fix: [suggestion]

[4] Edge Case Scenarios Tested
<identify edge cases that may fail and how to handle them>
- Empty strings: [handled/not handled]
- Null variables: [handled/not handled]
- Missing files: [handled/not handled]
- Division by zero: [checked/not checked]
- Array bounds: [checked/not checked]
- Other edge cases: [list]

[5] Corrected/Improved Code Suggestion
<full or partial code snippets showing improved and audited version>
For each issue, show:
\`\`\`bash
# Before (Line X):
[original code]

# After (Line X):
[corrected code]
\`\`\`

[6] Verification Checklist
- [ ] All syntax errors identified and corrected
- [ ] All variable expansions properly quoted
- [ ] All edge cases handled
- [ ] All security issues addressed
- [ ] All improvements grounded in original context
- [ ] All fixes syntactically validated
- [ ] Functionality preserved

=== END REPORT ===
\`\`\`

## 5. Grounding, Anti‑Hallucination, and Verification Rules

**CRITICAL:** Minimize hallucinations and ground all recommendations:

- Do not introduce functions, tools, or behavior not referenced in or derivable from the provided code
- Base each recommendation on real language or runtime documentation (Bash/POSIX shell specs)
- Validate any fix by simulating the logic mentally before producing output
- When unsure, explicitly mark a point as "needs manual verification"
- Do not assume external tools or commands exist unless clearly used in codebase
- Verify all suggested patterns against actual shell behavior
- Cross-reference with ShellCheck recommendations when applicable

## 6. CRITICAL: SUGGESTIONS ONLY - NO AUTO-APPLY

- **DO NOT auto-apply any corrections**
- **ONLY suggest corrections** in the report format above
- All edits must be **visible and require manual approval**
- Show suggestions in [5] Corrected/Improved Code Suggestion section with before/after
- User will manually review and apply changes if desired
- Suggestions appear in IDE for manual approval/rejection
- Treat this as a code review, not an auto-fix tool

## 7. Mode of Operation

This audit runs automatically before every git commit. The agent automatically runs through all eight stages exhaustively and outputs the final structured report. The developer reviews the report, approves/rejects recommended fixes manually, and then continues with the commit.

**Execution Flow:**
1. Pre-commit hook triggers audit
2. All 8 stages execute sequentially
3. Structured report generated
4. Developer reviews report in IDE
5. Developer manually applies approved fixes
6. Commit proceeds after review

## 8. Completeness Guarantee

**You MUST check ALL of the following in every audit:**

✓ Syntax and structure (Stage 2, all subsections)
✓ Variable expansion safety (Stage 4.1, all patterns)
✓ Shell expansion correctness (Stage 4.2, all types)
✓ Logical correctness (Stage 3.1, all checks)
✓ Error handling (Stage 3.4, all critical commands)
✓ Edge cases (Stage 6, all subsections)
✓ Security vulnerabilities (Stage 7, all subsections)
✓ Performance issues (Stage 5, all subsections)

**Missing any of these checks constitutes an incomplete audit.**
EOF

    # Append prompt to audit report
    echo "" >> "${AUDIT_REPORT}"
    echo "=== CURSOR AI AGENT AUDIT ===" >> "${AUDIT_REPORT}"
    echo "File: ${file}" >> "${AUDIT_REPORT}"
    echo "Prompt saved to: ${prompt_file}" >> "${AUDIT_REPORT}"
    echo "" >> "${AUDIT_REPORT}"
    echo "HOW TO USE (Same as manually entering the prompt):" >> "${AUDIT_REPORT}"
    echo "  1. Open the changed file in Cursor: ${file}" >> "${AUDIT_REPORT}"
    echo "  2. Use Cmd+K (Mac) or Ctrl+K (Linux/Windows) to open Cursor AI" >> "${AUDIT_REPORT}"
    echo "  3. Copy and paste the prompt from: ${prompt_file}" >> "${AUDIT_REPORT}"
    echo "  4. Cursor AI will analyze and SUGGEST corrections (not auto-apply)" >> "${AUDIT_REPORT}"
    echo "  5. Review suggestions and manually approve/reject each change" >> "${AUDIT_REPORT}"
    echo "" >> "${AUDIT_REPORT}"
    echo "ALTERNATIVE: Open prompt file and use Cmd/Ctrl+K directly" >> "${AUDIT_REPORT}"
    echo "  The prompt file contains everything ready to use." >> "${AUDIT_REPORT}"
    echo "" >> "${AUDIT_REPORT}"
    
    # Try to invoke Cursor AI if possible
    # Method 1: Check if cursor CLI exists
    if command -v cursor >/dev/null 2>&1; then
        log_info "Attempting to invoke Cursor AI via CLI..."
        # Try to use cursor command if available
        if cursor chat --prompt-file "${prompt_file}" >> "${AUDIT_REPORT}" 2>&1; then
            log_success "Cursor AI analysis completed"
        else
            log_info "Cursor CLI not configured for AI analysis"
        fi
    fi
    
    # Method 2: Create a Cursor Rules file for automatic analysis
    local rules_file="${PROJECT_ROOT}/.cursor/rules/shell-audit.md"
    mkdir -p "${PROJECT_ROOT}/.cursor/rules" 2>/dev/null || true
    
    # Create a rule that Cursor can use for automatic analysis
    cat > "${rules_file}" <<'RULES_EOF'
# Shell Script Pre-Commit Audit Rule

When analyzing shell script changes before commit, use the comprehensive 8-pass audit process:

1. Diff Context Understanding
2. Syntax and Formatting Consistency  
3. Expansion and Escape Safety Audit
4. Semantic and Logical Analysis
5. Robustness and Error Handling
6. Efficiency and Performance
7. Security and Safety Review
8. Edge Cases and Boundary Conditions

Output format: Use the structured report format with 7 sections as specified.
RULES_EOF
    
    log_info "Cursor AI prompt created: ${prompt_file}"
    log_info "Cursor rules file created: ${rules_file}"
    
    # Attempt to auto-trigger Cursor AI in IDE
    if [ -f "${SCRIPT_DIR}/auto-trigger-cursor-ai.sh" ]; then
        log_info "Attempting to auto-trigger Cursor AI in IDE..."
        bash "${SCRIPT_DIR}/auto-trigger-cursor-ai.sh" "${file}" "${prompt_file}" >> "${AUDIT_REPORT}" 2>&1 || true
    fi
    
    # Create a Cursor workspace file that can auto-trigger
    create_cursor_workspace_trigger "${file}" "${prompt_file}"
    
    echo ""
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Cursor AI Audit - Auto-Triggered (if available)"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "${GREEN}✓ Prompt generated and ready${NC}"
    echo -e "${GREEN}✓ Attempting to auto-trigger Cursor AI in IDE...${NC}"
    echo ""
    echo -e "${CYAN}If auto-trigger works:${NC}"
    echo "  → Cursor AI chat should open automatically"
    echo "  → Suggestions will appear in IDE"
    echo "  → Review and approve/reject each suggestion"
    echo ""
    echo -e "${CYAN}If auto-trigger doesn't work:${NC}"
    echo "  1. Open file in Cursor: ${file}"
    echo "  2. Press Cmd+K (Mac) or Ctrl+K (Linux/Windows)"
    echo "  3. Prompt is ready in: ${prompt_file}"
    echo "  4. Cursor will SUGGEST corrections (not auto-apply)"
    echo ""
    echo -e "${YELLOW}Note:${NC} All suggestions require manual approval. No auto-apply."
    echo ""
    
    # Don't fail commit on AI audit (it's informational)
    return 0
}

# Create Cursor workspace trigger file
create_cursor_workspace_trigger() {
    local file="$1"
    local prompt_file="$2"
    
    # Create a workspace settings file that Cursor can use
    mkdir -p "${PROJECT_ROOT}/.cursor" 2>/dev/null || true
    
    # Create a trigger file that Cursor watches
    local trigger_file="${PROJECT_ROOT}/.cursor/.ai-audit-trigger.json"
    cat > "${trigger_file}" <<EOF
{
  "trigger": "pre-commit-audit",
  "file": "${file}",
  "prompt_file": "${prompt_file}",
  "timestamp": $(date +%s),
  "action": "open_chat_with_prompt"
}
EOF
    
    # Also create a Cursor command file
    mkdir -p "${PROJECT_ROOT}/.cursor/commands" 2>/dev/null || true
    local command_file="${PROJECT_ROOT}/.cursor/commands/audit-$(basename "${file}").json"
    cat > "${command_file}" <<EOF
{
  "command": "cursor.chat.audit",
  "file": "${file}",
  "prompt": "$(cat "${prompt_file}" | sed 's/"/\\"/g' | tr '\n' ' ')"
}
EOF
    
    log_info "Workspace trigger files created for auto-detection"
}

# Style and best practices check
style_check() {
    local file="$1"
    local issues=0
    
    log_info "Running style checks: ${file}"
    
    # Check for set -euo pipefail
    if ! grep -qE 'set\s+[+-]euo?\s+pipefail' "${file}"; then
        log_warning "Missing 'set -euo pipefail' in: ${file}"
        echo "  → Consider adding strict error handling" >> "${AUDIT_REPORT}"
        ((issues++)) || true
    fi
    
    # Check shebang
    if ! head -n 1 "${file}" | grep -qE '^#!/bin/(ba)?sh'; then
        log_warning "Missing or incorrect shebang in: ${file}"
        echo "  → Should start with #!/bin/bash or #!/bin/sh" >> "${AUDIT_REPORT}"
        ((issues++)) || true
    fi
    
    # Check for bash-specific features without bash shebang
    if head -n 1 "${file}" | grep -q '^#!/bin/sh' && grep -qE '\[\[|declare|local|function ' "${file}"; then
        log_warning "Bash-specific features used but shebang is /bin/sh: ${file}"
        echo "  → Consider changing shebang to #!/bin/bash" >> "${AUDIT_REPORT}"
    fi
    
    if [ $issues -eq 0 ]; then
        log_success "Style checks passed: ${file}"
        return 0
    else
        log_warning "Style improvements recommended for: ${file}"
        return 0  # Don't fail on style warnings
    fi
}

# Main audit function
audit_file() {
    local file="$1"
    
    # Skip excluded files
    if is_excluded "${file}"; then
        log_info "Skipping excluded file: ${file}"
        return 0
    fi
    
    echo "" >> "${AUDIT_REPORT}"
    echo "--- Auditing: ${file} ---" >> "${AUDIT_REPORT}"
    echo "" >> "${AUDIT_REPORT}"
    
    log_info "Auditing shell script: ${file}"
    
    local failed=0
    
    # Run all comprehensive checks
    syntax_check "${file}" || failed=1
    run_shellcheck "${file}" || failed=1
    variable_expansion_check "${file}" || true  # Warnings
    shell_expansion_check "${file}" || true     # Warnings
    escape_sequence_check "${file}" || true     # Warnings
    logical_error_check "${file}" || true       # Warnings
    robustness_check "${file}" || true          # Warnings
    edge_case_check "${file}" || true           # Warnings
    security_check "${file}" || true            # Warnings
    style_check "${file}" || true               # Warnings
    
    # Run Cursor AI agent audit (semantic analysis)
    cursor_ai_audit "${file}" || true  # Warnings only, don't fail commit
    
    if [ $failed -eq 0 ]; then
        log_success "All critical checks passed for: ${file}"
        return 0
    else
        log_error "Critical issues found in: ${file}"
        return 1
    fi
}

# Main execution
main() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}Cursor Shell Script Pre-Commit Audit${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # Get staged shell scripts
    local staged_files
    staged_files=$(get_staged_shell_scripts)
    
    if [ -z "${staged_files}" ]; then
        log_success "No shell scripts staged for commit"
        rm -f "${AUDIT_REPORT}"
        exit 0
    fi
    
    log_info "Found $(echo "${staged_files}" | wc -l) staged shell script(s)"
    echo ""
    
    # Audit each file
    while IFS= read -r file; do
        [ -n "${file}" ] && audit_file "${file}"
    done <<< "${staged_files}"
    
    # Summary
    echo "" >> "${AUDIT_REPORT}"
    echo "=== Summary ===" >> "${AUDIT_REPORT}"
    echo "Audited: $(echo "${staged_files}" | wc -l) file(s)" >> "${AUDIT_REPORT}"
    echo "Status: $([ $FAILED -eq 0 ] && echo "PASSED" || echo "FAILED")" >> "${AUDIT_REPORT}"
    echo "" >> "${AUDIT_REPORT}"
    
    echo ""
    echo -e "${CYAN}========================================${NC}"
    if [ $FAILED -eq 0 ]; then
        log_success "All audits passed!"
        echo ""
        log_info "Full report: ${AUDIT_REPORT}"
        exit 0
    else
        log_error "Audit failed! Please fix issues before committing."
        echo ""
        log_error "Review report: ${AUDIT_REPORT}"
        echo ""
        echo -e "${YELLOW}To skip audit (not recommended): git commit --no-verify${NC}"
        exit 1
    fi
}

# Run main
main "$@"

