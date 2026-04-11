#pragma once

#include <cmath>
#include <cstdlib>
#include <iostream>
#include <limits>
#include <memory>
#include <limits>
#include <random>

using std::make_shared;
using std::shared_ptr;

const double infinity = std::numeric_limits<double>::infinity();
const double pi = 3.1415926535897932385;

inline double degrees_to_radians(double degrees) {
	return degrees * pi / 180.0;
}

inline double random_double() {
	static std::mt19937 generator(std::random_device{}());
	static std::uniform_real_distribution<double> dis(0.0, 1.0);
	return dis(generator);
}

inline double random_double(double min, double max) {
	return min + (max - min) * random_double();
}

inline int random_int(int min, int max) {
	static std::mt19937 generator(std::random_device{}());
	static std::uniform_int_distribution<int> dis(min, max);
	return dis(generator);
}

