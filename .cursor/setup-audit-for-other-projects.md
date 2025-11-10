# Setting Up Cursor Pre-Commit Audit for Other Projects

This guide helps you set up the Cursor pre-commit audit system in any new repository.

## Overview

The audit system provides **10 comprehensive check categories**:
- ✅ Syntax Validation (bash -n)
- ✅ ShellCheck Linting (100+ error types)
- ✅ Variable Expansion checks
- ✅ Shell Expansion checks
- ✅ Escape Sequence verification
- ✅ Logical Error detection
- ✅ Robustness checks
- ✅ Edge Case handling
- ✅ Security checks
- ✅ Cursor AI Agent semantic analysis (8-pass audit)

## Quick Setup (5 minutes)

### Step 1: Copy Required Files

Copy these files and directories to your new project:

```bash
# From this repository to your new project
PROJECT_ROOT="/path/to/new-project"

# Copy .cursor directory (excludes generated files)
cp -r .cursor/ "${PROJECT_ROOT}/"

# Copy pre-commit hook
mkdir -p "${PROJECT_ROOT}/.git/hooks"
cp .git/hooks/pre-commit "${PROJECT_ROOT}/.git/hooks/"

# Optional: Copy pre-commit.env if you have custom environment variables
# cp .git/hooks/pre-commit.env "${PROJECT_ROOT}/.git/hooks/" 2>/dev/null || true
```

**Required files:**
- `.cursor/pre-commit-audit.sh` - Main audit script
- `.cursor/audit-config.json` - Configuration file
- `.cursor/rules/shell-audit.md` - Cursor AI rules (auto-generated, but can be customized)
- `.git/hooks/pre-commit` - Git hook

**Optional files:**
- `.cursor/auto-trigger-cursor-ai.sh` - Auto-trigger Cursor AI (if using)
- `.cursor/manual-commit-audit-prompt.md` - Manual prompt template

### Step 2: Make Executable

```bash
cd /path/to/new-project
chmod +x .cursor/pre-commit-audit.sh .git/hooks/pre-commit
```

### Step 3: Customize Configuration

Edit `.cursor/audit-config.json` for your project:

```json
{
  "shellcheck": {
    "enabled": true,
    "level": "all",
    "description": "ShellCheck level: 'error', 'warning', or 'all' (recommended: 'all' for full coverage)"
  },
  "syntax_check": {
    "enabled": true,
    "description": "Enable bash -n syntax checking"
  },
  "security": {
    "enabled": true,
    "description": "Enable security pattern checks"
  },
  "style": {
    "enabled": true,
    "description": "Enable style and best practices checks"
  },
  "cursor_ai": {
    "enabled": true,
    "description": "Enable Cursor AI agent semantic analysis (8-pass audit)"
  },
  "excluded_files": [
    "\\.git/",
    "^generated_script\\.sh$",
    "^legacy_file\\.sh$"
  ],
  "description": "Pre-commit audit configuration"
}
```

**Configuration Options:**
- `shellcheck.level`: `"error"` (only errors), `"warning"` (errors+warnings), or `"all"` (comprehensive - recommended)
- `cursor_ai.enabled`: Enable/disable Cursor AI semantic analysis
- `excluded_files`: Regex patterns for files to skip (e.g., generated files)

### Step 4: Install ShellCheck (Recommended)

The audit works without ShellCheck but will skip those checks. For full functionality:

```bash
# Ubuntu/Debian
sudo apt install shellcheck

# macOS
brew install shellcheck

# Or download from: https://github.com/koalaman/shellcheck
```

**Optional dependencies:**
- `jq` - For JSON parsing (falls back to simple parsing if not available)
- `bash` 4.0+ - For advanced features

### Step 5: Test the Setup

```bash
cd /path/to/new-project

# Test the audit script directly
.cursor/pre-commit-audit.sh

# Or test on a specific file
.cursor/pre-commit-audit.sh path/to/script.sh

# Test the git hook
.git/hooks/pre-commit

# Make a test commit
git add .cursor/
git commit -m "Add pre-commit audit system"
```

### Step 6: Verify Cursor AI Integration (Optional)

The system automatically creates `.cursor/rules/shell-audit.md` for Cursor AI analysis. To use it:

1. **Automatic**: Cursor IDE will use the rules file automatically when analyzing code
2. **Manual**: Open changed files in Cursor and use **Cmd+K** (Mac) or **Ctrl+K** (Linux/Windows)
3. **Prompt file**: Check `.cursor/.cursor-ai-prompt-*.md` after audit runs

## How It Works

1. **Git pre-commit hook** (`.git/hooks/pre-commit`) runs automatically on commit
2. **Hook calls** `.cursor/pre-commit-audit.sh`
3. **Audit script** checks all staged `.sh` and `.bash` files with:
   - Syntax validation
   - ShellCheck linting (if available)
   - Variable expansion checks
   - Security pattern checks
   - Style checks
   - Cursor AI analysis (if enabled)
4. **Reports errors** and blocks commit if critical issues found
5. **Generates report** in `.cursor/.audit-report.txt` (gitignored)
6. **Creates Cursor rules** in `.cursor/rules/shell-audit.md` for AI analysis

## Customization Guide

### For Python Projects

Add Python linting to `.cursor/pre-commit-audit.sh`:

```bash
audit_python() {
    local file="$1"
    
    if [[ "${file}" =~ \.py$ ]]; then
        if command -v pylint >/dev/null 2>&1; then
            pylint "${file}" || return 1
        fi
        if command -v black >/dev/null 2>&1; then
            black --check "${file}" || return 1
        fi
    fi
}
```

### For JavaScript/TypeScript Projects

Add ESLint/Prettier checks:

```bash
audit_javascript() {
    local file="$1"
    
    if [[ "${file}" =~ \.(js|ts|jsx|tsx)$ ]]; then
        if command -v eslint >/dev/null 2>&1; then
            eslint "${file}" || return 1
        fi
        if command -v prettier >/dev/null 2>&1; then
            prettier --check "${file}" || return 1
        fi
    fi
}
```

### For Multi-Language Projects

Extend the `main()` function:

```bash
main() {
    # ... existing code ...
    
    while IFS= read -r file; do
        [ -n "${file}" ] || continue
        
        # Route to appropriate auditor
        case "${file}" in
            *.sh|*.bash)
                audit_file "${file}"
                ;;
            *.py)
                audit_python "${file}"
                ;;
            *.js|*.ts)
                audit_javascript "${file}"
                ;;
        esac
    done <<< "${staged_files}"
}
```

## Cursor AI Agent Integration

The system includes **Cursor AI agent analysis** with an 8-pass semantic audit:

1. **Diff Context Understanding** - Understands purpose and impact
2. **Syntax and Formatting** - Validates consistency
3. **Expansion and Escape Safety** - Variable/shell expansion, escape sequences
4. **Semantic and Logical Analysis** - Logical errors, unreachable code
5. **Robustness and Error Handling** - Error handling, input validation
6. **Efficiency and Performance** - Optimizes redundant operations
7. **Security and Safety** - Injection risks, dangerous patterns
8. **Edge Cases and Boundaries** - Empty strings, null variables, boundary conditions

**How it works:**
- Automatically generates `.cursor/rules/shell-audit.md` with audit rules
- Creates prompt files in `.cursor/.cursor-ai-prompt-*.md` for manual review
- Cursor IDE uses the rules file automatically for context-aware analysis
- All suggestions require manual approval (no auto-apply)

**Using Cursor AI:**
```bash
# After audit runs, check the report
cat .cursor/.audit-report.txt

# Find prompt file location in report, then:
# 1. Open the changed file in Cursor
# 2. Press Cmd+K (Mac) or Ctrl+K (Linux/Windows)
# 3. Cursor will analyze using the 8-pass audit requirements
```

## Integration with Pre-Commit Framework

If you're already using the `pre-commit` framework (https://pre-commit.com), you can integrate this:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: cursor-shell-audit
        name: Cursor Shell Audit
        entry: .cursor/pre-commit-audit.sh
        language: system
        pass_filenames: false
        always_run: true
```

## CI/CD Integration

You can also run the audit in CI/CD:

```yaml
# .github/workflows/lint.yml
name: Shell Audit

on: [push, pull_request]

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install ShellCheck
        run: sudo apt-get install shellcheck
      - name: Run Audit
        run: .cursor/pre-commit-audit.sh
```

## Troubleshooting

### Hook Not Running

```bash
# Check if hook exists
ls -la .git/hooks/pre-commit

# Make executable
chmod +x .git/hooks/pre-commit

# Test manually
.git/hooks/pre-commit

# Check hook content
cat .git/hooks/pre-commit
```

### ShellCheck Not Found

The audit works without ShellCheck but will skip those checks. Install it for full functionality:

```bash
# Ubuntu/Debian
sudo apt install shellcheck

# macOS
brew install shellcheck

# Verify installation
shellcheck --version
```

### Audit Script Not Found

```bash
# Check if script exists
ls -la .cursor/pre-commit-audit.sh

# Make executable
chmod +x .cursor/pre-commit-audit.sh

# Check path in hook
grep AUDIT_SCRIPT .git/hooks/pre-commit
```

### Cursor AI Not Working

1. **Check rules file exists**: `.cursor/rules/shell-audit.md` (auto-generated)
2. **Check prompt file**: Look for `.cursor/.cursor-ai-prompt-*.md` after audit
3. **Verify Cursor IDE**: Make sure you're using Cursor IDE (not VS Code)
4. **Check configuration**: Ensure `cursor_ai.enabled: true` in `audit-config.json`

### Performance Issues

For large repositories, consider:
- Excluding generated files in `audit-config.json`
- Using `--no-verify` for large automated commits: `git commit --no-verify`
- Running audit only on changed files (already implemented)
- Adjusting ShellCheck level to `"error"` instead of `"all"` for faster checks

### False Positives

- Add problematic files to `excluded_files` in `audit-config.json`
- Use `git commit --no-verify` for specific cases (not recommended)
- Review and fix legitimate issues (recommended)

## Best Practices

1. **Enable for all projects** - Consistent code quality across repositories
2. **Install ShellCheck** - Better detection of issues (100+ error types)
3. **Use `"all"` level** - Full coverage including warnings, info, and style checks
4. **Customize exclusions** - Don't audit generated files or third-party scripts
5. **Document exceptions** - Note why certain files are excluded in comments
6. **Regular updates** - Keep ShellCheck and audit script updated
7. **Enable Cursor AI** - Get semantic analysis and suggestions
8. **Review reports** - Check `.cursor/.audit-report.txt` for detailed findings
9. **Commit .cursor directory** - Share audit system with team
10. **Test before committing** - Run `.cursor/pre-commit-audit.sh` manually first

## Sharing with Team

To ensure all team members use the audit:

1. **Commit required files to git**:
   ```bash
   git add .cursor/pre-commit-audit.sh
   git add .cursor/audit-config.json
   git add .cursor/rules/shell-audit.md  # Optional: commit if customized
   git add .git/hooks/pre-commit
   git commit -m "Add pre-commit audit system"
   ```

2. **Add to .gitignore** (if needed):
   ```
   .cursor/.audit-report.txt
   .cursor/.cursor-ai-prompt-*.md
   ```

3. **Add setup instructions** to project README:
   ```markdown
   ## Pre-Commit Audit
   
   This project uses automated shell script auditing. After cloning:
   ```bash
   chmod +x .cursor/pre-commit-audit.sh .git/hooks/pre-commit
   ```
   
   See `.cursor/setup-audit-for-other-projects.md` for details.
   ```

4. **Document in team onboarding** materials
5. **Install ShellCheck** - Add to setup instructions

## Advanced: Custom Audit Rules

You can add project-specific rules in `.cursor/pre-commit-audit.sh`:

```bash
# Custom project rule
project_specific_check() {
    local file="$1"
    
    # Example: Check for required variables
    if ! grep -q "REQUIRED_VAR" "${file}"; then
        log_warning "Missing REQUIRED_VAR in ${file}"
    fi
}
```

## File Structure

After setup, your project should have:

```
.cursor/
├── pre-commit-audit.sh      # Main audit script
├── audit-config.json        # Configuration
├── rules/
│   └── shell-audit.md      # Cursor AI rules (auto-generated)
├── .audit-report.txt       # Generated report (gitignored)
└── .cursor-ai-prompt-*.md   # AI prompt files (gitignored)

.git/hooks/
└── pre-commit              # Git hook
```

## Skip Audit (Emergency Only)

If you need to skip the audit (not recommended):

```bash
git commit --no-verify -m "your message"
```

**Warning**: Only use `--no-verify` for emergency commits. Regular commits should pass all audits.

## Questions?

- **Main audit script**: `.cursor/pre-commit-audit.sh`
- **Configuration**: `.cursor/audit-config.json`
- **Cursor AI rules**: `.cursor/rules/shell-audit.md`
- **ShellCheck docs**: https://github.com/koalaman/shellcheck
- **Git hooks**: https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks
- **This repository**: See `.cursor/README.md` for detailed documentation

