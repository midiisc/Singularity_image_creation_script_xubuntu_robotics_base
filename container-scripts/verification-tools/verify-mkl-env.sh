#!/usr/bin/env bash
# verify-mkl-env.sh – Compile and run a trivial MKL CBLAS smoke test.
#
# This script validates that the local toolchain can find and link Intel MKL
# with the GNU OpenMP runtime. It emits diagnostic information, compiles a tiny
# `cblas_dgemm` program, runs it, and inspects the resulting binary for MKL
# dependencies.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

info()  { printf '[info] %s\n' "$*"; }
warn()  { printf '[warn] %s\n' "$*" >&2; }
error() { printf '[error] %s\n' "$*" >&2; }

cleanup() {
    if [[ -n "${TMP_WORKDIR:-}" && -d "${TMP_WORKDIR}" ]]; then
        rm -rf "${TMP_WORKDIR}"
    fi
}
trap cleanup EXIT

if ! command -v gcc >/dev/null 2>&1; then
    error "gcc not found on PATH; install build-essential/gcc before running."
    exit 1
fi

MKLROOT="${MKLROOT:-}"
if [[ -z "${MKLROOT}" ]]; then
    # Attempt to source oneAPI MKL environment if present
    DEFAULT_MKL_VARS="/opt/intel/oneapi/mkl/latest/env/vars.sh"
    if [[ -f "${DEFAULT_MKL_VARS}" ]]; then
        info "MKLROOT not set – sourcing ${DEFAULT_MKL_VARS}"
        # shellcheck disable=SC1090
        source "${DEFAULT_MKL_VARS}"
    fi
fi

MKLROOT="${MKLROOT:-}"
if [[ -z "${MKLROOT}" ]]; then
    error "MKLROOT is not set and could not be inferred; please source MKL vars.sh."
    exit 1
fi

if [[ ! -d "${MKLROOT}/include" ]]; then
    error "MKL include directory not found at ${MKLROOT}/include"
    exit 1
fi

LIB_DIR="${MKL_LIB_DIR:-${MKLROOT}/lib/intel64}"
if [[ ! -d "${LIB_DIR}" ]]; then
    error "MKL library directory not found at ${LIB_DIR}"
    exit 1
fi

export MKL_THREADING_LAYER="${MKL_THREADING_LAYER:-GNU}"
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-4}"

info "MKLROOT=${MKLROOT}"
info "MKL library dir=${LIB_DIR}"
info "MKL threading layer=${MKL_THREADING_LAYER}"
info "OMP_NUM_THREADS=${OMP_NUM_THREADS}"

TMP_WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/mkl-verify-XXXXXX")"
SRC_FILE="${TMP_WORKDIR}/mkl_dgemm.c"
BIN_FILE="${TMP_WORKDIR}/mkl_dgemm"

cat > "${SRC_FILE}" <<'EOF'
#include <stdio.h>
#include <math.h>
#include "mkl_cblas.h"

int main(void) {
    const MKL_INT n = 2;
    const double A[4] = {1.0, 2.0, 3.0, 4.0};
    const double B[4] = {5.0, 6.0, 7.0, 8.0};
    double C[4] = {0.0, 0.0, 0.0, 0.0};

    cblas_dgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans,
                n, n, n,
                1.0, A, n,
                B, n,
                0.0, C, n);

    const double expected00 = 19.0; /* 1*5 + 2*7 */
    const double tol = 1e-9;

    if (fabs(C[0] - expected00) > tol) {
        fprintf(stderr,
                "Unexpected DGEMM result: C[0]=%.12f (expected %.12f)\n",
                C[0], expected00);
        return 2;
    }

    printf("MKL DGEMM check passed. C = [%.1f %.1f %.1f %.1f]\n",
           C[0], C[1], C[2], C[3]);
    return 0;
}
EOF

info "Compiling MKL DGEMM probe..."
set -x
gcc "${SRC_FILE}" -o "${BIN_FILE}" \
    -I"${MKLROOT}/include" \
    -L"${LIB_DIR}" \
    -fopenmp -O2 \
    -Wl,--start-group \
      -lmkl_intel_lp64 -lmkl_core -lmkl_gnu_thread \
    -Wl,--end-group \
    -lgomp -lpthread -lm -ldl
set +x

info "Running MKL probe binary..."
if ! "${BIN_FILE}"; then
    error "MKL DGEMM runtime check failed."
    exit 1
fi

info "Inspecting binary linkage..."
if command -v ldd >/dev/null 2>&1; then
    if ldd "${BIN_FILE}" | grep -q "libmkl"; then
        info "ldd confirms MKL shared libraries are linked."
    else
        warn "ldd output did not list MKL libraries – investigate static linking or rpath."
    fi

    if ldd "${BIN_FILE}" | grep -q "libgomp"; then
        info "GNU OpenMP runtime detected."
    else
        warn "GNU OpenMP runtime not detected in ldd output."
    fi
else
    warn "ldd not available; skipping linkage inspection."
fi

info "MKL environment verification complete."

