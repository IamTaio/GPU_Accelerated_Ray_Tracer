#pragma once

// FIX: removed duplicate #pragma once

#include "aabb.cuh"
#include "hittable.cuh"
#include "hittable_list.cuh"

class bvh_node : public hittable {
public:

    __device__ ~bvh_node() {}

    __device__ bvh_node(hittable_list list) : bvh_node(list.get_objects(), 0, list.capacity) {}

    __device__ bvh_node(hittable** objects, size_t start, size_t end) {
        size_t     object_span = end - start;
        hittable** copy = (hittable**)malloc(sizeof(hittable*) * object_span);
        for (int i = 0; i < object_span; i++)
            copy[i] = objects[start + i];

        bbox = aabb::empty();
        for (size_t i = 0; i < object_span; i++)
            bbox = aabb(bbox, copy[i]->bounding_box());

        int axis = bbox.longest_axis();

        auto comparator = (axis == 0) ? box_x_compare
            : (axis == 1) ? box_y_compare
            : box_z_compare;

        if (object_span == 1) {
            left = right = copy[0];
        }
        else if (object_span == 2) {
            left = copy[0];
            right = copy[1];
        }
        else {
            sort(copy, 0, object_span, comparator);
            auto mid = object_span / 2;
            left = new bvh_node(copy, 0, mid);
            right = new bvh_node(copy, mid, object_span);
        }

        free(copy);
    }

    __device__ bool hit(const ray& r, interval ray_t, hit_record& rec) const override {
        if (!bbox.hit(r, ray_t)) return false;

        bool hit_left = left->hit(r, ray_t, rec);
        bool hit_right = right->hit(r, interval(ray_t.min, hit_left ? rec.t : ray_t.max), rec);

        return hit_left || hit_right;
    }

    __device__ aabb bounding_box() const override { return bbox; }

    hittable* left;
    hittable* right;
    aabb      bbox;

    __device__ static bool box_compare(const hittable* a, const hittable* b, int axis) {
        return a->bounding_box()[axis].min < b->bounding_box()[axis].min;
    }

    __device__ static bool box_x_compare(const hittable* a, const hittable* b) { return box_compare(a, b, 0); }
    __device__ static bool box_y_compare(const hittable* a, const hittable* b) { return box_compare(a, b, 1); }
    __device__ static bool box_z_compare(const hittable* a, const hittable* b) { return box_compare(a, b, 2); }

    __device__ static void sort(hittable** list, size_t start, size_t end,
        bool(*comparator)(const hittable*, const hittable*)) {
        if (start == end - 1) return;

        size_t mid = start + (end - start) / 2;
        sort(list, start, mid, comparator);
        sort(list, mid, end, comparator);

        hittable** sorted = (hittable**)malloc((end - start) * sizeof(hittable*));
        int l = start, r = mid, s = 0;
        while (l < mid && r < end)
            sorted[s++] = comparator(list[l], list[r]) ? list[l++] : list[r++];
        while (l < mid) sorted[s++] = list[l++];
        while (r < end) sorted[s++] = list[r++];
        for (int i = 0; i < (int)(end - start); i++)
            list[start + i] = sorted[i];
        free(sorted);
    }
};
