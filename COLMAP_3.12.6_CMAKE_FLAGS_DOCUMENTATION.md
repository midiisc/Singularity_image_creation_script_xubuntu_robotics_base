# COLMAP 3.12.6 - Comprehensive CMake Flags Documentation

**Version:** 3.12.6  
**Source Repository:** https://github.com/colmap/colmap  
**Documentation Generated:** From source code analysis  
**CMake Minimum Version:** 3.12

---

## Table of Contents

1. [Core Build Options](#core-build-options)
2. [Performance Options](#performance-options)
3. [CUDA Options](#cuda-options)
4. [GUI Options](#gui-options)
5. [Testing Options](#testing-options)
6. [Dependency Options](#dependency-options)
7. [Development Options](#development-options)
8. [Standard CMake Variables](#standard-cmake-variables)
9. [Dependency Find Variables](#dependency-find-variables)
10. [Usage Examples](#usage-examples)

---

## Core Build Options

### `CMAKE_BUILD_TYPE`
- **Type:** `STRING` (Cache variable)
- **Default:** `Release` (if not specified)
- **Options:** `Debug`, `Release`, `RelWithDebInfo`, `MinSizeRel`
- **Description:** Specifies the build configuration.
- **Usage:**
  ```cmake
  -DCMAKE_BUILD_TYPE=Release
  ```
- **Note:** Defaults to Release if not specified.

### `CMAKE_INSTALL_PREFIX`
- **Type:** `CACHE PATH`
- **Default:** Platform-dependent (e.g., `/usr/local` on Unix)
- **Description:** Installation prefix for COLMAP.
- **Usage:**
  ```cmake
  -DCMAKE_INSTALL_PREFIX=/usr/local
  ```

### `CMAKE_POSITION_INDEPENDENT_CODE`
- **Type:** `BOOL`
- **Default:** `ON` (hardcoded)
- **Description:** Build position-independent code (PIC) for shared library compatibility.
- **Note:** Always ON in COLMAP CMakeLists.txt.

### `CMAKE_CXX_STANDARD`
- **Type:** `INTEGER`
- **Default:** `17` (hardcoded)
- **Description:** C++ standard version (COLMAP requires C++17).
- **Note:** Always 17 in COLMAP CMakeLists.txt.

### `CMAKE_CXX_STANDARD_REQUIRED`
- **Type:** `BOOL`
- **Default:** `ON` (hardcoded)
- **Description:** Require C++17 standard.
- **Note:** Always ON in COLMAP CMakeLists.txt.

### `CMAKE_CUDA_STANDARD`
- **Type:** `INTEGER`
- **Default:** `17` (hardcoded, if CUDA enabled)
- **Description:** CUDA standard version.
- **Note:** Always 17 when CUDA is enabled.

### `CMAKE_CUDA_STANDARD_REQUIRED`
- **Type:** `BOOL`
- **Default:** `ON` (hardcoded, if CUDA enabled)
- **Description:** Require CUDA C++17 standard.

---

## Performance Options

### `SIMD_ENABLED`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Whether to enable SIMD optimizations (SSE, AVX, etc.).
- **Usage:**
  ```cmake
  -DSIMD_ENABLED=ON
  ```

### `OPENMP_ENABLED`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Whether to enable OpenMP parallelization.
- **Usage:**
  ```cmake
  -DOPENMP_ENABLED=ON
  ```
- **Note:** Requires OpenMP library.

### `IPO_ENABLED`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Whether to enable interprocedural optimization (LTO/Link Time Optimization).
- **Usage:**
  ```cmake
  -DIPO_ENABLED=ON
  ```
- **Note:** May significantly increase compile time but improves performance.

---

## CUDA Options

### `CUDA_ENABLED`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Whether to enable CUDA, if available.
- **Usage:**
  ```cmake
  -DCUDA_ENABLED=ON
  ```
- **Note:** Automatically disabled if CUDA toolkit is not found.

### `CMAKE_CUDA_ARCHITECTURES`
- **Type:** `CACHE STRING`
- **Default:** Not set (auto-detected or CMake default)
- **Description:** CUDA compute architectures to target (e.g., `"86;89;90"`).
- **Usage:**
  ```cmake
  -DCMAKE_CUDA_ARCHITECTURES="86;89;90"
  ```
- **Note:** Required for CUDA-enabled builds. Separate multiple architectures with semicolon.

### `CUDA_TOOLKIT_ROOT_DIR`
- **Type:** `CACHE PATH`
- **Default:** Auto-detected
- **Description:** Root directory of CUDA toolkit installation.
- **Usage:**
  ```cmake
  -DCUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda-12.6
  ```

---

## GUI Options

### `GUI_ENABLED`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Whether to enable the graphical UI.
- **Usage:**
  ```cmake
  -DGUI_ENABLED=ON
  ```
- **Note:** Requires Qt5/Qt6. Disable for headless/server builds.

### `OPENGL_ENABLED`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON` (if OpenGL found)
- **Description:** Whether to enable OpenGL, if available.
- **Usage:**
  ```cmake
  -DOPENGL_ENABLED=ON
  ```
- **Note:** Requires OpenGL library. Used for 3D visualization.

---

## Testing Options

### `TESTS_ENABLED`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Whether to build test binaries.
- **Usage:**
  ```cmake
  -DTESTS_ENABLED=ON
  ```

---

## Development Options

### `COVERAGE_ENABLED`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Whether to enable code coverage reporting.
- **Usage:**
  ```cmake
  -DCOVERAGE_ENABLED=ON
  ```
- **Note:** Adds `--coverage` compiler flags.

### `ASAN_ENABLED`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Whether to enable AddressSanitizer flags.
- **Usage:**
  ```cmake
  -DASAN_ENABLED=ON
  ```
- **Note:** For debugging memory errors.

### `TSAN_ENABLED`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Whether to enable ThreadSanitizer flags.
- **Usage:**
  ```cmake
  -DTSAN_ENABLED=ON
  ```
- **Note:** For debugging thread-related issues.

### `UBSAN_ENABLED`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Whether to enable UndefinedBehaviorSanitizer flags.
- **Usage:**
  ```cmake
  -DUBSAN_ENABLED=ON
  ```
- **Note:** For detecting undefined behavior.

### `PROFILING_ENABLED`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Whether to enable google-perftools linker flags.
- **Usage:**
  ```cmake
  -DPROFILING_ENABLED=ON
  ```
- **Note:** Requires google-perftools (gperftools) library.

### `CCACHE_ENABLED`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Whether to enable compiler caching, if available.
- **Usage:**
  ```cmake
  -DCCACHE_ENABLED=ON
  ```
- **Note:** Requires ccache. Speeds up rebuilds.

---

## Dependency Options

### `CGAL_ENABLED`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Whether to enable the CGAL library (Computational Geometry Algorithms Library).
- **Usage:**
  ```cmake
  -DCGAL_ENABLED=ON
  ```
- **Note:** Required for some reconstruction features.

### `LSD_ENABLED`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Whether to enable the LSD library (Line Segment Detector).
- **Usage:**
  ```cmake
  -DLSD_ENABLED=ON
  ```
- **Note:** Used for line segment detection in images.

### `DOWNLOAD_ENABLED`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Whether to enable (automatic) download of resources (requires Curl/OpenSSL).
- **Usage:**
  ```cmake
  -DDOWNLOAD_ENABLED=ON
  ```
- **Note:** Used for downloading test data and models.

### `FETCH_POSELIB`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Whether to consume PoseLib using FetchContent or find_package.
- **Usage:**
  ```cmake
  -DFETCH_POSELIB=ON
  ```
- **Note:** `ON` uses FetchContent (downloads if not found), `OFF` uses `find_package()`.

### `FETCH_FAISS`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Whether to consume faiss using FetchContent or find_package.
- **Usage:**
  ```cmake
  -DFETCH_FAISS=ON
  ```
- **Note:** `ON` uses FetchContent (downloads if not found), `OFF` uses `find_package()`.

---

## Other Options

### `UNINSTALL_ENABLED`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Whether to create a target to 'uninstall' colmap.
- **Usage:**
  ```cmake
  -DUNINSTALL_ENABLED=ON
  ```
- **Note:** Creates `make uninstall` or equivalent target.

### `ALL_SOURCE_TARGET`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Whether to create a target for all source files (for Visual Studio / XCode development).
- **Usage:**
  ```cmake
  -DALL_SOURCE_TARGET=ON
  ```
- **Note:** Useful for IDE integration (Visual Studio, Xcode).

---

## Standard CMake Variables

COLMAP respects standard CMake variables:

### Build System
- `CMAKE_GENERATOR`: Build system generator (e.g., `Ninja`, `Unix Makefiles`)
- `CMAKE_BUILD_TYPE`: Build configuration
- `CMAKE_INSTALL_PREFIX`: Installation directory

### Compilers
- `CMAKE_C_COMPILER`: C compiler
- `CMAKE_CXX_COMPILER`: C++ compiler
- `CMAKE_CUDA_COMPILER`: CUDA compiler (if `CUDA_ENABLED=ON`)

### Compiler Flags
- `CMAKE_C_FLAGS`: C compiler flags
- `CMAKE_CXX_FLAGS`: C++ compiler flags
- `CMAKE_CUDA_FLAGS`: CUDA compiler flags
- `CMAKE_EXE_LINKER_FLAGS`: Executable linker flags
- `CMAKE_SHARED_LINKER_FLAGS`: Shared library linker flags

### RPATH
- `CMAKE_INSTALL_RPATH`: RPATH entries for installed libraries
- `CMAKE_INSTALL_RPATH_USE_LINK_PATH`: Use linker path as RPATH

---

## Dependency Find Variables

COLMAP uses standard CMake `find_package()` for dependencies. These variables can help CMake locate dependencies:

### Ceres Solver
- `Ceres_DIR`: Directory containing `CeresConfig.cmake`
- **Required:** Yes (for bundle adjustment)

### Eigen3
- `Eigen3_DIR`: Directory containing `Eigen3Config.cmake`
- **Required:** Yes

### glog
- `glog_DIR`: Directory containing `glogConfig.cmake` (CMake-built glog)
- `GLOG_INCLUDE_DIR_HINTS`: Custom include directory hint (CACHE variable)
- `GLOG_LIBRARY_DIR_HINTS`: Custom library directory hint (CACHE variable)
- **Required:** Yes (for logging)

### gflags
- `gflags_DIR`: Directory containing `gflagsConfig.cmake`
- **Required:** Yes (used with glog)

### OpenCV
- `OpenCV_DIR`: Directory containing `OpenCVConfig.cmake`
- **Required:** Yes (for image processing)

### Qt5/Qt6 (if `GUI_ENABLED=ON`)
- `Qt5_DIR` or `Qt6_DIR`: Directory containing Qt CMake config
- **Required:** Yes for GUI

### CGAL (if `CGAL_ENABLED=ON`)
- `CGAL_DIR`: Directory containing `CGALConfig.cmake`
- **Required:** Yes

### FreeImage
- `FREEIMAGE_INCLUDE_DIR_HINTS`: Custom include directory hint (CACHE variable)
- `FREEIMAGE_LIBRARY_DIR_HINTS`: Custom library directory hint (CACHE variable)
- **Required:** Yes (for image I/O)

### METIS (if `GTSAM_SUPPORT_NESTED_DISSECTION` or similar)
- `METIS_INCLUDE_DIR_HINTS`: Custom include directory hint (CACHE variable)
- `METIS_LIBRARY_DIR_HINTS`: Custom library directory hint (CACHE variable)

### OpenGL (if `OPENGL_ENABLED=ON`)
- Uses standard CMake `find_package(OpenGL)`

### CUDA (if `CUDA_ENABLED=ON`)
- `CUDAToolkit_ROOT`: Root directory of CUDA toolkit (CMake 3.17+)
- `CUDA_TOOLKIT_ROOT_DIR`: Root directory (legacy)

---

## Usage Examples

### Minimal Configuration (Headless Build)
```cmake
cmake .. \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DCUDA_ENABLED=ON \
  -DCMAKE_CUDA_ARCHITECTURES="86;89;90" \
  -DSIMD_ENABLED=ON \
  -DOPENMP_ENABLED=ON \
  -DIPO_ENABLED=ON \
  -DGUI_ENABLED=OFF \
  -DTESTS_ENABLED=OFF \
  -DCeres_DIR=/usr/local/lib/cmake/Ceres \
  -DEigen3_DIR=/usr/local/share/eigen3/cmake \
  -Dglog_DIR=/usr/lib/x86_64-linux-gnu/cmake/glog \
  -Dgflags_DIR=/usr/lib/x86_64-linux-gnu/cmake/gflags \
  -DOpenCV_DIR=/usr/local/lib/cmake/opencv4
```

### Full Configuration with GUI
```cmake
cmake .. \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DCUDA_ENABLED=ON \
  -DCMAKE_CUDA_ARCHITECTURES="86;89;90" \
  -DSIMD_ENABLED=ON \
  -DOPENMP_ENABLED=ON \
  -DIPO_ENABLED=ON \
  -DGUI_ENABLED=ON \
  -DOPENGL_ENABLED=ON \
  -DCGAL_ENABLED=ON \
  -DLSD_ENABLED=ON \
  -DTESTS_ENABLED=OFF \
  -DCCACHE_ENABLED=ON \
  -DCeres_DIR=/usr/local/lib/cmake/Ceres \
  -DEigen3_DIR=/usr/local/share/eigen3/cmake \
  -Dglog_DIR=/usr/lib/x86_64-linux-gnu/cmake/glog \
  -Dgflags_DIR=/usr/lib/x86_64-linux-gnu/cmake/gflags \
  -DOpenCV_DIR=/usr/local/lib/cmake/opencv4 \
  -DQt5_DIR=/usr/lib/x86_64-linux-gnu/cmake/Qt5
```

### Development Build with Sanitizers
```cmake
cmake .. \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCUDA_ENABLED=OFF \
  -DTESTS_ENABLED=ON \
  -DASAN_ENABLED=ON \
  -DUBSAN_ENABLED=ON \
  -DCOVERAGE_ENABLED=ON \
  -DCCACHE_ENABLED=ON
```

---

## Notes and Best Practices

1. **C++17 Required:** COLMAP requires C++17. Ensure your compiler supports it (GCC 7+, Clang 5+, MSVC 2017+).

2. **CUDA Architectures:** Set `CMAKE_CUDA_ARCHITECTURES` to match your GPU. Use `"86;89;90"` for modern GPUs (RTX 30xx, A6000, RTX 40xx).

3. **System glog:** COLMAP works best with system glog (Ubuntu's patched version 0.6.0) for compatibility. Use `glog_DIR` to point to system installation.

4. **GUI Dependencies:** `GUI_ENABLED=ON` requires Qt5 or Qt6. For headless builds, set `GUI_ENABLED=OFF`.

5. **Ceres Solver:** Required for bundle adjustment. Ensure Ceres is compiled with compatible options (e.g., `USE_CUDA=ON` if using CUDA).

6. **OpenCV:** Required. Ensure OpenCV is built with CUDA support if you want GPU acceleration.

7. **CGAL:** Required for some advanced reconstruction features. Can be disabled if not needed (`CGAL_ENABLED=OFF`).

8. **LTO/IPO:** `IPO_ENABLED=ON` improves performance but significantly increases compile time. Consider disabling for development builds.

9. **FetchContent vs find_package:** Use `FETCH_POSELIB=OFF` and `FETCH_FAISS=OFF` if you have system installations of these libraries.

10. **Sanitizers:** Use sanitizers (`ASAN_ENABLED`, `TSAN_ENABLED`, `UBSAN_ENABLED`) for debugging. They significantly slow down execution.

---

## Invalid/Non-existent Flags

The following flags are **NOT** supported by COLMAP 3.12.6:

- `BUILD_SHARED_LIBS` - COLMAP does not support this (uses static libraries by default)
- `WITH_CUDA` - Use `CUDA_ENABLED` instead
- `WITH_OPENMP` - Use `OPENMP_ENABLED` instead
- `BUILD_TESTS` - Use `TESTS_ENABLED` instead
- `CMAKE_CXX_STANDARD` - Hardcoded to 17 (cannot be changed)
- `BOOST_STATIC` - Deprecated/removed in COLMAP 3.12.6

---

## References

- COLMAP Documentation: https://colmap.github.io/
- COLMAP GitHub Repository: https://github.com/colmap/colmap
- CMake Documentation: https://cmake.org/documentation/

---

**Document Version:** 1.0  
**Last Updated:** Generated from COLMAP 3.12.6 source code

