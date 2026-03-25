shader_type spatial;

uniform sampler2D texture_wall: source_color, repeat_enable, filter_nearest;
uniform sampler2D texture_roof: source_color, repeat_enable, filter_nearest;
uniform float wall_texture_scale;
uniform float roof_texture_scale;

void fragment() {
	vec4 vertex = INV_VIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 adjusted_normal = abs(normal);
	vec3 weights = adjusted_normal / (adjusted_normal.x + adjusted_normal.y + adjusted_normal.z) * 3.0;

	vec2 uv_x = vertex.zy * wall_texture_scale;
	vec2 uv_y = vertex.xz * roof_texture_scale;
	vec2 uv_z = vertex.xy * wall_texture_scale;

	vec3 color_x = texture(texture_wall, uv_x).rgb * weights.x;
	vec3 color_y = texture(texture_roof, uv_y).rgb * weights.y;
	vec3 color_z = texture(texture_wall, uv_z).rgb * weights.z;
	ALBEDO = (color_x + color_y + color_z) / 3.0;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
