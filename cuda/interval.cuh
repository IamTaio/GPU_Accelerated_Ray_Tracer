#pragma once

#include "utils.cuh"

class interval {
public:
	double min, max;

	__device__ __host__ interval() : min(+infinity), max(-infinity) {}

	__device__ __host__ interval(double min, double max) : min(min), max(max) {}

	__device__ __host__ interval(const interval& a, const interval& b) {
		min = fmin(a.min, b.min);
		max = fmax(a.max, b.max);
	}

	__device__ __host__ double size() const {
		return max - min;
	}

	__device__ __host__ bool contains(double x) const {
		return min <= x && x <= max;
	}

	__device__ __host__ bool surrounds(double x) const {
		return min < x && x < max;
	}

	__device__ __host__ double clamp(double x) const {
		if (x < min) return min;
		if (x > max) return max;
		return x;
	}

	__device__ __host__ interval expand(double delta) const {
		auto padding = delta / 2;
		return interval(min - padding, max + padding);
	}

	static const interval empty, universe;
};



