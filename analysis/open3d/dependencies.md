# Dependency Signals

_Generated on 2025-11-09T09:13:12Z_

## find_package Calls

- CUDAToolkit
- IntelSYCL
- Open3D
- OSMesa
- Python3
- PythonInterp
- Pytorch
- Tensorflow
- Threads

## target_link_libraries

- Target: ${EXAMPLE_CPP_NAME} | Scope: PRIVATE | Links: Open3D::Open3D ${ARGN}
- Target: ${TARGET_NAME} | Scope: PRIVATE | Links: Open3D::Open3D TBB::tbb ${ARGN}
- Target: ${TOOL_NAME} | Scope: PRIVATE | Links: Open3D::Open3D ${ARGN}
- Target: benchmarks | Scope: PRIVATE | Links: benchmark::benchmark
- Target: benchmarks | Scope: PRIVATE | Links: CUDA::cudart
- Target: benchmarks | Scope: PRIVATE | Links: Open3D::Open3D
- Target: Draw | Scope: PRIVATE | Links: Open3D::Open3D
target_link_libraries(ManuallyAlignPointCloud PRIVATE
 target_link_libraries(open3d_tf_ops PRIVATE
target_link_libraries(open3d_tf_ops PRIVATE
 target_link_libraries(open3d_torch_ops PRIVATE
target_link_libraries(open3d_torch_ops PRIVATE
 target_link_libraries(tests PRIVATE
target_link_libraries(tests PRIVATE
- Target: Open3DHelper | Scope: INTERFACE | Links: Open3D
- Target: pybind | Scope: PRIVATE | Links: Open3D::Open3D
- Target: tests | Scope: PRIVATE | Links: CUDA::cudart

## FetchContent_Declare

- (none found)

## pkg_check_modules

- (none found)

