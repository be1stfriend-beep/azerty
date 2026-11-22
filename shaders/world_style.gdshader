shader_type spatial;

#include "res://shaders/restore.gdshaderinc"

uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform float rim_strength = 0.5;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = tint.rgb * texture(albedo_tex, UV).rgb;
	ALBEDO = mix(dusty(base), lush(base), restoration(world_pos));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	DIFFUSE_LIGHT += cel_light(NORMAL, LIGHT, VIEW, LIGHT_COLOR, ATTENUATION, rim_strength);
}
