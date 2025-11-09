#!/usr/bin/env bash
# build-suitesparse-cuda.sh – Build SuiteSparse with MKL + CUDA + OpenMP

set -euo pipefail

SUITESPARSE_VERSION="${SUITESPARSE_VERSION:-v7.12.1}"
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
MKLROOT="${MKLROOT:-/opt/intel/oneapi/mkl/latest}"
BUILD_DIR="${BUILD_DIR:-${HOME}/.cache/suitesparse-build}"

if [[ -z "${CUDA_HOME:-}" ]]; then
    if command -v nvcc >/dev/null 2>&1; then
        CUDA_HOME="$(dirname "$(dirname "$(realpath "$(command -v nvcc)")")")"
        echo "Detected CUDA toolkit at ${CUDA_HOME}"
    else
        CUDA_HOME="/usr/local/cuda"
        echo "nvcc not in PATH; defaulting CUDA_HOME to ${CUDA_HOME}"
    fi
fi

if [[ ! -d "${CUDA_HOME}" ]]; then
    echo "ERROR: CUDA_HOME '${CUDA_HOME}' does not exist. Run setup-cuda-dev-local.sh first."
    exit 1
fi

CUDA_INCLUDE_DIR="${CUDA_HOME}/include"
CUDA_LIB_DIR=""
for candidate in "${CUDA_HOME}/lib64" "${CUDA_HOME}/targets/x86_64-linux/lib"; do
    if [[ -d "${candidate}" ]]; then
        CUDA_LIB_DIR="${candidate}"
        break
    fi
done

if [[ -z "${CUDA_LIB_DIR}" ]]; then
    echo "ERROR: Could not locate CUDA library directory under ${CUDA_HOME}."
    exit 1
fi

if [[ ! -d "${CUDA_INCLUDE_DIR}" ]]; then
    echo "ERROR: CUDA include directory '${CUDA_INCLUDE_DIR}' not found."
    exit 1
fi

for required_lib in "libcublas.so" "libcusparse.so" "libcusolver.so" "libcurand.so"; do
    if [[ ! -f "${CUDA_LIB_DIR}/${required_lib}" ]]; then
        match_path="$(find "${CUDA_LIB_DIR}" -maxdepth 1 -name "${required_lib}*" -print -quit)"
        if [[ -n "${match_path}" ]]; then
            echo "Using ${match_path} for ${required_lib}"
            declare "FOUND_${required_lib//./_}=${match_path}"
        else
            echo "ERROR: Required CUDA library ${required_lib} not found under ${CUDA_LIB_DIR}."
            exit 1
        fi
    fi
done

if [[ ! -d "${MKLROOT}" ]]; then
    echo "ERROR: MKLROOT '${MKLROOT}' not found."
    exit 1
fi

export MKLROOT
export LD_LIBRARY_PATH="${MKLROOT}/lib/intel64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
export LIBRARY_PATH="${MKLROOT}/lib/intel64${LIBRARY_PATH:+:${LIBRARY_PATH}}"
export CPATH="${MKLROOT}/include${CPATH:+:${CPATH}}"

CMAKE_CUDA_ARCH="${CMAKE_CUDA_ARCHITECTURES:-86}"

echo "=== Building SuiteSparse ${SUITESPARSE_VERSION} with MKL + CUDA ==="

mkdir -p "${BUILD_DIR}"
rm -rf "${BUILD_DIR:?}/SuiteSparse"

pushd "${BUILD_DIR}" >/dev/null
git clone --depth 1 --branch "${SUITESPARSE_VERSION}" https://github.com/DrTimothyAldenDavis/SuiteSparse.git
cd SuiteSparse
rm -rf build
mkdir build && cd build

cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
    -DCMAKE_CXX_FLAGS="-O3 -march=native -fPIC -fopenmp" \
    -DCMAKE_CUDA_FLAGS="-O3 -fPIC -Xcompiler -fopenmp --ptxas-options=-v" \
    -DCMAKE_CUDA_ARCHITECTURES="${CMAKE_CUDA_ARCH}" \
    -DBUILD_SHARED_LIBS=ON \
    -DBLA_VENDOR=Intel10_64lp \
    -DBLAS_LIBRARIES="${MKLROOT}/lib/intel64/libmkl_intel_lp64.so;${MKLROOT}/lib/intel64/libmkl_core.so;${MKLROOT}/lib/intel64/libmkl_gnu_thread.so;-lgomp;-lpthread;-lm;-ldl" \
    -DLAPACK_LIBRARIES="${MKLROOT}/lib/intel64/libmkl_intel_lp64.so;${MKLROOT}/lib/intel64/libmkl_core.so;${MKLROOT}/lib/intel64/libmkl_gnu_thread.so;-lgomp;-lpthread;-lm;-ldl" \
    -DBLA_SIZEOF_INTEGER=4 \
    -DBLA_STATIC=OFF \
    -DSUITESPARSE_USE_CUDA=ON \
    -DSUITESPARSE_USE_OPENMP=ON \
    -DSUITESPARSE_USE_STRICT=ON \
    -DSUITESPARSE_USE_64BIT_BLAS=OFF \
    -DSUITESPARSE_REQUIRE_BLAS=ON \
    -DSUITESPARSE_CUDA_ARCHITECTURES="${CMAKE_CUDA_ARCH}" \
    -DSUITESPARSE_ENABLE_PROJECTS="all" \
    -DSUITESPARSE_ENABLE_UNIT_TESTS=OFF \
    -DCHOLMOD_USE_CUDA=ON \
    -DSPQR_USE_CUDA=ON \
    -DGRAPHBLAS_USE_CUDA=OFF \
    -DENABLE_OPENMP=ON \
    -DENABLE_PTHREADS=ON \
    -DSUITESPARSE_USE_FORTRAN=ON \
    -DFORTRAN_C_CALLING_CONVENTION="(name,NAME) name##_" \
    -DSUITESPARSE_C_TO_FORTRAN="(name,NAME) name##_" \
    -DCUDA_TOOLKIT_ROOT_DIR="${CUDA_HOME}" \
    -DCMAKE_CUDA_COMPILER="${CUDA_HOME}/bin/nvcc" \
    -DCUDA_HOST_COMPILER="${CUDA_HOST_COMPILER:-$(command -v gcc || echo gcc)}" \
    -DCUBLAS_LIB="${FOUND_libcublas_so:-${CUDA_LIB_DIR}/libcublas.so}" \
    -DCUBLAS_INCLUDE="${CUDA_INCLUDE_DIR}" \
    -DCUSPARSE_LIB="${FOUND_libcusparse_so:-${CUDA_LIB_DIR}/libcusparse.so}" \
    -DCUSPARSE_INCLUDE="${CUDA_INCLUDE_DIR}" \
    -DCUSOLVER_LIB="${FOUND_libcusolver_so:-${CUDA_LIB_DIR}/libcusolver.so}" \
    -DCUSOLVER_INCLUDE="${CUDA_INCLUDE_DIR}" \
    -DCURAND_LIB="${FOUND_libcurand_so:-${CUDA_LIB_DIR}/libcurand.so}" \
    -DCURAND_INCLUDE="${CUDA_INCLUDE_DIR}" \
    -DENABLE_CUDA_RUNTIME_CHECKS=ON \
    -DCUDA_SEPARABLE_COMPILATION=ON \
    -DCMAKE_PREFIX_PATH="${CUDA_HOME};${MKLROOT}${CMAKE_PREFIX_PATH:+;${CMAKE_PREFIX_PATH}}" \
    -DBUILD_TESTING=OFF

cmake --build . -j"$(nproc)" --verbose
if [[ "${SKIP_INSTALL:-0}" -eq 1 ]]; then
    echo "SKIP_INSTALL=1 → skipping cmake --install step."
else
    if cmake --install .; then
        :
    else
        echo "cmake --install failed without elevated permissions; retrying with sudo..."
        sudo cmake --install .
    fi
fi

popd >/dev/null

echo ""
echo "=== Post-build verification ==="

check_lib() {
    local lib_path="$1"
    local label="$2"
    if [ -f "${lib_path}" ]; then
        echo "Inspecting ${label} (${lib_path})"
        ldd "${lib_path}" | grep -E 'mkl_intel|mkl_core' >/dev/null && echo "  ✅ MKL linked" || echo "  ❌ MKL missing"
        ldd "${lib_path}" | grep -E 'cudart|cublas|cusparse|cusolver' >/dev/null && echo "  ✅ CUDA deps present" || echo "  ⚠️  CUDA deps not found (may be dlopen'd)"
        ldd "${lib_path}" | grep -E 'libgomp|libomp' >/dev/null && echo "  ✅ OpenMP runtime detected" || echo "  ❌ OpenMP runtime missing"
    else
        echo "⚠️  ${label} not found at ${lib_path}"
    fi
    if [[ "${SKIP_INSTALL:-0}" -eq 1 ]]; then
        echo "  (Validation assumes in-tree build artifacts; adjust paths if needed.)"
    fi
}

if [[ "${SKIP_INSTALL:-0}" -eq 1 ]]; then
    LIB_SEARCH_DIRS=(
        "${BUILD_DIR}/SuiteSparse/build/CHOLMOD"
        "${BUILD_DIR}/SuiteSparse/build/SPQR"
        "${BUILD_DIR}/SuiteSparse/build/GraphBLAS"
        "${BUILD_DIR}/SuiteSparse/build"
    )
    found_any=0
    for dir in "${LIB_SEARCH_DIRS[@]}"; do
        if [[ -d "${dir}" ]]; then
            check_lib "${dir}/libcholmod.so" "CHOLMOD"
            check_lib "${dir}/libspqr.so" "SPQR"
            check_lib "${dir}/libgraphblas.so" "GraphBLAS"
            found_any=1
            break
        fi
    done
    if [[ "${found_any}" -eq 0 ]]; then
        echo "⚠️  Could not locate build output directory for verification."
    fi
else
    check_lib "${INSTALL_PREFIX}/lib/libcholmod.so" "CHOLMOD"
    check_lib "${INSTALL_PREFIX}/lib/libspqr.so" "SPQR"
    check_lib "${INSTALL_PREFIX}/lib/libgraphblas.so" "GraphBLAS"
fi

echo "✅ SuiteSparse CUDA build complete."

