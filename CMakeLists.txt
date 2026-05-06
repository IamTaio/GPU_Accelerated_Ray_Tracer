cmake_minimum_required(VERSION 3.22)

project(GPUAccRayTracer)

find_package(glfw3 REQUIRED)

add_executable(GPUAccRayTracer
    main.cpp
    aabb.cpp
    interval.cpp
)

target_include_directories(GPUAccRayTracer PRIVATE include/)

# GLAD
add_library(glad external/glad/src/glad.c)

target_include_directories(glad PUBLIC external/glad/include)

target_link_libraries(GPUAccRayTracer PRIVATE glad)

target_link_libraries(GPUAccRayTracer PRIVATE glfw)