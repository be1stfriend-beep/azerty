shader_type canvas_item;

uniform vec4 haze_color : source_color;
uniform float haze_amount = 0.06;
uniform float vignette_amount = 0.45;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float edge = smoothstep(0.35, 0.85, length(centered * vec2(1.25, 1.0)));
	float darken = edge * vignette_amount;
	vec3 col = mix(haze_color.rgb, vec3(0.0), darken / max(darken + haze_amount, 0.001));
	COLOR = vec4(col, darken + haze_amount);
}
