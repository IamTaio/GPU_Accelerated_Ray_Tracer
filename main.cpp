#define __STDC_WANT_LIB_EXT1__ 1
#define STBI_MSC_SECURE_CRT
#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <iostream>
#include <thread>
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

#include "include/common.h"
#include "include/bvh.h"
#include "include/camera.h"
#include "include/hittable_list.h"
#include "include/material.h"
#include "include/sphere.h"
#include "include/shader.h"

// settings
const unsigned int IMAGE_WIDTH = 400;
const double ASPECT_RATIO = 16.0 / 9.0;
const unsigned int IMAGE_HEIGHT = int(IMAGE_WIDTH / ASPECT_RATIO);

void save_frame(const char* filename, int image_height, int image_width, int channels, const std::vector<uint8_t>& buffer);
void framebuffer_size_callback(GLFWwindow* window, int width, int height);


hittable_list build_scene() {
    hittable_list world;

    auto ground = make_shared<lambertian>(color(0.5, 0.5, 0.5));
    world.add(make_shared<sphere>(point3(0, -1000, 0), 1000, ground));

    world.add(make_shared<sphere>(point3(0, 1, 0), 1.0, make_shared<dielectric>(1.5)));
    world.add(make_shared<sphere>(point3(-4, 1, 0), 1.0, make_shared<lambertian>(color(0.4, 0.2, 0.1))));
    world.add(make_shared<sphere>(point3(4, 1, 0), 1.0, make_shared<metal>(color(0.7, 0.6, 0.5), 0.0)));

    return hittable_list(make_shared<bvh_node>(world));
}

camera build_camera() {
    camera cam;

    cam.aspect_ratio = ASPECT_RATIO;
    cam.image_width = IMAGE_WIDTH;
    cam.samples_per_pixel = 100;
    cam.max_depth = 50;

    cam.vfov = 20;
    cam.lookfrom = point3(13, 2, 3);
    cam.lookat = point3(0, 0, 0);
    cam.vup = vec3(0, 1, 0);

    cam.defocus_angle = 0.6;
    cam.focus_dist = 10.0;

    return cam;
}

int main()
{
    //SCENE
    // Scene
    hittable_list world = build_scene();
    camera cam = build_camera();

    std::vector<uint8_t> buffer(IMAGE_WIDTH * IMAGE_HEIGHT * 3);

    // GLFW
    glfwInit();
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

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
    std::thread t1([&]() { cam.render(world, buffer); });
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, IMAGE_WIDTH, IMAGE_HEIGHT, 0, GL_RGB, GL_UNSIGNED_BYTE, nullptr);

    bool s_was_pressed = false;

    // Loop
    while (!glfwWindowShouldClose(window)) {
        bool s_pressed = glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS;
        if (s_pressed && !s_was_pressed) {
            save_frame("output.png", IMAGE_HEIGHT, IMAGE_WIDTH, 3, buffer);
        }
        s_was_pressed = s_pressed;
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, IMAGE_WIDTH, IMAGE_HEIGHT, GL_RGB, GL_UNSIGNED_BYTE, buffer.data());

        shader.use();
        glBindVertexArray(VAO);
        glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);

        glfwSwapBuffers(window);
        glfwPollEvents();
    }
    t1.join();
    glDeleteVertexArrays(1, &VAO);
    glDeleteBuffers(1, &VBO);
    glDeleteBuffers(1, &EBO);
    glDeleteTextures(1, &tex);
    glfwTerminate();

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

void save_frame(const char* filename, int image_height, int image_width, int channels,const std::vector<uint8_t>& buffer) {
    if (stbi_write_png(filename, image_width, image_height, channels, buffer.data(), image_width * channels)) {
        std::cout << "Image successfully saved to: " << filename << "\n";
    }
    else {
        std::cout << "Image failed to save: \n";
    }
}
