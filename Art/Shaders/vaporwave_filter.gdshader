shader_type spatial;
render_mode unshaded, skip_vertex_transform, cull_disabled;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

//Vaporwave
uniform float vapor_tint_strength : hint_range(0.0, 1.0) = 0.35;
uniform vec3 neonPink_color = vec3( 0.9, 0.1, 0.6);
uniform vec3 neonCyan_color = vec3(0.0, 0.9, 0.9);

//Screen Distortion
uniform float aberration_amount : hint_range(0.0, 0.05) = 0.005;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	
	//Chromatic Aberation
	vec2 direction = SCREEN_UV - vec2(0.5);
	float edge = dot(direction, direction);
	vec2 offset = direction * edge * aberration_amount;
	
	vec2 shrunk_uv = vec2(0.5) + direction * (1.0 - aberration_amount);
	
	float r = texture(screen_texture, shrunk_uv + offset).r;
	float g = texture(screen_texture, uv).g; //No green shift, want to capture sunset colors
	float b = texture(screen_texture, shrunk_uv - offset).b;
	vec3 base_color = vec3(r, g, b);
	
	//Tinting
	float luminance = dot(base_color, vec3(0.299, 0.587, 0.114));
	float lum_perceptual = pow(luminance, 1.0 / 2.2);
	lum_perceptual = smoothstep(0.15, 0.85, lum_perceptual);
	vec3 vapor_tint = mix(neonCyan_color, neonPink_color, luminance);
	vec3 mixed_color = mix(base_color, vapor_tint, vapor_tint_strength);
	
	
	ALBEDO = mixed_color;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
