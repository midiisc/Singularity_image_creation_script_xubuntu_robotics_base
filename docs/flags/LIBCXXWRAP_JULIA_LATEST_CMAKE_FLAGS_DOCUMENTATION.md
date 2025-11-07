# libcxxwrap-julia (JlCxx) - Comprehensive CMake Flags Documentation

**Version:** Latest (git master)  
**Source Repository:** https://github.com/JuliaInterop/libcxxwrap-julia  
**Documentation Generated:** From source code analysis  
**CMake Minimum Version:** 3.5

---

## Table of Contents

1. [Core Build Options](#core-build-options)
2. [Julia Configuration](#julia-configuration)
3. [Testing Options](#testing-options)
4. [Standard CMake Variables](#standard-cmake-variables)
5. [Dependency Find Variables](#dependency-find-variables)
6. [Usage Examples](#usage-examples)

---

## Core Build Options

### `CMAKE_BUILD_TYPE`
- **Type:** `STRING` (Cache variable)
- **Default:** `Release` (recommended)
- **Options:** `Debug`, `Release`, `MinSizeRel`, `RelWithDebInfo`
- **Description:** Specifies the build configuration.
- **Usage:**
  ```cmake
  -DCMAKE_BUILD_TYPE=Release
  ```

### `CMAKE_CXX_STANDARD`
- **Type:** `INTEGER`
- **Default:** `20` (hardcoded)
- **Description:** C++ standard version (libcxxwrap-julia requires C++20).
- **Note:** Hardcoded to C++20 in CMakeLists.txt. Cannot be changed.

---

## Julia Configuration

### `Julia_EXECUTABLE`
- **Type:** `CACHE FILEPATH`
- **Default:** Auto-detected via `find_package(Julia)`
- **Description:** Path to Julia executable.
- **Usage:**
  ```cmake
  -DJulia_EXECUTABLE=/opt/julia/bin/julia
  ```
- **Note:** Required. Auto-detected by `find_package(Julia REQUIRED)`.

### `Julia_INCLUDE_DIR`
- **Type:** `CACHE PATH`
- **Default:** Auto-detected via `find_package(Julia)`
- **Description:** Julia include directory (typically `$JULIA_HOME/include/julia`).
- **Usage:**
  ```cmake
  -DJulia_INCLUDE_DIR=/opt/julia/include/julia
  ```
- **Note:** Auto-detected, but can be manually specified.

### `Julia_LIBRARY_DIR`
- **Type:** `CACHE PATH`
- **Default:** Auto-detected via `find_package(Julia)`
- **Description:** Julia library directory (typically `$JULIA_HOME/lib`).
- **Usage:**
  ```cmake
  -DJulia_LIBRARY_DIR=/opt/julia/lib
  ```
- **Note:** Auto-detected, but can be manually specified.

---

## Testing Options

### `JLCXX_BUILD_EXAMPLES`
- **Type:** `CACHE BOOL`
- **Default:** `ON`
- **Description:** Build the JlCxx examples.
- **Usage:**
  ```cmake
  -DJLCXX_BUILD_EXAMPLES=ON
  ```

### `JLCXX_BUILD_TESTS`
- **Type:** `CACHE BOOL`
- **Default:** `ON`
- **Description:** Build the JlCxx tests.
- **Usage:**
  ```cmake
  -DJLCXX_BUILD_TESTS=OFF
  ```

---

## Installation Options

### `CMAKE_INSTALL_PREFIX`
- **Type:** `CACHE PATH`
- **Default:** Platform-dependent (e.g., `/usr/local` on Unix)
- **Description:** Installation prefix for libcxxwrap-julia.
- **Usage:**
  ```cmake
  -DCMAKE_INSTALL_PREFIX=/opt/libcxxwrap-julia
  ```

### `CMAKE_INSTALL_LIBDIR`
- **Type:** `CACHE STRING`
- **Default:** `lib` (hardcoded)
- **Description:** Library installation directory (relative to `CMAKE_INSTALL_PREFIX`).
- **Note:** Hardcoded to `lib` in CMakeLists.txt.

### `JLCXX_CMAKECONFIG_INSTALL_DIR`
- **Type:** `CACHE STRING`
- **Default:** `${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}`
- **Description:** Install path for `jlcxxConfig.cmake`.
- **Usage:**
  ```cmake
  -DJLCXX_CMAKECONFIG_INSTALL_DIR=lib/cmake/JlCxx
  ```

---

## Julia Artifacts Options

### `OVERRIDES_PATH`
- **Type:** `CACHE FILEPATH`
- **Default:** `$ENV{HOME}/.julia/artifacts/Overrides.toml`
- **Description:** Path to the Overrides file for Julia artifacts.
- **Usage:**
  ```cmake
  -DOVERRIDES_PATH=/path/to/Overrides.toml
  ```
- **Note:** Used for Julia artifact management.

### `OVERRIDE_ROOT`
- **Type:** `CACHE PATH`
- **Default:** `${CMAKE_CURRENT_BINARY_DIR}`
- **Description:** Path to the installation or build directory to use for overrides.
- **Usage:**
  ```cmake
  -DOVERRIDE_ROOT=/opt/libcxxwrap-julia
  ```

### `APPEND_OVERRIDES_TOML`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Append an entry to the Overrides.toml file to make Julia use the libcxxwrap in the current dir.
- **Usage:**
  ```cmake
  -DAPPEND_OVERRIDES_TOML=ON
  ```
- **Note:** Useful for development builds.

---

## Standard CMake Variables

libcxxwrap-julia respects standard CMake variables:

### Build System
- `CMAKE_GENERATOR`: Build system generator (e.g., `Ninja`, `Unix Makefiles`)
- `CMAKE_BUILD_TYPE`: Build configuration
- `CMAKE_INSTALL_PREFIX`: Installation directory

### Compilers
- `CMAKE_C_COMPILER`: C compiler (not used, C++ only)
- `CMAKE_CXX_COMPILER`: C++ compiler
- `CMAKE_CXX_STANDARD`: C++ standard (hardcoded to 20)
- `CMAKE_CXX_STANDARD_REQUIRED`: Require C++20 (hardcoded)

### Compiler Flags
- `CMAKE_CXX_FLAGS`: C++ compiler flags (additional warnings added: `-Wunused-parameter -Wextra -Wreorder -fPIC`)

### RPATH
- `CMAKE_INSTALL_RPATH`: RPATH entries (includes `${CMAKE_INSTALL_PREFIX}/lib` and `${Julia_LIBRARY_DIR}`)
- `CMAKE_INSTALL_RPATH_USE_LINK_PATH`: Set to `TRUE` (hardcoded)
- `CMAKE_MACOSX_RPATH`: Set to `1` (hardcoded) for macOS

---

## Dependency Find Variables

libcxxwrap-julia uses standard CMake `find_package()` for dependencies:

### Julia
- **Required:** Yes (`find_package(Julia REQUIRED)`)
- `Julia_ROOT`: Root directory of Julia installation
- `Julia_EXECUTABLE`: Julia executable path
- `Julia_INCLUDE_DIR`: Julia include directory
- `Julia_LIBRARY_DIR`: Julia library directory

---

## Usage Examples

### Minimal Configuration
```cmake
cmake .. \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/opt/libcxxwrap-julia \
  -DJulia_EXECUTABLE=/opt/julia/bin/julia \
  -DJulia_INCLUDE_DIR=/opt/julia/include/julia \
  -DJulia_LIBRARY_DIR=/opt/julia/lib \
  -DJLCXX_BUILD_EXAMPLES=OFF \
  -DJLCXX_BUILD_TESTS=OFF
```

### Full Configuration with Examples
```cmake
cmake .. \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/opt/libcxxwrap-julia \
  -DJulia_EXECUTABLE=/opt/julia/bin/julia \
  -DJulia_INCLUDE_DIR=/opt/julia/include/julia \
  -DJulia_LIBRARY_DIR=/opt/julia/lib \
  -DJLCXX_BUILD_EXAMPLES=ON \
  -DJLCXX_BUILD_TESTS=ON \
  -DAPPEND_OVERRIDES_TOML=OFF
```

### Development Build
```cmake
cmake .. \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_INSTALL_PREFIX=/opt/libcxxwrap-julia \
  -DJulia_EXECUTABLE=/opt/julia/bin/julia \
  -DJLCXX_BUILD_EXAMPLES=ON \
  -DJLCXX_BUILD_TESTS=ON \
  -DAPPEND_OVERRIDES_TOML=ON
```

---

## Notes and Best Practices

1. **C++20 Required:** libcxxwrap-julia requires C++20 (hardcoded in CMakeLists.txt). Ensure your compiler supports C++20 (GCC 10+, Clang 10+, MSVC 2019+).

2. **Julia Version:** Compatible with Julia 1.0+. Recommended: Latest stable Julia version.

3. **Julia Paths:** Julia paths are usually auto-detected by `find_package(Julia)`. Manually specify if Julia is in a non-standard location.

4. **RPATH:** libcxxwrap-julia sets RPATH to include both its own library directory and Julia's library directory for proper runtime linking.

5. **Installation:** Install to a custom prefix (e.g., `/opt/libcxxwrap-julia`) to avoid conflicts with system packages.

6. **CMake Config:** The generated `JlCxxConfig.cmake` can be used by other projects (e.g., OpenCV) to find libcxxwrap-julia.

7. **Julia Artifacts:** Use `APPEND_OVERRIDES_TOML=ON` for development builds to make Julia use the locally built version.

8. **Platform Notes:**
   - **Windows (MSVC):** Adds `/bigobj` flag automatically.
   - **Windows (MinGW):** Adds `-Wa,-mbig-obj -O2` flags automatically.
   - **macOS:** Sets `CMAKE_MACOSX_RPATH=1` for proper RPATH handling.

---

## Invalid/Non-existent Flags

The following flags are **NOT** supported by libcxxwrap-julia:

- `BUILD_SHARED_LIBS` - Always builds shared library (not configurable)
- `CMAKE_CXX_STANDARD` - Hardcoded to 20 (cannot be changed)
- `WITH_CUDA` - Not applicable
- `WITH_PYTHON` - Not applicable (Julia-only)
- `JLCXX_USE_SYSTEM_JULIA` - Not used (always uses `find_package(Julia)`)

---

## References

- libcxxwrap-julia GitHub Repository: https://github.com/JuliaInterop/libcxxwrap-julia
- Julia Documentation: https://julialang.org/
- CMake Documentation: https://cmake.org/documentation/

---

**Document Version:** 1.0  
**Last Updated:** Generated from libcxxwrap-julia latest source code

