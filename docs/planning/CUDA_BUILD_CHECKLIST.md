# CUDA Build Checklist

Quick reference for enabling CUDA across the MKL-enabled robotics stack.

## 1. System Prerequisites
### Local build machine (no NVIDIA GPU)
- (Optional) Run `scripts/setup-cuda-dev-local.sh` if you still need to compile CUDA-enabled libraries directly on the host. The helper installs the CUDA toolkit and companion developer libraries without attempting to load a kernel driver, sourcing `config.sh` so the version suffixes stay in sync with `CUDA_VERSION`. Packages covered:  
  `cuda-toolkit-12-6`, `libcublas-12-6`, `libcublas-dev-12-6`, `libcusparse-12-6`, `libcusparse-dev-12-6`, `libcusolver-12-6`, `libcusolver-dev-12-6`, `libcurand-12-6`, `libcurand-dev-12-6`, `libnpp-12-6`, `libnpp-dev-12-6`, `cuda-gdb-12-6`, `cuda-sanitizer-12-6`.
- Full CUDA runtime installs should pull the metapackage defined in `config.sh` (`cuda-12-6`), which in turn pulls the matching `nvidia-open-560` driver branch required for CUDA 12.6 on Ubuntu 24.04.  
- cuDNN (`cudnn-cuda-12`) and TensorRT can be added if downstream workloads require them; they remain idle without hardware.
- Driver packages may install but will remain inactive without a GPU; ignore `nvidia-smi` failures on the local PC.

### HPC runtime node (A6000)
- Confirm `nvidia-smi` shows the A6000 and driver ≥ 550.
- Ensure CUDA toolkit 12.6 (matching the build) and runtime drivers are present.
- Environment:
  ```
  export CUDA_HOME=/usr/local/cuda-12.6
  export PATH="$CUDA_HOME/bin:${PATH}"
  export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"
  export CMAKE_PREFIX_PATH="$CUDA_HOME:${CMAKE_PREFIX_PATH:-}"
  ```
- Install build tools early: `gcc g++ gfortran clang cmake ninja-build ccache pkg-config`.

## 2. Common CMake Flags
- `-DCMAKE_BUILD_TYPE=Release`
- `-DCUDA_TOOLKIT_ROOT_DIR=$CUDA_HOME`
- `-DCMAKE_CUDA_ARCHITECTURES=86`
- `-DWITH_CUDA=ON` (OpenCV), `-DCUDA_ENABLED=ON` (COLMAP), `-DCeres_ENABLE_CUDA=ON` (Ceres), `-DBUILD_CUDA_MODULE=ON` (Open3D).
- **Note:** g2o does not support CUDA (confirmed in `docs/flags/G2O_20241228_CMAKE_FLAGS_DOCUMENTATION.md`). MKL configuration is sufficient.
- For SuiteSparse: `-DSUITESPARSE_USE_CUDA=ON -DSUITESPARSE_CUDA_ARCHITECTURES=86 -DCUBLAS_LIB=$CUDA_HOME/lib64/libcublas.so -DCUSPARSE_LIB=$CUDA_HOME/lib64/libcusparse.so -DCUSOLVER_LIB=$CUDA_HOME/lib64/libcusolver.so -DCURAND_LIB=$CUDA_HOME/lib64/libcurand.so`.

## 3. MKL/BLAS Coordination
- Install Intel oneAPI MKL (`intel-oneapi-mkl`, `intel-oneapi-mkl-devel`).
- Export MKL vars alongside CUDA:
  ```
  source /opt/intel/oneapi/mkl/latest/env/vars.sh
  export MKL_THREADING_LAYER=GNU
  export BLA_VENDOR=Intel10_64lp
  ```
- Link flags used across builds:
  ```
  -lmkl_intel_lp64 -lmkl_core -lmkl_gnu_thread -lgomp -lpthread -lm -ldl
  ```

## 4. Verification
- **Local PC:** Skip runtime binaries; instead ensure `nvcc --version` works and `ldd` on SuiteSparse, Ceres, OpenCV, COLMAP reports CUDA libraries resolving.
- **HPC node:** Run sample CUDA binaries (`deviceQuery`, `bandwidthTest`) and execute GPU smoke tests for each package (OpenCV CUDA modules, Ceres CUDA solver, Open3D GPU pipelines).
- Run `scripts/verify-cuda-mkl-linkage.sh` to confirm MKL/CUDA/OpenMP linkage before copying artefacts to the HPC node.
- Run `scripts/verify-mkl-env.sh` locally to compile and execute a `cblas_dgemm` probe against MKL and verify GNU OpenMP linkage.
- `xubuntu_robotics_base_full.sh` Block 26B now installs PyTorch CUDA 12.6 wheels and verifies MKL availability (`torch.backends.mkl.is_available()`).
- Container builds now install CUDA/cuDNN (Block 13) before compiling GPU-aware libraries (SuiteSparse, Ceres, OpenCV, etc.), so no additional manual step is required inside the image.

## 5. Troubleshooting Notes
- Avoid mixing GNU and Intel OpenMP runtimes; keeping `MKL_THREADING_LAYER=GNU` with GCC toolchain ensures `libgomp` only.
- On the build PC, `nvidia-smi` will report “No devices were found”; this is expected and safe to ignore.
- If CMake fails to find CUDA, confirm `FindCUDAToolkit.cmake` is ≥ 3.18 and `CMAKE_PREFIX_PATH` includes `$CUDA_HOME`.
- For container builds, add `%post` steps to install CUDA/MKL before compiling sources; ensure `nvidia-container-toolkit` runtime configuration is active on the HPC node.

Keep this checklist in sync with `docs/planning/MKL_MIGRATION_PLAN.md` as phases evolve.

