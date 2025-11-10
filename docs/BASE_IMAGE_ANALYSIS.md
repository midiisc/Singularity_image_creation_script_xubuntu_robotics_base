# Base Image Analysis – ROS Jazzy MKL Migration

## Image Details
- **Base image:** `osrf/ros:jazzy-desktop-full-noble`
- **Host OS:** Ubuntu 24.04 (glibc 2.39)
- **Audit date:** 2025-11-09
- **Audit tools:** `ldconfig`, `dpkg`, `Eigen` smoke test (baseline audit script not needed - migration is complete)

## Executive Summary
| Component | Status | Notes |
|-----------|--------|-------|
| **Intel MKL** | ❌ Not installed | No `intel-oneapi-*` packages present; safe to install via oneAPI repo |
| **BLAS/LAPACK** | ✅ Netlib reference (`libblas3`, `liblapack3`) | Managed by Ubuntu alternatives; OpenBLAS not installed by default |
| **OpenBLAS** | ⚪ Not installed | Only reference BLAS/LAPACK present; OpenBLAS can be added if needed |
| **OpenCV** | ✅ Ubuntu 4.6 packages | ROS depends on distro packages; our custom MKL build will shadow them |
| **SuiteSparse** | ⚪ Not installed | No `libcholmod*`/`libspqr*`; we will build SuiteSparse v7.12.1 with MKL |
| **Ceres / GTSAM / g2o / Open3D / COLMAP** | ⚪ Not installed | Will be built from source against MKL once SuiteSparse is ready |
| **OpenMP runtime** | ✅ GNU `libgomp1` | Compatible with MKL using `MKL_THREADING_LAYER=GNU` |

## Package Inventory Highlights
Excerpt from `dpkg -l`:
- `libblas3`, `liblapack3`, `liblapacke` (reference implementations)
- **No** `libopenblas*` packages in the base image
- Full Ubuntu OpenCV 4.6 suite (`libopencv-*`, `python3-opencv`, `ros-jazzy-vision-opencv`)
- No MKL, SuiteSparse, Ceres, GTSAM, g2o, Open3D, or COLMAP packages present (all to be introduced via source builds)

## Library Search Paths (`ldconfig`)
- `/lib/x86_64-linux-gnu` contains reference BLAS/LAPACK and OpenCV 4.6.
- `/usr/local/lib` already holds a custom OpenCV build (likely from a previous iteration); our MKL build will reuse this precedence.
- CUDA 12.x libraries are registered under `/usr/local/cuda-*`.
- No MKL libraries present yet.

## pkg-config Snapshot
- `openblas` / `openblas-blas` / `openblas-lapack` entries exist.
- No `mkl` pkg-config files yet (expected until oneAPI packages are installed).

## Eigen Compilation Smoke Test
Eigen compilation smoke test verifies Eigen headers via:
```bash
g++ -O3 -march=native -I/usr/include/eigen3 test_eigen.cpp
```
The test binary executes successfully (`Eigen OK: …`), confirming the toolchain is functional prior to MKL installation.

## Observations & Recommendations
1. **Keep system OpenCV installed.** ROS packages rely on Ubuntu 4.6; our MKL-enabled build in `/usr/local` can safely shadow it via library ordering and environment variables.
2. **Bring in SuiteSparse/Ceres/GTSAM/g2o/Open3D/COLMAP via source builds.** None are present in the base image, so we will install the latest versions with MKL support.
3. **APT pinning required post-install.** Once custom builds are in place, deploy `/etc/apt/preferences.d/robotics-stack-pin` to block the Ubuntu packages from reinstalling on upgrade.
4. **MKL installation path is clear.** Install via Intel’s oneAPI APT repository (`intel-oneapi-mkl`, `intel-oneapi-mkl-devel`) and source `/opt/intel/oneapi/mkl/latest/env/vars.sh`.
5. **OpenBLAS optional.** The base image lacks OpenBLAS; if a fallback is desired, it can be installed, but the primary plan is to rely solely on MKL.
6. **Documentation updates.** Refer to `docs/planning/MKL_MIGRATION_PLAN.md` for phased migration steps; this document stores the consolidated base-image audit.

## Audit Script Usage
Baseline audit can be performed manually using:
- `dpkg -l` for package inventory
- `ldconfig -p` for library search paths
- `pkg-config --list-all` for pkg-config entries
- Eigen compilation smoke test for toolchain verification

Outputs:
- Package list (BLAS/LAPACK/MKL/OpenCV + key robotics libs)
- `ldconfig` entries for math/vision libraries
- Eigen compilation smoke test
- Custom prefix entries (`/usr/local`, `/opt`)

## Next Steps
1. Complete Phase 0 tasks: install pin file, keep baseline log, and proceed to MKL installation.
2. Follow the phased plan in `docs/planning/MKL_MIGRATION_PLAN.md` to install MKL, rebuild SuiteSparse and robotics libraries, and verify linkage.
3. Maintain this document as a snapshot reference until the migration is finalized; update or remove once the new MKL baseline is established.

