#pragma once

#include "common.cuh"
#include "read_image.h"

class texture {
public:
    __device__ virtual ~texture() = default;
    __device__ virtual color value(double u, double v, const point3& p) const = 0;
};

class solid_color : public texture {
public:
    __device__ solid_color(const color& albedo) : albedo(albedo) {}
    __device__ solid_color(double r, double g, double b) : albedo(color(r, g, b)) {}

    __device__ color value(double u, double v, const point3& p) const override {
        return albedo;
    }
private:
    color albedo;
};

class checker_texture : public texture {
public:

    __device__ checker_texture(double scale, texture* even, texture* odd)
        : inv_scale(1.0 / scale), even(even), odd(odd) {
    }

    __device__ checker_texture(double scale, const color& c1, const color& c2)
        : inv_scale(1.0 / scale),
        even(new solid_color(c1)),
        odd(new solid_color(c2)) {
    }

    __device__ ~checker_texture() override {
        delete even;
        delete odd;
    }

    __device__ color value(double u, double v, const point3& p) const override {
        auto xInteger = int(floor(inv_scale * p.x()));
        auto yInteger = int(floor(inv_scale * p.y()));
        auto zInteger = int(floor(inv_scale * p.z()));
        bool isEven = (xInteger + yInteger + zInteger) % 2 == 0;
        return isEven ? even->value(u, v, p) : odd->value(u, v, p);
    }

private:
    double   inv_scale;
    texture* even;
    texture* odd;
};

// In texture.cuh — device-compatible, no read_image dependency
class image_texture : public texture {
public:
    __device__ image_texture(const uint8_t* dev_data, int width, int height)
        : data(dev_data), image_width(width), image_height(height) {
    }

    __device__ color value(double u, double v, const point3& p) const override {
        if (!data || image_height <= 0) return color(0, 1, 1);

        u = interval(0, 1).clamp(u);
        v = 1.0 - interval(0, 1).clamp(v);

        int i = int(u * image_width);
        int j = int(v * image_height);
        if (i >= image_width)  i = image_width - 1;
        if (j >= image_height) j = image_height - 1;

        const uint8_t* pixel = data + (j * image_width + i) * 3;
        auto cs = 1.0 / 255.0;
        return color(cs * pixel[0], cs * pixel[1], cs * pixel[2]);
    }

private:
    const uint8_t* data;
    int image_width;
    int image_height;
};