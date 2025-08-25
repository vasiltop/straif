shader_type spatial;

render_mode depth_draw_never, cull_back, unshaded;

void fragment() {
    ALBEDO = vec3(1.0, 0.0, 0.0); // Red color example
}