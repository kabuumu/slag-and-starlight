shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 fog_tint : source_color = vec4(0.24, 0.11, 0.06, 1.0);
uniform float fog_strength : hint_range(0.0, 1.0) = 0.16;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;
uniform float rust_warmth : hint_range(0.0, 1.0) = 0.12;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 col = texture(screen_texture, uv);

	// Subtle Khoros-IV rust/amber atmospheric tint
	vec3 tinted = mix(col.rgb, fog_tint.rgb, fog_strength * 0.35);
	tinted.r = clamp(tinted.r + rust_warmth * 0.06, 0.0, 1.0);
	tinted.b = clamp(tinted.b - rust_warmth * 0.04, 0.0, 1.0);

	// 256-color industrial/rust palette quantization (8 x 8 x 4 = 256 levels)
	vec3 quantized;
	quantized.r = floor(tinted.r * 7.0 + 0.5) / 7.0;
	quantized.g = floor(tinted.g * 7.0 + 0.5) / 7.0;
	quantized.b = floor(tinted.b * 3.0 + 0.5) / 3.0;

	// Retro CRT vignette
	vec2 centered = uv - vec2(0.5);
	float dist = dot(centered, centered) * 2.0;
	float vig = clamp(1.0 - dist * vignette_strength, 0.35, 1.0);
	vec3 final_rgb = mix(fog_tint.rgb * 0.25, quantized * vig, vig);

	COLOR = vec4(final_rgb, col.a);
}
