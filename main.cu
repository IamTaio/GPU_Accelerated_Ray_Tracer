#define __STDC_WANT_LIB_EXT1__ 1
#define STBI_MSC_SECURE_CRT
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include "include/shader.h"

#include "cuda/common.cuh"
#include "cuda/bvh.cuh"
#include "cuda/camera.cuh"
#include "cuda/hittable_list.cuh"
#include "cuda/material.cuh"
#include "cuda/sphere.cuh"
#include <cuda_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <chrono>

#define IMAGE_WIDTH  1600
#define ASPECT_RATIO (16.0 / 9.0)
#define IMAGE_HEIGHT ((int)(IMAGE_WIDTH / ASPECT_RATIO))
#define WORLD_SIZE   484

#define CUDA_CHECK(call)                                                          \
do {                                                                              \
    cudaError_t err = call;                                                       \
    if (err != cudaSuccess) {                                                     \
        fprintf(stderr, "CUDA error in file '%s' at line %d: %s\n",               \
                __FILE__, __LINE__, cudaGetErrorString(err));                     \
        exit(EXIT_FAILURE);                                                       \
    }                                                                             \
} while (0)

#include "cuda/earth_scene.cuh"

__global__ void free_world(hittable** list_d, camera** cam_d) {
    for (int i = 0; i < WORLD_SIZE; i++)
        delete list_d[i];
    delete* cam_d;
}

__global__ void initialize_random_states(seed_t* states, int width, int height,
    unsigned long long seed) {
    int pixel_x = blockIdx.x * blockDim.x + threadIdx.x;
    int pixel_y = blockIdx.y * blockDim.y + threadIdx.y;
    if (!(pixel_x < width && pixel_y < height)) return;
    int index = pixel_y * width + pixel_x;
    curand_init(seed, index, 0, &states[index]);
}

__global__ void render(hittable** world, camera** cam,
    seed_t* states, uint8_t* buffer) {
    int pixel_x = blockIdx.x * blockDim.x + threadIdx.x;
    int pixel_y = blockIdx.y * blockDim.y + threadIdx.y;
    if (pixel_x >= (*cam)->image_width || pixel_y >= (*cam)->image_height) return;

    int    index = pixel_y * (*cam)->image_width + pixel_x;
    seed_t local_state = states[index];

    color pixel_color(0, 0, 0);
    for (int s = 0; s < (*cam)->samples_per_pixel; s++) {
        ray r = (*cam)->get_ray(pixel_x, pixel_y, &local_state);
        pixel_color += (*cam)->ray_color(r, (*cam)->max_depth, **world, &local_state);
    }
    get_colors((*cam)->pixel_samples_scale * pixel_color, &buffer[index * 3]);
}

void framebuffer_size_callback(GLFWwindow* window, int width, int height) {
    glViewport(0, 0, width, height);
}

void save_frame(const char* filename, int w, int h, int ch, const uint8_t* buf) {
    if (stbi_write_png(filename, w, h, ch, buf, w * ch))
        fprintf(stderr, "Saved %s\n", filename);
    else
        fprintf(stderr, "Failed to save %s\n", filename);
}

int main() {
    CUDA_CHECK(cudaDeviceSetLimit(cudaLimitMallocHeapSize, 32 * 1024 * 1024));

    hittable** list_d;
    CUDA_CHECK(cudaMalloc((void**)&list_d, sizeof(hittable*) * WORLD_SIZE));
    hittable** world_d;
    CUDA_CHECK(cudaMalloc((void**)&world_d, sizeof(hittable*)));
    camera** cam_d;
    CUDA_CHECK(cudaMalloc((void**)&cam_d, sizeof(camera*)));

    size_t   buffer_size = IMAGE_WIDTH * IMAGE_HEIGHT * 3 * sizeof(uint8_t);
    uint8_t* buffer_d;
    CUDA_CHECK(cudaMalloc((void**)&buffer_d, buffer_size));
    uint8_t* buffer_h;
    CUDA_CHECK(cudaMallocHost((void**)&buffer_h, buffer_size));

    seed_t* states_d;
    CUDA_CHECK(cudaMalloc((void**)&states_d, IMAGE_WIDTH * IMAGE_HEIGHT * sizeof(seed_t)));
    int ew, eh, mw, mh, vw, vh, ch;

    unsigned char* eh_host = stbi_load("assets/earthmap.jpg", &ew, &eh, &ch, 3);
    unsigned char* mh_host = stbi_load("assets/marsmap.jpg", &mw, &mh, &ch, 3);
    unsigned char* vh_host = stbi_load("assets/venusmap.jpg", &vw, &vh, &ch, 3);

    uint8_t* earth_dev = nullptr, * mars_dev = nullptr, * venus_dev = nullptr;

    auto upload = [](unsigned char* host, uint8_t** dev, int w, int h, const char* name) {
        if (host) {
            cudaMalloc(dev, w * h * 3);
            cudaMemcpy(*dev, host, w * h * 3, cudaMemcpyHostToDevice);
            stbi_image_free(host);
        }
        else {
            fprintf(stderr, "Warning: could not load %s\n", name);
        }
        };

    upload(eh_host, &earth_dev, ew, eh, "earthmap.jpg");
    upload(mh_host, &mars_dev, mw, mh, "marsmap.jpg");
    upload(vh_host, &venus_dev, vw, vh, "venusmap.jpg");
    // ── Scene + BVH construction ─────────────────────────────────────────────

    CUDA_CHECK(cudaDeviceSetLimit(cudaLimitStackSize, 8 * 1024));
    init_scene << <1, 1 >> > (list_d, world_d, cam_d,
        earth_dev, ew, eh,
        mars_dev, mw, mh,
        venus_dev, vw, vh);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());
    CUDA_CHECK(cudaDeviceSetLimit(cudaLimitStackSize, 2 * 1024));

    int  tx = 16, ty = 16;
    dim3 blocks((IMAGE_WIDTH + tx - 1) / tx,
        (IMAGE_HEIGHT + ty - 1) / ty);
    dim3 threads(tx, ty);

    initialize_random_states << <blocks, threads >> > (
        states_d, IMAGE_WIDTH, IMAGE_HEIGHT, 1234ULL);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());

    // ── GLFW / OpenGL setup ──────────────────────────────────────────────────

    glfwInit();
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_CONTEXT_CREATION_API, GLFW_NATIVE_CONTEXT_API);

    GLFWwindow* window = glfwCreateWindow(IMAGE_WIDTH, IMAGE_HEIGHT,
        "CUDA Ray Tracer", NULL, NULL);
    if (!window) {
        fprintf(stderr, "Failed to create GLFW window\n");
        glfwTerminate();
        return -1;
    }
    glfwMakeContextCurrent(window);
    glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);

    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)) {
        fprintf(stderr, "Failed to initialize GLAD\n");
        return -1;
    }

    Shader shader("vertexShader.vs", "FragShader.fs");

    float vertices[] = {
         1.0f,  1.0f, 0.0f,  0.0f, 0.0f,
         1.0f, -1.0f, 0.0f,  0.0f, 1.0f,
        -1.0f, -1.0f, 0.0f,  1.0f, 1.0f,
        -1.0f,  1.0f, 0.0f,  1.0f, 0.0f,
    };
    unsigned int indices[] = { 0, 1, 3, 1, 2, 3 };

    unsigned int VAO, VBO, EBO;
    glGenVertexArrays(1, &VAO);
    glGenBuffers(1, &VBO);
    glGenBuffers(1, &EBO);
    glBindVertexArray(VAO);
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)(3 * sizeof(float)));
    glEnableVertexAttribArray(1);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindVertexArray(0);

    GLuint tex;
    glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_2D, tex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    shader.use();
    glUniform1i(glGetUniformLocation(shader.ID, "ourTexture"), 0);

    // ── Render ───────────────────────────────────────────────────────────────

    fprintf(stderr, "Rendering...\n");

    auto t_start = std::chrono::high_resolution_clock::now();

    render << <blocks, threads >> > (world_d, cam_d, states_d, buffer_d);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());

    auto t_end = std::chrono::high_resolution_clock::now();
    double seconds = std::chrono::duration<double>(t_end - t_start).count();
    fprintf(stderr, "Render time: %.2f s  (%.0f ms)\n", seconds, seconds * 1000.0);

    CUDA_CHECK(cudaMemcpy(buffer_h, buffer_d, buffer_size, cudaMemcpyDeviceToHost));

    save_frame("output.png", IMAGE_WIDTH, IMAGE_HEIGHT, 3, buffer_h);

    // ── Display ──────────────────────────────────────────────────────────────

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, IMAGE_WIDTH, IMAGE_HEIGHT,
        0, GL_RGB, GL_UNSIGNED_BYTE, buffer_h);

    bool s_was_pressed = false;
    while (!glfwWindowShouldClose(window)) {
        bool s_pressed = glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS;
        if (s_pressed && !s_was_pressed)
            save_frame("output.png", IMAGE_WIDTH, IMAGE_HEIGHT, 3, buffer_h);
        s_was_pressed = s_pressed;

        glClear(GL_COLOR_BUFFER_BIT);
        shader.use();
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, tex);
        glBindVertexArray(VAO);
        glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    // ── Cleanup ───────────────────────────────────────────────────────────────

    glDeleteVertexArrays(1, &VAO);
    glDeleteBuffers(1, &VBO);
    glDeleteBuffers(1, &EBO);
    glDeleteTextures(1, &tex);
    glfwTerminate();

    free_world << <1, 1 >> > (list_d, cam_d);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());

    cudaFree(list_d);
    cudaFree(world_d);
    cudaFree(cam_d);
    cudaFree(buffer_d);
    cudaFree(states_d);
    if (earth_dev) cudaFree(earth_dev);
    cudaFreeHost(buffer_h);
    return 0;
}
