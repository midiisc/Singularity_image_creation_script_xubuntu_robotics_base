#!/bin/bash
# Intel MKL environment setup (auto-generated)

MKLROOT=/opt/intel/oneapi/mkl/latest
export MKLROOT

if [ -f "${MKLROOT}/env/vars.sh" ]; then
    # shellcheck disable=SC1090
    . "${MKLROOT}/env/vars.sh" >/dev/null 2>&1
fi

export LD_LIBRARY_PATH="${MKLROOT}/lib/intel64:${LD_LIBRARY_PATH:-}"
export LIBRARY_PATH="${MKLROOT}/lib/intel64:${LIBRARY_PATH:-}"
export CMAKE_PREFIX_PATH="${MKLROOT}:${CMAKE_PREFIX_PATH:-}"
export PKG_CONFIG_PATH="${MKLROOT}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

export MKL_THREADING_LAYER="${MKL_THREADING_LAYER:-GNU}"
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-32}"
export MKL_NUM_THREADS="${MKL_NUM_THREADS:-32}"

BLAS_LAPACK_STRING="-L${MKLROOT}/lib/intel64 -lmkl_intel_lp64 -lmkl_core -lmkl_gnu_thread -lgomp -lpthread -lm -ldl"
export BLAS_LIBRARIES="${BLAS_LIBRARIES:-${BLAS_LAPACK_STRING}}"
export LAPACK_LIBRARIES="${LAPACK_LIBRARIES:-${BLAS_LAPACK_STRING}}"

if [ -n "${PS1:-}" ]; then
    echo "✅ Intel MKL environment configured"
    echo "   MKLROOT: ${MKLROOT}"
    echo "   MKL Threading: ${MKL_THREADING_LAYER}"
    echo "   OMP Threads: ${OMP_NUM_THREADS}"
fi
