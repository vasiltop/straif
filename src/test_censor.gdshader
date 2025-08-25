shader_type spatial;
render_mode unshaded;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float pixel_size = 0.04;

void fragment() {
    vec2 screen_uv = SCREEN_UV;

    // Pixelation step
    vec2 pixel_uv = floor(screen_uv / pixel_size) * pixel_size;

    // Sample the screen
    vec4 pixel_color = texture(SCREEN_TEXTURE, pixel_uv);

    // Convert to grayscale (black & white)
    float gray = dot(pixel_color.rgb, vec3(0.299, 0.587, 0.114)); // Luma formula
    vec3 bw_color = vec3(gray);

    ALBEDO = bw_color;
    ALPHA = 1.0;
}
