# Pattern Learning Repository
## Automated Error Pattern Detection & Prevention

**Purpose**: This file stores patterns learned from real errors encountered during development. Each pattern is automatically checked during code review to prevent recurrence.

**Generation**: Patterns are extracted automatically by the AI agent when solving preventable errors during commits.

**Integration**: Referenced by:
- `.cursor/rules/MASTER-RULES-VALIDATION.mdc` (Section 3.4)
- `prompts/Advanced-CoT-Multi-Agent-Prompt.md` (PHASE P - Pattern Checking)
- `prompts/Code_check_prompt_manual.txt` (Step 3 - Pattern Validation)

**Format**: Each pattern includes:
- **Pattern ID**: Unique identifier (P-YYYYMMDD-NNN)
- **Category**: Type of error (syntax, config, logic, performance, security, etc.)
- **Error Description**: What went wrong
- **Root Cause**: Why it happened
- **Detection Pattern**: How to identify it in code (regex, AST pattern, semantic check)
- **Prevention**: How to fix it
- **Example**: Real code that triggered the pattern
- **Date Added**: When pattern was learned
- **Frequency**: How often this pattern appears (auto-updated)

---

## Active Patterns

### P-20251113-001: Bash 4+ Uppercase Conversion (${var^^})
- **Category**: Syntax/Compatibility
- **Error**: Using `${var^^}` for uppercase conversion fails in Bash 3.x
- **Root Cause**: Bash 4+ feature not available in older environments
- **Detection**: 
  ```regex
  \$\{[a-zA-Z_][a-zA-Z0-9_]*\^\^\}
  ```
- **Prevention**: Replace with `tr '[:lower:]' '[:upper:]'` or `awk '{print toupper($0)}'`
- **Example**:
  ```bash
  # WRONG (Bash 4+ only)
  lib_upper=${lib^^}
  
  # CORRECT (POSIX-compatible)
  lib_upper=$(echo "${lib}" | tr '[:lower:]' '[:upper:]')
  ```
- **Date Added**: 2025-11-13
- **Frequency**: 3 occurrences detected
- **Related**: Code_check_prompt_manual.txt A6 (BASH VERSION COMPATIBILITY)

### P-20251113-002: Echo Pipe to Grep (Unsafe Pattern)
- **Category**: Performance/Security
- **Error**: Using `echo "${VAR}" | grep "pattern"` instead of here-string
- **Root Cause**: Creates unnecessary subshell, potential echo flag interpretation
- **Detection**:
  ```regex
  echo\s+[^|]*\|\s*grep
  ```
- **Prevention**: Use `grep <<< "${VAR}"` or `[[ "${VAR}" =~ pattern ]]`
- **Example**:
  ```bash
  # WRONG (unsafe, inefficient)
  if echo "${LDCONFIG_CACHE}" | grep -q "libfoo.so"; then
  
  # CORRECT (here-string, safe)
  if grep -q "libfoo.so" <<< "${LDCONFIG_CACHE}"; then
  
  # CORRECT (Bash regex, no external command)
  if [[ "${LDCONFIG_CACHE}" =~ libfoo\.so ]]; then
  ```
- **Date Added**: 2025-11-13
- **Frequency**: 15+ occurrences detected
- **Related**: Code_check_prompt_manual.txt D3 (PIPE PATTERN SAFETY), Advanced CoT L5

### P-20251113-003: Local Keyword Outside Function
- **Category**: Syntax/Error
- **Error**: Using `local` keyword at top-level scope (outside functions)
- **Root Cause**: Shell syntax error - `local` only valid inside functions
- **Detection**:
  ```regex
  ^[[:space:]]*local[[:space:]]+[a-zA-Z_]
  ```
  (at file scope, not inside function body)
- **Prevention**: Use plain assignment or `declare` without `local` at top level
- **Example**:
  ```bash
  # WRONG (top-level scope)
  local apt_update_output=""
  
  # CORRECT (function scope)
  do_update() {
    local apt_update_output=""
    ...
  }
  
  # CORRECT (top-level scope)
  apt_update_output=""  # or: declare apt_update_output=""
  ```
- **Date Added**: 2025-11-13
- **Frequency**: 2 occurrences detected
- **Related**: Code_check_prompt_manual.txt C2 (Variables & Defaults)

### P-20251113-004: Unbound Variable in Set -u Context
- **Category**: Runtime Error
- **Error**: Variable used without default when `set -u` is active
- **Root Cause**: Missing `${VAR:-default}` pattern for potentially unset variables
- **Detection**:
  ```regex
  \$\{?[A-Z_][A-Z0-9_]*\}?(?!\:[-=\?+])
  ```
  (environment variable without default pattern, in set -u context)
- **Prevention**: Always use `${VAR:-default}` for environment variables
- **Example**:
  ```bash
  # WRONG (fails if CONTAINER_APT_CACHE unset)
  CACHE_DIR="${CONTAINER_APT_CACHE}"
  
  # CORRECT (has fallback)
  CACHE_DIR="${CONTAINER_APT_CACHE:-/var/cache/apt/archives}"
  
  # CORRECT (detection + fallback)
  if [ -z "${CONTAINER_APT_CACHE:-}" ]; then
    echo "WARNING: CONTAINER_APT_CACHE not set, using default"
    export CONTAINER_APT_CACHE="/var/cache/apt/archives"
  fi
  CACHE_DIR="${CONTAINER_APT_CACHE}"
  ```
- **Date Added**: 2025-11-13
- **Frequency**: 5 occurrences detected
- **Related**: Code_check_prompt_manual.txt C5 (UNBOUND VARIABLE PROTECTION)

### P-20251113-005: CMake Flag Not in Documentation
- **Category**: Configuration/Build
- **Error**: Using CMake flag that doesn't exist in library's CMakeLists.txt
- **Root Cause**: Assumed flag exists without checking official documentation
- **Detection**:
  ```bash
  # Extract -D flags from cmake command
  grep -oP '\-D\s*\K[A-Z_]+=' cmake_command
  # Cross-check against docs/flags/*.md
  ```
- **Prevention**: Verify every `-D FLAG=VALUE` exists in `docs/flags/LIBRARY_VERSION_CMAKE_FLAGS_DOCUMENTATION.md`
- **Example**:
  ```bash
  # WRONG (Ceres_ENABLE_CUDA doesn't exist in Ceres 2.2.0)
  cmake -DCeres_ENABLE_CUDA=ON ..
  
  # CORRECT (documented flag name)
  cmake -DUSE_CUDA=ON ..
  
  # WRONG (MKL_ROOT not supported by Ceres)
  cmake -DMKL_ROOT=/opt/intel/mkl ..
  
  # CORRECT (standard CMake variable)
  cmake -DBLA_VENDOR=Intel10_64lp ..
  ```
- **Date Added**: 2025-11-13
- **Frequency**: 7+ occurrences in recent commits
- **Related**: Code_check_prompt_manual.txt M11 (CMAKE FLAG VALIDATION)

### P-20251113-006: Mixed MKL/OpenBLAS BLAS Conflict
- **Category**: HPC/Linker Error
- **Error**: Linking both MKL BLAS and OpenBLAS in same library build
- **Root Cause**: Multiple BLAS implementations cause symbol conflicts
- **Detection**:
  ```bash
  # Check CMakeCache.txt after configuration
  if grep -q "MKL" CMakeCache.txt && grep -q "openblas" CMakeCache.txt; then
    echo "ERROR: Mixed BLAS detected"
  fi
  ```
- **Prevention**: Use single BLAS vendor consistently across entire dependency chain
- **Example**:
  ```bash
  # WRONG (both MKL and OpenBLAS detected)
  cmake -DBLA_VENDOR=Intel10_64lp ..  # but OpenBLAS found in system paths
  
  # CORRECT (explicit exclusion)
  cmake -DBLA_VENDOR=Intel10_64lp \
        -DCMAKE_IGNORE_PATH=/usr/lib/x86_64-linux-gnu/openblas-pthread ..
  
  # VERIFICATION (after configure)
  BLAS_FOUND=$(grep "^BLAS_LIBRARIES:" CMakeCache.txt | cut -d= -f2)
  if echo "${BLAS_FOUND}" | grep -qE "mkl.*openblas|openblas.*mkl"; then
    echo "ERROR: Mixed BLAS in linker path"
    exit 1
  fi
  ```
- **Date Added**: 2025-11-13
- **Frequency**: 3 occurrences detected
- **Related**: Code_check_prompt_manual.txt M12 (HPC LIBRARY CONFLICT DETECTION)

### P-20251113-007: MKL TBB vs System TBB Conflict
- **Category**: HPC/Linker Error
- **Error**: Using MKL's bundled TBB instead of system TBB
- **Root Cause**: CMake finds MKL's TBB first in search path
- **Detection**:
  ```bash
  TBB_LIB=$(grep "^TBB_LIBRARIES:" CMakeCache.txt | cut -d= -f2)
  if echo "${TBB_LIB}" | grep -qE "/opt/intel|mkl"; then
    echo "ERROR: Using MKL TBB instead of system TBB"
  fi
  ```
- **Prevention**: Explicitly set TBB_DIR and exclude MKL paths
- **Example**:
  ```bash
  # WRONG (picks up MKL TBB)
  cmake -DMKLROOT=/opt/intel/mkl ..
  
  # CORRECT (force system TBB)
  cmake -DMKLROOT=/opt/intel/mkl \
        -DTBB_DIR=/usr/lib/x86_64-linux-gnu/cmake/TBB \
        -DCMAKE_IGNORE_PATH=/opt/intel ..
  
  # VERIFICATION
  ldd /usr/local/lib/libopencv_core.so | grep tbb
  # Should show: /usr/lib/x86_64-linux-gnu/libtbb.so (not /opt/intel/*/tbb)
  ```
- **Date Added**: 2025-11-13
- **Frequency**: 2 occurrences (OpenCV, GTSAM)
- **Related**: Code_check_prompt_manual.txt M12 (HPC LIBRARY CONFLICT DETECTION)

### P-20251113-008: HTTP Error Code Not Checked
- **Category**: Network/Error Handling
- **Error**: curl/wget operations without HTTP status code validation
- **Root Cause**: Assuming network operations succeed without verification
- **Detection**:
  ```regex
  curl.*(?!-w\s+"%\{http_code\}")
  ```
- **Prevention**: Always capture and validate HTTP status codes
- **Example**:
  ```bash
  # WRONG (no error checking)
  curl -o output.txt https://example.com/file
  
  # CORRECT (capture HTTP code, check for errors)
  temp_out=$(mktemp)
  temp_err=$(mktemp)
  http_code=$(curl -sS -w "%{http_code}" -o "${temp_out}" \
              https://example.com/file 2>"${temp_err}" | tail -n1)
  
  if [[ ! "${http_code}" =~ ^[0-9]{3}$ ]]; then
    echo "ERROR: Invalid HTTP code: ${http_code}"
    cat "${temp_err}" >&2
    exit 1
  fi
  
  if [[ "${http_code}" =~ ^[45][0-9][0-9]$ ]]; then
    echo "ERROR: HTTP ${http_code} - $(head -n5 "${temp_err}")"
    # Fallback logic here
    exit 1
  fi
  
  mv "${temp_out}" output.txt
  rm -f "${temp_err}"
  ```
- **Date Added**: 2025-11-13
- **Frequency**: 10+ occurrences in mirror/download code
- **Related**: Code_check_prompt_manual.txt I4 (HTTP ERROR HANDLING)

### P-20251113-009: Single-Phase Library Verification
- **Category**: Testing/Reliability
- **Error**: Checking library installation with only ldconfig cache (single phase)
- **Root Cause**: Cache can be stale or file may exist but not be in cache
- **Detection**:
  ```bash
  # Pattern: only checking ldconfig without file existence
  if ldconfig -p | grep -q "libname.so"; then
  ```
- **Prevention**: Use multi-phase verification (file → cache → retry → version)
- **Example**:
  ```bash
  # WRONG (single phase - unreliable)
  if ldconfig -p | grep -q "libg2o_core.so"; then
    echo "g2o installed"
  fi
  
  # CORRECT (multi-phase - reliable ~95%)
  verify_lib() {
    local lib="$1"
    local install_path="/usr/local/lib/${lib}.so"
    
    # Phase 1: File existence
    if [ ! -f "${install_path}" ]; then
      echo "FAILED: ${lib} not found at ${install_path}"
      ls -la "/usr/local/lib/${lib}"*.so 2>/dev/null || echo "No ${lib} files"
      return 1
    fi
    echo "✓ Library file exists"
    
    # Phase 2: Linker cache check
    if ! timeout 5 ldconfig -p | grep -q "${lib}.so"; then
      echo "⚠ Library exists but not in cache, refreshing..."
      run_ldconfig_refresh
      
      # Phase 3: Retry after refresh
      if ! timeout 5 ldconfig -p | grep -q "${lib}.so"; then
        echo "FAILED: Still not in cache after refresh"
        ldconfig -p | grep "${lib}" || echo "No ${lib} in cache"
        return 1
      fi
      echo "✓ Library now in cache"
    else
      echo "✓ Library verified in cache"
    fi
    
    return 0
  }
  ```
- **Date Added**: 2025-11-13
- **Frequency**: Ongoing issue with g2o verification
- **Related**: Code_check_prompt_manual.txt O4 (MULTI-PHASE INSTALLATION VERIFICATION)

### P-20251113-010: Multi-Phase Logic Without Documentation
- **Category**: Maintainability/Documentation
- **Error**: Complex multi-phase detection logic without phase markers/comments
- **Root Cause**: Complex logic hard to understand without explicit structure
- **Detection**:
  ```bash
  # Pattern: Multiple related if-blocks checking conditions without phase comments
  # Look for: 3+ sequential if blocks with similar variables/intent
  ```
- **Prevention**: Add phase markers and strategy documentation
- **Example**:
  ```bash
  # WRONG (no phase structure)
  if [ -d "/opt/SDK" ]; then
    SDK_PATH="/opt/SDK"
  fi
  for candidate in /usr/include /usr/local/include; do
    if [ -f "${candidate}/header.h" ]; then
      HEADER="${candidate}/header.h"
    fi
  done
  if grep -q "libsdk.so" <<< "${LDCONFIG_CACHE}"; then
    LIB_FOUND="true"
  fi
  if [ -n "${SDK_PATH}" ] && [ -n "${HEADER}" ] && [ "${LIB_FOUND}" = "true" ]; then
    ENABLE_SDK="yes"
  fi
  
  # CORRECT (documented phases)
  # Evaluate SDK availability
  # Strategy: 3-phase detection for maximum compatibility
  # Phase 1: Check explicit installation path
  # Phase 2: Search common header locations
  # Phase 3: Verify runtime libraries via ldconfig
  # All three conditions must pass to enable SDK
  
  # Phase 1: Explicit SDK installation check
  if [ -d "/opt/SDK" ]; then
    SDK_PATH="/opt/SDK"
  fi
  
  # Phase 2: Fallback header search
  for candidate in /usr/include /usr/local/include; do
    if [ -f "${candidate}/header.h" ]; then
      HEADER="${candidate}/header.h"
    fi
  done
  
  # Phase 3: Verify runtime libraries
  if grep -q "libsdk.so" <<< "${LDCONFIG_CACHE}"; then
    LIB_FOUND="true"
  fi
  
  # Final decision: Enable only if all three phases passed
  if [ -n "${SDK_PATH}" ] && [ -n "${HEADER}" ] && [ "${LIB_FOUND}" = "true" ]; then
    ENABLE_SDK="yes"
  fi
  ```
- **Date Added**: 2025-11-13
- **Frequency**: 3 occurrences (NVDEC/NVENC detection)
- **Related**: Code_check_prompt_manual.txt L5 (MULTI-PHASE LOGIC DOCUMENTATION), Advanced CoT L5

### P-20251113-011: Silent Failure in Command Substitutions
- **Category**: Error Handling/Reliability
- **Error**: Command substitutions with `|| echo ""` or `|| true` mask failures, allowing empty/invalid results to be used
- **Root Cause**: Command substitutions `$(command)` don't propagate exit codes, and error masking (`|| echo ""`) makes failures invisible
- **Severity**: **CRITICAL** in strict mode blocks (`set -e`, `set -euo pipefail`) - can cause script to continue with invalid state
- **Detection**:
  ```bash
  # Pattern 1: Command substitution with error masking
  grep -nE '\$\([^)]*\|\| (echo ""|true)\)' script.sh
  
  # Pattern 2: Using result without validation
  # Look for: result=$(command || echo ""); if [ -n "${result}" ]; then use_result
  # This pattern fails because empty string passes -n check even on failure
  
  # Pattern 3: Parallel operations with masked failures
  grep -nE 'xargs.*\|\| true' script.sh
  ```
- **Prevention**: Always validate results after masking failures:
  1. Check result file is non-empty: `[ -s "${RESULT_FILE}" ]`
  2. Validate result format: `grep -qE 'expected_pattern' "${RESULT_FILE}"`
  3. For command substitutions: Capture exit code separately or validate result format
  4. Log failures explicitly: `if [ ! -s "${RESULT_FILE}" ]; then echo "[ERROR] All operations failed"; fi`
- **Example**:
  ```bash
  # WRONG (silent failure - fastest mirror probe)
  xargs -P 6 -I{} bash -c 'test_mirror "$1" "$2" "$3"' _ "{}" "${CODENAME}" "${PROBE_RESULTS}" || true
  fastest_mirror_raw="$(sort -n "${PROBE_RESULTS}" | awk '...' || echo "")"
  if [ -z "${fastest_mirror_raw:-}" ]; then
    # Falls back, but doesn't log that ALL probes failed
  fi
  
  # CORRECT (explicit validation)
  # Run probes
  xargs -P 6 -I{} bash -c 'test_mirror "$1" "$2" "$3" || exit 1' _ "{}" "${CODENAME}" "${PROBE_RESULTS}" || true
  
  # Validate result file contains data
  if [ ! -s "${PROBE_RESULTS}" ]; then
    echo "[ERROR] ⚠ All mirror probes failed - result file is empty"
    echo "[info] Falling back to archive.ubuntu.com"
    FASTEST_MIRROR="http://archive.ubuntu.com/ubuntu"
    return 0
  fi
  
  # Validate result format before parsing
  if ! grep -qE '^[0-9.]+ https?://' "${PROBE_RESULTS}"; then
    echo "[ERROR] ⚠ Invalid result format in probe results"
    echo "[info] Falling back to archive.ubuntu.com"
    FASTEST_MIRROR="http://archive.ubuntu.com/ubuntu"
    return 0
  fi
  
  # Parse with validation
  fastest_mirror_raw="$(sort -n "${PROBE_RESULTS}" | awk 'NF==2 && $1 < 15.0 && $1 < 999.0 {print $2; exit}')"
  if [ -z "${fastest_mirror_raw}" ] || ! validate_mirror_url "${fastest_mirror_raw}"; then
    echo "[warn] No valid mirrors found in results"
    FASTEST_MIRROR="http://archive.ubuntu.com/ubuntu"
  else
    FASTEST_MIRROR="${fastest_mirror_raw}"
  fi
  ```
- **Date Added**: 2025-11-13
- **Frequency**: 1 occurrence (fastest mirror silent failure)
- **Related**: Code_check_prompt_manual.txt H4 (SILENT FAILURE PREVENTION), F2 (Exit Code Handling), B3 (STRICT MODE SILENT FAILURE PREVENTION)

### P-20251113-012: Silent Failure in Strict Mode Blocks
- **Category**: Error Handling/Critical
- **Error**: Using `|| true` or `|| echo ""` in blocks with `set -e` or `set -euo pipefail` without validation
- **Root Cause**: Strict mode expects failures to exit, but masked failures allow script to continue with invalid state
- **Severity**: **CRITICAL** - Can cause cascading failures, invalid state propagation, or logic errors
- **Detection**:
  ```bash
  # Pattern 1: Find strict mode blocks
  grep -nE 'set -e|set -eo|set -euo' script.sh
  
  # Pattern 2: Find masked failures in strict mode context
  # Manually check: For each strict mode block, find all || true or || echo "" patterns
  
  # Pattern 3: Command substitutions without validation in strict mode
  # Look for: result=$(command || echo "") followed by use without validation
  ```
- **Prevention**: In strict mode blocks:
  1. **NEVER** use `|| true` without explicit validation and logging
  2. **ALWAYS** validate result files: `[ -s "${RESULT_FILE}" ] || { echo "[ERROR] ..."; exit 1; }`
  3. **ALWAYS** validate command substitution results: `result=$(command) || { echo "[ERROR] ..."; exit 1; }` then validate format
  4. **ALWAYS** log failures explicitly before masking: `command || { echo "[ERROR] Operation failed: command"; exit 1; }`
  5. **ALWAYS** check result format before parsing: `grep -qE 'expected_pattern' "${RESULT_FILE}" || exit 1`
- **Example**:
  ```bash
  # WRONG (silent failure in strict mode - EXTREMELY DANGEROUS)
  set -euo pipefail  # Strict mode active
  xargs -P 6 -I{} test_mirror "$1" "$2" "$3" _ "{}" "${CODENAME}" "${PROBE_RESULTS}" || true
  fastest_mirror_raw="$(sort -n "${PROBE_RESULTS}" | awk '...' || echo "")"
  # If PROBE_RESULTS is empty, fastest_mirror_raw is empty, but script continues
  # Later: use "${fastest_mirror_raw}" may cause logic error or trigger set -u
  
  # CORRECT (explicit validation in strict mode)
  set -euo pipefail  # Strict mode active
  
  # Run probes
  xargs -P 6 -I{} bash -c 'test_mirror "$1" "$2" "$3" || exit 1' _ "{}" "${CODENAME}" "${PROBE_RESULTS}" || {
    echo "[ERROR] ⚠ Mirror probe operations failed"
    exit 1
  }
  
  # Validate result file BEFORE parsing
  if [ ! -s "${PROBE_RESULTS}" ]; then
    echo "[ERROR] ⚠ All mirror probes failed - result file is empty"
    echo "[info] Falling back to archive.ubuntu.com"
    FASTEST_MIRROR="http://archive.ubuntu.com/ubuntu"
    export FASTEST_MIRROR
    return 0  # Exit function, not script (if in function)
  fi
  
  # Validate result format
  if ! grep -qE '^[0-9.]+ https?://' "${PROBE_RESULTS}"; then
    echo "[ERROR] ⚠ Invalid result format in probe results"
    echo "[info] Falling back to archive.ubuntu.com"
    FASTEST_MIRROR="http://archive.ubuntu.com/ubuntu"
    export FASTEST_MIRROR
    return 0
  fi
  
  # Parse with validation
  fastest_mirror_raw="$(sort -n "${PROBE_RESULTS}" | awk 'NF==2 && $1 < 15.0 && $1 < 999.0 {print $2; exit}')" || {
    echo "[ERROR] ⚠ Failed to parse probe results"
    exit 1
  }
  
  # Validate result
  if [ -z "${fastest_mirror_raw}" ] || ! validate_mirror_url "${fastest_mirror_raw}"; then
    echo "[warn] No valid mirrors found, using archive.ubuntu.com"
    FASTEST_MIRROR="http://archive.ubuntu.com/ubuntu"
  else
    FASTEST_MIRROR="${fastest_mirror_raw}"
  fi
  export FASTEST_MIRROR
  ```
- **Edge Cases**:
  - **Case 1**: `set -u` + empty result → Variable is empty string (not unset), but logic fails silently
  - **Case 2**: `set -e` + `|| true` → Script continues but invalid state causes later failures
  - **Case 3**: `set -o pipefail` + masked pipeline → Pipeline succeeds but produces invalid output
  - **Case 4**: Strict mode + subshell with masked failure → Subshell exits 0, parent uses invalid result
- **Date Added**: 2025-11-13
- **Frequency**: 0 occurrences (preventive pattern)
- **Related**: Code_check_prompt_manual.txt B3 (STRICT MODE SILENT FAILURE PREVENTION), H4 (SILENT FAILURE PREVENTION)

---

## Pattern Categories

- **Syntax/Compatibility** (3 patterns): Shell version issues, deprecated syntax
- **Performance/Security** (2 patterns): Inefficient patterns, unsafe constructs
- **Configuration/Build** (3 patterns): CMake flags, library conflicts
- **Network/Error Handling** (3 patterns): HTTP error validation, silent failure prevention, strict mode silent failures
- **Testing/Reliability** (1 pattern): Verification approaches
- **Maintainability/Documentation** (1 pattern): Code clarity

---

## Pattern Learning Workflow

### Automatic Pattern Extraction (AI Agent)

When the AI agent solves an error during commit/validation:

1. **Trigger Detection**: Agent identifies error is preventable/recurring
2. **Pattern Analysis**:
   - Extract error type and root cause
   - Identify code pattern that caused it
   - Determine detection method (regex, semantic check, etc.)
   - Document prevention approach
   - Create example (before/after)
3. **Pattern Storage**: Add to this file with unique ID
4. **Integration**: Pattern automatically checked in future code reviews
5. **Frequency Tracking**: Update count when pattern detected again

### Manual Pattern Addition (Developers)

Developers can add patterns manually:

```markdown
### P-YYYYMMDD-NNN: Pattern Title
- **Category**: [Category]
- **Error**: [What went wrong]
- **Root Cause**: [Why it happened]
- **Detection**: [How to find it - regex, command, etc.]
- **Prevention**: [How to fix it]
- **Example**:
  ```[language]
  # WRONG
  [bad code]
  
  # CORRECT
  [good code]
  ```
- **Date Added**: YYYY-MM-DD
- **Frequency**: N occurrences
- **Related**: [Reference to checklist item]
```

### Pattern Evolution

Patterns can be:
- **Refined**: Improve detection or prevention methods
- **Merged**: Combine similar patterns
- **Deprecated**: Mark as no longer relevant (with explanation)
- **Upgraded**: Promote frequent patterns to core checklist

### Pattern ID Format

`P-YYYYMMDD-NNN` where:
- `P`: Pattern prefix
- `YYYYMMDD`: Date pattern was added
- `NNN`: Sequential number (001-999)

---

## Integration Points

### 1. MASTER-RULES-VALIDATION.mdc (Section 3.4)
- Triggers pattern learning during validation
- References this file for pattern checks

### 2. Advanced-CoT-Multi-Agent-Prompt.md (PHASE P)
- Checks all active patterns during code review
- Reports violations with pattern ID and prevention

### 3. Code_check_prompt_manual.txt (Step 3)
- References patterns after main checklist
- Ensures bash-specific patterns are checked

### 4. Pre-commit Hook
- Can be extended to check patterns automatically
- Fast feedback before commit completes

---

## Metrics & Analytics

### Pattern Effectiveness
- Total patterns: 12 (as of 2025-11-13)
- Patterns detected in reviews: Track per pattern
- False positives: Track and refine detection
- Patterns promoted to core checklist: 0 (target: patterns with 20+ occurrences)

### Coverage by Category
- Syntax/Compatibility: 25% (3 patterns)
- Performance/Security: 17% (2 patterns)
- Configuration/Build: 25% (3 patterns)
- Network/Error Handling: 25% (3 patterns)
- Testing/Reliability: 8% (1 pattern)
- Maintainability/Documentation: 8% (1 pattern)

---

## Future Enhancements

- Automated pattern mining from git history
- Pattern confidence scoring and false positive tracking
- Pattern clustering and AI-suggested patterns
- Cross-project pattern sharing
- Pattern testing with unit tests

**Last Updated**: 2025-11-13 | **Next Review**: 2025-11-20
