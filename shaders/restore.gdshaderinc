global uniform vec4 tower_0;
global uniform vec4 tower_1;
global uniform vec4 tower_2;
global uniform vec4 tower_3;
global uniform float restore_0;
global uniform float restore_1;
global uniform float restore_2;
global uniform float restore_3;
// xyz centre, w radius; zero radius means the level has no Dome.
global uniform vec4 dome_area;

// BRIEF: a soft 4 m edge inside each tower radius.
const float RESTORE_EDGE = 4.0;
const float DOME_EDGE = 2.5;
// The Dome's clean air keeps things alive, but only towers bring back full colour.
const float DOME_LIFE = 0.6;
const vec3 LUMA = vec3(0.299, 0.587, 0.114);

float tower_weight(vec4 tower, float amount, vec3 p) {
	if (tower.w <= 0.0) {
		return 0.0;
	}
	float d = distance(p.xz, tower.xz);
	// Equals smoothstep(radius, radius - EDGE, d); GLSL leaves reversed edges undefined.
	return (1.0 - smoothstep(tower.w - RESTORE_EDGE, tower.w, d)) * amount;
}

float restoration(vec3 p) {
	float a = max(tower_weight(tower_0, restore_0, p), tower_weight(tower_1, restore_1, p));
	float b = max(tower_weight(tower_2, restore_2, p), tower_weight(tower_3, restore_3, p));
	return max(a, b);
}

float dome_weight(vec3 p) {
	if (dome_area.w <= 0.0) {
		return 0.0;
	}
	return 1.0 - smoothstep(dome_area.w - DOME_EDGE, dome_area.w, distance(p.xz, dome_area.xz));
}

float liveliness(vec3 p) {
	return max(restoration(p), dome_weight(p) * DOME_LIFE);
}

vec3 dusty(vec3 c) {
	vec3 grey = vec3(dot(c, LUMA));
	return mix(grey, c, 0.35) * vec3(1.0, 0.88, 0.72) * 0.82;
}

vec3 lush(vec3 c) {
	vec3 grey = vec3(dot(c, LUMA));
	return clamp(mix(grey, c, 1.3) * 1.1, 0.0, 1.0);
}

// LIGHT_COLOR already carries a factor of PI in Godot 4, hence the division.
vec3 cel_light(vec3 normal, vec3 light, vec3 view, vec3 light_color, float attenuation, float rim_strength) {
	float ndl = dot(normal, light);
	float band = ndl > 0.55 ? 1.0 : (ndl > 0.1 ? 0.6 : 0.3);
	float fresnel = 1.0 - clamp(dot(normal, view), 0.0, 1.0);
	float rim = smoothstep(0.72, 0.78, fresnel) * rim_strength * step(0.0, ndl);
	return light_color * attenuation * (band + rim) / PI;
}
