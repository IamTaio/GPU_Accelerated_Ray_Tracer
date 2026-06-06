#pragma once

#include "vec3.cuh"

class ray {
private:
	point3 orig;
	vec3 dir;
	double tm;
public:
	__device__ __host__ ray() : tm(0) {}

	__device__ __host__ ray(const point3& origin, const vec3& direction, double time) : orig(origin), dir(direction), tm(time) {}

	__device__ __host__ ray(const point3& origin, const vec3& direction) : ray(origin, direction, 0) {}

	__device__ __host__ const point3& origin() const { return orig; }
	__device__ __host__ const vec3& direction() const { return dir; }

	__device__ __host__ double time() const { return tm; }

	__device__ __host__ point3 at(double t) const {
		return orig + t * dir;
	}
};