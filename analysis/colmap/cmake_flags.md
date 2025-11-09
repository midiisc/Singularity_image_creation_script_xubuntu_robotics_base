# CMake Flag Inventory

_Generated on 2025-11-09T09:11:41Z_

## benchmark/runtime/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## src/colmap/optim/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## src/colmap/ui/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## src/colmap/retrieval/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## src/colmap/exe/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## src/colmap/sfm/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## src/colmap/geometry/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## src/colmap/estimators/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## src/colmap/util/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- L75: target_compile_definitions(colmap_util PRIVATE COLMAP_USE_CRYPTOPP)
- L78: target_compile_definitions(colmap_util PRIVATE COLMAP_USE_OPENSSL)

**add_definitions**
- (none found)

## src/colmap/tools/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## src/colmap/math/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## src/colmap/feature/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## src/colmap/image/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## src/colmap/mvs/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## src/colmap/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- L32: set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /W3")
- L33: set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /W3")
- L37: set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall")
- L38: set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall")
- L42: set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} --use_fast_math")
- L46: set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} --default-stream per-thread")
- L50: set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -Xptxas=-suppress-stack-size-warning")

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## src/colmap/sensor/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## src/colmap/controllers/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## src/colmap/scene/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## src/thirdparty/PoissonRecon/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- L2: set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -funroll-loops -ffast-math")

**Target Compile Options/Definitions**
- L48: target_compile_definitions(colmap_poisson_recon PRIVATE RELEASE)

**add_definitions**
- (none found)

## src/thirdparty/LSD/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## src/thirdparty/VLFeat/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## src/thirdparty/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- L31: set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /W0")
- L32: set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /W0")
- L34: set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -w")
- L35: set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -w")

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## src/thirdparty/SiftGPU/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## python/CMakeLists.txt

**Options**
- L3: option(GENERATE_STUBS "Whether to generate stubs" ON)

**Global Compiler Flags**
- L15: set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /EHsc")
- L17: set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /MP")
- L18: set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /MP")

**Target Compile Options/Definitions**
- L36: target_compile_definitions(_core PRIVATE VERSION_INFO="${PROJECT_VERSION}")

**add_definitions**
- (none found)

## CMakeLists.txt

**Options**
- L37: option(SIMD_ENABLED "Whether to enable SIMD optimizations" ON)
- L38: option(OPENMP_ENABLED "Whether to enable OpenMP parallelization" ON)
- L39: option(IPO_ENABLED "Whether to enable interprocedural optimization" ON)
- L40: option(CUDA_ENABLED "Whether to enable CUDA, if available" ON)
- L41: option(GUI_ENABLED "Whether to enable the graphical UI" ON)
- L42: option(OPENGL_ENABLED "Whether to enable OpenGL, if available" ON)
- L43: option(TESTS_ENABLED "Whether to build test binaries" OFF)
- L44: option(COVERAGE_ENABLED "Whether to enable code coverage" OFF)
- L45: option(ASAN_ENABLED "Whether to enable AddressSanitizer flags" OFF)
- L46: option(TSAN_ENABLED "Whether to enable ThreadSanitizer flags" OFF)
- L47: option(UBSAN_ENABLED "Whether to enable UndefinedBehaviorSanitizer flags" OFF)
- L48: option(PROFILING_ENABLED "Whether to enable google-perftools linker flags" OFF)
- L49: option(CCACHE_ENABLED "Whether to enable compiler caching, if available" ON)
- L50: option(CGAL_ENABLED "Whether to enable the CGAL library" ON)
- L51: option(LSD_ENABLED "Whether to enable the LSD library" ON)
- L52: option(DOWNLOAD_ENABLED "Whether to enable (automatic) download of resources (requires Curl/OpenSSL)" ON)
- L53: option(UNINSTALL_ENABLED "Whether to create a target to 'uninstall' colmap" ON)
- L54: option(FETCH_POSELIB "Whether to consume PoseLib using FetchContent or find_package" ON)
- L55: option(FETCH_FAISS "Whether to consume faiss using FetchContent or find_package" ON)
- L56: option(ALL_SOURCE_TARGET "Whether to create a target for all source files (for Visual Studio / XCode development)" OFF)

**Global Compiler Flags**
- L141: set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /EHsc")
- L143: set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /wd4244 /wd4267 /wd4305")
- L145: set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /MP")
- L146: set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /MP")
- L148: set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /bigobj")
- L149: set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /bigobj")
- L226: set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -lprofiler -ltcmalloc")
- L227: set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -lprofiler -ltcmalloc")

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

## doc/sample-project/CMakeLists.txt

**Options**
- (none found)

**Global Compiler Flags**
- (none found)

**Target Compile Options/Definitions**
- (none found)

**add_definitions**
- (none found)

