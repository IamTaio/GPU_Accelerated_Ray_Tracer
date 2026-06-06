#pragma once

#include "ray.cuh"
#include "aabb.cuh"
#include "sphere.cuh"
#include "bvh.cuh"


class material;
enum class ShapeType { Sphere, BVH };

class hit_record {
public:
	point3 p;
	double u;
	double v;
	vec3 normal;
	material* mat;
	double t;
	bool front_face;

	__host__ __device__ void set_face_normal(const ray& r, const vec3& outward_normal) {
		front_face = dot(r.direction(), outward_normal) < 0;
		normal = front_face ? outward_normal : -outward_normal;
	}
};

class hittable {
public:
	ShapeType m_type;
	__host__ __device__ ~hittable() = default;

	__host__ __device__ bool hit(const ray& r, interval ray_t, hit_record& rec) const {
		switch (m_type) {
            case ShapeType::Sphere:   return ((sphere*)this)->hit(r, ray_t, rec);
			case ShapeType::BVH:	  return ((bvh_node*)this)->hit(r, ray_t, rec);
            default:                  return false;
        }
	};

	__host__ __device__ aabb bounding_box() const {};
};

