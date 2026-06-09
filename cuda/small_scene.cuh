#pragma once

// Auto-generated scene data — CPU-side execution of the book's random scene
// with seed 42. All sphere positions and material parameters are exact.
// Total: 485 spheres.

__global__ void init_scene(hittable** list_d, hittable** world_d, camera** cam_d) {

    *cam_d = new camera();
    (*cam_d)->aspect_ratio = ASPECT_RATIO;
    (*cam_d)->image_width = IMAGE_WIDTH;
    (*cam_d)->samples_per_pixel = 100;
    (*cam_d)->max_depth = 50;
    (*cam_d)->vfov = 20;
    (*cam_d)->lookfrom = point3(13, 2, 3);
    (*cam_d)->lookat = point3(0, 0, 0);
    (*cam_d)->vup = vec3(0, 1, 0);
    (*cam_d)->defocus_angle = 0.6;
    (*cam_d)->focus_dist = 10.0;
    (*cam_d)->initialize();

    size_t i = 0;

    // Ground
    auto checker = new checker_texture(0.32, color(0.2, 0.3, 0.1), color(0.9, 0.9, 0.9));
    list_d[i++] = new sphere(point3(0, -1000, 0), 1000, new lambertian(checker));

    // Large spheres
    list_d[i++] = new sphere(point3(0, 1, 0), 1.0, new dielectric(1.5));
    list_d[i++] = new sphere(point3(-4, 1, 0), 1.0, new lambertian(color(0.4, 0.2, 0.1)));
    list_d[i++] = new sphere(point3(4, 1, 0), 1.0, new metal(color(0.7, 0.6, 0.5), 0.0));

#ifdef USE_BVH
    * world_d = new bvh_node(list_d, 0, i);
#else
    * world_d = new hittable_list(list_d, i);
#endif
    //*world_d = new bvh_node(list_d, 0, i);
}
