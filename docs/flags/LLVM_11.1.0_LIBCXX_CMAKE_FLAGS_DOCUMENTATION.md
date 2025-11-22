# LLVM 11.1.0 libc++/libc++abi CMake Configuration Flags - Complete Documentation

**Source:** LLVM 11.1.0 (GitHub: llvm/llvm-project)  
**Commit:** `llvmorg-11.1.0` (release tag)  
**Last Audited:** January 2025  
**CMake Minimum Version:** 3.13

This document provides documentation for CMake configuration flags used when building libc++ and libc++abi from LLVM 11.1.0 runtimes.

> **Note:** This build configuration builds only libc++ and libc++abi runtimes, not the full LLVM toolchain. This is significantly faster and sufficient for C++ standard library needs.

---

## Table of Contents

1. [LLVM Build Configuration Flags](#llvm-build-configuration-flags)
2. [libc++ Build Options](#libc-build-options)
3. [libc++abi Build Options](#libcabi-build-options)
4. [Standard CMake Variables](#standard-cmake-variables)

---

## LLVM Build Configuration Flags

### LLVM_ENABLE_PROJECTS
- **Type:** `STRING`
- **Default:** `""` (empty - no projects enabled)
- **Description:** Semicolon-separated list of LLVM projects to build. When building only runtimes (libc++/libc++abi), this should be empty.
- **Usage:** `-DLLVM_ENABLE_PROJECTS=""`
- **Valid Values:** `""`, `"clang"`, `"lld"`, `"compiler-rt"`, etc. (empty for runtime-only builds)
- **Note:** For libc++/libc++abi builds, this must be empty to avoid building unnecessary LLVM components.

### LLVM_ENABLE_RUNTIMES
- **Type:** `STRING`
- **Default:** `""` (empty - no runtimes enabled)
- **Description:** Semicolon-separated list of LLVM runtimes to build. For C++ standard library, use `"libcxx;libcxxabi"`.
- **Usage:** `-DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi"`
- **Valid Values:** `"libcxx"`, `"libcxxabi"`, `"libunwind"`, `"compiler-rt"`, etc. (semicolon-separated)
- **Note:** `libcxx` requires `libcxxabi` to be built together. Both are specified in a single string separated by semicolons.

---

## libc++ Build Options

### LIBCXX_ENABLE_SHARED
- **Type:** `BOOL`
- **Default:** `ON` (varies by platform)
- **Description:** Build libc++ as a shared library (.so/.dylib/.dll) instead of static library.
- **Usage:** `-DLIBCXX_ENABLE_SHARED=ON`
- **Valid Values:** `ON`, `OFF`
- **Note:** Shared libraries are recommended for most use cases as they reduce binary size and allow library updates without recompiling applications.

### LIBCXX_ENABLE_STATIC
- **Type:** `BOOL`
- **Default:** `ON` (varies by platform)
- **Description:** Build libc++ as a static library (.a/.lib) in addition to or instead of shared library.
- **Usage:** `-DLIBCXX_ENABLE_STATIC=OFF`
- **Valid Values:** `ON`, `OFF`
- **Note:** Can be enabled alongside `LIBCXX_ENABLE_SHARED=ON` to build both static and shared versions. For runtime-only builds, static is often disabled to reduce build time.

---

## libc++abi Build Options

### LIBCXXABI_ENABLE_SHARED
- **Type:** `BOOL`
- **Default:** `ON` (varies by platform)
- **Description:** Build libc++abi (C++ ABI library) as a shared library (.so/.dylib/.dll) instead of static library.
- **Usage:** `-DLIBCXXABI_ENABLE_SHARED=ON`
- **Valid Values:** `ON`, `OFF`
- **Note:** libc++abi provides the low-level ABI support for libc++. It must match the linkage type (shared/static) of libc++.

### LIBCXXABI_ENABLE_STATIC
- **Type:** `BOOL`
- **Default:** `ON` (varies by platform)
- **Description:** Build libc++abi as a static library (.a/.lib) in addition to or instead of shared library.
- **Usage:** `-DLIBCXXABI_ENABLE_STATIC=OFF`
- **Valid Values:** `ON`, `OFF`
- **Note:** Should match the static/shared configuration of libc++ for consistency.

---

## Standard CMake Variables

### CMAKE_BUILD_TYPE
- **Type:** `STRING`
- **Default:** `""` (empty - no default)
- **Description:** Build type for the project. For production builds, use `Release`.
- **Usage:** `-DCMAKE_BUILD_TYPE=Release`
- **Valid Values:** `Debug`, `Release`, `RelWithDebInfo`, `MinSizeRel`
- **Note:** `Release` enables optimizations and is recommended for production use.

### CMAKE_INSTALL_PREFIX
- **Type:** `PATH`
- **Default:** Platform-dependent (typically `/usr/local`)
- **Description:** Installation prefix for libc++ and libc++abi libraries and headers.
- **Usage:** `-DCMAKE_INSTALL_PREFIX=/path/to/install`
- **Note:** For local builds, use a custom prefix to avoid conflicts with system libraries.

### CMAKE_C_COMPILER
- **Type:** `FILEPATH`
- **Default:** Platform default C compiler
- **Description:** Path to the C compiler executable.
- **Usage:** `-DCMAKE_C_COMPILER=gcc`
- **Note:** Required for building libc++abi which has C components.

### CMAKE_CXX_COMPILER
- **Type:** `FILEPATH`
- **Default:** Platform default C++ compiler
- **Description:** Path to the C++ compiler executable.
- **Usage:** `-DCMAKE_CXX_COMPILER=g++`
- **Note:** Must be compatible with the C++ standard version required by libc++.

---

## Build Configuration Example

The following example shows a typical configuration for building libc++ and libc++abi as shared libraries only:

```bash
cmake ../llvm-project/runtimes \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
    -DLLVM_ENABLE_PROJECTS="" \
    -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi" \
    -DCMAKE_C_COMPILER=gcc \
    -DCMAKE_CXX_COMPILER=g++ \
    -DLIBCXX_ENABLE_SHARED=ON \
    -DLIBCXXABI_ENABLE_SHARED=ON \
    -DLIBCXX_ENABLE_STATIC=OFF \
    -DLIBCXXABI_ENABLE_STATIC=OFF
```

---

## References

- **LLVM Project:** https://github.com/llvm/llvm-project
- **LLVM 11.1.0 Release:** https://github.com/llvm/llvm-project/releases/tag/llvmorg-11.1.0
- **libc++ Documentation:** https://libcxx.llvm.org/
- **CMake Documentation:** https://cmake.org/documentation/

---

**Last Updated:** January 2025  
**Maintained By:** Build Script Validation System

