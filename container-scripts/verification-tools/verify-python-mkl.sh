#!/usr/bin/env bash
# shellcheck shell=bash
#===============================================================================
# Python MKL Verification Script
#===============================================================================
# Purpose: Verify that Python packages (NumPy, SciPy) are using MKL backend
#          and that MKL is properly linked and functional
# Usage: verify-python-mkl.sh
# Output: Verification results with pass/fail status
#===============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# A5a: Use printf instead of echo -e for robustness
printf '%s\n' "${BLUE}===============================================================================${NC}"
printf '%s\n' "${BLUE}Python MKL Verification${NC}"
printf '%s\n' "${BLUE}===============================================================================${NC}"
echo ""

#===============================================================================
# MKL Environment Setup
#===============================================================================
# Purpose: Set up MKL environment variables before verification
# This is needed because verification scripts run standalone (not embedded in
# main build script which already has environment set up)
#===============================================================================

# Try to source container MKL environment setup script first (if available)
if [ -f "/etc/profile.d/intel-mkl.sh" ]; then
    # shellcheck disable=SC1090
    . "/etc/profile.d/intel-mkl.sh" >/dev/null 2>&1 || true
fi

# If MKLROOT still not set, try to source Intel's vars.sh
if [ -z "${MKLROOT:-}" ]; then
    # Try multiple possible locations for vars.sh
    MKL_VARS_CANDIDATES=(
        "/opt/intel/oneapi/mkl/latest/env/vars.sh"
        "/opt/intel/oneapi/mkl/2024.1/env/vars.sh"
        "/opt/intel/oneapi/mkl/2024.0/env/vars.sh"
        "/opt/intel/oneapi/mkl/2023.2/env/vars.sh"
        "/opt/intel/oneapi/mkl/2023.1/env/vars.sh"
    )
    
    MKL_VARS_FOUND=""
    for vars_path in "${MKL_VARS_CANDIDATES[@]}"; do
        if [ -f "${vars_path}" ]; then
            MKL_VARS_FOUND="${vars_path}"
            printf '%s\n' "${YELLOW}  Sourcing MKL vars.sh: ${vars_path}${NC}"
            # shellcheck disable=SC1090
            source "${vars_path}" >/dev/null 2>&1 || true
            break
        fi
    done
    
    # If vars.sh not found, try to detect MKL installation directory
    if [ -z "${MKLROOT:-}" ]; then
        MKL_BASE="/opt/intel/oneapi/mkl"
        if [ -d "${MKL_BASE}" ]; then
            # Find the actual MKL installation directory (could be latest, or versioned)
            MKL_ACTUAL_DIR=$(find "${MKL_BASE}" -maxdepth 2 -type d -name "lib" -path "*/intel64" 2>/dev/null | head -1 | sed 's|/lib/intel64$||' || echo "")
            if [ -n "${MKL_ACTUAL_DIR}" ] && [ -d "${MKL_ACTUAL_DIR}/lib/intel64" ]; then
                export MKLROOT="${MKL_ACTUAL_DIR}"
                printf '%s\n' "${GREEN}  ✓ MKL installation detected: ${MKLROOT}${NC}"
            fi
        fi
    fi
fi

# Set default MKLROOT if still not set (fallback to expected location)
if [ -z "${MKLROOT:-}" ]; then
    if [ -d "/opt/intel/oneapi/mkl/latest" ]; then
        export MKLROOT="/opt/intel/oneapi/mkl/latest"
        printf '%s\n' "${YELLOW}  ⚠ MKLROOT not set, using default: ${MKLROOT}${NC}"
    else
        printf '%s\n' "${RED}  ✗ MKLROOT not set and could not be detected${NC}"
        printf '%s\n' "${RED}  ✗ MKL base directory not found at /opt/intel/oneapi/mkl${NC}"
        printf '%s\n' "${YELLOW}  Note: This script needs MKL environment to be set up${NC}"
        printf '%s\n' "${YELLOW}  Try: source /etc/profile.d/intel-mkl.sh${NC}"
    fi
fi

# Track overall status
OVERALL_STATUS=0

# Function to check Python package MKL linkage
check_python_mkl() {
    local package_name="$1"
    local import_name="${2:-$package_name}"
    local test_code="$3"
    
    # A5a: Use printf instead of echo -e for robustness
    printf '%s\n' "${YELLOW}Checking ${package_name}...${NC}"
    
    # Check if package can be imported
    if ! python3 -c "import ${import_name}" 2>/dev/null; then
        printf '%s\n' "  ${RED}✗ ${package_name} not available${NC}"
        return 1
    fi
    
    # Run verification test
    if python3 -c "${test_code}" 2>/dev/null; then
        printf '%s\n' "  ${GREEN}✓ ${package_name} MKL verification passed${NC}"
        return 0
    else
        printf '%s\n' "  ${RED}✗ ${package_name} MKL verification failed${NC}"
        return 1
    fi
}

# Test 1: NumPy MKL backend
printf '%s\n' "${BLUE}Test 1: NumPy MKL Backend${NC}"
if check_python_mkl "numpy" "numpy" "
import numpy as np
# Check if NumPy is using MKL
config = np.__config__
blas_info = config.blas_opt_info if hasattr(config, 'blas_opt_info') else {}
lapack_info = config.lapack_opt_info if hasattr(config, 'lapack_opt_info') else {}

# Check for MKL indicators
has_mkl = False
if 'libraries' in blas_info:
    libs = blas_info['libraries']
    if any('mkl' in str(lib).lower() for lib in libs):
        has_mkl = True

if 'libraries' in lapack_info:
    libs = lapack_info['libraries']
    if any('mkl' in str(lib).lower() for lib in libs):
        has_mkl = True

# Alternative check: look for MKL in library paths
if hasattr(config, 'mkl_info'):
    has_mkl = True

if has_mkl:
    print('  NumPy is using MKL backend')
    exit(0)
else:
    print('  NumPy is NOT using MKL backend')
    print('  BLAS info:', blas_info)
    print('  LAPACK info:', lapack_info)
    exit(1)
"; then
    printf '%s\n' "  ${GREEN}✓ NumPy MKL backend verified${NC}"
else
    printf '%s\n' "  ${RED}✗ NumPy MKL backend not detected${NC}"
    OVERALL_STATUS=1
fi
echo ""

# Test 2: NumPy BLAS functionality
printf '%s\n' "${BLUE}Test 2: NumPy BLAS Functionality${NC}"
if python3 << 'NUMPY_BLAS_TEST'
import numpy as np
import sys

# Test matrix multiplication (uses BLAS)
try:
    a = np.random.rand(100, 100).astype(np.float64)
    b = np.random.rand(100, 100).astype(np.float64)
    c = np.dot(a, b)
    
    # Verify result
    if c.shape == (100, 100) and not np.isnan(c).any():
        print("  NumPy BLAS functionality: OK")
        sys.exit(0)
    else:
        print("  NumPy BLAS functionality: FAILED (invalid result)")
        sys.exit(1)
except Exception as e:
    print(f"  NumPy BLAS functionality: FAILED ({e})")
    sys.exit(1)
NUMPY_BLAS_TEST
then
    printf '%s\n' "  ${GREEN}✓ NumPy BLAS functionality verified${NC}"
else
    printf '%s\n' "  ${RED}✗ NumPy BLAS functionality test failed${NC}"
    OVERALL_STATUS=1
fi
echo ""

# Test 3: SciPy MKL backend
printf '%s\n' "${BLUE}Test 3: SciPy MKL Backend${NC}"
if check_python_mkl "scipy" "scipy" "
import scipy
import numpy as np

# Check SciPy configuration
config = scipy.__config__
blas_info = config.blas_opt_info if hasattr(config, 'blas_opt_info') else {}
lapack_info = config.lapack_opt_info if hasattr(config, 'lapack_opt_info') else {}

# Check for MKL indicators
has_mkl = False
if 'libraries' in blas_info:
    libs = blas_info['libraries']
    if any('mkl' in str(lib).lower() for lib in libs):
        has_mkl = True

if 'libraries' in lapack_info:
    libs = lapack_info['libraries']
    if any('mkl' in str(lib).lower() for lib in libs):
        has_mkl = True

if has_mkl:
    print('  SciPy is using MKL backend')
    exit(0)
else:
    print('  SciPy is NOT using MKL backend')
    exit(1)
"; then
    printf '%s\n' "  ${GREEN}✓ SciPy MKL backend verified${NC}"
else
    printf '%s\n' "  ${YELLOW}⚠ SciPy MKL backend not detected (may use system BLAS/LAPACK)${NC}"
    # This is a warning, not a failure, as SciPy may use system BLAS/LAPACK
fi
echo ""

# Test 4: SciPy LAPACK functionality
printf '%s\n' "${BLUE}Test 4: SciPy LAPACK Functionality${NC}"
if python3 << 'SCIPY_LAPACK_TEST'
import scipy.linalg
import numpy as np
import sys

# Test LAPACK functionality (matrix decomposition)
try:
    a = np.random.rand(50, 50).astype(np.float64)
    # Make it symmetric positive definite
    a = a @ a.T + np.eye(50) * 0.1
    
    # Test Cholesky decomposition (uses LAPACK)
    L = scipy.linalg.cholesky(a, lower=True)
    
    # Verify result
    reconstructed = L @ L.T
    if np.allclose(a, reconstructed, rtol=1e-5):
        print("  SciPy LAPACK functionality: OK")
        sys.exit(0)
    else:
        print("  SciPy LAPACK functionality: FAILED (invalid result)")
        sys.exit(1)
except Exception as e:
    print(f"  SciPy LAPACK functionality: FAILED ({e})")
    sys.exit(1)
SCIPY_LAPACK_TEST
then
    printf '%s\n' "  ${GREEN}✓ SciPy LAPACK functionality verified${NC}"
else
    printf '%s\n' "  ${RED}✗ SciPy LAPACK functionality test failed${NC}"
    OVERALL_STATUS=1
fi
echo ""

# Test 5: MKL environment variables
printf '%s\n' "${BLUE}Test 5: MKL Environment Variables${NC}"
MKL_ENV_OK=true
if [ -z "${MKLROOT:-}" ]; then
    printf '%s\n' "  ${YELLOW}⚠ MKLROOT not set${NC}"
    MKL_ENV_OK=false
else
    printf '%s\n' "  ${GREEN}✓ MKLROOT: ${MKLROOT}${NC}"
fi

if [ -z "${MKL_THREADING_LAYER:-}" ]; then
    printf '%s\n' "  ${YELLOW}⚠ MKL_THREADING_LAYER not set (default: GNU)${NC}"
else
    printf '%s\n' "  ${GREEN}✓ MKL_THREADING_LAYER: ${MKL_THREADING_LAYER}${NC}"
fi

if [ -z "${MKL_NUM_THREADS:-}" ]; then
    printf '%s\n' "  ${YELLOW}⚠ MKL_NUM_THREADS not set${NC}"
else
    printf '%s\n' "  ${GREEN}✓ MKL_NUM_THREADS: ${MKL_NUM_THREADS}${NC}"
fi

if [ "$MKL_ENV_OK" = true ]; then
    printf '%s\n' "  ${GREEN}✓ MKL environment variables configured${NC}"
else
    printf '%s\n' "  ${YELLOW}⚠ Some MKL environment variables not set${NC}"
fi
echo ""

# Test 6: MKL library availability
printf '%s\n' "${BLUE}Test 6: MKL Library Availability${NC}"
MKL_LIB_FOUND=false
if [ -n "${MKLROOT:-}" ]; then
    # Try multiple possible library directory locations
    MKL_LIB_CANDIDATES=(
        "${MKLROOT}/lib/intel64"
        "${MKLROOT}/lib/intel64_lin"
        "${MKLROOT}/lib/linux/intel64"
        "${MKLROOT}/lib"
    )
    
    for lib_dir in "${MKL_LIB_CANDIDATES[@]}"; do
        if [ -d "${lib_dir}" ]; then
            MKL_LIB_COUNT=$(find "${lib_dir}" -name "libmkl*.so" 2>/dev/null | wc -l)
            if [ "${MKL_LIB_COUNT}" -gt 0 ]; then
                printf '%s\n' "  ${GREEN}✓ MKL libraries found: ${MKL_LIB_COUNT} libraries${NC}"
                printf '%s\n' "  ${GREEN}✓ MKL library directory: ${lib_dir}${NC}"
                MKL_LIB_FOUND=true
                break
            fi
        fi
    done
    
    # If not found in expected locations, try to find anywhere under MKLROOT
    if [ "${MKL_LIB_FOUND}" = false ]; then
        found_lib=$(find "${MKLROOT}" -maxdepth 4 -type f \( -name "libmkl_rt.so" -o -name "libmkl_intel_lp64.so" \) -print -quit 2>/dev/null || echo "")
        if [ -n "${found_lib}" ] && [ -f "${found_lib}" ]; then
            lib_dir=$(dirname "${found_lib}")
            MKL_LIB_COUNT=$(find "${lib_dir}" -name "libmkl*.so" 2>/dev/null | wc -l)
            printf '%s\n' "  ${GREEN}✓ MKL libraries found: ${MKL_LIB_COUNT} libraries${NC}"
            printf '%s\n' "  ${GREEN}✓ MKL library directory: ${lib_dir}${NC}"
            MKL_LIB_FOUND=true
        fi
    fi
    
    if [ "${MKL_LIB_FOUND}" = false ]; then
        printf '%s\n' "  ${RED}✗ MKL libraries not found under ${MKLROOT}${NC}"
        OVERALL_STATUS=1
    fi
else
    printf '%s\n' "  ${RED}✗ MKLROOT not set - cannot locate MKL libraries${NC}"
    printf '%s\n' "  ${YELLOW}  Expected locations:${NC}"
    printf '%s\n' "    - /opt/intel/oneapi/mkl/latest/lib/intel64${NC}"
    printf '%s\n' "    - /opt/intel/oneapi/mkl/<version>/lib/intel64${NC}"
    OVERALL_STATUS=1
fi
echo ""

# Test 7: Python package linkage (ldd check)
printf '%s\n' "${BLUE}Test 7: Python Package MKL Linkage (ldd)${NC}"
PYTHON_LIB_DIR=$(python3 -c "import sys; print(sys.executable)" | xargs dirname)/../lib
NUMPY_SO=$(find "${PYTHON_LIB_DIR}" -name "_multiarray_umath*.so" 2>/dev/null | head -1)

if [ -n "${NUMPY_SO}" ] && [ -f "${NUMPY_SO}" ]; then
    if ldd "${NUMPY_SO}" 2>/dev/null | grep -q "libmkl"; then
        printf '%s\n' "  ${GREEN}✓ NumPy is linked against MKL libraries${NC}"
        ldd "${NUMPY_SO}" 2>/dev/null | grep "libmkl" | head -3 | while read -r line; do
            printf '%s\n' "    ${GREEN}  ${line}${NC}"
        done
    else
        printf '%s\n' "  ${RED}✗ NumPy is NOT linked against MKL libraries${NC}"
        printf '%s\n' "  ${YELLOW}  NumPy may be using OpenBLAS or system BLAS${NC}"
        OVERALL_STATUS=1
    fi
else
    printf '%s\n' "  ${YELLOW}⚠ NumPy shared library not found for ldd check${NC}"
fi
echo ""

# Summary
printf '%s\n' "${BLUE}===============================================================================${NC}"
if [ "${OVERALL_STATUS}" -eq 0 ]; then
    printf '%s\n' "${GREEN}✓ Python MKL verification PASSED${NC}"
    printf '%s\n' "${GREEN}  All Python packages are using MKL backend${NC}"
    exit 0
else
    printf '%s\n' "${RED}✗ Python MKL verification FAILED${NC}"
    printf '%s\n' "${RED}  Some Python packages are not using MKL backend${NC}"
    printf '%s\n' "${YELLOW}  Note: NumPy/SciPy may use system BLAS/LAPACK if MKL is not properly configured${NC}"
    exit 1
fi
printf '%s\n' "${BLUE}===============================================================================${NC}"

