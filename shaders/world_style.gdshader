shader_type spatial;

#include "res://shaders/restore.gdshaderinc"

uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform float rim_strength = 0.5;
// Imported models that paint with vertex colours (the nature pack) instead of a texture.
uniform float use_vertex_color = 0.0;
// Characters keep their saturated colours so they pop against the dusty world.
uniform float character = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = tint.rgb * texture(albedo_tex, UV).rgb * mix(vec3(1.0), COLOR.rgb, use_vertex_color);
	vec3 world_col = mix(dusty(base), lush(base), restoration(world_pos));
	ALBEDO = mix(world_col, base, character);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	DIFFUSE_LIGHT += cel_light(NORMAL, LIGHT, VIEW, LIGHT_COLOR, ATTENUATION, rim_strength);
}
