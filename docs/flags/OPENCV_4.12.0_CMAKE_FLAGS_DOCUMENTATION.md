# OpenCV 4.12.0 - Comprehensive CMake Flags Documentation

**Version:** 4.12.0  
**Source Repository:** https://github.com/opencv/opencv  
**Contrib Repository:** https://github.com/opencv/opencv_contrib  
**Commit:** `49486f61fb25722cbcf586b7f4320921d46fb38e`  
**Last Audited:** November 9, 2025 (Library-Analysis-Tool)  
**Documentation Generated:** From source code analysis  
**CMake Minimum Version:** 3.5

> **2025 Audit Highlights**
> - Library-Analysis-Tool scanned 118 `CMakeLists.txt`, 1,735 headers, and 16 helper scripts in the 4.12.0 tag.  
> - No new top-level `option()` entries were introduced; feature gates such as `OPENCV_ENABLE_NONFREE`, `WITH_CUDA`, `WITH_OPENCL`, `BUILD_opencv_*`, and `OPENCV_DNN_OPENVINO` retain their documented defaults.  
> - Dependency scan continues to report the same optional integrations (Intel TBB, CUDA, cuDNN, OpenVINO, FFmpeg, GStreamer, Vulkan, etc.) with no additional mandatory packages.

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
- **Description:** Use OpenBLAS for BLAS operations.
- **Usage:**
  ```cmake
  -DWITH_OPENBLAS=ON
  ```

### `WITH_TBB`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Use Intel Threading Building Blocks for parallelization.
- **Usage:**
  ```cmake
  -DWITH_TBB=ON
  ```
- **Note:** When `WITH_TBB=ON`, OpenCV uses `find_package(TBB)` to locate TBB. For proper detection, also set:
  - `TBB_DIR`: Path to TBB CMake config directory (e.g., `/usr/lib/x86_64-linux-gnu/cmake/TBB`)
  - `TBB_ROOT_DIR`: Root directory of TBB installation (e.g., `/usr`)
  - `TBB_INCLUDE_DIR` or `TBB_INCLUDE_DIRS`: Path to TBB headers (e.g., `/usr/include/tbb`)
  - `TBB_LIBRARIES`: Path to TBB library file (e.g., `/usr/lib/x86_64-linux-gnu/libtbb.so`)
- **Critical:** If TBB is not detected, ensure `CMAKE_PREFIX_PATH` includes the TBB installation directory.

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
- **Default:** `OFF`
- **Description:** Enable LAPACK support for linear algebra operations (SVD, QR decomposition, Cholesky, etc.).
- **Usage:**
  ```cmake
  -DWITH_LAPACK=ON
  ```
- **Note:** When `WITH_LAPACK=ON`, OpenCV uses `find_package(LAPACK)` to locate LAPACK. For proper detection, also set:
  - `LAPACK_LIBRARIES`: Path to LAPACK library files (semicolon-separated for multiple libraries)
  - `LAPACK_INCLUDE_DIR` or `LAPACK_INCLUDE_DIRS`: Path to LAPACK headers (e.g., `${MKLROOT}/include` for Intel MKL)
  - `BLA_VENDOR`: BLAS/LAPACK vendor (e.g., `Intel10_64lp` for Intel MKL)
  - `BLAS_LIBRARIES`: BLAS library files (often same as LAPACK when using MKL)
- **Critical:** If LAPACK is not detected, ensure:
  1. `CMAKE_PREFIX_PATH` includes the LAPACK installation directory (e.g., `${MKLROOT}` for Intel MKL)
  2. Both `LAPACK_LIBRARIES` and `LAPACK_INCLUDE_DIR` are explicitly set
  3. `BLA_VENDOR` matches your BLAS/LAPACK provider
- **Example with Intel MKL:**
  ```cmake
  -DWITH_LAPACK=ON
  -DBLA_VENDOR=Intel10_64lp
  -DLAPACK_LIBRARIES="${MKLROOT}/lib/intel64/libmkl_intel_lp64.so;${MKLROOT}/lib/intel64/libmkl_core.so;${MKLROOT}/lib/intel64/libmkl_gnu_thread.so"
  -DLAPACK_INCLUDE_DIR="${MKLROOT}/include"
  -DCMAKE_PREFIX_PATH="${MKLROOT}"
  ```

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
- `TBB_ROOT_DIR`: Root directory of TBB installation (e.g., `/usr`)
- `TBB_INCLUDE_DIR` or `TBB_INCLUDE_DIRS`: Path to TBB header directory (e.g., `/usr/include/tbb`)
- `TBB_LIBRARIES`: Path to TBB library file (e.g., `/usr/lib/x86_64-linux-gnu/libtbb.so`)

**Critical Notes:**
- OpenCV uses `find_package(LAPACK)` and `find_package(TBB)` internally
- If detection fails, explicitly set all relevant variables (`*_LIBRARIES`, `*_INCLUDE_DIR`, `*_DIR`, etc.)
- Ensure `CMAKE_PREFIX_PATH` includes installation directories for both LAPACK and TBB
- For Intel MKL, set `CMAKE_PREFIX_PATH` to include `${MKLROOT}`

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

### Full Configuration with CUDA
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
  -DWITH_OPENBLAS=ON \
  -DWITH_TBB=ON \
  -DTBB_DIR=/usr/lib/x86_64-linux-gnu/cmake/TBB \
  -DTBB_ROOT_DIR=/usr \
  -DTBB_INCLUDE_DIR=/usr/include/tbb \
  -DTBB_LIBRARIES=/usr/lib/x86_64-linux-gnu/libtbb.so \
  -DWITH_EIGEN=ON \
  -DWITH_FFMPEG=ON \
  -DWITH_GSTREAMER=ON \
  -DWITH_LAPACK=ON \
  -DBLA_VENDOR=Intel10_64lp \
  -DLAPACK_LIBRARIES="${MKLROOT}/lib/intel64/libmkl_intel_lp64.so;${MKLROOT}/lib/intel64/libmkl_core.so;${MKLROOT}/lib/intel64/libmkl_gnu_thread.so" \
  -DLAPACK_INCLUDE_DIR="${MKLROOT}/include" \
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

