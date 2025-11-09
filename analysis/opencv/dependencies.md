# Dependency Signals

_Generated on 2025-11-09T09:11:19Z_

## find_package Calls

- ${hal}
- Caffe
- ComputeCpp
- dnnl
- Doxygen
- Flake8
- Java
- JNI
- OpenCL
- OpenCV
- OpenMP
- PkgConfig
- SYCL
- TBB
- Threads
- X11

## target_link_libraries

ocv_target_link_libraries(${histogram} PRIVATE ${OPENCV_LINKER_LIBS}
ocv_target_link_libraries(${norm} PRIVATE ${OPENCV_LINKER_LIBS}
 ocv_target_link_libraries(${tgt} PRIVATE
ocv_target_link_libraries(${the_module} PRIVATE
 ocv_target_link_libraries(${the_module} PUBLIC jnigraphics # for Mat <=> Bitmap converters
 ocv_target_link_libraries(${the_module} PUBLIC log dl z
- Target: ${ITT_LIBRARY} | Scope: | Links: dl
- Target: ${OPENJPEG_LIBRARY_NAME} | Scope: PRIVATE | Links: ${CMAKE_THREAD_LIBS_INIT}
- Target: ${OPENJPEG_LIBRARY_NAME} | Scope: PRIVATE | Links: m
- Target: ${PNG_LIBRARY} | Scope: | Links: ${ZLIB_LIBRARIES}
- Target: ${SPNG_LIBRARY} | Scope: | Links: ${ZLIB_LIBRARIES}
- Target: ${target}pnp_detection | Scope: PRIVATE | Links: ${OPENCV_LINKER_LIBS} ${OPENCV_CPP_SAMPLES_REQUIRED_DEPS}
- Target: ${target}pnp_registration | Scope: PRIVATE | Links: ${OPENCV_LINKER_LIBS} ${OPENCV_CPP_SAMPLES_REQUIRED_DEPS}
- Target: ${target} | Scope: | Links: ${ANDROID_OPENCV_COMPONENTS}
- Target: ${target} | Scope: | Links: ${ANDROID_OPENCV_COMPONENTS} -lGLESv2 -lEGL -llog
- Target: ${target} | Scope: | Links: ${OpenCL_LIBRARIES}
- Target: ${target} | Scope: | Links: -lOpenCL
- Target: ${tgt} | Scope: PRIVATE | Links: ${EPOXY_LIBRARIES}
- Target: ${tgt} | Scope: PRIVATE | Links: ${OPENCV_LINKER_LIBS} ${deps}
- Target: ${tgt} | Scope: PRIVATE | Links: ${OPENCV_LINKER_LIBS} ${OPENCV_CUDA_SAMPLES_REQUIRED_DEPS}
- Target: ${tgt} | Scope: PRIVATE | Links: ${OPENCV_LINKER_LIBS} ${OPENCV_DIRECTX_SAMPLES_REQUIRED_DEPS}
- Target: ${tgt} | Scope: PRIVATE | Links: ${OPENCV_LINKER_LIBS} ${OPENCV_DNN_SAMPLES_REQUIRED_DEPS}
- Target: ${tgt} | Scope: PRIVATE | Links: ${OPENCV_LINKER_LIBS} ${OPENCV_OPENVX_SAMPLE_REQUIRED_DEPS}
- Target: ${tgt} | Scope: PRIVATE | Links: ${OPENCV_LINKER_LIBS} ${OPENCV_TAPI_SAMPLES_REQUIRED_DEPS}
- Target: ${tgt} | Scope: PRIVATE | Links: ${OPENCV_LINKER_LIBS} ${OPENCV_VA_INTEL_SAMPLES_REQUIRED_DEPS} ${VA_LIBRARIES}
- Target: ${tgt} | Scope: PRIVATE | Links: "${OPENGL_LIBRARIES}"
- Target: ${tgt} | Scope: PRIVATE | Links: "${OPENGL_LIBRARIES}" "${OPENCV_OPENGL_SAMPLES_REQUIRED_DEPS}"
- Target: ${tgt} | Scope: PRIVATE | Links: ${VTK_LIBRARIES}
- Target: ${tgt} | Scope: PRIVATE | Links: ${X11_LIBRARIES}
- Target: ${tgt} | Scope: PRIVATE | Links: d3d10
- Target: ${tgt} | Scope: PRIVATE | Links: d3d11
- Target: ${tgt} | Scope: PRIVATE | Links: d3d9
- Target: ${tgt} | Scope: PRIVATE | Links: "gdi32"
- Target: ${tgt} | Scope: PRIVATE | Links: opencv_cudaarithm opencv_cudafilters
- Target: ${tgt} | Scope: PRIVATE | Links: opencv_cudacodec
- Target: ${tgt} | Scope: PRIVATE | Links: opencv_xfeatures2d
- Target: ${the_module} | Scope: | Links: ${LAPACK_LIBRARIES}
- Target: ${the_module} | Scope: | Links: LINK_PRIVATE "${HPX_LIBRARIES}"
- Target: ${the_module} | Scope: | Links: LINK_PRIVATE "${OpenMP_CXX_LIBRARIES}"
- Target: ${the_module} | Scope: | Links: LINK_PRIVATE ${tgts}
- Target: ${the_module} | Scope: | Links: quirc
- Target: ${the_module} | Scope: PRIVATE | Links: ${__deps}
- Target: ${the_module} | Scope: PRIVATE | Links: ${__deps} ${OPENCV_LINKER_LIBS}
- Target: ${the_module} | Scope: PRIVATE | Links: ${__extradeps} ${OPENCV_LINKER_LIBS}
- Target: ${the_module} | Scope: PRIVATE | Links: ${FREETYPE_LIBRARIES}
- Target: ${the_module} | Scope: PRIVATE | Links: ${ITT_LIBRARIES}
- Target: ${the_module} | Scope: PRIVATE | Links: ${ONNX_LIBRARY}
- Target: ${the_module} | Scope: PRIVATE | Links: ${PLAIDML_LIBRARIES}
- Target: ${the_module} | Scope: PRIVATE | Links: ${VA_LIBRARIES}
- Target: ${the_module} | Scope: PRIVATE | Links: ${VPL_IMPORTED_TARGETS}
- Target: ${the_module} | Scope: PRIVATE | Links: ade
- Target: ${the_module} | Scope: PRIVATE | Links: d3d11 dxgi
- Target: ${the_module} | Scope: PRIVATE | Links: depthai::core
- Target: ${the_module} | Scope: PRIVATE | Links: mf mfuuid mfplat shlwapi mfreadwrite
- Target: ${the_module} | Scope: PRIVATE | Links: ocv.3rdparty.gstreamer
- Target: ${the_module} | Scope: PRIVATE | Links: ocv.3rdparty.msmf
- Target: ${the_module} | Scope: PRIVATE | Links: ocv.3rdparty.openvino
- Target: ${the_module} | Scope: PRIVATE | Links: tbb
- Target: ${the_module} | Scope: PRIVATE | Links: -Wl,-force_load "${_dep}"
- Target: ${the_module} | Scope: PRIVATE | Links: -Wl,-whole-archive ${__deps} -Wl,-no-whole-archive
- Target: ${the_module} | Scope: PRIVATE | Links: wsock32 ws2_32
- Target: ${the_module} | Scope: PUBLIC | Links: regex
- Target: ${the_target} | Scope: | Links: ${APP_MODULES}
- Target: ${TIFF_LIBRARY} | Scope: | Links: ${ZLIB_LIBRARIES}
- Target: ${WEBP_LIBRARY} | Scope: | Links: ${CPUFEATURES_LIBRARIES}
- Target: example_gapi_onevpl_infer_with_advanced_device_selection | Scope: PRIVATE | Links: ${VA_LIBRARIES}
- Target: example_gapi_onevpl_infer_with_advanced_device_selection | Scope: PRIVATE | Links: d3d11 dxgi
- Target: example_gapi_onevpl_infer_with_advanced_device_selection | Scope: PRIVATE | Links: ocv.3rdparty.openvino
- Target: example_gapi_pipeline_modeling_tool | Scope: | Links: winmm.lib
- Target: fastcv_hal | Scope: PUBLIC | Links: ${FASTCV_LIBRARY}
- Target: IlmImf | Scope: | Links: ${ZLIB_LIBRARIES}
- Target: ipphal | Scope: PUBLIC | Links: ${IPP_IW_LIBRARY} ${IPP_LIBRARIES}
- Target: libprotobuf | Scope: INTERFACE | Links: "-landroid" "-llog"
 target_link_libraries(${OPENCV_PLUGIN_NAME} PRIVATE
 target_link_libraries(opencv_example_openmp_backend PRIVATE
 target_link_libraries(opencv_example_tbb_backend PRIVATE
- Target: opencv_example | Scope: PRIVATE | Links: ${OpenCV_LIBS}
- Target: opencv_highgui_gtk2 | Scope: | Links: ocv.3rdparty.gtkglext
- Target: opencv_highgui_gtk3 | Scope: | Links: ocv.3rdparty.gtkglext
- Target: opencv_highgui_gtk | Scope: | Links: ocv.3rdparty.gtkglext
- Target: opencv_perf_dnn | Scope: | Links: caffe
- Target: opencv_perf_gapi | Scope: PRIVATE | Links: ${VPL_IMPORTED_TARGETS}
- Target: opencv_test_dnn | Scope: | Links: ocv.3rdparty.cann
- Target: opencv_test_dnn | Scope: | Links: ocv.3rdparty.openvino
- Target: opencv_test_gapi | Scope: PRIVATE | Links: ${ONNX_LIBRARY}
- Target: opencv_test_gapi | Scope: PRIVATE | Links: ${VA_LIBRARIES}
- Target: opencv_test_gapi | Scope: PRIVATE | Links: ${VPL_IMPORTED_TARGETS}
- Target: opencv_test_gapi | Scope: PRIVATE | Links: ade
- Target: opencv_test_gapi | Scope: PRIVATE | Links: ocv.3rdparty.gstreamer
- Target: opencv_test_gapi | Scope: PRIVATE | Links: tbb
- Target: opencv_videoio_ffmpeg | Scope: | Links: ocv.3rdparty.ffmpeg.plugin_deps
- Target: opencv_videoio_ffmpeg | Scope: | Links: ocv.3rdparty.mediasdk
- Target: openvx_hal | Scope: PUBLIC | Links: ${OPENVX_LIBRARIES}
- Target: ... | Scope: | Links: ${SYCL_TARGET}
- Target: tbb | Scope: | Links: c m dl

## FetchContent_Declare

- (none found)

## pkg_check_modules

- (none found)

