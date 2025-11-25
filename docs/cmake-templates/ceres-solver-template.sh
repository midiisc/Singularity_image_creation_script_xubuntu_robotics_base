#!/bin/bash
################################################################################
# CERES SOLVER CMAKE CONFIGURATION TEMPLATE
# Version: 2.2.0+
# Reference: docs/flags/CERES_SOLVER_2.2.0_CMAKE_FLAGS_DOCUMENTATION.md
#
# Usage:
#   source docs/cmake-templates/ceres-solver-template.sh
#   cmake "${CERES_CMAKE_ARGS[@]}" ..
################################################################################

# Required flags (must be set)
CERES_CMAKE_ARGS=(
  "-G" "Ninja"
  "-D" "CMAKE_BUILD_TYPE=Release"
  "-D" "CMAKE_INSTALL_PREFIX=/usr/local"
  
  # Build options
  "-D" "BUILD_SHARED_LIBS=ON"
  "-D" "BUILD_EXAMPLES=OFF"
  "-D" "BUILD_TESTING=OFF"
  "-D" "BUILD_BENCHMARKS=OFF"
  
  # BLAS/LAPACK configuration (use standard CMake variables)
  "-D" "BLA_VENDOR=Intel10_64lp"           # or OpenBLAS, Generic, etc.
  "-D" "BLAS_LIBRARIES=${MKL_BLAS_LIBRARIES}"
  "-D" "LAPACK_LIBRARIES=${MKL_BLAS_LIBRARIES}"
  "-D" "LAPACK=ON"
  
  # Sparse solver support
  "-D" "SUITESPARSE=ON"
  "-D" "EIGENSPARSE=ON"
  "-D" "EIGENMETIS=ON"
  
  # Performance optimizations
  "-D" "SCHUR_SPECIALIZATIONS=ON"          # Fixed-size Schur complement specializations
  "-D" "CUSTOM_BLAS=OFF"                   # OFF for MKL, ON for better generic BLAS performance
  
  # CUDA support (optional)
  "-D" "USE_CUDA=ON"                       # NOT Ceres_ENABLE_CUDA (invalid)
  "-D" "CMAKE_CUDA_ARCHITECTURES=86;89;90"
  
  # Compiler flags
  "-D" "CMAKE_CXX_STANDARD=17"
  "-D" "CMAKE_CXX_STANDARD_REQUIRED=ON"
  "-D" "CMAKE_CXX_FLAGS=-march=x86-64-v3 -O3 -mavx2 -mfma -msse4.2 -fopenmp -funroll-loops"
  "-D" "CMAKE_C_FLAGS=-march=x86-64-v3 -O3 -mavx2 -mfma -msse4.2 -fopenmp -funroll-loops"
  "-D" "CMAKE_SHARED_LINKER_FLAGS=-flto -fopenmp"
  
  # Installation paths
  "-D" "CMAKE_INSTALL_RPATH=/usr/local/lib"
  "-D" "CMAKE_INSTALL_RPATH_USE_LINK_PATH=TRUE"
  
  # Misc
  "-D" "CMAKE_POSITION_INDEPENDENT_CODE=ON"
  "-D" "CMAKE_INTERPROCEDURAL_OPTIMIZATION=ON"
  "-D" "PROVIDE_UNINSTALL_TARGET=ON"
  "-D" "GFLAGS=ON"
  "-D" "MINIGLOG=OFF"  # Use system glog
)

# Optional: Add SuiteSparse paths if needed
if [ -n "${SuiteSparse_DIR:-}" ]; then
  CERES_CMAKE_ARGS+=(
    "-D" "SuiteSparse_DIR=${SuiteSparse_DIR}"
    "-D" "SuiteSparse_ROOT=${SuiteSparse_ROOT}"
  )
fi

# Verification: After cmake configuration, check CMakeCache.txt
verify_ceres_config() {
  local cache_file="$1"
  
  if [ ! -f "${cache_file}" ]; then
    echo "ERROR: CMakeCache.txt not found: ${cache_file}"
    return 1
  fi
  
  echo "Verifying Ceres configuration..."
  
  # Check critical flags
  if ! grep -q "^USE_CUDA:BOOL=ON" "${cache_file}" 2>/dev/null; then
    echo "WARNING: CUDA support not enabled"
  fi
  
  if ! grep -q "^SCHUR_SPECIALIZATIONS:BOOL=ON" "${cache_file}" 2>/dev/null; then
    echo "WARNING: SCHUR_SPECIALIZATIONS not enabled (performance will be suboptimal)"
  fi
  
  # Check TBB source
  TBB_LIB=$(grep -E "^TBB_LIBRARIES" "${cache_file}" 2>/dev/null | cut -d= -f2)
  if echo "${TBB_LIB}" | grep -qE "/opt/intel|mkl"; then
    echo "ERROR: Using MKL TBB instead of system TBB"
    return 1
  fi
  
  echo "✓ Ceres configuration verification passed"
  return 0
}

# Export for use in scripts
export CERES_CMAKE_ARGS
export -f verify_ceres_config
