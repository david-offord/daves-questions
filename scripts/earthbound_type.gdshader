shader_type canvas_item;

void fragment() {
    // Center UVs so (0,0) is the middle
    vec2 uv = UV - 0.5;

    // Time-scaled motion
    float t = TIME * 0.1;

    // Radial distance from center
    float dist = length(uv);

    // Wavy distortion
    float wave =
        sin(dist * 12.0 - t) +
        sin(uv.x * 8.0 + t * 1.2) +
        sin(uv.y * 8.0 - t * 0.8);

    // Color channels drift independently
    float r = sin(wave + t);
    float g = sin(wave + t + 2.0);
    float b = sin(wave + t + 4.0);

    // Normalize to 0–1 range
    vec3 color = vec3(r, g, b) * 0.5 + 0.5;
	color = mix(vec3(0.3), color, 0.6);
	
	
	const vec3 PALETTE[4] = vec3[](
    	vec3(0.90, 0.60, 0.60), // pastel red
    	vec3(0.95, 0.90, 0.65), // pastel yellow
    	vec3(0.75, 0.65, 0.90), // pastel purple
    	vec3(0.70, 0.85, 0.70)  // pastel green
	);
	
	
	
	
	
	
	
	
	
	
	
float index = floor(color.r * float(PALETTE.length()));
index = clamp(index, 0.0, float(PALETTE.length() - 1));

COLOR = vec4(PALETTE[int(index)], 1.0);
}