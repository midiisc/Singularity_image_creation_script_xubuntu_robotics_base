# g2o (General Graph Optimization) - Comprehensive CMake Flags Documentation

**Version:** Latest (2024-12-28 git commit)  
**Source Repository:** https://github.com/RainerKuemmerle/g2o  
**Documentation Generated:** From source code analysis  
**CMake Minimum Version:** 3.14

---

## Table of Contents

1. [Core Build Options](#core-build-options)
2. [Linear Algebra Solvers](#linear-algebra-solvers)
3. [Type System Options](#type-system-options)
4. [Visualization Options](#visualization-options)
5. [Optimization Options](#optimization-options)
6. [Testing and Examples](#testing-and-examples)
7. [SSE Optimizations](#sse-optimizations)
8. [Standard CMake Variables](#standard-cmake-variables)
9. [Dependency Find Variables](#dependency-find-variables)
10. [Usage Examples](#usage-examples)

---

## Core Build Options

### `BUILD_SHARED_LIBS`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON` (shared libraries preferred)
- **Description:** Build shared libraries (`.so`) or static libraries (`.a`). Shared libraries are preferred and required for the g2o plugin system.
- **Usage:**
  ```cmake
  -DBUILD_SHARED_LIBS=ON
  ```
- **Note:** Plugin system requires shared libraries.

### `CMAKE_BUILD_TYPE`
- **Type:** `STRING` (Cache variable)
- **Default:** `Release` (if not specified)
- **Options:** `None`, `Debug`, `Release`, `RelWithDebInfo`, `MinSizeRel`
- **Description:** Specifies the build configuration.
- **Usage:**
  ```cmake
  -DCMAKE_BUILD_TYPE=Release
  ```

### `G2O_INSTALL_CMAKE_CONFIG`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Install CMake configuration files even when used as subdirectory.
- **Usage:**
  ```cmake
  -DG2O_INSTALL_CMAKE_CONFIG=ON
  ```
- **Note:** Useful when g2o is used as a subdirectory in another project.

### `G2O_LIB_VERSION`
- **Type:** `CACHE STRING`
- **Default:** `"0.2.0"`
- **Description:** g2o library version string.
- **Usage:**
  ```cmake
  -DG2O_LIB_VERSION="0.2.0"
  ```

### `G2O_LIB_SOVERSION`
- **Type:** `CACHE STRING`
- **Default:** `"0.2"`
- **Description:** g2o library soversion (soname version).
- **Usage:**
  ```cmake
  -DG2O_LIB_SOVERSION="0.2"
  ```

---

## Linear Algebra Solvers

### `G2O_USE_CHOLMOD`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Build g2o with CHOLMOD support (from SuiteSparse).
- **Usage:**
  ```cmake
  -DG2O_USE_CHOLMOD=ON
  ```
- **Note:** Requires SuiteSparse with CHOLMOD component. Uses `find_package(CHOLMOD)`.

### `G2O_USE_CSPARSE`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Build g2o with CSparse support (LGPL library).
- **Usage:**
  ```cmake
  -DG2O_USE_CSPARSE=ON
  ```
- **Note:** Requires CSparse library and `G2O_USE_LGPL_LIBS=ON`. Uses `find_package(CSparse)`.

### `G2O_USE_LGPL_LIBS`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `TRUE`
- **Description:** Build libraries which use LGPL code (required for CSparse).
- **Usage:**
  ```cmake
  -DG2O_USE_LGPL_LIBS=ON
  ```
- **Note:** If disabled, CSparse support is automatically disabled. License implications for static vs shared libraries.

### `BUILD_LGPL_SHARED_LIBS` (Legacy)
- **Type:** `OPTION` (deprecated)
- **Description:** Legacy flag for LGPL libraries. Must match `BUILD_SHARED_LIBS`.
- **Note:** Replaced by `G2O_USE_LGPL_LIBS`.

---

## Type System Options

### `G2O_BUILD_SLAM2D_TYPES`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Build SLAM2D types.
- **Usage:**
  ```cmake
  -DG2O_BUILD_SLAM2D_TYPES=ON
  ```
- **Note:** If disabled, all SLAM2D-related types are disabled.

### `G2O_BUILD_SLAM2D_ADDON_TYPES`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Build SLAM2D addon types.
- **Usage:**
  ```cmake
  -DG2O_BUILD_SLAM2D_ADDON_TYPES=ON
  ```
- **Note:** Only active if `G2O_BUILD_SLAM2D_TYPES=ON`.

### `G2O_BUILD_DATA_TYPES`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Build SLAM2D data types.
- **Usage:**
  ```cmake
  -DG2O_BUILD_DATA_TYPES=ON
  ```
- **Note:** Only active if `G2O_BUILD_SLAM2D_TYPES=ON`.

### `G2O_BUILD_SCLAM2D_TYPES`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Build SCLAM2D types.
- **Usage:**
  ```cmake
  -DG2O_BUILD_SCLAM2D_TYPES=ON
  ```
- **Note:** Only active if `G2O_BUILD_SLAM2D_TYPES=ON`.

### `G2O_BUILD_SLAM3D_TYPES`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Build SLAM 3D types.
- **Usage:**
  ```cmake
  -DG2O_BUILD_SLAM3D_TYPES=ON
  ```
- **Note:** If disabled, all SLAM3D-related types are disabled.

### `G2O_BUILD_SLAM3D_ADDON_TYPES`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Build SLAM 3D addon types.
- **Usage:**
  ```cmake
  -DG2O_BUILD_SLAM3D_ADDON_TYPES=ON
  ```
- **Note:** Only active if `G2O_BUILD_SLAM3D_TYPES=ON`.

### `G2O_BUILD_SBA_TYPES`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Build SLAM3D SBA (Sparse Bundle Adjustment) types.
- **Usage:**
  ```cmake
  -DG2O_BUILD_SBA_TYPES=ON
  ```
- **Note:** Automatically enabled if `G2O_BUILD_ICP_TYPES` or `G2O_BUILD_SIM3_TYPES` is enabled.

### `G2O_BUILD_ICP_TYPES`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Build SLAM3D ICP (Iterative Closest Point) types.
- **Usage:**
  ```cmake
  -DG2O_BUILD_ICP_TYPES=ON
  ```
- **Note:** Requires `G2O_BUILD_SBA_TYPES` (auto-enabled if needed).

### `G2O_BUILD_SIM3_TYPES`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Build SLAM3D sim3 (similarity transformation) types.
- **Usage:**
  ```cmake
  -DG2O_BUILD_SIM3_TYPES=ON
  ```
- **Note:** Requires `G2O_BUILD_SBA_TYPES` (auto-enabled if needed).

---

## Visualization Options

### `G2O_USE_OPENGL`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Build g2o with OpenGL support for visualization.
- **Usage:**
  ```cmake
  -DG2O_USE_OPENGL=ON
  ```
- **Note:** Requires OpenGL library. Uses `find_package(OpenGL)`.

---

## Optimization Options

### `G2O_USE_OPENMP`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Build g2o with OpenMP support (EXPERIMENTAL).
- **Usage:**
  ```cmake
  -DG2O_USE_OPENMP=ON
  ```
- **Note:** Experimental. Some slowdowns have been observed. Requires OpenMP library via `find_package(OpenMP)`.

### `G2O_FAST_MATH`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Enable fast math operations (may affect precision).
- **Usage:**
  ```cmake
  -DG2O_FAST_MATH=ON
  ```
- **Note:** Adds `-ffast-math` (GCC) or `/fp:fast` (MSVC) compiler flags.

### `BUILD_WITH_MARCH_NATIVE`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Build with `-march=native` (optimize for current CPU).
- **Usage:**
  ```cmake
  -DBUILD_WITH_MARCH_NATIVE=ON
  ```
- **Note:** Only works on Linux (not ARM) and macOS. May produce non-portable binaries.

### `G2O_NO_IMPLICIT_OWNERSHIP_OF_OBJECTS`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Disables memory management in the graph types, requiring callers to manage memory of edges and nodes.
- **Usage:**
  ```cmake
  -DG2O_NO_IMPLICIT_OWNERSHIP_OF_OBJECTS=ON
  ```
- **Note:** Advanced option for custom memory management.

---

## Testing and Examples

### `G2O_BUILD_APPS`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON` (top-level project), `OFF` (subdirectory)
- **Description:** Build g2o applications.
- **Usage:**
  ```cmake
  -DG2O_BUILD_APPS=ON
  ```

### `G2O_BUILD_LINKED_APPS`
- **Type:** `CMAKE_DEPENDENT_OPTION`
- **Default:** `OFF`
- **Description:** Build apps linked with the libraries (no plugin system).
- **Usage:**
  ```cmake
  -DG2O_BUILD_LINKED_APPS=ON
  ```
- **Note:** Only available if `G2O_BUILD_APPS=ON`.

### `G2O_BUILD_EXAMPLES`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON` (top-level project), `OFF` (subdirectory)
- **Description:** Build g2o examples.
- **Usage:**
  ```cmake
  -DG2O_BUILD_EXAMPLES=ON
  ```

### `BUILD_UNITTESTS`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Build unit test framework and the tests.
- **Usage:**
  ```cmake
  -DBUILD_UNITTESTS=ON
  ```

### `G2O_BUILD_BENCHMARKS`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Build benchmarks (requires Google benchmark library).
- **Usage:**
  ```cmake
  -DG2O_BUILD_BENCHMARKS=ON
  ```
- **Note:** Requires `find_package(benchmark)`. Auto-disabled if benchmark not found.

---

## SSE Optimizations

### `DO_SSE_AUTODETECT`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Enable autodetection of SSE* CPU sets and enable their use in optimized code.
- **Usage:**
  ```cmake
  -DDO_SSE_AUTODETECT=ON
  ```
- **Note:** Requires `/proc/cpuinfo` (Linux). Automatically detects SSE2, SSE3, SSE4.1, SSE4.2, SSE4a.

### `DISABLE_SSE2`, `DISABLE_SSE3`, `DISABLE_SSE4_1`, `DISABLE_SSE4_2`, `DISABLE_SSE4_A`
- **Type:** `OPTION` (ON/OFF, advanced)
- **Default:** `OFF`
- **Description:** Forces compilation WITHOUT specific SSE extensions (only when `DO_SSE_AUTODETECT=OFF`).
- **Usage:**
  ```cmake
  -DDO_SSE_AUTODETECT=OFF -DDISABLE_SSE4_1=ON
  ```
- **Note:** Advanced variables, hidden by default. Only relevant when autodetection is disabled.

---

## Other Options

### `G2O_USE_LOGGING`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Try to use spdlog for logging.
- **Usage:**
  ```cmake
  -DG2O_USE_LOGGING=ON
  ```
- **Note:** Requires spdlog 1.6+. Uses `find_package(spdlog)`.

### `BUILD_CODE_COVERAGE`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Enable coverage reporting (adds `--coverage` flags).
- **Usage:**
  ```cmake
  -DBUILD_CODE_COVERAGE=ON
  ```
- **Note:** Only works with GCC or Clang.

---

## Standard CMake Variables

g2o respects standard CMake variables:

### Build System
- `CMAKE_GENERATOR`: Build system generator (e.g., `Ninja`, `Unix Makefiles`)
- `CMAKE_BUILD_TYPE`: Build configuration
- `CMAKE_INSTALL_PREFIX`: Installation directory

### Compilers
- `CMAKE_C_COMPILER`: C compiler
- `CMAKE_CXX_COMPILER`: C++ compiler
- `CMAKE_CXX_STANDARD`: C++ standard (g2o requires C++11+)
- `CMAKE_CXX_STANDARD_REQUIRED`: Require C++ standard

### Compiler Flags
- `CMAKE_C_FLAGS`: C compiler flags
- `CMAKE_CXX_FLAGS`: C++ compiler flags
- `CMAKE_EXE_LINKER_FLAGS`: Executable linker flags
- `CMAKE_SHARED_LINKER_FLAGS`: Shared library linker flags
- `CMAKE_MODULE_LINKER_FLAGS`: Module linker flags

### RPATH
- `CMAKE_INSTALL_RPATH`: RPATH entries for installed libraries
- `CMAKE_INSTALL_RPATH_USE_LINK_PATH`: Use linker path as RPATH

### Platform-Specific
- `CMAKE_OSX_DEPLOYMENT_TARGET`: Minimum OS X deployment target (default: `"10.15"`)

---

## Dependency Find Variables

g2o uses standard CMake `find_package()` for dependencies. These variables can help CMake locate dependencies:

### Eigen3
- `Eigen3_DIR`: Directory containing `Eigen3Config.cmake`
- **Required:** Yes (REQUIRED)

### CHOLMOD (if `G2O_USE_CHOLMOD=ON`)
- Uses `find_package(CHOLMOD)`
- Requires SuiteSparse with CHOLMOD component

### CSparse (if `G2O_USE_CSPARSE=ON`)
- Uses `find_package(CSparse)`

### OpenGL (if `G2O_USE_OPENGL=ON`)
- Uses `find_package(OpenGL)`
- Prefers GLVND (`OpenGL_GL_PREFERENCE="GLVND"`)

### QGLViewer
- Uses `find_package(QGLViewer)`
- Optional, for GUI applications

### OpenMP (if `G2O_USE_OPENMP=ON`)
- Uses `find_package(OpenMP)`

### spdlog (if `G2O_USE_LOGGING=ON`)
- Uses `find_package(spdlog 1.6)`
- **Required Version:** 1.6+

### benchmark (if `G2O_BUILD_BENCHMARKS=ON`)
- Uses `find_package(benchmark)`

---

## Usage Examples

### Minimal Configuration (Shared Library)
```cmake
cmake .. \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=ON \
  -DG2O_USE_CHOLMOD=ON \
  -DG2O_USE_CSPARSE=ON \
  -DG2O_USE_OPENGL=ON
```

### Full Configuration with Optimizations
```cmake
cmake .. \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DBUILD_SHARED_LIBS=ON \
  -DG2O_USE_CHOLMOD=ON \
  -DG2O_USE_CSPARSE=ON \
  -DG2O_USE_LGPL_LIBS=ON \
  -DG2O_USE_OPENMP=ON \
  -DG2O_USE_OPENGL=ON \
  -DG2O_USE_LOGGING=ON \
  -DG2O_BUILD_SLAM2D_TYPES=ON \
  -DG2O_BUILD_SLAM3D_TYPES=ON \
  -DG2O_BUILD_APPS=ON \
  -DG2O_BUILD_EXAMPLES=ON \
  -DBUILD_WITH_MARCH_NATIVE=OFF \
  -DG2O_FAST_MATH=OFF \
  -DBUILD_UNITTESTS=OFF \
  -DEigen3_DIR=/usr/local/share/eigen3/cmake
```

### Static Library Build (No Plugins)
```cmake
cmake .. \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DG2O_USE_CHOLMOD=ON \
  -DG2O_USE_CSPARSE=OFF \
  -DG2O_USE_LGPL_LIBS=OFF \
  -DG2O_USE_OPENGL=OFF \
  -DG2O_BUILD_APPS=OFF \
  -DG2O_BUILD_EXAMPLES=OFF
```

### Minimal Build (No Visualization)
```cmake
cmake .. \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=ON \
  -DG2O_USE_CHOLMOD=ON \
  -DG2O_USE_CSPARSE=OFF \
  -DG2O_USE_LGPL_LIBS=OFF \
  -DG2O_USE_OPENGL=OFF \
  -DG2O_BUILD_APPS=OFF \
  -DG2O_BUILD_EXAMPLES=OFF \
  -DBUILD_UNITTESTS=OFF
```

---

## Notes and Best Practices

1. **Shared Libraries:** The plugin system requires shared libraries (`BUILD_SHARED_LIBS=ON`).

2. **LGPL License:** If using CSparse (`G2O_USE_CSPARSE=ON`), you must enable `G2O_USE_LGPL_LIBS=ON`. License implications vary for static vs shared libraries.

3. **OpenMP:** Experimental feature with reported slowdowns. Use with caution.

4. **Type Dependencies:** Some types (ICP, SIM3) automatically enable SBA types if needed.

5. **SSE Autodetection:** Automatic SSE detection requires `/proc/cpuinfo` (Linux). On other platforms, manually control SSE via `DO_SSE_AUTODETECT=OFF` and `DISABLE_SSE*` options.

6. **Eigen Version:** g2o requires Eigen3 (via `find_package(Eigen3 REQUIRED NO_MODULE)`).

7. **Build Type:** Default is Release. Debug builds are available but may be slower.

8. **Subdirectory Usage:** When used as subdirectory, `G2O_BUILD_APPS` and `G2O_BUILD_EXAMPLES` default to OFF.

---

## Invalid/Non-existent Flags

The following flags are **NOT** supported by g2o:

- `USE_SYSTEM_EIGEN` - Not used (Eigen is always found via `find_package`)
- `BUILD_CHOLMOD` - g2o does not build CHOLMOD
- `BUILD_CSPARSE` - g2o does not build CSparse
- `WITH_CUDA` - g2o does not support CUDA
- `WITH_OPENCV` - g2o does not use OpenCV
- `G2O_BUILD_CUDA` - Not supported
- `CMAKE_CUDA_ARCHITECTURES` - Not relevant (no CUDA support)

---

## References

- g2o GitHub Repository: https://github.com/RainerKuemmerle/g2o
- CMake Documentation: https://cmake.org/documentation/

---

**Document Version:** 1.0  
**Last Updated:** Generated from g2o latest source code (2024-12-28)

