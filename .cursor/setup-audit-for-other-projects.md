# Setting Up Cursor Pre-Commit Audit for Other Projects

This guide helps you set up the Cursor pre-commit audit system in any new repository.

## Quick Setup (5 minutes)

### Step 1: Copy Files

Copy these files to your new project:

```bash
# From this repository
cp -r .cursor/ /path/to/new-project/
cp .git/hooks/pre-commit /path/to/new-project/.git/hooks/
```

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
    "level": "warning"  // Adjust based on your needs
  },
  "excluded_files": [
    "^generated_script\\.sh$",
    "^legacy_file\\.sh$"
  ]
}
```

### Step 4: Install ShellCheck (Optional but Recommended)

```bash
# Ubuntu/Debian
sudo apt install shellcheck

# macOS
brew install shellcheck

# Or download from: https://github.com/koalaman/shellcheck
```

### Step 5: Test

```bash
# Test the audit
.cursor/pre-commit-audit.sh

# Make a test commit
git add .cursor/
git commit -m "Add pre-commit audit system"
```

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
```

### ShellCheck Not Found

The audit works without ShellCheck but will skip those checks. Install it for full functionality.

### Performance Issues

For large repositories, consider:
- Excluding generated files in `audit-config.json`
- Using `--no-verify` for large automated commits
- Running audit only on changed files (already implemented)

## Best Practices

1. **Enable for all projects** - Consistent code quality
2. **Install ShellCheck** - Better detection of issues
3. **Customize exclusions** - Don't audit generated files
4. **Document exceptions** - Note why certain files are excluded
5. **Regular updates** - Keep ShellCheck and audit script updated

## Sharing with Team

To ensure all team members use the audit:

1. Commit the `.cursor/` directory and `.git/hooks/pre-commit` to git
2. Add setup instructions to project README
3. Document in team onboarding materials

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

## Questions?

- Review the main audit script: `.cursor/pre-commit-audit.sh`
- Check configuration: `.cursor/audit-config.json`
- Read ShellCheck docs: https://github.com/koalaman/shellcheck

