# Comprehensive Shell Script Pre-Commit Audit Prompt

Copy and paste this prompt into Cursor AI chat before each commit to perform a thorough, line-by-line audit of all changes.

---

## AUDIT REQUEST

Please perform a **comprehensive, end-to-end, line-by-line audit** of all code changes in the staged diff from the previous commit. This audit must be **thorough and take time** to check every aspect systematically.

### Instructions:
1. **Get the diff**: Analyze `git diff HEAD` to see all changes since last commit
2. **Line-by-line analysis**: Check every single line in the diff for issues
3. **Show corrections inline**: For each issue found, show the correction directly in the code with clear before/after
4. **Accept/Reject options**: Present each correction as a code suggestion that can be accepted or rejected
5. **No report file**: Just show corrections in the code, no separate report needed

---

## COMPREHENSIVE AUDIT CHECKLIST

Perform these checks **sequentially and exhaustively** for every line in the diff:

### Stage 1: Syntax and Structure (MANDATORY)
- [ ] **Syntax errors**: Unclosed quotes, brackets, parentheses, braces
- [ ] **Command termination**: Missing semicolons, newlines
- [ ] **Conditionals**: Malformed `if [`, `if [[`, `case`, `for`, `while`
- [ ] **Function definitions**: `function name()` vs `name()` syntax
- [ ] **Control structures**: Missing `do`/`done`, `then`/`fi`, `case`/`esac` pairs
- [ ] **Indentation**: Consistent tabs/spaces
- [ ] **Line length**: Check for overly long lines (>100 chars)

### Stage 2: Unbound Variables (CRITICAL)
- [ ] **Variable initialization**: Every variable used must be defined before use
- [ ] **Early references**: Variables referenced before BUILD_DIR, etc. are initialized
- [ ] **Default values**: Variables without defaults that may be unbound
- [ ] **Set -u check**: Script should use `set -u` or `set -euo pipefail`
- [ ] **For each `${VAR}` or `$VAR`**: Verify it's defined or has default `${VAR:-default}`

### Stage 3: Variable Scope (CRITICAL)
- [ ] **Local in functions**: Variables in functions should use `local` keyword
- [ ] **Local outside functions**: `local` keyword used outside functions (ERROR)
- [ ] **Global pollution**: Functions using global variables without `local`
- [ ] **Scope conflicts**: Variables that might conflict between functions

### Stage 4: Function Declaration Order (CRITICAL)
- [ ] **Function calls before definition**: Functions called before they're defined
- [ ] **Duplicate definitions**: Same function defined multiple times
- [ ] **Function structure**: Properly closed functions, correct syntax
- [ ] **Function parameters**: Parameters handled correctly

### Stage 5: Variable Expansion Safety
- [ ] **Unquoted variables**: `$VAR` or `${VAR}` not in quotes (word splitting risk)
- [ ] **Pathname expansion**: Unquoted `*` or `?` patterns
- [ ] **Parameter expansion**: Proper syntax `${VAR:-default}`, `${VAR:=default}`
- [ ] **Array expansion**: `${array[@]}` vs `${array[*]}` usage

### Stage 6: Shell Expansion
- [ ] **Brace expansion**: Malformed `{a,b,c}` or `{1..10}`
- [ ] **Arithmetic expansion**: Unclosed `$((expression))`
- [ ] **Command substitution**: Unclosed `$(command)` or backticks
- [ ] **Tilde expansion**: Proper `~` and `~user` usage

### Stage 7: Escape Sequences
- [ ] **Echo without -e**: Escape sequences in `echo` without `-e` flag
- [ ] **Unescaped special chars**: `$`, backtick, `*`, `?`, `[`, `]` in strings
- [ ] **Printf format**: Valid format specifiers `%s`, `%d`, etc.

### Stage 8: Logical Errors
- [ ] **Infinite loops**: `while true` without `break`/`exit`
- [ ] **Unreachable code**: Code after `return`/`exit`
- [ ] **Conditional logic**: `=` vs `==` in `[ ]` vs `[[ ]]`
- [ ] **Error handling**: Missing `|| exit 1` or `|| return 1` on critical commands

### Stage 9: Robustness
- [ ] **Error handling**: Missing `set -euo pipefail` or trap handlers
- [ ] **Critical commands**: `rm`, `mv`, `cp`, `mkdir`, `cd` without error handling
- [ ] **Input validation**: Positional parameters validated
- [ ] **Cleanup handlers**: Temporary files have `trap EXIT` cleanup

### Stage 10: Edge Cases
- [ ] **Empty strings**: Variables handle empty strings `[ -n "${VAR:-}" ]`
- [ ] **Null variables**: Variables use defaults `${VAR:-default}`
- [ ] **Division by zero**: Arithmetic division checks divisor != 0
- [ ] **Array bounds**: Array access within bounds
- [ ] **File existence**: Files checked before operations `[ -f "$file" ]`

### Stage 11: Security
- [ ] **Command injection**: Unquoted user input `$1`, `$@`
- [ ] **Dangerous patterns**: `rm -rf /`, `eval $*`, `curl | sh`
- [ ] **File permissions**: Insecure temp files, world-writable files
- [ ] **Input sanitization**: User input sanitized before use

### Stage 12: Performance
- [ ] **Unnecessary loops**: Could use built-ins instead
- [ ] **Subshells**: Unnecessary `(command)` vs `{ command; }`
- [ ] **Large file operations**: Streaming for large files
- [ ] **Memory leaks**: Long-running script memory issues

---

## OUTPUT FORMAT

For each issue found, show:

```bash
# ISSUE: [Type] - Line X
# Description: [What's wrong]
# Risk: [High/Medium/Low]

# BEFORE (Line X):
[original code with issue]

# AFTER (Line X) - CORRECTION:
[corrected code]

# [ ] Accept this correction
# [ ] Reject this correction
```

---

## CRITICAL REQUIREMENTS

1. **Line-by-line**: Check EVERY line in the diff, not just obvious issues
2. **Take time**: Don't rush - thorough checking is required
3. **Show in code**: Corrections must be shown as code blocks, not just descriptions
4. **Accept/Reject**: Each correction must be actionable (can accept/reject)
5. **No report file**: All output should be in chat, no separate file
6. **Sequential checking**: Complete each stage fully before moving to next
7. **End-to-end**: Check from first line to last line of diff

---

## EXAMPLE AUDIT FLOW

1. Get diff: `git diff HEAD`
2. For each file in diff:
   - Stage 1: Check syntax line-by-line
   - Stage 2: Check unbound variables line-by-line
   - Stage 3: Check variable scope line-by-line
   - ... (continue through all 12 stages)
3. For each issue found:
   - Show line number
   - Show before/after code
   - Mark as High/Medium/Low risk
   - Provide accept/reject option

---

**Start the audit now. Begin by showing the diff, then proceed stage by stage, line by line.**

