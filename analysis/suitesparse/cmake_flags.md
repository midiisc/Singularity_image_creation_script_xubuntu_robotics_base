# CMake Flag Inventory

_Generated on 2025-11-09T09:08:27Z_

## TestConfig/BTF/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## TestConfig/KLU/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## TestConfig/LDL/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## TestConfig/Mongoose/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## TestConfig/RBio/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## TestConfig/UMFPACK/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## TestConfig/CAMD/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## TestConfig/CCOLAMD/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## TestConfig/CHOLMOD/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## TestConfig/SPQR/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## TestConfig/ParU/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## TestConfig/SuiteSparse_config/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## TestConfig/CXSparse/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## TestConfig/SPEX/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## TestConfig/AMD/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## TestConfig/GraphBLAS/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## TestConfig/COLAMD/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## TestConfig/LAGraph/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## BTF/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## KLU/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## LDL/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## Mongoose/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L227: target_compile_definitions ( Mongoose_static PUBLIC MONGOOSE_STATIC )
- L256: target_compile_definitions ( Mongoose PRIVATE MONGOOSE_BUILDING )

**add_definitions**
- (none found)

## RBio/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## UMFPACK/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L223: target_compile_definitions ( UMFPACK PRIVATE NCHOLMOD )
- L226: target_compile_definitions ( UMFPACK_static PRIVATE NCHOLMOD )
- L284: target_compile_definitions ( UMFPACK PRIVATE "HAVE_PRAGMA_GCC_IVDEP" )
- L287: target_compile_definitions ( UMFPACK_static PRIVATE "HAVE_PRAGMA_GCC_IVDEP" )
- L308: target_compile_definitions ( UMFPACK PRIVATE "HAVE_PRAGMA_CLANG_LOOP_VECTORIZE" )
- L310: target_compile_options ( UMFPACK PRIVATE "-Wno-pass-failed" )
- L314: target_compile_definitions ( UMFPACK_static PRIVATE "HAVE_PRAGMA_CLANG_LOOP_VECTORIZE" )
- L316: target_compile_options ( UMFPACK_static PRIVATE "-Wno-pass-failed" )
- L336: target_compile_definitions ( UMFPACK PRIVATE "HAVE_PRAGMA_IVDEP" )
- L339: target_compile_definitions ( UMFPACK_static PRIVATE "HAVE_PRAGMA_IVDEP" )
- L358: target_compile_definitions ( UMFPACK PRIVATE "HAVE_PRAGMA_LOOP_IVDEP" )
- L361: target_compile_definitions ( UMFPACK_static PRIVATE "HAVE_PRAGMA_LOOP_IVDEP" )
- L382: target_compile_definitions ( UMFPACK PRIVATE "HAVE_PRAGMA_GCC_NOVECTOR" )
- L385: target_compile_definitions ( UMFPACK_static PRIVATE "HAVE_PRAGMA_GCC_NOVECTOR" )
- L404: target_compile_definitions ( UMFPACK PRIVATE "HAVE_PRAGMA_NOVECTOR" )
- L407: target_compile_definitions ( UMFPACK_static PRIVATE "HAVE_PRAGMA_NOVECTOR" )
- L426: target_compile_definitions ( UMFPACK PRIVATE "HAVE_PRAGMA_LOOP_NO_VECTOR" )
- L429: target_compile_definitions ( UMFPACK_static PRIVATE "HAVE_PRAGMA_LOOP_NO_VECTOR" )

**add_definitions**
- (none found)

## CAMD/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## CCOLAMD/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## CHOLMOD/GPU/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L56: #   target_compile_definitions ( CHOLMOD PUBLIC "CHOLMOD_HAS_CUDA" )
- L65: #   target_compile_definitions ( CHOLMOD_static PUBLIC "CHOLMOD_HAS_CUDA" )

**add_definitions**
- (none found)

## CHOLMOD/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L622: target_compile_definitions ( CHOLMOD PRIVATE NCOMPAR_FN_T )
- L625: target_compile_definitions ( CHOLMOD_static PRIVATE NCOMPAR_FN_T )

**add_definitions**
- (none found)

## CHOLMOD/SuiteSparse_metis/include/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## CHOLMOD/SuiteSparse_metis/GKlib/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## CHOLMOD/SuiteSparse_metis/GKlib/test/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## CHOLMOD/SuiteSparse_metis/programs/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- L31: add_definitions(-DSVNINFO="${SVNREV}")

## CHOLMOD/SuiteSparse_metis/libmetis/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## CHOLMOD/SuiteSparse_metis/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## CSparse/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## SPQR/GPUQREngine/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L108: target_compile_definitions ( GPUQREngine PRIVATE "SPQR_HAS_CUDA" )
- L151: target_compile_definitions ( GPUQREngine_static PRIVATE "SPQR_HAS_CUDA" )

**add_definitions**
- (none found)

## SPQR/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L188: target_compile_definitions ( SPQR PUBLIC "SPQR_HAS_CUDA" )
- L193: target_compile_definitions ( SPQR_static PUBLIC "SPQR_HAS_CUDA" )

**add_definitions**
- (none found)

## SPQR/GPURuntime/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L81: target_compile_definitions ( GPURuntime PRIVATE "SPQR_HAS_CUDA" )
- L121: target_compile_definitions ( GPURuntime_static PRIVATE "SPQR_HAS_CUDA" )

**add_definitions**
- (none found)

## SPQR/SPQRGPU/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L40: target_compile_definitions ( SPQR PRIVATE "SPQR_HAS_CUDA" )
- L49: target_compile_definitions ( SPQR_static PRIVATE "SPQR_HAS_CUDA" )

**add_definitions**
- (none found)

## ParU/Demo/Benchmarking/superlu_mt_401_benchmarking/CMakeLists.txt

**Options**
- L38: option(enable_internal_blaslib  "Build the CBLAS library" ${enable_blaslib_xSDK})
- L39: option(enable_single    "Enable single precision library" ON)
- L40: option(enable_double    "Enable double precision library" ON)
- L41: option(enable_complex   "Enable complex precision library" ON)
- L42: option(enable_complex16 "Enable complex16 precision library" ON)
- L43: option(enable_matlabmex "Build the Matlab mex library" OFF)
- L44: option(enable_doc       "Add target 'doc' to build Doxygen documentation" OFF)
- L45: option(enable_examples  "Build examples" ON)
- L46: option(enable_fortran   "Build Fortran interface" ${enable_fortran_xSDK})
- L47: option(enable_tests     "Build tests" ON)
- L74: option(TPL_ENABLE_INTERNAL_BLASLIB  "Build the CBLAS library" ${enable_internal_blaslib})
- L75: option(TPL_BLAS_LIBRARIES "List of absolute paths to blas libraries [].")

**Global Compiler Flags**
- L108: set(CMAKE_C_FLAGS "-DUSE_VENDOR_BLAS ${CMAKE_C_FLAGS}")

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## ParU/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L205: target_compile_definitions (ParU PRIVATE PARU_1TASK )
- L208: target_compile_definitions (ParU_static PRIVATE PARU_1TASK )

**add_definitions**
- (none found)

## SuiteSparse_config/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## CXSparse/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## SPEX/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## AMD/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## GraphBLAS/cpu_features/cmake/ci/sample/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## GraphBLAS/cpu_features/ndk_compat/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## GraphBLAS/cpu_features/CMakeLists.txt

**Options**
- L16: option(BUILD_TESTING "Enable test rule" OFF)
- L18: option(BUILD_TESTING "Enable test rule" ON)
- L31: option(BUILD_EXECUTABLE "Build list_cpu_features executable." OFF)
- L33: option(BUILD_EXECUTABLE "Build list_cpu_features executable." ON)
- L39: option(ENABLE_INSTALL "Enable install targets" OFF)
- L41: option(ENABLE_INSTALL "Enable install targets" ON)
- L49: option(BUILD_SHARED_LIBS "Build library as shared." OFF)
- L54: option(CMAKE_POSITION_INDEPENDENT_CODE "Build with Position Independant Code." ON)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L66: target_compile_definitions(${TARGET_NAME}
- L154: target_compile_definitions(unix_based_hardware_detection PRIVATE HAVE_DLFCN_H)
- L158: target_compile_definitions(unix_based_hardware_detection PRIVATE HAVE_STRONG_GETAUXVAL)
- L181: target_compile_definitions(cpu_features PRIVATE HAVE_SYSCTLBYNAME)

**add_definitions**
- (none found)

## GraphBLAS/cpu_features/test/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L12: target_compile_definitions(filesystem_for_testing PUBLIC CPU_FEATURES_MOCK_FILESYSTEM)
- L18: target_compile_definitions(stack_line_reader PUBLIC STACK_LINE_READER_BUFFER_SIZE=1024)
- L22: target_compile_definitions(stack_line_reader_for_test PUBLIC STACK_LINE_READER_BUFFER_SIZE=16)
- L57: target_compile_definitions(cpuinfo_x86_test PUBLIC CPU_FEATURES_MOCK_CPUID_X86)
- L59: target_compile_definitions(cpuinfo_x86_test PRIVATE HAVE_SYSCTLBYNAME)
- L81: target_compile_definitions(cpuinfo_aarch64_test PUBLIC CPU_FEATURES_MOCK_SYSCTL_AARCH64)
- L82: target_compile_definitions(cpuinfo_aarch64_test PRIVATE HAVE_SYSCTLBYNAME)
- L84: target_compile_definitions(cpuinfo_aarch64_test PUBLIC CPU_FEATURES_MOCK_CPUID_AARCH64)

**add_definitions**
- L6: add_definitions(-DCPU_FEATURES_TEST)

## GraphBLAS/CUDA/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L70: target_compile_definitions ( GraphBLAS_CUDA PRIVATE GBNVTX )
- L73: target_compile_definitions ( GraphBLAS_CUDA PUBLIC "GRAPHBLAS_HAS_CUDA" )

**add_definitions**
- (none found)

## GraphBLAS/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L329: target_compile_definitions ( GraphBLAS PRIVATE "GRAPHBLAS_HAS_CUDA" )
- L334: target_compile_definitions ( GraphBLAS PRIVATE GB_DLL_EXPORT )
- L377: target_compile_definitions ( GraphBLAS_static PRIVATE "GRAPHBLAS_HAS_CUDA" )
- L382: target_compile_definitions ( GraphBLAS_static PUBLIC GB_STATIC )
- L407: target_compile_definitions ( GraphBLAS PRIVATE HAVE_DLFCN_H )
- L410: target_compile_definitions ( GraphBLAS_static PRIVATE HAVE_DLFCN_H )
- L419: target_compile_definitions ( GraphBLAS PRIVATE HAVE_STRONG_GETAUXVAL )
- L422: target_compile_definitions ( GraphBLAS_static PRIVATE HAVE_STRONG_GETAUXVAL )

**add_definitions**
- (none found)

## GraphBLAS/JITpackage/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## GraphBLAS/rmm_wrap/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## GraphBLAS/GraphBLAS/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L303: target_compile_definitions ( graphblas_matlab PRIVATE HAVE_DLFCN_H )
- L307: target_compile_definitions ( graphblas_matlab PRIVATE HAVE_STRONG_GETAUXVAL )

**add_definitions**
- (none found)

## COLAMD/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## Example/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L321: target_compile_definitions ( my PRIVATE NO_GRAPHBLAS )
- L322: target_compile_definitions ( my_cxx PRIVATE NO_GRAPHBLAS )
- L325: target_compile_definitions ( my_static PRIVATE NO_GRAPHBLAS )
- L326: target_compile_definitions ( my_cxx_static PRIVATE NO_GRAPHBLAS )
- L377: target_compile_definitions ( my PRIVATE NO_LAGRAPH )
- L378: target_compile_definitions ( my_cxx PRIVATE NO_LAGRAPH )
- L381: target_compile_definitions ( my_static PRIVATE NO_LAGRAPH )
- L382: target_compile_definitions ( my_cxx_static PRIVATE NO_LAGRAPH )

**add_definitions**
- (none found)

## LAGraph/src/benchmark/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## LAGraph/src/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L48: target_compile_definitions ( LAGraph PRIVATE LG_LIBRARY )
- L49: target_compile_definitions ( LAGraph PUBLIC LG_DLL )

**add_definitions**
- (none found)

## LAGraph/src/test/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L49: target_compile_definitions ( lagraphtest PRIVATE LG_TEST_LIBRARY )
- L50: target_compile_definitions ( lagraphtest PUBLIC LG_TEST_DLL )

**add_definitions**
- (none found)

## LAGraph/experimental/benchmark/matching-tests/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## LAGraph/experimental/benchmark/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## LAGraph/experimental/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L47: target_compile_definitions ( LAGraphX PRIVATE LGX_LIBRARY )
- L48: target_compile_definitions ( LAGraphX PUBLIC LGX_DLL )

**add_definitions**
- (none found)

## LAGraph/experimental/test/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L47: target_compile_definitions ( lagraphxtest PRIVATE LGX_TEST_LIBRARY )
- L48: target_compile_definitions ( lagraphxtest PUBLIC LGX_TEST_DLL )

**add_definitions**
- (none found)

## LAGraph/deps/json_h/test/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L71: target_compile_options(json_test PUBLIC -fno-omit-frame-pointer -fsanitize=${JSON_USE_SANITIZER})

**add_definitions**
- (none found)

## LAGraph/rtdocs/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## LAGraph/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

