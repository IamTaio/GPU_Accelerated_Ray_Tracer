#define __STDC_WANT_LIB_EXT1__ 1
#define STBI_MSC_SECURE_CRT
#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <iostream>
#include <thread>
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"
#include <time.h>

#include "cuda/common.cuh"
#include "cuda/bvh.cuh"
#include "cuda/camera.cuh"
#include "cuda/hittable_list.cuh"
#include "cuda/material.cuh"
#include "cuda/sphere.cuh"
#include "include/shader.h"
#include <cuda_runtime.h>

// settings
#define BLOCK_DIM 16
#define IMAGE_WIDTH 512
#define ASPECT_RATIO (16.0 / 9.0)
#define IMAGE_HEIGHT ((int)(IMAGE_WIDTH / ASPECT_RATIO))
#define WORLD_SIZE 4

float Theta = 0.0f;

void save_frame(const char* filename, int image_height, int image_width, int channels, const uint8_t* buffer);
void framebuffer_size_callback(GLFWwindow* window, int width, int height);

#define CUDA_CHECK(call)                                                          \
do {                                                                              \
    cudaError_t err = call;                                                       \
    if (err != cudaSuccess) {                                                     \
        fprintf(stderr, "CUDA error in file '%s' at line %d: %s\n",               \
                __FILE__, __LINE__, cudaGetErrorString(err));                     \
        exit(EXIT_FAILURE);                                                       \
    }                                                                             \
} while (0)

extern __global__ void kernel_warmup();
extern __global__ void init_scene(hittable** list_d, hittable_list* world_d, hittable_list* bvh_world_d, bvh_node* node_d, camera* cam_d);
extern __global__ void free_world(hittable** list_d);
extern __global__ void initialize_random_states(seed_t* states, int width, int height, unsigned long long seed);
extern __global__ void render(hittable* world, camera* cam, seed_t* states, uint8_t* buffer);
extern __global__ void update_camera(camera* cam, float* theta);
void rotate_left(){
    Theta += 5.0;
}
void rotate_right(){
    Theta -= 5.0;
}

void key_callback(GLFWwindow* window, int key, int scancode, int action, int mods){
    if (action != GLFW_PRESS) return;
    switch(key){
        case GLFW_KEY_LEFT:
            rotate_left();
            break;
        case GLFW_KEY_RIGHT:
            rotate_right();
            break;
    }
}

int main()
{
    // kernel_warmup<<<1,1>>>();
    
    hittable** list_d;
    CUDA_CHECK(cudaMalloc((void**) &list_d, sizeof(hittable*) * WORLD_SIZE));

    hittable_list* world_d;
    CUDA_CHECK(cudaMalloc((void**) &world_d, sizeof(hittable_list)));
    
    bvh_node* node_d;
    CUDA_CHECK(cudaMalloc((void**) &node_d, sizeof(bvh_node)));
    
    hittable_list* bvh_world_d;
    CUDA_CHECK(cudaMalloc((void**) &bvh_world_d, sizeof(hittable_list)));
    
    camera* cam_d;
    CUDA_CHECK(cudaMalloc((void**) &cam_d, sizeof(camera)));
    
    size_t buffer_size = IMAGE_WIDTH * IMAGE_HEIGHT * 3 * sizeof(uint8_t);
    
    uint8_t* buffer_d;
    CUDA_CHECK(cudaMalloc((void**) &buffer_d, buffer_size));
    
    uint8_t* buffer_h;
    CUDA_CHECK(cudaMallocHost((void**) &buffer_h, buffer_size));
    
    seed_t* states_d;
    CUDA_CHECK(cudaMalloc((void**) &states_d, IMAGE_WIDTH * IMAGE_HEIGHT * sizeof(seed_t)));

    float* theta_d;
    CUDA_CHECK(cudaMalloc((void**) &theta_d, sizeof(float)));
    
    int tx = BLOCK_DIM; int ty = BLOCK_DIM;
    dim3 threads(tx, ty, 1);
    dim3 grid(IMAGE_WIDTH/threads.x,IMAGE_HEIGHT/threads.y);
    
    clock_t start_time = clock();
    init_scene<<<1,1>>>(list_d, world_d, bvh_world_d, node_d, cam_d);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());


    // GLFW
    glfwInit();
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_CONTEXT_CREATION_API, GLFW_NATIVE_CONTEXT_API);

    GLFWwindow* window = glfwCreateWindow(IMAGE_WIDTH, IMAGE_HEIGHT, "Ray Tracer", NULL, NULL);
    if (!window) {
        std::cerr << "Failed to create GLFW window\n";
        glfwTerminate();
        return -1;
    }
    glfwMakeContextCurrent(window);
    glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);
    glfwSetKeyCallback(window, key_callback);
    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)) {
        std::cerr << "Failed to initialize GLAD\n";
        return -1;
    }

    // Shaders
    Shader shader("vertexShader.vs", "FragShader.fs");

    // Fullscreen quad
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

    // Texture
    GLuint tex;
    glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_2D, tex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    // Render and upload
    initialize_random_states<<<grid, threads>>>(states_d, IMAGE_WIDTH, IMAGE_HEIGHT, 1234ULL);
    CUDA_CHECK(cudaGetLastError());
    render<<<grid, threads>>>(bvh_world_d, cam_d, states_d, buffer_d);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());
    CUDA_CHECK(cudaMemcpy(buffer_h, buffer_d, buffer_size, cudaMemcpyDeviceToHost));
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, IMAGE_WIDTH, IMAGE_HEIGHT, 0, GL_RGB, GL_UNSIGNED_BYTE, buffer_h);

    bool s_was_pressed = false;
    // int frames = 0;
    // start_time = clock();
    // Loop
    while (!glfwWindowShouldClose(window)) {
        
        bool s_pressed = glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS;
        // bool left_pressed = glfwGetKey(window, GLFW_KEY_LEFT) == GLFW_PRESS;
        // bool right_pressed = glfwGetKey(window, GLFW_KEY_RIGHT) == GLFW_PRESS;
        if (s_pressed && !s_was_pressed) {
            save_frame("output.png", IMAGE_HEIGHT, IMAGE_WIDTH, 3, buffer_h);
        }
        s_was_pressed = s_pressed;
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        
        if(Theta != 0.0f){
            CUDA_CHECK(cudaMemcpy(theta_d, &Theta, sizeof(float), cudaMemcpyHostToDevice));
            update_camera<<<1,1>>>(cam_d, theta_d);
            Theta = 0.0f;
        }
        initialize_random_states<<<grid, threads>>>(states_d, IMAGE_WIDTH, IMAGE_HEIGHT, 1234ULL);
        CUDA_CHECK(cudaGetLastError());
        render<<<grid, threads>>>(bvh_world_d, cam_d, states_d, buffer_d);
        CUDA_CHECK(cudaGetLastError());
        CUDA_CHECK(cudaDeviceSynchronize());
        CUDA_CHECK(cudaMemcpy(buffer_h, buffer_d, buffer_size, cudaMemcpyDeviceToHost));
        

        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, IMAGE_WIDTH, IMAGE_HEIGHT, GL_RGB, GL_UNSIGNED_BYTE, buffer_h);

        shader.use();
        glBindVertexArray(VAO);
        glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);

        glfwSwapBuffers(window);
        glfwPollEvents();
        // frames++;
    }

    // clock_t end_time = clock();
    // double elapsed = ((double)(end_time - start_time)) / CLOCKS_PER_SEC * 1000.0;

    // printf("Average time for rendering a single frame: %d", elapsed/frames);

    glDeleteVertexArrays(1, &VAO);
    glDeleteBuffers(1, &VBO);
    glDeleteBuffers(1, &EBO);
    glDeleteTextures(1, &tex);
    glfwTerminate();

    free_world<<<1,1>>>(list_d);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());
    
    cudaFree(node_d);
    cudaFree(bvh_world_d);
    cudaFree(world_d);
    cudaFree(cam_d);
    cudaFree(buffer_d);
    cudaFree(states_d); 
    cudaFreeHost(buffer_h);
    return 0;
}

// glfw: whenever the window size changed (by OS or user resize) this callback function executes
// ---------------------------------------------------------------------------------------------
void framebuffer_size_callback(GLFWwindow* window, int width, int height)
{
    // make sure the viewport matches the new window dimensions; note that width and 
    // height will be significantly larger than specified on retina displays.
    glViewport(0, 0, width, height);
}

void save_frame(const char* filename, int image_height, int image_width, int channels,const uint8_t* buffer) {
    if (stbi_write_png(filename, image_width, image_height, channels, buffer, image_width * channels)) {
        std::cout << "Image successfully saved to: " << filename << "\n";
    }
    else {
        std::cout << "Image failed to save: \n";
    }
}
