#!/bin/bash
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

echo -e "${BLUE}===============================================================================${NC}"
echo -e "${BLUE}Python MKL Verification${NC}"
echo -e "${BLUE}===============================================================================${NC}"
echo ""

# Track overall status
OVERALL_STATUS=0

# Function to check Python package MKL linkage
check_python_mkl() {
    local package_name="$1"
    local import_name="${2:-$package_name}"
    local test_code="$3"
    
    echo -e "${YELLOW}Checking ${package_name}...${NC}"
    
    # Check if package can be imported
    if ! python3 -c "import ${import_name}" 2>/dev/null; then
        echo -e "  ${RED}✗ ${package_name} not available${NC}"
        return 1
    fi
    
    # Run verification test
    if python3 -c "${test_code}" 2>/dev/null; then
        echo -e "  ${GREEN}✓ ${package_name} MKL verification passed${NC}"
        return 0
    else
        echo -e "  ${RED}✗ ${package_name} MKL verification failed${NC}"
        return 1
    fi
}

# Test 1: NumPy MKL backend
echo -e "${BLUE}Test 1: NumPy MKL Backend${NC}"
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
    echo -e "  ${GREEN}✓ NumPy MKL backend verified${NC}"
else
    echo -e "  ${RED}✗ NumPy MKL backend not detected${NC}"
    OVERALL_STATUS=1
fi
echo ""

# Test 2: NumPy BLAS functionality
echo -e "${BLUE}Test 2: NumPy BLAS Functionality${NC}"
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
    echo -e "  ${GREEN}✓ NumPy BLAS functionality verified${NC}"
else
    echo -e "  ${RED}✗ NumPy BLAS functionality test failed${NC}"
    OVERALL_STATUS=1
fi
echo ""

# Test 3: SciPy MKL backend
echo -e "${BLUE}Test 3: SciPy MKL Backend${NC}"
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
    echo -e "  ${GREEN}✓ SciPy MKL backend verified${NC}"
else
    echo -e "  ${YELLOW}⚠ SciPy MKL backend not detected (may use system BLAS/LAPACK)${NC}"
    # This is a warning, not a failure, as SciPy may use system BLAS/LAPACK
fi
echo ""

# Test 4: SciPy LAPACK functionality
echo -e "${BLUE}Test 4: SciPy LAPACK Functionality${NC}"
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
    echo -e "  ${GREEN}✓ SciPy LAPACK functionality verified${NC}"
else
    echo -e "  ${RED}✗ SciPy LAPACK functionality test failed${NC}"
    OVERALL_STATUS=1
fi
echo ""

# Test 5: MKL environment variables
echo -e "${BLUE}Test 5: MKL Environment Variables${NC}"
MKL_ENV_OK=true
if [ -z "${MKLROOT:-}" ]; then
    echo -e "  ${YELLOW}⚠ MKLROOT not set${NC}"
    MKL_ENV_OK=false
else
    echo -e "  ${GREEN}✓ MKLROOT: ${MKLROOT}${NC}"
fi

if [ -z "${MKL_THREADING_LAYER:-}" ]; then
    echo -e "  ${YELLOW}⚠ MKL_THREADING_LAYER not set (default: GNU)${NC}"
else
    echo -e "  ${GREEN}✓ MKL_THREADING_LAYER: ${MKL_THREADING_LAYER}${NC}"
fi

if [ -z "${MKL_NUM_THREADS:-}" ]; then
    echo -e "  ${YELLOW}⚠ MKL_NUM_THREADS not set${NC}"
else
    echo -e "  ${GREEN}✓ MKL_NUM_THREADS: ${MKL_NUM_THREADS}${NC}"
fi

if [ "$MKL_ENV_OK" = true ]; then
    echo -e "  ${GREEN}✓ MKL environment variables configured${NC}"
else
    echo -e "  ${YELLOW}⚠ Some MKL environment variables not set${NC}"
fi
echo ""

# Test 6: MKL library availability
echo -e "${BLUE}Test 6: MKL Library Availability${NC}"
if [ -n "${MKLROOT:-}" ] && [ -d "${MKLROOT}/lib/intel64" ]; then
    MKL_LIB_COUNT=$(find "${MKLROOT}/lib/intel64" -name "libmkl*.so" 2>/dev/null | wc -l)
    if [ "${MKL_LIB_COUNT}" -gt 0 ]; then
        echo -e "  ${GREEN}✓ MKL libraries found: ${MKL_LIB_COUNT} libraries${NC}"
        echo -e "  ${GREEN}✓ MKL library directory: ${MKLROOT}/lib/intel64${NC}"
    else
        echo -e "  ${RED}✗ MKL libraries not found in ${MKLROOT}/lib/intel64${NC}"
        OVERALL_STATUS=1
    fi
else
    echo -e "  ${YELLOW}⚠ MKLROOT not set or MKL library directory not found${NC}"
    echo -e "  ${YELLOW}  Expected: /opt/intel/oneapi/mkl/latest/lib/intel64${NC}"
fi
echo ""

# Test 7: Python package linkage (ldd check)
echo -e "${BLUE}Test 7: Python Package MKL Linkage (ldd)${NC}"
PYTHON_LIB_DIR=$(python3 -c "import sys; print(sys.executable)" | xargs dirname)/../lib
NUMPY_SO=$(find "${PYTHON_LIB_DIR}" -name "_multiarray_umath*.so" 2>/dev/null | head -1)

if [ -n "${NUMPY_SO}" ] && [ -f "${NUMPY_SO}" ]; then
    if ldd "${NUMPY_SO}" 2>/dev/null | grep -q "libmkl"; then
        echo -e "  ${GREEN}✓ NumPy is linked against MKL libraries${NC}"
        ldd "${NUMPY_SO}" 2>/dev/null | grep "libmkl" | head -3 | while read -r line; do
            echo -e "    ${GREEN}  ${line}${NC}"
        done
    else
        echo -e "  ${RED}✗ NumPy is NOT linked against MKL libraries${NC}"
        echo -e "  ${YELLOW}  NumPy may be using OpenBLAS or system BLAS${NC}"
        OVERALL_STATUS=1
    fi
else
    echo -e "  ${YELLOW}⚠ NumPy shared library not found for ldd check${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}===============================================================================${NC}"
if [ "${OVERALL_STATUS}" -eq 0 ]; then
    echo -e "${GREEN}✓ Python MKL verification PASSED${NC}"
    echo -e "${GREEN}  All Python packages are using MKL backend${NC}"
    exit 0
else
    echo -e "${RED}✗ Python MKL verification FAILED${NC}"
    echo -e "${RED}  Some Python packages are not using MKL backend${NC}"
    echo -e "${YELLOW}  Note: NumPy/SciPy may use system BLAS/LAPACK if MKL is not properly configured${NC}"
    exit 1
fi
echo -e "${BLUE}===============================================================================${NC}"

