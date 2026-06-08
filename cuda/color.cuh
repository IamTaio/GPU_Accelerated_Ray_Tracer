#pragma once

#include "interval.cuh"
#include "vec3.cuh"

using color = vec3;

 __device__ inline double linear_to_gamma(double linear_component) {
    if (linear_component > 0) {
        return sqrt(linear_component);
    }
    return 0;
}

//  inline void write_color(std::ostream& out, const color& pixel_color) {
//     auto r = linear_to_gamma(pixel_color.x());
//     auto g = linear_to_gamma(pixel_color.y());
//     auto b = linear_to_gamma(pixel_color.z());


//     // Translate the [0,1] component values to the byte range [0,255].
//     const interval intensity(0.000, 0.999);
//     int rbyte = int(256 * intensity.clamp(r));
//     int gbyte = int(256 * intensity.clamp(g));
//     int bbyte = int(256 * intensity.clamp(b));

//     // Write out the pixel color components.
//     out << rbyte << ' ' << gbyte << ' ' << bbyte << '\n';
// }

 __device__ inline void get_colors(const color& pixel_color, uint8_t* out) {
    auto r = linear_to_gamma(pixel_color.x());
    auto g = linear_to_gamma(pixel_color.y());
    auto b = linear_to_gamma(pixel_color.z());

    const interval intensity(0.000, 0.999);
    
    out[0] = static_cast<uint8_t>(256 * intensity.clamp(r));
    out[1] = static_cast<uint8_t>(256 * intensity.clamp(g));
    out[2] = static_cast<uint8_t>(256 * intensity.clamp(b));
}