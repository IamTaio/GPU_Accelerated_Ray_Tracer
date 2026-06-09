cmake_minimum_required(VERSION 3.18)
project(GPUAccRayTracer LANGUAGES C CXX CUDA)

find_package(CUDAToolkit REQUIRED)
find_package(OpenGL REQUIRED)

# GLFW - built from source, no system install needed
set(GLFW_BUILD_DOCS OFF CACHE BOOL "" FORCE)
set(GLFW_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(GLFW_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/glfw-3.4)

# GLM - header only, needed by shader.h
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/glm)

add_executable(GPUAccRayTracer
    main.cu
)

add_custom_command(TARGET GPUAccRayTracer POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${CMAKE_SOURCE_DIR}/assets"
            "$<TARGET_FILE_DIR:GPUAccRayTracer>/assets"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CMAKE_SOURCE_DIR}/vertexShader.vs"
        "$<TARGET_FILE_DIR:GPUAccRayTracer>/vertexShader.vs"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CMAKE_SOURCE_DIR}/FragShader.fs"
        "$<TARGET_FILE_DIR:GPUAccRayTracer>/FragShader.fs"
)

target_include_directories(GPUAccRayTracer PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include/)
target_include_directories(GPUAccRayTracer PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/cuda/)
target_include_directories(GPUAccRayTracer PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/external/stb/)

# GLAD
add_library(glad STATIC ${CMAKE_CURRENT_SOURCE_DIR}/external/glad/src/glad.c)
target_include_directories(glad PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/external/glad/include)

# cudadevrt - tell the linker where to find it directly
target_link_directories(GPUAccRayTracer PRIVATE "${CUDAToolkit_LIBRARY_DIR}")

target_link_libraries(GPUAccRayTracer PRIVATE glad glfw glm::glm OpenGL::GL CUDA::cudart CUDA::curand cudadevrt)

target_compile_options(GPUAccRayTracer PRIVATE
    $<$<COMPILE_LANGUAGE:CXX>:/Zc:preprocessor>
    $<$<COMPILE_LANGUAGE:CUDA>:-Xcompiler=/Zc:preprocessor>
)

set_property(TARGET GPUAccRayTracer PROPERTY CXX_STANDARD 17)
set_property(TARGET GPUAccRayTracer PROPERTY CUDA_STANDARD 17)

set_target_properties(GPUAccRayTracer PROPERTIES
    CUDA_ARCHITECTURES 75
    CUDA_SEPARABLE_COMPILATION OFF
    VS_DEBUGGER_WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    VS_DEBUGGER_ENVIRONMENT "__NV_PRIME_RENDER_OFFLOAD=1;__GLX_VENDOR_LIBRARY_NAME=nvidia"
)