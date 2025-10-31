# nvtop - Comprehensive CMake Flags Documentation

**Version:** Latest (git master)  
**Source Repository:** https://github.com/syllo/nvtop  
**Documentation Generated:** From source code analysis  
**CMake Minimum Version:** 3.18

---

## Table of Contents

1. [Core Build Options](#core-build-options)
2. [GPU Vendor Support Options](#gpu-vendor-support-options)
3. [Standard CMake Variables](#standard-cmake-variables)
4. [Dependency Find Variables](#dependency-find-variables)
5. [Usage Examples](#usage-examples)

---

## Core Build Options

### `CMAKE_BUILD_TYPE`
- **Type:** `STRING` (Cache variable)
- **Default:** `Release`
- **Options:** `Debug`, `Release`, `MinSizeRel`, `RelWithDebInfo`
- **Description:** Specifies the build configuration.
- **Usage:**
  ```cmake
  -DCMAKE_BUILD_TYPE=Release
  ```

### `CMAKE_EXPORT_COMPILE_COMMANDS`
- **Type:** `BOOL`
- **Default:** `ON` (hardcoded)
- **Description:** Generate `compile_commands.json` for IDE support.
- **Note:** Always ON in nvtop CMakeLists.txt.

---

## GPU Vendor Support Options

### `NVIDIA_SUPPORT`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON` (Linux), `OFF` (macOS)
- **Description:** Build support for NVIDIA GPUs through libnvml.
- **Usage:**
  ```cmake
  -DNVIDIA_SUPPORT=ON
  ```
- **Note:** Requires NVIDIA Management Library (NVML). Default depends on platform.

### `AMDGPU_SUPPORT`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON` (Linux), `OFF` (macOS)
- **Description:** Build support for AMD GPUs through amdgpu driver.
- **Usage:**
  ```cmake
  -DAMDGPU_SUPPORT=ON
  ```
- **Note:** Requires AMD GPU driver. Default depends on platform.

### `INTEL_SUPPORT`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON` (Linux), `OFF` (macOS)
- **Description:** Build support for Intel GPUs through i915 or xe driver.
- **Usage:**
  ```cmake
  -DINTEL_SUPPORT=ON
  ```

### `MSM_SUPPORT`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON` (Linux), `OFF` (macOS)
- **Description:** Build support for Adreno GPUs through msm driver (Qualcomm/Adreno).
- **Usage:**
  ```cmake
  -DMSM_SUPPORT=ON
  ```

### `APPLE_SUPPORT`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON` (macOS), `OFF` (Linux)
- **Description:** Build support for Apple GPUs through Metal.
- **Usage:**
  ```cmake
  -DAPPLE_SUPPORT=ON
  ```
- **Note:** macOS only. Default depends on platform.

### `PANFROST_SUPPORT`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON` (Linux), `OFF` (macOS)
- **Description:** Build support for Mali GPUs through panfrost driver.
- **Usage:**
  ```cmake
  -DPANFROST_SUPPORT=ON
  ```
- **Note:** ARM Mali GPU support.

### `PANTHOR_SUPPORT`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON` (Linux), `OFF` (macOS)
- **Description:** Build support for Mali GPUs through panthor driver (newer driver).
- **Usage:**
  ```cmake
  -DPANTHOR_SUPPORT=ON
  ```
- **Note:** ARM Mali GPU support (newer driver).

### `V3D_SUPPORT`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON` (Linux), `OFF` (macOS)
- **Description:** Build support for Raspberry Pi through v3d driver.
- **Usage:**
  ```cmake
  -DV3D_SUPPORT=ON
  ```
- **Note:** Raspberry Pi GPU support.

### `ASCEND_SUPPORT`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF` (auto-detected based on platform)
- **Description:** Build support for Ascend NPUs through Ascend DCMI.
- **Usage:**
  ```cmake
  -DASCEND_SUPPORT=ON
  ```
- **Note:** Huawei Ascend NPU support.

### `TPU_SUPPORT`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON` if `libtpuinfo.so` found, `OFF` otherwise (Linux only)
- **Description:** Build support for Google TPUs through GRPC.
- **Usage:**
  ```cmake
  -DTPU_SUPPORT=ON
  ```
- **Note:** Linux only. Auto-detected based on library presence.

### `ROCKCHIP_SUPPORT`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON` (ARM Linux), `OFF` (others)
- **Description:** Enable support for Rockchip NPU.
- **Usage:**
  ```cmake
  -DROCKCHIP_SUPPORT=ON
  ```
- **Note:** ARM Linux only (armv7 or aarch64).

### `METAX_SUPPORT`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `ON` (Linux), `OFF` (macOS)
- **Description:** Build support for MetaX GPUs through libmxsml.
- **Usage:**
  ```cmake
  -DMETAX_SUPPORT=ON
  ```

---

## Other Options

### `USE_LIBUDEV_OVER_LIBSYSTEMD`
- **Type:** `OPTION` (ON/OFF)
- **Default:** `OFF`
- **Description:** Use libudev, even if libsystemd is present.
- **Usage:**
  ```cmake
  -DUSE_LIBUDEV_OVER_LIBSYSTEMD=ON
  ```
- **Note:** Advanced option for systemd vs udev preference.

---

## Standard CMake Variables

nvtop respects standard CMake variables:

### Build System
- `CMAKE_GENERATOR`: Build system generator (e.g., `Ninja`, `Unix Makefiles`)
- `CMAKE_BUILD_TYPE`: Build configuration
- `CMAKE_INSTALL_PREFIX`: Installation directory

### Compilers
- `CMAKE_C_COMPILER`: C compiler
- `CMAKE_CXX_COMPILER`: C++ compiler

### RPATH
- `CMAKE_INSTALL_RPATH`: RPATH entries for installed libraries
- `CMAKE_INSTALL_RPATH_USE_LINK_PATH`: Use linker path as RPATH

---

## Dependency Find Variables

nvtop uses standard CMake `find_package()` for dependencies:

### Curses/ncurses
- Uses `find_package(Curses)` with Unicode support preference
- **Required:** Yes
- **Preference:** Wide character support (`CURSES_NEED_WIDE=TRUE`)

### NVIDIA Management Library (if `NVIDIA_SUPPORT=ON`)
- Requires NVML (libnvml)
- Usually provided by NVIDIA driver installation

### System Libraries
- **libudev** or **libsystemd**: For device monitoring
- **libtpuinfo.so**: For TPU support (if `TPU_SUPPORT=ON`)
- **libmxsml**: For MetaX GPU support (if `METAX_SUPPORT=ON`)

---

## Usage Examples

### Minimal Configuration (NVIDIA Only)
```cmake
cmake .. \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DNVIDIA_SUPPORT=ON \
  -DAMDGPU_SUPPORT=OFF \
  -DINTEL_SUPPORT=OFF \
  -DMSM_SUPPORT=OFF \
  -DAPPLE_SUPPORT=OFF \
  -DV3D_SUPPORT=OFF \
  -DPANFROST_SUPPORT=OFF \
  -DPANTHOR_SUPPORT=OFF \
  -DASCEND_SUPPORT=OFF \
  -DTPU_SUPPORT=OFF \
  -DROCKCHIP_SUPPORT=OFF \
  -DMETAX_SUPPORT=OFF \
  -DCMAKE_INSTALL_PREFIX=/usr/local
```

### Full Configuration (All GPU Support)
```cmake
cmake .. \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DNVIDIA_SUPPORT=ON \
  -DAMDGPU_SUPPORT=ON \
  -DINTEL_SUPPORT=ON \
  -DMSM_SUPPORT=ON \
  -DPANFROST_SUPPORT=ON \
  -DPANTHOR_SUPPORT=ON \
  -DV3D_SUPPORT=ON \
  -DTPU_SUPPORT=ON \
  -DROCKCHIP_SUPPORT=ON \
  -DMETAX_SUPPORT=ON \
  -DCMAKE_INSTALL_PREFIX=/usr/local
```

### Linux Configuration (Typical)
```cmake
cmake .. \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DNVIDIA_SUPPORT=ON \
  -DAMDGPU_SUPPORT=ON \
  -DINTEL_SUPPORT=ON \
  -DMSM_SUPPORT=ON \
  -DV3D_SUPPORT=ON \
  -DPANFROST_SUPPORT=ON \
  -DPANTHOR_SUPPORT=ON \
  -DMETAX_SUPPORT=ON \
  -DTPU_SUPPORT=OFF \
  -DROCKCHIP_SUPPORT=OFF \
  -DASCEND_SUPPORT=OFF \
  -DAPPLE_SUPPORT=OFF \
  -DCMAKE_INSTALL_PREFIX=/usr/local
```

---

## Notes and Best Practices

1. **Platform Defaults:** nvtop automatically sets reasonable defaults based on the platform (Linux vs macOS).

2. **GPU Support:** Enable only the GPU vendor support options you need to reduce dependencies and build time.

3. **NVIDIA Support:** Requires NVIDIA drivers with NVML library. Usually auto-detected if NVIDIA drivers are installed.

4. **ARM Support:** Rockchip and some Mali support options are automatically enabled on ARM platforms.

5. **TPU Support:** Auto-detected if `libtpuinfo.so` is found in system library paths.

6. **System Dependencies:** ncurses (with Unicode support) is required. libudev or libsystemd is used for device monitoring.

7. **Build Performance:** Disabling unused GPU vendor support reduces compilation time and dependencies.

---

## Invalid/Non-existent Flags

The following flags are **NOT** supported by modern nvtop (v3.0+):

- `NVML_SUPPORT` - Deprecated, use `NVIDIA_SUPPORT` instead
- `USE_SYSTEM_NVML` - Deprecated, NVML is auto-detected
- `BUILD_SHARED_LIBS` - nvtop builds a single executable, not a library
- `WITH_CUDA` - nvtop does not use CUDA directly (uses NVML for NVIDIA)

---

## References

- nvtop GitHub Repository: https://github.com/syllo/nvtop
- CMake Documentation: https://cmake.org/documentation/

---

**Document Version:** 1.0  
**Last Updated:** Generated from nvtop latest source code

