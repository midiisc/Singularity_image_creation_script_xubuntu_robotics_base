#!/usr/bin/env bash
# install-suitesparse-cuda-deps.sh – Ensure CUDA/MKL prerequisites for SuiteSparse

set -euo pipefail

echo "=== Installing CUDA companion libraries for SuiteSparse ==="

TARGET_CUDA_VERSION="12.6"

install_packages() {
    local description="$1"
    shift
    local -a packages=("$@")
    echo "Attempting to install ${description}: ${packages[*]}"
    set +e
    sudo apt-get install -y --no-install-recommends "${packages[@]}"
    local status=$?
    set -e
    return "${status}"
}

DETECTED_NVCC="$(command -v nvcc || true)"
if [[ -n "${DETECTED_NVCC}" ]]; then
    DETECTED_VERSION_RAW="$("${DETECTED_NVCC}" --version | grep -oE 'release [0-9]+\.[0-9]+' | awk '{print $2}' || true)"
    if [[ -n "${DETECTED_VERSION_RAW}" ]]; then
        echo "Detected existing CUDA toolkit version ${DETECTED_VERSION_RAW}"
        CUDA_VERSION_USE="${DETECTED_VERSION_RAW}"
    else
        echo "Found nvcc but could not parse version; proceeding with repository checks."
    fi
fi

CUDA_VERSION_FOR_INSTALL="${CUDA_VERSION_USE:-${TARGET_CUDA_VERSION}}"

sudo apt-get update

GENERIC_PACKAGES=(
    "libcublas-dev"
    "libcusparse-dev"
    "libcusolver-dev"
    "libcurand-dev"
    "libpthread-stubs0-dev"
    "libnuma-dev"
    "pkg-config"
    "libgmp-dev"
    "libmpfr-dev"
)

declare -a candidate_versions=()
declare -A seen_versions=()

if [[ -n "${CUDA_VERSION_USE:-}" ]]; then
    candidate_versions+=("${CUDA_VERSION_USE}")
    seen_versions["${CUDA_VERSION_USE}"]=1
fi

if [[ -z "${seen_versions[${TARGET_CUDA_VERSION}]:-}" ]]; then
    candidate_versions+=("${TARGET_CUDA_VERSION}")
    seen_versions["${TARGET_CUDA_VERSION}"]=1
fi

for fallback_version in 12.6 12.5 12.4 12.3 12.2; do
    if [[ -z "${seen_versions[${fallback_version}]:-}" ]]; then
        candidate_versions+=("${fallback_version}")
        seen_versions["${fallback_version}"]=1
    fi
done

INSTALL_SUCCESS=0
for candidate in "${candidate_versions[@]}"; do
    pkg_suffix=${candidate/./-}
    if apt-cache policy "libcublas-dev-${pkg_suffix}" | awk '/Candidate:/ {print $2}' | grep -vq "(none)"; then
        VERSIONED_PACKAGES=(
            "libcublas-${pkg_suffix}"
            "libcublas-dev-${pkg_suffix}"
            "libcusparse-${pkg_suffix}"
            "libcusparse-dev-${pkg_suffix}"
            "libcusolver-${pkg_suffix}"
            "libcusolver-dev-${pkg_suffix}"
            "libcurand-${pkg_suffix}"
            "libcurand-dev-${pkg_suffix}"
            "libpthread-stubs0-dev"
            "libnuma-dev"
            "pkg-config"
            "libgmp-dev"
            "libmpfr-dev"
        )
        if install_packages "CUDA companion packages ${candidate}" "${VERSIONED_PACKAGES[@]}"; then
            CUDA_VERSION_FOR_INSTALL="${candidate}"
            INSTALL_SUCCESS=1
            break
        else
            echo "Attempt to install CUDA companion packages ${candidate} failed; trying next candidate."
        fi
    else
        echo "CUDA companion packages ${candidate} not available; skipping."
    fi
done

if [[ "${INSTALL_SUCCESS}" -ne 1 ]]; then
    echo "Falling back to generic CUDA companion package names."
    if install_packages "generic CUDA companion packages" "${GENERIC_PACKAGES[@]}"; then
        INSTALL_SUCCESS=1
    else
        echo "ERROR: Unable to install CUDA companion libraries required for SuiteSparse."
        exit 1
    fi
fi

CUDA_HOME_DEFAULT=""
if [[ -n "${DETECTED_NVCC}" ]]; then
    CUDA_HOME_DEFAULT="$(dirname "$(dirname "$(realpath "${DETECTED_NVCC}")")")"
fi

CUDA_HOME=${CUDA_HOME:-${CUDA_HOME_DEFAULT:-/usr/local/cuda-${CUDA_VERSION_FOR_INSTALL}}}

echo ""
echo "=== Verifying library presence ==="

LIB_SEARCH_DIRS=(
    "/usr/lib"
    "/usr/local/lib"
    "${CUDA_HOME}/lib64"
    "/usr/lib/x86_64-linux-gnu"
)

if [[ -d "${CUDA_HOME}/targets/x86_64-linux/lib" ]]; then
    LIB_SEARCH_DIRS+=("${CUDA_HOME}/targets/x86_64-linux/lib")
fi

for alt_cuda in /usr/local/cuda-*/targets/x86_64-linux/lib; do
    if [[ -d "${alt_cuda}" ]]; then
        LIB_SEARCH_DIRS+=("${alt_cuda}")
    fi
done
for lib_base in "libcublas" "libcusparse" "libcusolver" "libcurand"; do
    if ldconfig -p 2>/dev/null | grep -q "${lib_base}\.so"; then
        echo "✅ ${lib_base}.so registered with ldconfig"
        continue
    fi
    found_path=""
    for dir in "${LIB_SEARCH_DIRS[@]}"; do
        if [[ -d "${dir}" ]] && find "${dir}" -maxdepth 1 -name "${lib_base}.so*" | grep -q "${lib_base}"; then
            found_path="$(find "${dir}" -maxdepth 1 -name "${lib_base}.so*" | head -n 1)"
            break
        fi
    done
    if [[ -n "${found_path}" ]]; then
        echo "✅ ${lib_base}.so located at ${found_path}"
    else
        echo "⚠️  ${lib_base}.so not discovered; ensure CUDA libraries are in LD_LIBRARY_PATH."
    fi
done

if pkg-config --exists gmp; then
    echo "✅ GMP detected via pkg-config (version $(pkg-config --modversion gmp))"
else
    echo "⚠️  GMP not found via pkg-config; SuiteSparse may fail to configure"
fi

if pkg-config --exists mpfr; then
    echo "✅ MPFR detected via pkg-config (version $(pkg-config --modversion mpfr))"
else
    echo "⚠️  MPFR not found via pkg-config; SuiteSparse components relying on MPFR may fail"
fi

for dir in "thrust" "cub"; do
    if [ -d "${CUDA_HOME}/include/${dir}" ]; then
        echo "✅ ${dir} headers present"
    else
        echo "⚠️  ${dir} headers missing under ${CUDA_HOME}/include"
    fi
done

echo "✅ SuiteSparse CUDA dependencies checked."

