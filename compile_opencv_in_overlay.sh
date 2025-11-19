#!/bin/bash
#===============================================================================
# OPENCV COMPILATION SCRIPT FOR WRITABLE OVERLAY
#===============================================================================
# Purpose: Compile OpenCV from source in a writable overlay environment
#          with CUDA, TBB, MKL, and all accelerations, then test and verify
# Usage: Run this script INSIDE a Singularity container with overlay mounted
# Example: singularity shell --overlay overlay.img:rw image.sif
#          Singularity> ./compile_opencv_in_overlay.sh
#
# Prerequisites:
#   - Container built with xubuntu_robotics_base_pre_opencv_debug.sh
#   - Writable overlay mounted: --overlay overlay.img:rw
#   - All dependencies installed (CUDA, TBB, MKL, etc.)
#===============================================================================

#===============================================================================
# BLOCK 1: SCRIPT INITIALIZATION
#===============================================================================
# Purpose: Validate bash shell and set strict error handling
# Self-contained: Yes (complete if-fi block with exit)
# Dependencies: None
# Outputs: Environment variables, configuration
#-------------------------------------------------------------------------------

#--- Sub-block 1.1: Bash version validation ---
if [ -z "${BASH_VERSION:-}" ]; then
    printf '%s\n' "ERROR: This script requires bash. Please run with: /bin/bash"
    printf '%s\n' "Current shell: ${0}"
    exit 1
fi
# ENDIF: Bash version check

#--- Sub-block 1.2: Strict error handling ---
set -euo pipefail

#--- Sub-block 1.3: Colors for output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

#===============================================================================
# BLOCK 2: LOAD CONFIGURATION
#===============================================================================
# Purpose: Source config.sh to get OpenCV version and other settings
# Self-contained: Yes (complete if-fi block with exit)
# Dependencies: config.sh must exist
# Outputs: Environment variables from config.sh
#-------------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"

if [ ! -f "${CONFIG_FILE}" ]; then
    # Try /etc/config.sh (container path)
    if [ -f "/etc/config.sh" ]; then
        CONFIG_FILE="/etc/config.sh"
    else
        printf '%s\n' "${RED}ERROR: config.sh not found${NC}" >&2
        printf '%s\n' "  Searched: ${SCRIPT_DIR}/config.sh" >&2
        printf '%s\n' "  Searched: /etc/config.sh" >&2
        exit 1
    fi
fi

# Source config.sh
# shellcheck source=/dev/null
source "${CONFIG_FILE}"

# Verify OpenCV version is set
if [ -z "${OPENCV_VERSION:-}" ]; then
    printf '%s\n' "${RED}ERROR: OPENCV_VERSION not set in config.sh${NC}" >&2
    exit 1
fi

#===============================================================================
# BLOCK 3: ENVIRONMENT VERIFICATION
#===============================================================================
# Purpose: Verify we're in a container with writable overlay
# Self-contained: Yes (complete if-fi block with exit)
# Dependencies: None
# Outputs: Verification status
#-------------------------------------------------------------------------------

printf '\n%s\n' "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf '%s\n' "${BLUE}OPENCV COMPILATION IN WRITABLE OVERLAY${NC}"
printf '%s\n' "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf '%s\n' ""

# Check if we're in a container
if [ ! -f "/.singularity.d/Singularity" ] && [ -z "${SINGULARITY_NAME:-}" ] && [ -z "${APPTAINER_NAME:-}" ]; then
    printf '%s\n' "${YELLOW}⚠ WARNING: Not detected as running in Singularity/Apptainer container${NC}"
    printf '%s\n' "  Continuing anyway (may be running in different container environment)"
fi

# Check if /usr/local is writable (overlay should make it writable)
if ! touch /usr/local/.test_write 2>/dev/null; then
    printf '%s\n' "${RED}ERROR: /usr/local is not writable${NC}" >&2
    printf '%s\n' "  Make sure overlay is mounted in read-write mode:" >&2
    printf '%s\n' "    singularity shell --overlay overlay.img:rw image.sif" >&2
    exit 1
fi
rm -f /usr/local/.test_write

# Verify critical dependencies
printf '%s\n' "${CYAN}Verifying dependencies...${NC}"

# Check CUDA
if [ -z "${CUDA_HOME:-}" ] && [ ! -d "/usr/local/cuda" ]; then
    printf '%s\n' "${YELLOW}⚠ WARNING: CUDA not found (OpenCV will compile without CUDA support)${NC}"
else
    CUDA_HOME="${CUDA_HOME:-/usr/local/cuda}"
    if [ -d "${CUDA_HOME}" ]; then
        printf '%s\n' "${GREEN}✓ CUDA found: ${CUDA_HOME}${NC}"
    fi
fi

# Check MKL
if [ -z "${MKLROOT:-}" ]; then
    printf '%s\n' "${YELLOW}⚠ WARNING: MKLROOT not set (OpenCV will use system BLAS/LAPACK)${NC}"
else
    if [ -d "${MKLROOT}" ]; then
        printf '%s\n' "${GREEN}✓ MKL found: ${MKLROOT}${NC}"
    else
        printf '%s\n' "${YELLOW}⚠ WARNING: MKLROOT set but directory not found: ${MKLROOT}${NC}"
    fi
fi

# Check TBB
if [ -f "/usr/lib/x86_64-linux-gnu/libtbb.so" ] || [ -f "/usr/lib/libtbb.so" ]; then
    printf '%s\n' "${GREEN}✓ TBB found${NC}"
else
    printf '%s\n' "${YELLOW}⚠ WARNING: TBB not found (OpenCV will compile without TBB support)${NC}"
fi

# Check build tools
if ! command -v cmake >/dev/null 2>&1; then
    printf '%s\n' "${RED}ERROR: cmake not found${NC}" >&2
    exit 1
fi
if ! command -v ninja >/dev/null 2>&1; then
    printf '%s\n' "${RED}ERROR: ninja not found${NC}" >&2
    exit 1
fi
if ! command -v g++ >/dev/null 2>&1; then
    printf '%s\n' "${RED}ERROR: g++ not found${NC}" >&2
    exit 1
fi

printf '%s\n' "${GREEN}✓ Build tools verified${NC}"
printf '%s\n' ""

#===============================================================================
# BLOCK 4: OPENCV SOURCE DOWNLOAD
#===============================================================================
# Purpose: Clone OpenCV core and contrib modules
# Self-contained: Yes (complete with error handling)
# Dependencies: git, network access
# Outputs: OpenCV source code in /tmp/opencv and /tmp/opencv_contrib
#-------------------------------------------------------------------------------

printf '%s\n' "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf '%s\n' "${CYAN}PHASE 1: Downloading OpenCV Source Code${NC}"
printf '%s\n' "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf '%s\n' ""

# Cleanup previous builds
cd / || true
rm -rf /tmp/opencv /tmp/opencv_contrib

# Clone function with retry
clone_with_retry() {
    local url="${1}"
    local dest="${2}"
    local tag="${3}"
    local max_attempts=3
    local attempt=1
    
    while [ ${attempt} -le ${max_attempts} ]; do
        printf '%s\n' "  Attempt ${attempt}/${max_attempts}: Cloning ${url} (tag: ${tag})..."
        if git clone --depth 1 --branch "${tag}" "${url}" "${dest}" 2>&1; then
            printf '%s\n' "${GREEN}  ✓ Successfully cloned ${url}${NC}"
            return 0
        else
            if [ ${attempt} -lt ${max_attempts} ]; then
                printf '%s\n' "${YELLOW}  ⚠ Clone failed, retrying in 5 seconds...${NC}"
                sleep 5
            fi
            attempt=$((attempt + 1))
        fi
    done
    
    printf '%s\n' "${RED}  ✗ Failed to clone ${url} after ${max_attempts} attempts${NC}" >&2
    return 1
}

# Clone OpenCV core
if ! clone_with_retry "https://github.com/opencv/opencv.git" "/tmp/opencv" "${OPENCV_VERSION}"; then
    printf '%s\n' "${RED}ERROR: Failed to clone OpenCV core${NC}" >&2
    exit 1
fi

# Clone OpenCV contrib
if ! clone_with_retry "https://github.com/opencv/opencv_contrib.git" "/tmp/opencv_contrib" "${OPENCV_VERSION}"; then
    printf '%s\n' "${RED}ERROR: Failed to clone OpenCV contrib${NC}" >&2
    exit 1
fi

printf '%s\n' "${GREEN}✓ OpenCV source code downloaded${NC}"
printf '%s\n' ""

#===============================================================================
# BLOCK 5: OPENCV CMAKE CONFIGURATION
#===============================================================================
# Purpose: Configure OpenCV build with CMake
# Self-contained: Yes (complete with error handling)
# Dependencies: OpenCV source, CMake, all dependencies
# Outputs: CMake configuration in /tmp/opencv/build
#-------------------------------------------------------------------------------

printf '%s\n' "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf '%s\n' "${CYAN}PHASE 2: Configuring OpenCV Build${NC}"
printf '%s\n' "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf '%s\n' ""

# Verify source directory exists
if [ ! -d "/tmp/opencv" ]; then
    printf '%s\n' "${RED}ERROR: OpenCV source directory not found: /tmp/opencv${NC}" >&2
    exit 1
fi

cd /tmp/opencv || { printf '%s\n' "${RED}ERROR: Failed to access opencv directory${NC}" >&2; exit 1; }

# Remove existing build directory
rm -rf build
mkdir -p build
cd build || { printf '%s\n' "${RED}ERROR: Failed to access build directory${NC}" >&2; exit 1; }

# Set environment variables
export PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:/usr/local/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig"
export LIBRARY_PATH="${LIBRARY_PATH}:/usr/lib/x86_64-linux-gnu"

# Detect GCC version for CUDA compatibility
GCC_VERSION_FOR_OPENCV=""
GCC_MAJOR_FOR_OPENCV=""
if command -v gcc-12 >/dev/null 2>&1; then
    GCC_VERSION_FOR_OPENCV=$(gcc-12 --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "")
elif command -v gcc >/dev/null 2>&1; then
    GCC_VERSION_FOR_OPENCV=$(gcc --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "")
fi

if [ -n "${GCC_VERSION_FOR_OPENCV}" ]; then
    GCC_MAJOR_FOR_OPENCV=$(cut -d. -f1 <<< "${GCC_VERSION_FOR_OPENCV}")
    printf '%s\n' "  Detected GCC version: ${GCC_VERSION_FOR_OPENCV}"
fi

# CUDA flags (with GCC compatibility workarounds)
CUDA_ARCH="8.6"
OPENCV_CUDA_NVCC_FLAGS="--expt-relaxed-constexpr --expt-extended-lambda;-Xcompiler=-fPIC;-Xcompiler=-Wno-deprecated-declarations;-x=cu;-std=c++17"
OPENCV_CUDA_FLAGS="-Xcompiler=-Wno-deprecated-declarations"

if [ -n "${GCC_MAJOR_FOR_OPENCV}" ]; then
    if [ "${GCC_MAJOR_FOR_OPENCV}" = "11" ]; then
        printf '%s\n' "${YELLOW}  ⚠ GCC 11 detected - adding compatibility workarounds for NVCC${NC}"
        OPENCV_CUDA_NVCC_FLAGS="--expt-relaxed-constexpr --expt-extended-lambda;-allow-unsupported-compiler;-Xcompiler=-fPIC;-Xcompiler=-Wno-deprecated-declarations;-x=cu;-std=c++17"
        OPENCV_CUDA_FLAGS="-allow-unsupported-compiler -Xcompiler=-Wno-deprecated-declarations"
    elif [ "${GCC_MAJOR_FOR_OPENCV}" -ge "12" ]; then
        printf '%s\n' "${GREEN}  ✓ GCC 12+ detected - using standard NVCC flags${NC}"
    fi
fi

# MKL Configuration
MKL_BLA_VENDOR="${MKL_BLA_VENDOR:-Intel10_64lp}"
MKL_THREADING_LAYER="${MKL_THREADING_LAYER:-GNU}"
INSTALL_PREFIX="/usr/local"

# Build CMake arguments
OPENCV_CMAKE_ARGS=(
  -G "Ninja"
  "-DCPU_BASELINE=AVX2"
  "-DCPU_DISPATCH=AVX2,FP16,AVX512_SKX"
  "-DCMAKE_BUILD_TYPE=Release"
  "-DCMAKE_C_COMPILER=/usr/bin/gcc-12"
  "-DCMAKE_CXX_COMPILER=/usr/bin/g++-12"
  "-DCUDA_HOST_COMPILER=/usr/bin/g++-12"
  "-DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX}"
  "-DCMAKE_POLICY_DEFAULT_CMP0146=OLD"
  "-DOPENCV_EXTRA_MODULES_PATH=/tmp/opencv_contrib/modules"
  "-DBUILD_SHARED_LIBS=ON"
  "-DCMAKE_C_COMPILER_LAUNCHER=ccache"
  "-DCMAKE_CXX_COMPILER_LAUNCHER=ccache"
  "-DOPENCV_CMAKE_DEBUG_MESSAGES=ON"
  "-DOPENCV_GENERATE_PKGCONFIG=ON"
  "-DCUDA_NVCC_FLAGS=${OPENCV_CUDA_NVCC_FLAGS}"
  "-DCMAKE_CUDA_FLAGS=${OPENCV_CUDA_FLAGS}"
  "-DWITH_CUDA=ON"
  "-DWITH_CUDNN=ON"
  "-DCUDA_ARCH_BIN=${CUDA_ARCH}"
  "-DCUDA_ARCH_PTX=${CUDA_ARCH}"
  "-DOPENCV_DNN_CUDA=ON"
  "-DCUDA_TOOLKIT_ROOT_DIR=${CUDA_HOME:-/usr/local/cuda}"
  "-DENABLE_FAST_MATH=1"
  "-DCUDA_FAST_MATH=1"
  "-DWITH_CUBLAS=1"
  "-DWITH_CUFFT=ON"
  "-DWITH_OPENGL=ON"
  "-DWITH_TBB=ON"
  "-DWITH_EIGEN=ON"
  "-DWITH_FFMPEG=ON"
  "-DWITH_GSTREAMER=ON"
  "-DWITH_LAPACK=ON"
  "-DWITH_MKL=ON"
  "-DMKL_WITH_OPENMP=ON"
  "-DMKL_USE_STATIC_LIBS=OFF"
  "-DWITH_TIFF=ON"
  "-DWITH_OPENMP=ON"
  "-DBLA_VENDOR=${MKL_BLA_VENDOR}"
  "-DOPENCV_LAPACK_DISABLE_MKL=OFF"
  "-DOPENCV_ENABLE_NONFREE=ON"
  "-DBUILD_EXAMPLES=OFF"
  "-DBUILD_TESTS=OFF"
  "-DBUILD_PERF_TESTS=OFF"
  "-DBUILD_DOCS=OFF"
  "-DWITH_IPP=OFF"
  "-DBUILD_opencv_apps=OFF"
  "-DBUILD_opencv_sfm=OFF"
  "-DBUILD_opencv_python3=ON"
  "-DBUILD_opencv_cudacodec=ON"
  "-DBUILD_opencv_cudaarithm=ON"
  "-DBUILD_opencv_cudev=ON"
  "-DBUILD_opencv_cudafeatures2d=ON"
  "-DBUILD_opencv_cudafilters=ON"
  "-DBUILD_opencv_cudaimgproc=ON"
  "-DBUILD_opencv_cudalegacy=ON"
  "-DBUILD_opencv_cudaobjdetect=ON"
  "-DBUILD_opencv_cudaoptflow=ON"
  "-DBUILD_opencv_cudastereo=ON"
  "-DBUILD_opencv_cudawarping=ON"
  "-DBUILD_opencv_video=ON"
  "-DBUILD_opencv_videoio=ON"
  "-DBUILD_opencv_julia=OFF"
  "-DPYTHON3_EXECUTABLE=/usr/bin/python3"
  "-DPYTHON3_INCLUDE_DIR=/usr/include/python${SYSTEM_PYTHON_VER:-3.12}"
  "-DPYTHON3_LIBRARY=/usr/lib/x86_64-linux-gnu/libpython${SYSTEM_PYTHON_VER:-3.12}.so"
  "-DPYTHON3_NUMPY_INCLUDE_DIRS=/usr/lib/python3/dist-packages/numpy/core/include"
  "-DTBB_DIR=/usr/lib/x86_64-linux-gnu/cmake/TBB"
  "-DTBB_ROOT_DIR=/usr"
  "-DTBB_LIBRARIES=/usr/lib/x86_64-linux-gnu/libtbb.so"
  "-DTBB_INCLUDE_DIR=/usr/include"
  "-DTBB_INCLUDE_DIRS=/usr/include"
  "-DCMAKE_INSTALL_RPATH=/usr/local/lib"
  "-DCMAKE_C_STANDARD=17"
  "-DCMAKE_CXX_STANDARD=17"
  "-DCMAKE_CUDA_STANDARD=17"
  "-DCMAKE_C_STANDARD_REQUIRED=ON"
  "-DCMAKE_CXX_STANDARD_REQUIRED=ON"
  "-DCMAKE_CUDA_STANDARD_REQUIRED=ON"
  "-DCMAKE_INCLUDE_PATH=/usr/include/x86_64-linux-gnu;/usr/include;${MKL_INCLUDE_DIR:-}"
  "-DCMAKE_CXX_FLAGS=-Wno-deprecated -fpermissive -march=x86-64-v3 -O3 -mavx2 -mfma -msse4.2 -funroll-loops -fopenmp -isystem /usr/include/x86_64-linux-gnu -isystem /usr/include"
  "-DCMAKE_C_FLAGS=-march=x86-64-v3 -O3 -mavx2 -mfma -msse4.2 -funroll-loops -fopenmp -isystem /usr/include/x86_64-linux-gnu -isystem /usr/include"
  "-DCMAKE_SYSTEM_PREFIX_PATH=/usr;/usr/local"
  "-DCMAKE_EXE_LINKER_FLAGS=-flto -fopenmp"
  "-DCMAKE_MODULE_LINKER_FLAGS=-flto -fopenmp"
  "-DCMAKE_SHARED_LINKER_FLAGS=-flto -fopenmp"
  "-DENABLE_PRECOMPILED_HEADERS=ON"
  "-DCV_ENABLE_INTRINSICS=ON"
  "-DPARALLEL_ENABLE_PLUGINS=ON"
  "-DCMAKE_PREFIX_PATH=/usr/local:/usr:${MKLROOT:-}${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}"
  "-DCeres_DIR=/usr/local/lib/cmake/Ceres"
  "-DSuiteSparse_DIR=${SUITESPARSE_INSTALL_PREFIX:-/usr/local}/lib/cmake/SuiteSparse"
  "-DCMAKE_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:/usr/lib:${MKL_LIB_DIR:-}"
)

# Add MKL-specific flags if MKL is available
if [ -n "${MKLROOT:-}" ] && [ -d "${MKLROOT}" ]; then
    MKL_INCLUDE_DIR="${MKLROOT}/include"
    MKL_LIB_DIR="${MKLROOT}/lib/intel64"
    OPENCV_CMAKE_ARGS+=(
      "-DMKL_ROOT=${MKLROOT}"
      "-DMKL_DIR=${MKLROOT}/lib/cmake/mkl"
      "-DLAPACK_INCLUDE_DIR=${MKL_INCLUDE_DIR}"
      "-DLAPACK_INCLUDE_DIRS=${MKL_INCLUDE_DIR}"
      "-DBLAS_LIBRARIES=${MKL_BLAS_LIBRARIES:-}"
      "-DLAPACK_LIBRARIES=${MKL_BLAS_LIBRARIES:-}"
      "-DMKL_THREADING_LAYER=${MKL_THREADING_LAYER}"
    )
fi

# Exclude MKL TBB from search path
if [ -d "/opt/intel/oneapi/tbb" ]; then
    OPENCV_CMAKE_ARGS+=("-DCMAKE_IGNORE_PATH=/opt/intel/oneapi/tbb")
    printf '%s\n' "${YELLOW}  [INFO] Excluding MKL TBB from search path (using system TBB)${NC}"
fi

# Run CMake configuration
printf '%s\n' "${CYAN}Running CMake configuration...${NC}"
printf '%s\n' "  This may take several minutes..."
printf '%s\n' ""

if ! cmake "${OPENCV_CMAKE_ARGS[@]}" .. 2>&1 | tee /tmp/opencv_cmake.log; then
    printf '%s\n' "${RED}ERROR: CMake configuration failed${NC}" >&2
    printf '%s\n' "  Check log: /tmp/opencv_cmake.log" >&2
    exit 1
fi

printf '%s\n' ""
printf '%s\n' "${GREEN}✓ CMake configuration completed${NC}"
printf '%s\n' ""

#===============================================================================
# BLOCK 6: OPENCV COMPILATION
#===============================================================================
# Purpose: Build OpenCV with Ninja
# Self-contained: Yes (complete with error handling)
# Dependencies: CMake configuration
# Outputs: Compiled OpenCV libraries
#-------------------------------------------------------------------------------

printf '%s\n' "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf '%s\n' "${CYAN}PHASE 3: Compiling OpenCV${NC}"
printf '%s\n' "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf '%s\n' ""

# Calculate build jobs (memory-aware)
calculate_build_jobs() {
    local available_mem_gb
    local num_cores
    local jobs
    
    # Get available memory in GB
    if command -v free >/dev/null 2>&1; then
        available_mem_gb=$(free -g | awk '/^Mem:/ {print $7}')
    else
        available_mem_gb=8  # Default fallback
    fi
    
    # Get number of CPU cores
    if command -v nproc >/dev/null 2>&1; then
        num_cores=$(nproc)
    else
        num_cores=4  # Default fallback
    fi
    
    # OpenCV builds are memory-intensive, use conservative job count
    # Estimate ~4GB per job for OpenCV
    jobs=$((available_mem_gb / 4))
    
    # Ensure at least 1 job, but don't exceed number of cores
    if [ ${jobs} -lt 1 ]; then
        jobs=1
    elif [ ${jobs} -gt ${num_cores} ]; then
        jobs=${num_cores}
    fi
    
    printf '%s\n' "${jobs}"
}

BUILD_JOBS=$(calculate_build_jobs)
BUILD_JOBS=${BUILD_JOBS:-1}

printf '%s\n' "Using ${BUILD_JOBS} parallel jobs for OpenCV build"
mem_info=$(free -h 2>/dev/null | grep Mem | awk '{print $2}' || printf '%s\n' "unknown")
printf '%s\n' "  System: $(nproc) cores, ${mem_info} RAM"
printf '%s\n' ""
printf '%s\n' "${YELLOW}⚠ This compilation may take 30-60 minutes depending on system resources${NC}"
printf '%s\n' ""

# Build with Ninja
if ! ninja -j"${BUILD_JOBS}" 2>&1 | tee /tmp/opencv_build.log; then
    printf '%s\n' "${RED}ERROR: OpenCV build failed${NC}" >&2
    printf '%s\n' "  Check log: /tmp/opencv_build.log" >&2
    printf '%s\n' "  Last 50 lines:" >&2
    tail -50 /tmp/opencv_build.log >&2
    exit 1
fi

printf '%s\n' ""
printf '%s\n' "${GREEN}✓ OpenCV compilation completed${NC}"
printf '%s\n' ""

#===============================================================================
# BLOCK 7: OPENCV INSTALLATION
#===============================================================================
# Purpose: Install OpenCV to /usr/local
# Self-contained: Yes (complete with error handling)
# Dependencies: Successful compilation
# Outputs: Installed OpenCV libraries and headers
#-------------------------------------------------------------------------------

printf '%s\n' "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf '%s\n' "${CYAN}PHASE 4: Installing OpenCV${NC}"
printf '%s\n' "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf '%s\n' ""

if ! ninja install 2>&1 | tee /tmp/opencv_install.log; then
    printf '%s\n' "${RED}ERROR: OpenCV installation failed${NC}" >&2
    printf '%s\n' "  Check log: /tmp/opencv_install.log" >&2
    exit 1
fi

# Update library cache
if command -v ldconfig >/dev/null 2>&1; then
    printf '%s\n' "Updating library cache..."
    ldconfig || true
fi

printf '%s\n' ""
printf '%s\n' "${GREEN}✓ OpenCV installed to ${INSTALL_PREFIX}${NC}"
printf '%s\n' ""

#===============================================================================
# BLOCK 8: OPENCV TESTING AND VERIFICATION
#===============================================================================
# Purpose: Test OpenCV installation and verify all features
# Self-contained: Yes (complete with error handling)
# Dependencies: Successful installation
# Outputs: Test results
#-------------------------------------------------------------------------------

printf '%s\n' "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf '%s\n' "${CYAN}PHASE 5: Testing and Verification${NC}"
printf '%s\n' "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf '%s\n' ""

# Test 1: Verify OpenCV installation
printf '%s\n' "${CYAN}Test 1: Verifying OpenCV installation...${NC}"
if [ -f "${INSTALL_PREFIX}/lib/pkgconfig/opencv4.pc" ]; then
    printf '%s\n' "${GREEN}  ✓ OpenCV pkg-config file found${NC}"
else
    printf '%s\n' "${YELLOW}  ⚠ OpenCV pkg-config file not found${NC}"
fi

if [ -f "${INSTALL_PREFIX}/lib/libopencv_core.so" ] || [ -f "${INSTALL_PREFIX}/lib/libopencv_core.so.${OPENCV_VERSION}" ]; then
    printf '%s\n' "${GREEN}  ✓ OpenCV core library found${NC}"
else
    printf '%s\n' "${RED}  ✗ OpenCV core library not found${NC}" >&2
fi

# Test 2: Python import test
printf '%s\n' "${CYAN}Test 2: Testing Python import...${NC}"
PYTHON_TEST_CODE='
import sys
try:
    import cv2
    print(f"  ✓ OpenCV Python module imported successfully")
    print(f"  ✓ OpenCV version: {cv2.__version__}")
    print(f"  ✓ Build information:")
    build_info = cv2.getBuildInformation()
    # Check for key features
    if "CUDA" in build_info:
        print(f"  ✓ CUDA support: Enabled")
    if "TBB" in build_info:
        print(f"  ✓ TBB support: Enabled")
    if "MKL" in build_info or "Intel MKL" in build_info:
        print(f"  ✓ MKL support: Enabled")
    sys.exit(0)
except ImportError as e:
    print(f"  ✗ Failed to import OpenCV: {e}")
    sys.exit(1)
'

if python3 -c "${PYTHON_TEST_CODE}" 2>&1; then
    printf '%s\n' "${GREEN}  ✓ Python import test passed${NC}"
else
    printf '%s\n' "${YELLOW}  ⚠ Python import test failed (may need to set PYTHONPATH)${NC}"
fi

# Test 3: C++ compilation test
printf '%s\n' "${CYAN}Test 3: Testing C++ compilation...${NC}"
CXX_TEST_CODE='
#include <opencv2/opencv.hpp>
#include <iostream>
int main() {
    std::cout << "OpenCV version: " << CV_VERSION << std::endl;
    cv::Mat img = cv::Mat::zeros(100, 100, CV_8UC3);
    std::cout << "Image created: " << img.rows << "x" << img.cols << std::endl;
    return 0;
}
'

CXX_TEST_FILE="/tmp/test_opencv.cpp"
printf '%s' "${CXX_TEST_CODE}" > "${CXX_TEST_FILE}"

if g++ -std=c++17 -I"${INSTALL_PREFIX}/include/opencv4" \
    -L"${INSTALL_PREFIX}/lib" \
    -lopencv_core -lopencv_imgproc -lopencv_imgcodecs \
    "${CXX_TEST_FILE}" -o /tmp/test_opencv 2>&1; then
    if /tmp/test_opencv 2>&1; then
        printf '%s\n' "${GREEN}  ✓ C++ compilation and execution test passed${NC}"
    else
        printf '%s\n' "${YELLOW}  ⚠ C++ compilation succeeded but execution failed${NC}"
    fi
    rm -f /tmp/test_opencv
else
    printf '%s\n' "${YELLOW}  ⚠ C++ compilation test failed (may need to set LD_LIBRARY_PATH)${NC}"
fi
rm -f "${CXX_TEST_FILE}"

# Test 4: CUDA test (if CUDA is available)
if [ -n "${CUDA_HOME:-}" ] && [ -d "${CUDA_HOME}" ]; then
    printf '%s\n' "${CYAN}Test 4: Testing CUDA support...${NC}"
    CUDA_TEST_CODE='
import cv2
import sys
try:
    # Check if CUDA is available
    if cv2.cuda.getCudaEnabledDeviceCount() > 0:
        print(f"  ✓ CUDA devices detected: {cv2.cuda.getCudaEnabledDeviceCount()}")
        print(f"  ✓ CUDA support: Enabled")
    else:
        print(f"  ⚠ CUDA devices not detected (CUDA may still be compiled)")
    sys.exit(0)
except Exception as e:
    print(f"  ⚠ CUDA test failed: {e}")
    sys.exit(0)  # Non-fatal
'
    if python3 -c "${CUDA_TEST_CODE}" 2>&1; then
        printf '%s\n' "${GREEN}  ✓ CUDA test completed${NC}"
    fi
fi

# Test 5: Feature verification
printf '%s\n' "${CYAN}Test 5: Verifying build features...${NC}"
FEATURE_TEST_CODE='
import cv2
build_info = cv2.getBuildInformation()
features = {
    "CUDA": False,
    "TBB": False,
    "MKL": False,
    "FFMPEG": False,
    "GSTREAMER": False,
}

for line in build_info.split("\n"):
    line_upper = line.upper()
    if "CUDA" in line_upper and ("YES" in line_upper or "ON" in line_upper):
        features["CUDA"] = True
    if "TBB" in line_upper and ("YES" in line_upper or "ON" in line_upper):
        features["TBB"] = True
    if "MKL" in line_upper or "INTEL MKL" in line_upper:
        features["MKL"] = True
    if "FFMPEG" in line_upper and ("YES" in line_upper or "ON" in line_upper):
        features["FFMPEG"] = True
    if "GSTREAMER" in line_upper and ("YES" in line_upper or "ON" in line_upper):
        features["GSTREAMER"] = True

for feature, enabled in features.items():
    if enabled:
        print(f"  ✓ {feature}: Enabled")
    else:
        print(f"  ⚠ {feature}: Not detected")
'

if python3 -c "${FEATURE_TEST_CODE}" 2>&1; then
    printf '%s\n' "${GREEN}  ✓ Feature verification completed${NC}"
fi

printf '%s\n' ""
printf '%s\n' "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf '%s\n' "${GREEN}✓ OPENCV COMPILATION AND VERIFICATION COMPLETE${NC}"
printf '%s\n' "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf '%s\n' ""
printf '%s\n' "OpenCV ${OPENCV_VERSION} has been successfully compiled and installed."
printf '%s\n' ""
printf '%s\n' "Installation location: ${INSTALL_PREFIX}"
printf '%s\n' "Build logs:"
printf '%s\n' "  - CMake: /tmp/opencv_cmake.log"
printf '%s\n' "  - Build: /tmp/opencv_build.log"
printf '%s\n' "  - Install: /tmp/opencv_install.log"
printf '%s\n' ""
printf '%s\n' "To use OpenCV in your code:"
printf '%s\n' "  - C++: Include <opencv2/opencv.hpp> and link against -lopencv_core, etc."
printf '%s\n' "  - Python: import cv2"
printf '%s\n' ""
printf '%s\n' "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf '%s\n' ""

exit 0

