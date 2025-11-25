# MKL Installation Analysis: Working vs Current Version

## Executive Summary

**Working Version (Commit 2c97007)**: Simple, inline MKL installation that created `/etc/profile.d/intel-mkl.sh` directly in the installation block.

**Current Version**: Complex installation that depends on `container-scripts/install.sh` to install `/etc/profile.d/intel-mkl.sh` in BLOCK 0, with extensive error handling and dynamic directory discovery.

**Root Cause**: The current version has a **hard dependency** on BLOCK 0 successfully installing `/etc/profile.d/intel-mkl.sh`, but if BLOCK 0 fails or the file isn't installed, BLOCK 12A will exit with error (line 4910-4911).

---

## Detailed Comparison

### 1. File Creation Approach

#### Working Version (2c97007)
```bash
# Created /etc/profile.d/intel-mkl.sh inline using heredoc
cat > /etc/profile.d/intel-mkl.sh <<'EOF'
#!/bin/bash
# Intel MKL environment setup (auto-generated)
MKLROOT=/opt/intel/oneapi/mkl/latest
export MKLROOT
# ... rest of config ...
EOF
chmod +x /etc/profile.d/intel-mkl.sh
source /etc/profile.d/intel-mkl.sh
```

**Advantages:**
- ✅ File is always created (no external dependency)
- ✅ Simple, straightforward
- ✅ Works even if container-scripts installation fails

#### Current Version
```bash
# Expects file to be installed by container-scripts/install.sh in BLOCK 0
# Source: shell-scripts/block-11-apt-aria-wrapper-setup-must-be-before-nvidia/intel-mkl-environment-setup.sh
# Target: /etc/profile.d/intel-mkl.sh
# Installed in Block 0 (early in script, before any scripts are needed)

# Verify file was installed successfully
if [ ! -f /etc/profile.d/intel-mkl.sh ]; then
    echo "[ERROR] ⚠ intel-mkl.sh file not found after installation"
    exit 1  # HARD EXIT - BLOCKS BUILD
fi
```

**Issues:**
- ❌ Hard dependency on BLOCK 0 success
- ❌ If `container-scripts/install.sh` fails, build fails
- ❌ No fallback to create file inline

---

### 2. vars.sh Handling

#### Working Version (2c97007)
```bash
MKL_ENV_SCRIPT="/opt/intel/oneapi/mkl/latest/env/vars.sh"
if [ ! -f "${MKL_ENV_SCRIPT}" ]; then
    echo -e "  ${RED}✗ Expected MKL environment script not found at ${MKL_ENV_SCRIPT}${NC}"
    exit 1
fi
source "${MKL_ENV_SCRIPT}"
```

**Behavior:**
- Simple check for fixed path
- Exit if not found (strict)

#### Current Version
```bash
# Search for MKL environment script in common locations
MKL_ENV_CANDIDATES=(
    "/opt/intel/oneapi/mkl/latest/env/vars.sh"
    "/opt/intel/oneapi/mkl/2025.3/env/vars.sh"
    "/opt/intel/oneapi/mkl/2025.2/env/vars.sh"
    # ... multiple versions ...
)

# Try to find vars.sh script
for candidate in "${MKL_ENV_CANDIDATES[@]}"; do
    if [ -f "${candidate}" ]; then
        MKL_ENV_SCRIPT="${candidate}"
        break
    fi
done

# If vars.sh not found, check if MKL is installed via alternative method
if [ -z "${MKL_ENV_SCRIPT}" ]; then
    # Complex fallback logic with directory discovery
    # ...
fi
```

**Behavior:**
- Multiple candidate paths (supports versioned layouts)
- Graceful fallback if vars.sh missing
- More complex but more robust

---

### 3. Error Handling Complexity

#### Working Version (2c97007)
- Simple `curl` for GPG key download
- Basic error checks
- Straightforward flow

#### Current Version
- HTTP status code validation for GPG key download
- Multiple verification steps
- Extensive error messages
- File existence checks at every step
- **Potential issue**: Too many exit points can cause premature failures

---

### 4. Directory Discovery

#### Working Version (2c97007)
```bash
MKLROOT="/opt/intel/oneapi/mkl/latest"  # Fixed path
MKL_LIB_DIR="${MKLROOT}/lib/intel64"
MKL_INCLUDE_DIR="${MKLROOT}/include"
```

**Behavior:**
- Fixed paths
- Simple, predictable

#### Current Version
```bash
# Dynamic MKL directory discovery (supports versioned layouts like 2025.3)
MKL_INCLUDE_CANDIDATES=(
    "${MKLROOT}/include"
    "${MKLROOT}/../include"
    "${MKLROOT}/../../include"
)
MKL_LIB_CANDIDATES=(
    "${MKLROOT}/lib/intel64"
    "${MKLROOT}/lib/intel64_lin"
    "${MKLROOT}/lib/linux/intel64"
    # ... multiple candidates ...
)

# Search through candidates
for candidate in "${MKL_INCLUDE_CANDIDATES[@]}"; do
    if [ -d "${candidate}" ] && [ -f "${candidate}/mkl_cblas.h" ]; then
        MKL_INCLUDE_DIR="$(realpath -m "${candidate}")"
        break
    fi
done

# Fallback to find command if candidates don't work
if [ -z "${MKL_INCLUDE_DIR}" ]; then
    found_include=$(find "${MKLROOT}" -maxdepth 4 -type f -name "mkl_cblas.h" -print -quit 2>/dev/null || echo "")
    # ...
fi
```

**Behavior:**
- Dynamic discovery
- Supports versioned layouts (2025.3, 2025.2, etc.)
- Multiple fallback paths
- More complex but handles different installation structures

---

## Failure Analysis

### Primary Failure Point

**Line 4909-4911 in current version:**
```bash
if [ ! -f /etc/profile.d/intel-mkl.sh ]; then
    echo "[ERROR] ⚠ intel-mkl.sh file not found after installation"
    exit 1  # HARD EXIT
fi
```

**Why this fails:**
1. BLOCK 0 runs `container-scripts/install.sh --all`
2. If `install.sh` fails or doesn't install the file, `/etc/profile.d/intel-mkl.sh` won't exist
3. BLOCK 12A checks for the file and exits if not found
4. **No fallback** to create the file inline (unlike working version)

### Secondary Failure Points

1. **GPG Key Download** (lines 4655-4686):
   - HTTP status code validation may be too strict
   - Network issues could cause failures

2. **vars.sh Discovery** (lines 4851-4898):
   - Complex fallback logic may have edge cases
   - If MKL is installed but structure differs, could fail

3. **Directory Discovery** (lines 4950-5018):
   - Multiple candidates and fallbacks
   - If all candidates fail, exits with error

---

## Root Cause Summary

1. **Architectural Change**: Moved from inline file creation to external installation dependency
2. **Missing Fallback**: No fallback to create `/etc/profile.d/intel-mkl.sh` if BLOCK 0 fails
3. **Over-Engineering**: Too much complexity for simple file creation
4. **Hard Dependencies**: Multiple hard exits without graceful degradation

---

## Fix Plan

### Option 1: Add Fallback (Recommended)
**Restore inline file creation as fallback if container-scripts installation fails**

```bash
# Try to use container-scripts installed file first
if [ -f /etc/profile.d/intel-mkl.sh ]; then
    echo "✓ Using container-scripts installed intel-mkl.sh"
    source /etc/profile.d/intel-mkl.sh
else
    echo "⚠ intel-mkl.sh not found from container-scripts, creating inline..."
    # Create file inline (like working version)
    cat > /etc/profile.d/intel-mkl.sh <<'EOF'
#!/bin/bash
# Intel MKL environment setup (auto-generated)
MKLROOT=/opt/intel/oneapi/mkl/latest
export MKLROOT
# ... rest of config ...
EOF
    chmod +x /etc/profile.d/intel-mkl.sh
    source /etc/profile.d/intel-mkl.sh
fi
```

**Advantages:**
- ✅ Maintains container-scripts approach (preferred)
- ✅ Fallback ensures build doesn't fail
- ✅ Best of both worlds

### Option 2: Simplify vars.sh Handling
**Make vars.sh optional (it's already handled by /etc/profile.d/intel-mkl.sh)**

```bash
# vars.sh is optional - /etc/profile.d/intel-mkl.sh handles environment
if [ -f "${MKL_ENV_SCRIPT}" ]; then
    source "${MKL_ENV_SCRIPT}"  # Optional enhancement
else
    echo "⚠ vars.sh not found (using /etc/profile.d/intel-mkl.sh instead)"
fi
```

### Option 3: Improve BLOCK 0 Error Handling
**Ensure container-scripts installation is more robust**

- Add verification that `/etc/profile.d/intel-mkl.sh` was installed
- If not, create it inline in BLOCK 0
- Report warnings but don't fail build

### Option 4: Hybrid Approach (Best)
**Combine all three options:**
1. Improve BLOCK 0 to verify file installation
2. Add fallback in BLOCK 12A to create file if missing
3. Make vars.sh optional (non-blocking)

---

## Recommended Implementation

1. **Immediate Fix**: Add fallback in BLOCK 12A (Option 1)
2. **Short-term**: Make vars.sh optional (Option 2)
3. **Long-term**: Improve BLOCK 0 verification (Option 3)

This ensures:
- ✅ Build doesn't fail if container-scripts installation has issues
- ✅ Maintains preferred container-scripts approach
- ✅ Graceful degradation
- ✅ Backward compatibility with working version logic

---

## Testing Plan

1. **Test Case 1**: Normal flow (container-scripts installs file)
   - Verify file exists from BLOCK 0
   - Verify BLOCK 12A uses it

2. **Test Case 2**: BLOCK 0 failure (file not installed)
   - Simulate BLOCK 0 failure
   - Verify BLOCK 12A creates file inline
   - Verify build continues

3. **Test Case 3**: vars.sh missing
   - Install MKL without vars.sh
   - Verify build continues (uses /etc/profile.d/intel-mkl.sh)

4. **Test Case 4**: Versioned MKL layout (2025.3)
   - Install MKL with versioned directory
   - Verify dynamic discovery works

---

## Conclusion

The current version is **over-engineered** compared to the working version. While it adds useful features (versioned layout support, better error handling), it introduces **hard dependencies** that can cause build failures.

**The fix is simple**: Add a fallback to create `/etc/profile.d/intel-mkl.sh` inline if container-scripts installation fails. This maintains the preferred approach while ensuring builds don't fail unnecessarily.

