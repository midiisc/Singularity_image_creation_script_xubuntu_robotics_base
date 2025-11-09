# OpenBLAS Compilation Flags Reference

**Version:** 0.3.30 (Latest Stable Release)  
**Repository:** https://github.com/OpenMathLib/OpenBLAS  
**Commit:** `993fad6aebbce34a97d3f8c34d6d79d35b64cc48`  
**Last Updated:** November 9, 2025 (Library-Analysis-Tool snapshot)

> **2025-11-09 Audit Notes**
> - Verified the tag `v0.3.30` using Library-Analysis-Tool; no new `option()` toggles were introduced since the June 2025 revision.  
> - Kernel builds continue to define `USE_GEMM3M` internally when complex 3M GEMM paths are enabled. Retain the `USE_GEMM3M=1` make flag (or `-DCORE_GEMM3M=ON` in CMake presets) when targeting complex workloads that rely on Strassen-style kernels.  
> - File inventory: 33 `CMakeLists.txt`, 79 headers, 3 helper scripts. No additional dependencies beyond the documented BLAS/LAPACK toolchain were detected.

## Table of Contents

1. [Architecture Selection Flags](#architecture-selection-flags)
2. [Threading Flags](#threading-flags)
3. [Performance Optimization Flags](#performance-optimization-flags)
4. [Feature Selection Flags](#feature-selection-flags)
5. [Compiler and Build Flags](#compiler-and-build-flags)
6. [Advanced Configuration Flags](#advanced-configuration-flags)
7. [Recommended Build Configuration](#recommended-build-configuration)

---

## Architecture Selection Flags

### `TARGET`
Specify the target CPU architecture. When using `DYNAMIC_ARCH=1`, set this to the **oldest** CPU model you expect to encounter to avoid illegal instruction errors.

**Available x86_64 Targets:**
- **Intel:** P2, KATMAI, COPPERMINE, NORTHWOOD, PRESCOTT, BANIAS, YONAH, CORE2, PENRYN, DUNNINGTON, NEHALEM, SANDYBRIDGE, HASWELL, SKYLAKEX, ATOM, COOPERLAKE, SAPPHIRERAPIDS
- **AMD:** ATHLON, OPTERON, OPTERON_SSE3, BARCELONA, SHANGHAI, ISTANBUL, BOBCAT, BULLDOZER, PILEDRIVER, STEAMROLLER, EXCAVATOR, ZEN
- **VIA:** SSE_GENERIC, VIAC3, NANO

**Example:**
```bash
make TARGET=GENERIC  # Safe base target (recommended with DYNAMIC_ARCH)
make TARGET=HASWELL  # Optimized for Intel Haswell
make TARGET=ZEN      # Optimized for AMD Zen
```

### `DYNAMIC_ARCH`
Enable runtime CPU detection for optimal performance across multiple architectures. **This is the recommended option for maximum portability and performance.**

**Values:**
- `DYNAMIC_ARCH=1` - Enable dynamic architecture support

**Supported Architectures with DYNAMIC_ARCH:**
- **x86_64:** Prescott, Core2, Nehalem, Barcelona, Sandybridge, Bulldozer, Piledriver, Steamroller, Excavator, Haswell, Zen, SkylakeX, Cooper Lake, Sapphire Rapids
- **x86:** Katmai, Coppermine, Northwood, Prescott, Banias, Core2, Penryn, Dunnington, Nehalem, Athlon, Opteron, Opteron_SSE3, Barcelona, Bobcat, Atom, Nano
- **ARMv8:** CortexA53, CortexA57, CortexA72, CortexA73, Falkor, ThunderX, ThunderX2T99, TSV110, generic ARMV8
- **POWER:** POWER6, POWER8, POWER9, POWER10 (if recent compiler)
- **RISC-V:** riscv64_zvl128b, riscv64_zvl256b, generic riscv64
- **LoongArch64:** LA264, LA464, generic LoongArch64

**Example:**
```bash
make DYNAMIC_ARCH=1 TARGET=GENERIC
```

**Important:** Always use `TARGET=GENERIC` (or the oldest expected CPU) with `DYNAMIC_ARCH=1` to avoid using advanced instructions in common code.

### `DYNAMIC_OLDER`
Include support for older CPU models (Penryn, Dunnington, Opteron, Opteron/SSE3, Bobcat, Atom, Nano) in DYNAMIC_ARCH builds.

**Example:**
```bash
make DYNAMIC_ARCH=1 DYNAMIC_OLDER=1 TARGET=GENERIC
```

### `DYNAMIC_LIST`
Specify a custom list of targets to include in DYNAMIC_ARCH builds instead of the default list.

### `BINARY`
Specify binary type: 32-bit or 64-bit.

**Values:**
- `BINARY=32` - 32-bit binary (AVX/AVX2/AVX-512 disabled)
- `BINARY=64` - 64-bit binary (default)

---

## Threading Flags

### `USE_THREAD`
Control threaded BLAS. Automatically detected if not specified.

**Values:**
- `USE_THREAD=0` - Single-threaded
- `USE_THREAD=1` - Multi-threaded (default if multiple cores detected)

### `USE_OPENMP`
Enable OpenMP threading support. **Recommended for best performance.**

**Values:**
- `USE_OPENMP=1` - Enable OpenMP (recommended)
- `USE_OPENMP=0` - Disable OpenMP

**Note:** When `USE_OPENMP=1` is set, OpenBLAS ignores `OPENBLAS_NUM_THREADS` and `GOTO_NUM_THREADS` environment variables. Use `OMP_NUM_THREADS` instead.

**Example:**
```bash
make DYNAMIC_ARCH=1 USE_OPENMP=1 TARGET=GENERIC
```

### `NUM_THREADS`
Maximum number of threads. Should be less than or equal to the number of CPU threads. Automatically detected if not specified.

**Example:**
```bash
make NUM_THREADS=64  # For systems with up to 64 threads
```

**Note:** Setting a large NUM_THREADS value (e.g., 32-256) has a RAM footprint penalty even if users reduce threads at runtime.

### `NUM_PARALLEL`
Number of parallel instances of OpenBLAS calculation API that can run simultaneously. Required if `USE_OPENMP=1` and your application calls OpenBLAS from multiple threads.

**Example:**
```bash
make USE_OPENMP=1 NUM_PARALLEL=2
```

### `USE_LOCKING`
Enable thread safety for single-threaded OpenBLAS when called from multiple concurrent threads.

**Values:**
- `USE_LOCKING=1` - Enable locking (not needed with USE_OPENMP=1 or USE_THREAD=1)

### `USE_TLS`
Use thread-local storage instead of central memory buffer. Requires glibc 2.21+.

**Values:**
- `USE_TLS=1` - Enable thread-local storage

---

## Performance Optimization Flags

### `NO_AFFINITY`
Disable CPU affinity handling. **Recommended to avoid conflicts with other threading libraries.**

**Values:**
- `NO_AFFINITY=1` - Disable affinity (recommended, default)

**Note:** Enabling affinity may improve performance on NUMA systems but can conflict with applications that manage affinity.

### `NO_WARMUP`
Disable warmup phase. Enabled by default.

**Values:**
- `NO_WARMUP=1` - Disable warmup (default)

### `GEMM_MULTITHREAD_THRESHOLD`
Threshold for single-threaded GEMM execution. Default is 4. Higher values (up to 50, recommended for Julia) reduce multi-threading overhead for small matrices.

**Example:**
```bash
make GEMM_MULTITHREAD_THRESHOLD=50
```

### `NO_AVX`
Disable AVX kernel on Sandy Bridge (for compatibility with old compilers/OS).

**Values:**
- `NO_AVX=1` - Disable AVX

### `NO_AVX2`
Disable Haswell optimizations (if binutils is too old, e.g., RHEL6).

**Values:**
- `NO_AVX2=1` - Disable AVX2

### `NO_AVX512`
Disable SkylakeX optimizations (build system auto-detects if compiler/binutils are too old).

**Values:**
- `NO_AVX512=1` - Disable AVX512

### `BUFFERSIZE`
Memory buffer size for thread communication. Default is 32MB on x86_64. Increase for very large problems (>30000x30000).

**Example:**
```bash
make BUFFERSIZE=25  # 32MB (32<<20)
```

### `MAX_STACK_ALLOC`
Maximum stack allocation. Default is 2048. Set to 0 to disable stack allocation (may reduce GER and GEMV performance).

**Example:**
```bash
make MAX_STACK_ALLOC=0
```

### `BIGNUMA`
Enable support for systems with more than 16 NUMA nodes or more than 256 CPUs.

**Values:**
- `BIGNUMA=1` - Enable large NUMA support

---

## Feature Selection Flags

### `NO_STATIC`
Don't build static library.

**Values:**
- `NO_STATIC=1` - Skip static library

### `NO_SHARED`
Don't build shared library.

**Values:**
- `NO_SHARED=1` - Skip shared library

### `NO_CBLAS`
Don't build CBLAS interface.

**Values:**
- `NO_CBLAS=1` - Skip CBLAS

### `ONLY_CBLAS`
Build only CBLAS interface (no Fortran compiler needed).

**Values:**
- `ONLY_CBLAS=1` - Build only CBLAS

### `NO_LAPACK`
Don't build LAPACK (automatically sets `NO_LAPACKE=1`).

**Values:**
- `NO_LAPACK=1` - Skip LAPACK

### `NO_LAPACKE`
Don't build LAPACKE (C interface to LAPACK).

**Values:**
- `NO_LAPACKE=1` - Skip LAPACKE

### `BUILD_LAPACK_DEPRECATED`
Build LAPACK deprecated functions (enabled by default in 0.3.30).

**Values:**
- `BUILD_LAPACK_DEPRECATED=1` - Build deprecated functions

### `BUILD_RELAPACK`
Build RecursiveLAPACK on top of LAPACK.

**Values:**
- `BUILD_RELAPACK=1` - Build RecursiveLAPACK

### `RELAPACK_REPLACE`
Have RecursiveLAPACK replace standard LAPACK routines instead of adding RELAPACK_ prefixed versions.

**Values:**
- `RELAPACK_REPLACE=1` - Replace LAPACK with RecursiveLAPACK

### `BUILD_SINGLE`
Build only single precision real functions (SGEMM, etc.).

**Values:**
- `BUILD_SINGLE=1` - Build only single precision

### `BUILD_DOUBLE`
Build only double precision real functions (DGEMM, etc.).

**Values:**
- `BUILD_DOUBLE=1` - Build only double precision

### `BUILD_COMPLEX`
Build only single precision complex functions (CGEMM, etc.).

**Values:**
- `BUILD_COMPLEX=1` - Build only single precision complex

### `BUILD_COMPLEX16`
Build only double precision complex functions (ZGEMM, etc.).

**Values:**
- `BUILD_COMPLEX16=1` - Build only double precision complex

### `BUILD_BFLOAT16`
Enable experimental BFLOAT16 support.

**Values:**
- `BUILD_BFLOAT16=1` - Enable BFLOAT16

---

## Compiler and Build Flags

### `CC`
C compiler. Default is `gcc`.

**Example:**
```bash
make CC=gcc
make CC=clang
```

### `FC`
Fortran compiler. Default is `gfortran`.

**Example:**
```bash
make FC=gfortran
```

### `HOSTCC`
Host C compiler (for cross-compilation).

**Example:**
```bash
make HOSTCC=gcc
```

### `COMMON_OPT`
Common optimization flags. Default is `-O2`.

**Example:**
```bash
make COMMON_OPT="-O3 -march=native"
```

**Note:** Don't modify `COMMON_OPT` for POWER8 (flags defined in Makefile.power).

### `FCOMMON_OPT`
Fortran optimization flags. Default is `-frecursive` for gfortran.

**Note:** Don't modify `FCOMMON_OPT` for POWER8 (flags defined in Makefile.power).

### `PREFIX`
Installation directory. Default is `/opt/OpenBLAS`.

**Example:**
```bash
make install PREFIX=/usr/local
```

### `DEBUG`
Build debug version.

**Values:**
- `DEBUG=1` - Build debug version

### `FUNCTION_PROFILE`
Enable detailed performance profiling.

**Values:**
- `FUNCTION_PROFILE=1` - Enable profiling

### `SANITY_CHECK`
Enable sanity check by comparing results to reference BLAS (very slow, not implemented yet).

**Values:**
- `SANITY_CHECK=1` - Enable sanity check

---

## Advanced Configuration Flags

### `USE_SIMPLE_THREADED_LEVEL3`
Use legacy threaded Level 3 implementation.

**Values:**
- `USE_SIMPLE_THREADED_LEVEL3=1` - Use simple threading

### `INTERFACE64`
Enable 64-bit integer interface (equivalent to `-i8` ifort option).

**Values:**
- `INTERFACE64=1` - Enable 64-bit integers

### `CONSISTENT_FPCSR`
Synchronize FP CSR between threads (x86/x86_64 and aarch64 only).

**Values:**
- `CONSISTENT_FPCSR=1` - Enable FP CSR sync

### `HUGETLB_ALLOCATION`
Use large page allocation (hugepages) for thread buffers.

**Values:**
- `HUGETLB_ALLOCATION=1` - Enable hugepages

### `HUGETLBFILE_ALLOCATION`
Use hugepages based on mmap accessing memory-backed pseudofile (requires hugetlbfs mounted).

**Example:**
```bash
make HUGETLBFILE_ALLOCATION=/hugepages
```

### `DEVICEDRIVER_ALLOCATION`
Use special device driver for mapping physically contiguous memory.

**Values:**
- `DEVICEDRIVER_ALLOCATION=1` - Enable device driver allocation

### `LIBNAMEPREFIX`
Add prefix to library name: `lib$(LIBNAMEPREFIX)openblas.a`

**Example:**
```bash
make LIBNAMEPREFIX=scipy  # Results in libscipyopenblas.a
```

### `LIBNAMESUFFIX`
Add suffix to library name: `libopenblas_$(LIBNAMESUFFIX).a`

**Example:**
```bash
make LIBNAMESUFFIX=omp  # Results in libopenblas_omp.a
```

### `SYMBOLPREFIX` / `SYMBOLSUFFIX`
Add prefix/suffix to all exported symbol names in shared library.

**Example:**
```bash
make SYMBOLPREFIX=scipy_ SYMBOLSUFFIX=_64
```

### `CPP_THREAD_SAFETY_TEST`
Run C++ thread safety tester after build (requires C++11, OpenMP, ~1300 MiB RAM).

**Values:**
- `CPP_THREAD_SAFETY_TEST=1` - Enable thread safety test

### `CPP_THREAD_SAFETY_GEMV`
Run only the less memory-hungry GEMV test.

**Values:**
- `CPP_THREAD_SAFETY_GEMV=1` - Run GEMV test only

### `MAKE_NB_JOBS`
Force number of make jobs (default is number of logical CPUs).

**Example:**
```bash
make MAKE_NB_JOBS=4
```

### `NO_PARALLEL_MAKE`
Disable parallel make.

**Values:**
- `NO_PARALLEL_MAKE=1` - Disable parallel make

### `EMBEDDED`
Build for embedded systems (bare metal, e.g., Cortex M). Requires malloc()/free() implementation.

**Values:**
- `EMBEDDED=1` - Enable embedded mode

### `LAPACK_STRLEN`
Variable type for character argument length (default: `size_t`, older GCC: `int`).

**Example:**
```bash
make LAPACK_STRLEN=int
```

---

## Recommended Build Configuration

### For Maximum Portability and Performance (Recommended)

This configuration provides the best balance of performance, portability, and compatibility:

```bash
make DYNAMIC_ARCH=1 \
     TARGET=GENERIC \
     USE_OPENMP=1 \
     NO_AFFINITY=1 \
     NUM_THREADS=64 \
     CC=gcc \
     FC=gfortran \
     PREFIX=/usr/local
```

**Flags Explained:**
- `DYNAMIC_ARCH=1` - Runtime CPU detection for optimal performance on different CPUs
- `TARGET=GENERIC` - Safe base target, avoids illegal instructions
- `USE_OPENMP=1` - Best multi-threading performance
- `NO_AFFINITY=1` - Avoid conflicts with other threading libraries
- `NUM_THREADS=64` - Support for systems with up to 64 threads

### For Maximum Performance on Known Hardware

If you know the exact CPU architecture:

```bash
make TARGET=HASWELL \
     USE_OPENMP=1 \
     NUM_THREADS=24 \
     CC=gcc \
     FC=gfortran \
     PREFIX=/usr/local
```

Replace `HASWELL` with your CPU target (e.g., `SKYLAKEX`, `ZEN`, `SANDYBRIDGE`).

### For PyTorch/Deep Learning Workloads

Optimized for PyTorch and similar frameworks:

```bash
make DYNAMIC_ARCH=1 \
     TARGET=GENERIC \
     USE_OPENMP=1 \
     NO_AFFINITY=1 \
     NUM_THREADS=64 \
     GEMM_MULTITHREAD_THRESHOLD=50 \
     CC=gcc \
     FC=gfortran \
     PREFIX=/usr/local
```

**Additional Notes:**
- `GEMM_MULTITHREAD_THRESHOLD=50` is recommended for Julia and similar workloads
- Ensure OpenMP is available: `apt-get install libgomp1` or `yum install libgomp`

### Installation

After building, install with the same flags:

```bash
make install PREFIX=/usr/local
```

Then update the library cache:

```bash
ldconfig
```

---

## Performance Comparison: OpenBLAS vs MKL

### OpenBLAS with DYNAMIC_ARCH=1 Advantages:
- **Portability:** Works optimally on Intel, AMD, and other architectures
- **AMD Performance:** Often outperforms MKL on AMD hardware (2-2.4x faster in some benchmarks)
- **Open Source:** No licensing restrictions
- **Runtime CPU Detection:** Automatically optimizes for the CPU at runtime

### MKL Advantages:
- **Intel Performance:** Slightly better performance on Intel hardware (typically 5-10%)
- **Intel Optimizations:** Deep integration with Intel CPUs

### Recommendation:
For maximum portability and good performance across different hardware, **OpenBLAS with DYNAMIC_ARCH=1 is the recommended choice**, especially for:
- Multi-architecture deployments
- AMD hardware
- Open-source projects
- Systems requiring runtime CPU detection

---

## References

- **Official Repository:** https://github.com/OpenMathLib/OpenBLAS
- **Documentation:** http://www.openmathlib.org/OpenBLAS/docs/
- **User Manual:** http://www.openmathlib.org/OpenBLAS/docs/user_manual/
- **Installation Guide:** http://www.openmathlib.org/OpenBLAS/docs/install/
- **Target List:** See `TargetList.txt` in the source repository

