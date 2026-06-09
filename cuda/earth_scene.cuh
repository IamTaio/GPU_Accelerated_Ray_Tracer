#pragma once

__global__ void init_scene(hittable** list_d, hittable** world_d, camera** cam_d,
    uint8_t* earth_dev, int earth_w, int earth_h,
    uint8_t* mars_dev, int mars_w, int mars_h,
    uint8_t* venus_dev, int venus_w, int venus_h) {

    *cam_d = new camera();
    (*cam_d)->aspect_ratio = ASPECT_RATIO;
    (*cam_d)->image_width = IMAGE_WIDTH;
    (*cam_d)->samples_per_pixel = 500;
    (*cam_d)->max_depth = 50;
    (*cam_d)->vfov = 20;
    (*cam_d)->lookfrom = point3(13, 2, 3);
    (*cam_d)->lookat = point3(0, 0, 0);
    (*cam_d)->vup = vec3(0, 1, 0);
    (*cam_d)->defocus_angle = 0.6;
    (*cam_d)->focus_dist = 10.0;
    (*cam_d)->initialize();

    size_t i = 0;

    // Ground — solid grey sphere
    list_d[i++] = new sphere(point3(0, -1000, 0), 1000,
        new lambertian(color(0.5, 0.5, 0.5)));

    // Planet spheres
    list_d[i++] = new sphere(point3(-4, 1, 0), 1.0,
        new lambertian(new image_texture(mars_dev, mars_w, mars_h)));
    list_d[i++] = new sphere(point3(0, 1, 0), 1.0,
        new lambertian(new image_texture(earth_dev, earth_w, earth_h)));
    list_d[i++] = new sphere(point3(4, 1, 0), 1.0,
        new lambertian(new image_texture(venus_dev, venus_w, venus_h)));

#ifdef USE_BVH
    * world_d = new bvh_node(list_d, 0, i);
#else
    * world_d = new hittable_list(list_d, i);
#endif
}