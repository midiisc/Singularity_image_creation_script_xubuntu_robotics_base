# Dependency Signals

_Generated on 2025-11-09T09:08:59Z_

## find_package Calls

- BLAS
- CpuFeatures
- Doxygen
- Sphinx
- Threads

## target_link_libraries

- Target: ${prog} | Scope: | Links: GKlib
- Target: ${prog} | Scope: | Links: metis
- Target: ${prog} | Scope: | Links: metis profiler
- Target: all_libraries | Scope: | Links: hwcaps_for_testing stack_line_reader string_view
- Target: cpu_features | Scope: PUBLIC | Links: ${CMAKE_DL_LIBS}
- Target: cpuinfo_aarch64_test | Scope: | Links: all_libraries
- Target: cpuinfo_arm_test | Scope: | Links: all_libraries
- Target: cpuinfo_loongarch_test | Scope: | Links: all_libraries
- Target: cpuinfo_mips_test | Scope: | Links: all_libraries
- Target: cpuinfo_ppc_test | Scope: | Links: all_libraries
- Target: cpuinfo_riscv_test | Scope: | Links: all_libraries
- Target: cpuinfo_s390x_test | Scope: | Links: all_libraries
- Target: cpuinfo_x86_test | Scope: | Links: all_libraries
- Target: GKlib | Scope: PUBLIC | Links: m
- Target: hwcaps_for_testing | Scope: | Links: filesystem_for_testing
 target_link_libraries( ${demoname}
 target_link_libraries( ${demoname} LAGraph LAGraphX lagraphtest GraphBLAS::GraphBLAS )
 target_link_libraries( ${demoname} LAGraph_static LAGraphX_static lagraphtest_static GraphBLAS::GraphBLAS )
 target_link_libraries( ${testname}
 target_link_libraries( ${testname} LAGraph LAGraphX lagraphtest GraphBLAS::GraphBLAS )
 target_link_libraries( ${testname} LAGraph_static LAGraphX_static lagraphtest_static GraphBLAS::GraphBLAS )
target_link_libraries(bit_utils_test)
- Target: list_cpu_features | Scope: PRIVATE | Links: cpu_features
- Target: metis | Scope: | Links: m
- Target: ndk_compat | Scope: PUBLIC | Links: ${CMAKE_DL_LIBS} ${CMAKE_THREAD_LIBS_INIT}
- Target: ndk-compat-test | Scope: PRIVATE | Links: ndk_compat
- Target: sample | Scope: PRIVATE | Links: CpuFeatures::cpu_features
- Target: stack_line_reader_for_test | Scope: | Links: string_view filesystem_for_testing
- Target: stack_line_reader | Scope: | Links: string_view
- Target: stack_line_reader_test | Scope: | Links: stack_line_reader_for_test
- Target: string_view_test | Scope: | Links: string_view

## FetchContent_Declare

- (none found)

## pkg_check_modules

- (none found)

