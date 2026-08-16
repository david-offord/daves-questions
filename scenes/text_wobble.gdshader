shader_type canvas_item;

uniform float amplitude = 0.01;
uniform float frequency = 20.0;
uniform float speed = 3.0;

void fragment() {
	vec2 uv = UV;

	float wave = sin((uv.x * frequency) + TIME * speed) * amplitude;
	uv.y += wave;

	vec4 tex = texture(TEXTURE, uv);

	COLOR = tex * COLOR;
}