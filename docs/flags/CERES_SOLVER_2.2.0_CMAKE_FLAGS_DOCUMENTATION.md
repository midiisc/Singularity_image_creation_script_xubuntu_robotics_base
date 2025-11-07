# Ceres Solver 2.2.0 - Comprehensive CMake Flags Documentation

**Version:** 2.2.0  
**Source Repository:** https://github.com/ceres-solver/ceres-solver  
**Documentation Generated:** From source code analysis  
**CMake Minimum Version:** 3.16...3.27

---

## Table of Contents

1. [Core Build Options](#core-build-options)
2. [Dependency Options](#dependency-options)
3. [Linear Algebra Backends](#linear-algebra-backends)
4. [Sparse Linear Algebra](#sparse-linear-algebra)
5. [CUDA Options](#cuda-options)
6. [Testing and Examples](#testing-and-examples)
7. [Compilation Options](#compilation-options)
8. [Installation Options](#installation-options)
9. [Platform-Specific Options](#platform-specific-options)
10. [Standard CMake Variables](#standard-cmake-variables)
11. [Dependency Find Variables](#dependency-find-variables)
12. [Cache Variables](#cache-variables)
13. [Usage Examples](#usage-examples)

---

## Core Build Options

### `BUILD_SHARED_LIBS`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF` (builds static library)
- **Description:** Controls whether Ceres is built as a shared library (`.so`) or static library (`.a`).
- **Usage:**
  ```cmake
  -DBUILD_SHARED_LIBS=ON
  ```
- **Note:** Static builds are default. Set to ON for shared library builds.

### `CMAKE_BUILD_TYPE`
- **Type:** `STRING` (Cache variable)
- **Default:** `Release` (if not specified)
- **Options:** `None`, `Debug`, `Release`, `RelWithDebInfo`, `MinSizeRel`
- **Description:** Specifies the build configuration. Debug builds have terrible performance.
- **Usage:**
  ```cmake
  -DCMAKE_BUILD_TYPE=Release
  ```
- **Warning:** Debug builds explicitly warn about terrible performance.

### `SCHUR_SPECIALIZATIONS`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Enables fixed-size Schur complement specializations for better performance.
- **Usage:**
  ```cmake
  -DSCHUR_SPECIALIZATIONS=ON
  ```
- **Note:** If compile time, binary size, or compiler performance is an issue, you may consider disabling this.

### `CUSTOM_BLAS`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Use handcoded BLAS routines (usually faster) instead of Eigen.
- **Usage:**
  ```cmake
  -DCUSTOM_BLAS=ON
  ```
- **Note:** Disabling this uses Eigen for BLAS operations.

---

## Dependency Options

### `MINIGLOG`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Use a stripped down version of glog instead of system glog.
- **Usage:**
  ```cmake
  -DMINIGLOG=ON
  ```
- **Note:** If enabled, Ceres compiles a minimal glog substitute into the library. If disabled, requires system glog via `find_package(Glog)`.

### `MINIGLOG_MAX_LOG_LEVEL`
- **Type:** `CACHE STRING`
- **Default:** `2`
- **Description:** Maximum message severity level when using miniglog (only active when `MINIGLOG=ON`).
- **Usage:**
  ```cmake
  -DMINIGLOG_MAX_LOG_LEVEL=2
  ```
- **Note:** Only relevant when `MINIGLOG=ON`.

### `GFLAGS`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Enable Google Flags support.
- **Usage:**
  ```cmake
  -DGFLAGS=ON
  ```
- **Note:** If disabled, no tests or tools will be built. Requires gflags 2.2.0+.

---

## Linear Algebra Backends

### `LAPACK`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Enable use of LAPACK directly within Ceres for dense linear algebra.
- **Usage:**
  ```cmake
  -DLAPACK=ON
  ```
- **Note:** CMake will use `find_package(LAPACK)` to locate LAPACK libraries. If not found, automatically disabled.
- **CMake Variables:** Uses standard CMake FindBLAS/FindLAPACK variables:
  - `BLA_VENDOR`: Vendor selection (e.g., `OpenBLAS`, `Generic`)
  - `LAPACK_LIBRARIES`: Direct library paths (optional)

### `USE_CUDA`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Enable use of CUDA linear algebra solvers.
- **Usage:**
  ```cmake
  -DUSE_CUDA=ON
  ```
- **Note:** Requires CUDA toolkit. Uses `find_package(CUDAToolkit)` (CMake 3.17+) or legacy `FindCUDA` (CMake < 3.17).
- **CUDA Architecture:** Automatically sets `CMAKE_CUDA_ARCHITECTURES` to `"50;60;70;80"` for Maxwell, Pascal, Volta, Turing, and Ampere GPUs (CMake 3.18+).

---

## Sparse Linear Algebra

### `SUITESPARSE`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Enable SuiteSparse support for sparse linear algebra.
- **Usage:**
  ```cmake
  -DSUITESPARSE=ON
  ```
- **Note:** Requires SuiteSparse 4.5.6+ with CHOLMOD and SPQR components. Optional METIS component for partitioning.
- **Dependencies:** Automatically searches for SuiteSparse via `find_package(SuiteSparse)`.

### `EIGENSPARSE`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Enable Eigen as a sparse linear algebra library for solving nonlinear least squares problems.
- **Usage:**
  ```cmake
  -DEIGENSPARSE=ON
  ```
- **Note:** Disabling this does not affect the covariance estimation algorithm which can still use `EIGEN_SPARSE_QR`.

### `EIGENMETIS`
- **Type:** `CMAKE_DEPENDENT_OPTION`
- **Default:** `ON` (if `EIGENSPARSE=ON`)
- **Description:** Enable Eigen METIS support for sparse matrix ordering.
- **Usage:**
  ```cmake
  -DEIGENMETIS=ON
  ```
- **Note:** Only available if `EIGENSPARSE=ON`. Requires METIS library via `find_package(METIS)`.

### `ACCELERATESPARSE`
- **Type:** `OPTION` (ON/OFF, macOS/iOS only)
- **Default:** `ON` (on Apple platforms)
- **Description:** Enable use of sparse solvers in Apple's Accelerate framework.
- **Usage:**
  ```cmake
  -DACCELERATESPARSE=ON
  ```
- **Platform:** macOS and iOS only.

---

## CUDA Options

### `CMAKE_CUDA_ARCHITECTURES`
- **Type:** `STRING`
- **Default:** `"50;60;70;80"` (CMake 3.18+, auto-set by Ceres)
- **Description:** CUDA compute architectures to target (e.g., Maxwell 50, Pascal 60, Volta 70, Turing 75, Ampere 80).
- **Usage:**
  ```cmake
  -DCMAKE_CUDA_ARCHITECTURES="86;89;90"  # For A6000, RTX 30xx, etc.
  ```
- **Note:** Only relevant when `USE_CUDA=ON`. Ceres automatically sets this for CMake 3.18+.

### `CUDA_TOOLKIT_ROOT_DIR`
- **Type:** `PATH` (detected via FindCUDAToolkit)
- **Description:** Root directory of CUDA toolkit installation.
- **Usage:**
  ```cmake
  -DCUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda-12.6
  ```
- **Note:** Usually auto-detected. Can be manually specified if CMake cannot find CUDA.

### `CMAKE_CUDA_RUNTIME_LIBRARY`
- **Type:** `STRING`
- **Default:** `NONE` (for Ceres)
- **Description:** CUDA runtime library linkage mode.
- **Note:** Ceres sets this to `NONE` internally.

---

## Testing and Examples

### `BUILD_TESTING`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Enable building Ceres unit tests.
- **Usage:**
  ```cmake
  -DBUILD_TESTING=OFF
  ```
- **Note:** Tests require gflags. If `GFLAGS=OFF`, tests cannot be built.

### `BUILD_EXAMPLES`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Build example programs.
- **Usage:**
  ```cmake
  -DBUILD_EXAMPLES=OFF
  ```

### `BUILD_BENCHMARKS`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Build Ceres benchmarking suite.
- **Usage:**
  ```cmake
  -DBUILD_BENCHMARKS=OFF
  ```
- **Note:** Requires Google benchmark library 1.3+. If not found, automatically disabled.

### `BUILD_DOCUMENTATION`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Build User's Guide (HTML documentation).
- **Usage:**
  ```cmake
  -DBUILD_DOCUMENTATION=ON
  ```
- **Note:** Requires Sphinx with `sphinx_rtd_theme` component.

---

## Compilation Options

### `CMAKE_CXX_STANDARD`
- **Type:** `STRING`
- **Description:** C++ standard version (Ceres requires C++14 minimum, but works with C++17/C++20).
- **Usage:**
  ```cmake
  -DCMAKE_CXX_STANDARD=17
  ```

### `CMAKE_CXX_STANDARD_REQUIRED`
- **Type:** `BOOL`
- **Description:** Require the specified C++ standard (recommended: ON).
- **Usage:**
  ```cmake
  -DCMAKE_CXX_STANDARD_REQUIRED=ON
  ```

### `SANITIZERS`
- **Type:** `CACHE STRING`
- **Default:** `""` (empty)
- **Description:** Semicolon-separated list of sanitizers to use (e.g., `address`, `memory`, `thread`).
- **Usage:**
  ```cmake
  -DSANITIZERS="address;undefined"
  ```
- **Note:** Useful for debugging. May significantly slow down builds.

### `CMAKE_POSITION_INDEPENDENT_CODE`
- **Type:** `BOOL`
- **Default:** `ON` (hardcoded in Ceres)
- **Description:** Always build position-independent code (PIC), even for static libraries.
- **Note:** This is hardcoded to ON in Ceres CMakeLists.txt to allow shared libraries to link against static Ceres.

---

## Installation Options

### `CMAKE_INSTALL_PREFIX`
- **Type:** `PATH`
- **Default:** Platform-dependent (e.g., `/usr/local` on Unix)
- **Description:** Installation prefix for Ceres.
- **Usage:**
  ```cmake
  -DCMAKE_INSTALL_PREFIX=/usr/local
  ```

### `PROVIDE_UNINSTALL_TARGET`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Add a custom `uninstall` target to ease removal of installed targets.
- **Usage:**
  ```cmake
  -DPROVIDE_UNINSTALL_TARGET=ON
  ```

### `EXPORT_BUILD_DIR`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Export build directory using CMake (enables external use without install).
- **Usage:**
  ```cmake
  -DEXPORT_BUILD_DIR=ON
  ```
- **Note:** Allows using Ceres from build directory without installation via CMake package registry.

---

## Platform-Specific Options

### `ENABLE_BITCODE` (iOS/macOS)
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Enable bitcode for iOS builds (disables inline optimizations for Eigen).
- **Usage:**
  ```cmake
  -DENABLE_BITCODE=ON
  ```
- **Note:** iOS/macOS only. Cannot be used with Eigen optimizations.

### `ANDROID_STRIP_DEBUG_SYMBOLS` (Android)
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Strip debug symbols from Android builds (reduces file sizes).
- **Usage:**
  ```cmake
  -DANDROID_STRIP_DEBUG_SYMBOLS=ON
  ```
- **Note:** Android only. Prevents +200MB library file sizes.

---

## Standard CMake Variables

Ceres respects standard CMake variables:

### Build System
- `CMAKE_GENERATOR`: Build system generator (e.g., `Ninja`, `Unix Makefiles`)
- `CMAKE_BUILD_TYPE`: Build configuration (`Release`, `Debug`, etc.)
- `CMAKE_INSTALL_PREFIX`: Installation directory

### Compilers
- `CMAKE_C_COMPILER`: C compiler
- `CMAKE_CXX_COMPILER`: C++ compiler
- `CMAKE_CUDA_COMPILER`: CUDA compiler (when `USE_CUDA=ON`)
- `CMAKE_C_COMPILER_WORKS`: Skip compiler test
- `CMAKE_CXX_COMPILER_WORKS`: Skip compiler test

### Compiler Flags
- `CMAKE_C_FLAGS`: C compiler flags
- `CMAKE_CXX_FLAGS`: C++ compiler flags
- `CMAKE_CUDA_FLAGS`: CUDA compiler flags
- `CMAKE_EXE_LINKER_FLAGS`: Executable linker flags
- `CMAKE_SHARED_LINKER_FLAGS`: Shared library linker flags
- `CMAKE_MODULE_LINKER_FLAGS`: Module linker flags

### RPATH
- `CMAKE_INSTALL_RPATH`: RPATH entries for installed libraries
- `CMAKE_INSTALL_RPATH_USE_LINK_PATH`: Use linker path as RPATH

---

## Dependency Find Variables

Ceres uses standard CMake `find_package()` for dependencies. These variables can help CMake locate dependencies:

### Eigen3
- `Eigen3_DIR`: Directory containing `Eigen3Config.cmake`
- **Required Version:** 3.3+ (3.3.4+ on aarch64)

### glog (if `MINIGLOG=OFF`)
- `glog_DIR`: Directory containing `glogConfig.cmake` (CMake-built glog)
- `GLOG_INCLUDE_DIR`: Include directory for glog
- `GLOG_LIBRARY`: Library file for glog

### gflags (if `GFLAGS=ON`)
- `gflags_DIR`: Directory containing `gflagsConfig.cmake`
- **Required Version:** 2.2.0+

### LAPACK (if `LAPACK=ON`)
- `BLA_VENDOR`: BLAS/LAPACK vendor (e.g., `OpenBLAS`, `Generic`)
- `LAPACK_LIBRARIES`: Direct specification of LAPACK libraries (optional)

### SuiteSparse (if `SUITESPARSE=ON`)
- `SuiteSparse_DIR`: Directory containing `SuiteSparseConfig.cmake`
- **Required Version:** 4.5.6+
- **Required Components:** CHOLMOD, SPQR
- **Optional Components:** Partition (METIS)

### METIS (if `EIGENMETIS=ON`)
- `METIS_DIR`: Directory containing `METISConfig.cmake`

### CUDA (if `USE_CUDA=ON`)
- `CUDAToolkit_ROOT`: Root directory of CUDA toolkit (CMake 3.17+)
- `CUDA_TOOLKIT_ROOT_DIR`: Root directory (legacy, CMake < 3.17)

### benchmark (if `BUILD_BENCHMARKS=ON`)
- `benchmark_DIR`: Directory containing `benchmarkConfig.cmake`
- **Required Version:** 1.3+

---

## Cache Variables

### Advanced Variables (Hidden by default)
Ceres marks several dependency search variables as advanced (hidden from CMake GUI by default):

- `GLOG_INCLUDE_DIR`
- `GLOG_LIBRARY`
- `AccelerateSparse_INCLUDE_DIR`
- `AccelerateSparse_LIBRARY`
- `benchmark_DIR`

---

## Usage Examples

### Minimal Configuration (Shared Library)
```cmake
cmake .. \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=ON \
  -DMINIGLOG=OFF \
  -DGFLAGS=ON \
  -DUSE_CUDA=ON
```

### Full Configuration with System Libraries
```cmake
cmake .. \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DBUILD_SHARED_LIBS=ON \
  -DMINIGLOG=OFF \
  -DGFLAGS=ON \
  -DLAPACK=ON \
  -DBLA_VENDOR=OpenBLAS \
  -DUSE_CUDA=ON \
  -DCMAKE_CUDA_ARCHITECTURES="86;89;90" \
  -DSUITESPARSE=ON \
  -DEIGENSPARSE=ON \
  -DEIGENMETIS=ON \
  -DSCHUR_SPECIALIZATIONS=ON \
  -DCUSTOM_BLAS=ON \
  -DBUILD_TESTING=OFF \
  -DBUILD_EXAMPLES=OFF \
  -DBUILD_BENCHMARKS=OFF \
  -DEigen3_DIR=/usr/local/share/eigen3/cmake \
  -DCeres_DIR=/usr/local/lib/cmake/Ceres
```

### Static Library Build with Miniglog
```cmake
cmake .. \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DMINIGLOG=ON \
  -DGFLAGS=OFF \
  -DLAPACK=ON \
  -DUSE_CUDA=OFF \
  -DBUILD_TESTING=OFF
```

### Debug Build with Sanitizers
```cmake
cmake .. \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Debug \
  -DSANITIZERS="address;undefined" \
  -DBUILD_TESTING=ON \
  -DGFLAGS=ON
```

---

## Notes and Best Practices

1. **LAPACK Detection:** Ceres uses CMake's `find_package(LAPACK)`. Set `BLA_VENDOR=OpenBLAS` to prefer OpenBLAS over generic LAPACK.

2. **CUDA Architectures:** For modern GPUs (RTX 30xx, A6000, etc.), set `CMAKE_CUDA_ARCHITECTURES="86;89;90"` to target compute capabilities 8.6, 8.9, and 9.0.

3. **Eigen Version:** Ceres requires Eigen 3.3+, and exactly the same Eigen version must be used when linking against Ceres (to avoid ODR violations).

4. **glog vs miniglog:** System glog provides better logging features but requires installation. Miniglog is embedded but limited.

5. **Sparse Libraries:** At least one sparse library (SuiteSparse, EigenSparse, or AccelerateSparse) should be enabled, or sparse solvers will be unavailable.

6. **Build Performance:** Debug builds have terrible performance. Always use `Release` builds for production.

7. **iOS/macOS:** `ENABLE_BITCODE` and Eigen optimizations are mutually exclusive on Clang.

---

## Invalid/Non-existent Flags

The following flags are **NOT** supported by Ceres Solver 2.2.0:

- `USE_SYSTEM_BLAS` - Use `LAPACK=ON` and `BLA_VENDOR` instead
- `USE_SYSTEM_LAPACK` - Use `LAPACK=ON` instead
- `BUILD_BLAS` - Ceres does not build BLAS
- `BUILD_LAPACK` - Ceres does not build LAPACK
- `OpenBLAS_LIB` - Use `LAPACK_LIBRARIES` or `BLA_VENDOR=OpenBLAS`
- `OpenBLAS_INCLUDE_DIR` - Not used by Ceres
- `BLAS_LIBRARIES` - Use `LAPACK_LIBRARIES` (LAPACK includes BLAS)
- `LAPACK_LIBRARY` - Use `LAPACK_LIBRARIES` (plural) if needed
- `CMAKE_PREFIX_PATH` - Standard CMake variable, use for dependency hints
- `CMAKE_LIBRARY_PATH` - Standard CMake variable, use for library search
- `CMAKE_INCLUDE_PATH` - Standard CMake variable, use for include search

---

## References

- Ceres Solver Documentation: http://ceres-solver.org/
- GitHub Repository: https://github.com/ceres-solver/ceres-solver
- CMake Documentation: https://cmake.org/documentation/

---

**Document Version:** 1.0  
**Last Updated:** Generated from Ceres Solver 2.2.0 source code

