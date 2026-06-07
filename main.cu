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

#define nThreads 512

// settings
const unsigned int IMAGE_WIDTH = 400;
const double ASPECT_RATIO = 16.0 / 9.0;
const unsigned int IMAGE_HEIGHT = int(IMAGE_WIDTH / ASPECT_RATIO);

void save_frame(const char* filename, int image_height, int image_width, int channels, const uint8_t* buffer);
void framebuffer_size_callback(GLFWwindow* window, int width, int height);

__global__ void init_camera(camera* cam){
    cam->aspect_ratio = ASPECT_RATIO;
    cam->image_width = IMAGE_WIDTH;
    cam->samples_per_pixel = 100;
    cam->max_depth = 50;

    cam->vfov = 20;
    cam->lookfrom = point3(13, 2, 3);
    cam->lookat = point3(0, 0, 0);
    cam->vup = vec3(0, 1, 0);

    cam->defocus_angle = 0.6;
    cam->focus_dist = 10.0;
    cam->initialize();
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

__global__ void render(const hittable& world, camera* cam, seed_t* states, uint8_t* buffer) {

		int pixel_x = blockIdx.x * blockDim.x + threadIdx.x;
		int pixel_y = blockIdx.y * blockDim.y + threadIdx.y;
		
		if(!(pixel_x < cam->image_width && pixel_y < cam->image_height)){
			return;
		}

		int index = pixel_y * cam->image_width + pixel_x;
		seed_t local_state = states[index];

		// std::cout << "P3\n" << image_width << ' ' << image_height << "\n255\n";
		
		color pixel_color(0, 0, 0);
		for (int sample = 0; sample < cam->samples_per_pixel; sample++) {
			ray r = cam->get_ray(pixel_y, pixel_x, local_state);
			pixel_color += cam->ray_color(r, cam->max_depth, world, local_state);
		}

		for (int channel = 0; channel < 3; channel++) {
			buffer[index * 3 + channel] = pixel_color[channel];
		}
		// write_color(std::cout, cam.pixel_samples_scale * pixel_color);
		// std::clog << "\rDone.                                      \n";
}


int main()
{
    //SCENE
    // Scene
    cudaSetDevice(1);
    size_t num_objects = 4;
    hittable** objects = NULL;
    cudaMallocManaged(&objects, sizeof(hittable*)*num_objects);

    lambertian* ground_mat = NULL; 
    cudaMallocManaged(&ground_mat, sizeof(lambertian));
    new (ground_mat) lambertian(color(0.5, 0.5, 0.5));

    lambertian* s2_mat = NULL;
    cudaMallocManaged(&s2_mat, sizeof(lambertian));
    new (s2_mat) lambertian(color(0.4, 0.2, 0.1));

    dielectric* s1_mat = NULL; 
    cudaMallocManaged(&s1_mat, sizeof(dielectric));
    new (s1_mat) dielectric(1.5);

    metal* s3_mat = NULL;
    cudaMallocManaged(&s3_mat, sizeof(metal));
    new (s3_mat) metal(color(0.7, 0.6, 0.5), 0.0);

    sphere* ground = NULL;
    cudaMallocManaged(&ground, sizeof(sphere));
    new (ground) sphere(point3(0, -1000, 0), 1000, ground_mat);

    sphere* s1 = NULL;
    cudaMallocManaged(&s1, sizeof(sphere));
    new (s1) sphere(point3(0, 1, 0), 1.0, s1_mat);

    sphere* s2 = NULL;
    cudaMallocManaged(&s2, sizeof(sphere));
    new (s2) sphere(point3(-4, 1, 0), 1.0, s2_mat);

    sphere* s3 = NULL;
    cudaMallocManaged(&s3, sizeof(sphere));
    new (s3) sphere(point3(4, 1, 0), 1.0, s3_mat);

    hittable_list* world = NULL;
    cudaMallocManaged(&world, sizeof(hittable_list));
    new (world) hittable_list();

    world->add(ground);
    world->add(s1);
    world->add(s2);
    world->add(s3);

    camera* cam = NULL;
    cudaMallocManaged(&cam, sizeof(camera));
    new (cam) camera();

    init_camera<<<1,1>>>(cam);
    cudaDeviceSynchronize();

    size_t buffer_size = IMAGE_WIDTH * IMAGE_HEIGHT * 3 * sizeof(uint8_t);
    uint8_t* buffer_d = NULL;
    cudaMalloc((void**) &buffer_d, buffer_size);

    uint8_t* buffer_h = NULL;
    cudaMallocHost((void**) &buffer_h, buffer_size);

    seed_t* states = NULL;
    cudaMalloc((void**) &states, IMAGE_WIDTH * IMAGE_HEIGHT * sizeof(seed_t));

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
    initialize_random_states<<<(IMAGE_HEIGHT * IMAGE_WIDTH)/nThreads, nThreads>>>(states, IMAGE_WIDTH, IMAGE_HEIGHT, 1234ULL);
    render<<<(IMAGE_HEIGHT * IMAGE_WIDTH)/nThreads, nThreads>>>(*world, cam, states, buffer_d);
    cudaMemcpy(buffer_h, buffer_d, buffer_size, cudaMemcpyDeviceToHost);
    
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
        initialize_random_states<<<(IMAGE_HEIGHT * IMAGE_WIDTH)/nThreads, nThreads>>>(states, IMAGE_WIDTH, IMAGE_HEIGHT, 1234ULL);
        render<<<(IMAGE_HEIGHT * IMAGE_WIDTH)/nThreads, nThreads>>>(*world, cam, states, buffer_d);
        cudaMemcpy(buffer_h, buffer_d, buffer_size, cudaMemcpyDeviceToHost);

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

    cudaFree(ground_mat);
    cudaFree(ground);
    cudaFree(s1_mat);
    cudaFree(s1);
    cudaFree(s2_mat);
    cudaFree(s2);
    cudaFree(s3_mat);
    cudaFree(s3);
    cudaFree(world);
    cudaFree(cam);
    cudaFree(buffer_d);
    cudaFree(states); 
    cudaFree(objects);
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
