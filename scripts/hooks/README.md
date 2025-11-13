# Git Hooks - Installation and Usage

This directory contains git hooks and validators for maintaining code quality.

## Available Hooks

### 1. Pre-Commit Hook (Comprehensive)
**File**: `pre-commit`  
**Implements**: Multiple validation checks on build scripts

**Validations Performed**:
- **D4**: Sed character class escaping validation
- **M8/M9/M10**: CMake flag documentation validation

**Installation**:
```bash
# From repository root
ln -sf ../../scripts/hooks/pre-commit .git/hooks/pre-commit
```

**What it checks**:
- Malformed sed bracket expressions (e.g., `sed 's/[[...'`)
- Missing error fallbacks in command substitutions
- Undocumented or invalid CMake flags

### 2. CMake Validator Hook (Legacy)
**File**: `pre-commit-cmake-validator`  
**Implements**: CMake flag validation only

**Installation**:
```bash
# From repository root
ln -sf ../../scripts/hooks/pre-commit-cmake-validator .git/hooks/pre-commit
```

**Note**: Use the comprehensive `pre-commit` hook instead for full validation.

## Standalone Validators

### Sed Pattern Validator
**File**: `../helpers/validate_sed_patterns.sh`

**Usage**:
```bash
# Strict mode (fails on warnings)
./scripts/helpers/validate_sed_patterns.sh script.sh --strict

# Warn mode (passes with warnings)
./scripts/helpers/validate_sed_patterns.sh script.sh --warn
```

**Detects**:
1. Malformed sed bracket classes: `sed 's/[[...'`
2. Missing error fallbacks: `$(sed ...)` without `|| echo ""`
3. Inconsistent escaping patterns

**Example errors caught**:
```bash
# WRONG: Malformed bracket class + no fallback
var="$(printf '%s' "$url" | sed 's/[[\/&]/\\&/g')"

# RIGHT: Correct bracket class + error fallback
var="$(printf '%s' "$url" | sed 's/[][\\\/&]/\\&/g' || echo "")"
```

### CMake Flag Validator
**File**: `../helpers/validate_cmake_flags.sh`

**Usage**:
```bash
./scripts/helpers/validate_cmake_flags.sh script.sh --strict
```

**Reference**: See `prompts/Code_check_prompt_manual.txt` (M8/M9/M10)

## Bypass Hook (Not Recommended)

If you need to bypass validation temporarily:
```bash
git commit --no-verify
```

**Warning**: Only use this when absolutely necessary. Failed validation usually indicates real issues.

## Hook Testing

Test validators on any script:
```bash
# Test sed validator
./scripts/helpers/validate_sed_patterns.sh xubuntu_robotics_base_post_ULTRA_CLEANED.sh --strict

# Test cmake validator
./scripts/helpers/validate_cmake_flags.sh xubuntu_robotics_base_post_ULTRA_CLEANED.sh --strict
```

## Troubleshooting

### Hook not executing
```bash
# Verify symlink exists
ls -la .git/hooks/pre-commit

# Verify hook is executable
chmod +x .git/hooks/pre-commit
chmod +x scripts/hooks/pre-commit
```

### Validator not found
```bash
# Verify validators are executable
chmod +x scripts/helpers/validate_sed_patterns.sh
chmod +x scripts/helpers/validate_cmake_flags.sh
```

### False positives
If the validator reports issues incorrectly:
1. Check if the pattern truly matches D4 or M8/M9/M10 requirements
2. Use `--warn` mode temporarily if needed
3. Report the false positive for validator improvement

## References

- **Sed validation (D4)**: `prompts/Code_check_prompt_manual.txt` section D4
- **CMake validation (M8/M9/M10)**: `prompts/Code_check_prompt_manual.txt` sections M8-M10
- **Hook documentation**: `docs/AI_PRECOMMIT_HOOK.md`

## Real-World Prevention

**Error prevented** (2025-11-13):
- Script crash after "Updated /etc/apt/sources.list" message
- Root cause: Malformed sed pattern without error fallback
- Detection: `grep -nE "sed 's/\[\[" script.sh` found 6 instances
- Result: 100% detection rate, prevents production failures

## Contributing

When adding new validators:
1. Create validator script in `scripts/helpers/`
2. Make it executable: `chmod +x scripts/helpers/validate_*.sh`
3. Add check to `scripts/hooks/pre-commit`
4. Document in this README
5. Update `prompts/Code_check_prompt_manual.txt` with check requirements
