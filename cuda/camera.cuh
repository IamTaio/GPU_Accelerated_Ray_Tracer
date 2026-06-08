#pragma once

#include "common.cuh"
#include "hittable.cuh"
#include "material.cuh"
#include <cuda_runtime.h>
#include <curand_kernel.h>

class camera {
private:
	point3 center;
	point3 pixel00_loc;
	vec3 pixel_delta_u;
	vec3 pixel_delta_v;
	vec3 u, v, w;
	vec3 defocus_disk_u;
	vec3 defocus_disk_v;


public:
	double pixel_samples_scale;
	int image_height;
	double aspect_ratio = 1.0;
	int image_width = 100;
	int samples_per_pixel = 10;
	int max_depth = 10;

	double vfov = 90;
	point3 lookfrom = point3(0, 0, 0);
	point3 lookat = point3(0, 0, -1);
	vec3 vup = vec3(0, 1, 0);

	double defocus_angle = 0;
	double focus_dist = 10;

	__device__ void initialize() {
		image_height = int(image_width / aspect_ratio);
		image_height = (image_height < 1) ? 1 : image_height;

		pixel_samples_scale = 1.0 / samples_per_pixel;

		center = lookfrom;

		// Determine viewport dimensions.
		auto theta = degrees_to_radians(vfov);
		auto h = tan(theta / 2);
		auto viewport_height = 2 * h * focus_dist;
		auto viewport_width = viewport_height * (double(image_width) / image_height);

		w = unit_vector(lookfrom - lookat);
		u = unit_vector(cross(vup, w));
		v = cross(w, u);

		// Calculate the vectors across the horizontal and down the vertical viewport edges.
		auto viewport_u = viewport_width * u;
		auto viewport_v = viewport_height * -v;

		// Calculate the horizontal and vertical delta vectors from pixel to pixel.
		pixel_delta_u = viewport_u / image_width;
		pixel_delta_v = viewport_v / image_height;

		auto viewport_upper_left = center - (focus_dist * w) - viewport_u / 2 - viewport_v / 2;
		pixel00_loc = viewport_upper_left + 0.5 * (pixel_delta_u + pixel_delta_v);

		auto defocus_radius = focus_dist * tan(degrees_to_radians(defocus_angle / 2));
		defocus_disk_u = u * defocus_radius;
		defocus_disk_v = v * defocus_radius;
	}

	__device__ ray get_ray(int i, int j, seed_t* seed) const {
		// Construct a camera ray originating from the defocus disk and directed at a randomly
		// sampled point around the pixel location i, j.

		auto offset = sample_square(seed);
		auto pixel_sample = pixel00_loc + ((i + offset.x()) * pixel_delta_u) + ((j + offset.y()) * pixel_delta_v);

		auto ray_origin = (defocus_angle <= 0) ? center : defocus_disk_sample(seed);
		auto ray_direction = pixel_sample - ray_origin;
		auto ray_time = random_double(seed);

		return ray(ray_origin, ray_direction, ray_time);
	}

	__device__ point3 defocus_disk_sample(seed_t* seed) const {
		auto p = random_in_unit_disk(seed);
		return center + (p[0] * defocus_disk_u) + (p[1] * defocus_disk_v);
	}

	__device__ vec3 sample_square(seed_t* seed) const {
		// Returns the vector to a random point in the [-.5, -.5] to [.5, .5] unit square.
		return vec3(random_double(seed) - 0.5, random_double(seed) - 0.5, 0);
	}

	__device__ color ray_color(ray r, int depth, const hittable& world, seed_t* seed) const {

		color result = color(1, 1, 1);
		for (int i = 0; i < depth; i++){
			hit_record rec;

			if (world.hit(r, interval(0.001, infinity), rec)) {
				ray scattered;
				color attenuation;
				if (rec.mat->scatter(r, rec, attenuation, scattered, seed)) {
					result = result * attenuation;
					r = scattered;
				} else {
					return color(0, 0, 0);
				}
				
			} else {
				vec3 unit_direction = unit_vector(r.direction());
				auto a = 0.5 * (unit_direction.y() + 1.0);
				color background = (1.0 - a) * color(1.0, 1.0, 1.0) + a * color(0.5, 0.7, 1.0);
				return result * background;
			}

		}
		return color(0, 0, 0);

	}

};