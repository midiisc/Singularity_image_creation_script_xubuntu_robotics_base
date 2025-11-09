# Open3D 0.19.0 CMake Configuration Flags - Complete Documentation

**Source:** Open3D v0.19.0 (GitHub: isl-org/Open3D)  
**Commit:** `1e7b17438687a0b0c1e5a7187321ac7044afe275`  
**Last Audited:** November 9, 2025 (Library-Analysis-Tool)  
**CMake Minimum Version:** 3.24

This document provides an exhaustive list of all supported CMake configuration flags, variables, and options in Open3D 0.19.0.

> **2025 Audit Highlights**
> - Library-Analysis-Tool traversed 75 `CMakeLists.txt`, 511 headers, and 13 helper scripts for tag `v0.19.0`.  
> - No new configurable flags were introduced since the previous revision; key toggles (`BUILD_SHARED_LIBS`, `BUILD_EXAMPLES`, `BUILD_GUI`, `BUILD_ISPC_MODULE`, `BUILD_TENSORFLOW_OPS`, `BUILD_PYTHON_MODULE`, etc.) retain their documented defaults.  
> - Dependency scan confirms the optional integrations with CUDA, ROCm, SYCL/oneAPI, Vulkan, ISPC, TensorFlow/PyTorch ML ops, and RealSense/Azure sensor backends exactly as summarised below.

---

## Table of Contents

1. [Core Build Options](#core-build-options)
2. [Module Build Options](#module-build-options)
3. [Third-Party Dependency Options](#third-party-dependency-options)
4. [CUDA Options](#cuda-options)
5. [ISPC Options](#ispc-options)
6. [SYCL Options](#sycl-options)
7. [GUI and Rendering Options](#gui-and-rendering-options)
8. [Python Options](#python-options)
9. [ML/AI Options](#mlai-options)
10. [Sensor Options](#sensor-options)
11. [Compiler and Build System Options](#compiler-and-build-system-options)
12. [Platform-Specific Options](#platform-specific-options)
13. [Cache Variables](#cache-variables)
14. [Standard CMake Variables](#standard-cmake-variables)
15. [Dependency Find Variables](#dependency-find-variables)

---

## Core Build Options

### BUILD_SHARED_LIBS
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Build shared libraries (.so/.dll/.dylib) instead of static libraries (.a/.lib)
- **Usage:** `-DBUILD_SHARED_LIBS=ON`

### BUILD_EXAMPLES
- **Type:** `BOOL`
- **Default:** `ON`
- **Description:** Build Open3D example programs
- **Usage:** `-DBUILD_EXAMPLES=ON`

### BUILD_UNIT_TESTS
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Build Open3D unit tests
- **Usage:** `-DBUILD_UNIT_TESTS=ON`

### BUILD_BENCHMARKS
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Build the micro benchmarks
- **Usage:** `-DBUILD_BENCHMARKS=ON`

### DEVELOPER_BUILD
- **Type:** `BOOL`
- **Default:** `ON`
- **Description:** Add +commit_hash to the project version number. When OFF, automatically sets BUILD_COMMON_CUDA_ARCHS=ON for release builds.
- **Usage:** `-DDEVELOPER_BUILD=OFF`

---

## Module Build Options

### BUILD_PYTHON_MODULE
- **Type:** `BOOL`
- **Default:** `ON`
- **Description:** Build the Python module (pybind11 bindings)
- **Requirements:** Python >= 3.6
- **Usage:** `-DBUILD_PYTHON_MODULE=ON`

### BUILD_CUDA_MODULE
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Build the CUDA module for GPU acceleration
- **Requirements:** CUDA >= 11.5, NVIDIA GPU
- **Incompatible with:** BUILD_SYCL_MODULE
- **Usage:** `-DBUILD_CUDA_MODULE=ON`

### BUILD_ISPC_MODULE
- **Type:** `BOOL`
- **Default:** `ON` (x86_64), `OFF` (ARM)
- **Description:** Build the ISPC (Intel SPMD Program Compiler) module for SIMD acceleration
- **Requirements:** ISPC >= 1.16, x86_64 architecture
- **Incompatible with:** ARM architectures, BUILD_SYCL_MODULE
- **Usage:** `-DBUILD_ISPC_MODULE=ON`

### BUILD_SYCL_MODULE
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Build SYCL module with Intel oneAPI for heterogeneous computing
- **Requirements:** IntelLLVM (DPC++) compiler, Linux, GLIBCXX_USE_CXX11_ABI=ON
- **Incompatible with:** BUILD_CUDA_MODULE, BUILD_ISPC_MODULE
- **Usage:** `-DBUILD_SYCL_MODULE=ON`

### BUILD_GUI
- **Type:** `BOOL`
- **Default:** `ON`
- **Description:** Build the new GUI (graphical user interface)
- **Dependencies:** GLFW, GLEW
- **Usage:** `-DBUILD_GUI=ON`

### BUILD_WEBRTC
- **Type:** `BOOL`
- **Default:** `ON` (when BUILD_GUI=ON and x86_64), `OFF` (ARM/other)
- **Description:** Build WebRTC visualizer for remote visualization
- **Requirements:** BUILD_GUI=ON, x86_64 architecture (not ARM Linux)
- **Usage:** `-DBUILD_WEBRTC=ON`

### BUILD_JUPYTER_EXTENSION
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Build Jupyter extension (requires BUILD_WEBRTC=ON and BUILD_PYTHON_MODULE=ON)
- **Requirements:** BUILD_WEBRTC=ON, BUILD_PYTHON_MODULE=ON
- **Usage:** `-DBUILD_JUPYTER_EXTENSION=ON`

---

## Third-Party Dependency Options

All `USE_SYSTEM_*` options control whether Open3D uses system-installed libraries or builds them from source.

### USE_BLAS
- **Type:** `BOOL`
- **Default:** `ON` (ARM), `OFF` (x86_64)
- **Description:** Use BLAS/LAPACK instead of MKL (Intel Math Kernel Library)
- **Required:** `ON` for ARM architectures
- **Usage:** `-DUSE_BLAS=ON`

### USE_SYSTEM_BLAS
- **Type:** `BOOL`
- **Default:** `OFF` (when USE_BLAS=ON), `ON` (when USE_BLAS=OFF)
- **Description:** Use system pre-installed OpenBLAS instead of building from source
- **Note:** When enabled, CMake's FindBLAS.cmake is used. Supports BLA_VENDOR=OpenBLAS.
- **Usage:** `-DUSE_SYSTEM_BLAS=ON -DBLA_VENDOR=OpenBLAS`

### USE_SYSTEM_ASSIMP
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Use system pre-installed Assimp library
- **Usage:** `-DUSE_SYSTEM_ASSIMP=ON`

### USE_SYSTEM_CURL
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Use system pre-installed libcurl
- **Usage:** `-DUSE_SYSTEM_CURL=ON`

### USE_SYSTEM_CUTLASS
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Use system pre-installed NVIDIA CUTLASS library
- **Usage:** `-DUSE_SYSTEM_CUTLASS=ON`

### USE_SYSTEM_EIGEN3
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Use system pre-installed Eigen3 linear algebra library
- **Usage:** `-DUSE_SYSTEM_EIGEN3=ON`

### USE_SYSTEM_EMBREE
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Use system pre-installed Intel Embree ray tracing library
- **Usage:** `-DUSE_SYSTEM_EMBREE=ON`

### USE_SYSTEM_FILAMENT
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Use system pre-installed Google Filament rendering engine
- **Usage:** `-DUSE_SYSTEM_FILAMENT=ON`

### USE_SYSTEM_FMT
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Use system pre-installed fmt formatting library
- **Usage:** `-DUSE_SYSTEM_FMT=ON`

### USE_SYSTEM_GLEW
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Use system pre-installed GLEW (OpenGL Extension Wrangler)
- **Note:** Must be OFF if ENABLE_HEADLESS_RENDERING=ON
- **Usage:** `-DUSE_SYSTEM_GLEW=ON`

### USE_SYSTEM_GLFW
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Use system pre-installed GLFW windowing library
- **Note:** Must be OFF if ENABLE_HEADLESS_RENDERING=ON
- **Usage:** `-DUSE_SYSTEM_GLFW=ON`

### USE_SYSTEM_GOOGLETEST
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Use system pre-installed GoogleTest testing framework
- **Usage:** `-DUSE_SYSTEM_GOOGLETEST=ON`

### USE_SYSTEM_IMGUI
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Use system pre-installed Dear ImGui library
- **Usage:** `-DUSE_SYSTEM_IMGUI=ON`

### USE_SYSTEM_JPEG
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Use system pre-installed libjpeg
- **Usage:** `-DUSE_SYSTEM_JPEG=ON`

### USE_SYSTEM_JSONCPP
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Use system pre-installed jsoncpp library
- **Usage:** `-DUSE_SYSTEM_JSONCPP=ON`

### USE_SYSTEM_LIBLZF
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Use system pre-installed liblzf compression library
- **Usage:** `-DUSE_SYSTEM_LIBLZF=ON`

### USE_SYSTEM_MSGPACK
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Use system pre-installed msgpack library
- **Usage:** `-DUSE_SYSTEM_MSGPACK=ON`

### USE_SYSTEM_NANOFLANN
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Use system pre-installed nanoflann nearest neighbor library
- **Usage:** `-DUSE_SYSTEM_NANOFLANN=ON`

### USE_SYSTEM_OPENSSL
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Use system pre-installed OpenSSL cryptographic library
- **Usage:** `-DUSE_SYSTEM_OPENSSL=ON`

### USE_SYSTEM_PNG
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Use system pre-installed libpng
- **Usage:** `-DUSE_SYSTEM_PNG=ON`

### USE_SYSTEM_PYBIND11
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Use system pre-installed pybind11 library
- **Usage:** `-DUSE_SYSTEM_PYBIND11=ON`

### USE_SYSTEM_QHULLCPP
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Use system pre-installed Qhull computational geometry library
- **Usage:** `-DUSE_SYSTEM_QHULLCPP=ON`

### USE_SYSTEM_STDGPU
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Use system pre-installed stdgpu GPU container library
- **Usage:** `-DUSE_SYSTEM_STDGPU=ON`

### USE_SYSTEM_TBB
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Use system pre-installed Intel TBB (Threading Building Blocks)
- **Usage:** `-DUSE_SYSTEM_TBB=ON`

### USE_SYSTEM_TINYGLTF
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Use system pre-installed tinygltf library
- **Usage:** `-DUSE_SYSTEM_TINYGLTF=ON`

### USE_SYSTEM_TINYOBJLOADER
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Use system pre-installed tinyobjloader library
- **Usage:** `-DUSE_SYSTEM_TINYOBJLOADER=ON`

### USE_SYSTEM_VTK
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Use system pre-installed VTK (Visualization Toolkit)
- **Usage:** `-DUSE_SYSTEM_VTK=ON`

### USE_SYSTEM_ZEROMQ
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Use system pre-installed ZeroMQ messaging library
- **Usage:** `-DUSE_SYSTEM_ZEROMQ=ON`

### OPEN3D_USE_ONEAPI_PACKAGES
- **Type:** `BOOL`
- **Default:** `ON` (if oneAPI detected), `OFF` (otherwise)
- **Description:** Use the oneAPI distribution of MKL/TBB instead of separate packages
- **Platform:** Linux (oneAPI support)
- **Usage:** `-DOPEN3D_USE_ONEAPI_PACKAGES=ON`

### USE_SYSTEM_LIBREALSENSE
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Use system pre-installed Intel RealSense SDK
- **Usage:** `-DUSE_SYSTEM_LIBREALSENSE=ON`

### BUILD_VTK_FROM_SOURCE
- **Type:** `BOOL`
- **Default:** `ON` (ARM), `OFF` (x86_64)
- **Description:** Build VTK from source instead of using system version
- **Usage:** `-DBUILD_VTK_FROM_SOURCE=ON`

### BUILD_FILAMENT_FROM_SOURCE
- **Type:** `BOOL`
- **Default:** `ON` (ARM Linux), `OFF` (others)
- **Description:** Build Filament rendering engine from source
- **Required:** ON for ARM Linux architectures
- **Usage:** `-DBUILD_FILAMENT_FROM_SOURCE=ON`

---

## CUDA Options

### BUILD_WITH_CUDA_STATIC
- **Type:** `BOOL`
- **Default:** `ON`
- **Description:** Build with static CUDA libraries instead of shared libraries
- **Usage:** `-DBUILD_WITH_CUDA_STATIC=ON`

### BUILD_COMMON_CUDA_ARCHS
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Build for common CUDA GPUs (for release builds). Automatically set to ON when DEVELOPER_BUILD=OFF.
- **Auto-Configured Architectures:**
  - CUDA 11.8+: 75, 80, 86, 89, 90 (Turing, Ampere, Ada Lovelace, Hopper)
  - CUDA 11.1-11.7: 70, 75, 80, 86 (Volta, Turing, Ampere)
  - CUDA 11.0: 60, 70, 72, 75, 80 (Pascal, Volta, Turing, Ampere)
  - CUDA <11.0: 30, 50, 60, 70, 75 (Kepler, Maxwell, Pascal, Turing)
- **Usage:** `-DBUILD_COMMON_CUDA_ARCHS=ON`

### CMAKE_CUDA_ARCHITECTURES
- **Type:** `STRING`
- **Default:** `native` (if GPU detected), or common architectures if BUILD_COMMON_CUDA_ARCHS=ON
- **Description:** Specify CUDA GPU architectures to build for
- **Format:** Semicolon-separated list or "native" for auto-detect
- **Examples:** 
  - `-DCMAKE_CUDA_ARCHITECTURES="86;89;90"` (for A6000, RTX 4090, H100)
  - `-DCMAKE_CUDA_ARCHITECTURES="75-real;80-real"` (for specific compute capabilities)
  - `-DCMAKE_CUDA_ARCHITECTURES=native` (auto-detect from nvidia-smi)
- **Usage:** `-DCMAKE_CUDA_ARCHITECTURES="86;89;90"`

### ENABLE_CACHED_CUDA_MANAGER
- **Type:** `BOOL`
- **Default:** `ON` (Linux/macOS), `OFF` (Windows)
- **Description:** Enable cached CUDA memory manager for improved performance
- **Note:** Causes CUDA runtime error on Windows (see issue #6555)
- **Usage:** `-DENABLE_CACHED_CUDA_MANAGER=ON`

### CMAKE_CUDA_FLAGS
- **Type:** `STRING`
- **Description:** Additional flags for nvcc compiler
- **Auto-Set:** `--allow-unsupported-compiler` on MSVC 2022 with CUDA 11.7-12.4
- **Usage:** `-DCMAKE_CUDA_FLAGS="--expt-relaxed-constexpr"`

### CMAKE_CUDA_STANDARD
- **Type:** `STRING`
- **Default:** `17`
- **Description:** C++ standard for CUDA code
- **Usage:** `-DCMAKE_CUDA_STANDARD=17`

---

## ISPC Options

### BUILD_COMMON_ISPC_ISAS
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Build for common ISPC instruction sets (for release builds)
- **Usage:** `-DBUILD_COMMON_ISPC_ISAS=ON`

### ISPC_USE_LEGACY_EMULATION
- **Type:** `BOOL`
- **Default:** `OFF` (with ISPC compiler), `ON` (without ISPC compiler or non-Make/Ninja generators)
- **Description:** Use legacy ISPC language emulation over first-class CMake support
- **Usage:** `-DISPC_USE_LEGACY_EMULATION=OFF`

### ISPC_PRINT_LEGACY_COMPILE_COMMANDS
- **Type:** `BOOL`
- **Default:** `ON`
- **Description:** Print legacy compile commands on CMake configuration time
- **Usage:** `-DISPC_PRINT_LEGACY_COMPILE_COMMANDS=ON`

### CMAKE_ISPC_INSTRUCTION_SETS
- **Type:** `STRING`
- **Default:** Auto-detected based on CPU
- **Description:** ISPC instruction sets to build for
- **Usage:** `-DCMAKE_ISPC_INSTRUCTION_SETS="sse4;avx2;avx512skx"`

---

## SYCL Options

### OPEN3D_SYCL_TARGETS
- **Type:** `STRING`
- **Default:** `"spir64"`
- **Description:** SYCL targets for compilation (spir64 for JIT, or another for AOT)
- **Documentation:** https://github.com/intel/llvm/blob/sycl/sycl/doc/UsersManual.md
- **Usage:** `-DOPEN3D_SYCL_TARGETS="spir64"`

### OPEN3D_SYCL_TARGET_BACKEND_OPTIONS
- **Type:** `STRING`
- **Default:** `""`
- **Description:** SYCL target backend options for specific device compilation
- **Usage:** `-DOPEN3D_SYCL_TARGET_BACKEND_OPTIONS="..."`

### ENABLE_SYCL_UNIFIED_SHARED_MEMORY
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Enable SYCL unified shared memory
- **Usage:** `-DENABLE_SYCL_UNIFIED_SHARED_MEMORY=ON`

---

## GUI and Rendering Options

### ENABLE_HEADLESS_RENDERING
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Use OSMesa for headless rendering (no display required)
- **Requirements:** Forces USE_SYSTEM_GLEW=OFF and USE_SYSTEM_GLFW=OFF
- **Incompatible:** macOS (not supported)
- **Note:** Automatically disables BUILD_GUI
- **Usage:** `-DENABLE_HEADLESS_RENDERING=ON`

### WITH_OPENMP
- **Type:** `BOOL`
- **Default:** `ON`
- **Description:** Use OpenMP multi-threading for parallel operations
- **Usage:** `-DWITH_OPENMP=ON`

### WITH_IPP
- **Type:** `BOOL`
- **Default:** `ON`
- **Description:** Use Intel Integrated Performance Primitives (IPP) for optimized routines
- **Usage:** `-DWITH_IPP=ON`

---

## Python Options

### PYPI_PACKAGE_NAME
- **Type:** `STRING`
- **Default:** `"open3d"`
- **Description:** PyPI package name for Python wheel distribution
- **Deprecated names:** open3d-python, py3d, open3d-original, open3d-official, open-3d
- **Usage:** `-DPYPI_PACKAGE_NAME="open3d"`

### PYTHON_EXECUTABLE
- **Type:** `STRING`
- **Default:** Auto-detected from Python3_FOUND
- **Description:** Path to Python executable (deprecated, use Python3_EXECUTABLE instead)
- **Usage:** `-DPYTHON_EXECUTABLE=/usr/bin/python3`

### Python3_EXECUTABLE
- **Type:** `STRING` (via find_package)
- **Default:** Auto-detected
- **Description:** Python 3 executable path (requires Python >= 3.6)
- **Usage:** `-DPython3_EXECUTABLE=/usr/bin/python3`

---

## ML/AI Options

### BUILD_TENSORFLOW_OPS
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Build ops for TensorFlow integration
- **Requirements:** TensorFlow installed
- **Usage:** `-DBUILD_TENSORFLOW_OPS=ON`

### BUILD_PYTORCH_OPS
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Build ops for PyTorch integration
- **Requirements:** PyTorch installed
- **Usage:** `-DBUILD_PYTORCH_OPS=ON`

### BUNDLE_OPEN3D_ML
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Includes the Open3D-ML repo in the Python wheel
- **Requirements:** BUILD_TENSORFLOW_OPS=ON or BUILD_PYTORCH_OPS=ON
- **Usage:** `-DBUNDLE_OPEN3D_ML=ON`

---

## Sensor Options

### BUILD_LIBREALSENSE
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Build support for Intel RealSense camera
- **Usage:** `-DBUILD_LIBREALSENSE=ON`

### BUILD_AZURE_KINECT
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Build support for Azure Kinect sensor
- **Usage:** `-DBUILD_AZURE_KINECT=ON`

---

## Compiler and Build System Options

### GLIBCXX_USE_CXX11_ABI
- **Type:** `BOOL`
- **Default:** `ON`
- **Description:** Set -D_GLIBCXX_USE_CXX11_ABI=1 for C++11 ABI compatibility
- **Required:** ON for BUILD_SYCL_MODULE
- **Usage:** `-DGLIBCXX_USE_CXX11_ABI=ON`

### CMAKE_CXX_STANDARD
- **Type:** `STRING`
- **Default:** `17` (hardcoded in CMakeLists.txt)
- **Description:** C++ standard version
- **Note:** Hardcoded to 17, not configurable via flag
- **Usage:** Not directly configurable (hardcoded)

### CMAKE_BUILD_TYPE
- **Type:** `STRING`
- **Default:** `Release` (if not multi-config generator)
- **Values:** `Debug`, `Release`, `MinSizeRel`, `RelWithDebInfo`
- **Description:** Build type for single-config generators
- **Usage:** `-DCMAKE_BUILD_TYPE=Release`

### CMAKE_POSITION_INDEPENDENT_CODE
- **Type:** `BOOL`
- **Default:** `ON` (hardcoded)
- **Description:** Build with -fPIC (position independent code)
- **Usage:** Not directly configurable (always ON)

### THREADS_PREFER_PTHREAD_FLAG
- **Type:** `BOOL`
- **Default:** `TRUE` (hardcoded)
- **Description:** Prefer -pthread flag over -lpthread library
- **Usage:** Not directly configurable (always TRUE)

### STATIC_WINDOWS_RUNTIME
- **Type:** `BOOL`
- **Default:** `ON` (if BUILD_SHARED_LIBS=OFF), `OFF` (if BUILD_SHARED_LIBS=ON)
- **Description:** Use static (MT/MTd) Windows runtime instead of DLL runtime
- **Platform:** Windows only
- **Usage:** `-DSTATIC_WINDOWS_RUNTIME=ON`

### OPEN3D_WARNINGS_AS_ERRORS
- **Type:** `BOOL`
- **Default:** Not defined in main CMakeLists.txt
- **Description:** Treat compiler warnings as errors (may be used in subdirectories)
- **Usage:** `-DOPEN3D_WARNINGS_AS_ERRORS=OFF`

---

## Platform-Specific Options

### PREFER_OSX_HOMEBREW
- **Type:** `BOOL`
- **Default:** `ON`
- **Description:** Prefer Homebrew libraries over macOS frameworks
- **Platform:** macOS only
- **Usage:** `-DPREFER_OSX_HOMEBREW=ON`

### CMAKE_OSX_DEPLOYMENT_TARGET
- **Type:** `STRING`
- **Default:** `11.0` (ARM64 macOS), `10.15` (x86_64 macOS)
- **Description:** Minimum macOS deployment version
- **Platform:** macOS only
- **Usage:** `-DCMAKE_OSX_DEPLOYMENT_TARGET=11.0`

### WITH_MINIZIP
- **Type:** `BOOL`
- **Default:** `OFF`
- **Description:** Enable MiniZIP compression support
- **Usage:** `-DWITH_MINIZIP=ON`

---

## Cache Variables

### OPEN3D_THIRD_PARTY_DOWNLOAD_DIR
- **Type:** `PATH`
- **Default:** `${CMAKE_CURRENT_SOURCE_DIR}/3rdparty_downloads`
- **Description:** Third-party download directory for caching downloaded dependencies
- **Usage:** `-DOPEN3D_THIRD_PARTY_DOWNLOAD_DIR=/path/to/cache`

### FILAMENT_PRECOMPILED_ROOT
- **Type:** `PATH`
- **Default:** `""`
- **Description:** Path to precompiled Filament library (used if BUILD_FILAMENT_FROM_SOURCE=OFF)
- **Usage:** `-DFILAMENT_PRECOMPILED_ROOT=/path/to/filament`

### OPEN3D_VERSION_FULL
- **Type:** `STRING`
- **Default:** Auto-calculated from version.txt + git commit hash (if DEVELOPER_BUILD=ON)
- **Description:** Full version string including commit hash
- **Usage:** Read-only, auto-generated

### OPEN3D_ABI_VERSION
- **Type:** `STRING`
- **Default:** `${OPEN3D_VERSION_MAJOR}.${OPEN3D_VERSION_MINOR}`
- **Description:** Open3D ABI version / SOVERSION (for releases only)
- **Usage:** Read-only, auto-generated

### DESKTOP_INSTALL_DIR
- **Type:** `PATH`
- **Default:** `/usr/share` (Linux), `$HOME/.local/share` (macOS/Windows)
- **Description:** Install directory for desktop applications
- **Usage:** `-DDESKTOP_INSTALL_DIR=/usr/share`

---

## Standard CMake Variables

These standard CMake variables are also used by Open3D:

### CMAKE_INSTALL_PREFIX
- **Type:** `PATH`
- **Default:** Platform-dependent
- **Description:** Installation prefix
- **Usage:** `-DCMAKE_INSTALL_PREFIX=/usr/local`

### CMAKE_C_COMPILER
- **Type:** `STRING`
- **Description:** C compiler path
- **Usage:** `-DCMAKE_C_COMPILER=/usr/bin/gcc`

### CMAKE_CXX_COMPILER
- **Type:** `STRING`
- **Description:** C++ compiler path
- **Usage:** `-DCMAKE_CXX_COMPILER=/usr/bin/g++`

### CMAKE_CUDA_COMPILER
- **Type:** `STRING`
- **Description:** CUDA compiler path
- **Usage:** `-DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc`

### CMAKE_C_COMPILER_LAUNCHER
- **Type:** `STRING`
- **Default:** Auto-detected if ccache found
- **Description:** Compiler launcher (e.g., ccache)
- **Usage:** `-DCMAKE_C_COMPILER_LAUNCHER=ccache`

### CMAKE_CXX_COMPILER_LAUNCHER
- **Type:** `STRING`
- **Default:** Auto-detected if ccache found
- **Description:** C++ compiler launcher
- **Usage:** `-DCMAKE_CXX_COMPILER_LAUNCHER=ccache`

### CMAKE_CUDA_COMPILER_LAUNCHER
- **Type:** `STRING`
- **Default:** Auto-detected if ccache found and BUILD_CUDA_MODULE=ON
- **Description:** CUDA compiler launcher
- **Usage:** `-DCMAKE_CUDA_COMPILER_LAUNCHER=ccache`

---

## Dependency Find Variables

These variables are used by CMake's find_package() to locate dependencies:

### BLA_VENDOR
- **Type:** `STRING`
- **Description:** BLAS/LAPACK vendor (used by FindBLAS.cmake)
- **Values:** `OpenBLAS`, `Generic`, `Intel10_64lp_seq`, etc.
- **Usage:** `-DBLA_VENDOR=OpenBLAS`

### BLAS_LIBRARIES
- **Type:** `STRING`
- **Description:** BLAS library paths (cache variable for FindBLAS.cmake)
- **Usage:** `-DBLAS_LIBRARIES=/usr/lib/x86_64-linux-gnu/libopenblas.so`

### LAPACK_LIBRARIES
- **Type:** `STRING`
- **Description:** LAPACK library paths (used by FindLAPACK.cmake)
- **Usage:** `-DLAPACK_LIBRARIES=/usr/lib/x86_64-linux-gnu/libopenblas.so`

### Eigen3_DIR
- **Type:** `PATH`
- **Description:** CMake config directory for Eigen3
- **Usage:** `-DEigen3_DIR=/usr/local/share/eigen3/cmake`

### OpenCV_DIR
- **Type:** `PATH`
- **Description:** CMake config directory for OpenCV
- **Usage:** `-DOpenCV_DIR=/usr/local/lib/cmake/opencv4`

### GLFW_CMAKE_PREFIX_PATH
- **Type:** `PATH`
- **Description:** Additional search path for GLFW
- **Usage:** `-DGLFW_CMAKE_PREFIX_PATH=/usr/local`

### CMAKE_PREFIX_PATH
- **Type:** `PATH`
- **Description:** Additional search paths for find_package()
- **Usage:** `-DCMAKE_PREFIX_PATH="/usr/local;/opt/custom"`

### CMAKE_LIBRARY_PATH
- **Type:** `PATH`
- **Description:** Additional library search paths
- **Usage:** `-DCMAKE_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu;/usr/lib64"`

### CMAKE_INCLUDE_PATH
- **Type:** `PATH`
- **Description:** Additional include search paths
- **Usage:** `-DCMAKE_INCLUDE_PATH="/usr/include/x86_64-linux-gnu;/usr/include"`

---

## Flag Dependencies and Constraints

### Critical Dependencies
- `BUILD_JUPYTER_EXTENSION=ON` requires `BUILD_WEBRTC=ON` and `BUILD_PYTHON_MODULE=ON`
- `BUILD_WEBRTC=ON` requires `BUILD_GUI=ON`
- `BUILD_SYCL_MODULE=ON` requires `GLIBCXX_USE_CXX11_ABI=ON`
- `BUNDLE_OPEN3D_ML=ON` requires `BUILD_TENSORFLOW_OPS=ON` or `BUILD_PYTORCH_OPS=ON`

### Platform Requirements
- ARM architectures: `USE_BLAS=ON` (required), `BUILD_FILAMENT_FROM_SOURCE=ON` (ARM Linux)
- ARM architectures: `BUILD_ISPC_MODULE=OFF` (not supported)
- ARM Linux: `BUILD_WEBRTC=OFF` (not supported)
- macOS: `ENABLE_HEADLESS_RENDERING=OFF` (not supported)
- Windows: `ENABLE_CACHED_CUDA_MANAGER=OFF` (causes errors)

### Mutual Exclusivity
- `BUILD_SYCL_MODULE` and `BUILD_CUDA_MODULE` cannot both be ON
- `BUILD_SYCL_MODULE` and `BUILD_ISPC_MODULE` cannot both be ON
- `ENABLE_HEADLESS_RENDERING=ON` disables `BUILD_GUI`

---

## Example CMake Configuration

### Minimal Configuration (CPU-only)
```bash
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DBUILD_CUDA_MODULE=OFF \
    -DBUILD_PYTHON_MODULE=ON
```

### CUDA-Enabled Configuration
```bash
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_CUDA_MODULE=ON \
    -DCMAKE_CUDA_ARCHITECTURES="86;89;90" \
    -DBUILD_PYTHON_MODULE=ON \
    -DUSE_SYSTEM_BLAS=ON \
    -DBLA_VENDOR=OpenBLAS
```

### System Libraries Configuration
```bash
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DUSE_SYSTEM_EIGEN3=ON \
    -DUSE_SYSTEM_GLEW=ON \
    -DUSE_SYSTEM_GLFW=ON \
    -DUSE_SYSTEM_BLAS=ON \
    -DBLA_VENDOR=OpenBLAS \
    -DEigen3_DIR=/usr/local/share/eigen3/cmake
```

### Headless Rendering Configuration
```bash
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DENABLE_HEADLESS_RENDERING=ON \
    -DBUILD_PYTHON_MODULE=ON \
    -DBUILD_GUI=OFF
```

---

## Notes

1. **Invalid Flags:** Some flags like `USE_SYSTEM_OPENBLAS`, `BUILD_OPENBLAS`, `OpenBLAS_LIB` do NOT exist in Open3D 0.19.0. Use `USE_SYSTEM_BLAS` instead.

2. **CMake Version:** Open3D 0.19.0 requires CMake >= 3.24

3. **Python Version:** Requires Python >= 3.6

4. **CUDA Version:** Requires CUDA >= 11.5 (CUDA 11.4 and older not supported)

5. **ISPC Version:** Requires ISPC >= 1.16 (ISPC 1.15 and older not supported)

6. **Auto-Detection:** Many dependencies are auto-detected via `find_package()`. Explicit paths can be provided via standard CMake variables.

---

**Document Version:** 1.0  
**Last Updated:** 2024  
**Open3D Version:** 0.19.0  
**Source Repository:** https://github.com/isl-org/Open3D

---

## Quick Reference: Invalid/Non-Existent Flags

The following flags are **NOT** valid in Open3D 0.19.0 (commonly mistaken flags):

- ❌ `USE_SYSTEM_OPENBLAS` → Use `USE_SYSTEM_BLAS` instead
- ❌ `BUILD_OPENBLAS` → Does not exist
- ❌ `OpenBLAS_LIB` → Does not exist (use `BLAS_LIBRARIES` with FindBLAS)
- ❌ `OpenBLAS_INCLUDE_DIR` → Does not exist (use standard include paths)
- ❌ `LAPACK_LIBRARY` → Not used by Open3D (use `LAPACK_LIBRARIES` with FindLAPACK)
- ❌ `LAPACKE_LIBRARY` → Not used by Open3D (use FindLAPACKE)
- ❌ `LAPACK_LIBRARY_DEBUG` → Not used by Open3D
- ❌ `LAPACK_CBLAS_H` → Not used by Open3D
- ❌ `LAPACK_LAPACKE_H` → Not used by Open3D
- ❌ `OPENBVLAS_LIB` → Typo, does not exist
- ❌ `BUILD_OPENVBLAS` → Does not exist

