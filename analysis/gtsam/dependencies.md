# Dependency Signals

_Generated on 2025-11-09T09:09:46Z_

## find_package Calls

- ACML
- Adolc
- ATLAS
- BLAZE
- Blitz
- Boost
- Catch
- Cholmod
- CUDA
- Doxygen
- Eigen2
- Eigen3
- FFTW
- GLEW
- GLUT
- GMM
- GMP
- GoogleHash
- GTSAM
- GTSAMCMakeTools
- LAPACK
- MKL
- MPFR
- MTL4
- OPENBLAS
- OpenGL
- PASTIX
- pybind11
- PythonInterp
- Qt4
- SPQR
- StandardMathLibrary
- SuperLU
- Tensor
- Threads
- Tvmet
- Umfpack

## target_link_libraries

- Target: ${compile_snippet_target} | Scope: | Links: ${EIGEN_STANDARD_LIBRARIES_TO_LINK_TO}
- Target: ${example} | Scope: | Links: ${EIGEN_STANDARD_LIBRARIES_TO_LINK_TO}
- Target: ${prog} | Scope: | Links: GKlib
- Target: ${prog} | Scope: | Links: metis
- Target: ${prog} | Scope: | Links: metis profiler
- Target: ${targetname} | Scope: | Links: ${DEFAULT_LIBRARIES} ${EIGEN_BTL_RT_LIBRARY}
- Target: ${targetname} | Scope: | Links: ${EIGEN_STANDARD_LIBRARIES_TO_LINK_TO}
- Target: ${targetname} | Scope: | Links: ${EXTERNAL_LIBS}
- Target: ${targetname} | Scope: | Links: eigen_blas
- Target: ${target} | Scope: PRIVATE | Links: ${STD_FS_LIB}
- Target: ${target} | Scope: PRIVATE | Links: Boost::headers
- Target: ${target} | Scope: PRIVATE | Links: Eigen3::Eigen
- Target: btl_acml | Scope: | Links: ${ACML_LIBRARIES} 
- Target: btl_atlas | Scope: | Links: ${ATLAS_LIBRARIES}
- Target: btl_blaze | Scope: | Links: ${Boost_LIBRARIES}
- Target: btl_blitz | Scope: | Links: ${BLITZ_LIBRARIES}
- Target: btl_eigen3_adv | Scope: | Links: ${MKL_LIBRARIES}
- Target: btl_eigenblas | Scope: | Links: eigen_blas eigen_lapack 
- Target: btl_mkl | Scope: | Links: ${MKL_LIBRARIES}
- Target: btl_openblas | Scope: | Links: ${OPENBLAS_LIBRARIES} 
- Target: btl_tiny_blitz | Scope: | Links: ${BLITZ_LIBRARIES}
- Target: CppUnitLite | Scope: PUBLIC | Links: Boost::boost
- Target: eigen_blas | Scope: | Links: ${EIGEN_STANDARD_LIBRARIES_TO_LINK_TO}
- Target: eigen_blas_static | Scope: | Links: ${EIGEN_STANDARD_LIBRARIES_TO_LINK_TO}
- Target: eigen_lapack | Scope: | Links: ${EIGEN_STANDARD_LIBRARIES_TO_LINK_TO}
- Target: eigen_lapack | Scope: | Links: eigen_blas
- Target: eigen_lapack_static | Scope: | Links: ${EIGEN_STANDARD_LIBRARIES_TO_LINK_TO}
- Target: example_${example} | Scope: | Links: ${EIGEN_STANDARD_LIBRARIES_TO_LINK_TO}
- Target: example | Scope: PRIVATE | Links: gtsam
- Target: GKlib | Scope: | Links: m
- Target: gtsam | Scope: PRIVATE | Links: Dbghelp
- Target: gtsam | Scope: PUBLIC | Links: ${GTSAM_ADDITIONAL_LIBRARIES}
- Target: gtsam | Scope: PUBLIC | Links: ${GTSAM_BOOST_LIBRARIES}
- Target: gtsam | Scope: PUBLIC | Links: Eigen3::Eigen
- Target: gtsam_unstable | Scope: PUBLIC | Links: gtsam
 target_link_libraries(quaternion_demo
- Target: mandelbrot | Scope: | Links: ${QT_QTCORE_LIBRARY} ${QT_QTGUI_LIBRARY}
- Target: metis-gtsam | Scope: | Links: m
- Target: random_cpp11 | Scope: | Links: ${EIGEN_STANDARD_LIBRARIES_TO_LINK_TO}
- Target: test_embed_lib | Scope: PRIVATE | Links: pybind11::embed
- Target: test_embed | Scope: PRIVATE | Links: pybind11::embed Catch2::Catch2 Threads::Threads
- Target: test_installed_embed | Scope: PRIVATE | Links: pybind11::embed
- Target: test_installed_target | Scope: PRIVATE | Links: pybind11::module
- Target: test_subdirectory_embed | Scope: PRIVATE | Links: pybind11::embed
- Target: test_subdirectory_target | Scope: PRIVATE | Links: pybind11::module
- Target: timeGaussianFactorGraph | Scope: | Links: CppUnitLite
- Target: Tutorial_sparse_example | Scope: | Links: ${EIGEN_STANDARD_LIBRARIES_TO_LINK_TO} ${QT_QTCORE_LIBRARY} ${QT_QTGUI_LIBRARY}

## FetchContent_Declare

    FetchContent_Declare(

## pkg_check_modules

- (none found)

