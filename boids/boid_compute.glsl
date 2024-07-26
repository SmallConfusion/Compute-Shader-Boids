#[compute]
#version 450

#define xp boids.data[gl_GlobalInvocationID.x * 4]
#define yp boids.data[gl_GlobalInvocationID.x * 4 + 1]
#define xv boids.data[gl_GlobalInvocationID.x * 4 + 2]
#define yv boids.data[gl_GlobalInvocationID.x * 4 + 3]

#define bxp(x) boids.data[x * 4]
#define byp(x) boids.data[x * 4 + 1]
#define bxv(x) boids.data[x * 4 + 2]
#define byv(x) boids.data[x * 4 + 3]



layout(local_size_x = 32, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer Boids {
	float data[];
}
boids;

layout(push_constant) uniform PushConstants {
	float time;
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
}
pc;


void main() {
	vec2 separation_total = vec2(0);
	vec2 alignment_total = vec2(0);
	vec2 cohesion_total = vec2(0);

	float total = 0.;

	for (int i = 0; i < pc.boid_count; i += 1) {
		if (gl_GlobalInvocationID.x != i) {
		
			float rough_dist = max(abs(bxp(i) - xp), abs(byp(i) - yp));
			
			if (rough_dist < pc.influence_dist) {
				vec2 this_pos = vec2(xp, yp);
				vec2 other_pos = vec2(bxp(i), byp(i));
				vec2 other_dir = vec2(bxv(i), byv(i));

				float d = distance(this_pos, other_pos);
				float influence = 1. - clamp(d / pc.influence_dist, 0, 1);
				
				separation_total += normalize(this_pos - other_pos) * pow(influence, pc.ease_s);
				alignment_total += normalize(other_dir) * influence * pow(influence, pc.ease_a);
				cohesion_total += other_pos;

				total += 1.;
			}
		}
	}

	cohesion_total /= total;

	cohesion_total = cohesion_total - vec2(xp, yp);

	separation_total *= pc.separation;
	alignment_total *= pc.alignment;
	cohesion_total *= pc.cohesion;


	vec2 movement_total = (separation_total + alignment_total + cohesion_total);

	movement_total = normalize(movement_total) * pc.speed;

	vec2 v = vec2(xv, yv);
	
	v += movement_total;
	v *= pc.friction;


	if (xp <= pc.edge_padding) {
		v.x += pc.edge_influence * (pc.edge_padding - xp);
	}

	if (yp <= pc.edge_padding) {
		v.y += pc.edge_influence * (pc.edge_padding - yp);
	}

	if (xp >= pc.width - pc.edge_padding) {
		v.x -= pc.edge_influence * (pc.edge_padding - (pc.width - xp));
	}

	if (yp >= pc.height - pc.edge_padding) {
		v.y -= pc.edge_influence * (pc.edge_padding - (pc.height - yp));
	}



	if (length(v) > pc.max_speed) {
		v = normalize(v) * pc.max_speed;
	}


	xv = v.x;
	yv = v.y;

	// apply velocity
	xp = clamp(xp + xv, 0, pc.width);
	yp = clamp(yp + yv, 0, pc.height);
}