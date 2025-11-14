# OpenCV 4.12.0 - Comprehensive CMake Flags Documentation

**Version:** 4.12.0  
**Source Repository:** https://github.com/opencv/opencv  
**Contrib Repository:** https://github.com/opencv/opencv_contrib  
**Commit:** `49486f61fb25722cbcf586b7f4320921d46fb38e`  
**Last Audited:** November 14, 2025 (Deep Analysis - TBB, LAPACK, MKL, Threading)  
**Documentation Generated:** From source code analysis  
**CMake Minimum Version:** 3.5

> **2025 Audit Highlights**
> - Library-Analysis-Tool scanned 118 `CMakeLists.txt`, 1,735 headers, and 16 helper scripts in the 4.12.0 tag.  
> - No new top-level `option()` entries were introduced; feature gates such as `OPENCV_ENABLE_NONFREE`, `WITH_CUDA`, `WITH_OPENCL`, `BUILD_opencv_*`, and `OPENCV_DNN_OPENVINO` retain their documented defaults.  
> - Dependency scan continues to report the same optional integrations (Intel TBB, CUDA, cuDNN, OpenVINO, FFmpeg, GStreamer, Vulkan, etc.) with no additional mandatory packages.
> - **TBB Verification:** System TBB 2021.11.0 (TBB_INTERFACE_VERSION >= 12000) verified on Ubuntu 24.04. OpenCV automatically sets `__TBB_NO_IMPLICIT_LINKAGE=1` for oneTBB 2021+. CMake config files located at `/usr/lib/x86_64-linux-gnu/cmake/TBB`.
> - **LAPACK/MKL Verification:** OpenCV prioritizes MKL over OpenBLAS via `cmake/OpenCVFindMKL.cmake`. Requires `mkl_cblas.h` and `mkl_lapack.h` headers. Uses `mkl_gnu_thread` for GCC toolchain compatibility.

---

## Table of Contents

1. [Core Build Options](#core-build-options)
2. [Module Options](#module-options)
3. [Dependency Options](#dependency-options)
4. [CUDA Options](#cuda-options)
5. [Python Options](#python-options)
6. [Testing and Examples](#testing-and-examples)
7. [Performance Options](#performance-options)
8. [Standard CMake Variables](#standard-cmake-variables)
9. [Module-Specific BUILD_opencv_* Options](#module-specific-build_opencv_-options)
10. [Usage Examples](#usage-examples)

---

## Core Build Options

### `BUILD_SHARED_LIBS`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Build shared libraries (`.so`) instead of static (`.a`).
- **Usage:**
  ```cmake
  -DBUILD_SHARED_LIBS=ON
  ```

### `CMAKE_BUILD_TYPE`
- **Type:** `STRING` (Cache variable)
- **Default:** `Release`
- **Options:** `Debug`, `Release`, `RelWithDebInfo`, `MinSizeRel`
- **Description:** Specifies the build configuration.
- **Usage:**
  ```cmake
  -DCMAKE_BUILD_TYPE=Release
  ```

### `ENABLE_PIC`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `TRUE`
- **Description:** Generate position independent code (necessary for shared libraries).
- **Usage:**
  ```cmake
  -DENABLE_PIC=ON
  ```

### `BUILD_LIST`
- **Type:** `CACHE STRING`
- **Default:** `""` (empty, builds all modules)
- **Description:** Build only listed modules (comma-separated, e.g., 'videoio,dnn,ts').
- **Usage:**
  ```cmake
  -DBUILD_LIST="videoio,dnn,imgproc"
  ```
- **Note:** Useful for minimal builds.

### `OPENCV_EXTRA_MODULES_PATH`
- **Type:** `CACHE PATH`
- **Default:** `""` (empty)
- **Description:** Where to look for additional OpenCV modules (can be `;`-separated list of paths).
- **Usage:**
  ```cmake
  -DOPENCV_EXTRA_MODULES_PATH=/path/to/opencv_contrib/modules
  ```
- **Note:** Required for building opencv_contrib modules.

---

## Module Options

### `BUILD_opencv_<MODULE_NAME>`
- **Type:** `OPTION` (ON/OFF)
- **Default:** Varies by module (most are ON)
- **Description:** Enable/Disable building a specific OpenCV module.
- **Usage:**
  ```cmake
  -DBUILD_opencv_core=ON
  -DBUILD_opencv_imgproc=ON
  -DBUILD_opencv_dnn=ON
  ```
- **Note:** OpenCV has 100+ modules. See [Module-Specific BUILD_opencv_* Options](#module-specific-build_opencv_-options) section.

**Common Core Modules:**
- `BUILD_opencv_core` - Core functionality (always ON if building)
- `BUILD_opencv_imgproc` - Image processing
- `BUILD_opencv_imgcodecs` - Image codecs
- `BUILD_opencv_videoio` - Video I/O
- `BUILD_opencv_highgui` - High-level GUI
- `BUILD_opencv_features2d` - Feature detection
- `BUILD_opencv_calib3d` - Camera calibration
- `BUILD_opencv_objdetect` - Object detection
- `BUILD_opencv_dnn` - Deep Neural Networks module
- `BUILD_opencv_ml` - Machine Learning
- `BUILD_opencv_flann` - Fast Library for Approximate Nearest Neighbors

**Common Contrib Modules** (require `OPENCV_EXTRA_MODULES_PATH`):
- `BUILD_opencv_sfm` - Structure from Motion
- `BUILD_opencv_xfeatures2d` - Extended 2D features
- `BUILD_opencv_ximgproc` - Extended image processing
- `BUILD_opencv_aruco` - ArUco markers
- `BUILD_opencv_bgsegm` - Background segmentation

---

## Dependency Options

### `WITH_CUDA`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF` (auto-enabled if CUDA found)
- **Description:** Enable CUDA support.
- **Usage:**
  ```cmake
  -DWITH_CUDA=ON
  ```

### `WITH_CUDNN`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON` (if CUDNN found)
- **Description:** Enable cuDNN support for DNN module.
- **Usage:**
  ```cmake
  -DWITH_CUDNN=ON
  ```
- **Note:** Requires `WITH_CUDA=ON`.

### `WITH_OPENBLAS`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Use OpenBLAS for BLAS operations (NOT RECOMMENDED - use MKL instead).
- **Usage:**
  ```cmake
  -DWITH_OPENBLAS=ON
  ```
- **CRITICAL NOTE:** OpenCV should use Intel MKL (not OpenBLAS) for optimal performance and compatibility with other HPC libraries (GTSAM, Ceres, etc.). Use `WITH_MKL=ON` instead of `WITH_OPENBLAS=ON`.

### `WITH_TBB`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Use Intel Threading Building Blocks (TBB) for parallelization. TBB provides task-based parallelism for OpenCV operations.
- **Usage:**
  ```cmake
  -DWITH_TBB=ON
  ```
- **TBB Detection Process (from `cmake/OpenCVDetectTBB.cmake`):**
  1. **CMake Package Search:** OpenCV first tries `find_package(TBB QUIET COMPONENTS tbb)` searching in:
     - `$ENV{TBBROOT}/cmake`
     - `$ENV{TBBROOT}/lib/cmake/tbb`
  2. **Environment Variable Search:** If CMake package not found, searches via:
     - `TBBROOT` environment variable
     - `CPATH` for headers (`tbb/tbb.h`)
     - `LIBRARY_PATH` for libraries (`libtbb.so`)
  3. **Version Detection:** Reads TBB version from:
     - `oneapi/tbb/version.h` (oneTBB 2021+, preferred)
     - `tbb/tbb_stddef.h` (legacy TBB, fallback)
  4. **Version Requirements:** Requires `TBB_INTERFACE_VERSION >= 6000` (TBB 4.0+)
  5. **oneTBB 2021+ Handling:** For `TBB_INTERFACE_VERSION >= 12000`, automatically sets `__TBB_NO_IMPLICIT_LINKAGE=1` to avoid defaultlib issues

- **Recommended CMake Variables (for reliable detection):**
  - `TBB_DIR`: Path to TBB CMake config directory (e.g., `/usr/lib/x86_64-linux-gnu/cmake/TBB`)
    - **CRITICAL:** Modern Ubuntu TBB packages (libtbb-dev) provide CMake config files at this location
    - OpenCV's `find_package(TBB)` will use this if available
  - `TBB_ROOT_DIR`: Root directory of TBB installation (e.g., `/usr`)
    - Used as fallback if `TBB_DIR` is not found
  - `TBB_INCLUDE_DIR` or `TBB_INCLUDE_DIRS`: Path to TBB header directory (e.g., `/usr/include/tbb`)
    - **Required Headers:** Must contain `tbb/tbb.h` (or `oneapi/tbb/version.h` for oneTBB)
  - `TBB_LIBRARIES`: Full path to TBB library file (e.g., `/usr/lib/x86_64-linux-gnu/libtbb.so`)
    - **Explicit override:** Ensures correct library is linked even if `TBB_DIR` is ignored

- **System TBB vs MKL TBB:**
  - **CRITICAL:** OpenCV must use **system TBB** (from `libtbb-dev`), NOT MKL's optional TBB build
  - System TBB: `/usr/lib/x86_64-linux-gnu/libtbb.so` (correct)
  - MKL TBB: `/opt/intel/oneapi/tbb/lib/libtbb.so` (incorrect, causes conflicts)
  - Use `CMAKE_IGNORE_PATH` to exclude MKL TBB: `-DCMAKE_IGNORE_PATH=/opt/intel/oneapi/tbb`

- **TBB Header Structure (Ubuntu 24.04 - Verified):**
  - Legacy headers: `/usr/include/tbb/tbb.h` (wrapper that includes `../oneapi/tbb.h`)
  - oneTBB headers: `/usr/include/oneapi/tbb/version.h`, `/usr/include/oneapi/tbb.h`
  - **Verified Version:** TBB 2021.11.0 (TBB_VERSION_MAJOR=2021, TBB_VERSION_MINOR=11, TBB_VERSION_PATCH=0)
  - **TBB_INTERFACE_VERSION:** >= 12000 (oneTBB 2021+), automatically triggers `__TBB_NO_IMPLICIT_LINKAGE=1`
  - **CMake Config Location:** `/usr/lib/x86_64-linux-gnu/cmake/TBB` (TBBConfig.cmake, TBBTargets.cmake)
  - **Library Location:** `/usr/lib/x86_64-linux-gnu/libtbb.so.12` (system TBB, NOT MKL TBB)
  - **pkg-config:** `pkg-config --modversion tbb` returns `2021.11.0`
  - OpenCV detects both structures automatically

- **Critical:** If TBB is not detected, ensure:
  1. `CMAKE_PREFIX_PATH` includes the TBB installation directory (e.g., `/usr`)
  2. All TBB variables (`TBB_DIR`, `TBB_INCLUDE_DIR`, `TBB_LIBRARIES`) are explicitly set:
     - `TBB_DIR=/usr/lib/x86_64-linux-gnu/cmake/TBB` (Ubuntu 24.04 verified path)
     - `TBB_INCLUDE_DIR=/usr/include/tbb` or `/usr/include` (if using oneapi/tbb)
     - `TBB_LIBRARIES=/usr/lib/x86_64-linux-gnu/libtbb.so` (system TBB, NOT MKL TBB)
  3. MKL TBB paths are excluded via `CMAKE_IGNORE_PATH=/opt/intel/oneapi/tbb`
  4. **Verify TBB version:** `pkg-config --modversion tbb` should return `2021.11.0` or later
  5. **Verify CMake config:** Check that `/usr/lib/x86_64-linux-gnu/cmake/TBB/TBBConfig.cmake` exists

### `WITH_EIGEN`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Use Eigen3 library.
- **Usage:**
  ```cmake
  -DWITH_EIGEN=ON
  ```

### `WITH_FFMPEG`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON` (if FFmpeg found)
- **Description:** Enable FFmpeg support for video codecs.
- **Usage:**
  ```cmake
  -DWITH_FFMPEG=ON
  ```

### `WITH_GSTREAMER`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Enable GStreamer support.
- **Usage:**
  ```cmake
  -DWITH_GSTREAMER=ON
  ```

### `WITH_LAPACK`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF` (unless `CV_DISABLE_OPTIMIZATION` is set)
- **Description:** Enable LAPACK support for linear algebra operations (SVD, QR decomposition, Cholesky, eigenvalue problems, etc.).

- **CRITICAL: OpenCV MUST use Intel MKL (not OpenBLAS)**
  - OpenCV is configured to link with Intel MKL for optimal performance
  - OpenBLAS is built as a fallback but is **NOT used by OpenCV**
  - MKL provides better performance and compatibility with other HPC libraries (GTSAM, Ceres, etc.)

- **LAPACK Detection Process (from `cmake/OpenCVFindLAPACK.cmake`):**
  1. **MKL Detection (First Priority):** If `OPENCV_LAPACK_DISABLE_MKL` is not set:
     - Searches for MKL via `cmake/OpenCVFindMKL.cmake`
     - Requires headers: `mkl_cblas.h` and `mkl_lapack.h` in `${MKLROOT}/include`
     - Validates with test compile (`cmake/checks/lapack_check.cpp`)
     - Creates proxy header `opencv_lapack.h` that includes MKL headers
  2. **OpenBLAS Detection (Fallback):** If MKL not found:
     - Searches via `cmake/OpenCVFindOpenBLAS.cmake`
     - Requires headers: `cblas.h` and `lapacke.h`
  3. **ATLAS Detection (Linux Fallback):** If OpenBLAS not found:
     - Searches via `cmake/OpenCVFindAtlas.cmake`
  4. **Generic LAPACK Detection:** If none found:
     - Uses CMake's `find_package(LAPACK)`
     - Searches for `lapacke.h` and `cblas.h` in standard locations

- **Required Headers (MKL):**
  - **CBLAS Header:** `${MKLROOT}/include/mkl_cblas.h`
  - **LAPACKE Header:** `${MKLROOT}/include/mkl_lapack.h`
  - Both headers must exist and be accessible

- **MKL Threading Model (CRITICAL):**
  - **Recommended:** `MKL_THREADING_LAYER=GNU` (GNU OpenMP)
  - **Why GNU OpenMP?**
    - Compatible with GCC toolchain (uses `libgomp`, not Intel OpenMP)
    - Avoids conflicts between Intel OpenMP (`libiomp5`) and GNU OpenMP (`libgomp`)
    - Better performance on Linux systems with GCC
    - Matches threading model used by other HPC libraries (GTSAM, Ceres)
  - **CMake Variable:** `-DMKL_THREADING_LAYER=GNU`
  - **OpenCV MKL Configuration:** When `MKL_WITH_OPENMP=ON` and not MSVC:
    - OpenCV's `OpenCVFindMKL.cmake` automatically links `mkl_gnu_thread`
    - This uses GNU OpenMP runtime (`libgomp.so.1`)
  - **Alternative Threading Models (NOT RECOMMENDED):**
    - `MKL_THREADING_LAYER=INTEL`: Requires Intel OpenMP (`libiomp5`), conflicts with GNU OpenMP
    - `MKL_THREADING_LAYER=TBB`: Requires TBB threading, less common for MKL
    - `MKL_THREADING_LAYER=SEQUENTIAL`: Single-threaded, poor performance

- **Usage:**
  ```cmake
  -DWITH_LAPACK=ON
  -DWITH_MKL=ON
  -DMKL_WITH_OPENMP=ON
  -DMKL_THREADING_LAYER=GNU
  ```

- **Required CMake Variables (MKL):**
  - `LAPACK_LIBRARIES`: Semicolon-separated list of MKL library files
    - Example: `"${MKLROOT}/lib/intel64/libmkl_intel_lp64.so;${MKLROOT}/lib/intel64/libmkl_core.so;${MKLROOT}/lib/intel64/libmkl_gnu_thread.so"`
  - `LAPACK_INCLUDE_DIR` or `LAPACK_INCLUDE_DIRS`: Path to MKL headers
    - Example: `"${MKLROOT}/include"`
  - `BLA_VENDOR`: BLAS/LAPACK vendor identifier
    - For MKL: `Intel10_64lp` (LP64 interface, 32-bit integers, 64-bit pointers)
    - Alternative: `Intel10_64lp_seq` (sequential, no threading)
  - `BLAS_LIBRARIES`: BLAS library files (often same as LAPACK for MKL)
    - Example: Same as `LAPACK_LIBRARIES` when using MKL
  - `MKL_ROOT`: Root directory of MKL installation
    - Example: `"${MKLROOT}"` (from environment variable)

- **Complete MKL Configuration Example:**
  ```cmake
  -DWITH_LAPACK=ON
  -DWITH_MKL=ON
  -DMKL_WITH_OPENMP=ON
  -DMKL_THREADING_LAYER=GNU
  -DMKL_USE_STATIC_LIBS=OFF
  -DBLA_VENDOR=Intel10_64lp
  -DBLAS_LIBRARIES="${MKLROOT}/lib/intel64/libmkl_intel_lp64.so;${MKLROOT}/lib/intel64/libmkl_core.so;${MKLROOT}/lib/intel64/libmkl_gnu_thread.so"
  -DLAPACK_LIBRARIES="${MKLROOT}/lib/intel64/libmkl_intel_lp64.so;${MKLROOT}/lib/intel64/libmkl_core.so;${MKLROOT}/lib/intel64/libmkl_gnu_thread.so"
  -DLAPACK_INCLUDE_DIR="${MKLROOT}/include"
  -DLAPACK_INCLUDE_DIRS="${MKLROOT}/include"
  -DMKL_ROOT="${MKLROOT}"
  -DCMAKE_PREFIX_PATH="${MKLROOT}"
  ```

- **Critical:** If LAPACK is not detected, ensure:
  1. `CMAKE_PREFIX_PATH` includes `${MKLROOT}`
  2. Both `LAPACK_LIBRARIES` and `LAPACK_INCLUDE_DIR` are explicitly set
  3. `BLA_VENDOR=Intel10_64lp` matches your MKL installation
  4. `MKL_THREADING_LAYER=GNU` is set for GCC toolchain compatibility
  5. MKL headers (`mkl_cblas.h`, `mkl_lapack.h`) exist in `${MKLROOT}/include`
  6. MKL libraries exist and are accessible

- **Verification:**
  - After CMake configure, check `CMakeCache.txt`:
    - `LAPACK_FOUND:BOOL=ON` or `HAVE_LAPACK:BOOL=1`
    - `LAPACK_IMPL:STRING=MKL`
    - `LAPACK_LIBRARIES` should point to MKL libraries (not OpenBLAS)

### `WITH_OPENGL`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Enable OpenGL support.
- **Usage:**
  ```cmake
  -DWITH_OPENGL=ON
  ```

### `WITH_OPENMP`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Enable OpenMP support.
- **Usage:**
  ```cmake
  -DWITH_OPENMP=ON
  ```

### `WITH_IPP`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Enable Intel Integrated Performance Primitives.
- **Usage:**
  ```cmake
  -DWITH_IPP=ON
  ```

### `WITH_VTK`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Enable VTK support.
- **Usage:**
  ```cmake
  -DWITH_VTK=ON
  ```

### `WITH_QUIRC`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Enable QR code detection via quirc library.
- **Usage:**
  ```cmake
  -DWITH_QUIRC=ON
  ```

---

## CUDA Options

### `CUDA_ARCH_BIN`
- **Type:** `CACHE STRING`
- **Default:** Auto-detected or `"6.1"`
- **Description:** CUDA compute capabilities (e.g., `"8.6;8.9;9.0"`).
- **Usage:**
  ```cmake
  -DCUDA_ARCH_BIN="86;89;90"
  ```
- **Note:** Separate multiple architectures with semicolon.

### `CUDA_ARCH_PTX`
- **Type:** `CACHE STRING`
- **Default:** Same as `CUDA_ARCH_BIN`
- **Description:** CUDA PTX architectures for JIT compilation.
- **Usage:**
  ```cmake
  -DCUDA_ARCH_PTX="86"
  ```

### `CUDA_TOOLKIT_ROOT_DIR`
- **Type:** `CACHE PATH`
- **Default:** Auto-detected
- **Description:** Root directory of CUDA toolkit.
- **Usage:**
  ```cmake
  -DCUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda-12.6
  ```

### `CUDA_HOST_COMPILER`
- **Type:** `CACHE FILEPATH`
- **Default:** System default C++ compiler
- **Description:** Host compiler for CUDA (must be compatible).
- **Usage:**
  ```cmake
  -DCUDA_HOST_COMPILER=/usr/bin/g++-12
  ```

### `OPENCV_DNN_CUDA`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON` (if CUDA found)
- **Description:** Enable CUDA backend for DNN module.
- **Usage:**
  ```cmake
  -DOPENCV_DNN_CUDA=ON
  ```
- **Note:** Requires `WITH_CUDA=ON` and `WITH_CUDNN=ON`.

### `OPENCV_DNN_CUDA_VERSION`
- **Type:** `CACHE STRING`
- **Description:** CUDA version for DNN (e.g., `"12.6"`).
- **Usage:**
  ```cmake
  -DOPENCV_DNN_CUDA_VERSION=12.6
  ```

### `CMAKE_CUDA_ARCHITECTURES`
- **Type:** `CACHE STRING`
- **Description:** CMake standard variable for CUDA architectures.
- **Usage:**
  ```cmake
  -DCMAKE_CUDA_ARCHITECTURES="86;89;90"
  ```

### `ENABLE_FAST_MATH`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Enable fast math optimizations (may affect precision).
- **Usage:**
  ```cmake
  -DENABLE_FAST_MATH=ON
  ```

### `CUDA_FAST_MATH`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Enable CUDA fast math (use `--use_fast_math`).
- **Usage:**
  ```cmake
  -DCUDA_FAST_MATH=ON
  ```

### `WITH_CUBLAS`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON` (if CUDA found)
- **Description:** Enable cuBLAS support.
- **Usage:**
  ```cmake
  -DWITH_CUBLAS=ON
  ```

### `WITH_CUFFT`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON` (if CUDA found)
- **Description:** Enable cuFFT support.
- **Usage:**
  ```cmake
  -DWITH_CUFFT=ON
  ```

---

## Python Options

### `BUILD_opencv_python3`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON` (if Python3 found)
- **Description:** Build Python 3 bindings.
- **Usage:**
  ```cmake
  -DBUILD_opencv_python3=ON
  ```

### `PYTHON3_EXECUTABLE`
- **Type:** `CACHE FILEPATH`
- **Default:** Auto-detected
- **Description:** Python 3 executable path.
- **Usage:**
  ```cmake
  -DPYTHON3_EXECUTABLE=/usr/bin/python3
  ```

### `PYTHON3_INCLUDE_DIR`
- **Type:** `CACHE PATH`
- **Default:** Auto-detected
- **Description:** Python 3 include directory.
- **Usage:**
  ```cmake
  -DPYTHON3_INCLUDE_DIR=/usr/include/python3.12
  ```

### `PYTHON3_LIBRARY`
- **Type:** `CACHE FILEPATH`
- **Default:** Auto-detected
- **Description:** Python 3 library file.
- **Usage:**
  ```cmake
  -DPYTHON3_LIBRARY=/usr/lib/x86_64-linux-gnu/libpython3.12.so
  ```

### `PYTHON3_NUMPY_INCLUDE_DIRS`
- **Type:** `CACHE PATH`
- **Default:** Auto-detected
- **Description:** NumPy include directories.
- **Usage:**
  ```cmake
  -DPYTHON3_NUMPY_INCLUDE_DIRS=/usr/lib/python3/dist-packages/numpy/core/include
  ```

### `PYTHON3_PACKAGES_PATH`
- **Type:** `CACHE PATH`
- **Default:** Auto-detected
- **Description:** Python 3 packages installation path.
- **Usage:**
  ```cmake
  -DPYTHON3_PACKAGES_PATH=/usr/lib/python3/dist-packages
  ```

### `PYPI_PACKAGE_NAME`
- **Type:** `CACHE STRING`
- **Default:** `opencv-python` or `opencv-contrib-python`
- **Description:** Package name for PyPI installation.
- **Usage:**
  ```cmake
  -DPYPI_PACKAGE_NAME=open3d
  ```

---

## Testing and Examples

### `BUILD_TESTS`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Build unit tests.
- **Usage:**
  ```cmake
  -DBUILD_TESTS=OFF
  ```

### `BUILD_PERF_TESTS`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Build performance tests.
- **Usage:**
  ```cmake
  -DBUILD_PERF_TESTS=OFF
  ```

### `BUILD_EXAMPLES`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Build example applications.
- **Usage:**
  ```cmake
  -DBUILD_EXAMPLES=OFF
  ```

### `BUILD_DOCS`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Build documentation.
- **Usage:**
  ```cmake
  -DBUILD_DOCS=OFF
  ```

### `BUILD_opencv_apps`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Build OpenCV applications.
- **Usage:**
  ```cmake
  -DBUILD_opencv_apps=OFF
  ```

---

## Performance Options

### `CPU_BASELINE`
- **Type:** `CACHE STRING`
- **Default:** `"SSE3"`
- **Description:** Minimum CPU features required (e.g., `"SSE3"`, `"AVX2"`).
- **Usage:**
  ```cmake
  -DCPU_BASELINE=AVX2
  ```

### `CPU_DISPATCH`
- **Type:** `CACHE STRING`
- **Default:** `""`
- **Description:** Optimized CPU features to enable (e.g., `"AVX2,FP16,AVX512_SKX"`).
- **Usage:**
  ```cmake
  -DCPU_DISPATCH="AVX2,FP16,AVX512_SKX"
  ```

### `OPENCV_ENABLE_NONFREE`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Enable non-free algorithms (SIFT, SURF, etc.).
- **Usage:**
  ```cmake
  -DOPENCV_ENABLE_NONFREE=ON
  ```
- **Note:** License restrictions apply.

### `OPENCV_GENERATE_PKGCONFIG`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Generate pkg-config file.
- **Usage:**
  ```cmake
  -DOPENCV_GENERATE_PKGCONFIG=ON
  ```

---

## Standard CMake Variables

OpenCV respects standard CMake variables:

### Build System
- `CMAKE_GENERATOR`: Build system generator
- `CMAKE_BUILD_TYPE`: Build configuration
- `CMAKE_INSTALL_PREFIX`: Installation directory

### Compilers
- `CMAKE_C_COMPILER`: C compiler
- `CMAKE_CXX_COMPILER`: C++ compiler
- `CMAKE_CUDA_COMPILER`: CUDA compiler
- `CMAKE_CXX_STANDARD`: C++ standard (OpenCV requires C++11+)
- `CMAKE_CUDA_STANDARD`: CUDA standard (typically C++14/17)

### Compiler Flags
- `CMAKE_C_FLAGS`: C compiler flags
- `CMAKE_CXX_FLAGS`: C++ compiler flags
- `CMAKE_CUDA_FLAGS`: CUDA compiler flags
- `CMAKE_EXE_LINKER_FLAGS`: Executable linker flags
- `CMAKE_SHARED_LINKER_FLAGS`: Shared library linker flags

### RPATH
- `CMAKE_INSTALL_RPATH`: RPATH entries for installed libraries
- `CMAKE_INSTALL_RPATH_USE_LINK_PATH`: Use linker path as RPATH

### Dependency Detection
- `CMAKE_PREFIX_PATH`: Semicolon-separated list of paths where CMake searches for dependencies (critical for LAPACK and TBB detection)
- `CMAKE_INCLUDE_PATH`: Semicolon-separated list of paths for header file search
- `CMAKE_LIBRARY_PATH`: Semicolon-separated list of paths for library file search

### LAPACK Detection Variables
- `LAPACK_LIBRARIES`: Semicolon-separated list of LAPACK library files (required when `WITH_LAPACK=ON`)
- `LAPACK_INCLUDE_DIR` or `LAPACK_INCLUDE_DIRS`: Path to LAPACK header directory (required for proper detection)
- `BLA_VENDOR`: BLAS/LAPACK vendor identifier (e.g., `Intel10_64lp`, `OpenBLAS`, `Generic`)
- `BLAS_LIBRARIES`: BLAS library files (often same as LAPACK when using MKL)

### TBB Detection Variables
- `TBB_DIR`: Path to TBB CMake config directory (e.g., `/usr/lib/x86_64-linux-gnu/cmake/TBB`)
  - **CRITICAL:** Modern Ubuntu TBB packages provide CMake config files here
  - OpenCV's `find_package(TBB)` will use this if available
- `TBB_ROOT_DIR`: Root directory of TBB installation (e.g., `/usr`)
  - Used as fallback if `TBB_DIR` is not found
- `TBB_INCLUDE_DIR` or `TBB_INCLUDE_DIRS`: Path to TBB header directory (e.g., `/usr/include/tbb`)
  - **Required Headers:** Must contain `tbb/tbb.h` (or `oneapi/tbb/version.h` for oneTBB 2021+)
  - Ubuntu 24.04 provides both legacy (`/usr/include/tbb/tbb.h`) and oneTBB (`/usr/include/oneapi/tbb/version.h`) headers
- `TBB_LIBRARIES`: Full path to TBB library file (e.g., `/usr/lib/x86_64-linux-gnu/libtbb.so`)
  - **Explicit override:** Ensures correct library is linked even if `TBB_DIR` is ignored
  - **CRITICAL:** Must point to system TBB, NOT MKL TBB (`/opt/intel/oneapi/tbb/lib/libtbb.so`)

### LAPACK Detection Variables (MKL)
- `LAPACK_LIBRARIES`: Semicolon-separated list of MKL library files
  - **CRITICAL:** Must use MKL libraries, NOT OpenBLAS
  - Example: `"${MKLROOT}/lib/intel64/libmkl_intel_lp64.so;${MKLROOT}/lib/intel64/libmkl_core.so;${MKLROOT}/lib/intel64/libmkl_gnu_thread.so"`
- `LAPACK_INCLUDE_DIR` or `LAPACK_INCLUDE_DIRS`: Path to MKL header directory
  - **Required Headers:** Must contain `mkl_cblas.h` and `mkl_lapack.h`
  - Example: `"${MKLROOT}/include"`
- `BLA_VENDOR`: BLAS/LAPACK vendor identifier
  - **For MKL:** `Intel10_64lp` (LP64 interface, recommended)
  - **Alternative:** `Intel10_64lp_seq` (sequential, no threading, not recommended)
- `BLAS_LIBRARIES`: BLAS library files (often same as LAPACK for MKL)
  - Example: Same as `LAPACK_LIBRARIES` when using MKL
- `MKL_ROOT`: Root directory of MKL installation
  - Example: `"${MKLROOT}"` (from environment variable)
- `MKL_THREADING_LAYER`: MKL threading layer (CRITICAL for performance)
  - **Recommended:** `GNU` (GNU OpenMP, compatible with GCC toolchain)
  - **Why GNU?** Uses `libgomp` (GNU OpenMP), avoids conflicts with Intel OpenMP
  - **Alternative (NOT RECOMMENDED):** `INTEL` (requires Intel OpenMP, conflicts with GNU OpenMP)

**Critical Notes:**
- **OpenCV MUST use MKL (not OpenBLAS):** OpenCV is configured to link with Intel MKL for optimal performance
- **MKL Threading Model:** Use `MKL_THREADING_LAYER=GNU` with `MKL_WITH_OPENMP=ON` for GCC toolchain compatibility
- **TBB vs MKL TBB:** OpenCV uses system TBB (`/usr/lib/x86_64-linux-gnu/libtbb.so`), NOT MKL's optional TBB build
- OpenCV uses `find_package(LAPACK)` and `find_package(TBB)` internally, but explicit variables ensure reliable detection
- If detection fails, explicitly set all relevant variables (`*_LIBRARIES`, `*_INCLUDE_DIR`, `*_DIR`, etc.)
- Ensure `CMAKE_PREFIX_PATH` includes installation directories:
  - For MKL: `${MKLROOT}`
  - For TBB: `/usr` (system TBB)
- Use `CMAKE_IGNORE_PATH` to exclude MKL TBB: `-DCMAKE_IGNORE_PATH=/opt/intel/oneapi/tbb`

---

## Module-Specific BUILD_opencv_* Options

OpenCV has 100+ modules, each with a `BUILD_opencv_<module>` option. Common modules include:

**Core Modules:**
- `BUILD_opencv_core`, `BUILD_opencv_imgproc`, `BUILD_opencv_imgcodecs`, `BUILD_opencv_videoio`, `BUILD_opencv_highgui`, `BUILD_opencv_features2d`, `BUILD_opencv_calib3d`, `BUILD_opencv_objdetect`, `BUILD_opencv_dnn`, `BUILD_opencv_ml`, `BUILD_opencv_flann`, `BUILD_opencv_photo`, `BUILD_opencv_video`, `BUILD_opencv_stitching`, `BUILD_opencv_superres`, `BUILD_opencv_videostab`

**CUDA Modules** (require `WITH_CUDA=ON`):
- `BUILD_opencv_cudaarithm`, `BUILD_opencv_cudabgsegm`, `BUILD_opencv_cudacodec`, `BUILD_opencv_cudafeatures2d`, `BUILD_opencv_cudafilters`, `BUILD_opencv_cudaimgproc`, `BUILD_opencv_cudaobjdetect`, `BUILD_opencv_cudaoptflow`, `BUILD_opencv_cudastereo`, `BUILD_opencv_cudawarping`, `BUILD_opencv_cudev`

**Contrib Modules** (require `OPENCV_EXTRA_MODULES_PATH`):
- `BUILD_opencv_sfm`, `BUILD_opencv_xfeatures2d`, `BUILD_opencv_ximgproc`, `BUILD_opencv_aruco`, `BUILD_opencv_bgsegm`, `BUILD_opencv_bioinspired`, `BUILD_opencv_ccalib`, `BUILD_opencv_datasets`, `BUILD_opencv_dpm`, `BUILD_opencv_face`, `BUILD_opencv_freetype`, `BUILD_opencv_fuzzy`, `BUILD_opencv_hdf`, `BUILD_opencv_hfs`, `BUILD_opencv_img_hash`, `BUILD_opencv_line_descriptor`, `BUILD_opencv_optflow`, `BUILD_opencv_phase_unwrapping`, `BUILD_opencv_plot`, `BUILD_opencv_reg`, `BUILD_opencv_rgbd`, `BUILD_opencv_saliency`, `BUILD_opencv_shape`, `BUILD_opencv_stereo`, `BUILD_opencv_structured_light`, `BUILD_opencv_superres`, `BUILD_opencv_surface_matching`, `BUILD_opencv_text`, `BUILD_opencv_tracking`, `BUILD_opencv_xfeatures2d`, `BUILD_opencv_ximgproc`, `BUILD_opencv_xobjdetect`, `BUILD_opencv_xphoto`

**Note:** To see all available modules, run CMake and check the output or browse `modules/` directory.

---

## Usage Examples

### Minimal Configuration (Shared Library)
```cmake
cmake .. \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=ON \
  -DWITH_OPENMP=ON \
  -DBUILD_TESTS=OFF \
  -DBUILD_EXAMPLES=OFF
```

### Full Configuration with CUDA and MKL
```cmake
cmake .. \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/opt \
  -DBUILD_SHARED_LIBS=ON \
  -DOPENCV_EXTRA_MODULES_PATH=/tmp/opencv_contrib/modules \
  -DWITH_CUDA=ON \
  -DCUDA_ARCH_BIN="86;89;90" \
  -DCUDA_ARCH_PTX="86" \
  -DCUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda-12.6 \
  -DCUDA_HOST_COMPILER=/usr/bin/g++-12 \
  -DWITH_CUDNN=ON \
  -DOPENCV_DNN_CUDA=ON \
  -DOPENCV_DNN_CUDA_VERSION=12.6 \
  -DWITH_TBB=ON \
  -DTBB_DIR=/usr/lib/x86_64-linux-gnu/cmake/TBB \
  -DTBB_ROOT_DIR=/usr \
  -DTBB_INCLUDE_DIR=/usr/include/tbb \
  -DTBB_INCLUDE_DIRS=/usr/include/tbb \
  -DTBB_LIBRARIES=/usr/lib/x86_64-linux-gnu/libtbb.so \
  -DCMAKE_IGNORE_PATH=/opt/intel/oneapi/tbb \
  -DWITH_EIGEN=ON \
  -DWITH_FFMPEG=ON \
  -DWITH_GSTREAMER=ON \
  -DWITH_LAPACK=ON \
  -DWITH_MKL=ON \
  -DMKL_WITH_OPENMP=ON \
  -DMKL_THREADING_LAYER=GNU \
  -DMKL_USE_STATIC_LIBS=OFF \
  -DBLA_VENDOR=Intel10_64lp \
  -DBLAS_LIBRARIES="${MKLROOT}/lib/intel64/libmkl_intel_lp64.so;${MKLROOT}/lib/intel64/libmkl_core.so;${MKLROOT}/lib/intel64/libmkl_gnu_thread.so" \
  -DLAPACK_LIBRARIES="${MKLROOT}/lib/intel64/libmkl_intel_lp64.so;${MKLROOT}/lib/intel64/libmkl_core.so;${MKLROOT}/lib/intel64/libmkl_gnu_thread.so" \
  -DLAPACK_INCLUDE_DIR="${MKLROOT}/include" \
  -DLAPACK_INCLUDE_DIRS="${MKLROOT}/include" \
  -DMKL_ROOT="${MKLROOT}" \
  -DWITH_OPENGL=ON \
  -DWITH_OPENMP=ON \
  -DENABLE_FAST_MATH=ON \
  -DCUDA_FAST_MATH=ON \
  -DCPU_BASELINE=AVX2 \
  -DCPU_DISPATCH="AVX2,FP16,AVX512_SKX" \
  -DCMAKE_PREFIX_PATH="/usr:${MKLROOT}" \
  -DBUILD_opencv_python3=ON \
  -DPYTHON3_EXECUTABLE=/usr/bin/python3 \
  -DBUILD_TESTS=OFF \
  -DBUILD_EXAMPLES=OFF \
  -DBUILD_PERF_TESTS=OFF \
  -DBUILD_DOCS=OFF
```

**Key Points:**
- **MKL (not OpenBLAS):** `WITH_MKL=ON` ensures OpenCV uses Intel MKL for LAPACK operations
- **MKL Threading:** `MKL_THREADING_LAYER=GNU` uses GNU OpenMP (`libgomp`), compatible with GCC toolchain
- **TBB Exclusion:** `CMAKE_IGNORE_PATH=/opt/intel/oneapi/tbb` prevents OpenCV from using MKL's optional TBB build
- **System TBB:** TBB variables point to system TBB (`/usr/lib/x86_64-linux-gnu/libtbb.so`), not MKL TBB
- **Explicit Library Paths (CRITICAL):** Use explicit `Ceres_DIR` and `SuiteSparse_DIR` to ensure OpenCV uses compiled libraries (e.g., from our builds) rather than system-installed versions:
  ```cmake
  -DCeres_DIR=/usr/local/lib/cmake/Ceres
  -DSuiteSparse_DIR=/usr/local/lib/cmake/SuiteSparse
  ```
  Include `/usr/local` first in `CMAKE_PREFIX_PATH` to prioritize compiled libraries over system libraries.

### Static Library Build
```cmake
cmake .. \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DENABLE_PIC=ON \
  -DWITH_OPENMP=ON \
  -DBUILD_TESTS=OFF
```

---

## Notes and Best Practices

1. **opencv_contrib:** Many advanced features require `OPENCV_EXTRA_MODULES_PATH` pointing to opencv_contrib modules.

2. **CUDA Architectures:** Set `CUDA_ARCH_BIN` to match your GPU compute capability (e.g., `"86"` for RTX 3090/A6000, `"89"` for RTX 4090).

3. **Python Bindings:** Python 3 bindings are built by default if Python 3 is found. Use `PYTHON3_*` variables to control paths.

4. **Module Selection:** Use `BUILD_LIST` to build only specific modules for minimal builds.

5. **Performance:** Enable `CPU_BASELINE` and `CPU_DISPATCH` for optimized builds targeting specific CPUs.

6. **License:** `OPENCV_ENABLE_NONFREE=ON` enables algorithms with restrictive licenses (SIFT, SURF).

7. **DNN CUDA:** Requires both `WITH_CUDA=ON` and `WITH_CUDNN=ON` for GPU-accelerated deep learning.

8. **Explicit Library Paths (CRITICAL FOR COMPILED LIBRARIES):** When OpenCV depends on libraries you've compiled from source (e.g., Ceres, SuiteSparse), explicitly set their CMake config directories to ensure OpenCV uses your builds instead of system-installed versions:
   - Use `-DCeres_DIR=/usr/local/lib/cmake/Ceres` to force OpenCV to use compiled Ceres
   - Use `-DSuiteSparse_DIR=/usr/local/lib/cmake/SuiteSparse` to force OpenCV to use compiled SuiteSparse
   - Include `/usr/local` first in `CMAKE_PREFIX_PATH` to prioritize compiled libraries: `-DCMAKE_PREFIX_PATH=/usr/local:/usr:${MKLROOT}`
   - This ensures compatibility and consistency across the build stack

---

## References

- OpenCV Documentation: https://docs.opencv.org/
- OpenCV GitHub: https://github.com/opencv/opencv
- opencv_contrib GitHub: https://github.com/opencv/opencv_contrib
- CMake Documentation: https://cmake.org/documentation/

---

**Document Version:** 1.0  
**Last Updated:** Generated from OpenCV 4.12.0 source code

**Note:** This documentation covers the most commonly used options. OpenCV has 100+ modules with individual `BUILD_opencv_*` options. Refer to CMake configuration output or `modules/` directory for complete list.

