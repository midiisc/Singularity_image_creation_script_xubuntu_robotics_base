# CMake Flag Inventory

_Generated on 2025-11-09T09:10:46Z_

## samples/dnn/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/cpp/tutorial_code/calib3d/real_time_pose_estimation/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/cpp/tutorial_code/gpu/gpu-thrust-interop/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/cpp/tutorial_code/core/parallel_backend/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/cpp/example_cmake/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/cpp/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L56: target_compile_definitions(${tgt} PRIVATE -DUSE_VTK)
- L59: target_compile_definitions(${tgt} PRIVATE HAVE_OPENGL)
- L65: #target_compile_definitions(${tgt} PRIVATE OPENCV_SIMD_CONFIG_HEADER=opencv_simd_config_custom.hpp)
- L66: #target_compile_definitions(${tgt} PRIVATE OPENCV_SIMD_CONFIG_INCLUDE_DIR=1)
- L67: #target_compile_options(${tgt} PRIVATE -mavx2)

**add_definitions**
- (none found)

## samples/opencl/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/va_intel/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/sycl/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- L63: set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${SYCL_FLAGS}")
- L64: set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${SYCL_FLAGS}")

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/opengl/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/gpu/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- L49: set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wno-unused-function")

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- L33: add_definitions(-DHAVE_CUDA=1)

## samples/semihosting/include/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/semihosting/histogram/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/semihosting/norm/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/semihosting/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/hal/c_hal/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/hal/slow_hal/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/python/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/directx/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/android/tutorial-4-opencl/jni/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- L25: set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,-z,max-page-size=16384")

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- L37: add_definitions("-DOPENCL_FOUND")
- L46: add_definitions("-DOPENCL_FOUND")
- L47: add_definitions("-DCL_HPP_MINIMUM_OPENCL_VERSION=120")
- L48: add_definitions("-DCL_HPP_TARGET_OPENCL_VERSION=120")
- L49: add_definitions("-DCL_HPP_ENABLE_PROGRAM_CONSTRUCTION_FROM_ARRAY_COMPATIBILITY")

## samples/android/tutorial-4-opencl/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/android/15-puzzle/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/android/qr-detection/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/android/tutorial-2-mixedprocessing/jni/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- L21: set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,-z,max-page-size=16384")

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/android/tutorial-2-mixedprocessing/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/android/image-manipulations/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/android/color-blob-detection/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/android/tutorial-3-cameracontrol/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/android/camera-calibration/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/android/tutorial-1-camerapreview/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/android/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/android/video-recorder/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/android/face-detection/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/android/mobilenet-objdetect/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/java/tutorial_code/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/tapi/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## samples/CMakeLists.txt

**Options**
- L68: option(BUILD_EXAMPLES "Build samples" ON)

**Global Compiler Flags**
- L105: set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} /NODEFAULTLIB:atlthunk.lib /NODEFAULTLIB:msvcrt.lib /NODEFAULTLIB:msvcrtd.lib")
- L107: set(CMAKE_EXE_LINKER_FLAGS_DEBUG "${CMAKE_EXE_LINKER_FLAGS_DEBUG} /NODEFAULTLIB:libcmt.lib")
- L108: set(CMAKE_EXE_LINKER_FLAGS_RELEASE "${CMAKE_EXE_LINKER_FLAGS_RELEASE} /NODEFAULTLIB:libcmtd.lib")

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- L20: add_definitions(-DHAVE_THREADS=1)
- L88: add_definitions(-D_CRT_SECURE_NO_WARNINGS)
- L122: add_definitions(-DHAVE_THREADS=1)

## samples/openvx/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- L19: add_definitions(-DIVX_USE_OPENCV)
- L20: add_definitions(-DIVX_HIDE_INFO_WARNINGS)

## include/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/calib3d/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/dnn/misc/plugin/openvino/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/dnn/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L23: ocv_target_compile_definitions(${the_module} PRIVATE "CV_OCL4DNN=1")
- L27: ocv_target_compile_definitions(${the_module} PRIVATE "HAVE_WEBNN=1")
- L31: ocv_target_compile_definitions(${the_module} PRIVATE "HAVE_TIMVX=1")
- L35: ocv_target_compile_definitions(${the_module} PRIVATE "HAVE_CANN=1")
- L46: ocv_target_compile_definitions(${the_module} PRIVATE "CV_CUDA4DNN=1")
- L96: ocv_target_compile_definitions(${the_module} PRIVATE "OPENCV_DNN_EXTERNAL_PROTOBUF=1")
- L114: ocv_target_compile_definitions(${the_module} PRIVATE "HAVE_PROTOBUF=1")
- L265: ocv_target_compile_definitions(opencv_test_dnn PRIVATE "OPENCV_DNN_EXTERNAL_PROTOBUF=1")
- L286: ocv_target_compile_definitions(opencv_perf_dnn PRIVATE "HAVE_CAFFE=1")
- L294: ocv_target_compile_definitions(opencv_perf_dnn PRIVATE "HAVE_CLCAFFE=1")
- L301: ocv_target_compile_definitions(${the_module} PRIVATE ENABLE_PLUGINS)
- L303: ocv_target_compile_definitions(opencv_test_dnn PRIVATE ENABLE_PLUGINS)
- L327: ocv_target_compile_definitions(opencv_test_dnn PRIVATE "HAVE_TIMVX=1")
- L334: ocv_target_compile_definitions(opencv_test_dnn PRIVATE "OPENCV_TEST_DNN_TFLITE=1")
- L337: ocv_target_compile_definitions(opencv_perf_dnn PRIVATE "OPENCV_TEST_DNN_TFLITE=1")

**add_definitions**
- L63: add_definitions( -D_CRT_SECURE_NO_WARNINGS=1 )
- L92: add_definitions(-DDISABLE_POSIX_MEMALIGN -DTH_DISABLE_HEAP_TRACKING)

## modules/imgcodecs/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- L13: set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /ZW")

**Target Compile Options/Definitions**
- L198: ocv_target_compile_definitions(opencv_test_imgcodecs PRIVATE OPENCV_IMGCODECS_ENABLE_JASPER_TESTS=1)
- L201: ocv_target_compile_definitions(opencv_test_imgcodecs PRIVATE OPENCV_IMGCODECS_ENABLE_OPENEXR_TESTS=1)
- L205: ocv_target_compile_definitions(opencv_test_imgcodecs PRIVATE OPENCV_IMGCODECS_PNG_WITH_EXIF=1)

**add_definitions**
- L27: add_definitions(-DHAVE_WEBP)
- L33: add_definitions(${SPNG_DEFINITIONS})
- L39: add_definitions(${PNG_DEFINITIONS})
- L69: add_definitions(-DOPENCV_IMGCODECS_FORCE_JASPER=1)
- L81: add_definitions(-DOPENCV_IMGCODECS_USE_OPENEXR=1)
- L98: add_definitions(-DHAVE_IMGCODEC_GIF)
- L102: add_definitions(-DHAVE_IMGCODEC_HDR)
- L106: add_definitions(-DHAVE_IMGCODEC_SUNRASTER)
- L110: add_definitions(-DHAVE_IMGCODEC_PXM)
- L114: add_definitions(-DHAVE_IMGCODEC_PFM)

## modules/highgui/misc/plugins/plugin_gtk/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/highgui/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- L30: set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /ZW")

**Target Compile Options/Definitions**
- L315: ocv_target_compile_definitions(${the_module} PRIVATE ENABLE_PLUGINS)
- L317: ocv_target_compile_definitions(opencv_test_highgui PRIVATE ENABLE_PLUGINS)

**add_definitions**
- L39: add_definitions(-DHAVE_WEBP)
- L54: add_definitions(-DHAVE_FRAMEBUFFER)
- L58: add_definitions(-DHAVE_FRAMEBUFFER_XVFB)
- L64: add_definitions(-DHAVE_WAYLAND)
- L89: add_definitions(-DHAVE_QT)
- L98: add_definitions(-DHAVE_QT6) # QGLWidget deprecated for QT6, use this preprocessor to adjust window_QT.[h,cpp]
- L116: add_definitions(-DHAVE_QT_OPENGL)
- L128: add_definitions(${Qt${QT_VERSION_MAJOR}${dt_dep}_DEFINITIONS})
- L189: add_definitions(-DHAVE_COCOA)

## modules/ts/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L48: ocv_target_compile_definitions(${the_module} PUBLIC GTEST_HAS_PTHREAD=0)

**add_definitions**
- (none found)

## modules/gapi/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L283: ocv_target_compile_definitions(${the_module} PRIVATE -DOPENCV_WITH_ITT=1)
- L308: ocv_target_compile_definitions(${the_module} PRIVATE -DHAVE_FREETYPE)
- L310: ocv_target_compile_definitions(opencv_test_gapi PRIVATE -DHAVE_FREETYPE)
- L317: ocv_target_compile_definitions(${the_module} PRIVATE -DHAVE_OAK)
- L319: ocv_target_compile_definitions(opencv_test_gapi PRIVATE -DHAVE_OAK)
- L325: ocv_target_compile_definitions(${the_module} PRIVATE -DHAVE_PLAIDML)
- L327: ocv_target_compile_definitions(opencv_test_gapi PRIVATE -DHAVE_PLAIDML)
- L335: ocv_target_compile_definitions(opencv_test_gapi PRIVATE -DHAVE_ONEVPL)
- L338: target_compile_options(opencv_test_gapi PUBLIC "/wd4201")
- L345: ocv_target_compile_definitions(${the_module} PRIVATE -DHAVE_ONEVPL)
- L371: ocv_target_compile_definitions(opencv_test_gapi PRIVATE -DHAVE_GSTREAMER)
- L374: ocv_target_compile_definitions(${the_module} PRIVATE -DHAVE_GSTREAMER)
- L386: ocv_target_compile_definitions(opencv_test_gapi PRIVATE -DHAVE_GAPI_MSMF)
- L388: ocv_target_compile_definitions(${the_module} PRIVATE -DHAVE_GAPI_MSMF)
- L393: ocv_target_compile_definitions(${the_module} PRIVATE HAVE_DIRECTML=1)
- L398: ocv_target_compile_definitions(${the_module} PRIVATE HAVE_ONNX=1)
- L400: ocv_target_compile_definitions(${the_module} PRIVATE HAVE_ONNX_DML=1)
- L403: ocv_target_compile_definitions(opencv_test_gapi PRIVATE HAVE_ONNX=1)
- L443: ocv_target_compile_definitions(opencv_perf_gapi PRIVATE -DHAVE_ONEVPL)

**add_definitions**
- (none found)

## modules/features2d/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/imgproc/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L16: ocv_target_compile_definitions(${the_module} PRIVATE "OPENCV_EXCLUDE_C_API=1")

**add_definitions**
- (none found)

## modules/stitching/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/core/misc/plugins/parallel_tbb/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/core/misc/plugins/parallel_openmp/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/core/CMakeLists.txt

**Options**
- L132: option(OPENCV_ENABLE_ALLOCATOR_STATS "Enable Allocator metrics" ON)

**Global Compiler Flags**
- L50: set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /ZW")

**Target Compile Options/Definitions**
- L185: ocv_target_compile_definitions(${the_module} PRIVATE "OPENCV_EXCLUDE_C_API=1")
- L189: ocv_target_compile_definitions(${the_module} PUBLIC "OPENCV_DISABLE_THREAD_SUPPORT=1")
- L197: ocv_target_compile_definitions(${the_module} PRIVATE "-DOPENCV_SEMIHOSTING")
- L201: ocv_target_compile_definitions(${the_module} PRIVATE "-DOPENCV_ALGO_HINT_DEFAULT=${OPENCV_ALGO_HINT_DEFAULT}")

**add_definitions**
- L54: add_definitions(-DOPENCV_WITH_ITT=1)
- L135: add_definitions(-DOPENCV_DISABLE_ALLOCATOR_STATS=1)
- L152: add_definitions("-DOPENCV_ALLOCATOR_STATS_COUNTER_TYPE=${OPENCV_ALLOCATOR_STATS_COUNTER_TYPE}")

## modules/python/bindings/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/python/python3/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/python/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/python/python2/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/python/test/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/ml/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/videoio/misc/plugin_gstreamer/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/videoio/misc/plugin_ffmpeg/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/videoio/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- L56: set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /ZW")

**Target Compile Options/Definitions**
- L285: ocv_target_compile_definitions(${the_module} PRIVATE ENABLE_PLUGINS)

**add_definitions**
- (none found)

## modules/java/android_sdk/libcxx_helper/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/java/android_sdk/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/java/generator/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/java/jni/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/java/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/java/test/android_test/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/java/test/pure_test/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/java/jar/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/world/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L84: ocv_target_compile_definitions(${the_module} PRIVATE OPENCV_MODULE_IS_PART_OF_WORLD=1)

**add_definitions**
- (none found)

## modules/flann/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/objc/generator/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/objc/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/photo/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/js/generator/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/js/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- L41: add_definitions("-std=c++11")
- L52: add_definitions(-DTEST_WASM_INTRIN)

## modules/video/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## modules/objdetect/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## hal/ipp/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L24: target_compile_definitions(ipphal PRIVATE HAVE_IPP_ICV)
- L28: target_compile_definitions(ipphal PRIVATE HAVE_IPP_IW)

**add_definitions**
- (none found)

## hal/fastcv/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## hal/kleidicv/CMakeLists.txt

**Options**
- L4: option(KLEIDICV_ENABLE_SME2 "" OFF) # not compatible with some CLang versions in NDK
- L5: option(KLEIDICV_USE_CV_NAMESPACE_IN_OPENCV_HAL "" OFF)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L8: target_compile_options( kleidicv_hal PRIVATE

**add_definitions**
- (none found)

## hal/carotene/hal/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- L41: set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${TEGRA_COMPILER_FLAGS}")
- L42: set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${TEGRA_COMPILER_FLAGS}")
- L46: set( CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fno-tree-vectorize" )
- L47: set( CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fno-tree-vectorize" )

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- L52: add_definitions(-DHAVE_LOGS)

## hal/carotene/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- L17: set(CMAKE_CXX_FLAGS "-fvisibility=hidden ${CMAKE_CXX_FLAGS}")

**Target Compile Options/Definitions**
- L40: target_compile_definitions(carotene_objs PUBLIC "-DCAROTENE_NS=${CAROTENE_NS}")
- L44: target_compile_definitions(carotene_objs PRIVATE "-DWITH_NEON")
- L48: target_compile_definitions(carotene_objs PRIVATE "-D_USE_MATH_DEFINES=1")

**add_definitions**
- (none found)

## hal/riscv-rvv/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## hal/openvx/hal/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## hal/openvx/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## hal/ndsrvp/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## 3rdparty/tbb/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- L67: set(CMAKE_LINKER_FLAGS "${CMAKE_LINKER_FLAGS} /APPCONTAINER")
- L86: set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -flifetime-dse=1") # workaround for GCC 6.x
- L134: set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} /DEF:${tbb_src_dir}/src/tbb/tbb.def /DLL /MAP /fixed:no /INCREMENTAL:NO")

**Target Compile Options/Definitions**
- L113: target_compile_definitions(tbb PUBLIC

**add_definitions**
- L51: add_definitions(/D__TBB_DYNAMIC_LOAD_ENABLED=0
- L62: add_definitions(/D_WIN32_WINNT=0x0602
- L69: add_definitions(-D__TBB_DYNAMIC_LOAD_ENABLED=0         #required
- L80: add_definitions(-DUSE_PTHREAD) #required for Unix
- L84: add_definitions(-DTBB_USE_GCC_BUILTINS=1) #required for ARM GCC
- L91: add_definitions(-D__TBB_GCC_BUILTIN_ATOMICS_PRESENT=1)

## 3rdparty/protobuf/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- L5: add_definitions(-DHAVE_PTHREAD=1)
- L9: add_definitions( -D_CRT_SECURE_NO_WARNINGS=1 )

## 3rdparty/zlib-ng/CMakeLists.txt

**Options**
- L76: option(WITH_GZFILEOP "Compile with support for gzFile related functions" ON)
- L77: option(ZLIB_COMPAT "Compile with zlib compatible API" ON)
- L78: option(ZLIB_ENABLE_TESTS "Build test binaries" OFF)
- L79: option(ZLIBNG_ENABLE_TESTS "Test zlib-ng specific API" OFF)
- L80: option(WITH_GTEST "Build gtest_zlib" OFF)
- L81: option(WITH_FUZZERS "Build test/fuzz" OFF)
- L82: option(WITH_BENCHMARKS "Build test/benchmarks" OFF)
- L83: option(WITH_BENCHMARK_APPS "Build application benchmarks" OFF)
- L84: option(WITH_OPTIM "Build with optimisation" ON)
- L85: option(WITH_REDUCED_MEM "Reduced memory usage for special cases (reduces performance)" OFF)
- L86: option(WITH_NEW_STRATEGIES "Use new strategies" ON)
- L87: option(WITH_NATIVE_INSTRUCTIONS
- L89: option(WITH_RUNTIME_CPU_DETECTION "Build with runtime detection of CPU architecture" ON)
- L90: option(WITH_MAINTAINER_WARNINGS "Build with project maintainer warnings" OFF)
- L91: option(WITH_CODE_COVERAGE "Enable code coverage reporting" OFF)
- L92: option(WITH_INFLATE_STRICT "Build with strict inflate distance checking" OFF)
- L93: option(WITH_INFLATE_ALLOW_INVALID_DIST "Build with zero fill for inflate invalid distances" OFF)
- L94: option(WITH_UNALIGNED "Support unaligned reads on platforms that support it" ON)
- L105: option(WITH_ACLE "Build with ACLE" ON)
- L106: option(WITH_NEON "Build with NEON intrinsics" ON)
- L109: option(WITH_ALTIVEC "Build with AltiVec (VMX) optimisations for PowerPC" ON)
- L110: option(WITH_POWER8 "Build with optimisations for POWER8" ON)
- L111: option(WITH_POWER9 "Build with optimisations for POWER9" ON)
- L113: option(WITH_RVV "Build with RVV intrinsics" ON)
- L115: option(WITH_DFLTCC_DEFLATE "Build with DFLTCC intrinsics for compression on IBM Z" OFF)
- L116: option(WITH_DFLTCC_INFLATE "Build with DFLTCC intrinsics for decompression on IBM Z" OFF)
- L117: option(WITH_CRC32_VX "Build with vectorized CRC32 on IBM Z" ON)
- L119: option(WITH_SSE2 "Build with SSE2" ON)
- L129: option(INSTALL_UTILS "Copy minigzip and minideflate during install" OFF)

**Global Compiler Flags**
- L186: set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -diag-disable=10441")
- L187: set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -diag-disable=10441")
- L214: set(CMAKE_REQUIRED_FLAGS "-fno-lto")
- L218: set(CMAKE_REQUIRED_FLAGS)
- L228: set(CMAKE_REQUIRED_FLAGS -mfloat-abi=softfp)
- L236: set(CMAKE_REQUIRED_FLAGS -mfloat-abi=hard)
- L245: set(CMAKE_REQUIRED_FLAGS)
- L309: set(CMAKE_REQUIRED_FLAGS "${NATIVEFLAG}")
- L317: set(CMAKE_REQUIRED_FLAGS)

**Target Compile Options/Definitions**
- L1189: target_compile_definitions(${ZLIB_INSTALL_LIBRARY} PUBLIC ZLIBNG_NATIVE_API)

**add_definitions**
- L158: add_definitions(-DZLIB_COMPAT)
- L170: add_definitions(-DWITH_GZFILEOP)
- L203: add_definitions(-D_ARM_WINAPI_PARTITION_DESKTOP_SDK_AVAILABLE)
- L319: add_definitions(
- L330: add_definitions(-DDISABLE_RUNTIME_CPU_DETECTION)
- L344: add_definitions(-DNO_UNALIGNED)
- L371: add_definitions(-DHAVE_ARM_ACLE_H)
- L375: add_definitions(-DHAVE_SYS_AUXV_H)
- L379: add_definitions(-DHAVE_SYS_SDT_H)
- L388: add_definitions(-DHAVE_LINUX_AUXVEC_H)
- L397: add_definitions(-D_LARGEFILE64_SOURCE=1 -D__USE_LARGEFILE64)
- L401: add_definitions(-D_LARGEFILE64_SOURCE=1 -D__USE_LARGEFILE64)
- L413: add_definitions(-DNO_FSEEKO)
- L418: add_definitions(-DNO_STRERROR)
- L424: add_definitions(-DHAVE_POSIX_MEMALIGN)
- L431: add_definitions(-DHAVE_ALIGNED_ALLOC)
- L461: add_definitions(-DHAVE_VISIBILITY_HIDDEN)
- L475: add_definitions(-DHAVE_VISIBILITY_INTERNAL)
- L489: add_definitions(-DHAVE_ATTRIBUTE_ALIGNED)
- L505: add_definitions(-DHAVE_BUILTIN_ASSUME_ALIGNED)
- L521: add_definitions(-DHAVE_BUILTIN_CTZ)
- L537: add_definitions(-DHAVE_BUILTIN_CTZLL)
- L571: add_definitions(-D_CRT_SECURE_NO_DEPRECATE)
- L572: add_definitions(-D_CRT_NONSTDC_NO_DEPRECATE)
- L586: add_definitions(-DNO_QUICK_STRATEGY)
- L592: add_definitions(-DNO_MEDIUM_STRATEGY)
- L598: add_definitions(-DINFLATE_STRICT)
- L602: add_definitions(-DINFLATE_ALLOW_INVALID_DISTANCE_TOOFAR_ARRR)
- L609: add_definitions(-DHASH_SIZE=32768u -DGZBUFSIZE=8192 -DNO_LIT_MEM)
- L638: add_definitions(-DARM_FEATURES)
- L649: add_definitions(-DARM_AUXV_HAS_CRC32)
- L662: add_definitions(-DARM_AUXV_HAS_CRC32)
- L673: add_definitions(-DARM_AUXV_HAS_CRC32 -DARM_ASM_HWCAP)
- L686: add_definitions(-DARM_AUXV_HAS_NEON)
- L696: add_definitions(-DARM_AUXV_HAS_NEON)
- L712: add_definitions(-DARM_ACLE)
- L726: add_definitions(-DARM_NEON)
- L732: add_definitions(-D__ARM_NEON__)
- L738: add_definitions(-DARM_NEON_HASLD4)
- L747: add_definitions(-DARM_SIMD)
- L753: add_definitions(-DARM_SIMD_INTRIN)
- L773: add_definitions(-DPOWER_NEED_AUXVEC_H)
- L776: add_definitions(-DPOWER_FEATURES)
- L788: add_definitions(-DPPC_FEATURES)
- L790: add_definitions(-DPPC_VMX)
- L803: add_definitions(-DPOWER8_VSX)
- L806: add_definitions(-DPOWER8_VSX_CRC32)
- L818: add_definitions(-DPOWER9)
- L830: add_definitions(-DRISCV_FEATURES)
- L831: add_definitions(-DRISCV_RVV)
- L852: add_definitions(-DS390_FEATURES)
- L860: add_definitions(-DS390_DFLTCC_DEFLATE)
- L864: add_definitions(-DS390_DFLTCC_INFLATE)
- L870: add_definitions(-DS390_CRC32_VX)
- L879: add_definitions(-DX86_FEATURES)
- L895: add_definitions(-DX86_HAVE_XSAVE_INTRIN)
- L901: add_definitions(-DX86_SSE2)
- L908: add_definitions(-DX86_NOCHECK_SSE2)
- L918: add_definitions(-DX86_SSSE3)
- L930: add_definitions(-DX86_SSE42)
- L942: add_definitions(-DX86_PCLMULQDQ_CRC)
- L954: add_definitions(-DX86_AVX2)
- L972: add_definitions(-DX86_AVX512)
- L985: add_definitions(-DX86_AVX512VNNI)
- L997: add_definitions(-DX86_VPCLMULQDQ_CRC)
- L1246: add_definitions(-DHAVE_SYMVER)

## 3rdparty/libjasper/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- L8: add_definitions(-DEXCLUDE_MIF_SUPPORT -DEXCLUDE_PNM_SUPPORT -DEXCLUDE_BMP_SUPPORT -DEXCLUDE_RAS_SUPPORT  -DEXCLUDE_JPG_SUPPORT -DEXCLUDE_PGX_SUPPORT)
- L23: add_definitions(-DJAS_WIN_MSVC_BUILD)

## 3rdparty/libjpeg/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## 3rdparty/cpufeatures/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## 3rdparty/quirc/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## 3rdparty/ippicv/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- L24: set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wno-unused-function -Wno-missing-braces -Wno-missing-field-initializers")
- L27: set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wno-self-assign -Wno-strict-prototypes")

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- L8: add_definitions(-DIW_BUILD)
- L10: add_definitions(-DICV_BASE)

## 3rdparty/libspng/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L36: target_compile_definitions(${SPNG_LIBRARY} PUBLIC SPNG_STATIC)

**add_definitions**
- L22: add_definitions(-D_CRT_SECURE_NO_DEPRECATE)

## 3rdparty/ittnotify/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## 3rdparty/openjpeg/openjp2/CMakeLists.txt

**Options**
- L27: option(OPJ_DISABLE_TPSOT_FIX "Disable TPsot==TNsot fix. See https://github.com/uclouvain/openjpeg/issues/254." OFF)
- L64: option(OPJ_USE_THREAD "Build with thread/mutex support " ON)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L47: target_compile_definitions(${OPENJPEG_LIBRARY_NAME} PUBLIC OPJ_STATIC)

**add_definitions**
- L29: add_definitions(-DOPJ_DISABLE_TPSOT_FIX)
- L66: add_definitions(-DMUTEX_stub)
- L72: add_definitions(-DMUTEX_win32)
- L77: add_definitions(-DMUTEX_win32)
- L81: add_definitions(-DMUTEX_pthread)

## 3rdparty/openjpeg/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- L79: add_definitions(

## 3rdparty/zlib/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- L18: add_definitions(-DNO_FSEEKO)
- L29: add_definitions(-D_CRT_SECURE_NO_DEPRECATE)
- L30: add_definitions(-D_CRT_NONSTDC_NO_DEPRECATE)
- L38: add_definitions(-D_LARGEFILE64_SOURCE=1)

## 3rdparty/libpng/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- L62: add_definitions(-DPNG_ARM_NEON_OPT=2)
- L64: add_definitions(-DPNG_ARM_NEON_CHECK_SUPPORTED)
- L67: add_definitions(-DPNG_ARM_NEON_OPT=0) # NEON assembler is not supported
- L84: add_definitions(-DPNG_POWERPC_VSX_OPT=2)
- L87: add_definitions(-DPNG_POWERPC_VSX_OPT=0)
- L104: add_definitions(-DPNG_INTEL_SSE_OPT=1)
- L107: add_definitions(-DPNG_INTEL_SSE_OPT=0)
- L135: add_definitions(-DPNG_MIPS_MSA_OPT=2)
- L136: add_definitions(-DPNG_MIPS_MMI_OPT=1)
- L139: add_definitions(-DPNG_MIPS_MSA_OPT=2)
- L140: add_definitions(-DPNG_MIPS_MMI_OPT=0)
- L143: add_definitions(-DPNG_MIPS_MSA_OPT=0)
- L144: add_definitions(-DPNG_MIPS_MMI_OPT=1)
- L146: add_definitions(-DPNG_MIPS_MSA_OPT=0)
- L147: add_definitions(-DPNG_MIPS_MMI_OPT=0)
- L172: add_definitions(-DPNG_LOONGARCH_LSX_OPT=1)
- L177: add_definitions(-DPNG_LOONGARCH_LSX_OPT=0)
- L185: add_definitions(-DPNG_ARM_NEON_OPT=0)
- L190: add_definitions(-DPNG_POWERPC_VSX_OPT=0)
- L195: add_definitions(-DPNG_INTEL_SSE_OPT=0)
- L200: add_definitions(-DPNG_MIPS_MSA_OPT=0)
- L205: add_definitions(-DPNG_LOONGARCH_LSX_OPT=0)
- L215: add_definitions(-D_CRT_SECURE_NO_DEPRECATE)

## 3rdparty/libjpeg-turbo/simd/CMakeLists.txt

**Options**
- L326: option(NEON_INTRINSICS

**Global Compiler Flags**
- L17: set(CMAKE_ASM_NASM_FLAGS_DEBUG_INIT "-g")
- L18: set(CMAKE_ASM_NASM_FLAGS_RELWITHDEBINFO_INIT "-g")
- L56: set(CMAKE_ASM_NASM_FLAGS "${CMAKE_ASM_NASM_FLAGS} -DMACHO")
- L58: set(CMAKE_ASM_NASM_FLAGS "${CMAKE_ASM_NASM_FLAGS} -DELF")
- L63: set(CMAKE_ASM_NASM_FLAGS "${CMAKE_ASM_NASM_FLAGS} -DWIN64")
- L65: set(CMAKE_ASM_NASM_FLAGS "${CMAKE_ASM_NASM_FLAGS} -D__x86_64__")
- L68: set(CMAKE_ASM_NASM_FLAGS "${CMAKE_ASM_NASM_FLAGS} -DOBJ32")
- L70: set(CMAKE_ASM_NASM_FLAGS "${CMAKE_ASM_NASM_FLAGS} -DWIN32")
- L96: set(CMAKE_ASM_NASM_FLAGS "${CMAKE_ASM_NASM_FLAGS} -DPIC")
- L107: set(CMAKE_ASM_NASM_FLAGS "${CMAKE_ASM_NASM_FLAGS} -D__CET__")
- L115: set(CMAKE_ASM_NASM_FLAGS "${CMAKE_ASM_NASM_FLAGS} -I\"${CMAKE_CURRENT_SOURCE_DIR}/nasm/\" -I\"${CMAKE_CURRENT_SOURCE_DIR}/${CPU_TYPE}/\"")
- L260: set(CMAKE_REQUIRED_FLAGS "-mfpu=neon ${SOFTFP_FLAG}")
- L332: set(CMAKE_ASM_FLAGS "${CMAKE_C_FLAGS} ${CMAKE_ASM_FLAGS}")
- L415: set(CMAKE_REQUIRED_FLAGS -mdspr2)
- L450: set(CMAKE_REQUIRED_FLAGS -Wa,-mloongson-mmi,-mloongson-ext)
- L501: set(CMAKE_REQUIRED_FLAGS -maltivec)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- L366: add_definitions(-DNEON_INTRINSICS)

## 3rdparty/libjpeg-turbo/CMakeLists.txt

**Options**
- L91: option(WITH_ARITH_ENC "Include arithmetic encoding support when emulating the libjpeg v6b API/ABI" TRUE)
- L92: option(WITH_ARITH_DEC "Include arithmetic decoding support when emulating the libjpeg v6b API/ABI" TRUE)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- L144: add_definitions(-DNO_GETENV -DNO_PUTENV)
- L147: add_definitions(-W3 -wd4996 -wd4018)
- L208: add_definitions(-DNEON_INTRINSICS)

## 3rdparty/libtiff/CMakeLists.txt

**Options**
- L253: option(ccitt "support for CCITT Group 3 & 4 algorithms" ON)
- L256: option(packbits "support for Macintosh PackBits algorithm" ON)
- L259: option(lzw "support for LZW algorithm" ON)
- L262: option(thunder "support for ThunderScan 4-bit RLE algorithm" ON)
- L265: option(next "support for NeXT 2-bit RLE algorithm" ON)
- L268: option(logluv "support for LogLuv high dynamic range algorithm" ON)
- L272: option(mdi "support for Microsoft Document Imaging" ON)
- L294: option(old-jpeg "support for Old JPEG compression (read-only)" OFF)  # OpenCV: changed to OFF

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- L229: add_definitions(-DWORDS_BIGENDIAN)
- L243: add_definitions(-D_FILE_OFFSET_BITS=64)

## 3rdparty/libwebp/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- L30: add_definitions(-DWEBP_USE_THREAD)

## 3rdparty/openexr/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- L12: set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11")
- L126: set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /Qrestrict")
- L127: set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /Qrestrict")

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## apps/model-diagnostics/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## apps/interactive-calibration/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## apps/version/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L4: target_compile_definitions(opencv_version_win32 PRIVATE "OPENCV_WIN32_API=1")

**add_definitions**
- (none found)

## apps/visualisation/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## apps/annotation/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## apps/traincascade/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## apps/createsamples/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## apps/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- L1: add_definitions(-D__OPENCV_BUILD=1)
- L2: add_definitions(-D__OPENCV_APPS=1)

## CMakeLists.txt

**Options**
- L122: option(ENABLE_PIC "Generate position independent code (necessary for shared libraries)" TRUE)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- L557: add_definitions(-DCV_COLLECT_IMPL_DATA)
- L561: add_definitions(-DOPENCV_HAVE_FILESYSTEM_SUPPORT=0)

## data/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## doc/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

