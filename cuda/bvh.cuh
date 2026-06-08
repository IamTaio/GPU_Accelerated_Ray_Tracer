#pragma once

#pragma once

#include "aabb.cuh"
#include "hittable.cuh"
#include "hittable_list.cuh"

// #include <thrust/sort.h>
// #include <thrust/device_vector.h>

// class bvh_node : public hittable {
// public:
// 	__device__ bvh_node(hittable_list list) : bvh_node(list.get_objects(), 0, list.capacity) {

// 	}

// 	__device__ bvh_node(hittable** objects, size_t start, size_t end) {
// 		left = (bvh_node*)malloc(sizeof(bvh_node));
// 		right = (bvh_node*)malloc(sizeof(bvh_node));
// 		bbox = aabb::empty;

// 		for (size_t object_index = start; object_index < end; object_index++) {
// 			bbox = aabb(bbox, (*objects[object_index]).bounding_box());
// 		}

// 		int axis = bbox.longest_axis();

// 		auto comparator = (axis == 0) ? box_x_compare
// 			: (axis == 1) ? box_y_compare
// 			: box_z_compare;

// 		size_t  object_span = end - start;

// 		if (object_span == 1) {
// 			left = right = objects[start];
// 		}
// 		else if (object_span == 2) {
// 			left = objects[start];
// 			right = objects[start + 1];
// 		}
// 		else {
// 			sort(objects, comparator);

// 			auto mid = start + object_span / 2;
			
// 			new (left) bvh_node(objects, start, mid);
// 			new (right) bvh_node(objects, mid, end);
// 			// left = &bvh_node(objects, start, mid);
// 			// right = &bvh_node(objects, mid, end);
// 		}
// 	}

// 	__device__ bool hit(const ray& r, interval ray_t, hit_record& rec) const {
// 		if (!bbox.hit(r, ray_t)) {
// 			return false;
// 		}

// 		bool hit_left = left->hit(r, ray_t, rec);
// 		bool hit_right = right->hit(r, interval(ray_t.min, hit_left ? rec.t : ray_t.max), rec);

// 		return hit_left || hit_right;
// 	}

// 	 __device__ aabb bounding_box() const { return bbox; }

// private:
// 	hittable* left;
// 	hittable* right;
// 	aabb bbox;

// 	__device__ static bool box_compare(const hittable* a, const hittable* b, int axis_index) {
// 		auto a_axis_interval = a->bounding_box()[axis_index];
// 		auto b_axis_interval = b->bounding_box()[axis_index];
// 		return a_axis_interval.min < b_axis_interval.min;
// 	}

// 	__device__ static bool box_x_compare(const hittable* a, const hittable* b) {
// 		return box_compare(a, b, 0);
// 	}

// 	__device__ static bool box_y_compare(const hittable* a, const hittable* b) {
// 		return box_compare(a, b, 1);
// 	}

// 	__device__ static bool box_z_compare(const hittable* a, const hittable* b) {
// 		return box_compare(a, b, 2);
// 	}
// };

// __device__ hittable** sort(hittable** list, size_t size, bool(*comparator)(hittable*, hittable*)) {
//     if (size == 1) {
//         hittable** result = (hittable**)malloc(sizeof(hittable*));
//         result[0] = list[0];
//         return result;
//     }

//     size_t size_l = size / 2;
//     size_t size_r = size - size_l;

//     hittable** left  = (hittable**)malloc(size_l * sizeof(hittable*));
//     hittable** right = (hittable**)malloc(size_r * sizeof(hittable*));

//     for (int i = 0; i < size_l; i++) left[i]  = list[i];
//     for (int i = 0; i < size_r; i++) right[i] = list[i + size_l];

//     hittable** left_sorted  = sort(left,  size_l, comparator);
//     hittable** right_sorted = sort(right, size_r, comparator);

//     hittable** sorted = (hittable**)malloc(size * sizeof(hittable*));
//     int l = 0, r = 0, s = 0;
//     while (l < size_l && r < size_r) {
//         if (comparator(left_sorted[l], right_sorted[r]))
//             sorted[s++] = left_sorted[l++];
//         else
//             sorted[s++] = right_sorted[r++];
//     }
//     while (l < size_l) sorted[s++] = left_sorted[l++];
//     while (r < size_r) sorted[s++] = right_sorted[r++];

// 	free(left);
//     free(right);
//     free(left_sorted);
//     free(right_sorted);

//     return sorted;
// }