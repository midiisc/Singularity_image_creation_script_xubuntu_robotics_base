# Dependency Signals

_Generated on 2025-11-09T09:11:43Z_

## find_package Calls

- benchmark
- colmap
- pybind11
- Python

## target_link_libraries

- Target: benchmark_cost_functions | Scope: PRIVATE | Links: colmap::colmap benchmark::benchmark
- Target: colmap_estimators | Scope: PUBLIC | Links: colmap_util_cuda
- Target: colmap_feature | Scope: PRIVATE | Links: colmap_sift_gpu
- Target: colmap_feature | Scope: PRIVATE | Links: GLEW::GLEW
- Target: colmap_feature_sift_test | Scope: | Links: Qt${QT_VERSION_MAJOR}::Widgets
- Target: colmap_image | Scope: PRIVATE | Links: colmap_lsd
- Target: colmap_mvs | Scope: PRIVATE | Links: CGAL
- Target: colmap_poisson_recon | Scope: PRIVATE | Links: OpenMP::OpenMP_CXX
- Target: colmap_retrieval | Scope: PUBLIC | Links: OpenMP::OpenMP_CXX
- Target: colmap | Scope: INTERFACE | Links: ${COLMAP_EXPORT_LIBS}
- Target: colmap_util | Scope: PRIVATE | Links: cryptopp::cryptopp
- Target: colmap_util | Scope: PRIVATE | Links: CURL::libcurl
- Target: colmap_util | Scope: PRIVATE | Links: OpenSSL::Crypto
- Target: colmap_util | Scope: PUBLIC | Links: ${COLMAP_UTIL_QT_LIBS} OpenGL::GL
- Target: colmap_vlfeat | Scope: PRIVATE | Links: OpenMP::OpenMP_C
- Target: _core | Scope: PRIVATE | Links: colmap::colmap glog::glog Ceres::ceres
- Target: hello_world | Scope: | Links: colmap::colmap

## FetchContent_Declare

- faiss
- poselib

## pkg_check_modules

- (none found)

