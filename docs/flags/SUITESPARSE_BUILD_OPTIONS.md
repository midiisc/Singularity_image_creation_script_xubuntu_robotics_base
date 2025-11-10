# SuiteSparse Build Options (v7.12.1)

**Repository:** https://github.com/DrTimothyAldenDavis/SuiteSparse  
**Commit:** `901381cd753c004cc2db8e91bdb48f1b51212d3d`  
**Last Audited:** November 9, 2025 (Library-Analysis-Tool)

> **Audit Highlights**
> - Library-Analysis-Tool re-scanned tag `v7.12.1`; the global policy module still defines the expected switches (`SUITESPARSE_USE_OPENMP`, `SUITESPARSE_USE_CUDA`, `SUITESPARSE_USE_FORTRAN`, etc.) with defaults unchanged.  
> - No new CMake `option()` entries surfaced outside of package-specific test/demo toggles (`enable_examples`, `enable_tests`, `enable_internal_blaslib`). Existing documentation already covers these controls.  
> - 67 `CMakeLists.txt` and 499 header files were detected; dependency extraction confirms the established BLAS/LAPACK, CUDA, and OpenMP requirements only.

This note summarises the key CMake options and build switches in the SuiteSparse repository (`https://github.com/DrTimothyAldenDavis/SuiteSparse`, tag `v7.12.1`) that matter for the MKL migration.

## Toolchain Basics
- **Minimum CMake**: 3.22 when using the root `CMakeLists.txt`. (GraphBLAS/LAGraph/CSparse standalone builds allow slightly older versions.)
- **Recommended compilers**: GCC/Clang on Linux. When mixing compilers (e.g. Intel `icx` + GNU `gfortran`) pay attention to OpenMP runtime conflicts (see below).
- **BLAS requirement**: Many packages require BLAS/LAPACK. MKL is supported by setting:
  ```bash
  -DBLA_VENDOR=Intel10_64lp -DBLA_SIZEOF_INTEGER=4
  ```
  and ensuring MKL libraries (`libmkl_intel_lp64`, `libmkl_core`, `libmkl_gnu_thread`/`libmkl_intel_thread`) are visible via `LD_LIBRARY_PATH`/`CMAKE_PREFIX_PATH`.
- **CUDA prerequisites (Ubuntu 24.04)**: Ensure the following packages are installed prior to configuring SuiteSparse:
  ```
  cuda-toolkit-12-6
  libcublas-12-6         libcublas-dev-12-6
  libcusparse-12-6       libcusparse-dev-12-6
  libcusolver-12-6       libcusolver-dev-12-6
  libcurand-12-6         libcurand-dev-12-6
  libnpp-12-6            libnpp-dev-12-6
  libpthread-stubs0-dev  libnuma-dev  pkg-config
  ```
  These provide `libcudart`, cuBLAS, cuSPARSE, cuSOLVER, and cuRAND needed by CHOLMOD/SPQR GPU kernels.

## Global CMake Options (from `SuiteSparse_config/cmake_modules/SuiteSparsePolicy.cmake`)
- `SUITESPARSE_USE_OPENMP` (default `ON`): Master switch; per-package `*_USE_OPENMP` options inherit this value.
- `SUITESPARSE_USE_CUDA` (default `ON`): Enables CUDA paths where supported (CHOLMOD, SPQR, GraphBLAS).
- `SUITESPARSE_USE_STRICT` (default `OFF`): When `ON`, any `_USE_*` option that cannot be satisfied triggers a CMake error instead of a warning.
- `SUITESPARSE_USE_FORTRAN` (default `ON`): Controls whether Fortran code is compiled. Set `OFF` if you wish to avoid Fortran dependencies, but ensure `SUITESPARSE_C_TO_FORTRAN` matches MKL’s symbol convention (`"(name,NAME) name##_"` on Linux).
- `SUITESPARSE_USE_64BIT_BLAS` (default `OFF`): When `ON`, the BLAS finder prefers ILP64 variants (Intel MKL ILP64, OpenBLAS ILP64, etc.). Combine with `-DBLA_VENDOR` to enforce the integer width strictly.
- `SUITESPARSE_USE_PYTHON` (default `ON`): Currently affects SPEX Python bindings.
- `SUITESPARSE_DEMOS` (default `OFF`): Enable demo binaries/tests when set `ON`.
- `BUILD_SHARED_LIBS` / `BUILD_STATIC_LIBS`: Shared libs `ON` by default; static also `ON` unless `NSTATIC` is set or GraphBLAS (default static `OFF`).
- `SUITESPARSE_LOCAL_INSTALL` (default `OFF`): When `ON`, installs into `SuiteSparse/lib`/`SuiteSparse/include` relative to the source tree (requires CMake 3.19). Normally leave `OFF` and control install prefix via `CMAKE_INSTALL_PREFIX`.
- `SUITESPARSE_CONFIG_USE_OPENMP`: Mirrors `SUITESPARSE_USE_OPENMP` and specifically toggles OpenMP in `SuiteSparse_config`.
- `SUITESPARSE_REQUIRE_BLAS` (default `ON`): Must remain `ON` when building CHOLMOD (supernodal), SPQR, UMFPACK, or ParU. Turning it `OFF` will raise a fatal error if those components are enabled.
- `SUITESPARSE_PKGFILEDIR`: Controls where CMake config and pkg-config files are installed (defaults beneath the chosen libdir).
- `SUITESPARSE_INCLUDEDIR_POSTFIX`: Default “suitesparse”; change to adjust header install path.
- `SUITESPARSE_CUDA_ARCHITECTURES` (default `"52;75;80"`): Overrides the SM list passed to `nvcc`. Accepts a semicolon-separated list or `"all"` (requires CMake ≥ 3.23).
- `BLA_STATIC` (default `OFF`): Forces static linkage for BLAS/LAPACK when enabled (`SuiteSparseBLAS.cmake`).
- `SUITESPARSE_C_TO_FORTRAN`: Name-mangling macro used when no Fortran compiler is detected. Defaults to `"(name,NAME) name"` on MSVC and `"(name,NAME) name##_"` elsewhere; set manually if your BLAS uses a different convention.

### System Library Overrides
For each core package there is an option to use pre-installed system libraries instead of building SuiteSparse’s copy:
```
SUITESPARSE_USE_SYSTEM_BTF
SUITESPARSE_USE_SYSTEM_CHOLMOD
SUITESPARSE_USE_SYSTEM_AMD
SUITESPARSE_USE_SYSTEM_CAMD
SUITESPARSE_USE_SYSTEM_COLAMD
SUITESPARSE_USE_SYSTEM_CCOLAMD
SUITESPARSE_USE_SYSTEM_GRAPHBLAS
SUITESPARSE_USE_SYSTEM_SUITESPARSE_CONFIG
SUITESPARSE_USE_SYSTEM_UMFPACK
```
All default to `OFF`. Setting any of these to `ON` removes the project from the build graph and invokes `find_package(...)` for the specified minimum version.

## Project Selection (root `CMakeLists.txt`)
- `SUITESPARSE_ENABLE_PROJECTS` (string): Semicolon-separated list of lowercase component names or `all`. Defaults to `all`. The build script auto-adds dependencies (e.g. enabling ParU forces UMFPACK, CHOLMOD, AMD, etc.).
- `CHOLMOD_CAMD`, `CHOLMOD_SUPERNODAL`: Control optional modules inside CHOLMOD (both default `ON`).
- `KLU_USE_CHOLMOD`, `UMFPACK_USE_CHOLMOD`: Default `ON`; toggle CHOLMOD-based enhancements.
- `GRAPHBLAS_BUILD_STATIC_LIBS`: Allows GraphBLAS static libraries; default `OFF` for faster builds.

## Per-Package Options
Each subdirectory exposes additional toggles. Key ones relevant to MKL/OpenMP:

| Package | Option | Default | Notes |
|---------|--------|---------|-------|
| **SuiteSparse_config** | `SUITESPARSE_CONFIG_USE_OPENMP` | `SUITESPARSE_USE_OPENMP` | Ties the reference timer to OpenMP APIs (`omp_get_wtime`) when available. |
| **CHOLMOD** | `CHOLMOD_USE_OPENMP` | `SUITESPARSE_USE_OPENMP` | Controls OpenMP parallelism. |
| | `CHOLMOD_USE_CUDA` | `SUITESPARSE_USE_CUDA` | Optional CUDA acceleration. |
| | `CHOLMOD_GPL` | `ON` | Drop all GPL modules (MatrixOps, Modify, Supernodal, CUDA) when `OFF`. |
| | `CHOLMOD_CHECK`, `CHOLMOD_MATRIXOPS`, `CHOLMOD_CHOLESKY`, `CHOLMOD_MODIFY`, `CHOLMOD_PARTITION` | `ON` | Fine-grained module switches. `CHOLMOD_CHOLESKY=OFF` disables Supernodal/Modify; `CHOLMOD_CAMD=OFF` disables Partition. |
| | `CHOLMOD_CAMD`, `CHOLMOD_SUPERNODAL` | `ON` | Switch CAMD/CCOLAMD adapters and Supernodal kernels on/off. Supernodal enforces BLAS/LAPACK usage. |
| **SPQR** | `SPQR_USE_CUDA` | `SUITESPARSE_USE_CUDA` | CUDA support for QR. |
| **GraphBLAS** | `GRAPHBLAS_USE_OPENMP` | `SUITESPARSE_USE_OPENMP` | CPU parallelism. |
| | `GRAPHBLAS_USE_CUDA` | `OFF` upstream | Development CUDA path; requires CUDA ≥ 11.2 and enables GPU kernels plus RMM. |
| | `GRAPHBLAS_USE_JIT` | Auto (`ON` when host toolchain supports it) | Controls the CPU JIT pipeline; falls back to stub sources when `OFF`. |
| | `GRAPHBLAS_COMPACT` | `OFF` | Skips FactoryKernel builds to shorten compile time (implied for some CUDA dev flows). |
| **LAGraph** | `LAGRAPH_USE_OPENMP` | `SUITESPARSE_USE_OPENMP` | Graph algorithms parallelism. |
| **ParU** | `PARU_USE_OPENMP` | `SUITESPARSE_USE_OPENMP` | Requires OpenMP ≥ 4.5; disables GPU-like tasking otherwise. |
| **SPEX** | `SPEX_USE_OPENMP` | `SUITESPARSE_USE_OPENMP` | Governs parallel sections in rational solvers. |
| | `SPEX_USE_PYTHON` | auto (`ON` when building shared libs) | Builds the optional `spexpy` bindings; disable to avoid Python/MPFR wheel build. |
| **UMFPACK, KLU** | `UMFPACK_USE_CHOLMOD`, `KLU_USE_CHOLMOD` | `ON` | Enable the optional CHOLMOD-based orderings. |
| **Mongoose** | `MONGOOSE_COVERAGE` | `OFF` (inherits from `-DCOV=ON`) | Adds gcov/lcov instrumentation for the graph partitioner demos. |
| **CXSparse** | `CXSPARSE_USE_COMPLEX` | `ON` except MSVC | Enables complex-number kernels; adds `NCOMPLEX` define when `OFF`. |

### CHOLMOD module flags

All default to `ON` unless the corresponding directory is missing:
- `CHOLMOD_GPL`: when `OFF`, drops MatrixOps, Modify, Supernodal, and CUDA modules (`NGPL`).
- `CHOLMOD_CHECK`: disables the diagnostic Check module when `OFF` (`NCHECK`).
- `CHOLMOD_MATRIXOPS`: strips MatrixOps helpers when `OFF` (`NMATRIXOPS`).
- `CHOLMOD_CHOLESKY`: removes Cholesky kernels when `OFF`, also forces `CHOLMOD_SUPERNODAL`/`CHOLMOD_MODIFY` off (`NCHOLESKY`).
- `CHOLMOD_MODIFY`: disables rank-update functionality when `OFF` (`NMODIFY`).
- `CHOLMOD_CAMD`: controls CAMD/CCOLAMD adapters; disabling sets `NCAMD` and cascades to `CHOLMOD_PARTITION=OFF`.
- `CHOLMOD_PARTITION`: wraps METIS-based partitioning; when `OFF`, emits `NPARTITION` and clears CAMD integration.
- `CHOLMOD_SUPERNODAL`: toggles the supernodal factorization (`NSUPERNODAL`); requires BLAS/LAPACK when enabled.

### GraphBLAS toggles

- `GRAPHBLAS_USE_JIT`: default `ON` when the host C toolchain is detected; falls back to stubbed kernels when disabled.
- `GRAPHBLAS_USE_CUDA`: manually enable for GPU development builds; upstream keeps it `OFF` for production due to maturity concerns.
- `GRAPHBLAS_COMPACT`: removes FactoryKernel compilation (`GBCOMPACT`) to reduce build size/time—useful for lightweight CPU-only installs.
- Architecture hints (`GBNCPUFEAT`, `GBX86`, `GBAVX2`, `GBAVX512F`, `GBRISCV64`, `GBRVV`) can be provided as cache variables to override auto-detected SIMD/vector targets when testing specific back ends.
- `GRAPHBLAS_JIT_ENABLE_RELOCATE`: defaults `ON` (except macOS); switches JIT library references to `-l` form so cache entries remain relocatable.
- `GRAPHBLAS_JITINIT`: integer knob (default `4`) that sets the CPU JIT control mode (`4 on` → `0 off`); propagated via the `JITINIT=` compile definition.
- `GRAPHBLAS_CACHE_PATH`: not a CMake flag but an env override for the CPU/GPU JIT cache location (`$HOME/.SuiteSparse/GrB*` by default).
- `GRAPHBLAS_CROSS_TOOLCHAIN_FLAGS_NATIVE`: string cache variable passed to the native build used to generate `GB_JITpackage.c` when cross-compiling; supply `-DCMAKE_TOOLCHAIN_FILE=...` entries here if the host/compiler differs from the target.

### SPEX Python bindings

- `SPEX_USE_PYTHON`: defaults to `ON` when shared libraries are requested, wiring the SPEX Python interface and packaging pieces. Set `OFF` to avoid bringing Python, GMP, and MPFR headers into the build.

### Mongoose coverage toggle

- `MONGOOSE_COVERAGE`: when `ON`, recompiles the graph partitioner with `-fprofile-arcs -ftest-coverage` and switches builds to debug to support coverage runs.

### SuiteSparse METIS / GKlib debug flags

The METIS compatibility layer (`CHOLMOD/SuiteSparse_metis/GKlib`) exposes extra switches—default `OFF`:
- `GDB`, `DEBUG`, `GPROF`: enable debugger symbols or gprof instrumentation.
- `ASSERT`, `ASSERT2`: retain increasingly strict runtime checks (`NDEBUG/NDEBUG2` otherwise).
- `OPENMP`: turn on GKlib’s internal OpenMP usage (distinct from SuiteSparse’s main OpenMP flag).
- `PCRE`, `GKREGEX`, `GKRAND`: link optional regex/random helpers when available.

### LAGraph GraphBLAS discovery helpers

- `LAGRAPH_DUMP`: available through `FindGraphBLAS.cmake`; prints each search path attempt when diagnosing missing GraphBLAS installations.

### Coverage utilities

- `CODE_COVERAGE_VERBOSE`: toggle defined in LAGraph’s `CodeCoverage.cmake` (default `FALSE`). Set `-DCODE_COVERAGE_VERBOSE=TRUE` when `COVERAGE=1` to echo every file fed through `lcov`.

Refer to each `Package/CMakeLists.txt` for further package-specific switches (e.g. demo builds, Python bindings, optional ordering modules).

## BLAS/LAPACK Integration Notes
- SuiteSparse honours CMake’s BLAS/LAPACK discovery. For MKL:
  ```bash
  cmake .. \
    -DBLA_VENDOR=Intel10_64lp \
    -DBLA_SIZEOF_INTEGER=4 \
    -DCMAKE_PREFIX_PATH=/opt/intel/oneapi/mkl/latest \
    -DCMAKE_BUILD_TYPE=Release
  ```
- If building MKL ILP64 (64-bit integers) you can set `-DBLA_SIZEOF_INTEGER=8` and keep `SUITESPARSE_USE_64BIT_BLAS=ON`.
- Ensure **exactly one** OpenMP runtime is linked. MKL + GNU compilers should use `libmkl_gnu_thread` and `libgomp`. If mixing Intel and GNU compilers, either disable Fortran (`SUITESPARSE_USE_FORTRAN=OFF`) or compile everything with a consistent toolchain to avoid linking both `libiomp5` and `libgomp`.

## Installation & Packaging
- CMake install destinations are controlled by the standard GNU install dirs (`CMAKE_INSTALL_LIBDIR`, `CMAKE_INSTALL_INCLUDEDIR`). The root build enables RPATH `$ORIGIN` support so installed libraries can locate peers in the same prefix.
- Generated Config files live under `${libdir}/cmake/<project>` and pkg-config files under `${libdir}/pkgconfig` by default. Adjust using `SUITESPARSE_PKGFILEDIR`.

## References
- Repository: <https://github.com/DrTimothyAldenDavis/SuiteSparse>
- Root `CMakeLists.txt` (project selection, dependencies, BLAS enforcement)
- `SuiteSparse_config/cmake_modules/SuiteSparsePolicy.cmake` (global options, BLAS/Fortran notes)
- Individual package `CMakeLists.txt` for fine-grained toggles (CHOLMOD, SPQR, GraphBLAS, ParU, SPEX, etc.)

