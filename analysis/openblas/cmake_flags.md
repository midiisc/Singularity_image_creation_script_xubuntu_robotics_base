# CMake Flag Inventory

_Generated on 2025-11-09T09:07:05Z_

## kernel/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L1367: target_compile_definitions(kernel${TSUFFIX} PRIVATE USE_GEMM3M)

**add_definitions**
- (none found)

## driver/level3/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## driver/level2/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## driver/others/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## utest/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## lapack-netlib/BLAS/TESTING/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## lapack-netlib/BLAS/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## lapack-netlib/BLAS/SRC/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## lapack-netlib/TESTING/LIN/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## lapack-netlib/TESTING/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## lapack-netlib/TESTING/MATGEN/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## lapack-netlib/TESTING/EIG/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## lapack-netlib/INSTALL/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## lapack-netlib/LAPACKE/src/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## lapack-netlib/LAPACKE/include/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## lapack-netlib/LAPACKE/mangling/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## lapack-netlib/LAPACKE/utils/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## lapack-netlib/LAPACKE/CMakeLists.txt

**Options**
- L24: option(LAPACKE_BUILD_SINGLE "Build LAPACKE single precision real" ON)
- L25: option(LAPACKE_BUILD_DOUBLE "Build LAPACKE double precision real" ON)
- L26: option(LAPACKE_BUILD_COMPLEX "Build LAPACKE single precision complex" ON)
- L27: option(LAPACKE_BUILD_COMPLEX16 "Build LAPACKE double precision complex" ON)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L87: target_compile_definitions(${LAPACKELIB} PUBLIC HAVE_LAPACK_CONFIG_H LAPACK_COMPLEX_STRUCTURE)

**add_definitions**
- (none found)

## lapack-netlib/LAPACKE/example/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## lapack-netlib/CMakeLists.txt

**Options**
- L49: option( LAPACK_TESTING_USE_PYTHON "Use Python for testing. Disable it on memory checks." ON )
- L57: option(TEST_FORTRAN_COMPILER "Test Fortran compiler complex abs and complex division" OFF)
- L91: option(BUILD_SHARED_LIBS "Build shared libraries" OFF)
- L94: option(BUILD_INDEX64 "Build Index-64 API libraries" OFF)
- L111: option(BUILD_INDEX64_EXT_API "Build Index-64 API as extended API with _64 suffix" ON)
- L142: option(USE_FLAT_NAMESPACE "Use flat namespaces for symbol resolution during build and runtime." OFF)
- L173: option(BUILD_TESTING "Build tests" ${_is_coverage_build})
- L198: option(BUILD_DEPRECATED "Build deprecated routines" OFF)
- L204: option(BUILD_SINGLE "Build single precision real" ON)
- L205: option(BUILD_DOUBLE "Build double precision real" ON)
- L206: option(BUILD_COMPLEX "Build single precision complex" ON)
- L207: option(BUILD_COMPLEX16 "Build double precision complex" ON)
- L222: option(USE_OPTIMIZED_BLAS "Whether or not to use an optimized BLAS library instead of included netlib BLAS" OFF)
- L264: option(CBLAS "Build CBLAS" OFF)
- L273: option(USE_XBLAS "Build extended precision (needs XBLAS)" OFF)
- L278: option(USE_OPTIMIZED_LAPACK "Whether or not to use an optimized LAPACK library instead of included netlib LAPACK" OFF)
- L357: option(LAPACKE "Build LAPACKE" OFF)
- L361: option(LAPACKE_WITH_TMG "Build LAPACKE with tmglib routines" OFF)
- L402: option(BLAS++ "Build BLAS++" OFF)
- L403: option(LAPACK++ "Build LAPACK++" OFF)
- L602: option(BUILD_HTML_DOCUMENTATION "Create and install the HTML based API
- L604: option(BUILD_MAN_DOCUMENTATION "Create and install the MAN based documentation (requires Doxygen) - command: make man" OFF)

**Global Compiler Flags**
- L101: set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DWeirdNEC -DLAPACK_ILP64 -DHAVE_LAPACK_CONFIG_H")
- L145: set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,-flat_namespace")
- L146: set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} -Wl,-flat_namespace")
- L147: set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,-flat_namespace")
- L250: set(CMAKE_EXE_LINKER_FLAGS
- L253: set(CMAKE_MODULE_LINKER_FLAGS
- L256: set(CMAKE_SHARED_LINKER_FLAGS
- L340: set(CMAKE_EXE_LINKER_FLAGS
- L343: set(CMAKE_MODULE_LINKER_FLAGS
- L346: set(CMAKE_SHARED_LINKER_FLAGS

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## lapack-netlib/SRC/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## lapack-netlib/CBLAS/src/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## lapack-netlib/CBLAS/include/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## lapack-netlib/CBLAS/examples/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## lapack-netlib/CBLAS/testing/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## lapack-netlib/CBLAS/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## lapack/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## ctest/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- L8: set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DADD${BU} -DCBLAS")

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## interface/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## cpp_thread_test/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- L6: set(CMAKE_CXX_FLAGS "${CMAKE_C_FLAGS} -DADD${BU} -DCBLAS")

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## CMakeLists.txt

**Options**
- L22: option(BUILD_WITHOUT_LAPACK "Do not build LAPACK and LAPACKE (Only BLAS or CBLAS)" OFF)
- L24: option(BUILD_WITHOUT_LAPACKE "Do not build the C interface to LAPACK)" OFF)
- L26: option(BUILD_LAPACK_DEPRECATED "When building LAPACK, include also some older, deprecated routines" ON)
- L30: option(BUILD_TESTING "Build LAPACK testsuite when building LAPACK" ON)
- L32: option(BUILD_BENCHMARKS "Build the collection of BLAS/LAPACK benchmarks" OFF)
- L34: option(C_LAPACK "Build LAPACK from C sources instead of the original Fortran" OFF)
- L36: option(BUILD_WITHOUT_CBLAS "Do not build the C interface (CBLAS) to the BLAS functions" OFF)
- L38: option(DYNAMIC_ARCH "Include support for multiple CPU targets, with automatic selection at runtime (x86/x86_64, aarch64, ppc or RISCV64-RVV1.0 only)" OFF)
- L40: option(DYNAMIC_OLDER "Include specific support for older x86 cpu models (Penryn,Dunnington,Atom,Nano,Opteron) with DYNAMIC_ARCH" OFF)
- L42: option(BUILD_RELAPACK "Build with ReLAPACK (recursive implementation of several LAPACK functions on top of standard LAPACK)" OFF)
- L44: option(USE_LOCKING "Use locks even in single-threaded builds to make them callable from multiple threads" OFF)
- L46: option(USE_PERL "Use the older PERL scripts for build preparation instead of universal shell scripts" OFF)
- L48: option(NO_WARMUP "Do not run a benchmark on each startup just to find the best location for the memory buffer" ON)
- L50: option(FIXED_LIBNAME "Use a non-versioned name for the library and no symbolic linking to variant names" OFF)
- L56: option(NO_AFFINITY "Disable support for CPU affinity masks to avoid binding processes from e.g. R or numpy/scipy to a single core" ON)
- L61: option(CPP_THREAD_SAFETY_TEST "Run a massively parallel DGEMM test to confirm thread safety of the library (requires OpenMP and about 1.3GB of RAM)" OFF)
- L63: option(CPP_THREAD_SAFETY_GEMV "Run a massively parallel DGEMV test to confirm thread safety of the library (requires OpenMP)" OFF)
- L64: option(BUILD_STATIC_LIBS "Build static library" OFF)
- L65: option(BUILD_SHARED_LIBS "Build shared library" OFF)

**Global Compiler Flags**
- L231: set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} /Zi")
- L232: set(CMAKE_SHARED_LINKER_FLAGS_RELEASE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE} /DEBUG /OPT:REF /OPT:ICF")
- L426: set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} /FORCE:MULTIPLE")

**Target Compile Options/Definitions**
- L605: target_compile_definitions(${target_name} PRIVATE ${define})

**add_definitions**
- (none found)

## test/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## relapack/src/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

