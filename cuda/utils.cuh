#pragma once

#include <cmath>
#include <cstdlib>
#include <float.h>
#include <random>
#include <curand.h>
#include <curand_kernel.h>
const double infinity = DBL_MAX;
const double pi = 3.1415926535897932385;
typedef curandState seed_t;

 __device__ inline double degrees_to_radians(double degrees) {
	return degrees * pi / 180.0;
}

 __device__ inline double random_double(seed_t* seed) {
	
	#ifdef __CUDA_ARCH__
		return curand_uniform(seed);
	#else
		static std::mt19937 generator(std::random_device{}());
		static std::uniform_real_distribution<double> dis(0.0, 1.0);
		return dis(generator);
	#endif
}

 __device__ inline double random_double(double min, double max, seed_t* seed) {
	return min + (max - min) * random_double(seed);
}

 __device__ inline int random_int(int min, int max, seed_t* seed) {
	#ifdef __CUDA_ARCH__
		return min + static_cast<int>(curand_uniform(seed) * (max - min + 1));
	#else
		static std::mt19937 generator(std::random_device{}());
		static std::uniform_int_distribution<int> dis(min, max);
		return dis(generator);
	#endif
}


