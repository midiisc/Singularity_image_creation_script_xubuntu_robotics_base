#!/usr/bin/env bash
# verify-cuda-mkl-linkage.sh – Inspect shared libraries for MKL/CUDA/OpenMP usage

set -euo pipefail

INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"

declare -a TARGETS=(
    "${INSTALL_PREFIX}/lib/libcholmod.so:SuiteSparse CHOLMOD"
    "${INSTALL_PREFIX}/lib/libspqr.so:SuiteSparse SPQR"
    "${INSTALL_PREFIX}/lib/libgraphblas.so:SuiteSparse GraphBLAS"
    "${INSTALL_PREFIX}/lib/libceres.so:Ceres Solver"
    "${INSTALL_PREFIX}/lib/libg2o_core.so:g2o Core"
    "${INSTALL_PREFIX}/lib/libopencv_core.so:OpenCV Core"
)

echo "=== Verifying MKL / CUDA / OpenMP linkage ==="

for entry in "${TARGETS[@]}"; do
    IFS=":" read -r path label <<<"${entry}"
    echo ""
    if [ ! -f "${path}" ]; then
        echo "⚠️  ${label}: ${path} missing"
        continue
    fi
    echo "${label} (${path})"

    if ldd "${path}" 2>/dev/null | grep -q "libmkl_"; then
        echo "  ✅ MKL detected"
    else
        echo "  ❌ MKL libraries not found"
    fi

    if ldd "${path}" 2>/dev/null | grep -qE "libcudart|libcublas|libcusparse|libcusolver"; then
        echo "  ✅ CUDA dependencies detected"
    else
        echo "  ⚠️  No direct CUDA linkage (may rely on optional modules)"
    fi

    if ldd "${path}" 2>/dev/null | grep -q "libgomp"; then
        echo "  ✅ GNU OpenMP runtime detected"
    elif ldd "${path}" 2>/dev/null | grep -q "libomp"; then
        echo "  ✅ LLVM OpenMP runtime detected"
    else
        echo "  ❌ No OpenMP runtime found"
    fi
done

echo ""
echo "✅ Verification pass complete."

