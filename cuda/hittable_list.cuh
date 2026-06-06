#pragma once

#include "hittable.cuh"
#include "common.cuh"
#include <thrust/device_vector.h>

class hittable_list : public hittable {
public:
	thrust::device_vector<hittable*> objects;

	__device__ hittable_list() {}
	__device__ hittable_list(hittable* object) { add(object); }

	
	__device__ void clear() { 
		objects.clear();
	 }

	__device__ void add(hittable* object) {
		objects.push_back(object);
		bbox = aabb(bbox, object->bounding_box());
	}

	__device__ bool hit(const ray& r, interval ray_t, hit_record& rec) const {
		hit_record temp_rec;
		bool hit_anything = false;
		auto closest_so_far = ray_t.max;

		for (auto object: objects) {
			if ((*object).hit(r, interval(ray_t.min, closest_so_far), temp_rec)) {
				hit_anything = true;
				closest_so_far = temp_rec.t;
				rec = temp_rec;
			}
		}

		return hit_anything;
	}
	__device__ aabb bounding_box() const { return bbox; }

private:
	aabb bbox;
};