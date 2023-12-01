shader_type canvas_item;

uniform float epsilon = 0.001;

void fragment() {
	if (mod(UV.x,TEXTURE_PIXEL_SIZE.x) < 0.0001) {
		COLOR = vec4(0,0,0,1);
	}
	if (mod(UV.y,TEXTURE_PIXEL_SIZE.y) < 0.0001) {
		COLOR = vec4(0,0,0,1);
	}
}