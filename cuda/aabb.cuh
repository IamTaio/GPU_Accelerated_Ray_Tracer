#pragma once

#include "common.cuh"


class aabb {
public:
	interval x, y, z;

	__device__ aabb() {}

	__device__ aabb(const interval& x, const interval& y, const interval& z) : x(x), y(y), z(z) {}

	__device__ aabb(const point3& a, const point3& b) {
		// The points a and b represent two extremas of the bounding box.

		x = (a[0] <= b[0]) ? interval(a[0], b[0]) : interval(b[0], a[0]);
		y = (a[1] <= b[1]) ? interval(a[1], b[1]) : interval(b[1], a[1]);
		z = (a[2] <= b[2]) ? interval(a[2], b[2]) : interval(b[2], a[2]);
	}

	__device__ aabb(const aabb& box0, const aabb& box1) {
		x = interval(box0.x, box1.x);
		y = interval(box0.y, box1.y);
		z = interval(box0.z, box1.z);
	}

	__device__ interval operator[](int i) const {
		if (i == 1) return y;
		if (i == 2) return z;
		return x;
	}

	__device__ interval& operator[](int i) {
		if (i == 1) return y;
		if (i == 2) return z;
		return x;
	}

	__device__ bool hit(const ray& r, interval ray_t) const {
		const point3& ray_orig = r.origin();
		const vec3& ray_dir = r.direction();

		for (int axis = 0; axis < 3; axis++) {
			const interval& ax = (*this)[axis];
			const double inverse_dir = 1.0 / ray_dir[axis];

			double t0 = (ax.min - ray_orig[axis]) * inverse_dir;
			double t1 = (ax.max - ray_orig[axis]) * inverse_dir;

			ray_t.min = fmaxf(ray_t.min, fminf(t0, t1));
			ray_t.max = fminf(ray_t.max, fmaxf(t0, t1));

			if (ray_t.max <= ray_t.min) return false;
		}

		return true;
	}

	__device__ int longest_axis() const {
		// Returns the index of the longest axis of the bounding box.

		if (x.size() > y.size()) {
			return x.size() > z.size() ? 0 : 2;
		}
		else {
			return y.size() > z.size() ? 1 : 2;
		}
	}

	static const aabb empty, universe;
};
