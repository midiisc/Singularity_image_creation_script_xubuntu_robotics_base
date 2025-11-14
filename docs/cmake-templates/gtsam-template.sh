#!/bin/bash
################################################################################
# GTSAM CMAKE CONFIGURATION TEMPLATE
# Version: 4.2+
# Reference: Official GTSAM CMake documentation
#
# Usage:
#   source docs/cmake-templates/gtsam-template.sh
#   cmake "${GTSAM_CMAKE_ARGS[@]}" ..
#
# CRITICAL: GTSAM requires system TBB, NOT MKL TBB
################################################################################

# Required flags
GTSAM_CMAKE_ARGS=(
  "-G" "Ninja"
  "-D" "CMAKE_BUILD_TYPE=Release"
  "-D" "CMAKE_INSTALL_PREFIX=/usr/local"
  "-D" "CMAKE_POLICY_DEFAULT_CMP0069=NEW"
  
  # Build options
  "-D" "BUILD_SHARED_LIBS=ON"
  "-D" "GTSAM_BUILD_TESTS=OFF"
  "-D" "GTSAM_BUILD_EXAMPLES_ALWAYS=OFF"
  
  # TBB support (CRITICAL - must use system TBB)
  "-D" "GTSAM_WITH_TBB=ON"
  "-D" "TBB_ROOT_DIR=/usr"                        # System TBB location
  "-D" "TBB_DIR=/usr/lib/x86_64-linux-gnu/cmake/TBB"  # Explicit CMake config path
  # CRITICAL FIX: Explicitly set TBB_LIBRARIES and TBB_INCLUDE_DIR to ensure
  # FindTBB.cmake can locate TBB even if TBB_DIR is ignored (common issue)
  "-D" "TBB_LIBRARIES=/usr/lib/x86_64-linux-gnu/libtbb.so"  # Explicit library path
  "-D" "TBB_INCLUDE_DIR=/usr/include/tbb"         # Explicit include path
  "-D" "TBB_INCLUDE_DIRS=/usr/include/tbb"       # Alternative include path name
  # Exclude MKL TBB from search (prevents conflicts)
  # Add to CMAKE_IGNORE_PATH: /opt/intel/oneapi/tbb
  
  # MKL/Eigen configuration
  "-D" "GTSAM_WITH_EIGEN_MKL=ON"
  "-D" "GTSAM_WITH_EIGEN_MKL_OPENMP=ON"
  "-D" "GTSAM_USE_SYSTEM_EIGEN=ON"
  "-D" "MKL_ROOT_DIR=${MKLROOT}"
  "-D" "MKL_INCLUDE_DIR=${MKL_INCLUDE_DIR}"
  "-D" "MKL_LIBRARIES=${MKL_BLAS_LIBRARIES}"
  "-D" "MKL_THREADING_LAYER=GNU"                  # Must match OpenMP
  
  # METIS support
  "-D" "GTSAM_USE_SYSTEM_METIS=ON"
  
  # Optimization options
  "-D" "GTSAM_POSE3_EXPMAP=ON"
  "-D" "GTSAM_ROT3_EXPMAP=ON"
  "-D" "GTSAM_BUILD_WITH_MARCH_NATIVE=OFF"       # Use explicit -march flags instead
  
  # Python bindings
  "-D" "GTSAM_BUILD_PYTHON=ON"
  "-D" "GTSAM_PYTHON_VERSION=${SYSTEM_PYTHON_VER}"
  
  # Compiler flags
  "-D" "CMAKE_CXX_STANDARD=17"
  "-D" "CMAKE_CXX_STANDARD_REQUIRED=ON"
  "-D" "CMAKE_CXX_FLAGS=-march=x86-64-v3 -O3 -mavx2 -mfma -msse4.2 -fopenmp -funroll-loops"
  "-D" "CMAKE_C_FLAGS=-march=x86-64-v3 -O3 -mavx2 -mfma -msse4.2 -fopenmp -funroll-loops"
  "-D" "CMAKE_SHARED_LINKER_FLAGS=-flto -fopenmp"
  
  # Installation paths
  "-D" "CMAKE_INSTALL_RPATH=/usr/local/lib"
  "-D" "CMAKE_INSTALL_RPATH_USE_LINK_PATH=TRUE"
  "-D" "CMAKE_INTERPROCEDURAL_OPTIMIZATION=ON"
)

# Verification: After cmake configuration, check CMakeCache.txt
verify_gtsam_config() {
  local cache_file="$1"
  
  if [ ! -f "${cache_file}" ]; then
    echo "ERROR: CMakeCache.txt not found: ${cache_file}"
    return 1
  fi
  
  echo "Verifying GTSAM configuration..."
  
  # Check TBB is enabled
  if ! grep -q "^GTSAM_WITH_TBB:BOOL=ON" "${cache_file}" 2>/dev/null; then
    echo "ERROR: GTSAM_WITH_TBB not enabled (required for performance)"
    return 1
  fi
  
  # CRITICAL: Check TBB source
  TBB_LIB=$(grep -E "^TBB_LIBRARIES" "${cache_file}" 2>/dev/null | cut -d= -f2)
  if echo "${TBB_LIB}" | grep -qE "/opt/intel|mkl"; then
    echo "ERROR: GTSAM is using MKL TBB instead of system TBB"
    echo "This WILL cause runtime conflicts"
    echo "TBB path: ${TBB_LIB}"
    return 1
  elif echo "${TBB_LIB}" | grep -q "/usr/lib/x86_64-linux-gnu/libtbb"; then
    echo "✓ GTSAM using system TBB: ${TBB_LIB}"
  else
    echo "WARNING: TBB source uncertain: ${TBB_LIB}"
  fi
  
  # Check MKL configuration
  if grep -q "^GTSAM_WITH_EIGEN_MKL:BOOL=ON" "${cache_file}" 2>/dev/null; then
    echo "✓ GTSAM Eigen-MKL integration enabled"
  else
    echo "WARNING: GTSAM_WITH_EIGEN_MKL not enabled (optional but recommended)"
  fi
  
  echo "✓ GTSAM configuration verification passed"
  return 0
}

# Export for use in scripts
export GTSAM_CMAKE_ARGS
export -f verify_gtsam_config
