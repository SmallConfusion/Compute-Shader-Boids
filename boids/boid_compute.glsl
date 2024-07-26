#[compute]
#version 450

layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer Boids {
	float data[];
}
boids;

layout(push_constant) uniform PushConstants {
	int boid_count;
	float separation;
	float alignment;
	float cohesion;
	float speed;
	float friction;
	float max_speed;
	float ease_s;
	float ease_a;
	float edge_influence;
	float edge_padding;
	float influence_dist;
	float width;
	float height;
	float speed_variation;
}
pc;


void main() {
	float this_random = fract(sin(gl_GlobalInvocationID.x * 24.538904) * 48439.385955);
	
	vec2 pos = vec2(
		boids.data[gl_GlobalInvocationID.x * 4],
		boids.data[gl_GlobalInvocationID.x * 4 + 1]
	);

	vec2 vel = vec2(
		boids.data[gl_GlobalInvocationID.x * 4 + 2],
		boids.data[gl_GlobalInvocationID.x * 4 + 3]
	);

	vec2 separation_total = vec2(0);
	vec2 alignment_total = vec2(0);
	vec2 cohesion_total = vec2(0);

	float total = 0.;

	for (int i = 0; i < pc.boid_count; i += 1) {
		if (gl_GlobalInvocationID.x != i) {
			vec2 other_pos = vec2(
				boids.data[i * 4],
				boids.data[i * 4 + 1]
			);

			float dist_scaled = distance(pos, other_pos) / pc.influence_dist;

			if (dist_scaled < 1.) {
				vec2 other_vel = vec2(
					boids.data[i * 4 + 2],
					boids.data[i * 4 + 3]
				);

				float influence = 1. - dist_scaled;
				
				separation_total += normalize(pos - other_pos) * pow(influence, pc.ease_s);
				alignment_total += normalize(other_vel) * pow(influence, pc.ease_a);
				cohesion_total += other_pos;

				total += 1.;
			}
		}
	}

	cohesion_total = cohesion_total / total - pos;

	separation_total *= pc.separation;
	alignment_total *= pc.alignment;
	cohesion_total *= pc.cohesion;


	vec2 movement_total = (separation_total + alignment_total + cohesion_total);

	float speed = pc.speed - pc.speed * this_random * pc.speed_variation;
	movement_total = normalize(movement_total) * speed;
	
	vel += movement_total;
	vel *= pc.friction;


	vec2 d_to_max = vec2(pc.width, pc.height) - pos;

	vec2 edge = max(1 - pos / pc.edge_padding, 0) +
				min(d_to_max / pc.edge_padding, 1) - 1;


	vel += edge * pow(pc.edge_influence, 2);


	float vel_len = length(vel);
	float max_speed = pc.max_speed - pc.max_speed * this_random * pc.speed_variation;

	vel = vel / vel_len * min(vel_len, max_speed);

	pos += vel;

	boids.data[gl_GlobalInvocationID.x * 4] = pos.x;
	boids.data[gl_GlobalInvocationID.x * 4 + 1] = pos.y;
	boids.data[gl_GlobalInvocationID.x * 4 + 2] = vel.x;
	boids.data[gl_GlobalInvocationID.x * 4 + 3] = vel.y;
}