# Git Hooks - Installation and Usage

This directory contains git hooks and validators for maintaining code quality.

## Available Hooks

### 1. Pre-Commit Hook (Fully Automated with Auto-Fix)
**File**: `pre-commit`  
**Implements**: Automated validation and fixing with zero human intervention

**Features**:
- **Automatic Detection**: Finds sed pattern errors and CMake issues
- **Automatic Fixing**: Corrects malformed patterns without user input
- **Auto-Staging**: Re-stages fixed files automatically
- **Re-Validation**: Confirms fixes work before allowing commit
- **Loop Control**: Max 3 fix attempts with clear reporting

**Validations & Auto-Fixes**:
- **D4**: Sed character class escaping validation + AUTO-FIX
- **M8/M9/M10**: CMake flag documentation validation

**Installation**:
```bash
# From repository root
ln -sf ../../scripts/hooks/pre-commit .git/hooks/pre-commit

# Configure AI review environment (automated setup)
./scripts/hooks/setup_ai_review_env.sh
# Then edit .git/hooks/pre-commit.env and add your API keys
```

**Automated Flow**:
1. **Detect** → Hook finds issues during commit
2. **Fix** → Automatically corrects sed patterns
3. **Re-stage** → Fixed files added to commit
4. **Re-validate** → Confirms all fixes worked
5. **Commit** → Proceeds automatically if clean

**What it checks & fixes**:
- ✅ **AUTO-FIXES**: Malformed sed bracket expressions `sed 's/[[...'` → `sed 's/[][]...'`
- ✅ **AUTO-FIXES**: Missing error fallbacks `$(sed ...)` → `$(sed ... || echo "")`
- ⚠️ **Manual**: Undocumented or invalid CMake flags (requires review)

### 2. CMake Validator Hook (Legacy)
**File**: `pre-commit-cmake-validator`  
**Implements**: CMake flag validation only

**Installation**:
```bash
# From repository root
ln -sf ../../scripts/hooks/pre-commit-cmake-validator .git/hooks/pre-commit
```

**Note**: Use the comprehensive `pre-commit` hook instead for full validation.

### 3. AI Review Environment Setup
**File**: `setup_ai_review_env.sh`  
**Purpose**: Automated configuration of AI review environment variables

**Quick Setup**:
```bash
# Run the setup script (creates .git/hooks/pre-commit.env)
./scripts/hooks/setup_ai_review_env.sh

# Edit the created file and add your API keys
nano .git/hooks/pre-commit.env
```

**Configuration Notes**:
- **Primary Provider**: Anthropic (Claude) - REQUIRED
  - Valid models: `claude-3-opus-20240229`, `claude-3-sonnet-20240229`, `claude-3-haiku-20240307`
  - **DO NOT use "latest" model names** - they are not supported by the API
- **Secondary Provider**: OpenAI (optional) or `none` (recommended)
  - Cursor API is **NOT supported** (no chat/completion endpoints available)
  - Set `AI_REVIEW_SECONDARY_PROVIDER="none"` to disable

**Auto-Load in Shell Sessions**:
Add to your `~/.bashrc` or `~/.zshrc`:
```bash
# Auto-load AI review environment variables
PRE_COMMIT_ENV="$HOME/Documents/Singularity_image_creation_script_xubuntu_robotics_base/.git/hooks/pre-commit.env"
if [ -f "$PRE_COMMIT_ENV" ] && [ -r "$PRE_COMMIT_ENV" ]; then
    . "$PRE_COMMIT_ENV"
fi
```

**Reference**: See `docs/AI_PRECOMMIT_HOOK.md` for complete documentation.

## Standalone Tools

### 1. Sed Pattern Auto-Fix (NEW!)
**File**: `../helpers/auto_fix_sed_patterns.sh`

**Usage**:
```bash
# Preview fixes (dry-run mode)
./scripts/helpers/auto_fix_sed_patterns.sh script.sh --dry-run

# Apply fixes automatically
./scripts/helpers/auto_fix_sed_patterns.sh script.sh
```

**What it fixes**:
- Converts `sed 's/[[...'` → `sed 's/[][]...'`
- Adds `|| echo ""` to command substitutions
- Creates backup before making changes
- Runs validation to confirm fixes

### 2. Sed Pattern Validator
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
./scripts/helpers/validate_sed_patterns.sh xubuntu_robotics_base_full.sh --strict

# Test cmake validator
./scripts/helpers/validate_cmake_flags.sh xubuntu_robotics_base_full.sh --strict
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
