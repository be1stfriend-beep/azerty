shader_type spatial;

#include "res://shaders/restore.gdshaderinc"

uniform vec4 dust_color : source_color;
uniform vec4 grass_color : source_color;
uniform vec4 soil_color : source_color;
uniform float soil_speckle_scale = 0.9;
uniform float band_scale = 0.035;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x);
	float b = mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x);
	return mix(a, b, u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * band_scale;
	float n = value_noise(p) * 0.65 + value_noise(p * 2.7 + 13.0) * 0.35;
	// Quantised bands keep the ground in the same flat cel look as the props.
	float shade = 0.88 + floor(n * 3.0) / 3.0 * 0.14;
	// Fine two-tone patches so the Dome soil reads as tilled earth with moss, not flat paint.
	float speckle = step(0.55, value_noise(world_pos.xz * soil_speckle_scale));
	vec3 soil = mix(soil_color.rgb, grass_color.rgb, speckle * 0.45);
	vec3 col = mix(dust_color.rgb, soil, dome_weight(world_pos));
	col = mix(col, grass_color.rgb, restoration(world_pos));
	ALBEDO = col * shade;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	DIFFUSE_LIGHT += cel_light(NORMAL, LIGHT, VIEW, LIGHT_COLOR, ATTENUATION, 0.0);
}
