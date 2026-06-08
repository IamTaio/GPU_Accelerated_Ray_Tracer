#pragma once

#pragma once

#include "aabb.cuh"
#include "hittable.cuh"
#include "hittable_list.cuh"

class bvh_node : public hittable {
public:

	__device__ ~bvh_node(){
		if (left == right){
			delete left;
			left = nullptr;
			right = nullptr;
			return;
		}
		delete left;
		delete right;
		left = nullptr;
		right = nullptr;
	}

	__device__ bvh_node(hittable_list list) : bvh_node(list.get_objects(), 0, list.capacity) {

	}

	__device__ bvh_node(hittable** objects, size_t start, size_t end) {
		// left = (bvh_node*)malloc(sizeof(bvh_node));
		// right = (bvh_node*)malloc(sizeof(bvh_node));
		bbox = aabb::empty();

		for (size_t object_index = start; object_index < end; object_index++) {
			bbox = aabb(bbox, (*objects[object_index]).bounding_box());
		}

		int axis = bbox.longest_axis();

		auto comparator = (axis == 0) ? box_x_compare
			: (axis == 1) ? box_y_compare
			: box_z_compare;

		size_t  object_span = end - start;

		if (object_span == 1) {
			left = right = objects[start];
		}
		else if (object_span == 2) {
			left = objects[start];
			right = objects[start + 1];
		}
		else {
			sort(objects, start, end, comparator);

			auto mid = start + object_span / 2;
			
			// new (left) bvh_node(objects, start, mid);
			// new (right) bvh_node(objects, mid, end);
			left = new bvh_node(objects, start, mid);
			right = new bvh_node(objects, mid, end);
		}
	}

	__device__ bool hit(const ray& r, interval ray_t, hit_record& rec) const {
		if (!bbox.hit(r, ray_t)) {
			return false;
		}

		bool hit_left = left->hit(r, ray_t, rec);
		bool hit_right = right->hit(r, interval(ray_t.min, hit_left ? rec.t : ray_t.max), rec);

		return hit_left || hit_right;
	}

	 __device__ aabb bounding_box() const { return bbox; }

private:
	hittable* left;
	hittable* right;
	aabb bbox;

	__device__ static bool box_compare(const hittable* a, const hittable* b, int axis_index) {
		auto a_axis_interval = a->bounding_box()[axis_index];
		auto b_axis_interval = b->bounding_box()[axis_index];
		return a_axis_interval.min < b_axis_interval.min;
	}

	__device__ static bool box_x_compare(const hittable* a, const hittable* b) {
		return box_compare(a, b, 0);
	}

	__device__ static bool box_y_compare(const hittable* a, const hittable* b) {
		return box_compare(a, b, 1);
	}

	__device__ static bool box_z_compare(const hittable* a, const hittable* b) {
		return box_compare(a, b, 2);
	}

	__device__ void sort(hittable** list, size_t start, size_t end, bool(*comparator)(const hittable* a, const hittable* b)) {
    if (start == end - 1)
        return;

    size_t mid = start + (end - start) / 2;

    sort(list, start, mid, comparator);
    sort(list, mid, end, comparator);

	int l = start, r = mid, s = 0;
	hittable** sorted = (hittable**)malloc((end - start) * sizeof(hittable*));
    while (l < mid && r < end) {
        if (comparator(list[l], list[r])){
            sorted[s++] = list[l++];
		}
        else
            sorted[s++] = list[r++];
    }
    while (l < mid) sorted[s++] = list[l++];
    while (r < end) sorted[s++] = list[r++];

	for(int i = 0; i < (end - start); i++){
		list[start+i] = sorted[i];
	}

    free(sorted);
}
};

