#!/usr/bin/env bash
# setup-cuda-dev-local.sh – Prepare CUDA toolchain on a GPU-less build host
#
# Installs CUDA headers/libraries required to compile GPU-enabled projects
# without attempting to load kernel drivers. Intended for Ubuntu 24.04 builders
# targeting deployment on NVIDIA A6000-class hardware.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${REPO_ROOT}/config.sh"

if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${CONFIG_FILE}"
else
    echo "WARNING: config.sh not found at ${CONFIG_FILE}; falling back to script defaults." >&2
fi

echo "=== CUDA development environment (compile-only) ==="

TARGET_CUDA_VERSION="${CUDA_VERSION:-12.6}"
PYTORCH_VERSION_RAW="${PYTORCH_VERSION:-v2.6.0}"
PYTORCH_VERSION_STR="${PYTORCH_VERSION_RAW#v}"
PYTORCH_INDEX_URL="${PYTORCH_INDEX_URL:-https://download.pytorch.org/whl/cu126}"
TORCHVISION_VERSION="${TORCHVISION_VERSION:-0.21.0}"
TORCHAUDIO_VERSION="${TORCHAUDIO_VERSION:-${PYTORCH_VERSION_STR}}"
INSTALL_PYTORCH_BINARIES="${INSTALL_PYTORCH_BINARIES:-true}"

ensure_cuda_keyring() {
    local keyring_pkg="cuda-keyring"
    if dpkg-query -W -f='${Status}\n' "${keyring_pkg}" 2>/dev/null | grep -q "install ok installed"; then
        return 0
    fi

    local keyring_deb="${NVIDIA_KEYRING_DEB:-cuda-keyring_${NVIDIA_KEYRING_VER}_all.deb}"
    local keyring_url="${CUDA_REPO_URL}/${keyring_deb}"
    local tmp_path="/tmp/${keyring_deb}"

    echo "Ensuring NVIDIA CUDA repository keyring is installed..."
    if curl -fsSL "${keyring_url}" -o "${tmp_path}"; then
        if sudo dpkg -i "${tmp_path}"; then
            rm -f "${tmp_path}"
            return 0
        fi
    fi

    rm -f "${tmp_path}"
    echo "ERROR: Failed to install NVIDIA CUDA keyring package (${keyring_deb})." >&2
    return 1
}

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

ensure_shellcheck() {
    if command -v shellcheck >/dev/null 2>&1; then
        echo "ShellCheck already present; skipping installation."
        return 0
    fi

    if install_packages "ShellCheck (shell script analyzer)" shellcheck; then
        return 0
    fi

    echo "WARNING: Failed to install ShellCheck." >&2
    return 1
}

ensure_python_tooling() {
    if ! command -v python3 >/dev/null 2>&1; then
        echo "Python 3 not found; installing python3 interpreter..."
        install_packages "Python 3 interpreter" python3
    fi

    if ! python3 -m pip --version >/dev/null 2>&1; then
        echo "python3-pip missing; installing..."
        install_packages "python3-pip" python3-pip
    fi
}

install_pytorch_binaries() {
    if [[ "${INSTALL_PYTORCH_BINARIES}" != "true" ]]; then
        echo "Skipping PyTorch binary installation (INSTALL_PYTORCH_BINARIES=${INSTALL_PYTORCH_BINARIES})."
        return 0
    fi

    ensure_python_tooling

    if python3 - <<PYTHON >/dev/null 2>&1
import sys
try:
    import torch
    import torchvision
    import torchaudio
except ModuleNotFoundError:
    sys.exit(1)
if not torch.__version__.startswith("${PYTORCH_VERSION_STR}"):
    sys.exit(1)
sys.exit(0)
PYTHON
    then
        echo "PyTorch ${PYTORCH_VERSION_STR} (with torchvision/torchaudio) already installed; skipping."
        return 0
    fi

    echo "Installing PyTorch ${PYTORCH_VERSION_STR} binaries (CUDA 12.6 wheel, MKL enabled)..."
    sudo -H python3 -m pip install --upgrade --no-cache-dir pip setuptools wheel
    sudo -H python3 -m pip install --no-cache-dir \
        "torch==${PYTORCH_VERSION_STR}" \
        "torchvision==${TORCHVISION_VERSION}" \
        "torchaudio==${TORCHAUDIO_VERSION}" \
        --index-url "${PYTORCH_INDEX_URL}"

    echo "Validating PyTorch installation..."
    if ! python3 - <<PYTHON
import torch
import torchvision
import torchaudio
import sys
print(f"torch {torch.__version__}, torchvision {torchvision.__version__}, torchaudio {torchaudio.__version__}")
if not torch.__version__.startswith("${PYTORCH_VERSION_STR}"):
    sys.exit("ERROR: Unexpected torch version")
if torch.backends.mkl.is_available():
    print("MKL backend available ✔")
else:
    print("WARNING: MKL backend not detected")
print("CUDA available:", torch.cuda.is_available())
PYTHON
    then
        echo "ERROR: PyTorch validation failed." >&2
        return 1
    fi

    return 0
}

DETECTED_NVCC="$(command -v nvcc || true)"
if [[ -n "${DETECTED_NVCC}" ]]; then
    DETECTED_VERSION_RAW="$("${DETECTED_NVCC}" --version | grep -oE 'release [0-9]+\.[0-9]+' | awk '{print $2}' || true)"
    if [[ -n "${DETECTED_VERSION_RAW}" ]]; then
        echo "Detected existing CUDA toolkit (nvcc ${DETECTED_VERSION_RAW}) at $(dirname "$(dirname "$(realpath "${DETECTED_NVCC}")")")"
        CUDA_VERSION_USE="${DETECTED_VERSION_RAW}"
        CUDA_HOME_DEFAULT="$(dirname "$(dirname "$(realpath "${DETECTED_NVCC}")")")"
    else
        echo "Found nvcc but could not parse version; will proceed with installation checks."
    fi
fi

CUDA_VERSION_FOR_INSTALL="${CUDA_VERSION_USE:-${TARGET_CUDA_VERSION}}"
CUDA_DEFAULT_PKG_SUFFIX="${CUDA_VERSION_FOR_INSTALL/./-}"
CUDA_TOOLKIT_PACKAGE_DEFAULT="${CUDA_TOOLKIT_PACKAGE:-cuda-toolkit-${CUDA_DEFAULT_PKG_SUFFIX}}"

if ! ensure_cuda_keyring; then
    echo "ERROR: Unable to configure NVIDIA CUDA APT repository." >&2
    exit 1
fi

sudo apt-get update

ensure_shellcheck || true

GENERIC_PACKAGES=(
    "cuda-toolkit"
    "libcublas-dev"
    "libcusparse-dev"
    "libcusolver-dev"
    "libcurand-dev"
    "libnpp-dev"
    "cuda-gdb"
    "cuda-sanitizer"
)

# Build a preference-ordered list of CUDA versions to try.
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
    if apt-cache policy "cuda-toolkit-${pkg_suffix}" | awk '/Candidate:/ {print $2}' | grep -vq "(none)"; then
        VERSIONED_PACKAGES=(
            "cuda-toolkit-${pkg_suffix}"
            "libcublas-${pkg_suffix}"
            "libcublas-dev-${pkg_suffix}"
            "libcusparse-${pkg_suffix}"
            "libcusparse-dev-${pkg_suffix}"
            "libcusolver-${pkg_suffix}"
            "libcusolver-dev-${pkg_suffix}"
            "libcurand-${pkg_suffix}"
            "libcurand-dev-${pkg_suffix}"
            "libnpp-${pkg_suffix}"
            "libnpp-dev-${pkg_suffix}"
            "cuda-gdb-${pkg_suffix}"
            "cuda-sanitizer-${pkg_suffix}"
        )

        if install_packages "CUDA ${candidate} packages" "${VERSIONED_PACKAGES[@]}"; then
            CUDA_VERSION_FOR_INSTALL="${candidate}"
            INSTALL_SUCCESS=1
            break
        else
            echo "Attempt to install CUDA ${candidate} packages failed; trying next candidate."
        fi
    else
        echo "CUDA ${candidate} packages not available in APT repo; skipping."
    fi
done

if [[ "${INSTALL_SUCCESS}" -ne 1 ]]; then
    echo "Version-specific CUDA packages unavailable or failed to install; falling back to generic package names."
    if install_packages "generic CUDA packages" "${GENERIC_PACKAGES[@]}"; then
        INSTALL_SUCCESS=1
    else
        if [[ -n "${DETECTED_NVCC}" ]]; then
            echo "WARNING: Failed to install CUDA development packages via APT, continuing with existing toolkit."
        else
            echo "ERROR: Unable to install required CUDA development packages."
            exit 1
        fi
    fi
fi

echo "⚠️  Skipping NVIDIA driver install (no GPU present). Ignore dkms warnings."

# Re-detect in case packages were installed or upgraded.
DETECTED_NVCC="$(command -v nvcc || true)"
if [[ -n "${DETECTED_NVCC}" ]]; then
    DETECTED_VERSION_RAW="$("${DETECTED_NVCC}" --version | grep -oE 'release [0-9]+\.[0-9]+' | awk '{print $2}' || true)"
    CUDA_HOME_DEFAULT="$(dirname "$(dirname "$(realpath "${DETECTED_NVCC}")")")"
    CUDA_VERSION_USE="${DETECTED_VERSION_RAW:-${CUDA_VERSION_FOR_INSTALL}}"
fi

CUDA_HOME=${CUDA_HOME:-${CUDA_HOME_DEFAULT:-/usr/local/cuda}}
if [[ ! -d "${CUDA_HOME}" ]]; then
    echo "ERROR: Expected CUDA_HOME directory '${CUDA_HOME}' not found."
    exit 1
fi

read -r -d '' CUDA_ENV_SCRIPT <<EOF || true
export CUDA_HOME=${CUDA_HOME}
export CUDA_TOOLKIT_ROOT_DIR=\${CUDA_HOME}
export PATH=\${CUDA_HOME}/bin\${PATH:+:\${PATH}}
export LD_LIBRARY_PATH=\${CUDA_HOME}/lib64\${LD_LIBRARY_PATH:+:\${LD_LIBRARY_PATH}}
export LIBRARY_PATH=\${CUDA_HOME}/lib64\${LIBRARY_PATH:+:\${LIBRARY_PATH}}
export PKG_CONFIG_PATH=\${CUDA_HOME}/lib/pkgconfig\${PKG_CONFIG_PATH:+:\${PKG_CONFIG_PATH}}
export CMAKE_PREFIX_PATH=\${CUDA_HOME}\${CMAKE_PREFIX_PATH:+:\${CMAKE_PREFIX_PATH}}
export CUDA_ARCH=sm_86
export CMAKE_CUDA_ARCHITECTURES=86
export CUDAFLAGS="-O3 -fPIC -Xcompiler -fopenmp"
EOF

if [[ "$(id -u)" -eq 0 ]]; then
    printf '%s\n' "${CUDA_ENV_SCRIPT}" > /etc/profile.d/cuda-dev.sh
else
    printf '%s\n' "${CUDA_ENV_SCRIPT}" | sudo tee /etc/profile.d/cuda-dev.sh >/dev/null
fi

# shellcheck disable=SC1091
source /etc/profile.d/cuda-dev.sh

echo ""
nvcc --version
find "${CUDA_HOME}" -maxdepth 3 -name "cublas.h" -o -name "cusparse.h" | head -n 5
echo "✅ CUDA development environment ready (compile-only)."

if ! install_pytorch_binaries; then
    echo "WARNING: PyTorch installation encountered issues. Please review the logs above." >&2
fi

