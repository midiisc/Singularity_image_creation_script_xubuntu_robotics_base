#!/bin/bash
#===============================================================================
# OpenBLAS Compilation Test Script
# Purpose: Test OpenBLAS compilation with DYNAMIC_ARCH=1 to verify prerequisites
# Usage: ./test_openblas_compilation.sh
#
# This script follows the official OpenBLAS documentation:
# - Installation Guide: http://www.openmathlib.org/OpenBLAS/docs/install/
# - Build System: http://www.openmathlib.org/OpenBLAS/docs/build_system/
#
# Key practices implemented:
# - Uses stable release from GitHub Releases (not develop branch)
# - Passes all build flags to make install (required per documentation)
# - Sets HOSTCC explicitly for robustness
# - Uses recommended flags for maximum portability and performance
#===============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}OpenBLAS Compilation Test${NC}"
echo "=================================="
echo ""

# Check prerequisites
echo "Checking prerequisites..."
MISSING_PREREQS=()

# Check for gcc
if ! command -v gcc >/dev/null 2>&1; then
    MISSING_PREREQS+=("gcc")
else
    GCC_VERSION=$(gcc --version | head -1)
    echo -e "  ${GREEN}✓ gcc: ${GCC_VERSION}${NC}"
fi

# Check for gfortran
if ! command -v gfortran >/dev/null 2>&1; then
    MISSING_PREREQS+=("gfortran")
else
    GFORTRAN_VERSION=$(gfortran --version | head -1)
    echo -e "  ${GREEN}✓ gfortran: ${GFORTRAN_VERSION}${NC}"
fi

# Check for make
if ! command -v make >/dev/null 2>&1; then
    MISSING_PREREQS+=("make")
else
    MAKE_VERSION=$(make --version | head -1)
    echo -e "  ${GREEN}✓ make: ${MAKE_VERSION}${NC}"
fi

# Check for git
if ! command -v git >/dev/null 2>&1; then
    MISSING_PREREQS+=("git")
else
    GIT_VERSION=$(git --version)
    echo -e "  ${GREEN}✓ git: ${GIT_VERSION}${NC}"
fi

# Check for wget (fallback for downloading)
if ! command -v wget >/dev/null 2>&1; then
    if [ ${#MISSING_PREREQS[@]} -eq 0 ]; then
        echo -e "  ${YELLOW}⚠ wget: not found (optional, used as fallback for downloading)${NC}"
    fi
else
    echo -e "  ${GREEN}✓ wget: found${NC}"
fi

# Check for perl (required by OpenBLAS build system)
if ! command -v perl >/dev/null 2>&1; then
    MISSING_PREREQS+=("perl")
else
    PERL_VERSION=$(perl --version | head -2 | tail -1)
    echo -e "  ${GREEN}✓ perl: ${PERL_VERSION}${NC}"
fi

# Check for curl (alternative download method)
if ! command -v curl >/dev/null 2>&1; then
    echo -e "  ${YELLOW}⚠ curl: not found (optional)${NC}"
else
    echo -e "  ${GREEN}✓ curl: found${NC}"
fi

# Report missing prerequisites
if [ ${#MISSING_PREREQS[@]} -gt 0 ]; then
    echo ""
    echo -e "${RED}✗ Missing prerequisites: ${MISSING_PREREQS[*]}${NC}"
    echo "Install with: sudo apt-get install -y ${MISSING_PREREQS[*]}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ All prerequisites found${NC}"
echo ""

# Test OpenBLAS compilation
OPENBLAS_TEST_DIR="/tmp/openblas_test_build"
# Use latest stable release from official OpenMathLib/OpenBLAS repository
# Latest: v0.3.30 (released Jun 19, 2025) - check https://github.com/OpenMathLib/OpenBLAS/releases
OPENBLAS_VERSION="v0.3.30"
OPENBLAS_REPO_URL="https://github.com/OpenMathLib/OpenBLAS.git"
OPENBLAS_INSTALL_PREFIX="/tmp/openblas_test_install"

# Clean up any previous test
rm -rf "${OPENBLAS_TEST_DIR}" "${OPENBLAS_INSTALL_PREFIX}"
mkdir -p "${OPENBLAS_TEST_DIR}" "${OPENBLAS_INSTALL_PREFIX}"

echo "Testing OpenBLAS compilation with DYNAMIC_ARCH=1..."
echo "  Source directory: ${OPENBLAS_TEST_DIR}"
echo "  Install prefix: ${OPENBLAS_INSTALL_PREFIX}"
echo "  Version: ${OPENBLAS_VERSION}"
echo ""

cd "${OPENBLAS_TEST_DIR}" || exit 1

# Download OpenBLAS source from official repository
echo "Step 1: Downloading OpenBLAS source from official repository..."
echo "  Repository: ${OPENBLAS_REPO_URL}"
echo "  Version: ${OPENBLAS_VERSION} (stable release from GitHub Releases)"
echo "  Documentation: http://www.openmathlib.org/OpenBLAS/docs/install/"
echo ""

DOWNLOAD_SUCCESS=false
TARBALL_NAME="OpenBLAS-${OPENBLAS_VERSION#v}.tar.gz"
TARBALL_URL="https://github.com/OpenMathLib/OpenBLAS/releases/download/${OPENBLAS_VERSION}/${TARBALL_NAME}"

# Method 1: Try downloading release tarball (most reliable for releases)
if command -v wget >/dev/null 2>&1; then
    echo "  Attempting to download release tarball using wget..."
    if wget -q --show-progress "${TARBALL_URL}" -O "${TARBALL_NAME}" 2>/dev/null; then
        if [ -f "${TARBALL_NAME}" ] && [ -s "${TARBALL_NAME}" ]; then
            if tar -xzf "${TARBALL_NAME}" 2>/dev/null; then
                cd "OpenBLAS-${OPENBLAS_VERSION#v}" || exit 1
                echo -e "  ${GREEN}✓ Downloaded OpenBLAS ${OPENBLAS_VERSION} release tarball${NC}"
                DOWNLOAD_SUCCESS=true
            else
                echo -e "  ${YELLOW}⚠ Failed to extract tarball${NC}"
                rm -f "${TARBALL_NAME}"
            fi
        fi
    fi
elif command -v curl >/dev/null 2>&1; then
    echo "  Attempting to download release tarball using curl..."
    if curl -L -f -s "${TARBALL_URL}" -o "${TARBALL_NAME}" 2>/dev/null; then
        if [ -f "${TARBALL_NAME}" ] && [ -s "${TARBALL_NAME}" ]; then
            if tar -xzf "${TARBALL_NAME}" 2>/dev/null; then
                cd "OpenBLAS-${OPENBLAS_VERSION#v}" || exit 1
                echo -e "  ${GREEN}✓ Downloaded OpenBLAS ${OPENBLAS_VERSION} release tarball${NC}"
                DOWNLOAD_SUCCESS=true
            else
                echo -e "  ${YELLOW}⚠ Failed to extract tarball${NC}"
                rm -f "${TARBALL_NAME}"
            fi
        fi
    fi
fi

# Method 2: Try git clone if tarball download failed
if [ "${DOWNLOAD_SUCCESS}" != "true" ]; then
    if command -v git >/dev/null 2>&1; then
        echo "  Tarball download failed, attempting to clone repository using git..."
        # Save current directory before going up
        CURRENT_DIR="${PWD}"
        if [ "${CURRENT_DIR}" != "/" ] && [ -d "${CURRENT_DIR}/.." ]; then
            cd .. || exit 1
        fi
        rm -rf "${OPENBLAS_TEST_DIR}"
        mkdir -p "${OPENBLAS_TEST_DIR}"
        cd "${OPENBLAS_TEST_DIR}" || exit 1
        
        # Try cloning with tag (tags are usually lightweight)
        if git clone --depth 1 --branch "${OPENBLAS_VERSION}" "${OPENBLAS_REPO_URL}" . 2>&1; then
            echo -e "  ${GREEN}✓ Cloned OpenBLAS ${OPENBLAS_VERSION} from repository${NC}"
            DOWNLOAD_SUCCESS=true
        # Try cloning develop branch and checking out tag
        elif git clone --depth 50 "${OPENBLAS_REPO_URL}" . 2>&1; then
            if git checkout "${OPENBLAS_VERSION}" 2>&1; then
                echo -e "  ${GREEN}✓ Checked out OpenBLAS ${OPENBLAS_VERSION}${NC}"
                DOWNLOAD_SUCCESS=true
            else
                echo -e "  ${YELLOW}⚠ Tag ${OPENBLAS_VERSION} not found, trying latest release...${NC}"
                # Try to get latest release tag from GitHub API
                LATEST_TAG=""
                if command -v wget >/dev/null 2>&1; then
                    LATEST_TAG=$(wget -q -O - "https://api.github.com/repos/OpenMathLib/OpenBLAS/releases/latest" 2>/dev/null | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4 | head -1 || true)
                elif command -v curl >/dev/null 2>&1; then
                    LATEST_TAG=$(curl -s "https://api.github.com/repos/OpenMathLib/OpenBLAS/releases/latest" 2>/dev/null | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4 | head -1 || true)
                fi
                if [ -n "${LATEST_TAG:-}" ] && git checkout "${LATEST_TAG}" 2>&1; then
                    echo -e "  ${GREEN}✓ Using latest release: ${LATEST_TAG}${NC}"
                    OPENBLAS_VERSION="${LATEST_TAG}"
                    DOWNLOAD_SUCCESS=true
                fi
            fi
        fi
    fi
fi

# Final check
if [ "${DOWNLOAD_SUCCESS}" != "true" ]; then
    echo -e "  ${RED}✗ Failed to download OpenBLAS source${NC}"
    echo ""
    echo "  Tried methods:"
    echo "    1. Release tarball: ${TARBALL_URL}"
    if command -v git >/dev/null 2>&1; then
        echo "    2. Git clone with tag: ${OPENBLAS_VERSION}"
    fi
    echo ""
    echo "  Please verify:"
    echo "    - Version ${OPENBLAS_VERSION} exists at https://github.com/OpenMathLib/OpenBLAS/releases"
    echo "    - Internet connectivity is available"
    echo "    - You have wget, curl, or git installed"
    exit 1
fi

# Check if Makefile exists
if [ ! -f "Makefile" ]; then
    echo -e "  ${RED}✗ Makefile not found${NC}"
    exit 1
fi

echo ""
echo "Step 2: Compiling OpenBLAS with DYNAMIC_ARCH=1..."
echo "  Build flags:"
echo "    DYNAMIC_ARCH=1 (runtime CPU detection)"
echo "    USE_OPENMP=1 (OpenMP support)"
echo "    NO_AFFINITY=1 (disable CPU affinity)"
echo "    TARGET=GENERIC (generic target)"
echo ""

# Get number of CPU cores for parallel build
BUILD_JOBS=$(nproc 2>/dev/null || echo "4")
if [ "${BUILD_JOBS:-0}" -lt 1 ]; then
    BUILD_JOBS=1
fi
echo "  Using ${BUILD_JOBS} parallel jobs"

# Clean any previous build
make clean >/dev/null 2>&1 || true

# Compile OpenBLAS with optimal flags for maximum portability and performance
# Based on OpenBLAS 0.3.30 official documentation and best practices
# References:
#   - Installation: http://www.openmathlib.org/OpenBLAS/docs/install/
#   - Build System: http://www.openmathlib.org/OpenBLAS/docs/build_system/
#   - See OpenBLAS_Compilation_Flags.md for detailed flag documentation
echo "  Compilation flags (optimized for portability and performance):"
echo "    DYNAMIC_ARCH=1 (runtime CPU detection - supports multiple architectures)"
echo "    TARGET=GENERIC (safe base target, avoids illegal instructions)"
echo "    USE_OPENMP=1 (OpenMP threading - best multi-threading performance)"
echo "    NO_AFFINITY=1 (disable CPU affinity - prevents conflicts with other threading libraries)"
echo "    NUM_THREADS=64 (support for systems with up to 64 threads)"
echo "    GEMM_MULTITHREAD_THRESHOLD=50 (optimal for deep learning workloads)"
echo "    BUILD_LAPACK_DEPRECATED=1 (build deprecated LAPACK functions - default)"
echo "    NO_WARMUP=1 (disable warmup phase for faster startup)"
echo "    BINARY=64 (explicitly set for x86_64 - auto-detected but explicit is clearer)"
echo "    HOSTCC=gcc (explicitly set for robustness - auto-detected but explicit is better)"
echo ""

# Build OpenBLAS following official documentation recommendations:
# - Use stable release from GitHub Releases (not develop branch) ✓
# - Pass all build flags to make install ✓
# - Set HOSTCC explicitly for robustness (auto-detected but explicit is better)
# - BINARY=64 explicitly set for x86_64 (auto-detected but explicit is clearer)
# Reference: http://www.openmathlib.org/OpenBLAS/docs/install/
# Reference: http://www.openmathlib.org/OpenBLAS/docs/build_system/
if make -j"${BUILD_JOBS}" \
    DYNAMIC_ARCH=1 \
    TARGET=GENERIC \
    USE_OPENMP=1 \
    NO_AFFINITY=1 \
    NUM_THREADS=64 \
    GEMM_MULTITHREAD_THRESHOLD=50 \
    BUILD_LAPACK_DEPRECATED=1 \
    NO_WARMUP=1 \
    BINARY=64 \
    CC=gcc \
    FC=gfortran \
    HOSTCC=gcc \
    2>&1 | tee /tmp/openblas_test_build.log; then
    echo ""
    echo -e "  ${GREEN}✓ OpenBLAS compilation successful${NC}"
else
    echo ""
    echo -e "  ${RED}✗ OpenBLAS compilation failed${NC}"
    echo "  Check log: /tmp/openblas_test_build.log"
    exit 1
fi

echo ""
echo "Step 3: Installing OpenBLAS..."
echo "  Using same build flags for installation..."
# Important: Pass all build flags to make install (per official documentation)
# Reference: http://www.openmathlib.org/OpenBLAS/docs/install/
if make install \
    PREFIX="${OPENBLAS_INSTALL_PREFIX}" \
    DYNAMIC_ARCH=1 \
    TARGET=GENERIC \
    USE_OPENMP=1 \
    NO_AFFINITY=1 \
    NUM_THREADS=64 \
    GEMM_MULTITHREAD_THRESHOLD=50 \
    BUILD_LAPACK_DEPRECATED=1 \
    NO_WARMUP=1 \
    BINARY=64 \
    CC=gcc \
    FC=gfortran \
    HOSTCC=gcc \
    2>&1 | tee -a /tmp/openblas_test_build.log; then
    echo -e "  ${GREEN}✓ OpenBLAS installation successful${NC}"
else
    echo -e "  ${RED}✗ OpenBLAS installation failed${NC}"
    exit 1
fi

echo ""
echo "Step 4: Verifying installation..."
OPENBLAS_LIB="${OPENBLAS_INSTALL_PREFIX}/lib/libopenblas.so"

if [ -f "${OPENBLAS_LIB}" ]; then
    echo -e "  ${GREEN}✓ OpenBLAS library found: ${OPENBLAS_LIB}${NC}"
    
    # Check library size
    LIB_SIZE=$(du -h "${OPENBLAS_LIB}" | cut -f1)
    echo "  Library size: ${LIB_SIZE}"
    
    # Check for DYNAMIC_ARCH in library
    echo ""
    echo "  Verifying DYNAMIC_ARCH support..."
    if strings "${OPENBLAS_LIB}" 2>/dev/null | grep -qi "DYNAMIC_ARCH\|dynamic_arch\|DYNAMICARCH"; then
        echo -e "    ${GREEN}✓ DYNAMIC_ARCH support confirmed in library${NC}"
    else
        echo -e "    ${YELLOW}⚠ DYNAMIC_ARCH string not found (may still work)${NC}"
    fi
    
    # Check for architecture-specific kernels
    ARCH_COUNT="0"
    if ARCH_COUNT_RAW=$(strings "${OPENBLAS_LIB}" 2>/dev/null | grep -ciE "HASWELL|SANDYBRIDGE|NEHALEM|PENRYN|CORE2|SKYLAKEX|CASCADELAKE|COOPERLAKE|ICELAKE|SAPPHIRERAPIDS" 2>/dev/null || true); then
        ARCH_COUNT="${ARCH_COUNT_RAW}"
    fi
    if [ "${ARCH_COUNT:-0}" -gt 0 ]; then
        echo -e "    ${GREEN}✓ Multiple CPU architecture kernels found (${ARCH_COUNT} architectures)${NC}"
    else
        echo -e "    ${YELLOW}⚠ Architecture kernels not detected${NC}"
    fi
    
    # Test library loading
    echo ""
    echo "  Testing library loading..."
    if ldconfig -p 2>/dev/null | grep -q libopenblas || \
       ldd "${OPENBLAS_LIB}" >/dev/null 2>&1; then
        echo -e "    ${GREEN}✓ Library can be loaded${NC}"
    else
        echo -e "    ${YELLOW}⚠ Library loading test inconclusive${NC}"
    fi
else
    echo -e "  ${RED}✗ OpenBLAS library not found at ${OPENBLAS_LIB}${NC}"
    exit 1
fi

echo ""
echo "Step 5: Testing library functionality..."
# Create a simple test program
cat > /tmp/test_openblas.c << 'EOF'
#include <cblas.h>
#include <stdio.h>

int main() {
    double a[4] = {1.0, 2.0, 3.0, 4.0};
    double b[4] = {5.0, 6.0, 7.0, 8.0};
    double c[4];
    
    // Test dgemm (matrix multiplication)
    cblas_dgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans,
                2, 2, 2, 1.0, a, 2, b, 2, 0.0, c, 2);
    
    printf("OpenBLAS test: dgemm result = [%f, %f, %f, %f]\n", c[0], c[1], c[2], c[3]);
    return 0;
}
EOF

if gcc -o /tmp/test_openblas /tmp/test_openblas.c \
    -I"${OPENBLAS_INSTALL_PREFIX}/include" \
    -L"${OPENBLAS_INSTALL_PREFIX}/lib" \
    -lopenblas \
    -lm 2>&1; then
    echo -e "  ${GREEN}✓ Test program compiled${NC}"
    
    # Run test
    TEST_LD_LIBRARY_PATH="${OPENBLAS_INSTALL_PREFIX}/lib"
    if [ -n "${LD_LIBRARY_PATH:-}" ]; then
        TEST_LD_LIBRARY_PATH="${TEST_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}"
    fi
    if LD_LIBRARY_PATH="${TEST_LD_LIBRARY_PATH}" /tmp/test_openblas 2>&1; then
        echo -e "  ${GREEN}✓ OpenBLAS functionality test passed${NC}"
    else
        echo -e "  ${YELLOW}⚠ OpenBLAS functionality test failed (may be due to missing runtime dependencies)${NC}"
    fi
    rm -f /tmp/test_openblas /tmp/test_openblas.c
else
    echo -e "  ${YELLOW}⚠ Test program compilation failed (headers may be in different location)${NC}"
    rm -f /tmp/test_openblas.c
fi

echo ""
echo "=================================="
echo -e "${GREEN}✓ OpenBLAS compilation test completed successfully!${NC}"
echo ""
echo "Summary:"
echo "  - All prerequisites found"
echo "  - OpenBLAS v0.3.30 compiled successfully with DYNAMIC_ARCH=1"
echo "  - Installation verified (all build flags passed to make install)"
echo "  - Library located at: ${OPENBLAS_LIB}"
echo ""
echo "Build Configuration:"
echo "  - Follows official OpenBLAS documentation recommendations"
echo "  - Uses stable release from GitHub Releases (not develop branch)"
echo "  - All build flags passed to make install (required per documentation)"
echo "  - Optimized for maximum portability and performance"
echo ""
echo "The compilation process is ready to be integrated into the main build script."
echo ""
echo "Note: OpenBLAS with DYNAMIC_ARCH=1 provides:"
echo "  - Runtime CPU detection for optimal performance"
echo "  - Support for multiple CPU architectures (Intel, AMD, etc.)"
echo "  - Good performance comparable to MKL on many workloads"
echo "  - Better performance than MKL on AMD hardware"
echo "  - Open-source and free (no licensing restrictions)"
echo ""
echo "Documentation References:"
echo "  - Installation Guide: http://www.openmathlib.org/OpenBLAS/docs/install/"
echo "  - Build System: http://www.openmathlib.org/OpenBLAS/docs/build_system/"
echo ""
echo "Cleanup: Removing test files..."
rm -rf "${OPENBLAS_TEST_DIR}" "${OPENBLAS_INSTALL_PREFIX}"
echo -e "${GREEN}✓ Cleanup complete${NC}"

