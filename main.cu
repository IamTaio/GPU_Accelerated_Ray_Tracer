#define __STDC_WANT_LIB_EXT1__ 1
#define STBI_MSC_SECURE_CRT
#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <iostream>
#include <thread>
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

#include "cuda/common.cuh"
#include "cuda/bvh.cuh"
#include "cuda/camera.cuh"
#include "cuda/hittable_list.cuh"
#include "cuda/material.cuh"
#include "cuda/sphere.cuh"
#include "include/shader.h"
#include <cuda_runtime.h>

// settings
#define nThreads 512
#define IMAGE_WIDTH 400
#define ASPECT_RATIO (16.0 / 9.0)
#define IMAGE_HEIGHT ((int)(IMAGE_WIDTH / ASPECT_RATIO))
#define WORLD_SIZE 4


__global__ void add(int *a, int *b, int *c) {
*c = *a + *b;
}

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

__global__ void init_scene(hittable** list_d, hittable_list* world_d, hittable_list* bvh_world_d, camera* cam_d){

    new (cam_d) camera();
    cam_d->aspect_ratio = ASPECT_RATIO;
    cam_d->image_width = IMAGE_WIDTH;
    cam_d->samples_per_pixel = 100;
    cam_d->max_depth = 50;

    cam_d->vfov = 20;
    cam_d->lookfrom = point3(13, 2, 3);
    cam_d->lookat = point3(0, 0, 0);
    cam_d->vup = vec3(0, 1, 0);

    cam_d->defocus_angle = 0.6;
    cam_d->focus_dist = 10.0;
    cam_d->initialize();

    size_t i = 0;
    list_d[i++] = new sphere(point3(0, -1000, 0), 1000, new lambertian(color(0.5, 0.5, 0.5)));
    list_d[i++] = new sphere(point3(0, 1, 0), 1.0, new dielectric(1.5));
    list_d[i++] = new sphere(point3(-4, 1, 0), 1.0, new lambertian(color(0.4, 0.2, 0.1)));
    list_d[i++] = new sphere(point3(4, 1, 0), 1.0, new metal(color(0.7, 0.6, 0.5), 0.0));
    new (world_d) hittable_list(list_d, i);
    new (bvh_world_d) hittable_list(new bvh_node(*world_d));
}

__global__ void free_world(hittable** list_d, hittable_list* bvh_world_d) {

    for(int i=0; i < WORLD_SIZE; i++) {
        delete ((sphere *)list_d[i])->mat;
        delete list_d[i];
    }
    delete bvh_world_d->get_objects()[0];
}

__global__ void initialize_random_states(seed_t* states, int width, int height, unsigned long long seed){
	int pixel_x = blockIdx.x * blockDim.x + threadIdx.x;
	int pixel_y = blockIdx.y * blockDim.y + threadIdx.y;
	
	if(!(pixel_x < width && pixel_y < height)){
		return;
	}

	int index = pixel_y * width + pixel_x;
	curand_init(seed, index, 0, &states[index]);
}

__global__ void render(hittable* world, camera* cam, seed_t* states, uint8_t* buffer) {

		int pixel_x = blockIdx.x * blockDim.x + threadIdx.x;
		int pixel_y = blockIdx.y * blockDim.y + threadIdx.y;
		
		if(!(pixel_x < cam->image_width && pixel_y < cam->image_height)){
			return;
		}

		int index = pixel_y * cam->image_width + pixel_x;
		seed_t local_state = states[index];
		
		color pixel_color(0, 0, 0);
		for (int sample = 0; sample < cam->samples_per_pixel; sample++) {
			ray r = cam->get_ray(pixel_x, pixel_y, &local_state);
			pixel_color += cam->ray_color(r, cam->max_depth, *world, &local_state);
		}
			get_colors(cam->pixel_samples_scale * pixel_color, &buffer[index * 3]);

}


int main()
{

    hittable** list_d;
    CUDA_CHECK(cudaMalloc((void**) &list_d, sizeof(hittable*) * WORLD_SIZE));

    hittable_list* world_d;
    CUDA_CHECK(cudaMalloc((void**) &world_d, sizeof(hittable_list)));

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

    int tx = 8; int ty = 8;
    dim3 blocks(IMAGE_WIDTH/tx+1,IMAGE_HEIGHT/ty+1);
    dim3 threads(tx,ty);

    init_scene<<<1,1>>>(list_d, world_d, bvh_world_d, cam_d);
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
    initialize_random_states<<<blocks, threads>>>(states_d, IMAGE_WIDTH, IMAGE_HEIGHT, 1234ULL);
    CUDA_CHECK(cudaGetLastError());
    render<<<blocks, threads>>>(bvh_world_d, cam_d, states_d, buffer_d);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());
    CUDA_CHECK(cudaMemcpy(buffer_h, buffer_d, buffer_size, cudaMemcpyDeviceToHost));
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, IMAGE_WIDTH, IMAGE_HEIGHT, 0, GL_RGB, GL_UNSIGNED_BYTE, buffer_h);

    bool s_was_pressed = false;

    // Loop
    while (!glfwWindowShouldClose(window)) {
        
        bool s_pressed = glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS;
        if (s_pressed && !s_was_pressed) {
            save_frame("output.png", IMAGE_HEIGHT, IMAGE_WIDTH, 3, buffer_h);
        }
        s_was_pressed = s_pressed;
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        initialize_random_states<<<blocks, threads>>>(states_d, IMAGE_WIDTH, IMAGE_HEIGHT, 1234ULL);
        CUDA_CHECK(cudaGetLastError());
        render<<<blocks, threads>>>(bvh_world_d, cam_d, states_d, buffer_d);
        CUDA_CHECK(cudaGetLastError());
        CUDA_CHECK(cudaDeviceSynchronize());
        CUDA_CHECK(cudaMemcpy(buffer_h, buffer_d, buffer_size, cudaMemcpyDeviceToHost)); 

        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, IMAGE_WIDTH, IMAGE_HEIGHT, GL_RGB, GL_UNSIGNED_BYTE, buffer_h);

        shader.use();
        glBindVertexArray(VAO);
        glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);

        glfwSwapBuffers(window);
        glfwPollEvents();
    }
    glDeleteVertexArrays(1, &VAO);
    glDeleteBuffers(1, &VBO);
    glDeleteBuffers(1, &EBO);
    glDeleteTextures(1, &tex);
    glfwTerminate();

    free_world<<<1,1>>>(list_d, bvh_world_d);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());
    
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
