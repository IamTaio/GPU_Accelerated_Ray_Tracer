#pragma once

#include "utils.cuh"

class interval {
public:
	double min, max;

	constexpr __device__ interval() : min(+infinity), max(-infinity) {}

	constexpr __device__ interval(double min, double max) : min(min), max(max) {}

	 __device__ interval(const interval& a, const interval& b) {
		min = fminf(a.min, b.min);
		max = fmaxf(a.max, b.max);
	}

	 __device__ double size() const {
		return max - min;
	}

	 __device__ bool contains(double x) const {
		return min <= x && x <= max;
	}

	 __device__ bool surrounds(double x) const {
		return min < x && x < max;
	}

	 __device__ double clamp(double x) const {
		if (x < min) return min;
		if (x > max) return max;
		return x;
	}

	 __device__ interval expand(double delta) const {
		auto padding = delta / 2;
		return interval(min - padding, max + padding);
	}

	__device__ static interval empty(){
		return interval(+infinity, -infinity);
	}

	__device__ static interval universe(){
		return interval(-infinity, +infinity);
	}
	
};




