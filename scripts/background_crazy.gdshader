shader_type canvas_item;

uniform float screen_height = 1080;

//fragment runs for every pixel
void fragment() {
	//basically get the amount of difference the pixels should be moving
	//float diff_x = 0.1 * sin((10.0 * UV.y) + (.3 * TIME))  + .1;
	float diff_x = 0.1 * sin((10.0 * UV.y) + (.3 * (TIME + 25.0)))  + .1;

	COLOR = texture(TEXTURE, vec2(UV.x + diff_x, UV.y));

	COLOR = mix(COLOR, vec4(0.0), float(int(UV.y * screen_height) % 2));
}
