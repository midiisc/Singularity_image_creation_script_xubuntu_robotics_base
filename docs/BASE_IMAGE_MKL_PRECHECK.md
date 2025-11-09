# Base Image MKL Preflight Audit

## Image Under Test
- Repository: `osrf/ros`
- Tag: `jazzy-desktop-full-noble`
- Command: `docker run --rm osrf/ros:jazzy-desktop-full-noble bash`
- Audit date: 2025-11-09

## Preinstalled Math & Vision Stack
- **BLAS/LAPACK**
  - `libblas3` `3.12.0-3build1.1`
  - `libblas-dev` `3.12.0-3build1.1`
  - `liblapack3` `3.12.0-3build1.1`
  - `liblapack-dev` `3.12.0-3build1.1`
- **OpenMP runtime**
  - `libgomp1` `14.2.0-4ubuntu2~24.04` (GNU OpenMP from GCC)
  - No `libomp5` (LLVM) or `libiomp5` (Intel) present
- **OpenCV stack** (Ubuntu build 4.6.0+dfsg)
  - Full suite of `libopencv-*406t64` runtime libraries
  - Matching `libopencv-*-dev` development packages
  - `libopencv-dev`
  - `python3-opencv`
  - ROS wrapper `ros-jazzy-vision-opencv` 4.1.0-1noble.20250912.124238
- **Eigen / Boost / TBB**
  - `libeigen3-dev` `3.4.0-4build0.1`
  - Complete Boost 1.83 development stack (`libboost-all-dev`, modular packages)
  - Intel oneTBB 2021.11 packaged as `libtbb-dev`, `libtbb12`, `libtbbmalloc2`, `libtbbbind-2-5`
- **Point Cloud / FLANN / HDF5**
  - `libflann1.9`, `libflann-dev`
  - PCL 1.14 runtime and development packages (`libpcl-*`, `libpcl-dev`)
  - HDF5 serial and OpenMPI variants (`libhdf5-*`, `libhdf5-openmpi-*`, `hdf5-helpers`)
  - OpenMPI runtime/tooling (`openmpi-bin`, `libopenmpi3t64`, `libopenmpi-dev`)
- **ROS Glue Packages**
  - `ros-jazzy-eigen3-cmake-module`
  - `ros-jazzy-pcl-*` meta-packages and message bindings

## Detailed Package Inventory (Snapshot)

| Package | Version | Arch | Present? |
| --- | --- | --- | --- |
| `libblas3` | 3.12.0-3build1.1 | amd64 | ✅ |
| `libblas-dev` | 3.12.0-3build1.1 | amd64 | ✅ |
| `liblapack3` | 3.12.0-3build1.1 | amd64 | ✅ |
| `liblapack-dev` | 3.12.0-3build1.1 | amd64 | ✅ |
| `libgomp1` | 14.2.0-4ubuntu2~24.04 | amd64 | ✅ |
| `libomp5` | — | — | ❌ |
| `libiomp5` | — | — | ❌ |
| `libtbb-dev` | 2021.11.0-2ubuntu2 | amd64 | ✅ |
| `libtbb12` | 2021.11.0-2ubuntu2 | amd64 | ✅ |
| `libeigen3-dev` | 3.4.0-4build0.1 | all | ✅ |
| `libopencv-dev` | 4.6.0+dfsg-13.1ubuntu1 | amd64 | ✅ |
| `python3-opencv` | 4.6.0+dfsg-13.1ubuntu1 | amd64 | ✅ |
| `libopencv-core406t64` | 4.6.0+dfsg-13.1ubuntu1 | amd64 | ✅ |
| `libopencv-imgproc406t64` | 4.6.0+dfsg-13.1ubuntu1 | amd64 | ✅ |
| `libopencv-dnn406t64` | 4.6.0+dfsg-13.1ubuntu1 | amd64 | ✅ |
| `libceres-dev` | — | — | ❌ |
| `libceres2` | — | — | ❌ |
| `libgtsam-dev` | — | — | ❌ |
| `libgtsam4` | — | — | ❌ |
| `libg2o-dev` | — | — | ❌ |
| `libg2o-core0` | — | — | ❌ |
| `libg2o-core-dev` | — | — | ❌ |
| `open3d` | — | — | ❌ |
| `colmap` | — | — | ❌ |
| `libpcl-dev` | 1.14.0+dfsg-1 | amd64 | ✅ |
| `libflann-dev` | 1.9.2+dfsg-2build1 | amd64 | ✅ |
| `libhdf5-dev` | 1.10.10+repack-3.1ubuntu4 | amd64 | ✅ |
| `libhdf5-103-1t64` | 1.10.10+repack-3.1ubuntu4 | amd64 | ✅ |
| `libhdf5-openmpi-103-1t64` | 1.10.10+repack-3.1ubuntu4 | amd64 | ✅ |
| `libsuitesparse-dev` | — | — | ❌ |
| `libcholmod3` | — | — | ❌ |
| `libmetis5` | — | — | ❌ |
| `libcxsparse3` | — | — | ❌ |
| `ros-jazzy-vision-opencv` | 4.1.0-1noble.20250912.124238 | amd64 | ✅ |

Legend: ✅ = present in base image; ❌ = not installed

## Components Confirmed Absent
- Intel MKL (`intel-oneapi-mkl`, `libmkl*`)
- OpenBLAS (`libopenblas*`)
- Ceres Solver (`libceres*`)
- GTSAM (`libgtsam*`)
- Open3D (`open3d*`)
- COLMAP (`colmap`)
- PyTorch / LibTorch (`torch`, `libtorch`)
- LLVM OpenMP runtime (`libomp5`)

## Implications & Recommended Handling
- **OpenCV:** Ship with Ubuntu 4.6 packages; custom MKL build must install to `/usr/local` and optionally purge or pin the system packages to avoid accidental linkage. ROS packages depend on them, so evaluate removal carefully before purging.
- **BLAS/LAPACK:** System reference BLAS/LAPACK remain; downstream builds must point explicitly to MKL to prevent fallback to these libraries.
- **OpenMP:** GNU `libgomp1` is available; keep `MKL_THREADING_LAYER=GNU` to stay compatible. No conflicts with Intel `libiomp5` expected once MKL is installed.
- **Boost/Eigen/PCL/HDF5:** Present in Ubuntu versions. Decide case-by-case whether to replace with source builds; if keeping system versions, add APT pinning to prevent removal when compiling dependent libraries.
- **Absent Components:** Fresh MKL-centric builds can proceed without uninstalling prior versions, aside from OpenCV.

## Suggested Mitigations Before Custom Builds
- Document optional purge commands for the OpenCV 4.6 packages if we need a clean replacement (`apt-get purge 'libopencv-*' python3-opencv ros-jazzy-vision-opencv`).
- Add APT pin files for packages we rebuild (Ceres, GTSAM, OpenCV, Open3D, COLMAP) so the system doesn’t reinstall Ubuntu versions later in the script.
- Ensure `LD_LIBRARY_PATH` and `CMAKE_PREFIX_PATH` are set so compiled libraries in `/usr/local` shadow the distribution packages.

## Data Collection Commands
```
dpkg -l | egrep 'intel-oneapi-mkl|libmkl|libopenblas|libblas|liblapack|libgomp|libomp|opencv|ceres|gtsam|open3d|colmap|torch'
dpkg -l | egrep 'eigen|tbb|suite|cholmod|metis|flann|pcl|openmpi|hdf5|boost'
apt-mark showmanual
```
