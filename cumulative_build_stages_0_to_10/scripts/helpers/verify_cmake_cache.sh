#!/bin/bash
################################################################################
# CMAKECACHE.TXT VERIFICATION TOOL
# Purpose: Validate CMakeCache.txt after library configuration
# Usage: ./verify_cmake_cache.sh <cmake_cache_file> <library_name>
#
# Features:
#   - TBB source verification (system vs MKL)
#   - BLAS vendor consistency check
#   - LAPACK detection validation
#   - CUDA architecture verification
#   - Required features enabled check
#
# Exit codes:
#   0 = All checks passed
#   1 = Critical errors found
#   2 = Warnings found (non-critical)
################################################################################

set -euo pipefail

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Script configuration
# SCRIPT_DIR unused - removed to fix SC2034
CACHE_FILE=""
LIBRARY_NAME=""

# Check counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

################################################################################
# HELPER FUNCTIONS
################################################################################

print_usage() {
  cat <<EOF
Usage: ${0##*/} <cmake_cache_file> <library_name>

Validate CMakeCache.txt after library configuration

Arguments:
  cmake_cache_file  Path to CMakeCache.txt file
  library_name      Library being validated (opencv|ceres|gtsam|g2o|open3d|colmap)

Examples:
  ${0##*/} /tmp/opencv/build/CMakeCache.txt opencv
  ${0##*/} /tmp/ceres/build/CMakeCache.txt ceres

EOF
  exit 1
}

log_pass() {
  echo -e "  ${GREEN}✓${NC} $1"
  ((CHECKS_PASSED++))
}

log_fail() {
  echo -e "  ${RED}✗${NC} $1"
  ((CHECKS_FAILED++))
}

log_warn() {
  echo -e "  ${YELLOW}⚠${NC} $1"
  ((CHECKS_WARNING++))
}

log_info() {
  echo -e "  ${BLUE}•${NC} $1"
}

################################################################################
# VERIFICATION FUNCTIONS
################################################################################

verify_tbb_source() {
  echo ""
  echo "Checking TBB source..."
  
  TBB_FOUND=$(grep -E "^TBB_FOUND:BOOL=(1|ON|TRUE)" "${CACHE_FILE}" 2>/dev/null || echo "")
  TBB_LIBRARIES=$(grep -E "^TBB_LIBRARIES(:|=)" "${CACHE_FILE}" 2>/dev/null | head -1 | sed 's/.*[=:]//' | tr -d '[:space:]' || echo "")
  
  if [ -z "${TBB_FOUND}" ]; then
    log_info "TBB not used by ${LIBRARY_NAME}"
    return 0
  fi
  
  if [ -z "${TBB_LIBRARIES}" ]; then
    log_warn "TBB_FOUND=TRUE but TBB_LIBRARIES is empty"
    return 0
  fi
  
  # Check for MKL TBB (BAD)
  if echo "${TBB_LIBRARIES}" | grep -qE "(/opt/intel|/usr/local/intel|/opt/intel/oneapi|mkl)"; then
    log_fail "Using MKL TBB: ${TBB_LIBRARIES}"
    log_info "This will cause runtime conflicts. Use -DTBB_DIR=/usr/lib/x86_64-linux-gnu/cmake/TBB"
    return 1
  # Check for system TBB (GOOD)
  elif echo "${TBB_LIBRARIES}" | grep -qE "/usr/lib/x86_64-linux-gnu/libtbb"; then
    log_pass "Using system TBB: ${TBB_LIBRARIES}"
    return 0
  else
    log_warn "TBB source uncertain: ${TBB_LIBRARIES}"
    return 0
  fi
}

verify_blas_vendor() {
  echo ""
  echo "Checking BLAS/LAPACK configuration..."
  
  # Extract BLAS vendor
  BLA_VENDOR=$(grep -E "^BLA_VENDOR:" "${CACHE_FILE}" 2>/dev/null | sed 's/.*=//' | tr -d '[:space:]' || echo "")
  BLAS_FOUND=$(grep -E "^BLAS_FOUND:BOOL=(1|ON|TRUE)" "${CACHE_FILE}" 2>/dev/null || echo "")
  LAPACK_FOUND=$(grep -E "^LAPACK.*_FOUND:BOOL=(1|ON|TRUE)" "${CACHE_FILE}" 2>/dev/null | head -1 || echo "")
  
  # Check for mixed BLAS implementations
  HAS_MKL=$(grep -qE "mkl|MKL" "${CACHE_FILE}" && echo "true" || echo "false")
  HAS_OPENBLAS=$(grep -qE "openblas|OpenBLAS" "${CACHE_FILE}" && echo "true" || echo "false")
  
  if [ "${HAS_MKL}" = "true" ] && [ "${HAS_OPENBLAS}" = "true" ]; then
    log_fail "Mixed BLAS detected: Both MKL and OpenBLAS found in CMakeCache.txt"
    log_info "This will cause symbol conflicts. Choose one BLAS implementation."
    return 1
  fi
  
  # Verify BLAS vendor if specified
  if [ -n "${BLA_VENDOR}" ]; then
    case "${BLA_VENDOR}" in
      Intel*|MKL*)
        if [ "${HAS_MKL}" = "true" ]; then
          log_pass "BLAS vendor: ${BLA_VENDOR} (MKL detected)"
        else
          log_warn "BLA_VENDOR=${BLA_VENDOR} but MKL not found in cache"
        fi
        ;;
      OpenBLAS)
        if [ "${HAS_OPENBLAS}" = "true" ]; then
          log_pass "BLAS vendor: ${BLA_VENDOR} (OpenBLAS detected)"
        else
          log_warn "BLA_VENDOR=${BLA_VENDOR} but OpenBLAS not found in cache"
        fi
        ;;
      *)
        log_info "BLAS vendor: ${BLA_VENDOR}"
        ;;
    esac
  fi
  
  # Check BLAS/LAPACK found status
  if [ -n "${BLAS_FOUND}" ]; then
    log_pass "BLAS detected successfully"
  else
    log_warn "BLAS not found"
  fi
  
  if [ -n "${LAPACK_FOUND}" ]; then
    log_pass "LAPACK detected successfully"
  else
    log_warn "LAPACK not found"
  fi
  
  return 0
}

verify_cuda_config() {
  echo ""
  echo "Checking CUDA configuration..."
  
  CUDA_FOUND=$(grep -E "^CUDA_FOUND:BOOL=(1|ON|TRUE)" "${CACHE_FILE}" 2>/dev/null || echo "")
  CUDA_VERSION=$(grep -E "^CUDA_VERSION:" "${CACHE_FILE}" 2>/dev/null | sed 's/.*=//' | tr -d '[:space:]' || echo "")
  CUDA_ARCH=$(grep -E "^CMAKE_CUDA_ARCHITECTURES:" "${CACHE_FILE}" 2>/dev/null | sed 's/.*=//' | tr -d '[:space:]' || echo "")
  
  if [ -z "${CUDA_FOUND}" ]; then
    log_info "CUDA not used by ${LIBRARY_NAME}"
    return 0
  fi
  
  log_pass "CUDA detected (version ${CUDA_VERSION:-unknown})"
  
  if [ -n "${CUDA_ARCH}" ]; then
    log_pass "CUDA architectures: ${CUDA_ARCH}"
    
    # Validate architectures are sensible
    if echo "${CUDA_ARCH}" | grep -qE "^[0-9;]+$"; then
      log_pass "CUDA architecture format valid"
    else
      log_warn "CUDA architecture format may be invalid: ${CUDA_ARCH}"
    fi
  else
    log_warn "CMAKE_CUDA_ARCHITECTURES not set"
  fi
  
  return 0
}

verify_library_specific() {
  echo ""
  echo "Checking ${LIBRARY_NAME}-specific configuration..."
  
  case "${LIBRARY_NAME,,}" in
    opencv)
      verify_opencv_config
      ;;
    ceres)
      verify_ceres_config
      ;;
    gtsam)
      verify_gtsam_config
      ;;
    g2o)
      verify_g2o_config
      ;;
    open3d)
      verify_open3d_config
      ;;
    colmap)
      verify_colmap_config
      ;;
    *)
      log_info "No library-specific checks for ${LIBRARY_NAME}"
      ;;
  esac
}

verify_opencv_config() {
  # Check video modules
  VIDEO_MODULE=$(grep -E "^BUILD_opencv_video:BOOL=(ON|TRUE)" "${CACHE_FILE}" 2>/dev/null || echo "")
  VIDEOIO_MODULE=$(grep -E "^BUILD_opencv_videoio:BOOL=(ON|TRUE)" "${CACHE_FILE}" 2>/dev/null || echo "")
  
  if [ -n "${VIDEO_MODULE}" ]; then
    log_pass "opencv_video module enabled"
  else
    log_fail "opencv_video module disabled (should be enabled)"
  fi
  
  if [ -n "${VIDEOIO_MODULE}" ]; then
    log_pass "opencv_videoio module enabled"
  else
    log_fail "opencv_videoio module disabled (should be enabled)"
  fi
  
  # Check NVENC/NVDEC
  NVCUVID=$(grep -E "^WITH_NVCUVID:BOOL=(ON|TRUE)" "${CACHE_FILE}" 2>/dev/null || echo "")
  NVCUVENC=$(grep -E "^WITH_NVCUVENC:BOOL=(ON|TRUE)" "${CACHE_FILE}" 2>/dev/null || echo "")
  
  if [ -n "${NVCUVID}" ] && [ -n "${NVCUVENC}" ]; then
    log_pass "NVIDIA Video Codec SDK enabled (NVDEC/NVENC)"
  else
    log_info "NVIDIA Video Codec SDK not enabled (optional)"
  fi
}

verify_ceres_config() {
  # Check CUDA support
  USE_CUDA=$(grep -E "^USE_CUDA:BOOL=(ON|TRUE)" "${CACHE_FILE}" 2>/dev/null || echo "")
  
  if [ -n "${USE_CUDA}" ]; then
    log_pass "CUDA support enabled"
  else
    log_info "CUDA support not enabled (optional)"
  fi
  
  # Check Schur specializations
  SCHUR=$(grep -E "^SCHUR_SPECIALIZATIONS:BOOL=(ON|TRUE)" "${CACHE_FILE}" 2>/dev/null || echo "")
  
  if [ -n "${SCHUR}" ]; then
    log_pass "SCHUR_SPECIALIZATIONS enabled (performance optimization)"
  else
    log_warn "SCHUR_SPECIALIZATIONS not enabled (recommended for performance)"
  fi
}

verify_gtsam_config() {
  # Check TBB (critical for GTSAM)
  GTSAM_TBB=$(grep -E "^GTSAM_WITH_TBB:BOOL=(ON|TRUE)" "${CACHE_FILE}" 2>/dev/null || echo "")
  
  if [ -n "${GTSAM_TBB}" ]; then
    log_pass "GTSAM_WITH_TBB enabled"
  else
    log_warn "GTSAM_WITH_TBB disabled (TBB is recommended for performance)"
  fi
  
  # Check MKL
  GTSAM_MKL=$(grep -E "^GTSAM_WITH_EIGEN_MKL:BOOL=(ON|TRUE)" "${CACHE_FILE}" 2>/dev/null || echo "")
  
  if [ -n "${GTSAM_MKL}" ]; then
    log_pass "GTSAM_WITH_EIGEN_MKL enabled"
  else
    log_info "GTSAM_WITH_EIGEN_MKL not enabled (optional)"
  fi
}

verify_g2o_config() {
  # Check CHOLMOD
  G2O_CHOLMOD=$(grep -E "^G2O_USE_CHOLMOD:BOOL=(ON|TRUE)" "${CACHE_FILE}" 2>/dev/null || echo "")
  
  if [ -n "${G2O_CHOLMOD}" ]; then
    log_pass "G2O_USE_CHOLMOD enabled"
  else
    log_warn "G2O_USE_CHOLMOD not enabled (sparse solver support recommended)"
  fi
  
  # Check OpenMP
  G2O_OPENMP=$(grep -E "^G2O_USE_OPENMP:BOOL=(ON|TRUE)" "${CACHE_FILE}" 2>/dev/null || echo "")
  
  if [ -n "${G2O_OPENMP}" ]; then
    log_pass "G2O_USE_OPENMP enabled"
  else
    log_warn "G2O_USE_OPENMP not enabled (parallel processing recommended)"
  fi
}

verify_open3d_config() {
  # Check CUDA module
  CUDA_MODULE=$(grep -E "^BUILD_CUDA_MODULE:BOOL=(ON|TRUE)" "${CACHE_FILE}" 2>/dev/null || echo "")
  
  if [ -n "${CUDA_MODULE}" ]; then
    log_pass "CUDA module enabled"
  else
    log_info "CUDA module not enabled (optional)"
  fi
  
  # Check GUI
  BUILD_GUI=$(grep -E "^BUILD_GUI:BOOL=(ON|TRUE)" "${CACHE_FILE}" 2>/dev/null || echo "")
  
  if [ -n "${BUILD_GUI}" ]; then
    log_pass "GUI enabled"
  else
    log_info "GUI not enabled (optional)"
  fi
}

verify_colmap_config() {
  # Check CUDA
  COLMAP_CUDA=$(grep -E "^CUDA_ENABLED:BOOL=(ON|TRUE)" "${CACHE_FILE}" 2>/dev/null || echo "")
  
  if [ -n "${COLMAP_CUDA}" ]; then
    log_pass "CUDA enabled"
  else
    log_info "CUDA not enabled (optional)"
  fi
}

################################################################################
# MAIN EXECUTION
################################################################################

main() {
  # Parse arguments
  if [ $# -lt 2 ]; then
    print_usage
  fi
  
  CACHE_FILE="$1"
  LIBRARY_NAME="$2"
  
  # Validate inputs
  if [ ! -f "${CACHE_FILE}" ]; then
    echo -e "${RED}ERROR: CMakeCache.txt not found: ${CACHE_FILE}${NC}"
    exit 1
  fi
  
  # Print header
  echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║     CMAKECACHE.TXT VERIFICATION TOOL              ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo "Library: ${LIBRARY_NAME}"
  echo "Cache file: ${CACHE_FILE}"
  
  # Run checks
  verify_tbb_source
  verify_blas_vendor
  verify_cuda_config
  verify_library_specific
  
  # Print summary
  echo ""
  echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║     VERIFICATION SUMMARY                           ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${GREEN}Passed:${NC}   ${CHECKS_PASSED}"
  echo -e "  ${YELLOW}Warnings:${NC} ${CHECKS_WARNING}"
  echo -e "  ${RED}Failed:${NC}   ${CHECKS_FAILED}"
  echo ""
  
  # Determine exit code
  if [ ${CHECKS_FAILED} -gt 0 ]; then
    echo -e "${RED}✗ VERIFICATION FAILED${NC}"
    echo "Critical errors must be fixed before proceeding."
    exit 1
  elif [ ${CHECKS_WARNING} -gt 0 ]; then
    echo -e "${YELLOW}⚠ VERIFICATION PASSED WITH WARNINGS${NC}"
    echo "Review warnings before proceeding."
    exit 2
  else
    echo -e "${GREEN}✓ VERIFICATION PASSED${NC}"
    echo "All checks passed successfully."
    exit 0
  fi
}

main "$@"
