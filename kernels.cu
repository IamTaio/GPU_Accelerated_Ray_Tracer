
#include "cuda/common.cuh"
#include "cuda/bvh.cuh"
#include "cuda/camera.cuh"
#include "cuda/hittable_list.cuh"
#include "cuda/material.cuh"
#include "cuda/sphere.cuh"
#include <cuda_runtime.h>

// settings
#define IMAGE_WIDTH 512
#define ASPECT_RATIO (16.0 / 9.0)
#define IMAGE_HEIGHT ((int)(IMAGE_WIDTH / ASPECT_RATIO))
#define WORLD_SIZE 4
#define DEG_TO_RAD (pi/180.0)

__global__ void kernel_warmup() {
    // Empty kernel for warmup
}

__global__ void init_scene(hittable** list_d, hittable_list* world_d, hittable_list* bvh_world_d, bvh_node* node_d, camera* cam_d){

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
    new (node_d) bvh_node(world_d);
    new (bvh_world_d) hittable_list(node_d);
}

__global__ void free_world(hittable** list_d) {

    for(int i=0; i < WORLD_SIZE; i++) {
        delete ((sphere *)list_d[i])->mat;
        delete list_d[i];
    }
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

__global__ void update_camera(camera* cam, float* theta){
    double rad = *theta * DEG_TO_RAD;
    double orig_x = cam->lookfrom.x();
    double orig_z = cam->lookfrom.z();

    cam->lookfrom = point3(
        orig_x *  cos(rad) + orig_z * sin(rad),
        cam->lookfrom.y(),
        orig_x * -sin(rad) + orig_z * cos(rad)
    );
    cam->initialize();
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


