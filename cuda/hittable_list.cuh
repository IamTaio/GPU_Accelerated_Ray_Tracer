#pragma once

#include "hittable.cuh"
#include "common.cuh"
#include <thrust/device_vector.h>

#define OBJS_MAX_SIZE 1024
class hittable_list : public hittable {
public:
	int capacity;
	hittable** objects;

	__device__ hittable_list(): capacity(0), objects(new hittable*[OBJS_MAX_SIZE]), bbox(aabb::empty()) {}

	__device__ hittable_list(hittable* obj): hittable_list(){
		add(obj);
		capacity = 1;
	}

	__device__ hittable_list(hittable** objs, int cap): hittable_list() {
		for(int i = 0; i < cap; i++)
			add(objs[i]);
		capacity = cap;
	}

	__device__ void clear() { 
		for(int i = 0; i < capacity; i++){
			objects[i] = nullptr;
		}
		capacity = 0;
	 }

	__device__ void add(hittable* object) {
		if(capacity >= OBJS_MAX_SIZE)
			return;
		objects[capacity++] = object;
		bbox = aabb(bbox, object->bounding_box());
	}

	__device__ hittable** get_objects(){
		return objects;
	}

	// __device__ hittable* get(){return;}
 
	__device__ bool hit(const ray& r, interval ray_t, hit_record& rec) const override{
		hit_record temp_rec;
		bool hit_anything = false;
		auto closest_so_far = ray_t.max;

		for (int i = 0; i < capacity; i++) {
			if (objects[i]->hit(r, interval(ray_t.min, closest_so_far), temp_rec)) {
				hit_anything = true;
				closest_so_far = temp_rec.t;
				rec = temp_rec;
			}
		}

		return hit_anything;
	}
	__device__ aabb bounding_box() const override { return bbox; }

private:
	aabb bbox;
};
