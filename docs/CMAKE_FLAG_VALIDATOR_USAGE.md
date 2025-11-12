# CMAKE Flag Validator - Usage Guide

## Overview

The CMAKE Flag Validator is an automated tool that validates all CMake flags in build scripts against comprehensive flag documentation, preventing invalid or undocumented flags from being used.

**Location:** `scripts/helpers/validate_cmake_flags.sh`

## Features

- ✅ Extracts all CMake configuration commands from build scripts
- ✅ Identifies library context (Ceres, g2o, GTSAM, OpenCV, etc.)
- ✅ Cross-validates flags against docs/flags/*.md documentation
- ✅ Generates detailed validation reports
- ✅ Supports strict mode for CI/CD integration
- ✅ Pre-commit hook available for automatic validation

## Installation

### 1. Make Script Executable

```bash
chmod +x scripts/helpers/validate_cmake_flags.sh
```

### 2. Install Pre-Commit Hook (Optional)

```bash
# Create symlink to enable automatic validation before commits
ln -s ../../scripts/hooks/pre-commit-cmake-validator .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

## Usage

### Basic Validation

```bash
./scripts/helpers/validate_cmake_flags.sh xubuntu_robotics_base_post_ULTRA_CLEANED.sh
```

### Strict Mode (Exit on Errors)

```bash
./scripts/helpers/validate_cmake_flags.sh xubuntu_robotics_base_post_ULTRA_CLEANED.sh --strict
```

**Use strict mode for:**
- CI/CD pipelines
- Pre-commit hooks
- Automated quality checks

### Report-Only Mode

```bash
./scripts/helpers/validate_cmake_flags.sh xubuntu_robotics_base_post_ULTRA_CLEANED.sh --report-only
```

Shows extracted CMake commands without validation.

## How It Works

### 1. **CMake Command Extraction**
   - Scans build script for `cmake ..` and `cmake .` commands
   - Handles multi-line commands with backslash continuations
   - Filters out build commands (`cmake --build`)

### 2. **Library Detection**
   - Analyzes context around CMake commands
   - Detects library names from comments (up to 50 lines back)
   - Supported libraries: Ceres, g2o, GTSAM, OpenCV, Open3D, COLMAP, OpenBLAS, SuiteSparse, nvtop

### 3. **Flag Extraction**
   - Extracts all `-D FLAG=VALUE` patterns
   - Handles both `-D FLAG` and `-DFLAG` formats
   - Filters environment variables and standard CMake flags

### 4. **Documentation Lookup**
   - Searches `docs/flags/*CMAKE*FLAGS*.md` files
   - Matches flag names against documented flags
   - Reports missing documentation or undocumented flags

### 5. **Report Generation**
   - Shows validation status for each flag
   - Calculates success rate
   - Provides actionable recommendations

## Output Format

```
╔════════════════════════════════════════════════════╗
║     CMAKE FLAG VALIDATOR v1.0                      ║
╚════════════════════════════════════════════════════╝

[INFO] Extracting CMake commands from script...
[INFO] Found 12 cmake command(s)
[INFO] Validating CMake flags against documentation...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Library: CERES (line 6537)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[✓] Flag: BUILD_SHARED_LIBS - Documented in CERES_SOLVER_2.2.0_CMAKE_FLAGS_DOCUMENTATION.md
[✓] Flag: USE_CUDA - Documented in CERES_SOLVER_2.2.0_CMAKE_FLAGS_DOCUMENTATION.md
[✗] Flag: INVALID_FLAG - NOT documented in ceres flags

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
         CMAKE FLAG VALIDATION REPORT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Script Analyzed: xubuntu_robotics_base_post_ULTRA_CLEANED.sh
Validation Date: 2025-11-12 04:00:00

STATISTICS:
  CMake Commands Found: 12
  Total Flags Found:    156
  Valid Flags:          154
  Invalid Flags:        2
  Undocumented Libs:    0

SUCCESS RATE: 98%

✓ ALL FLAGS VALIDATED SUCCESSFULLY  (or ✗ VALIDATION FAILURES DETECTED)
```

## Exit Codes

- **0**: All flags valid (or report-only mode)
- **1**: Invalid flags found (strict mode) or script errors
- **2**: Documentation missing (strict mode)

## Integration with CI/CD

### GitHub Actions Example

```yaml
- name: Validate CMake Flags
  run: |
    ./scripts/helpers/validate_cmake_flags.sh \
      xubuntu_robotics_base_post_ULTRA_CLEANED.sh \
      --strict
```

### Pre-Commit Hook

The pre-commit hook automatically validates CMake flags before allowing commits:

```bash
# Validates only if build scripts are staged
# Blocks commit if validation fails
# Can be bypassed with --no-verify (not recommended)
```

## Troubleshooting

### "No cmake commands found"

**Cause:** Script doesn't match CMake command patterns  
**Solution:** Ensure commands are formatted as `cmake ..` or `cmake .` with flags

### "Documentation missing for library"

**Cause:** No flag documentation exists in `docs/flags/`  
**Solution:** Generate documentation using:
```bash
./analyze-library.sh --library <name>
```

### "Flag NOT documented"

**Cause:** Flag name doesn't match documentation  
**Solution:** 
1. Check docs/flags/*.md for correct flag name
2. Verify flag is actually defined in library's CMakeLists.txt
3. Regenerate documentation if library version changed

### "Cannot validate (unknown library context)"

**Cause:** Validator couldn't detect library name from context  
**Solution:** Add comment above cmake command mentioning library name

## Best Practices

### 1. **Always Reference Documentation**
```bash
# Reference: docs/flags/CERES_SOLVER_2.2.0_CMAKE_FLAGS_DOCUMENTATION.md
cmake .. \
  -D USE_CUDA=ON \
  -D BUILD_SHARED_LIBS=ON
```

### 2. **Document Flag Choices**
```bash
# PERFORMANCE FLAGS (from Ceres documentation):
#   - SCHUR_SPECIALIZATIONS=ON: Fixed-size Schur complement (15-30% faster)
#   - CUSTOM_BLAS=ON: Handcoded BLAS routines (10-20% faster than Eigen)
cmake .. \
  -D SCHUR_SPECIALIZATIONS=ON \
  -D CUSTOM_BLAS=ON
```

### 3. **Run Validator Before Committing**
```bash
# Manual validation
./scripts/helpers/validate_cmake_flags.sh xubuntu_robotics_base_post_ULTRA_CLEANED.sh

# Or use pre-commit hook (automatic)
```

### 4. **Keep Flag Documentation Updated**
```bash
# When upgrading library versions
./analyze-library.sh --library ceres --ref 2.2.0
```

## Related Documentation

- **Code Review Checklist:** `prompts/Code_check_prompt_manual.txt` (M8, M9, M10, O4)
- **Library Analysis Tool:** `prompts/Library-Analysis-Tool.md`
- **Flag Documentation:** `docs/flags/*.md`

## Support

For issues or questions:
1. Check this documentation
2. Review flag documentation in `docs/flags/`
3. Run validator with `--report-only` to debug extraction
4. Check pre-commit hook logs in `.git/hooks/`

---

**Version:** 1.0  
**Last Updated:** 2025-11-12  
**Maintainer:** Development Team
