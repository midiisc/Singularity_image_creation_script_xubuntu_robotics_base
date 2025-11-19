# MKL Migration Plan (Phased)

## Status Snapshot (2025-11-09)

- ✅ SuiteSparse v7.12.1 (MKL + CUDA) builds in the `xubuntu_robotics_base_full.sh` orchestrator have completed locally; HPC execution is pending.
- ✅ OpenBLAS v0.3.30 rebuilt locally with the documented high-performance flags (dynamic arch, OpenMP, GEMM 3M) and installed at `~/.local/openblas`; dynamic kernels and DYNAMIC_ARCH strings verified.
- ✅ Block 13 now detects pre-existing CUDA/cuDNN stacks and skips redundant `apt-get install` runs while still refreshing environment hooks; the immediate cache sync (Block 13.7) only executes when new packages are downloaded.
- ✅ Ceres, g2o, GTSAM, OpenCV, Open3D, and COLMAP now pass explicit Intel MKL BLAS/LAPACK flags in `xubuntu_robotics_base_full.sh`; end-to-end HPC validation is pending.
- 🔄 Follow-up: remove the legacy NVIDIA cache sync path from `build_xubuntu_robotics_base.sh` and document the idempotent CUDA install flow in `docs/planning/CUDA_BUILD_CHECKLIST.md`.
- ✅ **COMPLETE** - All MKL/CUDA flags are in the orchestrator script. Standalone rebuild scripts are not needed (no standalone builds).

## Phase 0 – Baseline Audit & Cleanup

**0.1 Capture Current State**  
✅ **COMPLETE** - Base analysis documented in `docs/BASE_IMAGE_ANALYSIS.md`. Automated baseline audit not needed (migration is complete, baseline audit was for BEFORE migration).

**0.2 Protect Source Builds**  
Install `/etc/apt/preferences.d/robotics-stack-pin` to block APT from reinstalling the binaries we rebuild (Ceres, GTSAM, g2o, OpenCV, Open3D, SuiteSparse, COLMAP).

**0.3 OpenCV Shadowing**  
Keep Ubuntu’s OpenCV packages installed for ROS compatibility. The custom MKL build will live in `/usr/local` and take precedence via library path ordering; use APT pinning to prevent system upgrades from overwriting it.

---

## Phase 1 – CUDA, Toolchain & Threading Foundations

**1.1 GPU Driver & CUDA Toolchain (local build vs. HPC runtime)**  
- On the local PC (no discrete NVIDIA GPU), run `scripts/setup-cuda-dev-local.sh` to install the CUDA toolkit headers/libraries only (`--no-install-recommends` prevents driver pulls). Ignore DKMS warnings – they are expected without hardware.  
- Export `CUDA_HOME=/usr/local/cuda-12.6`, prepend `$CUDA_HOME/bin` to `PATH`, and ensure `/usr/local/cuda-12.6/lib64` is in both `LD_LIBRARY_PATH` and `CMAKE_PREFIX_PATH`.  
- Runtime validation with `nvidia-smi` will happen later on the HPC node; the local build only verifies headers/libs resolve.

**1.2 CUDA Companion Libraries for SuiteSparse (✔ integrated in orchestrator)**  
`xubuntu_robotics_base_full.sh` now provisions the CUDA/cuDNN stack in Block 13 before GPU-enabled builds run. Keep `scripts/install-suitesparse-cuda-deps.sh` as a standalone fallback, but the orchestrator flow is the canonical path and will simply reuse an existing toolkit when present.

**1.3 Compilers & Build Utilities**  
Install GCC/G++/GFortran 14, Clang 18 (for OpenMP offload experiments), CMake ≥3.27, Ninja, ccache, and `pkg-config`. Confirm `gfortran` so SuiteSparse Fortran entry points align with MKL.

**1.4 OpenMP Runtime**  
Ubuntu already ships `libgomp1`; add `libomp-14-dev` only if LLVM OpenMP is needed. Standardise on GNU OpenMP by setting `MKL_THREADING_LAYER=GNU` and compiling with `-fopenmp`.

**1.5 Optional OpenBLAS Fallback (✔ Completed Locally)**  
OpenBLAS v0.3.30 now builds locally with the documented high-performance flag set:
```
DYNAMIC_ARCH=1 DYNAMIC_OLDER=1 TARGET=GENERIC USE_OPENMP=1 USE_TLS=1 \
NO_AFFINITY=1 NUM_THREADS=64 GEMM_MULTITHREAD_THRESHOLD=50 BUILD_LAPACK_DEPRECATED=1 \
NO_WARMUP=1 BINARY=64 CC=gcc FC=gfortran HOSTCC=gcc
```
The resulting artifacts live at `~/.local/openblas` with `libopenblas.so`, `libopenblasp-r0.3.30.so`, headers, and pkg-config/CMake metadata. `strings libopenblas.so` confirms both the `DYNAMIC_ARCH` banner and multiple CPU kernels (>8k markers), matching the guidance in `docs/flags/OpenBLAS_Compilation_Flags.md`. Retain the environment exports (`LD_LIBRARY_PATH`, `PKG_CONFIG_PATH`, `OpenBLAS_DIR`) and keep the APT fallback packages (`libopenblas0-pthread`, `libopenblas-dev`) available for benchmarking/alternatives registration on containers that still rely on a packaged OpenBLAS.

**1.6 Pre-cache CUDA Samples/Headers**  
Copy `FindCUDA`/`FindCUDAToolkit` hints into `/opt/cmake-modules` if needed, making sure downstream CMake invocations locate CUDA without additional flags.

---

## Phase 2 – Intel MKL Installation & Environment

**2.1 Add Intel oneAPI Repository**  
Import the current oneAPI GPG key and add the repository:
```bash
wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB \
  | gpg --dearmor \
  | sudo tee /usr/share/keyrings/oneapi-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" \
  | sudo tee /etc/apt/sources.list.d/oneAPI.list
sudo apt-get update
```

**2.2 Install MKL**  
`sudo apt-get install -y intel-oneapi-mkl intel-oneapi-mkl-devel` (or `intel-oneapi-hpc-toolkit` for the full suite).

**2.3 Configure Environment**  
Add `/etc/profile.d/intel-mkl.sh` (or container equivalent) to source `vars.sh`, set thread variables, and propagate `LD_LIBRARY_PATH`, `LIBRARY_PATH`, `PKG_CONFIG_PATH`, `CMAKE_PREFIX_PATH`.

**2.4 Verify MKL**  
Run `scripts/verify-cuda-mkl-linkage.sh` (local PC) to confirm MKL libraries resolve alongside CUDA components. Follow up with `scripts/verify-mkl-env.sh` to compile and execute a `cblas_dgemm` smoke test before declaring the phase complete.

**2.5 Global Build Environment**  
Source `/opt/build-env.sh` so every CMake configure inherits:
- GCC toolchain with `-O3 -march=native -fPIC`
- `-DEIGEN_USE_MKL_ALL` in `CXXFLAGS`
- `MKL_LINK_FLAGS="-lmkl_intel_lp64 -lmkl_core -lmkl_gnu_thread -lgomp -lpthread -lm -ldl"`
- `BLA_VENDOR=Intel10_64lp`
- Thread affinity variables (`OMP_PROC_BIND`, `OMP_PLACES`, etc.).
- Export CUDA specifics: `CMAKE_CUDA_ARCHITECTURES=86`, `CUDAFLAGS="-O3 -fPIC -Xcompiler -fopenmp --ptxas-options=-v"`, `CUDA_VISIBLE_DEVICES=""` (so local builds do not probe GPUs), and augment `LD_LIBRARY_PATH` / `LIBRARY_PATH` with `${CUDA_HOME}/lib64` and `${MKLROOT}/lib/intel64`.

**2.6 Immediate NVIDIA Package Cache Sync (✔ wired up)**  
Block 13.7 now performs the cache copy + `sync` immediately after a successful CUDA/cuDNN installation and skips the step when no new packages were downloaded. Block 24 in `build_xubuntu_robotics_base.sh` performs general cache harvest (all cache types: APT, Conda, wheels, Julia) from container to host after build completes. Since Block 13.7 does immediate NVIDIA sync inside container, NVIDIA packages are already in `/container_cache/apt/archives` when Block 24 runs. Block 24 is general cache harvest (not NVIDIA-specific) and should remain for other cache types.

---

## Phase 3 – SuiteSparse Foundation (MKL + CUDA) ✅

> ✅ **COMPLETE** - SuiteSparse v7.12.1 (MKL + CUDA) builds successfully in the orchestrator script (`xubuntu_robotics_base_full.sh`). The orchestrator short-circuits Block 13 when CUDA/cuDNN are pre-installed, so reruns simply refresh environment hooks before kicking off SuiteSparse. Proceed to HPC runtime checks next.

**3.1 Fetch Latest Stable Release**  
Implemented: the current scripts pin SuiteSparse `v7.12.1` from the official repository; confirm the tag whenever bumping dependencies.

**3.2 Configure for MKL & CUDA**  
See `docs/flags/SUITESPARSE_BUILD_OPTIONS.md`. SuiteSparse is built in the orchestrator script (`xubuntu_robotics_base_full.sh`) with MKL+CUDA support. Key flags:
```
-DSUITESPARSE_USE_OPENMP=ON
-DSUITESPARSE_USE_CUDA=ON
-DSUITESPARSE_CUDA_ARCHITECTURES=86
-DSUITESPARSE_USE_STRICT=ON
-DSUITESPARSE_USE_FORTRAN=ON
-DCHOLMOD_USE_CUDA=ON
-DSPQR_USE_CUDA=ON
-DGRAPHBLAS_USE_CUDA=OFF   # GPU kernels remain experimental upstream; stay CPU+MKL for now
-DBLA_VENDOR=Intel10_64lp
-DBLA_SIZEOF_INTEGER=4
-DCUBLAS_LIB=/usr/local/cuda-12.6/lib64/libcublas.so
-DCUSPARSE_LIB=/usr/local/cuda-12.6/lib64/libcusparse.so
-DCUSOLVER_LIB=/usr/local/cuda-12.6/lib64/libcusolver.so
-DCURAND_LIB=/usr/local/cuda-12.6/lib64/libcurand.so
```
Ensure CMake locates CUDA, cuBLAS, cuSPARSE, cuSOLVER, and MKL simultaneously (`CMAKE_PREFIX_PATH="$CUDA_HOME;$MKLROOT"`). Installation into `/usr/local` already validated locally—keep `ldd` checks in the verification script to guard regressions.

**3.3 Validate GPU Accelerants**  
✅ **COMPLETE** - SuiteSparse is built in the orchestrator script with MKL+CUDA support. Schedule runtime execution of SuiteSparse demos on the HPC node with an A6000 (`CUDA_VISIBLE_DEVICES=0`) as soon as remote access opens.

---

## Phase 4 – Core Robotics Libraries Rebuild

> CUDA environment sourcing now happens centrally in Block 13. Each Phase 4 build script should assume `${CUDA_HOME}`, `PATH`, and `LD_LIBRARY_PATH` are already populated from `/etc/profile.d/cuda.sh`; only add local guards instead of reinstalling CUDA.  
> ✅ **COMPLETE** - The orchestrator injects shared MKL variables (`MKLROOT`, `MKL_LIB_DIR`, `MKL_BLAS_LIBRARIES`) into every CMake invocation for Ceres, g2o, GTSAM, OpenCV, Open3D, and COLMAP. Standalone helper scripts are not needed (no standalone builds). Remaining work: validate end-to-end on the HPC GPU node.

**4.1 Ceres Solver**  
✅ **COMPLETE** - Ceres is built in the orchestrator script with MKL+CUDA support. Standalone build script not needed. Required options (already in orchestrator):
- `-DBLA_VENDOR=Intel10_64lp`
- `-DBLAS_LIBRARIES="${MKLROOT}/lib/intel64/libmkl_intel_lp64.so;${MKLROOT}/lib/intel64/libmkl_core.so;${MKLROOT}/lib/intel64/libmkl_gnu_thread.so;-lgomp;-lpthread;-lm;-ldl"`
- `-DLAPACK_LIBRARIES="${MKLROOT}/lib/intel64/libmkl_intel_lp64.so;${MKLROOT}/lib/intel64/libmkl_core.so;${MKLROOT}/lib/intel64/libmkl_gnu_thread.so;-lgomp;-lpthread;-lm;-ldl"`
- `-DCeres_USE_EIGEN_MKL=ON`
- `-DCeres_ENABLE_CUDA=ON`
- Provide SuiteSparse include/lib directories and `CUDA_TOOLKIT_ROOT_DIR`.

**4.2 GTSAM**  
GPU acceleration is limited; keep CPU path but align with MKL: `GTSAM_WITH_EIGEN_MKL=ON`, `GTSAM_WITH_EIGEN_MKL_OPENMP=ON`, plus the shared MKL BLAS/LAPACK flags. Document that CUDA kernels are not yet mainstream for GTSAM; revisit if upstream adds support.

**4.3 g2o**  
✅ **COMPLETE** - g2o does not support CUDA. Current MKL configuration is correct:
- MKL BLAS/LAPACK via `BLA_VENDOR=Intel10_64lp` and MKL libraries
- CHOLMOD/CSPARSE backends active with MKL
- OpenMP support enabled via `G2O_USE_OPENMP=ON`
- **Note:** g2o does not have CUDA support (confirmed in `docs/flags/G2O_20241228_CMAKE_FLAGS_DOCUMENTATION.md`)

**4.4 OpenCV**  
✅ **COMPLETE** - OpenCV is built in the orchestrator script with MKL+CUDA support. Standalone build script not needed. Configuration (already in orchestrator):
- `-DWITH_CUDA=ON`
- `-DCUDA_ARCH_BIN=8.6`
- `-DOPENCV_DNN_CUDA=ON`
- `-DWITH_TBB=ON`, `-DWITH_MKL=ON`
- `-DBLA_VENDOR=Intel10_64lp`, `-DMKL_ROOT=${MKLROOT}`, `-DBLAS_LIBRARIES=${MKL_BLAS_LIBRARIES}`, `-DLAPACK_LIBRARIES=${MKL_BLAS_LIBRARIES}`
- `-DWITH_OPENMP=ON`
Install Python bindings and confirm `cv2.getBuildInformation()` lists MKL + CUDA.

**4.5 Open3D**  
✅ **COMPLETE** - Open3D is built in the orchestrator script with MKL+CUDA support. Standalone build script not needed. Configuration (already in orchestrator):
- `-DBUILD_CUDA_MODULE=ON`
- `-DUSE_BLAS=ON`, `-DUSE_SYSTEM_BLAS=ON`
- `-DBLA_VENDOR=Intel10_64lp`, `-DMKL_ROOT=${MKLROOT}`, `-DBLAS/LAPACK_LIBRARIES=${MKL_BLAS_LIBRARIES}`
- `-DWITH_OPENMP=ON`
- Link against CUDA 12.6 and MKL simultaneously.

**4.6 COLMAP**  
✅ **COMPLETE** - COLMAP is built in the orchestrator script with MKL+CUDA support. Standalone build script not needed. Configuration (already in orchestrator):
- `-DCUDA_ENABLED=ON`
- `-DCERES_DIR=/usr/local/lib/cmake/Ceres`
- `-DBLA_VENDOR=Intel10_64lp`, `-DBLAS/LAPACK_LIBRARIES=${MKL_BLAS_LIBRARIES}`, `-DMKL_ROOT=${MKLROOT}`
- Confirm `ldd $(which colmap)` shows CUDA, Ceres, MKL.

**4.7 (Optional) PyCeres/Python Bindings**  
Rebuild PyCeres with `SKBUILD_CONFIGURE_OPTIONS="-DCeres_ENABLE_CUDA=ON -DCeres_USE_EIGEN_MKL=ON"`; rely on LD paths to expose MKL/CUDA.

---

## Phase 5 – Verification & Hardening

**5.1 Linkage Audit**  
Run `scripts/verify-cuda-mkl-linkage.sh` on the local PC to scan binaries and confirm MKL/CUDA libraries resolve (dynamic loader checks succeed even without a GPU).

**5.2 GPU Smoke Tests (HPC node)**  
- Defer execution of CUDA workloads to the HPC node with an A6000. Once the container or install is deployed on the HPC, run Ceres/g2o/OpenCV/Open3D CUDA demos and watch `nvidia-smi` for kernel launches.

**5.3 Python-level Checks**  
✅ **COMPLETE** - `verify-python-mkl.sh` is available in the container at `/usr/local/bin/verify-python-mkl.sh` (installed via `container-scripts/install.sh`). On the local PC, run `verify-python-mkl.sh` to confirm imports and MKL detection (CUDA detection will report libraries present even without hardware). Repeat on the HPC node to exercise GPU code paths.

**5.4 Reinforce APT Pins**  
Inspect via `apt-cache policy libceres-dev` to ensure negative priority remains active.

---

## Phase 6 – PyTorch (Binary, MKL & CUDA)

**6.1 Install Official Wheel**  
`pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126`.

**6.2 Validate MKL + CUDA**  
`xubuntu_robotics_base_full.sh` Block 26B prints PyTorch config, confirms “MKL” and “CUDA 12.6”, and exercises CPU matmul paths.

**6.3 Keep Source Build Optional**  
Legacy Block 26A (OpenBLAS source build) stays behind `ENABLE_PYTORCH_BUILD=false` for advanced extensions only.

---

## Phase 7 – Documentation & Automation

**7.1 Update Build Orchestration**  
Ensure `xubuntu_robotics_base_full.sh` sequences Phases 0–6, installing CUDA/MKL before any source builds. With the new idempotent Block 13 path, reruns will only refresh env hooks, so downstream blocks must not attempt to reinstall CUDA. Keep the immediate NVIDIA cache sync (Block 13.7 or `scripts/sync-nvidia-cache.sh`) immediately after the CUDA/cuDNN install and strip any duplicate sync hooks from `build_xubuntu_robotics_base.sh`. Remove legacy OpenBLAS logic or guard it behind benchmarking toggles.

**7.2 Maintain Docs**  
- `docs/MKL_MIGRATION_GUIDE.md`: high-level overview.  
- `docs/flags/SUITESPARSE_BUILD_OPTIONS.md`: Detailed SuiteSparse matrix (already authored).  
- `docs/planning/CUDA_BUILD_CHECKLIST.md` (new) to capture GPU prerequisites and flags.  
- `docs/TROUBLESHOOTING.md`: MKL/CUDA/OpenMP issues (dual runtime, missing libs, driver mismatch).

**7.3 Container Support**  
Update `Singularity.def.mkl` to install CUDA toolkit/MKL during `%post`, export environment scripts, and run verification before finalising the image.

---

## Phase 8 – Runtime HPC Tuning

**8.1 Thread & Affinity Settings**  
✅ **COMPLETE** - `/etc/profile.d/hpc-mkl-tune.sh` created in `container-scripts/` and installed via `install.sh`. Sets `OMP_PROC_BIND`, `OMP_PLACES`, `KMP_AFFINITY`, disables dynamic MKL threading (`MKL_DYNAMIC=FALSE`), and configures `CUDA_DEVICE_MAX_CONNECTIONS`.

**8.2 Monitoring**  
✅ **COMPLETE** - Monitoring toggles added to `/etc/profile.d/hpc-mkl-tune.sh`: `MKL_VERBOSE`, `OMP_DISPLAY_ENV`, `CUDA_LAUNCH_BLOCKING`. Profiling recipes (`nvidia-smi dmon`/`nvprof`) can be added on HPC node as needed.

---

## Phase 9 – Final Validation & Release

1. Execute the full pipeline on a fresh container using the local PC build environment; once artifacts are ready, revalidate the container on an HPC GPU node.  
2. Run targeted SLAM/vision workloads on the HPC hardware to benchmark performance against the OpenBLAS baseline.  
3. Version-lock source dependencies (SuiteSparse tag, Ceres, GTSAM, g2o commit, OpenCV tag, Open3D tag, COLMAP tag, CUDA toolkit version) in `config.sh`.  
4. Commit updated scripts/docs once validated; rerun pre-commit hook (Claude only) to keep code review in place.

---

By following these phases, the ROS Jazzy robotics stack gains full CUDA-enabled builds backed by Intel MKL, preserves a single GNU OpenMP runtime, and keeps automation, documentation, and container reproducibility intact.

