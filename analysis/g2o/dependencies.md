# Dependency Signals

_Generated on 2025-11-09T08:55:36Z_

## find_package Calls

- benchmark
- CHOLMOD
- CSparse
- Eigen3
- OpenGL
- OpenMP
- QGLViewer
- spdlog

## target_link_libraries

- Target: ${target} | Scope: | Links: gtest gmock gtest_main
- Target: ba_anchored_inverse_depth_demo | Scope: | Links: core types_sba
- Target: ba_anchored_inverse_depth_demo | Scope: | Links: solver_cholmod
- Target: ba_anchored_inverse_depth_demo | Scope: | Links: solver_eigen
- Target: ba_demo | Scope: | Links: core types_sba solver_dense
- Target: ba_demo | Scope: | Links: solver_cholmod
- Target: ba_demo | Scope: | Links: solver_eigen
- Target: bal_example | Scope: | Links: solver_cholmod
- Target: bal_example | Scope: | Links: solver_eigen
- Target: benchmark_jacobian_timing | Scope: | Links: benchmark::benchmark Eigen3::Eigen
- Target: calibration_odom_laser_library | Scope: | Links: core solver_eigen types_sclam2d types_data
- Target: circle_fit | Scope: | Links: core solver_dense
- Target: constant_velocity_target | Scope: | Links: core solver_eigen solver_pcg
- Target: convert_sba_slam3d | Scope: | Links: core types_slam3d types_sba
- Target: convertSegmentLine_application | Scope: | Links: types_slam2d_addons types_slam3d types_slam2d core stuff
- Target: core | Scope: PUBLIC | Links: g2o_ceres_ad
- Target: core | Scope: PUBLIC | Links: stuff Eigen3::Eigen
- Target: create_sphere | Scope: | Links: core types_slam3d
- Target: csparse_extension | Scope: PUBLIC | Links: stuff ${CSPARSE_LIBRARY} Eigen3::Eigen
- Target: curve_fit | Scope: | Links: core solver_dense
- Target: example_library | Scope: | Links: parser_library interface_library
- Target: freeglut_minimal | Scope: PUBLIC | Links: ${G2O_OPENGL_TARGET}
- Target: g2o_anonymize_observations_application | Scope: | Links: types_slam3d types_slam2d core
- Target: g2o_cli_application_linked | Scope: | Links: g2o_cli_library
- Target: g2o_cli_application_linked | Scope: | Links: solver_cholmod
- Target: g2o_cli_application_linked | Scope: | Links: solver_csparse solver_pcg
- Target: g2o_cli_application_linked | Scope: | Links: types_slam2d types_slam3d types_sba types_sclam2d
- Target: g2o_cli_application | Scope: | Links: g2o_cli_library
- Target: g2o_cli_library | Scope: | Links: ${CMAKE_DL_LIBS}
- Target: g2o_cli_library | Scope: | Links: core
- Target: g2o_hierarchical_application | Scope: | Links: g2o_hierarchical_library g2o_cli_library types_slam3d 
- Target: g2o_hierarchical_library | Scope: | Links: core
- Target: g2o_incremental_application | Scope: | Links: g2o_incremental_library
- Target: g2o_incremental_library | Scope: | Links: g2o_interactive_library solver_cholmod ${CAMD_LIBRARY} SuiteSparse::CHOLMOD
- Target: g2o_interactive_library | Scope: | Links: core types_slam2d types_slam3d solver_cholmod parser_library interface_library
- Target: g2o_online_application | Scope: | Links: g2o_interactive_library
- Target: g2o_simulator2d_application | Scope: | Links: g2o_simulator_library types_slam2d_addons types_slam2d core
- Target: g2o_simulator3d_application | Scope: | Links: g2o_simulator_library types_slam3d_addons types_slam3d types_slam2d_addons types_slam2d core
- Target: g2o_simulator_library | Scope: | Links: types_slam3d_addons types_slam3d types_slam2d_addons types_slam2d core
- Target: g2o_viewer_linked | Scope: | Links: solver_cholmod
- Target: g2o_viewer_linked | Scope: | Links: solver_csparse solver_pcg
- Target: g2o_viewer_linked | Scope: | Links: types_slam2d types_slam3d types_sba types_sclam2d
- Target: g2o_viewer_linked | Scope: | Links: viewer_library
- Target: g2o_viewer | Scope: | Links: viewer_library
- Target: generate_commands_application | Scope: | Links: g2o_interactive_library
- Target: gicp_demo | Scope: | Links: core types_sba types_slam3d types_icp ${OPENGL_LIBRARIES} solver_eigen
- Target: gicp_sba_demo | Scope: | Links: core types_sba types_slam3d types_icp ${OPENGL_LIBRARIES} solver_eigen
- Target: interface_library | Scope: | Links: parser_library
- Target: line_test | Scope: | Links: types_slam3d_addons types_slam3d
target_link_libraries(slam2d_g2o core solver_eigen types_slam2d opengl_helper
target_link_libraries(solver_cholmod
target_link_libraries(solver_csparse
- Target: logging_application | Scope: | Links: stuff
- Target: opengl_helper | Scope: PUBLIC | Links: ${G2O_OPENGL_TARGET} Eigen3::Eigen
- Target: optimize_sphere_by_sim3 | Scope: | Links: core types_slam3d types_sim3
- Target: polynomial_fit | Scope: | Links: core solver_eigen
- Target: sba_demo | Scope: | Links: core types_icp types_sba
- Target: sba_demo | Scope: | Links: solver_cholmod
- Target: sba_demo | Scope: | Links: solver_eigen
- Target: sclam_laser_calib | Scope: | Links: calibration_odom_laser_library
- Target: sclam_odom_laser | Scope: | Links: calibration_odom_laser_library
- Target: sclam_pure_calibration | Scope: | Links: calibration_odom_laser_library
- Target: simple_optimize | Scope: | Links: core solver_eigen
- Target: simple_optimize | Scope: | Links: types_slam2d
- Target: simple_optimize | Scope: | Links: types_slam3d
- Target: simulator_3d_line | Scope: | Links: solver_eigen types_slam3d_addons
- Target: simulator_3d_plane | Scope: | Links: solver_eigen types_slam3d_addons
- Target: solver_dense | Scope: | Links: core
- Target: solver_eigen | Scope: | Links: core
- Target: solver_pcg | Scope: | Links: core
- Target: solver_slam2d_linear | Scope: | Links: solver_eigen types_slam2d
- Target: solver_structure_only | Scope: | Links: core
- Target: static_dynamic_function_fit | Scope: | Links: core solver_eigen
- Target: static_target | Scope: | Links: core solver_eigen
- Target: stuff | Scope: PUBLIC | Links: Eigen3::Eigen
- Target: stuff | Scope: PUBLIC | Links: rt
- Target: stuff | Scope: PUBLIC | Links: spdlog::spdlog
- Target: stuff | Scope: PUBLIC | Links: spdlog::spdlog_header_only
- Target: test_slam_interface | Scope: | Links: example_library
- Target: test_slam_parser | Scope: | Links: parser_library
- Target: tutorial_slam2d_library | Scope: | Links: core solver_eigen
- Target: tutorial_slam2d | Scope: | Links: tutorial_slam2d_library
- Target: types_data | Scope: | Links: core types_slam2d
- Target: types_data | Scope: | Links: freeglut_minimal opengl_helper
- Target: types_icp | Scope: | Links: types_sba types_slam3d
- Target: types_sba | Scope: | Links: core types_slam3d
- Target: types_sclam2d | Scope: | Links: opengl_helper
- Target: types_sclam2d | Scope: | Links: types_slam2d core
- Target: types_sim3 | Scope: PUBLIC | Links: types_sba
- Target: types_slam2d_addons | Scope: | Links: opengl_helper
- Target: types_slam2d_addons | Scope: | Links: types_slam2d core
- Target: types_slam2d | Scope: | Links: core
- Target: types_slam2d | Scope: | Links: opengl_helper
- Target: types_slam3d_addons | Scope: | Links: opengl_helper
- Target: types_slam3d_addons | Scope: | Links: types_slam3d core
- Target: types_slam3d | Scope: | Links: core
- Target: types_slam3d | Scope: | Links: opengl_helper
- Target: unittest_data | Scope: | Links: types_data stuff
- Target: unittest_general | Scope: | Links: types_slam3d types_slam2d
- Target: unittest_icp | Scope: | Links: types_icp
- Target: unittest_sba | Scope: | Links: types_sba
- Target: unittest_sclam2d | Scope: | Links: types_sclam2d
- Target: unittest_sim3 | Scope: | Links: types_sim3
- Target: unittest_slam2d_addons | Scope: | Links: types_slam2d_addons
- Target: unittest_slam2d | Scope: | Links: types_slam2d
- Target: unittest_slam3d_addons | Scope: | Links: types_slam3d_addons
- Target: unittest_slam3d | Scope: | Links: types_slam3d
- Target: unittest_solver | Scope: | Links: ${SOLVER_LIBRARIES}
- Target: unittest_stuff | Scope: | Links: stuff
- Target: viewer_library | Scope: | Links: core g2o_cli_library ${QGLVIEWER_LIBRARY} ${MY_QT_LIBRARIES} ${OPENGL_LIBRARY}
- Target: viewer_library | Scope: | Links: core opengl_helper

## FetchContent_Declare

FetchContent_Declare(

## pkg_check_modules

- (none found)

