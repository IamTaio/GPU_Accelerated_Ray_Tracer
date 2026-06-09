#pragma once

#ifdef _MSC_VER
#pragma warning(push, 0)
#endif

#define STB_IMAGE_IMPLEMENTATION
#define STBI_FAILURE_USERMSG
#include "stb_image.h"   // lives in external/stb/

#include <cstdlib>
#include <iostream>
#include <string>

class read_image {
public:
    read_image() {}

    read_image(const char* image_filename) {
        auto filename = std::string(image_filename);

        if (load(filename))               return;
        if (load("assets/" + filename))   return;

        std::cerr << "ERROR: Could not load image file '" << image_filename << "'.\n";
    }

    ~read_image() {
        delete[] bdata;
        STBI_FREE(fdata);
    }

    bool load(const std::string& filename) {
        auto n = bytes_per_pixel;
        fdata = stbi_loadf(filename.c_str(), &image_width, &image_height, &n, bytes_per_pixel);
        if (fdata == nullptr) return false;
        bytes_per_scanline = image_width * bytes_per_pixel;
        convert_to_bytes();
        return true;
    }

    int width()  const { return fdata ? image_width : 0; }
    int height() const { return fdata ? image_height : 0; }
    int bytes()  const { return image_width * image_height * bytes_per_pixel; }

    // FIX: data() getter — lets main.cu copy pixel bytes to device memory
    // via cudaMalloc + cudaMemcpy for use with image_texture.
    const unsigned char* data() const { return bdata; }

    const unsigned char* pixel_data(int x, int y) const {
        static unsigned char magenta[] = { 255, 0, 255 };
        if (!bdata) return magenta;
        x = clamp(x, 0, image_width);
        y = clamp(y, 0, image_height);
        return bdata + y * bytes_per_scanline + x * bytes_per_pixel;
    }

private:
    const int      bytes_per_pixel = 3;
    float* fdata = nullptr;
    unsigned char* bdata = nullptr;
    int            image_width = 0;
    int            image_height = 0;
    int            bytes_per_scanline = 0;

    static int clamp(int x, int low, int high) {
        if (x < low)  return low;
        if (x < high) return x;
        return high - 1;
    }

    static unsigned char float_to_byte(float value) {
        if (value <= 0.0f) return 0;
        if (value >= 1.0f) return 255;
        return static_cast<unsigned char>(256.0f * value);
    }

    void convert_to_bytes() {
        int total = image_width * image_height * bytes_per_pixel;
        bdata = new unsigned char[total];
        auto* b = bdata;
        auto* f = fdata;
        for (int i = 0; i < total; i++, f++, b++)
            *b = float_to_byte(*f);
    }
};

#ifdef _MSC_VER
#pragma warning(pop)
#endif