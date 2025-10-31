# GTSAM (Georgia Tech Smoothing and Mapping) 4.2.0 - Comprehensive CMake Flags Documentation

**Version:** 4.2.0  
**Source Repository:** https://github.com/borglab/gtsam  
**Documentation Generated:** From source code analysis  
**CMake Minimum Version:** 3.0

---

## Table of Contents

1. [Core Build Options](#core-build-options)
2. [Pose Representation Options](#pose-representation-options)
3. [Dependency Options](#dependency-options)
4. [Python/Matlab Options](#pythonmatlab-options)
5. [Testing Options](#testing-options)
6. [Performance Options](#performance-options)
7. [Compiler Options](#compiler-options)
8. [Standard CMake Variables](#standard-cmake-variables)
9. [Usage Examples](#usage-examples)

---

## Core Build Options

### `BUILD_SHARED_LIBS`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Build shared gtsam library (`.so`) instead of static (`.a`).
- **Usage:**
  ```cmake
  -DBUILD_SHARED_LIBS=ON
  ```

### `CMAKE_BUILD_TYPE`
- **Type:** `STRING` (Cache variable)
- **Default:** `Release`
- **Options:** `Debug`, `Release`, `RelWithDebInfo`, `MinSizeRel`, `Profiling`, `Timing`
- **Description:** Specifies the build configuration.
- **Usage:**
  ```cmake
  -DCMAKE_BUILD_TYPE=Release
  ```
- **Note:** GTSAM supports custom build types: `Profiling` and `Timing`.

### `GTSAM_BUILD_TYPE_POSTFIXES`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Enable/Disable appending the build type to the name of compiled libraries.
- **Usage:**
  ```cmake
  -DGTSAM_BUILD_TYPE_POSTFIXES=ON
  ```

### `GTSAM_BUILD_UNSTABLE`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON` (if `gtsam_unstable` directory exists)
- **Description:** Enable/Disable libgtsam_unstable (experimental features).
- **Usage:**
  ```cmake
  -DGTSAM_BUILD_UNSTABLE=ON
  ```
- **Note:** Only available if `gtsam_unstable` directory exists (typically in git checkouts).

---

## Pose Representation Options

### `GTSAM_USE_QUATERNIONS`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Enable using an internal Quaternion representation for rotations instead of rotation matrices. If enabled, Rot3::EXPMAP is enforced by default.
- **Usage:**
  ```cmake
  -DGTSAM_USE_QUATERNIONS=OFF
  ```

### `GTSAM_POSE3_EXPMAP`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Enable/Disable using Pose3::EXPMAP as the default mode. If disabled, Pose3::FIRST_ORDER will be used.
- **Usage:**
  ```cmake
  -DGTSAM_POSE3_EXPMAP=ON
  ```
- **Note:** Automatically enables `GTSAM_ROT3_EXPMAP` if set to ON.

### `GTSAM_ROT3_EXPMAP`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Ignore if `GTSAM_USE_QUATERNIONS` is OFF (Rot3::EXPMAP by default). Otherwise, enable Rot3::EXPMAP, or if disabled, use Rot3::CAYLEY.
- **Usage:**
  ```cmake
  -DGTSAM_ROT3_EXPMAP=ON
  ```
- **Note:** Automatically enables `GTSAM_POSE3_EXPMAP` if set to ON.

---

## Dependency Options

### `GTSAM_USE_SYSTEM_EIGEN`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Find and use system-installed Eigen. If 'off', use the one bundled with GTSAM.
- **Usage:**
  ```cmake
  -DGTSAM_USE_SYSTEM_EIGEN=ON
  ```

### `GTSAM_WITH_EIGEN_UNSUPPORTED`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Install Eigen's unsupported modules.
- **Usage:**
  ```cmake
  -DGTSAM_WITH_EIGEN_UNSUPPORTED=ON
  ```
- **Note:** Only relevant when `GTSAM_USE_SYSTEM_EIGEN=OFF`.

### `GTSAM_USE_SYSTEM_METIS`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Find and use system-installed libmetis. If 'off', use the one bundled with GTSAM.
- **Usage:**
  ```cmake
  -DGTSAM_USE_SYSTEM_METIS=ON
  ```

### `GTSAM_BUILD_METIS_EXECUTABLES`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Build metis library executables.
- **Usage:**
  ```cmake
  -DGTSAM_BUILD_METIS_EXECUTABLES=ON
  ```
- **Note:** Only relevant when `GTSAM_USE_SYSTEM_METIS=OFF`.

### `GTSAM_WITH_TBB`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Use Intel Threaded Building Blocks (TBB) if available.
- **Usage:**
  ```cmake
  -DGTSAM_WITH_TBB=ON
  ```

### `GTSAM_WITH_EIGEN_MKL`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Eigen will use Intel MKL if available.
- **Usage:**
  ```cmake
  -DGTSAM_WITH_EIGEN_MKL=ON
  ```

### `GTSAM_WITH_EIGEN_MKL_OPENMP`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Eigen, when using Intel MKL, will also use OpenMP for multithreading if available.
- **Usage:**
  ```cmake
  -DGTSAM_WITH_EIGEN_MKL_OPENMP=ON
  ```
- **Note:** Only relevant when `GTSAM_WITH_EIGEN_MKL=ON`.

### `GTSAM_DISABLE_NEW_TIMERS`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Disables using Boost.chrono for timing.
- **Usage:**
  ```cmake
  -DGTSAM_DISABLE_NEW_TIMERS=ON
  ```

---

## Python/Matlab Options

### `GTSAM_BUILD_PYTHON`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Enable/Disable building & installation of Python module with pybind11.
- **Usage:**
  ```cmake
  -DGTSAM_BUILD_PYTHON=ON
  ```
- **Note:** Requires pybind11. Requires Python >= 3.6.

### `GTSAM_PYTHON_VERSION`
- **Type:** `CACHE STRING`
- **Default:** `"Default"`
- **Description:** The version of Python to build the wrappers against (auto-detected if "Default").
- **Usage:**
  ```cmake
  -DGTSAM_PYTHON_VERSION="3.12"
  ```

### `GTSAM_INSTALL_MATLAB_TOOLBOX`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Enable/Disable installation of matlab toolbox.
- **Usage:**
  ```cmake
  -DGTSAM_INSTALL_MATLAB_TOOLBOX=ON
  ```

### `GTSAM_UNSTABLE_BUILD_PYTHON`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Enable/Disable Python wrapper for libgtsam_unstable.
- **Usage:**
  ```cmake
  -DGTSAM_UNSTABLE_BUILD_PYTHON=ON
  ```
- **Note:** Only available if `GTSAM_BUILD_UNSTABLE=ON`.

### `GTSAM_UNSTABLE_INSTALL_MATLAB_TOOLBOX`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Enable/Disable MATLAB wrapper for libgtsam_unstable.
- **Usage:**
  ```cmake
  -DGTSAM_UNSTABLE_INSTALL_MATLAB_TOOLBOX=OFF
  ```
- **Note:** Only available if `GTSAM_BUILD_UNSTABLE=ON`.

---

## Testing Options

### `GTSAM_BUILD_TESTS`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Enable/Disable building of tests.
- **Usage:**
  ```cmake
  -DGTSAM_BUILD_TESTS=ON
  ```

### `GTSAM_SINGLE_TEST_EXE`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON` (MSVC/Xcode), `OFF` (others)
- **Description:** Combine unit tests into single executable (faster compile).
- **Usage:**
  ```cmake
  -DGTSAM_SINGLE_TEST_EXE=ON
  ```
- **Note:** Advanced option (hidden by default).

### `GTSAM_BUILD_EXAMPLES_ALWAYS`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Build examples with 'make all' (build with 'make examples' if not).
- **Usage:**
  ```cmake
  -DGTSAM_BUILD_EXAMPLES_ALWAYS=ON
  ```

### `GTSAM_BUILD_TIMING_ALWAYS`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Build timing scripts with 'make all' (build with 'make timing' if not).
- **Usage:**
  ```cmake
  -DGTSAM_BUILD_TIMING_ALWAYS=ON
  ```

---

## Performance Options

### `GTSAM_SUPPORT_NESTED_DISSECTION`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Support Metis-based nested dissection.
- **Usage:**
  ```cmake
  -DGTSAM_SUPPORT_NESTED_DISSECTION=ON
  ```
- **Note:** Requires METIS.

### `GTSAM_TANGENT_PREINTEGRATION`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Use new ImuFactor with integration on tangent space.
- **Usage:**
  ```cmake
  -DGTSAM_TANGENT_PREINTEGRATION=ON
  ```

### `GTSAM_BUILD_WITH_MARCH_NATIVE`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Enable/Disable building with all instructions supported by native architecture (binary may not be portable!).
- **Usage:**
  ```cmake
  -DGTSAM_BUILD_WITH_MARCH_NATIVE=OFF
  ```

### `GTSAM_BUILD_WITH_CCACHE`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON` (if not MSVC/Xcode)
- **Description:** Use ccache compiler cache.
- **Usage:**
  ```cmake
  -DGTSAM_BUILD_WITH_CCACHE=ON
  ```
- **Note:** Not available on MSVC/Xcode.

### `GTSAM_DEFAULT_ALLOCATOR`
- **Type:** `CACHE STRING`
- **Description:** Default allocator (TBB, Perftools, or standard).
- **Note:** Advanced option, auto-detected based on available libraries.

---

## Other Options

### `GTSAM_ENABLE_CONSISTENCY_CHECKS`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Enable/Disable expensive consistency checks.
- **Usage:**
  ```cmake
  -DGTSAM_ENABLE_CONSISTENCY_CHECKS=OFF
  ```

### `GTSAM_THROW_CHEIRALITY_EXCEPTION`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Throw exception when a triangulated point is behind a camera.
- **Usage:**
  ```cmake
  -DGTSAM_THROW_CHEIRALITY_EXCEPTION=ON
  ```

### `GTSAM_ALLOW_DEPRECATED_SINCE_V42`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON`
- **Description:** Allow use of methods/functions deprecated in GTSAM 4.2.
- **Usage:**
  ```cmake
  -DGTSAM_ALLOW_DEPRECATED_SINCE_V42=ON
  ```

### `GTSAM_SLOW_BUT_CORRECT_BETWEENFACTOR`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Use the slower but correct version of BetweenFactor.
- **Usage:**
  ```cmake
  -DGTSAM_SLOW_BUT_CORRECT_BETWEENFACTOR=OFF
  ```

---

## Compiler Options (Advanced Cache Variables)

GTSAM provides extensive control over compiler flags via cache variables:

### Build Type-Specific Flags

**Debug:**
- `GTSAM_COMPILE_OPTIONS_PRIVATE_DEBUG`: Private compiler flags for Debug
- `GTSAM_COMPILE_DEFINITIONS_PRIVATE_DEBUG`: Private preprocessor macros (default: `_DEBUG;EIGEN_INITIALIZE_MATRICES_BY_NAN`)

**Release:**
- `GTSAM_COMPILE_OPTIONS_PRIVATE_RELEASE`: Private compiler flags for Release (default: `-O3` on Unix, `/O2` on MSVC)
- `GTSAM_COMPILE_DEFINITIONS_PRIVATE_RELEASE`: Private preprocessor macros (default: `NDEBUG`)

**RelWithDebInfo:**
- `GTSAM_COMPILE_OPTIONS_PRIVATE_RELWITHDEBINFO`: Private compiler flags (default: `-g -O3` on Unix)
- `GTSAM_COMPILE_DEFINITIONS_PRIVATE_RELWITHDEBINFO`: Private preprocessor macros (default: `NDEBUG`)

**Profiling:**
- `GTSAM_COMPILE_OPTIONS_PRIVATE_PROFILING`: Private compiler flags (default: `-O3` on Unix)
- `GTSAM_COMPILE_DEFINITIONS_PRIVATE_PROFILING`: Private preprocessor macros (default: `NDEBUG`)

**Timing:**
- `GTSAM_COMPILE_OPTIONS_PRIVATE_TIMING`: Private compiler flags (default: `-g -O3` on Unix)
- `GTSAM_COMPILE_DEFINITIONS_PRIVATE_TIMING`: Private preprocessor macros (default: `NDEBUG;ENABLE_TIMING`)

### Public Flags (Exported to User Projects)

- `GTSAM_COMPILE_OPTIONS_PUBLIC`: Public compiler flags for all configurations
- `GTSAM_COMPILE_OPTIONS_PUBLIC_<BUILD_TYPE>`: Public compiler flags per build type
- `GTSAM_COMPILE_DEFINITIONS_PUBLIC`: Public preprocessor macros for all configurations
- `GTSAM_COMPILE_DEFINITIONS_PUBLIC_<BUILD_TYPE>`: Public preprocessor macros per build type

### C++ Standard

- `GTSAM_COMPILE_FEATURES_PUBLIC`: CMake compile features property (default: `"cxx_std_11"`)

---

## Standard CMake Variables

GTSAM respects standard CMake variables:

### Build System
- `CMAKE_GENERATOR`: Build system generator
- `CMAKE_BUILD_TYPE`: Build configuration
- `CMAKE_INSTALL_PREFIX`: Installation directory

### Compilers
- `CMAKE_C_COMPILER`: C compiler
- `CMAKE_CXX_COMPILER`: C++ compiler
- `CMAKE_CXX_STANDARD`: C++ standard (GTSAM supports C++11+)
- `CMAKE_CXX_STANDARD_REQUIRED`: Require C++ standard

### RPATH
- `CMAKE_INSTALL_RPATH`: RPATH entries for installed libraries
- `CMAKE_INSTALL_RPATH_USE_LINK_PATH`: Use linker path as RPATH

---

## Dependency Find Variables

GTSAM uses standard CMake `find_package()` for dependencies:

### Eigen3
- `Eigen3_DIR`: Directory containing `Eigen3Config.cmake`
- **Note:** If `GTSAM_USE_SYSTEM_EIGEN=OFF`, uses bundled Eigen.

### TBB (if `GTSAM_WITH_TBB=ON`)
- Uses `find_package(TBB)`
- Custom find module in `cmake/FindTBB.cmake`

### METIS (if `GTSAM_SUPPORT_NESTED_DISSECTION=ON`)
- Uses `find_package(METIS)`
- If `GTSAM_USE_SYSTEM_METIS=OFF`, uses bundled METIS.

### MKL (if `GTSAM_WITH_EIGEN_MKL=ON`)
- Uses `find_package(MKL)`
- Custom find module in `cmake/FindMKL.cmake`

### Boost
- Uses `find_package(Boost)` (required)

### Python (if `GTSAM_BUILD_PYTHON=ON`)
- Uses `find_package(Python3 COMPONENTS Interpreter Development)` (CMake 3.12+) or legacy `find_package(PythonInterp)` + `find_package(PythonLibs)`
- **Required Version:** >= 3.6

---

## Usage Examples

### Minimal Configuration (Shared Library)
```cmake
cmake .. \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=ON \
  -DGTSAM_USE_SYSTEM_EIGEN=ON \
  -DGTSAM_WITH_TBB=ON
```

### Full Configuration with Python
```cmake
cmake .. \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DBUILD_SHARED_LIBS=ON \
  -DGTSAM_USE_SYSTEM_EIGEN=ON \
  -DGTSAM_USE_SYSTEM_METIS=ON \
  -DGTSAM_WITH_TBB=ON \
  -DGTSAM_BUILD_PYTHON=ON \
  -DGTSAM_PYTHON_VERSION=${SYSTEM_PYTHON_VER} \
  -DGTSAM_BUILD_UNSTABLE=ON \
  -DGTSAM_POSE3_EXPMAP=ON \
  -DGTSAM_ROT3_EXPMAP=ON \
  -DGTSAM_BUILD_TESTS=OFF \
  -DEigen3_DIR=/usr/local/share/eigen3/cmake
```

### Static Library Build
```cmake
cmake .. \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DGTSAM_USE_SYSTEM_EIGEN=ON \
  -DGTSAM_WITH_TBB=ON \
  -DGTSAM_BUILD_PYTHON=OFF \
  -DGTSAM_BUILD_TESTS=OFF
```

---

## Notes and Best Practices

1. **Pose Representation:** `GTSAM_POSE3_EXPMAP` and `GTSAM_ROT3_EXPMAP` are interdependent (enabling one enables the other).

2. **System vs Bundled:** Prefer system libraries (`GTSAM_USE_SYSTEM_EIGEN`, `GTSAM_USE_SYSTEM_METIS`) for better compatibility and updates.

3. **Python Version:** Set `GTSAM_PYTHON_VERSION` explicitly or use "Default" for auto-detection.

4. **TBB:** Enabled by default for better multithreading performance.

5. **Build Types:** GTSAM supports custom build types (`Profiling`, `Timing`) in addition to standard ones.

6. **Unstable Features:** `GTSAM_BUILD_UNSTABLE` requires the `gtsam_unstable` directory (typically in git checkouts, not release tarballs).

7. **C++ Standard:** GTSAM requires C++11 minimum. Ensure your compiler supports it.

---

## Invalid/Non-existent Flags

The following flags are **NOT** supported by GTSAM 4.2.0:

- `USE_CUDA` - GTSAM does not support CUDA
- `BUILD_CUDA` - Not supported
- `CMAKE_CUDA_ARCHITECTURES` - Not relevant
- `GTSAM_WITH_OPENCV` - GTSAM does not use OpenCV
- `GTSAM_WITH_CERES` - GTSAM does not use Ceres Solver

---

## References

- GTSAM GitHub Repository: https://github.com/borglab/gtsam
- GTSAM Documentation: https://gtsam.org/
- CMake Documentation: https://cmake.org/documentation/

---

**Document Version:** 1.0  
**Last Updated:** Generated from GTSAM 4.2.0 source code

