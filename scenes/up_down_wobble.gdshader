shader_type canvas_item;

uniform float screen_height = 1080;

//fragment runs for every pixel
void fragment() {
	//basically get the amount of difference the pixels should be moving
	//float diff_x = 0.1 * sin((10.0 * UV.y) + (.3 * TIME))  + .1;
	float wob_y = 0.05 * sin((10.0 * UV.x) + (.3 * (TIME + 1.0)));

	COLOR = texture(TEXTURE, vec2(UV.x , UV.y + wob_y));

	//COLOR = mix(COLOR, vec4(0.0), float(int(UV.y * screen_height)));
}
