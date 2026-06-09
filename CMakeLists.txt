cmake_minimum_required(VERSION 3.18)
project(GPUAccRayTracer LANGUAGES C CXX CUDA)

find_package(CUDAToolkit REQUIRED)
find_package(OpenGL REQUIRED)
# CMake had issues finding glfw3
find_package(glfw3 REQUIRED)

add_executable(GPUAccRayTracer main.cu kernels.cu)

target_include_directories(GPUAccRayTracer PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include/)
target_include_directories(GPUAccRayTracer PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/cuda/)

# GLAD
add_library(glad STATIC ${CMAKE_CURRENT_SOURCE_DIR}/external/glad/src/glad.c)

target_include_directories(glad PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/external/glad/include)

target_link_libraries(GPUAccRayTracer PRIVATE glad)

# GLFW
target_link_libraries(GPUAccRayTracer PRIVATE glfw)

# OpenGL
target_link_libraries(GPUAccRayTracer PRIVATE OpenGL::GL)

# CUDA
target_link_libraries(GPUAccRayTracer PRIVATE CUDA::cudart CUDA::curand)

# set_target_properties(GPUAccRayTracer PROPERTIES
#     VS_DEBUGGER_ENVIRONMENT 
#     "__NV_PRIME_RENDER_OFFLOAD=1;__GLX_VENDOR_LIBRARY_NAME=nvidia"
# )