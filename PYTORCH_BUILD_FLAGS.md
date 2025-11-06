# PyTorch Build Flags Documentation

This document contains a comprehensive list of all PyTorch build flags extracted from the official PyTorch repository with detailed descriptions of their purposes.

**Source**: PyTorch GitHub Repository  
**Repository**: https://github.com/pytorch/pytorch  
**Documentation**: https://github.com/pytorch/pytorch#from-source  
**Generated**: 2025-11-06 04:36:47 UTC  
**PyTorch Source**: /tmp/pytorch_openblas_test/pytorch-2.9.0

---

## Overview

PyTorch build flags are environment variables that control the compilation process. They can be set before running `python setup.py build` or `python setup.py install`.

---

## Build Flags

### Core Build Flags (USE_*)

| Flag | Purpose | Default | Notes |
|------|---------|---------|-------|
| `USE_CUDA` | Enable CUDA support for GPU acceleration | 0 | Set to 1 to enable NVIDIA GPU support. Requires CUDA toolkit and drivers. |
| `USE_CUDNN` | Enable cuDNN library for optimized deep learning primitives | 0 | Set to 1 to enable cuDNN (convolution, pooling, etc.). Requires cuDNN library. |
| `USE_CUDSS` | Enable cuDSS (CUDA Direct Sparse Solver) | 0 | Set to 1 to enable sparse matrix solvers on GPU. |
| `USE_CUFILE` | Enable cuFile library for GPU-accelerated file I/O | 0 | Set to 1 to enable GPU Direct Storage support. |
| `USE_CUSPARSELT` | Enable cuSPARSELt library for sparse matrix operations | 0 | Set to 1 to enable optimized sparse tensor operations. |
| `USE_CUSTOM_DEBINFO` | Build specific files with debug info | - | Set to semicolon-separated file paths for selective debug symbols. |
| `USE_DISTRIBUTED` | Enable distributed training support | 0 | Set to 1 to enable multi-GPU/multi-node training capabilities. |
| `USE_FBGEMM` | Enable FBGEMM for quantized CPU operations | 0 | Set to 1 to enable Facebook's GEMM library for quantization. |
| `USE_FBGEMM_GENAI` | Enable FBGEMM GenAI optimizations | 0 | Set to 1 to enable generative AI optimizations in FBGEMM. |
| `USE_FLASH_ATTENTION` | Enable Flash Attention for efficient attention computation | 0 | Set to 1 to enable optimized attention mechanisms (memory efficient). |
| `USE_GLOO` | Enable Gloo backend for distributed training | 0 | Set to 1 to enable Gloo communication backend (CPU-based). |
| `USE_ITT` | Enable Intel VTune Profiler ITT functionality | 0 | Set to 1 to enable Intel Threading Tools integration. |
| `USE_KINETO` | Enable libkineto for profiling | 0 | Set to 1 to enable performance profiling with libkineto. |
| `USE_MEM_EFF_ATTENTION` | Enable memory-efficient attention | 0 | Set to 1 to enable memory-efficient attention implementations. |
| `USE_MKL` | Enable Intel MKL (Math Kernel Library) | Auto-detect | Set to 0 to disable MKL, use OpenBLAS instead. |
| `USE_MKLDNN` | Enable Intel MKL-DNN for CPU acceleration | Auto-detect | Set to 0 to disable MKL-DNN (requires USE_MKL=0 for OpenBLAS builds). |
| `USE_MPI` | Enable MPI backend for distributed training | 0 | Set to 1 to enable Message Passing Interface for multi-node training. |
| `USE_NCCL` | Enable NCCL for multi-GPU communication | 0 | Set to 1 to enable NVIDIA Collective Communications Library. |
| `USE_NIGHTLY` | Build nightly/pre-release version | 0 | Set to 1 to build from main branch instead of stable release. |
| `USE_NNPACK` | Enable NNPACK for optimized neural network operations | Auto-detect | Set to 0 to disable NNPACK (faster compilation). |
| `USE_NUMPY` | Enable NumPy support | 1 | Set to 0 to disable NumPy integration (not recommended). |
| `USE_OPENMP` | Enable OpenMP for parallel CPU operations | Auto-detect | Set to 1 to enable multi-threaded CPU operations (required for OpenBLAS builds). |
| `USE_PRIORITIZED_TEXT_FOR_LD` | Use prioritized text sections for linker | 0 | Advanced linker optimization flag. |
| `USE_ROCM_CK_GEMM` | Enable Composable Kernel GEMM for ROCm | 0 | Set to 1 for AMD GPU support with optimized GEMM operations. |
| `USE_ROCM_CK_SDPA` | Enable Composable Kernel SDPA for ROCm | 0 | Set to 1 for AMD GPU scaled dot-product attention. |
| `USE_ROCM_KERNEL_ASSERT` | Enable kernel assertions in ROCm | 0 | Set to 1 to enable debug assertions for AMD GPU kernels. |
| `USE_STATIC_MKL` | Statically link MKL libraries | 0 | Set to 1 to link MKL statically (Unix only, larger binaries). |
| `USE_SYSTEM_BENCHMARK` | Use system-installed Google Benchmark | 0 | Set to 1 to use system benchmark library instead of bundled version. |
| `USE_SYSTEM_CPUINFO` | Use system-installed cpuinfo library | 0 | Set to 1 to use system cpuinfo instead of bundled version. |
| `USE_SYSTEM_EIGEN_INSTALL` | Use system-installed Eigen library | 0 | Set to 1 to use system Eigen instead of bundled version. |
| `USE_SYSTEM_FXDIV` | Use system-installed fxdiv library | 0 | Set to 1 to use system fxdiv instead of bundled version. |
| `USE_SYSTEM_GLOO` | Use system-installed Gloo library | 0 | Set to 1 to use system Gloo instead of bundled version. |
| `USE_SYSTEM_LIBS` | Use system-provided libraries where possible | 0 | Set to 1 to prefer system libraries (work in progress, may cause issues). |
| `USE_SYSTEM_NCCL` | Use system-installed NCCL | 0 | Set to 1 to use system NCCL instead of bundled version. |
| `USE_SYSTEM_NVTX` | Use system-installed NVTX | 0 | Set to 1 to use system NVIDIA Tools Extension instead of bundled. |
| `USE_SYSTEM_ONNX` | Use system-installed ONNX | 0 | Set to 1 to use system ONNX instead of bundled version. |
| `USE_SYSTEM_PSIMD` | Use system-installed psimd library | 0 | Set to 1 to use system psimd instead of bundled version. |
| `USE_SYSTEM_PTHREADPOOL` | Use system-installed pthreadpool | 0 | Set to 1 to use system pthreadpool instead of bundled version. |
| `USE_SYSTEM_SLEEF` | Use system-installed SLEEF library | 0 | Set to 1 to use system SLEEF instead of bundled version. |
| `USE_SYSTEM_XNNPACK` | Use system-installed XNNPACK | 0 | Set to 1 to use system XNNPACK instead of bundled version. |
| `USE_TBB` | Enable Intel Threading Building Blocks | Auto-detect | Set to 1 to enable TBB for parallel CPU operations. |
| `USE_TENSORPIPE` | Enable TensorPipe for distributed training | 0 | Set to 1 to enable TensorPipe communication backend. |

### CUDA-Specific Flags

| Flag | Purpose | Default | Notes |
|------|---------|---------|-------|
| `TORCH_CUDA_ARCH_LIST` | Specify CUDA compute capabilities to build for | Auto-detect | Format: "8.6;8.9;9.0" (semicolon-separated). Defines which GPU architectures to compile kernels for. |
| `CMAKE_CUDA_ARCHITECTURES` | CMake CUDA architectures | Auto-detect | Format: "86;89;90" (no dots). CMake equivalent of TORCH_CUDA_ARCH_LIST. |
| `CUDA_HOME` | Path to CUDA installation | Auto-detect | Set if CUDA is installed in non-standard location. |
| `CUDA_NVCC_EXECUTABLE` | Path to nvcc compiler | Auto-detect | Set if nvcc is not in PATH. |

### CMake Flags

| Flag | Purpose | Default | Notes |
|------|---------|---------|-------|
| `CMAKE_OSX_ARCHITECTURES` | macOS target architectures | Auto-detect | Set to "x86_64" or "arm64" for macOS builds. |
| `CMAKE_OSX_SYSROOT` | macOS SDK path | Auto-detect | Set to macOS SDK path if needed. |
| `CMAKE_BUILD_TYPE` | Build type (Release/Debug) | Release | Set to "Debug" for debug builds (slower, larger binaries). |
| `CMAKE_BUILD_PARALLEL_LEVEL` | Number of parallel build jobs | Auto-detect | Controls CMake parallel compilation. |

### Build Configuration Flags

| Flag | Purpose | Default | Notes |
|------|---------|---------|-------|
| `BUILD_CUSTOM_PROTOBUF` | Build custom Protobuf | Auto-detect | Set to OFF to use system Protobuf. |
| `BUILD_DEPS` | Build dependencies | 1 | Set to 0 to skip dependency building. |
| `BUILD_LIBTORCH_WHL` | Build libtorch wheel | 0 | Set to 1 to build C++ libtorch wheel. |
| `BUILD_PYTHON_ONLY` | Build Python package only | 0 | Set to 1 to skip C++ libtorch build. |
| `BUILD_TEST` | Build test suite | 1 | Set to 0 to skip tests (faster build). |
| `BUILD_WARNING` | Enable build warnings | 1 | Set to 0 to suppress warnings. |
| `MAX_JOBS` | Maximum parallel compilation jobs | Auto-detect | Controls build parallelism. Set to lower value if system runs out of memory. |

### Runtime Configuration (Not Build Flags)

These are runtime environment variables, not build flags:

| Variable | Purpose | Notes |
|----------|---------|-------|
| `OMP_NUM_THREADS` | Number of OpenMP threads | Controls CPU parallelism at runtime. |
| `MKL_NUM_THREADS` | Number of MKL threads | Controls MKL parallelism at runtime. |
| `OPENBLAS_NUM_THREADS` | Number of OpenBLAS threads | Controls OpenBLAS parallelism at runtime. |
| `NUMEXPR_NUM_THREADS` | Number of NumExpr threads | Controls NumExpr parallelism at runtime. |

---

## Common Build Flag Combinations

### OpenBLAS Build (No MKL)

```bash
export USE_MKL=0
export USE_MKLDNN=0
export USE_STATIC_MKL=0
export BLAS=OpenBLAS
export LAPACK=OpenBLAS
export USE_OPENMP=1
export USE_TBB=1
```

**Purpose**: Build PyTorch with OpenBLAS instead of Intel MKL. Useful for systems without MKL or when avoiding MKL licensing.

### CUDA Build with OpenBLAS

```bash
export USE_MKL=0
export USE_MKLDNN=0
export USE_CUDA=1
export USE_CUDNN=1
export TORCH_CUDA_ARCH_LIST="8.6;8.9;9.0"
export CMAKE_CUDA_ARCHITECTURES="86;89;90"
export USE_OPENMP=1
```

**Purpose**: Build PyTorch with GPU support (CUDA) and OpenBLAS for CPU operations. Supports multiple GPU architectures.

### Performance Libraries

```bash
export USE_OPENMP=1
export USE_TBB=1
export OMP_NUM_THREADS=$(nproc)
export OPENBLAS_NUM_THREADS=$(nproc)
export MKL_NUM_THREADS=$(nproc)
export NUMEXPR_NUM_THREADS=$(nproc)
```

**Purpose**: Enable all CPU parallelism libraries and configure thread counts for optimal performance.

### Minimal Build (Faster Compilation)

```bash
export BUILD_TEST=0
export USE_DISTRIBUTED=0
export USE_TENSORPIPE=0
export USE_GLOO=0
export USE_MPI=0
export USE_NNPACK=0
export USE_FBGEMM=0
```

**Purpose**: Disable optional features to speed up compilation. Reduces build time but limits functionality.

---

## Compilation Script Usage

### Can I run the PyTorch compilation script on HPC?

**Yes!** The `test_pytorch_compilation.sh` script is designed to work on HPC systems:

1. **Automatic download**: The script automatically downloads PyTorch source from GitHub
2. **Resource management**: Built-in CPU, memory, and I/O limiting to prevent system saturation
3. **Singularity support**: Can run inside Singularity containers with overlay support
4. **No GPU required for compilation**: GPU is only needed for running PyTorch, not for building it

**Usage on HPC:**
```bash
# Run directly on HPC node
./test_pytorch_compilation.sh

# Or inside Singularity container with overlay
./test_pytorch_compilation.sh --overlay overlay.img --image image.sif

# With GPU support (for CUDA compilation)
./test_pytorch_compilation.sh --overlay overlay.img --image image.sif --gpu
```

### Can I run it on the image build PC (CUDA 12.7, moderate GPU)?

**Yes!** The script works perfectly on your build PC:

1. **CUDA 12.7 compatibility**: PyTorch 2.9 supports CUDA 12.x. The script will detect CUDA 12.7 automatically
2. **GPU not needed for compilation**: The GPU is only used to verify CUDA installation. Compilation itself is CPU-based
3. **Moderate GPU is fine**: GPU performance doesn't affect compilation speed - only CPU and memory matter
4. **Resource limiting**: The script automatically limits CPU usage (25% max) and memory to prevent system freezes

**What the script does:**
- Downloads PyTorch source from GitHub (if not already present)
- Compiles PyTorch with OpenBLAS + CUDA support
- Creates a wheel file (`.whl`) that can be installed later
- Does NOT install PyTorch (build only, as requested)

**Build time estimates:**
- On moderate hardware: 1-3 hours depending on CPU cores and memory
- The script uses conservative resource limits to prevent system freezes
- Build artifacts are preserved for reuse (large downloads are cached)

**Important notes:**
- The script requires internet access to download PyTorch source
- CUDA toolkit and cuDNN must be installed (the script verifies this)
- Sufficient disk space needed (~10-20GB for source + build artifacts)
- Memory: At least 8GB available RAM recommended (script warns if low)

---

## Notes

- All flags are environment variables that should be set before running the build
- Boolean flags typically use `1` for enabled, `0` for disabled
- Some flags may require additional dependencies to be installed
- Refer to the official PyTorch documentation for the most up-to-date information
- Flag names are case-sensitive
- Threading flags (OMP_NUM_THREADS, etc.) are runtime configuration, not build flags
- GPU is not required for compilation - only for running PyTorch after installation
- CUDA version compatibility: PyTorch 2.9 supports CUDA 11.8, 12.1, 12.4, and 12.6+ (12.7 should work)

---

## References

- [PyTorch Build Documentation](https://github.com/pytorch/pytorch#from-source)
- [PyTorch GitHub Repository](https://github.com/pytorch/pytorch)
- [PyTorch Releases](https://github.com/pytorch/pytorch/releases)
- [PyTorch setup.py](https://github.com/pytorch/pytorch/blob/main/setup.py)
- [CUDA Compatibility](https://pytorch.org/get-started/locally/)
