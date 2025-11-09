# Dependency Signals

_Generated on 2025-11-09T09:07:33Z_

## find_package Calls

- BLAS
- codecov
- Doxygen
- LAPACK
- OpenMP
- PythonInterp
- Threads

## target_link_libraries

- Target: ${CBLASLIB} | Scope: PRIVATE | Links: ${BLAS_LIBRARIES}
- Target: ${LAPACKELIB} | Scope: PRIVATE | Links: ${LAPACK_LIBRARIES}
- Target: ${LAPACKELIB} | Scope: PRIVATE | Links: ${TMGLIB}
- Target: ${LAPACKLIB} | Scope: PRIVATE | Links: ${BLAS_LIBRARIES}
- Target: ${LAPACKLIB} | Scope: PRIVATE | Links: ${XBLAS_LIBRARY}
- Target: ${LAPACKLIB} | Scope: PRIVATE | Links: gcov
- Target: ${name} | Scope: | Links: ${BLASLIB}
- Target: ${name} | Scope: | Links: ${LIBNAMEPREFIX}openblas${LIBNAMESUFFIX}${SUFFIX64_UNDERSCORE}
- Target: ${OpenBLAS_LIBNAME}_shared | Scope: | Links: ${CMAKE_THREAD_LIBS_INIT}
- Target: ${OpenBLAS_LIBNAME}_shared | Scope: | Links: m
- Target: ${OpenBLAS_LIBNAME}_shared | Scope: | Links: OpenMP::OpenMP_C
- Target: ${OpenBLAS_LIBNAME}_shared | Scope: | Links: OpenMP::OpenMP_C OpenMP::OpenMP_Fortran
- Target: ${OpenBLAS_LIBNAME}_shared | Scope: | Links: "-Wl,-allow-multiple-definition"
- Target: ${OpenBLAS_LIBNAME}_static | Scope: | Links: ${CMAKE_THREAD_LIBS_INIT}
- Target: ${OpenBLAS_LIBNAME}_static | Scope: | Links: m
- Target: ${OpenBLAS_LIBNAME}_static | Scope: | Links: OpenMP::OpenMP_C
- Target: ${OpenBLAS_LIBNAME}_static | Scope: | Links: OpenMP::OpenMP_C OpenMP::OpenMP_Fortran
- Target: ${OpenBLAS_utest_bin} | Scope: | Links: ${OpenBLAS_LIBNAME}
- Target: ${OpenBLAS_utest_bin} | Scope: | Links: m
- Target: ${OpenBLAS_utest_ext_bin} | Scope: | Links: ${OpenBLAS_LIBNAME}
- Target: ${target_name} | Scope: | Links: ${OpenBLAS_LIBNAME} 
- Target: ${target_name} | Scope: | Links: ${OpenBLAS_LIBNAME} OpenMP::OpenMP_C
- Target: ${test_bin} | Scope: | Links: ${OpenBLAS_LIBNAME}
- Target: ${TMGLIB} | Scope: | Links: ${LAPACK_LIBRARIES} ${BLAS_LIBRARIES}
- Target: dgemm_thread_safety | Scope: | Links: ${OpenBLAS_LIBNAME}
- Target: dgemv_thread_safety | Scope: | Links: ${OpenBLAS_LIBNAME}
- Target: driver_level2 | Scope: | Links: OpenMP::OpenMP_C
- Target: driver_level3 | Scope: | Links: OpenMP::OpenMP_C
- Target: driver_others | Scope: | Links: OpenMP::OpenMP_C
- Target: interface | Scope: | Links: OpenMP::OpenMP_C
- Target: kernel${TSUFFIX} | Scope: | Links: OpenMP::OpenMP_C
- Target: LAPACK_OVERRIDES | Scope: | Links: OpenMP::OpenMP_Fortran
- Target: lapack | Scope: | Links: OpenMP::OpenMP_C
- Target: x${float_char}cblat1 | Scope: | Links: ${OpenBLAS_LIBNAME}
- Target: x${float_char}cblat1 | Scope: | Links: m
- Target: x${float_char}cblat2 | Scope: | Links: ${OpenBLAS_LIBNAME}
- Target: x${float_char}cblat2 | Scope: | Links: m
- Target: x${float_char}cblat3_3m | Scope: | Links: ${OpenBLAS_LIBNAME}
- Target: x${float_char}cblat3_3m | Scope: | Links: m
- Target: x${float_char}cblat3 | Scope: | Links: ${OpenBLAS_LIBNAME}
- Target: x${float_char}cblat3 | Scope: | Links: m
- Target: xccblat1 | Scope: | Links: ${CBLASLIB} ${BLAS_LIBRARIES}
- Target: xccblat2 | Scope: | Links: ${CBLASLIB}
- Target: xccblat3 | Scope: | Links: ${CBLASLIB}
- Target: xdcblat1 | Scope: | Links: ${CBLASLIB}
- Target: xdcblat2 | Scope: | Links: ${CBLASLIB}
- Target: xdcblat3 | Scope: | Links: ${CBLASLIB}
- Target: xexample1_CBLAS | Scope: | Links: ${CBLASLIB}
- Target: xexample2_CBLAS | Scope: | Links: ${CBLASLIB} ${BLAS_LIBRARIES}
- Target: xexample_DGELS_colmajor | Scope: | Links: ${LAPACKELIB}
- Target: xexample_DGELS_rowmajor | Scope: | Links: ${LAPACKELIB}
- Target: xexample_DGESV_colmajor | Scope: | Links: ${LAPACKELIB}
- Target: xexample_DGESV_rowmajor | Scope: | Links: ${LAPACKELIB}
- Target: xscblat1 | Scope: | Links: ${CBLASLIB}
- Target: xscblat2 | Scope: | Links: ${CBLASLIB}
- Target: xscblat3 | Scope: | Links: ${CBLASLIB}
- Target: xzcblat1 | Scope: | Links: ${CBLASLIB}
- Target: xzcblat2 | Scope: | Links: ${CBLASLIB}
- Target: xzcblat3 | Scope: | Links: ${CBLASLIB}

## FetchContent_Declare

- (none found)

## pkg_check_modules

- (none found)

