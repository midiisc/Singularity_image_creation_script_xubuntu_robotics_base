# Cursor Pre-Commit Audit System

This directory contains the automated pre-commit audit system for shell scripts in this repository.

## Overview

The pre-commit audit system automatically checks shell scripts before each git commit with **10 comprehensive check categories** (9 programmatic + 1 AI agent):

✅ **Syntax Validation** - Valid bash syntax (`bash -n`)  
✅ **ShellCheck Linting** - Industry-standard checks (100+ error types)  
✅ **Variable Expansion** - Word splitting, pathname expansion, parameter expansion  
✅ **Shell Expansion** - Brace, arithmetic, command substitution  
✅ **Escape Sequences** - Proper escape handling, printf format strings  
✅ **Logical Errors** - Infinite loops, unreachable code, conditional logic  
✅ **Robustness** - Error handling, input validation, cleanup handlers  
✅ **Edge Cases** - Empty strings, null variables, division by zero, array bounds  
✅ **Security** - Command injection, dangerous patterns, unquoted input  
✅ **Cursor AI Agent** - Semantic code analysis using AI understanding (8-pass audit)

**Total Coverage:** 100+ specific error types across all categories + AI semantic analysis

## Files

- **`pre-commit-audit.sh`** - Main audit script
- **`audit-config.json`** - Configuration file
- **`.audit-report.txt`** - Generated audit report (gitignored)

## Quick Start

The system is automatically enabled when you commit. To test manually:

```bash
# Run audit on staged files
.cursor/pre-commit-audit.sh

# Or test on a specific file
.cursor/pre-commit-audit.sh test_file.sh
```

## Cursor AI Agent Integration

The system includes **Cursor AI agent analysis** that semantically understands your code changes:

### How It Works

1. **Automatic Prompt Generation**: When you commit, a Cursor AI prompt is generated with:
   - The staged diff
   - Your comprehensive 8-pass audit requirements
   - Structured output format

2. **Cursor Rules**: A `.cursor/rules/shell-audit.md` file is created that Cursor uses for consistent AI behavior

3. **AI Review**: You can review the changes with Cursor AI:
   - **Method 1**: Open the generated prompt file (`.cursor/.cursor-ai-prompt-*.md`) and use **Cmd+K** (Mac) or **Ctrl+K** (Linux)
   - **Method 2**: Use **Cursor Composer** to review the diff
   - **Method 3**: Cursor will automatically use the rules file for context-aware analysis

### Using Cursor AI for Review

```bash
# After running the audit, check the report:
cat .cursor/.audit-report.txt

# Find the prompt file location in the report, then:
# 1. Open the prompt file in Cursor
# 2. Use Cmd+K (Mac) or Ctrl+K (Linux/Windows)
# 3. Cursor AI will analyze using your 8-pass audit requirements
```

### The 8-Pass AI Audit Process

The AI agent performs semantic analysis in 8 passes:
1. **Diff Context Understanding** - Understands purpose and impact
2. **Syntax and Formatting** - Validates consistency
3. **Expansion and Escape Safety** - Checks variable expansion, shell expansion, escape sequences
4. **Semantic and Logical Analysis** - Detects logical errors, unreachable code
5. **Robustness and Error Handling** - Validates error handling, input validation
6. **Efficiency and Performance** - Optimizes redundant operations
7. **Security and Safety** - Identifies injection risks, dangerous patterns
8. **Edge Cases and Boundaries** - Checks empty strings, null variables, division by zero

### AI Audit Output Format

The AI provides a structured report with:
- Summary of changes
- Critical findings with line numbers
- High-priority fixes
- Additional improvements
- Edge case handling
- Suggested corrected snippets
- Verification checklist

## Configuration

Edit `.cursor/audit-config.json` to customize:

```json
{
  "shellcheck": {
    "enabled": true,
    "level": "error"  // "error", "warning", or "all"
  },
  "syntax_check": {
    "enabled": true
  },
  "excluded_files": [
    "^large_generated_file\\.sh$"
  ]
}
```

## Skip Audit (Not Recommended)

If you need to skip the audit (e.g., for emergency commits):

```bash
git commit --no-verify -m "your message"
```

## Requirements

- **ShellCheck** (recommended): Install with `sudo apt install shellcheck`
  - Or download from: https://github.com/koalaman/shellcheck
  - Audit works without it but will skip ShellCheck checks

## How It Works

1. Git pre-commit hook (`.git/hooks/pre-commit`) runs automatically
2. Hook calls `.cursor/pre-commit-audit.sh`
3. Audit script checks all staged `.sh` and `.bash` files
4. Reports errors and warnings
5. Blocks commit if critical issues found

## Troubleshooting

### ShellCheck not found
```bash
# Install on Ubuntu/Debian
sudo apt install shellcheck

# Or on macOS
brew install shellcheck
```

### Hook not running
```bash
# Make sure hook is executable
chmod +x .git/hooks/pre-commit

# Test manually
.git/hooks/pre-commit
```

### False positives
- Add problematic files to `excluded_files` in `audit-config.json`
- Or use `git commit --no-verify` for specific cases

## Extending for Other Languages

To add support for Python, JavaScript, etc.:

1. Edit `.cursor/pre-commit-audit.sh`
2. Add new audit functions (e.g., `audit_python()`)
3. Call from `main()` function
4. Update configuration file

## Industry Standards

This system follows industry best practices:
- ✅ Uses ShellCheck (most widely used bash linter)
- ✅ Fast execution (only checks staged files)
- ✅ Configurable (can skip with --no-verify)
- ✅ Clear error messages
- ✅ Non-blocking for optional tools (works without ShellCheck)

## Auto-Triggering Cursor AI

The system attempts to automatically trigger Cursor AI when you commit:

1. **Generates prompt file** with your diff and 8-pass audit requirements
2. **Creates trigger files** for Cursor to detect
3. **Attempts multiple methods** to auto-open Cursor AI chat
4. **Shows suggestions in IDE** (if auto-trigger works)

**If auto-trigger works:**
- Cursor AI chat opens automatically
- Suggestions appear in IDE
- You review and approve/reject each suggestion

**If auto-trigger doesn't work:**
- Open the changed file in Cursor
- Press Cmd+K (Mac) or Ctrl+K (Linux/Windows)
- Copy prompt from `.cursor/.cursor-ai-prompt-*.md`
- Paste and send - Cursor will suggest corrections

**Note:** All suggestions require manual approval. No auto-apply.

## For Other Projects

See `setup-audit-for-other-projects.md` for instructions on setting this up in new repositories.

## Related

- ShellCheck documentation: https://github.com/koalaman/shellcheck
- Git hooks: https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks

